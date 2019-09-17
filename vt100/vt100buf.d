/* coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * Understanding is not required. Only obedience.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 3 of the License ONLY.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */
module iv.vt100.vt100buf;
private:

import iv.alice;
import iv.strex;
import iv.utfutil;
import iv.x11;

import iv.vt100.scrbuf;


// ////////////////////////////////////////////////////////////////////////// //
// screen buffer with VT-100 emulator
public class VT100Buf : ScreenBuffer {
protected:
  bool mIsUTF8 = true; // should putc interpret UTF-8? use koi8 if false

public:
  this (int aw, int ah, bool mIsUtfuck=true) nothrow @safe {
    super(aw, ah);
    mGAltBuf.length = aw*ah; // alternative screen
    mIsUTF8 = mIsUtfuck;
    reset(); // reset terminal
  }

  ~this () {}

  // called by various functions when emulator wants to output data to execed application
  void putData (const(void)[] buf) nothrow @trusted @nogc {}

  // DO NOT CALL!
  override void intrClear () nothrow @trusted {
    super.intrClear();
    delete mGAltBuf;
  }

  override void resize (int aw, int ah) nothrow @trusted {
    if (aw < 1 || ah < 1 || aw > MaxBufferWidth || ah > MaxBufferHeight) assert(0, "invalid screen buffer size");
    if (aw == mWidth && ah == mHeight) return;
    if (!altScreen) {
      // on a normal screen
      //{ import core.stdc.stdio; stderr.fprintf("RESIZE from %dx%d to %dx%d (NORMAL)\n", mWidth, mHeight, aw, ah); }
      resizeBuf(mGBuf, aw, ah);
      resizeBufSimple(mGAltBuf, aw, ah);
    } else {
      // on an alternalte screen
      //{ import core.stdc.stdio; stderr.fprintf("RESIZE from %dx%d to %dx%d (ALT)\n", mWidth, mHeight, aw, ah); }
      resizeBufSimple(mGBuf, aw, ah);
      resizeBuf(mGAltBuf, aw, ah);
    }
    mWidth = aw;
    mHeight = ah;
    resetOnResize();
  }

  // provide at least 16 chars in `dest`
  // empty result is "oops"
  char[] key2tty (char[] dest, dchar dch, KeySym ksym, X11ModState modstate) {
    usize dpos = 0;
    bool didit = false;

    version(none) scope(exit) {
      if (didit) {
        import core.stdc.stdio;
        fprintf(stderr, "\n");
      }
    }

    void put (const(char)[] s...) nothrow @trusted @nogc {
      if (s.length == 0) return;
      didit = true;
      version(none) {
        import core.stdc.stdio;
        foreach (char ch; s) {
          if (ch <= ' ' || ch >= 127) stderr.fprintf("{%u}", cast(uint)ch); else stderr.fprintf("%c", ch);
        }
      }
      foreach (char ch; s) {
        if (dpos < dest.length) dest.ptr[dpos++] = ch;
      }
    }

    if (modstate == "" && ksym == XK_BackSpace) put("\x7f");

    // rxvt navigation keys
    if (!didit) {
      char xc = 0;
      switch (ksym) {
        case XK_Insert: xc = '2'; break;
        case XK_Delete: xc = '3'; break;
        case XK_Prior: xc = '5'; break;
        case XK_Next: xc = '6'; break;
        case XK_Home: xc = '7'; break;
        case XK_End: xc = '8'; break;
        default: break;
      }
      if (xc) {
        if (modstate.meta) put("\x1b");
        modstate.meta = false;
        put("\x1b[");
        put(xc);
             if (modstate.ctrl && modstate.shift) put("@");
        else if (modstate.ctrl) put("^");
        else if (modstate.shift) put("$");
        else put("~");
      }
    }

    // rxvt function keys
    if (!didit) {
      int fcode = 0;
      switch (ksym) {
        case XK_F1: fcode = (modstate.shift ? 23 : 11); break;
        case XK_F2: fcode = (modstate.shift ? 24 : 12); break;
        case XK_F3: fcode = (modstate.shift ? 25 : 13); break;
        case XK_F4: fcode = (modstate.shift ? 26 : 14); break;
        case XK_F5: fcode = (modstate.shift ? 28 : 15); break;
        case XK_F6: fcode = (modstate.shift ? 29 : 17); break;
        case XK_F7: fcode = (modstate.shift ? 31 : 18); break;
        case XK_F8: fcode = (modstate.shift ? 32 : 19); break;
        case XK_F9: fcode = (modstate.shift ? 33 : 20); break;
        case XK_F10: fcode = (modstate.shift ? 34 : 21); break;
        case XK_F11: fcode = 23; break;
        case XK_F12: fcode = 24; break;
        default: break;
      }
      if (fcode) {
        if (modstate.meta) put("\x1b");
        modstate.meta = false;
        put("\x1b[");
        put(cast(char)(fcode/10+'0'));
        put(cast(char)(fcode%10+'0'));
             if (modstate.ctrl || modstate.shift) put("@");
        else if (modstate.ctrl) put("^");
        else put("~");
      }
    }

    // rxvt arrows
    if (!didit) {
      char xc = 0;
      switch (ksym) {
        case XK_Up: xc = 'A'; break;
        case XK_Down: xc = 'B'; break;
        case XK_Right: xc = 'C'; break;
        case XK_Left: xc = 'D'; break;
        default: break;
      }
      if (xc) {
        if (modstate.meta) put("\x1b");
        modstate.meta = false;
        put("\x1b");
        if (modstate.shift) xc += 32; // to lower case
        if (modstate.ctrl) put("O"); else put("[");
        put(xc);
      }
    }

    char normch = 0;
    mixin((){
      string res = `switch (ksym) {`;
      foreach (immutable cc; 'A'..'Z'+1) {
        res ~= `case XK_`;
        res ~= cast(char)cc;
        res ~= `: normch = '`;
        res ~= cast(char)cc;
        res ~= `'; break;`;
      }
      res ~= `default: break;}`;
      return res;
    }());

    // rxvt alt/ctrl
    if (!didit && normch && (modstate.ctrl || modstate.meta)) {
      if (modstate.meta) put("\x1b");
      modstate.meta = false;
      if (modstate.ctrl) {
        if (normch >= 'a' && normch <= 'z') normch -= 32; //toupper
        put(cast(char)(normch-'A'+1));
      } else {
        if (modstate.shift && normch >= 'a' && normch <= 'z') normch -= 32; //toupper
        if (!modstate.shift && normch >= 'A' && normch <= 'Z') normch += 32; //tolower
        put(normch);
      }
    }

    // return?
    if (!didit && ksym == XK_Return && modstate.meta && !modstate.ctrl && !modstate.shift) {
      put("\x1b\n");
    }

    // tab?
    if (!didit && ksym == XK_Tab) {
      if (modstate == "") {
        put("\t");
      } else if (modstate.meta && !modstate.ctrl && !modstate.shift) {
        // only meta
        put("\x1b\t");
      } else {
             if (modstate.meta && !modstate.ctrl && modstate.shift) put("\x1b[1;4Z");
        else if (!modstate.meta && modstate.ctrl && !modstate.shift) put("\x1b[1;5Z");
        else if (!modstate.meta && modstate.ctrl && modstate.shift) put("\x1b[1;6Z");
        else if (modstate.meta && modstate.ctrl && !modstate.shift) put("\x1b[1;7Z");
        else if (modstate.meta && modstate.ctrl && modstate.shift) put("\x1b[1;8Z");
      }
    }

    // non-ascii?
    if (!didit && dch >= 128) {
      if (mIsUTF8) {
        // to utfuck
        char[8] u = 0;
        int len = utf8Encode(u[], dch);
        if (len > 0) put(u[0..len]);
      } else {
        char kch = uni2koi!'\0'(dch);
        if (kch) {
          if (modstate.meta) put("\x1b");
          put(kch);
        }
      }
    }

    // normal char?
    if (!didit && dch > 0 && dch < 128) {
      if (modstate.meta) put("\x1b");
      put(cast(char)dch);
    }

    return (dpos > 0 ? dest[0..dpos] : null);
  }

