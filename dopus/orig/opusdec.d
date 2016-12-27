/*
 * Opus decoder
 * Copyright (c) 2012 Andrew D'Addesio
 * Copyright (c) 2013-2014 Mozilla Corporation
 *
 * This file is part of FFmpeg.
 *
 * FFmpeg is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * FFmpeg is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with FFmpeg; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */
module opusdec;

/**
 * @file
 * Opus decoder
 * @author Andrew D'Addesio, Anton Khirnov
 *
 * Codec homepage: http://opus-codec.org/
 * Specification: http://tools.ietf.org/html/rfc6716
 * Ogg Opus specification: https://tools.ietf.org/html/draft-ietf-codec-oggopus-03
 *
 * Ogg-contained .opus files can be produced with opus-tools:
 * http://git.xiph.org/?p=opus-tools.git
 */

import iv.cmdcon;

import avmem;
import avfft;
import opus;
import opus_celt;
import opus_silk;
import opus_resampler;


enum AV_SAMPLE_FMT_FLTP = 8; //HACK


static immutable uint16_t[16] silk_frame_duration_ms = [
  10, 20, 40, 60,
  10, 20, 40, 60,
  10, 20, 40, 60,
  10, 20,
  10, 20,
];

/* number of samples of silence to feed to the resampler at the beginning */
static immutable int[5] silk_resample_delay = [ 4, 8, 11, 11, 11 ];

static immutable uint8_t[5] celt_band_end = [ 13, 17, 17, 19, 21 ];

static int get_silk_samplerate (int config) {
  return (config < 4 ? 8000 : config < 8 ? 12000 : 16000);
}

/**
 * Range decoder
 */
static int opus_rc_init (OpusRangeCoder *rc, const(uint8_t)* data, int size) {
  //conwritefln!"size=%s; 0x%02x"(size, data[0]);
  int ret = rc.gb.init_get_bits8(data, size);
  if (ret < 0) return ret;

  rc.range = 128;
  rc.value = 127 - rc.gb.get_bits(7);
  rc.total_read_bits = 9;
  opus_rc_normalize(rc);
  //conwriteln("range=", rc.range, "; value=", rc.value);
  //assert(0);

  return 0;
}

static void opus_raw_init (OpusRangeCoder* rc, const(uint8_t)* rightend, uint bytes) {
  rc.rb.position = rightend;
  rc.rb.bytes    = bytes;
  rc.rb.cachelen = 0;
  rc.rb.cacheval = 0;
}

static void opus_fade (float *out_, const(float)* in1, const(float)* in2, const(float)* window, int len) {
  for (int i = 0; i < len; i++) out_[i] = in2[i] * window[i] + in1[i] * (1.0 - window[i]);
}

static int opus_flush_resample (OpusStreamContext* s, int nb_samples) {
  int celt_size = av_audio_fifo_size(s.celt_delay); //k8
  int ret, i;
  ret = s.flr.swrconvert(cast(float**)s.out_, nb_samples, null, 0);
  if (ret < 0) return AVERROR_BUG;
  if (ret != nb_samples) {
    //av_log(s.avctx, AV_LOG_ERROR, "Wrong number of flushed samples: %d\n", ret);
    return AVERROR_BUG;
  }

  if (celt_size) {
    if (celt_size != nb_samples) {
      //av_log(s.avctx, AV_LOG_ERROR, "Wrong number of CELT delay samples.\n");
      return AVERROR_BUG;
    }
    av_audio_fifo_read(s.celt_delay, cast(void**)s.celt_output.ptr, nb_samples);
    for (i = 0; i < s.output_channels; i++) {
      vector_fmac_scalar(s.out_[i], s.celt_output[i], 1.0, nb_samples);
    }
  }

  if (s.redundancy_idx) {
    for (i = 0; i < s.output_channels; i++) {
      opus_fade(s.out_[i], s.out_[i], s.redundancy_output[i] + 120 + s.redundancy_idx, ff_celt_window2.ptr + s.redundancy_idx, 120 - s.redundancy_idx);
    }
    s.redundancy_idx = 0;
  }

  s.out_[0]   += nb_samples;
  s.out_[1]   += nb_samples;
  s.out_size -= nb_samples * float.sizeof;

  return 0;
}

