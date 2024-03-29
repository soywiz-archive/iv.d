/*
 * coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
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
// various vector and matrix operations
// matrix should be compatible with OpenGL, but mostly untested
module iv.vmath /*is aliced*/;
import iv.alice;

//version = aabbtree_many_asserts;
version = aabbtree_query_count;
version = vmath_slow_normalize;


// ////////////////////////////////////////////////////////////////////////// //
version(vmath_double) {
  alias VFloat = double;
} else {
  alias VFloat = float;
}
enum VFloatNum(long v) = cast(VFloat)v;
enum VFloatNum(float v) = cast(VFloat)v;
enum VFloatNum(double v) = cast(VFloat)v;
enum VFloatNum(real v) = cast(VFloat)v;


// ////////////////////////////////////////////////////////////////////////// //
/// is `v` finite (i.e. not a nan and not an infinity)?
public bool isFiniteDbl (in double v) pure nothrow @trusted @nogc {
  pragma(inline, true);
  return (((*cast(const(ulong)*)&v)&0x7ff0_0000_0000_0000UL) != 0x7ff0_0000_0000_0000UL);
}


/// is `v` finite (i.e. not a nan and not an infinity)?
public bool isFiniteFlt (in float v) pure nothrow @trusted @nogc {
  pragma(inline, true);
  return (((*cast(const(uint)*)&v)&0x7f80_0000U) != 0x7f80_0000U);
}


// ////////////////////////////////////////////////////////////////////////// //
private template isGoodSwizzling(string s, string comps, int minlen, int maxlen) {
  private static template hasChar(string str, char ch, uint idx=0) {
         static if (idx >= str.length) enum hasChar = false;
    else static if (str[idx] == ch) enum hasChar = true;
    else enum hasChar = hasChar!(str, ch, idx+1);
  }
  private static template swz(string str, string comps, uint idx=0) {
         static if (idx >= str.length) enum swz = true;
    else static if (hasChar!(comps, str[idx])) enum swz = swz!(str, comps, idx+1);
    else enum swz = false;
  }
  static if (s.length >= minlen && s.length <= maxlen) enum isGoodSwizzling = swz!(s, comps);
  else enum isGoodSwizzling = false;
}

private template SwizzleCtor(string stn, string s) {
  private static template buildCtor (string s, uint idx) {
    static if (idx >= s.length) enum buildCtor = "";
    else enum buildCtor = s[idx]~","~buildCtor!(s, idx+1);
  }
  enum SwizzleCtor = stn~"("~buildCtor!(s, 0)~")";
}


// ////////////////////////////////////////////////////////////////////////// //
// Values obtained from Wolfram Alpha. 116 bits ought to be enough for anybody.
// Wolfram Alpha LLC. 2011. Wolfram|Alpha. http://www.wolframalpha.com/input/?i=e+in+base+16 (access July 6, 2011).
enum real E_R =          0x1.5bf0a8b1457695355fb8ac404e7a8p+1L; /* e = 2.718281... */
enum real LOG2T_R =      0x1.a934f0979a3715fc9257edfe9b5fbp+1L; /* log2 10 = 3.321928... */
enum real LOG2E_R =      0x1.71547652b82fe1777d0ffda0d23a8p+0L; /* log2 e = 1.442695... */
enum real LOG2_R =       0x1.34413509f79fef311f12b35816f92p-2L; /* log10 2 = 0.301029... */
enum real LOG10E_R =     0x1.bcb7b1526e50e32a6ab7555f5a67cp-2L; /* log10 e = 0.434294... */
enum real LN2_R =        0x1.62e42fefa39ef35793c7673007e5fp-1L; /* ln 2  = 0.693147... */
enum real LN10_R =       0x1.26bb1bbb5551582dd4adac5705a61p+1L; /* ln 10 = 2.302585... */
enum real PI_R =         0x1.921fb54442d18469898cc51701b84p+1L; /* PI = 3.141592... */
enum real PI_2_R =       PI_R/2;                                /* PI / 2 = 1.570796... */
enum real PI_4_R =       PI_R/4;                                /* PI / 4 = 0.785398... */
enum real M_1_PI_R =     0x1.45f306dc9c882a53f84eafa3ea69cp-2L; /* 1 / PI = 0.318309... */
enum real M_2_PI_R =     2*M_1_PI_R;                            /* 2 / PI = 0.636619... */
enum real M_2_SQRTPI_R = 0x1.20dd750429b6d11ae3a914fed7fd8p+0L; /* 2 / sqrt(PI) = 1.128379... */
enum real SQRT2_R =      0x1.6a09e667f3bcc908b2fb1366ea958p+0L; /* sqrt(2) = 1.414213... */
enum real SQRT1_2_R =    SQRT2_R/2;                             /* sqrt(1/2) = 0.707106... */

enum double E_D =          cast(double)0x1.5bf0a8b1457695355fb8ac404e7a8p+1L; /* e = 2.718281... */
enum double LOG2T_D =      cast(double)0x1.a934f0979a3715fc9257edfe9b5fbp+1L; /* log2 10 = 3.321928... */
enum double LOG2E_D =      cast(double)0x1.71547652b82fe1777d0ffda0d23a8p+0L; /* log2 e = 1.442695... */
enum double LOG2_D =       cast(double)0x1.34413509f79fef311f12b35816f92p-2L; /* log10 2 = 0.301029... */
enum double LOG10E_D =     cast(double)0x1.bcb7b1526e50e32a6ab7555f5a67cp-2L; /* log10 e = 0.434294... */
enum double LN2_D =        cast(double)0x1.62e42fefa39ef35793c7673007e5fp-1L; /* ln 2  = 0.693147... */
enum double LN10_D =       cast(double)0x1.26bb1bbb5551582dd4adac5705a61p+1L; /* ln 10 = 2.302585... */
enum double PI_D =         cast(double)0x1.921fb54442d18469898cc51701b84p+1L; /* PI = 3.141592... */
enum double PI_2_D =       cast(double)(PI_R/2);                              /* PI / 2 = 1.570796... */
enum double PI_4_D =       cast(double)(PI_R/4);                              /* PI / 4 = 0.785398... */
enum double M_1_PI_D =     cast(double)0x1.45f306dc9c882a53f84eafa3ea69cp-2L; /* 1 / PI = 0.318309... */
enum double M_2_PI_D =     cast(double)(2*M_1_PI_R);                          /* 2 / PI = 0.636619... */
enum double M_2_SQRTPI_D = cast(double)0x1.20dd750429b6d11ae3a914fed7fd8p+0L; /* 2 / sqrt(PI) = 1.128379... */
enum double SQRT2_D =      cast(double)0x1.6a09e667f3bcc908b2fb1366ea958p+0L; /* sqrt(2) = 1.414213... */
enum double SQRT1_2_D =    cast(double)(SQRT2_R/2);                           /* sqrt(1/2) = 0.707106... */

enum float E_F =          cast(float)0x1.5bf0a8b1457695355fb8ac404e7a8p+1L; /* e = 2.718281... */
enum float LOG2T_F =      cast(float)0x1.a934f0979a3715fc9257edfe9b5fbp+1L; /* log2 10 = 3.321928... */
enum float LOG2E_F =      cast(float)0x1.71547652b82fe1777d0ffda0d23a8p+0L; /* log2 e = 1.442695... */
enum float LOG2_F =       cast(float)0x1.34413509f79fef311f12b35816f92p-2L; /* log10 2 = 0.301029... */
enum float LOG10E_F =     cast(float)0x1.bcb7b1526e50e32a6ab7555f5a67cp-2L; /* log10 e = 0.434294... */
enum float LN2_F =        cast(float)0x1.62e42fefa39ef35793c7673007e5fp-1L; /* ln 2  = 0.693147... */
enum float LN10_F =       cast(float)0x1.26bb1bbb5551582dd4adac5705a61p+1L; /* ln 10 = 2.302585... */
enum float PI_F =         cast(float)0x1.921fb54442d18469898cc51701b84p+1L; /* PI = 3.141592... */
enum float PI_2_F =       cast(float)(PI_R/2);                              /* PI / 2 = 1.570796... */
enum float PI_4_F =       cast(float)(PI_R/4);                              /* PI / 4 = 0.785398... */
enum float M_1_PI_F =     cast(float)0x1.45f306dc9c882a53f84eafa3ea69cp-2L; /* 1 / PI = 0.318309... */
enum float M_2_PI_F =     cast(float)(2*M_1_PI_R);                          /* 2 / PI = 0.636619... */
enum float M_2_SQRTPI_F = cast(float)0x1.20dd750429b6d11ae3a914fed7fd8p+0L; /* 2 / sqrt(PI) = 1.128379... */
enum float SQRT2_F =      cast(float)0x1.6a09e667f3bcc908b2fb1366ea958p+0L; /* sqrt(2) = 1.414213... */
enum float SQRT1_2_F =    cast(float)(SQRT2_R/2);                           /* sqrt(1/2) = 0.707106... */


// ////////////////////////////////////////////////////////////////////////// //
private template IsKnownVMathConstant(string name) {
  static if (name == "E" || name == "LOG2T" || name == "LOG2E" || name == "LOG2" || name == "LOG10E" ||
             name == "LN2" || name == "LN10" || name == "PI" || name == "PI_2" || name == "PI_4" ||
             name == "M_1_PI" || name == "M_2_PI" || name == "M_2_SQRTPI" || name == "SQRT2" || name == "SQRT1_2")
  {
    enum IsKnownVMathConstant = true;
  } else {
    enum IsKnownVMathConstant = false;
  }
}

template ImportCoreMath(FloatType, T...) {
  static assert(
    (is(FloatType == float) || is(FloatType == const float) || is(FloatType == immutable float)) ||
    (is(FloatType == double) || is(FloatType == const double) || is(FloatType == immutable double)),
    "import type should be `float` or `double`");
  private template InternalImport(T...) {
    static if (T.length == 0) enum InternalImport = "";
    else static if (is(typeof(T[0]) == string)) {
      static if (T[0] == "fabs" || T[0] == "cos" || T[0] == "sin" || T[0] == "sqrt") {
        enum InternalImport = "import core.math : "~T[0]~";"~InternalImport!(T[1..$]);
      } else static if (T[0] == "min" || T[0] == "nmin") {
        enum InternalImport = "static T "~T[0]~"(T) (in T a, in T b) { pragma(inline, true); return (a < b ? a : b); }"~InternalImport!(T[1..$]);
      } else static if (T[0] == "max" || T[0] == "nmax") {
        enum InternalImport = "static T "~T[0]~"(T) (in T a, in T b) { pragma(inline, true); return (a > b ? a : b); }"~InternalImport!(T[1..$]);
      } else static if (IsKnownVMathConstant!(T[0])) {
        static if (is(FloatType == float) || is(FloatType == const float) || is(FloatType == immutable float)) {
          enum InternalImport = "enum "~T[0]~"="~T[0]~"_F;"~InternalImport!(T[1..$]);
        } else {
          enum InternalImport = "enum "~T[0]~"="~T[0]~"_D;"~InternalImport!(T[1..$]);
        }
      } else static if (T[0] == "isnan") {
        enum InternalImport = "import core.stdc.math : isnan;"~InternalImport!(T[1..$]);
      } else static if (T[0] == "isfinite") {
        static if (is(FloatType == float) || is(FloatType == const float) || is(FloatType == immutable float)) {
          enum InternalImport = "import iv.nanpay : isfinite = isFinite;"~InternalImport!(T[1..$]);
        } else {
          enum InternalImport = "import iv.nanpay : isfinite = isFiniteD;"~InternalImport!(T[1..$]);
        }
      } else static if (is(FloatType == float) || is(FloatType == const float) || is(FloatType == immutable float)) {
        enum InternalImport = "import core.stdc.math : "~T[0]~"="~T[0]~"f;"~InternalImport!(T[1..$]);
      } else {
        enum InternalImport = "import core.stdc.math : "~T[0]~";"~InternalImport!(T[1..$]);
      }
    }
    else static assert(0, "string expected");
  }
  static if (T.length > 0) {
    enum ImportCoreMath = InternalImport!T;
  } else {
    enum ImportCoreMath = "{}";
  }
}


// ////////////////////////////////////////////////////////////////////////// //
enum FLTEPS = 1e-6f;
enum DBLEPS = 1.0e-18;
template EPSILON(T) if (is(T == float) || is(T == double)) {
       static if (is(T == float)) enum EPSILON = FLTEPS;
  else static if (is(T == double)) enum EPSILON = DBLEPS;
  else static assert(0, "wtf?!");
}
template SMALLEPSILON(T) if (is(T == float) || is(T == double)) {
       static if (is(T == float)) enum SMALLEPSILON = 1e-5f;
  else static if (is(T == double)) enum SMALLEPSILON = 1.0e-9;
  else static assert(0, "wtf?!");
}

auto deg2rad(T:double) (T v) pure nothrow @safe @nogc {
  pragma(inline, true);
  static if (__traits(isFloating, T)) {
    static if (is(T == float)) alias PI = PI_F; else alias PI = PI_D;
    return cast(T)(v*cast(T)PI/cast(T)180);
  } else {
    static if (is(VFloat == float)) alias PI = PI_F; else alias PI = PI_D;
    return cast(VFloat)(cast(VFloat)v*cast(VFloat)PI/cast(VFloat)180);
  }
}

