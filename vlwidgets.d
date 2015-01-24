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
module iv.vlwidgets is aliced;

import iv.videolib;
import iv.rect;

import core.stdc.stdlib : malloc, realloc, free;
import core.stdc.string : memcpy, memmove;
//import std.exception;
import std.conv;
import std.functional;
import std.stdio;
import std.string;
import std.variant;


////////////////////////////////////////////////////////////////////////////////
/// generic VideoLib exception
class WidgetError : object.Exception {
  @safe pure nothrow this (string msg, string file=__FILE__, usize line=__LINE__, Throwable next=null) {
    super(msg, file, line, next);
  }
}


////////////////////////////////////////////////////////////////////////////////
/// palettes (aka 'color schemes')
/// entries looks like: `window.button.text`
/// widgets will look in this order:
///   `active.widgetname.text`
///   `widgetname.text`
///   `text`
/// i.e.removing dots until color is found or no more dots left to remove
struct Palette {
  uint opIndex (string cname) nothrow {
    while (cname.length != 0) {
      auto clr = (cname in colors);
      if (clr !is null) return *clr;
      //cname.munch("^."); // not nothrow
      usize pos;
      while (pos < cname.length && cname[pos] != '.') ++pos;
      if (++pos >= cname.length) break;
      cname = cname[pos..$];
    }
    return rgb2col(0, 0, 0);
  }

private:
  uint[string] colors;
}


////////////////////////////////////////////////////////////////////////////////
abstract class Widget {
public:
  alias EventCB = void delegate (Widget wd);

  // for 'button' and 'btstate'
  enum Button {
    Left = 0x01,
    Middle = 0x02,
    Right = 0x04
  }

  enum Flags {
    Disabled = 0x01,
    Hidden = 0x02,
    NoFocus = 0x04,
    Focused = 0x100,
    Dead = 0x8000
  }


public:
  this() (int ax, int ay, int awdt, int ahgt, string acaption=null) {
    debug(widgets) try writeln("constuctor: ", this); catch (Exception) {}
    mArea.x = ax;
    mArea.y = ay;
    mArea.width = awdt;
    mArea.height = ahgt;
    mCaption = acaption;
    mPalette = null;
    mPal = null;
    mDirty = true;
  }

  ~this () nothrow {
    debug(widgets) try writeln("destructor: ", this); catch (Exception) {}
    mFlags |= Flags.Dead;
    mOwner = null;
  }

  /// get widget palette
  @property final ref Palette pal () nothrow {
    if (mPal is null) {
      if (mOwner !is null) return *(mOwner.mPal);
      return *(VLDesk.defaultPalette in VLDesk.palettes);
    } else {
      return (*mPal);
    }
  }

  @property final bool dirty () const nothrow { return mDirty; }
  // we can't reset dirty flag, you know
  @property final void dirty (bool v) nothrow {
    if (!mDirty && v) {
      mDirty = true;
      if (mOwner) mOwner.dirty = true;
    }
  }

  @property final Group topOwner () nothrow {
    if (mOwner !is null) {
      Group w = mOwner;
      while (w.mOwner !is null) w = w.mOwner;
      return w;
    }
    return null;
  }

  @property final Widget lastWidget () nothrow { return lastWidgetImpl(); }

  @property final Rect area () const nothrow { return mArea; }

  @property final int x () const nothrow { return mArea.x; }
  @property final int y () const nothrow { return mArea.y; }
  @property final int width () const nothrow { return mArea.width; }
  @property final int height () const nothrow { return mArea.height; }

  @property final int x0 () const nothrow { return mArea.x0; }
  @property final int y0 () const nothrow { return mArea.y0; }
  @property final int x1 () const nothrow { return mArea.x1; }
  @property final int y1 () const nothrow { return mArea.y1; }

  @property final void x (int ax) {
    if (mArea.x != ax) { mArea.x = ax; dirty = true; onPositionChanged(); }
  }
  @property final void y (int ay) {
    if (mArea.y != ay) { mArea.y = ay; dirty = true; onPositionChanged(); }
  }
  @property final void width (int wdt) {
    if (wdt < 0) wdt = 0;
    if (wdt != mArea.width) { mArea.width = wdt; dirty = true; onSizeChanged(); }
  }
  @property final void height (int hgt) {
    if (hgt < 0) hgt = 0;
    if (hgt != mArea.height) { mArea.height = hgt; dirty = true; onSizeChanged(); }
  }

