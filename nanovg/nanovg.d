//
// Copyright (c) 2013 Mikko Mononen memon@inside.org
//
// This software is provided 'as-is', without any express or implied
// warranty.  In no event will the authors be held liable for any damages
// arising from the use of this software.
// Permission is granted to anyone to use this software for any purpose,
// including commercial applications, and to alter it and redistribute it
// freely, subject to the following restrictions:
// 1. The origin of this software must not be misrepresented; you must not
//    claim that you wrote the original software. If you use this software
//    in a product, an acknowledgment in the product documentation would be
//    appreciated but is not required.
// 2. Altered source versions must be plainly marked as such, and must not be
//    misrepresented as being the original software.
// 3. This notice may not be removed or altered from any source distribution.
//
/* Invisible Vector Library
 * ported by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * Understanding is not required. Only obedience.
 * yes, this D port is GPLed.
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
module iv.nanovg.nanovg;

//version = nanosvg_asserts;


// ////////////////////////////////////////////////////////////////////////// //
// engine
// ////////////////////////////////////////////////////////////////////////// //
import core.stdc.stdlib : malloc, realloc, free;
import core.stdc.string : memset, memcpy, strlen;
import std.math : PI;
//import iv.nanovg.fontstash;

public:
alias NVG_PI = PI;

version = nanovg_use_arsd_image;

version(nanovg_use_arsd_image) {
  import arsd.color;
  static if (__traits(compiles, {import arsd.png;})) import arsd.png;
  static if (__traits(compiles, {import arsd.jpeg;})) import arsd.jpeg;
} else {
  void stbi_set_unpremultiply_on_load (int flag_true_if_should_unpremultiply) {}
  void stbi_convert_iphone_png_to_rgb (int flag_true_if_should_convert) {}
  ubyte* stbi_load (const(char)* filename, int* x, int* y, int* comp, int req_comp) { return null; }
  ubyte* stbi_load_from_memory (const(void)* buffer, int len, int* x, int* y, int* comp, int req_comp) { return null; }
  void stbi_image_free (void* retval_from_stbi_load) {}
}


///
align(1) struct NVGColor {
align(1):
public:
  float[4] rgba = 0; // default color is transparent

public:
  @property string toString () const @safe { import std.string : format; return "NVGColor(%s,%s,%s,%s)".format(r, g, b, a); }

nothrow @safe @nogc:
public:
  this (ubyte ar, ubyte ag, ubyte ab, ubyte aa=255) pure {
    pragma(inline, true);
    r = ar/255.0f;
    g = ag/255.0f;
    b = ab/255.0f;
    a = aa/255.0f;
  }

  this (float ar, float ag, float ab, float aa=1) pure {
    pragma(inline, true);
    r = ar;
    g = ag;
    b = ab;
    a = aa;
  }

  // AABBGGRR (same format as little-endian RGBA image, coincidentally, the same as arsd.color)
  this (uint c) pure {
    pragma(inline, true);
    r = (c&0xff)/255.0f;
    g = ((c>>8)&0xff)/255.0f;
    b = ((c>>16)&0xff)/255.0f;
    a = ((c>>24)&0xff)/255.0f;
  }

  // AABBGGRR (same format as little-endian RGBA image, coincidentally, the same as arsd.color)
  @property uint asUint () const pure {
    pragma(inline, true);
    return
      cast(uint)(r*255)|
      (cast(uint)(g*255)<<8)|
      (cast(uint)(b*255)<<16)|
      (cast(uint)(a*255)<<24);
  }

  // AABBGGRR (same format as little-endian RGBA image, coincidentally, the same as arsd.color)
  @property uint asUintHtml () const pure {
    pragma(inline, true);
    return
      cast(uint)(b*255)|
      (cast(uint)(g*255)<<8)|
      (cast(uint)(r*255)<<16)|
      (cast(uint)(a*255)<<24);
  }

  static NVGColor fromHtml (uint c) pure {
    pragma(inline, true);
    return NVGColor((c>>16)&0xff, (c>>8)&0xff, c&0xff, (c>>24)&0xff);
  }

  @property ref inout(float) r () inout pure @trusted { pragma(inline, true); return rgba.ptr[0]; }
  @property ref inout(float) g () inout pure @trusted { pragma(inline, true); return rgba.ptr[1]; }
  @property ref inout(float) b () inout pure @trusted { pragma(inline, true); return rgba.ptr[2]; }
  @property ref inout(float) a () inout pure @trusted { pragma(inline, true); return rgba.ptr[3]; }

  NVGHSL asHSL() (bool useWeightedLightness=false) const { /*pragma(inline, true);*/ return NVGHSL.fromColor(this, useWeightedLightness); }
  static fromHSL() (in auto ref NVGHSL hsl) { /*pragma(inline, true);*/ return hsl.asColor; }

  version(nanovg_use_arsd_image) {
    Color toArsd () const { /*pragma(inline, true);*/ return Color(cast(int)(r*255), cast(int)(g*255), cast(int)(b*255), cast(int)(a*255)); }
    static NVGColor fromArsd() (in auto ref Color c) const { /*pragma(inline, true);*/ return NVGColor(c.r, c.g, c.b, c.a); }
  }
}


align(1) struct NVGHSL {
align(1):
  float h=0, s=0, l=1, a=1;

  string toString () const { import std.format : format; return (a != 1 ? "HSL(%s,%s,%s,%d)".format(h, s, l, a) : "HSL(%s,%s,%s)".format(h, s, l)); }

nothrow @safe @nogc:
public:
  this (float ah, float as, float al, float aa=1) pure { pragma(inline, true); h = ah; s = as; l = al; a = aa; }

  NVGColor asColor () const { /*pragma(inline, true);*/ return nvgHSLA(h, s, l, a); }

  // taken from Adam's arsd.color
  /** Converts an RGB color into an HSL triplet.
   * `useWeightedLightness` will try to get a better value for luminosity for the human eye,
   * which is more sensitive to green than red and more to red than blue.
   * If it is false, it just does average of the rgb. */
  static NVGHSL fromColor() (in auto ref NVGColor c, bool useWeightedLightness=false) pure {
    NVGHSL res;
    res.a = c.a;
    float r1 = c.r;
    float g1 = c.g;
    float b1 = c.b;

    float maxColor = r1;
    if (g1 > maxColor) maxColor = g1;
    if (b1 > maxColor) maxColor = b1;
    float minColor = r1;
    if (g1 < minColor) minColor = g1;
    if (b1 < minColor) minColor = b1;

    res.l = (maxColor+minColor)/2;
    if (useWeightedLightness) {
      // the colors don't affect the eye equally
      // this is a little more accurate than plain HSL numbers
      res.l = 0.2126*r1+0.7152*g1+0.0722*b1;
    }
    //res.s = 0;
    //res.h = 0;
    if (maxColor != minColor) {
      if (res.l < 0.5) {
        res.s = (maxColor-minColor)/(maxColor+minColor);
      } else {
        res.s = (maxColor-minColor)/(2.0-maxColor-minColor);
      }
      if (r1 == maxColor) {
        res.h = (g1-b1)/(maxColor-minColor);
      } else if(g1 == maxColor) {
        res.h = 2.0+(b1-r1)/(maxColor-minColor);
      } else {
        res.h = 4.0+(r1-g1)/(maxColor-minColor);
      }
    }

    res.h = res.h*60;
    if (res.h < 0) res.h += 360;
    res.h /= 360;

    return res;
  }
}


///
struct NVGPaint {
  float[6] xform;
  float[2] extent;
  float radius;
  float feather;
  NVGColor innerColor;
  NVGColor outerColor;
  int image;
}

///
enum NVGWinding {
  CCW = 1, /// Winding for solid shapes
  CW = 2,  /// Winding for holes
}

///
enum NVGSolidity {
  Solid = 1, /// CCW
  Hole = 2, /// CW
}

///
enum NVGLineCap {
  Butt, ///
  Round, ///
  Square, ///
  Bevel, ///
  Miter, ///
}

/// Text align.
align(1) struct NVGTextAlign {
align(1):
  /// Horizontal align.
  enum H : ubyte {
    Left     = 0, /// Default, align text horizontally to left.
    Center   = 1, /// Align text horizontally to center.
    Right    = 2, /// Align text horizontally to right.
  }

  /// Vertical align.
  enum V : ubyte {
    Baseline = 0, /// Default, align text vertically to baseline.
    Top      = 1, /// Align text vertically to top.
    Middle   = 2, /// Align text vertically to middle.
    Bottom   = 3, /// Align text vertically to bottom.
  }

pure nothrow @safe @nogc:
public:
  this (H h) { pragma(inline, true); value = h; }
  this (V v) { pragma(inline, true); value = cast(ubyte)(v<<4); }
  this (H h, V v) { pragma(inline, true); value = cast(ubyte)(h|(v<<4)); }
  this (V v, H h) { pragma(inline, true); value = cast(ubyte)(h|(v<<4)); }
  void reset () { pragma(inline, true); value = 0; }
  void reset (H h, V v) { pragma(inline, true); value = cast(ubyte)(h|(v<<4)); }
  void reset (V v, H h) { pragma(inline, true); value = cast(ubyte)(h|(v<<4)); }
@property:
  bool left () const { pragma(inline, true); return ((value&0x0f) == H.Left); } ///
  void left (bool v) { pragma(inline, true); value = cast(ubyte)((value&0xf0)|(v ? H.Left : 0)); } ///
  bool center () const { pragma(inline, true); return ((value&0x0f) == H.Center); } ///
  void center (bool v) { pragma(inline, true); value = cast(ubyte)((value&0xf0)|(v ? H.Center : 0)); } ///
  bool right () const { pragma(inline, true); return ((value&0x0f) == H.Right); } ///
  void right (bool v) { pragma(inline, true); value = cast(ubyte)((value&0xf0)|(v ? H.Right : 0)); } ///
  //
  bool baseline () const { pragma(inline, true); return (((value>>4)&0x0f) == V.Baseline); } ///
  void baseline (bool v) { pragma(inline, true); value = cast(ubyte)((value&0x0f)|(v ? V.Baseline<<4 : 0)); } ///
  bool top () const { pragma(inline, true); return (((value>>4)&0x0f) == V.Top); } ///
  void top (bool v) { pragma(inline, true); value = cast(ubyte)((value&0x0f)|(v ? V.Top<<4 : 0)); } ///
  bool middle () const { pragma(inline, true); return (((value>>4)&0x0f) == V.Middle); } ///
  void middle (bool v) { pragma(inline, true); value = cast(ubyte)((value&0x0f)|(v ? V.Middle<<4 : 0)); } ///
  bool bottom () const { pragma(inline, true); return (((value>>4)&0x0f) == V.Bottom); } ///
  void bottom (bool v) { pragma(inline, true); value = cast(ubyte)((value&0x0f)|(v ? V.Bottom<<4 : 0)); } ///
  //
  H horizontal () const { pragma(inline, true); return cast(H)(value&0x0f); } ///
  void horizontal (H v) { pragma(inline, true); value = (value&0xf0)|v; } ///
  //
  V vertical () const { pragma(inline, true); return cast(V)((value>>4)&0x0f); } ///
  void vertical (V v) { pragma(inline, true); value = (value&0x0f)|cast(ubyte)(v<<4); } ///
  //
private:
  ubyte value = 0; // low nibble: horizontal; high nibble: vertical
}

///
struct NVGGlyphPosition {
  size_t strpos;    /// Position of the glyph in the input string.
  float x;          /// The x-coordinate of the logical glyph position.
  float minx, maxx; /// The bounds of the glyph shape.
}

///
struct NVGTextRow {
  const(char)[] str;
  const(dchar)[] dstr;
  int start;        /// Index in the input text where the row starts.
  int end;          /// Index in the input text where the row ends (one past the last character).
  float width;      /// Logical width of the row.
  float minx, maxx; /// Actual bounds of the row. Logical with and bounds can differ because of kerning and some parts over extending.
  @property bool isChar () const pure nothrow @trusted @nogc { pragma(inline, true); return (str.ptr !is null); } /// Is this char or dchar row?
  /// Get rest of the string.
  @property const(T)[] rest(T) () const pure nothrow @trusted @nogc if (is(T == char) || is(T == dchar)) {
    pragma(inline, true);
    static if (is(T == char)) return (end <= str.length ? str[end..$] : null);
    else return (end <= dstr.length ? dstr[end..$] : null);
  }
  /// Get current row.
  @property const(T)[] row(T) () const pure nothrow @trusted @nogc if (is(T == char) || is(T == dchar)) {
    pragma(inline, true);
    static if (is(T == char)) return str[start..end]; else return dstr[start..end];
  }
  @property const(T)[] string(T) () const pure nothrow @trusted @nogc if (is(T == char) || is(T == dchar)) {
    pragma(inline, true);
    static if (is(T == char)) return str; else return dstr;
  }
  @property void string(T) (const(T)[] v) pure nothrow @trusted @nogc if (is(T == char) || is(T == dchar)) {
    pragma(inline, true);
    static if (is(T == char)) str = v; else dstr = v;
  }
}

///
enum NVGImageFlags {
  None            =    0, /// Nothing special.
  GenerateMipmaps = 1<<0, /// Generate mipmaps during creation of the image.
  RepeatX         = 1<<1, /// Repeat image in X direction.
  RepeatY         = 1<<2, /// Repeat image in Y direction.
  FlipY           = 1<<3, /// Flips (inverses) image in Y direction when rendered.
  Premultiplied   = 1<<4, /// Image data has premultiplied alpha.
}

// ////////////////////////////////////////////////////////////////////////// //
package/*(iv.nanovg)*/:

// Internal Render API
enum NVGtexture {
  Alpha = 0x01,
  RGBA  = 0x02,
}

struct NVGscissor {
  float[6] xform;
  float[2] extent;
}

struct NVGvertex {
  float x, y, u, v;
}

struct NVGpath {
  int first;
  int count;
  ubyte closed;
  int nbevel;
  NVGvertex* fill;
  int nfill;
  NVGvertex* stroke;
  int nstroke;
  NVGWinding winding;
  int convex;
}

struct NVGparams {
  void* userPtr;
  bool edgeAntiAlias;
  bool function (void* uptr) renderCreate;
  int function (void* uptr, NVGtexture type, int w, int h, int imageFlags, const(ubyte)* data) renderCreateTexture;
  bool function (void* uptr, int image) renderDeleteTexture;
  bool function (void* uptr, int image, int x, int y, int w, int h, const(ubyte)* data) renderUpdateTexture;
  bool function (void* uptr, int image, int* w, int* h) renderGetTextureSize;
  void function (void* uptr, int width, int height) renderViewport;
  void function (void* uptr) renderCancel;
  void function (void* uptr) renderFlush;
  void function (void* uptr, NVGPaint* paint, NVGscissor* scissor, float fringe, const(float)* bounds, const(NVGpath)* paths, int npaths) renderFill;
  void function (void* uptr, NVGPaint* paint, NVGscissor* scissor, float fringe, float strokeWidth, const(NVGpath)* paths, int npaths) renderStroke;
  void function (void* uptr, NVGPaint* paint, NVGscissor* scissor, const(NVGvertex)* verts, int nverts) renderTriangles;
  void function (void* uptr) renderDelete;
}

// ////////////////////////////////////////////////////////////////////////// //
private:

enum NVG_INIT_FONTIMAGE_SIZE = 512;
enum NVG_MAX_FONTIMAGE_SIZE  = 2048;
enum NVG_MAX_FONTIMAGES      = 4;

enum NVG_INIT_COMMANDS_SIZE = 256;
enum NVG_INIT_POINTS_SIZE   = 128;
enum NVG_INIT_PATHS_SIZE    = 16;
enum NVG_INIT_VERTS_SIZE    = 256;
enum NVG_MAX_STATES         = 32;

enum NVG_KAPPA90 = 0.5522847493f; // Length proportional to radius of a cubic bezier handle for 90deg arcs.

enum NVGcommands : int {
  MoveTo = 0,
  LineTo = 1,
  BezierTo = 2,
  Close = 3,
  Winding = 4,
}

enum NVGpointFlags : int {
  Corner = 0x01,
  Left = 0x02,
  Bevel = 0x04,
  InnerBevelPR = 0x08,
}

struct NVGstate {
  NVGPaint fill;
  NVGPaint stroke;
  float strokeWidth;
  float miterLimit;
  NVGLineCap lineJoin;
  NVGLineCap lineCap;
  float alpha;
  float[6] xform;
  NVGscissor scissor;
  float fontSize;
  float letterSpacing;
  float lineHeight;
  float fontBlur;
  NVGTextAlign textAlign;
  int fontId;
}

struct NVGpoint {
  float x, y;
  float dx, dy;
  float len;
  float dmx, dmy;
  ubyte flags;
}

struct NVGpathCache {
  NVGpoint* points;
  int npoints;
  int cpoints;
  NVGpath* paths;
  int npaths;
  int cpaths;
  NVGvertex* verts;
  int nverts;
  int cverts;
  float[4] bounds;
}

/// pointer to opaque NanoVG context structure.
public alias NVGContext = NVGcontext*;

/// Returns FontStash context of the given NanoVG context.
FONScontext* fonsContext (NVGContext ctx) { return (ctx !is null ? ctx.fs : null); }

private struct NVGcontext {
  NVGparams params;
  float* commands;
  int ccommands;
  int ncommands;
  float commandx, commandy;
  NVGstate[NVG_MAX_STATES] states;
  int nstates;
  NVGpathCache* cache;
  float tessTol;
  float distTol;
  float fringeWidth;
  float devicePxRatio;
  FONScontext* fs;
  int[NVG_MAX_FONTIMAGES] fontImages;
  int fontImageIdx;
  int drawCallCount;
  int fillTriCount;
  int strokeTriCount;
  int textTriCount;
}

import core.stdc.math :
  nvg__sqrtf = sqrtf,
  nvg__modf = fmodf,
  nvg__sinf = sinf,
  nvg__cosf = cosf,
  nvg__tanf = tanf,
  nvg__atan2f = atan2f,
  nvg__acosf = acosf,
  nvg__ceilf = ceilf;

auto nvg__min(T) (T a, T b) { pragma(inline, true); return (a < b ? a : b); }
auto nvg__max(T) (T a, T b) { pragma(inline, true); return (a > b ? a : b); }
auto nvg__clamp(T) (T a, T mn, T mx) { pragma(inline, true); return (a < mn ? mn : (a > mx ? mx : a)); }
//float nvg__absf() (float a) { pragma(inline, true); return (a >= 0.0f ? a : -a); }
auto nvg__sign(T) (T a) { pragma(inline, true); return (a >= cast(T)0 ? cast(T)1 : cast(T)(-1)); }
float nvg__cross() (float dx0, float dy0, float dx1, float dy1) { pragma(inline, true); return (dx1*dy0-dx0*dy1); }

private import core.stdc.math : nvg__absf = fabsf;


float nvg__normalize (float* x, float* y) {
  float d = nvg__sqrtf((*x)*(*x)+(*y)*(*y));
  if (d > 1e-6f) {
    immutable float id = 1.0f/d;
    *x *= id;
    *y *= id;
  }
  return d;
}


void nvg__deletePathCache (NVGpathCache* c) {
  if (c is null) return;
  if (c.points !is null) free(c.points);
  if (c.paths !is null) free(c.paths);
  if (c.verts !is null) free(c.verts);
  free(c);
}


NVGpathCache* nvg__allocPathCache () {
  NVGpathCache* c = cast(NVGpathCache*)malloc(NVGpathCache.sizeof);
  if (c is null) goto error;
  memset(c, 0, NVGpathCache.sizeof);

  c.points = cast(NVGpoint*)malloc(NVGpoint.sizeof*NVG_INIT_POINTS_SIZE);
  if (c.points is null) goto error;
  c.npoints = 0;
  c.cpoints = NVG_INIT_POINTS_SIZE;

  c.paths = cast(NVGpath*)malloc(NVGpath.sizeof*NVG_INIT_PATHS_SIZE);
  if (c.paths is null) goto error;
  c.npaths = 0;
  c.cpaths = NVG_INIT_PATHS_SIZE;

  c.verts = cast(NVGvertex*)malloc((NVGvertex).sizeof*NVG_INIT_VERTS_SIZE);
  if (c.verts is null) goto error;
  c.nverts = 0;
  c.cverts = NVG_INIT_VERTS_SIZE;

  return c;
error:
  nvg__deletePathCache(c);
  return null;
}

void nvg__setDevicePixelRatio (NVGContext ctx, float ratio) {
  ctx.tessTol = 0.25f/ratio;
  ctx.distTol = 0.01f/ratio;
  ctx.fringeWidth = 1.0f/ratio;
  ctx.devicePxRatio = ratio;
}

// Constructor called by the render back-end.
package/*(iv.nanovg)*/ NVGContext createInternal (NVGparams* params) {
  FONSparams fontParams;
  NVGContext ctx = cast(NVGContext)malloc(NVGcontext.sizeof);
  if (ctx is null) goto error;
  memset(ctx, 0, NVGcontext.sizeof);

  ctx.params = *params;
  ctx.fontImages[0..NVG_MAX_FONTIMAGES] = 0;

  ctx.commands = cast(float*)malloc(float.sizeof*NVG_INIT_COMMANDS_SIZE);
  if (ctx.commands is null) goto error;
  ctx.ncommands = 0;
  ctx.ccommands = NVG_INIT_COMMANDS_SIZE;

  ctx.cache = nvg__allocPathCache();
  if (ctx.cache is null) goto error;

  ctx.save();
  ctx.reset();

  nvg__setDevicePixelRatio(ctx, 1.0f);

  if (!ctx.params.renderCreate(ctx.params.userPtr)) goto error;

  // Init font rendering
  memset(&fontParams, 0, fontParams.sizeof);
  fontParams.width = NVG_INIT_FONTIMAGE_SIZE;
  fontParams.height = NVG_INIT_FONTIMAGE_SIZE;
  fontParams.flags = FONS_ZERO_TOPLEFT;
  fontParams.renderCreate = null;
  fontParams.renderUpdate = null;
  fontParams.renderDraw = null;
  fontParams.renderDelete = null;
  fontParams.userPtr = null;
  ctx.fs = fonsCreateInternal(&fontParams);
  if (ctx.fs is null) goto error;

  // Create font texture
  ctx.fontImages[0] = ctx.params.renderCreateTexture(ctx.params.userPtr, NVGtexture.Alpha, fontParams.width, fontParams.height, 0, null);
  if (ctx.fontImages[0] == 0) goto error;
  ctx.fontImageIdx = 0;

  return ctx;

error:
  ctx.deleteInternal();
  return null;
}

// Called by render backend.
package/*(iv.nanovg)*/ NVGparams* internalParams (NVGContext ctx) {
  return &ctx.params;
}

// Destructor called by the render back-end.
package/*(iv.nanovg)*/ void deleteInternal (NVGContext ctx) {
  if (ctx is null) return;
  if (ctx.commands !is null) free(ctx.commands);
  if (ctx.cache !is null) nvg__deletePathCache(ctx.cache);

  if (ctx.fs) fonsDeleteInternal(ctx.fs);

  foreach (uint i; 0..NVG_MAX_FONTIMAGES) {
    if (ctx.fontImages[i] != 0) {
      ctx.deleteImage(ctx.fontImages[i]);
      ctx.fontImages[i] = 0;
    }
  }

  if (ctx.params.renderDelete !is null) ctx.params.renderDelete(ctx.params.userPtr);

  free(ctx);
}

/** Begin drawing a new frame
 *
 * Calls to nanovg drawing API should be wrapped in `beginFrame()` and `endFrame()`
 *
 * `beginFrame()` defines the size of the window to render to in relation currently
 * set viewport (i.e. glViewport on GL backends). Device pixel ration allows to
 * control the rendering on Hi-DPI devices.
 *
 * For example, GLFW returns two dimension for an opened window: window size and
 * frame buffer size. In that case you would set windowWidth/windowHeight to the window size,
 * devicePixelRatio to: `windowWidth/windowHeight`.
 *
 * see also `glNVGClearFlags()`, which returns necessary flags for `glClear()`.
 */
public void beginFrame (NVGContext ctx, int windowWidth, int windowHeight, float devicePixelRatio=float.nan) {
  import std.math : isNaN;
  /*
  printf("Tris: draws:%d  fill:%d  stroke:%d  text:%d  TOT:%d\n",
         ctx.drawCallCount, ctx.fillTriCount, ctx.strokeTriCount, ctx.textTriCount,
         ctx.fillTriCount+ctx.strokeTriCount+ctx.textTriCount);
  */

  if (isNaN(devicePixelRatio)) devicePixelRatio = (windowHeight > 0 ? cast(float)windowWidth/cast(float)windowHeight : 1024.0/768.0);

  ctx.nstates = 0;
  ctx.save();
  ctx.reset();

  nvg__setDevicePixelRatio(ctx, devicePixelRatio);

  ctx.params.renderViewport(ctx.params.userPtr, windowWidth, windowHeight);

  ctx.drawCallCount = 0;
  ctx.fillTriCount = 0;
  ctx.strokeTriCount = 0;
  ctx.textTriCount = 0;
}

/// Cancels drawing the current frame.
public void cancelFrame (NVGContext ctx) {
  ctx.params.renderCancel(ctx.params.userPtr);
}

/// Ends drawing flushing remaining render state.
public void endFrame (NVGContext ctx) {
  ctx.params.renderFlush(ctx.params.userPtr);
  if (ctx.fontImageIdx != 0) {
    int fontImage = ctx.fontImages[ctx.fontImageIdx];
    int j, iw, ih;
    // delete images that smaller than current one
    if (fontImage == 0) return;
    ctx.imageSize(fontImage, &iw, &ih);
    foreach (int i; 0..ctx.fontImageIdx) {
      if (ctx.fontImages[i] != 0) {
        int nw, nh;
        ctx.imageSize(ctx.fontImages[i], &nw, &nh);
        if (nw < iw || nh < ih) {
          ctx.deleteImage(ctx.fontImages[i]);
        } else {
          ctx.fontImages[j++] = ctx.fontImages[i];
        }
      }
    }
    // make current font image to first
    ctx.fontImages[j++] = ctx.fontImages[0];
    ctx.fontImages[0] = fontImage;
    ctx.fontImageIdx = 0;
    // clear all images after j
    ctx.fontImages[j..NVG_MAX_FONTIMAGES] = 0;
  }
}

// ////////////////////////////////////////////////////////////////////////// //
/// <h1>Color utils</h1>
/// Colors in NanoVG are stored as unsigned ints in ABGR format.
public alias NVGSectionDummy00 = void;

/// Returns a color value from red, green, blue values. Alpha will be set to 255 (1.0f).
public NVGColor nvgRGB() (ubyte r, ubyte g, ubyte b) {
  pragma(inline, true);
  return NVGColor(r, g, b, 255);
}

/// Returns a color value from red, green, blue values. Alpha will be set to 1.0f.
public NVGColor nvgRGBf() (float r, float g, float b) {
  pragma(inline, true);
  return NVGColor(r, g, b, 1.0f);
}

/// Returns a color value from red, green, blue and alpha values.
public NVGColor nvgRGBA() (ubyte r, ubyte g, ubyte b, ubyte a=255) @trusted {
  pragma(inline, true);
  return NVGColor(r, g, b, a);
}

/// Returns a color value from red, green, blue and alpha values.
public NVGColor nvgRGBAf() (float r, float g, float b, float a=1) {
  pragma(inline, true);
  return NVGColor(r, g, b, a);
}

/// Sets transparency of a color value.
public NVGColor nvgTransRGBA() (NVGColor c, ubyte a) {
  pragma(inline, true);
  c.a = a/255.0f;
  return c;
}

/// Sets transparency of a color value.
public NVGColor nvgTransRGBAf() (NVGColor c, float a) {
  pragma(inline, true);
  c.a = a;
  return c;
}

/// Linearly interpolates from color c0 to c1, and returns resulting color value.
public NVGColor nvgLerpRGBA() (in auto ref NVGColor c0, in auto ref NVGColor c1, float u) {
  NVGColor cint = void;
  u = nvg__clamp(u, 0.0f, 1.0f);
  float oneminu = 1.0f-u;
  foreach (uint i; 0..4) cint.rgba.ptr[i] = c0.rgba.ptr[i]*oneminu+c1.rgba.ptr[i]*u;
  return cint;
}

/* see below
public NVGColor nvgHSL() (float h, float s, float l) {
  //pragma(inline, true); // alas
  return nvgHSLA(h, s, l, 255);
}
*/

float nvg__hue() (float h, float m1, float m2) {
  if (h < 0) h += 1;
  if (h > 1) h -= 1;
  if (h < 1.0f/6.0f) return m1+(m2-m1)*h*6.0f;
  if (h < 3.0f/6.0f) return m2;
  if (h < 4.0f/6.0f) return m1+(m2-m1)*(2.0f/3.0f-h)*6.0f;
  return m1;
}

/// Returns color value specified by hue, saturation and lightness.
/// HSL values are all in range [0..1], alpha will be set to 255.
public alias nvgHSL = nvgHSLA; // trick to allow inlining

/// Returns color value specified by hue, saturation and lightness and alpha.
/// HSL values are all in range [0..1], alpha in range [0..255]
public NVGColor nvgHSLA() (float h, float s, float l, ubyte a=255) {
  static if (__VERSION__ >= 2072) pragma(inline, true);
  //float m1, m2;
  NVGColor col = void;
  h = nvg__modf(h, 1.0f);
  if (h < 0.0f) h += 1.0f;
  s = nvg__clamp(s, 0.0f, 1.0f);
  l = nvg__clamp(l, 0.0f, 1.0f);
  immutable float m2 = (l <= 0.5f ? l*(1+s) : l+s-l*s);
  immutable float m1 = 2*l-m2;
  col.r = nvg__clamp(nvg__hue(h+1.0f/3.0f, m1, m2), 0.0f, 1.0f);
  col.g = nvg__clamp(nvg__hue(h, m1, m2), 0.0f, 1.0f);
  col.b = nvg__clamp(nvg__hue(h-1.0f/3.0f, m1, m2), 0.0f, 1.0f);
  col.a = a/255.0f;
  return col;
}

/// Ditto.
public NVGColor nvgHSLA() (float h, float s, float l, float a) {
  // sorry for copypasta, it is for inliner
  static if (__VERSION__ >= 2072) pragma(inline, true);
  //float m1, m2;
  NVGColor col = void;
  h = nvg__modf(h, 1.0f);
  if (h < 0.0f) h += 1.0f;
  s = nvg__clamp(s, 0.0f, 1.0f);
  l = nvg__clamp(l, 0.0f, 1.0f);
  immutable m2 = (l <= 0.5f ? l*(1+s) : l+s-l*s);
  immutable m1 = 2*l-m2;
  col.r = nvg__clamp(nvg__hue(h+1.0f/3.0f, m1, m2), 0.0f, 1.0f);
  col.g = nvg__clamp(nvg__hue(h, m1, m2), 0.0f, 1.0f);
  col.b = nvg__clamp(nvg__hue(h-1.0f/3.0f, m1, m2), 0.0f, 1.0f);
  col.a = a;
  return col;
}


NVGstate* nvg__getState (NVGContext ctx) {
  //pragma(inline, true);
  return &ctx.states[ctx.nstates-1];
}

// ////////////////////////////////////////////////////////////////////////// //
/// <h1>Transforms</h1>
//
/** The paths, gradients, patterns and scissor region are transformed by an transformation
 * matrix at the time when they are passed to the API.
 * The current transformation matrix is a affine matrix:
 *
 * ----------------------
 *   [sx kx tx]
 *   [ky sy ty]
 *   [ 0  0  1]
 * ----------------------
 *
 * Where: (sx, sy) define scaling, (kx, ky) skewing, and (tx, ty) translation.
 * The last row is assumed to be (0, 0, 1) and is not stored.
 *
 * Apart from `resetTransform()`, each transformation function first creates
 * specific transformation matrix and pre-multiplies the current transformation by it.
 *
 * Current coordinate system (transformation) can be saved and restored using `save()` and `restore()`.
 *
 * The following functions can be used to make calculations on 2x3 transformation matrices.
 * A 2x3 matrix is represented as float[6].
 */
public alias NVGSectionDummy01 = void;

/// Sets the transform to identity matrix.
public void nvgTransformIdentity (float[] t) {
  pragma(inline, true);
  version(nanosvg_asserts) assert(t.length > 5);
  t.ptr[0] = 1.0f; t.ptr[1] = 0.0f;
  t.ptr[2] = 0.0f; t.ptr[3] = 1.0f;
  t.ptr[4] = 0.0f; t.ptr[5] = 0.0f;
}

/// Sets the transform to translation matrix matrix.
public void nvgTransformTranslate (float[] t, float tx, float ty) {
  pragma(inline, true);
  version(nanosvg_asserts) assert(t.length > 5);
  t.ptr[0] = 1.0f; t.ptr[1] = 0.0f;
  t.ptr[2] = 0.0f; t.ptr[3] = 1.0f;
  t.ptr[4] = tx; t.ptr[5] = ty;
}

/// Sets the transform to scale matrix.
public void nvgTransformScale (float[] t, float sx, float sy) {
  pragma(inline, true);
  version(nanosvg_asserts) assert(t.length > 5);
  t.ptr[0] = sx; t.ptr[1] = 0.0f;
  t.ptr[2] = 0.0f; t.ptr[3] = sy;
  t.ptr[4] = 0.0f; t.ptr[5] = 0.0f;
}

/// Sets the transform to rotate matrix. Angle is specified in radians.
public void nvgTransformRotate (float[] t, float a) {
  //pragma(inline, true);
  version(nanosvg_asserts) assert(t.length > 5);
  float cs = nvg__cosf(a), sn = nvg__sinf(a);
  t.ptr[0] = cs; t.ptr[1] = sn;
  t.ptr[2] = -sn; t.ptr[3] = cs;
  t.ptr[4] = 0.0f; t.ptr[5] = 0.0f;
}

