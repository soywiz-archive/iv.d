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
module iv.egtui.tui;

import iv.strex;
import iv.rawtty2;

import iv.egtui.editor;
public import iv.egtui.layout;
import iv.egtui.tty;
import iv.egtui.types;
import iv.egtui.utils;


// ////////////////////////////////////////////////////////////////////////// //
struct Palette {
  uint def; // default color
  uint sel; // sel is also focus
  uint mark; // marked text
  uint marksel; // active marked text
  uint gauge; // unused
  uint input; // input field
  uint inputmark; // input field marked text (?)
  uint inputunchanged; // unchanged input field
  uint reverse; // reversed text
  uint title; // window title
  uint disabled; // disabled text
  // hotkey
  uint hot;
  uint hotsel;
}


// ////////////////////////////////////////////////////////////////////////// //
enum TuiPaletteNormal = 0;
enum TuiPaletteError = 1;

__gshared Palette[2] tuiPalette; // default palette

shared static this () {
  tuiPalette[TuiPaletteNormal].def = XtColorFB!(ttyRgb2Color(0xd0, 0xd0, 0xd0), ttyRgb2Color(0x4e, 0x4e, 0x4e)); // 252,239
  // sel is also focus
  tuiPalette[TuiPaletteNormal].sel = XtColorFB!(ttyRgb2Color(0xda, 0xda, 0xda), ttyRgb2Color(0x00, 0x5f, 0x5f)); // 253,23
  tuiPalette[TuiPaletteNormal].mark = XtColorFB!(ttyRgb2Color(0xff, 0xff, 0x00), ttyRgb2Color(0x5f, 0x5f, 0x5f)); // 226,59
  tuiPalette[TuiPaletteNormal].marksel = XtColorFB!(ttyRgb2Color(0xff, 0xff, 0x87), ttyRgb2Color(0x00, 0x5f, 0x87)); // 228,24
  tuiPalette[TuiPaletteNormal].gauge = XtColorFB!(ttyRgb2Color(0xbc, 0xbc, 0xbc), ttyRgb2Color(0x5f, 0x87, 0x87)); // 250,66
  tuiPalette[TuiPaletteNormal].input = XtColorFB!(ttyRgb2Color(0xd7, 0xd7, 0xaf), ttyRgb2Color(0x26, 0x26, 0x26)); // 187,235
  tuiPalette[TuiPaletteNormal].inputmark = XtColorFB!(ttyRgb2Color(0xff, 0xff, 0x87), ttyRgb2Color(0x00, 0x5f, 0x5f)); // 228,23
  //tuiPalette[TuiPaletteNormal].inputunchanged = XtColorFB!(ttyRgb2Color(0xff, 0xff, 0xff), ttyRgb2Color(0x26, 0x26, 0x26)); // 144,235
  tuiPalette[TuiPaletteNormal].inputunchanged = XtColorFB!(ttyRgb2Color(0xff, 0xff, 0xff), ttyRgb2Color(0x00, 0x00, 0x40));
  tuiPalette[TuiPaletteNormal].reverse = XtColorFB!(ttyRgb2Color(0xe4, 0xe4, 0xe4), ttyRgb2Color(0x5f, 0x87, 0x87)); // 254,66
  tuiPalette[TuiPaletteNormal].title = XtColorFB!(ttyRgb2Color(0xd7, 0xaf, 0x87), ttyRgb2Color(0x4e, 0x4e, 0x4e)); // 180,239
  tuiPalette[TuiPaletteNormal].disabled = XtColorFB!(ttyRgb2Color(0x94, 0x94, 0x94), ttyRgb2Color(0x4e, 0x4e, 0x4e)); // 246,239
  // hotkey
  tuiPalette[TuiPaletteNormal].hot = XtColorFB!(ttyRgb2Color(0xff, 0xaf, 0x00), ttyRgb2Color(0x4e, 0x4e, 0x4e)); // 214,239
  tuiPalette[TuiPaletteNormal].hotsel = XtColorFB!(ttyRgb2Color(0xff, 0xaf, 0x00), ttyRgb2Color(0x00, 0x5f, 0x5f)); // 214,23

  tuiPalette[TuiPaletteError] = tuiPalette[TuiPaletteNormal];
  tuiPalette[TuiPaletteError].def = XtColorFB!(ttyRgb2Color(0xff, 0xff, 0xd7), ttyRgb2Color(0x5f, 0x00, 0x00)); // 230,52
  tuiPalette[TuiPaletteError].sel = XtColorFB!(ttyRgb2Color(0xe4, 0xe4, 0xe4), ttyRgb2Color(0x00, 0x5f, 0x5f)); // 254,23
  tuiPalette[TuiPaletteError].hot = XtColorFB!(ttyRgb2Color(0xff, 0x5f, 0x5f), ttyRgb2Color(0x5f, 0x00, 0x00)); // 203,52
  tuiPalette[TuiPaletteError].hotsel = XtColorFB!(ttyRgb2Color(0xff, 0x5f, 0x5f), ttyRgb2Color(0x00, 0x5f, 0x5f)); // 203,23
  tuiPalette[TuiPaletteError].title = XtColorFB!(ttyRgb2Color(0xff, 0xff, 0x5f), ttyRgb2Color(0x5f, 0x00, 0x00)); // 227,52
}


// ////////////////////////////////////////////////////////////////////////// //
private int visStrLen(bool dohot=true) (const(char)[] s) nothrow @trusted @nogc {
  if (s.length > int.max) s = s[0..int.max];
  int res = cast(int)s.length;
       if (res && s.ptr[0] == '\x01') --res; // left
  else if (res && s.ptr[0] == '\x02') --res; // right
  else if (res && s.ptr[0] == '\x03') --res; // center (default)
  static if (dohot) {
    for (;;) {
      auto ampos = s.indexOf('&');
      if (ampos < 0 || s.length-ampos < 2) break;
      if (s.ptr[ampos+1] != '&') { --res; break; }
      s = s[ampos+2..$];
    }
  }
  return res;
}


private char visHotChar (const(char)[] s) nothrow @trusted @nogc {
  bool prevWasAmp = false;
  foreach (char ch; s) {
    if (ch == '&') {
      prevWasAmp = !prevWasAmp;
    } else if (prevWasAmp) {
      return ch;
    }
  }
  return 0;
}


// ////////////////////////////////////////////////////////////////////////// //
private const(char)[] getz (const(char)[] s) nothrow @trusted @nogc {
  foreach (immutable idx, char ch; s) if (ch == 0) return s[0..idx];
  return s;
}


private void setz (char[] dest, const(char)[] s) nothrow @trusted @nogc {
  dest[] = 0;
  if (s.length >= dest.length) s = s[0..dest.length-1];
  if (s.length) dest[0..s.length] = s[];
}


// ////////////////////////////////////////////////////////////////////////// //
enum FuiCtlUserFlags : ushort {
  Default = 1<<0,
}


// ////////////////////////////////////////////////////////////////////////// //
enum FuiCtlType : ubyte {
  Invisible,
  HLine,
  Box,
  Panel,
  EditLine,
  EditText,
  TextView,
  ListBox,
  CustomBox,
  //WARNING: button-likes should be last!
  Label,
  Button,
  Check,
  Radio,
}

// onchange callback; return -666 to continue, -1 to exit via "esc", or control id to return from `modalDialog()`
alias TuiActionCB = int delegate (FuiContext ctx, int self);
// draw widget; rc is in global space
alias TuiDrawCB = void delegate (FuiContext ctx, int self, FuiRect rc);
// process event; return `true` if event was eaten
alias TuiEventCB = bool delegate (FuiContext ctx, int self, FuiEvent ev);

mixin template FuiCtlHeader() {
  FuiCtlType type;
  Palette pal;
  char[64] id = 0; // widget it
  char[128] caption = 0; // widget caption
align(8):
  // onchange callback; return -666 to continue, -1 to exit via "esc", or control id to return from `modalDialog()`
  TuiActionCB actcb;
  // draw widget; rc is in global space
  TuiDrawCB drawcb;
  // process event; return `true` if event was eaten
  TuiEventCB eventcb;
}


struct FuiCtlHead {
  mixin FuiCtlHeader;
}
static assert(FuiCtlHead.actcb.offsetof%8 == 0);


//TODO: make delegate this scoped?
bool setActionCB (FuiContext ctx, int item, TuiActionCB cb) {
  if (auto data = ctx.itemIntr!FuiCtlHead(item)) {
    data.actcb = cb;
    return true;
  }
  return false;
}


//TODO: make delegate this scoped?
bool setDrawCB (FuiContext ctx, int item, TuiDrawCB cb) {
  if (auto data = ctx.itemIntr!FuiCtlHead(item)) {
    data.drawcb = cb;
    return true;
  }
  return false;
}


//TODO: make delegate this scoped?
bool setEventCB (FuiContext ctx, int item, TuiEventCB cb) {
  if (auto data = ctx.itemIntr!FuiCtlHead(item)) {
    data.eventcb = cb;
    return true;
  }
  return false;
}


