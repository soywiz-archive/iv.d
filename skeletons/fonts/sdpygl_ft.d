import arsd.color;
import arsd.simpledisplay;

//import iv.bclamp;
import iv.cmdcon;
import iv.cmdcongl;
import iv.utfutil;
import iv.vfs;

import iv.freetype;


// ////////////////////////////////////////////////////////////////////////// //
public struct GxPoint {
public:
  int x, y; ///

pure nothrow @safe @nogc:
  this() (in auto ref GxPoint p) { pragma(inline, true); x = p.x; y = p.y; } ///
  this (int ax, int ay) { pragma(inline, true); x = ax; y = ay; } ///
  void opAssign() (in auto ref GxPoint p) { pragma(inline, true); x = p.x; y = p.y; } ///
  bool opEquals() (in auto ref GxPoint p) const { pragma(inline, true); return (p.x == x && p.y == y); } ///
  ///
  int opCmp() (in auto ref GxPoint p) const {
    pragma(inline, true);
         if (auto d0 = y-p.y) return (d0 < 0 ? -1 : 1);
    else if (auto d1 = x-p.x) return (d1 < 0 ? -1 : 1);
    else return 0;
  }
}

public struct GxRect {
public:
  int x0, y0; ///
  int width = -1; // <0: invalid rect
  int height = -1; // <0: invalid rect

  alias left = x0; ///
  alias top = y0; ///
  alias right = x1; ///
  alias bottom = y1; ///

  ///
  string toString () const @trusted nothrow {
    if (valid) {
      import core.stdc.stdio : snprintf;
      char[128] buf = void;
      return buf[0..snprintf(buf.ptr, buf.length, "(%d,%d)-(%d,%d)", x0, y0, x0+width-1, y0+height-1)].idup;
    } else {
      return "(invalid-rect)";
    }
  }

pure nothrow @safe @nogc:
  ///
  this() (in auto ref GxRect rc) { pragma(inline, true); x0 = rc.x0; y0 = rc.y0; width = rc.width; height = rc.height; } ///

  ///
  this (int ax0, int ay0, int awidth, int aheight) {
    pragma(inline, true);
    x0 = ax0;
    y0 = ay0;
    width = awidth;
    height = aheight;
  }

  ///
  this() (in auto ref GxPoint xy0, int awidth, int aheight) {
    pragma(inline, true);
    x0 = xy0.x;
    y0 = xy0.y;
    width = awidth;
    height = aheight;
  }

  ///
  this() (in auto ref GxPoint xy0, in auto ref GxPoint xy1) {
    pragma(inline, true);
    x0 = xy0.x;
    y0 = xy0.y;
    width = xy1.x-xy0.x+1;
    height = xy1.y-xy0.y+1;
  }

  void opAssign() (in auto ref GxRect rc) { pragma(inline, true); x0 = rc.x0; y0 = rc.y0; width = rc.width; height = rc.height; } ///
  bool opEquals() (in auto ref GxRect rc) const { pragma(inline, true); return (rc.x0 == x0 && rc.y0 == y0 && rc.width == width && rc.height == height); } ///
  ///
  int opCmp() (in auto ref GxRect p) const {
    if (auto d0 = y0-rc.y0) return (d0 < 0 ? -1 : 1);
    if (auto d1 = x0-rc.x0) return (d1 < 0 ? -1 : 1);
    if (auto d2 = width*height-rc.width*rc.height) return (d2 < 0 ? -1 : 1);
    return 0;
  }

  @property bool valid () const { pragma(inline, true); return (width >= 0 && height >= 0); } ///
  @property bool invalid () const { pragma(inline, true); return (width < 0 || height < 0); } ///
  @property bool empty () const { pragma(inline, true); return (width <= 0 || height <= 0); } /// invalid rects are empty

  void invalidate () { pragma(inline, true); width = height = -1; } ///

