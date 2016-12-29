import iv.cmdcon;
import iv.vfs;

import iv.nukedopl3;
import xalsa;


__gshared opl3_chip opl;
__gshared short[4096] smpbuf;
__gshared uint smpbufpos;
__gshared double gain = 1;


void playbuf () {
  if (smpbufpos == 0) return;
  foreach (ref short v; smpbuf[0..smpbufpos]) {
    int n = cast(int)(cast(double)v*gain);
    if (n < short.min) n = short.min;
    if (n > short.max) n = short.max;
    v = cast(short)n;
  }
  alsaWriteX(smpbuf.ptr, smpbufpos/2);
  smpbufpos = 0;
}


void main (string[] args) {
  conRegVar!gain(0.0f, 20.0f, "gain", "replay gain (multiplier)");
  conProcessArgs!true(args);

  if (args.length < 2) assert(0);
  auto fl = VFile(args[1]);
  uint flen = fl.readNum!ushort;
  if (flen == 0) {
    flen = cast(uint)fl.size;
    fl.seek(0);
  }
  OPL3_Reset(&opl, 48000);
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
      OPL3_WriteReg(&opl, reg, val);
      if (samplesLeft) { samplesLeft = samplesLeft*48000/560; break; }
    }
    --samplesLeft;
    OPL3_GenerateStream(&opl, smpbuf.ptr+smpbufpos, 1);
    smpbufpos += 2;
    if (smpbufpos >= smpbuf.length) playbuf();
  }
  playbuf();
}
