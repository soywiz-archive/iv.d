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
module iv.cmdcon.gl /*is aliced*/;
private:

import iv.alice;
public import iv.cmdcon;
import iv.vfs;
import iv.strex;
import iv.pxclock;

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
  conRegVar!rConsoleVisible("r_console", "console visibility"/*, ConVarAttr.Archive*/);
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
  scrhgt = 0;
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
    if (rConsoleHeight > 0 && scrhgt > 0) rConsoleHeight = cast(int)(cast(double)rConsoleHeight/cast(double)scrhgt*cast(double)ascrhgt);
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
    if (scrhgt == 0) scrhgt = 600;
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
  if (glconRenderFailed || scrhgt == 0) return false;

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

  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, nextPOTU32(scrwdt), nextPOTU32(scrhgt), 0, /*GL_RGBA*/GL_BGRA, GL_UNSIGNED_BYTE, null); // this creates texture
  glTexSubImage2D(GL_TEXTURE_2D, 0, 0/*x*/, 0/*y*/, scrwdt, scrhgt, /*GL_RGBA*/GL_BGRA, GL_UNSIGNED_BYTE, convbuf); // this updates texture

  //{ import core.stdc.stdio; printf("glconGenTexture: yep\n"); }
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
  if (!rConsoleVisible || scrhgt == 0) return;

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

  immutable float gtx1 = cast(float)scrwdt/nextPOTU32(scrwdt);
  immutable float gty1 = cast(float)scrhgt/nextPOTU32(scrhgt);

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
  glDisable(GL_SCISSOR_TEST);
  glDisable(GL_CULL_FACE);
  glDisable(GL_POLYGON_OFFSET_FILL);
  glDisable(GL_ALPHA_TEST);
  glDisable(GL_FOG);
  glDisable(GL_COLOR_LOGIC_OP);
  glDisable(GL_INDEX_LOGIC_OP);
  glDisable(GL_POLYGON_SMOOTH);

  glBindTexture(GL_TEXTURE_2D, convbufTexId);
  if (updatetex) {
    //glTextureSubImage2D(convbufTexId, 0, 0/*x*/, 0/*y*/, scrwdt, scrhgt, GL_RGBA, GL_UNSIGNED_BYTE, convbuf);
    glTexSubImage2D(GL_TEXTURE_2D, 0, 0/*x*/, 0/*y*/, scrwdt, scrhgt, /*GL_RGBA*/GL_BGRA, GL_UNSIGNED_BYTE, convbuf);
    //{ import core.stdc.stdio; printf("glconDraw: yep (%u)\n", convbufTexId); }
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
    glTexCoord2f(gtx1, 0.0f); glVertex2i(w, y); // top-right
    glTexCoord2f(gtx1, gty1); glVertex2i(w, h); // bottom-right
    glTexCoord2f(0.0f, gty1); glVertex2i(x, h); // bottom-left
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
  if (!forced && (conLastChange == cbufLastChange && conLastIBChange == conInputLastChange) || scrhgt == 0) return false;

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

  foreach (/*auto*/ line; conbufLinesRev) {
    putLine(line);
    if (y+conCharHeight <= 0) break;
  }

  return true;
}


