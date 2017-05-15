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
module iv.cmdcongl is aliced;
private:

public import iv.cmdcon;
import iv.vfs;
import iv.strex;

static if (__traits(compiles, (){import arsd.simpledisplay;}())) {
  enum OptCmdConGlHasSdpy = true;
  import arsd.simpledisplay : UsingSimpledisplayX11;
} else {
  enum OptCmdConGlHasSdpy = false;
  private enum UsingSimpledisplayX11 = false;
}


// ////////////////////////////////////////////////////////////////////////// //
public __gshared bool glconAllowOpenGLRender = true;
__gshared uint conScale = 0;
__gshared uint scrwdt, scrhgt;

public __gshared void delegate () glconOnShow = null;
public __gshared void delegate () glconOnHide = null;


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
/// you may call this in char event, but `glconCharEvent()` will do that for you
public void glconCharInput (char ch) {
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
enum conCharWidth = 10;
enum conCharHeight = 10;

__gshared char rPromptChar = '>';
__gshared float rConAlpha = 0.8;
__gshared bool rConsoleVisible = false;
__gshared bool rConsoleVisiblePrev = false;
__gshared int rConsoleHeight = 10*3;
__gshared uint rConTextColor = 0x00ff00; // rgb
__gshared uint rConCursorColor = 0xff7f00; // rgb
__gshared uint rConInputColor = 0xffff00; // rgb
__gshared uint rConPromptColor = 0xffffff; // rgb
__gshared uint rConStarColor = 0x3f0000; // rgb
shared bool vquitRequested = false;

__gshared int conskiplines = 0;


// initialize glcmdcon variables and commands, sets screen size and scale
// NOT THREAD-SAFE! also, should be called only once.
// screen dimensions can be fixed later by calling `glconResize()`.
private void initConsole () {
  enum ascrwdt = 800;
  enum ascrhgt = 600;
  enum ascale = 1;
  if (conScale != 0) assert(0, "cmdcon already initialized");
  if (ascrwdt < 64 || ascrhgt < 64 || ascrwdt > 4096 || ascrhgt > 4096) assert(0, "invalid cmdcon dimensions");
  if (ascale < 1 || ascale > 64) assert(0, "invalid cmdcon scale");
  scrwdt = ascrwdt;
  scrhgt = ascrhgt;
  conScale = ascale;
  conRegVar!rConsoleVisible("r_console", "console visibility", ConVarAttr.Archive);
  conRegVar!rConsoleHeight(10*3, scrhgt, "r_conheight", "console height", ConVarAttr.Archive);
  conRegVar!rConTextColor("r_contextcolor", "console log text color, 0xrrggbb", ConVarAttr.Archive, ConVarAttr.Hex);
  conRegVar!rConCursorColor("r_concursorcolor", "console cursor color, 0xrrggbb", ConVarAttr.Archive, ConVarAttr.Hex);
  conRegVar!rConInputColor("r_coninputcolor", "console input color, 0xrrggbb", ConVarAttr.Archive, ConVarAttr.Hex);
  conRegVar!rConPromptColor("r_conpromptcolor", "console prompt color, 0xrrggbb", ConVarAttr.Archive, ConVarAttr.Hex);
  conRegVar!rConStarColor("r_constarcolor", "console star color, 0xrrggbb", ConVarAttr.Archive, ConVarAttr.Hex);
  conRegVar!rPromptChar("r_conpromptchar", "console prompt character", ConVarAttr.Archive);
  conRegVar!rConAlpha("r_conalpha", "console transparency (0 is fully transparent, 1 is opaque)", ConVarAttr.Archive);
  //rConsoleHeight = scrhgt-scrhgt/3;
  rConsoleHeight = scrhgt/2;
  conRegFunc!({
    import core.atomic;
    atomicStore(vquitRequested, true);
  })("quit", "quit");
}

shared static this () { initConsole(); }


// ////////////////////////////////////////////////////////////////////////// //
/// initialize OpenGL part of glcmdcon. it is ok to call it with the same dimensions repeatedly.
/// NOT THREAD-SAFE!
public void glconInit (uint ascrwdt, uint ascrhgt, uint ascale=1) {
  if (ascrwdt < 64 || ascrhgt < 64 || ascrwdt > 4096 || ascrhgt > 4096) return;
  if (ascale < 1 || ascale > 64) return;
  conScale = ascale;
  if (scrwdt != ascrwdt || scrhgt != ascrhgt || convbuf is null) {
    if (rConsoleHeight > 0) rConsoleHeight = cast(int)(cast(double)rConsoleHeight/cast(double)scrhgt*cast(double)ascrhgt);
    scrwdt = ascrwdt;
    scrhgt = ascrhgt;
    if (rConsoleHeight > scrhgt) rConsoleHeight = scrhgt;
    //conLastChange = 0;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
/// call this if window was resized. will return `true` if resize was successfull.
/// NOT THREAD-SAFE!
/// can be called instead of `glconInit()`. it is ok to call it with the same dimensions repeatedly.
public void glconResize (uint ascrwdt, uint ascrhgt, uint ascale=1) {
  glconInit(ascrwdt, ascrhgt, ascale); // reallocate back buffer and texture
}


// ////////////////////////////////////////////////////////////////////////// //
__gshared uint* convbuf = null; // RGBA, malloced
__gshared uint convbufTexId = 0;
__gshared uint prevScrWdt = 0, prevScrHgt = 0;
__gshared bool glconRenderFailed = false;


// returns `true` if buffer need to be regenerated
private bool glconGenRenderBuffer () {
  if (glconRenderFailed) return false;
  if (convbuf is null || prevScrWdt != scrwdt || prevScrHgt != scrhgt) {
    import core.stdc.stdlib : free, realloc;
    // need new buffer; kill old texture, so it will be recreated
    if (glconDrawWindow is null && glconAllowOpenGLRender) {
      if (convbufTexId) { glDeleteTextures(1, &convbufTexId); convbufTexId = 0; }
    }
    auto nbuf = cast(uint*)realloc(convbuf, scrwdt*scrhgt*4);
    if (nbuf is null) {
      if (convbuf !is null) { free(convbuf); convbuf = null; }
      glconRenderFailed = true;
      return false;
    }
    convbuf = nbuf;
    prevScrWdt = scrwdt;
    prevScrHgt = scrhgt;
    convbuf[0..scrwdt*scrhgt] = 0xff000000;
    return true; // buffer updated
  }
  return false; // buffer not updated
}


// returns `true` if texture was recreated
private bool glconGenTexture () {
  if (glconRenderFailed) return false;

  static if (OptCmdConGlHasSdpy) {
    if (glconDrawWindow !is null) return false;
  }

  if (convbufTexId != 0) return false;

  if (!glconAllowOpenGLRender) return false;

  enum wrapOpt = GL_REPEAT;
  enum filterOpt = GL_NEAREST; //GL_LINEAR;
  enum ttype = GL_UNSIGNED_BYTE;

  glGenTextures(1, &convbufTexId);
  if (convbufTexId == 0) {
    import core.stdc.stdlib : free;
    if (convbuf !is null) { free(convbuf); convbuf = null; }
    glconRenderFailed = true;
    return false;
  }

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

  /*
  GLfloat[4] bclr = 0.0;
  glTexParameterfv(GL_TEXTURE_2D, GL_TEXTURE_BORDER_COLOR, bclr.ptr);
  */

  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, scrwdt, scrhgt, 0, /*GL_RGBA*/GL_BGRA, GL_UNSIGNED_BYTE, convbuf); // this updates texture

  return true;
}


private void glconCallShowHideHandler () {
  if (rConsoleVisible != rConsoleVisiblePrev) {
    rConsoleVisiblePrev = rConsoleVisible;
    try {
           if (rConsoleVisible) { if (glconOnShow !is null) glconOnShow(); }
      else if (!rConsoleVisible) { if (glconOnHide !is null) glconOnHide(); }
    } catch (Exception) {}
  }
}


// ////////////////////////////////////////////////////////////////////////// //
/// render console (if it is visible). tries hard to not change OpenGL state.
public void glconDraw () {
  glconCallShowHideHandler();
  if (!rConsoleVisible) return;

  consoleLock();
  scope(exit) consoleUnlock();

  bool regen = glconGenRenderBuffer();
  if (glconRenderFailed) return; // alas

  assert(convbuf !is null);

  auto updatetex = renderConsole(regen);
  if (glconGenTexture()) updatetex = false;
  if (glconRenderFailed) return; // alas

  static if (OptCmdConGlHasSdpy) {
    if (glconDrawWindow !is null) {
      static if (UsingSimpledisplayX11) {
        // ooops. render to backbuffer
        //{ import core.stdc.stdio; printf("rendering to backbuffer\n"); }
        if (!glconDrawWindow.closed && scrwdt > 0 && scrhgt > 0 && (!glconDrawDirect || !glconDrawWindow.hidden)) {
          XImage ximg;
          //glcon_ximageInitSimple(ximg, scrwdt, scrhgt, convbuf);
          ximg.width = scrwdt;
          ximg.height = scrhgt;
          ximg.xoffset = 0;
          ximg.format = ImageFormat.ZPixmap;
          ximg.data = convbuf;
          ximg.byte_order = 0;
          ximg.bitmap_unit = 32;
          ximg.bitmap_bit_order = 0;
          ximg.bitmap_pad = 8;
          ximg.depth = 24;
          ximg.bytes_per_line = 0;
          ximg.bits_per_pixel = 32; // THIS MATTERS!
          ximg.red_mask = 0x00ff0000;
          ximg.green_mask = 0x0000ff00;
          ximg.blue_mask = 0x000000ff;
          XInitImage(&ximg);
          int desty = rConsoleHeight-scrhgt;
          auto dpy = glconDrawWindow.impl.display;
          Drawable drw = (glconDrawDirect ? cast(Drawable)glconDrawWindow.impl.window : cast(Drawable)glconDrawWindow.impl.buffer);
          GC gc = XCreateGC(dpy, drw, 0, null);
          scope(exit) XFreeGC(dpy, gc);
          XCopyGC(dpy, DefaultGC(dpy, DefaultScreen(dpy)), 0xffffffff, gc);
          XSetClipMask(dpy, gc, None);
          XPutImage(dpy, drw, gc, &ximg, 0, 0, 0/*destx*/, desty, scrwdt, scrhgt);
        }
      }
      return;
    }
  }

  if (!glconAllowOpenGLRender) return;
  assert(convbufTexId != 0);

  GLint glmatmode;
  GLint gltextbinding;
  GLint oldprg;
  GLint oldfbr, oldfbw;
  GLint[4] glviewport;
  glGetIntegerv(GL_MATRIX_MODE, &glmatmode);
  glGetIntegerv(GL_TEXTURE_BINDING_2D, &gltextbinding);
  glGetIntegerv(GL_VIEWPORT, glviewport.ptr);
  glGetIntegerv(GL_CURRENT_PROGRAM, &oldprg);
  glGetIntegerv(GL_READ_FRAMEBUFFER_BINDING, &oldfbr);
  glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING, &oldfbw);
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
    if (glHasFunc!"glBindFramebufferEXT") glBindFramebufferEXT(GL_READ_FRAMEBUFFER_EXT, oldfbr);
    if (glHasFunc!"glBindFramebufferEXT") glBindFramebufferEXT(GL_DRAW_FRAMEBUFFER_EXT, oldfbw);
    glBindTexture(GL_TEXTURE_2D, gltextbinding);
    if (glHasFunc!"glUseProgram") glUseProgram(oldprg);
    glViewport(glviewport.ptr[0], glviewport.ptr[1], glviewport.ptr[2], glviewport.ptr[3]);
  }

  enum x = 0;
  int y = 0;
  int w = scrwdt*conScale;
  int h = scrhgt*conScale;

  glBindTexture(GL_TEXTURE_CUBE_MAP, 0);
  if (glHasFunc!"glBindFramebufferEXT") glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, 0);
  if (glHasFunc!"glUseProgram") glUseProgram(0);

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
  glDisable(GL_STENCIL_TEST);

  glBindTexture(GL_TEXTURE_2D, convbufTexId);
  if (updatetex) {
    //glTextureSubImage2D(convbufTexId, 0, 0/*x*/, 0/*y*/, scrwdt, scrhgt, GL_RGBA, GL_UNSIGNED_BYTE, convbuf);
    glTexSubImage2D(GL_TEXTURE_2D, 0, 0/*x*/, 0/*y*/, scrwdt, scrhgt, /*GL_RGBA*/GL_BGRA, GL_UNSIGNED_BYTE, convbuf);
  }

  int ofs = (scrhgt-rConsoleHeight)*conScale;
  y -= ofs;
  h -= ofs;
  float alpha = rConAlpha;
  if (alpha < 0) alpha = 0; else if (alpha > 1) alpha = 1;
  glColor4f(1, 1, 1, alpha);
  //scope(exit) glBindTexture(GL_TEXTURE_2D, 0);
  glBegin(GL_QUADS);
    glTexCoord2f(0.0f, 0.0f); glVertex2i(x, y); // top-left
    glTexCoord2f(1.0f, 0.0f); glVertex2i(w, y); // top-right
    glTexCoord2f(1.0f, 1.0f); glVertex2i(w, h); // bottom-right
    glTexCoord2f(0.0f, 1.0f); glVertex2i(x, h); // bottom-left
  glEnd();
  //glDisable(GL_BLEND);
}


