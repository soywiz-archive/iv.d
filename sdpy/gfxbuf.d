/*
 * Pixel Graphics Library
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
module iv.sdpy.gfxbuf is aliced;

import iv.sdpy.compat;
import iv.sdpy.core;
import iv.sdpy.font6;
import iv.sdpy.color;
import iv.sdpy.region;


// ////////////////////////////////////////////////////////////////////////// //
static assert(VColor.sizeof == uint.sizeof);


// ////////////////////////////////////////////////////////////////////////// //
struct GfxBuf {
private:
  // to avoid importing `std.math`
  static int abs (int n) pure nothrow @safe @nogc { static if (__VERSION__ > 2067) pragma(inline, true); return (n >= 0 ? n : -n); }

  static struct VScr {
  nothrow @trusted @nogc:
    VColor* buf;
    int w, h; // vscreen size
    int rc = -1; // refcount; <0: this is vlVScr
    Region reg; // here, to keep struct size small
    int mClipX0, mClipY0;
    int mClipX1, mClipY1;
    int mXOfs, mYOfs;
    // "real" cliprect, always inside buf
    int mRClipX0, mRClipY0;
    int mRClipX1, mRClipY1;

    //@disable this ();
    @disable this (this);
  }

public:
  alias stringc = const(char)[];

private:
  usize mVScrS = 0; // this is actually `VScr*`

nothrow @trusted @nogc:
  void vscrIncRef () {
    if (mVScrS == 0) return;
    auto vscr = cast(VScr*)mVScrS;
    if (vscr.rc > 0) ++vscr.rc; // !vlVScr buf
  }

  void vscrDecRef () {
    if (mVScrS == 0) return;
    auto vscr = cast(VScr*)mVScrS;
    if (vscr.rc < 0) return; // vlVScr buf
    if (--vscr.rc == 0) {
      import core.stdc.stdlib : free;
      if (vscr.buf !is null) free(vscr.buf);
      vscr.buf = null;
    } else {
      if (vscr.rc < 0) assert(0);
    }
    mVScrS = 0;
  }

  void createVBuf (int wdt, int hgt) {
    //import core.exception : onOutOfMemoryError;
    import core.stdc.stdlib : malloc, realloc, free;
    import core.stdc.string : memcpy;
    if (wdt < 0) wdt = 0;
    if (hgt < 0) hgt = 0;
    if (wdt > 32767 || hgt > 32767) assert(0, "invalid GfxBuf dimensions");
    auto vs = cast(VScr*)malloc(VScr.sizeof);
    if (vs is null) assert(0, "GfxBuf: out of memory");
    static immutable VScr initr = VScr.init;
    memcpy(vs, &initr, VScr.sizeof);
    //(*vs).__ctor();
    vs.buf = cast(VColor*)malloc((wdt && hgt ? wdt*hgt : 1)*VColor.sizeof);
    if (vs.buf is null) { free(vs); assert(0, "GfxBuf: out of memory"); }
    mVScrS = cast(usize)vs;
    vs.w = wdt;
    vs.h = hgt;
    vs.rc = 1;
    resetClipOfs();
    vs.reg.setSize(wdt, hgt);
  }

  @property inout(VScr)* vscr () inout pure {
    static if (__VERSION__ > 2067) pragma(inline, true);
    return cast(VScr*)mVScrS;
  }

  // to create GfxBuf for vlVScr
  this (VScr* vs) { mVScrS = cast(usize)vs; }

  __gshared VScr vsbuf;

  static void fixVSBuf () {
    vsbuf.buf = cast(VColor*)vlVScr;
    if (vsbuf.w != vlWidth || vsbuf.h != vlHeight) {
      vsbuf.w = vlWidth;
      vsbuf.h = vlHeight;
      vsbuf.rc = -1; // special mark
      vsbuf.mClipX0 = vsbuf.mClipY0 = vsbuf.mRClipX0 = vsbuf.mRClipY0 = 0;
      vsbuf.mXOfs = vsbuf.mYOfs = 0;
      vsbuf.mClipX1 = vsbuf.mRClipX1 = vlWidth-1;
      vsbuf.mClipY1 = vsbuf.mRClipY1 = vlHeight-1;
      vsbuf.reg.setSize(vlWidth, vlHeight);
    }
  }

  package static void updateVScr () { fixVSBuf(); }

public:
  this (int wdt, int hgt) { createVBuf(wdt, hgt); }
  ~this () { vscrDecRef(); }
  this (this) { vscrIncRef(); }

  void setSize (int wdt, int hgt) {
    if (mVScrS != 0) {
      if (wdt == vscr.w && hgt == vscr.h) return;
      if (vscr.rc < 0) assert(0, "GfxBuf: double init");
      vscrDecRef();
    }
    createVBuf(wdt, hgt);
  }

  static GfxBuf vlVScrBuf () {
    fixVSBuf();
    return GfxBuf(&vsbuf);
  }

  @property VColor* vbuf () pure { static if (__VERSION__ > 2067) pragma(inline, true); return vscr.buf; }

  @property int width () pure { static if (__VERSION__ > 2067) pragma(inline, true); return vscr.w; }
  @property int height () pure { static if (__VERSION__ > 2067) pragma(inline, true); return vscr.h; }

  VColor* scanline (usize idx) pure { static if (__VERSION__ > 2067) pragma(inline, true); return (idx < height ? vbuf+idx*width : null); }

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
  @gcc_inline void putPixel() (int x, int y, VColor col) {
    static if (__VERSION__ > 2067) pragma(inline, true);
    if (!col.isTransparent && vscr.reg.visible(x, y)) {
      //TODO: overflow check
      auto vs = vscr;
      x += vs.mXOfs;
      y += vs.mYOfs;
      if (x >= vs.mRClipX0 && y >= vs.mRClipY0 && x <= vs.mRClipX1 && y <= vs.mRClipY1) {
        uint* da = cast(uint*)vs.buf+y*vs.w+x;
        mixin(VColor.ColorBlendMixinStr!("col.u32", "*da"));
      }
    }
  }

  /**
   * Draw pixel onto virtual screen; don't mix colors.
   *
   * Params:
   *  x = x coordinate
   *  y = y coordinate
   *  col = rgb color
   *
   * Returns:
   *  nothing
   */
  @gcc_inline void setPixel() (int x, int y, VColor col) {
    static if (__VERSION__ > 2067) pragma(inline, true);
    //TODO: overflow check
    if (vscr.reg.visible(x, y)) {
      auto vs = vscr;
      x += vs.mXOfs;
      y += vs.mYOfs;
      if (x >= vs.mRClipX0 && y >= vs.mRClipY0 && x <= vs.mRClipX1 && y <= vs.mRClipY1) {
        *(vs.buf+y*vs.w+x) = col;
      }
    }
  }

  // //////////////////////////////////////////////////////////////////// //
  // offsets and clips
  bool isEmptyClip () const pure {
    static if (__VERSION__ > 2067) pragma(inline, true);
    auto vs = vscr;
    return (vs.mRClipX0 > vs.mRClipX1 || vs.mRClipY0 > vs.mRClipY1 || vs.reg.empty);
  }

  void resetClipOfs () {
    auto vs = vscr;
    vs.mXOfs = vs.mYOfs = 0;
    vs.mClipX0 = vs.mClipY0 = vs.mRClipX0 = vs.mRClipY0 = 0;
    vs.mClipX1 = vs.mRClipX1 = vs.w-1;
    vs.mClipY1 = vs.mRClipY1 = vs.h-1;
  }

  void resetOfs () { vscr.mXOfs = vscr.mYOfs = 0; }

  void resetClip () {
    auto vs = vscr;
    vs.mClipX0 = vs.mClipY0 = vs.mRClipX0 = vs.mRClipY0 = 0;
    vs.mClipX1 = vs.mRClipX1 = vs.w-1;
    vs.mClipY1 = vs.mRClipY1 = vs.h-1;
  }

  @property int xofs () const pure { static if (__VERSION__ > 2067) pragma(inline, true); return vscr.mXOfs; }
  @property void xofs (int v) { static if (__VERSION__ > 2067) pragma(inline, true); vscr.mXOfs = v; }

  @property int yofs () const pure { static if (__VERSION__ > 2067) pragma(inline, true); return vscr.mYOfs; }
  @property void yofs (int v) { static if (__VERSION__ > 2067) pragma(inline, true); vscr.mYOfs = v; }

  static struct Clip { int x, y, w, h; }

  @property Clip clip () pure {
    Clip res = void;
    auto vs = vscr;
    res.x = vs.mClipX0;
    res.y = vs.mClipY0;
    res.w = vs.mClipX1-vs.mClipX0+1;
    res.h = vs.mClipY1-vs.mClipY0+1;
    if (res.w < 0) res.w = 0;
    if (res.h < 0) res.h = 0;
    return res;
  }

  @property void clip() (in auto ref Clip c) {
    auto vs = vscr;
    vs.mClipX0 = vs.mRClipX0 = c.x;
    vs.mClipY0 = vs.mRClipY0 = c.y;
    vs.mClipX1 = vs.mRClipX1 = c.x+c.w-1;
    vs.mClipY1 = vs.mRClipY1 = c.y+c.h-1;
    if (vs.mRClipX0 < 0) vs.mRClipX0 = 0;
    if (vs.mRClipX1 < 0) vs.mRClipX1 = 0;
    if (vs.mRClipY0 < 0) vs.mRClipY0 = 0;
    if (vs.mRClipY1 < 0) vs.mRClipY1 = 0;
    if (vs.mRClipX0 >= vs.w) vs.mRClipX0 = vs.w-1;
    if (vs.mRClipX1 >= vs.w) vs.mRClipX1 = vs.w-1;
    if (vs.mRClipY0 >= vs.h) vs.mRClipY0 = vs.h-1;
    if (vs.mRClipY1 >= vs.h) vs.mRClipY1 = vs.h-1;
    if (vs.mRClipX1 < 0 || vs.mRClipX0 >= vs.w || vs.mRClipY1 < 0 || vs.mRClipY0 >= vs.h) {
      vs.mRClipX0 = vs.mRClipY0 = 1;
      vs.mRClipX1 = vs.mRClipY1 = 0;
    }
  }

  // //////////////////////////////////////////////////////////////////// //
  // region
  @property ref Region region () { static if (__VERSION__ > 2067) pragma(inline, true); return vscr.reg; }

  // //////////////////////////////////////////////////////////////////////// //
  // various drawing
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
  void drawCharWdt (int x, int y, int wdt, int shift, char ch, VColor col, VColor bkcol=VColor.transparent) {
    usize pos = ch*8;
    if (wdt < 1 || shift >= 8) return;
    if (col.isTransparent && bkcol.isTransparent) return;
    if (isEmptyClip) return;
    if (wdt > 8) wdt = 8;
    if (shift < 0) shift = 0;
    foreach (immutable int dy; 0..8) {
      ubyte b = cast(ubyte)(vlFont6[pos++]<<shift);
      foreach (immutable int dx; 0..wdt) {
        VColor c = (b&0x80 ? col : bkcol);
        if (!c.isTransparent) putPixel(x+dx, y+dy, c);
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
  void drawCharWdtOut (int x, int y, int wdt, int shift, char ch, VColor col, VColor outcol=VColor.transparent, ubyte ot=0) {
    if (col.isTransparent && outcol.isTransparent) return;
    if (ot == 0 || outcol.isTransparent) {
      // no outline? simple draw
      drawCharWdt(x, y, wdt, shift, ch, col, VColor.transparent);
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
  void drawChar (int x, int y, char ch, VColor col, VColor bkcol=VColor.transparent) {
    drawCharWdt(x, y, 6, 0, ch, col, bkcol);
  }

  void drawCharOut (int x, int y, char ch, VColor col, VColor outcol=VColor.transparent, ubyte ot=OutAll) {
    drawCharWdtOut(x, y, 6, 0, ch, col, outcol, ot);
  }

  void drawText (int x, int y, stringc str, VColor col, VColor bkcol=VColor.transparent) {
    if (col.isTransparent && bkcol.isTransparent) return;
    if (isEmptyClip) return;
    foreach (immutable char ch; str) {
      drawChar(x, y, ch, col, bkcol);
      x += 6;
    }
  }

  void drawTextOut (int x, int y, stringc str, VColor col, VColor outcol=VColor.transparent, ubyte ot=OutAll) {
    if (isEmptyClip) return;
    foreach (immutable char ch; str) {
      drawCharOut(x, y, ch, col, outcol, ot);
      x += 6;
    }
  }

  static @property int fontHeight () pure { static if (__VERSION__ > 2067) pragma(inline, true); return 8; }
  static int charWidthProp (char ch) pure { static if (__VERSION__ > 2067) pragma(inline, true); return (vlFontPropWidth[ch]&0x0f); }
  static int textWidth (stringc str) pure { static if (__VERSION__ > 2067) pragma(inline, true); return cast(int)str.length*6; }
  static int textWidthProp (stringc str) {
    int wdt = 0;
    foreach (immutable char ch; str) wdt += (vlFontPropWidth[ch]&0x0f)+1;
    if (wdt > 0) --wdt; // don't count last empty pixel
    return wdt;
  }

  int drawCharProp (int x, int y, char ch, VColor col, VColor bkcol=VColor.transparent) {
    immutable int wdt = (vlFontPropWidth[ch]&0x0f);
    drawCharWdt(x, y, wdt, vlFontPropWidth[ch]>>4, ch, col, bkcol);
    return wdt;
  }

  int drawCharPropOut (int x, int y, char ch, VColor col, VColor outcol=VColor.transparent, ubyte ot=OutAll) {
    immutable int wdt = (vlFontPropWidth[ch]&0x0f);
    drawCharWdtOut(x, y, wdt, vlFontPropWidth[ch]>>4, ch, col, outcol, ot);
    return wdt;
  }

  int drawTextProp (int x, int y, stringc str, VColor col, VColor bkcol=VColor.transparent) {
    bool vline = false;
    int sx = x;
    foreach (immutable char ch; str) {
      if (vline) {
        if (!bkcol.isTransparent) foreach (int dy; 0..8) putPixel(x, y+dy, bkcol);
        ++x;
      }
      vline = true;
      x += drawCharProp(x, y, ch, col, bkcol);
    }
    return x-sx;
  }

  int drawTextPropOut (int x, int y, stringc str, VColor col, VColor outcol=VColor.transparent, ubyte ot=OutAll) {
    int sx = x;
    foreach (immutable char ch; str) x += drawCharPropOut(x, y, ch, col, outcol, ot)+1;
    if (x > sx) --x; // don't count last empty pixel
    return x-sx;
  }

  // ////////////////////////////////////////////////////////////////////////// //
  void clear (VColor col) {
    auto vs = vscr;
    if (vs.w && vs.h && !vs.reg.empty) {
      col.u32 &= ~VColor.AMask;
      if (vs.reg.solid) {
        vs.buf[0..vs.w*vs.h] = col;
      } else {
        VColor* da = vs.buf;
        foreach (immutable y; 0..vs.h) {
          vs.reg.spans!true(y, 0, vs.w-1, (int sx, int ex) @trusted {
            //{ import iv.writer; writeln("y=", y, "; sx=", sx, "; ex=", ex); }
            da[sx..ex+1] = col;
          });
          da += vs.w;
        }
      }
    }
  }

  void hline (int x0, int y0, int len, VColor col) {
    if (len < 1 || col.isTransparent || isEmptyClip) return;
    if (len == 1) { putPixel(x0, y0, col); return; }
    auto vs = vscr;
    x0 += vs.mXOfs;
    y0 += vs.mYOfs;
    int ex = x0+len-1;
    if (y0 < vs.mRClipY0 || y0 > vs.mRClipY1 || ex < vs.mRClipX0 || x0 > vs.mRClipX1) return;
    if (x0 < vs.mRClipX0) x0 = vs.mRClipX0;
    if (x0 > vs.mRClipX1) x0 = vs.mRClipX1;
    if (ex < vs.mRClipX0) ex = vs.mRClipX0;
    if (ex > vs.mRClipX1) ex = vs.mRClipX1;
    if (x0 > ex) return;
    uint adr = y0*vs.w;
    vs.reg.spans!true(y0-vs.mYOfs, vs.mXOfs, x0, ex, (int sx, int ex) @trusted {
      if (col.isOpaque) {
        vs.buf[adr+sx..adr+ex+1] = col;
      } else {
        uint* da = cast(uint*)vs.buf+adr+sx;
        while (sx++ <= ex) {
          mixin(VColor.ColorBlendMixinStr!("col.u32", "*da"));
          ++da;
        }
      }
    });
  }

  void vline (int x0, int y0, int len, VColor col) {
    if (len < 1 || col.isTransparent || isEmptyClip) return;
    while (len-- > 0) putPixel(x0, y0++, col);
  }


  // as the paper on which this code is based in not available to public,
  // so fuck you, and no credits.
  // knowledge must be publicly available; those who hides the knowledge
  // are not deserving any credits.
  void drawLine(bool lastPoint) (int x0, int y0, int x1, int y1, immutable VColor col) {
    enum swap(string a, string b) = "{int tmp_="~a~";"~a~"="~b~";"~b~"=tmp_;}";

    if (col.isTransparent || isEmptyClip) return;

    if (x0 == x1 && y0 == y1) {
      static if (lastPoint) putPixel(x0, y0, col);
      return;
    }

    auto vs = vscr;
    x0 += vs.mXOfs;
    x1 += vs.mXOfs;
    y0 += vs.mYOfs;
    y1 += vs.mYOfs;

    // clip rectange
    int wx0 = vs.mRClipX0, wy0 = vs.mRClipY0, wx1 = vs.mRClipX1, wy1 = vs.mRClipY1;
    if (wx0 > wx1 || wy0 > wy1) return;
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
      if (vs.reg.visible(*d0-vs.mXOfs, *d1-vs.mYOfs)) {
        uint* da = cast(uint*)vs.buf+(*d1)*vs.w+(*d0);
        mixin(VColor.ColorBlendMixinStr!("col.u32", "*da"));
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

  void line (int x0, int y0, int x1, int y1, VColor col) { drawLine!true(x0, y0, x1, y1, col); }
  void lineNoLast (int x0, int y0, int x1, int y1, VColor col) { drawLine!false(x0, y0, x1, y1, col); }

  void fillRect (int x, int y, int w, int h, VColor col) {
    if (col.isTransparent || isEmptyClip || w < 1 || h < 1) return;
    auto vs = vscr;
    x += vs.mXOfs;
    y += vs.mYOfs;
    int ex = x+w-1;
    int ey = y+h-1;
    if (x > vs.mRClipX1 || y > vs.mRClipY1 || ex < vs.mRClipX0 || ey < vs.mRClipY0) return;
    if (y < vs.mRClipY0) y = vs.mRClipY0;
    if (ey > vs.mRClipY1) ey = vs.mRClipY1;
    w = ex-x+1;
    x -= vs.mXOfs;
    foreach (int dy; y-vs.mYOfs..ey-vs.mYOfs+1) hline(x, dy, w, col);
  }

  void rect (int x, int y, int w, int h, VColor col) {
    if (w > 0 && h > 0) {
      if (w == 1) {
        vline(x, y, h, col);
      } else if (h == 1) {
        hline(x, y, w, col);
      } else {
        hline(x, y, w, col);
        hline(x, y+h-1, w, col);
        h -= 2;
        y += 1;
        vline(x, y, h, col);
        vline(x+w-1, y, h, col);
      }
    }
  }

  /* 4 phases */
  void selectionRect (int phase, int x0, int y0, int wdt, int hgt, VColor col0, VColor col1=VColor.transparent) {
    if (wdt > 0 && hgt > 0) {
      // top
      if (wdt > 1) foreach (immutable f; x0..x0+wdt) { putPixel(f, y0, ((phase %= 4) < 2 ? col0 : col1)); ++phase; }
      if (hgt == 1) return;
      // right
      foreach (immutable f; y0+1..y0+hgt) { putPixel(x0+wdt-1, f, ((phase %= 4) < 2 ? col0 : col1)); ++phase; }
      if (wdt == 1) return;
      // bottom
      foreach_reverse (immutable f; x0..x0+wdt-1) { putPixel(f, y0+hgt-1, ((phase %= 4) < 2 ? col0 : col1)); ++phase; }
      // left
      foreach_reverse (immutable f; y0..y0+hgt-1) { putPixel(x0, f, ((phase %= 4) < 2 ? col0 : col1)); ++phase; }
    }
  }

  private void plot4points() (int cx, int cy, int x, int y, VColor col) {
    //static if (__VERSION__ > 2067) pragma(inline, true); // alas, dmd inliner sux again
    putPixel(cx+x, cy+y, col);
    if (x != 0) putPixel(cx-x, cy+y, col);
    if (y != 0) putPixel(cx+x, cy-y, col);
    putPixel(cx-x, cy-y, col);
  }

  void circle (int cx, int cy, int radius, VColor col) {
    if (radius > 0 && !col.isTransparent && !isEmptyClip) {
      int error = -radius, x = radius, y = 0;
      if (radius == 1) { putPixel(cx, cy, col); return; }
      while (x > y) {
        plot4points(cx, cy, x, y, col);
        plot4points(cx, cy, y, x, col);
        error += y*2+1;
        ++y;
        if (error >= 0) { --x; error -= x*2; }
      }
      plot4points(cx, cy, x, y, col);
    }
  }

  void fillCircle (int cx, int cy, int radius, VColor col) {
    if (radius > 0 && !col.isTransparent && !isEmptyClip) {
      int error = -radius, x = radius, y = 0;
      if (radius == 1) { putPixel(cx, cy, col); return; }
      while (x >= y) {
        int last_y = y;
        error += y;
        ++y;
        error += y;
        hline(cx-x, cy+last_y, 2*x+1, col);
        if (x != 0 && last_y != 0) hline(cx-x, cy-last_y, 2*x+1, col);
        if (error >= 0) {
          if (x != last_y) {
            hline(cx-last_y, cy+x, 2*last_y+1, col);
            if (last_y != 0 && x != 0) hline(cx-last_y, cy-x, 2*last_y+1, col);
          }
          error -= x;
          --x;
          error -= x;
        }
      }
    }
  }

  void ellipse (int x0, int y0, int x1, int y1, VColor col) {
    if (col.isTransparent || isEmptyClip) return;
    int a = abs(x1-x0), b = abs(y1-y0), b1 = b&1; // values of diameter
    long dx = 4*(1-a)*b*b, dy = 4*(b1+1)*a*a; // error increment
    long err = dx+dy+b1*a*a; // error of 1.step
    if (x0 > x1) { x0 = x1; x1 += a; } // if called with swapped points...
    if (y0 > y1) y0 = y1; // ...exchange them
    y0 += (b+1)/2; y1 = y0-b1;  // starting pixel
    a *= 8*a; b1 = 8*b*b;
    do {
      long e2;
      putPixel(x1, y0, col); //   I. Quadrant
      putPixel(x0, y0, col); //  II. Quadrant
      putPixel(x0, y1, col); // III. Quadrant
      putPixel(x1, y1, col); //  IV. Quadrant
      e2 = 2*err;
      if (e2 >= dx) { ++x0; --x1; err += dx += b1; } // x step
      if (e2 <= dy) { ++y0; --y1; err += dy += a; }  // y step
    } while (x0 <= x1);
    while (y0-y1 < b) {
      // too early stop of flat ellipses a=1
      putPixel(x0-1, ++y0, col); // complete tip of ellipse
      putPixel(x0-1, --y1, col);
    }
  }

  void fillEllipse (int x0, int y0, int x1, int y1, VColor col) {
    if (col.isTransparent || isEmptyClip) return;
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
      if (y0 != prev_y0) { hline(x0, y0, x1-x0+1, col); prev_y0 = y0; }
      if (y1 != y0 && y1 != prev_y1) { hline(x0, y1, x1-x0+1, col); prev_y1 = y1; }
      e2 = 2*err;
      if (e2 >= dx) { ++x0; --x1; err += dx += b1; } // x step
      if (e2 <= dy) { ++y0; --y1; err += dy += a; }  // y step
    } while (x0 <= x1);
    while (y0-y1 < b) {
      // too early stop of flat ellipses a=1
      putPixel(x0-1, ++y0, col); // complete tip of ellipse
      putPixel(x0-1, --y1, col);
    }
  }

  // blit overlay to buffer, possibly with alpha
  // destbuf should not overlap with vscr.buf
  // `reg` starting at `(sofsx, sofsy)`
  void blitRectTo(string btype="NoSrcAlpha") (
      VColor* destbuf, int destw, int desth,
      int sofsx, int sofsy, int sw, int sh,
      int xd, int yd,
      ubyte alpha,
      in auto ref Region reg)
  {
    static assert(btype == "NoSrcAlpha" || btype == "SrcAlpha");
    auto vs = vscr;
    if (destbuf is null || destw < 1 || desth < 1 || reg.empty || alpha == 255 ||
        sw < 1 || sh < 1 || vs.w < 1 || vs.h < 1 ||
        sofsx >= vs.w || sofsy >= vs.h || sofsx+sw <= 0 || sofsy+sh <= 0 ||
        xd >= destw || yd >= desth)
    {
      return;
    }
    int sx = sofsx, ex = sx+sw-1;
    int sy = sofsy, ey = sy+sh-1;
    // sanitize source rect
    if (sx < 0) { xd += -sx; sx = 0; }
    if (sy < 0) { yd += -sy; sy = 0; }
    if (ex >= vs.w) ex = vs.w-1;
    if (ey >= vs.h) ey = vs.h-1;
    if (sx > ex || sy > ey) return; // completely clipped out
    // clip source rect against dest rect
    if (xd < 0) {
      if ((sx += -xd) > ex) return;
      xd = 0;
    }
    if (xd+(ex-sx+1) > destw) {
      if ((ex = sx+destw-xd-1) < sx) return;
    }
    if (yd < 0) {
      if ((sy += -yd) > ey) return;
      yd = 0;
    }
    if (yd+(ey-sy+1) > desth) {
      if ((ey = sy+desth-yd-1) < sy) return;
    }
    if (sx > ex || sy > ey) return;
    assert(sx >= 0 && ex < vs.w && sx <= ex);
    assert(sy >= 0 && ey < vs.h && sy <= ey);
    // now we can put spans
    uint* sba = cast(uint*)vs.buf+sy*vs.w;
    uint* dba = cast(uint*)destbuf+yd*destw+xd;
    static if (btype == "NoSrcAlpha") {
      if (alpha == 0) {
        // copying
        while (sy <= ey) {
          reg.spans!true(sy-sofsy, sofsx, sx, ex, (int x0, int x1) @trusted {
            import core.stdc.string : memcpy;
            memcpy(dba+x0-sx, sba+x0, (x1-x0+1)*VColor.sizeof);
          });
          sba += vs.w;
          dba += destw;
          ++sy;
        }
        return;
      }
    }
    // alpha mixing
    {
      static if (btype == "NoSrcAlpha") immutable uint a = (alpha<<VColor.AShift);
      while (sy <= ey) {
        vs.reg.spans!true(sy-sofsy, sofsx, sx, ex, (int x0, int x1) @trusted {
          uint* src = sba+x0;
          uint* dst = dba+x0-sx;
          while (x0++ <= x1) {
            uint s = *src++;
            static if (btype == "SrcAlpha") {
              s = s&~VColor.AMask|(clampToByte(alpha+((s>>VColor.AShift)&0xff)));
            } else {
              s = s&~VColor.AMask|a;
            }
            mixin(VColor.ColorBlendMixinStr!("s", "*dst"));
            ++dst;
          }
        });
        sba += vs.w;
        dba += destw;
        ++sy;
      }
    }
  }

  void blitTo(string btype="NoSrcAlpha") (ref GfxBuf dest, int xd, int yd, ubyte alpha, in auto ref Region reg) {
    blitRectTo!btype(dest.vscr.buf, dest.width, dest.height, 0, 0, vscr.w, vscr.h, xd, yd, alpha, reg);
  }
  void blitTo(string btype="NoSrcAlpha") (ref GfxBuf dest, int xd, int yd, ubyte alpha=0) { blitTo!btype(dest, xd, yd, alpha, vscr.reg); }

  void blitToVScr(string btype="NoSrcAlpha") (int xd, int yd, ubyte alpha, in auto ref Region reg) {
    blitRectTo!btype(cast(VColor*)vlVScr, vlWidth, vlHeight, 0, 0, vscr.w, vscr.h, xd, yd, alpha, reg);
  }
  void blitToVScr(string btype="NoSrcAlpha") (int xd, int yd, ubyte alpha=0) { blitToVScr!btype(xd, yd, alpha, vscr.reg); }
}
