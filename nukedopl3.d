//
// Copyright (C) 2013-2016 Alexey Khokholov (Nuke.YKT)
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
//
//  Nuked OPL3 emulator.
//  Thanks:
//      MAME Development Team(Jarek Burczynski, Tatsuyuki Satoh):
//          Feedback and Rhythm part calculation information.
//      forums.submarine.org.uk(carbon14, opl3):
//          Tremolo and phase generator calculation information.
//      OPLx decapsulated(Matthew Gambrell, Olli Niemitalo):
//          OPL2 ROMs.
//
// version: 1.7.4
module iv.nukedopl3;
nothrow @trusted @nogc:

public:
enum OPL_WRITEBUF_SIZE = 1024;
enum OPL_WRITEBUF_DELAY = 2;


struct opl3_slot {
  opl3_channel* channel;
  opl3_chip* chip;
  short out_;
  short fbmod;
  short* mod;
  short prout;
  short eg_rout;
  short eg_out;
  ubyte eg_inc;
  ubyte eg_gen;
  ubyte eg_rate;
  ubyte eg_ksl;
  ubyte *trem;
  ubyte reg_vib;
  ubyte reg_type;
  ubyte reg_ksr;
  ubyte reg_mult;
  ubyte reg_ksl;
  ubyte reg_tl;
  ubyte reg_ar;
  ubyte reg_dr;
  ubyte reg_sl;
  ubyte reg_rr;
  ubyte reg_wf;
  ubyte key;
  uint pg_phase;
  uint timer;
}

struct opl3_channel {
  opl3_slot*[2] slots;
  opl3_channel* pair;
  opl3_chip* chip;
  short*[4] out_;
  ubyte chtype;
  ushort f_num;
  ubyte block;
  ubyte fb;
  ubyte con;
  ubyte alg;
  ubyte ksv;
  ushort cha, chb;
}

struct opl3_writebuf {
  ulong time;
  ushort reg;
  ubyte data;
}

struct opl3_chip {
  opl3_channel[18] channel;
  opl3_slot[36] slot;
  ushort timer;
  ubyte newm;
  ubyte nts;
  ubyte rhy;
  ubyte vibpos;
  ubyte vibshift;
  ubyte tremolo;
  ubyte tremolopos;
  ubyte tremoloshift;
  uint noise;
  short zeromod;
  int[2] mixbuff;
  //OPL3L
  int rateratio;
  int samplecnt;
  short[2] oldsamples;
  short[2] samples;

  ulong writebuf_samplecnt;
  uint writebuf_cur;
  uint writebuf_last;
  ulong writebuf_lasttime;
  opl3_writebuf[OPL_WRITEBUF_SIZE] writebuf;
}


private:
enum RSM_FRAC = 10;

// Channel types

enum {
  ch_2op = 0,
  ch_4op = 1,
  ch_4op2 = 2,
  ch_drum = 3
}

// Envelope key types

enum {
  egk_norm = 0x01,
  egk_drum = 0x02
}


//
// logsin table
//

static immutable ushort[256] logsinrom = [
  0x859, 0x6c3, 0x607, 0x58b, 0x52e, 0x4e4, 0x4a6, 0x471,
  0x443, 0x41a, 0x3f5, 0x3d3, 0x3b5, 0x398, 0x37e, 0x365,
  0x34e, 0x339, 0x324, 0x311, 0x2ff, 0x2ed, 0x2dc, 0x2cd,
  0x2bd, 0x2af, 0x2a0, 0x293, 0x286, 0x279, 0x26d, 0x261,
  0x256, 0x24b, 0x240, 0x236, 0x22c, 0x222, 0x218, 0x20f,
  0x206, 0x1fd, 0x1f5, 0x1ec, 0x1e4, 0x1dc, 0x1d4, 0x1cd,
  0x1c5, 0x1be, 0x1b7, 0x1b0, 0x1a9, 0x1a2, 0x19b, 0x195,
  0x18f, 0x188, 0x182, 0x17c, 0x177, 0x171, 0x16b, 0x166,
  0x160, 0x15b, 0x155, 0x150, 0x14b, 0x146, 0x141, 0x13c,
  0x137, 0x133, 0x12e, 0x129, 0x125, 0x121, 0x11c, 0x118,
  0x114, 0x10f, 0x10b, 0x107, 0x103, 0x0ff, 0x0fb, 0x0f8,
  0x0f4, 0x0f0, 0x0ec, 0x0e9, 0x0e5, 0x0e2, 0x0de, 0x0db,
  0x0d7, 0x0d4, 0x0d1, 0x0cd, 0x0ca, 0x0c7, 0x0c4, 0x0c1,
  0x0be, 0x0bb, 0x0b8, 0x0b5, 0x0b2, 0x0af, 0x0ac, 0x0a9,
  0x0a7, 0x0a4, 0x0a1, 0x09f, 0x09c, 0x099, 0x097, 0x094,
  0x092, 0x08f, 0x08d, 0x08a, 0x088, 0x086, 0x083, 0x081,
  0x07f, 0x07d, 0x07a, 0x078, 0x076, 0x074, 0x072, 0x070,
  0x06e, 0x06c, 0x06a, 0x068, 0x066, 0x064, 0x062, 0x060,
  0x05e, 0x05c, 0x05b, 0x059, 0x057, 0x055, 0x053, 0x052,
  0x050, 0x04e, 0x04d, 0x04b, 0x04a, 0x048, 0x046, 0x045,
  0x043, 0x042, 0x040, 0x03f, 0x03e, 0x03c, 0x03b, 0x039,
  0x038, 0x037, 0x035, 0x034, 0x033, 0x031, 0x030, 0x02f,
  0x02e, 0x02d, 0x02b, 0x02a, 0x029, 0x028, 0x027, 0x026,
  0x025, 0x024, 0x023, 0x022, 0x021, 0x020, 0x01f, 0x01e,
  0x01d, 0x01c, 0x01b, 0x01a, 0x019, 0x018, 0x017, 0x017,
  0x016, 0x015, 0x014, 0x014, 0x013, 0x012, 0x011, 0x011,
  0x010, 0x00f, 0x00f, 0x00e, 0x00d, 0x00d, 0x00c, 0x00c,
  0x00b, 0x00a, 0x00a, 0x009, 0x009, 0x008, 0x008, 0x007,
  0x007, 0x007, 0x006, 0x006, 0x005, 0x005, 0x005, 0x004,
  0x004, 0x004, 0x003, 0x003, 0x003, 0x002, 0x002, 0x002,
  0x002, 0x001, 0x001, 0x001, 0x001, 0x001, 0x001, 0x001,
  0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000
];

//
// exp table
//

