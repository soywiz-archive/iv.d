/* coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
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
module iv.vt100.scrbuf;
private:

import iv.alice;
import iv.strex;
import iv.utfutil;
import iv.x11;


// ////////////////////////////////////////////////////////////////////////// //
public align(1) struct X11ModState {
align(1):
public:
  uint modstate;

public pure nothrow @safe @nogc:
  this (uint astate) {
    modstate = astate&(Mod1Mask|Mod4Mask|ControlMask|ShiftMask);
  }

  @property bool meta () const { pragma(inline, true); return ((modstate&Mod1Mask) != 0); }
  @property bool hyper () const { pragma(inline, true); return ((modstate&Mod4Mask) != 0); }
  @property bool ctrl () const { pragma(inline, true); return ((modstate&ControlMask) != 0); }
  @property bool shift () const { pragma(inline, true); return ((modstate&ShiftMask) != 0); }

  @property void meta (bool v) { pragma(inline, true); if (v) modstate |= Mod1Mask; else modstate &= ~cast(uint)Mod1Mask; }
  @property void hyper (bool v) { pragma(inline, true); if (v) modstate |= Mod4Mask; else modstate &= ~cast(uint)Mod4Mask; }
  @property void ctrl (bool v) { pragma(inline, true); if (v) modstate |= ControlMask; else modstate &= ~cast(uint)ControlMask; }
  @property void shift (bool v) { pragma(inline, true); if (v) modstate |= ShiftMask; else modstate &= ~cast(uint)ShiftMask; }

  bool opEquals (const(char)[] s) const {
    uint mask = 0;
    foreach (char ch; s) {
      //if (ch >= 'a' && ch <= 'z') ch -= 32; // poor man's `toupper()`
      if (ch < ' ') continue;
      switch (ch) {
        case 'C': case 'c': mask |= ControlMask; break;
        case 'S': case 's': mask |= ShiftMask; break;
        case 'M': case 'm': mask |= Mod1Mask; break;
        case 'H': case 'h': mask |= Mod4Mask; break;
        default: return false;
      }
    }
    return (modstate == mask);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
public enum MinBufferWidth = 80;
public enum MinBufferHeight = 24;
public enum MaxBufferWidth = 8192;
public enum MaxBufferHeight = 8192;


// ////////////////////////////////////////////////////////////////////// //
public align(1) struct Attr {
align(1):
  enum : uint {
    DefaultBG = 0x01U,
    DefaultFG = 0x02U,
    Underline = 0x04U,
    Bold      = 0x08U,
    Blink     = 0x10U,
    Reversed  = 0x20U,
    Dirty     = 0x40U, // we need this in alot of other modules, so let it be here too
    AutoWrap  = 0x80U, // has meaning only for last glyph in line; means "this line was autowrapped"
  }
  enum BGShift = 8;
  enum FlagsShift = 16;
  uint attr = (DefaultBG|DefaultFG|Dirty)<<FlagsShift; // by bytes: bg, fg, flags, dummy

  enum ColorDefault = -1;
  enum ColorBold = 256;
  enum ColorUnderline = 257;
  enum ColorBoldUnderline = 258;
  enum ColorUnderlineBold = ColorBoldUnderline;

pure nothrow @safe @nogc:
  //this (ubyte afg, ubyte abg) { pragma(inline, true); attr = (abg<<BGShift)|afg|((DefaultBG|DefaultFG)<<FlagsShift); }
  this (ubyte afg, ubyte abg) { pragma(inline, true); attr = (abg<<BGShift)|afg; }
  this (ubyte afg, ubyte abg, ushort aflags) { pragma(inline, true); attr = (abg<<BGShift)|afg|(aflags<<FlagsShift); }

  @property ubyte fg () const { pragma(inline, true); return (attr&0xff); }
  @property ubyte bg () const { pragma(inline, true); return ((attr>>BGShift)&0xff); }
  @property ushort flags () const { pragma(inline, true); return ((attr>>FlagsShift)&0xffff); }

  @property void fg (ubyte v) { pragma(inline, true); attr = (attr&~0xffU)|v; }
  @property void bg (ubyte v) { pragma(inline, true); attr = (attr&~0xff00U)|(v<<BGShift); }
  @property void flags (ushort v) { pragma(inline, true); attr = (attr&~0xffff0000U)|(v<<FlagsShift); }

  private static template GenSG(string pname) {
    private static template up1(string s) { enum up1 = ""~cast(char)(s[0]-32)~s[1..$]; }
    enum GenSG =
      "@property bool "~pname~" (bool v) {
        /*pragma(inline, true);*/
        if (v) attr |= "~up1!pname~"<<FlagsShift; else attr &= ~(cast(uint)("~up1!pname~"<<FlagsShift));
        return v;
      }
      @property bool "~pname~" () const pure { pragma(inline, true); return ((attr&("~up1!pname~"<<FlagsShift)) != 0); }";
  }

  mixin(GenSG!"defaultBG");
  mixin(GenSG!"defaultFG");
  mixin(GenSG!"underline");
  mixin(GenSG!"bold");
  mixin(GenSG!"blink");
  mixin(GenSG!"reversed");
  mixin(GenSG!"dirty");
  mixin(GenSG!"autoWrap");

  // see ColorXXX special constants
  @property int realFG () const {
    pragma(inline, true);
    return
      (attr&(Reversed<<FlagsShift) ?
        // reversed: get background color
        (attr&(DefaultBG<<FlagsShift) ? ColorDefault : (attr>>BGShift)&0xff) :
        // normal: get foreground color
        (attr&(DefaultFG<<FlagsShift) ?
          (attr&((Underline|Bold)<<FlagsShift) ? ColorBoldUnderline :
           attr&(Underline<<FlagsShift) ? ColorUnderline :
           attr&(Bold<<FlagsShift) ? ColorBold :
           ColorDefault) : attr&0xff)
      );
  }

  // see ColorXXX special constants
  @property int realBG () const {
    pragma(inline, true);
    return
      (attr&(Reversed<<FlagsShift) ?
        // reversed: get foreground color
        (attr&(DefaultFG<<FlagsShift) ?
          (attr&((Underline|Bold)<<FlagsShift) ? ColorBoldUnderline :
           attr&(Underline<<FlagsShift) ? ColorUnderline :
           attr&(Bold<<FlagsShift) ? ColorBold :
           ColorDefault) : attr&0xff) :
        // normal: get background color
        (attr&(DefaultBG<<FlagsShift) ? ColorDefault : (attr>>BGShift)&0xff)
      );
  }

  bool opEquals() (in Attr a) const {
    pragma(inline, true);
    return ((flags&(Underline|Bold|Reversed)) == (a.flags&(Underline|Bold|Reversed)) && a.realBG == realBG && a.realFG == realFG);
  }
}
static assert(Attr.sizeof == 4);
static assert(Attr(0, 5, Attr.DefaultBG|Attr.DefaultFG) == Attr(5, 0, Attr.DefaultBG|Attr.DefaultFG));


