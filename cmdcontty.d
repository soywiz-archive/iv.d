/* coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
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
module iv.cmdcontty is aliced;
private:

public import iv.cmdcon;
import iv.vfs;
import iv.strex;
import iv.rawtty;


// ////////////////////////////////////////////////////////////////////////// //
// public void glconInit (); -- call in `visibleForTheFirstTime`
// public void glconDraw (); -- call in `redrawOpenGlScene` (it tries hard to not modify render modes)
// public bool glconKeyEvent (KeyEvent event); -- returns `true` if event was eaten
// public bool glconCharEvent (dchar ch); -- returns `true` if event was eaten
//
// public bool conProcessQueue (); (from iv.cmdcon)
//   call this in your main loop to process all accumulated console commands.
//   WARNING! this is NOT thread-safe, you MUST call this in your "processing thread", and
//            you MUST put `consoleLock()/consoleUnlock()` around the call!

// ////////////////////////////////////////////////////////////////////////// //
public bool isConsoleVisible () nothrow @trusted @nogc { pragma(inline, true); return rConsoleVisible; } ///
public bool isQuitRequested () nothrow @trusted @nogc { pragma(inline, true); import core.atomic; return atomicLoad(vquitRequested); } ///
public void setQuitRequested () nothrow @trusted @nogc { pragma(inline, true); import core.atomic; atomicStore(vquitRequested, true); } ///


// ////////////////////////////////////////////////////////////////////////// //
/// you may call this manually, but `ttyconEvent()` will do that for you
public void ttyconCharInput (char ch) {
  if (!ch) return;
  consoleLock();
  scope(exit) consoleUnlock();

  if (ch == ConInputChar.PageUp) {
    int lnx = rConsoleHeight-2;
    if (lnx < 1) lnx = 1;
    conskiplines += lnx;
    conLastChange = 0;
    return;
  }

  if (ch == ConInputChar.PageDown) {
    if (conskiplines > 0) {
      int lnx = rConsoleHeight-2;
      if (lnx < 1) lnx = 1;
      if ((conskiplines -= lnx) < 0) conskiplines = 0;
      conLastChange = 0;
    }
    return;
  }

  if (ch == ConInputChar.LineUp) {
    ++conskiplines;
    conLastChange = 0;
    return;
  }

  if (ch == ConInputChar.LineDown) {
    if (conskiplines > 0) {
      --conskiplines;
      conLastChange = 0;
    }
    return;
  }

  if (ch == ConInputChar.Enter) {
    if (conskiplines) { conskiplines = 0; conLastChange = 0; }
    auto s = conInputBuffer;
    if (s.length > 0) {
      concmdAdd(s);
      conInputBufferClear(true); // add to history
      conLastChange = 0;
    }
    return;
  }

  //if (ch == '`' && conInputBuffer.length == 0) { concmd("r_console ona"); return; }

  auto pcc = conInputLastChange();
  conAddInputChar(ch);
  if (pcc != conInputLastChange()) conLastChange = 0;
}


// ////////////////////////////////////////////////////////////////////////// //
__gshared char rPromptChar = '>';
__gshared bool rConsoleVisible = false;
__gshared int rConsoleHeight = 10;
__gshared uint rConTextColor = 0x00ff00; // rgb
__gshared uint rConCursorColor = 0xff7f00; // rgb
__gshared uint rConInputColor = 0xffff00; // rgb
__gshared uint rConPromptColor = 0xffffff; // rgb
__gshared uint rConBackColor = 0x000080; // rgb
shared bool vquitRequested = false;
__gshared char* conOutBuf = null; // tty buffer
__gshared uint conOBPos, conOBSize;
__gshared int conskiplines = 0;


void conOReset () nothrow @trusted @nogc { conOBPos = 0; }

void conOFlush () nothrow @trusted @nogc { if (conOBPos) ttyRawWrite(conOutBuf[0..conOBPos]); conOBPos = 0; }

void conOPut (const(char)[] s...) nothrow @trusted @nogc {
  if (s.length == 0) return;
  if (s.length > 1024*1024) assert(0, "wtf?!");
  if (conOBPos+s.length >= conOBSize) {
    import core.stdc.stdlib : realloc;
    auto nsz = cast(uint)(conOBPos+s.length+8192);
    //if (nsz < conOBSize) assert(0, "wtf?!");
    auto nb = realloc(conOutBuf, nsz);
    if (nb is null) assert(0, "wtf?!");
    conOutBuf = cast(char*)nb;
  }
  conOutBuf[conOBPos..conOBPos+s.length] = s[];
  conOBPos += cast(uint)s.length;
}

void conOInt(T) (T n) nothrow @trusted @nogc if (__traits(isIntegral, T) && !is(T == char) && !is(T == wchar) && !is(T == dchar) && !is(T == bool) && !is(T == enum)) {
  import core.stdc.stdio : snprintf;
  char[64] buf = void;
  static if (__traits(isUnsigned, T)) {
    static if (T.sizeof > 4) {
      auto len = snprintf(buf.ptr, buf.length, "%llu", n);
    } else {
      auto len = snprintf(buf.ptr, buf.length, "%u", cast(uint)n);
    }
  } else {
    static if (T.sizeof > 4) {
      auto len = snprintf(buf.ptr, buf.length, "%lld", n);
    } else {
      auto len = snprintf(buf.ptr, buf.length, "%d", cast(int)n);
    }
  }
  if (len > 0) conOPut(buf[0..len]);
}

void conOColorFG (uint c) nothrow @trusted @nogc {
  conOPut("\x1b[38;5;");
  conOInt(ttyRgb2Color((c>>16)&0xff, (c>>8)&0xff, c&0xff));
  conOPut("m");
}

void conOColorBG (uint c) nothrow @trusted @nogc {
  conOPut("\x1b[48;5;");
  conOInt(ttyRgb2Color((c>>16)&0xff, (c>>8)&0xff, c&0xff));
  conOPut("m");
}


// initialize glcmdcon variables and commands, sets screen size and scale
// NOT THREAD-SAFE! also, should be called only once.
private void initConsole () {
  conRegVar!rConsoleVisible("r_console", "console visibility", ConVarAttr.Archive);
  conRegVar!rConsoleHeight(2, 4096, "r_conheight", "console height", ConVarAttr.Archive);
  conRegVar!rConTextColor("r_contextcolor", "console log text color, 0xrrggbb", ConVarAttr.Archive, ConVarAttr.Hex);
  conRegVar!rConCursorColor("r_concursorcolor", "console cursor color, 0xrrggbb", ConVarAttr.Archive, ConVarAttr.Hex);
  conRegVar!rConInputColor("r_coninputcolor", "console input color, 0xrrggbb", ConVarAttr.Archive, ConVarAttr.Hex);
  conRegVar!rConPromptColor("r_conpromptcolor", "console prompt color, 0xrrggbb", ConVarAttr.Archive, ConVarAttr.Hex);
  conRegVar!rConBackColor("r_conbackcolor", "console background color, 0xrrggbb", ConVarAttr.Archive, ConVarAttr.Hex);
  conRegVar!rPromptChar("r_conpromptchar", "console prompt character", ConVarAttr.Archive);
  conRegFunc!({
    import core.atomic;
    atomicStore(vquitRequested, true);
  })("quit", "quit");
}

shared static this () { initConsole(); }


// ////////////////////////////////////////////////////////////////////////// //
__gshared bool lastWasVisible = false;
__gshared int lastConHgt = 0;
//__gshared ConDump conoldcdump;


/// initialize ttycmdcon. it is ok to call it repeatedly.
/// NOT THREAD-SAFE!
public void ttyconInit () {
  // oops
}


/// render console (if it is visible)
public void ttyconDraw () {
  consoleLock();
  scope(exit) consoleUnlock();

  auto w = ttyWidth;
  auto h = ttyHeight;
  if (w < 4 || h < 2) return;

  if (!rConsoleVisible) {
    //conDump = conoldcdump;
    if (lastWasVisible) {
      conOReset();
      {
        conOPut("\x1b7");
        scope(exit) conOPut("\x1b8");
        conOPut("\x1b[1;1H\x1b[0m");
        if (lastConHgt > h) lastConHgt = h;
        while (lastConHgt-- > 0) {
          if (lastConHgt) conOPut("\r\x1b[B");
          conOPut("\x1b[K");
        }
      }
      conOFlush();
    }
    return;
  }

  //if (!lastWasVisible || conDump != ConDump.none) conoldcdump = conDump;
  //conDump = ConDump.none;

  lastWasVisible = true;
  lastConHgt = rConsoleHeight;
  conLastChange = cbufLastChange+1;

  conOReset();
  renderConsole();
  conOFlush();
}


// ////////////////////////////////////////////////////////////////////////// //
__gshared uint conLastChange = 0;
__gshared uint conLastIBChange = 0;
__gshared int prevCurX = -1;
__gshared int prevIXOfs = 0;


bool renderConsole () nothrow @trusted @nogc {
  if (conLastChange == cbufLastChange && conLastIBChange == conInputLastChange) return false;

  immutable sw = ttyWidth, sh = ttyHeight;
  int skipLines = conskiplines;
  conLastChange = cbufLastChange;
  conLastIBChange = conInputLastChange;

  int y = rConsoleHeight;
  if (y < 1) y = 1;
  if (y > sh) y = sh;

  conOPut("\x1b7");
  scope(exit) conOPut("\x1b8");

  conOPut("\x1b[");
  conOInt(y);
  conOPut(";1H\x1b[0m");

  conOColorBG(rConBackColor);

  auto concli = conInputBuffer;
  int conclilen = cast(int)concli.length;
  int concurx = conInputBufferCurX();

  // draw command line
  {
    int charsInLine = sw-1; // reserve room for cursor
    if (rPromptChar >= ' ') --charsInLine;
    if (charsInLine < 2) charsInLine = 2; // just in case
    int stpos = prevIXOfs;
    if (concurx == conclilen) {
      stpos = conclilen-charsInLine;
      prevCurX = concurx;
    } else if (prevCurX != concurx) {
      // cursor position changed, fix x offset
      if (concurx <= prevIXOfs) {
        stpos = concurx-1;
      } else if (concurx-prevIXOfs >= charsInLine-1) {
        stpos = concurx-charsInLine+1;
      }
    }
    if (stpos < 0) stpos = 0;
    prevCurX = concurx;
    prevIXOfs = stpos;

    if (rPromptChar >= ' ') {
      conOColorFG(rConPromptColor);
      conOPut(rPromptChar);
    }
    conOColorFG(rConInputColor);
    foreach (int pos; stpos..stpos+charsInLine+1) {
      if (pos == concurx) {
        conOColorBG(rConCursorColor);
        conOColorFG(0);
        conOPut(" ");
        conOColorBG(rConBackColor);
        conOColorFG(rConInputColor);
      }
      if (pos >= 0 && pos < conclilen) conOPut(concli.ptr[pos]);
    }
    conOPut("\x1b[K");
    y -= 1;
  }

  // draw console text
  conOColorFG(rConTextColor);
  conOPut("\x1b[K\r\x1b[A");

  void putLine(T) (auto ref T line, usize pos=0) {
    if (y < 1 || pos >= line.length) return;
    int w = 0, lastWordW = -1;
    usize sp = pos, lastWordEnd = 0;
    while (sp < line.length) {
      char ch = line[sp++];
      // remember last word position
      if (/*lastWordW < 0 &&*/ (ch == ' ' || ch == '\t')) {
        lastWordEnd = sp-1; // space will be put on next line (rough indication of line wrapping)
        lastWordW = w;
      }
      if ((w += 1) > sw) {
        w -= 1;
        --sp;
        // current char is non-space, and, previous char is non-space, and we have a complete word?
        if (lastWordW > 0 && ch != ' ' && ch != '\t' && sp > pos && line[sp-1] != ' ' && line[sp-1] != '\t') {
          // yes, split on last word boundary
          sp = lastWordEnd;
        }
        break;
      }
    }
    if (sp < line.length) putLine(line, sp); // recursive put tail
    // draw line
    if (skipLines-- <= 0) {
      while (pos < sp) conOPut(line[pos++]);
      y -= 1;
      if (y >= 1) conOPut("\x1b[K\r\x1b[A");
    }
  }

  foreach (auto line; conbufLinesRev) {
    putLine(line);
    if (y <= 1) break;
  }
  while (y >= 1) {
    conOPut("\x1b[K\r\x1b[A");
    --y;
  }

  return true;
}


