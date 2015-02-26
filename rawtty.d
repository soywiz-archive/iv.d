/* coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * Understanding is not required. Only obedience.
 *
 *                   INVISIBLE VECTOR PUBLIC LICENSE
 *                       Version 0, August 2014
 *
 * Copyright (C) 2014 Ketmar Dark <ketmar@ketmar.no-ip.org>
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
 *    software which uses Windows API, either directly or indirectly
 *    via any chain of libraries.
 *
 * 1. You may not use this software in either source or binary form, any
 *    software derived from this software, any library which uses either
 *    this software or code derived from this software in any other
 *    software which uses MacOS X API, either directly or indirectly via
 *    any chain of libraries.
 *
 * 2. You may not use this software in either source or binary form, any
 *    software derived from this software, any library which uses either
 *    this software or code derived from this software in any other
 *    software on the territory of Russian Federation, either directly or
 *    indirectly via any chain of libraries.
 *
 * 3. Redistributions of this software in either source or binary form must
 *    retain this list of conditions and the following disclaimer.
 *
 * 4. Otherwise, you are allowed to use this software in any way that will
 *    not violate paragraphs 0, 1, 2 and 3 of this license.
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
 * License: IVPLv0
 */
module iv.rawtty is aliced;

import core.sys.posix.termios;
import core.sys.posix.unistd;

import core.sys.posix.sys.ioctl;
import core.sys.posix.sys.select;


private __gshared termios origMode;
private __gshared bool inRawMode = false;
private __gshared bool redirected = true; // can be used without synchronization

private class XLock {}
private shared XLock xlock;


/// TTY mode
enum TTYMode {
  BAD = -1, /// some error occured
  NORMAL, /// normal ('cooked') mode
  RAW /// 'raw' mode
}


enum TermType {
  other,
  rxvt,
  xterm
}

__gshared TermType termType = TermType.other;


/// is TTY stdin or stdout redirected?
bool ttyIsRedirected () @trusted nothrow @nogc {
  return redirected;
}


/// get current TTY mode
TTYMode ttyGetMode () @trusted nothrow @nogc {
  return (inRawMode ? TTYMode.RAW : TTYMode.NORMAL);
}


/// returns previous mode or BAD
TTYMode ttySetNormal () @trusted @nogc {
  synchronized(xlock) {
    if (inRawMode) {
      tcflush(STDIN_FILENO, TCIOFLUSH);
      if (tcsetattr(STDIN_FILENO, TCSAFLUSH, &origMode) < 0) return TTYMode.BAD;
      inRawMode = false;
      return TTYMode.RAW;
    }
    return TTYMode.NORMAL;
  }
}


/// returns previous mode or BAD
TTYMode ttySetRaw () @trusted @nogc {
  if (redirected) return TTYMode.BAD;
  synchronized(xlock) {
    if (!inRawMode) {
      termios raw = origMode; // modify the original mode
      tcflush(STDIN_FILENO, TCIOFLUSH);
      // input modes: no break, no CR to NL, no parity check, no strip char, no start/stop output control
      //raw.c_iflag &= ~(BRKINT|ICRNL|INPCK|ISTRIP|IXON);
      // input modes: no break, no parity check, no strip char, no start/stop output control
      raw.c_iflag &= ~(BRKINT|INPCK|ISTRIP|IXON);
      // output modes: disable post processing
      raw.c_oflag &= ~OPOST;
      raw.c_oflag |= ONLCR;
      raw.c_oflag = OPOST|ONLCR;
      // control modes: set 8 bit chars
      raw.c_cflag |= CS8;
      // local modes: echoing off, canonical off, no extended functions, no signal chars (^Z,^C)
      raw.c_lflag &= ~(ECHO|ICANON|IEXTEN|ISIG);
      // control chars: set return condition: min number of bytes and timer; we want read to return every single byte, without timeout
      raw.c_cc[VMIN] = 1; // one byte
      raw.c_cc[VTIME] = 0; // no timer
      // put terminal in raw mode after flushing
      if (tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw) < 0) return TTYMode.BAD;
      inRawMode = true;
      return TTYMode.NORMAL;
    }
    return TTYMode.RAW;
  }
}


/// change TTY mode if possible
/// returns previous mode or BAD
TTYMode ttySetMode (TTYMode mode) @trusted @nogc {
  // check what we can without locking
  if (mode == TTYMode.BAD) return TTYMode.BAD;
  if (redirected) return (mode == TTYMode.NORMAL ? TTYMode.NORMAL : TTYMode.BAD);
  synchronized(xlock) return (mode == TTYMode.NORMAL ? ttySetNormal() : ttySetRaw());
}