// ////////////////////////////////////////////////////////////////////// //
// only 0x0000..0xffff chars are allowed
public align(1) struct Glyph {
align(1):
  wchar mChar = ' ';
  Attr mAttr;

nothrow @safe @nogc:
  @property bool dirty () const pure { pragma(inline, true); return mAttr.dirty; }
  @property void dirty (bool v) pure { pragma(inline, true); mAttr.dirty = v; }

  @property wchar ch () const pure { pragma(inline, true); return mChar; }
  @property void ch (wchar v) pure { pragma(inline, true); if (mChar != v) { mChar = v; mAttr.dirty = true; } }
  //@property void ch (char v) pure { pragma(inline, true); if (mChar != koi2uni(v)) { mChar = koi2uni(v); mAttr.dirty = true; } }

  @property Attr attr () const pure { pragma(inline, true); return mAttr; }
  @property void attr (Attr v) pure { pragma(inline, true); if (v.dirty || v != mAttr) { v.dirty = true; mAttr = v; } }

  void set (wchar ach, Attr aa) pure {
    pragma(inline, true);
    if (mChar != ach || aa.dirty || aa != mAttr) {
      aa.dirty = true;
      mChar = ach;
      mAttr = aa;
    }
  }

  bool opEquals() (auto ref const Glyph g) const pure {
    pragma(inline, true);
    // for spaces only background matters
    return (mChar == g.mChar && mAttr.realBG == g.mAttr.realBG && (mChar == ' ' || mChar == 0 || mAttr.realFG == g.mAttr.realFG));
  }
}
static assert(Glyph(' ', Attr(5, 0, Attr.DefaultBG|Attr.DefaultFG)) == Glyph(' ', Attr(0, 5, Attr.DefaultBG|Attr.DefaultFG)));
static assert(Glyph(' ', Attr(5, 0, 0)) != Glyph(' ', Attr(5, 1, 0)));
static assert(Glyph('!', Attr(5, 0, 0)) != Glyph(' ', Attr(5, 0, 0)));
static assert(Glyph('!', Attr(5, 0, 0)) != Glyph(' ', Attr(5, 1, 0)));