static immutable ushort[256] exprom = [
  0x000, 0x003, 0x006, 0x008, 0x00b, 0x00e, 0x011, 0x014,
  0x016, 0x019, 0x01c, 0x01f, 0x022, 0x025, 0x028, 0x02a,
  0x02d, 0x030, 0x033, 0x036, 0x039, 0x03c, 0x03f, 0x042,
  0x045, 0x048, 0x04b, 0x04e, 0x051, 0x054, 0x057, 0x05a,
  0x05d, 0x060, 0x063, 0x066, 0x069, 0x06c, 0x06f, 0x072,
  0x075, 0x078, 0x07b, 0x07e, 0x082, 0x085, 0x088, 0x08b,
  0x08e, 0x091, 0x094, 0x098, 0x09b, 0x09e, 0x0a1, 0x0a4,
  0x0a8, 0x0ab, 0x0ae, 0x0b1, 0x0b5, 0x0b8, 0x0bb, 0x0be,
  0x0c2, 0x0c5, 0x0c8, 0x0cc, 0x0cf, 0x0d2, 0x0d6, 0x0d9,
  0x0dc, 0x0e0, 0x0e3, 0x0e7, 0x0ea, 0x0ed, 0x0f1, 0x0f4,
  0x0f8, 0x0fb, 0x0ff, 0x102, 0x106, 0x109, 0x10c, 0x110,
  0x114, 0x117, 0x11b, 0x11e, 0x122, 0x125, 0x129, 0x12c,
  0x130, 0x134, 0x137, 0x13b, 0x13e, 0x142, 0x146, 0x149,
  0x14d, 0x151, 0x154, 0x158, 0x15c, 0x160, 0x163, 0x167,
  0x16b, 0x16f, 0x172, 0x176, 0x17a, 0x17e, 0x181, 0x185,
  0x189, 0x18d, 0x191, 0x195, 0x199, 0x19c, 0x1a0, 0x1a4,
  0x1a8, 0x1ac, 0x1b0, 0x1b4, 0x1b8, 0x1bc, 0x1c0, 0x1c4,
  0x1c8, 0x1cc, 0x1d0, 0x1d4, 0x1d8, 0x1dc, 0x1e0, 0x1e4,
  0x1e8, 0x1ec, 0x1f0, 0x1f5, 0x1f9, 0x1fd, 0x201, 0x205,
  0x209, 0x20e, 0x212, 0x216, 0x21a, 0x21e, 0x223, 0x227,
  0x22b, 0x230, 0x234, 0x238, 0x23c, 0x241, 0x245, 0x249,
  0x24e, 0x252, 0x257, 0x25b, 0x25f, 0x264, 0x268, 0x26d,
  0x271, 0x276, 0x27a, 0x27f, 0x283, 0x288, 0x28c, 0x291,
  0x295, 0x29a, 0x29e, 0x2a3, 0x2a8, 0x2ac, 0x2b1, 0x2b5,
  0x2ba, 0x2bf, 0x2c4, 0x2c8, 0x2cd, 0x2d2, 0x2d6, 0x2db,
  0x2e0, 0x2e5, 0x2e9, 0x2ee, 0x2f3, 0x2f8, 0x2fd, 0x302,
  0x306, 0x30b, 0x310, 0x315, 0x31a, 0x31f, 0x324, 0x329,
  0x32e, 0x333, 0x338, 0x33d, 0x342, 0x347, 0x34c, 0x351,
  0x356, 0x35b, 0x360, 0x365, 0x36a, 0x370, 0x375, 0x37a,
  0x37f, 0x384, 0x38a, 0x38f, 0x394, 0x399, 0x39f, 0x3a4,
  0x3a9, 0x3ae, 0x3b4, 0x3b9, 0x3bf, 0x3c4, 0x3c9, 0x3cf,
  0x3d4, 0x3da, 0x3df, 0x3e4, 0x3ea, 0x3ef, 0x3f5, 0x3fa
];

//
// freq mult table multiplied by 2
//
// 1/2, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 10, 12, 12, 15, 15
//

static immutable ubyte[16] mt = [
  1, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 20, 24, 24, 30, 30
];

//
// ksl table
//

static immutable ubyte[16] kslrom = [
  0, 32, 40, 45, 48, 51, 53, 55, 56, 58, 59, 60, 61, 62, 63, 64
];

static immutable ubyte[4] kslshift = [
  8, 1, 2, 0
];

//
// envelope generator constants
//

static immutable ubyte[8][4][3] eg_incstep = [
  [
      [ 0, 0, 0, 0, 0, 0, 0, 0 ],
      [ 0, 0, 0, 0, 0, 0, 0, 0 ],
      [ 0, 0, 0, 0, 0, 0, 0, 0 ],
      [ 0, 0, 0, 0, 0, 0, 0, 0 ]
  ],
  [
      [ 0, 1, 0, 1, 0, 1, 0, 1 ],
      [ 0, 1, 0, 1, 1, 1, 0, 1 ],
      [ 0, 1, 1, 1, 0, 1, 1, 1 ],
      [ 0, 1, 1, 1, 1, 1, 1, 1 ]
  ],
  [
      [ 1, 1, 1, 1, 1, 1, 1, 1 ],
      [ 2, 2, 1, 1, 1, 1, 1, 1 ],
      [ 2, 2, 1, 1, 2, 2, 1, 1 ],
      [ 2, 2, 2, 2, 2, 2, 1, 1 ]
  ]
];

static immutable ubyte[16] eg_incdesc = [
  0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 2
];

static immutable byte[16] eg_incsh = [
  0, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0, 0, -1, -2
];

//
// address decoding
//

static immutable byte[0x20] ad_slot = [
  0, 1, 2, 3, 4, 5, -1, -1, 6, 7, 8, 9, 10, 11, -1, -1,
  12, 13, 14, 15, 16, 17, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1
];

static immutable ubyte[18] ch_slot = [
  0, 1, 2, 6, 7, 8, 12, 13, 14, 18, 19, 20, 24, 25, 26, 30, 31, 32
];

//
// Envelope generator
//

alias envelope_sinfunc = short function (ushort phase, ushort envelope) nothrow @trusted @nogc;
alias envelope_genfunc = void function (opl3_slot *slott) nothrow @trusted @nogc;

private short OPL3_EnvelopeCalcExp (uint level) {
  if (level > 0x1fff) level = 0x1fff;
  return cast(short)(((exprom.ptr[(level&0xff)^0xff]|0x400)<<1)>>(level>>8));
}

private short OPL3_EnvelopeCalcSin0 (ushort phase, ushort envelope) {
  ushort out_ = 0;
  ushort neg = 0;
  phase &= 0x3ff;
  if (phase&0x200) neg = ushort.max;
  if (phase&0x100) out_ = logsinrom.ptr[(phase&0xff)^0xff]; else out_ = logsinrom.ptr[phase&0xff];
  return OPL3_EnvelopeCalcExp(out_+(envelope<<3))^neg;
}

