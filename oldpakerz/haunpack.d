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
// stand-alone unpacker
module iv.oldpakerz.haunpack is aliced;
private:


// ////////////////////////////////////////////////////////////////////////// //
// <0: error; 0: EOF; >0: bytes read (can be less that buf_len)
// buf_len can never be negative or zero; it will not be more that INT_MAX/2-1 either
public alias haunp_bread_fn_t = int delegate (void* buf, int buf_len);


public alias haunp_t = haunp_s*;


// ////////////////////////////////////////////////////////////////////////// //
enum POSCODES = 31200;
enum SLCODES = 16;
enum LLCODES = 48;
enum LLLEN = 16;
enum LLBITS = 4;
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


// ////////////////////////////////////////////////////////////////////////// //
struct haunp_s {
  enum RD_BUF_SIZE = 1024;
  // hup
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
  // swd
  ubyte[POSCODES] dict;
  ushort dict_pos;
  ushort dict_pair_len;
  ushort dict_pair_pos;
  // ari
  ushort ari_h, ari_l, ari_v;
  short ari_s;
  short ari_gpat, ari_ppat;
  int ari_init_done;
  // reader
  haunp_bread_fn_t reader;
  ubyte[RD_BUF_SIZE] rd_buf;
  int rd_pos;
  int rd_max;
  bool no_more; // high-level flag: don't call read callback anymore
  // unpacker
  int done;
}
version(oldpack_sizes) pragma(msg, haunp_s.sizeof);


// ////////////////////////////////////////////////////////////////////////// //
void tabinit (ushort[] t, ushort tl, ushort ival) {
  /*ushort*/uint i, j;
  for (i = tl; i < 2*tl; ++i) t[i] = ival;
  for (i = tl-1, j = (tl<<1)-2; i; --i, j -= 2) t[i] = cast(ushort)(t[j]+t[j+1]);
}


void tscale (ushort[] t, ushort tl) {
  /*ushort*/uint i, j;
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


void ttscale (haunp_t hup, ushort con) {
  hup.ttab[con][0] >>= 1;
  if (hup.ttab[con][0] == 0) hup.ttab[con][0] = 1;
  hup.ttab[con][1] >>= 1;
  if (hup.ttab[con][1] == 0) hup.ttab[con][1] = 1;
}


// ////////////////////////////////////////////////////////////////////////// //
// return number of bytes copied (can be less thatn olen)
int swd_do_pair (haunp_t hup, ubyte* obuf, int olen) {
  int todo = (olen > hup.dict_pair_len ? hup.dict_pair_len : olen);
  int res = todo;
  hup.dict_pair_len -= todo;
  while (todo-- > 0) {
    hup.dict[hup.dict_pos] = hup.dict[hup.dict_pair_pos];
    *obuf++ = hup.dict[hup.dict_pair_pos];
    if (++hup.dict_pos == POSCODES) hup.dict_pos = 0;
    if (++hup.dict_pair_pos == POSCODES) hup.dict_pair_pos = 0;
  }
  return res;
}


// ////////////////////////////////////////////////////////////////////////// //
// Arithmetic decoding

// read next byte (buffered)
enum getbyte(string bto) = "{
  if (hup.rd_pos >= hup.rd_max && !hup.no_more) {
    hup.rd_pos = 0;
    hup.rd_max = hup.reader(hup.rd_buf.ptr, hup.RD_BUF_SIZE);
    hup.no_more = (hup.rd_max <= 0);
    if (hup.rd_max < 0) throw new Exception(`read error`);
  }
  "~bto~" = (!hup.no_more ? hup.rd_buf[hup.rd_pos++] : -1);
}";


enum getbit(string b) = "{
  hup.ari_gpat <<= 1;
  if (!(hup.ari_gpat&0xff)) {
    "~getbyte!"hup.ari_gpat"~"
    if (hup.ari_gpat&0x100) {
      hup.ari_gpat = 0x100;
    } else {
      hup.ari_gpat <<= 1;
      hup.ari_gpat |= 1;
    }
  }
  "~b~" |= (hup.ari_gpat&0x100)>>8;
}";


