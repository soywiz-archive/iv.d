/* Invisible Vector Library
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
// linux tty utilities
module iv.rawtty2;

import core.sys.posix.termios : termios;


// ////////////////////////////////////////////////////////////////////////// //
private __gshared termios origMode;
private __gshared bool redirected = true; // can be used without synchronization
private shared bool inRawMode = false;

private class XLock {}


// ////////////////////////////////////////////////////////////////////////// //
/// TTY mode
enum TTYMode {
  Bad = -1, /// some error occured
  Normal, /// normal ('cooked') mode
  Raw /// 'raw' mode
}


/// Terminal type (yeah, i know alot of 'em)
enum TermType {
  other,
  rxvt,
  xterm
}

__gshared TermType termType = TermType.other; ///


// ////////////////////////////////////////////////////////////////////////// //
/// is TTY stdin or stdout redirected?
@property bool ttyIsRedirected () nothrow @trusted @nogc { pragma(inline, true); return redirected; }


// ////////////////////////////////////////////////////////////////////////// //
/// return TTY width
@property int ttyWidth () nothrow @trusted @nogc {
  if (!redirected) {
    import core.sys.posix.sys.ioctl : ioctl, winsize, TIOCGWINSZ;
    winsize sz = void;
    if (ioctl(1, TIOCGWINSZ, &sz) != -1) return sz.ws_col;
  }
  return 80;
}


/// return TTY height
@property int ttyHeight () nothrow @trusted @nogc {
  if (!redirected) {
    import core.sys.posix.sys.ioctl : ioctl, winsize, TIOCGWINSZ;
    winsize sz = void;
    if (ioctl(1, TIOCGWINSZ, &sz) != -1) return sz.ws_row;
    return sz.ws_row;
  }
  return 25;
}


// ////////////////////////////////////////////////////////////////////////// //
void ttyEnableBracketedPaste () {
  import core.sys.posix.unistd : write;
  enum str = "\x1b[?2004h";
  write(1, str.ptr, str.length);
}


void ttyDisableBracketedPaste () {
  import core.sys.posix.unistd : write;
  enum str = "\x1b[?2004l";
  write(1, str.ptr, str.length);
}


// ////////////////////////////////////////////////////////////////////////// //
/// get current TTY mode
TTYMode ttyGetMode () nothrow @trusted @nogc {
  import core.atomic;
  return (atomicLoad(inRawMode) ? TTYMode.Raw : TTYMode.Normal);
}


/// Restore terminal mode we had at program startup
void ttyRestoreOrigMode () {
  import core.atomic;
  import core.sys.posix.termios : tcflush, tcsetattr;
  import core.sys.posix.termios : TCIOFLUSH, TCSAFLUSH;
  import core.sys.posix.unistd : STDIN_FILENO;
  //tcflush(STDIN_FILENO, TCIOFLUSH);
  tcsetattr(STDIN_FILENO, TCSAFLUSH, &origMode);
  atomicStore(inRawMode, false);
}


/// returns previous mode or Bad
TTYMode ttySetNormal () @trusted @nogc {
  import core.atomic;
  synchronized(XLock.classinfo) {
    if (atomicLoad(inRawMode)) {
      import core.sys.posix.termios : tcflush, tcsetattr;
      import core.sys.posix.termios : TCIOFLUSH, TCSAFLUSH;
      import core.sys.posix.unistd : STDIN_FILENO;
      //tcflush(STDIN_FILENO, TCIOFLUSH);
      if (tcsetattr(STDIN_FILENO, TCSAFLUSH, &origMode) < 0) return TTYMode.Bad;
      atomicStore(inRawMode, false);
      return TTYMode.Raw;
    }
    return TTYMode.Normal;
  }
}


/// returns previous mode or Bad
TTYMode ttySetRaw (bool waitkey=true) @trusted @nogc {
  import core.atomic;
  if (redirected) return TTYMode.Bad;
  synchronized(XLock.classinfo) {
    if (!atomicLoad(inRawMode)) {
      import core.sys.posix.termios : tcflush, tcsetattr;
      import core.sys.posix.termios : TCIOFLUSH, TCSAFLUSH;
      import core.sys.posix.termios : BRKINT, CS8, ECHO, ICANON, IEXTEN, INPCK, ISIG, ISTRIP, IXON, ONLCR, OPOST, VMIN, VTIME;
      import core.sys.posix.unistd : STDIN_FILENO;
      termios raw = origMode; // modify the original mode
      //tcflush(STDIN_FILENO, TCIOFLUSH);
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
      raw.c_cc[VMIN] = (waitkey ? 1 : 0); // wait/poll mode
      raw.c_cc[VTIME] = 0; // no timer
      // put terminal in raw mode after flushing
      if (tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw) < 0) return TTYMode.Bad;
      atomicStore(inRawMode, true);
      return TTYMode.Normal;
    }
    return TTYMode.Raw;
  }
}


/// change TTY mode if possible
/// returns previous mode or Bad
TTYMode ttySetMode (TTYMode mode) @trusted @nogc {
  // check what we can without locking
  if (mode == TTYMode.Bad) return TTYMode.Bad;
  if (redirected) return (mode == TTYMode.Normal ? TTYMode.Normal : TTYMode.Bad);
  synchronized(XLock.classinfo) return (mode == TTYMode.Normal ? ttySetNormal() : ttySetRaw());
}


// ////////////////////////////////////////////////////////////////////////// //
/// set wait/poll mode
bool ttySetWaitKey (bool doWait) @trusted @nogc {
  import core.atomic;
  if (redirected) return false;
  synchronized(XLock.classinfo) {
    if (atomicLoad(inRawMode)) {
      import core.sys.posix.termios : tcflush, tcgetattr, tcsetattr;
      import core.sys.posix.termios : TCIOFLUSH, TCSAFLUSH;
      import core.sys.posix.termios : VMIN;
      import core.sys.posix.unistd : STDIN_FILENO;
      termios raw;
      //tcflush(STDIN_FILENO, TCIOFLUSH);
      if (tcgetattr(STDIN_FILENO, &raw) == 0) redirected = false;
      raw.c_cc[VMIN] = (doWait ? 1 : 0); // wait/poll mode
      if (tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw) < 0) return false;
      return true;
    }
  }
  return false;
}


// ////////////////////////////////////////////////////////////////////////// //
/**
 * Wait for keypress.
 *
 * Params:
 *  toMSec = timeout in milliseconds; <0: infinite; 0: don't wait; default is -1
 *
 * Returns:
 *  true if key was pressed, false if no key was pressed in the given time
 */