/// Sets the transform to skew-x matrix. Angle is specified in radians.
public void nvgTransformSkewX (float[] t, float a) {
  //pragma(inline, true);
  version(nanosvg_asserts) assert(t.length > 5);
  t.ptr[0] = 1.0f; t.ptr[1] = 0.0f;
  t.ptr[2] = nvg__tanf(a); t.ptr[3] = 1.0f;
  t.ptr[4] = 0.0f; t.ptr[5] = 0.0f;
}

/// Sets the transform to skew-y matrix. Angle is specified in radians.
public void nvgTransformSkewY (float[] t, float a) {
  //pragma(inline, true);
  version(nanosvg_asserts) assert(t.length > 5);
  t.ptr[0] = 1.0f; t.ptr[1] = nvg__tanf(a);
  t.ptr[2] = 0.0f; t.ptr[3] = 1.0f;
  t.ptr[4] = 0.0f; t.ptr[5] = 0.0f;
}

/// Sets the transform to the result of multiplication of two transforms, of A = A*B.
public void nvgTransformMultiply (float[] t, const(float)[] s) {
  version(nanosvg_asserts) assert(t.length > 5);
  version(nanosvg_asserts) assert(s.length > 5);
  //pragma(inline, true);
  float t0 = t.ptr[0]*s.ptr[0]+t.ptr[1]*s.ptr[2];
  float t2 = t.ptr[2]*s.ptr[0]+t.ptr[3]*s.ptr[2];
  float t4 = t.ptr[4]*s.ptr[0]+t.ptr[5]*s.ptr[2]+s.ptr[4];
  t.ptr[1] = t.ptr[0]*s.ptr[1]+t.ptr[1]*s.ptr[3];
  t.ptr[3] = t.ptr[2]*s.ptr[1]+t.ptr[3]*s.ptr[3];
  t.ptr[5] = t.ptr[4]*s.ptr[1]+t.ptr[5]*s.ptr[3]+s.ptr[5];
  t.ptr[0] = t0;
  t.ptr[2] = t2;
  t.ptr[4] = t4;
}

/// Sets the transform to the result of multiplication of two transforms, of A = B*A.
public void nvgTransformPremultiply (float[] t, const(float)[] s) {
  version(nanosvg_asserts) assert(t.length > 5);
  version(nanosvg_asserts) assert(s.length > 5);
  //pragma(inline, true);
  float[6] s2 = s[0..6];
  nvgTransformMultiply(s2[], t);
  t[0..6] = s2[];
}

/// Sets the destination to inverse of specified transform.
/// Returns `true` if the inverse could be calculated, else `false`.
public bool nvgTransformInverse (float[] inv, const(float)[] t) {
  version(nanosvg_asserts) assert(t.length > 5);
  version(nanosvg_asserts) assert(inv.length > 5);
  immutable double det = cast(double)t.ptr[0]*t.ptr[3]-cast(double)t.ptr[2]*t.ptr[1];
  if (det > -1e-6 && det < 1e-6) {
    nvgTransformIdentity(inv);
    return false;
  }
  immutable double invdet = 1.0/det;
  inv.ptr[0] = cast(float)(t.ptr[3]*invdet);
  inv.ptr[2] = cast(float)(-t.ptr[2]*invdet);
  inv.ptr[4] = cast(float)((cast(double)t.ptr[2]*t.ptr[5]-cast(double)t.ptr[3]*t.ptr[4])*invdet);
  inv.ptr[1] = cast(float)(-t.ptr[1]*invdet);
  inv.ptr[3] = cast(float)(t.ptr[0]*invdet);
  inv.ptr[5] = cast(float)((cast(double)t.ptr[1]*t.ptr[4]-cast(double)t.ptr[0]*t.ptr[5])*invdet);
  return true;
}

/// Transform a point by given transform.
public void nvgTransformPoint (float* dx, float* dy, const(float)[] t, float sx, float sy) {
  pragma(inline, true);
  version(nanosvg_asserts) assert(t.length > 5);
  *dx = sx*t.ptr[0]+sy*t.ptr[2]+t.ptr[4];
  *dy = sx*t.ptr[1]+sy*t.ptr[3]+t.ptr[5];
}

// Converts degrees to radians.
public float nvgDegToRad() (float deg) {
  pragma(inline, true);
  return deg/180.0f*NVG_PI;
}

// Converts radians to degrees.
public float nvgRadToDeg() (float rad) {
  pragma(inline, true);
  return rad/NVG_PI*180.0f;
}

void nvg__setPaintColor (NVGPaint* p, NVGColor color) {
  //pragma(inline, true);
  memset(p, 0, (*p).sizeof);
  nvgTransformIdentity(p.xform[]);
  p.radius = 0.0f;
  p.feather = 1.0f;
  p.innerColor = color;
  p.outerColor = color;
}


// ////////////////////////////////////////////////////////////////////////// //
/// <h1>State handling</h1>
//
/** NanoVG contains state which represents how paths will be rendered.
 * The state contains transform, fill and stroke styles, text and font styles,
 * and scissor clipping.
 */
public alias NVGSectionDummy02 = void;

/** Pushes and saves the current render state into a state stack.
 * A matching `restore()` must be used to restore the state.
 * Returns `false` if state stack overflowed.
 */
public bool save (NVGContext ctx) {
  if (ctx.nstates >= NVG_MAX_STATES) return false;
  if (ctx.nstates > 0) memcpy(&ctx.states[ctx.nstates], &ctx.states[ctx.nstates-1], NVGstate.sizeof);
  ++ctx.nstates;
  return true;
}

/// Pops and restores current render state.
public bool restore (NVGContext ctx) {
  if (ctx.nstates <= 1) return false;
  --ctx.nstates;
  return true;
}

/// Resets current render state to default values. Does not affect the render state stack.
public void reset (NVGContext ctx) {
  NVGstate* state = nvg__getState(ctx);
  memset(state, 0, (*state).sizeof);

  nvg__setPaintColor(&state.fill, nvgRGBA(255, 255, 255, 255));
  nvg__setPaintColor(&state.stroke, nvgRGBA(0, 0, 0, 255));
  state.strokeWidth = 1.0f;
  state.miterLimit = 10.0f;
  state.lineCap = NVGLineCap.Butt;
  state.lineJoin = NVGLineCap.Miter;
  state.alpha = 1.0f;
  nvgTransformIdentity(state.xform[]);

  state.scissor.extent.ptr[0] = -1.0f;
  state.scissor.extent.ptr[1] = -1.0f;

  state.fontSize = 16.0f;
  state.letterSpacing = 0.0f;
  state.lineHeight = 1.0f;
  state.fontBlur = 0.0f;
  state.textAlign.reset;
  state.fontId = 0;
}

// ////////////////////////////////////////////////////////////////////////// //
/// <h1>Render styles</h1>
//
/** Fill and stroke render style can be either a solid color or a paint which is a gradient or a pattern.
 * Solid color is simply defined as a color value, different kinds of paints can be created
 * using `linearGradient()`, `boxGradient()`, `radialGradient()` and `imagePattern()`.
 *
 * Current render style can be saved and restored using `save()` and `restore()`.
 */
public alias NVGSectionDummy03 = void;

/// Sets the stroke width of the stroke style.
public void strokeWidth (NVGContext ctx, float width) {
  NVGstate* state = nvg__getState(ctx);
  state.strokeWidth = width;
}

/// Sets the miter limit of the stroke style. Miter limit controls when a sharp corner is beveled.
public void miterLimit (NVGContext ctx, float limit) {
  NVGstate* state = nvg__getState(ctx);
  state.miterLimit = limit;
}

/// Sets how the end of the line (cap) is drawn,
/// Can be one of: NVGLineCap.Butt (default), NVGLineCap.Round, NVGLineCap.Square.
public void lineCap (NVGContext ctx, NVGLineCap cap) {
  NVGstate* state = nvg__getState(ctx);
  state.lineCap = cap;
}

/// Sets how sharp path corners are drawn.
/// Can be one of NVGLineCap.Miter (default), NVGLineCap.Round, NVGLineCap.Bevel.
public void lineJoin (NVGContext ctx, NVGLineCap join) {
  NVGstate* state = nvg__getState(ctx);
  state.lineJoin = join;
}

/// Sets the transparency applied to all rendered shapes.
/// Already transparent paths will get proportionally more transparent as well.
public void globalAlpha (NVGContext ctx, float alpha) {
  NVGstate* state = nvg__getState(ctx);
  state.alpha = alpha;
}

/** Premultiplies current coordinate system by specified matrix.
 *
 * The parameters are interpreted as matrix as follows:
 *
 * ----------------------
 *   [a c e]
 *   [b d f]
 *   [0 0 1]
 * ----------------------
 */
public void transform (NVGContext ctx, float a, float b, float c, float d, float e, float f) {
  NVGstate* state = nvg__getState(ctx);
  //float[6] t = [ a, b, c, d, e, f ];
  float[6] t = void;
  t.ptr[0] = a;
  t.ptr[1] = b;
  t.ptr[2] = c;
  t.ptr[3] = d;
  t.ptr[4] = e;
  t.ptr[5] = f;
  nvgTransformPremultiply(state.xform[], t[]);
}

/// Resets current transform to a identity matrix.
public void resetTransform (NVGContext ctx) {
  NVGstate* state = nvg__getState(ctx);
  nvgTransformIdentity(state.xform[]);
}

/// Translates current coordinate system.
public void translate (NVGContext ctx, float x, float y) {
  NVGstate* state = nvg__getState(ctx);
  float[6] t = void;
  nvgTransformTranslate(t[], x, y);
  nvgTransformPremultiply(state.xform[], t[]);
}

/// Rotates current coordinate system. Angle is specified in radians.
public void rotate (NVGContext ctx, float angle) {
  NVGstate* state = nvg__getState(ctx);
  float[6] t = void;
  nvgTransformRotate(t[], angle);
  nvgTransformPremultiply(state.xform[], t[]);
}

/// Skews the current coordinate system along X axis. Angle is specified in radians.
public void skewX (NVGContext ctx, float angle) {
  NVGstate* state = nvg__getState(ctx);
  float[6] t = void;
  nvgTransformSkewX(t[], angle);
  nvgTransformPremultiply(state.xform[], t[]);
}

/// Skews the current coordinate system along Y axis. Angle is specified in radians.
public void skewY (NVGContext ctx, float angle) {
  NVGstate* state = nvg__getState(ctx);
  float[6] t = void;
  nvgTransformSkewY(t[], angle);
  nvgTransformPremultiply(state.xform[], t[]);
}

/// Scales the current coordinate system.
public void scale (NVGContext ctx, float x, float y) {
  NVGstate* state = nvg__getState(ctx);
  float[6] t = void;
  nvgTransformScale(t[], x, y);
  nvgTransformPremultiply(state.xform[], t[]);
}

/** Stores the top part (a-f) of the current transformation matrix in to the specified buffer.
 *
 * ----------------------
 *   [a c e]
 *   [b d f]
 *   [0 0 1]
 * ----------------------
 *
 * There should be space for 6 floats in the return buffer for the values a-f.
 */
public void currentTransform (NVGContext ctx, float[] xform) {
  version(nanosvg_asserts) assert(xform.length > 5);
  NVGstate* state = nvg__getState(ctx);
  xform[0..6] = state.xform[0..6];
}

/// Sets current stroke style to a solid color.
public void strokeColor (NVGContext ctx, NVGColor color) {
  NVGstate* state = nvg__getState(ctx);
  nvg__setPaintColor(&state.stroke, color);
}

/// Sets current stroke style to a paint, which can be a one of the gradients or a pattern.
public void strokePaint (NVGContext ctx, NVGPaint paint) {
  NVGstate* state = nvg__getState(ctx);
  state.stroke = paint;
  nvgTransformMultiply(state.stroke.xform[], state.xform[]);
}

/// Sets current fill style to a solid color.
public void fillColor (NVGContext ctx, NVGColor color) {
  NVGstate* state = nvg__getState(ctx);
  nvg__setPaintColor(&state.fill, color);
}

/// Sets current fill style to a paint, which can be a one of the gradients or a pattern.
public void fillPaint (NVGContext ctx, NVGPaint paint) {
  NVGstate* state = nvg__getState(ctx);
  state.fill = paint;
  nvgTransformMultiply(state.fill.xform[], state.xform[]);
}


// ////////////////////////////////////////////////////////////////////////// //
/// <h1>Images</h1>
//
/** NanoVG allows you to load jpg and png (if arsd loaders are in place) files to be used for rendering.
 * In addition you can upload your own image.
 * The parameter imageFlags is combination of flags defined in NVGImageFlags.
 */
public alias NVGSectionDummy04 = void;

version(nanovg_use_arsd_image) {
  // do we have new arsd API to load images?
  static if (!is(typeof(MemoryImage.fromImage))) {
    // oops
    MemoryImage fromImage(T : const(char)[]) (T filename) @trusted {
      static if (__traits(compiles, {import arsd.jpeg;}) || __traits(compiles, {import iv.jpegd;})) {
        // yay, we have jpeg loader here, try it!
        static if (__traits(compiles, {import arsd.jpeg;})) import arsd.jpeg; else import iv.jpegd;
        bool goodJpeg = false;
        try {
          int w, h, c;
          goodJpeg = detect_jpeg_image_from_file(filename, w, h, c);
          if (goodJpeg && (w < 1 || h < 1)) goodJpeg = false;
        } catch (Exception) {} // sorry
        if (goodJpeg) return readJpeg(filename);
        enum HasJpeg = true;
      } else {
        enum HasJpeg = false;
      }
      static if (__traits(compiles, {import arsd.png;})) {
        // yay, we have png loader here, try it!
        import arsd.png;
        static if (is(T == string)) {
          return readPng(filename);
        } else {
          // std.stdio sux!
          return readPng(filename.idup);
        }
        enum HasPng = true;
      } else {
        enum HasPng = false;
      }
      static if (HasJpeg || HasPng) {
        throw new Exception("cannot load image '"~filename.idup~"' in unknown format");
      } else {
        static assert(0, "please provide 'arsd.png', 'arsd.jpeg' or both to load images!");
      }
    }
    alias ArsdImage = fromImage;
  } else {
    alias ArsdImage = MemoryImage.fromImage;
  }
}

/// Creates image by loading it from the disk from specified file name.
/// Returns handle to the image.
public int createImage (NVGContext ctx, const(char)[] filename, int imageFlags=NVGImageFlags.None) {
  version(nanovg_use_arsd_image) {
    try {
      auto img = ArsdImage(filename).getAsTrueColorImage;
      scope(exit) img.destroy;
      return ctx.createImageRGBA(img.width, img.height, img.imageData.bytes[], imageFlags);
    } catch (Exception) {}
    return 0;
  } else {
    import std.internal.cstring;
    ubyte* img;
    int w, h, n, image;
    stbi_set_unpremultiply_on_load(1);
    stbi_convert_iphone_png_to_rgb(1);
    img = stbi_load(filename.tempCString, &w, &h, &n, 4);
    if (img is null) {
      //printf("Failed to load %s - %s\n", filename, stbi_failure_reason());
      return 0;
    }
    image = ctx.createImageRGBA(w, h, imageFlags, img[0..w*h*4]);
    stbi_image_free(img);
    return image;
  }
}

version(nanovg_use_arsd_image) {
  /// Creates image by loading it from the specified chunk of memory.
  /// Returns handle to the image.
  public int createImageFromMemoryImage (NVGContext ctx, MemoryImage img, int imageFlags=NVGImageFlags.None) {
    if (img is null) return 0;
    auto tc = img.getAsTrueColorImage;
    return ctx.createImageRGBA(tc.width, tc.height, tc.imageData.bytes[], imageFlags);
  }
} else {
  /// Creates image by loading it from the specified chunk of memory.
  /// Returns handle to the image.
  public int createImageMem (NVGContext ctx, const(ubyte)* data, int ndata, int imageFlags=NVGImageFlags.None) {
    int w, h, n, image;
    ubyte* img = stbi_load_from_memory(data, ndata, &w, &h, &n, 4);
    if (img is null) {
      //printf("Failed to load %s - %s\n", filename, stbi_failure_reason());
      return 0;
    }
    image = ctx.createImageRGBA(w, h, img[0..w*h*4], imageFlags);
    stbi_image_free(img);
    return image;
  }
}

/// Creates image from specified image data.
/// Returns handle to the image.
public int createImageRGBA (NVGContext ctx, int w, int h, const(void)[] data, int imageFlags=NVGImageFlags.None) {
  if (w < 1 || h < 1 || data.length < w*h*4) return -1;
  return ctx.params.renderCreateTexture(ctx.params.userPtr, NVGtexture.RGBA, w, h, imageFlags, cast(const(ubyte)*)data.ptr);
}

/// Updates image data specified by image handle.
public void updateImage (NVGContext ctx, int image, const(void)[] data) {
  int w, h;
  ctx.params.renderGetTextureSize(ctx.params.userPtr, image, &w, &h);
  ctx.params.renderUpdateTexture(ctx.params.userPtr, image, 0, 0, w, h, cast(const(ubyte)*)data.ptr);
}

/// Returns the dimensions of a created image.
public void imageSize (NVGContext ctx, int image, int* w, int* h) {
  ctx.params.renderGetTextureSize(ctx.params.userPtr, image, w, h);
}

/// Deletes created image.
public void deleteImage (NVGContext ctx, int image) {
  if (ctx is null || image < 0) return;
  ctx.params.renderDeleteTexture(ctx.params.userPtr, image);
}


// ////////////////////////////////////////////////////////////////////////// //
/// <h1>Paints</h1>
//
/** NanoVG supports four types of paints: linear gradient, box gradient, radial gradient and image pattern.
 * These can be used as paints for strokes and fills.
 */
public alias NVGSectionDummy05 = void;

/** Creates and returns a linear gradient. Parameters `(sx, sy) (ex, ey)` specify the start and end coordinates
 * of the linear gradient, icol specifies the start color and ocol the end color.
 * The gradient is transformed by the current transform when it is passed to `fillPaint()` or `strokePaint()`.
 */
public NVGPaint linearGradient (NVGContext ctx, float sx, float sy, float ex, float ey, NVGColor icol, NVGColor ocol) {
  NVGPaint p;
  //float dx, dy, d;
  //const float large = 1e5;
  enum large = 1e5f;
  //NVG_NOTUSED(ctx);
  memset(&p, 0, p.sizeof);

  // Calculate transform aligned to the line
  float dx = ex-sx;
  float dy = ey-sy;
  immutable float d = nvg__sqrtf(dx*dx+dy*dy);
  if (d > 0.0001f) {
    dx /= d;
    dy /= d;
  } else {
    dx = 0;
    dy = 1;
  }

  p.xform.ptr[0] = dy; p.xform.ptr[1] = -dx;
  p.xform.ptr[2] = dx; p.xform.ptr[3] = dy;
  p.xform.ptr[4] = sx-dx*large; p.xform.ptr[5] = sy-dy*large;

  p.extent[0] = large;
  p.extent[1] = large+d*0.5f;

  p.radius = 0.0f;

  p.feather = nvg__max(1.0f, d);

  p.innerColor = icol;
  p.outerColor = ocol;

  return p;
}

/** Creates and returns a radial gradient. Parameters (cx, cy) specify the center, inr and outr specify
 * the inner and outer radius of the gradient, icol specifies the start color and ocol the end color.
 * The gradient is transformed by the current transform when it is passed to `fillPaint()` or `strokePaint()`.
 */
public NVGPaint radialGradient (NVGContext ctx, float cx, float cy, float inr, float outr, NVGColor icol, NVGColor ocol) {
  NVGPaint p;
  immutable float r = (inr+outr)*0.5f;
  immutable float f = (outr-inr);
  //NVG_NOTUSED(ctx);
  memset(&p, 0, p.sizeof);

  nvgTransformIdentity(p.xform[]);
  p.xform.ptr[4] = cx;
  p.xform.ptr[5] = cy;

  p.extent[0] = r;
  p.extent[1] = r;

  p.radius = r;

  p.feather = nvg__max(1.0f, f);

  p.innerColor = icol;
  p.outerColor = ocol;

  return p;
}

/** Creates and returns a box gradient. Box gradient is a feathered rounded rectangle, it is useful for rendering
 * drop shadows or highlights for boxes. Parameters (x, y) define the top-left corner of the rectangle,
 * (w, h) define the size of the rectangle, r defines the corner radius, and f feather. Feather defines how blurry
 * the border of the rectangle is. Parameter icol specifies the inner color and ocol the outer color of the gradient.
 * The gradient is transformed by the current transform when it is passed to `fillPaint()` or `strokePaint()`.
 */
public NVGPaint boxGradient (NVGContext ctx, float x, float y, float w, float h, float r, float f, NVGColor icol, NVGColor ocol) {
  NVGPaint p;
  //NVG_NOTUSED(ctx);
  memset(&p, 0, p.sizeof);

  nvgTransformIdentity(p.xform[]);
  p.xform.ptr[4] = x+w*0.5f;
  p.xform.ptr[5] = y+h*0.5f;

  p.extent[0] = w*0.5f;
  p.extent[1] = h*0.5f;

  p.radius = r;

  p.feather = nvg__max(1.0f, f);

  p.innerColor = icol;
  p.outerColor = ocol;

  return p;
}


/** Creates and returns an image patter. Parameters `(cx, cy)` specify the left-top location of the image pattern,
 * `(w, h)` the size of one image, `angle` rotation around the top-left corner, `image` is handle to the image to render.
 * The gradient is transformed by the current transform when it is passed to `fillPaint()` or `strokePaint()`.
 */
public NVGPaint imagePattern (NVGContext ctx, float cx, float cy, float w, float h, float angle, int image, float alpha=1) {
  NVGPaint p;
  //NVG_NOTUSED(ctx);
  memset(&p, 0, p.sizeof);

  nvgTransformRotate(p.xform[], angle);
  p.xform.ptr[4] = cx;
  p.xform.ptr[5] = cy;

  p.extent[0] = w;
  p.extent[1] = h;

  p.image = image;

  p.innerColor = p.outerColor = nvgRGBAf(1, 1, 1, alpha);

  return p;
}

// ////////////////////////////////////////////////////////////////////////// //
/// <h1>Scissoring</h1>
//
/** Scissoring allows you to clip the rendering into a rectangle. This is useful for various
 * user interface cases like rendering a text edit or a timeline.
 */
public alias NVGSectionDummy06 = void;

/// Sets the current scissor rectangle. The scissor rectangle is transformed by the current transform.
public void scissor (NVGContext ctx, float x, float y, float w, float h) {
  NVGstate* state = nvg__getState(ctx);

  w = nvg__max(0.0f, w);
  h = nvg__max(0.0f, h);

  nvgTransformIdentity(state.scissor.xform[]);
  state.scissor.xform.ptr[4] = x+w*0.5f;
  state.scissor.xform.ptr[5] = y+h*0.5f;
  nvgTransformMultiply(state.scissor.xform[], state.xform[]);

  state.scissor.extent[0] = w*0.5f;
  state.scissor.extent[1] = h*0.5f;
}

void nvg__isectRects (float* dst, float ax, float ay, float aw, float ah, float bx, float by, float bw, float bh) {
  immutable float minx = nvg__max(ax, bx);
  immutable float miny = nvg__max(ay, by);
  immutable float maxx = nvg__min(ax+aw, bx+bw);
  immutable float maxy = nvg__min(ay+ah, by+bh);
  dst[0] = minx;
  dst[1] = miny;
  dst[2] = nvg__max(0.0f, maxx-minx);
  dst[3] = nvg__max(0.0f, maxy-miny);
}

/** Intersects current scissor rectangle with the specified rectangle.
 * The scissor rectangle is transformed by the current transform.
 * Note: in case the rotation of previous scissor rect differs from
 * the current one, the intersection will be done between the specified
 * rectangle and the previous scissor rectangle transformed in the current
 * transform space. The resulting shape is always rectangle.
 */
public void intersectScissor (NVGContext ctx, float x, float y, float w, float h) {
  NVGstate* state = nvg__getState(ctx);

  // If no previous scissor has been set, set the scissor as current scissor.
  if (state.scissor.extent[0] < 0) {
    ctx.scissor(x, y, w, h);
    return;
  }

  float[6] pxform = void;
  float[6] invxorm = void;
  float[4] rect = void;
  //float ex, ey, tex, tey;

  // Transform the current scissor rect into current transform space.
  // If there is difference in rotation, this will be approximation.
  memcpy(pxform.ptr, state.scissor.xform.ptr, float.sizeof*6);
  immutable float ex = state.scissor.extent[0];
  immutable float ey = state.scissor.extent[1];
  nvgTransformInverse(invxorm[], state.xform[]);
  nvgTransformMultiply(pxform[], invxorm[]);
  immutable float tex = ex*nvg__absf(pxform.ptr[0])+ey*nvg__absf(pxform.ptr[2]);
  immutable float tey = ex*nvg__absf(pxform.ptr[1])+ey*nvg__absf(pxform.ptr[3]);

  // Intersect rects.
  nvg__isectRects(rect.ptr, pxform.ptr[4]-tex, pxform.ptr[5]-tey, tex*2, tey*2, x, y, w, h);

  ctx.scissor(rect.ptr[0], rect.ptr[1], rect.ptr[2], rect.ptr[3]);
}

/// Reset and disables scissoring.
public void resetScissor (NVGContext ctx) {
  NVGstate* state = nvg__getState(ctx);
  memset(state.scissor.xform.ptr, 0, (state.scissor.xform.ptr).sizeof);
  state.scissor.extent[0] = -1.0f;
  state.scissor.extent[1] = -1.0f;
}

int nvg__ptEquals (float x1, float y1, float x2, float y2, float tol) {
  //pragma(inline, true);
  immutable float dx = x2-x1;
  immutable float dy = y2-y1;
  return dx*dx+dy*dy < tol*tol;
}

float nvg__distPtSeg (float x, float y, float px, float py, float qx, float qy) {
  //float pqx, pqy, dx, dy, d, t;
  immutable float pqx = qx-px;
  immutable float pqy = qy-py;
  float dx = x-px;
  float dy = y-py;
  immutable float d = pqx*pqx+pqy*pqy;
  float t = pqx*dx+pqy*dy;
  if (d > 0) t /= d;
  if (t < 0) t = 0; else if (t > 1) t = 1;
  dx = px+t*pqx-x;
  dy = py+t*pqy-y;
  return dx*dx+dy*dy;
}

void nvg__appendCommands (NVGContext ctx, float* vals, int nvals) {
  NVGstate* state = nvg__getState(ctx);

  if (ctx.ncommands+nvals > ctx.ccommands) {
    float* commands;
    int ccommands = ctx.ncommands+nvals+ctx.ccommands/2;
    commands = cast(float*)realloc(ctx.commands, (float).sizeof*ccommands);
    if (commands is null) return;
    ctx.commands = commands;
    ctx.ccommands = ccommands;
  }

  if (cast(int)vals[0] != NVGcommands.Close && cast(int)vals[0] != NVGcommands.Winding) {
    ctx.commandx = vals[nvals-2];
    ctx.commandy = vals[nvals-1];
  }

  // transform commands
  int i = 0;
  while (i < nvals) {
    auto cmd = cast(NVGcommands)vals[i];
    switch (cmd) {
    case NVGcommands.MoveTo:
      nvgTransformPoint(&vals[i+1], &vals[i+2], state.xform[], vals[i+1], vals[i+2]);
      i += 3;
      break;
    case NVGcommands.LineTo:
      nvgTransformPoint(&vals[i+1], &vals[i+2], state.xform[], vals[i+1], vals[i+2]);
      i += 3;
      break;
    case NVGcommands.BezierTo:
      nvgTransformPoint(&vals[i+1], &vals[i+2], state.xform[], vals[i+1], vals[i+2]);
      nvgTransformPoint(&vals[i+3], &vals[i+4], state.xform[], vals[i+3], vals[i+4]);
      nvgTransformPoint(&vals[i+5], &vals[i+6], state.xform[], vals[i+5], vals[i+6]);
      i += 7;
      break;
    case NVGcommands.Close:
      ++i;
      break;
    case NVGcommands.Winding:
      i += 2;
      break;
    default:
      ++i;
    }
  }

  memcpy(&ctx.commands[ctx.ncommands], vals, nvals*float.sizeof);

  ctx.ncommands += nvals;
}


void nvg__clearPathCache (NVGContext ctx) {
  ctx.cache.npoints = 0;
  ctx.cache.npaths = 0;
}

NVGpath* nvg__lastPath (NVGContext ctx) {
  return (ctx.cache.npaths > 0 ? &ctx.cache.paths[ctx.cache.npaths-1] : null);
}

void nvg__addPath (NVGContext ctx) {
  NVGpath* path;
  if (ctx.cache.npaths+1 > ctx.cache.cpaths) {
    NVGpath* paths;
    int cpaths = ctx.cache.npaths+1+ctx.cache.cpaths/2;
    paths = cast(NVGpath*)realloc(ctx.cache.paths, NVGpath.sizeof*cpaths);
    if (paths is null) return;
    ctx.cache.paths = paths;
    ctx.cache.cpaths = cpaths;
  }
  path = &ctx.cache.paths[ctx.cache.npaths];
  memset(path, 0, (*path).sizeof);
  path.first = ctx.cache.npoints;
  path.winding = NVGWinding.CCW;

  ++ctx.cache.npaths;
}

NVGpoint* nvg__lastPoint (NVGContext ctx) {
  return (ctx.cache.npoints > 0 ? &ctx.cache.points[ctx.cache.npoints-1] : null);
}

void nvg__addPoint (NVGContext ctx, float x, float y, int flags) {
  NVGpath* path = nvg__lastPath(ctx);
  NVGpoint* pt;
  if (path is null) return;

  if (path.count > 0 && ctx.cache.npoints > 0) {
    pt = nvg__lastPoint(ctx);
    if (nvg__ptEquals(pt.x, pt.y, x, y, ctx.distTol)) {
      pt.flags |= flags;
      return;
    }
  }

  if (ctx.cache.npoints+1 > ctx.cache.cpoints) {
    NVGpoint* points;
    int cpoints = ctx.cache.npoints+1+ctx.cache.cpoints/2;
    points = cast(NVGpoint*)realloc(ctx.cache.points, NVGpoint.sizeof*cpoints);
    if (points is null) return;
    ctx.cache.points = points;
    ctx.cache.cpoints = cpoints;
  }

  pt = &ctx.cache.points[ctx.cache.npoints];
  memset(pt, 0, (*pt).sizeof);
  pt.x = x;
  pt.y = y;
  pt.flags = cast(ubyte)flags;

  ++ctx.cache.npoints;
  ++path.count;
}

void nvg__closePath (NVGContext ctx) {
  NVGpath* path = nvg__lastPath(ctx);
  if (path is null) return;
  path.closed = 1;
}

void nvg__pathWinding (NVGContext ctx, NVGWinding winding) {
  NVGpath* path = nvg__lastPath(ctx);
  if (path is null) return;
  path.winding = winding;
}

float nvg__getAverageScale (float[] t) {
  version(nanosvg_asserts) assert(t.length > 5);
  immutable float sx = nvg__sqrtf(t.ptr[0]*t.ptr[0]+t.ptr[2]*t.ptr[2]);
  immutable float sy = nvg__sqrtf(t.ptr[1]*t.ptr[1]+t.ptr[3]*t.ptr[3]);
  return (sx+sy)*0.5f;
}

NVGvertex* nvg__allocTempVerts (NVGContext ctx, int nverts) {
  if (nverts > ctx.cache.cverts) {
    int cverts = (nverts+0xff)&~0xff; // Round up to prevent allocations when things change just slightly.
    NVGvertex* verts = cast(NVGvertex*)realloc(ctx.cache.verts, (NVGvertex).sizeof*cverts);
    if (verts is null) return null;
    ctx.cache.verts = verts;
    ctx.cache.cverts = cverts;
  }

  return ctx.cache.verts;
}

float nvg__triarea2 (float ax, float ay, float bx, float by, float cx, float cy) {
  immutable float abx = bx-ax;
  immutable float aby = by-ay;
  immutable float acx = cx-ax;
  immutable float acy = cy-ay;
  return acx*aby-abx*acy;
}

float nvg__polyArea (NVGpoint* pts, int npts) {
  float area = 0;
  foreach (int i; 2..npts) {
    NVGpoint* a = &pts[0];
    NVGpoint* b = &pts[i-1];
    NVGpoint* c = &pts[i];
    area += nvg__triarea2(a.x, a.y, b.x, b.y, c.x, c.y);
  }
  return area*0.5f;
}

void nvg__polyReverse (NVGpoint* pts, int npts) {
  NVGpoint tmp;
  int i = 0, j = npts-1;
  while (i < j) {
    tmp = pts[i];
    pts[i] = pts[j];
    pts[j] = tmp;
    ++i;
    --j;
  }
}

void nvg__vset (NVGvertex* vtx, float x, float y, float u, float v) {
  vtx.x = x;
  vtx.y = y;
  vtx.u = u;
  vtx.v = v;
}

void nvg__tesselateBezier (NVGContext ctx, in float x1, in float y1, in float x2, in float y2, in float x3, in float y3, in float x4, in float y4, in int level, in int type) {
  //import core.stdc.math : fabsf;
  //float x12, y12, x23, y23, x34, y34, x123, y123, x234, y234, x1234, y1234;
  //float dx, dy, d2, d3;

  if (level > 10) return;

  immutable float x12 = (x1+x2)*0.5f;
  immutable float y12 = (y1+y2)*0.5f;
  immutable float x23 = (x2+x3)*0.5f;
  immutable float y23 = (y2+y3)*0.5f;
  immutable float x34 = (x3+x4)*0.5f;
  immutable float y34 = (y3+y4)*0.5f;
  immutable float x123 = (x12+x23)*0.5f;
  immutable float y123 = (y12+y23)*0.5f;

  immutable float dx = x4-x1;
  immutable float dy = y4-y1;
  immutable float d2 = nvg__absf(((x2-x4)*dy-(y2-y4)*dx));
  immutable float d3 = nvg__absf(((x3-x4)*dy-(y3-y4)*dx));

  if ((d2+d3)*(d2+d3) < ctx.tessTol*(dx*dx+dy*dy)) {
    nvg__addPoint(ctx, x4, y4, type);
    return;
  }

  /*
  if (nvg__absf(x1+x3-x2-x2)+nvg__absf(y1+y3-y2-y2)+nvg__absf(x2+x4-x3-x3)+nvg__absf(y2+y4-y3-y3) < ctx.tessTol) {
    nvg__addPoint(ctx, x4, y4, type);
    return;
  }
  */

  immutable float x234 = (x23+x34)*0.5f;
  immutable float y234 = (y23+y34)*0.5f;
  immutable float x1234 = (x123+x234)*0.5f;
  immutable float y1234 = (y123+y234)*0.5f;

  nvg__tesselateBezier(ctx, x1, y1, x12, y12, x123, y123, x1234, y1234, level+1, 0);
  nvg__tesselateBezier(ctx, x1234, y1234, x234, y234, x34, y34, x4, y4, level+1, type);
}

