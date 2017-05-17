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
module iv.vl2.vlo /*is aliced*/;

import iv.vl2.core;
import iv.vl2.font6;


// ////////////////////////////////////////////////////////////////////////// //
version(GNU) {
  static import gcc.attribute;
  private enum gcc_inline = gcc.attribute.attribute("forceinline");
  private enum gcc_noinline = gcc.attribute.attribute("noinline");
  private enum gcc_flatten = gcc.attribute.attribute("flatten");
} else {
  // hackery for non-gcc compilers
  private enum gcc_inline;
  private enum gcc_noinline;
  private enum gcc_flatten;
}


// ////////////////////////////////////////////////////////////////////////// //
__gshared VLOverlay vlsOvl; /// vscreen overlay


// ////////////////////////////////////////////////////////////////////////// //
private void vloInitVSO () {
  vlsOvl.setupWithVScr(vlVScr, vlWidth, vlHeight);
}


private void vloDeinitVSO () {
  vlsOvl.free(); // this will not free VScr, as vlsOvl isn't own it
}


shared static this () {
  vlInitHook = &vloInitVSO;
  vlDeinitHook = &vloDeinitVSO;
}


// ////////////////////////////////////////////////////////////////////////// //
// BEWARE! ANY COPIES WILL RESET `vscrOwn` FLAG! NO REFCOUNTING HERE!
struct VLOverlay {
//private:
public:
  int mWidth, mHeight;
  int mClipX0, mClipY0;
  int mClipX1, mClipY1;
  int mXOfs, mYOfs;
  uint* mVScr;
  bool vscrOwn; // true: `free()` mVScr in dtor

//private:
public:
  this (void* avscr, int wdt, int hgt) @trusted nothrow @nogc { setupWithVScr(avscr, wdt, hgt); }

public:
  this(TW, TH) (TW wdt, TH hgt) if (__traits(isIntegral, TW) && __traits(isIntegral, TH)) {
    resize(wdt, hgt);
  }

  ~this () @trusted nothrow @nogc { free(); }

  // any copy resets "own" flag
  this (this) @safe nothrow @nogc { vscrOwn = false; }

//final:
  void setupWithVScr (void* avscr, int wdt, int hgt) @trusted nothrow @nogc {
    if (wdt < 1 || hgt < 1 || avscr is null) {
      free();
    } else {
      if (avscr !is mVScr) free();
      mVScr = cast(uint*)avscr;
      vscrOwn = false;
      mWidth = wdt;
      mHeight = hgt;
      resetClipOfs();
    }
  }

  void resize(TW, TH) (TW wdt, TH hgt) if (__traits(isIntegral, TW) && __traits(isIntegral, TH)) {
    import core.exception : onOutOfMemoryError;
    import core.stdc.stdlib : malloc, realloc, free;
    if (wdt < 1 || wdt > 16384 || hgt < 1 || hgt > 16384) throw new VideoLibError("VLOverlay: invalid size");
    if (!vscrOwn) throw new VideoLibError("VLOverlay: can't resize predefined overlay");
    if (mVScr is null) {
      mWidth = cast(int)wdt;
      mHeight = cast(int)hgt;
      mVScr = cast(uint*)malloc(mWidth*mHeight*mVScr[0].sizeof);
      if (mVScr is null) onOutOfMemoryError();
    } else if (mWidth != cast(int)wdt || mHeight != cast(int)hgt) {
      mWidth = cast(int)wdt;
      mHeight = cast(int)hgt;
      auto scr = cast(uint*)realloc(mVScr, mWidth*mHeight*mVScr[0].sizeof);
      if (scr is null) { this.free(); onOutOfMemoryError(); }
      mVScr = scr;
    }
    resetClipOfs();
  }

  /// WARNING! this will trash virtual screen!
  @property void width(T) (T w) if (__traits(isIntegral, T)) { resize(w, mHeight); }
  @property void height(T) (T h) if (__traits(isIntegral, T)) { resize(mWidth, h); }

@nogc:
nothrow:
  @property bool valid () const pure { return (mVScr !is null); }

