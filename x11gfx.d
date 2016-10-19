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
module iv.x11gfx;

import arsd.simpledisplay;


// ////////////////////////////////////////////////////////////////////////// //
// 0:b; 1:g; 2:r; 3: nothing
__gshared int vbufW = 320, vbufH = 240;
__gshared uint[] vbuf;
__gshared bool blit2x = true;
enum BlitType { Normal, BlackWhite, Green }
__gshared int blitType = BlitType.Normal;
__gshared Image vbimg;
__gshared SimpleWindow vbwin;


// ////////////////////////////////////////////////////////////////////////// //
void x11gfxDeinit () {
  flushGui();
  if (vbimg !is null) delete vbimg;
  if (vbwin !is null) { if (!vbwin.closed) vbwin.close(); delete vbwin; }
  if (vbuf !is null) delete vbuf;
  vbimg = null;
  vbwin = null;
  vbuf = null;
  flushGui();
}


SimpleWindow x11gfxInit (string title) {
  if (vbufW < 1 || vbufH < 1 || vbufW > 4096 || vbufH > 4096) assert(0, "invalid dimensions");
  vbuf.length = vbufW*vbufH;
  vbuf[] = 0;
  vbwin = new SimpleWindow(vbufW*(blit2x ? 2 : 1), vbufH*(blit2x ? 2 : 1), title, OpenGlOptions.no, Resizablity.fixedSize);
  vbimg = new Image(vbufW*(blit2x ? 2 : 1), vbufH*(blit2x ? 2 : 1));
  return vbwin;
}


void x11gfxBlit () {
  if (vbwin is null || vbwin.closed) return;
  auto painter = vbwin.draw();
  painter.drawImage(Point(0, 0), vbimg);
}


// ////////////////////////////////////////////////////////////////////////// //
final class X11Image {
  int width, height;
  VColor[] data;

  this (int w, int h) {
    assert(w > 0 && w <= 4096);
    assert(h > 0 && h <= 4096);
    width = w;
    height = h;
    data.length = w*h;
    data[] = Transparent;
  }

  VColor getPixel (int x, int y) const {
    return (x >= 0 && y >= 0 && x < width && y < height ? data[y*width+x] : Transparent);
  }

  void setPixel (int x, int y, VColor c) {
    if (x >= 0 && y >= 0 && x < width && y < height) data[y*width+x] = c;
  }

  void blitFast (int x, int y) const {
    if (width < 1 || height < 1) return;
    if (x <= -width || y <= -height) return;
    if (x >= vbufW || y >= vbufH) return;
    auto src = cast(const(VColor)*)data.ptr;
    if (x >= 0 && y >= 0 && x+width < vbufW && y+height < vbufH) {
      auto d = cast(uint*)vbuf.ptr;
      d += vbufW*y+x;
      foreach (int dy; 0..height) {
        d[0..width] = src[0..width];
        src += width;
        d += vbufW;
      }
    } else {
      foreach (int dy; 0..height) {
        foreach (int dx; 0..width) {
          .setPixel(x+dx, y+dy, *src++);
        }
      }
    }
  }

  void blit (int x, int y) const {
    if (width < 1 || height < 1) return;
    if (x <= -width || y <= -height) return;
    if (x >= vbufW || y >= vbufH) return;
    auto src = cast(const(VColor)*)data.ptr;
    foreach (int dy; 0..height) {
      foreach (int dx; 0..width) {
        putPixel(x+dx, y+dy, *src++);
      }
    }
  }

  void blit2x (int x, int y) const {
    if (width < 1 || height < 1) return;
    if (x <= -width || y <= -height) return;
    if (x >= vbufW || y >= vbufH) return;
    auto src = cast(const(VColor)*)data.ptr;
    foreach (immutable int dy; 0..height) {
      foreach (immutable int dx; 0..width) {
        putPixel(x+dx*2+0, y+dy*2+0, *src);
        putPixel(x+dx*2+1, y+dy*2+0, *src);
        putPixel(x+dx*2+0, y+dy*2+1, *src);
        putPixel(x+dx*2+1, y+dy*2+1, *src);
        ++src;
      }
    }
  }

  private void blit2xImpl(string op) (int x, int y) nothrow @trusted @nogc {
    if (width < 1 || height < 1) return;
    if (x <= -width || y <= -height) return;
    if (x >= vbufW || y >= vbufH) return;
    auto s = cast(const(ubyte)*)data.ptr;
    //auto d = cast(uint*)vscr2x;
    foreach (immutable int dy; 0..height) {
      foreach (immutable int dx; 0..width) {
        static if (op.length) mixin(op);
        immutable uint c1 = ((((c0&0x00ff00ff)*6)>>3)&0x00ff00ff)|(((c0&0x0000ff00)*6)>>3)&0x0000ff00;
        putPixel(x+dx*2+0, y+dy*2+0, c0);
        putPixel(x+dx*2+1, y+dy*2+0, c0);
        putPixel(x+dx*2+0, y+dy*2+1, c1);
        putPixel(x+dx*2+1, y+dy*2+1, c1);
        s += 4;
      }
    }
  }

  alias blit2xTV = blit2xImpl!"immutable uint c0 = (cast(immutable(uint)*)s)[0];";
  alias blit2xTVBW = blit2xImpl!"immutable ubyte i = cast(ubyte)((s[0]*28+s[1]*151+s[2]*77)/256); immutable uint c0 = (i<<16)|(i<<8)|i;";
  alias blit2xTVGreen = blit2xImpl!"immutable ubyte i = cast(ubyte)((s[0]*28+s[1]*151+s[2]*77)/256); immutable uint c0 = i<<8;";
}


// ////////////////////////////////////////////////////////////////////////// //
private {
  void blit2xImpl(string op, bool scanlines=true) (Image img) {
    static if (UsingSimpledisplayX11) {
      auto s = cast(const(ubyte)*)vbuf.ptr;
      immutable iw = img.width;
      auto dd = cast(uint*)img.getDataPointer;
      foreach (immutable int dy; 0..vbufH) {
        if (dy*2+1 >= img.height) return;
        auto d = dd+iw*(dy*2);
        foreach (immutable int dx; 0..vbufW) {
          if (dx+1 < iw) {
            static if (op.length) mixin(op);
            static if (scanlines) {
              immutable uint c1 = ((((c0&0x00ff00ff)*6)>>3)&0x00ff00ff)|(((c0&0x0000ff00)*6)>>3)&0x0000ff00;
            } else {
              alias c1 = c0;
            }
            d[0] = d[1] = c0;
            d[iw+0] = d[iw+1] = c1;
            d += 2;
            s += 4;
          }
        }
      }
    } else {
      // this sux
      immutable bpp = img.bytesPerPixel();
      immutable rofs = img.redByteOffset;
      immutable gofs = img.greenByteOffset;
      immutable bofs = img.blueByteOffset;
      immutable nlo = img.adjustmentForNextLine;
      auto s = cast(const(ubyte)*)vbuf.ptr;
      immutable iw = img.width;
      auto dd = cast(ubyte*)img.getDataPointer;
      foreach (immutable int dy; 0..vbufH) {
        if (dy*2+1 >= img.height) return;
        auto d = dd+img.offsetForPixel(0, dy*2);
        foreach (immutable int dx; 0..vbufW) {
          if (dx+1 < iw) {
            static if (op.length) mixin(op);
            static if (scanlines) {
              immutable uint c1 = ((((c0&0x00ff00ff)*6)>>3)&0x00ff00ff)|(((c0&0x0000ff00)*6)>>3)&0x0000ff00;
            } else {
              alias c1 = c0;
            }
            d[bofs] = d[bofs+bpp] = c0&0xff;
            d[gofs] = d[gofs+bpp] = (c0>>8)&0xff;
            d[rofs] = d[rofs+bpp] = (c0>>16)&0xff;
            d[bofs+nlo] = d[bofs+nlo+bpp] = c0&0xff;
            d[gofs+nlo] = d[gofs+nlo+bpp] = (c0>>8)&0xff;
            d[rofs+nlo] = d[rofs+nlo+bpp] = (c0>>16)&0xff;
            d += bpp*2;
            s += 4;
          }
        }
      }
    }
  }

  alias blit2xTV = blit2xImpl!"immutable uint c0 = (cast(immutable(uint)*)s)[0];";
  alias blit2xTVBW = blit2xImpl!"immutable ubyte i = cast(ubyte)((s[0]*28+s[1]*151+s[2]*77)/256); immutable uint c0 = (i<<16)|(i<<8)|i;";
  alias blit2xTVGreen = blit2xImpl!"immutable ubyte i = cast(ubyte)((s[0]*28+s[1]*151+s[2]*77)/256); immutable uint c0 = i<<8;";
}


