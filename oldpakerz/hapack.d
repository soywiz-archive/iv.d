/***********************************************************************
 * This file is part of HA, a general purpose file archiver.
 * Copyright (C) 1995 Harri Hirvola
 * Modified by Ketmar // Invisible Vector
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 ***********************************************************************/
module iv.oldpakerz.hapack /*is aliced*/;
private:
import iv.alice;


// ////////////////////////////////////////////////////////////////////////// //
alias libha_read_fn = int delegate (void *buf, int buf_len); // return number of bytes read; 0: EOF; <0: error; can be less than buf_len
alias libha_write_fn = int delegate (const(void)* buf, int buf_len); // result != buf_len: error


// ////////////////////////////////////////////////////////////////////////// //
public alias libha_t = libha_s*;


// ////////////////////////////////////////////////////////////////////////// //
// some constants
// ////////////////////////////////////////////////////////////////////////// //
// ASC
enum POSCODES = 31200; // also, dictionary buffer len for SWD
enum SLCODES = 16;
enum LLCODES = 48;
enum LLLEN = 16;
enum LLBITS = 4;
enum LLMASK = LLLEN-1;
enum LENCODES = SLCODES+LLCODES*LLLEN;
enum LTCODES = SLCODES+LLCODES;
enum CTCODES = 256;
enum PTCODES = 16;
enum LTSTEP = 8;
enum MAXLT = 750*LTSTEP;
enum CTSTEP = 1;
enum MAXCT = 1000*CTSTEP;
enum PTSTEP = 24;
enum MAXPT = 250*PTSTEP;
enum TTSTEP = 40;
enum MAXTT = 150*TTSTEP;
enum TTORD = 4;
enum TTOMASK = TTORD-1;
enum LCUTOFF = 3*LTSTEP;
enum CCUTOFF = 3*CTSTEP;
enum CPLEN = 8;
enum LPLEN = 4;
enum MINLENLIM = 4096;

// SWD
// Minimum possible match lenght for this implementation
enum MINLEN = 3;
enum HSIZE = 16384;
enum HSHIFT = 3;
enum MAXCNT = 1024;
// derived
enum MAXFLEN = LENCODES+MINLEN-1;  // max len to be found
enum MAXDLEN = POSCODES+MAXFLEN;   // reserved bytes for dict; POSCODES+2*MAXFLEN-1<32768 !!!

enum HASH(string p) = "((swd.b["~p~"]^((swd.b["~p~"+1]^(swd.b["~p~"+2]<<HSHIFT))<<HSHIFT))&(HSIZE-1))";


// ////////////////////////////////////////////////////////////////////////// //
struct io_t {
  libha_read_fn bread;
  libha_write_fn bwrite;
  // input buffer
  ubyte *bufin;
  int bufin_pos;
  int bufin_max;
  int bufin_size;
  // output buffer
  ubyte *bufout;
  int bufout_pos;
  int bufout_size;
}


// ////////////////////////////////////////////////////////////////////////// //
int get_byte (io_t *io) {
  if (io.bufin_pos >= io.bufin_max) {
    if (io.bufin_pos < io.bufin_size+1) {
      io.bufin_pos = 0;
      io.bufin_max = io.bread(io.bufin, io.bufin_size);
      if (io.bufin_max < 0) throw new Exception("read error");
      if (io.bufin_max == 0) { io.bufin_pos = io.bufin_size+42; return -1; } // EOF
    } else {
      return -1; // EOF
    }
  }
  return io.bufin[io.bufin_pos++];
}


void put_byte (io_t *io, int c) {
  if (io.bufout_pos >= io.bufout_size) {
    int res = io.bwrite(io.bufout, io.bufout_pos);
    if (res != io.bufout_pos) throw new Exception("write error");
    io.bufout_pos = 0;
  }
  io.bufout[io.bufout_pos++] = c&0xff;
}


