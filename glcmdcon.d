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
module iv.glcmdcon is aliced;
private:

//import arsd.color;
//import arsd.simpledisplay;

public import iv.cmdcon;
public import iv.vfs;
import iv.glbinds;

static if (__traits(compiles, (){import arsd.simpledisplay;}())) {
  enum OptGlCmdConHasSdpy = true;
} else {
  enum OptGlCmdConHasSdpy = false;
}


// ////////////////////////////////////////////////////////////////////////// //
__gshared uint winScale = 0;
__gshared uint scrwdt, scrhgt;


// ////////////////////////////////////////////////////////////////////////// //
public VFile openFileEx (const(char)[] name) {
  VFSDriverId[128] dids;
  int didcount;
  scope(exit) foreach_reverse (VFSDriverId did; dids[0..didcount]) vfsRemovePack(did);

  if (name.length >= int.max/4) throw new VFSException("name too long");
  int cp = 0;
  while (cp < name.length) {
    auto ep = cp;
    while (ep < name.length && name[ep] != ':') ++ep;
    if (ep >= name.length) return VFile(name);
    //{ writeln("pak: '", name[0..ep], "'; prefix: '", name[0..ep+1], "'"); }
    vfsAddPak(name[0..ep], name[0..ep+1]);
    /*
    vfsForEachFile((in ref VFSDriver.DirEntry de) {
      writeln("  ", de.name);
      return 0;
    });
    */
    cp = ep+1;
  }
  throw new VFSException("empty name");
}


// ////////////////////////////////////////////////////////////////////////// //
// public void initConsole (uint ascrwdt, uint ascrhgt, uint ascale=1); -- call at startup
// public void oglInitConsole (); -- call in `visibleForTheFirstTime`
// public void oglDrawConsole (); -- call in `redrawOpenGlScene` (it should not modify render modes)
// public bool conKeyEvent (KeyEvent event); -- returns `true` if event was eaten
// public bool conCharEvent (dchar ch); -- returns `true` if event was eaten
//
// public void concmdDoAll ();
//   call this in your main loop to process all accumulated console commands.
//   WARNING! this is NOT thread-safe, you MUST call this in your "processing thread", and
//            you MUST put `consoleLock()/consoleUnlock()` around the call!

// ////////////////////////////////////////////////////////////////////////// //
public bool isConsoleVisible () nothrow @trusted @nogc { pragma(inline, true); return rConsoleVisible; }
public bool isQuitRequested () nothrow @trusted @nogc { pragma(inline, true); import core.atomic; return atomicLoad(vquitRequested); }


// ////////////////////////////////////////////////////////////////////////// //
// add console command to execution queue
public void concmd (const(char)[] cmd) {
  //if (!atomicLoad(renderThreadStarted)) return;
  consoleLock();
  scope(exit) consoleUnlock();
  concmdAdd(cmd);
}

// get console variable value; doesn't do complex conversions!
public T convar(T) (const(char)[] s) {
  consoleLock();
  scope(exit) consoleUnlock();
  return conGetVar!T(s);
}

// set console variable value; doesn't do complex conversions!
public void convar(T) (const(char)[] s, T val) {
  consoleLock();
  scope(exit) consoleUnlock();
  conSetVar!T(s, val);
}


