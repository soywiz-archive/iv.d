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
module iv.tuing.controls.editline;

import iv.strex;
import iv.rawtty2;

import iv.tuing.eventbus;
import iv.tuing.events;
import iv.tuing.layout;
import iv.tuing.tty;
import iv.tuing.tui;
import iv.tuing.types;
import iv.tuing.ttyeditor;
import iv.tuing.controls.box;
import iv.tuing.controls.button;
import iv.tuing.controls.hline;
import iv.tuing.controls.listbox;
import iv.tuing.controls.span;
import iv.tuing.controls.window;


// ////////////////////////////////////////////////////////////////////////// //
private class FuiHistoryWindow : FuiWindow {
  alias onMyEvent = super.onMyEvent;
  alias onBubbleEvent = super.onBubbleEvent;

  FuiEditLine el;
  FuiListBox hlb;

  this (FuiEditLine ael) {
    assert(ael !is null);
    this.connectListeners();
    super();
    el = ael;
    /*this works
    addEventListener(this, (FuiEventClose evt) {
      ttyBeep;
    });
    */
  }

  override void onBubbleEvent (FuiEventKey evt) {
    if (evt.key == "Enter" && hlb !is null) {
      if (auto hm = el.historymgr) {
        auto it = hlb.curitem;
        if (it >= 0 && it < hm.count(el)) {
          it = hm.count(el)-it-1;
          el.ed.setNewText(hm.item(el, it));
          hm.activate(el, it);
          el.doAction();
        }
      }
    }
    super.onBubbleEvent(evt);
  }
}


private void createHistoryWin (FuiEditLine el) {
  if (el is null) return;
  auto desk = el.getDesk;
  if (desk is null) return;
  auto hm = el.historymgr;
  if (hm is null) return;
  if (!hm.has(el) || hm.count(el) < 1) return;
  auto win = new FuiHistoryWindow(el);
  //win.lp.minSize = FuiSize(30, 7);
  win.caption = "History";
  win.frame = win.Frame.Small;
  win.minSize.w = 14;
  if (auto lb = new FuiListBox(win)) {
    lb.aligning = lb.Align.Stretch;
    foreach_reverse (immutable idx; 0..hm.count(el)) lb.addItem(hm.item(el, idx));
    lb.curitem = lb.count-1;
    lb.defctl = true;
    lb.escctl = true;
    lb.maxSize.w = ttyw-8;
    lb.maxSize.h = ttyh-8;
    win.hlb = lb;
  }
  //win.onBlur = (FuiControl self) { (new FuiEventClose(self, null)).post; };
  fuiLayout(win);
  //import std.random : uniform;
  auto pt = el.toGlobal(FuiPoint(0, 1));
  if (pt.x+win.size.w > ttyw) pt.x = ttyw-win.size.w;
  if (pt.y+win.size.h > ttyh) pt.y = ttyh-win.size.h;
  win.pos.x = pt.x;
  win.pos.y = pt.y;
  tuidesk.addPopup(win);
}


// ////////////////////////////////////////////////////////////////////////// //
public class FuiEditLine : FuiControl {
  alias onMyEvent = super.onMyEvent;

  TtyEditor ed;

  this (FuiControl aparent, string atext) {
    this.connectListeners();
    super(aparent);
    ed = new TtyEditor(0, 0, 10, 1, true); // size will be fixed later
    ed.hideStatus = true;
    //ed.utfuck = utfuck;
    ed.setNewText(atext);
    minSize.w = 10;
    horizontal = true;
    aligning = Align.Start;
    minSize.h = maxSize.h = 1;
    canBeFocused = true;
    hotkeyed = false;
    acceptClick(TtyEvent.MButton.Left);
  }

  T getText(T:const(char)[]) () if (!is(T == typeof(null))) {
    if (ed is null) return null;
    char[] res;
    auto rng = ed[];
    res.reserve(rng.length);
    foreach (char ch; rng) res ~= ch;
    return cast(T)res;
  }

  // action called when editor processed any key
  override void doAction () {
    if (onAction !is null) { onAction(this); return; }
    //(new FuiEventClose(toplevel, this)).post;
  }

  protected override void drawSelf (XtWindow win) {
    //ed.hideStatus = true;
    ed.moveResize(win.x0, win.y0, win.width, win.height);
    ed.fullDirty;
    ed.dontSetCursor = !focused;
    if (enabled) {
      if (focused) {
        ed.clrBlock = palColor!"inputmark"();
        ed.clrText = palColor!"input"();
        ed.clrTextUnchanged = palColor!"inputunchanged"();
      } else {
        ed.clrBlock = palColor!"inputmark"();
        ed.clrText = palColor!"input"();
        ed.clrTextUnchanged = palColor!"inputunchanged"();
      }
    } else {
      ed.clrBlock = palColor!"disabled"();
      ed.clrText = palColor!"disabled"();
      ed.clrTextUnchanged = palColor!"disabled"();
    }
    ed.drawPage();
  }

  void onMyEvent (FuiEventClick evt) {
    if (evt.left && ed.processClick(evt.bidx, evt.pt.x, evt.pt.y)) {
      evt.eat();
      doAction();
    }
  }

  void onMyEvent (FuiEventKey evt) {
    if (disabled) return;
    // history
    if (auto hm = historymgr) {
      if (evt.key == "M-H" || evt.key == "M-Down") {
        // history dialog
        createHistoryWin(this);
        evt.eat();
        return;
      }
      if (evt.key == "M-A") {
        hm.add(this, getText!string);
        evt.eat();
        return;
      }
    }
    /*
    if (evt.key == "F1") {
      import iv.vfs.io;
      VFile("zhelp.log", "w").writeln(ed.buildHelpText);
      evt.eat();
      return;
    }
    */
    if (ed.processKey(evt.key)) {
      evt.eat();
      doAction();
      return;
    }
  }
}