// ////////////////////////////////////////////////////////////////////////// //
public class ScreenBuffer {
public:
  static T min(T, T0, T1) (T0 a, T1 b) { pragma(inline, true); return cast(T)(a < b ? a : b); }
  static T max(T, T0, T1) (T0 a, T1 b) { pragma(inline, true); return cast(T)(a > b ? a : b); }
  static T between(T, T0, T1, T2) (T0 lo, T1 hi, T2 val) { pragma(inline, true); return cast(T)(val < lo ? lo : val > hi ? hi : val); }

  static T min(T, T1) (T a, T1 b) { pragma(inline, true); return cast(T)(a < b ? a : b); }
  static T max(T, T1) (T a, T1 b) { pragma(inline, true); return cast(T)(a > b ? a : b); }

  static wchar filterDC (dchar ch) pure nothrow @safe @nogc {
    pragma(inline, true);
    return
      ((ch >= 0x02B0 && ch <= 0x036F) ||
       (ch >= 0x20D0 && ch <= 0x20FF) ||
       (ch >= 0xD800 && ch <= 0xDBFF) ||
       (ch >= 0xDC00 && ch <= 0xF8FF) ||
       (ch >= 0xFE20 && ch <= 0xFE2F) ||
       (ch >= 0xFEFF && ch <= 0xFFEF) ||
       (ch >= 0xFFF0) ? '?' : cast(wchar)ch);
  }

public:
  enum {
    CornerLU,
    CornerRU,
    CornerLD,
    CornerRD,
    HLine,
    VLine,
  }

  enum FrameType {
    Single,
    Double,
  }

  static immutable wchar[6][2] FrameChars = [
    "\u250c\u2510\u2514\u2518\u2500\u2502"w,
    "\u2554\u2557\u255a\u255d\u2550\u2551"w,
  ];

protected:
  Glyph[] mGBuf;
  int mWidth, mHeight;
  int mCurX = 0; // can be == mWidth, that means "do wrap on next output"
  int mCurY = 0;
  bool mCurVis = true;
  int mDirtyCount = 0;
  Attr mCurAttr;