void nvg__flattenPaths (NVGContext ctx) {
  NVGpathCache* cache = ctx.cache;
  //NVGstate* state = nvg__getState(ctx);
  NVGpoint* last;
  NVGpoint* p0;
  NVGpoint* p1;
  NVGpoint* pts;
  NVGpath* path;
  //int i, j;
  float* cp1;
  float* cp2;
  float* p;
  //float area;

  if (cache.npaths > 0) return;

  // Flatten
  int i = 0;
  while (i < ctx.ncommands) {
    auto cmd = cast(NVGcommands)ctx.commands[i];
    switch (cmd) {
      case NVGcommands.MoveTo:
        nvg__addPath(ctx);
        p = &ctx.commands[i+1];
        nvg__addPoint(ctx, p[0], p[1], NVGpointFlags.Corner);
        i += 3;
        break;
      case NVGcommands.LineTo:
        p = &ctx.commands[i+1];
        nvg__addPoint(ctx, p[0], p[1], NVGpointFlags.Corner);
        i += 3;
        break;
      case NVGcommands.BezierTo:
        last = nvg__lastPoint(ctx);
        if (last !is null) {
          cp1 = &ctx.commands[i+1];
          cp2 = &ctx.commands[i+3];
          p = &ctx.commands[i+5];
          nvg__tesselateBezier(ctx, last.x, last.y, cp1[0], cp1[1], cp2[0], cp2[1], p[0], p[1], 0, NVGpointFlags.Corner);
        }
        i += 7;
        break;
      case NVGcommands.Close:
        nvg__closePath(ctx);
        ++i;
        break;
      case NVGcommands.Winding:
        nvg__pathWinding(ctx, cast(NVGWinding)ctx.commands[i+1]);
        i += 2;
        break;
      default:
        ++i;
    }
  }

  cache.bounds.ptr[0] = cache.bounds.ptr[1] = 1e6f;
  cache.bounds.ptr[2] = cache.bounds.ptr[3] = -1e6f;

  // Calculate the direction and length of line segments.
  foreach (int j; 0..cache.npaths) {
    path = &cache.paths[j];
    pts = &cache.points[path.first];

    // If the first and last points are the same, remove the last, mark as closed path.
    p0 = &pts[path.count-1];
    p1 = &pts[0];
    if (nvg__ptEquals(p0.x, p0.y, p1.x, p1.y, ctx.distTol)) {
      path.count--;
      p0 = &pts[path.count-1];
      path.closed = 1;
    }

    // Enforce winding.
    if (path.count > 2) {
      immutable float area = nvg__polyArea(pts, path.count);
      if (path.winding == NVGWinding.CCW && area < 0.0f) nvg__polyReverse(pts, path.count);
      if (path.winding == NVGWinding.CW && area > 0.0f) nvg__polyReverse(pts, path.count);
    }

    foreach (immutable _; 0..path.count) {
      // Calculate segment direction and length
      p0.dx = p1.x-p0.x;
      p0.dy = p1.y-p0.y;
      p0.len = nvg__normalize(&p0.dx, &p0.dy);
      // Update bounds
      cache.bounds.ptr[0] = nvg__min(cache.bounds.ptr[0], p0.x);
      cache.bounds.ptr[1] = nvg__min(cache.bounds.ptr[1], p0.y);
      cache.bounds.ptr[2] = nvg__max(cache.bounds.ptr[2], p0.x);
      cache.bounds.ptr[3] = nvg__max(cache.bounds.ptr[3], p0.y);
      // Advance
      p0 = p1++;
    }
  }
}

int nvg__curveDivs (float r, float arc, float tol) {
  immutable float da = nvg__acosf(r/(r+tol))*2.0f;
  return nvg__max(2, cast(int)nvg__ceilf(arc/da));
}

void nvg__chooseBevel (int bevel, NVGpoint* p0, NVGpoint* p1, float w, float* x0, float* y0, float* x1, float* y1) {
  if (bevel) {
    *x0 = p1.x+p0.dy*w;
    *y0 = p1.y-p0.dx*w;
    *x1 = p1.x+p1.dy*w;
    *y1 = p1.y-p1.dx*w;
  } else {
    *x0 = p1.x+p1.dmx*w;
    *y0 = p1.y+p1.dmy*w;
    *x1 = p1.x+p1.dmx*w;
    *y1 = p1.y+p1.dmy*w;
  }
}

NVGvertex* nvg__roundJoin (NVGvertex* dst, NVGpoint* p0, NVGpoint* p1, float lw, float rw, float lu, float ru, int ncap, float fringe) {
  int i, n;
  float dlx0 = p0.dy;
  float dly0 = -p0.dx;
  float dlx1 = p1.dy;
  float dly1 = -p1.dx;
  //NVG_NOTUSED(fringe);

  if (p1.flags&NVGpointFlags.Left) {
    //float lx0, ly0, lx1, ly1, a0, a1;
    float lx0 = void, ly0 = void, lx1 = void, ly1 = void;
    nvg__chooseBevel(p1.flags&NVGpointFlags.InnerBevelPR, p0, p1, lw, &lx0, &ly0, &lx1, &ly1);
    immutable float a0 = nvg__atan2f(-dly0, -dlx0);
    float a1 = nvg__atan2f(-dly1, -dlx1);
    if (a1 > a0) a1 -= NVG_PI*2;

    nvg__vset(dst, lx0, ly0, lu, 1); dst++;
    nvg__vset(dst, p1.x-dlx0*rw, p1.y-dly0*rw, ru, 1); dst++;

    n = nvg__clamp(cast(int)nvg__ceilf(((a0-a1)/NVG_PI)*ncap), 2, ncap);
    for (i = 0; i < n; ++i) {
      float u = i/cast(float)(n-1);
      float a = a0+u*(a1-a0);
      float rx = p1.x+nvg__cosf(a)*rw;
      float ry = p1.y+nvg__sinf(a)*rw;
      nvg__vset(dst, p1.x, p1.y, 0.5f, 1); dst++;
      nvg__vset(dst, rx, ry, ru, 1); dst++;
    }

    nvg__vset(dst, lx1, ly1, lu, 1); dst++;
    nvg__vset(dst, p1.x-dlx1*rw, p1.y-dly1*rw, ru, 1); dst++;

  } else {
    //float rx0, ry0, rx1, ry1, a0, a1;
    float rx0 = void, ry0 = void, rx1 = void, ry1 = void;
    nvg__chooseBevel(p1.flags&NVGpointFlags.InnerBevelPR, p0, p1, -rw, &rx0, &ry0, &rx1, &ry1);
    immutable float a0 = nvg__atan2f(dly0, dlx0);
    float a1 = nvg__atan2f(dly1, dlx1);
    if (a1 < a0) a1 += NVG_PI*2;

    nvg__vset(dst, p1.x+dlx0*rw, p1.y+dly0*rw, lu, 1); dst++;
    nvg__vset(dst, rx0, ry0, ru, 1); dst++;

    n = nvg__clamp(cast(int)nvg__ceilf(((a1-a0)/NVG_PI)*ncap), 2, ncap);
    for (i = 0; i < n; i++) {
      float u = i/cast(float)(n-1);
      float a = a0+u*(a1-a0);
      float lx = p1.x+nvg__cosf(a)*lw;
      float ly = p1.y+nvg__sinf(a)*lw;
      nvg__vset(dst, lx, ly, lu, 1); dst++;
      nvg__vset(dst, p1.x, p1.y, 0.5f, 1); dst++;
    }

    nvg__vset(dst, p1.x+dlx1*rw, p1.y+dly1*rw, lu, 1); dst++;
    nvg__vset(dst, rx1, ry1, ru, 1); dst++;

  }
  return dst;
}

NVGvertex* nvg__bevelJoin (NVGvertex* dst, NVGpoint* p0, NVGpoint* p1, float lw, float rw, float lu, float ru, float fringe) {
  float rx0, ry0, rx1, ry1;
  float lx0, ly0, lx1, ly1;
  float dlx0 = p0.dy;
  float dly0 = -p0.dx;
  float dlx1 = p1.dy;
  float dly1 = -p1.dx;
  //NVG_NOTUSED(fringe);

  if (p1.flags&NVGpointFlags.Left) {
    nvg__chooseBevel(p1.flags&NVGpointFlags.InnerBevelPR, p0, p1, lw, &lx0, &ly0, &lx1, &ly1);

    nvg__vset(dst, lx0, ly0, lu, 1); dst++;
    nvg__vset(dst, p1.x-dlx0*rw, p1.y-dly0*rw, ru, 1); dst++;

    if (p1.flags&NVGpointFlags.Bevel) {
      nvg__vset(dst, lx0, ly0, lu, 1); dst++;
      nvg__vset(dst, p1.x-dlx0*rw, p1.y-dly0*rw, ru, 1); dst++;

      nvg__vset(dst, lx1, ly1, lu, 1); dst++;
      nvg__vset(dst, p1.x-dlx1*rw, p1.y-dly1*rw, ru, 1); dst++;
    } else {
      rx0 = p1.x-p1.dmx*rw;
      ry0 = p1.y-p1.dmy*rw;

      nvg__vset(dst, p1.x, p1.y, 0.5f, 1); dst++;
      nvg__vset(dst, p1.x-dlx0*rw, p1.y-dly0*rw, ru, 1); dst++;

      nvg__vset(dst, rx0, ry0, ru, 1); dst++;
      nvg__vset(dst, rx0, ry0, ru, 1); dst++;

      nvg__vset(dst, p1.x, p1.y, 0.5f, 1); dst++;
      nvg__vset(dst, p1.x-dlx1*rw, p1.y-dly1*rw, ru, 1); dst++;
    }

    nvg__vset(dst, lx1, ly1, lu, 1); dst++;
    nvg__vset(dst, p1.x-dlx1*rw, p1.y-dly1*rw, ru, 1); dst++;

  } else {
    nvg__chooseBevel(p1.flags&NVGpointFlags.InnerBevelPR, p0, p1, -rw, &rx0, &ry0, &rx1, &ry1);

    nvg__vset(dst, p1.x+dlx0*lw, p1.y+dly0*lw, lu, 1); dst++;
    nvg__vset(dst, rx0, ry0, ru, 1); dst++;

    if (p1.flags&NVGpointFlags.Bevel) {
      nvg__vset(dst, p1.x+dlx0*lw, p1.y+dly0*lw, lu, 1); dst++;
      nvg__vset(dst, rx0, ry0, ru, 1); dst++;

      nvg__vset(dst, p1.x+dlx1*lw, p1.y+dly1*lw, lu, 1); dst++;
      nvg__vset(dst, rx1, ry1, ru, 1); dst++;
    } else {
      lx0 = p1.x+p1.dmx*lw;
      ly0 = p1.y+p1.dmy*lw;

      nvg__vset(dst, p1.x+dlx0*lw, p1.y+dly0*lw, lu, 1); dst++;
      nvg__vset(dst, p1.x, p1.y, 0.5f, 1); dst++;

      nvg__vset(dst, lx0, ly0, lu, 1); dst++;
      nvg__vset(dst, lx0, ly0, lu, 1); dst++;

      nvg__vset(dst, p1.x+dlx1*lw, p1.y+dly1*lw, lu, 1); dst++;
      nvg__vset(dst, p1.x, p1.y, 0.5f, 1); dst++;
    }

    nvg__vset(dst, p1.x+dlx1*lw, p1.y+dly1*lw, lu, 1); dst++;
    nvg__vset(dst, rx1, ry1, ru, 1); dst++;
  }

  return dst;
}

NVGvertex* nvg__buttCapStart (NVGvertex* dst, NVGpoint* p, float dx, float dy, float w, float d, float aa) {
  immutable float px = p.x-dx*d;
  immutable float py = p.y-dy*d;
  immutable float dlx = dy;
  immutable float dly = -dx;
  nvg__vset(dst, px+dlx*w-dx*aa, py+dly*w-dy*aa, 0, 0); dst++;
  nvg__vset(dst, px-dlx*w-dx*aa, py-dly*w-dy*aa, 1, 0); dst++;
  nvg__vset(dst, px+dlx*w, py+dly*w, 0, 1); dst++;
  nvg__vset(dst, px-dlx*w, py-dly*w, 1, 1); dst++;
  return dst;
}

NVGvertex* nvg__buttCapEnd (NVGvertex* dst, NVGpoint* p, float dx, float dy, float w, float d, float aa) {
  immutable float px = p.x+dx*d;
  immutable float py = p.y+dy*d;
  immutable float dlx = dy;
  immutable float dly = -dx;
  nvg__vset(dst, px+dlx*w, py+dly*w, 0, 1); dst++;
  nvg__vset(dst, px-dlx*w, py-dly*w, 1, 1); dst++;
  nvg__vset(dst, px+dlx*w+dx*aa, py+dly*w+dy*aa, 0, 0); dst++;
  nvg__vset(dst, px-dlx*w+dx*aa, py-dly*w+dy*aa, 1, 0); dst++;
  return dst;
}


NVGvertex* nvg__roundCapStart (NVGvertex* dst, NVGpoint* p, float dx, float dy, float w, int ncap, float aa) {
  immutable float px = p.x;
  immutable float py = p.y;
  immutable float dlx = dy;
  immutable float dly = -dx;
  //NVG_NOTUSED(aa);
  immutable float ncpf = cast(float)(ncap-1);
  foreach (int i; 0..ncap) {
    float a = i/*/cast(float)(ncap-1)*//ncpf*NVG_PI;
    float ax = nvg__cosf(a)*w, ay = nvg__sinf(a)*w;
    nvg__vset(dst, px-dlx*ax-dx*ay, py-dly*ax-dy*ay, 0, 1); dst++;
    nvg__vset(dst, px, py, 0.5f, 1); dst++;
  }
  nvg__vset(dst, px+dlx*w, py+dly*w, 0, 1); dst++;
  nvg__vset(dst, px-dlx*w, py-dly*w, 1, 1); dst++;
  return dst;
}

NVGvertex* nvg__roundCapEnd (NVGvertex* dst, NVGpoint* p, float dx, float dy, float w, int ncap, float aa) {
  immutable float px = p.x;
  immutable float py = p.y;
  immutable float dlx = dy;
  immutable float dly = -dx;
  //NVG_NOTUSED(aa);
  nvg__vset(dst, px+dlx*w, py+dly*w, 0, 1); dst++;
  nvg__vset(dst, px-dlx*w, py-dly*w, 1, 1); dst++;
  immutable float ncpf = cast(float)(ncap-1);
  foreach (int i; 0..ncap) {
    float a = i/*cast(float)(ncap-1)*//ncpf*NVG_PI;
    float ax = nvg__cosf(a)*w, ay = nvg__sinf(a)*w;
    nvg__vset(dst, px, py, 0.5f, 1); dst++;
    nvg__vset(dst, px-dlx*ax+dx*ay, py-dly*ax+dy*ay, 0, 1); dst++;
  }
  return dst;
}


void nvg__calculateJoins (NVGContext ctx, float w, int lineJoin, float miterLimit) {
  NVGpathCache* cache = ctx.cache;
  //int i, j;
  float iw = 0.0f;

  if (w > 0.0f) iw = 1.0f/w;

  // Calculate which joins needs extra vertices to append, and gather vertex count.
  foreach (int i; 0..cache.npaths) {
    NVGpath* path = &cache.paths[i];
    NVGpoint* pts = &cache.points[path.first];
    NVGpoint* p0 = &pts[path.count-1];
    NVGpoint* p1 = &pts[0];
    int nleft = 0;

    path.nbevel = 0;

    foreach (int j; 0..path.count) {
      float dlx0, dly0, dlx1, dly1, dmr2, cross, limit;
      dlx0 = p0.dy;
      dly0 = -p0.dx;
      dlx1 = p1.dy;
      dly1 = -p1.dx;
      // Calculate extrusions
      p1.dmx = (dlx0+dlx1)*0.5f;
      p1.dmy = (dly0+dly1)*0.5f;
      dmr2 = p1.dmx*p1.dmx+p1.dmy*p1.dmy;
      if (dmr2 > 0.000001f) {
        float scale = 1.0f/dmr2;
        if (scale > 600.0f) {
          scale = 600.0f;
        }
        p1.dmx *= scale;
        p1.dmy *= scale;
      }

      // Clear flags, but keep the corner.
      p1.flags = (p1.flags&NVGpointFlags.Corner) ? NVGpointFlags.Corner : 0;

      // Keep track of left turns.
      cross = p1.dx*p0.dy-p0.dx*p1.dy;
      if (cross > 0.0f) {
        nleft++;
        p1.flags |= NVGpointFlags.Left;
      }

      // Calculate if we should use bevel or miter for inner join.
      limit = nvg__max(1.01f, nvg__min(p0.len, p1.len)*iw);
      if ((dmr2*limit*limit) < 1.0f)
        p1.flags |= NVGpointFlags.InnerBevelPR;

      // Check to see if the corner needs to be beveled.
      if (p1.flags&NVGpointFlags.Corner) {
        if ((dmr2*miterLimit*miterLimit) < 1.0f || lineJoin == NVGLineCap.Bevel || lineJoin == NVGLineCap.Round) {
          p1.flags |= NVGpointFlags.Bevel;
        }
      }

      if ((p1.flags&(NVGpointFlags.Bevel|NVGpointFlags.InnerBevelPR)) != 0)
        path.nbevel++;

      p0 = p1++;
    }

    path.convex = (nleft == path.count) ? 1 : 0;
  }
}


int nvg__expandStroke (NVGContext ctx, float w, int lineCap, int lineJoin, float miterLimit) {
  NVGpathCache* cache = ctx.cache;
  NVGvertex* verts;
  NVGvertex* dst;
  int cverts; //, i, j;
  float aa = ctx.fringeWidth;
  int ncap = nvg__curveDivs(w, NVG_PI, ctx.tessTol); // Calculate divisions per half circle.

  nvg__calculateJoins(ctx, w, lineJoin, miterLimit);

  // Calculate max vertex usage.
  cverts = 0;
  foreach (int i; 0..cache.npaths) {
    NVGpath* path = &cache.paths[i];
    int loop = (path.closed == 0) ? 0 : 1;
    if (lineJoin == NVGLineCap.Round)
      cverts += (path.count+path.nbevel*(ncap+2)+1)*2; // plus one for loop
    else
      cverts += (path.count+path.nbevel*5+1)*2; // plus one for loop
    if (loop == 0) {
      // space for caps
      if (lineCap == NVGLineCap.Round) {
        cverts += (ncap*2+2)*2;
      } else {
        cverts += (3+3)*2;
      }
    }
  }

  verts = nvg__allocTempVerts(ctx, cverts);
  if (verts is null) return 0;

  foreach (int i; 0..cache.npaths) {
    NVGpath* path = &cache.paths[i];
    NVGpoint* pts = &cache.points[path.first];
    NVGpoint* p0;
    NVGpoint* p1;
    int s, e, loop;
    float dx, dy;

    path.fill = null;
    path.nfill = 0;

    // Calculate fringe or stroke
    loop = (path.closed == 0) ? 0 : 1;
    dst = verts;
    path.stroke = dst;

    if (loop) {
      // Looping
      p0 = &pts[path.count-1];
      p1 = &pts[0];
      s = 0;
      e = path.count;
    } else {
      // Add cap
      p0 = &pts[0];
      p1 = &pts[1];
      s = 1;
      e = path.count-1;
    }

    if (loop == 0) {
      // Add cap
      dx = p1.x-p0.x;
      dy = p1.y-p0.y;
      nvg__normalize(&dx, &dy);
      if (lineCap == NVGLineCap.Butt)
        dst = nvg__buttCapStart(dst, p0, dx, dy, w, -aa*0.5f, aa);
      else if (lineCap == NVGLineCap.Butt || lineCap == NVGLineCap.Square)
        dst = nvg__buttCapStart(dst, p0, dx, dy, w, w-aa, aa);
      else if (lineCap == NVGLineCap.Round)
        dst = nvg__roundCapStart(dst, p0, dx, dy, w, ncap, aa);
    }

    foreach (int j; s..e) {
      if ((p1.flags&(NVGpointFlags.Bevel|NVGpointFlags.InnerBevelPR)) != 0) {
        if (lineJoin == NVGLineCap.Round) {
          dst = nvg__roundJoin(dst, p0, p1, w, w, 0, 1, ncap, aa);
        } else {
          dst = nvg__bevelJoin(dst, p0, p1, w, w, 0, 1, aa);
        }
      } else {
        nvg__vset(dst, p1.x+(p1.dmx*w), p1.y+(p1.dmy*w), 0, 1); dst++;
        nvg__vset(dst, p1.x-(p1.dmx*w), p1.y-(p1.dmy*w), 1, 1); dst++;
      }
      p0 = p1++;
    }

    if (loop) {
      // Loop it
      nvg__vset(dst, verts[0].x, verts[0].y, 0, 1); dst++;
      nvg__vset(dst, verts[1].x, verts[1].y, 1, 1); dst++;
    } else {
      // Add cap
      dx = p1.x-p0.x;
      dy = p1.y-p0.y;
      nvg__normalize(&dx, &dy);
      if (lineCap == NVGLineCap.Butt)
        dst = nvg__buttCapEnd(dst, p1, dx, dy, w, -aa*0.5f, aa);
      else if (lineCap == NVGLineCap.Butt || lineCap == NVGLineCap.Square)
        dst = nvg__buttCapEnd(dst, p1, dx, dy, w, w-aa, aa);
      else if (lineCap == NVGLineCap.Round)
        dst = nvg__roundCapEnd(dst, p1, dx, dy, w, ncap, aa);
    }

    path.nstroke = cast(int)(dst-verts);

    verts = dst;
  }

  return 1;
}

int nvg__expandFill (NVGContext ctx, float w, int lineJoin, float miterLimit) {
  NVGpathCache* cache = ctx.cache;
  NVGvertex* verts;
  NVGvertex* dst;
  int cverts, convex; //, i, j;
  float aa = ctx.fringeWidth;
  int fringe = w > 0.0f;

  nvg__calculateJoins(ctx, w, lineJoin, miterLimit);

  // Calculate max vertex usage.
  cverts = 0;
  foreach (int i; 0..cache.npaths) {
    NVGpath* path = &cache.paths[i];
    cverts += path.count+path.nbevel+1;
    if (fringe) cverts += (path.count+path.nbevel*5+1)*2; // plus one for loop
  }

  verts = nvg__allocTempVerts(ctx, cverts);
  if (verts is null) return 0;

  convex = cache.npaths == 1 && cache.paths[0].convex;

  foreach (int i; 0..cache.npaths) {
    NVGpath* path = &cache.paths[i];
    NVGpoint* pts = &cache.points[path.first];
    NVGpoint* p0;
    NVGpoint* p1;
    float rw, lw, woff;
    float ru, lu;

    // Calculate shape vertices.
    woff = 0.5f*aa;
    dst = verts;
    path.fill = dst;

    if (fringe) {
      // Looping
      p0 = &pts[path.count-1];
      p1 = &pts[0];
      foreach (int j; 0..path.count) {
        if (p1.flags&NVGpointFlags.Bevel) {
          float dlx0 = p0.dy;
          float dly0 = -p0.dx;
          float dlx1 = p1.dy;
          float dly1 = -p1.dx;
          if (p1.flags&NVGpointFlags.Left) {
            float lx = p1.x+p1.dmx*woff;
            float ly = p1.y+p1.dmy*woff;
            nvg__vset(dst, lx, ly, 0.5f, 1); dst++;
          } else {
            float lx0 = p1.x+dlx0*woff;
            float ly0 = p1.y+dly0*woff;
            float lx1 = p1.x+dlx1*woff;
            float ly1 = p1.y+dly1*woff;
            nvg__vset(dst, lx0, ly0, 0.5f, 1); dst++;
            nvg__vset(dst, lx1, ly1, 0.5f, 1); dst++;
          }
        } else {
          nvg__vset(dst, p1.x+(p1.dmx*woff), p1.y+(p1.dmy*woff), 0.5f, 1); dst++;
        }
        p0 = p1++;
      }
    } else {
      foreach (int j; 0..path.count) {
        nvg__vset(dst, pts[j].x, pts[j].y, 0.5f, 1);
        dst++;
      }
    }

    path.nfill = cast(int)(dst-verts);
    verts = dst;

    // Calculate fringe
    if (fringe) {
      lw = w+woff;
      rw = w-woff;
      lu = 0;
      ru = 1;
      dst = verts;
      path.stroke = dst;

      // Create only half a fringe for convex shapes so that
      // the shape can be rendered without stenciling.
      if (convex) {
        lw = woff;  // This should generate the same vertex as fill inset above.
        lu = 0.5f;  // Set outline fade at middle.
      }

      // Looping
      p0 = &pts[path.count-1];
      p1 = &pts[0];

      foreach (int j; 0..path.count) {
        if ((p1.flags&(NVGpointFlags.Bevel|NVGpointFlags.InnerBevelPR)) != 0) {
          dst = nvg__bevelJoin(dst, p0, p1, lw, rw, lu, ru, ctx.fringeWidth);
        } else {
          nvg__vset(dst, p1.x+(p1.dmx*lw), p1.y+(p1.dmy*lw), lu, 1); dst++;
          nvg__vset(dst, p1.x-(p1.dmx*rw), p1.y-(p1.dmy*rw), ru, 1); dst++;
        }
        p0 = p1++;
      }

      // Loop it
      nvg__vset(dst, verts[0].x, verts[0].y, lu, 1); dst++;
      nvg__vset(dst, verts[1].x, verts[1].y, ru, 1); dst++;

      path.nstroke = cast(int)(dst-verts);
      verts = dst;
    } else {
      path.stroke = null;
      path.nstroke = 0;
    }
  }

  return 1;
}


// ////////////////////////////////////////////////////////////////////////// //
/// <h1>Paths</h1>
//
/** Drawing a new shape starts with `beginPath()`, it clears all the currently defined paths.
 * Then you define one or more paths and sub-paths which describe the shape. The are functions
 * to draw common shapes like rectangles and circles, and lower level step-by-step functions,
 * which allow to define a path curve by curve.
 *
 * NanoVG uses even-odd fill rule to draw the shapes. Solid shapes should have counter clockwise
 * winding and holes should have counter clockwise order. To specify winding of a path you can
 * call `pathWinding()`. This is useful especially for the common shapes, which are drawn CCW.
 *
 * Finally you can fill the path using current fill style by calling `fill()`, and stroke it
 * with current stroke style by calling `stroke()`.
 *
 * The curve segments and sub-paths are transformed by the current transform.
 */
public alias NVGSectionDummy07 = void;

/// Clears the current path and sub-paths.
public void beginPath (NVGContext ctx) {
  ctx.ncommands = 0;
  nvg__clearPathCache(ctx);
}

/// Starts new sub-path with specified point as first point.
public void moveTo (NVGContext ctx, float x, float y) {
  float[3] vals = [ NVGcommands.MoveTo, x, y ];
  nvg__appendCommands(ctx, vals.ptr, cast(uint)(vals).length);
}

/// Adds line segment from the last point in the path to the specified point.
public void lineTo (NVGContext ctx, float x, float y) {
  float[3] vals = [ NVGcommands.LineTo, x, y ];
  nvg__appendCommands(ctx, vals.ptr, cast(uint)(vals).length);
}

/// Adds cubic bezier segment from last point in the path via two control points to the specified point.
public void bezierTo (NVGContext ctx, float c1x, float c1y, float c2x, float c2y, float x, float y) {
  float[7] vals = [ NVGcommands.BezierTo, c1x, c1y, c2x, c2y, x, y ];
  nvg__appendCommands(ctx, vals.ptr, cast(uint)(vals).length);
}

/// Adds quadratic bezier segment from last point in the path via a control point to the specified point.
public void quadTo (NVGContext ctx, float cx, float cy, float x, float y) {
  float x0 = ctx.commandx;
  float y0 = ctx.commandy;
  float[7] vals = [ NVGcommands.BezierTo,
        x0+2.0f/3.0f*(cx-x0), y0+2.0f/3.0f*(cy-y0),
        x+2.0f/3.0f*(cx-x), y+2.0f/3.0f*(cy-y),
        x, y ];
  nvg__appendCommands(ctx, vals.ptr, cast(uint)(vals).length);
}

/// Adds an arc segment at the corner defined by the last path point, and two specified points.
public void arcTo (NVGContext ctx, float x1, float y1, float x2, float y2, float radius) {
  float x0 = ctx.commandx;
  float y0 = ctx.commandy;
  float dx0, dy0, dx1, dy1, a, d, cx, cy, a0, a1;
  NVGWinding dir;

  if (ctx.ncommands == 0) return;

  // Handle degenerate cases.
  if (nvg__ptEquals(x0, y0, x1, y1, ctx.distTol) ||
    nvg__ptEquals(x1, y1, x2, y2, ctx.distTol) ||
    nvg__distPtSeg(x1, y1, x0, y0, x2, y2) < ctx.distTol*ctx.distTol ||
    radius < ctx.distTol) {
    ctx.lineTo(x1, y1);
    return;
  }

  // Calculate tangential circle to lines (x0, y0)-(x1, y1) and (x1, y1)-(x2, y2).
  dx0 = x0-x1;
  dy0 = y0-y1;
  dx1 = x2-x1;
  dy1 = y2-y1;
  nvg__normalize(&dx0, &dy0);
  nvg__normalize(&dx1, &dy1);
  a = nvg__acosf(dx0*dx1+dy0*dy1);
  d = radius/nvg__tanf(a/2.0f);

  //printf("a=%f° d=%f\n", a/NVG_PI*180.0f, d);

  if (d > 10000.0f) {
    ctx.lineTo(x1, y1);
    return;
  }

  if (nvg__cross(dx0, dy0, dx1, dy1) > 0.0f) {
    cx = x1+dx0*d+dy0*radius;
    cy = y1+dy0*d+-dx0*radius;
    a0 = nvg__atan2f(dx0, -dy0);
    a1 = nvg__atan2f(-dx1, dy1);
    dir = NVGWinding.CW;
    //printf("CW c=(%f, %f) a0=%f° a1=%f°\n", cx, cy, a0/NVG_PI*180.0f, a1/NVG_PI*180.0f);
  } else {
    cx = x1+dx0*d+-dy0*radius;
    cy = y1+dy0*d+dx0*radius;
    a0 = nvg__atan2f(-dx0, dy0);
    a1 = nvg__atan2f(dx1, -dy1);
    dir = NVGWinding.CCW;
    //printf("CCW c=(%f, %f) a0=%f° a1=%f°\n", cx, cy, a0/NVG_PI*180.0f, a1/NVG_PI*180.0f);
  }

  ctx.arc(cx, cy, radius, a0, a1, dir);
}

/// Closes current sub-path with a line segment.
public void closePath (NVGContext ctx) {
  float[1] vals = [ NVGcommands.Close ];
  nvg__appendCommands(ctx, vals.ptr, cast(uint)(vals).length);
}

/// Sets the current sub-path winding, see NVGWinding and NVGSolidity.
public void pathWinding (NVGContext ctx, NVGWinding dir) {
  float[2] vals = [ NVGcommands.Winding, cast(float)dir ];
  nvg__appendCommands(ctx, vals.ptr, cast(uint)(vals).length);
}

/// Ditto.
public void pathWinding (NVGContext ctx, NVGSolidity dir) {
  float[2] vals = [ NVGcommands.Winding, cast(float)dir ];
  nvg__appendCommands(ctx, vals.ptr, cast(uint)(vals).length);
}

/** Creates new circle arc shaped sub-path. The arc center is at (cx, cy), the arc radius is r,
 * and the arc is drawn from angle a0 to a1, and swept in direction dir (NVGWinding.CCW, or NVGWinding.CW).
 * Angles are specified in radians.
 */
public void arc (NVGContext ctx, float cx, float cy, float r, float a0, float a1, NVGWinding dir) {
  //float a = 0;
  //float dx = 0, dy = 0, x = 0, y = 0, tanx = 0, tany = 0;
  //float px = 0, py = 0, ptanx = 0, ptany = 0;
  float[3+5*7+100] vals = void;
  //int i, ndivs, nvals;
  int move = (ctx.ncommands > 0 ? NVGcommands.LineTo : NVGcommands.MoveTo);

  // Clamp angles
  float da = a1-a0;
  if (dir == NVGWinding.CW) {
    if (nvg__absf(da) >= NVG_PI*2) {
      da = NVG_PI*2;
    } else {
      while (da < 0.0f) da += NVG_PI*2;
    }
  } else {
    if (nvg__absf(da) >= NVG_PI*2) {
      da = -NVG_PI*2;
    } else {
      while (da > 0.0f) da -= NVG_PI*2;
    }
  }

  // Split arc into max 90 degree segments.
  immutable int ndivs = nvg__max(1, nvg__min(cast(int)(nvg__absf(da)/(NVG_PI*0.5f)+0.5f), 5));
  immutable float hda = (da/cast(float)ndivs)/2.0f;
  float kappa = nvg__absf(4.0f/3.0f*(1.0f-nvg__cosf(hda))/nvg__sinf(hda));

  if (dir == NVGWinding.CCW) kappa = -kappa;

  int nvals = 0;
  float px = 0, py = 0, ptanx = 0, ptany = 0;
  foreach (int i; 0..ndivs+1) {
    immutable float a = a0+da*(i/cast(float)ndivs);
    immutable float dx = nvg__cosf(a);
    immutable float dy = nvg__sinf(a);
    immutable float x = cx+dx*r;
    immutable float y = cy+dy*r;
    immutable float tanx = -dy*r*kappa;
    immutable float tany = dx*r*kappa;

    if (i == 0) {
      vals[nvals++] = cast(float)move;
      vals[nvals++] = x;
      vals[nvals++] = y;
    } else {
      vals[nvals++] = NVGcommands.BezierTo;
      vals[nvals++] = px+ptanx;
      vals[nvals++] = py+ptany;
      vals[nvals++] = x-tanx;
      vals[nvals++] = y-tany;
      vals[nvals++] = x;
      vals[nvals++] = y;
    }
    px = x;
    py = y;
    ptanx = tanx;
    ptany = tany;
  }

  nvg__appendCommands(ctx, vals.ptr, nvals);
}

