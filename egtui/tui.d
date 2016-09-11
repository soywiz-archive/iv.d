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
module iv.egtui.tui;

import iv.strex;
import iv.rawtty2;

import iv.egtui.editor;
import iv.egtui.parser;
import iv.egtui.tty;
import iv.egtui.types;
import iv.egtui.utils;

//version = fui_many_asserts;


// ////////////////////////////////////////////////////////////////////////// //
__gshared ushort fuiDoubleTime = 250; // 250 msecs to register doubleclick


// ////////////////////////////////////////////////////////////////////////// //
align(1) struct FuiPoint {
align(1):
  int x, y;
@property pure nothrow @safe @nogc:
  bool inside (in FuiRect rc) const { pragma(inline, true); return (x >= rc.pos.x && y >= rc.pos.y && x < rc.pos.x+rc.size.w && y < rc.pos.y+rc.size.h); }
}
align(1) struct FuiSize { align(1): int w, h; }
align(1) struct FuiRect {
align(1):
  FuiPoint pos;
  FuiSize size;
@property pure nothrow @safe @nogc:
  int x () const { pragma(inline, true); return pos.x; }
  int y () const { pragma(inline, true); return pos.y; }
  int w () const { pragma(inline, true); return size.w; }
  int h () const { pragma(inline, true); return size.h; }
  void x (int v) { pragma(inline, true); pos.x = v; }
  void y (int v) { pragma(inline, true); pos.y = v; }
  void w (int v) { pragma(inline, true); size.w = v; }
  void h (int v) { pragma(inline, true); size.h = v; }

  ref int xp () { pragma(inline, true); return pos.x; }
  ref int yp () { pragma(inline, true); return pos.y; }
  ref int wp () { pragma(inline, true); return size.w; }
  ref int hp () { pragma(inline, true); return size.h; }

  bool inside (in FuiPoint pt) const { pragma(inline, true); return (pt.x >= pos.x && pt.y >= pos.y && pt.x < pos.x+size.w && pt.y < pos.y+size.h); }
}
align(1) struct FuiMargin { align(1): int left, top, right, bottom; }


