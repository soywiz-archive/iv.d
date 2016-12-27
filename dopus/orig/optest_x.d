import avmem;
import avfft;
import opus;
import opus_celt;
import opus_silk;
import opusdec;
import swresample;
import zogg;

import iv.alsa;
import iv.cmdcon;
import iv.vfs;


//version = noplay;

//enum FileName = "/tmp/03/linda_karandashi_i_spichki.opus";
//enum FileName = "/tmp/03/melodie_128.opus";
enum FileName = "z00.raw";


__gshared snd_pcm_t* pcm;


enum Rate = 48000;
enum Chans = 2;


void alsaOpen () {
  int err;
  if ((err = snd_pcm_open(&pcm, "plug:default", SND_PCM_STREAM_PLAYBACK, 0)) < 0) {
    import core.stdc.stdio : printf;
    import core.stdc.stdlib : exit, EXIT_FAILURE;
    printf("Playback open error: %s\n", snd_strerror(err));
    exit(EXIT_FAILURE);
  }

  if ((err = snd_pcm_set_params(pcm, SND_PCM_FORMAT_S16_LE, SND_PCM_ACCESS_RW_INTERLEAVED, Chans, Rate, 1, 500000)) < 0) {
    import core.stdc.stdio : printf;
    import core.stdc.stdlib : exit, EXIT_FAILURE;
    printf("Playback open error: %s\n", snd_strerror(err));
    exit(EXIT_FAILURE);
  }
}


void alsaClose () {
  if (pcm !is null) {
    snd_pcm_close(pcm);
    pcm = null;
  }
}


void alsaWriteX (short* sptr, uint frms) {
  while (frms > 0) {
    snd_pcm_sframes_t frames = snd_pcm_writei(pcm, sptr, frms);
    if (frames < 0) {
      frames = snd_pcm_recover(pcm, cast(int)frames, 0);
      if (frames < 0) {
        import core.stdc.stdio : printf;
        import core.stdc.stdlib : exit, EXIT_FAILURE;
        printf("snd_pcm_writei failed: %s\n", snd_strerror(cast(int)frames));
        exit(EXIT_FAILURE);
      }
    } else {
      frms -= frames;
      sptr += frames*Chans;
    }
  }
}


void alsaWrite2B (ubyte** eptr, uint frms) {
  static short[4096] buf;
  auto sptr = cast(float**)eptr;
  while (frms > 0) {
    uint len = cast(uint)buf.length;
    if (len > frms) len = frms;
    uint dpos = 0;
    foreach (immutable pos; 0..len) {
      foreach (immutable chn; 0..Chans) {
        //assert(*sptr[chn] >= -1.0f && *sptr[chn] <= 1.0f);
        buf[dpos++] = cast(short)((*sptr[chn]++)*32767.0f);
      }
    }
    dpos = 0;
    while (dpos < len) {
      snd_pcm_sframes_t frames = snd_pcm_writei(pcm, buf.ptr+dpos*Chans, len-dpos);
      if (frames < 0) {
        frames = snd_pcm_recover(pcm, cast(int)frames, 0);
        import core.stdc.stdio : printf;
        import core.stdc.stdlib : exit, EXIT_FAILURE;
        printf("snd_pcm_writei failed: %s\n", snd_strerror(cast(int)frames));
        exit(EXIT_FAILURE);
      } else {
        frms -= frames;
        dpos += frames;
      }
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
void main (string[] args) {
  if (args.length == 1) args ~= FileName;

  OpusContext c;

  auto fl = VFile(args[1]);

  if (opus_decode_init_ll(&c) < 0) assert(0, "fuuuuu");

  enum outsize = 48000*2;
  foreach (immutable chn; 0..c.streams[0].output_channels) {
    conwriteln("output buf for chan #", chn);
    c.streams.out_[chn] = av_mallocz!float(48000);
  }

  short[] sbuf;
  sbuf.length = Rate*4;

  float[][2] obuf;
  foreach (ref obb; obuf[]) obb.length = outsize;
  ubyte*[2] eptr;
  ulong packets, frames;

  version(noplay) {} else alsaOpen();
  version(noplay) {} else scope(exit) alsaClose();

  ubyte[] data;
  for (;;) {
    uint pklen;
    try { pklen = fl.readNum!(uint, "BE"); } catch (Exception) break;
    fl.readNum!uint; // final range state
    //conwriteln("packet length: ", pklen);
    if (data.length < pklen) data.length = pklen;
    fl.rawReadExact(data[0..pklen]);

    //conwriteln("packet #", packets, "; frame #", frames);
    AVFrame frame;
    AVPacket pkt;
    frame.linesize[0] = outsize;
    pkt.data = data.ptr;
    pkt.size = pklen;
    foreach (immutable idx, ref obb; obuf[]) eptr[idx] = cast(ubyte*)(obb.ptr);
    frame.extended_data = eptr.ptr;
    //c.streams.out_size = outsize;
    int gotfrptr = 0;
    int r = opus_decode_packet(&c, &frame, &gotfrptr, &pkt);
    if (r < 0) {
      conwriteln("can't process packet #", packets);
      assert(0);
    }
    if (gotfrptr) {
      ++frames;
      //assert(0);
    }
    //conwriteln("  ", c.streams.out_size);
    //conwriteln("dc=", r);

    //err = opus_decode(dc, data.ptr, pklen, sbuf.ptr, sbuf.length/2, 0);
    //if (err < 0) assert(0, opus_strerr(err).idup);

    //conwrite("\rpacket length: ", pklen, "; samples: ", opus_decoder_get_nb_samples(dc, data.ptr, pklen), " (", err, "); chans=", opus_packet_get_nb_channels(dc), "\e[K");

    //conwriteln("  ", c.streams.out_size);
    //conwriteln("samples=", err);
    //version(noplay) {} else alsaWrite2B(sbuf.ptr, r);
    version(noplay) {} else alsaWrite2B(eptr.ptr, r);

    ++packets;
  }
  conwriteln("\n", packets, " opus packets found");
}
