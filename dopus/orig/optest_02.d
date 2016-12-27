import iv.libopus;
import zogg;

import iv.alsa;
import iv.cmdcon;
import iv.vfs;


//version = noplay;

//enum FileName = "/tmp/03/linda_karandashi_i_spichki.opus";
enum FileName = "/tmp/03/melodie_128.opus";
//enum FileName = "z00.raw";


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


// ////////////////////////////////////////////////////////////////////////// //
import iv.encoding;

void main (string[] args) {
  if (args.length == 1) args ~= FileName;

  OggStream ogg;
  ogg.setup(VFile(args[1]));

  if (!ogg.loadPacket()) assert(0); // comments

  int err;
  OpusDecoder* dc = opus_decoder_create(Rate, Chans, &err);
  if (err != OPUS_OK) assert(0, opus_strerr(err).idup);
  scope(exit) opus_decoder_destroy(dc);

  short[] sbuf;
  sbuf.length = Rate*2;

  ulong packets;

  version(noplay) {} else alsaOpen();
  version(noplay) {} else scope(exit) alsaClose();

  for (;;) {
    if (!ogg.loadPacket()) break;

    err = opus_decode(dc, ogg.packetData.ptr, ogg.packetLength, sbuf.ptr, sbuf.length/2, 0);
    if (err < 0) assert(0, opus_strerr(err).idup);

    if (ogg.packetLength > 128) {
      auto fo = VFile("./zpkt.bin", "w");
      fo.rawWriteExact(ogg.packetData[0..ogg.packetLength]);
      fo.close();
      return;
    }

    //conwrite("\rpacket length: ", ogg.packetLength, "; samples: ", opus_decoder_get_nb_samples(dc, ogg.packetData.ptr, ogg.packetLength), " (", err, "); chans=", opus_packet_get_nb_channels(dc), "\e[K");

    //conwriteln("  ", c.streams.out_size);
    //conwriteln("samples=", err);
    version(noplay) {} else alsaWriteX(sbuf.ptr, err);

    ++packets;
  }
  conwriteln("\n", packets, " opus packets found");
}