private short OPL3_EnvelopeCalcSin1 (ushort phase, ushort envelope) {
  ushort out_ = 0;
  phase &= 0x3ff;
       if (phase&0x200) out_ = 0x1000;
  else if (phase&0x100) out_ = logsinrom.ptr[(phase&0xff)^0xff];
  else out_ = logsinrom.ptr[phase&0xff];
  return OPL3_EnvelopeCalcExp(out_+(envelope<<3));
}

private short OPL3_EnvelopeCalcSin2 (ushort phase, ushort envelope) {
  ushort out_ = 0;
  phase &= 0x3ff;
  if (phase&0x100) out_ = logsinrom.ptr[(phase&0xff)^0xff]; else out_ = logsinrom.ptr[phase&0xff];
  return OPL3_EnvelopeCalcExp(out_+(envelope<<3));
}

private short OPL3_EnvelopeCalcSin3 (ushort phase, ushort envelope) {
  ushort out_ = 0;
  phase &= 0x3ff;
  if (phase&0x100) out_ = 0x1000; else out_ = logsinrom.ptr[phase&0xff];
  return OPL3_EnvelopeCalcExp(out_+(envelope<<3));
}

private short OPL3_EnvelopeCalcSin4 (ushort phase, ushort envelope) {
  ushort out_ = 0;
  ushort neg = 0;
  phase &= 0x3ff;
  if ((phase&0x300) == 0x100) neg = ushort.max;
       if (phase&0x200) out_ = 0x1000;
  else if (phase&0x80) out_ = logsinrom.ptr[((phase^0xff)<<1)&0xff];
  else out_ = logsinrom.ptr[(phase<<1)&0xff];
  return OPL3_EnvelopeCalcExp(out_+(envelope<<3))^neg;
}

private short OPL3_EnvelopeCalcSin5 (ushort phase, ushort envelope) {
  ushort out_ = 0;
  phase &= 0x3ff;
       if (phase&0x200) out_ = 0x1000;
  else if (phase&0x80) out_ = logsinrom.ptr[((phase^0xff)<<1)&0xff];
  else out_ = logsinrom.ptr[(phase<<1)&0xff];
  return OPL3_EnvelopeCalcExp(out_+(envelope<<3));
}

private short OPL3_EnvelopeCalcSin6 (ushort phase, ushort envelope) {
  ushort neg = 0;
  phase &= 0x3ff;
  if (phase&0x200) neg = ushort.max;
  return OPL3_EnvelopeCalcExp(envelope<<3)^neg;
}

private short OPL3_EnvelopeCalcSin7 (ushort phase, ushort envelope) {
  ushort out_ = 0;
  ushort neg = 0;
  phase &= 0x3ff;
  if (phase&0x200) {
    neg = ushort.max;
    phase = (phase&0x1ff)^0x1ff;
  }
  out_ = cast(ushort)(phase<<3);
  return OPL3_EnvelopeCalcExp(out_+(envelope<<3))^neg;
}

static immutable envelope_sinfunc[8] envelope_sin = [
  &OPL3_EnvelopeCalcSin0,
  &OPL3_EnvelopeCalcSin1,
  &OPL3_EnvelopeCalcSin2,
  &OPL3_EnvelopeCalcSin3,
  &OPL3_EnvelopeCalcSin4,
  &OPL3_EnvelopeCalcSin5,
  &OPL3_EnvelopeCalcSin6,
  &OPL3_EnvelopeCalcSin7
];

static immutable envelope_genfunc[5] envelope_gen = [
  &OPL3_EnvelopeGenOff,
  &OPL3_EnvelopeGenAttack,
  &OPL3_EnvelopeGenDecay,
  &OPL3_EnvelopeGenSustain,
  &OPL3_EnvelopeGenRelease
];

alias envelope_gen_num = int;
enum /*envelope_gen_num*/:int {
  envelope_gen_num_off = 0,
  envelope_gen_num_attack = 1,
  envelope_gen_num_decay = 2,
  envelope_gen_num_sustain = 3,
  envelope_gen_num_release = 4
}

private ubyte OPL3_EnvelopeCalcRate (opl3_slot* slot, ubyte reg_rate) {
  if (reg_rate == 0x00) return 0x00;
  ubyte rate = cast(ubyte)((reg_rate<<2)+(slot.reg_ksr ? slot.channel.ksv : (slot.channel.ksv>>2)));
  if (rate > 0x3c) rate = 0x3c;
  return rate;
}

private void OPL3_EnvelopeUpdateKSL (opl3_slot* slot) {
  short ksl = (kslrom.ptr[slot.channel.f_num>>6]<<2)-((0x08-slot.channel.block)<<5);
  if (ksl < 0) ksl = 0;
  slot.eg_ksl = cast(ubyte)ksl;
}

private void OPL3_EnvelopeUpdateRate (opl3_slot* slot) {
  switch (slot.eg_gen) {
    case envelope_gen_num_off:
    case envelope_gen_num_attack:
      slot.eg_rate = OPL3_EnvelopeCalcRate(slot, slot.reg_ar);
      break;
    case envelope_gen_num_decay:
      slot.eg_rate = OPL3_EnvelopeCalcRate(slot, slot.reg_dr);
      break;
    case envelope_gen_num_sustain:
    case envelope_gen_num_release:
      slot.eg_rate = OPL3_EnvelopeCalcRate(slot, slot.reg_rr);
      break;
    default: break;
  }
}

private void OPL3_EnvelopeGenOff (opl3_slot* slot) {
  slot.eg_rout = 0x1ff;
}

private void OPL3_EnvelopeGenAttack (opl3_slot* slot) {
  if (slot.eg_rout == 0x00) {
    slot.eg_gen = envelope_gen_num_decay;
    OPL3_EnvelopeUpdateRate(slot);
  } else {
    slot.eg_rout += ((~slot.eg_rout)*slot.eg_inc)>>3;
    if (slot.eg_rout < 0x00) slot.eg_rout = 0x00;
  }
}

private void OPL3_EnvelopeGenDecay (opl3_slot* slot) {
  if (slot.eg_rout >= slot.reg_sl<<4) {
    slot.eg_gen = envelope_gen_num_sustain;
    OPL3_EnvelopeUpdateRate(slot);
  } else {
    slot.eg_rout += slot.eg_inc;
  }
}

private void OPL3_EnvelopeGenSustain (opl3_slot* slot) {
  if (!slot.reg_type) OPL3_EnvelopeGenRelease(slot);
}

private void OPL3_EnvelopeGenRelease (opl3_slot* slot) {
  if (slot.eg_rout >= 0x1ff) {
    slot.eg_gen = envelope_gen_num_off;
    slot.eg_rout = 0x1ff;
    OPL3_EnvelopeUpdateRate(slot);
  } else {
    slot.eg_rout += slot.eg_inc;
  }
}