// ////////////////////////////////////////////////////////////////////////// //
static if (OptCmdConGlHasSdpy) {
import arsd.simpledisplay : KeyEvent, MouseEvent, Key, ModifierState, SimpleWindow;
version(Posix) {
  import arsd.simpledisplay : Pixmap, XImage, XDisplay, Visual, XPutImage, ImageFormat, Drawable, Status, XInitImage;
  import arsd.simpledisplay : GC, XCreateGC, XFreeGC, XCopyGC, XSetClipMask, DefaultGC, DefaultScreen, None;
}

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
public void glconPostDoConCommands(bool checkempty=false) () {
  static if (checkempty) {
    {
      consoleLock();
      scope(exit) consoleUnlock();
      if (conQueueEmpty()) return;
    }
  }
  if (glconCtlWindow !is null && !glconCtlWindow.eventQueued!GLConDoConsoleCommandsEvent) glconCtlWindow.postEvent(evDoConCommands);
}


// ////////////////////////////////////////////////////////////////////////// //
public __gshared bool glconTranslateKeypad = true; /// translate keypad keys to "normal" keys?
public __gshared bool glconTranslateMods = true; /// translate right modifiers "normal" modifiers?
public __gshared bool glconNoMouseEventsWhenConsoleIsVisible = true; ///

public __gshared void delegate () oglSetupDG; /// called when window will become visible for the first time
public __gshared bool delegate () closeQueryDG; /// called when window will going to be closed; return `false` to prevent closing
public __gshared void delegate () redrawFrameDG; /// frame need to be redrawn (but not rebuilt)
public __gshared void delegate () nextFrameDG; /// frame need to be rebuilt (but not redrawn)
public __gshared void delegate (KeyEvent event) keyEventDG; ///
public __gshared void delegate (MouseEvent event) mouseEventDG; ///
public __gshared void delegate (dchar ch) charEventDG; ///
public __gshared void delegate (int wdt, int hgt) resizeEventDG; ///
public __gshared void delegate (bool focused) focusEventDG; ///


// ////////////////////////////////////////////////////////////////////////// //
private void glconRunGLWindowInternal (int wdt, int hgt, string title, string klass, bool resizeable) {
  import arsd.simpledisplay : sdpyWindowClass, OpenGlOptions, Resizability, flushGui;
  if (klass !is null) sdpyWindowClass = klass;
  auto sdwin = new SimpleWindow(wdt, hgt, title, OpenGlOptions.yes, (resizeable ? Resizability.allowResizing : Resizability.fixedSize));
  glconSetupForGLWindow(sdwin);
  sdwin.eventLoop(0);
  flushGui();
  conProcessQueue(int.max/4);
}


// ////////////////////////////////////////////////////////////////////////// //
///
public void glconRunGLWindow (int wdt, int hgt, string title, string klass=null) {
  glconRunGLWindowInternal(wdt, hgt, title, klass, false);
}

///
public void glconRunGLWindowResizeable (int wdt, int hgt, string title, string klass=null) {
  glconRunGLWindowInternal(wdt, hgt, title, klass, true);
}


// ////////////////////////////////////////////////////////////////////////// //
private __gshared int glconFPS = 30;
private __gshared double nextFrameTime = 0; // in msecs

public void glconSetAndSealFPS (int fps) {
  if (fps < 1) fps = 1; else if (fps > 200) fps = 200;
  glconFPS = fps;
  conSealVar("r_fps");
}


private final class NextFrameEvent {}
private __gshared NextFrameEvent eventNextFrame;
private shared static this () {
  eventNextFrame = new NextFrameEvent();
  conRegVar!glconFPS(1, 200, "r_fps", "frames per second (affects both rendering and processing)");
  // use `conSealVar("r_fps")` to seal it
}

/// call this to reset frame timer, and immediately post "rebuild frame" event
// called automatically when window is shown, if `glconSetupForGLWindow()` is used
public void glconResetNextFrame () {
  nextFrameTime = 0;
  glconPostNextFrame();
}

/// usually will be called automatically
public void glconPostNextFrame () {
  import iv.pxclock;
  if (glconCtlWindow.eventQueued!NextFrameEvent) return;
  ulong nft = cast(ulong)nextFrameTime;
  auto ctime = clockMilli();
  if (nft > 0 && nft > ctime) {
    glconCtlWindow.postTimeout(eventNextFrame, cast(uint)(nft-ctime));
  } else {
    // next frame time is either now, or passed
    int fps = glconFPS;
    if (fps < 1) fps = 1;
    if (fps > 200) fps = 200;
    if (nft <= 0) nextFrameTime = ctime;
    nextFrameTime += 1000.0/fps;
    nft = cast(ulong)nextFrameTime;
    if (nft <= ctime) {
      nextFrameTime = ctime; // too much time passed, reset timer
      glconCtlWindow.postTimeout(eventNextFrame, 0);
    } else {
      glconCtlWindow.postTimeout(eventNextFrame, cast(uint)(nft-ctime));
    }
  }
}

/** use this after you set all the necessary *DG handlers, like this:
 *
 * ------
 * sdpyWindowClass = "SDPY WINDOW";
 * auto sdwin = new SimpleWindow(VBufWidth, VBufHeight, "My D App", OpenGlOptions.yes, Resizability.allowResizing);
 * //sdwin.hideCursor();
 * glconSetupForGLWindow(sdwin);
 * sdwin.eventLoop(0);
 * flushGui();
 * conProcessQueue(int.max/4);
 * ------
 */
public void glconSetupForGLWindow (SimpleWindow w) {
  if (glconCtlWindow !is null) {
    if (w !is glconCtlWindow) throw new Exception("glconSetupForGLWindow() was already called for another window");
    return;
  }

  glconCtlWindow = w;
  if (w is null) return;

  static if (is(typeof(&glconCtlWindow.closeQuery))) {
    glconCtlWindow.closeQuery = delegate () {
      if (closeQueryDG !is null && !closeQueryDG()) return;
      concmd("quit");
      glconPostDoConCommands();
    };
  }

  glconCtlWindow.visibleForTheFirstTime = delegate () {
    import iv.glbinds;
    glconCtlWindow.setAsCurrentOpenGlContext(); // make this window active

    glconInit(glconCtlWindow.width, glconCtlWindow.height);
    if (oglSetupDG !is null) oglSetupDG();

    glconResetNextFrame();
    //glconPostNextFrame();
  };

  glconCtlWindow.addEventListener((NextFrameEvent evt) {
    glconPostDoConCommands!true();
    if (glconCtlWindow.closed) return;
    if (isQuitRequested) { glconCtlWindow.close(); return; }
    if (nextFrameDG !is null) nextFrameDG();
    //{ import core.stdc.stdio; printf("000: FRAME\n"); }
    glconCtlWindow.redrawOpenGlSceneNow();
    //{ import core.stdc.stdio; printf("001: FRAME\n"); }
    glconPostNextFrame();
  });

  glconCtlWindow.addEventListener((GLConScreenRepaintEvent evt) {
    if (glconCtlWindow.closed) return;
    if (isQuitRequested) { glconCtlWindow.close(); return; }
    //{ import core.stdc.stdio; printf("000: SCREPAINT\n"); }
    glconCtlWindow.redrawOpenGlSceneNow();
    //{ import core.stdc.stdio; printf("001: SCREPAINT\n"); }
  });

  glconCtlWindow.addEventListener((GLConDoConsoleCommandsEvent evt) {
    glconProcessEventMessage();
  });

  glconCtlWindow.windowResized = delegate (int wdt, int hgt) {
    if (glconCtlWindow.closed) return;
    glconResize(wdt, hgt);
    glconPostScreenRepaint/*Delayed*/();
    if (resizeEventDG !is null) resizeEventDG(wdt, hgt);
  };

  glconCtlWindow.onFocusChange = delegate (bool focused) {
    if (glconCtlWindow.closed) return;
    if (focusEventDG !is null) focusEventDG(focused);
  };

  glconCtlWindow.redrawOpenGlScene = delegate () {
    glconPostDoConCommands!true();
    if (glconCtlWindow.closed) return;
    // draw main screen
    if (redrawFrameDG !is null) redrawFrameDG();
    glconDraw();
  };

  glconCtlWindow.handleKeyEvent = delegate (KeyEvent event) {
    scope(exit) glconPostDoConCommands!true();
    if (glconCtlWindow.closed) return;
    if (isQuitRequested) { glconCtlWindow.close(); return; }
    if (glconKeyEvent(event)) { glconPostScreenRepaint(); return; }

    if (keyEventDG is null) return;

    if (glconTranslateMods) {
      switch (event.key) {
        case Key.Ctrl_r: event.key = Key.Ctrl; break;
        case Key.Shift_r: event.key = Key.Shift; break;
        case Key.Alt_r: event.key = Key.Alt; break;
        case Key.Windows_r: event.key = Key.Windows; break;
        default:
      }
    }
    if (glconTranslateKeypad) {
      if ((event.modifierState&ModifierState.numLock) == 0) {
        switch (event.key) {
          case Key.PadEnter: event.key = Key.Enter; break;
          case Key.Pad1: event.key = Key.End; break;
          case Key.Pad2: event.key = Key.Down; break;
          case Key.Pad3: event.key = Key.PageDown; break;
          case Key.Pad4: event.key = Key.Left; break;
          //case Key.Pad5: event.key = Key.; break;
          case Key.Pad6: event.key = Key.Right; break;
          case Key.Pad7: event.key = Key.Home; break;
          case Key.Pad8: event.key = Key.Up; break;
          case Key.Pad9: event.key = Key.PageUp; break;
          case Key.Pad0: event.key = Key.Insert; break;
          default:
        }
      }
    }
    keyEventDG(event);
  };

  glconCtlWindow.handleMouseEvent = delegate (MouseEvent event) {
    scope(exit) glconPostDoConCommands!true();
    if (glconCtlWindow.closed) return;
    if (rConsoleVisible && glconNoMouseEventsWhenConsoleIsVisible) return;
    if (mouseEventDG !is null) mouseEventDG(event);
  };

  glconCtlWindow.handleCharEvent = delegate (dchar ch) {
    scope(exit) glconPostDoConCommands!true();
    if (glconCtlWindow.closed) return;
    if (glconCharEvent(ch)) { glconPostScreenRepaint(); return; }
    if (charEventDG !is null) charEventDG(ch);
  };

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
version(glbinds_mixin) import iv.glbinds.binds_full_mixin; else import iv.glbinds;