void ac_in (haunp_t hup, ushort low, ushort high, ushort tot) {
  uint r;
  if (tot == 0) throw new Exception("bad data");
  r = cast(uint)(hup.ari_h-hup.ari_l)+1;
  hup.ari_h = cast(ushort)(cast(ushort)(r*high/tot-1)+hup.ari_l);
  hup.ari_l += cast(ushort)(r*low/tot);
  while (!((hup.ari_h^hup.ari_l)&0x8000)) {
    hup.ari_l <<= 1;
    hup.ari_h <<= 1;
    hup.ari_h |= 1;
    hup.ari_v <<= 1;
    mixin(getbit!"hup.ari_v");
  }
  while ((hup.ari_l&0x4000) && !(hup.ari_h&0x4000)) {
    hup.ari_l <<= 1;
    hup.ari_l &= 0x7fff;
    hup.ari_h <<= 1;
    hup.ari_h |= 0x8001;
    hup.ari_v <<= 1;
    hup.ari_v ^= 0x8000;
    mixin(getbit!"hup.ari_v");
  }
}


ushort ac_threshold_val (haunp_t hup, ushort tot) {
  uint r = cast(uint)(hup.ari_h-hup.ari_l)+1;
  if (r == 0) throw new Exception("bad data");
  return cast(ushort)(((cast(uint)(hup.ari_v-hup.ari_l)+1)*tot-1)/r);
}


