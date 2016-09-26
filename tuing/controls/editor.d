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
module iv.tuing.controls.editor;

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
private class FuiEditorCPWindow : FuiWindow {
  alias onMyEvent = super.onMyEvent;
  alias onBubbleEvent = super.onBubbleEvent;

  FuiEditor ed;
  FuiListBox lb;

  this (FuiEditor aed) {
    assert(aed !is null);
    this.connectListeners();
    super();
    ed = aed;
  }

  override void onBubbleEvent (FuiEventKey evt) {
    if (evt.key == "Enter" && lb !is null) {
      (new EventEditorReplyCodePage(ed.ed, lb.curitem)).post;
    }
    super.onBubbleEvent(evt);
  }

  static void create (FuiEditor aed, int ccp) {
    if (aed is null) return;
    auto desk = aed.getDesk;
    if (desk is null) return;
    auto win = new FuiEditorCPWindow(aed);
    win.caption = "Codepage";
    win.frame = win.Frame.Small;
    //win.minSize.w = 14;
    win.lb = new FuiListBox(win);
    win.lb.aligning = lb.Align.Stretch;
    win.lb.addItem("KOI8-U");
    win.lb.addItem("CP1251");
    win.lb.addItem("CP-866");
    win.lb.addItem("UTFUCK");
    win.lb.curitem = ccp;
    win.lb.defctl = true;
    win.lb.escctl = true;
    win.lb.maxSize.w = ttyw-8;
    win.lb.maxSize.h = ttyh-8;
    fuiLayout(win);
    auto pt = aed.toGlobal(FuiPoint(0, 1));
    if (pt.x+win.size.w > ttyw) pt.x = ttyw-win.size.w;
    if (pt.y+win.size.h > ttyh) pt.y = ttyh-win.size.h;
    win.pos.x = pt.x;
    win.pos.y = pt.y;
    tuidesk.addPopup(win);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
public class FuiEditor : FuiControl {
  alias onMyEvent = super.onMyEvent;

  TtyEditor ed;

  this (FuiControl aparent, string atext=null) {
    this.connectListeners();
    super(aparent);
    ed = new TtyEditor(0, 0, 10, 1, false); // size will be fixed later
    //ed.hideStatus = true;
    //ed.utfuck = utfuck;
    ed.setNewText(atext);
    minSize.w = 30;
    minSize.h = 6;
    horizontal = true;
    aligning = Align.Stretch;
    canBeFocused = true;
    hotkeyed = false;
    acceptClick(TtyEvent.MButton.Left);
    addEventListener(ed, (EventEditorQueryCodePage evt) {
      FuiEditorCPWindow.create(this, evt.cp);
    });
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
