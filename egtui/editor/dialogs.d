/* Invisible Vector Library
 * simple FlexBox-based TUI engine
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 3 of the License ONLY.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */
module iv.egtui.editor.dialogs /*is aliced*/;

import iv.alice;
import iv.rawtty;
import iv.strex;
import iv.vfs.io;

import iv.egtui.tty;
import iv.egtui.tui;
import iv.egtui.parser;


/* history ids for editor dialogs:
 * dlg-linenum-lnum
 *  line number dialog
 *
 * dlg-tabsize-tabsize"
 *  tab size dialog
 *
 * dlg-srr-edsearch
 *  search-and-replace dialog, search pattern
 *
 * dlg-srr-edreplace
 *  search-and-replace dialog, replace pattern
 */


// ///////////////////////////////////////////////////////////////////////// //
int dialogFileModified (const(char)[] filename, bool def, const(char)[] query="File was modified. Save it?") {
  string dotsdots = "";
  if (filename.length > ttyw-10) {
    // strip filename
    dotsdots = "...";
    filename = filename[$-(ttyw-13)..$];
  }

  enum laydesc = q{
    caption: "File was modified!"
    small-frame: false
    // hbox for text
    hbox: {
      textview: {
        id: "text"
        text: `\C${query}\n\C<${dotsdots}${filename}>`
      }
    }
    hline
    // center buttons
    hbox: {
      span: { flex: 1 }
      button: { id: "bttan" caption: "&tan" }
      spacer: { width: 1 } // this hack just inserts space
      button: { id: "btona" caption: "o&na" }
      span: { flex: 1 }
    }
  };

  auto ctx = FuiContext.create();
  //ctx.maxDimensions = FuiSize(ttyw, ttyh);
  ctx.parse!(dotsdots, filename, query)(laydesc);
  ctx.relayout();
  ctx.focused = ctx[def ? "bttan" : "btona"];
  auto res = ctx.modalDialog;
  if (res >= 0) return (ctx.itemId(res) == "bttan" ? 1 : 0);
  return -1;
}