  // `true`: eaten
  override bool keypressEvent (dchar dch, KeySym ksym, X11ModState modstate) {
    if (modstate.hyper) return false;
    modstate.hyper = false;
    //if (dch == 8) { import core.stdc.stdio; stderr.fprintf("\n!!!***!!!\n"); }
    doKeyTrans(ksym);
    char[16] ktc = 0;
    auto ttyc = key2tty(ktc[], dch, ksym, modstate);
    if (ttyc.length) putData(ttyc);
    return (ttyc.length > 0);
  }

  // ////////////////////////////////////////////////////////////////////// //
  // terminal emulation code
protected:
  enum DECIDSTR = "\x1b[?1;0c";
  enum Terminus = true;

protected:
  Glyph[] mGAltBuf; // alternative screen
  int mAltCurX, mAltCurY;
  bool mAltCurVis;

  // terminal mode flags (bitmask)
  public enum Mode {
    Normal      = 0x00,
    DoWrap      = 0x01,
    Insert      = 0x02,
    AppKeypad   = 0x04,
    AltScreen   = 0x08,
    CRLF        = 0x10,
    MouseBtn    = 0x20,
    MouseMotion = 0x40,
    Mouse       = 0x20|0x40,
    Reversed    = 0x80,
    BracPaste   = 0x100,
    FocusEvt    = 0x200,
    DispCtrl    = 0x400, //TODO: not implemented yet
    Gfx0        = 0x1000,
    Gfx1        = 0x2000,
    ScrollLock  = 0x4000, // set: cursor is locked in scroll region, home is (0, mTop)
    NoEcho      = 0x8000, // echo non-control characters on screen?
  }
  uint mMode = Mode.Normal;

  ushort mCharset = Mode.Gfx0; // Mode.Gfx0 or Mode.Gfx1
  ubyte mTabSize = 8;

  enum MouseMode {
    X10 = 9,
    XTerm = 1000,
    Utf8 = 1005,
    SGR = 1006,
    URxvt = 1015,
  }
  MouseMode mMouseMode = MouseMode.XTerm;

  static struct CurState {
    int x, y;
    Attr a;
    int top, bot; // scroll area
    ushort charset; // Mode.Gfx0 and Mode.Gfx1 only
  }
  CurState mCurSaved;

  final void saveTo (ref CurState cs) nothrow @safe @nogc {
    cs.x = mCurX;
    cs.y = mCurY;
    cs.a = mCurAttr;
    cs.top = mTop;
    cs.bot = mBot;
    cs.charset = mMode&(Mode.Gfx0|Mode.Gfx1);
  }

  final void restoreFrom (in ref CurState cs) nothrow @safe @nogc {
    mCurX = cs.x;
    mCurY = cs.y;
    mCurAttr = cs.a;
    mTop = cs.top;
    mBot = cs.bot;
    mMode = (mMode&~(Mode.Gfx0|Mode.Gfx1))|(cs.charset&(Mode.Gfx0|Mode.Gfx1));
  }

  // scroll area
  int mTop, mBot; // 0..mHeight-1

  // collecting UTF-8 chars here
  char[4] mCharBuf;
  usize mCBUsed;

  // escape sequence processor state
  enum Esc {
    None,
    Start, // got '\e'
    CSI,
    OSC,
    Title,
    AltG0,
    AltG1,
    Hash,
    Percent,
    IgnoreNext, // ignore next char and finish ESC
  }
  ubyte mEsc = Esc.None; // escape state flags

  // CSI Escape sequence structs
  // ESC '[' [[ [<priv>] <arg> [;]] <mode>]
  static struct EscState {
  nothrow @safe @nogc:
    bool priv = false;
    ushort[64] arg;
    usize narg; // # of collected args
    char mode = '\0'; // escape mode

    protected bool firstChar = true;
    protected bool wasNum = false;

    void reset () { pragma(inline, true); this = this.init; }

    ushort opIndex (usize idx) @trusted { pragma(inline, true); return (idx < narg ? max(arg.ptr[idx], 1) : 1); }
    // weird abuse of index operation
    ushort opIndex (usize idx, ushort defval) @trusted { pragma(inline, true); return (idx < narg && arg.ptr[idx] ? arg.ptr[idx] : defval); }

    // parse CSI
    // return true if sequence is completed
    bool putdc (dchar ch) {
      // control char?
      if (ch < 32 || ch == 127) return false; // ignore control char
      if (firstChar) {
        firstChar = false;
        if (ch == '?') {
          priv = true;
          return false; // go on
        }
      }
      // digit?
      if (ch >= '0' && ch <= '9') {
        wasNum = true;
        if (narg < arg.length) {
          int n = arg[narg]*10+ch-'0';
          if (n > 65535) n = 65535;
          arg[narg] = cast(ushort)n;
        }
        return false; // go on
      }
      // not a digit
      if (wasNum) {
        // previous was a digit, register new arg
        wasNum = false;
        if (narg < arg.length) ++narg;
      }
      // arg separator?
      if (ch == ';') return false; // go on
      // end of sequence
      if (ch > 0x7f) ch = '.';
      mode = cast(char)ch;
      //dump();
      return true; // got it
    }

    void dump () const @trusted {
      import core.stdc.stdio : printf;
      printf(`\x1b[`);
      if (priv) printf("?");
      foreach (immutable idx; 0..narg) {
        if (idx) printf(";");
        printf("%u", cast(uint)arg[idx]);
      }
      printf("%c\n", mode);
    }
  }
  EscState mEscSeq;

  // UTF-8
  char[1024] mTitle;
  usize mTitleLen;

protected:
  final void doClear(string mode="") (int x0, int y0, int x1, int y1) nothrow @trusted @nogc {
    static assert(mode == "" || mode == "KeepAttr", "invalid mode for doClear");
    if (x1 < 0 || y1 < 0) return;
    if (x0 > x1 || y0 > y1 || x0 >= mWidth || y0 >= mHeight) return;
    int sx = max(0, min(x0, mWidth-1));
    int sy = max(0, min(y0, mHeight-1));
    int ex = max(0, min(x1, mWidth-1));
    int ey = max(0, min(y1, mHeight-1));
    if (sx > ex || sy > ey) return;
    static if (mode != "KeepAttr") { auto ng = Glyph(' ', mCurAttr); ng.dirty = true; }
    foreach (immutable y; sy..ey+1) {
      mGBuf.ptr[(y+1)*mWidth-1].mAttr.autoWrap = false;
      static if (mode == "KeepAttr") {
        // keep attributes
        foreach (ref Glyph g; mGBuf.ptr[y*mWidth+sx..y*mWidth+ex+1]) {
          if (g.ch != ' ') {
            if (!g.dirty) ++mDirtyCount;
            g.ch = ' ';
            g.dirty = true;
          }
        }
      } else {
        // clear attributes
        foreach (ref Glyph g; mGBuf.ptr[y*mWidth+sx..y*mWidth+ex+1]) {
          if (g != ng) {
            if (!g.dirty) ++mDirtyCount;
            g = ng;
          }
        }
      }
    }
  }

