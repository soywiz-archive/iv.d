/* coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * Understanding is not required. Only obedience.
 *
 *                   INVISIBLE VECTOR PUBLIC LICENSE
 *                       Version 0, August 2014
 *
 * Copyright (C) 2014 Ketmar Dark <ketmar@ketmar.no-ip.org>
 *
 * Everyone is permitted to copy and distribute verbatim or modified
 * copies of this license document, and changing it is allowed as long
 * as the name is changed.
 *
 *                   INVISIBLE VECTOR PUBLIC LICENSE
 *   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
 *
 * 0. You may not use this software in either source or binary form, any
 *    software derived from this software, any library which uses either
 *    this software or code derived from this software in any other
 *    software which uses Windows API, either directly or indirectly
 *    via any chain of libraries.
 *
 * 1. You may not use this software in either source or binary form, any
 *    software derived from this software, any library which uses either
 *    this software or code derived from this software in any other
 *    software which uses MacOS X API, either directly or indirectly via
 *    any chain of libraries.
 *
 * 2. You may not use this software in either source or binary form, any
 *    software derived from this software, any library which uses either
 *    this software or code derived from this software in any other
 *    software on the territory of Russian Federation, either directly or
 *    indirectly via any chain of libraries.
 *
 * 3. Redistributions of this software in either source or binary form must
 *    retain this list of conditions and the following disclaimer.
 *
 * 4. Otherwise, you are allowed to use this software in any way that will
 *    not violate paragraphs 0, 1, 2 and 3 of this license.
 *
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 * Authors: Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * License: IVPLv0
 */
module iv.crt.screen is aliced;

import core.atomic;
import core.sys.posix.unistd;
import core.stdc.locale;

import std.conv;
import std.string;
import std.traits;
import std.utf;

import iv.gccattrs;
import iv.rawtty;

public import iv.rect;

import iv.crt.evloop;


// ////////////////////////////////////////////////////////////////////////// //
debug(crt_locale) version = crt_log_enabled;
else debug(crt_updates) version = crt_log_enabled;
else debug(crt_clipping) version = crt_log_enabled;
else debug(crt_debug) version = crt_log_enabled;


// ////////////////////////////////////////////////////////////////////////// //
version(GNU) {
private extern(C) ssize_t write (int, in void*, usize) @trusted nothrow @nogc;
private alias cwrite = write;
} else {
private alias cwrite = core.sys.posix.unistd.write;
}


// ////////////////////////////////////////////////////////////////////////// //
version(crt_log_enabled) {
  import std.stdio;

  void logln(A...) (A a) @trusted nothrow {
    try {
      auto fo = File("debug.log", "a");
      foreach (w; a) fo.write(to!string(w));
      fo.writeln();
    } catch (Exception) {}
  }

  void logfln(T, A...) (lazy T fmt, lazy A args) @trusted nothrow if (isSomeString!T) {
    logln(std.string.format(fmt, args));
  }
}


// ////////////////////////////////////////////////////////////////////////// //
private __gshared bool koiConvert = void;


private immutable ubyte[0x458-0x401] uni2koiTable = [
  0xB3,0x3F,0x3F,0xB4,0x3F,0xB6,0xB7,0x3F,0x3F,0x3F,0x3F,0x3F,0x3F,0x3F,0x3F,0xE1,
  0xE2,0xF7,0xE7,0xE4,0xE5,0xF6,0xFA,0xE9,0xEA,0xEB,0xEC,0xED,0xEE,0xEF,0xF0,0xF2,
  0xF3,0xF4,0xF5,0xE6,0xE8,0xE3,0xFE,0xFB,0xFD,0xFF,0xF9,0xF8,0xFC,0xE0,0xF1,0xC1,
  0xC2,0xD7,0xC7,0xC4,0xC5,0xD6,0xDA,0xC9,0xCA,0xCB,0xCC,0xCD,0xCE,0xCF,0xD0,0xD2,
  0xD3,0xD4,0xD5,0xC6,0xC8,0xC3,0xDE,0xDB,0xDD,0xDF,0xD9,0xD8,0xDC,0xC0,0xD1,0x3F,
  0xA3,0x3F,0x3F,0xA4,0x3F,0xA6,0xA7
];