  public final inout(Glyph)[] scrbuf () inout pure nothrow @safe @nogc { pragma(inline, true); return mGBuf; }

public:
  // called after scrolling up
  void delegate (ScreenBuffer self, int y0, int y1, int count, bool wasDirty) nothrow onScrollUp;
  // called after scrolling down
  void delegate (ScreenBuffer self, int y0, int y1, int count, bool wasDirty) nothrow onScrollDown;
  // ring a bell
  void delegate (ScreenBuffer self) nothrow @safe @nogc onBell;
  // new title was set; we don't check if it's the same as old title
  void delegate (ScreenBuffer self, const(char)[] title) nothrow onNewTitleEvent;
  // inverse mode changed; it should be in effect immediately
  void delegate (ScreenBuffer self) nothrow @safe @nogc onReverseEvent;
  // this will be called when screen buffer is scrolled, and owner should save history line
  // check `autoWrap` property on last line glyph to see if this line is autowrapped
  // never called by `ScreenBuffer`, but can be called by VT-100 Emulator, for example
  void delegate (const(Glyph)[] aline) nothrow onAppendHistory;

public:
  static final doKeyTrans (ref KeySym ksym) nothrow @safe @nogc {
    switch (ksym) {
      case XK_KP_Home: ksym = XK_Home; break;
      case XK_KP_Left: ksym = XK_Left; break;
      case XK_KP_Up: ksym = XK_Up; break;
      case XK_KP_Right: ksym = XK_Right; break;
      case XK_KP_Down: ksym = XK_Down; break;
      case XK_KP_Prior: ksym = XK_Prior; break;
      case XK_KP_Next: ksym = XK_Next; break;
      case XK_KP_End: ksym = XK_End; break;
      case XK_KP_Begin: ksym = XK_Begin; break;
      case XK_KP_Insert: ksym = XK_Insert; break;
      case XK_KP_Delete: ksym = XK_Delete; break;
      case XK_KP_Enter: ksym = XK_Return; break;
      case XK_ISO_Left_Tab: ksym = XK_Tab; break; // x11 is fucked
      default: break;
    }
  }

public:
  this (int aw, int ah) nothrow @safe {
    if (aw < 1 || ah < 1 || aw > MaxBufferWidth || ah > MaxBufferHeight) assert(0, "invalid screen buffer size");
    mGBuf.length = aw*ah;
    mWidth = aw;
    mHeight = ah;
    foreach (ref Glyph g; mGBuf) g.dirty = true;
    mDirtyCount = aw*ah;
  }

  void intrClear () nothrow @trusted {
    delete mGBuf;
    mWidth = mHeight = 0;
    mCurX = mCurY = 0;
    mCurVis = true;
    mDirtyCount = 0;
  }

  final @property bool isDirty () const pure nothrow @safe @nogc { pragma(inline, true); return (mDirtyCount != 0); }

  final @property Attr curAttr () const pure nothrow @safe @nogc { pragma(inline, true); return mCurAttr; }
  final @property void curAttr (Attr v) pure nothrow @safe @nogc { pragma(inline, true); mCurAttr = v; }

  final @property int width () const pure nothrow @safe @nogc { pragma(inline, true); return mWidth; }
  final @property int height () const pure nothrow @safe @nogc { pragma(inline, true); return mHeight; }

  final @property int curX () const pure nothrow @safe @nogc { /*pragma(inline, true);*/ return (mCurX == mWidth ? mWidth-1 : mCurX); }
  final @property int curY () const pure nothrow @safe @nogc { /*pragma(inline, true);*/ return mCurY; }
  final @property bool curVisible () const pure nothrow @safe @nogc { pragma(inline, true); return mCurVis; }

  final void gotoXYSetVis (int ax, int ay, bool avis) pure nothrow @trusted @nogc {
    if (ax != mCurX || ay != mCurY || avis != mCurVis) {
      // mark old and new cursor positions as dirty
      if (mCurVis && mCurX >= 0 && mCurY >= 0 && mCurX < mWidth && mCurY < mHeight && !mGBuf.ptr[mCurY*mWidth+mCurX].dirty) {
        // old cursor is visible and not dirty
        mGBuf.ptr[mCurY*mWidth+mCurX].dirty = true;
        ++mDirtyCount;
      }
      if (avis && ax >= 0 && ay >= 0 && ax < mWidth && ay < mHeight && !mGBuf.ptr[ay*mWidth+ax].dirty) {
        // new cursor is visible and not dirty
        mGBuf.ptr[ay*mWidth+ax].dirty = true;
        ++mDirtyCount;
      }
      mCurX = ax;
      mCurY = ay;
      mCurVis = avis;
    }
  }

  final void gotoXY (int ax, int ay) pure nothrow @trusted @nogc { pragma(inline, true); gotoXYSetVis(ax, ay, mCurVis); }