  void free () @trusted {
    if (vscrOwn && mVScr !is null) {
      import core.stdc.stdlib : free;
      free(mVScr);
      mVScr = null;
    }
    mWidth = 1;
    mHeight = 1;
    resetClipOfs();
  }

  /**
   * Draw (possibly semi-transparent) pixel onto virtual screen; mix colors.
   *
   * Params:
   *  x = x coordinate
   *  y = y coordinate
   *  col = rgba color
   *
   * Returns:
   *  nothing
   */
  @gcc_inline void putPixel(TX, TY) (TX x, TY y, Color col) @trusted
  if (__traits(isIntegral, TX) && __traits(isIntegral, TY))
  {
    static if (__VERSION__ > 2067) pragma(inline, true);
    immutable long xx = cast(long)x+mXOfs;
    immutable long yy = cast(long)y+mYOfs;
    if ((col&vlAMask) != vlAMask && xx >= mClipX0 && yy >= mClipY0 && xx <= mClipX1 && yy <= mClipY1) {
      uint* da = mVScr+yy*mWidth+xx;
      if (col&vlAMask) {
        immutable uint a = 256-(col>>24); // to not loose bits
        immutable uint dc = (*da)&0xffffff;
        immutable uint srb = (col&0xff00ff);
        immutable uint sg = (col&0x00ff00);
        immutable uint drb = (dc&0xff00ff);
        immutable uint dg = (dc&0x00ff00);
        immutable uint orb = (drb+(((srb-drb)*a+0x800080)>>8))&0xff00ff;
        immutable uint og = (dg+(((sg-dg)*a+0x008000)>>8))&0x00ff00;
        *da = orb|og;
      } else {
        *da = col;
      }
    }
  }

  /**
   * Draw (possibly semi-transparent) pixel onto virtual screen; don't mix colors.
   *
   * Params:
   *  x = x coordinate
   *  y = y coordinate
   *  col = rgba color
   *
   * Returns:
   *  nothing
   */
  @gcc_inline void setPixel(TX, TY) (TX x, TY y, Color col) @trusted
  if (__traits(isIntegral, TX) && __traits(isIntegral, TY))
  {
    static if (__VERSION__ > 2067) pragma(inline, true);
    immutable long xx = cast(long)x+mXOfs;
    immutable long yy = cast(long)y+mYOfs;
    if (xx >= mClipX0 && yy >= mClipY0 && xx <= mClipX1 && yy <= mClipY1) {
      uint* da = mVScr+yy*mWidth+xx;
      *da = col;
    }
  }

  void resetClipOfs () @safe {
    if (mVScr !is null) {
      mClipX0 = mClipY0 = mXOfs = mYOfs = 0;
      mClipX1 = mWidth-1;
      mClipY1 = mHeight-1;
    } else {
      // all functions checks clipping, and this is not valid region
      // so we can omit VScr checks
      mClipX0 = mClipY0 = -42;
      mClipX1 = mClipY1 = -666;
    }
  }

  @property int width () const @safe pure { return mWidth; }
  @property int height () const @safe pure { return mHeight; }

  @property int xOfs () const @safe pure { return mXOfs; }
  @property void xOfs (int v) @safe { mXOfs = v; }

  @property int yOfs () const @safe pure { return mYOfs; }
  @property void yOfs (int v) @safe { mYOfs = v; }

  void getOfs (ref int x, ref int y) const @safe pure { x = mXOfs; y = mYOfs; }
  void setOfs (in int x, in int y) @safe { mXOfs = x; mYOfs = y; }


  struct Ofs {
    int x, y;
  }

  void getOfs (ref Ofs ofs) const @safe pure { ofs.x = mXOfs; ofs.y = mYOfs; }
  void setOfs (in ref Ofs ofs) @safe { mXOfs = ofs.x; mYOfs = ofs.y; }
  void resetOfs () @safe { mXOfs = mYOfs = 0; }


