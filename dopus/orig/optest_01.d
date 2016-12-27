import iv.libopus;
import zogg;

import iv.alsa;
import iv.cmdcon;
import iv.vfs;


//version = noplay;

//enum FileName = "/tmp/03/linda_karandashi_i_spichki.opus";
//enum FileName = "/tmp/03/melodie_128.opus";
enum FileName = "z00.x";


__gshared snd_pcm_t* pcm;


enum Rate = 48000;


void alsaOpen (int chans) {
  int err;
  if ((err = snd_pcm_open(&pcm, "plug:default", SND_PCM_STREAM_PLAYBACK, 0)) < 0) {
    import core.stdc.stdio : printf;
    import core.stdc.stdlib : exit, EXIT_FAILURE;
    printf("Playback open error: %s\n", snd_strerror(err));
    exit(EXIT_FAILURE);
  }

  if ((err = snd_pcm_set_params(pcm, SND_PCM_FORMAT_S16_LE, SND_PCM_ACCESS_RW_INTERLEAVED, chans, Rate, 1, 500000)) < 0) {
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


void alsaWriteX (short* sptr, int chans, uint frms) {
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
      sptr += frames*chans;
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
import iv.encoding;

void main (string[] args) {
  if (args.length == 1) args ~= FileName;

  auto fl = VFile(args[1]);

  enum Chans = 2;

  int err;
  OpusDecoder* dc = opus_decoder_create(Rate, Chans, &err);
  if (err != OPUS_OK) assert(0, opus_strerr(err).idup);
  scope(exit) opus_decoder_destroy(dc);

  short[] sbuf;
  sbuf.length = OpusMaxFrameDurationMS*2*Rate/1000+1024*2;

  ulong packets;

  version(noplay) {} else alsaOpen(1);
  version(noplay) {} else scope(exit) alsaClose();

  ubyte[] data;
  for (;;) {
    auto rd = fl.rawRead(sbuf[]);

    version(noplay) {} else alsaWriteX(sbuf.ptr, Chans, rd.length/Chans);

    ++packets;
  }
  conwriteln("\n", packets, " opus packets found");
}