/// Creates new rectangle shaped sub-path.
public void rect (NVGContext ctx, float x, float y, float w, float h) {
  float[13] vals = [
    NVGcommands.MoveTo, x, y,
    NVGcommands.LineTo, x, y+h,
    NVGcommands.LineTo, x+w, y+h,
    NVGcommands.LineTo, x+w, y,
    NVGcommands.Close
  ];
  nvg__appendCommands(ctx, vals.ptr, cast(uint)(vals).length);
}

/// Creates new rounded rectangle shaped sub-path.
public void roundedRect (NVGContext ctx, float x, float y, float w, float h, float r) {
  if (r < 0.1f) {
    ctx.rect(x, y, w, h);
  } else {
    float rx = nvg__min(r, nvg__absf(w)*0.5f)*nvg__sign(w), ry = nvg__min(r, nvg__absf(h)*0.5f)*nvg__sign(h);
    float[44] vals = [
      NVGcommands.MoveTo, x, y+ry,
      NVGcommands.LineTo, x, y+h-ry,
      NVGcommands.BezierTo, x, y+h-ry*(1-NVG_KAPPA90), x+rx*(1-NVG_KAPPA90), y+h, x+rx, y+h,
      NVGcommands.LineTo, x+w-rx, y+h,
      NVGcommands.BezierTo, x+w-rx*(1-NVG_KAPPA90), y+h, x+w, y+h-ry*(1-NVG_KAPPA90), x+w, y+h-ry,
      NVGcommands.LineTo, x+w, y+ry,
      NVGcommands.BezierTo, x+w, y+ry*(1-NVG_KAPPA90), x+w-rx*(1-NVG_KAPPA90), y, x+w-rx, y,
      NVGcommands.LineTo, x+rx, y,
      NVGcommands.BezierTo, x+rx*(1-NVG_KAPPA90), y, x, y+ry*(1-NVG_KAPPA90), x, y+ry,
      NVGcommands.Close
    ];
    nvg__appendCommands(ctx, vals.ptr, cast(uint)(vals).length);
  }
}

/// Creates new ellipse shaped sub-path.
public void ellipse (NVGContext ctx, float cx, float cy, float rx, float ry) {
  float[32] vals = [
    NVGcommands.MoveTo, cx-rx, cy,
    NVGcommands.BezierTo, cx-rx, cy+ry*NVG_KAPPA90, cx-rx*NVG_KAPPA90, cy+ry, cx, cy+ry,
    NVGcommands.BezierTo, cx+rx*NVG_KAPPA90, cy+ry, cx+rx, cy+ry*NVG_KAPPA90, cx+rx, cy,
    NVGcommands.BezierTo, cx+rx, cy-ry*NVG_KAPPA90, cx+rx*NVG_KAPPA90, cy-ry, cx, cy-ry,
    NVGcommands.BezierTo, cx-rx*NVG_KAPPA90, cy-ry, cx-rx, cy-ry*NVG_KAPPA90, cx-rx, cy,
    NVGcommands.Close
  ];
  nvg__appendCommands(ctx, vals.ptr, cast(uint)(vals).length);
}

/// Creates new circle shaped sub-path.
public void circle (NVGContext ctx, float cx, float cy, float r) {
  ctx.ellipse(cx, cy, r, r);
}

/// Debug function to dump cached path data.
debug public void debugDumpPathCache (NVGContext ctx) {
  import core.stdc.stdio : printf;
  const(NVGpath)* path;
  int i, j;

  printf("Dumping %d cached paths\n", ctx.cache.npaths);
  for (i = 0; i < ctx.cache.npaths; i++) {
    path = &ctx.cache.paths[i];
    printf("-Path %d\n", i);
    if (path.nfill) {
      printf("-fill: %d\n", path.nfill);
      for (j = 0; j < path.nfill; j++)
        printf("%f\t%f\n", path.fill[j].x, path.fill[j].y);
    }
    if (path.nstroke) {
      printf("-stroke: %d\n", path.nstroke);
      for (j = 0; j < path.nstroke; j++)
        printf("%f\t%f\n", path.stroke[j].x, path.stroke[j].y);
    }
  }
}

/// Fills the current path with current fill style.
public void fill (NVGContext ctx) {
  NVGstate* state = nvg__getState(ctx);
  const(NVGpath)* path;
  NVGPaint fillPaint = state.fill;

  nvg__flattenPaths(ctx);
  if (ctx.params.edgeAntiAlias)
    nvg__expandFill(ctx, ctx.fringeWidth, NVGLineCap.Miter, 2.4f);
  else
    nvg__expandFill(ctx, 0.0f, NVGLineCap.Miter, 2.4f);

  // Apply global alpha
  fillPaint.innerColor.a *= state.alpha;
  fillPaint.outerColor.a *= state.alpha;

  ctx.params.renderFill(ctx.params.userPtr, &fillPaint, &state.scissor, ctx.fringeWidth,
               ctx.cache.bounds.ptr, ctx.cache.paths, ctx.cache.npaths);

  // Count triangles
  foreach (int i; 0..ctx.cache.npaths) {
    path = &ctx.cache.paths[i];
    ctx.fillTriCount += path.nfill-2;
    ctx.fillTriCount += path.nstroke-2;
    ctx.drawCallCount += 2;
  }
}

/// Fills the current path with current stroke style.
public void stroke (NVGContext ctx) {
  NVGstate* state = nvg__getState(ctx);
  float scale = nvg__getAverageScale(state.xform[]);
  float strokeWidth = nvg__clamp(state.strokeWidth*scale, 0.0f, 200.0f);
  NVGPaint strokePaint = state.stroke;
  const(NVGpath)* path;

  if (strokeWidth < ctx.fringeWidth) {
    // If the stroke width is less than pixel size, use alpha to emulate coverage.
    // Since coverage is area, scale by alpha*alpha.
    float alpha = nvg__clamp(strokeWidth/ctx.fringeWidth, 0.0f, 1.0f);
    strokePaint.innerColor.a *= alpha*alpha;
    strokePaint.outerColor.a *= alpha*alpha;
    strokeWidth = ctx.fringeWidth;
  }

  // Apply global alpha
  strokePaint.innerColor.a *= state.alpha;
  strokePaint.outerColor.a *= state.alpha;

  nvg__flattenPaths(ctx);

  if (ctx.params.edgeAntiAlias)
    nvg__expandStroke(ctx, strokeWidth*0.5f+ctx.fringeWidth*0.5f, state.lineCap, state.lineJoin, state.miterLimit);
  else
    nvg__expandStroke(ctx, strokeWidth*0.5f, state.lineCap, state.lineJoin, state.miterLimit);

  ctx.params.renderStroke(ctx.params.userPtr, &strokePaint, &state.scissor, ctx.fringeWidth,
               strokeWidth, ctx.cache.paths, ctx.cache.npaths);

  // Count triangles
  foreach (int i; 0..ctx.cache.npaths) {
    path = &ctx.cache.paths[i];
    ctx.strokeTriCount += path.nstroke-2;
    ctx.drawCallCount++;
  }
}

// ////////////////////////////////////////////////////////////////////////// //
/// <h1>Text</h1>
//
/** NanoVG allows you to load .ttf files and use the font to render text.
 *
 * The appearance of the text can be defined by setting the current text style
 * and by specifying the fill color. Common text and font settings such as
 * font size, letter spacing and text align are supported. Font blur allows you
 * to create simple text effects such as drop shadows.
 *
 * At render time the font face can be set based on the font handles or name.
 *
 * Font measure functions return values in local space, the calculations are
 * carried in the same resolution as the final rendering. This is done because
 * the text glyph positions are snapped to the nearest pixels sharp rendering.
 *
 * The local space means that values are not rotated or scale as per the current
 * transformation. For example if you set font size to 12, which would mean that
 * line height is 16, then regardless of the current scaling and rotation, the
 * returned line height is always 16. Some measures may vary because of the scaling
 * since aforementioned pixel snapping.
 *
 * While this may sound a little odd, the setup allows you to always render the
 * same way regardless of scaling. I.e. following works regardless of scaling:
 *
 * ----------------------
 *    string txt = "Text me up.";
 *    vg.textBounds(x, y, txt, bounds);
 *    vg.beginPath();
 *    vg.roundedRect(bounds[0], bounds[1], bounds[2]-bounds[0], bounds[3]-bounds[1]);
 *    vg.fill();
 * ----------------------
 *
 * Note: currently only solid color fill is supported for text.
 */
public alias NVGSectionDummy08 = void;

/** Creates font by loading it from the disk from specified file name.
 * Returns handle to the font.
 * use "fontname:noaa" as `name` to turn off antialiasing (if font driver supports that). */
public int createFont (NVGContext ctx, const(char)[] name, const(char)[] path) {
  return fonsAddFont(ctx.fs, name, path);
}

/** Creates font by loading it from the specified memory chunk.
 * Returns handle to the font. */
public int createFontMem (NVGContext ctx, const(char)[] name, ubyte* data, int ndata, int freeData) {
  return fonsAddFontMem(ctx.fs, name, data, ndata, freeData);
}

/// Finds a loaded font of specified name, and returns handle to it, or -1 if the font is not found.
public int findFont (NVGContext ctx, const(char)[] name) {
  pragma(inline, true);
  return (name.length == 0 ? -1 : fonsGetFontByName(ctx.fs, name));
}

/// Sets the font size of current text style.
public void fontSize (NVGContext ctx, float size) {
  pragma(inline, true);
  nvg__getState(ctx).fontSize = size;
}

/// Gets the font size of current text style.
public float fontSize (NVGContext ctx) {
  pragma(inline, true);
  return nvg__getState(ctx).fontSize;
}

/// Sets the blur of current text style.
public void fontBlur (NVGContext ctx, float blur) {
  pragma(inline, true);
  nvg__getState(ctx).fontBlur = blur;
}

/// Gets the blur of current text style.
public float fontBlur (NVGContext ctx) {
  pragma(inline, true);
  return nvg__getState(ctx).fontBlur;
}

/// Sets the letter spacing of current text style.
public void textLetterSpacing (NVGContext ctx, float spacing) {
  pragma(inline, true);
  nvg__getState(ctx).letterSpacing = spacing;
}

/// Gets the letter spacing of current text style.
public float textLetterSpacing (NVGContext ctx) {
  pragma(inline, true);
  return nvg__getState(ctx).letterSpacing;
}

/// Sets the proportional line height of current text style. The line height is specified as multiple of font size.
public void textLineHeight (NVGContext ctx, float lineHeight) {
  pragma(inline, true);
  nvg__getState(ctx).lineHeight = lineHeight;
}

/// Gets the proportional line height of current text style. The line height is specified as multiple of font size.
public float textLineHeight (NVGContext ctx) {
  pragma(inline, true);
  return nvg__getState(ctx).lineHeight;
}

/// Sets the text align of current text style, see `NVGTextAlign` for options.
public void textAlign (NVGContext ctx, NVGTextAlign talign) {
  pragma(inline, true);
  nvg__getState(ctx).textAlign = talign;
}

/// Ditto.
public void textAlign (NVGContext ctx, NVGTextAlign.H h) {
  pragma(inline, true);
  nvg__getState(ctx).textAlign.horizontal = h;
}

/// Ditto.
public void textAlign (NVGContext ctx, NVGTextAlign.V v) {
  pragma(inline, true);
  nvg__getState(ctx).textAlign.vertical = v;
}

/// Ditto.
public void textAlign (NVGContext ctx, NVGTextAlign.H h, NVGTextAlign.V v) {
  pragma(inline, true);
  nvg__getState(ctx).textAlign.reset(h, v);
}

/// Ditto.
public void textAlign (NVGContext ctx, NVGTextAlign.V v, NVGTextAlign.H h) {
  pragma(inline, true);
  nvg__getState(ctx).textAlign.reset(h, v);
}

/// Gets the text align of current text style, see `NVGTextAlign` for options.
public NVGTextAlign textAlign (NVGContext ctx) {
  pragma(inline, true);
  return nvg__getState(ctx).textAlign;
}

/// Sets the font face based on specified id of current text style.
public void fontFaceId (NVGContext ctx, int font) {
  pragma(inline, true);
  nvg__getState(ctx).fontId = font;
}

/// Gets the font face based on specified id of current text style.
public int fontFaceId (NVGContext ctx) {
  pragma(inline, true);
  return nvg__getState(ctx).fontId;
}

/// Sets the font face based on specified name of current text style.
public void fontFace (NVGContext ctx, const(char)[] font) {
  pragma(inline, true);
  nvg__getState(ctx).fontId = fonsGetFontByName(ctx.fs, font);
}

float nvg__quantize (float a, float d) {
  pragma(inline, true);
  return (cast(int)(a/d+0.5f))*d;
}

float nvg__getFontScale (NVGstate* state) {
  pragma(inline, true);
  return nvg__min(nvg__quantize(nvg__getAverageScale(state.xform[]), 0.01f), 4.0f);
}

void nvg__flushTextTexture (NVGContext ctx) {
  int[4] dirty = void;
  if (fonsValidateTexture(ctx.fs, dirty.ptr)) {
    int fontImage = ctx.fontImages[ctx.fontImageIdx];
    // Update texture
    if (fontImage != 0) {
      int iw, ih;
      const(ubyte)* data = fonsGetTextureData(ctx.fs, &iw, &ih);
      int x = dirty[0];
      int y = dirty[1];
      int w = dirty[2]-dirty[0];
      int h = dirty[3]-dirty[1];
      ctx.params.renderUpdateTexture(ctx.params.userPtr, fontImage, x, y, w, h, data);
    }
  }
}

bool nvg__allocTextAtlas (NVGContext ctx) {
  int iw, ih;
  nvg__flushTextTexture(ctx);
  if (ctx.fontImageIdx >= NVG_MAX_FONTIMAGES-1) return false;
  // if next fontImage already have a texture
  if (ctx.fontImages[ctx.fontImageIdx+1] != 0) {
    ctx.imageSize(ctx.fontImages[ctx.fontImageIdx+1], &iw, &ih);
  } else {
    // calculate the new font image size and create it
    ctx.imageSize(ctx.fontImages[ctx.fontImageIdx], &iw, &ih);
    if (iw > ih) ih *= 2; else iw *= 2;
    if (iw > NVG_MAX_FONTIMAGE_SIZE || ih > NVG_MAX_FONTIMAGE_SIZE) iw = ih = NVG_MAX_FONTIMAGE_SIZE;
    ctx.fontImages[ctx.fontImageIdx+1] = ctx.params.renderCreateTexture(ctx.params.userPtr, NVGtexture.Alpha, iw, ih, 0, null);
  }
  ++ctx.fontImageIdx;
  fonsResetAtlas(ctx.fs, iw, ih);
  return true;
}

void nvg__renderText (NVGContext ctx, NVGvertex* verts, int nverts) {
  NVGstate* state = nvg__getState(ctx);
  NVGPaint paint = state.fill;

  // Render triangles.
  paint.image = ctx.fontImages[ctx.fontImageIdx];

  // Apply global alpha
  paint.innerColor.a *= state.alpha;
  paint.outerColor.a *= state.alpha;

  ctx.params.renderTriangles(ctx.params.userPtr, &paint, &state.scissor, verts, nverts);

  ++ctx.drawCallCount;
  ctx.textTriCount += nverts/3;
}

/// Draws text string at specified location. Returns next x position.
public float text(T) (NVGContext ctx, float x, float y, const(T)[] str) if (is(T == char) || is(T == dchar)) {
  NVGstate* state = nvg__getState(ctx);
  FONStextIter iter, prevIter;
  FONSquad q;
  NVGvertex* verts;
  float scale = nvg__getFontScale(state)*ctx.devicePxRatio;
  float invscale = 1.0f/scale;
  int cverts = 0;
  int nverts = 0;

  if (state.fontId == FONS_INVALID) return x;
  if (str.length == 0) return x;

  fonsSetSize(ctx.fs, state.fontSize*scale);
  fonsSetSpacing(ctx.fs, state.letterSpacing*scale);
  fonsSetBlur(ctx.fs, state.fontBlur*scale);
  fonsSetAlign(ctx.fs, state.textAlign);
  fonsSetFont(ctx.fs, state.fontId);

  cverts = nvg__max(2, cast(int)(str.length))*6; // conservative estimate
  verts = nvg__allocTempVerts(ctx, cverts);
  if (verts is null) return x;

  fonsTextIterInit(ctx.fs, &iter, x*scale, y*scale, str);
  prevIter = iter;
  while (fonsTextIterNext(ctx.fs, &iter, &q)) {
    float[4*2] c = void;
    if (iter.prevGlyphIndex < 0) { // can not retrieve glyph?
      if (!nvg__allocTextAtlas(ctx)) break; // no memory :(
      if (nverts != 0) {
        nvg__renderText(ctx, verts, nverts);
        nverts = 0;
      }
      iter = prevIter;
      fonsTextIterNext(ctx.fs, &iter, &q); // try again
      if (iter.prevGlyphIndex < 0) break; // still can not find glyph?
    }
    prevIter = iter;
    // Transform corners.
    nvgTransformPoint(&c[0], &c[1], state.xform[], q.x0*invscale, q.y0*invscale);
    nvgTransformPoint(&c[2], &c[3], state.xform[], q.x1*invscale, q.y0*invscale);
    nvgTransformPoint(&c[4], &c[5], state.xform[], q.x1*invscale, q.y1*invscale);
    nvgTransformPoint(&c[6], &c[7], state.xform[], q.x0*invscale, q.y1*invscale);
    // Create triangles
    if (nverts+6 <= cverts) {
      nvg__vset(&verts[nverts], c[0], c[1], q.s0, q.t0); ++nverts;
      nvg__vset(&verts[nverts], c[4], c[5], q.s1, q.t1); ++nverts;
      nvg__vset(&verts[nverts], c[2], c[3], q.s1, q.t0); ++nverts;
      nvg__vset(&verts[nverts], c[0], c[1], q.s0, q.t0); ++nverts;
      nvg__vset(&verts[nverts], c[6], c[7], q.s0, q.t1); ++nverts;
      nvg__vset(&verts[nverts], c[4], c[5], q.s1, q.t1); ++nverts;
    }
  }

  // TODO: add back-end bit to do this just once per frame
  nvg__flushTextTexture(ctx);

  nvg__renderText(ctx, verts, nverts);

  return iter.x;
}

/** Draws multi-line text string at specified location wrapped at the specified width. If end is specified only the sub-string up to the end is drawn.
 * White space is stripped at the beginning of the rows, the text is split at word boundaries or when new-line characters are encountered.
 * Words longer than the max width are slit at nearest character (i.e. no hyphenation). */
public void textBox(T) (NVGContext ctx, float x, float y, float breakRowWidth, const(T)[] str) if (is(T == char) || is(T == dchar)) {
  NVGstate* state = nvg__getState(ctx);
  if (state.fontId == FONS_INVALID) return;

  NVGTextRow[2] rows;
  auto oldAlign = state.textAlign;
  scope(exit) state.textAlign = oldAlign;
  auto halign = state.textAlign.horizontal;
  float lineh = 0;

  ctx.textMetrics(null, null, &lineh);
  state.textAlign.horizontal = NVGTextAlign.H.Left;
  for (;;) {
    auto rres = ctx.textBreakLines(str, breakRowWidth, rows[]);
    //{ import core.stdc.stdio : printf; printf("slen=%u; rlen=%u; bw=%f\n", cast(uint)str.length, cast(uint)rres.length, cast(double)breakRowWidth); }
    if (rres.length == 0) break;
    foreach (ref row; rres) {
      final switch (halign) {
        case NVGTextAlign.H.Left: ctx.text(x, y, row.row!T); break;
        case NVGTextAlign.H.Center: ctx.text(x+breakRowWidth*0.5f-row.width*0.5f, y, row.row!T); break;
        case NVGTextAlign.H.Right: ctx.text(x+breakRowWidth-row.width, y, row.row!T); break;
      }
      y += lineh*state.lineHeight;
    }
    str = rres[$-1].rest!T;
  }
}

private template isGoodPositionDelegate(DG) {
  private DG dg;
  static if (is(typeof({ NVGGlyphPosition pos; bool res = dg(pos); })) ||
             is(typeof({ NVGGlyphPosition pos; dg(pos); })))
    enum isGoodPositionDelegate = true;
  else
    enum isGoodPositionDelegate = false;
}

/** Calculates the glyph x positions of the specified text. If end is specified only the sub-string will be used.
 * Measured values are returned in local coordinate space.
 */
public NVGGlyphPosition[] textGlyphPositions(T) (NVGContext ctx, float x, float y, const(T)[] str, NVGGlyphPosition[] positions) if (is(T == char) || is(T == dchar)) {
  if (str.length == 0 || positions.length == 0) return positions[0..0];
  size_t posnum;
  auto len = ctx.textGlyphPositions(x, y, str, (in ref NVGGlyphPosition pos) {
    positions.ptr[posnum++] = pos;
    return (posnum < positions.length);
  });
  return positions[0..len];
}

/// Ditto.
public int textGlyphPositions(T, DG) (NVGContext ctx, float x, float y, const(T)[] str, scope DG dg)
if (isGoodPositionDelegate!DG && (is(T == char) || is(T == dchar)))
{
  import std.traits : ReturnType;
  static if (is(ReturnType!dg == void)) enum RetBool = false; else enum RetBool = true;

  NVGstate* state = nvg__getState(ctx);
  float scale = nvg__getFontScale(state)*ctx.devicePxRatio;
  float invscale = 1.0f/scale;
  FONStextIter iter, prevIter;
  FONSquad q;
  int npos = 0;

  if (str.length == 0) return 0;

  fonsSetSize(ctx.fs, state.fontSize*scale);
  fonsSetSpacing(ctx.fs, state.letterSpacing*scale);
  fonsSetBlur(ctx.fs, state.fontBlur*scale);
  fonsSetAlign(ctx.fs, state.textAlign);
  fonsSetFont(ctx.fs, state.fontId);

  fonsTextIterInit(ctx.fs, &iter, x*scale, y*scale, str);
  prevIter = iter;
  while (fonsTextIterNext(ctx.fs, &iter, &q)) {
    if (iter.prevGlyphIndex < 0 && nvg__allocTextAtlas(ctx)) { // can not retrieve glyph?
      iter = prevIter;
      fonsTextIterNext(ctx.fs, &iter, &q); // try again
    }
    prevIter = iter;
    NVGGlyphPosition position = void; //WARNING!
    static if (is(T == char)) {
      position.strpos = cast(size_t)(iter.str-str.ptr);
    } else {
      position.strpos = cast(size_t)(iter.dstr-str.ptr);
    }
    position.x = iter.x*invscale;
    position.minx = nvg__min(iter.x, q.x0)*invscale;
    position.maxx = nvg__max(iter.nextx, q.x1)*invscale;
    ++npos;
    static if (RetBool) { if (!dg(position)) return npos; } else dg(position);
  }

  return npos;
}

private template isGoodRowDelegate(DG) {
  private DG dg;
  static if (is(typeof({ NVGTextRow row; bool res = dg(row); })) ||
             is(typeof({ NVGTextRow row; dg(row); })))
    enum isGoodRowDelegate = true;
  else
    enum isGoodRowDelegate = false;
}

/** Breaks the specified text into lines.
 * White space is stripped at the beginning of the rows, the text is split at word boundaries or when new-line characters are encountered.
 * Words longer than the max width are slit at nearest character (i.e. no hyphenation).
 */
public NVGTextRow[] textBreakLines(T) (NVGContext ctx, const(T)[] str, float breakRowWidth, NVGTextRow[] rows) if (is(T == char) || is(T == dchar)) {
  if (rows.length == 0) return rows;
  if (rows.length > int.max-1) rows = rows[0..int.max-1];
  int nrow = 0;
  auto count = ctx.textBreakLines(str, breakRowWidth, (in ref NVGTextRow row) {
    rows[nrow++] = row;
    return (nrow < rows.length);
  });
  return rows[0..count];
}

/// Ditto.
public int textBreakLines(T, DG) (NVGContext ctx, const(T)[] str, float breakRowWidth, scope DG dg)
if (isGoodRowDelegate!DG && (is(T == char) || is(T == dchar)))
{
  import std.traits : ReturnType;
  static if (is(ReturnType!dg == void)) enum RetBool = false; else enum RetBool = true;

  enum NVGcodepointType : int {
    Space,
    NewLine,
    Char,
  }

  NVGstate* state = nvg__getState(ctx);
  float scale = nvg__getFontScale(state)*ctx.devicePxRatio;
  float invscale = 1.0f/scale;
  FONStextIter iter, prevIter;
  FONSquad q;
  int nrows = 0;
  float rowStartX = 0;
  float rowWidth = 0;
  float rowMinX = 0;
  float rowMaxX = 0;
  int rowStart = 0;
  int rowEnd = 0;
  int wordStart = 0;
  float wordStartX = 0;
  float wordMinX = 0;
  int breakEnd = 0;
  float breakWidth = 0;
  float breakMaxX = 0;
  int type = NVGcodepointType.Space, ptype = NVGcodepointType.Space;
  uint pcodepoint = 0;

  if (state.fontId == FONS_INVALID) return 0;
  if (str.length == 0 || dg is null) return 0;

  fonsSetSize(ctx.fs, state.fontSize*scale);
  fonsSetSpacing(ctx.fs, state.letterSpacing*scale);
  fonsSetBlur(ctx.fs, state.fontBlur*scale);
  fonsSetAlign(ctx.fs, state.textAlign);
  fonsSetFont(ctx.fs, state.fontId);

  breakRowWidth *= scale;

  enum Phase {
    Normal, // searching for breaking point
    SkipBlanks, // skip leading blanks
  }
  Phase phase = Phase.SkipBlanks; // don't skip blanks on first line

  fonsTextIterInit(ctx.fs, &iter, 0, 0, str);
  prevIter = iter;
  while (fonsTextIterNext(ctx.fs, &iter, &q)) {
    if (iter.prevGlyphIndex < 0 && nvg__allocTextAtlas(ctx)) { // can not retrieve glyph?
      iter = prevIter;
      fonsTextIterNext(ctx.fs, &iter, &q); // try again
    }
    prevIter = iter;
    switch (iter.codepoint) {
      case 9: // \t
      case 11: // \v
      case 12: // \f
      case 32: // space
      case 0x00a0: // NBSP
        type = NVGcodepointType.Space;
        break;
      case 10: // \n
        type = (pcodepoint == 13 ? NVGcodepointType.Space : NVGcodepointType.NewLine);
        break;
      case 13: // \r
        type = (pcodepoint == 10 ? NVGcodepointType.Space : NVGcodepointType.NewLine);
        break;
      case 0x0085: // NEL
      case 0x2028: // Line Separator
      case 0x2029: // Paragraph Separator
        type = NVGcodepointType.NewLine;
        break;
      default:
        type = NVGcodepointType.Char;
        break;
    }
    if (phase == Phase.SkipBlanks) {
      // fix row start
      rowStart = cast(int)(iter.string!T-str.ptr);
      rowEnd = rowStart;
      rowStartX = iter.x;
      rowWidth = iter.nextx-rowStartX; // q.x1-rowStartX;
      rowMinX = q.x0-rowStartX;
      rowMaxX = q.x1-rowStartX;
      wordStart = rowStart;
      wordStartX = iter.x;
      wordMinX = q.x0-rowStartX;
      breakEnd = rowStart;
      breakWidth = 0.0;
      breakMaxX = 0.0;
      if (type == NVGcodepointType.Space) continue;
      phase = Phase.Normal;
    }

    if (type == NVGcodepointType.NewLine) {
      // always handle new lines
      NVGTextRow row;
      row.string!T = str;
      row.start = rowStart;
      row.end = rowEnd;
      row.width = rowWidth*invscale;
      row.minx = rowMinX*invscale;
      row.maxx = rowMaxX*invscale;
      ++nrows;
      static if (RetBool) { if (!dg(row)) return nrows; } else dg(row);
      phase = Phase.SkipBlanks;
    } else {
      float nextWidth = iter.nextx-rowStartX;
      // track last non-white space character
      if (type == NVGcodepointType.Char) {
        rowEnd = cast(int)(iter.nextp!T-str.ptr);
        rowWidth = iter.nextx-rowStartX;
        rowMaxX = q.x1-rowStartX;
      }
      // track last end of a word
      if (ptype == NVGcodepointType.Char && type == NVGcodepointType.Space) {
        breakEnd = cast(int)(iter.string!T-str.ptr);
        breakWidth = rowWidth;
        breakMaxX = rowMaxX;
      }
      // track last beginning of a word
      if (ptype == NVGcodepointType.Space && type == NVGcodepointType.Char) {
        wordStart = cast(int)(iter.string!T-str.ptr);
        wordStartX = iter.x;
        wordMinX = q.x0-rowStartX;
      }
      // break to new line when a character is beyond break width
      if (type == NVGcodepointType.Char && nextWidth > breakRowWidth) {
        // the run length is too long, need to break to new line
        NVGTextRow row;
        row.string!T = str;
        if (breakEnd == rowStart) {
          // the current word is longer than the row length, just break it from here
          row.start = rowStart;
          row.end = cast(int)(iter.string!T-str.ptr);
          row.width = rowWidth*invscale;
          row.minx = rowMinX*invscale;
          row.maxx = rowMaxX*invscale;
          ++nrows;
          static if (RetBool) { if (!dg(row)) return nrows; } else dg(row);
          rowStartX = iter.x;
          rowStart = cast(int)(iter.string!T-str.ptr);
          rowEnd = cast(int)(iter.nextp!T-str.ptr);
          rowWidth = iter.nextx-rowStartX;
          rowMinX = q.x0-rowStartX;
          rowMaxX = q.x1-rowStartX;
          wordStart = rowStart;
          wordStartX = iter.x;
          wordMinX = q.x0-rowStartX;
        } else {
          // break the line from the end of the last word, and start new line from the beginning of the new
          //{ import core.stdc.stdio : printf; printf("rowStart=%u; rowEnd=%u; breakEnd=%u; len=%u\n", rowStart, rowEnd, breakEnd, cast(uint)str.length); }
          row.start = rowStart;
          row.end = breakEnd;
          row.width = breakWidth*invscale;
          row.minx = rowMinX*invscale;
          row.maxx = breakMaxX*invscale;
          ++nrows;
          static if (RetBool) { if (!dg(row)) return nrows; } else dg(row);
          rowStartX = wordStartX;
          rowStart = wordStart;
          rowEnd = cast(int)(iter.nextp!T-str.ptr);
          rowWidth = iter.nextx-rowStartX;
          rowMinX = wordMinX;
          rowMaxX = q.x1-rowStartX;
          // no change to the word start
        }
        // set null break point
        breakEnd = rowStart;
        breakWidth = 0.0;
        breakMaxX = 0.0;
      }
    }

    pcodepoint = iter.codepoint;
    ptype = type;
  }

  // break the line from the end of the last word, and start new line from the beginning of the new
  if (phase != Phase.SkipBlanks && rowStart < str.length) {
    //{ import core.stdc.stdio : printf; printf("  rowStart=%u; len=%u\n", rowStart, cast(uint)str.length); }
    NVGTextRow row;
    row.string!T = str;
    row.start = rowStart;
    row.end = cast(int)str.length;
    row.width = rowWidth*invscale;
    row.minx = rowMinX*invscale;
    row.maxx = rowMaxX*invscale;
    ++nrows;
    static if (RetBool) { if (!dg(row)) return nrows; } else dg(row);
  }

  return nrows;
}

/** Returns iterator which you can use to calculate text bounds and advancement.
 * This is usable when you need to do some text layouting with wrapping, to avoid
 * guesswork ("will advancement for this space stay the same?"), and Schlemiel's
 * algorithm. Note that you can copy the returned struct to save iterator state.
 *
 * You can check if iterator is valid with `valid` property, put new chars with
 * `put()` method, get current advance with `advance` property, and current
 * bounds with `getBounds(ref float[4] bounds)` method.
 *
 * WARNING! Don't change font parameters while iterating! Or use `restoreFont()`
 *          method.
 */
public struct TextBoundsIterator {
private:
  NVGContext ctx;
  FonsTextBoundsIterator fsiter; // fontstash iterator
  float scale, invscale, xscaled, yscaled;
  // font settings
  float fsSize, fsSpacing, fsBlur;
  int fsFontId;
  NVGTextAlign fsAlign;

public:
  this (NVGContext actx, float ax, float ay) { reset(actx, ax, ay); }

  void reset (NVGContext actx, float ax, float ay) {
    fsiter = fsiter.init;
    this = this.init;
    if (actx is null) return;
    NVGstate* state = nvg__getState(actx);
    if (state is null) return;
    if (state.fontId == FONS_INVALID) { ctx = null; return; }

    ctx = actx;
    scale = nvg__getFontScale(state)*ctx.devicePxRatio;
    invscale = 1.0f/scale;

    fsSize = state.fontSize*scale;
    fsSpacing = state.letterSpacing*scale;
    fsBlur = state.fontBlur*scale;
    fsAlign = state.textAlign;
    fsFontId = state.fontId;
    restoreFont();

    xscaled = ax*scale;
    yscaled = ay*scale;
    fsiter.reset(ctx.fs, xscaled, yscaled);
  }