  struct Clip {
    int x, y, w, h;
  }

  void getClip (ref int x0, ref int y0, ref int wdt, ref int hgt) const @safe pure {
    if (mVScr !is null) {
      x0 = mClipX0;
      y0 = mClipY0;
      wdt = mClipX1-mClipX0+1;
      hgt = mClipY1-mClipY0+1;
    } else {
      x0 = y0 = wdt = hgt = 0;
    }
  }

  void setClip (in int x0, in int y0, in int wdt, in int hgt) @safe {
    if (mVScr !is null) {
      mClipX0 = x0;
      mClipY0 = y0;
      mClipX1 = (wdt > 0 ? x0+wdt-1 : x0-1);
      mClipY1 = (hgt > 0 ? y0+hgt-1 : y0-1);
      if (mClipX0 < 0) mClipX0 = 0;
      if (mClipY0 < 0) mClipY0 = 0;
      if (mClipX0 >= mWidth) mClipX0 = mWidth-1;
      if (mClipY0 >= mHeight) mClipY0 = mHeight-1;
      if (mClipX1 < 0) mClipX1 = 0;
      if (mClipY1 < 0) mClipY1 = 0;
      if (mClipX1 >= mWidth) mClipX1 = mWidth-1;
      if (mClipY1 >= mHeight) mClipY1 = mHeight-1;
    }
  }

  void resetClip () @safe {
    if (mVScr !is null) {
      mClipX0 = mClipY0 = 0;
      mClipX1 = mWidth-1;
      mClipY1 = mHeight-1;
    } else {
      // all functions checks clipping, and this is not valid region
      // so we can omit VScr checks
      mClipX0 = mClipY0 = -42;
      mClipX1 = mClipY1 = -666;
    }
  }

  void getClip (ref Clip clip) const @safe pure { getClip(clip.x, clip.y, clip.w, clip.h); }
  void setClip (in ref Clip clip) @safe { setClip(clip.x, clip.y, clip.w, clip.h); }

  void clipIntrude (int dx, int dy) @safe {
    if (mVScr !is null) {
      mClipX0 += dx;
      mClipY0 += dx;
      mClipX1 -= dx;
      mClipY1 -= dx;
      if (mClipX1 >= mClipX0 && mClipY1 >= mClipY0) {
        setClip(mClipX0, mClipY0, mClipX1-mClipX0+1, mClipY1-mClipY0+1);
      }
    }
  }

  void clipExtrude (int dx, int dy) @safe { clipIntrude(-dx, -dy); }

  // //////////////////////////////////////////////////////////////////////// //
  /**
   * Draw character onto virtual screen in KOI8 encoding.
   *
   * Params:
   *  x = x coordinate
   *  y = y coordinate
   *  wdt = char width
   *  shift = shl count
   *  ch = character
   *  col = foreground color
   *  bkcol = background color
   *
   * Returns:
   *  nothing
   */
  void drawCharWdt (int x, int y, int wdt, int shift, char ch, Color col, Color bkcol=vlcTransparent) @trusted {
    usize pos = ch*8;
    if (wdt < 1 || shift >= 8) return;
    if (col == vlcTransparent && bkcol == vlcTransparent) return;
    if (wdt > 8) wdt = 8;
    if (shift < 0) shift = 0;
    foreach (immutable int dy; 0..8) {
      ubyte b = cast(ubyte)(vlFont6[pos++]<<shift);
      foreach (immutable int dx; 0..wdt) {
        Color c = (b&0x80 ? col : bkcol);
        if (!vlcIsTransparent(c)) putPixel(x+dx, y+dy, c);
        b = (b<<1)&0xff;
      }
    }
  }