  final @property void curX (int v) pure nothrow @trusted @nogc { pragma(inline, true); gotoXYSetVis(v, mCurY, mCurVis); }
  final @property void curY (int v) pure nothrow @trusted @nogc { pragma(inline, true); gotoXYSetVis(mCurX, v, mCurVis); }
  final @property void curVisible (bool v) pure nothrow @trusted @nogc { pragma(inline, true); gotoXYSetVis(mCurX, mCurY, v); }

  //TODO: send cutted lines to history buffer
  protected final void resizeBuf (ref Glyph[] buf, int aw, int ah) nothrow @trusted {
    if (aw == mWidth) {
      // only height
      buf[$-1].mAttr.autoWrap = false;
      buf.length = aw*ah;
      buf.assumeSafeAppend;
      if (ah > mHeight) foreach (ref Glyph g; buf[ah*mWidth..$]) g.dirty = true;
    } else {
      // collect lines
      Glyph[][] lines;
      scope(exit) { foreach (ref arr; lines) delete arr; delete lines; }
      lines.reserve(mHeight);
      int pos = 0;
      while (pos < buf.length) {
        // find line end (rough)
        int epos = pos+mWidth;
        assert(epos <= buf.length);
        while (epos < buf.length && buf[epos-1].attr.autoWrap) epos += mWidth;
        // new line
        auto line = new Glyph[](epos-pos);
        line[] = buf[pos..epos];
        // remove spaces, 'cause why not
        while (line.length && line[$-1].ch <= ' ') line = line[0..$-1];
        lines ~= line;
        pos = epos;
      }
      // remove empty lines, 'cause why should we keep 'em?
      while (lines.length && lines[$-1].length == 0) lines = lines[0..$-1];
      // redistribute lines, starting from the last one
      auto newbuf = new Glyph[](aw*ah);
      if (lines.length) {
        int srcline = cast(int)lines.length-1;
        int desty = ah-2;
        while (srcline >= 0 && desty >= 0) {
          auto ln = lines[srcline--];
          int lc = cast(int)(ln.length/aw+(ln.length%aw ? 1 : 0));
          //{ import core.stdc.stdio; stderr.fprintf("srcline=%d; lc=%d\n", srcline+1, lc); }
          if (lc > 0) {
            foreach (immutable dy; desty-lc+1..desty+1) {
              int xlen = cast(int)ln.length;
              if (xlen > aw) xlen = aw;
              if (dy >= 0 && dy < ah) {
                newbuf[dy*aw..dy*aw+xlen] = ln[0..xlen];
                bool awrap = (xlen == aw && xlen+1 < ln.length);
                newbuf[(dy+1)*aw-1].mAttr.autoWrap = (xlen+1 < ln.length);
              }
              ln = ln[xlen..$];
            }
            desty -= lc;
          } else {
            --desty;
          }
        }
      }
      delete buf;
      buf = newbuf;
    }
  }

  protected final void resizeBufSimple (ref Glyph[] buf, int aw, int ah) nothrow @trusted {
    auto newbuf = new Glyph[](aw*ah);
    foreach (immutable y; 0..min(ah, mHeight)) {
      foreach (immutable x; 0..min(aw, mWidth)) {
        newbuf[y*aw+x] = buf[y*mWidth+x];
      }
    }
    delete buf;
    buf = newbuf;
  }

  void resize (int aw, int ah) nothrow @trusted {
    if (aw < 1 || ah < 1 || aw > MaxBufferWidth || ah > MaxBufferHeight) assert(0, "invalid screen buffer size");
    if (aw == mWidth && ah == mHeight) return;
    resizeBuf(mGBuf, aw, ah);
    mWidth = aw;
    mHeight = ah;
  }

  final Glyph opIndex (int x, int y) const nothrow @trusted @nogc {
    pragma(inline, true);
    return (x >= 0 && y >= 0 && x < mWidth && y < mHeight ? mGBuf.ptr[y*mWidth+x] : Glyph.init);
  }

  final void opIndexAssign (Glyph g, int x, int y) nothrow @trusted @nogc {
    if (x >= 0 && y >= 0 && x < mWidth && y < mHeight) {
      if (g != mGBuf.ptr[y*mWidth+x]) {
        if (!mGBuf.ptr[y*mWidth+x].dirty) ++mDirtyCount;
        g.dirty = true;
        mGBuf.ptr[y*mWidth+x] = g;
      }
    }
  }