static int opus_init_resample (OpusStreamContext* s) {
  float[16] delay = 0.0;
  const(float)*[2] delayptr = [ cast(immutable(float)*)delay.ptr, cast(immutable(float)*)delay.ptr ];
  float[128] odelay = void;
  float*[2] odelayptr = [ odelay.ptr, odelay.ptr ];
  int ret;

  if (s.flr.inited && s.flr.getInRate == s.silk_samplerate) {
    s.flr.reset();
  } else if (!s.flr.inited || s.flr.getChans != s.output_channels) {
    // use Voip(3) quality
    if (s.flr.setup(s.output_channels, s.silk_samplerate, 48000, 3) != s.flr.Error.OK) return AVERROR_BUG;
  } else {
    if (s.flr.setRate(s.silk_samplerate, 48000)  != s.flr.Error.OK) return AVERROR_BUG;
  }

  ret = s.flr.swrconvert(odelayptr.ptr, 128, delayptr.ptr, silk_resample_delay[s.packet.bandwidth]);
  if (ret < 0) {
    //av_log(s.avctx, AV_LOG_ERROR, "Error feeding initial silence to the resampler.\n");
    return AVERROR_BUG;
  }

  return 0;
}

static int opus_decode_redundancy (OpusStreamContext* s, const(uint8_t)* data, int size) {
  int ret;
  OpusBandwidth bw = s.packet.bandwidth;

  if (s.packet.mode == OPUS_MODE_SILK && bw == OPUS_BANDWIDTH_MEDIUMBAND) bw = OPUS_BANDWIDTH_WIDEBAND;

  ret = opus_rc_init(&s.redundancy_rc, data, size);
  if (ret < 0) goto fail;
  opus_raw_init(&s.redundancy_rc, data + size, size);

  ret = ff_celt_decode_frame(s.celt, &s.redundancy_rc, s.redundancy_output.ptr, s.packet.stereo + 1, 240, 0, celt_band_end[s.packet.bandwidth]);
  if (ret < 0) goto fail;

  return 0;
fail:
  //av_log(s.avctx, AV_LOG_ERROR, "Error decoding the redundancy frame.\n");
  return ret;
}