  final void doScroll(string dir, string mode="") (int y0, int y1, int amount) nothrow {
    static assert(dir == "up" || dir == "down", "invalid scroll direction");
    static assert(mode == "" || mode == "KeepAttr", "invalid mode for doScroll");
    // scrolling down should never use "keepAttr"
    static if (dir == "down") {
      static assert(mode == "", "internal ditty error");
    }
    assert(amount >= 0);
    if (y1 < 0 || amount == 0 || y1 < y0 || y0 >= mHeight) return;
    amount = min(amount, mHeight);
    y0 = max(0, min(y0, mHeight-1));
    y1 = max(0, min(y1, mHeight-1));
    if (y1 < y0) return;
    if (amount >= y1-y0+1) {
      // clear
      doClear!mode(0, y0, mWidth, y1);
    } else {
      // scroll it
      bool wasDirty = (mDirtyCount != 0);
      static if (dir == "up") {
        int srcy = y0+amount;
        int desty = y0;
        while (srcy <= y1) {
          foreach (immutable cx; 0..mWidth) {
            auto go = mGBuf[desty*mWidth+cx];
            auto gn = mGBuf[srcy*mWidth+cx];
            if (go != gn) {
              if (!go.dirty) ++mDirtyCount;
              gn.dirty = true;
              mGBuf[desty*mWidth+cx] = gn;
            }
          }
          ++srcy;
          ++desty;
        }
        // clear new lines
        doClear!mode(0, y1-amount+1, mWidth, y1);
        if (onScrollUp !is null) onScrollUp(this, y0, y1, amount, wasDirty);
      } else {
        int srcy = y1-amount;
        int desty = y1;
        while (srcy >= y0) {
          foreach (immutable cx; 0..mWidth) {
            auto go = mGBuf[desty*mWidth+cx];
            auto gn = mGBuf[srcy*mWidth+cx];
            if (go != gn) {
              if (!go.dirty) ++mDirtyCount;
              gn.dirty = true;
              mGBuf[desty*mWidth+cx] = gn;
            }
          }
          --srcy;
          --desty;
        }
        doClear!mode(0, y0, mWidth, y0+amount-1);
        if (onScrollDown !is null) onScrollDown(this, y0, y1, amount, wasDirty);
      }
    }
  }

  // scroll characters in line to right, starting from x0
  // fill new chars with current attribute
  final void doInsertChars (int cx, int amount) nothrow {
    if (mCurY < 0 || mCurY >= mHeight || amount < 1 || cx >= mWidth) return;
    if (cx < 0) cx = 0;
    if (amount >= mWidth || amount+cx >= mWidth) { doClear(cx, mCurY, mWidth, mCurY); return; }
    foreach_reverse (immutable pos; cx+amount..mWidth) {
      auto og = mGBuf[mCurY*mWidth+pos];
      auto ng = mGBuf[mCurY*mWidth+pos-amount];
      if (og != ng) {
        if (!og.dirty) ++mDirtyCount;
        ng.dirty = true;
        mGBuf[mCurY*mWidth+pos] = ng;
      }
    }
    // clear scrolled part
    doClear(cx, mCurY, cx+amount-1, mCurY);
  }

  // scroll characters in line to left, starting from x0
  // fill new chars with current attribute
  final void doDeleteChars (int cx, int amount) nothrow {
    if (mCurY < 0 || mCurY >= mHeight || amount < 1 || cx >= mWidth) return;
    if (cx < 0) cx = 0;
    if (amount >= mWidth || amount+cx >= mWidth) { doClear(cx, mCurY, mWidth, mCurY); return; }
    foreach (immutable pos; cx+amount..mWidth) {
      auto og = mGBuf[mCurY*mWidth+pos-amount];
      auto ng = mGBuf[mCurY*mWidth+pos];
      if (og != ng) {
        if (!og.dirty) ++mDirtyCount;
        ng.dirty = true;
        mGBuf[mCurY*mWidth+pos-amount] = ng;
      }
    }
    // clear scrolled part
    doClear(mWidth-amount, mCurY, mWidth-1, mCurY);
  }

public:
  final @property pure nothrow @safe @nogc {
    // getters
    const {
      bool isUTF8 () { pragma(inline, true); return mIsUTF8; }

      uint mode () { pragma(inline, true); return mMode; }
      bool altScreen () { pragma(inline, true); return ((mMode&Mode.AltScreen) != 0); }
      bool keypadMode () { pragma(inline, true); return ((mMode&Mode.AppKeypad) != 0); }
      bool mouseButtonReport () { pragma(inline, true); return ((mMode&Mode.MouseBtn) != 0); }
      bool mouseMotionReport () { pragma(inline, true); return ((mMode&Mode.MouseMotion) != 0); }
      MouseMode mouseMode () { pragma(inline, true); return mMouseMode; }
      bool reversed () { pragma(inline, true); return ((mMode&Mode.Reversed) != 0); }
      bool bracketPaste () { pragma(inline, true); return ((mMode&Mode.BracPaste) != 0); }
      bool focusReport () { pragma(inline, true); return ((mMode&Mode.FocusEvt) != 0); }
      ubyte tabSize () { pragma(inline, true); return mTabSize; }
    }
    // setters
    void tabSize (ubyte v) { if (v < 1) v = 1; mTabSize = v; }
    void isUTF8 (bool v) { if (mIsUTF8 != v) { mIsUTF8 = v; mCBUsed = 0; } }
  }

public:
  // button: 1=left, 2=middle, 3=right
  override void doMouseReport (uint x, uint y, MouseEvent event, ubyte button, uint mods) {
    char[32] buf;
    usize bufpos;
    char lastCh = 'M';

    void putStr() (const(char)[] s...) {
      foreach (char ch; s) {
        if (bufpos >= buf.length) assert(0, "WTF?!");
        buf[bufpos++] = ch;
      }
    }

    void putUtf8Char() (uint ch) {
      char[4] buf;
      auto len = utf8Encode(buf[], cast(dchar)ch);
      if (len > 0) putStr(buf[0..len]);
    }

    void putNum() (uint num) {
      char[8] nn;
      usize pos = nn.length;
      if (num > 65535) num = 65535;
      do {
        nn[--pos] = cast(char)(num%10+'0');
        num /= 10;
      } while (num != 0);
      putStr(nn[pos..$]);
    }

    if (x >= width || y >= height) return;

    if (event == MouseEvent.Motion) {
      // we doesn't do motion tracking
      //if (!mouseMotionReport) return;
      return;
    }

    if (event != MouseEvent.Up && event != MouseEvent.Down) return;
    if (!mouseButtonReport) return;
    if (button == 0 || button > 5) return;
    --button; // convert button number to zero-based
    immutable evDown = (event == MouseEvent.Down);
    immutable exButton = (button >= 3);
    if (evDown && exButton) return; // no release events for wheel buttons
    if (exButton) button -= 3;

    immutable ss =
      (evDown ? button : 3)|
      (mods&MouseMods.Shift ? 0b0000_0100 : 0)|
      (mods&MouseMods.Meta  ? 0b0000_1000 : 0)|
      (mods&MouseMods.Ctrl  ? 0b0001_0000 : 0)|
      (exButton             ? 0b0100_0000 : 0);

    final switch (mouseMode) {
      case MouseMode.X10:
        putStr("\x1b[M"); // CSI M
        putStr(cast(char)(button+32));
        putStr(cast(char)(min(x, 222)+33));
        putStr(cast(char)(min(y, 222)+33));
        break;
      case MouseMode.XTerm:
        putStr("\x1b[M"); // CSI M
        putStr(cast(char)(ss+32));
        putStr(cast(char)(min(x, 222)+33));
        putStr(cast(char)(min(y, 222)+33));
        break;
      case MouseMode.Utf8:
        putStr("\x1b[M"); // CSI M
        putUtf8Char(ss+32);
        putUtf8Char(x+33);
        putUtf8Char(y+33);
        break;
      case MouseMode.SGR:
        putStr("\x1b[<"); // CSI <
        putNum((ss&~3)|button); // release encoded differently
        putStr(';');
        putNum(x+1);
        putStr(';');
        putNum(y+1);
        putStr(evDown ? 'M' : 'm');
        break;
      case MouseMode.URxvt:
        putStr("\x1b["); // CSI
        putNum(ss+32);
        putStr(';');
        putNum(x+1);
        putStr(';');
        putNum(y+1);
        putStr('M');
        break;
    }
    putData(buf[0..bufpos]);
  }

protected:
  // do "newline" with possible scrolling
  final void doNewline(string mode="") () nothrow {
    static assert(mode == "" || mode == "cr", "invalid doNewline mode");
    //FIXME: if cursor is unlocked, should we scroll when cursor was moved out of scroll area?
    static if (mode == "cr") mCurX = 0;
    // need to scroll?
    if (mCurY == mBot) {
      // move cursor out of scrolling region if cursor is not locked
      if (mBot < mHeight-1 && !(mMode&Mode.ScrollLock)) ++mCurY;
      // send scroll event
      // is this "scroll to history" event?
      if (!altScreen && mTop == 0 && mBot == mHeight-1 && onAppendHistory !is null) {
        // store top line to history
        onAppendHistory(mGBuf[0..mWidth]);
      }
      doScroll!"up"(mTop, mBot, 1);
    } else {
      // just move cursor
      ++mCurY;
      assert(mCurY < mHeight);
    }
  }

