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
  enum Result {
    Normal,
    CtrlC,
    CtrlD,
  }

  enum MaxLength = 4096;
  uint historyLimit = 512;
  string[] history;

protected:
  char[] curline;
  int curlen;
  int curpos;
  int curofs; // output offset
  char[] promptbuf;

public:
  this () {
    promptbuf = ">".dup;
  }

  final @property T get(T=string) () if (is(T == const(char)[]) || is(T == string)) {
    static if (is(T == string)) return curline[0..curlen].idup; else return curline[0..curlen];
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
         if (history.length > MaxLength) history.length = MaxLength;
    else if (history.length < MaxLength) history.length += 1;
    foreach_reverse (immutable c; 1..history.length) history[c] = history[c-1];
    history[0] = hs;
  }

  // return `null` on special
  final Result readline () {
    char[] lastInput; // stored for history walks
    uint lastLen; // stored for history walks
    int hpos = -1; // -1: current

    void fixCurLine () {
      if (hpos != -1) {
        curline = history[hpos].dup;
        hpos = -1;
      }
      lastInput = null;
    }

    void drawLine () {
      auto wdt = ttyWidth;
      const(char)[] cline = (hpos < 0 ? curline : history[hpos]);
      if (wdt <= promptbuf.length+2) wdt = 2; else wdt -= promptbuf.length;
      if (curpos < 0) curpos = 0;
      if (curpos > curlen) curpos = curlen;
      if (curpos < curofs) curofs = curpos-8;
      if (curofs < 0) curofs = 0;
      if (curofs+wdt <= curpos) {
        curofs = curpos-(wdt < 8 ? wdt-1 : wdt-8);
        if (curofs < 0) curofs = 0;
      }
      int end = curofs+wdt;
      if (end > curlen) end = curlen;
      wrt("\r");
      wrt(promptbuf);
      wrt(cline[curofs..end]);
      wrt("\x1b[K\r\x1b[");
      wrtuint(promptbuf.length+(curpos-curofs));
      wrt("C");
    }

    curlen = 0;
    curpos = 0;
    curofs = 0;
    curline.assumeSafeAppend;
    auto ttymode = ttyGetMode();
    scope(exit) ttySetMode(ttymode);
    ttySetRaw();

    void doBackspace () {
      if (curlen-curpos > 1) {
        import core.stdc.string : memmove;
        memmove(curline.ptr+curpos-1, curline.ptr+curpos, curlen-curpos);
      }
      --curpos;
      --curlen;
    }

    for (;;) {
      drawLine();
      auto key = ttyReadKey();
      if (key.length == 0) continue;
      if (key == "^C") { curlen = 0; return Result.CtrlC; }
      if (key == "^D") { curlen = 0; return Result.CtrlD; }
      if (key == "left") { --curpos; continue; }
      if (key == "right") { ++curpos; continue; }
      if (key == "home" || key == "^A") { curpos = 0; continue; }
      if (key == "end" || key == "^E") { curpos = curlen; continue; }
      if (key == "return") { fixCurLine(); return Result.Normal; }
      if (key == "tab") { fixCurLine(); autocomplete(); continue; }
      if (key == "^K") { fixCurLine(); curlen = curpos; continue; }
      if (key == "^W") {
        if (curpos > 0) {
          fixCurLine();
          while (curpos > 0 && curline[curpos-1] <= ' ') doBackspace();
          while (curpos > 0 && curline[curpos-1] > ' ') doBackspace();
          continue;
        }
      }
      if (key == "up") {
        if (history.length == 0) continue;
        if (hpos == -1) {
          // store current line so we can return to it
          lastInput = curline;
          lastLen = curlen;
          hpos = 0;
        } else if (hpos < history.length-1) {
          ++hpos;
        } else {
          continue;
        }
        curlen = cast(int)history[hpos].length;
        curpos = curlen;
        curofs = 0;
        continue;
      }
      if (key == "down") {
        if (history.length == 0) continue;
        if (hpos == 0) {
          // store current line so we can return to it
          hpos = -1;
          curline = lastInput;
          curlen = lastLen;
        } else if (hpos > 0) {
          --hpos;
          curlen = cast(int)history[hpos].length;
        } else {
          continue;
        }
        curpos = curlen;
        curofs = 0;
        continue;
      }
      if (key == "backspace") {
        if (curlen > 0 && curpos > 0) {
          fixCurLine();
          doBackspace();
        }
        continue;
      }
      if (key.length == 1) {
        if (curlen < MaxLength) {
          import core.stdc.string : memmove;
          fixCurLine();
          if (curlen+1 >= curline.length) curline.length = curlen+1024;
          // make room
          if (curpos < curlen) memmove(curline.ptr+curpos+1, curline.ptr+curpos, curlen-curpos); // insert
          curline[curpos++] = key[0];
          ++curlen;
        }
        continue;
      }
    }
  }

  void autocomplete () {}

protected:
  void replaceLine (const(char)[] s) {
    if (s.length > MaxLength) s = s[0..MaxLength];
    if (curline.length < s.length) curline.length = s.length;
    if (s.length) {
      curline[0..s.length] = s[];
    }
    curpos = curlen = cast(int)s.length;
  }

  void clearOutput () { wrt("\r\x1b[K"); }

static:
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
}


// ////////////////////////////////////////////////////////////////////////// //
version(editline_test) {
import iv.strex;
void main () {
  auto el = new EditLine();
  el.readline();
  import std.stdio;
  writeln("\n[", el.get.quote, "]");
}
}
