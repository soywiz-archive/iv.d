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
//TODO:
//  group: events on add and remove widgets
module iv.vwidgets;

import iv.videolib;
import iv.rect;

/*
import core.stdc.stdlib : malloc, realloc, free;
import core.stdc.string : memcpy, memmove;
//import std.exception;
import std.conv;
import std.functional;
import std.stdio;
import std.string;
import std.variant;
*/


// ////////////////////////////////////////////////////////////////////////// //
/// generic VideoLib exception
class WidgetError : object.Exception {
  this (string msg, string file=__FILE__, usize line=__LINE__, Throwable next=null) @safe pure nothrow {
    super(msg, file, line, next);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
/// palettes (aka 'color schemes')
/// entries looks like: `window.button.text`
/// widgets will look in this order:
///   `active.widgetname.text`
///   `widgetname.text`
///   `text`
/// i.e.removing dots until color is found or no more dots left to remove
struct Palette {
  Color opIndex (string cname) const @trusted pure nothrow @nogc {
    while (cname.length != 0) {
      import std.string : indexOf;
      auto clr = (cname in colors);
      if (clr !is null) return *clr;
      //cname.munch("^."); // not nothrow
      usize pos = usize.max;
      foreach (usize idx, char ch; cname) if (ch == '.') { pos = idx+1; break; }
      if (pos >= cname.length) break;
      cname = cname[pos..$];
    }
    return Transparent;
  }

private:
  string name;
  Color[string] colors;
}


// ////////////////////////////////////////////////////////////////////////// //
enum {
  VK_UNKNOWN = SDLK_UNKNOWN,
  VK_RETURN = SDLK_RETURN,
  VK_ESCAPE = SDLK_ESCAPE,
  VK_BACKSPACE = SDLK_BACKSPACE,
  VK_TAB = SDLK_TAB,
  VK_SPACE = SDLK_SPACE,
  VK_EXCLAIM = SDLK_EXCLAIM,
  VK_QUOTEDBL = SDLK_QUOTEDBL,
  VK_HASH = SDLK_HASH,
  VK_PERCENT = SDLK_PERCENT,
  VK_DOLLAR = SDLK_DOLLAR,
  VK_AMPERSAND = SDLK_AMPERSAND,
  VK_QUOTE = SDLK_QUOTE,
  VK_LEFTPAREN = SDLK_LEFTPAREN,
  VK_RIGHTPAREN = SDLK_RIGHTPAREN,
  VK_ASTERISK = SDLK_ASTERISK,
  VK_PLUS = SDLK_PLUS,
  VK_COMMA = SDLK_COMMA,
  VK_MINUS = SDLK_MINUS,
  VK_PERIOD = SDLK_PERIOD,
  VK_SLASH = SDLK_SLASH,
  VK_COLON = SDLK_COLON,
  VK_SEMICOLON = SDLK_SEMICOLON,
  VK_LESS = SDLK_LESS,
  VK_EQUALS = SDLK_EQUALS,
  VK_GREATER = SDLK_GREATER,
  VK_QUESTION = SDLK_QUESTION,
  VK_AT = SDLK_AT,

  VK_LEFTBRACKET = SDLK_LEFTBRACKET,
  VK_BACKSLASH = SDLK_BACKSLASH,
  VK_RIGHTBRACKET = SDLK_RIGHTBRACKET,
  VK_CARET = SDLK_CARET,
  VK_UNDERSCORE = SDLK_UNDERSCORE,
  VK_BACKQUOTE = SDLK_BACKQUOTE,

  VK_0 = '0',
  VK_1 = '1',
  VK_2 = '2',
  VK_3 = '3',
  VK_4 = '4',
  VK_5 = '5',
  VK_6 = '6',
  VK_7 = '7',
  VK_8 = '8',
  VK_9 = '9',

  // SDL passes this as lower-case; fix in handler
  VK_A = 'A',
  VK_B = 'B',
  VK_C = 'C',
  VK_D = 'D',
  VK_E = 'E',
  VK_F = 'F',
  VK_G = 'G',
  VK_H = 'H',
  VK_I = 'I',
  VK_J = 'J',
  VK_K = 'K',
  VK_L = 'L',
  VK_M = 'M',
  VK_N = 'N',
  VK_O = 'O',
  VK_P = 'P',
  VK_Q = 'Q',
  VK_R = 'R',
  VK_S = 'S',
  VK_T = 'T',
  VK_U = 'U',
  VK_V = 'V',
  VK_W = 'W',
  VK_X = 'X',
  VK_Y = 'Y',
  VK_Z = 'Z',

  VK_CAPSLOCK = SDLK_CAPSLOCK,

  VK_F1 = SDLK_F1,
  VK_F2 = SDLK_F2,
  VK_F3 = SDLK_F3,
  VK_F4 = SDLK_F4,
  VK_F5 = SDLK_F5,
  VK_F6 = SDLK_F6,
  VK_F7 = SDLK_F7,
  VK_F8 = SDLK_F8,
  VK_F9 = SDLK_F9,
  VK_F10 = SDLK_F10,
  VK_F11 = SDLK_F11,
  VK_F12 = SDLK_F12,

  VK_PRINTSCREEN = SDLK_PRINTSCREEN,
  VK_SCROLLLOCK = SDLK_SCROLLLOCK,
  VK_PAUSE = SDLK_PAUSE,
  VK_INSERT = SDLK_INSERT,
  VK_HOME = SDLK_HOME,
  VK_PAGEUP = SDLK_PAGEUP,
  VK_DELETE = SDLK_DELETE,
  VK_END = SDLK_END,
  VK_PAGEDOWN = SDLK_PAGEDOWN,
  VK_RIGHT = SDLK_RIGHT,
  VK_LEFT = SDLK_LEFT,
  VK_DOWN = SDLK_DOWN,
  VK_UP = SDLK_UP,

  VK_NUMLOCKCLEAR = SDLK_NUMLOCKCLEAR,
  VK_KP_DIVIDE = SDLK_KP_DIVIDE,
  VK_KP_MULTIPLY = SDLK_KP_MULTIPLY,
  VK_KP_MINUS = SDLK_KP_MINUS,
  VK_KP_PLUS = SDLK_KP_PLUS,
  VK_KP_ENTER = SDLK_KP_ENTER,
  VK_KP_1 = SDLK_KP_1,
  VK_KP_2 = SDLK_KP_2,
  VK_KP_3 = SDLK_KP_3,
  VK_KP_4 = SDLK_KP_4,
  VK_KP_5 = SDLK_KP_5,
  VK_KP_6 = SDLK_KP_6,
  VK_KP_7 = SDLK_KP_7,
  VK_KP_8 = SDLK_KP_8,
  VK_KP_9 = SDLK_KP_9,
  VK_KP_0 = SDLK_KP_0,
  VK_KP_PERIOD = SDLK_KP_PERIOD,

  VK_LCTRL = SDLK_LCTRL,
  VK_LSHIFT = SDLK_LSHIFT,
  VK_LALT = SDLK_LALT,
  VK_LGUI = SDLK_LGUI,
  VK_RCTRL = SDLK_RCTRL,
  VK_RSHIFT = SDLK_RSHIFT,
  VK_RALT = SDLK_RALT,
  VK_RGUI = SDLK_RGUI,

  VK_MODE = SDLK_MODE,
}


enum {
  VMOD_NONE = KMOD_NONE,
  VMOD_LSHIFT = KMOD_LSHIFT,
  VMOD_RSHIFT = KMOD_RSHIFT,
  VMOD_LCTRL = KMOD_LCTRL,
  VMOD_RCTRL = KMOD_RCTRL,
  VMOD_LALT = KMOD_LALT,
  VMOD_RALT = KMOD_RALT,
  VMOD_LGUI = KMOD_LGUI,
  VMOD_RGUI = KMOD_RGUI,
  VMOD_NUM = KMOD_NUM,
  VMOD_CAPS = KMOD_CAPS,
  VMOD_MODE = KMOD_MODE,

  VMOD_CTRL = (VMOD_LCTRL|VMOD_RCTRL),
  VMOD_SHIFT = (VMOD_LSHIFT|VMOD_RSHIFT),
  VMOD_ALT = (VMOD_LALT|VMOD_RALT),
  VMOD_GUI = (VMOD_LGUI|VMOD_RGUI),
}


enum {
  VBUT_NONE = 0x00,
  VBUT_LEFT = 0x01,
  VBUT_RIGHT = 0x02,
  VBUT_MIDDLE = 0x04,
}


// ////////////////////////////////////////////////////////////////////////// //
struct WEvent {
  enum Type {
    Nothing,
    KeyDown,
    KeyUp,
    KeyChar,
    MouseDown,
    MouseUp,
    MouseDouble,
    MouseMotion,
    MouseWheel, // delta: -1, 1
    // ...
    User = 666,
  }

  Widget *dest; // destination widget or null
  Type type;
  uint mods; // VMOD_XXX bits
  union {
    // KeyDown, KeyUp
    uint keycode; // VK_XXX
    // KeyChar
    dchar ch;
    // MouseDown, MouseUp, MouseDouble, MouseMotion
    struct {
      int x, y; // mouse position
      ubyte bstate; // VB_XXX bits: current buttons state
      ubyte button; // VB_XXX: used button
      int delta; // for MouseWheel
    }
  }
  // userdata, various
  void* udataptr;
  ulong udata; // for casting
}


// ////////////////////////////////////////////////////////////////////////// //
class Widget {
public:
  alias WID = uint;
  alias EventCB = void delegate (Widget wg, in WEvent evt);

  enum Flags {
    Disabled = 0x01,
    Hidden = 0x02,
    NoFocus = 0x04,
    Active = 0x100,
    Dead = 0x8000
  }

protected:
  static uint genID () @trusted nothrow @nogc {
    import core.atomic : atomicOp;
    static shared WID lastUsedWidgetID = 0;
    uint res = atomicOp!"+="(lastUsedWidgetID, 1);
    return res;
  }

  immutable WID mID; // can't change, ever
  VLOverlay mOvl; // lazy creation
  Widget mOwner;
  Palette* mPal; // null: use owner palette
  Rect mArea;
  string mCaption;
  uint mFlags;
  EventCB mECB;
  bool mDirty;
  bool mHasDirtyChildren;
  Widget[WID] mChildren;
  Widget mPrev, mNext;

protected:
  final void callECB (in WEvent evt) @trusted {
    if ((mFlags&Flags.Dead) == 0) handleEvent(evt);
  }

public:
  this (int ax, int ay, int awdt, int ahgt, string acaption=null) @safe nothrow @nogc {
    if (awdt < 0) awdt = 0;
    if (ahgt < 0) ahgt = 0;
    mID = genID();
    mArea.x = ax;
    mArea.y = ay;
    mArea.width = awdt;
    mArea.height = ahgt;
    mCaption = acaption;
    mPal = null;
    mDirty = true;
  }

  ~this () @safe nothrow @nogc {
    mFlags |= Flags.Dead;
    mOwner = null;
  }

  void handleEvent (in WEvent evt) {
    if (mECB !is null) mECB(this, evt);
  }

  @property void caption (string acap) @trusted nothrow @nogc {
    if (acap != mCaption) {
      mCaption = acap;
      dirty = true;
    }
  }

 final { @safe { nothrow { @nogc {
  @property WID id () const pure { return mID; }

  /// return widget flags (see Flags enum)
  @property uint flags () const pure { return mFlags; }
  @property string caption () const pure { return mCaption; }

  /// get widget palette
  @property const(Palette*) pal () const {
    return (mPal is null ?
      (mOwner !is null ? mOwner.pal : WDesktop.defaultPalette) :
      mPal);
  }

  Color getColor (string name) const {
    auto p = pal;
    return (p !is null ? (*p)[name] : Transparent);
  }

  void dirtyChild (Widget wg) {
    if (wg !is null) {
      mHasDirtyChildren = true;
      if (mOwner !is null) mOwner.dirtyChild(this);
    }
  }

  @property bool dirty () const pure { return mDirty; }
  // we can't reset dirty flag, you know
  @property void dirty (bool v) {
    if (!mDirty && v) {
      mDirty = true;
      if (mOwner !is null) mOwner.dirtyChild(this);
    }
  }

  @property Rect area () const { return mArea; }

  @property int x () const pure { return mArea.x; }
  @property int y () const pure { return mArea.y; }
  @property int width () const pure { return mArea.width; }
  @property int height () const pure { return mArea.height; }

  @property int x0 () const pure { return mArea.x0; }
  @property int y0 () const pure { return mArea.y0; }
  @property int x1 () const pure { return mArea.x1; }
  @property int y1 () const pure { return mArea.y1; }

  void moveTo (int ax, int ay) {
    if (mArea.x != ax || mArea.y != ay) {
      mArea.x = ax;
      mArea.y = ay;
      dirty = true;
    }
  }

  void resizeTo (int awdt, int ahgt) {
    if (awdt < 0) awdt = 0;
    if (ahgt < 0) ahgt = 0;
    if (mArea.width != awdt || mArea.height != ahgt) {
      // remove overlay, it must be recreated
      if (mOvl !is null) {
        mOvl.free();
        mOvl = null;
      }
      mArea.width = awdt;
      mArea.height = ahgt;
      dirty = true;
    }
  }

  @property void x (int ax) { moveTo(ax, mArea.y); }
  @property void y (int ay) { moveTo(mArea.x, ay); }

  @property void width (int awdt) { resizeTo(awdt, mArea.height); }
  @property void height (int ahgt) { resizeTo(mArea.width, ahgt); }

  @property void x0 (int ax) { this.x = ax; }
  @property void y0 (int ay) { this.y = ay; }
  @property void x1 (int ax) { this.width = ax-mArea.x+1; }
  @property void y1 (int ay) { this.height = ay-mArea.y+1; }

  /// is widget alive? widget can be dead, but not collected yet
  @property bool alive () const pure { return ((mFlags&Flags.Dead) == 0); }

  /// is widget focused?
  @property bool focused () const { return (WDesktop.focused is this); }

  /// is widget active? widget can be active, but not focused
  @property bool active () const pure { return ((mFlags&Flags.Active) != 0); }

  /// is widget enabled?
  @property bool enabled () const pure { return ((mFlags&Flags.Disabled) == 0); }

  /// change widget enabled state
  @property void enabled (bool v) {
    if (enabled != v) {
      if (v) mFlags &= ~Flags.Disabled; else mFlags |= Flags.Disabled;
      dirty = true;
    }
  }

  /// is widget visible?
  @property bool visible () const pure { return ((mFlags&Flags.Hidden) == 0); }

  /// change widget visible state
  @property void visible (bool v) {
    if (visible != v) {
      if (v) mFlags &= ~Flags.Hidden; else mFlags |= Flags.Hidden;
      dirty = true;
    }
  }

  /// can this widget be activated? it should be alive, visible, not disabled
  /// and so it's owners
  @property bool canBeActivated () const pure {
    if ((mFlags&(Flags.Disabled|Flags.Hidden|Flags.Dead|Flags.NoFocus)) == 0) {
      return (mOwner !is null ? mOwner.canBeActivated : true);
    }
    return false;
  }

  void setActiveFlag (bool setit, Widget src=null) {
    if (!alive) return;
    if (active != setit) {
      if (setit) mFlags |= Flags.Active; else mFlags &= ~Flags.Active;
      if (mOwner !is null) mOwner.setActiveFlag(setit, this);
      dirty = true;
    }
  }


  @property inout(Widget) topOwner () inout pure { return (mOwner is null ? this : mOwner.topOwner); }
  @property inout(Widget) firstWidget () inout pure { return (mPrev is null ? this : mPrev.firstWidget); }
  @property inout(Widget) lastWidget () inout pure { return (mNext is null ? this : mNext.lastWidget); }

  /// is w direct child of this widget?
  bool isMyChild (const(Widget) w) const pure { return (w !is null && (w.id in mChildren) !is null); }

  /// is w direct or indirect child of this widget?
  bool isChild (const(Widget) w) const pure @trusted {
    if (isMyChild(w)) return true;
    if (w !is null) foreach (auto wg; mChildren.byValue) if (wg.isChild(w)) return true;
    return false;
  }

  inout(EventCB) eventCB () inout pure { return mECB; }
  EventCB eventCB (EventCB ncb) {
    auto res = mECB;
    mECB = ncb;
    return res;
  }

  @property bool skipPaint () const pure { return ((mFlags&(Flags.Hidden|Flags.Dead)) == 0); }
 }}}} // final

  protected @property final VLOverlay overlay () {
    if (mArea.width < 1 || mArea.height < 1) {
      if (mOvl is null) {
        mOvl = new VLOverlay(1, 1);
      } else {
        mOvl.resize(1, 1);
      }
    } else if (mOvl is null) {
      mOvl = new VLOverlay(mArea.width, mArea.height);
    } else if (mOvl.width != mArea.width || mOvl.height != mArea.height) {
      mOvl.resize(mArea.width, mArea.height);
    }
    return mOvl;
  }

  void paintChildren () {
    if (skipPaint) return;
    if (overlay is null) return;
    foreach (auto w; this) {
      if (!w.skipPaint) {
        if (w.dirty || w.mOvl is null) w.paint();
        if (w.mOvl !is null) w.mOvl.blitSrcAlpha(mOvl, w.mArea.x, w.mArea.y);
      }
    }
  }

  // clear and so on
  void prePaint () {
    overlay.clear(0);
  }

  // cut corners for window for example
  void postPaint () {
  }

  void paint () {
    if (skipPaint) return;
    with (overlay) {
      resetClipOfs();
      mHasDirtyChildren = false;
      mDirty = false;
      prePaint();
      paintChildren();
      postPaint();
    }
  }


final:
  usize length () const pure @safe nothrow @nogc { return mChildren.length; }
  alias opDollar = length;

  // foreach overloading
  private static template thisOrThat (bool cond, string t, string f=``) {
    static if (cond) enum thisOrThat = t; else enum thisOrThat = f;
  }

  private static template opApplyImpl(bool fwd, bool counted, bool cst) {
    enum opApplyImpl =
    `int opApply`~thisOrThat!(!fwd, `Reverse`)~` (int delegate(`~
      thisOrThat!(counted, `usize, `)~
      thisOrThat!(cst, `const `)~`Widget) d) `~
      thisOrThat!(cst, `const `)~
      `{`~
        `int res = 0;`~
        `if (mChildren.length > 0) {`~
          thisOrThat!(cst, `import std.typecons : Rebindable;`)~
          thisOrThat!(counted,
            thisOrThat!(fwd, `usize count = 0;`, `usize count = mChildren.length;`)
          )~
          `auto a = `~thisOrThat!(cst, `Rebindable!(const Widget)(`)~
            `mChildren.byValue.front`~
            thisOrThat!(cst, `)`)~`;`~
          `while (a.`~thisOrThat!(fwd, `mPrev`, `mNext`)~` !is null) a = a.`~thisOrThat!(fwd, `mPrev`, `mNext`)~`;`~
          `while (a !is null && res == 0) {`~
            thisOrThat!(counted && !fwd, `--count;`)~
            `if (a.alive) {`~
              `if ((res = d(`~thisOrThat!(counted, `count, `)~`a)) != 0) break;`~
            `}`~
            thisOrThat!(counted && fwd, `++count;`)~
            `a = a.`~thisOrThat!(fwd, `mNext`, `mPrev`)~`;`~
          `}`~
        `}`~
        `return res;`~
      `}`;
  }

  private static template opApplyAllImpl() {
    enum opApplyAllImpl =
      opApplyImpl!(true, true, true)~
      opApplyImpl!(true, false, true)~
      opApplyImpl!(true, true, false)~
      opApplyImpl!(true, false, false)~
      opApplyImpl!(false, true, true)~
      opApplyImpl!(false, false, true)~
      opApplyImpl!(false, true, false)~
      opApplyImpl!(false, false, false);
  }

  mixin(opApplyAllImpl!());

protected:
  final void addWidget (Widget w) {
    if (w !is null) {
      if (w.mOwner is this) return;
      if (w.mOwner !is null) throw new WidgetError("widget can't has two parents");
      w.mOwner = this;
      if (mChildren.length == 0) {
        w.mPrev = null;
      } else {
        auto a = mChildren.byValue.front;
        while (a.mNext !is null) a = a.mNext;
        a.mNext = w;
        w.mPrev = a;
      }
      w.mNext = null;
      mChildren[w.id] = w;
      w.dirty = true;
    }
  }

  final Widget takeWidget (Widget w) {
    if (w !is null) {
      if (w.mOwner !is this) throw new WidgetError("can't take widget from alien parent");
      if (mChildren.length > 1) {
        // has at least two widgets
        if (w.mPrev is null) {
          // first
          w.mNext.mPrev = null;
        } else if (w.mNext is null) {
          // last
          w.mPrev.mNext = null;
        } else {
          // not first, not last
          w.mPrev.mNext = w.mNext;
          w.mNext.mPrev = w.mPrev;
        }
      }
      mChildren.remove(w.id);
      w.mOwner = w.mNext = w.mPrev = null;
      dirty = true;
      return w;
    }
    return null;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
class WButton : Widget {
  this (int ax, int ay, string acaption) @safe nothrow @nogc {
    int wdt = acaption.length*6+4;
    super(ax, ay, wdt, 10, acaption);
  }

  override void prePaint () {
    with (overlay) {
      Color cback, ctext;
      if (focused) {
        cback = getColor("active.button.back");
        ctext = getColor("active.button.text");
      } else {
        cback = getColor("button.back");
        ctext = getColor("button.text");
      }
      // back
      clear(cback);
      // text
      drawStr(cast(int)(mArea.width-mCaption.length*6)/2, (mArea.height-8)/2, mCaption, ctext);
      // frame
      rect(0, 0, mArea.width, mArea.height, cback);
      // corners
      setPixel(0, 0, Transparent);
      setPixel(0, mArea.height-1, Transparent);
      setPixel(mArea.width-1, 0, Transparent);
      setPixel(mArea.width-1, mArea.height-1, Transparent);
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
class WGroup : Widget {
  this (int ax, int ay, int awdt, int ahgt, string acaption=null) @safe nothrow @nogc {
    super(ax, ay, awdt, ahgt, acaption);
  }

final:
  final Widget opOpAssign(string op : "~") (Widget w) { addWidget(w); }
  final Widget opOpAssign(string op : "+") (Widget w) { addWidget(w); }
  final Widget opOpAssign(string op : "-") (Widget w) { takeWidget(w); }
  final bool opBinaryRight(string op : "in") (inout(Widget) w) inout @trusted { return isMyChild(w); }
}


// ////////////////////////////////////////////////////////////////////////// //
class WWindow : WGroup {
  // frame is drawn by desktop
  this (int ax, int ay, int awdt, int ahgt, string acaption) @safe nothrow @nogc {
    super(ax, ay, awdt, ahgt, acaption);
  }
}



/+
// ////////////////////////////////////////////////////////////////////////// //
abstract class WDesktop {
shared static this () {
  initPalettes();
  installHandlers();
}

shared static ~this () {
  wFocused = null;
  mwLocked = null;
  closeWindows();
}


__gshared Palette[string] palettes;
__gshared string defaultPalette = "red";

private __gshared VLWindow[] wList;
private __gshared Widget wFocused = null; // current focused widget (not window!)

static private Widget mwLocked = null; // mouse was pressed on this widget


private __gshared PaintHookType oldPaintHook = void;

private __gshared uint* vscrBackup = null; // backup for vlwidgets
private __gshared usize vscrSize;


final: // just in case: everything is final here
static: // and everything is static here



@property VLWindow activeWindow () nothrow {
  Widget w = wFocused;
  if (wFocused !is null) while (w.mOwner !is null) w = w.mOwner;
  return cast(VLWindow)w;
}

@property activeWindow (VLWindow w) {
/*
  assert(w is null || w.mOwner is null);
  if (w !is null && w.canBeActivated) {
    if (wFocused !is w) {
      if (wFocused !is null) wFocused.onDeactivate();
      wFocused = w;
      wFocused.onActivate(); // this should set focus to window's active widget
    }
  }
*/
}


@property Widget focused () nothrow { return wFocused; }

@property void focused (Widget w) {
  if (w !is null && w !is wFocused && w.canBeActivated) {
    debug(widgets) writeln("changing focus!");
    if (wFocused !is null) {
      wFocused.setFocusedFlag(false);
      wFocused.onDeactivate();
    }
    wFocused = w;
    wFocused.setFocusedFlag(true);
    wFocused.onActivate();
  } else if (w is null && wFocused !is null) {
    wFocused.setFocusedFlag(false);
    wFocused.onDeactivate();
    wFocused = null;
  }
}

void focus (Widget w) { focused = w; }


/// add widget
VLWindow opOpAssign(string op) (VLWindow wd) if (op == "+" || op == "~") {
  assert(wd !is null);
  foreach (w; wList) if (w is wd) return wd;
  wList ~= wd;
  if (wFocused is null) wd.focus();
  return wd;
}

/// remove widget
VLWindow opOpAssign(string op) (VLWindow wd) if (op == "-") {
  assert(wd !is null);
  usize widx = wList.length;
  foreach (idx, w; wList) if (w is wd) { widx = idx; break; }
  if (widx < wList.length) {
    //TODO: move focus to another window
    if (wd.focused) focused = null;
    for (usize f = widx+1; f < wList.length; ++f) wList[f-1] = wList[f];
    wList[$-1] = null;
    wList.length = wList.length-1;
    wd.mFlags |= Widget.Flags.Dead;
  }
  return wd;
}


void closeWindows () {
  debug(widgets) writeln("closeWindows()");
  while (wList.length > 0) WDesktop -= wList[$-1];
}


// ////////////////////////////////////////////////////////////////////////// //
void paintWidgets () @trusted {
  foreach (w; wList) {
    if (w.dirty) w.paint(null);
    w.mOvl.setPixel(0, 0, Transparent);
    w.mOvl.setPixel(w.mOvl.width-1, 0, Transparent);
    w.mOvl.setPixel(0, w.mOvl.height-1, Transparent);
    w.mOvl.setPixel(w.mOvl.width-1, w.mOvl.height-1, Transparent);
    w.mOvl.blitSrcAlpha(vscrOvl, w.x, w.y);
  }
}


shared static ~this () {
  if (vscrBackup !is null) {
    free(vscrBackup);
    vscrBackup = null;
    vscrSize = 0;
  }
}


private void widgetsPaintHook () @trusted {
  if (vscrBackup is null || vscrSize != vlWidth*vlHeight*vscr[0].sizeof) {
    if (vscrBackup !is null) {
      free(vscrBackup);
      vscrBackup = null;
    }
    vscrSize = vlWidth*vlHeight*vscr[0].sizeof;
    vscrBackup = cast(uint*)malloc(vscrSize);
    if (vscrBackup is null) {
      vscrSize = 0;
      assert(0);
    }
  }
  memcpy(vscrBackup, vscr, vscrSize);
  scope(exit) memcpy(vscr, vscrBackup, vscrSize);
  paintWidgets();
  oldPaintHook();
}


// ////////////////////////////////////////////////////////////////////////// //
/*
static VLWindow inWindow (in int x, in int y) nothrow {
  for (auto win = winLast; win !is null; win = win.mPrev) if (win.inMe(x, y)) return win;
  return null;
}

/ *
  // x and y are in local coords for this widget
  bool onMouseMotion (int x, int y, uint buttons, int xrel, int yrel) { return false; }
  bool onMouseDouble (int x, int y, ubyte button, uint buttons) { return false; }
  bool onMouseDown (int x, int y, ubyte button, uint buttons) { return false; }
  bool onMouseUp (int x, int y, ubyte button, uint buttons) { return false; }
* /
*/

// ////////////////////////////////////////////////////////////////////////// //
private bool bubbleEvent (bool delegate (Widget) handler, Widget wd=null) {
  if (wd is null) wd = (mwLocked is null ? wFocused : mwLocked);
  for (; wd !is null; wd = wd.mOwner) {
    //writeln(" bubble: wd=", wd);
    if (wd.alive && wd.enabled && wd.visible) {
      if (handler(wd)) return true;
    }
  }
  return false;
}


bool onKeyDown (in ref SDL_KeyboardEvent ev) {
  bool doIt (Widget wd) { return wd.onKeyDown(ev.keysym.sym, ev.keysym.mod); }
  //writefln("KEYDOWN! key=%s; mod=%s", ev.keysym.sym, ev.keysym.mod);
  return bubbleEvent(&doIt);
}


bool onKeyUp (in ref SDL_KeyboardEvent ev) {
  bool doIt (Widget wd) { return wd.onKeyUp(ev.keysym.sym, ev.keysym.mod); }
  return bubbleEvent(&doIt);
}


bool onMouseWheel (in ref SDL_MouseWheelEvent ev) {
  uint btns = SDL_GetMouseState(null, null);
  bool doIt (Widget wd) { return wd.onMouseWheel(ev.x, ev.y, btns); }
  return bubbleEvent(&doIt);
}


bool onMouseMotion (in ref SDL_MouseMotionEvent ev) {
  if (mwLocked is null && wFocused is null) return false;
  Group to = (mwLocked is null ? wFocused : mwLocked).topOwner;
  if (to is null) return false;
  int lx = ev.x-to.x, ly = ev.y-to.y;
  bool doIt (Widget wd) {
    int xx = lx, yy = ly;
    wd.topToLocal(xx, yy);
    //debug(widgets) writefln("%s: (%s,%s) -- (%s,%s)", wd, lx, ly, xx, yy);
    return wd.onMouseMotion(xx, yy, ev.xrel, ev.yrel, ev.state);
  }
  return bubbleEvent(&doIt);
}


bool onMouseDown (in ref SDL_MouseButtonEvent ev) {
  if (mwLocked is null && wFocused is null) return false;
  Group to = (mwLocked is null ? wFocused : mwLocked).topOwner;
  if (to is null) return false;
  int lx = ev.x-to.x, ly = ev.y-to.y;
  uint btns = SDL_GetMouseState(null, null);
  ubyte bt = 0;
  switch (ev.button) {
    case SDL_BUTTON_LEFT: bt = Widget.Button.Left; break;
    case SDL_BUTTON_MIDDLE: bt = Widget.Button.Middle; break;
    case SDL_BUTTON_RIGHT: bt = Widget.Button.Right; break;
    default:
  }
  btns |= bt;
  bool doIt (Widget wd) {
    int xx = lx, yy = ly;
    wd.topToLocal(xx, yy);
    return wd.onMouseDown(xx, yy, bt, btns);
  }
  if (mwLocked is null) mwLocked = wFocused;
  return bubbleEvent(&doIt);
}


bool onMouseUp (in ref SDL_MouseButtonEvent ev) {
  if (mwLocked is null && wFocused is null) return false;
  Group to = (mwLocked is null ? wFocused : mwLocked).topOwner;
  if (to is null) return false;
  int lx = ev.x-to.x, ly = ev.y-to.y;
  uint btns = SDL_GetMouseState(null, null);
  ubyte bt = 0;
  switch (ev.button) {
    case SDL_BUTTON_LEFT: bt = Widget.Button.Left; break;
    case SDL_BUTTON_MIDDLE: bt = Widget.Button.Middle; break;
    case SDL_BUTTON_RIGHT: bt = Widget.Button.Right; break;
    default:
  }
  btns &= ~bt;
  bool doIt (Widget wd) {
    int xx = lx, yy = ly;
    wd.topToLocal(xx, yy);
    return wd.onMouseUp(xx, yy, bt, btns);
  }
  auto res = bubbleEvent(&doIt);
  if (bt == 0) mwLocked = null;
  return res;
}


/*
bool onMouseDouble (in ref SDL_MouseButtonEvent ev) {
  return false;
}


bool onMouseMotion (in ref SDL_MouseMotionEvent ev) {
  int x, int y, uint buttons, int xrel, int yrel
  return false;
}
*/


private int widgetPreprocessEvents (ref SDL_Event ev) {
  switch (ev.type) {
    case SDL_KEYDOWN: if (onKeyDown(ev.key)) return 1; break;
    case SDL_KEYUP: if (onKeyUp(ev.key)) return 1; break;
    case SDL_MOUSEBUTTONDOWN: if (onMouseDown(ev.button)) return 1; break;
    case SDL_MOUSEBUTTONUP: if (onMouseUp(ev.button)) return 1; break;
    case SDL_MOUSEWHEEL: if (onMouseWheel(ev.wheel)) return 1; break;
    case SDL_MOUSEMOTION: if (onMouseMotion(ev.motion)) return 1; break;
/*
    case SDL_MOUSEDOUBLE: if (onMouseDouble(ev.button)) return 1; break;
*/
    default:
  }
  return 0;
}


// there is no way to remove them (yet?)
void installHandlers () nothrow {
  __gshared bool handlersInstalled = false;
  if (!handlersInstalled) {
    oldPaintHook = paintHook;
    paintHook = &widgetsPaintHook;
    preprocessEventsHook = &widgetPreprocessEvents;
    handlersInstalled = true;
  }
}

}
+/


// ////////////////////////////////////////////////////////////////////////// //
abstract final class WDesktop {
private:
  __gshared PaintHookType oldPaintHook = void;
  __gshared uint* vscrBackup = null; // backup for vlwidgets
  __gshared usize vscrSize;

static:
  Palette[string] palettes;
  Palette* mDefaultPalette;
  Widget mFocused;
  Widget[] mTopLevel; // list of all top-level widgets


public:
  void initialize () {
    static bool inited = false;
    if (!inited) {
      initPalettes();
      installHandlers();
      inited = true;
    }
  }

  void deinitialize () {
    if (vscrBackup !is null) {
      import core.stdc.stdlib : free;
      free(vscrBackup);
      vscrBackup = null;
      vscrSize = 0;
    }
  }

  @property const(Palette*) defaultPalette () @safe nothrow @nogc { return mDefaultPalette; }

  @property Widget focused () @safe nothrow @nogc { return mFocused; }

  //Widget opOpAssign(string op : "~") (Widget w) { addWidget(w); }
  //Widget opOpAssign(string op : "+") (Widget w) { addWidget(w); }
  //bool opBinaryRight(string op : "in") (inout(Widget) w) inout @trusted { return isMyChild(w); }

private:
  // draw window
  void drawWindow (Widget win) {
    if (win is null || win.skipPaint) return;
    vscrOvl.resetClipOfs();
    if (win.dirty) win.paint();
    win.mOvl.blitSrcAlpha(vscrOvl, win.x+1, win.y+10);
    // draw frame
    if (win.width > 0) {
      with (vscrOvl) {
        uint cfrm, ctxt;
        cfrm = win.getColor("window.caption.back");
        ctxt = win.getColor("window.caption.text");
        // frame
        hline(win.x+1, win.y, win.width, cfrm); // top
        hline(win.x+1, win.y+win.height+10, win.width, cfrm); // bottom
        vline(win.x, win.y+1, win.height+9, cfrm); // left
        vline(win.x+win.width+1, win.y+1, win.height+9, cfrm); // right
        setPixel(win.x+1, win.y+win.height+9, cfrm); // bottom-left
        setPixel(win.x+win.width+1, win.y+win.height+9, cfrm); // bottom-right
        // caption
        fillRect(win.x+1, win.y+1, win.width, 9, cfrm);
        setClip(win.x+1, win.y+1, win.width, 8);
        if (win.mCaption.length > 0) {
          drawStr(win.x+1-(win.width-cast(int)win.mCaption.length*6)/2, 1, win.mCaption, ctxt);
        }
        resetClip();
      }
    }
  }

  void paintWidgets () @trusted {
    foreach (auto w; mTopLevel) {
      if (w.skipPaint) continue;
      if (w.dirty) w.paint();
      if (w.mOvl !is null) {
        if (cast(WWindow)w) {
          drawWindow(w);
        } else {
          w.mOvl.blitSrcAlpha(vscrOvl, w.x, w.y);
        }
      }
    }
  }


  private void widgetsPaintHook () @trusted {
    if (mTopLevel.length > 0) {
      import core.stdc.string : memcpy;
      if (vscrBackup is null || vscrSize != vlWidth*vlHeight*vscr[0].sizeof) {
        import core.stdc.stdlib : malloc;
        if (vscrBackup !is null) {
          import core.stdc.stdlib : free;
          free(vscrBackup);
          vscrBackup = null;
        }
        vscrSize = vlWidth*vlHeight*vscr[0].sizeof;
        vscrBackup = cast(uint*)malloc(vscrSize);
        if (vscrBackup is null) {
          vscrSize = 0;
          assert(0);
        }
      }
      memcpy(vscrBackup, vscr, vscrSize);
      scope(exit) memcpy(vscr, vscrBackup, vscrSize);
      paintWidgets();
    }
    oldPaintHook();
  }

private:
  void initPalettes () {
    // red
    {
      Palette pal;
      pal.name = "red";
      // window
      pal.colors["window.caption.text"] = rgb2col(0, 0, 0);
      pal.colors["window.caption.back"] = rgb2col(255, 255, 255);
      pal.colors["window.text"] = rgb2col(255, 255, 0);
      pal.colors["window.back"] = rgb2col(128, 0, 0);
      // button
      pal.colors["active.button.text"] = rgb2col(0, 64, 0);
      pal.colors["active.button.back"] = rgb2col(255, 255, 255);
      pal.colors["disabled.button.text"] = rgb2col(60, 60, 60);
      pal.colors["disabled.button.back"] = rgb2col(190, 190, 190);
      pal.colors["button.text"] = rgb2col(0, 0, 0);
      pal.colors["button.back"] = rgb2col(190, 190, 190);
      //
      palettes[pal.name] = pal;
    }
    mDefaultPalette = "red" in palettes;
    if (mDefaultPalette is null) assert(0);
  }

  // there is no way to remove them (yet?)
  void installHandlers () nothrow {
    __gshared bool handlersInstalled = false;
    if (!handlersInstalled) {
      oldPaintHook = paintHook;
      paintHook = &widgetsPaintHook;
      //preprocessEventsHook = &widgetPreprocessEvents;
      handlersInstalled = true;
    }
  }
}