static int opus_decode_frame (OpusStreamContext* s, const(uint8_t)* data, int size) {
  import core.stdc.string : memcpy;
  int samples = s.packet.frame_duration;
  int redundancy = 0;
  int redundancy_size, redundancy_pos;
  int ret, i, consumed;
  int delayed_samples = s.delayed_samples;

  ret = opus_rc_init(&s.rc, data, size);
  if (ret < 0) return ret;

  //if (s.packet.mode != OPUS_MODE_CELT) assert(0);
  // decode the silk frame
  if (s.packet.mode == OPUS_MODE_SILK || s.packet.mode == OPUS_MODE_HYBRID) {
    if (!s.flr.inited) {
      ret = opus_init_resample(s);
      if (ret < 0) return ret;
    }
    //conwriteln("silk sr: ", s.silk_samplerate);

    samples = ff_silk_decode_superframe(s.silk, &s.rc, s.silk_output.ptr,
                                        FFMIN(s.packet.bandwidth, OPUS_BANDWIDTH_WIDEBAND),
                                        s.packet.stereo + 1,
                                        silk_frame_duration_ms[s.packet.config]);
    if (samples < 0) {
      //av_log(s.avctx, AV_LOG_ERROR, "Error decoding a SILK frame.\n");
      return samples;
    }
    //samples = swr_convert(s.swr, cast(uint8_t**)s.out_.ptr, s.packet.frame_duration, cast(const(uint8_t)**)s.silk_output.ptr, samples);
    immutable insamples = samples;
    samples = s.flr.swrconvert(cast(float**)s.out_.ptr, s.packet.frame_duration, cast(const(float)**)s.silk_output.ptr, samples);
    if (samples < 0) {
      //av_log(s.avctx, AV_LOG_ERROR, "Error resampling SILK data.\n");
      return samples;
    }
    //conwriteln("dcsamples: ", samples, "; outs=", s.packet.frame_duration, "; ins=", insamples);
    //k8???!!! assert((samples & 7) == 0);
    s.delayed_samples += s.packet.frame_duration - samples;
  } else {
    ff_silk_flush(s.silk);
  }

  // decode redundancy information
  consumed = opus_rc_tell(&s.rc);
  if (s.packet.mode == OPUS_MODE_HYBRID && consumed + 37 <= size * 8) redundancy = opus_rc_p2model(&s.rc, 12);
  else if (s.packet.mode == OPUS_MODE_SILK && consumed + 17 <= size * 8) redundancy = 1;

  if (redundancy) {
    redundancy_pos = opus_rc_p2model(&s.rc, 1);

    if (s.packet.mode == OPUS_MODE_HYBRID)
      redundancy_size = opus_rc_unimodel(&s.rc, 256) + 2;
    else
      redundancy_size = size - (consumed + 7) / 8;
    size -= redundancy_size;
    if (size < 0) {
      //av_log(s.avctx, AV_LOG_ERROR, "Invalid redundancy frame size.\n");
      return AVERROR_INVALIDDATA;
    }

    if (redundancy_pos) {
      ret = opus_decode_redundancy(s, data + size, redundancy_size);
      if (ret < 0) return ret;
      ff_celt_flush(s.celt);
    }
  }

  // decode the CELT frame
  if (s.packet.mode == OPUS_MODE_CELT || s.packet.mode == OPUS_MODE_HYBRID) {
    float*[2] out_tmp = [ s.out_[0], s.out_[1] ];
    float **dst = (s.packet.mode == OPUS_MODE_CELT ? out_tmp.ptr : s.celt_output.ptr);
    int celt_output_samples = samples;
    int delay_samples = av_audio_fifo_size(s.celt_delay);

    if (delay_samples) {
      if (s.packet.mode == OPUS_MODE_HYBRID) {
        av_audio_fifo_read(s.celt_delay, cast(void**)s.celt_output.ptr, delay_samples);

        for (i = 0; i < s.output_channels; i++) {
          vector_fmac_scalar(out_tmp[i], s.celt_output[i], 1.0, delay_samples);
          out_tmp[i] += delay_samples;
        }
        celt_output_samples -= delay_samples;
      } else {
        //av_log(s.avctx, AV_LOG_WARNING, "Spurious CELT delay samples present.\n");
        av_audio_fifo_drain(s.celt_delay, delay_samples);
        //if (s.avctx.err_recognition & AV_EF_EXPLODE) return AVERROR_BUG;
      }
    }

    opus_raw_init(&s.rc, data + size, size);

    ret = ff_celt_decode_frame(s.celt, &s.rc, dst,
                               s.packet.stereo + 1,
                               s.packet.frame_duration,
                               (s.packet.mode == OPUS_MODE_HYBRID) ? 17 : 0,
                               celt_band_end[s.packet.bandwidth]);
    if (ret < 0) return ret;

    if (s.packet.mode == OPUS_MODE_HYBRID) {
      int celt_delay = s.packet.frame_duration - celt_output_samples;
      void*[2] delaybuf = [ s.celt_output[0] + celt_output_samples,
                            s.celt_output[1] + celt_output_samples ];

      for (i = 0; i < s.output_channels; i++) {
        vector_fmac_scalar(out_tmp[i], s.celt_output[i], 1.0, celt_output_samples);
      }

      ret = av_audio_fifo_write(s.celt_delay, delaybuf.ptr, celt_delay);
      if (ret < 0) return ret;
    }
  } else {
    ff_celt_flush(s.celt);
  }

  if (s.redundancy_idx) {
    for (i = 0; i < s.output_channels; i++) {
      opus_fade(s.out_[i], s.out_[i],
                s.redundancy_output[i] + 120 + s.redundancy_idx,
                ff_celt_window2.ptr + s.redundancy_idx, 120 - s.redundancy_idx);
    }
    s.redundancy_idx = 0;
  }

  if (redundancy) {
    if (!redundancy_pos) {
      ff_celt_flush(s.celt);
      ret = opus_decode_redundancy(s, data + size, redundancy_size);
      if (ret < 0) return ret;

      for (i = 0; i < s.output_channels; i++) {
        opus_fade(s.out_[i] + samples - 120 + delayed_samples,
                  s.out_[i] + samples - 120 + delayed_samples,
                  s.redundancy_output[i] + 120,
                  ff_celt_window2.ptr, 120 - delayed_samples);
        if (delayed_samples)
            s.redundancy_idx = 120 - delayed_samples;
      }
    } else {
      for (i = 0; i < s.output_channels; i++) {
        memcpy(s.out_[i] + delayed_samples, s.redundancy_output[i], 120 * float.sizeof);
        opus_fade(s.out_[i] + 120 + delayed_samples,
                  s.redundancy_output[i] + 120,
                  s.out_[i] + 120 + delayed_samples,
                  ff_celt_window2.ptr, 120);
      }
    }
  }

  return samples;
}

