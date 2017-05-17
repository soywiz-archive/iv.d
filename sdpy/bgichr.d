/*
 * Pixel Graphics Library
 * coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * Understanding is not required. Only obedience.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */
module iv.sdpy.bgichr /*is aliced*/;

import iv.alice;
import iv.sdpy.color;
import iv.sdpy.gfxbuf;

import iv.stream;


// ////////////////////////////////////////////////////////////////////////// //
final class BgiChr {
private:
  enum {
    OpEnd,
    OpScan,
    OpMove,
    OpDraw,
  }

  static struct Stroke {
    ubyte opcode;
    byte x, y;
  }

  char[4] name;
  char[4] type;
  int ffirstChar;
  int flastChar;
  int fascent;
  int fbase;
  int fdescent;
  int[256] wdt;
  int[256] ffirstStroke;
  Stroke[] stk;
  ushort fver, dver; // font and driver versions

public:
  this (const(char)[] fname) {
    import std.stdio : File;
    load(File(fname.idup)); // fixme
  }

  this(ST) (auto ref ST st) if (isReadableStream!ST) {
    load(st);
  }

  @property const pure nothrow @safe @nogc {
    int height () { return fascent-fdescent; }
    int ascent () { return fascent; }
    int descent () { return fdescent; }
    int baseline () { return fbase; }
  }

  const pure nothrow @safe @nogc {
    int charWidth (char ch, double scale=1.0) { return cast(int)(scale*wdt[cast(ubyte)ch]); }
    int textWidth (const(char)[] str, double scale=1.0) {
      double w = 0.0;
      foreach (immutable ch; str) w += scale*wdt[cast(ubyte)ch];
      return cast(int)w;
    }
  }

  int drawChar() (auto ref GfxBuf gb, int x, int y, char ch, VColor clr, double scale=1.0) {
    int sn = ffirstStroke[cast(ubyte)ch];
    if (sn < 0) return 0;
    double ox = 0, oy = 0;
    while (sn < stk.length && stk[sn].opcode != OpEnd) {
      double nx = scale*stk[sn].x, ny = scale*stk[sn].y;
      if (stk[sn].opcode == OpDraw) {
        if (sn+1 >= stk.length || stk[sn+1].opcode != OpDraw) {
          gb.line(cast(int)(x+ox), cast(int)(y-oy), cast(int)(x+nx), cast(int)(y-ny), clr);
        } else {
          /* skip last pixel */
          gb.lineNoLast(cast(int)(x+ox), cast(int)(y-oy), cast(int)(x+nx), cast(int)(y-ny), clr);
        }
      }
      ox = nx;
      oy = ny;
      ++sn;
    }
    return cast(int)(scale*wdt[ch]);
  }

  int drawText() (auto ref GfxBuf gb, int x, int y, const(char)[] str, VColor clr, double scale=1.0) {
    int w = 0;
    foreach (immutable ch; str) {
      int d = drawChar(gb, x, y, ch, clr, scale);
      w += d;
      x += d;
    }
    return w;
  }

private:
  void load(ST) (auto ref ST st) if (isReadableStream!ST) {
    char[4] sign;
    int dataSize, charCount, stkOfs, dataOfs;
    int snum, btcount;
    // signature
    st.rawReadExact(sign[0..4]);
    if (sign != "PK\x08\x08") throw new Exception("invalid CHR signature");
    // font type ("BGI ", "LCD ")
    st.rawReadExact(type[0..4]);
    // skip description
    btcount = 8; // temp counter
    for (;;) {
      ubyte b = st.readNum!ubyte();
      ++btcount;
      if (b == 26) break;
      if (btcount > 65535) throw new Exception("CHR description too long");
    }
    // header size
    dataOfs = st.readNum!ushort();
    btcount += 2;
    // internal name
    st.rawReadExact(name[0..4]);
    btcount += 4;
    // data size
    dataSize = st.readNum!ushort();
    btcount += 2;
    if (dataSize < 2) throw new Exception("invalid CHR data size");
    // versions
    fver = cast(ushort)(st.readNum!ubyte()<<8);
    fver |= st.readNum!ubyte();
    dver = cast(ushort)(st.readNum!ubyte()<<8);
    dver |= st.readNum!ubyte();
    btcount += 4;
    // skip other header bytes
    if (dataOfs < btcount) throw new Exception("invalid CHR data offset");
    while (btcount < dataOfs) { st.readNum!ubyte(); ++btcount; }
    btcount = 0;
    // signature
    //debug { import std.stdio; writefln("ofs=0x%08x", st.tell); }
    if (st.readNum!ubyte() != '+') throw new Exception("invalid CHR data signature");
    ++btcount;
    // number of chars
    charCount = st.readNum!ushort();
    btcount += 2;
    if (charCount < 1 || charCount > 255) throw new Exception("invalid CHR character count");
    // meaningless byte
    st.readNum!ubyte();
    ++btcount;
    // first char
    ffirstChar = st.readNum!ubyte();
    ++btcount;
    // offset to stroke data (from the start of this header)
    stkOfs = st.readNum!ushort();
    btcount += 2;
    // scanable flag
    st.readNum!ubyte();
    ++btcount;
    // capitals height
    fascent = st.readNum!byte();
    ++btcount;
    // baseline
    fbase = st.readNum!byte();
    ++btcount;
    // decender height
    fdescent = st.readNum!byte();
    ++btcount;
    // internal font name
    st.rawReadExact(sign[0..4]);
    btcount += 4;
    // unused byte
    st.readNum!byte();
    ++btcount;
    // stroke offsets in stroke data
    ffirstStroke[] = -1;
    wdt[] = 0;
    //debug { import std.stdio; writefln("stofs=0x%08x", st.tell); }
    foreach (int cn; ffirstChar..ffirstChar+charCount) {
      auto fs = st.readNum!ushort();
      btcount += 2;
      if (fs < 0 || fs%2) throw new Exception("invalid CHR stroke offset");
      if (cn < 256) ffirstStroke[cn] = fs/2;
    }
    //debug { import std.stdio; writefln("wdtofs=0x%08x", st.tell); }
    // char width table
    foreach (int cn; ffirstChar..ffirstChar+charCount) {
      auto w = st.readNum!ubyte();
      ++btcount;
      if (cn < 256) wdt[cn] = w;
    }
    // move to stroke data
    if (btcount > stkOfs) throw new Exception("invalid CHR stroke data offset");
    while (btcount < stkOfs) { st.readNum!ubyte(); ++btcount; }
    // read stroke data
    //debug { import std.stdio; writefln("sdofs=0x%08x", st.tell); }
    if ((dataSize -= btcount) < 2) throw new Exception("invalid CHR no stroke data");
    stk.length = dataSize/2;
    foreach (ref s; stk) {
      int x, y, op;
      if (dataSize == 1) {
        st.readNum!ubyte();
        break;
      }
      x = st.readNum!ubyte();
      y = st.readNum!ubyte();
      dataSize -= 2;
      op = (x>>7)|((y>>6)&0x02);
      if ((x &= 0x7f) > 63) x -= 128;
      if ((y &= 0x7f) > 63) y -= 128;
      s.opcode = cast(ubyte)op;
      s.x = cast(byte)x;
      s.y = cast(byte)y;
    }
    flastChar = ffirstChar+charCount-1;
    if (flastChar > 255) flastChar = 255;
  }
}