// ////////////////////////////////////////////////////////////////////////// //
__gshared int conDrawX, conDrawY;
__gshared uint conColor;


void vsetPixel (int x, int y, uint c) nothrow @trusted @nogc {
  pragma(inline, true);
  if (x >= 0 && y >= 0 && x < scrwdt && y < scrhgt) convbuf[y*scrwdt+x] = c;
}


void drawStar (int x0, int y0, int radius) nothrow @trusted @nogc {
  if (radius < 32) return;

  static void drawLine(bool lastPoint=true) (int x0, int y0, int x1, int y1) nothrow @trusted @nogc {
    enum swap(string a, string b) = "{int tmp_="~a~";"~a~"="~b~";"~b~"=tmp_;}";

    if (x0 == x1 && y0 == y1) {
      static if (lastPoint) vsetPixel(x0, y0, conColor);
      return;
    }

    // clip rectange
    int wx0 = 0, wy0 = 0, wx1 = scrwdt-1, wy1 = scrhgt-1;
    // other vars
    int stx, sty; // "steps" for x and y axes
    int dsx, dsy; // "lengthes" for x and y axes
    int dx2, dy2; // "double lengthes" for x and y axes
    int xd, yd; // current coord
    int e; // "error" (as in bresenham algo)
    int rem;
    int term;
    int *d0, d1;
    // horizontal setup
    if (x0 < x1) {
      // from left to right
      if (x0 > wx1 || x1 < wx0) return; // out of screen
      stx = 1; // going right
    } else {
      // from right to left
      if (x1 > wx1 || x0 < wx0) return; // out of screen
      stx = -1; // going left
      x0 = -x0;
      x1 = -x1;
      wx0 = -wx0;
      wx1 = -wx1;
      mixin(swap!("wx0", "wx1"));
    }
    // vertical setup
    if (y0 < y1) {
      // from top to bottom
      if (y0 > wy1 || y1 < wy0) return; // out of screen
      sty = 1; // going down
    } else {
      // from bottom to top
      if (y1 > wy1 || y0 < wy0) return; // out of screen
      sty = -1; // going up
      y0 = -y0;
      y1 = -y1;
      wy0 = -wy0;
      wy1 = -wy1;
      mixin(swap!("wy0", "wy1"));
    }
    dsx = x1-x0;
    dsy = y1-y0;
    if (dsx < dsy) {
      d0 = &yd;
      d1 = &xd;
      mixin(swap!("x0", "y0"));
      mixin(swap!("x1", "y1"));
      mixin(swap!("dsx", "dsy"));
      mixin(swap!("wx0", "wy0"));
      mixin(swap!("wx1", "wy1"));
      mixin(swap!("stx", "sty"));
    } else {
      d0 = &xd;
      d1 = &yd;
    }
    dx2 = 2*dsx;
    dy2 = 2*dsy;
    xd = x0;
    yd = y0;
    e = 2*dsy-dsx;
    term = x1;
    bool xfixed = false;
    if (y0 < wy0) {
      // clip at top
      int temp = dx2*(wy0-y0)-dsx;
      xd += temp/dy2;
      rem = temp%dy2;
      if (xd > wx1) return; // x is moved out of clipping rect, nothing to do
      if (xd+1 >= wx0) {
        yd = wy0;
        e -= rem+dsx;
        if (rem > 0) { ++xd; e += dy2; }
        xfixed = true;
      }
    }
    if (!xfixed && x0 < wx0) {
      // clip at left
      int temp = dy2*(wx0-x0);
      yd += temp/dx2;
      rem = temp%dx2;
      if (yd > wy1 || yd == wy1 && rem >= dsx) return;
      xd = wx0;
      e += rem;
      if (rem >= dsx) { ++yd; e -= dx2; }
    }
    if (y1 > wy1) {
      // clip at bottom
      int temp = dx2*(wy1-y0)+dsx;
      term = x0+temp/dy2;
      rem = temp%dy2;
      if (rem == 0) --term;
    }
    if (term > wx1) term = wx1; // clip at right
    static if (lastPoint) {
      // draw last point
      ++term;
    } else {
      if (term == xd) return; // this is the only point, get out of here
    }
    if (sty == -1) yd = -yd;
    if (stx == -1) { xd = -xd; term = -term; }
    dx2 -= dy2;
    // draw it; `vsetPixel()` can omit checks
    while (xd != term) {
      vsetPixel(*d0, *d1, conColor);
      // done drawing, move coords
      if (e >= 0) {
        yd += sty;
        e -= dx2;
      } else {
        e += dy2;
      }
      xd += stx;
    }
  }

  static void drawCircle (int cx, int cy, int radius) nothrow @trusted @nogc {
    static void plot4points() (int cx, int cy, int x, int y) nothrow @trusted @nogc {
      vsetPixel(cx+x, cy+y, conColor);
      if (x != 0) vsetPixel(cx-x, cy+y, conColor);
      if (y != 0) vsetPixel(cx+x, cy-y, conColor);
      vsetPixel(cx-x, cy-y, conColor);
    }

    if (radius > 0) {
      int error = -radius, x = radius, y = 0;
      if (radius == 1) { vsetPixel(cx, cy, conColor); return; }
      while (x > y) {
        plot4points(cx, cy, x, y);
        plot4points(cx, cy, y, x);
        error += y*2+1;
        ++y;
        if (error >= 0) { --x; error -= x*2; }
      }
      plot4points(cx, cy, x, y);
    }
  }

  static auto deg2rad(T : double) (T v) pure nothrow @safe @nogc { pragma(inline, true); import std.math : PI; return v*PI/180.0; }

  drawCircle(x0, y0, radius);
  foreach (immutable n; 0..5) {
    import std.math;
    auto a0 = deg2rad(360.0/5*n+18);
    auto a1 = deg2rad(360.0/5*(n+2)+18);
    drawLine(
      cast(uint)(x0+cos(a0)*radius), cast(uint)(y0+sin(a0)*radius),
      cast(uint)(x0+cos(a1)*radius), cast(uint)(y0+sin(a1)*radius),
    );
  }
}


void conSetColor (uint c) nothrow @trusted @nogc {
  pragma(inline, true);
  //conColor = (c&0x00ff00)|((c>>16)&0xff)|((c&0xff)<<16)|0xff000000;
  conColor = c|0xff000000;
}


void conDrawChar (char ch) nothrow @trusted @nogc {
  /*
  int r = conColor&0xff;
  int g = (conColor>>8)&0xff;
  int b = (conColor>>16)&0xff;
  */
  int r = (conColor>>16)&0xff;
  int g = (conColor>>8)&0xff;
  int b = conColor&0xff;
  immutable int rr = r, gg = g, bb = b;
  foreach_reverse (immutable y; 0..10) {
    ushort v = glConFont10.ptr[cast(uint)ch*10+y];
    //immutable uint cc = (b<<16)|(g<<8)|r|0xff000000;
    immutable uint cc = (r<<16)|(g<<8)|b|0xff000000;
    foreach (immutable x; 0..10) {
      if (v&0x8000) vsetPixel(conDrawX+x, conDrawY+y, cc);
      v <<= 1;
    }
    static if (false) {
      if ((r += 8) > 255) r = 255;
      if ((g += 8) > 255) g = 255;
      if ((b += 8) > 255) b = 255;
    } else {
      if ((r -= 7) < 0) r = rr;
      if ((g -= 7) < 0) g = gg;
      if ((b -= 7) < 0) b = bb;
    }
  }
  conDrawX += 10;
}


