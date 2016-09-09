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
module iv.egtui.editor.highlighters;
private:

import iv.rawtty2;
import iv.strex;

import iv.egtui.tty;
import iv.egtui.editor.editor;


// ////////////////////////////////////////////////////////////////////////// //
public enum TextColor = XtColorFB!(TtyRgb2Color!(0xd0, 0xd0, 0xd0), TtyRgb2Color!(0x3a, 0x3a, 0x3a)); // 252,237
public enum TextKillColor = XtColorFB!(TtyRgb2Color!(0xe0, 0xe0, 0xe0), TtyRgb2Color!(0x3a, 0x3a, 0x3a)); // 252,237
public enum BadColor = XtColorFB!(TtyRgb2Color!(0xff, 0xff, 0x54), TtyRgb2Color!(0xb2, 0x18, 0x18)); // 11,1
//public enum TrailSpaceColor = XtColorFB!(TtyRgb2Color!(0xff, 0xff, 0x00), TtyRgb2Color!(0x00, 0x00, 0x87)); // 226,18
public enum TrailSpaceColor = XtColorFB!(TtyRgb2Color!(0x6c, 0x6c, 0x6c), TtyRgb2Color!(0x26, 0x26, 0x26)); // 242,235
public enum BlockColor = XtColorFB!(TtyRgb2Color!(0xff, 0xff, 0xff), TtyRgb2Color!(0x00, 0x5f, 0xff)); // 15,27
public enum BookmarkColor = XtColorFB!(TtyRgb2Color!(0xff, 0xff, 0xff), TtyRgb2Color!(0x87, 0x00, 0xd7)); // 15,92
public enum BracketColor = XtColorFB!(TtyRgb2Color!(0xff, 0xff, 0x54), TtyRgb2Color!(0x00, 0x00, 0x00)); // 11,0
public enum IncSearchColor = XtColorFB!(TtyRgb2Color!(0xff, 0xff, 0x00), TtyRgb2Color!(0xd7, 0x00, 0x00)); // 226,160

public enum UtfuckedColor = XtColorFB!(TtyRgb2Color!(0x6c, 0x6c, 0x6c), TtyRgb2Color!(0x26, 0x26, 0x26)); // 242,235

public enum VLineColor = XtColorFB!(TtyRgb2Color!(0x60, 0x60, 0x60), TtyRgb2Color!(0x3a, 0x3a, 0x3a)); // 252,237


// ////////////////////////////////////////////////////////////////////////// //
public enum {
  HiNone = 0,
  HiText, // dunno what, just a text

  HiCommentOneLine,
  HiCommentMulti, // kwidx: level; 0: non-nesting

  HiNumber,

  HiChar, // starting, ending, text
  HiCharSpecial,

  // normal string
  HiString,
  HiStringSpecial,
  // backquoted string
  HiBQString,
  // rquoted string
  HiRQString,

  HiKeyword, // yellow
  HiKeywordHi, // while
  HiBuiltin, // red
  HiType, // olive
  HiSpecial, // green
  HiInternal, // red
  HiPunct, // some punctuation token
  HiSemi, // semicolon
  HiUDA, // bluish
  HiAliced,

  HiRegExp, // js inline regexp
}


// ////////////////////////////////////////////////////////////////////////// //
public uint hiColor() (in auto ref GapBuffer.HighState hs) nothrow @safe @nogc {
  switch (hs.kwtype) {
    case HiNone: return XtColorFB!(TtyRgb2Color!(0xb2, 0xb2, 0xb2), TtyRgb2Color!(0x00, 0x00, 0x00)); // 7,0
    case HiText: return TextColor;

    case HiCommentOneLine:
    case HiCommentMulti:
      return XtColorFB!(TtyRgb2Color!(0xb2, 0x68, 0x18), TtyRgb2Color!(0x3a, 0x3a, 0x3a)); // 3,237

    case HiNumber:
      return XtColorFB!(TtyRgb2Color!(0x18, 0xb2, 0x18), TtyRgb2Color!(0x3a, 0x3a, 0x3a)); // 2,237

    case HiChar:
      return XtColorFB!(TtyRgb2Color!(0x54, 0xff, 0xff), TtyRgb2Color!(0x3a, 0x3a, 0x3a)); // 14,237
    case HiCharSpecial:
      return XtColorFB!(TtyRgb2Color!(0x54, 0xff, 0x54), TtyRgb2Color!(0x3a, 0x3a, 0x3a)); // 10,237; green
      //return XtColorFB!(TtyRgb2Color!(0x18, 0xb2, 0x18), TtyRgb2Color!(0x3a, 0x3a, 0x3a)); // 2,237
      //return XtColorFB!(TtyRgb2Color!(0x54, 0xff, 0xff), TtyRgb2Color!(0x3a, 0x3a, 0x3a)); // 14,237

    // normal string
    case HiString:
    case HiBQString:
    case HiRQString:
      return XtColorFB!(TtyRgb2Color!(0x18, 0xb2, 0xb2), TtyRgb2Color!(0x3a, 0x3a, 0x3a)); // 6,237
    case HiStringSpecial:
      return XtColorFB!(TtyRgb2Color!(0x54, 0xff, 0xff), TtyRgb2Color!(0x3a, 0x3a, 0x3a)); // 14,237
      //return XtColorFB!(TtyRgb2Color!(0x18, 0xb2, 0x18), TtyRgb2Color!(0x3a, 0x3a, 0x3a)); // 2,237

    case HiKeyword: return XtColorFB!(TtyRgb2Color!(0xff, 0xff, 0x54), TtyRgb2Color!(0x3a, 0x3a, 0x3a)); // 11,237
    case HiKeywordHi: return XtColorFB!(TtyRgb2Color!(0xff, 0xff, 0xff), TtyRgb2Color!(0x3a, 0x3a, 0x3a)); // 202,237
    case HiBuiltin: return XtColorFB!(TtyRgb2Color!(0xff, 0x5f, 0x00), TtyRgb2Color!(0x3a, 0x3a, 0x3a)); // 202,237
    case HiType: return XtColorFB!(TtyRgb2Color!(0xff, 0xaf, 0x00), TtyRgb2Color!(0x3a, 0x3a, 0x3a)); // 214,237
    case HiSpecial: return XtColorFB!(TtyRgb2Color!(0x54, 0xff, 0x54), TtyRgb2Color!(0x3a, 0x3a, 0x3a)); // 10,237; green
    case HiInternal: return XtColorFB!(TtyRgb2Color!(0xff, 0x54, 0x54), TtyRgb2Color!(0x3a, 0x3a, 0x3a)); // 9,237; red
    case HiPunct: return XtColorFB!(TtyRgb2Color!(0x54, 0xff, 0xff), TtyRgb2Color!(0x3a, 0x3a, 0x3a)); // 14,237
    case HiSemi: return XtColorFB!(TtyRgb2Color!(0xff, 0x00, 0xff), TtyRgb2Color!(0x3a, 0x3a, 0x3a)); // 201,237
    case HiUDA: return XtColorFB!(TtyRgb2Color!(0x00, 0x87, 0xff), TtyRgb2Color!(0x3a, 0x3a, 0x3a)); // 33,237
    case HiAliced: return XtColorFB!(TtyRgb2Color!(0xff, 0x5f, 0x00), TtyRgb2Color!(0x3a, 0x3a, 0x3a)); // 202,237

    case HiRegExp: return XtColorFB!(TtyRgb2Color!(0xff, 0x5f, 0x00), TtyRgb2Color!(0x3a, 0x3a, 0x3a)); // 202,237

    default: assert(0, "wtf?!");
  }
}


