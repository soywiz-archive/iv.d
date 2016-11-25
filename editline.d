/* Simple readline/editline replacement. Deliberately non-configurable.
 *
 * Written by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
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
module iv.editline;

import iv.rawtty;
import iv.strex;


// ////////////////////////////////////////////////////////////////////////// //
class EditLine {
public:
  final class Line {
  public:
    enum MaxLen = 4096;

  private:
    char[MaxLen] cline;
    int lpos; // cursor position: [0..len]
    int llen; // line length (line can be longer)
    //uint ofs; // used in text draw

  public:
    this () {}

    // cursor position
    @property int pos () const pure nothrow @safe @nogc { pragma(inline, true); return lpos; }
    @property void pos (int npos) pure nothrow @safe @nogc { if (npos < 0) npos = 0; if (npos > llen) npos = llen; lpos = npos; }
    void movePos (int delta) {
      if (delta < -MaxLen) delta = -MaxLen;
      if (delta > MaxLen) delta = MaxLen;
      pos = lpos+delta;
    }

    // line length
    @property int length () const pure nothrow @safe @nogc { pragma(inline, true); return llen; }

    char opIndex (long pos) const pure nothrow @trusted @nogc { pragma(inline, true); return (pos >= 0 && pos < llen ? cline.ptr[cast(uint)pos] : 0); }
    const(char)[] opIndex() (in auto ref WordPos wp) const pure nothrow @safe @nogc { pragma(inline, true); return this[wp.s..wp.e]; }

    // do not slice it, buffer WILL change
    const(char)[] opSlice () const pure nothrow @safe @nogc { pragma(inline, true); return cline[0..llen]; }
    const(char)[] opSlice (long lo, long hi) const pure nothrow @safe @nogc {
      //pragma(inline, true);
      if (lo >= hi) return null;
      if (hi <= 0 || lo >= llen) return null;
      if (lo < 0) lo = 0;
      if (hi > llen) hi = llen;
      return cline[cast(uint)lo..cast(uint)hi];
    }

    // clear line
    void clear () pure nothrow @trusted @nogc { lpos = llen = 0; }

    // crop line at current position
    void crop () pure nothrow @trusted @nogc { llen = lpos; }

    // set current line, move cursor to end; crop if length is too big
    // return `false` if new line was cropped
    bool set (const(char)[] s...) pure nothrow @trusted @nogc {
      bool res = true;
      if (s.length > MaxLen) { s = s[0..MaxLen]; res = false; }
      if (s.length) cline[0..s.length] = s[];
      lpos = llen = cast(int)s.length;
      return res;
    }

    // insert chars at cursor position, move cursor
    // return `false` if there is no room, line is not modified in this case
    bool insert (const(char)[] s...) pure nothrow @trusted @nogc {
      if (s.length == 0) return true;
      if (s.length > MaxLen || llen+s.length > MaxLen) return false;
      // make room
      if (lpos < llen) {
        import core.stdc.string : memmove;
        memmove(cline.ptr+lpos+cast(int)s.length, cline.ptr+lpos, llen-lpos);
      }
      llen += cast(int)s.length;
      // copy
      cline[lpos..lpos+cast(int)s.length] = s[];
      lpos += cast(int)s.length;
      return true;
    }

    // replace chars at cursor position, move cursor; does appending
    // return `false` if there is no room, line is not modified in this case
    bool replace (const(char)[] s...) pure nothrow @trusted @nogc {
      if (s.length == 0) return true;
      if (s.length > MaxLen || lpos+s.length > MaxLen) return false;
      // replace
      cline[lpos..lpos+cast(int)s.length] = s[];
      lpos += cast(int)s.length;
      if (llen < lpos) llen = lpos;
      return true;
    }

    // remove chars at cursor position (delete), don't move cursor
    void remove (int len) pure nothrow @trusted @nogc {
      if (len < 1 || lpos >= llen) return;
      if (len > MaxLen) len = MaxLen;
      if (lpos+len >= llen) {
        // strip
        llen = lpos;
      } else {
        import core.stdc.string : memmove;
        memmove(cline.ptr+lpos, cline.ptr+lpos+len, llen-(lpos+len));
        llen -= len;
        assert(lpos < llen);
      }
    }

    // delete chars at cursor position (backspace), move cursor
    void backspace (int len) pure nothrow @trusted @nogc {
      if (len < 1 || lpos < 1) return;
      if (len > lpos) len = lpos;
      lpos -= len;
      remove(len);
    }

    // //// something to make programmer's life easier //// //

    static struct WordPos {
      int s, e; // start and end position, suitable for slicing
      @property bool valid () const pure nothrow @safe @nogc { pragma(inline, true); return (s >= 0 && s < e); }
      @property int length () const pure nothrow @safe @nogc { pragma(inline, true); return e-s; }
    }

    // word positions range
    auto words () inout pure nothrow @trusted @nogc {
      static struct Result {
      private:
        const Line ln;
        WordPos wp;
        this (in Line aln) pure nothrow @safe @nogc { ln = aln; popFront(); }
        this() (in Line aln, in auto ref WordPos awp) pure nothrow @safe @nogc { ln = aln; wp.s = awp.s; wp.e = awp.e; }
      public:
        @property const(char)[] word () const pure nothrow @safe @nogc { pragma(inline, true); return ln[wp.s..wp.e]; }
        @property WordPos front () const pure nothrow @safe @nogc { pragma(inline, true); return WordPos(wp.s, wp.e); }
        @property bool empty () const pure nothrow @safe @nogc { pragma(inline, true); return (wp.s >= ln.llen); }
        @property auto save () const pure nothrow @safe @nogc { pragma(inline, true); return Result(ln, wp); }
        @property void popFront () pure nothrow @trusted @nogc {
          if (wp.s >= ln.llen) return;
          wp.s = wp.e;
          while (wp.s < ln.llen && ln.cline.ptr[wp.s] <= ' ') ++wp.s;
          wp.e = wp.s;
          if (wp.e >= ln.llen) return;
          char qch = ln.cline.ptr[wp.e];
          if (qch == '"' || qch == '\'' || qch == '`') {
            // quoted
            ++wp.e;
            while (wp.e < ln.llen) {
              char ch = ln.cline.ptr[wp.e++];
              if (ch == '\\') {
                if (wp.e < ln.llen) ++wp.e;
              } else if (ch == qch) {
                break;
              }
            }
          } else {
            while (wp.e < ln.llen && ln.cline.ptr[wp.e] > ' ') ++wp.e;
          }
        }
      }
      return Result(this);
    }

    int wordCount () const pure nothrow @trusted @nogc {
      int res = 0;
      auto ww = words();
      while (!ww.empty) { ++res; ww.popFront(); }
      return res;
    }

    const(char)[] word (int idx) const pure nothrow @trusted @nogc {
      if (idx < 0) return null;
      auto ww = words();
      while (idx > 0 && !ww.empty) { --idx; ww.popFront(); }
      if (!ww.empty) return this[ww.front.s..ww.front.e];
      return null;
    }

    // assume that `pos` is inside word, return `true` if word starts with quote
    bool wordQuoted (int pos) const pure nothrow @trusted @nogc {
      foreach (const ref wp; words) {
        if (pos >= wp.s && pos < wp.e) {
          // our word
          char ch = this[wp.s];
          return (ch == '"' || ch == '\'' || ch == '`');
        }
      }
      return false;
    }

    // we can autocomplete empty line or any word if we're at it's end
    bool canAutocomplete () const pure nothrow @trusted @nogc {
      if (llen == 0) return true;
      if (llen == MaxLen) return false;
      if (lpos == 0) return false; // we have some text, so can't
      if (lpos == llen) return (cline.ptr[lpos-1] <= ' ' || !wordQuoted(lpos-1));
      // end of word?
      return (cline.ptr[lpos] <= ' ' && cline.ptr[lpos-1] > ' ' && !wordQuoted(lpos-1));
    }

    // get word number for autocompletion
    int acWordNum () const pure nothrow @trusted @nogc {
      if (!canAutocomplete) return -1;
      if (lpos == llen && cline.ptr[lpos-1] <= ' ') return wordCount;
      int idx;
      foreach (ref wp; words) {
        if (lpos >= wp.s && lpos <= wp.e) return idx;
        ++idx;
      }
      return idx;
    }

    // get word for autocompletion
    WordPos acWordPos () const pure nothrow @trusted @nogc {
      if (!canAutocomplete) return WordPos();
      if (lpos == llen && cline.ptr[lpos-1] <= ' ') return WordPos(llen, llen);
      foreach (ref wp; words) if (lpos >= wp.s && lpos <= wp.e) return wp;
      return WordPos(llen, llen);
    }

    // replace current with new
    bool acWordReplace (const(char)[] w, bool addSpace=false) pure nothrow @trusted @nogc {
      if (w.length == 0 || w.length > MaxLen || !canAutocomplete) return false;
      foreach (const ref wp; words) {
        if (lpos >= wp.s && lpos <= wp.e) {
          // check if we should add space
          if (addSpace) addSpace = (wp.e >= llen || cline.ptr[wp.e] > ' ');
          int addlen = (addSpace ? 1 : 0);
          if (llen-wp.length+w.length+addlen > MaxLen) return false;
          backspace(wp.length);
          insert(w);
          if (addSpace) insert(' ');
          return true;
        }
      }
      return false;
    }

    // replace current word with new, add space
    bool acWordReplaceSpaced (const(char)[] w) pure nothrow @trusted @nogc { return acWordReplace(w, true); }
  }

public:
  enum Result {
    Normal,
    CtrlC,
    CtrlD,
  }

  uint historyLimit = 512;
  string[] history;

protected:
  Line curline;
  char[] promptbuf;

public:
  this () { promptbuf = ">".dup; curline = new Line(); }

  final @property inout(Line) line () inout pure nothrow @safe @nogc { pragma(inline, true); return curline; }

  // const(char)[] returns slice of internal buffer, don't store it!
  final @property T get(T=string) () if (is(T : const(char)[])) {
         static if (is(T == string)) return curline[].idup;
    else static if (is(T == const(char)[])) return curline[];
    else return curline[].dup;
  }

  final @property string prompt () { return promptbuf.idup; }
  final @property prompt (const(char)[] pt) {
    promptbuf.length = 0;
    promptbuf.assumeSafeAppend;
    if (pt.length > 61) { promptbuf ~= "..."; pt = pt[$-61..$]; }
    promptbuf ~= pt;
  }

  final void pushCurrentToHistory () { pushToHistory(get!string); }

  final void pushToHistory(T : const(char)[]) (T s) {
         static if (is(T == typeof(null))) string hs = null;
    else static if (is(T == string)) string hs = s.xstrip;
    else string hs = s.xstrip.idup;
    if (hs.length == 0) return;
    // find duplicate and remove it
    foreach (immutable idx, string st; history) {
      if (st.xstrip == hs) {
        // i found her!
        // remove
        foreach (immutable c; idx+1..history.length) history[c-1] = history[c];
        // move
        foreach_reverse (immutable c; 1..history.length) history[c] = history[c-1];
        // set
        history[0] = hs;
        // done
        return;
      }
    }
         if (history.length > historyLimit) history.length = historyLimit;
    else if (history.length < historyLimit) history.length += 1;
    foreach_reverse (immutable c; 1..history.length) history[c] = history[c-1];
    history[0] = hs;
  }

  final Result readline (const(char)[] initval=null) {
    char[Line.MaxLen] lastInput; // stored for history walks
    uint lastLen; // stored for history walks
    int hpos = -1; // -1: current
    int curofs; // output offset

    void fixCurLine () {
      hpos = -1;
      lastLen = 0;
    }

    void drawLine () {
      auto wdt = ttyWidth-1;
      if (wdt < 16) wdt = 16;
      const(char)[] cline = (hpos < 0 ? curline[] : history[hpos]);
      if (wdt <= promptbuf.length+3) wdt = 3; else wdt -= cast(int)promptbuf.length;
      int wvis = (wdt < 10 ? wdt-1 : 8);
      int cpos = curline.pos;
      // special handling for negative offset: it means "make left part visible"
      if (curofs < 0) {
        // is cursor at eol? special handling
        if (cpos == curline.length) {
          curofs = cpos-wdt;
          if (curofs < 0) curofs = 0;
        } else {
          // make wvis char after cursor visible
          curofs = cpos-wdt+wvis;
          if (curofs < 0) curofs = 0;
          // i did something wrong here...
          if (curofs >= curline.length) {
            curofs = curline.length-wdt;
            if (curofs < 0) curofs = 0;
          }
        }
      } else {
        // is cursor too far at left?
        if (cpos < curofs) {
          // make wvis left chars visible
          curofs = cpos-wvis;
          if (curofs < 0) curofs = 0;
        }
        // is cursor too far at right?
        if (curofs+wdt <= cpos) {
          // make wvis right chars visible
          curofs = cpos-wdt+wvis;
          if (curofs < 0) curofs = 0;
          if (curofs >= curline.length) {
            curofs = curline.length-wdt;
            if (curofs < 0) curofs = 0;
          }
        }
      }
      assert(curofs >= 0 && curofs <= curline.length);
      int end = curofs+wdt;
      if (end > curline.length) end = curline.length;
      wrt("\r");
      wrt(promptbuf);
      wrt(curline[curofs..end]);
      if (cpos == end) {
        wrt("\x1b[K");
      } else {
        wrt("\x1b[K\r\x1b[");
        wrtuint(promptbuf.length+(cpos-curofs));
        wrt("C");
      }
    }

    curofs = 0;
    curline.clear();
    if (initval.length) curline.set(initval);

    auto ttymode = ttyGetMode();
    scope(exit) ttySetMode(ttymode);
    ttySetRaw();

    void delPrevWord () {
      if (curline.pos > 0) {
        fixCurLine();
        while (curline.pos > 0 && curline[curline.pos-1] <= ' ') curline.backspace(1);
        while (curline.pos > 0 && curline[curline.pos-1] > ' ') curline.backspace(1);
      }
    }

    for (;;) {
      drawLine();
      auto key = ttyReadKey();
      if (key.key == TtyEvent.Key.Error) { curline.clear(); return Result.CtrlD; }
      if (key.key == TtyEvent.Key.Unknown) continue;
      if (key.key == TtyEvent.Key.ModChar) {
        if (!key.alt && key.ctrl && !key.shift && key.ch == 'W') { delPrevWord(); continue; }
        if (!key.alt && key.ctrl && !key.shift && key.ch == 'C') { curline.clear(); return Result.CtrlC; }
        if (!key.alt && key.ctrl && !key.shift && key.ch == 'D') { curline.clear(); return Result.CtrlD; }
        if (!key.alt && key.ctrl && !key.shift && key.ch == 'K') { fixCurLine(); curline.crop(); continue; }
        if (!key.alt && key.ctrl && !key.shift && key.ch == 'Y') { fixCurLine(); curline.clear(); continue; }
        if (!key.alt && key.ctrl && !key.shift && key.ch == 'A') { curline.movePos(-curline.MaxLen); continue; }
        if (!key.alt && key.ctrl && !key.shift && key.ch == 'E') { curline.movePos(curline.MaxLen); continue; }
        continue;
      }
      switch (key.key) {
        case TtyEvent.Key.Left:
          if (!key.alt && !key.shift) {
            if (key.ctrl) {
              if (curline.pos > 0) {
                if (curline[curline.pos-1] <= ' ') {
                  // move to word end
                  while (curline.pos > 0 && curline[curline.pos-1] <= ' ') curline.movePos(-1);
                } else {
                  // move to word start
                  while (curline.pos > 0 && curline[curline.pos-1] > ' ') curline.movePos(-1);
                }
              }
            } else {
              curline.movePos(-1);
            }
          }
          break;
        case TtyEvent.Key.Right:
          if (!key.alt && !key.shift) {
            if (key.ctrl) {
              if (curline.pos < curline.length) {
                if (curline[curline.pos] <= ' ') {
                  // move to word start
                  while (curline.pos < curline.length && curline[curline.pos] <= ' ') curline.movePos(1);
                } else {
                  // move to word end
                  while (curline.pos < curline.length && curline[curline.pos] > ' ') curline.movePos(1);
                }
              }
            } else {
              curline.movePos(1);
            }
          }
          break;
        case TtyEvent.Key.Home:
          if (!key.ctrl && !key.alt && !key.shift) curline.movePos(-curline.MaxLen);
          break;
        case TtyEvent.Key.End:
          if (!key.ctrl && !key.alt && !key.shift) curline.movePos(curline.MaxLen);
          break;
        case TtyEvent.Key.Enter:
          fixCurLine();
          wrt("\r\n");
          return Result.Normal;
        case TtyEvent.Key.Tab:
          if (!key.ctrl && !key.alt && !key.shift) { fixCurLine(); autocomplete(); continue; }
          break;
        case TtyEvent.Key.Up:
          if (!key.ctrl && !key.alt && !key.shift) {
            if (history.length == 0) continue;
            if (hpos == -1) {
              // store current line so we can return to it
              lastInput[0..curline.length] = curline[];
              lastLen = curline.length;
              hpos = 0;
            } else if (hpos < history.length-1) {
              ++hpos;
            } else {
              continue;
            }
            curline.set(history[hpos]);
            curofs = 0;
          }
          break;
        case TtyEvent.Key.Down:
          if (!key.ctrl && !key.alt && !key.shift) {
            if (history.length == 0) continue;
            if (hpos == 0) {
              // restore previous user line
              hpos = -1;
              curline.set(lastInput[0..lastLen]);
              curofs = 0;
            } else if (hpos > 0) {
              --hpos;
              curline.set(history[hpos]);
              curofs = 0;
            }
          }
          break;
        case TtyEvent.Key.Backspace:
          if (!key.ctrl && !key.alt && !key.shift) {
            if (curline.length > 0 && curline.pos > 0) {
              fixCurLine();
              curline.backspace(1);
            }
          } else if (!key.ctrl && key.alt && !key.shift) {
            delPrevWord();
          }
          break;
        case TtyEvent.Key.Delete:
          if (!key.ctrl && !key.alt && !key.shift) {
            if (curline.pos < curline.length) {
              fixCurLine();
              curline.remove(1);
            }
          }
          break;
        case TtyEvent.Key.Char:
          if (key.ch >= ' ' && key.ch < 127) {
            if (curline.length < Line.MaxLen) {
              fixCurLine();
              curline.insert(cast(char)key.ch);
            }
          }
          break;
        default:
      }
    }
  }

  void autocomplete () {}

public:
static:
  void clearOutput () { wrt("\r\x1b[K"); }

  void wrt (const(char)[] str...) nothrow @nogc {
    import core.sys.posix.unistd : write;
    if (str.length) write(1, str.ptr, str.length);
  }

  void wrtuint (int n) nothrow @nogc {
    char[32] buf = void;
    uint pos = buf.length;
    if (n < 0) n = 0;
    do {
      buf.ptr[--pos] = cast(char)(n%10+'0');
      n /= 10;
    } while (n != 0);
    wrt(buf[pos..$]);
  }

  void beep () { wrt('\x07'); }
}


// ////////////////////////////////////////////////////////////////////////// //
version(editline_test) {
import iv.strex;
void main () {
  auto el = new EditLine();
  for (;;) {
    import std.stdio;
    auto res = el.readline();
    writeln;
    if (res != EditLine.Result.Normal) break;
    writeln("[", el.get.quote, "]");
    writeln(el.line.wordCount, " words in line");
    foreach (const ref wp; el.line.words) writeln("  ", el.line[wp].quote);
    el.pushCurrentToHistory();
  }
}
}