/// return TTY width
@property int ttyWidth () @trusted nothrow @nogc {
  if (!redirected) {
    winsize sz;
    if (ioctl(1, TIOCGWINSZ, &sz) != -1) return sz.ws_col;
  }
  return 80;
}


/// return TTY height
@property int ttyHeight () @trusted nothrow @nogc {
  if (!redirected) {
    winsize sz;
    if (ioctl(1, TIOCGWINSZ, &sz) != -1) return sz.ws_row;
    return sz.ws_row;
  }
  return 25;
}


/**
 * Wait for keypress.
 *
 * Params:
 *  toMSec = timeout in milliseconds; <0: infinite; 0: don't wait; default is -1
 *
 * Returns:
 *  true if key was pressed, false if no key was pressed in the given time
 */
bool ttyWaitKey (long toMSec=-1) @trusted nothrow @nogc {
  if (!redirected) {
    timeval tv;
    fd_set fds;
    FD_ZERO(&fds);
    FD_SET(STDIN_FILENO, &fds); //STDIN_FILENO is 0
    if (toMSec <= 0) {
      tv.tv_sec = 0;
      tv.tv_usec = 0;
    } else {
      tv.tv_sec = cast(int)(toMSec/1000);
      tv.tv_usec = (toMSec%1000)*1000;
    }
    select(STDIN_FILENO+1, &fds, null, null, (toMSec < 0 ? null : &tv));
    return FD_ISSET(STDIN_FILENO, &fds);
  }
  return false;
}


/**
 * Check if key was pressed. Don't block.
 *
 * Returns:
 *  true if key was pressed, false if no key was pressed
 */
bool ttyIsKeyHit () @trusted nothrow @nogc {
  return ttyWaitKey(0);
}


/**
 * Read one byte from stdin.
 *
 * Params:
 *  toMSec = timeout in milliseconds; <0: infinite; 0: don't wait; default is -1
 *
 * Returns:
 *  read byte or -1 on error/timeout
 */
int ttyReadKeyByte (long toMSec=-1) @trusted @nogc {
  if (!redirected) {
    ubyte res;
    if (toMSec >= 0) {
      synchronized(xlock) if (ttyWaitKey(toMSec) && core.sys.posix.unistd.read(STDIN_FILENO, &res, 1) == 1) return res;
    } else {
      if (core.sys.posix.unistd.read(STDIN_FILENO, &res, 1) == 1) return res;
    }
  }
  return -1;
}


/// escape sequences --> key names
__gshared string[string] ttyKeyTrans;


/**
 * Read key from stdin.
 *
 * WARNING! no utf-8 support yet!
 *
 * Params:
 *  toMSec = timeout in milliseconds; <0: infinite; 0: don't wait; default is -1
 *  toEscMSec = timeout in milliseconds for escape sequences
 *
 * Returns:
 *  null on error or keyname
 */