// ////////////////////////////////////////////////////////////////////////// //
void libha_unpack (haunp_t hup, ubyte* obuf, int olen) {
  //ushort l, p, tv, i, lt;
  hup.done = 0;
  if (hup.no_more) return;
  // complete defered ari initialization
  if (!hup.ari_init_done) {
    int b;
    hup.ari_init_done = 1;
    mixin(getbyte!"b");
    if (b < 0) throw new Exception("read error");
    hup.ari_v = cast(ushort)(b<<8);
    mixin(getbyte!"b");
    if (b < 0) throw new Exception("read error");
    hup.ari_v |= b;
  }
 do_pair:
  // if we have some data in dictionary, copy it
  if (hup.dict_pair_len) {
    int d = swd_do_pair(hup, obuf, olen);
    hup.done += d;
    if ((olen -= d) == 0) return;
    obuf += d;
  }
  // main unpacking loop; olen is definitely positive here
  do {
    ushort l, p, lt;
    ushort tv = ac_threshold_val(hup, cast(ushort)(hup.ttab[hup.ttcon][0]+hup.ttab[hup.ttcon][1]+1));
    ushort i = cast(ushort)(hup.ttab[hup.ttcon][0]+hup.ttab[hup.ttcon][1]);
    if (hup.ttab[hup.ttcon][0] > tv) {
      ac_in(hup, 0, hup.ttab[hup.ttcon][0], cast(ushort)(i+1));
      hup.ttab[hup.ttcon][0] += TTSTEP;
      if (i >= MAXTT) ttscale(hup, hup.ttcon);
      hup.ttcon = (hup.ttcon<<1)&TTOMASK;
      tv = ac_threshold_val(hup, cast(ushort)(hup.ctab[1]+hup.ces));
      if (tv >= hup.ctab[1]) {
        ac_in(hup, hup.ctab[1], cast(ushort)(hup.ctab[1]+hup.ces), cast(ushort)(hup.ctab[1]+hup.ces));
        tv = ac_threshold_val(hup, hup.ectab[1]);
        l = 2;
        lt = 0;
        for (;;) {
          if (lt+hup.ectab[l] <= tv) { lt += hup.ectab[l]; ++l; }
          if (l >= CTCODES) { l -= CTCODES; break; }
          l <<= 1;
        }
        ac_in(hup, lt, cast(ushort)(lt+hup.ectab[CTCODES+l]), hup.ectab[1]);
        tzero(hup.ectab, CTCODES, l);
        if (hup.ectab[1] != 0) hup.ces += CTSTEP; else hup.ces = 0;
        for (i = cast(ushort)(l < CPLEN ? 0 : l-CPLEN); i < (l+CPLEN >= CTCODES-1 ? CTCODES-1 : l+CPLEN); ++i) {
          if (hup.ectab[CTCODES+i]) tupd(hup.ectab, CTCODES, MAXCT, 1, i);
        }
      } else {
        l = 2;
        lt = 0;
        for (;;) {
          if (lt+hup.ctab[l] <= tv) { lt += hup.ctab[l]; ++l; }
          if (l >= CTCODES) { l -= CTCODES; break; }
          l <<= 1;
        }
        ac_in(hup, lt, cast(ushort)(lt+hup.ctab[CTCODES+l]), cast(ushort)(hup.ctab[1]+hup.ces));
      }
      tupd(hup.ctab, CTCODES, MAXCT, CTSTEP, l);
      if (hup.ctab[CTCODES+l] == CCUTOFF) hup.ces -= (CTSTEP < hup.ces ? CTSTEP : hup.ces-1);
      // literal char from dictionary
      hup.dict[hup.dict_pos] = cast(ubyte)l;
      if (++hup.dict_pos == POSCODES) hup.dict_pos = 0;
      // asc decoder
      if (hup.accnt < POSCODES) ++hup.accnt;
      // output char
      *obuf++ = cast(ubyte)l;
      --olen;
      ++hup.done;
    } else if (i > tv) {
      ac_in(hup, hup.ttab[hup.ttcon][0], i, cast(ushort)(i+1));
      hup.ttab[hup.ttcon][1] += TTSTEP;
      if (i >= MAXTT) ttscale(hup, hup.ttcon);
      hup.ttcon = ((hup.ttcon<<1)|1)&TTOMASK;
      while (hup.accnt > hup.pmax) {
        tupd(hup.ptab, PTCODES, MAXPT, PTSTEP, hup.npt++);
        hup.pmax <<= 1;
      }
      tv = ac_threshold_val(hup, hup.ptab[1]);
      p = 2;
      lt = 0;
      for (;;) {
        if (lt+hup.ptab[p] <= tv) { lt += hup.ptab[p]; ++p; }
        if (p >= PTCODES) { p -= PTCODES; break; }
        p <<= 1;
      }
      ac_in(hup, lt, cast(ushort)(lt+hup.ptab[PTCODES+p]), hup.ptab[1]);
      tupd(hup.ptab, PTCODES, MAXPT, PTSTEP, p);
      if (p > 1) {
        for (i = 1; p; i <<= 1, --p) {}
        i >>= 1;
        l = cast(ushort)(i == hup.pmax>>1 ? hup.accnt-(hup.pmax>>1) : i);
        p = ac_threshold_val(hup, l);
        ac_in(hup, p, cast(ushort)(p+1), l);
        p += i;
      }
      tv = ac_threshold_val(hup, cast(ushort)(hup.ltab[1]+hup.les));
      if (tv >= hup.ltab[1]) {
        ac_in(hup, hup.ltab[1], cast(ushort)(hup.ltab[1]+hup.les), cast(ushort)(hup.ltab[1]+hup.les));
        tv = ac_threshold_val(hup, hup.eltab[1]);
        l = 2;
        lt = 0;
        for (;;) {
          if (lt+hup.eltab[l] <= tv) { lt += hup.eltab[l]; ++l; }
          if (l >= LTCODES) { l -= LTCODES; break; }
          l <<= 1;
        }
        ac_in(hup, lt, cast(ushort)(lt+hup.eltab[LTCODES+l]), hup.eltab[1]);
        tzero(hup.eltab, LTCODES, l);
        if (hup.eltab[1] != 0) hup.les += LTSTEP; else hup.les = 0;
        for (i = cast(ushort)(l < LPLEN ? 0 : l-LPLEN); i < (l+LPLEN >= LTCODES-1 ? LTCODES-1 : l+LPLEN); ++i) {
          if (hup.eltab[LTCODES+i]) tupd(hup.eltab, LTCODES, MAXLT, 1, i);
        }
      } else {
        l = 2;
        lt = 0;
        for (;;) {
          if (lt+hup.ltab[l] <= tv) { lt += hup.ltab[l]; ++l; }
          if (l >= LTCODES) { l -= LTCODES; break; }
          l <<= 1;
        }
        ac_in(hup, lt, cast(ushort)(lt+hup.ltab[LTCODES+l]), cast(ushort)(hup.ltab[1]+hup.les));
      }
      tupd(hup.ltab, LTCODES, MAXLT, LTSTEP, l);
      if (hup.ltab[LTCODES+l] == LCUTOFF) hup.les -= (LTSTEP < hup.les ? LTSTEP : hup.les-1);
      if (l == SLCODES-1) {
        l = LENCODES-1;
      } else if (l >= SLCODES) {
        i = ac_threshold_val(hup, LLLEN);
        ac_in(hup, i, cast(ushort)(i+1), LLLEN);
        l = cast(ushort)(((l-SLCODES)<<LLBITS)+i+SLCODES-1);
      }
      l += 3;
      if (hup.accnt < POSCODES) {
        hup.accnt += l;
        if (hup.accnt > POSCODES) hup.accnt = POSCODES;
      }
      // pair from dictionary
      if (hup.dict_pos > p) {
        hup.dict_pair_pos = cast(ushort)(hup.dict_pos-1-p);
      } else {
        hup.dict_pair_pos = cast(ushort)(POSCODES-1-p+hup.dict_pos);
      }
      hup.dict_pair_len = l;
      goto do_pair; // recursive tail call
    } else {
      // EOF
      // ac_in(hup, i, i+1, i+1); don't need this
      hup.no_more = true;
      break;
    }
  } while (olen > 0);
}