  final void swapScreen () nothrow @trusted @nogc {
    mMode ^= Mode.AltScreen;
    // fixes for "main" screen
    if (!altScreen) {
      // force visible cursor on "main" screen
      if (!mCurVis) curVisible = true;
      // force "normal" charset
      mCharset = Mode.Gfx0;
      mMode &= ~Mode.Gfx0;
    }
    // swap buffers
    assert(mGBuf.length == mGAltBuf.length);
    foreach (immutable pos, ref Glyph og; mGBuf) {
      auto ng = mGAltBuf.ptr[pos];
      if (ng != og) {
        auto tmpg = og;
        if (!og.dirty) ++mDirtyCount;
        og = ng;
        og.dirty = true;
        tmpg.dirty = false;
        mGAltBuf.ptr[pos] = tmpg;
      }
    }
  }

  final void ttyGotoXY (int nx, int ny) nothrow @safe @nogc {
    nx = between!int(0, mWidth-1, nx);
    if (mMode&Mode.ScrollLock) {
      ny = between!int(mTop, mBot, ny+mTop);
    } else {
      ny = between!int(0, mHeight-1, ny);
    }
    gotoXY(nx, ny);
  }

  final void ttyGotoY (int ny) nothrow @safe @nogc {
    if (mMode&Mode.ScrollLock) {
      ny = between!int(mTop, mBot, ny+mTop);
    } else {
      ny = between!int(0, mHeight-1, ny);
    }
    gotoXY(mCurX, ny);
  }

  enum CtrlRes {
    Normal, // normal char
    Ctrl, // control char
    Interrupt // control char, interrupt esc sequence
  }

  final CtrlRes putCtrl (dchar ch) nothrow {
    if (mEsc == Esc.Title) return ((ch < ' ' || ch == 127) ? CtrlRes.Interrupt : CtrlRes.Normal);
    CtrlRes res = CtrlRes.Ctrl;
    switch (ch) {
      case '\t':
        if (mCurX < 0) return res;
        if (mCurX >= mWidth) { doNewline(); return res; }
        if (mTabSize == 0) return res;
        foreach (immutable _; 0..mTabSize-(mCurX%mTabSize)) putdc(' ');
        break;
      case '\b':
        if (mCurX > 0) ttyGotoXY(mCurX-1, mCurY);
        break;
      case '\r':
        if (mCurY >= 0 && mCurY < mHeight) mGBuf.ptr[mCurY*mWidth+mWidth-1].mAttr.autoWrap = false; // no autowrap
        if (mCurX > 0) ttyGotoXY(0, mCurY);
        break;
      case '\f': case '\n': case '\v':
        if (mCurY >= 0 && mCurY < mHeight) mGBuf.ptr[mCurY*mWidth+mWidth-1].mAttr.autoWrap = false; // no autowrap
        if (mMode&Mode.CRLF) doNewline!"cr"(); else doNewline();
        break;
      case '\a':
        if (onBell !is null) onBell(this);
        break;
      case 14:
        mCharset = Mode.Gfx1;
        break;
      case 15:
        mCharset = Mode.Gfx0;
        break;
      case 0x18:
      case 0x1a:
        // do nothing, interrupt current escape sequence
        res = CtrlRes.Interrupt;
        break;
      case '\x1b':
        mEscSeq.reset();
        mEsc = Esc.Start;
        break;
      case 127:
        break; // ignore it
      default:
        res = CtrlRes.Normal;
        break;
    }
    return res;
  }

