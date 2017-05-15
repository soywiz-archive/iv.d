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
module iv.tuing.controls.editor is aliced;

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
import iv.tuing.controls.editline;
import iv.tuing.controls.label;
import iv.tuing.controls.listbox;
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
    if (auto box = new FuiHBox(this)) {
      auto lb = new FuiLabel(box, alabel);
      editline = new FuiEditLine(box, (defval > 0 ? "%s".format(defval) : ""));
      editline.onAction = (FuiControl self) { btok.enabled = (getNum() > 0); };
    }
    defaultFocus = editline;
    new FuiHLine(this);
    if (auto box = new FuiHBox(this)) {
      new FuiSpan(box);
      btok = new FuiButton(box, "O&K");
      with (btok) {
        defctl = true;
        enabled = (defval > 0);
      }
      with (new FuiButton(box, "&Cancel")) {
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
  tuidesk.addModal(win);
}


private void createGotoLineWindow (FuiEditor aed) {
  if (aed is null) return;
  auto desk = aed.getDesk;
  if (desk is null) return;
  auto win = new FuiEditorNumInputWindow(aed, "Editor Query", "Line &number:", -1);
  win.btok.onAction = (FuiControl self) {
    if (auto w = cast(FuiEditorNumInputWindow)self.toplevel) {
      int n = w.getNum();
      if (n > 0) {
        (new EventEditorReplyGotoLine(w.edt.ed, n)).post;
        (new FuiEventClose(w, self)).post;
      }
    }
  };
  fuiLayout(win);
  win.positionCenterInControl(aed);
  tuidesk.addModal(win);
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
private class FuiEditorACWindow : FuiWindow {
  alias onMyEvent = super.onMyEvent;
  alias onBubbleEvent = super.onBubbleEvent;

  FuiEditor ed;
  FuiListBox lb;
  int pos, len;

  this (FuiEditor aed, int apos, int alen, const(char)[][] list) {
    assert(aed !is null);
    this.connectListeners();
    super();
    ed = aed;
    pos = apos;
    len = alen;
    frame = Frame.Small;
    lb = new FuiListBox(this);
    with (lb) {
      aligning = Align.Stretch;
      foreach (const(char)[] s; list) addItem(s);
      defctl = true;
      escctl = true;
      maxSize.w = ttyw-8;
      maxSize.h = 16;//ttyh-8;
    }
    // cancel autocompletion on close
    addEventListener(this, (FuiEventClose evt) {
      (new EventEditorReplyAutocompletion(ed.ed, pos, len, null)).post;
    });
  }

  override void onBubbleEvent (FuiEventKey evt) {
    if (evt.key == "Enter" && lb !is null) {
      (new EventEditorReplyAutocompletion(ed.ed, pos, len, lb[lb.curitem])).post;
    } else if (evt.key == "Escape") {
      (new EventEditorReplyAutocompletion(ed.ed, pos, len, null)).post;
    }
    super.onBubbleEvent(evt);
  }

  static void create (FuiEditor aed, FuiPoint pt, int apos, int alen, const(char)[][] list) {
    if (aed is null) return;
    auto desk = aed.getDesk;
    if (desk is null) return;
    auto win = new FuiEditorACWindow(aed, apos, alen, list);
    fuiLayout(win);
    pt = aed.toGlobal(pt);
    if (!aed.ed.hideSBar) pt.x = pt.x+1;
    if (!aed.ed.hideStatus) pt.y = pt.y+1;
    win.positionAtGlobal(pt);
    tuidesk.addPopup(win);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
private class FuiEditorSRWindow : FuiWindow {
  FuiEditor ed;
  TtyEditor.SROptions* srr;
  FuiEditLine els, elr;
  FuiCheckBox cbinsel;
  FuiCheckBox cbnocom;
  FuiButton btok;

  this (FuiEditor aed, TtyEditor.SROptions* asrr) {
    assert(aed !is null);
    this.connectListeners();
    super();
    ed = aed;
    srr = asrr;
    caption = "Search And Replace";
    frame = Frame.Normal;
    minSize.w = ttyw-(ttyw/3);

    auto lbs = new FuiLabel(this, "&Search string:");
    lbs.lineBreak = true;
    els = new FuiEditLine(this, srr.search);
    els.aligning = Align.Stretch;
    els.lineBreak = true;
    els.onAction = (FuiControl self) { btok.enabled = (els.ed.textsize > 0); };
    lbs.dest = els;

    auto lbr = new FuiLabel(this, "Re&placement string:");
    lbr.lineBreak = true;
    elr = new FuiEditLine(this, srr.replace);
    elr.aligning = Align.Stretch;
    elr.lineBreak = true;
    lbr.dest = elr;

    new FuiHLine(this);

    if (auto box = new FuiHBox(this)) {
      box.aligning = Align.Start;
      radio("srrtype", cast(int)srr.type);
      if (auto vb = new FuiVBox(box)) {
        new FuiRadio(vb, "No&rmal", "srrtype", 0);
        new FuiRadio(vb, "Re&gular expression", "srrtype", 1);
      }
      if (auto vb = new FuiVBox(box)) {
        new FuiCheckBox(vb, "Cas&e sensitive", "casesens", srr.casesens);
        new FuiCheckBox(vb, "&Backwards", "backwards", srr.backwards);
        new FuiCheckBox(vb, "&Whole words", "wholeword", srr.wholeword);
        cbinsel = new FuiCheckBox(vb, "In se&lection", "inselection", srr.inselection);
        cbinsel.enabled = aed.ed.hasMarkedBlock;
        cbnocom = new FuiCheckBox(vb, "S&kip comments", "nocomments", srr.nocomments);
      }
    }

    new FuiHLine(this);
    if (auto box = new FuiHBox(this)) {
      new FuiSpan(box);
      btok = new FuiButton(box, "O&K");
      with (btok) {
        defctl = true;
        enabled = (srr.search.length > 0);
        onAction = (FuiControl self) {
          self.closetop;
          auto rv = radio("srrtype");
          if (rv < TtyEditor.SROptions.Type.min || rv > TtyEditor.SROptions.Type.max) return;
          srr.type = cast(TtyEditor.SROptions.Type)rv;
          srr.casesens = checkbox("casesens");
          srr.backwards = checkbox("backwards");
          srr.wholeword = checkbox("wholeword");
          srr.inselection = checkbox("inselection");
          srr.nocomments = checkbox("nocomments");
          srr.search = els.getText!(const(char)[]);
          srr.replace = elr.getText!(const(char)[]);
          (new EventEditorReplySR(ed.ed, srr, true)).post;
        };
      }
      with (new FuiButton(box, "&Cancel")) {
        escctl = true;
        onAction = (FuiControl self) {
          self.closetop;
          (new EventEditorReplySR(ed.ed, srr, false)).post;
        };
      }
      new FuiSpan(box);
    }
  }

  static void create (FuiEditor aed, TtyEditor.SROptions* srr) {
    if (aed is null) return;
    auto desk = aed.getDesk;
    if (desk is null) return;
    auto win = new FuiEditorSRWindow(aed, srr);
    fuiLayout(win);
    win.positionCenterInControl(aed);
    tuidesk.addModal(win);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
private class FuiEditorSRConfirmWindow : FuiWindow {
  FuiEditor ed;
  TtyEditor.SROptions* srr;

  this (FuiEditor aed, TtyEditor.SROptions* asrr) {
    assert(aed !is null);
    this.connectListeners();
    super();
    ed = aed;
    srr = asrr;
    caption = "Confirm replace";
    frame = Frame.Normal;

    with (new FuiLabel(this, "\x03Pattern found. Select your action!")) aligning = Align.Stretch;

    new FuiHLine(this);

    if (auto box = new FuiHBox(this)) {
      (new FuiSpan(box)).minSize.w = 1;
      with (new FuiButton(box, "&Replace")) {
        onAction = (FuiControl self) {
          self.closetop;
          srr.cont = TtyEditor.SROptions.Cont.Yes;
          (new EventEditorReplyReplacement(ed.ed, srr)).post;
        };
      }
      with (new FuiButton(box, "A&ll")) {
        onAction = (FuiControl self) {
          self.closetop;
          srr.cont = TtyEditor.SROptions.Cont.All;
          (new EventEditorReplyReplacement(ed.ed, srr)).post;
        };
      }
      with (new FuiButton(box, "&Skip")) {
        onAction = (FuiControl self) {
          self.closetop;
          srr.cont = TtyEditor.SROptions.Cont.No;
          (new EventEditorReplyReplacement(ed.ed, srr)).post;
        };
      }
      with (new FuiButton(box, "&Cancel")) {
        escctl = true;
        onAction = (FuiControl self) {
          self.closetop;
          srr.cont = TtyEditor.SROptions.Cont.Cancel;
          (new EventEditorReplyReplacement(ed.ed, srr)).post;
        };
      }
      (new FuiSpan(box)).minSize.w = 1;
    }
  }

  static void create (FuiEditor aed, TtyEditor.SROptions* srr) {
    if (aed is null) return;
    auto desk = aed.getDesk;
    if (desk is null) return;
    auto win = new FuiEditorSRConfirmWindow(aed, srr);
    fuiLayout(win);
    //auto pt = FuiPoint(aed.ed.curx, aed.ed.cury);
    auto pt = FuiPoint(0, aed.ed.cury);
    pt.y -= aed.ed.topline;
    pt.y = pt.y+1;
    if (!aed.ed.hideSBar) pt.x = pt.x+1;
    if (!aed.ed.hideStatus) pt.y = pt.y+1;
    pt = aed.toGlobal(pt);
    win.positionAtGlobal(pt);
    tuidesk.addModal(win);
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
    addEventListener(ed, (EventEditorQueryGotoLine evt) { createGotoLineWindow(this); });
    addEventListener(ed, (EventEditorQuerySR evt) { FuiEditorSRWindow.create(this, cast(TtyEditor.SROptions*)evt.opt); });
    addEventListener(ed, (EventEditorQueryReplacement evt) { FuiEditorSRConfirmWindow.create(this, cast(TtyEditor.SROptions*)evt.opt); });
    addEventListener(ed, (EventEditorQueryAutocompletion evt) { FuiEditorACWindow.create(this, evt.pt, evt.pos, evt.len, evt.list); });
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
    ed.moveResize(win.x0+(ed.hideSBar ? 0 : 1), win.y0+(ed.hideStatus ? 0 : 1), win.width-(ed.hideSBar ? 0 : 1), win.height-(ed.hideStatus ? 0 : 1));
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
    if (!evt.key.mouse && ed.pasteMode) { evt.eat(); return; }
  }
}