  // outline types
  enum : ubyte {
    OutLeft   = 0x01,
    OutRight  = 0x02,
    OutUp     = 0x04,
    OutDown   = 0x08,
    OutLU     = 0x10, // left-up
    OutRU     = 0x20, // right-up
    OutLD     = 0x40, // left-down
    OutRD     = 0x80, // right-down
    OutAll    = 0xff,
  }

  /**
   * Draw outlined character onto virtual screen in KOI8 encoding.
   *
   * Params:
   *  x = x coordinate
   *  y = y coordinate
   *  wdt = char width
   *  shift = shl count
   *  ch = character
   *  col = foreground color
   *  outcol = outline color
   *  ot = outline type, OutXXX, ored
   *
   * Returns:
   *  nothing
   */
  void drawCharWdtOut (int x, int y, int wdt, int shift, char ch, Color col, Color outcol=vlcTransparent, ubyte ot=0) @trusted {
    if (col == vlcTransparent && outcol == vlcTransparent) return;
    if (ot == 0 || outcol == vlcTransparent) {
      // no outline? simple draw
      drawCharWdt(x, y, wdt, shift, ch, col, vlcTransparent);
      return;
    }
    usize pos = ch*8;
    if (wdt < 1 || shift >= 8) return;
    if (wdt > 8) wdt = 8;
    if (shift < 0) shift = 0;
    ubyte[8+2][8+2] bmp = 0; // char bitmap; 0: empty; 1: char; 2: outline
    foreach (immutable dy; 1..9) {
      ubyte b = cast(ubyte)(vlFont6[pos++]<<shift);
      foreach (immutable dx; 1..wdt+1) {
        if (b&0x80) {
          // put pixel
          bmp[dy][dx] = 1;
          // put outlines
          if ((ot&OutUp) && bmp[dy-1][dx] == 0) bmp[dy-1][dx] = 2;
          if ((ot&OutDown) && bmp[dy+1][dx] == 0) bmp[dy+1][dx] = 2;
          if ((ot&OutLeft) && bmp[dy][dx-1] == 0) bmp[dy][dx-1] = 2;
          if ((ot&OutRight) && bmp[dy][dx+1] == 0) bmp[dy][dx+1] = 2;
          if ((ot&OutLU) && bmp[dy-1][dx-1] == 0) bmp[dy-1][dx-1] = 2;
          if ((ot&OutRU) && bmp[dy-1][dx+1] == 0) bmp[dy-1][dx+1] = 2;
          if ((ot&OutLD) && bmp[dy+1][dx-1] == 0) bmp[dy+1][dx-1] = 2;
          if ((ot&OutRD) && bmp[dy+1][dx+1] == 0) bmp[dy+1][dx+1] = 2;
        }
        b = (b<<1)&0xff;
      }
    }
    // now draw it
    --x;
    --y;
    foreach (immutable int dy; 0..10) {
      foreach (immutable int dx; 0..10) {
        if (auto t = bmp[dy][dx]) putPixel(x+dx, y+dy, (t == 1 ? col : outcol));
      }
    }
  }

  /**
   * Draw 6x8 character onto virtual screen in KOI8 encoding.
   *
   * Params:
   *  x = x coordinate
   *  y = y coordinate
   *  ch = character
   *  col = foreground color
   *  bkcol = background color
   *
   * Returns:
   *  nothing
   */
  void drawChar (int x, int y, char ch, Color col, Color bkcol=vlcTransparent) @trusted {
    drawCharWdt(x, y, 6, 0, ch, col, bkcol);
  }

  void drawCharOut (int x, int y, char ch, Color col, Color outcol=vlcTransparent, ubyte ot=OutAll) @trusted {
    drawCharWdtOut(x, y, 6, 0, ch, col, outcol, ot);
  }

  void drawStr (int x, int y, string str, Color col, Color bkcol=vlcTransparent) @trusted {
    foreach (immutable char ch; str) {
      drawChar(x, y, ch, col, bkcol);
      x += 6;
    }
  }