private void OPL3_EnvelopeCalc (opl3_slot* slot) {
  ubyte rate_h, rate_l;
  ubyte inc = 0;
  rate_h = slot.eg_rate>>2;
  rate_l = slot.eg_rate&3;
  if (eg_incsh.ptr[rate_h] > 0) {
    if ((slot.chip.timer&((1<<eg_incsh.ptr[rate_h])-1)) == 0) {
      inc = eg_incstep.ptr[eg_incdesc.ptr[rate_h]].ptr[rate_l].ptr[((slot.chip.timer)>> eg_incsh.ptr[rate_h])&0x07];
    }
  } else {
    inc = cast(ubyte)(eg_incstep.ptr[eg_incdesc.ptr[rate_h]].ptr[rate_l].ptr[slot.chip.timer&0x07]<<(-(eg_incsh.ptr[rate_h])));
  }
  slot.eg_inc = inc;
  slot.eg_out = cast(short)(slot.eg_rout+(slot.reg_tl<<2)+(slot.eg_ksl>>kslshift.ptr[slot.reg_ksl])+*slot.trem);
  envelope_gen[slot.eg_gen](slot);
}

private void OPL3_EnvelopeKeyOn (opl3_slot* slot, ubyte type) {
  if (!slot.key) {
    slot.eg_gen = envelope_gen_num_attack;
    OPL3_EnvelopeUpdateRate(slot);
    if ((slot.eg_rate>>2) == 0x0f) {
      slot.eg_gen = envelope_gen_num_decay;
      OPL3_EnvelopeUpdateRate(slot);
      slot.eg_rout = 0x00;
    }
    slot.pg_phase = 0x00;
  }
  slot.key |= type;
}

private void OPL3_EnvelopeKeyOff (opl3_slot* slot, ubyte type) {
  if (slot.key) {
    slot.key &= (~type);
    if (!slot.key) {
      slot.eg_gen = envelope_gen_num_release;
      OPL3_EnvelopeUpdateRate(slot);
    }
  }
}

//
// Phase Generator
//

private void OPL3_PhaseGenerate (opl3_slot* slot) {
  ushort f_num;
  uint basefreq;

  f_num = slot.channel.f_num;
  if (slot.reg_vib) {
    byte range;
    ubyte vibpos;

    range = (f_num>>7)&7;
    vibpos = slot.chip.vibpos;

         if (!(vibpos&3)) range = 0;
    else if (vibpos&1) range >>= 1;
    range >>= slot.chip.vibshift;

    if (vibpos&4) range = -(range);
    f_num += range;
  }
  basefreq = (f_num<<slot.channel.block)>>1;
  slot.pg_phase += (basefreq*mt.ptr[slot.reg_mult])>>1;
}

//
// Noise Generator
//

private void OPL3_NoiseGenerate (opl3_chip* chip) {
  if (chip.noise&0x01) chip.noise ^= 0x800302;
  chip.noise >>= 1;
}

//
// Slot
//

private void OPL3_SlotWrite20 (opl3_slot* slot, ubyte data) {
  slot.trem = ((data>>7)&0x01 ? &slot.chip.tremolo : cast(ubyte*)&slot.chip.zeromod);
  slot.reg_vib = (data>>6)&0x01;
  slot.reg_type = (data>>5)&0x01;
  slot.reg_ksr = (data>>4)&0x01;
  slot.reg_mult = data&0x0f;
  OPL3_EnvelopeUpdateRate(slot);
}

private void OPL3_SlotWrite40 (opl3_slot* slot, ubyte data) {
  slot.reg_ksl = (data>>6)&0x03;
  slot.reg_tl = data&0x3f;
  OPL3_EnvelopeUpdateKSL(slot);
}

private void OPL3_SlotWrite60 (opl3_slot* slot, ubyte data) {
  slot.reg_ar = (data>>4)&0x0f;
  slot.reg_dr = data&0x0f;
  OPL3_EnvelopeUpdateRate(slot);
}

private void OPL3_SlotWrite80 (opl3_slot* slot, ubyte data) {
  slot.reg_sl = (data>>4)&0x0f;
  if (slot.reg_sl == 0x0f) slot.reg_sl = 0x1f;
  slot.reg_rr = data&0x0f;
  OPL3_EnvelopeUpdateRate(slot);
}

private void OPL3_SlotWriteE0 (opl3_slot* slot, ubyte data) {
  slot.reg_wf = data&0x07;
  if (slot.chip.newm == 0x00) slot.reg_wf &= 0x03;
}

private void OPL3_SlotGeneratePhase (opl3_slot* slot, ushort phase) {
  slot.out_ = envelope_sin[slot.reg_wf](phase, slot.eg_out);
}

private void OPL3_SlotGenerate (opl3_slot* slot) {
  OPL3_SlotGeneratePhase(slot, cast(ushort)(cast(ushort)(slot.pg_phase>>9)+*slot.mod));
}

private void OPL3_SlotGenerateZM (opl3_slot* slot) {
  OPL3_SlotGeneratePhase(slot, cast(ushort)(slot.pg_phase>>9));
}

private void OPL3_SlotCalcFB (opl3_slot* slot) {
  slot.fbmod = (slot.channel.fb != 0x00 ? cast(short)((slot.prout+slot.out_)>>(0x09-slot.channel.fb)) : 0);
  slot.prout = slot.out_;
}

//
// Channel
//