  @property final void x0 (int ax) { this.x = ax; }
  @property final void y0 (int ay) { this.y = ay; }
  @property final void x1 (int ax) { this.width = ax-mArea.x+1; }
  @property final void y1 (int ay) { this.height = ay-mArea.y+1; }


  /// return widget flags (see Flags enum)
  @property final uint flags () const nothrow { return mFlags; }

  /// can this widget be activated? it should be alive, visible, not disabled
  /// and so it's owners
  @property bool canBeActivated () const nothrow {
    if ((mFlags&(Flags.Disabled|Flags.Hidden|Flags.Dead|Flags.NoFocus)) == 0) {
      return (mOwner !is null ? mOwner.canBeActivated : true);
    }
    return false;
  }

  /// is widget alive? widget can be dead, but not collected yet
  @property final bool alive () const nothrow { return ((mFlags&Flags.Dead) == 0); }

  /// is widget focused?
  @property final bool focused () const nothrow { return ((mFlags&Flags.Focused) != 0 && VLDesk.focused is this); }
  @property final void focused (bool v) { focus(); }

  @property protected final bool semiFocused () const nothrow { return ((mFlags&Flags.Focused) != 0); }

  void focus () { setFocusedFlag(true); }

  protected void setFocusedFlag (bool setit, Widget src=null) {
    if (!alive) return;
    if (semiFocused != setit) {
      if (setit) mFlags |= Flags.Focused; else mFlags &= ~Flags.Focused;
      if (mOwner !is null) mOwner.setFocusedFlag(setit, this);
      dirty = true;
    }
  }

  /// is widget enabled?
  @property final bool enabled () const nothrow { return ((mFlags&Flags.Disabled) == 0); }

  /// change widget enabled state
  @property final void enabled (bool v) {
    if (enabled != v) {
      if (v) {
        mFlags &= ~Flags.Disabled;
        onEnable();
      } else {
        mFlags |= Flags.Disabled;
        onDisable();
        //TODO: change focus
      }
      dirty = true;
    }
  }

  /// is widget visible?
  @property final bool visible () const nothrow { return ((mFlags&Flags.Hidden) == 0); }

  /// change widget visible state
  @property final void visible (bool v) {
    if (visible != v) {
      if (v) {
        mFlags &= ~Flags.Hidden;
        //onShow();
      } else {
        mFlags |= Flags.Hidden;
        //onHide();
        //TODO: change focus
      }
      dirty = true;
    }
  }


  /// is w direct child of this widget?
  bool myWidget (const Widget w) const nothrow { return false; }

  /// is w direct or indirect child of this widget?
  bool myOrChildWidget (const Widget w) const nothrow { return false; }


  /// set/remove callback
  final void opIndexAssign (EventCB ecb, string name) {
    if (ecb !is null) {
      mECB[name] = ecb;
    } else {
      mECB.remove(name);
    }
  }

  /// ditto
  final void opIndexAssign (void function (Widget) ecb, string name) {
    if (ecb !is null) {
      mECB[name] = std.functional.toDelegate(ecb);
    } else {
      mECB.remove(name);
    }
  }

  /// remove callback by name
  final void remove (string name) {
    mECB.remove(name);
  }


  /// is global (x,y) in this widget?
  bool localInMe (in int x, in int y) const nothrow { return mArea.inside(x, y); }


  /// convert (x,y) from global coords to widget local coords
  void globalToLocal (ref int x, ref int y) const nothrow { x -= mArea.x; y -= mArea.y; }

  /// convert (x,y) from widget local coords to widget client area coords
  void localToClient (ref int x, ref int y) const nothrow {}

  /// convert (x,y) from widget client coords to widget local coords
  void clientToLocal (ref int x, ref int y) const nothrow {}

