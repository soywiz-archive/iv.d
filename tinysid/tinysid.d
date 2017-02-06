module tinysid;

import core.time;

import iv.cmdcon;
import iv.cmdcontty;
import iv.follin.resampler;
import iv.follin.utils;
import iv.simplealsa;
import iv.rawtty;
import iv.vfs;

import sidengine;


// ////////////////////////////////////////////////////////////////////////// //
enum BUF_SIZE = 882; // Audio Buffer size, in samples

__gshared short[BUF_SIZE*16] soundbuffer; // the soundbuffer
__gshared SpeexResampler rsm;


// ////////////////////////////////////////////////////////////////////////// //
void main (string[] args) {
  if (args.length < 2) {
    conwriteln("TinySID v0.94");
    conwriteln("(c)Copyright 1999-2006 T. Hinrichs and R. Sinsch.");
    conwriteln("All rights reserved.");
    return;
  }

  if (ttyIsRedirected) assert(0, "no redirects, please!");

  concmd("exec tinysid.rc tan");
  conProcessQueue(); // load config
  conProcessArgs!true(args);

  ttySetRaw();
  scope(exit) ttySetNormal();
  ttyconInit();

  alsaDevice = "plug:default";

  float[] rsfbufi, rsfbufo;

  int idx = 1;
  mainloop: while (idx < args.length) {
    string fname = args[idx];

    auto fl = VFile(fname);
    ubyte speed = c64SidGetSpeed(fl);

    c64Init(/*speed == 1*/);

    if (!alsaInit(44100, 1)) assert(0, "error initializing ALSA");
    scope(exit) alsaShutdown(true);

    conwriteln("ALSA initialized; real sampling rate is ", alsaRealRate, "Hz");

    conwriteln("Loading '", args[1], "'...");
    SidSong song;
    c64SidLoad(fl, song);

    conwriteln("TITLE    : ", song.name);
    conwriteln("AUTHOR   : ", song.author);
    conwriteln("COPYRIGHT: ", song.copyright);
    conwriteln("SPEED    : ", speed);

    cpuJSR(song.init_addr, song.sub_song_start);
    //conwriteln("Playing... Hit ^C to quit.");

    ushort play_addr = song.play_addr;
    ubyte play_speed = song.speed;

    //conwriteln("SPEED    : ", play_speed);

    auto stt = MonoTime.currTime;
    auto stu = MonoTime.zero;
    uint msecs = 0;

    bool playing = true;
    bool paused = false;

    if (speed == 1) {
      rsm.setup(1, 44100*2, 44100, 8);
    }

    while (playing) {
      if (!paused) {
        if (play_speed == 0) {
          // Single Speed (50Hz); render 16*50Hz buffer
          foreach (immutable j; 0..8) {
            cpuJSR(play_addr, 0);
            synth_render(&soundbuffer[BUF_SIZE*j], BUF_SIZE);
          }
        } else if (play_speed == 1) {
          // Double Speed (100Hz); render 16*50Hz buffer
          foreach (immutable j; 0..16) {
            cpuJSR(play_addr, 0);
            synth_render(&soundbuffer[BUF_SIZE/2*j], BUF_SIZE/2);
          }
        } else {
          assert(0, "invalid playing speed");
        }
        alsaWriteShort(soundbuffer[0..BUF_SIZE*8]); // mono
        /*
        foreach (immutable j; 0..8) {
          cpuJSR(play_addr, 0);
          synth_render(&soundbuffer[BUF_SIZE*j], BUF_SIZE);
        }
        if (speed == 1) {
          // oops, must resample
          SpeexResampler.Data srbdata;
          if (rsfbufi.length < BUF_SIZE*8) rsfbufi.length = BUF_SIZE*8;
          if (rsfbufo.length < BUF_SIZE*8) rsfbufo.length = BUF_SIZE*8;
          tflShort2Float(soundbuffer[0..BUF_SIZE*8], rsfbufi[0..BUF_SIZE*8]);
          uint inpos = 0;
          for (;;) {
            srbdata = srbdata.init; // just in case
            srbdata.dataIn = rsfbufi[inpos..BUF_SIZE*8];
            srbdata.dataOut = rsfbufo[];
            if (rsm.process(srbdata) != 0) assert(0, "resampling error");
            if (srbdata.outputSamplesUsed) {
              tflFloat2Short(rsfbufo[0..srbdata.outputSamplesUsed], soundbuffer[0..srbdata.outputSamplesUsed]);
              //outSoundFlushX(b, srbdata.outputSamplesUsed*2);
              //conwriteln("RSM: ", srbdata.outputSamplesUsed);
              alsaWriteShort(soundbuffer[0..srbdata.outputSamplesUsed]); // mono
            } else {
              // no data consumed, no data produced, so we're done
              if (inpos >= BUF_SIZE*8) break;
            }
            inpos += cast(uint)srbdata.inputSamplesUsed;
          }
        } else {
          alsaWriteShort(soundbuffer[0..BUF_SIZE*8]); // mono
        }
        */
      } else {
        soundbuffer[0..BUF_SIZE*8] = 0;
        alsaWriteShort(soundbuffer[0..BUF_SIZE*8]); // mono
      }

      while (ttyIsKeyHit) {
        auto key = ttyReadKey(0, 20);
        if (!ttyconEvent(key)) {
          switch (key.key) {
            case TtyEvent.Key.Char:
              if (key.ch == '<') { if (idx > 1) { ttyRawWrite("\n"); --idx; continue mainloop; } }
              if (key.ch == '>') { ttyRawWrite("\n"); ++idx; continue mainloop; }
              if (key.ch == 'q') { ttyRawWrite("\n"); break mainloop; }
              if (key.ch == ' ') {
                paused = !paused;
                auto ctt = MonoTime.currTime;
                if (paused) {
                  auto cms = (ctt-stt).total!"msecs"+msecs;
                  msecs = cast(uint)cms;
                }
                stt = ctt;
              }
              break;
            default: break;
          }
        }
      }

      {
        auto ctt = MonoTime.currTime;
        auto cms = (ctt-stt).total!"msecs"+msecs;
        if (cms >= 2*60*1000) break;
        if ((ctt-stu).total!"seconds" >= 1) {
          import core.stdc.stdio : snprintf;
          stu = ctt;
          char[512] tmp;
          auto len = snprintf(tmp.ptr, tmp.length, "\r%02u:%02u", cast(uint)(cms/1000/60), cast(uint)(cms/1000%60));
          ttyRawWrite(tmp[0..len]);
        }
      }
    }
    ttyRawWrite("\n");

    ++idx;
  }
}
