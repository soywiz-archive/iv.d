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
module iv.nanovg.engine;

import core.stdc.stdlib : malloc, realloc, free;
import core.stdc.string : memset, memcpy, strlen;
import std.math : PI;
import iv.nanovg.fontstash;

alias NVG_PI = PI;

version = nanovg_use_arsd_image;

version(nanovg_use_arsd_image) {
  import arsd.color;
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
  union {
    float[4] rgba;
    align(1) struct {
    align(1):
      float r, g, b, a;
    }
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

///
enum NVGAlign {
  // Horizontal align
  Left     = 1<<0, /// Default, align text horizontally to left.
  Center   = 1<<1, /// Align text horizontally to center.
  Right    = 1<<2, /// Align text horizontally to right.
  // Vertical align
  Top      = 1<<3, /// Align text vertically to top.
  Middle   = 1<<4, /// Align text vertically to middle.
  Bottom   = 1<<5, /// Align text vertically to bottom.
  Baseline = 1<<6, /// Default, align text vertically to baseline.
}

///
struct NVGGlyphPosition {
  const(char)* str; /// Position of the glyph in the input string.
  float x;          /// The x-coordinate of the logical glyph position.
  float minx, maxx; /// The bounds of the glyph shape.
}

///
struct NVGTextRow {
  const(char)* start; /// Pointer to the input text where the row starts.
  const(char)* end;   /// Pointer to the input text where the row ends (one past the last character).
  const(char)* next;  /// Pointer to the beginning of the next row.
  float width;        /// Logical width of the row.
  float minx, maxx;   /// Actual bounds of the row. Logical with and bounds can differ because of kerning and some parts over extending.
const pure nothrow @trusted @nogc:
  @property int nextpos () { pragma(inline, true); return cast(int)(cast(size_t)next-cast(size_t)start); } ///
}

///
enum NVGImageFlags {
  GenerateMipmaps = 1<<0, /// Generate mipmaps during creation of the image.
  RepeatX         = 1<<1, /// Repeat image in X direction.
  RepeatY         = 1<<2, /// Repeat image in Y direction.
  FlipY           = 1<<3, /// Flips (inverses) image in Y direction when rendered.
  Premultiplied   = 1<<4, /// Image data has premultiplied alpha.
}

// ////////////////////////////////////////////////////////////////////////// //
package(iv.nanovg):

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
  int edgeAntiAlias;
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
  int textAlign;
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

int nvg__mini() (int a, int b) { pragma(inline, true); return (a < b ? a : b); }
int nvg__maxi() (int a, int b) { pragma(inline, true); return (a > b ? a : b); }
int nvg__clampi() (int a, int mn, int mx) { pragma(inline, true); return (a < mn ? mn : (a > mx ? mx : a)); }
float nvg__minf() (float a, float b) { pragma(inline, true); return (a < b ? a : b); }
float nvg__maxf() (float a, float b) { pragma(inline, true); return (a > b ? a : b); }
float nvg__absf() (float a) { pragma(inline, true); return (a >= 0.0f ? a : -a); }
float nvg__signf() (float a) { pragma(inline, true); return (a >= 0.0f ? 1.0f : -1.0f); }
float nvg__clampf() (float a, float mn, float mx) { pragma(inline, true); return (a < mn ? mn : (a > mx ? mx : a)); }
float nvg__cross() (float dx0, float dy0, float dx1, float dy1) { pragma(inline, true); return (dx1*dy0-dx0*dy1); }

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
package(iv.nanovg) NVGContext createInternal (NVGparams* params) {
  FONSparams fontParams;
  NVGContext ctx = cast(NVGContext )malloc(NVGcontext.sizeof);
  if (ctx is null) goto error;
  memset(ctx, 0, NVGcontext.sizeof);

  ctx.params = *params;
  foreach (uint i; 0..NVG_MAX_FONTIMAGES) ctx.fontImages[i] = 0;

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
package(iv.nanovg) NVGparams* internalParams (NVGContext ctx) {
  return &ctx.params;
}

// Destructor called by the render back-end.
package(iv.nanovg) void deleteInternal (NVGContext ctx) {
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

  if (isNaN(devicePixelRatio)) {
    devicePixelRatio = (windowHeight > 0 ? cast(float)windowWidth/cast(float)windowHeight : 1024.0/768.0);
  }

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
    int i, j, iw, ih;
    // delete images that smaller than current one
    if (fontImage == 0) return;
    ctx.imageSize(fontImage, &iw, &ih);
    for (i = j = 0; i < ctx.fontImageIdx; i++) {
      if (ctx.fontImages[i] != 0) {
        int nw, nh;
        ctx.imageSize(ctx.fontImages[i], &nw, &nh);
        if (nw < iw || nh < ih) ctx.deleteImage(ctx.fontImages[i]); else ctx.fontImages[j++] = ctx.fontImages[i];
      }
    }
    // make current font image to first
    ctx.fontImages[j++] = ctx.fontImages[0];
    ctx.fontImages[0] = fontImage;
    ctx.fontImageIdx = 0;
    // clear all images after j
    for (i = j; i < NVG_MAX_FONTIMAGES; i++) ctx.fontImages[i] = 0;
  }
}

// ////////////////////////////////////////////////////////////////////////// //
/// <h1>Color utils</h1>
/// Colors in NanoVG are stored as unsigned ints in ABGR format.
public alias NVGSectionDummy00 = void;

/// Returns a color value from red, green, blue values. Alpha will be set to 255 (1.0f).
public NVGColor nvgRGB() (ubyte r, ubyte g, ubyte b) {
  pragma(inline, true);
  return nvgRGBA(r, g, b, 255);
}

/// Returns a color value from red, green, blue values. Alpha will be set to 1.0f.
public NVGColor nvgRGBf() (float r, float g, float b) {
  pragma(inline, true);
  return nvgRGBAf(r, g, b, 1.0f);
}

/// Returns a color value from red, green, blue and alpha values.
public NVGColor nvgRGBA() (ubyte r, ubyte g, ubyte b, ubyte a=255) @trusted {
  pragma(inline, true);
  NVGColor color = void;
  // Use longer initialization to suppress warning.
  color.r = r/255.0f;
  color.g = g/255.0f;
  color.b = b/255.0f;
  color.a = a/255.0f;
  return color;
}

/// Returns a color value from red, green, blue and alpha values.
public NVGColor nvgRGBAf() (float r, float g, float b, float a=1) {
  pragma(inline, true);
  NVGColor color;
  // Use longer initialization to suppress warning.
  color.r = r;
  color.g = g;
  color.b = b;
  color.a = a;
  return color;
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
public NVGColor nvgLerpRGBA() (NVGColor c0, NVGColor c1, float u) {
  int i;
  float oneminu;
  NVGColor cint;
  u = nvg__clampf(u, 0.0f, 1.0f);
  oneminu = 1.0f-u;
  foreach (uint i; 0..4) cint.rgba[i] = c0.rgba[i]*oneminu+c1.rgba[i]*u;
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
  pragma(inline, true);
  float m1, m2;
  NVGColor col;
  h = nvg__modf(h, 1.0f);
  if (h < 0.0f) h += 1.0f;
  s = nvg__clampf(s, 0.0f, 1.0f);
  l = nvg__clampf(l, 0.0f, 1.0f);
  m2 = l <= 0.5f ? (l*(1+s)) : (l+s-l*s);
  m1 = 2*l-m2;
  col.r = nvg__clampf(nvg__hue(h+1.0f/3.0f, m1, m2), 0.0f, 1.0f);
  col.g = nvg__clampf(nvg__hue(h, m1, m2), 0.0f, 1.0f);
  col.b = nvg__clampf(nvg__hue(h-1.0f/3.0f, m1, m2), 0.0f, 1.0f);
  col.a = a/255.0f;
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
public void nvgTransformIdentity (float* t) {
  pragma(inline, true);
  t[0] = 1.0f; t[1] = 0.0f;
  t[2] = 0.0f; t[3] = 1.0f;
  t[4] = 0.0f; t[5] = 0.0f;
}

/// Sets the transform to translation matrix matrix.
public void nvgTransformTranslate (float* t, float tx, float ty) {
  pragma(inline, true);
  t[0] = 1.0f; t[1] = 0.0f;
  t[2] = 0.0f; t[3] = 1.0f;
  t[4] = tx; t[5] = ty;
}

/// Sets the transform to scale matrix.
public void nvgTransformScale (float* t, float sx, float sy) {
  pragma(inline, true);
  t[0] = sx; t[1] = 0.0f;
  t[2] = 0.0f; t[3] = sy;
  t[4] = 0.0f; t[5] = 0.0f;
}

/// Sets the transform to rotate matrix. Angle is specified in radians.
public void nvgTransformRotate (float* t, float a) {
  //pragma(inline, true);
  float cs = nvg__cosf(a), sn = nvg__sinf(a);
  t[0] = cs; t[1] = sn;
  t[2] = -sn; t[3] = cs;
  t[4] = 0.0f; t[5] = 0.0f;
}

/// Sets the transform to skew-x matrix. Angle is specified in radians.
public void nvgTransformSkewX (float* t, float a) {
  //pragma(inline, true);
  t[0] = 1.0f; t[1] = 0.0f;
  t[2] = nvg__tanf(a); t[3] = 1.0f;
  t[4] = 0.0f; t[5] = 0.0f;
}

/// Sets the transform to skew-y matrix. Angle is specified in radians.
public void nvgTransformSkewY (float* t, float a) {
  //pragma(inline, true);
  t[0] = 1.0f; t[1] = nvg__tanf(a);
  t[2] = 0.0f; t[3] = 1.0f;
  t[4] = 0.0f; t[5] = 0.0f;
}

/// Sets the transform to the result of multiplication of two transforms, of A = A*B.
public void nvgTransformMultiply (float* t, const(float)* s) {
  //pragma(inline, true);
  float t0 = t[0]*s[0]+t[1]*s[2];
  float t2 = t[2]*s[0]+t[3]*s[2];
  float t4 = t[4]*s[0]+t[5]*s[2]+s[4];
  t[1] = t[0]*s[1]+t[1]*s[3];
  t[3] = t[2]*s[1]+t[3]*s[3];
  t[5] = t[4]*s[1]+t[5]*s[3]+s[5];
  t[0] = t0;
  t[2] = t2;
  t[4] = t4;
}

/// Sets the transform to the result of multiplication of two transforms, of A = B*A.
public void nvgTransformPremultiply (float* t, const(float)* s) {
  //pragma(inline, true);
  float[6] s2;
  memcpy(s2.ptr, s, (float).sizeof*6);
  nvgTransformMultiply(s2.ptr, t);
  memcpy(t, s2.ptr, (float).sizeof*6);
}

/// Sets the destination to inverse of specified transform.
/// Returns 1 if the inverse could be calculated, else 0.
public int nvgTransformInverse (float* inv, const(float)* t) {
  double det = cast(double)t[0]*t[3]-cast(double)t[2]*t[1];
  if (det > -1e-6 && det < 1e-6) {
    nvgTransformIdentity(inv);
    return 0;
  }
  double invdet = 1.0/det;
  inv[0] = cast(float)(t[3]*invdet);
  inv[2] = cast(float)(-t[2]*invdet);
  inv[4] = cast(float)((cast(double)t[2]*t[5]-cast(double)t[3]*t[4])*invdet);
  inv[1] = cast(float)(-t[1]*invdet);
  inv[3] = cast(float)(t[0]*invdet);
  inv[5] = cast(float)((cast(double)t[1]*t[4]-cast(double)t[0]*t[5])*invdet);
  return 1;
}

/// Transform a point by given transform.
public void nvgTransformPoint (float* dx, float* dy, const(float)* t, float sx, float sy) {
  pragma(inline, true);
  *dx = sx*t[0]+sy*t[2]+t[4];
  *dy = sx*t[1]+sy*t[3]+t[5];
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
  nvgTransformIdentity(p.xform.ptr);
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
 */
public void save (NVGContext ctx) {
  if (ctx.nstates >= NVG_MAX_STATES) return;
  if (ctx.nstates > 0) memcpy(&ctx.states[ctx.nstates], &ctx.states[ctx.nstates-1], (NVGstate).sizeof);
  ++ctx.nstates;
}

/// Pops and restores current render state.
public void restore (NVGContext ctx) {
  if (ctx.nstates <= 1) return;
  --ctx.nstates;
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
  nvgTransformIdentity(state.xform.ptr);

  state.scissor.extent[0] = -1.0f;
  state.scissor.extent[1] = -1.0f;

  state.fontSize = 16.0f;
  state.letterSpacing = 0.0f;
  state.lineHeight = 1.0f;
  state.fontBlur = 0.0f;
  state.textAlign = NVGAlign.Left|NVGAlign.Baseline;
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
  float[6] t = [ a, b, c, d, e, f ];
  nvgTransformPremultiply(state.xform.ptr, t.ptr);
}

/// Resets current transform to a identity matrix.
public void resetTransform (NVGContext ctx) {
  NVGstate* state = nvg__getState(ctx);
  nvgTransformIdentity(state.xform.ptr);
}

/// Translates current coordinate system.
public void translate (NVGContext ctx, float x, float y) {
  NVGstate* state = nvg__getState(ctx);
  float[6] t;
  nvgTransformTranslate(t.ptr, x, y);
  nvgTransformPremultiply(state.xform.ptr, t.ptr);
}

/// Rotates current coordinate system. Angle is specified in radians.
public void rotate (NVGContext ctx, float angle) {
  NVGstate* state = nvg__getState(ctx);
  float[6] t;
  nvgTransformRotate(t.ptr, angle);
  nvgTransformPremultiply(state.xform.ptr, t.ptr);
}

/// Skews the current coordinate system along X axis. Angle is specified in radians.
public void skewX (NVGContext ctx, float angle) {
  NVGstate* state = nvg__getState(ctx);
  float[6] t;
  nvgTransformSkewX(t.ptr, angle);
  nvgTransformPremultiply(state.xform.ptr, t.ptr);
}

/// Skews the current coordinate system along Y axis. Angle is specified in radians.
public void skewY (NVGContext ctx, float angle) {
  NVGstate* state = nvg__getState(ctx);
  float[6] t;
  nvgTransformSkewY(t.ptr, angle);
  nvgTransformPremultiply(state.xform.ptr, t.ptr);
}

/// Scales the current coordinate system.
public void scale (NVGContext ctx, float x, float y) {
  NVGstate* state = nvg__getState(ctx);
  float[6] t;
  nvgTransformScale(t.ptr, x, y);
  nvgTransformPremultiply(state.xform.ptr, t.ptr);
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
public void currentTransform (NVGContext ctx, float* xform) {
  NVGstate* state = nvg__getState(ctx);
  if (xform is null) return;
  memcpy(xform, state.xform.ptr, (float).sizeof*6);
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
  nvgTransformMultiply(state.stroke.xform.ptr, state.xform.ptr);
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
  nvgTransformMultiply(state.fill.xform.ptr, state.xform.ptr);
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
public int createImage (NVGContext ctx, const(char)[] filename, int imageFlags) {
  version(nanovg_use_arsd_image) {
    try {
      auto img = ArsdImage(filename).getAsTrueColorImage;
      scope(exit) img.destroy;
      return ctx.createImageRGBA(img.width, img.height, imageFlags, img.imageData.bytes.ptr);
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
    image = ctx.createImageRGBA(w, h, imageFlags, img);
    stbi_image_free(img);
    return image;
  }
}

version(nanovg_use_arsd_image) {
  /// Creates image by loading it from the specified chunk of memory.
  /// Returns handle to the image.
  public int createImageFromMemoryImage (NVGContext ctx, int imageFlags, MemoryImage img) {
    if (img is null) return 0;
    auto tc = img.getAsTrueColorImage;
    return ctx.createImageRGBA(tc.width, tc.height, imageFlags, tc.imageData.bytes.ptr);
  }
} else {
  /// Creates image by loading it from the specified chunk of memory.
  /// Returns handle to the image.
  public int createImageMem (NVGContext ctx, int imageFlags, ubyte* data, int ndata) {
    int w, h, n, image;
    ubyte* img = stbi_load_from_memory(data, ndata, &w, &h, &n, 4);
    if (img is null) {
      //printf("Failed to load %s - %s\n", filename, stbi_failure_reason());
      return 0;
    }
    image = ctx.createImageRGBA(w, h, imageFlags, img);
    stbi_image_free(img);
    return image;
  }
}

/// Creates image from specified image data.
/// Returns handle to the image.
public int createImageRGBA (NVGContext ctx, int w, int h, int imageFlags, const(ubyte)* data) {
  return ctx.params.renderCreateTexture(ctx.params.userPtr, NVGtexture.RGBA, w, h, imageFlags, data);
}

/// Updates image data specified by image handle.
public void updateImage (NVGContext ctx, int image, const(ubyte)* data) {
  int w, h;
  ctx.params.renderGetTextureSize(ctx.params.userPtr, image, &w, &h);
  ctx.params.renderUpdateTexture(ctx.params.userPtr, image, 0, 0, w, h, data);
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
  float dx, dy, d;
  const float large = 1e5;
  //NVG_NOTUSED(ctx);
  memset(&p, 0, p.sizeof);

  // Calculate transform aligned to the line
  dx = ex-sx;
  dy = ey-sy;
  d = nvg__sqrtf(dx*dx+dy*dy);
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

  p.feather = nvg__maxf(1.0f, d);

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
  float r = (inr+outr)*0.5f;
  float f = (outr-inr);
  //NVG_NOTUSED(ctx);
  memset(&p, 0, p.sizeof);

  nvgTransformIdentity(p.xform.ptr);
  p.xform.ptr[4] = cx;
  p.xform.ptr[5] = cy;

  p.extent[0] = r;
  p.extent[1] = r;

  p.radius = r;

  p.feather = nvg__maxf(1.0f, f);

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

  nvgTransformIdentity(p.xform.ptr);
  p.xform.ptr[4] = x+w*0.5f;
  p.xform.ptr[5] = y+h*0.5f;

  p.extent[0] = w*0.5f;
  p.extent[1] = h*0.5f;

  p.radius = r;

  p.feather = nvg__maxf(1.0f, f);

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

  nvgTransformRotate(p.xform.ptr, angle);
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

  w = nvg__maxf(0.0f, w);
  h = nvg__maxf(0.0f, h);

  nvgTransformIdentity(state.scissor.xform.ptr);
  state.scissor.xform.ptr[4] = x+w*0.5f;
  state.scissor.xform.ptr[5] = y+h*0.5f;
  nvgTransformMultiply(state.scissor.xform.ptr, state.xform.ptr);

  state.scissor.extent[0] = w*0.5f;
  state.scissor.extent[1] = h*0.5f;
}

void nvg__isectRects (float* dst, float ax, float ay, float aw, float ah, float bx, float by, float bw, float bh) {
  float minx = nvg__maxf(ax, bx);
  float miny = nvg__maxf(ay, by);
  float maxx = nvg__minf(ax+aw, bx+bw);
  float maxy = nvg__minf(ay+ah, by+bh);
  dst[0] = minx;
  dst[1] = miny;
  dst[2] = nvg__maxf(0.0f, maxx-minx);
  dst[3] = nvg__maxf(0.0f, maxy-miny);
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

  float[6] pxform, invxorm;
  float[4] rect;
  float ex, ey, tex, tey;

  // Transform the current scissor rect into current transform space.
  // If there is difference in rotation, this will be approximation.
  memcpy(pxform.ptr, state.scissor.xform.ptr, float.sizeof*6);
  ex = state.scissor.extent[0];
  ey = state.scissor.extent[1];
  nvgTransformInverse(invxorm.ptr, state.xform.ptr);
  nvgTransformMultiply(pxform.ptr, invxorm.ptr);
  tex = ex*nvg__absf(pxform[0])+ey*nvg__absf(pxform[2]);
  tey = ex*nvg__absf(pxform[1])+ey*nvg__absf(pxform[3]);

  // Intersect rects.
  nvg__isectRects(rect.ptr, pxform[4]-tex, pxform[5]-tey, tex*2, tey*2, x, y, w, h);

  ctx.scissor(rect[0], rect[1], rect[2], rect[3]);
}

/// Reset and disables scissoring.
public void resetScissor (NVGContext ctx) {
  NVGstate* state = nvg__getState(ctx);
  memset(state.scissor.xform.ptr, 0, (state.scissor.xform.ptr).sizeof);
  state.scissor.extent[0] = -1.0f;
  state.scissor.extent[1] = -1.0f;
}

int nvg__ptEquals (float x1, float y1, float x2, float y2, float tol) {
  float dx = x2-x1;
  float dy = y2-y1;
  return dx*dx+dy*dy < tol*tol;
}

float nvg__distPtSeg (float x, float y, float px, float py, float qx, float qy) {
  float pqx, pqy, dx, dy, d, t;
  pqx = qx-px;
  pqy = qy-py;
  dx = x-px;
  dy = y-py;
  d = pqx*pqx+pqy*pqy;
  t = pqx*dx+pqy*dy;
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
      nvgTransformPoint(&vals[i+1], &vals[i+2], state.xform.ptr, vals[i+1], vals[i+2]);
      i += 3;
      break;
    case NVGcommands.LineTo:
      nvgTransformPoint(&vals[i+1], &vals[i+2], state.xform.ptr, vals[i+1], vals[i+2]);
      i += 3;
      break;
    case NVGcommands.BezierTo:
      nvgTransformPoint(&vals[i+1], &vals[i+2], state.xform.ptr, vals[i+1], vals[i+2]);
      nvgTransformPoint(&vals[i+3], &vals[i+4], state.xform.ptr, vals[i+3], vals[i+4]);
      nvgTransformPoint(&vals[i+5], &vals[i+6], state.xform.ptr, vals[i+5], vals[i+6]);
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

float nvg__getAverageScale (float* t) {
  float sx = nvg__sqrtf(t[0]*t[0]+t[2]*t[2]);
  float sy = nvg__sqrtf(t[1]*t[1]+t[3]*t[3]);
  return (sx+sy)*0.5f;
}

NVGvertex* nvg__allocTempVerts (NVGContext ctx, int nverts) {
  if (nverts > ctx.cache.cverts) {
    NVGvertex* verts;
    int cverts = (nverts+0xff)&~0xff; // Round up to prevent allocations when things change just slightly.
    verts = cast(NVGvertex*)realloc(ctx.cache.verts, (NVGvertex).sizeof*cverts);
    if (verts is null) return null;
    ctx.cache.verts = verts;
    ctx.cache.cverts = cverts;
  }

  return ctx.cache.verts;
}

float nvg__triarea2 (float ax, float ay, float bx, float by, float cx, float cy) {
  float abx = bx-ax;
  float aby = by-ay;
  float acx = cx-ax;
  float acy = cy-ay;
  return acx*aby-abx*acy;
}

float nvg__polyArea (NVGpoint* pts, int npts) {
  int i;
  float area = 0;
  for (i = 2; i < npts; i++) {
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

void nvg__tesselateBezier (NVGContext ctx, float x1, float y1, float x2, float y2, float x3, float y3, float x4, float y4, int level, int type) {
  float x12, y12, x23, y23, x34, y34, x123, y123, x234, y234, x1234, y1234;
  float dx, dy, d2, d3;

  if (level > 10) return;

  x12 = (x1+x2)*0.5f;
  y12 = (y1+y2)*0.5f;
  x23 = (x2+x3)*0.5f;
  y23 = (y2+y3)*0.5f;
  x34 = (x3+x4)*0.5f;
  y34 = (y3+y4)*0.5f;
  x123 = (x12+x23)*0.5f;
  y123 = (y12+y23)*0.5f;

  dx = x4-x1;
  dy = y4-y1;
  d2 = nvg__absf(((x2-x4)*dy-(y2-y4)*dx));
  d3 = nvg__absf(((x3-x4)*dy-(y3-y4)*dx));

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

  x234 = (x23+x34)*0.5f;
  y234 = (y23+y34)*0.5f;
  x1234 = (x123+x234)*0.5f;
  y1234 = (y123+y234)*0.5f;

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
  int i, j;
  float* cp1;
  float* cp2;
  float* p;
  float area;

  if (cache.npaths > 0) return;

  // Flatten
  i = 0;
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

  cache.bounds[0] = cache.bounds[1] = 1e6f;
  cache.bounds[2] = cache.bounds[3] = -1e6f;

  // Calculate the direction and length of line segments.
  for (j = 0; j < cache.npaths; ++j) {
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
      area = nvg__polyArea(pts, path.count);
      if (path.winding == NVGWinding.CCW && area < 0.0f)
        nvg__polyReverse(pts, path.count);
      if (path.winding == NVGWinding.CW && area > 0.0f)
        nvg__polyReverse(pts, path.count);
    }

    for (i = 0; i < path.count; ++i) {
      // Calculate segment direction and length
      p0.dx = p1.x-p0.x;
      p0.dy = p1.y-p0.y;
      p0.len = nvg__normalize(&p0.dx, &p0.dy);
      // Update bounds
      cache.bounds[0] = nvg__minf(cache.bounds[0], p0.x);
      cache.bounds[1] = nvg__minf(cache.bounds[1], p0.y);
      cache.bounds[2] = nvg__maxf(cache.bounds[2], p0.x);
      cache.bounds[3] = nvg__maxf(cache.bounds[3], p0.y);
      // Advance
      p0 = p1++;
    }
  }
}

int nvg__curveDivs (float r, float arc, float tol) {
  float da = nvg__acosf(r/(r+tol))*2.0f;
  return nvg__maxi(2, cast(int)nvg__ceilf(arc/da));
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
    float lx0, ly0, lx1, ly1, a0, a1;
    nvg__chooseBevel(p1.flags&NVGpointFlags.InnerBevelPR, p0, p1, lw, &lx0, &ly0, &lx1, &ly1);
    a0 = nvg__atan2f(-dly0, -dlx0);
    a1 = nvg__atan2f(-dly1, -dlx1);
    if (a1 > a0) a1 -= NVG_PI*2;

    nvg__vset(dst, lx0, ly0, lu, 1); dst++;
    nvg__vset(dst, p1.x-dlx0*rw, p1.y-dly0*rw, ru, 1); dst++;

    n = nvg__clampi(cast(int)nvg__ceilf(((a0-a1)/NVG_PI)*ncap), 2, ncap);
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
    float rx0, ry0, rx1, ry1, a0, a1;
    nvg__chooseBevel(p1.flags&NVGpointFlags.InnerBevelPR, p0, p1, -rw, &rx0, &ry0, &rx1, &ry1);
    a0 = nvg__atan2f(dly0, dlx0);
    a1 = nvg__atan2f(dly1, dlx1);
    if (a1 < a0) a1 += NVG_PI*2;

    nvg__vset(dst, p1.x+dlx0*rw, p1.y+dly0*rw, lu, 1); dst++;
    nvg__vset(dst, rx0, ry0, ru, 1); dst++;

    n = nvg__clampi(cast(int)nvg__ceilf(((a1-a0)/NVG_PI)*ncap), 2, ncap);
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
  float px = p.x-dx*d;
  float py = p.y-dy*d;
  float dlx = dy;
  float dly = -dx;
  nvg__vset(dst, px+dlx*w-dx*aa, py+dly*w-dy*aa, 0, 0); dst++;
  nvg__vset(dst, px-dlx*w-dx*aa, py-dly*w-dy*aa, 1, 0); dst++;
  nvg__vset(dst, px+dlx*w, py+dly*w, 0, 1); dst++;
  nvg__vset(dst, px-dlx*w, py-dly*w, 1, 1); dst++;
  return dst;
}

NVGvertex* nvg__buttCapEnd (NVGvertex* dst, NVGpoint* p, float dx, float dy, float w, float d, float aa) {
  float px = p.x+dx*d;
  float py = p.y+dy*d;
  float dlx = dy;
  float dly = -dx;
  nvg__vset(dst, px+dlx*w, py+dly*w, 0, 1); dst++;
  nvg__vset(dst, px-dlx*w, py-dly*w, 1, 1); dst++;
  nvg__vset(dst, px+dlx*w+dx*aa, py+dly*w+dy*aa, 0, 0); dst++;
  nvg__vset(dst, px-dlx*w+dx*aa, py-dly*w+dy*aa, 1, 0); dst++;
  return dst;
}


NVGvertex* nvg__roundCapStart (NVGvertex* dst, NVGpoint* p, float dx, float dy, float w, int ncap, float aa) {
  int i;
  float px = p.x;
  float py = p.y;
  float dlx = dy;
  float dly = -dx;
  //NVG_NOTUSED(aa);
  for (i = 0; i < ncap; i++) {
    float a = i/cast(float)(ncap-1)*NVG_PI;
    float ax = nvg__cosf(a)*w, ay = nvg__sinf(a)*w;
    nvg__vset(dst, px-dlx*ax-dx*ay, py-dly*ax-dy*ay, 0, 1); dst++;
    nvg__vset(dst, px, py, 0.5f, 1); dst++;
  }
  nvg__vset(dst, px+dlx*w, py+dly*w, 0, 1); dst++;
  nvg__vset(dst, px-dlx*w, py-dly*w, 1, 1); dst++;
  return dst;
}

NVGvertex* nvg__roundCapEnd (NVGvertex* dst, NVGpoint* p, float dx, float dy, float w, int ncap, float aa) {
  int i;
  float px = p.x;
  float py = p.y;
  float dlx = dy;
  float dly = -dx;
  //NVG_NOTUSED(aa);
  nvg__vset(dst, px+dlx*w, py+dly*w, 0, 1); dst++;
  nvg__vset(dst, px-dlx*w, py-dly*w, 1, 1); dst++;
  for (i = 0; i < ncap; i++) {
    float a = i/cast(float)(ncap-1)*NVG_PI;
    float ax = nvg__cosf(a)*w, ay = nvg__sinf(a)*w;
    nvg__vset(dst, px, py, 0.5f, 1); dst++;
    nvg__vset(dst, px-dlx*ax+dx*ay, py-dly*ax+dy*ay, 0, 1); dst++;
  }
  return dst;
}


void nvg__calculateJoins (NVGContext ctx, float w, int lineJoin, float miterLimit) {
  NVGpathCache* cache = ctx.cache;
  int i, j;
  float iw = 0.0f;

  if (w > 0.0f) iw = 1.0f/w;

  // Calculate which joins needs extra vertices to append, and gather vertex count.
  for (i = 0; i < cache.npaths; i++) {
    NVGpath* path = &cache.paths[i];
    NVGpoint* pts = &cache.points[path.first];
    NVGpoint* p0 = &pts[path.count-1];
    NVGpoint* p1 = &pts[0];
    int nleft = 0;

    path.nbevel = 0;

    for (j = 0; j < path.count; j++) {
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
      limit = nvg__maxf(1.01f, nvg__minf(p0.len, p1.len)*iw);
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
  int cverts, i, j;
  float aa = ctx.fringeWidth;
  int ncap = nvg__curveDivs(w, NVG_PI, ctx.tessTol); // Calculate divisions per half circle.

  nvg__calculateJoins(ctx, w, lineJoin, miterLimit);

  // Calculate max vertex usage.
  cverts = 0;
  for (i = 0; i < cache.npaths; i++) {
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

  for (i = 0; i < cache.npaths; i++) {
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

    for (j = s; j < e; ++j) {
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
  int cverts, convex, i, j;
  float aa = ctx.fringeWidth;
  int fringe = w > 0.0f;

  nvg__calculateJoins(ctx, w, lineJoin, miterLimit);

  // Calculate max vertex usage.
  cverts = 0;
  for (i = 0; i < cache.npaths; i++) {
    NVGpath* path = &cache.paths[i];
    cverts += path.count+path.nbevel+1;
    if (fringe)
      cverts += (path.count+path.nbevel*5+1)*2; // plus one for loop
  }

  verts = nvg__allocTempVerts(ctx, cverts);
  if (verts is null) return 0;

  convex = cache.npaths == 1 && cache.paths[0].convex;

  for (i = 0; i < cache.npaths; i++) {
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
      for (j = 0; j < path.count; ++j) {
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
      for (j = 0; j < path.count; ++j) {
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

      for (j = 0; j < path.count; ++j) {
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
  float a = 0, da = 0, hda = 0, kappa = 0;
  float dx = 0, dy = 0, x = 0, y = 0, tanx = 0, tany = 0;
  float px = 0, py = 0, ptanx = 0, ptany = 0;
  float[3+5*7+100] vals = void;
  int i, ndivs, nvals;
  int move = ctx.ncommands > 0 ? NVGcommands.LineTo : NVGcommands.MoveTo;

  // Clamp angles
  da = a1-a0;
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
  ndivs = nvg__maxi(1, nvg__mini(cast(int)(nvg__absf(da)/(NVG_PI*0.5f)+0.5f), 5));
  hda = (da/cast(float)ndivs)/2.0f;
  kappa = nvg__absf(4.0f/3.0f*(1.0f-nvg__cosf(hda))/nvg__sinf(hda));

  if (dir == NVGWinding.CCW) kappa = -kappa;

  nvals = 0;
  for (i = 0; i <= ndivs; i++) {
    a = a0+da*(i/cast(float)ndivs);
    dx = nvg__cosf(a);
    dy = nvg__sinf(a);
    x = cx+dx*r;
    y = cy+dy*r;
    tanx = -dy*r*kappa;
    tany = dx*r*kappa;

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
    return;
  } else {
    float rx = nvg__minf(r, nvg__absf(w)*0.5f)*nvg__signf(w), ry = nvg__minf(r, nvg__absf(h)*0.5f)*nvg__signf(h);
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
  float scale = nvg__getAverageScale(state.xform.ptr);
  float strokeWidth = nvg__clampf(state.strokeWidth*scale, 0.0f, 200.0f);
  NVGPaint strokePaint = state.stroke;
  const(NVGpath)* path;

  if (strokeWidth < ctx.fringeWidth) {
    // If the stroke width is less than pixel size, use alpha to emulate coverage.
    // Since coverage is area, scale by alpha*alpha.
    float alpha = nvg__clampf(strokeWidth/ctx.fringeWidth, 0.0f, 1.0f);
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
  if (name is null) return -1;
  return fonsGetFontByName(ctx.fs, name);
}

/// Sets the font size of current text style.
public void fontSize (NVGContext ctx, float size) {
  NVGstate* state = nvg__getState(ctx);
  state.fontSize = size;
}

/// Sets the blur of current text style.
public void fontBlur (NVGContext ctx, float blur) {
  NVGstate* state = nvg__getState(ctx);
  state.fontBlur = blur;
}

/// Sets the letter spacing of current text style.
public void textLetterSpacing (NVGContext ctx, float spacing) {
  NVGstate* state = nvg__getState(ctx);
  state.letterSpacing = spacing;
}

/// Sets the proportional line height of current text style. The line height is specified as multiple of font size.
public void textLineHeight (NVGContext ctx, float lineHeight) {
  NVGstate* state = nvg__getState(ctx);
  state.lineHeight = lineHeight;
}

/// Sets the text align of current text style, see NVGAlign for options.
public void textAlign (NVGContext ctx, int align_) {
  NVGstate* state = nvg__getState(ctx);
  state.textAlign = align_;
}

/// Sets the font face based on specified id of current text style.
public void fontFaceId (NVGContext ctx, int font) {
  NVGstate* state = nvg__getState(ctx);
  state.fontId = font;
}

/// Sets the font face based on specified name of current text style.
public void fontFace (NVGContext ctx, const(char)[] font) {
  NVGstate* state = nvg__getState(ctx);
  state.fontId = fonsGetFontByName(ctx.fs, font);
}

float nvg__quantize (float a, float d) {
  pragma(inline, true);
  return (cast(int)(a/d+0.5f))*d;
}

float nvg__getFontScale (NVGstate* state) {
  pragma(inline, true);
  return nvg__minf(nvg__quantize(nvg__getAverageScale(state.xform.ptr), 0.01f), 4.0f);
}

void nvg__flushTextTexture (NVGContext ctx) {
  int[4] dirty;
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

int nvg__allocTextAtlas (NVGContext ctx) {
  int iw, ih;
  nvg__flushTextTexture(ctx);
  if (ctx.fontImageIdx >= NVG_MAX_FONTIMAGES-1) return 0;
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
  return 1;
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

/// Draws text string at specified location. If end is specified only the sub-string up to the end is drawn.
public float text (NVGContext ctx, float x, float y, const(char)[] str) { return (str.length ? ctx.text(x, y, str.ptr, str.ptr+str.length) : x); }

/// Ditto.
public float text (NVGContext ctx, float x, float y, const(char)* str, const(char)* end) {
  NVGstate* state = nvg__getState(ctx);
  FONStextIter iter, prevIter;
  FONSquad q;
  NVGvertex* verts;
  float scale = nvg__getFontScale(state)*ctx.devicePxRatio;
  float invscale = 1.0f/scale;
  int cverts = 0;
  int nverts = 0;

  if (end is null) end = str+strlen(str);

  if (state.fontId == FONS_INVALID) return x;

  fonsSetSize(ctx.fs, state.fontSize*scale);
  fonsSetSpacing(ctx.fs, state.letterSpacing*scale);
  fonsSetBlur(ctx.fs, state.fontBlur*scale);
  fonsSetAlign(ctx.fs, state.textAlign);
  fonsSetFont(ctx.fs, state.fontId);

  cverts = nvg__maxi(2, cast(int)(end-str))*6; // conservative estimate.
  verts = nvg__allocTempVerts(ctx, cverts);
  if (verts is null) return x;

  fonsTextIterInit(ctx.fs, &iter, x*scale, y*scale, str, end);
  prevIter = iter;
  while (fonsTextIterNext(ctx.fs, &iter, &q)) {
    float[4*2] c = void;
    if (iter.prevGlyphIndex == -1) { // can not retrieve glyph?
      if (!nvg__allocTextAtlas(ctx)) break; // no memory :(
      if (nverts != 0) {
        nvg__renderText(ctx, verts, nverts);
        nverts = 0;
      }
      iter = prevIter;
      fonsTextIterNext(ctx.fs, &iter, &q); // try again
      if (iter.prevGlyphIndex == -1) break; // still can not find glyph?
    }
    prevIter = iter;
    // Transform corners.
    nvgTransformPoint(&c[0], &c[1], state.xform.ptr, q.x0*invscale, q.y0*invscale);
    nvgTransformPoint(&c[2], &c[3], state.xform.ptr, q.x1*invscale, q.y0*invscale);
    nvgTransformPoint(&c[4], &c[5], state.xform.ptr, q.x1*invscale, q.y1*invscale);
    nvgTransformPoint(&c[6], &c[7], state.xform.ptr, q.x0*invscale, q.y1*invscale);
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

  // TODO: add back-end bit to do this just once per frame.
  nvg__flushTextTexture(ctx);

  nvg__renderText(ctx, verts, nverts);

  return iter.x;
}

/** Draws multi-line text string at specified location wrapped at the specified width. If end is specified only the sub-string up to the end is drawn.
 * White space is stripped at the beginning of the rows, the text is split at word boundaries or when new-line characters are encountered.
 * Words longer than the max width are slit at nearest character (i.e. no hyphenation).
 */
public void textBox (NVGContext ctx, float x, float y, float breakRowWidth, const(char)[] str) { if (str.length) ctx.textBox(x, y, breakRowWidth, str.ptr, str.ptr+str.length); }

/// Ditto.
public void textBox (NVGContext ctx, float x, float y, float breakRowWidth, const(char)* str, const(char)* end) {
  NVGstate* state = nvg__getState(ctx);
  NVGTextRow[2] rows = void;
  int nrows = 0, i;
  int oldAlign = state.textAlign;
  int haling = state.textAlign&(NVGAlign.Left|NVGAlign.Center|NVGAlign.Right);
  int valign = state.textAlign&(NVGAlign.Top|NVGAlign.Middle|NVGAlign.Bottom|NVGAlign.Baseline);
  float lineh = 0;

  if (state.fontId == FONS_INVALID) return;

  ctx.textMetrics(null, null, &lineh);

  state.textAlign = NVGAlign.Left|valign;

  while ((nrows = ctx.textBreakLines(str, end, breakRowWidth, rows.ptr, 2)) != 0) {
    for (i = 0; i < nrows; i++) {
      NVGTextRow* row = &rows[i];
      if (haling&NVGAlign.Left)
        ctx.text(x, y, row.start, row.end);
      else if (haling&NVGAlign.Center)
        ctx.text(x+breakRowWidth*0.5f-row.width*0.5f, y, row.start, row.end);
      else if (haling&NVGAlign.Right)
        ctx.text(x+breakRowWidth-row.width, y, row.start, row.end);
      y += lineh*state.lineHeight;
    }
    str = rows[nrows-1].next;
  }

  state.textAlign = oldAlign;
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
public int textGlyphPositions (NVGContext ctx, float x, float y, const(char)[] str, NVGGlyphPosition[] positions) {
  if (str.length == 0 || positions.length == 0) return 0;
  size_t posnum;
  return ctx.textGlyphPositions(x, y, str.ptr, str.ptr+str.length, (in ref NVGGlyphPosition pos) {
    positions.ptr[posnum++] = pos;
    return (posnum < positions.length);
  });
}

/// Ditto.
public int textGlyphPositions(DG) (NVGContext ctx, float x, float y, const(char)[] str, scope DG dg) if (isGoodPositionDelegate!DG) {
  if (str.length == 0) return 0;
  return ctx.textGlyphPositions(x, y, str.ptr, str.ptr+str.length, dg);
}

/// Ditto.
public int textGlyphPositions (NVGContext ctx, float x, float y, const(char)* str, const(char)* end, NVGGlyphPosition* positions, int maxPositions) {
  if (maxPositions < 1 || str is null) return 0;
  size_t posnum;
  return ctx.textGlyphPositions(x, y, str, end, (in ref NVGGlyphPosition pos) {
    positions[posnum++] = pos;
    return (posnum < maxPositions);
  });
}

/// Ditto.
public int textGlyphPositions(DG) (NVGContext ctx, float x, float y, const(char)* str, const(char)* end, scope DG dg) if (isGoodPositionDelegate!DG) {
  import std.traits : ReturnType;
  static if (is(ReturnType!dg == void)) enum RetBool = false; else enum RetBool = true;

  NVGstate* state = nvg__getState(ctx);
  float scale = nvg__getFontScale(state)*ctx.devicePxRatio;
  float invscale = 1.0f/scale;
  FONStextIter iter, prevIter;
  FONSquad q;
  int npos = 0;

  if (state.fontId == FONS_INVALID) return 0;

  if (end is null) end = str+strlen(str);

  if (str == end) return 0;

  fonsSetSize(ctx.fs, state.fontSize*scale);
  fonsSetSpacing(ctx.fs, state.letterSpacing*scale);
  fonsSetBlur(ctx.fs, state.fontBlur*scale);
  fonsSetAlign(ctx.fs, state.textAlign);
  fonsSetFont(ctx.fs, state.fontId);

  fonsTextIterInit(ctx.fs, &iter, x*scale, y*scale, str, end);
  prevIter = iter;
  while (fonsTextIterNext(ctx.fs, &iter, &q)) {
    if (iter.prevGlyphIndex < 0 && nvg__allocTextAtlas(ctx)) { // can not retrieve glyph?
      iter = prevIter;
      fonsTextIterNext(ctx.fs, &iter, &q); // try again
    }
    prevIter = iter;
    NVGGlyphPosition position = void; //WARNING!
    position.str = iter.str;
    position.x = iter.x*invscale;
    position.minx = nvg__minf(iter.x, q.x0)*invscale;
    position.maxx = nvg__maxf(iter.nextx, q.x1)*invscale;
    ++npos;
    static if (RetBool) { if (!dg(position)) return npos; } else dg(position);
  }

  return npos;
}

/** Breaks the specified text into lines. If end is specified only the sub-string will be used.
 * White space is stripped at the beginning of the rows, the text is split at word boundaries or when new-line characters are encountered.
 * Words longer than the max width are slit at nearest character (i.e. no hyphenation).
 */
public int textBreakLines (NVGContext ctx, const(char)[] str, float breakRowWidth, NVGTextRow* rows, int maxRows) {
  if (str.length == 0) str = "";
  return ctx.textBreakLines(str.ptr, str.ptr+str.length, breakRowWidth, rows, maxRows);
}

private template isGoodRowDelegate(DG) {
  private DG dg;
  static if (is(typeof({ NVGTextRow row; bool res = dg(row); })) ||
             is(typeof({ NVGTextRow row; dg(row); })))
    enum isGoodRowDelegate = true;
  else
    enum isGoodRowDelegate = false;
}

/// Ditto.
public int textBreakLines(DG) (NVGContext ctx, const(char)[] str, float breakRowWidth, scope DG dg) if (isGoodRowDelegate!DG) {
  if (str.length == 0) str = "";
  return ctx.textBreakLines(str.ptr, str.ptr+str.length, breakRowWidth, dg);
}

/// Ditto.
public int textBreakLines (NVGContext ctx, const(char)* str, const(char)* end, float breakRowWidth, NVGTextRow* rows, int maxRows) {
  if (maxRows <= 0) return 0;
  int nrow = 0;
  return ctx.textBreakLines(str, end, breakRowWidth, (in ref NVGTextRow row) {
    rows[nrow++] = row;
    return (nrow < maxRows);
  });
}

/// Ditto.
public int textBreakLines(DG) (NVGContext ctx, const(char)* str, const(char)* end, float breakRowWidth, scope DG dg) if (isGoodRowDelegate!DG) {
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
  const(char)* rowStart = null;
  const(char)* rowEnd = null;
  const(char)* wordStart = null;
  float wordStartX = 0;
  float wordMinX = 0;
  const(char)* breakEnd = null;
  float breakWidth = 0;
  float breakMaxX = 0;
  int type = NVGcodepointType.Space, ptype = NVGcodepointType.Space;
  uint pcodepoint = 0;

  if (state.fontId == FONS_INVALID) return 0;
  if (str is null || dg is null) return 0;

  if (end is null) end = str+strlen(str);

  if (str is end) return 0;

  fonsSetSize(ctx.fs, state.fontSize*scale);
  fonsSetSpacing(ctx.fs, state.letterSpacing*scale);
  fonsSetBlur(ctx.fs, state.fontBlur*scale);
  fonsSetAlign(ctx.fs, state.textAlign);
  fonsSetFont(ctx.fs, state.fontId);

  breakRowWidth *= scale;

  fonsTextIterInit(ctx.fs, &iter, 0, 0, str, end);
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
        type = pcodepoint == 13 ? NVGcodepointType.Space : NVGcodepointType.NewLine;
        break;
      case 13: // \r
        type = pcodepoint == 10 ? NVGcodepointType.Space : NVGcodepointType.NewLine;
        break;
      case 0x0085: // NEL
        type = NVGcodepointType.NewLine;
        break;
      default:
        type = NVGcodepointType.Char;
        break;
    }

    if (type == NVGcodepointType.NewLine) {
      // Always handle new lines.
      NVGTextRow row = void; //WARNING!
      row.start = (rowStart !is null ? rowStart : iter.str);
      row.end = (rowEnd !is null ? rowEnd : iter.str);
      row.width = rowWidth*invscale;
      row.minx = rowMinX*invscale;
      row.maxx = rowMaxX*invscale;
      row.next = iter.next;
      ++nrows;
      static if (RetBool) { if (!dg(row)) return nrows; } else dg(row);
      // Set null break point
      breakEnd = rowStart;
      breakWidth = 0.0;
      breakMaxX = 0.0;
      // Indicate to skip the white space at the beginning of the row.
      rowStart = null;
      rowEnd = null;
      rowWidth = 0;
      rowMinX = rowMaxX = 0;
    } else {
      if (rowStart is null) {
        // Skip white space until the beginning of the line
        if (type == NVGcodepointType.Char) {
          // The current char is the row so far
          rowStartX = iter.x;
          rowStart = iter.str;
          rowEnd = iter.next;
          rowWidth = iter.nextx-rowStartX; // q.x1-rowStartX;
          rowMinX = q.x0-rowStartX;
          rowMaxX = q.x1-rowStartX;
          wordStart = iter.str;
          wordStartX = iter.x;
          wordMinX = q.x0-rowStartX;
          // Set null break point
          breakEnd = rowStart;
          breakWidth = 0.0;
          breakMaxX = 0.0;
        }
      } else {
        float nextWidth = iter.nextx-rowStartX;

        // track last non-white space character
        if (type == NVGcodepointType.Char) {
          rowEnd = iter.next;
          rowWidth = iter.nextx-rowStartX;
          rowMaxX = q.x1-rowStartX;
        }
        // track last end of a word
        if (ptype == NVGcodepointType.Char && type == NVGcodepointType.Space) {
          breakEnd = iter.str;
          breakWidth = rowWidth;
          breakMaxX = rowMaxX;
        }
        // track last beginning of a word
        if (ptype == NVGcodepointType.Space && type == NVGcodepointType.Char) {
          wordStart = iter.str;
          wordStartX = iter.x;
          wordMinX = q.x0-rowStartX;
        }

        // Break to new line when a character is beyond break width.
        if (type == NVGcodepointType.Char && nextWidth > breakRowWidth) {
          // The run length is too long, need to break to new line.
          NVGTextRow row = void; //WARNING!
          if (breakEnd == rowStart) {
            // The current word is longer than the row length, just break it from here.
            row.start = rowStart;
            row.end = iter.str;
            row.width = rowWidth*invscale;
            row.minx = rowMinX*invscale;
            row.maxx = rowMaxX*invscale;
            row.next = iter.str;
            ++nrows;
            static if (RetBool) { if (!dg(row)) return nrows; } else dg(row);
            rowStartX = iter.x;
            rowStart = iter.str;
            rowEnd = iter.next;
            rowWidth = iter.nextx-rowStartX;
            rowMinX = q.x0-rowStartX;
            rowMaxX = q.x1-rowStartX;
            wordStart = iter.str;
            wordStartX = iter.x;
            wordMinX = q.x0-rowStartX;
          } else {
            // Break the line from the end of the last word, and start new line from the beginning of the new.
            row.start = rowStart;
            row.end = breakEnd;
            row.width = breakWidth*invscale;
            row.minx = rowMinX*invscale;
            row.maxx = breakMaxX*invscale;
            row.next = wordStart;
            ++nrows;
            static if (RetBool) { if (!dg(row)) return nrows; } else dg(row);
            rowStartX = wordStartX;
            rowStart = wordStart;
            rowEnd = iter.next;
            rowWidth = iter.nextx-rowStartX;
            rowMinX = wordMinX;
            rowMaxX = q.x1-rowStartX;
            // No change to the word start
          }
          // Set null break point
          breakEnd = rowStart;
          breakWidth = 0.0;
          breakMaxX = 0.0;
        }
      }
    }

    pcodepoint = iter.codepoint;
    ptype = type;
  }

  // Break the line from the end of the last word, and start new line from the beginning of the new.
  if (rowStart !is null) {
    NVGTextRow row = void; //WARNING!
    row.start = rowStart;
    row.end = rowEnd;
    row.width = rowWidth*invscale;
    row.minx = rowMinX*invscale;
    row.maxx = rowMaxX*invscale;
    row.next = end;
    ++nrows;
    static if (RetBool) { if (!dg(row)) return nrows; } else dg(row);
  }

  return nrows;
}

/** Measures the specified text string. Parameter bounds should be a pointer to float[4],
 * if the bounding box of the text should be returned. The bounds value are [xmin, ymin, xmax, ymax]
 * Returns the horizontal advance of the measured text (i.e. where the next character should drawn).
 * Measured values are returned in local coordinate space.
 */
public float textBounds (NVGContext ctx, float x, float y, const(char)[] str, float[] bounds) {
  if (str.length == 0) str = "";
  float[4] bnd = void;
  auto res = ctx.textBounds(x, y, str.ptr, str.ptr+str.length, bnd.ptr);
  for (int i = 0; i < 4; ++i) {
    if (i >= bounds.length) break;
    bounds.ptr[i] = bnd[i];
  }
  return res;
}

/// Ditto.
public float textBounds (NVGContext ctx, float x, float y, const(char)* str, const(char)* end, float* bounds) {
  NVGstate* state = nvg__getState(ctx);
  float scale = nvg__getFontScale(state)*ctx.devicePxRatio;
  float invscale = 1.0f/scale;
  float width;

  if (state.fontId == FONS_INVALID) return 0;

  fonsSetSize(ctx.fs, state.fontSize*scale);
  fonsSetSpacing(ctx.fs, state.letterSpacing*scale);
  fonsSetBlur(ctx.fs, state.fontBlur*scale);
  fonsSetAlign(ctx.fs, state.textAlign);
  fonsSetFont(ctx.fs, state.fontId);

  width = fonsTextBounds(ctx.fs, x*scale, y*scale, str, end, bounds);
  if (bounds !is null) {
    // Use line bounds for height.
    fonsLineBounds(ctx.fs, y*scale, &bounds[1], &bounds[3]);
    bounds[0] *= invscale;
    bounds[1] *= invscale;
    bounds[2] *= invscale;
    bounds[3] *= invscale;
  }
  return width*invscale;
}

/// Ditto.
public void textBoxBounds (NVGContext ctx, float x, float y, float breakRowWidth, const(char)[] str, float[] bounds) {
  if (bounds.length == 0) return;
  if (str.length == 0) str = "";
  float[4] bnd = void;
  ctx.textBoxBounds(x, y, breakRowWidth, str.ptr, str.ptr+str.length, bnd.ptr);
  for (int i = 0; i < 4; ++i) {
    if (i >= bounds.length) break;
    bounds.ptr[i] = bnd[i];
  }
}

/// Ditto.
public void textBoxBounds (NVGContext ctx, float x, float y, float breakRowWidth, const(char)* str, const(char)* end, float* bounds) {
  NVGstate* state = nvg__getState(ctx);
  NVGTextRow[2] rows;
  float scale = nvg__getFontScale(state)*ctx.devicePxRatio;
  float invscale = 1.0f/scale;
  int nrows = 0;
  int oldAlign = state.textAlign;
  int haling = state.textAlign&(NVGAlign.Left|NVGAlign.Center|NVGAlign.Right);
  int valign = state.textAlign&(NVGAlign.Top|NVGAlign.Middle|NVGAlign.Bottom|NVGAlign.Baseline);
  float lineh = 0, rminy = 0, rmaxy = 0;
  float minx, miny, maxx, maxy;

  if (state.fontId == FONS_INVALID) {
    if (bounds !is null) bounds[0] = bounds[1] = bounds[2] = bounds[3] = 0.0f;
    return;
  }

  ctx.textMetrics(null, null, &lineh);

  state.textAlign = NVGAlign.Left|valign;

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

  while ((nrows = ctx.textBreakLines(str, end, breakRowWidth, rows.ptr, 2)) != 0) {
    foreach (int i; 0..nrows) {
      NVGTextRow* row = &rows[i];
      float rminx, rmaxx, dx = 0;
      // Horizontal bounds
           if (haling&NVGAlign.Left) dx = 0;
      else if (haling&NVGAlign.Center) dx = breakRowWidth*0.5f-row.width*0.5f;
      else if (haling&NVGAlign.Right) dx = breakRowWidth-row.width;
      rminx = x+row.minx+dx;
      rmaxx = x+row.maxx+dx;
      minx = nvg__minf(minx, rminx);
      maxx = nvg__maxf(maxx, rmaxx);
      // Vertical bounds.
      miny = nvg__minf(miny, y+rminy);
      maxy = nvg__maxf(maxy, y+rmaxy);

      y += lineh*state.lineHeight;
    }
    str = rows[nrows-1].next;
  }

  state.textAlign = oldAlign;

  if (bounds !is null) {
    bounds[0] = minx;
    bounds[1] = miny;
    bounds[2] = maxx;
    bounds[3] = maxy;
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
