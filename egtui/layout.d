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
module iv.egtui.layout;

import iv.strex;
import iv.rawtty;

import iv.egtui.types;

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

  private union {
    struct {
      uint param0;
      uint param1;
      short mx, my; // coordinates *inside* item
    }
    TtyEvent paramkey;
  }

@property pure nothrow @safe @nogc:
  ref TtyEvent keyp () @trusted { pragma(inline, true); return paramkey; }
  TtyEvent key () @trusted { pragma(inline, true); return paramkey; }

@property const pure nothrow @safe @nogc:
  ubyte mods () { pragma(inline, true); return cast(ubyte)(param1>>8); }
  ubyte buts () { pragma(inline, true); return cast(ubyte)param1; }

  dchar ch () { pragma(inline, true); return cast(dchar)param0; }
  ubyte bidx () { pragma(inline, true); return cast(ubyte)param0; }
  short x () { pragma(inline, true); return mx; }
  short y () { pragma(inline, true); return my; }

  int result () { pragma(inline, true); return param0; }
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
      mx = cast(short)(aparam2&0xffff);
      my = cast(short)((aparam2>>16)&0xffff);
    }
  }

  void queueEvent (int aitem, FuiEvent.Type atype, TtyEvent akey) nothrow @trusted @nogc {
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
    TtyEvent kev;
    //MouseEvent mev;
    dchar cev;
  }
  private ExternalEvent[MaxQueuedExternalEvents] extEvents;
  uint extevHead, extevPos;

  void keyboardEvent (TtyEvent ev) nothrow @trusted @nogc {
    if (extevPos >= extEvents.length) return;
    if (ev.key == TtyEvent.Key.None) return;
    auto nn = (extevHead+extevPos++)%extEvents.length;
    if (ev.key == TtyEvent.Key.Char) {
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
          if (extEvents.ptr[extevHead].kev.key == TtyEvent.Key.Tab) {
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
          if (ev.button != TtyEvent.MButton.None) {
            if (ev.mpress || ev.mrelease) {
              newButtonState(ev.button-TtyEvent.MButton.First, ev.mpress);
            } else if (ev.mwheel) {
              // rawtty workaround
              newButtonState(ev.button-TtyEvent.MButton.First, true);
              newButtonState(ev.button-TtyEvent.MButton.First, false);
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

  void addRootPanel () {
    import iv.egtui.tui : FuiCtlRootPanel, FuiCtlType;
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

  // copypaste to allow dmdfe to inline things
  package(iv.egtui) inout(T)* itemIntr(T) (int idx) inout if (!is(T == class)) {
    pragma(inline, true);
    // size is aligned, so this static if
    static if (FuiLayoutProps.sizeof%8 != 0) {
      enum ofs = ((cast(uint)FuiLayoutProps.sizeof)|7)+1;
    } else {
      enum ofs = cast(uint)FuiLayoutProps.sizeof;
    }
    return (ctxp && idx >= 0 && idx < length ? cast(typeof(return))(ctx.pmem+ctx.pidx[idx]+ofs) : null);
  }

  // copypaste to allow dmdfe to inline things
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
        if (idx > 0) {
          lp.position = lp.position.init; // zero it out
        } else {
          lp.position.size = lp.position.size.init;
        }
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

      //FIXME: mark changed items and process only those
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
          //{ import core.stdc.stdio : printf; printf("grp=%d; gidx=%d\n", grp, groupLast[grp]); }
          while (layprops(gidx) !is null) {
            int it = gidx;
            while (layprops(it) !is null) {
              //{ import core.stdc.stdio : printf; printf(" === it=%d ===\n", it); }
              int itt = it;
              for (;;) {
                auto lp = layprops(itt);
                if (lp is null) break;
                //{ import core.stdc.stdio : printf; printf("  itt=%d\n", itt); }
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

  FuiPoint toGlobal (int item, FuiPoint pt) {
    return (ctxp ? ctx.toGlobal(item, pt) : pt);
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
  void keyboardEvent (TtyEvent ev) { pragma(inline, true); if (ctxp) ctx.keyboardEvent(ev); }
  //void charEvent (dchar ch) { pragma(inline, true); if (ctxp) ctx.charEvent(ch); }
  //void mouseEvent (MouseEvent ev) { pragma(inline, true); if (ctxp) ctx.mouseEvent(ev); }

  // don't pass anything to automatically calculate update delta
  void update (int msecDelta=-1) { pragma(inline, true); if (ctxp) ctx.update(msecDelta); }

  void queueEvent (int aitem, FuiEvent.Type atype, uint aparam0=0, uint aparam1=0) nothrow @trusted @nogc { pragma(inline, true); if (ctxp) ctx.queueEvent(aitem, atype, aparam0, aparam1); }
  bool hasEvents () const nothrow @trusted @nogc { pragma(inline, true); return (ctxp ? ctx.hasEvents() : false); }
  FuiEvent getEvent () nothrow @trusted @nogc { pragma(inline, true); return (ctxp ? ctx.getEvent() : FuiEvent.init); }

  @property ubyte lastButtons () nothrow @trusted @nogc { pragma(inline, true); return (ctxp ? ctx.lastButtons : 0); }
  @property ubyte lastMods () nothrow @trusted @nogc { pragma(inline, true); return (ctxp ? ctx.lastMods : 0); }

  int opIndex (const(char)[] id) nothrow @trusted @nogc {
    pragma(inline, true);
    import iv.egtui.tui : findById;
    return this.findById(id);
  }
}
