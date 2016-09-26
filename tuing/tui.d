/* Invisible Vector Library
 * simple FlexBox-based TUI engine
 *
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
module iv.tuing.tui;

import iv.strex;
import iv.rawtty2;
import iv.weakref;

import iv.tuing.types;
import iv.tuing.layout;
import iv.tuing.eventbus;
import iv.tuing.tty;
import iv.tuing.events;
import iv.tuing.controls.window;


// ////////////////////////////////////////////////////////////////////////// //
__gshared ushort fuiDoubleTime = 250; // 250 msecs to register doubleclick


public void fuiLayout (FuiControl ctl) { if (ctl !is null) iv.tuing.layout.fuiLayout(ctl.lp); }


// ////////////////////////////////////////////////////////////////////////// //
// `id` is element id
public class FuiHistoryManager {
public:
  this () {}
  abstract bool has (FuiControl ctl);
  abstract int count (FuiControl ctl);
  abstract const(char)[] item (FuiControl ctl, int idx); // 0: oldest
  abstract void add (FuiControl ctl, const(char)[] value); // this can shrink history; should correctly process duplicates
  abstract void clear (FuiControl ctl);
  abstract void activate (FuiControl ctl, int idx); // usually moves item to bottom
}


// ////////////////////////////////////////////////////////////////////////// //
struct FuiPalette {
  uint def; // default color
  uint sel; // sel is also focus
  uint mark; // marked text
  uint marksel; // active marked text
  uint gauge; // unused
  uint input; // input field
  uint inputmark; // input field marked text (?)
  uint inputunchanged; // unchanged input field
  uint reverse; // reversed text
  uint title; // window title
  uint disabled; // disabled text
  // hotkey
  uint hot;
  uint hotsel;
}


// ////////////////////////////////////////////////////////////////////////// //
enum FuiPaletteNormal = 0;
enum FuiPaletteError = 1;

__gshared FuiPalette[2] fuiPalette; // default palette

shared static this () {
  fuiPalette[FuiPaletteNormal].def = XtColorFB!(ttyRgb2Color(0xd0, 0xd0, 0xd0), ttyRgb2Color(0x4e, 0x4e, 0x4e)); // 252,239
  // sel is also focus
  fuiPalette[FuiPaletteNormal].sel = XtColorFB!(ttyRgb2Color(0xda, 0xda, 0xda), ttyRgb2Color(0x00, 0x5f, 0x5f)); // 253,23
  fuiPalette[FuiPaletteNormal].mark = XtColorFB!(ttyRgb2Color(0xff, 0xff, 0x00), ttyRgb2Color(0x5f, 0x5f, 0x5f)); // 226,59
  fuiPalette[FuiPaletteNormal].marksel = XtColorFB!(ttyRgb2Color(0xff, 0xff, 0x87), ttyRgb2Color(0x00, 0x5f, 0x87)); // 228,24
  fuiPalette[FuiPaletteNormal].gauge = XtColorFB!(ttyRgb2Color(0xbc, 0xbc, 0xbc), ttyRgb2Color(0x5f, 0x87, 0x87)); // 250,66
  fuiPalette[FuiPaletteNormal].input = XtColorFB!(ttyRgb2Color(0xd7, 0xd7, 0xaf), ttyRgb2Color(0x26, 0x26, 0x26)); // 187,235
  fuiPalette[FuiPaletteNormal].inputmark = XtColorFB!(ttyRgb2Color(0xff, 0xff, 0x87), ttyRgb2Color(0x00, 0x5f, 0x5f)); // 228,23
  //fuiPalette[FuiPaletteNormal].inputunchanged = XtColorFB!(ttyRgb2Color(0xff, 0xff, 0xff), ttyRgb2Color(0x26, 0x26, 0x26)); // 144,235
  fuiPalette[FuiPaletteNormal].inputunchanged = XtColorFB!(ttyRgb2Color(0xff, 0xff, 0xff), ttyRgb2Color(0x00, 0x00, 0x40));
  fuiPalette[FuiPaletteNormal].reverse = XtColorFB!(ttyRgb2Color(0xe4, 0xe4, 0xe4), ttyRgb2Color(0x5f, 0x87, 0x87)); // 254,66
  fuiPalette[FuiPaletteNormal].title = XtColorFB!(ttyRgb2Color(0xd7, 0xaf, 0x87), ttyRgb2Color(0x4e, 0x4e, 0x4e)); // 180,239
  fuiPalette[FuiPaletteNormal].disabled = XtColorFB!(ttyRgb2Color(0x94, 0x94, 0x94), ttyRgb2Color(0x4e, 0x4e, 0x4e)); // 246,239
  // hotkey
  fuiPalette[FuiPaletteNormal].hot = XtColorFB!(ttyRgb2Color(0xff, 0xaf, 0x00), ttyRgb2Color(0x4e, 0x4e, 0x4e)); // 214,239
  fuiPalette[FuiPaletteNormal].hotsel = XtColorFB!(ttyRgb2Color(0xff, 0xaf, 0x00), ttyRgb2Color(0x00, 0x5f, 0x5f)); // 214,23

  fuiPalette[FuiPaletteError] = fuiPalette[FuiPaletteNormal];
  fuiPalette[FuiPaletteError].def = XtColorFB!(ttyRgb2Color(0xff, 0xff, 0xd7), ttyRgb2Color(0x5f, 0x00, 0x00)); // 230,52
  fuiPalette[FuiPaletteError].sel = XtColorFB!(ttyRgb2Color(0xe4, 0xe4, 0xe4), ttyRgb2Color(0x00, 0x5f, 0x5f)); // 254,23
  fuiPalette[FuiPaletteError].hot = XtColorFB!(ttyRgb2Color(0xff, 0x5f, 0x5f), ttyRgb2Color(0x5f, 0x00, 0x00)); // 203,52
  fuiPalette[FuiPaletteError].hotsel = XtColorFB!(ttyRgb2Color(0xff, 0x5f, 0x5f), ttyRgb2Color(0x00, 0x5f, 0x5f)); // 203,23
  fuiPalette[FuiPaletteError].title = XtColorFB!(ttyRgb2Color(0xff, 0xff, 0x5f), ttyRgb2Color(0x5f, 0x00, 0x00)); // 227,52

  if (termType == TermType.linux) {
    fuiPalette[FuiPaletteNormal].def = XtColorFB!(ttyRgb2Color(0xd0, 0xd0, 0xd0), ttyRgb2Color(0x18, 0x18, 0xb2));
    fuiPalette[FuiPaletteNormal].title = XtColorFB!(ttyRgb2Color(0xd7, 0xaf, 0x87), ttyRgb2Color(0x18, 0x18, 0xb2));
    fuiPalette[FuiPaletteNormal].disabled = XtColorFB!(ttyRgb2Color(0x94, 0x94, 0x94), ttyRgb2Color(0x18, 0x18, 0xb2));
    fuiPalette[FuiPaletteNormal].hot = XtColorFB!(ttyRgb2Color(0xff, 0xaf, 0x00), ttyRgb2Color(0x18, 0x18, 0xb2));
  }
}


// ////////////////////////////////////////////////////////////////////////// //
public class FuiCtlLayoutProps : FuiLayoutProps {
  FuiControl ctl;
  this (FuiControl actl) { ctl = actl; }
  override void layoutingStarted () { if (ctl !is null) ctl.layoutingStarted(); }
  override void layoutingComplete () { if (ctl !is null) ctl.layoutingComplete(); }
}


// ////////////////////////////////////////////////////////////////////////// //
public class FuiControl : EventTarget {
  enum Flags : ubyte {
    None = 0,
    // UI flags
    CanBeFocused   = 1U<<0, // this item can be focused
    Disabled       = 1U<<1, // this item is dimed
    Hovered        = 1U<<2, // this item is hovered
    Active         = 1U<<3, // mouse is pressed on this
    Focused        = 1U<<4, // mouse is pressed on this
  }

  FuiPalette pal; // custom palette
  int palidx = FuiPaletteNormal;
  FuiCtlLayoutProps lp;
  ubyte flags;
  string id; // not used by the engine itself
  string caption; // use "&k" to mark hotkey
  bool defctl; // set to `true` to make this control respond to "default"
  bool escctl; // set to `true` to make this control respond to "cancel"
  bool hotkeyed; // set to `true` to make `tryHotKey()` check for hotkey in caption
  protected string[2] groupid;
  FuiHistoryManager hisman;

  void delegate (FuiControl self) onAction;
  void delegate (FuiControl self, XtWindow win) onDraw;
  void delegate (FuiControl self) onBlur;

  protected void layoutingStarted () {
    // setup groups
    //{ import iv.vfs.io; VFile("zlx.log", "a").writefln("me: %s; parent: 0x%08x", this.classinfo.name, *cast(void**)&lp.parent); }
    if (lp.parent is null) {
      FuiControl[][string][2] grp;
      forEach((FuiControl ctl) {
        ctl.lp.groupNext[] = null;
        foreach (immutable idx; 0..2) {
          if (ctl.groupid[idx].length) {
            if (auto ap = ctl.groupid[idx] in grp[idx]) (*ap) ~= ctl; else grp[idx][ctl.groupid[idx]] = [ctl];
          }
        }
        return false;
      });
      foreach (immutable gidx; 0..2) {
        foreach (FuiControl[] carr; grp[gidx].byValue) {
          foreach (immutable xidx, FuiControl c; carr) {
            if (xidx > 0) carr[xidx-1].lp.groupNext[gidx] = c.lp;
          }
        }
      }
    }
  }

  protected void layoutingComplete () {}

  this (FuiControl aparent) {
    lp = new FuiCtlLayoutProps(this);
    visible = true;
    if (aparent !is null) {
      lp.parent = aparent.lp;
      auto lcc = aparent.lp.firstChild;
      if (lcc is null) {
        // first child
        aparent.lp.firstChild = lp;
      } else {
        // non-first child
        while (lcc.nextSibling !is null) lcc = lcc.nextSibling;
        lcc.nextSibling = lp;
      }
    }
    this.connectListeners();
  }

  alias Orientation = FuiLayoutProps.Orientation;
  alias Align = FuiLayoutProps.Align;

  final @property pure nothrow @safe @nogc {
    inout(FuiControl) parent () inout { if (auto plp = cast(inout(FuiCtlLayoutProps))lp.parent) return plp.ctl; else return null; }
    inout(FuiControl) toplevel () inout { if (auto plp = cast(inout(FuiCtlLayoutProps))lp.parent) return plp.ctl.toplevel; else return this; }
    inout(FuiControl) nextSibling () inout { if (auto nlp = cast(inout(FuiCtlLayoutProps))lp.nextSibling) return nlp.ctl; else return null; }
    inout(FuiControl) firstChild () inout { if (auto flp = cast(inout(FuiCtlLayoutProps))lp.firstChild) return flp.ctl; else return null; }

    inout(FuiControl) lastChild () inout @trusted {
      if (auto fcc = cast(FuiControl)firstChild) {
        for (;;) {
          if (auto nc = fcc.nextSibling) fcc = nc; else break;
        }
        return cast(typeof(return))fcc;
      }
      return null;
    }

    alias previousSibling = prevSibling; // insanely long name
    inout(FuiControl) prevSibling () inout @trusted {
      FuiControl prev = null;
      if (auto plp = cast(inout(FuiCtlLayoutProps))lp.parent) {
        for (FuiControl cc = cast(FuiControl)plp.firstChild; cc !is null; prev = cc, cc = cc.nextSibling) {
          if (cc is this) break;
        }
      }
      return cast(typeof(return))prev;
    }

    FuiHistoryManager historymgr () {
      for (FuiControl ctl = this; ctl !is null; ctl = ctl.parent) {
        if (ctl.hisman !is null) return ctl.hisman;
      }
      return null;
    }
  }

  // ////////////////////////////////////////////////////////////////////////// //
  final uint palColor(string name) () const nothrow @trusted @nogc {
    static if (is(typeof(mixin("FuiPalette."~name)))) {
      for (auto ctl = cast(FuiControl)this; ctl !is null; ctl = ctl.parent) {
        if (auto res = mixin("ctl.pal."~name)) return res;
      }
      if (palidx >= 0 && palidx < fuiPalette.length) {
        if (auto res = mixin("fuiPalette[palidx]."~name)) return res;
      }
    }
    return XtColorFB!(7, 0);
  }


  // EventTarget interface
  override {
    // this should return parent object or null
    @property Object eventbusParent () { return parent; }
    // this will be called on sinking and bubbling
    void eventbusOnEvent (Event evt) {}
  }

  // flags accessors
  final @property pure nothrow @safe @nogc {
    bool hovered () const { pragma(inline, true); return ((flags&Flags.Hovered) != 0); }
    bool active () const { pragma(inline, true); return ((flags&Flags.Active) != 0); }
    bool focused () const { pragma(inline, true); return ((flags&Flags.Focused) != 0); }

    bool canBeFocused () const { return (lp.visible && (flags&(Flags.CanBeFocused|Flags.Disabled)) == Flags.CanBeFocused); }
    void canBeFocused (bool v) { pragma(inline, true); if (v) flags |= Flags.CanBeFocused; else flags &= ~Flags.CanBeFocused; }

    bool enabled () const { pragma(inline, true); return ((flags&Flags.Disabled) == 0); }
    void enabled (bool v) { pragma(inline, true); if (v) flags &= ~Flags.Disabled; else flags = (flags|Flags.Disabled)&~(Flags.Hovered|Flags.Active); }

    bool disabled () const { pragma(inline, true); return ((flags&Flags.Disabled) != 0); }
    void disabled (bool v) { pragma(inline, true); if (v) flags = (flags|Flags.Disabled)&~(Flags.Hovered|Flags.Active); else flags &= ~Flags.Disabled; }

    bool visible () const { pragma(inline, true); return lp.visible; }
    void visible (bool v) { pragma(inline, true); lp.visible = v; }

    bool hidden () const { pragma(inline, true); return !lp.visible; }
    void hidden (bool v) { pragma(inline, true); lp.visible = !v; }

    bool lineBreak () const { pragma(inline, true); return lp.lineBreak; }
    void lineBreak (bool v) { pragma(inline, true); lp.lineBreak = v; }

    bool ignoreSpacing () const { pragma(inline, true); return lp.ignoreSpacing; }
    void ignoreSpacing (bool v) { pragma(inline, true); lp.ignoreSpacing = v; }

    bool horizontal () const { pragma(inline, true); return (lp.orientation == lp.Orientation.Horizontal); }
    bool vertical () const { pragma(inline, true); return (lp.orientation == lp.Orientation.Vertical); }

    void horizontal (bool v) { pragma(inline, true); lp.orientation = (v ? lp.Orientation.Horizontal : lp.Orientation.Vertical); }
    void vertical (bool v) { pragma(inline, true); lp.orientation = (v ? lp.Orientation.Vertical : lp.Orientation.Horizontal); }

    Align aligning () const { pragma(inline, true); return lp.aligning; }
    void aligning (Align v) { pragma(inline, true); lp.aligning = v; }

    int flex () const { pragma(inline, true); return lp.flex; }
    void flex (int v) { pragma(inline, true); lp.flex = v; }

    int spacing () const { pragma(inline, true); return lp.spacing; }
    void spacing (int v) { pragma(inline, true); lp.spacing = v; }

    int lineSpacing () const { pragma(inline, true); return lp.lineSpacing; }
    void lineSpacing (int v) { pragma(inline, true); lp.lineSpacing = v; }

    ref inout(FuiMargin) padding () inout { pragma(inline, true); return lp.padding; }
    void padding (FuiMargin v) { pragma(inline, true); lp.padding = v; }

    ref inout(FuiSize) minSize () inout { pragma(inline, true); return lp.minSize; }
    void minSize (FuiSize v) { pragma(inline, true); lp.minSize = v; }

    ref inout(FuiSize) maxSize () inout { pragma(inline, true); return lp.maxSize; }
    void maxSize (FuiSize v) { pragma(inline, true); lp.maxSize = v; }

    // calculated item dimensions
    ref inout(FuiPoint) pos () inout { pragma(inline, true); return lp.pos; }
    void pos (FuiPoint v) { pragma(inline, true); lp.pos = v; }

    ref inout(FuiSize) size () inout { pragma(inline, true); return lp.size; }
    void size (FuiSize v) { pragma(inline, true); lp.size = v; }

    ref inout(FuiRect) rect () inout { pragma(inline, true); return lp.rect; }
    void rect (FuiRect v) { pragma(inline, true); lp.rect = v; }

    FuiPoint toGlobal (FuiPoint pt) const { return lp.toGlobal(pt); }

    protected {
      void hovered (bool v) { pragma(inline, true); if (v) flags |= Flags.Hovered; else flags &= ~Flags.Hovered; }
      void active (bool v) { pragma(inline, true); if (v) flags |= Flags.Active; else flags &= ~Flags.Active; }
      void focused (bool v) { pragma(inline, true); if (v) flags |= Flags.Focused; else flags &= ~Flags.Focused; }
    }
  }

  protected ubyte clickMask; // buttons that can be used to click this item to do some action
  protected ubyte doubleMask; // buttons that can be used to double-click this item to do some action

  final bool canAcceptClick (TtyEvent.MButton bt) {
    return
      (bt >= TtyEvent.MButton.First && bt-TtyEvent.MButton.First < 8 ?
         ((clickMask&(1<<bt-TtyEvent.MButton.First)) != 0) : false);
  }

  final void acceptClick (TtyEvent.MButton bt, bool v=true) {
    if (bt >= TtyEvent.MButton.First && bt-TtyEvent.MButton.First < 8) {
      if (v) {
        clickMask |= cast(ubyte)(1<<(bt-TtyEvent.MButton.First));
      } else {
        clickMask &= cast(ubyte)~(1<<(bt-TtyEvent.MButton.First));
      }
    }
  }

  final bool canAcceptDouble (TtyEvent.MButton bt) {
    return
      (bt >= TtyEvent.MButton.First && bt-TtyEvent.MButton.First < 8 ?
         ((doubleMask&(1<<(bt-TtyEvent.MButton.First))) != 0) : false);
  }

  final void acceptDouble (TtyEvent.MButton bt, bool v=true) {
    if (bt >= TtyEvent.MButton.First && bt-TtyEvent.MButton.First < 8) {
      if (v) {
        doubleMask |= cast(ubyte)(1<<(bt-TtyEvent.MButton.First));
      } else {
        doubleMask &= cast(ubyte)~(1<<(bt-TtyEvent.MButton.First));
      }
    }
  }

  // depth first; calls delegate for itself too
  final FuiControl forEach() (scope bool delegate (FuiControl ctl) dg) {
    if (dg is null) return null;
    FuiControl descend() (FuiControl c) {
      while (c !is null) {
        if (auto cx = descend(c.firstChild)) return cx;
        if (dg(c)) return c;
        c = c.nextSibling;
      }
      return null;
    }
    if (dg(this)) return this;
    return descend(this.firstChild);
  }

  final FuiEventQueueDesk getDesk () {
    if (auto win = cast(FuiWindow)toplevel) return win.desk;
    return null;
  }

  final FuiControl opIndex (const(char)[] id) {
    if (id.length == 0) return null;
    return forEach((FuiControl ctl) => (ctl.id == id));
  }

  final @property void hgroup (string v) { groupid[lp.Orientation.Horizontal] = v; }
  final @property void vgroup (string v) { groupid[lp.Orientation.Vertical] = v; }
  final @property string hgroup () { return groupid[lp.Orientation.Horizontal]; }
  final @property string vgroup () { return groupid[lp.Orientation.Vertical]; }

  void doAction () {
    if (onAction !is null) onAction(this);
  }

  bool tryHotKey (TtyEvent key) {
    if (!hotkeyed) return false;
    auto hotch = XtWindow.hotChar(caption).tolower;
    if (hotch == 0) return false;
    if (key.key == TtyEvent.Key.ModChar && !key.ctrl && key.alt && key.ch < 128 && tolower(cast(char)key.ch) == hotch) return true;
    if (key.key == TtyEvent.Key.Char && key.ch < 128 && tolower(cast(char)key.ch) == hotch) return true;
    return false;
  }

  protected void drawChildren (XtWindow win) {
    if (lp.firstChild is null) return;
    // setup scissoring
    auto mgb = lp.toGlobal(FuiPoint(0, 0));
    auto osc = ttyScissor;
    scope(exit) ttyScissor = osc;
    ttyScissor = ttyScissor.crop(mgb.x, mgb.y, lp.size.w, lp.size.h);
    if (!ttyScissor.visible) return;
    for (auto cc = firstChild; cc !is null; cc = cc.nextSibling) {
      if (!cc.visible) continue;
      mgb = cc.lp.toGlobal(FuiPoint(0, 0));
      cc.draw(XtWindow(mgb.x, mgb.y, cc.lp.size.w, cc.lp.size.h));
    }
  }

  // this one is without scissors; used to draw shadows
  protected void drawSelfPre (XtWindow win) {
  }

  protected void drawSelfPost (XtWindow win) {
  }

  protected void drawSelf (XtWindow win) {
    if (onDraw is null) {
      win.color = palColor!"def"();
      win.fill(0, 0, win.width, win.height);
    } else {
      onDraw(this, win);
    }
  }

  public void draw (XtWindow win) {
    if (!lp.visible) return;
    if (lp.size.w < 1 || lp.size.h < 1) return;
    // setup scissoring
    auto mgb = lp.toGlobal(FuiPoint(0, 0));
    drawSelfPre(XtWindow(mgb.x, mgb.y, lp.size.w, lp.size.h));
    auto osc = ttyScissor;
    scope(exit) ttyScissor = osc;
    ttyScissor = ttyScissor.crop(mgb.x, mgb.y, lp.size.w, lp.size.h);
    if (!ttyScissor.visible) return;
    auto csc = ttyScissor;
    drawSelf(XtWindow(mgb.x, mgb.y, lp.size.w, lp.size.h));
    ttyScissor = csc;
    drawChildren(XtWindow(mgb.x, mgb.y, lp.size.w, lp.size.h));
    ttyScissor = csc;
    drawSelfPost(XtWindow(mgb.x, mgb.y, lp.size.w, lp.size.h));
  }

  void onMyEvent (FuiEventFocus evt) { if (canBeFocused || lp.parent is null) focused = true; }
  void onMyEvent (FuiEventBlur evt) { focused = false; if (onBlur !is null) onBlur(this); }
  void onMyEvent (FuiEventActive evt) { active = true; }
  void onMyEvent (FuiEventInactive evt) { active = false; }

  /*
  void onMyEvent (FuiEventClick evt) {
    if (!canBeFocused) return;
    if (auto desk = getDesk) desk.switchFocusTo(this);
  }
  */
}