  void drawStrOut (int x, int y, string str, Color col, Color outcol=vlcTransparent, ubyte ot=OutAll) @trusted {
    foreach (immutable char ch; str) {
      drawCharOut(x, y, ch, col, outcol, ot);
      x += 6;
    }
  }

  static int charWidthProp (char ch) @trusted pure { return (vlFontPropWidth[ch]&0x0f); }

  int strWidthProp (string str) @trusted pure {
    int wdt = 0;
    foreach (immutable char ch; str) wdt += (vlFontPropWidth[ch]&0x0f)+1;
    if (wdt > 0) --wdt; // don't count last empty pixel
    return wdt;
  }

  int drawCharProp (int x, int y, char ch, Color col, Color bkcol=vlcTransparent) @trusted {
    immutable int wdt = (vlFontPropWidth[ch]&0x0f);
    drawCharWdt(x, y, wdt, vlFontPropWidth[ch]>>4, ch, col, bkcol);
    return wdt;
  }

  int drawCharPropOut (int x, int y, char ch, Color col, Color outcol=vlcTransparent, ubyte ot=OutAll) @trusted {
    immutable int wdt = (vlFontPropWidth[ch]&0x0f);
    drawCharWdtOut(x, y, wdt, vlFontPropWidth[ch]>>4, ch, col, outcol, ot);
    return wdt;
  }

  int drawStrProp (int x, int y, string str, Color col, Color bkcol=vlcTransparent) @trusted {
    bool vline = false;
    int sx = x;
    foreach (immutable char ch; str) {
      if (vline) {
        if (!vlcIsTransparent(bkcol)) foreach (int dy; 0..8) putPixel(x, y+dy, bkcol);
        ++x;
      }
      vline = true;
      x += drawCharProp(x, y, ch, col, bkcol);
    }
    return x-sx;
  }

  int drawStrPropOut (int x, int y, string str, Color col, Color outcol=vlcTransparent, ubyte ot=OutAll) @trusted {
    int sx = x;
    foreach (immutable char ch; str) {
      x += drawCharPropOut(x, y, ch, col, outcol, ot)+1;
    }
    if (x > sx) --x; // don't count last empty pixel
    return x-sx;
  }

  // ////////////////////////////////////////////////////////////////////////// //
  void clear (Color col) @trusted {
    if (mVScr !is null) {
      if (!vscrOwn) col &= 0xffffff;
      mVScr[0..mWidth*mHeight] = col;
    }
  }

  void hline (int x0, int y0, int len, Color col) @trusted {
    if (isOpaque(col) && len > 0 && mVScr !is null) {
      x0 += mXOfs;
      y0 += mYOfs;
      if (y0 >= mClipY0 && x0 <= mClipX1 && y0 <= mClipY1 && x0+len > mClipX0) {
        if (x0 < mClipX0) { if ((len += (x0-mClipX0)) <= 0) return; x0 = mClipX0; }
        if (x0+len-1 > mClipX1) len = mClipX1-x0+1;
        immutable usize ofs = y0*mWidth+x0;
        mVScr[ofs..ofs+len] = col;
      }
    } else {
      while (len-- > 0) putPixel(x0++, y0, col);
    }
  }

  void vline (int x0, int y0, int len, Color col) @trusted {
    while (len-- > 0) putPixel(x0, y0++, col);
  }


  /+
  void drawLine(bool lastPoint) (int x0, int y0, int x1, int y1, Color col) @trusted {
    import std.math : abs;
    int dx =  abs(x1-x0), sx = (x0 < x1 ? 1 : -1);
    int dy = -abs(y1-y0), sy = (y0 < y1 ? 1 : -1);
    int err = dx+dy, e2; // error value e_xy
    for (;;) {
      static if (lastPoint) putPixel(x0, y0, col);
      if (x0 == x1 && y0 == y1) break;
      static if (!lastPoint) putPixel(x0, y0, col);
      e2 = 2*err;
      if (e2 >= dy) { err += dy; x0 += sx; } // e_xy+e_x > 0
      if (e2 <= dx) { err += dx; y0 += sy; } // e_xy+e_y < 0
    }
  }
  +/

