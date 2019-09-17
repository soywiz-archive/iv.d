/* coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * Understanding is not required. Only obedience.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 3 of the License ONLY.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */
module iv.color;


// color in sRGB space
struct RGB8 {
public:
  string toString () const nothrow @trusted {
    import core.stdc.stdio : snprintf;
    char[256] buf = void;
    auto len = snprintf(buf.ptr, buf.length, "RGB8(%u,%u,%u)", cast(uint)r, cast(uint)g, cast(uint)b);
    return buf[0..len].idup;
  }

public pure nothrow @safe @nogc:
  ubyte r=0, g=0, b=0;

  this (int ar, int ag, int ab) pure nothrow @safe @nogc { pragma(inline, true); r = clampToByte(ar); g = clampToByte(ag); b = clampToByte(ab); }
  this() (in auto ref RGB8 c) pure nothrow @safe @nogc { pragma(inline, true); r = c.r; g = c.g; b = c.b; }
  this() (in auto ref SRGB c) pure nothrow @safe @nogc { pragma(inline, true); r = clampToByte(cast(int)(c.r*255.0)); g = clampToByte(cast(int)(c.g*255.0)); b = clampToByte(cast(int)(c.b*255.0)); }
  this() (in auto ref CLAB c) pure nothrow @safe @nogc { pragma(inline, true); this = cast(RGB8)cast(CXYZD65)c; }
  this(C) (in auto ref C c) pure nothrow @safe @nogc if (is(C : CXYZImpl!M, string M) || is(C == CHSL)) { pragma(inline, true); this = cast(RGB8)c; }

  ref auto opAssign() (in auto ref RGB8 c) { pragma(inline, true); r = c.r; g = c.g; b = c.b; return this; }
  ref auto opAssign() (in auto ref SRGB c) { pragma(inline, true); this = cast(RGB8)c; return this; }
  ref auto opAssign() (in auto ref CLAB c) { pragma(inline, true); this = cast(RGB8)cast(CXYZD65)c; return this; }
  ref auto opAssign(C) (in auto ref C c) if (is(C : CXYZImpl!M, string M) || is(C == CHSL)) { pragma(inline, true); this = cast(RGB8)c; return this; }

  SRGB opCast(T:RGB8) () const nothrow @safe @nogc { pragma(inline, true); return RGB8(r, g, b); }
  SRGB opCast(T:SRGB) () const nothrow @safe @nogc { pragma(inline, true); return SRGB(this); }
  CLAB opCast(T:CLAB) () const nothrow @safe @nogc { pragma(inline, true); return CLAB(CXYZD65(this)); }
  C opCast(C) () const nothrow @safe @nogc if (is(C : CXYZImpl!M, string M) || is(C == CHSL)) { pragma(inline, true); return C(this); }

  // CIE76
  float distance(C) (in auto ref C c) const if (is(C : CXYZImpl!M, string M) || is(C == SRGB) || is(C == RGB8) || is(C == CLAB) || is(C == CHSL)) { pragma(inline, true); return (cast(CLAB)this).distance(c); }
  float distanceSquared(C) (in auto ref C c) const if (is(C : CXYZImpl!M, string M) || is(C == SRGB) || is(C == RGB8) || is(C == CLAB) || is(C == CHSL)) { pragma(inline, true); return (cast(CLAB)this).distanceSquared(c); }

static:
  // this is actually branch-less for ints on x86, and even for longs on x86_64
  static ubyte clampToByte(T) (T n) pure nothrow @safe @nogc if (__traits(isIntegral, T)) {
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
}


// color in sRGB space
struct SRGB {
public:
  string toString () const nothrow @trusted {
    import core.stdc.stdio : snprintf;
    char[256] buf = void;
    auto len = snprintf(buf.ptr, buf.length, "SRGB(%g,%g,%g)", cast(double)r, cast(double)g, cast(double)b);
    return buf[0..len].idup;
  }

public pure nothrow @safe @nogc:
  float r=0, g=0, b=0; // [0..1]