// ////////////////////////////////////////////////////////////////////////// //
void realizeVBuf (/*Image img*/) {
  if (vbimg is null) return;
  Image img = vbimg;
  /*
  auto sp = vbuf.ptr;
  auto dp = cast(uint*)img.getDataPointer;
  import core.stdc.string : memcpy;
  memcpy(dp, sp, vbufW*vbufH*4);
  */
  if (blit2x) {
    if (img.width < vbufW*2 || img.height < vbufH*2) return;
    switch (blitType) {
      case BlitType.BlackWhite: blit2xTVBW(img); break;
      case BlitType.Green: blit2xTVGreen(img); break;
      default: blit2xTV(img); break;
    }
  } else {
    if (img.width < vbufW || img.height < vbufH) return;
    static if (UsingSimpledisplayX11) {
      auto dp = cast(uint*)img.getDataPointer;
      dp[0..vbufW*vbufH] = vbuf.ptr[0..vbufW*vbufH];
    } else {
      // this sux
      auto sp = cast(ubyte*)vbuf.ptr;
      auto dp = cast(ubyte*)img.getDataPointer;
      immutable bpp = img.bytesPerPixel();
      immutable rofs = img.redByteOffset;
      immutable gofs = img.greenByteOffset;
      immutable bofs = img.blueByteOffset;
      foreach (immutable y; 0..vbufH) {
        auto d = dp+img.offsetForTopLeftPixel;
        foreach (immutable x; 0..vbufW) {
          d[bofs] = *sp++;
          d[gofs] = *sp++;
          d[rofs] = *sp++;
          ++sp;
          d += bpp;
        }
      }
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
ubyte clampToByte(T) (T n) @safe pure nothrow @nogc
if (__traits(isIntegral, T) && (T.sizeof == 2 || T.sizeof == 4))
{
  static if (__VERSION__ > 2067) pragma(inline, true);
  n &= -cast(int)(n >= 0);
  return cast(ubyte)(n|((255-cast(int)n)>>31));
}

ubyte clampToByte(T) (T n) @safe pure nothrow @nogc
if (__traits(isIntegral, T) && T.sizeof == 1)
{
  static if (__VERSION__ > 2067) pragma(inline, true);
  return cast(ubyte)n;
}


// ////////////////////////////////////////////////////////////////////////// //
alias VColor = uint;

/// vlRGBA struct to ease color components extraction/replacing
align(1) struct vlRGBA {
align(1):
  ubyte b, g, r, a;
}
static assert(vlRGBA.sizeof == VColor.sizeof);


enum : VColor {
  vlAMask = 0xff000000u,
  vlRMask = 0x00ff0000u,
  vlGMask = 0x0000ff00u,
  vlBMask = 0x000000ffu
}

enum : VColor {
  vlAShift = 24,
  vlRShift = 16,
  vlGShift = 8,
  vlBShift = 0
}


enum VColor Transparent = vlAMask; /// completely transparent pixel color


bool isTransparent(T : VColor) (T col) @safe pure nothrow @nogc {
  static if (__VERSION__ > 2067) pragma(inline, true);
  return ((col&vlAMask) == vlAMask);
}

bool isOpaque(T : VColor) (T col) @safe pure nothrow @nogc {
  static if (__VERSION__ > 2067) pragma(inline, true);
  return ((col&vlAMask) == 0);
}

// a=0: opaque
VColor rgbcol(TR, TG, TB, TA=ubyte) (TR r, TG g, TB b, TA a=0) @safe pure nothrow @nogc
if (__traits(isIntegral, TR) && __traits(isIntegral, TG) && __traits(isIntegral, TB) && __traits(isIntegral, TA)) {
  static if (__VERSION__ > 2067) pragma(inline, true);
  return
    (clampToByte(a)<<vlAShift)|
    (clampToByte(r)<<vlRShift)|
    (clampToByte(g)<<vlGShift)|
    (clampToByte(b)<<vlBShift);
}

alias rgbacol = rgbcol;


// generate some templates
private enum genRGBGetSet(string cname) =
  "ubyte rgb"~cname~"() (VColor clr) @safe pure nothrow @nogc {\n"~
  "  static if (__VERSION__ > 2067) pragma(inline, true);\n"~
  "  return ((clr>>vl"~cname[0]~"Shift)&0xff);\n"~
  "}\n"~
  "VColor rgbSet"~cname~"(T) (VColor clr, T v) @safe pure nothrow @nogc if (__traits(isIntegral, T)) {\n"~
  "  static if (__VERSION__ > 2067) pragma(inline, true);\n"~
  "  return (clr&~vl"~cname[0]~"Mask)|(clampToByte(v)<<vl"~cname[0]~"Shift);\n"~
  "}\n";

mixin(genRGBGetSet!"Alpha");
mixin(genRGBGetSet!"Red");
mixin(genRGBGetSet!"Green");
mixin(genRGBGetSet!"Blue");


// ////////////////////////////////////////////////////////////////////////// //
void putPixel(TX, TY) (TX x, TY y, VColor col) @trusted
if (__traits(isIntegral, TX) && __traits(isIntegral, TY))
{
  static if (__VERSION__ > 2067) pragma(inline, true);
  immutable long xx = cast(long)x;
  immutable long yy = cast(long)y;
  if ((col&vlAMask) != vlAMask && xx >= 0 && yy >= 0 && xx < vbufW && yy < vbufH) {
    uint* da = vbuf.ptr+yy*vbufW+xx;
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


void setPixel(TX, TY) (TX x, TY y, VColor col) @trusted
if (__traits(isIntegral, TX) && __traits(isIntegral, TY))
{
  static if (__VERSION__ > 2067) pragma(inline, true);
  immutable long xx = cast(long)x;
  immutable long yy = cast(long)y;
  if (xx >= 0 && yy >= 0 && xx < vbufW && yy < vbufH) {
    uint* da = vbuf.ptr+yy*vbufW+xx;
    *da = col;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
void drawLine(bool lastPoint=true) (int x0, int y0, int x1, int y1, immutable VColor col) {
  enum swap(string a, string b) = "{int tmp_="~a~";"~a~"="~b~";"~b~"=tmp_;}";

  if ((col&vlAMask) == vlAMask) return;

  if (x0 == x1 && y0 == y1) {
    static if (lastPoint) putPixel(x0, y0, col);
    return;
  }

  // clip rectange
  int wx0 = 0, wy0 = 0, wx1 = vbufW-1, wy1 = vbufH-1;
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
    uint* da = vbuf.ptr+(*d1)*vbufW+(*d0);
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


// //////////////////////////////////////////////////////////////////////// //
/*
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
void drawCharWdt (int x, int y, int wdt, int shift, char ch, VColor col, VColor bkcol=Transparent) @trusted {
  size_t pos = ch*8;
  if (wdt < 1 || shift >= 8) return;
  if (col == Transparent && bkcol == Transparent) return;
  if (wdt > 8) wdt = 8;
  if (shift < 0) shift = 0;
  foreach (immutable int dy; 0..8) {
    ubyte b = cast(ubyte)(vlFont6[pos++]<<shift);
    foreach (immutable int dx; 0..wdt) {
      VColor c = (b&0x80 ? col : bkcol);
      if (!isTransparent(c)) putPixel(x+dx, y+dy, c);
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

/*
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
void drawCharWdtOut (int x, int y, int wdt, int shift, char ch, VColor col, VColor outcol=Transparent, ubyte ot=0) @trusted {
  if (col == Transparent && outcol == Transparent) return;
  if (ot == 0 || outcol == Transparent) {
    // no outline? simple draw
    drawCharWdt(x, y, wdt, shift, ch, col, Transparent);
    return;
  }
  size_t pos = ch*8;
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

/*
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
void drawChar (int x, int y, char ch, VColor col, VColor bkcol=Transparent) @trusted {
  drawCharWdt(x, y, 6, 0, ch, col, bkcol);
}

void drawCharOut (int x, int y, char ch, VColor col, VColor outcol=Transparent, ubyte ot=OutAll) @trusted {
  drawCharWdtOut(x, y, 6, 0, ch, col, outcol, ot);
}

void drawStr (int x, int y, string str, VColor col, VColor bkcol=Transparent) @trusted {
  foreach (immutable char ch; str) {
    drawChar(x, y, ch, col, bkcol);
    x += 6;
  }
}

void drawStrOut (int x, int y, string str, VColor col, VColor outcol=Transparent, ubyte ot=OutAll) @trusted {
  foreach (immutable char ch; str) {
    drawCharOut(x, y, ch, col, outcol, ot);
    x += 6;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
static int charWidthProp (char ch) @trusted pure { return (vlFontPropWidth[ch]&0x0f); }

int strWidthProp (string str) @trusted pure {
  int wdt = 0;
  foreach (immutable char ch; str) wdt += (vlFontPropWidth[ch]&0x0f)+1;
  if (wdt > 0) --wdt; // don't count last empty pixel
  return wdt;
}

int drawCharProp (int x, int y, char ch, VColor col, VColor bkcol=Transparent) @trusted {
  immutable int wdt = (vlFontPropWidth[ch]&0x0f);
  drawCharWdt(x, y, wdt, vlFontPropWidth[ch]>>4, ch, col, bkcol);
  return wdt;
}

int drawCharPropOut (int x, int y, char ch, VColor col, VColor outcol=Transparent, ubyte ot=OutAll) @trusted {
  immutable int wdt = (vlFontPropWidth[ch]&0x0f);
  drawCharWdtOut(x, y, wdt, vlFontPropWidth[ch]>>4, ch, col, outcol, ot);
  return wdt;
}

int drawStrProp (int x, int y, string str, VColor col, VColor bkcol=Transparent) @trusted {
  bool vline = false;
  int sx = x;
  foreach (immutable char ch; str) {
    if (vline) {
      if (!isTransparent(bkcol)) foreach (int dy; 0..8) putPixel(x, y+dy, bkcol);
      ++x;
    }
    vline = true;
    x += drawCharProp(x, y, ch, col, bkcol);
  }
  return x-sx;
}

int drawStrPropOut (int x, int y, string str, VColor col, VColor outcol=Transparent, ubyte ot=OutAll) @trusted {
  int sx = x;
  foreach (immutable char ch; str) {
    x += drawCharPropOut(x, y, ch, col, outcol, ot)+1;
  }
  if (x > sx) --x; // don't count last empty pixel
  return x-sx;
}


// ////////////////////////////////////////////////////////////////////////// //
void cls (VColor col) @trusted {
  vbuf.ptr[0..vbufW*vbufH] = col;
}


// ////////////////////////////////////////////////////////////////////////// //
public immutable ubyte[256*8] vlFont6 = [
/* 0 */
0b_00000000,
0b_00000000,
0b_00000000,
0b_00000000,
0b_00000000,
0b_00000000,
0b_00000000,
0b_00000000,
/* 1 */
0b_00111100,
0b_01000010,
0b_10100101,
0b_10000001,
0b_10100101,
0b_10011001,
0b_01000010,
0b_00111100,
/* 2 */
0b_00111100,
0b_01111110,
0b_11011011,
0b_11111111,
0b_11111111,
0b_11011011,
0b_01100110,
0b_00111100,
/* 3 */
0b_01101100,
0b_11111110,
0b_11111110,
0b_11111110,
0b_01111100,
0b_00111000,
0b_00010000,
0b_00000000,
/* 4 */
0b_00010000,
0b_00111000,
0b_01111100,
0b_11111110,
0b_01111100,
0b_00111000,
0b_00010000,
0b_00000000,
/* 5 */
0b_00010000,
0b_00111000,
0b_01010100,
0b_11111110,
0b_01010100,
0b_00010000,
0b_00111000,
0b_00000000,
/* 6 */
0b_00010000,
0b_00111000,
0b_01111100,
0b_11111110,
0b_11111110,
0b_00010000,
0b_00111000,
0b_00000000,
/* 7 */
0b_00000000,
0b_00000000,
0b_00000000,
0b_00110000,
0b_00110000,
0b_00000000,
0b_00000000,
0b_00000000,
/* 8 */
0b_11111111,
0b_11111111,
0b_11111111,
0b_11100111,
0b_11100111,
0b_11111111,
0b_11111111,
0b_11111111,
/* 9 */
0b_00111000,
0b_01000100,
0b_10000010,
0b_10000010,
0b_10000010,
0b_01000100,
0b_00111000,
0b_00000000,
/* 10 */
0b_11000111,
0b_10111011,
0b_01111101,
0b_01111101,
0b_01111101,
0b_10111011,
0b_11000111,
0b_11111111,
/* 11 */
0b_00001111,
0b_00000011,
0b_00000101,
0b_01111001,
0b_10001000,
0b_10001000,
0b_10001000,
0b_01110000,
/* 12 */
0b_00111000,
0b_01000100,
0b_01000100,
0b_01000100,
0b_00111000,
0b_00010000,
0b_01111100,
0b_00010000,
/* 13 */
0b_00110000,
0b_00101000,
0b_00100100,
0b_00100100,
0b_00101000,
0b_00100000,
0b_11100000,
0b_11000000,
/* 14 */
0b_00111100,
0b_00100100,
0b_00111100,
0b_00100100,
0b_00100100,
0b_11100100,
0b_11011100,
0b_00011000,
/* 15 */
0b_00010000,
0b_01010100,
0b_00111000,
0b_11101110,
0b_00111000,
0b_01010100,
0b_00010000,
0b_00000000,
/* 16 */
0b_00010000,
0b_00010000,
0b_00010000,
0b_01111100,
0b_00010000,
0b_00010000,
0b_00010000,
0b_00010000,
/* 17 */
0b_00010000,
0b_00010000,
0b_00010000,
0b_11111111,
0b_00000000,
0b_00000000,
0b_00000000,
0b_00000000,
/* 18 */
0b_00000000,
0b_00000000,
0b_00000000,
0b_11111111,
0b_00010000,
0b_00010000,
0b_00010000,
0b_00010000,
/* 19 */
0b_00010000,
0b_00010000,
0b_00010000,
0b_11110000,
0b_00010000,
0b_00010000,
0b_00010000,
0b_00010000,
/* 20 */
0b_00010000,
0b_00010000,
0b_00010000,
0b_00011111,
0b_00010000,
0b_00010000,
0b_00010000,
0b_00010000,
/* 21 */
0b_00010000,
0b_00010000,
0b_00010000,
0b_11111111,
0b_00010000,
0b_00010000,
0b_00010000,
0b_00010000,
/* 22 */
0b_00010000,
0b_00010000,
0b_00010000,
0b_00010000,
0b_00010000,
0b_00010000,
0b_00010000,
0b_00010000,
/* 23 */
0b_00000000,
0b_00000000,
0b_00000000,
0b_11111111,
0b_00000000,
0b_00000000,
0b_00000000,
0b_00000000,
/* 24 */
0b_00000000,
0b_00000000,
0b_00000000,
0b_00011111,
0b_00010000,
0b_00010000,
0b_00010000,
0b_00010000,
/* 25 */
0b_00000000,
0b_00000000,
0b_00000000,
0b_11110000,
0b_00010000,
0b_00010000,
0b_00010000,
0b_00010000,
/* 26 */
0b_00010000,
0b_00010000,
0b_00010000,
0b_00011111,
0b_00000000,
0b_00000000,
0b_00000000,
0b_00000000,
/* 27 */
0b_00010000,
0b_00010000,
0b_00010000,
0b_11110000,
0b_00000000,
0b_00000000,
0b_00000000,
0b_00000000,
/* 28 */
0b_10000001,
0b_01000010,
0b_00100100,
0b_00011000,
0b_00011000,
0b_00100100,
0b_01000010,
0b_10000001,
/* 29 */
0b_00000001,
0b_00000010,
0b_00000100,
0b_00001000,
0b_00010000,
0b_00100000,
0b_01000000,
0b_10000000,
/* 30 */
0b_10000000,
0b_01000000,
0b_00100000,
0b_00010000,
0b_00001000,
0b_00000100,
0b_00000010,
0b_00000001,
/* 31 */
0b_00000000,
0b_00010000,
0b_00010000,
0b_11111111,
0b_00010000,
0b_00010000,
0b_00000000,
0b_00000000,
/* 32 ' ' */
0b_00000000,
0b_00000000,
0b_00000000,
0b_00000000,
0b_00000000,
0b_00000000,
0b_00000000,
0b_00000000,
/* 33 '!' */
0b_00100000,
0b_00100000,
0b_00100000,
0b_00100000,
0b_00000000,
0b_00000000,
0b_00100000,
0b_00000000,
/* 34 '"' */
0b_01010000,
0b_01010000,
0b_01010000,
0b_00000000,
0b_00000000,
0b_00000000,
0b_00000000,
0b_00000000,
/* 35 '#' */
0b_01010000,
0b_01010000,
0b_11111000,
0b_01010000,
0b_11111000,
0b_01010000,
0b_01010000,
0b_00000000,
/* 36 '$' */
0b_00100000,
0b_01111000,
0b_10100000,
0b_01110000,
0b_00101000,
0b_11110000,
0b_00100000,
0b_00000000,
/* 37 '%' */
0b_11000000,
0b_11001000,
0b_00010000,
0b_00100000,
0b_01000000,
0b_10011000,
0b_00011000,
0b_00000000,
/* 38 '&' */
0b_01000000,
0b_10100000,
0b_01000000,
0b_10101000,
0b_10010000,
0b_10011000,
0b_01100000,
0b_00000000,
/* 39 ''' */
0b_00010000,
0b_00100000,
0b_01000000,
0b_00000000,
0b_00000000,
0b_00000000,
0b_00000000,
0b_00000000,
/* 40 '(' */
0b_00010000,
0b_00100000,
0b_01000000,
0b_01000000,
0b_01000000,
0b_00100000,
0b_00010000,
0b_00000000,
/* 41 ')' */
0b_01000000,
0b_00100000,
0b_00010000,
0b_00010000,
0b_00010000,
0b_00100000,
0b_01000000,
0b_00000000,
/* 42 '*' */
0b_10001000,
0b_01010000,
0b_00100000,
0b_11111000,
0b_00100000,
0b_01010000,
0b_10001000,
0b_00000000,
/* 43 '+' */
0b_00000000,
0b_00100000,
0b_00100000,
0b_11111000,
0b_00100000,
0b_00100000,
0b_00000000,
0b_00000000,
/* 44 ',' */
0b_00000000,
0b_00000000,
0b_00000000,
0b_00000000,
0b_00000000,
0b_00100000,
0b_00100000,
0b_01000000,
/* 45 '-' */
0b_00000000,
0b_00000000,
0b_00000000,
0b_01111000,
0b_00000000,
0b_00000000,
0b_00000000,
0b_00000000,
/* 46 '.' */
0b_00000000,
0b_00000000,
0b_00000000,
0b_00000000,
0b_00000000,
0b_01100000,
0b_01100000,
0b_00000000,
/* 47 '/' */
0b_00000000,
0b_00000000,
0b_00001000,
0b_00010000,
0b_00100000,
0b_01000000,
0b_10000000,
0b_00000000,
/* 48 '0' */
0b_01110000,
0b_10001000,
0b_10011000,
0b_10101000,
0b_11001000,
0b_10001000,
0b_01110000,
0b_00000000,
/* 49 '1' */
0b_00100000,
0b_01100000,
0b_10100000,
0b_00100000,
0b_00100000,
0b_00100000,
0b_11111000,
0b_00000000,
/* 50 '2' */
0b_01110000,
0b_10001000,
0b_00001000,
0b_00010000,
0b_01100000,
0b_10000000,
0b_11111000,
0b_00000000,
/* 51 '3' */
0b_01110000,
0b_10001000,
0b_00001000,
0b_00110000,
0b_00001000,
0b_10001000,
0b_01110000,
0b_00000000,
/* 52 '4' */
0b_00010000,
0b_00110000,
0b_01010000,
0b_10010000,
0b_11111000,
0b_00010000,
0b_00010000,
0b_00000000,
/* 53 '5' */
0b_11111000,
0b_10000000,
0b_11100000,
0b_00010000,
0b_00001000,
0b_00010000,
0b_11100000,
0b_00000000,
/* 54 '6' */
0b_00110000,
0b_01000000,
0b_10000000,
0b_11110000,
0b_10001000,
0b_10001000,
0b_01110000,
0b_00000000,
/* 55 '7' */
0b_11111000,
0b_10001000,
0b_00010000,
0b_00100000,
0b_00100000,
0b_00100000,
0b_00100000,
0b_00000000,
/* 56 '8' */
0b_01110000,
0b_10001000,
0b_10001000,
0b_01110000,
0b_10001000,
0b_10001000,
0b_01110000,
0b_00000000,
/* 57 '9' */
0b_01110000,
0b_10001000,
0b_10001000,
0b_01111000,
0b_00001000,
0b_00010000,
0b_01100000,
0b_00000000,
/* 58 ':' */
0b_00000000,
0b_00000000,
0b_00100000,
0b_00000000,
0b_00000000,
0b_00100000,
0b_00000000,
0b_00000000,
/* 59 ';' */
0b_00000000,
0b_00000000,
0b_00100000,
0b_00000000,
0b_00000000,
0b_00100000,
0b_00100000,
0b_01000000,
/* 60 '<' */
0b_00011000,
0b_00110000,
0b_01100000,
0b_11000000,
0b_01100000,
0b_00110000,
0b_00011000,
0b_00000000,
/* 61 '=' */
0b_00000000,
0b_00000000,
0b_11111000,
0b_00000000,
0b_11111000,
0b_00000000,
0b_00000000,
0b_00000000,
/* 62 '>' */
0b_11000000,
0b_01100000,
0b_00110000,
0b_00011000,
0b_00110000,
0b_01100000,
0b_11000000,
0b_00000000,
/* 63 '?' */
0b_01110000,
0b_10001000,
0b_00001000,
0b_00010000,
0b_00100000,
0b_00000000,
0b_00100000,
0b_00000000,
/* 64 '@' */
0b_01110000,
0b_10001000,
0b_00001000,
0b_01101000,
0b_10101000,
0b_10101000,
0b_01110000,
0b_00000000,
/* 65 'A' */
0b_00100000,
0b_01010000,
0b_10001000,
0b_10001000,
0b_11111000,
0b_10001000,
0b_10001000,
0b_00000000,
/* 66 'B' */
0b_11110000,
0b_01001000,
0b_01001000,
0b_01110000,
0b_01001000,
0b_01001000,
0b_11110000,
0b_00000000,
/* 67 'C' */
0b_00110000,
0b_01001000,
0b_10000000,
0b_10000000,
0b_10000000,
0b_01001000,
0b_00110000,
0b_00000000,
/* 68 'D' */
0b_11100000,
0b_01010000,
0b_01001000,
0b_01001000,
0b_01001000,
0b_01010000,
0b_11100000,
0b_00000000,
/* 69 'E' */
0b_11111000,
0b_10000000,
0b_10000000,
0b_11110000,
0b_10000000,
0b_10000000,
0b_11111000,
0b_00000000,
/* 70 'F' */
0b_11111000,
0b_10000000,
0b_10000000,
0b_11110000,
0b_10000000,
0b_10000000,
0b_10000000,
0b_00000000,
/* 71 'G' */
0b_01110000,
0b_10001000,
0b_10000000,
0b_10111000,
0b_10001000,
0b_10001000,
0b_01110000,
0b_00000000,
/* 72 'H' */
0b_10001000,
0b_10001000,
0b_10001000,
0b_11111000,
0b_10001000,
0b_10001000,
0b_10001000,
0b_00000000,
/* 73 'I' */
0b_01110000,
0b_00100000,
0b_00100000,
0b_00100000,
0b_00100000,
0b_00100000,
0b_01110000,
0b_00000000,
/* 74 'J' */
0b_00111000,
0b_00010000,
0b_00010000,
0b_00010000,
0b_10010000,
0b_10010000,
0b_01100000,
0b_00000000,
/* 75 'K' */
0b_10001000,
0b_10010000,
0b_10100000,
0b_11000000,
0b_10100000,
0b_10010000,
0b_10001000,
0b_00000000,
/* 76 'L' */
0b_10000000,
0b_10000000,
0b_10000000,
0b_10000000,
0b_10000000,
0b_10000000,
0b_11111000,
0b_00000000,
/* 77 'M' */
0b_10001000,
0b_11011000,
0b_10101000,
0b_10101000,
0b_10001000,
0b_10001000,
0b_10001000,
0b_00000000,
/* 78 'N' */
0b_10001000,
0b_11001000,
0b_11001000,
0b_10101000,
0b_10011000,
0b_10011000,
0b_10001000,
0b_00000000,
/* 79 'O' */
0b_01110000,
0b_10001000,
0b_10001000,
0b_10001000,
0b_10001000,
0b_10001000,
0b_01110000,
0b_00000000,
/* 80 'P' */
0b_11110000,
0b_10001000,
0b_10001000,
0b_11110000,
0b_10000000,
0b_10000000,
0b_10000000,
0b_00000000,
/* 81 'Q' */
0b_01110000,
0b_10001000,
0b_10001000,
0b_10001000,
0b_10101000,
0b_10010000,
0b_01101000,
0b_00000000,
/* 82 'R' */
0b_11110000,
0b_10001000,
0b_10001000,
0b_11110000,
0b_10100000,
0b_10010000,
0b_10001000,
0b_00000000,
/* 83 'S' */
0b_01110000,
0b_10001000,
0b_10000000,
0b_01110000,
0b_00001000,
0b_10001000,
0b_01110000,
0b_00000000,
/* 84 'T' */
0b_11111000,
0b_00100000,
0b_00100000,
0b_00100000,
0b_00100000,
0b_00100000,
0b_00100000,
0b_00000000,
/* 85 'U' */
0b_10001000,
0b_10001000,
0b_10001000,
0b_10001000,
0b_10001000,
0b_10001000,
0b_01110000,
0b_00000000,
/* 86 'V' */
0b_10001000,
0b_10001000,
0b_10001000,
0b_10001000,
0b_01010000,
0b_01010000,
0b_00100000,
0b_00000000,
/* 87 'W' */
0b_10001000,
0b_10001000,
0b_10001000,
0b_10101000,
0b_10101000,
0b_11011000,
0b_10001000,
0b_00000000,
/* 88 'X' */
0b_10001000,
0b_10001000,
0b_01010000,
0b_00100000,
0b_01010000,
0b_10001000,
0b_10001000,
0b_00000000,
/* 89 'Y' */
0b_10001000,
0b_10001000,
0b_10001000,
0b_01110000,
0b_00100000,
0b_00100000,
0b_00100000,
0b_00000000,
/* 90 'Z' */
0b_11111000,
0b_00001000,
0b_00010000,
0b_00100000,
0b_01000000,
0b_10000000,
0b_11111000,
0b_00000000,
/* 91 '[' */
0b_01110000,
0b_01000000,
0b_01000000,
0b_01000000,
0b_01000000,
0b_01000000,
0b_01110000,
0b_00000000,
/* 92 '\' */
0b_00000000,
0b_00000000,
0b_10000000,
0b_01000000,
0b_00100000,
0b_00010000,
0b_00001000,
0b_00000000,
/* 93 ']' */
0b_01110000,
0b_00010000,
0b_00010000,
0b_00010000,
0b_00010000,
0b_00010000,
0b_01110000,
0b_00000000,
/* 94 '^' */
0b_00100000,
0b_01010000,
0b_10001000,
0b_00000000,
0b_00000000,
0b_00000000,
0b_00000000,
0b_00000000,
/* 95 '_' */
0b_00000000,
0b_00000000,
0b_00000000,
0b_00000000,
0b_00000000,
0b_00000000,
0b_11111000,
0b_00000000,
/* 96 '`' */
0b_01000000,
0b_00100000,
0b_00010000,
0b_00000000,
0b_00000000,
0b_00000000,
0b_00000000,
0b_00000000,
/* 97 'a' */
0b_00000000,
0b_00000000,
0b_01110000,
0b_00001000,
0b_01111000,
0b_10001000,
0b_01111000,
0b_00000000,
/* 98 'b' */
0b_10000000,
0b_10000000,
0b_10110000,
0b_11001000,
0b_10001000,
0b_11001000,
0b_10110000,
0b_00000000,
/* 99 'c' */
0b_00000000,
0b_00000000,
0b_01110000,
0b_10001000,
0b_10000000,
0b_10001000,
0b_01110000,
0b_00000000,
/* 100 'd' */
0b_00001000,
0b_00001000,
0b_01101000,
0b_10011000,
0b_10001000,
0b_10011000,
0b_01101000,
0b_00000000,
/* 101 'e' */
0b_00000000,
0b_00000000,
0b_01110000,
0b_10001000,
0b_11111000,
0b_10000000,
0b_01110000,
0b_00000000,
/* 102 'f' */
0b_00010000,
0b_00101000,
0b_00100000,
0b_11111000,
0b_00100000,
0b_00100000,
0b_00100000,
0b_00000000,
/* 103 'g' */
0b_00000000,
0b_00000000,
0b_01101000,
0b_10011000,
0b_10011000,
0b_01101000,
0b_00001000,
0b_01110000,
/* 104 'h' */
0b_10000000,
0b_10000000,
0b_11110000,
0b_10001000,
0b_10001000,
0b_10001000,
0b_10001000,
0b_00000000,
/* 105 'i' */
0b_00100000,
0b_00000000,
0b_01100000,
0b_00100000,
0b_00100000,
0b_00100000,
0b_01110000,
0b_00000000,
/* 106 'j' */
0b_00010000,
0b_00000000,
0b_00110000,
0b_00010000,
0b_00010000,
0b_00010000,
0b_10010000,
0b_01100000,
/* 107 'k' */
0b_01000000,
0b_01000000,
0b_01001000,
0b_01010000,
0b_01100000,
0b_01010000,
0b_01001000,
0b_00000000,
/* 108 'l' */
0b_01100000,
0b_00100000,
0b_00100000,
0b_00100000,
0b_00100000,
0b_00100000,
0b_01110000,
0b_00000000,
/* 109 'm' */
0b_00000000,
0b_00000000,
0b_11010000,
0b_10101000,
0b_10101000,
0b_10101000,
0b_10101000,
0b_00000000,
/* 110 'n' */
0b_00000000,
0b_00000000,
0b_10110000,
0b_11001000,
0b_10001000,
0b_10001000,
0b_10001000,
0b_00000000,
/* 111 'o' */
0b_00000000,
0b_00000000,
0b_01110000,
0b_10001000,
0b_10001000,
0b_10001000,
0b_01110000,
0b_00000000,
/* 112 'p' */
0b_00000000,
0b_00000000,
0b_10110000,
0b_11001000,
0b_11001000,
0b_10110000,
0b_10000000,
0b_10000000,
/* 113 'q' */
0b_00000000,
0b_00000000,
0b_01101000,
0b_10011000,
0b_10011000,
0b_01101000,
0b_00001000,
0b_00001000,
/* 114 'r' */
0b_00000000,
0b_00000000,
0b_10110000,
0b_11001000,
0b_10000000,
0b_10000000,
0b_10000000,
0b_00000000,
/* 115 's' */
0b_00000000,
0b_00000000,
0b_01111000,
0b_10000000,
0b_11110000,
0b_00001000,
0b_11110000,
0b_00000000,
/* 116 't' */
0b_01000000,
0b_01000000,
0b_11110000,
0b_01000000,
0b_01000000,
0b_01001000,
0b_00110000,
0b_00000000,
/* 117 'u' */
0b_00000000,
0b_00000000,
0b_10010000,
0b_10010000,
0b_10010000,
0b_10010000,
0b_01101000,
0b_00000000,
/* 118 'v' */
0b_00000000,
0b_00000000,
0b_10001000,
0b_10001000,
0b_10001000,
0b_01010000,
0b_00100000,
0b_00000000,
/* 119 'w' */
0b_00000000,
0b_00000000,
0b_10001000,
0b_10101000,
0b_10101000,
0b_10101000,
0b_01010000,
0b_00000000,
/* 120 'x' */
0b_00000000,
0b_00000000,
0b_10001000,
0b_01010000,
0b_00100000,
0b_01010000,
0b_10001000,
0b_00000000,
/* 121 'y' */
0b_00000000,
0b_00000000,
0b_10001000,
0b_10001000,
0b_10011000,
0b_01101000,
0b_00001000,
0b_01110000,
/* 122 'z' */
0b_00000000,
0b_00000000,
0b_11111000,
0b_00010000,
0b_00100000,
0b_01000000,
0b_11111000,
0b_00000000,
/* 123 '{' */
0b_00011000,
0b_00100000,
0b_00100000,
0b_01000000,
0b_00100000,
0b_00100000,
0b_00011000,
0b_00000000,
/* 124 '|' */
0b_00100000,
0b_00100000,
0b_00100000,
0b_00000000,
0b_00100000,
0b_00100000,
0b_00100000,
0b_00000000,
/* 125 '}' */
0b_11000000,
0b_00100000,
0b_00100000,
0b_00010000,
0b_00100000,
0b_00100000,
0b_11000000,
0b_00000000,
/* 126 '~' */
0b_01000000,
0b_10101000,
0b_00010000,
0b_00000000,
0b_00000000,
0b_00000000,
0b_00000000,
0b_00000000,
/* 127 */
0b_00000000,
0b_00000000,
0b_00100000,
0b_01010000,
0b_11111000,
0b_00000000,
0b_00000000,
0b_00000000,
/* 128 */
0b_00000000,
0b_00000000,
0b_00000000,
0b_00000000,
0b_00000000,
0b_00000000,
0b_11111111,
0b_11111111,
/* 129 */
0b_11110000,
0b_11110000,
0b_11110000,
0b_11110000,
0b_00001111,
0b_00001111,
0b_00001111,
0b_00001111,
/* 130 */
0b_00000000,
0b_00000000,
0b_11111111,
0b_11111111,
0b_11111111,
0b_11111111,
0b_11111111,
0b_11111111,
/* 131 */
0b_11111111,
0b_11111111,
0b_00000000,
0b_00000000,
0b_00000000,
0b_00000000,
0b_00000000,
0b_00000000,
/* 132 */
0b_00000000,
0b_00000000,
0b_00000000,
0b_00111100,
0b_00111100,
0b_00000000,
0b_00000000,
0b_00000000,
/* 133 */
0b_11111111,
0b_11111111,
0b_11111111,
0b_11111111,
0b_11111111,
0b_11111111,
0b_00000000,
0b_00000000,
/* 134 */
0b_11000000,
0b_11000000,
0b_11000000,
0b_11000000,
0b_11000000,
0b_11000000,
0b_11000000,
0b_11000000,
/* 135 */
0b_00001111,
0b_00001111,
0b_00001111,
0b_00001111,
0b_11110000,
0b_11110000,
0b_11110000,
0b_11110000,
/* 136 */
0b_11111100,
0b_11111100,
0b_11111100,
0b_11111100,
0b_11111100,
0b_11111100,
0b_11111100,
0b_11111100,
/* 137 */
0b_00000011,
0b_00000011,
0b_00000011,
0b_00000011,
0b_00000011,
0b_00000011,
0b_00000011,
0b_00000011,
/* 138 */
0b_00111111,
0b_00111111,
0b_00111111,
0b_00111111,
0b_00111111,
0b_00111111,
0b_00111111,
0b_00111111,
/* 139 */
0b_00010001,
0b_00100010,
0b_01000100,
0b_10001000,
0b_00010001,
0b_00100010,
0b_01000100,
0b_10001000,
/* 140 */
0b_10001000,
0b_01000100,
0b_00100010,
0b_00010001,
0b_10001000,
0b_01000100,
0b_00100010,
0b_00010001,
/* 141 */
0b_11111110,
0b_01111100,
0b_00111000,
0b_00010000,
0b_00000000,
0b_00000000,
0b_00000000,
0b_00000000,
/* 142 */
0b_00000000,
0b_00000000,
0b_00000000,
0b_00000000,
0b_00010000,
0b_00111000,
0b_01111100,
0b_11111110,
/* 143 */
0b_10000000,
0b_11000000,
0b_11100000,
0b_11110000,
0b_11100000,
0b_11000000,
0b_10000000,
0b_00000000,
/* 144 */
0b_00000001,
0b_00000011,
0b_00000111,
0b_00001111,
0b_00000111,
0b_00000011,
0b_00000001,
0b_00000000,
/* 145 */
0b_11111111,
0b_01111110,
0b_00111100,
0b_00011000,
0b_00011000,
0b_00111100,
0b_01111110,
0b_11111111,
/* 146 */
0b_10000001,
0b_11000011,
0b_11100111,
0b_11111111,
0b_11111111,
0b_11100111,
0b_11000011,
0b_10000001,
/* 147 */
0b_11110000,
0b_11110000,
0b_11110000,
0b_11110000,
0b_00000000,
0b_00000000,
0b_00000000,
0b_00000000,
/* 148 */
0b_00000000,
0b_00000000,
0b_00000000,
0b_00000000,
0b_00001111,
0b_00001111,
0b_00001111,
0b_00001111,
/* 149 */
0b_00001111,
0b_00001111,
0b_00001111,
0b_00001111,
0b_00000000,
0b_00000000,
0b_00000000,
0b_00000000,
/* 150 */
0b_00000000,
0b_00000000,
0b_00000000,
0b_00000000,
0b_11110000,
0b_11110000,
0b_11110000,
0b_11110000,
/* 151 */
0b_00110011,
0b_00110011,
0b_11001100,
0b_11001100,
0b_00110011,
0b_00110011,
0b_11001100,
0b_11001100,
/* 152 */
0b_00000000,
0b_00100000,
0b_00100000,
0b_01010000,
0b_01010000,
0b_10001000,
0b_11111000,
0b_00000000,
/* 153 */
0b_00100000,
0b_00100000,
0b_01110000,
0b_00100000,
0b_01110000,
0b_00100000,
0b_00100000,
0b_00000000,
/* 154 */
0b_00000000,
0b_00000000,
0b_00000000,
0b_01010000,
0b_10001000,
0b_10101000,
0b_01010000,
0b_00000000,
/* 155 */
0b_11111111,
0b_11111111,
0b_11111111,
0b_11111111,
0b_11111111,
0b_11111111,
0b_11111111,
0b_11111111,
/* 156 */
0b_00000000,
0b_00000000,
0b_00000000,
0b_00000000,
0b_11111111,
0b_11111111,
0b_11111111,
0b_11111111,
/* 157 */
0b_11110000,
0b_11110000,
0b_11110000,
0b_11110000,
0b_11110000,
0b_11110000,
0b_11110000,
0b_11110000,
/* 158 */
0b_00001111,
0b_00001111,
0b_00001111,
0b_00001111,
0b_00001111,
0b_00001111,
0b_00001111,
0b_00001111,
/* 159 */
0b_11111111,
0b_11111111,
0b_11111111,
0b_11111111,
0b_00000000,
0b_00000000,
0b_00000000,
0b_00000000,
/* 160 */
0b_00000000,
0b_00000000,
0b_01101000,
0b_10010000,
0b_10010000,
0b_10010000,
0b_01101000,
0b_00000000,
/* 161 */
0b_00110000,
0b_01001000,
0b_01001000,
0b_01110000,
0b_01001000,
0b_01001000,
0b_01110000,
0b_11000000,
/* 162 */
0b_11111000,
0b_10001000,
0b_10000000,
0b_10000000,
0b_10000000,
0b_10000000,
0b_10000000,
0b_00000000,
/* 163 */
0b_00000000,
0b_01010000,
0b_01110000,
0b_10001000,
0b_11111000,
0b_10000000,
0b_01110000,
0b_00000000,
/* 164 */
0b_00000000,
0b_00000000,
0b_01111000,
0b_10000000,
0b_11110000,
0b_10000000,
0b_01111000,
0b_00000000,
/* 165 */
0b_00000000,
0b_00000000,
0b_01111000,
0b_10010000,
0b_10010000,
0b_10010000,
0b_01100000,
0b_00000000,
/* 166 */
0b_00100000,
0b_00000000,
0b_01100000,
0b_00100000,
0b_00100000,
0b_00100000,
0b_01110000,
0b_00000000,
/* 167 */
0b_01010000,
0b_00000000,
0b_01110000,
0b_00100000,
0b_00100000,
0b_00100000,
0b_01110000,
0b_00000000,
/* 168 */
0b_11111000,
0b_00100000,
0b_01110000,
0b_10101000,
0b_10101000,
0b_01110000,
0b_00100000,
0b_11111000,
/* 169 */
0b_00100000,
0b_01010000,
0b_10001000,
0b_11111000,
0b_10001000,
0b_01010000,
0b_00100000,
0b_00000000,
/* 170 */
0b_01110000,
0b_10001000,
0b_10001000,
0b_10001000,
0b_01010000,
0b_01010000,
0b_11011000,
0b_00000000,
/* 171 */
0b_00110000,
0b_01000000,
0b_01000000,
0b_00100000,
0b_01010000,
0b_01010000,
0b_01010000,
0b_00100000,
/* 172 */
0b_00000000,
0b_00000000,
0b_00000000,
0b_01010000,
0b_10101000,
0b_10101000,
0b_01010000,
0b_00000000,
/* 173 */
0b_00001000,
0b_01110000,
0b_10101000,
0b_10101000,
0b_10101000,
0b_01110000,
0b_10000000,
0b_00000000,
/* 174 */
0b_00111000,
0b_01000000,
0b_10000000,
0b_11111000,
0b_10000000,
0b_01000000,
0b_00111000,
0b_00000000,
/* 175 */
0b_01110000,
0b_10001000,
0b_10001000,
0b_10001000,
0b_10001000,
0b_10001000,
0b_10001000,
0b_00000000,
/* 176 */
0b_00000000,
0b_11111000,
0b_00000000,
0b_11111000,
0b_00000000,
0b_11111000,
0b_00000000,
0b_00000000,
/* 177 */
0b_00100000,
0b_00100000,
0b_11111000,
0b_00100000,
0b_00100000,
0b_00000000,
0b_11111000,
0b_00000000,
/* 178 */
0b_11000000,
0b_00110000,
0b_00001000,
0b_00110000,
0b_11000000,
0b_00000000,
0b_11111000,
0b_00000000,
/* 179 */
0b_01010000,
0b_11111000,
0b_10000000,
0b_11110000,
0b_10000000,
0b_10000000,
0b_11111000,
0b_00000000,
/* 180 */
0b_01111000,
0b_10000000,
0b_10000000,
0b_11110000,
0b_10000000,
0b_10000000,
0b_01111000,
0b_00000000,
/* 181 */
0b_00100000,
0b_00100000,
0b_00100000,
0b_00100000,
0b_00100000,
0b_00100000,
0b_10100000,
0b_01000000,
/* 182 */
0b_01110000,
0b_00100000,
0b_00100000,
0b_00100000,
0b_00100000,
0b_00100000,
0b_01110000,
0b_00000000,
/* 183 */
0b_01010000,
0b_01110000,
0b_00100000,
0b_00100000,
0b_00100000,
0b_00100000,
0b_01110000,
0b_00000000,
/* 184 */
0b_00000000,
0b_00011000,
0b_00100100,
0b_00100100,
0b_00011000,
0b_00000000,
0b_00000000,
0b_00000000,
/* 185 */
0b_00000000,
0b_00110000,
0b_01111000,
0b_01111000,
0b_00110000,
0b_00000000,
0b_00000000,
0b_00000000,
/* 186 */
0b_00000000,
0b_00000000,
0b_00000000,
0b_00000000,
0b_00110000,
0b_00000000,
0b_00000000,
0b_00000000,
/* 187 */
0b_00111110,
0b_00100000,
0b_00100000,
0b_00100000,
0b_10100000,
0b_01100000,
0b_00100000,
0b_00000000,
/* 188 */
0b_10100000,
0b_01010000,
0b_01010000,
0b_01010000,
0b_00000000,
0b_00000000,
0b_00000000,
0b_00000000,
/* 189 */
0b_01000000,
0b_10100000,
0b_00100000,
0b_01000000,
0b_11100000,
0b_00000000,
0b_00000000,
0b_00000000,
/* 190 */
0b_00000000,
0b_00111000,
0b_00111000,
0b_00111000,
0b_00111000,
0b_00111000,
0b_00111000,
0b_00000000,
/* 191 */
0b_00111100,
0b_01000010,
0b_10011001,
0b_10100001,
0b_10100001,
0b_10011001,
0b_01000010,
0b_00111100,
/* 192 */
0b_00000000,
0b_00000000,
0b_10010000,
0b_10101000,
0b_11101000,
0b_10101000,
0b_10010000,
0b_00000000,
/* 193 */
0b_00000000,
0b_00000000,
0b_01100000,
0b_00010000,
0b_01110000,
0b_10010000,
0b_01101000,
0b_00000000,
/* 194 */
0b_00000000,
0b_00000000,
0b_11110000,
0b_10000000,
0b_11110000,
0b_10001000,
0b_11110000,
0b_00000000,
/* 195 */
0b_00000000,
0b_00000000,
0b_10010000,
0b_10010000,
0b_10010000,
0b_11111000,
0b_00001000,
0b_00000000,
/* 196 */
0b_00000000,
0b_00000000,
0b_00110000,
0b_01010000,
0b_01010000,
0b_01110000,
0b_10001000,
0b_00000000,
/* 197 */
0b_00000000,
0b_00000000,
0b_01110000,
0b_10001000,
0b_11111000,
0b_10000000,
0b_01110000,
0b_00000000,
/* 198 */
0b_00000000,
0b_00100000,
0b_01110000,
0b_10101000,
0b_10101000,
0b_01110000,
0b_00100000,
0b_00000000,
/* 199 */
0b_00000000,
0b_00000000,
0b_01111000,
0b_01001000,
0b_01000000,
0b_01000000,
0b_01000000,
0b_00000000,
/* 200 */
0b_00000000,
0b_00000000,
0b_10001000,
0b_01010000,
0b_00100000,
0b_01010000,
0b_10001000,
0b_00000000,
/* 201 */
0b_00000000,
0b_00000000,
0b_10001000,
0b_10011000,
0b_10101000,
0b_11001000,
0b_10001000,
0b_00000000,
/* 202 */
0b_00000000,
0b_01010000,
0b_00100000,
0b_00000000,
0b_10011000,
0b_10101000,
0b_11001000,
0b_00000000,
/* 203 */
0b_00000000,
0b_00000000,
0b_10010000,
0b_10100000,
0b_11000000,
0b_10100000,
0b_10010000,
0b_00000000,
/* 204 */
0b_00000000,
0b_00000000,
0b_00111000,
0b_00101000,
0b_00101000,
0b_01001000,
0b_10001000,
0b_00000000,
/* 205 */
0b_00000000,
0b_00000000,
0b_10001000,
0b_11011000,
0b_10101000,
0b_10001000,
0b_10001000,
0b_00000000,
/* 206 */
0b_00000000,
0b_00000000,
0b_10001000,
0b_10001000,
0b_11111000,
0b_10001000,
0b_10001000,
0b_00000000,
/* 207 */
0b_00000000,
0b_00000000,
0b_01110000,
0b_10001000,
0b_10001000,
0b_10001000,
0b_01110000,
0b_00000000,
/* 208 */
0b_00000000,
0b_00000000,
0b_01111000,
0b_01001000,
0b_01001000,
0b_01001000,
0b_01001000,
0b_00000000,
/* 209 */
0b_00000000,
0b_00000000,
0b_01111000,
0b_10001000,
0b_01111000,
0b_00101000,
0b_01001000,
0b_00000000,
/* 210 */
0b_00000000,
0b_00000000,
0b_11110000,
0b_10001000,
0b_11110000,
0b_10000000,
0b_10000000,
0b_00000000,
/* 211 */
0b_00000000,
0b_00000000,
0b_01111000,
0b_10000000,
0b_10000000,
0b_10000000,
0b_01111000,
0b_00000000,
/* 212 */
0b_00000000,
0b_00000000,
0b_11111000,
0b_00100000,
0b_00100000,
0b_00100000,
0b_00100000,
0b_00000000,
/* 213 */
0b_00000000,
0b_00000000,
0b_10001000,
0b_01010000,
0b_00100000,
0b_01000000,
0b_10000000,
0b_00000000,
/* 214 */
0b_00000000,
0b_00000000,
0b_10101000,
0b_01110000,
0b_00100000,
0b_01110000,
0b_10101000,
0b_00000000,
/* 215 */
0b_00000000,
0b_00000000,
0b_11110000,
0b_01001000,
0b_01110000,
0b_01001000,
0b_11110000,
0b_00000000,
/* 216 */
0b_00000000,
0b_00000000,
0b_01000000,
0b_01000000,
0b_01110000,
0b_01001000,
0b_01110000,
0b_00000000,
/* 217 */
0b_00000000,
0b_00000000,
0b_10001000,
0b_10001000,
0b_11001000,
0b_10101000,
0b_11001000,
0b_00000000,
/* 218 */
0b_00000000,
0b_00000000,
0b_11110000,
0b_00001000,
0b_01110000,
0b_00001000,
0b_11110000,
0b_00000000,
/* 219 */
0b_00000000,
0b_00000000,
0b_10101000,
0b_10101000,
0b_10101000,
0b_10101000,
0b_11111000,
0b_00000000,
/* 220 */
0b_00000000,
0b_00000000,
0b_01110000,
0b_10001000,
0b_00111000,
0b_10001000,
0b_01110000,
0b_00000000,
/* 221 */
0b_00000000,
0b_00000000,
0b_10101000,
0b_10101000,
0b_10101000,
0b_11111000,
0b_00001000,
0b_00000000,
/* 222 */
0b_00000000,
0b_00000000,
0b_01001000,
0b_01001000,
0b_01111000,
0b_00001000,
0b_00001000,
0b_00000000,
/* 223 */
0b_00000000,
0b_00000000,
0b_11000000,
0b_01000000,
0b_01110000,
0b_01001000,
0b_01110000,
0b_00000000,
/* 224 */
0b_10010000,
0b_10101000,
0b_10101000,
0b_11101000,
0b_10101000,
0b_10101000,
0b_10010000,
0b_00000000,
/* 225 */
0b_00100000,
0b_01010000,
0b_10001000,
0b_10001000,
0b_11111000,
0b_10001000,
0b_10001000,
0b_00000000,
/* 226 */
0b_11111000,
0b_10001000,
0b_10000000,
0b_11110000,
0b_10001000,
0b_10001000,
0b_11110000,
0b_00000000,
/* 227 */
0b_10010000,
0b_10010000,
0b_10010000,
0b_10010000,
0b_10010000,
0b_11111000,
0b_00001000,
0b_00000000,
/* 228 */
0b_00111000,
0b_00101000,
0b_00101000,
0b_01001000,
0b_01001000,
0b_11111000,
0b_10001000,
0b_00000000,
/* 229 */
0b_11111000,
0b_10000000,
0b_10000000,
0b_11110000,
0b_10000000,
0b_10000000,
0b_11111000,
0b_00000000,
/* 230 */
0b_00100000,
0b_01110000,
0b_10101000,
0b_10101000,
0b_10101000,
0b_01110000,
0b_00100000,
0b_00000000,
/* 231 */
0b_11111000,
0b_10001000,
0b_10001000,
0b_10000000,
0b_10000000,
0b_10000000,
0b_10000000,
0b_00000000,
/* 232 */
0b_10001000,
0b_10001000,
0b_01010000,
0b_00100000,
0b_01010000,
0b_10001000,
0b_10001000,
0b_00000000,
/* 233 */
0b_10001000,
0b_10001000,
0b_10011000,
0b_10101000,
0b_11001000,
0b_10001000,
0b_10001000,
0b_00000000,
/* 234 */
0b_01010000,
0b_00100000,
0b_10001000,
0b_10011000,
0b_10101000,
0b_11001000,
0b_10001000,
0b_00000000,
/* 235 */
0b_10001000,
0b_10010000,
0b_10100000,
0b_11000000,
0b_10100000,
0b_10010000,
0b_10001000,
0b_00000000,
/* 236 */
0b_00011000,
0b_00101000,
0b_01001000,
0b_01001000,
0b_01001000,
0b_01001000,
0b_10001000,
0b_00000000,
/* 237 */
0b_10001000,
0b_11011000,
0b_10101000,
0b_10101000,
0b_10001000,
0b_10001000,
0b_10001000,
0b_00000000,
/* 238 */
0b_10001000,
0b_10001000,
0b_10001000,
0b_11111000,
0b_10001000,
0b_10001000,
0b_10001000,
0b_00000000,
/* 239 */
0b_01110000,
0b_10001000,
0b_10001000,
0b_10001000,
0b_10001000,
0b_10001000,
0b_01110000,
0b_00000000,
/* 240 */
0b_11111000,
0b_10001000,
0b_10001000,
0b_10001000,
0b_10001000,
0b_10001000,
0b_10001000,
0b_00000000,
/* 241 */
0b_01111000,
0b_10001000,
0b_10001000,
0b_01111000,
0b_00101000,
0b_01001000,
0b_10001000,
0b_00000000,
/* 242 */
0b_11110000,
0b_10001000,
0b_10001000,
0b_11110000,
0b_10000000,
0b_10000000,
0b_10000000,
0b_00000000,
/* 243 */
0b_01110000,
0b_10001000,
0b_10000000,
0b_10000000,
0b_10000000,
0b_10001000,
0b_01110000,
0b_00000000,
/* 244 */
0b_11111000,
0b_00100000,
0b_00100000,
0b_00100000,
0b_00100000,
0b_00100000,
0b_00100000,
0b_00000000,
/* 245 */
0b_10001000,
0b_10001000,
0b_10001000,
0b_01010000,
0b_00100000,
0b_01000000,
0b_10000000,
0b_00000000,
/* 246 */
0b_10101000,
0b_10101000,
0b_01110000,
0b_00100000,
0b_01110000,
0b_10101000,
0b_10101000,
0b_00000000,
/* 247 */
0b_11110000,
0b_01001000,
0b_01001000,
0b_01110000,
0b_01001000,
0b_01001000,
0b_11110000,
0b_00000000,
/* 248 */
0b_10000000,
0b_10000000,
0b_10000000,
0b_11110000,
0b_10001000,
0b_10001000,
0b_11110000,
0b_00000000,
/* 249 */
0b_10001000,
0b_10001000,
0b_10001000,
0b_11001000,
0b_10101000,
0b_10101000,
0b_11001000,
0b_00000000,
/* 250 */
0b_11110000,
0b_00001000,
0b_00001000,
0b_00110000,
0b_00001000,
0b_00001000,
0b_11110000,
0b_00000000,
/* 251 */
0b_10101000,
0b_10101000,
0b_10101000,
0b_10101000,
0b_10101000,
0b_10101000,
0b_11111000,
0b_00000000,
/* 252 */
0b_01110000,
0b_10001000,
0b_00001000,
0b_01111000,
0b_00001000,
0b_10001000,
0b_01110000,
0b_00000000,
/* 253 */
0b_10101000,
0b_10101000,
0b_10101000,
0b_10101000,
0b_10101000,
0b_11111000,
0b_00001000,
0b_00000000,
/* 254 */
0b_10001000,
0b_10001000,
0b_10001000,
0b_10001000,
0b_01111000,
0b_00001000,
0b_00001000,
0b_00000000,
/* 255 */
0b_11000000,
0b_01000000,
0b_01000000,
0b_01110000,
0b_01001000,
0b_01001000,
0b_01110000,
0b_00000000,
];


// bits 0..3: width
// bits 4..7: lshift
public immutable ubyte[256] vlFontPropWidth = () {
  ubyte[256] res;
  foreach (immutable cnum; 0..256) {
    import core.bitop : bsf, bsr;
    immutable doshift =
      (cnum >= 32 && cnum <= 127) ||
      (cnum >= 143 && cnum <= 144) ||
      (cnum >= 166 && cnum <= 167) ||
      (cnum >= 192 && cnum <= 255);
    int shift = 0;
    if (doshift) {
      shift = 8;
      foreach (immutable dy; 0..8) {
        immutable b = vlFont6[cnum*8+dy];
        if (b) {
          immutable mn = 7-bsr(b);
          if (mn < shift) shift = mn;
        }
      }
    }
    ubyte wdt = 0;
    foreach (immutable dy; 0..8) {
      immutable b = (vlFont6[cnum*8+dy]<<shift);
      immutable cwdt = (b ? 8-bsf(b) : 0);
      if (cwdt > wdt) wdt = cast(ubyte)cwdt;
    }
    switch (cnum) {
      case 0: wdt = 8; break; // 8px space
      case 32: wdt = 5; break; // 5px space
      case  17: .. case  27: wdt = 8; break; // single frames
      case  48: .. case  57: wdt = 5; break; // digits are monospaced
      case 127: .. case 142: wdt = 8; break; // filled frames
      case 145: .. case 151: wdt = 8; break; // filled frames
      case 155: .. case 159: wdt = 8; break; // filled frames
      default:
    }
    res[cnum] = (wdt&0x0f)|((shift<<4)&0xf0);
  }
  return res;
}();