static int opus_decode_subpacket (OpusStreamContext* s, const(uint8_t)* buf, int buf_size, float** out_, int out_size, int nb_samples) {
  import core.stdc.string : memset;
  int output_samples = 0;
  int flush_needed   = 0;
  int i, j, ret;

  s.out_[0]   = out_[0];
  s.out_[1]   = out_[1];
  s.out_size = out_size;

  /* check if we need to flush the resampler */
  if (s.flr.inited) {
    if (buf) {
      int64_t cur_samplerate = s.flr.getInRate;
      //av_opt_get_int(s.swr, "in_sample_rate", 0, &cur_samplerate);
      flush_needed = (s.packet.mode == OPUS_MODE_CELT) || (cur_samplerate != s.silk_samplerate);
    } else {
      flush_needed = !!s.delayed_samples;
    }
  }

  if (!buf && !flush_needed)
      return 0;

  /* use dummy output buffers if the channel is not mapped to anything */
  if (s.out_[0] is null ||
      (s.output_channels == 2 && s.out_[1] is null)) {
      av_fast_malloc(cast(void**)&s.out_dummy, &s.out_dummy_allocated_size, s.out_size);
      if (!s.out_dummy)
          return AVERROR(ENOMEM);
      if (!s.out_[0])
          s.out_[0] = s.out_dummy;
      if (!s.out_[1])
          s.out_[1] = s.out_dummy;
  }

  /* flush the resampler if necessary */
  if (flush_needed) {
      ret = opus_flush_resample(s, s.delayed_samples);
      if (ret < 0) {
          //av_log(s.avctx, AV_LOG_ERROR, "Error flushing the resampler.\n");
          return ret;
      }
      //swr_close(s.swr);
      s.flr.deinit();
      output_samples += s.delayed_samples;
      s.delayed_samples = 0;

      if (!buf)
          goto finish;
  }

  /* decode all the frames in the packet */
  for (i = 0; i < s.packet.frame_count; i++) {
      int size = s.packet.frame_size[i];
      int samples = opus_decode_frame(s, buf + s.packet.frame_offset[i], size);

      if (samples < 0) {
          //av_log(s.avctx, AV_LOG_ERROR, "Error decoding an Opus frame.\n");
          //if (s.avctx.err_recognition & AV_EF_EXPLODE) return samples;

          for (j = 0; j < s.output_channels; j++)
              memset(s.out_[j], 0, s.packet.frame_duration * float.sizeof);
          samples = s.packet.frame_duration;
      }
      output_samples += samples;

      for (j = 0; j < s.output_channels; j++)
          s.out_[j] += samples;
      s.out_size -= samples * float.sizeof;
  }

finish:
  s.out_[0] = s.out_[1] = null;
  s.out_size = 0;

  return output_samples;
}