  this (in float ar, in float ag, in float ab) pure nothrow @safe @nogc { pragma(inline, true); r = ar; g = ag; b = ab; }
  this() (in auto ref RGB8 c) pure nothrow @safe @nogc { pragma(inline, true); r = c.r/255.0; g = c.g/255.0; b = c.b/255.0; }
  this() (in auto ref SRGB c) pure nothrow @safe @nogc { pragma(inline, true); r = c.r; g = c.g; b = c.b; }
  this() (in auto ref CLAB c) pure nothrow @safe @nogc { pragma(inline, true); this = cast(SRGB)cast(CXYZD65)c; }
  this(C) (in auto ref C c) pure nothrow @safe @nogc if (is(C : CXYZImpl!M, string M) || is(C == CHSL)) { pragma(inline, true); this = cast(SRGB)c; }

  ref auto opAssign() (in auto ref RGB8 c) { pragma(inline, true); r = c.r/255.0; g = c.g/255.0; b = c.b/255.0; return this; }
  ref auto opAssign() (in auto ref SRGB c) { pragma(inline, true); r = c.r; g = c.g; b = c.b; return this; }
  ref auto opAssign() (in auto ref CLAB c) { pragma(inline, true); this = cast(SRGB)cast(CXYZD65)c; return this; }
  ref auto opAssign(C) (in auto ref C c) if (is(C : CXYZImpl!M, string M) || is(C == CHSL)) { pragma(inline, true); this = cast(SRGB)c; return this; }

  RGB8 opCast(T:RGB8) () const nothrow @safe @nogc { pragma(inline, true); return RGB8(cast(int)(r*255.0+0.5), cast(int)(g*255.0+0.5), cast(int)(b*255.0+0.5)); }
  SRGB opCast(T:SRGB) () const nothrow @safe @nogc { pragma(inline, true); return SRGB(r, g, b); }
  CLAB opCast(T:CLAB) () const nothrow @safe @nogc { pragma(inline, true); return CLAB(CXYZD65(this)); }
  C opCast(C) () const nothrow @safe @nogc if (is(C : CXYZImpl!M, string M) || is(C == CHSL)) { pragma(inline, true); return C(this); }

  // CIE76
  float distance(C) (in auto ref C c) const if (is(C : CXYZImpl!M, string M) || is(C == SRGB) || is(C == RGB8) || is(C == CLAB) || is(C == CHSL)) { pragma(inline, true); return (cast(CLAB)this).distance(c); }
  float distanceSquared(C) (in auto ref C c) const if (is(C : CXYZImpl!M, string M) || is(C == SRGB) || is(C == RGB8) || is(C == CLAB) || is(C == CHSL)) { pragma(inline, true); return (cast(CLAB)this).distanceSquared(c); }
}


alias CXYZD65 = CXYZImpl!"d65"; // color in CIE Standard Illuminant D65
alias CXYZLinear = CXYZImpl!"linear"; // color in linear space

// color in linear space
struct CXYZImpl(string mode) {
public:
  static assert(mode == "d65" || mode == "linear", "invalid CXYZ mode: '"~mode~"'");
  alias MyType = CXYZImpl!mode;

public:
  string toString () const nothrow @trusted {
    import core.stdc.stdio : snprintf;
    char[256] buf = void;
    auto len = snprintf(buf.ptr, buf.length, "CXYZ[%s](%g,%g,%g)", mode.ptr, cast(double)x, cast(double)y, cast(double)z);
    return buf[0..len].idup;
  }

public pure nothrow @safe @nogc:
  float x=0, y=0, z=0; // [0..1]

  this (in float ax, in float ay, in float az) { pragma(inline, true); x = ax; y = ay; z = az; }
  this() (in auto ref MyType c) { pragma(inline, true); x = c.x; y = c.y; z = c.z; }
  this() (in auto CLAB c) { pragma(inline, true); this = cast(MyType)c; }
  this() (in auto CHSL c) { pragma(inline, true); this = cast(MyType)c; }
  this() (in auto ref RGB8 c) {
    static if (mode == "d65") {
      immutable double rl = valueFromGamma(c.r/255.0);
      immutable double gl = valueFromGamma(c.g/255.0);
      immutable double bl = valueFromGamma(c.b/255.0);
      // observer = 2degs, illuminant = D65
      x = rl*0.4124+gl*0.3576+bl*0.1805;
      y = rl*0.2126+gl*0.7152+bl*0.0722;
      z = rl*0.0193+gl*0.1192+bl*0.9505;
    } else {
      x = valueFromGamma(c.r/255.0);
      y = valueFromGamma(c.g/255.0);
      z = valueFromGamma(c.b/255.0);
    }
  }
  this() (in auto ref SRGB c) {
    static if (mode == "d65") {
      immutable double rl = valueFromGamma(c.r);
      immutable double gl = valueFromGamma(c.g);
      immutable double bl = valueFromGamma(c.b);
      // observer = 2degs, illuminant = D65
      x = rl*0.4124+gl*0.3576+bl*0.1805;
      y = rl*0.2126+gl*0.7152+bl*0.0722;
      z = rl*0.0193+gl*0.1192+bl*0.9505;
    } else {
      x = valueFromGamma(c.r);
      y = valueFromGamma(c.g);
      z = valueFromGamma(c.b);
    }
  }