private void OPL3_ChannelUpdateRhythm (opl3_chip* chip, ubyte data) {
  opl3_channel* channel6;
  opl3_channel* channel7;
  opl3_channel* channel8;
  ubyte chnum;

  chip.rhy = data&0x3f;
  if (chip.rhy&0x20) {
    channel6 = &chip.channel[6];
    channel7 = &chip.channel[7];
    channel8 = &chip.channel[8];
    channel6.out_.ptr[0] = &channel6.slots.ptr[1].out_;
    channel6.out_.ptr[1] = &channel6.slots.ptr[1].out_;
    channel6.out_.ptr[2] = &chip.zeromod;
    channel6.out_.ptr[3] = &chip.zeromod;
    channel7.out_.ptr[0] = &channel7.slots.ptr[0].out_;
    channel7.out_.ptr[1] = &channel7.slots.ptr[0].out_;
    channel7.out_.ptr[2] = &channel7.slots.ptr[1].out_;
    channel7.out_.ptr[3] = &channel7.slots.ptr[1].out_;
    channel8.out_.ptr[0] = &channel8.slots.ptr[0].out_;
    channel8.out_.ptr[1] = &channel8.slots.ptr[0].out_;
    channel8.out_.ptr[2] = &channel8.slots.ptr[1].out_;
    channel8.out_.ptr[3] = &channel8.slots.ptr[1].out_;
    for (chnum = 6; chnum < 9; ++chnum) chip.channel[chnum].chtype = ch_drum;
    OPL3_ChannelSetupAlg(channel6);
    //hh
    if (chip.rhy&0x01) {
      OPL3_EnvelopeKeyOn(channel7.slots.ptr[0], egk_drum);
    } else {
      OPL3_EnvelopeKeyOff(channel7.slots.ptr[0], egk_drum);
    }
    //tc
    if (chip.rhy&0x02) {
      OPL3_EnvelopeKeyOn(channel8.slots.ptr[1], egk_drum);
    } else {
      OPL3_EnvelopeKeyOff(channel8.slots.ptr[1], egk_drum);
    }
    //tom
    if (chip.rhy&0x04) {
      OPL3_EnvelopeKeyOn(channel8.slots.ptr[0], egk_drum);
    } else {
      OPL3_EnvelopeKeyOff(channel8.slots.ptr[0], egk_drum);
    }
    //sd
    if (chip.rhy&0x08) {
      OPL3_EnvelopeKeyOn(channel7.slots.ptr[1], egk_drum);
    } else {
      OPL3_EnvelopeKeyOff(channel7.slots.ptr[1], egk_drum);
    }
    //bd
    if (chip.rhy&0x10) {
      OPL3_EnvelopeKeyOn(channel6.slots.ptr[0], egk_drum);
      OPL3_EnvelopeKeyOn(channel6.slots.ptr[1], egk_drum);
    } else {
      OPL3_EnvelopeKeyOff(channel6.slots.ptr[0], egk_drum);
      OPL3_EnvelopeKeyOff(channel6.slots.ptr[1], egk_drum);
    }
  } else {
    for (chnum = 6; chnum < 9; ++chnum) {
      chip.channel[chnum].chtype = ch_2op;
      OPL3_ChannelSetupAlg(&chip.channel[chnum]);
      OPL3_EnvelopeKeyOff(chip.channel[chnum].slots.ptr[0], egk_drum);
      OPL3_EnvelopeKeyOff(chip.channel[chnum].slots.ptr[1], egk_drum);
    }
  }
}

private void OPL3_ChannelWriteA0 (opl3_channel* channel, ubyte data) {
  if (channel.chip.newm && channel.chtype == ch_4op2) return;
  channel.f_num = (channel.f_num&0x300)|data;
  channel.ksv = cast(ubyte)((channel.block<<1)|((channel.f_num>>(0x09-channel.chip.nts))&0x01));
  OPL3_EnvelopeUpdateKSL(channel.slots.ptr[0]);
  OPL3_EnvelopeUpdateKSL(channel.slots.ptr[1]);
  OPL3_EnvelopeUpdateRate(channel.slots.ptr[0]);
  OPL3_EnvelopeUpdateRate(channel.slots.ptr[1]);
  if (channel.chip.newm && channel.chtype == ch_4op) {
    channel.pair.f_num = channel.f_num;
    channel.pair.ksv = channel.ksv;
    OPL3_EnvelopeUpdateKSL(channel.pair.slots.ptr[0]);
    OPL3_EnvelopeUpdateKSL(channel.pair.slots.ptr[1]);
    OPL3_EnvelopeUpdateRate(channel.pair.slots.ptr[0]);
    OPL3_EnvelopeUpdateRate(channel.pair.slots.ptr[1]);
  }
}

private void OPL3_ChannelWriteB0 (opl3_channel* channel, ubyte data) {
  if (channel.chip.newm && channel.chtype == ch_4op2) return;
  channel.f_num = (channel.f_num&0xff)|((data&0x03)<<8);
  channel.block = (data>>2)&0x07;
  channel.ksv = cast(ubyte)((channel.block<<1)|((channel.f_num>>(0x09-channel.chip.nts))&0x01));
  OPL3_EnvelopeUpdateKSL(channel.slots.ptr[0]);
  OPL3_EnvelopeUpdateKSL(channel.slots.ptr[1]);
  OPL3_EnvelopeUpdateRate(channel.slots.ptr[0]);
  OPL3_EnvelopeUpdateRate(channel.slots.ptr[1]);
  if (channel.chip.newm && channel.chtype == ch_4op) {
    channel.pair.f_num = channel.f_num;
    channel.pair.block = channel.block;
    channel.pair.ksv = channel.ksv;
    OPL3_EnvelopeUpdateKSL(channel.pair.slots.ptr[0]);
    OPL3_EnvelopeUpdateKSL(channel.pair.slots.ptr[1]);
    OPL3_EnvelopeUpdateRate(channel.pair.slots.ptr[0]);
    OPL3_EnvelopeUpdateRate(channel.pair.slots.ptr[1]);
  }
}

private void OPL3_ChannelSetupAlg (opl3_channel* channel) {
  if (channel.chtype == ch_drum) {
    final switch (channel.alg&0x01) {
      case 0x00:
        channel.slots.ptr[0].mod = &channel.slots.ptr[0].fbmod;
        channel.slots.ptr[1].mod = &channel.slots.ptr[0].out_;
        break;
      case 0x01:
        channel.slots.ptr[0].mod = &channel.slots.ptr[0].fbmod;
        channel.slots.ptr[1].mod = &channel.chip.zeromod;
        break;
    }
    return;
  }
  if (channel.alg&0x08) return;
  if (channel.alg&0x04) {
    channel.pair.out_.ptr[0] = &channel.chip.zeromod;
    channel.pair.out_.ptr[1] = &channel.chip.zeromod;
    channel.pair.out_.ptr[2] = &channel.chip.zeromod;
    channel.pair.out_.ptr[3] = &channel.chip.zeromod;
    final switch (channel.alg&0x03) {
      case 0x00:
        channel.pair.slots.ptr[0].mod = &channel.pair.slots.ptr[0].fbmod;
        channel.pair.slots.ptr[1].mod = &channel.pair.slots.ptr[0].out_;
        channel.slots.ptr[0].mod = &channel.pair.slots.ptr[1].out_;
        channel.slots.ptr[1].mod = &channel.slots.ptr[0].out_;
        channel.out_.ptr[0] = &channel.slots.ptr[1].out_;
        channel.out_.ptr[1] = &channel.chip.zeromod;
        channel.out_.ptr[2] = &channel.chip.zeromod;
        channel.out_.ptr[3] = &channel.chip.zeromod;
        break;
      case 0x01:
        channel.pair.slots.ptr[0].mod = &channel.pair.slots.ptr[0].fbmod;
        channel.pair.slots.ptr[1].mod = &channel.pair.slots.ptr[0].out_;
        channel.slots.ptr[0].mod = &channel.chip.zeromod;
        channel.slots.ptr[1].mod = &channel.slots.ptr[0].out_;
        channel.out_.ptr[0] = &channel.pair.slots.ptr[1].out_;
        channel.out_.ptr[1] = &channel.slots.ptr[1].out_;
        channel.out_.ptr[2] = &channel.chip.zeromod;
        channel.out_.ptr[3] = &channel.chip.zeromod;
        break;
      case 0x02:
        channel.pair.slots.ptr[0].mod = &channel.pair.slots.ptr[0].fbmod;
        channel.pair.slots.ptr[1].mod = &channel.chip.zeromod;
        channel.slots.ptr[0].mod = &channel.pair.slots.ptr[1].out_;
        channel.slots.ptr[1].mod = &channel.slots.ptr[0].out_;
        channel.out_.ptr[0] = &channel.pair.slots.ptr[0].out_;
        channel.out_.ptr[1] = &channel.slots.ptr[1].out_;
        channel.out_.ptr[2] = &channel.chip.zeromod;
        channel.out_.ptr[3] = &channel.chip.zeromod;
        break;
      case 0x03:
        channel.pair.slots.ptr[0].mod = &channel.pair.slots.ptr[0].fbmod;
        channel.pair.slots.ptr[1].mod = &channel.chip.zeromod;
        channel.slots.ptr[0].mod = &channel.pair.slots.ptr[1].out_;
        channel.slots.ptr[1].mod = &channel.chip.zeromod;
        channel.out_.ptr[0] = &channel.pair.slots.ptr[0].out_;
        channel.out_.ptr[1] = &channel.slots.ptr[0].out_;
        channel.out_.ptr[2] = &channel.slots.ptr[1].out_;
        channel.out_.ptr[3] = &channel.chip.zeromod;
        break;
    }
  } else {
    final switch (channel.alg&0x01) {
      case 0x00:
        channel.slots.ptr[0].mod = &channel.slots.ptr[0].fbmod;
        channel.slots.ptr[1].mod = &channel.slots.ptr[0].out_;
        channel.out_.ptr[0] = &channel.slots.ptr[1].out_;
        channel.out_.ptr[1] = &channel.chip.zeromod;
        channel.out_.ptr[2] = &channel.chip.zeromod;
        channel.out_.ptr[3] = &channel.chip.zeromod;
        break;
      case 0x01:
        channel.slots.ptr[0].mod = &channel.slots.ptr[0].fbmod;
        channel.slots.ptr[1].mod = &channel.chip.zeromod;
        channel.out_.ptr[0] = &channel.slots.ptr[0].out_;
        channel.out_.ptr[1] = &channel.slots.ptr[1].out_;
        channel.out_.ptr[2] = &channel.chip.zeromod;
        channel.out_.ptr[3] = &channel.chip.zeromod;
        break;
    }
  }
}