bool setCaption (FuiContext ctx, int item, const(char)[] caption) {
  if (auto data = ctx.item!FuiCtlHead(item)) {
    data.caption.setz(caption);
    auto cpt = data.caption.getz;
    auto lp = ctx.layprops(item);
    /*if (lp.minSize.w < cpt.length)*/ lp.minSize.w = cast(int)cpt.length;
    return true;
  }
  return false;
}


// ////////////////////////////////////////////////////////////////////////// //
void postClose (FuiContext ctx, int res) {
  if (!ctx.valid) return;
  ctx.queueEvent(0, FuiEvent.Type.Close, res);
}


// ////////////////////////////////////////////////////////////////////////// //
enum FuiDialogFrameType : ubyte {
  Normal,
  Small,
  //None,
}

struct FuiCtlRootPanel {
  mixin FuiCtlHeader;
  FuiDialogFrameType frame;
  bool enterclose;
  bool moving;
}


// purely cosmetic
void dialogMoving (FuiContext ctx, bool v) {
  if (!ctx.valid) return;
  auto data = ctx.itemIntr!FuiCtlRootPanel(0);
  data.moving = v;
}

bool dialogMoving (FuiContext ctx) {
  if (!ctx.valid) return false;
  auto data = ctx.itemIntr!FuiCtlRootPanel(0);
  return data.moving;
}


void dialogCaption (FuiContext ctx, const(char)[] text) {
  if (!ctx.valid) return;
  auto data = ctx.itemIntr!FuiCtlRootPanel(0);
  data.caption.setz(text);
}


FuiDialogFrameType dialogFrame (FuiContext ctx) {
  if (!ctx.valid) return FuiDialogFrameType.Normal;
  auto data = ctx.itemIntr!FuiCtlRootPanel(0);
  return data.frame;
}

void dialogFrame (FuiContext ctx, FuiDialogFrameType t) {
  if (!ctx.valid) return;
  auto data = ctx.itemIntr!FuiCtlRootPanel(0);
  auto lp = ctx.layprops(0);
  final switch (t) {
    case FuiDialogFrameType.Normal:
      data.frame = FuiDialogFrameType.Normal;
      with (lp.padding) {
        left = 3;
        right = 3;
        top = 2;
        bottom = 2;
      }
      break;
    case FuiDialogFrameType.Small:
      data.frame = FuiDialogFrameType.Small;
      with (lp.padding) {
        left = 1;
        right = 1;
        top = 1;
        bottom = 1;
      }
      break;
  }
}


void dialogEnterClose (FuiContext ctx, bool enterclose) {
  if (!ctx.valid) return;
  auto data = ctx.itemIntr!FuiCtlRootPanel(0);
  data.enterclose = enterclose;
}


bool dialogEnterClose (FuiContext ctx) {
  if (!ctx.valid) return false;
  auto data = ctx.itemIntr!FuiCtlRootPanel(0);
  return data.enterclose;
}


// ////////////////////////////////////////////////////////////////////////// //
struct FuiCtlCustomBox {
  mixin FuiCtlHeader;
  align(8) void* udata;
}


int custombox (FuiContext ctx, int parent, const(char)[] id=null) {
  if (!ctx.valid) return -1;
  auto item = ctx.addItem!FuiCtlSpan(parent);
  with (ctx.layprops(item)) {
    //flex = 1;
    visible = true;
    horizontal = true;
    aligning = FuiLayoutProps.Align.Stretch;
    minSize.w = 1;
    minSize.h = 1;
    //clickMask |= FuiLayoutProps.Buttons.Left;
    //canBeFocused = true;
    wantTab = false;
  }
  auto data = ctx.item!FuiCtlCustomBox(item);
  data.type = FuiCtlType.CustomBox;
  data.id.setz(id);
  /*
  data.drawcb = delegate (FuiContext ctx, int self, FuiRect rc) {
    auto win = XtWindow(rc.x, rc.y, rc.w, rc.h);
    win.color = ctx.palColor!"def"(item);
    win.bg = 1;
    win.fill(0, 0, rc.w, rc.h);
  };
  */
  return item;
}


// ////////////////////////////////////////////////////////////////////////// //
struct FuiCtlSpan {
  mixin FuiCtlHeader;
}


int span (FuiContext ctx, int parent, bool ahorizontal) {
  if (!ctx.valid) return -1;
  auto item = ctx.addItem!FuiCtlSpan(parent);
  with (ctx.layprops(item)) {
    flex = 1;
    visible = false;
    horizontal = ahorizontal;
    aligning = (ahorizontal ? FuiLayoutProps.Align.Stretch : FuiLayoutProps.Align.Start);
  }
  auto data = ctx.item!FuiCtlSpan(item);
  data.type = FuiCtlType.Invisible;
  //data.pal = Palette.init;
  return item;
}

int hspan (FuiContext ctx, int parent) { return ctx.span(parent, true); }
int vspan (FuiContext ctx, int parent) { return ctx.span(parent, false); }


int spacer (FuiContext ctx, int parent) {
  if (!ctx.valid) return -1;
  auto item = ctx.addItem!FuiCtlSpan(parent);
  with (ctx.layprops(item)) {
    flex = 0;
    visible = false;
    horizontal = true;
    aligning = FuiLayoutProps.Align.Start;
  }
  auto data = ctx.item!FuiCtlSpan(item);
  data.type = FuiCtlType.Invisible;
  //data.pal = Palette.init;
  return item;
}


int hline (FuiContext ctx, int parent) {
  if (!ctx.valid) return -1;
  auto item = ctx.addItem!FuiCtlSpan(parent);
  with (ctx.layprops(item)) {
    flex = 0;
    visible = true;
    horizontal = true;
    lineBreak = true;
    aligning = FuiLayoutProps.Align.Stretch;
    minSize.h = maxSize.h = 1;
  }
  auto data = ctx.item!FuiCtlSpan(item);
  data.type = FuiCtlType.HLine;
  //data.pal = Palette.init;
  data.drawcb = delegate (FuiContext ctx, int self, FuiRect rc) {
    auto lp = ctx.layprops(self);
    auto win = XtWindow.fullscreen;
    win.color = ctx.palColor!"def"(self);
    if (lp.parent == 0) {
      auto rlp = ctx.layprops(0);
      int x0, x1;
      final switch (ctx.dialogFrame) {
        case FuiDialogFrameType.Normal:
          x0 = rc.x-2;
          x1 = x0+(rlp.position.w-2);
          break;
        case FuiDialogFrameType.Small:
          x0 = rc.x-1;
          x1 = x0+rlp.position.w;
          break;
      }
      win.hline(x0, rc.y, x1-x0);
    } else {
      win.hline(rc.x, rc.y, rc.w);
    }
  };
  return item;
}

// ////////////////////////////////////////////////////////////////////////// //
struct FuiCtlBox {
  mixin FuiCtlHeader;
}


int box (FuiContext ctx, int parent, bool ahorizontal, const(char)[] id=null) {
  if (!ctx.valid) return -1;
  auto item = ctx.addItem!FuiCtlBox(parent);
  with (ctx.layprops(item)) {
    flex = (ahorizontal ? 0 : 1);
    horizontal = ahorizontal;
    aligning = (ahorizontal ? FuiLayoutProps.Align.Stretch : FuiLayoutProps.Align.Start);
    visible = true;
  }
  auto data = ctx.item!FuiCtlBox(item);
  data.type = FuiCtlType.Box;
  //data.pal = Palette.init;
  data.id.setz(id);
  return item;
}

int hbox (FuiContext ctx, int parent, const(char)[] id=null) { return ctx.box(parent, true, id); }
int vbox (FuiContext ctx, int parent, const(char)[] id=null) { return ctx.box(parent, false, id); }


// ////////////////////////////////////////////////////////////////////////// //
struct FuiCtlPanel {
  mixin FuiCtlHeader;
}


int panel (FuiContext ctx, int parent, const(char)[] caption, bool ahorizontal, const(char)[] id=null) {
  if (!ctx.valid) return -1;
  auto item = ctx.addItem!FuiCtlPanel(parent);
  with (ctx.layprops(item)) {
    flex = (ahorizontal ? 0 : 1);
    horizontal = ahorizontal;
    aligning = (ahorizontal ? FuiLayoutProps.Align.Stretch : FuiLayoutProps.Align.Start);
    minSize = FuiSize(visStrLen(caption)+4, 2);
    padding.left = 1;
    padding.right = 1;
    padding.top = 1;
    padding.bottom = 1;
  }
  auto data = ctx.item!FuiCtlPanel(item);
  data.type = FuiCtlType.Panel;
  //data.pal = Palette.init;
  data.id.setz(id);
  data.caption.setz(caption);
  data.drawcb = delegate (FuiContext ctx, int self, FuiRect rc) {
    auto data = ctx.item!FuiCtlPanel(self);
    auto win = XtWindow.fullscreen;
    win.color = ctx.palColor!"def"(self);
    win.frame!true(rc.x, rc.y, rc.w, rc.h);
    win.tuiWriteStr!("center", true)(rc.x+1, rc.y, rc.w-2, data.caption.getz, ctx.palColor!"title"(self), ctx.palColor!"hot"(self));
  };
  return item;
}