  /// Restart iteration. Will not restore font.
  void restart () {
    if (ctx !is null) fsiter.reset(ctx.fs, xscaled, yscaled);
  }

  /// Restore font settings for the context.
  void restoreFont () {
    if (ctx !is null) {
      fonsSetSize(ctx.fs, fsSize);
      fonsSetSpacing(ctx.fs, fsSpacing);
      fonsSetBlur(ctx.fs, fsBlur);
      fonsSetAlign(ctx.fs, fsAlign);
      fonsSetFont(ctx.fs, fsFontId);
    }
  }

  /// Is this iterator valid?
  @property bool valid () const pure nothrow @safe @nogc { pragma(inline, true); return (ctx !is null); }

  /// Add chars.
  void put(T) (const(T)[] str...) if (is(T == char) || is(T == dchar)) {
    if (ctx !is null) fsiter.put(str[]);
  }

  /// Return current advance
  @property float advance () const pure nothrow @safe @nogc { pragma(inline, true); return (ctx !is null ? fsiter.advance*invscale : 0); }

  /// Return current text bounds.
  void getBounds (ref float[4] bounds) {
    if (ctx !is null) {
      fsiter.getBounds(bounds);
      fonsLineBounds(ctx.fs, yscaled, &bounds[1], &bounds[3]);
      bounds[0] *= invscale;
      bounds[1] *= invscale;
      bounds[2] *= invscale;
      bounds[3] *= invscale;
    } else {
      bounds[] = 0;
    }
  }

  /// Return current horizontal text bounds.
  void getHBounds (out float xmin, out float xmax) {
    if (ctx !is null) {
      fsiter.getHBounds(xmin, xmax);
      xmin *= invscale;
      xmax *= invscale;
    }
  }

  /// Return current vertical text bounds.
  void getVBounds (out float ymin, out float ymax) {
    if (ctx !is null) {
      //fsiter.getVBounds(ymin, ymax);
      fonsLineBounds(ctx.fs, yscaled, &ymin, &ymax);
      ymin *= invscale;
      ymax *= invscale;
    }
  }
}

/** Measures the specified text string. Parameter bounds should be a pointer to float[4],
 * if the bounding box of the text should be returned. The bounds value are [xmin, ymin, xmax, ymax]
 * Returns the horizontal advance of the measured text (i.e. where the next character should drawn).
 * Measured values are returned in local coordinate space.
 */
public float textBounds(T) (NVGContext ctx, float x, float y, const(T)[] str, float[] bounds) if (is(T == char) || is(T == dchar)) {
  NVGstate* state = nvg__getState(ctx);
  float scale = nvg__getFontScale(state)*ctx.devicePxRatio;
  float invscale = 1.0f/scale;
  float width;

  if (state.fontId == FONS_INVALID) {
    bounds[] = 0;
    return 0;
  }

  fonsSetSize(ctx.fs, state.fontSize*scale);
  fonsSetSpacing(ctx.fs, state.letterSpacing*scale);
  fonsSetBlur(ctx.fs, state.fontBlur*scale);
  fonsSetAlign(ctx.fs, state.textAlign);
  fonsSetFont(ctx.fs, state.fontId);

  float[4] b = void;
  width = fonsTextBounds(ctx.fs, x*scale, y*scale, str, b[]);
  if (bounds.length) {
    // use line bounds for height
    fonsLineBounds(ctx.fs, y*scale, b.ptr+1, b.ptr+3);
    if (bounds.length > 0) bounds.ptr[0] = b.ptr[0]*invscale;
    if (bounds.length > 1) bounds.ptr[1] = b.ptr[1]*invscale;
    if (bounds.length > 2) bounds.ptr[2] = b.ptr[2]*invscale;
    if (bounds.length > 3) bounds.ptr[3] = b.ptr[3]*invscale;
  }
  return width*invscale;
}

/// Ditto.
public void textBoxBounds(T) (NVGContext ctx, float x, float y, float breakRowWidth, const(T)[] str, float[] bounds) if (is(T == char) || is(T == dchar)) {
  NVGstate* state = nvg__getState(ctx);
  NVGTextRow[2] rows;
  float scale = nvg__getFontScale(state)*ctx.devicePxRatio;
  float invscale = 1.0f/scale;
  float lineh = 0, rminy = 0, rmaxy = 0;
  float minx, miny, maxx, maxy;

  if (state.fontId == FONS_INVALID) {
    bounds[] = 0;
    return;
  }

  auto oldAlign = state.textAlign;
  scope(exit) state.textAlign = oldAlign;
  auto halign = state.textAlign.horizontal;

  ctx.textMetrics(null, null, &lineh);
  state.textAlign.horizontal = NVGTextAlign.H.Left;

  minx = maxx = x;
  miny = maxy = y;

  fonsSetSize(ctx.fs, state.fontSize*scale);
  fonsSetSpacing(ctx.fs, state.letterSpacing*scale);
  fonsSetBlur(ctx.fs, state.fontBlur*scale);
  fonsSetAlign(ctx.fs, state.textAlign);
  fonsSetFont(ctx.fs, state.fontId);
  fonsLineBounds(ctx.fs, 0, &rminy, &rmaxy);
  rminy *= invscale;
  rmaxy *= invscale;

  for (;;) {
    auto rres = ctx.textBreakLines(str, breakRowWidth, rows[]);
    if (rres.length == 0) break;
    foreach (ref row; rres) {
      float rminx, rmaxx, dx = 0;
      // horizontal bounds
      final switch (halign) {
        case NVGTextAlign.H.Left: dx = 0; break;
        case NVGTextAlign.H.Center: dx = breakRowWidth*0.5f-row.width*0.5f; break;
        case NVGTextAlign.H.Right: dx = breakRowWidth-row.width; break;
      }
      rminx = x+row.minx+dx;
      rmaxx = x+row.maxx+dx;
      minx = nvg__min(minx, rminx);
      maxx = nvg__max(maxx, rmaxx);
      // vertical bounds
      miny = nvg__min(miny, y+rminy);
      maxy = nvg__max(maxy, y+rmaxy);
      y += lineh*state.lineHeight;
    }
    str = rres[$-1].rest!T;
  }

  if (bounds.length) {
    if (bounds.length > 0) bounds.ptr[0] = minx;
    if (bounds.length > 1) bounds.ptr[1] = miny;
    if (bounds.length > 2) bounds.ptr[2] = maxx;
    if (bounds.length > 3) bounds.ptr[3] = maxy;
  }
}

/// Returns the vertical metrics based on the current text style. Measured values are returned in local coordinate space.
public void textMetrics (NVGContext ctx, float* ascender, float* descender, float* lineh) {
  NVGstate* state = nvg__getState(ctx);
  float scale = nvg__getFontScale(state)*ctx.devicePxRatio;
  float invscale = 1.0f/scale;

  if (state.fontId == FONS_INVALID) return;

  fonsSetSize(ctx.fs, state.fontSize*scale);
  fonsSetSpacing(ctx.fs, state.letterSpacing*scale);
  fonsSetBlur(ctx.fs, state.fontBlur*scale);
  fonsSetAlign(ctx.fs, state.textAlign);
  fonsSetFont(ctx.fs, state.fontId);

  fonsVertMetrics(ctx.fs, ascender, descender, lineh);
  if (ascender !is null) *ascender *= invscale;
  if (descender !is null) *descender *= invscale;
  if (lineh !is null) *lineh *= invscale;
}


// ////////////////////////////////////////////////////////////////////////// //
// fontstash
// ////////////////////////////////////////////////////////////////////////// //
import core.stdc.stdlib : malloc, realloc, free;
import core.stdc.string : memset, memcpy, strncpy, strcmp, strlen;
import core.stdc.stdio : FILE, fopen, fclose, fseek, ftell, fread, SEEK_END, SEEK_SET;

public:
// welcome to version hell!
version(nanovg_force_detect) {} else version(nanovg_use_freetype) { version = nanovg_use_freetype_ii; }
version(nanovg_ignore_iv_stb_ttf) enum nanovg_ignore_iv_stb_ttf = true; else enum nanovg_ignore_iv_stb_ttf = false;
//version(nanovg_ignore_mono);

version(nanovg_use_freetype_ii) {
  enum HasAST = false;
  //pragma(msg, "iv.freetype: forced");
} else {
  static if (!nanovg_ignore_iv_stb_ttf && __traits(compiles, { import iv.stb.ttf; })) {
    import iv.stb.ttf;
    enum HasAST = true;
    //pragma(msg, "iv.stb.ttf");
  } else static if (__traits(compiles, { import arsd.ttf; })) {
    import arsd.ttf;
    enum HasAST = true;
    //pragma(msg, "arsd.ttf");
  } else static if (__traits(compiles, { import stb_truetype; })) {
    import stb_truetype;
    enum HasAST = true;
    //pragma(msg, "stb_truetype");
  } else static if (__traits(compiles, { import iv.freetype; })) {
    import iv.freetype;
    enum HasAST = false;
    //pragma(msg, "iv.freetype");
  } else {
    static assert(0, "no stb_ttf/iv.freetype found!");
  }
}

//version = nanovg_kill_font_blur;


// ////////////////////////////////////////////////////////////////////////// //
//version = nanovg_ft_mono;

enum FONS_INVALID = -1;

alias FONSflags = int;
enum /*FONSflags*/ {
  FONS_ZERO_TOPLEFT    = 1<<0,
  FONS_ZERO_BOTTOMLEFT = 1<<1,
}

/+
alias FONSalign = int;
enum /*FONSalign*/ {
  // Horizontal align
  FONS_ALIGN_LEFT   = 1<<0, // Default
  FONS_ALIGN_CENTER   = 1<<1,
  FONS_ALIGN_RIGHT  = 1<<2,
  // Vertical align
  FONS_ALIGN_TOP    = 1<<3,
  FONS_ALIGN_MIDDLE = 1<<4,
  FONS_ALIGN_BOTTOM = 1<<5,
  FONS_ALIGN_BASELINE = 1<<6, // Default
}
+/

alias FONSerrorCode = int;
enum /*FONSerrorCode*/ {
  // Font atlas is full.
  FONS_ATLAS_FULL = 1,
  // Scratch memory used to render glyphs is full, requested size reported in 'val', you may need to bump up FONS_SCRATCH_BUF_SIZE.
  FONS_SCRATCH_FULL = 2,
  // Calls to fonsPushState has created too large stack, if you need deep state stack bump up FONS_MAX_STATES.
  FONS_STATES_OVERFLOW = 3,
  // Trying to pop too many states fonsPopState().
  FONS_STATES_UNDERFLOW = 4,
}

struct FONSparams {
  int width, height;
  ubyte flags;
  void* userPtr;
  bool function (void* uptr, int width, int height) renderCreate;
  int function (void* uptr, int width, int height) renderResize;
  void function (void* uptr, int* rect, const(ubyte)* data) renderUpdate;
  void function (void* uptr, const(float)* verts, const(float)* tcoords, const(uint)* colors, int nverts) renderDraw;
  void function (void* uptr) renderDelete;
}

struct FONSquad {
  float x0=0, y0=0, s0=0, t0=0;
  float x1=0, y1=0, s1=0, t1=0;
}

struct FONStextIter {
  float x=0, y=0, nextx=0, nexty=0, scale=0, spacing=0;
  uint codepoint;
  short isize, iblur;
  FONSfont* font;
  int prevGlyphIndex;
  union {
    // for char
    struct {
      const(char)* str;
      const(char)* next;
      const(char)* end;
      uint utf8state;
    }
    // for dchar
    struct {
      const(dchar)* dstr;
      const(dchar)* dnext;
      const(dchar)* dend;
    }
  }
  bool isChar;
  @property const(T)* string(T) () const pure nothrow @nogc if (is(T == char) || is(T == dchar)) {
    pragma(inline, true);
    static if (is(T == char)) return str; else return dstr;
  }
  @property const(T)* nextp(T) () const pure nothrow @nogc if (is(T == char) || is(T == dchar)) {
    pragma(inline, true);
    static if (is(T == char)) return next; else return dnext;
  }
  @property const(T)* endp(T) () const pure nothrow @nogc if (is(T == char) || is(T == dchar)) {
    pragma(inline, true);
    static if (is(T == char)) return end; else return dend;
  }
  ~this () { pragma(inline, true); if (isChar) { str = next = end = null; utf8state = 0; } else { dstr = dnext = dend = null; } }
}


// ////////////////////////////////////////////////////////////////////////// //
//static if (!HasAST) version = nanovg_use_freetype_ii_x;

/*version(nanovg_use_freetype_ii_x)*/ static if (!HasAST) {
import iv.freetype;

struct FONSttFontImpl {
  FT_Face font;
  bool mono; // no aa?
}

__gshared FT_Library ftLibrary;

int fons__tt_init (FONScontext* context) {
  FT_Error ftError;
  //FONS_NOTUSED(context);
  ftError = FT_Init_FreeType(&ftLibrary);
  return (ftError == 0);
}

void fons__tt_setMono (FONScontext* context, FONSttFontImpl* font, bool v) {
  font.mono = v;
}

int fons__tt_loadFont (FONScontext* context, FONSttFontImpl* font, ubyte* data, int dataSize) {
  FT_Error ftError;
  //font.font.userdata = stash;
  ftError = FT_New_Memory_Face(ftLibrary, cast(const(FT_Byte)*)data, dataSize, 0, &font.font);
  return ftError == 0;
}

void fons__tt_getFontVMetrics (FONSttFontImpl* font, int* ascent, int* descent, int* lineGap) {
  *ascent = font.font.ascender;
  *descent = font.font.descender;
  *lineGap = font.font.height-(*ascent - *descent);
}

float fons__tt_getPixelHeightScale (FONSttFontImpl* font, float size) {
  return size/(font.font.ascender-font.font.descender);
}

int fons__tt_getGlyphIndex (FONSttFontImpl* font, int codepoint) {
  return FT_Get_Char_Index(font.font, codepoint);
}

int fons__tt_buildGlyphBitmap (FONSttFontImpl* font, int glyph, float size, float scale, int* advance, int* lsb, int* x0, int* y0, int* x1, int* y1) {
  FT_Error ftError;
  FT_GlyphSlot ftGlyph;
  //version(nanovg_ignore_mono) enum exflags = 0;
  //else version(nanovg_ft_mono) enum exflags = FT_LOAD_MONOCHROME; else enum exflags = 0;
  uint exflags = (font.mono ? FT_LOAD_MONOCHROME : 0);
  ftError = FT_Set_Pixel_Sizes(font.font, 0, cast(FT_UInt)(size*cast(float)font.font.units_per_EM/cast(float)(font.font.ascender-font.font.descender)));
  if (ftError) return 0;
  ftError = FT_Load_Glyph(font.font, glyph, FT_LOAD_RENDER|/*FT_LOAD_NO_AUTOHINT|*/exflags);
  if (ftError) return 0;
  ftError = FT_Get_Advance(font.font, glyph, FT_LOAD_NO_SCALE|/*FT_LOAD_NO_AUTOHINT|*/exflags, cast(FT_Fixed*)advance);
  if (ftError) return 0;
  ftGlyph = font.font.glyph;
  *lsb = cast(int)ftGlyph.metrics.horiBearingX;
  *x0 = ftGlyph.bitmap_left;
  *x1 = *x0+ftGlyph.bitmap.width;
  *y0 = -ftGlyph.bitmap_top;
  *y1 = *y0+ftGlyph.bitmap.rows;
  return 1;
}

void fons__tt_renderGlyphBitmap (FONSttFontImpl* font, ubyte* output, int outWidth, int outHeight, int outStride, float scaleX, float scaleY, int glyph) {
  FT_GlyphSlot ftGlyph = font.font.glyph;
  //FONS_NOTUSED(glyph); // glyph has already been loaded by fons__tt_buildGlyphBitmap
  //version(nanovg_ignore_mono) enum RenderAA = true;
  //else version(nanovg_ft_mono) enum RenderAA = false;
  //else enum RenderAA = true;
  if (font.mono) {
    auto src = ftGlyph.bitmap.buffer;
    auto dst = output;
    auto spt = ftGlyph.bitmap.pitch;
    if (spt < 0) spt = -spt;
    foreach (int y; 0..ftGlyph.bitmap.rows) {
      ubyte count = 0, b = 0;
      auto s = src;
      auto d = dst;
      foreach (int x; 0..ftGlyph.bitmap.width) {
        if (count-- == 0) { count = 7; b = *s++; } else b <<= 1;
        *d++ = (b&0x80 ? 255 : 0);
      }
      src += spt;
      dst += outStride;
    }
  } else {
    auto src = ftGlyph.bitmap.buffer;
    auto dst = output;
    auto spt = ftGlyph.bitmap.pitch;
    if (spt < 0) spt = -spt;
    foreach (int y; 0..ftGlyph.bitmap.rows) {
      import core.stdc.string : memcpy;
      //dst[0..ftGlyph.bitmap.width] = src[0..ftGlyph.bitmap.width];
      memcpy(dst, src, ftGlyph.bitmap.width);
      src += spt;
      dst += outStride;
    }
  }
}

int fons__tt_getGlyphKernAdvance (FONSttFontImpl* font, int glyph1, int glyph2) {
  FT_Vector ftKerning;
  FT_Get_Kerning(font.font, glyph1, glyph2, FT_KERNING_DEFAULT, &ftKerning);
  return cast(int)ftKerning.x;
}

} else {
// ////////////////////////////////////////////////////////////////////////// //
struct FONSttFontImpl {
  stbtt_fontinfo font;
}

int fons__tt_init (FONScontext* context) {
  return 1;
}

void fons__tt_setMono (FONScontext* context, FONSttFontImpl* font, bool v) {
}

int fons__tt_loadFont (FONScontext* context, FONSttFontImpl* font, ubyte* data, int dataSize) {
  int stbError;
  font.font.userdata = context;
  stbError = stbtt_InitFont(&font.font, data, 0);
  return stbError;
}

void fons__tt_getFontVMetrics (FONSttFontImpl* font, int* ascent, int* descent, int* lineGap) {
  stbtt_GetFontVMetrics(&font.font, ascent, descent, lineGap);
}

float fons__tt_getPixelHeightScale (FONSttFontImpl* font, float size) {
  return stbtt_ScaleForPixelHeight(&font.font, size);
}

int fons__tt_getGlyphIndex (FONSttFontImpl* font, int codepoint) {
  return stbtt_FindGlyphIndex(&font.font, codepoint);
}

int fons__tt_buildGlyphBitmap (FONSttFontImpl* font, int glyph, float size, float scale, int* advance, int* lsb, int* x0, int* y0, int* x1, int* y1) {
  stbtt_GetGlyphHMetrics(&font.font, glyph, advance, lsb);
  stbtt_GetGlyphBitmapBox(&font.font, glyph, scale, scale, x0, y0, x1, y1);
  return 1;
}

void fons__tt_renderGlyphBitmap (FONSttFontImpl* font, ubyte* output, int outWidth, int outHeight, int outStride, float scaleX, float scaleY, int glyph) {
  stbtt_MakeGlyphBitmap(&font.font, output, outWidth, outHeight, outStride, scaleX, scaleY, glyph);
}

int fons__tt_getGlyphKernAdvance (FONSttFontImpl* font, int glyph1, int glyph2) {
  return stbtt_GetGlyphKernAdvance(&font.font, glyph1, glyph2);
}

} // version


private:
enum FONS_SCRATCH_BUF_SIZE = 64000;
enum FONS_HASH_LUT_SIZE = 256;
enum FONS_INIT_FONTS = 4;
enum FONS_INIT_GLYPHS = 256;
enum FONS_INIT_ATLAS_NODES = 256;
enum FONS_VERTEX_COUNT = 1024;
enum FONS_MAX_STATES = 20;

uint fons__hashint() (uint a) {
  pragma(inline, true);
  a += ~(a<<15);
  a ^=  (a>>10);
  a +=  (a<<3);
  a ^=  (a>>6);
  a += ~(a<<11);
  a ^=  (a>>16);
  return a;
}

struct FONSglyph {
  uint codepoint;
  int index;
  int next;
  short size, blur;
  short x0, y0, x1, y1;
  short xadv, xoff, yoff;
}

struct FONSfont {
  FONSttFontImpl font;
  char[64] name;
  uint namelen;
  ubyte* data;
  int dataSize;
  ubyte freeData;
  float ascender;
  float descender;
  float lineh;
  FONSglyph* glyphs;
  int cglyphs;
  int nglyphs;
  int[FONS_HASH_LUT_SIZE] lut;
}

struct FONSstate {
  int font;
  NVGTextAlign talign;
  float size;
  uint color;
  float blur;
  float spacing;
}

struct FONSatlasNode {
  short x, y, width;
}

struct FONSatlas {
  int width, height;
  FONSatlasNode* nodes;
  int nnodes;
  int cnodes;
}

public struct FONScontext {
  FONSparams params;
  float itw, ith;
  ubyte* texData;
  int[4] dirtyRect;
  FONSfont** fonts;
  FONSatlas* atlas;
  int cfonts;
  int nfonts;
  float[FONS_VERTEX_COUNT*2] verts;
  float[FONS_VERTEX_COUNT*2] tcoords;
  uint[FONS_VERTEX_COUNT] colors;
  int nverts;
  ubyte* scratch;
  int nscratch;
  FONSstate[FONS_MAX_STATES] states;
  int nstates;
  void function (void* uptr, int error, int val) handleError;
  void* errorUptr;
}

void* fons__tmpalloc (size_t size, void* up) {
  ubyte* ptr;
  FONScontext* stash = cast(FONScontext*)up;
  // 16-byte align the returned pointer
  size = (size+0xf)&~0xf;
  if (stash.nscratch+cast(int)size > FONS_SCRATCH_BUF_SIZE) {
    if (stash.handleError) stash.handleError(stash.errorUptr, FONS_SCRATCH_FULL, stash.nscratch+cast(int)size);
    return null;
  }
  ptr = stash.scratch+stash.nscratch;
  stash.nscratch += cast(int)size;
  return ptr;
}

void fons__tmpfree (void* ptr, void* up) {
  // empty
}

// Copyright (c) 2008-2010 Bjoern Hoehrmann <bjoern@hoehrmann.de>
// See http://bjoern.hoehrmann.de/utf-8/decoder/dfa/ for details.

enum FONS_UTF8_ACCEPT = 0;
enum FONS_UTF8_REJECT = 12;

static immutable ubyte[364] utf8d = [
  // The first part of the table maps bytes to character classes that
  // to reduce the size of the transition table and create bitmasks.
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9,
  7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,  7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
  8, 8, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,  2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
  10, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 4, 3, 3, 11, 6, 6, 6, 5, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8,

  // The second part is a transition table that maps a combination
  // of a state of the automaton and a character class to a state.
  0, 12, 24, 36, 60, 96, 84, 12, 12, 12, 48, 72, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12,
  12, 0, 12, 12, 12, 12, 12, 0, 12, 0, 12, 12, 12, 24, 12, 12, 12, 12, 12, 24, 12, 24, 12, 12,
  12, 12, 12, 12, 12, 12, 12, 24, 12, 12, 12, 12, 12, 24, 12, 12, 12, 12, 12, 12, 12, 24, 12, 12,
  12, 12, 12, 12, 12, 12, 12, 36, 12, 36, 12, 12, 12, 36, 12, 12, 12, 12, 12, 36, 12, 36, 12, 12,
  12, 36, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12,
];

private enum DecUtfMixin(string state, string codep, string byte_) =
`{
  uint type_ = utf8d.ptr[`~byte_~`];
  `~codep~` = (`~state~` != FONS_UTF8_ACCEPT ? (`~byte_~`&0x3fu)|(`~codep~`<<6) : (0xff>>type_)&`~byte_~`);
  if ((`~state~` = utf8d.ptr[256+`~state~`+type_]) == FONS_UTF8_REJECT) {
    `~state~` = FONS_UTF8_ACCEPT;
    `~codep~` = '?';
  }
 }`;

/*
uint fons__decutf8 (uint* state, uint* codep, uint byte_) {
  pragma(inline, true);
  uint type = utf8d.ptr[byte_];
  *codep = (*state != FONS_UTF8_ACCEPT ? (byte_&0x3fu)|(*codep<<6) : (0xff>>type)&byte_);
  *state = utf8d.ptr[256 + *state+type];
  return *state;
}
*/

// Atlas based on Skyline Bin Packer by Jukka Jylänki
void fons__deleteAtlas (FONSatlas* atlas) {
  if (atlas is null) return;
  if (atlas.nodes !is null) free(atlas.nodes);
  free(atlas);
}

FONSatlas* fons__allocAtlas (int w, int h, int nnodes) {
  FONSatlas* atlas = null;

  // Allocate memory for the font stash.
  atlas = cast(FONSatlas*)malloc(FONSatlas.sizeof);
  if (atlas is null) goto error;
  memset(atlas, 0, FONSatlas.sizeof);

  atlas.width = w;
  atlas.height = h;

  // Allocate space for skyline nodes
  atlas.nodes = cast(FONSatlasNode*)malloc(FONSatlasNode.sizeof*nnodes);
  if (atlas.nodes is null) goto error;
  memset(atlas.nodes, 0, FONSatlasNode.sizeof*nnodes);
  atlas.nnodes = 0;
  atlas.cnodes = nnodes;

  // Init root node.
  atlas.nodes[0].x = 0;
  atlas.nodes[0].y = 0;
  atlas.nodes[0].width = cast(short)w;
  ++atlas.nnodes;

  return atlas;

error:
  if (atlas !is null) fons__deleteAtlas(atlas);
  return null;
}

bool fons__atlasInsertNode (FONSatlas* atlas, int idx, int x, int y, int w) {
  // Insert node
  if (atlas.nnodes+1 > atlas.cnodes) {
    atlas.cnodes = (atlas.cnodes == 0 ? 8 : atlas.cnodes*2);
    atlas.nodes = cast(FONSatlasNode*)realloc(atlas.nodes, FONSatlasNode.sizeof*atlas.cnodes);
    if (atlas.nodes is null) return false;
  }
  for (int i = atlas.nnodes; i > idx; --i) atlas.nodes[i] = atlas.nodes[i-1];
  atlas.nodes[idx].x = cast(short)x;
  atlas.nodes[idx].y = cast(short)y;
  atlas.nodes[idx].width = cast(short)w;
  ++atlas.nnodes;
  return 1;
}

void fons__atlasRemoveNode (FONSatlas* atlas, int idx) {
  if (atlas.nnodes == 0) return;
  for (int i = idx; i < atlas.nnodes-1; ++i) atlas.nodes[i] = atlas.nodes[i+1];
  --atlas.nnodes;
}

void fons__atlasExpand (FONSatlas* atlas, int w, int h) {
  // Insert node for empty space
  if (w > atlas.width) fons__atlasInsertNode(atlas, atlas.nnodes, atlas.width, 0, w-atlas.width);
  atlas.width = w;
  atlas.height = h;
}

void fons__atlasReset (FONSatlas* atlas, int w, int h) {
  atlas.width = w;
  atlas.height = h;
  atlas.nnodes = 0;
  // Init root node.
  atlas.nodes[0].x = 0;
  atlas.nodes[0].y = 0;
  atlas.nodes[0].width = cast(short)w;
  ++atlas.nnodes;
}

bool fons__atlasAddSkylineLevel (FONSatlas* atlas, int idx, int x, int y, int w, int h) {
  // Insert new node
  if (!fons__atlasInsertNode(atlas, idx, x, y+h, w)) return false;

  // Delete skyline segments that fall under the shadow of the new segment
  for (int i = idx+1; i < atlas.nnodes; ++i) {
    if (atlas.nodes[i].x < atlas.nodes[i-1].x+atlas.nodes[i-1].width) {
      int shrink = atlas.nodes[i-1].x+atlas.nodes[i-1].width-atlas.nodes[i].x;
      atlas.nodes[i].x += cast(short)shrink;
      atlas.nodes[i].width -= cast(short)shrink;
      if (atlas.nodes[i].width <= 0) {
        fons__atlasRemoveNode(atlas, i);
        --i;
      } else {
        break;
      }
    } else {
      break;
    }
  }

  // Merge same height skyline segments that are next to each other
  for (int i = 0; i < atlas.nnodes-1; ++i) {
    if (atlas.nodes[i].y == atlas.nodes[i+1].y) {
      atlas.nodes[i].width += atlas.nodes[i+1].width;
      fons__atlasRemoveNode(atlas, i+1);
      --i;
    }
  }

  return true;
}

int fons__atlasRectFits (FONSatlas* atlas, int i, int w, int h) {
  // Checks if there is enough space at the location of skyline span 'i',
  // and return the max height of all skyline spans under that at that location,
  // (think tetris block being dropped at that position). Or -1 if no space found.
  int x = atlas.nodes[i].x;
  int y = atlas.nodes[i].y;
  int spaceLeft;
  if (x+w > atlas.width) return -1;
  spaceLeft = w;
  while (spaceLeft > 0) {
    if (i == atlas.nnodes) return -1;
    y = nvg__max(y, atlas.nodes[i].y);
    if (y+h > atlas.height) return -1;
    spaceLeft -= atlas.nodes[i].width;
    ++i;
  }
  return y;
}

bool fons__atlasAddRect (FONSatlas* atlas, int rw, int rh, int* rx, int* ry) {
  int besth = atlas.height, bestw = atlas.width, besti = -1;
  int bestx = -1, besty = -1;

  // Bottom left fit heuristic.
  for (int i = 0; i < atlas.nnodes; ++i) {
    int y = fons__atlasRectFits(atlas, i, rw, rh);
    if (y != -1) {
      if (y+rh < besth || (y+rh == besth && atlas.nodes[i].width < bestw)) {
        besti = i;
        bestw = atlas.nodes[i].width;
        besth = y+rh;
        bestx = atlas.nodes[i].x;
        besty = y;
      }
    }
  }

  if (besti == -1) return false;

  // Perform the actual packing.
  if (!fons__atlasAddSkylineLevel(atlas, besti, bestx, besty, rw, rh)) return false;

  *rx = bestx;
  *ry = besty;

  return true;
}

void fons__addWhiteRect (FONScontext* stash, int w, int h) {
  int gx, gy;
  ubyte* dst;

  if (!fons__atlasAddRect(stash.atlas, w, h, &gx, &gy)) return;

  // Rasterize
  dst = &stash.texData[gx+gy*stash.params.width];
  foreach (int y; 0..h) {
    foreach (int x; 0..w) {
      dst[x] = 0xff;
    }
    dst += stash.params.width;
  }

  stash.dirtyRect.ptr[0] = nvg__min(stash.dirtyRect.ptr[0], gx);
  stash.dirtyRect.ptr[1] = nvg__min(stash.dirtyRect.ptr[1], gy);
  stash.dirtyRect.ptr[2] = nvg__max(stash.dirtyRect.ptr[2], gx+w);
  stash.dirtyRect.ptr[3] = nvg__max(stash.dirtyRect.ptr[3], gy+h);
}

public FONScontext* fonsCreateInternal (FONSparams* params) {
  FONScontext* stash = null;

  // Allocate memory for the font stash.
  stash = cast(FONScontext*)malloc(FONScontext.sizeof);
  if (stash is null) goto error;
  memset(stash, 0, FONScontext.sizeof);

  stash.params = *params;

  // Allocate scratch buffer.
  stash.scratch = cast(ubyte*)malloc(FONS_SCRATCH_BUF_SIZE);
  if (stash.scratch is null) goto error;

  // Initialize implementation library
  if (!fons__tt_init(stash)) goto error;

  if (stash.params.renderCreate !is null) {
    if (!stash.params.renderCreate(stash.params.userPtr, stash.params.width, stash.params.height)) goto error;
  }

  stash.atlas = fons__allocAtlas(stash.params.width, stash.params.height, FONS_INIT_ATLAS_NODES);
  if (stash.atlas is null) goto error;

  // Allocate space for fonts.
  stash.fonts = cast(FONSfont**)malloc((FONSfont*).sizeof*FONS_INIT_FONTS);
  if (stash.fonts is null) goto error;
  memset(stash.fonts, 0, (FONSfont*).sizeof*FONS_INIT_FONTS);
  stash.cfonts = FONS_INIT_FONTS;
  stash.nfonts = 0;

  // Create texture for the cache.
  stash.itw = 1.0f/stash.params.width;
  stash.ith = 1.0f/stash.params.height;
  stash.texData = cast(ubyte*)malloc(stash.params.width*stash.params.height);
  if (stash.texData is null) goto error;
  memset(stash.texData, 0, stash.params.width*stash.params.height);

  stash.dirtyRect.ptr[0] = stash.params.width;
  stash.dirtyRect.ptr[1] = stash.params.height;
  stash.dirtyRect.ptr[2] = 0;
  stash.dirtyRect.ptr[3] = 0;

  // Add white rect at 0, 0 for debug drawing.
  fons__addWhiteRect(stash, 2, 2);

  fonsPushState(stash);
  fonsClearState(stash);

  return stash;

error:
  fonsDeleteInternal(stash);
  return null;
}

FONSstate* fons__getState (FONScontext* stash) {
  pragma(inline, true);
  return &stash.states[stash.nstates-1];
}

public void fonsSetSize (FONScontext* stash, float size) {
  pragma(inline, true);
  fons__getState(stash).size = size;
}

public void fonsSetColor (FONScontext* stash, uint color) {
  pragma(inline, true);
  fons__getState(stash).color = color;
}

public void fonsSetSpacing (FONScontext* stash, float spacing) {
  pragma(inline, true);
  fons__getState(stash).spacing = spacing;
}

public void fonsSetBlur (FONScontext* stash, float blur) {
  pragma(inline, true);
  version(nanovg_kill_font_blur) blur = 0;
  fons__getState(stash).blur = blur;
}

public void fonsSetAlign (FONScontext* stash, NVGTextAlign talign) {
  pragma(inline, true);
  fons__getState(stash).talign = talign;
}

public void fonsSetFont (FONScontext* stash, int font) {
  pragma(inline, true);
  fons__getState(stash).font = font;
}