  ref auto opAssign() (in auto ref MyType c) { pragma(inline, true); x = c.x; y = c.y; z = c.z; return this; }
  ref auto opAssign(C) (in auto ref C c) if (is(C == RGB8) || is(C == SRGB) || is(C == CHSL)) { pragma(inline, true); this = cast(MyType)c; return this; }
  static if (mode == "d65") ref auto opAssign() (in auto CLAB c) { pragma(inline, true); this = cast(MyType)c; return this; }
  static if (mode == "linear") ref auto opAssign() (in auto CLAB c) { pragma(inline, true); this = cast(MyType)cast(SRGB)c; return this; }

  MyType opCast(T:MyType) () const { pragma(inline, true); return MyType(x, y, z); }
  static if (mode == "d65") CLAB opCast(T:CLAB) () { pragma(inline, true); return CLAB(this); }

  RGB8 opCast(T:RGB8) () const {
    static if (mode == "d65") {
      immutable double xs = x* 3.2406+y*-1.5372+z*-0.4986;
      immutable double ys = x*-0.9689+y* 1.8758+z* 0.0415;
      immutable double zs = x* 0.0557+y*-0.2040+z* 1.0570;
      return RGB8(cast(int)(valueFromLinear(xs)*255.0+0.5), cast(int)(valueFromLinear(ys)*255.0+0.5), cast(int)(valueFromLinear(zs)*255.0+0.5));
    } else {
      return SRGB(cast(int)(valueFromLinear(x)*255.0+0.5), cast(int)(valueFromLinear(y)*255.0+0.5), cast(int)(valueFromLinear(z)*255.0+0.5));
    }
  }

  SRGB opCast(T:SRGB) () const {
    static if (mode == "d65") {
      immutable double xs = x* 3.2406+y*-1.5372+z*-0.4986;
      immutable double ys = x*-0.9689+y* 1.8758+z* 0.0415;
      immutable double zs = x* 0.0557+y*-0.2040+z* 1.0570;
      return SRGB(valueFromLinear(xs), valueFromLinear(ys), valueFromLinear(zs));
    } else {
      return SRGB(valueFromLinear(x), valueFromLinear(y), valueFromLinear(z));
    }
  }

  MyType lighten (in float n) const { pragma(inline, true); return MyType(clamp(x+n), clamp(y+n), clamp(z+n)); }
  MyType darken (in float n) const { pragma(inline, true); return MyType(clamp(x-n), clamp(y-n), clamp(z-n)); }

  // CIE76
  float distance(C) (in auto ref C c) const if (is(C : CXYZImpl!M, string M) || is(C == SRGB) || is(C == RGB8) || is(C == CLAB) || is(C == CHSL)) { pragma(inline, true); return (cast(CLAB)this).distance(c); }
  float distanceSquared(C) (in auto ref C c) const if (is(C : CXYZImpl!M, string M) || is(C == SRGB) || is(C == RGB8) || is(C == CLAB) || is(C == CHSL)) { pragma(inline, true); return (cast(CLAB)this).distanceSquared(c); }

public:
  static T clamp(T) (in T a) { pragma(inline, true); return (a < 0 ? 0 : a > 1 ? 1 : a); }

  // gamma to linear conversion
  // value should be in [0..1] range
  static T valueFromGamma(T : real) (T v) {
    import std.math : pow;
    return (v > 0.04045 ? pow((v+0.055)/1.055, 2.4) : v/12.92);
  }