  // as the paper on which this code is based in not available to public,
  // i say "fuck you!"
  // knowledge must be publicly available; the ones who hides the knowledge
  // are not deserving any credits.
  void drawLine(bool lastPoint) (int x0, int y0, int x1, int y1, immutable Color col) {
    enum swap(string a, string b) = "{int tmp_="~a~";"~a~"="~b~";"~b~"=tmp_;}";

    if ((col&vlAMask) == vlAMask || mClipX0 > mClipX1 || mClipY0 > mClipY1 || mVScr is null) return;

    if (x0 == x1 && y0 == y1) {
      static if (lastPoint) putPixel(x0, y0, col);
      return;
    }

    x0 += mXOfs; x1 += mXOfs;
    y0 += mYOfs; y1 += mYOfs;

    // clip rectange
    int wx0 = mClipX0, wy0 = mClipY0, wx1 = mClipX1, wy1 = mClipY1;
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
    // draw it; `putPixel()` can omit checks
    while (xd != term) {
      // inlined `putPixel(*d0, *d1, col)`
      // this can be made even faster by precalculating `da` and making
      // separate code branches for mixing and non-mixing drawing, but...
      // ah, screw it!
      uint* da = mVScr+(*d1)*mWidth+(*d0);
      if (col&vlAMask) {
        immutable uint a = 256-(col>>24); // to not loose bits
        immutable uint dc = (*da)&0xffffff;
        immutable uint srb = (col&0xff00ff);
        immutable uint sg = (col&0x00ff00);
        immutable uint drb = (dc&0xff00ff);
        immutable uint dg = (dc&0x00ff00);
        immutable uint orb = (drb+(((srb-drb)*a+0x800080)>>8))&0xff00ff;
        immutable uint og = (dg+(((sg-dg)*a+0x008000)>>8))&0x00ff00;
        *da = orb|og;
      } else {
        *da = col;
      }
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

  void line (int x0, int y0, int x1, int y1, Color col) @trusted { drawLine!true(x0, y0, x1, y1, col); }
  void lineNoLast (int x0, int y0, int x1, int y1, Color col) @trusted { drawLine!false(x0, y0, x1, y1, col); }

  void fillRect (int x, int y, int w, int h, Color col) @trusted {
    x += mXOfs;
    y += mYOfs;
    if (w > 0 && h > 0 && x+w > mClipX0 && y+h > mClipY0 && x <= mClipX1 && y <= mClipY1) {
      SDL_Rect r, sr, dr;
      sr.x = mClipX0; sr.y = mClipY0; sr.w = mClipX1-mClipX0+1; sr.h = mClipY1-mClipY0+1;
      r.x = x; r.y = y; r.w = w; r.h = h;
      if (SDL_IntersectRect(&sr, &r, &dr)) {
        x = dr.x-mXOfs;
        y = dr.y-mYOfs;
        while (dr.h-- > 0) hline(x, y++, dr.w, col);
      }
    }
  }

  void rect (int x, int y, int w, int h, Color col) @trusted {
    if (w > 0 && h > 0) {
      hline(x, y, w, col);
      hline(x, y+h-1, w, col);
      vline(x, y+1, h-2, col);
      vline(x+w-1, y+1, h-2, col);
    }
  }

  /* 4 phases */
  void selectionRect (int phase, int x0, int y0, int wdt, int hgt, Color col0, Color col1=vlcTransparent) @trusted {
    if (wdt > 0 && hgt > 0) {
      // top
      foreach (immutable f; x0..x0+wdt) { putPixel(f, y0, ((phase %= 4) < 2 ? col0 : col1)); ++phase; }
      // right
      foreach (immutable f; y0+1..y0+hgt) { putPixel(x0+wdt-1, f, ((phase %= 4) < 2 ? col0 : col1)); ++phase; }
      // bottom
      foreach_reverse (immutable f; x0..x0+wdt-1) { putPixel(f, y0+hgt-1, ((phase %= 4) < 2 ? col0 : col1)); ++phase; }
      // left
      foreach_reverse (immutable f; y0..y0+hgt-1) { putPixel(x0, f, ((phase %= 4) < 2 ? col0 : col1)); ++phase; }
    }
  }

  private void plot4points() (int cx, int cy, int x, int y, Color clr) @trusted {
    putPixel(cx+x, cy+y, clr);
    if (x != 0) putPixel(cx-x, cy+y, clr);
    if (y != 0) putPixel(cx+x, cy-y, clr);
    putPixel(cx-x, cy-y, clr);
  }

  void circle (int cx, int cy, int radius, Color clr) @trusted {
    if (radius > 0 && !vlcIsTransparent(clr)) {
      int error = -radius, x = radius, y = 0;
      if (radius == 1) { putPixel(cx, cy, clr); return; }
      while (x > y) {
        plot4points(cx, cy, x, y, clr);
        plot4points(cx, cy, y, x, clr);
        error += y*2+1;
        ++y;
        if (error >= 0) { --x; error -= x*2; }
      }
      plot4points(cx, cy, x, y, clr);
    }
  }

  void fillCircle (int cx, int cy, int radius, Color clr) @trusted {
    if (radius > 0 && !vlcIsTransparent(clr)) {
      int error = -radius, x = radius, y = 0;
      if (radius == 1) { putPixel(cx, cy, clr); return; }
      while (x >= y) {
        int last_y = y;
        error += y;
        ++y;
        error += y;
        hline(cx-x, cy+last_y, 2*x+1, clr);
        if (x != 0 && last_y != 0) hline(cx-x, cy-last_y, 2*x+1, clr);
        if (error >= 0) {
          if (x != last_y) {
            hline(cx-last_y, cy+x, 2*last_y+1, clr);
            if (last_y != 0 && x != 0) hline(cx-last_y, cy-x, 2*last_y+1, clr);
          }
          error -= x;
          --x;
          error -= x;
        }
      }
    }
  }

  void ellipse (int x0, int y0, int x1, int y1, Color clr) @trusted {
    import std.math : abs;
    int a = abs(x1-x0), b = abs(y1-y0), b1 = b&1; // values of diameter
    long dx = 4*(1-a)*b*b, dy = 4*(b1+1)*a*a; // error increment
    long err = dx+dy+b1*a*a; // error of 1.step
    if (x0 > x1) { x0 = x1; x1 += a; } // if called with swapped points...
    if (y0 > y1) y0 = y1; // ...exchange them
    y0 += (b+1)/2; y1 = y0-b1;  // starting pixel
    a *= 8*a; b1 = 8*b*b;
    do {
      long e2;
      putPixel(x1, y0, clr); //   I. Quadrant
      putPixel(x0, y0, clr); //  II. Quadrant
      putPixel(x0, y1, clr); // III. Quadrant
      putPixel(x1, y1, clr); //  IV. Quadrant
      e2 = 2*err;
      if (e2 >= dx) { ++x0; --x1; err += dx += b1; } // x step
      if (e2 <= dy) { ++y0; --y1; err += dy += a; }  // y step
    } while (x0 <= x1);
    while (y0-y1 < b) {
      // too early stop of flat ellipses a=1
      putPixel(x0-1, ++y0, clr); // complete tip of ellipse
      putPixel(x0-1, --y1, clr);
    }
  }

  void fillEllipse (int x0, int y0, int x1, int y1, Color clr) @trusted {
    import std.math : abs;
    int a = abs(x1-x0), b = abs(y1-y0), b1 = b&1; // values of diameter
    long dx = 4*(1-a)*b*b, dy = 4*(b1+1)*a*a; // error increment
    long err = dx+dy+b1*a*a; // error of 1.step
    int prev_y0 = -1, prev_y1 = -1;
    if (x0 > x1) { x0 = x1; x1 += a; } // if called with swapped points...
    if (y0 > y1) y0 = y1; // ...exchange them
    y0 += (b+1)/2; y1 = y0-b1; // starting pixel
    a *= 8*a; b1 = 8*b*b;
    do {
      long e2;
      if (y0 != prev_y0) { hline(x0, y0, x1-x0+1, clr); prev_y0 = y0; }
      if (y1 != y0 && y1 != prev_y1) { hline(x0, y1, x1-x0+1, clr); prev_y1 = y1; }
      e2 = 2*err;
      if (e2 >= dx) { ++x0; --x1; err += dx += b1; } // x step
      if (e2 <= dy) { ++y0; --y1; err += dy += a; }  // y step
    } while (x0 <= x1);
    while (y0-y1 < b) {
      // too early stop of flat ellipses a=1
      putPixel(x0-1, ++y0, clr); // complete tip of ellipse
      putPixel(x0-1, --y1, clr);
    }
  }

  /** blit overlay to main screen */
  void blitTpl(string btype) (ref VLOverlay destovl, int xd, int yd, ubyte alpha=0) @trusted {
    static if (btype == "NoSrcAlpha") import core.stdc.string : memcpy;
    if (!valid || !destovl.valid) return;
    if (xd > -mWidth && yd > -mHeight && xd < destovl.mWidth && yd < destovl.mHeight && alpha < 255) {
      int w = mWidth, h = mHeight;
      immutable uint vsPitch = destovl.mWidth;
      immutable uint myPitch = mWidth;
      uint *my = mVScr;
      uint *dest;
      // vertical clipping
      if (yd < 0) {
        // skip invisible top part
        if ((h += yd) < 1) return;
        my -= yd*mWidth;
        yd = 0;
      }
      if (yd+h > destovl.mHeight) {
        // don't draw invisible bottom part
        if ((h = destovl.mHeight-yd) < 1) return;
      }
      // horizontal clipping
      if (xd < 0) {
        // skip invisible left part
        if ((w += xd) < 1) return;
        my -= xd;
        xd = 0;
      }
      if (xd+w > destovl.mWidth) {
        // don't draw invisible right part
        if ((w = destovl.mWidth-xd) < 1) return;
      }
      // copying?
      dest = destovl.mVScr+yd*vsPitch+xd;
      static if (btype == "NoSrcAlpha") {
        if (alpha == 0) {
          while (h-- > 0) {
            import core.stdc.string : memcpy;
            memcpy(dest, my, w*destovl.mVScr[0].sizeof);
            dest += vsPitch;
            my += myPitch;
          }
          return;
        }
      }
      // alpha mixing
      {
        static if (btype == "NoSrcAlpha") immutable uint a = 256-alpha; // to not loose bits
        while (h-- > 0) {
          auto src = cast(immutable(uint)*)my;
          auto dst = dest;
          foreach_reverse (immutable dx; 0..w) {
            immutable uint s = *src++;
            static if (btype == "SrcAlpha") {
              if ((s&vlAMask) == vlcTransparent) { ++dst; continue; }
              immutable uint a = 256-clampToByte(cast(int)(alpha+(s>>vlAShift)&0xff)); // to not loose bits
            }
            immutable uint dc = (*dst)&0xffffff;
            immutable uint srb = (s&0xff00ff);
            immutable uint sg = (s&0x00ff00);
            immutable uint drb = (dc&0xff00ff);
            immutable uint dg = (dc&0x00ff00);
            immutable uint orb = (drb+(((srb-drb)*a+0x800080)>>8))&0xff00ff;
            immutable uint og = (dg+(((sg-dg)*a+0x008000)>>8))&0x00ff00;
            *dst++ = orb|og;
          }
          dest += vsPitch;
          my += myPitch;
        }
      }
    }
  }

  alias blit = blitTpl!"NoSrcAlpha";
  alias blitSrcAlpha = blitTpl!"SrcAlpha";
}
