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
import iv.tuing.controls.editline;
import iv.tuing.controls.hline;
import iv.tuing.controls.label;
import iv.tuing.controls.listbox;
import iv.tuing.controls.span;
import iv.tuing.controls.window;


// ////////////////////////////////////////////////////////////////////////// //
private class FuiEditorMessageWindow : FuiWindow {
  alias onMyEvent = super.onMyEvent;
  alias onBubbleEvent = super.onBubbleEvent;

  this (FuiEditor aed, string msg) {
    assert(aed !is null);
    this.connectListeners();
    super();
    caption = "Editor Message";
    minSize.w = cast(int)caption.length+6;
    frame = Frame.Normal;
    if (auto lb = new FuiLabel(this, "\x03"~msg)) {
      lb.hotkeyed = false;
      lb.aligning = Align.Stretch;
    }
    new FuiHLine(this);
    if (auto box = new FuiHBox(this)) {
      new FuiSpan(box);
      with (new FuiButton(box, "&Close")) {
        defctl = true;
        escctl = true;
      }
      new FuiSpan(box);
    }
  }

  static void create (FuiEditor aed, string msg) {
    if (aed is null) return;
    auto desk = aed.getDesk;
    if (desk is null) return;
    auto win = new FuiEditorMessageWindow(aed, msg);
    fuiLayout(win);
    win.positionCenterInControl(aed);
    tuidesk.addPopup(win);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
private class FuiEditorNumInputWindow : FuiWindow {
  alias onMyEvent = super.onMyEvent;
  alias onBubbleEvent = super.onBubbleEvent;

  FuiEditor edt;
  FuiEditLine editline;
  FuiButton btok;

  int getNum () {
    auto ed = editline.ed;
    if (ed is null) return -1;
    int num = 0;
    auto rng = ed[];
    while (!rng.empty && rng.front <= ' ') rng.popFront();
    if (rng.empty || !rng.front.isdigit) return -1;
    while (!rng.empty && rng.front.isdigit) {
      num = num*10+rng.front-'0';
      rng.popFront();
    }
    while (!rng.empty && rng.front <= ' ') rng.popFront();
    return (rng.empty ? num : -1);
  }

  this (FuiEditor aed, string acaption, string alabel, int defval) {
    import std.format : format;
    assert(aed !is null);
    this.connectListeners();
    super();
    edt = aed;
    caption = acaption;
    minSize.w = cast(int)caption.length+6;
    frame = Frame.Normal;
    auto lb = new FuiLabel(this, alabel);
    editline = new FuiEditLine(this, (defval > 0 ? "%s".format(defval) : ""));
    editline.onAction = (FuiControl self) { btok.enabled = (getNum() > 0); };
    defaultFocus = editline;
    new FuiHLine(this);
    if (auto box = new FuiHBox(this)) {
      new FuiSpan(box);
      btok = new FuiButton(box, "&OK");
      with (btok) {
        defctl = true;
        enabled = (defval > 0);
      }
      with (new FuiButton(box, "&Close")) {
        escctl = true;
      }
      new FuiSpan(box);
    }
  }
}


private void createTabSizeWindow (FuiEditor aed, int tabsize) {
  if (aed is null) return;
  auto desk = aed.getDesk;
  if (desk is null) return;
  auto win = new FuiEditorNumInputWindow(aed, "Editor Query", "&Tab size:", tabsize);
  win.btok.onAction = (FuiControl self) {
    if (auto w = cast(FuiEditorNumInputWindow)self.toplevel) {
      int n = w.getNum();
      if (n > 0) {
        (new EventEditorReplyTabSize(w.edt.ed, n)).post;
        (new FuiEventClose(w, self)).post;
      }
    }
  };
  fuiLayout(win);
  win.positionCenterInControl(aed);
  tuidesk.addPopup(win);
}


// ////////////////////////////////////////////////////////////////////////// //
private class FuiEditorCPWindow : FuiWindow {
  alias onMyEvent = super.onMyEvent;
  alias onBubbleEvent = super.onBubbleEvent;

  FuiEditor ed;
  FuiListBox lb;

  this (FuiEditor aed, int ccp) {
    assert(aed !is null);
    this.connectListeners();
    super();
    ed = aed;
    caption = "Codepage";
    frame = Frame.Small;
    //minSize.w = 14;
    lb = new FuiListBox(this);
    with (lb) {
      aligning = Align.Stretch;
      addItem("KOI8-U");
      addItem("CP1251");
      addItem("CP-866");
      addItem("UTFUCK");
      curitem = ccp;
      defctl = true;
      escctl = true;
      maxSize.w = ttyw-8;
      maxSize.h = ttyh-8;
    }
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
    auto win = new FuiEditorCPWindow(aed, ccp);
    fuiLayout(win);
    win.positionCenterInControl(aed);
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

    addEventListener(ed, (EventEditorMessage evt) { FuiEditorMessageWindow.create(this, evt.msg); });
    addEventListener(ed, (EventEditorQueryCodePage evt) { FuiEditorCPWindow.create(this, evt.cp); });
    addEventListener(ed, (EventEditorQueryTabSize evt) { createTabSizeWindow(this, evt.tabsize); });

    //(new EventEditorQueryReplacement(this, &srr)).post;
    //(new EventEditorQueryGotoLine(this)).post;
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
  //override void doAction ()

  protected override void drawSelf (XtWindow win) {
    //ed.hideStatus = true;
    ed.moveResize(win.x0+(ed.hideSBar ? 0 : 1), win.y0+(ed.hideStatus ? 0 : 1), win.width-(ed.hideSBar ? 0 : 2), win.height-(ed.hideStatus ? 0 : 2));
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