// ////////////////////////////////////////////////////////////////////////// //
// you may call this in char event, but `conCharEvent()` will do that for you
public void concliChar (char ch) {
  if (!ch) return;
  consoleLock();
  scope(exit) consoleUnlock();

  if (ch == ConInputChar.PageUp) {
    int lnx = rConsoleHeight/conCharHeight-2;
    if (lnx < 1) lnx = 1;
    conskiplines += lnx;
    conLastChange = 0;
    return;
  }

  if (ch == ConInputChar.PageDown) {
    if (conskiplines > 0) {
      int lnx = rConsoleHeight/conCharHeight-2;
      if (lnx < 1) lnx = 1;
      if ((conskiplines -= lnx) < 0) conskiplines = 0;
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

  if (ch == '`' && conInputBuffer.length == 0) { concmd("r_console ona"); return; }

  auto pcc = conInputLastChange();
  conAddInputChar(ch);
  if (pcc != conInputLastChange()) conLastChange = 0;
}


// ////////////////////////////////////////////////////////////////////////// //
__gshared char[] concmdbuf;
__gshared uint concmdbufpos;
shared static this () { concmdbuf.length = 65536; }

__gshared int conskiplines = 0;


void concmdAdd (const(char)[] s) {
  if (s.length) {
    if (concmdbuf.length-concmdbufpos < s.length+1) {
      concmdbuf.assumeSafeAppend.length += s.length-(concmdbuf.length-concmdbufpos)+512;
    }
    if (concmdbufpos > 0 && concmdbuf[concmdbufpos-1] != '\n') concmdbuf.ptr[concmdbufpos++] = '\n';
    concmdbuf[concmdbufpos..concmdbufpos+s.length] = s[];
    concmdbufpos += s.length;
  }
}


//FIXME! multithreading!
// all new commands will be postponed for the next call
public void concmdDoAll () {
  if (concmdbufpos == 0) return;
  auto ebuf = concmdbufpos;
  const(char)[] s = concmdbuf[0..ebuf];
  while (s.length) {
    auto cmd = conGetCommandStr(s);
    if (cmd is null) break;
    try {
      //consoleLock();
      //scope(exit) consoleUnlock();
      conExecute(cmd);
    } catch (Exception e) {
      conwriteln("***ERROR: ", e.msg);
    }
  }
  // shift postponed commands
  if (concmdbufpos > ebuf) {
    import core.stdc.string : memmove;
    //consoleLock();
    //scope(exit) consoleUnlock();
    memmove(concmdbuf.ptr, concmdbuf.ptr+ebuf, concmdbufpos-ebuf);
    concmdbufpos -= ebuf;
    //s = concmdbuf[0..concmdbufpos];
    //ebuf = concmdbufpos;
  } else {
    concmdbufpos = 0;
  }
}


static int conCharWidth() (char ch) { pragma(inline, true); return 10; }
enum conCharHeight = 10;


// ////////////////////////////////////////////////////////////////////////// //
__gshared bool rConsoleVisible = false;
__gshared int rConsoleHeight = 10*3;
__gshared uint rConTextColor = 0x00ff00; // rgb
__gshared uint rConCursorColor = 0xff7f00; // rgb
__gshared uint rConInputColor = 0xffff00; // rgb
__gshared uint rConPromptColor = 0xffffff; // rgb
shared bool vquitRequested = false;


public void initConsole (uint ascrwdt, uint ascrhgt, uint ascale=1) {
  if (winScale != 0) assert(0, "cmdcon already initialized");
  if (ascrwdt < 64 || ascrhgt < 64 || ascrwdt > 4096 || ascrhgt > 4096) assert(0, "invalid cmdcon dimensions");
  if (ascale < 1 || ascale > 64) assert(0, "invalid cmdcon scale");
  scrwdt = ascrwdt;
  scrhgt = ascrhgt;
  winScale = ascale;
  conRegFunc!((const(char)[] fname, bool silent=false) {
    try {
      auto fl = openFileEx(fname);
      auto sz = fl.size;
      if (sz > 1024*1024*64) throw new Exception("script file too big");
      if (sz > 0) {
        auto s = new char[](cast(uint)sz);
        fl.rawReadExact(s);
        concmd(s);
      }
    } catch (Exception e) {
      if (!silent) conwriteln("ERROR loading script \"", fname, "\"");
    }
  })("exec", "execute console script (name [silent_failure_flag])");
  conRegVar!rConsoleVisible("r_console", "console visibility");
  conRegVar!rConsoleHeight(10*3, scrhgt, "r_conheight");
  conRegVarHex!rConTextColor("r_contextcolor", "console log text color, 0xrrggbb");
  conRegVarHex!rConCursorColor("r_concursorcolor", "console cursor color, 0xrrggbb");
  conRegVarHex!rConInputColor("r_coninputcolor", "console input color, 0xrrggbb");
  conRegVarHex!rConPromptColor("r_conpromptcolor", "console prompt color, 0xrrggbb");
  //rConsoleHeight = scrhgt-scrhgt/3;
  rConsoleHeight = scrhgt/2;
  conRegFunc!({
    import core.atomic;
    atomicStore(vquitRequested, true);
  })("quit", "quit");
}


// ////////////////////////////////////////////////////////////////////////// //
__gshared uint* convbuf = null; // RGBA
__gshared uint convbufTexId = 0;


public void oglInitConsole () {
  import core.stdc.stdlib;
  //import iv.glbinds;

  //conwriteln("scrwdt=", scrwdt, "; scrhgt=", scrhgt, "; scale=", winScale);

  convbuf = cast(uint*)realloc(convbuf, scrwdt*scrhgt*4);
  if (convbuf is null) assert(0, "out of memory");
  convbuf[0..scrwdt*scrhgt] = 0xff000000;

  if (convbufTexId) { glDeleteTextures(1, &convbufTexId); convbufTexId = 0; }

  GLuint wrapOpt = GL_REPEAT;
  GLuint filterOpt = GL_NEAREST; //GL_LINEAR;
  GLuint ttype = GL_UNSIGNED_BYTE;

  glGenTextures(1, &convbufTexId);
  if (convbufTexId == 0) assert(0, "can't create cmdcon texture");

  GLint gltextbinding;
  glGetIntegerv(GL_TEXTURE_BINDING_2D, &gltextbinding);
  scope(exit) glBindTexture(GL_TEXTURE_2D, gltextbinding);

  glBindTexture(GL_TEXTURE_2D, convbufTexId);
  glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, wrapOpt);
  glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, wrapOpt);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, filterOpt);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, filterOpt);
  //glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);
  //glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);

  GLfloat[4] bclr = 0.0;
  glTexParameterfv(GL_TEXTURE_2D, GL_TEXTURE_BORDER_COLOR, bclr.ptr);
  glTexImage2D(GL_TEXTURE_2D, 0, (ttype == GL_FLOAT ? GL_RGBA16F : GL_RGBA), scrwdt, scrhgt, 0, GL_RGBA, GL_UNSIGNED_BYTE, convbuf);
}