// ////////////////////////////////////////////////////////////////////////// //
class FuiEventQueue {
protected:
  Weak!FuiControl lastHover, lastFocus;
  ubyte lastButtons, lastMods;
  FuiPoint lastMouse = FuiPoint(-666, -666); // last mouse coordinates
  int[8] lastClickDelta = int.max; // how much time passed since last click with the given button was registered?
  Weak!FuiControl[8] lastClick; // on which item it was registered?
  ubyte[8] beventCount; // oooh...

public:
  this () {
    lastHover = new Weak!FuiControl();
    lastFocus = new Weak!FuiControl();
    foreach (ref lcc; lastClick) lcc = new Weak!FuiControl();
  }

  // `pt` is global
  abstract FuiControl atXY (FuiPoint pt);

  abstract void switchFocusTo (FuiControl ctl, bool allowWindowSwitch=false);

  void fixHovering () {
    auto lho = lastHover.object;
    if (lho !is null && (lho.hidden || lho.disabled)) {
      (new FuiEventLeave(lastHover.object)).post;
      lastHover.object = null;
      lho = null;
    }
    auto nh = atXY(lastMouse);
    if (nh !is null && (nh.hidden || nh.disabled)) nh = null;
    if (nh !is lho) {
      if (lho !is null) (new FuiEventLeave(lastHover.object)).post;
      lastHover.object = nh;
      if (nh !is null) (new FuiEventEnter(nh)).post;
    }
  }