private void OPL3_ChannelWriteC0 (opl3_channel* channel, ubyte data) {
  channel.fb = (data&0x0e)>>1;
  channel.con = data&0x01;
  channel.alg = channel.con;
  if (channel.chip.newm) {
    if (channel.chtype == ch_4op) {
      channel.pair.alg = cast(ubyte)(0x04|(channel.con<<1)|(channel.pair.con));
      channel.alg = 0x08;
      OPL3_ChannelSetupAlg(channel.pair);
    } else if (channel.chtype == ch_4op2) {
      channel.alg = cast(ubyte)(0x04|(channel.pair.con<<1)|(channel.con));
      channel.pair.alg = 0x08;
      OPL3_ChannelSetupAlg(channel);
    } else {
      OPL3_ChannelSetupAlg(channel);
    }
  } else {
    OPL3_ChannelSetupAlg(channel);
  }
  if (channel.chip.newm) {
    channel.cha = ((data>>4)&0x01 ? ushort.max : 0);
    channel.chb = ((data>>5)&0x01 ? ushort.max : 0);
  } else {
    channel.cha = channel.chb = ushort.max;
  }
}

private void OPL3_ChannelKeyOn (opl3_channel* channel) {
  if (channel.chip.newm) {
    if (channel.chtype == ch_4op) {
      OPL3_EnvelopeKeyOn(channel.slots.ptr[0], egk_norm);
      OPL3_EnvelopeKeyOn(channel.slots.ptr[1], egk_norm);
      OPL3_EnvelopeKeyOn(channel.pair.slots.ptr[0], egk_norm);
      OPL3_EnvelopeKeyOn(channel.pair.slots.ptr[1], egk_norm);
    } else if (channel.chtype == ch_2op || channel.chtype == ch_drum) {
      OPL3_EnvelopeKeyOn(channel.slots.ptr[0], egk_norm);
      OPL3_EnvelopeKeyOn(channel.slots.ptr[1], egk_norm);
    }
  } else {
    OPL3_EnvelopeKeyOn(channel.slots.ptr[0], egk_norm);
    OPL3_EnvelopeKeyOn(channel.slots.ptr[1], egk_norm);
  }
}

private void OPL3_ChannelKeyOff (opl3_channel* channel) {
  if (channel.chip.newm) {
    if (channel.chtype == ch_4op) {
      OPL3_EnvelopeKeyOff(channel.slots.ptr[0], egk_norm);
      OPL3_EnvelopeKeyOff(channel.slots.ptr[1], egk_norm);
      OPL3_EnvelopeKeyOff(channel.pair.slots.ptr[0], egk_norm);
      OPL3_EnvelopeKeyOff(channel.pair.slots.ptr[1], egk_norm);
    } else if (channel.chtype == ch_2op || channel.chtype == ch_drum) {
      OPL3_EnvelopeKeyOff(channel.slots.ptr[0], egk_norm);
      OPL3_EnvelopeKeyOff(channel.slots.ptr[1], egk_norm);
    }
  } else {
    OPL3_EnvelopeKeyOff(channel.slots.ptr[0], egk_norm);
    OPL3_EnvelopeKeyOff(channel.slots.ptr[1], egk_norm);
  }
}

private void OPL3_ChannelSet4Op (opl3_chip* chip, ubyte data) {
  ubyte bit;
  ubyte chnum;
  for (bit = 0; bit < 6; ++bit) {
    chnum = bit;
    if (bit >= 3) chnum += 9-3;
    if ((data>>bit)&0x01) {
      chip.channel[chnum].chtype = ch_4op;
      chip.channel[chnum+3].chtype = ch_4op2;
    } else {
      chip.channel[chnum].chtype = ch_2op;
      chip.channel[chnum+3].chtype = ch_2op;
    }
  }
}

private short OPL3_ClipSample (int sample) pure {
  pragma(inline, true);
       if (sample > 32767) sample = 32767;
  else if (sample < -32768) sample = -32768;
  return cast(short)sample;
}