// ////////////////////////////////////////////////////////////////////////// //
public int opus_decode_packet (/*AVCtx* avctx,*/ OpusContext* c, AVFrame* frame, int* got_frame_ptr, AVPacket* avpkt) {
  import core.stdc.string : memcpy, memset;
  //AVFrame *frame      = data;
  const(uint8_t)*buf  = avpkt.data;
  int buf_size        = avpkt.size;
  int coded_samples   = 0;
  int decoded_samples = int.max;
  int delayed_samples = 0;
  int i, ret;

  /*
  if (buf_size > 3) {
    import iv.vfs;
    auto fo = VFile("./zpkt.bin", "w");
    fo.rawWriteExact(buf[0..buf_size]);
    fo.close();
    assert(0);
  }
  */

  // calculate the number of delayed samples
  for (i = 0; i < c.nb_streams; i++) {
    OpusStreamContext *s = &c.streams[i];
    s.out_[0] = s.out_[1] = null;
    delayed_samples = FFMAX(delayed_samples, s.delayed_samples+av_audio_fifo_size(c.sync_buffers[i]));
  }

  // decode the header of the first sub-packet to find out the sample count
  if (buf !is null) {
    OpusPacket *pkt = &c.streams[0].packet;
    ret = ff_opus_parse_packet(pkt, buf, buf_size, c.nb_streams > 1);
    if (ret < 0) {
      //av_log(avctx, AV_LOG_ERROR, "Error parsing the packet header.\n");
      return ret;
    }
    coded_samples += pkt.frame_count * pkt.frame_duration;
    c.streams[0].silk_samplerate = get_silk_samplerate(pkt.config);
  }

  frame.nb_samples = coded_samples + delayed_samples;
  //conwriteln("frame samples: ", frame.nb_samples);

  /* no input or buffered data => nothing to do */
  if (!frame.nb_samples) {
    *got_frame_ptr = 0;
    return 0;
  }

  /* setup the data buffers */
  ret = ff_get_buffer(frame, 0);
  if (ret < 0) return ret;
  frame.nb_samples = 0;

  memset(c.out_, 0, c.nb_streams*2*(*c.out_).sizeof);
  for (i = 0; i < c.in_channels; i++) {
    ChannelMap *map = &c.channel_maps[i];
    //if (!map.copy) conwriteln("[", 2*map.stream_idx+map.channel_idx, "] = [", i, "]");
    if (!map.copy) c.out_[2*map.stream_idx+map.channel_idx] = cast(float*)frame.extended_data[i];
  }

  // read the data from the sync buffers
  for (i = 0; i < c.nb_streams; i++) {
    float** out_ = c.out_+2*i;
    int sync_size = av_audio_fifo_size(c.sync_buffers[i]);

    float[32] sync_dummy = void;
    int out_dummy = (!out_[0]) | ((!out_[1]) << 1);

    if (!out_[0]) out_[0] = sync_dummy.ptr;
    if (!out_[1]) out_[1] = sync_dummy.ptr;
    if (out_dummy && sync_size > /*FF_ARRAY_ELEMS*/sync_dummy.length) return AVERROR_BUG;

    ret = av_audio_fifo_read(c.sync_buffers[i], cast(void**)out_, sync_size);
    if (ret < 0) return ret;

    if (out_dummy & 1) out_[0] = null; else out_[0] += ret;
    if (out_dummy & 2) out_[1] = null; else out_[1] += ret;

    //conwriteln("ret=", ret);
    c.out_size[i] = frame.linesize[0]-ret*float.sizeof;
  }

  // decode each sub-packet
  for (i = 0; i < c.nb_streams; i++) {
    OpusStreamContext *s = &c.streams[i];
    if (i && buf) {
      ret = ff_opus_parse_packet(&s.packet, buf, buf_size, (i != c.nb_streams-1));
      if (ret < 0) {
        //av_log(avctx, AV_LOG_ERROR, "Error parsing the packet header.\n");
        return ret;
      }
      if (coded_samples != s.packet.frame_count * s.packet.frame_duration) {
        //av_log(avctx, AV_LOG_ERROR, "Mismatching coded sample count in substream %d.\n", i);
        return AVERROR_INVALIDDATA;
      }
      s.silk_samplerate = get_silk_samplerate(s.packet.config);
    }

    ret = opus_decode_subpacket(&c.streams[i], buf, s.packet.data_size, c.out_+2*i, c.out_size[i], coded_samples);
    if (ret < 0) return ret;
    c.decoded_samples[i] = ret;
    decoded_samples = FFMIN(decoded_samples, ret);

    buf += s.packet.packet_size;
    buf_size -= s.packet.packet_size;
  }

  // buffer the extra samples
  for (i = 0; i < c.nb_streams; i++) {
    int buffer_samples = c.decoded_samples[i]-decoded_samples;
    if (buffer_samples) {
      float*[2] buff = [ c.out_[2 * i + 0] ? c.out_[2 * i + 0] : cast(float*)frame.extended_data[0],
                         c.out_[2 * i + 1] ? c.out_[2 * i + 1] : cast(float*)frame.extended_data[0] ];
      buff[0] += decoded_samples;
      buff[1] += decoded_samples;
      ret = av_audio_fifo_write(c.sync_buffers[i], cast(void**)buff.ptr, buffer_samples);
      if (ret < 0) return ret;
    }
  }

  for (i = 0; i < c.in_channels; i++) {
    ChannelMap *map = &c.channel_maps[i];
    // handle copied channels
    if (map.copy) {
      memcpy(frame.extended_data[i], frame.extended_data[map.copy_idx], frame.linesize[0]);
    } else if (map.silence) {
      memset(frame.extended_data[i], 0, frame.linesize[0]);
    }
    if (c.gain_i && decoded_samples > 0) {
      vector_fmul_scalar(cast(float*)frame.extended_data[i], cast(float*)frame.extended_data[i], c.gain, /*FFALIGN(decoded_samples, 8)*/decoded_samples);
    }
  }

  //frame.nb_samples = decoded_samples;
  *got_frame_ptr = !!decoded_samples;

  //return /*avpkt.size*/datasize;
  return decoded_samples;
}


