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

  version(none) {
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
  } else {
    immutable float scale = (radius*2.0f)/BaphometDims;
    //{ import core.stdc.stdio; printf("radius=%d; scale=%g; rr=%g\n", radius, cast(double)scale, cast(double)(512*scale)); }
    baphometRender((int x, int y) @trusted => vsetPixel(x+x0, y+y0, conColor), 0, 0, scale);
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
  if (sw >= 128 && sh >= 128) {
    import std.algorithm : min;
    conSetColor(rConStarColor);
    int radius = min(sw, sh)/3;
    //{ import core.stdc.stdio; printf("sw=%d; sh=%d; radius=%d\n", sw, sh, radius); }
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
public __gshared void delegate () nextFrameDG; /// frame need to be rebuilt (but not redrawn); won't be used for FPS == 0
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
/// create window and run event loop. use this after you set all the required *DG delegates.
public void glconRunGLWindow (int wdt, int hgt, string title, string klass=null) {
  glconRunGLWindowInternal(wdt, hgt, title, klass, false);
}

/// ditto.
public void glconRunGLWindowResizeable (int wdt, int hgt, string title, string klass=null) {
  glconRunGLWindowInternal(wdt, hgt, title, klass, true);
}


// ////////////////////////////////////////////////////////////////////////// //
private __gshared int glconFPS = 30; // 0 means "render on demand"
private __gshared double nextFrameTime = 0; // in msecs


/// <=0 means "render on demand" (i.e. never automatically invoke `glconPostNextFrame()`)
/// this will automatically seal "r_fps" convar
/// note that you cannot set FPS to 0 with "r_fps" console variable
public void glconSetAndSealFPS (int fps) {
  if (fps < 0) fps = 0; else if (fps > 200) fps = 200;
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


/// call this to reset frame timer, and immediately post "rebuild frame" event if FPS > 0
/// will post repaint event if FPS == 0
/// called automatically when window is shown, if `glconSetupForGLWindow()` is used
public void glconResetNextFrame () {
  nextFrameTime = 0;
  if (glconFPS <= 0) {
    glconPostScreenRepaint();
  } else {
    glconPostNextFrame();
  }
}

/// called automatically if FPS is > 0
/// noop if FPS == 0
public void glconPostNextFrame () {
  import iv.pxclock;
  if (glconFPS > 0) {
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

    if (glconFPS > 0) glconResetNextFrame();
  };

  glconCtlWindow.addEventListener((NextFrameEvent evt) {
    glconPostDoConCommands!true();
    if (glconCtlWindow.closed) return;
    if (isQuitRequested) { glconCtlWindow.close(); return; }
    if (glconFPS > 0 && nextFrameDG !is null) nextFrameDG();
    glconCtlWindow.redrawOpenGlSceneNow();
    if (glconFPS > 0) glconPostNextFrame();
  });

  glconCtlWindow.addEventListener((GLConScreenRepaintEvent evt) {
    if (glconCtlWindow.closed) return;
    if (isQuitRequested) { glconCtlWindow.close(); return; }
    glconCtlWindow.redrawOpenGlSceneNow();
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

// 512x512
private static immutable float[2264] baphometPath =
[ 0x0p+0,-0x1p+8,-0x1p+8,0x1p+8,0x1p+8,0x1p+0,0x1p+2,0x1.8p+2,0x1.268p-5,0x1p+8,
  0x1p+3,0x1.1a038p+7,0x1p+8,0x1p+8,0x1.1a0388p+7,0x1p+8,0x1.268p-5,0x1p+3,0x1p+8,
  -0x1.1a0388p+7,0x1.1a038p+7,-0x1p+8,0x1.268p-5,-0x1p+8,0x1p+3,-0x1.1a0388p+7,-0x1p+8,
  -0x1p+8,-0x1.1a0388p+7,-0x1p+8,0x1.268p-5,0x1p+3,-0x1p+8,0x1.1a0388p+7,-0x1.1a0388p+7,
  0x1p+8,0x1.268p-5,0x1p+8,0x1.4p+3,0x1.8p+2,0x1.268p-5,0x1.77d9b4p+7,0x1p+3,0x1.9e0fb8p+6,
  0x1.77d9b4p+7,0x1.77d9bp+7,0x1.9e0fcp+6,0x1.77d9bp+7,0x1.268p-5,0x1p+3,0x1.77d9bp+7,
  -0x1.9e0fcp+6,0x1.9e0fb8p+6,-0x1.77d9b8p+7,0x1.268p-5,-0x1.77d9b8p+7,0x1p+3,-0x1.9e0fc4p+6,
  -0x1.77d9b8p+7,-0x1.77d9b8p+7,-0x1.9e0fcp+6,-0x1.77d9b8p+7,0x1.268p-5,0x1p+3,-0x1.77d9b8p+7,
  0x1.9e0fcp+6,-0x1.9e0fc4p+6,0x1.77d9b4p+7,0x1.268p-5,0x1.77d9b4p+7,0x1.4p+3,0x1.8p+2,
  -0x1.b7adf4p+6,-0x1.27d488p+7,0x1.cp+2,-0x1.01fp-2,0x1.73d214p+7,0x1.cp+2,0x1.9897a8p+6,
  -0x1.34c87cp+7,0x1.cp+2,-0x1.5f6244p+7,0x1.c5ed8p+5,0x1.cp+2,0x1.62b1a8p+7,0x1.c5ed8p+5,
  0x1.cp+2,-0x1.b7adf4p+6,-0x1.27d488p+7,0x1.4p+3,0x1.8p+2,-0x1.68612p+3,-0x1.6fdcep+4,
  0x1p+3,-0x1.97964p+2,-0x1.104c8p+4,-0x1.b586p+1,-0x1.1c636p+3,-0x1.2b5b8p+1,0x1.673cp+0,
  0x1p+3,-0x1.5e06p-1,-0x1.132d4p+3,0x1.5969p+1,-0x1.0dff1p+4,0x1.132d4p+3,-0x1.68f45p+4,
  0x1.2p+3,0x1.8p+2,0x1.ae094p+4,-0x1.7c872p+4,0x1p+3,0x1.e426ap+4,-0x1.36dfp+2,
  0x1.0cd84p+4,-0x1.2b5bp+1,0x1.6051p+2,0x1.2191ep+4,0x1.2p+3,0x1.8p+2,-0x1.6178ap+3,
  0x1.3524ap+4,0x1p+3,-0x1.ab28ap+3,0x1.629fp+1,-0x1.4fe99p+5,-0x1.c7f1p+1,-0x1.0d2208p+5,
  -0x1.4c2bap+4,0x1.2p+3,0x1.8p+2,-0x1.6783fp+5,-0x1.750bp+1,0x1p+3,-0x1.74c198p+5,
  0x1.56886p+4,-0x1.d936ap+3,0x1.494a8p+2,-0x1.59fccp+4,0x1.cad22p+4,0x1.2p+3,0x1.8p+2,
  -0x1.b8f9ap+3,0x1.4a27dp+5,0x1p+3,-0x1.0f25ep+4,0x1.9b53cp+5,-0x1.14e7bp+4,0x1.ed13p+5,
  -0x1.9d57cp+3,0x1.1fb2ep+6,0x1.2p+3,0x1.8p+2,0x1.8e5fp+2,0x1.433f5p+5,0x1p+3,0x1.311ccp+3,
  0x1.9b53cp+5,0x1.234bcp+3,0x1.ef609p+5,0x1.6051p+2,0x1.1fb2ep+6,0x1.2p+3,0x1.8p+2,
  0x1.5159cp+3,0x1.254fcp+5,0x1p+3,0x1.bd944p+3,0x1.26767p+5,0x1.e7074p+3,0x1.33b42p+5,
  0x1.03a22p+4,0x1.51104p+5,0x1.2p+3,0x1.8p+2,-0x1.b4f2p+4,0x1.384f3p+5,0x1p+3,-0x1.ace2cp+4,
  0x1.2429p+5,-0x1.880abp+4,0x1.1938fp+5,-0x1.48b77p+4,0x1.177edp+5,0x1.2p+3,0x1.8p+2,
  0x1.ae77e8p+6,0x1.e6744p+4,0x1p+3,0x1.952368p+6,0x1.7478p+4,0x1.6d20dp+6,0x1.5d71p+4,
  0x1.416048p+6,0x1.5fbe6p+4,0x1p+3,0x1.08187p+6,0x1.67cd8p+4,0x1.b9432p+5,0x1.f4d88p+3,
  0x1.714d4p+5,0x1.40148p+2,0x1p+3,0x1.7a834p+5,0x1.84968p+4,0x1.3ea43p+5,0x1.384f3p+5,
  0x1.c637p+4,0x1.9da14p+5,0x1p+3,0x1.a4d36p+4,0x1.b81c7p+5,0x1.a5fap+4,0x1.e5973p+5,
  0x1.8248cp+4,0x1.12befp+6,0x1p+3,0x1.50c68p+4,0x1.23271p+6,0x1.22b86p+4,0x1.34b61p+6,
  0x1.0964p+4,0x1.4e5448p+6,0x1p+3,0x1.160e4p+4,0x1.67a8dp+6,0x1.05efcp+4,0x1.86756p+6,
  0x1.c47dp+3,0x1.a8b63p+6,0x1p+3,0x1.73e44p+3,0x1.b158d8p+6,0x1.0c44cp+3,0x1.b7f7ap+6,
  0x1.d126p+1,0x1.ba8edp+6,0x1p+3,-0x1.0fb98p+1,0x1.bd2608p+6,-0x1.4cbfp+3,0x1.b9fb78p+6,
  -0x1.2191ep+4,0x1.b1ec38p+6,0x1p+3,-0x1.39bfap+4,0x1.94466p+6,-0x1.3c0d3p+4,0x1.76a08p+6,
  -0x1.7913p+4,0x1.5d4cp+6,0x1p+3,-0x1.b618cp+4,0x1.47b578p+6,-0x1.df8bdp+4,0x1.30ae7p+6,
  -0x1.eb0f5p+4,0x1.17a3ap+6,0x1p+3,-0x1.f31e9p+4,0x1.f9bd4p+5,-0x1.fc548p+4,0x1.b8afep+5,
  -0x1.18123p+5,0x1.8fd03p+5,0x1p+3,-0x1.730778p+5,0x1.2395ap+5,-0x1.b25ac8p+5,0x1.7ffb6p+4,
  -0x1.d60c08p+5,0x1.336a4p+3,0x1p+3,-0x1.d69f6p+5,0x1.b3cb2p+4,-0x1.c12da8p+6,0x1.d52eep+4,
  -0x1.e29174p+6,0x1.f0d1p+4,0x1.2p+3,0x1.8p+2,-0x1.132dap+3,0x1.194b5p+7,0x1p+3,
  -0x1.a0ccp+2,0x1.00af04p+7,-0x1.1cf6fp+4,0x1.d75798p+6,-0x1.2191ep+4,0x1.b235ep+6,
  0x1p+3,-0x1.1fd8p+2,0x1.c3c4d8p+6,0x1.36dep+2,0x1.c61258p+6,0x1.bd944p+3,0x1.ab03bp+6,
  0x1p+3,0x1.8402cp+3,0x1.ccb128p+6,0x1.90acp+1,0x1.00d3d8p+7,0x1.571bp+2,0x1.17dadcp+7,
  0x1.2p+3,0x1.8p+2,-0x1.7375f8p+6,-0x1.de89dp+6,0x1p+3,-0x1.af79ep+5,-0x1.59d7c4p+6,
  -0x1.995p+4,-0x1.d32b28p+5,-0x1.bf4edp+4,-0x1.1657f8p+5,0x1.2p+3,0x1.8p+2,0x1.5f4fdp+6,
  -0x1.eea84cp+6,0x1p+3,0x1.872d9p+5,-0x1.69ac94p+6,0x1.48b74p+4,-0x1.f3682p+5,0x1.6eb6p+4,
  -0x1.36951p+5,0x1.2p+3,0x1.8p+2,-0x1.b8afe8p+5,0x1.9deaep+4,0x1p+3,-0x1.b7892p+5,
  0x1.9deaep+4,-0x1.b2ee2p+5,0x1.9140cp+4,-0x1.b1c758p+5,0x1.9140cp+4,0x1p+3,-0x1.3f12dp+6,
  0x1.93448p+5,-0x1.caad5cp+6,0x1.b414ep+5,-0x1.32e984p+7,0x1.74c1ap+5,0x1p+3,-0x1.07e136p+7,
  0x1.3975fp+5,-0x1.de89ccp+6,0x1.db844p+3,-0x1.bd2608p+6,0x1.b6abcp+3,0x1p+3,-0x1.2ef45p+6,
  0x1.f168p-1,-0x1.8d82cp+5,-0x1.d24ep+3,-0x1.844cb8p+5,-0x1.a720ep+4,0x1p+3,-0x1.57f8dp+5,
  -0x1.0f00f8p+6,-0x1.97baa4p+6,-0x1.a668b4p+6,-0x1.ab4d68p+6,-0x1.1f7b98p+7,0x1p+3,
  -0x1.8c80dp+6,-0x1.1160e4p+7,-0x1.6db438p+6,-0x1.034634p+7,-0x1.4ee7a8p+6,-0x1.ea57p+6,
  0x1p+3,-0x1.4d7734p+6,-0x1.e0d74cp+6,-0x1.4116a8p+6,-0x1.d75798p+6,-0x1.2dcd94p+6,
  -0x1.d7a15p+6,0x1p+3,-0x1.24043p+6,-0x1.dba8fp+6,-0x1.1c884cp+6,-0x1.d399a8p+6,
  -0x1.17a39cp+6,-0x1.c7391cp+6,0x1p+3,-0x1.06f1bcp+6,-0x1.c3c4d8p+6,-0x1.02ea1cp+6,
  -0x1.b9b1c8p+6,-0x1.f929fp+5,-0x1.b10f24p+6,0x1p+3,-0x1.d85988p+5,-0x1.ad0788p+6,
  -0x1.c83b08p+5,-0x1.a2aacp+6,-0x1.b53bap+5,-0x1.9974c4p+6,0x1p+3,-0x1.b25ac8p+5,
  -0x1.8e849cp+6,-0x1.a1158p+5,-0x1.890c9p+6,-0x1.8d82cp+5,-0x1.84718cp+6,0x1p+3,
  -0x1.6e6c78p+5,-0x1.82241p+6,-0x1.609b78p+5,-0x1.7cf5a8p+6,-0x1.5517f8p+5,-0x1.777d9cp+6,
  0x1p+3,-0x1.535ddp+5,-0x1.6a89a4p+6,-0x1.3b3008p+5,-0x1.630dc8p+6,-0x1.1efaa8p+5,
  -0x1.5c6ef8p+6,0x1p+3,-0x1.fa071p+4,-0x1.566388p+6,-0x1.fb2ddp+4,-0x1.4c507p+6,
  -0x1.ee839p+4,-0x1.42d0bcp+6,0x1p+3,-0x1.dd3e4p+4,-0x1.37038cp+6,-0x1.c2c2fp+4,
  -0x1.31d52cp+6,-0x1.a3acbp+4,-0x1.2fd16p+6,0x1p+3,-0x1.6eb63p+4,-0x1.2cf07cp+6,
  -0x1.5c4a3p+4,-0x1.2293b8p+6,-0x1.4f9ffp+4,-0x1.1759ecp+6,0x1p+3,-0x1.42f5cp+4,
  -0x1.10bb18p+6,-0x1.33fdfp+4,-0x1.0b430cp+6,-0x1.0cd87p+4,-0x1.0cb378p+6,0x1p+3,
  -0x1.8d394p+3,-0x1.037d74p+6,-0x1.b2112p+3,-0x1.f3fb9p+5,-0x1.9fa52p+3,-0x1.e0fc18p+5,
  0x1p+3,-0x1.ab28ap+3,-0x1.9f5b68p+5,-0x1.6178ap+3,-0x1.990628p+5,-0x1.1c638p+3,
  -0x1.8f3cc8p+5,0x1p+3,-0x1.5280cp+2,-0x1.8a0e8p+5,-0x1.b3384p+2,-0x1.5c0078p+5,
  -0x1.ef17p+2,-0x1.1c19c8p+5,0x1p+3,-0x1.07aap+3,-0x1.0077c8p+5,-0x1.290e4p+2,-0x1.0e48b8p+5,
  0x1.6738p+0,-0x1.267678p+5,0x1p+3,0x1.36dep+2,-0x1.2d5fp+5,0x1.7e4p+1,-0x1.7c3d7p+5,
  0x1.9e7cp+0,-0x1.b00d3p+5,0x1p+3,0x1.2b5ap+1,-0x1.c83b1p+5,0x1.1206p+2,-0x1.dd87fp+5,
  0x1.dcaa8p+2,-0x1.ef609p+5,0x1p+3,0x1.5a8fcp+3,-0x1.04a438p+6,0x1.787f4p+3,-0x1.0eb74p+6,
  0x1.966ecp+3,-0x1.1880a8p+6,0x1p+3,0x1.a1f24p+3,-0x1.272ebcp+6,0x1.e4bap+3,-0x1.2ca6dp+6,
  0x1.1aa92p+4,-0x1.3141ccp+6,0x1p+3,0x1.5b234p+4,-0x1.37038cp+6,0x1.4b04cp+4,-0x1.4a965p+6,
  0x1.57afp+4,-0x1.4d2d8p+6,0x1p+3,0x1.86e3cp+4,-0x1.598e18p+6,0x1.abbbcp+4,-0x1.5d95b4p+6,
  0x1.cd1f8p+4,-0x1.5fe334p+6,0x1p+3,0x1.010b1p+5,-0x1.630dc8p+6,0x1.0a411p+5,-0x1.6bb06cp+6,
  0x1.11299p+5,-0x1.753018p+6,0x1p+3,0x1.1a5f9p+5,-0x1.7f8cdcp+6,0x1.2ba4dp+5,-0x1.86755cp+6,
  0x1.42187p+5,-0x1.8a335p+6,0x1p+3,0x1.68aaap+5,-0x1.91657cp+6,0x1.6cb24p+5,-0x1.9c9f54p+6,
  0x1.7a834p+5,-0x1.a41b34p+6,0x1p+3,0x1.9f5b4p+5,-0x1.b7adf8p+6,0x1.b2ee1p+5,-0x1.b7adf8p+6,
  0x1.c9f51p+5,-0x1.bb6becp+6,0x1p+3,0x1.d732bp+5,-0x1.bee028p+6,0x1.e222dp+5,-0x1.c3317cp+6,
  0x1.e18f7p+5,-0x1.ccfadcp+6,0x1p+3,0x1.dcf47p+5,-0x1.dbf29cp+6,0x1.01c348p+6,-0x1.ddaccp+6,
  0x1.10716p+6,-0x1.e247b8p+6,0x1p+3,0x1.1e8c1p+6,-0x1.e72c7p+6,0x1.2b8p+6,-0x1.ee14f4p+6,
  0x1.36267p+6,-0x1.f9986cp+6,0x1p+3,0x1.374d38p+6,-0x1.001bap+7,0x1.3be838p+6,-0x1.01b0ecp+7,
  0x1.408338p+6,-0x1.034634p+7,0x1p+3,0x1.51c88p+6,-0x1.08060cp+7,0x1.5619c8p+6,
  -0x1.0ca10cp+7,0x1.5cb8ap+6,-0x1.1160e4p+7,0x1p+3,0x1.627a6p+6,-0x1.1620cp+7,0x1.6b1dp+6,
  -0x1.17ffb4p+7,0x1.7453p+6,-0x1.1995p+7,0x1p+3,0x1.7e1c6p+6,-0x1.1c2c2ep+7,0x1.826db8p+6,
  -0x1.1e9e88p+7,0x1.85e1fp+6,-0x1.2135b6p+7,0x1p+3,0x1.9eecc8p+6,-0x1.da387cp+6,
  0x1.e8c1ap+4,-0x1.0cb378p+6,0x1.5517ep+5,-0x1.81223p+4,0x1p+3,0x1.79efep+5,-0x1.5a904p+3,
  0x1.03c72p+6,-0x1.10ep+3,0x1.6bfa1p+6,0x1.99e4p+1,0x1p+3,0x1.011d84p+7,0x1.9a76ap+4,
  0x1.d7a14p+6,0x1.2709ep+5,0x1.2110dcp+7,0x1.65c9dp+5,0x1p+3,0x1.95b6c8p+6,0x1.84e02p+5,
  0x1.05379p+6,0x1.80d87p+5,0x1.77a26p+5,0x1.abbcp+4,0x1.2p+3,0x1.8p+2,-0x1.17ed4cp+6,
  -0x1.c6a5b8p+6,0x1p+3,-0x1.0f945cp+6,-0x1.bc92a8p+6,-0x1.107168p+6,-0x1.ade498p+6,
  -0x1.17ed4cp+6,-0x1.9ea32p+6,0x1.2p+3,0x1.8p+2,-0x1.fb7768p+5,-0x1.b1ec38p+6,0x1p+3,
  -0x1.deaeap+5,-0x1.a2aacp+6,-0x1.d69f6p+5,-0x1.93694cp+6,-0x1.e3dd08p+5,-0x1.8427ep+6,
  0x1.2p+3,0x1.8p+2,-0x1.99064p+5,-0x1.879c1cp+6,0x1p+3,-0x1.8b354p+5,-0x1.7b853cp+6,
  -0x1.869a38p+5,-0x1.6f6e54p+6,-0x1.8b354p+5,-0x1.63a124p+6,0x1.2p+3,0x1.8p+2,-0x1.3c56dp+5,
  -0x1.63eadcp+6,0x1p+3,-0x1.37bbdp+5,-0x1.52a594p+6,-0x1.3975f8p+5,-0x1.43addp+6,
  -0x1.42189p+5,-0x1.3796fp+6,0x1.2p+3,0x1.8p+2,-0x1.daf0dp+4,-0x1.39075cp+6,0x1p+3,
  -0x1.c6373p+4,-0x1.29c5fp+6,-0x1.cad25p+4,-0x1.1d655cp+6,-0x1.e0b28p+4,-0x1.130894p+6,
  0x1.2p+3,0x1.8p+2,-0x1.50c6bp+4,-0x1.19a768p+6,0x1p+3,-0x1.4790bp+4,-0x1.073b6cp+6,
  -0x1.50c6bp+4,-0x1.e62a8p+5,-0x1.6c68bp+4,-0x1.b9d69p+5,0x1.2p+3,0x1.8p+2,-0x1.787fap+3,
  -0x1.9d0dd8p+5,0x1p+3,-0x1.91d42p+3,-0x1.7cd0ep+5,-0x1.d000ap+3,-0x1.640fb8p+5,
  -0x1.1982ap+4,-0x1.535dc8p+5,0x1.2p+3,0x1.8p+2,0x1.370388p+6,-0x1.fa758p+6,0x1p+3,
  0x1.3a77c8p+6,-0x1.f3d6b4p+6,0x1.3b54d8p+6,-0x1.e9c39cp+6,0x1.35dcc8p+6,-0x1.dd195cp+6,
  0x1.2p+3,0x1.8p+2,0x1.0b8cbp+6,-0x1.ddaccp+6,0x1p+3,0x1.0cfd2p+6,-0x1.cf485cp+6,
  0x1.09d29p+6,-0x1.c17758p+6,0x1.00e64p+6,-0x1.b4cd18p+6,0x1.2p+3,0x1.8p+2,0x1.a489bp+5,
  -0x1.b27f9p+6,0x1p+3,0x1.b4a83p+5,-0x1.abe0c8p+6,0x1.b81c7p+5,-0x1.9974c4p+6,0x1.a362ep+5,
  -0x1.82241p+6,0x1.2p+3,0x1.8p+2,0x1.41852p+5,-0x1.882f8p+6,0x1p+3,0x1.4f562p+5,
  -0x1.7f8cdcp+6,0x1.4fe97p+5,-0x1.6db43cp+6,0x1.405e5p+5,-0x1.5ab4d4p+6,0x1.2p+3,
  0x1.8p+2,0x1.bab38p+4,-0x1.5d4c08p+6,0x1p+3,0x1.daf0ap+4,-0x1.525bep+6,0x1.e426ap+4,
  -0x1.399acp+6,0x1.be27cp+4,-0x1.22005cp+6,0x1.2p+3,0x1.8p+2,0x1.206bp+4,-0x1.31d52cp+6,
  0x1p+3,0x1.3f814p+4,-0x1.280bccp+6,0x1.4f9fcp+4,-0x1.0fde08p+6,0x1.31b04p+4,-0x1.f11ab8p+5,
  0x1.2p+3,0x1.8p+2,0x1.77588p+2,-0x1.e222fp+5,0x1p+3,0x1.fce7p+2,-0x1.da13bp+5,
  0x1.86504p+3,-0x1.ad2c58p+5,0x1.b6abcp+3,-0x1.7fb1b8p+5,0x1.2p+3,0x1.8p+2,0x1.e82cp+0,
  -0x1.29eab8p+5,0x1p+3,0x1.0682p+1,-0x1.51104p+5,0x1.2224p+1,-0x1.62e9p+5,-0x1.82ep-1,
  -0x1.959208p+5,0x1.2p+3,0x1.8p+2,-0x1.1fd8p+2,-0x1.0d22p+5,0x1p+3,-0x1.1207p+2,
  -0x1.34dafp+5,-0x1.1207p+2,-0x1.23025p+5,-0x1.1fd8p+2,-0x1.4a27d8p+5,0x1.2p+3,
  0x1.8p+2,-0x1.18fp+1,-0x1.181218p+5,0x1p+3,-0x1.50338p+1,-0x1.37bbc8p+5,0x1.6bd4p+1,
  -0x1.2b119p+5,-0x1.0684p+1,-0x1.6effdp+5,0x1.2p+3,0x1.8p+2,-0x1.66f098p+5,0x1.d9368p+3,
  0x1p+3,-0x1.42abe8p+5,0x1.1bd02p+4,-0x1.44f968p+5,0x1.86e3ep+4,-0x1.1cad3p+5,0x1.d77c6p+4,
  0x1p+3,-0x1.d9cap+4,0x1.09adcp+5,-0x1.2ac7ep+4,0x1.d77c6p+4,-0x1.66a7p+4,0x1.c3e9ap+4,
  0x1p+3,-0x1.2830bp+5,0x1.b056ep+4,-0x1.38e288p+5,0x1.0154ep+4,-0x1.0512c8p+5,0x1.9421cp+3,
  0x1.2p+3,0x1.8p+2,0x1.31669p+5,0x1.d6e94p+3,0x1p+3,0x1.0d21fp+5,0x1.19828p+4,0x1.0edc1p+5,
  0x1.84968p+4,0x1.ce464p+4,0x1.d52eep+4,0x1p+3,0x1.6eb6p+4,0x1.091a5p+5,0x1.86504p+3,
  0x1.d1baap+4,0x1.fe0e4p+3,0x1.be27ep+4,0x1p+3,0x1.e8c1ap+4,0x1.aa952p+4,0x1.f692ap+4,
  0x1.d6e94p+3,0x1.8ef3p+4,0x1.6860cp+3,0x1.2p+3,0x1.8p+2,0x1.18121p+5,-0x1.494a8p+2,
  0x1p+3,0x1.26767p+5,0x1.33fdcp+4,-0x1.1d8bp+0,0x1.10ep+3,0x1.db84p+3,0x1.c2c3p+4,
  0x1.2p+3,0x1.8p+1,0x1p+2,0x1.8p+2,-0x1.c75e1p+4,0x1.77ec4p+4,0x1p+3,-0x1.b618cp+4,
  0x1.77ec4p+4,-0x1.a720fp+4,0x1.66a6ep+4,-0x1.a720fp+4,0x1.4f9fep+4,0x1p+3,-0x1.a720fp+4,
  0x1.39bfcp+4,-0x1.b618cp+4,0x1.287a6p+4,-0x1.c75e1p+4,0x1.287a6p+4,0x1p+3,-0x1.d77c9p+4,
  0x1.287a6p+4,-0x1.e6745p+4,0x1.39bfcp+4,-0x1.e6745p+4,0x1.4f9fep+4,0x1p+3,-0x1.e6745p+4,
  0x1.66a6ep+4,-0x1.d77c9p+4,0x1.77ec4p+4,-0x1.c75e1p+4,0x1.77ec4p+4,0x1.4p+3,0x1.8p+2,
  0x1.35248p+4,0x1.77ec4p+4,0x1p+3,0x1.4669ap+4,0x1.77ec4p+4,0x1.543acp+4,0x1.66a6ep+4,
  0x1.543acp+4,0x1.4f9fep+4,0x1p+3,0x1.543acp+4,0x1.39bfcp+4,0x1.4669ap+4,0x1.287a6p+4,
  0x1.35248p+4,0x1.287a6p+4,0x1p+3,0x1.2506p+4,0x1.287a6p+4,0x1.160e4p+4,0x1.39bfcp+4,
  0x1.160e4p+4,0x1.4f9fep+4,0x1p+3,0x1.160e4p+4,0x1.66a6ep+4,0x1.2506p+4,0x1.77ec4p+4,
  0x1.35248p+4,0x1.77ec4p+4,0x1.4p+3,0x1p+1,0x1p+2,0x1.8p+2,0x1.a8dacp+3,0x1.22006p+6,
  0x1p+3,0x1.86504p+3,0x1.34b61p+6,0x1.2224p+1,0x1.62c418p+6,0x1.18eep+1,0x1.7375f8p+6,
  0x1p+3,0x1.8c1p+0,0x1.82b77p+6,0x1.fa9ap+0,0x1.8cca78p+6,0x1.69878p+2,0x1.8e3ae8p+6,
  0x1p+3,0x1.1a15cp+3,0x1.8f61bp+6,0x1.4a714p+3,0x1.8ba3cp+6,0x1.311ccp+3,0x1.7e1c68p+6,
  0x1p+3,0x1.20fe4p+3,0x1.777d98p+6,0x1.20fe4p+3,0x1.724f4p+6,0x1.f84c8p+2,0x1.6bfa1p+6,
  0x1p+3,0x1.ca3e8p+2,0x1.647e4p+6,0x1.c5a38p+2,0x1.5ab4ep+6,0x1.6aae4p+3,0x1.451e4p+6,
  0x1p+3,0x1.c6ca4p+3,0x1.36b9e8p+6,0x1.e26c4p+3,0x1.163328p+6,0x1.a8dacp+3,0x1.22006p+6,
  0x1.4p+3,0x1.8p+2,-0x1.2ac7ep+4,0x1.23ba8p+6,0x1p+3,-0x1.1982ap+4,0x1.36703p+6,
  -0x1.e5e14p+2,0x1.647e4p+6,-0x1.e1464p+2,0x1.753018p+6,0x1p+3,-0x1.b7d34p+2,0x1.847188p+6,
  -0x1.d3754p+2,0x1.8e8498p+6,-0x1.6178ap+3,0x1.8ff508p+6,0x1p+3,-0x1.c6cacp+3,0x1.911bdp+6,
  -0x1.f7262p+3,0x1.8d5de8p+6,-0x1.ddd1cp+3,0x1.7fd688p+6,0x1p+3,-0x1.cdb34p+3,0x1.79817p+6,
  -0x1.cdb34p+3,0x1.74096p+6,-0x1.a8db2p+3,0x1.6db43p+6,0x1p+3,-0x1.91d42p+3,0x1.66385p+6,
  -0x1.8f86ap+3,0x1.5c6efp+6,-0x1.0bb19p+4,0x1.46d868p+6,0x1p+3,-0x1.39bfap+4,0x1.3873f8p+6,
  -0x1.4790bp+4,0x1.17ed48p+6,-0x1.2ac7ep+4,0x1.23ba8p+6,0x1.4p+3,0x1p+0,0x1.4p+2,
  0x1.8p+2,-0x1.494b4p+2,0x1.0d346cp+7,0x1p+3,-0x1.0c452p+3,0x1.207d8p+7,-0x1.50338p+1,
  0x1.27afacp+7,-0x1.3b7ap+2,0x1.37f31p+7,0x1.2p+3,0x1.8p+2,0x1.b0e8p+0,0x1.0decap+7,
  0x1p+3,0x1.3b798p+2,0x1.215a9p+7,-0x1.82ep-1,0x1.288ccp+7,0x1.79a4p+0,0x1.38d018p+7,
  0x1.2p+3,0x1.8p+2,-0x1.d5c3p+0,0x1.1d093cp+7,0x1p+3,-0x1.da5ep+1,0x1.281e34p+7,
  0x1.268p-5,0x1.33eb68p+7,-0x1.d5c3p+0,0x1.3e482cp+7,0x1.2p+3,0x1p+0,0x1.4p+2,0x1.8p+2,
  -0x1.1f7b9ap+7,0x1.7c3d7p+5,0x1p+3,-0x1.186e4p+7,0x1.74c1ap+5,-0x1.12f62ep+7,0x1.640fbp+5,
  -0x1.123df6p+7,0x1.57f8cp+5,0x1.2p+3,0x1.8p+2,-0x1.0a09dcp+7,0x1.869a4p+5,0x1p+3,
  -0x1.038fe4p+7,0x1.7a835p+5,-0x1.f90518p+6,0x1.609b7p+5,-0x1.f66de4p+6,0x1.4f562p+5,
  0x1.2p+3,0x1.8p+2,-0x1.ef8564p+6,0x1.8d82ap+5,0x1p+3,-0x1.e77624p+6,0x1.8326p+5,
  -0x1.dccfbp+6,0x1.693e2p+5,-0x1.dacbep+6,0x1.5517fp+5,0x1.2p+3,0x1.8p+2,-0x1.d2bc9cp+6,
  0x1.8cef6p+5,0x1p+3,-0x1.c7cc7cp+6,0x1.80d87p+5,-0x1.bb2238p+6,0x1.637c5p+5,-0x1.b7adf4p+6,
  0x1.4d9c2p+5,0x1.2p+3,0x1.8p+2,-0x1.9e0fc4p+6,0x1.84e02p+5,0x1p+3,-0x1.9b2eep+6,
  0x1.770f1p+5,-0x1.984ep+6,0x1.6008p+5,-0x1.9a51dp+6,0x1.52371p+5,0x1.2p+3,0x1.8p+2,
  -0x1.89564p+6,0x1.7d643p+5,0x1p+3,-0x1.854eap+6,0x1.6d45bp+5,-0x1.80b3ap+6,0x1.4fe98p+5,
  -0x1.83011cp+6,0x1.44f97p+5,0x1.2p+3,0x1.8p+2,-0x1.6d6a8cp+6,0x1.72741p+5,0x1p+3,
  -0x1.675f1cp+6,0x1.5f74cp+5,-0x1.62c418p+6,0x1.3c56cp+5,-0x1.65a4f8p+6,0x1.2df27p+5,
  0x1.2p+3,0x1.8p+2,-0x1.553cc4p+6,0x1.62559p+5,0x1p+3,-0x1.4ee7a8p+6,0x1.52ca6p+5,
  -0x1.4c5074p+6,0x1.30d34p+5,-0x1.500e68p+6,0x1.20b4cp+5,0x1.2p+3,0x1.8p+2,-0x1.3796f4p+6,
  0x1.4a27dp+5,0x1p+3,-0x1.321eep+6,0x1.384f3p+5,-0x1.30ae74p+6,0x1.16eb6p+5,-0x1.3422bp+6,
  0x1.0a413p+5,0x1.2p+3,0x1.8p+2,-0x1.25be4cp+6,0x1.384f3p+5,0x1p+3,-0x1.1fb2dcp+6,
  0x1.2b119p+5,-0x1.1c3eap+6,0x1.1002ep+5,-0x1.1c884cp+6,0x1.0231fp+5,0x1.2p+3,0x1.8p+2,
  -0x1.107168p+6,0x1.1f8e1p+5,0x1p+3,-0x1.0a65f8p+6,0x1.15c4bp+5,-0x1.08f58cp+6,
  0x1.ffc8cp+4,-0x1.081878p+6,0x1.e3p+4,0x1.2p+3,0x1.8p+2,-0x1.e6bdfp+5,0x1.e426ap+4,
  0x1p+3,-0x1.daa7p+5,0x1.ce466p+4,-0x1.dc6128p+5,0x1.a847cp+4,-0x1.d85988p+5,0x1.81224p+4,
  0x1.2p+3,0x1.8p+2,0x1.0dc7c8p+7,0x1.68174p+5,0x1p+3,0x1.069594p+7,0x1.612eep+5,
  0x1.01426p+7,0x1.507cfp+5,0x1.00654cp+7,0x1.43d2ap+5,0x1.2p+3,0x1.8p+2,0x1.f54718p+6,
  0x1.6f934p+5,0x1p+3,0x1.e89cd8p+6,0x1.62e8ep+5,0x1.da822p+6,0x1.49947p+5,0x1.d7a14p+6,
  0x1.384f3p+5,0x1.2p+3,0x1.8p+2,0x1.d06f1p+6,0x1.739adp+5,0x1p+3,0x1.c8162p+6,0x1.69d16p+5,
  0x1.bdb96p+6,0x1.4fe98p+5,0x1.bbb59p+6,0x1.3bc36p+5,0x1.2p+3,0x1.8p+2,0x1.b439a8p+6,
  0x1.739adp+5,0x1p+3,0x1.a9499p+6,0x1.6784p+5,0x1.9c5598p+6,0x1.4a27dp+5,0x1.992b08p+6,
  0x1.34478p+5,0x1.2p+3,0x1.8p+2,0x1.8b1058p+6,0x1.70b9fp+5,0x1p+3,0x1.882f78p+6,
  0x1.62e8ep+5,0x1.854e98p+6,0x1.4be1fp+5,0x1.875268p+6,0x1.3e10ep+5,0x1.2p+3,0x1.8p+2,
  0x1.6d20dp+6,0x1.6cb24p+5,0x1p+3,0x1.69193p+6,0x1.5c93cp+5,0x1.64348p+6,0x1.3f37ap+5,
  0x1.6682p+6,0x1.34478p+5,0x1.2p+3,0x1.8p+2,0x1.513518p+6,0x1.61c22p+5,0x1p+3,0x1.4b29a8p+6,
  0x1.4ec2dp+5,0x1.4644f8p+6,0x1.2ba4ep+5,0x1.4925d8p+6,0x1.1d408p+5,0x1.2p+3,0x1.8p+2,
  0x1.39075p+6,0x1.5d273p+5,0x1p+3,0x1.32b238p+6,0x1.4d08bp+5,0x1.301bp+6,0x1.2b119p+5,
  0x1.33d8f8p+6,0x1.1b866p+5,0x1.2p+3,0x1.8p+2,0x1.1d655p+6,0x1.4a27dp+5,0x1p+3,
  0x1.17ed4p+6,0x1.384f3p+5,0x1.167cdp+6,0x1.16eb6p+5,0x1.19f11p+6,0x1.09adcp+5,
  0x1.2p+3,0x1.8p+2,0x1.073b6p+6,0x1.3e10ep+5,0x1p+3,0x1.012ffp+6,0x1.303fdp+5,0x1.fb775p+5,
  0x1.15c4bp+5,0x1.fb775p+5,0x1.07f3ap+5,0x1.2p+3,0x1.8p+2,0x1.e18f7p+5,0x1.28309p+5,
  0x1p+3,0x1.d5789p+5,0x1.1efaap+5,0x1.d297bp+5,0x1.0887p+5,0x1.d0dd9p+5,0x1.f4456p+4,
  0x1.2p+3,0x1.8p+2,0x1.b8afdp+5,0x1.0c8e9p+5,0x1p+3,0x1.ac98fp+5,0x1.019e8p+5,0x1.aee67p+5,
  0x1.dd3e4p+4,0x1.aa4b7p+5,0x1.b618cp+4,0x1.2p+3,0x1p+1,0x1p+2,0x1.8p+2,-0x1.a85a18p+7,
  0x1.46b39p+5,0x1p+3,-0x1.a70e8p+7,0x1.458ccp+5,-0x1.a5c2e8p+7,0x1.4466p+5,-0x1.a45278p+7,
  0x1.42abep+5,0x1p+3,-0x1.912e3cp+7,0x1.43d2ap+5,-0x1.907604p+7,0x1.88546p+5,-0x1.923024p+7,
  0x1.dd87fp+5,0x1p+3,-0x1.937bbcp+7,0x1.1d655p+6,-0x1.9612eep+7,0x1.54f318p+6,-0x1.90512cp+7,
  0x1.6bfa1p+6,0x1p+3,-0x1.8b9154p+7,0x1.7bcee8p+6,-0x1.8968acp+7,0x1.8d143p+6,-0x1.891efap+7,
  0x1.9f8028p+6,0x1.cp+2,-0x1.891efap+7,0x1.ab03bp+6,0x1p+3,-0x1.898d84p+7,0x1.c25468p+6,
  -0x1.8c933cp+7,0x1.db5f38p+6,-0x1.90bfb4p+7,0x1.f54718p+6,0x1p+3,-0x1.957f8cp+7,
  0x1.c5c8bp+6,-0x1.a1bb48p+7,0x1.a184p+6,-0x1.a85a18p+7,0x1.882f8p+6,0x1.cp+2,-0x1.a85a18p+7,
  0x1.1fb2ep+6,0x1p+3,-0x1.a7c6b8p+7,0x1.19141p+6,-0x1.a7583p+7,0x1.12befp+6,-0x1.a6e9a8p+7,
  0x1.0cfd3p+6,0x1p+3,-0x1.a39a4p+7,0x1.ee39cp+5,-0x1.a4c1p+7,0x1.deaebp+5,-0x1.a85a18p+7,
  0x1.da13bp+5,0x1.cp+2,-0x1.a85a18p+7,0x1.bf05p+5,0x1p+3,-0x1.a50abp+7,0x1.bf986p+5,
  -0x1.a29858p+7,0x1.c30cbp+5,-0x1.a1967p+7,0x1.ca888p+5,0x1p+3,-0x1.9e90b8p+7,0x1.e7e4ap+5,
  -0x1.a1031p+7,0x1.1df8cp+6,-0x1.a4e5d8p+7,0x1.416048p+6,0x1p+3,-0x1.a8a3c8p+7,
  0x1.64c7ep+6,-0x1.a45278p+7,0x1.7e662p+6,-0x1.9cfb6ep+7,0x1.96dd9p+6,0x1p+3,-0x1.9a3f66p+7,
  0x1.9ea318p+6,-0x1.983b96p+7,0x1.ab9718p+6,-0x1.95a464p+7,0x1.b3a658p+6,0x1p+3,
  -0x1.8d269cp+7,0x1.d42d08p+6,-0x1.8c6e64p+7,0x1.b56078p+6,-0x1.919cc4p+7,0x1.91af28p+6,
  0x1p+3,-0x1.99872ep+7,0x1.643488p+6,-0x1.9b6626p+7,0x1.4925ep+6,-0x1.9af79ep+7,
  0x1.34ffc8p+6,0x1p+3,-0x1.9c1e5ep+7,0x1.17a3ap+6,-0x1.8c6e64p+7,0x1.4e2f6p+5,-0x1.a85a18p+7,
  0x1.5ad9ap+5,0x1.cp+2,-0x1.a85a18p+7,0x1.46b39p+5,0x1.4p+3,0x1.8p+2,-0x1.c522dep+7,
  0x1.458ccp+5,0x1p+3,-0x1.c368bep+7,0x1.2e85dp+5,-0x1.b9e90cp+7,0x1.5517fp+5,-0x1.a85a18p+7,
  0x1.46b39p+5,0x1.cp+2,-0x1.a85a18p+7,0x1.5ad9ap+5,0x1p+3,-0x1.a8c8ap+7,0x1.5ad9ap+5,
  -0x1.a93728p+7,0x1.5b6d1p+5,-0x1.a9a5bp+7,0x1.5b6d1p+5,0x1p+3,-0x1.b1b4f2p+7,0x1.70b9fp+5,
  -0x1.bceec4p+7,0x1.563eap+5,-0x1.bfaaccp+7,0x1.609b7p+5,0x1p+3,-0x1.c547b6p+7,
  0x1.75e85p+5,-0x1.c14014p+7,0x1.bc242p+5,-0x1.bca514p+7,0x1.bf986p+5,0x1p+3,-0x1.b6be7cp+7,
  0x1.c1e5dp+5,-0x1.ae658ap+7,0x1.bd4adp+5,-0x1.a85a18p+7,0x1.bf05p+5,0x1.cp+2,-0x1.a85a18p+7,
  0x1.da13bp+5,0x1p+3,-0x1.aa82cp+7,0x1.d7c62p+5,-0x1.ad887ap+7,0x1.d8ecep+5,-0x1.b0fcbap+7,
  0x1.daa7p+5,0x1p+3,-0x1.b64ff2p+7,0x1.db3a6p+5,-0x1.b8789cp+7,0x1.daa7p+5,-0x1.bdcbd4p+7,
  0x1.db3a6p+5,0x1p+3,-0x1.c4fe06p+7,0x1.d9804p+5,-0x1.c905a6p+7,0x1.9d0dep+5,-0x1.c74b86p+7,
  0x1.85737p+5,0x1p+3,-0x1.c74b86p+7,0x1.5e4dep+5,-0x1.c84d6ep+7,0x1.6cb24p+5,-0x1.c522dep+7,
  0x1.458ccp+5,0x1.cp+2,-0x1.c522dep+7,0x1.458ccp+5,0x1.4p+3,0x1.8p+2,-0x1.a85a18p+7,
  0x1.882f8p+6,0x1p+3,-0x1.ab162p+7,0x1.7e1c68p+6,-0x1.acd04p+7,0x1.760d28p+6,-0x1.ad19fp+7,
  0x1.6f6e58p+6,0x1p+3,-0x1.aef8eap+7,0x1.651198p+6,-0x1.ab3af8p+7,0x1.3f5c8p+6,
  -0x1.a85a18p+7,0x1.1fb2ep+6,0x1.cp+2,-0x1.a85a18p+7,0x1.882f8p+6,0x1.4p+3,0x1.8p+2,
  0x1.954p-2,0x1.9af798p+7,0x1p+3,0x1.82d8p-1,0x1.9ad2c8p+7,0x1.1d88p+0,0x1.9aadecp+7,
  0x1.8c1p+0,0x1.9a891p+7,0x1p+3,0x1.030ecp+3,0x1.98f3c8p+7,0x1.c6ca4p+3,0x1.940f18p+7,
  0x1.620bap+4,0x1.9a3f64p+7,0x1p+3,0x1.94b4cp+4,0x1.9e4704p+7,0x1.abbbcp+4,0x1.a3bf18p+7,
  0x1.ae094p+4,0x1.aa5de8p+7,0x1.cp+2,0x1.ae094p+4,0x1.acab68p+7,0x1p+3,0x1.aa95p+4,
  0x1.b7082cp+7,0x1.7a398p+4,0x1.c3d74p+7,0x1.32d6ep+4,0x1.d216dp+7,0x1p+3,0x1.45d64p+3,
  0x1.ef4e1cp+7,0x1.09f74p+3,0x1.ee7108p+7,0x1.35b7cp+3,0x1.e0318p+7,0x1p+3,0x1.14e78p+4,
  0x1.baa144p+7,0x1.c22f4p+3,0x1.b0d7ep+7,0x1.ff34p+1,0x1.b955a8p+7,0x1p+3,0x1.750ap+1,
  0x1.ba0dep+7,0x1.b0e8p+0,0x1.baa144p+7,0x1.954p-2,0x1.bb0fccp+7,0x1.cp+2,0x1.954p-2,
  0x1.b2dbbp+7,0x1p+3,0x1.ff34p+1,0x1.b1b4f4p+7,0x1.d374p+2,0x1.b06958p+7,0x1.61784p+3,
  0x1.af4298p+7,0x1p+3,0x1.5b234p+4,0x1.aa391p+7,0x1.b6abcp+3,0x1.d3873cp+7,0x1.f725cp+3,
  0x1.d2608p+7,0x1p+3,0x1.4d524p+4,0x1.be3a58p+7,0x1.be27cp+4,0x1.a6c4ccp+7,0x1.160e4p+4,
  0x1.9f48fp+7,0x1p+3,0x1.5159cp+3,0x1.9dfd54p+7,0x1.36dep+2,0x1.9f6dcp+7,0x1.954p-2,
  0x1.a0de34p+7,0x1.cp+2,0x1.954p-2,0x1.9af798p+7,0x1.4p+3,0x1.8p+2,-0x1.364b6p+4,
  0x1.84156cp+7,0x1p+3,-0x1.c5a44p+2,0x1.84cdacp+7,-0x1.32d72p+4,0x1.a2e204p+7,0x1.954p-2,
  0x1.9af798p+7,0x1.cp+2,0x1.954p-2,0x1.a0de34p+7,0x1p+3,-0x1.16a1cp+2,0x1.a2737cp+7,
  -0x1.f84d4p+2,0x1.a408c4p+7,-0x1.43892p+3,0x1.a306ep+7,0x1p+3,-0x1.966f4p+3,0x1.a04ad4p+7,
  -0x1.bd94cp+3,0x1.9e6bdcp+7,-0x1.ddd1cp+3,0x1.929eacp+7,0x1p+3,-0x1.04c93p+4,0x1.8bb62cp+7,
  -0x1.2753bp+4,0x1.88b07p+7,-0x1.48b77p+4,0x1.88b07p+7,0x1p+3,-0x1.8ef33p+4,0x1.8bffd8p+7,
  -0x1.29a12p+4,0x1.920b48p+7,-0x1.364b6p+4,0x1.9bd4acp+7,0x1p+3,-0x1.4669ep+4,0x1.a73354p+7,
  -0x1.57af3p+4,0x1.b2b6d8p+7,-0x1.11736p+4,0x1.b5e16cp+7,0x1p+3,-0x1.311d2p+3,0x1.b597b8p+7,
  -0x1.1207p+2,0x1.b470f8p+7,0x1.954p-2,0x1.b2dbbp+7,0x1.cp+2,0x1.954p-2,0x1.bb0fccp+7,
  0x1p+3,-0x1.b586p+1,0x1.bca514p+7,-0x1.e5e14p+2,0x1.bd8224p+7,-0x1.7d1acp+3,0x1.be3a58p+7,
  0x1p+3,-0x1.3c0d3p+4,0x1.bfcfap+7,-0x1.4f9ffp+4,0x1.baa144p+7,-0x1.68f46p+4,0x1.b4274cp+7,
  0x1p+3,-0x1.89318p+4,0x1.abf33p+7,-0x1.4790bp+4,0x1.a127e4p+7,-0x1.6c68bp+4,0x1.98f3c8p+7,
  0x1p+3,-0x1.81224p+4,0x1.9433f4p+7,-0x1.8ef33p+4,0x1.8fe2ap+7,-0x1.9140cp+4,0x1.8c6e64p+7,
  0x1.cp+2,-0x1.9140cp+4,0x1.8a6a94p+7,0x1p+3,-0x1.8dcc8p+4,0x1.863e18p+7,-0x1.73513p+4,
  0x1.83cbcp+7,-0x1.364b6p+4,0x1.84156cp+7,0x1.4p+3,0x1.8p+2,0x1.fd0ca8p+6,-0x1.8662fp+7,
  0x1p+3,0x1.05004cp+7,-0x1.8687cap+7,0x1.0a5384p+7,-0x1.8662fp+7,0x1.105ef8p+7,
  -0x1.85175ap+7,0x1p+3,0x1.121918p+7,-0x1.838212p+7,0x1.12d15p+7,-0x1.817e3ep+7,
  0x1.131bp+7,-0x1.7f0be6p+7,0x1.cp+2,0x1.131bp+7,-0x1.7c2b04p+7,0x1p+3,0x1.12ac78p+7,
  -0x1.754284p+7,0x1.0f3838p+7,-0x1.6ae5c4p+7,0x1.0b7a48p+7,-0x1.5b10fp+7,0x1p+3,
  0x1.011d84p+7,-0x1.49a6d8p+7,0x1.ffed88p+6,-0x1.51914p+7,0x1.fd0ca8p+6,-0x1.5c37b4p+7,
  0x1.cp+2,0x1.fd0ca8p+6,-0x1.6fef4cp+7,0x1p+3,0x1.ff5a28p+6,-0x1.6e352ep+7,0x1.001b9cp+7,
  -0x1.6b544cp+7,0x1.02691cp+7,-0x1.6267f8p+7,0x1p+3,0x1.028df4p+7,-0x1.55bdb8p+7,
  0x1.0670bcp+7,-0x1.5a0f08p+7,0x1.084fb8p+7,-0x1.632034p+7,0x1p+3,0x1.08be4p+7,
  -0x1.6f80c4p+7,0x1.13ae6p+7,-0x1.794a24p+7,0x1.0ca108p+7,-0x1.7f0be6p+7,0x1p+3,
  0x1.0b9f2p+7,-0x1.80578p+7,0x1.064be8p+7,-0x1.8211a2p+7,0x1.fd0ca8p+6,-0x1.81c7fp+7,
  0x1.cp+2,0x1.fd0ca8p+6,-0x1.8662fp+7,0x1.4p+3,0x1.8p+2,0x1.dc85fp+6,-0x1.8f741ap+7,
  0x1p+3,0x1.e2db18p+6,-0x1.9177eap+7,0x1.e49538p+6,-0x1.87ae88p+7,0x1.f4fd68p+6,
  -0x1.863e18p+7,0x1p+3,0x1.f7de48p+6,-0x1.863e18p+7,0x1.fa7578p+6,-0x1.863e18p+7,
  0x1.fd0ca8p+6,-0x1.8662fp+7,0x1.cp+2,0x1.fd0ca8p+6,-0x1.81c7fp+7,0x1p+3,0x1.fb9c38p+6,
  -0x1.81c7fp+7,0x1.fa2bc8p+6,-0x1.81a31ap+7,0x1.f8bb58p+6,-0x1.81a31ap+7,0x1p+3,
  0x1.ea0d4p+6,-0x1.810fb6p+7,0x1.dccfa8p+6,-0x1.8b22c8p+7,0x1.dccfa8p+6,-0x1.888b9ap+7,
  0x1p+3,0x1.dacbd8p+6,-0x1.83a6e8p+7,0x1.dd195p+6,-0x1.7d9b76p+7,0x1.e1fep+6,-0x1.76fca8p+7,
  0x1p+3,0x1.e3b828p+6,-0x1.7319dep+7,0x1.eea848p+6,-0x1.723cccp+7,0x1.fa2bc8p+6,
  -0x1.715fbcp+7,0x1p+3,0x1.fb5288p+6,-0x1.70f134p+7,0x1.fc2f98p+6,-0x1.7082acp+7,
  0x1.fd0ca8p+6,-0x1.6fef4cp+7,0x1.cp+2,0x1.fd0ca8p+6,-0x1.5c37b4p+7,0x1p+3,0x1.fa7578p+6,
  -0x1.65dc3cp+7,0x1.f74ae8p+6,-0x1.71f31cp+7,0x1.e5289p+6,-0x1.6f5becp+7,0x1p+3,
  0x1.da822p+6,-0x1.6f3716p+7,0x1.d50a1p+6,-0x1.78483cp+7,0x1.d476bp+6,-0x1.80c608p+7,
  0x1.cp+2,0x1.d476bp+6,-0x1.845f2p+7,0x1p+3,0x1.d4c06p+6,-0x1.8a20ep+7,0x1.d7a14p+6,
  -0x1.8f0592p+7,0x1.dc85fp+6,-0x1.8f741ap+7,0x1.4p+3,0x1.8p+2,0x1.aba97cp+7,0x1.38e28p+5,
  0x1p+3,0x1.b34a34p+7,0x1.384f3p+5,0x1.baa13cp+7,0x1.3975fp+5,0x1.c164e8p+7,0x1.3f37ap+5,
  0x1p+3,0x1.c343dcp+7,0x1.46202p+5,0x1.c420ecp+7,0x1.52ca6p+5,0x1.c445c8p+7,0x1.637c5p+5,
  0x1.cp+2,0x1.c445c8p+7,0x1.770f1p+5,0x1p+3,0x1.c3b264p+7,0x1.a7fdfp+5,0x1.bf6118p+7,
  0x1.f1aep+5,0x1.bac614p+7,0x1.1f1f78p+6,0x1p+3,0x1.b99f58p+7,0x1.2c5d18p+6,0x1.b87898p+7,
  0x1.399acp+6,0x1.b72dp+7,0x1.46d868p+6,0x1p+3,0x1.b26d24p+7,0x1.70decp+6,0x1.b06954p+7,
  0x1.5e291p+6,0x1.aed408p+7,0x1.431a68p+6,0x1p+3,0x1.af8c44p+7,0x1.1cd1f8p+6,0x1.b1fe9cp+7,
  0x1.ea323p+5,0x1.aba97cp+7,0x1.c1528p+5,0x1.cp+2,0x1.aba97cp+7,0x1.9ec8p+5,0x1p+3,
  0x1.ac1804p+7,0x1.9ec8p+5,0x1.ac868cp+7,0x1.9f5b6p+5,0x1.acf514p+7,0x1.9f5b6p+5,
  0x1p+3,0x1.afb11cp+7,0x1.a7fdfp+5,0x1.b2b6d4p+7,0x1.d3be7p+5,0x1.b470f8p+7,0x1.07851p+6,
  0x1p+3,0x1.b572dcp+7,0x1.2651bp+6,0x1.b70824p+7,0x1.1fb2ep+6,0x1.b8e72p+7,0x1.08188p+6,
  0x1p+3,0x1.b97a7cp+7,0x1.d5789p+5,0x1.c3fc1cp+7,0x1.79efep+5,0x1.bbc8p+7,0x1.5e4dep+5,
  0x1p+3,0x1.ba7c68p+7,0x1.588c3p+5,0x1.b50454p+7,0x1.4d9c2p+5,0x1.aba97cp+7,0x1.4f562p+5,
  0x1.cp+2,0x1.aba97cp+7,0x1.38e28p+5,0x1.4p+3,0x1.8p+2,0x1.9918ap+7,0x1.0e48bp+5,
  0x1p+3,0x1.9cd69p+7,0x1.047f5p+5,0x1.9b8af8p+7,0x1.3320dp+5,0x1.a52f84p+7,0x1.3a093p+5,
  0x1p+3,0x1.a75828p+7,0x1.3975fp+5,0x1.a980d4p+7,0x1.3975fp+5,0x1.aba97cp+7,0x1.38e28p+5,
  0x1.cp+2,0x1.aba97cp+7,0x1.4f562p+5,0x1p+3,0x1.ab161cp+7,0x1.4f562p+5,0x1.aa5dep+7,
  0x1.4f562p+5,0x1.a9a5acp+7,0x1.4f562p+5,0x1p+3,0x1.a10308p+7,0x1.52371p+5,0x1.98f3c8p+7,
  0x1.2f192p+5,0x1.98f3c8p+7,0x1.3b301p+5,0x1p+3,0x1.97a83p+7,0x1.52371p+5,0x1.99625p+7,
  0x1.62559p+5,0x1.9c433p+7,0x1.81ff2p+5,0x1p+3,0x1.9d4518p+7,0x1.93448p+5,0x1.a50aa8p+7,
  0x1.9a2dp+5,0x1.aba97cp+7,0x1.9ec8p+5,0x1.cp+2,0x1.aba97cp+7,0x1.c1528p+5,0x1p+3,
  0x1.a9124cp+7,0x1.b00d3p+5,0x1.a4c0fcp+7,0x1.a5b08p+5,0x1.9e2228p+7,0x1.a5b08p+5,
  0x1p+3,0x1.97cd08p+7,0x1.a5b08p+5,0x1.94a278p+7,0x1.7baap+5,0x1.9433fp+7,0x1.53f13p+5,
  0x1.cp+2,0x1.9433fp+7,0x1.42189p+5,0x1p+3,0x1.947d9cp+7,0x1.2709ep+5,0x1.9637cp+7,
  0x1.10964p+5,0x1.9918ap+7,0x1.0e48bp+5,0x1.4p+3,0x1.8p+2,-0x1.192678p+7,-0x1.701428p+7,
  0x1p+3,-0x1.0b7a4cp+7,-0x1.72ab56p+7,-0x1.fabf3p+6,-0x1.75facp+7,-0x1.e64f5cp+6,
  -0x1.741bc6p+7,0x1p+3,-0x1.d8c81p+6,-0x1.72ab56p+7,-0x1.d476bcp+6,-0x1.6727d4p+7,
  -0x1.d3e358p+6,-0x1.55058p+7,0x1.cp+2,-0x1.d3e358p+6,-0x1.4eb06p+7,0x1p+3,-0x1.d3e358p+6,
  -0x1.4b1744p+7,-0x1.d42d1p+6,-0x1.47347cp+7,-0x1.d476bcp+6,-0x1.432cdcp+7,0x1p+3,
  -0x1.d7a14cp+6,-0x1.2f5068p+7,-0x1.e043ecp+6,-0x1.2ee1ep+7,-0x1.ec112p+6,-0x1.4530acp+7,
  0x1p+3,-0x1.f18934p+6,-0x1.5777d8p+7,-0x1.fb9c4p+6,-0x1.603f52p+7,-0x1.192678p+7,
  -0x1.5a7d9p+7,0x1.cp+2,-0x1.192678p+7,-0x1.61661p+7,0x1p+3,-0x1.12192p+7,-0x1.628cd4p+7,
  -0x1.0a7864p+7,-0x1.63450ap+7,-0x1.01d5c4p+7,-0x1.62d68p+7,0x1p+3,-0x1.efcf1p+6,
  -0x1.611c64p+7,-0x1.f7de5p+6,-0x1.5cefe8p+7,-0x1.ded38p+6,-0x1.49f086p+7,0x1p+3,
  -0x1.d630ep+6,-0x1.47347cp+7,-0x1.db5f3cp+6,-0x1.669474p+7,-0x1.eaa0b4p+6,-0x1.6c7b0cp+7,
  0x1p+3,-0x1.eb340cp+6,-0x1.6fca74p+7,-0x1.0b7a4cp+7,-0x1.6c7b0cp+7,-0x1.192678p+7,
  -0x1.6ac0eep+7,0x1.cp+2,-0x1.192678p+7,-0x1.701428p+7,0x1.4p+3,0x1.8p+2,-0x1.457a6p+7,
  -0x1.77d9b8p+7,0x1p+3,-0x1.3f4a18p+7,-0x1.796fp+7,-0x1.27d48ap+7,-0x1.6dc6a4p+7,
  -0x1.1a96e8p+7,-0x1.6fca74p+7,0x1p+3,-0x1.1a0388p+7,-0x1.6fef4cp+7,-0x1.1995p+7,
  -0x1.6fef4cp+7,-0x1.192678p+7,-0x1.701428p+7,0x1.cp+2,-0x1.192678p+7,-0x1.6ac0eep+7,
  0x1p+3,-0x1.1a96e8p+7,-0x1.6a9c14p+7,-0x1.1c2c3p+7,-0x1.6a773cp+7,-0x1.1d77c8p+7,
  -0x1.6a5264p+7,0x1p+3,-0x1.292022p+7,-0x1.69e3dcp+7,-0x1.353704p+7,-0x1.6ae5c4p+7,
  -0x1.4172bep+7,-0x1.6f3716p+7,0x1p+3,-0x1.459f38p+7,-0x1.70a786p+7,-0x1.457a6p+7,
  -0x1.6dc6a4p+7,-0x1.4351b8p+7,-0x1.68bd1ap+7,0x1p+3,-0x1.404cp+7,-0x1.628cd4p+7,
  -0x1.3eb6b6p+7,-0x1.5ecee2p+7,-0x1.39d206p+7,-0x1.5598ep+7,0x1p+3,-0x1.36f124p+7,
  -0x1.4e66aep+7,-0x1.3a1bb4p+7,-0x1.3b8c26p+7,-0x1.3fb89ep+7,-0x1.310a8ap+7,0x1p+3,
  -0x1.483668p+7,-0x1.25d0b8p+7,-0x1.35a58cp+7,-0x1.263f4p+7,-0x1.3459f6p+7,-0x1.3008a2p+7,
  0x1p+3,-0x1.329fd4p+7,-0x1.3cfc92p+7,-0x1.325624p+7,-0x1.46c5f8p+7,-0x1.330e5cp+7,
  -0x1.4fb248p+7,0x1p+3,-0x1.310a8cp+7,-0x1.5854eap+7,-0x1.2cde14p+7,-0x1.5a7d9p+7,
  -0x1.26641ap+7,-0x1.5e853p+7,0x1p+3,-0x1.2212c8p+7,-0x1.5fabf4p+7,-0x1.1d9cap+7,
  -0x1.60addcp+7,-0x1.192678p+7,-0x1.61661p+7,0x1.cp+2,-0x1.192678p+7,-0x1.5a7d9p+7,
  0x1p+3,-0x1.1b2a48p+7,-0x1.5a0f08p+7,-0x1.1d77c8p+7,-0x1.597ba8p+7,-0x1.1fc548p+7,
  -0x1.58e848p+7,0x1p+3,-0x1.3919ccp+7,-0x1.59ea3p+7,-0x1.29b384p+7,-0x1.2ee1ep+7,
  -0x1.2ebd0cp+7,-0x1.2d02ecp+7,0x1p+3,-0x1.386194p+7,-0x1.233984p+7,-0x1.4095bp+7,
  -0x1.20ec08p+7,-0x1.477e3p+7,-0x1.263f4p+7,0x1p+3,-0x1.4a83e8p+7,-0x1.2ab568p+7,
  -0x1.4c62ep+7,-0x1.2ee1ep+7,-0x1.447878p+7,-0x1.3580b2p+7,0x1p+3,-0x1.3b675p+7,
  -0x1.42997cp+7,-0x1.3fb89ep+7,-0x1.419794p+7,-0x1.3db4cep+7,-0x1.4fd71ep+7,0x1p+3,
  -0x1.3b4276p+7,-0x1.5ca63cp+7,-0x1.54039cp+7,-0x1.6b7924p+7,-0x1.457a6p+7,-0x1.77d9b8p+7,
  0x1.4p+3,]
;

public enum BaphometDims = 512; /// it is square

public void baphometRender (scope void delegate (int x, int y) nothrow @trusted @nogc drawPixel, float ofsx=0, float ofsy=0, float scale=1) nothrow @trusted @nogc { renderPath(drawPixel, baphometPath[], ofsx, ofsy, scale); } ///

private void renderPath (scope void delegate (int x, int y) nothrow @trusted @nogc drawPixel, const(float)[] path, float ofsx, float ofsy, float scale) nothrow @trusted @nogc {
  import std.math : floor;

  void drawLine (int x0, int y0, int x1, int y1) {
    import std.math : abs;
    int dx = abs(x1-x0), sx = (x0 < x1 ? 1 : -1);
    int dy = -abs(y1-y0), sy = (y0 < y1 ? 1 : -1);
    int err = dx+dy; // error value e_xy
    for (;;) {
      drawPixel(x0, y0);
      int e2 = 2*err;
      // e_xy+e_x > 0
      if (e2 >= dy) {
        if (x0 == x1) break;
        err += dy; x0 += sx;
      }
      // e_xy+e_y < 0
      if (e2 <= dx) {
        if (y0 == y1) break;
        err += dx; y0 += sy;
      }
    }
  }

  // plot a limited quadratic Bezier segment
  void drawQuadBezierSeg (int x0, int y0, int x1, int y1, int x2, int y2) {
    int sx = x2-x1, sy = y2-y1;
    long xx = x0-x1, yy = y0-y1, xy; // relative values for checks
    double cur = xx*sy-yy*sx; // curvature
    assert(xx*sx <= 0 && yy*sy <= 0); // sign of gradient must not change
    // begin with longer part
    if (sx*cast(long)sx+sy*cast(long)sy > xx*xx+yy*yy) { x2 = x0; x0 = sx+x1; y2 = y0; y0 = sy+y1; cur = -cur; } // swap P0 P2
    // no straight line
    if (cur != 0) {
      xx += sx; xx *= (sx = x0 < x2 ? 1 : -1); // x step direction
      yy += sy; yy *= (sy = y0 < y2 ? 1 : -1); // y step direction
      xy = 2*xx*yy; xx *= xx; yy *= yy; // differences 2nd degree
      // negated curvature?
      if (cur*sx*sy < 0) { xx = -xx; yy = -yy; xy = -xy; cur = -cur; }
      double dx = 4.0*sy*cur*(x1-x0)+xx-xy; // differences 1st degree
      double dy = 4.0*sx*cur*(y0-y1)+yy-xy;
      xx += xx;
      yy += yy;
      double err = dx+dy+xy; // error 1st step
      do {
        drawPixel(x0, y0); // plot curve
        if (x0 == x2 && y0 == y2) return; // last pixel -> curve finished
        y1 = 2*err < dx; // save value for test of y step
        if (2*err > dy) { x0 += sx; dx -= xy; err += dy += yy; } // x step
        if (    y1    ) { y0 += sy; dy -= xy; err += dx += xx; } // y step
      } while (dy < 0 && dx > 0); // gradient negates -> algorithm fails
    }
    drawLine(x0, y0, x2, y2); // plot remaining part to end
  }

  // plot any quadratic Bezier curve
  void drawQuadBezier (int x0, int y0, int x1, int y1, int x2, int y2) {
    import std.math : abs, floor;

    int x = x0-x1, y = y0-y1;
    double t = x0-2*x1+x2;

    // horizontal cut at P4?
    if (cast(long)x*(x2-x1) > 0) {
      // vertical cut at P6 too?
      if (cast(long)y*(y2-y1) > 0) {
        // which first?
        if (abs((y0-2*y1+y2)/t*x) > abs(y)) { x0 = x2; x2 = x+x1; y0 = y2; y2 = y+y1; } // swap points
        // now horizontal cut at P4 comes first
      }
      t = (x0-x1)/t;
      double r = (1-t)*((1-t)*y0+2.0*t*y1)+t*t*y2; // By(t=P4)
      t = (x0*x2-x1*x1)*t/(x0-x1); // gradient dP4/dx=0
      x = cast(int)floor(t+0.5); y = cast(int)floor(r+0.5);
      r = (y1-y0)*(t-x0)/(x1-x0)+y0; // intersect P3 | P0 P1
      drawQuadBezierSeg(x0, y0, x, cast(int)floor(r+0.5), x, y);
      r = (y1-y2)*(t-x2)/(x1-x2)+y2; // intersect P4 | P1 P2
      x0 = x1 = x; y0 = y; y1 = cast(int)floor(r+0.5); // P0 = P4, P1 = P8
    }
    // vertical cut at P6?
    if (cast(long)(y0-y1)*(y2-y1) > 0) {
      t = y0-2*y1+y2; t = (y0-y1)/t;
      double r = (1-t)*((1-t)*x0+2.0*t*x1)+t*t*x2; // Bx(t=P6)
      t = (y0*y2-y1*y1)*t/(y0-y1); // gradient dP6/dy=0
      x = cast(int)floor(r+0.5); y = cast(int)floor(t+0.5);
      r = (x1-x0)*(t-y0)/(y1-y0)+x0; // intersect P6 | P0 P1
      drawQuadBezierSeg(x0, y0, cast(int)floor(r+0.5), y, x, y);
      r = (x1-x2)*(t-y2)/(y1-y2)+x2; // intersect P7 | P1 P2
      x0 = x; x1 = cast(int)floor(r+0.5); y0 = y1 = y; // P0 = P6, P1 = P7
    }
    drawQuadBezierSeg(x0, y0, x1, y1, x2, y2); // remaining part
  }

  // plot limited cubic Bezier segment
  void drawCubicBezierSeg (int x0, int y0, float x1, float y1, float x2, float y2, int x3, int y3) {
    import std.math : abs, floor, sqrt;
    immutable double EP = 0.01;

    int f, fx, fy, leg = 1;
    int sx = (x0 < x3 ? 1 : -1), sy = (y0 < y3 ? 1 : -1); // step direction
    float xc = -abs(x0+x1-x2-x3), xa = xc-4*sx*(x1-x2), xb = sx*(x0-x1-x2+x3);
    float yc = -abs(y0+y1-y2-y3), ya = yc-4*sy*(y1-y2), yb = sy*(y0-y1-y2+y3);
    double ab, ac, bc, cb, xx, xy, yy, dx, dy, ex;
    const(double)* pxy;

    // check for curve restrains
    // slope P0-P1 == P2-P3   and  (P0-P3 == P1-P2      or  no slope change)
    assert((x1-x0)*(x2-x3) < EP && ((x3-x0)*(x1-x2) < EP || xb*xb < xa*xc+EP));
    assert((y1-y0)*(y2-y3) < EP && ((y3-y0)*(y1-y2) < EP || yb*yb < ya*yc+EP));
    // quadratic Bezier
    if (xa == 0 && ya == 0) {
      // new midpoint
      sx = cast(int)floor((3*x1-x0+1)/2);
      sy = cast(int)floor((3*y1-y0+1)/2);
      return drawQuadBezierSeg(x0, y0, sx, sy, x3, y3);
    }
    x1 = (x1-x0)*(x1-x0)+(y1-y0)*(y1-y0)+1; // line lengths
    x2 = (x2-x3)*(x2-x3)+(y2-y3)*(y2-y3)+1;
    do { // loop over both ends
      ab = xa*yb-xb*ya; ac = xa*yc-xc*ya; bc = xb*yc-xc*yb;
      ex = ab*(ab+ac-3*bc)+ac*ac; // P0 part of self-intersection loop?
      f = cast(int)(ex > 0 ? 1 : sqrt(1+1024/x1)); // calculate resolution
      ab *= f; ac *= f; bc *= f; ex *= f*f; // increase resolution
      xy = 9*(ab+ac+bc)/8; cb = 8*(xa-ya);/* init differences of 1st degree */
      dx = 27*(8*ab*(yb*yb-ya*yc)+ex*(ya+2*yb+yc))/64-ya*ya*(xy-ya);
      dy = 27*(8*ab*(xb*xb-xa*xc)-ex*(xa+2*xb+xc))/64-xa*xa*(xy+xa);
      // init differences of 2nd degree
      xx = 3*(3*ab*(3*yb*yb-ya*ya-2*ya*yc)-ya*(3*ac*(ya+yb)+ya*cb))/4;
      yy = 3*(3*ab*(3*xb*xb-xa*xa-2*xa*xc)-xa*(3*ac*(xa+xb)+xa*cb))/4;
      xy = xa*ya*(6*ab+6*ac-3*bc+cb); ac = ya*ya; cb = xa*xa;
      xy = 3*(xy+9*f*(cb*yb*yc-xb*xc*ac)-18*xb*yb*ab)/8;
      if (ex < 0) { // negate values if inside self-intersection loop
        dx = -dx; dy = -dy; xx = -xx; yy = -yy; xy = -xy; ac = -ac; cb = -cb;
      } // init differences of 3rd degree
      ab = 6*ya*ac; ac = -6*xa*ac; bc = 6*ya*cb; cb = -6*xa*cb;
      dx += xy; ex = dx+dy; dy += xy; // error of 1st step
      zzloop: for (pxy = &xy, fx = fy = f; x0 != x3 && y0 != y3; ) {
        drawPixel(x0, y0); // plot curve
        do { // move sub-steps of one pixel
          if (dx > *pxy || dy < *pxy) break zzloop; // confusing values
          y1 = 2*ex-dy; // save value for test of y step
          if (2*ex >= dx) { fx--; ex += dx += xx; dy += xy += ac; yy += bc; xx += ab; } // x sub-step
          if (y1 <= 0) { fy--; ex += dy += yy; dx += xy += bc; xx += ac; yy += cb; } // y sub-step
        } while (fx > 0 && fy > 0); // pixel complete?
        if (2*fx <= f) { x0 += sx; fx += f; } // x step
        if (2*fy <= f) { y0 += sy; fy += f; } // y step
        if (pxy == &xy && dx < 0 && dy > 0) pxy = &EP;/* pixel ahead valid */
      }
      xx = x0; x0 = x3; x3 = cast(int)xx; sx = -sx; xb = -xb; // swap legs
      yy = y0; y0 = y3; y3 = cast(int)yy; sy = -sy; yb = -yb; x1 = x2;
    } while (leg--); // try other end
    drawLine(x0, y0, x3, y3); // remaining part in case of cusp or crunode
  }

  // plot any cubic Bezier curve
  void drawCubicBezier (int x0, int y0, int x1, int y1, int x2, int y2, int x3, int y3) {
    import std.math : abs, floor, sqrt;
    int n = 0, i = 0;
    long xc = x0+x1-x2-x3, xa = xc-4*(x1-x2);
    long xb = x0-x1-x2+x3, xd = xb+4*(x1+x2);
    long yc = y0+y1-y2-y3, ya = yc-4*(y1-y2);
    long yb = y0-y1-y2+y3, yd = yb+4*(y1+y2);
    float fx0 = x0, fx1, fx2, fx3, fy0 = y0, fy1, fy2, fy3;
    double t1 = xb*xb-xa*xc, t2;
    double[5] t;
    // sub-divide curve at gradient sign changes
    if (xa == 0) { // horizontal
      if (abs(xc) < 2*abs(xb)) t[n++] = xc/(2.0*xb); // one change
    } else if (t1 > 0.0) { // two changes
      t2 = sqrt(t1);
      t1 = (xb-t2)/xa; if (abs(t1) < 1.0) t[n++] = t1;
      t1 = (xb+t2)/xa; if (abs(t1) < 1.0) t[n++] = t1;
    }
    t1 = yb*yb-ya*yc;
    if (ya == 0) { // vertical
      if (abs(yc) < 2*abs(yb)) t[n++] = yc/(2.0*yb); // one change
    } else if (t1 > 0.0) { // two changes
      t2 = sqrt(t1);
      t1 = (yb-t2)/ya; if (abs(t1) < 1.0) t[n++] = t1;
      t1 = (yb+t2)/ya; if (abs(t1) < 1.0) t[n++] = t1;
    }
    // bubble sort of 4 points
    for (i = 1; i < n; i++) if ((t1 = t[i-1]) > t[i]) { t[i-1] = t[i]; t[i] = t1; i = 0; }
    t1 = -1.0; t[n] = 1.0; // begin / end point
    for (i = 0; i <= n; i++) { // plot each segment separately
      t2 = t[i]; // sub-divide at t[i-1], t[i]
      fx1 = (t1*(t1*xb-2*xc)-t2*(t1*(t1*xa-2*xb)+xc)+xd)/8-fx0;
      fy1 = (t1*(t1*yb-2*yc)-t2*(t1*(t1*ya-2*yb)+yc)+yd)/8-fy0;
      fx2 = (t2*(t2*xb-2*xc)-t1*(t2*(t2*xa-2*xb)+xc)+xd)/8-fx0;
      fy2 = (t2*(t2*yb-2*yc)-t1*(t2*(t2*ya-2*yb)+yc)+yd)/8-fy0;
      fx0 -= fx3 = (t2*(t2*(3*xb-t2*xa)-3*xc)+xd)/8;
      fy0 -= fy3 = (t2*(t2*(3*yb-t2*ya)-3*yc)+yd)/8;
      // scale bounds to int
      x3 = cast(int)floor(fx3+0.5);
      y3 = cast(int)floor(fy3+0.5);
      if (fx0 != 0.0) { fx1 *= fx0 = (x0-x3)/fx0; fx2 *= fx0; }
      if (fy0 != 0.0) { fy1 *= fy0 = (y0-y3)/fy0; fy2 *= fy0; }
      if (x0 != x3 || y0 != y3) drawCubicBezierSeg(x0, y0, x0+fx1, y0+fy1, x0+fx2, y0+fy2, x3, y3); // segment t1 - t2
      x0 = x3; y0 = y3; fx0 = fx3; fy0 = fy3; t1 = t2;
    }
  }

  enum Command {
    Bounds, // always first, has 4 args (x0, y0, x1, y1)
    StrokeMode,
    FillMode,
    StrokeFillMode,
    NormalStroke,
    ThinStroke,
    MoveTo,
    LineTo,
    CubicTo, // cubic bezier
    EndPath, // don't close this path
    ClosePath, // close this path, start new path
  }
  static assert(Command.StrokeMode == 1);
  static assert(Command.FillMode == 2);

  int scaleX (float v) nothrow @trusted @nogc => cast(int)floor(ofsx+v*scale);
  int scaleY (float v) nothrow @trusted @nogc => cast(int)floor(ofsy+v*scale);

  if (path.length == 0) return;
  bool firstPoint = true;
  float firstx = 0, firsty = 0, cx = 0, cy = 0;
  usize pos = 0;
  int mode = 0;
  int sw = Command.NormalStroke;
  while (pos < path.length) {
    switch (cast(Command)path.ptr[pos++]) {
      case Command.Bounds: pos += 4; break;
      case Command.StrokeMode: mode = Command.StrokeMode; break;
      case Command.FillMode: mode = Command.FillMode; break;
      case Command.StrokeFillMode: mode = Command.StrokeFillMode; break;
      case Command.NormalStroke: sw = Command.NormalStroke; /*fc = fgc;*/ break;
      case Command.ThinStroke: sw = Command.ThinStroke; /*fc = fgc.setLightness(0.3);*/ break;
      case Command.MoveTo:
        if (path.length-pos < 2) assert(0, "invalid path command");
        cx = path.ptr[pos];
        cy = path.ptr[pos+1];
        if (firstPoint) { firstx = cx; firsty = cy; firstPoint = false; }
        pos += 2;
        continue;
      case Command.LineTo:
        if (path.length-pos < 2) assert(0, "invalid path command");
        if (firstPoint) assert(0, "invalid path command");
        drawLine(scaleX(cx), scaleY(cy), scaleX(path.ptr[pos+0]), scaleY(path.ptr[pos+1]));
        cx = path.ptr[pos+0];
        cy = path.ptr[pos+1];
        pos += 2;
        continue;
      case Command.CubicTo: // cubic bezier
        if (path.length-pos < 6) assert(0, "invalid path command");
        if (firstPoint) assert(0, "invalid path command");
        drawCubicBezier(
          scaleX(cx), scaleY(cy),
          scaleX(path.ptr[pos+0]), scaleY(path.ptr[pos+1]),
          scaleX(path.ptr[pos+2]), scaleY(path.ptr[pos+3]),
          scaleX(path.ptr[pos+4]), scaleY(path.ptr[pos+5]),
        );
        cx = path.ptr[pos+4];
        cy = path.ptr[pos+5];
        pos += 6;
        continue;
      case Command.ClosePath: // close this path, start new path
        if (!firstPoint) drawLine(scaleX(cx), scaleY(cy), scaleX(firstx), scaleY(firsty));
        goto case Command.EndPath;
      case Command.EndPath: // don't close this path
        firstPoint = true;
        break;
      default: assert(0, "invalid path command");
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
version(glbinds_mixin) import iv.glbinds.binds_full_mixin; else import iv.glbinds;
