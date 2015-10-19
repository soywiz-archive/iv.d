/* coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * Understanding is not required. Only obedience.
 *
 *                   INVISIBLE VECTOR PUBLIC LICENSE
 *                       Version 1, September 2015
 *
 * Copyright (C) 2015 Ketmar Dark <ketmar@ketmar.no-ip.org>
 *
 * Everyone is permitted to copy and distribute verbatim or modified
 * copies of this license document, and changing it is allowed as long
 * as the name is changed.
 *
 *                   INVISIBLE VECTOR PUBLIC LICENSE
 *   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
 *
 * 0. You may not use this software in either source or binary form, any
 *    software derived from this software, any library which uses either
 *    this software or code derived from this software in any other
 *    software on the territory of Russian Federation, either directly or
 *    indirectly via any chain of libraries.
 *
 * 1. Redistributions of this software in either source or binary form must
 *    retain this list of conditions and the following disclaimer.
 *
 * 2. Otherwise, you are allowed to use this software in any way that will
 *    not violate paragraphs 0 and 1 of this license.
 *
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 * Authors: Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * License: IVPLv1
 */


/**
 * Read string from TTY with autocompletion.
 *
 * WARNING! Maximum str length is 64!
 *
 * Params:
 *  prompt = input prompt
 *  strlist = list of autocompletions
 *  str = initial string value
 *
 * Returns:
 *  entered string or empty string on cancel
 *
 * Throws:
 *  Exception on TTY mode errors
 */
string ttyReadString (string prompt, const(string)[] strlist=null, string str=string.default) @trusted {
  import core.sys.posix.unistd : STDOUT_FILENO, write;
  import std.algorithm : min, max;
  import iv.rawtty : ttyIsRedirected, ttyGetMode, ttySetMode, ttySetRaw, ttyReadKeyByte, ttyWidth, ttyHeight, TTYMode;
  import iv.autocomplete : autocomplete;

  static void wrt (const(char)[] s) @trusted nothrow @nogc {
    if (s.length) write(STDOUT_FILENO, s.ptr, s.length);
  }

  static void beep () @trusted nothrow @nogc => wrt("\x07");

  if (ttyIsRedirected) throw new Exception("TTY is redirected");
  auto oldMode = ttyGetMode();
  scope(exit) ttySetMode(oldMode);
  if (oldMode != TTYMode.RAW) {
    if (ttySetRaw() == TTYMode.BAD) throw new Exception("can't change TTY mode to raw");
  }

  uint prevLines = 0; // # of previous written lines in 'tab list'

  void upPrevLines () {
    char[32] num;
    usize pos = num.length;
    auto n = prevLines;
    num[--pos] = 'A';
    do {
      num[--pos] = cast(char)('0'+n%10);
      n /= 10;
    } while (n);
    num[--pos] = '[';
    num[--pos] = '\e';
    wrt(num[pos..$]);
  }

  // clear prompt and hint lines
  // return cursor to prompt line
  void clearHints () {
    if (prevLines) {
      wrt("\r\x1b[K");
      foreach (; 0..prevLines) wrt("\n\r\x1b[K");
      upPrevLines();
      prevLines = 0;
    }
  }

  bool prevWasReturn = false;
  wrt("\x1b[0m");
  scope(exit) {
    clearHints();
    wrt("\r\x1b[K");
  }
  for (;;) {
    int ch;
    wrt("\r\x1b[0m");
    wrt(prompt);
    wrt("\x1b[37;1m");
    wrt(str);
    wrt("\x1b[0m\x1b[K");
    // try to see if we have something to show here
    if (strlist.length) {
      auto ac = autocomplete(str, strlist);
      if (ac.length > 0) {
        //stdout.writeln("\r\n", ac);
        auto s = ac[0];
        s = s[str.length..$];
        wrt("\x1b[0;1m");
        wrt(s);
        foreach (; 0..s.length) wrt("\x08");
        wrt("\x1b[0m");
      }
    }
    //stdout.flush();
    ch = ttyReadKeyByte();
    if (ch < 0 || ch == 3 || ch == 4) { str = ""; break; } // error, ^C or ^D
    if (ch == 10) {
      // return
      if (strlist.length == 0) break; // we have no autocompletion variants
      // if there is exactly one full match, return it
      auto ac = autocomplete(str, strlist);
      if (ac.length == 1) { str = ac[0]; break; } // the match is ok
      if (prevWasReturn) break; // this is second return in a row
      // else do autocomplete
      ch = 9;
      if (ac.length) beep(); // 'cause #9 will not beep in this case
      prevWasReturn = true; // next 'return' will force return
    } else {
      // reset 'double return' flag
      prevWasReturn = false;
    }
    if (ch == 23 || ch == 25) {
      // ^W or ^Y
      str = "";
      continue;
    }
    if (ch == 27) {
      // esc
      ch = ttyReadKeyByte();
      if (ch == 27) { str = ""; break; }
      clearHints();
      do {
        version(readstring_debug) {
          import std.stdio : stdout;
          stdout.writef("ch: %3d", ch);
          if (ch >= 32 && ch != 127) stdout.write("'", cast(char)ch, "'");
          stdout.writeln();
        }
        if (ch != '[' && ch != ';' && (ch < '0' || ch > '9')) {
          version(readstring_debug) wrt("DONE!");
          break;
        }
      } while ((ch = ttyReadKeyByte(100)) >= 0);
    }
    if (ch == 8 || ch == 127) {
      // backspace
      if (str.length) str = str[0..$-1]; else beep();
      continue;
    }
    if (ch == 9) {
      // tab
      clearHints();
      prevLines = 0;
      auto ac = autocomplete(str, strlist);
      if (ac.length != 1) beep();
      if (ac.length) {
        str = ac[0];
        if (ac.length > 1) {
          usize maxlen, rc;
          ac = ac[1..$];
          //sort!"a<b"(ac);
          // calculate maximum item length
          foreach (immutable s; ac) maxlen = max(maxlen, s.length);
          ++maxlen; // plus space
          if (maxlen < ttyWidth) {
            rc = ttyWidth/maxlen;
          } else {
            rc = 1;
          }
          prevLines = min(ac.length/rc+(ac.length%rc != 0), ttyHeight-1);
          wrt("\r\n\x1b[1m"); // skip prompt line
          foreach (immutable i, immutable s; ac) {
            if (i && i%rc == 0) wrt("\n");
            wrt(s);
            wrt(" ");
          }
          wrt("\x1b[0m");
          upPrevLines();
        }
      }
      continue;
    }
    if (ch > 32 && ch < 127 && str.length < 64) {
      str ~= ch;
      continue;
    }
    beep();
  }
  return str;
}