  /// convert (x,y) from global to client
  final void globalToClient (ref int x, ref int y) const nothrow {
    globalToLocal(x, y);
    localToClient(x, y);
  }

  void localToParent (ref int x, ref int y) const nothrow {
    x += mArea.x;
    y += mArea.y;
    if (mOwner !is null) mOwner.clientToLocal(x, y);
  }

  // local coords to top-level widget coords
  void localToTop (ref int x, ref int y) const nothrow {
    debug(widgets_coords) writefln("localToTop: in: (%s,%s)", x, y);
    if (mOwner !is null) {
      x += mArea.x;
      y += mArea.y;
      debug(widgets_coords) writefln("localToTop: atowner client: (%s,%s)", x, y);
      mOwner.clientToLocal(x, y);
      debug(widgets_coords) writefln("localToTop: atowner local: (%s,%s)", x, y);
      mOwner.localToTop(x, y);
      debug(widgets_coords) writefln("localToTop: res: (%s,%s)", x, y);
    }
  }


  // top-level local widget coords to this widget's local coords
  void topToLocal (ref int x, ref int y) const nothrow {
    if (mOwner !is null) {
      mOwner.topToLocal(x, y);
      mOwner.localToClient(x, y);
      x -= mArea.x;
      y -= mArea.y;
    }
  }


  /// WARNING: overlay clip region must not be increased
  /// overlay offset set to widget origin
  /// overlay clip region set to widget dimensions
  abstract void paint (VLOverlay ovl);

  void onAction () { callECB("onAction"); }

  void onAdopted () { dirty = true; callECB("onAdopted"); } /// called after widget was added to children
  void onOrphaned () { dirty = true; callECB("onOrphaned"); } /// called before widget will be removed from children

  void onActivate () { dirty = true; callECB("onActivate"); }
  void onDeactivate () { dirty = true; callECB("onDeactivate"); }

  void onEnable () { dirty = true; callECB("onActivate"); }
  void onDisable () { dirty = true; callECB("onDeactivate"); }

  void onPositionChanged () { dirty = true; callECB("onPositionChanged"); }
  void onSizeChanged () { dirty = true; callECB("onSizeChanged"); }

  bool onKeyDown (int keycode, ushort keymod) { return false; }
  bool onKeyUp (int keycode, ushort keymod) { return false; }

  // x<0: left; x>0: right
  // y<0: down; x>0: up
  bool onMouseWheel (int x, int y, uint buttons) { return false; }
  // x and y are in local coords for this widget
  bool onMouseMotion (int x, int y, uint buttons, int xrel, int yrel) { return false; }
  bool onMouseDouble (int x, int y, ubyte button, uint buttons) { return false; }
  bool onMouseDown (int x, int y, ubyte button, uint buttons) { return false; }
  bool onMouseUp (int x, int y, ubyte button, uint buttons) { return false; }


protected:
  Widget lastWidgetImpl () nothrow {
    return null;
  }


private:
  final void callECB (string name) {
    auto ecb = (name in mECB);
    if (ecb !is null) (*ecb)(this);
  }


private:
  Group mOwner;
  string mPalette; // null: use window palette
  Palette* mPal; // null: use window palette
  Rect mArea;
  string mCaption;
  uint mFlags;
  EventCB[string] mECB;
  bool mDirty;
}


////////////////////////////////////////////////////////////////////////////////
class Group : Widget {
  this(T) (int ax, int ay, int awdt, int ahgt, T acaption=null) if (isSomeString!T) {
    mActiveIdx = -1;
    super(ax, ay, awdt, ahgt, acaption);
  }


  /// foreach overloading
  int opApply (int delegate(const Widget) d) const {
    int res = 0;
    for (usize f = 0; f < mChildren.length; ++f) if ((res = d(mChildren[f])) != 0) break;
    return res;
  }

  /// ditto
  int opApply (int delegate(usize, const Widget) d) const {
    int res = 0;
    for (usize f = 0; f < mChildren.length; ++f) if ((res = d(f, mChildren[f])) != 0) break;
    return res;
  }