public void fonsPushState (FONScontext* stash) {
  if (stash.nstates >= FONS_MAX_STATES) {
    if (stash.handleError) stash.handleError(stash.errorUptr, FONS_STATES_OVERFLOW, 0);
    return;
  }
  if (stash.nstates > 0) memcpy(&stash.states[stash.nstates], &stash.states[stash.nstates-1], FONSstate.sizeof);
  ++stash.nstates;
}

public void fonsPopState (FONScontext* stash) {
  if (stash.nstates <= 1) {
    if (stash.handleError) stash.handleError(stash.errorUptr, FONS_STATES_UNDERFLOW, 0);
    return;
  }
  --stash.nstates;
}

public void fonsClearState (FONScontext* stash) {
  FONSstate* state = fons__getState(stash);
  state.size = 12.0f;
  state.color = 0xffffffff;
  state.font = 0;
  state.blur = 0;
  state.spacing = 0;
  state.talign.reset; //FONS_ALIGN_LEFT|FONS_ALIGN_BASELINE;
}

void fons__freeFont (FONSfont* font) {
  if (font is null) return;
  if (font.glyphs) free(font.glyphs);
  if (font.freeData && font.data) free(font.data);
  free(font);
}

int fons__allocFont (FONScontext* stash) {
  FONSfont* font = null;
  if (stash.nfonts+1 > stash.cfonts) {
    stash.cfonts = (stash.cfonts == 0 ? 8 : stash.cfonts*2);
    stash.fonts = cast(FONSfont**)realloc(stash.fonts, (FONSfont*).sizeof*stash.cfonts);
    if (stash.fonts is null) return -1;
  }
  font = cast(FONSfont*)malloc(FONSfont.sizeof);
  if (font is null) goto error;
  memset(font, 0, FONSfont.sizeof);

  font.glyphs = cast(FONSglyph*)malloc(FONSglyph.sizeof*FONS_INIT_GLYPHS);
  if (font.glyphs is null) goto error;
  font.cglyphs = FONS_INIT_GLYPHS;
  font.nglyphs = 0;

  stash.fonts[stash.nfonts++] = font;
  return stash.nfonts-1;

error:
  fons__freeFont(font);

  return FONS_INVALID;
}

private enum NoAlias = ":noaa";

public int fonsAddFont (FONScontext* stash, const(char)[] name, const(char)[] path) {
  import std.internal.cstring;

  FILE* fp = null;
  int dataSize = 0;
  ubyte* data = null;

  // if font path ends with ":noaa", add this to font name instead
  if (path.length >= NoAlias.length && path[$-NoAlias.length..$] == NoAlias) {
    path = path[0..$-NoAlias.length];
    if (name.length < NoAlias.length || name[$-NoAlias.length..$] != NoAlias) name = name.idup~":noaa";
  }

  if (path.length == 0) return FONS_INVALID;
  if (name.length == 0 || name == NoAlias) return FONS_INVALID;

  if (path.length && path[0] == '~') {
    import std.path : expandTilde;
    path = path.idup.expandTilde;
  }

  // Read in the font data.
  fp = fopen(path.tempCString, "rb");
  if (fp is null) goto error;
  fseek(fp, 0, SEEK_END);
  dataSize = cast(int)ftell(fp);
  fseek(fp, 0, SEEK_SET);
  data = cast(ubyte*)malloc(dataSize);
  if (data is null) goto error;
  fread(data, 1, dataSize, fp);
  fclose(fp);
  fp = null;

  return fonsAddFontMem(stash, name, data, dataSize, 1);

error:
  if (data) free(data);
  if (fp) fclose(fp);
  return FONS_INVALID;
}

public int fonsAddFontMem (FONScontext* stash, const(char)[] name, ubyte* data, int dataSize, int freeData) {
  int i, ascent, descent, fh, lineGap;
  FONSfont* font;

  if (name.length == 0 || name == NoAlias) return FONS_INVALID;

  int idx = fons__allocFont(stash);
  if (idx == FONS_INVALID) return FONS_INVALID;

  font = stash.fonts[idx];

  //strncpy(font.name.ptr, name, (font.name).sizeof);
  if (name.length > font.name.length-1) name = name[0..font.name.length-1];
  font.name[] = 0;
  font.name[0..name.length] = name[];
  font.namelen = cast(uint)name.length;

  // Init hash lookup.
  for (i = 0; i < FONS_HASH_LUT_SIZE; ++i) font.lut[i] = -1;

  // Read in the font data.
  font.dataSize = dataSize;
  font.data = data;
  font.freeData = cast(ubyte)freeData;

  if (name.length >= NoAlias.length && name[$-NoAlias.length..$] == NoAlias) {
    //{ import core.stdc.stdio : printf; printf("MONO: [%.*s]\n", cast(uint)name.length, name.ptr); }
    fons__tt_setMono(stash, &font.font, true);
  }

  // Init font
  stash.nscratch = 0;
  if (!fons__tt_loadFont(stash, &font.font, data, dataSize)) goto error;

  // Store normalized line height. The real line height is got
  // by multiplying the lineh by font size.
  fons__tt_getFontVMetrics( &font.font, &ascent, &descent, &lineGap);
  fh = ascent-descent;
  font.ascender = cast(float)ascent/cast(float)fh;
  font.descender = cast(float)descent/cast(float)fh;
  font.lineh = cast(float)(fh+lineGap)/cast(float)fh;

  return idx;

error:
  fons__freeFont(font);
  stash.nfonts--;
  return FONS_INVALID;
}

public int fonsGetFontByName (FONScontext* s, const(char)[] name) {
  foreach (immutable idx, FONSfont* font; s.fonts[0..s.nfonts]) {
    if (font.namelen == name.length && font.name[0..font.namelen] == name[]) return cast(int)idx;
  }
  // not found, try variations
  if (name.length >= NoAlias.length && name[$-NoAlias.length..$] == NoAlias) {
    // search for font name without ":noaa"
    name = name[0..$-NoAlias.length];
    foreach (immutable idx, FONSfont* font; s.fonts[0..s.nfonts]) {
      if (font.namelen == name.length && font.name[0..font.namelen] == name[]) return cast(int)idx;
    }
  } else {
    // search for font name with ":noaa"
    foreach (immutable idx, FONSfont* font; s.fonts[0..s.nfonts]) {
      if (font.namelen == name.length+NoAlias.length) {
        if (font.name[0..name.length] == name[] && font.name[name.length..font.namelen] == NoAlias) {
          //{ import std.stdio; writeln(font.name[0..name.length], " : ", name, " <", font.name[name.length..$], ">"); }
          return cast(int)idx;
        }
      }
    }
  }
  return FONS_INVALID;
}


FONSglyph* fons__allocGlyph (FONSfont* font) {
  if (font.nglyphs+1 > font.cglyphs) {
    font.cglyphs = (font.cglyphs == 0 ? 8 : font.cglyphs*2);
    font.glyphs = cast(FONSglyph*)realloc(font.glyphs, FONSglyph.sizeof*font.cglyphs);
    if (font.glyphs is null) return null;
  }
  ++font.nglyphs;
  return &font.glyphs[font.nglyphs-1];
}


// Based on Exponential blur, Jani Huhtanen, 2006

enum APREC = 16;
enum ZPREC = 7;

void fons__blurCols (ubyte* dst, int w, int h, int dstStride, int alpha) {
  foreach (int y; 0..h) {
    int z = 0; // force zero border
    foreach (int x; 1..w) {
      z += (alpha*((cast(int)(dst[x])<<ZPREC)-z))>>APREC;
      dst[x] = cast(ubyte)(z>>ZPREC);
    }
    dst[w-1] = 0; // force zero border
    z = 0;
    for (int x = w-2; x >= 0; --x) {
      z += (alpha*((cast(int)(dst[x])<<ZPREC)-z))>>APREC;
      dst[x] = cast(ubyte)(z>>ZPREC);
    }
    dst[0] = 0; // force zero border
    dst += dstStride;
  }
}

void fons__blurRows (ubyte* dst, int w, int h, int dstStride, int alpha) {
  foreach (int x; 0..w) {
    int z = 0; // force zero border
    for (int y = dstStride; y < h*dstStride; y += dstStride) {
      z += (alpha*((cast(int)(dst[y])<<ZPREC)-z))>>APREC;
      dst[y] = cast(ubyte)(z>>ZPREC);
    }
    dst[(h-1)*dstStride] = 0; // force zero border
    z = 0;
    for (int y = (h-2)*dstStride; y >= 0; y -= dstStride) {
      z += (alpha*((cast(int)(dst[y])<<ZPREC)-z))>>APREC;
      dst[y] = cast(ubyte)(z>>ZPREC);
    }
    dst[0] = 0; // force zero border
    ++dst;
  }
}


void fons__blur (FONScontext* stash, ubyte* dst, int w, int h, int dstStride, int blur) {
  import std.math : expf = exp;
  int alpha;
  float sigma;
  if (blur < 1) return;
  // Calculate the alpha such that 90% of the kernel is within the radius. (Kernel extends to infinity)
  sigma = cast(float)blur*0.57735f; // 1/sqrt(3)
  alpha = cast(int)((1<<APREC)*(1.0f-expf(-2.3f/(sigma+1.0f))));
  fons__blurRows(dst, w, h, dstStride, alpha);
  fons__blurCols(dst, w, h, dstStride, alpha);
  fons__blurRows(dst, w, h, dstStride, alpha);
  fons__blurCols(dst, w, h, dstStride, alpha);
  //fons__blurrows(dst, w, h, dstStride, alpha);
  //fons__blurcols(dst, w, h, dstStride, alpha);
}

FONSglyph* fons__getGlyph (FONScontext* stash, FONSfont* font, uint codepoint, short isize, short iblur) {
  int i, g, advance, lsb, x0, y0, x1, y1, gw, gh, gx, gy, x, y;
  float scale;
  FONSglyph* glyph = null;
  uint h;
  float size = isize/10.0f;
  int pad, added;
  ubyte* bdst;
  ubyte* dst;

  version(nanovg_kill_font_blur) iblur = 0;

  if (isize < 2) return null;
  if (iblur > 20) iblur = 20;
  pad = iblur+2;

  // Reset allocator.
  stash.nscratch = 0;

  // Find code point and size.
  h = fons__hashint(codepoint)&(FONS_HASH_LUT_SIZE-1);
  i = font.lut[h];
  while (i != -1) {
    if (font.glyphs[i].codepoint == codepoint && font.glyphs[i].size == isize && font.glyphs[i].blur == iblur) return &font.glyphs[i];
    i = font.glyphs[i].next;
  }

  // Could not find glyph, create it.
  scale = fons__tt_getPixelHeightScale(&font.font, size);
  g = fons__tt_getGlyphIndex(&font.font, codepoint);
  fons__tt_buildGlyphBitmap(&font.font, g, size, scale, &advance, &lsb, &x0, &y0, &x1, &y1);
  gw = x1-x0+pad*2;
  gh = y1-y0+pad*2;

  // Find free spot for the rect in the atlas
  added = fons__atlasAddRect(stash.atlas, gw, gh, &gx, &gy);
  if (added == 0 && stash.handleError !is null) {
    // Atlas is full, let the user to resize the atlas (or not), and try again.
    stash.handleError(stash.errorUptr, FONS_ATLAS_FULL, 0);
    added = fons__atlasAddRect(stash.atlas, gw, gh, &gx, &gy);
  }
  if (added == 0) return null;

  // Init glyph.
  glyph = fons__allocGlyph(font);
  glyph.codepoint = codepoint;
  glyph.size = isize;
  glyph.blur = iblur;
  glyph.index = g;
  glyph.x0 = cast(short)gx;
  glyph.y0 = cast(short)gy;
  glyph.x1 = cast(short)(glyph.x0+gw);
  glyph.y1 = cast(short)(glyph.y0+gh);
  glyph.xadv = cast(short)(scale*advance*10.0f);
  glyph.xoff = cast(short)(x0-pad);
  glyph.yoff = cast(short)(y0-pad);
  glyph.next = 0;

  // Insert char to hash lookup.
  glyph.next = font.lut[h];
  font.lut[h] = font.nglyphs-1;

  // Rasterize
  dst = &stash.texData[(glyph.x0+pad)+(glyph.y0+pad)*stash.params.width];
  fons__tt_renderGlyphBitmap(&font.font, dst, gw-pad*2, gh-pad*2, stash.params.width, scale, scale, g);

  // Make sure there is one pixel empty border.
  dst = &stash.texData[glyph.x0+glyph.y0*stash.params.width];
  for (y = 0; y < gh; y++) {
    dst[y*stash.params.width] = 0;
    dst[gw-1+y*stash.params.width] = 0;
  }
  for (x = 0; x < gw; x++) {
    dst[x] = 0;
    dst[x+(gh-1)*stash.params.width] = 0;
  }

  // Debug code to color the glyph background
  version(none) {
    ubyte* fdst = &stash.texData[glyph.x0+glyph.y0*stash.params.width];
    foreach (immutable yy; 0..gh) {
      foreach (immutable xx; 0..gw) {
        int a = cast(int)fdst[xx+yy*stash.params.width]+20;
        if (a > 255) a = 255;
        fdst[xx+yy*stash.params.width] = cast(ubyte)a;
      }
    }
  }

  // Blur
  if (iblur > 0) {
    stash.nscratch = 0;
    bdst = &stash.texData[glyph.x0+glyph.y0*stash.params.width];
    fons__blur(stash, bdst, gw, gh, stash.params.width, iblur);
  }

  stash.dirtyRect.ptr[0] = nvg__min(stash.dirtyRect.ptr[0], glyph.x0);
  stash.dirtyRect.ptr[1] = nvg__min(stash.dirtyRect.ptr[1], glyph.y0);
  stash.dirtyRect.ptr[2] = nvg__max(stash.dirtyRect.ptr[2], glyph.x1);
  stash.dirtyRect.ptr[3] = nvg__max(stash.dirtyRect.ptr[3], glyph.y1);

  return glyph;
}

void fons__getQuad (FONScontext* stash, FONSfont* font, int prevGlyphIndex, FONSglyph* glyph, float scale, float spacing, float* x, float* y, FONSquad* q) {
  float rx, ry, xoff, yoff, x0, y0, x1, y1;

  if (prevGlyphIndex >= 0) {
    float adv = fons__tt_getGlyphKernAdvance(&font.font, prevGlyphIndex, glyph.index)*scale;
    *x += cast(int)(adv+spacing+0.5f);
  }

  // Each glyph has 2px border to allow good interpolation,
  // one pixel to prevent leaking, and one to allow good interpolation for rendering.
  // Inset the texture region by one pixel for correct interpolation.
  xoff = cast(short)(glyph.xoff+1);
  yoff = cast(short)(glyph.yoff+1);
  x0 = cast(float)(glyph.x0+1);
  y0 = cast(float)(glyph.y0+1);
  x1 = cast(float)(glyph.x1-1);
  y1 = cast(float)(glyph.y1-1);

  if (stash.params.flags&FONS_ZERO_TOPLEFT) {
    rx = cast(float)cast(int)(*x+xoff);
    ry = cast(float)cast(int)(*y+yoff);

    q.x0 = rx;
    q.y0 = ry;
    q.x1 = rx+x1-x0;
    q.y1 = ry+y1-y0;

    q.s0 = x0*stash.itw;
    q.t0 = y0*stash.ith;
    q.s1 = x1*stash.itw;
    q.t1 = y1*stash.ith;
  } else {
    rx = cast(float)cast(int)(*x+xoff);
    ry = cast(float)cast(int)(*y-yoff);

    q.x0 = rx;
    q.y0 = ry;
    q.x1 = rx+x1-x0;
    q.y1 = ry-y1+y0;

    q.s0 = x0*stash.itw;
    q.t0 = y0*stash.ith;
    q.s1 = x1*stash.itw;
    q.t1 = y1*stash.ith;
  }

  *x += cast(int)(glyph.xadv/10.0f+0.5f);
}

void fons__flush (FONScontext* stash) {
  // Flush texture
  if (stash.dirtyRect.ptr[0] < stash.dirtyRect.ptr[2] && stash.dirtyRect.ptr[1] < stash.dirtyRect.ptr[3]) {
    if (stash.params.renderUpdate !is null) stash.params.renderUpdate(stash.params.userPtr, stash.dirtyRect.ptr, stash.texData);
    // Reset dirty rect
    stash.dirtyRect.ptr[0] = stash.params.width;
    stash.dirtyRect.ptr[1] = stash.params.height;
    stash.dirtyRect.ptr[2] = 0;
    stash.dirtyRect.ptr[3] = 0;
  }

  // Flush triangles
  if (stash.nverts > 0) {
    if (stash.params.renderDraw !is null) stash.params.renderDraw(stash.params.userPtr, stash.verts.ptr, stash.tcoords.ptr, stash.colors.ptr, stash.nverts);
    stash.nverts = 0;
  }
}

void fons__vertex (FONScontext* stash, float x, float y, float s, float t, uint c) {
  stash.verts[stash.nverts*2+0] = x;
  stash.verts[stash.nverts*2+1] = y;
  stash.tcoords[stash.nverts*2+0] = s;
  stash.tcoords[stash.nverts*2+1] = t;
  stash.colors[stash.nverts] = c;
  ++stash.nverts;
}

float fons__getVertAlign (FONScontext* stash, FONSfont* font, NVGTextAlign talign, short isize) {
  if (stash.params.flags&FONS_ZERO_TOPLEFT) {
    final switch (talign.vertical) {
      case NVGTextAlign.V.Top: return font.ascender*cast(float)isize/10.0f;
      case NVGTextAlign.V.Middle: return (font.ascender+font.descender)/2.0f*cast(float)isize/10.0f;
      case NVGTextAlign.V.Baseline: return 0.0f;
      case NVGTextAlign.V.Bottom: return font.descender*cast(float)isize/10.0f;
    }
  } else {
    final switch (talign.vertical) {
      case NVGTextAlign.V.Top: return -font.ascender*cast(float)isize/10.0f;
      case NVGTextAlign.V.Middle: return -(font.ascender+font.descender)/2.0f*cast(float)isize/10.0f;
      case NVGTextAlign.V.Baseline: return 0.0f;
      case NVGTextAlign.V.Bottom: return -font.descender*cast(float)isize/10.0f;
    }
  }
  assert(0);
}

/+k8: not used
public float fonsDrawText (FONScontext* stash, float x, float y, const(char)* str, const(char)* end) {
  FONSstate* state = fons__getState(stash);
  uint codepoint;
  uint utf8state = 0;
  FONSglyph* glyph = null;
  FONSquad q;
  int prevGlyphIndex = -1;
  short isize = cast(short)(state.size*10.0f);
  short iblur = cast(short)state.blur;
  float scale;
  FONSfont* font;
  float width;

  if (stash is null || str is null) return x;
  if (state.font < 0 || state.font >= stash.nfonts) return x;
  font = stash.fonts[state.font];
  if (font.data is null) return x;

  scale = fons__tt_getPixelHeightScale(&font.font, cast(float)isize/10.0f);

  if (end is null) end = str+strlen(str);

  // Align horizontally
  if (state.align_&FONS_ALIGN_LEFT) {
    // empty
  } else if (state.align_&FONS_ALIGN_RIGHT) {
    width = fonsTextBounds(stash, x, y, str, end, null);
    x -= width;
  } else if (state.align_&FONS_ALIGN_CENTER) {
    width = fonsTextBounds(stash, x, y, str, end, null);
    x -= width*0.5f;
  }
  // Align vertically.
  y += fons__getVertAlign(stash, font, state.align_, isize);

  for (; str != end; ++str) {
    if (fons__decutf8(&utf8state, &codepoint, *cast(const(ubyte)*)str)) continue;
    glyph = fons__getGlyph(stash, font, codepoint, isize, iblur);
    if (glyph !is null) {
      fons__getQuad(stash, font, prevGlyphIndex, glyph, scale, state.spacing, &x, &y, &q);

      if (stash.nverts+6 > FONS_VERTEX_COUNT) fons__flush(stash);

      fons__vertex(stash, q.x0, q.y0, q.s0, q.t0, state.color);
      fons__vertex(stash, q.x1, q.y1, q.s1, q.t1, state.color);
      fons__vertex(stash, q.x1, q.y0, q.s1, q.t0, state.color);

      fons__vertex(stash, q.x0, q.y0, q.s0, q.t0, state.color);
      fons__vertex(stash, q.x0, q.y1, q.s0, q.t1, state.color);
      fons__vertex(stash, q.x1, q.y1, q.s1, q.t1, state.color);
    }
    prevGlyphIndex = (glyph !is null ? glyph.index : -1);
  }
  fons__flush(stash);

  return x;
}
+/

public bool fonsTextIterInit(T) (FONScontext* stash, FONStextIter* iter, float x, float y, const(T)[] str) if (is(T == char) || is(T == dchar)) {
  if (stash is null || iter is null) return false;

  FONSstate* state = fons__getState(stash);
  float width;

  memset(iter, 0, (*iter).sizeof);

  if (stash is null) return false;
  if (state.font < 0 || state.font >= stash.nfonts) return false;
  iter.font = stash.fonts[state.font];
  if (iter.font.data is null) return false;

  iter.isize = cast(short)(state.size*10.0f);
  iter.iblur = cast(short)state.blur;
  iter.scale = fons__tt_getPixelHeightScale(&iter.font.font, cast(float)iter.isize/10.0f);

  // Align horizontally
  if (state.talign.left) {
    // empty
  } else if (state.talign.right) {
    width = fonsTextBounds(stash, x, y, str, null);
    x -= width;
  } else if (state.talign.center) {
    width = fonsTextBounds(stash, x, y, str, null);
    x -= width*0.5f;
  }
  // Align vertically.
  y += fons__getVertAlign(stash, iter.font, state.talign, iter.isize);

  iter.x = iter.nextx = x;
  iter.y = iter.nexty = y;
  iter.spacing = state.spacing;
  static if (is(T == char)) {
    if (str.ptr is null) str = "";
    iter.str = str.ptr;
    iter.next = str.ptr;
    iter.end = str.ptr+str.length;
    iter.isChar = true;
  } else {
    iter.dstr = str.ptr;
    iter.dnext = str.ptr;
    iter.dend = str.ptr+str.length;
    iter.isChar = false;
  }
  iter.codepoint = 0;
  iter.prevGlyphIndex = -1;

  return true;
}

public bool fonsTextIterNext (FONScontext* stash, FONStextIter* iter, FONSquad* quad) {
  if (stash is null || iter is null) return false;
  FONSglyph* glyph = null;
  if (iter.isChar) {
    const(char)* str = iter.next;
    iter.str = iter.next;
    if (str is iter.end) return false;
    const(char)*e = iter.end;
    for (; str !is e; ++str) {
      /*if (fons__decutf8(&iter.utf8state, &iter.codepoint, *cast(const(ubyte)*)str)) continue;*/
      mixin(DecUtfMixin!("iter.utf8state", "iter.codepoint", "*cast(const(ubyte)*)str"));
      if (iter.utf8state) continue;
      ++str; // 'cause we'll break anyway
      // get glyph and quad
      iter.x = iter.nextx;
      iter.y = iter.nexty;
      glyph = fons__getGlyph(stash, iter.font, iter.codepoint, iter.isize, iter.iblur);
      if (glyph !is null) {
        fons__getQuad(stash, iter.font, iter.prevGlyphIndex, glyph, iter.scale, iter.spacing, &iter.nextx, &iter.nexty, quad);
        iter.prevGlyphIndex = glyph.index;
      } else {
        iter.prevGlyphIndex = -1;
      }
      break;
    }
    iter.next = str;
  } else {
    const(dchar)* str = iter.dnext;
    iter.dstr = iter.dnext;
    if (str is iter.dend) return false;
    iter.codepoint = cast(uint)(*str++);
    if (iter.codepoint > dchar.max) iter.codepoint = '?';
    // Get glyph and quad
    iter.x = iter.nextx;
    iter.y = iter.nexty;
    glyph = fons__getGlyph(stash, iter.font, iter.codepoint, iter.isize, iter.iblur);
    if (glyph !is null) {
      fons__getQuad(stash, iter.font, iter.prevGlyphIndex, glyph, iter.scale, iter.spacing, &iter.nextx, &iter.nexty, quad);
      iter.prevGlyphIndex = glyph.index;
    } else {
      iter.prevGlyphIndex = -1;
    }
    iter.dnext = str;
  }
  return true;
}

debug public void fonsDrawDebug (FONScontext* stash, float x, float y) {
  int i;
  int w = stash.params.width;
  int h = stash.params.height;
  float u = (w == 0 ? 0 : 1.0f/w);
  float v = (h == 0 ? 0 : 1.0f/h);

  if (stash.nverts+6+6 > FONS_VERTEX_COUNT) fons__flush(stash);

  // Draw background
  fons__vertex(stash, x+0, y+0, u, v, 0x0fffffff);
  fons__vertex(stash, x+w, y+h, u, v, 0x0fffffff);
  fons__vertex(stash, x+w, y+0, u, v, 0x0fffffff);

  fons__vertex(stash, x+0, y+0, u, v, 0x0fffffff);
  fons__vertex(stash, x+0, y+h, u, v, 0x0fffffff);
  fons__vertex(stash, x+w, y+h, u, v, 0x0fffffff);

  // Draw texture
  fons__vertex(stash, x+0, y+0, 0, 0, 0xffffffff);
  fons__vertex(stash, x+w, y+h, 1, 1, 0xffffffff);
  fons__vertex(stash, x+w, y+0, 1, 0, 0xffffffff);

  fons__vertex(stash, x+0, y+0, 0, 0, 0xffffffff);
  fons__vertex(stash, x+0, y+h, 0, 1, 0xffffffff);
  fons__vertex(stash, x+w, y+h, 1, 1, 0xffffffff);

  // Drawbug draw atlas
  for (i = 0; i < stash.atlas.nnodes; i++) {
    FONSatlasNode* n = &stash.atlas.nodes[i];

    if (stash.nverts+6 > FONS_VERTEX_COUNT)
      fons__flush(stash);

    fons__vertex(stash, x+n.x+0, y+n.y+0, u, v, 0xc00000ff);
    fons__vertex(stash, x+n.x+n.width, y+n.y+1, u, v, 0xc00000ff);
    fons__vertex(stash, x+n.x+n.width, y+n.y+0, u, v, 0xc00000ff);

    fons__vertex(stash, x+n.x+0, y+n.y+0, u, v, 0xc00000ff);
    fons__vertex(stash, x+n.x+0, y+n.y+1, u, v, 0xc00000ff);
    fons__vertex(stash, x+n.x+n.width, y+n.y+1, u, v, 0xc00000ff);
  }

  fons__flush(stash);
}

public struct FonsTextBoundsIterator {
private:
  FONScontext* stash;
  FONSstate* state;
  uint codepoint;
  uint utf8state = 0;
  FONSquad q;
  FONSglyph* glyph = null;
  int prevGlyphIndex = -1;
  short isize, iblur;
  float scale;
  FONSfont* font;
  float startx, x, y;
  float minx, miny, maxx, maxy;

public:
  this (FONScontext* astash, float ax, float ay) { reset(astash, ax, ay); }

  void reset (FONScontext* astash, float ax, float ay) {
    this = this.init;
    if (astash is null) return;
    stash = astash;
    state = fons__getState(stash);
    if (state is null) { stash = null; return; } // alas

    x = ax;
    y = ay;

    isize = cast(short)(state.size*10.0f);
    iblur = cast(short)state.blur;

    if (state.font < 0 || state.font >= stash.nfonts) { stash = null; return; }
    font = stash.fonts[state.font];
    if (font.data is null) { stash = null; return; }

    scale = fons__tt_getPixelHeightScale(&font.font, cast(float)isize/10.0f);

    // align vertically
    y += fons__getVertAlign(stash, font, state.talign, isize);

    minx = maxx = x;
    miny = maxy = y;
    startx = x;
    //assert(prevGlyphIndex == -1);
  }

public:
  @property bool valid () const pure nothrow @safe @nogc { pragma(inline, true); return (state !is null); }

  void put(T) (const(T)[] str...) if (is(T == char) || is(T == dchar)) {
    enum DoCodePointMixin = q{
      glyph = fons__getGlyph(stash, font, codepoint, isize, iblur);
      if (glyph !is null) {
        fons__getQuad(stash, font, prevGlyphIndex, glyph, scale, state.spacing, &x, &y, &q);
        if (q.x0 < minx) minx = q.x0;
        if (q.x1 > maxx) maxx = q.x1;
        if (stash.params.flags&FONS_ZERO_TOPLEFT) {
          if (q.y0 < miny) miny = q.y0;
          if (q.y1 > maxy) maxy = q.y1;
        } else {
          if (q.y1 < miny) miny = q.y1;
          if (q.y0 > maxy) maxy = q.y0;
        }
        prevGlyphIndex = glyph.index;
      } else {
        prevGlyphIndex = -1;
      }
    };

    if (state is null) return; // alas
    static if (is(T == char)) {
      foreach (char ch; str) {
        mixin(DecUtfMixin!("utf8state", "codepoint", "cast(ubyte)ch"));
        if (utf8state) continue; // full char is not collected yet
        mixin(DoCodePointMixin);
      }
    } else {
      if (str.length == 0) return;
      if (utf8state) {
        utf8state = 0;
        codepoint = '?';
        mixin(DoCodePointMixin);
      }
      foreach (dchar dch; str) {
        if (dch > dchar.max) dch = '?';
        codepoint = cast(uint)dch;
        mixin(DoCodePointMixin);
      }
    }
  }

  // return current advance
  @property float advance () const pure nothrow @safe @nogc { pragma(inline, true); return (state !is null ? x-startx : 0); }

  void getBounds (ref float[4] bounds) const pure nothrow @safe @nogc {
    if (state is null) { bounds[] = 0; return; }
    float lminx = minx, lmaxx = maxx;
    // align horizontally
    if (state.talign.left) {
      // empty
    } else if (state.talign.right) {
      float ca = advance;
      lminx -= ca;
      lmaxx -= ca;
    } else if (state.talign.center) {
      float ca = advance*0.5f;
      lminx -= ca;
      lmaxx -= ca;
    }
    bounds[0] = lminx;
    bounds[1] = miny;
    bounds[2] = lmaxx;
    bounds[3] = maxy;
  }

  // Return current horizontal text bounds.
  void getHBounds (out float xmin, out float xmax) {
    if (state !is null) {
      float lminx = minx, lmaxx = maxx;
      // align horizontally
      if (state.talign.left) {
        // empty
      } else if (state.talign.right) {
        float ca = advance;
        lminx -= ca;
        lmaxx -= ca;
      } else if (state.talign.center) {
        float ca = advance*0.5f;
        lminx -= ca;
        lmaxx -= ca;
      }
      xmin = lminx;
      xmax = lmaxx;
    }
  }

  // Return current vertical text bounds.
  void getVBounds (out float ymin, out float ymax) {
    if (state !is null) {
      ymin = miny;
      ymax = maxy;
    }
  }
}

public float fonsTextBounds(T) (FONScontext* stash, float x, float y, const(T)[] str, float[] bounds) if (is(T == char) || is(T == dchar)) {
  FONSstate* state = fons__getState(stash);
  uint codepoint;
  uint utf8state = 0;
  FONSquad q;
  FONSglyph* glyph = null;
  int prevGlyphIndex = -1;
  short isize = cast(short)(state.size*10.0f);
  short iblur = cast(short)state.blur;
  float scale;
  FONSfont* font;
  float startx, advance;
  float minx, miny, maxx, maxy;

  if (stash is null) return 0;
  if (state.font < 0 || state.font >= stash.nfonts) return 0;
  font = stash.fonts[state.font];
  if (font.data is null) return 0;

  scale = fons__tt_getPixelHeightScale(&font.font, cast(float)isize/10.0f);

  // Align vertically.
  y += fons__getVertAlign(stash, font, state.talign, isize);

  minx = maxx = x;
  miny = maxy = y;
  startx = x;

  static if (is(T == char)) {
    foreach (char ch; str) {
      //if (fons__decutf8(&utf8state, &codepoint, *cast(const(ubyte)*)str)) continue;
      mixin(DecUtfMixin!("utf8state", "codepoint", "(cast(ubyte)ch)"));
      if (utf8state) continue;
      glyph = fons__getGlyph(stash, font, codepoint, isize, iblur);
      if (glyph !is null) {
        fons__getQuad(stash, font, prevGlyphIndex, glyph, scale, state.spacing, &x, &y, &q);
        if (q.x0 < minx) minx = q.x0;
        if (q.x1 > maxx) maxx = q.x1;
        if (stash.params.flags&FONS_ZERO_TOPLEFT) {
          if (q.y0 < miny) miny = q.y0;
          if (q.y1 > maxy) maxy = q.y1;
        } else {
          if (q.y1 < miny) miny = q.y1;
          if (q.y0 > maxy) maxy = q.y0;
        }
        prevGlyphIndex = glyph.index;
      } else {
        prevGlyphIndex = -1;
      }
    }
  } else {
    foreach (dchar ch; str) {
      if (ch > dchar.max) ch = '?';
      codepoint = cast(uint)ch;
      glyph = fons__getGlyph(stash, font, codepoint, isize, iblur);
      if (glyph !is null) {
        fons__getQuad(stash, font, prevGlyphIndex, glyph, scale, state.spacing, &x, &y, &q);
        if (q.x0 < minx) minx = q.x0;
        if (q.x1 > maxx) maxx = q.x1;
        if (stash.params.flags&FONS_ZERO_TOPLEFT) {
          if (q.y0 < miny) miny = q.y0;
          if (q.y1 > maxy) maxy = q.y1;
        } else {
          if (q.y1 < miny) miny = q.y1;
          if (q.y0 > maxy) maxy = q.y0;
        }
        prevGlyphIndex = glyph.index;
      } else {
        prevGlyphIndex = -1;
      }
    }
  }

  advance = x-startx;

  // Align horizontally
  if (state.talign.left) {
    // empty
  } else if (state.talign.right) {
    minx -= advance;
    maxx -= advance;
  } else if (state.talign.center) {
    minx -= advance*0.5f;
    maxx -= advance*0.5f;
  }

  if (bounds.length) {
    if (bounds.length > 0) bounds.ptr[0] = minx;
    if (bounds.length > 1) bounds.ptr[1] = miny;
    if (bounds.length > 2) bounds.ptr[2] = maxx;
    if (bounds.length > 3) bounds.ptr[3] = maxy;
  }

  return advance;
}