  // linear to gamma conversion
  // value should be in [0..1] range
  static T valueFromLinear(T : real) (T v) {
    import std.math : pow;
    return (v > 0.0031308 ? 1.055*pow(v, (1.0/2.4))-0.055 : 12.92*v);
  }
}


// color in CIE Lab space
struct CLAB {
public:
  string toString () const nothrow @trusted {
    import core.stdc.stdio : snprintf;
    char[256] buf = void;
    auto len = snprintf(buf.ptr, buf.length, "CLAB(%g,%g,%g)", cast(double)l, cast(double)a, cast(double)b);
    return buf[0..len].idup;
  }

public pure nothrow @safe @nogc:
  float l=0, a=0, b=0; // *NOT* [0..1]

  this (in float al, in float aa, in float ab) { pragma(inline, true); l = al; a = aa; b = ab; }
  this(C) (in auto ref C c) if (is(C == SRGB) || is(C == RGB8)) { pragma(inline, true); this = cast(CLAB)c; }

  this() (in auto ref CXYZD65 c) {
    import std.math : pow;

    double xs = c.x/95.047;
    double ys = c.y/100.0;
    double zs = c.z/108.883;

    xs = (xs > 0.008856 ? pow(xs, 1.0/3.0) : (7.787*xs)+16.0/116.0);
    ys = (ys > 0.008856 ? pow(ys, 1.0/3.0) : (7.787*ys)+16.0/116.0);
    zs = (zs > 0.008856 ? pow(zs, 1.0/3.0) : (7.787*zs)+16.0/116.0);

    l = cast(float)((116.0*ys)-16.0);
    a = cast(float)(500.0*(xs-ys));
    b = cast(float)(200.0*(ys-zs));
  }

  ref auto opAssign() (in auto ref CLAB c) { pragma(inline, true); l = c.l; a = c.a; b = c.b; return this; }
  ref auto opAssign(C) (in auto ref C c) if (is(C == RGB8) || is(C == SRGB) || is(C == CXYZD65) || is(C == CHSL)) { pragma(inline, true); this = cast(CLAB)c; return this; }
  ref auto opAssign() (in auto ref CXYZLinear c) { pragma(inline, true); this = cast(CLAB)cast(SRGB)c; return this; }

  CLAB opCast(T:CLAB) () const { pragma(inline, true); return CLAB(l, a, b); }
  SRGB opCast(T:SRGB) () const { pragma(inline, true); return SRGB(this); }
  RGB8 opCast(T:RGB8) () const { pragma(inline, true); return RGB8(this); }
  RGB8 opCast(T:CHSL) () const { pragma(inline, true); return CHSL(this); }
  CXYZLinear opCast(T:CXYZLinear) () const { pragma(inline, true); return CXYZLinear(cast(SRGB)this); }

  CXYZD65 opCast(T:CXYZD65) () const {
    immutable double ys = (l+16.0)/116.0;
    immutable double xs = (a/500.0)+ys;
    immutable double zs = ys-(b/200.0);

    immutable double x3 = xs*xs*xs;
    immutable double y3 = ys*ys*ys;
    immutable double z3 = zs*zs*zs;

    return CXYZD65(
      (x3 > 0.008856 ? x3 : (xs-16.0/116.0)/7.787)*95.047,
      (y3 > 0.008856 ? y3 : (ys-16.0/116.0)/7.787)*100.000,
      (z3 > 0.008856 ? z3 : (zs-16.0/116.0)/7.787)*108.883,
    );
  }