// ////////////////////////////////////////////////////////////////////////// //
// pporperties for layouter
public align(1) struct FuiLayoutProps {
align(1):
  enum Orientation {
    Horizontal,
    Vertical,
  }

  // "NPD" means "non-packing direction"
  enum Align {
    Center, // the available space is divided evenly
    Start, // the NPD edge of each box is placed along the NPD of the parent box
    End, // the opposite-NPD edge of each box is placed along the opposite-NPD of the parent box
    Stretch, // the NPD-size of each boxes is adjusted to fill the parent box
  }

  // flags accessors
  @property pure nothrow @safe @nogc {
    bool hovered () const { pragma(inline, true); return ((flags&Flags.Hovered) != 0); }
    bool active () const { pragma(inline, true); return ((flags&Flags.Active) != 0); }

    bool canBeFocused () const { pragma(inline, true); return ((flags&Flags.CanBeFocused) != 0); }
    void canBeFocused (bool v) { pragma(inline, true); if (v) flags |= Flags.CanBeFocused; else flags &= ~Flags.CanBeFocused; }

    bool enabled () const { pragma(inline, true); return ((flags&Flags.Disabled) == 0); }
    void enabled (bool v) { pragma(inline, true); if (v) flags &= ~Flags.Disabled; else flags = (flags|Flags.Disabled)&~(Flags.Hovered|Flags.Active); }

    bool disabled () const { pragma(inline, true); return ((flags&Flags.Disabled) != 0); }
    void disabled (bool v) { pragma(inline, true); if (v) flags = (flags|Flags.Disabled)&~(Flags.Hovered|Flags.Active); else flags &= ~Flags.Disabled; }

    bool visible () const { pragma(inline, true); return ((flags&Flags.Invisible) == 0); }
    void visible (bool v) { pragma(inline, true); if (v) flags &= ~Flags.Invisible; else flags = (flags|Flags.Invisible)&~(Flags.Hovered|Flags.Active); }

    bool hidden () const { pragma(inline, true); return ((flags&Flags.Invisible) != 0); }
    void hidden (bool v) { pragma(inline, true); if (v) flags = (flags|Flags.Invisible)&~(Flags.Hovered|Flags.Active); else flags &= ~Flags.Invisible; }

    bool lineBreak () const { pragma(inline, true); return ((flags&Flags.LineBreak) != 0); }
    void lineBreak (bool v) { pragma(inline, true); if (v) flags |= Flags.LineBreak; else flags &= ~Flags.LineBreak; }

    bool wantTab () const { pragma(inline, true); return ((flags&Flags.WantTab) != 0); }
    void wantTab (bool v) { pragma(inline, true); if (v) flags |= Flags.WantTab; else flags &= ~Flags.WantTab; }

    bool wantReturn () const { pragma(inline, true); return ((flags&Flags.WantReturn) != 0); }
    void wantReturn (bool v) { pragma(inline, true); if (v) flags |= Flags.WantReturn; else flags &= ~Flags.WantReturn; }

    ushort userFlags () const { pragma(inline, true); return (flags&Flags.UserFlagsMask); }
    void userFlags (ushort v) { pragma(inline, true); flags = (flags&~Flags.UserFlagsMask)|v; }
  }

  // WARNING! don't change this fields from user code!
  FuiRect position; // calculated item position
  int itemid = -1;
  int parent = -1; // item parent
  int firstChild = -1;
  int lastChild = -1;
  int prevSibling = -1;
  int nextSibling = -1;

  Orientation orientation = Orientation.Horizontal; // box orientation
  Align aligning = Align.Start; // NPD for children
  int flex = 1; // default flex value

  @property pure nothrow @safe @nogc {
    bool horizontal () const { pragma(inline, true); return (orientation == Orientation.Horizontal); }
    bool vertical () const { pragma(inline, true); return (orientation == Orientation.Vertical); }

    void horizontal (bool v) { pragma(inline, true); orientation = (v ? Orientation.Horizontal : Orientation.Vertical); }
    void vertical (bool v) { pragma(inline, true); orientation = (v ? Orientation.Vertical : Orientation.Horizontal); }
  }

  FuiSize minSize;
  FuiSize maxSize = FuiSize(int.max-1024, int.max-1024); // arbitrary limit, you know
  FuiMargin padding;
  int spacing; // spacing for children
  int lineSpacing; // line spacing for horizontal boxes

  enum Buttons : ubyte {
    None      = 0,
    Left      = 0x01,
    Right     = 0x02,
    Middle    = 0x04,
    WheelUp   = 0x08,
    WheelDown = 0x10,
  }

  enum Button : ubyte {
    Left,
    Right,
    Middle,
    WheelUp,
    WheelDown,
  }

  ubyte clickMask; // buttons that can be used to click this item to do some action
  ubyte doubleMask; // buttons that can be used to double-click this item to do some action

  @property void hgroup (int parent) nothrow @safe @nogc { setGroup(Group.H, parent); }
  @property void vgroup (int parent) nothrow @safe @nogc { setGroup(Group.V, parent); }

private:
  enum Flags : uint {
    None = 0,
    UserFlagsMask  = 0xffffu,
    // UI flags
    Disabled       = 0x0001_0000u, // this item is dimed
    LineBreak      = 0x0002_0000u, // layouter should start a new line after this item
    Invisible      = 0x0004_0000u, // this item is used purely for layouting purposes
    Hovered        = 0x0008_0000u, // this item is hovered
    CanBeFocused   = 0x0010_0000u, // this item can be focused
    Active         = 0x0020_0000u, // mouse is pressed on this
    WantTab        = 0x0040_0000u, // want to receive tab key events
    WantReturn     = 0x0080_0000u, // want to receive return key events
    // internal flags for layouter
    TempLineBreak  = 0x1000_0000u,
    TouchedByGroup = 0x2000_0000u,
    LayouterFlagsMask =
      TempLineBreak|
      TouchedByGroup|
      0,
  }

  enum Group { H = 0, V = 1 }

  uint flags = Flags.None; // see Flags
  // "mark counter" for groups; also, bit 31 set means "group head"
  int[2] groupNext = -1; // next group head
  int[2] groupSibling = -1; // next item in this hgroup; not -1 and bit 31 set: head
  FuiContextImpl* ctx;

  void setGroup (int grp, int parent) nothrow @trusted @nogc {
    if (ctx is null || itemid < 0 || parent == itemid || grp < 0 || grp > 1) return;
    auto lp = ctx.layprops(parent);
    if (lp is null) return; //assert(0, "invalid parent for group");
    if (lp.groupSibling.ptr[grp] == -1) {
      // first item in new group
      lp.groupSibling.ptr[grp] = itemid|0x8000_0000;
    } else {
      // append to group
      auto it = lp.groupSibling.ptr[grp]&0x7fff_ffff;
      version(fui_many_asserts) assert(it != 0x7fff_ffff);
      for (;;) {
        auto clp = ctx.layprops(it);
        version(fui_many_asserts) assert(clp !is null);
        if (clp.groupSibling.ptr[grp] == -1) {
          clp.groupSibling.ptr[grp] = itemid;
          return;
        }
        it = clp.groupSibling.ptr[grp];
      }
    }
  }

  @property pure nothrow @safe @nogc {
    void resetLayouterFlags () { pragma(inline, true); flags &= ~Flags.LayouterFlagsMask; }

    bool tempLineBreak () const { pragma(inline, true); return ((flags&Flags.TempLineBreak) != 0); }
    void tempLineBreak (bool v) { pragma(inline, true); if (v) flags |= Flags.TempLineBreak; else flags &= ~Flags.TempLineBreak; }

    bool touchedByGroup () const { pragma(inline, true); return ((flags&Flags.TouchedByGroup) != 0); }
    void touchedByGroup (bool v) { pragma(inline, true); if (v) flags |= Flags.TouchedByGroup; else flags &= ~Flags.TouchedByGroup; }

    // this is strictly internal thing
    void hovered (bool v) { pragma(inline, true); if (v) flags |= Flags.Hovered; else flags &= ~Flags.Hovered; }
    void active (bool v) { pragma(inline, true); if (v) flags |= Flags.Active; else flags &= ~Flags.Active; }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
public static struct FuiEvent {
  enum Type {
    None, // just in case
    Char, // param0: dchar; param1: mods&buttons
    Key, // paramkey: key
    Click, // mouse click; param0: buttton index; param1: mods&buttons
    Double, // mouse double-click; param0: buttton index; param1: mods&buttons
    Close, // close dialog with param0 as result
  }

  Type type;
  int item;
  union {
    struct {
      uint param0;
      uint param1;
      uint param2; // coordinates *inside* item
    }
    TtyKey paramkey;
  }

@property pure nothrow @safe @nogc:
  ref TtyKey keyp () { pragma(inline, true); return paramkey; }

@property const pure nothrow @safe @nogc:
  ubyte mods () { pragma(inline, true); return cast(ubyte)(param1>>8); }
  ubyte buts () { pragma(inline, true); return cast(ubyte)param1; }

  TtyKey key () { pragma(inline, true); return paramkey; }
  dchar ch () { pragma(inline, true); return cast(dchar)param0; }
  ubyte bidx () { pragma(inline, true); return cast(ubyte)param0; }
  short x () { pragma(inline, true); return cast(short)(param2&0xffff); }
  short y () { pragma(inline, true); return cast(short)((param2>>16)&0xffff); }
}


// ////////////////////////////////////////////////////////////////////////// //
// all controls lives here! ;-)
private struct FuiContextImpl {
private:
  enum MaxQueuedEvents = 16;
  enum MaxQueuedExternalEvents = 64;

private:
  uint rc = 1; // refcount
  ubyte* pmem; // private memory: this holds controls
  uint pmemused;
  uint pmemsize;
  uint* pidx; // this will hold offset of each item in `pmem`
  uint pidxsize; // in elements
  int pcount; // number of controls in this context
  int focusedId = -1; // what item is focused (i.e. will receive keyboard events)?
  int lastHover = -1; // for speed
  ubyte lastButtons, lastMods;
  FuiPoint lastMouse = FuiPoint(-1, -1); // last mouse coordinates
  short[8] lastClickDelta = short.max; // how much time passed since last click with the given button was registered?
  int[8] lastClick = -1; // on which item it was registered?
  ubyte[8] beventCount; // oooh...
  FuiEvent[MaxQueuedEvents] events;
  uint eventHead, eventPos;
  FuiSize mMaxDimensions;

public:
  // return id or -1
  // contrary to what you may think, `id` itself will be checked too
  int findNextEx (int id, scope bool delegate (int id) check) {
    if (id == -1) id = 0;
    for (;;) {
      auto lp = layprops(id);
      if (lp is null) return -1;
      if (lp.firstChild != -1) {
        // has children, descent
        id = lp.firstChild;
        continue;
      }
      // no children, check ourself
      if (check(id)) return id;
      // go to next sibling
      for (;;) {
        if (lp.nextSibling != -1) { id = lp.nextSibling; break; }
        // no sibling, bubble and get next sibling
        id = lp.parent;
        lp = layprops(id);
        if (lp is null) return -1;
      }
    }
  }

nothrow @nogc:
private:
  void queueEvent (int aitem, FuiEvent.Type atype, uint aparam0=0, uint aparam1=0, uint aparam2=0) nothrow @trusted @nogc {
    if (eventPos >= events.length) return;
    auto nn = (eventHead+eventPos++)%events.length;
    with (events.ptr[nn]) {
      type = atype;
      item = aitem;
      param0 = aparam0;
      param1 = aparam1;
      param2 = aparam2;
    }
  }

  void queueEvent (int aitem, FuiEvent.Type atype, TtyKey akey) nothrow @trusted @nogc {
    if (eventPos >= events.length) return;
    auto nn = (eventHead+eventPos++)%events.length;
    with (events.ptr[nn]) {
      type = atype;
      item = aitem;
      paramkey = akey;
    }
  }

  bool hasEvents () const pure nothrow @safe @nogc { pragma(inline, true); return (eventPos > 0); }

  FuiEvent getEvent () nothrow @trusted @nogc {
    if (eventPos > 0) {
      auto nn = eventHead;
      eventHead = (eventHead+1)%events.length;
      --eventPos;
      return events.ptr[nn];
    } else {
      return FuiEvent.init;
    }
  }

  // pt is inside item
  FuiPoint toGlobal (int item, FuiPoint pt) {
    while (item >= 0) {
      if (auto lp = layprops(item)) {
        pt.x += lp.position.x;
        pt.y += lp.position.y;
        if (item == 0) break;
        item = lp.parent;
      }
    }
    return pt;
  }

  uint mouseXY (int item) {
    auto pt = toGlobal(item, FuiPoint(0, 0));
    pt = FuiPoint(lastMouse.x-pt.x, lastMouse.y-pt.y);
    if (pt.x < short.min) pt.x = short.min;
    if (pt.x > short.max) pt.x = short.max;
    if (pt.y < short.min) pt.y = short.min;
    if (pt.y > short.max) pt.y = short.max;
    return cast(uint)(((pt.y&0xffff)<<16)|(pt.x&0xffff));
  }

  // [0..7]
  void newButtonState (uint bidx, bool down) {
    // 0: nothing was pressed or released yet
    // 1: button was pressed for the first time
    // 2: button was released for the first time
    // 3: button was pressed for the second time
    // 4: button was released for the second time

    //debug(fui_mouse) { import core.stdc.stdio : printf; printf("NBS: bidx=%u; down=%d\n", bidx, cast(int)down); }

    void resetActive() () {
      auto i = lastClick.ptr[bidx];
      if (i == -1) return;
      foreach (immutable idx, int lc; lastClick) {
        if (idx != bidx && lc == i) return;
      }
      layprops(i).active = false;
    }

    void doRelease() () {
      resetActive();
      // did we released the button on the same control we pressed it?
      if (beventCount.ptr[bidx] == 0 || lastHover == -1 || (lastHover != lastClick.ptr[bidx])) {
        debug(fui_mouse) { import core.stdc.stdio : printf; printf("button #%u released x00: lastHover=%d; lastClick=%d; ec=%u\n", bidx, lastHover, lastClick.ptr[bidx], cast(uint)beventCount.ptr[bidx]); }
        // no, this is nothing, reset all info
        lastClick.ptr[bidx] = -1;
        beventCount.ptr[bidx] = 0;
        return;
      }
      auto lp = layprops(lastHover);
      // yep, check which kind of event this is
      if (beventCount.ptr[bidx] == 3 && (lp.doubleMask&(1<<bidx)) != 0) {
        debug(fui_mouse) { import core.stdc.stdio : printf; printf("button #%u possible double: lastHover=%d; lastClick=%d; ec=%u; ltt=%d\n", bidx, lastHover, lastClick.ptr[bidx], cast(uint)beventCount.ptr[bidx], lastClickDelta.ptr[bidx]); }
        // we accepts doubleclicks, and this can be doubleclick
        if (lastClickDelta.ptr[bidx] <= fuiDoubleTime) {
          debug(fui_mouse) { import core.stdc.stdio : printf; printf("  DOUBLE!\n"); }
          // it comes right in time too
          queueEvent(lastHover, FuiEvent.Type.Double, bidx, lastButtons|(lastMods<<8), mouseXY(lastHover));
          // continue registering doubleclicks
          lastClickDelta.ptr[bidx] = 0;
          beventCount.ptr[bidx] = 2;
          return;
        }
        debug(fui_mouse) { import core.stdc.stdio : printf; printf("  not double\n"); }
        // this is invalid doubleclick, revert to simple click
        beventCount.ptr[bidx] = 1;
        // start registering doubleclicks
        lastClickDelta.ptr[bidx] = 0;
      }
      debug(fui_mouse) { import core.stdc.stdio : printf; printf("button #%u possible single: lastHover=%d; lastClick=%d; ec=%u\n", bidx, lastHover, lastClick.ptr[bidx], cast(uint)beventCount.ptr[bidx]); }
      // try single click
      if (beventCount.ptr[bidx] == 1) {
        debug(fui_mouse) { import core.stdc.stdio : printf; printf("  SINGLE\n"); }
        if (lp.clickMask&(1<<bidx)) queueEvent(lastHover, FuiEvent.Type.Click, bidx, lastButtons|(lastMods<<8), mouseXY(lastHover));
        // start doubleclick timer
        beventCount.ptr[bidx] = 2;
        // start registering doubleclicks
        lastClickDelta.ptr[bidx] = 0;
        return;
      }
      debug(fui_mouse) { import core.stdc.stdio : printf; printf("  UNEXPECTED\n"); }
      // something unexpected, reset it all
      lastClick.ptr[bidx] = -1;
      beventCount.ptr[bidx] = 0;
      lastClickDelta.ptr[bidx] = lastClickDelta[0].max;
    }

    void doPress() () {
      // void?
      if (lastHover == -1) {
        // reset all
        debug(fui_mouse) { import core.stdc.stdio : printf; printf("button #%u pressed at nowhere\n", bidx); }
        lastClick.ptr[bidx] = -1;
        beventCount.ptr[bidx] = 0;
        lastClickDelta.ptr[bidx] = lastClickDelta[0].max;
        return;
      }
      // first press?
      if (beventCount.ptr[bidx] == 0) {
        debug(fui_mouse) { import core.stdc.stdio : printf; printf("button #%u first press: lastHover=%d; lastClick=%d; ec=%u\n", bidx, lastHover, lastClick.ptr[bidx], cast(uint)beventCount.ptr[bidx]); }
        // start single
        lastClick.ptr[bidx] = lastHover;
        beventCount.ptr[bidx] = 1;
        lastClickDelta.ptr[bidx] = lastClickDelta[0].max;
        auto lp = layprops(lastHover);
        version(fui_many_asserts) assert(lp !is null);
        if (lp.canBeFocused) focused = lastHover;
        if ((lp.clickMask&(1<<bidx)) != 0) lp.active = true;
        return;
      }
      // second press?
      if (beventCount.ptr[bidx] == 2) {
        debug(fui_mouse) { import core.stdc.stdio : printf; printf("button #%u second press: lastHover=%d; lastClick=%d; ec=%u\n", bidx, lastHover, lastClick.ptr[bidx], cast(uint)beventCount.ptr[bidx]); }
        //bool asDouble = false;
        // start double if control is the same
        if (lastClick.ptr[bidx] == lastHover) {
          debug(fui_mouse) { import core.stdc.stdio : printf; printf("  SAME\n"); }
          // same
          if (lastClickDelta.ptr[bidx] > fuiDoubleTime) {
            // reset double to single
            beventCount.ptr[bidx] = 1;
            lastClickDelta.ptr[bidx] = lastClickDelta[0].max;
          } else {
            //asDouble = true;
            beventCount.ptr[bidx] = 3;
            //lastClickDelta.ptr[bidx] = 0;
          }
        } else {
          debug(fui_mouse) { import core.stdc.stdio : printf; printf("  OTHER\n"); }
          // other, reset to "first press"
          lastClick.ptr[bidx] = lastHover;
          beventCount.ptr[bidx] = 1;
          lastClickDelta.ptr[bidx] = lastClickDelta[0].max;
        }
        auto lp = layprops(lastHover);
        version(fui_many_asserts) assert(lp !is null);
        if (lp.canBeFocused) focused = lastHover;
        if (((lp.doubleMask|lp.clickMask)&(1<<bidx)) != 0) lp.active = true;
        return;
      }
      debug(fui_mouse) { import core.stdc.stdio : printf; printf("button #%u unexpected press: lastHover=%d; lastClick=%d; ec=%u\n", bidx, lastHover, lastClick.ptr[bidx], cast(uint)beventCount.ptr[bidx]); }
      resetActive();
      // something unexpected, reset all
      lastClick.ptr[bidx] = -1;
      beventCount.ptr[bidx] = 0;
      lastClickDelta.ptr[bidx] = lastClickDelta[0].max;
    }

    if (bidx >= lastClickDelta.length) return;
    if (down) {
      // button pressed
      if ((lastButtons&(1<<bidx)) != 0) return; // state didn't changed
      lastButtons |= cast(ubyte)(1<<bidx);
      debug(fui_mouse) { import core.stdc.stdio : printf; printf("DOWN: bidx=%u; buts=0x%02x\n", bidx, lastButtons); }
      doPress();
    } else {
      // button released
      if ((lastButtons&(1<<bidx)) == 0) return; // state didn't changed
      lastButtons &= cast(ubyte)~(1<<bidx);
      debug(fui_mouse) { import core.stdc.stdio : printf; printf("UP  : bidx=%u; buts=0x%02x\n", bidx, lastButtons); }
      doRelease();
    }
  }

  // external actions
  void mouseAt (in FuiPoint pt) {
    if (lastMouse != pt) {
      lastMouse = pt;
      auto nh = itemAt(pt);
      if (nh != lastHover) {
        if (auto lp = layprops(lastHover)) lp.hovered = false;
        if (auto lp = layprops(nh)) { if (lp.enabled) lp.hovered = true; else nh = -1; } else nh = -1;
        lastHover = nh;
      }
    }
  }

  private import core.time;
  private MonoTime lastUpdateTime;
  private bool updateWasCalled;

  static struct ExternalEvent {
    enum Type { Key, Char, Mouse }
    Type type;
    TtyKey kev;
    //MouseEvent mev;
    dchar cev;
  }
  private ExternalEvent[MaxQueuedExternalEvents] extEvents;
  uint extevHead, extevPos;

  void keyboardEvent (TtyKey ev) nothrow @trusted @nogc {
    if (extevPos >= extEvents.length) return;
    if (ev.key == TtyKey.Key.None) return;
    auto nn = (extevHead+extevPos++)%extEvents.length;
    if (ev.key == TtyKey.Key.Char) {
      with (extEvents.ptr[nn]) { type = ExternalEvent.Type.Char; cev = ev.ch; }
    } else if (ev.mouse) {
      with (extEvents.ptr[nn]) { type = ExternalEvent.Type.Mouse; kev = ev; }
    } else {
      with (extEvents.ptr[nn]) { type = ExternalEvent.Type.Key; kev = ev; }
    }
  }

  void charEvent (dchar ch) nothrow @trusted @nogc {
    if (extevPos >= extEvents.length || ch == 0 || ch > dchar.max) return;
    auto nn = (extevHead+extevPos++)%extEvents.length;
    with (extEvents.ptr[nn]) { type = ExternalEvent.Type.Char; cev = ch; }
  }

  /*
  void mouseEvent (MouseEvent ev) nothrow @trusted @nogc {
    if (extevPos >= extEvents.length) return;
    auto nn = (extevHead+extevPos++)%extEvents.length;
    with (extEvents.ptr[nn]) { type = ExternalEvent.Type.Mouse; mev = ev; }
  }
  */

  //FIXME: write `findPrev()`!
  void focusPrev () {
    int prevIt = -1;
    auto lfc = layprops(focused);
    if (lfc !is null) {
      findNext(-1, (int item) {
        if (auto lc = layprops(item)) {
          if (item == focused) return true;
          if (lc.canBeFocused && lc.visible && !lc.disabled) prevIt = item;
        }
        return false;
      });
    }
    if (prevIt == -1) {
      findNext(-1, (int item) {
        if (auto lc = layprops(item)) {
          if (lc.canBeFocused && lc.visible && !lc.disabled) prevIt = item;
        }
        return false;
      });
    }
    focused = prevIt;
  }

  void focusNext () {
    auto lfc = layprops(focused);
    if (lfc is null) {
      focused = findNext(0, (int item) {
        if (auto lc = layprops(item)) return (lc.canBeFocused && lc.visible && !lc.disabled);
        return false;
      });
    } else if (!lfc.wantTab || lfc.disabled) {
      focused = findNext(focused, (int item) {
        if (auto lc = layprops(item)) return (item != focused && lc.canBeFocused && lc.visible && !lc.disabled);
        return false;
      });
      if (focused == -1) focused = findNext(0, (int item) {
        if (auto lc = layprops(item)) return (lc.canBeFocused && lc.visible && !lc.disabled);
        return false;
      });
    }
  }

  // don't pass anything to automatically calculate update delta
  void update (int msecDelta) {
    if (!updateWasCalled) {
      updateWasCalled = true;
      lastUpdateTime = MonoTime.currTime;
    }
    if (msecDelta < 0) {
      auto ct = MonoTime.currTime;
      msecDelta = cast(int)((ct-lastUpdateTime).total!"msecs");
      lastUpdateTime = ct;
    } else {
      lastUpdateTime = MonoTime.currTime;
    }
    //assert(msecDelta >= 0);
    foreach (ref ltm; lastClickDelta) {
      if (ltm >= 0 && ltm < lastClickDelta[0].max) {
        auto nt = ltm+msecDelta;
        if (nt < 0 || nt > lastClickDelta[0].max) nt = lastClickDelta[0].max;
        ltm = cast(short)nt;
      }
    }
    while (extevPos > 0) {
      final switch (extEvents.ptr[extevHead].type) {
        case ExternalEvent.Type.Char:
          if (auto lc = layprops(focused)) {
            if (lc.canBeFocused) queueEvent(focused, FuiEvent.Type.Char, cast(uint)extEvents.ptr[extevHead].cev);
          }
          break;
        case ExternalEvent.Type.Key:
          //if (!extEvents.ptr[extevHead].kev.pressed) break;
          if (extEvents.ptr[extevHead].kev.key == TtyKey.Key.Tab) {
            auto kk = extEvents.ptr[extevHead].kev;
            if (auto lc = layprops(focused)) {
              if (lc.visible && !lc.disabled && lc.wantTab) break;
            }
            if (!kk.ctrl && !kk.alt && !kk.shift) focusNext();
            if (!kk.ctrl && !kk.alt && kk.shift) focusPrev();
            break;
          }
          if (auto lc = layprops(focused)) {
            if (lc.canBeFocused && lc.enabled) queueEvent(focused, FuiEvent.Type.Key, extEvents.ptr[extevHead].kev);
          }
          break;
        case ExternalEvent.Type.Mouse:
          auto ev = &extEvents.ptr[extevHead].kev;
          mouseAt(FuiPoint(ev.x, ev.y));
          if (ev.button >= 0) {
            if (!ev.mwheel) {
              newButtonState(ev.button, ev.mpress);
            } else {
              // rawtty2 workaround
              newButtonState(ev.button, true);
              newButtonState(ev.button, false);
            }
          }
          /*
          switch (ev.type) {
            case MouseEventType.buttonPressed:
            case MouseEventType.buttonReleased:
              if (ev.button) newButtonState(cast(uint)ev.button-1, (ev.type == MouseEventType.buttonPressed));
              break;
            case MouseEventType.motion:
              //{ import std.stdio; writeln(ev.x, ",", ev.y); }
              break;
            default:
          }
          */
          break;
      }
      extevHead = (extevHead+1)%extEvents.length;
      --extevPos;
    }
  }

private:
  // return current offset in allocation buffer
  uint allocOfs () const pure @safe { pragma(inline, true); return pmemused; }

  T* structAtOfs(T) (uint ofs) @trusted {
    if (ofs >= pmemused || ofs+T.sizeof > pmemused) return null; // simple sanity check
    return cast(T*)(pmem+ofs);
  }

  // will align size to 8
  T* xcalloc(T) (int addsize=0) if (!is(T == class) && T.sizeof <= 65536) {
    if (addsize < 0 || addsize > 0x100_0000) assert(0, "Fui: WTF?!");
    if (cast(long)pmemused+T.sizeof+addsize > 0x1000_0000) assert(0, "Fui context too big");
    uint asz = cast(uint)T.sizeof+addsize;
    if (asz&0x07) asz = (asz|0x07)+1;
    /*
    {
      import core.stdc.stdio;
      auto fo = fopen("zx01", "a");
      fo.fprintf("realloc: used=%u; size=%u; asize=%u\n", pmemused, pmemsize, cast(uint)(T.sizeof));
      fclose(fo);
    }
    */
    if (pmemused+asz > pmemsize) {
      import core.stdc.stdlib : realloc;
      import core.memory : GC;
      uint newsz = pmemused+asz;
      if (asz <= 4096) newsz += asz*16; // add more space for such controls
      //if (newsz&0xfff) newsz = (newsz|0xfff)+1; // align to 4KB
      if (newsz&0x7fff) newsz = (newsz|0x7fff)+1; // align to 32KB
      if (pmem !is null) GC.removeRange(pmem);
      auto v = cast(ubyte*)realloc(pmem, newsz);
      if (v is null) assert(0, "out of memory for Fui context");
      /*
      {
        import core.stdc.stdio;
        auto fo = fopen("zx01", "a");
        fo.fprintf("realloc: oldused=%u; oldsize=%u; newsize=%u; oldp=%p; newp=%p\n", pmemused, pmemsize, newsz, pmem, v);
        fclose(fo);
      }
      */
      pmem = v;
      pmem[pmemsize..newsz] = 0;
      pmemsize = newsz;
      GC.addRange(cast(void*)v, newsz, typeid(void*));
    }
    version(fui_many_asserts) assert(pmemsize-pmemused >= asz);
    assert(pmemused%8 == 0);
    ubyte* res = pmem+pmemused;
    res[0..asz] = 0;
    pmemused += asz;
    static if (is(T == struct)) {
      import core.stdc.string : memcpy;
      static immutable T i = T.init;
      memcpy(res, &i, T.sizeof);
    }
    return cast(T*)res;
  }

  @property int lastItemIndex () const pure { pragma(inline, true); return pcount-1; }

  // -1: none
  @property int focused () const pure { pragma(inline, true); return focusedId; }
  @property void focused (int id) pure { pragma(inline, true); focusedId = (id >= 0 && id < pcount ? id : -1); }

  // add new item; set it's offset to current memtop; return pointer to allocated data
  T* addItem(T) () if (!is(T == class) && T.sizeof <= 65536) {
    if (pcount >= 65535) assert(0, "too many controls in Fui context"); // arbitrary limit
    auto ofs = pmemused;
    auto res = xcalloc!T();
    if (pidxsize-pcount < 1) {
      import core.stdc.stdlib : realloc;
      uint newsz = cast(uint)(*pidx).sizeof*pidxsize+128; // make room for more controls
      auto v = realloc(pidx, newsz);
      if (v is null) assert(0, "out of memory for Fui context");
      pidx = cast(uint*)v;
      pidxsize = newsz/cast(uint)(*pidx).sizeof;
    }
    version(fui_many_asserts) assert(pidxsize-pcount > 0);
    pidx[pcount] = ofs;
    ++pcount;
    return res;
  }

  void clear () {
    clearControls();
    focusedId = -1;
    lastHover = -1;
    lastClickDelta[] = short.max;
    lastClick[] = -1; // on which item it was registered?
    eventHead =  eventPos = 0;
  }

  // this will clear only controls, use with care!
  void clearControls () {
    if (pmemused > 0) {
      import core.stdc.string : memset;
      memset(pmem, 0, pmemused);
    }
    pmemused = 0;
    pcount = 0;
  }

public:
  @disable this (this); // no copies!

  static void decRef (usize me) {
    if (me) {
      auto nfo = cast(FuiContextImpl*)me;
      version(fui_many_asserts) assert(nfo.rc);
      if (--nfo.rc == 0) {
        import core.stdc.stdlib : free;
        if (nfo.pmem !is null) {
          import core.memory : GC;
          GC.removeRange(nfo.pmem);
          free(nfo.pmem);
        }
        if (nfo.pidx !is null) free(nfo.pidx);
        free(nfo);
      }
    }
  }

  @property int length () pure const nothrow @safe @nogc { pragma(inline, true); return pcount; }

  inout(FuiLayoutProps)* layprops (int idx) inout {
    pragma(inline, true);
    return (idx >= 0 && idx < length ? cast(typeof(return))(pmem+pidx[idx]) : null);
  }

  // -1 or item id, iterating items backwards (so last drawn will be first hit)
  // `pt` is global
  int itemAt (FuiPoint pt) {
    int check() (int id, FuiPoint g) {
      // go to last sibling
      debug(fui_item_at) { import core.stdc.stdio : printf; printf("startsib: %d\n", id); }
      for (;;) {
        auto lp = layprops(id);
        version(fui_many_asserts) assert(lp !is null);
        if (lp.nextSibling == -1) break;
        id = lp.nextSibling;
      }
      debug(fui_item_at) { import core.stdc.stdio : printf; printf("lastsib: %d\n", id); }
      // check all siblings from the last one
      for (;;) {
        auto lp = layprops(id);
        if (lp is null) return -1;
        if (lp.visible) {
          auto rc = lp.position;
          rc.xp += g.x;
          rc.yp += g.y;
          if (pt.inside(rc)) {
            // inside, go on
            if (lp.firstChild == -1) {
              debug(fui_item_at) { import core.stdc.stdio : printf; printf("FOUND %d: pt=(%d,%d) g=(%d,%d) rc=(%d,%d|%d,%d)\n", id, pt.x, pt.y, g.x, g.y, rc.x, rc.y, rc.w, rc.h); }
              return id; // i found her!
            }
            debug(fui_item_at) { import core.stdc.stdio : printf; printf("going down: fc=%d; lc=%d\n", lp.firstChild, lp.lastChild); }
            auto res = check(lp.lastChild, rc.pos);
            return (res != -1 ? res : id); // i found her!
          } else {
            debug(fui_item_at) { import core.stdc.stdio : printf; printf("skip %d: pt=(%d,%d) g=(%d,%d) rc=(%d,%d|%d,%d)\n", id, pt.x, pt.y, g.x, g.y, rc.x, rc.y, rc.w, rc.h); }
          }
        }
        // move to previous sibling
        id = lp.prevSibling;
      }
    }
    if (length == 0 || !layprops(0).visible) return -1;
    return check(0, FuiPoint(0, 0));
  }

  // return id or -1
  // contrary to what you may think, `id` itself will be checked too
  int findNext (int id, scope bool delegate (int id) nothrow @nogc check) {
    if (id == -1) id = 0;
    for (;;) {
      auto lp = layprops(id);
      if (lp is null) return -1;
      if (lp.firstChild != -1) {
        // has children, descent
        id = lp.firstChild;
        continue;
      }
      // no children, check ourself
      if (check(id)) return id;
      // go to next sibling
      for (;;) {
        if (lp.nextSibling != -1) { id = lp.nextSibling; break; }
        // no sibling, bubble and get next sibling
        id = lp.parent;
        lp = layprops(id);
        if (lp is null) return -1;
      }
    }
  }

  @property FuiSize maxDimensions () const @trusted { pragma(inline, true); return mMaxDimensions; }
  @property void maxDimensions (FuiSize v) @trusted { pragma(inline, true); mMaxDimensions = v; }
}


// ////////////////////////////////////////////////////////////////////////// //
// note that GC *WILL* *NOT* scan private context memory!
// also, item struct dtors/postblits *MAY* *NOT* *BE* *CALLED*!
struct FuiContext {
  static assert(usize.sizeof >= (void*).sizeof);

private:
  usize ctxp; // hide from GC

public:
  int findNextEx (int id, scope bool delegate (int id) check) {
    if (ctxp == 0) return -1;
    return ctx.findNextEx(id, check);
  }

nothrow @nogc:
private:
  inout(FuiContextImpl)* ctx () inout { pragma(inline, true); return cast(typeof(return))ctxp; }

  void decRef () { pragma(inline, true); if (ctxp) { FuiContextImpl.decRef(ctxp); ctxp = 0; } }
  void incRef () { pragma(inline, true); if (ctxp) ++(cast(FuiContextImpl*)ctxp).rc; }

  inout(T)* itemIntr(T) (int idx) inout if (!is(T == class)) {
    pragma(inline, true);
    return (ctxp && idx >= 0 && idx < length ? cast(typeof(return))(ctx.pmem+ctx.pidx[idx]+FuiLayoutProps.sizeof) : null);
  }

  void addRootPanel () {
    assert(ctx.length == 0);
    ctx.addItem!FuiLayoutProps();
    auto lp = ctx.layprops(0);
    lp.ctx = ctx;
    with (lp) {
      vertical = true;
      padding.left = 3;
      padding.right = 3;
      padding.top = 2;
      padding.bottom = 2;
      spacing = 0;
      itemid = 0;
    }
    lp.maxSize = ctx.maxDimensions;
    if (lp.maxSize.w < 1) lp.maxSize.w = int.max-1024; // arbitrary limit, you know
    if (lp.maxSize.h < 1) lp.maxSize.h = int.max-1024; // arbitrary limit, you know
    // add item data
    ctx.xcalloc!FuiCtlRootPanel();
    auto data = itemIntr!FuiCtlRootPanel(0);
    data.type = FuiCtlType.Box;
  }

public:
  // this will produce new context, ready to accept controls
  static FuiContext create () {
    import core.stdc.stdlib : malloc;
    import core.stdc.string : memcpy;
    FuiContext res;
    // each context always have top-level panel
    auto ct = cast(FuiContextImpl*)malloc(FuiContextImpl.sizeof);
    if (ct is null) assert(0, "out of memory for Fui context");
    static immutable FuiContextImpl i = FuiContextImpl.init;
    memcpy(ct, &i, FuiContextImpl.sizeof);
    res.ctxp = cast(usize)ct;
    res.addRootPanel();
    return res;
  }

public:
  // refcounting mechanics
  this (in FuiContext csrc) { ctxp = csrc.ctxp; incRef(); }
  ~this () { pragma(inline, true); decRef(); }
  this (this) { static if (__VERSION__ > 2071) pragma(inline, true); incRef(); }
  void opAssign (in FuiContext csrc) {
    if (csrc.ctxp) {
      // first increase refcounter for source
      ++(cast(FuiContextImpl*)csrc.ctxp).rc;
      // now decreare our refcounter
      FuiContextImpl.decRef(ctxp);
      // and copy source pointer
      ctxp = csrc.ctxp;
    } else if (ctxp) {
      // assigning empty context
      FuiContextImpl.decRef(ctxp);
      ctxp = 0;
    }
  }

public:
  @property int length () const { pragma(inline, true); return (ctxp ? ctx.length : 0); }
  alias opDollar = length;

  @property bool valid () const { pragma(inline, true); return (length > 0); }

  @property FuiSize maxDimensions () const @trusted { pragma(inline, true); return (ctxp ? ctx.maxDimensions : FuiSize.init); }
  @property void maxDimensions (FuiSize v) @trusted { pragma(inline, true); if (ctxp) ctx.maxDimensions = v; }

  // add new item; return pointer to allocated data
  // in context implementation we place item data right after FuiLayoutProps
  int addItem(T) (int parent=0, int addsize=0) if (!is(T == class) && T.sizeof <= 65536) {
    if (ctxp == 0) assert(0, "can't add item to uninitialized Fui context");
    if (length == 0) assert(0, "invalid Fui context");
    auto cidx = length;
    if (parent >= cidx) assert(0, "invalid parent for Fui item");
    // add layouter properties
    ctx.addItem!FuiLayoutProps();
    auto clp = layprops(cidx);
    clp.ctx = ctx;
    clp.itemid = cidx;
    if (parent >= 0) {
      version(fui_many_asserts) assert(clp.prevSibling == -1);
      version(fui_many_asserts) assert(clp.nextSibling == -1);
      auto pp = layprops(parent);
      clp.parent = parent;
      clp.prevSibling = pp.lastChild;
      if (pp.firstChild == -1) {
        // no children
        version(fui_many_asserts) assert(pp.lastChild == -1);
        pp.firstChild = pp.lastChild = cidx;
      } else {
        version(fui_many_asserts) assert(pp.lastChild != -1);
        layprops(pp.lastChild).nextSibling = cidx;
        pp.lastChild = cidx;
      }
    }
    // add item data
    ctx.xcalloc!T(addsize);
    return cidx;
  }

  // allocate structure, return pointer to it and offset
  T* addStruct(T) (out uint ofs, int addsize=0) if (is(T == struct)) {
    if (ctxp == 0) assert(0, "can't add struct to uninitialized Fui context");
    if (addsize > 65536) assert(0, "structure too big");
    if (addsize < 0) addsize = 0;
    ofs = ctx.allocOfs;
    return ctx.xcalloc!T(addsize);
  }

  T* structAtOfs(T) (uint ofs) @trusted if (is(T == struct)) {
    pragma(inline, true);
    return (ctxp ? ctx.structAtOfs!T(ofs) : null);
  }

  // this *WILL* *NOT* call item dtors!
  void clear () {
    pragma(inline, true);
    if (ctxp) {
      ctx.clear();
      addRootPanel();
    }
  }

  // this will clear only controls, use with care!
  void clearControls () {
    pragma(inline, true);
    if (ctxp) {
      ctx.clearControls();
      addRootPanel();
    }
  }

  inout(T)* item(T) (int idx) inout if (!is(T == class)) {
    pragma(inline, true);
    // size is aligned, so this static if
    static if (FuiLayoutProps.sizeof%8 != 0) {
      enum ofs = ((cast(uint)FuiLayoutProps.sizeof)|7)+1;
    } else {
      enum ofs = cast(uint)FuiLayoutProps.sizeof;
    }
    return (ctxp && idx > 0 && idx < length ? cast(typeof(return))(ctx.pmem+ctx.pidx[idx]+ofs) : null);
  }

  inout(FuiLayoutProps)* layprops (int idx) inout {
    pragma(inline, true);
    return (ctxp && idx >= 0 && idx < length ? cast(typeof(return))(ctx.pmem+ctx.pidx[idx]) : null);
  }

  // should be called after adding all controls, or when something was changed
  void relayout () {
    import std.algorithm : min, max;

    int[2] groupLast = -1; // list tails

    void resetValues() () {
      // reset sizes and positions for all controls
      // also, find and fix hgroups and vgroups
      foreach (int idx; 0..length) {
        auto lp = layprops(idx);
        lp.resetLayouterFlags();
        lp.position = lp.position.init; // zero it out
        // setup group lists
        foreach (immutable grp; 0..2) {
          if (lp.groupSibling[grp] != -1 && (cast(uint)(lp.groupSibling[grp])&0x8000_0000)) {
            // group start, fix list
            lp.groupNext[grp] = groupLast[grp];
            groupLast[grp] = idx;
          }
        }
      }
      version(none) {
        { import core.stdc.stdio : printf; printf("hGroupLast=%d; vGroupLast=%d\n", groupLast[0], groupLast[1]); }
        for (int n = groupLast[0]; n != -1; n = layprops(n).groupNext[0]) {
          import core.stdc.stdio : printf;
          printf("=== HGROUP #%d ===\n", n);
          int id = groupLast[0];
          for (;;) {
            auto lp = layprops(id);
            if (lp is null) break;
            printf("  item #%d\n", id);
            if (lp.groupSibling[0] == -1) break;
            id = lp.groupSibling[0]&0x7fff_ffff;
          }
        }
      }
    }

    // layout children in this item
    // `spareGroups`: don't touch widget sizes for hv groups
    // `spareAll`: don't fix this widget's size
    void layit() (int topid) {
      auto lp = layprops(topid);
      if (lp is null) return;
      // if we do group relayouting, skip touched items

      // cache values
      immutable bpadLeft = max(0, lp.padding.left);
      immutable bpadRight = max(0, lp.padding.right);
      immutable bpadTop = max(0, lp.padding.top);
      immutable bpadBottom = max(0, lp.padding.bottom);
      immutable bspc = max(0, lp.spacing);
      immutable hbox = (lp.orientation == FuiLayoutProps.Orientation.Horizontal);

      // widget can only grow, and while doing that, `maxSize` will be respected, so we don't need to fix it's size

      // layout children, insert line breaks, if necessary
      int curWidth = bpadLeft+bpadRight, maxW = bpadLeft+bpadRight, maxH = bpadTop+bpadBottom;
      int lastCIdx = -1; // last processed item for the current line
      int lineH = 0; // for the current line
      int lineCount = 0;
      //int lineStartIdx = 0;

      // unconditionally add current item to the current line
      void addToLine (FuiLayoutProps* clp, int cidx) {
        clp.tempLineBreak = false;
        debug(fui_layout) { import core.stdc.stdio : printf; printf("addToLine #%d; curWidth=%d; newWidth=%d\n", lineCount, curWidth, curWidth+clp.position.w+(lastCIdx != -1 ? bspc : 0)); }
        curWidth += clp.position.w+(lastCIdx != -1 ? bspc : 0);
        lineH = max(lineH, clp.position.h);
        lastCIdx = cidx;
      }

      // flush current line
      void flushLine () {
        if (lastCIdx == -1) return;
        // mark last item as line break
        layprops(lastCIdx).tempLineBreak = true;
        debug(fui_layout) { import core.stdc.stdio : printf; printf("flushLine #%d; curWidth=%d; maxW=%d; lineH=%d; maxH=%d; new maxH=%d\n", lineCount, curWidth, maxW, lineH+(lineCount ? lp.lineSpacing : 0), maxH, maxH+lineH+(lineCount ? lp.lineSpacing : 0)); }
        //layprops(lineStartIdx).tempLineHeight = lineH;
        // fix max width
        maxW = max(maxW, curWidth);
        // fix max height
        maxH += lineH+(lineCount ? lp.lineSpacing : 0);
        // restart line
        curWidth = bpadLeft+bpadRight;
        lastCIdx = -1;
        lineH = 0;
        ++lineCount;
      }

      // put item, do line management
      void putItem (FuiLayoutProps* clp, int cidx) {
        int nw = curWidth+clp.position.w+(lastCIdx != -1 ? bspc : 0);
        // do we neeed to start a new line?
        if (nw <= (lp.position.w ? lp.position.w : lp.maxSize.w)) {
          // no, just put item into the current line
          addToLine(clp, cidx);
          return;
        }
        // yes, check if we have at least one item in the current line
        if (lastCIdx == -1) {
          // alas, no items in the current line, put one
          addToLine(clp, cidx);
          // and flush it immediately
          flushLine();
        } else {
          // flush current line
          flushLine();
          // and add this item to it
          addToLine(clp, cidx);
        }
      }

      // layout children, insert "soft" line breaks
      int cidx = lp.firstChild;
      for (;;) {
        auto clp = layprops(cidx);
        if (clp is null) break;
        layit(cidx); // layout children of this box
        if (hbox) {
          // for horizontal box, logic is somewhat messy
          putItem(clp, cidx);
          if (clp.flags&clp.Flags.LineBreak) flushLine();
        } else {
          // for vertical box, it is as easy as this
          clp.tempLineBreak = true;
          maxW = max(maxW, clp.position.w+bpadLeft+bpadRight);
          maxH += clp.position.h+(lineCount ? bspc : 0);
          ++lineCount;
        }
        cidx = clp.nextSibling;
      }
      if (hbox) flushLine(); // flush last list for horizontal box (it is safe to flush empty line)

      // grow box or clamp max size
      // but only if size is not defined; in other cases our size is changed by parent to fit in
      if (lp.position.w == 0) lp.position.w = min(max(0, lp.minSize.w, maxW), lp.maxSize.w);
      if (lp.position.h == 0) lp.position.h = min(max(0, lp.minSize.h, maxH), lp.maxSize.h);
      maxH = lp.position.h;
      maxW = lp.position.w;

      int flexTotal; // total sum of flex fields
      int flexBoxCount; // number of boxes
      int curSpc; // "current" spacing in layout calculations (for bspc)
      int spaceLeft;

      if (hbox) {
        // layout horizontal box; we should do this for each line separately
        int lineStartY = bpadTop;

        void resetLine () {
          flexTotal = 0;
          flexBoxCount = 0;
          curSpc = 0;
          spaceLeft = lp.position.w-(bpadLeft+bpadRight);
          lineH = 0;
        }

        int lstart = lp.firstChild;
        int lineNum = 0;
        for (;;) {
          if (layprops(lstart) is null) break;
          // calculate flex variables and line height
          --lineCount; // so 0 will be "last line"
          version(fui_many_asserts) assert(lineCount >= 0);
          resetLine();
          cidx = lstart;
          for (;;) {
            auto clp = layprops(cidx);
            if (clp is null) break;
            auto dim = clp.position.w+curSpc;
            spaceLeft -= dim;
            lineH = max(lineH, clp.position.h);
            // process flex
            if (clp.flex > 0) { flexTotal += clp.flex; ++flexBoxCount; }
            if (clp.tempLineBreak) break; // no more in this line
            curSpc = bspc;
            cidx = clp.nextSibling;
          }
          //spaceLeft += curSpc; // last control should not be "spaced after"
          if (lineCount == 0) lineH = max(lineH, lp.position.h-bpadBottom-lineStartY-lineH);
          debug(fui_layout) { import core.stdc.stdio : printf; printf("lineStartY=%d; lineH=%d\n", lineStartY, lineH); }

          // distribute flex space, fix coordinates
          debug(fui_layout) { import core.stdc.stdio : printf; printf("flexTotal=%d; flexBoxCount=%d; spaceLeft=%d\n", flexTotal, flexBoxCount, spaceLeft); }
          cidx = lstart;
          float flt = cast(float)flexTotal;
          float left = cast(float)spaceLeft;
          int curpos = bpadLeft;
          for (;;) {
            auto clp = layprops(cidx);
            if (clp is null) break;
            // fix packing coordinate
            clp.position.x = curpos;
            bool doChildrenRelayout = false;
            // fix non-packing coordinate (and, maybe, non-packing dimension)
            // fix y coord
            final switch (clp.aligning) {
              case FuiLayoutProps.Align.Start: clp.position.y = lineStartY; break;
              case FuiLayoutProps.Align.End: clp.position.y = (lineStartY+lineH)-clp.position.h; break;
              case FuiLayoutProps.Align.Center: clp.position.y = lineStartY+(lineH-clp.position.h)/2; break;
              case FuiLayoutProps.Align.Stretch:
                clp.position.y = lineStartY;
                int nd = min(max(0, lineH, clp.minSize.h), clp.maxSize.h);
                if (nd != clp.position.h) {
                  // size changed, relayout children
                  doChildrenRelayout = true;
                  clp.position.h = nd;
                }
                break;
            }
            // fix flexbox size
            if (clp.flex > 0) {
              int toadd = cast(int)(left*cast(float)clp.flex/flt+0.5);
              if (toadd > 0) {
                // size changed, relayout children
                doChildrenRelayout = true;
                clp.position.wp += toadd;
                // compensate (crudely) rounding errors
                if (toadd > 1 && lp.position.w-(curpos+clp.position.w) < 0) {
                  clp.position.wp -= 1;
                }
              }
            }
            // advance packing coordinate
            curpos += clp.position.w+bspc;
            // relayout children if dimensions was changed
            if (doChildrenRelayout) layit(cidx);
            cidx = clp.nextSibling;
            if (clp.tempLineBreak) break; // next line, please!
          }
          // yep, move to next line
          lstart = cidx;
          debug(fui_layout) { import core.stdc.stdio : printf; printf("lineStartY=%d; next lineStartY=%d\n", lineStartY, lineStartY+lineH+lp.lineSpacing); }
          lineStartY += lineH+lp.lineSpacing;
        }
      } else {
        // layout vertical box, it is much easier

        // setup vars
        //flexTotal = 0;
        //flexBoxCount = 0;
        //curSpc = 0;
        spaceLeft = lp.position.h-(bpadTop+bpadBottom);

        // calculate flex variables
        cidx = lp.firstChild;
        for (;;) {
          auto clp = layprops(cidx);
          if (clp is null) break;
          auto dim = clp.position.h+curSpc;
          spaceLeft -= dim;
          // process flex
          if (clp.flex > 0) { flexTotal += clp.flex; ++flexBoxCount; }
          curSpc = bspc;
          cidx = clp.nextSibling;
        }

        // distribute flex space, fix coordinates
        cidx = lp.firstChild;
        float flt = cast(float)flexTotal;
        float left = cast(float)spaceLeft;
        int curpos = bpadTop;
        for (;;) {
          auto clp = layprops(cidx);
          if (clp is null) break;
          // fix packing coordinate
          clp.position.y = curpos;
          bool doChildrenRelayout = false;
          // fix non-packing coordinate (and, maybe, non-packing dimension)
          // fix x coord
          final switch (clp.aligning) {
            case FuiLayoutProps.Align.Start: clp.position.x = bpadLeft; break;
            case FuiLayoutProps.Align.End: clp.position.x = lp.position.w-bpadRight-clp.position.w; break;
            case FuiLayoutProps.Align.Center: clp.position.x = (lp.position.w-clp.position.w)/2; break;
            case FuiLayoutProps.Align.Stretch:
              int nd = min(max(0, lp.position.w-(bpadLeft+bpadRight), clp.minSize.w), clp.maxSize.w);
              if (nd != clp.position.w) {
                // size changed, relayout children
                doChildrenRelayout = true;
                clp.position.w = nd;
              }
              clp.position.x = bpadLeft;
              break;
          }
          // fix flexbox size
          if (clp.flex > 0) {
            int toadd = cast(int)(left*cast(float)clp.flex/flt);
            if (toadd > 0) {
              // size changed, relayout children
              doChildrenRelayout = true;
              clp.position.hp += toadd;
            }
          }
          // advance packing coordinate
          curpos += clp.position.h+bspc;
          // relayout children if dimensions was changed
          if (doChildrenRelayout) layit(cidx);
          cidx = clp.nextSibling;
        }
        // that's all for vertical boxes
      }
    }

    // main code
    if (ctxp == 0 || length < 1) return;

    resetValues();

    // do top-level packing
    layit(0);
    bool resetTouched = false;
    for (;;) {
      bool doItAgain = false;
      bool doFix = false;

      void fixGroups (int grp, scope int delegate (int item) nothrow @nogc getdim, scope void delegate (int item, int v) nothrow @nogc setdim, scope int delegate (int item) nothrow @nogc getmax) nothrow @nogc {
        int gidx = groupLast[grp];
        while (layprops(gidx) !is null) {
          int dim = 1;
          int cidx = gidx;
          // calcluate maximal dimension
          for (;;) {
            auto clp = layprops(cidx);
            if (clp is null) break;
            dim = max(dim, getdim(cidx));
            if (clp.groupSibling[grp] == -1) break;
            cidx = clp.groupSibling[grp]&0x7fff_ffff;
          }
          // fix dimensions
          cidx = gidx;
          for (;;) {
            auto clp = layprops(cidx);
            if (clp is null) break;
            auto od = getdim(cidx);
            int nd = max(od, dim);
            auto mx = getmax(cidx);
            if (mx > 0) nd = min(nd, mx);
            if (od != nd) {
              doFix = true;
              setdim(cidx, nd);
              if (clp.parent == 0) doItAgain = true;
            }
            if (clp.groupSibling[grp] == -1) break;
            cidx = clp.groupSibling[grp]&0x7fff_ffff;
          }
          // process next group
          gidx = layprops(gidx).groupNext[grp];
        }
      }

      fixGroups(FuiLayoutProps.Group.H,
        (int item) => ctx.layprops(item).position.w,
        (int item, int v) { ctx.layprops(item).position.wp = v; },
        (int item) => ctx.layprops(item).maxSize.w,
      );
      fixGroups(FuiLayoutProps.Group.V,
        (int item) => ctx.layprops(item).position.h,
        (int item, int v) { ctx.layprops(item).position.wp = v; },
        (int item) => ctx.layprops(item).maxSize.h,
      );
      if (!doFix && !doItAgain) break; // nothing to do
      // reset "group touched" flag, if necessary
      if (resetTouched) {
        foreach (int idx; 0..length) layprops(idx).touchedByGroup = false;
      } else {
        resetTouched = true;
      }

      // if we need to fix some parts of the layout, do it
      if (doFix) {
        foreach (int grp; 0..2) {
          int gidx = groupLast[grp];
          { import core.stdc.stdio : printf; printf("grp=%d; gidx=%d\n", grp, groupLast[grp]); }
          while (layprops(gidx) !is null) {
            int it = gidx;
            while (layprops(it) !is null) {
              { import core.stdc.stdio : printf; printf(" === it=%d ===\n", it); }
              int itt = it;
              for (;;) {
                auto lp = layprops(itt);
                if (lp is null) break;
                { import core.stdc.stdio : printf; printf("  itt=%d\n", itt); }
                if (!lp.touchedByGroup) {
                  lp.touchedByGroup = true;
                  auto ow = lp.position.w, oh = lp.position.h;
                  layit(itt);
                  if (itt != it && ow == lp.position.w && oh == lp.position.h) break;
                } else {
                  break;
                }
                itt = lp.parent;
              }
              auto lp = layprops(it);
              if (lp.groupSibling[grp] == -1) break;
              it = lp.groupSibling[grp]&0x7fff_ffff;
            }
            gidx = layprops(gidx).groupNext[grp];
          }
        }
        //doItAgain = true;
      }
      if (!doItAgain) break;
    }
  }

  debug(tui_dump) void dumpLayout () const {
    import core.stdc.stdio : fopen, fclose, fprintf;

    auto fo = fopen("zlay.bin", "w");
    if (fo is null) return;
    scope(exit) fclose(fo);

    void ind (int indent) { foreach (immutable _; 0..indent) fo.fprintf(" "); }

    void dumpItem (int idx, int indent) {
      auto lp = layprops(idx);
      if (lp is null) return;
      ind(indent);
      fo.fprintf("Ctl#%d: position:(%d,%d); size:(%d,%d)\n", idx, lp.position.x, lp.position.y, lp.position.w, lp.position.h);
      idx = lp.firstChild;
      for (;;) {
        lp = layprops(idx);
        if (lp is null) break;
        dumpItem(idx, indent+2);
        idx = lp.nextSibling;
      }
    }

    dumpItem(0, 0);
  }

  debug void dumpLayoutBack () const {
    import core.stdc.stdio : printf;

    static void ind (int indent) { foreach (immutable _; 0..indent) printf(" "); }

    void dumpItem (int idx, int indent) {
      auto lp = layprops(idx);
      if (lp is null) return;
      ind(indent);
      printf("Ctl#%d: position:(%d,%d); size:(%d,%d)\n", idx, lp.position.x, lp.position.y, lp.position.w, lp.position.h);
      idx = lp.lastChild;
      for (;;) {
        lp = layprops(idx);
        if (lp is null) break;
        dumpItem(idx, indent+2);
        idx = lp.prevSibling;
      }
    }

    dumpItem(0, 0);
  }

  // -1 or item id, iterating items backwards (so last drawn will be first hit)
  int itemAt (FuiPoint pt) { pragma(inline, true); return (ctxp ? ctx.itemAt(pt) : -1); }

  // return id or -1
  // contrary to what you may think, `id` itself will be checked too
  int findNext (int id, scope bool delegate (int id) nothrow @nogc check) { pragma(inline, true); return (ctxp ? ctx.findNext(id, check) : -1); }

  void focusPrev () { pragma(inline, true); if (ctxp) ctx.focusPrev(); }
  void focusNext () { pragma(inline, true); if (ctxp) ctx.focusNext(); }

  // -1: none
  @property int focused () const { pragma(inline, true); return (ctxp ? ctx.focusedId : -1); }
  @property void focused (int id) { pragma(inline, true); if (ctxp) ctx.focused = id; }

  void setEnabled (int id, bool v) {
    if (auto lp = layprops(id)) {
      if (lp.enabled != v) {
        lp.enabled = v;
        if (!v && focused == id) focusNext();
      }
    }
  }

  // external actions
  void keyboardEvent (TtyKey ev) { pragma(inline, true); if (ctxp) ctx.keyboardEvent(ev); }
  //void charEvent (dchar ch) { pragma(inline, true); if (ctxp) ctx.charEvent(ch); }
  //void mouseEvent (MouseEvent ev) { pragma(inline, true); if (ctxp) ctx.mouseEvent(ev); }

  // don't pass anything to automatically calculate update delta
  void update (int msecDelta=-1) { pragma(inline, true); if (ctxp) ctx.update(msecDelta); }

  void queueEvent (int aitem, FuiEvent.Type atype, uint aparam0=0, uint aparam1=0) nothrow @trusted @nogc { pragma(inline, true); if (ctxp) ctx.queueEvent(aitem, atype, aparam0, aparam1); }
  bool hasEvents () const nothrow @trusted @nogc { pragma(inline, true); return (ctxp ? ctx.hasEvents() : false); }
  FuiEvent getEvent () nothrow @trusted @nogc { pragma(inline, true); return (ctxp ? ctx.getEvent() : FuiEvent.init); }

  @property ubyte lastButtons () nothrow @trusted @nogc { pragma(inline, true); return (ctxp ? ctx.lastButtons : 0); }
  @property ubyte lastMods () nothrow @trusted @nogc { pragma(inline, true); return (ctxp ? ctx.lastMods : 0); }
}


// ////////////////////////////////////////////////////////////////////////// //
struct Palette {
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
enum TuiPaletteNormal = 0;
enum TuiPaletteError = 1;

__gshared Palette[2] tuiPalette; // default palette

shared static this () {
  tuiPalette[TuiPaletteNormal].def = XtColorFB!(ttyRgb2Color(0xd0, 0xd0, 0xd0), ttyRgb2Color(0x4e, 0x4e, 0x4e)); // 252,239
  // sel is also focus
  tuiPalette[TuiPaletteNormal].sel = XtColorFB!(ttyRgb2Color(0xda, 0xda, 0xda), ttyRgb2Color(0x00, 0x5f, 0x5f)); // 253,23
  tuiPalette[TuiPaletteNormal].mark = XtColorFB!(ttyRgb2Color(0xff, 0xff, 0x00), ttyRgb2Color(0x5f, 0x5f, 0x5f)); // 226,59
  tuiPalette[TuiPaletteNormal].marksel = XtColorFB!(ttyRgb2Color(0xff, 0xff, 0x87), ttyRgb2Color(0x00, 0x5f, 0x87)); // 228,24
  tuiPalette[TuiPaletteNormal].gauge = XtColorFB!(ttyRgb2Color(0xbc, 0xbc, 0xbc), ttyRgb2Color(0x5f, 0x87, 0x87)); // 250,66
  tuiPalette[TuiPaletteNormal].input = XtColorFB!(ttyRgb2Color(0xd7, 0xd7, 0xaf), ttyRgb2Color(0x26, 0x26, 0x26)); // 187,235
  tuiPalette[TuiPaletteNormal].inputmark = XtColorFB!(ttyRgb2Color(0xff, 0xff, 0x87), ttyRgb2Color(0x00, 0x5f, 0x5f)); // 228,23
  //tuiPalette[TuiPaletteNormal].inputunchanged = XtColorFB!(ttyRgb2Color(0xff, 0xff, 0xff), ttyRgb2Color(0x26, 0x26, 0x26)); // 144,235
  tuiPalette[TuiPaletteNormal].inputunchanged = XtColorFB!(ttyRgb2Color(0xff, 0xff, 0xff), ttyRgb2Color(0x00, 0x00, 0x40));
  tuiPalette[TuiPaletteNormal].reverse = XtColorFB!(ttyRgb2Color(0xe4, 0xe4, 0xe4), ttyRgb2Color(0x5f, 0x87, 0x87)); // 254,66
  tuiPalette[TuiPaletteNormal].title = XtColorFB!(ttyRgb2Color(0xd7, 0xaf, 0x87), ttyRgb2Color(0x4e, 0x4e, 0x4e)); // 180,239
  tuiPalette[TuiPaletteNormal].disabled = XtColorFB!(ttyRgb2Color(0x94, 0x94, 0x94), ttyRgb2Color(0x4e, 0x4e, 0x4e)); // 246,239
  // hotkey
  tuiPalette[TuiPaletteNormal].hot = XtColorFB!(ttyRgb2Color(0xff, 0xaf, 0x00), ttyRgb2Color(0x4e, 0x4e, 0x4e)); // 214,239
  tuiPalette[TuiPaletteNormal].hotsel = XtColorFB!(ttyRgb2Color(0xff, 0xaf, 0x00), ttyRgb2Color(0x00, 0x5f, 0x5f)); // 214,23

  tuiPalette[TuiPaletteError] = tuiPalette[TuiPaletteNormal];
  tuiPalette[TuiPaletteError].def = XtColorFB!(ttyRgb2Color(0xff, 0xff, 0xd7), ttyRgb2Color(0x5f, 0x00, 0x00)); // 230,52
  tuiPalette[TuiPaletteError].sel = XtColorFB!(ttyRgb2Color(0xe4, 0xe4, 0xe4), ttyRgb2Color(0x00, 0x5f, 0x5f)); // 254,23
  tuiPalette[TuiPaletteError].hot = XtColorFB!(ttyRgb2Color(0xff, 0x5f, 0x5f), ttyRgb2Color(0x5f, 0x00, 0x00)); // 203,52
  tuiPalette[TuiPaletteError].hotsel = XtColorFB!(ttyRgb2Color(0xff, 0x5f, 0x5f), ttyRgb2Color(0x00, 0x5f, 0x5f)); // 203,23
  tuiPalette[TuiPaletteError].title = XtColorFB!(ttyRgb2Color(0xff, 0xff, 0x5f), ttyRgb2Color(0x5f, 0x00, 0x00)); // 227,52
}


// ////////////////////////////////////////////////////////////////////////// //
private int visStrLen(bool dohot=true) (const(char)[] s) nothrow @trusted @nogc {
  if (s.length > int.max) s = s[0..int.max];
  int res = cast(int)s.length;
       if (res && s.ptr[0] == '\x01') --res; // left
  else if (res && s.ptr[0] == '\x02') --res; // right
  else if (res && s.ptr[0] == '\x03') --res; // center (default)
  static if (dohot) {
    for (;;) {
      auto ampos = s.indexOf('&');
      if (ampos < 0 || s.length-ampos < 2) break;
      if (s.ptr[ampos+1] != '&') { --res; break; }
      s = s[ampos+2..$];
    }
  }
  return res;
}


private char visHotChar (const(char)[] s) nothrow @trusted @nogc {
  bool prevWasAmp = false;
  foreach (char ch; s) {
    if (ch == '&') {
      prevWasAmp = !prevWasAmp;
    } else if (prevWasAmp) {
      return ch;
    }
  }
  return 0;
}


// ////////////////////////////////////////////////////////////////////////// //
private const(char)[] getz (const(char)[] s) nothrow @trusted @nogc {
  foreach (immutable idx, char ch; s) if (ch == 0) return s[0..idx];
  return s;
}


private void setz (char[] dest, const(char)[] s) nothrow @trusted @nogc {
  dest[] = 0;
  if (s.length >= dest.length) s = s[0..dest.length-1];
  if (s.length) dest[0..s.length] = s[];
}


// ////////////////////////////////////////////////////////////////////////// //
enum FuiCtlUserFlags : ushort {
  Default = 1<<0,
}


// ////////////////////////////////////////////////////////////////////////// //
enum FuiCtlType : ubyte {
  Invisible,
  HLine,
  Box,
  Panel,
  EditLine,
  EditText,
  TextView,
  ListBox,
  CustomBox,
  //WARNING: button-likes should be last!
  Label,
  Button,
  Check,
  Radio,
}

// onchange callback; return -666 to continue, -1 to exit via "esc", or control id to return from `modalDialog()`
alias TuiActionCB = int delegate (FuiContext ctx, int self);
// draw widget; rc is in global space
alias TuiDrawCB = void delegate (FuiContext ctx, int self, FuiRect rc);
// process event; return `true` if event was eaten
alias TuiEventCB = bool delegate (FuiContext ctx, int self, FuiEvent ev);

mixin template FuiCtlHeader() {
  FuiCtlType type;
  Palette pal;
  char[64] id = 0; // widget it
  char[128] caption = 0; // widget caption
align(8):
  // onchange callback; return -666 to continue, -1 to exit via "esc", or control id to return from `modalDialog()`
  TuiActionCB actcb;
  // draw widget; rc is in global space
  TuiDrawCB drawcb;
  // process event; return `true` if event was eaten
  TuiEventCB eventcb;
}


struct FuiCtlHead {
  mixin FuiCtlHeader;
}
static assert(FuiCtlHead.actcb.offsetof%8 == 0);


//TODO: make delegate this scoped?
bool setActionCB (FuiContext ctx, int item, TuiActionCB cb) {
  if (auto data = ctx.item!FuiCtlHead(item)) {
    data.actcb = cb;
    return true;
  }
  return false;
}


//TODO: make delegate this scoped?
bool setDrawCB (FuiContext ctx, int item, TuiDrawCB cb) {
  if (auto data = ctx.item!FuiCtlHead(item)) {
    data.drawcb = cb;
    return true;
  }
  return false;
}


//TODO: make delegate this scoped?
bool setEventCB (FuiContext ctx, int item, TuiEventCB cb) {
  if (auto data = ctx.item!FuiCtlHead(item)) {
    data.eventcb = cb;
    return true;
  }
  return false;
}


bool setCaption (FuiContext ctx, int item, const(char)[] caption) {
  if (auto data = ctx.item!FuiCtlHead(item)) {
    data.caption.setz(caption);
    auto cpt = data.caption.getz;
    auto lp = ctx.layprops(item);
    /*if (lp.minSize.w < cpt.length)*/ lp.minSize.w = cast(int)cpt.length;
    return true;
  }
  return false;
}


// ////////////////////////////////////////////////////////////////////////// //
enum FuiDialogFrameType : ubyte {
  Normal,
  Small,
  //None,
}

struct FuiCtlRootPanel {
  mixin FuiCtlHeader;
  FuiDialogFrameType frame;
  bool enterclose;
}


void dialogCaption (FuiContext ctx, const(char)[] text) {
  if (!ctx.valid) return;
  auto data = ctx.itemIntr!FuiCtlRootPanel(0);
  data.caption.setz(text);
}


FuiDialogFrameType dialogFrame (FuiContext ctx) {
  if (!ctx.valid) return FuiDialogFrameType.Normal;
  auto data = ctx.itemIntr!FuiCtlRootPanel(0);
  return data.frame;
}


void dialogFrame (FuiContext ctx, FuiDialogFrameType t) {
  if (!ctx.valid) return;
  auto data = ctx.itemIntr!FuiCtlRootPanel(0);
  auto lp = ctx.layprops(0);
  final switch (t) {
    case FuiDialogFrameType.Normal:
      data.frame = FuiDialogFrameType.Normal;
      with (lp.padding) {
        left = 3;
        right = 3;
        top = 2;
        bottom = 2;
      }
      break;
    case FuiDialogFrameType.Small:
      data.frame = FuiDialogFrameType.Small;
      with (lp.padding) {
        left = 1;
        right = 1;
        top = 1;
        bottom = 1;
      }
      break;
  }
}


void dialogEnterClose (FuiContext ctx, bool enterclose) {
  if (!ctx.valid) return;
  auto data = ctx.itemIntr!FuiCtlRootPanel(0);
  data.enterclose = enterclose;
}


bool dialogEnterClose (FuiContext ctx) {
  if (!ctx.valid) return false;
  auto data = ctx.itemIntr!FuiCtlRootPanel(0);
  return data.enterclose;
}


// ////////////////////////////////////////////////////////////////////////// //
struct FuiCtlCustomBox {
  mixin FuiCtlHeader;
  align(8) void* udata;
}


int custombox (FuiContext ctx, int parent, const(char)[] id=null) {
  if (!ctx.valid) return -1;
  auto item = ctx.addItem!FuiCtlSpan(parent);
  with (ctx.layprops(item)) {
    //flex = 1;
    visible = true;
    horizontal = true;
    aligning = FuiLayoutProps.Align.Stretch;
    minSize.w = 1;
    minSize.h = 1;
    //clickMask |= FuiLayoutProps.Buttons.Left;
    //canBeFocused = true;
    wantTab = false;
  }
  auto data = ctx.item!FuiCtlCustomBox(item);
  data.type = FuiCtlType.CustomBox;
  data.id.setz(id);
  /*
  data.drawcb = delegate (FuiContext ctx, int self, FuiRect rc) {
    auto win = XtWindow(rc.x, rc.y, rc.w, rc.h);
    win.color = ctx.palColor!"def"(item);
    win.bg = 1;
    win.fill(0, 0, rc.w, rc.h);
  };
  */
  return item;
}


// ////////////////////////////////////////////////////////////////////////// //
struct FuiCtlSpan {
  mixin FuiCtlHeader;
}


int span (FuiContext ctx, int parent, bool ahorizontal) {
  if (!ctx.valid) return -1;
  auto item = ctx.addItem!FuiCtlSpan(parent);
  with (ctx.layprops(item)) {
    flex = 1;
    visible = false;
    horizontal = ahorizontal;
    aligning = (ahorizontal ? FuiLayoutProps.Align.Stretch : FuiLayoutProps.Align.Start);
  }
  auto data = ctx.item!FuiCtlSpan(item);
  data.type = FuiCtlType.Invisible;
  //data.pal = Palette.init;
  return item;
}

int hspan (FuiContext ctx, int parent) { return ctx.span(parent, true); }
int vspan (FuiContext ctx, int parent) { return ctx.span(parent, false); }


int spacer (FuiContext ctx, int parent) {
  if (!ctx.valid) return -1;
  auto item = ctx.addItem!FuiCtlSpan(parent);
  with (ctx.layprops(item)) {
    flex = 0;
    visible = false;
    horizontal = true;
    aligning = FuiLayoutProps.Align.Start;
  }
  auto data = ctx.item!FuiCtlSpan(item);
  data.type = FuiCtlType.Invisible;
  //data.pal = Palette.init;
  return item;
}


int hline (FuiContext ctx, int parent) {
  if (!ctx.valid) return -1;
  auto item = ctx.addItem!FuiCtlSpan(parent);
  with (ctx.layprops(item)) {
    flex = 0;
    visible = true;
    horizontal = true;
    lineBreak = true;
    aligning = FuiLayoutProps.Align.Stretch;
    minSize.h = maxSize.h = 1;
  }
  auto data = ctx.item!FuiCtlSpan(item);
  data.type = FuiCtlType.HLine;
  //data.pal = Palette.init;
  data.drawcb = delegate (FuiContext ctx, int self, FuiRect rc) {
    auto lp = ctx.layprops(self);
    auto win = XtWindow.fullscreen;
    win.color = ctx.palColor!"def"(self);
    if (lp.parent == 0) {
      auto rlp = ctx.layprops(0);
      int x0, x1;
      final switch (ctx.dialogFrame) {
        case FuiDialogFrameType.Normal:
          x0 = rc.x-2;
          x1 = x0+(rlp.position.w-2);
          break;
        case FuiDialogFrameType.Small:
          x0 = rc.x-1;
          x1 = x0+rlp.position.w;
          break;
      }
      win.hline(x0, rc.y, x1-x0);
    } else {
      win.hline(rc.x, rc.y, rc.w);
    }
  };
  return item;
}

// ////////////////////////////////////////////////////////////////////////// //
struct FuiCtlBox {
  mixin FuiCtlHeader;
}


int box (FuiContext ctx, int parent, bool ahorizontal, const(char)[] id=null) {
  if (!ctx.valid) return -1;
  auto item = ctx.addItem!FuiCtlBox(parent);
  with (ctx.layprops(item)) {
    flex = (ahorizontal ? 0 : 1);
    horizontal = ahorizontal;
    aligning = (ahorizontal ? FuiLayoutProps.Align.Stretch : FuiLayoutProps.Align.Start);
    visible = true;
  }
  auto data = ctx.item!FuiCtlBox(item);
  data.type = FuiCtlType.Box;
  //data.pal = Palette.init;
  data.id.setz(id);
  return item;
}

int hbox (FuiContext ctx, int parent, const(char)[] id=null) { return ctx.box(parent, true, id); }
int vbox (FuiContext ctx, int parent, const(char)[] id=null) { return ctx.box(parent, false, id); }


// ////////////////////////////////////////////////////////////////////////// //
struct FuiCtlPanel {
  mixin FuiCtlHeader;
}


int panel (FuiContext ctx, int parent, const(char)[] caption, bool ahorizontal, const(char)[] id=null) {
  if (!ctx.valid) return -1;
  auto item = ctx.addItem!FuiCtlPanel(parent);
  with (ctx.layprops(item)) {
    flex = (ahorizontal ? 0 : 1);
    horizontal = ahorizontal;
    aligning = (ahorizontal ? FuiLayoutProps.Align.Stretch : FuiLayoutProps.Align.Start);
    minSize = FuiSize(visStrLen(caption)+4, 2);
    padding.left = 1;
    padding.right = 1;
    padding.top = 1;
    padding.bottom = 1;
  }
  auto data = ctx.item!FuiCtlPanel(item);
  data.type = FuiCtlType.Panel;
  //data.pal = Palette.init;
  data.id.setz(id);
  data.caption.setz(caption);
  data.drawcb = delegate (FuiContext ctx, int self, FuiRect rc) {
    auto data = ctx.item!FuiCtlPanel(self);
    auto win = XtWindow.fullscreen;
    win.color = ctx.palColor!"def"(self);
    win.frame!true(rc.x, rc.y, rc.w, rc.h);
    win.tuiWriteStr!("center", true)(rc.x+1, rc.y, rc.w-2, data.caption.getz, ctx.palColor!"title"(self), ctx.palColor!"hot"(self));
  };
  return item;
}

int hpanel (FuiContext ctx, int parent, const(char)[] caption, const(char)[] id=null) { return ctx.panel(parent, caption, true, id); }
int vpanel (FuiContext ctx, int parent, const(char)[] caption, const(char)[] id=null) { return ctx.panel(parent, caption, false, id); }


// ////////////////////////////////////////////////////////////////////////// //
struct FuiCtlEditLine {
  mixin FuiCtlHeader;
  align(8) TtyEditor ed;
}
static assert(FuiCtlEditLine.ed.offsetof%4 == 0);


private int editlinetext(bool text) (FuiContext ctx, int parent, const(char)[] id, const(char)[] deftext=null, bool utfuck=false) {
  if (!ctx.valid) return -1;
  auto item = ctx.addItem!FuiCtlEditLine(parent);
  with (ctx.layprops(item)) {
    flex = 0;
    horizontal = true;
    clickMask |= FuiLayoutProps.Buttons.Left;
    canBeFocused = true;
    wantTab = false;
    //aligning = (ahorizontal ? FuiLayoutProps.Align.Stretch : FuiLayoutProps.Align.Start);
    int mw = (deftext.length < 10 ? 10 : deftext.length > 50 ? 50 : cast(int)deftext.length);
    minSize = FuiSize(mw, 1);
    maxSize = FuiSize(int.max-1024, 1);
  }
  auto data = ctx.item!FuiCtlEditLine(item);
  static if (text) {
    data.type = FuiCtlType.EditText;
  } else {
    data.type = FuiCtlType.EditLine;
  }
  //data.pal = Palette.init;
  data.id.setz(id);
  data.ed = new TtyEditor(0, 0, 10, 1, !text); // size will be fixed later
  data.ed.utfuck = utfuck;
  data.ed.doPutText(deftext);
  data.ed.clearUndo();
  static if (!text) data.ed.killTextOnChar = true;
  data.drawcb = delegate (FuiContext ctx, int self, FuiRect rc) {
    auto data = ctx.item!FuiCtlEditLine(self);
    auto lp = ctx.layprops(self);
    auto ed = data.ed;
    ed.moveResize(rc.x, rc.y, rc.w, rc.h);
    ed.fullDirty;
    ed.dontSetCursor = (self != ctx.focused);
    if (lp.enabled) {
      if (self == ctx.focused) {
        ed.clrBlock = ctx.palColor!"inputmark"(self);
        ed.clrText = ctx.palColor!"input"(self);
        ed.clrTextUnchanged = ctx.palColor!"inputunchanged"(self);
      } else {
        ed.clrBlock = ctx.palColor!"inputmark"(self);
        ed.clrText = ctx.palColor!"input"(self);
        ed.clrTextUnchanged = ctx.palColor!"inputunchanged"(self);
      }
    } else {
      ed.clrBlock = ctx.palColor!"disabled"(self);
      ed.clrText = ctx.palColor!"disabled"(self);
      ed.clrTextUnchanged = ctx.palColor!"disabled"(self);
    }
    auto oldcolor = xtGetColor();
    scope(exit) xtSetColor(oldcolor);
    ed.drawPage();
  };
  data.eventcb = delegate (FuiContext ctx, int self, FuiEvent ev) {
    if (ev.item != self) return false;
    auto eld = ctx.item!FuiCtlEditLine(self);
    final switch (ev.type) {
      case FuiEvent.Type.None:
        return false;
      case FuiEvent.Type.Char: // param0: dchar; param1: mods&buttons
        TtyKey k;
        k.key = TtyKey.Key.Char;
        k.ch = ev.ch;
        if (eld.ed.processKey(k)) {
          if (eld.actcb !is null) {
            auto rr = eld.actcb(ctx, ev.item);
            if (rr >= -1) ctx.queueEvent(ev.item, FuiEvent.Type.Close, rr);
          }
          return true;
        }
        return false;
      case FuiEvent.Type.Key: // param0: sdpy keycode; param1: mods&buttons
        // editline
        if (eld.ed.processKey(ev.key)) {
          if (eld.actcb !is null) {
            auto rr = eld.actcb(ctx, ev.item);
            if (rr >= -1) ctx.queueEvent(ev.item, FuiEvent.Type.Close, rr);
          }
          return true;
        }
        return false;
      case FuiEvent.Type.Click: // mouse click; param0: buttton index; param1: mods&buttons
        if (eld.ed.processClick(ev.bidx, ev.x, ev.y)) return true;
        return true;
      case FuiEvent.Type.Double: // mouse double-click; param0: buttton index; param1: mods&buttons
        return true;
      case FuiEvent.Type.Close: // close dialog; param0: return id
        return false;
    }
  };
  return item;
}


// `actcb` will be called *after* editor was changed (or not changed, who knows)
int editline (FuiContext ctx, int parent, const(char)[] id, const(char)[] deftext=null, bool utfuck=false) {
  return editlinetext!false(ctx, parent, id, deftext, utfuck);
}


// `actcb` will be called *after* editor was changed (or not changed, who knows)
int edittext (FuiContext ctx, int parent, const(char)[] id, const(char)[] deftext=null, bool utfuck=false) {
  return editlinetext!true(ctx, parent, id, deftext, utfuck);
}


TtyEditor editlineEditor (FuiContext ctx, int item) {
  if (auto data = ctx.item!FuiCtlEditLine(item)) {
    if (data.type == FuiCtlType.EditLine) return data.ed;
  }
  return null;
}


TtyEditor edittextEditor (FuiContext ctx, int item) {
  if (auto data = ctx.item!FuiCtlEditLine(item)) {
    if (data.type == FuiCtlType.EditText) return data.ed;
  }
  return null;
}


char[] editlineGetText (FuiContext ctx, int item) {
  if (auto edl = ctx.itemAs!"editline"(item)) {
    auto ed = edl.ed;
    if (ed is null) return null;
    char[] res;
    auto rng = ed[];
    res.reserve(rng.length);
    foreach (char ch; rng) res ~= ch;
    return res;
  }
  return null;
}


char[] edittextGetText (FuiContext ctx, int item) {
  if (auto edl = ctx.itemAs!"edittext"(item)) {
    auto ed = edl.ed;
    if (ed is null) return null;
    char[] res;
    auto rng = ed[];
    res.reserve(rng.length);
    foreach (char ch; rng) res ~= ch;
    return res;
  }
  return null;
}


// ////////////////////////////////////////////////////////////////////////// //
mixin template FuiCtlBtnLike() {
  mixin FuiCtlHeader;
  char hotchar = 0;
  bool spaceClicks = true;
  bool enterClicks = false;
align(8):
  // internal function, does some action on "click"
  // will be called before `actcb`
  // return `false` if click should not be processed further (no `actcb` will be called)
  bool delegate (FuiContext ctx, int self) doclickcb;
}

struct FuiCtlBtnLikeHead {
  mixin FuiCtlBtnLike;
}


private bool btnlikeClick (FuiContext ctx, int item, int clickButton=-1) {
  if (auto lp = ctx.layprops(item)) {
    if (!lp.visible || lp.disabled || (clickButton >= 0 && lp.clickMask == 0)) return false;
    auto data = ctx.item!FuiCtlBtnLikeHead(item);
    bool clicked = false;
    if (clickButton >= 0) {
      foreach (ubyte shift; 0..8) {
        if (shift == clickButton && (lp.clickMask&(1<<shift)) != 0) { clicked = true; break; }
      }
    } else {
      clicked = true;
    }
    if (clicked) {
      if (data.doclickcb !is null) {
        if (!data.doclickcb(ctx, item)) return false;
      }
      if (data.actcb !is null) {
        auto rr = data.actcb(ctx, item);
        if (rr >= -1) {
          ctx.queueEvent(item, FuiEvent.Type.Close, rr);
          return true;
        }
      }
      //ctx.queueEvent(item, FuiEvent.Type.Click, bidx, ctx.lastButtons|(ctx.lastMods<<8));
      //ctx.queueEvent(item, FuiEvent.Type.Close, item);
      return true;
    }
  }
  return false;
}


private int buttonLike(T, FuiCtlType type) (FuiContext ctx, int parent, const(char)[] id, const(char)[] text) {
  if (!ctx.valid) return -1;
  auto item = ctx.addItem!T(parent);
  auto data = ctx.item!T(item);
  data.type = type;
  //data.pal = Palette.init;
  if (text.length > 255) text = text[0..255];
  if (id.length > 255) id = id[0..255];
  data.id.setz(id);
  data.caption.setz(text);
  if (text.length) {
    data.hotchar = visHotChar(text).toupper;
  } else {
    data.hotchar = 0;
  }
  with (ctx.layprops(item)) {
    flex = 0;
    minSize = FuiSize(visStrLen(data.caption.getz), 1);
    clickMask |= FuiLayoutProps.Buttons.Left;
  }
  data.eventcb = delegate (FuiContext ctx, int self, FuiEvent ev) {
    final switch (ev.type) {
      case FuiEvent.Type.None:
        return false;
      case FuiEvent.Type.Char: // param0: dchar; param1: mods&buttons
        if (ev.item != self) return false;
        auto data = ctx.item!FuiCtlBtnLikeHead(self);
        if (!data.spaceClicks) return false;
        if (ev.ch != ' ') return false;
        if (auto lp = ctx.layprops(self)) {
          if (!lp.visible || lp.disabled) return false;
          if (lp.canBeFocused) ctx.focused = self;
          return ctx.btnlikeClick(self);
        }
        return false;
      case FuiEvent.Type.Key: // param0: sdpy keycode; param1: mods&buttons
        auto data = ctx.item!FuiCtlBtnLikeHead(self);
        auto lp = ctx.layprops(self);
        if (!lp.visible || lp.disabled) return false;
        if (data.enterClicks && ev.item == self && ev.key == "Enter") {
          if (lp.canBeFocused) ctx.focused = self;
          return ctx.btnlikeClick(self);
        }
        if (ev.key.key != TtyKey.Key.ModChar || ev.key.ctrl || !ev.key.alt || ev.key.shift) return false;
        if (data.hotchar != ev.key.ch) return false;
        if (lp.canBeFocused) ctx.focused = self;
        ctx.btnlikeClick(self);
        return true;
      case FuiEvent.Type.Click: // mouse click; param0: buttton index; param1: mods&buttons
        if (ev.item == self) return ctx.btnlikeClick(self, ev.param0);
        return false;
      case FuiEvent.Type.Double: // mouse double-click; param0: buttton index; param1: mods&buttons
        return false;
      case FuiEvent.Type.Close: // close dialog; param0: return id
        return false;
    }
  };
  return item;
}


// ////////////////////////////////////////////////////////////////////////// //
struct FuiCtlLabel {
  mixin FuiCtlBtnLike;
  ubyte destlen;
  char[256] dest;
}

int label (FuiContext ctx, int parent, const(char)[] id, const(char)[] text, const(char)[] destid=null) {
  auto res = ctx.buttonLike!(FuiCtlLabel, FuiCtlType.Label)(parent, id, text);
  auto data = ctx.item!FuiCtlLabel(res);
  data.dest.setz(destid);
  if (destid.length == 0) {
    data.hotchar = 0;
    ctx.layprops(res).minSize.w = visStrLen!false(data.caption.getz);
    ctx.layprops(res).clickMask = 0;
  }
  data.spaceClicks = data.enterClicks = false;
  data.drawcb = delegate (FuiContext ctx, int self, FuiRect rc) {
    auto data = ctx.item!FuiCtlLabel(self);
    auto lp = ctx.layprops(self);
    auto win = XtWindow.fullscreen;
    uint anorm, ahot;
    if (lp.enabled) {
      anorm = ctx.palColor!"def"(self);
      ahot = ctx.palColor!"hot"(self);
    } else {
      anorm = ahot = ctx.palColor!"disabled"(self);
    }
    if (data.hotchar) {
      win.tuiWriteStr!("right", false)(rc.x, rc.y, rc.w, data.caption.getz, anorm, ahot);
    } else {
      win.tuiWriteStr!("right", false, false)(rc.x, rc.y, rc.w, data.caption.getz, anorm, ahot);
    }
  };
  data.doclickcb = delegate (FuiContext ctx, int self) {
    auto data = ctx.item!FuiCtlLabel(self);
    auto did = ctx.findById(data.dest.getz);
    if (did <= 0) return false;
    if (auto lp = ctx.layprops(did)) {
      if (lp.canBeFocused && lp.visible && lp.enabled) {
        ctx.focused = did;
        return true;
      }
    }
    return false;
  };
  return res;
}


// ////////////////////////////////////////////////////////////////////////// //
struct FuiCtlButton {
  mixin FuiCtlBtnLike;
}

int button (FuiContext ctx, int parent, const(char)[] id, const(char)[] text) {
  auto item = ctx.buttonLike!(FuiCtlButton, FuiCtlType.Button)(parent, id, text);
  if (item >= 0) {
    with (ctx.layprops(item)) {
      //clickMask |= FuiLayoutProps.Buttons.Left;
      canBeFocused = true;
      minSize.w += 4;
    }
    auto data = ctx.item!FuiCtlButton(item);
    data.spaceClicks = data.enterClicks = true;
    data.drawcb = delegate (FuiContext ctx, int self, FuiRect rc) {
      auto data = ctx.item!FuiCtlButton(self);
      auto lp = ctx.layprops(self);
      auto win = XtWindow.fullscreen;
      uint anorm, ahot;
      int hotx = rc.x;
      if (lp.enabled) {
        if (ctx.focused != self) {
          anorm = ctx.palColor!"def"(self);
          ahot = ctx.palColor!"hot"(self);
        } else {
          anorm = ctx.palColor!"sel"(self);
          ahot = ctx.palColor!"hotsel"(self);
        }
      } else {
        anorm = ahot = ctx.palColor!"disabled"(self);
      }
      win.color = anorm;
      bool def = ((lp.userFlags&FuiCtlUserFlags.Default) != 0);
      if (rc.w == 1) {
        win.writeCharsAt!true(rc.x, rc.y, 1, '`');
      } else if (rc.w == 2) {
        win.writeStrAt(rc.x, rc.y, (def ? "<>" : "[]"));
      } else if (rc.w > 2) {
        win.writeCharsAt(rc.x, rc.y, rc.w, ' ');
        if (def) {
          win.writeCharsAt(rc.x+1, rc.y, 1, '<');
          win.writeCharsAt(rc.x+rc.w-2, rc.y, 1, '>');
        }
        win.writeCharsAt(rc.x, rc.y, 1, '[');
        win.writeCharsAt(rc.x+rc.w-1, rc.y, 1, ']');
        hotx = rc.x+1;
        win.tuiWriteStr!("center", false)(rc.x+2, rc.y, rc.w-4, data.caption.getz, anorm, ahot, &hotx);
      }
      if (ctx.focused == self) win.gotoXY(hotx, rc.y);
    };
    data.doclickcb = delegate (FuiContext ctx, int self) {
      // send "close" to root
      ctx.queueEvent(0, FuiEvent.Type.Close, self);
      return true;
    };
  }
  return item;
}


// ////////////////////////////////////////////////////////////////////////// //
private void drawCheckRadio(string type) (FuiContext ctx, int self, FuiRect rc, const(char)[] text, bool marked) {
  static assert(type == "checkbox" || type == "radio");
  auto lp = ctx.layprops(self);
  auto win = XtWindow.fullscreen;
  uint anorm, ahot;
  int hotx = rc.x;
  if (lp.enabled) {
    if (ctx.focused != self) {
      anorm = ctx.palColor!"def"(self);
      ahot = ctx.palColor!"hot"(self);
    } else {
      anorm = ctx.palColor!"sel"(self);
      ahot = ctx.palColor!"hotsel"(self);
    }
  } else {
    anorm = ahot = ctx.palColor!"disabled"(self);
  }
  win.color = anorm;
  win.writeCharsAt(rc.x, rc.y, rc.w, ' ');
  char markCh = ' ';
  if (marked) {
         static if (type == "checkbox") markCh = 'x';
    else static if (type == "radio") markCh = '*';
    else static assert(0, "wtf?!");
  }
  if (rc.w == 1) {
    win.writeCharsAt(rc.x, rc.y, 1, markCh);
  } else if (rc.w == 2) {
    win.writeCharsAt(rc.x, rc.y, 1, markCh);
    win.writeCharsAt(rc.x+1, rc.y, 1, ' ');
  } else if (rc.w > 2) {
         static if (type == "checkbox") win.writeStrAt(rc.x, rc.y, "[ ]");
    else static if (type == "radio") win.writeStrAt(rc.x, rc.y, "( )");
    else static assert(0, "wtf?!");
    if (markCh != ' ') win.writeCharsAt(rc.x+1, rc.y, 1, markCh);
    hotx = rc.x+1;
    win.tuiWriteStr!("left", false)(rc.x+4, rc.y, rc.w-4, text, anorm, ahot);
  }
  if (ctx.focused == self) win.gotoXY(hotx, rc.y);
}


struct FuiCtlCheck {
  mixin FuiCtlBtnLike;
  bool* var;
}

int checkbox (FuiContext ctx, int parent, const(char)[] id, const(char)[] text, bool* var) {
  auto item = ctx.buttonLike!(FuiCtlCheck, FuiCtlType.Check)(parent, id, text);
  if (item >= 0) {
    auto data = ctx.item!FuiCtlCheck(item);
    data.spaceClicks = true;
    data.enterClicks = false;
    data.var = var;
    with (ctx.layprops(item)) {
      //clickMask |= FuiLayoutProps.Buttons.Left;
      canBeFocused = true;
      minSize.w += 4;
    }
    data.drawcb = delegate (FuiContext ctx, int self, FuiRect rc) {
      auto data = ctx.item!FuiCtlCheck(self);
      bool marked = (data.var !is null ? *data.var : false);
      ctx.drawCheckRadio!"checkbox"(self, rc, data.caption.getz, marked);
    };
    data.doclickcb = delegate (FuiContext ctx, int self) {
      auto data = ctx.item!FuiCtlCheck(self);
      if (data.var !is null) *data.var = !*data.var;
      return true;
    };
  }
  return item;
}


// ////////////////////////////////////////////////////////////////////////// //
struct FuiCtlRadio {
  mixin FuiCtlBtnLike;
  int gid; // radio group index; <0: standalone
  int* var;
}

private int countRadio (FuiContext ctx, int* var) {
  if (!ctx.valid || var is null) return -1;
  int res = 0;
  foreach (int fid; 1..ctx.length) {
    if (auto data = ctx.item!FuiCtlRadio(fid)) {
      if (data.type == FuiCtlType.Radio) {
        if (data.var is var) ++res;
      }
    }
  }
  return res;
}

int radio (FuiContext ctx, int parent, const(char)[] id, const(char)[] text, int* var) {
  auto item = ctx.buttonLike!(FuiCtlRadio, FuiCtlType.Radio)(parent, id, text);
  if (item >= 0) {
    auto gid = ctx.countRadio(var);
    auto data = ctx.item!FuiCtlRadio(item);
    data.spaceClicks = true;
    data.enterClicks = false;
    data.var = var;
    data.gid = gid;
    with (ctx.layprops(item)) {
      flex = 0;
      //clickMask |= FuiLayoutProps.Buttons.Left;
      canBeFocused = true;
      minSize.w += 4;
    }
    data.drawcb = delegate (FuiContext ctx, int self, FuiRect rc) {
      auto data = ctx.item!FuiCtlRadio(self);
      bool marked = (data.var ? (*data.var == data.gid) : false);
      ctx.drawCheckRadio!"radio"(self, rc, data.caption.getz, marked);
    };
    data.doclickcb = delegate (FuiContext ctx, int self) {
      auto data = ctx.item!FuiCtlRadio(self);
      if (data.var !is null) *data.var = data.gid;
      return true;
    };
  }
  return item;
}


// ////////////////////////////////////////////////////////////////////////// //
struct FuiCtlTextView {
  mixin FuiCtlHeader;
  uint textlen;
  int topline;
  char[0] text; // this *will* be modified by wrapper; '\1' is "soft wrap"; '\0' is EOT
}


// `actcb` will be called *after* editor was changed (or not changed, who knows)
int textview (FuiContext ctx, int parent, const(char)[] id, const(char)[] text) {
  if (!ctx.valid) return -1;
  if (text.length > 256*1024) throw new Exception("text view: text too long");
  auto item = ctx.addItem!FuiCtlTextView(parent, cast(int)text.length+256);
  with (ctx.layprops(item)) {
    flex = 1;
    aligning = FuiLayoutProps.Align.Stretch;
    clickMask |= FuiLayoutProps.Buttons.WheelUp|FuiLayoutProps.Buttons.WheelDown;
    //canBeFocused = true;
  }
  auto data = ctx.item!FuiCtlTextView(item);
  data.type = FuiCtlType.TextView;
  //data.pal = Palette.init;
  data.id.setz(id);
  data.textlen = cast(uint)text.length;
  if (text.length > 0) {
    data.text.ptr[0..text.length] = text[];
    int c, r;
    data.textlen = calcTextBoundsEx(c, r, data.text.ptr[0..data.textlen], ttyw-8);
    //with (ctx.layprops(item).maxSize) { w = c; h = r; }
    with (ctx.layprops(item).minSize) { w = c+2; h = r; }
    //with (ctx.layprops(item).minSize) { w = 2; h = 1; }
  }
  data.drawcb = delegate (FuiContext ctx, int self, FuiRect rc) {
    if (rc.w < 1 || rc.h < 1) return;
    auto data = ctx.item!FuiCtlTextView(self);
    auto lp = ctx.layprops(self);
    //auto win = XtWindow.fullscreen;
    auto win = XtWindow(rc.x, rc.y, rc.w, rc.h);
    if (lp.enabled) {
      win.color = ctx.palColor!"def"(self);
    } else {
      win.color = ctx.palColor!"disabled"(self);
    }
    //win.fill(rc.x, rc.y, rc.w, rc.h);
    win.fill(0, 0, rc.w, rc.h);
    if (data.textlen) {
      int c, r;
      data.textlen = calcTextBoundsEx(c, r, data.text.ptr[0..data.textlen], rc.w-lp.padding.left-lp.padding.right);
      if (data.topline < 0) data.topline = 0;
      if (data.topline+rc.h >= r) {
        data.topline = r-rc.h;
        if (data.topline < 0) data.topline = 0;
      }
      bool wantSBar = (r > rc.h);
      int xofs = (wantSBar ? 2 : 1);
      uint tpos = 0;
      int ty = -data.topline;
      int talign = 0; // 0: left; 1: right; 2: center;
      if (data.textlen > 0 && data.text.ptr[0] >= 1 && data.text.ptr[0] <= 3) {
        talign = data.text.ptr[tpos]-1;
        ++tpos;
      }
      while (tpos < data.textlen && ty < rc.h) {
        uint epos = tpos;
        while (epos < data.textlen && data.text.ptr[epos] != '\n' && data.text.ptr[epos] != '\6') {
          if (epos-tpos == rc.w) break;
          ++epos;
        }
        final switch (talign) {
          case 0: // left
            win.writeStrAt(xofs, ty, data.text.ptr[tpos..epos]);
            break;
          case 1: // right
            win.writeStrAt(rc.w-xofs-(epos-tpos), ty, data.text.ptr[tpos..epos]);
            break;
          case 2: // center
            win.writeStrAt(xofs+(rc.w-xofs-(epos-tpos))/2, ty, data.text.ptr[tpos..epos]);
            break;
        }
        if (epos < data.textlen && data.text.ptr[epos] <= ' ') {
          if (data.textlen-epos > 1 && data.text.ptr[epos] == '\n' && data.text.ptr[epos+1] >= 1 && data.text.ptr[epos+1] <= 3) {
            ++epos;
            talign = data.text.ptr[epos]-1;
          } else {
            // keep it
            //talign = 0;
          }
          ++epos;
        }
        tpos = epos;
        ++ty;
      }
      // draw scrollbar
      if (wantSBar) {
        //win.color = atext;
        win.vline(1, 0, rc.h);
        int last = data.topline+rc.h;
        if (last > r) last = r;
        last = rc.h*last/r;
        foreach (int yy; 0..rc.h) win.writeCharsAt!true(0, yy, 1, (yy <= last ? 'a' : ' '));
      }
    }
  };
  data.eventcb = delegate (FuiContext ctx, int self, FuiEvent ev) {
    if (ev.item != self) return false;
    final switch (ev.type) {
      case FuiEvent.Type.None:
        return false;
      case FuiEvent.Type.Char: // param0: dchar; param1: mods&buttons
        return false;
      case FuiEvent.Type.Key: // param0: sdpy keycode; param1: mods&buttons
        auto lp = ctx.layprops(self);
        if (lp !is null) {
          if (!lp.visible || lp.disabled) return false;
        } else {
          return false;
        }
        if (auto tv = ctx.itemAs!"textview"(self)) {
          if (ev.key == "Up") { --tv.topline; return true; }
          if (ev.key == "Down") { ++tv.topline; return true; }
          if (ev.key == "Home") { tv.topline = 0; return true; }
          if (ev.key == "End") { tv.topline = int.max/2; return true; }
          int pgstep = lp.position.h-1;
          if (pgstep < 1) pgstep = 1;
          if (ev.key == "PageUp") { tv.topline -= pgstep; return true; }
          if (ev.key == "PageDown") { tv.topline += pgstep; return true; }
        }
        return false;
      case FuiEvent.Type.Click: // mouse click; param0: buttton index; param1: mods&buttons
        return false;
      case FuiEvent.Type.Double: // mouse double-click; param0: buttton index; param1: mods&buttons
        return false;
      case FuiEvent.Type.Close: // close dialog; param0: return id
        return false;
    }
  };
  return item;
}


// ////////////////////////////////////////////////////////////////////////// //
struct FuiCtlListBoxItem {
  uint nextofs;
  uint length;
  char[0] text;
}

struct FuiCtlListBox {
  mixin FuiCtlHeader;
  int itemCount; // total number of items
  int topItem;
  int curItem;
  int maxWidth;
  uint firstItemOffset; // in layout buffer
  uint lastItemOffset; // in layout buffer
  uint topItemOffset; // in layout buffer
}


// return `true` if it has scrollbar
private bool listboxNorm (FuiContext ctx, int item) {
  auto data = ctx.item!FuiCtlListBox(item);
  if (data is null) return false;
  auto lp = ctx.layprops(item);
  // make current item visible
  if (data.itemCount == 0) return false;
  // sanitize current item (just in case, it should be sane always)
  if (data.curItem < 0) data.curItem = 0;
  if (data.curItem >= data.itemCount) data.curItem = data.itemCount-1;
  int oldtop = data.topItem;
  if (data.topItem > data.itemCount-lp.position.h) data.topItem = data.itemCount-lp.position.h;
  if (data.topItem < 0) data.topItem = 0;
  if (data.curItem < data.topItem) {
    data.topItem = data.curItem;
  } else if (data.topItem+lp.position.h <= data.curItem) {
    data.topItem = data.curItem-lp.position.h+1;
    if (data.topItem < 0) data.topItem = 0;
  }
  if (data.topItem != oldtop || data.topItemOffset == 0) {
    data.topItemOffset = ctx.listboxItemOffset(item, data.topItem);
    assert(data.topItemOffset != 0);
  }
  bool wantSBar = false;
  // should i draw a scrollbar?
  if (lp.position.w > 2 && (data.topItem > 0 || data.topItem+lp.position.h < data.itemCount)) {
    // yes
    wantSBar = true;
  }
  return wantSBar;
}


// `actcb` will be called *after* editor was changed (or not changed, who knows)
int listbox (FuiContext ctx, int parent, const(char)[] id) {
  if (!ctx.valid) return -1;
  auto item = ctx.addItem!FuiCtlListBox(parent);
  if (item == -1) return -1;
  with (ctx.layprops(item)) {
    flex = 1;
    aligning = FuiLayoutProps.Align.Stretch;
    clickMask |= FuiLayoutProps.Buttons.Left|FuiLayoutProps.Buttons.WheelUp|FuiLayoutProps.Buttons.WheelDown;
    canBeFocused = true;
    minSize = FuiSize(5, 2);
  }
  auto data = ctx.item!FuiCtlListBox(item);
  data.type = FuiCtlType.ListBox;
  //data.pal = Palette.init;
  data.id.setz(id);
  data.drawcb = delegate (FuiContext ctx, int self, FuiRect rc) {
    auto data = ctx.item!FuiCtlListBox(self);
    auto lp = ctx.layprops(self);
    auto win = XtWindow.fullscreen;
    // get colors
    uint atext, asel, agauge;
    if (lp.enabled) {
      atext = ctx.palColor!"def"(self);
      asel = ctx.palColor!"sel"(self);
      agauge = ctx.palColor!"gauge"(self);
    } else {
      atext = asel = agauge = ctx.palColor!"disabled"(self);
    }
    win.color = atext;
    win.fill(rc.x, rc.y, rc.w, rc.h);
    // make current item visible
    if (data.itemCount == 0) return;
    // sanitize current item (just in case, it should be sane always)
    if (data.curItem < 0) data.curItem = 0;
    if (data.curItem >= data.itemCount) data.curItem = data.itemCount-1;
    int oldtop = data.topItem;
    if (data.topItem > data.itemCount-rc.h) data.topItem = data.itemCount-rc.h;
    if (data.topItem < 0) data.topItem = 0;
    if (data.curItem < data.topItem) {
      data.topItem = data.curItem;
    } else if (data.topItem+rc.h <= data.curItem) {
      data.topItem = data.curItem-rc.h+1;
      if (data.topItem < 0) data.topItem = 0;
    }
    if (data.topItem != oldtop || data.topItemOffset == 0) {
      data.topItemOffset = ctx.listboxItemOffset(self, data.topItem);
      assert(data.topItemOffset != 0);
    }
    bool wantSBar = false;
    int wdt = rc.w;
    int x = 0, y = 0;
    // should i draw a scrollbar?
    if (wdt > 2 && (data.topItem > 0 || data.topItem+rc.h < data.itemCount)) {
      // yes
      wantSBar = true;
      wdt -= 2;
      x += 2;
    } else {
      x += 1;
      wdt -= 1;
    }
    x += rc.x;
    // draw items
    auto itofs = data.topItemOffset;
    auto curit = data.topItem;
    while (itofs != 0 && y < rc.h) {
      auto it = ctx.structAtOfs!FuiCtlListBoxItem(itofs);
      auto t = it.text.ptr[0..it.length];
      if (t.length > wdt) t = t[0..wdt];
      if (curit == data.curItem) {
        win.color = asel;
        // fill cursor
        win.writeCharsAt(x-(wantSBar ? 0 : 1), rc.y+y, wdt+(wantSBar ? 0 : 1), ' ');
        if (self == ctx.focused) win.gotoXY(x-(wantSBar ? 0 : 1), rc.y+y);
      } else {
        win.color = atext;
      }
      win.writeStrAt(x, rc.y+y, t);
      itofs = it.nextofs;
      ++y;
      ++curit;
    }
    // draw scrollbar
    if (wantSBar) {
      x -= 2;
      win.color = atext;
      win.vline(x+1, rc.y, rc.h);
      win.color = agauge; //atext;
      int last = data.topItem+rc.h;
      if (last > data.itemCount) last = data.itemCount;
      last = rc.h*last/data.itemCount;
      foreach (int yy; 0..rc.h) win.writeCharsAt!true(x, rc.y+yy, 1, (yy <= last ? 'a' : ' '));
    }
  };
  data.eventcb = delegate (FuiContext ctx, int self, FuiEvent ev) {
    if (ev.item != self) return false;
    final switch (ev.type) {
      case FuiEvent.Type.None:
        return false;
      case FuiEvent.Type.Char: // param0: dchar; param1: mods&buttons
        return false;
      case FuiEvent.Type.Key: // param0: sdpy keycode; param1: mods&buttons
        if (auto lp = ctx.layprops(self)) {
          if (!lp.visible || lp.disabled) return false;
        } else {
          return false;
        }
        if (auto lbox = ctx.itemAs!"listbox"(self)) {
          bool procIt() () {
            auto lp = ctx.layprops(ev.item);
            if (ev.key == "Up") {
              if (--lbox.curItem < 0) lbox.curItem = 0;
              return true;
            }
            if (ev.key == "S-Up") {
              if (--lbox.topItem < 0) lbox.topItem = 0;
              lbox.topItemOffset = 0; // invalidate
              return true;
            }
            if (ev.key == "Down") {
              if (lbox.itemCount > 0) {
                if (++lbox.curItem >= lbox.itemCount) lbox.curItem = lbox.itemCount-1;
              }
              return true;
            }
            if (ev.key == "S-Down") {
              if (lbox.topItem+lp.position.h < lbox.itemCount) {
                ++lbox.topItem;
                lbox.topItemOffset = 0; // invalidate
              }
              return true;
            }
            if (ev.key == "Home") {
              lbox.curItem = 0;
              return true;
            }
            if (ev.key == "End") {
              if (lbox.itemCount > 0) lbox.curItem = lbox.itemCount-1;
              return true;
            }
            if (ev.key == "PageUp") {
              if (lbox.curItem > lbox.topItem) {
                lbox.curItem = lbox.topItem;
              } else if (lp.position.h > 1) {
                if ((lbox.curItem -= lp.position.h-1) < 0) lbox.curItem = 0;
              }
              return true;
            }
            if (ev.key == "PageDown") {
              if (lbox.curItem < lbox.topItem+lp.position.h-1) {
                lbox.curItem = lbox.topItem+lp.position.h-1;
              } else if (lp.position.h > 1 && lbox.itemCount > 0) {
                if ((lbox.curItem += lp.position.h-1) >= lbox.itemCount) lbox.curItem = lbox.itemCount-1;
              }
              return true;
            }
            return false;
          }
          ctx.listboxNorm(self);
          auto oldCI = lbox.curItem;
          if (procIt()) {
            ctx.listboxNorm(self);
            if (oldCI != lbox.curItem && lbox.actcb !is null) {
              auto rr = lbox.actcb(ctx, self);
              if (rr >= -1) ctx.queueEvent(ev.item, FuiEvent.Type.Close, rr);
            }
          }
          return true;
        }
        return false;
      case FuiEvent.Type.Click: // mouse click; param0: buttton index; param1: mods&buttons
        if (auto lbox = ctx.itemAs!"listbox"(self)) {
          ctx.listboxNorm(self);
          auto oldCI = lbox.curItem;
          if (ev.bidx == FuiLayoutProps.Button.WheelUp) {
            if (--lbox.curItem < 0) lbox.curItem = 0;
          } else if (ev.bidx == FuiLayoutProps.Button.WheelDown) {
            if (lbox.itemCount > 0) {
              if (++lbox.curItem >= lbox.itemCount) lbox.curItem = lbox.itemCount-1;
            }
          } else if (ev.x > 0) {
            int it = ev.y-lbox.topItem;
            lbox.curItem = it;
          }
          ctx.listboxNorm(self);
          if (oldCI != lbox.curItem && lbox.actcb !is null) {
            auto rr = lbox.actcb(ctx, self);
            if (rr >= -1) ctx.queueEvent(ev.item, FuiEvent.Type.Close, rr);
          }
        }
        return true;
      case FuiEvent.Type.Double: // mouse double-click; param0: buttton index; param1: mods&buttons
        return false;
      case FuiEvent.Type.Close: // close dialog; param0: return id
        return false;
    }
  };
  return item;
}


void listboxItemAdd (FuiContext ctx, int item, const(char)[] text) {
  if (auto data = ctx.itemAs!"listbox"(item)) {
    int len = (text.length < 255 ? cast(int)text.length : 255);
    uint itofs;
    auto it = ctx.addStruct!FuiCtlListBoxItem(itofs, len);
    it.length = len;
    if (text.length <= 255) {
      it.text.ptr[0..text.length] = text[];
    } else {
      it.text.ptr[0..256] = text[0..256];
      it.text.ptr[253..256] = '.';
    }
    if (data.maxWidth < len) data.maxWidth = len;
    if (data.firstItemOffset == 0) {
      data.firstItemOffset = itofs;
      data.topItemOffset = itofs;
    } else {
      auto prev = ctx.structAtOfs!FuiCtlListBoxItem(data.lastItemOffset);
      prev.nextofs = itofs;
    }
    data.lastItemOffset = itofs;
    ++data.itemCount;
    auto lp = ctx.layprops(item);
    if (lp.minSize.w < len+3) lp.minSize.w = len+3;
    if (lp.minSize.h < data.itemCount) lp.minSize.h = data.itemCount;
    if (lp.minSize.w > lp.maxSize.w) lp.minSize.w = lp.maxSize.w;
    if (lp.minSize.h > lp.maxSize.h) lp.minSize.h = lp.maxSize.h;
  }
}


int listboxMaxItemWidth (FuiContext ctx, int item) {
  if (auto data = ctx.itemAs!"listbox"(item)) return data.maxWidth+2;
  return 0;
}


int listboxItemCount (FuiContext ctx, int item) {
  if (auto data = ctx.itemAs!"listbox"(item)) return data.itemCount;
  return 0;
}


int listboxItemCurrent (FuiContext ctx, int item) {
  if (auto data = ctx.itemAs!"listbox"(item)) return data.curItem;
  return 0;
}


void listboxItemSetCurrent (FuiContext ctx, int item, int cur) {
  if (auto data = ctx.itemAs!"listbox"(item)) {
    if (data.itemCount > 0) {
      if (cur < 0) cur = 0;
      if (cur > data.itemCount) cur = data.itemCount-1;
      data.curItem = cur;
    }
  }
}


private uint listboxItemOffset (FuiContext ctx, int item, int inum) {
  if (auto data = ctx.itemAs!"listbox"(item)) {
    if (inum > data.itemCount) inum = data.itemCount-1;
    if (inum < 0) inum = 0;
    uint itofs = data.firstItemOffset;
    while (inum-- > 0) {
      assert(itofs > 0);
      auto it = ctx.structAtOfs!FuiCtlListBoxItem(itofs);
      if (it.nextofs == 0) break;
      itofs = it.nextofs;
    }
    return itofs;
  }
  return 0;
}


// ////////////////////////////////////////////////////////////////////////// //
// returned value valid until first layout change
const(char)[] itemId (FuiContext ctx, int item) nothrow @trusted @nogc {
  if (auto lp = ctx.item!FuiCtlHead(item)) return lp.id.getz;
  return null;
}


// ////////////////////////////////////////////////////////////////////////// //
// return item id or -1
int findById (FuiContext ctx, const(char)[] id) nothrow @trusted @nogc {
  foreach (int fid; 0..ctx.length) {
    if (auto data = ctx.item!FuiCtlHead(fid)) {
      if (data.id.getz == id) return fid;
    }
  }
  return -1;
}


auto itemAs(string type) (FuiContext ctx, int item) nothrow @trusted @nogc {
  if (!ctx.valid) return null;
  static if (type.strEquCI("hline")) {
    enum ctp = FuiCtlType.HLine;
    alias tp = FuiCtlSpan;
  } else static if (type.strEquCI("box") || type.strEquCI("vbox") || type.strEquCI("hbox")) {
    enum ctp = FuiCtlType.Box;
    alias tp = FuiCtlBox;
  } else static if (type.strEquCI("panel") || type.strEquCI("vpanel") || type.strEquCI("hpanel")) {
    enum ctp = FuiCtlType.Panel;
    alias tp = FuiCtlPanel;
  } else static if (type.strEquCI("editline")) {
    enum ctp = FuiCtlType.EditLine;
    alias tp = FuiCtlEditLine;
  } else static if (type.strEquCI("edittext")) {
    enum ctp = FuiCtlType.EditText;
    alias tp = FuiCtlEditLine;
  } else static if (type.strEquCI("label")) {
    enum ctp = FuiCtlType.Label;
    alias tp = FuiCtlLabel;
  } else static if (type.strEquCI("button")) {
    enum ctp = FuiCtlType.Button;
    alias tp = FuiCtlButton;
  } else static if (type.strEquCI("check") || type.strEquCI("checkbox")) {
    enum ctp = FuiCtlType.Check;
    alias tp = FuiCtlCheck;
  } else static if (type.strEquCI("radio") || type.strEquCI("radio")) {
    enum ctp = FuiCtlType.Radio;
    alias tp = FuiCtlRadio;
  } else static if (type.strEquCI("textview")) {
    enum ctp = FuiCtlType.TextView;
    alias tp = FuiCtlTextView;
  } else static if (type.strEquCI("listbox")) {
    enum ctp = FuiCtlType.ListBox;
    alias tp = FuiCtlListBox;
  } else static if (type.strEquCI("custombox")) {
    enum ctp = FuiCtlType.CustomBox;
    alias tp = FuiCtlCustomBox;
  } else {
    static assert(0, "invalid control type: '"~type~"'");
  }
  if (auto data = ctx.item!FuiCtlHead(item)) {
    if (data.type == ctp) return ctx.item!tp(item);
  }
  return null;
}


auto itemAs(string type) (FuiContext ctx, const(char)[] id) nothrow @trusted @nogc {
  if (!ctx.valid) return null;
  foreach (int fid; 0..ctx.length) {
    if (auto data = ctx.itemAs!type(fid)) {
      if (data.id.getz == id) return data;
    }
  }
  return null;
}


FuiCtlType itemType (FuiContext ctx, int item) nothrow @trusted @nogc {
  if (!ctx.valid) return FuiCtlType.Invisible;
  if (auto data = ctx.itemIntr!FuiCtlHead(item)) return data.type;
  return FuiCtlType.Invisible;
}


// ////////////////////////////////////////////////////////////////////////// //
void focusFirst (FuiContext ctx) nothrow @trusted @nogc {
  if (!ctx.valid) return;
  auto fid = ctx.focused;
  if (fid < 1 || fid >= ctx.length) fid = 0;
  auto lp = ctx.layprops(fid);
  if (fid < 1 || fid >= ctx.length || !lp.visible || !lp.enabled || !lp.canBeFocused) {
    for (fid = 1; fid < ctx.length; ++fid) {
      lp = ctx.layprops(fid);
      if (lp is null) continue;
      if (lp.visible && lp.enabled && lp.canBeFocused) {
        ctx.focused = fid;
        return;
      }
    }
  }
}


int findDefault (FuiContext ctx) nothrow @trusted @nogc {
  if (!ctx.valid) return -1;
  foreach (int fid; 0..ctx.length) {
    if (auto lp = ctx.layprops(fid)) {
      if (lp.visible && lp.enabled && lp.canBeFocused && (lp.userFlags&FuiCtlUserFlags.Default) != 0) return fid;
    }
  }
  return -1;
}


// ////////////////////////////////////////////////////////////////////////// //
void dialogPalette (FuiContext ctx, int palidx) {
  if (palidx < 0 || palidx >= tuiPalette.length) palidx = 0;
  if (auto data = ctx.itemIntr!FuiCtlHead(0)) {
    data.pal = tuiPalette[palidx];
  }
}


void palColor(string name) (FuiContext ctx, int itemid, uint clr) {
  if (auto data = ctx.item!FuiCtlHead(itemid)) {
    mixin("data.pal."~name~" = clr;");
  }
}


// ////////////////////////////////////////////////////////////////////////// //
uint palColor(string name) (FuiContext ctx, int itemid) {
  uint res;
  for (;;) {
    if (auto data = ctx.itemIntr!FuiCtlHead(itemid)) {
      res = mixin("data.pal."~name);
      if (res) break;
      itemid = ctx.layprops(itemid).parent;
    } else {
      res = mixin("tuiPalette[TuiPaletteNormal]."~name);
      break;
    }
  }
  return (res ? res : XtColorFB!(ttyRgb2Color(0xd0, 0xd0, 0xd0), ttyRgb2Color(0x4e, 0x4e, 0x4e))); // 252,239
}


// ////////////////////////////////////////////////////////////////////////// //
private void tuiWriteStr(string defcenter, bool spaces, bool dohot=true) (auto ref XtWindow win, int x, int y, int w, const(char)[] s, uint attr, uint hotattr, int* hotx=null) {
  static assert(defcenter == "left" || defcenter == "right" || defcenter == "center");
  if (hotx !is null) *hotx = x;
  if (w < 1) return;
  win.color = attr;
  static if (spaces) { x += 1; w -= 2; }
  if (w < 1 || s.length == 0) return;
  int sx = x, ex = x+w-1;
  auto vislen = visStrLen!dohot(s);
  if (s.ptr[0] == '\x01') {
    // left, nothing to do
    s = s[1..$];
  } else if (s.ptr[0] == '\x02') {
    // right
    x += (w-vislen);
    s = s[1..$];
  } else if (s.ptr[0] == '\x03') {
    // center
    auto len = visStrLen(s);
    x += (w-len)/2;
    s = s[1..$];
  } else {
    static if (defcenter == "left") {
    } else static if (defcenter == "right") {
      x += (w-vislen);
    } else static if (defcenter == "center") {
      // center
      x += (w-vislen)/2;
    }
  }
  bool wasHot;
  static if (spaces) {
    win.writeCharsAt(x-1, y, 1, ' ');
    int ee = x+vislen;
    if (ee <= ex+1) win.writeCharsAt(ee, y, 1, ' ');
  }
  while (s.length > 0) {
    if (dohot && s.length > 1 && s.ptr[0] == '&' && s.ptr[1] != '&') {
      if (!wasHot && hotx !is null) *hotx = x;
      if (x >= sx && x <= ex) {
        if (hotattr && !wasHot) win.color = hotattr;
        win.writeCharsAt(x, y, 1, s.ptr[1]);
        win.color = attr;
      }
      s = s[2..$];
      wasHot = true;
    } else if (dohot && s.length > 1 && s.ptr[0] == '&' && s.ptr[1] != '&') {
      if (x >= sx && x <= ex) win.writeCharsAt(x, y, 1, s.ptr[0]);
      s = s[2..$];
    } else {
      if (x >= sx && x <= ex) win.writeCharsAt(x, y, 1, s.ptr[0]);
      s = s[1..$];
    }
    ++x;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
// we have to draw shadow separately, so it won't get darken each time
void drawShadow (FuiContext ctx) nothrow @trusted @nogc {
  if (!ctx.valid) return;
  auto lp = ctx.layprops(0);
  if (lp is null) return;
  auto rc = lp.position;
  xtShadowBox(rc.x+rc.w, rc.y+1, 2, rc.h-1);
  xtHShadow(rc.x+2, rc.y+rc.h, rc.w);
}


void draw (FuiContext ctx) {
  if (!ctx.valid) return;

  void drawItem (int item, FuiPoint g) {
    auto lp = ctx.layprops(item);
    if (lp is null) return;
    if (!lp.visible) return;

    // convert local coords to global coords
    auto rc = lp.position;
    // don't shift root panes, it is already shifted
    if (item != 0) {
      rc.xp += g.x;
      rc.yp += g.y;
    }

    if (item == 0) {
      auto anorm = ctx.palColor!"def"(item);
      auto atitle = ctx.palColor!"title"(item);
      auto win = XtWindow.fullscreen;
      win.color = anorm;
      if (rc.w > 0 && rc.h > 0) {
        auto data = ctx.itemIntr!FuiCtlRootPanel(0);
        win.fill(rc.x, rc.y, rc.w, rc.h);
        final switch (data.frame) {
          case FuiDialogFrameType.Normal:
            win.frame!false(rc.x+1, rc.y+1, rc.w-2, rc.h-2);
            win.tuiWriteStr!("center", true)(rc.x+1, rc.y+1, rc.w-2, data.caption.getz, atitle, atitle);
            break;
          case FuiDialogFrameType.Small:
            win.frame!false(rc.x, rc.y, rc.w, rc.h);
            win.tuiWriteStr!("center", true)(rc.x+1, rc.y, rc.w-2, data.caption.getz, atitle, atitle);
            break;
        }
      }
    } else {
      auto head = ctx.item!FuiCtlHead(item);
      if (head.drawcb !is null) head.drawcb(ctx, item, rc);
    }

    // draw children
    item = lp.firstChild;
    lp = ctx.layprops(item);
    if (lp is null) return;
    while (lp !is null) {
      drawItem(item, rc.pos);
      item = lp.nextSibling;
      lp = ctx.layprops(item);
    }
  }

  drawItem(0, ctx.layprops(0).position.pos);
}


// ////////////////////////////////////////////////////////////////////////// //
// returns `true` if event was consumed
bool processEvent (FuiContext ctx, FuiEvent ev) {
  if (!ctx.valid) return false;
  if (auto lp = ctx.layprops(ev.item)) {
    if (lp.visible && !lp.disabled) {
      auto data = ctx.item!FuiCtlHead(ev.item);
      if (data.eventcb !is null) {
        if (data.eventcb(ctx, ev.item, ev)) return true;
      }
    }
  }
  // event is not processed
  if (ev.type == FuiEvent.Type.Char) {
    // broadcast char as ModChar
    auto ch = ev.ch;
    if (ch > ' ' && ch < 256) ch = toupper(cast(char)ch);
    ev.type = FuiEvent.Type.Key;
    ev.keyp = TtyKey.init;
    ev.keyp.key = TtyKey.Key.ModChar;
    ev.keyp.ctrl = false;
    ev.keyp.alt = true;
    ev.keyp.shift = false;
    ev.keyp.ch = ch;
    //assert(ev.type == FuiEvent.Type.Key);
  } else {
    if (ev.type != FuiEvent.Type.Key) return false;
  }
  // do navigation
  if (ev.key == "Enter") {
    // either current or default
    auto def = ctx.findDefault;
    if (def >= 0) return ctx.btnlikeClick(def);
    if (auto rd = ctx.itemIntr!FuiCtlRootPanel(0)) {
      if (rd.enterclose) {
        // send "close" to root with root as result
        ctx.queueEvent(0, FuiEvent.Type.Close, 0);
        return true;
      }
    }
    return false;
  }
  if (ev.key == "Up" || ev.key == "Left") { ctx.focusPrev(); return true; }
  if (ev.key == "Down" || ev.key == "Right") { ctx.focusNext(); return true; }
  // broadcast ModChar, so widgets can process hotkeys
  if (ev.key.key == TtyKey.Key.ModChar && !ev.key.ctrl && ev.key.alt && !ev.key.shift) {
    auto res = ctx.findNextEx(0, (int id) {
      if (auto lp = ctx.layprops(id)) {
        if (lp.visible && !lp.disabled) {
          auto data = ctx.item!FuiCtlHead(id);
          if (data.eventcb !is null) {
            if (data.eventcb(ctx, id, ev)) return true;
          }
        }
      }
      return false;
    });
    if (res >= 0) return true;
  }
  return false;
}


// ////////////////////////////////////////////////////////////////////////// //
__gshared FuiContext tuiCurrentContext;

// returns clicked item or -1 for esc
int modalDialog (FuiContext ctx) {
  if (!ctx.valid) return -1;

  scope(exit) {
    import core.memory : GC;
    GC.collect;
    GC.minimize;
  }

  void saveArea () {
    xtPushArea(
      ctx.layprops(0).position.x, ctx.layprops(0).position.y,
      ctx.layprops(0).position.w+2, ctx.layprops(0).position.h+1
    );
  }

  int processContextEvents () {
    ctx.update();
    while (ctx.hasEvents) {
      auto ev = ctx.getEvent();
      if (ev.type == FuiEvent.Type.Close) return ev.param0;
      if (ctx.processEvent(ev)) continue;
    }
    return -666;
  }

  //FIXME: center if coords are zero
  if (auto lp = ctx.layprops(0)) {
    if (lp.position.x == 0) lp.position.x = (ttyw-lp.position.w)/2;
    if (lp.position.y == 0) lp.position.y = (ttyh-lp.position.h)/2;
  }
  ctx.focusFirst();

  auto octx = tuiCurrentContext;
  tuiCurrentContext = ctx;
  scope(exit) tuiCurrentContext = octx;

  saveArea();
  scope(exit) xtPopArea();

  bool windowMoving;
  int wmX, wmY;

  ctx.drawShadow();
  for (;;) {
    int res = processContextEvents();
    if (res >= -1) return res;
    ctx.draw;
    xtFlush(); // show screen
    auto key = ttyReadKey(-1, TtyDefaultEscWait);
    /*
    if (key.mouse) {
      import std.format : format;
      xtWriteStrAt(0, 0, "x=%s; y=%s; item=%s".format(key.x, key.y, ctx.itemAt(FuiPoint(key.x, key.y))));
      xtFlush(); // show screen
      ttyReadKey(-1, TtyDefaultEscWait);
      continue;
    }
    */
    if (key.key == TtyKey.Key.Error) { return -1; }
    if (key.key == TtyKey.Key.Unknown) continue;
    if (key.key == TtyKey.Key.Escape) { return -1; }
    if (key == "^L") { xtFullRefresh(); continue; }
    int dx = 0, dy = 0;
    if (key == "M-Left") dx = -1;
    if (key == "M-Right") dx = 1;
    if (key == "M-Up") dy = -1;
    if (key == "M-Down") dy = 1;
    if (dx || dy) {
      xtPopArea();
      ctx.layprops(0).position.x = ctx.layprops(0).position.x+dx;
      ctx.layprops(0).position.y = ctx.layprops(0).position.y+dy;
      saveArea();
      ctx.drawShadow();
      continue;
    }
    ctx.keyboardEvent(key);
  }
}
