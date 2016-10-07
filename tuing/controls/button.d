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
// button
module iv.tuing.controls.button;

import iv.eventbus;
import iv.flexlayout;
import iv.strex;
import iv.rawtty2;

import iv.tuing.events;
import iv.tuing.tty;
import iv.tuing.tui;
import iv.tuing.types;


// ////////////////////////////////////////////////////////////////////////// //
public class FuiButton : FuiControl {
  alias onMyEvent = super.onMyEvent;

  this (FuiControl aparent, string atext) {
    this.connectListeners();
    super(aparent);
    caption = atext;
    minSize.w = XtWindow.hotStrLen(atext)+4;
    horizontal = true;
    aligning = Align.Start;
    minSize.h = maxSize.h = 1;
    canBeFocused = true;
    hotkeyed = true;
    acceptClick(TtyEvent.MButton.Left);
    assert(clickMask != 0);
  }

  override void doAction () {
    if (canBeFocused) {
      if (auto desk = getDesk) desk.switchFocusTo(this, false);
    }
    if (onAction !is null) { onAction(this); return; }
    closetop;
  }

  protected override void drawSelf (XtWindow win) {
    win.color = (focused ? palColor!"sel"() : disabled ? palColor!"disabled"() : palColor!"def"());
    auto hotcolor = (focused ? palColor!"hotsel"() : disabled ? palColor!"disabled" : palColor!"hot"());
    win.fill(0, 0, win.width, win.height);
    if (defctl) {
      win.writeCharAt(0, 0, '<');
      win.writeCharAt(win.width-1, 0, '>');
    } else if (escctl) {
      win.writeCharAt(0, 0, '{');
      win.writeCharAt(win.width-1, 0, '}');
    } else {
      win.writeCharAt(0, 0, '[');
      win.writeCharAt(win.width-1, 0, ']');
    }
    win.writeHotStrAt(2, 0, win.width-4, caption, hotcolor, win.Align.Center, hotkeyed, focused);
  }

  void onMyEvent (FuiEventClick evt) {
    if (evt.left) {
      evt.eat();
      doAction();
    }
  }

  void onMyEvent (FuiEventKey evt) {
    if (evt.key == "Space" || evt.key == "Enter") { evt.eat(); doAction(); return; }
    if (tryHotKey(evt.key)) { evt.eat(); doAction(); return; }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
public class FuiCheckBox : FuiControl {
  alias onMyEvent = super.onMyEvent;

  string groupid;

  this (FuiControl aparent, string atext, string agroupid) {
    this.connectListeners();
    super(aparent);
    cbSetup(atext, agroupid);
  }

  this (FuiControl aparent, string atext, string agroupid, bool defval) {
    this.connectListeners();
    super(aparent);
    cbSetup(atext, agroupid);
    if (agroupid.length) {
      if (auto w = topwindow) w.checkbox(agroupid, defval);
    }
  }

  private final void cbSetup (string atext, string agroupid) {
    groupid = agroupid;
    caption = atext;
    minSize.w = XtWindow.hotStrLen(atext)+4;
    horizontal = true;
    aligning = Align.Start;
    minSize.h = maxSize.h = 1;
    canBeFocused = true;
    hotkeyed = true;
    acceptClick(TtyEvent.MButton.Left);
  }

  override void doAction () {
    if (canBeFocused) {
      if (auto desk = getDesk) desk.switchFocusTo(this, false);
    }
    if (onAction !is null) { onAction(this); return; }
    if (groupid.length) {
      if (auto w = topwindow) {
        auto nv = !w.checkbox(groupid);
        static assert(is(typeof(nv) == bool));
        w.checkbox(groupid, nv);
        (new FuiEventCheckBoxChanged(this, groupid, nv)).post;
      }
    }
  }

  protected override void drawSelf (XtWindow win) {
    win.color = (focused ? palColor!"sel"() : disabled ? palColor!"disabled"() : palColor!"def"());
    auto hotcolor = (focused ? palColor!"hotsel"() : disabled ? palColor!"disabled" : palColor!"hot"());
    win.fill(0, 0, win.width, win.height);
    win.writeStrAt(0, 0, "[ ]");
    if (auto w = topwindow) {
      if (w.checkbox(groupid)) win.writeCharAt(1, 0, 'x');
    }
    win.writeHotStrAt(4, 0, win.width-4, caption, hotcolor, win.Align.Center, hotkeyed);
    if (focused) win.gotoXY(1, 0);
  }

  void onMyEvent (FuiEventClick evt) {
    if (evt.left) {
      evt.eat();
      doAction();
    }
  }

  void onMyEvent (FuiEventKey evt) {
    if (evt.key == "Space" /*|| evt.key == "Enter"*/) { evt.eat(); doAction(); return; }
    if (tryHotKey(evt.key)) { evt.eat(); doAction(); return; }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
public class FuiRadio : FuiControl {
  alias onMyEvent = super.onMyEvent;

  string groupid;
  int myval;

  this (FuiControl aparent, string atext, string agroupid, int amyval) {
    this.connectListeners();
    super(aparent);
    groupid = agroupid;
    myval = amyval;
    caption = atext;
    minSize.w = XtWindow.hotStrLen(atext)+4;
    horizontal = true;
    aligning = Align.Start;
    minSize.h = maxSize.h = 1;
    canBeFocused = true;
    hotkeyed = true;
    acceptClick(TtyEvent.MButton.Left);
    assert(clickMask != 0);
  }

  override void doAction () {
    if (canBeFocused) {
      if (auto desk = getDesk) desk.switchFocusTo(this, false);
    }
    if (onAction !is null) { onAction(this); return; }
    if (groupid.length && myval >= 0) {
      if (auto w = topwindow) {
        auto nv = w.radio(groupid);
        if (nv != myval) {
          w.radio(groupid, myval);
          (new FuiEventRadioChanged(this, groupid, myval)).post;
        }
      }
    }
  }

  protected override void drawSelf (XtWindow win) {
    win.color = (focused ? palColor!"sel"() : disabled ? palColor!"disabled"() : palColor!"def"());
    auto hotcolor = (focused ? palColor!"hotsel"() : disabled ? palColor!"disabled" : palColor!"hot"());
    win.fill(0, 0, win.width, win.height);
    win.writeStrAt(0, 0, "( )");
    if (myval >= 0) {
      if (auto w = topwindow) {
        if (w.radio(groupid) == myval) win.writeCharAt(1, 0, '*');
      }
    }
    win.writeHotStrAt(4, 0, win.width-4, caption, hotcolor, win.Align.Center, hotkeyed);
    if (focused) win.gotoXY(1, 0);
  }

  void onMyEvent (FuiEventClick evt) {
    if (evt.left) {
      evt.eat();
      doAction();
    }
  }

  void onMyEvent (FuiEventKey evt) {
    if (evt.key == "Space" /*|| evt.key == "Enter"*/) { evt.eat(); doAction(); return; }
    if (tryHotKey(evt.key)) { evt.eat(); doAction(); return; }
  }
}
