module tinysid;

import iv.cmdcon;
import iv.simplealsa;
import iv.vfs;

import sidengine;


// ////////////////////////////////////////////////////////////////////////// //
enum BUF_SIZE = 882; // Audio Buffer size, in samples

__gshared short[BUF_SIZE*16] soundbuffer; // the soundbuffer


// ////////////////////////////////////////////////////////////////////////// //
void main (string[] args) {
  if (args.length != 2) {
    conwriteln("TinySID v0.94");
    conwriteln("(c)Copyright 1999-2006 T. Hinrichs and R. Sinsch.");
    conwriteln("All rights reserved.");
    return;
  }

  c64Init();

  if (!alsaInit(44100, 1)) assert(0, "error initializing ALSA");
  scope(exit) alsaShutdown(true);

  conwriteln("ALSA initialized; real sampling rate is ", alsaRealRate, "Hz");

  conwriteln("Loading '", args[1], "'...");
  SidSong song;
  c64SidLoad(VFile(args[1]), song);

  conwriteln("TITLE    : ", song.name);
  conwriteln("AUTHOR   : ", song.author);
  conwriteln("COPYRIGHT: ", song.copyright);

  cpuJSR(song.init_addr, song.sub_song_start);
  conwriteln("Playing... Hit ^C to quit.");
  //start_playing(play_addr, play_speed);

  ushort play_addr = song.play_addr;
  ubyte play_speed = song.speed;

  bool playing = true;
  while (playing) {
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
  }
}