  final bool isDirtyAt (int x, int y) const nothrow @trusted @nogc {
    pragma(inline, true);
    return (x >= 0 && y >= 0 && x < mWidth && y < mHeight ? mGBuf.ptr[y*mWidth+x].dirty : false);
  }

  final void setDirtyAt (int x, int y, bool v) nothrow @trusted @nogc {
    pragma(inline, true);
    if (x >= 0 && y >= 0 && x < mWidth && y < mHeight && mGBuf.ptr[y*mWidth+x].dirty != v) {
      mDirtyCount += (v ? 1 : -1);
      mGBuf.ptr[y*mWidth+x].dirty = v;
    }
  }

  final bool isDirtyLine (int y) const nothrow @trusted @nogc {
    if (y >= 0 && y < mHeight) {
      foreach (const ref Glyph g; mGBuf.ptr[y*mWidth..(y+1)*mWidth]) if (g.dirty) return true;
    }
    return false;
  }

  final void resetDirtyLine (int y) nothrow @trusted @nogc {
    if (y >= 0 && y < mHeight) {
      foreach (ref Glyph g; mGBuf.ptr[y*mWidth..(y+1)*mWidth]) {
        if (g.dirty) --mDirtyCount;
        g.dirty = false;
      }
    }
  }

  final void setDirtyLine (int y) nothrow @trusted @nogc {
    if (y >= 0 && y < mHeight) {
      foreach (ref Glyph g; mGBuf.ptr[y*mWidth..(y+1)*mWidth]) {
        if (!g.dirty) ++mDirtyCount;
        g.dirty = true;
      }
    }
  }

  final void setFullDirty () nothrow @trusted @nogc {
    foreach (ref Glyph g; mGBuf) g.dirty = true;
    mDirtyCount = mWidth*mHeight;
  }

  final void resetFullDirty () nothrow @trusted @nogc {
    foreach (ref Glyph g; mGBuf) g.dirty = false;
    mDirtyCount = 0;
  }

  void scrollUp () nothrow {
    bool wasDirty = (mDirtyCount != 0);
    int mh = mHeight;
    auto gbp = mGBuf.ptr;
    // copy chars
    foreach (immutable pos; mh..mGBuf.length) {
      if (gbp[pos-mh] != gbp[pos]) {
        gbp[pos-mh] = gbp[pos];
        gbp[pos-mh].dirty = true;
      }
    }
    // clear last line
    auto defg = Glyph(' ', mCurAttr);
    foreach (ref Glyph g; mGBuf[$-mWidth..$]) {
      if (g != defg) { g = defg; g.dirty = true; }
    }
    // recalculate dirty counter
    mDirtyCount = 0;
    foreach (const ref Glyph g; mGBuf) if (g.dirty) ++mDirtyCount;
    if (onScrollUp !is null) onScrollUp(this, 0, mh-1, 1, wasDirty);
  }