void conRect (int w, int h) nothrow @trusted @nogc {
  /*
  int r = conColor&0xff;
  int g = (conColor>>8)&0xff;
  int b = (conColor>>16)&0xff;
  */
  int r = (conColor>>16)&0xff;
  int g = (conColor>>8)&0xff;
  int b = conColor&0xff;
  foreach_reverse (immutable y; 0..h) {
    //immutable uint cc = (b<<16)|(g<<8)|r|0xff000000;
    immutable uint cc = (r<<16)|(g<<8)|b|0xff000000;
    foreach (immutable x; conDrawX..conDrawX+w) vsetPixel(x, conDrawY+y, cc);
    if ((r -= 8) < 0) r = 0;
    if ((g -= 8) < 0) g = 0;
    if ((b -= 8) < 0) b = 0;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
__gshared uint conLastChange = 0;
__gshared uint conLastIBChange = 0;
__gshared int prevCurX = -1;
__gshared int prevIXOfs = 0;


bool renderConsole (bool forced) nothrow @trusted @nogc {
  if (!forced && (conLastChange == cbufLastChange && conLastIBChange == conInputLastChange)) return false;

  enum XOfs = 0;
  immutable sw = scrwdt, sh = scrhgt;
  int skipLines = conskiplines;
  convbuf[0..sw*sh] = 0xff000000;
  conLastChange = cbufLastChange;
  conLastIBChange = conInputLastChange;
  {
    import std.algorithm : min;
    conSetColor(rConStarColor);
    int radius = min(sw, sh)/3;
    drawStar(sw/2, /*sh/2*/sh-radius-16, radius);
  }

  auto concli = conInputBuffer;
  int conclilen = cast(int)concli.length;
  int concurx = conInputBufferCurX();

  int y = sh-conCharHeight;
  // draw command line
  {
    conDrawX = XOfs;
    conDrawY = y;
    int charsInLine = (sw-XOfs*2)/conCharWidth-1; // reserve room for cursor
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
      conSetColor(rConPromptColor);
      conDrawChar(rPromptChar);
    }
    conSetColor(rConInputColor);
    version(none) {
      foreach (int pos; stpos..stpos+charsInLine+1) {
        if (pos < concurx) {
          if (pos < conclilen) conDrawChar(concli.ptr[pos]);
        } else if (pos == concurx) {
          conSetColor(rConCursorColor);
          conRect(conCharWidth, conCharHeight);
          conDrawX += conCharWidth;
          conSetColor(rConInputColor);
        } else if (pos-1 < conclilen) {
          conDrawChar(concli.ptr[pos-1]);
        }
      }
    } else {
      foreach (int pos; stpos..stpos+charsInLine+1) {
        if (pos == concurx) {
          conSetColor(rConCursorColor);
          conRect(conCharWidth, conCharHeight);
          conSetColor(rConInputColor);
        }
        if (pos >= 0 && pos < conclilen) conDrawChar(concli.ptr[pos]);
      }
    }
    y -= conCharHeight;
  }

  // draw console text
  conSetColor(rConTextColor);
  conDrawX = XOfs;
  conDrawY = y;

  void putLine(T) (auto ref T line, usize pos=0) {
    if (y+conCharHeight <= 0 || pos >= line.length) return;
    int w = XOfs, lastWordW = -1;
    usize sp = pos, lastWordEnd = 0;
    while (sp < line.length) {
      char ch = line[sp++];
      enum cw = conCharWidth;
      // remember last word position
      if (/*lastWordW < 0 &&*/ (ch == ' ' || ch == '\t')) {
        lastWordEnd = sp-1; // space will be put on next line (rough indication of line wrapping)
        lastWordW = w;
      }
      if ((w += cw) > sw-XOfs*2) {
        w -= cw;
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

  return true;
}


// ////////////////////////////////////////////////////////////////////////// //
static if (OptCmdConGlHasSdpy) {
import arsd.simpledisplay : KeyEvent, Key, SimpleWindow, Pixmap, XImage, XDisplay, Visual, XPutImage, ImageFormat, Drawable, Status, XInitImage;
import arsd.simpledisplay : GC, XCreateGC, XFreeGC, XCopyGC, XSetClipMask, DefaultGC, DefaultScreen, None;

public __gshared string glconShowKey = "M-Grave"; /// this key will be eaten

shared static this () {
  conRegVar!glconShowKey("c_togglekey", "console toggle key name");
}


/// process keyboard event. returns `true` if event was eaten.
public bool glconKeyEvent (KeyEvent event) {
  import arsd.simpledisplay;
  if (!rConsoleVisible) {
    if (event == glconShowKey) {
      if (event.pressed) concmd("r_console 1");
      return true;
    }
    return false;
  }
  if (!event.pressed) return true;
  if (event == glconShowKey) {
    if (glconShowKey.length == 1 && glconShowKey[0] >= ' ' && glconShowKey[0] < 128) {
      if (conInputBuffer.length == 0) concmd("r_console 0");
    } else if (glconShowKey == "Grave") {
      if (conInputBuffer.length == 0) concmd("r_console 0");
    } else {
      concmd("r_console 0");
    }
    return true;
  }
  if (event.key == Key.Escape) { concmd("r_console 0"); return true; }
  switch (event.key) {
    case Key.Up:
      if (event.modifierState&ModifierState.alt) {
        glconCharInput(ConInputChar.LineUp);
      } else {
        glconCharInput(ConInputChar.Up);
      }
      return true;
    case Key.Down:
      if (event.modifierState&ModifierState.alt) {
        glconCharInput(ConInputChar.LineDown);
      } else {
        glconCharInput(ConInputChar.Down);
      }
      return true;
    case Key.Left: glconCharInput(ConInputChar.Left); return true;
    case Key.Right: glconCharInput(ConInputChar.Right); return true;
    case Key.Home: glconCharInput(ConInputChar.Home); return true;
    case Key.End: glconCharInput(ConInputChar.End); return true;
    case Key.PageUp:
      if (event.modifierState&ModifierState.alt) {
        glconCharInput(ConInputChar.LineUp);
      } else {
        glconCharInput(ConInputChar.PageUp);
      }
      return true;
    case Key.PageDown:
      if (event.modifierState&ModifierState.alt) {
        glconCharInput(ConInputChar.LineDown);
      } else {
        glconCharInput(ConInputChar.PageDown);
      }
      return true;
    case Key.Backspace: glconCharInput(ConInputChar.Backspace); return true;
    case Key.Tab: glconCharInput(ConInputChar.Tab); return true;
    case Key.Enter: glconCharInput(ConInputChar.Enter); return true;
    case Key.Delete: glconCharInput(ConInputChar.Delete); return true;
    case Key.Insert: glconCharInput(ConInputChar.Insert); return true;
    case Key.W: if (event.modifierState&ModifierState.ctrl) glconCharInput(ConInputChar.CtrlW); return true;
    case Key.Y: if (event.modifierState&ModifierState.ctrl) glconCharInput(ConInputChar.CtrlY); return true;
    default:
  }
  return true;
}


/// process character event. returns `true` if event was eaten.
public bool glconCharEvent (dchar ch) {
  if (!rConsoleVisible) {
    if (glconShowKey.length == 1 && glconShowKey[0] >= ' ' && glconShowKey[0] < 128) {
      if (ch == glconShowKey[0]) return true;
      if (ch == '`' && glconShowKey == "Grave" && conInputBuffer.length == 0) return true; // HACK!
      if (glconShowKey[0] >= 'A' && glconShowKey[0] <= 'Z' && ch >= 'a' && ch <= 'z' && glconShowKey[0] == ch-32) return true;
    }
    return false;
  }
  if (glconShowKey.length == 1 && glconShowKey[0] >= ' ' && glconShowKey[0] < 128 && ch == glconShowKey[0] && conInputBuffer.length == 0) return true; // HACK!
  if (ch == '`' && glconShowKey == "Grave" && conInputBuffer.length == 0) return true; // HACK!
  if (ch >= ' ' && ch < 127) glconCharInput(cast(char)ch);
  return true;
}


/// call this in GLConDoConsoleCommandsEvent handler
public void glconProcessEventMessage () {
  bool sendAnother = false;
  bool wasCommands = false;
  bool prevVisible = isConsoleVisible;
  {
    consoleLock();
    scope(exit) consoleUnlock();
    wasCommands = conQueueEmpty;
    conProcessQueue();
    sendAnother = !conQueueEmpty();
  }
  if (glconCtlWindow is null || glconCtlWindow.closed) return;
  if (sendAnother) glconPostDoConCommands();
  glconCallShowHideHandler();
  if (wasCommands || prevVisible || isConsoleVisible) glconPostScreenRepaint();
}


public class GLConScreenRepaintEvent {} ///
public class GLConDoConsoleCommandsEvent {} ///

__gshared GLConScreenRepaintEvent evScreenRepaint;
__gshared GLConDoConsoleCommandsEvent evDoConCommands;
public __gshared SimpleWindow glconCtlWindow; /// this window will be used to send messages
public __gshared SimpleWindow glconDrawWindow; /// if `null`, OpenGL will be used
public __gshared bool glconDrawDirect = false; /// if `true`, draw directly to glconDrawWindow, else to it's backbuffer

shared static this () {
  evScreenRepaint = new GLConScreenRepaintEvent();
  evDoConCommands = new GLConDoConsoleCommandsEvent();
  //__gshared oldccb = conInputChangedCB;
  conInputChangedCB = delegate () nothrow @trusted {
    try {
      glconPostScreenRepaint();
    } catch (Exception e) {}
    //if (oldccb !is null) oldccb();
  };
}

///
public void glconPostScreenRepaint () {
  if (glconCtlWindow !is null && !glconCtlWindow.eventQueued!GLConScreenRepaintEvent) glconCtlWindow.postEvent(evScreenRepaint);
}

///
public void glconPostScreenRepaintDelayed (int tout=35) {
  if (glconCtlWindow !is null && !glconCtlWindow.eventQueued!GLConScreenRepaintEvent) glconCtlWindow.postTimeout(evScreenRepaint, (tout < 0 ? 0 : tout));
}

///
public void glconPostDoConCommands () {
  if (glconCtlWindow !is null && !glconCtlWindow.eventQueued!GLConDoConsoleCommandsEvent) glconCtlWindow.postEvent(evDoConCommands);
}
}


// ////////////////////////////////////////////////////////////////////////// //
static public immutable ushort[256*10] glConFont10 = [
0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x3f00,0x4080,0x5280,0x4080,0x5e80,0x4c80,0x2100,0x1e00,
0x0000,0x0000,0x3f00,0x7f80,0x6d80,0x7f80,0x6180,0x7380,0x3f00,0x1e00,0x0000,0x0000,0x3b80,0x7fc0,0x7fc0,0x7fc0,0x3f80,0x1f00,0x0e00,
0x0400,0x0000,0x0400,0x0e00,0x1f00,0x3f80,0x7fc0,0x3f80,0x1f00,0x0e00,0x0400,0x0000,0x0000,0x0e00,0x1f00,0x0e00,0x3f80,0x7fc0,0x3580,
0x0400,0x0e00,0x0000,0x0400,0x0e00,0x1f00,0x3f80,0x7fc0,0x7fc0,0x3580,0x0400,0x0e00,0x0000,0x0000,0x0000,0x0000,0x0c00,0x1e00,0x1e00,
0x0c00,0x0000,0x0000,0x0000,0xffc0,0xffc0,0xffc0,0xf3c0,0xe1c0,0xe1c0,0xf3c0,0xffc0,0xffc0,0xffc0,0x0000,0x0000,0x1e00,0x3300,0x2100,
0x2100,0x3300,0x1e00,0x0000,0x0000,0xffc0,0xffc0,0xe1c0,0xccc0,0xdec0,0xdec0,0xccc0,0xe1c0,0xffc0,0xffc0,0x0000,0x0780,0x0380,0x0780,
0x3e80,0x6600,0x6600,0x6600,0x3c00,0x0000,0x0000,0x1e00,0x3300,0x3300,0x3300,0x1e00,0x0c00,0x3f00,0x0c00,0x0000,0x0400,0x0600,0x0700,
0x0500,0x0500,0x0400,0x1c00,0x3c00,0x1800,0x0000,0x0000,0x1f80,0x1f80,0x1080,0x1080,0x1180,0x3380,0x7100,0x2000,0x0000,0x0000,0x0c00,
0x6d80,0x1e00,0x7380,0x7380,0x1e00,0x6d80,0x0c00,0x0000,0x1000,0x1800,0x1c00,0x1e00,0x1f00,0x1e00,0x1c00,0x1800,0x1000,0x0000,0x0100,
0x0300,0x0700,0x0f00,0x1f00,0x0f00,0x0700,0x0300,0x0100,0x0000,0x0000,0x0c00,0x1e00,0x3f00,0x0c00,0x0c00,0x3f00,0x1e00,0x0c00,0x0000,
0x0000,0x3300,0x3300,0x3300,0x3300,0x3300,0x0000,0x3300,0x0000,0x0000,0x0000,0x3f80,0x6d80,0x6d80,0x3d80,0x0d80,0x0d80,0x0d80,0x0000,
0x0000,0x0000,0x1f00,0x3000,0x1f00,0x3180,0x1f00,0x0180,0x1f00,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x7f80,0x7f80,0x7f80,
0x0000,0x0000,0x0000,0x0c00,0x1e00,0x3f00,0x0c00,0x0c00,0x3f00,0x1e00,0x0c00,0xffc0,0x0000,0x0c00,0x1e00,0x3f00,0x0c00,0x0c00,0x0c00,
0x0c00,0x0c00,0x0000,0x0000,0x0c00,0x0c00,0x0c00,0x0c00,0x0c00,0x3f00,0x1e00,0x0c00,0x0000,0x0000,0x0000,0x0600,0x0300,0x7f80,0x0300,
0x0600,0x0000,0x0000,0x0000,0x0000,0x0000,0x1800,0x3000,0x7f80,0x3000,0x1800,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x6000,
0x6000,0x6000,0x7f80,0x0000,0x0000,0x0000,0x0000,0x1100,0x3180,0x7fc0,0x3180,0x1100,0x0000,0x0000,0x0000,0x0000,0x0000,0x0400,0x0e00,
0x1f00,0x3f80,0x7fc0,0x0000,0x0000,0x0000,0x0000,0x0000,0x7fc0,0x3f80,0x1f00,0x0e00,0x0400,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,
0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0c00,0x1e00,0x1e00,0x0c00,0x0c00,0x0000,0x0c00,0x0000,0x0000,0x0000,0x1b00,
0x1b00,0x1b00,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x1b00,0x1b00,0x7fc0,0x1b00,0x7fc0,0x1b00,0x1b00,0x0000,0x0000,0x0400,
0x1f00,0x3580,0x3400,0x1f00,0x0580,0x3580,0x1f00,0x0400,0x0000,0x0000,0x3180,0x3300,0x0600,0x0c00,0x1980,0x3180,0x0000,0x0000,0x0000,
0x0000,0x1c00,0x3300,0x3300,0x1f80,0x3300,0x3300,0x1d80,0x0000,0x0000,0x0000,0x0e00,0x0c00,0x1800,0x0000,0x0000,0x0000,0x0000,0x0000,
0x0000,0x0000,0x0600,0x0c00,0x1800,0x1800,0x1800,0x0c00,0x0600,0x0000,0x0000,0x0000,0x1800,0x0c00,0x0600,0x0600,0x0600,0x0c00,0x1800,
0x0000,0x0000,0x0000,0x0000,0x3300,0x1e00,0x7f80,0x1e00,0x3300,0x0000,0x0000,0x0000,0x0000,0x0000,0x0c00,0x0c00,0x3f00,0x0c00,0x0c00,
0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0c00,0x0c00,0x1800,0x0000,0x0000,0x0000,0x0000,0x0000,0x3f00,0x0000,
0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0c00,0x0c00,0x0000,0x0000,0x0000,0x0180,0x0300,0x0600,0x0c00,
0x1800,0x3000,0x6000,0x0000,0x0000,0x0000,0x1f00,0x3380,0x3780,0x3f80,0x3d80,0x3980,0x1f00,0x0000,0x0000,0x0000,0x0c00,0x1c00,0x0c00,
0x0c00,0x0c00,0x0c00,0x3f00,0x0000,0x0000,0x0000,0x1f00,0x3180,0x0180,0x0f00,0x1800,0x3180,0x3f80,0x0000,0x0000,0x0000,0x1f00,0x3180,
0x0180,0x0700,0x0180,0x3180,0x1f00,0x0000,0x0000,0x0000,0x0700,0x0f00,0x1b00,0x3300,0x3f80,0x0300,0x0780,0x0000,0x0000,0x0000,0x3f80,
0x3000,0x3000,0x3f00,0x0180,0x3180,0x1f00,0x0000,0x0000,0x0000,0x0f00,0x1800,0x3000,0x3f00,0x3180,0x3180,0x1f00,0x0000,0x0000,0x0000,
0x3f80,0x3180,0x0180,0x0300,0x0600,0x0c00,0x0c00,0x0000,0x0000,0x0000,0x1f00,0x3180,0x3180,0x1f00,0x3180,0x3180,0x1f00,0x0000,0x0000,
0x0000,0x1f00,0x3180,0x3180,0x1f80,0x0180,0x0300,0x1e00,0x0000,0x0000,0x0000,0x0000,0x0c00,0x0c00,0x0000,0x0000,0x0c00,0x0c00,0x0000,
0x0000,0x0000,0x0000,0x0c00,0x0c00,0x0000,0x0000,0x0c00,0x0c00,0x1800,0x0000,0x0000,0x0300,0x0600,0x0c00,0x1800,0x0c00,0x0600,0x0300,
0x0000,0x0000,0x0000,0x0000,0x0000,0x3f00,0x0000,0x3f00,0x0000,0x0000,0x0000,0x0000,0x0000,0x1800,0x0c00,0x0600,0x0300,0x0600,0x0c00,
0x1800,0x0000,0x0000,0x0000,0x1e00,0x3300,0x0300,0x0300,0x0600,0x0c00,0x0000,0x0c00,0x0000,0x0000,0x3f00,0x6180,0x6780,0x6d80,0x6780,
0x6000,0x3f00,0x0000,0x0000,0x0000,0x1f00,0x3180,0x3180,0x3f80,0x3180,0x3180,0x3180,0x0000,0x0000,0x0000,0x3f00,0x3180,0x3180,0x3f00,
0x3180,0x3180,0x3f00,0x0000,0x0000,0x0000,0x1f00,0x3180,0x3000,0x3000,0x3000,0x3180,0x1f00,0x0000,0x0000,0x0000,0x3e00,0x3300,0x3180,
0x3180,0x3180,0x3300,0x3e00,0x0000,0x0000,0x0000,0x3f80,0x3000,0x3000,0x3f00,0x3000,0x3000,0x3f80,0x0000,0x0000,0x0000,0x3f80,0x3000,
0x3000,0x3f00,0x3000,0x3000,0x3000,0x0000,0x0000,0x0000,0x1f00,0x3180,0x3000,0x3380,0x3180,0x3180,0x1f00,0x0000,0x0000,0x0000,0x3180,
0x3180,0x3180,0x3f80,0x3180,0x3180,0x3180,0x0000,0x0000,0x0000,0x1e00,0x0c00,0x0c00,0x0c00,0x0c00,0x0c00,0x1e00,0x0000,0x0000,0x0000,
0x0700,0x0300,0x0300,0x0300,0x3300,0x3300,0x1e00,0x0000,0x0000,0x0000,0x3180,0x3180,0x3300,0x3e00,0x3300,0x3180,0x3180,0x0000,0x0000,
0x0000,0x3000,0x3000,0x3000,0x3000,0x3000,0x3000,0x3f80,0x0000,0x0000,0x0000,0x6180,0x7380,0x7f80,0x6d80,0x6180,0x6180,0x6180,0x0000,
0x0000,0x0000,0x3180,0x3980,0x3d80,0x3780,0x3380,0x3180,0x3180,0x0000,0x0000,0x0000,0x1f00,0x3180,0x3180,0x3180,0x3180,0x3180,0x1f00,
0x0000,0x0000,0x0000,0x3f00,0x3180,0x3180,0x3f00,0x3000,0x3000,0x3000,0x0000,0x0000,0x0000,0x1f00,0x3180,0x3180,0x3180,0x3180,0x3380,
0x1f00,0x0380,0x0000,0x0000,0x3f00,0x3180,0x3180,0x3f00,0x3300,0x3180,0x3180,0x0000,0x0000,0x0000,0x1f00,0x3180,0x3000,0x1f00,0x0180,
0x3180,0x1f00,0x0000,0x0000,0x0000,0x7f80,0x0c00,0x0c00,0x0c00,0x0c00,0x0c00,0x0c00,0x0000,0x0000,0x0000,0x3180,0x3180,0x3180,0x3180,
0x3180,0x3180,0x1f00,0x0000,0x0000,0x0000,0x3180,0x3180,0x3180,0x3180,0x1b00,0x0e00,0x0400,0x0000,0x0000,0x0000,0x6180,0x6180,0x6180,
0x6d80,0x7f80,0x7380,0x6180,0x0000,0x0000,0x0000,0x6180,0x3300,0x1e00,0x0c00,0x1e00,0x3300,0x6180,0x0000,0x0000,0x0000,0x6180,0x6180,
0x3300,0x1e00,0x0c00,0x0c00,0x0c00,0x0000,0x0000,0x0000,0x3f80,0x0300,0x0600,0x0c00,0x1800,0x3000,0x3f80,0x0000,0x0000,0x0000,0x1e00,
0x1800,0x1800,0x1800,0x1800,0x1800,0x1e00,0x0000,0x0000,0x0000,0x6000,0x3000,0x1800,0x0c00,0x0600,0x0300,0x0000,0x0000,0x0000,0x0000,
0x1e00,0x0600,0x0600,0x0600,0x0600,0x0600,0x1e00,0x0000,0x0000,0x0000,0x0400,0x0e00,0x1b00,0x3180,0x0000,0x0000,0x0000,0x0000,0x0000,
0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0xffc0,0x0000,0x0000,0x1c00,0x0c00,0x0600,0x0000,0x0000,0x0000,0x0000,0x0000,
0x0000,0x0000,0x0000,0x0000,0x1f00,0x0180,0x1f80,0x3180,0x1f80,0x0000,0x0000,0x0000,0x3000,0x3000,0x3f00,0x3180,0x3180,0x3180,0x3f00,
0x0000,0x0000,0x0000,0x0000,0x0000,0x1f00,0x3180,0x3000,0x3180,0x1f00,0x0000,0x0000,0x0000,0x0180,0x0180,0x1f80,0x3180,0x3180,0x3180,
0x1f80,0x0000,0x0000,0x0000,0x0000,0x0000,0x1f00,0x3180,0x3f80,0x3000,0x1f00,0x0000,0x0000,0x0000,0x0f00,0x1800,0x1800,0x3e00,0x1800,
0x1800,0x1800,0x0000,0x0000,0x0000,0x0000,0x0000,0x1f80,0x3180,0x3180,0x3180,0x1f80,0x0180,0x1f00,0x0000,0x3000,0x3000,0x3f00,0x3180,
0x3180,0x3180,0x3180,0x0000,0x0000,0x0000,0x0c00,0x0000,0x1c00,0x0c00,0x0c00,0x0c00,0x1e00,0x0000,0x0000,0x0000,0x0600,0x0000,0x0e00,
0x0600,0x0600,0x0600,0x0600,0x0600,0x1c00,0x0000,0x3000,0x3000,0x3180,0x3300,0x3e00,0x3300,0x3180,0x0000,0x0000,0x0000,0x1c00,0x0c00,
0x0c00,0x0c00,0x0c00,0x0c00,0x0700,0x0000,0x0000,0x0000,0x0000,0x0000,0x3300,0x7f80,0x6d80,0x6d80,0x6180,0x0000,0x0000,0x0000,0x0000,
0x0000,0x3f00,0x3180,0x3180,0x3180,0x3180,0x0000,0x0000,0x0000,0x0000,0x0000,0x1f00,0x3180,0x3180,0x3180,0x1f00,0x0000,0x0000,0x0000,
0x0000,0x0000,0x3f00,0x3180,0x3180,0x3f00,0x3000,0x3000,0x0000,0x0000,0x0000,0x0000,0x1f80,0x3180,0x3180,0x1f80,0x0180,0x01c0,0x0000,
0x0000,0x0000,0x0000,0x3f00,0x3180,0x3000,0x3000,0x3000,0x0000,0x0000,0x0000,0x0000,0x0000,0x1f80,0x3000,0x1f00,0x0180,0x3f00,0x0000,
0x0000,0x0000,0x1800,0x1800,0x3e00,0x1800,0x1800,0x1800,0x0f00,0x0000,0x0000,0x0000,0x0000,0x0000,0x3180,0x3180,0x3180,0x3180,0x1f80,
0x0000,0x0000,0x0000,0x0000,0x0000,0x3180,0x3180,0x1b00,0x0e00,0x0400,0x0000,0x0000,0x0000,0x0000,0x0000,0x6180,0x6d80,0x6d80,0x7f80,
0x3300,0x0000,0x0000,0x0000,0x0000,0x0000,0x3180,0x1b00,0x0e00,0x1b00,0x3180,0x0000,0x0000,0x0000,0x0000,0x0000,0x3180,0x3180,0x3180,
0x1f80,0x0180,0x1f00,0x0000,0x0000,0x0000,0x0000,0x3f00,0x0600,0x0c00,0x1800,0x3f00,0x0000,0x0000,0x0000,0x0e00,0x1800,0x1800,0x3000,
0x1800,0x1800,0x0e00,0x0000,0x0000,0x0c00,0x0c00,0x0c00,0x0c00,0x0000,0x0c00,0x0c00,0x0c00,0x0c00,0x0000,0x0000,0x1c00,0x0600,0x0600,
0x0300,0x0600,0x0600,0x1c00,0x0000,0x0000,0x0000,0x0000,0x0000,0x3800,0x6d80,0x0700,0x0000,0x0000,0x0000,0x0000,0x0000,0x0400,0x0e00,
0x1b00,0x3180,0x3180,0x3180,0x3f80,0x0000,0x0000,0x0000,0x1f00,0x3180,0x3000,0x3000,0x3000,0x3180,0x1f00,0x0c00,0x1800,0x0000,0x1b00,
0x0000,0x3180,0x3180,0x3180,0x3180,0x1f80,0x0000,0x0000,0x0600,0x0c00,0x0000,0x1f00,0x3180,0x3f80,0x3000,0x1f00,0x0000,0x0000,0x0e00,
0x1b00,0x0000,0x1f00,0x0180,0x1f80,0x3180,0x1f80,0x0000,0x0000,0x0000,0x1b00,0x0000,0x1f00,0x0180,0x1f80,0x3180,0x1f80,0x0000,0x0000,
0x0c00,0x0600,0x0000,0x1f00,0x0180,0x1f80,0x3180,0x1f80,0x0000,0x0000,0x0e00,0x1b00,0x0e00,0x1f00,0x0180,0x1f80,0x3180,0x1f80,0x0000,
0x0000,0x0000,0x0000,0x0000,0x1f00,0x3180,0x3000,0x3180,0x1f00,0x0c00,0x1800,0x0e00,0x1b00,0x0000,0x1f00,0x3180,0x3f80,0x3000,0x1f00,
0x0000,0x0000,0x0000,0x1b00,0x0000,0x1f00,0x3180,0x3f80,0x3000,0x1f00,0x0000,0x0000,0x0c00,0x0600,0x0000,0x1f00,0x3180,0x3f80,0x3000,
0x1f00,0x0000,0x0000,0x0000,0x3600,0x0000,0x1c00,0x0c00,0x0c00,0x0c00,0x1e00,0x0000,0x0000,0x1c00,0x3600,0x0000,0x1c00,0x0c00,0x0c00,
0x0c00,0x1e00,0x0000,0x0000,0x1800,0x0c00,0x0000,0x1c00,0x0c00,0x0c00,0x0c00,0x1e00,0x0000,0x0000,0x0000,0x1b00,0x0000,0x1f00,0x3180,
0x3f80,0x3180,0x3180,0x0000,0x0000,0x0e00,0x1b00,0x0e00,0x1f00,0x3180,0x3f80,0x3180,0x3180,0x0000,0x0000,0x0600,0x0c00,0x0000,0x3f80,
0x3000,0x3f00,0x3000,0x3f80,0x0000,0x0000,0x0000,0x0000,0x0000,0x3b80,0x0ec0,0x3fc0,0x6e00,0x3b80,0x0000,0x0000,0x0000,0x1f80,0x3600,
0x6600,0x7f80,0x6600,0x6600,0x6780,0x0000,0x0000,0x0e00,0x1b00,0x0000,0x1f00,0x3180,0x3180,0x3180,0x1f00,0x0000,0x0000,0x0000,0x1b00,
0x0000,0x1f00,0x3180,0x3180,0x3180,0x1f00,0x0000,0x0000,0x0c00,0x0600,0x0000,0x1f00,0x3180,0x3180,0x3180,0x1f00,0x0000,0x0000,0x0e00,
0x1b00,0x0000,0x3180,0x3180,0x3180,0x3180,0x1f80,0x0000,0x0000,0x0c00,0x0600,0x0000,0x3180,0x3180,0x3180,0x3180,0x1f80,0x0000,0x0000,
0x0000,0x1b00,0x0000,0x3180,0x3180,0x3180,0x1f80,0x0180,0x1f00,0x0000,0x0000,0x1b00,0x0000,0x1f00,0x3180,0x3180,0x3180,0x1f00,0x0000,
0x0000,0x0000,0x1b00,0x0000,0x3180,0x3180,0x3180,0x3180,0x1f80,0x0000,0x0000,0x0000,0x0000,0x0400,0x1f00,0x3580,0x3400,0x3580,0x1f00,
0x0400,0x0000,0x0000,0x0f00,0x1980,0x1800,0x3e00,0x1800,0x1800,0x3000,0x3f80,0x0000,0x0000,0x6180,0x6180,0x3300,0x1e00,0x3f00,0x0c00,
0x3f00,0x0c00,0x0000,0x0000,0x7f00,0x6180,0x6d80,0x6d80,0x7f00,0x6c00,0x6c00,0x6700,0x0000,0x0000,0x0700,0x0c00,0x0c00,0x1e00,0x0c00,
0x0c00,0x0c00,0x3800,0x0000,0x0600,0x0c00,0x0000,0x1f00,0x0180,0x1f80,0x3180,0x1f80,0x0000,0x0000,0x0c00,0x1800,0x0000,0x1c00,0x0c00,
0x0c00,0x0c00,0x1e00,0x0000,0x0000,0x0600,0x0c00,0x0000,0x1f00,0x3180,0x3180,0x3180,0x1f00,0x0000,0x0000,0x0600,0x0c00,0x0000,0x3180,
0x3180,0x3180,0x3180,0x1f80,0x0000,0x0000,0x1d80,0x3700,0x0000,0x3f00,0x3180,0x3180,0x3180,0x3180,0x0000,0x0000,0x1d80,0x3700,0x0000,
0x3980,0x3d80,0x3780,0x3380,0x3180,0x0000,0x0000,0x0000,0x1e00,0x0300,0x1f00,0x3300,0x1f00,0x0000,0x0000,0x0000,0x0000,0x0000,0x1e00,
0x3300,0x3300,0x3300,0x1e00,0x0000,0x0000,0x0000,0x0000,0x0000,0x0c00,0x0000,0x0c00,0x1800,0x3000,0x3000,0x3300,0x1e00,0x0000,0x0000,
0x0000,0x0000,0x0000,0x3f80,0x3000,0x3000,0x3000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x3f80,0x0180,0x0180,0x0180,0x0000,0x0000,
0x0000,0x2080,0x2100,0x2200,0x2400,0x0b00,0x1180,0x2300,0x4380,0x0000,0x0000,0x2080,0x2100,0x2200,0x2400,0x0a80,0x1280,0x2380,0x4080,
0x0000,0x0000,0x0c00,0x0000,0x0c00,0x0c00,0x1e00,0x1e00,0x0c00,0x0000,0x0000,0x0000,0x0000,0x1980,0x3300,0x6600,0x3300,0x1980,0x0000,
0x0000,0x0000,0x0000,0x0000,0x6600,0x3300,0x1980,0x3300,0x6600,0x0000,0x0000,0x0000,0x2200,0x8880,0x2200,0x8880,0x2200,0x8880,0x2200,
0x8880,0x2200,0x8880,0x5540,0xaa80,0x5540,0xaa80,0x5540,0xaa80,0x5540,0xaa80,0x5540,0xaa80,0xbb80,0xeec0,0xbb80,0xeec0,0xbb80,0xeec0,
0xbb80,0xeec0,0xbb80,0xeec0,0x0c00,0x0c00,0x0c00,0x0c00,0x0c00,0x0c00,0x0c00,0x0c00,0x0c00,0x0c00,0x0c00,0x0c00,0x0c00,0x0c00,0xfc00,
0xfc00,0x0c00,0x0c00,0x0c00,0x0c00,0x0c00,0x0c00,0xfc00,0xfc00,0x0c00,0x0c00,0xfc00,0xfc00,0x0c00,0x0c00,0x3300,0x3300,0x3300,0x3300,
0xf300,0xf300,0x3300,0x3300,0x3300,0x3300,0x0000,0x0000,0x0000,0x0000,0xff00,0xff00,0x3300,0x3300,0x3300,0x3300,0x0000,0x0000,0xfc00,
0xfc00,0x0c00,0x0c00,0xfc00,0xfc00,0x0c00,0x0c00,0x3300,0x3300,0xf300,0xf300,0x0300,0x0300,0xf300,0xf300,0x3300,0x3300,0x3300,0x3300,
0x3300,0x3300,0x3300,0x3300,0x3300,0x3300,0x3300,0x3300,0x0000,0x0000,0xff00,0xff00,0x0300,0x0300,0xf300,0xf300,0x3300,0x3300,0x3300,
0x3300,0xf300,0xf300,0x0300,0x0300,0xff00,0xff00,0x0000,0x0000,0x3300,0x3300,0x3300,0x3300,0xff00,0xff00,0x0000,0x0000,0x0000,0x0000,
0x1800,0x1800,0xf800,0xf800,0x1800,0x1800,0xf800,0xf800,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0xfc00,0xfc00,0x0c00,0x0c00,0x0c00,
0x0c00,0x0c00,0x0c00,0x0c00,0x0c00,0x0fc0,0x0fc0,0x0000,0x0000,0x0000,0x0000,0x0c00,0x0c00,0x0c00,0x0c00,0xffc0,0xffc0,0x0000,0x0000,
0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0xffc0,0xffc0,0x0c00,0x0c00,0x0c00,0x0c00,0x0c00,0x0c00,0x0c00,0x0c00,0x0fc0,0x0fc0,0x0c00,
0x0c00,0x0c00,0x0c00,0x0000,0x0000,0x0000,0x0000,0xffc0,0xffc0,0x0000,0x0000,0x0000,0x0000,0x0c00,0x0c00,0x0c00,0x0c00,0xffc0,0xffc0,
0x0c00,0x0c00,0x0c00,0x0c00,0x0c00,0x0c00,0x0fc0,0x0fc0,0x0c00,0x0c00,0x0fc0,0x0fc0,0x0c00,0x0c00,0x3300,0x3300,0x3300,0x3300,0x33c0,
0x33c0,0x3300,0x3300,0x3300,0x3300,0x3300,0x3300,0x33c0,0x33c0,0x3000,0x3000,0x3fc0,0x3fc0,0x0000,0x0000,0x0000,0x0000,0x3fc0,0x3fc0,
0x3000,0x3000,0x33c0,0x33c0,0x3300,0x3300,0x3300,0x3300,0xf3c0,0xf3c0,0x0000,0x0000,0xffc0,0xffc0,0x0000,0x0000,0x0000,0x0000,0xffc0,
0xffc0,0x0000,0x0000,0xf3c0,0xf3c0,0x3300,0x3300,0x3300,0x3300,0x33c0,0x33c0,0x3000,0x3000,0x33c0,0x33c0,0x3300,0x3300,0x0000,0x0000,
0xffc0,0xffc0,0x0000,0x0000,0xffc0,0xffc0,0x0000,0x0000,0x3300,0x3300,0xf3c0,0xf3c0,0x0000,0x0000,0xf3c0,0xf3c0,0x3300,0x3300,0x0c00,
0x0c00,0xffc0,0xffc0,0x0000,0x0000,0xffc0,0xffc0,0x0000,0x0000,0x3300,0x3300,0x3300,0x3300,0xffc0,0xffc0,0x0000,0x0000,0x0000,0x0000,
0x0000,0x0000,0xffc0,0xffc0,0x0000,0x0000,0xffc0,0xffc0,0x0c00,0x0c00,0x0000,0x0000,0x0000,0x0000,0xffc0,0xffc0,0x3300,0x3300,0x3300,
0x3300,0x3300,0x3300,0x3300,0x3300,0x3fc0,0x3fc0,0x0000,0x0000,0x0000,0x0000,0x0c00,0x0c00,0x0fc0,0x0fc0,0x0c00,0x0c00,0x0fc0,0x0fc0,
0x0000,0x0000,0x0000,0x0000,0x0fc0,0x0fc0,0x0c00,0x0c00,0x0fc0,0x0fc0,0x0c00,0x0c00,0x0000,0x0000,0x0000,0x0000,0x3fc0,0x3fc0,0x3300,
0x3300,0x3300,0x3300,0x3300,0x3300,0x3300,0x3300,0xf3c0,0xf3c0,0x3300,0x3300,0x3300,0x3300,0x0c00,0x0c00,0xffc0,0xffc0,0x0000,0x0000,
0xffc0,0xffc0,0x0c00,0x0c00,0x0c00,0x0c00,0x0c00,0x0c00,0xfc00,0xfc00,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0fc0,
0x0fc0,0x0c00,0x0c00,0x0c00,0x0c00,0xffc0,0xffc0,0xffc0,0xffc0,0xffc0,0xffc0,0xffc0,0xffc0,0xffc0,0xffc0,0x0000,0x0000,0x0000,0x0000,
0x0000,0xffc0,0xffc0,0xffc0,0xffc0,0xffc0,0xf800,0xf800,0xf800,0xf800,0xf800,0xf800,0xf800,0xf800,0xf800,0xf800,0x07c0,0x07c0,0x07c0,
0x07c0,0x07c0,0x07c0,0x07c0,0x07c0,0x07c0,0x07c0,0xffc0,0xffc0,0xffc0,0xffc0,0xffc0,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,
0x0000,0x1d80,0x3700,0x3200,0x3700,0x1d80,0x0000,0x0000,0x0000,0x1e00,0x3300,0x3300,0x3600,0x3300,0x3180,0x3700,0x3000,0x0000,0x0000,
0x3f80,0x3180,0x3000,0x3000,0x3000,0x3000,0x3000,0x0000,0x0000,0x0000,0x0000,0x7f80,0x3300,0x3300,0x3300,0x3300,0x3300,0x0000,0x0000,
0x0000,0x3f80,0x1800,0x0c00,0x0600,0x0c00,0x1800,0x3f80,0x0000,0x0000,0x0000,0x0000,0x0000,0x1f80,0x3600,0x3300,0x3300,0x1e00,0x0000,
0x0000,0x0000,0x0000,0x0000,0x6300,0x6300,0x6700,0x7d80,0x6000,0x6000,0x0000,0x0000,0x0000,0x0000,0x3f00,0x0c00,0x0c00,0x0c00,0x0600,
0x0000,0x0000,0x0000,0x1e00,0x0c00,0x3f00,0x6d80,0x6d80,0x3f00,0x0c00,0x1e00,0x0000,0x0000,0x1e00,0x3300,0x3300,0x3f00,0x3300,0x3300,
0x1e00,0x0000,0x0000,0x0000,0x1f00,0x3180,0x3180,0x3180,0x3180,0x1b00,0x3b80,0x0000,0x0000,0x0000,0x1f00,0x0c00,0x0600,0x1f00,0x3180,
0x3180,0x1f00,0x0000,0x0000,0x0000,0x0000,0x0000,0x3b80,0x66c0,0x64c0,0x6cc0,0x3b80,0x0000,0x0000,0x0000,0x0000,0x0180,0x3f00,0x6780,
0x6d80,0x7980,0x3f00,0x6000,0x0000,0x0000,0x0000,0x0000,0x1f00,0x3000,0x1e00,0x3000,0x1f00,0x0000,0x0000,0x0000,0x1f00,0x3180,0x3180,
0x3180,0x3180,0x3180,0x3180,0x0000,0x0000,0x0000,0x0000,0x3f00,0x0000,0x3f00,0x0000,0x3f00,0x0000,0x0000,0x0000,0x0000,0x0c00,0x0c00,
0x3f00,0x0c00,0x0c00,0x0000,0x3f00,0x0000,0x0000,0x0000,0x0600,0x0c00,0x1800,0x0c00,0x0600,0x0000,0x3f00,0x0000,0x0000,0x0000,0x1800,
0x0c00,0x0600,0x0c00,0x1800,0x0000,0x3f00,0x0000,0x0000,0x0000,0x0700,0x0d80,0x0d80,0x0c00,0x0c00,0x0c00,0x0c00,0x0c00,0x0c00,0x0c00,
0x0c00,0x0c00,0x0c00,0x0c00,0x0c00,0x6c00,0x6c00,0x3800,0x0000,0x0000,0x0000,0x0c00,0x0000,0x3f00,0x0000,0x0c00,0x0000,0x0000,0x0000,
0x0000,0x3800,0x6d80,0x0700,0x0000,0x3800,0x6d80,0x0700,0x0000,0x0000,0x0000,0x0e00,0x1b00,0x1b00,0x0e00,0x0000,0x0000,0x0000,0x0000,
0x0000,0x0000,0x0000,0x0000,0x0c00,0x0c00,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0c00,0x0000,0x0000,0x0000,
0x0000,0x0000,0x0000,0x07c0,0x0600,0x0600,0x6600,0x3600,0x1e00,0x0e00,0x0600,0x0200,0x0000,0x3e00,0x3300,0x3300,0x3300,0x3300,0x0000,
0x0000,0x0000,0x0000,0x0000,0x1e00,0x0300,0x0e00,0x1800,0x1f00,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x1e00,0x1e00,0x1e00,
0x1e00,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,
];


// ////////////////////////////////////////////////////////////////////////// //
version(none)
private nothrow @nogc {

version(Windows) {
  pragma(lib, "opengl32");
  private void* glbindGetProcAddress (const(char)* name) {
    import core.sys.windows.wingdi : wglGetProcAddress;
    void* res = wglGetProcAddress(name);
    if (res is null) {
      import core.sys.windows.windef, core.sys.windows.winbase;
      static HINSTANCE dll = null;
      if (dll is null) {
        dll = LoadLibraryA("opengl32.dll");
        if (dll is null) return null; // <32, but idc
      }
      return GetProcAddress(dll, name);
    }
    return res;
  }
} else {
  pragma(lib, "GL");
  extern(C) {
    void* glXGetProcAddress (const(char)* name);
    alias glbindGetProcAddress = glXGetProcAddress;
  }
}

bool glHasFunction (const(char)[] name) {
  if (name.length == 0 || name.length > 255) return false; // arbitrary limit
  char[256] xname = 0;
  xname[0..name.length] = name[];
  return (glbindGetProcAddress(xname.ptr) !is null);
}

// convenient template checker
bool glHasFunc(string name) () {
  static int flag = -1;
  if (flag < 0) flag = (glHasFunction(name) ? 1 : 0);
  return (flag == 1);
}


extern(System):
alias GLvoid = void;
alias GLintptr = ptrdiff_t;
alias GLsizei = int;
alias GLchar = char;
alias GLcharARB = byte;
alias GLushort = ushort;
alias GLint64EXT = long;
alias GLshort = short;
alias GLuint64 = ulong;
alias GLhalfARB = ushort;
alias GLubyte = ubyte;
alias GLdouble = double;
alias GLhandleARB = uint;
alias GLint64 = long;
alias GLenum = uint;
alias GLeglImageOES = void*;
alias GLintptrARB = ptrdiff_t;
alias GLsizeiptr = ptrdiff_t;
alias GLint = int;
alias GLboolean = ubyte;
alias GLbitfield = uint;
alias GLsizeiptrARB = ptrdiff_t;
alias GLfloat = float;
alias GLuint64EXT = ulong;
alias GLclampf = float;
alias GLbyte = byte;
alias GLclampd = double;
alias GLuint = uint;
alias GLvdpauSurfaceNV = ptrdiff_t;
alias GLfixed = int;
alias GLhalf = ushort;
alias GLclampx = int;
alias GLhalfNV = ushort;

enum uint GL_QUADS = 0x0007;
enum uint GL_LIGHTING = 0x0B50;
enum uint GL_DITHER = 0x0BD0;
enum uint GL_DEPTH_TEST = 0x0B71;
enum uint GL_BLEND = 0x0BE2;
enum uint GL_STENCIL_TEST = 0x0B90;
enum uint GL_MATRIX_MODE = 0x0BA0;
enum uint GL_VIEWPORT = 0x0BA2;
enum uint GL_TEXTURE_2D = 0x0DE1;
enum uint GL_UNSIGNED_BYTE = 0x1401;
enum uint GL_MODELVIEW = 0x1700;
enum uint GL_PROJECTION = 0x1701;
enum uint GL_TEXTURE = 0x1702;
enum uint GL_COLOR = 0x1800;
enum uint GL_RGBA = 0x1908;
enum uint GL_BGRA = 0x80E1;
enum uint GL_NEAREST = 0x2600;
enum uint GL_TEXTURE_MAG_FILTER = 0x2800;
enum uint GL_TEXTURE_MIN_FILTER = 0x2801;
enum uint GL_TEXTURE_WRAP_S = 0x2802;
enum uint GL_TEXTURE_WRAP_T = 0x2803;
enum uint GL_REPEAT = 0x2901;
enum uint GL_TEXTURE_BINDING_2D = 0x8069;
enum uint GL_TEXTURE_CUBE_MAP = 0x8513;
enum uint GL_CURRENT_PROGRAM = 0x8B8D;
enum uint GL_DRAW_FRAMEBUFFER_BINDING = 0x8CA6;
enum uint GL_READ_FRAMEBUFFER_EXT = 0x8CA8;
enum uint GL_DRAW_FRAMEBUFFER_EXT = 0x8CA9;
enum uint GL_READ_FRAMEBUFFER_BINDING = 0x8CAA;
enum uint GL_FRAMEBUFFER_EXT = 0x8D40;
enum uint GL_ALL_ATTRIB_BITS = 0xFFFFFFFF;
enum uint GL_SRC_ALPHA = 0x0302;
enum uint GL_ONE_MINUS_SRC_ALPHA = 0x0303;

alias glbfn_glDeleteTextures = void function(GLsizei, const(GLuint)*);
alias glbfn_glGenTextures = void function(GLsizei, GLuint*);
alias glbfn_glGetIntegerv = void function(GLenum, GLint*);
alias glbfn_glBindTexture = void function(GLenum, GLuint);
alias glbfn_glTexParameterf = void function(GLenum, GLenum, GLfloat);
alias glbfn_glTexParameterfv = void function(GLenum, GLenum, const(GLfloat)*);
alias glbfn_glTexParameteri = void function(GLenum, GLenum, GLint);
alias glbfn_glTexImage2D = void function(GLenum, GLint, GLint, GLsizei, GLsizei, GLint, GLenum, GLenum, const(void)*);
alias glbfn_glMatrixMode = void function(GLenum);
alias glbfn_glPopMatrix = void function();
alias glbfn_glPushMatrix = void function();
alias glbfn_glPopAttrib = void function();
alias glbfn_glPushAttrib = void function(GLbitfield);
alias glbfn_glBindFramebufferEXT = void function(GLenum, GLuint);
alias glbfn_glUseProgram = void function(GLuint);
alias glbfn_glViewport = void function(GLint, GLint, GLsizei, GLsizei);
alias glbfn_glLoadIdentity = void function();
alias glbfn_glOrtho = void function(GLdouble, GLdouble, GLdouble, GLdouble, GLdouble, GLdouble);
alias glbfn_glDisable = void function(GLenum);
alias glbfn_glEnable = void function(GLenum);
alias glbfn_glBlendFunc = void function(GLenum, GLenum);
alias glbfn_glTexSubImage2D = void function(GLenum, GLint, GLint, GLint, GLsizei, GLsizei, GLenum, GLenum, const(void)*);
alias glbfn_glColor4f = void function(GLfloat, GLfloat, GLfloat, GLfloat);
alias glbfn_glBegin = void function(GLenum);
alias glbfn_glEnd = void function();
alias glbfn_glTexCoord2f = void function(GLfloat, GLfloat);
alias glbfn_glVertex2i = void function(GLint, GLint);

__gshared glbfn_glDeleteTextures glDeleteTextures = function void (int a0, const(uint)* a1) nothrow @nogc {
  glbfn_glDeleteTextures_loader(a0,a1,);
};
private auto glbfn_glDeleteTextures_loader (int a0, const(uint)* a1) nothrow @nogc {
  glDeleteTextures = cast(glbfn_glDeleteTextures)glbindGetProcAddress(`glDeleteTextures`);
  if (glDeleteTextures is null) assert(0, `OpenGL function 'glDeleteTextures' not found!`);
  glDeleteTextures(a0,a1,);
}
__gshared glbfn_glGenTextures glGenTextures = function void (int a0, uint* a1) nothrow @nogc {
  glbfn_glGenTextures_loader(a0,a1,);
};
private auto glbfn_glGenTextures_loader (int a0, uint* a1) nothrow @nogc {
  glGenTextures = cast(glbfn_glGenTextures)glbindGetProcAddress(`glGenTextures`);
  if (glGenTextures is null) assert(0, `OpenGL function 'glGenTextures' not found!`);
  glGenTextures(a0,a1,);
}
__gshared glbfn_glGetIntegerv glGetIntegerv = function void (uint a0, int* a1) nothrow @nogc {
  glbfn_glGetIntegerv_loader(a0,a1,);
};
private auto glbfn_glGetIntegerv_loader (uint a0, int* a1) nothrow @nogc {
  glGetIntegerv = cast(glbfn_glGetIntegerv)glbindGetProcAddress(`glGetIntegerv`);
  if (glGetIntegerv is null) assert(0, `OpenGL function 'glGetIntegerv' not found!`);
  glGetIntegerv(a0,a1,);
}
__gshared glbfn_glBindTexture glBindTexture = function void (uint a0, uint a1) nothrow @nogc {
  glbfn_glBindTexture_loader(a0,a1,);
};
private auto glbfn_glBindTexture_loader (uint a0, uint a1) nothrow @nogc {
  glBindTexture = cast(glbfn_glBindTexture)glbindGetProcAddress(`glBindTexture`);
  if (glBindTexture is null) assert(0, `OpenGL function 'glBindTexture' not found!`);
  glBindTexture(a0,a1,);
}
__gshared glbfn_glTexParameterf glTexParameterf = function void (uint a0, uint a1, float a2) nothrow @nogc {
  glbfn_glTexParameterf_loader(a0,a1,a2,);
};
private auto glbfn_glTexParameterf_loader (uint a0, uint a1, float a2) nothrow @nogc {
  glTexParameterf = cast(glbfn_glTexParameterf)glbindGetProcAddress(`glTexParameterf`);
  if (glTexParameterf is null) assert(0, `OpenGL function 'glTexParameterf' not found!`);
  glTexParameterf(a0,a1,a2,);
}
__gshared glbfn_glTexParameterfv glTexParameterfv = function void (uint a0, uint a1, const(float)* a2) nothrow @nogc {
  glbfn_glTexParameterfv_loader(a0,a1,a2,);
};
private auto glbfn_glTexParameterfv_loader (uint a0, uint a1, const(float)* a2) nothrow @nogc {
  glTexParameterfv = cast(glbfn_glTexParameterfv)glbindGetProcAddress(`glTexParameterfv`);
  if (glTexParameterfv is null) assert(0, `OpenGL function 'glTexParameterfv' not found!`);
  glTexParameterfv(a0,a1,a2,);
}
__gshared glbfn_glTexParameteri glTexParameteri = function void (uint a0, uint a1, int a2) nothrow @nogc {
  glbfn_glTexParameteri_loader(a0,a1,a2,);
};
private auto glbfn_glTexParameteri_loader (uint a0, uint a1, int a2) nothrow @nogc {
  glTexParameteri = cast(glbfn_glTexParameteri)glbindGetProcAddress(`glTexParameteri`);
  if (glTexParameteri is null) assert(0, `OpenGL function 'glTexParameteri' not found!`);
  glTexParameteri(a0,a1,a2,);
}
__gshared glbfn_glTexImage2D glTexImage2D = function void (uint a0, int a1, int a2, int a3, int a4, int a5, uint a6, uint a7, const(void)* a8) nothrow @nogc {
  glbfn_glTexImage2D_loader(a0,a1,a2,a3,a4,a5,a6,a7,a8,);
};
private auto glbfn_glTexImage2D_loader (uint a0, int a1, int a2, int a3, int a4, int a5, uint a6, uint a7, const(void)* a8) nothrow @nogc {
  glTexImage2D = cast(glbfn_glTexImage2D)glbindGetProcAddress(`glTexImage2D`);
  if (glTexImage2D is null) assert(0, `OpenGL function 'glTexImage2D' not found!`);
  glTexImage2D(a0,a1,a2,a3,a4,a5,a6,a7,a8,);
}
__gshared glbfn_glMatrixMode glMatrixMode = function void (uint a0) nothrow @nogc {
  glbfn_glMatrixMode_loader(a0,);
};
private auto glbfn_glMatrixMode_loader (uint a0) nothrow @nogc {
  glMatrixMode = cast(glbfn_glMatrixMode)glbindGetProcAddress(`glMatrixMode`);
  if (glMatrixMode is null) assert(0, `OpenGL function 'glMatrixMode' not found!`);
  glMatrixMode(a0,);
}
__gshared glbfn_glPopMatrix glPopMatrix = function void () nothrow @nogc {
  glbfn_glPopMatrix_loader();
};
private auto glbfn_glPopMatrix_loader () nothrow @nogc {
  glPopMatrix = cast(glbfn_glPopMatrix)glbindGetProcAddress(`glPopMatrix`);
  if (glPopMatrix is null) assert(0, `OpenGL function 'glPopMatrix' not found!`);
  glPopMatrix();
}
__gshared glbfn_glPushMatrix glPushMatrix = function void () nothrow @nogc {
  glbfn_glPushMatrix_loader();
};
private auto glbfn_glPushMatrix_loader () nothrow @nogc {
  glPushMatrix = cast(glbfn_glPushMatrix)glbindGetProcAddress(`glPushMatrix`);
  if (glPushMatrix is null) assert(0, `OpenGL function 'glPushMatrix' not found!`);
  glPushMatrix();
}
__gshared glbfn_glPopAttrib glPopAttrib = function void () nothrow @nogc {
  glbfn_glPopAttrib_loader();
};
private auto glbfn_glPopAttrib_loader () nothrow @nogc {
  glPopAttrib = cast(glbfn_glPopAttrib)glbindGetProcAddress(`glPopAttrib`);
  if (glPopAttrib is null) assert(0, `OpenGL function 'glPopAttrib' not found!`);
  glPopAttrib();
}
__gshared glbfn_glPushAttrib glPushAttrib = function void (uint a0) nothrow @nogc {
  glbfn_glPushAttrib_loader(a0,);
};
private auto glbfn_glPushAttrib_loader (uint a0) nothrow @nogc {
  glPushAttrib = cast(glbfn_glPushAttrib)glbindGetProcAddress(`glPushAttrib`);
  if (glPushAttrib is null) assert(0, `OpenGL function 'glPushAttrib' not found!`);
  glPushAttrib(a0,);
}
__gshared glbfn_glBindFramebufferEXT glBindFramebufferEXT = function void (uint a0, uint a1) nothrow @nogc {
  glbfn_glBindFramebufferEXT_loader(a0,a1,);
};
private auto glbfn_glBindFramebufferEXT_loader (uint a0, uint a1) nothrow @nogc {
  glBindFramebufferEXT = cast(glbfn_glBindFramebufferEXT)glbindGetProcAddress(`glBindFramebufferEXT`);
  if (glBindFramebufferEXT is null) assert(0, `OpenGL function 'glBindFramebufferEXT' not found!`);
  glBindFramebufferEXT(a0,a1,);
}
__gshared glbfn_glUseProgram glUseProgram = function void (uint a0) nothrow @nogc {
  glbfn_glUseProgram_loader(a0,);
};
private auto glbfn_glUseProgram_loader (uint a0) nothrow @nogc {
  glUseProgram = cast(glbfn_glUseProgram)glbindGetProcAddress(`glUseProgram`);
  if (glUseProgram is null) assert(0, `OpenGL function 'glUseProgram' not found!`);
  glUseProgram(a0,);
}
__gshared glbfn_glViewport glViewport = function void (int a0, int a1, int a2, int a3) nothrow @nogc {
  glbfn_glViewport_loader(a0,a1,a2,a3,);
};
private auto glbfn_glViewport_loader (int a0, int a1, int a2, int a3) nothrow @nogc {
  glViewport = cast(glbfn_glViewport)glbindGetProcAddress(`glViewport`);
  if (glViewport is null) assert(0, `OpenGL function 'glViewport' not found!`);
  glViewport(a0,a1,a2,a3,);
}
__gshared glbfn_glLoadIdentity glLoadIdentity = function void () nothrow @nogc {
  glbfn_glLoadIdentity_loader();
};
private auto glbfn_glLoadIdentity_loader () nothrow @nogc {
  glLoadIdentity = cast(glbfn_glLoadIdentity)glbindGetProcAddress(`glLoadIdentity`);
  if (glLoadIdentity is null) assert(0, `OpenGL function 'glLoadIdentity' not found!`);
  glLoadIdentity();
}
__gshared glbfn_glOrtho glOrtho = function void (double a0, double a1, double a2, double a3, double a4, double a5) nothrow @nogc {
  glbfn_glOrtho_loader(a0,a1,a2,a3,a4,a5,);
};
private auto glbfn_glOrtho_loader (double a0, double a1, double a2, double a3, double a4, double a5) nothrow @nogc {
  glOrtho = cast(glbfn_glOrtho)glbindGetProcAddress(`glOrtho`);
  if (glOrtho is null) assert(0, `OpenGL function 'glOrtho' not found!`);
  glOrtho(a0,a1,a2,a3,a4,a5,);
}
__gshared glbfn_glDisable glDisable = function void (uint a0) nothrow @nogc {
  glbfn_glDisable_loader(a0,);
};
private auto glbfn_glDisable_loader (uint a0) nothrow @nogc {
  glDisable = cast(glbfn_glDisable)glbindGetProcAddress(`glDisable`);
  if (glDisable is null) assert(0, `OpenGL function 'glDisable' not found!`);
  glDisable(a0,);
}
__gshared glbfn_glEnable glEnable = function void (uint a0) nothrow @nogc {
  glbfn_glEnable_loader(a0,);
};
private auto glbfn_glEnable_loader (uint a0) nothrow @nogc {
  glEnable = cast(glbfn_glEnable)glbindGetProcAddress(`glEnable`);
  if (glEnable is null) assert(0, `OpenGL function 'glEnable' not found!`);
  glEnable(a0,);
}
__gshared glbfn_glBlendFunc glBlendFunc = function void (uint a0, uint a1) nothrow @nogc {
  glbfn_glBlendFunc_loader(a0,a1,);
};
private auto glbfn_glBlendFunc_loader (uint a0, uint a1) nothrow @nogc {
  glBlendFunc = cast(glbfn_glBlendFunc)glbindGetProcAddress(`glBlendFunc`);
  if (glBlendFunc is null) assert(0, `OpenGL function 'glBlendFunc' not found!`);
  glBlendFunc(a0,a1,);
}
__gshared glbfn_glTexSubImage2D glTexSubImage2D = function void (uint a0, int a1, int a2, int a3, int a4, int a5, uint a6, uint a7, const(void)* a8) nothrow @nogc {
  glbfn_glTexSubImage2D_loader(a0,a1,a2,a3,a4,a5,a6,a7,a8,);
};
private auto glbfn_glTexSubImage2D_loader (uint a0, int a1, int a2, int a3, int a4, int a5, uint a6, uint a7, const(void)* a8) nothrow @nogc {
  glTexSubImage2D = cast(glbfn_glTexSubImage2D)glbindGetProcAddress(`glTexSubImage2D`);
  if (glTexSubImage2D is null) assert(0, `OpenGL function 'glTexSubImage2D' not found!`);
  glTexSubImage2D(a0,a1,a2,a3,a4,a5,a6,a7,a8,);
}
__gshared glbfn_glColor4f glColor4f = function void (float a0, float a1, float a2, float a3) nothrow @nogc {
  glbfn_glColor4f_loader(a0,a1,a2,a3,);
};
private auto glbfn_glColor4f_loader (float a0, float a1, float a2, float a3) nothrow @nogc {
  glColor4f = cast(glbfn_glColor4f)glbindGetProcAddress(`glColor4f`);
  if (glColor4f is null) assert(0, `OpenGL function 'glColor4f' not found!`);
  glColor4f(a0,a1,a2,a3,);
}
__gshared glbfn_glBegin glBegin = function void (uint a0) nothrow @nogc {
  glbfn_glBegin_loader(a0,);
};
private auto glbfn_glBegin_loader (uint a0) nothrow @nogc {
  glBegin = cast(glbfn_glBegin)glbindGetProcAddress(`glBegin`);
  if (glBegin is null) assert(0, `OpenGL function 'glBegin' not found!`);
  glBegin(a0,);
}
__gshared glbfn_glEnd glEnd = function void () nothrow @nogc {
  glbfn_glEnd_loader();
};
private auto glbfn_glEnd_loader () nothrow @nogc {
  glEnd = cast(glbfn_glEnd)glbindGetProcAddress(`glEnd`);
  if (glEnd is null) assert(0, `OpenGL function 'glEnd' not found!`);
  glEnd();
}
__gshared glbfn_glTexCoord2f glTexCoord2f = function void (float a0, float a1) nothrow @nogc {
  glbfn_glTexCoord2f_loader(a0,a1,);
};
private auto glbfn_glTexCoord2f_loader (float a0, float a1) nothrow @nogc {
  glTexCoord2f = cast(glbfn_glTexCoord2f)glbindGetProcAddress(`glTexCoord2f`);
  if (glTexCoord2f is null) assert(0, `OpenGL function 'glTexCoord2f' not found!`);
  glTexCoord2f(a0,a1,);
}
__gshared glbfn_glVertex2i glVertex2i = function void (int a0, int a1) nothrow @nogc {
  glbfn_glVertex2i_loader(a0,a1,);
};
private auto glbfn_glVertex2i_loader (int a0, int a1) nothrow @nogc {
  glVertex2i = cast(glbfn_glVertex2i)glbindGetProcAddress(`glVertex2i`);
  if (glVertex2i is null) assert(0, `OpenGL function 'glVertex2i' not found!`);
  glVertex2i(a0,a1,);
}

} else {
  import iv.glbinds;
}


// ////////////////////////////////////////////////////////////////////////// //
/+
extern(C) nothrow @trusted @nogc {
  Status XInitImage (XImage* image);
}

private extern(C) nothrow @trusted @nogc {
  import core.stdc.config : c_long, c_ulong;

  XImage* glcon_xxsimple_create_image (XDisplay* display, Visual* visual, uint depth, int format, int offset, ubyte* data, uint width, uint height, int bitmap_pad, int bytes_per_line) {
    //return XCreateImage(display, visual, depth, format, offset, data, width, height, bitmap_pad, bytes_per_line);
    return null;
  }

  int glcon_xxsimple_destroy_image (XImage* ximg) {
    ximg.data = null;
    ximg.width = ximg.height = 0;
    return 0;
  }

  c_ulong glcon_xxsimple_get_pixel (XImage* ximg, int x, int y) {
    if (ximg.data is null) return 0;
    if (x < 0 || y < 0 || x >= ximg.width || y >= ximg.height) return 0;
    auto buf = cast(const(uint)*)ximg.data;
    //uint v = buf[y*ximg.width+x];
    //v = (v&0xff_00ff00u)|((v>>16)&0x00_0000ffu)|((v<<16)&0x00_ff0000u);
    //return v;
    return buf[y*ximg.width+x];
  }

  int glcon_xxsimple_put_pixel (XImage* ximg, int x, int y, c_ulong clr) {
    return 0;
  }

  XImage* glcon_xxsimple_sub_image (XImage* ximg, int x, int y, uint wdt, uint hgt) {
    return null;
  }

  int glcon_xxsimple_add_pixel (XImage* ximg, c_long clr) {
    return 0;
  }

  // create "simple" XImage with allocated buffer
  void glcon_ximageInitSimple (ref XImage handle, int width, int height, void* data) {
    handle.width = width;
    handle.height = height;
    handle.xoffset = 0;
    handle.format = ImageFormat.ZPixmap;
    handle.data = data;
    handle.byte_order = 0;
    handle.bitmap_unit = 0;
    handle.bitmap_bit_order = 0;
    handle.bitmap_pad = 0;
    handle.depth = 24;
    handle.bytes_per_line = 0;
    handle.bits_per_pixel = 0; // THIS MATTERS!
    handle.red_mask = 0;
    handle.green_mask = 0;
    handle.blue_mask = 0;

    handle.obdata = null;
    handle.f.create_image = &glcon_xxsimple_create_image;
    handle.f.destroy_image = &glcon_xxsimple_destroy_image;
    handle.f.get_pixel = &glcon_xxsimple_get_pixel;
    handle.f.put_pixel = &glcon_xxsimple_put_pixel;
    handle.f.sub_image = &glcon_xxsimple_sub_image;
    handle.f.add_pixel = &glcon_xxsimple_add_pixel;
  }
}
+/