  // CIE76
  float distance() (in auto ref CLAB c) const { pragma(inline, true); import std.math : sqrt; return sqrt((l-c.l)*(l-c.l)+(a-c.a)*(a-c.a)+(b-c.b)*(b-c.b)); }
  float distance(C) (in auto ref C c) const if (is(C : CXYZImpl!M, string M) || is(C == SRGB) || is(C == RGB8) || is(C == CHSL)) { pragma(inline, true); return distance(cast(CLAB)c); }
  float distanceSquared() (in auto ref CLAB c) const { pragma(inline, true); return (l-c.l)*(l-c.l)+(a-c.a)*(a-c.a)+(b-c.b)*(b-c.b); }
  float distanceSquared(C) (in auto ref C c) const if (is(C : CXYZImpl!M, string M) || is(C == SRGB) || is(C == RGB8) || is(C == CHSL)) { pragma(inline, true); return distanceSquared(cast(CLAB)c); }
}


// Hue/Saturation/Lighting color
struct CHSL {
public:
  string toString () const nothrow @trusted {
    import core.stdc.stdio : snprintf;
    char[256] buf = void;
    auto len = snprintf(buf.ptr, buf.length, "CHSL(%g,%g,%g)", cast(double)h, cast(double)s, cast(double)l);
    return buf[0..len].idup;
  }

private nothrow @safe @nogc:
  void fromColor(C) (in auto ref C c) pure {
    static if (is(C == SRGB)) {
      enum Weighted = true;
      immutable double r1 = clamp(c.r);
      immutable double g1 = clamp(c.g);
      immutable double b1 = clamp(c.b);
    } else static if (is(C == RGB8)) {
      enum Weighted = true;
      immutable double r1 = c.r/255.0;
      immutable double g1 = c.g/255.0;
      immutable double b1 = c.b/255.0;
    } else static if (is(C : CXYZImpl!M, string M)) {
      enum Weighted = false;
      immutable double r1 = clamp(c.r);
      immutable double g1 = clamp(c.g);
      immutable double b1 = clamp(c.b);
    } else {
      immutable cc = cast(CXYZD65)c;
      enum Weighted = false;
      immutable double r1 = clamp(cc.r);
      immutable double g1 = clamp(cc.g);
      immutable double b1 = clamp(cc.b);
    }

    double maxColor = r1;
    if (g1 > maxColor) maxColor = g1;
    if (b1 > maxColor) maxColor = b1;

    double minColor = r1;
    if (g1 < minColor) minColor = g1;
    if (b1 < minColor) minColor = b1;

    static if (Weighted && false) {
      // the colors don't affect the eye equally
      // this is a little more accurate than plain HSL numbers
      l = 0.2126*r1+0.7152*g1+0.0722*b1;
    } else {
      l = (maxColor+minColor)/2.0;
    }
    if (maxColor != minColor) {
      if (l < 0.5) {
        s = (maxColor-minColor)/(maxColor+minColor);
      } else {
        s = (maxColor-minColor)/(2.0-maxColor-minColor);
      }
      if (r1 == maxColor) {
        h = (g1-b1)/(maxColor-minColor);
      } else if(g1 == maxColor) {
        h = 2.0+(b1-r1)/(maxColor-minColor);
      } else {
        h = 4.0+(r1-g1)/(maxColor-minColor);
      }
    }

    h = h*60;
    if (h < 0) h += 360;
    h /= 360;
  }

  C toColor(C) () const {
    static double hue (double h, double m1, double m2) pure nothrow @safe @nogc {
      if (h < 0) h += 1;
      if (h > 1) h -= 1;
      if (h < 1.0/6.0) return m1+(m2-m1)*h*6.0;
      if (h < 3.0/6.0) return m2;
      if (h < 4.0/6.0) return m1+(m2-m1)*(2.0/3.0-h)*6.0;
      return m1;
    }
    import std.math : modf;
    real tmpi = void;
    double sh = modf(h, tmpi);
    if (sh < 0.0f) sh += 1.0f;
    double ss = clamp(s);
    double sl = clamp(l);
    immutable double m2 = (sl <= 0.5 ? sl*(1+ss) : sl+ss-sl*ss);
    immutable double m1 = 2*sl-m2;

    static if (is(C == SRGB)) {
      return SRGB(
        clamp(hue(sh+1.0/3.0, m1, m2)),
        clamp(hue(sh, m1, m2)),
        clamp(hue(sh-1.0/3.0, m1, m2)),
      );
    } else static if (is(C == RGB8)) {
      return RGB8(
        cast(int)(hue(sh+1.0/3.0, m1, m2)*255.0),
        cast(int)(hue(sh, m1, m2)*255.0),
        cast(int)(hue(sh-1.0/3.0, m1, m2)*255.0),
      );
    } else static if (is(C : CXYZImpl!M, string M)) {
      return C(
        clamp(hue(sh+1.0/3.0, m1, m2)),
        clamp(hue(sh, m1, m2)),
        clamp(hue(sh-1.0/3.0, m1, m2)),
      );
    } else {
      return cast(C)CXYZD65(
        clamp(hue(sh+1.0/3.0, m1, m2)),
        clamp(hue(sh, m1, m2)),
        clamp(hue(sh-1.0/3.0, m1, m2)),
      );
    }
  }

public nothrow @safe @nogc:
  float h = 0, s = 0, l = 0; // [0..1]