  @property GxPoint lefttop () const { pragma(inline, true); return GxPoint(x0, y0); } ///
  @property GxPoint righttop () const { pragma(inline, true); return GxPoint(x0+width-1, y0); } ///
  @property GxPoint leftbottom () const { pragma(inline, true); return GxPoint(x0, y0+height-1); } ///
  @property GxPoint rightbottom () const { pragma(inline, true); return GxPoint(x0+width-1, y0+height-1); } ///

  alias topleft = lefttop; ///
  alias topright = righttop; ///
  alias bottomleft = leftbottom; ///
  alias bottomright = rightbottom; ///

  @property int x1 () const { pragma(inline, true); return (width > 0 ? x0+width-1 : x0-1); } ///
  @property int y1 () const { pragma(inline, true); return (height > 0 ? y0+height-1 : y0-1); } ///

  @property void x1 (in int val) { pragma(inline, true); width = val-x0+1; } ///
  @property void y1 (in int val) { pragma(inline, true); height = val-y0+1; } ///

  ///
  bool inside() (in auto ref GxPoint p) const {
    pragma(inline, true);
    return (width >= 0 && height >= 0 ? (p.x >= x0 && p.y >= y0 && p.x < x0+width && p.y < y0+height) : false);
  }

  /// ditto
  bool inside (in int ax, in int ay) const {
    pragma(inline, true);
    return (width >= 0 && height >= 0 ? (ax >= x0 && ay >= y0 && ax < x0+width && ay < y0+height) : false);
  }

  /// is `r` inside `this`?
  bool inside() (in auto ref GxRect r) const {
    pragma(inline, true);
    return
      !empty && !r.empty &&
      r.x >= x0 && r.y >= y0 &&
      r.x1 <= x1 && r.y1 <= y1;
  }

  /// is `r` and `this` overlaps?
  bool overlap() (in auto ref GxRect r) const {
    pragma(inline, true);
    return
      !empty && !r.empty &&
      x <= r.x1 && r.x <= x1 && y <= r.y1 && r.y <= y1;
  }

  /// extend `this` so it will include `r`
  void include() (in auto ref GxRect r) {
    pragma(inline, true);
    if (!r.empty) {
      if (empty) {
        x0 = r.x;
        y0 = r.y;
        width = r.width;
        height = r.height;
      } else {
        if (r.x < x0) x0 = r.x;
        if (r.y < y0) y0 = r.y;
        if (r.x1 > x1) x1 = r.x1;
        if (r.y1 > y1) y1 = r.y1;
      }
    }
  }

  /// clip `this` so it will not be larger than `r`
  bool intersect() (in auto ref GxRect r) {
    if (r.invalid || invalid) { width = height = -1; return false; }
    if (r.empty || empty) { width = height = 0; return false; }
    if (r.y1 < y0 || r.x1 < x0 || r.x0 > x1 || r.y0 > y1) { width = height = 0; return false; }
    // rc is at least partially inside this rect
    if (x0 < r.x0) x0 = r.x0;
    if (y0 < r.y0) y0 = r.y0;
    if (x1 > r.x1) x1 = r.x1;
    if (y1 > r.y1) y1 = r.y1;
    assert(!empty); // yeah, always
    return true;
  }

  ///
  void shrinkBy (int dx, int dy) {
    pragma(inline, true);
    if ((dx || dy) && valid) {
      x0 += dx;
      y0 += dy;
      width -= dx*2;
      height -= dy*2;
    }
  }

  ///
  void growBy (int dx, int dy) {
    pragma(inline, true);
    if ((dx || dy) && valid) {
      x0 -= dx;
      y0 -= dy;
      width += dx*2;
      height += dy*2;
    }
  }

  ///
  void set (int ax0, int ay0, int awidth, int aheight) {
    pragma(inline, true);
    x0 = ax0;
    y0 = ay0;
    width = awidth;
    height = aheight;
  }

