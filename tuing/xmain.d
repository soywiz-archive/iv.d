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
module xmain /*is aliced*/;

import iv.tuing;
import iv.vfs.io;


// ////////////////////////////////////////////////////////////////////////// //
__gshared HistoryManager hisman;


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
    caption = "History";
    frame = Frame.Small;
    minSize.w = 14;
    hlb = new FuiListBox(this);
    hlb.aligning = hlb.Align.Stretch;
    foreach_reverse (immutable idx; 0..hisman.count(el)) hlb.addItem(hisman.item(el, idx));
    if (hlb.count > 1) hlb.curitem = 1;
    hlb.defctl = true;
    hlb.escctl = true;
    hlb.maxSize.w = ttyw-8;
    hlb.maxSize.h = ttyh-8;
    /*this works
    addEventListener(this, (FuiEventClose evt) {
      ttyBeep;
    });
    */
  }

  override void onBubbleEvent (FuiEventKey evt) {
    if (evt.key == "Enter" && hlb !is null) {
      auto it = hlb.curitem;
      if (it >= 0 && it < hisman.count(el)) {
        (new FuiEventHistoryReply(el, hlb[it])).post;
        //it = hisman.count(el)-it-1;
        hisman.activate(el, it);
      }
    }
    super.onBubbleEvent(evt);
  }

  static void create (FuiEditLine el) {
    if (el is null) return;
    auto desk = el.getDesk;
    if (desk is null) return;
    if (hisman is null) return;
    if (!hisman.has(el) || hisman.count(el) < 1) return;
    auto win = new FuiHistoryWindow(el);
    fuiLayout(win);
    win.positionUnderControl(el);
    tuidesk.addPopup(win);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
public class HistoryManager {
public:
  enum MaxHistory = 128;

  string[][string] history;

public:
  this () { this.connectListeners(); }

  void onEvent (FuiEventHistoryQuery evt) {
    if (auto el = cast(FuiEditLine)evt.sourcectl) {
      evt.eat();
      FuiHistoryWindow.create(el);
    }
  }

  bool has (FuiControl ctl) {
    //if (ctl.id.length == 0) return;
    //VFile("/home/ketmar/back/D/prj/edgap/zzz", "a").writeln("check: '", id, "'");
    return ((ctl.id in history) !is null);
  }

  int count (FuiControl ctl) {
    if (auto listp = ctl.id in history) return listp.length;
    return 0;
  }

  // 0: oldest
  const(char)[] item (FuiControl ctl, int idx) {
    if (idx < 0) return null;
    if (auto listp = ctl.id in history) {
      return (idx < listp.length ? (*listp)[idx] : null);
    }
    return null;
  }

  // this can shrink history; should correctly process duplicates
  void add (FuiControl ctl, const(char)[] value) {
    if (value.length == 0 || ctl.id.length == 0) return;
    if (auto listp = ctl.id in history) {
      // check for existing item
      foreach (immutable idx; 0..listp.length) {
        if ((*listp)[idx] == value) {
          // move to bottom
          activate(ctl, cast(int)idx);
          return;
        }
      }
      if (listp.length > MaxHistory) (*listp).length = MaxHistory;
      if (listp.length == MaxHistory) {
        // remove oldest item
        foreach (immutable c; 1..listp.length) (*listp)[c-1] = (*listp)[c];
        (*listp)[$-1] = value.idup;
      } else {
        (*listp) ~= value.idup;
      }
    } else {
      string[] list;
      list ~= value.idup;
      history[ctl.id] = list;
    }
  }

  void clear (FuiControl ctl) {
    if (auto listp = ctl.id in history) {
      if (listp.length) {
        (*listp).length = 0;
        (*listp).assumeSafeAppend;
      }
    }
  }

  // usually moves item to bottom
  void activate (FuiControl ctl, int idx) {
    if (idx < 0) return;
    if (auto listp = ctl.id in history) {
      if (listp.length > 1 && idx < listp.length-1) {
        // move item to bottom
        auto s = (*listp)[0];
        foreach (immutable c; 1..listp.length) (*listp)[c-1] = (*listp)[c];
        (*listp)[$-1] = s;
      }
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
public class FuiTextLine : FuiControl {
  alias onMyEvent = super.onMyEvent;

  this (FuiControl aparent, string atext) {
    this.connectListeners();
    FuiControl ctl = (aparent !is null ? aparent.lastChild : null);
    if (ctl !is null) ctl.lineBreak = true;
    super(aparent);
    caption = atext;
    lp.minSize.w = cast(int)atext.length;
    lp.orientation = lp.Orientation.Horizontal;
    lp.aligning = lp.Align.Stretch;
    lp.minSize.h = lp.maxSize.h = 1;
    lp.lineBreak = true;
  }

  protected override void drawSelf (XtWindow win) {
    win.color = palColor!"def"();
    win.fill(0, 0, win.width, win.height);
    win.writeStrAt(0, 0, caption);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
FuiWindow createWin (bool closeOnBlur=false) {
  import std.format : format;
  if (hisman is null) hisman = new HistoryManager();
  __gshared int counter;
  auto win = new FuiWindow();
  //win.minSize = FuiSize(30, 7);
  win.caption = "Test Window %s".format(counter++);
  new FuiTextLine(win, "hello, i am the first text line");
  new FuiHLine(win);
  new FuiTextLine(win, "hello, i am the second text line");
  new FuiHLine(win);
  if (auto box = new FuiHBox(win)) {
    auto lbl0 = new FuiLabel(box, "&first:", "bx0");
    lbl0.hgroup = "label0group";
    if (auto btn = new FuiButton(box, "button &0")) { btn.id = "bx0"; btn.lineBreak = true; }
    auto lbl1 = new FuiLabel(box, "&second:", "bx1");
    lbl1.hgroup = "label0group";
    //if (auto btn = new FuiButton(box, "button &1")) { btn.id = "bx1"; btn.lineBreak = true; }
    if (auto edt = new FuiEditLine(box, "default text")) {
      edt.minSize.w = 30;
      edt.aligning = edt.Align.Stretch;
      edt.id = "bx1";
      edt.lineBreak = true;
    }
    if (auto btn = new FuiCheckBox(box, "checkbox &2", "cbgroup0")) { btn.lineBreak = true; }
    if (auto pan = new FuiPanel(box, "Radio")) {
      new FuiRadio(pan, "radio &3", "rbgroup0", 3);
      new FuiRadio(pan, "radio &4", "rbgroup0", 4);
      new FuiRadio(pan, "radio &5", "rbgroup0", 5);
    }
  }
  new FuiTextLine(win, "hello, i am the third text line");
  new FuiHLine(win);
  if (auto box = new FuiHBox(win)) {
    new FuiSpan(box);
    (new FuiButton(box, "&OK")).defctl = true;
    new FuiButton(box, "&Cancel");
    new FuiSpan(box);
  }
  new FuiHLine(win);
  if (closeOnBlur) {
    if (auto lb = new FuiEditor(win, "line 1\nlist with tab!: \t2\nlast 3")) {
      //lb.ed.gotoXY(0, 0);
      lb.ed.visualtabs = true;
      //lb.ed.tabsize = 8;
      win.defaultFocus = lb;
    }
  } else {
    if (auto lb = new FuiListBox(win)) {
      //lb.minSize.w = 24;
      //lb.minSize.h = 16;
      lb.allowmarks = true;
      foreach (immutable idx; 0..24) {
        import std.format : format;
        lb.addItem("item #%s".format(idx));
      }
    }
  }
  if (closeOnBlur) win.onBlur = (FuiControl self) { if (auto w = cast(FuiWindow)self) w.close; };
  fuiLayout(win);
  if (closeOnBlur) {
    win.pos = FuiPoint((ttyw-win.size.w)/2, (ttyh-win.size.h)/2);
  } else {
    import std.random : uniform;
    win.pos = FuiPoint(uniform!"[]"(0, ttyw-win.size.w), uniform!"[]"(0, ttyh-win.size.h));
  }
  return win;
}


// ////////////////////////////////////////////////////////////////////////// //
void main (string[] args) {
  if (ttyIsRedirected) assert(0, "no redirections, please");
  xtInit();

  auto ttymode = ttyGetMode();
  scope(exit) {
    normalScreen();
    ttySetMode(ttymode);
  }
  ttySetRaw();
  altScreen();

  bool doQuit = false;
  addEventListener((FuiEventQuit evt) { doQuit = true; });

  foreach (immutable _; 0..2) tuidesk.addWindow(createWin());
  tuidesk.addWindow(createWin(true));

  tuidesk.registerHotKey("M-A", () {
    if (auto ed = cast(FuiEditLine)tuidesk.focused) {
      ttyBeep;
      auto str = ed.getText!string;
      if (str.length) hisman.add(ed, str);
    }
  });

  while (!doQuit) {
    foreach (immutable _; 0..100) {
      while (ebusSafeDelay == 0) processEvents();
      if (ebusSafeDelay != 0) break;
    }
    tuidesk.draw();
    xtFlush();
    //{ import core.memory : GC; GC.collect(); GC.minimize(); }
    if (doQuit) break;
    if (ttyIsKeyHit || ebusSafeDelay < 0) {
      if (ebusSafeDelay < 0) { import core.memory : GC; GC.collect(); GC.minimize(); }
      auto key = ttyReadKey(ebusSafeDelay, TtyDefaultEscWait);
      if (key.key == TtyEvent.Key.Error) break;
      if (key.key == TtyEvent.Key.Unknown) continue;
      if (key == "C-c") break;
      //if (key.key == TtyEvent.Key.Escape) { (new FuiEventQuit).post; continue; }
      if (key.key == TtyEvent.Key.ModChar && key.ctrl && !key.alt && !key.shift && key.ch == 'L') { xtFullRefresh(); continue; }
      tuidesk.queue(key);
    }
  }
}
