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

import iv.nukedopl3;
import xalsa;


__gshared OPL3Chip opl;
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
  if (args.length < 2) assert(0, "file?");
  auto fl = VFile(args[1]);
  uint flen = fl.readNum!ushort;
  if (flen == 0) {
    flen = cast(uint)fl.size;
    fl.seek(0);
  }
  opl.reset(48000);
  alsaOpen(2);
  scope(exit) alsaClose();
  uint samplesLeft = 0;
  mainloop: for (;;) {
    while (samplesLeft == 0) {
      if (flen < 4) break mainloop;
      flen -= 4;
      ubyte reg = fl.readNum!ubyte;
      ubyte val = fl.readNum!ubyte;
      samplesLeft = fl.readNum!ushort;
      //conwritefln!"reg=0x%02x; val=0x%02x; delay=%s (%s)"(reg, val, samplesLeft, samplesLeft*48000/560);
      opl.writeReg(reg, val);
      if (samplesLeft) { samplesLeft = samplesLeft*48000/560; break; }
    }
    --samplesLeft;
    opl.generateStream(smpbuf[smpbufpos..smpbufpos+2]);
    smpbufpos += 2;
    if (smpbufpos >= smpbuf.length) playbuf();
  }
  playbuf();
}