int hpanel (FuiContext ctx, int parent, const(char)[] caption, const(char)[] id=null) { return ctx.panel(parent, caption, true, id); }
int vpanel (FuiContext ctx, int parent, const(char)[] caption, const(char)[] id=null) { return ctx.panel(parent, caption, false, id); }


// ////////////////////////////////////////////////////////////////////////// //
struct FuiCtlEditLine {
  mixin FuiCtlHeader;
  align(8) TtyEditor ed;
}
static assert(FuiCtlEditLine.ed.offsetof%4 == 0);


private int editlinetext(bool text) (FuiContext ctx, int parent, const(char)[] id, const(char)[] deftext=null, bool utfuck=false) {
  if (!ctx.valid) return -1;
  auto item = ctx.addItem!FuiCtlEditLine(parent);
  with (ctx.layprops(item)) {
    flex = 0;
    horizontal = true;
    clickMask |= FuiLayoutProps.Buttons.Left;
    canBeFocused = true;
    wantTab = false;
    //aligning = (ahorizontal ? FuiLayoutProps.Align.Stretch : FuiLayoutProps.Align.Start);
    int mw = (deftext.length < 10 ? 10 : deftext.length > 50 ? 50 : cast(int)deftext.length);
    minSize = FuiSize(mw, 1);
    maxSize = FuiSize(int.max-1024, 1);
  }
  auto data = ctx.item!FuiCtlEditLine(item);
  static if (text) {
    data.type = FuiCtlType.EditText;
  } else {
    data.type = FuiCtlType.EditLine;
  }
  //data.pal = Palette.init;
  data.id.setz(id);
  data.ed = new TtyEditor(0, 0, 10, 1, !text); // size will be fixed later
  data.ed.utfuck = utfuck;
  data.ed.doPutText(deftext);
  data.ed.clearUndo();
  static if (!text) data.ed.killTextOnChar = true;
  data.drawcb = delegate (FuiContext ctx, int self, FuiRect rc) {
    auto data = ctx.item!FuiCtlEditLine(self);
    auto lp = ctx.layprops(self);
    auto ed = data.ed;
    ed.moveResize(rc.x, rc.y, rc.w, rc.h);
    ed.fullDirty;
    ed.dontSetCursor = (self != ctx.focused);
    if (lp.enabled) {
      if (self == ctx.focused) {
        ed.clrBlock = ctx.palColor!"inputmark"(self);
        ed.clrText = ctx.palColor!"input"(self);
        ed.clrTextUnchanged = ctx.palColor!"inputunchanged"(self);
      } else {
        ed.clrBlock = ctx.palColor!"inputmark"(self);
        ed.clrText = ctx.palColor!"input"(self);
        ed.clrTextUnchanged = ctx.palColor!"inputunchanged"(self);
      }
    } else {
      ed.clrBlock = ctx.palColor!"disabled"(self);
      ed.clrText = ctx.palColor!"disabled"(self);
      ed.clrTextUnchanged = ctx.palColor!"disabled"(self);
    }
    auto oldcolor = xtGetColor();
    scope(exit) xtSetColor(oldcolor);
    ed.drawPage();
  };
  data.eventcb = delegate (FuiContext ctx, int self, FuiEvent ev) {
    if (ev.item != self) return false;
    auto eld = ctx.item!FuiCtlEditLine(self);
    final switch (ev.type) {
      case FuiEvent.Type.None:
        return false;
      case FuiEvent.Type.Char: // param0: dchar; param1: mods&buttons
        TtyKey k;
        k.key = TtyKey.Key.Char;
        k.ch = ev.ch;
        if (eld.ed.processKey(k)) {
          if (eld.actcb !is null) {
            auto rr = eld.actcb(ctx, ev.item);
            if (rr >= -1) ctx.postClose(rr);
          }
          return true;
        }
        return false;
      case FuiEvent.Type.Key: // param0: sdpy keycode; param1: mods&buttons
        // editline
        if (eld.ed.processKey(ev.key)) {
          if (eld.actcb !is null) {
            auto rr = eld.actcb(ctx, ev.item);
            if (rr >= -1) ctx.postClose(rr);
          }
          return true;
        }
        return false;
      case FuiEvent.Type.Click: // mouse click; param0: buttton index; param1: mods&buttons
        if (eld.ed.processClick(ev.bidx, ev.x, ev.y)) return true;
        return true;
      case FuiEvent.Type.Double: // mouse double-click; param0: buttton index; param1: mods&buttons
        return true;
      case FuiEvent.Type.Close: // close dialog; param0: return id
        return false;
    }
  };
  return item;
}


// `actcb` will be called *after* editor was changed (or not changed, who knows)
int editline (FuiContext ctx, int parent, const(char)[] id, const(char)[] deftext=null, bool utfuck=false) {
  return editlinetext!false(ctx, parent, id, deftext, utfuck);
}


// `actcb` will be called *after* editor was changed (or not changed, who knows)
int edittext (FuiContext ctx, int parent, const(char)[] id, const(char)[] deftext=null, bool utfuck=false) {
  return editlinetext!true(ctx, parent, id, deftext, utfuck);
}


TtyEditor editlineEditor (FuiContext ctx, int item) {
  if (auto data = ctx.item!FuiCtlEditLine(item)) {
    if (data.type == FuiCtlType.EditLine) return data.ed;
  }
  return null;
}


TtyEditor edittextEditor (FuiContext ctx, int item) {
  if (auto data = ctx.item!FuiCtlEditLine(item)) {
    if (data.type == FuiCtlType.EditText) return data.ed;
  }
  return null;
}


char[] editlineGetText (FuiContext ctx, int item) {
  if (auto edl = ctx.itemAs!"editline"(item)) {
    auto ed = edl.ed;
    if (ed is null) return null;
    char[] res;
    auto rng = ed[];
    res.reserve(rng.length);
    foreach (char ch; rng) res ~= ch;
    return res;
  }
  return null;
}


char[] edittextGetText (FuiContext ctx, int item) {
  if (auto edl = ctx.itemAs!"edittext"(item)) {
    auto ed = edl.ed;
    if (ed is null) return null;
    char[] res;
    auto rng = ed[];
    res.reserve(rng.length);
    foreach (char ch; rng) res ~= ch;
    return res;
  }
  return null;
}


// ////////////////////////////////////////////////////////////////////////// //
mixin template FuiCtlBtnLike() {
  mixin FuiCtlHeader;
  char hotchar = 0;
  bool spaceClicks = true;
  bool enterClicks = false;
align(8):
  // internal function, does some action on "click"
  // will be called before `actcb`
  // return `false` if click should not be processed further (no `actcb` will be called)
  bool delegate (FuiContext ctx, int self) doclickcb;
}

struct FuiCtlBtnLikeHead {
  mixin FuiCtlBtnLike;
}


private bool btnlikeClick (FuiContext ctx, int item, int clickButton=-1) {
  if (auto lp = ctx.layprops(item)) {
    if (!lp.visible || lp.disabled || (clickButton >= 0 && lp.clickMask == 0)) return false;
    auto data = ctx.item!FuiCtlBtnLikeHead(item);
    bool clicked = false;
    if (clickButton >= 0) {
      foreach (ubyte shift; 0..8) {
        if (shift == clickButton && (lp.clickMask&(1<<shift)) != 0) { clicked = true; break; }
      }
    } else {
      clicked = true;
    }
    if (clicked) {
      if (data.doclickcb !is null) {
        if (!data.doclickcb(ctx, item)) return false;
      }
      if (data.actcb !is null) {
        auto rr = data.actcb(ctx, item);
        if (rr >= -1) {
          ctx.postClose(rr);
          return true;
        }
      }
      return true;
    }
  }
  return false;
}


private int buttonLike(T, FuiCtlType type) (FuiContext ctx, int parent, const(char)[] id, const(char)[] text) {
  if (!ctx.valid) return -1;
  auto item = ctx.addItem!T(parent);
  auto data = ctx.item!T(item);
  data.type = type;
  //data.pal = Palette.init;
  if (text.length > 255) text = text[0..255];
  if (id.length > 255) id = id[0..255];
  data.id.setz(id);
  data.caption.setz(text);
  if (text.length) {
    data.hotchar = visHotChar(text).toupper;
  } else {
    data.hotchar = 0;
  }
  with (ctx.layprops(item)) {
    flex = 0;
    minSize = FuiSize(visStrLen(data.caption.getz), 1);
    clickMask |= FuiLayoutProps.Buttons.Left;
  }
  data.eventcb = delegate (FuiContext ctx, int self, FuiEvent ev) {
    final switch (ev.type) {
      case FuiEvent.Type.None:
        return false;
      case FuiEvent.Type.Char: // param0: dchar; param1: mods&buttons
        if (ev.item != self) return false;
        auto data = ctx.item!FuiCtlBtnLikeHead(self);
        if (!data.spaceClicks) return false;
        if (ev.ch != ' ') return false;
        if (auto lp = ctx.layprops(self)) {
          if (!lp.visible || lp.disabled) return false;
          if (lp.canBeFocused) ctx.focused = self;
          return ctx.btnlikeClick(self);
        }
        return false;
      case FuiEvent.Type.Key: // param0: sdpy keycode; param1: mods&buttons
        auto data = ctx.item!FuiCtlBtnLikeHead(self);
        auto lp = ctx.layprops(self);
        if (!lp.visible || lp.disabled) return false;
        if (data.enterClicks && ev.item == self && ev.key == "Enter") {
          if (lp.canBeFocused) ctx.focused = self;
          return ctx.btnlikeClick(self);
        }
        if (ev.key.key != TtyKey.Key.ModChar || ev.key.ctrl || !ev.key.alt || ev.key.shift) return false;
        if (data.hotchar != ev.key.ch) return false;
        if (lp.canBeFocused) ctx.focused = self;
        ctx.btnlikeClick(self);
        return true;
      case FuiEvent.Type.Click: // mouse click; param0: buttton index; param1: mods&buttons
        if (ev.item == self) return ctx.btnlikeClick(self, ev.bidx);
        return false;
      case FuiEvent.Type.Double: // mouse double-click; param0: buttton index; param1: mods&buttons
        return false;
      case FuiEvent.Type.Close: // close dialog; param0: return id
        return false;
    }
  };
  return item;
}


