// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
import iv.cmdcon;
import iv.vfs;
import iv.vfs.io;

import iv.nukedopl3;
import xalsa;


////////////////////////////////////////////////////////////////////////////////
__gshared OPLPlayer player;
__gshared short[4096] smpbuf;
__gshared uint smpbufpos;


void playbuf () {
  if (smpbufpos == 0) return;
  foreach (ref short v; smpbuf[0..smpbufpos]) {
    int n = v*4;
    if (n < short.min) n = short.min;
    if (n > short.max) n = short.max;
    v = cast(short)n;
  }
  alsaWriteX(smpbuf.ptr, smpbufpos/2);
  smpbufpos = 0;
}


void main (string[] args) {
  bool useOPL3 = true;
  string filename = null;
  bool nomore = false;
  foreach (string a; args[1..$]) {
    if (nomore) {
      if (filename !is null) assert(0, "too many file names");
      filename = a;
      continue;
    }
    if (a == "--") { nomore = true; continue; }
    if (a.length == 0) continue;
         if (a == "-opl2" || a == "--opl2") useOPL3 = false;
    else if (a == "-opl3" || a == "--opl3") useOPL3 = true;
    else if (a[0] == '-') assert(0, "invalid option: '"~a~"'");
    else {
      if (filename !is null) assert(0, "too many file names");
      filename = a;
      continue;
    }
  }
  player = new OPLPlayer(48000, useOPL3);
  version(genmidi_dumper) {
    player.dumpGenMidi(stdout);
  } else {
    if (filename.length == 0) assert(0, "file?");
    auto fl = VFile(filename);
    uint flen = cast(uint)fl.size;
    assert(flen > 0);
    alsaOpen(2);
    scope(exit) alsaClose();

    conwriteln("OPL", (useOPL3 ? "3" : "2"), ": playing '", filename, "'...");
    ubyte[] fdata = new ubyte[](flen);
    fl.rawReadExact(fdata);
    if (!player.load(fdata)) assert(0, "cannot load song");
    delete fdata;
    player.play();

    while (player.playing) {
      smpbufpos = player.generate(smpbuf[])*2;
      if (smpbufpos == 0) break;
      playbuf();
    }
    playbuf();
  }
}