  // at current cursor position, with current attrs; interprets some control codes
  void writeStr (const(char)[] s...) {
    if (s.length == 0) return;
    Utf8DecoderFast dc;
    foreach (immutable char ch; s) {
      if (!dc.decodeSafe(ch)) continue;
      wchar wc = (dc.codepoint <= wchar.max ? cast(wchar)dc.codepoint : '?');
      // cr?
      if (wc == 13) {
        if (mCurY >= 0 && mCurY < mHeight) mGBuf.ptr[mCurY*mWidth+mWidth-1].mAttr.autoWrap = false; // no autowrap
        mCurX = 0;
        continue;
      }
      // lf?
      if (wc == 10) {
        if (mCurY >= 0 && mCurY < mHeight) mGBuf.ptr[mCurY*mWidth+mWidth-1].mAttr.autoWrap = false; // no autowrap
        mCurX = 0;
        ++mCurY;
        if (mCurY >= mHeight) { mCurY = mHeight-1; scrollUp(); }
        continue;
      }
      // bs?
      if (wc == 8) {
        if (mCurX > 0) --mCurX;
        continue;
      }
      // beep?
      if (wc == 8) continue;
      // tab and other chars
      int count = 1; // for tab
      // tab?
      if (wc == 9) {
        if (mCurX < 0) {
          count = mCurX%8;
          if (count < 0) count = -count; else count = 8;
        } else if (mCurX >= mWidth) {
          count = 8;
        } else {
          count = 8-(mCurX%8);
        }
        wc = ' '; // put spaces instead of tabs
      }
      if (wc == 0) wc = ' '; //HACK
      // put chars
      foreach (immutable _; 0..count) {
        // other chars
        if (mCurX >= mWidth && mCurY >= 0 && mCurY < mHeight) mGBuf.ptr[mCurY*mWidth+mWidth-1].mAttr.autoWrap = true; // autowrap
        // scroll?
        if (mCurX >= mWidth) {
          mCurX = 0;
          ++mCurY;
          if (mCurY >= mHeight) { mCurY = mHeight-1; scrollUp(); }
        }
        // put char
        if (mCurX >= 0 && mCurX < mWidth && mCurY >= 0 && mCurY < mHeight) {
          auto ng = Glyph(wc, mCurAttr);
          ng.dirty = true;
          if (mGBuf.ptr[mCurY*mWidth+mCurX] != ng) {
            if (!mGBuf.ptr[mCurY*mWidth+mCurX].dirty) ++mDirtyCount;
            mGBuf.ptr[mCurY*mWidth+mCurX] = ng;
          }
        }
        // move to next position
        ++mCurX;
      }
    }
  }

  void writeCharsAt (int x, int y, int count, dchar dch, Attr a) nothrow @trusted @nogc {
    if (y < 0 || count < 1 || y >= mHeight || x >= mWidth || dch >= dchar.max) return;
    if (x < 0) {
      if (x == int.min) return;
      count += x;
      if (count < 1) return;
      x = 0;
    }
    wchar wc = (dch <= wchar.max ? cast(wchar)dch : '?');
    auto ng = Glyph(wc, a);
    ng.dirty = true;
    Glyph* g = mGBuf.ptr+y*mWidth+x;
    foreach (immutable _; 0..count) {
      if (*g != ng) {
        if (!g.dirty) ++mDirtyCount;
        *g = ng;
      }
      ++g;
      if (++x >= mWidth) return;
    }
  }

  void writeStrAt (int x, int y, const(char)[] s, Attr a) nothrow @trusted @nogc {
    if (y < 0 || y >= mHeight || x >= mWidth || s.length == 0) return;
    if (x < 0) {
      if (x == int.min) return;
      if (s.length <= -x) return;
    }
    Utf8DecoderFast dc;
    Glyph* g = mGBuf.ptr+y*mWidth+(x > 0 ? x : 0);
    foreach (immutable char ch; s) {
      if (!dc.decodeSafe(ch)) continue;
      wchar wc = filterDC(dc.codepoint);
      if (x >= 0) {
        auto ng = Glyph(wc, a);
        ng.dirty = true;
        if (*g != ng) {
          if (!g.dirty) ++mDirtyCount;
          *g = ng;
        }
        ++g;
      }
      if (++x >= mWidth) return;
    }
  }

  void writeStrAt (int x, int y, const(wchar)[] s, Attr a) nothrow @trusted @nogc {
    if (y < 0 || y >= mHeight || x >= mWidth || s.length == 0) return;
    if (x < 0) {
      if (x == int.min) return;
      x = -x;
      if (s.length <= x) return;
      s = s[x..$];
      x = 0;
    }
    Glyph* g = mGBuf.ptr+y*mWidth+x;
    foreach (immutable wchar wc; s) {
      auto ng = Glyph(wc, a);
      ng.dirty = true;
      if (*g != ng) {
        if (!g.dirty) ++mDirtyCount;
        *g = ng;
      }
      ++g;
      if (++x >= mWidth) return;
    }
  }