  final void setAttrFromCSI () nothrow @safe @nogc {
    if (mEscSeq.narg == 0) { mCurAttr = Attr.init; return; }
    usize idx = 0;
    while (idx < mEscSeq.narg) {
      immutable aa = mEscSeq.arg[idx++];
      switch (aa) {
        case 0: mCurAttr = Attr.init; break;
        case 1: mCurAttr.bold = true; break;
        case 4: mCurAttr.underline = true; break;
        case 5: mCurAttr.blink = true; break;
        case 7: mCurAttr.reversed = true; break;
        case 21: case 22: mCurAttr.bold = false; break;
        case 24: mCurAttr.underline = false; break;
        case 25: mCurAttr.blink = false; break;
        case 27: mCurAttr.reversed = false; break;
        case 30: .. case 37:
          //setFGColor(aa-30);
          mCurAttr.fg = cast(ubyte)(aa-30);
          mCurAttr.defaultFG = false;
          break;
        case 38:
          if (idx+1 < mEscSeq.narg && mEscSeq.arg[idx] == 5) {
            //setFGColor(mEscSeq.arg[idx+1]);
            int clr = mEscSeq.arg[idx+1];
            if (clr < 0 || clr > 255) clr = 0;
            mCurAttr.fg = cast(ubyte)clr;
            mCurAttr.defaultFG = false;
            idx += 2;
            break;
          }
          goto case 39;
        case 39:
          //setFGColor(-1);
          mCurAttr.fg = 7;
          mCurAttr.defaultFG = true;
          break;
        case 40: .. case 47:
          //setBGColor(aa-40);
          mCurAttr.bg = cast(ubyte)(aa-40);
          mCurAttr.defaultBG = false;
          break;
        case 48:
          if (idx+1 < mEscSeq.narg && mEscSeq.arg[idx] == 5) {
            //setBGColor(mEscSeq.arg[idx+1]);
            int clr = mEscSeq.arg[idx+1];
            if (clr < 0 || clr > 255) clr = 0;
            mCurAttr.bg = cast(ubyte)clr;
            mCurAttr.defaultBG = false;
            idx += 2;
            break;
          }
          goto case 49;
        case 49:
          //setBGColor(-1);
          mCurAttr.bg = 0;
          mCurAttr.defaultBG = true;
          break;
        case 90: .. case 97:
          //setFGColor(aa-90+8);
          mCurAttr.fg = cast(ubyte)(aa-90+8);
          mCurAttr.defaultFG = false;
          break;
        case 100: .. case 107:
          //setBGColor(aa-100+8);
          mCurAttr.bg = cast(ubyte)(aa-100+8);
          mCurAttr.defaultBG = false;
          break;
        default: break;
      }
    }
  }

  // h
  final void doCSIModeSet (ushort code) nothrow @safe @nogc {
    switch (code) {
      case 3: mMode |= Mode.DispCtrl; break;
      case 4: mMode |= Mode.Insert; break;
      case 12: mMode |= Mode.NoEcho; break;
      case 20: mMode |= Mode.CRLF; break;
      default:
    }
  }

  // l
  final void doCSIModeReset (ushort code) nothrow @safe @nogc {
    switch (code) {
      //2: Keyboard Action Mode (AM)
      //12: Send/receive (SRM)
      case 3: mMode &= ~Mode.DispCtrl; break;
      case 4: mMode &= ~Mode.Insert; break;
      case 12: mMode &= ~Mode.NoEcho; break;
      case 20: mMode &= ~Mode.CRLF; break;
      default:
    }
  }

  // h
  final void doCSIPrvModeSet (ushort code) nothrow {
    switch (code) {
      case 1:
        mMode |= Mode.AppKeypad;
        break;
      case 2: // DECANM -- Designate USASCII for character sets G0-G3, and set VT100 mode
        mMode &= ~(Mode.Gfx0|Mode.Gfx1);
        break;
      case 3: // 132 column mode
        reset();
        break;
      case 5: // DECSCNM -- Reverse video
        if (!(mMode&Mode.Reversed)) {
          mMode |= Mode.Reversed;
          if (onReverseEvent !is null) onReverseEvent(this);
        }
        break;
      case 6: // DECOM -- set cursor origin and lock
        mMode |= Mode.ScrollLock;
        ttyGotoXY(0, 0);
        break;
      case 7: // autowrap on
        mMode |= Mode.DoWrap;
        break;
      case 20:
        mMode |= Mode.CRLF;
        break;
      case 25: // show cursor
        mCurVis = true;
        break;
      case 1002: // enable xterm mouse motion report
        if (!(mMode&Mode.MouseMotion)) {
          //mMsLastX = mMsLastY = ushort.max;
          mMode |= Mode.MouseMotion;
        }
        break;
      case 1004:
        mMode |= Mode.FocusEvt;
        break;
      case 9: // X10 mouse reporting
      case 1000: // enable xterm mouse report
      case 1005: // utf-8 mouse encoding
      case 1006: // sgr mouse encoding
      case 1015: // urxvt mouse encoding
        mMode |= Mode.MouseBtn;
        mMouseMode = cast(MouseMode)code;
        break;
      // switch to alternate screen
      case 47: // don't clear, don't save cursor
      case 1047: // clear, don't save cursor
      case 1049: // save cursor, clear
        if (!altScreen) {
          if (code == 1049) saveTo(mCurSaved);
          swapScreen();
          //onSwitchScreenEvent(code != 47);
          if (code != 47) doClear(0, 0, mWidth-1, mHeight-1);
        }
        break;
      case 1048: // save cursor position
        saveTo(mCurSaved);
        break;
      case 2004: // set bracketed paste mode
        mMode |= Mode.BracPaste;
        break;
      default:
    }
  }

  // l
  final void doCSIPrvModeReset (ushort code) nothrow {
    switch (code) {
      case 1: // 1001 for xterm compatibility
        mMode &= ~Mode.AppKeypad;
        break;
      case 3: // 80 column mode
        reset();
        break;
      case 5: // DECSCNM -- Remove reverse video
        if (mMode&Mode.Reversed) {
          mMode &= ~Mode.Reversed;
          if (onReverseEvent !is null) onReverseEvent(this);
        }
        break;
      case 6: // DECOM -- reset cursor origin and lock
        mMode &= ~Mode.ScrollLock;
        break;
      case 7: // autowrap off
        mMode &= ~Mode.DoWrap;
        break;
      case 9: // disable X10 mouse reporting
        mMode &= ~Mode.MouseBtn;
        break;
      case 20:
        mMode &= ~Mode.CRLF;
        break;
      case 25: // hide cursor
        mCurVis = false;
        break;
      case 1002:
        //mMsLastX = mMsLastY = ushort.max;
        mMode &= ~Mode.MouseMotion;
        break;
      case 1004:
        mMode &= ~Mode.FocusEvt;
        break;
      case 1000: // disable X11 xterm mouse reporting
      case 1005: // utf-8 mouse encoding
      case 1006: // sgr mouse encoding
      case 1015: // urxvt mouse encoding
        mMode &= ~Mode.MouseBtn;
        mMouseMode = MouseMode.XTerm;
        break;
      // switch to alternate screen
      case 47: // don't clear, don't save cursor
      case 1047: // clear, don't save cursor
      case 1049: // save cursor, clear
        if (altScreen) {
          swapScreen();
          if (code == 1049) restoreFrom(mCurSaved);
          //onSwitchScreenEvent(DoClear.No);
        }
        break;
      case 1048: // restore cursor position
        restoreFrom(mCurSaved);
        break;
      case 2004: // reset bracketed paste mode
        mMode &= ~Mode.BracPaste;
        break;
      default:
    }
  }