private void OPL3_GenerateRhythm1 (opl3_chip* chip) {
  opl3_channel* channel6;
  opl3_channel* channel7;
  opl3_channel* channel8;
  ushort phase14;
  ushort phase17;
  ushort phase;
  ushort phasebit;

  channel6 = &chip.channel[6];
  channel7 = &chip.channel[7];
  channel8 = &chip.channel[8];
  OPL3_SlotGenerate(channel6.slots.ptr[0]);
  phase14 = (channel7.slots.ptr[0].pg_phase>>9)&0x3ff;
  phase17 = (channel8.slots.ptr[1].pg_phase>>9)&0x3ff;
  phase = 0x00;
  //hh tc phase bit
  phasebit = ((phase14&0x08)|(((phase14>>5)^phase14)&0x04)|(((phase17>>2)^phase17)&0x08)) ? 0x01 : 0x00;
  //hh
  phase = cast(ushort)((phasebit<<9)|(0x34<<((phasebit^(chip.noise&0x01))<<1)));
  OPL3_SlotGeneratePhase(channel7.slots.ptr[0], phase);
  //tt
  OPL3_SlotGenerateZM(channel8.slots.ptr[0]);
}

private void OPL3_GenerateRhythm2 (opl3_chip* chip) {
  opl3_channel* channel6;
  opl3_channel* channel7;
  opl3_channel* channel8;
  ushort phase14;
  ushort phase17;
  ushort phase;
  ushort phasebit;

  channel6 = &chip.channel[6];
  channel7 = &chip.channel[7];
  channel8 = &chip.channel[8];
  OPL3_SlotGenerate(channel6.slots.ptr[1]);
  phase14 = (channel7.slots.ptr[0].pg_phase>>9)&0x3ff;
  phase17 = (channel8.slots.ptr[1].pg_phase>>9)&0x3ff;
  phase = 0x00;
  //hh tc phase bit
  phasebit = ((phase14&0x08)|(((phase14>>5)^phase14)&0x04)|(((phase17>>2)^phase17)&0x08)) ? 0x01 : 0x00;
  //sd
  phase = (0x100<<((phase14>>8)&0x01))^((chip.noise&0x01)<<8);
  OPL3_SlotGeneratePhase(channel7.slots.ptr[1], phase);
  //tc
  phase = cast(ushort)(0x100|(phasebit<<9));
  OPL3_SlotGeneratePhase(channel8.slots.ptr[1], phase);
}


// ////////////////////////////////////////////////////////////////////////// //
///
public void OPL3_Generate (opl3_chip* chip, short* buf) {
  ubyte ii;
  ubyte jj;
  short accm;

  buf[1] = OPL3_ClipSample(chip.mixbuff.ptr[1]);

  for (ii = 0; ii < 12; ++ii) {
    OPL3_SlotCalcFB(&chip.slot.ptr[ii]);
    OPL3_PhaseGenerate(&chip.slot.ptr[ii]);
    OPL3_EnvelopeCalc(&chip.slot.ptr[ii]);
    OPL3_SlotGenerate(&chip.slot.ptr[ii]);
  }

  for (ii = 12; ii < 15; ++ii) {
    OPL3_SlotCalcFB(&chip.slot.ptr[ii]);
    OPL3_PhaseGenerate(&chip.slot.ptr[ii]);
    OPL3_EnvelopeCalc(&chip.slot.ptr[ii]);
  }

  if (chip.rhy&0x20) {
    OPL3_GenerateRhythm1(chip);
  } else {
    OPL3_SlotGenerate(&chip.slot.ptr[12]);
    OPL3_SlotGenerate(&chip.slot.ptr[13]);
    OPL3_SlotGenerate(&chip.slot.ptr[14]);
  }

  chip.mixbuff.ptr[0] = 0;
  for (ii = 0; ii < 18; ++ii) {
    accm = 0;
    for (jj = 0; jj < 4; ++jj) accm += *chip.channel[ii].out_.ptr[jj];
    chip.mixbuff.ptr[0] += cast(short)(accm&chip.channel[ii].cha);
  }

  for (ii = 15; ii < 18; ++ii) {
    OPL3_SlotCalcFB(&chip.slot.ptr[ii]);
    OPL3_PhaseGenerate(&chip.slot.ptr[ii]);
    OPL3_EnvelopeCalc(&chip.slot.ptr[ii]);
  }

  if (chip.rhy&0x20) {
    OPL3_GenerateRhythm2(chip);
  } else {
    OPL3_SlotGenerate(&chip.slot.ptr[15]);
    OPL3_SlotGenerate(&chip.slot.ptr[16]);
    OPL3_SlotGenerate(&chip.slot.ptr[17]);
  }

  buf[0] = OPL3_ClipSample(chip.mixbuff.ptr[0]);

  for (ii = 18; ii < 33; ++ii) {
    OPL3_SlotCalcFB(&chip.slot.ptr[ii]);
    OPL3_PhaseGenerate(&chip.slot.ptr[ii]);
    OPL3_EnvelopeCalc(&chip.slot.ptr[ii]);
    OPL3_SlotGenerate(&chip.slot.ptr[ii]);
  }

  chip.mixbuff.ptr[1] = 0;
  for (ii = 0; ii < 18; ++ii) {
    accm = 0;
    for (jj = 0; jj < 4; jj++) accm += *chip.channel[ii].out_.ptr[jj];
    chip.mixbuff.ptr[1] += cast(short)(accm&chip.channel[ii].chb);
  }

  for (ii = 33; ii < 36; ++ii) {
    OPL3_SlotCalcFB(&chip.slot.ptr[ii]);
    OPL3_PhaseGenerate(&chip.slot.ptr[ii]);
    OPL3_EnvelopeCalc(&chip.slot.ptr[ii]);
    OPL3_SlotGenerate(&chip.slot.ptr[ii]);
  }

  OPL3_NoiseGenerate(chip);

  if ((chip.timer&0x3f) == 0x3f) chip.tremolopos = (chip.tremolopos+1)%210;
  chip.tremolo = (chip.tremolopos < 105 ? chip.tremolopos>>chip.tremoloshift : cast(ubyte)((210-chip.tremolopos)>>chip.tremoloshift));
  if ((chip.timer&0x3ff) == 0x3ff) chip.vibpos = (chip.vibpos+1)&7;

  ++chip.timer;

  while (chip.writebuf[chip.writebuf_cur].time <= chip.writebuf_samplecnt) {
    if (!(chip.writebuf[chip.writebuf_cur].reg&0x200)) break;
    chip.writebuf[chip.writebuf_cur].reg &= 0x1ff;
    OPL3_WriteReg(chip, chip.writebuf[chip.writebuf_cur].reg, chip.writebuf[chip.writebuf_cur].data);
    chip.writebuf_cur = (chip.writebuf_cur+1)%OPL_WRITEBUF_SIZE;
  }
  ++chip.writebuf_samplecnt;
}


///
public void OPL3_GenerateResampled (opl3_chip* chip, short* buf) {
  while (chip.samplecnt >= chip.rateratio) {
    chip.oldsamples.ptr[0] = chip.samples.ptr[0];
    chip.oldsamples.ptr[1] = chip.samples.ptr[1];
    OPL3_Generate(chip, chip.samples.ptr);
    chip.samplecnt -= chip.rateratio;
  }
  buf[0] = cast(short)((chip.oldsamples.ptr[0]*(chip.rateratio-chip.samplecnt)+chip.samples.ptr[0]*chip.samplecnt)/chip.rateratio);
  buf[1] = cast(short)((chip.oldsamples.ptr[1]*(chip.rateratio-chip.samplecnt)+chip.samples.ptr[1]*chip.samplecnt)/chip.rateratio);
  chip.samplecnt += 1<<RSM_FRAC;
}