public bool hiIsComment() (in auto ref GapBuffer.HighState hs) nothrow @safe @nogc {
  switch (hs.kwtype) {
    case HiCommentOneLine:
    case HiCommentMulti:
      return true;
    default:
      break;
  }
  return false;
}


// ////////////////////////////////////////////////////////////////////////// //
public class EditorHLExt : EditorHL {
private:
  alias HS = GapBuffer.HighState;

protected:
  EdHiTokens tks;
  int validLines; // how much lines was ever highlighted?

public:
  this (EdHiTokens atk) { tks = atk; super(); }

  // return `true` if next line was fucked
  final bool redoLine (int ls, int le) {
    if (gb.hi(ls).kwtype == 0) {
      auto est = gb.hi(le);
      rehighlightLine(ls, le);
      // need to fix next line?
      if (le+1 < gb.textsize && est != gb.hi(le)) {
        gb.hi(le+1).kwtype = 0;
        return true;
      }
    }
    return false;
  }

  // return true if highlighting for this line was changed
  override bool fixLine (int line) {
    if (validLines == 0) {
      // anyway
      rehighlightLine(0, gb.lineend(0));
      validLines = 1;
      if (line == 0) return true;
    }
    bool res = false;
    if (line >= validLines) {
      auto spos = gb.line2pos(validLines);
      while (line >= validLines) {
        if (true/*gb.hi(spos).kwtype == 0*/) {
          if (validLines == line) res = true;
          auto epos = gb.lineend(validLines);
          auto est = gb.hi(epos);
          rehighlightLine(spos, epos);
          // need to fix next line?
          if (epos+1 < gb.textsize && est != gb.hi(epos)) gb.hi(epos+1).kwtype = 0;
          spos = epos+1;
        } else {
          spos = gb.line2pos(validLines+1);
        }
        ++validLines;
      }
    } else {
      auto ls = gb.line2pos(line);
      auto stt = gb.hi(ls).kwtype;
      if (stt == 0) {
        auto le = gb.lineend(line);
        if (redoLine(ls, le)) validLines = line+1; // should check next lines
        res = true;
      }
    }
    return res;
  }

  // mark line as "need rehighlighting" (and possibly other text too)
  // wasInsDel: some lines was inserted/deleted down the text
  override void lineChanged (int line, bool wasInsDel) {
    if (line >= validLines) return; // nothing to do
    gb.hi(gb.line2pos(line)).kwtype = 0; // "rehighlight" flag
    if (wasInsDel) validLines = line; // rehighlight the following text
  }

private final:
  // returns either 0 or "skip count"
  int isGoodChar (int pos) nothrow @nogc {
    if (gb[pos] != '\'') return 0;
    if (gb[pos+1] == '\\') {
      auto ch = gb[pos+2];
      if (ch != 'x' && ch != 'X') return (gb[pos+3] == '\'' ? 4 : 0);
      if (!gb[pos+3].isxdigit) return 0;
      ch = gb[pos+4];
      if (!ch.isxdigit) return (ch == '\'' ? 5 : 0);
      return (gb[pos+5] == '\'' ? 6 : 0);
    } else if (gb[pos+2] == '\'') {
      return 3;
    } else {
      return 0;
    }
  }

  bool isDecStart (int pos) nothrow @nogc {
    auto ch = gb[pos];
    if (ch == '-' || ch == '+') ch = gb[++pos];
    return ch.isdigit;
  }

