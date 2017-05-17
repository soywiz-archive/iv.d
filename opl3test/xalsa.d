module xalsa /*is aliced*/;

import iv.alice;
import iv.alsa;
import iv.follin.utils;


// ////////////////////////////////////////////////////////////////////////// //
__gshared snd_pcm_t* pcm;


enum Rate = 48000;
__gshared uint Chans = 2;


// ////////////////////////////////////////////////////////////////////////// //
void alsaOpen (int chans=-1) {
  if (chans >= 0) {
    if (chans < 1 || chans > 2) assert(0, "fuck");
    Chans = chans;
  }
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


// ////////////////////////////////////////////////////////////////////////// //
void alsaClose () {
  if (pcm !is null) {
    snd_pcm_close(pcm);
    pcm = null;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
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


// ////////////////////////////////////////////////////////////////////////// //
void alsaWrite2B (ubyte** eptr, uint frms) {
  static float[4096] fbuf;
  static short[4096] sbuf;
  auto fptr = cast(float**)eptr;
  while (frms > 0) {
    uint len = cast(uint)(fbuf.length/Chans);
    if (len > frms) len = frms;
    uint dpos = 0;
    foreach (immutable pos; 0..len) {
      foreach (immutable chn; 0..Chans) {
        //assert(*sptr[chn] >= -1.0f && *sptr[chn] <= 1.0f);
        fbuf[dpos++] = *fptr[chn]++;
      }
    }
    tflFloat2Short(fbuf[0..dpos], sbuf[0..dpos]);
    dpos = 0;
    while (dpos < len) {
      snd_pcm_sframes_t frames = snd_pcm_writei(pcm, sbuf.ptr+dpos*Chans, len-dpos);
      if (frames < 0) {
        frames = snd_pcm_recover(pcm, cast(int)frames, 0);
        import core.stdc.stdio : printf;
        import core.stdc.stdlib : exit, EXIT_FAILURE;
        printf("snd_pcm_writei failed: %s\n", snd_strerror(cast(int)frames));
        exit(EXIT_FAILURE);
      } else {
        frms -= frames;
        dpos += frames*Chans;
      }
    }
  }
}