  final void performCSI () nothrow {
    void curUpDown(string mode="") (int d) {
      static assert(mode == "" || mode == "cr", "invalid mode");
      if (d) {
        int ncp;
        if (d < 0) {
          // move up
          ncp = mCurY-min(-d, mHeight);
          ncp = max(ncp, (mMode&Mode.ScrollLock ? mTop : 0));
        } else {
          // move down
          ncp = mCurY+min(d, mHeight);
          ncp = min(ncp, (mMode&Mode.ScrollLock ? mBot : mHeight-1));
        }
        static if (mode == "cr") mCurX = 0;
        mCurY = cast(ushort)ncp;
      }
    }

    void curLeftRight() (int d) {
      if (d) {
        int ncp;
        if (d < 0) {
          // left
          if (mCurX == 0) return;
          ncp = max(0, mCurX-min(-d, mWidth));
        } else {
          // right
          if (mCurX >= mWidth-1) return;
          ncp = min(mCurX+min(d, mWidth), mWidth-1);
        }
        mCurX = cast(ushort)ncp;
      }
    }

    //bool wasWrapping = false;
    switch (mEscSeq.mode) {
      case '@': // ICH -- Insert <n> blank chars
      case 'P': // DCH -- Delete <n> chars
        if (mCurX < mWidth) {
          immutable amount = mEscSeq[0];
          if (amount >= mWidth-mCurX) {
            // clear area
            doClear(mCurX, mCurY, mWidth, mCurY);
          } else {
            // "move" event
            if (mEscSeq.mode == '@') {
              doInsertChars(mCurX, amount);
            } else {
              doDeleteChars(mCurX, amount);
            }
          }
        }
        break;
      case 'A': // CUU -- Cursor <n> Up
      case 'e':
        curUpDown(-cast(int)mEscSeq[0]);
        break;
      case 'B': // CUD -- Cursor <n> Down
        curUpDown(mEscSeq[0]);
        break;
      case 'C': // CUF -- Cursor <n> Forward
      case 'a':
        curLeftRight(mEscSeq[0]);
        break;
      case 'D': // CUB -- Cursor <n> Backward
        curLeftRight(-cast(int)mEscSeq[0]);
        break;
      case 'E': // CNL -- Cursor <n> Down and first col
        curUpDown!"cr"(mEscSeq[0]);
        break;
      case 'F': // CPL -- Cursor <n> Up and first col
        curUpDown!"cr"(-cast(int)mEscSeq[0]);
        break;
      case 'G': // CHA -- Move to <col>
      case '`': // XXX: HPA -- same
        ttyGotoXY(mEscSeq[0]-1, mCurY);
        break;
      case 'H': // CUP -- Move to <row> <col>
      case 'f': // XXX: HVP -- same
        ttyGotoXY(mEscSeq[1]-1, mEscSeq[0]-1);
        break;
      // XXX: (CSI n I) CHT -- Cursor Forward Tabulation <n> tab stops
      case 'J': // ED -- Clear screen
        switch (mEscSeq.arg[0]) {
          case 0: // below
            if (mCurX < mWidth) doClear(mCurX, mCurY, mWidth, mCurY);
            doClear(0, cast(ushort)(mCurY+1), mWidth, mHeight);
            break;
          case 1: // above
            if (mCurX < mWidth-1) {
              // last line is incomplete
              if (mCurY > 0) doClear(0, 0, mWidth, cast(ushort)(mCurY-1));
              doClear(0, mCurY, mCurX, mCurY);
            } else {
              doClear(0, 0, mWidth, mCurY);
            }
            break;
          //case 2: // all
          default:
            doClear(0, 0, mWidth, mHeight);
            break;
        }
        break;
      case 'K': // EL -- Clear line
        switch (mEscSeq.arg[0]) {
          case 0: // right
            doClear(mCurX, mCurY, mWidth, mCurY);
            break;
          case 1: // left
            doClear(0, mCurY, mCurX, mCurY);
            break;
          //case 2: // all
          default:
            doClear(0, mCurY, mWidth, mCurY);
            break;
        }
        break;
      case 'S': // SU -- Scroll <n> lines up
        doScroll!"up"(mTop, mBot, mEscSeq[0]);
        break;
      case 'T': // SD -- Scroll <n> lines down
        doScroll!"down"(mTop, mBot, mEscSeq[0]);
        break;
      case 'L': // IL -- Insert <n> blank lines (scroll down)
        // only in scrolling region
        if (mCurY >= mTop && mCurY <= mBot) doScroll!"down"(mCurY, mBot, mEscSeq[0]);
        break;
      case 'M': // DL -- Delete <n> lines (scroll up)
        // only in scrolling region
        // lines added to bottom of screen have spaces with same character attributes as last line moved up
        if (mCurY >= mTop && mCurY <= mBot) doScroll!("up", "KeepAttr")(mCurY, mBot, mEscSeq[0]);
        break;
      case 'X': // ECH -- Erase <n> chars
        doClear(mCurX, mCurY, cast(ushort)(mCurX+min(mEscSeq[0], mWidth)-1), mCurY);
        break;
      // XXX: (CSI n Z) CBT -- Cursor Backward Tabulation <n> tab stops
      case 'd': // VPA -- Move to <row>
        ttyGotoY(mEscSeq[0]-1);
        break;
      case 'h': // SM -- Set terminal mode
      case 'l': // RM -- Reset Mode
        foreach (immutable code; mEscSeq.arg[0..mEscSeq.narg]) {
          if (mEscSeq.mode == 'h') {
            // set
            if (mEscSeq.priv) doCSIPrvModeSet(code); else doCSIModeSet(code);
          } else {
            // reset
            if (mEscSeq.priv) doCSIPrvModeReset(code); else doCSIModeReset(code);
          }
        }
        break;
      case 'm': // SGR -- Terminal attribute (color)
        setAttrFromCSI();
        break;
      case 'n':
        if (!mEscSeq.priv) {
          switch (mEscSeq.arg[0]) {
            case 5: // Device status report (DSR)
              putData("\x1b[0n");
              break;
            case 6: // cursor position report
              version(none) {
                import std.string : format;
                putData("\x1b[%s;%sR".format((mMode&Mode.ScrollLock ? mCurY-mTop : mCurY)+1, mCurX+1));
              } else {
                char[128] buf = void;
                import core.stdc.stdio;
                auto len = snprintf(buf.ptr, buf.length, "\x1b[%d;%dR", (mMode&Mode.ScrollLock ? mCurY-mTop : mCurY)+1, mCurX+1);
                if (len < 1) len = snprintf(buf.ptr, buf.length, "\x1b[1;1R");
                assert(len > 0);
                putData(buf[0..len]);
              }
              break;
            default:
          }
        }
        break;
      case 'r': // DECSTBM -- Set Scrolling Region
        if (mEscSeq.priv) {
          if (mEscSeq.arg[0] == 1001) {
            // xterm compatibility
            mMode &= ~Mode.AppKeypad;
          }
        } else {
          mTop = max(0, min(mEscSeq[0]-1, mHeight-1));
          mBot = max(0, min(mEscSeq[1, cast(ushort)mHeight]-1, mHeight-1));
          if (mTop > mBot) {
            immutable n = mTop;
            mTop = mBot;
            mBot = n;
          }
          // move cursor to home, as per http://www.vt100.net/docs/vt102-ug/chapter5.html
          ttyGotoXY(0, 0);
        }
        break;
      case 's': // DECSC -- Save cursor position (ANSI.SYS)
        if (mEscSeq.priv) {
          if (mEscSeq.arg[0] == 1001) {
            // xterm compatibility
            mMode |= Mode.AppKeypad;
          }
        } else {
          saveTo(mCurSaved);
        }
        break;
      case 'u': // DECRC -- Restore cursor position (ANSI.SYS)
        if (!mEscSeq.priv) {
          restoreFrom(mCurSaved);
        }
        break;
      case 'c': // same as ESC Z
        if (!mEscSeq.priv) {
          if (mEscSeq.narg == 0 || mEscSeq.arg[0] == 0) putData(DECIDSTR);
        }
        break;
      default:
    }
  }