public void opus_decode_flush (OpusContext* c) {
  import core.stdc.string : memset;
  for (int i = 0; i < c.nb_streams; i++) {
    OpusStreamContext *s = &c.streams[i];

    memset(&s.packet, 0, s.packet.sizeof);
    s.delayed_samples = 0;

    if (s.celt_delay) av_audio_fifo_drain(s.celt_delay, av_audio_fifo_size(s.celt_delay));
    //swr_close(s.swr);
    s.flr.deinit();

    av_audio_fifo_drain(c.sync_buffers[i], av_audio_fifo_size(c.sync_buffers[i]));

    ff_silk_flush(s.silk);
    ff_celt_flush(s.celt);
  }
}

public int opus_decode_close (OpusContext* c) {
  int i;

  for (i = 0; i < c.nb_streams; i++) {
    OpusStreamContext *s = &c.streams[i];

    ff_silk_free(&s.silk);
    ff_celt_free(&s.celt);

    av_freep(&s.out_dummy);
    s.out_dummy_allocated_size = 0;

    av_audio_fifo_free(s.celt_delay);
    //swr_free(&s.swr);
    s.flr.deinit();
  }

  av_freep(&c.streams);

  if (c.sync_buffers) {
    for (i = 0; i < c.nb_streams; i++) av_audio_fifo_free(c.sync_buffers[i]);
  }
  av_freep(&c.sync_buffers);
  av_freep(&c.decoded_samples);
  av_freep(&c.out_);
  av_freep(&c.out_size);

  c.nb_streams = 0;

  av_freep(&c.channel_maps);
  //av_freep(&c.fdsp);

  return 0;
}