public void fonsVertMetrics (FONScontext* stash, float* ascender, float* descender, float* lineh) {
  FONSfont* font;
  FONSstate* state = fons__getState(stash);
  short isize;

  if (stash is null) return;
  if (state.font < 0 || state.font >= stash.nfonts) return;
  font = stash.fonts[state.font];
  isize = cast(short)(state.size*10.0f);
  if (font.data is null) return;

  if (ascender) *ascender = font.ascender*isize/10.0f;
  if (descender) *descender = font.descender*isize/10.0f;
  if (lineh) *lineh = font.lineh*isize/10.0f;
}

public void fonsLineBounds (FONScontext* stash, float y, float* miny, float* maxy) {
  FONSfont* font;
  FONSstate* state = fons__getState(stash);
  short isize;

  if (stash is null) return;
  if (state.font < 0 || state.font >= stash.nfonts) return;
  font = stash.fonts[state.font];
  isize = cast(short)(state.size*10.0f);
  if (font.data is null) return;

  y += fons__getVertAlign(stash, font, state.talign, isize);

  if (stash.params.flags&FONS_ZERO_TOPLEFT) {
    *miny = y-font.ascender*cast(float)isize/10.0f;
    *maxy = *miny+font.lineh*isize/10.0f;
  } else {
    *maxy = y+font.descender*cast(float)isize/10.0f;
    *miny = *maxy-font.lineh*isize/10.0f;
  }
}

public const(ubyte)* fonsGetTextureData (FONScontext* stash, int* width, int* height) {
  if (width !is null) *width = stash.params.width;
  if (height !is null) *height = stash.params.height;
  return stash.texData;
}

public int fonsValidateTexture (FONScontext* stash, int* dirty) {
  if (stash.dirtyRect.ptr[0] < stash.dirtyRect.ptr[2] && stash.dirtyRect.ptr[1] < stash.dirtyRect.ptr[3]) {
    dirty[0] = stash.dirtyRect.ptr[0];
    dirty[1] = stash.dirtyRect.ptr[1];
    dirty[2] = stash.dirtyRect.ptr[2];
    dirty[3] = stash.dirtyRect.ptr[3];
    // Reset dirty rect
    stash.dirtyRect.ptr[0] = stash.params.width;
    stash.dirtyRect.ptr[1] = stash.params.height;
    stash.dirtyRect.ptr[2] = 0;
    stash.dirtyRect.ptr[3] = 0;
    return 1;
  }
  return 0;
}

public void fonsDeleteInternal (FONScontext* stash) {
  if (stash is null) return;

  if (stash.params.renderDelete) stash.params.renderDelete(stash.params.userPtr);

  foreach (int i; 0..stash.nfonts) fons__freeFont(stash.fonts[i]);

  if (stash.atlas) fons__deleteAtlas(stash.atlas);
  if (stash.fonts) free(stash.fonts);
  if (stash.texData) free(stash.texData);
  if (stash.scratch) free(stash.scratch);
  free(stash);
}

public void fonsSetErrorCallback (FONScontext* stash, void function (void* uptr, int error, int val) callback, void* uptr) {
  if (stash is null) return;
  stash.handleError = callback;
  stash.errorUptr = uptr;
}

public void fonsGetAtlasSize (FONScontext* stash, int* width, int* height) {
  if (stash is null) return;
  *width = stash.params.width;
  *height = stash.params.height;
}

public int fonsExpandAtlas (FONScontext* stash, int width, int height) {
  int i, maxy = 0;
  ubyte* data = null;
  if (stash is null) return 0;

  width = nvg__max(width, stash.params.width);
  height = nvg__max(height, stash.params.height);

  if (width == stash.params.width && height == stash.params.height) return 1;

  // Flush pending glyphs.
  fons__flush(stash);

  // Create new texture
  if (stash.params.renderResize !is null) {
    if (stash.params.renderResize(stash.params.userPtr, width, height) == 0) return 0;
  }
  // Copy old texture data over.
  data = cast(ubyte*)malloc(width*height);
  if (data is null) return 0;
  for (i = 0; i < stash.params.height; i++) {
    ubyte* dst = &data[i*width];
    ubyte* src = &stash.texData[i*stash.params.width];
    memcpy(dst, src, stash.params.width);
    if (width > stash.params.width)
      memset(dst+stash.params.width, 0, width-stash.params.width);
  }
  if (height > stash.params.height) memset(&data[stash.params.height*width], 0, (height-stash.params.height)*width);

  free(stash.texData);
  stash.texData = data;

  // Increase atlas size
  fons__atlasExpand(stash.atlas, width, height);

  // Add existing data as dirty.
  for (i = 0; i < stash.atlas.nnodes; i++) maxy = nvg__max(maxy, stash.atlas.nodes[i].y);
  stash.dirtyRect.ptr[0] = 0;
  stash.dirtyRect.ptr[1] = 0;
  stash.dirtyRect.ptr[2] = stash.params.width;
  stash.dirtyRect.ptr[3] = maxy;

  stash.params.width = width;
  stash.params.height = height;
  stash.itw = 1.0f/stash.params.width;
  stash.ith = 1.0f/stash.params.height;

  return 1;
}

public int fonsResetAtlas (FONScontext* stash, int width, int height) {
  int i, j;
  if (stash is null) return 0;

  // Flush pending glyphs.
  fons__flush(stash);

  // Create new texture
  if (stash.params.renderResize !is null) {
    if (stash.params.renderResize(stash.params.userPtr, width, height) == 0) return 0;
  }

  // Reset atlas
  fons__atlasReset(stash.atlas, width, height);

  // Clear texture data.
  stash.texData = cast(ubyte*)realloc(stash.texData, width*height);
  if (stash.texData is null) return 0;
  memset(stash.texData, 0, width*height);

  // Reset dirty rect
  stash.dirtyRect.ptr[0] = width;
  stash.dirtyRect.ptr[1] = height;
  stash.dirtyRect.ptr[2] = 0;
  stash.dirtyRect.ptr[3] = 0;

  // Reset cached glyphs
  for (i = 0; i < stash.nfonts; i++) {
    FONSfont* font = stash.fonts[i];
    font.nglyphs = 0;
    for (j = 0; j < FONS_HASH_LUT_SIZE; j++) font.lut[j] = -1;
  }

  stash.params.width = width;
  stash.params.height = height;
  stash.itw = 1.0f/stash.params.width;
  stash.ith = 1.0f/stash.params.height;

  // Add white rect at 0, 0 for debug drawing.
  fons__addWhiteRect(stash, 2, 2);

  return 1;
}


// ////////////////////////////////////////////////////////////////////////// //
// backgl
// ////////////////////////////////////////////////////////////////////////// //
import core.stdc.stdlib : malloc, realloc, free;
import core.stdc.string : memcpy, memset;

//import iv.nanovg.engine;
import arsd.simpledisplay;

public:
// sdpy is missing that yet
static if (!is(typeof(GL_STENCIL_BUFFER_BIT))) enum uint GL_STENCIL_BUFFER_BIT = 0x00000400;


// OpenGL API missing from simpledisplay
private extern(System) nothrow @nogc {
  alias GLvoid = void;
  alias GLboolean = ubyte;
  alias GLuint = uint;
  alias GLenum = uint;
  alias GLchar = char;
  alias GLsizei = int;
  alias GLfloat = float;
  alias GLsizeiptr = ptrdiff_t;

  enum uint GL_ZERO = 0;
  enum uint GL_ONE = 1;

  enum uint GL_FLOAT = 0x1406;

  enum uint GL_STREAM_DRAW = 0x88E0;

  enum uint GL_CCW = 0x0901;

  enum uint GL_STENCIL_TEST = 0x0B90;
  enum uint GL_SCISSOR_TEST = 0x0C11;

  enum uint GL_EQUAL = 0x0202;
  enum uint GL_NOTEQUAL = 0x0205;

  enum uint GL_ALWAYS = 0x0207;
  enum uint GL_KEEP = 0x1E00;

  enum uint GL_INCR = 0x1E02;

  enum uint GL_INCR_WRAP = 0x8507;
  enum uint GL_DECR_WRAP = 0x8508;

  enum uint GL_CULL_FACE = 0x0B44;
  enum uint GL_BACK = 0x0405;

  enum uint GL_FRAGMENT_SHADER = 0x8B30;
  enum uint GL_VERTEX_SHADER = 0x8B31;

  enum uint GL_COMPILE_STATUS = 0x8B81;
  enum uint GL_LINK_STATUS = 0x8B82;

  enum uint GL_UNPACK_ALIGNMENT = 0x0CF5;
  enum uint GL_UNPACK_ROW_LENGTH = 0x0CF2;
  enum uint GL_UNPACK_SKIP_PIXELS = 0x0CF4;
  enum uint GL_UNPACK_SKIP_ROWS = 0x0CF3;

  enum uint GL_GENERATE_MIPMAP = 0x8191;
  enum uint GL_LINEAR_MIPMAP_LINEAR = 0x2703;

  enum uint GL_RED = 0x1903;

  enum uint GL_TEXTURE0 = 0x84C0;

  enum uint GL_ARRAY_BUFFER = 0x8892;

  /*
  version(Windows) {
    private void* kglLoad (const(char)* name) {
      void* res = glGetProcAddress(name);
      if (res is null) {
        import core.sys.windows.windef, core.sys.windows.winbase;
        static HINSTANCE dll = null;
        if (dll is null) {
          dll = LoadLibraryA("opengl32.dll");
          if (dll is null) return null; // <32, but idc
          return GetProcAddress(dll, name);
        }
      }
    }
  } else {
    alias kglLoad = glGetProcAddress;
  }
  */

  alias glbfn_glStencilMask = void function(GLuint);
  __gshared glbfn_glStencilMask glStencilMask;
  alias glbfn_glStencilFunc = void function(GLenum, GLint, GLuint);
  __gshared glbfn_glStencilFunc glStencilFunc;
  alias glbfn_glGetShaderInfoLog = void function(GLuint, GLsizei, GLsizei*, GLchar*);
  __gshared glbfn_glGetShaderInfoLog glGetShaderInfoLog;
  alias glbfn_glGetProgramInfoLog = void function(GLuint, GLsizei, GLsizei*, GLchar*);
  __gshared glbfn_glGetProgramInfoLog glGetProgramInfoLog;
  alias glbfn_glCreateProgram = GLuint function();
  __gshared glbfn_glCreateProgram glCreateProgram;
  alias glbfn_glCreateShader = GLuint function(GLenum);
  __gshared glbfn_glCreateShader glCreateShader;
  alias glbfn_glShaderSource = void function(GLuint, GLsizei, const(GLchar*)*, const(GLint)*);
  __gshared glbfn_glShaderSource glShaderSource;
  alias glbfn_glCompileShader = void function(GLuint);
  __gshared glbfn_glCompileShader glCompileShader;
  alias glbfn_glGetShaderiv = void function(GLuint, GLenum, GLint*);
  __gshared glbfn_glGetShaderiv glGetShaderiv;
  alias glbfn_glAttachShader = void function(GLuint, GLuint);
  __gshared glbfn_glAttachShader glAttachShader;
  alias glbfn_glBindAttribLocation = void function(GLuint, GLuint, const(GLchar)*);
  __gshared glbfn_glBindAttribLocation glBindAttribLocation;
  alias glbfn_glLinkProgram = void function(GLuint);
  __gshared glbfn_glLinkProgram glLinkProgram;
  alias glbfn_glGetProgramiv = void function(GLuint, GLenum, GLint*);
  __gshared glbfn_glGetProgramiv glGetProgramiv;
  alias glbfn_glDeleteProgram = void function(GLuint);
  __gshared glbfn_glDeleteProgram glDeleteProgram;
  alias glbfn_glDeleteShader = void function(GLuint);
  __gshared glbfn_glDeleteShader glDeleteShader;
  alias glbfn_glGetUniformLocation = GLint function(GLuint, const(GLchar)*);
  __gshared glbfn_glGetUniformLocation glGetUniformLocation;
  alias glbfn_glGenBuffers = void function(GLsizei, GLuint*);
  __gshared glbfn_glGenBuffers glGenBuffers;
  alias glbfn_glPixelStorei = void function(GLenum, GLint);
  __gshared glbfn_glPixelStorei glPixelStorei;
  alias glbfn_glUniform4fv = void function(GLint, GLsizei, const(GLfloat)*);
  __gshared glbfn_glUniform4fv glUniform4fv;
  alias glbfn_glColorMask = void function(GLboolean, GLboolean, GLboolean, GLboolean);
  __gshared glbfn_glColorMask glColorMask;
  alias glbfn_glStencilOpSeparate = void function(GLenum, GLenum, GLenum, GLenum);
  __gshared glbfn_glStencilOpSeparate glStencilOpSeparate;
  alias glbfn_glDrawArrays = void function(GLenum, GLint, GLsizei);
  __gshared glbfn_glDrawArrays glDrawArrays;
  alias glbfn_glStencilOp = void function(GLenum, GLenum, GLenum);
  __gshared glbfn_glStencilOp glStencilOp;
  alias glbfn_glUseProgram = void function(GLuint);
  __gshared glbfn_glUseProgram glUseProgram;
  alias glbfn_glCullFace = void function(GLenum);
  __gshared glbfn_glCullFace glCullFace;
  alias glbfn_glFrontFace = void function(GLenum);
  __gshared glbfn_glFrontFace glFrontFace;
  alias glbfn_glActiveTexture = void function(GLenum);
  __gshared glbfn_glActiveTexture glActiveTexture;
  alias glbfn_glBindBuffer = void function(GLenum, GLuint);
  __gshared glbfn_glBindBuffer glBindBuffer;
  alias glbfn_glBufferData = void function(GLenum, GLsizeiptr, const(void)*, GLenum);
  __gshared glbfn_glBufferData glBufferData;
  alias glbfn_glEnableVertexAttribArray = void function(GLuint);
  __gshared glbfn_glEnableVertexAttribArray glEnableVertexAttribArray;
  alias glbfn_glVertexAttribPointer = void function(GLuint, GLint, GLenum, GLboolean, GLsizei, const(void)*);
  __gshared glbfn_glVertexAttribPointer glVertexAttribPointer;
  alias glbfn_glUniform1i = void function(GLint, GLint);
  __gshared glbfn_glUniform1i glUniform1i;
  alias glbfn_glUniform2fv = void function(GLint, GLsizei, const(GLfloat)*);
  __gshared glbfn_glUniform2fv glUniform2fv;
  alias glbfn_glDisableVertexAttribArray = void function(GLuint);
  __gshared glbfn_glDisableVertexAttribArray glDisableVertexAttribArray;
  alias glbfn_glDeleteBuffers = void function(GLsizei, const(GLuint)*);
  __gshared glbfn_glDeleteBuffers glDeleteBuffers;

  private void nanovgInitOpenGL () {
    __gshared bool initialized = false;
    if (initialized) return;
    glStencilMask = cast(glbfn_glStencilMask)glGetProcAddress(`glStencilMask`);
    if (glStencilMask is null) assert(0, `OpenGL function 'glStencilMask' not found!`);
    glStencilFunc = cast(glbfn_glStencilFunc)glGetProcAddress(`glStencilFunc`);
    if (glStencilFunc is null) assert(0, `OpenGL function 'glStencilFunc' not found!`);
    glGetShaderInfoLog = cast(glbfn_glGetShaderInfoLog)glGetProcAddress(`glGetShaderInfoLog`);
    if (glGetShaderInfoLog is null) assert(0, `OpenGL function 'glGetShaderInfoLog' not found!`);
    glGetProgramInfoLog = cast(glbfn_glGetProgramInfoLog)glGetProcAddress(`glGetProgramInfoLog`);
    if (glGetProgramInfoLog is null) assert(0, `OpenGL function 'glGetProgramInfoLog' not found!`);
    glCreateProgram = cast(glbfn_glCreateProgram)glGetProcAddress(`glCreateProgram`);
    if (glCreateProgram is null) assert(0, `OpenGL function 'glCreateProgram' not found!`);
    glCreateShader = cast(glbfn_glCreateShader)glGetProcAddress(`glCreateShader`);
    if (glCreateShader is null) assert(0, `OpenGL function 'glCreateShader' not found!`);
    glShaderSource = cast(glbfn_glShaderSource)glGetProcAddress(`glShaderSource`);
    if (glShaderSource is null) assert(0, `OpenGL function 'glShaderSource' not found!`);
    glCompileShader = cast(glbfn_glCompileShader)glGetProcAddress(`glCompileShader`);
    if (glCompileShader is null) assert(0, `OpenGL function 'glCompileShader' not found!`);
    glGetShaderiv = cast(glbfn_glGetShaderiv)glGetProcAddress(`glGetShaderiv`);
    if (glGetShaderiv is null) assert(0, `OpenGL function 'glGetShaderiv' not found!`);
    glAttachShader = cast(glbfn_glAttachShader)glGetProcAddress(`glAttachShader`);
    if (glAttachShader is null) assert(0, `OpenGL function 'glAttachShader' not found!`);
    glBindAttribLocation = cast(glbfn_glBindAttribLocation)glGetProcAddress(`glBindAttribLocation`);
    if (glBindAttribLocation is null) assert(0, `OpenGL function 'glBindAttribLocation' not found!`);
    glLinkProgram = cast(glbfn_glLinkProgram)glGetProcAddress(`glLinkProgram`);
    if (glLinkProgram is null) assert(0, `OpenGL function 'glLinkProgram' not found!`);
    glGetProgramiv = cast(glbfn_glGetProgramiv)glGetProcAddress(`glGetProgramiv`);
    if (glGetProgramiv is null) assert(0, `OpenGL function 'glGetProgramiv' not found!`);
    glDeleteProgram = cast(glbfn_glDeleteProgram)glGetProcAddress(`glDeleteProgram`);
    if (glDeleteProgram is null) assert(0, `OpenGL function 'glDeleteProgram' not found!`);
    glDeleteShader = cast(glbfn_glDeleteShader)glGetProcAddress(`glDeleteShader`);
    if (glDeleteShader is null) assert(0, `OpenGL function 'glDeleteShader' not found!`);
    glGetUniformLocation = cast(glbfn_glGetUniformLocation)glGetProcAddress(`glGetUniformLocation`);
    if (glGetUniformLocation is null) assert(0, `OpenGL function 'glGetUniformLocation' not found!`);
    glGenBuffers = cast(glbfn_glGenBuffers)glGetProcAddress(`glGenBuffers`);
    if (glGenBuffers is null) assert(0, `OpenGL function 'glGenBuffers' not found!`);
    glPixelStorei = cast(glbfn_glPixelStorei)glGetProcAddress(`glPixelStorei`);
    if (glPixelStorei is null) assert(0, `OpenGL function 'glPixelStorei' not found!`);
    glUniform4fv = cast(glbfn_glUniform4fv)glGetProcAddress(`glUniform4fv`);
    if (glUniform4fv is null) assert(0, `OpenGL function 'glUniform4fv' not found!`);
    glColorMask = cast(glbfn_glColorMask)glGetProcAddress(`glColorMask`);
    if (glColorMask is null) assert(0, `OpenGL function 'glColorMask' not found!`);
    glStencilOpSeparate = cast(glbfn_glStencilOpSeparate)glGetProcAddress(`glStencilOpSeparate`);
    if (glStencilOpSeparate is null) assert(0, `OpenGL function 'glStencilOpSeparate' not found!`);
    glDrawArrays = cast(glbfn_glDrawArrays)glGetProcAddress(`glDrawArrays`);
    if (glDrawArrays is null) assert(0, `OpenGL function 'glDrawArrays' not found!`);
    glStencilOp = cast(glbfn_glStencilOp)glGetProcAddress(`glStencilOp`);
    if (glStencilOp is null) assert(0, `OpenGL function 'glStencilOp' not found!`);
    glUseProgram = cast(glbfn_glUseProgram)glGetProcAddress(`glUseProgram`);
    if (glUseProgram is null) assert(0, `OpenGL function 'glUseProgram' not found!`);
    glCullFace = cast(glbfn_glCullFace)glGetProcAddress(`glCullFace`);
    if (glCullFace is null) assert(0, `OpenGL function 'glCullFace' not found!`);
    glFrontFace = cast(glbfn_glFrontFace)glGetProcAddress(`glFrontFace`);
    if (glFrontFace is null) assert(0, `OpenGL function 'glFrontFace' not found!`);
    glActiveTexture = cast(glbfn_glActiveTexture)glGetProcAddress(`glActiveTexture`);
    if (glActiveTexture is null) assert(0, `OpenGL function 'glActiveTexture' not found!`);
    glBindBuffer = cast(glbfn_glBindBuffer)glGetProcAddress(`glBindBuffer`);
    if (glBindBuffer is null) assert(0, `OpenGL function 'glBindBuffer' not found!`);
    glBufferData = cast(glbfn_glBufferData)glGetProcAddress(`glBufferData`);
    if (glBufferData is null) assert(0, `OpenGL function 'glBufferData' not found!`);
    glEnableVertexAttribArray = cast(glbfn_glEnableVertexAttribArray)glGetProcAddress(`glEnableVertexAttribArray`);
    if (glEnableVertexAttribArray is null) assert(0, `OpenGL function 'glEnableVertexAttribArray' not found!`);
    glVertexAttribPointer = cast(glbfn_glVertexAttribPointer)glGetProcAddress(`glVertexAttribPointer`);
    if (glVertexAttribPointer is null) assert(0, `OpenGL function 'glVertexAttribPointer' not found!`);
    glUniform1i = cast(glbfn_glUniform1i)glGetProcAddress(`glUniform1i`);
    if (glUniform1i is null) assert(0, `OpenGL function 'glUniform1i' not found!`);
    glUniform2fv = cast(glbfn_glUniform2fv)glGetProcAddress(`glUniform2fv`);
    if (glUniform2fv is null) assert(0, `OpenGL function 'glUniform2fv' not found!`);
    glDisableVertexAttribArray = cast(glbfn_glDisableVertexAttribArray)glGetProcAddress(`glDisableVertexAttribArray`);
    if (glDisableVertexAttribArray is null) assert(0, `OpenGL function 'glDisableVertexAttribArray' not found!`);
    glDeleteBuffers = cast(glbfn_glDeleteBuffers)glGetProcAddress(`glDeleteBuffers`);
    if (glDeleteBuffers is null) assert(0, `OpenGL function 'glDeleteBuffers' not found!`);
    initialized = true;
  }
}


/// Create flags
alias NVGcreateFlags = int;
/// Create flags
enum /*NVGcreateFlags*/ {
  /// Flag indicating if geometry based anti-aliasing is used (may not be needed when using MSAA).
  NVG_ANTIALIAS = 1<<0,
  /** Flag indicating if strokes should be drawn using stencil buffer. The rendering will be a little
    * slower, but path overlaps (i.e. self-intersecting or sharp turns) will be drawn just once. */
  NVG_STENCIL_STROKES = 1<<1,
  /// Flag indicating that additional debug checks are done.
  NVG_DEBUG = 1<<2,
}

enum NANOVG_GL_USE_STATE_FILTER = true;

// These are additional flags on top of NVGImageFlags.
alias NVGimageFlagsGL = int;
enum /*NVGimageFlagsGL*/ {
  NVG_IMAGE_NODELETE = 1<<16,  // Do not delete GL texture handle.
}


/// Return flags for glClear().
uint glNVGClearFlags () pure nothrow @safe @nogc {
  pragma(inline, true);
  return (GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT|GL_STENCIL_BUFFER_BIT);
}


// ////////////////////////////////////////////////////////////////////////// //
private:

alias GLNVGuniformLoc = int;
enum /*GLNVGuniformLoc*/ {
  GLNVG_LOC_VIEWSIZE,
  GLNVG_LOC_TEX,
  GLNVG_LOC_FRAG,
  GLNVG_MAX_LOCS,
}

alias GLNVGshaderType = int;
enum /*GLNVGshaderType*/ {
  NSVG_SHADER_FILLGRAD,
  NSVG_SHADER_FILLIMG,
  NSVG_SHADER_SIMPLE,
  NSVG_SHADER_IMG,
}

struct GLNVGshader {
  GLuint prog;
  GLuint frag;
  GLuint vert;
  GLint[GLNVG_MAX_LOCS] loc;
}

struct GLNVGtexture {
  int id;
  GLuint tex;
  int width, height;
  NVGtexture type;
  int flags;
}

alias GLNVGcallType = int;
enum /*GLNVGcallType*/ {
  GLNVG_NONE = 0,
  GLNVG_FILL,
  GLNVG_CONVEXFILL,
  GLNVG_STROKE,
  GLNVG_TRIANGLES,
}

struct GLNVGcall {
  int type;
  int image;
  int pathOffset;
  int pathCount;
  int triangleOffset;
  int triangleCount;
  int uniformOffset;
}

struct GLNVGpath {
  int fillOffset;
  int fillCount;
  int strokeOffset;
  int strokeCount;
}

enum NANOVG_GL_UNIFORMARRAY_SIZE = 11;
struct GLNVGfragUniforms {
  // note: after modifying layout or size of uniform array,
  // don't forget to also update the fragment shader source!
  union {
    struct {
      float[12] scissorMat; // matrices are actually 3 vec4s
      float[12] paintMat;
      NVGColor innerCol;
      NVGColor outerCol;
      float[2] scissorExt;
      float[2] scissorScale;
      float[2] extent;
      float radius;
      float feather;
      float strokeMult;
      float strokeThr;
      float texType;
      float type;
    }
    float[4][NANOVG_GL_UNIFORMARRAY_SIZE] uniformArray;
  }
}

struct GLNVGcontext {
  GLNVGshader shader;
  GLNVGtexture* textures;
  float[2] view;
  int ntextures;
  int ctextures;
  int textureId;
  GLuint vertBuf;
  int fragSize;
  int flags;

  // Per frame buffers
  GLNVGcall* calls;
  int ccalls;
  int ncalls;
  GLNVGpath* paths;
  int cpaths;
  int npaths;
  NVGvertex* verts;
  int cverts;
  int nverts;
  ubyte* uniforms;
  int cuniforms;
  int nuniforms;

  // cached state
  static if (NANOVG_GL_USE_STATE_FILTER) {
    GLuint boundTexture;
    GLuint stencilMask;
    GLenum stencilFunc;
    GLint stencilFuncRef;
    GLuint stencilFuncMask;
  }
}

int glnvg__maxi() (int a, int b) { pragma(inline, true); return (a > b ? a : b); }

void glnvg__bindTexture (GLNVGcontext* gl, GLuint tex) {
  static if (NANOVG_GL_USE_STATE_FILTER) {
    if (gl.boundTexture != tex) {
      gl.boundTexture = tex;
      glBindTexture(GL_TEXTURE_2D, tex);
    }
  } else {
    glBindTexture(GL_TEXTURE_2D, tex);
  }
}

void glnvg__stencilMask (GLNVGcontext* gl, GLuint mask) {
  static if (NANOVG_GL_USE_STATE_FILTER) {
    if (gl.stencilMask != mask) {
      gl.stencilMask = mask;
      glStencilMask(mask);
    }
  } else {
    glStencilMask(mask);
  }
}

void glnvg__stencilFunc (GLNVGcontext* gl, GLenum func, GLint ref_, GLuint mask) {
  static if (NANOVG_GL_USE_STATE_FILTER) {
    if (gl.stencilFunc != func || gl.stencilFuncRef != ref_ || gl.stencilFuncMask != mask) {
      gl.stencilFunc = func;
      gl.stencilFuncRef = ref_;
      gl.stencilFuncMask = mask;
      glStencilFunc(func, ref_, mask);
    }
  } else {
    glStencilFunc(func, ref_, mask);
  }
}

GLNVGtexture* glnvg__allocTexture (GLNVGcontext* gl) {
  GLNVGtexture* tex = null;
  foreach (int i; 0..gl.ntextures) {
    if (gl.textures[i].id == 0) {
      tex = &gl.textures[i];
      break;
    }
  }
  if (tex is null) {
    if (gl.ntextures+1 > gl.ctextures) {
      GLNVGtexture* textures;
      int ctextures = glnvg__maxi(gl.ntextures+1, 4)+gl.ctextures/2; // 1.5x Overallocate
      textures = cast(GLNVGtexture*)realloc(gl.textures, GLNVGtexture.sizeof*ctextures);
      if (textures is null) return null;
      gl.textures = textures;
      gl.ctextures = ctextures;
    }
    tex = &gl.textures[gl.ntextures++];
  }

  memset(tex, 0, (*tex).sizeof);
  tex.id = ++gl.textureId;

  return tex;
}

GLNVGtexture* glnvg__findTexture (GLNVGcontext* gl, int id) {
  foreach (int i; 0..gl.ntextures) if (gl.textures[i].id == id) return &gl.textures[i];
  return null;
}

bool glnvg__deleteTexture (GLNVGcontext* gl, int id) {
  foreach (int i; 0..gl.ntextures) {
    if (gl.textures[i].id == id) {
      if (gl.textures[i].tex != 0 && (gl.textures[i].flags&NVG_IMAGE_NODELETE) == 0) glDeleteTextures(1, &gl.textures[i].tex);
      memset(&gl.textures[i], 0, (gl.textures[i]).sizeof);
      return true;
    }
  }
  return false;
}

void glnvg__dumpShaderError (GLuint shader, const(char)* name, const(char)* type) {
  import core.stdc.stdio : fprintf, stderr;
  GLchar[512+1] str = 0;
  GLsizei len = 0;
  glGetShaderInfoLog(shader, 512, &len, str.ptr);
  if (len > 512) len = 512;
  str[len] = '\0';
  fprintf(stderr, "Shader %s/%s error:\n%s\n", name, type, str.ptr);
}

void glnvg__dumpProgramError (GLuint prog, const(char)* name) {
  import core.stdc.stdio : fprintf, stderr;
  GLchar[512+1] str = 0;
  GLsizei len = 0;
  glGetProgramInfoLog(prog, 512, &len, str.ptr);
  if (len > 512) len = 512;
  str[len] = '\0';
  fprintf(stderr, "Program %s error:\n%s\n", name, str.ptr);
}

void glnvg__checkError (GLNVGcontext* gl, const(char)* str) {
  GLenum err;
  if ((gl.flags&NVG_DEBUG) == 0) return;
  err = glGetError();
  if (err != GL_NO_ERROR) {
    import core.stdc.stdio : fprintf, stderr;
    fprintf(stderr, "Error %08x after %s\n", err, str);
    return;
  }
}

bool glnvg__createShader (GLNVGshader* shader, const(char)* name, const(char)* header, const(char)* opts, const(char)* vshader, const(char)* fshader) {
  GLint status;
  GLuint prog, vert, frag;
  const(char)*[3] str;

  memset(shader, 0, (*shader).sizeof);

  prog = glCreateProgram();
  vert = glCreateShader(GL_VERTEX_SHADER);
  frag = glCreateShader(GL_FRAGMENT_SHADER);
  str[0] = header;
  str[1] = (opts !is null ? opts : "");
  str[2] = vshader;
  glShaderSource(vert, 3, cast(const(char*)*)str.ptr, null);

  glCompileShader(vert);
  glGetShaderiv(vert, GL_COMPILE_STATUS, &status);
  if (status != GL_TRUE) {
    glnvg__dumpShaderError(vert, name, "vert");
    return false;
  }

  str[0] = header;
  str[1] = (opts !is null ? opts : "");
  str[2] = fshader;
  glShaderSource(frag, 3, cast(const(char*)*)str.ptr, null);

  glCompileShader(frag);
  glGetShaderiv(frag, GL_COMPILE_STATUS, &status);
  if (status != GL_TRUE) {
    glnvg__dumpShaderError(frag, name, "frag");
    return false;
  }

  glAttachShader(prog, vert);
  glAttachShader(prog, frag);

  glBindAttribLocation(prog, 0, "vertex");
  glBindAttribLocation(prog, 1, "tcoord");

  glLinkProgram(prog);
  glGetProgramiv(prog, GL_LINK_STATUS, &status);
  if (status != GL_TRUE) {
    glnvg__dumpProgramError(prog, name);
    return false;
  }

  shader.prog = prog;
  shader.vert = vert;
  shader.frag = frag;

  return true;
}

void glnvg__deleteShader (GLNVGshader* shader) {
  if (shader.prog != 0) glDeleteProgram(shader.prog);
  if (shader.vert != 0) glDeleteShader(shader.vert);
  if (shader.frag != 0) glDeleteShader(shader.frag);
}

void glnvg__getUniforms (GLNVGshader* shader) {
  shader.loc[GLNVG_LOC_VIEWSIZE] = glGetUniformLocation(shader.prog, "viewSize");
  shader.loc[GLNVG_LOC_TEX] = glGetUniformLocation(shader.prog, "tex");
  shader.loc[GLNVG_LOC_FRAG] = glGetUniformLocation(shader.prog, "frag");
}

