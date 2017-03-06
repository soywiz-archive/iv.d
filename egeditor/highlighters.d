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

private enum HiBodySpecialMark = 253; // sorry; end user will never see this


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
      if (!(opt&EdHiTokens.Opt.NoStrings)) {
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
      }
      // identifier/keyword?
      if (ch.isalpha || ch == '_') {
        auto tmach = tks.start();
        auto epos = spos;
        ubyte stx = 0;
        while (epos <= le) {
          ch = gb[epos++];
          if (ch != '_' && !ch.isalnum) break;
          stx = tmach.advance(ch);
        }
        --epos;
        if (stx) {
          st = HS(stx);
          // sorry
          if (stx == HiBodySpecialMark) {
            st = HS(HiText);
            int xofs = epos;
            for (;;) {
              ch = gb[xofs];
              if (ch == '{') { st = HS(HiSpecial); break; }
              if (ch > ' ') break;
              ++xofs;
            }
          }
        } else {
          st = HS(HiText);
        }
        foreach (immutable _; spos..epos) gb.hi(spos++) = st;
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
      if (tks.canStartWith(ch)) {
        bool isdollar = (ch == '$');
        auto tmach = tks.start();
        auto epos = spos;
        uint lastlen = 0;
        ubyte stx = 0;
        while (epos <= le && tmach.canContinue) {
          if (auto tx = tmach.advance(gb[epos++])) {
            lastlen = cast(uint)(epos-spos);
            stx = tx;
          }
        }
        if (lastlen == 0 && isdollar && (opt&EdHiTokens.Opt.ShellSigil) && spos+1 < le) goto sigil;
        if (lastlen == 0) {
          lastlen = 1;
          st = HS(HiPunct);
        } else {
          st = HS(stx);
        }
        foreach (immutable cp; 0..lastlen) gb.hi(spos++) = st;
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
struct TokenMachine {
public:
  enum InvalidState = 0;

private:
  static struct MachineNode {
    char ch = 0; // current char
    ubyte endstate = InvalidState; // if not ubyte.max, this is what we should have if this node is terminal
    char firstch; // in next array
    int[] nexta;
    @property int next (char ch) const pure nothrow @trusted @nogc {
      pragma(inline, true);
      return (ch >= firstch && ch < firstch+nexta.length ? nexta.ptr[ch-firstch] : 0);
    }
    void setNext (char ch, int n) nothrow @trusted {
      assert(n != 0);
      auto optr = nexta.ptr;
      if (nexta.length == 0) {
        firstch = ch;
        nexta.reserve(2);
        nexta.length = 1;
        nexta[0] = n;
      } else if (ch < firstch) {
        int nfch = ch;
        auto inclen = firstch-nfch;
        nexta.length += inclen;
        foreach_reverse (immutable cc; inclen..nexta.length) nexta.ptr[cc] = nexta.ptr[cc-inclen];
        nexta[0..inclen] = 0;
        firstch = ch;
      } else {
        if (ch-firstch >= nexta.length) nexta.length = ch-firstch+1;
      }
      nexta[ch-firstch] = n;
      if (nexta.ptr !is optr) {
        import core.memory : GC;
        if (nexta.ptr is GC.addrOf(nexta.ptr)) {
          //conwriteln("resized, fixing flags...");
          GC.setAttr(nexta.ptr, GC.BlkAttr.NO_SCAN|GC.BlkAttr.NO_INTERIOR); // less false positives
        }
      }
    }
  }

private:
  MachineNode[] mach;

public:
  int minlen = 0, maxlen = 0; // token lengthes
  bool casesens = true;

private:
  int addMachineNode (MachineNode node) {
    if (mach.length >= int.max) assert(0, "too many nodes in mach");
    auto optr = mach.ptr;
    auto res = cast(int)mach.length;
    mach ~= node;
    if (mach.ptr !is optr) {
      import core.memory : GC;
      if (mach.ptr is GC.addrOf(mach.ptr)) {
        //conwriteln("resized, fixing flags...");
        GC.setAttr(mach.ptr, GC.BlkAttr.NO_INTERIOR); // less false positives
      }
    }
    return res;
  }

public:
  void addToken (string tok, ubyte estate) {
    if (tok.length >= int.max/8) assert(0, "wtf?!");
    if (tok.length == 0) return;
    if (minlen == 0 || tok.length < minlen) minlen = cast(int)tok.length;
    if (tok.length > maxlen) maxlen = cast(int)tok.length;
    assert(estate != InvalidState);
    if (mach.length == 0) addMachineNode(MachineNode(0));

    auto tst = checkToken(tok);
    if (tst != InvalidState) {
      if (tst != estate) {
        import core.stdc.stdio : stderr, fprintf;
        stderr.fprintf("WARNING: CONFLICTING TOKEN: '%.*s'\n", cast(uint)tok.length, tok.ptr);
      }
      return;
    }

    int lastnode = 0;
    foreach (char ch; tok) {
      if (!casesens && ch >= 'A' && ch <= 'Z') ch += 32;
      int nextnode = mach[lastnode].next(ch);
      if (nextnode == 0) {
        // new node
        nextnode = addMachineNode(MachineNode(ch));
        mach[lastnode].setNext(ch, nextnode);
      }
      lastnode = nextnode;
    }
    assert(lastnode > 0);
    char lastch = tok[$-1];
    assert(mach[lastnode].ch == lastch);
    assert(mach[lastnode].endstate == InvalidState);
    mach[lastnode].endstate = estate;
  }

  ubyte checkToken (const(char)[] tok) const nothrow @trusted @nogc {
    if (tok.length < minlen || tok.length > maxlen) return InvalidState;
    int node = 0;
    if (casesens) {
      foreach (char ch; tok) if ((node = mach.ptr[node].next(ch)) == 0) return InvalidState;
    } else {
      foreach (char ch; tok) {
        if (ch >= 'A' && ch <= 'Z') ch += 32;
        if ((node = mach.ptr[node].next(ch)) == 0) return InvalidState;
      }
    }
    return mach.ptr[node].endstate;
  }

  auto start () const nothrow @trusted @nogc {
    static struct Checker {
    private:
      const(TokenMachine)* tmach;
      int curnode;
    public:
    nothrow @trusted @nogc:
      @property ubyte state () const { pragma(inline, true); return (curnode >= 0 ? tmach.mach.ptr[curnode].endstate : InvalidState); }
      @property bool canContinue () const { pragma(inline, true); return (curnode >= 0); }
      @property int mintklen () const { pragma(inline, true); return tmach.minlen; }
      @property int maxtklen () const { pragma(inline, true); return tmach.maxlen; }
      ubyte advance (char ch) {
        if (curnode >= 0) {
          if (!tmach.casesens && ch >= 'A' && ch <= 'Z') ch += 32;
          if ((curnode = tmach.mach.ptr[curnode].next(ch)) == 0) {
            curnode = -1;
            return InvalidState;
          } else {
            return tmach.mach.ptr[curnode].endstate;
          }
        } else {
          return InvalidState;
        }
      }
    }
    return Checker(&this, 0);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
public abstract class EdHiTokens {
public:
  enum NotFound = 0;
  static assert(NotFound == TokenMachine.InvalidState);

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
    CPreprocessor = 1U<<12, // does this language use C preprocessor?
    JSRegExp      = 1U<<13, // parse JS inline regexps?
    ShellSigil    = 1U<<14, // parse shell sigils?
    // token machine options
    CaseInsensitive = 1U<<15, // are tokens case-sensitive?
    NoStrings       = 1U<<16, // no strings at all?
  }
  static assert(Opt.max <= uint.max);

public:
  uint options;
  TokenMachine tmach;

  final void setOptions (uint opt) {
    options = opt;
    tmach.casesens = ((opt&Opt.CaseInsensitive) == 0);
  }

public:
  this (uint opt) { setOptions(opt); }

final:
  void addToken (string tok, ubyte estate) {
    pragma(inline, true);
    tmach.addToken(tok, estate);
  }

  bool canStartWith (char ch) const nothrow @trusted @nogc {
    pragma(inline, true);
    return (tmach.mach.ptr[0].next(ch) > 0);
  }

  auto start () const nothrow @trusted @nogc {
    pragma(inline, true);
    return tmach.start();
  }
}


// ////////////////////////////////////////////////////////////////////////// //
public class EdHiTokensD : EdHiTokens {
  this () {
    super(
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
      //Opt.CPreprocessor|
      //Opt.JSRegExp|
      //Opt.ShellSigil|
      //Opt.CaseInsensitive|
      //Opt.NoStrings|
      0
    );

    addToken("body", /*HiSpecial*/HiBodySpecialMark);

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
    super(
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
      //Opt.CPreprocessor|
      Opt.JSRegExp|
      //Opt.ShellSigil|
      //Opt.CaseInsensitive|
      //Opt.NoStrings|
      0
    );

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
    super(
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
      Opt.CPreprocessor|
      //Opt.JSRegExp|
      //Opt.ShellSigil|
      //Opt.CaseInsensitive|
      //Opt.NoStrings|
      0
    );

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
    super(
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
      //Opt.CPreprocessor|
      //Opt.JSRegExp|
      Opt.ShellSigil|
      //Opt.CaseInsensitive|
      //Opt.NoStrings|
      0
    );

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
    super(
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
      Opt.CPreprocessor|
      //Opt.JSRegExp|
      //Opt.ShellSigil|
      //Opt.CaseInsensitive|
      //Opt.NoStrings|
      0
    );

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


// ////////////////////////////////////////////////////////////////////////// //
public class EdHiTokensHtml : EdHiTokens {
  this () {
    super(
      //Opt.Num0b|
      //Opt.Num0o|
      //Opt.Num0x|
      //Opt.NumAllowUnder|
      //Opt.NumAllowSign|
      //Opt.SQString|
      //Opt.BQString|
      //Opt.RQString|
      //Opt.DNestedComment|
      //Opt.ShellSingleComment|
      //Opt.CSingleComment|
      //Opt.CMultiComment|
      //Opt.CPreprocessor|
      //Opt.JSRegExp|
      //Opt.ShellSigil|
      Opt.CaseInsensitive|
      Opt.NoStrings|
      0
    );

    addToken("a", HiSpecial);
    addToken("abbr", HiSpecial);
    addToken("address", HiSpecial);
    addToken("applet", HiSpecial);
    addToken("area", HiSpecial);
    addToken("article", HiSpecial);
    addToken("aside", HiSpecial);
    addToken("audio", HiSpecial);
    addToken("b", HiSpecial);
    addToken("base", HiSpecial);
    addToken("basefont", HiSpecial);
    addToken("bdi", HiSpecial);
    addToken("bdo", HiSpecial);
    addToken("bgsound", HiSpecial);
    addToken("big", HiSpecial);
    addToken("blockquote", HiSpecial);
    addToken("body", HiSpecial);
    addToken("br", HiSpecial);
    addToken("button", HiSpecial);
    addToken("canvas", HiSpecial);
    addToken("caption", HiSpecial);
    addToken("center", HiSpecial);
    addToken("cite", HiSpecial);
    addToken("code", HiSpecial);
    addToken("col", HiSpecial);
    addToken("colgroup", HiSpecial);
    addToken("command", HiSpecial);
    addToken("data", HiSpecial);
    addToken("datalist", HiSpecial);
    addToken("dd", HiSpecial);
    addToken("del", HiSpecial);
    addToken("details", HiSpecial);
    addToken("dfn", HiSpecial);
    addToken("dialog", HiSpecial);
    addToken("dir", HiSpecial);
    addToken("div", HiSpecial);
    addToken("dl", HiSpecial);
    addToken("dt", HiSpecial);
    addToken("em", HiSpecial);
    addToken("embed", HiSpecial);
    addToken("fieldset", HiSpecial);
    addToken("figcaption", HiSpecial);
    addToken("figure", HiSpecial);
    addToken("font", HiSpecial);
    addToken("footer", HiSpecial);
    addToken("form", HiSpecial);
    addToken("frame", HiSpecial);
    addToken("frameset", HiSpecial);
    addToken("h1", HiSpecial);
    addToken("h2", HiSpecial);
    addToken("h3", HiSpecial);
    addToken("h4", HiSpecial);
    addToken("h5", HiSpecial);
    addToken("h6", HiSpecial);
    addToken("head", HiSpecial);
    addToken("header", HiSpecial);
    addToken("hgroup", HiSpecial);
    addToken("hr", HiSpecial);
    addToken("html", HiSpecial);
    addToken("i", HiSpecial);
    addToken("iframe", HiSpecial);
    addToken("image", HiSpecial);
    addToken("img", HiSpecial);
    addToken("input", HiSpecial);
    addToken("ins", HiSpecial);
    addToken("kbd", HiSpecial);
    addToken("keygen", HiSpecial);
    addToken("label", HiSpecial);
    addToken("legend", HiSpecial);
    addToken("li", HiSpecial);
    addToken("link", HiSpecial);
    addToken("listing", HiSpecial);
    addToken("main", HiSpecial);
    addToken("map", HiSpecial);
    addToken("mark", HiSpecial);
    addToken("marquee", HiSpecial);
    addToken("math", HiSpecial);
    addToken("mathml", HiSpecial);
    addToken("menu", HiSpecial);
    addToken("menuitem", HiSpecial);
    addToken("meta", HiSpecial);
    addToken("meter", HiSpecial);
    addToken("nav", HiSpecial);
    addToken("nobr", HiSpecial);
    addToken("noembed", HiSpecial);
    addToken("noframes", HiSpecial);
    addToken("noscript", HiSpecial);
    addToken("object", HiSpecial);
    addToken("ol", HiSpecial);
    addToken("optgroup", HiSpecial);
    addToken("option", HiSpecial);
    addToken("output", HiSpecial);
    addToken("p", HiSpecial);
    addToken("param", HiSpecial);
    addToken("picture", HiSpecial);
    addToken("plaintext", HiSpecial);
    addToken("pre", HiSpecial);
    addToken("progress", HiSpecial);
    addToken("q", HiSpecial);
    addToken("rb", HiSpecial);
    addToken("rp", HiSpecial);
    addToken("rt", HiSpecial);
    addToken("rtc", HiSpecial);
    addToken("ruby", HiSpecial);
    addToken("s", HiSpecial);
    addToken("samp", HiSpecial);
    addToken("script", HiSpecial);
    addToken("section", HiSpecial);
    addToken("select", HiSpecial);
    addToken("slot", HiSpecial);
    addToken("small", HiSpecial);
    addToken("source", HiSpecial);
    addToken("span", HiSpecial);
    addToken("strike", HiSpecial);
    addToken("strong", HiSpecial);
    addToken("style", HiSpecial);
    addToken("sub", HiSpecial);
    addToken("summary", HiSpecial);
    addToken("sup", HiSpecial);
    addToken("svg", HiSpecial);
    addToken("table", HiSpecial);
    addToken("tbody", HiSpecial);
    addToken("td", HiSpecial);
    addToken("template", HiSpecial);
    addToken("textarea", HiSpecial);
    addToken("tfoot", HiSpecial);
    addToken("th", HiSpecial);
    addToken("thead", HiSpecial);
    addToken("time", HiSpecial);
    addToken("title", HiSpecial);
    addToken("tr", HiSpecial);
    addToken("track", HiSpecial);
    addToken("tt", HiSpecial);
    addToken("u", HiSpecial);
    addToken("ul", HiSpecial);
    addToken("var", HiSpecial);
    addToken("video", HiSpecial);
    addToken("wbr", HiSpecial);
    addToken("xmp", HiSpecial);
  }
}