public int opus_decode_init (AVCtx* avctx, OpusContext* c) {
  int ret, i, j;

  avctx.sample_fmt  = AV_SAMPLE_FMT_FLTP;
  avctx.sample_rate = 48000;

  //c.fdsp = avpriv_float_dsp_alloc(0);
  //if (!c.fdsp) return AVERROR(ENOMEM);

  // find out the channel configuration
  ret = ff_opus_parse_extradata(avctx, c);
  if (ret < 0) {
    av_freep(&c.channel_maps);
    //av_freep(&c.fdsp);
    return ret;
  }
  c.in_channels = avctx.channels;

  conwriteln("c.nb_streams=", c.nb_streams);
  conwriteln("chans=", c.in_channels);
  // allocate and init each independent decoder
  c.streams = av_mallocz_array!(typeof(c.streams[0]))(c.nb_streams);
  c.out_ = av_mallocz_array!(typeof(c.out_[0]))(c.nb_streams * 2);
  c.out_size = av_mallocz_array!(typeof(c.out_size[0]))(c.nb_streams);
  c.sync_buffers = av_mallocz_array!(typeof(c.sync_buffers[0]))(c.nb_streams);
  c.decoded_samples = av_mallocz_array!(typeof(c.decoded_samples[0]))(c.nb_streams);
  if (c.streams is null || c.sync_buffers is null || c.decoded_samples is null || c.out_ is null || c.out_size is null) {
    c.nb_streams = 0;
    ret = AVERROR(ENOMEM);
    goto fail;
  }

  for (i = 0; i < c.nb_streams; i++) {
    OpusStreamContext *s = &c.streams[i];
    uint64_t layout;

    s.output_channels = (i < c.nb_stereo_streams) ? 2 : 1;
    conwriteln("stream #", i, "; chans: ", s.output_channels);

    //s.avctx = avctx;

    for (j = 0; j < s.output_channels; j++) {
      s.silk_output[j] = s.silk_buf[j].ptr;
      s.celt_output[j] = s.celt_buf[j].ptr;
      s.redundancy_output[j] = s.redundancy_buf[j].ptr;
    }

    //s.fdsp = c.fdsp;
    layout = (s.output_channels == 1) ? AV_CH_LAYOUT_MONO : AV_CH_LAYOUT_STEREO;

    /+
    s.swr = swr_alloc();
    if (!s.swr) goto fail;

    /*
    av_opt_set_int(s.swr, "in_sample_fmt",      avctx.sample_fmt,  0);
    av_opt_set_int(s.swr, "out_sample_fmt",     avctx.sample_fmt,  0);
    av_opt_set_int(s.swr, "in_channel_layout",  layout,             0);
    av_opt_set_int(s.swr, "out_channel_layout", layout,             0);
    av_opt_set_int(s.swr, "out_sample_rate",    avctx.sample_rate, 0);
    av_opt_set_int(s.swr, "filter_size",        16,                 0);
    */
    +/
    /*
    s.swr = swr_alloc_set_opts(null,
      layout, // out_ch_layout
      AV_SAMPLE_FMT_FLTP, // out_sample_fmt
      avctx.sample_rate, // out_sample_rate
      layout, // in_ch_layout
      AV_SAMPLE_FMT_FLTP, // in_sample_fmt
      avctx.sample_rate, // in_sample_rate
      0, null);

    conwriteln("in_sample_fmt     : ", avctx.sample_fmt);
    conwriteln("out_sample_fmt    : ", avctx.sample_fmt);
    conwriteln("in_channel_layout : ", layout);
    conwriteln("out_channel_layout: ", layout);
    conwriteln("out_sample_rate   : ", avctx.sample_rate);
    conwriteln("filter_size       : ", 16);
    */

    ret = ff_silk_init(/*avctx, */&s.silk, s.output_channels);
    if (ret < 0) goto fail;

    ret = ff_celt_init(/*avctx, */&s.celt, s.output_channels);
    if (ret < 0) goto fail;

    s.celt_delay = av_audio_fifo_alloc(avctx.sample_fmt, s.output_channels, 1024);
    if (!s.celt_delay) {
      ret = AVERROR(ENOMEM);
      goto fail;
    }

    c.sync_buffers[i] = av_audio_fifo_alloc(avctx.sample_fmt, s.output_channels, 32);
    if (!c.sync_buffers[i]) {
      ret = AVERROR(ENOMEM);
      goto fail;
    }
  }

  return 0;
fail:
  opus_decode_close(/*avctx*/c);
  return ret;
}