// ////////////////////////////////////////////////////////////////////////// //
struct FuiCtlLabel {
  mixin FuiCtlBtnLike;
  ubyte destlen;
  char[256] dest;
}

int label (FuiContext ctx, int parent, const(char)[] id, const(char)[] text, const(char)[] destid=null) {
  auto res = ctx.buttonLike!(FuiCtlLabel, FuiCtlType.Label)(parent, id, text);
  with (ctx.layprops(res)) {
    clickMask = 0;
    canBeFocused = false;
  }
  auto data = ctx.item!FuiCtlLabel(res);
  data.dest.setz(destid);
  if (destid.length == 0) {
    data.hotchar = 0;
    ctx.layprops(res).minSize.w = visStrLen!false(data.caption.getz);
    ctx.layprops(res).clickMask = 0;
  }
  data.spaceClicks = data.enterClicks = false;
  data.drawcb = delegate (FuiContext ctx, int self, FuiRect rc) {
    auto data = ctx.item!FuiCtlLabel(self);
    auto lp = ctx.layprops(self);
    auto win = XtWindow.fullscreen;
    uint anorm, ahot;
    if (lp.enabled) {
      anorm = ctx.palColor!"def"(self);
      ahot = ctx.palColor!"hot"(self);
    } else {
      anorm = ahot = ctx.palColor!"disabled"(self);
    }
    if (data.hotchar) {
      win.tuiWriteStr!("right", false)(rc.x, rc.y, rc.w, data.caption.getz, anorm, ahot);
    } else {
      win.tuiWriteStr!("left", false, false)(rc.x, rc.y, rc.w, data.caption.getz, anorm, ahot);
    }
  };
  data.doclickcb = delegate (FuiContext ctx, int self) {
    auto data = ctx.item!FuiCtlLabel(self);
    auto did = ctx[data.dest.getz];
    if (did <= 0) return false;
    if (auto lp = ctx.layprops(did)) {
      if (lp.canBeFocused && lp.visible && lp.enabled) {
        ctx.focused = did;
        return true;
      }
    }
    return false;
  };
  return res;
}


// ////////////////////////////////////////////////////////////////////////// //
struct FuiCtlButton {
  mixin FuiCtlBtnLike;
}

int button (FuiContext ctx, int parent, const(char)[] id, const(char)[] text) {
  auto item = ctx.buttonLike!(FuiCtlButton, FuiCtlType.Button)(parent, id, text);
  if (item >= 0) {
    with (ctx.layprops(item)) {
      //clickMask |= FuiLayoutProps.Buttons.Left;
      canBeFocused = true;
      minSize.w += 4;
    }
    auto data = ctx.item!FuiCtlButton(item);
    data.spaceClicks = data.enterClicks = true;
    data.drawcb = delegate (FuiContext ctx, int self, FuiRect rc) {
      auto data = ctx.item!FuiCtlButton(self);
      auto lp = ctx.layprops(self);
      auto win = XtWindow.fullscreen;
      uint anorm, ahot;
      int hotx = rc.x;
      if (lp.enabled) {
        if (ctx.focused != self) {
          anorm = ctx.palColor!"def"(self);
          ahot = ctx.palColor!"hot"(self);
        } else {
          anorm = ctx.palColor!"sel"(self);
          ahot = ctx.palColor!"hotsel"(self);
        }
      } else {
        anorm = ahot = ctx.palColor!"disabled"(self);
      }
      win.color = anorm;
      bool def = ((lp.userFlags&FuiCtlUserFlags.Default) != 0);
      if (rc.w == 1) {
        win.writeCharsAt!true(rc.x, rc.y, 1, '`');
      } else if (rc.w == 2) {
        win.writeStrAt(rc.x, rc.y, (def ? "<>" : "[]"));
      } else if (rc.w > 2) {
        win.writeCharsAt(rc.x, rc.y, rc.w, ' ');
        if (def) {
          win.writeCharsAt(rc.x+1, rc.y, 1, '<');
          win.writeCharsAt(rc.x+rc.w-2, rc.y, 1, '>');
        }
        win.writeCharsAt(rc.x, rc.y, 1, '[');
        win.writeCharsAt(rc.x+rc.w-1, rc.y, 1, ']');
        hotx = rc.x+1;
        win.tuiWriteStr!("center", false)(rc.x+2, rc.y, rc.w-4, data.caption.getz, anorm, ahot, &hotx);
      }
      if (ctx.focused == self) win.gotoXY(hotx, rc.y);
    };
    data.doclickcb = delegate (FuiContext ctx, int self) {
      // send "close" to root
      ctx.postClose(self);
      return true;
    };
  }
  return item;
}


// ////////////////////////////////////////////////////////////////////////// //
private void drawCheckRadio(string type) (FuiContext ctx, int self, FuiRect rc, const(char)[] text, bool marked) {
  static assert(type == "checkbox" || type == "radio");
  auto lp = ctx.layprops(self);
  auto win = XtWindow.fullscreen;
  uint anorm, ahot;
  int hotx = rc.x;
  if (lp.enabled) {
    if (ctx.focused != self) {
      anorm = ctx.palColor!"def"(self);
      ahot = ctx.palColor!"hot"(self);
    } else {
      anorm = ctx.palColor!"sel"(self);
      ahot = ctx.palColor!"hotsel"(self);
    }
  } else {
    anorm = ahot = ctx.palColor!"disabled"(self);
  }
  win.color = anorm;
  win.writeCharsAt(rc.x, rc.y, rc.w, ' ');
  char markCh = ' ';
  if (marked) {
         static if (type == "checkbox") markCh = 'x';
    else static if (type == "radio") markCh = '*';
    else static assert(0, "wtf?!");
  }
  if (rc.w == 1) {
    win.writeCharsAt(rc.x, rc.y, 1, markCh);
  } else if (rc.w == 2) {
    win.writeCharsAt(rc.x, rc.y, 1, markCh);
    win.writeCharsAt(rc.x+1, rc.y, 1, ' ');
  } else if (rc.w > 2) {
         static if (type == "checkbox") win.writeStrAt(rc.x, rc.y, "[ ]");
    else static if (type == "radio") win.writeStrAt(rc.x, rc.y, "( )");
    else static assert(0, "wtf?!");
    if (markCh != ' ') win.writeCharsAt(rc.x+1, rc.y, 1, markCh);
    hotx = rc.x+1;
    win.tuiWriteStr!("left", false)(rc.x+4, rc.y, rc.w-4, text, anorm, ahot);
  }
  if (ctx.focused == self) win.gotoXY(hotx, rc.y);
}


struct FuiCtlCheck {
  mixin FuiCtlBtnLike;
  bool* var;
}

int checkbox (FuiContext ctx, int parent, const(char)[] id, const(char)[] text, bool* var) {
  auto item = ctx.buttonLike!(FuiCtlCheck, FuiCtlType.Check)(parent, id, text);
  if (item >= 0) {
    auto data = ctx.item!FuiCtlCheck(item);
    data.spaceClicks = true;
    data.enterClicks = false;
    data.var = var;
    with (ctx.layprops(item)) {
      //clickMask |= FuiLayoutProps.Buttons.Left;
      canBeFocused = true;
      minSize.w += 4;
    }
    data.drawcb = delegate (FuiContext ctx, int self, FuiRect rc) {
      auto data = ctx.item!FuiCtlCheck(self);
      bool marked = (data.var !is null ? *data.var : false);
      ctx.drawCheckRadio!"checkbox"(self, rc, data.caption.getz, marked);
    };
    data.doclickcb = delegate (FuiContext ctx, int self) {
      auto data = ctx.item!FuiCtlCheck(self);
      if (data.var !is null) *data.var = !*data.var;
      return true;
    };
  }
  return item;
}


// ////////////////////////////////////////////////////////////////////////// //
struct FuiCtlRadio {
  mixin FuiCtlBtnLike;
  int gid; // radio group index; <0: standalone
  int* var;
}

private int countRadio (FuiContext ctx, int* var) {
  if (!ctx.valid || var is null) return -1;
  int res = 0;
  foreach (int fid; 1..ctx.length) {
    if (auto data = ctx.item!FuiCtlRadio(fid)) {
      if (data.type == FuiCtlType.Radio) {
        if (data.var is var) ++res;
      }
    }
  }
  return res;
}

