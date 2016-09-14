/* Invisible Vector Library
 * simple FlexBox-based TUI engine
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
module iv.egtui.dialogs;

import iv.rawtty2;
import iv.strex;
import iv.vfs.io;

import iv.egtui.tty;
import iv.egtui.tui;
import iv.egtui.parser;


// ///////////////////////////////////////////////////////////////////////// //
void dialogMessage(string type, A...) (const(char)[] title, const(char)[] fmt, A args) {
  static assert(type == "error" || type == "info" || type == "debug", "invalid message dialog type");

  enum laydesc = q{
    caption: "$title"
    small-frame: false

    label: { align: expand  caption: "$msg" }

    hline

    hbox: {
      hspan
      button: { id: "btclose"  caption: "&Close" }
      hspan
    }
  };

  import std.format : format;
  string msg = fmt.format(args);

  auto ctx = FuiContext.create();
  static if (type == "error") {
    ctx.dialogPalette(TuiPaletteError/*TuiPaletteNormal*/);
  }
  ctx.parse!(title, msg)(laydesc);
  ctx.relayout();
  ctx.modalDialog;
}


// ///////////////////////////////////////////////////////////////////////// //
int dialogTanOna (const(char)[] title, const(char)[] text, bool def) {
  enum laydesc = q{
    caption: $title
    small-frame: false
    // hbox for text
    hbox: {
      textview: {
        id: "text"
        text: `\C$text`
      }
    }
    hline
    // center buttons
    hbox: {
      spacing: 1
      span //: { flex: 1 }
      button: { id: "bttan" caption: "&tan" }
      //spacer: { width: 1 } // this hack just inserts space
      button: { id: "btona" caption: "o&na" }
      span //: { flex: 1 }
    }
  };

  auto ctx = FuiContext.create();
  //ctx.maxDimensions = FuiSize(ttyw, ttyh);
  ctx.parse!(title, text)(laydesc);
  ctx.relayout();
  ctx.focused = ctx[def ? "bttan" : "btona"];
  auto res = ctx.modalDialog;
  if (res >= 0) return (ctx.itemId(res) == "bttan" ? 1 : 0);
  return -1;
}


// ///////////////////////////////////////////////////////////////////////// //
// result.ptr is null: calcelled
string dialogInputLine (const(char)[] msg, const(char)[] def=null) {
  enum laydesc = q{
    caption: "Input query"
    small-frame: false
    // hbox for text
    label: {
      align: expand
      text: `\L$msg:`
    }
    editline: {
      align: expand
      id: "ed"
      text: "$def"
    }
    hline
    // center buttons
    hbox: {
      spacing: 1
      hspan
      button: { id: "btok" caption: " O&K " default }
      button: { id: "btcancel" caption: "&Cancel" }
      hspan
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

  ctx.parse!(msg, def)(laydesc);
  ctx.relayout();
  if (ctx.layprops(0).position.w < ttyw/3*2) {
    ctx.layprops(0).minSize.w = ttyw/3*2;
    ctx.relayout();
  }
  auto res = ctx.modalDialog;
  if (res >= 0) {
    if (auto edl = ctx.itemAs!"editline"(ctx["ed"])) {
      auto ed = edl.ed;
      char[] rs;
      auto rng = ed[];
      if (rng.length == 0) return ""; // so it won't be null
      rs.reserve(rng.length);
      foreach (char ch; rng) rs ~= ch;
      return cast(string)rs; // it is safe to cast it here
    }
  }
  return null;
}


// ///////////////////////////////////////////////////////////////////////// //
void dialogTextView (const(char)[] title, const(char)[] text) {
  enum laydesc = q{
    caption: "$title"
    small-frame: false

    max-width: $winmw
    max-height: $winmh
    height: $winmh

    textview: {
      id: "text"
      text: "$text"
      max-width: $mw
      //max-height: $mh
      flex: 1  // eat all possible vertical space
      can-be-focused
    }

    hline

    hbox: {
      hspan
      button: { id: "btclose"  caption: "&Close" }
      hspan
    }
  };

  int winmw = ttyw-8;
  int winmh = ttyh-4;
  //winmh = 24;

  int mw = winmw-6;
  int mh = winmh-6;

  auto ctx = FuiContext.create();
  ctx.parse!(title, text, mw, mh, winmw, winmh)(laydesc);
  ctx.relayout();
  int th = ctx.textviewHeight(ctx["text"]);
  if (th < mh) {
    // fix size and relayout
    auto lpr = ctx.layprops(0);
    lpr.minSize.h = lpr.maxSize.h = lpr.position.h-(mh-th);
    lpr.position.y = 0; // make sure that `modalDialog()` will center it
    ctx.relayout();
  }
  ctx.modalDialog;
}