// ////////////////////////////////////////////////////////////////////////// //
public haunp_t haunp_create () {
  import core.stdc.stdlib : calloc;
  haunp_t hup = cast(haunp_t)calloc(1, (*haunp_t).sizeof);
  if (hup != null) haunp_reset(hup);
  return hup;
}


public void haunp_free (haunp_t hup) {
  import core.stdc.stdlib : free;
  if (hup !is null) free(hup);
}


public void haunp_reset (haunp_t hup) {
  if (hup !is null) {
    import core.stdc.string : memset;
    memset(hup, 0, (*hup).sizeof);
    hup.reader = null;
    // init dictionary
    hup.dict_pos = 0;
    // init model
    hup.ces = CTSTEP;
    hup.les = LTSTEP;
    hup.accnt = 0;
    hup.ttcon = 0;
    hup.npt = hup.pmax = 1;
    for (int i = 0; i < TTORD; ++i) hup.ttab[i][0] = hup.ttab[i][1] = TTSTEP;
    tabinit(hup.ltab, LTCODES, 0);
    tabinit(hup.eltab, LTCODES, 1);
    tabinit(hup.ctab, CTCODES, 0);
    tabinit(hup.ectab, CTCODES, 1);
    tabinit(hup.ptab, PTCODES, 0);
    tupd(hup.ptab, PTCODES, MAXPT, PTSTEP, 0);
    // init arithmetic decoder
    hup.ari_h = 0xffff;
    hup.ari_l = 0;
    hup.ari_gpat = 0;
    hup.ari_init_done = 0; // defer initialization
    // read buffer
    hup.no_more = false;
  }
}


// return number of bytes read (<len: end of data), throws on error
public usize haunp_read (haunp_t hup, void[] buf, haunp_bread_fn_t reader) {
  if (buf.length == 0) return 0;
  if (hup !is null && reader !is null) {
    hup.reader = reader;
    scope(exit) hup.reader = null;
    usize res = 0;
    auto d = cast(ubyte*)buf.ptr;
    auto left = buf.length;
    while (left > 0) {
      hup.done = 0;
      auto rd = cast(int)(left > int.max/8 ? int.max/8 : left);
      libha_unpack(hup, d, rd);
      d += hup.done;
      left -= hup.done;
      res += hup.done;
      if (hup.done != rd) break;
    }
    return res;
  }
  throw new Exception("haunpack error");
}
