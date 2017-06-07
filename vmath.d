/*
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
// various vector and matrix operations
// matrix should be compatible with OpenGL, but mostly untested
module iv.vmath /*is aliced*/;
import iv.alice;

//version = aabbtree_many_asserts;
//version = aabbtree_query_count;


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
template ImportCoreMath(FloatType, T...) {
  private template InternalImport(T...) {
    static if (T.length == 0) enum InternalImport = "";
    else static if (is(typeof(T[0]) == string)) {
      static if (T[0] == "fabs" || T[0] == "cos" || T[0] == "sin" || T[0] == "sqrt") {
        enum InternalImport = "import core.math : "~T[0]~";"~InternalImport!(T[1..$]);
      } else static if (is(FloatType == float)) {
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
  import std.math : PI;
  static if (__traits(isFloating, T)) {
    return cast(T)(v*cast(T)PI/cast(T)180);
  } else {
    return cast(VFloat)(cast(VFloat)v*cast(VFloat)PI/cast(VFloat)180);
  }
}

auto rad2deg(T:double) (T v) pure nothrow @safe @nogc {
  pragma(inline, true);
  import std.math : PI;
  static if (__traits(isFloating, T)) {
    return cast(T)(v*cast(T)180/cast(T)PI);
  } else {
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
  enum isVector(VT) = (is(VT == VecN!(2, FloatType)) || is(VT == VecN!(3, FloatType)));
  enum isVector2(VT) = is(VT == VecN!(2, FloatType));
  enum isVector3(VT) = is(VT == VecN!(3, FloatType));
  enum isSameVector(VT) = is(VT == VecN!(dims, FloatType));

  alias v2 = VecN!(2, FloatType);
  alias v3 = VecN!(3, FloatType);

  alias Me = typeof(this);
  alias Float = FloatType;
  alias Dims = dims;

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

  @property bool valid () const nothrow @safe @nogc {
    pragma(inline, true);
    import core.stdc.math : isnan;
         static if (dims == 2) return !isnan(x) && !isnan(y);
    else static if (dims == 3) return !isnan(x) && !isnan(y) && !isnan(z);
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
    mixin(ImportCoreMath!(Float, "sqrt"));
         static if (dims == 2) immutable Float invlen = cast(Float)1/sqrt(x*x+y*y);
    else static if (dims == 3) immutable Float invlen = cast(Float)1/sqrt(x*x+y*y+z*z);
    else static assert(0, "invalid dimension count for vector");
    x *= invlen;
    y *= invlen;
    static if (dims == 3) z *= invlen;
    return this;
  }

  Float normalizeRetLength () {
    //pragma(inline, true);
    mixin(ImportCoreMath!(Float, "sqrt"));
         static if (dims == 2) immutable Float len = sqrt(x*x+y*y);
    else static if (dims == 3) immutable Float len = sqrt(x*x+y*y+z*z);
    else static assert(0, "invalid dimension count for vector");
    immutable Float invlen = cast(Float)1/len;
    x *= invlen;
    y *= invlen;
    static if (dims == 3) z *= invlen;
    return len;
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
    a = cast(Float)1/a;
    x *= a;
    y *= a;
    static if (dims == 3) z *= a;
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

  @property Float lengthSquared () {
    pragma(inline, true);
         static if (dims == 2) return x*x+y*y;
    else static if (dims == 3) return x*x+y*y+z*z;
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
    a = cast(Float)1/a; // 1/0 == inf
         static if (dims == 2) return v2(x*a, y*a);
    else static if (dims == 3) return v3(x*a, y*a, z*a);
    else static assert(0, "invalid dimension count for vector");
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
      mixin(ImportCoreMath!(Float, "atan2"));
      return v2(
        atan2(cast(Float)tmp.x, cast(Float)0),
        -atan2(cast(Float)tmp.y, cast(Float)tmp.x),
      );
    } else {
      mixin(ImportCoreMath!(Float, "atan2", "sqrt"));
      return v3(
        atan2(cast(Float)tmp.x, cast(Float)tmp.z),
        -atan2(cast(Float)tmp.y, cast(Float)sqrt(tmp.x*tmp.x+tmp.z*tmp.z)),
        0
      );
    }
  }

  // some more supplementary functions to support various things
  Float vcos(VT) (in auto ref VT v) if (isVector!VT) {
    immutable Float len = length*v.length;
    return (len > EPSILON!Float ? dot(v)/len : 0);
  }

  Float vsin(VT) (in auto ref VT v) if (isVector!VT) {
    immutable Float len = length*v.length;
    return (len > EPSILON!Float ? cross(v)/len : 0);
  }

  Float angle180(VT) (in auto ref VT v) if (isVector!VT) {
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

  Float angle360(VT) (in auto ref VT v) if (isVector!VT) {
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

static:
  // linearly interpolate between v1 and v2
  /*
  VT lerp(VT) (in auto ref VT v1, in auto ref VT v2, const Float t) if (isSameVector!VT) {
    pragma(inline, true);
    return (v1*cast(Float)1.0f-t)+(v2*t);
  }
  */
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

  @property Float opIndex (usize x, usize y) @trusted @nogc { pragma(inline, true); return (x < 4 && y < 4 ? mt.ptr[y*4+x] : Float.nan); }

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

  // same as `glFrustum()`
  static mat4 Frustum() (Float left, Float right, Float bottom, Float top, Float nearVal, Float farVal) nothrow @trusted @nogc {
    auto res = mat4(0);
    res.mt.ptr[0]  = 2*nearVal/(right-left);
    res.mt.ptr[5]  = 2*nearVal/(top-bottom);
    res.mt.ptr[8]  = (right+left)/(right-left);
    res.mt.ptr[9]  = (top+bottom)/(top-bottom);
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
    return mat;
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
    return frustum(-fW, fW, -fH, fH, zNear, zFar);
  }

public:
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

  ref mat4 translate() (in auto ref vec3 v) {
    mt.ptr[0] += mt.ptr[3]*v.x; mt.ptr[4] += mt.ptr[7]*v.x; mt.ptr[8] += mt.ptr[11]*v.x; mt.ptr[12] += mt.ptr[15]*v.x;
    mt.ptr[1] += mt.ptr[3]*v.y; mt.ptr[5] += mt.ptr[7]*v.y; mt.ptr[9] += mt.ptr[11]*v.y; mt.ptr[13] += mt.ptr[15]*v.y;
    mt.ptr[2] += mt.ptr[3]*v.z; mt.ptr[6] += mt.ptr[7]*v.z; mt.ptr[10] += mt.ptr[11]*v.z; mt.ptr[14] += mt.ptr[15]*v.z;
    return this;
  }

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
  mat4 scaled() (in auto ref vec3 v) const { pragma(inline, true); auto res = mat4(this); return res.scale(v); }

  // retrieve angles in degree from rotation matrix, M = Rx*Ry*Rz
  // Rx: rotation about X-axis, pitch
  // Ry: rotation about Y-axis, yaw (heading)
  // Rz: rotation about Z-axis, roll
  vec3 getAngles () const {
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

  mat4 transpose () const {
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

  mat4 opUnary(string op:"-") () const {
    return mat4(
      -mt.ptr[0], -mt.ptr[1], -mt.ptr[2], -mt.ptr[3],
      -mt.ptr[4], -mt.ptr[5], -mt.ptr[6], -mt.ptr[7],
      -mt.ptr[8], -mt.ptr[9], -mt.ptr[10], -mt.ptr[11],
      -mt.ptr[12], -mt.ptr[13], -mt.ptr[14], -mt.ptr[15],
    );
  }

  Float determinant() () const {
    return mt.ptr[0]*getCofactor(mt.ptr[5], mt.ptr[6], mt.ptr[7], mt.ptr[9], mt.ptr[10], mt.ptr[11], mt.ptr[13], mt.ptr[14], mt.ptr[15])-
           mt.ptr[1]*getCofactor(mt.ptr[4], mt.ptr[6], mt.ptr[7], mt.ptr[8], mt.ptr[10], mt.ptr[11], mt.ptr[12], mt.ptr[14], mt.ptr[15])+
           mt.ptr[2]*getCofactor(mt.ptr[4], mt.ptr[5], mt.ptr[7], mt.ptr[8], mt.ptr[9], mt.ptr[11], mt.ptr[12], mt.ptr[13], mt.ptr[15])-
           mt.ptr[3]*getCofactor(mt.ptr[4], mt.ptr[5], mt.ptr[6], mt.ptr[8], mt.ptr[9], mt.ptr[10], mt.ptr[12], mt.ptr[13], mt.ptr[14]);
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
  ref mat4 invertedEuclidean() () {
    Float tmp = void;
    tmp = mt.ptr[1]; mt.ptr[1] = mt.ptr[4]; mt.ptr[4] = tmp;
    tmp = mt.ptr[2]; mt.ptr[2] = mt.ptr[8]; mt.ptr[8] = tmp;
    tmp = mt.ptr[6]; mt.ptr[6] = mt.ptr[9]; mt.ptr[9] = tmp;
    Float x = mt.ptr[12];
    Float y = mt.ptr[13];
    Float z = mt.ptr[14];
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
    Float[9] r = [ mt.ptr[0],mt.ptr[1],mt.ptr[2], mt.ptr[4],mt.ptr[5],mt.ptr[6], mt.ptr[8],mt.ptr[9],mt.ptr[10] ];
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
      Float determinant = r.ptr[0]*tmp.ptr[0]+r.ptr[1]*tmp.ptr[3]+r.ptr[2]*tmp.ptr[6];
      if (fabs(determinant) <= EPSILON!Float) {
        // cannot inverse, make it idenety matrix
        r[] = 0;
        r.ptr[0] = r.ptr[4] = r.ptr[8] = 1;
      } else {
        // divide by the determinant
        Float invDeterminant = cast(Float)1/determinant;
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

  ref mat4 inverted() () {
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
  ref mat4 invertedGeneral() () {
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
    Float tr = mt.ptr[0*4+0]+mt.ptr[1*4+1]+mt.ptr[2*4+2];
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
      int i, j, k;
      int[3] nxt = [1, 2, 0];
      Float s = void;
      Float[4] q = void;
      i = 0;
      if (mt.ptr[1*4+1] > mt.ptr[0*4+0]) i = 1;
      if (mt.ptr[2*4+2] > mt.ptr[i*4+i]) i = 2;
      j = nxt.ptr[i];
      k = nxt.ptr[j];
      s = sqrt((mt.ptr[i*4+i]-(mt.ptr[j*4+j]+mt.ptr[k*4+k]))+cast(Float)1);
      q[i] = s*cast(Float)0.5;
      if (s != 0) s = cast(Float)0.5/s;
      q[3] = (mt.ptr[k*4+j]-mt.ptr[j*4+k])*s;
      q[j] = (mt.ptr[j*4+i]+mt.ptr[i*4+j])*s;
      q[k] = (mt.ptr[k*4+i]+mt.ptr[i*4+k])*s;
      res.x = q[0];
      res.y = q[1];
      res.z = q[2];
      res.w = q[3];
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
    w = aw;
    x = ax;
    y = ay;
    z = az;
  }

  static quat4 Identity () nothrow @trusted @nogc { pragma(inline, true); return quat4(1, 0, 0, 0); }

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

  @property bool valid () const nothrow @safe @nogc { pragma(inline, true); import core.stdc.math : isnan; return !isnan(w) && !isnan(x) && !isnan(y) && !isnan(z); }

  Mat4!VT toMatrix () const nothrow @trusted @nogc {
    //Float wx = void, wy = void, wz = void, xx = void, yy = void, yz = void;
    //Float xy = void, xz = void, zz = void, x2 = void, y2 = void, z2 = void;

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
      to1[0] = -to.x;
      to1[1] = -to.y;
      to1[2] = -to.z;
      to1[3] = -to.w;
    } else  {
      to1[0] = to.x;
      to1[1] = to.y;
      to1[2] = to.z;
      to1[3] = to.w;
    }
    Float scale0 = void, scale1 = void;
    // calculate coefficients
    if (cast(Float)1-cosom > EPSILON!Float) {
      // standard case (slerp)
      Float omega = acos(cosom);
      Float sinom = sin(omega);
      scale0 = sin((cast(Float)1-t)*omega)/sinom;
      scale1 = sin(t*omega)/sinom;
    } else {
      // "from" and "to" quaternions are very close
      //  ... so we can do a linear interpolation
      scale0 = cast(Float)1-t;
      scale1 = t;
    }
    // calculate final values
    return quat4(
      scale0*this.w+scale1*to1[3],
      scale0*this.x+scale1*to1[0],
      scale0*this.y+scale1*to1[1],
      scale0*this.z+scale1*to1[2],
    );
  }
}


// ////////////////////////////////////////////////////////////////////////// //
alias mat3 = Mat3!vec2;

// very simple (and mostly not tested) 3x3 matrix
align(1) struct Mat3(VT) if (IsVectorDim!(VT, 2)) {
align(1):

private:
  alias Float = VT.Float;
  alias m3 = typeof(this);
  alias v2 = VecN!(2, Float);
  alias v3 = VecN!(3, Float);

  enum isVector(VT) = (is(VT == VecN!(2, Float)) || is(VT == VecN!(3, Float)));
  enum isVector2(VT) = is(VT == VecN!(2, Float));
  enum isVector3(VT) = is(VT == VecN!(3, Float));

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
      m.ptr[0..9] = 0;
      m.ptr[0..vals.length] = vals[];
    }
  }

  Float opIndex (usize x, usize y) const {
    pragma(inline, true);
    return (x < 3 && y < 3 ? m.ptr[y*3+x] : Float.nan);
  }

  void opIndexAssign (Float v, usize x, usize y) {
    pragma(inline, true);
    if (x < 3 && y < 3) m.ptr[y*3+x] = v;
  }

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
    m3 res;
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
    m3 res;
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
    m3 res;
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

  auto opBinary(string op:"*") (in auto ref v2 v) const {
    pragma(inline, true);
    return v2(
      v.x*m.ptr[3*0+0]+v.y*m.ptr[3*1+0]+m.ptr[3*2+0],
      v.x*m.ptr[3*0+1]+v.y*m.ptr[3*1+1]+m.ptr[3*2+1],
    );
  }

  /*
  auto opBinary(string op:"*") (in auto ref v3 v) const {
    pragma(inline, true);
    return v3(
      v.x*m.ptr[3*0+0]+v.y*m.ptr[3*1+0]+v.z*m.ptr[3*2+0],
      v.x*m.ptr[3*0+1]+v.y*m.ptr[3*1+1]+v.z*m.ptr[3*2+1],
      v.x*m.ptr[3*0+2]+v.y*m.ptr[3*1+2]+v.z*m.ptr[3*2+2],
    );
  }
  */

  auto opBinaryRight(string op:"*") (in auto ref v2 v) const { pragma(inline, true); return this*v; }
  //auto opBinaryRight(string op:"*") (in auto ref v3 v) const { pragma(inline, true); return this*v; }

  auto opBinary(string op:"*") (in auto ref m3 b) const {
    //pragma(inline, true);
    m3 res;
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
    m3 res;
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

static:
  auto Identity () { pragma(inline, true); return m3(); }
  auto Zero () { pragma(inline, true); return m3(0); }

  auto Rotate (in Float angle) {
    pragma(inline, true);
    mixin(SinCosImportMixin);
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

private:
  private enum SinCosImportMixin = q{
    static if (is(Float == float)) {
      import core.stdc.math : cos=cosf, sin=sinf;
    } else {
      import core.stdc.math : cos, sin;
    }
  };
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

  @property bool valid () const { import core.stdc.math : isnan; pragma(inline, true); return (!isnan(radius) && radius > 0); }

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
  static if (is(PT == Plane3!(PFT, eps, swiz), PFT, PFT eps, bool swiz)) {
    enum IsPlane3 = (is(PFT == float) || is(PFT == double));
  } else {
    enum IsPlane3 = false;
  }
}


template IsPlane3(PT, FT) {
  static if (is(PT == Plane3!(PFT, eps, swiz), PFT, FT eps, bool swiz)) {
    enum IsPlane3 = (is(FT == PFT) && (is(PFT == float) || is(PFT == double)));
  } else {
    enum IsPlane3 = false;
  }
}


// plane in 3D space: Ax+By+Cz+D=0
align(1) struct Plane3(FloatType=VFloat, FloatType PlaneEps=-1.0, bool enableSwizzling=true) if (is(FloatType == float) || is(FloatType == double)) {
align(1):
public:
  alias Float = FloatType;
  alias plane3 = typeof(this);
  alias vec3 = VecN!(3, Float);
  static if (PlaneEps < 0) {
    enum EPS = EPSILON!Float;
  } else {
    enum EPS = PlaneEps;
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
  this() (in auto ref vec3 anormal, Float aw) { pragma(inline, true); set(anormal, aw); }
  this() (in auto ref vec3 a, in auto ref vec3 b, in auto ref vec3 c) { pragma(inline, true); setFromPoints(a, b, c); }

  void set () (in auto ref vec3 anormal, Float aw) {
    mixin(ImportCoreMath!(Float, "fabs"));
    normal = anormal;
    w = aw;
    if (fabs(w) <= EPS) w = 0;
  }

  ref plane3 setFromPoints() (in auto ref vec3 a, in auto ref vec3 b, in auto ref vec3 c) @nogc {
    normal = ((b-a)%(c-a)).normalized;
    w = normal*a; // n.dot(a)
    return this;
  }

  @property bool valid () const { pragma(inline, true); import core.stdc.math : isnan; return !isnan(w); }

  Float opIndex (usize idx) const {
    pragma(inline, true);
    return (idx == 0 ? normal.x : idx == 1 ? normal.y : idx == 2 ? normal.z : idx == 3 ? w : Float.nan);
  }

  void opIndexAssign (Float v, usize idx) {
    pragma(inline, true);
    if (idx == 0) normal.x = v; else if (idx == 1) normal.y = v; else if (idx == 2) normal.z = v; else if (idx == 3) w = v;
  }

  ref plane3 normalize () {
    Float dd = normal.length;
    if (dd >= EPSILON!Float) {
      dd = cast(Float)1/dd;
      normal.x *= dd;
      normal.y *= dd;
      normal.z *= dd;
      w *= dd;
    } else {
      normal = vec3(0, 0, 0);
      w = 0;
    }
    return this;
  }

  PType pointSide() (in auto ref vec3 p) const {
    pragma(inline, true);
    auto t = (normal*p)-w; // dot
    return (t < -EPS ? Back : (t > EPS ? Front : Coplanar));
  }

  Float pointSideF() (in auto ref vec3 p) const {
    pragma(inline, true);
    return (normal*p)-w; // dot
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

  void setOrigDir (VT.Float x, VT.Float y, VT.Float angle) {
    pragma(inline, true);
    mixin(ImportCoreMath!(Float, "cos", "sin"));
    orig.x = x;
    orig.y = y;
    dir.x = cos(angle);
    dir.y = sin(angle);
  }

  void setOrigDir() (in auto ref VT aorg, VT.Float angle) {
    pragma(inline, true);
    mixin(ImportCoreMath!(Float, "cos", "sin"));
    orig.x = aorg.x;
    orig.y = aorg.y;
    dir.x = cos(angle);
    dir.y = sin(angle);
  }

  void setOrig (VT.Float x, VT.Float y) {
    pragma(inline, true);
    orig.x = x;
    orig.y = y;
  }

  void setOrig() (in auto ref VT aorg) {
    pragma(inline, true);
    orig.x = aorg.x;
    orig.y = aorg.y;
  }

  void setDir (VT.Float angle) {
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

  // return true if the current AABB contains the AABB given in parameter
  bool contains() (in auto ref Me aabb) const {
    pragma(inline, true);
    version(all) {
      // exit with no intersection if found separated along an axis
      if (max.x < aabbmin.x || min.x > aabbmax.x) return false;
      if (max.y < aabbmin.y || min.y > aabbmax.y) return false;
      static if (VT.Dims == 3) {
        if (max.z < aabbmin.z || min.z > aabbmax.z) return false;
      }
      // no separating axis found, therefor there is at least one overlapping axis
      return true;
    } else {
      bool isInside = true;
      isInside = (isInside && min.x <= aabb.min.x);
      isInside = (isInside && min.y <= aabb.min.y);
      isInside = (isInside && max.x >= aabb.max.x);
      isInside = (isInside && max.y >= aabb.max.y);
      static if (VT.Dims == 3) {
        isInside = (isInside && min.z <= aabb.min.z);
        isInside = (isInside && max.z >= aabb.max.z);
      }
      return isInside;
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
    if (max.x < aabb.min.x || aabb.max.x < min.x) return false;
    if (max.y < aabb.min.y || aabb.max.y < min.y) return false;
    static if (VT.Dims == 3) {
      if (max.z < aabb.min.z || aabb.max.z < min.z) return false;
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

  /// sweep two AABB's to see if and when they first and last were overlapping
  /// u0 = normalized time of first collision (i.e. collision starts at myMove*u0)
  /// u1 = normalized time of second collision (i.e. collision stops after myMove*u0)
  /// hitnormal = normal that will move `this` apart of `b` edge it collided with
  /// no output values are valid if no collision detected
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

  /// UNTESTED!
  bool sweepLine() (in auto ref VT myMove, in auto ref VT la, in auto ref VT lb, Float* u0, VT* hitnormal=null, Float* u1=null) const @trusted if (VT.Dims == 2) {
    mixin(ImportCoreMath!(Float, "fabs"));

    alias a = this;
    alias v = myMove;

    auto lineDir = lb-la;
    auto lineMin = VT(0, 0, 0);
    auto lineMax = VT(0, 0, 0);

    if (lineDir.x > 0) {
      // right
      lineMin.x = la.x;
      lineMax.x = lb.x;
    } else {
      // left
      lineMin.x = lb.x;
      lineMax.x = la.x;
    }

    if (lineDir.y > 0) {
      // up
      lineMin.y = la.y;
      lineMax.y = lb.y;
    } else {
      // down
      lineMin.y = lb.y;
      lineMax.y = la.y;
    }

    // initialise out info
    //outVel = v;
    //hitNormal = new VT(0,0);

    Float hitTime = 0;
    Float outTime = 1;
    Float[VT.Dims] overlapTime = 0;

    static if (VT.Dims == 3) {
      static assert(0, "not yet");
    } else {
      //auto lnorm = VT(-lineDir.y, lineDir.x).normalized;
      auto lnorm = lineDir.perp.normalized;
    }

    Float r = a.extent.x*fabs(lnorm.x)+a.extent.y*fabs(lnorm.y); // radius to line
    Float boxProj = (la-a.center).dot(lnorm); // projected line distance to n
    Float velProj = v.dot(lnorm); // projected velocity to n

    if (velProj < 0) r = -r;

    hitTime = nmax((boxProj-r)/velProj, hitTime);
    outTime = nmin((boxProj+r)/velProj, outTime);

    foreach (immutable aidx; 0..VT.Dims) {
      // axis overlap
      immutable Float vv = v[aidx];
      if (vv < 0) {
        immutable Float invv = cast(Float)1/vv;
        if (a.max[aidx] < lineMin[aidx]) return false;
        hitTime = nmax((overlapTime.ptr[aidx] = (lineMax[aidx]-a.min[aidx])*invv), hitTime);
        outTime = nmin((lineMin[aidx]-a.max[aidx])*invv, outTime);
        if (hitTime > outTime) return false;
      } else if (vv > 0) {
        immutable Float invv = cast(Float)1/vv;
        if (a.min[aidx] > lineMax[aidx]) return false;
        hitTime = nmax((overlapTime.ptr[aidx] = (lineMin[aidx]-a.max[aidx])*invv), hitTime);
        outTime = nmin((lineMax[aidx]-a.min[aidx])*invv, outTime);
        if (hitTime > outTime) return false;
      } else {
        if (lineMin[aidx] > a.max[aidx] || lineMax[aidx] < a.min[aidx]) return false;
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
    version(aabbtree_many_asserts) assert(freeNodeId >= mNodeCount && freeNodeId < mAllocCount);
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
      Float costLeft;
      AABB currentAndLeftAABB = AABB.mergeAABBs(newNodeAABB, mNodes[leftChild].aabb);
      if (mNodes[leftChild].leaf) {
        costLeft = currentAndLeftAABB.volume+costI;
      } else {
        Float leftChildVolume = mNodes[leftChild].aabb.volume;
        costLeft = costI+currentAndLeftAABB.volume-leftChildVolume;
      }

      // compute the cost of descending into the right child
      Float costRight;
      AABB currentAndRightAABB = AABB.mergeAABBs(newNodeAABB, mNodes[rightChild].aabb);
      if (mNodes[rightChild].leaf) {
        costRight = currentAndRightAABB.volume+costI;
      } else {
        Float rightChildVolume = mNodes[rightChild].aabb.volume;
        costRight = costI+currentAndRightAABB.volume-rightChildVolume;
      }

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
    int[256] stack = void; // stack with the nodes to visit
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
    version(aabbtree_many_asserts) assert(mRootNodeId >= 0 && mRootNodeId < mNodeCount);
    return mNodes[mRootNodeId].aabb;
  }

  /// does the given id represents a valid object?
  /// WARNING: ids of removed objects can be reused on later insertions!
  @property bool isValidId (int id) const nothrow @trusted @nogc { pragma(inline, true); return (id >= 0 && id < mNodeCount && mNodes[id].leaf); }

  /// get current extra AABB gap
  @property Float extraGap () const pure nothrow @trusted @nogc { pragma(inline, true); return mExtraGap; }

  /// set current extra AABB gap
  @property void extraGap (Float aExtraGap) pure nothrow @trusted @nogc { pragma(inline, true); mExtraGap = aExtraGap; }

  /// get object by id; can return null for invalid ids
  BodyBase getObject (int id) nothrow @trusted @nogc { pragma(inline, true); return (id >= 0 && id < mNodeCount && mNodes[id].leaf ? mNodes[id].flesh : null); }

  /// get fat object AABB by id; returns random shit for invalid ids
  AABB getObjectFatAABB (int id) nothrow @trusted @nogc { pragma(inline, true); return (id >= 0 && id < mNodeCount && !mNodes[id].free ? mNodes[id].aabb : AABB()); }

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
    if (nodeId < 0 || nodeId >= mNodeCount || !mNodes[nodeId].leaf) assert(0, "invalid node id");
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
    if (nodeId < 0 || nodeId >= mNodeCount || !mNodes[nodeId].leaf) assert(0, "invalid node id");

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
    version(aabbtree_many_asserts) assert(nid < 0 || (nid >= 0 && nid < mNodeCount && mNodes[nid].leaf));
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