// ///////////////////////////////////////////////////////////////////////// //
// 0: invalid number
int dialogLineNumber (FuiHistoryManager dghisman, int defval=-1) {
  enum laydesc = q{
    caption: "Select line number"
    small-frame: false
    // hbox for text
    hbox: {
      label: {
        text: `\RLine &number: `
        dest: "lnum"
      }
      editline: {
        flex: 1
        id: "dlg-linenum-lnum"
        on-action: validate
      }
    }
    hline
    // center buttons
    hbox: {
      span: { flex: 1 }
      button: { id: "btok" caption: " O&K " default }
      span: { flex: 1 }
    }
  };

  auto ctx = FuiContext.create();

  int edGetNum (int item) {
    if (auto edl = ctx.itemAs!"editline"(item)) {
      auto ed = edl.ed;
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
    return -1;
  }

  int validate (FuiContext ctx, int item) {
    ctx.setEnabled(ctx["btok"], edGetNum(item) > 0);
    return FuiContinue;
  }

  //ctx.maxDimensions = FuiSize(ttyw, ttyh);
  ctx.parse!(validate)(laydesc);
  ctx.dialogHistoryManager = dghisman;
  ctx.relayout();
  validate(ctx, ctx["dlg-linenum-lnum"]);
  //ctx.focused = ctx["dlg-linenum-lnum"];
  if (defval > 0) {
    import std.conv : to;
    with (ctx.itemAs!"editline"("dlg-linenum-lnum")) ed.setNewText(defval.to!string);
    validate(ctx, ctx["dlg-linenum-lnum"]);
  }
  auto res = ctx.modalDialog;
  if (res >= 0) {
    auto ln = edGetNum(ctx["dlg-linenum-lnum"]);
    if (ln > 0) {
      if (auto hisman = ctx.dialogHistoryManager) {
        import std.conv : to;
        hisman.add("dlg-linenum-lnum", ln.to!string);
      }
    }
    return ln;
  }
  return -1;
}


// ///////////////////////////////////////////////////////////////////////// //
// <=0: invalid number
int dialogTabSize (FuiHistoryManager dghisman, int defval) {
  enum laydesc = q{
    caption: "Select Tab Size"
    small-frame: false
    // hbox for text
    hbox: {
      label: {
        text: `\R&Tab size: `
        dest: "dlg-tabsize-tabsize"
      }
      editline: {
        flex: 1
        id: "dlg-tabsize-tabsize"
        on-action: validate
      }
    }
    hline
    // center buttons
    hbox: {
      span: { flex: 1 }
      button: { id: "btok" caption: " O&K " default }
      span: { flex: 1 }
    }
  };

  auto ctx = FuiContext.create();

  int edGetNum (int item) {
    if (auto edl = ctx.itemAs!"editline"(item)) {
      auto ed = edl.ed;
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
    return -1;
  }

  int validate (FuiContext ctx, int item) {
    auto num = edGetNum(item);
    ctx.setEnabled(ctx["btok"], (num > 0 && num <= 32));
    return FuiContinue;
  }

  //ctx.maxDimensions = FuiSize(ttyw, ttyh);
  ctx.parse!(validate)(laydesc);
  ctx.dialogHistoryManager = dghisman;
  ctx.relayout();
  validate(ctx, ctx["dlg-tabsize-tabsize"]);
  //ctx.focused = ctx["dlg-tabsize-tabsize"];
  if (defval > 0) {
    import std.conv : to;
    with (ctx.itemAs!"editline"("dlg-tabsize-tabsize")) ed.setNewText(defval.to!string);
    validate(ctx, ctx["dlg-tabsize-tabsize"]);
  }
  auto res = ctx.modalDialog;
  if (res >= 0) {
    auto ts = edGetNum(ctx["dlg-tabsize-tabsize"]);
    if (ts > 0) {
      if (auto hisman = ctx.dialogHistoryManager) {
        import std.conv : to;
        hisman.add("dlg-tabsize-tabsize", ts.to!string);
      }
    }
    return ts;
  }
  return -1;
}


// ///////////////////////////////////////////////////////////////////////// //
// <0: cancel
struct SearchReplaceOptions {
  // WARNING! keep in sync with window layout!
  enum Type : int {
    Normal,
    Regex,
  }
  const(char)[] search;
  const(char)[] replace;
  bool inselenabled = true; // "in selection" enabled
  bool utfuck;
  Type type;
  bool casesens;
  bool backwards;
  bool wholeword;
  bool inselection;
  bool nocomments;
}

bool dialogSearchReplace (FuiHistoryManager dghisman, ref SearchReplaceOptions opts) {
  enum laydesc = q{
    caption: "Replace"
    small-frame: false

    label: { caption: "&Search string:"  dest: "dlg-srr-edsearch" }
    editline: { align: expand  id: "dlg-srr-edsearch"  text: "$searchstr"  on-action: validate  utfuck: $utfuck }

    label: { caption: "Re&placement string:"  dest: "dlg-srr-edreplace" }
    editline: { align: expand  id: "dlg-srr-edreplace"  text: "$replacestr"  on-action: validate  utfuck: $utfuck }

    hline

    hbox: {
      spacing: 1
      vbox: {
        flex: 0
        radio: { caption: "No&rmal"  bind-var: opttype }
        radio: { caption: "Re&gular expression"  bind-var: opttype }
      }
      vbox: {
        flex: 0
        checkbox: { caption: "Cas&e sensitive"  bind-var: optci }
        checkbox: { caption: "&Backwards"  bind-var: optback }
        checkbox: { caption: "&Whole words"  bind-var: optword }
        checkbox: { caption: "In se&lection"  id: "cbinsel"  bind-var: optsel }
        checkbox: { caption: "S&kip comments"  id: "cbnocom"  bind-var: optnocom }
      }
    }

    hline

    hbox: {
      spacing: 1
      hspan
      button: { id: "btok"  caption: " O&K "  default }
      button: { id: "btcancel"  caption: "&Cancel" }
      hspan
    }
  };

  bool utfuck = opts.utfuck;
  int opttype = opts.type;
  bool optci = opts.casesens;
  bool optback = opts.backwards;
  bool optword = opts.wholeword;
  bool optsel = opts.inselection;
  bool optnocom = opts.nocomments;
  auto searchstr = opts.search;
  auto replacestr = opts.replace;

  auto ctx = FuiContext.create();

  int validate (FuiContext ctx, int item=-1) {
    bool ok = true;
    if (auto edl = ctx.itemAs!"editline"("dlg-srr-edsearch")) {
      if (edl.ed.textsize == 0) ok = false;
    }
    ctx.setEnabled(ctx["btok"], ok);
    ctx.setEnabled(ctx["cbinsel"], opts.inselenabled);
    return FuiContinue;
  }

  //searchstr = "koi";
  //replacestr = "w";
  //opttype = SearchReplaceOptions.Type.Regex;

  ctx.parse!(opttype, optci, optback, optsel, searchstr, replacestr, validate, utfuck, optword, optnocom)(laydesc);
  ctx.dialogHistoryManager = dghisman;
  ctx.relayout();
  if (ctx.layprops(0).position.w < ttyw/3*2) {
    ctx.layprops(0).minSize.w = ttyw/3*2;
    ctx.relayout();
  }
  validate(ctx);
  auto res = ctx.modalDialog;
  if (ctx.itemId(res) == "btok") {
    opts.type = cast(SearchReplaceOptions.Type)(opttype >= SearchReplaceOptions.Type.min && opttype <= SearchReplaceOptions.Type.max ? opttype : 0);
    opts.casesens = optci;
    opts.backwards = optback;
    opts.wholeword = optword;
    opts.inselection = optsel;
    opts.nocomments = optnocom;
    opts.search = ctx.editlineGetText(ctx["dlg-srr-edsearch"]);
    opts.replace = ctx.editlineGetText(ctx["dlg-srr-edreplace"]);
    if (auto hisman = ctx.dialogHistoryManager) {
      hisman.add("dlg-srr-edsearch", opts.search);
      hisman.add("dlg-srr-edreplace", opts.replace);
    }
    return true;
  }
  return false;
}


// ///////////////////////////////////////////////////////////////////////// //
enum DialogRepPromptResult {
  Cancel = -1,
  Skip = 0,
  Replace = 1,
  All = 2
}

DialogRepPromptResult dialogReplacePrompt (int sy=-1) {
  enum laydesc = q{
    caption: "Confirm replace"
    small-frame: false

    label: { align: expand  caption: `\CPattern found. What to do?` }

    hline

    hbox: {
      spacing: 1
      hspan
      button: { id: "btreplace"  caption: " &Replace " default }
      button: { id: "btall"  caption: "A&ll" }
      button: { id: "btskip"  caption: "&Skip" }
      button: { id: "btcancel"  caption: "&Cancel" }
      hspan
    }
  };

  auto ctx = FuiContext.create();
  ctx.parse(laydesc);
  ctx.relayout();
  if (sy >= 0 && sy < ttyh) {
    if (sy+1+ctx.layprops(0).position.h < ttyh-1) {
      ctx.layprops(0).position.y = sy+1;
    } else if (sy-1-ctx.layprops(0).position.h >= 0) {
      ctx.layprops(0).position.y = sy-1-ctx.layprops(0).position.h;
    }
  }
  auto res = ctx.modalDialog;
  if (res < 0) return DialogRepPromptResult.Cancel;
  auto rid = ctx.itemId(res);
  if (rid == "btreplace") return DialogRepPromptResult.Replace;
  if (rid == "btall") return DialogRepPromptResult.All;
  if (rid == "btskip") return DialogRepPromptResult.Skip;
  return DialogRepPromptResult.Cancel;
}


// ///////////////////////////////////////////////////////////////////////// //
// <0: cancelled
int dialogCodePage (int curcp) {
  enum laydesc = q{
    caption: "Select codepage"
    small-frame: false

    listbox: {
      id: "lbcp"
      items: {
        "KOI8-U"
        "CP1251"
        "CP866"
        "UTF-8"
      }
    }

    hline

    hbox: {
      spacing: 1
      hspan
      button: { id: "btok"  caption: " O&K "  default }
      button: { id: "btcancel"  caption: "&Cancel" }
      hspan
    }
  };

  auto ctx = FuiContext.create();
  ctx.parse(laydesc);
  ctx.relayout();
  if (curcp < 0) curcp = 0; else if (curcp > 3) curcp = 3;
  ctx.listboxItemSetCurrent(ctx["lbcp"], curcp);
  //ctx.setDialogPalette(TuiPaletteError);
  auto res = ctx.modalDialog;
  if (ctx.itemId(res) != "btok") return -1;
  return ctx.listboxItemCurrent(ctx["lbcp"]);
}


// ///////////////////////////////////////////////////////////////////////// //
// return -1 on escape or index
// tries to show it under (or above) (winx, winy), so the line itself is visible
int dialogSelectAC(T : const(char)[]) (T[] items, int winx, int winy, int idx=0, int maxhgt=-1) {
  if (items.length == 0) return -1;

  if (maxhgt < 0 || maxhgt > ttyh) maxhgt = ttyh;
  if (maxhgt < 3) maxhgt = 3;

  int maxwdt = ttyw;
  if (maxwdt < 3) maxwdt = 3;

  int topline = 0;
  int maxlen = 0;
  foreach (const s; items) if (s.length > maxlen) maxlen = cast(int)s.length;
  if (maxlen > ttyw-4) maxlen = ttyw-4;

  int pgsize = cast(int)items.length;
  if (pgsize > maxhgt-2) pgsize = maxhgt-2;

  if (winx < 0) {
    winx = (ttyw-(maxlen+4))/2;
    if (winx < 0) winx = 0;
  }
  if (winy < 0) {
    winy = (ttyh-(pgsize+2))/2;
    if (winy < 0) winy = 0;
  }

  int x0 = winx;
  int y0 = winy;
  // no room to show it at the bottom?
  if (y0+pgsize+1 > ttyh) {
    y0 = winy-pgsize-2;
    // no room to show it at the top? center it then
    if (y0 < 0 || y0 >= ttyh) y0 = (ttyh-(pgsize+2))/2;
  }
  if (x0+maxlen+4 > ttyw) x0 = ttyw-maxlen-4;
  if (x0 < 0) x0 = 0;
  if (y0 < 0) y0 = 0;

  int winhgt = pgsize+2;
  int winwdt = maxlen+4;

  enum laydesc = q{
    //caption: "Completions"
    small-frame: true
    enter-close: true
    min-height: $winhgt
    min-width: $winwdt
    max-height: $maxhgt
    max-width: $maxwdt

    listbox: {
      id: "lbac"
      flex: 1
      align: expand
    }
  };

  auto ctx = FuiContext.create();
  ctx.parse!(winhgt, winwdt, maxwdt, maxhgt)(laydesc);

  // add items
  auto lbi = ctx["lbac"];
  assert(lbi > 0);
  foreach (const s; items) ctx.listboxItemAdd(lbi, s);
  //ctx.listboxItemSetCurrent(lbi, cast(int)items.length-1);

  ctx.relayout();
  ctx.layprops(0).position.x = x0;
  ctx.layprops(0).position.y = y0;
  auto res = ctx.modalDialog!false; // don't center
  if (res < 0) return -1;
  return ctx.listboxItemCurrent(lbi);
}