  ///
  void moveLeftTopBy (int dx, int dy) {
    pragma(inline, true);
    x0 += dx;
    y0 += dy;
    width -= dx;
    height -= dy;
  }

  alias moveTopLeftBy = moveLeftTopBy; /// ditto

  ///
  void moveRightBottomBy (int dx, int dy) {
    pragma(inline, true);
    width += dx;
    height += dy;
  }

  alias moveBottomRightBy = moveRightBottomBy; /// ditto

  ///
  void moveBy (int dx, int dy) {
    pragma(inline, true);
    x0 += dx;
    y0 += dy;
  }

  ///
  void moveTo (int nx, int ny) {
    pragma(inline, true);
    x0 = nx;
    y0 = ny;
  }

  /**
   * clip (x,y,len) stripe to this rect
   *
   * Params:
   *  x = stripe start (not relative to rect)
   *  y = stripe start (not relative to rect)
   *  len = stripe length
   *
   * Returns:
   *  x = fixed x
   *  len = fixed length
   *  leftSkip = how much cells skipped at the left side
   *  result = false if stripe is completely clipped out
   *
   * TODO:
   *  overflows
   */
  bool clipStripe (ref int x, int y, ref int len, out int leftSkip) const {
    if (empty) return false;
    if (len <= 0 || y < y0 || y >= y0+height || x >= x0+width) return false;
    if (x < x0) {
      // left clip
      if (x+len <= x0) return false;
      len -= (leftSkip = x0-x);
      x = x0;
    }
    if (x+len >= x0+width) {
      // right clip
      len = x0+width-x;
      assert(len > 0); // yeah, always
    }
    return true;
  }

  /// ditto
  bool clipStripe (ref int x, int y, ref int len) const {
    pragma(inline, true);
    int dummy = void;
    return clipStripe(x, y, len, dummy);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
private import iv.bclamp;

//public enum GLTexType = GL_RGBA;
public enum GLTexType = GL_BGRA;

private __gshared int VBufWidth = 800;
private __gshared int VBufHeight = 600;

public __gshared uint* vglTexBuf = null; // OpenGL texture buffer
public __gshared uint vglTexId = 0;


public @property int winWidth () nothrow @trusted @nogc { pragma(inline, true); return VBufWidth; }
public @property int winHeight () nothrow @trusted @nogc { pragma(inline, true); return VBufHeight; }


// ////////////////////////////////////////////////////////////////////////// //
public void gxResize (int wdt, int hgt) nothrow @trusted {
  if (wdt < 1) wdt = 1;
  if (hgt < 1) hgt = 1;
  if (wdt > 16384) wdt = 16384;
  if (hgt > 16384) hgt = 16384;
  if (vglTexBuf is null || wdt != VBufWidth || hgt != VBufHeight || vglTexId == 0) {
    import core.stdc.stdlib : realloc;
    VBufWidth = wdt;
    VBufHeight = hgt;
    vglTexBuf = cast(uint*)realloc(vglTexBuf, wdt*hgt*vglTexBuf[0].sizeof);
    if (vglTexBuf is null) assert(0, "VGL: out of memory");
    vglTexBuf[0..wdt*hgt] = 0;

    if (gxRebuildScreenCB !is null) {
      gxClipReset();
      try {
        gxRebuildScreenCB();
      } catch (Exception e) {
        conwriteln("SCREEN REBUILD ERROR: ", e.msg);
      }
    }

    enum wrapOpt = GL_REPEAT;
    enum filterOpt = GL_NEAREST; //GL_LINEAR;
    enum ttype = GL_UNSIGNED_BYTE;

    if (vglTexId) glDeleteTextures(1, &vglTexId);
    vglTexId = 0;
    glGenTextures(1, &vglTexId);
    if (vglTexId == 0) assert(0, "VGL: can't create screen texture");

    glBindTexture(GL_TEXTURE_2D, vglTexId);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, wrapOpt);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, wrapOpt);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, filterOpt);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, filterOpt);

    //GLfloat[4] bclr = 0.0;
    //glTexParameterfv(GL_TEXTURE_2D, GL_TEXTURE_BORDER_COLOR, bclr.ptr);

    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, VBufWidth, VBufHeight, 0, GLTexType, GL_UNSIGNED_BYTE, vglTexBuf);
  }
}