int radio (FuiContext ctx, int parent, const(char)[] id, const(char)[] text, int* var) {
  auto item = ctx.buttonLike!(FuiCtlRadio, FuiCtlType.Radio)(parent, id, text);
  if (item >= 0) {
    auto gid = ctx.countRadio(var);
    auto data = ctx.item!FuiCtlRadio(item);
    data.spaceClicks = true;
    data.enterClicks = false;
    data.var = var;
    data.gid = gid;
    with (ctx.layprops(item)) {
      flex = 0;
      //clickMask |= FuiLayoutProps.Buttons.Left;
      canBeFocused = true;
      minSize.w += 4;
    }
    data.drawcb = delegate (FuiContext ctx, int self, FuiRect rc) {
      auto data = ctx.item!FuiCtlRadio(self);
      bool marked = (data.var ? (*data.var == data.gid) : false);
      ctx.drawCheckRadio!"radio"(self, rc, data.caption.getz, marked);
    };
    data.doclickcb = delegate (FuiContext ctx, int self) {
      auto data = ctx.item!FuiCtlRadio(self);
      if (data.var !is null) *data.var = data.gid;
      return true;
    };
  }
  return item;
}


// ////////////////////////////////////////////////////////////////////////// //
struct FuiCtlTextView {
  mixin FuiCtlHeader;
  uint textlen;
  int topline;
  char[0] text; // this *will* be modified by wrapper; '\1' is "soft wrap"; '\0' is EOT
}


// `actcb` will be called *after* editor was changed (or not changed, who knows)
int textview (FuiContext ctx, int parent, const(char)[] id, const(char)[] text) {
  if (!ctx.valid) return -1;
  if (text.length > 256*1024) throw new Exception("text view: text too long");
  auto item = ctx.addItem!FuiCtlTextView(parent, cast(int)text.length+256);
  with (ctx.layprops(item)) {
    flex = 1;
    aligning = FuiLayoutProps.Align.Stretch;
    clickMask |= FuiLayoutProps.Buttons.WheelUp|FuiLayoutProps.Buttons.WheelDown;
    //canBeFocused = true;
  }
  auto data = ctx.item!FuiCtlTextView(item);
  data.type = FuiCtlType.TextView;
  //data.pal = Palette.init;
  data.id.setz(id);
  data.textlen = cast(uint)text.length;
  if (text.length > 0) {
    data.text.ptr[0..text.length] = text[];
    int c, r;
    data.textlen = calcTextBoundsEx(c, r, data.text.ptr[0..data.textlen], ttyw-8);
    //with (ctx.layprops(item).maxSize) { w = c; h = r; }
    with (ctx.layprops(item).minSize) { w = c+2; h = r; }
    //with (ctx.layprops(item).minSize) { w = 2; h = 1; }
  }
  data.drawcb = delegate (FuiContext ctx, int self, FuiRect rc) {
    if (rc.w < 1 || rc.h < 1) return;
    auto data = ctx.item!FuiCtlTextView(self);
    auto lp = ctx.layprops(self);
    //auto win = XtWindow.fullscreen;
    auto win = XtWindow(rc.x, rc.y, rc.w, rc.h);
    if (lp.enabled) {
      win.color = ctx.palColor!"def"(self);
    } else {
      win.color = ctx.palColor!"disabled"(self);
    }
    //win.fill(rc.x, rc.y, rc.w, rc.h);
    win.fill(0, 0, rc.w, rc.h);
    if (data.textlen) {
      int c, r;
      data.textlen = calcTextBoundsEx(c, r, data.text.ptr[0..data.textlen], rc.w-lp.padding.left-lp.padding.right);
      if (data.topline < 0) data.topline = 0;
      if (data.topline+rc.h >= r) {
        data.topline = r-rc.h;
        if (data.topline < 0) data.topline = 0;
      }
      bool wantSBar = (r > rc.h);
      int xofs = (wantSBar ? 2 : 1);
      uint tpos = 0;
      int ty = -data.topline;
      int talign = 0; // 0: left; 1: right; 2: center;
      if (data.textlen > 0 && data.text.ptr[0] >= 1 && data.text.ptr[0] <= 3) {
        talign = data.text.ptr[tpos]-1;
        ++tpos;
      }
      while (tpos < data.textlen && ty < rc.h) {
        uint epos = tpos;
        while (epos < data.textlen && data.text.ptr[epos] != '\n' && data.text.ptr[epos] != '\6') {
          if (epos-tpos == rc.w) break;
          ++epos;
        }
        final switch (talign) {
          case 0: // left
            win.writeStrAt(xofs, ty, data.text.ptr[tpos..epos]);
            break;
          case 1: // right
            win.writeStrAt(rc.w-xofs-(epos-tpos), ty, data.text.ptr[tpos..epos]);
            break;
          case 2: // center
            win.writeStrAt(xofs+(rc.w-xofs-(epos-tpos))/2, ty, data.text.ptr[tpos..epos]);
            break;
        }
        if (epos < data.textlen && data.text.ptr[epos] <= ' ') {
          if (data.textlen-epos > 1 && data.text.ptr[epos] == '\n' && data.text.ptr[epos+1] >= 1 && data.text.ptr[epos+1] <= 3) {
            ++epos;
            talign = data.text.ptr[epos]-1;
          } else {
            // keep it
            //talign = 0;
          }
          ++epos;
        }
        tpos = epos;
        ++ty;
      }
      // draw scrollbar
      if (wantSBar) {
        //win.color = atext;
        win.vline(1, 0, rc.h);
        int last = data.topline+rc.h;
        if (last > r) last = r;
        last = rc.h*last/r;
        foreach (int yy; 0..rc.h) win.writeCharsAt!true(0, yy, 1, (yy <= last ? 'a' : ' '));
      }
    }
  };
  data.eventcb = delegate (FuiContext ctx, int self, FuiEvent ev) {
    if (ev.item != self) return false;
    final switch (ev.type) {
      case FuiEvent.Type.None:
        return false;
      case FuiEvent.Type.Char: // param0: dchar; param1: mods&buttons
        return false;
      case FuiEvent.Type.Key: // param0: sdpy keycode; param1: mods&buttons
        auto lp = ctx.layprops(self);
        if (lp !is null) {
          if (!lp.visible || lp.disabled) return false;
        } else {
          return false;
        }
        if (auto tv = ctx.itemAs!"textview"(self)) {
          if (ev.key == "Up") { --tv.topline; return true; }
          if (ev.key == "Down") { ++tv.topline; return true; }
          if (ev.key == "Home") { tv.topline = 0; return true; }
          if (ev.key == "End") { tv.topline = int.max/2; return true; }
          int pgstep = lp.position.h-1;
          if (pgstep < 1) pgstep = 1;
          if (ev.key == "PageUp") { tv.topline -= pgstep; return true; }
          if (ev.key == "PageDown") { tv.topline += pgstep; return true; }
        }
        return false;
      case FuiEvent.Type.Click: // mouse click; param0: buttton index; param1: mods&buttons
        return false;
      case FuiEvent.Type.Double: // mouse double-click; param0: buttton index; param1: mods&buttons
        return false;
      case FuiEvent.Type.Close: // close dialog; param0: return id
        return false;
    }
  };
  return item;
}


// ////////////////////////////////////////////////////////////////////////// //
struct FuiCtlListBoxItem {
  uint nextofs;
  uint length;
  char[0] text;
}

struct FuiCtlListBox {
  mixin FuiCtlHeader;
  int itemCount; // total number of items
  int topItem;
  int curItem;
  int maxWidth;
  uint firstItemOffset; // in layout buffer
  uint lastItemOffset; // in layout buffer
  uint topItemOffset; // in layout buffer
}


// return `true` if it has scrollbar
bool listboxNormPage (FuiContext ctx, int item) {
  auto data = ctx.item!FuiCtlListBox(item);
  if (data is null) return false;
  auto lp = ctx.layprops(item);
  // make current item visible
  if (data.itemCount == 0) return false;
  // sanitize current item (just in case, it should be sane always)
  if (data.curItem < 0) data.curItem = 0;
  if (data.curItem >= data.itemCount) data.curItem = data.itemCount-1;
  int oldtop = data.topItem;
  if (data.topItem > data.itemCount-lp.position.h) data.topItem = data.itemCount-lp.position.h;
  if (data.topItem < 0) data.topItem = 0;
  if (data.curItem < data.topItem) {
    data.topItem = data.curItem;
  } else if (data.topItem+lp.position.h <= data.curItem) {
    data.topItem = data.curItem-lp.position.h+1;
    if (data.topItem < 0) data.topItem = 0;
  }
  if (data.topItem != oldtop || data.topItemOffset == 0) {
    data.topItemOffset = ctx.listboxItemOffset(item, data.topItem);
    assert(data.topItemOffset != 0);
  }
  bool wantSBar = false;
  // should i draw a scrollbar?
  if (lp.position.w > 2 && (data.topItem > 0 || data.topItem+lp.position.h < data.itemCount)) {
    // yes
    wantSBar = true;
  }
  return wantSBar;
}


