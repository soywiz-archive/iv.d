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
  FuiEditLine el;
  this (FuiEditLine ael) {
    this.connectListeners();
    super();
    el = ael;
  }
}


private void createHistoryWin (FuiEditLine el) {
  if (el is null) return;
  auto desk = el.getDesk;
  if (desk is null) return;
  auto win = new FuiHistoryWindow(el);
  //win.lp.minSize = FuiSize(30, 7);
  win.caption = "History Window";
  win.frame = win.Frame.Small;
  if (auto box = new FuiHBox(win)) {
    new FuiSpan(box);
    (new FuiButton(box, "&OK")).defctl = true;
    new FuiButton(box, "&Cancel");
    new FuiSpan(box);
  }
  new FuiHLine(win);
  if (auto lb = new FuiListBox(win)) {
    //lb.minSize.w = 24;
    //lb.minSize.h = 16;
    lb.allowmarks = true;
    foreach (immutable idx; 0..24) {
      import std.format : format;
      lb.addItem("item #%s".format(idx));
    }
  }
  win.onBlur = (FuiControl self) { (new FuiEventClose(self, null)).post; };
  fuiLayout(win);
  import std.random : uniform;
  win.lp.pos = FuiPoint(uniform!"[]"(0, ttyw-win.lp.size.w), uniform!"[]"(0, ttyh-win.lp.size.h));
  tuidesk.addWindow(win, true);
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
    /*
    if (evt.key == "Space") { evt.eat(); doAction(); return; }
    if (tryHotKey(evt.key)) { evt.eat(); doAction(); return; }
    */
    // history
    if (auto hm = historymgr) {
      if (evt.key == "M-H") {
        // history dialog
        createHistoryWin(this);
        /*
        if (auto lp = ctx.layprops(self)) {
          auto pt = ctx.toGlobal(self, FuiPoint(0, 0));
          auto hidx = dialogHistory(hisman, eid, pt.x, pt.y);
          if (hidx >= 0) {
            auto s = hisman.item(eid, hidx);
            eld.ed.setNewText(s, false); // don't clear on type
            hisman.activate(eid, hidx);
            if (eld.actcb !is null) {
              auto rr = eld.actcb(ctx, ev.item);
              if (rr >= -1) ctx.postClose(rr);
            }
          }
          return true;
        }
        */
        evt.eat();
        return;
      }
    }
    if (ed.processKey(evt.key)) {
      evt.eat();
      doAction();
      return;
    }
  }
}