public void gxUpdateTexture () nothrow @trusted @nogc {
  if (vglTexId) {
    glBindTexture(GL_TEXTURE_2D, vglTexId);
    glTexSubImage2D(GL_TEXTURE_2D, 0, 0/*x*/, 0/*y*/, VBufWidth, VBufHeight, GLTexType, GL_UNSIGNED_BYTE, vglTexBuf);
    //glBindTexture(GL_TEXTURE_2D, 0);
  }
}


public void gxBlitTexture () nothrow @trusted @nogc {
  if (!vglTexId) return;

  glMatrixMode(GL_PROJECTION); // for ortho camera
  glLoadIdentity();
  glViewport(0, 0, VBufWidth, VBufHeight);
  glOrtho(0, VBufWidth, VBufHeight, 0, -1, 1); // top-to-bottom
  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity();

  glEnable(GL_TEXTURE_2D);
  glDisable(GL_LIGHTING);
  glDisable(GL_DITHER);
  glDisable(GL_DEPTH_TEST);
  glDisable(GL_BLEND);
  //glDisable(GL_STENCIL_TEST);

  immutable w = VBufWidth;
  immutable h = VBufHeight;

  glColor4f(1, 1, 1, 1);
  glBindTexture(GL_TEXTURE_2D, vglTexId);
  //scope(exit) glBindTexture(GL_TEXTURE_2D, 0);
  glBegin(GL_QUADS);
    glTexCoord2f(0.0f, 0.0f); glVertex2i(0, 0); // top-left
    glTexCoord2f(1.0f, 0.0f); glVertex2i(w, 0); // top-right
    glTexCoord2f(1.0f, 1.0f); glVertex2i(w, h); // bottom-right
    glTexCoord2f(0.0f, 1.0f); glVertex2i(0, h); // bottom-left
  glEnd();
}


// ////////////////////////////////////////////////////////////////////////// //
// mix dc with ARGB (or ABGR) col; dc A is ignored (removed)
public uint gxColMix (uint dc, uint col) pure nothrow @trusted @nogc {
  pragma(inline, true);
  immutable uint a = 256-(col>>24); // to not loose bits
  //immutable uint dc = (da)&0xffffff;
  dc &= 0xffffff;
  immutable uint srb = (col&0xff00ff);
  immutable uint sg = (col&0x00ff00);
  immutable uint drb = (dc&0xff00ff);
  immutable uint dg = (dc&0x00ff00);
  immutable uint orb = (drb+(((srb-drb)*a+0x800080)>>8))&0xff00ff;
  immutable uint og = (dg+(((sg-dg)*a+0x008000)>>8))&0x00ff00;
  return orb|og;
}


// ////////////////////////////////////////////////////////////////////////// //
private template isGoodRGBInt(T) {
  import std.traits : Unqual;
  alias TT = Unqual!T;
  enum isGoodRGBInt =
    is(TT == ubyte) ||
    is(TT == short) || is(TT == ushort) ||
    is(TT == int) || is(TT == uint) ||
    is(TT == long) || is(TT == ulong);
}


// ////////////////////////////////////////////////////////////////////////// //
public uint gxrgb(T0, T1, T2) (T0 r, T1 g, T2 b) pure nothrow @trusted @nogc if (isGoodRGBInt!T0 && isGoodRGBInt!T1 && isGoodRGBInt!T2) {
  pragma(inline, true);
  return (clampToByte(r)<<16)|(clampToByte(g)<<8)|clampToByte(b);
}


public template gxRGB(int r, int g, int b) {
  enum gxRGB = (clampToByte(r)<<16)|(clampToByte(g)<<8)|clampToByte(b);
}

