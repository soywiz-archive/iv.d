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
enum FileName = "/tmp/03/melodie_128.opus";


__gshared snd_pcm_t* pcm;


void alsaOpen (int chans) {
  int err;
  if ((err = snd_pcm_open(&pcm, "plug:default", SND_PCM_STREAM_PLAYBACK, 0)) < 0) {
    import core.stdc.stdio : printf;
    import core.stdc.stdlib : exit, EXIT_FAILURE;
    printf("Playback open error: %s\n", snd_strerror(err));
    exit(EXIT_FAILURE);
  }

  if ((err = snd_pcm_set_params(pcm, SND_PCM_FORMAT_S16_LE, SND_PCM_ACCESS_RW_INTERLEAVED, chans, 48000, 1, 500000)) < 0) {
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


void alsaWrite (ubyte** eptr, int chans, uint frms) {
  static short[4096] buf;
  auto sptr = cast(float**)eptr;
  while (frms > 0) {
    uint len = cast(uint)buf.length;
    if (len > frms) len = frms;
    uint dpos = 0;
    foreach (immutable pos; 0..len) {
      foreach (immutable chn; 0..chans) {
        //assert(*sptr[chn] >= -1.0f && *sptr[chn] <= 1.0f);
        buf[dpos++] = cast(short)((*sptr[chn]++)*32767.0f);
      }
    }
    dpos = 0;
    while (dpos < len) {
      snd_pcm_sframes_t frames = snd_pcm_writei(pcm, buf.ptr+dpos*chans, len-dpos);
      if (frames < 0) {
        frames = snd_pcm_recover(pcm, cast(int)frames, 0);
      } else if (frames < 0) {
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
import iv.encoding;

void main (string[] args) {
  if (args.length == 1) args ~= FileName;

  AVCtx ctx;
  OpusContext c;

  OggStream ogg;
  ogg.setup(VFile(args[1]));

  for (;;) {
    auto r = opus_header(&ctx, ogg);
    if (r < 0) assert(0);
    if (!ogg.loadPacket()) assert(0);
    if (r == 1) break;
  }

  if (opus_decode_init(&ctx, &c) < 0) assert(0, "fuuuuu");
  scope(exit) opus_decode_close(&c);
  assert(c.nb_streams == 1);
  assert(c.streams[0].output_channels >= 1 && c.streams[0].output_channels <= 2);

  enum outsize = 8192*float.sizeof;
  foreach (immutable chn; 0..c.streams[0].output_channels) {
    conwriteln("output buf for chan #", chn);
    //c.streams.out_[chn] = av_mallocz!float(8192);
  }

  float[][2] obuf;
  foreach (ref obb; obuf[]) obb.length = outsize;
  ubyte*[2] eptr;
  ulong packets, frames;

  version(noplay) {} else alsaOpen(c.streams[0].output_channels);
  version(noplay) {} else scope(exit) alsaClose();

  for (;;) {
    auto r = opus_packet(&ctx, ogg);
    if (r < 0) break;

    //conwriteln("packet #", packets, "; frame #", frames);
    AVFrame frame;
    AVPacket pkt;
    frame.linesize[0] = outsize;
    pkt.data = ogg.packetData.ptr;
    pkt.size = cast(uint)ogg.packetLength;
    foreach (immutable idx, ref obb; obuf[]) eptr[idx] = cast(ubyte*)(obb.ptr);
    frame.extended_data = eptr.ptr;
    //c.streams.out_size = outsize;
    int gotfrptr = 0;
    r = opus_decode_packet(&ctx, &c, &frame, &gotfrptr, &pkt);
    if (r < 0) {
      conwriteln("can't process packet #", packets);
      assert(0);
    }
    if (gotfrptr) ++frames;
    //conwriteln("  ", c.streams.out_size);
    //conwriteln("dc=", r);
    version(noplay) {} else alsaWrite(eptr.ptr, c.streams[0].output_channels, r);

    ++packets;
    if (!ogg.loadPacket()) break;
  }
  conwriteln(packets, " opus packets, ", frames, " frames found");
}