// `actcb` will be called *after* editor was changed (or not changed, who knows)
int listbox (FuiContext ctx, int parent, const(char)[] id) {
  if (!ctx.valid) return -1;
  auto item = ctx.addItem!FuiCtlListBox(parent);
  if (item == -1) return -1;
  with (ctx.layprops(item)) {
    flex = 1;
    aligning = FuiLayoutProps.Align.Stretch;
    clickMask |= FuiLayoutProps.Buttons.Left|FuiLayoutProps.Buttons.WheelUp|FuiLayoutProps.Buttons.WheelDown;
    canBeFocused = true;
    minSize = FuiSize(5, 2);
  }
  auto data = ctx.item!FuiCtlListBox(item);
  data.type = FuiCtlType.ListBox;
  //data.pal = Palette.init;
  data.id.setz(id);
  data.drawcb = delegate (FuiContext ctx, int self, FuiRect rc) {
    auto data = ctx.item!FuiCtlListBox(self);
    auto lp = ctx.layprops(self);
    auto win = XtWindow.fullscreen;
    // get colors
    uint atext, asel, agauge;
    if (lp.enabled) {
      atext = ctx.palColor!"def"(self);
      asel = ctx.palColor!"sel"(self);
      agauge = ctx.palColor!"gauge"(self);
    } else {
      atext = asel = agauge = ctx.palColor!"disabled"(self);
    }
    win.color = atext;
    win.fill(rc.x, rc.y, rc.w, rc.h);
    // make current item visible
    if (data.itemCount == 0) return;
    // sanitize current item (just in case, it should be sane always)
    if (data.curItem < 0) data.curItem = 0;
    if (data.curItem >= data.itemCount) data.curItem = data.itemCount-1;
    int oldtop = data.topItem;
    if (data.topItem > data.itemCount-rc.h) data.topItem = data.itemCount-rc.h;
    if (data.topItem < 0) data.topItem = 0;
    if (data.curItem < data.topItem) {
      data.topItem = data.curItem;
    } else if (data.topItem+rc.h <= data.curItem) {
      data.topItem = data.curItem-rc.h+1;
      if (data.topItem < 0) data.topItem = 0;
    }
    if (data.topItem != oldtop || data.topItemOffset == 0) {
      data.topItemOffset = ctx.listboxItemOffset(self, data.topItem);
      assert(data.topItemOffset != 0);
    }
    bool wantSBar = false;
    int wdt = rc.w;
    int x = 0, y = 0;
    // should i draw a scrollbar?
    if (wdt > 2 && (data.topItem > 0 || data.topItem+rc.h < data.itemCount)) {
      // yes
      wantSBar = true;
      wdt -= 2;
      x += 2;
    } else {
      x += 1;
      wdt -= 1;
    }
    x += rc.x;
    // draw items
    auto itofs = data.topItemOffset;
    auto curit = data.topItem;
    while (itofs != 0 && y < rc.h) {
      auto it = ctx.structAtOfs!FuiCtlListBoxItem(itofs);
      auto t = it.text.ptr[0..it.length];
      if (t.length > wdt) t = t[0..wdt];
      if (curit == data.curItem) {
        win.color = asel;
        // fill cursor
        win.writeCharsAt(x-(wantSBar ? 0 : 1), rc.y+y, wdt+(wantSBar ? 0 : 1), ' ');
        if (self == ctx.focused) win.gotoXY(x-(wantSBar ? 0 : 1), rc.y+y);
      } else {
        win.color = atext;
      }
      win.writeStrAt(x, rc.y+y, t);
      itofs = it.nextofs;
      ++y;
      ++curit;
    }
    // draw scrollbar
    if (wantSBar) {
      x -= 2;
      win.color = atext;
      win.vline(x+1, rc.y, rc.h);
      win.color = agauge; //atext;
      int last = data.topItem+rc.h;
      if (last > data.itemCount) last = data.itemCount;
      last = rc.h*last/data.itemCount;
      foreach (int yy; 0..rc.h) win.writeCharsAt!true(x, rc.y+yy, 1, (yy <= last ? 'a' : ' '));
    }
  };
  data.eventcb = delegate (FuiContext ctx, int self, FuiEvent ev) {
    if (ev.item != self) return false;
    final switch (ev.type) {
      case FuiEvent.Type.None:
        return false;
      case FuiEvent.Type.Char: // param0: dchar; param1: mods&buttons
        return false;
      case FuiEvent.Type.Key: // param0: sdpy keycode; param1: mods&buttons
        if (auto lp = ctx.layprops(self)) {
          if (!lp.visible || lp.disabled) return false;
        } else {
          return false;
        }
        if (auto lbox = ctx.itemAs!"listbox"(self)) {
          bool procIt() () {
            auto lp = ctx.layprops(ev.item);
            if (ev.key == "Up") {
              if (--lbox.curItem < 0) lbox.curItem = 0;
              return true;
            }
            if (ev.key == "S-Up") {
              if (--lbox.topItem < 0) lbox.topItem = 0;
              lbox.topItemOffset = 0; // invalidate
              return true;
            }
            if (ev.key == "Down") {
              if (lbox.itemCount > 0) {
                if (++lbox.curItem >= lbox.itemCount) lbox.curItem = lbox.itemCount-1;
              }
              return true;
            }
            if (ev.key == "S-Down") {
              if (lbox.topItem+lp.position.h < lbox.itemCount) {
                ++lbox.topItem;
                lbox.topItemOffset = 0; // invalidate
              }
              return true;
            }
            if (ev.key == "Home") {
              lbox.curItem = 0;
              return true;
            }
            if (ev.key == "End") {
              if (lbox.itemCount > 0) lbox.curItem = lbox.itemCount-1;
              return true;
            }
            if (ev.key == "PageUp") {
              if (lbox.curItem > lbox.topItem) {
                lbox.curItem = lbox.topItem;
              } else if (lp.position.h > 1) {
                if ((lbox.curItem -= lp.position.h-1) < 0) lbox.curItem = 0;
              }
              return true;
            }
            if (ev.key == "PageDown") {
              if (lbox.curItem < lbox.topItem+lp.position.h-1) {
                lbox.curItem = lbox.topItem+lp.position.h-1;
              } else if (lp.position.h > 1 && lbox.itemCount > 0) {
                if ((lbox.curItem += lp.position.h-1) >= lbox.itemCount) lbox.curItem = lbox.itemCount-1;
              }
              return true;
            }
            return false;
          }
          ctx.listboxNormPage(self);
          auto oldCI = lbox.curItem;
          if (procIt()) {
            ctx.listboxNormPage(self);
            if (oldCI != lbox.curItem && lbox.actcb !is null) {
              auto rr = lbox.actcb(ctx, self);
              if (rr >= -1) ctx.postClose(rr);
            }
            return true;
          }
        }
        return false;
      case FuiEvent.Type.Click: // mouse click; param0: buttton index; param1: mods&buttons
        if (auto lbox = ctx.itemAs!"listbox"(self)) {
          ctx.listboxNormPage(self);
          auto oldCI = lbox.curItem;
          if (ev.bidx == FuiLayoutProps.Button.WheelUp) {
            if (--lbox.curItem < 0) lbox.curItem = 0;
          } else if (ev.bidx == FuiLayoutProps.Button.WheelDown) {
            if (lbox.itemCount > 0) {
              if (++lbox.curItem >= lbox.itemCount) lbox.curItem = lbox.itemCount-1;
            }
          } else if (ev.x > 0) {
            int it = lbox.topItem+ev.y;
            lbox.curItem = it;
          }
          ctx.listboxNormPage(self);
          if (oldCI != lbox.curItem && lbox.actcb !is null) {
            auto rr = lbox.actcb(ctx, self);
            if (rr >= -1) ctx.postClose(rr);
          }
        }
        return true;
      case FuiEvent.Type.Double: // mouse double-click; param0: buttton index; param1: mods&buttons
        return false;
      case FuiEvent.Type.Close: // close dialog; param0: return id
        return false;
    }
  };
  return item;
}


void listboxItemAdd (FuiContext ctx, int item, const(char)[] text) {
  if (auto data = ctx.itemAs!"listbox"(item)) {
    int len = (text.length < 255 ? cast(int)text.length : 255);
    uint itofs;
    auto it = ctx.addStruct!FuiCtlListBoxItem(itofs, len);
    it.length = len;
    if (text.length <= 255) {
      it.text.ptr[0..text.length] = text[];
    } else {
      it.text.ptr[0..256] = text[0..256];
      it.text.ptr[253..256] = '.';
    }
    if (data.maxWidth < len) data.maxWidth = len;
    if (data.firstItemOffset == 0) {
      data.firstItemOffset = itofs;
      data.topItemOffset = itofs;
    } else {
      auto prev = ctx.structAtOfs!FuiCtlListBoxItem(data.lastItemOffset);
      prev.nextofs = itofs;
    }
    data.lastItemOffset = itofs;
    ++data.itemCount;
    auto lp = ctx.layprops(item);
    if (lp.minSize.w < len+3) lp.minSize.w = len+3;
    if (lp.minSize.h < data.itemCount) lp.minSize.h = data.itemCount;
    if (lp.minSize.w > lp.maxSize.w) lp.minSize.w = lp.maxSize.w;
    if (lp.minSize.h > lp.maxSize.h) lp.minSize.h = lp.maxSize.h;
  }
}