public template gxRGBA(int r, int g, int b, int a) {
  enum gxRGBA = (clampToByte(a)<<24)|(clampToByte(r)<<16)|(clampToByte(g)<<8)|clampToByte(b);
}


// ////////////////////////////////////////////////////////////////////////// //
public __gshared GxRect gxClipRect = GxRect(0, 0, 65535, 65535);

private struct GxClipSave {
  GxRect rc;
  ~this () const nothrow @trusted @nogc {
    pragma(inline, true);
    gxClipRect = rc;
  }
}

public GxClipSave gxClipSave () nothrow @trusted @nogc {
  pragma(inline, true);
  return GxClipSave(gxClipRect);
}

public void gxClipRestore() (in auto ref GxClipSave cs) nothrow @trusted @nogc {
  pragma(inline, true);
  gxClipRect = cs.rc;
}

public void gxClipReset () nothrow @trusted @nogc {
  pragma(inline, true);
  gxClipRect = GxRect(0, 0, VBufWidth, VBufHeight);
}


// ////////////////////////////////////////////////////////////////////////// //
public void gxClearScreen (uint clr) nothrow @trusted @nogc {
  pragma(inline, true);
  vglTexBuf[0..VBufWidth*VBufHeight+4] = clr;
}


public void gxPutPixel (int x, int y, uint c) nothrow @trusted @nogc {
  pragma(inline, true);
  if (x >= 0 && y >= 0 && x < VBufWidth && y < VBufHeight && (c&0xff000000) != 0xff000000 && gxClipRect.inside(x, y)) {
    uint* dp = cast(uint*)(cast(ubyte*)vglTexBuf)+y*VBufWidth+x;
    *dp = gxColMix(*dp, c);
  }
}


