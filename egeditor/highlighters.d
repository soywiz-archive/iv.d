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
module iv.egeditor.highlighters;

import iv.strex;

import iv.egeditor.editor;


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
  HiSQString,
  HiSQStringSpecial,
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
  HiPreprocessor,

  HiRegExp, // js inline regexp

  HiToDoOpen, // [.]
  HiToDoUrgent, // [!]
  HiToDoSemi, // [+]
  HiToDoDone, // [*]
  HiToDoDont, // [-]
  HiToDoUnsure, // [?]
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
      if (ls < gb.textsize) rehighlightLine(ls, le);
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
      if (gb.textsize > 0) rehighlightLine(0, gb.lineend(0));
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
          if (spos < gb.textsize) rehighlightLine(spos, epos);
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

  // this is *inclusive* range
  protected void rehighlightLine (int ls, int le) {
    auto tks = this.tks;
    auto opt = this.tks.options;

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
    bool seenNonBlank = false; // comments are blanks
    bool inPreprocessor = false;

    if (st.kwtype == HiPreprocessor) inPreprocessor = true;

    void skipNumMods () {
      auto ch = gb[spos+ofs];
      if (ch == 'L') {
        ++ofs;
        if (gb[spos+ofs].tolower == 'u') ++ofs;
      } else if (ch == 'u' || ch == 'U') {
        ++ofs;
        if (gb[spos+ofs] == 'L') ++ofs;
      } else if (ch == 'f') {
        ++ofs;
      }
    }

    mainloop: while (spos <= le) {
      // in string?
      if (st.kwtype == HiString || st.kwtype == HiStringSpecial) {
        seenNonBlank = true;
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
      // in single-quoted string?
      if (st.kwtype == HiSQString || st.kwtype == HiSQStringSpecial) {
        seenNonBlank = true;
        while (spos <= le) {
          auto len = skipStrChar!(true, true)();
          if (len == 0) { st = HS(HiText); continue mainloop; }
          if (len == 1) {
            // normal
            gb.hi(spos++) = HS(HiSQString);
            if (gb[spos-1] == '\'') { st = HS(HiText); continue mainloop; }
          } else {
            // special
            foreach (immutable _; 0..len) gb.hi(spos++) = HS(HiSQStringSpecial);
          }
        }
        st = HS(HiSQString);
        continue mainloop;
      }
      // in backquoted string?
      if (st.kwtype == HiBQString) {
        seenNonBlank = true;
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
        seenNonBlank = true;
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
      if (ch == '/' && (opt&EdHiTokens.Opt.CSingleComment) && gb[spos+1] == '/') {
        gb.hi(spos++) = HS(HiCommentOneLine);
        gb.hi(spos++) = HS(HiCommentOneLine);
        st = HS(HiCommentOneLine);
        while (spos <= le) gb.hi(spos++) = st;
        continue mainloop;
      }
      // shell single-line comment?
      if (ch == '#' && (opt&EdHiTokens.Opt.ShellSingleComment)) {
        gb.hi(spos++) = HS(HiCommentOneLine);
        gb.hi(spos++) = HS(HiCommentOneLine);
        st = HS(HiCommentOneLine);
        while (spos <= le) gb.hi(spos++) = st;
        continue mainloop;
      }
      // multiline comment?
      if (ch == '/' && (opt&EdHiTokens.Opt.CMultiComment) && gb[spos+1] == '*') {
        gb.hi(spos++) = HS(HiCommentMulti);
        gb.hi(spos++) = HS(HiCommentMulti);
        st = HS(HiCommentMulti);
        continue mainloop;
      }
      // nested multiline comment?
      if (ch == '/' && (opt&EdHiTokens.Opt.DNestedComment) && gb[spos+1] == '+') {
        gb.hi(spos++) = HS(HiCommentMulti, 1);
        gb.hi(spos++) = HS(HiCommentMulti, 1);
        st = HS(HiCommentMulti, 1);
        continue mainloop;
      }
      // C preprocessor?
      if (!inPreprocessor && ch == '#' && !seenNonBlank && (opt&EdHiTokens.Opt.CPreprocessor)) inPreprocessor = true;
      if (inPreprocessor) {
        // in preprocessor; eol?
        if (ch == '\n') {
          // check for continuation
          if (spos-1 >= ls && gb[spos-1] == '\\') {
            // yep
            st = HS(HiPreprocessor);
            gb.hi(spos++) = st;
          } else {
            // no
            st = HS(HiText);
            gb.hi(spos++) = st;
          }
          continue mainloop;
        }
        // not a EOL, go on
        st = HS(HiPreprocessor);
        gb.hi(spos++) = st;
        continue mainloop;
      }
      // non-blank?
      if (ch > ' ') seenNonBlank = true;
      // js inline regexp?
      if (ch == '/' && (opt&EdHiTokens.Opt.JSRegExp)) {
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
      // EOL?
      if (ch == '\n') {
        gb.hi(spos++) = st;
        continue mainloop;
      }
      // control char or non-ascii char?
      if (ch <= ' ' || ch >= 127) {
        st = HS(HiText);
        gb.hi(spos++) = st;
        continue mainloop;
      }
      // char?
      if (ch == '\'' && !(opt&EdHiTokens.Opt.SQString)) {
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
      // string?
      if (ch == '\'' && (opt&EdHiTokens.Opt.SQString)) {
        gb.hi(spos++) = HS(HiSQString);
        st = HS(HiSQString);
        continue mainloop;
      }
      // bqstring?
      if (ch == '`' && (opt&EdHiTokens.Opt.BQString)) {
        gb.hi(spos++) = HS(HiBQString);
        st = HS(HiBQString);
        continue mainloop;
      }
      // rqstring?
      if (ch == 'r' && (opt&EdHiTokens.Opt.RQString) && gb[spos+1] == '"') {
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
            if (tk[0..tklen] == "body" && (opt&EdHiTokens.Opt.BodyIsSpecial)) {
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
        bool au = (opt&EdHiTokens.Opt.NumAllowUnder) != 0;
        ofs = (ch == '+' || ch == '-' ? 3 : 2);
        while (spos+ofs <= le) {
          ch = gb[spos+ofs];
          if (ch.digitInBase(base) >= 0 || (au && ch == '_')) { ++ofs; continue; }
          break;
        }
        skipNumMods();
        st = HS(HiText);
        if (gb[spos+ofs].isalnum) { gb.hi(spos++) = st; continue mainloop; }
        // good number
        st = HS(HiNumber);
        foreach (immutable _; 0..ofs) gb.hi(spos++) = st;
        st = HS(HiText);
        continue mainloop;
      }
      // decimal/floating number
      if (isDecStart(spos)) {
        bool au = (opt&EdHiTokens.Opt.NumAllowUnder) != 0;
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
        if (gb[spos+ofs].isalnum) { gb.hi(spos++) = st; continue mainloop; }
        // good number
        st = HS(HiNumber);
        foreach (immutable _; 0..ofs) gb.hi(spos++) = st;
        st = HS(HiText);
        continue mainloop;
      }
      // punctuation token
      if (tks.punctCanStartWith(ch)) {
        bool isdollar = (ch == '$');
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
        if (tknum == ubyte.max && isdollar && (opt&EdHiTokens.Opt.ShellSigil) && spos+1 < le) goto sigil;
        st = HS(tknum != ubyte.max ? tknum : HiPunct);
        foreach (immutable cp; 0..tkbest) gb.hi(spos++) = st;
        continue mainloop;
      }
      // shell sigils
      if (ch == '$' && (opt&EdHiTokens.Opt.ShellSigil) && spos+1 < le) {
       sigil:
        st = HS(HiSpecial);
        gb.hi(spos++) = st;
        if (gb[spos] == '{') {
          // complex sigil
          while (spos < le) {
            ch = gb[spos];
            if (ch != '}') {
              gb.hi(spos++) = st;
            } else {
              break;
            }
          }
        } else {
          // simple sigil
          while (spos < le) {
            ch = gb[spos];
            if (ch.isalnum || ch == '.' || ch == '_') {
              gb.hi(spos++) = st;
            } else {
              break;
            }
          }
        }
        st = HS(HiText);
      }
      // normal text
      st = HS(HiText);
      gb.hi(spos++) = st;
    }
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
    if (ch == '-' || ch == '+') {
      if (!(tks.options&EdHiTokens.Opt.NumAllowSign)) return false;
      ch = gb[++pos];
    }
    if (ch.isdigit) return true;
    // floating can start with '.<digit>'
    return (ch == '.' && gb[pos+1].isdigit);
  }

  // 0 or base
  int isBasedStart (int pos) nothrow @nogc {
    auto ch = gb[pos++];
    if (ch == '-' || ch == '+') {
      if (!(tks.options&EdHiTokens.Opt.NumAllowSign)) return 0;
      ch = gb[pos++];
    }
    if (ch != '0') return 0;
    ch = gb[pos++];
    int base = 0;
         if (ch == 'x' || ch == 'X') base = 16;
    else if (ch == 'o' || ch == 'O') base = 8;
    else if (ch == 'b' || ch == 'B') base = 2;
    else return 0;
    if (!(tks.options&EdHiTokens.Opt.Num0x) && base == 16) return 0;
    if (!(tks.options&EdHiTokens.Opt.Num0o) && base == 8) return 0;
    if (!(tks.options&EdHiTokens.Opt.Num0b) && base == 2) return 0;
    return (gb[pos].digitInBase(base) >= 0 ? base : 0);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
public class EditorHLTODO : EditorHLExt {
  this () { super(null); }

  protected override void rehighlightLine (int ls, int le) {
    while (ls <= le && gb[ls] <= ' ') gb.hi(ls++) = HS(HiText);
    if (le-ls+1 >= 3 && gb[ls] == '[' && gb[ls+2] == ']') {
      auto st = HS(HiNone);
      switch (gb[ls+1]) {
        case '.': st = HS(HiToDoOpen); break;
        case '!': st = HS(HiToDoUrgent); break;
        case '+': st = HS(HiToDoSemi); break;
        case '*': st = HS(HiToDoDone); break;
        case '-': st = HS(HiToDoDont); break;
        case '?': st = HS(HiToDoUnsure); break;
        default:
      }
      if (st.kwtype != HiNone) {
        gb.hi(ls++) = st;
        gb.hi(ls++) = st;
        gb.hi(ls++) = st;
      }
    }
    while (ls <= le) gb.hi(ls++) = HS(HiText);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
public class EditorHLGitCommit : EditorHLExt {
  this () { super(null); }

  protected override void rehighlightLine (int ls, int le) {
    while (ls <= le && gb[ls] != '#') gb.hi(ls++) = HS(HiText);
    while (ls <= le) gb.hi(ls++) = HS(HiCommentOneLine);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
public abstract class EdHiTokens {
private:
  ubyte[string] tokenMap; // tokens, by name, alphanum
  ubyte[string] tokenPunct; // indicies, by first char, nonalphanum
  bool[256] tokensPunctAny; // by first char, nonalphanum
  int mMaxPunctLen = 0;

public:
  enum NotFound = 0;

  enum Opt : uint {
    // number parsing options
    Num0b         = 1U<<0,
    Num0o         = 1U<<1,
    Num0x         = 1U<<2,
    NumAllowUnder = 1U<<3,
    NumAllowSign  = 1U<<4,
    SQString      = 1U<<5, // can string be single-quoted?
    BQString      = 1U<<6, // allow D-style `...` strings
    RQString      = 1U<<7, // allow D-style r"..." strings
    // comment options
    DNestedComment     = 1U<<8, // allow `/+ ... +/` newsted comments
    ShellSingleComment = 1U<<9, // allow `# ` comments
    CSingleComment     = 1U<<10, // allow `//` comments
    CMultiComment      = 1U<<11, // allow `/* ... */` comments
    // other options
    BodyIsSpecial = 1U<<12, // is "body" token special? (aliced)
    CPreprocessor = 1U<<13, // does this language use C preprocessor?
    JSRegExp      = 1U<<14, // parse JS inline regexps?
    ShellSigil    = 1U<<15, // parse shell sigils?
  }
  static assert(Opt.max <= uint.max);

  uint options;

public:
  this () {}

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
public class EdHiTokensD : EdHiTokens {
  this () {
    options =
      Opt.Num0b|
      Opt.Num0o|
      Opt.Num0x|
      Opt.NumAllowUnder|
      //Opt.NumAllowSign|
      //Opt.SQString|
      Opt.BQString|
      Opt.RQString|
      Opt.DNestedComment|
      //Opt.ShellSingleComment|
      Opt.CSingleComment|
      Opt.CMultiComment|
      Opt.BodyIsSpecial|
      //Opt.CPreprocessor|
      //Opt.JSRegExp|
      //Opt.ShellSigil|
      0;

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
    addToken("cstring", HiType);

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
public class EdHiTokensJS : EdHiTokens {
  this () {
    options =
      //Opt.Num0b|
      //Opt.Num0o|
      Opt.Num0x|
      //Opt.NumAllowUnder|
      //Opt.NumAllowSign|
      Opt.SQString|
      //Opt.BQString|
      //Opt.RQString|
      //Opt.DNestedComment|
      //Opt.ShellSingleComment|
      Opt.CSingleComment|
      Opt.CMultiComment|
      //Opt.BodyIsSpecial|
      //Opt.CPreprocessor|
      Opt.JSRegExp|
      //Opt.ShellSigil|
      0;

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
public class EdHiTokensC : EdHiTokens {
  this () {
    options =
      Opt.Num0b|
      Opt.Num0o|
      Opt.Num0x|
      //Opt.NumAllowUnder|
      //Opt.NumAllowSign|
      //Opt.SQString|
      //Opt.BQString|
      //Opt.RQString|
      //Opt.DNestedComment|
      //Opt.ShellSingleComment|
      Opt.CSingleComment|
      Opt.CMultiComment|
      //Opt.BodyIsSpecial|
      Opt.CPreprocessor|
      //Opt.JSRegExp|
      //Opt.ShellSigil|
      0;

    addToken("auto", HiKeyword);
    addToken("break", HiKeyword);
    addToken("case", HiKeyword);
    addToken("const", HiKeyword);
    addToken("continue", HiKeyword);
    addToken("do", HiKeyword);
    addToken("else", HiKeyword);
    addToken("enum", HiKeyword);
    addToken("extern", HiKeyword);
    addToken("for", HiKeyword);
    addToken("goto", HiKeyword);
    addToken("if", HiKeyword);
    addToken("return", HiKeyword);
    addToken("short", HiKeyword);
    addToken("sizeof", HiKeyword);
    addToken("static", HiKeyword);
    addToken("struct", HiKeyword);
    addToken("switch", HiKeyword);
    addToken("typedef", HiKeyword);
    addToken("union", HiKeyword);
    addToken("volatile", HiKeyword);
    addToken("while", HiKeyword);
    addToken("asm", HiKeyword);
    addToken("inline", HiKeyword);
    addToken("...", HiKeyword);
    addToken("class", HiKeyword);
    addToken("protected", HiKeyword);
    addToken("private", HiKeyword);
    addToken("public", HiKeyword);

    addToken("register", HiInternal);

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
    addToken("signed", HiType);
    addToken("unsigned", HiType);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
public class EdHiTokensShell : EdHiTokens {
  this () {
    options =
      //Opt.Num0b|
      //Opt.Num0o|
      //Opt.Num0x|
      //Opt.NumAllowUnder|
      //Opt.NumAllowSign|
      Opt.SQString|
      Opt.BQString|
      //Opt.RQString|
      //Opt.DNestedComment|
      Opt.ShellSingleComment|
      //Opt.CSingleComment|
      //Opt.CMultiComment|
      //Opt.BodyIsSpecial|
      //Opt.CPreprocessor|
      //Opt.JSRegExp|
      Opt.ShellSigil|
      0;

    addToken("{", HiPunct);
    addToken("}", HiPunct);

    addToken("$*", HiInternal);
    addToken("$@", HiInternal);
    addToken("$#", HiInternal);
    addToken("$?", HiInternal);
    addToken("$-", HiInternal);
    addToken("$$", HiInternal);
    addToken("$!", HiInternal);
    addToken("$_", HiInternal);

    addToken("2>&1", HiInternal);
    addToken("2>&2", HiInternal);
    addToken("2>", HiInternal);
    addToken("1>", HiInternal);

    addToken(";", HiSemi);

    addToken("break", HiKeyword);
    addToken("case", HiKeyword);
    addToken("clear", HiKeyword);
    addToken("continue", HiKeyword);
    addToken("declare", HiKeyword);
    addToken("done", HiKeyword);
    addToken("do", HiKeyword);
    addToken("elif", HiKeyword);
    addToken("else", HiKeyword);
    addToken("esac", HiKeyword);
    addToken("exit", HiKeyword);
    addToken("export", HiKeyword);
    addToken("fi", HiKeyword);
    addToken("for", HiKeyword);
    addToken("getopts", HiKeyword);
    addToken("if", HiKeyword);
    addToken("in", HiKeyword);
    addToken("read", HiKeyword);
    addToken("return", HiKeyword);
    addToken("select", HiKeyword);
    addToken("shift", HiKeyword);
    addToken("source", HiKeyword);
    addToken("then", HiKeyword);
    addToken("trap", HiKeyword);
    addToken("until", HiKeyword);
    addToken("unset", HiKeyword);
    addToken("wait", HiKeyword);
    addToken("while", HiKeyword);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
public class EdHiTokensFrag : EdHiTokens {
  this () {
    options =
      Opt.Num0b|
      Opt.Num0o|
      Opt.Num0x|
      //Opt.NumAllowUnder|
      //Opt.NumAllowSign|
      //Opt.SQString|
      //Opt.BQString|
      //Opt.RQString|
      //Opt.DNestedComment|
      //Opt.ShellSingleComment|
      Opt.CSingleComment|
      Opt.CMultiComment|
      //Opt.BodyIsSpecial|
      Opt.CPreprocessor|
      //Opt.JSRegExp|
      //Opt.ShellSigil|
      0;

    addToken("break", HiKeyword);
    addToken("case", HiKeyword);
    addToken("const", HiKeyword);
    addToken("continue", HiKeyword);
    addToken("do", HiKeyword);
    addToken("else", HiKeyword);
    addToken("enum", HiKeyword);
    addToken("for", HiKeyword);
    addToken("goto", HiKeyword);
    addToken("if", HiKeyword);
    addToken("return", HiKeyword);
    addToken("sizeof", HiKeyword);
    addToken("struct", HiKeyword);
    addToken("switch", HiKeyword);
    addToken("union", HiKeyword);
    addToken("while", HiKeyword);

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

    addToken("uniform", HiInternal);
    addToken("varying", HiInternal);
    addToken("attribute", HiInternal);

    addToken("precision", HiInternal);

    addToken("gl_FragColor", HiInternal);
    addToken("gl_FragData", HiInternal);
    addToken("gl_FrontFacing", HiInternal);
    addToken("gl_PointCoord", HiInternal);
    addToken("gl_PointSize", HiInternal);
    addToken("gl_Position", HiInternal);
    addToken("gl_MaxVertexAttribs", HiInternal);
    addToken("gl_MaxVertexUniformVectors", HiInternal);
    addToken("gl_MaxVaryingVectors", HiInternal);
    addToken("gl_MaxVertexTextureImageUnits", HiInternal);
    addToken("gl_MaxCombinedTextureImageUnits", HiInternal);
    addToken("gl_MaxFragmentUniformVectors", HiInternal);
    addToken("gl_MaxDrawBuffers", HiInternal);
    addToken("gl_Vertex", HiInternal);
    addToken("gl_Normal", HiInternal);
    addToken("gl_Color", HiInternal);
    addToken("gl_FogCoodr", HiInternal);
    addToken("gl_MultiTexCoord0", HiInternal);
    addToken("gl_MultiTexCoord1", HiInternal);
    addToken("gl_MultiTexCoord2", HiInternal);
    addToken("gl_MultiTexCoord3", HiInternal);
    addToken("gl_MultiTexCoord4", HiInternal);
    addToken("gl_MultiTexCoord5", HiInternal);
    addToken("gl_MultiTexCoord6", HiInternal);
    addToken("gl_MultiTexCoord7", HiInternal);

    addToken("layout", HiInternal);
    addToken("location", HiInternal);

    addToken("void", HiType);
    addToken("int", HiType);
    addToken("bool", HiType);
    addToken("unsigneg", HiType);
    addToken("float", HiType);
    addToken("double", HiType);
    addToken("vec1", HiType);
    addToken("vec2", HiType);
    addToken("vec3", HiType);
    addToken("vec4", HiType);
    addToken("bvec1", HiType);
    addToken("bvec2", HiType);
    addToken("bvec3", HiType);
    addToken("bvec4", HiType);
    addToken("ivec1", HiType);
    addToken("ivec2", HiType);
    addToken("ivec3", HiType);
    addToken("ivec4", HiType);
    addToken("uvec1", HiType);
    addToken("uvec2", HiType);
    addToken("uvec3", HiType);
    addToken("uvec4", HiType);
    addToken("dvec1", HiType);
    addToken("dvec2", HiType);
    addToken("dvec3", HiType);
    addToken("dvec4", HiType);

    addToken("in", HiSpecial);
    addToken("out", HiSpecial);
    addToken("inout", HiSpecial);
  }
}