  // return `false` if event wasn't processed
  bool queue (TtyEvent key) {
    if (key.key == TtyEvent.Key.None) return false;
    if (key.key == TtyEvent.Key.Error) return false;
    if (key.key == TtyEvent.Key.Unknown) return false;
    if (key.mouse) {
      // fix hovering
      auto pt = FuiPoint(key.x, key.y);
      lastMouse = pt;
      fixHovering();
      // process buttons
      if (key.button != TtyEvent.MButton.None) {
        if (key.mpress || key.mrelease) {
          newButtonState(key.button-TtyEvent.MButton.First, key.mpress);
        } else if (key.mwheel) {
          // rawtty2 workaround: send press and release
          newButtonState(key.button-TtyEvent.MButton.First, true);
          newButtonState(key.button-TtyEvent.MButton.First, false);
        }
      }
      return true;
    }
    fixHovering(); // anyway, 'cause toplevel widget can be changed
    if (auto fcs = lastFocus.object) {
      // focus events
      //if (key.focusin) { (new FuiEventFocus(fcs)).post; return true; }
      //if (key.focusout) { (new FuiEventBlur(fcs)).post; return true; }
      if (key.focusin || key.focusout) return false;
      (new FuiEventKey(fcs, key)).post;
      return true;
    }
    return false;
  }

private:
  // [0..7]
  void newButtonState (uint bidx, bool down) {
    // beventCount:
    //   0: nothing was pressed or released yet
    //   1: button was pressed for the first time
    //   2: button was released for the first time
    //   3: button was pressed for the second time
    //   4: button was released for the second time

    // reset "active" control state
    void resetActive() () {
      if (auto i = lastClick[bidx].object) {
        foreach (immutable idx, Weak!FuiControl lc; lastClick) {
          if (idx != bidx && lc.object is i) return;
        }
        (new FuiEventInactive(i)).post;
      }
    }

    void doRelease() () {
      resetActive();
      auto lp = lastHover.object;
      // did we released the button on the same control we pressed it?
      if (beventCount[bidx] == 0 || lp is null || (lp !is lastClick[bidx].object)) {
        // no, this is nothing, reset all info
        lastClick[bidx].object = null;
        beventCount[bidx] = 0;
        return;
      }
      // yep, check which kind of event this is
      if (beventCount[bidx] == 3 && (lp.doubleMask&(1<<bidx)) != 0) {
        // we accepts doubleclicks, and this can be doubleclick
        if (lastClickDelta[bidx] <= fuiDoubleTime) {
          // it comes right in time too
          if (lp.enabled) (new FuiEventDouble(lp, lp.lp.toLocal(lastMouse), cast(TtyEvent.MButton)(TtyEvent.MButton.First+bidx))).post;
          // continue registering doubleclicks
          lastClickDelta[bidx] = 0;
          beventCount[bidx] = 2;
          return;
        }
        // this is invalid doubleclick, revert to simple click
        beventCount[bidx] = 1;
        // start registering doubleclicks
        lastClickDelta[bidx] = 0;
      }
      // try single click
      if (beventCount[bidx] == 1) {
        if (lp.clickMask&(1<<bidx)) {
          if (lp.enabled) (new FuiEventClick(lp, lp.lp.toLocal(lastMouse), cast(TtyEvent.MButton)(TtyEvent.MButton.First+bidx))).post;
        }
        // start doubleclick timer
        beventCount[bidx] = ((lp.doubleMask&(1<<bidx)) != 0 ? 2 : 0);
        // start registering doubleclicks
        lastClickDelta[bidx] = 0;
        return;
      }
      // something unexpected, reset it all
      lastClick[bidx].object = null;
      beventCount[bidx] = 0;
      lastClickDelta[bidx] = lastClickDelta[0].max;
    }

    void doPress() () {
      // void?
      auto lp = lastHover.object;
      if (lp is null) {
        // reset all
        lastClick[bidx].object = null;
        beventCount[bidx] = 0;
        lastClickDelta[bidx] = lastClickDelta[0].max;
        return;
      }
      // first press?
      if (beventCount[bidx] == 0) {
        // start single
        lastClick[bidx].object = lp;
        beventCount[bidx] = 1;
        lastClickDelta[bidx] = lastClickDelta[0].max;
        // change focus
        if (lp.canBeFocused) switchFocusTo(lp);
        if ((lp.clickMask&(1<<bidx)) != 0) (new FuiEventActive(lp)).post;
        return;
      }
      // second press?
      if (beventCount[bidx] == 2) {
        // start double if control is the same
        if (lastClick[bidx].object is lp) {
          // same
          if (lastClickDelta[bidx] > fuiDoubleTime) {
            // reset double to single
            beventCount[bidx] = 1;
            lastClickDelta[bidx] = lastClickDelta[0].max;
          } else {
            beventCount[bidx] = 3;
          }
        } else {
          // other, reset to "first press"
          lastClick[bidx].object = lp;
          beventCount[bidx] = 1;
          lastClickDelta[bidx] = lastClickDelta[0].max;
        }
        // change focus
        if (lp.canBeFocused) switchFocusTo(lp);
        if (((lp.doubleMask|lp.clickMask)&(1<<bidx)) != 0) (new FuiEventActive(lp)).post;
        return;
      }
      resetActive();
      // something unexpected, reset all
      lastClick[bidx].object = null;
      beventCount[bidx] = 0;
      lastClickDelta[bidx] = lastClickDelta[0].max;
    }

    if (bidx >= lastClickDelta.length) return;
    if (down) {
      // button pressed
      if ((lastButtons&(1<<bidx)) != 0) return; // state didn't changed
      lastButtons |= cast(ubyte)(1<<bidx);
      doPress();
    } else {
      // button released
      if ((lastButtons&(1<<bidx)) == 0) return; // state didn't changed
      lastButtons &= cast(ubyte)~(1<<bidx);
      doRelease();
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
class FuiEventQueueDesk : FuiEventQueue {
  static struct WinItem {
    enum Type { Normal, Modal, Popup }
    FuiWindow win;
    Type type = Type.Normal;
    @property const pure nothrow @safe @nogc {
      bool shouldSendWindowBlurToOthers () { return (type == Type.Normal); }
      bool shouldCloseOnBlur () { return (type == Type.Popup); }
      bool canBeBlurred () { return (type == Type.Normal || type == Type.Popup); }
    }
  }
  WinItem[] winlist; // latest is on the top
  FuiWindow[] wintoplist; // "on top" windows, latest is on the top
  void delegate (FuiEventQueueDesk desk) drawDesk; // draw desktop background

  final bool isOnTopWindow (FuiControl ctl) {
    if (ctl is null) return false;
    ctl = ctl.toplevel;
    foreach_reverse (FuiControl w; wintoplist) if (w is ctl) return true;
    return false;
  }

  final bool isNormalWindow (FuiControl ctl) {
    if (ctl is null) return false;
    ctl = ctl.toplevel;
    foreach_reverse (ref WinItem w; winlist) if (w.win is ctl) return true;
    return false;
  }

  // normal top-level window
  final bool isTopWindow (FuiControl ctl) {
    if (ctl is null || winlist.length == 0) return false;
    return (ctl.toplevel is winlist[$-1].win);
  }

  // `pt` is global
  override FuiControl atXY (FuiPoint pt) {
    static FuiControl descend (FuiControl ctl, FuiPoint pt) {
      FuiControl lasthit = null;
      if (ctl !is null && ctl.lp.visible) {
        pt -= ctl.lp.pos;
        if (pt.x >= 0 && pt.y >= 0 && pt.x < ctl.lp.size.w && pt.y < ctl.lp.size.h) {
          lasthit = ctl;
          for (auto cx = ctl.firstChild; cx !is null; cx = cx.nextSibling) {
            if (!cx.visible) continue;
            auto ht = descend(cx, pt);
            if (ht !is null) lasthit = ht;
          }
        }
      }
      return lasthit;
    }
    auto lp = lastFocus.object;
    if (lp !is null) return descend(lp.toplevel, pt);
    // check ontop windows
    foreach_reverse (FuiWindow tw; wintoplist) {
      if (auto cc = descend(tw, pt)) return cc;
    }
    // check normal top-level window
    if (winlist.length) return descend(winlist[$-1].win, pt);
    return null;
  }

  // pwi.win can be null, but should not be current top-level
  // pwi is "previous active window"
  private void topwindowFocusJustChanged (WinItem pwi=WinItem.init) {
    if (winlist.length && pwi.win is winlist[$-1].win) return; // just in case
    // send blur event to pwi.win
    if (pwi.win !is null) {
      auto fcs = lastFocus.object;
      if (fcs !is null && fcs.toplevel is pwi.win) {
        lastFocus.object = null;
        if (fcs !is pwi.win) (new FuiEventBlur(fcs)).post;
        if (winlist.length == 0 || winlist[$-1].shouldSendWindowBlurToOthers) {
          if (pwi.shouldCloseOnBlur) (new FuiEventClose(pwi.win, null)).post; else (new FuiEventBlur(pwi.win)).post;
        }
      }
    }
    // just in case: another blur attempt
    if (auto fcs = lastFocus.object) {
      if (fcs !is null && (winlist.length == 0 || fcs.toplevel !is winlist[$-1].win)) {
        lastFocus.object = null;
        if (fcs !is fcs.toplevel) (new FuiEventBlur(fcs)).post;
        if (winlist.length == 0 || winlist[$-1].shouldSendWindowBlurToOthers) {
          auto tl = fcs.toplevel;
          foreach (ref WinItem wi; winlist) {
            if (wi.win is tl) {
              if (wi.shouldCloseOnBlur) (new FuiEventClose(wi.win, null)).post; else (new FuiEventBlur(wi.win)).post;
              break;
            }
          }
        }
      }
    }
    // old active window is blurred, focus new one
    if (winlist.length == 0) return;
    auto w = winlist[$-1].win;
    assert(w !is null);
    (new FuiEventFocus(w)).post;
    if (w.lastfct is null) w.lastfct = w.findFirstToFocus;
    lastFocus.object = (w.lastfct is null ? w : w.lastfct);
    if (auto fcs = lastFocus.object) (new FuiEventFocus(fcs)).post;
  }

  override void switchFocusTo (FuiControl ctl, bool allowWindowSwitch=false) {
    if (ctl is null) return;
    if (!ctl.canBeFocused) return;
    if (auto ww = cast(FuiWindow)ctl.toplevel) {
      if (ww.desk !is this) return;
    } else {
      return;
    }
    // fix focus
    auto ofc = lastFocus.object;
    if (ofc is ctl) return;
    if (auto win = cast(FuiWindow)ctl.toplevel) {
      if (win.desk !is this) return;
      if (!isTopWindow(win)) {
        if (!allowWindowSwitch) return;
        if (winlist.length && !winlist[$-1].canBeBlurred) return;
      }
    } else {
      // alas
      return;
    }
    // remove focus from current focused ctl
    if (ofc !is null) {
      lastFocus.object = null;
      (new FuiEventBlur(ofc)).post;
      ofc = null;
    }
    bool winFocusSent = false;
    // check if we should bring another window to top
    auto tl = ctl.toplevel;
    if (!isTopWindow(tl) && !isOnTopWindow(tl)) {
      foreach_reverse (immutable idx, ref WinItem wi; winlist) {
        auto w = wi.win;
        if (idx == winlist.length-1) continue;
        if (w is tl) {
          winFocusSent = true;
          if (winlist[$-1].shouldCloseOnBlur) {
            (new FuiEventClose(winlist[$-1].win, null)).post;
          } else {
            (new FuiEventBlur(winlist[$-1].win)).post;
          }
          (new FuiEventFocus(w)).post;
          auto xwi = wi;
          foreach (immutable c; idx+1..winlist.length) winlist[c-1] = winlist[c];
          winlist[$-1] = xwi;
          break;
        }
      }
    }
    // focus new control
    if (auto w = cast(FuiWindow)tl) {
      w.lastfct = (ctl !is tl ? ctl : null);
      if (w.lastfct is null) w.lastfct = w.findFirstToFocus();
      if (w.lastfct !is null) ctl = w.lastfct;
    } else {
      assert(0);
    }
    lastFocus.object = ctl;
    if (winFocusSent && ctl is tl) return;
    (new FuiEventFocus(ctl)).post;
  }

  this () {
    this.connectListeners();
    super();
  }

  protected void addWindowWithType (FuiWindow w, WinItem.Type type) {
    if (w is null) return;
    if (w.desk !is null) return;
    w.desk = this;
    winlist ~= WinItem(w, type);
    topwindowFocusJustChanged();
    assert(lastFocus.object !is null);
  }

  void addWindow (FuiWindow w) { addWindowWithType(w, WinItem.Type.Normal); }
  void addModal (FuiWindow w) { addWindowWithType(w, WinItem.Type.Modal); }
  void addPopup (FuiWindow w) { addWindowWithType(w, WinItem.Type.Popup); }

  override bool queue (TtyEvent key) {
    // check if we clicked on another window and activate it
    // but only if current top window can be blurred (i.e. deactivated) this way
    if (key.mpress && winlist.length && winlist[$-1].canBeBlurred) {
      auto pt = FuiPoint(key.x, key.y);
      // if top window is popup, and user clicked outside of it, close it
      if (winlist.length && winlist[$-1].type == WinItem.Type.Popup && !pt.inside(winlist[$-1].win.rect)) {
        (new FuiEventClose(winlist[$-1].win, null)).post;
      } else if (winlist.length && winlist[$-1].type == WinItem.Type.Modal && !pt.inside(winlist[$-1].win.rect)) {
        // do nothing, as modal window cannot be dismissed this way
      } else if (winlist.length > 1 && !pt.inside(winlist[$-1].win.rect)) {
        foreach_reverse (immutable idx, ref WinItem wi; winlist[0..$-1]) {
          auto w = wi.win;
          if (w.hidden || w.disabled) continue;
          if (pt.inside(w.lp.rect)) {
            auto lastWF = winlist[$-1];
            auto xwi = wi;
            foreach (immutable c; idx+1..winlist.length) winlist[c-1] = winlist[c];
            winlist[$-1] = xwi;
            topwindowFocusJustChanged(lastWF);
            break;
          }
        }
      }
    }
    return super.queue(key);
  }

  void draw () {
    if (drawDesk is null) {
      XtWindow win = XtWindow.fullscreen;
      //win.color = XtColorFB!(7, 0);
      win.color = XtColorFB!(TtyRgb2Color!(0x00, 0x00, 0x00), TtyRgb2Color!(0x00, 0x5f, 0xaf));
      win.fill!true(0, 0, win.width, win.height, 'a');
    } else {
      drawDesk(this);
    }
    foreach (ref WinItem wi; winlist) wi.win.draw(XtWindow(wi.win.lp.pos.x, wi.win.lp.pos.y, wi.win.lp.size.w, wi.win.lp.size.h));
    foreach (FuiWindow w; wintoplist) w.draw(XtWindow(w.lp.pos.x, w.lp.pos.y, w.lp.size.w, w.lp.size.h));
  }

  void onEvent (FuiEventClose evt) {
    if (evt.source is null) return;
    if (auto ww = cast(FuiWindow)evt.source) {
      if (ww.desk !is this) return;
    } else {
      return;
    }
    // reverse usually faster
    foreach_reverse (immutable idx, ref WinItem twi; winlist) {
      FuiWindow tw = twi.win;
      if (evt.source is tw) {
        // i found her!
        auto lastWF = (idx == winlist.length-1 ? twi : WinItem.init);
        foreach (immutable c; idx+1..winlist.length) winlist[c-1] = winlist[c];
        winlist[$-1] = WinItem.init;
        winlist.length -= 1;
        winlist.assumeSafeAppend;
        if (lastWF.win !is null) { topwindowFocusJustChanged(lastWF); lastWF.win.desk = null; }
        tw.desk = null;
        if (winlist.length == 0 && wintoplist.length == 0) (new FuiEventQuit).post;
        return;
      }
    }
    foreach_reverse (immutable idx, FuiWindow tw; wintoplist) {
      if (evt.source is tw) {
        // i found her!
        foreach (immutable c; idx+1..wintoplist.length) wintoplist[c-1] = wintoplist[c];
        wintoplist[$-1] = null;
        wintoplist.length -= 1;
        wintoplist.assumeSafeAppend;
        if (auto fcs = lastFocus.object) {
          if (fcs.toplevel is tw) topwindowFocusJustChanged();
        }
        tw.desk = null;
        if (winlist.length == 0 && wintoplist.length == 0) (new FuiEventQuit).post;
        return;
      }
    }
    if (winlist.length == 0 && wintoplist.length == 0) (new FuiEventQuit).post;
  }

  void onEvent (FuiEventWinFocusPrev evt) {
    if (auto win = evt.sourcewin) {
      if (win.desk !is this) return;
      auto nfc = win.findPrevToFocus();
      if (nfc is null) nfc = win.findLastToFocus();
      if (nfc !is null) switchFocusTo(nfc);
    }
  }

  void onEvent (FuiEventWinFocusNext evt) {
    if (auto win = evt.sourcewin) {
      if (win.desk !is this) return;
      auto nfc = win.findNextToFocus();
      if (nfc is null) nfc = win.findFirstToFocus();
      if (nfc !is null) switchFocusTo(nfc);
    }
  }
}


__gshared FuiEventQueueDesk tuidesk;

shared static this () {
  tuidesk = new FuiEventQueueDesk();
}

shared static ~this () {
  tuidesk = null;
}