  this (in float ah, in float as, in float al) { pragma(inline, true); h = ah; s = as; l = al; }
  this() (in auto ref CHSL c) { pragma(inline, true); h = c.h; s = c.s; l = c.l; }
  this(C) (in auto ref C c) if (is(C : CXYZImpl!M, string M) || is(C == SRGB) || is(C == RGB8) || is(C == CLAB)) { pragma(inline, true); fromColor(c); }

  ref opAssign(C:CHSL) (in auto ref C c) { pragma(inline, true); h = c.h; s = c.s; l = c.l; return this; }
  ref opAssign(C) (in auto ref C c) if (is(C : CXYZImpl!M, string M) || is(C == SRGB) || is(C == RGB8) || is(C == CLAB)) { pragma(inline, true); fromColor(c); return this; }

  CHSL opCast(C:CHSL) () const { pragma(inline, true); return CHSL(h, s, l); }
  C opCast(C) () const if (is(C : CXYZImpl!M, string M) || is(C == SRGB) || is(C == RGB8) || is(C == CLAB)) { pragma(inline, true); return toColor!C; }

  //CHSL darken (in float n) const { pragma(inline, true); return CHSL(clamp(h*n), s, l); }

  // CIE76
  float distance(C) (in auto ref C c) const if (is(C : CXYZImpl!M, string M) || is(C == SRGB) || is(C == RGB8) || is(C == CLAB)) { pragma(inline, true); return (cast(CLAB)this).distance(c); }
  float distanceSquared(C) (in auto ref C c) const if (is(C : CXYZImpl!M, string M) || is(C == SRGB) || is(C == RGB8) || is(C == CLAB)) { pragma(inline, true); return (cast(CLAB)this).distanceSquared(c); }

public:
  static T clamp(T) (in T a) { pragma(inline, true); return (a < 0 ? 0 : a > 1 ? 1 : a); }
}


version(iv_color_unittest) unittest {
  import std.stdio;
  {
    auto s0 = SRGB(1, 128/255.0, 0);
    auto l0 = cast(CXYZD65)s0;
    auto l1 = cast(CXYZLinear)s0;
    auto s1 = cast(SRGB)l0;
    auto s2 = cast(SRGB)l1;
    writeln("s0=", s0, " : ", cast(RGB8)s0);
    writeln("l0=", l0);
    writeln("l1=", l1);
    writeln("s1=", s1);
    writeln("s2=", s2);

    writeln("black XYZ=", cast(CXYZD65)SRGB(0, 0, 0));
    writeln("white XYZ=", cast(CXYZD65)SRGB(1, 1, 1));
    writeln("MUST BE  =CXYZ(0.9642,1,0.8249)");
    //writeln("white XYZ=", cast(linear)sRGB(1));

    auto lab = cast(CLAB)s0;
    writeln("srgb->lab->srgb: ", cast(SRGB)lab, " : ", cast(RGB8)lab);
    writeln("rgb: ", s0, " : ", cast(RGB8)s0);
    writeln("lab: ", lab);
    writeln("rgb: ", cast(SRGB)lab);
    lab.l -= 1;
    auto z1 = cast(SRGB)lab; //cast(SRGB)CLAB(lab.l-0.01, lab.a, lab.b);
    writeln("rgbX: ", z1, " : ", cast(RGB8)z1);
    writeln("xxx: ", cast(CLAB)cast(CXYZD65)RGB8(255-16, 128-16, 0));
  }

  {
    writeln("============");
    auto s0 = RGB8(255, 127, 0);
    writeln("*s0: ", s0, " : ", cast(RGB8)s0);
    auto h0 = cast(CHSL)s0;
    writeln("*h0: ", h0);
    h0.h *= 0.9;
    writeln("*s1: ", h0, " : ", cast(RGB8)h0);
    writeln(RGB8(255-25, 127-25, 0-25));
  }

  {
    writeln("============");
    auto s0 = cast(CXYZD65)RGB8(255, 127, 0);
    writeln("*s0: ", s0, " : ", cast(RGB8)s0);
    auto s1 = s0.darken(0.1);
    writeln("*s1: ", s0, " : ", cast(RGB8)s0);
    writeln(RGB8(255-25, 127-25, 0-25));
  }
}