  final bool processCSISeq (dchar ch) nothrow {
    if (mEsc != Esc.CSI) return false;
    if (mEscSeq.putdc(ch)) {
      version(dump_escapes) mEscSeq.dump();
      mEsc = Esc.None;
      performCSI();
    }
    return true;
  }

  final bool processOSCSeq (dchar ch) nothrow @safe @nogc {
    if (mEsc != Esc.OSC) return false;
    // TODO: handle other OSC
    if (mEscSeq.narg) {
      // other crap, do nothing
      if (ch < ' ' || ch == 127) {
        mEsc = Esc.None;
        return false;
      }
    } else {
      // collecting number
      if (ch >= '0' && ch <= '9') {
        auto n = mEscSeq.arg[0]+ch-'0';
        if (n > 65535) n = 65535;
        mEscSeq.arg[0] = cast(short)n;
      } else if (ch == ';') {
        ++mEscSeq.narg; // set "got number" flag
        if (mEscSeq.arg[0] == 0 || mEscSeq.arg[0] == 2) {
          mTitleLen = 0;
          mEsc = Esc.Title;
        } else {
          mEsc = Esc.None;
        }
      } else {
        mEsc = Esc.None;
        return false;
      }
    }
    return true;
  }

  final void finishTitle () nothrow {
    if (onNewTitleEvent !is null) onNewTitleEvent(this, mTitle[0..mTitleLen]);
  }

  final bool processTitleSeq (dchar ch) nothrow {
    if (mEsc != Esc.Title) return false;
    if (ch == '\a' || mTitleLen+1 >= mTitle.length) {
      mEsc = Esc.None;
      finishTitle();
    } else {
      char[4] buf;
      auto len = utf8Encode(buf[], ch);
      if (len > 0 && mTitleLen+len <= mTitle.length) {
        mTitle[mTitleLen..mTitleLen+len] = buf[0..len];
        mTitleLen += len;
      }
    }
    return true;
  }

  final bool processAltG0G1Seq (dchar ch) nothrow @safe @nogc {
    if (mEsc != Esc.AltG0 && mEsc != Esc.AltG1) return false;
    immutable xcs = (mEsc == Esc.AltG0 ? Mode.Gfx0 : Mode.Gfx1);
    mEsc = Esc.None;
    switch (ch) {
      case '0': // Line drawing crap
        mMode |= xcs;
        break;
      /*
      case 'A': // UK
      case 'B': // US
      case '1': // AltROM
      case '2': // AltROM special
      */
      default:
        mMode &= ~xcs;
        break;
    }
    return true;
  }

  final bool processHashSeq (dchar ch) nothrow {
    if (mEsc != Esc.Hash) return false;
    mEsc = Esc.None;
    switch (ch) {
      case '8': // DECALN -- DEC screen alignment test -- fill screen with E's
        //onFillWithEEvent();
        foreach (ref Glyph g; mGBuf) {
          if (g.ch != 'E') {
            if (!g.dirty) ++mDirtyCount;
            g.ch = 'E';
            g.dirty = true;
          }
        }
        break;
      default:
    }
    return true;
  }

  final bool processPercentSeq (dchar ch) nothrow @safe @nogc {
    if (mEsc != Esc.Percent) return false;
    mEsc = Esc.None;
    // case 'G': case '8': // select UTF-8 charset
    // case '@': // select default charset (ISO 8859-1)
    return true;
  }

  final bool processStartSeq (dchar ch) nothrow {
    if (mEsc != Esc.Start) return false;
    switch (ch) {
      case '[': mEsc = Esc.CSI; return true;
      case ']': mEsc = Esc.OSC; return true;
      case '(': mEsc = Esc.AltG0; return true;
      case ')': mEsc = Esc.AltG1; return true;
      case '#': mEsc = Esc.Hash; return true;
      case '%': mEsc = Esc.Percent; return true;
      case ' ': case '.': case '*': case '+': case '-': case '/': mEsc = Esc.IgnoreNext; return true;
      default: // other escapes
    }
    mEsc = Esc.None;
    version(dump_escapes) { import iv.writer; writeln("ESC:<", cast(char)ch, ">"); }
    switch (ch) {
      case 'D': // IND -- Linefeed
        doNewline();
        break;
      case 'E': // NEL -- Next line
        doNewline!"cr"();
        break;
      case 'M': // RI -- Reverse linefeed
        if (mCurY == mTop) {
          if (mCurY > 0 && !(mMode&Mode.ScrollLock)) --mCurY;
          doScroll!"down"(mTop, mBot, 1);
        } else {
          --mCurY;
        }
        break;
      case 'c': // RIS -- Reset to inital state
        reset();
        break;
      case '=': // DECPAM -- Application keypad
      case '>': // DECPNM -- Normal keypad
        break;
      case '7': // DECSC -- Save Cursor
        // Save current state (cursor coordinates, attributes, character sets pointed at by G0, G1) */
        saveTo(mCurSaved);
        break;
      case '8': // DECRC -- Restore Cursor
        // Restore current state (cursor coordinates, attributes, character sets pointed at by G0, G1) */
        restoreFrom(mCurSaved);
        break;
      case 'F': // Cursor to lower left corner of screen
        ttyGotoXY(0, mHeight);
        break;
      case 'Z': // DEC private identification
        // No options                   ESC [?1;0c
        // Processor option (STP)       ESC [?1;1c
        // Advanced video option (AVO)  ESC [?1;2c
        // AVO and STP                  ESC [?1;3c
        // Graphics option (GPO)        ESC [?1;4c
        // GPO and STP                  ESC [?1;5c
        // GPO and AVO                  ESC [?1;6c
        // GPO, STP and AVO             ESC [?1;7c
        // xterm: "64;1;2;6;6;9;15;18;21;22c"
        //emitSend("\x1b[?1;2;6c");
        putData(DECIDSTR);
        break;
      default:
        break;
    }
    return true;
  }

  final bool processEscapeSeq (dchar ch) nothrow {
    if (mEsc == Esc.None) return false;
    if (mEsc == Esc.IgnoreNext) { mEsc = Esc.None; return true; }
    return
      processStartSeq(ch) ||
      processCSISeq(ch) ||
      processOSCSeq(ch) ||
      processTitleSeq(ch) ||
      processAltG0G1Seq(ch) ||
      processHashSeq(ch) ||
      processPercentSeq(ch) ||
      processEscapeSeq(ch);
  }

public:
  override void onBlurFocus (bool focused) nothrow {
    if (focused) putData("\x1b[I"); else putData("\x1b[O");
  }

  // should mark dirty areas if necessary
  override void resetSelection () nothrow {
  }

  // should mark dirty areas if necessary
  override void doneSelection () nothrow {
  }

  // should mark dirty areas if necessary
  // this called by mouse handler, with cell coords
  // when mouse button released, `doneSelection()` will be called
  override void selectionChanged (int x, int y) nothrow {
  }

  override bool isInSelection (int x, int y) nothrow @trusted @nogc {
    return false;
  }