bool ttyWaitKey (int toMSec=-1) @trusted @nogc {
  import core.atomic;
  if (!redirected && atomicLoad(inRawMode)) {
    import core.sys.posix.sys.select : fd_set, select, timeval, FD_ISSET, FD_SET, FD_ZERO;
    import core.sys.posix.unistd : STDIN_FILENO;
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
bool ttyIsKeyHit () @trusted @nogc { return ttyWaitKey(0); }


/**
 * Read one byte from stdin.
 *
 * Params:
 *  toMSec = timeout in milliseconds; <0: infinite; 0: don't wait; default is -1
 *
 * Returns:
 *  read byte or -1 on error/timeout
 */
int ttyReadKeyByte (int toMSec=-1) @trusted @nogc {
  import core.atomic;
  if (!redirected && atomicLoad(inRawMode)) {
    import core.sys.posix.unistd : read, STDIN_FILENO;
    ubyte res;
    if (toMSec >= 0) {
      synchronized(XLock.classinfo) if (ttyWaitKey(toMSec) && read(STDIN_FILENO, &res, 1) == 1) return res;
    } else {
      if (read(STDIN_FILENO, &res, 1) == 1) {
        //{ import core.stdc.stdio; if (res > 32 && res != 127) printf("[%c]\n", res); else printf("{%d}\n", res); }
        return res;
      }
    }
  }
  return -1;
}


// ////////////////////////////////////////////////////////////////////////// //
/// pressed key info
public struct TtyKey {
  enum Key {
    None, ///
    Error, /// error reading key
    Unknown, /// can't interpret escape code

    Char, ///
    ModChar, /// char with some modifier

    // for bracketed paste mode
    PasteStart,
    PasteEnd,

    Up, ///
    Down, ///
    Left, ///
    Right, ///
    Insert, ///
    Delete, ///
    PageUp, ///
    PageDown, ///
    Home, ///
    End, ///

    Escape, ///
    Backspace, ///
    Tab, ///
    Enter, ///

    Pad5, /// xterm can return this

    F1, ///
    F2, ///
    F3, ///
    F4, ///
    F5, ///
    F6, ///
    F7, ///
    F8, ///
    F9, ///
    F10, ///
    F11, ///
    F12, ///

    //A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q, R, S, T, U, V, W, X, Y, Z,
    //N0, N1, N2, N3, N4, N5, N6, N7, N8, N9,
  }

  Key key; ///
  bool alt, ctrl, shift; /// for special keys
  dchar ch = 0; /// can be 0 for special key
}


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
TtyKey ttyReadKey (int toMSec=-1, int toEscMSec=-1/*300*/) @trusted @nogc {
  TtyKey key;

  void skipCSI () {
    key.key = TtyKey.Key.Unknown;
    for (;;) {
      auto ch = ttyReadKeyByte(toEscMSec);
      if (ch < 0 || ch == 27) { key.key = TtyKey.Key.Escape; key.ch = 27; break; }
      if (ch != ';' && (ch < '0' || ch > '9')) break;
    }
  }

  bool xtermMods (uint mci) {
    switch (mci) {
      case 2: key.shift = true; return true;
      case 3: key.alt = true; return true;
      case 4: key.alt = true; key.shift = true; return true;
      case 5: key.ctrl = true; return true;
      case 6: key.ctrl = true; key.shift = true; return true;
      case 7: key.alt = true; key.ctrl = true; return true;
      case 8: key.alt = true; key.ctrl = true; key.shift = true; return true;
      default:
    }
    return false;
  }

  void badCSI () {
    key = key.init;
    key.key = TtyKey.Key.Unknown;
  }

  void csiSpecial (uint n) {
    switch (n) {
      case 1: key.key = TtyKey.Key.Home; return;
      case 2: key.key = TtyKey.Key.Insert; return;
      case 3: key.key = TtyKey.Key.Delete; return;
      case 4: key.key = TtyKey.Key.End; return;
      case 5: key.key = TtyKey.Key.PageUp; return;
      case 6: key.key = TtyKey.Key.PageDown; return;
      case 7: key.key = TtyKey.Key.Home; return;
      case 8: key.key = TtyKey.Key.End; return;
      case 1+10: key.key = TtyKey.Key.F1; return;
      case 2+10: key.key = TtyKey.Key.F2; return;
      case 3+10: key.key = TtyKey.Key.F3; return;
      case 4+10: key.key = TtyKey.Key.F4; return;
      case 5+10: key.key = TtyKey.Key.F5; return;
      case 6+11: key.key = TtyKey.Key.F6; return;
      case 7+11: key.key = TtyKey.Key.F7; return;
      case 8+11: key.key = TtyKey.Key.F8; return;
      case 9+11: key.key = TtyKey.Key.F9; return;
      case 10+11: key.key = TtyKey.Key.F10; return;
      case 11+12: key.key = TtyKey.Key.F11; return;
      case 12+12: key.key = TtyKey.Key.F12; return;
      default: badCSI(); break;
    }
  }

  void xtermSpecial (char ch) {
    switch (ch) {
      case 'A': key.key = TtyKey.Key.Up; break;
      case 'B': key.key = TtyKey.Key.Down; break;
      case 'C': key.key = TtyKey.Key.Right; break;
      case 'D': key.key = TtyKey.Key.Left; break;
      case 'E': key.key = TtyKey.Key.Pad5; break;
      case 'H': key.key = TtyKey.Key.Home; break;
      case 'F': key.key = TtyKey.Key.End; break;
      case 'P': key.key = TtyKey.Key.F1; break;
      case 'Q': key.key = TtyKey.Key.F2; break;
      case 'R': key.key = TtyKey.Key.F3; break;
      case 'S': key.key = TtyKey.Key.F4; break;
      default: badCSI(); break;
    }
  }

  int ch = ttyReadKeyByte(toMSec);
  if (ch < 0) { key.key = TtyKey.Key.Error; return key; } // error
  if (ch == 0) { key.key = TtyKey.Key.ModChar; key.alt = true; key.ch = '`'; return key; }
  if (ch == 8 || ch == 127) { key.key = TtyKey.Key.Backspace; key.ch = 8; return key; }
  if (ch == 9) { key.key = TtyKey.Key.Tab; key.ch = 9; return key; }
  if (ch == 10) { key.key = TtyKey.Key.Enter; key.ch = 13; return key; }

  key.key = TtyKey.Key.Unknown;

  // escape?
  if (ch == 27) {
    ch = ttyReadKeyByte(toEscMSec);
    if (ch < 0 || ch == 27) { key.key = TtyKey.Key.Escape; key.ch = 27; return key; }
    // xterm stupidity
    if (termType != TermType.rxvt && ch == 'O') {
      ch = ttyReadKeyByte(toEscMSec);
      if (ch < 0 || ch == 27) { key.key = TtyKey.Key.Escape; key.ch = 27; return key; }
      if (ch >= 'A' && ch <= 'Z') xtermSpecial(cast(char)ch);
      return key;
    }
    // csi
    if (ch == '[') {
      uint[2] nn;
      uint nc = 0;
      bool wasDigit = false;
      // parse csi
      for (;;) {
        ch = ttyReadKeyByte(toEscMSec);
        if (ch < 0 || ch == 27) { key.key = TtyKey.Key.Escape; key.ch = 27; return key; }
        if (ch == ';') {
          ++nc;
          if (nc > nn.length) { skipCSI(); return key; }
        } else if (ch >= '0' && ch <= '9') {
          if (nc >= nn.length) { skipCSI(); return key; }
          nn.ptr[nc] = nn.ptr[nc]*10+ch-'0';
          wasDigit = true;
        } else {
          if (wasDigit) ++nc;
          break;
        }
      }
      //{ import core.stdc.stdio : printf; printf("nc=%u", nc); foreach (uint idx; 0..nc) printf("; n%u=%u", idx, nn.ptr[idx]); printf("; ch=%c\n", ch); }
      // process specials
      if (nc == 0) {
        if (ch >= 'A' && ch <= 'Z') xtermSpecial(cast(char)ch);
        switch (ch) {
          case 'A': key.key = TtyKey.Key.Up; return key;
          case 'B': key.key = TtyKey.Key.Down; return key;
          case 'C': key.key = TtyKey.Key.Right; return key;
          case 'D': key.key = TtyKey.Key.Left; return key;
          case 'E': key.key = TtyKey.Key.Pad5; return key;
          case 'H': key.key = TtyKey.Key.Home; return key;
          case 'F': key.key = TtyKey.Key.End; return key;
          case 'P': key.key = TtyKey.Key.F1; break;
          case 'Q': key.key = TtyKey.Key.F2; break;
          case 'R': key.key = TtyKey.Key.F3; break;
          case 'S': key.key = TtyKey.Key.F4; break;
          default:
        }
        badCSI();
      } else if (nc == 1) {
        if (ch == '~' && nn.ptr[0] == 200) { key.key = TtyKey.Key.PasteStart; return key; }
        if (ch == '~' && nn.ptr[0] == 201) { key.key = TtyKey.Key.PasteEnd; return key; }
        switch (ch) {
          case '~':
            switch (nn.ptr[0]) {
              case 23: key.shift = true; key.key = TtyKey.Key.F1; return key;
              case 24: key.shift = true; key.key = TtyKey.Key.F2; return key;
              case 25: key.shift = true; key.key = TtyKey.Key.F3; return key;
              case 26: key.shift = true; key.key = TtyKey.Key.F4; return key;
              case 28: key.shift = true; key.key = TtyKey.Key.F5; return key;
              case 29: key.shift = true; key.key = TtyKey.Key.F6; return key;
              case 31: key.shift = true; key.key = TtyKey.Key.F7; return key;
              case 32: key.shift = true; key.key = TtyKey.Key.F8; return key;
              case 33: key.shift = true; key.key = TtyKey.Key.F9; return key;
              case 34: key.shift = true; key.key = TtyKey.Key.F10; return key;
              default:
            }
            break;
          case '^': key.ctrl = true; break;
          case '$': key.shift = true; break;
          case '@': key.ctrl = true; key.shift = true; break;
          case 'A': .. case 'Z': xtermMods(nn.ptr[0]); xtermSpecial(cast(char)ch); return key;
          default: badCSI(); return key;
        }
        csiSpecial(nn.ptr[0]);
      } else if (nc == 2 && xtermMods(nn.ptr[1])) {
        if (nn.ptr[0] == 1 && ch >= 'A' && ch <= 'Z') {
          xtermSpecial(cast(char)ch);
        } else if (ch == '~') {
          csiSpecial(nn.ptr[0]);
        }
      } else {
        badCSI();
      }
      return key;
    }
    if (ch == 9) {
      key.key = TtyKey.Key.Tab;
      key.alt = true;
      key.ch = 9;
      return key;
    }
    if (ch >= 1 && ch <= 26) {
      key.key = TtyKey.Key.ModChar;
      key.alt = true;
      key.ch = cast(dchar)(ch+64);
           if (key.ch == 'H') { key.key = TtyKey.Key.Backspace; key.ch = 8; }
      else if (key.ch == 'J') { key.key = TtyKey.Key.Enter; key.ch = 13; }
      return key;
    }
    if ((ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9') || ch == '_') {
      key.alt = true;
      key.key = TtyKey.Key.ModChar;
      key.shift = (ch >= 'A' && ch <= 'Z'); // ignore capslock
      if (ch >= 'a' && ch <= 'z') ch -= 32;
      key.ch = cast(dchar)ch;
      return key;
    }
    return key;
  }

  if (ch < 32) {
    // ctrl+letter
    key.key = TtyKey.Key.ModChar;
    key.ctrl = true;
    key.ch = cast(dchar)(ch+64);
  } else {
    key.key = TtyKey.Key.Char;
    key.ch = cast(dchar)(ch);
    // xterm does alt+letter with 7th bit set
    if (termType == TermType.xterm && ch >= 0x80 && ch <= 0xff) {
      ch -= 0x80;
      if ((ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9') || ch == '_') {
        key.alt = true;
        key.key = TtyKey.Key.ModChar;
        key.shift = (ch >= 'A' && ch <= 'Z'); // ignore capslock
        if (ch >= 'a' && ch <= 'z') ch -= 32;
        key.ch = cast(dchar)ch;
        return key;
      }
    }
  }
  return key;
}


// ////////////////////////////////////////////////////////////////////////// //
// housekeeping
private extern(C) void ttyExitRestore () {
  import core.atomic;
  if (atomicLoad(inRawMode)) {
    import core.sys.posix.termios : tcflush, tcsetattr;
    import core.sys.posix.termios : TCIOFLUSH, TCSAFLUSH;
    import core.sys.posix.unistd : STDIN_FILENO;
    //tcflush(STDIN_FILENO, TCIOFLUSH);
    tcsetattr(STDIN_FILENO, TCSAFLUSH, &origMode);
  }
}

shared static this () {
  {
    import core.stdc.stdlib : atexit;
    atexit(&ttyExitRestore);
  }
  {
    import core.stdc.stdlib : getenv;
    import core.stdc.string : strcmp;
    auto tt = getenv("TERM");
    if (tt !is null) {
      auto len = 0;
      while (len < 5 && tt[len]) ++len;
           if (len >= 4 && tt[0..4] == "rxvt") termType = TermType.rxvt;
      else if (len >= 5 && tt[0..5] == "xterm") termType = TermType.xterm;
    }
  }
  {
    import core.sys.posix.unistd : isatty, STDIN_FILENO, STDOUT_FILENO;
    import core.sys.posix.termios : tcgetattr;
    if (isatty(STDIN_FILENO) && isatty(STDOUT_FILENO)) {
      if (tcgetattr(STDIN_FILENO, &origMode) == 0) redirected = false;
    }
  }
}


shared static ~this () {
  ttySetNormal();
}


// ////////////////////////////////////////////////////////////////////////// //
/// k8sterm color table, lol
static immutable uint[256] ttyRGB = {
  uint[256] res;
  // standard terminal colors
  res[0] = 0x000000;
  res[1] = 0xb21818;
  res[2] = 0x18b218;
  res[3] = 0xb26818;
  res[4] = 0x1818b2;
  res[5] = 0xb218b2;
  res[6] = 0x18b2b2;
  res[7] = 0xb2b2b2;
  res[8] = 0x686868;
  res[9] = 0xff5454;
  res[10] = 0x54ff54;
  res[11] = 0xffff54;
  res[12] = 0x5454ff;
  res[13] = 0xff54ff;
  res[14] = 0x54ffff;
  res[15] = 0xffffff;
  // rgb colors [16..231]
  int f = 16;
  foreach (ubyte r; 0..6) {
    foreach (ubyte g; 0..6) {
      foreach (ubyte b; 0..6) {
        uint cr = (r == 0 ? 0 : 0x37+0x28*r); assert(cr <= 255);
        uint cg = (g == 0 ? 0 : 0x37+0x28*g); assert(cg <= 255);
        uint cb = (b == 0 ? 0 : 0x37+0x28*b); assert(cb <= 255);
        res[f++] = (cr<<16)|(cg<<8)|cb;
      }
    }
  }
  assert(f == 232);
  // b/w shades [232..255]
  foreach (ubyte n; 0..24) {
    uint c = 0x08+0x0a*n; assert(c <= 255);
    res[f++] = (c<<16)|(c<<8)|c;
  }
  assert(f == 256);
  return res;
}();


/// Convert 256-color terminal color number to approximate rgb values
void ttyColor2rgb (ubyte cnum, out ubyte r, out ubyte g, out ubyte b) pure nothrow @trusted @nogc {
  pragma(inline, true);
  r = cast(ubyte)(ttyRGB.ptr[cnum]>>16);
  g = cast(ubyte)(ttyRGB.ptr[cnum]>>8);
  b = cast(ubyte)(ttyRGB.ptr[cnum]);
  /*
  if (cnum == 0) {
    r = g = b = 0;
  } else if (cnum == 8) {
    r = g = b = 0x80;
  } else if (cnum >= 0 && cnum < 16) {
    r = (cnum&(1<<0) ? (cnum&(1<<3) ? 0xff : 0x80) : 0x00);
    g = (cnum&(1<<1) ? (cnum&(1<<3) ? 0xff : 0x80) : 0x00);
    b = (cnum&(1<<2) ? (cnum&(1<<3) ? 0xff : 0x80) : 0x00);
  } else if (cnum >= 16 && cnum < 232) {
    // [0..5] -> [0..255]
    b = cast(ubyte)(((cnum-16)%6)*51);
    g = cast(ubyte)((((cnum-16)/6)%6)*51);
    r = cast(ubyte)((((cnum-16)/6/6)%6)*51);
  } else if (cnum >= 232 && cnum <= 255) {
    // [0..23] (0 is very dark gray; 23 is *almost* white)
    b = g = r = cast(ubyte)(8+(cnum-232)*10);
  }
  */
}


/// Convert rgb values to approximate 256-color (or 16-color) teminal color number
ubyte ttyRgb2Color(bool allow256=true) (ubyte r, ubyte g, ubyte b) pure nothrow @trusted @nogc {
  // use standard (weighted) color distance function to find the closest match
  // d = ((r2-r1)*0.30)^^2+((g2-g1)*0.59)^^2+((b2-b1)*0.11)^^2
  enum n = 16384; // scale
  enum m0 = 4916; // 0.30*16384
  enum m1 = 9666; // 0.59*16384
  enum m2 = 1802; // 0.11*16384
  long dist = long.max;
  ubyte resclr = 0;
  static if (allow256) enum lastc = 256; else enum lastc = 16;
  foreach (immutable idx, uint cc; ttyRGB[0..lastc]) {
    long dr = cast(int)((cc>>16)&0xff)-cast(int)r;
    dr = ((dr*m0)*(dr*m0))/n;
    assert(dr >= 0);
    long dg = cast(int)((cc>>8)&0xff)-cast(int)g;
    dg = ((dg*m1)*(dg*m1))/n;
    assert(dg >= 0);
    long db = cast(int)(cc&0xff)-cast(int)b;
    db = ((db*m2)*(db*m2))/n;
    assert(db >= 0);
    long d = dr+dg+db;
    assert(d >= 0);
    if (d < dist) {
      resclr = cast(ubyte)idx;
      dist = d;
    }
  }
  return resclr;
}