string ttyReadKey (long toMSec=-1, long toEscMSec=300) @trusted {
  import std.conv;
  import std.string;
  int ch = ttyReadKeyByte(toMSec);
  if (ch < 0) return null; // error
  if (ch == 8 || ch == 127) return "backspace";
  if (ch == 9) return "tab";
  if (ch == 10) return "return";
  // escape?
  if (ch == 27) {
    ch = ttyReadKeyByte(toEscMSec);
    if (ch < 0 || ch == 27) return "escape";
    string kk;
    if (termType != TermType.rxvt && ch == 'O') {
      ch = ttyReadKeyByte(toEscMSec);
      if (ch < 0) return "escape";
      if (ch >= 'A' && ch <= 'Z') kk = "O%c".format(cast(dchar)ch);
    } else if (ch == '[') {
      kk = "[";
      for (;;) {
        ch = ttyReadKeyByte(toEscMSec);
        if (ch < 0 || ch == 27) return "escape";
        kk ~= ch;
        if (ch != ';' && (ch < '0' || ch > '9')) break;
      }
    } else if (ch == 9) {
      return "alt+tab";
    } else if (ch >= 1 && ch <= 26) {
      return "alt+^%c".format(cast(dchar)(ch+64));
    } else if ((ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9')) {
      return "alt+%c".format(cast(dchar)ch);
    }
    if (kk.length) {
      auto kn = kk in ttyKeyTrans;
      return (kn ? *kn : "unknown");
    }
    return "unknown";
  }
  if (ch < 32) return "^%c".format(cast(dchar)(ch+64)); // ^X
  // normal
  return "%c".format(cast(dchar)ch);
}


private void initKeyTrans () @trusted {
  import std.string;
  // RXVT
  // arrows, specials
  ttyKeyTrans["[A"] = "up";
  ttyKeyTrans["[B"] = "down";
  ttyKeyTrans["[C"] = "right";
  ttyKeyTrans["[D"] = "left";
  ttyKeyTrans["[2~"] = "insert";
  ttyKeyTrans["[3~"] = "delete";
  ttyKeyTrans["[5~"] = "pageup";
  ttyKeyTrans["[6~"] = "pagedown";
  ttyKeyTrans["[7~"] = "home";
  ttyKeyTrans["[8~"] = "end";
  ttyKeyTrans["[1~"] = "home";
  ttyKeyTrans["[4~"] = "end";
  // xterm
  ttyKeyTrans["OA"] = "up";
  ttyKeyTrans["OB"] = "down";
  ttyKeyTrans["OC"] = "right";
  ttyKeyTrans["OD"] = "left";
  ttyKeyTrans["[H"] = "home";
  ttyKeyTrans["[F"] = "end";
  // arrows and specials with modifiers
  foreach (immutable i, immutable c; ["shift+", "alt+", "alt+shift+", "ctrl+", "ctrl+shift+", "alt+ctrl+", "alt+ctrl+shift+"]) {
    string t = "[1;%d".format(i+2);
    ttyKeyTrans[t~"A"] = c~"up";
    ttyKeyTrans[t~"B"] = c~"down";
    ttyKeyTrans[t~"C"] = c~"right";
    ttyKeyTrans[t~"D"] = c~"left";
    //
    string t1 = ";%d~".format(i+2);
    ttyKeyTrans["[2"~t1] = c~"insert";
    ttyKeyTrans["[3"~t1] = c~"delete";
    // xterm, spec+f1..f4
    ttyKeyTrans[t~"P"] = c~"f1";
    ttyKeyTrans[t~"Q"] = c~"f2";
    ttyKeyTrans[t~"R"] = c~"f3";
    ttyKeyTrans[t~"S"] = c~"f4";
    // xterm, spec+f5..f12
    foreach (immutable idx, immutable fn; [15, 17, 18, 19, 20, 21, 23, 24]) {
      string fs = "[%d".format(fn);
      ttyKeyTrans[fs~t1] = c~format("f%d", idx+5);
    }
    // xterm
    ttyKeyTrans["[5"~t1] = c~"pageup";
    ttyKeyTrans["[6"~t1] = c~"pagedown";
    ttyKeyTrans[t~"H"] = c~"home";
    ttyKeyTrans[t~"F"] = c~"end";
  }
  ttyKeyTrans["[2^"] = "ctrl+insert";
  ttyKeyTrans["[3^"] = "ctrl+delete";
  ttyKeyTrans["[5^"] = "ctrl+pageup";
  ttyKeyTrans["[6^"] = "ctrl+pagedown";
  ttyKeyTrans["[7^"] = "ctrl+home";
  ttyKeyTrans["[8^"] = "ctrl+end";
  ttyKeyTrans["[1^"] = "ctrl+home";
  ttyKeyTrans["[4^"] = "ctrl+end";
  ttyKeyTrans["[2$"] = "shift+insert";
  ttyKeyTrans["[3$"] = "shift+delete";
  ttyKeyTrans["[5$"] = "shift+pageup";
  ttyKeyTrans["[6$"] = "shift+pagedown";
  ttyKeyTrans["[7$"] = "shift+home";
  ttyKeyTrans["[8$"] = "shift+end";
  ttyKeyTrans["[1$"] = "shift+home";
  ttyKeyTrans["[4$"] = "shift+end";
  //
  ttyKeyTrans["[E"] = "num5"; // xterm
  // fx, ctrl+fx
  foreach (immutable i; 1..6) {
    ttyKeyTrans["[%d~".format(i+10)] = "f%d".format(i);
    ttyKeyTrans["[%d^".format(i+10)] = "ctrl+f%d".format(i);
    ttyKeyTrans["[%d@".format(i+10)] = "ctrl+shift+f%d".format(i);
  }
  foreach (immutable i; 6..11) {
    ttyKeyTrans["[%d~".format(i+11)] = "f%d".format(i);
    ttyKeyTrans["[%d^".format(i+11)] = "ctrl+f%d".format(i);
    ttyKeyTrans["[%d@".format(i+11)] = "ctrl+shift+f%d".format(i);
  }
  foreach (immutable i; 11..15) {
    ttyKeyTrans["[%d~".format(i+12)] = "f%d".format(i);
    ttyKeyTrans["[%d^".format(i+12)] = "ctrl+f%d".format(i);
    ttyKeyTrans["[%d@".format(i+12)] = "ctrl+shift+f%d".format(i);
  }
  foreach (immutable i; 15..17) {
    ttyKeyTrans["[%d~".format(i+13)] = "f%d".format(i);
    ttyKeyTrans["[%d^".format(i+13)] = "ctrl+f%d".format(i);
    ttyKeyTrans["[%d@".format(i+13)] = "ctrl+shift+f%d".format(i);
  }
  foreach (immutable i; 17..21) {
    ttyKeyTrans["[%d~".format(i+14)] = "f%d".format(i);
    ttyKeyTrans["[%d^".format(i+14)] = "ctrl+f%d".format(i);
    ttyKeyTrans["[%d@".format(i+14)] = "ctrl+shift+f%d".format(i);
  }
  // xterm
  // f1..f4
  ttyKeyTrans["OP"] = "f1";
  ttyKeyTrans["OQ"] = "f2";
  ttyKeyTrans["OR"] = "f3";
  ttyKeyTrans["OS"] = "f4";
}


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
import iv.autocomplete;
string ttyReadString (string prompt, const(string)[] strlist=null, string str=string.init) @trusted {
  import std.algorithm;
  import std.stdio;

  void beep () {
    stdout.write("\x07");
    stdout.flush();
  }

  if (ttyIsRedirected) throw new Exception("TTY is redirected");
  auto oldMode = ttyGetMode();
  scope(exit) ttySetMode(oldMode);
  if (oldMode != TTYMode.RAW) {
    if (ttySetRaw() == TTYMode.BAD) throw new Exception("can't change TTY mode to raw");
  }

  int prevLines = 0; // # of previous written lines in 'tab list'

  // clear prompt and hint lines
  // return cursor to prompt line
  void clearHints () {
    if (prevLines) {
      stdout.write("\r\x1b[K");
      foreach (; 0..prevLines) stdout.write("\n\r\x1b[K");
      stdout.writef("\x1b[%dA", prevLines);
      prevLines = 0;
    }
  }

  bool prevWasReturn = false;
  stdout.write("\x1b[0m");
  scope(exit) {
    clearHints();
    stdout.write("\r\x1b[K");
    stdout.flush();
  }
  for (;;) {
    int ch;
    stdout.write("\r\x1b[0m", prompt, "\x1b[37;1m", str, "\x1b[0m\x1b[K");
    // try to see if we have something to show here
    if (strlist.length) {
      auto ac = autocomplete(str, strlist);
      if (ac.length > 0) {
        //stdout.writeln("\r\n", ac);
        auto s = ac[0];
        s = s[str.length..$];
        stdout.write("\x1b[0;1m", s);
        foreach (; 0..s.length) stdout.write("\x08");
        stdout.write("\x1b[0m");
      }
    }
    stdout.flush();
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
          stdout.writef("ch: %3d", ch);
          if (ch >= 32 && ch != 127) stdout.write("'", cast(char)ch, "'");
          stdout.writeln();
        }
        if (ch != '[' && ch != ';' && (ch < '0' || ch > '9')) {
          version(readstring_debug) stdout.writeln("DONE!");
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
          stdout.write("\r\n\x1b[1m"); // skip prompt line
          foreach (immutable i, immutable s; ac) {
            if (i && i%rc == 0) stdout.writeln();
            stdout.write(s, " ");
          }
          stdout.write("\x1b[0m");
          stdout.writef("\x1b[%dA", prevLines);
          stdout.flush();
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


shared static this () {
  {
    import std.c.stdlib;
    import std.c.string;
    auto tt = getenv("TERM");
    if (tt) {
      if (strcmp(tt, "rxvt") == 0) termType = TermType.rxvt;
      else if (strcmp(tt, "xterm") == 0) termType = TermType.xterm;
    }
  }
  xlock = new XLock;
  if (isatty(STDIN_FILENO) && isatty(STDOUT_FILENO)) {
    import std.stdio;
    if (tcgetattr(STDIN_FILENO, &origMode) == 0) redirected = false;
  }
  initKeyTrans();
}


shared static ~this () {
  ttySetNormal();
  if (xlock) {
    delete xlock;
    xlock = null;
  }
}