public void gxPutPixel() (in auto ref GxPoint p, uint c) nothrow @trusted @nogc {
  pragma(inline, true);
  if (p.x >= 0 && p.y >= 0 && p.x < VBufWidth && p.y < VBufHeight && (c&0xff000000) != 0xff000000 && gxClipRect.inside(p)) {
    uint* dp = cast(uint*)(cast(ubyte*)vglTexBuf)+p.y*VBufWidth+p.x;
    *dp = gxColMix(*dp, c);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
public void gxHLine (int x, int y, int w, uint clr) nothrow @trusted @nogc {
  if (w < 1 || y < 0 || y >= VBufHeight || x >= VBufWidth) return;
  if (x < 0) {
    if (x+w <= 0) return;
    w += x;
    x = 0;
    assert(w > 0);
  }
  if (x+w > VBufWidth) {
    w = VBufWidth-x;
    assert(w > 0);
  }
  while (w-- > 0) gxPutPixel(x++, y, clr);
}

public void gxHLine() (in auto ref GxPoint p, int w, uint clr) nothrow @trusted @nogc { gxHLine(p.x, p.y, w, clr); }

public void gxVLine (int x, int y, int h, uint clr) nothrow @trusted @nogc {
  if (h < 1 || x < 0 || x >= VBufWidth || y >= VBufHeight) return;
  if (y < 0) {
    if (y+h <= 0) return;
    h += y;
    y = 0;
    assert(h > 0);
  }
  if (y+h > VBufHeight) {
    h = VBufHeight-y;
    assert(h > 0);
  }
  while (h-- > 0) gxPutPixel(x, y++, clr);
}

public void gxVLine() (in auto ref GxPoint p, int h, uint clr) nothrow @trusted @nogc { gxVLine(p.x, p.y, h, clr); }

public void gxFillRect (int x, int y, int w, int h, uint clr) nothrow @trusted @nogc {
  if (w < 1 || h < 1 || x >= VBufWidth || y >= VBufHeight) return;
  while (h-- > 0) gxHLine(x, y++, w, clr);
}

public void gxFillRect() (in auto ref GxRect rc, uint clr) nothrow @trusted @nogc {
  gxFillRect(rc.x0, rc.y0, rc.width, rc.height, clr);
}

public void gxDrawRect (int x, int y, int w, int h, uint clr) nothrow @trusted @nogc {
  if (w < 1 || h < 1 || x >= VBufWidth || y >= VBufHeight) return;
  gxHLine(x, y, w, clr);
  gxHLine(x, y+h-1, w, clr);
  gxVLine(x, y+1, h-2, clr);
  gxVLine(x+w-1, y+1, h-2, clr);
}

public void gxDrawRect() (in auto ref GxRect rc, uint clr) nothrow @trusted @nogc {
  gxDrawRect(rc.x0, rc.y0, rc.width, rc.height, clr);
}


// ////////////////////////////////////////////////////////////////////////// //
public __gshared void delegate () gxRebuildScreenCB;

public void gxRebuildScreen () nothrow {
  if (gxRebuildScreenCB !is null) {
    gxClipReset();
    try {
      gxRebuildScreenCB();
    } catch (Exception e) {
      conwriteln("SCREEN REBUILD ERROR: ", e.msg);
    }
    gxUpdateTexture();
  }
}


// ////////////////////////////////////////////////////////////////////////// //
__gshared string ttffilename = "~/ttf/ms/verdana.ttf";
__gshared ubyte* ttfontdata;
__gshared FT_Library ftLibrary;
__gshared FT_Face ttfont;


void ttfLoad () {
  auto fl = VFile(ttffilename);
  auto fsz = fl.size;
  if (fsz < 16 || fsz > int.max/8) throw new Exception("invalid ttf size");
  import core.stdc.stdlib : malloc;
  ttfontdata = cast(ubyte*)malloc(cast(uint)fsz);
  fl.rawReadExact(ttfontdata[0..cast(uint)fsz]);

  FT_Error ftError = FT_Init_FreeType(&ftLibrary);
  if (ftError) assert(0, "can't initialize FreeType");

  ftError = FT_New_Memory_Face(ftLibrary, cast(const(FT_Byte)*)ttfontdata, cast(uint)fsz, 0, &ttfont);
  if (ftError) throw new Exception("can't load ttf");
}


float ttfGetPixelHeightScale (FT_Face ttfont, float size) {
  pragma(inline, true);
  return size/(ttfont.ascender-ttfont.descender);
}


ubyte* ttfRenderGlyphBitmap(bool mono=true) (FT_Face ttfont, int codepoint, float size, ref int advance, ref int lsb, ref int x0, ref int y0, ref int x1, ref int y1, ref int bwdt, ref int bhgt) {
  import core.stdc.stdlib : malloc;

  FT_Error ftError;
  //FT_GlyphSlot ftGlyph; // ttfont.glyph

  // load glyph
  int glyph = FT_Get_Char_Index(ttfont, codepoint);
  if (glyph == 0) return null;

  //immutable float scale = ttfGetPixelHeightScale(ttfont, size);

  static if (mono) enum exflags = FT_LOAD_MONOCHROME/*|FT_LOAD_NO_AUTOHINT*/; else enum exflags = 0/*|FT_LOAD_NO_AUTOHINT*/;
  //ftError = FT_Set_Pixel_Sizes(ttfont, 0, cast(FT_UInt)(size*cast(float)ttfont.units_per_EM/cast(float)(ttfont.ascender-ttfont.descender)));
  ftError = FT_Set_Pixel_Sizes(ttfont, 0, cast(FT_UInt)size);
  if (ftError) return null;
  ftError = FT_Load_Glyph(ttfont, glyph, FT_LOAD_RENDER|exflags);
  if (ftError) return null;
  //ftError = FT_Get_Advance(ttfont, glyph, /*FT_LOAD_NO_SCALE|*/exflags, cast(FT_Fixed*)&advance);
  //if (ftError) return null;
  //advance >>= 16; // 16.16 format
  advance = ttfont.glyph.advance.x>>6; // 26.6

  //ftGlyph = ttfont.glyph;
  lsb = cast(int)ttfont.glyph.metrics.horiBearingX;
  x0 = ttfont.glyph.bitmap_left;
  x1 = x0+ttfont.glyph.bitmap.width;
  y0 = -ttfont.glyph.bitmap_top;
  y1 = y0+ttfont.glyph.bitmap.rows;

  //conwriteln("codepoint=", codepoint, "; bwdt=", ttfont.glyph.bitmap.width, "; bhgt=", ttfont.glyph.bitmap.rows, "; fmt=", (ttfont.glyph.format == FT_GLYPH_FORMAT_BITMAP));
  bwdt = ttfont.glyph.bitmap.width;
  bhgt = ttfont.glyph.bitmap.rows;

  ubyte* output = cast(ubyte*)malloc(ttfont.glyph.bitmap.width*ttfont.glyph.bitmap.rows);
  if (output is null) return null;
  auto dst = output;
  auto src = ttfont.glyph.bitmap.buffer;
  auto spt = ttfont.glyph.bitmap.pitch;
  if (spt < 0) spt = -spt;
  static if (mono) {
    foreach (immutable int y; 0..ttfont.glyph.bitmap.rows) {
      ubyte count = 0, b = 0;
      auto s = src;
      foreach (immutable int x; 0..ttfont.glyph.bitmap.width) {
        if (count-- == 0) { count = 7; b = *s++; } else b <<= 1;
        *dst++ = (b&0x80 ? 255 : 0);
      }
      src += spt;
    }
  } else {
    foreach (int y; 0..ttfont.glyph.bitmap.rows) {
      import core.stdc.string : memcpy;
      memcpy(dst, src, ttfont.glyph.bitmap.width);
      src += spt;
      dst += ttfont.glyph.bitmap.width;
    }
  }

  return output;
}


float ttfGetGlyphKernAdvance (FT_Face ttfont, int cp0, int cp1) {
  // unfitted kerning
  if (cp0 < 0) return 0;
  int glyph1 = FT_Get_Char_Index(ttfont, cp0);
  int glyph2 = FT_Get_Char_Index(ttfont, cp1);
  FT_Vector ftKerning;
  FT_Get_Kerning(ttfont, glyph1, glyph2, FT_KERNING_UNFITTED, &ftKerning);
  return ftKerning.x/64.0f;
}


// ////////////////////////////////////////////////////////////////////////// //
void ttfDrawTextUtf (int x, int y, const(char)[] str, uint fg) {
  fg &= 0xff_ff_ffU;
  Utf8DecoderFast ud;
  int prevcp = -1;
  enum FontHeight = 12;
  immutable float scale = ttfGetPixelHeightScale(ttfont, FontHeight);
  foreach (char ch; str) {
    if (ud.decode(cast(ubyte)ch)) {
      int dc = (ud.complete ? ud.codepoint : ud.replacement);
      int advance, lsb, x0, y0, x1, y1, bwdt, bhgt;
      auto bmp = ttfRenderGlyphBitmap!true(ttfont, dc, FontHeight, ref advance, ref lsb, ref x0, ref y0, ref x1, ref y1, ref bwdt, ref bhgt);
      if (bmp !is null) {
        auto kadv = ttfGetGlyphKernAdvance(ttfont, prevcp, dc);
        //conwriteln("dc=", dc, "; advance=", advance, "; lsb=", lsb, "; x0=", x0, "; y0=", y0, "; x1=", x1, "; y1=", y1, "; kadv=", kadv);
        prevcp = dc;
        x += cast(int)(kadv*scale);
        import core.stdc.stdlib : free;
        scope(exit) free(bmp);
        foreach (immutable dy; 0..bhgt) {
          foreach (immutable dx; 0..bwdt) {
            immutable ubyte v = cast(ubyte)(255-bmp[dy*bwdt+dx]);
            gxPutPixel(x+x0+dx, y+y0+dy, fg|(v<<24));
          }
        }
        x += advance;
      }
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
void main (string[] args) {
  conRegVar!ttffilename("ttf_file", "ttf font file name");

  sdpyWindowClass = "SDPY WINDOW";
  glconShowKey = "M-Grave";

  conProcessQueue(); // load config
  conProcessArgs!true(args);

  ttfLoad();

  gxRebuildScreenCB = delegate () {
    gxClearScreen(gxRGB!(0, 0, 0));
    gxDrawRect(10, 10, VBufWidth-20, VBufHeight-20, gxRGB!(255, 127, 0));
    ttfDrawTextUtf(100, 100, "Hello, пизда!", gxRGB!(255, 255, 0));
  };

  auto sdwin = new SimpleWindow(VBufWidth, VBufHeight, "My D App", OpenGlOptions.yes, Resizability.allowResizing);
  glconCtlWindow = sdwin;
  glconDrawWindow = sdwin;
  //sdwin.hideCursor();

  static if (is(typeof(&sdwin.closeQuery))) {
    sdwin.closeQuery = delegate () { concmd("quit"); glconPostDoConCommands(); };
  }

  sdwin.addEventListener((GLConScreenRepaintEvent evt) {
    if (sdwin.closed) return;
    if (isQuitRequested) { sdwin.close(); return; }
    gxRebuildScreen();
    sdwin.redrawOpenGlSceneNow();
  });

  sdwin.addEventListener((GLConDoConsoleCommandsEvent evt) { glconProcessEventMessage(); });

  sdwin.windowResized = delegate (int wdt, int hgt) {
    if (sdwin.closed) return;
    glconResize(wdt, hgt);
    gxResize(wdt, hgt);
    //glconPostScreenRebuild();
    gxRebuildScreen();
  };

  sdwin.redrawOpenGlScene = delegate () {
    if (sdwin.closed) return;

    {
      consoleLock();
      scope(exit) consoleUnlock();
      if (!conQueueEmpty()) glconPostDoConCommands();
    }

    // draw main screen
    /*
    glClearColor(0, 0, 0, 0);
    glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT|GL_ACCUM_BUFFER_BIT|GL_STENCIL_BUFFER_BIT);
    glViewport(0, 0, sdwin.width, sdwin.height);
    */
    gxBlitTexture();
    glconDraw();

    //if (isQuitRequested()) sdwin.glconPostEvent(new QuitEvent());
  };

  sdwin.visibleForTheFirstTime = delegate () {
    sdwin.setAsCurrentOpenGlContext();
    glconInit(sdwin.width, sdwin.height);
    gxResize(sdwin.width, sdwin.height);
    gxRebuildScreen();
    sdwin.redrawOpenGlSceneNow();
  };

  sdwin.eventLoop(0,
    delegate () {
      scope(exit) if (!conQueueEmpty()) glconPostDoConCommands();
      if (sdwin.closed) return;
      if (isQuitRequested) { sdwin.close(); return; }
    },
    delegate (KeyEvent event) {
      scope(exit) if (!conQueueEmpty()) glconPostDoConCommands();
      if (sdwin.closed) return;
      if (isQuitRequested) { sdwin.close(); return; }
      if (glconKeyEvent(event)) { glconPostScreenRepaint(); return; }
      if (event.pressed && event == "Escape") { concmd("quit"); return; }
    },
    delegate (MouseEvent event) {
      scope(exit) if (!conQueueEmpty()) glconPostDoConCommands();
      if (sdwin.closed) return;
    },
    delegate (dchar ch) {
      if (sdwin.closed) return;
      scope(exit) if (!conQueueEmpty()) glconPostDoConCommands();
      if (glconCharEvent(ch)) { glconPostScreenRepaint(); return; }
    },
  );
  flushGui();
  conProcessQueue(int.max/4);
}
