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

private __gshared termios origMode;
private __gshared bool redirected = true; // can be used without synchronization
private shared bool inRawMode = false;

private class XLock {}


/// TTY mode
enum TTYMode {
  Bad = -1, /// some error occured
  Normal, /// normal ('cooked') mode
  Raw /// 'raw' mode
}


enum TermType {
  other,
  rxvt,
  xterm
}

__gshared TermType termType = TermType.other;


/// is TTY stdin or stdout redirected?
@property bool ttyIsRedirected () nothrow @trusted @nogc { pragma(inline, true); return redirected; }

/// get current TTY mode
TTYMode ttyGetMode () nothrow @trusted @nogc {
  import core.atomic;
  return (atomicLoad(inRawMode) ? TTYMode.Raw : TTYMode.Normal);
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


/// change TTY mode if possible
/// returns previous mode or Bad
TTYMode ttySetMode (TTYMode mode) @trusted @nogc {
  // check what we can without locking
  if (mode == TTYMode.Bad) return TTYMode.Bad;
  if (redirected) return (mode == TTYMode.Normal ? TTYMode.Normal : TTYMode.Bad);
  synchronized(XLock.classinfo) return (mode == TTYMode.Normal ? ttySetNormal() : ttySetRaw());
}


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
bool ttyIsKeyHit () @trusted @nogc {
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
int ttyReadKeyByte (int toMSec=-1) @trusted @nogc {
  import core.atomic;
  if (!redirected && atomicLoad(inRawMode)) {
    import core.sys.posix.unistd : read, STDIN_FILENO;
    ubyte res;
    if (toMSec >= 0) {
      synchronized(XLock.classinfo) if (ttyWaitKey(toMSec) && read(STDIN_FILENO, &res, 1) == 1) return res;
    } else {
      if (read(STDIN_FILENO, &res, 1) == 1) return res;
    }
  }
  return -1;
}


/// pressed key info
public struct TtyKey {
  enum Key {
    None, ///
    Error, /// error reading key
    Unknown, /// can't interpret escape code

    Char, ///
    ModChar, /// char with some modifier

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
  }

  Key key; ///
  bool alt, ctrl, shift; /// for special keys
  dchar ch; /// can be 0 for special key
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
TtyKey ttyReadKey (int toMSec=-1, int toEscMSec=300) @trusted @nogc {
  TtyKey key;
  int ch = ttyReadKeyByte(toMSec);
  if (ch < 0) { key.key = TtyKey.Key.Error; return key; } // error
  if (ch == 0) { key.key = TtyKey.Key.ModChar; key.alt = true; key.ch = '`'; return key; }
  if (ch == 8 || ch == 127) { key.key = TtyKey.Key.Backspace; return key; }
  if (ch == 9) { key.key = TtyKey.Key.Tab; return key; }
  if (ch == 10) { key.key = TtyKey.Key.Enter; return key; }
  // escape?
  if (ch == 27) {
    char[64] kkk;
    uint kkpos;

    void put (const(char)[] s...) nothrow @trusted @nogc {
      foreach (char ch; s) if (kkpos < kkk.length) kkk.ptr[kkpos++] = ch;
    }

    ch = ttyReadKeyByte(toEscMSec);
    if (ch < 0 || ch == 27) { key.key = TtyKey.Key.Escape; return key; }

    if (termType != TermType.rxvt && ch == 'O') {
      put('O');
      ch = ttyReadKeyByte(toEscMSec);
      if (ch < 0 || ch == 27) { key.key = TtyKey.Key.Escape; return key; }
      if (ch >= 'A' && ch <= 'Z') put(cast(char)ch);
    } else if (ch == '[') {
      put('[');
      for (;;) {
        ch = ttyReadKeyByte(toEscMSec);
        if (ch < 0 || ch == 27) { key.key = TtyKey.Key.Escape; return key; }
        put(cast(char)ch);
        if (ch != ';' && (ch < '0' || ch > '9')) break;
      }
    } else if (ch == 9) {
      key.key = TtyKey.Key.Tab;
      key.alt = true;
      key.ch = 9;
      return key;
    } else if (ch >= 1 && ch <= 26) {
      key.key = TtyKey.Key.ModChar;
      key.alt = true;
      key.ch = cast(dchar)(ch+64);
      return key;
    } else if ((ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9')) {
      key.key = TtyKey.Key.ModChar;
      key.alt = true;
      key.shift = (ch >= 'A' && ch <= 'Z'); // ignore capslock
      key.ch = cast(dchar)ch;
      return key;
    }
    return translateKey(kkk[0..kkpos]);
  }
  if (ch < 32) {
    // ctrl+letter
    key.key = TtyKey.Key.ModChar;
    key.ctrl = true;
    key.ch = cast(dchar)(ch+64);
  } else {
    key.key = TtyKey.Key.Char;
    key.ch = cast(dchar)(ch);
  }
  return key;
}


private TtyKey translateKey (const(char)[] kn) nothrow @trusted @nogc {
  TtyKey key;
  key.key = TtyKey.Key.Unknown;

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

  if (kn.length == 0) return key;
  if (kn.ptr[0] == 'O') {
    if (kn.length != 2) return key;
    switch (kn.ptr[1]) {
      case 'A': key.key = TtyKey.Key.Up; return key;
      case 'B': key.key = TtyKey.Key.Down; return key;
      case 'C': key.key = TtyKey.Key.Right; return key;
      case 'D': key.key = TtyKey.Key.Left; return key;
      case 'P': key.key = TtyKey.Key.F1; return key;
      case 'Q': key.key = TtyKey.Key.F2; return key;
      case 'R': key.key = TtyKey.Key.F3; return key;
      case 'S': key.key = TtyKey.Key.F4; return key;
      default:
    }
    return key;
  }
  if (kn.ptr[0] != '[') return key;

  switch (kn) {
    // rxvt
    case "[A": key.key = TtyKey.Key.Up; return key;
    case "[B": key.key = TtyKey.Key.Down; return key;
    case "[C": key.key = TtyKey.Key.Right; return key;
    case "[D": key.key = TtyKey.Key.Left; return key;
    case "[2~": key.key = TtyKey.Key.Insert; return key;
    case "[3~": key.key = TtyKey.Key.Delete; return key;
    case "[5~": key.key = TtyKey.Key.PageUp; return key;
    case "[6~": key.key = TtyKey.Key.PageDown; return key;
    case "[7~": key.key = TtyKey.Key.Home; return key;
    case "[8~": key.key = TtyKey.Key.End; return key;
    case "[1~": key.key = TtyKey.Key.Home; return key;
    case "[4~": key.key = TtyKey.Key.End; return key;
    // xterm
    case "[2^": key.ctrl = true; key.key = TtyKey.Key.Insert; return key;
    case "[3^": key.ctrl = true; key.key = TtyKey.Key.Delete; return key;
    case "[5^": key.ctrl = true; key.key = TtyKey.Key.PageUp; return key;
    case "[6^": key.ctrl = true; key.key = TtyKey.Key.PageDown; return key;
    case "[7^": key.ctrl = true; key.key = TtyKey.Key.Home; return key;
    case "[8^": key.ctrl = true; key.key = TtyKey.Key.End; return key;
    case "[1^": key.ctrl = true; key.key = TtyKey.Key.Home; return key;
    case "[4^": key.ctrl = true; key.key = TtyKey.Key.End; return key;
    case "[H": key.key = TtyKey.Key.Home; return key;
    case "[F": key.key = TtyKey.Key.End; return key;
    case "[E": key.key = TtyKey.Key.Pad5; return key;
    case "[2$": key.shift = true; key.key = TtyKey.Key.Insert; return key;
    case "[3$": key.shift = true; key.key = TtyKey.Key.Delete; return key;
    case "[5$": key.shift = true; key.key = TtyKey.Key.PageUp; return key;
    case "[6$": key.shift = true; key.key = TtyKey.Key.PageDown; return key;
    case "[7$": key.shift = true; key.key = TtyKey.Key.Home; return key;
    case "[8$": key.shift = true; key.key = TtyKey.Key.End; return key;
    case "[1$": key.shift = true; key.key = TtyKey.Key.Home; return key;
    case "[4$": key.shift = true; key.key = TtyKey.Key.End; return key;
    default:
  }
  if (kn.length > 3 && kn[0..3] == "[1;") {
    // try special modifiers
    kn = kn[3..$];
    uint mci;
    while (kn.length && kn.ptr[0] >= '0' && kn.ptr[0] <= '9') {
      mci = mci*10+kn.ptr[0]-'0';
      kn = kn[1..$];
    }
    if (kn.length == 1 && xtermMods(mci)) {
      switch (kn.ptr[0]) {
        case 'A': key.key = TtyKey.Key.Up; return key;
        case 'B': key.key = TtyKey.Key.Down; return key;
        case 'C': key.key = TtyKey.Key.Right; return key;
        case 'D': key.key = TtyKey.Key.Left; return key;
        case 'H': key.key = TtyKey.Key.Home; return key;
        case 'F': key.key = TtyKey.Key.End; return key;
        case 'P': key.key = TtyKey.Key.F1; return key;
        case 'Q': key.key = TtyKey.Key.F2; return key;
        case 'R': key.key = TtyKey.Key.F3; return key;
        case 'S': key.key = TtyKey.Key.F4; return key;
        default:
      }
    }
  } else {
    if (kn.length < 2 || kn.ptr[0] != '[' || kn.ptr[1] < '0' || kn.ptr[1] > '9') return key;
    kn = kn[1..$];
    uint n0, n1;
    while (kn.length && kn.ptr[0] >= '0' && kn.ptr[0] <= '9') {
      n0 = n0*10+kn.ptr[0]-'0';
      kn = kn[1..$];
    }
    if (kn.length == 0) return key;
    if (kn.ptr[0] == ';') {
      // two nums
      if (kn.length < 2 || kn.ptr[1] < '0' || kn.ptr[1] > '9') return key;
      kn = kn[2..$];
      while (kn.length && kn.ptr[0] >= '0' && kn.ptr[0] <= '9') {
        n1 = n1*10+kn.ptr[0]-'0';
        kn = kn[1..$];
      }
      if (kn == "~" && xtermMods(n1)) {
        switch (n0) {
          case 2: key.key = TtyKey.Key.Insert; return key;
          case 3: key.key = TtyKey.Key.Delete; return key;
          case 5: key.key = TtyKey.Key.PageUp; return key;
          case 6: key.key = TtyKey.Key.PageDown; return key;
          case 15: key.key = TtyKey.Key.F5; return key;
          case 17: key.key = TtyKey.Key.F6; return key;
          case 18: key.key = TtyKey.Key.F7; return key;
          case 19: key.key = TtyKey.Key.F8; return key;
          case 20: key.key = TtyKey.Key.F9; return key;
          case 21: key.key = TtyKey.Key.F10; return key;
          case 23: key.key = TtyKey.Key.F11; return key;
          case 24: key.key = TtyKey.Key.F12; return key;
          default:
        }
      }
    } else {
      // one num
      if (kn.length != 1) return key;
      switch (kn.ptr[0]) {
        case '~': break;
        case '^': key.ctrl = true; break;
        case '@': key.ctrl = true; key.shift = true; break;
        default: return key;
      }
      if (n0 >= 1+10 && n0 < 6+10) { key.key = cast(TtyKey.Key)(TtyKey.Key.F1+n0-10); return key; }
      if (n0 >= 6+11 && n0 < 11+11) { key.key = cast(TtyKey.Key)(TtyKey.Key.F6+n0-(6+11)); return key; }
      if (n0 == 11+12) { key.key = TtyKey.Key.F12; return key; }
    }
  }
  key = TtyKey.init;
  key.key = TtyKey.Key.Unknown;
  return key;
}


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
