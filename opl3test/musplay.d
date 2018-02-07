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
  player = new OPLPlayer(48000, true);
  version(genmidi_dumper) {
    player.dumpGenMidi(stdout);
  } else {
    if (args.length < 2) assert(0, "file?");
    auto fl = VFile(args[1]);
    uint flen = cast(uint)fl.size;
    assert(flen > 0);
    alsaOpen(2);
    scope(exit) alsaClose();

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