  /// ditto
  int opApply (int delegate(Widget) d) {
    int res = 0;
    for (usize f = 0; f < mChildren.length; ++f) if ((res = d(mChildren[f])) != 0) break;
    return res;
  }

  /// ditto
  int opApply (int delegate(usize, Widget) d) {
    int res = 0;
    for (usize f = 0; f < mChildren.length; ++f) if ((res = d(f, mChildren[f])) != 0) break;
    return res;
  }


  private final int widgetIndex (const Widget w) const nothrow {
    foreach (idx, wd; mChildren) if (w is wd) return cast(int)idx;
    return -1;
  }


  protected override void setFocusedFlag (bool setit, Widget src=null) {
    if (!alive) return;
    if (semiFocused != setit) {
      int idx = widgetIndex(src);
      if (setit) {
        mFlags |= Flags.Focused;
        mActiveIdx = idx;
      } else {
        mFlags &= ~Flags.Focused;
      }
      if (mOwner !is null) mOwner.setFocusedFlag(setit, this);
      dirty = true;
    }
  }


  /// is w direct child of this widget?
  override bool myWidget (const Widget w) const nothrow {
    if (w !is null) {
      foreach (xw; mChildren) if (w is xw) return true;
    }
    return false;
  }


  /// is w direct or indirect child of this widget?
  override bool myOrChildWidget (const Widget w) const nothrow {
    if (w !is null) {
      if (myWidget(w)) return true;
      foreach (xw; mChildren) if (xw.myWidget(w)) return true;
    }
    return false;
  }


  /// get direct child of this widget from w
  final Widget childToMyWidget (Widget w) nothrow {
    if (w !is null) {
      if (myWidget(w)) return w;
      foreach (xw; mChildren) if (xw.myWidget(w)) return xw;
    }
    return null;
  }


  /// in which direct child (x,y) is
  /// (x,y) are client coords (see localToClient())
  final Widget clientInWidget (in int x, in int y) nothrow {
    foreach_reverse (xw; mChildren) {
      if (xw.visible && x >= xw.x && y >= xw.y && x < xw.x+xw.width && y < xw.y+xw.height) return xw;
    }
    return null;
  }


  /// WARNING: overlay clip region must not be increased
  /// overlay offset set to widget origin
  /// overlay clip region set to widget dimensions
  override void paint (VLOverlay ovl) {
    assert(ovl !is null);
    debug(widgets) writeln("Group.paint()");
    mDirty = false;
    foreach (idx, wd; mChildren) {
      //TODO: coords to parent; set ofs and clip; draw
      if (!wd.visible) {
        debug(widgets) writefln(" child #%s: invisible", idx);
        continue;
      }
      auto w = wd.mArea.width, h = wd.mArea.height;
      debug(widgets) writefln(" child #%s size: %sx%s", idx, w, h);
      if (w > 0 && h > 0) {
        auto x = 0, y = 0;
        //debug(widgets) writefln(" child #%s pos: (%s,%s)", idx, x, y);
        wd.localToTop(x, y);
        debug(widgets) writefln(" child #%s pos in top: (%s,%s); ovl size: %sx%s", idx, x, y, ovl.width, ovl.height);
        if (x+w > 0 && y+h > 0 && x < ovl.width && y < ovl.height) {
          ovl.setOfs(x, y);
          ovl.setClip(x, y, w, h);
          wd.paint(ovl);
        }
      }
    }
  }

  override void onActivate () {
    Widget.onActivate();
    if (mActiveIdx >= 0 && VLDesk.focused != mChildren[mActiveIdx]) VLDesk.focused = mChildren[mActiveIdx];
  }

  override bool onKeyDown (int keycode, ushort keymod) {
    if (keycode == SDLK_TAB && (keymod&~KMOD_SHIFT) == 0) {
      int next = findNextPrevWidgetToActivate(keymod&KMOD_SHIFT ? -1 : 1);
      debug(widgets) writefln("group keydown; cur=%s; next=%s", mActiveIdx, next);
      if (next >= 0) {
        dirty = true;
        VLDesk.focused = mChildren[next];
        return true;
      }
    }
    return false;
  }

  override bool onKeyUp (int keycode, ushort keymod) {
    return false;
  }

