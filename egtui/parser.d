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
module iv.egtui.parser;

import iv.strex;
import iv.rawtty2;

import iv.egtui.tty;
import iv.egtui.tui;


// ////////////////////////////////////////////////////////////////////////// //
void tuiParse(Vars...) (ref FuiContext ctx, const(char)[] text) {
  ctx.clearControls();

  auto rmd = ctx.maxDimensions;
  if (rmd.w < 1) rmd.w = ttyw;
  if (rmd.h < 1) rmd.h = ttyh;
  ctx.maxDimensions = rmd;

  // stupid "reusable string" thingy
  static struct DynStr {
    char[] buf;

    @disable this (this); // no copies
    ~this () nothrow { delete buf; buf = null; }

    void reset () nothrow {
      if (buf.length > 0) {
        buf.length = 0;
        buf.assumeSafeAppend;
      }
    }

    @property int pos () const pure nothrow @safe @nogc { pragma(inline, true); return cast(int)buf.length; }
    @property void pos (int v) nothrow {
      if (v < buf.length) {
        buf.length = (v > 0 ? v : 0);
        buf.assumeSafeAppend;
      }
    }

    const(char)[] opSlice () const pure nothrow @safe @nogc { pragma(inline, true); return buf[]; }
    const(char)[] opSlice (usize lo, usize hi) const pure nothrow @safe @nogc { pragma(inline, true); return buf[lo..hi]; }

    char opIndex (usize idx) const pure nothrow @safe @nogc { pragma(inline, true); return buf[idx]; }

    @property usize length () const pure nothrow @safe @nogc { pragma(inline, true); return buf.length; }
    alias opDollar = length;

    void put (const(char)[] s...) nothrow @safe { pragma(inline, true); buf ~= s; }

    @property bool empty () const pure nothrow @safe @nogc { pragma(inline, true); return (buf.length == 0); }
    @property const(char)[] getz () const pure nothrow @safe @nogc { pragma(inline, true); return buf[]; }
  }

  DynStr tokenbuf;
  bool eof;
  bool hasValue;
  bool tkstr;

  void skipBlanks () {
    while (text.length > 0) {
      if (text.length > 1 && text.ptr[0] == '/' && text.ptr[1] == '/') {
        while (text.length && text.ptr[0] != '\n') text = text[1..$];
      } else if (text.length > 1 && text.ptr[0] == '#') {
        while (text.length && text.ptr[0] != '\n') text = text[1..$];
      } else if (text.length > 1 && text.ptr[0] == '/' && text.ptr[1] == '*') {
        text = text[2..$];
        while (text.length) {
          if (text.length < 2) { text = text[$..$]; break; }
          if (text.ptr[0] == '*' && text.ptr[1] == '/') { text = text[2..$]; break; }
          text = text[1..$];
        }
      } else if (text.length > 1 && text.ptr[0] == '/' && text.ptr[1] == '+') {
        text = text[2..$];
        int level = 1;
        while (text.length) {
          if (text.length < 2) { text = text[$..$]; break; }
          if (text.ptr[0] == '+' && text.ptr[1] == '/') {
            text = text[2..$];
            if (--level == 0) break;
            continue;
          }
          if (text.ptr[0] == '/' && text.ptr[1] == '+') {
            text = text[2..$];
            ++level;
            continue;
          }
          text = text[1..$];
        }
      } else if (text.ptr[0] <= ' ') {
        text = text[1..$];
      } else {
        break;
      }
    }
  }

  void nextToken () {
    bool processVarSubst () {
      if (text.length < 2) return false;
      if (text.ptr[0] == '\\' && text.ptr[1] == '$') {
        tokenbuf.put('$');
        text = text[2..$];
        return true;
      }
      if (text.ptr[0] != '$') return false;
      if (text.ptr[1] == '$') {
        tokenbuf.put('$');
        text = text[2..$];
        return true;
      }
      auto stpos = tokenbuf.pos;
      if (text.ptr[1].isalpha || text.ptr[1].isalpha == '_') {
        text = text[1..$];
        while (text.length > 0) {
          char ch = text.ptr[0];
          if (ch != '_' && ch != '-') {
            if (ch <= ' ' || !isalnum(ch)) break;
          }
          tokenbuf.put(ch);
          text = text[1..$];
        }
      } else if (text.ptr[1] == '{') {
        usize pos = 2;
        while (pos < text.length) {
          if (text.ptr[pos] == '\n') return false;
          if (text.ptr[pos] == '}') break;
          ++pos;
        }
        if (pos >= text.length) return false;
        tokenbuf.put(text[2..pos]);
        text = text[pos+1..$];
      } else {
        return false;
      }
      auto name = tokenbuf[stpos..$];
      //{ import iv.vfs.io; VFile("z00.log", "a").writeln(name.quote); }
      foreach (immutable idx, var; Vars) {
        static if (!is(typeof(var) == function) && !is(typeof(var) == delegate)) {
          import std.conv : to;
          static if (is(typeof({auto s = var.to!string;}))) {
            if (Vars[idx].stringof == name) {
              tokenbuf.pos = stpos;
              tokenbuf.put(Vars[idx].to!string);
            }
          }
        }
      }
      return true;
    }

    skipBlanks();
    tokenbuf.reset();
    hasValue = false;
    tkstr = false;
    eof = false;
    if (text.length == 0) { eof = true; return; }
    if (text.ptr[0] == '"' || text.ptr[0] == '\'' || text.ptr[0] == '`') {
      char ech = text.ptr[0];
      text = text[1..$];
      char ch = ' ';
      tkstr = true;
      while (text.length > 0) {
        ch = text.ptr[0];
        if (processVarSubst()) continue;
        text = text[1..$];
        if (ch == ech) break;
        if (ch == '\\' && text.length > 0) {
          ch = text.ptr[0];
          text = text[1..$];
          switch (ch) {
            case 't': ch = '\t'; break;
            case 'n': ch = '\n'; break;
            case 'L': ch = '\x01'; break;
            case 'R': ch = '\x02'; break;
            case 'C': ch = '\x03'; break;
            default:
              if (ch == 'x' || ch == 'X') {
                if (text.length == 0) throw new Exception("invalid escape");
                int n = digitInBase(text.ptr[0], 16);
                if (n < 0) throw new Exception("invalid escape");
                text = text[1..$];
                if (text.length && digitInBase(text.ptr[0], 16) >= 0) {
                  n = n*16+digitInBase(text.ptr[0], 16);
                  text = text[1..$];
                }
                ch = cast(char)n;
              } else if (ch.isalnum) {
                throw new Exception("invalid escape");
              }
              break;
          }
        }
        tokenbuf.put(ch);
      }
      if (ch != ech) throw new Exception("unterminated string");
      skipBlanks();
      if (text.length && text.ptr[0] == ':') {
        text = text[1..$];
        hasValue = true;
      }
    } else if (processVarSubst()) {
      skipBlanks();
      if (text.length && text.ptr[0] == ':') {
        text = text[1..$];
        hasValue = true;
      }
    } else if (text.ptr[0].isalnum || text.ptr[0] == '_' || text.ptr[0] == '-') {
      while (text.length > 0) {
        char ch = text.ptr[0];
        if (ch != '_' && ch != '-') {
          if (ch <= ' ' || !isalnum(ch)) break;
        }
        tokenbuf.put(ch);
        text = text[1..$];
      }
      skipBlanks();
      if (text.length && text.ptr[0] == ':') {
        text = text[1..$];
        hasValue = true;
      }
    } else {
      assert(text.length > 0);
      tokenbuf.put(text.ptr[0]);
      text = text[1..$];
    }
  }

  const(char)[] token () { pragma(inline, true); return tokenbuf.getz; }

  DynStr widname;

  // "{" eaten
  void skipGroup () {
    for (;;) {
      nextToken();
      if (eof) break;
      if (tkstr) continue;
      if (token == "{") skipGroup();
      if (token == "}") break;
    }
  }

  int getInt () {
    import std.conv : to;
    if (!hasValue) throw new Exception("number value expected");
    nextToken();
    if (tkstr || eof) throw new Exception("number expected");
    if (hasValue) throw new Exception("number expected");
    auto t = token;
    if (t.length == 0 || !t.ptr[0].isdigit) throw new Exception("number expected");
    return t.to!int;
  }

  int getBool () {
    if (!hasValue) return 1;
    nextToken();
    if (tkstr || eof) throw new Exception("boolean expected");
    if (hasValue) throw new Exception("boolean expected");
    auto t = token;
    if (t.strEquCI("yes") || t.strEquCI("tan") || t.strEquCI("true") || t.strEquCI("y") || t.strEquCI("t")) return 1;
    if (t.strEquCI("no") || t.strEquCI("ona") || t.strEquCI("false") || t.strEquCI("n") || t.strEquCI("f") || t.strEquCI("o")) return 0;
    throw new Exception("boolean expected, but got '"~t.idup~"'");
  }

  void getStr (ref DynStr dest) {
    if (!hasValue) throw new Exception("string value expected");
    nextToken();
    if (eof) throw new Exception("string value expected");
    dest.reset();
    dest.put(token);
  }

  int getClickMask () {
    if (!hasValue) throw new Exception("clickmask value expected");
    nextToken();
    if (hasValue || eof) throw new Exception("clickmask expected");
    auto t = token.xstrip;
    int res;
    while (t.length > 0) {
      int pos = 0;
      while (pos < t.length && t.ptr[0] > ' ' && t.ptr[0] != ',') ++pos;
      if (pos > 0) {
        auto n = t[0..pos];
        t = t[pos..$];
             if (n.strEquCI("left")) res |= FuiLayoutProps.Buttons.Left;
        else if (n.strEquCI("right")) res |= FuiLayoutProps.Buttons.Right;
        else if (n.strEquCI("middle")) res |= FuiLayoutProps.Buttons.Middle;
        else throw new Exception("invalid button name: '"~n.idup~"'");
      }
      while (t.length && (t.ptr[0] <= ' ' || t.ptr[0] == ',')) t = t[1..$];
    }
    return res;
  }

  struct Props {
    // properties
    int paddingLeft = -1;
    int paddingRight = -1;
    int paddingTop = -1;
    int paddingBottom = -1;
    int flex = -1, spacing = -1;
    int clickMask = -1, doubleMask = -1;
    int linebreak = -1;
    int canbefocused = -1;
    int hv = -1;
    int def = -1;
    int smallframe = -1;
    int wpalign = -1;
    int minw = -1, minh = -1;
    int maxw = -1, maxh = -1;
    int disabled = -1;
    int alert = -1;
    int utfuck = -1;
    int enterclose = -1;
    DynStr id;
    DynStr caption;
    DynStr hgroup;
    DynStr vgroup;
    DynStr dest;
    DynStr bindvar;
    DynStr bindfunc;

    void reset () {
      foreach (ref v; this.tupleof) {
        static if (is(typeof(v) == DynStr)) v.reset;
        else static if (is(typeof(v) == int)) v = -1;
      }
    }

    // token: prop name
    bool parseProp () {
      auto ts = token;
      if (ts.strEquCI("flex")) { flex = getInt(); return true; }
      if (ts.strEquCI("vertical")) { if (getBool) hv = 1; else hv = 0; return true; }
      if (ts.strEquCI("horizontal")) { if (getBool) hv = 0; else hv = 1; return true; }
      if (ts.strEquCI("orientation")) {
        if (!hasValue) throw new Exception("value expected");
        nextToken();
        if (eof) throw new Exception("value expected");
             if (token.strEquCI("horizontal")) hv = 0;
        else if (token.strEquCI("vertical")) hv = 1;
        else throw new Exception("invalid orientation: '"~token.idup~"'");
        return true;
      }
      if (ts.strEquCI("align")) {
        if (!hasValue) throw new Exception("value expected");
        nextToken();
        if (eof) throw new Exception("value expected");
             if (token.strEquCI("center")) wpalign = FuiLayoutProps.Align.Center;
        else if (token.strEquCI("start")) wpalign = FuiLayoutProps.Align.Start;
        else if (token.strEquCI("end")) wpalign = FuiLayoutProps.Align.End;
        else if (token.strEquCI("stretch")) wpalign = FuiLayoutProps.Align.Stretch;
        else if (token.strEquCI("expand")) wpalign = FuiLayoutProps.Align.Stretch;
        else throw new Exception("invalid align: '"~token.idup~"'");
        return true;
      }
      if (ts.strEquCI("lineBreak") || ts.strEquCI("line-break")) { linebreak = getBool; return true; }
      if (ts.strEquCI("canBeFocused") || ts.strEquCI("can-be-focused")) { canbefocused = getBool; return true; }
      if (ts.strEquCI("id")) { getStr(id); return true; }
      if (ts.strEquCI("caption")) { getStr(caption); return true; }
      if (ts.strEquCI("text")) { getStr(caption); return true; } // alias for "caption"
      if (ts.strEquCI("dest")) { getStr(dest); return true; }
      if (ts.strEquCI("hgroup")) { getStr(hgroup); return true; }
      if (ts.strEquCI("vgroup")) { getStr(vgroup); return true; }
      if (ts.strEquCI("bindVar") || ts.strEquCI("bind-var")) { getStr(bindvar); return true; }
      if (ts.strEquCI("bindFunc") || ts.strEquCI("bind-func")) { getStr(bindfunc); return true; }
      if (ts.strEquCI("paddingLeft") || ts.strEquCI("padding-left")) { paddingLeft = getInt(); return true; }
      if (ts.strEquCI("paddingTop") || ts.strEquCI("padding-top")) { paddingTop = getInt(); return true; }
      if (ts.strEquCI("paddingRight") || ts.strEquCI("padding-right")) { paddingRight = getInt(); return true; }
      if (ts.strEquCI("paddingBottom") || ts.strEquCI("padding-bottom")) { paddingBottom = getInt(); return true; }
      if (ts.strEquCI("spacing")) { spacing = getInt(); return true; }
      if (ts.strEquCI("width")) { minw = getInt(); return true; }
      if (ts.strEquCI("height")) { minh = getInt(); return true; }
      if (ts.strEquCI("min-width")) { minw = getInt(); return true; }
      if (ts.strEquCI("min-height")) { minh = getInt(); return true; }
      if (ts.strEquCI("max-width")) { maxw = getInt(); return true; }
      if (ts.strEquCI("max-height")) { maxh = getInt(); return true; }
      if (ts.strEquCI("default")) { def = getBool(); return true; }
      if (ts.strEquCI("disabled")) { disabled = getBool(); return true; }
      if (ts.strEquCI("enabled")) { disabled = 1-getBool(); return true; }
      if (ts.strEquCI("smallFrame") || ts.strEquCI("small-frame")) { smallframe = getBool(); return true; }
      if (ts.strEquCI("clickMask") || ts.strEquCI("click-mask")) { clickMask = getClickMask(); return true; }
      if (ts.strEquCI("doubleMask") || ts.strEquCI("double-mask")) { doubleMask = getClickMask(); return true; }
      if (ts.strEquCI("alert")) { alert = getBool(); return true; }
      if (ts.strEquCI("utfuck")) { utfuck = getBool(); return true; }
      if (ts.strEquCI("enter-close")) { enterclose = getBool(); return true; }
      return false;
    }
  }

  Props props;

  bool isGoodWidgetName (const(char)[] s) {
    return
      s.strEquCI("span") || s.strEquCI("hspan") || s.strEquCI("vspan") ||
      s.strEquCI("hline") ||
      s.strEquCI("spacer") ||
      s.strEquCI("box") || s.strEquCI("hbox") || s.strEquCI("vbox") ||
      s.strEquCI("panel") || s.strEquCI("hpanel") || s.strEquCI("vpanel") ||
      s.strEquCI("label") ||
      s.strEquCI("button") ||
      s.strEquCI("checkbox") ||
      s.strEquCI("radio") ||
      s.strEquCI("editline") || s.strEquCI("edittext") ||
      s.strEquCI("textview") ||
      s.strEquCI("listbox");
  }

  int bindFuncTo (int item) {
    if (!props.bindfunc.empty) {
      //{ import iv.vfs.io; writeln("bf: ", bindfunc.quote); }
      foreach (immutable idx, var; Vars) {
        static if (is(typeof(var) == function) || is(typeof(var) == delegate)) {
          static if (is(typeof((dg){int n = dg(FuiContext.init, 666);}(&Vars[idx])))) {
            if ((&Vars[idx]).stringof[1..$].xstrip == props.bindfunc.getz) {
              ctx.setActionCB(item, &Vars[idx]);
              return item;
            }
          }
        }
      }
    }
    return item;
  }

  int createWidget (int parent) {
    auto widn = widname.getz;
    if (widn.strEquCI("span")) return bindFuncTo(ctx.span(parent, (props.hv <= 0)));
    if (widn.strEquCI("hspan")) return bindFuncTo(ctx.hspan(parent));
    if (widn.strEquCI("vspan")) return bindFuncTo(ctx.vspan(parent));
    if (widn.strEquCI("spacer")) return bindFuncTo(ctx.spacer(parent));
    if (widn.strEquCI("hline")) return bindFuncTo(ctx.hline(parent));
    if (widn.strEquCI("box")) return bindFuncTo(ctx.box(parent, (props.hv <= 0), props.id.getz));
    if (widn.strEquCI("hbox")) return bindFuncTo(ctx.hbox(parent, props.id.getz));
    if (widn.strEquCI("vbox")) return bindFuncTo(ctx.vbox(parent, props.id.getz));
    if (widn.strEquCI("panel")) return bindFuncTo(ctx.panel(parent, props.caption.getz, (props.hv <= 0), props.id.getz));
    if (widn.strEquCI("hpanel")) return bindFuncTo(ctx.hpanel(parent, props.caption.getz, props.id.getz));
    if (widn.strEquCI("vpanel")) return bindFuncTo(ctx.vpanel(parent, props.caption.getz, props.id.getz));
    if (widn.strEquCI("label")) return bindFuncTo(ctx.label(parent, props.id.getz, props.caption.getz, props.dest.getz));
    if (widn.strEquCI("button")) return bindFuncTo(ctx.button(parent, props.id.getz, props.caption.getz));
    if (widn.strEquCI("editline")) return bindFuncTo(ctx.editline(parent, props.id.getz, props.caption.getz, props.utfuck > 0));
    if (widn.strEquCI("edittext")) return bindFuncTo(ctx.edittext(parent, props.id.getz, props.caption.getz, props.utfuck > 0));
    if (widn.strEquCI("textview")) return bindFuncTo(ctx.textview(parent, props.id.getz, props.caption.getz));
    if (widn.strEquCI("listbox")) return bindFuncTo(ctx.listbox(parent, props.id.getz));
    if (widn.strEquCI("checkbox")) {
      if (!props.bindvar.empty) {
        foreach (int idx, var; Vars) {
          static if (is(typeof(var) == bool)) {
            if (Vars[idx].stringof == props.bindvar.getz) {
              return bindFuncTo(ctx.checkbox(parent, props.id.getz, props.caption.getz, &Vars[idx]));
            }
          }
        }
      }
      return bindFuncTo(ctx.checkbox(parent, props.id.getz, props.caption.getz, null));
    }
    if (widn.strEquCI("radio")) {
      if (!props.bindvar.empty) {
        foreach (int idx, var; Vars) {
          static if (is(typeof(var) == int)) {
            if (Vars[idx].stringof == props.bindvar.getz) {
              return bindFuncTo(ctx.radio(parent, props.id.getz, props.caption.getz, &Vars[idx]));
            }
          }
        }
      }
      return bindFuncTo(ctx.radio(parent, props.id.getz, props.caption.getz, null));
    }
    throw new Exception("unknown widget: '"~widn.idup~"'");
  }

  // at widget name
  void readProps(bool doWidgetCreation=true) (int parent) {
    bool readGroup = true;
    int item = 0;

    widname.reset;
    if (eof) return;
    static if (doWidgetCreation) {
      if (!isGoodWidgetName(token)) throw new Exception("widget name expected");
      widname.put(token);
      readGroup = hasValue;
    }

    void setProps () {
      // set properties
      auto lp = ctx.layprops(item);
      if (props.paddingLeft >= 0) lp.padding.left = props.paddingLeft;
      if (props.paddingTop >= 0) lp.padding.top = props.paddingTop;
      if (props.paddingRight >= 0) lp.padding.right = props.paddingRight;
      if (props.paddingBottom >= 0) lp.padding.bottom = props.paddingBottom;
      if (props.flex >= 0) lp.flex = props.flex;
      if (props.spacing >= 0) lp.spacing = props.spacing;
      if (props.clickMask >= 0) lp.clickMask = cast(ubyte)props.clickMask;
      if (props.doubleMask >= 0) lp.doubleMask = cast(ubyte)props.doubleMask;
      if (props.linebreak >= 0) lp.lineBreak = (props.linebreak != 0);
      if (props.canbefocused >= 0) lp.canBeFocused = (props.canbefocused != 0);
      if (props.hv >= 0) lp.vertical = (props.hv != 0);
      if (props.def >= 0) lp.userFlags = (lp.userFlags&~FuiCtlUserFlags.Default)|(props.def > 0 ? FuiCtlUserFlags.Default : 0);
      if (props.wpalign >= 0) lp.aligning = cast(FuiLayoutProps.Align)props.wpalign;
      if (props.minw >= 0) lp.minSize.w = props.minw;
      if (props.minh >= 0) lp.minSize.h = props.minh;
      if (props.maxw >= 0) lp.maxSize.w = props.maxw;
      if (props.maxh >= 0) lp.maxSize.h = props.maxh;
      if (props.disabled >= 0) lp.disabled = (props.disabled > 0);
      if (!props.hgroup.empty) {
        auto id = ctx.findById(props.hgroup.getz);
        if (id < 0) throw new Exception("no widget with id '"~props.hgroup.getz.idup~"'");
        lp.hgroup = id;
      }
      if (!props.vgroup.empty) {
        auto id = ctx.findById(props.vgroup.getz);
        if (id < 0) throw new Exception("no widget with id '"~props.vgroup.getz.idup~"'");
        lp.vgroup = id;
      }
      if (item == 0) {
        ctx.dialogCaption(props.caption.getz);
        if (props.smallframe >= 0) ctx.dialogFrame(props.smallframe > 0 ? FuiDialogFrameType.Small : FuiDialogFrameType.Normal);
        if (props.alert >= 0) ctx.dialogPalette(props.alert > 0 ? TuiPaletteError : TuiPaletteNormal);
        if (props.enterclose >= 0) ctx.dialogEnterClose(props.enterclose > 0);
      }
    }

    props.reset();
    if (readGroup) {
      if (doWidgetCreation) {
        nextToken();
        if (eof || tkstr || token != "{") throw new Exception("group expected");
      }
      auto stpos = text;
      // collect properties
      for (;;) {
        nextToken();
        if (eof) break;
        auto ts = token;
        if (ts == "}") break;
        if (!hasValue && !tkstr && ts == ",") continue;
        if (ts == "{") {
          skipGroup();
          if (eof) throw new Exception("unclosed group");
          if (token != "}") throw new Exception("unclosed group");
          continue;
        }
        if (props.parseProp()) continue;
        if (ts.strEquCI("items")) {
          if (widname.getz != "listbox") throw new Exception("'"~widname.getz.idup~"' can't have items");
          if (hasValue) {
            nextToken();
            if (eof || token != "{") throw new Exception("items expected");
            skipGroup();
          }
          continue;
        }
        if (!isGoodWidgetName(ts)) throw new Exception("invalid token: '"~ts.idup~"'");
      }
      static if (doWidgetCreation) item = createWidget(parent);
      setProps();
      // second pass: process children, add items
      text = stpos;
      for (;;) {
        nextToken();
        if (eof) break;
        if (token == "}") break;
        if (!hasValue && !tkstr && token == ",") continue;
        if (isGoodWidgetName(token)) {
          readProps(item);
        } else if (token.strEquCI("items")) {
          //if (widname.getz != "listbox") throw new Exception("'"~widname.getz.idup~"' can't have items");
          if (hasValue) {
            nextToken();
            if (eof || token != "{") throw new Exception("items expected");
            for (;;) {
              nextToken();
              if (eof) throw new Exception("unclosed item group");
              if (token == "}") break;
              if (!hasValue && !tkstr && token == ",") continue;
              if (hasValue) throw new Exception("item can't have any value");
              ctx.listboxItemAdd(item, token);
            }
            auto lp = ctx.layprops(item);
            if (lp.minSize.w <= 3) lp.minSize.w = ctx.listboxMaxItemWidth(item);
            if (lp.minSize.h < 1) {
              int fh = (ctx.dialogFrame == FuiDialogFrameType.Normal ? 4 : 2);
              auto mh = ctx.listboxItemCount(item);
              if (mh > ttyh-fh) mh = ttyh-fh;
              lp.minSize.h = mh;
            }
          }
        } else {
          if (token == "{") throw new Exception("orphaned group");
        }
      }
    } else {
      if (doWidgetCreation) item = createWidget(parent);
    }
  }

  //{ import iv.vfs.io; writeln("text: ", text); }
  readProps!false(0);
}