int listboxMaxItemWidth (FuiContext ctx, int item) {
  if (auto data = ctx.itemAs!"listbox"(item)) return data.maxWidth+2;
  return 0;
}


int listboxItemCount (FuiContext ctx, int item) {
  if (auto data = ctx.itemAs!"listbox"(item)) return data.itemCount;
  return 0;
}


int listboxItemCurrent (FuiContext ctx, int item) {
  if (auto data = ctx.itemAs!"listbox"(item)) return data.curItem;
  return 0;
}


void listboxItemSetCurrent (FuiContext ctx, int item, int cur) {
  if (auto data = ctx.itemAs!"listbox"(item)) {
    if (data.itemCount > 0) {
      if (cur < 0) cur = 0;
      if (cur > data.itemCount) cur = data.itemCount-1;
      data.curItem = cur;
    }
  }
}


private uint listboxItemOffset (FuiContext ctx, int item, int inum) {
  if (auto data = ctx.itemAs!"listbox"(item)) {
    if (inum > data.itemCount) inum = data.itemCount-1;
    if (inum < 0) inum = 0;
    uint itofs = data.firstItemOffset;
    while (inum-- > 0) {
      assert(itofs > 0);
      auto it = ctx.structAtOfs!FuiCtlListBoxItem(itofs);
      if (it.nextofs == 0) break;
      itofs = it.nextofs;
    }
    return itofs;
  }
  return 0;
}


// ////////////////////////////////////////////////////////////////////////// //
// returned value valid until first layout change
const(char)[] itemId (FuiContext ctx, int item) nothrow @trusted @nogc {
  if (auto lp = ctx.item!FuiCtlHead(item)) return lp.id.getz;
  return null;
}


// ////////////////////////////////////////////////////////////////////////// //
// return item id or -1
int findById (FuiContext ctx, const(char)[] id) nothrow @trusted @nogc {
  foreach (int fid; 0..ctx.length) {
    if (auto data = ctx.item!FuiCtlHead(fid)) {
      if (data.id.getz == id) return fid;
    }
  }
  return -1;
}


auto itemAs(string type) (FuiContext ctx, int item) nothrow @trusted @nogc {
  if (!ctx.valid) return null;
  static if (type.strEquCI("hline")) {
    enum ctp = FuiCtlType.HLine;
    alias tp = FuiCtlSpan;
  } else static if (type.strEquCI("box") || type.strEquCI("vbox") || type.strEquCI("hbox")) {
    enum ctp = FuiCtlType.Box;
    alias tp = FuiCtlBox;
  } else static if (type.strEquCI("panel") || type.strEquCI("vpanel") || type.strEquCI("hpanel")) {
    enum ctp = FuiCtlType.Panel;
    alias tp = FuiCtlPanel;
  } else static if (type.strEquCI("editline")) {
    enum ctp = FuiCtlType.EditLine;
    alias tp = FuiCtlEditLine;
  } else static if (type.strEquCI("edittext")) {
    enum ctp = FuiCtlType.EditText;
    alias tp = FuiCtlEditLine;
  } else static if (type.strEquCI("label")) {
    enum ctp = FuiCtlType.Label;
    alias tp = FuiCtlLabel;
  } else static if (type.strEquCI("button")) {
    enum ctp = FuiCtlType.Button;
    alias tp = FuiCtlButton;
  } else static if (type.strEquCI("check") || type.strEquCI("checkbox")) {
    enum ctp = FuiCtlType.Check;
    alias tp = FuiCtlCheck;
  } else static if (type.strEquCI("radio") || type.strEquCI("radio")) {
    enum ctp = FuiCtlType.Radio;
    alias tp = FuiCtlRadio;
  } else static if (type.strEquCI("textview")) {
    enum ctp = FuiCtlType.TextView;
    alias tp = FuiCtlTextView;
  } else static if (type.strEquCI("listbox")) {
    enum ctp = FuiCtlType.ListBox;
    alias tp = FuiCtlListBox;
  } else static if (type.strEquCI("custombox")) {
    enum ctp = FuiCtlType.CustomBox;
    alias tp = FuiCtlCustomBox;
  } else {
    static assert(0, "invalid control type: '"~type~"'");
  }
  if (auto data = ctx.item!FuiCtlHead(item)) {
    if (data.type == ctp) return ctx.item!tp(item);
  }
  return null;
}


auto itemAs(string type) (FuiContext ctx, const(char)[] id) nothrow @trusted @nogc {
  if (!ctx.valid) return null;
  foreach (int fid; 0..ctx.length) {
    if (auto data = ctx.itemAs!type(fid)) {
      if (data.id.getz == id) return data;
    }
  }
  return null;
}


FuiCtlType itemType (FuiContext ctx, int item) nothrow @trusted @nogc {
  if (!ctx.valid) return FuiCtlType.Invisible;
  if (auto data = ctx.itemIntr!FuiCtlHead(item)) return data.type;
  return FuiCtlType.Invisible;
}


// ////////////////////////////////////////////////////////////////////////// //
void focusFirst (FuiContext ctx) nothrow @trusted @nogc {
  if (!ctx.valid) return;
  auto fid = ctx.focused;
  if (fid < 1 || fid >= ctx.length) fid = 0;
  auto lp = ctx.layprops(fid);
  if (fid < 1 || fid >= ctx.length || !lp.visible || !lp.enabled || !lp.canBeFocused) {
    for (fid = 1; fid < ctx.length; ++fid) {
      lp = ctx.layprops(fid);
      if (lp is null) continue;
      if (lp.visible && lp.enabled && lp.canBeFocused) {
        ctx.focused = fid;
        return;
      }
    }
  }
}


int findDefault (FuiContext ctx) nothrow @trusted @nogc {
  if (!ctx.valid) return -1;
  foreach (int fid; 0..ctx.length) {
    if (auto lp = ctx.layprops(fid)) {
      if (lp.visible && lp.enabled && lp.canBeFocused && (lp.userFlags&FuiCtlUserFlags.Default) != 0) return fid;
    }
  }
  return -1;
}


// ////////////////////////////////////////////////////////////////////////// //
void dialogPalette (FuiContext ctx, int palidx) {
  if (palidx < 0 || palidx >= tuiPalette.length) palidx = 0;
  if (auto data = ctx.itemIntr!FuiCtlHead(0)) {
    data.pal = tuiPalette[palidx];
  }
}


void palColor(string name) (FuiContext ctx, int itemid, uint clr) {
  if (auto data = ctx.item!FuiCtlHead(itemid)) {
    mixin("data.pal."~name~" = clr;");
  }
}


// ////////////////////////////////////////////////////////////////////////// //
uint palColor(string name) (FuiContext ctx, int itemid) {
  uint res;
  for (;;) {
    if (auto data = ctx.itemIntr!FuiCtlHead(itemid)) {
      res = mixin("data.pal."~name);
      if (res) break;
      itemid = ctx.layprops(itemid).parent;
    } else {
      res = mixin("tuiPalette[TuiPaletteNormal]."~name);
      break;
    }
  }
  return (res ? res : XtColorFB!(ttyRgb2Color(0xd0, 0xd0, 0xd0), ttyRgb2Color(0x4e, 0x4e, 0x4e))); // 252,239
}