  final bool doMouseEvent (int x, int y, bool delegate (Widget wd, int cx, int cy) handler) {
    if (localInMe(x, y)) {
      localToClient(x, y);
      for (int idx = mChildren.length-1; idx >= 0; --idx) {
        auto wd = mChildren[idx];
        if (wd.visible && wd.enabled) {
          int cx = x-wd.x, cy = y-wd.y;
          if (wd.localInMe(cx, cy)) return handler(wd, cx, cy);
        }
      }
      return true;
    }
    return false;
  }

  // x and y are in local coords for this widget
  override bool onMouseMotion (int x, int y, uint buttons, int xrel, int yrel) {
    return false;
  }

  // x<0: left; x>0: right
  // y<0: down; x>0: up
  override bool onMouseWheel (int x, int y, uint buttons) {
    return false;
  }

  override bool onMouseDouble (int x, int y, ubyte button, uint buttons) {
    bool doIt (Widget wd, int cx, int cy) { return wd.onMouseDouble(cx, cy, button, buttons); }
    return doMouseEvent(x, y, &doIt);
  }

  override bool onMouseDown (int x, int y, ubyte button, uint buttons) {
    bool doIt (Widget wd, int cx, int cy) { return wd.onMouseDown(cx, cy, button, buttons); }
    return doMouseEvent(x, y, &doIt);
  }

  override bool onMouseUp (int x, int y, ubyte button, uint buttons) {
    bool doIt (Widget wd, int cx, int cy) { return wd.onMouseUp(cx, cy, button, buttons); }
    return doMouseEvent(x, y, &doIt);
  }


  /// add widget
  final Widget opOpAssign(string op) (Widget wd) if (op == "+" || op == "~") {
    addWidget(wd);
    return wd;
  }

  /// remove widget
  final Widget opOpAssign(string op) (Widget wd) if (op == "-") {
    removeWidget(wd);
    return wd;
  }


protected:
  override Widget lastWidgetImpl () nothrow {
    return (mChildren.length ? mChildren[$-1] : null);
  }


private:
  Widget[] mChildren;
  int mActiveIdx;


private:
final:
  // <0: nothing was found
  int findNextPrevWidgetToActivate (int dir) nothrow
  in {
    assert(dir == -1 || dir == 1);
  }
  body {
    if (mActiveIdx >= 0) {
      for (auto i = mActiveIdx+dir; i >= 0 && i < mChildren.length; i += dir) if (mChildren[i].canBeActivated) return i;
      for (auto i = (dir > 0 ? 0 : mChildren.length-1); i != mActiveIdx; i += dir) if (mChildren[i].canBeActivated) return i;
    } else {
      for (auto i = (dir > 0 ? 0 : mChildren.length-1); i >= 0 && i < mChildren.length; i += dir) if (mChildren[i].canBeActivated) return i;
    }
    return -1;
  }

  void activateNextPrevWidget (int dir)
  in {
    assert(dir == -1 || dir == 1);
  }
  body {
    auto next = findNextPrevWidgetToActivate(dir);
    if (next >= 0) {
      dirty = true;
      VLDesk.focused = mChildren[next];
    }
  }


  /// activate next widget
  void activateNext () { activateNextPrevWidget(1); }

  /// activate previous widget
  void activatePrev () { activateNextPrevWidget(-1); }


  void addWidget (Widget wd) {
    if (wd !is null && wd.mOwner !is this) {
      bool wasFocused = (focused || VLDesk.focused is null);
      if (wd.focused) VLDesk.focused = null; // remove focus
      if (wd.mOwner !is null) wd.mOwner -= wd; // take widget from it's previous owner
      wd.mOwner = this;
      mChildren ~= wd;
      wd.onAdopted();
      dirty = true;
      if (mActiveIdx < 0 && wd.canBeActivated) {
        mActiveIdx = mChildren.length-1;
        if (wasFocused) VLDesk.focused = wd;
      }
      if (VLDesk.focused is null) focus();
    }
  }