  override bool lineHasSelection (int y) nothrow @trusted @nogc {
    return false;
  }

  override string getSelectionText () nothrow {
    return null;
  }

public:
  final void putdstr (const(dchar)[] str...) nothrow {
    foreach (immutable ch; str) putdc(ch);
  }

  final void putdc (dchar ch) nothrow {
    version(none) {
      {
        import core.stdc.stdio;
        if (ch <= 32 || ch >= 127) stderr.fprintf("{%u}", cast(uint)ch); else stderr.fprintf("%c", cast(char)ch);
      }
    }
    final switch (putCtrl(ch)) {
      case CtrlRes.Normal: break;
      case CtrlRes.Ctrl:
        // control char; should not break escape sequence
        return;
      case CtrlRes.Interrupt:
        // control char; should break escape sequence
        bool inTitle = (mEsc == Esc.Title);
        mEsc = Esc.None;
        if (inTitle) finishTitle();
        return;
    }
    if (processEscapeSeq(ch)) return;
    // put normal char
    if (mCurX >= mWidth && !(mMode&Mode.DoWrap)) return; // wrapping, but wrap is off, don't want more chars
    //import ditty.utf8 : filterDC;
    wchar wch = filterDC(ch);
    if (wch < 32 || wch == 127) return; // seems that these chars are empty
    if (mMode&mCharset) {
      // map VT100 line drawing chars to unicode
      // http://vt100.net/docs/vt220-rm/table2-4.html
      // for terminus
      static if (Terminus) {
        bool terminus = true;
        if (wch >= '`' && wch <= 'i') wch = cast(wchar)(wch-'`'+1);
        else if (wch >= 'o' && wch <= 's' && wch != 'q') wch = cast(wchar)(wch-'o'+16);
        else if (wch >= 'y' && wch <= '~') wch = cast(wchar)(wch-'y'+26);
        else terminus = false;
      } else {
        enum terminus = false;
      }
      if (!terminus) {
        // other
        switch (wch) {
          //case '`': wch = 0x0001; break; // black diamond (0x25c6)
          //case 'a': wch = 0x0002; break; // medium shade (0x2592)
          // lines
          case 'j': wch = 0x2518; break;
          case 'k': wch = 0x2510; break;
          case 'l': wch = 0x250c; break;
          case 'm': wch = 0x2514; break;
          case 'n': wch = 0x253c; break;
          //case 'o': wch = 0x25; break;
          //case 'p': wch = 0x25; break;
          case 'q': wch = 0x2500; break;
          //case 'r': wch = 0x25; break;
          //case 's': wch = 0x25; break;
          case 't': wch = 0x251c; break;
          case 'u': wch = 0x2524; break;
          case 'v': wch = 0x2534; break;
          case 'w': wch = 0x252c; break;
          case 'x': wch = 0x2502; break;
          //case 'y': wch = 0x25; break;
          //case 'z': wch = 0x25; break;
          default: if (wch >= '`') wch = ' '; break;
        }
      }
    }
    // wch is a good char here
    // need wrapping?
    if (mCurX >= mWidth) {
      // send "wrap line" event
      //onWrapEvent(mCurY);
      if (mCurY >= 0 && mCurY < mHeight) mGBuf.ptr[mCurY*mWidth+mWidth-1].mAttr.autoWrap = true; // no autowrap
      // do newline/scroll
      doNewline!"cr"();
    }
    // are we in insert mode?
    if ((mMode&Mode.Insert) && mCurX < mWidth-1) {
      // send "insert char" event
      doInsertChars(mCurX, 1);
    }
    // put char and move cursor
    auto gl = Glyph(filterWC(wch), mCurAttr);
    if (mCurX >= 0 && mCurY >= 0 && mCurX < mWidth && mCurY < mHeight) {
      auto gp = mGBuf.ptr+(mCurY*mWidth+mCurX);
      if (*gp != gl) {
        if (!(*gp).dirty) ++mDirtyCount;
        gl.dirty = true;
        *gp = gl;
      }
    }
    ++mCurX;
  }

  final void putstr (const(char)[] str...) nothrow {
    foreach (immutable ch; str) putc(ch);
  }

  final void putc (char ch) nothrow {
    if (mIsUTF8) {
      //import ditty.utf8 : isValidUtf8Start, isValidUtf8Cont, utf8Decode;
      // is new utf-8 sequence?
      //{ import iv.writer; writefln!"ch=0x%02x (%s)"(cast(ubyte)ch, mCBUsed); }
      //{ import iv.writer; writefln!" isValidUtf8Start=%s"(isValidUtf8Start(ch)); }
      if (ch < 0x80 || isValidUtf8Start(ch)) {
        if (mCBUsed > 0) {
          putdc('?');
          mCBUsed = 0;
        }
      }
      if (mCBUsed == 0) {
        // first utf char?
        if (!isUtf8Start(ch)) {
          putdc(ch);
          return;
        }
        // valid start
        mCharBuf[mCBUsed++] = ch;
      } else {
        // non-first utf char
        if (!isUtf8Cont(ch)) {
          // utf-8 sequence is broken
          // this can't be valid utf-8 start
          putdc('?');
          mCBUsed = 0;
          return;
        }
        // valid utf-8 sequence
        mCharBuf[mCBUsed++] = ch;
      }
      //{ import iv.writer; writefln!"(%s) utf8IsFull=%s"(mCBUsed, utf8IsFull(mCharBuf[0..mCBUsed])); }
      Utf8DecoderFast dc;
      bool ok = false;
      foreach (char c; mCharBuf[0..mCBUsed]) {
        if (dc.decodeSafe(c)) {
          putdc(dc.codepoint);
          mCBUsed = 0;
          ok = true;
          break;
        }
      }
      if (!ok && mCBUsed == 4) {
        putdc('?');
        mCBUsed = 0;
      }
    } else {
      //import ditty.utf8 : koi2uni;
      // koi8
      putdc(koi2uni(ch));
    }
  }

  final void resetOnResize () nothrow @trusted @nogc {
    mEsc = Esc.None;
    mTop = 0;
    mBot = mHeight-1;
    if (mMode&Mode.Reversed) {
      mMode &= ~Mode.Reversed;
      if (onReverseEvent !is null) onReverseEvent(this);
    }
    mCurX = 0;
    mCurY = mHeight-1;
    if (mCurSaved.y >= mHeight) mCurSaved.y = mHeight-1;
    mCurSaved.top = 0;
    mCurSaved.bot = mHeight-1;
    setFullDirty();
    sendTTYResizeSignal();
  }

  final void reset () nothrow @trusted @nogc {
    mEsc = Esc.None;
    mTop = 0;
    mBot = mHeight-1;
    if (mMode&Mode.Reversed) {
      mMode &= ~Mode.Reversed;
      if (onReverseEvent !is null) onReverseEvent(this);
    }
    mMode = Mode.DoWrap|Mode.Gfx1; // gfx1 is line drawing
    mMouseMode = MouseMode.XTerm;
    mCharset = Mode.Gfx0;
    mCurAttr = Attr.init;
    mCurVis = true;
    mCurX = mCurY = 0;
    saveTo(mCurSaved);
    sendTTYResizeSignal();
  }

  void sendTTYResizeSignal () nothrow @trusted @nogc {
  }
}