// ////////////////////////////////////////////////////////////////////////// //
private void tuiWriteStr(string defcenter, bool spaces, bool dohot=true) (auto ref XtWindow win, int x, int y, int w, const(char)[] s, uint attr, uint hotattr, int* hotx=null) {
  static assert(defcenter == "left" || defcenter == "right" || defcenter == "center");
  if (hotx !is null) *hotx = x;
  if (w < 1) return;
  win.color = attr;
  static if (spaces) { x += 1; w -= 2; }
  if (w < 1 || s.length == 0) return;
  int sx = x, ex = x+w-1;
  auto vislen = visStrLen!dohot(s);
  if (s.ptr[0] == '\x01') {
    // left, nothing to do
    s = s[1..$];
  } else if (s.ptr[0] == '\x02') {
    // right
    x += (w-vislen);
    s = s[1..$];
  } else if (s.ptr[0] == '\x03') {
    // center
    auto len = visStrLen(s);
    x += (w-len)/2;
    s = s[1..$];
  } else {
    static if (defcenter == "left") {
    } else static if (defcenter == "right") {
      x += (w-vislen);
    } else static if (defcenter == "center") {
      // center
      x += (w-vislen)/2;
    }
  }
  bool wasHot;
  static if (spaces) {
    win.writeCharsAt(x-1, y, 1, ' ');
    int ee = x+vislen;
    if (ee <= ex+1) win.writeCharsAt(ee, y, 1, ' ');
  }
  while (s.length > 0) {
    if (dohot && s.length > 1 && s.ptr[0] == '&' && s.ptr[1] != '&') {
      if (!wasHot && hotx !is null) *hotx = x;
      if (x >= sx && x <= ex) {
        if (hotattr && !wasHot) win.color = hotattr;
        win.writeCharsAt(x, y, 1, s.ptr[1]);
        win.color = attr;
      }
      s = s[2..$];
      wasHot = true;
    } else if (dohot && s.length > 1 && s.ptr[0] == '&' && s.ptr[1] != '&') {
      if (x >= sx && x <= ex) win.writeCharsAt(x, y, 1, s.ptr[0]);
      s = s[2..$];
    } else {
      if (x >= sx && x <= ex) win.writeCharsAt(x, y, 1, s.ptr[0]);
      s = s[1..$];
    }
    ++x;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
// we have to draw shadow separately, so it won't get darken each time
void drawShadow (FuiContext ctx) nothrow @trusted @nogc {
  if (!ctx.valid) return;
  auto lp = ctx.layprops(0);
  if (lp is null) return;
  auto rc = lp.position;
  xtShadowBox(rc.x+rc.w, rc.y+1, 2, rc.h-1);
  xtHShadow(rc.x+2, rc.y+rc.h, rc.w);
}


void draw (FuiContext ctx) {
  if (!ctx.valid) return;

  void drawItem (int item, FuiPoint g) {
    auto lp = ctx.layprops(item);
    if (lp is null) return;
    if (!lp.visible) return;

    // convert local coords to global coords
    auto rc = lp.position;
    // don't shift root panes, it is already shifted
    if (item != 0) {
      rc.xp += g.x;
      rc.yp += g.y;
    }

    void drawRootFrame (bool secondpass=false) {
      auto dlgdata = ctx.itemIntr!FuiCtlRootPanel(0);
      auto anorm = ctx.palColor!"def"(item);
      auto atitle = ctx.palColor!"title"(item);
      auto win = XtWindow.fullscreen;
      win.color = (!dlgdata.moving ? anorm : atitle);
      if (rc.w > 0 && rc.h > 0) {
        auto data = ctx.itemIntr!FuiCtlRootPanel(0);
        if (!secondpass) win.fill(rc.x, rc.y, rc.w, rc.h);
        final switch (data.frame) {
          case FuiDialogFrameType.Normal:
            win.frame!false(rc.x+1, rc.y+1, rc.w-2, rc.h-2);
            win.tuiWriteStr!("center", true)(rc.x+1, rc.y+1, rc.w-2, data.caption.getz, atitle, atitle);
            break;
          case FuiDialogFrameType.Small:
            win.frame!false(rc.x, rc.y, rc.w, rc.h);
            win.tuiWriteStr!("center", true)(rc.x+1, rc.y, rc.w-2, data.caption.getz, atitle, atitle);
            break;
        }
      }
    }

    bool root = (item == 0);
    if (item == 0) drawRootFrame();
    {
      auto head = ctx.itemIntr!FuiCtlHead(item);
      if (head.drawcb !is null) head.drawcb(ctx, item, rc);
    }

    // draw children
    item = lp.firstChild;
    lp = ctx.layprops(item);
    if (lp !is null) {
      while (lp !is null) {
        drawItem(item, rc.pos);
        item = lp.nextSibling;
        lp = ctx.layprops(item);
      }
    }

    if (root) {
      auto dlgdata = ctx.itemIntr!FuiCtlRootPanel(0);
      if (dlgdata.moving) drawRootFrame(true);
    }
  }

  drawItem(0, ctx.layprops(0).position.pos);
}


// ////////////////////////////////////////////////////////////////////////// //
// returns `true` if event was consumed
bool processEvent (FuiContext ctx, FuiEvent ev) {
  if (!ctx.valid) return false;

  if (auto rd = ctx.itemIntr!FuiCtlHead(0)) {
    if (rd.eventcb !is null) {
      if (rd.eventcb(ctx, ev.item, ev)) return true;
    }
  }

  if (ev.item > 0) {
    if (auto lp = ctx.layprops(ev.item)) {
      if (lp.visible && !lp.disabled) {
        auto data = ctx.itemIntr!FuiCtlHead(ev.item);
        assert(data !is null);
        if (data.eventcb !is null) {
          //{ import iv.vfs.io; VFile("z00.log", "a").writeln("ev.item=", ev.item); }
          if (data.eventcb(ctx, ev.item, ev)) return true;
        }
      }
    }
  }

  // event is not processed
  if (ev.type == FuiEvent.Type.Char) {
    // broadcast char as ModChar
    auto ch = ev.ch;
    if (ch > ' ' && ch < 256) ch = toupper(cast(char)ch);
    ev.type = FuiEvent.Type.Key;
    ev.keyp = TtyKey.init;
    ev.keyp.key = TtyKey.Key.ModChar;
    ev.keyp.ctrl = false;
    ev.keyp.alt = true;
    ev.keyp.shift = false;
    ev.keyp.ch = ch;
    //assert(ev.type == FuiEvent.Type.Key);
  } else {
    if (ev.type != FuiEvent.Type.Key) return false;
  }
  // do navigation
  if (ev.key == "Enter") {
    // either current or default
    auto def = ctx.findDefault;
    if (def >= 0) return ctx.btnlikeClick(def);
    if (auto rd = ctx.itemIntr!FuiCtlRootPanel(0)) {
      if (rd.enterclose) {
        // send "close" to root with root as result
        ctx.postClose(0);
        return true;
      }
    }
    return false;
  }
  if (ev.key == "Up" || ev.key == "Left") { ctx.focusPrev(); return true; }
  if (ev.key == "Down" || ev.key == "Right") { ctx.focusNext(); return true; }
  // broadcast ModChar, so widgets can process hotkeys
  if (ev.key.key == TtyKey.Key.ModChar && !ev.key.ctrl && ev.key.alt && !ev.key.shift) {
    auto res = ctx.findNextEx(0, (int id) {
      if (auto lp = ctx.layprops(id)) {
        if (lp.visible && !lp.disabled) {
          auto data = ctx.item!FuiCtlHead(id);
          if (data.eventcb !is null) {
            if (data.eventcb(ctx, id, ev)) return true;
          }
        }
      }
      return false;
    });
    if (res >= 0) return true;
  }
  return false;
}


// ////////////////////////////////////////////////////////////////////////// //
__gshared FuiContext tuiCurrentContext;

// returns clicked item or -1 for esc
int modalDialog(bool docenter=true) (FuiContext ctx) {
  if (!ctx.valid) return -1;

  scope(exit) {
    import core.memory : GC;
    GC.collect;
    GC.minimize;
  }

  void saveArea () {
    xtPushArea(
      ctx.layprops(0).position.x, ctx.layprops(0).position.y,
      ctx.layprops(0).position.w+2, ctx.layprops(0).position.h+1
    );
  }

  int processContextEvents () {
    ctx.update();
    while (ctx.hasEvents) {
      auto ev = ctx.getEvent();
      if (ev.type == FuiEvent.Type.Close) return ev.result;
      if (ctx.processEvent(ev)) continue;
    }
    return -666;
  }

  static if (docenter) {
    if (auto lp = ctx.layprops(0)) {
      if (lp.position.x == 0) lp.position.x = (ttyw-lp.position.w)/2;
      if (lp.position.y == 0) lp.position.y = (ttyh-lp.position.h)/2;
    }
  }
  ctx.focusFirst();

  auto octx = tuiCurrentContext;
  tuiCurrentContext = ctx;
  scope(exit) tuiCurrentContext = octx;

  saveArea();
  scope(exit) xtPopArea();

  bool windowMoving;
  int wmX, wmY;

  ctx.drawShadow();
  for (;;) {
    int res = processContextEvents();
    if (res >= -1) return res;
    if (windowMoving) ctx.dialogMoving = true;
    ctx.draw;
    if (windowMoving) ctx.dialogMoving = false;
    xtFlush(); // show screen
    auto key = ttyReadKey(-1, TtyDefaultEscWait);
    if (key.key == TtyKey.Key.Error) { return -1; }
    if (key.key == TtyKey.Key.Unknown) continue;
    if (key.key == TtyKey.Key.Escape) { return -1; }
    if (key == "^L") { xtFullRefresh(); continue; }
    int dx = 0, dy = 0;
    if (key == "M-Left") dx = -1;
    if (key == "M-Right") dx = 1;
    if (key == "M-Up") dy = -1;
    if (key == "M-Down") dy = 1;
    // move dialog with mouse
    if (windowMoving && key.mouse) {
      if (key.mrelease && key.button == 0) {
        windowMoving = false;
        continue;
      }
      dx = key.x-wmX;
      dy = key.y-wmY;
      wmX = key.x;
      wmY = key.y;
    }
    if (dx || dy) {
      xtPopArea();
      ctx.layprops(0).position.x = ctx.layprops(0).position.x+dx;
      ctx.layprops(0).position.y = ctx.layprops(0).position.y+dy;
      saveArea();
      ctx.drawShadow();
      continue;
    }
    if (windowMoving) continue;
    if (key.mouse) {
      //TODO: check for no frame when we'll get that
      if (key.mpress && key.button == 0 && key.y == ctx.layprops(0).position.y && key.x >= ctx.layprops(0).position.x && key.x < ctx.layprops(0).position.x+ctx.layprops(0).position.w) {
        windowMoving = true;
        wmX = key.x;
        wmY = key.y;
        continue;
      }
    }
    ctx.keyboardEvent(key);
  }
}