  void removeWidget (Widget wd) {
    if (wd !is null && wd.mOwner is this) {
      bool regainFocus = false;
      usize widx = mChildren.length;
      foreach (idx, w; mChildren) if (w is wd) { widx = idx; break; }
      assert(widx < mChildren.length);
      if (wd.focused) {
        // remove focus
        mActiveIdx = findNextPrevWidgetToActivate(1);
        regainFocus = true;
        VLDesk.focused = null;
      }
      wd.onOrphaned();
      if (mActiveIdx >= widx) {
        if (--mActiveIdx < 0) mActiveIdx = findNextPrevWidgetToActivate(1);
      }
      for (usize f = widx+1; f < mChildren.length; ++f) mChildren[f-1] = mChildren[f];
      mChildren[$-1] = null;
      mChildren.length = mChildren.length-1;
      wd.mOwner = null;
      if (regainFocus && mActiveIdx >= 0) VLDesk.focused = mChildren[mActiveIdx];
      dirty = true;
    }
  }
}


////////////////////////////////////////////////////////////////////////////////
class VLButton : Widget {
  this(T) (int ax, int ay, T acaption) if (isSomeString!T) {
    super(ax, ay, 1, 10, acaption);
    mArea.width = mCaption.length*6+4;
  }

  /// is global (x,y) in this widget?
  override bool localInMe (in int x, in int y) const nothrow {
    if (x == 0 || x == mArea.width-1) {
      if (y == 0 || y == mArea.height-1) return false; // corners?
    } else if (y == 0 || y == mArea.height-1) {
      if (x == 0 || x == mArea.width-1) return false; // corners?
    }
    return (x >= 0 && y >= 0 && x < mArea.width && y < mArea.height);
  }


  override void paint (VLOverlay ovl) {
    assert(ovl !is null);
    mDirty = false;
    debug(widgets) writeln("VLButton.paint()");
    uint cback, ctext;
    if (focused) {
      cback = pal["active.button.back"];
      ctext = pal["active.button.text"];
    } else {
      cback = pal["button.back"];
      ctext = pal["button.text"];
    }
    // back
    ovl.fillRect(1, 1, mArea.width-2, mArea.height-2, cback);
    ovl.hline(1, 0, mArea.width-2, cback);
    ovl.hline(1, mArea.height-1, mArea.width-2, cback);
    ovl.vline(0, 1, mArea.height-2, cback);
    ovl.vline(mArea.width-1, 1, mArea.height-2, cback);
    // text
    ovl.clipIntrude(1, 1); // don't override borders
    ovl.drawStr(cast(int)(mArea.width-mCaption.length*6)/2, 1, mCaption, ctext);
  }

  override bool onKeyDown (int keycode, ushort keymod) {
    if (focused && (keycode == SDLK_RETURN || keycode == SDLK_SPACE) && keymod == 0) {
      onAction();
      return true;
    }
    return false;
  }

  override bool onMouseDown (int x, int y, ubyte button, uint buttons) {
    debug(widgets) writefln("button mouse down at (%s,%s); button=%s; state=%d", x, y, button, buttons);
    if (button == Button.Left && localInMe(x, y)) {
      VLDesk.focused = this;
      return true;
    }
    return false;
  }

  override bool onMouseUp (int x, int y, ubyte button, uint buttons) {
    if (button == Button.Left && VLDesk.focused is this) {
      if (localInMe(x, y)) onAction();
      return true;
    }
    return false;
  }
}


////////////////////////////////////////////////////////////////////////////////
class VLWindow : Group {
  this(T) (int ax, int ay, int awdt, int ahgt, T acaption) if (isSomeString!T) {
    super(ax, ay, awdt, ahgt, acaption);
    //TODO: check width and height
    mOvl = new VLOverlay(awdt, ahgt);
    mPalette = VLDesk.defaultPalette;
    mPal = mPalette in VLDesk.palettes;
  }


  /// convert (x,y) from widget local coords to widget client area coords
  override void localToClient (ref int x, ref int y) const nothrow {
    x -= 1;
    y -= 10;
  }

  /// convert (x,y) from widget client coords to widget local coords
  override void clientToLocal (ref int x, ref int y) const nothrow {
    x += 1;
    y += 10;
  }