auto rad2deg(T:double) (T v) pure nothrow @safe @nogc {
  pragma(inline, true);
  static if (__traits(isFloating, T)) {
    static if (is(T == float)) alias PI = PI_F; else alias PI = PI_D;
    return cast(T)(v*cast(T)180/cast(T)PI);
  } else {
    static if (is(VFloat == float)) alias PI = PI_F; else alias PI = PI_D;
    return cast(VFloat)(cast(VFloat)v*cast(VFloat)180/cast(VFloat)PI);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
alias vec2 = VecN!2;
alias vec3 = VecN!3;
//alias AABB2 = AABBImpl!vec2;


// ////////////////////////////////////////////////////////////////////////// //
template IsVector(VT) {
  static if (is(VT == VecN!(D, T), ubyte D, T)) {
    enum IsVector = (D == 2 || D == 3);
  } else {
    enum IsVector = false;
  }
}

template IsVectorDim(VT, ubyte dim) {
  static if (is(VT == VecN!(D, T), ubyte D, T)) {
    enum IsVectorDim = (D == dim);
  } else {
    enum IsVectorDim = false;
  }
}

template IsVector(VT, FT) {
  static if (is(VT == VecN!(D, T), ubyte D, T)) {
    enum IsVector = ((D == 2 || D == 3) && is(T == FT));
  } else {
    enum IsVector = false;
  }
}

template IsVectorDim(VT, FT, ubyte dim) {
  static if (is(VT == VecN!(D, T), ubyte D, T)) {
    enum IsVectorDim = (D == dim && is(T == FT));
  } else {
    enum IsVectorDim = false;
  }
}

template VectorDims(VT) {
  static if (is(VT == VecN!(D, F), ubyte D, F)) {
    enum VectorDims = D;
  } else {
    enum VectorDims = 0;
  }
}

template VectorFloat(VT) {
  static if (is(VT == VecN!(D, F), ubyte D, F)) {
    alias VectorFloat = F;
  } else {
    static assert(0, "not a vector");
  }
}


// ////////////////////////////////////////////////////////////////////////// //
align(1) struct VecN(ubyte dims, FloatType=VFloat) if (dims >= 2 && dims <= 3 && (is(FloatType == float) || is(FloatType == double))) {
align(1):
public:
  static T nmin(T) (in T a, in T b) { pragma(inline, true); return (a < b ? a : b); }
  static T nmax(T) (in T a, in T b) { pragma(inline, true); return (a > b ? a : b); }

public:
  enum isVector(VT) = (is(VT == VecN!(2, FloatType)) || is(VT == VecN!(3, FloatType)));
  enum isVector2(VT) = is(VT == VecN!(2, FloatType));
  enum isVector3(VT) = is(VT == VecN!(3, FloatType));
  enum isSameVector(VT) = is(VT == VecN!(dims, FloatType));

  alias v2 = VecN!(2, FloatType);
  alias v3 = VecN!(3, FloatType);

  alias Me = typeof(this);
  alias Float = FloatType;
  alias Dims = dims;
  enum Epsilon = EPSILON!Float;

public:
  Float x = 0;
  Float y = 0;
  static if (dims >= 3) Float z = 0;

nothrow @safe:
  string toString () const {
    import std.string : format;
    try {
           static if (dims == 2) return "(%s,%s)".format(x, y);
      else static if (dims == 3) return "(%s,%s,%s)".format(x, y, z);
      else static assert(0, "invalid dimension count for vector");
    } catch (Exception) {
      assert(0);
    }
  }

  //HACK!
  inout(Float)* unsafePtr () inout nothrow @trusted @nogc { pragma(inline, true); return cast(typeof(return))&x; }

@nogc:
  this (in Float[] c) @trusted {
    x = (c.length >= 1 ? c.ptr[0] : 0);
    y = (c.length >= 2 ? c.ptr[1] : 0);
    static if (dims == 3) z = (c.length >= 3 ? c.ptr[2] : 0);
  }

  this (in Float ax, in Float ay) pure {
    pragma(inline, true);
    x = ax;
    y = ay;
    static if (dims == 3) z = 0;
  }

  this (in Float ax, in Float ay, in Float az) pure {
    //pragma(inline, true);
    x = ax;
    y = ay;
    static if (dims == 3) z = az;
  }

  this(VT) (in auto ref VT v) pure if (isVector!VT) {
    //pragma(inline, true);
    x = v.x;
    y = v.y;
    static if (dims == 3) {
      static if (isVector3!VT) z = v.z; else z = 0;
    }
  }

  static Me Zero () pure nothrow @safe @nogc { pragma(inline, true); return Me(0, 0); }
  static Me Invalid () pure nothrow @safe @nogc { pragma(inline, true); return Me(Float.nan, Float.nan); }

  // infinites are invalid too
  @property bool valid () const nothrow @safe @nogc {
    /*
    pragma(inline, true);
    import core.stdc.math : isnan;
         static if (dims == 2) return !isnan(x) && !isnan(y);
    else static if (dims == 3) return !isnan(x) && !isnan(y) && !isnan(z);
    else static assert(0, "invalid dimension count for vector");
    */
    // this also reject nans
    pragma(inline, true);
    import core.stdc.math : isfinite;
         static if (dims == 2) return isfinite(x) && isfinite(y);
    else static if (dims == 3) return isfinite(x) && isfinite(y) && isfinite(z);
    else static assert(0, "invalid dimension count for vector");
  }

  // this also reject nans
  @property bool isFinite () const nothrow @safe @nogc {
    pragma(inline, true);
    import core.stdc.math : isfinite;
         static if (dims == 2) return isfinite(x) && isfinite(y);
    else static if (dims == 3) return isfinite(x) && isfinite(y) && isfinite(z);
    else static assert(0, "invalid dimension count for vector");
  }

  @property bool isZero () const nothrow @safe @nogc {
    pragma(inline, true);
         static if (dims == 2) return (x == 0 && y == 0);
    else static if (dims == 3) return (x == 0 && y == 0 && z == 0);
    else static assert(0, "invalid dimension count for vector");
  }

  @property bool isNearZero () const nothrow @safe @nogc {
    pragma(inline, true);
    mixin(ImportCoreMath!(Float, "fabs"));
         static if (dims == 2) return (fabs(x) < EPSILON!Float && fabs(y) < EPSILON!Float);
    else static if (dims == 3) return (fabs(x) < EPSILON!Float && fabs(y) < EPSILON!Float && fabs(z) < EPSILON!Float);
    else static assert(0, "invalid dimension count for vector");
  }

  void set (in Float[] c...) @trusted {
    x = (c.length >= 1 ? c.ptr[0] : 0);
    y = (c.length >= 2 ? c.ptr[1] : 0);
    static if (dims == 3) z = (c.length >= 3 ? c.ptr[2] : 0);
  }

  static if (dims == 2)
  void set (in Float ax, in Float ay) {
    //pragma(inline, true);
    x = ax;
    y = ay;
  }

  static if (dims == 3)
  void set (in Float ax, in Float ay, in Float az) {
    //pragma(inline, true);
    x = ax;
    y = ay;
    z = az;
  }

  void opAssign(VT) (in auto ref VT v) if (isVector!VT) {
    //pragma(inline, true);
    x = v.x;
    y = v.y;
    static if (dims == 3) {
      static if (isVector3!VT) z = v.z; else z = 0;
    }
  }

  Float opIndex (usize idx) const {
    pragma(inline, true);
         static if (dims == 2) return (idx == 0 ? x : idx == 1 ? y : Float.nan);
    else static if (dims == 3) return (idx == 0 ? x : idx == 1 ? y : idx == 2 ? z : Float.nan);
    else static assert(0, "invalid dimension count for vector");
  }

  void opIndexAssign (Float v, usize idx) {
    pragma(inline, true);
         static if (dims == 2) { if (idx == 0) x = v; else if (idx == 1) y = v; }
    else static if (dims == 3) { if (idx == 0) x = v; else if (idx == 1) y = v; else if (idx == 2) z = v; }
    else static assert(0, "invalid dimension count for vector");
  }

  ref auto normalize () {
    //pragma(inline, true);
    mixin(ImportCoreMath!(double, "sqrt"));
    version(vmath_slow_normalize) {
           static if (dims == 2) immutable double len = sqrt(x*x+y*y);
      else static if (dims == 3) immutable double len = sqrt(x*x+y*y+z*z);
      else static assert(0, "invalid dimension count for vector");
      x /= len;
      y /= len;
      static if (dims == 3) z /= len;
    } else {
           static if (dims == 2) immutable double invlen = 1.0/sqrt(x*x+y*y);
      else static if (dims == 3) immutable double invlen = 1.0/sqrt(x*x+y*y+z*z);
      else static assert(0, "invalid dimension count for vector");
      x *= invlen;
      y *= invlen;
      static if (dims == 3) z *= invlen;
    }
    return this;
  }

  Float normalizeRetLength () {
    //pragma(inline, true);
    mixin(ImportCoreMath!(double, "sqrt"));
         static if (dims == 2) immutable double len = sqrt(x*x+y*y);
    else static if (dims == 3) immutable double len = sqrt(x*x+y*y+z*z);
    else static assert(0, "invalid dimension count for vector");
    version(vmath_slow_normalize) {
      x /= len;
      y /= len;
      static if (dims == 3) z /= len;
    } else {
      immutable double invlen = 1.0/len;
      x *= invlen;
      y *= invlen;
      static if (dims == 3) z *= invlen;
    }
    return cast(Float)len;
  }

  /+
  ref auto safeNormalize () pure {
    //pragma(inline, true);
    import std.math : sqrt;
         static if (dims == 2) Float invlength = sqrt(x*x+y*y);
    else static if (dims == 3) Float invlength = sqrt(x*x+y*y+z*z);
    else static assert(0, "invalid dimension count for vector");
    if (invlength >= EPSILON!Float) {
      invlength = cast(Float)1/invlength;
      x *= invlength;
      y *= invlength;
      static if (dims == 3) z *= invlength;
    } else {
      x = 1;
      y = 0;
      static if (dims == 3) z = 0;
    }
    return this;
  }
  +/

  ref auto opOpAssign(string op, VT) (in auto ref VT a) if (isVector!VT && (op == "+" || op == "-" || op == "*")) {
    //pragma(inline, true);
    mixin("x "~op~"= a.x;");
    mixin("y "~op~"= a.y;");
    static if (dims == 3 && isVector3!VT) mixin("z "~op~"= a.z;");
    return this;
  }

  ref auto opOpAssign(string op) (Float a) if (op == "+" || op == "-" || op == "*") {
    //pragma(inline, true);
    mixin("x "~op~"= a;");
    mixin("y "~op~"= a;");
    static if (dims == 3) mixin("z "~op~"= a;");
    return this;
  }

  ref auto opOpAssign(string op:"/") (Float a) {
    //import std.math : abs;
    //pragma(inline, true);
    //a = (abs(a) >= EPSILON!Float ? 1.0/a : Float.nan);
    version(all/*vmath_slow_normalize*/) {
      x /= a;
      y /= a;
      static if (dims == 3) z /= a;
    } else {
      immutable double aa = 1.0/a;
      x *= aa;
      y *= aa;
      static if (dims == 3) z *= aa;
    }
    return this;
  }

  static if (dims == 2) {
    // radians
    ref auto rotate (Float angle) {
      pragma(inline, true);
      mixin(ImportCoreMath!(Float, "cos", "sin"));
      immutable Float c = cos(angle);
      immutable Float s = sin(angle);
      immutable Float nx = x*c-y*s;
      immutable Float ny = x*s+y*c;
      x = nx;
      y = ny;
      return this;
    }

    auto rotated (Float angle) const {
      pragma(inline, true);
      mixin(ImportCoreMath!(Float, "cos", "sin"));
      immutable Float c = cos(angle);
      immutable Float s = sin(angle);
      return v2(x*c-y*s, x*s+y*c);
    }
  }

const:
  // from `this` to `a`
  auto lerp(VT) (in auto ref VT a, in Float t) if (isVector!VT) {
    pragma(inline, true);
    return this+(a-this)*t;
  }

  auto normalized () {
    pragma(inline, true);
    static if (dims == 2) return v2(x, y).normalize; else return v3(x, y, z).normalize;
  }

  /+
  auto safeNormalized () {
    pragma(inline, true);
    static if (dims == 2) return v2(x, y).safeNormalize; else return v3(x, y, z).safeNormalize;
  }
  +/

  @property Float length () {
    pragma(inline, true);
    mixin(ImportCoreMath!(Float, "sqrt"));
         static if (dims == 2) return sqrt(x*x+y*y);
    else static if (dims == 3) return sqrt(x*x+y*y+z*z);
    else static assert(0, "invalid dimension count for vector");
  }

  @property double dbllength () {
    pragma(inline, true);
    mixin(ImportCoreMath!(double, "sqrt"));
         static if (dims == 2) return sqrt(cast(double)x*cast(double)x+cast(double)y*cast(double)y);
    else static if (dims == 3) return sqrt(cast(double)x*cast(double)x+cast(double)y*cast(double)y+cast(double)z*cast(double)z);
    else static assert(0, "invalid dimension count for vector");
  }

  @property Float lengthSquared () {
    pragma(inline, true);
         static if (dims == 2) return x*x+y*y;
    else static if (dims == 3) return x*x+y*y+z*z;
    else static assert(0, "invalid dimension count for vector");
  }

  @property double dbllengthSquared () {
    pragma(inline, true);
         static if (dims == 2) return cast(double)x*cast(double)x+cast(double)y*cast(double)y;
    else static if (dims == 3) return cast(double)x*cast(double)x+cast(double)y*cast(double)y+cast(double)z*cast(double)z;
    else static assert(0, "invalid dimension count for vector");
  }

  // distance
  Float distance(VT) (in auto ref VT a) if (isVector!VT) {
    pragma(inline, true);
    mixin(ImportCoreMath!(Float, "sqrt"));
    static if (dims == 2) {
           static if (isVector2!VT) return sqrt((x-a.x)*(x-a.x)+(y-a.y)*(y-a.y));
      else static if (isVector3!VT) return sqrt((x-a.x)*(x-a.x)+(y-a.y)*(y-a.y)+a.z*a.z);
      else static assert(0, "invalid dimension count for vector");
    } else static if (dims == 3) {
           static if (isVector2!VT) return sqrt((x-a.x)*(x-a.x)+(y-a.y)*(y-a.y)+z*z);
      else static if (isVector3!VT) return sqrt((x-a.x)*(x-a.x)+(y-a.y)*(y-a.y)+(z-a.z)*(z-a.z));
      else static assert(0, "invalid dimension count for vector");
    } else {
      static assert(0, "invalid dimension count for vector");
    }
  }

  // distance
  Float distanceSquared(VT) (in auto ref VT a) if (isVector!VT) {
    pragma(inline, true);
    static if (dims == 2) {
           static if (isVector2!VT) return (x-a.x)*(x-a.x)+(y-a.y)*(y-a.y);
      else static if (isVector3!VT) return (x-a.x)*(x-a.x)+(y-a.y)*(y-a.y)+a.z*a.z;
      else static assert(0, "invalid dimension count for vector");
    } else static if (dims == 3) {
           static if (isVector2!VT) return (x-a.x)*(x-a.x)+(y-a.y)*(y-a.y)+z*z;
      else static if (isVector3!VT) return (x-a.x)*(x-a.x)+(y-a.y)*(y-a.y)+(z-a.z)*(z-a.z);
      else static assert(0, "invalid dimension count for vector");
    } else {
      static assert(0, "invalid dimension count for vector");
    }
  }

  // distance
  double dbldistance(VT) (in auto ref VT a) if (isVector!VT) {
    pragma(inline, true);
    mixin(ImportCoreMath!(double, "sqrt"));
    return sqrt(dbldistanceSquared(a));
  }

  // distance
  double dbldistanceSquared(VT) (in auto ref VT a) if (isVector!VT) {
    pragma(inline, true);
    static if (dims == 2) {
           static if (isVector2!VT) return cast(double)(x-a.x)*cast(double)(x-a.x)+cast(double)(y-a.y)*cast(double)(y-a.y);
      else static if (isVector3!VT) return cast(double)(x-a.x)*cast(double)(x-a.x)+cast(double)(y-a.y)*cast(double)(y-a.y)+cast(double)a.z*cast(double)a.z;
      else static assert(0, "invalid dimension count for vector");
    } else static if (dims == 3) {
           static if (isVector2!VT) return cast(double)(x-a.x)*cast(double)(x-a.x)+cast(double)(y-a.y)*cast(double)(y-a.y)+cast(double)z*cast(double)z;
      else static if (isVector3!VT) return cast(double)(x-a.x)*cast(double)(x-a.x)+cast(double)(y-a.y)*cast(double)(y-a.y)+cast(double)(z-a.z)*cast(double)(z-a.z);
      else static assert(0, "invalid dimension count for vector");
    } else {
      static assert(0, "invalid dimension count for vector");
    }
  }

  auto opBinary(string op, VT) (in auto ref VT a) if (isVector!VT && (op == "+" || op == "-")) {
    pragma(inline, true);
         static if (dims == 2 && isVector2!VT) mixin("return v2(x"~op~"a.x, y"~op~"a.y);");
    else static if (dims == 2 && isVector3!VT) mixin("return v3(x"~op~"a.x, y"~op~"a.y, 0);");
    else static if (dims == 3 && isVector2!VT) mixin("return v3(x"~op~"a.x, y"~op~"a.y, 0);");
    else static if (dims == 3 && isVector3!VT) mixin("return v3(x"~op~"a.x, y"~op~"a.y, z"~op~"a.z);");
    else static assert(0, "invalid dimension count for vector");
  }

  // vector elements operation
  auto op(string opr, VT) (in auto ref VT a) if (isVector!VT && (opr == "+" || opr == "-" || opr == "*" || opr == "/")) {
    pragma(inline, true);
    static if (dims == 2) {
           static if (isVector2!VT) mixin("return v2(x"~opr~"a.x, y"~opr~"a.y);");
      else static if (isVector3!VT) mixin("return v2(x"~opr~"a.x, y"~opr~"a.y);");
      else static assert(0, "invalid dimension count for vector");
    } else static if (dims == 3) {
           static if (isVector2!VT) mixin("return v3(x"~opr~"a.x, y"~opr~"a.y, 0);");
      else static if (isVector3!VT) mixin("return v3(x"~opr~"a.x, y"~opr~"a.y, z"~opr~"a.z);");
      else static assert(0, "invalid dimension count for vector");
    } else {
      static assert(0, "invalid dimension count for vector");
    }
  }

  // dot product
  Float opBinary(string op:"*", VT) (in auto ref VT a) if (isVector!VT) { pragma(inline, true); return dot(a); }

  // cross product
  auto opBinary(string op:"%", VT) (in auto ref VT a) if (isVector!VT) { pragma(inline, true); return cross(a); }
  auto opBinary(string op:"^", VT) (in auto ref VT a) if (isVector!VT) { pragma(inline, true); return cross(a); }

  static if (dims == 2) {
    auto opBinary(string op:"%", VT) (VT.Float a) if (isVector!VT) { pragma(inline, true); return cross(a); }
    auto opBinary(string op:"^", VT) (VT.Float a) if (isVector!VT) { pragma(inline, true); return cross(a); }
  }

  auto opBinary(string op) (Float a) if (op == "+" || op == "-" || op == "*") {
    pragma(inline, true);
         static if (dims == 2) mixin("return v2(x"~op~"a, y"~op~"a);");
    else static if (dims == 3) mixin("return v3(x"~op~"a, y"~op~"a, z"~op~"a);");
    else static assert(0, "invalid dimension count for vector");
  }

  auto opBinaryRight(string op:"*") (Float a) {
    pragma(inline, true);
         static if (dims == 2) mixin("return v2(x"~op~"a, y"~op~"a);");
    else static if (dims == 3) mixin("return v3(x"~op~"a, y"~op~"a, z"~op~"a);");
    else static assert(0, "invalid dimension count for vector");
  }

  auto opBinary(string op:"/") (Float a) {
    pragma(inline, true);
    //import std.math : abs;
    //immutable Float a = (abs(aa) >= EPSILON!Float ? 1.0/aa : Float.nan);
    //immutable Float a = cast(Float)1/aa; // 1/0 == inf
    version(all/*vmath_slow_normalize*/) {
           static if (dims == 2) return v2(x/a, y/a);
      else static if (dims == 3) return v3(x/a, y/a, z/a);
      else static assert(0, "invalid dimension count for vector");
    } else {
      a = cast(Float)1/a; // 1/0 == inf
           static if (dims == 2) return v2(x*a, y*a);
      else static if (dims == 3) return v3(x*a, y*a, z*a);
      else static assert(0, "invalid dimension count for vector");
    }
  }

  auto opBinaryRight(string op:"/") (Float aa) {
    pragma(inline, true);
    /*
    import std.math : abs;
         static if (dims == 2) return v2((abs(x) >= EPSILON!Float ? aa/x : 0), (abs(y) >= EPSILON!Float ? aa/y : 0));
    else static if (dims == 3) return v3((abs(x) >= EPSILON!Float ? aa/x : 0), (abs(y) >= EPSILON!Float ? aa/y : 0), (abs(z) >= EPSILON!Float ? aa/z : 0));
    else static assert(0, "invalid dimension count for vector");
    */
         static if (dims == 2) return v2(aa/x, aa/y);
    else static if (dims == 3) return v3(aa/x, aa/y, aa/z);
    else static assert(0, "invalid dimension count for vector");
  }

  auto opUnary(string op:"+") () { pragma(inline, true); return this; }

  auto opUnary(string op:"-") () {
    pragma(inline, true);
         static if (dims == 2) return v2(-x, -y);
    else static if (dims == 3) return v3(-x, -y, -z);
    else static assert(0, "invalid dimension count for vector");
  }

  // this method performs the following triple product: (this x b) x c
  Me tripleProduct() (in auto ref Me b, in auto ref Me c) {
    alias a = this;
    static if (dims == 2) {
      // perform a.dot(c)
      immutable Float ac = a.x*c.x+a.y*c.y;
      // perform b.dot(c)
      immutable Float bc = b.x*c.x+b.y*c.y;
      // perform b * a.dot(c) - a * b.dot(c)
      return Me(
        b.x*ac-a.x*bc,
        b.y*ac-a.y*bc,
      );
    } else {
      // perform a.dot(c)
      immutable Float ac = a.x*c.x+a.y*c.y+a.z*c.z;
      // perform b.dot(c)
      immutable Float bc = b.x*c.x+b.y*c.y+b.z*c.z;
      // perform b * a.dot(c) - a * b.dot(c)
      return Me(
        b.x*ac-a.x*bc,
        b.y*ac-a.y*bc,
        b.z*ac-a.z*bc,
      );
    }
  }

  auto abs () {
    pragma(inline, true);
    mixin(ImportCoreMath!(Float, "fabs"));
         static if (dims == 2) return v2(fabs(x), fabs(y));
    else static if (dims == 3) return v3(fabs(x), fabs(y), fabs(z));
    else static assert(0, "invalid dimension count for vector");
  }

  auto sign () {
    pragma(inline, true);
         static if (dims == 2) return v2((x < 0 ? -1 : x > 0 ? 1 : 0), (y < 0 ? -1 : y > 0 ? 1 : 0));
    else static if (dims == 3) return v3((x < 0 ? -1 : x > 0 ? 1 : 0), (y < 0 ? -1 : y > 0 ? 1 : 0), (z < 0 ? -1 : z > 0 ? 1 : 0));
    else static assert(0, "invalid dimension count for vector");
  }

  // `this` is edge; see glsl reference
  auto step(VT) (in auto ref VT val) if (IsVector!VT) {
    pragma(inline, true);
         static if (dims == 2) return v2((val.x < this.x ? 0f : 1f), (val.y < this.y ? 0f : 1f));
    else static if (dims == 3) {
      static if (VT.Dims == 3) {
        return v3((val.x < this.x ? 0f : 1f), (val.y < this.y ? 0f : 1f), (val.z < this.z ? 0f : 1f));
      } else {
        return v3((val.x < this.x ? 0f : 1f), (val.y < this.y ? 0f : 1f), (0 < this.z ? 0f : 1f));
      }
    }
    else static assert(0, "invalid dimension count for vector");
  }

  bool opEquals(VT) (in auto ref VT a) if (isVector!VT) {
    pragma(inline, true);
         static if (dims == 2 && isVector2!VT) return (x == a.x && y == a.y);
    else static if (dims == 2 && isVector3!VT) return (x == a.x && y == a.y && a.z == 0);
    else static if (dims == 3 && isVector2!VT) return (x == a.x && y == a.y && z == 0);
    else static if (dims == 3 && isVector3!VT) return (x == a.x && y == a.y && z == a.z);
    else static assert(0, "invalid dimension count for vector");
  }

  // this dot a
  @property Float dot(VT) (in auto ref VT a) if (isVector!VT) {
    pragma(inline, true);
    static if (dims == 2) {
      return x*a.x+y*a.y;
    } else static if (dims == 3) {
           static if (isVector2!VT) return x*a.x+y*a.y;
      else static if (isVector3!VT) return x*a.x+y*a.y+z*a.z;
      else static assert(0, "invalid dimension count for vector");
    } else {
      static assert(0, "invalid dimension count for vector");
    }
  }

  // this cross a
  auto cross(VT) (in auto ref VT a) if (isVector!VT) {
    pragma(inline, true);
         static if (dims == 2 && isVector2!VT) return /*v3(0, 0, x*a.y-y*a.x)*/x*a.y-y*a.x;
    else static if (dims == 2 && isVector3!VT) return v3(y*a.z, -x*a.z, x*a.y-y*a.x);
    else static if (dims == 3 && isVector2!VT) return v3(-z*a.y, z*a.x, x*a.y-y*a.x);
    else static if (dims == 3 && isVector3!VT) return v3(y*a.z-z*a.y, z*a.x-x*a.z, x*a.y-y*a.x);
    else static assert(0, "invalid dimension count for vector");
  }

  // this*s; if you want s*this, do cross(-s)
  static if (dims == 2) auto cross (Float s) {
    pragma(inline, true);
    return Me(s*y, -s*x);
  }

  // compute Euler angles from direction vector (this) (with zero roll)
  auto hpr () {
    auto tmp = this.normalized;
    /*hpr.x = -atan2(tmp.x, tmp.y);
      hpr.y = -atan2(tmp.z, sqrt(tmp.x*tmp.x+tmp.y*tmp.y));*/
    static if (dims == 2) {
      mixin(ImportCoreMath!(double, "atan2"));
      return v2(
        cast(Float)(atan2(cast(double)tmp.x, cast(Float)0)),
        cast(Float)(-atan2(cast(double)tmp.y, cast(double)tmp.x)),
      );
    } else {
      mixin(ImportCoreMath!(double, "atan2", "sqrt"));
      return v3(
        cast(Float)(atan2(cast(double)tmp.x, cast(double)tmp.z)),
        cast(Float)(-atan2(cast(double)tmp.y, cast(double)sqrt(tmp.x*tmp.x+tmp.z*tmp.z))),
        0
      );
    }
  }

  // some more supplementary functions to support various things
  Float vcos(VT) (in auto ref VT v) if (isVector!VT) {
    immutable double len = length*v.length;
    return cast(Float)(len > EPSILON!Float ? cast(Float)(dot(v)/len) : cast(Float)0);
  }

  static if (dims == 2) Float vsin(VT) (in auto ref VT v) if (isVector!VT) {
    immutable double len = length*v.length;
    return cast(Float)(len > EPSILON!Float ? cast(Float)(cross(v)/len) : cast(Float)0);
  }

  static if (dims == 2) Float angle180(VT) (in auto ref VT v) if (isVector!VT) {
    import std.math : PI;
    mixin(ImportCoreMath!(Float, "atan"));
    immutable Float cosv = vcos(v);
    immutable Float sinv = vsin(v);
    if (cosv == 0) return (sinv <= 0 ? -90 : 90);
    if (sinv == 0) return (cosv <= 0 ? 180 : 0);
    Float angle = (cast(Float)180*atan(sinv/cosv))/cast(Float)PI;
    if (cosv < 0) { if (angle > 0) angle -= 180; else angle += 180; }
    return angle;
  }

  static if (dims == 2) Float angle360(VT) (in auto ref VT v) if (isVector!VT) {
    import std.math : PI;
    mixin(ImportCoreMath!(Float, "atan"));
    immutable Float cosv = vcos(v);
    immutable Float sinv = vsin(v);
    if (cosv == 0) return (sinv <= 0 ? 270 : 90);
    if (sinv == 0) return (cosv <= 0 ? 180 : 0);
    Float angle = (cast(Float)180*atan(sinv/cosv))/cast(Float)PI;
    if (cosv < 0) angle += 180;
    if (angle < 0) angle += 360;
    return angle;
  }

  Float relativeAngle(VT) (in auto ref VT v) if (isVector!VT) {
    import std.math : PI;
    mixin(ImportCoreMath!(Float, "acos"));
    immutable Float cosv = vcos(v);
    if (cosv <= -1) return PI;
    if (cosv >= 1) return 0;
    return acos(cosv);
  }

  bool touch(VT) (in auto ref VT v) if (isVector!VT) { pragma(inline, true); return (distance(v) < /*SMALL*/EPSILON!Float); }
  bool touch(VT) (in auto ref VT v, in Float epsilon) if (isVector!VT) { pragma(inline, true); return (distance(v) < epsilon); }

  // is `this` on left? (or on line)
  bool onLeft(VT) (in auto ref VT v0, in auto ref VT v1) if (isVector!VT) {
    pragma(inline, true);
    return ((v1-v0).cross(this-v0) <= 0);
  }

  static if (dims == 2) {
    // 2d stuff
    // test if a point (`this`) is left/on/right of an infinite 2D line
    // return:
    //   <0: on the right
    //   =0: on the line
    //   >0: on the left
    Float side(VT) (in auto ref VT v0, in auto ref VT v1) const if (isVector2!VT) {
      pragma(inline, true);
      return ((v1.x-v0.x)*(this.y-v0.y)-(this.x-v0.x)*(v1.y-v0.y));
    }
  }

  // is` this` inside?
  bool inside(VT) (in auto ref VT v0, in auto ref VT v1, in auto ref VT v2) if (isVector!VT) {
    if ((v1-v0).cross(this-v0) <= 0) return false;
    if ((v2-v1).cross(this-v1) <= 0) return false;
    return ((v0-v2).cross(this-v2) > 0);
  }

  // box2dlite port support
  static if (dims == 2) {
    // returns a perpendicular vector (90 degree rotation)
    auto perp() () { pragma(inline, true); return v2(-y, x); }

    // returns a perpendicular vector (-90 degree rotation)
    auto rperp() () { pragma(inline, true); return v2(y, -x); }

    // returns the vector projection of this onto v
    auto projectTo() (in auto ref v2 v) { pragma(inline, true); return v*(this.dot(v)/v.dot(v)); }

    // returns the unit length vector for the given angle (in radians)
    auto forAngle (in Float a) { pragma(inline, true); mixin(ImportCoreMath!(Float, "cos", "sin")); return v2(cos(a), sin(a)); }

    // returns the angular direction v is pointing in (in radians)
    Float toAngle() () { pragma(inline, true); mixin(ImportCoreMath!(Float, "atan2")); return atan2(y, x); }

    auto scross() (Float s) { pragma(inline, true); return v2(-s*y, s*x); }

    // returns the closest point to `this` on the line segment from `a` to `b`, or invalid vector
    // if `asseg` is false, "segment" is actually a line (infinite in both directions)
    Me projectToSeg(bool asseg=true) (in auto ref Me a, in auto ref Me b) {
      mixin(ImportCoreMath!(Float, "fabs"));
      alias p = this;
      immutable ab = b-a; // vector from a to b
      // squared distance from a to b
      immutable absq = ab.dot(ab);
      if (fabs(absq) < Epsilon) return a; // a and b are the same point (roughly)
      immutable ap = p-a; // vector from a to p
      immutable t = ap.dot(ab)/absq;
      static if (asseg) {
        if (t < 0) return a; // "before" a on the line
        if (t > 1) return b; // "after" b on the line
      }
      // projection lies "inbetween" a and b on the line
      return a+t*ab;
    }

    // returns the closest point to `this` on the line segment from `a` to `b`, or invalid vector
    // if `asseg` is false, "segment" is actually a line (infinite in both directions)
    Me projectToSegT(bool asseg=true) (in auto ref Me a, in auto ref Me b, ref Float rest) {
      mixin(ImportCoreMath!(Float, "fabs"));
      alias p = this;
      immutable ab = b-a; // vector from a to b
      // squared distance from a to b
      immutable absq = ab.dot(ab);
      if (fabs(absq) < Epsilon) { rest = 0; return a; } // a and b are the same point (roughly)
      immutable ap = p-a; // vector from a to p
      immutable t = ap.dot(ab)/absq;
      rest = t;
      static if (asseg) {
        if (t < 0) return a; // "before" a on the line
        if (t > 1) return b; // "after" b on the line
      }
      // projection lies "inbetween" a and b on the line
      return a+t*ab;
    }

    // returns `t` (normalized distance of projected point from `a`)
    Float projectToLineT() (in auto ref Me a, in auto ref Me b) {
      mixin(ImportCoreMath!(Float, "fabs"));
      alias p = this;
      immutable ab = b-a; // vector from a to b
      // squared distance from a to b
      immutable absq = ab.dot(ab);
      if (fabs(absq) < Epsilon) return cast(Float)0; // a and b are the same point (roughly)
      immutable ap = p-a; // vector from a to p
      return cast(Float)(ap.dot(ab)/absq);
    }
  }

  bool equals() (in auto ref Me v) {
    pragma(inline, true);
    mixin(ImportCoreMath!(Float, "fabs"));
         static if (dims == 2) return (fabs(x-v.x) < EPSILON!Float && fabs(y-v.y) < EPSILON!Float);
    else static if (dims == 3) return (fabs(x-v.x) < EPSILON!Float && fabs(y-v.y) < EPSILON!Float && fabs(z-v.z) < EPSILON!Float);
    else static assert(0, "invalid dimension count for vector");
  }


  // swizzling
  auto opDispatch(string fld) ()
  if ((dims == 2 && isGoodSwizzling!(fld, "xy", 2, 3)) ||
      (dims == 3 && isGoodSwizzling!(fld, "xyz", 2, 3)))
  {
    static if (fld.length == 2) {
      return mixin(SwizzleCtor!("v2", fld));
    } else {
      return mixin(SwizzleCtor!("v3", fld));
    }
  }

  static if (dims == 3) bool collinear() (in auto ref Me v1, in auto ref Me v2) {
    pragma(inline, true);
    mixin(ImportCoreMath!(Float, "fabs"));
    alias v0 = this;
    immutable Float cx = (v1.y-v0.y)*(v2.z-v0.z)-(v2.y-v0.y)*(v1.z-v0.z);
    immutable Float cy = (v2.x-v0.x)*(v1.z-v0.z)-(v1.x-v0.x)*(v2.z-v0.z);
    immutable Float cz = (v1.x-v0.x)*(v2.y-v0.y)-(v2.x-v0.x)*(v1.y-v0.y);
    return (fabs(cast(double)(cx*cx+cy*cy+cz*cz)) < EPSILON!double);
  }

  static if (dims == 2) bool collinear() (in auto ref Me v1, in auto ref Me v2) {
    pragma(inline, true);
    mixin(ImportCoreMath!(double, "fabs"));
    alias v0 = this;
    immutable Float det = cast(Float)((v0-v1)*(v0-v2)-(v0-v2)*(v0-v1));
    return (fabs(det) <= EPSILON!Float);
  }

  static if (dims == 2) {
    import std.range.primitives : isInputRange, ElementType;

    static auto vertRange (const(Me)[] varr) {
      static struct VertRange {
        const(Me)[] arr;
        usize pos;
      nothrow @trusted @nogc:
        @property bool empty () const pure { pragma(inline, true); return (pos >= arr.length); }
        @property Me front () const pure { pragma(inline, true); return (pos < arr.length ? arr.ptr[pos] : Me.Invalid); }
        void popFront () { pragma(inline, true); if (pos < arr.length) ++pos; }
        auto save () const pure { pragma(inline, true); return VertRange(arr, pos); }
      }
      return VertRange(varr, 0);
    }

    bool insidePoly(VR) (auto ref VR vr) const if (isInputRange!VR && is(ElementType!VR : const Me)) {
      if (vr.empty) return false;
      Me p1 = vr.front;
      vr.popFront();
      if (vr.empty) return false;
      Me p2 = vr.front;
      vr.popFront();
      if (vr.empty) return false; //TODO: check if p is ON the edge?
      alias p = this;
      int counter = 0;
      for (;;) {
        if (p.y > nmin(p1.y, p2.y)) {
          if (p.y <= nmax(p1.y, p2.y)) {
            if (p.x <= nmax(p1.x, p2.x)) {
              if (p1.y != p2.y) {
                auto xinters = (p.y-p1.y)*(p2.x-p1.x)/(p2.y-p1.y)+p1.x;
                if (p1.x == p2.x || p.x <= xinters) counter ^= 1;
              }
            }
          }
        }
        if (vr.empty) break;
        p1 = p2;
        p2 = vr.front;
        vr.popFront();
      }
      return (counter != 0);
    }

    bool insidePoly() (const(Me)[] poly) const { pragma(inline, true); return insidePoly(vertRange(poly)); }

    // gets the signed area
    // if the area is less than 0, it indicates that the polygon is clockwise winded
    Me.Float signedArea(VR) (auto ref VR vr) const if (isInputRange!VR && is(ElementType!VR : const Me)) {
      Me.Float area = 0;
      if (vr.empty) return area;
      Me p1 = vr.front;
      vr.popFront();
      if (vr.empty) return area;
      Me p2 = vr.front;
      vr.popFront();
      if (vr.empty) return area;
      Me pfirst = p1;
      for (;;) {
        area += p1.x*p2.y;
        area -= p1.y*p2.x;
        if (vr.empty) break;
        p1 = p2;
        p2 = vr.front;
        vr.popFront();
      }
      // last and first
      area += p2.x*pfirst.y;
      area -= p2.y*pfirst.x;
      return area/cast(VT.Float)2;
    }

    Me.Float signedArea() (const(Me)[] poly) const { pragma(inline, true); return signedArea(vertRange(poly)); }

    // indicates if the vertices are in counter clockwise order
    // warning: If the area of the polygon is 0, it is unable to determine the winding
    bool isCCW(VR) (auto ref VR vr) const if (isInputRange!VR && is(ElementType!VR : const Me)) { pragma(inline, true); return (signedArea(vr) > 0); }
    bool isCCW() (const(Me)[] poly) const { pragma(inline, true); return (signedArea(vertRange(poly)) > 0); }

    // *signed* area; can be used to check on which side `b` is
    static auto triSignedArea() (in auto ref Me a, in auto ref Me b, in auto ref Me c) {
      pragma(inline, true);
      return (b.x-a.x)*(c.y-a.y)-(c.x-a.x)*(b.y-a.y);
    }
  } // dims2

  static if (dims == 3) {
    // project this point to the given line
    Me projectToLine() (in auto ref Me p0, in auto ref Me p1) const {
      immutable Me d = p1-p0;
      immutable Me.Float t = d.dot(this-p0)/d.dot(d);
      if (tout !is null) *tout = t;
      return p0+d*t;
    }

    // return "time" of projection
    Me.Float projectToLineTime() (in auto ref Me p0, in auto ref Me p1) const {
      immutable Me d = p1-p0;
      return d.dot(this-p0)/d.dot(d);
    }

    // calculate triangle normal
    static Me triangleNormal() (in auto ref Me v0, in auto ref Me v1, in auto ref Me v2) {
      mixin(ImportCoreMath!(Me.Float, "fabs"));
      immutable Me cp = (v1-v0).cross(v2-v1);
      immutable Me.Float m = cp.length;
      return (fabs(m) > Epsilon ? cp*(cast(Me.Float)1/m) : Me.init);
    }

    // polygon must be convex, ccw, and without collinear vertices
    //FIXME: UNTESTED
    bool insideConvexPoly (const(Me)[] ply...) const @trusted {
      if (ply.length < 3) return false;
      immutable normal = triangleNormal(ply.ptr[0], ply.ptr[1], ply.ptr[2]);
      auto pidx = ply.length-1;
      for (typeof(pidx) cidx = 0; cidx < ply.length; pidx = cidx, ++cidx) {
        immutable pp1 = ply.ptr[pidx];
        immutable pp2 = ply.ptr[cidx];
        immutable side = (pp2-pp1).cross(this-pp1);
        if (normal.dot(side) < 0) return false;
      }
      return true;
    }
  }

static:
  // linearly interpolate between v1 and v2
  /*
  VT lerp(VT) (in auto ref VT v1, in auto ref VT v2, const Float t) if (isSameVector!VT) {
    pragma(inline, true);
    return (v1*cast(Float)1.0f-t)+(v2*t);
  }
  */

  static if (dims == 2) {
    Me lineIntersect() (in auto ref Me p1, in auto ref Me p2, in auto ref Me q1, in auto ref Me q2) {
      pragma(inline, true);
      mixin(ImportCoreMath!(Me.Float, "fabs"));
      immutable Me.Float a1 = p2.y-p1.y;
      immutable Me.Float b1 = p1.x-p2.x;
      immutable Me.Float c1 = a1*p1.x+b1*p1.y;
      immutable Me.Float a2 = q2.y-q1.y;
      immutable Me.Float b2 = q1.x-q2.x;
      immutable Me.Float c2 = a2*q1.x+b2*q1.y;
      immutable Me.Float det = a1*b2-a2*b1;
      if (fabs(det) > EPSILON!(Me.Float)) {
        // lines are not parallel
        immutable Me.Float invdet = cast(Me.Float)1/det;
        return Me((b2*c1-b1*c2)*invdet, (a1*c2-a2*c1)*invdet);
      }
      return Me.Invalid;
    }

    Me segIntersect(bool firstIsSeg=true, bool secondIsSeg=true) (in auto ref Me point0, in auto ref Me point1, in auto ref Me point2, in auto ref Me point3) {
      mixin(ImportCoreMath!(Me.Float, "fabs"));
      static if (firstIsSeg && secondIsSeg) {
        // fast aabb test for possible early exit
        if (nmax(point0.x, point1.x) < nmin(point2.x, point3.x) || nmax(point2.x, point3.x) < nmin(point0.x, point1.x)) return Me.Invalid;
        if (nmax(point0.y, point1.y) < nmin(point2.y, point3.y) || nmax(point2.y, point3.y) < nmin(point0.y, point1.y)) return Me.Invalid;
      }
      immutable Me.Float den = ((point3.y-point2.y)*(point1.x-point0.x))-((point3.x-point2.x)*(point1.y-point0.y));
      if (fabs(den) > EPSILON!(Me.Float)) {
        immutable Me.Float e = point0.y-point2.y;
        immutable Me.Float f = point0.x-point2.x;
        immutable Me.Float invden = cast(Me.Float)1/den;
        immutable Me.Float ua = (((point3.x-point2.x)*e)-((point3.y-point2.y)*f))*invden;
        static if (firstIsSeg) { if (ua < 0 || ua > 1) return Me.Invalid; }
        if (ua >= 0 && ua <= 1) {
          immutable Me.Float ub = (((point1.x-point0.x)*e)-((point1.y-point0.y)*f))*invden;
          static if (secondIsSeg) { if (ub < 0 || ub > 1) return Me.Invalid; }
          if (ua != 0 || ub != 0) return Me(point0.x+ua*(point1.x-point0.x), point0.y+ua*(point1.y-point0.y));
        }
      }
      return Me.Invalid;
    }

    // returns hittime; <0: no collision; 0: inside
    // WARNING! NOT REALLY TESTED, AND MAY BE INCORRECT!
    Me.Float sweepCircle() (in auto ref Me v0, in auto ref Me v1, in auto ref Me pos, Me.Float radii, in auto ref Me vel, ref Me hitp) {
      mixin(ImportCoreMath!(Me.Float, "fabs", "sqrt"));
      if (v0.equals(v1)) return (pos.distanceSquared(v0) <= radii*radii ? 0 : -1); // v0 and v1 are the same point; do "point inside circle" check
      immutable Me normal = (v1-v0).perp.normalized;
      immutable Me.Float D = -normal*((v0+v1)/2);
      immutable d0 = normal.dot(pos)+D;
      if (fabs(d0) <= radii) return cast(Me.Float)0; // inside
      // sweep to plane
      immutable p1 = pos+vel;
      immutable Me.Float d1 = normal.dot(p1)+D;
      if (d0 > radii && d1 < radii) {
        Me.Float t = (d0-radii)/(d0-d1); // normalized time
        hitp = pos+vel*t;
        // project hitp point to segment
        alias a = v0;
        alias b = v1;
        alias p = hitp;
        immutable ab = b-a; // vector from a to b
        // squared distance from a to b
        immutable absq = ab.dot(ab);
        //assert(absq != 0); // a and b are the same point
        if (fabs(absq) < Me.Epsilon) return -1; // a and b are the same point (roughly) -- SOMETHING IS VERY WRONG
        // t1 is projection "time" of p; [0..1]
        Me.Float t1 = (p-a).dot(ab)/absq; //a+t1*ab -- projected point
        // is "contact center" lies on the seg?
        if (t1 >= 0 && t1 <= 1) return t; // yes: this is clear hit
        // because i'm teh idiot, i'll just check ray-circle intersection for edge's capsue endpoints
        // ('cause if we'll turn edge into the capsule (v0,v1) with radius radii, we can use raycasting)
        // this is not entirely valid for segments much shorter than radius, but meh
        Me.Float ct1;
        immutable Me eco = (t1 < 0 ? a : b);
        immutable Me rpj = eco.projectToSegT!false(pos, p1, ct1);
        immutable Me.Float dsq = eco.distanceSquared(rpj);
        if (dsq >= radii*radii) return -1; // endpoint may be on sphere or out of it, this is not interesting
        immutable Me.Float dt = sqrt(radii*radii-dsq)/sqrt(vel.x*vel.x+vel.y*vel.y);
        t = ct1-fabs(dt);
        hitp = pos+t*vel;
        return t;
      }
      // no collision
      return -1;
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
// 2x2 matrix for fast 2D rotations and such
alias mat22 = Mat22!vec2;

align(1) struct Mat22(VT) if (IsVectorDim!(VT, 2)) {
align(1):
public:
  alias Float = VT.Float;
  alias mat22 = typeof(this);
  alias vec2 = VecN!(3, Float);
  alias Me = typeof(this);

nothrow @safe @nogc:
public:
  // default is "not rotated"
  vec2 col1 = vec2(1, 0);
  vec2 col2 = vec2(0, 1);

public:
  this (Float angle) { pragma(inline, true); set(angle); }

  void set (Float angle) {
    pragma(inline, true);
    mixin(ImportCoreMath!(Float, "cos", "sin"));
    immutable Float c = cos(angle), s = sin(angle);
    col1.x =  c; col1.y = s;
    col2.x = -s; col2.y = c;
  }

pure:
  this() (in auto ref vec2 acol1, in auto ref vec2 acol2) { pragma(inline, true); col1 = acol1; col2 = acol2; }

  static Me Identity () { pragma(inline, true); Me res; return res; }

  Me transpose () const { pragma(inline, true); return Me(vec2(col1.x, col2.x), vec2(col1.y, col2.y)); }

  Me invert () const @trusted {
    pragma(inline, true);
    immutable Float a = col1.x, b = col2.x, c = col1.y, d = col2.y;
    Me bm = void;
    Float det = a*d-b*c;
    assert(det != cast(Float)0);
    det = cast(Float)1/det;
    bm.col1.x = det*d;
    bm.col2.x = -det*b;
    bm.col1.y = -det*c;
    bm.col2.y = det*a;
    return bm;
  }

  Me opUnary(string op:"+") () const { pragma(inline, true); return this; }
  Me opUnary(string op:"-") () const { pragma(inline, true); return Me(-col1, -col2); }

  vec2 opBinary(string op:"*") (in auto ref vec2 v) const { pragma(inline, true); return vec2(col1.x*v.x+col2.x*v.y, col1.y*v.x+col2.y*v.y); }
  vec2 opBinaryRight(string op:"*") (in auto ref vec2 v) const { pragma(inline, true); return vec2(col1.x*v.x+col2.x*v.y, col1.y*v.x+col2.y*v.y); }

  Me opBinary(string op:"*") (Float s) const { pragma(inline, true); return Me(vec2(col1*s, col2*s)); }
  Me opBinaryRight(string op:"*") (Float s) const { pragma(inline, true); return Me(vec2(col1*s, col2*s)); }

  Me opBinary(string op) (in auto ref Me bm) const if (op == "+" || op == "-") { pragma(inline, true); mixin("return Me(col1"~op~"bm.col1, col2"~op~"bm.col2);"); }
  Me opBinary(string op:"*") (in auto ref Me bm) const { pragma(inline, true); return Me(this*bm.col1, this*bm.col2); }

  ref Me opOpAssign(string op) (in auto ref Me bm) if (op == "+" || op == "-") { pragma(inline, true); mixin("col1 "~op~"= bm.col1;"); mixin("col2 "~op~"= bm.col2;"); return this; }

  ref Me opOpAssign(string op:"*") (Float s) const { pragma(inline, true); col1 *= s; col2 *= s; }

  Me abs() () { pragma(inline, true); return Me(col1.abs, col2.abs); }

  // solves the system of linear equations: Ax = b
  vec2 solve() (in auto ref vec2 v) const {
    immutable Float a = col1.x, b = col2.x, c = col1.y, d = col2.y;
    Float det = a*d-b*c;
    assert(det != cast(Float)0);
    det = cast(Float)1/det;
    return vec2((d*v.x-b*v.y)*det, (a*v.y-c*v.x)*det);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
alias mat3 = Mat3!vec2; /// for 2D
alias mat33 = Mat3!vec3; /// for 3D

/// very simple (and mostly not tested) 3x3 matrix, for 2D/3D (depenting of parameterizing vector type)
/// for 3D, 3x3 matrix cannot do translation
align(1) struct Mat3(VT) if (IsVectorDim!(VT, 2) || IsVectorDim!(VT, 3)) {
align(1):
private:
  alias Float = VT.Float;
  alias m3 = typeof(this);
  static if (VT.Dims == 2) {
    alias v2 = VT;
    enum TwoD = true;
    enum ThreeD = false;
    enum isVector2(VT) = is(VT == VecN!(2, Float));
  } else {
    alias v3 = VT;
    enum TwoD = false;
    enum ThreeD = true;
    enum isVector3(VT) = is(VT == VecN!(3, Float));
  }

private:
  // 3x3 matrix components
  Float[3*3] m = [
    1, 0, 0,
    0, 1, 0,
    0, 0, 1,
  ];

public:
  string toString () const nothrow @trusted {
    import std.string : format;
    try {
      return "0:[%g,%g,%g]\n3:[%g,%g,%g]\n6:[%g,%g,%g]".format(
        m.ptr[0], m.ptr[1], m.ptr[2],
        m.ptr[3], m.ptr[4], m.ptr[5],
        m.ptr[6], m.ptr[7], m.ptr[8],
      );
    } catch (Exception) {
      assert(0);
    }
  }

public:
nothrow @trusted @nogc:
  this (const(Float)[] vals...) {
    pragma(inline, true);
    if (vals.length >= 3*3) {
      m.ptr[0..9] = vals.ptr[0..9];
    } else {
      // so `m3(1)`, for example, will create matrix filled with `1`
      if (vals.length == 1) {
        m.ptr[0..9] = vals.ptr[0];
      } else {
        // still clear the matrix
        m.ptr[0..9] = 0;
        m.ptr[0..vals.length] = vals[];
      }
    }
  }

  this() (in auto ref m3 mt) {
    pragma(inline, true);
    m[] = mt.m[];
  }

  Float opIndex (usize x, usize y) const {
    pragma(inline, true);
    return (x < 3 && y < 3 ? m.ptr[y*3+x] : Float.nan);
  }

  void opIndexAssign (Float v, usize x, usize y) {
    pragma(inline, true);
    if (x < 3 && y < 3) m.ptr[y*3+x] = v;
  }

  @property bool isIdentity () const {
    pragma(inline, true); // can we?
    return
      m.ptr[0] == 1 && m.ptr[1] == 0 && m.ptr[2] == 0 &&
      m.ptr[3] == 0 && m.ptr[4] == 1 && m.ptr[5] == 0 &&
      m.ptr[6] == 0 && m.ptr[7] == 0 && m.ptr[8] == 1;
  }

  auto opUnary(string op:"+") () const { pragma(inline, true); return this; }

  auto opUnary(string op:"-") () const {
    pragma(inline, true);
    return m3(
      -m.ptr[0], -m.ptr[1], -m.ptr[2],
      -m.ptr[3], -m.ptr[4], -m.ptr[5],
      -m.ptr[6], -m.ptr[7], -m.ptr[8],
    );
  }

  auto opBinary(string op) (in auto ref m3 b) const if (op == "+" || op == "-") {
    pragma(inline, true);
    m3 res = void;
    mixin("res.m.ptr[0] = m.ptr[0]"~op~"b.m.ptr[0];");
    mixin("res.m.ptr[1] = m.ptr[1]"~op~"b.m.ptr[1];");
    mixin("res.m.ptr[2] = m.ptr[2]"~op~"b.m.ptr[2];");
    mixin("res.m.ptr[3] = m.ptr[3]"~op~"b.m.ptr[3];");
    mixin("res.m.ptr[4] = m.ptr[4]"~op~"b.m.ptr[4];");
    mixin("res.m.ptr[5] = m.ptr[5]"~op~"b.m.ptr[5];");
    mixin("res.m.ptr[6] = m.ptr[6]"~op~"b.m.ptr[6];");
    mixin("res.m.ptr[7] = m.ptr[7]"~op~"b.m.ptr[7];");
    mixin("res.m.ptr[8] = m.ptr[8]"~op~"b.m.ptr[8];");
    return m3;
  }

  ref auto opOpAssign(string op) (in auto ref m3 b) if (op == "+" || op == "-") {
    pragma(inline, true);
    mixin("m.ptr[0]"~op~"=b.m.ptr[0]; m.ptr[1]"~op~"=b.m.ptr[1]; m.ptr[2]"~op~"=b.m.ptr[2];");
    mixin("m.ptr[3]"~op~"=b.m.ptr[3]; m.ptr[4]"~op~"=b.m.ptr[4]; m.ptr[5]"~op~"=b.m.ptr[5];");
    mixin("m.ptr[6]"~op~"=b.m.ptr[6]; m.ptr[7]"~op~"=b.m.ptr[7]; m.ptr[8]"~op~"=b.m.ptr[8];");
    return this;
  }

  auto opBinary(string op) (in Float b) const if (op == "*" || op == "/") {
    pragma(inline, true);
    m3 res = void;
    mixin("res.m.ptr[0] = m.ptr[0]"~op~"b;");
    mixin("res.m.ptr[1] = m.ptr[1]"~op~"b;");
    mixin("res.m.ptr[2] = m.ptr[2]"~op~"b;");
    mixin("res.m.ptr[3] = m.ptr[3]"~op~"b;");
    mixin("res.m.ptr[4] = m.ptr[4]"~op~"b;");
    mixin("res.m.ptr[5] = m.ptr[5]"~op~"b;");
    mixin("res.m.ptr[6] = m.ptr[6]"~op~"b;");
    mixin("res.m.ptr[7] = m.ptr[7]"~op~"b;");
    mixin("res.m.ptr[8] = m.ptr[8]"~op~"b;");
    return res;
  }

  auto opBinaryRight(string op) (in Float b) const if (op == "*" || op == "/") {
    pragma(inline, true);
    m3 res = void;
    mixin("res.m.ptr[0] = m.ptr[0]"~op~"b;");
    mixin("res.m.ptr[1] = m.ptr[1]"~op~"b;");
    mixin("res.m.ptr[2] = m.ptr[2]"~op~"b;");
    mixin("res.m.ptr[3] = m.ptr[3]"~op~"b;");
    mixin("res.m.ptr[4] = m.ptr[4]"~op~"b;");
    mixin("res.m.ptr[5] = m.ptr[5]"~op~"b;");
    mixin("res.m.ptr[6] = m.ptr[6]"~op~"b;");
    mixin("res.m.ptr[7] = m.ptr[7]"~op~"b;");
    mixin("res.m.ptr[8] = m.ptr[8]"~op~"b;");
    return res;
  }

  ref auto opOpAssign(string op) (in Float b) if (op == "*" || op == "/") {
    pragma(inline, true);
    mixin("m.ptr[0]"~op~"=b; m.ptr[1]"~op~"=b; m.ptr[2]"~op~"=b;");
    mixin("m.ptr[3]"~op~"=b; m.ptr[4]"~op~"=b; m.ptr[5]"~op~"=b;");
    mixin("m.ptr[6]"~op~"=b; m.ptr[7]"~op~"=b; m.ptr[8]"~op~"=b;");
    return this;
  }

  static if (TwoD) auto opBinary(string op:"*") (in auto ref v2 v) const {
    pragma(inline, true);
    return v2(
      v.x*m.ptr[3*0+0]+v.y*m.ptr[3*1+0]+m.ptr[3*2+0],
      v.x*m.ptr[3*0+1]+v.y*m.ptr[3*1+1]+m.ptr[3*2+1],
    );
  }

  static if (ThreeD) auto opBinary(string op:"*") (in auto ref v3 v) const {
    pragma(inline, true);
    return v3(
      v.x*m.ptr[3*0+0]+v.y*m.ptr[3*1+0]+v.z*m.ptr[3*2+0],
      v.x*m.ptr[3*0+1]+v.y*m.ptr[3*1+1]+v.z*m.ptr[3*2+1],
      v.x*m.ptr[3*0+2]+v.y*m.ptr[3*1+2]+v.z*m.ptr[3*2+2],
    );
  }

  static if (TwoD) auto opBinaryRight(string op:"*") (in auto ref v2 v) const { pragma(inline, true); return this*v; }
  static if (ThreeD) auto opBinaryRight(string op:"*") (in auto ref v3 v) const { pragma(inline, true); return this*v; }

  auto opBinary(string op:"*") (in auto ref m3 b) const {
    //pragma(inline, true);
    m3 res = void;
    res.m.ptr[3*0+0] = m.ptr[3*0+0]*b.m.ptr[3*0+0]+m.ptr[3*0+1]*b.m.ptr[3*1+0]+m.ptr[3*0+2]*b.m.ptr[3*2+0];
    res.m.ptr[3*0+1] = m.ptr[3*0+0]*b.m.ptr[3*0+1]+m.ptr[3*0+1]*b.m.ptr[3*1+1]+m.ptr[3*0+2]*b.m.ptr[3*2+1];
    res.m.ptr[3*0+2] = m.ptr[3*0+0]*b.m.ptr[3*0+2]+m.ptr[3*0+1]*b.m.ptr[3*1+2]+m.ptr[3*0+2]*b.m.ptr[3*2+2];
    res.m.ptr[3*1+0] = m.ptr[3*1+0]*b.m.ptr[3*0+0]+m.ptr[3*1+1]*b.m.ptr[3*1+0]+m.ptr[3*1+2]*b.m.ptr[3*2+0];
    res.m.ptr[3*1+1] = m.ptr[3*1+0]*b.m.ptr[3*0+1]+m.ptr[3*1+1]*b.m.ptr[3*1+1]+m.ptr[3*1+2]*b.m.ptr[3*2+1];
    res.m.ptr[3*1+2] = m.ptr[3*1+0]*b.m.ptr[3*0+2]+m.ptr[3*1+1]*b.m.ptr[3*1+2]+m.ptr[3*1+2]*b.m.ptr[3*2+2];
    res.m.ptr[3*2+0] = m.ptr[3*2+0]*b.m.ptr[3*0+0]+m.ptr[3*2+1]*b.m.ptr[3*1+0]+m.ptr[3*2+2]*b.m.ptr[3*2+0];
    res.m.ptr[3*2+1] = m.ptr[3*2+0]*b.m.ptr[3*0+1]+m.ptr[3*2+1]*b.m.ptr[3*1+1]+m.ptr[3*2+2]*b.m.ptr[3*2+1];
    res.m.ptr[3*2+2] = m.ptr[3*2+0]*b.m.ptr[3*0+2]+m.ptr[3*2+1]*b.m.ptr[3*1+2]+m.ptr[3*2+2]*b.m.ptr[3*2+2];
    return res;
  }

  // multiply vector by transposed matrix (TESTME!)
  static if (ThreeD) auto transmul() (in auto ref v3 v) const {
    pragma(inline, true);
    return v3(
      v.x*m.ptr[3*0+0]+v.y*m.ptr[3*0+1]+v.z*m.ptr[3*0+2],
      v.x*m.ptr[3*1+0]+v.y*m.ptr[3*1+1]+v.z*m.ptr[3*1+2],
      v.x*m.ptr[3*2+0]+v.y*m.ptr[3*2+1]+v.z*m.ptr[3*2+2],
    );
  }

  // sum of the diagonal components
  Float trace () const { pragma(inline, true); return m.ptr[3*0+0]+m.ptr[3*1+1]+m.ptr[3*2+2]; }

  // determinant
  Float det () const {
    pragma(inline, true);
    Float res = 0;
    res += m.ptr[3*0+0]*(m.ptr[3*1+1]*m.ptr[3*2+2]-m.ptr[3*2+1]*m.ptr[3*1+2]);
    res -= m.ptr[3*0+1]*(m.ptr[3*1+0]*m.ptr[3*2+2]-m.ptr[3*2+0]*m.ptr[3*1+2]);
    res += m.ptr[3*0+2]*(m.ptr[3*1+0]*m.ptr[3*2+1]-m.ptr[3*2+0]*m.ptr[3*1+1]);
    return res;
  }

  auto transposed () const {
    pragma(inline, true);
    m3 res;
    res.m.ptr[3*0+0] = m.ptr[3*0+0];
    res.m.ptr[3*0+1] = m.ptr[3*1+0];
    res.m.ptr[3*0+2] = m.ptr[3*2+0];
    res.m.ptr[3*1+0] = m.ptr[3*0+1];
    res.m.ptr[3*1+1] = m.ptr[3*1+1];
    res.m.ptr[3*1+2] = m.ptr[3*2+1];
    res.m.ptr[3*2+0] = m.ptr[3*0+2];
    res.m.ptr[3*2+1] = m.ptr[3*1+2];
    res.m.ptr[3*2+2] = m.ptr[3*2+2];
    return res;
  }

  auto inv () const {
    //pragma(inline, true);
    immutable mtp = this.transposed;
    m3 res = void;

    res.m.ptr[3*0+0] = mtp.m.ptr[3*1+1]*mtp.m.ptr[3*2+2]-mtp.m.ptr[3*2+1]*mtp.m.ptr[3*1+2];
    res.m.ptr[3*0+1] = mtp.m.ptr[3*1+0]*mtp.m.ptr[3*2+2]-mtp.m.ptr[3*2+0]*mtp.m.ptr[3*1+2];
    res.m.ptr[3*0+2] = mtp.m.ptr[3*1+0]*mtp.m.ptr[3*2+1]-mtp.m.ptr[3*2+0]*mtp.m.ptr[3*1+1];
    res.m.ptr[3*1+0] = mtp.m.ptr[3*0+1]*mtp.m.ptr[3*2+2]-mtp.m.ptr[3*2+1]*mtp.m.ptr[3*0+2];
    res.m.ptr[3*1+1] = mtp.m.ptr[3*0+0]*mtp.m.ptr[3*2+2]-mtp.m.ptr[3*2+0]*mtp.m.ptr[3*0+2];
    res.m.ptr[3*1+2] = mtp.m.ptr[3*0+0]*mtp.m.ptr[3*2+1]-mtp.m.ptr[3*2+0]*mtp.m.ptr[3*0+1];
    res.m.ptr[3*2+0] = mtp.m.ptr[3*0+1]*mtp.m.ptr[3*1+2]-mtp.m.ptr[3*1+1]*mtp.m.ptr[3*0+2];
    res.m.ptr[3*2+1] = mtp.m.ptr[3*0+0]*mtp.m.ptr[3*1+2]-mtp.m.ptr[3*1+0]*mtp.m.ptr[3*0+2];
    res.m.ptr[3*2+2] = mtp.m.ptr[3*0+0]*mtp.m.ptr[3*1+1]-mtp.m.ptr[3*1+0]*mtp.m.ptr[3*0+1];

    res.m.ptr[3*0+1] *= -1;
    res.m.ptr[3*1+0] *= -1;
    res.m.ptr[3*1+2] *= -1;
    res.m.ptr[3*2+1] *= -1;

    return res/this.det;
  }

  static if (ThreeD) {
    ref m3 rotateX (Float angle) {
      mixin(ImportCoreMath!(Float, "cos", "sin"));
      alias A = this;

      // get the sine and cosine of the rotation angle
      immutable Float s = sin(angle);
      immutable Float c = cos(angle);

      // calculate the new values of the six affected matrix entries
      immutable Float temp01 = c*A[0, 1]+s*A[0, 2];
      immutable Float temp11 = c*A[1, 1]+s*A[1, 2];
      immutable Float temp21 = c*A[2, 1]+s*A[2, 2];
      immutable Float temp02 = c*A[0, 2]-s*A[0, 1];
      immutable Float temp12 = c*A[1, 2]-s*A[1, 1];
      immutable Float temp22 = c*A[2, 2]-s*A[2, 1];

      // put the results back into A
      A[0, 1] = temp01; A[0, 2] = temp02;
      A[1, 1] = temp11; A[1, 2] = temp12;
      A[2, 1] = temp21; A[2, 2] = temp22;

      return this;
    }

    ref m3 rotateY (Float angle) {
      mixin(ImportCoreMath!(Float, "cos", "sin"));
      alias A = this;

      // get the sine and cosine of the rotation angle
      immutable Float s = sin(angle);
      immutable Float c = cos(angle);

      // calculate the new values of the six affected matrix entries
      immutable Float temp00 = c*A[0, 0]+s*A[0, 2];
      immutable Float temp10 = c*A[1, 0]+s*A[1, 2];
      immutable Float temp20 = c*A[2, 0]+s*A[2, 2];
      immutable Float temp02 = c*A[0, 2]-s*A[0, 0];
      immutable Float temp12 = c*A[1, 2]-s*A[1, 0];
      immutable Float temp22 = c*A[2, 2]-s*A[2, 0];

      // put the results back into XformToChange
      A[0, 0] = temp00; A[0, 2] = temp02;
      A[1, 0] = temp10; A[1, 2] = temp12;
      A[2, 0] = temp20; A[2, 2] = temp22;

      return this;
    }

    ref m3 rotateZ (Float angle) {
      import core.stdc.math : cos, sin;
      alias A = this;

      // get the sine and cosine of the rotation angle
      immutable Float s = sin(angle);
      immutable Float c = cos(angle);

      // calculate the new values of the six affected matrix entries
      immutable Float temp00 = c*A[0, 0]+s*A[0, 1];
      immutable Float temp10 = c*A[1, 0]+s*A[1, 1];
      immutable Float temp20 = c*A[2, 0]+s*A[2, 1];
      immutable Float temp01 = c*A[0, 1]-s*A[0, 0];
      immutable Float temp11 = c*A[1, 1]-s*A[1, 0];
      immutable Float temp21 = c*A[2, 1]-s*A[2, 0];

      // put the results back into XformToChange
      A[0, 0] = temp00; A[0, 1] = temp01;
      A[1, 0] = temp10; A[1, 1] = temp11;
      A[2, 0] = temp20; A[2, 1] = temp21;

      return this;
    }
  }

static:
  auto Identity () { pragma(inline, true); return m3(); }
  auto Zero () { pragma(inline, true); return m3(0); }

  static if (TwoD) {
    auto Rotate (in Float angle) {
      pragma(inline, true);
      mixin(ImportCoreMath!(Float, "cos", "sin"));
      immutable Float c = cos(angle);
      immutable Float s = sin(angle);
      m3 res;
      res.m.ptr[3*0+0] =  c; res.m.ptr[3*0+1] = s;
      res.m.ptr[3*1+0] = -s; res.m.ptr[3*1+1] = c;
      return res;
    }

    auto Scale (in Float sx, in Float sy) {
      pragma(inline, true);
      m3 res;
      res.m.ptr[3*0+0] = sx;
      res.m.ptr[3*1+1] = sy;
      return res;
    }

    auto Scale() (in auto ref v2 sc) {
      pragma(inline, true);
      m3 res;
      res.m.ptr[3*0+0] = sc.x;
      res.m.ptr[3*1+1] = sc.y;
      return res;
    }

    auto Translate (in Float dx, in Float dy) {
      pragma(inline, true);
      m3 res;
      res.m.ptr[3*2+0] = dx;
      res.m.ptr[3*2+1] = dy;
      return res;
    }

    auto Translate() (in auto ref v2 v) {
      pragma(inline, true);
      m3 res;
      res.m.ptr[3*2+0] = v.x;
      res.m.ptr[3*2+1] = v.y;
      return res;
    }
  }

  static if (ThreeD) {
    // make rotation matrix from given angles
    static auto Rotate() (in auto ref v3 angles) {
      mixin(ImportCoreMath!(Float, "cos", "sin"));

      immutable Float cos_b = cos(angles[0]);
      immutable Float sin_b = sin(angles[0]);
      immutable Float cos_c = cos(angles[1]);
      immutable Float sin_c = sin(angles[1]);
      immutable Float cos_a = cos(angles[2]);
      immutable Float sin_a = sin(angles[2]);

      m3 M = void;

      // first matrix row
      M[0, 0] = cos_a*cos_c-sin_a*sin_b*sin_c;
      M[0, 1] = sin_a*cos_c+cos_a*sin_b*sin_c;
      M[0, 2] = cos_b*sin_c;

      // second matrix row
      M[1, 0] = -sin_a*cos_b;
      M[1, 1] = cos_a*cos_b;
      M[1, 2] = -sin_b;

      // third matrix row
      M[2, 0] = -cos_a*sin_c-sin_a*sin_b*cos_c;
      M[2, 1] = -sin_a*sin_c+cos_a*sin_b*cos_c;
      M[2, 2] = cos_b*cos_c;

      return M;
    }

    static auto RotateX() (Float angle) {
      m3 res;
      res.rotateX(angle);
      return res;
    }

    static auto RotateY() (Float angle) {
      m3 res;
      res.rotateY(angle);
      return res;
    }

    static auto RotateZ() (Float angle) {
      m3 res;
      res.rotateZ(angle);
      return res;
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
alias mat4 = Mat4!vec3;

align(1) struct Mat4(VT) if (IsVectorDim!(VT, 3)) {
align(1):
public:
  alias Float = VT.Float;
  alias mat4 = typeof(this);
  alias vec3 = VecN!(3, Float);

public:
  // OpenGL-compatible, row by row
  Float[4*4] mt = [
    1, 0, 0, 0,
    0, 1, 0, 0,
    0, 0, 1, 0,
    0, 0, 0, 1,
  ];

nothrow @safe:
  string toString () const @trusted {
    import std.string : format;
    try {
      return "0:[%g,%g,%g,%g]\n4:[%g,%g,%g,%g]\n8:[%g,%g,%g,%g]\nc:[%g,%g,%g,%g]".format(
        mt.ptr[ 0], mt.ptr[ 1], mt.ptr[ 2], mt.ptr[ 3],
        mt.ptr[ 4], mt.ptr[ 5], mt.ptr[ 6], mt.ptr[ 7],
        mt.ptr[ 8], mt.ptr[ 9], mt.ptr[10], mt.ptr[11],
        mt.ptr[12], mt.ptr[13], mt.ptr[14], mt.ptr[15],
      );
    } catch (Exception) {
      assert(0);
    }
  }

  Float opIndex (usize x, usize y) const @trusted @nogc { pragma(inline, true); return (x < 4 && y < 4 ? mt.ptr[y*4+x] : Float.nan); }
  void opIndexAssign (Float v, usize x, usize y) @trusted @nogc { pragma(inline, true); if (x < 4 && y < 4) mt.ptr[y*4+x] = v; }

@nogc @trusted:
  this() (in Float[] vals...) { pragma(inline, true); if (vals.length >= 16) mt.ptr[0..16] = vals.ptr[0..16]; else { mt.ptr[0..16] = 0; mt.ptr[0..vals.length] = vals.ptr[0..vals.length]; } }
  this() (in auto ref mat4 m) { pragma(inline, true); mt.ptr[0..16] = m.mt.ptr[0..16]; }
  this() (in auto ref vec3 v) {
    //mt.ptr[0..16] = 0;
    mt.ptr[0*4+0] = v.x;
    mt.ptr[1*4+1] = v.y;
    mt.ptr[2*4+2] = v.z;
    //mt.ptr[3*4+3] = 1; // just in case
  }

  static mat4 Zero () { pragma(inline, true); return mat4(0); }
  static mat4 Identity () { pragma(inline, true); /*mat4 res = Zero; res.mt.ptr[0*4+0] = res.mt.ptr[1*4+1] = res.mt.ptr[2*4+2] = res.mt.ptr[3*4+3] = 1; return res;*/ return mat4(); }

  // multiply current OpenGL matrix with this one
  // templated, to not compile it if we won't use it
  void glMultiply() () const {
    pragma(inline, true);
    import iv.glbinds;
    static if (is(Float == float)) {
      glMultMatrixf(mt.ptr);
    } else {
      glMultMatrixd(mt.ptr);
    }
  }

  static mat4 GLRetrieveAny() (uint mode) nothrow @trusted @nogc {
    pragma(inline, true);
    import iv.glbinds;
    mat4 res = void;
    static if (is(Float == float)) {
      glGetFloatv(mode, res.mt.ptr);
    } else {
      glGetDoublev(mode, res.mt.ptr);
    }
    return res;
  }

  static mat4 GLRetrieveModelView() () nothrow @trusted @nogc { pragma(inline, true); import iv.glbinds; return GLRetrieveAny(GL_MODELVIEW_MATRIX); }
  static mat4 GLRetrieveProjection() () nothrow @trusted @nogc { pragma(inline, true); import iv.glbinds; return GLRetrieveAny(GL_PROJECTION_MATRIX); }
  static mat4 GLRetrieveTexture() () nothrow @trusted @nogc { pragma(inline, true); import iv.glbinds; return GLRetrieveAny(GL_TEXTURE_MATRIX); }
  static mat4 GLRetrieveColor() () nothrow @trusted @nogc { pragma(inline, true); import iv.glbinds; return GLRetrieveAny(GL_COLOR_MATRIX); }

  void glRetrieveAny() (uint mode) nothrow @trusted @nogc {
    pragma(inline, true);
    import iv.glbinds;
    static if (is(Float == float)) {
      glGetFloatv(mode, mt.ptr);
    } else {
      glGetDoublev(mode, mt.ptr);
    }
  }

  void glRetrieveModelView() () nothrow @trusted @nogc { pragma(inline, true); import iv.glbinds; glRetrieveAny(GL_MODELVIEW_MATRIX); }
  void glRetrieveProjection() () nothrow @trusted @nogc { pragma(inline, true); import iv.glbinds; glRetrieveAny(GL_PROJECTION_MATRIX); }
  void glRetrieveTexture() () nothrow @trusted @nogc { pragma(inline, true); import iv.glbinds; glRetrieveAny(GL_TEXTURE_MATRIX); }
  void glRetrieveColor() () nothrow @trusted @nogc { pragma(inline, true); import iv.glbinds; glRetrieveAny(GL_COLOR_MATRIX); }

  @property bool isIdentity () const {
    pragma(inline, true); // can we?
    return
      mt.ptr[0] == 1 && mt.ptr[1] == 0 && mt.ptr[2] == 0 && mt.ptr[3] == 0 &&
      mt.ptr[4] == 0 && mt.ptr[5] == 1 && mt.ptr[6] == 0 && mt.ptr[7] == 0 &&
      mt.ptr[8] == 0 && mt.ptr[9] == 0 && mt.ptr[10] == 1 && mt.ptr[11] == 0 &&
      mt.ptr[12] == 0 && mt.ptr[13] == 0 && mt.ptr[14] == 0 && mt.ptr[15] == 1;
  }

  @property inout(Float)* glGetVUnsafe () inout nothrow @trusted @nogc { pragma(inline, true); return cast(typeof(return))mt.ptr; }

  Float[4] getRow (int idx) const {
    Float[4] res = Float.nan;
    switch (idx) {
      case 0:
        res.ptr[0] = mt.ptr[0];
        res.ptr[1] = mt.ptr[4];
        res.ptr[2] = mt.ptr[8];
        res.ptr[3] = mt.ptr[12];
        break;
      case 1:
        res.ptr[0] = mt.ptr[1];
        res.ptr[1] = mt.ptr[5];
        res.ptr[2] = mt.ptr[9];
        res.ptr[3] = mt.ptr[13];
        break;
      case 2:
        res.ptr[0] = mt.ptr[2];
        res.ptr[1] = mt.ptr[6];
        res.ptr[2] = mt.ptr[10];
        res.ptr[3] = mt.ptr[14];
        break;
      case 3:
        res.ptr[0] = mt.ptr[3];
        res.ptr[1] = mt.ptr[7];
        res.ptr[2] = mt.ptr[11];
        res.ptr[3] = mt.ptr[15];
        break;
      default: break;
    }
    return res;
  }

  Float[4] getCol (int idx) const {
    Float[4] res = Float.nan;
    if (idx >= 0 && idx <= 3) res = mt.ptr[idx*4..idx*5];
    return res;
  }

  // this is for camera matrices
  vec3 upVector () const { pragma(inline, true); return vec3(mt.ptr[1], mt.ptr[5], mt.ptr[9]); }
  vec3 rightVector () const { pragma(inline, true); return vec3(mt.ptr[0], mt.ptr[4], mt.ptr[8]); }
  vec3 forwardVector () const { pragma(inline, true); return vec3(mt.ptr[2], mt.ptr[6], mt.ptr[10]); }

  private enum SinCosImportMixin = q{
    static if (is(Float == float)) {
      import core.stdc.math : cos=cosf, sin=sinf;
    } else {
      import core.stdc.math : cos, sin;
    }
  };

  static mat4 RotateX() (Float angle) {
    mixin(SinCosImportMixin);
    auto res = mat4(0);
    res.mt.ptr[0*4+0] = cast(Float)1;
    res.mt.ptr[1*4+1] = cos(angle);
    res.mt.ptr[2*4+1] = -sin(angle);
    res.mt.ptr[1*4+2] = sin(angle);
    res.mt.ptr[2*4+2] = cos(angle);
    res.mt.ptr[3*4+3] = cast(Float)1;
    return res;
  }

  static mat4 RotateY() (Float angle) {
    mixin(SinCosImportMixin);
    auto res = mat4(0);
    res.mt.ptr[0*4+0] = cos(angle);
    res.mt.ptr[2*4+0] = sin(angle);
    res.mt.ptr[1*4+1] = cast(Float)1;
    res.mt.ptr[0*4+2] = -sin(angle);
    res.mt.ptr[2*4+2] = cos(angle);
    res.mt.ptr[3*4+3] = cast(Float)1;
    return res;
  }

  static mat4 RotateZ() (Float angle) {
    mixin(SinCosImportMixin);
    auto res = mat4(0);
    res.mt.ptr[0*4+0] = cos(angle);
    res.mt.ptr[1*4+0] = -sin(angle);
    res.mt.ptr[0*4+1] = sin(angle);
    res.mt.ptr[1*4+1] = cos(angle);
    res.mt.ptr[2*4+2] = cast(Float)1;
    res.mt.ptr[3*4+3] = cast(Float)1;
    return res;
  }

  static mat4 Translate() (in auto ref vec3 v) {
    auto res = mat4(0);
    res.mt.ptr[0*4+0] = res.mt.ptr[1*4+1] = res.mt.ptr[2*4+2] = 1;
    res.mt.ptr[3*4+0] = v.x;
    res.mt.ptr[3*4+1] = v.y;
    res.mt.ptr[3*4+2] = v.z;
    res.mt.ptr[3*4+3] = 1;
    return res;
  }

  static mat4 TranslateNeg() (in auto ref vec3 v) {
    auto res = mat4(0);
    res.mt.ptr[0*4+0] = res.mt.ptr[1*4+1] = res.mt.ptr[2*4+2] = 1;
    res.mt.ptr[3*4+0] = -v.x;
    res.mt.ptr[3*4+1] = -v.y;
    res.mt.ptr[3*4+2] = -v.z;
    res.mt.ptr[3*4+3] = 1;
    return res;
  }

  static mat4 Scale() (in auto ref vec3 v) {
    auto res = mat4(0);
    res.mt.ptr[0*4+0] = v.x;
    res.mt.ptr[1*4+1] = v.y;
    res.mt.ptr[2*4+2] = v.z;
    res.mt.ptr[3*4+3] = 1;
    return res;
  }

  static mat4 Rotate() (in auto ref vec3 v) {
    auto mx = mat4.RotateX(v.x);
    auto my = mat4.RotateY(v.y);
    auto mz = mat4.RotateZ(v.z);
    return mz*my*mx;
  }

  static mat4 RotateDeg() (in auto ref vec3 v) {
    auto mx = mat4.RotateX(v.x.deg2rad);
    auto my = mat4.RotateY(v.y.deg2rad);
    auto mz = mat4.RotateZ(v.z.deg2rad);
    return mz*my*mx;
  }

  // for camera; x is pitch (up/down); y is yaw (left/right); z is roll (tilt)
  static mat4 RotateZXY() (in auto ref vec3 v) {
    auto mx = mat4.RotateX(v.x);
    auto my = mat4.RotateY(v.y);
    auto mz = mat4.RotateZ(v.z);
    return mz*mx*my;
  }

  // for camera; x is pitch (up/down); y is yaw (left/right); z is roll (tilt)
  static mat4 RotateZXYDeg() (in auto ref vec3 v) {
    auto mx = mat4.RotateX(v.x.deg2rad);
    auto my = mat4.RotateY(v.y.deg2rad);
    auto mz = mat4.RotateZ(v.z.deg2rad);
    return mz*mx*my;
  }

  // same as `glFrustum()`
  static mat4 Frustum() (Float left, Float right, Float bottom, Float top, Float nearVal, Float farVal) nothrow @trusted @nogc {
    auto res = mat4(0);
    res.mt.ptr[0] = 2*nearVal/(right-left);
    res.mt.ptr[5] = 2*nearVal/(top-bottom);
    res.mt.ptr[8] = (right+left)/(right-left);
    res.mt.ptr[9] = (top+bottom)/(top-bottom);
    res.mt.ptr[10] = -(farVal+nearVal)/(farVal-nearVal);
    res.mt.ptr[11] = -1;
    res.mt.ptr[14] = -(2*farVal*nearVal)/(farVal-nearVal);
    res.mt.ptr[15] = 0;
    return res;
  }

  // same as `glOrtho()`
  static mat4 Ortho() (Float left, Float right, Float bottom, Float top, Float nearVal, Float farVal) nothrow @trusted @nogc {
    auto res = mat4(0);
    res.mt.ptr[0]  = 2/(right-left);
    res.mt.ptr[5]  = 2/(top-bottom);
    res.mt.ptr[10] = -2/(farVal-nearVal);
    res.mt.ptr[12] = -(right+left)/(right-left);
    res.mt.ptr[13] = -(top+bottom)/(top-bottom);
    res.mt.ptr[14] = -(farVal+nearVal)/(farVal-nearVal);
    return res;
  }

  // same as `gluPerspective()`
  // sets the frustum to perspective mode
  // fovY   - Field of vision in degrees in the y direction
  // aspect - Aspect ratio of the viewport
  // zNear  - The near clipping distance
  // zFar   - The far clipping distance
  static mat4 Perspective() (Float fovY, Float aspect, Float zNear, Float zFar) nothrow @trusted @nogc {
    import std.math : PI;
    mixin(ImportCoreMath!(Float, "tan"));
    immutable Float fH = cast(Float)(tan(fovY/360*PI)*zNear);
    immutable Float fW = cast(Float)(fH*aspect);
    return Frustum(-fW, fW, -fH, fH, zNear, zFar);
  }

public:
  static mat4 LookAtFucked() (in auto ref vec3 eye, in auto ref vec3 center, in auto ref vec3 up) {
    // compute vector `N = EP-VRP` and normalize `N`
    vec3 n = eye-center;
    n.normalize;

    // compute vector `V = UP-VRP`
    // make vector `V` orthogonal to `N` and normalize `V`
    vec3 v = up-center;
    immutable dp = v.dot(n); //dp = (float)V3Dot(&v,&n);
    //v.x -= dp * n.x; v.y -= dp * n.y; v.z -= dp * n.z;
    v -= n*dp;
    v.normalize;

    // compute vector `U = V x N` (cross product)
    immutable vec3 u = v.cross(n);

    // write the vectors `U`, `V`, and `N` as the first three rows of first, second, and third columns of transformation matrix
    mat4 m = void;

    m.mt.ptr[0*4+0] = u.x;
    m.mt.ptr[1*4+0] = u.y;
    m.mt.ptr[2*4+0] = u.z;
    //m.mt.ptr[3*4+0] = 0;

    m.mt.ptr[0*4+1] = v.x;
    m.mt.ptr[1*4+1] = v.y;
    m.mt.ptr[2*4+1] = v.z;
    //m.mt.ptr[3*4+1] = 0;

    m.mt.ptr[0*4+2] = n.x;
    m.mt.ptr[1*4+2] = n.y;
    m.mt.ptr[2*4+2] = n.z;
    //m.mt.ptr[3*4+2] = 0;

    // compute the fourth row of transformation matrix to include the translation of `VRP` to the origin
    m.mt.ptr[3*4+0] = -u.x*center.x-u.y*center.y-u.z*center.z;
    m.mt.ptr[3*4+1] = -v.x*center.x-v.y*center.y-v.z*center.z;
    m.mt.ptr[3*4+2] = -n.x*center.x-n.y*center.y-n.z*center.z;
    m.mt.ptr[3*4+3] = 1;

    foreach (ref Float f; m.mt[]) {
      mixin(ImportCoreMath!(Float, "fabs"));
      if (fabs(f) < EPSILON!Float) f = 0;
    }

    return m;
  }

  // does `gluLookAt()`
  mat4 lookAt() (in auto ref vec3 eye, in auto ref vec3 center, in auto ref vec3 up) const {
    mixin(ImportCoreMath!(Float, "sqrt"));

    mat4 m = void;
    Float[3] x = void, y = void, z = void;
    Float mag;
    // make rotation matrix
    // Z vector
    z.ptr[0] = eye.x-center.x;
    z.ptr[1] = eye.y-center.y;
    z.ptr[2] = eye.z-center.z;
    mag = sqrt(z.ptr[0]*z.ptr[0]+z.ptr[1]*z.ptr[1]+z.ptr[2]*z.ptr[2]);
    if (mag != 0) {
      z.ptr[0] /= mag;
      z.ptr[1] /= mag;
      z.ptr[2] /= mag;
    }
    // Y vector
    y.ptr[0] = up.x;
    y.ptr[1] = up.y;
    y.ptr[2] = up.z;
    // X vector = Y cross Z
    x.ptr[0] =  y.ptr[1]*z.ptr[2]-y.ptr[2]*z.ptr[1];
    x.ptr[1] = -y.ptr[0]*z.ptr[2]+y.ptr[2]*z.ptr[0];
    x.ptr[2] =  y.ptr[0]*z.ptr[1]-y.ptr[1]*z.ptr[0];
    // Recompute Y = Z cross X
    y.ptr[0] =  z.ptr[1]*x.ptr[2]-z.ptr[2]*x.ptr[1];
    y.ptr[1] = -z.ptr[0]*x.ptr[2]+z.ptr[2]*x.ptr[0];
    y.ptr[2] =  z.ptr[0]*x.ptr[1]-z.ptr[1]*x.ptr[0];

    /* cross product gives area of parallelogram, which is < 1.0 for
     * non-perpendicular unit-length vectors; so normalize x, y here
     */
    mag = sqrt(x.ptr[0]*x.ptr[0]+x.ptr[1]*x.ptr[1]+x.ptr[2]*x.ptr[2]);
    if (mag != 0) {
      x.ptr[0] /= mag;
      x.ptr[1] /= mag;
      x.ptr[2] /= mag;
    }

    mag = sqrt(y.ptr[0]*y.ptr[0]+y.ptr[1]*y.ptr[1]+y.ptr[2]*y.ptr[2]);
    if (mag != 0) {
      y.ptr[0] /= mag;
      y.ptr[1] /= mag;
      y.ptr[2] /= mag;
    }

    m.mt.ptr[0*4+0] = x.ptr[0];
    m.mt.ptr[1*4+0] = x.ptr[1];
    m.mt.ptr[2*4+0] = x.ptr[2];
    m.mt.ptr[3*4+0] = 0;
    m.mt.ptr[0*4+1] = y.ptr[0];
    m.mt.ptr[1*4+1] = y.ptr[1];
    m.mt.ptr[2*4+1] = y.ptr[2];
    m.mt.ptr[3*4+1] = 0;
    m.mt.ptr[0*4+2] = z.ptr[0];
    m.mt.ptr[1*4+2] = z.ptr[1];
    m.mt.ptr[2*4+2] = z.ptr[2];
    m.mt.ptr[3*4+2] = 0;
    m.mt.ptr[0*4+3] = 0;
    m.mt.ptr[1*4+3] = 0;
    m.mt.ptr[2*4+3] = 0;
    m.mt.ptr[3*4+3] = 1;

    // move, and translate Eye to Origin
    return this*m*Translate(-eye);
  }

  // rotate matrix to face along the target direction
  // this function will clear the previous rotation and scale, but it will keep the previous translation
  // it is for rotating object to look at the target, NOT for camera
  ref mat4 lookingAt() (in auto ref vec3 target) {
    mixin(ImportCoreMath!(Float, "fabs"));
    vec3 position = vec3(mt.ptr[12], mt.ptr[13], mt.ptr[14]);
    vec3 forward = (target-position).normalized;
    vec3 up;
    if (fabs(forward.x) < EPSILON!Float && fabs(forward.z) < EPSILON!Float) {
      up.z = (forward.y > 0 ? -1 : 1);
    } else {
      up.y = 1;
    }
    vec3 left = up.cross(forward).normalized;
    up = forward.cross(left).normalized; //k8: `normalized` was commented out; why?
    mt.ptr[0*4+0] = left.x;
    mt.ptr[0*4+1] = left.y;
    mt.ptr[0*4+2] = left.z;
    mt.ptr[1*4+0] = up.x;
    mt.ptr[1*4+1] = up.y;
    mt.ptr[1*4+2] = up.z;
    mt.ptr[2*4+0] = forward.x;
    mt.ptr[2*4+1] = forward.y;
    mt.ptr[2*4+2] = forward.z;
    return this;
  }

  ref mat4 lookingAt() (in auto ref vec3 target, in auto ref vec3 upVec) {
    vec3 position = vec3(mt.ptr[12], mt.ptr[13], mt.ptr[14]);
    vec3 forward = (target-position).normalized;
    vec3 left = upVec.cross(forward).normalized;
    vec3 up = forward.cross(left).normalized;
    mt.ptr[0*4+0] = left.x;
    mt.ptr[0*4+1] = left.y;
    mt.ptr[0*4+2] = left.z;
    mt.ptr[1*4+0] = up.x;
    mt.ptr[1*4+1] = up.y;
    mt.ptr[1*4+2] = up.z;
    mt.ptr[2*4+0] = forward.x;
    mt.ptr[2*4+1] = forward.y;
    mt.ptr[2*4+2] = forward.z;
    return this;
  }

  mat4 lookAt() (in auto ref vec3 target) { pragma(inline, true); auto res = mat4(this); return this.lookingAt(target); }
  mat4 lookAt() (in auto ref vec3 target, in auto ref vec3 upVec) { pragma(inline, true); auto res = mat4(this); return this.lookingAt(target, upVec); }

  ref mat4 rotate() (Float angle, in auto ref vec3 axis) {
    mixin(SinCosImportMixin);
    angle = deg2rad(angle);
    immutable Float c = cos(angle);
    immutable Float s = sin(angle);
    immutable Float c1 = 1-c;
    immutable Float m0 = mt.ptr[0], m4 = mt.ptr[4], m8 = mt.ptr[8], m12 = mt.ptr[12];
    immutable Float m1 = mt.ptr[1], m5 = mt.ptr[5], m9 = mt.ptr[9], m13 = mt.ptr[13];
    immutable Float m2 = mt.ptr[2], m6 = mt.ptr[6], m10 = mt.ptr[10], m14 = mt.ptr[14];

    // build rotation matrix
    immutable Float r0 = axis.x*axis.x*c1+c;
    immutable Float r1 = axis.x*axis.y*c1+axis.z*s;
    immutable Float r2 = axis.x*axis.z*c1-axis.y*s;
    immutable Float r4 = axis.x*axis.y*c1-axis.z*s;
    immutable Float r5 = axis.y*axis.y*c1+c;
    immutable Float r6 = axis.y*axis.z*c1+axis.x*s;
    immutable Float r8 = axis.x*axis.z*c1+axis.y*s;
    immutable Float r9 = axis.y*axis.z*c1-axis.x*s;
    immutable Float r10= axis.z*axis.z*c1+c;

    // multiply rotation matrix
    mt.ptr[0] = r0*m0+r4*m1+r8*m2;
    mt.ptr[1] = r1*m0+r5*m1+r9*m2;
    mt.ptr[2] = r2*m0+r6*m1+r10*m2;
    mt.ptr[4] = r0*m4+r4*m5+r8*m6;
    mt.ptr[5] = r1*m4+r5*m5+r9*m6;
    mt.ptr[6] = r2*m4+r6*m5+r10*m6;
    mt.ptr[8] = r0*m8+r4*m9+r8*m10;
    mt.ptr[9] = r1*m8+r5*m9+r9*m10;
    mt.ptr[10] = r2*m8+r6*m9+r10*m10;
    mt.ptr[12] = r0*m12+r4*m13+r8*m14;
    mt.ptr[13] = r1*m12+r5*m13+r9*m14;
    mt.ptr[14] = r2*m12+r6*m13+r10*m14;

    return this;
  }

  ref mat4 rotateX() (Float angle) {
    mixin(SinCosImportMixin);
    angle = deg2rad(angle);
    immutable Float c = cos(angle);
    immutable Float s = sin(angle);
    immutable Float m1 = mt.ptr[1], m2 = mt.ptr[2];
    immutable Float m5 = mt.ptr[5], m6 = mt.ptr[6];
    immutable Float m9 = mt.ptr[9], m10 = mt.ptr[10];
    immutable Float m13 = mt.ptr[13], m14 = mt.ptr[14];

    mt.ptr[1] = m1*c+m2*-s;
    mt.ptr[2] = m1*s+m2*c;
    mt.ptr[5] = m5*c+m6*-s;
    mt.ptr[6] = m5*s+m6*c;
    mt.ptr[9] = m9*c+m10*-s;
    mt.ptr[10]= m9*s+m10*c;
    mt.ptr[13]= m13*c+m14*-s;
    mt.ptr[14]= m13*s+m14*c;

    return this;
  }

  ref mat4 rotateY() (Float angle) {
    mixin(SinCosImportMixin);
    angle = deg2rad(angle);
    immutable Float c = cos(angle);
    immutable Float s = sin(angle);
    immutable Float m0 = mt.ptr[0], m2 = mt.ptr[2];
    immutable Float m4 = mt.ptr[4], m6 = mt.ptr[6];
    immutable Float m8 = mt.ptr[8], m10 = mt.ptr[10];
    immutable Float m12 = mt.ptr[12], m14 = mt.ptr[14];

    mt.ptr[0] = m0*c+m2*s;
    mt.ptr[2] = m0*-s+m2*c;
    mt.ptr[4] = m4*c+m6*s;
    mt.ptr[6] = m4*-s+m6*c;
    mt.ptr[8] = m8*c+m10*s;
    mt.ptr[10]= m8*-s+m10*c;
    mt.ptr[12]= m12*c+m14*s;
    mt.ptr[14]= m12*-s+m14*c;

    return this;
  }

  ref mat4 rotateZ() (Float angle) {
    mixin(SinCosImportMixin);
    angle = deg2rad(angle);
    immutable Float c = cos(angle);
    immutable Float s = sin(angle);
    immutable Float m0 = mt.ptr[0], m1 = mt.ptr[1];
    immutable Float m4 = mt.ptr[4], m5 = mt.ptr[5];
    immutable Float m8 = mt.ptr[8], m9 = mt.ptr[9];
    immutable Float m12 = mt.ptr[12], m13 = mt.ptr[13];

    mt.ptr[0] = m0*c+m1*-s;
    mt.ptr[1] = m0*s+m1*c;
    mt.ptr[4] = m4*c+m5*-s;
    mt.ptr[5] = m4*s+m5*c;
    mt.ptr[8] = m8*c+m9*-s;
    mt.ptr[9] = m8*s+m9*c;
    mt.ptr[12]= m12*c+m13*-s;
    mt.ptr[13]= m12*s+m13*c;

    return this;
  }

  //k8: wtf is this?!
  ref mat4 translate() (in auto ref vec3 v) {
    mt.ptr[0] += mt.ptr[3]*v.x; mt.ptr[4] += mt.ptr[7]*v.x; mt.ptr[8] += mt.ptr[11]*v.x; mt.ptr[12] += mt.ptr[15]*v.x;
    mt.ptr[1] += mt.ptr[3]*v.y; mt.ptr[5] += mt.ptr[7]*v.y; mt.ptr[9] += mt.ptr[11]*v.y; mt.ptr[13] += mt.ptr[15]*v.y;
    mt.ptr[2] += mt.ptr[3]*v.z; mt.ptr[6] += mt.ptr[7]*v.z; mt.ptr[10] += mt.ptr[11]*v.z; mt.ptr[14] += mt.ptr[15]*v.z;
    return this;
  }

  ref mat4 translateNeg() (in auto ref vec3 v) {
    mt.ptr[0] -= mt.ptr[3]*v.x; mt.ptr[4] -= mt.ptr[7]*v.x; mt.ptr[8] -= mt.ptr[11]*v.x; mt.ptr[12] -= mt.ptr[15]*v.x;
    mt.ptr[1] -= mt.ptr[3]*v.y; mt.ptr[5] -= mt.ptr[7]*v.y; mt.ptr[9] -= mt.ptr[11]*v.y; mt.ptr[13] -= mt.ptr[15]*v.y;
    mt.ptr[2] -= mt.ptr[3]*v.z; mt.ptr[6] -= mt.ptr[7]*v.z; mt.ptr[10] -= mt.ptr[11]*v.z; mt.ptr[14] -= mt.ptr[15]*v.z;
    return this;
  }

  /*
  ref mat4 translate() (in auto ref vec3 v) {
    mt.ptr[12] += v.x;
    mt.ptr[13] += v.y;
    mt.ptr[14] += v.z;
    return this;
  }

  ref mat4 translateNeg() (in auto ref vec3 v) {
    mt.ptr[12] -= v.x;
    mt.ptr[13] -= v.y;
    mt.ptr[14] -= v.z;
    return this;
  }
  */

  //k8: wtf is this?!
  ref mat4 scale() (in auto ref vec3 v) {
    mt.ptr[0] *= v.x; mt.ptr[4] *= v.x; mt.ptr[8] *= v.x; mt.ptr[12] *= v.x;
    mt.ptr[1] *= v.y; mt.ptr[5] *= v.y; mt.ptr[9] *= v.y; mt.ptr[13] *= v.y;
    mt.ptr[2] *= v.z; mt.ptr[6] *= v.z; mt.ptr[10] *= v.z; mt.ptr[14] *= v.z;
    return this;
  }

  mat4 rotated() (Float angle, in auto ref vec3 axis) const { pragma(inline, true); auto res = mat4(this); return res.rotate(angle, axis); }
  mat4 rotatedX() (Float angle) const { pragma(inline, true); auto res = mat4(this); return res.rotateX(angle); }
  mat4 rotatedY() (Float angle) const { pragma(inline, true); auto res = mat4(this); return res.rotateY(angle); }
  mat4 rotatedZ() (Float angle) const { pragma(inline, true); auto res = mat4(this); return res.rotateZ(angle); }
  mat4 translated() (in auto ref vec3 v) const { pragma(inline, true); auto res = mat4(this); return res.translate(v); }
  mat4 translatedNeg() (in auto ref vec3 v) const { pragma(inline, true); auto res = mat4(this); return res.translateNeg(v); }
  mat4 scaled() (in auto ref vec3 v) const { pragma(inline, true); auto res = mat4(this); return res.scale(v); }

  // retrieve angles in degree from rotation matrix, M = Rx*Ry*Rz, in degrees
  // Rx: rotation about X-axis, pitch
  // Ry: rotation about Y-axis, yaw (heading)
  // Rz: rotation about Z-axis, roll
  vec3 getAnglesDeg () const {
    mixin(ImportCoreMath!(Float, "asin", "atan2"));
    Float pitch = void, roll = void;
    Float yaw = rad2deg(asin(mt.ptr[8]));
    if (mt.ptr[10] < 0) {
      if (yaw >= 0) yaw = 180-yaw; else yaw = -180-yaw;
    }
    if (mt.ptr[0] > -EPSILON!Float && mt.ptr[0] < EPSILON!Float) {
      roll = 0;
      pitch = rad2deg(atan2(mt.ptr[1], mt.ptr[5]));
    } else {
      roll = rad2deg(atan2(-mt.ptr[4], mt.ptr[0]));
      pitch = rad2deg(atan2(-mt.ptr[9], mt.ptr[10]));
    }
    return vec3(pitch, yaw, roll);
  }

  // retrieve angles in degree from rotation matrix, M = Rx*Ry*Rz, in radians
  // Rx: rotation about X-axis, pitch
  // Ry: rotation about Y-axis, yaw (heading)
  // Rz: rotation about Z-axis, roll
  vec3 getAngles () const {
    mixin(ImportCoreMath!(Float, "asin", "atan2"));
    Float pitch = void, roll = void;
    Float yaw = asin(mt.ptr[8]);
    if (mt.ptr[10] < 0) {
      if (yaw >= 0) yaw = 180-yaw; else yaw = -180-yaw;
    }
    if (mt.ptr[0] > -EPSILON!Float && mt.ptr[0] < EPSILON!Float) {
      roll = 0;
      pitch = atan2(mt.ptr[1], mt.ptr[5]);
    } else {
      roll = atan2(-mt.ptr[4], mt.ptr[0]);
      pitch = atan2(-mt.ptr[9], mt.ptr[10]);
    }
    return vec3(pitch, yaw, roll);
  }

  vec3 opBinary(string op:"*") (in auto ref vec3 v) const {
    //pragma(inline, true);
    return vec3(
      mt.ptr[0*4+0]*v.x+mt.ptr[1*4+0]*v.y+mt.ptr[2*4+0]*v.z+mt.ptr[3*4+0],
      mt.ptr[0*4+1]*v.x+mt.ptr[1*4+1]*v.y+mt.ptr[2*4+1]*v.z+mt.ptr[3*4+1],
      mt.ptr[0*4+2]*v.x+mt.ptr[1*4+2]*v.y+mt.ptr[2*4+2]*v.z+mt.ptr[3*4+2]);
  }

  vec3 opBinaryRight(string op:"*") (in auto ref vec3 v) const {
    //pragma(inline, true);
    return vec3(
      mt.ptr[0*4+0]*v.x+mt.ptr[0*4+1]*v.y+mt.ptr[0*4+2]*v.z+mt.ptr[0*4+3],
      mt.ptr[1*4+0]*v.x+mt.ptr[1*4+1]*v.y+mt.ptr[1*4+2]*v.z+mt.ptr[1*4+3],
      mt.ptr[2*4+0]*v.x+mt.ptr[2*4+1]*v.y+mt.ptr[2*4+2]*v.z+mt.ptr[2*4+3]);
  }

  mat4 opBinary(string op:"*") (in auto ref mat4 m) const {
    //pragma(inline, true);
    return mat4(
      mt.ptr[0]*m.mt.ptr[0] +mt.ptr[4]*m.mt.ptr[1] +mt.ptr[8]*m.mt.ptr[2] +mt.ptr[12]*m.mt.ptr[3], mt.ptr[1]*m.mt.ptr[0] +mt.ptr[5]*m.mt.ptr[1] +mt.ptr[9]*m.mt.ptr[2] +mt.ptr[13]*m.mt.ptr[3], mt.ptr[2]*m.mt.ptr[0] +mt.ptr[6]*m.mt.ptr[1] +mt.ptr[10]*m.mt.ptr[2] +mt.ptr[14]*m.mt.ptr[3], mt.ptr[3]*m.mt.ptr[0] +mt.ptr[7]*m.mt.ptr[1] +mt.ptr[11]*m.mt.ptr[2] +mt.ptr[15]*m.mt.ptr[3],
      mt.ptr[0]*m.mt.ptr[4] +mt.ptr[4]*m.mt.ptr[5] +mt.ptr[8]*m.mt.ptr[6] +mt.ptr[12]*m.mt.ptr[7], mt.ptr[1]*m.mt.ptr[4] +mt.ptr[5]*m.mt.ptr[5] +mt.ptr[9]*m.mt.ptr[6] +mt.ptr[13]*m.mt.ptr[7], mt.ptr[2]*m.mt.ptr[4] +mt.ptr[6]*m.mt.ptr[5] +mt.ptr[10]*m.mt.ptr[6] +mt.ptr[14]*m.mt.ptr[7], mt.ptr[3]*m.mt.ptr[4] +mt.ptr[7]*m.mt.ptr[5] +mt.ptr[11]*m.mt.ptr[6] +mt.ptr[15]*m.mt.ptr[7],
      mt.ptr[0]*m.mt.ptr[8] +mt.ptr[4]*m.mt.ptr[9] +mt.ptr[8]*m.mt.ptr[10]+mt.ptr[12]*m.mt.ptr[11],mt.ptr[1]*m.mt.ptr[8] +mt.ptr[5]*m.mt.ptr[9] +mt.ptr[9]*m.mt.ptr[10]+mt.ptr[13]*m.mt.ptr[11],mt.ptr[2]*m.mt.ptr[8] +mt.ptr[6]*m.mt.ptr[9] +mt.ptr[10]*m.mt.ptr[10]+mt.ptr[14]*m.mt.ptr[11],mt.ptr[3]*m.mt.ptr[8] +mt.ptr[7]*m.mt.ptr[9] +mt.ptr[11]*m.mt.ptr[10]+mt.ptr[15]*m.mt.ptr[11],
      mt.ptr[0]*m.mt.ptr[12]+mt.ptr[4]*m.mt.ptr[13]+mt.ptr[8]*m.mt.ptr[14]+mt.ptr[12]*m.mt.ptr[15],mt.ptr[1]*m.mt.ptr[12]+mt.ptr[5]*m.mt.ptr[13]+mt.ptr[9]*m.mt.ptr[14]+mt.ptr[13]*m.mt.ptr[15],mt.ptr[2]*m.mt.ptr[12]+mt.ptr[6]*m.mt.ptr[13]+mt.ptr[10]*m.mt.ptr[14]+mt.ptr[14]*m.mt.ptr[15],mt.ptr[3]*m.mt.ptr[12]+mt.ptr[7]*m.mt.ptr[13]+mt.ptr[11]*m.mt.ptr[14]+mt.ptr[15]*m.mt.ptr[15],
    );
  }

  mat4 opBinary(string op:"+") (in auto ref mat4 m) const {
    auto res = mat4(this);
    res.mt[] += m.mt[];
    return res;
  }

  mat4 opBinary(string op:"*") (Float a) const {
    auto res = mat4(this);
    res.mt[] *= a;
    return res;
  }

  mat4 opBinary(string op:"/") (Float a) const {
    mixin(ImportCoreMath!(Float, "fabs"));
    auto res = mat4(this);
    if (fabs(a) >= FLTEPS) {
      a = cast(Float)1/a;
      res.mt[] *= a;
    } else {
      res.mt[] = 0;
    }
    return res;
  }

  ref vec2 opOpAssign(string op:"*") (in auto ref mat4 m) {
    mat4 res;
    foreach (immutable i; 0..4) {
      foreach (immutable j; 0..4) {
        foreach (immutable k; 0..4) {
          res.mt.ptr[i+j*4] += mt.ptr[i+k*4]*m.mt.ptr[k+j*4];
        }
      }
    }
    mt[] = res.mt[];
    return this;
  }

  mat4 transposed () const {
    /*
    mat4 res;
    foreach (immutable i; 0..4) {
      foreach (immutable j; 0..4) {
        res.mt.ptr[i+j*4] = mt.ptr[j+i*4];
      }
    }
    return res;
    */
    return mat4(
      mt.ptr[0], mt.ptr[4], mt.ptr[8],  mt.ptr[12],
      mt.ptr[1], mt.ptr[5], mt.ptr[9],  mt.ptr[13],
      mt.ptr[2], mt.ptr[6], mt.ptr[10], mt.ptr[14],
      mt.ptr[3], mt.ptr[7], mt.ptr[11], mt.ptr[15],
    );
  }

  void negate () { foreach (ref v; mt) v = -v; }

  mat4 opUnary(string op:"-") () const { pragma(inline, true); return this; }

  mat4 opUnary(string op:"-") () const {
    return mat4(
      -mt.ptr[0], -mt.ptr[1], -mt.ptr[2], -mt.ptr[3],
      -mt.ptr[4], -mt.ptr[5], -mt.ptr[6], -mt.ptr[7],
      -mt.ptr[8], -mt.ptr[9], -mt.ptr[10], -mt.ptr[11],
      -mt.ptr[12], -mt.ptr[13], -mt.ptr[14], -mt.ptr[15],
    );
  }

  // blends two matrices together, at a given percentage (range is [0..1]), blend==0: m2 is ignored
  // WARNING! won't sanitize `blend`
  mat4 blended() (in auto ref mat4 m2, Float blend) const {
    immutable Float ib = cast(Float)1-blend;
    mat4 res = void;
    res.mt.ptr[0] = mt.ptr[0]*ib+m2.mt.ptr[0]*blend;
    res.mt.ptr[1] = mt.ptr[1]*ib+m2.mt.ptr[1]*blend;
    res.mt.ptr[2] = mt.ptr[2]*ib+m2.mt.ptr[2]*blend;
    res.mt.ptr[3] = mt.ptr[3]*ib+m2.mt.ptr[3]*blend;
    res.mt.ptr[4] = mt.ptr[4]*ib+m2.mt.ptr[4]*blend;
    res.mt.ptr[5] = mt.ptr[5]*ib+m2.mt.ptr[5]*blend;
    res.mt.ptr[6] = mt.ptr[6]*ib+m2.mt.ptr[6]*blend;
    res.mt.ptr[7] = mt.ptr[7]*ib+m2.mt.ptr[7]*blend;
    res.mt.ptr[8] = mt.ptr[8]*ib+m2.mt.ptr[8]*blend;
    res.mt.ptr[9] = mt.ptr[9]*ib+m2.mt.ptr[9]*blend;
    res.mt.ptr[10] = mt.ptr[10]*ib+m2.mt.ptr[10]*blend;
    res.mt.ptr[11] = mt.ptr[11]*ib+m2.mt.ptr[11]*blend;
    res.mt.ptr[12] = mt.ptr[12]*ib+m2.mt.ptr[12]*blend;
    res.mt.ptr[13] = mt.ptr[13]*ib+m2.mt.ptr[13]*blend;
    res.mt.ptr[14] = mt.ptr[14]*ib+m2.mt.ptr[14]*blend;
    res.mt.ptr[15] = mt.ptr[15]*ib+m2.mt.ptr[15]*blend;
    return res;
  }

  Float determinant() () const {
    return mt.ptr[0]*getCofactor(mt.ptr[5], mt.ptr[6], mt.ptr[7], mt.ptr[9], mt.ptr[10], mt.ptr[11], mt.ptr[13], mt.ptr[14], mt.ptr[15])-
           mt.ptr[1]*getCofactor(mt.ptr[4], mt.ptr[6], mt.ptr[7], mt.ptr[8], mt.ptr[10], mt.ptr[11], mt.ptr[12], mt.ptr[14], mt.ptr[15])+
           mt.ptr[2]*getCofactor(mt.ptr[4], mt.ptr[5], mt.ptr[7], mt.ptr[8], mt.ptr[9], mt.ptr[11], mt.ptr[12], mt.ptr[13], mt.ptr[15])-
           mt.ptr[3]*getCofactor(mt.ptr[4], mt.ptr[5], mt.ptr[6], mt.ptr[8], mt.ptr[9], mt.ptr[10], mt.ptr[12], mt.ptr[13], mt.ptr[14]);
  }

  //WARNING: this must be tested for row/col
  // partially ;-) taken from DarkPlaces
  // this assumes uniform scaling
  mat4 invertedSimple () const {
    // we only support uniform scaling, so assume the first row is enough
    // (note the lack of sqrt here, because we're trying to undo the scaling,
    // this means multiplying by the inverse scale twice - squaring it, which
    // makes the sqrt a waste of time)
    version(all) {
      immutable Float scale = cast(Float)1/(mt.ptr[0*4+0]*mt.ptr[0*4+0]+mt.ptr[1*4+0]*mt.ptr[1*4+0]+mt.ptr[2*4+0]*mt.ptr[2*4+0]);
    } else {
      mixin(ImportCoreMath!(Float, "sqrt"));
      Float scale = cast(Float)3/sqrt(
        mt.ptr[0*4+0]*mt.ptr[0*4+0]+mt.ptr[1*4+0]*mt.ptr[1*4+0]+mt.ptr[2*4+0]*mt.ptr[2*4+0]+
        mt.ptr[0*4+1]*mt.ptr[0*4+1]+mt.ptr[1*4+1]*mt.ptr[1*4+1]+mt.ptr[2*4+1]*mt.ptr[2*4+1]+
        mt.ptr[0*4+2]*mt.ptr[0*4+2]+mt.ptr[1*4+2]*mt.ptr[1*4+2]+mt.ptr[2*4+2]*mt.ptr[2*4+2]
      );
      scale *= scale;
    }

    mat4 res = void;

    // invert the rotation by transposing and multiplying by the squared recipricol of the input matrix scale as described above
    res.mt.ptr[0*4+0] = mt.ptr[0*4+0]*scale;
    res.mt.ptr[1*4+0] = mt.ptr[0*4+1]*scale;
    res.mt.ptr[2*4+0] = mt.ptr[0*4+2]*scale;
    res.mt.ptr[0*4+1] = mt.ptr[1*4+0]*scale;
    res.mt.ptr[1*4+1] = mt.ptr[1*4+1]*scale;
    res.mt.ptr[2*4+1] = mt.ptr[1*4+2]*scale;
    res.mt.ptr[0*4+2] = mt.ptr[2*4+0]*scale;
    res.mt.ptr[1*4+2] = mt.ptr[2*4+1]*scale;
    res.mt.ptr[2*4+2] = mt.ptr[2*4+2]*scale;

    // invert the translate
    res.mt.ptr[3*4+0] = -(mt.ptr[3*4+0]*res.mt.ptr[0*4+0]+mt.ptr[3*4+1]*res.mt.ptr[1*4+0]+mt.ptr[3*4+2]*res.mt.ptr[2*4+0]);
    res.mt.ptr[3*4+1] = -(mt.ptr[3*4+0]*res.mt.ptr[0*4+1]+mt.ptr[3*4+1]*res.mt.ptr[1*4+1]+mt.ptr[3*4+2]*res.mt.ptr[2*4+1]);
    res.mt.ptr[3*4+2] = -(mt.ptr[3*4+0]*res.mt.ptr[0*4+2]+mt.ptr[3*4+1]*res.mt.ptr[1*4+2]+mt.ptr[3*4+2]*res.mt.ptr[2*4+2]);

    // don't know if there's anything worth doing here
    res.mt.ptr[0*4+3] = cast(Float)0;
    res.mt.ptr[1*4+3] = cast(Float)0;
    res.mt.ptr[2*4+3] = cast(Float)0;
    res.mt.ptr[3*4+3] = cast(Float)1;

    return res;
  }

  //FIXME: make this fast pasta!
  ref mat4 invertSimple () {
    mt[] = invertedSimple().mt[];
    return this;
  }

  // ////////////////////////////////////////////////////////////////////////////
  // compute the inverse of 4x4 Euclidean transformation matrix
  //
  // Euclidean transformation is translation, rotation, and reflection.
  // With Euclidean transform, only the position and orientation of the object
  // will be changed. Euclidean transform does not change the shape of an object
  // (no scaling). Length and angle are reserved.
  //
  // Use inverseAffine() if the matrix has scale and shear transformation.
  ref mat4 invertEuclidean() () {
    Float tmp = void;
    tmp = mt.ptr[1]; mt.ptr[1] = mt.ptr[4]; mt.ptr[4] = tmp;
    tmp = mt.ptr[2]; mt.ptr[2] = mt.ptr[8]; mt.ptr[8] = tmp;
    tmp = mt.ptr[6]; mt.ptr[6] = mt.ptr[9]; mt.ptr[9] = tmp;
    immutable Float x = mt.ptr[12];
    immutable Float y = mt.ptr[13];
    immutable Float z = mt.ptr[14];
    mt.ptr[12] = -(mt.ptr[0]*x+mt.ptr[4]*y+mt.ptr[8]*z);
    mt.ptr[13] = -(mt.ptr[1]*x+mt.ptr[5]*y+mt.ptr[9]*z);
    mt.ptr[14] = -(mt.ptr[2]*x+mt.ptr[6]*y+mt.ptr[10]*z);
    return this;
  }

  // ////////////////////////////////////////////////////////////////////////////
  // compute the inverse of a 4x4 affine transformation matrix
  //
  // Affine transformations are generalizations of Euclidean transformations.
  // Affine transformation includes translation, rotation, reflection, scaling,
  // and shearing. Length and angle are NOT preserved.
  ref mat4 invertAffine() () {
    // R^-1
    mixin(ImportCoreMath!(Float, "fabs"));
    // inverse 3x3 matrix
    Float[9] r = void; //[ mt.ptr[0],mt.ptr[1],mt.ptr[2], mt.ptr[4],mt.ptr[5],mt.ptr[6], mt.ptr[8],mt.ptr[9],mt.ptr[10] ];
    r.ptr[0] = mt.ptr[0];
    r.ptr[1] = mt.ptr[1];
    r.ptr[2] = mt.ptr[2];
    r.ptr[3] = mt.ptr[4];
    r.ptr[4] = mt.ptr[5];
    r.ptr[5] = mt.ptr[6];
    r.ptr[6] = mt.ptr[8];
    r.ptr[7] = mt.ptr[9];
    r.ptr[8] = mt.ptr[10];
    {
      Float[9] tmp = void;
      tmp.ptr[0] = r.ptr[4]*r.ptr[8]-r.ptr[5]*r.ptr[7];
      tmp.ptr[1] = r.ptr[2]*r.ptr[7]-r.ptr[1]*r.ptr[8];
      tmp.ptr[2] = r.ptr[1]*r.ptr[5]-r.ptr[2]*r.ptr[4];
      tmp.ptr[3] = r.ptr[5]*r.ptr[6]-r.ptr[3]*r.ptr[8];
      tmp.ptr[4] = r.ptr[0]*r.ptr[8]-r.ptr[2]*r.ptr[6];
      tmp.ptr[5] = r.ptr[2]*r.ptr[3]-r.ptr[0]*r.ptr[5];
      tmp.ptr[6] = r.ptr[3]*r.ptr[7]-r.ptr[4]*r.ptr[6];
      tmp.ptr[7] = r.ptr[1]*r.ptr[6]-r.ptr[0]*r.ptr[7];
      tmp.ptr[8] = r.ptr[0]*r.ptr[4]-r.ptr[1]*r.ptr[3];
      // check determinant if it is 0
      immutable Float determinant = r.ptr[0]*tmp.ptr[0]+r.ptr[1]*tmp.ptr[3]+r.ptr[2]*tmp.ptr[6];
      if (fabs(determinant) <= EPSILON!Float) {
        // cannot inverse, make it idenety matrix
        r[] = 0;
        r.ptr[0] = r.ptr[4] = r.ptr[8] = 1;
      } else {
        // divide by the determinant
        immutable Float invDeterminant = cast(Float)1/determinant;
        r.ptr[0] = invDeterminant*tmp.ptr[0];
        r.ptr[1] = invDeterminant*tmp.ptr[1];
        r.ptr[2] = invDeterminant*tmp.ptr[2];
        r.ptr[3] = invDeterminant*tmp.ptr[3];
        r.ptr[4] = invDeterminant*tmp.ptr[4];
        r.ptr[5] = invDeterminant*tmp.ptr[5];
        r.ptr[6] = invDeterminant*tmp.ptr[6];
        r.ptr[7] = invDeterminant*tmp.ptr[7];
        r.ptr[8] = invDeterminant*tmp.ptr[8];
      }
    }

    mt.ptr[0] = r.ptr[0]; mt.ptr[1] = r.ptr[1]; mt.ptr[2] = r.ptr[2];
    mt.ptr[4] = r.ptr[3]; mt.ptr[5] = r.ptr[4]; mt.ptr[6] = r.ptr[5];
    mt.ptr[8] = r.ptr[6]; mt.ptr[9] = r.ptr[7]; mt.ptr[10]= r.ptr[8];

    // -R^-1 * T
    immutable Float x = mt.ptr[12];
    immutable Float y = mt.ptr[13];
    immutable Float z = mt.ptr[14];
    mt.ptr[12] = -(r.ptr[0]*x+r.ptr[3]*y+r.ptr[6]*z);
    mt.ptr[13] = -(r.ptr[1]*x+r.ptr[4]*y+r.ptr[7]*z);
    mt.ptr[14] = -(r.ptr[2]*x+r.ptr[5]*y+r.ptr[8]*z);

    // last row should be unchanged (0,0,0,1)
    //mt.ptr[3] = mt.ptr[7] = mt.ptr[11] = 0.0f;
    //mt.ptr[15] = 1.0f;

    return this;
  }

  ref mat4 invert() () {
    // if the 4th row is [0,0,0,1] then it is affine matrix and
    // it has no projective transformation
    if (mt.ptr[3] == 0 && mt.ptr[7] == 0 && mt.ptr[11] == 0 && mt.ptr[15] == 1) {
      return invertedAffine();
    } else {
      return invertedGeneral();
    }
  }

  ///////////////////////////////////////////////////////////////////////////////
  // compute the inverse of a general 4x4 matrix using Cramer's Rule
  // if cannot find inverse, return indentity matrix
  ref mat4 invertGeneral() () {
    mixin(ImportCoreMath!(Float, "fabs"));

    immutable Float cofactor0 = getCofactor(mt.ptr[5], mt.ptr[6], mt.ptr[7], mt.ptr[9], mt.ptr[10], mt.ptr[11], mt.ptr[13], mt.ptr[14], mt.ptr[15]);
    immutable Float cofactor1 = getCofactor(mt.ptr[4], mt.ptr[6], mt.ptr[7], mt.ptr[8], mt.ptr[10], mt.ptr[11], mt.ptr[12], mt.ptr[14], mt.ptr[15]);
    immutable Float cofactor2 = getCofactor(mt.ptr[4], mt.ptr[5], mt.ptr[7], mt.ptr[8], mt.ptr[9], mt.ptr[11], mt.ptr[12], mt.ptr[13], mt.ptr[15]);
    immutable Float cofactor3 = getCofactor(mt.ptr[4], mt.ptr[5], mt.ptr[6], mt.ptr[8], mt.ptr[9], mt.ptr[10], mt.ptr[12], mt.ptr[13], mt.ptr[14]);

    immutable Float determinant = mt.ptr[0]*cofactor0-mt.ptr[1]*cofactor1+mt.ptr[2]*cofactor2-mt.ptr[3]*cofactor3;
    if (fabs(determinant) <= EPSILON!Float) { this = Identity; return this; }

    immutable Float cofactor4 = getCofactor(mt.ptr[1], mt.ptr[2], mt.ptr[3], mt.ptr[9], mt.ptr[10], mt.ptr[11], mt.ptr[13], mt.ptr[14], mt.ptr[15]);
    immutable Float cofactor5 = getCofactor(mt.ptr[0], mt.ptr[2], mt.ptr[3], mt.ptr[8], mt.ptr[10], mt.ptr[11], mt.ptr[12], mt.ptr[14], mt.ptr[15]);
    immutable Float cofactor6 = getCofactor(mt.ptr[0], mt.ptr[1], mt.ptr[3], mt.ptr[8], mt.ptr[9], mt.ptr[11], mt.ptr[12], mt.ptr[13], mt.ptr[15]);
    immutable Float cofactor7 = getCofactor(mt.ptr[0], mt.ptr[1], mt.ptr[2], mt.ptr[8], mt.ptr[9], mt.ptr[10], mt.ptr[12], mt.ptr[13], mt.ptr[14]);

    immutable Float cofactor8 = getCofactor(mt.ptr[1], mt.ptr[2], mt.ptr[3], mt.ptr[5], mt.ptr[6], mt.ptr[7],  mt.ptr[13], mt.ptr[14], mt.ptr[15]);
    immutable Float cofactor9 = getCofactor(mt.ptr[0], mt.ptr[2], mt.ptr[3], mt.ptr[4], mt.ptr[6], mt.ptr[7],  mt.ptr[12], mt.ptr[14], mt.ptr[15]);
    immutable Float cofactor10= getCofactor(mt.ptr[0], mt.ptr[1], mt.ptr[3], mt.ptr[4], mt.ptr[5], mt.ptr[7],  mt.ptr[12], mt.ptr[13], mt.ptr[15]);
    immutable Float cofactor11= getCofactor(mt.ptr[0], mt.ptr[1], mt.ptr[2], mt.ptr[4], mt.ptr[5], mt.ptr[6],  mt.ptr[12], mt.ptr[13], mt.ptr[14]);

    immutable Float cofactor12= getCofactor(mt.ptr[1], mt.ptr[2], mt.ptr[3], mt.ptr[5], mt.ptr[6], mt.ptr[7],  mt.ptr[9], mt.ptr[10], mt.ptr[11]);
    immutable Float cofactor13= getCofactor(mt.ptr[0], mt.ptr[2], mt.ptr[3], mt.ptr[4], mt.ptr[6], mt.ptr[7],  mt.ptr[8], mt.ptr[10], mt.ptr[11]);
    immutable Float cofactor14= getCofactor(mt.ptr[0], mt.ptr[1], mt.ptr[3], mt.ptr[4], mt.ptr[5], mt.ptr[7],  mt.ptr[8], mt.ptr[9], mt.ptr[11]);
    immutable Float cofactor15= getCofactor(mt.ptr[0], mt.ptr[1], mt.ptr[2], mt.ptr[4], mt.ptr[5], mt.ptr[6],  mt.ptr[8], mt.ptr[9], mt.ptr[10]);

    immutable Float invDeterminant = cast(Float)1/determinant;
    mt.ptr[0] =  invDeterminant*cofactor0;
    mt.ptr[1] = -invDeterminant*cofactor4;
    mt.ptr[2] =  invDeterminant*cofactor8;
    mt.ptr[3] = -invDeterminant*cofactor12;

    mt.ptr[4] = -invDeterminant*cofactor1;
    mt.ptr[5] =  invDeterminant*cofactor5;
    mt.ptr[6] = -invDeterminant*cofactor9;
    mt.ptr[7] =  invDeterminant*cofactor13;

    mt.ptr[8] =  invDeterminant*cofactor2;
    mt.ptr[9] = -invDeterminant*cofactor6;
    mt.ptr[10]=  invDeterminant*cofactor10;
    mt.ptr[11]= -invDeterminant*cofactor14;

    mt.ptr[12]= -invDeterminant*cofactor3;
    mt.ptr[13]=  invDeterminant*cofactor7;
    mt.ptr[14]= -invDeterminant*cofactor11;
    mt.ptr[15]=  invDeterminant*cofactor15;

    return this;
  }

  // compute cofactor of 3x3 minor matrix without sign
  // input params are 9 elements of the minor matrix
  // NOTE: The caller must know its sign
  private static Float getCofactor() (Float m0, Float m1, Float m2, Float m3, Float m4, Float m5, Float m6, Float m7, Float m8) {
    pragma(inline, true);
    return m0*(m4*m8-m5*m7)-m1*(m3*m8-m5*m6)+m2*(m3*m7-m4*m6);
  }

  Quat4!VT toQuaternion () const nothrow @trusted @nogc {
    mixin(ImportCoreMath!(Float, "sqrt"));
    Quat4!VT res = void;
    immutable Float tr = mt.ptr[0*4+0]+mt.ptr[1*4+1]+mt.ptr[2*4+2];
    // check the diagonal
    if (tr > 0) {
      Float s = sqrt(tr+cast(Float)1);
      res.w = s/cast(Float)2;
      s = cast(Float)0.5/s;
      res.x = (mt.ptr[2*4+1]-mt.ptr[1*4+2])*s;
      res.y = (mt.ptr[0*4+2]-mt.ptr[2*4+0])*s;
      res.z = (mt.ptr[1*4+0]-mt.ptr[0*4+1])*s;
    } else {
      // diagonal is negative
      int[3] nxt = [1, 2, 0];
      int i = 0;
      if (mt.ptr[1*4+1] > mt.ptr[0*4+0]) i = 1;
      if (mt.ptr[2*4+2] > mt.ptr[i*4+i]) i = 2;
      int j = nxt.ptr[i];
      int k = nxt.ptr[j];
      Float s = sqrt((mt.ptr[i*4+i]-(mt.ptr[j*4+j]+mt.ptr[k*4+k]))+cast(Float)1);
      Float[4] q = void;
      q.ptr[i] = s*cast(Float)0.5;
      if (s != 0) s = cast(Float)0.5/s;
      q.ptr[3] = (mt.ptr[k*4+j]-mt.ptr[j*4+k])*s;
      q.ptr[j] = (mt.ptr[j*4+i]+mt.ptr[i*4+j])*s;
      q.ptr[k] = (mt.ptr[k*4+i]+mt.ptr[i*4+k])*s;
      res.x = q.ptr[0];
      res.y = q.ptr[1];
      res.z = q.ptr[2];
      res.w = q.ptr[3];
    }
    return res;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
alias quat4 = Quat4!vec3;

align(1) struct Quat4(VT) if (IsVector!VT) {
align(1):
public:
  alias Float = VT.Float;
  alias quat4 = typeof(this);

public:
  Float w=1, x=0, y=0, z=0; // default: identity

public:
  this (Float aw, Float ax, Float ay, Float az) nothrow @trusted @nogc {
    pragma(inline, true);
    w = aw;
    x = ax;
    y = ay;
    z = az;
  }

  // valid only for unit quaternions
  this (Float ax, Float ay, Float az) nothrow @trusted @nogc {
    immutable Float t = cast(Float)1-(ax*ax)-(ay*ay)-(az*az);
    if (t < 0) {
      w = 0;
    } else {
      mixin(ImportCoreMath!(Float, "sqrt"));
      w = -sqrt(t);
    }
    x = ax;
    y = ay;
    z = az;
  }

  this() (in auto ref VT v) nothrow @safe @nogc {
    pragma(inline, true);
    x = v.x;
    y = v.y;
    z = v.z;
    w = 0;
  }

  // the rotation of a point by a quaternion is given by the formula:
  //   R = Q.P.Q*
  // where R is the resultant quaternion, Q is the orientation quaternion by which you want to perform a rotation,
  // Q* the conjugate of Q and P is the point converted to a quaternion.
  // note: here the "." is the multiplication operator.
  //
  // to convert a 3D vector to a quaternion, copy the x, y and z components and set the w component to 0.
  // this is the same for quaternion to vector conversion: take the x, y and z components and forget the w.

  VT asVector () const nothrow @safe @nogc { pragma(inline, true); return VT(x, y, z); }

  static quat4 Identity () nothrow @safe @nogc { pragma(inline, true); return quat4(1, 0, 0, 0); }
  bool isIdentity () const nothrow @safe @nogc { pragma(inline, true); return (w == 1 && x == 0 && y == 0 && z == 0); }

  static quat4 fromAngles (Float roll, Float pitch, Float yaw) nothrow @trusted @nogc {
    mixin(ImportCoreMath!(Float, "cos", "sin"));
    // calculate trig identities
    immutable Float cr = cos(roll/2);
    immutable Float cp = cos(pitch/2);
    immutable Float cy = cos(yaw/2);
    immutable Float sr = sin(roll/2);
    immutable Float sp = sin(pitch/2);
    immutable Float sy = sin(yaw/2);
    immutable Float cpcy = cp*cy;
    immutable Float spsy = sp*sy;
    return quat4(
      cr*cpcy+sr*spsy,
      sr*cpcy-cr*spsy,
      cr*sp*cy+sr*cp*sy,
      cr*cp*sy-sr*sp*cy,
    );
  }

  //@property bool valid () const nothrow @safe @nogc { pragma(inline, true); import core.stdc.math : isnan; return !isnan(w) && !isnan(x) && !isnan(y) && !isnan(z); }
  @property bool valid () const nothrow @safe @nogc { pragma(inline, true); import core.stdc.math : isfinite; return isfinite(w) && isfinite(x) && isfinite(y) && isfinite(z); }

  // x,y,z,w
  Float opIndex (usize idx) const nothrow @safe @nogc {
    pragma(inline, true);
    return
      idx == 0 ? x :
      idx == 1 ? y :
      idx == 2 ? z :
      idx == 3 ? w :
      Float.nan;
  }

  // x,y,z,w
  void opIndexAssign (Float v, usize idx) {
    pragma(inline, true);
    if (idx == 0) x = v; else
    if (idx == 1) y = v; else
    if (idx == 2) z = v; else
    if (idx == 3) w = v; else
    assert(0, "invalid quaternion index");
  }

  Mat4!VT toMatrix () const nothrow @trusted @nogc {
    // calculate coefficients
    immutable Float x2 = this.x+this.x;
    immutable Float y2 = this.y+this.y;
    immutable Float z2 = this.z+this.z;
    immutable Float xx = this.x*x2;
    immutable Float xy = this.x*y2;
    immutable Float xz = this.x*z2;
    immutable Float yy = this.y*y2;
    immutable Float yz = this.y*z2;
    immutable Float zz = this.z*z2;
    immutable Float wx = this.w*x2;
    immutable Float wy = this.w*y2;
    immutable Float wz = this.w*z2;

    Mat4!VT res = void;
    res.mt.ptr[0*4+0] = cast(Float)1-(yy+zz);
    res.mt.ptr[0*4+1] = xy-wz;
    res.mt.ptr[0*4+2] = xz+wy;
    res.mt.ptr[0*4+3] = 0;

    res.mt.ptr[1*4+0] = xy+wz;
    res.mt.ptr[1*4+1] = cast(Float)1-(xx+zz);
    res.mt.ptr[1*4+2] = yz-wx;
    res.mt.ptr[1*4+3] = 0;

    res.mt.ptr[2*4+0] = xz-wy;
    res.mt.ptr[2*4+1] = yz+wx;
    res.mt.ptr[2*4+2] = cast(Float)1-(xx+yy);
    res.mt.ptr[2*4+3] = 0;

    res.mt.ptr[3*4+0] = 0;
    res.mt.ptr[3*4+1] = 0;
    res.mt.ptr[3*4+2] = 0;
    res.mt.ptr[3*4+3] = 1;

    return res;
  }

  auto opUnary(string op:"+") () const nothrow @safe @nogc { pragma(inline, true); return this; }

  // for unit quaternions, this is inverse/conjugate
  auto opUnary(string op:"-") () const nothrow @safe @nogc { pragma(inline, true); return quat4(-w, -x, -y, -z); }

  quat4 opBinary(string op:"*") (in auto ref quat4 q2) const nothrow @safe @nogc {
    auto res = quat4(this.w, this.x, this.y, this.z);
    return (res *= q2);
  }

  ref quat4 opOpAssign(string op:"*") (in auto ref quat4 q2) nothrow @safe @nogc {
    immutable Float A = (this.w+this.x)*(q2.w+q2.x);
    immutable Float B = (this.z-this.y)*(q2.y-q2.z);
    immutable Float C = (this.w-this.x)*(q2.y+q2.z);
    immutable Float D = (this.y+this.z)*(q2.w-q2.x);
    immutable Float E = (this.x+this.z)*(q2.x+q2.y);
    immutable Float F = (this.x-this.z)*(q2.x-q2.y);
    immutable Float G = (this.w+this.y)*(q2.w-q2.z);
    immutable Float H = (this.w-this.y)*(q2.w+q2.z);
    this.w = B+(-E-F+G+H)/2;
    this.x = A-(E+F+G+H)/2;
    this.y = C+(E-F+G-H)/2;
    this.z = D+(E-F-G+H)/2;
    return this;
  }

  quat4 slerp() (in auto ref quat4 to, Float t) const nothrow @trusted @nogc {
    mixin(ImportCoreMath!(Float, "acos", "sin"));
    Float[4] to1 = void;
    // calc cosine
    Float cosom = this.x*to.x+this.y*to.y+this.z*to.z+this.w*to.w;
    // adjust signs (if necessary)
    if (cosom < 0) {
      cosom = -cosom;
      to1.ptr[0] = -to.x;
      to1.ptr[1] = -to.y;
      to1.ptr[2] = -to.z;
      to1.ptr[3] = -to.w;
    } else  {
      to1.ptr[0] = to.x;
      to1.ptr[1] = to.y;
      to1.ptr[2] = to.z;
      to1.ptr[3] = to.w;
    }
    Float scale0 = void, scale1 = void;
    // calculate coefficients
    if (cast(Float)1-cosom > EPSILON!Float) {
      // standard case (slerp)
      immutable Float omega = acos(cosom);
      immutable Float sinom = sin(omega);
      scale0 = sin((cast(Float)1-t)*omega)/sinom;
      scale1 = sin(t*omega)/sinom;
    } else {
      // "from" and "to" quaternions are very close, so we can do a linear interpolation
      scale0 = cast(Float)1-t;
      scale1 = t;
    }
    // calculate final values
    return quat4(
      scale0*this.w+scale1*to1.ptr[3],
      scale0*this.x+scale1*to1.ptr[0],
      scale0*this.y+scale1*to1.ptr[1],
      scale0*this.z+scale1*to1.ptr[2],
    );
  }
}


// ////////////////////////////////////////////////////////////////////////// //
alias OBB2D = OBB2d!vec2;

/// Oriented Bounding Box
struct OBB2d(VT) if (IsVectorDim!(VT, 2)) {
  // to make the tests extremely efficient, `origin` stores the
  // projection of corner number zero onto a box's axes and the axes are stored
  // explicitly in axis. the magnitude of these stored axes is the inverse
  // of the corresponding edge length so that all overlap tests can be performed on
  // the interval [0, 1] without normalization, and square roots are avoided
  // throughout the entire test.
public:
  alias Me = typeof(this);
  alias Float = VT.Float;
  alias vec2 = VT;

private:
  VT[4] corner; // corners of the box, where 0 is the lower left
  bool aovalid; // are axes and origin valid?
  VT[2] axis; // two edges of the box extended away from corner[0]
  VT.Float[2] origin; // origin[a] = corner[0].dot(axis[a]);

private nothrow @trusted @nogc:
  // returns true if other overlaps one dimension of this
  bool overlaps1Way() (in auto ref Me other) const {
    foreach (immutable a; 0..2) {
      Float t = other.corner.ptr[0].dot(axis.ptr[a]);
      // find the extent of box 2 on axis a
      Float tMin = t, tMax = t;
      foreach (immutable c; 1..4) {
        t = other.corner.ptr[c].dot(axis.ptr[a]);
        if (t < tMin) tMin = t; else if (t > tMax) tMax = t;
      }
      // we have to subtract off the origin
      // see if [tMin, tMax] intersects [0, 1]
      if (tMin > 1+origin.ptr[a] || tMax < origin.ptr[a]) {
        // there was no intersection along this dimension; the boxes cannot possibly overlap
        return false;
      }
    }
    // there was no dimension along which there is no intersection: therefore the boxes overlap
    return true;
  }

  // updates the axes after the corners move; assumes the corners actually form a rectangle
  void computeAxes () {
    axis.ptr[0] = corner.ptr[1]-corner.ptr[0];
    axis.ptr[1] = corner.ptr[3]-corner.ptr[0];
    // make the length of each axis 1/edge length so we know any dot product must be less than 1 to fall within the edge
    foreach (immutable a; 0..2) {
      axis.ptr[a] /= axis.ptr[a].lengthSquared;
      origin.ptr[a] = corner.ptr[0].dot(axis.ptr[a]);
    }
    aovalid = true;
  }

public:
  ///
  this() (in auto ref VT center, in Float w, in Float h, in Float angle) {
    mixin(ImportCoreMath!(Float, "cos", "sin"));

    immutable Float ca = cos(angle);
    immutable Float sa = sin(angle);
    auto ox = VT( ca, sa);
    auto oy = VT(-sa, ca);

    ox *= w/2;
    oy *= h/2;

    corner.ptr[0] = center-ox-oy;
    corner.ptr[1] = center+ox-oy;
    corner.ptr[2] = center+ox+oy;
    corner.ptr[3] = center-ox+oy;

    // compute axes on demand
    //computeAxes();
  }

  VT[4] corners () const { pragma(inline, true); VT[4] res = corner[]; return res; }

  /// get corner
  VT opIndex (usize idx) const {
    pragma(inline, true);
    return (idx < 4 ? corner.ptr[idx] : VT(Float.nan, Float.nan, Float.nan));
  }

  ///
  void moveTo() (in auto ref VT center) {
    immutable centroid = (corner.ptr[0]+corner.ptr[1]+corner.ptr[2]+corner.ptr[3])/4;
    immutable translation = center-centroid;
    foreach (ref VT cv; corner[]) cv += translation;
    aovalid = false; // invalidate axes
  }

  ///
  void moveBy() (in auto ref VT delta) {
    foreach (ref VT cv; corner[]) cv += delta;
    aovalid = false; // invalidate axes
  }

  /// rotate around centroid
  void rotate() (Float angle) {
    mixin(ImportCoreMath!(Float, "cos", "sin"));
    immutable centroid = (corner.ptr[0]+corner.ptr[1]+corner.ptr[2]+corner.ptr[3])/4;
    immutable Float ca = cos(angle);
    immutable Float sa = sin(angle);
    foreach (ref cv; corner[]) {
      immutable Float ox = cv.x-centroid.x;
      immutable Float oy = cv.y-centroid.y;
      cv.x = ox*ca-oy*sa+centroid.x;
      cv.y = ox*sa+oy*ca+centroid.y;
    }
    aovalid = false; // invalidate axes
  }

  ///
  void scale() (Float mult) {
    immutable centroid = (corner.ptr[0]+corner.ptr[1]+corner.ptr[2]+corner.ptr[3])/4;
    foreach (ref cv; corner[]) cv = (cv-centroid)*mult+centroid;
    aovalid = false; // invalidate axes
  }

  /// apply transformation matrix, assuming that world (0,0) is at centroid
  void transform() (in auto ref Mat3!VT mat) {
    immutable centroid = (corner.ptr[0]+corner.ptr[1]+corner.ptr[2]+corner.ptr[3])/4;
    foreach (ref VT cv; corner[]) cv -= centroid;
    foreach (ref VT cv; corner[]) cv = cv*mat;
    foreach (ref VT cv; corner[]) cv += centroid;
    aovalid = false; // invalidate axes
  }

  /// returns true if the intersection of the boxes is non-empty
  bool overlaps() (in auto ref Me other) {
    pragma(inline, true);
    if (!aovalid) computeAxes(); // fix axes if necessary
    return (overlaps1Way(other) && other.overlaps1Way(this));
  }
}


// ////////////////////////////////////////////////////////////////////////// //
template IsSphere(ST) {
  static if (is(ST == Sphere!SVT, SVT)) {
    enum IsSphere = IsVector!SVT;
  } else {
    enum IsSphere = false;
  }
}

template IsSphere(ST, VT) {
  static if (is(ST == Sphere!SVT, SVT)) {
    enum IsSphere = (is(VT == SVT) && IsVector!SVT);
  } else {
    enum IsSphere = false;
  }
}


///
struct Sphere(VT) if (IsVector!VT) {
public:
  alias Float = VT.Float;
  alias vec = VT;
  alias Me = typeof(this);

public:
  vec orig; /// sphere origin
  Float radius; /// sphere radius

public nothrow @trusted @nogc:
  this() (in auto ref vec aorig, Float arad) { orig = aorig; radius = arad; }

  @property bool valid () const { import core.stdc.math : isfinite; pragma(inline, true); return (isfinite(radius) && radius > 0); }

  /// sweep test
  bool sweep() (in auto ref vec amove, in auto ref Me sb, Float* u0, Float* u1) const {
    mixin(ImportCoreMath!(Float, "sqrt"));

    immutable odist = sb.orig-this.orig; // vector from A0 to B0
    immutable vab = -amove; // relative velocity (in normalized time)
    immutable rab = this.radius+sb.radius;
    immutable Float a = vab.dot(vab); // u*u coefficient
    immutable Float b = cast(Float)2*vab.dot(odist); // u coefficient
    immutable Float c = odist.dot(odist)-rab*rab; // constant term

    // check if they're currently overlapping
    if (odist.dot(odist) <= rab*rab) {
      if (u0 !is null) *u0 = 0;
      if (u0 !is null) *u1 = 0;
      return true;
    }

    // check if they hit each other during the frame
    immutable Float q = b*b-4*a*c;
    if (q < 0) return false; // alas, complex roots

    immutable Float sq = sqrt(q);
    immutable Float d = cast(Float)1/(cast(Float)2*a);
    Float uu0 = (-b+sq)*d;
    Float uu1 = (-b-sq)*d;

    if (uu0 > uu1) { immutable t = uu0; uu0 = uu1; uu1 = t; } // swap
    if (u0 !is null) *u0 = uu0;
    if (u1 !is null) *u1 = uu1;

    return true;
  }

  // sweep test; if `true` (hit), `hitpos` will be sphere position when it hits this plane, and `u` will be normalized collision time
  bool sweep(PT) (in auto ref PT plane, in auto ref vec3 amove, vec3* hitpos, Float* u) const if (IsPlane3!(PT, Float)) {
    pragma(inline, true);
    return plane.sweep(this, amove, hitpos, u);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
template IsPlane3(PT) {
  static if (is(PT == Plane3!(PFT, eps, swiz), PFT, double eps, bool swiz)) {
    enum IsPlane3 = (is(PFT == float) || is(PFT == double));
  } else {
    enum IsPlane3 = false;
  }
}


template IsPlane3(PT, FT) {
  static if (is(PT == Plane3!(PFT, eps, swiz), PFT, double eps, bool swiz)) {
    enum IsPlane3 = (is(FT == PFT) && (is(PFT == float) || is(PFT == double)));
  } else {
    enum IsPlane3 = false;
  }
}


// plane in 3D space: Ax+By+Cz+D=0
align(1) struct Plane3(FloatType=VFloat, double PlaneEps=-1.0, bool enableSwizzling=true) if (is(FloatType == float) || is(FloatType == double)) {
align(1):
public:
  alias Float = FloatType;
  alias plane3 = typeof(this);
  alias Me = typeof(this);
  alias vec3 = VecN!(3, Float);
  static if (PlaneEps < 0) {
    enum EPS = EPSILON!Float;
  } else {
    enum EPS = cast(Float)PlaneEps;
  }

public:
  alias PType = ubyte;
  enum /*PType*/ {
    Coplanar = 0,
    Front = 1,
    Back = 2,
    Spanning = 3,
  }

public:
  //Float a = 0, b = 0, c = 0, d = 0;
  vec3 normal;
  Float w;

nothrow @safe:
  string toString () const {
    import std.string : format;
    try {
      return "(%s,%s,%s,%s)".format(normal.x, normal.y, normal.z, w);
    } catch (Exception) {
      assert(0);
    }
  }

@nogc:
  this() (in auto ref vec3 aorigin, in auto ref vec3 anormal) { pragma(inline, true); setOriginNormal(aorigin, anormal); }
  this() (in auto ref vec3 anormal, Float aw) { pragma(inline, true); set(anormal, aw); }
  this() (in auto ref vec3 a, in auto ref vec3 b, in auto ref vec3 c) { pragma(inline, true); setFromPoints(a, b, c); }

  @property Float offset () const pure { pragma(inline, true); return -w; }

  void set () (in auto ref vec3 anormal, Float aw) {
    pragma(inline, true);
    normal = anormal;
    w = aw;
  }

  void setOriginNormal () (in auto ref vec3 aorigin, in auto ref vec3 anormal) {
    normal = anormal.normalized;
    //origin = aorigin;
    w = normal.x*aorigin.x+normal.y*aorigin.y+normal.z*aorigin.z;
  }

  void setFromPoints() (in auto ref vec3 a, in auto ref vec3 b, in auto ref vec3 c) @trusted {
    //normal = ((b-a)^(c-a)).normalized;
    immutable vec3 b0 = b-a;
    immutable vec3 c0 = c-a;
    normal = vec3(b0.y*c0.z-b0.z*c0.y, b0.z*c0.x-b0.x*c0.z, b0.x*c0.y-b0.y*c0.x);
    version(none) {
      normal.normalize;
      //x*a.x+y*a.y+z*a.z
      //w = normal*a; // n.dot(a)
      w = normal.x*a.x+normal.y*a.y+normal.z*a.z;
      //immutable ow = w;
      //normalize; // just in case, to tolerate some floating point errors
      //assert(ow == w);
    } else {
      immutable double len = normal.dbllength;
      //{ import core.stdc.stdio; printf("**len=%g\n", len); }
      if (len <= EPSILON!Float) {
        // oops
        //{ import core.stdc.stdio; printf("  OOPS: n=(%g,%g,%g)\n", cast(double)normal.x, cast(double)normal.y, cast(double)normal.z); }
        normal = vec3.Invalid;
        w = vec3.Float.nan;
        return;
      }
      version(vmath_slow_normalize) {
        normal.x /= len;
        normal.y /= len;
        normal.z /= len;
      } else {
        immutable double dd = 1.0/len;
        normal.x *= dd;
        normal.y *= dd;
        normal.z *= dd;
      }
      w = normal.x*a.x+normal.y*a.y+normal.z*a.z;
      /*
      immutable ow = w;
      normalize; // just in case, to tolerate some floating point errors
      assert(ow == w);
      */
    }
    assert(valid);
    //return this;
  }

  @property bool valid () const { pragma(inline, true); import core.stdc.math : isfinite; return (isfinite(w) != 0); }

  Float opIndex (usize idx) const {
    pragma(inline, true);
    return (idx == 0 ? normal.x : idx == 1 ? normal.y : idx == 2 ? normal.z : idx == 3 ? w : Float.nan);
  }

  void opIndexAssign (Float v, usize idx) {
    pragma(inline, true);
    if (idx == 0) normal.x = v; else if (idx == 1) normal.y = v; else if (idx == 2) normal.z = v; else if (idx == 3) w = v;
  }

  ref plane3 normalize () {
    if (!normal.isFinite) {
      normal = vec3.Invalid;
      w = vec3.Float.nan;
      return this;
    }
    version(none) {
      mixin(ImportCoreMath!(Float, "fabs"));
      double dd = normal.dbllength;
      if (fabs(1.0-dd) > EPSILON!Float) {
        version(vmath_slow_normalize) {
          normal.x /= dd;
          normal.y /= dd;
          normal.z /= dd;
          w /= dd;
        } else {
          dd = cast(Float)1/dd;
          normal.x *= dd;
          normal.y *= dd;
          normal.z *= dd;
          w *= dd;
        }
      }
    } else {
      mixin(ImportCoreMath!(double, "sqrt"));
      double dd = sqrt(cast(double)normal.x*cast(double)normal.x+cast(double)normal.y*cast(double)normal.y+cast(double)normal.z*cast(double)normal.z);
      version(vmath_slow_normalize) {
        normal.x /= dd;
        normal.y /= dd;
        normal.z /= dd;
        w /= dd;
      } else {
        dd = 1.0/dd;
        normal.x *= dd;
        normal.y *= dd;
        normal.z *= dd;
        w *= dd;
      }
    }
    return this;
  }

  //WARNING! won't check if this plane is valid
  void flip () {
    pragma(inline, true);
    normal = -normal;
    w = -w;
  }

  //WARNING! won't check if this plane is valid
  plane3 fliped () const {
    pragma(inline, true);
    return plane3(-normal, -w);
  }

  PType pointSide() (in auto ref vec3 p) const {
    pragma(inline, true);
    //immutable Float t = (normal*p)-w; // dot
    immutable double t = cast(double)normal.x*cast(double)p.x+cast(double)normal.y*cast(double)p.y+cast(double)normal.z*cast(double)p.z-cast(double)w;
    return (t < -EPS ? Back : (t > EPS ? Front : Coplanar));
  }

  double pointSideD() (in auto ref vec3 p) const {
    pragma(inline, true);
    //return (normal*p)-w; // dot
    return cast(double)normal.x*cast(double)p.x+cast(double)normal.y*cast(double)p.y+cast(double)normal.z*cast(double)p.z-cast(double)w;
  }

  Float pointSideF() (in auto ref vec3 p) const {
    pragma(inline, true);
    //return (normal*p)-w; // dot
    return cast(Float)(cast(double)normal.x*cast(double)p.x+cast(double)normal.y*cast(double)p.y+cast(double)normal.z*cast(double)p.z-cast(double)w);
  }

  // distance from point to plane
  // plane must be normalized
  double dbldistance() (in auto ref vec3 p) const {
    pragma(inline, true);
    return (cast(double)normal.x*p.x+cast(double)normal.y*p.y+cast(double)normal.z*cast(double)p.z)/normal.dbllength;
  }

  // distance from point to plane
  // plane must be normalized
  Float distance() (in auto ref vec3 p) const {
    pragma(inline, true);
    return cast(Float)dbldistance;
  }

  // "land" point onto the plane
  // plane must be normalized
  vec3 landAlongNormal() (in auto ref vec3 p) const {
    pragma(inline, true);
    mixin(ImportCoreMath!(Float, "fabs"));
    immutable double pdist = pointSideF(p);
    return (fabs(pdist) > EPSILON!Float ? p-normal*pdist : p);
  }

  // "land" point onto the plane
  // plane must be normalized
  /*
  vec3 land() (in auto ref vec3 p) const {
    mixin(ImportCoreMath!(double, "fabs"));
    // distance from point to plane
    double pdist = (cast(double)normal.x*p.x+cast(double)normal.y*p.y+cast(double)normal.z*cast(double)p.z)/normal.dbllength;
    // just-in-case check
    if (fabs(pdist) > EPSILON!double) {
      // get side
      return p+normal*pdist;
    } else {
      // on the plane
      return p;
    }
  }
  */

  // plane must be normalized
  vec3 project() (in auto ref vec3 v) const {
    pragma(inline, true);
    mixin(ImportCoreMath!(double, "fabs"));
    return v-(v-normal*w).dot(normal)*normal;
  }

  // returns the point where the line p0-p1 intersects this plane
  vec3 lineIntersect() (in auto ref vec3 p0, in auto ref vec3 p1) const {
    pragma(inline, true);
    immutable dif = p1-p0;
    immutable t = (w-normal.dot(p0))/normal.dot(dif);
    return p0+(dif*t);
  }

  // swizzling
  static if (enableSwizzling) auto opDispatch(string fld) () if (isGoodSwizzling!(fld, "xyzw", 2, 3)) {
    static if (fld.length == 2) {
      return mixin(SwizzleCtor!("vec2", fld));
    } else {
      return mixin(SwizzleCtor!("vec3", fld));
    }
  }

  // sweep test; if `true` (hit), `hitpos` will be sphere position when it hits this plane, and `u` will be normalized collision time
  bool sweep(ST) (in auto ref ST sphere, in auto ref vec3 amove, vec3* hitpos, Float* u) const if (IsSphere!(ST, vec3)) {
    mixin(ImportCoreMath!(Float, "fabs"));
    immutable c0 = sphere.orig;
    immutable c1 = c0+amove;
    immutable Float r = sphere.radius;
    immutable Float d0 = (normal*c0)+w;
    immutable Float d1 = (normal*c1)+w;
    // check if the sphere is touching the plane
    if (fabs(d0) <= r) {
      if (hitpos !is null) *hitpos = c0;
      if (u !is null) *u = 0;
      return true;
    }
    // check if the sphere penetrated during movement
    if (d0 > r && d1 < r) {
      immutable Float uu = (d0-r)/(d0-d1); // normalized time
      if (u !is null) *u = uu;
      if (hitpos !is null) *hitpos = (1-uu)*c0+uu*c1; // point of first contact
      return true;
    }
    // no collision
    return false;
  }

  // intersection of 3 planes, Graphics Gems 1 pg 305
  auto intersectionPoint() (in auto ref plane3 plane2, in auto ref plane3 plane3) const {
    mixin(ImportCoreMath!(Float, "fabs"));
    alias plane1 = this;
    immutable Float det = plane1.normal.cross(plane2.normal).dot(plane3.normal);
    // if the determinant is 0, that means parallel planes, no intersection
    if (fabs(det) < EPSILON!Float) return vec3.Invalid;
    return
      (plane2.normal.cross(plane3.normal)*(-plane1.w)+
       plane3.normal.cross(plane1.normal)*(-plane2.w)+
       plane1.normal.cross(plane2.normal)*(-plane3.w))/det;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
struct Ray(VT) if (IsVector!VT) {
public:
  alias vec = VT;
  alias Float = VT.Float;

public:
  VT orig, dir; // dir should be normalized (setters does this)

nothrow @safe:
  string toString () const {
    import std.format : format;
    try {
      return "[(%s,%s):(%s,%s)]".format(orig.x, orig.y, dir.x, dir.y);
    } catch (Exception) {
      assert(0);
    }
  }

@nogc:
  this (VT.Float x, VT.Float y, VT.Float angle) { pragma(inline, true); setOrigDir(x, y, angle); }
  this() (in auto ref VT aorg, VT.Float angle) { pragma(inline, true); setOrigDir(aorg, angle); }

  static Ray!VT fromPoints() (in auto ref VT p0, in auto ref VT p1) {
    pragma(inline, true);
    Ray!VT res;
    res.orig = p0;
    res.dir = (p1-p0).normalized;
    return res;
  }

  static if (VT.Dims == 2) void setOrigDir (VT.Float x, VT.Float y, VT.Float angle) {
    pragma(inline, true);
    mixin(ImportCoreMath!(Float, "cos", "sin"));
    orig.x = x;
    orig.y = y;
    dir.x = cos(angle);
    dir.y = sin(angle);
  }

  static if (VT.Dims == 2) void setOrigDir() (in auto ref VT aorg, VT.Float angle) {
    pragma(inline, true);
    mixin(ImportCoreMath!(Float, "cos", "sin"));
    orig.x = aorg.x;
    orig.y = aorg.y;
    dir.x = cos(angle);
    dir.y = sin(angle);
  }

  static if (VT.Dims == 2) void setOrig (VT.Float x, VT.Float y) {
    pragma(inline, true);
    orig.x = x;
    orig.y = y;
  }

  void setOrig() (in auto ref VT aorg) {
    pragma(inline, true);
    orig.x = aorg.x;
    orig.y = aorg.y;
    static if (VT.Dims == 3) orig.z = aorg.z;
  }

  static if (VT.Dims == 2) void setDir (VT.Float angle) {
    pragma(inline, true);
    mixin(ImportCoreMath!(Float, "cos", "sin"));
    dir.x = cos(angle);
    dir.y = sin(angle);
  }

  @property VT right () const {
    pragma(inline, true);
    static if (VT.Dims == 2) return VT(dir.y, -dir.x);
    else return VT(dir.y, -dir.x, dir.z);
  }

  VT pointAt (VT.Float len) const { pragma(inline, true); return orig+dir*len; }
}


// ////////////////////////////////////////////////////////////////////////// //
public struct AABBImpl(VT) if (IsVector!VT) {
private:
  static T nmin(T) (in T a, in T b) { pragma(inline, true); return (a < b ? a : b); }
  static T nmax(T) (in T a, in T b) { pragma(inline, true); return (a > b ? a : b); }

public:
  alias VType = VT;
  alias Float = VT.Float;
  alias Me = typeof(this);

public:
  //VT center;
  //VT half; // should be positive
  VT min, max;

public:
  string toString () const {
    import std.format : format;
    return "[%s-%s]".format(min, max);
  }

public nothrow @safe @nogc:
  this() (in auto ref VT amin, in auto ref VT amax) {
    pragma(inline, true);
    //center = (amin+amax)/2;
    //half = VT((nmax(amin.x, amax.x)-nmin(amin.x, amax.x))/2, (nmax(amin.y, amax.y)-nmin(amin.y, amax.y))/2);
    version(none) {
      // this breaks VecN ctor inliner (fuck!)
      static if (VT.Dims == 2) {
        min = VT(nmin(amin.x, amax.x), nmin(amin.y, amax.y));
        max = VT(nmax(amin.x, amax.x), nmax(amin.y, amax.y));
      } else {
        min = VT(nmin(amin.x, amax.x), nmin(amin.y, amax.y), nmin(amin.z, amax.z));
        max = VT(nmax(amin.x, amax.x), nmax(amin.y, amax.y), nmax(amin.z, amax.z));
      }
    } else {
      min.x = nmin(amin.x, amax.x);
      min.y = nmin(amin.y, amax.y);
      static if (VT.Dims == 3) min.z = nmin(amin.z, amax.z);
      max.x = nmax(amin.x, amax.x);
      max.y = nmax(amin.y, amax.y);
      static if (VT.Dims == 3) max.z = nmax(amin.z, amax.z);
    }
  }

  void reset () {
    static if (VT.Dims == 2) {
      min = VT(+VT.Float.infinity, +VT.Float.infinity);
      max = VT(-VT.Float.infinity, -VT.Float.infinity);
    } else {
      min = VT(+VT.Float.infinity, +VT.Float.infinity, +VT.Float.infinity);
      max = VT(-VT.Float.infinity, -VT.Float.infinity, -VT.Float.infinity);
    }
  }

  void setMinMax() (in auto ref VT amin, in auto ref VT amax) pure {
    pragma(inline, true);
    version(none) {
      // this breaks VecN ctor inliner (fuck!)
      static if (VT.Dims == 2) {
        min = VT(nmin(amin.x, amax.x), nmin(amin.y, amax.y));
        max = VT(nmax(amin.x, amax.x), nmax(amin.y, amax.y));
      } else {
        min = VT(nmin(amin.x, amax.x), nmin(amin.y, amax.y), nmin(amin.z, amax.z));
        max = VT(nmax(amin.x, amax.x), nmax(amin.y, amax.y), nmax(amin.z, amax.z));
      }
    } else {
      min.x = nmin(amin.x, amax.x);
      min.y = nmin(amin.y, amax.y);
      static if (VT.Dims == 3) min.z = nmin(amin.z, amax.z);
      max.x = nmax(amin.x, amax.x);
      max.y = nmax(amin.y, amax.y);
      static if (VT.Dims == 3) max.z = nmax(amin.z, amax.z);
    }
  }

  //@property VT min () const pure { pragma(inline, true); return center-half; }
  //@property VT max () const pure { pragma(inline, true); return center+half; }

  VT center () const pure { pragma(inline, true); return (min+max)/2; }
  VT extent () const pure { pragma(inline, true); return max-min; }

  //@property valid () const { pragma(inline, true); return center.isFinite && half.isFinite; }
  @property valid () const {
    pragma(inline, true);
    static if (VT.Dims == 2) {
      return (min.isFinite && max.isFinite && min.x <= max.x && min.y <= max.y);
    } else {
      return (min.isFinite && max.isFinite && min.x <= max.x && min.y <= max.y && min.z <= max.z);
    }
  }

  // return the volume of the AABB
  @property Float volume () const {
    pragma(inline, true);
    immutable diff = max-min;
    static if (VT.Dims == 3) {
      return diff.x*diff.y*diff.z;
    } else {
      return diff.x*diff.y;
    }
  }

  static auto mergeAABBs() (in auto ref Me aabb1, in auto ref Me aabb2) {
    typeof(this) res;
    res.merge(aabb1, aabb2);
    return res;
  }

  void merge() (in auto ref Me aabb1, in auto ref Me aabb2) {
    pragma(inline, true);
    min.x = nmin(aabb1.min.x, aabb2.min.x);
    min.y = nmin(aabb1.min.y, aabb2.min.y);
    max.x = nmax(aabb1.max.x, aabb2.max.x);
    max.y = nmax(aabb1.max.y, aabb2.max.y);
    static if (VT.Dims == 3) {
      min.z = nmin(aabb1.min.z, aabb2.min.z);
      max.z = nmax(aabb1.max.z, aabb2.max.z);
    }
  }

  void merge() (in auto ref Me aabb1) {
    pragma(inline, true);
    min.x = nmin(aabb1.min.x, min.x);
    min.y = nmin(aabb1.min.y, min.y);
    max.x = nmax(aabb1.max.x, max.x);
    max.y = nmax(aabb1.max.y, max.y);
    static if (VT.Dims == 3) {
      min.z = nmin(aabb1.min.z, min.z);
      max.z = nmax(aabb1.max.z, max.z);
    }
  }

  void addPoint() (in auto ref VT v) {
    min.x = nmin(min.x, v.x);
    max.x = nmax(max.x, v.x);
    min.y = nmin(min.y, v.y);
    max.y = nmax(max.y, v.y);
    static if (VT.Dims == 3) {
      min.z = nmin(min.z, v.z);
      max.z = nmax(max.z, v.z);
    }
  }

  void opOpAssign(string op:"~") (in auto ref VT v) { pragma(inline, true); addPoint(v); }
  void opOpAssign(string op:"~") (in auto ref Me aabb1) { pragma(inline, true); merge(aabb1); }

  // return true if the current AABB contains the AABB given in parameter
  bool contains() (in auto ref Me aabb) const {
    //pragma(inline, true);
    static if (VT.Dims == 3) {
      return
        aabb.min.x >= min.x && aabb.min.y >= min.y && aabb.min.z >= min.z &&
        aabb.max.x <= max.x && aabb.max.y <= max.y && aabb.max.z <= max.z;
    } else {
      return
        aabb.min.x >= min.x && aabb.min.y >= min.y &&
        aabb.max.x <= max.x && aabb.max.y <= max.y;
    }
  }

  bool contains() (in auto ref VT p) const {
    pragma(inline, true);
    static if (VT.Dims == 2) {
      return (p.x >= min.x && p.y >= min.y && p.x <= max.x && p.y <= max.y);
    } else {
      return (p.x >= min.x && p.y >= min.y && p.z >= min.z && p.x <= max.x && p.y <= max.y && p.z <= max.z);
    }
  }

  // extrude bbox a little, to compensate floating point inexactness
  /*
  void extrude (Float delta) pure {
    min.x -= delta;
    min.y -= delta;
    static if (VT.Dims == 3) min.z -= delta;
    max.x += delta;
    max.y += delta;
    static if (VT.Dims == 3) max.z += delta;
  }
  */

  // return true if the current AABB is overlapping with the AABB in parameter
  // two AABBs overlap if they overlap in the two(three) x, y (and z) axes at the same time
  bool overlaps() (in auto ref Me aabb) const {
    //pragma(inline, true);
    // exit with no intersection if found separated along any axis
    if (max.x < aabb.min.x || min.x > aabb.max.x) return false;
    if (max.y < aabb.min.y || min.y > aabb.max.y) return false;
    static if (VT.Dims == 3) {
      if (max.z < aabb.min.z || min.z > aabb.max.z) return false;
    }
    return true;
  }

  // ////////////////////////////////////////////////////////////////////////// //
  // something to consider here is that 0 * inf =nan which occurs when the ray starts exactly on the edge of a box
  // rd: ray direction, normalized
  // https://tavianator.com/fast-branchless-raybounding-box-intersections-part-2-nans/
  static bool intersects() (in auto ref VT bmin, in auto ref VT bmax, in auto ref Ray!VT ray, Float* tmino=null, Float* tmaxo=null) {
    // ok with coplanars, but dmd sux at unrolled loops
    // do X
    immutable Float dinvp0 = cast(Float)1/ray.dir.x; // 1/0 will produce inf
    immutable Float t1p0 = (bmin.x-ray.orig.x)*dinvp0;
    immutable Float t2p0 = (bmax.x-ray.orig.x)*dinvp0;
    Float tmin = nmin(t1p0, t2p0);
    Float tmax = nmax(t1p0, t2p0);
    // do Y
    {
      immutable Float dinv = cast(Float)1/ray.dir.y; // 1/0 will produce inf
      immutable Float t1 = (bmin.y-ray.orig.y)*dinv;
      immutable Float t2 = (bmax.y-ray.orig.y)*dinv;
      tmin = nmax(tmin, nmin(nmin(t1, t2), tmax));
      tmax = nmin(tmax, nmax(nmax(t1, t2), tmin));
    }
    // do Z
    static if (VT.Dims == 3) {
      {
        immutable Float dinv = cast(Float)1/ray.dir.z; // 1/0 will produce inf
        immutable Float t1 = (bmin.z-ray.orig.z)*dinv;
        immutable Float t2 = (bmax.z-ray.orig.z)*dinv;
        tmin = nmax(tmin, nmin(nmin(t1, t2), tmax));
        tmax = nmin(tmax, nmax(nmax(t1, t2), tmin));
      }
    }
    if (tmax > nmax(tmin, cast(Float)0)) {
      if (tmino !is null) *tmino = tmin;
      if (tmaxo !is null) *tmaxo = tmax;
      return true;
    } else {
      return false;
    }
  }

  bool intersects() (in auto ref Ray!VT ray, Float* tmino=null, Float* tmaxo=null) const @trusted {
    // ok with coplanars, but dmd sux at unrolled loops
    // do X
    immutable Float dinvp0 = cast(Float)1/ray.dir.x; // 1/0 will produce inf
    immutable Float t1p0 = (min.x-ray.orig.x)*dinvp0;
    immutable Float t2p0 = (max.x-ray.orig.x)*dinvp0;
    Float tmin = nmin(t1p0, t2p0);
    Float tmax = nmax(t1p0, t2p0);
    // do Y
    {
      immutable Float dinv = cast(Float)1/ray.dir.y; // 1/0 will produce inf
      immutable Float t1 = (min.y-ray.orig.y)*dinv;
      immutable Float t2 = (max.y-ray.orig.y)*dinv;
      tmin = nmax(tmin, nmin(nmin(t1, t2), tmax));
      tmax = nmin(tmax, nmax(nmax(t1, t2), tmin));
    }
    // do Z
    static if (VT.Dims == 3) {
      {
        immutable Float dinv = cast(Float)1/ray.dir.z; // 1/0 will produce inf
        immutable Float t1 = (min.z-ray.orig.z)*dinv;
        immutable Float t2 = (max.z-ray.orig.z)*dinv;
        tmin = nmax(tmin, nmin(nmin(t1, t2), tmax));
        tmax = nmin(tmax, nmax(nmax(t1, t2), tmin));
      }
    }
    if (tmax > nmax(tmin, cast(Float)0)) {
      if (tmino !is null) *tmino = tmin;
      if (tmaxo !is null) *tmaxo = tmax;
      return true;
    } else {
      return false;
    }
  }

  Float segIntersectMin() (in auto ref VT a, in auto ref VT b) const @trusted {
    Float tmin;
    if (!intersects(Ray!VT.fromPoints(a, b), &tmin)) return -1;
    if (tmin < 0) return 0; // inside
    if (tmin*tmin > (b-a).lengthSquared) return -1;
    return tmin;
  }

  Float segIntersectMax() (in auto ref VT a, in auto ref VT b) const @trusted {
    Float tmax;
    if (!intersects(Ray!VT.fromPoints(a, b), null, &tmax)) return -1;
    if (tmax*tmax > (b-a).lengthSquared) return -1;
    return tmax;
  }

  bool isIntersects() (in auto ref VT a, in auto ref VT b) const @trusted {
    // it may be faster to first check if start or end point is inside AABB (this is sometimes enough for dyntree)
    static if (VT.Dims == 2) {
      if (a.x >= min.x && a.y >= min.y && a.x <= max.x && a.y <= max.y) return true; // a
      if (b.x >= min.x && b.y >= min.y && b.x <= max.x && b.y <= max.y) return true; // b
    } else {
      if (a.x >= min.x && a.y >= min.y && a.z >= min.z && a.x <= max.x && a.y <= max.y && a.z <= max.z) return true; // a
      if (b.x >= min.x && b.y >= min.y && b.z >= min.z && b.x <= max.x && b.y <= max.y && b.z <= max.z) return true; // b
    }
    // nope, do it hard way
    Float tmin;
    if (!intersects(Ray!VT.fromPoints(a, b), &tmin)) return false;
    if (tmin < 0) return true; // inside, just in case
    return (tmin*tmin <= (b-a).lengthSquared);
  }

  ref inout(VT) opIndex (usize idx) inout {
    pragma(inline, true);
    return (idx == 0 ? min : max);
  }

  /// sweep two AABB's to see if and when they are overlapping
  /// returns `true` if collision was detected (or boxes overlaps)
  /// u0 = normalized time of first collision (i.e. collision starts at myMove*u0)
  /// u1 = normalized time of second collision (i.e. collision stops after myMove*u1)
  /// hitnormal = normal that will move `this` apart of `b` edge it collided with
  /// no output values are valid if no collision was detected
  /// WARNING! hit normal calculation is not tested!
  bool sweep() (in auto ref VT myMove, in auto ref Me b, Float* u0, VT* hitnormal=null, Float* u1=null) const @trusted {
    // check if they are overlapping right now
    if (this.overlaps(b)) {
      if (u0 !is null) *u0 = 0;
      if (u1 !is null) *u1 = 0;
      if (hitnormal !is null) *hitnormal = VT(); // oops
      return true;
    }

    immutable v = -myMove; // treat b as stationary, so invert v to get relative velocity

    // not moving, and not overlapping
    if (v.isZero) return false;

    Float hitTime = 0;
    Float outTime = 1;
    Float[VT.Dims] overlapTime = 0;

    alias a = this;
    foreach (immutable aidx; 0..VT.Dims) {
      // axis overlap
      immutable Float vv = v[aidx];
      if (vv < 0) {
        immutable Float invv = cast(Float)1/vv;
        if (b.max[aidx] < a.min[aidx]) return false;
        if (b.max[aidx] > a.min[aidx]) outTime = nmin((a.min[aidx]-b.max[aidx])*invv, outTime);
        if (a.max[aidx] < b.min[aidx]) hitTime = nmax((overlapTime.ptr[aidx] = (a.max[aidx]-b.min[aidx])*invv), hitTime);
        if (hitTime > outTime) return false;
      } else if (vv > 0) {
        immutable Float invv = cast(Float)1/vv;
        if (b.min[aidx] > a.max[aidx]) return false;
        if (a.max[aidx] > b.min[aidx]) outTime = nmin((a.max[aidx]-b.min[aidx])*invv, outTime);
        if (b.max[aidx] < a.min[aidx]) hitTime = nmax((overlapTime.ptr[aidx] = (a.min[aidx]-b.max[aidx])*invv), hitTime);
        if (hitTime > outTime) return false;
      }
    }

    if (u0 !is null) *u0 = hitTime;
    if (u1 !is null) *u1 = outTime;

    // hit normal is along axis with the highest overlap time
    if (hitnormal !is null) {
      static if (VT.Dims == 3) {
        int aidx = 0;
        if (overlapTime.ptr[1] > overlapTime.ptr[0]) aidx = 1;
        if (overlapTime.ptr[2] > overlapTime.ptr[aidx]) aidx = 2;
        VT hn; // zero vector
        hn[aidx] = (v[aidx] < 0 ? -1 : v[aidx] > 0 ? 1 : 0);
        *hitnormal = hn;
      } else {
        if (overlapTime.ptr[0] > overlapTime.ptr[1]) {
          *hitnormal = VT((v.x < 0 ? -1 : v.x > 0 ? 1 : 0), 0);
        } else {
          *hitnormal = VT(0, (v.y < 0 ? -1 : v.y > 0 ? 1 : 0));
        }
      }
    }

    return true;

    /+
    version(none) {
      auto u_0 = VT(0, 0, 0); // first times of overlap along each axis
      auto u_1 = VT(1, 1, 1); // last times of overlap along each axis
      bool wasHit = false;

      // find the possible first and last times of overlap along each axis
      foreach (immutable idx; 0..VT.Dims) {
        Float dinv = v[idx];
        if (dinv != 0) {
          dinv = cast(Float)1/dinv;
          if (this.max[idx] < b.min[idx] && dinv < 0) {
            u_0[idx] = (this.max[idx]-b.min[idx])*dinv;
            wasHit = true;
          } else if (b.max[idx] < this.min[idx] && dinv > 0) {
            u_0[idx] = (this.min[idx]-b.max[idx])*dinv;
            wasHit = true;
          }
          if (b.max[idx] > this.min[idx] && dinv < 0) {
            u_1[idx] = (this.min[idx]-b.max[idx])*dinv;
            wasHit = true;
          } else if (this.max[idx] > b.min[idx] && dinv > 0) {
            u_1[idx] = (this.max[idx]-b.min[idx])*dinv;
            wasHit = true;
          }
        }
      }

      // oops
      if (!wasHit) {
        if (u0 !is null) *u0 = 0;
        if (u1 !is null) *u1 = 0;
        return false;
      }

      static if (VT.Dims == 3) {
        immutable Float uu0 = nmax(u_0.x, nmax(u_0.y, u_0.z)); // possible first time of overlap
        immutable Float uu1 = nmin(u_1.x, nmin(u_1.y, u_1.z)); // possible last time of overlap
      } else {
        immutable Float uu0 = nmax(u_0.x, u_0.y); // possible first time of overlap
        immutable Float uu1 = nmin(u_1.x, u_1.y); // possible last time of overlap
      }

      if (u0 !is null) *u0 = uu0;
      if (u1 !is null) *u1 = uu1;

      // they could have only collided if the first time of overlap occurred before the last time of overlap
      return (uu0 <= uu1);
    }
    +/
  }

  /// check to see if the sphere overlaps the AABB
  bool overlaps(ST) (in auto ref ST sphere) if (IsSphere!(ST, VT)) { pragma(inline, true); return overlapsSphere(sphere.orig, sphere.radius); }

  /// check to see if the sphere overlaps the AABB
  bool overlapsSphere() (in auto ref VT center, Float radius) {
    Float d = 0;
    // find the square of the distance from the sphere to the box
    foreach (immutable idx; 0..VT.Dims) {
      if (center[idx] < min[idx]) {
        immutable Float s = center[idx]-min[idx];
        d += s*s;
      } else if (center[idx] > max[idx]) {
        immutable Float s = center[idx]-max[idx];
        d += s*s;
      }
    }
    return (d <= radius*radius);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
/* Dynamic AABB tree (bounding volume hierarchy)
 * based on the code from ReactPhysics3D physics library, http://www.reactphysics3d.com
 * Copyright (c) 2010-2016 Daniel Chappuis
 *
 * This software is provided 'as-is', without any express or implied warranty.
 * In no event will the authors be held liable for any damages arising from the
 * use of this software.
 *
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 *
 * 1. The origin of this software must not be misrepresented; you must not claim
 *    that you wrote the original software. If you use this software in a
 *    product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 *
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 *
 * 3. This notice may not be removed or altered from any source distribution.
 */
/* WARNING! BY DEFAULT TREE WILL NOT PROTECT OBJECTS FROM GC! */
// ////////////////////////////////////////////////////////////////////////// //
/*
 * This class implements a dynamic AABB tree that is used for broad-phase
 * collision detection. This data structure is inspired by Nathanael Presson's
 * dynamic tree implementation in BulletPhysics. The following implementation is
 * based on the one from Erin Catto in Box2D as described in the book
 * "Introduction to Game Physics with Box2D" by Ian Parberry.
 */
/// Dynamic AABB Tree: can be used to speed up broad phase in various engines
/// GCAnchor==true: add nodes as GC roots; you won't need it if you're storing nodes in some other way
public final class DynamicAABBTree(VT, BodyBase, bool GCAnchor=false) if (IsVector!VT && is(BodyBase == class)) {
private:
  static T min(T) (in T a, in T b) { pragma(inline, true); return (a < b ? a : b); }
  static T max(T) (in T a, in T b) { pragma(inline, true); return (a > b ? a : b); }

public:
  alias VType = VT;
  alias Float = VT.Float;
  alias Me = typeof(this);
  alias AABB = AABBImpl!VT;

  enum FloatNum(Float v) = cast(Float)v;

public:
  // in the broad-phase collision detection (dynamic AABB tree), the AABBs are
  // also inflated in direction of the linear motion of the body by mutliplying the
  // followin constant with the linear velocity and the elapsed time between two frames
  enum Float LinearMotionGapMultiplier = FloatNum!(1.7);

public:
  // called when a overlapping node has been found during the call to forEachAABBOverlap()
  // return `true` to stop
  alias OverlapCallback = void delegate (BodyBase abody);
  alias SimpleQueryCallback = bool delegate (BodyBase abody);
  alias SimpleQueryCallbackNR = void delegate (BodyBase abody);
  alias SegQueryCallback = Float delegate (BodyBase abody, in ref VT a, in ref VT b); // return dist from a to abody

private:
  align(1) struct TreeNode {
  align(1):
    enum NullTreeNode = -1;
    enum { Left = 0, Right = 1 }
    // a node is either in the tree (has a parent) or in the free nodes list (has a next node)
    union {
      int parentId;
      int nextNodeId;
    }
    // a node is either a leaf (has data) or is an internal node (has children)
    union {
      int[2] children; /// left and right child of the node (children[0] = left child)
      BodyBase flesh;
    }
    // height of the node in the tree (-1 for free nodes)
    short height;
    // fat axis aligned bounding box (AABB) corresponding to the node
    AABBImpl!VT aabb;
    // return true if the node is a leaf of the tree
    @property const pure nothrow @safe @nogc {
      bool leaf () { pragma(inline, true); return (height == 0); }
      bool free () { pragma(inline, true); return (height == -1); }
    }
  }

private:
  TreeNode* mNodes; // pointer to the memory location of the nodes of the tree
  int mRootNodeId; // id of the root node of the tree
  int mFreeNodeId; // id of the first node of the list of free (allocated) nodes in the tree that we can use
  int mAllocCount; // number of allocated nodes in the tree
  int mNodeCount; // number of nodes in the tree

  // extra AABB Gap used to allow the collision shape to move a little bit
  // without triggering a large modification of the tree which can be costly
  Float mExtraGap;

private:
  // allocate and return a node to use in the tree
  int allocateNode () {
    // if there is no more allocated node to use
    if (mFreeNodeId == TreeNode.NullTreeNode) {
      import core.stdc.stdlib : realloc;
      version(aabbtree_many_asserts) assert(mNodeCount == mAllocCount);
      // allocate more nodes in the tree
      auto newsz = (mAllocCount < 8192 ? mAllocCount*2 : mAllocCount+8192);
      TreeNode* nn = cast(TreeNode*)realloc(mNodes, newsz*TreeNode.sizeof);
      if (nn is null) assert(0, "out of memory");
      //{ import core.stdc.stdio; printf("realloced: old=%u; new=%u\n", mAllocCount, newsz); }
      mAllocCount = newsz;
      mNodes = nn;
      // initialize the allocated nodes
      foreach (int i; mNodeCount..mAllocCount-1) {
        mNodes[i].nextNodeId = i+1;
        mNodes[i].height = -1;
      }
      mNodes[mAllocCount-1].nextNodeId = TreeNode.NullTreeNode;
      mNodes[mAllocCount-1].height = -1;
      mFreeNodeId = mNodeCount;
    }
    // get the next free node
    int freeNodeId = mFreeNodeId;
    version(aabbtree_many_asserts) assert(freeNodeId < mAllocCount);
    mFreeNodeId = mNodes[freeNodeId].nextNodeId;
    mNodes[freeNodeId].parentId = TreeNode.NullTreeNode;
    mNodes[freeNodeId].height = 0;
    ++mNodeCount;
    return freeNodeId;
  }

  // release a node
  void releaseNode (int nodeId) {
    version(aabbtree_many_asserts) assert(mNodeCount > 0);
    version(aabbtree_many_asserts) assert(nodeId >= 0 && nodeId < mAllocCount);
    version(aabbtree_many_asserts) assert(mNodes[nodeId].height >= 0);
    mNodes[nodeId].nextNodeId = mFreeNodeId;
    mNodes[nodeId].height = -1;
    mFreeNodeId = nodeId;
    --mNodeCount;
  }

  // insert a leaf node in the tree
  // the process of inserting a new leaf node in the dynamic tree is described in the book "Introduction to Game Physics with Box2D" by Ian Parberry
  void insertLeafNode (int nodeId) {
    // if the tree is empty
    if (mRootNodeId == TreeNode.NullTreeNode) {
      mRootNodeId = nodeId;
      mNodes[mRootNodeId].parentId = TreeNode.NullTreeNode;
      return;
    }

    version(aabbtree_many_asserts) assert(mRootNodeId != TreeNode.NullTreeNode);

    // find the best sibling node for the new node
    AABB newNodeAABB = mNodes[nodeId].aabb;
    int currentNodeId = mRootNodeId;
    while (!mNodes[currentNodeId].leaf) {
      int leftChild = mNodes[currentNodeId].children.ptr[TreeNode.Left];
      int rightChild = mNodes[currentNodeId].children.ptr[TreeNode.Right];

      // compute the merged AABB
      Float volumeAABB = mNodes[currentNodeId].aabb.volume;
      AABB mergedAABBs = AABB.mergeAABBs(mNodes[currentNodeId].aabb, newNodeAABB);
      Float mergedVolume = mergedAABBs.volume;

      // compute the cost of making the current node the sibling of the new node
      Float costS = FloatNum!2*mergedVolume;

      // compute the minimum cost of pushing the new node further down the tree (inheritance cost)
      Float costI = FloatNum!2*(mergedVolume-volumeAABB);

      // compute the cost of descending into the left child
      AABB currentAndLeftAABB = AABB.mergeAABBs(newNodeAABB, mNodes[leftChild].aabb);
      Float costLeft = currentAndLeftAABB.volume+costI;
      if (!mNodes[leftChild].leaf) costLeft -= mNodes[leftChild].aabb.volume;

      // compute the cost of descending into the right child
      AABB currentAndRightAABB = AABB.mergeAABBs(newNodeAABB, mNodes[rightChild].aabb);
      Float costRight = currentAndRightAABB.volume+costI;
      if (!mNodes[rightChild].leaf) costRight -= mNodes[rightChild].aabb.volume;

      // if the cost of making the current node a sibling of the new node is smaller than the cost of going down into the left or right child
      if (costS < costLeft && costS < costRight) break;

      // it is cheaper to go down into a child of the current node, choose the best child
      currentNodeId = (costLeft < costRight ? leftChild : rightChild);
    }

    int siblingNode = currentNodeId;

    // create a new parent for the new node and the sibling node
    int oldParentNode = mNodes[siblingNode].parentId;
    int newParentNode = allocateNode();
    mNodes[newParentNode].parentId = oldParentNode;
    mNodes[newParentNode].aabb.merge(mNodes[siblingNode].aabb, newNodeAABB);
    mNodes[newParentNode].height = cast(short)(mNodes[siblingNode].height+1);
    version(aabbtree_many_asserts) assert(mNodes[newParentNode].height > 0);

    // if the sibling node was not the root node
    if (oldParentNode != TreeNode.NullTreeNode) {
      version(aabbtree_many_asserts) assert(!mNodes[oldParentNode].leaf);
      if (mNodes[oldParentNode].children.ptr[TreeNode.Left] == siblingNode) {
        mNodes[oldParentNode].children.ptr[TreeNode.Left] = newParentNode;
      } else {
        mNodes[oldParentNode].children.ptr[TreeNode.Right] = newParentNode;
      }
      mNodes[newParentNode].children.ptr[TreeNode.Left] = siblingNode;
      mNodes[newParentNode].children.ptr[TreeNode.Right] = nodeId;
      mNodes[siblingNode].parentId = newParentNode;
      mNodes[nodeId].parentId = newParentNode;
    } else {
      // if the sibling node was the root node
      mNodes[newParentNode].children.ptr[TreeNode.Left] = siblingNode;
      mNodes[newParentNode].children.ptr[TreeNode.Right] = nodeId;
      mNodes[siblingNode].parentId = newParentNode;
      mNodes[nodeId].parentId = newParentNode;
      mRootNodeId = newParentNode;
    }

    // move up in the tree to change the AABBs that have changed
    currentNodeId = mNodes[nodeId].parentId;
    version(aabbtree_many_asserts) assert(!mNodes[currentNodeId].leaf);
    while (currentNodeId != TreeNode.NullTreeNode) {
      // balance the sub-tree of the current node if it is not balanced
      currentNodeId = balanceSubTreeAtNode(currentNodeId);
      version(aabbtree_many_asserts) assert(mNodes[nodeId].leaf);

      version(aabbtree_many_asserts) assert(!mNodes[currentNodeId].leaf);
      int leftChild = mNodes[currentNodeId].children.ptr[TreeNode.Left];
      int rightChild = mNodes[currentNodeId].children.ptr[TreeNode.Right];
      version(aabbtree_many_asserts) assert(leftChild != TreeNode.NullTreeNode);
      version(aabbtree_many_asserts) assert(rightChild != TreeNode.NullTreeNode);

      // recompute the height of the node in the tree
      mNodes[currentNodeId].height = cast(short)(max(mNodes[leftChild].height, mNodes[rightChild].height)+1);
      version(aabbtree_many_asserts) assert(mNodes[currentNodeId].height > 0);

      // recompute the AABB of the node
      mNodes[currentNodeId].aabb.merge(mNodes[leftChild].aabb, mNodes[rightChild].aabb);

      currentNodeId = mNodes[currentNodeId].parentId;
    }

    version(aabbtree_many_asserts) assert(mNodes[nodeId].leaf);
  }

  // remove a leaf node from the tree
  void removeLeafNode (int nodeId) {
    version(aabbtree_many_asserts) assert(nodeId >= 0 && nodeId < mAllocCount);
    version(aabbtree_many_asserts) assert(mNodes[nodeId].leaf);

    // if we are removing the root node (root node is a leaf in this case)
    if (mRootNodeId == nodeId) { mRootNodeId = TreeNode.NullTreeNode; return; }

    int parentNodeId = mNodes[nodeId].parentId;
    int grandParentNodeId = mNodes[parentNodeId].parentId;
    int siblingNodeId;

    if (mNodes[parentNodeId].children.ptr[TreeNode.Left] == nodeId) {
      siblingNodeId = mNodes[parentNodeId].children.ptr[TreeNode.Right];
    } else {
      siblingNodeId = mNodes[parentNodeId].children.ptr[TreeNode.Left];
    }

    // if the parent of the node to remove is not the root node
    if (grandParentNodeId != TreeNode.NullTreeNode) {
      // destroy the parent node
      if (mNodes[grandParentNodeId].children.ptr[TreeNode.Left] == parentNodeId) {
        mNodes[grandParentNodeId].children.ptr[TreeNode.Left] = siblingNodeId;
      } else {
        version(aabbtree_many_asserts) assert(mNodes[grandParentNodeId].children.ptr[TreeNode.Right] == parentNodeId);
        mNodes[grandParentNodeId].children.ptr[TreeNode.Right] = siblingNodeId;
      }
      mNodes[siblingNodeId].parentId = grandParentNodeId;
      releaseNode(parentNodeId);

      // now, we need to recompute the AABBs of the node on the path back to the root and make sure that the tree is still balanced
      int currentNodeId = grandParentNodeId;
      while (currentNodeId != TreeNode.NullTreeNode) {
        // balance the current sub-tree if necessary
        currentNodeId = balanceSubTreeAtNode(currentNodeId);

        version(aabbtree_many_asserts) assert(!mNodes[currentNodeId].leaf);

        // get the two children.ptr of the current node
        int leftChildId = mNodes[currentNodeId].children.ptr[TreeNode.Left];
        int rightChildId = mNodes[currentNodeId].children.ptr[TreeNode.Right];

        // recompute the AABB and the height of the current node
        mNodes[currentNodeId].aabb.merge(mNodes[leftChildId].aabb, mNodes[rightChildId].aabb);
        mNodes[currentNodeId].height = cast(short)(max(mNodes[leftChildId].height, mNodes[rightChildId].height)+1);
        version(aabbtree_many_asserts) assert(mNodes[currentNodeId].height > 0);

        currentNodeId = mNodes[currentNodeId].parentId;
      }
    } else {
      // if the parent of the node to remove is the root node, the sibling node becomes the new root node
      mRootNodeId = siblingNodeId;
      mNodes[siblingNodeId].parentId = TreeNode.NullTreeNode;
      releaseNode(parentNodeId);
    }
  }

  // balance the sub-tree of a given node using left or right rotations
  // the rotation schemes are described in the book "Introduction to Game Physics with Box2D" by Ian Parberry
  // this method returns the new root node id
  int balanceSubTreeAtNode (int nodeId) {
    version(aabbtree_many_asserts) assert(nodeId != TreeNode.NullTreeNode);

    TreeNode* nodeA = mNodes+nodeId;

    // if the node is a leaf or the height of A's sub-tree is less than 2
    if (nodeA.leaf || nodeA.height < 2) return nodeId; // do not perform any rotation

    // get the two children nodes
    int nodeBId = nodeA.children.ptr[TreeNode.Left];
    int nodeCId = nodeA.children.ptr[TreeNode.Right];
    version(aabbtree_many_asserts) assert(nodeBId >= 0 && nodeBId < mAllocCount);
    version(aabbtree_many_asserts) assert(nodeCId >= 0 && nodeCId < mAllocCount);
    TreeNode* nodeB = mNodes+nodeBId;
    TreeNode* nodeC = mNodes+nodeCId;

    // compute the factor of the left and right sub-trees
    int balanceFactor = nodeC.height-nodeB.height;

    // if the right node C is 2 higher than left node B
    if (balanceFactor > 1) {
      version(aabbtree_many_asserts) assert(!nodeC.leaf);

      int nodeFId = nodeC.children.ptr[TreeNode.Left];
      int nodeGId = nodeC.children.ptr[TreeNode.Right];
      version(aabbtree_many_asserts) assert(nodeFId >= 0 && nodeFId < mAllocCount);
      version(aabbtree_many_asserts) assert(nodeGId >= 0 && nodeGId < mAllocCount);
      TreeNode* nodeF = mNodes+nodeFId;
      TreeNode* nodeG = mNodes+nodeGId;

      nodeC.children.ptr[TreeNode.Left] = nodeId;
      nodeC.parentId = nodeA.parentId;
      nodeA.parentId = nodeCId;

      if (nodeC.parentId != TreeNode.NullTreeNode) {
        if (mNodes[nodeC.parentId].children.ptr[TreeNode.Left] == nodeId) {
          mNodes[nodeC.parentId].children.ptr[TreeNode.Left] = nodeCId;
        } else {
          version(aabbtree_many_asserts) assert(mNodes[nodeC.parentId].children.ptr[TreeNode.Right] == nodeId);
          mNodes[nodeC.parentId].children.ptr[TreeNode.Right] = nodeCId;
        }
      } else {
        mRootNodeId = nodeCId;
      }

      version(aabbtree_many_asserts) assert(!nodeC.leaf);
      version(aabbtree_many_asserts) assert(!nodeA.leaf);

      // if the right node C was higher than left node B because of the F node
      if (nodeF.height > nodeG.height) {
        nodeC.children.ptr[TreeNode.Right] = nodeFId;
        nodeA.children.ptr[TreeNode.Right] = nodeGId;
        nodeG.parentId = nodeId;

        // recompute the AABB of node A and C
        nodeA.aabb.merge(nodeB.aabb, nodeG.aabb);
        nodeC.aabb.merge(nodeA.aabb, nodeF.aabb);

        // recompute the height of node A and C
        nodeA.height = cast(short)(max(nodeB.height, nodeG.height)+1);
        nodeC.height = cast(short)(max(nodeA.height, nodeF.height)+1);
        version(aabbtree_many_asserts) assert(nodeA.height > 0);
        version(aabbtree_many_asserts) assert(nodeC.height > 0);
      } else {
        // if the right node C was higher than left node B because of node G
        nodeC.children.ptr[TreeNode.Right] = nodeGId;
        nodeA.children.ptr[TreeNode.Right] = nodeFId;
        nodeF.parentId = nodeId;

        // recompute the AABB of node A and C
        nodeA.aabb.merge(nodeB.aabb, nodeF.aabb);
        nodeC.aabb.merge(nodeA.aabb, nodeG.aabb);

        // recompute the height of node A and C
        nodeA.height = cast(short)(max(nodeB.height, nodeF.height)+1);
        nodeC.height = cast(short)(max(nodeA.height, nodeG.height)+1);
        version(aabbtree_many_asserts) assert(nodeA.height > 0);
        version(aabbtree_many_asserts) assert(nodeC.height > 0);
      }

      // return the new root of the sub-tree
      return nodeCId;
    }

    // if the left node B is 2 higher than right node C
    if (balanceFactor < -1) {
      version(aabbtree_many_asserts) assert(!nodeB.leaf);

      int nodeFId = nodeB.children.ptr[TreeNode.Left];
      int nodeGId = nodeB.children.ptr[TreeNode.Right];
      version(aabbtree_many_asserts) assert(nodeFId >= 0 && nodeFId < mAllocCount);
      version(aabbtree_many_asserts) assert(nodeGId >= 0 && nodeGId < mAllocCount);
      TreeNode* nodeF = mNodes+nodeFId;
      TreeNode* nodeG = mNodes+nodeGId;

      nodeB.children.ptr[TreeNode.Left] = nodeId;
      nodeB.parentId = nodeA.parentId;
      nodeA.parentId = nodeBId;

      if (nodeB.parentId != TreeNode.NullTreeNode) {
        if (mNodes[nodeB.parentId].children.ptr[TreeNode.Left] == nodeId) {
          mNodes[nodeB.parentId].children.ptr[TreeNode.Left] = nodeBId;
        } else {
          version(aabbtree_many_asserts) assert(mNodes[nodeB.parentId].children.ptr[TreeNode.Right] == nodeId);
          mNodes[nodeB.parentId].children.ptr[TreeNode.Right] = nodeBId;
        }
      } else {
        mRootNodeId = nodeBId;
      }

      version(aabbtree_many_asserts) assert(!nodeB.leaf);
      version(aabbtree_many_asserts) assert(!nodeA.leaf);

      // if the left node B was higher than right node C because of the F node
      if (nodeF.height > nodeG.height) {
        nodeB.children.ptr[TreeNode.Right] = nodeFId;
        nodeA.children.ptr[TreeNode.Left] = nodeGId;
        nodeG.parentId = nodeId;

        // recompute the AABB of node A and B
        nodeA.aabb.merge(nodeC.aabb, nodeG.aabb);
        nodeB.aabb.merge(nodeA.aabb, nodeF.aabb);

        // recompute the height of node A and B
        nodeA.height = cast(short)(max(nodeC.height, nodeG.height)+1);
        nodeB.height = cast(short)(max(nodeA.height, nodeF.height)+1);
        version(aabbtree_many_asserts) assert(nodeA.height > 0);
        version(aabbtree_many_asserts) assert(nodeB.height > 0);
      } else {
        // if the left node B was higher than right node C because of node G
        nodeB.children.ptr[TreeNode.Right] = nodeGId;
        nodeA.children.ptr[TreeNode.Left] = nodeFId;
        nodeF.parentId = nodeId;

        // recompute the AABB of node A and B
        nodeA.aabb.merge(nodeC.aabb, nodeF.aabb);
        nodeB.aabb.merge(nodeA.aabb, nodeG.aabb);

        // recompute the height of node A and B
        nodeA.height = cast(short)(max(nodeC.height, nodeF.height)+1);
        nodeB.height = cast(short)(max(nodeA.height, nodeG.height)+1);
        version(aabbtree_many_asserts) assert(nodeA.height > 0);
        version(aabbtree_many_asserts) assert(nodeB.height > 0);
      }

      // return the new root of the sub-tree
      return nodeBId;
    }

    // if the sub-tree is balanced, return the current root node
    return nodeId;
  }

  // compute the height of a given node in the tree
  int computeHeight (int nodeId) {
    version(aabbtree_many_asserts) assert(nodeId >= 0 && nodeId < mAllocCount);
    TreeNode* node = mNodes+nodeId;

    // if the node is a leaf, its height is zero
    if (node.leaf) return 0;

    // compute the height of the left and right sub-tree
    int leftHeight = computeHeight(node.children.ptr[TreeNode.Left]);
    int rightHeight = computeHeight(node.children.ptr[TreeNode.Right]);

    // return the height of the node
    return 1+max(leftHeight, rightHeight);
  }

  // internally add an object into the tree
  int insertObjectInternal (in ref AABB aabb, bool staticObject) {
    // get the next available node (or allocate new ones if necessary)
    int nodeId = allocateNode();

    // create the fat aabb to use in the tree
    mNodes[nodeId].aabb = aabb;
    if (!staticObject) {
      static if (VT.Dims == 2) {
        immutable gap = VT(mExtraGap, mExtraGap);
      } else {
        immutable gap = VT(mExtraGap, mExtraGap, mExtraGap);
      }
      mNodes[nodeId].aabb.min -= gap;
      mNodes[nodeId].aabb.max += gap;
    }

    // set the height of the node in the tree
    mNodes[nodeId].height = 0;

    // insert the new leaf node in the tree
    insertLeafNode(nodeId);
    version(aabbtree_many_asserts) assert(mNodes[nodeId].leaf);

    version(aabbtree_many_asserts) assert(nodeId >= 0);

    // return the id of the node
    return nodeId;
  }

  // initialize the tree
  void setup () {
    import core.stdc.stdlib : malloc;
    import core.stdc.string : memset;

    mRootNodeId = TreeNode.NullTreeNode;
    mNodeCount = 0;
    mAllocCount = 64;

    mNodes = cast(TreeNode*)malloc(mAllocCount*TreeNode.sizeof);
    if (mNodes is null) assert(0, "out of memory");
    memset(mNodes, 0, mAllocCount*TreeNode.sizeof);

    // initialize the allocated nodes
    foreach (int i; 0..mAllocCount-1) {
      mNodes[i].nextNodeId = i+1;
      mNodes[i].height = -1;
    }
    mNodes[mAllocCount-1].nextNodeId = TreeNode.NullTreeNode;
    mNodes[mAllocCount-1].height = -1;
    mFreeNodeId = 0;
  }

  // also, checks if the tree structure is valid (for debugging purpose)
  public void forEachLeaf (scope void delegate (BodyBase abody, in ref AABB aabb) dg) {
    void forEachNode (int nodeId) {
      if (nodeId == TreeNode.NullTreeNode) return;
      // if it is the root
      if (nodeId == mRootNodeId) {
        assert(mNodes[nodeId].parentId == TreeNode.NullTreeNode);
      }
      // get the children nodes
      TreeNode* pNode = mNodes+nodeId;
      assert(pNode.height >= 0);
      assert(pNode.aabb.volume > 0);
      // if the current node is a leaf
      if (pNode.leaf) {
        assert(pNode.height == 0);
        if (dg !is null) dg(pNode.flesh, pNode.aabb);
      } else {
        int leftChild = pNode.children.ptr[TreeNode.Left];
        int rightChild = pNode.children.ptr[TreeNode.Right];
        // check that the children node Ids are valid
        assert(0 <= leftChild && leftChild < mAllocCount);
        assert(0 <= rightChild && rightChild < mAllocCount);
        // check that the children nodes have the correct parent node
        assert(mNodes[leftChild].parentId == nodeId);
        assert(mNodes[rightChild].parentId == nodeId);
        // check the height of node
        int height = 1+max(mNodes[leftChild].height, mNodes[rightChild].height);
        assert(mNodes[nodeId].height == height);
        // check the AABB of the node
        AABB aabb = AABB.mergeAABBs(mNodes[leftChild].aabb, mNodes[rightChild].aabb);
        assert(aabb.min == mNodes[nodeId].aabb.min);
        assert(aabb.max == mNodes[nodeId].aabb.max);
        // recursively check the children nodes
        forEachNode(leftChild);
        forEachNode(rightChild);
      }
    }
    // recursively check each node
    forEachNode(mRootNodeId);
  }

  static if (GCAnchor) void gcRelease () {
    import core.memory : GC;
    foreach (ref TreeNode n; mNodes[0..mNodeCount]) {
      if (n.leaf) {
        auto flesh = n.flesh;
        GC.clrAttr(*cast(void**)&flesh, GC.BlkAttr.NO_MOVE);
        GC.removeRoot(*cast(void**)&flesh);
      }
    }
  }

  version(aabbtree_query_count) public int nodesVisited, nodesDeepVisited;

  // return `true` from visitor to stop immediately
  // checker should check if this node should be considered to further checking
  // returns tree node if visitor says stop or -1
  private int visit (scope bool delegate (TreeNode* node) checker, scope bool delegate (BodyBase abody) visitor) {
    int[1024] stack = void; // stack with the nodes to visit
    int sp = 0;
    int[] bigstack = null;
    scope(exit) if (bigstack.ptr !is null) delete bigstack;

    void spush (int id) {
      if (sp < stack.length) {
        // use "small stack"
        stack.ptr[sp++] = id;
      } else {
        if (sp >= int.max/2) assert(0, "huge tree!");
        // use "big stack"
        immutable int xsp = sp-cast(int)stack.length;
        if (xsp < bigstack.length) {
          // reuse
          bigstack.ptr[xsp] = id;
        } else {
          // grow
          auto optr = bigstack.ptr;
          bigstack ~= id;
          if (bigstack.ptr !is optr) {
            import core.memory : GC;
            optr = bigstack.ptr;
            if (optr is GC.addrOf(optr)) GC.setAttr(optr, GC.BlkAttr.NO_INTERIOR);
          }
        }
        ++sp;
      }
    }

    int spop () {
      pragma(inline, true); // why not?
      if (sp == 0) assert(0, "stack underflow");
      if (sp <= stack.length) {
        // use "small stack"
        return stack.ptr[--sp];
      } else {
        // use "big stack"
        --sp;
        return bigstack.ptr[sp-cast(int)stack.length];
      }
    }

    version(aabbtree_query_count) nodesVisited = nodesDeepVisited = 0;

    // start from root node
    spush(mRootNodeId);

    // while there are still nodes to visit
    while (sp > 0) {
      // get the next node id to visit
      int nodeId = spop();
      // skip it if it is a null node
      if (nodeId == TreeNode.NullTreeNode) continue;
      version(aabbtree_query_count) ++nodesVisited;
      // get the corresponding node
      TreeNode* node = mNodes+nodeId;
      // should we investigate this node?
      if (checker(node)) {
        // if the node is a leaf
        if (node.leaf) {
          // call visitor on it
          version(aabbtree_query_count) ++nodesDeepVisited;
          if (visitor(node.flesh)) return nodeId;
        } else {
          // if the node is not a leaf, we need to visit its children
          spush(node.children.ptr[TreeNode.Left]);
          spush(node.children.ptr[TreeNode.Right]);
        }
      }
    }

    return -1; // oops
  }

public:
  /// add `extraAABBGap` to bounding boxes so slight object movement won't cause tree rebuilds
  /// extra AABB Gap used to allow the collision shape to move a little bit without triggering a large modification of the tree which can be costly
  this (Float extraAABBGap=FloatNum!0) nothrow {
    mExtraGap = extraAABBGap;
    setup();
  }

  ~this () {
    import core.stdc.stdlib : free;
    static if (GCAnchor) gcRelease();
    free(mNodes);
  }

  /// return the root AABB of the tree
  AABB getRootAABB () nothrow @trusted @nogc {
    pragma(inline, true);
    version(aabbtree_many_asserts) assert(mRootNodeId >= 0 && mRootNodeId < mAllocCount);
    return mNodes[mRootNodeId].aabb;
  }

  /// does the given id represents a valid object?
  /// WARNING: ids of removed objects can be reused on later insertions!
  bool isValidId (int id) const nothrow @trusted @nogc { pragma(inline, true); return (id >= 0 && id < mAllocCount && mNodes[id].leaf); }

  /// get current extra AABB gap
  @property Float extraGap () const pure nothrow @trusted @nogc { pragma(inline, true); return mExtraGap; }

  /// set current extra AABB gap
  @property void extraGap (Float aExtraGap) pure nothrow @trusted @nogc { pragma(inline, true); mExtraGap = aExtraGap; }

  /// get object by id; can return null for invalid ids
  BodyBase getObject (int id) nothrow @trusted @nogc { pragma(inline, true); return (id >= 0 && id < mAllocCount && mNodes[id].leaf ? mNodes[id].flesh : null); }

  /// get fat object AABB by id; returns random shit for invalid ids
  AABB getObjectFatAABB (int id) nothrow @trusted @nogc { pragma(inline, true); return (id >= 0 && id < mAllocCount && !mNodes[id].free ? mNodes[id].aabb : AABB()); }

  /// insert an object into the tree
  /// this method creates a new leaf node in the tree and returns the id of the corresponding node
  /// AABB for static object will not be "fat" (simple optimization)
  /// WARNING! inserting the same object several times *WILL* break everything!
  int insertObject (BodyBase flesh, bool staticObject=false) {
    auto aabb = flesh.getAABB(); // can be passed as argument
    int nodeId = insertObjectInternal(aabb, staticObject);
    version(aabbtree_many_asserts) assert(mNodes[nodeId].leaf);
    mNodes[nodeId].flesh = flesh;
    static if (GCAnchor) {
      import core.memory : GC;
      GC.addRoot(*cast(void**)&flesh);
      GC.setAttr(*cast(void**)&flesh, GC.BlkAttr.NO_MOVE);
    }
    return nodeId;
  }

  /// remove an object from the tree
  /// WARNING: ids of removed objects can be reused on later insertions!
  void removeObject (int nodeId) {
    if (nodeId < 0 || nodeId >= mAllocCount || !mNodes[nodeId].leaf) assert(0, "invalid node id");
    static if (GCAnchor) {
      import core.memory : GC;
      auto flesh = mNodes[nodeId].flesh;
      GC.clrAttr(*cast(void**)&flesh, GC.BlkAttr.NO_MOVE);
      GC.removeRoot(*cast(void**)&flesh);
    }
    // remove the node from the tree
    removeLeafNode(nodeId);
    releaseNode(nodeId);
  }

  /** update the dynamic tree after an object has moved.
   *
   * if the new AABB of the object that has moved is still inside its fat AABB, then nothing is done.
   * otherwise, the corresponding node is removed and reinserted into the tree.
   * the method returns true if the object has been reinserted into the tree.
   * the "displacement" parameter is the linear velocity of the AABB multiplied by the elapsed time between two frames.
   * if the "forceReinsert" parameter is true, we force a removal and reinsertion of the node
   * (this can be useful if the shape AABB has become much smaller than the previous one for instance).
   *
   * note that you should call this method if body's AABB was modified, even if the body wasn't moved.
   *
   * if `forceReinsert` == `true` and `displacement` is zero, convert object to "static" (don't extrude AABB).
   *
   * return `true` if the tree was modified.
   */
  bool updateObject() (int nodeId, in auto ref AABB.VType displacement, bool forceReinsert=false) {
    if (nodeId < 0 || nodeId >= mAllocCount || !mNodes[nodeId].leaf) assert(0, "invalid node id");

    auto newAABB = mNodes[nodeId].flesh.getAABB(); // can be passed as argument

    // if the new AABB is still inside the fat AABB of the node
    if (!forceReinsert && mNodes[nodeId].aabb.contains(newAABB)) return false;

    // if the new AABB is outside the fat AABB, we remove the corresponding node
    removeLeafNode(nodeId);

    // compute the fat AABB by inflating the AABB with a constant gap
    mNodes[nodeId].aabb = newAABB;
    if (!(forceReinsert && displacement.isZero)) {
      static if (VT.Dims == 2) {
        immutable gap = VT(mExtraGap, mExtraGap);
      } else {
        immutable gap = VT(mExtraGap, mExtraGap, mExtraGap);
      }
      mNodes[nodeId].aabb.mMin -= gap;
      mNodes[nodeId].aabb.mMax += gap;
    }

    // inflate the fat AABB in direction of the linear motion of the AABB
    if (displacement.x < FloatNum!0) {
      mNodes[nodeId].aabb.mMin.x += LinearMotionGapMultiplier*displacement.x;
    } else {
      mNodes[nodeId].aabb.mMax.x += LinearMotionGapMultiplier*displacement.x;
    }
    if (displacement.y < FloatNum!0) {
      mNodes[nodeId].aabb.mMin.y += LinearMotionGapMultiplier*displacement.y;
    } else {
      mNodes[nodeId].aabb.mMax.y += LinearMotionGapMultiplier*displacement.y;
    }
    static if (AABB.VType.Dims == 3) {
      if (displacement.z < FloatNum!0) {
        mNodes[nodeId].aabb.mMin.z += LinearMotionGapMultiplier*displacement.z;
      } else {
        mNodes[nodeId].aabb.mMax.z += LinearMotionGapMultiplier*displacement.z;
      }
    }

    version(aabbtree_many_asserts) assert(mNodes[nodeId].aabb.contains(newAABB));

    // reinsert the node into the tree
    insertLeafNode(nodeId);

    return true;
  }

  /// report all shapes overlapping with the AABB given in parameter
  void forEachAABBOverlap() (in auto ref AABB aabb, scope OverlapCallback cb) {
    visit(
      // checker
      (node) => aabb.overlaps(node.aabb),
      // visitor
      (flesh) { cb(flesh); return false; }
    );
  }

  /// report body that contains the given point
  BodyBase pointQuery() (in auto ref VT point, scope SimpleQueryCallback cb) {
    int nid = visit(
      // checker
      (node) => node.aabb.contains(point),
      // visitor
      (flesh) => cb(flesh),
    );
    version(aabbtree_many_asserts) assert(nid < 0 || (nid >= 0 && nid < mAllocCount && mNodes[nid].leaf));
    return (nid >= 0 ? mNodes[nid].flesh : null);
  }

  /// report all bodies containing the given point
  void pointQuery() (in auto ref VT point, scope SimpleQueryCallbackNR cb) {
    visit(
      // checker
      (node) => node.aabb.contains(point),
      // visitor
      (flesh) { cb(flesh); return false; },
    );
  }

  ///
  static struct SegmentQueryResult {
    Float dist = -1; /// <0: nothing was hit
    BodyBase flesh; ///

    @property bool valid () const nothrow @safe @nogc { pragma(inline, true); return (dist >= 0 && flesh !is null); } ///
  }

  /// segment querying method
  SegmentQueryResult segmentQuery() (in auto ref VT a, in auto ref VT b, scope SegQueryCallback cb) {
    SegmentQueryResult res;
    Float maxFraction = Float.infinity;

    immutable VT cura = a;
    VT curb = b;
    immutable VT dir = (curb-cura).normalized;

    visit(
      // checker
      (node) => node.aabb.isIntersects(cura, curb),
      // visitor
      (flesh) {
        Float hitFraction = cb(flesh, cura, curb);
        // if the user returned a hitFraction of zero, it means that the raycasting should stop here
        if (hitFraction == FloatNum!0) {
          res.dist = 0;
          res.flesh = flesh;
          return true;
        }
        // if the user returned a positive fraction
        if (hitFraction > FloatNum!0) {
          // we update the maxFraction value and the ray AABB using the new maximum fraction
          if (hitFraction < maxFraction) {
            maxFraction = hitFraction;
            res.dist = hitFraction;
            res.flesh = flesh;
            // fix curb here
            curb = cura+dir*hitFraction;
          }
        }
        return false; // continue
      },
    );

    return res;
  }

  /// compute the height of the tree
  int computeHeight () { pragma(inline, true); return computeHeight(mRootNodeId); }

  @property int nodeCount () const pure nothrow @safe @nogc { pragma(inline, true); return mNodeCount; }
  @property int nodeAlloced () const pure nothrow @safe @nogc { pragma(inline, true); return mAllocCount; }

  /// clear all the nodes and reset the tree
  void reset() {
    import core.stdc.stdlib : free;
    static if (GCAnchor) gcRelease();
    free(mNodes);
    setup();
  }
}


/*
// ////////////////////////////////////////////////////////////////////////// //
final class Body {
  AABB aabb;

  this (vec2 amin, vec2 amax) { aabb.min = amin; aabb.max = amax; }

  AABB getAABB () { return aabb; }
}


// ////////////////////////////////////////////////////////////////////////// //
import iv.vfs.io;

void main () {
  auto tree = new DynamicAABBTree!Body(0.2);

  vec2 bmin = vec2(10, 15);
  vec2 bmax = vec2(42, 54);

  auto flesh = new Body(bmin, bmax);

  tree.insertObject(flesh);

  vec2 ro = vec2(5, 18);
  vec2 rd = vec2(1, 0.2).normalized;
  vec2 re = ro+rd*20;

  writeln(flesh.aabb.segIntersectMin(ro, re));

  auto res = tree.segmentQuery(ro, re, delegate (flesh, in ref vec2 a, in ref vec2 b) {
    auto dst = flesh.aabb.segIntersectMin(a, b);
    writeln("a=", a, "; b=", b, "; dst=", dst);
    if (dst < 0) return -1;
    return dst;
  });

  writeln(res);
}
*/