  // 0 or base
  int isBasedStart (int pos) nothrow @nogc {
    auto ch = gb[pos++];
    if (ch == '-' || ch == '+') ch = gb[pos++];
    if (ch != '0') return 0;
    ch = gb[pos++];
    int base = 0;
         if (ch == 'x' || ch == 'X') base = 16;
    else if (ch == 'o' || ch == 'O') base = 8;
    else if (ch == 'b' || ch == 'B') base = 2;
    else return 0;
    if (!tks.optNum0x && base == 16) return 0;
    if (!tks.optNum0o && base == 8) return 0;
    if (!tks.optNum0b && base == 2) return 0;
    return (gb[pos].digitInBase(base) >= 0 ? base : 0);
  }

  // this is *inclusive* range
  void rehighlightLine (int ls, int le) {
    auto tks = this.tks;

    if (ls >= gb.textsize) return;

    // spos: at char
    // return: 0: error; 1: normal; >1: escape (length)
    int skipStrChar(bool allowEol, bool allowEsc) () {
      import std.ascii : isHexDigit;
      if (spos >= gb.textsize) return 0;
      auto ch = gb[spos];
      if (ch == '\n') { static if (allowEol) return 1; else return 0; }
      static if (allowEsc) {
        if (ch == '\\') {
          ch = gb[spos+1];
          if (ch == 0) return 1;
          if (ch == '\n') { static if (allowEol) return 2; else return 1; }
          int hexd = 0;
               if (ch == 'x' || ch == 'X') hexd = 2;
          else if (ch == 'u' || ch == 'U') hexd = 4;
          if (hexd == 0) return 2; // not a hex escape
          foreach (immutable n; 0..hexd) {
            ch = gb[spos+2+n];
            if (!ch.isHexDigit) return n+2;
          }
          return hexd+2;
        }
      }
      return 1;
    }

    // take ending state for the previous line
    HS st = (ls > 0 ? gb.hi(ls-1) : HS(HiText));

    char ch;
    int ofs;
    int spos = ls;

    void skipNumMods () {
      auto ch = gb[spos+ofs];
      if (ch == 'L') {
        ++ofs;
        if (gb[spos+ofs].tolower == 'u') ++ofs;
      } else if (ch == 'u' || ch == 'U') {
        ++ofs;
        if (gb[spos+ofs] == 'L') ++ofs;
      }
    }

    mainloop: while (spos <= le) {
      // in string?
      if (st.kwtype == HiString || st.kwtype == HiStringSpecial) {
        while (spos <= le) {
          auto len = skipStrChar!(true, true)();
          if (len == 0) { st = HS(HiText); continue mainloop; }
          if (len == 1) {
            // normal
            gb.hi(spos++) = HS(HiString);
            if (gb[spos-1] == '"') { st = HS(HiText); continue mainloop; }
          } else {
            // special
            foreach (immutable _; 0..len) gb.hi(spos++) = HS(HiStringSpecial);
          }
        }
        st = HS(HiString);
        continue mainloop;
      }
      // in backquoted string?
      if (st.kwtype == HiBQString) {
        while (spos <= le) {
          auto len = skipStrChar!(true, false)();
          if (len == 0) { st = HS(HiText); continue mainloop; }
          assert(len == 1);
          gb.hi(spos++) = HS(HiBQString);
          if (gb[spos-1] == '`') { st = HS(HiText); continue mainloop; }
        }
        st = HS(HiBQString);
        continue mainloop;
      }
      // in rackquoted string?
      if (st.kwtype == HiRQString) {
        while (spos <= le) {
          auto len = skipStrChar!(true, false)();
          if (len == 0) { st = HS(HiText); continue mainloop; }
          assert(len == 1);
          gb.hi(spos++) = HS(HiRQString);
          if (gb[spos-1] == '"') { st = HS(HiText); continue mainloop; }
        }
        st = HS(HiRQString);
        continue mainloop;
      }
      // in multiline comment?
      if (st.kwtype == HiCommentMulti && st.kwidx == 0) {
        while (spos <= le) {
          gb.hi(spos++) = HS(HiCommentMulti);
          if (gb[spos-1] == '*' && gb[spos] == '/') {
            gb.hi(spos++) = HS(HiCommentMulti);
            st = HS(HiText);
            continue mainloop;
          }
        }
        st = HS(HiCommentMulti);
        continue mainloop;
      }
      // in nested multiline comment?
      if (st.kwtype == HiCommentMulti && st.kwidx > 0) {
        //FIXME: more than 255 levels aren't supported
        ubyte level = st.kwidx;
        assert(level);
        while (spos <= le) {
          ch = gb[spos];
          if (ch == '+' && gb[spos+1] == '/') {
            gb.hi(spos++) = HS(HiCommentMulti, level);
            gb.hi(spos++) = HS(HiCommentMulti, level);
            if (--level == 0) { st = HS(HiText); continue mainloop; }
          } else if (ch == '/' && gb[spos+1] == '+') {
            ++level;
            gb.hi(spos++) = HS(HiCommentMulti, level);
            gb.hi(spos++) = HS(HiCommentMulti, level);
          } else {
            gb.hi(spos++) = HS(HiCommentMulti, level);
          }
        }
        st = HS(HiCommentMulti, level);
        continue mainloop;
      }
      ch = gb[spos];
      // single-line comment?
      if (ch == '/' && tks.optCSingleComment && gb[spos+1] == '/') {
        gb.hi(spos++) = HS(HiCommentOneLine);
        gb.hi(spos++) = HS(HiCommentOneLine);
        st = HS(HiCommentOneLine);
        while (spos <= le) gb.hi(spos++) = st;
        continue mainloop;
      }
      // shell single-line comment?
      if (ch == '#' && tks.optShellSingleComment) {
        gb.hi(spos++) = HS(HiCommentOneLine);
        gb.hi(spos++) = HS(HiCommentOneLine);
        st = HS(HiCommentOneLine);
        while (spos <= le) gb.hi(spos++) = st;
        continue mainloop;
      }
      // multiline comment?
      if (ch == '/' && tks.optCMultiComment && gb[spos+1] == '*') {
        gb.hi(spos++) = HS(HiCommentMulti);
        gb.hi(spos++) = HS(HiCommentMulti);
        st = HS(HiCommentMulti);
        continue mainloop;
      }
      // nested multiline comment?
      if (ch == '/' && tks.optDNestedComment && gb[spos+1] == '+') {
        gb.hi(spos++) = HS(HiCommentMulti, 1);
        gb.hi(spos++) = HS(HiCommentMulti, 1);
        st = HS(HiCommentMulti, 1);
        continue mainloop;
      }
      // js inline regexp?
      if (ch == '/' && tks.optJSRegExp) {
        int ep = spos+1;
        while (ep <= le) {
          if (gb[ep] == '/') break;
          if (gb[ep] == '\\' && ep+1 <= le) ++ep;
          ++ep;
        }
        if (ep <= le) {
          // yep
          st = HS(HiRegExp);
          while (spos <= ep) gb.hi(spos++) = st;
          continue mainloop;
        }
      }
      // control char or non-ascii char?
      if (ch == '\n') {
        gb.hi(spos++) = st;
        continue mainloop;
      }
      if (ch <= ' ' || ch >= 127) {
        st = HS(HiText);
        gb.hi(spos++) = st;
        continue mainloop;
      }
      // char?
      if (ch == '\'' && !tks.optSQString) {
        auto xsp = spos;
        ++spos;
        auto len = skipStrChar!(false, true)();
        if (len > 0 && gb[spos+len] == '\'') {
          spos = xsp;
          gb.hi(spos++) = HS(HiChar);
          st = HS(len == 1 ? HiChar : HiCharSpecial);
          while (len--) gb.hi(spos++) = st;
          gb.hi(spos++) = HS(HiChar);
          st = HS(HiText);
        } else {
          spos = xsp;
          st = HS(HiText);
          gb.hi(spos++) = st;
          for (;;) {
            if (len == 0 || gb[spos] == '\'') { gb.hi(spos++) = st; continue mainloop; }
            while (len-- > 0) gb.hi(spos++) = st;
            len = skipStrChar!(false, true)();
          }
        }
        continue mainloop;
      }
      // string?
      if (ch == '"') {
        gb.hi(spos++) = HS(HiString);
        st = HS(HiString);
        continue mainloop;
      }
      // bqstring?
      if (ch == '`' && tks.optBQString) {
        gb.hi(spos++) = HS(HiBQString);
        st = HS(HiBQString);
        continue mainloop;
      }
      // rqstring?
      if (ch == 'r' && tks.optRQString && gb[spos+1] == '"') {
        gb.hi(spos++) = HS(HiRQString);
        gb.hi(spos++) = HS(HiRQString);
        st = HS(HiRQString);
        continue mainloop;
      }
      // identifier/keyword?
      if (ch.isalpha || ch == '_') {
        char[128] tk = void;
        uint tklen = 0;
        while (spos+tklen <= le) {
          ch = gb[spos+tklen];
          if (ch != '_' && !ch.isalnum) break;
          if (tklen < tk.length) tk.ptr[tklen] = cast(char)ch;
          ++tklen;
        }
        st = HS(HiText);
        if (tklen <= tk.length) {
          if (auto tknum = tks.findAlnumToken(tk[0..tklen])) {
            // token
            st = HS(tknum);
          } else {
            // sorry
            if (tks.optBodyIsSpecial && tk[0..tklen] == "body") {
              int xofs = spos+tklen;
              for (;;) {
                ch = gb[xofs];
                if (ch == '{') { st = HS(HiSpecial); break; }
                if (ch > ' ') break;
                ++xofs;
              }
            }
          }
        }
        foreach (immutable _; 0..tklen) gb.hi(spos++) = st;
        continue mainloop;
      }
      // based number?
      if (auto base = isBasedStart(spos)) {
        bool au = tks.optNumAllowUnder;
        ofs = (ch == '+' || ch == '-' ? 3 : 2);
        while (spos+ofs <= le) {
          ch = gb[spos+ofs];
          if (ch.digitInBase(base) >= 0 || (au && ch == '_')) { ++ofs; continue; }
          break;
        }
        skipNumMods();
        st = HS(HiText);
        if (!gb[spos+ofs].isalpha) st = HS(HiNumber); // number
        foreach (immutable cp; 0..ofs) gb.hi(spos++) = st;
        continue mainloop;
      }
      // decimal/floating number
      if (isDecStart(spos)) {
        bool au = tks.optNumAllowUnder;
        ofs = 1;
        while (spos+ofs <= le) {
          ch = gb[spos+ofs];
          if (ch.isdigit || (au && ch == '_')) { ++ofs; continue; }
          break;
        }
        if (gb[spos+ofs] == '.' && gb[spos+ofs+1] != '.') {
          ++ofs;
          if (isDecStart(spos+ofs)) {
            ++ofs;
            while (spos+ofs <= le && (gb[spos+ofs].isdigit || (au && gb[spos+ofs] == '_'))) ++ofs;
          }
          if (gb[spos+ofs].tolower == 'e' && isDecStart(spos+ofs+1)) {
            ofs += 2;
            while (spos+ofs <= le && (gb[spos+ofs].isdigit || (au && gb[spos+ofs] == '_'))) ++ofs;
          }
        }
        skipNumMods();
        st = HS(HiText);
        if (!gb[spos+ofs].isalpha) st = HS(HiNumber); // number
        foreach (immutable _; 0..ofs) gb.hi(spos++) = st;
        continue mainloop;
      }
      // punctuation token
      if (tks.punctCanStartWith(ch)) {
        ubyte tknum = ubyte.max;
        uint tkbest = 1;
        char[128] tk = void;
        uint tklen = 0;
        while (tklen < tk.length && spos+tklen <= le) {
          ch = gb[spos+tklen];
          if (ch > 255) break;
          tk.ptr[tklen++] = cast(char)ch;
          if (auto tknump = tks.findPunctToken(tk[0..tklen])) {
            tknum = tknump;
            tkbest = tklen;
          }
        }
        st = HS(tknum != ubyte.max ? tknum : HiPunct);
        foreach (immutable cp; 0..tkbest) gb.hi(spos++) = st;
        continue mainloop;
      }
      st = HS(HiText);
      gb.hi(spos++) = st;
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
abstract class EdHiTokens {
private:
  ubyte[string] tokenMap; // tokens, by name, alphanum
  ubyte[string] tokenPunct; // indicies, by first char, nonalphanum
  bool[256] tokensPunctAny; // by first char, nonalphanum
  int mMaxPunctLen = 0;

public:
  enum NotFound = 0;

public:
  this () {}

  // number parsing options
  abstract @property bool optNum0b () const pure nothrow @safe @nogc;
  abstract @property bool optNum0o () const pure nothrow @safe @nogc;
  abstract @property bool optNum0x () const pure nothrow @safe @nogc;
  abstract @property bool optNumAllowUnder () const pure nothrow @safe @nogc;

  // true: string can be single-quoted
  abstract @property bool optSQString () const pure nothrow @safe @nogc;

  // allow D-style `...` strings
  abstract @property bool optBQString () const pure nothrow @safe @nogc;
  // allow D-style r"..." strings
  abstract @property bool optRQString () const pure nothrow @safe @nogc;
  // allow `/+ ... +/` newsted comments
  abstract @property bool optDNestedComment () const pure nothrow @safe @nogc;
  // allow `# ` comments
  abstract @property bool optShellSingleComment () const pure nothrow @safe @nogc;
  // allow `//` comments
  abstract @property bool optCSingleComment () const pure nothrow @safe @nogc;
  // allow `/* ... */` comments
  abstract @property bool optCMultiComment () const pure nothrow @safe @nogc;
  // "body" token is special? (aliced)
  abstract @property bool optBodyIsSpecial () const pure nothrow @safe @nogc;

  abstract @property bool optJSRegExp () const pure nothrow @safe @nogc;

final:
  @property int maxPunctLen () const pure nothrow @safe @nogc { pragma(inline, true); return mMaxPunctLen; }

  ubyte findAlnumToken (const(char)[] tk) {
    if (tk.length > 0) {
      if (auto p = tk in tokenMap) return *p;
    }
    return NotFound;
  }

  bool punctCanStartWith (char ch) const pure nothrow @trusted @nogc { pragma(inline); return tokensPunctAny.ptr[cast(ubyte)ch]; }

  ubyte findPunctToken (const(char)[] tk) {
    if (tk.length > 0 && tk.length <= mMaxPunctLen) {
      if (auto p = tk in tokenPunct) return *p;
    }
    return NotFound;
  }

  void addToken(T : const(char)[]) (T name, ubyte tp) {
    static if (is(T == typeof(null))) {
      throw new Exception("empty tokens are not allowed");
    } else {
      import std.ascii : isAlphaNum;
      if (name.length == 0) throw new Exception("empty tokens are not allowed");
      if (name.length > int.max/4) throw new Exception("token too long");
      string tkn;
      static if (is(T == string)) tkn = name; else tkn = name.idup;
      if (name.ptr[0] == '_' || name.ptr[0].isAlphaNum) {
        tokenMap[tkn] = tp;
      } else {
        tokensPunctAny[name.ptr[0]] = true;
        tokenPunct[tkn] = tp;
        if (mMaxPunctLen < name.length) mMaxPunctLen = cast(int)name.length;
      }
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
class EdHiTokensD : EdHiTokens {
  // number parsing options
  override @property bool optNum0b () const pure nothrow @safe @nogc { return true; }
  override @property bool optNum0o () const pure nothrow @safe @nogc { return true; }
  override @property bool optNum0x () const pure nothrow @safe @nogc { return true; }
  override @property bool optNumAllowUnder () const pure nothrow @safe @nogc { return true; }

  // true: string can be single-quoted
  override @property bool optSQString () const pure nothrow @safe @nogc { return false; }

  // allow D-style `...` strings
  override @property bool optBQString () const pure nothrow @safe @nogc { return true; }
  // allow D-style r"..." strings
  override @property bool optRQString () const pure nothrow @safe @nogc { return true; }
  // allow `/+ ... +/` newsted comments
  override @property bool optDNestedComment () const pure nothrow @safe @nogc { return true; }
  // allow `# ` comments
  override @property bool optShellSingleComment () const pure nothrow @safe @nogc { return false; }
  // allow `//` comments
  override @property bool optCSingleComment () const pure nothrow @safe @nogc { return true; }
  // allow `/* ... */` comments
  override @property bool optCMultiComment () const pure nothrow @safe @nogc { return true; }
  // "body" token is special? (aliced)
  override @property bool optBodyIsSpecial () const pure nothrow @safe @nogc { return true; }

  override @property bool optJSRegExp () const pure nothrow @safe @nogc { return false; }

  this () {
    addToken("this", HiInternal);
    addToken("super", HiInternal);

    addToken("assert", HiBuiltin);
    addToken("new", HiBuiltin);
    addToken("delete", HiBuiltin);

    addToken("null", HiKeyword);
    addToken("true", HiKeyword);
    addToken("false", HiKeyword);
    addToken("cast", HiKeyword);
    addToken("throw", HiKeyword);
    addToken("module", HiKeyword);
    addToken("pragma", HiKeyword);
    addToken("typeof", HiKeyword);
    addToken("typeid", HiKeyword);
    addToken("sizeof", HiKeyword);
    addToken("template", HiKeyword);

    addToken("void", HiType);
    addToken("byte", HiType);
    addToken("ubyte", HiType);
    addToken("short", HiType);
    addToken("ushort", HiType);
    addToken("int", HiType);
    addToken("uint", HiType);
    addToken("long", HiType);
    addToken("ulong", HiType);
    addToken("cent", HiType);
    addToken("ucent", HiType);
    addToken("float", HiType);
    addToken("double", HiType);
    addToken("real", HiType);
    addToken("bool", HiType);
    addToken("char", HiType);
    addToken("wchar", HiType);
    addToken("dchar", HiType);
    addToken("ifloat", HiType);
    addToken("idouble", HiType);
    addToken("ireal", HiType);
    addToken("cfloat", HiType);
    addToken("cdouble", HiType);
    addToken("creal", HiType);
    addToken("string", HiType);
    addToken("usize", HiType);
    addToken("size_t", HiInternal);
    addToken("ptrdiff_t", HiInternal);

    addToken("delegate", HiKeyword);
    addToken("function", HiKeyword);
    addToken("is", HiKeyword);
    addToken("if", HiKeyword);
    addToken("else", HiKeyword);
    addToken("while", HiKeyword);
    addToken("for", HiKeyword);
    addToken("do", HiKeyword);
    addToken("switch", HiKeyword);
    addToken("case", HiKeyword);
    addToken("default", HiKeyword);
    addToken("break", HiKeyword);
    addToken("continue", HiKeyword);
    addToken("synchronized", HiBuiltin);
    addToken("return", HiKeyword);
    addToken("goto", HiKeyword);
    addToken("try", HiKeyword);
    addToken("catch", HiKeyword);
    addToken("finally", HiKeyword);
    addToken("with", HiKeyword);
    addToken("asm", HiKeyword);
    addToken("foreach", HiKeyword);
    addToken("foreach_reverse", HiKeyword);
    addToken("scope", HiKeyword);
    addToken("struct", HiKeyword);
    addToken("class", HiKeyword);
    addToken("interface", HiKeyword);
    addToken("union", HiKeyword);
    addToken("enum", HiKeyword);
    addToken("mixin", HiKeyword);
    addToken("static", HiKeyword);
    addToken("final", HiKeyword);
    addToken("const", HiKeyword);
    addToken("alias", HiKeyword);
    addToken("override", HiKeyword);
    addToken("abstract", HiKeyword);
    addToken("debug", HiKeyword);
    addToken("deprecated", HiKeyword);

    addToken("import", HiInternal);

    addToken("in", HiSpecial);
    addToken("out", HiSpecial);
    addToken("inout", HiSpecial);
    addToken("lazy", HiSpecial);

    addToken("auto", HiType);

    addToken("align", HiSpecial);
    addToken("extern", HiSpecial);
    addToken("private", HiSpecial);
    addToken("package", HiSpecial);
    addToken("protected", HiSpecial);
    addToken("public", HiSpecial);
    addToken("export", HiSpecial);
    addToken("invariant", HiSpecial);
    addToken("unittest", HiSpecial);
    addToken("version", HiSpecial);

    addToken("__argTypes", HiInternal);
    addToken("__parameters", HiInternal);

    addToken("ref", HiSpecial);

    addToken("macro", HiInternal);
    addToken("pure", HiInternal);
    addToken("__gshared", HiInternal);
    addToken("__traits", HiInternal);
    addToken("__vector", HiInternal);
    addToken("__overloadset", HiInternal);
    addToken("__FILE__", HiInternal);
    addToken("__FILE_FULL_PATH__", HiInternal);
    addToken("__LINE__", HiInternal);
    addToken("__MODULE__", HiInternal);
    addToken("__FUNCTION__", HiInternal);
    addToken("__PRETTY_FUNCTION__", HiInternal);
    addToken("shared", HiInternal);

    addToken("immutable", HiKeyword);

    addToken("nothrow", HiUDA);
    addToken("@nothrow", HiUDA);
    addToken("@nogc", HiUDA);
    addToken("@safe", HiUDA);
    addToken("@system", HiUDA);
    addToken("@trusted", HiUDA);
    addToken("@property", HiUDA);
    addToken("@disable", HiUDA);

    addToken("{", HiPunct);
    addToken("}", HiPunct);
    addToken("(", HiPunct);
    addToken(")", HiPunct);
    addToken("[", HiPunct);
    addToken("]", HiPunct);
    addToken(";", HiSemi);
    addToken(":", HiPunct);
    addToken(",", HiPunct);
    addToken(".", HiPunct);
    addToken("^", HiPunct);
    addToken("^=", HiPunct);
    addToken("=", HiPunct);
    addToken("=", HiPunct);
    addToken("=", HiPunct);
    addToken("<", HiPunct);
    addToken(">", HiPunct);
    addToken("<=", HiPunct);
    addToken(">=", HiPunct);
    addToken("==", HiPunct);
    addToken("!=", HiPunct);
    addToken("!<>=", HiPunct);
    addToken("!<>", HiPunct);
    addToken("<>", HiPunct);
    addToken("<>=", HiPunct);
    addToken("!>", HiPunct);
    addToken("!>=", HiPunct);
    addToken("!<", HiPunct);
    addToken("!<=", HiPunct);
    addToken("!", HiPunct);
    addToken("<<", HiPunct);
    addToken(">>", HiPunct);
    addToken(">>>", HiPunct);
    addToken("+", HiPunct);
    addToken("-", HiPunct);
    addToken("*", HiPunct);
    addToken("/", HiPunct);
    addToken("%", HiPunct);
    addToken("..", HiPunct);
    addToken("...", HiPunct);
    addToken("&", HiPunct);
    addToken("&&", HiPunct);
    addToken("|", HiPunct);
    addToken("||", HiPunct);
    addToken("[]", HiPunct);
    addToken("&", HiPunct);
    addToken("*", HiPunct);
    addToken("~", HiPunct);
    addToken("$", HiPunct);
    addToken("++", HiPunct);
    addToken("--", HiPunct);
    addToken("++", HiPunct);
    addToken("--", HiPunct);
    addToken("?", HiPunct);
    addToken("-", HiPunct);
    addToken("+", HiPunct);
    addToken("+=", HiPunct);
    addToken("-=", HiPunct);
    addToken("*=", HiPunct);
    addToken("/=", HiPunct);
    addToken("%=", HiPunct);
    addToken("<<=", HiPunct);
    addToken(">>=", HiPunct);
    addToken(">>>=", HiPunct);
    addToken("&=", HiPunct);
    addToken("|=", HiPunct);
    addToken("~=", HiPunct);
    addToken("~", HiPunct);
    //addToken("is", HiPunct);
    //addToken("!is", HiPunct);
    //addToken("@", HiPunct);
    addToken("^^", HiPunct);
    addToken("^^=", HiPunct);
    addToken("=>", HiPunct);

    addToken("aliced", HiAliced);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
class EdHiTokensJS : EdHiTokens {
  // number parsing options
  override @property bool optNum0b () const pure nothrow @safe @nogc { return false; }
  override @property bool optNum0o () const pure nothrow @safe @nogc { return false; }
  override @property bool optNum0x () const pure nothrow @safe @nogc { return true; }
  override @property bool optNumAllowUnder () const pure nothrow @safe @nogc { return false; }

  // true: string can be single-quoted
  override @property bool optSQString () const pure nothrow @safe @nogc { return true; }

  // allow D-style `...` strings
  override @property bool optBQString () const pure nothrow @safe @nogc { return false; }
  // allow D-style r"..." strings
  override @property bool optRQString () const pure nothrow @safe @nogc { return false; }
  // allow `/+ ... +/` newsted comments
  override @property bool optDNestedComment () const pure nothrow @safe @nogc { return false; }
  // allow `# ` comments
  override @property bool optShellSingleComment () const pure nothrow @safe @nogc { return false; }
  // allow `//` comments
  override @property bool optCSingleComment () const pure nothrow @safe @nogc { return true; }
  // allow `/* ... */` comments
  override @property bool optCMultiComment () const pure nothrow @safe @nogc { return true; }
  // "body" token is special? (aliced)
  override @property bool optBodyIsSpecial () const pure nothrow @safe @nogc { return false; }

  override @property bool optJSRegExp () const pure nothrow @safe @nogc { return true; }

  this () {
    addToken("arguments", HiKeyword);
    addToken("break", HiKeyword);
    addToken("callee", HiKeyword);
    addToken("caller", HiKeyword);
    addToken("case", HiKeyword);
    addToken("catch", HiKeyword);
    addToken("constructor", HiKeyword);
    addToken("const", HiKeywordHi);
    addToken("continue", HiKeyword);
    addToken("default", HiKeyword);
    addToken("delete", HiKeyword);
    addToken("do", HiKeyword);
    addToken("else", HiKeyword);
    addToken("finally", HiKeyword);
    addToken("for", HiKeyword);
    addToken("function", HiKeyword);
    addToken("get", HiKeywordHi);
    addToken("if", HiKeyword);
    addToken("instanceof", HiKeyword);
    addToken("in", HiSpecial);
    addToken("let", HiKeywordHi);
    addToken("new", HiSpecial);
    addToken("prototype", HiSpecial);
    addToken("return", HiKeyword);
    addToken("switch", HiKeyword);
    addToken("this", HiSpecial);
    addToken("throw", HiKeyword);
    addToken("try", HiKeyword);
    addToken("typeof", HiKeyword);
    addToken("var", HiKeywordHi);
    addToken("while", HiKeyword);
    addToken("with", HiKeywordHi);

    addToken("Array", HiKeywordHi);
    addToken("Boolean", HiKeywordHi);
    addToken("Date", HiKeywordHi);
    addToken("Function", HiKeywordHi);
    addToken("Math", HiKeywordHi);
    addToken("Number", HiKeywordHi);
    addToken("String", HiKeywordHi);
    addToken("Object", HiKeywordHi);
    addToken("RegExp", HiKeywordHi);

    // Most common functions
    addToken("escape", HiBuiltin);
    addToken("eval", HiBuiltin);
    addToken("indexOf", HiKeywordHi);
    addToken("isNaN", HiBuiltin);
    addToken("toString", HiBuiltin);
    addToken("unescape", HiBuiltin);
    addToken("valueOf", HiBuiltin);

    // Constants
    addToken("false", HiBuiltin);
    addToken("null", HiBuiltin);
    addToken("true", HiBuiltin);
    addToken("undefined", HiBuiltin);

    // punct
    addToken(".", HiPunct);
    addToken("*", HiPunct);
    addToken("+", HiPunct);
    addToken("-", HiPunct);
    addToken("/", HiPunct);
    addToken("%", HiPunct);
    addToken("=", HiPunct);
    addToken("!", HiPunct);
    addToken("&", HiPunct);
    addToken("|", HiPunct);
    addToken("^", HiPunct);
    addToken("~", HiPunct);
    addToken(">", HiPunct);
    addToken("<", HiPunct);

    addToken("{", HiPunct);
    addToken("}", HiPunct);
    addToken("(", HiPunct);
    addToken(")", HiPunct);
    addToken("[", HiPunct);
    addToken("]", HiPunct);
    addToken(",", HiPunct);
    addToken("?", HiPunct);
    addToken(":", HiPunct);
    addToken(";", HiSemi);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
class EdHiTokensC : EdHiTokens {
  // number parsing options
  override @property bool optNum0b () const pure nothrow @safe @nogc { return true; }
  override @property bool optNum0o () const pure nothrow @safe @nogc { return false; }
  override @property bool optNum0x () const pure nothrow @safe @nogc { return true; }
  override @property bool optNumAllowUnder () const pure nothrow @safe @nogc { return false; }

  // true: string can be single-quoted
  override @property bool optSQString () const pure nothrow @safe @nogc { return false; }

  // allow D-style `...` strings
  override @property bool optBQString () const pure nothrow @safe @nogc { return false; }
  // allow D-style r"..." strings
  override @property bool optRQString () const pure nothrow @safe @nogc { return false; }
  // allow `/+ ... +/` newsted comments
  override @property bool optDNestedComment () const pure nothrow @safe @nogc { return false; }
  // allow `# ` comments
  override @property bool optShellSingleComment () const pure nothrow @safe @nogc { return false; }
  // allow `//` comments
  override @property bool optCSingleComment () const pure nothrow @safe @nogc { return true; }
  // allow `/* ... */` comments
  override @property bool optCMultiComment () const pure nothrow @safe @nogc { return true; }
  // "body" token is special? (aliced)
  override @property bool optBodyIsSpecial () const pure nothrow @safe @nogc { return false; }

  override @property bool optJSRegExp () const pure nothrow @safe @nogc { return false; }

  this () {
    addToken("auto", HiKeyword);
    addToken("break", HiKeyword);
    addToken("case", HiKeyword);
    addToken("char", HiKeyword);
    addToken("const", HiKeyword);
    addToken("continue", HiKeyword);
    addToken("do", HiKeyword);
    addToken("double", HiKeyword);
    addToken("else", HiKeyword);
    addToken("enum", HiKeyword);
    addToken("extern", HiKeyword);
    addToken("float", HiKeyword);
    addToken("for", HiKeyword);
    addToken("goto", HiKeyword);
    addToken("if", HiKeyword);
    addToken("int", HiKeyword);
    addToken("long", HiKeyword);
    addToken("register", HiKeyword);
    addToken("return", HiKeyword);
    addToken("short", HiKeyword);
    addToken("signed", HiKeyword);
    addToken("sizeof", HiKeyword);
    addToken("static", HiKeyword);
    addToken("struct", HiKeyword);
    addToken("switch", HiKeyword);
    addToken("typedef", HiKeyword);
    addToken("union", HiKeyword);
    addToken("unsigned", HiKeyword);
    addToken("void", HiKeyword);
    addToken("volatile", HiKeyword);
    addToken("while", HiKeyword);
    addToken("asm", HiKeyword);
    addToken("inline", HiKeyword);
    addToken("wchar_t", HiKeyword);
    addToken("...", HiKeyword);
    addToken("class", HiKeyword);
    addToken("protected", HiKeyword);
    addToken("private", HiKeyword);
    addToken("public", HiKeyword);

    addToken("!", HiPunct);
    addToken("%", HiPunct);
    addToken("&&", HiPunct);
    addToken("&", HiPunct);
    addToken("(", HiPunct);
    addToken(")", HiPunct);
    addToken("*", HiPunct);
    addToken("+", HiPunct);
    addToken(",", HiPunct);
    addToken("-", HiPunct);
    addToken("/", HiPunct);
    addToken(":", HiPunct);
    addToken(";", HiSemi);
    addToken("<", HiPunct);
    addToken("=", HiPunct);
    addToken(">", HiPunct);
    addToken("?", HiPunct);
    addToken("[", HiPunct);
    addToken("]", HiPunct);
    addToken("^", HiPunct);
    addToken("{", HiPunct);
    addToken("||", HiPunct);
    addToken("|", HiPunct);
    addToken("}", HiPunct);
    addToken("~", HiPunct);
    addToken(".", HiPunct);
    addToken("->", HiInternal);

    addToken("void", HiType);
    addToken("short", HiType);
    addToken("int", HiType);
    addToken("long", HiType);
    addToken("float", HiType);
    addToken("double", HiType);
    addToken("char", HiType);
    addToken("wchar_t", HiType);
    addToken("size_t", HiType);
    addToken("ptrdiff_t", HiType);

    addToken("#include", HiInternal);
    addToken("#if", HiInternal);
    addToken("#ifdef", HiInternal);
    addToken("#else", HiInternal);
    addToken("#elif", HiInternal);
    addToken("#endif", HiInternal);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
// new higlighter instance for the file with the given extension
public __gshared EditorHL getHiglighterFor (const(char)[] ext) {
  if (ext.strEquCI(".d")) {
    __gshared EdHiTokensD toksd;
    if (toksd is null) toksd = new EdHiTokensD();
    return new EditorHLExt(toksd);
  }
  if (ext.strEquCI(".js") || ext.strEquCI(".jsm")) {
    __gshared EdHiTokensJS toksjs;
    if (toksjs is null) toksjs = new EdHiTokensJS();
    return new EditorHLExt(toksjs);
  }
  if (ext.strEquCI(".c") || ext.strEquCI(".cpp") || ext.strEquCI(".h") || ext.strEquCI(".hpp")) {
    __gshared EdHiTokensC toksc;
    if (toksc is null) toksc = new EdHiTokensC();
    return new EditorHLExt(toksc);
  }
  return null;
}
