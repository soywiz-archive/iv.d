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
module iv.tuing.controls.editline /*is aliced*/;

import iv.alice;
import iv.eventbus;
import iv.flexlayout;
import iv.strex;
import iv.rawtty;

import iv.tuing.events;
import iv.tuing.tty;
import iv.tuing.tui;
import iv.tuing.types;
import iv.tuing.ttyeditor;
import iv.tuing.controls.box;
import iv.tuing.controls.button;
import iv.tuing.controls.listbox;
import iv.tuing.controls.window;


// ////////////////////////////////////////////////////////////////////////// //
public class FuiEditLine : FuiControl {
  alias onMyEvent = super.onMyEvent;

  TtyEditor ed;

  this (FuiControl aparent, const(char)[] atext=null) {
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
  //override void doAction ();

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

  override void onMyEvent (FuiEventBlur evt) {
    ed.resetPasteMode();
    super.onMyEvent(evt);
  }

  void onMyEvent (FuiEventHistoryReply evt) {
    evt.eat();
    ed.setNewText(evt.text);
    doAction();
  }

  void onMyEvent (FuiEventKey evt) {
    if (disabled) return;
    // history
    if (evt.key == "M-H" || evt.key == "M-Down") {
      // history dialog
      (new FuiEventHistoryQuery(this)).post;
      evt.eat();
      return;
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
    if (!evt.key.mouse && ed.pasteMode) { evt.eat(); return; }
  }
}