public void oglDrawConsole () {
  if (!rConsoleVisible) return;
  if (convbufTexId && convbuf !is null) {
    //import iv.glbinds;
    consoleLock();
    scope(exit) consoleUnlock();

    //conwriteln("scrwdt=", scrwdt, "; scrhgt=", scrhgt, "; scale=", winScale, "; tid=", convbufTexId);
    renderConsole();

    GLint glmatmode;
    GLint gltextbinding;
    GLint[4] glviewport;
    glGetIntegerv(GL_MATRIX_MODE, &glmatmode);
    glGetIntegerv(GL_TEXTURE_BINDING_2D, &gltextbinding);
    glGetIntegerv(GL_VIEWPORT, glviewport.ptr);
    glMatrixMode(GL_PROJECTION); glPushMatrix();
    glMatrixMode(GL_MODELVIEW); glPushMatrix();
    glMatrixMode(GL_TEXTURE); glPushMatrix();
    glMatrixMode(GL_COLOR); glPushMatrix();
    glPushAttrib(/*GL_ENABLE_BIT|GL_COLOR_BUFFER_BIT|GL_CURRENT_BIT*/GL_ALL_ATTRIB_BITS); // let's play safe
    // restore on exit
    scope(exit) {
      glPopAttrib(/*GL_ENABLE_BIT*/);
      glMatrixMode(GL_PROJECTION); glPopMatrix();
      glMatrixMode(GL_MODELVIEW); glPopMatrix();
      glMatrixMode(GL_TEXTURE); glPopMatrix();
      glMatrixMode(GL_COLOR); glPopMatrix();
      glMatrixMode(glmatmode);
      glBindTexture(GL_TEXTURE_2D, gltextbinding);
      glViewport(glviewport.ptr[0], glviewport.ptr[1], glviewport.ptr[2], glviewport.ptr[3]);
    }

    glTextureSubImage2D(convbufTexId, 0, 0/*x*/, 0/*y*/, scrwdt, scrhgt, GL_RGBA, GL_UNSIGNED_BYTE, convbuf);

    enum x = 0;
    int y = 0;
    int w = scrwdt*winScale;
    int h = scrhgt*winScale;

    glMatrixMode(GL_PROJECTION); // for ortho camera
    glLoadIdentity();
    // left, right, bottom, top, near, far
    //glOrtho(0, wdt, 0, hgt, -1, 1); // bottom-to-top
    glOrtho(0, w, h, 0, -1, 1); // top-to-bottom
    glViewport(0, 0, w, h);
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();

    glEnable(GL_TEXTURE_2D);
    glDisable(GL_LIGHTING);
    glDisable(GL_DITHER);
    //glDisable(GL_BLEND);
    glDisable(GL_DEPTH_TEST);
    glEnable(GL_BLEND);
    //glBlendFunc(GL_SRC_ALPHA, GL_ONE);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    //glDisable(GL_BLEND);

    int ofs = (scrhgt-rConsoleHeight)*winScale;
    y -= ofs;
    h -= ofs;
    glColor4f(1, 1, 1, 0.8);
    glBindTexture(GL_TEXTURE_2D, convbufTexId);
    //scope(exit) glBindTexture(GL_TEXTURE_2D, 0);
    glBegin(GL_QUADS);
      glTexCoord2f(0.0f, 0.0f); glVertex2i(x, y); // top-left
      glTexCoord2f(1.0f, 0.0f); glVertex2i(w, y); // top-right
      glTexCoord2f(1.0f, 1.0f); glVertex2i(w, h); // bottom-right
      glTexCoord2f(0.0f, 1.0f); glVertex2i(x, h); // bottom-left
    glEnd();
    //glDisable(GL_BLEND);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
__gshared uint conLastChange = 0;

static void vsetPixel (int x, int y, uint c) nothrow @trusted @nogc {
  pragma(inline, true);
  if (x >= 0 && y >= 0 && x < scrwdt && y < scrhgt) convbuf[y*scrwdt+x] = c;
}


import iv.x11gfx : dosFont10;

void renderConsole () nothrow @trusted @nogc {
  static int conDrawX, conDrawY;
  static uint conColor;

  static void conDrawChar (char ch) nothrow @trusted @nogc {
    foreach (immutable y; 0..10) {
      ushort v = dosFont10.ptr[cast(uint)ch*10+y];
      foreach (immutable x; 0..10) {
        if (v&0x8000) vsetPixel(conDrawX+x, conDrawY+y, conColor);
        v <<= 1;
      }
    }
    conDrawX += 10;
  }

  static void conSetColor (uint c) nothrow @trusted @nogc {
    pragma(inline, true);
    conColor = (c&0x00ff00)|((c>>16)&0xff)|((c&0xff)<<16)|0xff000000;
  }

  static void conRect (int w, int h) nothrow @trusted @nogc {
    foreach (immutable y; 0..h) {
      foreach (immutable x; 0..w) {
        vsetPixel(conDrawX+x, conDrawY+y, conColor);
      }
    }
    conDrawX += 10;
  }

  enum XOfs = 0;
  if (conLastChange == cbufLastChange) return;
  // rerender console
  conLastChange = cbufLastChange;
  int skipLines = conskiplines;
  convbuf[0..scrwdt*scrhgt] = 0xff000000;
  {
    // draw command line
    //int y = /*convbuf.height*/rConsoleHeight-conCharHeight/*-2*/;
    int y = scrhgt-conCharHeight;
    {
      conDrawX = XOfs;
      conDrawY = y;
      int w = conCharWidth('>');
      conSetColor(rConPromptColor);
      conDrawChar('>');
      uint spos = conclilen;
      while (spos > 0) {
        char ch = concli.ptr[spos-1];
        if (w+conCharWidth(ch) > scrwdt-XOfs*2-12) break;
        w += conCharWidth(ch);
        --spos;
      }
      conSetColor(rConInputColor);
      foreach (char ch; concli[spos..conclilen]) conDrawChar(ch);
      // cursor
      conSetColor(rConCursorColor);
      conRect(conCharWidth('W'), conCharHeight);
      y -= conCharHeight;
    }
    // draw console text
    conSetColor(rConTextColor);
    conDrawX = XOfs;
    conDrawY = y;

    void putLine(T) (auto ref T line, usize pos=0) {
      if (y+conCharHeight <= 0) return;
      int w = XOfs;
      usize sp = pos;
      while (sp < line.length) {
        char ch = line[sp++];
        int cw = conCharWidth(ch);
        if ((w += cw) > scrwdt-XOfs) { w -= cw; --sp; break; }
      }
      if (sp < line.length) putLine(line, sp); // recursive put tail
      // draw line
      if (skipLines-- <= 0) {
        while (pos < sp) conDrawChar(line[pos++]);
        y -= conCharHeight;
        conDrawX = XOfs;
        conDrawY = y;
      }
    }

    foreach (auto line; conbufLinesRev) {
      putLine(line);
      if (y+conCharHeight <= 0) break;
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
static if (OptGlCmdConHasSdpy) {
import arsd.simpledisplay : KeyEvent;
// true: eaten
public bool conKeyEvent (KeyEvent event) {
  import arsd.simpledisplay;
  if (!rConsoleVisible) return false;
  if (!event.pressed) return true;
  if (event.key == Key.Escape) { concmd("r_console 0"); return true; }
  switch (event.key) {
    case Key.Up: concliChar(ConInputChar.Up); return true;
    case Key.Down: concliChar(ConInputChar.Down); return true;
    case Key.Left: concliChar(ConInputChar.Left); return true;
    case Key.Right: concliChar(ConInputChar.Right); return true;
    case Key.Home: concliChar(ConInputChar.Home); return true;
    case Key.End: concliChar(ConInputChar.End); return true;
    case Key.PageUp: concliChar(ConInputChar.PageUp); return true;
    case Key.PageDown: concliChar(ConInputChar.PageDown); return true;
    case Key.Backspace: concliChar(ConInputChar.Backspace); return true;
    case Key.Tab: concliChar(ConInputChar.Tab); return true;
    case Key.Enter: concliChar(ConInputChar.Enter); return true;
    case Key.Delete: concliChar(ConInputChar.Delete); return true;
    case Key.Insert: concliChar(ConInputChar.Insert); return true;
    case Key.Y: if (event.modifierState&ModifierState.ctrl) concliChar(ConInputChar.CtrlY); return true;
    default:
  }
  return true;
}


// true: eaten
public bool conCharEvent (dchar ch) {
  if (!rConsoleVisible) return false;
  if (ch >= ' ' && ch < 128) concliChar(cast(char)ch);
  return true;
}
}