// ////////////////////////////////////////////////////////////////////////// //
public __gshared char ttyconShowKey = '`'; /// this key will be eaten


/// process tty event. returns `true` if event was eaten.
public bool ttyconEvent (TtyEvent event) {
  if (!rConsoleVisible) {
    if (event.key == TtyEvent.Key.Char && event.ch == ttyconShowKey) {
      concmd("r_console 1");
      return true;
    }
    return false;
  }

  // console is visible
  if (event.key == TtyEvent.Key.Char && event.ch == ttyconShowKey) {
    if (conInputBuffer.length == 0) concmd("r_console 0");
    return true;
  }

  if (event.key == TtyEvent.Key.Char) {
    if (event == "C-W") { ttyconCharInput(ConInputChar.CtrlW); return true; }
    if (event == "C-Y") { ttyconCharInput(ConInputChar.CtrlY); return true; }
    if (event.ch >= ' ' && event.ch < 127) ttyconCharInput(cast(char)event.ch);
    return true;
  }

  if (event.key == TtyEvent.Key.Escape) { concmd("r_console 0"); return true; }
  switch (event.key) {
    case TtyEvent.Key.Up:
      //if (event.modifierState&ModifierState.alt) ttyconCharInput(ConInputChar.LineUp); else ttyconCharInput(ConInputChar.Up);
      ttyconCharInput(ConInputChar.Up);
      return true;
    case TtyEvent.Key.Down:
      //if (event.modifierState&ModifierState.alt) ttyconCharInput(ConInputChar.LineDown); else ttyconCharInput(ConInputChar.Down);
      ttyconCharInput(ConInputChar.Down);
      return true;
    case TtyEvent.Key.Left: ttyconCharInput(ConInputChar.Left); return true;
    case TtyEvent.Key.Right: ttyconCharInput(ConInputChar.Right); return true;
    case TtyEvent.Key.Home: ttyconCharInput(ConInputChar.Home); return true;
    case TtyEvent.Key.End: ttyconCharInput(ConInputChar.End); return true;
    case TtyEvent.Key.PageUp:
      //if (event.modifierState&ModifierState.alt) ttyconCharInput(ConInputChar.LineUp); else ttyconCharInput(ConInputChar.PageUp);
      ttyconCharInput(ConInputChar.PageUp);
      return true;
    case TtyEvent.Key.PageDown:
      //if (event.modifierState&ModifierState.alt) ttyconCharInput(ConInputChar.LineDown); else ttyconCharInput(ConInputChar.PageDown);
      ttyconCharInput(ConInputChar.PageDown);
      return true;
    case TtyEvent.Key.Backspace: ttyconCharInput(ConInputChar.Backspace); return true;
    case TtyEvent.Key.Tab: ttyconCharInput(ConInputChar.Tab); return true;
    case TtyEvent.Key.Enter: ttyconCharInput(ConInputChar.Enter); return true;
    case TtyEvent.Key.Delete: ttyconCharInput(ConInputChar.Delete); return true;
    case TtyEvent.Key.Insert: ttyconCharInput(ConInputChar.Insert); return true;
    //case TtyEvent.Key.W: if (event.modifierState&ModifierState.ctrl) ttyconCharInput(ConInputChar.CtrlW); return true;
    //case TtyEvent.Key.Y: if (event.modifierState&ModifierState.ctrl) ttyconCharInput(ConInputChar.CtrlY); return true;
    default:
  }
  return true;
}