bool glnvg__renderCreate (void* uptr) {
  GLNVGcontext* gl = cast(GLNVGcontext*)uptr;
  enum align_ = 4;

  enum shaderHeader = "#define UNIFORMARRAY_SIZE 11\n";

  enum fillVertShader = q{
    uniform vec2 viewSize;
    attribute vec2 vertex;
    attribute vec2 tcoord;
    varying vec2 ftcoord;
    varying vec2 fpos;
    void main (void) {
      ftcoord = tcoord;
      fpos = vertex;
      gl_Position = vec4(2.0*vertex.x/viewSize.x-1.0, 1.0-2.0*vertex.y/viewSize.y, 0, 1);
    }
  };

  enum fillFragShader = q{
    uniform vec4 frag[UNIFORMARRAY_SIZE];
    uniform sampler2D tex;
    varying vec2 ftcoord;
    varying vec2 fpos;
    #define scissorMat mat3(frag[0].xyz, frag[1].xyz, frag[2].xyz)
    #define paintMat mat3(frag[3].xyz, frag[4].xyz, frag[5].xyz)
    #define innerCol frag[6]
    #define outerCol frag[7]
    #define scissorExt frag[8].xy
    #define scissorScale frag[8].zw
    #define extent frag[9].xy
    #define radius frag[9].z
    #define feather frag[9].w
    #define strokeMult frag[10].x
    #define strokeThr frag[10].y
    #define texType int(frag[10].z)
    #define type int(frag[10].w)

    float sdroundrect (vec2 pt, vec2 ext, float rad) {
      vec2 ext2 = ext-vec2(rad, rad);
      vec2 d = abs(pt)-ext2;
      return min(max(d.x, d.y), 0.0)+length(max(d, 0.0))-rad;
    }

    // Scissoring
    float scissorMask (vec2 p) {
      vec2 sc = (abs((scissorMat*vec3(p, 1.0)).xy)-scissorExt);
      sc = vec2(0.5, 0.5)-sc*scissorScale;
      return clamp(sc.x, 0.0, 1.0)*clamp(sc.y, 0.0, 1.0);
    }
    #ifdef EDGE_AA
    // Stroke - from [0..1] to clipped pyramid, where the slope is 1px.
    float strokeMask () {
      return min(1.0, (1.0-abs(ftcoord.x*2.0-1.0))*strokeMult)*min(1.0, ftcoord.y);
    }
    #endif

    void main(void) {
      vec4 result;
      float scissor = scissorMask(fpos);
      #ifdef EDGE_AA
      float strokeAlpha = strokeMask();
      #else
      float strokeAlpha = 1.0;
      #endif
      if (type == 0) {
        // Gradient
        // Calculate gradient color using box gradient
        vec2 pt = (paintMat*vec3(fpos, 1.0)).xy;
        float d = clamp((sdroundrect(pt, extent, radius)+feather*0.5)/feather, 0.0, 1.0);
        vec4 color = mix(innerCol, outerCol, d);
        // Combine alpha
        color *= strokeAlpha*scissor;
        result = color;
      } else if (type == 1) {
        // Image
        // Calculate color from texture
        vec2 pt = (paintMat*vec3(fpos, 1.0)).xy/extent;
        vec4 color = texture2D(tex, pt);
        if (texType == 1) color = vec4(color.xyz*color.w, color.w);
        if (texType == 2) color = vec4(color.x);
        // Apply color tint and alpha.
        color *= innerCol;
        // Combine alpha
        color *= strokeAlpha*scissor;
        result = color;
      } else if (type == 2) {
        // Stencil fill
        result = vec4(1, 1, 1, 1);
      } else if (type == 3) {
        // Textured tris
        vec4 color = texture2D(tex, ftcoord);
        if (texType == 1) color = vec4(color.xyz*color.w, color.w);
        if (texType == 2) color = vec4(color.x);
        color *= scissor;
        result = color*innerCol;
      }
      #ifdef EDGE_AA
      if (strokeAlpha < strokeThr) discard;
      #endif
      gl_FragColor = result;
    }
  };

  glnvg__checkError(gl, "init");

  if (gl.flags&NVG_ANTIALIAS) {
    if (!glnvg__createShader(&gl.shader, "shader", shaderHeader, "#define EDGE_AA 1\n", fillVertShader, fillFragShader)) return false;
  } else {
    if (!glnvg__createShader(&gl.shader, "shader", shaderHeader, null, fillVertShader, fillFragShader)) return false;
  }

  glnvg__checkError(gl, "uniform locations");
  glnvg__getUniforms(&gl.shader);

  // Create dynamic vertex array
  glGenBuffers(1, &gl.vertBuf);

  gl.fragSize = (GLNVGfragUniforms).sizeof+align_-GLNVGfragUniforms.sizeof%align_;

  glnvg__checkError(gl, "create done");

  glFinish();

  return true;
}

int glnvg__renderCreateTexture (void* uptr, NVGtexture type, int w, int h, int imageFlags, const(ubyte)* data) {
  GLNVGcontext* gl = cast(GLNVGcontext*)uptr;
  GLNVGtexture* tex = glnvg__allocTexture(gl);

  if (tex is null) return 0;

  glGenTextures(1, &tex.tex);
  tex.width = w;
  tex.height = h;
  tex.type = type;
  tex.flags = imageFlags;
  glnvg__bindTexture(gl, tex.tex);

  glPixelStorei(GL_UNPACK_ALIGNMENT,1);
  glPixelStorei(GL_UNPACK_ROW_LENGTH, tex.width);
  glPixelStorei(GL_UNPACK_SKIP_PIXELS, 0);
  glPixelStorei(GL_UNPACK_SKIP_ROWS, 0);

  // GL 1.4 and later has support for generating mipmaps using a tex parameter.
  if (imageFlags&NVGImageFlags.GenerateMipmaps) glTexParameteri(GL_TEXTURE_2D, GL_GENERATE_MIPMAP, GL_TRUE);

  if (type == NVGtexture.RGBA) {
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE, data);
  } else {
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RED, w, h, 0, GL_RED, GL_UNSIGNED_BYTE, data);
  }

  if (imageFlags&NVGImageFlags.GenerateMipmaps) {
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
  } else {
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  }
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

  if (imageFlags&NVGImageFlags.RepeatX) {
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
  } else {
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  }

  if (imageFlags&NVGImageFlags.RepeatY) {
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
  } else {
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  }

  glPixelStorei(GL_UNPACK_ALIGNMENT, 4);
  glPixelStorei(GL_UNPACK_ROW_LENGTH, 0);
  glPixelStorei(GL_UNPACK_SKIP_PIXELS, 0);
  glPixelStorei(GL_UNPACK_SKIP_ROWS, 0);

  glnvg__checkError(gl, "create tex");
  glnvg__bindTexture(gl, 0);

  return tex.id;
}


bool glnvg__renderDeleteTexture (void* uptr, int image) {
  GLNVGcontext* gl = cast(GLNVGcontext*)uptr;
  return glnvg__deleteTexture(gl, image);
}

bool glnvg__renderUpdateTexture (void* uptr, int image, int x, int y, int w, int h, const(ubyte)* data) {
  GLNVGcontext* gl = cast(GLNVGcontext*)uptr;
  GLNVGtexture* tex = glnvg__findTexture(gl, image);

  if (tex is null) return false;
  glnvg__bindTexture(gl, tex.tex);

  glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
  glPixelStorei(GL_UNPACK_ROW_LENGTH, tex.width);
  glPixelStorei(GL_UNPACK_SKIP_PIXELS, x);
  glPixelStorei(GL_UNPACK_SKIP_ROWS, y);

  if (tex.type == NVGtexture.RGBA) {
    glTexSubImage2D(GL_TEXTURE_2D, 0, x,y, w,h, GL_RGBA, GL_UNSIGNED_BYTE, data);
  } else {
    glTexSubImage2D(GL_TEXTURE_2D, 0, x,y, w,h, GL_RED, GL_UNSIGNED_BYTE, data);
  }

  glPixelStorei(GL_UNPACK_ALIGNMENT, 4);
  glPixelStorei(GL_UNPACK_ROW_LENGTH, 0);
  glPixelStorei(GL_UNPACK_SKIP_PIXELS, 0);
  glPixelStorei(GL_UNPACK_SKIP_ROWS, 0);

  glnvg__bindTexture(gl, 0);

  return true;
}

bool glnvg__renderGetTextureSize (void* uptr, int image, int* w, int* h) {
  GLNVGcontext* gl = cast(GLNVGcontext*)uptr;
  GLNVGtexture* tex = glnvg__findTexture(gl, image);
  if (tex is null) return false;
  *w = tex.width;
  *h = tex.height;
  return true;
}

void glnvg__xformToMat3x4 (float[] m3, const(float)[] t) {
  version(nanosvg_asserts) assert(t.length > 5);
  version(nanosvg_asserts) assert(m3.length > 11);
  m3.ptr[0] = t.ptr[0];
  m3.ptr[1] = t.ptr[1];
  m3.ptr[2] = 0.0f;
  m3.ptr[3] = 0.0f;
  m3.ptr[4] = t.ptr[2];
  m3.ptr[5] = t.ptr[3];
  m3.ptr[6] = 0.0f;
  m3.ptr[7] = 0.0f;
  m3.ptr[8] = t.ptr[4];
  m3.ptr[9] = t.ptr[5];
  m3.ptr[10] = 1.0f;
  m3.ptr[11] = 0.0f;
}

NVGColor glnvg__premulColor (NVGColor c) {
  //pragma(inline, true);
  c.r *= c.a;
  c.g *= c.a;
  c.b *= c.a;
  return c;
}

bool glnvg__convertPaint (GLNVGcontext* gl, GLNVGfragUniforms* frag, NVGPaint* paint, NVGscissor* scissor, float width, float fringe, float strokeThr) {
  import core.stdc.math : sqrtf;
  GLNVGtexture* tex = null;
  float[6] invxform;

  memset(frag, 0, (*frag).sizeof);

  frag.innerCol = glnvg__premulColor(paint.innerColor);
  frag.outerCol = glnvg__premulColor(paint.outerColor);

  if (scissor.extent[0] < -0.5f || scissor.extent[1] < -0.5f) {
    memset(frag.scissorMat.ptr, 0, frag.scissorMat.sizeof);
    frag.scissorExt[0] = 1.0f;
    frag.scissorExt[1] = 1.0f;
    frag.scissorScale[0] = 1.0f;
    frag.scissorScale[1] = 1.0f;
  } else {
    nvgTransformInverse(invxform[], scissor.xform[]);
    glnvg__xformToMat3x4(frag.scissorMat[], invxform[]);
    frag.scissorExt[0] = scissor.extent[0];
    frag.scissorExt[1] = scissor.extent[1];
    frag.scissorScale[0] = sqrtf(scissor.xform[0]*scissor.xform[0]+scissor.xform[2]*scissor.xform[2])/fringe;
    frag.scissorScale[1] = sqrtf(scissor.xform[1]*scissor.xform[1]+scissor.xform[3]*scissor.xform[3])/fringe;
  }

  memcpy(frag.extent.ptr, paint.extent.ptr, frag.extent.sizeof);
  frag.strokeMult = (width*0.5f+fringe*0.5f)/fringe;
  frag.strokeThr = strokeThr;

  if (paint.image != 0) {
    tex = glnvg__findTexture(gl, paint.image);
    if (tex is null) return false;
    if ((tex.flags&NVGImageFlags.FlipY) != 0) {
      float[6] flipped;
      nvgTransformScale(flipped[], 1.0f, -1.0f);
      nvgTransformMultiply(flipped[], paint.xform[]);
      nvgTransformInverse(invxform[], flipped[]);
    } else {
      nvgTransformInverse(invxform[], paint.xform[]);
    }
    frag.type = NSVG_SHADER_FILLIMG;

    if (tex.type == NVGtexture.RGBA) {
      frag.texType = (tex.flags&NVGImageFlags.Premultiplied ? 0 : 1);
    } else {
      frag.texType = 2;
    }
    //printf("frag.texType = %d\n", frag.texType);
  } else {
    frag.type = NSVG_SHADER_FILLGRAD;
    frag.radius = paint.radius;
    frag.feather = paint.feather;
    nvgTransformInverse(invxform[], paint.xform[]);
  }

  glnvg__xformToMat3x4(frag.paintMat[], invxform[]);

  return true;
}

void glnvg__setUniforms (GLNVGcontext* gl, int uniformOffset, int image) {
  GLNVGfragUniforms* frag = nvg__fragUniformPtr(gl, uniformOffset);
  glUniform4fv(gl.shader.loc[GLNVG_LOC_FRAG], NANOVG_GL_UNIFORMARRAY_SIZE, &(frag.uniformArray[0][0]));
  if (image != 0) {
    GLNVGtexture* tex = glnvg__findTexture(gl, image);
    glnvg__bindTexture(gl, tex !is null ? tex.tex : 0);
    glnvg__checkError(gl, "tex paint tex");
  } else {
    glnvg__bindTexture(gl, 0);
  }
}

void glnvg__renderViewport (void* uptr, int width, int height) {
  GLNVGcontext* gl = cast(GLNVGcontext*)uptr;
  gl.view[0] = cast(float)width;
  gl.view[1] = cast(float)height;
}

void glnvg__fill (GLNVGcontext* gl, GLNVGcall* call) {
  GLNVGpath* paths = &gl.paths[call.pathOffset];
  int npaths = call.pathCount;

  // Draw shapes
  glEnable(GL_STENCIL_TEST);
  glnvg__stencilMask(gl, 0xff);
  glnvg__stencilFunc(gl, GL_ALWAYS, 0, 0xff);
  glColorMask(GL_FALSE, GL_FALSE, GL_FALSE, GL_FALSE);

  // set bindpoint for solid loc
  glnvg__setUniforms(gl, call.uniformOffset, 0);
  glnvg__checkError(gl, "fill simple");

  glStencilOpSeparate(GL_FRONT, GL_KEEP, GL_KEEP, GL_INCR_WRAP);
  glStencilOpSeparate(GL_BACK, GL_KEEP, GL_KEEP, GL_DECR_WRAP);
  glDisable(GL_CULL_FACE);
  foreach (int i; 0..npaths) glDrawArrays(GL_TRIANGLE_FAN, paths[i].fillOffset, paths[i].fillCount);
  glEnable(GL_CULL_FACE);

  // Draw anti-aliased pixels
  glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);

  glnvg__setUniforms(gl, call.uniformOffset+gl.fragSize, call.image);
  glnvg__checkError(gl, "fill fill");

  if (gl.flags&NVG_ANTIALIAS) {
    glnvg__stencilFunc(gl, GL_EQUAL, 0x00, 0xff);
    glStencilOp(GL_KEEP, GL_KEEP, GL_KEEP);
    // Draw fringes
    foreach (int i; 0..npaths) glDrawArrays(GL_TRIANGLE_STRIP, paths[i].strokeOffset, paths[i].strokeCount);
  }

  // Draw fill
  glnvg__stencilFunc(gl, GL_NOTEQUAL, 0x0, 0xff);
  glStencilOp(GL_ZERO, GL_ZERO, GL_ZERO);
  glDrawArrays(GL_TRIANGLES, call.triangleOffset, call.triangleCount);

  glDisable(GL_STENCIL_TEST);
}

void glnvg__convexFill (GLNVGcontext* gl, GLNVGcall* call) {
  GLNVGpath* paths = &gl.paths[call.pathOffset];
  int npaths = call.pathCount;

  glnvg__setUniforms(gl, call.uniformOffset, call.image);
  glnvg__checkError(gl, "convex fill");

  foreach (int i; 0..npaths) glDrawArrays(GL_TRIANGLE_FAN, paths[i].fillOffset, paths[i].fillCount);
  if (gl.flags&NVG_ANTIALIAS) {
    // Draw fringes
    foreach (int i; 0..npaths) glDrawArrays(GL_TRIANGLE_STRIP, paths[i].strokeOffset, paths[i].strokeCount);
  }
}

void glnvg__stroke (GLNVGcontext* gl, GLNVGcall* call) {
  GLNVGpath* paths = &gl.paths[call.pathOffset];
  int npaths = call.pathCount;

  if (gl.flags&NVG_STENCIL_STROKES) {
    glEnable(GL_STENCIL_TEST);
    glnvg__stencilMask(gl, 0xff);

    // Fill the stroke base without overlap
    glnvg__stencilFunc(gl, GL_EQUAL, 0x0, 0xff);
    glStencilOp(GL_KEEP, GL_KEEP, GL_INCR);
    glnvg__setUniforms(gl, call.uniformOffset+gl.fragSize, call.image);
    glnvg__checkError(gl, "stroke fill 0");
    foreach (int i; 0..npaths) glDrawArrays(GL_TRIANGLE_STRIP, paths[i].strokeOffset, paths[i].strokeCount);

    // Draw anti-aliased pixels.
    glnvg__setUniforms(gl, call.uniformOffset, call.image);
    glnvg__stencilFunc(gl, GL_EQUAL, 0x00, 0xff);
    glStencilOp(GL_KEEP, GL_KEEP, GL_KEEP);
    foreach (int i; 0..npaths) glDrawArrays(GL_TRIANGLE_STRIP, paths[i].strokeOffset, paths[i].strokeCount);

    // Clear stencil buffer.
    glColorMask(GL_FALSE, GL_FALSE, GL_FALSE, GL_FALSE);
    glnvg__stencilFunc(gl, GL_ALWAYS, 0x0, 0xff);
    glStencilOp(GL_ZERO, GL_ZERO, GL_ZERO);
    glnvg__checkError(gl, "stroke fill 1");
    foreach (int i; 0..npaths) glDrawArrays(GL_TRIANGLE_STRIP, paths[i].strokeOffset, paths[i].strokeCount);
    glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);

    glDisable(GL_STENCIL_TEST);

    //glnvg__convertPaint(gl, nvg__fragUniformPtr(gl, call.uniformOffset+gl.fragSize), paint, scissor, strokeWidth, fringe, 1.0f-0.5f/255.0f);
  } else {
    glnvg__setUniforms(gl, call.uniformOffset, call.image);
    glnvg__checkError(gl, "stroke fill");
    // Draw Strokes
    foreach (int i; 0..npaths) glDrawArrays(GL_TRIANGLE_STRIP, paths[i].strokeOffset, paths[i].strokeCount);
  }
}

void glnvg__triangles (GLNVGcontext* gl, GLNVGcall* call) {
  glnvg__setUniforms(gl, call.uniformOffset, call.image);
  glnvg__checkError(gl, "triangles fill");
  glDrawArrays(GL_TRIANGLES, call.triangleOffset, call.triangleCount);
}

void glnvg__renderCancel (void* uptr) {
  GLNVGcontext* gl = cast(GLNVGcontext*)uptr;
  gl.nverts = 0;
  gl.npaths = 0;
  gl.ncalls = 0;
  gl.nuniforms = 0;
}

void glnvg__renderFlush (void* uptr) {
  GLNVGcontext* gl = cast(GLNVGcontext*)uptr;
  if (gl.ncalls > 0) {
    // Setup require GL state.
    glUseProgram(gl.shader.prog);

    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    glEnable(GL_CULL_FACE);
    glCullFace(GL_BACK);
    glFrontFace(GL_CCW);
    glEnable(GL_BLEND);
    glDisable(GL_DEPTH_TEST);
    glDisable(GL_SCISSOR_TEST);
    glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);
    glStencilMask(0xffffffff);
    glStencilOp(GL_KEEP, GL_KEEP, GL_KEEP);
    glStencilFunc(GL_ALWAYS, 0, 0xffffffff);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, 0);
    static if (NANOVG_GL_USE_STATE_FILTER) {
      gl.boundTexture = 0;
      gl.stencilMask = 0xffffffff;
      gl.stencilFunc = GL_ALWAYS;
      gl.stencilFuncRef = 0;
      gl.stencilFuncMask = 0xffffffff;
    }

    // Upload vertex data
    glBindBuffer(GL_ARRAY_BUFFER, gl.vertBuf);
    glBufferData(GL_ARRAY_BUFFER, gl.nverts*NVGvertex.sizeof, gl.verts, GL_STREAM_DRAW);
    glEnableVertexAttribArray(0);
    glEnableVertexAttribArray(1);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, NVGvertex.sizeof, cast(const(GLvoid)*)cast(size_t)0);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, NVGvertex.sizeof, cast(const(GLvoid)*)(0+2*(float).sizeof));

    // Set view and texture just once per frame.
    glUniform1i(gl.shader.loc[GLNVG_LOC_TEX], 0);
    glUniform2fv(gl.shader.loc[GLNVG_LOC_VIEWSIZE], 1, gl.view.ptr);

    foreach (int i; 0..gl.ncalls) {
      GLNVGcall* call = &gl.calls[i];
           if (call.type == GLNVG_FILL) glnvg__fill(gl, call);
      else if (call.type == GLNVG_CONVEXFILL) glnvg__convexFill(gl, call);
      else if (call.type == GLNVG_STROKE) glnvg__stroke(gl, call);
      else if (call.type == GLNVG_TRIANGLES) glnvg__triangles(gl, call);
    }

    glDisableVertexAttribArray(0);
    glDisableVertexAttribArray(1);
    glDisable(GL_CULL_FACE);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glUseProgram(0);
    glnvg__bindTexture(gl, 0);
  }

  // Reset calls
  gl.nverts = 0;
  gl.npaths = 0;
  gl.ncalls = 0;
  gl.nuniforms = 0;
}

int glnvg__maxVertCount (const(NVGpath)* paths, int npaths) {
  int count = 0;
  foreach (int i; 0..npaths) {
    count += paths[i].nfill;
    count += paths[i].nstroke;
  }
  return count;
}

GLNVGcall* glnvg__allocCall (GLNVGcontext* gl) {
  GLNVGcall* ret = null;
  if (gl.ncalls+1 > gl.ccalls) {
    GLNVGcall* calls;
    int ccalls = glnvg__maxi(gl.ncalls+1, 128)+gl.ccalls/2; // 1.5x Overallocate
    calls = cast(GLNVGcall*)realloc(gl.calls, (GLNVGcall).sizeof*ccalls);
    if (calls is null) return null;
    gl.calls = calls;
    gl.ccalls = ccalls;
  }
  ret = &gl.calls[gl.ncalls++];
  memset(ret, 0, (GLNVGcall).sizeof);
  return ret;
}

int glnvg__allocPaths (GLNVGcontext* gl, int n) {
  int ret = 0;
  if (gl.npaths+n > gl.cpaths) {
    GLNVGpath* paths;
    int cpaths = glnvg__maxi(gl.npaths+n, 128)+gl.cpaths/2; // 1.5x Overallocate
    paths = cast(GLNVGpath*)realloc(gl.paths, (GLNVGpath).sizeof*cpaths);
    if (paths is null) return -1;
    gl.paths = paths;
    gl.cpaths = cpaths;
  }
  ret = gl.npaths;
  gl.npaths += n;
  return ret;
}

int glnvg__allocVerts (GLNVGcontext* gl, int n) {
  int ret = 0;
  if (gl.nverts+n > gl.cverts) {
    NVGvertex* verts;
    int cverts = glnvg__maxi(gl.nverts+n, 4096)+gl.cverts/2; // 1.5x Overallocate
    verts = cast(NVGvertex*)realloc(gl.verts, (NVGvertex).sizeof*cverts);
    if (verts is null) return -1;
    gl.verts = verts;
    gl.cverts = cverts;
  }
  ret = gl.nverts;
  gl.nverts += n;
  return ret;
}

int glnvg__allocFragUniforms (GLNVGcontext* gl, int n) {
  int ret = 0, structSize = gl.fragSize;
  if (gl.nuniforms+n > gl.cuniforms) {
    ubyte* uniforms;
    int cuniforms = glnvg__maxi(gl.nuniforms+n, 128)+gl.cuniforms/2; // 1.5x Overallocate
    uniforms = cast(ubyte*)realloc(gl.uniforms, structSize*cuniforms);
    if (uniforms is null) return -1;
    gl.uniforms = uniforms;
    gl.cuniforms = cuniforms;
  }
  ret = gl.nuniforms*structSize;
  gl.nuniforms += n;
  return ret;
}

GLNVGfragUniforms* nvg__fragUniformPtr (GLNVGcontext* gl, int i) {
  return cast(GLNVGfragUniforms*)&gl.uniforms[i];
}

void glnvg__vset (NVGvertex* vtx, float x, float y, float u, float v) {
  vtx.x = x;
  vtx.y = y;
  vtx.u = u;
  vtx.v = v;
}

void glnvg__renderFill (void* uptr, NVGPaint* paint, NVGscissor* scissor, float fringe, const(float)* bounds, const(NVGpath)* paths, int npaths) {
  GLNVGcontext* gl = cast(GLNVGcontext*)uptr;
  GLNVGcall* call = glnvg__allocCall(gl);
  NVGvertex* quad;
  GLNVGfragUniforms* frag;
  int maxverts, offset;

  if (call is null) return;

  call.type = GLNVG_FILL;
  call.pathOffset = glnvg__allocPaths(gl, npaths);
  if (call.pathOffset == -1) goto error;
  call.pathCount = npaths;
  call.image = paint.image;

  if (npaths == 1 && paths[0].convex) call.type = GLNVG_CONVEXFILL;

  // Allocate vertices for all the paths.
  maxverts = glnvg__maxVertCount(paths, npaths)+6;
  offset = glnvg__allocVerts(gl, maxverts);
  if (offset == -1) goto error;

  foreach (int i; 0..npaths) {
    GLNVGpath* copy = &gl.paths[call.pathOffset+i];
    const(NVGpath)* path = &paths[i];
    memset(copy, 0, GLNVGpath.sizeof);
    if (path.nfill > 0) {
      copy.fillOffset = offset;
      copy.fillCount = path.nfill;
      memcpy(&gl.verts[offset], path.fill, (NVGvertex).sizeof*path.nfill);
      offset += path.nfill;
    }
    if (path.nstroke > 0) {
      copy.strokeOffset = offset;
      copy.strokeCount = path.nstroke;
      memcpy(&gl.verts[offset], path.stroke, (NVGvertex).sizeof*path.nstroke);
      offset += path.nstroke;
    }
  }

  // Quad
  call.triangleOffset = offset;
  call.triangleCount = 6;
  quad = &gl.verts[call.triangleOffset];
  glnvg__vset(&quad[0], bounds[0], bounds[3], 0.5f, 1.0f);
  glnvg__vset(&quad[1], bounds[2], bounds[3], 0.5f, 1.0f);
  glnvg__vset(&quad[2], bounds[2], bounds[1], 0.5f, 1.0f);

  glnvg__vset(&quad[3], bounds[0], bounds[3], 0.5f, 1.0f);
  glnvg__vset(&quad[4], bounds[2], bounds[1], 0.5f, 1.0f);
  glnvg__vset(&quad[5], bounds[0], bounds[1], 0.5f, 1.0f);

  // Setup uniforms for draw calls
  if (call.type == GLNVG_FILL) {
    call.uniformOffset = glnvg__allocFragUniforms(gl, 2);
    if (call.uniformOffset == -1) goto error;
    // Simple shader for stencil
    frag = nvg__fragUniformPtr(gl, call.uniformOffset);
    memset(frag, 0, (*frag).sizeof);
    frag.strokeThr = -1.0f;
    frag.type = NSVG_SHADER_SIMPLE;
    // Fill shader
    glnvg__convertPaint(gl, nvg__fragUniformPtr(gl, call.uniformOffset+gl.fragSize), paint, scissor, fringe, fringe, -1.0f);
  } else {
    call.uniformOffset = glnvg__allocFragUniforms(gl, 1);
    if (call.uniformOffset == -1) goto error;
    // Fill shader
    glnvg__convertPaint(gl, nvg__fragUniformPtr(gl, call.uniformOffset), paint, scissor, fringe, fringe, -1.0f);
  }

  return;

error:
  // We get here if call alloc was ok, but something else is not.
  // Roll back the last call to prevent drawing it.
  if (gl.ncalls > 0) --gl.ncalls;
}

void glnvg__renderStroke (void* uptr, NVGPaint* paint, NVGscissor* scissor, float fringe, float strokeWidth, const(NVGpath)* paths, int npaths) {
  GLNVGcontext* gl = cast(GLNVGcontext*)uptr;
  GLNVGcall* call = glnvg__allocCall(gl);
  int maxverts, offset;

  if (call is null) return;

  call.type = GLNVG_STROKE;
  call.pathOffset = glnvg__allocPaths(gl, npaths);
  if (call.pathOffset == -1) goto error;
  call.pathCount = npaths;
  call.image = paint.image;

  // Allocate vertices for all the paths.
  maxverts = glnvg__maxVertCount(paths, npaths);
  offset = glnvg__allocVerts(gl, maxverts);
  if (offset == -1) goto error;

  foreach (int i; 0..npaths) {
    GLNVGpath* copy = &gl.paths[call.pathOffset+i];
    const(NVGpath)* path = &paths[i];
    memset(copy, 0, GLNVGpath.sizeof);
    if (path.nstroke) {
      copy.strokeOffset = offset;
      copy.strokeCount = path.nstroke;
      memcpy(&gl.verts[offset], path.stroke, (NVGvertex).sizeof*path.nstroke);
      offset += path.nstroke;
    }
  }

  if (gl.flags&NVG_STENCIL_STROKES) {
    // Fill shader
    call.uniformOffset = glnvg__allocFragUniforms(gl, 2);
    if (call.uniformOffset == -1) goto error;
    glnvg__convertPaint(gl, nvg__fragUniformPtr(gl, call.uniformOffset), paint, scissor, strokeWidth, fringe, -1.0f);
    glnvg__convertPaint(gl, nvg__fragUniformPtr(gl, call.uniformOffset+gl.fragSize), paint, scissor, strokeWidth, fringe, 1.0f-0.5f/255.0f);
  } else {
    // Fill shader
    call.uniformOffset = glnvg__allocFragUniforms(gl, 1);
    if (call.uniformOffset == -1) goto error;
    glnvg__convertPaint(gl, nvg__fragUniformPtr(gl, call.uniformOffset), paint, scissor, strokeWidth, fringe, -1.0f);
  }

  return;

error:
  // We get here if call alloc was ok, but something else is not.
  // Roll back the last call to prevent drawing it.
  if (gl.ncalls > 0) --gl.ncalls;
}

void glnvg__renderTriangles (void* uptr, NVGPaint* paint, NVGscissor* scissor, const(NVGvertex)* verts, int nverts) {
  GLNVGcontext* gl = cast(GLNVGcontext*)uptr;
  GLNVGcall* call = glnvg__allocCall(gl);
  GLNVGfragUniforms* frag;

  if (call is null) return;

  call.type = GLNVG_TRIANGLES;
  call.image = paint.image;

  // Allocate vertices for all the paths.
  call.triangleOffset = glnvg__allocVerts(gl, nverts);
  if (call.triangleOffset == -1) goto error;
  call.triangleCount = nverts;

  memcpy(&gl.verts[call.triangleOffset], verts, NVGvertex.sizeof*nverts);

  // Fill shader
  call.uniformOffset = glnvg__allocFragUniforms(gl, 1);
  if (call.uniformOffset == -1) goto error;
  frag = nvg__fragUniformPtr(gl, call.uniformOffset);
  glnvg__convertPaint(gl, frag, paint, scissor, 1.0f, 1.0f, -1.0f);
  frag.type = NSVG_SHADER_IMG;

  return;

error:
  // We get here if call alloc was ok, but something else is not.
  // Roll back the last call to prevent drawing it.
  if (gl.ncalls > 0) --gl.ncalls;
}

void glnvg__renderDelete (void* uptr) {
  GLNVGcontext* gl = cast(GLNVGcontext*)uptr;
  if (gl is null) return;

  glnvg__deleteShader(&gl.shader);

  if (gl.vertBuf != 0) glDeleteBuffers(1, &gl.vertBuf);

  foreach (int i; 0..gl.ntextures) {
    if (gl.textures[i].tex != 0 && (gl.textures[i].flags&NVG_IMAGE_NODELETE) == 0) glDeleteTextures(1, &gl.textures[i].tex);
  }
  free(gl.textures);

  free(gl.paths);
  free(gl.verts);
  free(gl.uniforms);
  free(gl.calls);

  free(gl);
}


/// Creates NanoVG contexts for OpenGL versions.
/// Flags should be combination of the create flags above.
public NVGContext createGL2NVG (int flags) {
  NVGparams params;
  NVGContext ctx = null;
  nanovgInitOpenGL(); // why not?
  GLNVGcontext* gl = cast(GLNVGcontext*)malloc(GLNVGcontext.sizeof);
  if (gl is null) goto error;
  memset(gl, 0, GLNVGcontext.sizeof);

  memset(&params, 0, params.sizeof);
  params.renderCreate = &glnvg__renderCreate;
  params.renderCreateTexture = &glnvg__renderCreateTexture;
  params.renderDeleteTexture = &glnvg__renderDeleteTexture;
  params.renderUpdateTexture = &glnvg__renderUpdateTexture;
  params.renderGetTextureSize = &glnvg__renderGetTextureSize;
  params.renderViewport = &glnvg__renderViewport;
  params.renderCancel = &glnvg__renderCancel;
  params.renderFlush = &glnvg__renderFlush;
  params.renderFill = &glnvg__renderFill;
  params.renderStroke = &glnvg__renderStroke;
  params.renderTriangles = &glnvg__renderTriangles;
  params.renderDelete = &glnvg__renderDelete;
  params.userPtr = gl;
  params.edgeAntiAlias = (flags&NVG_ANTIALIAS ? true : false);

  gl.flags = flags;

  ctx = createInternal(&params);
  if (ctx is null) goto error;

  return ctx;

error:
  // 'gl' is freed by nvgDeleteInternal.
  if (ctx !is null) ctx.deleteInternal();
  return null;
}

/// Delete NanoVG OpenGL context.
public void deleteGL2 (NVGContext ctx) {
  if (ctx !is null) ctx.deleteInternal();
}

/// Create NanoVG OpenGL image from texture id.
public int glCreateImageFromHandleGL2 (NVGContext ctx, GLuint textureId, int w, int h, int imageFlags) {
  GLNVGcontext* gl = cast(GLNVGcontext*)ctx.internalParams().userPtr;
  GLNVGtexture* tex = glnvg__allocTexture(gl);

  if (tex is null) return 0;

  tex.type = NVGtexture.RGBA;
  tex.tex = textureId;
  tex.flags = imageFlags;
  tex.width = w;
  tex.height = h;

  return tex.id;
}

/// Return OpenGL texture id for NanoVG image.
public GLuint glImageHandleGL2 (NVGContext ctx, int image) {
  GLNVGcontext* gl = cast(GLNVGcontext*)ctx.internalParams().userPtr;
  GLNVGtexture* tex = glnvg__findTexture(gl, image);
  return tex.tex;
}