///
public void OPL3_Reset (opl3_chip* chip, uint samplerate) {
  ubyte slotnum;
  ubyte channum;

  ubyte* cc = cast(ubyte*)chip;
  cc[0..opl3_chip.sizeof] = 0;

  for (slotnum = 0; slotnum < 36; ++slotnum) {
    chip.slot.ptr[slotnum].chip = chip;
    chip.slot.ptr[slotnum].mod = &chip.zeromod;
    chip.slot.ptr[slotnum].eg_rout = 0x1ff;
    chip.slot.ptr[slotnum].eg_out = 0x1ff;
    chip.slot.ptr[slotnum].eg_gen = envelope_gen_num_off;
    chip.slot.ptr[slotnum].trem = cast(ubyte*)&chip.zeromod;
  }
  for (channum = 0; channum < 18; ++channum) {
    chip.channel[channum].slots.ptr[0] = &chip.slot.ptr[ch_slot.ptr[channum]];
    chip.channel[channum].slots.ptr[1] = &chip.slot.ptr[ch_slot.ptr[channum]+3];
    chip.slot.ptr[ch_slot.ptr[channum]].channel = &chip.channel[channum];
    chip.slot.ptr[ch_slot.ptr[channum]+3].channel = &chip.channel[channum];
         if ((channum%9) < 3) chip.channel[channum].pair = &chip.channel[channum+3];
    else if ((channum%9) < 6) chip.channel[channum].pair = &chip.channel[channum-3];
    chip.channel[channum].chip = chip;
    chip.channel[channum].out_.ptr[0] = &chip.zeromod;
    chip.channel[channum].out_.ptr[1] = &chip.zeromod;
    chip.channel[channum].out_.ptr[2] = &chip.zeromod;
    chip.channel[channum].out_.ptr[3] = &chip.zeromod;
    chip.channel[channum].chtype = ch_2op;
    chip.channel[channum].cha = ushort.max;
    chip.channel[channum].chb = ushort.max;
    OPL3_ChannelSetupAlg(&chip.channel[channum]);
  }
  chip.noise = 0x306600;
  chip.rateratio = (samplerate<<RSM_FRAC)/49716;
  chip.tremoloshift = 4;
  chip.vibshift = 1;
}


///
public void OPL3_WriteReg (opl3_chip* chip, ushort reg, ubyte v) {
  ubyte high = (reg>>8)&0x01;
  ubyte regm = reg&0xff;
  switch (regm&0xf0) {
    case 0x00:
      if (high) {
        switch (regm&0x0f) {
          case 0x04:
            OPL3_ChannelSet4Op(chip, v);
            break;
          case 0x05:
            chip.newm = v&0x01;
            break;
          default: break;
        }
      } else {
        switch (regm&0x0f) {
          case 0x08:
            chip.nts = (v>>6)&0x01;
            break;
          default: break;
        }
      }
      break;
    case 0x20:
    case 0x30:
      if (ad_slot.ptr[regm&0x1f] >= 0) OPL3_SlotWrite20(&chip.slot.ptr[18*high+ad_slot.ptr[regm&0x1f]], v);
      break;
    case 0x40:
    case 0x50:
      if (ad_slot.ptr[regm&0x1f] >= 0) OPL3_SlotWrite40(&chip.slot.ptr[18*high+ad_slot.ptr[regm&0x1f]], v);
      break;
    case 0x60:
    case 0x70:
      if (ad_slot.ptr[regm&0x1f] >= 0) OPL3_SlotWrite60(&chip.slot.ptr[18*high+ad_slot.ptr[regm&0x1f]], v);
      break;
    case 0x80:
    case 0x90:
      if (ad_slot.ptr[regm&0x1f] >= 0) OPL3_SlotWrite80(&chip.slot.ptr[18*high+ad_slot.ptr[regm&0x1f]], v);
      break;
    case 0xe0:
    case 0xf0:
      if (ad_slot.ptr[regm&0x1f] >= 0) OPL3_SlotWriteE0(&chip.slot.ptr[18*high+ad_slot.ptr[regm&0x1f]], v);
      break;
    case 0xa0:
      if ((regm&0x0f) < 9) OPL3_ChannelWriteA0(&chip.channel[9*high+(regm&0x0f)], v);
      break;
    case 0xb0:
      if (regm == 0xbd && !high) {
        chip.tremoloshift = (((v>>7)^1)<<1)+2;
        chip.vibshift = ((v>>6)&0x01)^1;
        OPL3_ChannelUpdateRhythm(chip, v);
      } else if ((regm&0x0f) < 9) {
        OPL3_ChannelWriteB0(&chip.channel[9*high+(regm&0x0f)], v);
        if (v&0x20) OPL3_ChannelKeyOn(&chip.channel[9*high+(regm&0x0f)]); else OPL3_ChannelKeyOff(&chip.channel[9*high+(regm&0x0f)]);
      }
      break;
    case 0xc0:
      if ((regm&0x0f) < 9) OPL3_ChannelWriteC0(&chip.channel[9*high+(regm&0x0f)], v);
      break;
    default: break;
  }
}


///
public void OPL3_WriteRegBuffered (opl3_chip* chip, ushort reg, ubyte v) {
  ulong time1, time2;

  if (chip.writebuf[chip.writebuf_last].reg&0x200) {
    OPL3_WriteReg(chip, chip.writebuf[chip.writebuf_last].reg&0x1ff, chip.writebuf[chip.writebuf_last].data);
    chip.writebuf_cur = (chip.writebuf_last+1)%OPL_WRITEBUF_SIZE;
    chip.writebuf_samplecnt = chip.writebuf[chip.writebuf_last].time;
  }

  chip.writebuf[chip.writebuf_last].reg = reg|0x200;
  chip.writebuf[chip.writebuf_last].data = v;
  time1 = chip.writebuf_lasttime+OPL_WRITEBUF_DELAY;
  time2 = chip.writebuf_samplecnt;

  if (time1 < time2) time1 = time2;

  chip.writebuf[chip.writebuf_last].time = time1;
  chip.writebuf_lasttime = time1;
  chip.writebuf_last = (chip.writebuf_last+1)%OPL_WRITEBUF_SIZE;
}


///
public void OPL3_GenerateStream (opl3_chip* chip, short* sndptr, uint numsamples) {
  foreach (immutable _; 0..numsamples) {
    OPL3_GenerateResampled(chip, sndptr);
    sndptr += 2;
  }
}