void flush (io_t *io) {
  if (io.bufout_pos > 0) {
    int res = io.bwrite(io.bufout, io.bufout_pos);
    if (res != io.bufout_pos) throw new Exception("write error");
    io.bufout_pos = 0;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
struct swd_t {
  ushort swd_bpos, swd_mlf;
  short swd_char;
  ushort cblen, binb;
  ushort bbf, bbl, inptr;
  ushort[HSIZE] ccnt;
  ushort[MAXDLEN] ll;
  ushort[HSIZE] cr;
  ushort[MAXDLEN] best;
  ubyte[MAXDLEN+MAXFLEN] b; // was:-1
  ushort blen, iblen;
  io_t *io;
}


void swd_init (swd_t *swd) {
  import core.stdc.string : memset;
  memset(swd.ccnt.ptr, 0, swd.ccnt.sizeof);
  memset(swd.ll.ptr, 0, swd.ll.sizeof);
  memset(swd.cr.ptr, 0, swd.cr.sizeof);
  memset(swd.best.ptr, 0, swd.best.sizeof);
  memset(swd.b.ptr, 0, swd.b.sizeof);
  swd.binb = swd.bbf = swd.bbl = swd.inptr = 0;
  swd.swd_mlf = MINLEN-1;
}


// return -1 on EOF or 0
int swd_first_bytes (swd_t *swd) {
  while (swd.bbl < MAXFLEN) {
    int b = get_byte(swd.io);
    if (b < 0) return -1;
    swd.b[swd.inptr++] = cast(ubyte)b;
    ++swd.bbl;
  }
  return 0;
}


void swd_accept (swd_t *swd) {
  short j = cast(short)(swd.swd_mlf-2);
  // relies on non changed swd.swd_mlf !!!
  do {
    short i;
    if (swd.binb == POSCODES) --swd.ccnt[mixin(HASH!"swd.inptr")]; else ++swd.binb;
    i = mixin(HASH!"swd.bbf");
    swd.ll[swd.bbf] = swd.cr[i];
    swd.cr[i] = swd.bbf;
    swd.best[swd.bbf] = 30000;
    ++swd.ccnt[i];
    if (++swd.bbf == MAXDLEN) swd.bbf = 0;
    if ((i = cast(short)get_byte(swd.io)) < 0) {
      --swd.bbl;
      if (++swd.inptr == MAXDLEN) swd.inptr = 0;
      continue;
    }
    if (swd.inptr < MAXFLEN-1) {
      swd.b[swd.inptr+MAXDLEN] = swd.b[swd.inptr] = cast(ubyte)i;
      ++swd.inptr;
    } else {
      swd.b[swd.inptr] = cast(ubyte)i;
      if (++swd.inptr == MAXDLEN) swd.inptr = 0;
    }
  } while (--j);
  swd.swd_mlf = MINLEN-1;
}


void swd_findbest (swd_t *swd) {
  ushort ref_, ptr, start_len;
  int ch;
  ushort i = mixin(HASH!"swd.bbf");
  ushort cnt = swd.ccnt[i];
  ++swd.ccnt[i];
  if (cnt > MAXCNT) cnt = MAXCNT;
  ptr = swd.ll[swd.bbf] = swd.cr[i];
  swd.cr[i] = swd.bbf;
  swd.swd_char = swd.b[swd.bbf];
  if ((start_len = swd.swd_mlf) >= swd.bbl) {
    if (swd.bbl == 0) swd.swd_char = -1;
    swd.best[swd.bbf] = 30000;
  } else {
    for (ref_ = swd.b[swd.bbf+swd.swd_mlf-1]; cnt--; ptr = swd.ll[ptr]) {
      if (swd.b[ptr+swd.swd_mlf-1] == ref_ && swd.b[ptr] == swd.b[swd.bbf] && swd.b[ptr+1] == swd.b[swd.bbf+1]) {
        ubyte *p1 = swd.b.ptr+ptr+3;
        ubyte *p2 = swd.b.ptr+swd.bbf+3;
        for (i = 3; i < swd.bbl; ++i) if (*p1++ != *p2++) break;
        if (i <= swd.swd_mlf) continue;
        swd.swd_bpos = ptr;
        if ((swd.swd_mlf = i) == swd.bbl || swd.best[ptr] < i) break;
        ref_ = swd.b[swd.bbf+swd.swd_mlf-1];
      }
    }
    swd.best[swd.bbf] = swd.swd_mlf;
    if (swd.swd_mlf > start_len) {
      if (swd.swd_bpos < swd.bbf) {
        swd.swd_bpos = cast(ushort)(swd.bbf-swd.swd_bpos-1);
      } else {
        swd.swd_bpos = cast(ushort)(MAXDLEN-1-swd.swd_bpos+swd.bbf);
      }
    }
  }
  if (swd.binb == POSCODES) --swd.ccnt[mixin(HASH!"swd.inptr")]; else ++swd.binb;
  if (++swd.bbf == MAXDLEN) swd.bbf = 0;
  if ((ch = get_byte(swd.io)) < 0) {
    --swd.bbl;
    if (++swd.inptr == MAXDLEN) swd.inptr = 0;
    return;
  }
  if (swd.inptr < MAXFLEN-1) {
    swd.b[swd.inptr+MAXDLEN] = swd.b[swd.inptr] = cast(ubyte)ch;
    ++swd.inptr;
  } else {
    swd.b[swd.inptr] = cast(ubyte)ch;
    if (++swd.inptr == MAXDLEN) swd.inptr = 0;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
struct ari_t {
  ushort h, l, v;
  short s;
  short gpat, ppat;
  io_t *io;
}


// ////////////////////////////////////////////////////////////////////////// //
// Bit I/O
enum putbit(string b) = "{
  ari.ppat <<= 1;
  if ("~b~") ari.ppat |= 1;
  if (ari.ppat&0x100) {
    put_byte(ari.io, ari.ppat&0xff);
    ari.ppat = 1;
  }
}";


// ////////////////////////////////////////////////////////////////////////// //
// Arithmetic encoding
void ac_out (ari_t *ari, ushort low, ushort high, ushort tot) {
  uint r;
  if (tot == 0) throw new Exception("data error");
  r = cast(uint)(ari.h-ari.l)+1;
  ari.h = cast(ushort)(cast(ushort)(r*high/tot-1)+ari.l);
  ari.l += cast(ushort)(r*low/tot);
  if (!((ari.h^ari.l)&0x8000)) {
    mixin(putbit!"ari.l&0x8000");
    while (ari.s) {
      --ari.s;
      mixin(putbit!"~ari.l&0x8000");
    }
    ari.l <<= 1;
    ari.h <<= 1;
    ari.h |= 1;
    while (!((ari.h^ari.l)&0x8000)) {
      mixin(putbit!"ari.l&0x8000");
      ari.l <<= 1;
      ari.h <<= 1;
      ari.h |= 1;
    }
  }
  while ((ari.l&0x4000) && !(ari.h&0x4000)) {
    ++ari.s;
    ari.l <<= 1;
    ari.l &= 0x7fff;
    ari.h <<= 1;
    ari.h |= 0x8001;
  }
}


void ac_init_encode (ari_t *ari) {
  ari.h = 0xffff;
  ari.l = ari.s = 0;
  ari.ppat = 1;
}


void ac_end_encode (ari_t *ari) {
  ++ari.s;
  mixin(putbit!"ari.l&0x4000");
  while (ari.s--) {
    mixin(putbit!"~ari.l&0x4000");
  }
  if (ari.ppat == 1) {
    flush(ari.io);
    return;
  }
  while (!(ari.ppat&0x100)) ari.ppat <<= 1;
  put_byte(ari.io, ari.ppat&0xff);
  flush(ari.io);
}


// ////////////////////////////////////////////////////////////////////////// //
enum BUFIN_SIZE = 1024;
enum BUFOUT_SIZE = 1024;


struct libha_s {
  ushort[2*LTCODES] ltab;
  ushort[2*LTCODES] eltab;
  ushort[2*PTCODES] ptab;
  ushort[2*CTCODES] ctab;
  ushort[2*CTCODES] ectab;
  ushort[2][TTORD] ttab;
  ushort accnt, pmax, npt;
  ushort ces;
  ushort les;
  ushort ttcon;
  swd_t swd;
  ari_t ari;
  io_t io;
  ubyte[BUFIN_SIZE] bufin;
  ubyte[BUFOUT_SIZE] bufout;
  // step
  short fldOc;
  ushort fldOmlf, fldObpos;
  int phase; // 0: not initialized; 1: in progress; <0: error
}
version(oldpack_sizes) pragma(msg, libha_s.sizeof); // ~200 KB, wow!


void setup_buffers (libha_t asc) {
  asc.io.bufin = asc.bufin.ptr;
  asc.io.bufin_size = asc.bufin.sizeof;
  asc.io.bufin_pos = 0;
  asc.io.bufin_max = 0;
  asc.io.bufout = asc.bufout.ptr;
  asc.io.bufout_size = asc.bufout.sizeof;
  asc.io.bufout_pos = 0;
}


void tabinit (ushort[] t, ushort tl, ushort ival) {
  uint i, j;
  for (i = tl; i < 2*tl; ++i) t[i] = ival;
  for (i = tl-1, j = (tl<<1)-2; i; --i, j -= 2) t[i] = cast(ushort)(t[j]+t[j+1]);
}


void tscale (ushort[] t, ushort tl) {
  uint i, j;
  for (i = (tl<<1)-1; i >= tl; --i) if (t[i] > 1) t[i] >>= 1;
  for (i = tl-1, j = (tl<<1)-2; i; --i, j -= 2) t[i] = cast(ushort)(t[j]+t[j+1]);
}


void tupd (ushort[] t, ushort tl, ushort maxt, ushort step, ushort p) {
  int i;
  for (i = p+tl; i; i >>= 1) t[i] += step;
  if (t[1] >= maxt) tscale(t, tl);
}


void tzero (ushort[] t, ushort tl, ushort p) {
  int i;
  short step;
  for (i = p+tl, step = t[i]; i; i >>= 1) t[i] -= step;
}


void model_init (libha_t asc) {
  short i;
  asc.ces = CTSTEP;
  asc.les = LTSTEP;
  asc.accnt = 0;
  asc.ttcon = 0;
  asc.npt = asc.pmax = 1;
  for (i = 0; i < TTORD; ++i) asc.ttab[i][0] = asc.ttab[i][1] = TTSTEP;
  tabinit(asc.ltab, LTCODES, 0);
  tabinit(asc.eltab, LTCODES, 1);
  tabinit(asc.ctab, CTCODES, 0);
  tabinit(asc.ectab, CTCODES, 1);
  tabinit(asc.ptab, PTCODES, 0);
  tupd(asc.ptab, PTCODES, MAXPT, PTSTEP, 0);
}


void pack_init (libha_t asc) {
  model_init(asc);
  ac_init_encode(&asc.ari);
}


void ttscale (libha_t asc, ushort con) {
  asc.ttab[con][0] >>= 1;
  if (asc.ttab[con][0] == 0) asc.ttab[con][0] = 1;
  asc.ttab[con][1] >>= 1;
  if (asc.ttab[con][1] == 0) asc.ttab[con][1] = 1;
}


void codepair (libha_t asc, short l, short p) {
  ushort i, j, lt, k, cf, tot;
  i = cast(ushort)(asc.ttab[asc.ttcon][0]+asc.ttab[asc.ttcon][1]);
  ac_out(&asc.ari, asc.ttab[asc.ttcon][0], i, cast(ushort)(i+1)); // writes
  asc.ttab[asc.ttcon][1] += TTSTEP;
  if (i >= MAXTT) ttscale(asc, asc.ttcon);
  asc.ttcon = ((asc.ttcon<<1)|1)&TTOMASK;
  while (asc.accnt > asc.pmax) {
    tupd(asc.ptab, PTCODES, MAXPT, PTSTEP, asc.npt++);
    asc.pmax <<= 1;
  }
  for (i = p, j = 0; i; ++j, i >>= 1) {}
  cf = asc.ptab[PTCODES+j];
  tot = asc.ptab[1];
  for (lt = 0, i = cast(ushort)(PTCODES+j); i; i >>= 1) {
    if (i&1) lt += asc.ptab[i-1];
    asc.ptab[i] += PTSTEP;
  }
  if (asc.ptab[1] >= MAXPT) tscale(asc.ptab, PTCODES);
  ac_out(&asc.ari, lt, cast(ushort)(lt+cf), tot); // writes
  if (p > 1) {
    for (i = 0x8000U; !(p&i); i >>= 1) {}
    j = p&~i;
    if (i != (asc.pmax>>1)) {
      ac_out(&asc.ari, j, cast(ushort)(j+1), i); // writes
    } else {
      ac_out(&asc.ari, j, cast(ushort)(j+1), cast(ushort)(asc.accnt-(asc.pmax>>1))); // writes
    }
  }
  i = cast(ushort)(l-MINLEN);
  if (i == LENCODES-1) {
    i = SLCODES-1, j = 0xffff;
  } else if (i < SLCODES-1) {
    j = 0xffff;
  } else {
    j = (i-SLCODES+1)&LLMASK;
    i = ((i-SLCODES+1)>>LLBITS)+SLCODES;
  }
  if ((cf = asc.ltab[LTCODES+i]) == 0) {
    ac_out(&asc.ari, asc.ltab[1], cast(ushort)(asc.ltab[1]+asc.les), cast(ushort)(asc.ltab[1]+asc.les)); // writes
    for (lt = 0, k = cast(ushort)(LTCODES+i); k; k >>= 1) {
      if (k&1) lt += asc.eltab[k-1];
      asc.ltab[k] += LTSTEP;
    }
    if (asc.ltab[1] >= MAXLT) tscale(asc.ltab, LTCODES);
    ac_out(&asc.ari, lt, cast(ushort)(lt+asc.eltab[LTCODES+i]), asc.eltab[1]); // writes
    tzero(asc.eltab, LTCODES, i);
    if (asc.eltab[1] != 0) asc.les += LTSTEP; else asc.les = 0;
    for (k = cast(ushort)(i <= LPLEN ? 0 : i-LPLEN); k < (i+LPLEN >= LTCODES-1 ? LTCODES-1 : i+LPLEN); ++k) {
      if (asc.eltab[LTCODES+k]) tupd(asc.eltab, LTCODES, MAXLT, 1, k);
    }
  } else {
    tot = cast(ushort)(asc.ltab[1]+asc.les);
    for (lt = 0, k = cast(ushort)(LTCODES+i); k; k >>= 1) {
      if (k&1) lt += asc.ltab[k-1];
      asc.ltab[k] += LTSTEP;
    }
    if (asc.ltab[1] >= MAXLT) tscale(asc.ltab, LTCODES);
    ac_out(&asc.ari, lt, cast(ushort)(lt+cf), tot); // writes
  }
  if (asc.ltab[LTCODES+i] == LCUTOFF) asc.les -= (LTSTEP < asc.les ? LTSTEP : asc.les-1);
  if (j != 0xffff) ac_out(&asc.ari, j, cast(ushort)(j+1), LLLEN); // writes
  if (asc.accnt < POSCODES) {
    asc.accnt += l;
    if (asc.accnt > POSCODES) asc.accnt = POSCODES;
  }
}


void codechar (libha_t asc, short c) {
  ushort i, lt, tot, cf;
  i = cast(ushort)(asc.ttab[asc.ttcon][0]+asc.ttab[asc.ttcon][1]);
  ac_out(&asc.ari, 0, asc.ttab[asc.ttcon][0], cast(ushort)(i+1)); // writes
  asc.ttab[asc.ttcon][0] += TTSTEP;
  if (i >= MAXTT) ttscale(asc, asc.ttcon);
  asc.ttcon = (asc.ttcon<<1)&TTOMASK;
  if ((cf = asc.ctab[CTCODES+c]) == 0) {
    ac_out(&asc.ari, asc.ctab[1], cast(ushort)(asc.ctab[1]+asc.ces), cast(ushort)(asc.ctab[1]+asc.ces)); // writes
    for (lt = 0, i = cast(ushort)(CTCODES+c); i; i >>= 1) {
      if (i&1) lt += asc.ectab[i-1];
      asc.ctab[i] += CTSTEP;
    }
    if (asc.ctab[1] >= MAXCT) tscale(asc.ctab, CTCODES);
    ac_out(&asc.ari, lt, cast(ushort)(lt+asc.ectab[CTCODES+c]), asc.ectab[1]); // writes
    tzero(asc.ectab, CTCODES, c);
    if (asc.ectab[1] != 0) asc.ces += CTSTEP; else asc.ces = 0;
    for (i = cast(ushort)(c <= CPLEN ? 0 : c-CPLEN); i < (c+CPLEN >= CTCODES-1 ? CTCODES-1 : c+CPLEN); ++i) {
      if (asc.ectab[CTCODES+i]) tupd(asc.ectab, CTCODES, MAXCT, 1, i);
    }
  } else {
    tot = cast(ushort)(asc.ctab[1]+asc.ces);
    for (lt = 0, i = cast(ushort)(CTCODES+c); i; i >>= 1) {
      if (i&1) lt += asc.ctab[i-1];
      asc.ctab[i] += CTSTEP;
    }
    if (asc.ctab[1] >= MAXCT) tscale(asc.ctab, CTCODES);
    ac_out(&asc.ari, lt, cast(ushort)(lt+cf), tot); // writes
  }
  if (asc.ctab[CTCODES+c] == CCUTOFF) asc.ces -= (CTSTEP < asc.ces ? CTSTEP : asc.ces-1);
  if (asc.accnt < POSCODES) ++asc.accnt;
}


// ////////////////////////////////////////////////////////////////////////// //
public libha_t libha_create () {
  import core.stdc.stdlib : calloc;
  return cast(libha_t)calloc(1, libha_s.sizeof);
}


public void libha_free (libha_t asc) {
  import core.stdc.stdlib : free;
  if (asc != null) free(asc);
}


public void libha_reset (libha_t asc) {
  if (asc !is null) {
    import core.stdc.string : memset;
    memset(asc, 0, (*asc).sizeof);
  }
}


// return `false` when finished, or `true` if packer needs more steps
public bool libha_pack_step (libha_t asc, libha_read_fn rd, libha_write_fn wr) {
  //swd_findbest(): reads
  if (asc is null || asc.phase < 0 || rd is null || wr is null) throw new Exception("hapack error");
  asc.io.bread = rd;
  asc.io.bwrite = wr;
  asc.swd.io = asc.ari.io = &asc.io;
  scope(exit) {
    asc.io.bread = null;
    asc.io.bwrite = null;
    asc.swd.io = asc.ari.io = null;
  }
  // init?
  if (asc.phase == 0) {
    asc.phase = -1; // so throw will end up in error
    setup_buffers(asc);
    swd_init(&asc.swd);
    swd_first_bytes(&asc.swd); // reads MAXFLEN bytes
    pack_init(asc);
    swd_findbest(&asc.swd);
    asc.phase = 1;
  }
  assert(asc.phase == 1);
  if (asc.swd.swd_char < 0) {
    // finish
    asc.phase = -1; // so next call will end up in error
    ac_out(&asc.ari, cast(ushort)(asc.ttab[asc.ttcon][0]+asc.ttab[asc.ttcon][1]), cast(ushort)(asc.ttab[asc.ttcon][0]+asc.ttab[asc.ttcon][1]+1), cast(ushort)(asc.ttab[asc.ttcon][0]+asc.ttab[asc.ttcon][1]+1));
    ac_end_encode(&asc.ari);
    return false;
  }
  if (asc.swd.swd_mlf > MINLEN || (asc.swd.swd_mlf == MINLEN && asc.swd.swd_bpos < MINLENLIM)) {
    asc.fldOmlf = asc.swd.swd_mlf;
    asc.fldObpos = asc.swd.swd_bpos;
    asc.fldOc = asc.swd.swd_char;
    swd_findbest(&asc.swd); // reads
    if (asc.swd.swd_mlf > asc.fldOmlf) {
      codechar(asc, asc.fldOc);
    } else {
      swd_accept(&asc.swd); // reads
      codepair(asc, asc.fldOmlf, asc.fldObpos);
      swd_findbest(&asc.swd); // reads
    }
  } else {
    asc.swd.swd_mlf = MINLEN-1;
    codechar(asc, asc.swd.swd_char);
    swd_findbest(&asc.swd); // reads
  }
  asc.phase = 1; // go on
  return true;
}