public int opus_decode_init_ll (OpusContext* c) {
  int channels = 2;
  c.gain_i = 0;
  c.gain = 0;
  c.nb_streams = 1;
  c.nb_stereo_streams = 1;
  c.in_channels = channels;
  c.channel_maps = av_mallocz_array!(typeof(c.channel_maps[0]))(channels);
  if (c.channel_maps is null) return AVERROR(ENOMEM);
  c.channel_maps[0].stream_idx = 0;
  c.channel_maps[0].channel_idx = 0;
  c.channel_maps[1].stream_idx = 0;
  c.channel_maps[1].channel_idx = 1;

  conwriteln("c.nb_streams=", c.nb_streams);
  // allocate and init each independent decoder
  c.streams = av_mallocz_array!(typeof(c.streams[0]))(c.nb_streams);
  c.out_ = av_mallocz_array!(typeof(c.out_[0]))(c.nb_streams * 2);
  c.out_size = av_mallocz_array!(typeof(c.out_size[0]))(c.nb_streams);
  c.sync_buffers = av_mallocz_array!(typeof(c.sync_buffers[0]))(c.nb_streams);
  c.decoded_samples = av_mallocz_array!(typeof(c.decoded_samples[0]))(c.nb_streams);
  if (c.streams is null || c.sync_buffers is null || c.decoded_samples is null || c.out_ is null || c.out_size is null) {
    c.nb_streams = 0;
    opus_decode_close(c);
    return AVERROR(ENOMEM);
  }

  foreach (immutable i; 0..c.nb_streams) {
    OpusStreamContext *s = &c.streams[i];
    uint64_t layout;

    s.output_channels = (i < c.nb_stereo_streams ? 2 : 1);
    conwriteln("stream #", i, "; chans: ", s.output_channels);

    foreach (immutable j; 0..s.output_channels) {
      s.silk_output[j] = s.silk_buf[j].ptr;
      s.celt_output[j] = s.celt_buf[j].ptr;
      s.redundancy_output[j] = s.redundancy_buf[j].ptr;
    }

    layout = (s.output_channels == 1) ? AV_CH_LAYOUT_MONO : AV_CH_LAYOUT_STEREO;

    /+
    s.swr = swr_alloc_set_opts(null,
      layout, // out_ch_layout
      AV_SAMPLE_FMT_FLTP, // out_sample_fmt
      48000, // out_sample_rate
      layout, // in_ch_layout
      AV_SAMPLE_FMT_FLTP, // in_sample_fmt
      48000, // in_sample_rate
      0, null);
    +/

    if (ff_silk_init(/*avctx, */&s.silk, s.output_channels) < 0) {
      opus_decode_close(c);
      return AVERROR(ENOMEM);
    }

    if (ff_celt_init(/*avctx, */&s.celt, s.output_channels) < 0) {
      opus_decode_close(c);
      return AVERROR(ENOMEM);
    }

    s.celt_delay = av_audio_fifo_alloc(AV_SAMPLE_FMT_FLTP, s.output_channels, 1024);
    if (!s.celt_delay) {
      opus_decode_close(c);
      return AVERROR(ENOMEM);
    }

    c.sync_buffers[i] = av_audio_fifo_alloc(AV_SAMPLE_FMT_FLTP, s.output_channels, 32);
    if (!c.sync_buffers[i]) {
      opus_decode_close(c);
      return AVERROR(ENOMEM);
    }
  }

  return 0;
}
