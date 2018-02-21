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
/**
The NanoVega API is modeled loosely on HTML5 canvas API.
If you know canvas, you're up to speed with NanoVega in no time.


Creating drawing context
========================

The drawing context is created using platform specific constructor function.

  ---
  struct NVGContext vg = createGL2NVG(NVG_ANTIALIAS|NVG_STENCIL_STROKES);
  ---

The first parameter defines flags for creating the renderer.

- `NVG_ANTIALIAS` means that the renderer adjusts the geometry to include anti-aliasing.
   If you're using MSAA, you can omit this flags.

- `NVG_STENCIL_STROKES` means that the render uses better quality rendering for (overlapping) strokes.
  The quality is mostly visible on wider strokes. If you want speed, you can omit this flag.


Drawing shapes with NanoVega
============================

Drawing a simple shape using NanoVega consists of four steps: 1] begin a new shape,
2] define the path to draw, 3] set fill or stroke, 4] and finally fill or stroke the path.

  ---
  vg.beginPath();
  vg.rect(100, 100, 120, 30);
  vg.fillColor(nvgRGBA(255, 192, 0, 255));
  vg.fill();
  ---

Calling `beginPath()` will clear any existing paths and start drawing from blank slate.
There are number of number of functions to define the path to draw, such as rectangle,
rounded rectangle and ellipse, or you can use the common moveTo, lineTo, bezierTo and
arcTo API to compose the paths step by step.


Understanding Composite Paths
=============================

Because of the way the rendering backend is build in NanoVega, drawing a composite path,
that is path consisting from multiple paths defining holes and fills, is a bit more
involved. NanoVega uses non-zero filling rule and by default the paths are wound in counter
clockwise order. Keep that in mind when drawing using the low level draw API. In order to
wind one of the predefined shapes as a hole, you should call `pathWinding(NVGSolidity.Hole)`,
or `pathWinding(NVGSolidity.Solid)` *after* defining the path.

  ---
  vg.beginPath();
  vg.rect(100, 100, 120, 30);
  vg.circle(120, 120, 5);
  vg.pathWinding(NVGSolidity.Hole); // mark circle as a hole
  vg.fillColor(nvgRGBA(255, 192, 0, 255));
  vg.fill();
  ---


Rendering is wrong, what to do?
===============================

- make sure you have created NanoVega context using one of the `createGL2NVG()` call

- make sure you have initialised OpenGL with *stencil buffer*

- make sure you have cleared stencil buffer

- make sure all rendering calls happen between `beginFrame()` and `endFrame()`

- to enable more checks for OpenGL errors, add `NVG_DEBUG` flag to `createGL2NVG()`


OpenGL state touched by the backend
===================================

The OpenGL back-end touches following states:

When textures are uploaded or updated, the following pixel store is set to defaults:
`GL_UNPACK_ALIGNMENT`, `GL_UNPACK_ROW_LENGTH`, `GL_UNPACK_SKIP_PIXELS`, `GL_UNPACK_SKIP_ROWS`.
Texture binding is also affected. Texture updates can happen when the user loads images,
or when new font glyphs are added. Glyphs are added as needed between calls to `beginFrame()`
and `endFrame()`.

The data for the whole frame is buffered and flushed in `endFrame()`.
The following code illustrates the OpenGL state touched by the rendering code:

  ---
  glUseProgram(prog);
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
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
  glBindBuffer(GL_UNIFORM_BUFFER, buf);
  glBindVertexArray(arr);
  glBindBuffer(GL_ARRAY_BUFFER, buf);
  glBindTexture(GL_TEXTURE_2D, tex);
  glUniformBlockBinding(... , GLNVG_FRAG_BINDING);
  ---

 */
module iv.nanovega.nanovega is aliced;
private:

import iv.meta;
import iv.vfs;


// ////////////////////////////////////////////////////////////////////////// //
// engine
// ////////////////////////////////////////////////////////////////////////// //
import core.stdc.stdlib : malloc, realloc, free;
import core.stdc.string : memset, memcpy, strlen;
import std.math : PI;
//import iv.nanovega.fontstash;

version(nanovg_naked) {
  version = nanovg_disable_fontconfig;
} else {
  version = nanovg_use_freetype;
  version = nanovg_ft_mon;
  version = nanovg_demo_msfonts;
  version = nanovg_default_no_font_aa;
  version = nanovg_builtin_fontconfig_bindings;
  version = nanovg_builtin_opengl_bindings; // use `arsd.simpledisplay` to get basic bindings
}

version(Posix) {
  version(nanovg_disable_fontconfig) {
    public enum NVG_HAS_FONTCONFIG = false;
  } else {
    public enum NVG_HAS_FONTCONFIG = true;
    version(nanovg_builtin_fontconfig_bindings) {} else import iv.fontconfig;
  }
}


public:
alias NVG_PI = PI;

version = nanovg_use_arsd_image;

version(nanovg_use_arsd_image) {
  private import arsd.color;
  private import arsd.image;
} else {
  void stbi_set_unpremultiply_on_load (int flag_true_if_should_unpremultiply) {}
  void stbi_convert_iphone_png_to_rgb (int flag_true_if_should_convert) {}
  ubyte* stbi_load (const(char)* filename, int* x, int* y, int* comp, int req_comp) { return null; }
  ubyte* stbi_load_from_memory (const(void)* buffer, int len, int* x, int* y, int* comp, int req_comp) { return null; }
  void stbi_image_free (void* retval_from_stbi_load) {}
}

version(nanovg_default_no_font_aa) {
  __gshared bool NVG_INVERT_FONT_AA = false;
} else {
  __gshared bool NVG_INVERT_FONT_AA = true;
}


/// this is branchless for ints on x86, and even for longs on x86_64
public ubyte nvgClampToByte(T) (T n) pure nothrow @safe @nogc if (__traits(isIntegral, T)) {
  static if (__VERSION__ > 2067) pragma(inline, true);
  static if (T.sizeof == 2 || T.sizeof == 4) {
    static if (__traits(isUnsigned, T)) {
      return cast(ubyte)(n&0xff|(255-((-cast(int)(n < 256))>>24)));
    } else {
      n &= -cast(int)(n >= 0);
      return cast(ubyte)(n|((255-cast(int)n)>>31));
    }
  } else static if (T.sizeof == 1) {
    static assert(__traits(isUnsigned, T), "clampToByte: signed byte? no, really?");
    return cast(ubyte)n;
  } else static if (T.sizeof == 8) {
    static if (__traits(isUnsigned, T)) {
      return cast(ubyte)(n&0xff|(255-((-cast(long)(n < 256))>>56)));
    } else {
      n &= -cast(long)(n >= 0);
      return cast(ubyte)(n|((255-cast(long)n)>>63));
    }
  } else {
    static assert(false, "clampToByte: integer too big");
  }
}


/// NanoVega RGBA color
public align(1) struct NVGColor {
align(1):
public:
  float[4] rgba = 0; /// default color is transparent (a=1 is opaque)

public:
  @property string toString () const @safe { import std.string : format; return "NVGColor(%s,%s,%s,%s)".format(r, g, b, a); }

public:
  enum transparent = NVGColor(0.0f, 0.0f, 0.0f, 0.0f);
  enum k8orange = NVGColor(1.0f, 0.5f, 0.0f, 1.0f);

  enum aliceblue = NVGColor(240, 248, 255);
  enum antiquewhite = NVGColor(250, 235, 215);
  enum aqua = NVGColor(0, 255, 255);
  enum aquamarine = NVGColor(127, 255, 212);
  enum azure = NVGColor(240, 255, 255);
  enum beige = NVGColor(245, 245, 220);
  enum bisque = NVGColor(255, 228, 196);
  enum black = NVGColor(0, 0, 0); // basic color
  enum blanchedalmond = NVGColor(255, 235, 205);
  enum blue = NVGColor(0, 0, 255); // basic color
  enum blueviolet = NVGColor(138, 43, 226);
  enum brown = NVGColor(165, 42, 42);
  enum burlywood = NVGColor(222, 184, 135);
  enum cadetblue = NVGColor(95, 158, 160);
  enum chartreuse = NVGColor(127, 255, 0);
  enum chocolate = NVGColor(210, 105, 30);
  enum coral = NVGColor(255, 127, 80);
  enum cornflowerblue = NVGColor(100, 149, 237);
  enum cornsilk = NVGColor(255, 248, 220);
  enum crimson = NVGColor(220, 20, 60);
  enum cyan = NVGColor(0, 255, 255); // basic color
  enum darkblue = NVGColor(0, 0, 139);
  enum darkcyan = NVGColor(0, 139, 139);
  enum darkgoldenrod = NVGColor(184, 134, 11);
  enum darkgray = NVGColor(169, 169, 169);
  enum darkgreen = NVGColor(0, 100, 0);
  enum darkgrey = NVGColor(169, 169, 169);
  enum darkkhaki = NVGColor(189, 183, 107);
  enum darkmagenta = NVGColor(139, 0, 139);
  enum darkolivegreen = NVGColor(85, 107, 47);
  enum darkorange = NVGColor(255, 140, 0);
  enum darkorchid = NVGColor(153, 50, 204);
  enum darkred = NVGColor(139, 0, 0);
  enum darksalmon = NVGColor(233, 150, 122);
  enum darkseagreen = NVGColor(143, 188, 143);
  enum darkslateblue = NVGColor(72, 61, 139);
  enum darkslategray = NVGColor(47, 79, 79);
  enum darkslategrey = NVGColor(47, 79, 79);
  enum darkturquoise = NVGColor(0, 206, 209);
  enum darkviolet = NVGColor(148, 0, 211);
  enum deeppink = NVGColor(255, 20, 147);
  enum deepskyblue = NVGColor(0, 191, 255);
  enum dimgray = NVGColor(105, 105, 105);
  enum dimgrey = NVGColor(105, 105, 105);
  enum dodgerblue = NVGColor(30, 144, 255);
  enum firebrick = NVGColor(178, 34, 34);
  enum floralwhite = NVGColor(255, 250, 240);
  enum forestgreen = NVGColor(34, 139, 34);
  enum fuchsia = NVGColor(255, 0, 255);
  enum gainsboro = NVGColor(220, 220, 220);
  enum ghostwhite = NVGColor(248, 248, 255);
  enum gold = NVGColor(255, 215, 0);
  enum goldenrod = NVGColor(218, 165, 32);
  enum gray = NVGColor(128, 128, 128); // basic color
  enum green = NVGColor(0, 128, 0); // basic color
  enum greenyellow = NVGColor(173, 255, 47);
  enum grey = NVGColor(128, 128, 128); // basic color
  enum honeydew = NVGColor(240, 255, 240);
  enum hotpink = NVGColor(255, 105, 180);
  enum indianred = NVGColor(205, 92, 92);
  enum indigo = NVGColor(75, 0, 130);
  enum ivory = NVGColor(255, 255, 240);
  enum khaki = NVGColor(240, 230, 140);
  enum lavender = NVGColor(230, 230, 250);
  enum lavenderblush = NVGColor(255, 240, 245);
  enum lawngreen = NVGColor(124, 252, 0);
  enum lemonchiffon = NVGColor(255, 250, 205);
  enum lightblue = NVGColor(173, 216, 230);
  enum lightcoral = NVGColor(240, 128, 128);
  enum lightcyan = NVGColor(224, 255, 255);
  enum lightgoldenrodyellow = NVGColor(250, 250, 210);
  enum lightgray = NVGColor(211, 211, 211);
  enum lightgreen = NVGColor(144, 238, 144);
  enum lightgrey = NVGColor(211, 211, 211);
  enum lightpink = NVGColor(255, 182, 193);
  enum lightsalmon = NVGColor(255, 160, 122);
  enum lightseagreen = NVGColor(32, 178, 170);
  enum lightskyblue = NVGColor(135, 206, 250);
  enum lightslategray = NVGColor(119, 136, 153);
  enum lightslategrey = NVGColor(119, 136, 153);
  enum lightsteelblue = NVGColor(176, 196, 222);
  enum lightyellow = NVGColor(255, 255, 224);
  enum lime = NVGColor(0, 255, 0);
  enum limegreen = NVGColor(50, 205, 50);
  enum linen = NVGColor(250, 240, 230);
  enum magenta = NVGColor(255, 0, 255); // basic color
  enum maroon = NVGColor(128, 0, 0);
  enum mediumaquamarine = NVGColor(102, 205, 170);
  enum mediumblue = NVGColor(0, 0, 205);
  enum mediumorchid = NVGColor(186, 85, 211);
  enum mediumpurple = NVGColor(147, 112, 219);
  enum mediumseagreen = NVGColor(60, 179, 113);
  enum mediumslateblue = NVGColor(123, 104, 238);
  enum mediumspringgreen = NVGColor(0, 250, 154);
  enum mediumturquoise = NVGColor(72, 209, 204);
  enum mediumvioletred = NVGColor(199, 21, 133);
  enum midnightblue = NVGColor(25, 25, 112);
  enum mintcream = NVGColor(245, 255, 250);
  enum mistyrose = NVGColor(255, 228, 225);
  enum moccasin = NVGColor(255, 228, 181);
  enum navajowhite = NVGColor(255, 222, 173);
  enum navy = NVGColor(0, 0, 128);
  enum oldlace = NVGColor(253, 245, 230);
  enum olive = NVGColor(128, 128, 0);
  enum olivedrab = NVGColor(107, 142, 35);
  enum orange = NVGColor(255, 165, 0);
  enum orangered = NVGColor(255, 69, 0);
  enum orchid = NVGColor(218, 112, 214);
  enum palegoldenrod = NVGColor(238, 232, 170);
  enum palegreen = NVGColor(152, 251, 152);
  enum paleturquoise = NVGColor(175, 238, 238);
  enum palevioletred = NVGColor(219, 112, 147);
  enum papayawhip = NVGColor(255, 239, 213);
  enum peachpuff = NVGColor(255, 218, 185);
  enum peru = NVGColor(205, 133, 63);
  enum pink = NVGColor(255, 192, 203);
  enum plum = NVGColor(221, 160, 221);
  enum powderblue = NVGColor(176, 224, 230);
  enum purple = NVGColor(128, 0, 128);
  enum red = NVGColor(255, 0, 0); // basic color
  enum rosybrown = NVGColor(188, 143, 143);
  enum royalblue = NVGColor(65, 105, 225);
  enum saddlebrown = NVGColor(139, 69, 19);
  enum salmon = NVGColor(250, 128, 114);
  enum sandybrown = NVGColor(244, 164, 96);
  enum seagreen = NVGColor(46, 139, 87);
  enum seashell = NVGColor(255, 245, 238);
  enum sienna = NVGColor(160, 82, 45);
  enum silver = NVGColor(192, 192, 192);
  enum skyblue = NVGColor(135, 206, 235);
  enum slateblue = NVGColor(106, 90, 205);
  enum slategray = NVGColor(112, 128, 144);
  enum slategrey = NVGColor(112, 128, 144);
  enum snow = NVGColor(255, 250, 250);
  enum springgreen = NVGColor(0, 255, 127);
  enum steelblue = NVGColor(70, 130, 180);
  enum tan = NVGColor(210, 180, 140);
  enum teal = NVGColor(0, 128, 128);
  enum thistle = NVGColor(216, 191, 216);
  enum tomato = NVGColor(255, 99, 71);
  enum turquoise = NVGColor(64, 224, 208);
  enum violet = NVGColor(238, 130, 238);
  enum wheat = NVGColor(245, 222, 179);
  enum white = NVGColor(255, 255, 255); // basic color
  enum whitesmoke = NVGColor(245, 245, 245);
  enum yellow = NVGColor(255, 255, 0); // basic color
  enum yellowgreen = NVGColor(154, 205, 50);

nothrow @safe @nogc:
public:
  ///
  this (int ar, int ag, int ab, int aa=255) pure {
    pragma(inline, true);
    r = nvgClampToByte(ar)/255.0f;
    g = nvgClampToByte(ag)/255.0f;
    b = nvgClampToByte(ab)/255.0f;
    a = nvgClampToByte(aa)/255.0f;
  }

  ///
  this (float ar, float ag, float ab, float aa=1.0f) pure {
    pragma(inline, true);
    r = ar;
    g = ag;
    b = ab;
    a = aa;
  }

  /// AABBGGRR (same format as little-endian RGBA image, coincidentally, the same as arsd.color)
  this (uint c) pure {
    pragma(inline, true);
    r = (c&0xff)/255.0f;
    g = ((c>>8)&0xff)/255.0f;
    b = ((c>>16)&0xff)/255.0f;
    a = ((c>>24)&0xff)/255.0f;
  }

  /// Supports: "#rgb", "#rrggbb", "#argb", "#aarrggbb"
  this (const(char)[] srgb) {
    static int c2d (char ch) pure nothrow @safe @nogc {
      pragma(inline, true);
      return
        ch >= '0' && ch <= '9' ? ch-'0' :
        ch >= 'A' && ch <= 'F' ? ch-'A'+10 :
        ch >= 'a' && ch <= 'f' ? ch-'a'+10 :
        -1;
    }
    int[8] digs;
    int dc = -1;
    foreach (immutable char ch; srgb) {
      if (ch <= ' ') continue;
      if (ch == '#') {
        if (dc != -1) { dc = -1; break; }
        dc = 0;
      } else {
        if (dc >= digs.length) { dc = -1; break; }
        if ((digs[dc++] = c2d(ch)) < 0) { dc = -1; break; }
      }
    }
    switch (dc) {
      case 3: // rgb
        a = 1.0f;
        r = digs[0]/15.0f;
        g = digs[1]/15.0f;
        b = digs[2]/15.0f;
        break;
      case 4: // argb
        a = digs[0]/15.0f;
        r = digs[1]/15.0f;
        g = digs[2]/15.0f;
        b = digs[3]/15.0f;
        break;
      case 6: // rrggbb
        a = 1.0f;
        r = (digs[0]*16+digs[1])/255.0f;
        g = (digs[2]*16+digs[3])/255.0f;
        b = (digs[4]*16+digs[5])/255.0f;
        break;
      case 8: // aarrggbb
        a = (digs[0]*16+digs[1])/255.0f;
        r = (digs[2]*16+digs[3])/255.0f;
        g = (digs[4]*16+digs[5])/255.0f;
        b = (digs[6]*16+digs[7])/255.0f;
        break;
      default:
        break;
    }
  }

  /// Is this color completely opaque?
  @property bool isOpaque () const pure nothrow @trusted @nogc => (rgba.ptr[3] >= 1.0f);
  /// Is this color completely transparent?
  @property bool isTransparent () const pure nothrow @trusted @nogc => (rgba.ptr[3] <= 0.0f);

  /// AABBGGRR (same format as little-endian RGBA image, coincidentally, the same as arsd.color)
  @property uint asUint () const pure {
    pragma(inline, true);
    return
      cast(uint)(r*255)|
      (cast(uint)(g*255)<<8)|
      (cast(uint)(b*255)<<16)|
      (cast(uint)(a*255)<<24);
  }

  alias asUintABGR = asUint; /// Ditto.

  /// AABBGGRR (same format as little-endian RGBA image, coincidentally, the same as arsd.color)
  static NVGColor fromUint (uint c) pure => NVGColor(c);

  alias fromUintABGR = fromUint; /// Ditto.

  /// AARRGGBB
  @property uint asUintARGB () const pure {
    pragma(inline, true);
    return
      cast(uint)(b*255)|
      (cast(uint)(g*255)<<8)|
      (cast(uint)(r*255)<<16)|
      (cast(uint)(a*255)<<24);
  }

  /// AARRGGBB
  static NVGColor fromUintARGB (uint c) pure => NVGColor((c>>16)&0xff, (c>>8)&0xff, c&0xff, (c>>24)&0xff);

  @property ref inout(float) r () inout pure @trusted => rgba.ptr[0];
  @property ref inout(float) g () inout pure @trusted => rgba.ptr[1];
  @property ref inout(float) b () inout pure @trusted => rgba.ptr[2];
  @property ref inout(float) a () inout pure @trusted => rgba.ptr[3];

  NVGHSL asHSL() (bool useWeightedLightness=false) const => NVGHSL.fromColor(this, useWeightedLightness);
  static fromHSL() (in auto ref NVGHSL hsl) => hsl.asColor;

  version(nanovg_use_arsd_image) {
    Color toArsd () const => Color(cast(int)(r*255), cast(int)(g*255), cast(int)(b*255), cast(int)(a*255));
    static NVGColor fromArsd() (in auto ref Color c) const => NVGColor(c.r, c.g, c.b, c.a);
  }
}


/// NanoVega A-HSL color
public align(1) struct NVGHSL {
align(1):
  float h=0, s=0, l=1, a=1; ///

  string toString () const { import std.format : format; return (a != 1 ? "HSL(%s,%s,%s,%d)".format(h, s, l, a) : "HSL(%s,%s,%s)".format(h, s, l)); }

nothrow @safe @nogc:
public:
  ///
  this (float ah, float as, float al, float aa=1) pure { pragma(inline, true); h = ah; s = as; l = al; a = aa; }

  NVGColor asColor () const => nvgHSLA(h, s, l, a); ///

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


/// Paint parameters for various fills. Don't change anything here!
public struct NVGPaint {
  float[6] xform;
  float[2] extent;
  float radius;
  float feather;
  NVGColor innerColor; // this can be used to modulate image fill
  NVGColor outerColor;
  int image;
}

///
public enum NVGWinding {
  CCW = 1, /// Winding for solid shapes
  CW = 2,  /// Winding for holes
}

///
public enum NVGSolidity {
  Solid = 1, /// CCW
  Hole = 2, /// CW
}

///
public enum NVGLineCap {
  Butt, ///
  Round, ///
  Square, ///
  Bevel, ///
  Miter, ///
}

/// Text align.
public align(1) struct NVGTextAlign {
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
  this (H h) { pragma(inline, true); value = h; } ///
  this (V v) { pragma(inline, true); value = cast(ubyte)(v<<4); } ///
  this (H h, V v) { pragma(inline, true); value = cast(ubyte)(h|(v<<4)); } ///
  this (V v, H h) { pragma(inline, true); value = cast(ubyte)(h|(v<<4)); } ///
  void reset () { pragma(inline, true); value = 0; } ///
  void reset (H h, V v) { pragma(inline, true); value = cast(ubyte)(h|(v<<4)); } ///
  void reset (V v, H h) { pragma(inline, true); value = cast(ubyte)(h|(v<<4)); } ///
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
public enum NVGBlendFactor {
  ZERO = 1<<0, ///
  ONE = 1<<1, ///
  SRC_COLOR = 1<<2, ///
  ONE_MINUS_SRC_COLOR = 1<<3, ///
  DST_COLOR = 1<<4, ///
  ONE_MINUS_DST_COLOR = 1<<5, ///
  SRC_ALPHA = 1<<6, ///
  ONE_MINUS_SRC_ALPHA = 1<<7, ///
  DST_ALPHA = 1<<8, ///
  ONE_MINUS_DST_ALPHA = 1<<9, ///
  SRC_ALPHA_SATURATE = 1<<10, ///
}

///
public enum NVGCompositeOperation {
  SOURCE_OVER, ///
  SOURCE_IN, ///
  SOURCE_OUT, ///
  ATOP, ///
  DESTINATION_OVER, ///
  DESTINATION_IN, ///
  DESTINATION_OUT, ///
  DESTINATION_ATOP, ///
  LIGHTER, ///
  COPY, ///
  XOR, ///
}

///
public struct NVGCompositeOperationState {
  NVGBlendFactor srcRGB; ///
  NVGBlendFactor dstRGB; ///
  NVGBlendFactor srcAlpha; ///
  NVGBlendFactor dstAlpha; ///
}

///
public struct NVGGlyphPosition {
  usize strpos;     /// Position of the glyph in the input string.
  float x;          /// The x-coordinate of the logical glyph position.
  float minx, maxx; /// The bounds of the glyph shape.
}

///
public struct NVGTextRow(CT) if (isAnyCharType!CT) {
  alias CharType = CT;
  const(CT)[] s;
  int start;        /// Index in the input text where the row starts.
  int end;          /// Index in the input text where the row ends (one past the last character).
  float width;      /// Logical width of the row.
  float minx, maxx; /// Actual bounds of the row. Logical with and bounds can differ because of kerning and some parts over extending.
  /// Get rest of the string.
  @property const(CT)[] rest () const pure nothrow @trusted @nogc => (end <= s.length ? s[end..$] : null);
  /// Get current row.
  @property const(CT)[] row () const pure nothrow @trusted @nogc => s[start..end];
  @property const(CT)[] string () const pure nothrow @trusted @nogc => s;
  @property void string(CT) (const(CT)[] v) pure nothrow @trusted @nogc => s = v;
}

///
public enum NVGImageFlags {
  None            =    0, /// Nothing special.
  GenerateMipmaps = 1<<0, /// Generate mipmaps during creation of the image.
  RepeatX         = 1<<1, /// Repeat image in X direction.
  RepeatY         = 1<<2, /// Repeat image in Y direction.
  FlipY           = 1<<3, /// Flips (inverses) image in Y direction when rendered.
  Premultiplied   = 1<<4, /// Image data has premultiplied alpha.
  NoFiltering     = 1<<8, /// use GL_NEAREST instead of GL_LINEAR
  Nearest = NoFiltering,  /// compatibility with original NanoVega
}

// ////////////////////////////////////////////////////////////////////////// //
package/*(iv.nanovega)*/:

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
  bool fontAA;
  bool function (void* uptr) nothrow @trusted @nogc renderCreate;
  int function (void* uptr, NVGtexture type, int w, int h, int imageFlags, const(ubyte)* data) nothrow @trusted @nogc renderCreateTexture;
  bool function (void* uptr, int image) nothrow @trusted @nogc renderDeleteTexture;
  bool function (void* uptr, int image, int x, int y, int w, int h, const(ubyte)* data) nothrow @trusted @nogc renderUpdateTexture;
  bool function (void* uptr, int image, int* w, int* h) nothrow @trusted @nogc renderGetTextureSize;
  void function (void* uptr, int width, int height) nothrow @trusted @nogc renderViewport;
  void function (void* uptr) nothrow @trusted @nogc renderCancel;
  void function (void* uptr, NVGCompositeOperationState compositeOperation) nothrow @trusted @nogc renderFlush;
  void function (void* uptr, NVGPaint* paint, NVGscissor* scissor, float fringe, const(float)* bounds, const(NVGpath)* paths, int npaths, bool evenOdd) nothrow @trusted @nogc renderFill;
  void function (void* uptr, NVGPaint* paint, NVGscissor* scissor, float fringe, float strokeWidth, const(NVGpath)* paths, int npaths) nothrow @trusted @nogc renderStroke;
  void function (void* uptr, NVGPaint* paint, NVGscissor* scissor, const(NVGvertex)* verts, int nverts) nothrow @trusted @nogc renderTriangles;
  void function (void* uptr) nothrow @trusted @nogc renderDelete;
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
enum NVG_MIN_FEATHER = 0.001f; // it should be greater than zero, 'cause it is used in shader for divisions

enum Command {
  MoveTo = 0,
  LineTo = 1,
  BezierTo = 2,
  Close = 3,
  Winding = 4,
}

enum PointFlag : int {
  Corner = 0x01,
  Left = 0x02,
  Bevel = 0x04,
  InnerBevelPR = 0x08,
}

struct NVGstate {
  NVGCompositeOperationState compositeOperation;
  bool shapeAntiAlias;
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
  bool evenOddMode; // use even-odd filling rule (required for some svgs); otherwise use non-zero fill
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

/// pointer to opaque NanoVega context structure.
public alias NVGContext = NVGcontext*;

/// Returns FontStash context of the given NanoVega context.
FONScontext* fonsContext (NVGContext ctx) { return (ctx !is null ? ctx.fs : null); }

private struct NVGcontext {
private:
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
  public FONScontext* fs; /// this is public, so i can use it in text layouter, for example; WARNING: DON'T MODIFY!
  int[NVG_MAX_FONTIMAGES] fontImages;
  int fontImageIdx;
  int drawCallCount;
  int fillTriCount;
  int strokeTriCount;
  int textTriCount;
  // picking API
  NVGpickScene* pickScene;
  int pathPickId; // >=0: register all pathes for picking using this id
  uint pathPickRegistered; // if `pathPickId` >= 0, this is used to avoid double-registration (see `NVGPickKind`); hi 16 bit is check flags, lo 16 bit is mode
  // internals
  int mWidth, mHeight;
  float mDeviceRatio;
  void delegate (NVGContext ctx) nothrow @trusted @nogc cleanup;
public:
  // some public info
  const pure nothrow @safe @nogc {
    @property int width () => mWidth; /// valid only inside `beginFrame()`/`endFrame()`
    @property int height () => mHeight; /// valid only inside `beginFrame()`/`endFrame()`
    @property float devicePixelRatio () => mDeviceRatio; /// valid only inside `beginFrame()`/`endFrame()`
  }

  // path autoregistration
  pure nothrow @safe @nogc {
    enum NoPick = -1;

    @property int pickid () const => pathPickId; /// >=0: this pickid will be assigned to all filled/stroked pathes
    @property void pickid (int v) => pathPickId = v; /// >=0: this pickid will be assigned to all filled/stroked pathes

    @property uint pickmode () const => pathPickRegistered&NVGPickKind.All; /// pick autoregistration mode; see `NVGPickKind`
    @property void pickmode (uint v) => pathPickRegistered = (pathPickRegistered&0xffff_0000u)|(v&NVGPickKind.All); /// pick autoregistration mode; see `NVGPickKind`
  }
}

public import core.stdc.math :
  nvg__sqrtf = sqrtf,
  nvg__modf = fmodf,
  nvg__sinf = sinf,
  nvg__cosf = cosf,
  nvg__tanf = tanf,
  nvg__atan2f = atan2f,
  nvg__acosf = acosf,
  nvg__ceilf = ceilf;

version(Windows) {
  public int nvg__lrintf (float f) nothrow @trusted @nogc { pragma(inline, true); return cast(int)(f+0.5); }
} else {
  public import core.stdc.math : nvg__lrintf = lrintf;
}

public auto nvg__min(T) (T a, T b) { pragma(inline, true); return (a < b ? a : b); }
public auto nvg__max(T) (T a, T b) { pragma(inline, true); return (a > b ? a : b); }
public auto nvg__clamp(T) (T a, T mn, T mx) { pragma(inline, true); return (a < mn ? mn : (a > mx ? mx : a)); }
//float nvg__absf() (float a) { pragma(inline, true); return (a >= 0.0f ? a : -a); }
public auto nvg__sign(T) (T a) { pragma(inline, true); return (a >= cast(T)0 ? cast(T)1 : cast(T)(-1)); }
public float nvg__cross() (float dx0, float dy0, float dx1, float dy1) { pragma(inline, true); return (dx1*dy0-dx0*dy1); }

public import core.stdc.math : nvg__absf = fabsf;


float nvg__normalize (float* x, float* y) nothrow @safe @nogc {
  float d = nvg__sqrtf((*x)*(*x)+(*y)*(*y));
  if (d > 1e-6f) {
    immutable float id = 1.0f/d;
    *x *= id;
    *y *= id;
  }
  return d;
}

void nvg__deletePathCache (NVGpathCache* c) nothrow @trusted @nogc {
  if (c is null) return;
  if (c.points !is null) free(c.points);
  if (c.paths !is null) free(c.paths);
  if (c.verts !is null) free(c.verts);
  free(c);
}

NVGpathCache* nvg__allocPathCache () nothrow @trusted @nogc {
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

  c.verts = cast(NVGvertex*)malloc(NVGvertex.sizeof*NVG_INIT_VERTS_SIZE);
  if (c.verts is null) goto error;
  c.nverts = 0;
  c.cverts = NVG_INIT_VERTS_SIZE;

  return c;
error:
  nvg__deletePathCache(c);
  return null;
}

void nvg__setDevicePixelRatio (NVGContext ctx, float ratio) pure nothrow @safe @nogc {
  ctx.tessTol = 0.25f/ratio;
  ctx.distTol = 0.01f/ratio;
  ctx.fringeWidth = 1.0f/ratio;
  ctx.devicePxRatio = ratio;
}

NVGCompositeOperationState nvg__compositeOperationState (NVGCompositeOperation op) pure nothrow @safe @nogc {
  NVGBlendFactor sfactor, dfactor;
       if (op == NVGCompositeOperation.SOURCE_OVER) { sfactor = NVGBlendFactor.ONE; dfactor = NVGBlendFactor.ONE_MINUS_SRC_ALPHA;}
  else if (op == NVGCompositeOperation.SOURCE_IN) { sfactor = NVGBlendFactor.DST_ALPHA; dfactor = NVGBlendFactor.ZERO; }
  else if (op == NVGCompositeOperation.SOURCE_OUT) { sfactor = NVGBlendFactor.ONE_MINUS_DST_ALPHA; dfactor = NVGBlendFactor.ZERO; }
  else if (op == NVGCompositeOperation.ATOP) { sfactor = NVGBlendFactor.DST_ALPHA; dfactor = NVGBlendFactor.ONE_MINUS_SRC_ALPHA; }
  else if (op == NVGCompositeOperation.DESTINATION_OVER) { sfactor = NVGBlendFactor.ONE_MINUS_DST_ALPHA; dfactor = NVGBlendFactor.ONE; }
  else if (op == NVGCompositeOperation.DESTINATION_IN) { sfactor = NVGBlendFactor.ZERO; dfactor = NVGBlendFactor.SRC_ALPHA; }
  else if (op == NVGCompositeOperation.DESTINATION_OUT) { sfactor = NVGBlendFactor.ZERO; dfactor = NVGBlendFactor.ONE_MINUS_SRC_ALPHA; }
  else if (op == NVGCompositeOperation.DESTINATION_ATOP) { sfactor = NVGBlendFactor.ONE_MINUS_DST_ALPHA; dfactor = NVGBlendFactor.SRC_ALPHA; }
  else if (op == NVGCompositeOperation.LIGHTER) { sfactor = NVGBlendFactor.ONE; dfactor = NVGBlendFactor.ONE; }
  else if (op == NVGCompositeOperation.COPY) { sfactor = NVGBlendFactor.ONE; dfactor = NVGBlendFactor.ZERO;  }
  else if (op == NVGCompositeOperation.XOR) { sfactor = NVGBlendFactor.ONE_MINUS_DST_ALPHA; dfactor = NVGBlendFactor.ONE_MINUS_SRC_ALPHA; }
  else { sfactor = NVGBlendFactor.ONE; dfactor = NVGBlendFactor.ONE_MINUS_SRC_ALPHA;} // default value for invalid op: SOURCE_OVER

  NVGCompositeOperationState state;
  state.srcRGB = sfactor;
  state.dstRGB = dfactor;
  state.srcAlpha = sfactor;
  state.dstAlpha = dfactor;
  return state;
}

NVGstate* nvg__getState (NVGContext ctx) pure nothrow @trusted @nogc {
  //pragma(inline, true);
  return ctx.states.ptr+(ctx.nstates-1);
}

// Constructor called by the render back-end.
package/*(iv.nanovega)*/ NVGContext createInternal (NVGparams* params) nothrow @trusted @nogc {
  FONSparams fontParams = void;
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
  ctx.fontImages[0] = ctx.params.renderCreateTexture(ctx.params.userPtr, NVGtexture.Alpha, fontParams.width, fontParams.height, (ctx.params.fontAA ? 0 : NVGImageFlags.NoFiltering), null);
  if (ctx.fontImages[0] == 0) goto error;
  ctx.fontImageIdx = 0;

  ctx.pathPickId = -1;

  return ctx;

error:
  ctx.deleteInternal();
  return null;
}

// Called by render backend.
package/*(iv.nanovega)*/ NVGparams* internalParams (NVGContext ctx) nothrow @trusted @nogc {
  return &ctx.params;
}

// Destructor called by the render back-end.
package/*(iv.nanovega)*/ void deleteInternal (ref NVGContext ctx) nothrow @trusted @nogc {
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

  if (ctx.pickScene !is null) nvg__deletePickScene(ctx.pickScene);

  if (ctx.cleanup !is null) ctx.cleanup(ctx);

  free(ctx);
}

///
public void kill (ref NVGContext ctx) nothrow @trusted @nogc {
  if (ctx !is null) {
    ctx.deleteInternal();
    ctx = null;
  }
}

/** Begin drawing a new frame.
 *
 * Calls to NanoVega drawing API should be wrapped in `beginFrame()` and `endFrame()`
 *
 * `beginFrame()` defines the size of the window to render to in relation currently
 * set viewport (i.e. glViewport on GL backends). Device pixel ration allows to
 * control the rendering on Hi-DPI devices.
 *
 * For example, GLFW returns two dimension for an opened window: window size and
 * frame buffer size. In that case you would set windowWidth/windowHeight to the window size,
 * devicePixelRatio to: `windowWidth/windowHeight`.
 *
 * Default ratio is `1`.
 *
 * Note that fractional ratio can (and will) distort your fonts and images.
 *
 * This call also resets pick marks (see picking API for non-rasterized pathes).
 *
 * see also `glNVGClearFlags()`, which returns necessary flags for `glClear()`.
 */
public void beginFrame (NVGContext ctx, int windowWidth, int windowHeight, float devicePixelRatio=1.0f) nothrow @trusted @nogc {
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
  ctx.mWidth = windowWidth;
  ctx.mHeight = windowHeight;
  ctx.mDeviceRatio = devicePixelRatio;

  ctx.drawCallCount = 0;
  ctx.fillTriCount = 0;
  ctx.strokeTriCount = 0;
  ctx.textTriCount = 0;

  nvg__pickBeginFrame(ctx, windowWidth, windowHeight);
}

/// Cancels drawing the current frame.
public void cancelFrame (NVGContext ctx) nothrow @trusted @nogc {
  ctx.mWidth = 0;
  ctx.mHeight = 0;
  ctx.mDeviceRatio = 0;
  // cancel render queue
  ctx.params.renderCancel(ctx.params.userPtr);
}

/// Ends drawing the current frame (flushing remaining render state).
public void endFrame (NVGContext ctx) nothrow @trusted @nogc {
  ctx.mWidth = 0;
  ctx.mHeight = 0;
  ctx.mDeviceRatio = 0;
  // flush render queue
  NVGstate* state = nvg__getState(ctx);
  ctx.params.renderFlush(ctx.params.userPtr, state.compositeOperation);
  if (ctx.fontImageIdx != 0) {
    int fontImage = ctx.fontImages[ctx.fontImageIdx];
    int j, iw, ih;
    // delete images that smaller than current one
    if (fontImage == 0) return;
    ctx.imageSize(fontImage, iw, ih);
    foreach (int i; 0..ctx.fontImageIdx) {
      if (ctx.fontImages[i] != 0) {
        int nw, nh;
        ctx.imageSize(ctx.fontImages[i], nw, nh);
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
/** <h1>Composite operation</h1>
 * The composite operations in NanoVega are modeled after HTML Canvas API, and
 * the blend func is based on OpenGL (see corresponding manuals for more info).
 * The colors in the blending state have premultiplied alpha.
 */
public alias NVGSectionDummy00_00 = void;

/// Sets the composite operation.
public void globalCompositeOperation (NVGContext ctx, NVGCompositeOperation op) nothrow @trusted @nogc {
  NVGstate* state = nvg__getState(ctx);
  state.compositeOperation = nvg__compositeOperationState(op);
}

/// Sets the composite operation with custom pixel arithmetic.
public void globalCompositeBlendFunc (NVGContext ctx, NVGBlendFactor sfactor, NVGBlendFactor dfactor) nothrow @trusted @nogc {
  ctx.globalCompositeBlendFuncSeparate(sfactor, dfactor, sfactor, dfactor);
}

/// Sets the composite operation with custom pixel arithmetic for RGB and alpha components separately.
public void globalCompositeBlendFuncSeparate (NVGContext ctx, NVGBlendFactor srcRGB, NVGBlendFactor dstRGB, NVGBlendFactor srcAlpha, NVGBlendFactor dstAlpha) nothrow @trusted @nogc {
  NVGCompositeOperationState op;
  op.srcRGB = srcRGB;
  op.dstRGB = dstRGB;
  op.srcAlpha = srcAlpha;
  op.dstAlpha = dstAlpha;
  NVGstate* state = nvg__getState(ctx);
  state.compositeOperation = op;
}


// ////////////////////////////////////////////////////////////////////////// //
/// <h1>Color utils</h1>
/// Colors in NanoVega are stored as ARGB. Zero alpha means "transparent color".
public alias NVGSectionDummy00 = void;

/// Returns a color value from string form.
/// Supports: "#rgb", "#rrggbb", "#argb", "#aarrggbb"
public NVGColor nvgRGB() (const(char)[] srgb) => NVGColor(srgb);

/// Ditto.
public NVGColor nvgRGBA() (const(char)[] srgb) => NVGColor(srgb);

/// Returns a color value from red, green, blue values. Alpha will be set to 255 (1.0f).
public NVGColor nvgRGB() (int r, int g, int b) => NVGColor(r, g, b, 255);

/// Returns a color value from red, green, blue values. Alpha will be set to 1.0f.
public NVGColor nvgRGBf() (float r, float g, float b) => NVGColor(r, g, b, 1.0f);

/// Returns a color value from red, green, blue and alpha values.
public NVGColor nvgRGBA() (int r, int g, int b, int a=255) => NVGColor(r, g, b, a);

/// Returns a color value from red, green, blue and alpha values.
public NVGColor nvgRGBAf() (float r, float g, float b, float a=1.0f) => NVGColor(r, g, b, a);

/// Returns new color with transparency (alpha) set to `a`.
public NVGColor nvgTransRGBA() (NVGColor c, ubyte a) {
  pragma(inline, true);
  c.a = a/255.0f;
  return c;
}

/// Ditto.
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

float nvg__hue() (float h, float m1, float m2) pure nothrow @safe @nogc {
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
/// HSL values are all in range [0..1], alpha in range [0..255].
public NVGColor nvgHSLA() (float h, float s, float l, ubyte a=255) {
  static if (__VERSION__ >= 2072) pragma(inline, true);
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

/// Returns color value specified by hue, saturation and lightness and alpha.
/// HSL values and alpha are all in range [0..1].
public NVGColor nvgHSLA() (float h, float s, float l, float a) {
  // sorry for copypasta, it is for inliner
  static if (__VERSION__ >= 2072) pragma(inline, true);
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


// ////////////////////////////////////////////////////////////////////////// //
/// <h1>Transforms</h1>
//
/** The paths, gradients, patterns and scissor region are transformed by an transformation
 * matrix at the time when they are passed to the API.
 * The current transformation matrix is an affine matrix:
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
public void nvgTransformIdentity (float[] t) nothrow @trusted @nogc {
  pragma(inline, true);
  assert(t.length >= 6);
  t.ptr[0] = 1.0f; t.ptr[1] = 0.0f;
  t.ptr[2] = 0.0f; t.ptr[3] = 1.0f;
  t.ptr[4] = 0.0f; t.ptr[5] = 0.0f;
}

/// Sets the transform to translation matrix matrix.
public void nvgTransformTranslate (float[] t, float tx, float ty) nothrow @trusted @nogc {
  pragma(inline, true);
  assert(t.length >= 6);
  t.ptr[0] = 1.0f; t.ptr[1] = 0.0f;
  t.ptr[2] = 0.0f; t.ptr[3] = 1.0f;
  t.ptr[4] = tx; t.ptr[5] = ty;
}

/// Sets the transform to scale matrix.
public void nvgTransformScale (float[] t, float sx, float sy) nothrow @trusted @nogc {
  pragma(inline, true);
  assert(t.length >= 6);
  t.ptr[0] = sx; t.ptr[1] = 0.0f;
  t.ptr[2] = 0.0f; t.ptr[3] = sy;
  t.ptr[4] = 0.0f; t.ptr[5] = 0.0f;
}

/// Sets the transform to rotate matrix. Angle is specified in radians.
public void nvgTransformRotate (float[] t, float a) nothrow @trusted @nogc {
  //pragma(inline, true);
  assert(t.length >= 6);
  float cs = nvg__cosf(a), sn = nvg__sinf(a);
  t.ptr[0] = cs; t.ptr[1] = sn;
  t.ptr[2] = -sn; t.ptr[3] = cs;
  t.ptr[4] = 0.0f; t.ptr[5] = 0.0f;
}

/// Sets the transform to skew-x matrix. Angle is specified in radians.
public void nvgTransformSkewX (float[] t, float a) nothrow @trusted @nogc {
  //pragma(inline, true);
  assert(t.length >= 6);
  t.ptr[0] = 1.0f; t.ptr[1] = 0.0f;
  t.ptr[2] = nvg__tanf(a); t.ptr[3] = 1.0f;
  t.ptr[4] = 0.0f; t.ptr[5] = 0.0f;
}

/// Sets the transform to skew-y matrix. Angle is specified in radians.
public void nvgTransformSkewY (float[] t, float a) nothrow @trusted @nogc {
  //pragma(inline, true);
  assert(t.length >= 6);
  t.ptr[0] = 1.0f; t.ptr[1] = nvg__tanf(a);
  t.ptr[2] = 0.0f; t.ptr[3] = 1.0f;
  t.ptr[4] = 0.0f; t.ptr[5] = 0.0f;
}

/// Sets the transform to the result of multiplication of two transforms, of A = A*B.
public void nvgTransformMultiply (float[] t, const(float)[] s) nothrow @trusted @nogc {
  assert(t.length >= 6);
  assert(s.length >= 6);
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
public void nvgTransformPremultiply (float[] t, const(float)[] s) nothrow @trusted @nogc {
  assert(t.length >= 6);
  assert(s.length >= 6);
  //pragma(inline, true);
  float[6] s2 = s[0..6];
  nvgTransformMultiply(s2[], t);
  t[0..6] = s2[];
}

/// Sets the destination to inverse of specified transform.
/// Returns `true` if the inverse could be calculated, else `false`.
public bool nvgTransformInverse (float[] inv, const(float)[] t) nothrow @trusted @nogc {
  assert(t.length >= 6);
  assert(inv.length >= 6);
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
public void nvgTransformPoint (float* dx, float* dy, const(float)[] t, float sx, float sy) nothrow @trusted @nogc {
  pragma(inline, true);
  assert(t.length >= 6);
  if (dx !is null) *dx = sx*t.ptr[0]+sy*t.ptr[2]+t.ptr[4];
  if (dy !is null) *dy = sx*t.ptr[1]+sy*t.ptr[3]+t.ptr[5];
}

// Converts degrees to radians.
public float nvgDegToRad() (float deg) => deg/180.0f*NVG_PI;

// Converts radians to degrees.
public float nvgRadToDeg() (float rad) => rad/NVG_PI*180.0f;

void nvg__setPaintColor (ref NVGPaint p, NVGColor color) nothrow @trusted @nogc {
  //pragma(inline, true);
  memset(&p, 0, p.sizeof);
  nvgTransformIdentity(p.xform[]);
  p.radius = 0.0f;
  p.feather = 1.0f;
  p.innerColor = color;
  p.outerColor = color;
}


// ////////////////////////////////////////////////////////////////////////// //
/// <h1>State handling</h1>
//
/** NanoVega contains state which represents how paths will be rendered.
 * The state contains transform, fill and stroke styles, text and font styles,
 * and scissor clipping.
 */
public alias NVGSectionDummy02 = void;

/** Pushes and saves the current render state into a state stack.
 * A matching `restore()` must be used to restore the state.
 * Returns `false` if state stack overflowed.
 */
public bool save (NVGContext ctx) nothrow @trusted @nogc {
  if (ctx.nstates >= NVG_MAX_STATES) return false;
  if (ctx.nstates > 0) memcpy(&ctx.states[ctx.nstates], &ctx.states[ctx.nstates-1], NVGstate.sizeof);
  ++ctx.nstates;
  return true;
}

/// Pops and restores current render state.
public bool restore (NVGContext ctx) nothrow @trusted @nogc {
  if (ctx.nstates <= 1) return false;
  --ctx.nstates;
  return true;
}

/// Resets current render state to default values. Does not affect the render state stack.
public void reset (NVGContext ctx) nothrow @trusted @nogc {
  NVGstate* state = nvg__getState(ctx);
  memset(state, 0, (*state).sizeof);

  nvg__setPaintColor(state.fill, nvgRGBA(255, 255, 255, 255));
  nvg__setPaintColor(state.stroke, nvgRGBA(0, 0, 0, 255));
  state.compositeOperation = nvg__compositeOperationState(NVGCompositeOperation.SOURCE_OVER);
  state.shapeAntiAlias = true;
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
  state.evenOddMode = false;
}

/// Sets filling mode to "even-odd".
public void evenOddFill (NVGContext ctx) nothrow @trusted @nogc {
  NVGstate* state = nvg__getState(ctx);
  state.evenOddMode = true;
}

/// Sets filling mode to "non-zero" (this is default mode).
public void nonZeroFill (NVGContext ctx) nothrow @trusted @nogc {
  NVGstate* state = nvg__getState(ctx);
  state.evenOddMode = false;
}

// ////////////////////////////////////////////////////////////////////////// //
/// <h1>Render styles</h1>
//
/** Fill and stroke render style can be either a solid color or a paint which is a gradient or a pattern.
 * Solid color is simply defined as a color value, different kinds of paints can be created
 * using `linearGradient()`, `boxGradient()`, `radialGradient()` and `imagePattern()`.
 *
 * Current render style can be saved and restored using `save()` and `restore()`.
 *
 * Note that if you want "almost perfect" pixel rendering, you should set aspect ratio to 1,
 * and use `integerCoord+0.5f` as pixel coordinates.
 */
public alias NVGSectionDummy03 = void;

/// Sets whether to draw antialias for `stroke()` and `fill()`. It's enabled by default.
public void shapeAntiAlias (NVGContext ctx, bool enabled) {
  NVGstate* state = nvg__getState(ctx);
  state.shapeAntiAlias = enabled;
}

/// Sets the stroke width of the stroke style.
public void strokeWidth (NVGContext ctx, float width) nothrow @trusted @nogc {
  NVGstate* state = nvg__getState(ctx);
  state.strokeWidth = width;
}

/// Sets the miter limit of the stroke style. Miter limit controls when a sharp corner is beveled.
public void miterLimit (NVGContext ctx, float limit) nothrow @trusted @nogc {
  NVGstate* state = nvg__getState(ctx);
  state.miterLimit = limit;
}

/// Sets how the end of the line (cap) is drawn,
/// Can be one of: NVGLineCap.Butt (default), NVGLineCap.Round, NVGLineCap.Square.
public void lineCap (NVGContext ctx, NVGLineCap cap) nothrow @trusted @nogc {
  NVGstate* state = nvg__getState(ctx);
  state.lineCap = cap;
}

/// Sets how sharp path corners are drawn.
/// Can be one of NVGLineCap.Miter (default), NVGLineCap.Round, NVGLineCap.Bevel.
public void lineJoin (NVGContext ctx, NVGLineCap join) nothrow @trusted @nogc {
  NVGstate* state = nvg__getState(ctx);
  state.lineJoin = join;
}

/// Sets the transparency applied to all rendered shapes.
/// Already transparent paths will get proportionally more transparent as well.
public void globalAlpha (NVGContext ctx, float alpha) nothrow @trusted @nogc {
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
public void transform (NVGContext ctx, float a, float b, float c, float d, float e, float f) nothrow @trusted @nogc {
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

/// Resets current transform to an identity matrix.
public void resetTransform (NVGContext ctx) nothrow @trusted @nogc {
  NVGstate* state = nvg__getState(ctx);
  nvgTransformIdentity(state.xform[]);
}

/// Translates current coordinate system.
public void translate (NVGContext ctx, float x, float y) nothrow @trusted @nogc {
  NVGstate* state = nvg__getState(ctx);
  float[6] t = void;
  nvgTransformTranslate(t[], x, y);
  nvgTransformPremultiply(state.xform[], t[]);
}

/// Rotates current coordinate system. Angle is specified in radians.
public void rotate (NVGContext ctx, float angle) nothrow @trusted @nogc {
  NVGstate* state = nvg__getState(ctx);
  float[6] t = void;
  nvgTransformRotate(t[], angle);
  nvgTransformPremultiply(state.xform[], t[]);
}

/// Skews the current coordinate system along X axis. Angle is specified in radians.
public void skewX (NVGContext ctx, float angle) nothrow @trusted @nogc {
  NVGstate* state = nvg__getState(ctx);
  float[6] t = void;
  nvgTransformSkewX(t[], angle);
  nvgTransformPremultiply(state.xform[], t[]);
}

/// Skews the current coordinate system along Y axis. Angle is specified in radians.
public void skewY (NVGContext ctx, float angle) nothrow @trusted @nogc {
  NVGstate* state = nvg__getState(ctx);
  float[6] t = void;
  nvgTransformSkewY(t[], angle);
  nvgTransformPremultiply(state.xform[], t[]);
}

/// Scales the current coordinate system.
public void scale (NVGContext ctx, float x, float y) nothrow @trusted @nogc {
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
public void currentTransform (NVGContext ctx, float[] xform) nothrow @trusted @nogc {
  assert(xform.length >= 6);
  NVGstate* state = nvg__getState(ctx);
  xform[0..6] = state.xform[0..6];
}

/// Sets current stroke style to a solid color.
public void strokeColor (NVGContext ctx, NVGColor color) nothrow @trusted @nogc {
  NVGstate* state = nvg__getState(ctx);
  nvg__setPaintColor(state.stroke, color);
}

/// Sets current stroke style to a paint, which can be a one of the gradients or a pattern.
public void strokePaint (NVGContext ctx, NVGPaint paint) nothrow @trusted @nogc {
  NVGstate* state = nvg__getState(ctx);
  state.stroke = paint;
  nvgTransformMultiply(state.stroke.xform[], state.xform[]);
}

/// Sets current fill style to a solid color.
public void fillColor (NVGContext ctx, NVGColor color) nothrow @trusted @nogc {
  NVGstate* state = nvg__getState(ctx);
  nvg__setPaintColor(state.fill, color);
}

/// Sets current fill style to a paint, which can be a one of the gradients or a pattern.
public void fillPaint (NVGContext ctx, NVGPaint paint) nothrow @trusted @nogc {
  NVGstate* state = nvg__getState(ctx);
  state.fill = paint;
  nvgTransformMultiply(state.fill.xform[], state.xform[]);
}


// ////////////////////////////////////////////////////////////////////////// //
/// <h1>Images</h1>
//
/** NanoVega allows you to load image files in various formats (if arsd loaders are in place) to be used for rendering.
 * In addition you can upload your own image.
 * The parameter imageFlags is combination of flags defined in NVGImageFlags.
 */
public alias NVGSectionDummy04 = void;

version(nanovg_use_arsd_image) {
  // do we have new arsd API to load images?
  static if (!is(typeof(MemoryImage.fromImageFile))) {
    static assert(0, "Sorry, your ARSD is too old. Please, update it.");
  } else {
    alias ArsdImage = MemoryImage.fromImageFile;
  }
}

/// Creates image by loading it from the disk from specified file name.
/// Returns handle to the image or 0 on error.
public int createImage (NVGContext ctx, const(char)[] filename, int imageFlags=NVGImageFlags.None) {
  version(nanovg_use_arsd_image) {
    try {
      auto oimg = ArsdImage(filename);
      if (auto img = cast(TrueColorImage)oimg) {
        scope(exit) delete oimg;
        return ctx.createImageRGBA(img.width, img.height, img.imageData.bytes[], imageFlags);
      } else {
        TrueColorImage img = oimg.getAsTrueColorImage;
        delete oimg;
        scope(exit) delete img;
        return ctx.createImageRGBA(img.width, img.height, img.imageData.bytes[], imageFlags);
      }
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
  /// Returns handle to the image or 0 on error.
  public int createImageFromMemoryImage (NVGContext ctx, MemoryImage img, int imageFlags=NVGImageFlags.None) {
    if (img is null) return 0;
    if (auto tc = cast(TrueColorImage)img) {
      return ctx.createImageRGBA(tc.width, tc.height, tc.imageData.bytes[], imageFlags);
    } else {
      auto tc = img.getAsTrueColorImage;
      scope(exit) delete tc;
      return ctx.createImageRGBA(tc.width, tc.height, tc.imageData.bytes[], imageFlags);
    }
  }
} else {
  /// Creates image by loading it from the specified chunk of memory.
  /// Returns handle to the image or 0 on error.
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
/// Returns handle to the image or 0 on error.
public int createImageRGBA (NVGContext ctx, int w, int h, const(void)[] data, int imageFlags=NVGImageFlags.None) nothrow @trusted @nogc {
  if (w < 1 || h < 1 || data.length < w*h*4) return 0;
  return ctx.params.renderCreateTexture(ctx.params.userPtr, NVGtexture.RGBA, w, h, imageFlags, cast(const(ubyte)*)data.ptr);
}

/// Updates image data specified by image handle.
public void updateImage (NVGContext ctx, int image, const(void)[] data) nothrow @trusted @nogc {
  if (image > 0) {
    int w, h;
    ctx.params.renderGetTextureSize(ctx.params.userPtr, image, &w, &h);
    ctx.params.renderUpdateTexture(ctx.params.userPtr, image, 0, 0, w, h, cast(const(ubyte)*)data.ptr);
  }
}

/// Returns the dimensions of a created image.
public void imageSize (NVGContext ctx, int image, out int w, out int h) nothrow @trusted @nogc {
  if (image > 0) ctx.params.renderGetTextureSize(ctx.params.userPtr, image, &w, &h);
}

/// Deletes created image.
public void deleteImage (NVGContext ctx, int image) nothrow @trusted @nogc {
  if (ctx is null || image < 0) return;
  ctx.params.renderDeleteTexture(ctx.params.userPtr, image);
}


// ////////////////////////////////////////////////////////////////////////// //
/// <h1>Paints</h1>
//
/** NanoVega supports four types of paints: linear gradient, box gradient, radial gradient and image pattern.
 * These can be used as paints for strokes and fills.
 */
public alias NVGSectionDummy05 = void;

/** Creates and returns a linear gradient. Parameters `(sx, sy) (ex, ey)` specify the start and end coordinates
 * of the linear gradient, icol specifies the start color and ocol the end color.
 * The gradient is transformed by the current transform when it is passed to `fillPaint()` or `strokePaint()`.
 */
public NVGPaint linearGradient (NVGContext ctx, float sx, float sy, float ex, float ey, NVGColor icol, NVGColor ocol) nothrow @trusted @nogc {
  enum large = 1e5f;

  NVGPaint p = void;
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

  p.feather = nvg__max(NVG_MIN_FEATHER, d);

  p.innerColor = icol;
  p.outerColor = ocol;

  return p;
}

/** Creates and returns a radial gradient. Parameters (cx, cy) specify the center, inr and outr specify
 * the inner and outer radius of the gradient, icol specifies the start color and ocol the end color.
 * The gradient is transformed by the current transform when it is passed to `fillPaint()` or `strokePaint()`.
 */
public NVGPaint radialGradient (NVGContext ctx, float cx, float cy, float inr, float outr, NVGColor icol, NVGColor ocol) nothrow @trusted @nogc {
  immutable float r = (inr+outr)*0.5f;
  immutable float f = (outr-inr);

  NVGPaint p = void;
  memset(&p, 0, p.sizeof);

  nvgTransformIdentity(p.xform[]);
  p.xform.ptr[4] = cx;
  p.xform.ptr[5] = cy;

  p.extent[0] = r;
  p.extent[1] = r;

  p.radius = r;

  p.feather = nvg__max(NVG_MIN_FEATHER, f);

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
public NVGPaint boxGradient (NVGContext ctx, float x, float y, float w, float h, float r, float f, NVGColor icol, NVGColor ocol) nothrow @trusted @nogc {
  NVGPaint p = void;
  memset(&p, 0, p.sizeof);

  nvgTransformIdentity(p.xform[]);
  p.xform.ptr[4] = x+w*0.5f;
  p.xform.ptr[5] = y+h*0.5f;

  p.extent[0] = w*0.5f;
  p.extent[1] = h*0.5f;

  p.radius = r;

  p.feather = nvg__max(NVG_MIN_FEATHER, f);

  p.innerColor = icol;
  p.outerColor = ocol;

  return p;
}

/** Creates and returns an image pattern. Parameters `(cx, cy)` specify the left-top location of the image pattern,
 * `(w, h)` the size of one image, `angle` rotation around the top-left corner, `image` is handle to the image to render.
 * The gradient is transformed by the current transform when it is passed to `fillPaint()` or `strokePaint()`.
 */
public NVGPaint imagePattern (NVGContext ctx, float cx, float cy, float w, float h, float angle, int image, float alpha=1) nothrow @trusted @nogc {
  NVGPaint p = void;
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

public alias NVGLGS = NVGLGSdata*; ///

private struct NVGLGSdata {
  int imgid; // 0: invalid
  // `imagePattern()` arguments
  float cx, cy, w, h, angle;

  @disable this (this); // no copies
  public @property bool valid () const pure nothrow @safe @nogc => (imgid > 0); ///
}

/// Destroy linear gradient with stops
public void kill (NVGContext ctx, ref NVGLGS lgs) nothrow @trusted @nogc {
  if (lgs is null) return;
  if (lgs.imgid > 0) { ctx.deleteImage(lgs.imgid); lgs.imgid = 0; }
  free(lgs);
  lgs = null;
}

/** Sets linear gradient with stops, created with `createLinearGradientWithStops()`.
 * The gradient is transformed by the current transform when it is passed to `fillPaint()` or `strokePaint()`.
 */
public NVGPaint linearGradient (NVGContext ctx, NVGLGS lgs) nothrow @trusted @nogc {
  if (lgs is null || !lgs.valid) {
    NVGPaint p = void;
    memset(&p, 0, p.sizeof);
    nvg__setPaintColor(p, NVGColor.red);
    return p;
  } else {
    return ctx.imagePattern(lgs.cx, lgs.cy, lgs.w, lgs.h, lgs.angle, lgs.imgid);
  }
}

///
public struct NVGGradientStop {
  float offset; /// [0..1]
  NVGColor color; ///
}

/// Create linear gradient data suitable to use with `linearGradient(res)`.
/// Don't forget to destroy the result when you don't need it anymore with `ctx.kill(res);`.
public NVGLGS createLinearGradientWithStops (NVGContext ctx, float sx, float sy, float ex, float ey, const(NVGGradientStop)[] stops) nothrow @trusted @nogc {
  // based on the code by Jorge Acereda <jacereda@gmail.com>
  enum NVG_GRADIENT_SAMPLES = 1024;
  static void gradientSpan (uint* dst, const(NVGGradientStop)* s0, const(NVGGradientStop)* s1) nothrow @trusted @nogc {
    float s0o = nvg__clamp(s0.offset, 0.0f, 1.0f);
    float s1o = nvg__clamp(s1.offset, 0.0f, 1.0f);
    uint s = cast(uint)(s0o*NVG_GRADIENT_SAMPLES);
    uint e = cast(uint)(s1o*NVG_GRADIENT_SAMPLES);
    uint sc = 0xffffffffU;
    uint sh = 24;
    uint r = cast(uint)(s0.color.rgba[0]*sc);
    uint g = cast(uint)(s0.color.rgba[1]*sc);
    uint b = cast(uint)(s0.color.rgba[2]*sc);
    uint a = cast(uint)(s0.color.rgba[3]*sc);
    uint dr = cast(uint)((s1.color.rgba[0]*sc-r)/(e-s));
    uint dg = cast(uint)((s1.color.rgba[1]*sc-g)/(e-s));
    uint db = cast(uint)((s1.color.rgba[2]*sc-b)/(e-s));
    uint da = cast(uint)((s1.color.rgba[3]*sc-a)/(e-s));
    for (uint i = s; i < e; ++i) {
      version(BigEndian) {
        dst[i] = ((r>>sh)<<24)+((g>>sh)<<16)+((b>>sh)<<8)+((a>>sh)<<0);
      } else {
        dst[i] = ((a>>sh)<<24)+((b>>sh)<<16)+((g>>sh)<<8)+((r>>sh)<<0);
      }
      r += dr;
      g += dg;
      b += db;
      a += da;
    }
  }

  uint[NVG_GRADIENT_SAMPLES] data = void;
  float w = ex-sx;
  float h = ey-sy;
  float len = nvg__sqrtf(w*w + h*h);
  auto s0 = NVGGradientStop(0, nvgRGBAf(0, 0, 0, 1));
  auto s1 = NVGGradientStop(1, nvgRGBAf(1, 1, 1, 1));
  int img;
  if (stops.length > 64) stops = stops[0..64];
  if (stops.length) {
    s0.color = stops[0].color;
    s1.color = stops[$-1].color;
  }
  gradientSpan(data.ptr, &s0, (stops.length ? stops.ptr : &s1));
  if (stops.length) {
    foreach (immutable i; 0..stops.length-1) gradientSpan(data.ptr, stops.ptr+i, stops.ptr+i+1);
  }
  gradientSpan(data.ptr, (stops.length ? stops.ptr+stops.length-1 : &s0), &s1);
  img = ctx.createImageRGBA(NVG_GRADIENT_SAMPLES, 1, data[], NVGImageFlags.RepeatX|NVGImageFlags.RepeatY);
  if (img <= 0) return null;
  // allocate data
  NVGLGS res = cast(NVGLGS)malloc((*NVGLGS).sizeof);
  if (res is null) { ctx.deleteImage(img); return null; }
  // fill result
  res.imgid = img;
  res.cx = sx;
  res.cy = sy;
  res.w = len;
  res.h = len;
  res.angle = nvg__atan2f(ey-sy, ex-sx);
  return res;
}


// ////////////////////////////////////////////////////////////////////////// //
/// <h1>Scissoring</h1>
//
/** Scissoring allows you to clip the rendering into a rectangle. This is useful for various
 * user interface cases like rendering a text edit or a timeline.
 */
public alias NVGSectionDummy06 = void;

/// Sets the current scissor rectangle. The scissor rectangle is transformed by the current transform.
public void scissor (NVGContext ctx, float x, float y, float w, float h) nothrow @trusted @nogc {
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

void nvg__isectRects (float* dst, float ax, float ay, float aw, float ah, float bx, float by, float bw, float bh) nothrow @trusted @nogc {
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
public void intersectScissor (NVGContext ctx, float x, float y, float w, float h) nothrow @trusted @nogc {
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
public void resetScissor (NVGContext ctx) nothrow @trusted @nogc {
  NVGstate* state = nvg__getState(ctx);
  state.scissor.xform[] = 0;
  state.scissor.extent[] = -1.0f;
}


// ////////////////////////////////////////////////////////////////////////// //
int nvg__ptEquals (float x1, float y1, float x2, float y2, float tol) pure nothrow @safe @nogc {
  //pragma(inline, true);
  immutable float dx = x2-x1;
  immutable float dy = y2-y1;
  return dx*dx+dy*dy < tol*tol;
}

float nvg__distPtSeg (float x, float y, float px, float py, float qx, float qy) pure nothrow @safe @nogc {
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

void nvg__appendCommands (NVGContext ctx, const(float)[] vals...) nothrow @trusted @nogc {
  int nvals = cast(int)vals.length;
  assert(nvals != 0);

  NVGstate* state = nvg__getState(ctx);

  if (ctx.ncommands+nvals > ctx.ccommands) {
    //int ccommands = ctx.ncommands+nvals+ctx.ccommands/2;
    int ccommands = ((ctx.ncommands+nvals)|0xfff)+1;
    float* commands = cast(float*)realloc(ctx.commands, float.sizeof*ccommands);
    if (commands is null) assert(0, "NanoVega: out of memory");
    ctx.commands = commands;
    ctx.ccommands = ccommands;
    assert(ctx.ncommands+nvals <= ctx.ccommands);
  }

  if (cast(int)vals.ptr[0] != Command.Close && cast(int)vals.ptr[0] != Command.Winding) {
    assert(nvals >= 3);
    ctx.commandx = vals.ptr[nvals-2];
    ctx.commandy = vals.ptr[nvals-1];
  }

  // copy commands
  float* vp = ctx.commands+ctx.ncommands;
  memcpy(vp, vals.ptr, nvals*float.sizeof);
  ctx.ncommands += nvals;

  // transform commands
  int i = nvals;
  while (i > 0) {
    int nlen = 1;
    final switch (cast(Command)(*vp)) {
      case Command.MoveTo:
      case Command.LineTo:
        assert(i >= 3);
        nvgTransformPoint(vp+1, vp+2, state.xform[], vp[1], vp[2]);
        nlen = 3;
        break;
      case Command.BezierTo:
        assert(i >= 7);
        nvgTransformPoint(vp+1, vp+2, state.xform[], vp[1], vp[2]);
        nvgTransformPoint(vp+3, vp+4, state.xform[], vp[3], vp[4]);
        nvgTransformPoint(vp+5, vp+6, state.xform[], vp[5], vp[6]);
        nlen = 7;
        break;
      case Command.Close:
        nlen = 1;
        break;
      case Command.Winding:
        nlen = 2;
        break;
    }
    assert(nlen > 0 && nlen <= i);
    i -= nlen;
    vp += nlen;
  }
}

void nvg__clearPathCache (NVGContext ctx) nothrow @trusted @nogc {
  ctx.cache.npoints = 0;
  ctx.cache.npaths = 0;
}

NVGpath* nvg__lastPath (NVGContext ctx) nothrow @trusted @nogc {
  return (ctx.cache.npaths > 0 ? &ctx.cache.paths[ctx.cache.npaths-1] : null);
}

void nvg__addPath (NVGContext ctx) nothrow @trusted @nogc {
  if (ctx.cache.npaths+1 > ctx.cache.cpaths) {
    int cpaths = ctx.cache.npaths+1+ctx.cache.cpaths/2;
    NVGpath* paths = cast(NVGpath*)realloc(ctx.cache.paths, NVGpath.sizeof*cpaths);
    if (paths is null) return;
    ctx.cache.paths = paths;
    ctx.cache.cpaths = cpaths;
  }

  NVGpath* path = &ctx.cache.paths[ctx.cache.npaths];
  memset(path, 0, (*path).sizeof);
  path.first = ctx.cache.npoints;
  path.winding = NVGWinding.CCW;

  ++ctx.cache.npaths;
}

NVGpoint* nvg__lastPoint (NVGContext ctx) nothrow @trusted @nogc {
  return (ctx.cache.npoints > 0 ? &ctx.cache.points[ctx.cache.npoints-1] : null);
}

void nvg__addPoint (NVGContext ctx, float x, float y, int flags) nothrow @trusted @nogc {
  NVGpath* path = nvg__lastPath(ctx);
  if (path is null) return;

  if (path.count > 0 && ctx.cache.npoints > 0) {
    NVGpoint* pt = nvg__lastPoint(ctx);
    if (nvg__ptEquals(pt.x, pt.y, x, y, ctx.distTol)) {
      pt.flags |= flags;
      return;
    }
  }

  if (ctx.cache.npoints+1 > ctx.cache.cpoints) {
    int cpoints = ctx.cache.npoints+1+ctx.cache.cpoints/2;
    NVGpoint* points = cast(NVGpoint*)realloc(ctx.cache.points, NVGpoint.sizeof*cpoints);
    if (points is null) return;
    ctx.cache.points = points;
    ctx.cache.cpoints = cpoints;
  }

  NVGpoint* pt = &ctx.cache.points[ctx.cache.npoints];
  memset(pt, 0, (*pt).sizeof);
  pt.x = x;
  pt.y = y;
  pt.flags = cast(ubyte)flags;

  ++ctx.cache.npoints;
  ++path.count;
}

void nvg__closePath (NVGContext ctx) nothrow @trusted @nogc {
  NVGpath* path = nvg__lastPath(ctx);
  if (path is null) return;
  path.closed = 1;
}

void nvg__pathWinding (NVGContext ctx, NVGWinding winding) nothrow @trusted @nogc {
  NVGpath* path = nvg__lastPath(ctx);
  if (path is null) return;
  path.winding = winding;
}

float nvg__getAverageScale (float[] t) nothrow @trusted @nogc {
  assert(t.length >= 6);
  immutable float sx = nvg__sqrtf(t.ptr[0]*t.ptr[0]+t.ptr[2]*t.ptr[2]);
  immutable float sy = nvg__sqrtf(t.ptr[1]*t.ptr[1]+t.ptr[3]*t.ptr[3]);
  return (sx+sy)*0.5f;
}

NVGvertex* nvg__allocTempVerts (NVGContext ctx, int nverts) nothrow @trusted @nogc {
  if (nverts > ctx.cache.cverts) {
    int cverts = (nverts+0xff)&~0xff; // Round up to prevent allocations when things change just slightly.
    NVGvertex* verts = cast(NVGvertex*)realloc(ctx.cache.verts, NVGvertex.sizeof*cverts);
    if (verts is null) return null;
    ctx.cache.verts = verts;
    ctx.cache.cverts = cverts;
  }

  return ctx.cache.verts;
}

float nvg__triarea2 (float ax, float ay, float bx, float by, float cx, float cy) pure nothrow @safe @nogc {
  immutable float abx = bx-ax;
  immutable float aby = by-ay;
  immutable float acx = cx-ax;
  immutable float acy = cy-ay;
  return acx*aby-abx*acy;
}

float nvg__polyArea (NVGpoint* pts, int npts) nothrow @trusted @nogc {
  float area = 0;
  foreach (int i; 2..npts) {
    NVGpoint* a = &pts[0];
    NVGpoint* b = &pts[i-1];
    NVGpoint* c = &pts[i];
    area += nvg__triarea2(a.x, a.y, b.x, b.y, c.x, c.y);
  }
  return area*0.5f;
}

void nvg__polyReverse (NVGpoint* pts, int npts) nothrow @trusted @nogc {
  NVGpoint tmp = void;
  int i = 0, j = npts-1;
  while (i < j) {
    tmp = pts[i];
    pts[i] = pts[j];
    pts[j] = tmp;
    ++i;
    --j;
  }
}

void nvg__vset (NVGvertex* vtx, float x, float y, float u, float v) nothrow @trusted @nogc {
  vtx.x = x;
  vtx.y = y;
  vtx.u = u;
  vtx.v = v;
}

void nvg__tesselateBezier (NVGContext ctx, in float x1, in float y1, in float x2, in float y2, in float x3, in float y3, in float x4, in float y4, in int level, in int type) nothrow @trusted @nogc {
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

void nvg__flattenPaths (NVGContext ctx) nothrow @trusted @nogc {
  NVGpathCache* cache = ctx.cache;
  NVGpoint* last;
  NVGpoint* p0;
  NVGpoint* p1;
  NVGpoint* pts;
  NVGpath* path;
  float* cp1;
  float* cp2;
  float* p;

  if (cache.npaths > 0) return;

  // flatten
  int i = 0;
  while (i < ctx.ncommands) {
    final switch (cast(Command)ctx.commands[i]) {
      case Command.MoveTo:
        assert(i+3 <= ctx.ncommands);
        nvg__addPath(ctx);
        p = &ctx.commands[i+1];
        nvg__addPoint(ctx, p[0], p[1], PointFlag.Corner);
        i += 3;
        break;
      case Command.LineTo:
        assert(i+3 <= ctx.ncommands);
        p = &ctx.commands[i+1];
        nvg__addPoint(ctx, p[0], p[1], PointFlag.Corner);
        i += 3;
        break;
      case Command.BezierTo:
        assert(i+7 <= ctx.ncommands);
        last = nvg__lastPoint(ctx);
        if (last !is null) {
          cp1 = &ctx.commands[i+1];
          cp2 = &ctx.commands[i+3];
          p = &ctx.commands[i+5];
          nvg__tesselateBezier(ctx, last.x, last.y, cp1[0], cp1[1], cp2[0], cp2[1], p[0], p[1], 0, PointFlag.Corner);
        }
        i += 7;
        break;
      case Command.Close:
        assert(i+1 <= ctx.ncommands);
        nvg__closePath(ctx);
        ++i;
        break;
      case Command.Winding:
        assert(i+2 <= ctx.ncommands);
        nvg__pathWinding(ctx, cast(NVGWinding)ctx.commands[i+1]);
        i += 2;
        break;
    }
  }

  cache.bounds.ptr[0] = cache.bounds.ptr[1] = 1e6f;
  cache.bounds.ptr[2] = cache.bounds.ptr[3] = -1e6f;

  // calculate the direction and length of line segments
  foreach (int j; 0..cache.npaths) {
    path = &cache.paths[j];
    pts = &cache.points[path.first];

    // if the first and last points are the same, remove the last, mark as closed path
    p0 = &pts[path.count-1];
    p1 = &pts[0];
    if (nvg__ptEquals(p0.x, p0.y, p1.x, p1.y, ctx.distTol)) {
      --path.count;
      p0 = &pts[path.count-1];
      path.closed = 1;
    }

    // enforce winding
    if (path.count > 2) {
      immutable float area = nvg__polyArea(pts, path.count);
      if (path.winding == NVGWinding.CCW && area < 0.0f) nvg__polyReverse(pts, path.count);
      if (path.winding == NVGWinding.CW && area > 0.0f) nvg__polyReverse(pts, path.count);
    }

    foreach (; 0..path.count) {
      // calculate segment direction and length
      p0.dx = p1.x-p0.x;
      p0.dy = p1.y-p0.y;
      p0.len = nvg__normalize(&p0.dx, &p0.dy);
      // update bounds
      cache.bounds.ptr[0] = nvg__min(cache.bounds.ptr[0], p0.x);
      cache.bounds.ptr[1] = nvg__min(cache.bounds.ptr[1], p0.y);
      cache.bounds.ptr[2] = nvg__max(cache.bounds.ptr[2], p0.x);
      cache.bounds.ptr[3] = nvg__max(cache.bounds.ptr[3], p0.y);
      // advance
      p0 = p1++;
    }
  }
}

int nvg__curveDivs (float r, float arc, float tol) nothrow @trusted @nogc {
  immutable float da = nvg__acosf(r/(r+tol))*2.0f;
  return nvg__max(2, cast(int)nvg__ceilf(arc/da));
}

void nvg__chooseBevel (int bevel, NVGpoint* p0, NVGpoint* p1, float w, float* x0, float* y0, float* x1, float* y1) nothrow @trusted @nogc {
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

NVGvertex* nvg__roundJoin (NVGvertex* dst, NVGpoint* p0, NVGpoint* p1, float lw, float rw, float lu, float ru, int ncap, float fringe) nothrow @trusted @nogc {
  float dlx0 = p0.dy;
  float dly0 = -p0.dx;
  float dlx1 = p1.dy;
  float dly1 = -p1.dx;
  //NVG_NOTUSED(fringe);

  if (p1.flags&PointFlag.Left) {
    float lx0 = void, ly0 = void, lx1 = void, ly1 = void;
    nvg__chooseBevel(p1.flags&PointFlag.InnerBevelPR, p0, p1, lw, &lx0, &ly0, &lx1, &ly1);
    immutable float a0 = nvg__atan2f(-dly0, -dlx0);
    float a1 = nvg__atan2f(-dly1, -dlx1);
    if (a1 > a0) a1 -= NVG_PI*2;

    nvg__vset(dst, lx0, ly0, lu, 1); ++dst;
    nvg__vset(dst, p1.x-dlx0*rw, p1.y-dly0*rw, ru, 1); ++dst;

    int n = nvg__clamp(cast(int)nvg__ceilf(((a0-a1)/NVG_PI)*ncap), 2, ncap);
    for (int i = 0; i < n; ++i) {
      float u = i/cast(float)(n-1);
      float a = a0+u*(a1-a0);
      float rx = p1.x+nvg__cosf(a)*rw;
      float ry = p1.y+nvg__sinf(a)*rw;
      nvg__vset(dst, p1.x, p1.y, 0.5f, 1); ++dst;
      nvg__vset(dst, rx, ry, ru, 1); ++dst;
    }

    nvg__vset(dst, lx1, ly1, lu, 1); ++dst;
    nvg__vset(dst, p1.x-dlx1*rw, p1.y-dly1*rw, ru, 1); ++dst;

  } else {
    float rx0 = void, ry0 = void, rx1 = void, ry1 = void;
    nvg__chooseBevel(p1.flags&PointFlag.InnerBevelPR, p0, p1, -rw, &rx0, &ry0, &rx1, &ry1);
    immutable float a0 = nvg__atan2f(dly0, dlx0);
    float a1 = nvg__atan2f(dly1, dlx1);
    if (a1 < a0) a1 += NVG_PI*2;

    nvg__vset(dst, p1.x+dlx0*rw, p1.y+dly0*rw, lu, 1); ++dst;
    nvg__vset(dst, rx0, ry0, ru, 1); ++dst;

    int n = nvg__clamp(cast(int)nvg__ceilf(((a1-a0)/NVG_PI)*ncap), 2, ncap);
    for (int i = 0; i < n; i++) {
      float u = i/cast(float)(n-1);
      float a = a0+u*(a1-a0);
      float lx = p1.x+nvg__cosf(a)*lw;
      float ly = p1.y+nvg__sinf(a)*lw;
      nvg__vset(dst, lx, ly, lu, 1); ++dst;
      nvg__vset(dst, p1.x, p1.y, 0.5f, 1); ++dst;
    }

    nvg__vset(dst, p1.x+dlx1*rw, p1.y+dly1*rw, lu, 1); ++dst;
    nvg__vset(dst, rx1, ry1, ru, 1); ++dst;

  }
  return dst;
}

NVGvertex* nvg__bevelJoin (NVGvertex* dst, NVGpoint* p0, NVGpoint* p1, float lw, float rw, float lu, float ru, float fringe) nothrow @trusted @nogc {
  float rx0, ry0, rx1, ry1;
  float lx0, ly0, lx1, ly1;
  float dlx0 = p0.dy;
  float dly0 = -p0.dx;
  float dlx1 = p1.dy;
  float dly1 = -p1.dx;
  //NVG_NOTUSED(fringe);

  if (p1.flags&PointFlag.Left) {
    nvg__chooseBevel(p1.flags&PointFlag.InnerBevelPR, p0, p1, lw, &lx0, &ly0, &lx1, &ly1);

    nvg__vset(dst, lx0, ly0, lu, 1); ++dst;
    nvg__vset(dst, p1.x-dlx0*rw, p1.y-dly0*rw, ru, 1); ++dst;

    if (p1.flags&PointFlag.Bevel) {
      nvg__vset(dst, lx0, ly0, lu, 1); ++dst;
      nvg__vset(dst, p1.x-dlx0*rw, p1.y-dly0*rw, ru, 1); ++dst;

      nvg__vset(dst, lx1, ly1, lu, 1); ++dst;
      nvg__vset(dst, p1.x-dlx1*rw, p1.y-dly1*rw, ru, 1); ++dst;
    } else {
      rx0 = p1.x-p1.dmx*rw;
      ry0 = p1.y-p1.dmy*rw;

      nvg__vset(dst, p1.x, p1.y, 0.5f, 1); ++dst;
      nvg__vset(dst, p1.x-dlx0*rw, p1.y-dly0*rw, ru, 1); ++dst;

      nvg__vset(dst, rx0, ry0, ru, 1); ++dst;
      nvg__vset(dst, rx0, ry0, ru, 1); ++dst;

      nvg__vset(dst, p1.x, p1.y, 0.5f, 1); ++dst;
      nvg__vset(dst, p1.x-dlx1*rw, p1.y-dly1*rw, ru, 1); ++dst;
    }

    nvg__vset(dst, lx1, ly1, lu, 1); ++dst;
    nvg__vset(dst, p1.x-dlx1*rw, p1.y-dly1*rw, ru, 1); ++dst;

  } else {
    nvg__chooseBevel(p1.flags&PointFlag.InnerBevelPR, p0, p1, -rw, &rx0, &ry0, &rx1, &ry1);

    nvg__vset(dst, p1.x+dlx0*lw, p1.y+dly0*lw, lu, 1); ++dst;
    nvg__vset(dst, rx0, ry0, ru, 1); ++dst;

    if (p1.flags&PointFlag.Bevel) {
      nvg__vset(dst, p1.x+dlx0*lw, p1.y+dly0*lw, lu, 1); ++dst;
      nvg__vset(dst, rx0, ry0, ru, 1); ++dst;

      nvg__vset(dst, p1.x+dlx1*lw, p1.y+dly1*lw, lu, 1); ++dst;
      nvg__vset(dst, rx1, ry1, ru, 1); ++dst;
    } else {
      lx0 = p1.x+p1.dmx*lw;
      ly0 = p1.y+p1.dmy*lw;

      nvg__vset(dst, p1.x+dlx0*lw, p1.y+dly0*lw, lu, 1); ++dst;
      nvg__vset(dst, p1.x, p1.y, 0.5f, 1); ++dst;

      nvg__vset(dst, lx0, ly0, lu, 1); ++dst;
      nvg__vset(dst, lx0, ly0, lu, 1); ++dst;

      nvg__vset(dst, p1.x+dlx1*lw, p1.y+dly1*lw, lu, 1); ++dst;
      nvg__vset(dst, p1.x, p1.y, 0.5f, 1); ++dst;
    }

    nvg__vset(dst, p1.x+dlx1*lw, p1.y+dly1*lw, lu, 1); ++dst;
    nvg__vset(dst, rx1, ry1, ru, 1); ++dst;
  }

  return dst;
}

NVGvertex* nvg__buttCapStart (NVGvertex* dst, NVGpoint* p, float dx, float dy, float w, float d, float aa) nothrow @trusted @nogc {
  immutable float px = p.x-dx*d;
  immutable float py = p.y-dy*d;
  immutable float dlx = dy;
  immutable float dly = -dx;
  nvg__vset(dst, px+dlx*w-dx*aa, py+dly*w-dy*aa, 0, 0); ++dst;
  nvg__vset(dst, px-dlx*w-dx*aa, py-dly*w-dy*aa, 1, 0); ++dst;
  nvg__vset(dst, px+dlx*w, py+dly*w, 0, 1); ++dst;
  nvg__vset(dst, px-dlx*w, py-dly*w, 1, 1); ++dst;
  return dst;
}

NVGvertex* nvg__buttCapEnd (NVGvertex* dst, NVGpoint* p, float dx, float dy, float w, float d, float aa) nothrow @trusted @nogc {
  immutable float px = p.x+dx*d;
  immutable float py = p.y+dy*d;
  immutable float dlx = dy;
  immutable float dly = -dx;
  nvg__vset(dst, px+dlx*w, py+dly*w, 0, 1); ++dst;
  nvg__vset(dst, px-dlx*w, py-dly*w, 1, 1); ++dst;
  nvg__vset(dst, px+dlx*w+dx*aa, py+dly*w+dy*aa, 0, 0); ++dst;
  nvg__vset(dst, px-dlx*w+dx*aa, py-dly*w+dy*aa, 1, 0); ++dst;
  return dst;
}

NVGvertex* nvg__roundCapStart (NVGvertex* dst, NVGpoint* p, float dx, float dy, float w, int ncap, float aa) nothrow @trusted @nogc {
  immutable float px = p.x;
  immutable float py = p.y;
  immutable float dlx = dy;
  immutable float dly = -dx;
  //NVG_NOTUSED(aa);
  immutable float ncpf = cast(float)(ncap-1);
  foreach (int i; 0..ncap) {
    float a = i/*/cast(float)(ncap-1)*//ncpf*NVG_PI;
    float ax = nvg__cosf(a)*w, ay = nvg__sinf(a)*w;
    nvg__vset(dst, px-dlx*ax-dx*ay, py-dly*ax-dy*ay, 0, 1); ++dst;
    nvg__vset(dst, px, py, 0.5f, 1); ++dst;
  }
  nvg__vset(dst, px+dlx*w, py+dly*w, 0, 1); ++dst;
  nvg__vset(dst, px-dlx*w, py-dly*w, 1, 1); ++dst;
  return dst;
}

NVGvertex* nvg__roundCapEnd (NVGvertex* dst, NVGpoint* p, float dx, float dy, float w, int ncap, float aa) nothrow @trusted @nogc {
  immutable float px = p.x;
  immutable float py = p.y;
  immutable float dlx = dy;
  immutable float dly = -dx;
  //NVG_NOTUSED(aa);
  nvg__vset(dst, px+dlx*w, py+dly*w, 0, 1); ++dst;
  nvg__vset(dst, px-dlx*w, py-dly*w, 1, 1); ++dst;
  immutable float ncpf = cast(float)(ncap-1);
  foreach (int i; 0..ncap) {
    float a = i/*cast(float)(ncap-1)*//ncpf*NVG_PI;
    float ax = nvg__cosf(a)*w, ay = nvg__sinf(a)*w;
    nvg__vset(dst, px, py, 0.5f, 1); ++dst;
    nvg__vset(dst, px-dlx*ax+dx*ay, py-dly*ax+dy*ay, 0, 1); ++dst;
  }
  return dst;
}

void nvg__calculateJoins (NVGContext ctx, float w, int lineJoin, float miterLimit) nothrow @trusted @nogc {
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
      //float dlx0, dly0, dlx1, dly1, dmr2, cross, limit;
      immutable float dlx0 = p0.dy;
      immutable float dly0 = -p0.dx;
      immutable float dlx1 = p1.dy;
      immutable float dly1 = -p1.dx;
      // Calculate extrusions
      p1.dmx = (dlx0+dlx1)*0.5f;
      p1.dmy = (dly0+dly1)*0.5f;
      immutable float dmr2 = p1.dmx*p1.dmx+p1.dmy*p1.dmy;
      if (dmr2 > 0.000001f) {
        float scale = 1.0f/dmr2;
        if (scale > 600.0f) {
          scale = 600.0f;
        }
        p1.dmx *= scale;
        p1.dmy *= scale;
      }

      // Clear flags, but keep the corner.
      p1.flags = (p1.flags&PointFlag.Corner) ? PointFlag.Corner : 0;

      // Keep track of left turns.
      immutable float cross = p1.dx*p0.dy-p0.dx*p1.dy;
      if (cross > 0.0f) {
        nleft++;
        p1.flags |= PointFlag.Left;
      }

      // Calculate if we should use bevel or miter for inner join.
      immutable float limit = nvg__max(1.01f, nvg__min(p0.len, p1.len)*iw);
      if ((dmr2*limit*limit) < 1.0f) p1.flags |= PointFlag.InnerBevelPR;

      // Check to see if the corner needs to be beveled.
      if (p1.flags&PointFlag.Corner) {
        if ((dmr2*miterLimit*miterLimit) < 1.0f || lineJoin == NVGLineCap.Bevel || lineJoin == NVGLineCap.Round) {
          p1.flags |= PointFlag.Bevel;
        }
      }

      if ((p1.flags&(PointFlag.Bevel|PointFlag.InnerBevelPR)) != 0) path.nbevel++;

      p0 = p1++;
    }

    path.convex = (nleft == path.count) ? 1 : 0;
  }
}

int nvg__expandStroke (NVGContext ctx, float w, int lineCap, int lineJoin, float miterLimit) nothrow @trusted @nogc {
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
      if ((p1.flags&(PointFlag.Bevel|PointFlag.InnerBevelPR)) != 0) {
        if (lineJoin == NVGLineCap.Round) {
          dst = nvg__roundJoin(dst, p0, p1, w, w, 0, 1, ncap, aa);
        } else {
          dst = nvg__bevelJoin(dst, p0, p1, w, w, 0, 1, aa);
        }
      } else {
        nvg__vset(dst, p1.x+(p1.dmx*w), p1.y+(p1.dmy*w), 0, 1); ++dst;
        nvg__vset(dst, p1.x-(p1.dmx*w), p1.y-(p1.dmy*w), 1, 1); ++dst;
      }
      p0 = p1++;
    }

    if (loop) {
      // Loop it
      nvg__vset(dst, verts[0].x, verts[0].y, 0, 1); ++dst;
      nvg__vset(dst, verts[1].x, verts[1].y, 1, 1); ++dst;
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

bool nvg__expandFill (NVGContext ctx, float w, int lineJoin, float miterLimit) nothrow @trusted @nogc {
  NVGpathCache* cache = ctx.cache;
  NVGvertex* verts;
  NVGvertex* dst;
  float aa = ctx.fringeWidth;
  int fringe = w > 0.0f;

  nvg__calculateJoins(ctx, w, lineJoin, miterLimit);

  // Calculate max vertex usage.
  int cverts = 0;
  foreach (int i; 0..cache.npaths) {
    NVGpath* path = &cache.paths[i];
    cverts += path.count+path.nbevel+1;
    if (fringe) cverts += (path.count+path.nbevel*5+1)*2; // plus one for loop
  }

  verts = nvg__allocTempVerts(ctx, cverts);
  if (verts is null) return false;

  bool convex = (cache.npaths == 1 && cache.paths[0].convex);

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
        if (p1.flags&PointFlag.Bevel) {
          float dlx0 = p0.dy;
          float dly0 = -p0.dx;
          float dlx1 = p1.dy;
          float dly1 = -p1.dx;
          if (p1.flags&PointFlag.Left) {
            float lx = p1.x+p1.dmx*woff;
            float ly = p1.y+p1.dmy*woff;
            nvg__vset(dst, lx, ly, 0.5f, 1); ++dst;
          } else {
            float lx0 = p1.x+dlx0*woff;
            float ly0 = p1.y+dly0*woff;
            float lx1 = p1.x+dlx1*woff;
            float ly1 = p1.y+dly1*woff;
            nvg__vset(dst, lx0, ly0, 0.5f, 1); ++dst;
            nvg__vset(dst, lx1, ly1, 0.5f, 1); ++dst;
          }
        } else {
          nvg__vset(dst, p1.x+(p1.dmx*woff), p1.y+(p1.dmy*woff), 0.5f, 1); ++dst;
        }
        p0 = p1++;
      }
    } else {
      foreach (int j; 0..path.count) {
        nvg__vset(dst, pts[j].x, pts[j].y, 0.5f, 1);
        ++dst;
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
        if ((p1.flags&(PointFlag.Bevel|PointFlag.InnerBevelPR)) != 0) {
          dst = nvg__bevelJoin(dst, p0, p1, lw, rw, lu, ru, ctx.fringeWidth);
        } else {
          nvg__vset(dst, p1.x+(p1.dmx*lw), p1.y+(p1.dmy*lw), lu, 1); ++dst;
          nvg__vset(dst, p1.x-(p1.dmx*rw), p1.y-(p1.dmy*rw), ru, 1); ++dst;
        }
        p0 = p1++;
      }

      // Loop it
      nvg__vset(dst, verts[0].x, verts[0].y, lu, 1); ++dst;
      nvg__vset(dst, verts[1].x, verts[1].y, ru, 1); ++dst;

      path.nstroke = cast(int)(dst-verts);
      verts = dst;
    } else {
      path.stroke = null;
      path.nstroke = 0;
    }
  }

  return true;
}


// ////////////////////////////////////////////////////////////////////////// //
/// <h1>Paths</h1>
//
/** Drawing a new shape starts with `beginPath()`, it clears all the currently defined paths.
 * Then you define one or more paths and sub-paths which describe the shape. The are functions
 * to draw common shapes like rectangles and circles, and lower level step-by-step functions,
 * which allow to define a path curve by curve.
 *
 * NanoVega uses even-odd fill rule to draw the shapes. Solid shapes should have counter clockwise
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
/// Will call `nvgOnBeginPath()` callback if current path is not empty.
public void beginPath (NVGContext ctx) nothrow @trusted @nogc {
  ctx.ncommands = 0;
  ctx.pathPickRegistered &= NVGPickKind.All; // reset "registered" flags
  nvg__clearPathCache(ctx);
}

public alias newPath = beginPath; /// Ditto.

/// Starts new sub-path with specified point as first point.
public void moveTo (NVGContext ctx, in float x, in float y) nothrow @trusted @nogc {
  nvg__appendCommands(ctx, Command.MoveTo, x, y);
}

/// Adds line segment from the last point in the path to the specified point.
public void lineTo (NVGContext ctx, in float x, in float y) nothrow @trusted @nogc {
  nvg__appendCommands(ctx, Command.LineTo, x, y);
}

/// Adds cubic bezier segment from last point in the path via two control points to the specified point.
public void bezierTo (NVGContext ctx, in float c1x, in float c1y, in float c2x, in float c2y, in float x, in float y) nothrow @trusted @nogc {
  nvg__appendCommands(ctx, Command.BezierTo, c1x, c1y, c2x, c2y, x, y);
}

/// Adds quadratic bezier segment from last point in the path via a control point to the specified point.
public void quadTo (NVGContext ctx, in float cx, in float cy, in float x, in float y) nothrow @trusted @nogc {
  immutable float x0 = ctx.commandx;
  immutable float y0 = ctx.commandy;
  nvg__appendCommands(ctx,
    Command.BezierTo,
    x0+2.0f/3.0f*(cx-x0), y0+2.0f/3.0f*(cy-y0),
    x+2.0f/3.0f*(cx-x), y+2.0f/3.0f*(cy-y),
    x, y,
  );
}

/// Adds an arc segment at the corner defined by the last path point, and two specified points.
public void arcTo (NVGContext ctx, in float x1, in float y1, in float x2, in float y2, in float radius) nothrow @trusted @nogc {
  float x0 = ctx.commandx;
  float y0 = ctx.commandy;
  float cx, cy, a0, a1;
  NVGWinding dir;

  if (ctx.ncommands == 0) return;

  // Handle degenerate cases.
  if (nvg__ptEquals(x0, y0, x1, y1, ctx.distTol) ||
      nvg__ptEquals(x1, y1, x2, y2, ctx.distTol) ||
      nvg__distPtSeg(x1, y1, x0, y0, x2, y2) < ctx.distTol*ctx.distTol ||
      radius < ctx.distTol)
  {
    ctx.lineTo(x1, y1);
    return;
  }

  // Calculate tangential circle to lines (x0, y0)-(x1, y1) and (x1, y1)-(x2, y2).
  float dx0 = x0-x1;
  float dy0 = y0-y1;
  float dx1 = x2-x1;
  float dy1 = y2-y1;
  nvg__normalize(&dx0, &dy0);
  nvg__normalize(&dx1, &dy1);
  immutable float a = nvg__acosf(dx0*dx1+dy0*dy1);
  immutable float d = radius/nvg__tanf(a/2.0f);

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

  ctx.arc(cx, cy, radius, a0, a1, dir); // first is line
}

/// Closes current sub-path with a line segment.
public void closePath (NVGContext ctx) nothrow @trusted @nogc {
  nvg__appendCommands(ctx, Command.Close);
}

/// Sets the current sub-path winding, see NVGWinding and NVGSolidity.
public void pathWinding (NVGContext ctx, NVGWinding dir) nothrow @trusted @nogc {
  nvg__appendCommands(ctx, Command.Winding, cast(float)dir);
}

/// Ditto.
public void pathWinding (NVGContext ctx, NVGSolidity dir) nothrow @trusted @nogc {
  nvg__appendCommands(ctx, Command.Winding, cast(float)dir);
}

/** Creates new circle arc shaped sub-path. The arc center is at (cx, cy), the arc radius is r,
 * and the arc is drawn from angle a0 to a1, and swept in direction dir (NVGWinding.CCW, or NVGWinding.CW).
 * Angles are specified in radians.
 *
 * `mode` is: "original", "move", "line" -- first command will be like original NanoVega, MoveTo, or LineTo
 */
public void arc(string mode="original") (NVGContext ctx, in float cx, in float cy, in float r, in float a0, in float a1, NVGWinding dir) nothrow @trusted @nogc {
  static assert(mode == "original" || mode == "move" || mode == "line");
  float[3+5*7+100] vals = void;
  //int move = (ctx.ncommands > 0 ? Command.LineTo : Command.MoveTo);
  static if (mode == "original") {
    immutable int move = (ctx.ncommands > 0 ? Command.LineTo : Command.MoveTo);
  } else static if (mode == "move") {
    enum move = Command.MoveTo;
  } else static if (mode == "line") {
    enum move = Command.LineTo;
  } else {
    static assert(0, "wtf?!");
  }

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
      if (vals.length-nvals < 3) {
        // flush
        nvg__appendCommands(ctx, vals.ptr[0..nvals]);
        nvals = 0;
      }
      vals.ptr[nvals++] = cast(float)move;
      vals.ptr[nvals++] = x;
      vals.ptr[nvals++] = y;
    } else {
      if (vals.length-nvals < 7) {
        // flush
        nvg__appendCommands(ctx, vals.ptr[0..nvals]);
        nvals = 0;
      }
      vals.ptr[nvals++] = Command.BezierTo;
      vals.ptr[nvals++] = px+ptanx;
      vals.ptr[nvals++] = py+ptany;
      vals.ptr[nvals++] = x-tanx;
      vals.ptr[nvals++] = y-tany;
      vals.ptr[nvals++] = x;
      vals.ptr[nvals++] = y;
    }
    px = x;
    py = y;
    ptanx = tanx;
    ptany = tany;
  }

  nvg__appendCommands(ctx, vals.ptr[0..nvals]);
}

/// Creates new rectangle shaped sub-path.
public void rect (NVGContext ctx, in float x, in float y, in float w, in float h) nothrow @trusted @nogc {
  nvg__appendCommands(ctx,
    Command.MoveTo, x, y,
    Command.LineTo, x, y+h,
    Command.LineTo, x+w, y+h,
    Command.LineTo, x+w, y,
    Command.Close,
  );
}

/// Creates new rounded rectangle shaped sub-path.
public void roundedRect (NVGContext ctx, in float x, in float y, in float w, in float h, in float r) nothrow @trusted @nogc {
  ctx.roundedRectVarying(x, y, w, h, r, r, r, r);
}

/// Creates new rounded rectangle shaped sub-path. Specify ellipse width and height to round corners according to it.
public void roundedRectEllipse (NVGContext ctx, in float x, in float y, in float w, in float h, in float rw, in float rh) nothrow @trusted @nogc {
  if (rw < 0.1f || rh < 0.1f) { rect(ctx, x, y, w, h); return; }
  nvg__appendCommands(ctx,
    Command.MoveTo, x+rw, y,
    Command.LineTo, x+w-rw, y,
    Command.BezierTo, x+w-rw*(1-NVG_KAPPA90), y, x+w, y+rh*(1-NVG_KAPPA90), x+w, y+rh,
    Command.LineTo, x+w, y+h-rh,
    Command.BezierTo, x+w, y+h-rh*(1-NVG_KAPPA90), x+w-rw*(1-NVG_KAPPA90), y+h, x+w-rw, y+h,
    Command.LineTo, x+rw, y+h,
    Command.BezierTo, x+rw*(1-NVG_KAPPA90), y+h, x, y+h-rh*(1-NVG_KAPPA90), x, y+h-rh,
    Command.LineTo, x, y+rh,
    Command.BezierTo, x, y+rh*(1-NVG_KAPPA90), x+rw*(1-NVG_KAPPA90), y, x+rw, y,
    Command.Close,
  );
}

/// Creates new rounded rectangle shaped sub-path. This one allows you to specify different rounding radii for each corner.
public void roundedRectVarying (NVGContext ctx, in float x, in float y, in float w, in float h, in float radTopLeft, in float radTopRight, in float radBottomRight, in float radBottomLeft) nothrow @trusted @nogc {
  if (radTopLeft < 0.1f && radTopRight < 0.1f && radBottomRight < 0.1f && radBottomLeft < 0.1f) {
    ctx.rect(x, y, w, h);
  } else {
    immutable float halfw = nvg__absf(w)*0.5f;
    immutable float halfh = nvg__absf(h)*0.5f;
    immutable float rxBL = nvg__min(radBottomLeft, halfw)*nvg__sign(w), ryBL = nvg__min(radBottomLeft, halfh)*nvg__sign(h);
    immutable float rxBR = nvg__min(radBottomRight, halfw)*nvg__sign(w), ryBR = nvg__min(radBottomRight, halfh)*nvg__sign(h);
    immutable float rxTR = nvg__min(radTopRight, halfw)*nvg__sign(w), ryTR = nvg__min(radTopRight, halfh)*nvg__sign(h);
    immutable float rxTL = nvg__min(radTopLeft, halfw)*nvg__sign(w), ryTL = nvg__min(radTopLeft, halfh)*nvg__sign(h);
    nvg__appendCommands(ctx,
      Command.MoveTo, x, y+ryTL,
      Command.LineTo, x, y+h-ryBL,
      Command.BezierTo, x, y+h-ryBL*(1-NVG_KAPPA90), x+rxBL*(1-NVG_KAPPA90), y+h, x+rxBL, y+h,
      Command.LineTo, x+w-rxBR, y+h,
      Command.BezierTo, x+w-rxBR*(1-NVG_KAPPA90), y+h, x+w, y+h-ryBR*(1-NVG_KAPPA90), x+w, y+h-ryBR,
      Command.LineTo, x+w, y+ryTR,
      Command.BezierTo, x+w, y+ryTR*(1-NVG_KAPPA90), x+w-rxTR*(1-NVG_KAPPA90), y, x+w-rxTR, y,
      Command.LineTo, x+rxTL, y,
      Command.BezierTo, x+rxTL*(1-NVG_KAPPA90), y, x, y+ryTL*(1-NVG_KAPPA90), x, y+ryTL,
      Command.Close,
    );
  }
}

/// Creates new ellipse shaped sub-path.
public void ellipse (NVGContext ctx, in float cx, in float cy, in float rx, in float ry) nothrow @trusted @nogc {
  nvg__appendCommands(ctx,
    Command.MoveTo, cx-rx, cy,
    Command.BezierTo, cx-rx, cy+ry*NVG_KAPPA90, cx-rx*NVG_KAPPA90, cy+ry, cx, cy+ry,
    Command.BezierTo, cx+rx*NVG_KAPPA90, cy+ry, cx+rx, cy+ry*NVG_KAPPA90, cx+rx, cy,
    Command.BezierTo, cx+rx, cy-ry*NVG_KAPPA90, cx+rx*NVG_KAPPA90, cy-ry, cx, cy-ry,
    Command.BezierTo, cx-rx*NVG_KAPPA90, cy-ry, cx-rx, cy-ry*NVG_KAPPA90, cx-rx, cy,
    Command.Close,
  );
}

/// Creates new circle shaped sub-path.
public void circle (NVGContext ctx, in float cx, in float cy, in float r) nothrow @trusted @nogc {
  ctx.ellipse(cx, cy, r, r);
}

/// Debug function to dump cached path data.
debug public void debugDumpPathCache (NVGContext ctx) nothrow @trusted @nogc {
  import core.stdc.stdio : printf;
  const(NVGpath)* path;
  printf("Dumping %d cached paths\n", ctx.cache.npaths);
  for (int i = 0; i < ctx.cache.npaths; ++i) {
    path = &ctx.cache.paths[i];
    printf("-Path %d\n", i);
    if (path.nfill) {
      printf("-fill: %d\n", path.nfill);
      for (int j = 0; j < path.nfill; ++j) printf("%f\t%f\n", path.fill[j].x, path.fill[j].y);
    }
    if (path.nstroke) {
      printf("-stroke: %d\n", path.nstroke);
      for (int j = 0; j < path.nstroke; ++j) printf("%f\t%f\n", path.stroke[j].x, path.stroke[j].y);
    }
  }
}

/// Fills the current path with current fill style.
public void fill (NVGContext ctx) nothrow @trusted @nogc {
  NVGstate* state = nvg__getState(ctx);
  const(NVGpath)* path;
  NVGPaint fillPaint = state.fill;

  if (ctx.pathPickId >= 0 && (ctx.pathPickRegistered&(NVGPickKind.Fill|(NVGPickKind.Fill<<16))) == NVGPickKind.Fill) {
    ctx.pathPickRegistered |= NVGPickKind.Fill<<16;
    ctx.currFillHitId = ctx.pathPickId;
  }

  nvg__flattenPaths(ctx);
  if (ctx.params.edgeAntiAlias && state.shapeAntiAlias) {
    nvg__expandFill(ctx, ctx.fringeWidth, NVGLineCap.Miter, 2.4f);
  } else {
    nvg__expandFill(ctx, 0.0f, NVGLineCap.Miter, 2.4f);
  }

  // Apply global alpha
  fillPaint.innerColor.a *= state.alpha;
  fillPaint.outerColor.a *= state.alpha;

  ctx.params.renderFill(ctx.params.userPtr, &fillPaint, &state.scissor, ctx.fringeWidth, ctx.cache.bounds.ptr, ctx.cache.paths, ctx.cache.npaths, state.evenOddMode);

  // Count triangles
  foreach (int i; 0..ctx.cache.npaths) {
    path = &ctx.cache.paths[i];
    ctx.fillTriCount += path.nfill-2;
    ctx.fillTriCount += path.nstroke-2;
    ctx.drawCallCount += 2;
  }
}

/// Fills the current path with current stroke style.
public void stroke (NVGContext ctx) nothrow @trusted @nogc {
  NVGstate* state = nvg__getState(ctx);
  float scale = nvg__getAverageScale(state.xform[]);
  float strokeWidth = nvg__clamp(state.strokeWidth*scale, 0.0f, 200.0f);
  NVGPaint strokePaint = state.stroke;
  const(NVGpath)* path;

  if (ctx.pathPickId >= 0 && (ctx.pathPickRegistered&(NVGPickKind.Stroke|(NVGPickKind.Stroke<<16))) == NVGPickKind.Stroke) {
    ctx.pathPickRegistered |= NVGPickKind.Stroke<<16;
    ctx.currStrokeHitId = ctx.pathPickId;
  }

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

  if (ctx.params.edgeAntiAlias && state.shapeAntiAlias) {
    nvg__expandStroke(ctx, strokeWidth*0.5f+ctx.fringeWidth*0.5f, state.lineCap, state.lineJoin, state.miterLimit);
  } else {
    nvg__expandStroke(ctx, strokeWidth*0.5f, state.lineCap, state.lineJoin, state.miterLimit);
  }

  ctx.params.renderStroke(ctx.params.userPtr, &strokePaint, &state.scissor, ctx.fringeWidth, strokeWidth, ctx.cache.paths, ctx.cache.npaths);

  // Count triangles
  foreach (int i; 0..ctx.cache.npaths) {
    path = &ctx.cache.paths[i];
    ctx.strokeTriCount += path.nstroke-2;
    ++ctx.drawCallCount;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
/// <h1>Simple Picking On Already Drawn (Rasterized) Pathes</h1>
//
/** This is simple picking API, that allows you to detect if the given point is
 * inside the latest filled/stroked path. Sadly, this can be done only *after*
 * you made filling/stroking (i.e. your path is already drawn), so if you want to
 * change path transparency, for example, you have to do that on the next frame.
 * Sometimes you still can immediately redraw a path without noticable visual
 * artefacts (for example, changing color of an opaque path without AA), though.
 *
 * Usage examples:
 *
 *   ---
 *   nvg.beginPath();
 *   nvg.fillColor(nvgRGB(0, 0, 255));
 *   nvg.circle(100, 50, 20);
 *   nvg.fill();
 *   if (nvg.onFilledPath(mx, my)) {
 *     // it is not recommended to do this, but...
 *     nvg.fillColor(nvgRGBA(255, 0, 255));
 *     nvg.fill();
 *   }
 *   ---
 *
 */
public alias NVGSectionDummy60 = void;

/// Is point (mx, my) on the last stoked path? `tol` is a maximum distance from stroke.
public bool isOnStroke (NVGContext ctx, in float mx, in float my, float tol=float.nan) {
  import std.math : isNaN;
  if (tol.isNaN) tol = nvg__getState(ctx).strokeWidth*nvg__getAverageScale(nvg__getState(ctx).xform[]);
  if (tol < 1) tol = 1; else tol *= tol;
  foreach (const ref path; ctx.cache.paths[0..ctx.cache.npaths]) {
    if (path.nstroke == 0) continue;
    for (int i = 0, j = path.nstroke-1; i < path.nstroke; j = i++) {
      immutable ax = path.stroke[i].x;
      immutable ay = path.stroke[i].y;
      immutable bx = path.stroke[j].x;
      immutable by = path.stroke[j].y;
      if (nvg__distPtSeg(mx, my, ax, ay, bx, by) < tol) return true;
    }
  }
  return false;
}

/// Is point (mx, my) on the last filled path?
/// This doesn't support filling modes yet: it always using non-zero fill mode.
public bool isOnFill (NVGContext ctx, in float mx, in float my) {
  bool res = false;
  foreach (const ref path; ctx.cache.paths[0..ctx.cache.npaths]) {
    if (path.nfill == 0) continue;
    for (int i = 0, j = path.nfill-1; i < path.nfill; j = i++) {
      immutable ay = path.fill[i].y;
      immutable by = path.fill[j].y;
      if ((ay > my) != (by > my)) {
        immutable ax = path.fill[i].x;
        immutable bx = path.fill[j].x;
        if ((mx < (bx-ax)*(my-ay)/(by-ay)+ax)) res = !res;
      }
    }
  }
  return res;
}


// ////////////////////////////////////////////////////////////////////////// //
/// <h1>Picking Without Rasterizing</h1>
//
/** This is picking API that works directly on patches, without rasterizing 'em
 * first.
 *
 * `beginFrame()` resets picking state. Then you can create pathes as usual, but
 * there is a possibility to perform hit checks *before* rasterizing a path.
 * Call either id assigning functions (`currFillHitId()`/`currStrokeHitId()`), or
 * immediate hit test functions (`hitTestCurrFill()`/`hitTestCurrStroke()`)
 * before rasterizing (i.e. calling `fill()` or `stroke()`) to perform hover
 * effects, for example. Note that you can call `beginPath()` without rasterizing
 * if everything you want is hit detection.
 */
public alias NVGSectionDummy61 = void;

// most of the code is by Michael Wynne <mike@mikesspace.net>
// https://github.com/memononen/nanovg/pull/230
// https://github.com/MikeWW/nanovg

/// Pick type query. Used in `hitTest()` and `hitTestAll()`.
public enum NVGPickKind : ubyte {
  Fill = 0x01, ///
  Stroke = 0x02, ///
  All = 0x03, ///
}

/// Marks the fill of the current path as pickable with the specified id.
/// Note that you can create and mark path without rasterizing it.
public void currFillHitId (NVGcontext* ctx, int id) nothrow @trusted @nogc {
  NVGpickScene* ps = nvg__pickSceneGet(ctx);
  NVGpickPath* pp = nvg__pickPathCreate(ctx, id, forStroke:false);
  nvg__pickSceneInsert(ps, pp);
}

/// Marks the stroke of the current path as pickable with the specified id.
/// Note that you can create and mark path without rasterizing it.
public void currStrokeHitId (NVGcontext* ctx, int id) nothrow @trusted @nogc {
  NVGpickScene* ps = nvg__pickSceneGet(ctx);
  NVGpickPath* pp = nvg__pickPathCreate(ctx, id, forStroke:true);
  nvg__pickSceneInsert(ps, pp);
}

private template IsGoodHitTestDG(DG) {
  enum IsGoodHitTestDG =
    __traits(compiles, (){ DG dg; bool res = dg(cast(int)42, cast(int)666); }) ||
    __traits(compiles, (){ DG dg; dg(cast(int)42, cast(int)666); });
}

private template IsGoodHitTestInternalDG(DG) {
  enum IsGoodHitTestInternalDG =
    __traits(compiles, (){ DG dg; NVGpickPath* pp; bool res = dg(pp); }) ||
    __traits(compiles, (){ DG dg; NVGpickPath* pp; dg(pp); });
}

/// Call delegate `dg` for each path under the specified position (in no particular order).
/// Returns the id of the path for which delegate `dg` returned true or -1.
/// dg is: `bool delegate (int id, int order)` -- `order` is path ordering (ascending).
public int hitTestDG(DG) (NVGcontext* ctx, float x, float y, uint kind, scope DG dg) if (IsGoodHitTestDG!DG || IsGoodHitTestInternalDG!DG) {
  if (ctx.pickScene is null) return -1;

  NVGpickScene* ps = ctx.pickScene;
  int levelwidth = 1<<(ps.nlevels-1);
  int cellx = nvg__clamp(cast(int)(x/ps.xdim), 0, levelwidth);
  int celly = nvg__clamp(cast(int)(y/ps.ydim), 0, levelwidth);
  int npicked = 0;

  for (int lvl = ps.nlevels-1; lvl >= 0; --lvl) {
    NVGpickPath* pp = ps.levels[lvl][celly*levelwidth+cellx];
    while (pp !is null) {
      if (nvg__pickPathTestBounds(ps, pp, x, y)) {
        int hit = 0;
        if ((kind&NVGPickKind.Stroke) && (pp.flags&NVG_PICK_STROKE)) hit = nvg__pickPathStroke(ps, pp, x, y);
        if (!hit && (kind&NVGPickKind.Fill) && (pp.flags&NVG_PICK_FILL)) hit = nvg__pickPath(ps, pp, x, y);
        if (hit) {
          static if (IsGoodHitTestDG!DG) {
            static if (__traits(compiles, (){ DG dg; bool res = dg(cast(int)42, cast(int)666); })) {
              if (dg(pp.id, cast(int)pp.order)) return pp.id;
            } else {
              dg(pp.id, cast(int)pp.order);
            }
          } else {
            static if (__traits(compiles, (){ DG dg; NVGpickPath* pp; bool res = dg(pp); })) {
              if (dg(pp)) return pp.id;
            } else {
              dg(pp);
            }
          }
        }
      }
      pp = pp.next;
    }
    cellx >>= 1;
    celly >>= 1;
    levelwidth >>= 1;
  }

  return -1;
}

/// Fills ids with a list of the top most hit ids under the specified position.
/// Returns the slice of `ids`.
public int[] hitTestAll (NVGcontext* ctx, float x, float y, uint kind, int[] ids) nothrow @trusted @nogc {
  if (ctx.pickScene is null || ids.length == 0) return ids[0..0];

  int npicked = 0;
  NVGpickScene* ps = ctx.pickScene;

  ctx.hitTestDG(x, y, kind, delegate (NVGpickPath* pp) {
    if (npicked == ps.cpicked) {
      int cpicked = ps.cpicked+ps.cpicked;
      NVGpickPath** picked = cast(NVGpickPath**)realloc(ps.picked, (NVGpickPath*).sizeof*ps.cpicked);
      if (picked is null) return true; // abort
      ps.cpicked = cpicked;
      ps.picked = picked;
    }
    ps.picked[npicked] = pp;
    ++npicked;
    return false; // go on
  });

  qsort(ps.picked, npicked, (NVGpickPath*).sizeof, &nvg__comparePaths);

  assert(npicked >= 0);
  if (npicked > ids.length) npicked = cast(int)ids.length;
  foreach (immutable nidx, ref int did; ids[0..npicked]) did = ps.picked[nidx].id;

  return ids[0..npicked];
}

/// Returns the id of the pickable shape containing x,y or -1 if no shape was found.
public int hitTest (NVGcontext* ctx, float x, float y, uint kind) nothrow @trusted @nogc {
  if (ctx.pickScene is null) return -1;

  NVGpickScene* ps = ctx.pickScene;
  int bestOrder = -1;
  int bestID = -1;

  ctx.hitTestDG(x, y, kind, delegate (NVGpickPath* pp) {
    if (pp.order > bestOrder) {
      bestOrder = pp.order;
      bestID = pp.id;
    }
  });

  return bestID;
}

/// Returns `true` if the given point is within the fill of the currently defined path.
/// This operation can be done before rasterizing the current path.
public bool hitTestCurrFill (NVGcontext* ctx, float x, float y) nothrow @trusted @nogc {
  NVGpickScene* ps = nvg__pickSceneGet(ctx);
  int oldnpoints = ps.npoints;
  int oldnsegments = ps.nsegments;
  NVGpickPath* pp = nvg__pickPathCreate(ctx, 1, forStroke:false);
  if (pp is null) return false; // oops
  scope(exit) {
    nvg__freePickPath(ps, pp);
    ps.npoints = oldnpoints;
    ps.nsegments = oldnsegments;
  }
  return (nvg__pointInBounds(x, y, pp.bounds) ? nvg__pickPath(ps, pp, x, y) : false);
}

/// Returns `true` if the given point is within the stroke of the currently defined path.
/// This operation can be done before rasterizing the current path.
public bool hitTestCurrStroke (NVGcontext* ctx, float x, float y) nothrow @trusted @nogc {
  NVGpickScene* ps = nvg__pickSceneGet(ctx);
  int oldnpoints = ps.npoints;
  int oldnsegments = ps.nsegments;
  NVGpickPath* pp = nvg__pickPathCreate(ctx, 1, forStroke:true);
  if (pp is null) return false; // oops
  scope(exit) {
    nvg__freePickPath(ps, pp);
    ps.npoints = oldnpoints;
    ps.nsegments = oldnsegments;
  }
  return (nvg__pointInBounds(x, y, pp.bounds) ? nvg__pickPathStroke(ps, pp, x, y) : false);
}


nothrow @trusted @nogc {
extern(C) {
  private alias _compare_fp_t = int function (const void*, const void*) nothrow @nogc;
  private extern(C) void qsort (scope void* base, size_t nmemb, size_t size, _compare_fp_t compar) nothrow @nogc;

  extern(C) int nvg__comparePaths (const void* a, const void* b) {
    return (*cast(const(NVGpickPath)**)b).order-(*cast(const(NVGpickPath)**)a).order;
  }
}

enum NVG_PICK_EPS = 0.0001f;

// Segment flags
alias NVGsegmentFlags = uint;
enum /*NVGsegmentFlags*/ : uint {
  NVG_PICK_CORNER = 1,
  NVG_PICK_BEVEL = 2,
  NVG_PICK_INNERBEVEL = 4,
  NVG_PICK_CAP = 8,
  NVG_PICK_ENDCAP = 16,
}

// Path flags
alias NVGpathFlags = uint;
enum /*NVGpathFlags*/ : uint {
  NVG_PICK_SCISSOR = 1,
  NVG_PICK_STROKE = 2,
  NVG_PICK_FILL = 4,
}

struct NVGsegment {
  int firstPoint; // Index into NVGpickScene.points
  short type; // NVG_LINETO or NVG_BEZIERTO
  short flags; // Flags relate to the corner between the prev segment and this one.
  float[4] bounds;
  float[2] startDir; // Direction at t == 0
  float[2] endDir; // Direction at t == 1
  float[2] miterDir; // Direction of miter of corner between the prev segment and this one.
}

struct NVGpickSubPath {
  short winding; // TODO: Merge to flag field
  bool closed; // TODO: Merge to flag field

  int firstSegment; // Index into NVGpickScene.segments
  int nsegments;

  float[4] bounds;

  NVGpickSubPath* next;
}

struct NVGpickPath {
  int id;
  short flags;
  short order;
  float strokeWidth;
  float miterLimit;
  short lineCap;
  short lineJoin;
  bool evenOddMode;

  float[4] bounds;
  int scissor; // Indexes into ps->points and defines scissor rect as XVec, YVec and Center

  NVGpickSubPath*  subPaths;
  NVGpickPath* next;
  NVGpickPath* cellnext;
}

struct NVGpickScene {
  int npaths;

  NVGpickPath* paths; // Linked list of paths
  NVGpickPath* lastPath; // The last path in the paths linked list (the first path added)
  NVGpickPath* freePaths; // Linked list of free paths

  NVGpickSubPath* freeSubPaths; // Linked list of free sub paths

  int width;
  int height;

  // Points for all path sub paths.
  float* points;
  int npoints;
  int cpoints;

  // Segments for all path sub paths
  NVGsegment* segments;
  int nsegments;
  int csegments;

  // Implicit quadtree
  float xdim;   // Width / (1 << nlevels)
  float ydim;   // Height / (1 << nlevels)
  int ncells;   // Total number of cells in all levels
  int nlevels;
  NVGpickPath*** levels;  // Index: [Level][LevelY * LevelW + LevelX] Value: Linked list of paths

  // Temp storage for picking
  int cpicked;
  NVGpickPath** picked;
}


//
// Bounds Utilities
//
void nvg__initBounds (ref float[4] bounds) {
  bounds.ptr[0] = bounds.ptr[1] = 1e6f;
  bounds.ptr[2] = bounds.ptr[3] = -1e6f;
}

void nvg__expandBounds (ref float[4] bounds, const(float)* points, int npoints) {
  int i;
  npoints *= 2;
  for (i = 0; i < npoints; i += 2) {
    bounds.ptr[0] = nvg__min(bounds.ptr[0], points[i]);
    bounds.ptr[1] = nvg__min(bounds.ptr[1], points[i+1]);
    bounds.ptr[2] = nvg__max(bounds.ptr[2], points[i]);
    bounds.ptr[3] = nvg__max(bounds.ptr[3], points[i+1]);
  }
}

void nvg__unionBounds (ref float[4] bounds, in ref float[4] boundsB) {
  bounds.ptr[0] = nvg__min(bounds.ptr[0], boundsB.ptr[0]);
  bounds.ptr[1] = nvg__min(bounds.ptr[1], boundsB.ptr[1]);
  bounds.ptr[2] = nvg__max(bounds.ptr[2], boundsB.ptr[2]);
  bounds.ptr[3] = nvg__max(bounds.ptr[3], boundsB.ptr[3]);
}

void nvg__intersectBounds (ref float[4] bounds, in ref float[4] boundsB) {
  bounds.ptr[0] = nvg__max(boundsB.ptr[0], bounds.ptr[0]);
  bounds.ptr[1] = nvg__max(boundsB.ptr[1], bounds.ptr[1]);
  bounds.ptr[2] = nvg__min(boundsB.ptr[2], bounds.ptr[2]);
  bounds.ptr[3] = nvg__min(boundsB.ptr[3], bounds.ptr[3]);

  bounds.ptr[2] = nvg__max(bounds.ptr[0], bounds.ptr[2]);
  bounds.ptr[3] = nvg__max(bounds.ptr[1], bounds.ptr[3]);
}

bool nvg__pointInBounds (in float x, in float y, in ref float[4] bounds) =>
  (x >= bounds.ptr[0] && x <= bounds.ptr[2] && y >= bounds.ptr[1] && y <= bounds.ptr[3]);


//
// Building paths & sub paths
//
int nvg__pickSceneAddPoints (NVGpickScene* ps, const(float)* xy, int n) {
  if (ps.npoints+n > ps.cpoints) {
    int cpoints = ps.npoints+n+(ps.cpoints<<1);
    float* points = cast(float*)realloc(ps.points, float.sizeof*2*cpoints);
    if (points is null) return -1;
    ps.points = points;
    ps.cpoints = cpoints;
  }
  int i = ps.npoints;
  if (xy !is null) memcpy(&ps.points[i*2], xy, float.sizeof*2*n);
  ps.npoints += n;
  return i;
}

void nvg__pickSubPathAddSegment (NVGpickScene* ps, NVGpickSubPath* psp, int firstPoint, int type, short flags) {
  NVGsegment* seg = null;
  if (ps.nsegments == ps.csegments) {
    int csegments = 1+ps.csegments+(ps.csegments<<1);
    NVGsegment* segments = cast(NVGsegment*)realloc(ps.segments, NVGsegment.sizeof*csegments);
    if (segments is null) return;
    ps.segments = segments;
    ps.csegments = csegments;
  }

  if (psp.firstSegment == -1) psp.firstSegment = ps.nsegments;

  seg = &ps.segments[ps.nsegments];
  ++ps.nsegments;
  seg.firstPoint = firstPoint;
  seg.type = cast(short)type;
  seg.flags = flags;
  ++psp.nsegments;

  nvg__segmentDir(ps, psp, seg,  0, seg.startDir);
  nvg__segmentDir(ps, psp, seg,  1, seg.endDir);
}

void nvg__segmentDir (NVGpickScene* ps, NVGpickSubPath* psp, NVGsegment* seg, float t, ref float[2] d) {
  const(float)* points = &ps.points[seg.firstPoint*2];
  immutable float x0 = points[0*2+0], x1 = points[1*2+0];
  immutable float y0 = points[0*2+1], y1 = points[1*2+1];
  switch (seg.type) {
    case Command.LineTo:
      d.ptr[0] = x1-x0;
      d.ptr[1] = y1-y0;
      nvg__normalize(&d.ptr[0], &d.ptr[1]);
      break;
    case Command.BezierTo:
      immutable float x2 = points[2*2+0];
      immutable float y2 = points[2*2+1];
      immutable float x3 = points[3*2+0];
      immutable float y3 = points[3*2+1];

      immutable float omt = 1.0f-t;
      immutable float omt2 = omt*omt;
      immutable float t2 = t*t;

      d.ptr[0] =
        3.0f*omt2*(x1-x0)+
        6.0f*omt*t*(x2-x1)+
        3.0f*t2*(x3-x2);
      d.ptr[1] =
        3.0f*omt2*(y1-y0)+
        6.0f*omt*t*(y2-y1)+
        3.0f*t2*(y3-y2);

      nvg__normalize(&d.ptr[0], &d.ptr[1]);
      break;
    default:
      break;
  }
}

void nvg__pickSubPathAddFillSupports (NVGpickScene* ps, NVGpickSubPath* psp) {
  NVGsegment* segments = &ps.segments[psp.firstSegment];
  for (int s = 0; s < psp.nsegments; ++s) {
    NVGsegment* seg = &segments[s];
    const(float)* points = &ps.points[seg.firstPoint*2];
    if (seg.type == Command.LineTo) {
      nvg__initBounds(seg.bounds);
      nvg__expandBounds(seg.bounds, points, 2);
    } else {
      nvg__bezierBounds(points, seg.bounds);
    }
  }
}

void nvg__pickSubPathAddStrokeSupports (NVGpickScene* ps, NVGpickSubPath* psp, float strokeWidth, int lineCap, int lineJoin, float miterLimit) {
  bool closed = psp.closed;
  const(float)* points = ps.points;
  NVGsegment* seg = null;
  NVGsegment* segments = &ps.segments[psp.firstSegment];
  int nsegments = psp.nsegments;
  NVGsegment* prevseg = (closed ? &segments[psp.nsegments-1] : null);

  int ns = 0; // nsupports
  float[32] supportingPoints;
  int firstPoint, lastPoint;

  if (!closed) {
    segments[0].flags |= NVG_PICK_CAP;
    segments[nsegments-1].flags |= NVG_PICK_ENDCAP;
  }

  for (int s = 0; s < nsegments; ++s) {
    seg = &segments[s];
    nvg__initBounds(seg.bounds);

    firstPoint = seg.firstPoint*2;
    lastPoint = firstPoint+(seg.type == Command.LineTo ? 2 : 6);

    ns = 0;

    // First two supporting points are either side of the start point
    supportingPoints.ptr[ns++] = points[firstPoint]-seg.startDir.ptr[1]*strokeWidth;
    supportingPoints.ptr[ns++] = points[firstPoint+1]+seg.startDir.ptr[0]*strokeWidth;

    supportingPoints.ptr[ns++] = points[firstPoint]+seg.startDir.ptr[1]*strokeWidth;
    supportingPoints.ptr[ns++] = points[firstPoint+1]-seg.startDir.ptr[0]*strokeWidth;

    // Second two supporting points are either side of the end point
    supportingPoints.ptr[ns++] = points[lastPoint]-seg.endDir.ptr[1]*strokeWidth;
    supportingPoints.ptr[ns++] = points[lastPoint+1]+seg.endDir.ptr[0]*strokeWidth;

    supportingPoints.ptr[ns++] = points[lastPoint]+seg.endDir.ptr[1]*strokeWidth;
    supportingPoints.ptr[ns++] = points[lastPoint+1]-seg.endDir.ptr[0]*strokeWidth;

    if (seg.flags&NVG_PICK_CORNER && prevseg !is null) {
      seg.miterDir.ptr[0] = 0.5f*(-prevseg.endDir.ptr[1]-seg.startDir.ptr[1]);
      seg.miterDir.ptr[1] = 0.5f*(prevseg.endDir.ptr[0]+seg.startDir.ptr[0]);

      immutable float M2 = seg.miterDir.ptr[0]*seg.miterDir.ptr[0]+seg.miterDir.ptr[1]*seg.miterDir.ptr[1];

      if (M2 > 0.000001f) {
        float scale = 1.0f/M2;
        if (scale > 600.0f) scale = 600.0f;
        seg.miterDir.ptr[0] *= scale;
        seg.miterDir.ptr[1] *= scale;
      }

      //NVG_PICK_DEBUG_VECTOR_SCALE(&points[firstPoint], seg.miterDir, 10);

      // Add an additional support at the corner on the other line
      supportingPoints.ptr[ns++] = points[firstPoint]-prevseg.endDir.ptr[1]*strokeWidth;
      supportingPoints.ptr[ns++] = points[firstPoint+1]+prevseg.endDir.ptr[0]*strokeWidth;

      if (lineJoin == NVGLineCap.Miter || lineJoin == NVGLineCap.Bevel) {
        // Set a corner as beveled if the join type is bevel or mitered and
        // miterLimit is hit.
        if (lineJoin == NVGLineCap.Bevel || (M2*miterLimit*miterLimit) < 1.0f) {
          seg.flags |= NVG_PICK_BEVEL;
        } else {
          // Corner is mitered - add miter point as a support
          supportingPoints.ptr[ns++] = points[firstPoint]+seg.miterDir.ptr[0]*strokeWidth;
          supportingPoints.ptr[ns++] = points[firstPoint+1]+seg.miterDir.ptr[1]*strokeWidth;
        }
      } else if (lineJoin == NVGLineCap.Round) {
        // ... and at the midpoint of the corner arc
        float[2] vertexN = [ -seg.startDir.ptr[0]+prevseg.endDir.ptr[0], -seg.startDir.ptr[1]+prevseg.endDir.ptr[1] ];
        nvg__normalize(&vertexN[0], &vertexN[1]);

        supportingPoints.ptr[ns++] = points[firstPoint]+vertexN[0]*strokeWidth;
        supportingPoints.ptr[ns++] = points[firstPoint+1]+vertexN[1]*strokeWidth;
      }
    }

    if (seg.flags&NVG_PICK_CAP) {
      switch (lineCap) {
        case NVGLineCap.Butt:
          // Supports for butt already added.
          break;
        case NVGLineCap.Square:
          // Square cap supports are just the original two supports moved
          // out along the direction
          supportingPoints.ptr[ns++] = supportingPoints.ptr[0]-seg.startDir.ptr[0]*strokeWidth;
          supportingPoints.ptr[ns++] = supportingPoints.ptr[1]-seg.startDir.ptr[1]*strokeWidth;
          supportingPoints.ptr[ns++] = supportingPoints.ptr[2]-seg.startDir.ptr[0]*strokeWidth;
          supportingPoints.ptr[ns++] = supportingPoints.ptr[3]-seg.startDir.ptr[1]*strokeWidth;
          break;
        case NVGLineCap.Round:
          // Add one additional support for the round cap along the dir
          supportingPoints.ptr[ns++] = points[firstPoint]-seg.startDir.ptr[0]*strokeWidth;
          supportingPoints.ptr[ns++] = points[firstPoint+1]-seg.startDir.ptr[1]*strokeWidth;
          break;
        default:
          break;
      }
    }

    if (seg.flags&NVG_PICK_ENDCAP) {
      // End supporting points, either side of line
      int end = 4;
      switch(lineCap) {
        case NVGLineCap.Butt:
          // Supports for butt already added.
          break;
        case NVGLineCap.Square:
          // Square cap supports are just the original two supports moved
          // out along the direction
          supportingPoints.ptr[ns++] = supportingPoints.ptr[end+0]+seg.endDir.ptr[0]*strokeWidth;
          supportingPoints.ptr[ns++] = supportingPoints.ptr[end+1]+seg.endDir.ptr[1]*strokeWidth;
          supportingPoints.ptr[ns++] = supportingPoints.ptr[end+2]+seg.endDir.ptr[0]*strokeWidth;
          supportingPoints.ptr[ns++] = supportingPoints.ptr[end+3]+seg.endDir.ptr[1]*strokeWidth;
          break;
        case NVGLineCap.Round:
          // Add one additional support for the round cap along the dir
          supportingPoints.ptr[ns++] = points[lastPoint]+seg.endDir.ptr[0]*strokeWidth;
          supportingPoints.ptr[ns++] = points[lastPoint+1]+seg.endDir.ptr[1]*strokeWidth;
          break;
        default:
          break;
      }
    }

    nvg__expandBounds(seg.bounds, supportingPoints.ptr, ns/2);

    prevseg = seg;
  }
}

NVGpickPath* nvg__pickPathCreate (NVGcontext* context, int id, bool forStroke) {
  NVGpickScene* ps = nvg__pickSceneGet(context);
  if (ps is null) return null;

  int i = 0;

  int ncommands = context.ncommands;
  float* commands = context.commands;

  NVGpickPath* pp = null;
  NVGpickSubPath* psp = null;
  float[2] start;
  int firstPoint;

  int hasHoles = 0;
  NVGpickSubPath* prev = null;

  float[8] points;
  float[2] inflections;
  int ninflections = 0;

  NVGstate* state = nvg__getState(context);
  float[4] totalBounds;
  NVGsegment* segments = null;
  const(NVGsegment)* seg = null;
  NVGpickSubPath *curpsp;

  pp = nvg__allocPickPath(ps);
  if (pp is null) return null;

  pp.id = id;

  while (i < ncommands) {
    int cmd = cast(int)commands[i];
    switch (cmd) {
      case Command.MoveTo:
        start.ptr[0] = commands[i+1];
        start.ptr[1] = commands[i+2];

        // Start a new path for each sub path to handle sub paths that
        // intersect other sub paths.
        prev = psp;
        psp = nvg__allocPickSubPath(ps);
        if (psp is null) { psp = prev; break; }
        psp.firstSegment = -1;
        psp.winding = NVGSolidity.Solid;
        psp.next = prev;

        nvg__pickSceneAddPoints(ps, &commands[i+1], 1);
        i += 3;
        break;
      case Command.LineTo:
        firstPoint = nvg__pickSceneAddPoints(ps, &commands[i+1], 1);
        nvg__pickSubPathAddSegment(ps, psp, firstPoint-1, cmd, NVG_PICK_CORNER);
        i += 3;
        break;
      case Command.BezierTo:
        // Split the curve at it's dx==0 or dy==0 inflection points.
        // Thus:
        //    A horizontal line only ever interects the curves once.
        //  and
        //    Finding the closest point on any curve converges more reliably.

        // NOTE: We could just split on dy==0 here.

        memcpy(&points.ptr[0], &ps.points[(ps.npoints-1)*2], float.sizeof*2);
        memcpy(&points.ptr[2], &commands[i+1], float.sizeof*2*3);

        ninflections = 0;
        nvg__bezierInflections(points.ptr, 1, &ninflections, inflections.ptr);
        nvg__bezierInflections(points.ptr, 0, &ninflections, inflections.ptr);

        if (ninflections) {
          float previnfl = 0;
          float[8] pointsA = void, pointsB = void;
          int infl;

          nvg__smallsort(inflections.ptr, ninflections);

          for (infl = 0; infl < ninflections; ++infl) {
            if (nvg__absf(inflections.ptr[infl]-previnfl) < NVG_PICK_EPS) continue;

            immutable float t = (inflections.ptr[infl]-previnfl)*(1.0f/(1.0f-previnfl));

            previnfl = inflections.ptr[infl];

            nvg__splitBezier(points.ptr, t, pointsA.ptr, pointsB.ptr);

            firstPoint = nvg__pickSceneAddPoints(ps, &pointsA.ptr[2], 3);
            nvg__pickSubPathAddSegment(ps, psp, firstPoint-1, cmd, (infl == 0) ? NVG_PICK_CORNER : 0);

            memcpy(points.ptr, pointsB.ptr, float.sizeof*8);
          }

          firstPoint = nvg__pickSceneAddPoints(ps, &pointsB.ptr[2], 3);
          nvg__pickSubPathAddSegment(ps, psp, firstPoint-1, cmd, 0);
        } else {
          firstPoint = nvg__pickSceneAddPoints(ps, &commands[i+1], 3);
          nvg__pickSubPathAddSegment(ps, psp, firstPoint-1, cmd, NVG_PICK_CORNER);
        }
        i += 7;
        break;
      case Command.Close:
        if (ps.points[(ps.npoints-1)*2] != start.ptr[0] || ps.points[(ps.npoints-1)*2+1] != start.ptr[1]) {
          firstPoint = nvg__pickSceneAddPoints(ps, start.ptr, 1);
          nvg__pickSubPathAddSegment(ps, psp, firstPoint-1, Command.LineTo, NVG_PICK_CORNER);
        }
        psp.closed = true;

        i++;
        break;
      case Command.Winding:
        psp.winding = cast(short)cast(int)commands[i+1];
        if (psp.winding == NVGSolidity.Hole) hasHoles = 1;
        i += 2;
        break;
      default:
        i++;
        break;
    }
  }

  pp.flags = (forStroke ? NVG_PICK_STROKE : NVG_PICK_FILL);
  pp.subPaths = psp;
  pp.strokeWidth = state.strokeWidth*0.5f;
  pp.miterLimit = state.miterLimit;
  pp.lineCap = cast(short)state.lineCap;
  pp.lineJoin = cast(short)state.lineJoin;
  pp.evenOddMode = nvg__getState(context).evenOddMode;

  nvg__initBounds(totalBounds);

  for (curpsp = psp; curpsp; curpsp = curpsp.next) {
    if (forStroke) {
      nvg__pickSubPathAddStrokeSupports(ps, curpsp, pp.strokeWidth, pp.lineCap, pp.lineJoin, pp.miterLimit);
    } else {
      nvg__pickSubPathAddFillSupports(ps, curpsp);
    }

    segments = &ps.segments[curpsp.firstSegment];
    nvg__initBounds(curpsp.bounds);
    for (int s = 0; s < curpsp.nsegments; ++s) {
      seg = &segments[s];
      //NVG_PICK_DEBUG_BOUNDS(seg.bounds);
      nvg__unionBounds(curpsp.bounds, seg.bounds);
    }

    nvg__unionBounds(totalBounds, curpsp.bounds);
  }

  // Store the scissor rect if present.
  if (state.scissor.extent[0] != -1.0f) {
    // Use points storage to store the scissor data
    float* scissor = null;
    pp.scissor = nvg__pickSceneAddPoints(ps, null, 4);
    scissor = &ps.points[pp.scissor*2];

    memcpy(scissor, state.scissor.xform.ptr, 6*float.sizeof);
    memcpy(scissor+6, state.scissor.extent.ptr, 2*float.sizeof);

    pp.flags |= NVG_PICK_SCISSOR;
  }

  memcpy(pp.bounds.ptr, totalBounds.ptr, float.sizeof*4);

  return pp;
}


// Struct management
NVGpickPath* nvg__allocPickPath (NVGpickScene* ps) {
  NVGpickPath* pp = ps.freePaths;
  if (pp !is null) {
    ps.freePaths = pp.next;
  } else {
    pp = cast(NVGpickPath*)malloc(NVGpickPath.sizeof);
  }
  memset(pp, 0, NVGpickPath.sizeof);
  return pp;
}

// Put a pick path and any sub paths (back) to the free lists.
void nvg__freePickPath (NVGpickScene* ps, NVGpickPath* pp) {
  // Add all sub paths to the sub path free list.
  // Finds the end of the path sub paths, links that to the current
  // sub path free list head and replaces the head ptr with the
  // head path sub path entry.
  NVGpickSubPath* psp = null;
  for (psp = pp.subPaths; psp !is null && psp.next !is null; psp = psp.next) {}

  if (psp) {
    psp.next = ps.freeSubPaths;
    ps.freeSubPaths = pp.subPaths;
  }
  pp.subPaths = null;

  // Add the path to the path freelist
  pp.next = ps.freePaths;
  ps.freePaths = pp;
  if (pp.next is null) ps.lastPath = pp;
}

NVGpickSubPath* nvg__allocPickSubPath (NVGpickScene* ps) {
  NVGpickSubPath* psp = ps.freeSubPaths;
  if (psp !is null) {
    ps.freeSubPaths = psp.next;
  } else {
    psp = cast(NVGpickSubPath*)malloc(NVGpickSubPath.sizeof);
    if (psp is null) return null;
  }
  memset(psp, 0, NVGpickSubPath.sizeof);
  return psp;
}

void nvg__returnPickSubPath(NVGpickScene* ps, NVGpickSubPath* psp) {
  psp.next = ps.freeSubPaths;
  ps.freeSubPaths = psp;
}

NVGpickScene* nvg__allocPickScene () {
  NVGpickScene* ps = cast(NVGpickScene*)malloc(NVGpickScene.sizeof);
  if (ps is null) return null;
  memset(ps, 0, NVGpickScene.sizeof);
  ps.nlevels = 5;
  return ps;
}

void nvg__deletePickScene (NVGpickScene* ps) {
  NVGpickPath* pp;
  NVGpickSubPath* psp;

  // Add all paths (and thus sub paths) to the free list(s).
  while (ps.paths !is null) {
    pp = ps.paths.next;
    nvg__freePickPath(ps, ps.paths);
    ps.paths = pp;
  }

  // Delete all paths
  while (ps.freePaths !is null) {
    pp = ps.freePaths;
    ps.freePaths = pp.next;
    while (pp.subPaths !is null) {
      psp = pp.subPaths;
      pp.subPaths = psp.next;
      free(psp);
    }
    free(pp);
  }

  // Delete all sub paths
  while (ps.freeSubPaths !is null) {
    psp = ps.freeSubPaths.next;
    free(ps.freeSubPaths);
    ps.freeSubPaths = psp;
  }

  ps.npoints = 0;
  ps.nsegments = 0;

  if (ps.levels !is null) {
    free(ps.levels[0]);
    free(ps.levels);
  }

  if (ps.picked !is null) free(ps.picked);
  if (ps.points !is null) free(ps.points);
  if (ps.segments !is null) free(ps.segments);

  free(ps);
}

NVGpickScene* nvg__pickSceneGet (NVGcontext* ctx) {
  if (ctx.pickScene is null) ctx.pickScene = nvg__allocPickScene();
  return ctx.pickScene;
}


// Applies Casteljau's algorithm to a cubic bezier for a given parameter t
// points is 4 points (8 floats)
// lvl1 is 3 points (6 floats)
// lvl2 is 2 points (4 floats)
// lvl3 is 1 point (2 floats)
void nvg__casteljau (const(float)* points, float t, float* lvl1, float* lvl2, float* lvl3) {
  enum x0 = 0*2+0; enum x1 = 1*2+0; enum x2 = 2*2+0; enum x3 = 3*2+0;
  enum y0 = 0*2+1; enum y1 = 1*2+1; enum y2 = 2*2+1; enum y3 = 3*2+1;

  // Level 1
  lvl1[x0] = (points[x1]-points[x0])*t+points[x0];
  lvl1[y0] = (points[y1]-points[y0])*t+points[y0];

  lvl1[x1] = (points[x2]-points[x1])*t+points[x1];
  lvl1[y1] = (points[y2]-points[y1])*t+points[y1];

  lvl1[x2] = (points[x3]-points[x2])*t+points[x2];
  lvl1[y2] = (points[y3]-points[y2])*t+points[y2];

  // Level 2
  lvl2[x0] = (lvl1[x1]-lvl1[x0])*t+lvl1[x0];
  lvl2[y0] = (lvl1[y1]-lvl1[y0])*t+lvl1[y0];

  lvl2[x1] = (lvl1[x2]-lvl1[x1])*t+lvl1[x1];
  lvl2[y1] = (lvl1[y2]-lvl1[y1])*t+lvl1[y1];

  // Level 3
  lvl3[x0] = (lvl2[x1]-lvl2[x0])*t+lvl2[x0];
  lvl3[y0] = (lvl2[y1]-lvl2[y0])*t+lvl2[y0];
}

// Calculates a point on a bezier at point t.
void nvg__bezierEval (const(float)* points, float t, ref float[2] tpoint) {
  immutable float omt = 1-t;
  immutable float omt3 = omt*omt*omt;
  immutable float omt2 = omt*omt;
  immutable float t3 = t*t*t;
  immutable float t2 = t*t;

  tpoint.ptr[0] =
    points[0]*omt3+
    points[2]*3.0f*omt2*t+
    points[4]*3.0f*omt*t2+
    points[6]*t3;

  tpoint.ptr[1] =
    points[1]*omt3+
    points[3]*3.0f*omt2*t+
    points[5]*3.0f*omt*t2+
    points[7]*t3;
}

// Splits a cubic bezier curve into two parts at point t.
void nvg__splitBezier (const(float)* points, float t, float* pointsA, float* pointsB) {
  enum x0 = 0*2+0; enum x1 = 1*2+0; enum x2 = 2*2+0; enum x3 = 3*2+0;
  enum y0 = 0*2+1; enum y1 = 1*2+1; enum y2 = 2*2+1; enum y3 = 3*2+1;

  float[6] lvl1 = void;
  float[4] lvl2 = void;
  float[2] lvl3 = void;

  nvg__casteljau(points, t, lvl1.ptr, lvl2.ptr, lvl3.ptr);

  // First half
  pointsA[x0] = points[x0];
  pointsA[y0] = points[y0];

  pointsA[x1] = lvl1.ptr[x0];
  pointsA[y1] = lvl1.ptr[y0];

  pointsA[x2] = lvl2.ptr[x0];
  pointsA[y2] = lvl2.ptr[y0];

  pointsA[x3] = lvl3.ptr[x0];
  pointsA[y3] = lvl3.ptr[y0];

  // Second half
  pointsB[x0] = lvl3.ptr[x0];
  pointsB[y0] = lvl3.ptr[y0];

  pointsB[x1] = lvl2.ptr[x1];
  pointsB[y1] = lvl2.ptr[y1];

  pointsB[x2] = lvl1.ptr[x2];
  pointsB[y2] = lvl1.ptr[y2];

  pointsB[x3] = points[x3];
  pointsB[y3] = points[y3];
}

// Calculates the inflection points in coordinate coord (X = 0, Y = 1) of a cubic bezier.
// Appends any found inflection points to the array inflections and increments *ninflections.
// So finds the parameters where dx/dt or dy/dt is 0
void nvg__bezierInflections (const(float)* points, int coord, int* ninflections, float* inflections) {
  immutable float v0 = points[0*2+coord], v1 = points[1*2+coord], v2 = points[2*2+coord], v3 = points[3*2+coord];
  float[2] t = void;
  float a, b, c, d;
  int nvalid = *ninflections;

  a = 3.0f*( -v0+3.0f*v1-3.0f*v2+v3 );
  b = 6.0f*( v0-2.0f*v1+v2 );
  c = 3.0f*( v1-v0 );

  d = b*b-4.0f*a*c;
  if (nvg__absf(d-0.0f) < NVG_PICK_EPS) {
    // Zero or one root
    t.ptr[0] = -b/2.0f*a;
    if (t.ptr[0] > NVG_PICK_EPS && t.ptr[0] < (1.0f-NVG_PICK_EPS)) {
      inflections[nvalid] = t.ptr[0];
      ++nvalid;
    }
  } else if (d > NVG_PICK_EPS) {
    // zero, one or two roots
    d = nvg__sqrtf(d);

    t.ptr[0] = (-b+d)/(2.0f*a);
    t.ptr[1] = (-b-d)/(2.0f*a);

    for (int i = 0; i < 2; ++i) {
      if (t.ptr[i] > NVG_PICK_EPS && t.ptr[i] < (1.0f-NVG_PICK_EPS)) {
        inflections[nvalid] = t.ptr[i];
        ++nvalid;
      }
    }
  } else {
    // zero roots
  }

  *ninflections = nvalid;
}

// Sort a small number of floats in ascending order (0 < n < 6)
void nvg__smallsort (float* values, int n) {
  bool bSwapped = true;
  for (int j = 0; j < n-1 && bSwapped; ++j) {
    bSwapped = false;
    for (int i = 0; i < n-1; ++i) {
      if (values[i] > values[i+1]) {
        auto tmp = values[i];
        values[i] = values[i+1];
        values[i+1] = tmp;
      }
    }
  }
}

// Calculates the bounding rect of a given cubic bezier curve.
void nvg__bezierBounds (const(float)* points, ref float[4] bounds) {
  float[4] inflections = void;
  int ninflections = 0;
  float[2] tpoint = void;

  nvg__initBounds(bounds);

  // Include start and end points in bounds
  nvg__expandBounds(bounds, &points[0], 1);
  nvg__expandBounds(bounds, &points[6], 1);

  // Calculate dx==0 and dy==0 inflection points and add then
  // to the bounds

  nvg__bezierInflections(points, 0, &ninflections, inflections.ptr);
  nvg__bezierInflections(points, 1, &ninflections, inflections.ptr);

  for (int i = 0; i < ninflections; ++i) {
    nvg__bezierEval(points, inflections[i], tpoint);
    nvg__expandBounds(bounds, tpoint.ptr, 1);
  }
}

// Checks to see if a line originating from x,y along the +ve x axis
// intersects the given line (points[0],points[1]) -> (points[2], points[3]).
// Returns `true` on intersection.
// Horizontal lines are never hit.
bool nvg__intersectLine (const(float)* points, float x, float y) {
  immutable float x1 = points[0];
  immutable float y1 = points[1];
  immutable float x2 = points[2];
  immutable float y2 = points[3];
  immutable float d = y2-y1;
  if (d > NVG_PICK_EPS || d < -NVG_PICK_EPS) {
    immutable float s = (x2-x1)/d;
    immutable float lineX = x1+(y-y1)*s;
    return (lineX > x);
  } else {
    return false;
  }
}

// Checks to see if a line originating from x,y along the +ve x axis
// intersects the given bezier.
// It is assumed that the line originates from within the bounding box of
// the bezier and that the curve has no dy=0 inflection points.
// Returns the number of intersections found (which is either 1 or 0).
int nvg__intersectBezier (const(float)* points, float x, float y) {
  immutable float x0 = points[0*2+0], x1 = points[1*2+0], x2 = points[2*2+0], x3 = points[3*2+0];
  immutable float y0 = points[0*2+1], y1 = points[1*2+1], y2 = points[2*2+1], y3 = points[3*2+1];

  if (y0 == y1 && y1 == y2 && y2 == y3) return 0;

  // Initial t guess
  float t = void;
       if (y3 != y0) t = (y-y0)/(y3-y0);
  else if (x3 != x0) t = (x-x0)/(x3-x0);
  else t = 0.5f;

  // A few Newton iterations
  for (int iter = 0; iter < 6; ++iter) {
    immutable float omt = 1-t;
    immutable float omt2 = omt*omt;
    immutable float t2 = t*t;
    immutable float omt3 = omt2*omt;
    immutable float t3 = t2*t;

    immutable float ty = y0*omt3 +
      y1*3.0f*omt2*t +
      y2*3.0f*omt*t2 +
      y3*t3;

    // Newton iteration
    immutable float dty = 3.0f*omt2*(y1-y0) +
      6.0f*omt*t*(y2-y1) +
      3.0f*t2*(y3-y2);

    // dty will never == 0 since:
    //  Either omt, omt2 are zero OR t2 is zero
    //  y0 != y1 != y2 != y3 (checked above)
    t = t-(ty-y)/dty;
  }

  {
    immutable float omt = 1-t;
    immutable float omt2 = omt*omt;
    immutable float t2 = t*t;
    immutable float omt3 = omt2*omt;
    immutable float t3 = t2*t;

    immutable float tx =
      x0*omt3+
      x1*3.0f*omt2*t+
      x2*3.0f*omt*t2+
      x3*t3;

    return (tx > x ? 1 : 0);
  }
}

// Finds the closest point on a line to a given point
void nvg__closestLine (const(float)* points, float x, float y, float* closest, float* ot) {
  immutable float x1 = points[0];
  immutable float y1 = points[1];
  immutable float x2 = points[2];
  immutable float y2 = points[3];
  immutable float pqx = x2-x1;
  immutable float pqz = y2-y1;
  immutable float dx = x-x1;
  immutable float dz = y-y1;
  immutable float d = pqx*pqx+pqz*pqz;
  float t = pqx*dx+pqz*dz;
  if (d > 0) t /= d;
  if (t < 0) t = 0; else if (t > 1) t = 1;
  closest[0] = x1+t*pqx;
  closest[1] = y1+t*pqz;
  *ot = t;
}

// Finds the closest point on a curve for a given point (x,y).
// Assumes that the curve has no dx==0 or dy==0 inflection points.
void nvg__closestBezier (const(float)* points, float x, float y, float* closest, float *ot) {
  immutable float x0 = points[0*2+0], x1 = points[1*2+0], x2 = points[2*2+0], x3 = points[3*2+0];
  immutable float y0 = points[0*2+1], y1 = points[1*2+1], y2 = points[2*2+1], y3 = points[3*2+1];

  // This assumes that the curve has no dy=0 inflection points.

  // Initial t guess
  float t = 0.5f;

  // A few Newton iterations
  for (int iter = 0; iter < 6; ++iter) {
    immutable float omt = 1-t;
    immutable float omt2 = omt*omt;
    immutable float t2 = t*t;
    immutable float omt3 = omt2*omt;
    immutable float t3 = t2*t;

    immutable float ty =
      y0*omt3+
      y1*3.0f*omt2*t+
      y2*3.0f*omt*t2+
      y3*t3;

    immutable float tx =
      x0*omt3+
      x1*3.0f*omt2*t+
      x2*3.0f*omt*t2+
      x3*t3;

    // Newton iteration
    immutable float dty =
      3.0f*omt2*(y1-y0)+
      6.0f*omt*t*(y2-y1)+
      3.0f*t2*(y3-y2);

    immutable float ddty =
      6.0f*omt*(y2-2.0f*y1+y0)+
      6.0f*t*(y3-2.0f*y2+y1);

    immutable float dtx =
      3.0f*omt2*(x1-x0)+
      6.0f*omt*t*(x2-x1)+
      3.0f*t2*(x3-x2);

    immutable float ddtx =
      6.0f*omt*(x2-2.0f*x1+x0)+
      6.0f*t*(x3-2.0f*x2+x1);

    immutable float errorx = tx-x;
    immutable float errory = ty-y;

    immutable float n = errorx*dtx+errory*dty;
    if (n == 0) break;

    immutable float d = dtx*dtx+dty*dty+errorx*ddtx+errory*ddty;
    if (d != 0) t = t-n/d; else break;
  }

  t = nvg__max(0, nvg__min(1.0, t));
  *ot = t;
  {
    immutable float omt = 1-t;
    immutable float omt2 = omt*omt;
    immutable float t2 = t*t;
    immutable float omt3 = omt2*omt;
    immutable float t3 = t2*t;

    immutable float ty =
      y0*omt3+
      y1*3.0f*omt2*t+
      y2*3.0f*omt*t2+
      y3*t3;

    immutable float tx =
      x0*omt3+
      x1*3.0f*omt2*t+
      x2*3.0f*omt*t2+
      x3*t3;

    closest[0] = tx;
    closest[1] = ty;
  }
}

// Returns:
//  1  If (x,y) is contained by the stroke of the path
//  0  If (x,y) is not contained by the path.
int nvg__pickSubPathStroke (const NVGpickScene* ps, const NVGpickSubPath* psp, float x, float y, float strokeWidth, int lineCap, int lineJoin) {
  if (nvg__pointInBounds(x, y, psp.bounds) == 0) return 0;

  float[2] closest = void;
  float[2] d = void;
  float t = void;

  // trace a line from x,y out along the positive x axis and count the number of intersections
  int nsegments = psp.nsegments;
  const(NVGsegment)* seg = ps.segments+psp.firstSegment;
  const(NVGsegment)* prevseg = (psp.closed ? &ps.segments[psp.firstSegment+nsegments-1] : null);
  immutable float strokeWidthSqd = strokeWidth*strokeWidth;

  for (int s = 0; s < nsegments; ++s, prevseg = seg, ++seg) {
    if (nvg__pointInBounds(x, y, seg.bounds) != 0) {
      // Line potentially hits stroke.
      switch (seg.type) {
        case Command.LineTo:
          nvg__closestLine(&ps.points[seg.firstPoint*2], x, y, closest.ptr, &t);
          break;
        case Command.BezierTo:
          nvg__closestBezier(&ps.points[seg.firstPoint*2], x, y, closest.ptr, &t);
          break;
        default:
          continue;
      }

      d.ptr[0] = x-closest.ptr[0];
      d.ptr[1] = y-closest.ptr[1];

      if ((t >= NVG_PICK_EPS && t <= 1.0f-NVG_PICK_EPS) ||
          (seg.flags&(NVG_PICK_CORNER|NVG_PICK_CAP|NVG_PICK_ENDCAP)) == 0 ||
          (lineJoin == NVGLineCap.Round))
      {
        // Closest point is in the middle of the line/curve, at a rounded join/cap
        // or at a smooth join
        immutable float distSqd = d.ptr[0]*d.ptr[0]+d.ptr[1]*d.ptr[1];
        if (distSqd < strokeWidthSqd) return 1;
      } else if ( ( (t > (1.0f-NVG_PICK_EPS)) && (seg.flags&NVG_PICK_ENDCAP)) ||
            ( (t < NVG_PICK_EPS) && (seg.flags&NVG_PICK_CAP) ) ) {
        switch (lineCap) {
          case NVGLineCap.Butt:
            immutable float distSqd = d.ptr[0]*d.ptr[0]+d.ptr[1]*d.ptr[1];
            immutable float dirD = (t < NVG_PICK_EPS ?
              -(d.ptr[0]*seg.startDir.ptr[0]+d.ptr[1]*seg.startDir.ptr[1]) :
                d.ptr[0]*seg.endDir.ptr[0]+d.ptr[1]*seg.endDir.ptr[1]);
            if (dirD < -NVG_PICK_EPS && distSqd < strokeWidthSqd) return 1;
            break;
          case NVGLineCap.Square:
            if (nvg__absf(d.ptr[0]) < strokeWidth && nvg__absf(d.ptr[1]) < strokeWidth) return 1;
            break;
          case NVGLineCap.Round:
            immutable float distSqd = d.ptr[0]*d.ptr[0]+d.ptr[1]*d.ptr[1];
            if (distSqd < strokeWidthSqd) return 1;
            break;
          default:
            break;
        }
      } else if (seg.flags&NVG_PICK_CORNER) {
        // Closest point is at a corner
        const(NVGsegment)* seg0, seg1;

        if (t < NVG_PICK_EPS) {
          seg0 = prevseg;
          seg1 = seg;
        } else {
          seg0 = seg;
          seg1 = (s == nsegments-1 ? &ps.segments[psp.firstSegment] : seg+1);
        }

        if (!(seg1.flags&NVG_PICK_BEVEL)) {
          immutable float prevNDist = -seg0.endDir.ptr[1]*d.ptr[0]+seg0.endDir.ptr[0]*d.ptr[1];
          immutable float curNDist = seg1.startDir.ptr[1]*d.ptr[0]-seg1.startDir.ptr[0]*d.ptr[1];
          if (nvg__absf(prevNDist) < strokeWidth && nvg__absf(curNDist) < strokeWidth) return 1;
        } else {
          d.ptr[0] -= -seg1.startDir.ptr[1]*strokeWidth;
          d.ptr[1] -= +seg1.startDir.ptr[0]*strokeWidth;
          if (seg1.miterDir.ptr[0]*d.ptr[0]+seg1.miterDir.ptr[1]*d.ptr[1] < 0) return 1;
        }
      }
    }
  }

  return 0;
}

// Returns:
//   1  If (x,y) is contained by the path and the path is solid.
//  -1  If (x,y) is contained by the path and the path is a hole.
//   0  If (x,y) is not contained by the path.
int nvg__pickSubPath (const NVGpickScene* ps, const NVGpickSubPath* psp, float x, float y, bool evenOddMode) {
  if (nvg__pointInBounds(x, y, psp.bounds) == 0) return 0;

  const(NVGsegment)* seg = &ps.segments[psp.firstSegment];
  int nsegments = psp.nsegments;
  int nintersections = 0;

  // trace a line from x,y out along the positive x axis and count the number of intersections
  for (int s = 0; s < nsegments; ++s, ++seg) {
    if ((seg.bounds.ptr[1]-NVG_PICK_EPS) < y &&
        (seg.bounds.ptr[3]-NVG_PICK_EPS) > y &&
        seg.bounds.ptr[2] > x)
    {
      // Line hits the box.
      switch (seg.type) {
        case Command.LineTo:
          if (seg.bounds.ptr[0] > x) {
            // line originates outside the box
            ++nintersections;
          } else {
            // line originates inside the box
            nintersections += nvg__intersectLine(&ps.points[seg.firstPoint*2], x, y);
          }
          break;
        case Command.BezierTo:
          if (seg.bounds.ptr[0] > x) {
            // line originates outside the box
            ++nintersections;
          } else {
            // line originates inside the box
            nintersections += nvg__intersectBezier(&ps.points[seg.firstPoint*2], x, y);
          }
          break;
        default:
          break;
      }
    }
  }

  if (evenOddMode) {
    return nintersections;
  } else {
    return (nintersections&1 ? (psp.winding == NVGSolidity.Solid ? 1 : -1) : 0);
  }
}

bool nvg__pickPath (const(NVGpickScene)* ps, const(NVGpickPath)* pp, float x, float y) {
  int pickCount = 0;
  const(NVGpickSubPath)* psp = pp.subPaths;
  while (psp !is null) {
    pickCount += nvg__pickSubPath(ps, psp, x, y, pp.evenOddMode);
    psp = psp.next;
  }
  return ((pp.evenOddMode ? pickCount&1 : pickCount) != 0);
}

bool nvg__pickPathStroke (const(NVGpickScene)* ps, const(NVGpickPath)* pp, float x, float y) {
  const(NVGpickSubPath)* psp = pp.subPaths;
  while (psp !is null) {
    if (nvg__pickSubPathStroke(ps, psp, x, y, pp.strokeWidth, pp.lineCap, pp.lineJoin)) return true;
    psp = psp.next;
  }
  return false;
}

bool nvg__pickPathTestBounds (const NVGpickScene* ps, const NVGpickPath* pp, float x, float y) {
  if (nvg__pointInBounds(x, y, pp.bounds) != 0) {
    if (pp.flags&NVG_PICK_SCISSOR) {
      const(float)* scissor = &ps.points[pp.scissor*2];
      float rx = x-scissor[4];
      float ry = y-scissor[5];
      if (nvg__absf((scissor[0]*rx)+(scissor[1]*ry)) > scissor[6] ||
          nvg__absf((scissor[2]*rx)+(scissor[3]*ry)) > scissor[7])
      {
        return false;
      }
    }
    return true;
  }
  return false;
}

int nvg__countBitsUsed (int v) {
  pragma(inline, true);
  import core.bitop : popcnt;
  return (v != 0 ? popcnt(cast(uint)v) : 0);
}

void nvg__pickSceneInsert (NVGpickScene* ps, NVGpickPath* pp) {
  if (ps is null || pp is null) return;

  int[4] cellbounds;
  int base = ps.nlevels-1;
  int level;
  int levelwidth;
  int levelshift;
  int levelx;
  int levely;
  NVGpickPath** cell = null;

  // Bit tricks for inserting into an implicit quadtree.

  // Calc bounds of path in cells at the lowest level
  cellbounds.ptr[0] = cast(int)(pp.bounds.ptr[0]/ps.xdim);
  cellbounds.ptr[1] = cast(int)(pp.bounds.ptr[1]/ps.ydim);
  cellbounds.ptr[2] = cast(int)(pp.bounds.ptr[2]/ps.xdim);
  cellbounds.ptr[3] = cast(int)(pp.bounds.ptr[3]/ps.ydim);

  // Find which bits differ between the min/max x/y coords
  cellbounds.ptr[0] ^= cellbounds.ptr[2];
  cellbounds.ptr[1] ^= cellbounds.ptr[3];

  // Use the number of bits used (countBitsUsed(x) == sizeof(int) * 8 - clz(x);
  // to calculate the level to insert at (the level at which the bounds fit in a single cell)
  level = nvg__min(base-nvg__countBitsUsed(cellbounds.ptr[0]), base-nvg__countBitsUsed(cellbounds.ptr[1]));
  if (level < 0) level = 0;

  // Find the correct cell in the chosen level, clamping to the edges.
  levelwidth = 1<<level;
  levelshift = (ps.nlevels-level)-1;
  levelx = nvg__clamp(cellbounds.ptr[2]>>levelshift, 0, levelwidth-1);
  levely = nvg__clamp(cellbounds.ptr[3]>>levelshift, 0, levelwidth-1);

  // Insert the path into the linked list at that cell.
  cell = &ps.levels[level][levely*levelwidth+levelx];

  pp.cellnext = *cell;
  *cell = pp;

  if (ps.paths is null) ps.lastPath = pp;
  pp.next = ps.paths;
  ps.paths = pp;

  // Store the order (depth) of the path for picking ops.
  pp.order = cast(short)ps.npaths;
  ++ps.npaths;
}

void nvg__pickBeginFrame (NVGcontext* ctx, int width, int height) {
  NVGpickScene* ps = nvg__pickSceneGet(ctx);

  //NVG_PICK_DEBUG_NEWFRAME();

  // Return all paths & sub paths from last frame to the free list
  while (ps.paths !is null) {
    NVGpickPath* pp = ps.paths.next;
    nvg__freePickPath(ps, ps.paths);
    ps.paths = pp;
  }

  ps.paths = null;
  ps.npaths = 0;

  // Store the screen metrics for the quadtree
  ps.width = width;
  ps.height = height;

  immutable float lowestSubDiv = cast(float)(1<<(ps.nlevels-1));
  ps.xdim = cast(float)width/lowestSubDiv;
  ps.ydim = cast(float)height/lowestSubDiv;

  // Allocate the quadtree if required.
  if (ps.levels is null) {
    int ncells = 1;

    ps.levels = cast(NVGpickPath***)malloc((NVGpickPath**).sizeof*ps.nlevels);
    for (int l = 0; l < ps.nlevels; ++l) {
      int leveldim = 1<<l;
      ncells += leveldim*leveldim;
    }

    ps.levels[0] = cast(NVGpickPath**)malloc((NVGpickPath*).sizeof*ncells);

    int cell = 1;
    for (int l = 1; l < ps.nlevels; ++l) {
      ps.levels[l] = &ps.levels[0][cell];
      int leveldim = 1<<l;
      cell += leveldim*leveldim;
    }

    ps.ncells = ncells;
  }
  memset(ps.levels[0], 0, ps.ncells*(NVGpickPath*).sizeof);

  // Allocate temporary storage for nvgHitTestAll results if required.
  if (ps.picked is null) {
    ps.cpicked = 16;
    ps.picked = cast(NVGpickPath**)malloc((NVGpickPath*).sizeof*ps.cpicked);
  }

  ps.npoints = 0;
  ps.nsegments = 0;
}
} // nothrow @trusted @nogc


// ////////////////////////////////////////////////////////////////////////// //
/// <h1>Text</h1>
//
/** NanoVega allows you to load .ttf files and use the font to render text.
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
 * Returns handle to the font or FONS_INVALID (aka -1) on error.
 * use "fontname:noaa" as `name` to turn off antialiasing (if font driver supports that).
 * Maximum font name length is 63 chars, and it will be truncated.
 *
 * On POSIX systems it is possible to use fontconfig font names too.
 * `:noaa` in font path is still allowed, but it must be the last option.
 */
public int createFont (NVGContext ctx, const(char)[] name, const(char)[] path) nothrow @trusted {
  return fonsAddFont(ctx.fs, name, path, ctx.params.fontAA);
}

/** Creates font by loading it from the specified memory chunk.
 * Returns handle to the font or FONS_INVALID (aka -1) on error.
 * Won't free data on error.
 * Maximum font name length is 63 chars, and it will be truncated. */
public int createFontMem (NVGContext ctx, const(char)[] name, ubyte* data, int ndata, bool freeData) nothrow @trusted @nogc {
  return fonsAddFontMem(ctx.fs, name, data, ndata, freeData, ctx.params.fontAA);
}

/// Finds a loaded font of specified name, and returns handle to it, or FONS_INVALID (aka -1) if the font is not found.
public int findFont (NVGContext ctx, const(char)[] name) nothrow @trusted @nogc {
  pragma(inline, true);
  return (name.length == 0 ? FONS_INVALID : fonsGetFontByName(ctx.fs, name));
}

/// Sets the font size of current text style.
public void fontSize (NVGContext ctx, float size) nothrow @trusted @nogc {
  pragma(inline, true);
  nvg__getState(ctx).fontSize = size;
}

/// Gets the font size of current text style.
public float fontSize (NVGContext ctx) nothrow @trusted @nogc {
  pragma(inline, true);
  return nvg__getState(ctx).fontSize;
}

/// Sets the blur of current text style.
public void fontBlur (NVGContext ctx, float blur) nothrow @trusted @nogc {
  pragma(inline, true);
  nvg__getState(ctx).fontBlur = blur;
}

/// Gets the blur of current text style.
public float fontBlur (NVGContext ctx) nothrow @trusted @nogc {
  pragma(inline, true);
  return nvg__getState(ctx).fontBlur;
}

/// Sets the letter spacing of current text style.
public void textLetterSpacing (NVGContext ctx, float spacing) nothrow @trusted @nogc {
  pragma(inline, true);
  nvg__getState(ctx).letterSpacing = spacing;
}

/// Gets the letter spacing of current text style.
public float textLetterSpacing (NVGContext ctx) nothrow @trusted @nogc {
  pragma(inline, true);
  return nvg__getState(ctx).letterSpacing;
}

/// Sets the proportional line height of current text style. The line height is specified as multiple of font size.
public void textLineHeight (NVGContext ctx, float lineHeight) nothrow @trusted @nogc {
  pragma(inline, true);
  nvg__getState(ctx).lineHeight = lineHeight;
}

/// Gets the proportional line height of current text style. The line height is specified as multiple of font size.
public float textLineHeight (NVGContext ctx) nothrow @trusted @nogc {
  pragma(inline, true);
  return nvg__getState(ctx).lineHeight;
}

/// Sets the text align of current text style, see `NVGTextAlign` for options.
public void textAlign (NVGContext ctx, NVGTextAlign talign) nothrow @trusted @nogc {
  pragma(inline, true);
  nvg__getState(ctx).textAlign = talign;
}

/// Ditto.
public void textAlign (NVGContext ctx, NVGTextAlign.H h) nothrow @trusted @nogc {
  pragma(inline, true);
  nvg__getState(ctx).textAlign.horizontal = h;
}

/// Ditto.
public void textAlign (NVGContext ctx, NVGTextAlign.V v) nothrow @trusted @nogc {
  pragma(inline, true);
  nvg__getState(ctx).textAlign.vertical = v;
}

/// Ditto.
public void textAlign (NVGContext ctx, NVGTextAlign.H h, NVGTextAlign.V v) nothrow @trusted @nogc {
  pragma(inline, true);
  nvg__getState(ctx).textAlign.reset(h, v);
}

/// Ditto.
public void textAlign (NVGContext ctx, NVGTextAlign.V v, NVGTextAlign.H h) nothrow @trusted @nogc {
  pragma(inline, true);
  nvg__getState(ctx).textAlign.reset(h, v);
}

/// Gets the text align of current text style, see `NVGTextAlign` for options.
public NVGTextAlign textAlign (NVGContext ctx) nothrow @trusted @nogc {
  pragma(inline, true);
  return nvg__getState(ctx).textAlign;
}

/// Sets the font face based on specified id of current text style.
public void fontFaceId (NVGContext ctx, int font) nothrow @trusted @nogc {
  pragma(inline, true);
  nvg__getState(ctx).fontId = font;
}

/// Gets the font face based on specified id of current text style.
public int fontFaceId (NVGContext ctx) nothrow @trusted @nogc {
  pragma(inline, true);
  return nvg__getState(ctx).fontId;
}

/// Sets the font face based on specified name of current text style.
public void fontFace (NVGContext ctx, const(char)[] font) nothrow @trusted @nogc {
  pragma(inline, true);
  nvg__getState(ctx).fontId = fonsGetFontByName(ctx.fs, font);
}

float nvg__quantize (float a, float d) pure nothrow @safe @nogc {
  pragma(inline, true);
  return (cast(int)(a/d+0.5f))*d;
}

float nvg__getFontScale (NVGstate* state) nothrow @safe @nogc {
  pragma(inline, true);
  return nvg__min(nvg__quantize(nvg__getAverageScale(state.xform[]), 0.01f), 4.0f);
}

void nvg__flushTextTexture (NVGContext ctx) nothrow @trusted @nogc {
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

bool nvg__allocTextAtlas (NVGContext ctx) nothrow @trusted @nogc {
  int iw, ih;
  nvg__flushTextTexture(ctx);
  if (ctx.fontImageIdx >= NVG_MAX_FONTIMAGES-1) return false;
  // if next fontImage already have a texture
  if (ctx.fontImages[ctx.fontImageIdx+1] != 0) {
    ctx.imageSize(ctx.fontImages[ctx.fontImageIdx+1], iw, ih);
  } else {
    // calculate the new font image size and create it
    ctx.imageSize(ctx.fontImages[ctx.fontImageIdx], iw, ih);
    if (iw > ih) ih *= 2; else iw *= 2;
    if (iw > NVG_MAX_FONTIMAGE_SIZE || ih > NVG_MAX_FONTIMAGE_SIZE) iw = ih = NVG_MAX_FONTIMAGE_SIZE;
    ctx.fontImages[ctx.fontImageIdx+1] = ctx.params.renderCreateTexture(ctx.params.userPtr, NVGtexture.Alpha, iw, ih, (ctx.params.fontAA ? 0 : NVGImageFlags.NoFiltering), null);
  }
  ++ctx.fontImageIdx;
  fonsResetAtlas(ctx.fs, iw, ih);
  return true;
}

void nvg__renderText (NVGContext ctx, NVGvertex* verts, int nverts) nothrow @trusted @nogc {
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
public float text(T) (NVGContext ctx, float x, float y, const(T)[] str) nothrow @trusted @nogc if (isAnyCharType!T) {
  NVGstate* state = nvg__getState(ctx);
  FONStextIter!T iter, prevIter;
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

  fonsTextIterInit(ctx.fs, &iter, x*scale, y*scale, str, FONS_GLYPH_BITMAP_REQUIRED);
  prevIter = iter;
  while (fonsTextIterNext(ctx.fs, &iter, &q)) {
    float[4*2] c = void;
    if (iter.prevGlyphIndex < 0) { // can not retrieve glyph?
      if (nverts != 0) {
        // TODO: add back-end bit to do this just once per frame
        nvg__flushTextTexture(ctx);
        nvg__renderText(ctx, verts, nverts);
        nverts = 0;
      }
      if (!nvg__allocTextAtlas(ctx)) break; // no memory :(
      iter = prevIter;
      fonsTextIterNext(ctx.fs, &iter, &q); // try again
      if (iter.prevGlyphIndex < 0) {
        // still can not find glyph, try replacement
        iter = prevIter;
        if (!fonsTextIterGetDummyChar(ctx.fs, &iter, &q)) break;
      }
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
  if (nverts > 0) {
    nvg__flushTextTexture(ctx);
    nvg__renderText(ctx, verts, nverts);
  }

  return iter.nextx/scale;
}

/** Draws multi-line text string at specified location wrapped at the specified width.
 * White space is stripped at the beginning of the rows, the text is split at word boundaries or when new-line characters are encountered.
 * Words longer than the max width are slit at nearest character (i.e. no hyphenation). */
public void textBox(T) (NVGContext ctx, float x, float y, float breakRowWidth, const(T)[] str) nothrow @trusted @nogc if (isAnyCharType!T) {
  NVGstate* state = nvg__getState(ctx);
  if (state.fontId == FONS_INVALID) return;

  NVGTextRow!T[2] rows;
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
        case NVGTextAlign.H.Left: ctx.text(x, y, row.row); break;
        case NVGTextAlign.H.Center: ctx.text(x+breakRowWidth*0.5f-row.width*0.5f, y, row.row); break;
        case NVGTextAlign.H.Right: ctx.text(x+breakRowWidth-row.width, y, row.row); break;
      }
      y += lineh*state.lineHeight;
    }
    str = rres[$-1].rest;
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

/** Calculates the glyph x positions of the specified text.
 * Measured values are returned in local coordinate space.
 */
public NVGGlyphPosition[] textGlyphPositions(T) (NVGContext ctx, float x, float y, const(T)[] str, NVGGlyphPosition[] positions) nothrow @trusted @nogc
if (isAnyCharType!T)
{
  if (str.length == 0 || positions.length == 0) return positions[0..0];
  usize posnum;
  auto len = ctx.textGlyphPositions(x, y, str, (in ref NVGGlyphPosition pos) {
    positions.ptr[posnum++] = pos;
    return (posnum < positions.length);
  });
  return positions[0..len];
}

/// Ditto.
public int textGlyphPositions(T, DG) (NVGContext ctx, float x, float y, const(T)[] str, scope DG dg)
if (isAnyCharType!T && isGoodPositionDelegate!DG)
{
  import std.traits : ReturnType;
  static if (is(ReturnType!dg == void)) enum RetBool = false; else enum RetBool = true;

  NVGstate* state = nvg__getState(ctx);
  float scale = nvg__getFontScale(state)*ctx.devicePxRatio;
  float invscale = 1.0f/scale;
  FONStextIter!T iter, prevIter;
  FONSquad q;
  int npos = 0;

  if (str.length == 0) return 0;

  fonsSetSize(ctx.fs, state.fontSize*scale);
  fonsSetSpacing(ctx.fs, state.letterSpacing*scale);
  fonsSetBlur(ctx.fs, state.fontBlur*scale);
  fonsSetAlign(ctx.fs, state.textAlign);
  fonsSetFont(ctx.fs, state.fontId);

  fonsTextIterInit(ctx.fs, &iter, x*scale, y*scale, str, FONS_GLYPH_BITMAP_OPTIONAL);
  prevIter = iter;
  while (fonsTextIterNext(ctx.fs, &iter, &q)) {
    if (iter.prevGlyphIndex < 0) { // can not retrieve glyph?
      if (!nvg__allocTextAtlas(ctx)) break; // no memory
      iter = prevIter;
      fonsTextIterNext(ctx.fs, &iter, &q); // try again
      if (iter.prevGlyphIndex < 0) {
        // still can not find glyph, try replacement
        iter = prevIter;
        if (!fonsTextIterGetDummyChar(ctx.fs, &iter, &q)) break;
      }
    }
    prevIter = iter;
    NVGGlyphPosition position = void; //WARNING!
    position.strpos = cast(usize)(iter.string-str.ptr);
    position.x = iter.x*invscale;
    position.minx = nvg__min(iter.x, q.x0)*invscale;
    position.maxx = nvg__max(iter.nextx, q.x1)*invscale;
    ++npos;
    static if (RetBool) { if (!dg(position)) return npos; } else dg(position);
  }

  return npos;
}

private template isGoodRowDelegate(CT, DG) {
  private DG dg;
  static if (is(typeof({ NVGTextRow!CT row; bool res = dg(row); })) ||
             is(typeof({ NVGTextRow!CT row; dg(row); })))
    enum isGoodRowDelegate = true;
  else
    enum isGoodRowDelegate = false;
}

/** Breaks the specified text into lines.
 * White space is stripped at the beginning of the rows, the text is split at word boundaries or when new-line characters are encountered.
 * Words longer than the max width are slit at nearest character (i.e. no hyphenation).
 */
public NVGTextRow!T[] textBreakLines(T) (NVGContext ctx, const(T)[] str, float breakRowWidth, NVGTextRow!T[] rows) nothrow @trusted @nogc
if (isAnyCharType!T)
{
  if (rows.length == 0) return rows;
  if (rows.length > int.max-1) rows = rows[0..int.max-1];
  int nrow = 0;
  auto count = ctx.textBreakLines(str, breakRowWidth, (in ref NVGTextRow!T row) {
    rows[nrow++] = row;
    return (nrow < rows.length);
  });
  return rows[0..count];
}

/// Ditto.
public int textBreakLines(T, DG) (NVGContext ctx, const(T)[] str, float breakRowWidth, scope DG dg)
if (isAnyCharType!T && isGoodRowDelegate!(T, DG))
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
  FONStextIter!T iter, prevIter;
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

  fonsTextIterInit(ctx.fs, &iter, 0, 0, str, FONS_GLYPH_BITMAP_OPTIONAL);
  prevIter = iter;
  while (fonsTextIterNext(ctx.fs, &iter, &q)) {
    if (iter.prevGlyphIndex < 0) { // can not retrieve glyph?
      if (!nvg__allocTextAtlas(ctx)) break; // no memory
      iter = prevIter;
      fonsTextIterNext(ctx.fs, &iter, &q); // try again
      if (iter.prevGlyphIndex < 0) {
        // still can not find glyph, try replacement
        iter = prevIter;
        if (!fonsTextIterGetDummyChar(ctx.fs, &iter, &q)) break;
      }
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
      rowStart = cast(int)(iter.string-str.ptr);
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
      NVGTextRow!T row;
      row.string = str;
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
        rowEnd = cast(int)(iter.nextp-str.ptr);
        rowWidth = iter.nextx-rowStartX;
        rowMaxX = q.x1-rowStartX;
      }
      // track last end of a word
      if (ptype == NVGcodepointType.Char && type == NVGcodepointType.Space) {
        breakEnd = cast(int)(iter.string-str.ptr);
        breakWidth = rowWidth;
        breakMaxX = rowMaxX;
      }
      // track last beginning of a word
      if (ptype == NVGcodepointType.Space && type == NVGcodepointType.Char) {
        wordStart = cast(int)(iter.string-str.ptr);
        wordStartX = iter.x;
        wordMinX = q.x0-rowStartX;
      }
      // break to new line when a character is beyond break width
      if (type == NVGcodepointType.Char && nextWidth > breakRowWidth) {
        // the run length is too long, need to break to new line
        NVGTextRow!T row;
        row.string = str;
        if (breakEnd == rowStart) {
          // the current word is longer than the row length, just break it from here
          row.start = rowStart;
          row.end = cast(int)(iter.string-str.ptr);
          row.width = rowWidth*invscale;
          row.minx = rowMinX*invscale;
          row.maxx = rowMaxX*invscale;
          ++nrows;
          static if (RetBool) { if (!dg(row)) return nrows; } else dg(row);
          rowStartX = iter.x;
          rowStart = cast(int)(iter.string-str.ptr);
          rowEnd = cast(int)(iter.nextp-str.ptr);
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
          rowEnd = cast(int)(iter.nextp-str.ptr);
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
    NVGTextRow!T row;
    row.string = str;
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
  this (NVGContext actx, float ax, float ay) nothrow @trusted @nogc { reset(actx, ax, ay); }

  void reset (NVGContext actx, float ax, float ay) nothrow @trusted @nogc {
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
  void restart () nothrow @trusted @nogc {
    if (ctx !is null) fsiter.reset(ctx.fs, xscaled, yscaled);
  }

  /// Restore font settings for the context.
  void restoreFont () nothrow @trusted @nogc {
    if (ctx !is null) {
      fonsSetSize(ctx.fs, fsSize);
      fonsSetSpacing(ctx.fs, fsSpacing);
      fonsSetBlur(ctx.fs, fsBlur);
      fonsSetAlign(ctx.fs, fsAlign);
      fonsSetFont(ctx.fs, fsFontId);
    }
  }

  /// Is this iterator valid?
  @property bool valid () const pure nothrow @safe @nogc => (ctx !is null);

  /// Add chars.
  void put(T) (const(T)[] str...) nothrow @trusted @nogc if (isAnyCharType!T) { if (ctx !is null) fsiter.put(str[]); }

  /// Return current advance
  @property float advance () const pure nothrow @safe @nogc => (ctx !is null ? fsiter.advance*invscale : 0);

  /// Return current text bounds.
  void getBounds (ref float[4] bounds) nothrow @trusted @nogc {
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
  void getHBounds (out float xmin, out float xmax) nothrow @trusted @nogc {
    if (ctx !is null) {
      fsiter.getHBounds(xmin, xmax);
      xmin *= invscale;
      xmax *= invscale;
    }
  }

  /// Return current vertical text bounds.
  void getVBounds (out float ymin, out float ymax) nothrow @trusted @nogc {
    if (ctx !is null) {
      //fsiter.getVBounds(ymin, ymax);
      fonsLineBounds(ctx.fs, yscaled, &ymin, &ymax);
      ymin *= invscale;
      ymax *= invscale;
    }
  }
}

/** Return font line height (without line spacing), measured in local coordinate space. */
public float textFontHeight (NVGContext ctx) nothrow @trusted @nogc {
  float res = void;
  ctx.textMetrics(null, null, &res);
  return res;
}

/** Return font ascender, measured in local coordinate space. */
public float textFontAscender (NVGContext ctx) nothrow @trusted @nogc {
  float res = void;
  ctx.textMetrics(&res, null, null);
  return res;
}

/** Return font descender, measured in local coordinate space. */
public float textFontDescender (NVGContext ctx) nothrow @trusted @nogc {
  float res = void;
  ctx.textMetrics(null, &res, null);
  return res;
}

/** Measures the specified text string. Returns horizontal and vertical sizes of the measured text.
 * Measured values are returned in local coordinate space.
 */
public void textExtents(T) (NVGContext ctx, const(T)[] str, float *w, float *h) nothrow @trusted @nogc if (isAnyCharType!T) {
  float[4] bnd = void;
  ctx.textBounds(0, 0, str, bnd[]);
  if (!fonsGetFontAA(ctx.fs, nvg__getState(ctx).fontId)) {
    if (w !is null) *w = nvg__lrintf(bnd.ptr[2]-bnd.ptr[0]);
    if (h !is null) *h = nvg__lrintf(bnd.ptr[3]-bnd.ptr[1]);
  } else {
    if (w !is null) *w = bnd.ptr[2]-bnd.ptr[0];
    if (h !is null) *h = bnd.ptr[3]-bnd.ptr[1];
  }
}

/** Measures the specified text string. Returns horizontal size of the measured text.
 * Measured values are returned in local coordinate space.
 */
public float textWidth(T) (NVGContext ctx, const(T)[] str) nothrow @trusted @nogc if (isAnyCharType!T) {
  float w = void;
  ctx.textExtents(str, &w, null);
  return w;
}

/** Measures the specified text string. Parameter bounds should be a float[4],
 * if the bounding box of the text should be returned. The bounds value are [xmin, ymin, xmax, ymax]
 * Returns the horizontal advance of the measured text (i.e. where the next character should drawn).
 * Measured values are returned in local coordinate space.
 */
public float textBounds(T) (NVGContext ctx, float x, float y, const(T)[] str, float[] bounds) nothrow @trusted @nogc
if (isAnyCharType!T)
{
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
public void textBoxBounds(T) (NVGContext ctx, float x, float y, float breakRowWidth, const(T)[] str, float[] bounds) if (isAnyCharType!T) {
  NVGstate* state = nvg__getState(ctx);
  NVGTextRow!T[2] rows;
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
    str = rres[$-1].rest;
  }

  if (bounds.length) {
    if (bounds.length > 0) bounds.ptr[0] = minx;
    if (bounds.length > 1) bounds.ptr[1] = miny;
    if (bounds.length > 2) bounds.ptr[2] = maxx;
    if (bounds.length > 3) bounds.ptr[3] = maxy;
  }
}

/// Returns the vertical metrics based on the current text style. Measured values are returned in local coordinate space.
public void textMetrics (NVGContext ctx, float* ascender, float* descender, float* lineh) nothrow @trusted @nogc {
  NVGstate* state = nvg__getState(ctx);

  if (state.fontId == FONS_INVALID) {
    if (ascender !is null) *ascender *= 0;
    if (descender !is null) *descender *= 0;
    if (lineh !is null) *lineh *= 0;
    return;
  }

  immutable float scale = nvg__getFontScale(state)*ctx.devicePxRatio;
  immutable float invscale = 1.0f/scale;

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

alias FONSglyphBitmap = int;
enum /*FONSglyphBitmap*/ {
  FONS_GLYPH_BITMAP_OPTIONAL = 1,
  FONS_GLYPH_BITMAP_REQUIRED = 2,
};

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
  bool function (void* uptr, int width, int height) nothrow @trusted @nogc renderCreate;
  int function (void* uptr, int width, int height) nothrow @trusted @nogc renderResize;
  void function (void* uptr, int* rect, const(ubyte)* data) nothrow @trusted @nogc renderUpdate;
  void function (void* uptr, const(float)* verts, const(float)* tcoords, const(uint)* colors, int nverts) nothrow @trusted @nogc renderDraw;
  void function (void* uptr) nothrow @trusted @nogc renderDelete;
}

struct FONSquad {
  float x0=0, y0=0, s0=0, t0=0;
  float x1=0, y1=0, s1=0, t1=0;
}

struct FONStextIter(CT) if (isAnyCharType!CT) {
  alias CharType = CT;
  float x=0, y=0, nextx=0, nexty=0, scale=0, spacing=0;
  uint codepoint;
  short isize, iblur;
  FONSfont* font;
  int prevGlyphIndex;
  const(CT)* s; // string
  const(CT)* n; // next
  const(CT)* e; // end
  FONSglyphBitmap bitmapOption;
  static if (is(CT == char)) {
    uint utf8state;
  }
  ~this () nothrow @trusted @nogc { pragma(inline, true); static if (is(CT == char)) utf8state = 0; s = n = e = null; }
  @property const(CT)* string () const pure nothrow @nogc => s;
  @property const(CT)* nextp () const pure nothrow @nogc => n;
  @property const(CT)* endp () const pure nothrow @nogc => e;
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

int fons__tt_init (FONScontext* context) nothrow @trusted @nogc {
  FT_Error ftError;
  //FONS_NOTUSED(context);
  ftError = FT_Init_FreeType(&ftLibrary);
  return (ftError == 0);
}

void fons__tt_setMono (FONScontext* context, FONSttFontImpl* font, bool v) nothrow @trusted @nogc {
  font.mono = v;
}

int fons__tt_loadFont (FONScontext* context, FONSttFontImpl* font, ubyte* data, int dataSize) nothrow @trusted @nogc {
  FT_Error ftError;
  //font.font.userdata = stash;
  ftError = FT_New_Memory_Face(ftLibrary, cast(const(FT_Byte)*)data, dataSize, 0, &font.font);
  return ftError == 0;
}

void fons__tt_getFontVMetrics (FONSttFontImpl* font, int* ascent, int* descent, int* lineGap) nothrow @trusted @nogc {
  *ascent = font.font.ascender;
  *descent = font.font.descender;
  *lineGap = font.font.height-(*ascent - *descent);
}

float fons__tt_getPixelHeightScale (FONSttFontImpl* font, float size) nothrow @trusted @nogc {
  return size/(font.font.ascender-font.font.descender);
}

int fons__tt_getGlyphIndex (FONSttFontImpl* font, int codepoint) nothrow @trusted @nogc {
  return FT_Get_Char_Index(font.font, codepoint);
}

int fons__tt_buildGlyphBitmap (FONSttFontImpl* font, int glyph, float size, float scale, int* advance, int* lsb, int* x0, int* y0, int* x1, int* y1) nothrow @trusted @nogc {
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

void fons__tt_renderGlyphBitmap (FONSttFontImpl* font, ubyte* output, int outWidth, int outHeight, int outStride, float scaleX, float scaleY, int glyph) nothrow @trusted @nogc {
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

float fons__tt_getGlyphKernAdvance (FONSttFontImpl* font, float size, int glyph1, int glyph2) nothrow @trusted @nogc {
  FT_Vector ftKerning;
  version(none) {
    // fitted kerning
    FT_Get_Kerning(font.font, glyph1, glyph2, FT_KERNING_DEFAULT, &ftKerning);
    //{ import core.stdc.stdio : printf; printf("kern for %u:%u: %d %d\n", glyph1, glyph2, ftKerning.x, ftKerning.y); }
    return cast(int)ftKerning.x; // round up and convert to integer
  } else {
    // unfitted kerning
    //FT_Get_Kerning(font.font, glyph1, glyph2, FT_KERNING_UNFITTED, &ftKerning);
    if (glyph1 <= 0 || glyph2 <= 0 || (font.font.face_flags&FT_FACE_FLAG_KERNING) == 0) return 0;
    if (FT_Set_Pixel_Sizes(font.font, 0, cast(FT_UInt)(size*cast(float)font.font.units_per_EM/cast(float)(font.font.ascender-font.font.descender)))) return 0;
    if (FT_Get_Kerning(font.font, glyph1, glyph2, FT_KERNING_DEFAULT, &ftKerning)) return 0;
    version(none) {
      if (ftKerning.x) {
        //{ import core.stdc.stdio : printf; printf("has kerning: %u\n", cast(uint)(font.font.face_flags&FT_FACE_FLAG_KERNING)); }
        { import core.stdc.stdio : printf; printf("kern for %u:%u: %d %d (size=%g)\n", glyph1, glyph2, ftKerning.x, ftKerning.y, cast(double)size); }
      }
    }
    version(none) {
      FT_Vector kk;
      if (FT_Get_Kerning(font.font, glyph1, glyph2, FT_KERNING_UNSCALED, &kk)) assert(0, "wtf?!");
      auto kadvfrac = FT_MulFix(kk.x, font.font.size.metrics.x_scale); // 1/64 of pixel
      //return cast(int)((kadvfrac/*+(kadvfrac < 0 ? -32 : 32)*/)>>6);
      //assert(ftKerning.x == kadvfrac);
      if (ftKerning.x || kadvfrac) {
        { import core.stdc.stdio : printf; printf("kern for %u:%u: %d %d (%d) (size=%g)\n", glyph1, glyph2, ftKerning.x, cast(int)kadvfrac, cast(int)(kadvfrac+(kadvfrac < 0 ? -31 : 32)>>6), cast(double)size); }
      }
      //return cast(int)(kadvfrac+(kadvfrac < 0 ? -31 : 32)>>6); // round up and convert to integer
      return kadvfrac/64.0f;
    }
    //return cast(int)(ftKerning.x+(ftKerning.x < 0 ? -31 : 32)>>6); // round up and convert to integer
    return ftKerning.x/64.0f;
  }
}

} else {
// ////////////////////////////////////////////////////////////////////////// //
struct FONSttFontImpl {
  stbtt_fontinfo font;
  bool mono; // no aa?
}

int fons__tt_init (FONScontext* context) nothrow @trusted @nogc {
  return 1;
}

void fons__tt_setMono (FONScontext* context, FONSttFontImpl* font, bool v) nothrow @trusted @nogc {
  font.mono = v;
}

int fons__tt_loadFont (FONScontext* context, FONSttFontImpl* font, ubyte* data, int dataSize) nothrow @trusted @nogc {
  int stbError;
  font.font.userdata = context;
  stbError = stbtt_InitFont(&font.font, data, 0);
  return stbError;
}

void fons__tt_getFontVMetrics (FONSttFontImpl* font, int* ascent, int* descent, int* lineGap) nothrow @trusted @nogc {
  stbtt_GetFontVMetrics(&font.font, ascent, descent, lineGap);
}

float fons__tt_getPixelHeightScale (FONSttFontImpl* font, float size) nothrow @trusted @nogc {
  return stbtt_ScaleForPixelHeight(&font.font, size);
}

int fons__tt_getGlyphIndex (FONSttFontImpl* font, int codepoint) nothrow @trusted @nogc {
  return stbtt_FindGlyphIndex(&font.font, codepoint);
}

int fons__tt_buildGlyphBitmap (FONSttFontImpl* font, int glyph, float size, float scale, int* advance, int* lsb, int* x0, int* y0, int* x1, int* y1) nothrow @trusted @nogc {
  stbtt_GetGlyphHMetrics(&font.font, glyph, advance, lsb);
  stbtt_GetGlyphBitmapBox(&font.font, glyph, scale, scale, x0, y0, x1, y1);
  return 1;
}

void fons__tt_renderGlyphBitmap (FONSttFontImpl* font, ubyte* output, int outWidth, int outHeight, int outStride, float scaleX, float scaleY, int glyph) nothrow @trusted @nogc {
  stbtt_MakeGlyphBitmap(&font.font, output, outWidth, outHeight, outStride, scaleX, scaleY, glyph);
}

float fons__tt_getGlyphKernAdvance (FONSttFontImpl* font, float size, int glyph1, int glyph2) nothrow @trusted @nogc {
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
enum FONS_MAX_FALLBACKS = 20;

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
  char[4096] path; //asciiz; TODO: malloc this?
  ubyte* data;
  int dataSize;
  bool freeData;
  float ascender;
  float descender;
  float lineh;
  FONSglyph* glyphs;
  int cglyphs;
  int nglyphs;
  int[FONS_HASH_LUT_SIZE] lut;
  int[FONS_MAX_FALLBACKS] fallbacks;
  int nfallbacks;
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
  void function (void* uptr, int error, int val) nothrow @trusted @nogc handleError;
  void* errorUptr;

  // reset font cache for name searching
  void resetFFCC () pure nothrow @safe @nogc { pragma(inline, true); lastfontlen = -1; lastfontidx = -1; }

  char[64] lastfont;
  int lastfontlen;
  int lastfontidx;
}

void* fons__tmpalloc (usize size, void* up) nothrow @trusted @nogc {
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

void fons__tmpfree (void* ptr, void* up) nothrow @trusted @nogc {
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
    `~codep~` = 0xFFFD;
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
void fons__deleteAtlas (FONSatlas* atlas) nothrow @trusted @nogc {
  if (atlas is null) return;
  if (atlas.nodes !is null) free(atlas.nodes);
  free(atlas);
}

FONSatlas* fons__allocAtlas (int w, int h, int nnodes) nothrow @trusted @nogc {
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

bool fons__atlasInsertNode (FONSatlas* atlas, int idx, int x, int y, int w) nothrow @trusted @nogc {
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

void fons__atlasRemoveNode (FONSatlas* atlas, int idx) nothrow @trusted @nogc {
  if (atlas.nnodes == 0) return;
  for (int i = idx; i < atlas.nnodes-1; ++i) atlas.nodes[i] = atlas.nodes[i+1];
  --atlas.nnodes;
}

void fons__atlasExpand (FONSatlas* atlas, int w, int h) nothrow @trusted @nogc {
  // Insert node for empty space
  if (w > atlas.width) fons__atlasInsertNode(atlas, atlas.nnodes, atlas.width, 0, w-atlas.width);
  atlas.width = w;
  atlas.height = h;
}

void fons__atlasReset (FONSatlas* atlas, int w, int h) nothrow @trusted @nogc {
  atlas.width = w;
  atlas.height = h;
  atlas.nnodes = 0;
  // Init root node.
  atlas.nodes[0].x = 0;
  atlas.nodes[0].y = 0;
  atlas.nodes[0].width = cast(short)w;
  ++atlas.nnodes;
}

bool fons__atlasAddSkylineLevel (FONSatlas* atlas, int idx, int x, int y, int w, int h) nothrow @trusted @nogc {
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

int fons__atlasRectFits (FONSatlas* atlas, int i, int w, int h) nothrow @trusted @nogc {
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

bool fons__atlasAddRect (FONSatlas* atlas, int rw, int rh, int* rx, int* ry) nothrow @trusted @nogc {
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

void fons__addWhiteRect (FONScontext* stash, int w, int h) nothrow @trusted @nogc {
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

public FONScontext* fonsCreateInternal (FONSparams* params) nothrow @trusted @nogc {
  FONScontext* stash = null;

  // Allocate memory for the font stash.
  stash = cast(FONScontext*)malloc(FONScontext.sizeof);
  if (stash is null) goto error;
  memset(stash, 0, FONScontext.sizeof);

  stash.params = *params;
  stash.lastfontlen = -1;
  stash.lastfontidx = -1;

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

FONSstate* fons__getState (FONScontext* stash) nothrow @trusted @nogc {
  pragma(inline, true);
  return &stash.states[stash.nstates-1];
}

bool fonsAddFallbackFont (FONScontext* stash, int base, int fallback) nothrow @trusted @nogc {
  FONSfont* baseFont = stash.fonts[base];
  if (baseFont.nfallbacks < FONS_MAX_FALLBACKS) {
    baseFont.fallbacks.ptr[baseFont.nfallbacks++] = fallback;
    return true;
  }
  return false;
}

public void fonsSetSize (FONScontext* stash, float size) nothrow @trusted @nogc {
  pragma(inline, true);
  fons__getState(stash).size = size;
}

public void fonsSetColor (FONScontext* stash, uint color) nothrow @trusted @nogc {
  pragma(inline, true);
  fons__getState(stash).color = color;
}

public void fonsSetSpacing (FONScontext* stash, float spacing) nothrow @trusted @nogc {
  pragma(inline, true);
  fons__getState(stash).spacing = spacing;
}

public void fonsSetBlur (FONScontext* stash, float blur) nothrow @trusted @nogc {
  pragma(inline, true);
  version(nanovg_kill_font_blur) blur = 0;
  fons__getState(stash).blur = blur;
}

public void fonsSetAlign (FONScontext* stash, NVGTextAlign talign) nothrow @trusted @nogc {
  pragma(inline, true);
  fons__getState(stash).talign = talign;
}

public void fonsSetFont (FONScontext* stash, int font) nothrow @trusted @nogc {
  pragma(inline, true);
  fons__getState(stash).font = font;
}

// get AA for current font or for the specified font
public bool fonsGetFontAA (FONScontext* stash, int font=-1) nothrow @trusted @nogc {
  FONSstate* state = fons__getState(stash);
  if (font < 0) font = state.font;
  if (font < 0 || font >= stash.nfonts) return false;
  FONSfont* f = stash.fonts[font];
  return (f !is null ? !f.font.mono : false);
}

public void fonsPushState (FONScontext* stash) nothrow @trusted @nogc {
  if (stash.nstates >= FONS_MAX_STATES) {
    if (stash.handleError) stash.handleError(stash.errorUptr, FONS_STATES_OVERFLOW, 0);
    return;
  }
  if (stash.nstates > 0) memcpy(&stash.states[stash.nstates], &stash.states[stash.nstates-1], FONSstate.sizeof);
  ++stash.nstates;
}

public void fonsPopState (FONScontext* stash) nothrow @trusted @nogc {
  if (stash.nstates <= 1) {
    if (stash.handleError) stash.handleError(stash.errorUptr, FONS_STATES_UNDERFLOW, 0);
    return;
  }
  --stash.nstates;
}

public void fonsClearState (FONScontext* stash) nothrow @trusted @nogc {
  FONSstate* state = fons__getState(stash);
  state.size = 12.0f;
  state.color = 0xffffffff;
  state.font = 0;
  state.blur = 0;
  state.spacing = 0;
  state.talign.reset; //FONS_ALIGN_LEFT|FONS_ALIGN_BASELINE;
}

void fons__freeFont (FONSfont* font) nothrow @trusted @nogc {
  if (font is null) return;
  if (font.glyphs) free(font.glyphs);
  if (font.freeData && font.data !is null) free(font.data);
  free(font);
}

int fons__allocFont (FONScontext* stash, int atidx=-1) nothrow @trusted @nogc {
  FONSfont* font = cast(FONSfont*)malloc(FONSfont.sizeof);
  if (font is null) return FONS_INVALID;
  memset(font, 0, FONSfont.sizeof);

  font.glyphs = cast(FONSglyph*)malloc(FONSglyph.sizeof*FONS_INIT_GLYPHS);
  if (font.glyphs is null) { free(font); return FONS_INVALID; }
  font.cglyphs = FONS_INIT_GLYPHS;
  font.nglyphs = 0;

  if (atidx < 0) {
    if (stash.nfonts+1 > stash.cfonts) {
      stash.cfonts = (stash.cfonts == 0 ? 16 : stash.cfonts+32);
      stash.fonts = cast(FONSfont**)realloc(stash.fonts, (FONSfont*).sizeof*stash.cfonts);
      if (stash.fonts is null) assert(0, "out of memory in NanoVega fontstash");
    }
    assert(stash.nfonts < stash.cfonts);
    stash.fonts[stash.nfonts] = font;
    return stash.nfonts++;
  } else {
    if (atidx >= stash.cfonts) assert(0, "internal NanoVega fontstash error");
    stash.fonts[atidx] = font;
    return atidx;
  }
}

private bool strEquCI (const(char)[] s0, const(char)[] s1) nothrow @trusted @nogc {
  if (s0.length != s1.length) return false;
  const(char)* sp0 = s0.ptr;
  const(char)* sp1 = s1.ptr;
  foreach (; 0..s0.length) {
    char c0 = *sp0++;
    char c1 = *sp1++;
    if (c0 != c1) {
      if (c0 >= 'A' && c0 <= 'Z') c0 += 32; // poor man tolower
      if (c1 >= 'A' && c1 <= 'Z') c1 += 32; // poor man tolower
      if (c0 != c1) return false;
    }
  }
  return true;
}

private enum NoAlias = ":noaa";

// defAA: antialias flag for fonts without ":noaa"
public int fonsAddFont (FONScontext* stash, const(char)[] name, const(char)[] path, bool defAA) nothrow @trusted {
  char[64+NoAlias.length] fontnamebuf = 0;

  if (path.length == 0 || name.length == 0 || strEquCI(name, NoAlias)) return FONS_INVALID;
  if (path.length > 1024) return FONS_INVALID; // arbitrary limit

  if (name.length > 63) name = name[0..63];
  fontnamebuf[0..name.length] = name[];
  uint blen = cast(uint)name.length;

  // if font path ends with ":noaa", add this to font name instead
  if (path.length >= NoAlias.length && strEquCI(path[$-NoAlias.length..$], NoAlias)) {
    path = path[0..$-NoAlias.length];
    if (path.length == 0) return FONS_INVALID;
    if (name.length < NoAlias.length || !strEquCI(name[$-NoAlias.length..$], NoAlias)) {
      if (name.length+NoAlias.length > 63) return FONS_INVALID;
      fontnamebuf[name.length..name.length+NoAlias.length] = NoAlias;
      blen += cast(uint)NoAlias.length;
    }
  }
  assert(fontnamebuf[blen] == 0);

  // find a font with the given name
  stash.resetFFCC();
  int fidx = fonsGetFontByName!false(stash, fontnamebuf[0..blen]); // no substitutes
  stash.resetFFCC();
  //{ import core.stdc.stdio; printf("loading font '%.*s' [%s] (fidx=%d)...\n", cast(uint)path.length, path.ptr, fontnamebuf.ptr, fidx); }

  int loadFontFile (const(char)[] path) {
    // check if we already has a loaded font with this name
    if (fidx >= 0) {
      import core.stdc.string : strlen;
      auto plen = strlen(stash.fonts[fidx].path.ptr);
      version(Posix) {
        //{ import core.stdc.stdio; printf("+++ font [%.*s] was loaded from [%.*s]\n", cast(uint)blen, fontnamebuf.ptr, cast(uint)stash.fonts[fidx].path.length, stash.fonts[fidx].path.ptr); }
        if (plen == path.length && stash.fonts[fidx].path.ptr[0..plen] == path) {
          //{ import core.stdc.stdio; printf("*** font [%.*s] already loaded from [%.*s]\n", cast(uint)blen, fontnamebuf.ptr, cast(uint)plen, path.ptr); }
          // i found her!
          return fidx;
        }
      } else {
        if (plen == path.length && strEquCI(stash.fonts[fidx].path.ptr[0..plen],  path)) {
          // i found her!
          return fidx;
        }
      }
    }
    version(Windows) {
      // special shitdows check
      foreach (immutable char ch; path) if (ch == ':') return FONS_INVALID;
    }
    // either no such font, or another file was loaded
    //{ import core.stdc.stdio; printf("trying font [%.*s] from file [%.*s]\n", cast(uint)blen, fontnamebuf.ptr, cast(uint)path.length, path.ptr); }
    try {
      import core.stdc.stdlib : free, malloc;
      auto fl = VFile(path);
      auto dataSize = fl.size;
      if (dataSize < 16 || dataSize > int.max/32) return FONS_INVALID;
      ubyte* data = cast(ubyte*)malloc(cast(uint)dataSize);
      if (data is null) assert(0, "out of memory in NanoVega fontstash");
      scope(failure) free(data); // oops
      fl.rawReadExact(data[0..cast(uint)dataSize]);
      fl.close();
      auto xres = fonsAddFontMem(stash, fontnamebuf[0..blen], data, cast(int)dataSize, true, defAA);
      if (xres == FONS_INVALID) {
        free(data);
      } else {
        // remember path
        if (path.length <= stash.fonts[xres].path.length) stash.fonts[xres].path.ptr[0..path.length] = path[];
      }
      return xres;
    } catch (Exception e) {
      // oops; sorry
    }
    return FONS_INVALID;
  }

  // first try direct path
  auto res = loadFontFile(path);
  // if loading failed, try fontconfig (if fontconfig is available)
  static if (NVG_HAS_FONTCONFIG) {
    if (res == FONS_INVALID && fontconfigAvailable) {
      import std.internal.cstring : tempCString;
      FcPattern* pat = FcNameParse(path.tempCString);
      if (pat !is null) {
        if (FcConfigSubstitute(null, pat, FcMatchPattern)) {
          FcDefaultSubstitute(pat);
          // find the font
          FcResult result;
          FcPattern* font = FcFontMatch(null, pat, &result);
          if (font !is null) {
            char* file = null;
            if (FcPatternGetString(font, FC_FILE, 0, &file) == FcResultMatch) {
              if (file !is null && file[0]) {
                import core.stdc.string : strlen;
                res = loadFontFile(file[0..strlen(file)]);
              }
            }
            FcPatternDestroy(font);
          }
        }
      }
      FcPatternDestroy(pat);
    }
  }
  return res;
}

/// This will not free data on error!
public int fonsAddFontMem (FONScontext* stash, const(char)[] name, ubyte* data, int dataSize, bool freeData, bool defAA) nothrow @trusted @nogc {
  int i, ascent, descent, fh, lineGap;

  if (name.length == 0 || name == NoAlias) return FONS_INVALID;
  if (name.length > FONSfont.name.length-1) return FONS_INVALID; //name = name[0..FONSfont.name.length-1];

  // find a font with the given name
  FONSfont* oldfont = null;
  stash.resetFFCC();
  int oldidx = fonsGetFontByName!false(stash, name); // no substitutes
  stash.resetFFCC();
  if (oldidx != FONS_INVALID) oldfont = stash.fonts[oldidx];

  //{ import core.stdc.stdio; printf("creating font [%.*s] (oidx=%d)...\n", cast(uint)name.length, name.ptr, oldidx); }

  int idx = fons__allocFont(stash, oldidx);
  if (idx == FONS_INVALID) return FONS_INVALID;

  FONSfont* font = stash.fonts[idx];

  //strncpy(font.name.ptr, name, (font.name).sizeof);
  font.name[] = 0;
  font.name[0..name.length] = name[];
  font.namelen = cast(uint)name.length;

  // Init hash lookup.
  font.lut.ptr[0..FONS_HASH_LUT_SIZE] = -1;

  // Read in the font data.
  font.dataSize = dataSize;
  font.data = data;
  font.freeData = freeData;

  if (name.length >= NoAlias.length && name[$-NoAlias.length..$] == NoAlias) {
    //{ import core.stdc.stdio : printf; printf("MONO: [%.*s]\n", cast(uint)name.length, name.ptr); }
    fons__tt_setMono(stash, &font.font, true);
  } else {
    fons__tt_setMono(stash, &font.font, defAA);
  }

  // Init font
  stash.nscratch = 0;
  if (!fons__tt_loadFont(stash, &font.font, data, dataSize)) {
    font.freeData = false; // we promised to don't free data on error
    fons__freeFont(font);
    if (oldidx != FONS_INVALID) {
      stash.fonts[oldidx] = oldfont;
    } else {
      --stash.nfonts;
    }
    return FONS_INVALID;
  }

  // Store normalized line height. The real line height is got
  // by multiplying the lineh by font size.
  fons__tt_getFontVMetrics(&font.font, &ascent, &descent, &lineGap);
  fh = ascent-descent;
  font.ascender = cast(float)ascent/cast(float)fh;
  font.descender = cast(float)descent/cast(float)fh;
  font.lineh = cast(float)(fh+lineGap)/cast(float)fh;

  //{ import core.stdc.stdio; printf("created font [%.*s] (idx=%d)...\n", cast(uint)name.length, name.ptr, idx); }
  return idx;
}

// returns `null` on invalid index
// WARNING! copy name, as name buffer can be invalidated by next fontstash API call!
public const(char)[] fonsGetNameByIndex (FONScontext* stash, int idx) nothrow @trusted @nogc {
  if (idx < 0 || idx >= stash.nfonts) return null;
  return stash.fonts[idx].name[0..stash.fonts[idx].namelen];
}

// allowSubstitutes: check AA variants if exact name wasn't found?
// return `FONS_INVALID` if no font was found
public int fonsGetFontByName(bool allowSubstitutes=true) (FONScontext* stash, const(char)[] name) nothrow @trusted @nogc {
  // check cached name
  if (stash.lastfontlen == name.length && strEquCI(name, stash.lastfont[0..stash.lastfontlen])) {
    //{ import core.stdc.stdio; printf("fonsGetFontByName: cache hit: id=%d; [%.*s] <%.*s>\n", stash.lastfontidx, stash.lastfontlen, stash.lastfont.ptr, cast(uint)name.length, name.ptr); }
    return stash.lastfontidx;
  }

  int updateCache (usize idx, FONSfont* font) nothrow @trusted @nogc {
    if (name.length <= stash.lastfont.length) {
      stash.lastfont[0..name.length] = name[];
      stash.lastfontlen = cast(int)name.length;
      stash.lastfontidx = cast(int)idx;
      //{ import core.stdc.stdio; printf("fonsGetFontByName: new cache: id=%d; [%.*s] <%.*s>\n", stash.lastfontidx, stash.lastfontlen, stash.lastfont.ptr, cast(uint)name.length, name.ptr); }
    } else {
      stash.resetFFCC();
    }
    return cast(int)idx;
  }

  foreach (immutable idx, FONSfont* font; stash.fonts[0..stash.nfonts]) {
    if (strEquCI(name, font.name[0..font.namelen])) return updateCache(idx, font);
  }

  static if (allowSubstitutes) {
    // not found, try variations
    if (name.length >= NoAlias.length && name[$-NoAlias.length..$] == NoAlias) {
      // search for font name without ":noaa"
      name = name[0..$-NoAlias.length];
      foreach (immutable idx, FONSfont* font; stash.fonts[0..stash.nfonts]) {
        if (strEquCI(name, font.name[0..font.namelen])) return updateCache(idx, font);
      }
    } else {
      // search for font name with ":noaa"
      foreach (immutable idx, FONSfont* font; stash.fonts[0..stash.nfonts]) {
        if (font.namelen == name.length+NoAlias.length) {
          if (strEquCI(font.name[0..name.length], name[]) && strEquCI(font.name[name.length..font.namelen], NoAlias)) {
            //{ import std.stdio; writeln(font.name[0..name.length], " : ", name, " <", font.name[name.length..$], ">"); }
            return updateCache(idx, font);
          }
        }
      }
    }
  }

  return FONS_INVALID;
}


FONSglyph* fons__allocGlyph (FONSfont* font) nothrow @trusted @nogc {
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

void fons__blurCols (ubyte* dst, int w, int h, int dstStride, int alpha) nothrow @trusted @nogc {
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

void fons__blurRows (ubyte* dst, int w, int h, int dstStride, int alpha) nothrow @trusted @nogc {
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


void fons__blur (FONScontext* stash, ubyte* dst, int w, int h, int dstStride, int blur) nothrow @trusted @nogc {
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

FONSglyph* fons__getGlyph (FONScontext* stash, FONSfont* font, uint codepoint, short isize, short iblur, FONSglyphBitmap bitmapOption) nothrow @trusted @nogc {
  int i, g, advance, lsb, x0, y0, x1, y1, gw, gh, gx, gy, x, y;
  float scale;
  FONSglyph* glyph = null;
  uint h;
  float size = isize/10.0f;
  int pad, added;
  ubyte* bdst;
  ubyte* dst;
  FONSfont* renderFont = font;

  version(nanovg_kill_font_blur) iblur = 0;

  if (isize < 2) return null;
  if (iblur > 20) iblur = 20;
  pad = iblur+2;

  // Reset allocator.
  stash.nscratch = 0;

  // Find code point and size.
  h = fons__hashint(codepoint)&(FONS_HASH_LUT_SIZE-1);
  i = font.lut.ptr[h];
  while (i != -1) {
    //if (font.glyphs[i].codepoint == codepoint && font.glyphs[i].size == isize && font.glyphs[i].blur == iblur) return &font.glyphs[i];
    if (font.glyphs[i].codepoint == codepoint && font.glyphs[i].size == isize && font.glyphs[i].blur == iblur) {
      glyph = &font.glyphs[i];
      // Negative coordinate indicates there is no bitmap data created.
      if (bitmapOption == FONS_GLYPH_BITMAP_OPTIONAL || (glyph.x0 >= 0 && glyph.y0 >= 0)) return glyph;
      // At this point, glyph exists but the bitmap data is not yet created.
      break;
    }
    i = font.glyphs[i].next;
  }

  // Create a new glyph or rasterize bitmap data for a cached glyph.
  //scale = fons__tt_getPixelHeightScale(&font.font, size);
  g = fons__tt_getGlyphIndex(&font.font, codepoint);
  // Try to find the glyph in fallback fonts.
  if (g == 0) {
    for (i = 0; i < font.nfallbacks; ++i) {
      FONSfont* fallbackFont = stash.fonts[font.fallbacks.ptr[i]];
      int fallbackIndex = fons__tt_getGlyphIndex(&fallbackFont.font, codepoint);
      if (fallbackIndex != 0) {
        g = fallbackIndex;
        renderFont = fallbackFont;
        break;
      }
    }
    // It is possible that we did not find a fallback glyph.
    // In that case the glyph index 'g' is 0, and we'll proceed below and cache empty glyph.
  }
  scale = fons__tt_getPixelHeightScale(&renderFont.font, size);
  fons__tt_buildGlyphBitmap(&renderFont.font, g, size, scale, &advance, &lsb, &x0, &y0, &x1, &y1);
  gw = x1-x0+pad*2;
  gh = y1-y0+pad*2;

  // Determines the spot to draw glyph in the atlas.
  if (bitmapOption == FONS_GLYPH_BITMAP_REQUIRED) {
    // Find free spot for the rect in the atlas.
    added = fons__atlasAddRect(stash.atlas, gw, gh, &gx, &gy);
    if (added == 0 && stash.handleError !is null) {
      // Atlas is full, let the user to resize the atlas (or not), and try again.
      stash.handleError(stash.errorUptr, FONS_ATLAS_FULL, 0);
      added = fons__atlasAddRect(stash.atlas, gw, gh, &gx, &gy);
    }
    if (added == 0) return null;
  } else {
    // Negative coordinate indicates there is no bitmap data created.
    gx = -1;
    gy = -1;
  }

  // Init glyph.
  if (glyph is null) {
    glyph = fons__allocGlyph(font);
    glyph.codepoint = codepoint;
    glyph.size = isize;
    glyph.blur = iblur;
    glyph.next = 0;

    // Insert char to hash lookup.
    glyph.next = font.lut.ptr[h];
    font.lut.ptr[h] = font.nglyphs-1;
  }
  glyph.index = g;
  glyph.x0 = cast(short)gx;
  glyph.y0 = cast(short)gy;
  glyph.x1 = cast(short)(glyph.x0+gw);
  glyph.y1 = cast(short)(glyph.y0+gh);
  glyph.xadv = cast(short)(scale*advance*10.0f);
  glyph.xoff = cast(short)(x0-pad);
  glyph.yoff = cast(short)(y0-pad);

  if (bitmapOption == FONS_GLYPH_BITMAP_OPTIONAL) return glyph;

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
    foreach (immutable yy; 0..gh) {
      foreach (immutable xx; 0..gw) {
        int a = cast(int)dst[xx+yy*stash.params.width]+42;
        if (a > 255) a = 255;
        dst[xx+yy*stash.params.width] = cast(ubyte)a;
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

void fons__getQuad (FONScontext* stash, FONSfont* font, int prevGlyphIndex, FONSglyph* glyph, float size, float scale, float spacing, float* x, float* y, FONSquad* q) nothrow @trusted @nogc {
  if (prevGlyphIndex >= 0) {
    immutable float adv = fons__tt_getGlyphKernAdvance(&font.font, size, prevGlyphIndex, glyph.index)/**scale*/; //k8: do we really need scale here?
    //if (adv != 0) { import core.stdc.stdio; printf("adv=%g (scale=%g; spacing=%g)\n", cast(double)adv, cast(double)scale, cast(double)spacing); }
    *x += cast(int)(adv+spacing /*+0.5f*/); //k8: for me, it looks better this way (with non-aa fonts)
  }

  // Each glyph has 2px border to allow good interpolation,
  // one pixel to prevent leaking, and one to allow good interpolation for rendering.
  // Inset the texture region by one pixel for correct interpolation.
  immutable float xoff = cast(short)(glyph.xoff+1);
  immutable float yoff = cast(short)(glyph.yoff+1);
  immutable float x0 = cast(float)(glyph.x0+1);
  immutable float y0 = cast(float)(glyph.y0+1);
  immutable float x1 = cast(float)(glyph.x1-1);
  immutable float y1 = cast(float)(glyph.y1-1);

  if (stash.params.flags&FONS_ZERO_TOPLEFT) {
    immutable float rx = cast(float)cast(int)(*x+xoff);
    immutable float ry = cast(float)cast(int)(*y+yoff);

    q.x0 = rx;
    q.y0 = ry;
    q.x1 = rx+x1-x0;
    q.y1 = ry+y1-y0;

    q.s0 = x0*stash.itw;
    q.t0 = y0*stash.ith;
    q.s1 = x1*stash.itw;
    q.t1 = y1*stash.ith;
  } else {
    immutable float rx = cast(float)cast(int)(*x+xoff);
    immutable float ry = cast(float)cast(int)(*y-yoff);

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

void fons__flush (FONScontext* stash) nothrow @trusted @nogc {
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

void fons__vertex (FONScontext* stash, float x, float y, float s, float t, uint c) nothrow @trusted @nogc {
  stash.verts.ptr[stash.nverts*2+0] = x;
  stash.verts.ptr[stash.nverts*2+1] = y;
  stash.tcoords.ptr[stash.nverts*2+0] = s;
  stash.tcoords.ptr[stash.nverts*2+1] = t;
  stash.colors.ptr[stash.nverts] = c;
  ++stash.nverts;
}

float fons__getVertAlign (FONScontext* stash, FONSfont* font, NVGTextAlign talign, short isize) nothrow @trusted @nogc {
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
    glyph = fons__getGlyph(stash, font, codepoint, isize, iblur, FONS_GLYPH_BITMAP_REQUIRED);
    if (glyph !is null) {
      fons__getQuad(stash, font, prevGlyphIndex, glyph, isize/10.0f, scale, state.spacing, &x, &y, &q);

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

public bool fonsTextIterInit(T) (FONScontext* stash, FONStextIter!T* iter, float x, float y, const(T)[] str, FONSglyphBitmap bitmapOption) if (isAnyCharType!T) {
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
  if (str.ptr is null) {
         static if (is(T == char)) str = "";
    else static if (is(T == wchar)) str = ""w;
    else static if (is(T == dchar)) str = ""d;
    else static assert(0, "wtf?!");
  }
  iter.s = str.ptr;
  iter.n = str.ptr;
  iter.e = str.ptr+str.length;
  iter.codepoint = 0;
  iter.prevGlyphIndex = -1;
  iter.bitmapOption = bitmapOption;

  return true;
}

public bool fonsTextIterGetDummyChar(FT) (FONScontext* stash, FT* iter, FONSquad* quad) nothrow @trusted @nogc if (is(FT : FONStextIter!CT, CT)) {
  if (stash is null || iter is null) return false;
  // Get glyph and quad
  iter.x = iter.nextx;
  iter.y = iter.nexty;
  FONSglyph* glyph = fons__getGlyph(stash, iter.font, 0xFFFD, iter.isize, iter.iblur, iter.bitmapOption);
  if (glyph !is null) {
    fons__getQuad(stash, iter.font, iter.prevGlyphIndex, glyph, iter.isize/10.0f, iter.scale, iter.spacing, &iter.nextx, &iter.nexty, quad);
    iter.prevGlyphIndex = glyph.index;
    return true;
  } else {
    iter.prevGlyphIndex = -1;
    return false;
  }
}

public bool fonsTextIterNext(FT) (FONScontext* stash, FT* iter, FONSquad* quad) nothrow @trusted @nogc if (is(FT : FONStextIter!CT, CT)) {
  if (stash is null || iter is null) return false;
  FONSglyph* glyph = null;
  static if (is(FT.CharType == char)) {
    const(char)* str = iter.n;
    iter.s = iter.n;
    if (str is iter.e) return false;
    const(char)* e = iter.e;
    for (; str !is e; ++str) {
      /*if (fons__decutf8(&iter.utf8state, &iter.codepoint, *cast(const(ubyte)*)str)) continue;*/
      mixin(DecUtfMixin!("iter.utf8state", "iter.codepoint", "*cast(const(ubyte)*)str"));
      if (iter.utf8state) continue;
      ++str; // 'cause we'll break anyway
      // get glyph and quad
      iter.x = iter.nextx;
      iter.y = iter.nexty;
      glyph = fons__getGlyph(stash, iter.font, iter.codepoint, iter.isize, iter.iblur, iter.bitmapOption);
      if (glyph !is null) {
        fons__getQuad(stash, iter.font, iter.prevGlyphIndex, glyph, iter.isize/10.0f, iter.scale, iter.spacing, &iter.nextx, &iter.nexty, quad);
        iter.prevGlyphIndex = glyph.index;
      } else {
        iter.prevGlyphIndex = -1;
      }
      break;
    }
    iter.n = str;
  } else {
    const(FT.CharType)* str = iter.n;
    iter.s = iter.n;
    if (str is iter.e) return false;
    iter.codepoint = cast(uint)(*str++);
    if (iter.codepoint > dchar.max) iter.codepoint = 0xFFFD;
    // Get glyph and quad
    iter.x = iter.nextx;
    iter.y = iter.nexty;
    glyph = fons__getGlyph(stash, iter.font, iter.codepoint, iter.isize, iter.iblur, iter.bitmapOption);
    if (glyph !is null) {
      fons__getQuad(stash, iter.font, iter.prevGlyphIndex, glyph, iter.isize/10.0f, iter.scale, iter.spacing, &iter.nextx, &iter.nexty, quad);
      iter.prevGlyphIndex = glyph.index;
    } else {
      iter.prevGlyphIndex = -1;
    }
    iter.n = str;
  }
  return true;
}

debug public void fonsDrawDebug (FONScontext* stash, float x, float y) nothrow @trusted @nogc {
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
  this (FONScontext* astash, float ax, float ay) nothrow @trusted @nogc { reset(astash, ax, ay); }

  void reset (FONScontext* astash, float ax, float ay) nothrow @trusted @nogc {
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
  @property bool valid () const pure nothrow @safe @nogc => (state !is null);

  void put(T) (const(T)[] str...) nothrow @trusted @nogc if (isAnyCharType!T) {
    enum DoCodePointMixin = q{
      glyph = fons__getGlyph(stash, font, codepoint, isize, iblur, FONS_GLYPH_BITMAP_OPTIONAL);
      if (glyph !is null) {
        fons__getQuad(stash, font, prevGlyphIndex, glyph, isize/10.0f, scale, state.spacing, &x, &y, &q);
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
        codepoint = 0xFFFD;
        mixin(DoCodePointMixin);
      }
      foreach (T dch; str) {
        static if (is(T == dchar)) {
          if (dch > dchar.max) dch = 0xFFFD;
        }
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
  void getHBounds (out float xmin, out float xmax) nothrow @trusted @nogc {
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
  void getVBounds (out float ymin, out float ymax) nothrow @trusted @nogc {
    if (state !is null) {
      ymin = miny;
      ymax = maxy;
    }
  }
}

public float fonsTextBounds(T) (FONScontext* stash, float x, float y, const(T)[] str, float[] bounds) nothrow @trusted @nogc
if (isAnyCharType!T)
{
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
      glyph = fons__getGlyph(stash, font, codepoint, isize, iblur, FONS_GLYPH_BITMAP_OPTIONAL);
      if (glyph !is null) {
        fons__getQuad(stash, font, prevGlyphIndex, glyph, isize/10.0f, scale, state.spacing, &x, &y, &q);
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
    foreach (T ch; str) {
      static if (is(T == dchar)) {
        if (ch > dchar.max) ch = 0xFFFD;
      }
      codepoint = cast(uint)ch;
      glyph = fons__getGlyph(stash, font, codepoint, isize, iblur, FONS_GLYPH_BITMAP_OPTIONAL);
      if (glyph !is null) {
        fons__getQuad(stash, font, prevGlyphIndex, glyph, isize/10.0f, scale, state.spacing, &x, &y, &q);
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

public void fonsVertMetrics (FONScontext* stash, float* ascender, float* descender, float* lineh) nothrow @trusted @nogc {
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

public void fonsLineBounds (FONScontext* stash, float y, float* minyp, float* maxyp) nothrow @trusted @nogc {
  FONSfont* font;
  FONSstate* state = fons__getState(stash);
  short isize;

  if (minyp !is null) *minyp = 0;
  if (maxyp !is null) *maxyp = 0;

  if (stash is null) return;
  if (state.font < 0 || state.font >= stash.nfonts) return;
  font = stash.fonts[state.font];
  isize = cast(short)(state.size*10.0f);
  if (font.data is null) return;

  y += fons__getVertAlign(stash, font, state.talign, isize);

  if (stash.params.flags&FONS_ZERO_TOPLEFT) {
    immutable float miny = y-font.ascender*cast(float)isize/10.0f;
    immutable float maxy = miny+font.lineh*isize/10.0f;
    if (minyp !is null) *minyp = miny;
    if (maxyp !is null) *maxyp = maxy;
  } else {
    immutable float maxy = y+font.descender*cast(float)isize/10.0f;
    immutable float miny = maxy-font.lineh*isize/10.0f;
    if (minyp !is null) *minyp = miny;
    if (maxyp !is null) *maxyp = maxy;
  }
}

public const(ubyte)* fonsGetTextureData (FONScontext* stash, int* width, int* height) nothrow @trusted @nogc {
  if (width !is null) *width = stash.params.width;
  if (height !is null) *height = stash.params.height;
  return stash.texData;
}

public int fonsValidateTexture (FONScontext* stash, int* dirty) nothrow @trusted @nogc {
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

public void fonsDeleteInternal (FONScontext* stash) nothrow @trusted @nogc {
  if (stash is null) return;

  if (stash.params.renderDelete) stash.params.renderDelete(stash.params.userPtr);

  foreach (int i; 0..stash.nfonts) fons__freeFont(stash.fonts[i]);

  if (stash.atlas) fons__deleteAtlas(stash.atlas);
  if (stash.fonts) free(stash.fonts);
  if (stash.texData) free(stash.texData);
  if (stash.scratch) free(stash.scratch);
  free(stash);
}

public void fonsSetErrorCallback (FONScontext* stash, void function (void* uptr, int error, int val) nothrow @trusted @nogc callback, void* uptr) nothrow @trusted @nogc {
  if (stash is null) return;
  stash.handleError = callback;
  stash.errorUptr = uptr;
}

public void fonsGetAtlasSize (FONScontext* stash, int* width, int* height) nothrow @trusted @nogc {
  if (stash is null) return;
  *width = stash.params.width;
  *height = stash.params.height;
}

public int fonsExpandAtlas (FONScontext* stash, int width, int height) nothrow @trusted @nogc {
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

public int fonsResetAtlas (FONScontext* stash, int width, int height) nothrow @trusted @nogc {
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
    font.lut.ptr[0..FONS_HASH_LUT_SIZE] = -1;
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

//import arsd.simpledisplay;
version(nanovg_builtin_opengl_bindings) { import arsd.simpledisplay; } else { import iv.glbinds; }

private:
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

  enum uint GL_STENCIL_BUFFER_BIT = 0x00000400;

  enum uint GL_INVALID_ENUM = 0x0500;

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

  enum uint GL_SRC_COLOR = 0x0300;
  enum uint GL_ONE_MINUS_SRC_COLOR = 0x0301;
  enum uint GL_SRC_ALPHA = 0x0302;
  enum uint GL_ONE_MINUS_SRC_ALPHA = 0x0303;
  enum uint GL_DST_ALPHA = 0x0304;
  enum uint GL_ONE_MINUS_DST_ALPHA = 0x0305;
  enum uint GL_DST_COLOR = 0x0306;
  enum uint GL_ONE_MINUS_DST_COLOR = 0x0307;
  enum uint GL_SRC_ALPHA_SATURATE = 0x0308;

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
  __gshared glbfn_glStencilMask glStencilMask_NVGLZ; alias glStencilMask = glStencilMask_NVGLZ;
  alias glbfn_glStencilFunc = void function(GLenum, GLint, GLuint);
  __gshared glbfn_glStencilFunc glStencilFunc_NVGLZ; alias glStencilFunc = glStencilFunc_NVGLZ;
  alias glbfn_glGetShaderInfoLog = void function(GLuint, GLsizei, GLsizei*, GLchar*);
  __gshared glbfn_glGetShaderInfoLog glGetShaderInfoLog_NVGLZ; alias glGetShaderInfoLog = glGetShaderInfoLog_NVGLZ;
  alias glbfn_glGetProgramInfoLog = void function(GLuint, GLsizei, GLsizei*, GLchar*);
  __gshared glbfn_glGetProgramInfoLog glGetProgramInfoLog_NVGLZ; alias glGetProgramInfoLog = glGetProgramInfoLog_NVGLZ;
  alias glbfn_glCreateProgram = GLuint function();
  __gshared glbfn_glCreateProgram glCreateProgram_NVGLZ; alias glCreateProgram = glCreateProgram_NVGLZ;
  alias glbfn_glCreateShader = GLuint function(GLenum);
  __gshared glbfn_glCreateShader glCreateShader_NVGLZ; alias glCreateShader = glCreateShader_NVGLZ;
  alias glbfn_glShaderSource = void function(GLuint, GLsizei, const(GLchar*)*, const(GLint)*);
  __gshared glbfn_glShaderSource glShaderSource_NVGLZ; alias glShaderSource = glShaderSource_NVGLZ;
  alias glbfn_glCompileShader = void function(GLuint);
  __gshared glbfn_glCompileShader glCompileShader_NVGLZ; alias glCompileShader = glCompileShader_NVGLZ;
  alias glbfn_glGetShaderiv = void function(GLuint, GLenum, GLint*);
  __gshared glbfn_glGetShaderiv glGetShaderiv_NVGLZ; alias glGetShaderiv = glGetShaderiv_NVGLZ;
  alias glbfn_glAttachShader = void function(GLuint, GLuint);
  __gshared glbfn_glAttachShader glAttachShader_NVGLZ; alias glAttachShader = glAttachShader_NVGLZ;
  alias glbfn_glBindAttribLocation = void function(GLuint, GLuint, const(GLchar)*);
  __gshared glbfn_glBindAttribLocation glBindAttribLocation_NVGLZ; alias glBindAttribLocation = glBindAttribLocation_NVGLZ;
  alias glbfn_glLinkProgram = void function(GLuint);
  __gshared glbfn_glLinkProgram glLinkProgram_NVGLZ; alias glLinkProgram = glLinkProgram_NVGLZ;
  alias glbfn_glGetProgramiv = void function(GLuint, GLenum, GLint*);
  __gshared glbfn_glGetProgramiv glGetProgramiv_NVGLZ; alias glGetProgramiv = glGetProgramiv_NVGLZ;
  alias glbfn_glDeleteProgram = void function(GLuint);
  __gshared glbfn_glDeleteProgram glDeleteProgram_NVGLZ; alias glDeleteProgram = glDeleteProgram_NVGLZ;
  alias glbfn_glDeleteShader = void function(GLuint);
  __gshared glbfn_glDeleteShader glDeleteShader_NVGLZ; alias glDeleteShader = glDeleteShader_NVGLZ;
  alias glbfn_glGetUniformLocation = GLint function(GLuint, const(GLchar)*);
  __gshared glbfn_glGetUniformLocation glGetUniformLocation_NVGLZ; alias glGetUniformLocation = glGetUniformLocation_NVGLZ;
  alias glbfn_glGenBuffers = void function(GLsizei, GLuint*);
  __gshared glbfn_glGenBuffers glGenBuffers_NVGLZ; alias glGenBuffers = glGenBuffers_NVGLZ;
  alias glbfn_glPixelStorei = void function(GLenum, GLint);
  __gshared glbfn_glPixelStorei glPixelStorei_NVGLZ; alias glPixelStorei = glPixelStorei_NVGLZ;
  alias glbfn_glUniform4fv = void function(GLint, GLsizei, const(GLfloat)*);
  __gshared glbfn_glUniform4fv glUniform4fv_NVGLZ; alias glUniform4fv = glUniform4fv_NVGLZ;
  alias glbfn_glColorMask = void function(GLboolean, GLboolean, GLboolean, GLboolean);
  __gshared glbfn_glColorMask glColorMask_NVGLZ; alias glColorMask = glColorMask_NVGLZ;
  alias glbfn_glStencilOpSeparate = void function(GLenum, GLenum, GLenum, GLenum);
  __gshared glbfn_glStencilOpSeparate glStencilOpSeparate_NVGLZ; alias glStencilOpSeparate = glStencilOpSeparate_NVGLZ;
  alias glbfn_glDrawArrays = void function(GLenum, GLint, GLsizei);
  __gshared glbfn_glDrawArrays glDrawArrays_NVGLZ; alias glDrawArrays = glDrawArrays_NVGLZ;
  alias glbfn_glStencilOp = void function(GLenum, GLenum, GLenum);
  __gshared glbfn_glStencilOp glStencilOp_NVGLZ; alias glStencilOp = glStencilOp_NVGLZ;
  alias glbfn_glUseProgram = void function(GLuint);
  __gshared glbfn_glUseProgram glUseProgram_NVGLZ; alias glUseProgram = glUseProgram_NVGLZ;
  alias glbfn_glCullFace = void function(GLenum);
  __gshared glbfn_glCullFace glCullFace_NVGLZ; alias glCullFace = glCullFace_NVGLZ;
  alias glbfn_glFrontFace = void function(GLenum);
  __gshared glbfn_glFrontFace glFrontFace_NVGLZ; alias glFrontFace = glFrontFace_NVGLZ;
  alias glbfn_glActiveTexture = void function(GLenum);
  __gshared glbfn_glActiveTexture glActiveTexture_NVGLZ; alias glActiveTexture = glActiveTexture_NVGLZ;
  alias glbfn_glBindBuffer = void function(GLenum, GLuint);
  __gshared glbfn_glBindBuffer glBindBuffer_NVGLZ; alias glBindBuffer = glBindBuffer_NVGLZ;
  alias glbfn_glBufferData = void function(GLenum, GLsizeiptr, const(void)*, GLenum);
  __gshared glbfn_glBufferData glBufferData_NVGLZ; alias glBufferData = glBufferData_NVGLZ;
  alias glbfn_glEnableVertexAttribArray = void function(GLuint);
  __gshared glbfn_glEnableVertexAttribArray glEnableVertexAttribArray_NVGLZ; alias glEnableVertexAttribArray = glEnableVertexAttribArray_NVGLZ;
  alias glbfn_glVertexAttribPointer = void function(GLuint, GLint, GLenum, GLboolean, GLsizei, const(void)*);
  __gshared glbfn_glVertexAttribPointer glVertexAttribPointer_NVGLZ; alias glVertexAttribPointer = glVertexAttribPointer_NVGLZ;
  alias glbfn_glUniform1i = void function(GLint, GLint);
  __gshared glbfn_glUniform1i glUniform1i_NVGLZ; alias glUniform1i = glUniform1i_NVGLZ;
  alias glbfn_glUniform2fv = void function(GLint, GLsizei, const(GLfloat)*);
  __gshared glbfn_glUniform2fv glUniform2fv_NVGLZ; alias glUniform2fv = glUniform2fv_NVGLZ;
  alias glbfn_glDisableVertexAttribArray = void function(GLuint);
  __gshared glbfn_glDisableVertexAttribArray glDisableVertexAttribArray_NVGLZ; alias glDisableVertexAttribArray = glDisableVertexAttribArray_NVGLZ;
  alias glbfn_glDeleteBuffers = void function(GLsizei, const(GLuint)*);
  __gshared glbfn_glDeleteBuffers glDeleteBuffers_NVGLZ; alias glDeleteBuffers = glDeleteBuffers_NVGLZ;
  alias glbfn_glBlendFuncSeparate = void function(GLenum, GLenum, GLenum, GLenum);
  __gshared glbfn_glBlendFuncSeparate glBlendFuncSeparate_NVGLZ; alias glBlendFuncSeparate = glBlendFuncSeparate_NVGLZ;

  private void nanovgInitOpenGL () {
    __gshared bool initialized = false;
    if (initialized) return;
    glStencilMask_NVGLZ = cast(glbfn_glStencilMask)glbindGetProcAddress(`glStencilMask`);
    if (glStencilMask_NVGLZ is null) assert(0, `OpenGL function 'glStencilMask' not found!`);
    glStencilFunc_NVGLZ = cast(glbfn_glStencilFunc)glbindGetProcAddress(`glStencilFunc`);
    if (glStencilFunc_NVGLZ is null) assert(0, `OpenGL function 'glStencilFunc' not found!`);
    glGetShaderInfoLog_NVGLZ = cast(glbfn_glGetShaderInfoLog)glbindGetProcAddress(`glGetShaderInfoLog`);
    if (glGetShaderInfoLog_NVGLZ is null) assert(0, `OpenGL function 'glGetShaderInfoLog' not found!`);
    glGetProgramInfoLog_NVGLZ = cast(glbfn_glGetProgramInfoLog)glbindGetProcAddress(`glGetProgramInfoLog`);
    if (glGetProgramInfoLog_NVGLZ is null) assert(0, `OpenGL function 'glGetProgramInfoLog' not found!`);
    glCreateProgram_NVGLZ = cast(glbfn_glCreateProgram)glbindGetProcAddress(`glCreateProgram`);
    if (glCreateProgram_NVGLZ is null) assert(0, `OpenGL function 'glCreateProgram' not found!`);
    glCreateShader_NVGLZ = cast(glbfn_glCreateShader)glbindGetProcAddress(`glCreateShader`);
    if (glCreateShader_NVGLZ is null) assert(0, `OpenGL function 'glCreateShader' not found!`);
    glShaderSource_NVGLZ = cast(glbfn_glShaderSource)glbindGetProcAddress(`glShaderSource`);
    if (glShaderSource_NVGLZ is null) assert(0, `OpenGL function 'glShaderSource' not found!`);
    glCompileShader_NVGLZ = cast(glbfn_glCompileShader)glbindGetProcAddress(`glCompileShader`);
    if (glCompileShader_NVGLZ is null) assert(0, `OpenGL function 'glCompileShader' not found!`);
    glGetShaderiv_NVGLZ = cast(glbfn_glGetShaderiv)glbindGetProcAddress(`glGetShaderiv`);
    if (glGetShaderiv_NVGLZ is null) assert(0, `OpenGL function 'glGetShaderiv' not found!`);
    glAttachShader_NVGLZ = cast(glbfn_glAttachShader)glbindGetProcAddress(`glAttachShader`);
    if (glAttachShader_NVGLZ is null) assert(0, `OpenGL function 'glAttachShader' not found!`);
    glBindAttribLocation_NVGLZ = cast(glbfn_glBindAttribLocation)glbindGetProcAddress(`glBindAttribLocation`);
    if (glBindAttribLocation_NVGLZ is null) assert(0, `OpenGL function 'glBindAttribLocation' not found!`);
    glLinkProgram_NVGLZ = cast(glbfn_glLinkProgram)glbindGetProcAddress(`glLinkProgram`);
    if (glLinkProgram_NVGLZ is null) assert(0, `OpenGL function 'glLinkProgram' not found!`);
    glGetProgramiv_NVGLZ = cast(glbfn_glGetProgramiv)glbindGetProcAddress(`glGetProgramiv`);
    if (glGetProgramiv_NVGLZ is null) assert(0, `OpenGL function 'glGetProgramiv' not found!`);
    glDeleteProgram_NVGLZ = cast(glbfn_glDeleteProgram)glbindGetProcAddress(`glDeleteProgram`);
    if (glDeleteProgram_NVGLZ is null) assert(0, `OpenGL function 'glDeleteProgram' not found!`);
    glDeleteShader_NVGLZ = cast(glbfn_glDeleteShader)glbindGetProcAddress(`glDeleteShader`);
    if (glDeleteShader_NVGLZ is null) assert(0, `OpenGL function 'glDeleteShader' not found!`);
    glGetUniformLocation_NVGLZ = cast(glbfn_glGetUniformLocation)glbindGetProcAddress(`glGetUniformLocation`);
    if (glGetUniformLocation_NVGLZ is null) assert(0, `OpenGL function 'glGetUniformLocation' not found!`);
    glGenBuffers_NVGLZ = cast(glbfn_glGenBuffers)glbindGetProcAddress(`glGenBuffers`);
    if (glGenBuffers_NVGLZ is null) assert(0, `OpenGL function 'glGenBuffers' not found!`);
    glPixelStorei_NVGLZ = cast(glbfn_glPixelStorei)glbindGetProcAddress(`glPixelStorei`);
    if (glPixelStorei_NVGLZ is null) assert(0, `OpenGL function 'glPixelStorei' not found!`);
    glUniform4fv_NVGLZ = cast(glbfn_glUniform4fv)glbindGetProcAddress(`glUniform4fv`);
    if (glUniform4fv_NVGLZ is null) assert(0, `OpenGL function 'glUniform4fv' not found!`);
    glColorMask_NVGLZ = cast(glbfn_glColorMask)glbindGetProcAddress(`glColorMask`);
    if (glColorMask_NVGLZ is null) assert(0, `OpenGL function 'glColorMask' not found!`);
    glStencilOpSeparate_NVGLZ = cast(glbfn_glStencilOpSeparate)glbindGetProcAddress(`glStencilOpSeparate`);
    if (glStencilOpSeparate_NVGLZ is null) assert(0, `OpenGL function 'glStencilOpSeparate' not found!`);
    glDrawArrays_NVGLZ = cast(glbfn_glDrawArrays)glbindGetProcAddress(`glDrawArrays`);
    if (glDrawArrays_NVGLZ is null) assert(0, `OpenGL function 'glDrawArrays' not found!`);
    glStencilOp_NVGLZ = cast(glbfn_glStencilOp)glbindGetProcAddress(`glStencilOp`);
    if (glStencilOp_NVGLZ is null) assert(0, `OpenGL function 'glStencilOp' not found!`);
    glUseProgram_NVGLZ = cast(glbfn_glUseProgram)glbindGetProcAddress(`glUseProgram`);
    if (glUseProgram_NVGLZ is null) assert(0, `OpenGL function 'glUseProgram' not found!`);
    glCullFace_NVGLZ = cast(glbfn_glCullFace)glbindGetProcAddress(`glCullFace`);
    if (glCullFace_NVGLZ is null) assert(0, `OpenGL function 'glCullFace' not found!`);
    glFrontFace_NVGLZ = cast(glbfn_glFrontFace)glbindGetProcAddress(`glFrontFace`);
    if (glFrontFace_NVGLZ is null) assert(0, `OpenGL function 'glFrontFace' not found!`);
    glActiveTexture_NVGLZ = cast(glbfn_glActiveTexture)glbindGetProcAddress(`glActiveTexture`);
    if (glActiveTexture_NVGLZ is null) assert(0, `OpenGL function 'glActiveTexture' not found!`);
    glBindBuffer_NVGLZ = cast(glbfn_glBindBuffer)glbindGetProcAddress(`glBindBuffer`);
    if (glBindBuffer_NVGLZ is null) assert(0, `OpenGL function 'glBindBuffer' not found!`);
    glBufferData_NVGLZ = cast(glbfn_glBufferData)glbindGetProcAddress(`glBufferData`);
    if (glBufferData_NVGLZ is null) assert(0, `OpenGL function 'glBufferData' not found!`);
    glEnableVertexAttribArray_NVGLZ = cast(glbfn_glEnableVertexAttribArray)glbindGetProcAddress(`glEnableVertexAttribArray`);
    if (glEnableVertexAttribArray_NVGLZ is null) assert(0, `OpenGL function 'glEnableVertexAttribArray' not found!`);
    glVertexAttribPointer_NVGLZ = cast(glbfn_glVertexAttribPointer)glbindGetProcAddress(`glVertexAttribPointer`);
    if (glVertexAttribPointer_NVGLZ is null) assert(0, `OpenGL function 'glVertexAttribPointer' not found!`);
    glUniform1i_NVGLZ = cast(glbfn_glUniform1i)glbindGetProcAddress(`glUniform1i`);
    if (glUniform1i_NVGLZ is null) assert(0, `OpenGL function 'glUniform1i' not found!`);
    glUniform2fv_NVGLZ = cast(glbfn_glUniform2fv)glbindGetProcAddress(`glUniform2fv`);
    if (glUniform2fv_NVGLZ is null) assert(0, `OpenGL function 'glUniform2fv' not found!`);
    glDisableVertexAttribArray_NVGLZ = cast(glbfn_glDisableVertexAttribArray)glbindGetProcAddress(`glDisableVertexAttribArray`);
    if (glDisableVertexAttribArray_NVGLZ is null) assert(0, `OpenGL function 'glDisableVertexAttribArray' not found!`);
    glDeleteBuffers_NVGLZ = cast(glbfn_glDeleteBuffers)glbindGetProcAddress(`glDeleteBuffers`);
    if (glDeleteBuffers_NVGLZ is null) assert(0, `OpenGL function 'glDeleteBuffers' not found!`);
    glBlendFuncSeparate_NVGLZ = cast(glbfn_glBlendFuncSeparate)glbindGetProcAddress(`glBlendFuncSeparate`);
    if (glBlendFuncSeparate_NVGLZ is null) assert(0, `OpenGL function 'glBlendFuncSeparate' not found!`);
    initialized = true;
  }
}


/// Create flags
public alias NVGcreateFlags = int;
/// Create flags
public enum /*NVGcreateFlags*/ {
  /// Flag indicating if geometry based anti-aliasing is used (may not be needed when using MSAA).
  NVG_ANTIALIAS = 1<<0,
  /** Flag indicating if strokes should be drawn using stencil buffer. The rendering will be a little
    * slower, but path overlaps (i.e. self-intersecting or sharp turns) will be drawn just once. */
  NVG_STENCIL_STROKES = 1<<1,
  /// Flag indicating that additional debug checks are done.
  NVG_DEBUG = 1<<2,
  /// Filter (antialias) fonts
  NVG_FONT_AA = 1<<7,
  /// Don't filter (antialias) fonts
  NVG_FONT_NOAA = 1<<8,
}

public enum NANOVG_GL_USE_STATE_FILTER = true;

// These are additional flags on top of NVGImageFlags.
public alias NVGimageFlagsGL = int;
public enum /*NVGimageFlagsGL*/ {
  NVG_IMAGE_NODELETE = 1<<16,  // Do not delete GL texture handle.
}


/// Return flags for glClear().
public uint glNVGClearFlags () pure nothrow @safe @nogc {
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
  int evenOdd; // for fill
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
  int ctextures;
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

  IdPool32 texidpool;

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

void glnvg__bindTexture (GLNVGcontext* gl, GLuint tex) nothrow @trusted @nogc {
  static if (NANOVG_GL_USE_STATE_FILTER) {
    if (gl.boundTexture != tex) {
      gl.boundTexture = tex;
      glBindTexture(GL_TEXTURE_2D, tex);
    }
  } else {
    glBindTexture(GL_TEXTURE_2D, tex);
  }
}

void glnvg__stencilMask (GLNVGcontext* gl, GLuint mask) nothrow @trusted @nogc {
  static if (NANOVG_GL_USE_STATE_FILTER) {
    if (gl.stencilMask != mask) {
      gl.stencilMask = mask;
      glStencilMask(mask);
    }
  } else {
    glStencilMask(mask);
  }
}

void glnvg__stencilFunc (GLNVGcontext* gl, GLenum func, GLint ref_, GLuint mask) nothrow @trusted @nogc {
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

// texture id is never zero
GLNVGtexture* glnvg__allocTexture (GLNVGcontext* gl) nothrow @trusted @nogc {
  GLNVGtexture* tex = null;

  uint tid = gl.texidpool.allocId();
  if (tid == gl.texidpool.Invalid) return null;
  assert(tid != 0);

  if (tid-1 >= gl.ctextures) {
    assert(tid-1 == gl.ctextures);
    int ctextures = glnvg__maxi(tid, 4)+gl.ctextures/2; // 1.5x Overallocate
    GLNVGtexture* textures = cast(GLNVGtexture*)realloc(gl.textures, GLNVGtexture.sizeof*ctextures);
    if (textures is null) return null;
    memset(&textures[gl.ctextures], 0, (ctextures-gl.ctextures)*GLNVGtexture.sizeof);
    gl.textures = textures;
    gl.ctextures = ctextures;
  }
  assert(tid-1 < gl.ctextures);

  assert(gl.textures[tid-1].id == 0);
  tex = &gl.textures[tid-1];
  memset(tex, 0, (*tex).sizeof);
  tex.id = tid;

  return tex;
}

GLNVGtexture* glnvg__findTexture (GLNVGcontext* gl, int id) nothrow @trusted @nogc {
  if (!gl.texidpool.isAllocated(id)) return null;
  assert(gl.textures[id-1].id != 0);
  return &gl.textures[id-1];
}

bool glnvg__deleteTexture (GLNVGcontext* gl, int id) nothrow @trusted @nogc {
  if (!gl.texidpool.isAllocated(id)) return false;
  assert(gl.textures[id-1].id != 0);
  if (gl.textures[id-1].tex != 0 && (gl.textures[id-1].flags&NVG_IMAGE_NODELETE) == 0) glDeleteTextures(1, &gl.textures[id-1].tex);
  memset(&gl.textures[id-1], 0, (gl.textures[id-1]).sizeof);
  return true;
}

void glnvg__dumpShaderError (GLuint shader, const(char)* name, const(char)* type) nothrow @trusted @nogc {
  import core.stdc.stdio : fprintf, stderr;
  GLchar[512+1] str = 0;
  GLsizei len = 0;
  glGetShaderInfoLog(shader, 512, &len, str.ptr);
  if (len > 512) len = 512;
  str[len] = '\0';
  fprintf(stderr, "Shader %s/%s error:\n%s\n", name, type, str.ptr);
}

void glnvg__dumpProgramError (GLuint prog, const(char)* name) nothrow @trusted @nogc {
  import core.stdc.stdio : fprintf, stderr;
  GLchar[512+1] str = 0;
  GLsizei len = 0;
  glGetProgramInfoLog(prog, 512, &len, str.ptr);
  if (len > 512) len = 512;
  str[len] = '\0';
  fprintf(stderr, "Program %s error:\n%s\n", name, str.ptr);
}

void glnvg__checkError (GLNVGcontext* gl, const(char)* str) nothrow @trusted @nogc {
  GLenum err;
  if ((gl.flags&NVG_DEBUG) == 0) return;
  err = glGetError();
  if (err != GL_NO_ERROR) {
    import core.stdc.stdio : fprintf, stderr;
    fprintf(stderr, "Error %08x after %s\n", err, str);
    return;
  }
}

bool glnvg__createShader (GLNVGshader* shader, const(char)* name, const(char)* header, const(char)* opts, const(char)* vshader, const(char)* fshader) nothrow @trusted @nogc {
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
  glShaderSource(vert, 3, cast(const(char)**)str.ptr, null);

  glCompileShader(vert);
  glGetShaderiv(vert, GL_COMPILE_STATUS, &status);
  if (status != GL_TRUE) {
    glnvg__dumpShaderError(vert, name, "vert");
    return false;
  }

  str[0] = header;
  str[1] = (opts !is null ? opts : "");
  str[2] = fshader;
  glShaderSource(frag, 3, cast(const(char)**)str.ptr, null);

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

void glnvg__deleteShader (GLNVGshader* shader) nothrow @trusted @nogc {
  if (shader.prog != 0) glDeleteProgram(shader.prog);
  if (shader.vert != 0) glDeleteShader(shader.vert);
  if (shader.frag != 0) glDeleteShader(shader.frag);
}

void glnvg__getUniforms (GLNVGshader* shader) nothrow @trusted @nogc {
  shader.loc[GLNVG_LOC_VIEWSIZE] = glGetUniformLocation(shader.prog, "viewSize");
  shader.loc[GLNVG_LOC_TEX] = glGetUniformLocation(shader.prog, "tex");
  shader.loc[GLNVG_LOC_FRAG] = glGetUniformLocation(shader.prog, "frag");
}

bool glnvg__renderCreate (void* uptr) nothrow @trusted @nogc {
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

    void main (void) {
      vec4 result;
      float scissor = scissorMask(fpos);
      #ifdef EDGE_AA
      float strokeAlpha = strokeMask();
      if (strokeAlpha < strokeThr) discard;
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

  gl.fragSize = GLNVGfragUniforms.sizeof+align_-GLNVGfragUniforms.sizeof%align_;

  glnvg__checkError(gl, "create done");

  glFinish();

  return true;
}

int glnvg__renderCreateTexture (void* uptr, NVGtexture type, int w, int h, int imageFlags, const(ubyte)* data) nothrow @trusted @nogc {
  GLNVGcontext* gl = cast(GLNVGcontext*)uptr;
  GLNVGtexture* tex = glnvg__allocTexture(gl);

  if (tex is null) return 0;

  glGenTextures(1, &tex.tex);
  tex.width = w;
  tex.height = h;
  tex.type = type;
  tex.flags = imageFlags;
  glnvg__bindTexture(gl, tex.tex);

  glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
  glPixelStorei(GL_UNPACK_ROW_LENGTH, tex.width);
  glPixelStorei(GL_UNPACK_SKIP_PIXELS, 0);
  glPixelStorei(GL_UNPACK_SKIP_ROWS, 0);

  // GL 1.4 and later has support for generating mipmaps using a tex parameter.
  if ((imageFlags&(NVGImageFlags.GenerateMipmaps|NVGImageFlags.NoFiltering)) == NVGImageFlags.GenerateMipmaps) glTexParameteri(GL_TEXTURE_2D, GL_GENERATE_MIPMAP, GL_TRUE);

  if (type == NVGtexture.RGBA) {
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE, data);
  } else {
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RED, w, h, 0, GL_RED, GL_UNSIGNED_BYTE, data);
  }

  if ((imageFlags&(NVGImageFlags.GenerateMipmaps|NVGImageFlags.NoFiltering)) == NVGImageFlags.GenerateMipmaps) {
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
  } else {
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, (imageFlags&NVGImageFlags.NoFiltering ? GL_NEAREST : GL_LINEAR));
  }
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, (imageFlags&NVGImageFlags.NoFiltering ? GL_NEAREST : GL_LINEAR));

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


bool glnvg__renderDeleteTexture (void* uptr, int image) nothrow @trusted @nogc {
  GLNVGcontext* gl = cast(GLNVGcontext*)uptr;
  return glnvg__deleteTexture(gl, image);
}

bool glnvg__renderUpdateTexture (void* uptr, int image, int x, int y, int w, int h, const(ubyte)* data) nothrow @trusted @nogc {
  GLNVGcontext* gl = cast(GLNVGcontext*)uptr;
  GLNVGtexture* tex = glnvg__findTexture(gl, image);

  if (tex is null) return false;
  glnvg__bindTexture(gl, tex.tex);

  glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
  glPixelStorei(GL_UNPACK_ROW_LENGTH, tex.width);
  glPixelStorei(GL_UNPACK_SKIP_PIXELS, x);
  glPixelStorei(GL_UNPACK_SKIP_ROWS, y);

  if (tex.type == NVGtexture.RGBA) {
    glTexSubImage2D(GL_TEXTURE_2D, 0, x, y, w, h, GL_RGBA, GL_UNSIGNED_BYTE, data);
  } else {
    glTexSubImage2D(GL_TEXTURE_2D, 0, x, y, w, h, GL_RED, GL_UNSIGNED_BYTE, data);
  }

  glPixelStorei(GL_UNPACK_ALIGNMENT, 4);
  glPixelStorei(GL_UNPACK_ROW_LENGTH, 0);
  glPixelStorei(GL_UNPACK_SKIP_PIXELS, 0);
  glPixelStorei(GL_UNPACK_SKIP_ROWS, 0);

  glnvg__bindTexture(gl, 0);

  return true;
}

bool glnvg__renderGetTextureSize (void* uptr, int image, int* w, int* h) nothrow @trusted @nogc {
  GLNVGcontext* gl = cast(GLNVGcontext*)uptr;
  GLNVGtexture* tex = glnvg__findTexture(gl, image);
  if (tex is null) return false;
  if (w !is null) *w = tex.width;
  if (h !is null) *h = tex.height;
  return true;
}

void glnvg__xformToMat3x4 (float[] m3, const(float)[] t) nothrow @trusted @nogc {
  assert(t.length >= 6);
  assert(m3.length >= 12);
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

NVGColor glnvg__premulColor (NVGColor c) nothrow @trusted @nogc {
  //pragma(inline, true);
  c.r *= c.a;
  c.g *= c.a;
  c.b *= c.a;
  return c;
}

bool glnvg__convertPaint (GLNVGcontext* gl, GLNVGfragUniforms* frag, NVGPaint* paint, NVGscissor* scissor, float width, float fringe, float strokeThr) nothrow @trusted @nogc {
  import core.stdc.math : sqrtf;
  GLNVGtexture* tex = null;
  float[6] invxform = void;

  memset(frag, 0, (*frag).sizeof);

  frag.innerCol = glnvg__premulColor(paint.innerColor);
  frag.outerCol = glnvg__premulColor(paint.outerColor);

  if (scissor.extent[0] < -0.5f || scissor.extent[1] < -0.5f) {
    memset(frag.scissorMat.ptr, 0, frag.scissorMat.sizeof);
    frag.scissorExt.ptr[0] = 1.0f;
    frag.scissorExt.ptr[1] = 1.0f;
    frag.scissorScale.ptr[0] = 1.0f;
    frag.scissorScale.ptr[1] = 1.0f;
  } else {
    nvgTransformInverse(invxform[], scissor.xform[]);
    glnvg__xformToMat3x4(frag.scissorMat[], invxform[]);
    frag.scissorExt.ptr[0] = scissor.extent.ptr[0];
    frag.scissorExt.ptr[1] = scissor.extent.ptr[1];
    frag.scissorScale.ptr[0] = sqrtf(scissor.xform.ptr[0]*scissor.xform.ptr[0]+scissor.xform.ptr[2]*scissor.xform.ptr[2])/fringe;
    frag.scissorScale.ptr[1] = sqrtf(scissor.xform.ptr[1]*scissor.xform.ptr[1]+scissor.xform.ptr[3]*scissor.xform.ptr[3])/fringe;
  }

  memcpy(frag.extent.ptr, paint.extent.ptr, frag.extent.sizeof);
  frag.strokeMult = (width*0.5f+fringe*0.5f)/fringe;
  frag.strokeThr = strokeThr;

  if (paint.image != 0) {
    tex = glnvg__findTexture(gl, paint.image);
    if (tex is null) return false;
    if ((tex.flags&NVGImageFlags.FlipY) != 0) {
      /*
      float[6] flipped;
      nvgTransformScale(flipped[], 1.0f, -1.0f);
      nvgTransformMultiply(flipped[], paint.xform[]);
      nvgTransformInverse(invxform[], flipped[]);
      */
      float[6] m1 = void, m2 = void;
      nvgTransformTranslate(m1[], 0.0f, frag.extent.ptr[1]*0.5f);
      nvgTransformMultiply(m1[], paint.xform[]);
      nvgTransformScale(m2[], 1.0f, -1.0f);
      nvgTransformMultiply(m2[], m1[]);
      nvgTransformTranslate(m1[], 0.0f, -frag.extent.ptr[1]*0.5f);
      nvgTransformMultiply(m1[], m2[]);
      nvgTransformInverse(invxform[], m1[]);
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

void glnvg__setUniforms (GLNVGcontext* gl, int uniformOffset, int image) nothrow @trusted @nogc {
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

void glnvg__renderViewport (void* uptr, int width, int height) nothrow @trusted @nogc {
  GLNVGcontext* gl = cast(GLNVGcontext*)uptr;
  gl.view[0] = cast(float)width;
  gl.view[1] = cast(float)height;
}

void glnvg__fill (GLNVGcontext* gl, GLNVGcall* call) nothrow @trusted @nogc {
  GLNVGpath* paths = &gl.paths[call.pathOffset];
  int npaths = call.pathCount;

  // Draw shapes
  glEnable(GL_STENCIL_TEST);
  glnvg__stencilMask(gl, 0xffffffffU);
  glnvg__stencilFunc(gl, GL_ALWAYS, 0, 0xffffffffU);
  glColorMask(GL_FALSE, GL_FALSE, GL_FALSE, GL_FALSE);

  // set bindpoint for solid loc
  glnvg__setUniforms(gl, call.uniformOffset, 0);
  glnvg__checkError(gl, "fill simple");

  if (call.evenOdd) {
    glStencilOpSeparate(GL_FRONT, GL_KEEP, GL_KEEP, GL_INVERT);
    glStencilOpSeparate(GL_BACK, GL_KEEP, GL_KEEP, GL_INVERT);
  } else {
    glStencilOpSeparate(GL_FRONT, GL_KEEP, GL_KEEP, GL_INCR_WRAP);
    glStencilOpSeparate(GL_BACK, GL_KEEP, GL_KEEP, GL_DECR_WRAP);
  }
  glDisable(GL_CULL_FACE);
  foreach (int i; 0..npaths) glDrawArrays(GL_TRIANGLE_FAN, paths[i].fillOffset, paths[i].fillCount);
  glEnable(GL_CULL_FACE);

  // Draw anti-aliased pixels
  glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);

  glnvg__setUniforms(gl, call.uniformOffset+gl.fragSize, call.image);
  glnvg__checkError(gl, "fill fill");

  if (gl.flags&NVG_ANTIALIAS) {
    glnvg__stencilFunc(gl, GL_EQUAL, 0x00, 0xffffffffU);
    glStencilOp(GL_KEEP, GL_KEEP, GL_KEEP);
    // Draw fringes
    foreach (int i; 0..npaths) glDrawArrays(GL_TRIANGLE_STRIP, paths[i].strokeOffset, paths[i].strokeCount);
  }

  // Draw fill
  glnvg__stencilFunc(gl, GL_NOTEQUAL, 0x0, 0xffffffffU);
  glStencilOp(GL_ZERO, GL_ZERO, GL_ZERO);
  glDrawArrays(GL_TRIANGLE_STRIP, call.triangleOffset, call.triangleCount);

  glDisable(GL_STENCIL_TEST);
}

void glnvg__convexFill (GLNVGcontext* gl, GLNVGcall* call) nothrow @trusted @nogc {
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

void glnvg__stroke (GLNVGcontext* gl, GLNVGcall* call) nothrow @trusted @nogc {
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

void glnvg__triangles (GLNVGcontext* gl, GLNVGcall* call) nothrow @trusted @nogc {
  glnvg__setUniforms(gl, call.uniformOffset, call.image);
  glnvg__checkError(gl, "triangles fill");
  glDrawArrays(GL_TRIANGLES, call.triangleOffset, call.triangleCount);
}

void glnvg__renderCancel (void* uptr) nothrow @trusted @nogc {
  GLNVGcontext* gl = cast(GLNVGcontext*)uptr;
  gl.nverts = 0;
  gl.npaths = 0;
  gl.ncalls = 0;
  gl.nuniforms = 0;
}

GLenum glnvg_convertBlendFuncFactor (NVGBlendFactor factor) nothrow @trusted @nogc {
  if (factor == NVGBlendFactor.ZERO) return GL_ZERO;
  if (factor == NVGBlendFactor.ONE) return GL_ONE;
  if (factor == NVGBlendFactor.SRC_COLOR) return GL_SRC_COLOR;
  if (factor == NVGBlendFactor.ONE_MINUS_SRC_COLOR) return GL_ONE_MINUS_SRC_COLOR;
  if (factor == NVGBlendFactor.DST_COLOR) return GL_DST_COLOR;
  if (factor == NVGBlendFactor.ONE_MINUS_DST_COLOR) return GL_ONE_MINUS_DST_COLOR;
  if (factor == NVGBlendFactor.SRC_ALPHA) return GL_SRC_ALPHA;
  if (factor == NVGBlendFactor.ONE_MINUS_SRC_ALPHA) return GL_ONE_MINUS_SRC_ALPHA;
  if (factor == NVGBlendFactor.DST_ALPHA) return GL_DST_ALPHA;
  if (factor == NVGBlendFactor.ONE_MINUS_DST_ALPHA) return GL_ONE_MINUS_DST_ALPHA;
  if (factor == NVGBlendFactor.SRC_ALPHA_SATURATE) return GL_SRC_ALPHA_SATURATE;
  return GL_INVALID_ENUM;
}

void glnvg__blendCompositeOperation (NVGCompositeOperationState op) nothrow @trusted @nogc {
  //glBlendFuncSeparate(glnvg_convertBlendFuncFactor(op.srcRGB), glnvg_convertBlendFuncFactor(op.dstRGB), glnvg_convertBlendFuncFactor(op.srcAlpha), glnvg_convertBlendFuncFactor(op.dstAlpha));
  GLenum srcRGB = glnvg_convertBlendFuncFactor(op.srcRGB);
  GLenum dstRGB = glnvg_convertBlendFuncFactor(op.dstRGB);
  GLenum srcAlpha = glnvg_convertBlendFuncFactor(op.srcAlpha);
  GLenum dstAlpha = glnvg_convertBlendFuncFactor(op.dstAlpha);
  if (srcRGB == GL_INVALID_ENUM || dstRGB == GL_INVALID_ENUM || srcAlpha == GL_INVALID_ENUM || dstAlpha == GL_INVALID_ENUM) {
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
  } else {
    glBlendFuncSeparate(srcRGB, dstRGB, srcAlpha, dstAlpha);
  }
}

void glnvg__renderFlush (void* uptr, NVGCompositeOperationState compositeOperation) nothrow @trusted @nogc {
  GLNVGcontext* gl = cast(GLNVGcontext*)uptr;
  if (gl.ncalls > 0) {
    // Setup require GL state.
    glUseProgram(gl.shader.prog);

    //glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    glnvg__blendCompositeOperation(compositeOperation);
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
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, NVGvertex.sizeof, cast(const(GLvoid)*)cast(usize)0);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, NVGvertex.sizeof, cast(const(GLvoid)*)(0+2*float.sizeof));

    // Set view and texture just once per frame.
    glUniform1i(gl.shader.loc[GLNVG_LOC_TEX], 0);
    glUniform2fv(gl.shader.loc[GLNVG_LOC_VIEWSIZE], 1, gl.view.ptr);

    foreach (int i; 0..gl.ncalls) {
      GLNVGcall* call = &gl.calls[i];
      switch (call.type) {
        case GLNVG_FILL: glnvg__fill(gl, call); break;
        case GLNVG_CONVEXFILL: glnvg__convexFill(gl, call); break;
        case GLNVG_STROKE: glnvg__stroke(gl, call); break;
        case GLNVG_TRIANGLES: glnvg__triangles(gl, call); break;
        default: break;
      }
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

int glnvg__maxVertCount (const(NVGpath)* paths, int npaths) nothrow @trusted @nogc {
  int count = 0;
  foreach (int i; 0..npaths) {
    count += paths[i].nfill;
    count += paths[i].nstroke;
  }
  return count;
}

GLNVGcall* glnvg__allocCall (GLNVGcontext* gl) nothrow @trusted @nogc {
  GLNVGcall* ret = null;
  if (gl.ncalls+1 > gl.ccalls) {
    GLNVGcall* calls;
    int ccalls = glnvg__maxi(gl.ncalls+1, 128)+gl.ccalls/2; // 1.5x Overallocate
    calls = cast(GLNVGcall*)realloc(gl.calls, GLNVGcall.sizeof*ccalls);
    if (calls is null) return null;
    gl.calls = calls;
    gl.ccalls = ccalls;
  }
  ret = &gl.calls[gl.ncalls++];
  memset(ret, 0, GLNVGcall.sizeof);
  return ret;
}

int glnvg__allocPaths (GLNVGcontext* gl, int n) nothrow @trusted @nogc {
  int ret = 0;
  if (gl.npaths+n > gl.cpaths) {
    GLNVGpath* paths;
    int cpaths = glnvg__maxi(gl.npaths+n, 128)+gl.cpaths/2; // 1.5x Overallocate
    paths = cast(GLNVGpath*)realloc(gl.paths, GLNVGpath.sizeof*cpaths);
    if (paths is null) return -1;
    gl.paths = paths;
    gl.cpaths = cpaths;
  }
  ret = gl.npaths;
  gl.npaths += n;
  return ret;
}

int glnvg__allocVerts (GLNVGcontext* gl, int n) nothrow @trusted @nogc {
  int ret = 0;
  if (gl.nverts+n > gl.cverts) {
    NVGvertex* verts;
    int cverts = glnvg__maxi(gl.nverts+n, 4096)+gl.cverts/2; // 1.5x Overallocate
    verts = cast(NVGvertex*)realloc(gl.verts, NVGvertex.sizeof*cverts);
    if (verts is null) return -1;
    gl.verts = verts;
    gl.cverts = cverts;
  }
  ret = gl.nverts;
  gl.nverts += n;
  return ret;
}

int glnvg__allocFragUniforms (GLNVGcontext* gl, int n) nothrow @trusted @nogc {
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

GLNVGfragUniforms* nvg__fragUniformPtr (GLNVGcontext* gl, int i) nothrow @trusted @nogc {
  return cast(GLNVGfragUniforms*)&gl.uniforms[i];
}

void glnvg__vset (NVGvertex* vtx, float x, float y, float u, float v) nothrow @trusted @nogc {
  vtx.x = x;
  vtx.y = y;
  vtx.u = u;
  vtx.v = v;
}

void glnvg__renderFill (void* uptr, NVGPaint* paint, NVGscissor* scissor, float fringe, const(float)* bounds, const(NVGpath)* paths, int npaths, bool evenOdd) nothrow @trusted @nogc {
  GLNVGcontext* gl = cast(GLNVGcontext*)uptr;
  GLNVGcall* call = glnvg__allocCall(gl);
  NVGvertex* quad;
  GLNVGfragUniforms* frag;
  int maxverts, offset;

  if (call is null || npaths < 1) return;

  call.type = GLNVG_FILL;
  call.evenOdd = evenOdd;
  call.triangleCount = 4;
  call.pathOffset = glnvg__allocPaths(gl, npaths);
  if (call.pathOffset == -1) goto error;
  call.pathCount = npaths;
  call.image = paint.image;

  if (npaths == 1 && paths[0].convex) {
    call.type = GLNVG_CONVEXFILL;
    call.triangleCount = 0; // Bounding box fill quad not needed for convex fill
  }

  // Allocate vertices for all the paths.
  maxverts = glnvg__maxVertCount(paths, npaths)+call.triangleCount;
  offset = glnvg__allocVerts(gl, maxverts);
  if (offset == -1) goto error;

  foreach (int i; 0..npaths) {
    GLNVGpath* copy = &gl.paths[call.pathOffset+i];
    const(NVGpath)* path = &paths[i];
    memset(copy, 0, GLNVGpath.sizeof);
    if (path.nfill > 0) {
      copy.fillOffset = offset;
      copy.fillCount = path.nfill;
      memcpy(&gl.verts[offset], path.fill, NVGvertex.sizeof*path.nfill);
      offset += path.nfill;
    }
    if (path.nstroke > 0) {
      copy.strokeOffset = offset;
      copy.strokeCount = path.nstroke;
      memcpy(&gl.verts[offset], path.stroke, NVGvertex.sizeof*path.nstroke);
      offset += path.nstroke;
    }
  }

  // Setup uniforms for draw calls
  if (call.type == GLNVG_FILL) {
    // Quad
    call.triangleOffset = offset;
    quad = &gl.verts[call.triangleOffset];
    glnvg__vset(&quad[0], bounds[2], bounds[3], 0.5f, 1.0f);
    glnvg__vset(&quad[1], bounds[2], bounds[1], 0.5f, 1.0f);
    glnvg__vset(&quad[2], bounds[0], bounds[3], 0.5f, 1.0f);
    glnvg__vset(&quad[3], bounds[0], bounds[1], 0.5f, 1.0f);
    // Get uniform
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

void glnvg__renderStroke (void* uptr, NVGPaint* paint, NVGscissor* scissor, float fringe, float strokeWidth, const(NVGpath)* paths, int npaths) nothrow @trusted @nogc {
  GLNVGcontext* gl = cast(GLNVGcontext*)uptr;
  GLNVGcall* call = glnvg__allocCall(gl);
  int maxverts, offset;

  if (call is null || npaths < 1) return;

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
      memcpy(&gl.verts[offset], path.stroke, NVGvertex.sizeof*path.nstroke);
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

void glnvg__renderTriangles (void* uptr, NVGPaint* paint, NVGscissor* scissor, const(NVGvertex)* verts, int nverts) nothrow @trusted @nogc {
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

void glnvg__renderDelete (void* uptr) nothrow @trusted @nogc {
  GLNVGcontext* gl = cast(GLNVGcontext*)uptr;
  if (gl is null) return;

  glnvg__deleteShader(&gl.shader);

  if (gl.vertBuf != 0) glDeleteBuffers(1, &gl.vertBuf);

  foreach (int i; 0..gl.ctextures) {
    if (gl.textures[i].tex != 0 && (gl.textures[i].flags&NVG_IMAGE_NODELETE) == 0) glDeleteTextures(1, &gl.textures[i].tex);
  }
  free(gl.textures);

  free(gl.paths);
  free(gl.verts);
  free(gl.uniforms);
  free(gl.calls);

  gl.texidpool.destroy;

  free(gl);
}


/// Creates NanoVega contexts for OpenGL versions.
/// Flags should be combination of the create flags above.
public NVGContext createGL2NVG (int flags) nothrow @trusted @nogc {
  NVGparams params = void;
  NVGContext ctx = null;
  version(nanovg_builtin_opengl_bindings) nanovgInitOpenGL(); // why not?
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
  if (flags&(NVG_FONT_AA|NVG_FONT_NOAA)) {
    params.fontAA = (flags&NVG_FONT_NOAA ? NVG_INVERT_FONT_AA : !NVG_INVERT_FONT_AA);
  } else {
    params.fontAA = NVG_INVERT_FONT_AA;
  }

  gl.flags = flags;

  ctx = createInternal(&params);
  if (ctx is null) goto error;

  return ctx;

error:
  // 'gl' is freed by nvgDeleteInternal.
  if (ctx !is null) ctx.deleteInternal();
  return null;
}

/// Delete NanoVega OpenGL context.
public void deleteGL2 (NVGContext ctx) nothrow @trusted @nogc {
  if (ctx !is null) ctx.deleteInternal();
}

/// Create NanoVega OpenGL image from texture id.
public int glCreateImageFromHandleGL2 (NVGContext ctx, GLuint textureId, int w, int h, int imageFlags) nothrow @trusted @nogc {
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

/// Return OpenGL texture id for NanoVega image.
public GLuint glImageHandleGL2 (NVGContext ctx, int image) nothrow @trusted @nogc {
  GLNVGcontext* gl = cast(GLNVGcontext*)ctx.internalParams().userPtr;
  GLNVGtexture* tex = glnvg__findTexture(gl, image);
  return tex.tex;
}


// ////////////////////////////////////////////////////////////////////////// //
private:

alias IdPool32 = IdPoolImpl!uint;

struct IdPoolImpl(IDT, bool allowZero=false) if (is(IDT == ubyte) || is(IDT == ushort) || is(IDT == uint)) {
public:
  alias Type = IDT; ///
  enum Invalid = cast(IDT)IDT.max; /// "invalid id" value

private:
  static align(1) struct Range {
  align(1):
    Type first;
    Type last;
  }

  size_t rangesmem; // sorted array of ranges of free IDs; Range*; use `size_t` to force GC ignoring this struct
  uint rngcount; // number of ranges in list
  uint rngsize; // total capacity of range list (NOT size in bytes!)

  @property inout(Range)* ranges () const pure inout nothrow @trusted @nogc { pragma(inline, true); return cast(typeof(return))rangesmem; }

private nothrow @trusted @nogc:
  // will NOT change rngcount if `doChange` is `false`
  void growRangeArray(bool doChange) (uint newcount) {
    enum GrowStep = 128;
    if (newcount <= rngcount) {
      static if (doChange) rngcount = newcount;
      return;
    }
    assert(rngcount <= rngsize);
    if (newcount > rngsize) {
      // need to grow
      import core.stdc.stdlib : realloc;
      if (rngsize >= uint.max/(Range.sizeof+8) || newcount >= uint.max/(Range.sizeof+8)) assert(0, "out of memory");
      rngsize = ((newcount+(GrowStep-1))/GrowStep)*GrowStep;
      size_t newmem = cast(size_t)realloc(cast(void*)rangesmem, rngsize*Range.sizeof);
      if (newmem == 0) assert(0, "out of memory");
      rangesmem = newmem;
    }
    assert(newcount <= rngsize);
    static if (doChange) rngcount = newcount;
  }

  void insertRange (uint index) {
    growRangeArray!false(rngcount+1);
    if (index < rngcount) {
      // really inserting
      import core.stdc.string : memmove;
      memmove(ranges+index+1, ranges+index, (rngcount-index)*Range.sizeof);
    }
    ++rngcount;
  }

  void destroyRange (uint index) {
    import core.stdc.string : memmove;
    assert(rngcount > 0);
    if (--rngcount > 0) memmove(ranges+index, ranges+index+1, (rngcount-index)*Range.sizeof);
  }

public:
  this (Type aMaxId) { reset(aMaxId); }

  ~this () {
    if (rangesmem) {
      import core.stdc.stdlib : free;
      free(cast(void*)rangesmem);
    }
  }

  // checks if the given id is in valid id range.
  static bool isValid (Type id) pure nothrow @safe @nogc {
    pragma(inline, true);
    static if (allowZero) return (id != Invalid); else return (id && id != Invalid);
  }

  // remove all allocated ids, and set maximum available id.
  void reset (Type aMaxId=Type.max) {
    if (aMaxId < 1) assert(0, "are you nuts?");
    if (aMaxId == Type.max) --aMaxId; // to ease my life a little
    // start with a single range, from 0/1 to max allowed ID (specified)
    growRangeArray!true(1);
    static if (allowZero) ranges[0].first = 0; else ranges[0].first = 1;
    ranges[0].last = aMaxId;
  }

  // allocate lowest unused id.
  // returns `Invalid` if there are no more ids left.
  Type allocId () {
    if (rngcount == 0) {
      // wasn't inited, init with defaults
      growRangeArray!true(1);
      static if (allowZero) ranges[0].first = 0; else ranges[0].first = 1;
      ranges[0].last = Type.max-1;
    }
    auto rng = ranges;
    Type id = Invalid;
    if (rng.first <= rng.last) {
      id = rng.first;
      // if current range is full and there is another one, that will become the new current range
      if (rng.first == rng.last && rngcount > 1) destroyRange(0); else ++rng.first;
    }
    // otherwise we have no ranges left
    return id;
  }

  // allocate the given id.
  // returns id, or `Invalid` if this id was alrady allocated.
  Type allocId (Type aid) {
    static if (allowZero) {
      if (aid == Invalid) return Invalid;
    } else {
      if (aid == 0 || aid == Invalid) return Invalid;
    }

    if (rngcount == 0) {
      // wasn't inited, create two ranges (before and after this id)
      // but check for special cases first
      static if (allowZero) enum LowestId = 0; else enum LowestId = 1;
      // lowest possible id?
      if (aid == LowestId) {
        growRangeArray!true(1);
        ranges[0].first = cast(Type)(LowestId+1);
        ranges[0].last = Type.max-1;
        return aid;
      }
      // highest possible id?
      if (aid == Type.max-1) {
        growRangeArray!true(1);
        ranges[0].first = cast(Type)LowestId;
        ranges[0].last = Type.max-2;
        return aid;
      }
      // create two ranges
      growRangeArray!true(2);
      ranges[0].first = cast(Type)LowestId;
      ranges[0].last = cast(Type)(aid-1);
      ranges[1].first = cast(Type)(aid+1);
      ranges[1].last = cast(Type)(Type.max-1);
      return aid;
    }
    // already inited, check if the given id is not allocated, and split ranges
    // binary search of the range list
    uint i0 = 0, i1 = rngcount-1;
    for (;;) {
      uint i = (i0+i1)/2; // guaranteed to not overflow, see `growRangeArray()`
      Range* rngi = ranges+i;
      if (aid < rngi.first) {
        if (i == i0) return Invalid; // already allocated
        // cull upper half of list
        i1 = i-1;
      } else if (aid > rngi.last) {
        if (i == i1) return Invalid; // already allocated
        // cull bottom half of list
        i0 = i+1;
      } else {
        // inside a free block, split it
        // check for corner case: do we want range's starting id?
        if (rngi.first == aid) {
          // if current range is full and there is another one, that will become the new current range
          if (rngi.first == rngi.last && rngcount > 1) destroyRange(i); else ++rngi.first;
          return aid;
        }
        // check for corner case: do we want range's ending id?
        if (rngi.last == aid) {
          // if current range is full and there is another one, that will become the new current range
          if (rngi.first == rngi.last) {
            if (rngcount > 1) destroyRange(i); else ++rngi.first; // turn range into invalid
          } else {
            --rngi.last;
          }
          return aid;
        }
        // have to split the range in two
        if (rngcount >= uint.max-2) return Invalid; // no room
        insertRange(i+1);
        rngi = ranges+i; // pointer may be invalidated by inserting, so update it
        rngi[1].last = rngi.last;
        rngi[1].first = cast(Type)(aid+1);
        rngi[0].last = cast(Type)(aid-1);
        assert(rngi[0].first <= rngi[0].last);
        assert(rngi[1].first <= rngi[1].last);
        assert(rngi[0].last+2 == rngi[1].first);
        return aid;
      }
    }
  }

  // release allocated id.
  // returns `true` if `id` was a valid allocated one.
  bool releaseId (Type id) { return releaseRange(id, 1); }

  // release allocated id range.
  // returns `true` if the rage was a valid allocated one.
  bool releaseRange (Type id, uint count) {
    if (count == 0 || rngcount == 0) return false;
    if (count >= Type.max) return false; // too many

    static if (allowZero) {
      if (id == Invalid) return false;
    } else {
      if (id == 0 || id == Invalid) return false;
    }

    uint endid = id+count;
    static if (is(Type == uint)) {
      if (endid <= id) return false; // overflow check; fuck you, C!
    } else {
      if (endid <= id || endid > Type.max) return false; // overflow check; fuck you, C!
    }

    // binary search of the range list
    uint i0 = 0, i1 = rngcount-1;
    for (;;) {
      uint i = (i0+i1)/2; // guaranteed to not overflow, see `growRangeArray()`
      Range* rngi = ranges+i;
      if (id < rngi.first) {
        // before current range, check if neighboring
        if (endid >= rngi.first) {
          if (endid != rngi.first) return false; // overlaps a range of free IDs, thus (at least partially) invalid IDs
          // neighbor id, check if neighboring previous range too
          if (i > i0 && id-1 == ranges[i-1].last) {
            // merge with previous range
            ranges[i-1].last = rngi.last;
            destroyRange(i);
          } else {
            // just grow range
            rngi.first = id;
          }
          return true;
        } else {
          // non-neighbor id
          if (i != i0) {
            // cull upper half of list
            i1 = i-1;
          } else {
            // found our position in the list, insert the deleted range here
            insertRange(i);
            // refresh pointer
            rngi = ranges+i;
            rngi.first = id;
            rngi.last = cast(Type)(endid-1);
            return true;
          }
        }
      } else if (id > rngi.last) {
        // after current range, check if neighboring
        if (id-1 == rngi.last) {
          // neighbor id, check if neighboring next range too
          if (i < i1 && endid == ranges[i+1].first) {
            // merge with next range
            rngi.last = ranges[i+1].last;
            destroyRange(i+1);
          } else {
            // just grow range
            rngi.last += count;
          }
          return true;
        } else {
          // non-neighbor id
          if (i != i1) {
            // cull bottom half of list
            i0 = i+1;
          } else {
            // found our position in the list, insert the deleted range here
            insertRange(i+1);
            // get pointer to [i+1]
            rngi = ranges+i+1;
            rngi.first = id;
            rngi.last = cast(Type)(endid-1);
            return true;
          }
        }
      } else {
        // inside a free block, not a valid ID
        return false;
      }
    }
  }

  // is the gived id valid and allocated?
  bool isAllocated (Type id) const {
    if (rngcount == 0) return false; // anyway, 'cause not inited
    static if (allowZero) {
      if (id == Invalid) return false;
    } else {
      if (id == 0 || id == Invalid) return false;
    }
    // binary search of the range list
    uint i0 = 0, i1 = rngcount-1;
    for (;;) {
      uint i = (i0+i1)/2; // guaranteed to not overflow, see `growRangeArray()`
      const(Range)* rngi = ranges+i;
      if (id < rngi.first) {
        if (i == i0) return true;
        // cull upper half of list
        i1 = i-1;
      } else if (id > rngi.last) {
        if (i == i1) return true;
        // cull bottom half of list
        i0 = i+1;
      } else {
        // inside a free block, not a valid ID
        return false;
      }
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
static if (NVG_HAS_FONTCONFIG) {
  version(nanovg_builtin_fontconfig_bindings) {
    pragma(lib, "fontconfig");

    private extern(C) nothrow @trusted @nogc {
      enum FC_FILE = "file"; /* String */
      alias FcBool = int;
      alias FcChar8 = char;
      struct FcConfig;
      struct FcPattern;
      alias FcMatchKind = int;
      enum : FcMatchKind {
        FcMatchPattern,
        FcMatchFont,
        FcMatchScan
      }
      alias FcResult = int;
      enum : FcResult {
        FcResultMatch,
        FcResultNoMatch,
        FcResultTypeMismatch,
        FcResultNoId,
        FcResultOutOfMemory
      }
      FcBool FcInit ();
      FcBool FcConfigSubstituteWithPat (FcConfig* config, FcPattern* p, FcPattern* p_pat, FcMatchKind kind);
      void FcDefaultSubstitute (FcPattern* pattern);
      FcBool FcConfigSubstitute (FcConfig* config, FcPattern* p, FcMatchKind kind);
      FcPattern* FcFontMatch (FcConfig* config, FcPattern* p, FcResult* result);
      FcPattern* FcNameParse (const(FcChar8)* name);
      void FcPatternDestroy (FcPattern* p);
      FcResult FcPatternGetString (const(FcPattern)* p, const(char)* object, int n, FcChar8** s);
    }
  }

  __gshared bool fontconfigAvailable = false;
  // initialize fontconfig
  shared static this () {
    if (FcInit()) {
      fontconfigAvailable = true;
    } else {
      import core.stdc.stdio : stderr, fprintf;
      stderr.fprintf("***NanoVega WARNING: cannot init fontconfig!\n");
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
public enum BaphometDims = 512.0f; // baphomet icon is 512x512 ([0..511])
// mode: 'f' to allow fills; 's' to allow strokes; 'w' to allow stroke widths; 'c' to replace fills with strokes
public void renderBaphomet(string mode="fs") (NVGContext nvg, float ofsx=0, float ofsy=0, float scalex=1, float scaley=1) nothrow @trusted @nogc {
  static immutable float[2264] path =
[ 0x0p+0,0x0p+0,0x0p+0,0x1.ffp+8,0x1.ffp+8,0x1p+0,0x1p+2,0x1.8p+2,0x1.ff126p+7,0x1.ffp+8,
  0x1p+3,0x1.8c3b4p+8,0x1.ffp+8,0x1.ffp+8,0x1.8c3b44p+8,0x1.ffp+8,0x1.ff126p+7,0x1p+3,
  0x1.ffp+8,0x1.cb12f4p+6,0x1.8c3b4p+8,0x0p+0,0x1.ff126p+7,0x0p+0,0x1p+3,0x1.cb12f4p+6,
  0x0p+0,0x0p+0,0x1.cb12f4p+6,0x0p+0,0x1.ff126p+7,0x1p+3,0x0p+0,0x1.8c3b44p+8,0x1.cb12f4p+6,
  0x1.ffp+8,0x1.ff126p+7,0x1.ffp+8,0x1.4p+3,0x1.8p+2,0x1.ff126p+7,0x1.bb0ee4p+8,
  0x1p+3,0x1.66d02cp+8,0x1.bb0ee4p+8,0x1.bb0ee2p+8,0x1.66d02ep+8,0x1.bb0ee2p+8,0x1.ff126p+7,
  0x1p+3,0x1.bb0ee2p+8,0x1.305fa4p+7,0x1.66d02cp+8,0x1.0fc46ap+6,0x1.ff126p+7,0x1.0fc46ap+6,
  0x1p+3,0x1.305fa2p+7,0x1.0fc46ap+6,0x1.0fc46ap+6,0x1.305fa4p+7,0x1.0fc46ap+6,0x1.ff126p+7,
  0x1p+3,0x1.0fc46ap+6,0x1.66d02ep+8,0x1.305fa2p+7,0x1.bb0ee4p+8,0x1.ff126p+7,0x1.bb0ee4p+8,
  0x1.4p+3,0x1.8p+2,0x1.2396f2p+7,0x1.af7ec4p+6,0x1.cp+2,0x1.fe7f48p+7,0x1.b90c16p+8,
  0x1.cp+2,0x1.6572d8p+8,0x1.95a3dp+6,0x1.cp+2,0x1.409adcp+6,0x1.382152p+8,0x1.cp+2,
  0x1.b08026p+8,0x1.382152p+8,0x1.cp+2,0x1.2396f2p+7,0x1.af7ec4p+6,0x1.4p+3,0x1.8p+2,
  0x1.e8853p+7,0x1.d11b62p+7,0x1p+3,0x1.f249aep+7,0x1.dd0774p+7,0x1.f82d52p+7,0x1.ed42acp+7,
  0x1.fa54e8p+7,0x1.00e688p+8,0x1p+3,0x1.fda2aap+7,0x1.edd5c6p+7,0x1.023178p+8,0x1.dd50fep+7,
  0x1.08151ep+8,0x1.d1f804p+7,0x1.2p+3,0x1.8p+2,0x1.1a5324p+8,0x1.cf86e6p+7,0x1p+3,
  0x1.1db348p+8,0x1.f54de4p+7,0x1.10451ep+8,0x1.fa54eap+7,0x1.04fe84p+8,0x1.11901p+8,
  0x1.2p+3,0x1.8p+2,0x1.e8f382p+7,0x1.12c8ap+8,0x1p+3,0x1.e45adp+7,0x1.0243dcp+8,
  0x1.ab2f9ap+7,0x1.f7e3ccp+7,0x1.bbd922p+7,0x1.d58f5p+7,0x1.2p+3,0x1.8p+2,0x1.a54bf4p+7,
  0x1.f92ecp+7,0x1p+3,0x1.a1fe32p+7,0x1.14ddd2p+8,0x1.e17b6p+7,0x1.04a298p+8,0x1.d3d608p+7,
  0x1.1c1eccp+8,0x1.2p+3,0x1.8p+2,0x1.e37e2ep+7,0x1.28b058p+8,0x1p+3,0x1.dd2c38p+7,
  0x1.32d0c2p+8,0x1.dc745ap+7,0x1.3d039p+8,0x1.e5376ep+7,0x1.4748c2p+8,0x1.2p+3,
  0x1.8p+2,0x1.05b66p+8,0x1.27d3b6p+8,0x1p+3,0x1.090422p+8,0x1.32d0c2p+8,0x1.0895dp+8,
  0x1.3d4d1cp+8,0x1.04fe84p+8,0x1.4748c2p+8,0x1.2p+3,0x1.8p+2,0x1.0a0588p+8,0x1.2417a2p+8,
  0x1p+3,0x1.0d65acp+8,0x1.243c68p+8,0x1.0eb09ep+8,0x1.25e348p+8,0x1.0fb206p+8,0x1.298cf6p+8,
  0x1.2p+3,0x1.8p+2,0x1.c87d0ep+7,0x1.267662p+8,0x1p+3,0x1.c97e76p+7,0x1.23f2dep+8,
  0x1.ce172cp+7,0x1.22958ap+8,0x1.d5fd9ep+7,0x1.225e62p+8,0x1.2p+3,0x1.8p+2,0x1.6ae82cp+8,
  0x1.1dd81p+8,0x1p+3,0x1.649636p+8,0x1.16bbdcp+8,0x1.5a9a9p+8,0x1.154c24p+8,0x1.4fafe6p+8,
  0x1.1570e8p+8,0x1p+3,0x1.416518p+8,0x1.15f19ap+8,0x1.368cdp+8,0x1.0f1ef2p+8,0x1.2d9292p+8,
  0x1.047dd2p+8,0x1p+3,0x1.2eb8cp+8,0x1.17bd42p+8,0x1.27409cp+8,0x1.267662p+8,0x1.1bd53ep+8,
  0x1.331a4ep+8,0x1p+3,0x1.19c00ep+8,0x1.36680cp+8,0x1.19d27p+8,0x1.3c148cp+8,0x1.17987ap+8,
  0x1.440d64p+8,0x1p+3,0x1.1481e2p+8,0x1.48256p+8,0x1.11a272p+8,0x1.4c86ecp+8,0x1.100df4p+8,
  0x1.52eb48p+8,0x1p+3,0x1.10d832p+8,0x1.593d3ep+8,0x1.0fd6ccp+8,0x1.60ec88p+8,0x1.0d9cd6p+8,
  0x1.697876p+8,0x1p+3,0x1.0b1952p+8,0x1.6ba00cp+8,0x1.07ddf4p+8,0x1.6d46e8p+8,0x1.03207ap+8,
  0x1.6dec62p+8,0x1p+3,0x1.fac33ap+7,0x1.6e91dcp+8,0x1.ea3e76p+7,0x1.6dc79ep+8,0x1.dadfdcp+7,
  0x1.6bc4dp+8,0x1p+3,0x1.d7dba8p+7,0x1.645f0ep+8,0x1.d7921cp+7,0x1.5cf94ep+8,0x1.cff53p+7,
  0x1.56a756p+8,0x1p+3,0x1.c8584ap+7,0x1.514466p+8,0x1.c32c8p+7,0x1.4b8586p+8,0x1.c1bcc8p+7,
  0x1.4545f4p+8,0x1p+3,0x1.c0bb6p+7,0x1.3e980cp+8,0x1.bf9534p+7,0x1.367a7p+8,0x1.b91e76p+7,
  0x1.31610ap+8,0x1p+3,0x1.a26c84p+7,0x1.23e07ap+8,0x1.929f9ap+7,0x1.1773b6p+8,0x1.89b7cp+7,
  0x1.091684p+8,0x1p+3,0x1.8992fcp+7,0x1.1aaf14p+8,0x1.1ed978p+7,0x1.1cc446p+8,0x1.0e2feap+7,
  0x1.1e7d8ap+8,0x1.2p+3,0x1.8p+2,0x1.edd5cp+7,0x1.8bdf56p+8,0x1p+3,0x1.f20024p+7,
  0x1.7f9756p+8,0x1.db72f2p+7,0x1.751afcp+8,0x1.dadfdcp+7,0x1.6bd73p+8,0x1p+3,0x1.f605cp+7,
  0x1.7038bep+8,0x1.04590ap+8,0x1.70cbd2p+8,0x1.0d65acp+8,0x1.6a0b8cp+8,0x1p+3,0x1.0b9a06p+8,
  0x1.7272b4p+8,0x1.029fc8p+8,0x1.7fa9b6p+8,0x1.04d9bep+8,0x1.8b2778p+8,0x1.2p+3,
  0x1.8p+2,0x1.45a1ep+7,0x1.1032bap+7,0x1p+3,0x1.935778p+7,0x1.526a94p+7,0x1.cbef96p+7,
  0x1.8a6f9cp+7,0x1.c7321cp+7,0x1.b98ccep+7,0x1.2p+3,0x1.8p+2,0x1.57280ap+8,0x1.082784p+7,
  0x1p+3,0x1.304d3ep+8,0x1.4a8422p+7,0x1.14012ep+8,0x1.826464p+7,0x1.165feap+8,0x1.b1818ep+7,
  0x1.2p+3,0x1.8p+2,0x1.910b1ep+7,0x1.1951cp+8,0x1p+3,0x1.9154aap+7,0x1.1951cp+8,
  0x1.927ad6p+7,0x1.188782p+8,0x1.92c462p+7,0x1.188782p+8,0x1p+3,0x1.5fc65ep+7,0x1.31cf5ap+8,
  0x1.1a1bfep+7,0x1.35e75ap+8,0x1.995fep+6,0x1.2e00e8p+8,0x1p+3,0x1.ef4576p+6,0x1.269b26p+8,
  0x1.1032bcp+7,0x1.0e54b4p+8,0x1.20dc46p+7,0x1.0d2e84p+8,0x1p+3,0x1.67d194p+7,0x1.007836p+8,
  0x1.9bd1p+7,0x1.e1e9b4p+7,0x1.9e1d5cp+7,0x1.ca3656p+7,0x1p+3,0x1.a92cccp+7,0x1.77c346p+7,
  0x1.33889cp+7,0x1.2c354p+7,0x1.29c42p+7,0x1.c0284cp+6,0x1p+3,0x1.3922b8p+7,0x1.dc4f96p+6,
  0x1.488152p+7,0x1.f876e2p+6,0x1.57dfe6p+7,0x1.0a4f16p+7,0x1p+3,0x1.5897c4p+7,0x1.0f0c9p+7,
  0x1.5ec4f2p+7,0x1.13ca0ap+7,0x1.6864aap+7,0x1.13a54p+7,0x1p+3,0x1.6d46e8p+7,0x1.11a274p+7,
  0x1.7102fcp+7,0x1.15a812p+7,0x1.73741ap+7,0x1.1bd54p+7,0x1p+3,0x1.7bc8dep+7,0x1.1d8e86p+7,
  0x1.7dcbacp+7,0x1.229588p+7,0x1.80f4aap+7,0x1.26e4b2p+7,0x1p+3,0x1.8924aap+7,0x1.28e77ep+7,
  0x1.8d2a46p+7,0x1.2e134ap+7,0x1.91e7cp+7,0x1.32abfcp+7,0x1p+3,0x1.929f9ap+7,0x1.382154p+7,
  0x1.96eec2p+7,0x1.3adbfcp+7,0x1.9bd1p+7,0x1.3d2856p+7,0x1p+3,0x1.a392bp+7,0x1.3e4e82p+7,
  0x1.a70536p+7,0x1.40e46ap+7,0x1.a9e4a6p+7,0x1.439f1p+7,0x1p+3,0x1.aa52f6p+7,0x1.4a15dp+7,
  0x1.b05b64p+7,0x1.4dd1dep+7,0x1.b76536p+7,0x1.511fap+7,0x1p+3,0x1.bfdebep+7,0x1.5423d6p+7,
  0x1.bfb9fap+7,0x1.592adcp+7,0x1.c14e76p+7,0x1.5de856p+7,0x1p+3,0x1.c3760cp+7,0x1.63cbfap+7,
  0x1.c6c3cep+7,0x1.6661dep+7,0x1.caa4a6p+7,0x1.676346p+7,0x1p+3,0x1.d14024p+7,0x1.68d2fep+7,
  0x1.d38c8p+7,0x1.6dfec8p+7,0x1.d520fcp+7,0x1.7398e2p+7,0x1p+3,0x1.d6b578p+7,0x1.76e6a2p+7,
  0x1.d89382p+7,0x1.79a14ap+7,0x1.dd75cp+7,0x1.78e97p+7,0x1p+3,0x1.e638d6p+7,0x1.7d8226p+7,
  0x1.e3ec8p+7,0x1.823f9cp+7,0x1.e512aap+7,0x1.86fd1ap+7,0x1p+3,0x1.e45adp+7,0x1.975d12p+7,
  0x1.e8f382p+7,0x1.98f196p+7,0x1.ed42aap+7,0x1.9b62b6p+7,0x1p+3,0x1.f47144p+7,0x1.9cada2p+7,
  0x1.f16d0ap+7,0x1.a82b62p+7,0x1.ef8f06p+7,0x1.b81d12p+7,0x1p+3,0x1.ee8d9ep+7,0x1.bf021ep+7,
  0x1.f5bc34p+7,0x1.bb8f9cp+7,0x1.00e684p+8,0x1.b58732p+7,0x1p+3,0x1.04590ap+8,0x1.b3cdecp+7,
  0x1.027b02p+8,0x1.a0202cp+7,0x1.011dacp+8,0x1.9332b6p+7,0x1p+3,0x1.01d588p+8,0x1.8d2a44p+7,
  0x1.03c5f4p+8,0x1.87d9b4p+7,0x1.06eefp+8,0x1.8365c8p+7,0x1p+3,0x1.0a4f14p+8,0x1.7cef0cp+7,
  0x1.0b3e18p+8,0x1.77e80ep+7,0x1.0c2d1ep+8,0x1.7305ccp+7,0x1p+3,0x1.0c890ap+8,0x1.6bb26ep+7,
  0x1.0e9e3cp+8,0x1.68f7c2p+7,0x1.1121bep+8,0x1.66ab6cp+7,0x1p+3,0x1.15275cp+8,0x1.63cbfap+7,
  0x1.1425f4p+8,0x1.5a077ep+7,0x1.14f032p+8,0x1.58bc8ap+7,0x1p+3,0x1.17e206p+8,0x1.528f58p+7,
  0x1.1a2e5ep+8,0x1.508c8ap+7,0x1.1c439p+8,0x1.4f666p+7,0x1p+3,0x1.1f9152p+8,0x1.4dd1dep+7,
  0x1.20b77ep+8,0x1.4982b6p+7,0x1.21942p+8,0x1.44c54p+7,0x1p+3,0x1.22ba4cp+8,0x1.3f9976p+7,
  0x1.24e1ep+8,0x1.3c26fp+7,0x1.27aeeep+8,0x1.3a48e6p+7,0x1p+3,0x1.2c7ecap+8,0x1.36b19cp+7,
  0x1.2cff7cp+8,0x1.31177ep+7,0x1.2eb8cp+8,0x1.2d5b6cp+7,0x1p+3,0x1.335174p+8,0x1.2396fp+7,
  0x1.35c292p+8,0x1.2396fp+7,0x1.38a202p+8,0x1.21b8e6p+7,0x1p+3,0x1.3a48e4p+8,0x1.1fffa4p+7,
  0x1.3ba638p+8,0x1.1dd80ep+7,0x1.3b93d6p+8,0x1.18f5dp+7,0x1p+3,0x1.3b00cp+8,0x1.117daep+7,
  0x1.3fd09ap+8,0x1.10a10cp+7,0x1.437a4ap+8,0x1.0e54b6p+7,0x1p+3,0x1.46ff32p+8,0x1.0be392p+7,
  0x1.4a3a9p+8,0x1.08710cp+7,0x1.4ce2d8p+8,0x1.02b23p+7,0x1p+3,0x1.4d2c64p+8,0x1.fec8dcp+6,
  0x1.4e529p+8,0x1.fb9fdap+6,0x1.4f78bep+8,0x1.f876e2p+6,0x1p+3,0x1.53c7e6p+8,0x1.eefbeep+6,
  0x1.54dbbp+8,0x1.e5ca8ap+6,0x1.56829p+8,0x1.dc4f96p+6,0x1p+3,0x1.57f248p+8,0x1.d2d4a4p+6,
  0x1.5a19dcp+8,0x1.cf1898p+6,0x1.5c6636p+8,0x1.cbef98p+6,0x1p+3,0x1.5ed754p+8,0x1.c6c3dp+6,
  0x1.5feb2p+8,0x1.c1e192p+6,0x1.60c7cp+8,0x1.bcb5cap+6,0x1p+3,0x1.670754p+8,0x1.125a52p+7,
  0x1.1dfcd4p+8,0x1.78e97p+7,0x1.2a0daap+8,0x1.cef3ccp+7,0x1p+3,0x1.2ea65ep+8,0x1.e961d2p+7,
  0x1.40515p+8,0x1.edfa86p+7,0x1.5a5106p+8,0x1.02b22ep+8,0x1p+3,0x1.7fce7ap+8,0x1.191a96p+8,
  0x1.752d5cp+8,0x1.244eccp+8,0x1.8fc02ap+8,0x1.2c22dep+8,0x1p+3,0x1.64bafcp+8,0x1.3003b6p+8,
  0x1.40ad3cp+8,0x1.2f83p+8,0x1.2e5cd2p+8,0x1.1a2e62p+8,0x1.2p+3,0x1.8p+2,0x1.734f56p+7,
  0x1.1c1ecep+7,0x1p+3,0x1.7779b6p+7,0x1.2125dp+7,0x1.770b6ap+7,0x1.28792ep+7,0x1.734f56p+7,
  0x1.301618p+7,0x1.2p+3,0x1.8p+2,0x1.806194p+7,0x1.26766p+7,0x1p+3,0x1.87902ep+7,
  0x1.2e134ap+7,0x1.8992fcp+7,0x1.35b034p+7,0x1.86453ap+7,0x1.3d4d1ap+7,0x1.2p+3,
  0x1.8p+2,0x1.98f19p+7,0x1.3b93dap+7,0x1p+3,0x1.9c6416p+7,0x1.419c44p+7,0x1.9d8a46p+7,
  0x1.47a4bp+7,0x1.9c6416p+7,0x1.4d8856p+7,0x1.2p+3,0x1.8p+2,0x1.b011d8p+7,0x1.4d638ep+7,
  0x1p+3,0x1.b13804p+7,0x1.5601dep+7,0x1.b0c9b2p+7,0x1.5d7a04p+7,0x1.aea22p+7,0x1.63826ep+7,
  0x1.2p+3,0x1.8p+2,0x1.c3bf96p+7,0x1.62ca94p+7,0x1p+3,0x1.c6557cp+7,0x1.6a677ap+7,
  0x1.c5c264p+7,0x1.7094acp+7,0x1.c307bcp+7,0x1.75c078p+7,0x1.2p+3,0x1.8p+2,0x1.d4fc38p+7,
  0x1.7272b6p+7,0x1p+3,0x1.d62262p+7,0x1.7ba418p+7,0x1.d4fc38p+7,0x1.85b226p+7,0x1.d189b2p+7,
  0x1.90c196p+7,0x1.2p+3,0x1.8p+2,0x1.e783cap+7,0x1.97f02cp+7,0x1p+3,0x1.e5ef4cp+7,
  0x1.9ffb62p+7,0x1.e20e76p+7,0x1.a62894p+7,0x1.dbe144p+7,0x1.aa52f8p+7,0x1.2p+3,
  0x1.8p+2,0x1.4d1ap+8,0x1.0243dep+7,0x1p+3,0x1.4df6a4p+8,0x1.05919cp+7,0x1.4e2dccp+8,
  0x1.0a98a2p+7,0x1.4cd076p+8,0x1.10ea98p+7,0x1.2p+3,0x1.8p+2,0x1.4241bcp+8,0x1.10a10cp+7,
  0x1p+3,0x1.429da8p+8,0x1.17cfa6p+7,0x1.41d36ap+8,0x1.1eb4b2p+7,0x1.3f9974p+8,0x1.2506a8p+7,
  0x1.2p+3,0x1.8p+2,0x1.33f6eep+8,0x1.262cd8p+7,0x1p+3,0x1.35f9bcp+8,0x1.297a94p+7,
  0x1.36680cp+8,0x1.32abfcp+7,0x1.33d226p+8,0x1.3e4e82p+7,0x1.2p+3,0x1.8p+2,0x1.279c8cp+8,
  0x1.3b4a4cp+7,0x1p+3,0x1.2955cep+8,0x1.3f9976p+7,0x1.29683p+8,0x1.48815p+7,0x1.2777c4p+8,
  0x1.51fc42p+7,0x1.2p+3,0x1.8p+2,0x1.1b1d62p+8,0x1.50b15p+7,0x1p+3,0x1.1d2032p+8,
  0x1.5626a8p+7,0x1.1db348p+8,0x1.628108p+7,0x1.1b548cp+8,0x1.6e4852p+7,0x1.2p+3,
  0x1.8p+2,0x1.117dacp+8,0x1.6661dep+7,0x1p+3,0x1.136e18p+8,0x1.6b441cp+7,0x1.146f8p+8,
  0x1.7754f4p+7,0x1.129176p+8,0x1.82f776p+7,0x1.2p+3,0x1.8p+2,0x1.055a74p+8,0x1.86b388p+7,
  0x1p+3,0x1.076fa4p+8,0x1.88b656p+7,0x1.0bac6ap+8,0x1.93ea9p+7,0x1.0d2e84p+8,0x1.9f4388p+7,
  0x1.2p+3,0x1.8p+2,0x1.016738p+8,0x1.b4aa9p+7,0x1p+3,0x1.018bfep+8,0x1.aae612p+7,
  0x1.01c326p+8,0x1.a6721ep+7,0x1.fd7de2p+7,0x1.99ce3p+7,0x1.2p+3,0x1.8p+2,0x1.f605cp+7,
  0x1.bbd924p+7,0x1p+3,0x1.f67412p+7,0x1.b1efep+7,0x1.f67412p+7,0x1.b663ccp+7,0x1.f605cp+7,
  0x1.ac9f5p+7,0x1.2p+3,0x1.8p+2,0x1.fa9e72p+7,0x1.b91e7cp+7,0x1p+3,0x1.f9c1d2p+7,
  0x1.b13806p+7,0x1.02563cp+8,0x1.b460fep+7,0x1.fae7fep+7,0x1.a36decp+7,0x1.2p+3,
  0x1.8p+2,0x1.a570b8p+7,0x1.0e425p+8,0x1p+3,0x1.ae7d5cp+7,0x1.113424p+8,0x1.adea46p+7,
  0x1.17e208p+8,0x1.b7f84ap+7,0x1.1ce90ap+8,0x1p+3,0x1.c3e45ep+7,0x1.20a51cp+8,0x1.d9b9b2p+7,
  0x1.1ce90ap+8,0x1.d2418cp+7,0x1.1bb07ap+8,0x1p+3,0x1.b518dap+7,0x1.1a77eap+8,0x1.b0ee7ap+7,
  0x1.0f8d42p+8,0x1.bddbfp+7,0x1.0c1abcp+8,0x1.2p+3,0x1.8p+2,0x1.2599bcp+8,0x1.0e2feep+8,
  0x1p+3,0x1.21136cp+8,0x1.110f5cp+8,0x1.214a94p+8,0x1.17bd42p+8,0x1.1c55f2p+8,0x1.1cc446p+8,
  0x1p+3,0x1.165feap+8,0x1.2092b8p+8,0x1.0bac6ap+8,0x1.1c8d1cp+8,0x1.0f687ap+8,0x1.1b548ep+8,
  0x1p+3,0x1.1dfcd4p+8,0x1.1a1bfep+8,0x1.1ed976p+8,0x1.0e2feep+8,0x1.1862b8p+8,0x1.0abd64p+8,
  0x1.2p+3,0x1.8p+2,0x1.2270cp+8,0x1.f4bad2p+7,0x1p+3,0x1.243c68p+8,0x1.12b63cp+8,
  0x1.fcc608p+7,0x1.0802bcp+8,0x1.0e54b2p+8,0x1.1b9e1ap+8,0x1.2p+3,0x1.8p+1,0x1p+2,
  0x1.8p+2,0x1.c630b4p+7,0x1.16f304p+8,0x1p+3,0x1.c8584ap+7,0x1.16f304p+8,0x1.ca3654p+7,
  0x1.15df3ap+8,0x1.ca3654p+7,0x1.146f82p+8,0x1p+3,0x1.ca3654p+7,0x1.13122ep+8,0x1.c8584ap+7,
  0x1.11fe62p+8,0x1.c630b4p+7,0x1.11fe62p+8,0x1p+3,0x1.c42de6p+7,0x1.11fe62p+8,0x1.c24fdcp+7,
  0x1.13122ep+8,0x1.c24fdcp+7,0x1.146f82p+8,0x1p+3,0x1.c24fdcp+7,0x1.15df3ap+8,0x1.c42de6p+7,
  0x1.16f304p+8,0x1.c630b4p+7,0x1.16f304p+8,0x1.4p+3,0x1.8p+2,0x1.12c89ep+8,0x1.16f304p+8,
  0x1p+3,0x1.13dc68p+8,0x1.16f304p+8,0x1.14b90ap+8,0x1.15df3ap+8,0x1.14b90ap+8,0x1.146f82p+8,
  0x1p+3,0x1.14b90ap+8,0x1.13122ep+8,0x1.13dc68p+8,0x1.11fe62p+8,0x1.12c89ep+8,0x1.11fe62p+8,
  0x1p+3,0x1.11c738p+8,0x1.11fe62p+8,0x1.10d832p+8,0x1.13122ep+8,0x1.10d832p+8,0x1.146f82p+8,
  0x1p+3,0x1.10d832p+8,0x1.15df3ap+8,0x1.11c738p+8,0x1.16f304p+8,0x1.12c89ep+8,0x1.16f304p+8,
  0x1.4p+3,0x1p+1,0x1p+2,0x1.8p+2,0x1.0cc032p+8,0x1.47dbd8p+8,0x1p+3,0x1.0bac6ap+8,
  0x1.4c86ecp+8,0x1.01c326p+8,0x1.5804aep+8,0x1.01b0c2p+8,0x1.5c2f0ep+8,0x1p+3,0x1.010b4ap+8,
  0x1.5ffd86p+8,0x1.01799cp+8,0x1.628106p+8,0x1.05234ap+8,0x1.62dcf2p+8,0x1p+3,0x1.084c46p+8,
  0x1.63268p+8,0x1.09ce6p+8,0x1.62377cp+8,0x1.090422p+8,0x1.5ed756p+8,0x1p+3,0x1.08836ep+8,
  0x1.5d3076p+8,0x1.08836ep+8,0x1.5be586p+8,0x1.075d42p+8,0x1.5a5106p+8,0x1p+3,0x1.06a564p+8,
  0x1.5873p+8,0x1.069302p+8,0x1.5601ep+8,0x1.0acfc8p+8,0x1.509eecp+8,0x1p+3,0x1.0daf38p+8,
  0x1.4d07a2p+8,0x1.0e8bd8p+8,0x1.44ea02p+8,0x1.0cc032p+8,0x1.47dbd8p+8,0x1.4p+3,
  0x1.8p+2,0x1.d9b9b2p+7,0x1.484a28p+8,0x1p+3,0x1.dbe144p+7,0x1.4cf53ep+8,0x1.efd88ep+7,
  0x1.5873p+8,0x1.effd52p+7,0x1.5c9d6p+8,0x1p+3,0x1.f14846p+7,0x1.606bd4p+8,0x1.f06ba4p+7,
  0x1.62ef56p+8,0x1.e8f382p+7,0x1.634b44p+8,0x1p+3,0x1.e2a18cp+7,0x1.6394dp+8,0x1.df9d56p+7,
  0x1.62a5cep+8,0x1.e131d4p+7,0x1.5f45a8p+8,0x1p+3,0x1.e2333ap+7,0x1.5db12cp+8,0x1.e2333ap+7,
  0x1.5c53d8p+8,0x1.e47f94p+7,0x1.5abf56p+8,0x1p+3,0x1.e5ef4cp+7,0x1.58e14ep+8,0x1.e61412p+7,
  0x1.56702ep+8,0x1.dd9a88p+7,0x1.510d3ep+8,0x1p+3,0x1.d7dba8p+7,0x1.4d75fp+8,0x1.d62262p+7,
  0x1.455854p+8,0x1.d9b9b2p+7,0x1.484a28p+8,0x1.4p+3,0x1p+0,0x1.4p+2,0x1.8p+2,0x1.f4baccp+7,
  0x1.85d6e8p+8,0x1p+3,0x1.ee4412p+7,0x1.8f76ap+8,0x1.f9c1d2p+7,0x1.930deap+8,0x1.f5291ep+7,
  0x1.9b2b8ap+8,0x1.2p+3,0x1.8p+2,0x1.01301p+8,0x1.8632d6p+8,0x1p+3,0x1.046b6ep+8,
  0x1.8fe4f2p+8,0x1.fd7de2p+7,0x1.937c3cp+8,0x1.00f8e6p+8,0x1.9b99d8p+8,0x1.2p+3,
  0x1.8p+2,0x1.fb565p+7,0x1.8dbd5cp+8,0x1p+3,0x1.f79a3cp+7,0x1.934514p+8,0x1.ff126p+7,
  0x1.9928b8p+8,0x1.fb565p+7,0x1.9e5484p+8,0x1.2p+3,0x1p+0,0x1.4p+2,0x1.8p+2,0x1.c02848p+6,
  0x1.2eefeap+8,0x1p+3,0x1.ce3beep+6,0x1.2e00e8p+8,0x1.d9269ap+6,0x1.2bebb6p+8,0x1.da9652p+6,
  0x1.2a699ap+8,0x1.2p+3,0x1.8p+2,0x1.eaf652p+6,0x1.303adep+8,0x1p+3,0x1.f7e3c8p+6,
  0x1.2eb8c2p+8,0x1.02fbb6p+7,0x1.2b7d64p+8,0x1.0446aap+7,0x1.2955cep+8,0x1.2p+3,
  0x1.8p+2,0x1.07b93p+7,0x1.31177cp+8,0x1p+3,0x1.0bbeccp+7,0x1.2fcc8ep+8,0x1.110f5cp+7,
  0x1.2c913p+8,0x1.1210c2p+7,0x1.2a0dacp+8,0x1.2p+3,0x1.8p+2,0x1.161662p+7,0x1.31051cp+8,
  0x1p+3,0x1.1b8bb6p+7,0x1.2f83p+8,0x1.21ddacp+7,0x1.2bd952p+8,0x1.2396f2p+7,0x1.291eaap+8,
  0x1.2p+3,0x1.8p+2,0x1.305fa2p+7,0x1.3003b6p+8,0x1p+3,0x1.31cf5ap+7,0x1.2e4a7p+8,
  0x1.333f14p+7,0x1.2b6bp+8,0x1.323dacp+7,0x1.29b1cp+8,0x1.2p+3,0x1.8p+2,0x1.3ab734p+7,
  0x1.2f14bp+8,0x1p+3,0x1.3cba02p+7,0x1.2d11e2p+8,0x1.3f065ep+7,0x1.296832p+8,0x1.3de032p+7,
  0x1.280adep+8,0x1.2p+3,0x1.8p+2,0x1.48a616p+7,0x1.2db75cp+8,0x1p+3,0x1.4baa4ap+7,
  0x1.2b58ap+8,0x1.4df6a6p+7,0x1.26f714p+8,0x1.4c86ecp+7,0x1.252b6ep+8,0x1.2p+3,
  0x1.8p+2,0x1.54b6ecp+7,0x1.2bb48ep+8,0x1p+3,0x1.57dfe6p+7,0x1.29c42p+8,0x1.592adap+7,
  0x1.25875cp+8,0x1.574cdp+7,0x1.23848ep+8,0x1.2p+3,0x1.8p+2,0x1.63826cp+7,0x1.28b058p+8,
  0x1p+3,0x1.663d18p+7,0x1.267662p+8,0x1.66f4f2p+7,0x1.224bfep+8,0x1.653bb2p+7,0x1.20b782p+8,
  0x1.2p+3,0x1.8p+2,0x1.6c6a4ap+7,0x1.267662p+8,0x1p+3,0x1.6f6e7ep+7,0x1.24cf82p+8,
  0x1.7127cp+7,0x1.216f5cp+8,0x1.7102fcp+7,0x1.1fb61ap+8,0x1.2p+3,0x1.8p+2,0x1.770b6ap+7,
  0x1.235fc8p+8,0x1p+3,0x1.7a0f9ep+7,0x1.22273ap+8,0x1.7ac778p+7,0x1.1f6c8ep+8,0x1.7b35cap+7,
  0x1.1da0e8p+8,0x1.2p+3,0x1.8p+2,0x1.858d5cp+7,0x1.1db348p+8,0x1p+3,0x1.889194p+7,
  0x1.1c55f4p+8,0x1.882344p+7,0x1.19f73ap+8,0x1.8924aap+7,0x1.17861ap+8,0x1.2p+3,
  0x1.8p+2,0x1.862072p+8,0x1.2c6c68p+8,0x1p+3,0x1.828924p+8,0x1.2b8fc8p+8,0x1.7fe0dep+8,
  0x1.297a96p+8,0x1.7f728ep+8,0x1.27e616p+8,0x1.2p+3,0x1.8p+2,0x1.7c931ep+8,0x1.2d5b6ep+8,
  0x1p+3,0x1.796a22p+8,0x1.2bc6eep+8,0x1.75e538p+8,0x1.289df4p+8,0x1.752d5cp+8,0x1.267662p+8,
  0x1.2p+3,0x1.8p+2,0x1.7361b6p+8,0x1.2ddc2p+8,0x1p+3,0x1.714c84p+8,0x1.2ca39p+8,
  0x1.6eb6ap+8,0x1.296832p+8,0x1.6e35eep+8,0x1.26e4bp+8,0x1.2p+3,0x1.8p+2,0x1.6c57e4p+8,
  0x1.2ddc2p+8,0x1p+3,0x1.699d3ap+8,0x1.2c5a08p+8,0x1.6661dap+8,0x1.28b058p+8,0x1.65979cp+8,
  0x1.25f5acp+8,0x1.2p+3,0x1.8p+2,0x1.6212b4p+8,0x1.2d8032p+8,0x1p+3,0x1.615ad8p+8,
  0x1.2bc6eep+8,0x1.60a2fcp+8,0x1.28e78p+8,0x1.6123bp+8,0x1.272e3cp+8,0x1.2p+3,0x1.8p+2,
  0x1.5a9a9p+8,0x1.2cff7cp+8,0x1p+3,0x1.59992ap+8,0x1.2afcbp+8,0x1.58609ap+8,0x1.2753p+8,
  0x1.58f3bp+8,0x1.25f5acp+8,0x1.2p+3,0x1.8p+2,0x1.53a32p+8,0x1.2ba228p+8,0x1p+3,
  0x1.522106p+8,0x1.29436ep+8,0x1.50e876p+8,0x1.24e1e2p+8,0x1.51a052p+8,0x1.23163cp+8,
  0x1.2p+3,0x1.8p+2,0x1.4d9ab4p+8,0x1.2b0f14p+8,0x1p+3,0x1.4c0638p+8,0x1.290c46p+8,
  0x1.4b60bep+8,0x1.24cf82p+8,0x1.4c4fc2p+8,0x1.22df14p+8,0x1.2p+3,0x1.8p+2,0x1.46b5a8p+8,
  0x1.28b058p+8,0x1p+3,0x1.455852p+8,0x1.267662p+8,0x1.44fc64p+8,0x1.224bfep+8,0x1.45d906p+8,
  0x1.20a51cp+8,0x1.2p+3,0x1.8p+2,0x1.412dfp+8,0x1.272e3cp+8,0x1p+3,0x1.3fabd6p+8,
  0x1.2574f6p+8,0x1.3ecf32p+8,0x1.22273ap+8,0x1.3ecf32p+8,0x1.206df4p+8,0x1.2p+3,
  0x1.8p+2,0x1.3b93d6p+8,0x1.24739p+8,0x1p+3,0x1.3a11bcp+8,0x1.234d64p+8,0x1.39b5ccp+8,
  0x1.208058p+8,0x1.397ea4p+8,0x1.1eb4b4p+8,0x1.2p+3,0x1.8p+2,0x1.367a6ep+8,0x1.21010ap+8,
  0x1p+3,0x1.34f854p+8,0x1.1fa3b6p+8,0x1.3541ep+8,0x1.1d44fap+8,0x1.34aecap+8,0x1.1ad3dcp+8,
  0x1.2p+3,0x1p+1,0x1p+2,0x1.8p+2,0x1.5de854p+5,0x1.284208p+8,0x1p+3,0x1.63141ap+5,
  0x1.281d3ep+8,0x1.683fe6p+5,0x1.27f87ap+8,0x1.6dfec6p+5,0x1.27c152p+8,0x1p+3,0x1.ba696ap+5,
  0x1.27e616p+8,0x1.bd48dap+5,0x1.307206p+8,0x1.b663cep+5,0x1.3b1326p+8,0x1p+3,0x1.b13804p+5,
  0x1.46b5a8p+8,0x1.a6e07p+5,0x1.549228p+8,0x1.bddbfp+5,0x1.5a5106p+8,0x1p+3,0x1.d0d1d4p+5,
  0x1.5e444p+8,0x1.d97024p+5,0x1.62936ap+8,0x1.da9654p+5,0x1.672c1ap+8,0x1.cp+2,
  0x1.da9654p+5,0x1.6a0b8cp+8,0x1p+3,0x1.d8dd0ep+5,0x1.6fdcdp+8,0x1.cccc38p+5,0x1.761c62p+8,
  0x1.bc22aep+5,0x1.7c931ep+8,0x1p+3,0x1.a92cccp+5,0x1.70b972p+8,0x1.785658p+5,0x1.67acdp+8,
  0x1.5de854p+5,0x1.615adap+8,0x1.cp+2,0x1.5de854p+5,0x1.4748c2p+8,0x1p+3,0x1.6034aap+5,
  0x1.45a1ep+8,0x1.61edfp+5,0x1.440d64p+8,0x1.63a73p+5,0x1.429dacp+8,0x1p+3,0x1.70de38p+5,
  0x1.3d2854p+8,0x1.6c4582p+5,0x1.3b37eap+8,0x1.5de854p+5,0x1.3aa4d4p+8,0x1.cp+2,
  0x1.5de854p+5,0x1.3744aep+8,0x1p+3,0x1.6b1f56p+5,0x1.375714p+8,0x1.74e3d2p+5,0x1.37c564p+8,
  0x1.78e96ep+5,0x1.38b468p+8,0x1p+3,0x1.84fa46p+5,0x1.3c5e16p+8,0x1.7b35cap+5,0x1.46da7p+8,
  0x1.6bb26cp+5,0x1.4fafe6p+8,0x1p+3,0x1.5cc224p+5,0x1.58856p+8,0x1.6dfec6p+5,0x1.5ee9bap+8,
  0x1.8b4c3cp+5,0x1.650488p+8,0x1p+3,0x1.9636e8p+5,0x1.66f4f2p+8,0x1.9e422p+5,0x1.6a3054p+8,
  0x1.a899b6p+5,0x1.6c3322p+8,0x1p+3,0x1.ca7fdcp+5,0x1.7450bep+8,0x1.cd5f4ep+5,0x1.6ca172p+8,
  0x1.b8b028p+5,0x1.63b994p+8,0x1p+3,0x1.991658p+5,0x1.58609cp+8,0x1.919e32p+5,0x1.51a054p+8,
  0x1.935778p+5,0x1.4c9952p+8,0x1p+3,0x1.8ebec2p+5,0x1.4545f4p+8,0x1.cd5f4ep+5,0x1.29310ap+8,
  0x1.5de854p+5,0x1.2ac586p+8,0x1.cp+2,0x1.5de854p+5,0x1.284208p+8,0x1.4p+3,0x1.8p+2,
  0x1.d5fdap+4,0x1.281d3ep+8,0x1p+3,0x1.e3c7b8p+4,0x1.253dd2p+8,0x1.17cfa4p+5,0x1.2a0dacp+8,
  0x1.5de854p+5,0x1.284208p+8,0x1.cp+2,0x1.5de854p+5,0x1.2ac586p+8,0x1p+3,0x1.5c2f0ep+5,
  0x1.2ac586p+8,0x1.5a75cep+5,0x1.2ad7eap+8,0x1.58bc88p+5,0x1.2ad7eap+8,0x1p+3,0x1.388fa2p+5,
  0x1.2d8032p+8,0x1.0bbeccp+5,0x1.2a327p+8,0x1.00d424p+5,0x1.2b7d64p+8,0x1p+3,0x1.d4d776p+4,
  0x1.2e25acp+8,0x1.f5045ap+4,0x1.36e8c2p+8,0x1.0ce4fcp+5,0x1.375714p+8,0x1p+3,0x1.24739p+5,
  0x1.37a09cp+8,0x1.45c6a6p+5,0x1.370d86p+8,0x1.5de854p+5,0x1.3744aep+8,0x1.cp+2,
  0x1.5de854p+5,0x1.3aa4d4p+8,0x1p+3,0x1.554a02p+5,0x1.3a5b48p+8,0x1.49392cp+5,0x1.3a800cp+8,
  0x1.3b6f14p+5,0x1.3ab734p+8,0x1p+3,0x1.262cd6p+5,0x1.3ac99ap+8,0x1.1d8e84p+5,0x1.3ab734p+8,
  0x1.084c46p+5,0x1.3ac99ap+8,0x1p+3,0x1.d723ccp+4,0x1.3a927p+8,0x1.b6f6e6p+4,0x1.3307eap+8,
  0x1.c4c0fep+4,0x1.301616p+8,0x1p+3,0x1.c4c0fep+4,0x1.2b33d8p+8,0x1.bcb5c6p+4,0x1.2cff7cp+8,
  0x1.d5fdap+4,0x1.281d3ep+8,0x1.cp+2,0x1.d5fdap+4,0x1.281d3ep+8,0x1.4p+3,0x1.8p+2,
  0x1.5de854p+5,0x1.615adap+8,0x1p+3,0x1.52fda8p+5,0x1.5ed756p+8,0x1.4c189cp+5,0x1.5cd488p+8,
  0x1.4af27p+5,0x1.5b2da8p+8,0x1p+3,0x1.437a4ap+5,0x1.5897c4p+8,0x1.526a92p+5,0x1.4f2f34p+8,
  0x1.5de854p+5,0x1.4748c2p+8,0x1.cp+2,0x1.5de854p+5,0x1.615adap+8,0x1.4p+3,0x1.8p+2,
  0x1.ffca3ap+7,0x1.cc950ep+8,0x1p+3,0x1.00410cp+8,0x1.cc82aep+8,0x1.009cfap+8,0x1.cc704ap+8,
  0x1.010b4ap+8,0x1.cc5de6p+8,0x1p+3,0x1.07946ap+8,0x1.cb93a8p+8,0x1.0daf38p+8,0x1.c92288p+8,
  0x1.1595aap+8,0x1.cc3922p+8,0x1p+3,0x1.18bea6p+8,0x1.ce3bfp+8,0x1.1a2e5ep+8,0x1.d0f69cp+8,
  0x1.1a5324p+8,0x1.d4445ep+8,0x1.cp+2,0x1.1a5324p+8,0x1.d56a88p+8,0x1p+3,0x1.1a1bfcp+8,
  0x1.da9654p+8,0x1.1717c6p+8,0x1.e0faaap+8,0x1.12a3d8p+8,0x1.e816e4p+8,0x1p+3,0x1.09a99ap+8,
  0x1.f6ab3ap+8,0x1.07cb92p+8,0x1.f63ce8p+8,0x1.0928e6p+8,0x1.ef20b4p+8,0x1p+3,0x1.10c5dp+8,
  0x1.dc61fap+8,0x1.0d8a72p+8,0x1.d77fbap+8,0x1.037c6ap+8,0x1.dbbc8p+8,0x1p+3,0x1.02689ep+8,
  0x1.dc186cp+8,0x1.01301p+8,0x1.dc61fap+8,0x1.ffca3ap+7,0x1.dc9922p+8,0x1.cp+2,
  0x1.ffca3ap+7,0x1.d88122p+8,0x1p+3,0x1.037c6ap+8,0x1.d7ee0cp+8,0x1.06ca2ap+8,0x1.d74892p+8,
  0x1.0a863cp+8,0x1.d6b57cp+8,0x1p+3,0x1.15275cp+8,0x1.d431fap+8,0x1.0d2e84p+8,0x1.e8cebep+8,
  0x1.0f3152p+8,0x1.e83ba8p+8,0x1p+3,0x1.144ab8p+8,0x1.de2d9ep+8,0x1.1b548cp+8,0x1.d278b4p+8,
  0x1.10d832p+8,0x1.cebca6p+8,0x1p+3,0x1.0a0588p+8,0x1.ce172cp+8,0x1.04590ap+8,0x1.cecf06p+8,
  0x1.ffca3ap+7,0x1.cf86e4p+8,0x1.cp+2,0x1.ffca3ap+7,0x1.cc950ep+8,0x1.4p+3,0x1.8p+2,
  0x1.d849fap+7,0x1.c129b2p+8,0x1p+3,0x1.f0d9f4p+7,0x1.c185a2p+8,0x1.d8b84ap+7,0x1.d0884ap+8,
  0x1.ffca3ap+7,0x1.cc950ep+8,0x1.cp+2,0x1.ffca3ap+7,0x1.cf86e4p+8,0x1p+3,0x1.f64f4cp+7,
  0x1.d05122p+8,0x1.ef4578p+7,0x1.d11b6p+8,0x1.ead18cp+7,0x1.d09aaep+8,0x1p+3,0x1.e5a5cp+7,
  0x1.cf3d56p+8,0x1.e334ap+7,0x1.ce4e54p+8,0x1.e131d4p+7,0x1.c86aaep+8,0x1p+3,0x1.de7728p+7,
  0x1.c4f828p+8,0x1.da27fep+7,0x1.c3760cp+8,0x1.d5fd9ep+7,0x1.c3760cp+8,0x1p+3,0x1.cd3a88p+7,
  0x1.c51ceep+8,0x1.d9de76p+7,0x1.c82122p+8,0x1.d849fap+7,0x1.cd036p+8,0x1p+3,0x1.d6472cp+7,
  0x1.d2afdcp+8,0x1.d41f94p+7,0x1.d86ebep+8,0x1.dce2aap+7,0x1.da033ep+8,0x1p+3,0x1.ebf7b6p+7,
  0x1.d9de76p+8,0x1.f67412p+7,0x1.d94b6p+8,0x1.ffca3ap+7,0x1.d88122p+8,0x1.cp+2,
  0x1.ffca3ap+7,0x1.dc9922p+8,0x1p+3,0x1.f82d52p+7,0x1.dd636p+8,0x1.efd88ep+7,0x1.ddd1b2p+8,
  0x1.e73a3cp+7,0x1.de2d9ep+8,0x1p+3,0x1.d7921cp+7,0x1.def7dcp+8,0x1.d520fcp+7,0x1.dc61fap+8,
  0x1.d1f802p+7,0x1.d9269cp+8,0x1p+3,0x1.cdf262p+7,0x1.d50e9cp+8,0x1.d62262p+7,0x1.cfaba8p+8,
  0x1.d189b2p+7,0x1.cb93a8p+8,0x1p+3,0x1.cef3cap+7,0x1.c934eep+8,0x1.cd3a88p+7,0x1.c70d56p+8,
  0x1.ccf0fcp+7,0x1.c55416p+8,0x1.cp+2,0x1.ccf0fcp+7,0x1.c452aep+8,0x1p+3,0x1.cd5f4ep+7,
  0x1.c23d7cp+8,0x1.d0ad0ep+7,0x1.c104eep+8,0x1.d849fap+7,0x1.c129b2p+8,0x1.4p+3,
  0x1.8p+2,0x1.7e8388p+8,0x1.e5810ap+5,0x1p+3,0x1.81bee6p+8,0x1.e4ede8p+5,0x1.84672ep+8,
  0x1.e5810ap+5,0x1.876b64p+8,0x1.eaacc8p+5,0x1p+3,0x1.884806p+8,0x1.f0febcp+5,0x1.88a3f4p+8,
  0x1.f90a02p+5,0x1.88c8b8p+8,0x1.01674p+6,0x1.cp+2,0x1.88c8b8p+8,0x1.07262p+6,0x1p+3,
  0x1.88919p+8,0x1.14f038p+6,0x1.86d84ep+8,0x1.299f5ep+6,0x1.84fa46p+8,0x1.493932p+6,
  0x1p+3,0x1.7fce7ap+8,0x1.6bfbf6p+6,0x1.7f3b66p+8,0x1.5c2f1p+6,0x1.7e8388p+8,0x1.46ecd2p+6,
  0x1.cp+2,0x1.7e8388p+8,0x1.1f9158p+6,0x1p+3,0x1.7f169ep+8,0x1.2303dap+6,0x1.7f4dc8p+8,
  0x1.28c2bap+6,0x1.8073f4p+8,0x1.3a9276p+6,0x1p+3,0x1.808656p+8,0x1.53da5p+6,0x1.8276c2p+8,
  0x1.4b3cp+6,0x1.8365c8p+8,0x1.3922bap+6,0x1p+3,0x1.839cfp+8,0x1.206dfap+6,0x1.891244p+8,
  0x1.0ce502p+6,0x1.858d5cp+8,0x1.01674p+6,0x1p+3,0x1.850ca8p+8,0x1.fda2bp+5,0x1.82646p+8,
  0x1.f6bd9cp+5,0x1.7e8388p+8,0x1.f7e3dp+5,0x1.cp+2,0x1.7e8388p+8,0x1.e5810ap+5,
  0x1.4p+3,0x1.8p+2,0x1.7665ecp+8,0x1.c14e8p+5,0x1p+3,0x1.77fa6ap+8,0x1.b94348p+5,
  0x1.7868bcp+8,0x1.e0553ap+5,0x1.7c80bcp+8,0x1.e6141cp+5,0x1p+3,0x1.7d3898p+8,0x1.e6141cp+5,
  0x1.7dde1p+8,0x1.e6141cp+5,0x1.7e8388p+8,0x1.e5810ap+5,0x1.cp+2,0x1.7e8388p+8,
  0x1.f7e3dp+5,0x1p+3,0x1.7e279ap+8,0x1.f7e3dp+5,0x1.7dcbacp+8,0x1.f876e2p+5,0x1.7d6fbep+8,
  0x1.f876e2p+5,0x1p+3,0x1.79c61p+8,0x1.fac348p+5,0x1.76785p+8,0x1.d28b22p+5,0x1.76785p+8,
  0x1.dce2bp+5,0x1p+3,0x1.75f79cp+8,0x1.f06baap+5,0x1.768ab2p+8,0x1.0446bp+6,0x1.77c342p+8,
  0x1.117daep+6,0x1p+3,0x1.783192p+8,0x1.193f5ep+6,0x1.7aec3cp+8,0x1.1af8a2p+6,0x1.7dcbacp+8,
  0x1.1cb1e8p+6,0x1p+3,0x1.7e1538p+8,0x1.1d8e8ap+6,0x1.7e4c6p+8,0x1.1e6b2cp+6,0x1.7e8388p+8,
  0x1.1f9158p+6,0x1.cp+2,0x1.7e8388p+8,0x1.46ecd2p+6,0x1p+3,0x1.7dde1p+8,0x1.33ad62p+6,
  0x1.7d13dp+8,0x1.1b8bbcp+6,0x1.788d8p+8,0x1.20b784p+6,0x1p+3,0x1.75e538p+8,0x1.21010cp+6,
  0x1.7487e4p+8,0x1.0ee7dp+6,0x1.74631ep+8,0x1.fbe96cp+5,0x1.cp+2,0x1.74631ep+8,
  0x1.ed8c42p+5,0x1p+3,0x1.74758p+8,0x1.d690bep+5,0x1.752d5cp+8,0x1.c307c6p+5,0x1.7665ecp+8,
  0x1.c14e8p+5,0x1.4p+3,0x1.8p+2,0x1.d4e9d4p+8,0x1.2688c2p+8,0x1p+3,0x1.d8b848p+8,
  0x1.267662p+8,0x1.dc61f6p+8,0x1.269b26p+8,0x1.dfc21ap+8,0x1.2753p+8,0x1p+3,0x1.e0b11ep+8,
  0x1.282fa2p+8,0x1.e11f6ep+8,0x1.29c42p+8,0x1.e131d4p+8,0x1.2bd952p+8,0x1.cp+2,
  0x1.e131d4p+8,0x1.2e4a7p+8,0x1p+3,0x1.e0e846p+8,0x1.34653ep+8,0x1.dec0b4p+8,0x1.3d96a6p+8,
  0x1.dc745ap+8,0x1.4723fap+8,0x1p+3,0x1.dbe144p+8,0x1.4a71bap+8,0x1.db4e2ep+8,0x1.4dbf7cp+8,
  0x1.daa8b4p+8,0x1.510d3ep+8,0x1p+3,0x1.d849f8p+8,0x1.5b8994p+8,0x1.d7489p+8,0x1.56de8p+8,
  0x1.d67e5p+8,0x1.501e38p+8,0x1p+3,0x1.d6da3ep+8,0x1.4690e4p+8,0x1.d812cep+8,0x1.3ca7a2p+8,
  0x1.d4e9d4p+8,0x1.378e3cp+8,0x1.cp+2,0x1.d4e9d4p+8,0x1.333f14p+8,0x1p+3,0x1.d520fcp+8,
  0x1.333f14p+8,0x1.d55824p+8,0x1.335178p+8,0x1.d58f4ep+8,0x1.335178p+8,0x1p+3,0x1.d6eca2p+8,
  0x1.34653ep+8,0x1.d86ebcp+8,0x1.39da92p+8,0x1.d94b6p+8,0x1.414054p+8,0x1p+3,0x1.d9cc12p+8,
  0x1.48efa2p+8,0x1.da965p+8,0x1.4748c2p+8,0x1.db8556p+8,0x1.41651cp+8,0x1p+3,0x1.dbceep+8,
  0x1.3a11bcp+8,0x1.e10d0ep+8,0x1.2ea65ep+8,0x1.dcf50ep+8,0x1.2b33d8p+8,0x1p+3,0x1.dc4f94p+8,
  0x1.2a7bfep+8,0x1.d994e8p+8,0x1.291eaap+8,0x1.d4e9d4p+8,0x1.2955cep+8,0x1.cp+2,
  0x1.d4e9d4p+8,0x1.2688c2p+8,0x1.4p+3,0x1.8p+2,0x1.cba60ap+8,0x1.213832p+8,0x1p+3,
  0x1.cd8412p+8,0x1.1fffa2p+8,0x1.ccde9ap+8,0x1.25d0e8p+8,0x1.d1ae76p+8,0x1.26ad86p+8,
  0x1p+3,0x1.d2c23ep+8,0x1.269b26p+8,0x1.d3d60ap+8,0x1.269b26p+8,0x1.d4e9d4p+8,0x1.2688c2p+8,
  0x1.cp+2,0x1.d4e9d4p+8,0x1.2955cep+8,0x1p+3,0x1.d4a048p+8,0x1.2955cep+8,0x1.d4445ap+8,
  0x1.2955cep+8,0x1.d3e86cp+8,0x1.2955cep+8,0x1p+3,0x1.cf9944p+8,0x1.29b1cp+8,0x1.cb93a8p+8,
  0x1.255032p+8,0x1.cb93a8p+8,0x1.26d24ep+8,0x1p+3,0x1.caee2ep+8,0x1.29b1cp+8,0x1.cbcacep+8,
  0x1.2bb48ep+8,0x1.cd3a86p+8,0x1.2fa7c4p+8,0x1p+3,0x1.cdbb3ap+8,0x1.31cf5ap+8,0x1.d19c12p+8,
  0x1.32abfep+8,0x1.d4e9d4p+8,0x1.333f14p+8,0x1.cp+2,0x1.d4e9d4p+8,0x1.378e3cp+8,
  0x1p+3,0x1.d39ee2p+8,0x1.3566a6p+8,0x1.d1774ep+8,0x1.341bb6p+8,0x1.ce298cp+8,0x1.341bb6p+8,
  0x1p+3,0x1.cb009p+8,0x1.341bb6p+8,0x1.c96c14p+8,0x1.2edd86p+8,0x1.c934ecp+8,0x1.29e8e8p+8,
  0x1.cp+2,0x1.c934ecp+8,0x1.27aef2p+8,0x1p+3,0x1.c959bp+8,0x1.244eccp+8,0x1.ca3652p+8,
  0x1.2181cp+8,0x1.cba60ap+8,0x1.213832p+8,0x1.4p+3,0x1.8p+2,0x1.cccc36p+6,0x1.1f47c6p+6,
  0x1p+3,0x1.e816e2p+6,0x1.1a1cp+6,0x1.021f18p+7,0x1.13807cp+6,0x1.0c51e6p+7,0x1.173c9p+6,
  0x1p+3,0x1.13122ap+7,0x1.1a1cp+6,0x1.1539cp+7,0x1.311782p+6,0x1.15834cp+7,0x1.554a04p+6,
  0x1.cp+2,0x1.15834cp+7,0x1.61edf2p+6,0x1p+3,0x1.15834cp+7,0x1.691c8ep+6,0x1.155e84p+7,
  0x1.70de3ep+6,0x1.1539cp+7,0x1.78e974p+6,0x1p+3,0x1.13a542p+7,0x1.a08e8p+6,0x1.0f561ap+7,
  0x1.a16b22p+6,0x1.097276p+7,0x1.74e3d8p+6,0x1p+3,0x1.06b7cap+7,0x1.5067c6p+6,0x1.01b0c6p+7,
  0x1.3ee19cp+6,0x1.cccc36p+6,0x1.4a5f5cp+6,0x1.cp+2,0x1.cccc36p+6,0x1.3c9544p+6,
  0x1p+3,0x1.dadfdap+6,0x1.3a48e6p+6,0x1.ea19bp+6,0x1.38d932p+6,0x1.fb564ep+6,0x1.39b5d4p+6,
  0x1p+3,0x1.07946cp+7,0x1.3d2856p+6,0x1.038edp+7,0x1.457d1ep+6,0x1.100df4p+7,0x1.6b68e6p+6,
  0x1p+3,0x1.145d1cp+7,0x1.70de3ep+6,0x1.11c73ap+7,0x1.323daep+6,0x1.0a2a5p+7,0x1.267664p+6,
  0x1p+3,0x1.09e0c6p+7,0x1.1fdaep+6,0x1.e816e2p+6,0x1.267664p+6,0x1.cccc36p+6,0x1.29e8e6p+6,
  0x1.cp+2,0x1.cccc36p+6,0x1.1f47c6p+6,0x1.4p+3,0x1.8p+2,0x1.7450bcp+6,0x1.0fc46ap+6,
  0x1p+3,0x1.80ab1cp+6,0x1.0c9b7p+6,0x1.af7ecp+6,0x1.23e07cp+6,0x1.c9ecc6p+6,0x1.1fdaep+6,
  0x1p+3,0x1.cb12f4p+6,0x1.1f9158p+6,0x1.cbef98p+6,0x1.1f9158p+6,0x1.cccc36p+6,0x1.1f47c6p+6,
  0x1.cp+2,0x1.cccc36p+6,0x1.29e8e6p+6,0x1p+3,0x1.c9ecc6p+6,0x1.2a3276p+6,0x1.c6c3ccp+6,
  0x1.2a7cp+6,0x1.c42de8p+6,0x1.2ac588p+6,0x1p+3,0x1.ace8dcp+6,0x1.2ba22ap+6,0x1.94c72ep+6,
  0x1.299f5ep+6,0x1.7c5bf6p+6,0x1.21010cp+6,0x1p+3,0x1.74072ep+6,0x1.1e219cp+6,0x1.7450bcp+6,
  0x1.23e07cp+6,0x1.789fe4p+6,0x1.2dee8ap+6,0x1p+3,0x1.7ea84ep+6,0x1.3a48e6p+6,0x1.81d14ap+6,
  0x1.41c10cp+6,0x1.8b95c8p+6,0x1.5423dap+6,0x1p+3,0x1.9154a8p+6,0x1.62810cp+6,0x1.8b02b2p+6,
  0x1.882342p+6,0x1.7fce7cp+6,0x1.9d1bf6p+6,0x1p+3,0x1.6edb68p+6,0x1.b3846p+6,0x1.93ea8cp+6,
  0x1.b2a7bep+6,0x1.96807p+6,0x1.9f1ec4p+6,0x1p+3,0x1.99f2fap+6,0x1.8543d8p+6,0x1.9a860ep+6,
  0x1.71bad8p+6,0x1.991656p+6,0x1.5feb24p+6,0x1p+3,0x1.9d1bf2p+6,0x1.4eae82p+6,0x1.a570b6p+6,
  0x1.4a5f5cp+6,0x1.b25e3p+6,0x1.425426p+6,0x1p+3,0x1.bafc82p+6,0x1.4007c6p+6,0x1.c3e45cp+6,
  0x1.3e04f8p+6,0x1.cccc36p+6,0x1.3c9544p+6,0x1.cp+2,0x1.cccc36p+6,0x1.4a5f5cp+6,
  0x1p+3,0x1.c8c69ap+6,0x1.4b3cp+6,0x1.c42de8p+6,0x1.4c622ap+6,0x1.bf9532p+6,0x1.4d8856p+6,
  0x1p+3,0x1.8d058p+6,0x1.4b8588p+6,0x1.abc2aep+6,0x1.a16b22p+6,0x1.a1b4a8p+6,0x1.a5272ep+6,
  0x1p+3,0x1.8e7538p+6,0x1.b8b02ep+6,0x1.7e1538p+6,0x1.bd48dcp+6,0x1.704b2p+6,0x1.b2a7bep+6,
  0x1p+3,0x1.6a42b2p+6,0x1.a9bfe4p+6,0x1.6686a2p+6,0x1.a16b22p+6,0x1.76538ap+6,0x1.94341cp+6,
  0x1p+3,0x1.886ccap+6,0x1.7a0fap+6,0x1.7fce7cp+6,0x1.7c126ep+6,0x1.83d418p+6,0x1.5fa19ap+6,
  0x1p+3,0x1.88b656p+6,0x1.46103p+6,0x1.574ccep+6,0x1.287932p+6,0x1.7450bcp+6,0x1.0fc46ap+6,
  0x1.4p+3,]
;

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
  //static assert(Command.StrokeMode == 1);
  //static assert(Command.FillMode == 2);

  template hasChar(char ch, string s) {
         static if (s.length == 0) enum hasChar = false;
    else static if (s[0] == ch) enum hasChar = true;
    else enum hasChar = hasChar!(ch, s[1..$]);
  }
  enum AllowStroke = hasChar!('s', mode);
  enum AllowFill = hasChar!('f', mode);
  enum AllowWidth = hasChar!('w', mode);
  enum Contour = hasChar!('c', mode);
  //static assert(AllowWidth || AllowFill);
  if (nvg is null || path.length == 0) return;
  float firstx = 0, firsty = 0;
  usize pos = 0;
  int mode = 0;
  int sw = Command.NormalStroke;
  bool firstPoint = true;
  nvg.beginPath();
  while (pos < path.length) {
    switch (cast(Command)path.ptr[pos++]) {
      case Command.Bounds: pos += 4; break;
      case Command.StrokeMode: mode = Command.StrokeMode; break;
      case Command.FillMode: mode = Command.FillMode; break;
      case Command.StrokeFillMode: mode = Command.StrokeFillMode; break;
      case Command.NormalStroke: sw = Command.NormalStroke; break;
      case Command.ThinStroke: sw = Command.ThinStroke; break;
      case Command.MoveTo:
        if (path.length-pos < 2) assert(0, "invalid path command");
        if (firstPoint) { firstx = path.ptr[pos]; firsty = path.ptr[pos+1]; firstPoint = false; }
        nvg.moveTo(ofsx+path.ptr[pos]*scalex, ofsy+path.ptr[pos+1]*scaley);
        pos += 2;
        continue;
      case Command.LineTo:
        if (path.length-pos < 2) assert(0, "invalid path command");
        if (firstPoint) assert(0, "invalid path command");
        nvg.lineTo(ofsx+path.ptr[pos]*scalex, ofsy+path.ptr[pos+1]*scaley);
        pos += 2;
        continue;
      case Command.CubicTo: // cubic bezier
        if (path.length-pos < 6) assert(0, "invalid path command");
        if (firstPoint) assert(0, "invalid path command");
        nvg.bezierTo(
          ofsx+path.ptr[pos+0]*scalex, ofsy+path.ptr[pos+1]*scaley,
          ofsx+path.ptr[pos+2]*scalex, ofsy+path.ptr[pos+3]*scaley,
          ofsx+path.ptr[pos+4]*scalex, ofsy+path.ptr[pos+5]*scaley);
        pos += 6;
        continue;
      case Command.ClosePath: // close this path, start new path
        if (!firstPoint) nvg.lineTo(ofsx+firstx*scalex, ofsy+firsty*scaley);
        goto case Command.EndPath;
      case Command.EndPath: // don't close this path
        firstPoint = true;
        if (mode == Command.FillMode || mode == Command.StrokeFillMode) {
          static if (AllowFill || Contour) {
            static if (Contour) {
              if (mode == Command.FillMode) { nvg.strokeWidth = 1; nvg.stroke(); }
            } else {
              nvg.fill();
            }
          }
        }
        if (mode == Command.StrokeMode || mode == Command.StrokeFillMode) {
          static if (AllowStroke || Contour) {
            static if (AllowWidth) {
                   if (sw == Command.NormalStroke) nvg.strokeWidth = 1;
              else if (sw == Command.ThinStroke) nvg.strokeWidth = 0.5;
              else assert(0, "wtf?!");
            }
            nvg.stroke();
          }
        }
        nvg.newPath();
        break;
      default: assert(0, "invalid path command");
    }
  }
}