/// Convert utf-8 to koi8-u
@gcc_inline char utf2koi() (dchar ch) @safe pure nothrow @nogc {
  if (ch < 127) return ch&0xff;
  if (ch > 0x400 && ch < 0x458) return uni2koiTable[ch-0x401];
  switch (ch) {
    case 0x490: return 0xBD;
    case 0x491: return 0xAD;
    case 0x2500: return 0x80; // BOX DRAWINGS LIGHT HORIZONTAL
    case 0x2502: return 0x81; // BOX DRAWINGS LIGHT VERTICAL
    case 0x250c: return 0x82; // BOX DRAWINGS LIGHT DOWN AND RIGHT
    case 0x2510: return 0x83; // BOX DRAWINGS LIGHT DOWN AND LEFT
    case 0x2514: return 0x84; // BOX DRAWINGS LIGHT UP AND RIGHT
    case 0x2518: return 0x85; // BOX DRAWINGS LIGHT UP AND LEFT
    case 0x251c: return 0x86; // BOX DRAWINGS LIGHT VERTICAL AND RIGHT
    case 0x2524: return 0x87; // BOX DRAWINGS LIGHT VERTICAL AND LEFT
    case 0x252c: return 0x88; // BOX DRAWINGS LIGHT DOWN AND HORIZONTAL
    case 0x2534: return 0x89; // BOX DRAWINGS LIGHT UP AND HORIZONTAL
    case 0x253c: return 0x8A; // BOX DRAWINGS LIGHT VERTICAL AND HORIZONTAL
    case 0x2580: return 0x8B; // UPPER HALF BLOCK
    case 0x2584: return 0x8C; // LOWER HALF BLOCK
    case 0x2588: return 0x8D; // FULL BLOCK
    case 0x258c: return 0x8E; // LEFT HALF BLOCK
    case 0x2590: return 0x8F; // RIGHT HALF BLOCK
    case 0x2591: return 0x90; // LIGHT SHADE
    case 0x2592: return 0x91; // MEDIUM SHADE
    case 0x2593: return 0x92; // DARK SHADE
    case 0x2320: return 0x93; // TOP HALF INTEGRAL
    case 0x25a0: return 0x94; // BLACK SQUARE
    case 0x2219: return 0x95; // BULLET OPERATOR
    case 0x221a: return 0x96; // SQUARE ROOT
    case 0x2248: return 0x97; // ALMOST EQUAL TO
    case 0x2264: return 0x98; // LESS-THAN OR EQUAL TO
    case 0x2265: return 0x99; // GREATER-THAN OR EQUAL TO
    case 0x00a0: return 0x9A; // NO-BREAK SPACE
    case 0x2321: return 0x9B; // BOTTOM HALF INTEGRAL
    case 0x00b0: return 0x9C; // DEGREE SIGN
    case 0x00b2: return 0x9D; // SUPERSCRIPT TWO
    case 0x00b7: return 0x9E; // MIDDLE DOT
    case 0x00f7: return 0x9F; // DIVISION SIGN
    case 0x2550: return 0xA0; // BOX DRAWINGS DOUBLE HORIZONTAL
    case 0x2551: return 0xA1; // BOX DRAWINGS DOUBLE VERTICAL
    case 0x2552: return 0xA2; // BOX DRAWINGS DOWN SINGLE AND RIGHT DOUBLE
    case 0x2554: return 0xA5; // BOX DRAWINGS DOUBLE DOWN AND RIGHT
    case 0x2557: return 0xA8; // BOX DRAWINGS DOUBLE DOWN AND LEFT
    case 0x2558: return 0xA9; // BOX DRAWINGS UP SINGLE AND RIGHT DOUBLE
    case 0x2559: return 0xAA; // BOX DRAWINGS UP DOUBLE AND RIGHT SINGLE
    case 0x255a: return 0xAB; // BOX DRAWINGS DOUBLE UP AND RIGHT
    case 0x255b: return 0xAC; // BOX DRAWINGS UP SINGLE AND LEFT DOUBLE
    case 0x255d: return 0xAE; // BOX DRAWINGS DOUBLE UP AND LEFT
    case 0x255e: return 0xAF; // BOX DRAWINGS VERTICAL SINGLE AND RIGHT DOUBLE
    case 0x255f: return 0xB0; // BOX DRAWINGS VERTICAL DOUBLE AND RIGHT SINGLE
    case 0x2560: return 0xB1; // BOX DRAWINGS DOUBLE VERTICAL AND RIGHT
    case 0x2561: return 0xB2; // BOX DRAWINGS VERTICAL SINGLE AND LEFT DOUBLE
    case 0x2563: return 0xB5; // BOX DRAWINGS DOUBLE VERTICAL AND LEFT
    case 0x2566: return 0xB8; // BOX DRAWINGS DOUBLE DOWN AND HORIZONTAL
    case 0x2567: return 0xB9; // BOX DRAWINGS UP SINGLE AND HORIZONTAL DOUBLE
    case 0x2568: return 0xBA; // BOX DRAWINGS UP DOUBLE AND HORIZONTAL SINGLE
    case 0x2569: return 0xBB; // BOX DRAWINGS DOUBLE UP AND HORIZONTAL
    case 0x256a: return 0xBC; // BOX DRAWINGS VERTICAL SINGLE AND HORIZONTAL DOUBLE
    case 0x256c: return 0xBE; // BOX DRAWINGS DOUBLE VERTICAL AND HORIZONTAL
    case 0x00a9: return 0xBF; // COPYRIGHT SIGN
    //
    case 0x2562: return 0xB4; // BOX DRAWINGS DOUBLE VERTICAL AND LEFT SINGLE
    case 0x2564: return 0xB6; // BOX DRAWINGS DOWN SINGLE AND DOUBLE HORIZONTAL
    case 0x2565: return 0xB7; // BOX DRAWINGS DOWN DOUBLE AND SINGLE HORIZONTAL
    case 0x256B: return 0xBD; // BOX DRAWINGS DOUBLE VERTICAL AND HORIZONTAL SINGLE
    default: return 63;
  }
  assert(0);
}


