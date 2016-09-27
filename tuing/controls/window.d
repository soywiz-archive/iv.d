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
// top-level window
module iv.tuing.controls.window;

import iv.eventbus;
import iv.flexlayout;
import iv.strex;
import iv.rawtty2;

import iv.tuing.events;
import iv.tuing.tty;
import iv.tuing.tui;
import iv.tuing.types;


// ////////////////////////////////////////////////////////////////////////// //
public class FuiWindow : FuiControl {
  alias onMyEvent = super.onMyEvent;

  enum Frame : ubyte {
    Normal,
    Small,
    None,
  }
  Frame frame;
  FuiControl lastfct;
  FuiEventQueueDesk desk;
  bool shadowed = true;
  int[string] radios; // radio groups
  bool[string] checks; // checkboxes

  protected bool kbmoving;

  this () {
    this.connectListeners();
    super(null);
    vertical = true;
    aligning = Align.Start;
    maxSize.w = ttyw;
    maxSize.h = ttyh;
  }

  // call this after layouting
  void positionUnderControl (FuiControl c) {
    if (c is null) {
      pos.x = (ttyw-size.w)/2;
      pos.y = (ttyw-size.w)/2;
    } else {
      auto pt = c.toGlobal(FuiPoint(0, 1));
      if (pt.x+size.w > ttyw) pt.x = ttyw-size.w;
      if (pt.y+size.h > ttyh) pt.y = ttyh-size.h;
      pos.x = pt.x;
      pos.y = pt.y;
    }
  }

  // call this after layouting
  void positionCenterInControl (FuiControl c) {
    if (c is null) {
      pos.x = (ttyw-size.w)/2;
      pos.y = (ttyw-size.w)/2;
    } else {
      auto pt = c.toGlobal(FuiPoint(0, 0));
      pt.x += (c.size.w-size.w)/2;
      pt.y += (c.size.h-size.h)/2;
      if (pt.x+size.w > ttyw) pt.x = ttyw-size.w;
      if (pt.y+size.h > ttyh) pt.y = ttyh-size.h;
      pos.x = pt.x;
      pos.y = pt.y;
    }
  }

  void positionAtGlobal (FuiPoint pt) {
    if (pt.x+size.w > ttyw) pt.x = ttyw-size.w;
    if (pt.y+size.h > ttyh) {
      if (pt.y-size.h-2 >= 0) pt.y = pt.y-size.h-2; else pt.y = ttyh-size.h;
    }
    pos.x = pt.x;
    pos.y = pt.y;
  }

  final nothrow @safe {
    int radio(T : const(char)[]) (T id) {
      static if (is(T == typeof(null))) {
        return -1;
      } else {
        if (auto p = id in radios) return *p;
        return -1;
      }
    }

    void radio(T : const(char)[]) (T id, int v) {
      static if (!is(T == typeof(null))) {
        if (id.length > 0) {
          if (v == -1) { radios.remove(id); return; }
          static if (is(T == string)) {
            radios[id] = v;
          } else {
            radios[id.idup] = v;
          }
        }
      }
    }

    bool checkbox(T : const(char)[]) (T id) {
      static if (is(T == typeof(null))) {
        return false;
      } else {
        if (auto p = id in checks) return *p;
        return false;
      }
    }

    void checkbox(T : const(char)[]) (T id, bool v) {
      static if (!is(T == typeof(null))) {
        if (id.length > 0) {
          if (!v) { checks.remove(id); return; }
          static if (is(T == string)) {
            checks[id] = v;
          } else {
            checks[id.idup] = v;
          }
        }
      }
    }
  }

  final pure nothrow @safe @nogc {
    @property void defaultFocus (FuiControl c) {
      if (c.toplevel is this) lastfct = c;
    }

    FuiControl findLastToFocus () {
      FuiControl lastHit = null;
      // depth first
      void descend (FuiControl c) pure nothrow @safe @nogc {
        while (c !is null) {
          if (c.visible && c.enabled) {
            // check c first
            if (c.canBeFocused) lastHit = c;
            descend(c.firstChild);
          }
          c = c.nextSibling;
        }
      }
      descend(firstChild);
      return lastHit;
    }

    private FuiControl prevFocusableControl (FuiControl ctl) {
      if (ctl is null || ctl is this) return findLastToFocus();

      FuiControl lastHit = null;

      // depth first
      bool descend (FuiControl c) pure nothrow @safe @nogc {
        while (c !is null) {
          if (c is ctl) return true; // i found her
          // check c first, 'cause children are close to ctl
          if (c.canBeFocused) lastHit = c;
          if (descend(c.firstChild)) return true;
          c = c.nextSibling;
        }
        return false;
      }

      descend(firstChild);
      return lastHit;
    }

    FuiControl findFirstToFocus () {
      // depth first
      static FuiControl descend (FuiControl c) pure nothrow @safe @nogc {
        while (c !is null) {
          if (c.visible && c.enabled) {
            if (auto cx = descend(c.firstChild)) return cx;
            if (c.canBeFocused) return c;
          }
          c = c.nextSibling;
        }
        return null;
      }
      return descend(firstChild);
    }

    private FuiControl nextFocusableControl (FuiControl ctl) {
      if (ctl is null || ctl is this) return findFirstToFocus();

      bool ctlWasHit = false;

      // depth first
      FuiControl descend (FuiControl c) pure nothrow @safe @nogc {
        while (c !is null) {
          if (!ctlWasHit && c is ctl) ctlWasHit = true;
          if (auto cx = descend(c.firstChild)) return cx;
          if (ctlWasHit && c !is ctl && c.canBeFocused) return c;
          c = c.nextSibling;
        }
        return null;
      }

      return descend(firstChild);
    }

    FuiControl findPrevToFocus () { return prevFocusableControl(lastfct); }
    FuiControl findNextToFocus () { return nextFocusableControl(lastfct); }
  }