  void writeStrAt (int x, int y, const(dchar)[] s, Attr a) nothrow @trusted @nogc {
    if (y < 0 || y >= mHeight || x >= mWidth || s.length == 0) return;
    if (x < 0) {
      if (x == int.min) return;
      x = -x;
      if (s.length <= x) return;
      s = s[x..$];
      x = 0;
    }
    Glyph* g = mGBuf.ptr+y*mWidth+x;
    foreach (immutable dchar dc; s) {
      auto ng = Glyph(filterDC(dc), a);
      ng.dirty = true;
      if (*g != ng) {
        if (!g.dirty) ++mDirtyCount;
        *g = ng;
      }
      ++g;
      if (++x >= mWidth) return;
    }
  }

  void fillRect (int x, int y, int w, int h, Attr a) nothrow @trusted @nogc {
    if (w < 1 || h < 1 || x >= mWidth || y >= mHeight) return;
    foreach (immutable sy; y..y+h) writeCharsAt(x, sy, w, ' ', a);
  }

  void drawFrame (int x, int y, int w, int h, Attr a, FrameType ft=FrameType.Single) nothrow @trusted @nogc {
    if (w < 1 || h < 1) return;
    if (h == 1) {
      // horizontal line
      foreach (immutable sx; x..x+w) writeCharsAt(sx, y, 1, FrameChars[ft][HLine], a);
    } else if (w == 1) {
      // vertical line
      foreach (immutable sy; y..y+h) writeCharsAt(x, sy, 1, FrameChars[ft][VLine], a);
    } else {
      // horizontal lines
      writeCharsAt(x+1, y, w-2, FrameChars[ft][HLine], a);
      writeCharsAt(x+1, y+h-1, w-2, FrameChars[ft][HLine], a);
      // vertical lines
      foreach (immutable sy; y+1..y+h-1) {
        writeCharsAt(x, sy, 1, FrameChars[ft][VLine], a);
        writeCharsAt(x+w-1, sy, 1, FrameChars[ft][VLine], a);
      }
      // corners
      writeCharsAt(x, y, 1, FrameChars[ft][CornerLU], a);
      writeCharsAt(x+w-1, y, 1, FrameChars[ft][CornerRU], a);
      writeCharsAt(x, y+h-1, 1, FrameChars[ft][CornerLD], a);
      writeCharsAt(x+w-1, y+h-1, 1, FrameChars[ft][CornerRD], a);
    }
  }

  // ////////////////////////////////////////////////////////////////////// //
  // for mouse reports
  enum MouseMods {
    Shift = 0x01,
    Ctrl  = 0x02,
    Meta  = 0x04,
    Hyper = 0x08,
  }

  enum MouseEvent {
    Motion,
    Up,
    Down,
  }

  // button: 1=left, 2=middle, 3=right
  void doMouseReport (uint x, uint y, MouseEvent event, ubyte button, uint mods) {
  }

  // `true`: eaten
  bool keypressEvent (dchar dch, KeySym ksym, X11ModState modstate) {
    return false;
  }

  // ////////////////////////////////////////////////////////////////////// //
  void onBlurFocus (bool focused) nothrow {}

  // should mark dirty areas if necessary
  void resetSelection () nothrow {}

  // should mark dirty areas if necessary
  void doneSelection () nothrow {}

  // should mark dirty areas if necessary
  // this called by mouse handler, with cell coords
  // when mouse button released, `doneSelection()` will be called
  void selectionChanged (int x, int y) nothrow {}

  bool isInSelection (int x, int y) nothrow @trusted @nogc { return false; }

  bool lineHasSelection (int y) nothrow @trusted @nogc { return false; }

  string getSelectionText () nothrow { return null; }

  // ////////////////////////////////////////////////////////////////////// //
  // resets dirty flag
  final void blitTo (ScreenBuffer dest, int x0, int y0) nothrow @trusted @nogc {
    if (dest is null) return;
    Glyph* g = mGBuf.ptr;
    foreach (immutable y; 0..mHeight) {
      foreach (immutable x; 0..mWidth) {
        dest[x+x0, y+y0] = *g;
        g.dirty = false;
        ++g;
      }
    }
    mDirtyCount = 0;
  }
}