// ////////////////////////////////////////////////////////////////////////// //
private __gshared int ttyWdt, ttyHgt;
private shared bool doFullRefresh = true;
private shared int screenSwapped = 0;
private shared int cursorHidden = 0;
private __gshared Rect screenArea = void;
private __gshared Rect windowArea = void;


// ////////////////////////////////////////////////////////////////////////// //
void hideCursor () @trusted nothrow @nogc {
  version(GNU) {
    if (++cursorHidden == 1) {
      static immutable string estr = "\x1b[?25l";
      cwrite(STDOUT_FILENO, estr.ptr, estr.length);
    }
  } else {
    if (atomicOp!"+="(cursorHidden, 1) == 1) {
      static immutable string estr = "\x1b[?25l";
      cwrite(STDOUT_FILENO, estr.ptr, estr.length);
    }
  }
}


void showCursor () @trusted nothrow @nogc {
  version(GNU) {
    if (--cursorHidden == 0) {
      static immutable string estr = "\x1b[?25h";
      cwrite(STDOUT_FILENO, estr.ptr, estr.length);
    }
  } else {
    if (atomicOp!"-="(cursorHidden, 1) == 0) {
      static immutable string estr = "\x1b[?25h";
      cwrite(STDOUT_FILENO, estr.ptr, estr.length);
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
/* bit 31 set: this is special graphic char
 * bit 26+n, line parts:
 *   0
 *  1 2
 *   3
 *
 * 0b0011: 0x6A
 * 0b1010: 0x6B
 * 0b1100: 0x6C
 * 0b0101: 0x6D
 * 0b1111: 0x6E
 *
 * 0b1101: 0x74
 * 0b1011: 0x75
 * 0b0111: 0x76
 * 0b1110: 0x77
 *
 * 0b0110: 0x71
 * 0b1001: 0x78
 *
 * 0b0001: 0x60 (diamond)
 * 0b0010: 0x61 (50%-bar, checker)
 * 0b0100: 0x7E (cntrdot)
 *
 */
private enum {
  GraphMask = 0x8000_0000u,
  GraphLineMask = 0xe800_0000u,
  GraphShift = 27,
  //
  GraphUp    = 0b0001u,
  GraphLeft  = 0b0010u,
  GraphRight = 0b0100u,
  GraphDown  = 0b1000u,
  //
  GraphDiamond = 0x60/*|GraphMask*/,
  GraphChecker = 0x61/*|GraphMask*/,
  GraphCDot = 0x7E/*|GraphMask*/,
  //
  GraphInvalid = 0xffff_ffffu,
}


struct Glyph {
  dchar ch = ' '; // bits 27-30: special graphics char
  ubyte attr = Color.LightGray; // 4-7: background; 0-3: foreground

  @property bool valid () const pure nothrow @nogc { return (ch != GraphInvalid); }

  // 0: not a graphic char
  @property ubyte g1char () const pure nothrow @nogc {
    if (ch&GraphMask) {
      immutable ubyte ln = (ch>>GraphShift)&0x0f;
      if (ln) {
        static immutable ubyte[16] transTbl = [
          0x00, // 0b0000
          0x78, // 0b0001
          0x71, // 0b0010
          0x6A, // 0b0011
          0x71, // 0b0100
          0x6D, // 0b0101
          0x71, // 0b0110
          0x76, // 0b0111
          0x78, // 0b1000
          0x78, // 0b1001
          0x6B, // 0b1010
          0x75, // 0b1011
          0x6C, // 0b1100
          0x74, // 0b1101
          0x77, // 0b1110
          0x6E, // 0b1111
        ];
        return transTbl[ln];
      } else {
        return ch&0xff;
      }
    } else if (ch == 1) {
      return GraphChecker;
    } else if (ch == 2) {
      return GraphDiamond;
    } else if (ch == 3) {
      return GraphCDot;
    } else {
      return 0;
    }
  }

  void setLine (ubyte part, bool mix) nothrow @nogc {
    if (part && part <= 0x0f) {
      if (mix && (ch&GraphMask)) {
        ch |= (part<<GraphShift);
      } else {
        ch = (part<<GraphShift)|GraphMask;
      }
    } else if (part) {
      ch = part|GraphMask;
    } else {
      ch = ' ';
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
private __gshared Glyph[][2] vbufs;
__gshared void delegate () onScreenRefresh;


private void reinitBuffers () @trusted {
  screenArea.set(0, 0, ttyWdt, ttyHgt);
  vbufs[0].length = ttyWdt*ttyHgt;
  vbufs[1].length = ttyWdt*ttyHgt;
  foreach (idx, ref g; vbufs[0]) {
    g.ch = ' ';
    g.attr = Color.LightGray|(Color.Black<<4);
    vbufs[1][idx] = g;
  }
  atomicStore(doFullRefresh, true);
  if (onScreenRefresh !is null) onScreenRefresh();
}


// ////////////////////////////////////////////////////////////////////////// //
void altScreen () @trusted nothrow @nogc {
  version(GNU) {
    int swpd = cast(int)(++screenSwapped);
  } else {
    int swpd = atomicOp!"+="(screenSwapped, 1);
  }
  if (swpd == 1) {
    static immutable string initStr =
      /*"\r\x1b[Kswapping to alternate screen...\n"*/
      "\x1b[?1048h"~ // save cursor position
      "\x1b[?1047h"~ // set alternate screen
      "\x1b[?7l"~ // turn off autowrapping
      "\x1b[1;1H"~ // move cursor to top
      "\x1b[0;37;40m"~ // set 'normal' attributes
      "\x1b[2J"~ // clear screen
      "";
    cwrite(STDOUT_FILENO, initStr.ptr, initStr.length);
  }
}


void normalScreen () @trusted nothrow @nogc {
  version(GNU) {
    int swpd = cast(int)(--screenSwapped);
  } else {
    int swpd = atomicOp!"-="(screenSwapped, 1);
  }
  if (swpd == 0) {
    static immutable string deinitStr =
      /*"\r\x1b[Kswapping to normal screen...\n"*/
      "\x1b[?1047l"~ // set normal screen
      "\x1b[?7h"~ // turn on autowrapping
      "\x1b[0m"~ // set 'normal' attributes
      "\x1b[?1048l"~ // restore cursor position
      "\x1b[?25h"~ // make cursor visible
      "";
    cwrite(STDOUT_FILENO, deinitStr.ptr, deinitStr.length);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
private void sizeChanged (int w, int h) @trusted {
  //FIXME: do locking?
  if (ttyWdt != w || ttyHgt != h) {
    ttyWdt = w;
    ttyHgt = h;
    static immutable string initStr =
      "\x1b[0;37;40m"~ // set 'normal' attributes
      "\x1b[2J"; // clear screen
    cwrite(STDOUT_FILENO, initStr.ptr, initStr.length);
    reinitBuffers();
  }
}


shared static this () {
  if (ttySetRaw() == TTYMode.BAD) throw new Exception("not a tty");
  {
    import core.sys.posix.stdlib;
    auto lang = getenv("LANG");
    if (lang !is null) {
      auto s = to!string(lang);
      koiConvert = (s.indexOf("UTF", CaseSensitive.no) < 0);
    } else {
      koiConvert = false;
    }
    debug(crt_locale) stderr.writeln("koiConvert: ", koiConvert);
  }
  // init G0 and G1 charsets
  {
    static immutable string csinit = "\x1b(B\x1b)0\x0f";
    cwrite(STDOUT_FILENO, csinit.ptr, csinit.length);
  }
  ttyWdt = ttyWidth;
  ttyHgt = ttyHeight;
  windowArea.set(0, 0, ttyWdt, ttyHgt); // default window
  // screenArea will be initialized by reinitBuffers()
  reinitBuffers();
  altScreen();
  atomicStore(doFullRefresh, false);
  import iv.evloop : onSizeChanged;
  onSizeChanged = () {
    int w = ttyWidth;
    int h = ttyHeight;
    sizeChanged(w, h);
  };
}


shared static ~this () {
  if (atomicOp!"!="(screenSwapped, 0)) {
    atomicStore(screenSwapped, 1);
    normalScreen();
  }
  // deinit G0 and G1 charsets
  {
    static immutable string csdeinit = "\x1b(B\x1b)B\x0f";
    cwrite(STDOUT_FILENO, csdeinit.ptr, csdeinit.length);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
enum Color {
  None = -1,
  Black,
  Red,
  Green,
  Brown,
  Blue,
  Magenta,
  Cyan,
  LightGray,
  // note that there is no 'bright' variants for backgound colors
  Gray,
  BrightRed,
  BrightGreen,
  Yellow,
  BrightBlue,
  BrightMagenta,
  BrightCyan,
  White
}


// ////////////////////////////////////////////////////////////////////////// //
private void updateScreen (Glyph[] vbuf, Glyph[] obuf) @trusted nothrow @nogc {
  version(GNU) {
    bool fullrf = doFullRefresh;
    doFullRefresh = false;
  } else {
    bool fullrf = atomicLoad(doFullRefresh);
    atomicStore(doFullRefresh, false);
  }
  static char[32768] wbuf = void;
  usize wbufUsed = 0;
  usize pos = 0, ocurpos = 0xffffffffU;
  ubyte prevColor = 0xff; // impossible color
  bool prevWasHi = false;
  bool g1set = false;

  void flush () @trusted nothrow @nogc {
    if (wbufUsed > 0) {
      cwrite(STDOUT_FILENO, wbuf.ptr, wbufUsed);
      debug(crt_updates) try {
        auto fl = File("zlog.log", "a");
        fl.rawWrite(wbuf[0..wbufUsed]);
      } catch(Exception) {}
      wbufUsed = 0;
    }
  }

  void putChar (char ch) @trusted nothrow @nogc {
    if (wbufUsed >= wbuf.length) flush();
    wbuf[wbufUsed++] = ch;
  }

  void putStr (string s) @trusted nothrow @nogc {
    foreach (ch; s) putChar(ch);
  }

  void putNum (usize n) @trusted nothrow @nogc {
    char[8] bb = void;
    usize bpos = 0;
    do {
      bb[bpos++] = '0'+n%10;
      n /= 10;
    } while (n != 0);
    while (bpos-- > 0) putChar(bb[bpos]);
  }

  //TODO: optimize movement codes
  void moveCursor (usize pos) @trusted nothrow @nogc {
    if (ocurpos != pos) {
      putStr("\x1b[");
      putNum(pos/ttyWdt+1);
      putChar(';');
      putNum(pos%ttyWdt+1);
      putChar('H');
      ocurpos = pos;
    }
  }

  void setColor (ubyte clr) @trusted nothrow @nogc {
    if (clr != prevColor) {
      putStr("\x1b[");
      if (prevColor == 0xff) {
        if (clr&0x08) putStr("1;"); else putStr("22;");
        // fg
        putChar('3');
        putChar(cast(char)('0'+(clr&0x07)));
        // bg
        putStr(";4");
        putChar(cast(char)('0'+(clr>>4)));
      } else {
        bool needSemi = false;
        // fg intensity
        if ((clr&0x08) != (prevColor&0x08)) {
          if (clr&0x08) putChar('1'); else putStr("22");
          needSemi = true;
        }
        // fg
        if ((clr&0x07) != (prevColor&0x07)) {
          if (needSemi) putChar(';');
          needSemi = true;
          putChar('3');
          putChar(cast(char)('0'+(clr&0x07)));
        }
        // bg
        if ((clr>>4) != (prevColor>>4)) {
          if (needSemi) putChar(';');
          putChar('4');
          putChar(cast(char)('0'+(clr>>4)));
        }
      }
      putChar('m');
      prevColor = clr;
    }
  }

  char[4] utfs = void;
  while (pos < vbuf.length) {
    if (!fullrf) while (pos < vbuf.length && obuf[pos] == vbuf[pos]) ++pos;
    if (pos >= vbuf.length) break;
    moveCursor(pos);
    setColor(vbuf[pos].attr);
    ubyte g1c = vbuf[pos].g1char;
    if (g1c) {
      if (!g1set) { putChar('\x0e'); g1set = true; }
      putChar(cast(char)g1c);
    } else if (koiConvert) {
      if (g1set) { putChar('\x0f'); g1set = false; }
      if (wbufUsed+1 > wbuf.length) flush();
      putChar(cast(char)utf2koi(vbuf[pos].ch));
    } else {
      char[] n = toUTF8(utfs, vbuf[pos].ch);
      if (g1set) { putChar('\x0f'); g1set = false; }
      foreach (ch; n) putChar(ch);
    }
    obuf[pos] = vbuf[pos];
    ++pos;
    if (pos < vbuf.length && (++ocurpos)%ttyWdt == 0) putStr("\r\n");
  }
  if (g1set) putChar('\x0f');
  flush();
}


void flushScreen () @trusted nothrow @nogc {
  updateScreen(vbufs[0], vbufs[1]);
}


// ////////////////////////////////////////////////////////////////////////// //
// windowArea managemet
@property ref Rect window () @trusted nothrow @nogc { return windowArea; }
void makeFSWindow () @trusted nothrow @nogc { windowArea = screenArea; }

@property int screenWidth () @trusted nothrow @nogc { return screenArea.width; }
@property int screenHeight () @trusted nothrow @nogc { return screenArea.height; }


// ////////////////////////////////////////////////////////////////////////// //
@gcc_inline private bool isTransparent() (in Color clr) @trusted pure nothrow @nogc {
  return (clr < 0 || clr > 15);
}


@gcc_inline private void fixAttr() (usize pos, in Color fg, in Color bg) @trusted nothrow @nogc {
  if (!isTransparent(fg)) {
    // have foreground color
    if (!isTransparent(bg)) {
      // have foreground and background colors
      vbufs[0][pos].attr = cast(ubyte)(((bg&0x07)<<4)|fg);
    } else {
      // have only foreground color
      vbufs[0][pos].attr = cast(ubyte)((vbufs[0][pos].attr&0xf0)|fg);
    }
  } else if (!isTransparent(bg)) {
    // have only background color
    vbufs[0][pos].attr = (vbufs[0][pos].attr&0x0f)|((bg&0x07)<<4);
  }
}


@gcc_inline private void setShadow() (usize pos) @trusted nothrow @nogc {
  auto a = (vbufs[0][pos].attr&0x07);
  vbufs[0][pos].attr = (a != 8 ? 8 : 0);
}


// ////////////////////////////////////////////////////////////////////////// //
private bool normStripe(LT) (ref int x, ref int y, ref LT len, out int leftSkip) @trusted nothrow @nogc
if (isIntegral!LT) {
  int lskip;
  x += windowArea.x;
  y += windowArea.y;
  if (!windowArea.clipStripe(x, y, len, leftSkip)) return false; // out of window
  if (!screenArea.clipStripe(x, y, len, lskip)) return false; // out of screen
  leftSkip += lskip;
  return true;
}


private bool normStripe(LT) (ref int x, ref int y, ref LT len) @trusted nothrow @nogc
if (isIntegral!LT) {
  int lskip;
  return normStripe(x, y, len, lskip);
}


private bool normRect (ref Rect rc) @trusted nothrow @nogc {
  debug(crt_clipping) {
    logln("=== normRect ===");
    logln("screen: ", screenArea);
    logln("window: ", windowArea);
    logln("rc: ", rc);
  }
  rc.moveBy(windowArea.x, windowArea.y);
  debug(crt_clipping) logln("shifted rc: ", rc);
  if (!windowArea.clipRect(rc)) return false;
  debug(crt_clipping) logln("window-clipped rc: ", rc);
  if (!screenArea.clipRect(rc)) return false;
  debug(crt_clipping) logln("screen-clipped rc: ", rc);
  return true;
}


private bool normRect(CW, CH) (out Rect rc, int x, int y, CW width, CH height) @trusted nothrow @nogc
if (isIntegral!CW && isIntegral!CH) {
  rc.set(x, y, width, height);
  return normRect(rc);
}


// ////////////////////////////////////////////////////////////////////////// //
private dchar decodeUtf8Char (ref const(char)[] str) @trusted nothrow @nogc {
  import std.typetuple : TypeTuple;
  import std.utf : isValidDchar;
  /* The following encodings are valid, except for the 5 and 6 byte
   * combinations:
   *  0xxxxxxx
   *  110xxxxx 10xxxxxx
   *  1110xxxx 10xxxxxx 10xxxxxx
   *  11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
   *  111110xx 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx
   *  1111110x 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx
   */

  if (str.length == 0) return 0;

  /* Dchar bitmask for different numbers of UTF-8 code units. */
  alias bitMask = TypeTuple!((1 << 7) - 1, (1 << 11) - 1, (1 << 16) - 1, (1 << 21) - 1);

  ubyte bc = str[0];
  ubyte fst = bc;
  ubyte tmp = void;
  dchar d = fst; // upper control bits are masked out later
  fst <<= 1;

  // starter must have at least 2 first bits set
  if ((bc&0b1100_0000) != 0b1100_0000) goto notUtf;

  foreach (i; TypeTuple!(1, 2, 3)) {
    if (i == str.length) goto notUtf;
    tmp = str[i];
    if ((tmp&0xC0) != 0x80) goto notUtf;
    d = (d<<6)|(tmp&0x3F);
    fst <<= 1;
    if (!(fst&0x80)) {
      // no more bytes
      d &= bitMask[i]; // mask out control bits
      // overlong, could have been encoded with i bytes
      if ((d&~bitMask[i-1]) == 0) goto notUtf;
      // check for surrogates only needed for 3 bytes
      static if (i == 2) {
        if (!isValidDchar(d)) goto notUtf;
      }
      static if (i == 3) {
        if (d > dchar.max) goto notUtf;
      }
      str = str[i+1..$];
      return d;
    }
  }

notUtf:
  str = str[1..$];
  return bc;
}

void writeStr(T) (int x, int y, const(T)[] str, Color fg=Color.None, Color bg=Color.None) @trusted nothrow @nogc
if (is(T == char) || is(T == wchar) || is(T == dchar))
{
  int leftSkip;
  usize len = void;
  static if (isNarrowString!T) len = std.utf.count(str);
  else len = str.length;
  if (!normStripe(x, y, len, leftSkip)) return;
  if (leftSkip > 0) {
    static if (is(T == char)) {
      usize pos = 0;
      while (leftSkip--) {
        // skip one UTF-8 char
        ubyte ch = str[pos];
        if (pos >= str.length) return;
        // starter must have at least 2 first bits set
        if (ch < 0x80 || (ch&0b1100_0000) != 0b1100_0000) {
          ++pos;
        } else {
          import core.bitop;
          immutable cplen = 7-bsr(~str[pos]);
          pos += (cplen < 2 || cplen > 6 ? 1 : cplen);
        }
      }
      str = str[pos..$];
    } else {
      str = str[leftSkip..$];
    }
  }
  usize pos = y*ttyWdt+x;
  static if (is(T == char)) {
    while (str.length) {
      dchar ch = decodeUtf8Char(str);
      vbufs[0][pos].ch = ch;
      fixAttr(pos++, fg, bg);
    }
  } else {
    // '_aApplycd1' is not nothrow
    foreach (idx; 0..str.length) {
      vbufs[0][pos].ch = str[idx];
      fixAttr(pos++, fg, bg);
    }
  }
}


void fillChar(T, CW, CH) (int x, int y, CW width, CH height, T ch, Color fg=Color.None, Color bg=Color.None)
@trusted nothrow @nogc
if (isSomeChar!T && isIntegral!CW && isIntegral!CH)
{
  Rect rc = void;
  if (!normRect(rc, x, y, width, height)) return;
  usize pos = rc.y*ttyWdt+rc.x;
  foreach (_; 0..rc.height) {
    usize px = pos;
    foreach (_1; 0..rc.width) {
      vbufs[0][px].ch = ch;
      fixAttr(px++, fg, bg);
    }
    pos += ttyWdt;
  }
}


void fillChar(T) (in Rect rc, T ch, Color fg=Color.None, Color bg=Color.None) @trusted nothrow @nogc
if (isSomeChar!T) {
  if (!rc.empty) fillChar(rc.x, rc.y, rc.width, rc.height, ch, fg, bg);
}


void fillAttr(CW, CH) (int x, int y, CW width, CH height, Color fg=Color.None, Color bg=Color.None)
@trusted nothrow @nogc
if (isIntegral!CW && isIntegral!CH)
{
  if (isTransparent(fg) && isTransparent(bg)) return; // nothing to do
  Rect rc = void;
  if (!normRect(rc, x, y, width, height)) return;
  usize pos = rc.y*ttyWdt+rc.x;
  foreach (_; 0..rc.height) {
    usize px = pos;
    foreach (_1; 0..rc.width) fixAttr(px++, fg, bg);
    pos += ttyWdt;
  }
}


void fillAttr (in Rect rc, Color fg=Color.None, Color bg=Color.None) @trusted nothrow @nogc {
  if (!rc.empty) fillAttr(rc.x, rc.y, rc.width, rc.height, fg, bg);
}


void writeChar(T, CT) (int x, int y, CT count, T ch, Color fg=Color.None, Color bg=Color.None) @trusted nothrow @nogc
if (isSomeChar!T && isIntegral!CT)
{ fillChar(x, y, count, cast(typeof(count))1, ch, fg, bg); }


void writeCharV(T, CT) (int x, int y, CT count, T ch, Color fg=Color.None, Color bg=Color.None) @trusted nothrow @nogc
if (isSomeChar!T && isIntegral!CT)
{ fillChar(x, y, cast(typeof(count))1, count, ch, fg, bg); }


void writeAttr(CT) (int x, int y, CT count, Color fg=Color.None, Color bg=Color.None) @trusted nothrow @nogc
if (isIntegral!CT)
{ fillAttr(x, y, count, cast(typeof(count))1, fg, bg); }


void writeAttrV(T, CT) (int x, int y, CT count, T ch, Color fg=Color.None, Color bg=Color.None) @trusted nothrow @nogc
if (isSomeChar!T && isIntegral!CT)
{ fillAttr(x, y, cast(typeof(count))1, count, fg, bg); }


void writeShadow(CW, CH) (int x, int y, CW width, CH height) @trusted nothrow @nogc
if (isIntegral!CW && isIntegral!CH)
{
  Rect rc = void;
  if (!normRect(rc, x, y, width, height)) return;
  usize pos = rc.y*ttyWdt+rc.x;
  foreach (_; 0..rc.height) {
    usize px = pos;
    foreach (_1; 0..rc.width) setShadow(px++);
    pos += ttyWdt;
  }
}


void writeShadow (in Rect rc) @trusted nothrow @nogc {
  if (!rc.empty) writeShadow(rc.x, rc.y, rc.width, rc.height);
}


// ////////////////////////////////////////////////////////////////////////// //
Glyph readGlyph (int x, int y) @trusted nothrow @nogc {
  x += windowArea.x;
  y += windowArea.y;
  if (windowArea.inside(x, y) && screenArea.inside(x, y)) return vbufs[0][y*ttyWdt+x];
  return Glyph(); // impossible glyph
}


void writeGlyph (int x, int y, in Glyph g) @trusted nothrow @nogc {
  x += windowArea.x;
  y += windowArea.y;
  if (g.valid && windowArea.inside(x, y) && screenArea.inside(x, y)) vbufs[0][y*ttyWdt+x] = g;
}


// ////////////////////////////////////////////////////////////////////////// //
class SavedArea {
private:
  Rect mArea = void;
  Glyph[] mData;

public:
  this(CW, CH) (int x, int y, CW width, CH height) @trusted if (isIntegral!CW && isIntegral!CH) {
    mArea.set(x, y, width, height);
    if (!mArea.empty) {
      usize pos = 0;
      mData = new Glyph[](width*height);
      foreach (sy; mArea.y0..mArea.y1+1) {
        foreach (sx; mArea.x0..mArea.x1+1) {
          mData[pos++] = readGlyph(sx, sy);
        }
      }
    }
  }

final:
  @property Rect area () const @safe nothrow @nogc { return mArea; }
  @property int width () const @safe nothrow @nogc { return (!mArea.empty ? mArea.width : 0); }
  @property int height () const @safe nothrow @nogc { return (!mArea.empty ? mArea.height : 0); }

  void restore () @trusted nothrow @nogc { if (!mArea.empty) blit(mArea.x, mArea.y); }
  void save () @trusted nothrow @nogc { if (!mArea.empty) read(mArea.x, mArea.y); }

  void blit (int x, int y) @trusted nothrow @nogc {
    if (!mArea.empty) {
      usize pos = 0;
      foreach (sy; y..y+mArea.height) {
        foreach (sx; x..x+mArea.width) {
          writeGlyph(sx, sy, mData[pos++]);
        }
      }
    }
  }

  void read (int x, int y) @trusted nothrow @nogc {
    if (!mArea.empty) {
      usize pos = 0;
      foreach (sy; y..y+mArea.height) {
        foreach (sx; x..x+mArea.width) {
          mData[pos++] = readGlyph(sx, sy);
        }
      }
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
private void drawHLineImpl(CW) (bool mix, int x, int y, CW width, Color fg, Color bg)
if (isIntegral!CW)
{
  immutable CW owdt = width;
  int leftSkip;
  if (!normStripe(x, y, width, leftSkip)) return;
  usize pos = y*ttyWdt+x;
  immutable bool hasLast = (owdt == width);
  if (leftSkip == 0) {
    // has 'first' char (and maybe 'last')
    if (hasLast && width == 1) {
      // has both
      vbufs[0][pos].setLine(GraphRight|GraphLeft, mix);
      fixAttr(pos, fg, bg);
      return;
    } else {
      vbufs[0][pos].setLine(GraphRight, mix);
      fixAttr(pos++, fg, bg);
      if (--width == 0) return;
    }
  }
  foreach (idx; 0..width-(hasLast ? 1 : 0)) {
    vbufs[0][pos].setLine(GraphLeft|GraphRight, mix);
    fixAttr(pos++, fg, bg);
  }
  if (hasLast && width > 0) {
    // has 'last' char
    vbufs[0][pos].setLine(GraphLeft, mix);
    fixAttr(pos, fg, bg);
  }
}


void drawHLine(CW) (int x, int y, CW width, Color fg=Color.None, Color bg=Color.None)
if (isIntegral!CW)
{
  drawHLineImpl(true, x, y, width, fg, bg);
}

void writeHLine(CW) (int x, int y, CW width, Color fg=Color.None, Color bg=Color.None)
if (isIntegral!CW)
{
  drawHLineImpl(false, x, y, width, fg, bg);
}


// ////////////////////////////////////////////////////////////////////////// //
private void drawVLineImpl(CH) (bool mix, int x, int y, CH height, Color fg, Color bg)
if (isIntegral!CH)
{
  auto rc = Rect(x, y, 1, height);
  if (!normRect(rc)) return;
  usize pos = rc.y*ttyWdt+rc.x;
  immutable bool hasLast = (cast(uint)rc.height == height); // has 'last' char?
  if (rc.y == y+windowArea.y) {
    // has 'first' char (and maybe 'last')
    if (hasLast && rc.height == 1) {
      vbufs[0][pos].setLine(GraphDown|GraphUp, mix);
      fixAttr(pos, fg, bg);
      return;
    } else {
      vbufs[0][pos].setLine((hasLast && rc.height == 1 ? GraphDown|GraphUp : GraphDown), mix);
      fixAttr(pos, fg, bg);
      pos += ttyWdt;
      if (--rc.height == 0) return;
    }
  }
  foreach (idx; 0..rc.height-(hasLast ? 1 : 0)) {
    vbufs[0][pos].setLine(GraphDown|GraphUp, mix);
    fixAttr(pos, fg, bg);
    pos += ttyWdt;
  }
  if (hasLast && rc.height > 0) {
    // has 'last' char and it's not the only char in line
    vbufs[0][pos].setLine(GraphUp, mix);
    fixAttr(pos, fg, bg);
  }
}


void drawVLine(CH) (int x, int y, CH height, Color fg=Color.None, Color bg=Color.None)
if (isIntegral!CH)
{
  drawVLineImpl(true, x, y, height, fg, bg);
}


void writeVLine(CH) (int x, int y, CH height, Color fg=Color.None, Color bg=Color.None)
if (isIntegral!CH)
{
  drawVLineImpl(false, x, y, height, fg, bg);
}


// ////////////////////////////////////////////////////////////////////////// //
void drawFrame(CW, CH) (int x, int y, CW width, CH height, Color fg=Color.None, Color bg=Color.None)
if (isIntegral!CW && isIntegral!CH)
{
  if (width < 1 || height < 1) return;
  // left vbar
  drawVLine(x, y, height, fg, bg);
  // right vbar
  drawVLine(x+cast(int)width-1, y, height, fg, bg);
  // top hbar
  drawHLine(x, y, width, fg, bg);
  // bottom hbar
  drawHLine(x, y+cast(int)height-1, width, fg, bg);
}


void drawFilledFrame(CW, CH) (int x, int y, CW width, CH height, Color fg=Color.None, Color bg=Color.None)
if (isIntegral!CW && isIntegral!CH)
{
  if (width < 1 || height < 1) return;
  drawFrame(x, y, width, height, fg, bg);
  if (width > 2 && height > 2) fillChar(x+1, y+1, width-2, height-2, ' ', fg, bg);
}


// ////////////////////////////////////////////////////////////////////////// //
void writeFrame(CW, CH) (int x, int y, CW width, CH height, Color fg=Color.None, Color bg=Color.None)
if (isIntegral!CW && isIntegral!CH)
{
  if (width < 1 || height < 1) return;
  // left vbar
  writeCharV(x, y, height, ' ');
  // right vbar
  writeCharV(x+cast(int)width-1, y, height, ' ');
  // top hbar
  writeChar(x, y, width, ' ');
  // bottom hbar
  writeChar(x, y+cast(int)height-1, width, ' ');
  // draw frame
  drawFrame(x, y, width, height, fg, bg);
}


void writeFilledFrame(CW, CH) (int x, int y, CW width, CH height, Color fg=Color.None, Color bg=Color.None)
if (isIntegral!CW && isIntegral!CH)
{
  if (width < 1 || height < 1) return;
  writeFrame(x, y, width, height, fg, bg);
  if (width > 2 && height > 2) fillChar(x+1, y+1, width-2, height-2, ' ', fg, bg);
}


// ////////////////////////////////////////////////////////////////////////// //
/// generic TUI exception
/+
class WidgetError : object.Exception {
  this (string msg, string file=__FILE__, usize line=__LINE__, Throwable next=null) @safe pure nothrow {
    super(msg, file, line, next);
  }
}
+/