  void close (FuiControl closectl=null) { (new FuiEventClose(this, closectl)).post; }

  protected override void layoutingStarted () {
    final switch (frame) {
      case Frame.Normal: padding = FuiMargin(3, 2, 3, 2); break;
      case Frame.Small: padding = FuiMargin(1, 1, 1, 1); break;
      case Frame.None: padding = FuiMargin(0, 0, 0, 0); break;
    }
    super.layoutingStarted();
  }

  // this one is without scissors; used to draw shadows and hlines
  protected override void drawSelfPre (XtWindow win) {
    if (shadowed) {
      win.width = win.width+2;
      win.shadowBox(win.width-2, 1, 2, win.height);
      win.height = win.height+1;
      win.hshadow(2, win.height-1, win.width-2);
    }
  }

  protected override void drawSelf (XtWindow win) {
    win.color = (kbmoving ? palColor!"title" : palColor!"def"());
    win.fill(0, 0, win.width, win.height);
    final switch (frame) {
      case Frame.Normal:
        win.frame(1, 1, win.width-2, win.height-2);
        if (win.width <= 4) return;
        win.x0 = win.x0+2;
        win.width = win.width-4;
        win.y0 = win.y0+1;
        break;
      case Frame.Small:
        win.frame(0, 0, win.width, win.height);
        if (win.width <= 2) return;
        win.x0 = win.x0+1;
        win.width = win.width-2;
        break;
      case Frame.None:
        return;
    }
    if (caption.length == 0) return;
    //if (desk !is null && desk.isTopWindow(this)) win.color = palColor!"title"();
    if (focused) win.color = palColor!"title"();
    int x = (win.width-cast(int)caption.length)/2;
    // spaces around title
    win.fill(x-1, 0, cast(int)caption.length+2, 1);
    // title itself
    win.writeStrAt(x, 0, caption);
  }

  void doEventKey (FuiEventKey evt) {
    if (evt.key == "M-F4") {
      evt.eat();
      (new FuiEventClose(this, null)).post;
      return;
    }
    if (evt.key == "Tab" || evt.key == "Right" || evt.key == "Down") {
      evt.eat();
      (new FuiEventWinFocusNext(this)).post;
      return;
    }
    if (evt.key == "S-Tab" || evt.key == "C-Tab" || evt.key == "Up" || evt.key == "Left") {
      evt.eat();
      (new FuiEventWinFocusPrev(this)).post;
      return;
    }
    if (evt.bubbling) {
      if (evt.key == "Enter" || evt.key == "^Enter") {
        if (auto def = forEach((FuiControl ctl) => (ctl.visible && ctl.enabled && ctl.defctl))) {
          evt.eat();
          if (def.onAction !is null) def.onAction(def); else (new FuiEventClose(this, def)).post;
          return;
        }
      }
      if (evt.key == "Escape") {
        if (auto def = forEach((FuiControl ctl) => (ctl.visible && ctl.enabled && ctl.escctl))) {
          evt.eat();
          if (def.onAction !is null) def.onAction(def); else (new FuiEventClose(this, def)).post;
          return;
        }
      }
      forEach((FuiControl ctl) {
        if (ctl.hidden || ctl.disabled) return false;
        if (ctl.tryHotKey(evt.key)) { evt.eat(); ctl.doAction(); return true; }
        return false;
      });
      if (evt.key == "M-F5") {
        kbmoving = true;
        evt.eat();
        return;
      }
    }
  }

  override void onMyEvent (FuiEventBlur evt) { kbmoving = false; super.onMyEvent(evt); }

  void onSinkEvent (FuiEventKey evt) {
    if (kbmoving) {
      evt.eat();
      if (evt.key == "Left") pos.x = pos.x-1;
      if (evt.key == "Right") pos.x = pos.x+1;
      if (evt.key == "Up") pos.y = pos.y-1;
      if (evt.key == "Down") pos.y = pos.y+1;
      if (evt.key == "^Left") pos.x = pos.x-10;
      if (evt.key == "^Right") pos.x = pos.x+10;
      if (evt.key == "^Up") pos.y = pos.y-10;
      if (evt.key == "^Down") pos.y = pos.y+10;
      if (evt.key == "Escape" || evt.key == "Enter") kbmoving = false;
    }
  }

  void onMyEvent (FuiEventKey evt) { doEventKey(evt); }
  void onBubbleEvent (FuiEventKey evt) { doEventKey(evt); }

  void onSinkEvent (FuiEventFocusBlur evt) {
    if (auto ctl = cast(FuiControl)evt.source) {
      if (ctl !is this && ctl.toplevel is this) lastfct = ctl;
    }
  }
}