  override void localToTop (ref int x, ref int y) const nothrow {}
  override void topToLocal (ref int x, ref int y) const nothrow {}


  void close () {
    if (mOvl !is null && alive) {
      VLDesk -= this;
      mOvl.destroy;
      mOvl = null; //???
      mFlags |= Flags.Dead;
    }
  }

  // ovl is null here
  override void paint (VLOverlay ovl) {
    assert(ovl is null);
    if (mDirty) {
      mDirty = false;
      debug(widgets) writeln("VLWindow.paint()");
      uint cfrm, ctxt;
      cfrm = (*mPal)["window.caption.back"];
      ctxt = (*mPal)["window.caption.text"];
      mOvl.resetOfs();
      mOvl.resetClip();
      mOvl.clear((*mPal)["window.back"]);
      // frame
      mOvl.rect(0, 0, mOvl.width, mOvl.height, cfrm);
      // caption
      mOvl.fillRect(0, 0, mOvl.width, 10, cfrm);
      mOvl.setClip(1, 1, mOvl.width-2, 8);
      mOvl.drawStr(cast(int)(mOvl.width-2-mCaption.length*6)/2, 1, mCaption, ctxt);
      //
      mOvl.setClip(1, 10, mOvl.width-2, mOvl.height-11);
      Group.paint(mOvl);
      mOvl.resetOfs();
      mOvl.setClip(1, 10, mOvl.width-2, mOvl.height-11);
      // bottom frame pixels
      mOvl.resetClip();
      mOvl.setPixel(1, mOvl.height-2, cfrm);
      mOvl.setPixel(mOvl.width-2, mOvl.height-2, cfrm);
      //
    }
  }


  override bool onKeyDown (int keycode, ushort keymod) {
    if (Group.onKeyDown(keycode, keymod)) return true;
    return false;
  }

  override bool onKeyUp (int keycode, ushort keymod) {
    if (Group.onKeyUp(keycode, keymod)) return true;
    return false;
  }


private:
  VLOverlay mOvl;
}


////////////////////////////////////////////////////////////////////////////////
/// FUCKIN' HACKERY! idiotic D compiler will fuck up all my public imports if
/// i'm using the form 'import vl = iv.videolib;'. i REALLY hate it here.

abstract class VLDesk {
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

void initPalettes () {
  // red
  {
    Palette pal;
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
    palettes["red"] = pal;
  }
}


@property VLWindow activeWindow () nothrow {
  Widget w = wFocused;
  if (wFocused !is null) while (w.mOwner !is null) w = w.mOwner;
  return cast(VLWindow)w;
}

@property activeWindow (VLWindow w) {
/+
  assert(w is null || w.mOwner is null);
  if (w !is null && w.canBeActivated) {
    if (wFocused !is w) {
      if (wFocused !is null) wFocused.onDeactivate();
      wFocused = w;
      wFocused.onActivate(); // this should set focus to window's active widget
    }
  }
+/
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
  while (wList.length > 0) VLDesk -= wList[$-1];
}


////////////////////////////////////////////////////////////////////////////////
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


////////////////////////////////////////////////////////////////////////////////
/+
static VLWindow inWindow (in int x, in int y) nothrow {
  for (auto win = winLast; win !is null; win = win.mPrev) if (win.inMe(x, y)) return win;
  return null;
}

/*
  // x and y are in local coords for this widget
  bool onMouseMotion (int x, int y, uint buttons, int xrel, int yrel) { return false; }
  bool onMouseDouble (int x, int y, ubyte button, uint buttons) { return false; }
  bool onMouseDown (int x, int y, ubyte button, uint buttons) { return false; }
  bool onMouseUp (int x, int y, ubyte button, uint buttons) { return false; }
*/
+/

////////////////////////////////////////////////////////////////////////////////
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


/+
bool onMouseDouble (in ref SDL_MouseButtonEvent ev) {
  return false;
}


bool onMouseMotion (in ref SDL_MouseMotionEvent ev) {
  int x, int y, uint buttons, int xrel, int yrel
  return false;
}
+/


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
