/* Invisible Vector Library
 * simple FlexBox-based TUI engine
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
// virtual console with doublebuffering, to awoid alot of overdraw
module iv.tuing.tty /*is aliced*/;
private:

import iv.alice;
public import iv.rawtty;
import iv.strex;
import iv.utfutil;


// ////////////////////////////////////////////////////////////////////////// //
public __gshared int TtyDefaultEscWait = 50; // -1: forever
private __gshared int ttywIntr, ttyhIntr; // DO NOT CHANGE!
__gshared bool weAreFucked = false; // utfucked?
__gshared string ttyzTitleSuffix;

public @property int ttyw () nothrow @trusted @nogc { pragma(inline, true); return ttywIntr; }
public @property int ttyh () nothrow @trusted @nogc { pragma(inline, true); return ttyhIntr; }

public @property string ttyTitleSuffix () nothrow @trusted @nogc { return ttyzTitleSuffix; }
public @property void ttyTitleSuffix(T : const(char)[]) (T s) nothrow {
  static if (is(T == typeof(null))) {
    ttyzTitleSuffix = null;
  } else static if (is(T == string)) {
    ttyzTitleSuffix = s;
  } else {
    ttyzTitleSuffix = s.idup;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
public enum XtColorFB(ubyte fg, ubyte bg) = cast(uint)((fg<<8)|bg);


// ////////////////////////////////////////////////////////////////////////// //
// global scissors
public align(1) struct XtScissor {
align(1) nothrow @trusted @nogc:
private:
  ushort mX0, mY0, mW, mH;

public:
  this (int ax0, int ay0, int aw, int ah) {
    if (ay0 >= ttyhIntr || ax0 >= ttywIntr || aw < 1 || ah < 1) return;
    if (ax0 < 0) {
      if (ax0 <= -aw) return;
      aw += ax0;
      ax0 = 0;
    }
    if (ay0 < 0) {
      if (ay0 <= -ah) return;
      ah += ay0;
      ay0 = 0;
    }
    if (aw > ttywIntr) aw = ttywIntr;
    if (ah > ttyhIntr) ah = ttyhIntr;
    if (ttywIntr-ax0 > aw) aw = ttywIntr-ax0;
    if (ttyhIntr-ay0 > ah) ah = ttyhIntr-ay0;
    if (aw > 0 && ah > 0) {
      mX0 = cast(ushort)ax0;
      mY0 = cast(ushort)ay0;
      mW = cast(ushort)aw;
      mH = cast(ushort)ah;
    }
  }

  static XtScissor fullscreen () { return XtScissor(0, 0, ttywIntr, ttyhIntr); }

const @safe:
  // crop this scissor with another scissor
  XtScissor crop (int x, int y, int w, int h) { return crop(XtScissor(x, y, w, h)); }
pure:
  XtScissor crop (in XtScissor s) {
    import std.algorithm : max, min;
    XtScissor res = void;
    res.mX0 = this.mX0;
    res.mY0 = this.mY0;
    res.mW = this.mW;
    res.mH = this.mH;
    if (res.visible && s.visible) {
      int rx0 = max(mX0, s.mX0);
      int ry0 = max(mY0, s.mY0);
      int rx1 = min(x1, s.x1);
      int ry1 = min(y1, s.y1);
      if (rx1 < rx0 || ry1 < ry0) {
        res.mW = res.mH = 0;
      } else {
        res.mX0 = cast(ushort)rx0;
        res.mY0 = cast(ushort)ry0;
        res.mW = cast(ushort)(rx1-rx0+1);
        res.mH = cast(ushort)(ry1-ry0+1);
      }
    }
    return res;
  }

@property:
  bool visible () { pragma(inline, true); return (mW > 0 && mH > 0); }
  bool empty () { pragma(inline, true); return (mW == 0 && mH == 0); }
  int x0 () { pragma(inline, true); return mX0; }
  int y0 () { pragma(inline, true); return mY0; }
  int x1 () { pragma(inline, true); return mX0+mW-1; } // may be negative for empty scissor
  int y1 () { pragma(inline, true); return mY0+mH-1; } // may be negative for empty scissor
  int width () { pragma(inline, true); return mW; }
  int height () { pragma(inline, true); return mH; }
}

__gshared XtScissor ttyzScissor;


public @property XtScissor ttyScissor () nothrow @trusted @nogc { pragma(inline, true); return ttyzScissor; }
public @property void ttyScissor (in XtScissor sc) nothrow @trusted @nogc { pragma(inline, true); ttyzScissor = sc; }


// ////////////////////////////////////////////////////////////////////////// //
enum SIGWINCH = 28;

__gshared bool winSizeChanged = false;
__gshared bool winChSet = false;

extern(C) void sigwinchHandler (int sig) {
  winSizeChanged = true;
}

void setupWinch () {
  import core.sys.posix.signal;
  if (winChSet) return;
  winChSet = true;
  sigaction_t sa;
  sigemptyset(&sa.sa_mask);
  sa.sa_flags = 0;
  sa.sa_handler = &sigwinchHandler;
  if (sigaction(SIGWINCH, &sa, null) == -1) return;
}


// ////////////////////////////////////////////////////////////////////////// //
align(1) struct Glyph {
align(1):
  enum Flag : ubyte {
    G1         = 0b1000_0000u, // only this will be checked in refresh
    Mask       = 0b1000_0000u, // refresh compare mask
    GraphMask  = 0b0000_1111u,
    GraphUp    = 0b0000_0001u,
    GraphDown  = 0b0000_0010u,
    GraphLeft  = 0b0000_0100u,
    GraphRight = 0b0000_1000u,
  }
  ubyte fg = 7; // foreground color
  ubyte bg = 0; // background color
  char ch = 0; // char
  ubyte flags = 0; // see Flag enum
  // 0: not a graphic char
  @property char g1char () const pure nothrow @trusted @nogc {
    static immutable char[16] transTbl = [
      0x20, // ....
      0x78, // ...U
      0x78, // ..D.
      0x78, // ..DU
      0x71, // .L..
      0x6A, // .L.U
      0x6B, // .LD.
      0x75, // .LDU
      0x71, // R...
      0x6D, // R..U
      0x6C, // R.D.
      0x74, // R.DU
      0x71, // RL..
      0x76, // RL.U
      0x77, // RLD.
      0x6E, // RLDU
    ];
    return (flags&Flag.GraphMask ? transTbl.ptr[flags&Flag.GraphMask] : 0);
  }
  void g1line(bool setattr) (ubyte gf, ubyte afg, ubyte abg) nothrow @trusted @nogc {
    if (gf&Flag.GraphMask) {
      if (flags&Flag.G1) {
        if ((flags&Flag.GraphMask) == 0) {
          // check if we have some line drawing char here
          switch (ch) {
            case 0x6A: flags |= Flag.GraphLeft|Flag.GraphUp; break;
            case 0x6B: flags |= Flag.GraphLeft|Flag.GraphDown; break;
            case 0x6C: flags |= Flag.GraphRight|Flag.GraphDown; break;
            case 0x6D: flags |= Flag.GraphRight|Flag.GraphUp; break;
            case 0x6E: flags |= Flag.GraphLeft|Flag.GraphRight|Flag.GraphUp|Flag.GraphDown; break;
            case 0x71: flags |= Flag.GraphLeft|Flag.GraphRight; break;
            case 0x74: flags |= Flag.GraphUp|Flag.GraphDown|Flag.GraphRight; break;
            case 0x75: flags |= Flag.GraphUp|Flag.GraphDown|Flag.GraphLeft; break;
            case 0x76: flags |= Flag.GraphLeft|Flag.GraphRight|Flag.GraphUp; break;
            case 0x77: flags |= Flag.GraphLeft|Flag.GraphRight|Flag.GraphDown; break;
            case 0x78: flags |= Flag.GraphUp|Flag.GraphDown; break;
            default:
          }
        }
      } else {
        flags &= ~Flag.GraphMask;
      }
      flags |= (gf&Flag.GraphMask)|Flag.G1;
      ch = g1char;
    } else if (flags&Flag.G1) {
      flags &= ~(Flag.GraphMask|Flag.G1); // reset graphics
      ch = ' ';
    }
    static if (setattr) {
      fg = afg;
      bg = abg;
    }
  }
}
static assert(Glyph.sizeof == 4);


// ////////////////////////////////////////////////////////////////////////// //
__gshared int ttycx, ttycy; // current cursor position (0-based)
__gshared Glyph[] ttywb; // working buffer
__gshared Glyph[] ttybc; // previous buffer
__gshared ubyte curFG = 7, curBG = 0;
__gshared bool ttzFullRefresh = true;


// ////////////////////////////////////////////////////////////////////////// //
__gshared ubyte* ttySavedBufs;
__gshared uint ttySBUsed;
__gshared uint ttySBSize;

private align(1) struct TxSaveInfo {
align(1):
  int cx, cy; // cursor position
  ubyte fg, bg; // current color
  int x, y, w, h; // saved data (if any)
  Glyph[0] data;
}

shared static ~this () {
  import core.stdc.stdlib : free;
  if (ttySavedBufs !is null) free(ttySavedBufs);
}


private ubyte* ttzSBAlloc (uint size) {
  import core.stdc.stdlib : realloc;
  import core.stdc.string : memset;
  assert(size > 0);
  if (size >= 4*1024*1024) assert(0, "wtf?!");
  uint nsz = ttySBUsed+size;
  if (nsz > ttySBSize) {
    if (nsz&0xfff) nsz = (nsz|0xfff)+1;
    auto nb = cast(ubyte*)realloc(ttySavedBufs, nsz);
    if (nb is null) assert(0, "out of memory"); //FIXME
    ttySavedBufs = nb;
    ttySBSize = nsz;
  }
  assert(ttySBSize-ttySBUsed >= size);
  auto res = ttySavedBufs+ttySBUsed;
  ttySBUsed += size;
  memset(res, 0, size);
  return res;
}


// push area contents and cursor position (unaffected by scissors)
public void xtPushArea (int x, int y, int w, int h) {
  if (w < 1 || h < 1 || x >= ttywIntr || y >= ttyhIntr) { x = y = w = h = 0; }
  if (w > 0) {
    int x0 = x, y0 = y, x1 = x+w-1, y1 = y+h-1;
    if (x0 < 0) x0 = 0; else if (x0 >= ttywIntr) x0 = ttywIntr-1;
    if (x1 < 0) x1 = 0; else if (x1 >= ttywIntr) x1 = ttywIntr-1;
    if (y0 < 0) y0 = 0; else if (y0 >= ttyhIntr) y0 = ttyhIntr-1;
    if (y1 < 0) y1 = 0; else if (y1 >= ttyhIntr) y1 = ttyhIntr-1;
    if (x0 <= x1 && y0 <= y1) {
      x = x0;
      y = y0;
      w = x1-x0+1;
      h = y1-y0+1;
    } else {
      x = y = w = h = 0;
    }
  }
  if (w < 1 || h < 1) { x = y = w = h = 0; }
  uint sz = cast(uint)(TxSaveInfo.sizeof+Glyph.sizeof*w*h);
  auto buf = ttzSBAlloc(sz+4);
  auto st = cast(TxSaveInfo*)buf;
  st.cx = ttycx;
  st.cy = ttycy;
  st.fg = curFG;
  st.bg = curBG;
  st.x = x;
  st.y = y;
  st.w = w;
  st.h = h;
  if (w > 0 && h > 0) {
    assert(x >= 0 && y >= 0 && x < ttywIntr && y < ttyhIntr && x+w <= ttywIntr && y+h <= ttyhIntr);
    import core.stdc.string : memcpy;
    auto src = ttywb.ptr+y*ttywIntr+x;
    auto dst = st.data.ptr;
    foreach (immutable _; 0..h) {
      memcpy(dst, src, Glyph.sizeof*w);
      src += ttywIntr;
      dst += w;
    }
  }
  buf += sz;
  *cast(uint*)buf = sz;
}


// pop (restore) area contents and cursor position (unaffected by scissors)
public void xtPopArea () {
  if (ttySBUsed == 0) return;
  assert(ttySBUsed >= 4);
  auto sz = *cast(uint*)(ttySavedBufs+ttySBUsed-4);
  ttySBUsed -= sz+4;
  auto st = cast(TxSaveInfo*)(ttySavedBufs+ttySBUsed);
  ttycx = st.cx;
  ttycy = st.cy;
  curFG = st.fg;
  curBG = st.bg;
  auto x = st.x;
  auto y = st.y;
  auto w = st.w;
  auto h = st.h;
  if (w > 0 && h > 0) {
    assert(x >= 0 && y >= 0 && x < ttywIntr && y < ttyhIntr && x+w <= ttywIntr && y+h <= ttyhIntr);
    import core.stdc.string : memcpy;
    auto src = st.data.ptr;
    auto dst = ttywb.ptr+y*ttywIntr+x;
    foreach (immutable _; 0..h) {
      memcpy(dst, src, Glyph.sizeof*w);
      src += w;
      dst += ttywIntr;
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
// initialize system, allocate buffers, clear screen, etc
public void xtInit () {
  import core.sys.posix.unistd : write;
  weAreFucked = ttyIsUtfucked;
  setupWinch();
  ttywIntr = ttyWidth;
  ttyhIntr = ttyHeight;
  ttywb.length = ttywIntr*ttyhIntr;
  ttybc.length = ttywIntr*ttyhIntr;
  ttywb[] = Glyph.init;
  ttybc[] = Glyph.init;
  ttycx = ttycy = 0;
  ttyzScissor = XtScissor.fullscreen;
  // clear screen
  enum initStr =
    "\x1b[?1034l"~ // xterm: disable "eightBitInput"
    "\x1b[?1036h"~ // xterm: enable "metaSendsEscape"
    "\x1b[?1039h"~ // xterm: enable "altSendsEscape"
    // disable various mouse reports
    "\x1b[?1000l"~
    "\x1b[?1001l"~
    "\x1b[?1002l"~
    "\x1b[?1003l"~
    "\x1b[?1004l"~ // don't send focus events
    "\x1b[?1005l"~
    "\x1b[?1006l"~
    "\x1b[?1015l"~
    "\x1b[?1000l";
  write(1, initStr.ptr, initStr.length);
  xtFullRefresh();
}


public bool xtNeedReinit () {
  //return (ttywIntr != ttyWidth || ttyhIntr != ttyHeight);
  return winSizeChanged;
}


// this will reset scissors
public void xtReinit () {
  ttyzScissor = XtScissor.fullscreen;
  if (ttywIntr != ttyWidth || ttyhIntr != ttyHeight) {
    winSizeChanged = false;
    ttywIntr = ttyWidth;
    ttyhIntr = ttyHeight;
    ttywb.length = ttywIntr*ttyhIntr;
    ttybc.length = ttywIntr*ttyhIntr;
    ttywb[] = Glyph.init;
    ttybc[] = Glyph.init;
    ttycx = ttycy = 0;
    // clear screen
    //enum initStr = "\x1b[H\x1b[0;37;40m\x1b[2J";
    //write(1, initStr.ptr, initStr.length);
    xtFullRefresh();
  }
}


// ////////////////////////////////////////////////////////////////////////// //
__gshared char[128*1024] ttytbuf = 0;
__gshared int ttytpos;
__gshared int lastx, lasty;


private void ttzFlush () nothrow @nogc {
  if (ttytpos > 0) {
    import core.sys.posix.unistd : write;
    write(1, ttytbuf.ptr, ttytpos);
    ttytpos = 0;
  }
}


private void ttzPut (const(char)[] str...) nothrow @nogc {
  import core.stdc.string : memcpy;
  while (str.length > 0) {
    uint left = cast(uint)ttytbuf.length-ttytpos;
    if (left == 0) { ttzFlush(); left = cast(uint)ttytbuf.length; }
    if (left > str.length) left = cast(uint)str.length;
    memcpy(ttytbuf.ptr+ttytpos, str.ptr, left);
    ttytpos += left;
    str = str[left..$];
  }
}


private void ttzPutUInt (uint n) nothrow @nogc {
  import core.stdc.string : memcpy;
  char[64] ttbuf = void;
  uint tbpos = cast(uint)ttbuf.length;
  do {
    ttbuf[--tbpos] = cast(char)(n%10+'0');
  } while ((n /= 10) != 0);
  ttzPut(ttbuf[tbpos..$]);
}


private void ttzPutUHex (uint n) nothrow @nogc {
  char[8] ttbuf = void;
  foreach_reverse (ref char ch; ttbuf) {
    int d = n%16;
    if (d < 10) d += '0'; else d += 'a'-10;
    ch = cast(char)d;
    n /= 16;
  }
  ttzPut(ttbuf[]);
}


// ////////////////////////////////////////////////////////////////////////// //
public void xtSetTerminalTitle (const(char)[] title) {
  import core.sys.posix.unistd : write;
  if (title.length > 500) title = title[0..500];
  enum titStart = "\x1b]2;";
  enum titEnd = "\x07";
  //enum suffix = " -- egedit";
  bool good = true;
  foreach (char ch; title) if (ch < ' ' || ch == 127) { good = false; break; }
  write(1, titStart.ptr, titStart.length);
  if (good) {
    if (title.length) write(1, title.ptr, title.length);
  } else {
    foreach (char ch; title) write(1, &ch, 1);
  }
  if (ttyzTitleSuffix.length) write(1, ttyzTitleSuffix.ptr, ttyzTitleSuffix.length);
  write(1, titEnd.ptr, titEnd.length);
}


// ////////////////////////////////////////////////////////////////////////// //
// redraw the whole screen; doesn't flush it yet
public void xtFullRefresh () nothrow @trusted @nogc {
  ttzFullRefresh = true;
}


// ////////////////////////////////////////////////////////////////////////// //
// this will reset scissors
public void xtFlush () /*nothrow @nogc*/ {
  void gotoXY (int x, int y) {
    if (x == lastx && y == lasty) return;
    //debug { import iv.vfs.io; stderr.writeln("x=", x, "; y=", y, "; last=", lastx, "; lasty=", lasty); }
    if (y == lasty) {
      // move horizontally
      if (x == 0) { ttzPut("\r"); lastx = 0; return; }
      ttzPut("\x1b[");
      if (x < lastx) {
        // move cursor left
        ttzPutUInt(lastx-x);
        ttzPut("D");
      } else if (x > lastx) {
        // move cursor right
        ttzPutUInt(x-lastx);
        ttzPut("C");
      }
      lastx = x;
    } else if (x == lastx) {
      // move vertically
      ttzPut("\x1b[");
      if (y < lasty) {
        // move cursor up
        ttzPutUInt(lasty-y);
        ttzPut("A");
      } else if (y > lasty) {
        // move cursor down
        ttzPutUInt(y-lasty);
        ttzPut("B");
      }
      lasty = y;
    } else {
      // move in both directions
      //TODO: optimize this too
      ttzPut("\x1b[");
      ttzPutUInt(y+1);
      ttzPut(";");
      ttzPutUInt(x+1);
      ttzPut("H");
      lastx = x;
      lasty = y;
    }
  }

  ttyzScissor = XtScissor.fullscreen;

  ubyte inG0G1 = 0;
  ttytpos = 0; // reset output position
  if (ttzFullRefresh) {
    ttzPut("\x1b[H");
    lastx = lasty = 0;
  }
  ttzPut("\x1b[0;38;5;7;48;5;0m");
  ubyte lastFG = 7, lastBG = 0;
  int tsz = ttywIntr*ttyhIntr;
  // fix glyph chars
  auto tsrc = ttywb.ptr; // source buffer
  auto tdst = ttybc.ptr; // destination buffer
  //immutable doctrans = (termType == TermType.linux);
  enum doctrans = false;
  for (uint pos = 0; pos < tsz; *tdst++ = *tsrc++, ++pos) {
         if (tsrc.ch == '\t') { tsrc.ch = '\x62'; tsrc.flags = Glyph.Flag.G1; }
         if (tsrc.ch == '\v') { tsrc.ch = '\x69'; tsrc.flags = Glyph.Flag.G1; }
         if (tsrc.ch == '\n') { tsrc.ch = '\x65'; tsrc.flags = Glyph.Flag.G1; }
         if (tsrc.ch == '\r') { tsrc.ch = '\x64'; tsrc.flags = Glyph.Flag.G1; }
    else if (tsrc.ch == 0) { tsrc.ch = ' '; tsrc.flags = 0; }
    else if (tsrc.ch < ' ' || tsrc.ch == 127) { tsrc.ch = '\x7e'; tsrc.flags = Glyph.Flag.G1; }
    // skip things that doesn't need to be updated
    if (!ttzFullRefresh) {
      if (((tsrc.flags^tdst.flags)&Glyph.Flag.Mask) == 0 && tsrc.ch == tdst.ch && tsrc.bg == tdst.bg) {
        // same char, different attrs? for spaces, it is enough to compare only bg color
        // actually, some terminals may draw different colored cursor on different colored
        // spaces, but i don't care: fix your terminal!
        if (/*tsrc.ch == ' ' ||*/ tsrc.fg == tdst.fg) continue;
      }
    }
    gotoXY(pos%ttywIntr, pos/ttywIntr);
    if (inG0G1 != (tsrc.flags&Glyph.Flag.G1)) {
      if ((inG0G1 = (tsrc.flags&Glyph.Flag.G1)) != 0) ttzPut('\x0e'); else ttzPut('\x0f');
    }
    // new attrs?
    if (tsrc.bg != lastBG || (/*tsrc.ch != ' ' &&*/ tsrc.fg != lastFG)) {
      ttzPut("\x1b[");
      if (!doctrans) {
        bool needSC = false;
        if (tsrc.fg != lastFG) {
          lastFG = tsrc.fg;
          ttzPut("38;5;");
          ttzPutUInt(lastFG);
          needSC = true;
        }
        if (tsrc.bg != lastBG) {
          lastBG = tsrc.bg;
          if (needSC) ttzPut(';');
          ttzPut("48;5;");
          ttzPutUInt(lastBG);
        }
      } else {
        lastFG = tsrc.fg;
        lastBG = tsrc.bg;
        ttzPut("0;");
        auto c0 = tty2linux(lastFG);
        auto c1 = tty2linux(lastBG);
        if (c0 > 7) ttzPut("1;");
        ttzPut("3");
        ttzPutUInt(c0);
        ttzPut(";4");
        ttzPutUInt(c1);
      }
      ttzPut('m');
    }
    // draw char
    if (inG0G1) {
      ttzPut(tsrc.ch < 128 ? tsrc.ch : ' ');
    } else if (!weAreFucked || tsrc.ch < 128) {
      ttzPut(tsrc.ch);
    } else {
      char[8] ubuf = void;
      dchar dch = koi2uni(cast(char)tsrc.ch);
      auto len = utf8Encode(ubuf[], dch);
      if (len < 1) { ubuf[0] = '?'; len = 1; }
      ttzPut(ubuf[0..len]);
    }
    // adjust cursor position
    if (++lastx == ttywIntr) {
      lastx = 0;
      ttzPut("\r");
    }
  }
  // switch back to G0
  if (inG0G1) ttzPut('\x0f');
  // position cursor
  gotoXY(ttycx, ttycy);
  // done
  ttzFlush();
  ttzFullRefresh = false;
}


// ////////////////////////////////////////////////////////////////////////// //
public struct XtWindow {
private:
  int x, y, w, h;
  ushort fgbg;

nothrow @safe @nogc:
public:
  this (int ax, int ay, int aw, int ah) @trusted {
    x = ax;
    y = ay;
    w = aw;
    h = ah;
    fgbg = cast(ushort)((curFG<<8)|curBG); // with current color
  }

  static XtWindow fullscreen () @trusted { pragma(inline, true); return XtWindow(0, 0, ttywIntr, ttyhIntr); }

  @property bool valid () const pure { pragma(inline, true); return (w > 0 && h > 0); }
  // invalid windows are invisible ;-)
  @property bool visible () const @trusted {
    pragma(inline, true);
    return
      w > 0 && h > 0 && // valid
      x < ttywIntr && y < ttyhIntr && // not too right/bottom
      x+w > 0 && y+h > 0; // not too left/top
  }

  // clip this window to another window
  //FIXME: completely untested (and unused!)
  /*
  void clipBy() (in auto ref XtWindow ww) {
    if (empty || ww.empty) { w = h = 0; return; }
    if (x+w <= ww.x || y+h <= ww.y || x >= ww.x+ww.w || y >= ww.y+ww.h) { w = h = 0; return; }
    // we are at least partially inside ww
    if (x < ww.x) x = ww.x; // clip left
    if (y < ww.y) y = ww.y; // clip top
    if (x+w > ww.x+ww.w) w = ww.x+ww.w-x; // clip right
    if (y+h > ww.y+ww.h) y = ww.y+ww.h-y; // clip bottom
  }
  */

  @property int x0 () const pure { pragma(inline, true); return x; }
  @property int y0 () const pure { pragma(inline, true); return y; }
  @property int x1 () const pure { pragma(inline, true); return x+w-1; }
  @property int y1 () const pure { pragma(inline, true); return y+h-1; }
  @property int width () const pure { pragma(inline, true); return (w > 0 ? w : 0); }
  @property int height () const pure { pragma(inline, true); return (h > 0 ? h : 0); }

  @property void x0 (int v) pure { pragma(inline, true); x = v; }
  @property void y0 (int v) pure { pragma(inline, true); y = v; }
  @property void x1 (int v) pure { pragma(inline, true); w = (v-x0+1 > 0 ? v-x0+1 : 0); }
  @property void y1 (int v) pure { pragma(inline, true); h = (v-y0+1 > 0 ? v-y0+1 : 0); }
  @property void width (int v) pure { pragma(inline, true); w = v; }
  @property void height (int v) pure { pragma(inline, true); h = v; }

  @property ubyte fg () const pure { pragma(inline, true); return cast(ubyte)(fgbg>>8); }
  @property ubyte bg () const pure { pragma(inline, true); return cast(ubyte)(fgbg&0xff); }

  @property void fg (ubyte v) pure { pragma(inline, true); fgbg = cast(ushort)((fgbg&0x00ff)|(v<<8)); }
  @property void bg (ubyte v) pure { pragma(inline, true); fgbg = cast(ushort)((fgbg&0xff00)|v); }

  @property uint color () const pure { pragma(inline, true); return fgbg; }
  @property void color (uint v) pure { pragma(inline, true); fgbg = cast(ushort)(v&0xffff); }

  @property void fb (ubyte fg, ubyte bg) pure { pragma(inline, true); fgbg = cast(ushort)((fg<<8)|bg); }

  void gotoXY (int x, int y) @trusted {
    x += this.x;
    y += this.y;
    if (x >= this.x+this.w) x = this.x+this.w-1;
    if (y >= this.y+this.h) y = this.y+this.h-1;
    if (x < this.x) x = this.x;
    if (y < this.y) y = this.y;
    // now global
    if (x < 0) x = 0;
    if (y < 0) y = 0;
    if (x >= ttywIntr) x = ttywIntr-1;
    if (y > ttyhIntr) y = ttyhIntr-1;
    // set new coords
    ttycx = x;
    ttycy = y;
  }

  // returns new length (can be 0, and both `x` and `y` are undefined in this case)
  // ofs: bytes to skip (if x is "before" window
  // x, y: will be translated to global coords
  int normXYLen (ref int x, ref int y, int len, out int ofs) const @trusted {
    if (len < 1 || w < 1 || h < 1 || x >= w || y < 0 || y >= h || !visible || !ttyzScissor.visible) return 0; // nothing to do
    // crop to window
    if (x < 0) {
      if (x <= -len) return 0;
      len += x;
      ofs = -x;
      x = 0;
    }
    int left = w-x;
    if (left < len) len = left;
    if (len < 1) return 0; // just in case
    // crop to global space
    x += this.x;
    y += this.y;
    if (x+len <= ttyzScissor.mX0 || x > ttyzScissor.x1 || y < ttyzScissor.mY0 || y > ttyzScissor.y1) return 0;
    if (x < 0) {
      if (x <= -len) return 0;
      len += x;
      ofs = -x;
      x = 0;
    }
    if (x < ttyzScissor.mX0) {
      auto z = ttyzScissor.mX0-x;
      if (z >= len) return 0;
      x += z;
      len -= z;
    }
    if ((left = ttyzScissor.x1+1-x) < 1) return 0;
    if (left < len) len = left;
    return len;
  }

  int normXYLen (ref int x, ref int y, int len) const {
    int ofs;
    return normXYLen(x, y, len, ofs);
  }

@trusted:
  void writeHotStrAt (int x, int y, int w, const(char)[] s, uint hotattr, Align defalign=Align.Left, bool dohot=true, bool setcur=false) {
    if (w < 1) return;
    if (s.length && s.ptr[0] >= '\x01' && s.ptr[0] <= '\x03') {
      defalign = cast(Align)s.ptr[0];
      s = s[1..$];
    }
    if (s.length == 0) return;
    if (s.length > int.max/32) s = s[0..int.max/32];
    if (defalign < 1 || defalign > 3) defalign = Align.Left;
    final switch (defalign) {
      case Align.Left: break;
      case Align.Right: x += w-hotStrLen(s, dohot); break;
      case Align.Center: x += (w-hotStrLen(s, dohot))/2; break;
    }
    if (setcur) gotoXY(x, y);
    if (dohot) {
      // with hotchar
      for (;;) {
        import iv.strex : indexOf;
        auto ampos = s.indexOf('&');
        if (ampos < 0 || s.length-ampos < 2) { writeStrAt(x, y, s); break; }
        if (ampos > 0) { writeStrAt(x, y, s[0..ampos]); x += cast(int)ampos; }
        if (s.ptr[ampos+1] != '&') {
          if (setcur) { gotoXY(x, y); setcur = false; }
          auto oc = fgbg;
          fgbg = hotattr&0xffff;
          writeCharsAt(x, y, 1, s.ptr[ampos+1]);
          fgbg = oc;
        } else {
          writeCharsAt(x, y, 1, '&');
        }
        ++x;
        s = s[ampos+2..$];
      }
    } else {
      // no hotchar
      writeStrAt(x, y, s);
    }
  }

const:
  void writeStrAt(bool g1=false) (int x, int y, const(char)[] str...) {
    if (str.length > int.max) str = str[0..int.max];
    int ofs;
    auto len = normXYLen(x, y, cast(int)str.length, ofs);
    if (len < 1) return;
    immutable f = fg, b = bg;
    auto src = cast(const(char)*)str.ptr+ofs;
    auto dst = ttywb.ptr+y*ttywIntr+x;
    while (len-- > 0) {
      dst.fg = f;
      dst.bg = b;
      dst.ch = *src++;
      static if (g1) {
        dst.flags &= ~Glyph.Flag.GraphMask;
        dst.flags |= Glyph.Flag.G1;
      } else {
        dst.flags &= ~(Glyph.Flag.GraphMask|Glyph.Flag.G1);
      }
      ++dst;
    }
  }

  void writeCharAt(bool g1=false) (int x, int y, char ch) { writeCharsAt!g1(x, y, 1, ch); }

  void writeCharsAt(bool g1=false) (int x, int y, int count, char ch) {
    auto len = normXYLen(x, y, count);
    if (len < 1) return;
    immutable f = fg, b = bg;
    auto dst = ttywb.ptr+y*ttywIntr+x;
    while (len-- > 0) {
      dst.fg = f;
      dst.bg = b;
      dst.ch = ch;
      static if (g1) {
        dst.flags &= ~Glyph.Flag.GraphMask;
        dst.flags |= Glyph.Flag.G1;
      } else {
        dst.flags &= ~(Glyph.Flag.GraphMask|Glyph.Flag.G1);
      }
      ++dst;
    }
  }

  void writeUIntAt (int x, int y, uint n) {
    char[64] ttbuf = void;
    uint tbpos = cast(uint)ttbuf.length;
    do {
      ttbuf[--tbpos] = cast(char)(n%10+'0');
    } while ((n /= 10) != 0);
    writeStrAt(x, y, ttbuf[tbpos..$]);
  }

  void writeUHexAt (int x, int y, uint n) {
    char[8] ttbuf = void;
    foreach_reverse (ref char ch; ttbuf) {
      int d = n%16;
      if (d < 10) d += '0'; else d += 'a'-10;
      ch = cast(char)d;
      n /= 16;
    }
    writeStrAt(x, y, ttbuf[]);
  }

  void hline(bool setattr=true) (int x, int y, int len) {
    auto nlen = normXYLen(x, y, len);
    if (nlen < 1) return;
    immutable f = fg, b = bg;
    if (nlen == 1) {
      ttywb.ptr[y*ttywIntr+x].g1line!setattr(Glyph.Flag.GraphLeft|Glyph.Flag.GraphRight, f, b);
    } else {
      ttywb.ptr[y*ttywIntr+x].g1line!setattr(Glyph.Flag.GraphRight, f, b);
      foreach (ref gl; ttywb.ptr[y*ttywIntr+x+1..y*ttywIntr+x+nlen-1]) gl.g1line!setattr(Glyph.Flag.GraphLeft|Glyph.Flag.GraphRight, f, b);
      ttywb.ptr[y*ttywIntr+x+nlen-1].g1line!setattr(Glyph.Flag.GraphLeft, f, b);
    }
  }

  void vline(bool setattr=true) (int x, int y, int len) {
    if (x < 0 || x >= w || len < 1 || y >= h || w < 1 || h < 1) return;
    bool first = true;
    bool last = true;
    if (y < 0) {
      first = false;
      if (y <= -len) return;
      len += y;
      y = 0;
    }
    if (len > h-y) { last = false; len = h-y; }
    if (len < 1) return; // just in case
    immutable f = fg, b = bg;
    /*
    if (normXYLen(x, y, 1) != 1) return;
    if (len == 1) {
      ttywb.ptr[y*ttywIntr+x].g1line!setattr(Glyph.Flag.GraphUp|Glyph.Flag.GraphDown, f, b);
    } else {
      ttywb.ptr[y*ttywIntr+x].g1line!setattr(Glyph.Flag.GraphDown, f, b);
      foreach (int sy; y+1..y+len-1) ttywb.ptr[sy*ttywIntr+x].g1line!setattr(Glyph.Flag.GraphUp|Glyph.Flag.GraphDown, f, b);
      ttywb.ptr[(y+len-1)*ttywIntr+x].g1line!setattr(Glyph.Flag.GraphUp, f, b);
    }
    */
    if (len == 1) {
      if (normXYLen(x, y, 1) != 1) return;
      ttywb.ptr[y*ttywIntr+x].g1line!setattr(Glyph.Flag.GraphUp|Glyph.Flag.GraphDown, f, b);
      return;
    }
    while (len-- > 0) {
      int xx = x, yy = y;
      if (normXYLen(xx, yy, 1) == 1) {
        if (first) {
          first = false;
          ttywb.ptr[yy*ttywIntr+xx].g1line!setattr(Glyph.Flag.GraphDown, f, b);
        } else if (last && len == 0) {
          ttywb.ptr[yy*ttywIntr+xx].g1line!setattr(Glyph.Flag.GraphUp, f, b);
        } else {
          ttywb.ptr[yy*ttywIntr+xx].g1line!setattr(Glyph.Flag.GraphUp|Glyph.Flag.GraphDown, f, b);
        }
      }
      ++y;
    }
  }

  void frame(bool filled=false) (int x, int y, int w, int h) {
    if (w < 1 || h < 1) return;
    // erase lines first
    writeCharsAt(x, y, w, ' ');
    foreach (immutable sy; y..y+h) {
      writeCharsAt(x, sy, 1, ' ');
      writeCharsAt(x+w-1, sy, 1, ' ');
    }
    writeCharsAt(x, y+h-1, w, ' ');
    // draw lines
    if (h == 1) { hline(x, y, w); return; }
    if (w == 1) { vline(x, y, h); return; }
    hline(x, y, w); // top
    hline(x, y+h-1, w); // bottom
    vline(x, y, h); // left
    vline(x+w-1, y, h); // right
    static if (filled) {
      foreach (immutable sy; y+1..y+h-1) writeCharsAt(x+1, sy, w-2, ' ');
    }
  }

  void hshadow (int x, int y, int len) {
    static ubyte shadowColor (ubyte clr) nothrow @trusted @nogc {
      ubyte r, g, b;
      ttyColor2rgb(clr, r, g, b);
      return ttyRgb2Color(r/3, g/3, b/3);
    }

    len = normXYLen(x, y, len);
    if (len < 1) return;
    auto dst = ttywb.ptr+y*ttywIntr+x;
    while (len-- > 0) {
      dst.fg = shadowColor(dst.fg);
      dst.bg = shadowColor(dst.bg);
      ++dst;
    }
  }

  void shadowBox (int x, int y, int w, int h) {
    if (w < 1) return;
    while (h-- > 0) hshadow(x, y++, w);
  }

  void frameShadowed(bool filled=false) (int x, int y, int w, int h) {
    if (w < 1 || h < 1) return;
    frame!filled(x, y, w, h);
    shadowBox(x+w, y+1, 2, h-1);
    hshadow(x+2, y+h, w);
  }

  void fill(bool g1=false) (int x, int y, int w, int h, char ch=' ') {
    foreach (immutable sy; y..y+h) writeCharsAt!g1(x, sy, w, ch);
  }

  enum Align : char {
    Left = '\x01',
    Right = '\x02',
    Center = '\x03',
  }

  static int hotStrLen (const(char)[] s, bool dohot=true) nothrow @trusted @nogc {
    if (s.length > int.max) s = s[0..int.max];
    int res = cast(int)s.length;
    if (res && s.ptr[0] >= '\x01' && s.ptr[0] <= '\x03') --res; // left
    if (dohot) {
      for (;;) {
        import iv.strex : indexOf;
        auto ampos = s.indexOf('&');
        if (ampos < 0 || s.length-ampos < 2) break;
        --res;
        s = s[ampos+2..$];
      }
    }
    return res;
  }

  static char hotChar (const(char)[] s, bool dohot=true) nothrow @trusted @nogc {
    if (dohot) {
      if (s.length && s.ptr[0] >= '\x01' && s.ptr[0] <= '\x03') s = s[1..$];
      for (;;) {
        import iv.strex : indexOf;
        auto ampos = s.indexOf('&');
        if (ampos < 0 || s.length-ampos < 2) return 0;
        if (s.ptr[ampos+1] != '&') return s.ptr[ampos+1];
        s = s[ampos+2..$];
      }
    }
    return 0;
  }

  /*
  static int hotCharOfs (const(char)[] s, bool dohot=true) nothrow @trusted @nogc {
    if (dohot) {
      if (s.length && s.ptr[0] >= '\x01' && s.ptr[0] <= '\x03') s = s[1..$];
      int ofs = 0;
      for (;;) {
        import iv.strex : indexOf;
        auto ampos = s.indexOf('&');
        if (ampos < 0 || s.length-ampos < 2) return 0;
        if (s.ptr[ampos+1] != '&') return ofs+cast(int)ampos;
        s = s[ampos+2..$];
      }
    }
    return 0;
  }
  */
}


// ////////////////////////////////////////////////////////////////////////// //
private __gshared int screenSwapped = 0;


public void altScreen () nothrow @nogc {
  if (++screenSwapped == 1) {
    import core.sys.posix.unistd : write;
    enum initStr =
      "\x1b[?1048h"~ // save cursor position
      "\x1b[?1047h"~ // set alternate screen
      "\x1b[?7l"~ // turn off autowrapping
      "\x1b[?25h"~ // make cursor visible
      "\x1b(B"~ // G0 is ASCII
      "\x1b)0"~ // G1 is graphics
      "\x1b[?2004h"~ // enable bracketed paste
      "\x1b[?1000h\x1b[?1006h\x1b[?1002h"~ // SGR mouse reports
      "";
    write(1, initStr.ptr, initStr.length);
    xtFullRefresh();
  }
}


public void normalScreen () @trusted nothrow @nogc {
  if (--screenSwapped == 0) {
    import core.sys.posix.unistd : write;
    enum deinitStr =
      "\x1b[?1047l"~ // set normal screen
      "\x1b[?7h"~ // turn on autowrapping
      "\x1b[0;37;40m"~ // set 'normal' attributes
      "\x1b[?1048l"~ // restore cursor position
      "\x1b[?25h"~ // make cursor visible
      "\x1b[?2004l"~ // disable bracketed paste
      "\x1b[?1002l\x1b[?1006l\x1b[?1000l"~ // disable mouse reports
      "";
    write(1, deinitStr.ptr, deinitStr.length);
    xtFullRefresh();
  }
}


// ////////////////////////////////////////////////////////////////////////// //
private extern(C) void ttyzAtExit () {
  if (screenSwapped) {
    screenSwapped = 1;
    normalScreen();
  }
}

shared static this () {
  import core.stdc.stdlib : atexit;
  atexit(&ttyzAtExit);
}
