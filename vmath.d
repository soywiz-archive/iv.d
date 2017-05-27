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
// various vector and matrix operations.
// matrix should be compatible with OpenGL, but mostly untested.
module iv.vmath /*is aliced*/;
import iv.alice;

//version = aabbtree_many_asserts;


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

auto deg2rad(T : double) (T v) pure nothrow @safe @nogc { pragma(inline, true); import std.math : PI; return v*PI/180.0; }
auto rad2deg(T : double) (T v) pure nothrow @safe @nogc { pragma(inline, true); import std.math : PI; return v*180.0/PI; }


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

template IsVector(VT, FT) {
  static if (is(VT == VecN!(D, T), ubyte D, T)) {
    enum IsVector = is(T == FT);
  } else {
    enum IsVector = false;
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

  alias VecSelf = VecN!(dims, FloatType);
  alias Float = FloatType;
  alias Dims = dims;

public:
  FloatType x = 0;
  FloatType y = 0;
  static if (dims >= 3) FloatType z = 0;

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
  this (in FloatType[] c...) pure @trusted {
    x = (c.length >= 1 ? c.ptr[0] : 0);
    y = (c.length >= 2 ? c.ptr[1] : 0);
    static if (dims == 3) z = (c.length >= 3 ? c.ptr[2] : 0);
  }

  static if (dims == 2)
  this (in FloatType ax, in FloatType ay) pure {
    //pragma(inline, true);
    x = ax;
    y = ay;
  }

  static if (dims == 3)
  this (in FloatType ax, in FloatType ay, in FloatType az) pure {
    //pragma(inline, true);
    x = ax;
    y = ay;
    z = az;
  }

  this(VT) (in auto ref VT v) pure if (isVector!VT) {
    //pragma(inline, true);
    x = v.x;
    y = v.y;
    static if (dims == 3) {
      static if (isVector3!VT) z = v.z; else z = 0.0;
    }
  }

  @property bool valid () const nothrow @safe @nogc {
    pragma(inline, true);
    import core.stdc.math : isnan;
         static if (dims == 2) return !isnan(x) && !isnan(y);
    else static if (dims == 3) return !isnan(x) && !isnan(y) && !isnan(z);
    else static assert(0, "invalid dimension count for vector");
  }

  void set (in FloatType[] c...) pure @trusted {
    x = (c.length >= 1 ? c.ptr[0] : 0);
    y = (c.length >= 2 ? c.ptr[1] : 0);
    static if (dims == 3) z = (c.length >= 3 ? c.ptr[2] : 0);
  }

  static if (dims == 2)
  void set (in FloatType ax, in FloatType ay) pure {
    //pragma(inline, true);
    x = ax;
    y = ay;
  }

  static if (dims == 3)
  void set (in FloatType ax, in FloatType ay, in FloatType az) pure {
    //pragma(inline, true);
    x = ax;
    y = ay;
    z = az;
  }

  void opAssign(VT) (in auto ref VT v) pure if (isVector!VT) {
    //pragma(inline, true);
    x = v.x;
    y = v.y;
    static if (dims == 3) {
      static if (isVector3!VT) z = v.z; else z = 0.0;
    }
  }

  FloatType opIndex (usize idx) const pure {
    pragma(inline, true);
         static if (dims == 2) return (idx == 0 ? x : idx == 1 ? y : FloatType.nan);
    else static if (dims == 3) return (idx == 0 ? x : idx == 1 ? y : idx == 2 ? z : FloatType.nan);
    else static assert(0, "invalid dimension count for vector");
  }

  void opIndexAssign (FloatType v, usize idx) pure {
    pragma(inline, true);
         static if (dims == 2) { if (idx == 0) x = v; else if (idx == 1) y = v; }
    else static if (dims == 3) { if (idx == 0) x = v; else if (idx == 1) y = v; else if (idx == 2) z = v; }
    else static assert(0, "invalid dimension count for vector");
  }

  ref auto normalize () pure {
    //pragma(inline, true);
    import std.math : sqrt;
         static if (dims == 2) immutable FloatType invlength = cast(FloatType)1/sqrt(x*x+y*y);
    else static if (dims == 3) immutable FloatType invlength = cast(FloatType)1/sqrt(x*x+y*y+z*z);
    else static assert(0, "invalid dimension count for vector");
    x *= invlength;
    y *= invlength;
    static if (dims == 3) z *= invlength;
    return this;
  }

  /+
  ref auto safeNormalize () pure {
    //pragma(inline, true);
    import std.math : sqrt;
         static if (dims == 2) FloatType invlength = sqrt(x*x+y*y);
    else static if (dims == 3) FloatType invlength = sqrt(x*x+y*y+z*z);
    else static assert(0, "invalid dimension count for vector");
    if (invlength >= EPSILON!FloatType) {
      invlength = cast(FloatType)1/invlength;
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

  ref auto opOpAssign(string op) (FloatType a) if (op == "+" || op == "-" || op == "*") {
    //pragma(inline, true);
    mixin("x "~op~"= a;");
    mixin("y "~op~"= a;");
    static if (dims == 3) mixin("z "~op~"= a;");
    return this;
  }

  ref auto opOpAssign(string op:"/") (FloatType a) {
    //import std.math : abs;
    //pragma(inline, true);
    //a = (abs(a) >= EPSILON!FloatType ? 1.0/a : FloatType.nan);
    a = cast(FloatType)1/a;
    x *= a;
    y *= a;
    static if (dims == 3) z *= a;
    return this;
  }

  static if (dims == 2) {
    // radians
    ref auto rotate (float angle) {
      static if (is(FloatType == float)) {
        import core.stdc.math : cos=cosf, sin=sinf;
      } else static if (is(FloatType == double)) {
        import core.stdc.math : cos, sin;
      } else {
        import std.math : cos, sin;
      }
      pragma(inline, true);
      immutable FloatType c = cos(angle);
      immutable FloatType s = sin(angle);
      immutable FloatType nx = x*c-y*s;
      immutable FloatType ny = x*s+y*c;
      x = nx;
      y = ny;
      return this;
    }

    auto rotated (float angle) const {
      static if (is(FloatType == float)) {
        import core.stdc.math : cos=cosf, sin=sinf;
      } else static if (is(FloatType == double)) {
        import core.stdc.math : cos, sin;
      } else {
        import std.math : cos, sin;
      }
      pragma(inline, true);
      immutable FloatType c = cos(angle);
      immutable FloatType s = sin(angle);
      return v2(x*c-y*s, x*s+y*c);
    }
  }

const pure:
  auto lerp(VT) (in auto ref VT a, in FloatType t) if (isVector!VT) {
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

  @property FloatType length () {
    pragma(inline, true);
    import std.math : sqrt;
         static if (dims == 2) return sqrt(x*x+y*y);
    else static if (dims == 3) return sqrt(x*x+y*y+z*z);
    else static assert(0, "invalid dimension count for vector");
  }

  @property FloatType lengthSquared () {
    pragma(inline, true);
         static if (dims == 2) return x*x+y*y;
    else static if (dims == 3) return x*x+y*y+z*z;
    else static assert(0, "invalid dimension count for vector");
  }

  // distance
  FloatType distance(VT) (in auto ref VT a) if (isVector!VT) {
    pragma(inline, true);
    import std.math : sqrt;
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
  FloatType distanceSquared(VT) (in auto ref VT a) if (isVector!VT) {
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
  FloatType opBinary(string op:"*", VT) (in auto ref VT a) if (isVector!VT) {
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

  // cross product
  auto opBinary(string op:"%", VT) (in auto ref VT a) if (isVector!VT) {
    pragma(inline, true);
         static if (dims == 2 && isVector2!VT) return /*v3(0, 0, x*a.y-y*a.x)*/x*a.y-y*a.x;
    else static if (dims == 2 && isVector3!VT) return v3(y*a.z, -x*a.z, x*a.y-y*a.x);
    else static if (dims == 3 && isVector2!VT) return v3(-z*a.y, z*a.x, x*a.y-y*a.x);
    else static if (dims == 3 && isVector3!VT) return v3(y*a.z-z*a.y, z*a.x-x*a.z, x*a.y-y*a.x);
    else static assert(0, "invalid dimension count for vector");
  }

  auto opBinary(string op) (FloatType a) if (op == "+" || op == "-" || op == "*") {
    pragma(inline, true);
         static if (dims == 2) mixin("return v2(x"~op~"a, y"~op~"a);");
    else static if (dims == 3) mixin("return v3(x"~op~"a, y"~op~"a, z"~op~"a);");
    else static assert(0, "invalid dimension count for vector");
  }

  auto opBinaryRight(string op:"*") (FloatType a) {
    pragma(inline, true);
         static if (dims == 2) mixin("return v2(x"~op~"a, y"~op~"a);");
    else static if (dims == 3) mixin("return v3(x"~op~"a, y"~op~"a, z"~op~"a);");
    else static assert(0, "invalid dimension count for vector");
  }

  auto opBinary(string op:"/") (FloatType a) {
    pragma(inline, true);
    //import std.math : abs;
    //immutable FloatType a = (abs(aa) >= EPSILON!FloatType ? 1.0/aa : FloatType.nan);
    //immutable FloatType a = cast(FloatType)1/aa; // 1/0 == inf
    a = cast(FloatType)1/a; // 1/0 == inf
         static if (dims == 2) return v2(x*a, y*a);
    else static if (dims == 3) return v3(x*a, y*a, z*a);
    else static assert(0, "invalid dimension count for vector");
  }

  auto opBinaryRight(string op:"/") (FloatType aa) {
    pragma(inline, true);
    /*
    import std.math : abs;
         static if (dims == 2) return v2((abs(x) >= EPSILON!FloatType ? aa/x : 0), (abs(y) >= EPSILON!FloatType ? aa/y : 0));
    else static if (dims == 3) return v3((abs(x) >= EPSILON!FloatType ? aa/x : 0), (abs(y) >= EPSILON!FloatType ? aa/y : 0), (abs(z) >= EPSILON!FloatType ? aa/z : 0));
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

  auto abs () {
    pragma(inline, true);
    import std.math : abs;
         static if (dims == 2) return v2(abs(x), abs(y));
    else static if (dims == 3) return v3(abs(x), abs(y), abs(z));
    else static assert(0, "invalid dimension count for vector");
  }

  auto sign () {
    pragma(inline, true);
         static if (dims == 2) return v2((x < 0 ? -1 : x > 0 ? 1 : 0), (y < 0 ? -1 : y > 0 ? 1 : 0));
    else static if (dims == 3) return v3((x < 0 ? -1 : x > 0 ? 1 : 0), (y < 0 ? -1 : y > 0 ? 1 : 0), (z < 0 ? -1 : z > 0 ? 1 : 0));
    else static assert(0, "invalid dimension count for vector");
  }

  // `this` is edge; see glsl reference
  auto step() (in auto ref vec3 val) {
    pragma(inline, true);
         static if (dims == 2) return v2((val.x < this.x ? 0f : 1f), (val.y < this.y ? 0f : 1f));
    else static if (dims == 3) return v3((val.x < this.x ? 0f : 1f), (val.y < this.y ? 0f : 1f), (val.z < this.z ? 0f : 1f));
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

  // this dot v
  @property FloatType dot(VT) (in auto ref VT v) if (isVector!VT) { pragma(inline, true); return this*v; }

  // this cross v
  auto cross(VT) (in auto ref VT v) if (isVector!VT) { pragma(inline, true); return this%v; }

  // compute Euler angles from direction vector (this) (with zero roll)
  auto hpr () {
    import std.math : atan2, sqrt;
    auto tmp = this.normalized;
    /*hpr.x = -atan2(tmp.x, tmp.y);
      hpr.y = -atan2(tmp.z, sqrt(tmp.x*tmp.x+tmp.y*tmp.y));*/
    static if (dims == 2) {
      return v2(
        atan2(cast(FloatType)tmp.x, cast(FloatType)0.0),
        -atan2(cast(FloatType)tmp.y, cast(FloatType)tmp.x),
      );
    } else {
      return v3(
        atan2(cast(FloatType)tmp.x, cast(FloatType)tmp.z),
        -atan2(cast(FloatType)tmp.y, cast(FloatType)sqrt(tmp.x*tmp.x+tmp.z*tmp.z)),
        0
      );
    }
  }

  // some more supplementary functions to support various things
  FloatType vcos(VT) (in auto ref VT v) if (isVector!VT) {
    immutable double len = length*v.length;
    return (len > 0 ? dot(v)/len : 0.0);
  }

  FloatType vsin(VT) (in auto ref VT v) if (isVector!VT) {
    immutable double len = length*v.length;
    return (len > 0 ? cross(v)/len : 0.0);
  }

  FloatType angle180(VT) (in auto ref VT v) if (isVector!VT) {
    import std.math : atan, PI;
    immutable FloatType cosv = vcos(v);
    immutable FloatType sinv = vsin(v);
    if (cosv == 0) return (sinv <= 0 ? -90 : 90);
    if (sinv == 0) return (cosv <= 0 ? 180 : 0);
    FloatType angle = (180.0*atan(sinv/cosv))/PI;
    if (cosv < 0) { if (angle > 0) angle -= 180; else angle += 180; }
    return angle;
  }

  FloatType angle360(VT) (in auto ref VT v) if (isVector!VT) {
    import std.math : atan, PI;
    immutable FloatType cosv = vcos(v);
    immutable FloatType sinv = vsin(v);
    if (cosv == 0) return (sinv <= 0 ? 270 : 90);
    if (sinv == 0) return (cosv <= 0 ? 180 : 0);
    FloatType angle = (180.0*atan(sinv/cosv))/PI;
    if (cosv < 0) angle += 180;
    if (angle < 0) angle += 360;
    return angle;
  }

  FloatType relativeAngle(VT) (in auto ref VT v) if (isVector!VT) {
    import std.math : PI, acos;
    immutable FloatType cosv = vcos(v);
    if (cosv <= -1) return PI;
    if (cosv >= 1) return 0;
    return acos(cosv);
  }

  bool touch(VT) (in auto ref VT v) if (isVector!VT) { pragma(inline, true); return (distance(v) < /*SMALL*/EPSILON!FloatType); }
  bool touch(VT) (in auto ref VT v, in FloatType epsilon) if (isVector!VT) { pragma(inline, true); return (distance(v) < epsilon); }

  // is `this` on left?
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
    auto forAngle (in FloatType a) { pragma(inline, true); import std.math : cos, sin; return v2(cos(a), sin(a)); }

    // returns the angular direction v is pointing in (in radians)
    FloatType toAngle() () { pragma(inline, true); import std.math : atan2; return atan2(y, x); }

    auto scross() (FloatType s) { pragma(inline, true); return v2(-s*y, s*x); }
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
  VT lerp(VT) (in auto ref VT v1, in auto ref VT v2, const FloatType t) if (isSameVector!VT) {
    pragma(inline, true);
    return (v1*cast(FloatType)1.0f-t)+(v2*t);
  }
  */
}


// ////////////////////////////////////////////////////////////////////////// //
// plane in 3D space: Ax+By+Cz+D=0
align(1) struct Plane3(FloatType=VFloat, FloatType PlaneEps=-1.0, bool enableSwizzling=true) if (is(FloatType == float) || is(FloatType == double)) {
align(1):
public:
  alias plane3 = Plane3!(FloatType, PlaneEps, enableSwizzling);
  alias vec3 = VecN!(3, FloatType);
  static if (PlaneEps < 0) {
    enum EPS = EPSILON!FloatType;
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
  //FloatType a = 0, b = 0, c = 0, d = 0;
  vec3 normal;
  FloatType w;

nothrow @safe:
  string toString () const {
    import std.string : format;
    try {
      return "(%s,%s,%s,%s)".format(normal.x, normal.y, normal.z, w);
    } catch (Exception) {
      assert(0);
    }
  }

pure @nogc:
  this() (in auto ref vec3 anormal, FloatType aw) { pragma(inline, true); set(anormal, aw); }
  this() (in auto ref vec3 a, in auto ref vec3 b, in auto ref vec3 c) { pragma(inline, true); setFromPoints(a, b, c); }

  void set () (in auto ref vec3 anormal, FloatType aw) {
    import std.math : abs;
    normal = anormal;
    w = aw;
    if (abs(w) <= EPS) w = 0;
  }

  ref plane3 setFromPoints() (in auto ref vec3 a, in auto ref vec3 b, in auto ref vec3 c) @nogc {
    normal = ((b-a)%(c-a)).normalized;
    w = normal*a; // n.dot(a)
    return this;
  }

  @property bool valid () const { pragma(inline, true); import std.math : isNaN; return !isNaN(w); }

  FloatType opIndex (usize idx) const {
    pragma(inline, true);
    return (idx == 0 ? normal.x : idx == 1 ? normal.y : idx == 2 ? normal.z : idx == 3 ? w : FloatType.nan);
  }

  void opIndexAssign (FloatType v, usize idx) {
    pragma(inline, true);
    if (idx == 0) normal.x = v; else if (idx == 1) normal.y = v; else if (idx == 2) normal.z = v; else if (idx == 3) w = v;
  }

  ref plane3 normalize () {
    FloatType dd = normal.length;
    if (dd >= EPSILON!FloatType) {
      dd = 1.0/dd;
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

  FloatType pointSideF() (in auto ref vec3 p) const pure {
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
}


// ////////////////////////////////////////////////////////////////////////// //
struct Ray(VT) if (IsVector!VT) {
public:
  VT orig, dir;

nothrow @safe:
  string toString () const {
    import std.format : format;
    try {
      return "[(%s,%s):(%s,%s)]".format(orig.x, orig.y, dir.x, dir.y);
    } catch (Exception) {
      assert(0);
    }
  }

pure @nogc:
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
    import std.math : cos, sin;
    orig.x = x;
    orig.y = y;
    dir.x = cos(angle);
    dir.y = sin(angle);
  }

  void setOrigDir() (in auto ref VT aorg, VT.Float angle) {
    pragma(inline, true);
    import std.math : cos, sin;
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
    import std.math : cos, sin;
    dir.x = cos(angle);
    dir.y = sin(angle);
  }

  @property VT right () const {
    pragma(inline, true);
    static if (VT.Dims == 2) return VT(dir.y, -dir.x);
    else return VT(dir.y, -dir.x, dir.z);
  }

  VT movedBy (VT.Float len) const { pragma(inline, true); return orig+dir*len; }
}


// ////////////////////////////////////////////////////////////////////////// //
public struct AABBImpl(VT) if (IsVector!VT) {
private:
  static T nmin(T) (in T a, in T b) { pragma(inline, true); return (a < b ? a : b); }
  static T nmax(T) (in T a, in T b) { pragma(inline, true); return (a > b ? a : b); }

public:
  alias VType = VT;
  alias FType = VT.Float;
  alias Me = typeof(this);

public:
  VT min, max;

public:
  string toString () const {
    import std.format : format;
    return "[%s-%s]".format(min, max);
  }

public pure nothrow @safe @nogc:
  // return the volume of the AABB
  @property FType volume () const {
    pragma(inline, true);
    immutable diff = max-min;
    static if (VT.isVector3!VT) {
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
    static if (VT.isVector3!VT) {
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
    static if (VT.isVector3!VT) {
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
  void extrude (FType delta) {
    min.x -= delta;
    min.y -= delta;
    static if (VT.Dims == 3) min.z -= delta;
    max.x += delta;
    max.y += delta;
    static if (VT.Dims == 3) max.z += delta;
  }

  // return true if the current AABB is overlapping with the AABB in parameter
  // two AABBs overlap if they overlap in the two(three) x, y (and z) axes at the same time
  bool overlaps() (in auto ref Me aabb) const {
    //pragma(inline, true);
    if (max.x < aabb.min.x || aabb.max.x < min.x) return false;
    if (max.y < aabb.min.y || aabb.max.y < min.y) return false;
    static if (VT.isVector3!VT) {
      if (max.z < aabb.min.z || aabb.max.z < min.z) return false;
    }
    return true;
  }

  // ////////////////////////////////////////////////////////////////////////// //
  // something to consider here is that 0 * inf =nan which occurs when the ray starts exactly on the edge of a box
  // rd: ray direction, normalized
  // https://tavianator.com/fast-branchless-raybounding-box-intersections-part-2-nans/
  static bool intersect() (in auto ref VT bmin, in auto ref VT bmax, in auto ref Ray!VT ray, FType* tmino=null, FType* tmaxo=null) {
    // ok with coplanars, but dmd sux at unrolled loops
    // do X
    FType dinv = cast(FType)1/ray.dir.x; // 1/0 will produce inf
    FType t1 = (bmin.x-ray.orig.x)*dinv;
    FType t2 = (bmax.x-ray.orig.x)*dinv;
    FType tmin = nmin(t1, t2);
    FType tmax = nmax(t1, t2);
    // do Y
    dinv = cast(FType)1/ray.dir.y; // 1/0 will produce inf
    t1 = (bmin.y-ray.orig.y)*dinv;
    t2 = (bmax.y-ray.orig.y)*dinv;
    tmin = nmax(tmin, nmin(nmin(t1, t2), tmax));
    tmax = nmin(tmax, nmax(nmax(t1, t2), tmin));
    // do Z
    static if (VT.Dims == 3) {
      dinv = cast(FType)1/ray.dir.z; // 1/0 will produce inf
      t1 = (bmin.z-ray.orig.z)*dinv;
      t2 = (bmax.z-ray.orig.z)*dinv;
      tmin = nmax(tmin, nmin(nmin(t1, t2), tmax));
      tmax = nmin(tmax, nmax(nmax(t1, t2), tmin));
    }
    if (tmax > nmax(tmin, cast(FType)0)) {
      if (tmino !is null) *tmino = tmin;
      if (tmaxo !is null) *tmaxo = tmax;
      return true;
    } else {
      return false;
    }
  }

  bool intersect() (in auto ref Ray!VT ray, FType* tmino=null, FType* tmaxo=null) const @trusted {
    // ok with coplanars, but dmd sux at unrolled loops
    // do X
    FType dinv = cast(FType)1/ray.dir.x; // 1/0 will produce inf
    FType t1 = (min.x-ray.orig.x)*dinv;
    FType t2 = (max.x-ray.orig.x)*dinv;
    FType tmin = nmin(t1, t2);
    FType tmax = nmax(t1, t2);
    // do Y
    dinv = cast(FType)1/ray.dir.y; // 1/0 will produce inf
    t1 = (min.y-ray.orig.y)*dinv;
    t2 = (max.y-ray.orig.y)*dinv;
    tmin = nmax(tmin, nmin(nmin(t1, t2), tmax));
    tmax = nmin(tmax, nmax(nmax(t1, t2), tmin));
    // do Z
    static if (VT.Dims == 3) {
      dinv = cast(FType)1/ray.dir.z; // 1/0 will produce inf
      t1 = (min.z-ray.orig.z)*dinv;
      t2 = (max.z-ray.orig.z)*dinv;
      tmin = nmax(tmin, nmin(nmin(t1, t2), tmax));
      tmax = nmin(tmax, nmax(nmax(t1, t2), tmin));
    }
    if (tmax > nmax(tmin, cast(FType)0)) {
      if (tmino !is null) *tmino = tmin;
      if (tmaxo !is null) *tmaxo = tmax;
      return true;
    } else {
      return false;
    }
  }

  FType segIntersectMin() (in auto ref VT a, in auto ref VT b) const @trusted {
    FType tmin;
    if (!intersect(Ray!VT.fromPoints(a, b), &tmin)) return -1;
    if (tmin < 0) return 0; // inside
    if (tmin > (b-a).length) return -1;
    return tmin;
  }

  FType segIntersectMax() (in auto ref VT a, in auto ref VT b) const @trusted {
    FType tmax;
    if (!intersect(Ray!VT.fromPoints(a, b), null, &tmax)) return -1;
    if (tmax < 0) return 0; // inside
    if (tmax > (b-a).length) return -1;
    return tmax;
  }

  bool isIntersect() (in auto ref VT a, in auto ref VT b) const @trusted {
    //pragma(inline, true);
    // it may be faster to first check if start or end point is inside AABB (this is sometimes enough for dyntree)
    static if (VT.Dims == 2) {
      if (a.x >= min.x && a.y >= min.y && a.x <= max.x && a.y <= max.y) return true; // a
      if (b.x >= min.x && b.y >= min.y && b.x <= max.x && b.y <= max.y) return true; // b
    } else {
      if (a.x >= min.x && a.y >= min.y && a.z >= min.z && a.x <= max.x && a.y <= max.y && a.z <= max.z) return true; // a
      if (b.x >= min.x && b.y >= min.y && b.z >= min.z && b.x <= max.x && b.y <= max.y && b.z <= max.z) return true; // b
    }
    // nope, do it hard way
    //return (segIntersectMin(a, b) >= 0);
    FType tmin;
    if (!intersect(Ray!VT.fromPoints(a, b), &tmin)) return false;
    if (tmin < 0) return true; // inside, just in case
    if (tmin > (b-a).length) return false;
    return true;
  }

  ref inout(VT) opIndex (usize idx) inout {
    pragma(inline, true);
    return (idx == 0 ? min : max);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
alias mat4 = Mat4!float;

align(1) struct Mat4(FloatType=VFloat) if (is(FloatType == FloatType) || is(FloatType == double)) {
align(1):
public:
  alias mat4 = Mat4!FloatType;
  alias vec3 = VecN!(3, FloatType);

public:
   // OpenGL-compatible, row by row
  FloatType[4*4] mt = [
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

  @property FloatType opIndex (usize x, usize y) @trusted @nogc { pragma(inline, true); return (x < 4 && y < 4 ? mt.ptr[y*4+x] : FloatType.nan); }

@nogc @trusted:
  this() (in FloatType[] vals...) { pragma(inline, true); if (vals.length >= 16) mt.ptr[0..16] = vals.ptr[0..16]; else { mt.ptr[0..16] = 0; mt.ptr[0..vals.length] = vals.ptr[0..vals.length]; } }
  this() (in auto ref mat4 m) { pragma(inline, true); mt.ptr[0..16] = m.mt.ptr[0..16]; }
  this() (in auto ref vec3 v) {
    //mt.ptr[0..16] = 0;
    mt.ptr[0*4+0] = v.x;
    mt.ptr[1*4+1] = v.y;
    mt.ptr[2*4+2] = v.z;
    //mt.ptr[3*4+3] = 1; // just in case
  }

  static mat4 Zero () pure { pragma(inline, true); return mat4(0); }
  static mat4 Identity () pure { pragma(inline, true); /*mat4 res = Zero; res.mt.ptr[0*4+0] = res.mt.ptr[1*4+1] = res.mt.ptr[2*4+2] = res.mt.ptr[3*4+3] = 1; return res;*/ return mat4(); }

  private enum SinCosImportMixin = q{
    static if (is(FloatType == float)) {
      import core.stdc.math : cos=cosf, sin=sinf;
    } else static if (is(FloatType == double)) {
      import core.stdc.math : cos, sin;
    } else {
      import std.math : cos, sin;
    }
  };

  static mat4 RotateX() (FloatType angle) {
    mixin(SinCosImportMixin);
    auto res = mat4(0);
    res.mt.ptr[0*4+0] = 1.0;
    res.mt.ptr[1*4+1] = cos(angle);
    res.mt.ptr[2*4+1] = -sin(angle);
    res.mt.ptr[1*4+2] = sin(angle);
    res.mt.ptr[2*4+2] = cos(angle);
    res.mt.ptr[3*4+3] = 1.0;
    return res;
  }

  static mat4 RotateY() (FloatType angle) {
    mixin(SinCosImportMixin);
    auto res = mat4(0);
    res.mt.ptr[0*4+0] = cos(angle);
    res.mt.ptr[2*4+0] = sin(angle);
    res.mt.ptr[1*4+1] = 1.0;
    res.mt.ptr[0*4+2] = -sin(angle);
    res.mt.ptr[2*4+2] = cos(angle);
    res.mt.ptr[3*4+3] = 1.0;
    return res;
  }

  static mat4 RotateZ() (FloatType angle) {
    mixin(SinCosImportMixin);
    auto res = mat4(0);
    res.mt.ptr[0*4+0] = cos(angle);
    res.mt.ptr[1*4+0] = -sin(angle);
    res.mt.ptr[0*4+1] = sin(angle);
    res.mt.ptr[1*4+1] = cos(angle);
    res.mt.ptr[2*4+2] = 1.0;
    res.mt.ptr[3*4+3] = 1.0;
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
  static mat4 Frustum() (FloatType left, FloatType right, FloatType bottom, FloatType top, FloatType nearVal, FloatType farVal) nothrow @trusted @nogc {
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
  static mat4 Ortho() (FloatType left, FloatType right, FloatType bottom, FloatType top, FloatType nearVal, FloatType farVal) nothrow @trusted @nogc {
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
  // sets the frustum to perspective mode.
  // fovY   - Field of vision in degrees in the y direction
  // aspect - Aspect ratio of the viewport
  // zNear  - The near clipping distance
  // zFar   - The far clipping distance
  static mat4 Perspective() (FloatType fovY, FloatType aspect, FloatType zNear, FloatType zFar) nothrow @trusted @nogc {
    static if (is(FloatType == float)) {
      import core.stdc.math : tan=tanf;
    } else static if (is(FloatType == double)) {
      import core.stdc.math : tan;
    } else {
      import std.math : tan;
    }
    import std.math : PI;
    immutable FloatType fH = cast(FloatType)(tan(fovY/360*PI)*zNear);
    immutable FloatType fW = cast(FloatType)(fH*aspect);
    return frustum(-fW, fW, -fH, fH, zNear, zFar);
  }

public:
  // does `gluLookAt()`
  mat4 lookAt() (in auto ref vec3 eye, in auto ref vec3 center, in auto ref vec3 up) const {
    static if (is(FloatType == float)) {
      import core.stdc.math : sqrt=sqrtf;
    } else static if (is(FloatType == double)) {
      import core.stdc.math : sqrt;
    } else {
      import std.math : sqrt;
    }

    mat4 m = void;
    float[3] x = void, y = void, z = void;
    float mag;
    // make rotation matrix
    // Z vector
    z.ptr[0] = eye.x-center.x;
    z.ptr[1] = eye.y-center.y;
    z.ptr[2] = eye.z-center.z;
    mag = sqrt(z.ptr[0]*z.ptr[0]+z.ptr[1]*z.ptr[1]+z.ptr[2]*z.ptr[2]);
    if (mag != 0.0f) {
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
    if (mag != 0.0f) {
      x.ptr[0] /= mag;
      x.ptr[1] /= mag;
      x.ptr[2] /= mag;
    }

    mag = sqrt(y.ptr[0]*y.ptr[0]+y.ptr[1]*y.ptr[1]+y.ptr[2]*y.ptr[2]);
    if (mag != 0.0f) {
      y.ptr[0] /= mag;
      y.ptr[1] /= mag;
      y.ptr[2] /= mag;
    }

    m.mt.ptr[0*4+0] = x.ptr[0];
    m.mt.ptr[1*4+0] = x.ptr[1];
    m.mt.ptr[2*4+0] = x.ptr[2];
    m.mt.ptr[3*4+0] = 0.0f;
    m.mt.ptr[0*4+1] = y.ptr[0];
    m.mt.ptr[1*4+1] = y.ptr[1];
    m.mt.ptr[2*4+1] = y.ptr[2];
    m.mt.ptr[3*4+1] = 0.0f;
    m.mt.ptr[0*4+2] = z.ptr[0];
    m.mt.ptr[1*4+2] = z.ptr[1];
    m.mt.ptr[2*4+2] = z.ptr[2];
    m.mt.ptr[3*4+2] = 0.0f;
    m.mt.ptr[0*4+3] = 0.0f;
    m.mt.ptr[1*4+3] = 0.0f;
    m.mt.ptr[2*4+3] = 0.0f;
    m.mt.ptr[3*4+3] = 1.0f;

    // move, and translate Eye to Origin
    return this*m*Translate(-eye);
  }

  // rotate matrix to face along the target direction
  // this function will clear the previous rotation and scale, but it will keep the previous translation
  // it is for rotating object to look at the target, NOT for camera
  ref mat4 lookingAt() (in auto ref vec3 target) {
    static if (is(FloatType == float)) {
      import core.stdc.math : abs=fabsf;
    } else static if (is(FloatType == double)) {
      import core.stdc.math : abs=fabs;
    } else {
      import std.math : abs;
    }
    vec3 position = vec3(mt.ptr[12], mt.ptr[13], mt.ptr[14]);
    vec3 forward = (target-position).normalized;
    vec3 up;
    if (abs(forward.x) < EPSILON!FloatType && abs(forward.z) < EPSILON!FloatType) {
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

  ref mat4 rotate() (FloatType angle, in auto ref vec3 axis) {
    mixin(SinCosImportMixin);
    angle = deg2rad(angle);
    immutable FloatType c = cos(angle);
    immutable FloatType s = sin(angle);
    immutable FloatType c1 = 1-c;
    immutable FloatType m0 = mt.ptr[0], m4 = mt.ptr[4], m8 = mt.ptr[8], m12 = mt.ptr[12];
    immutable FloatType m1 = mt.ptr[1], m5 = mt.ptr[5], m9 = mt.ptr[9], m13 = mt.ptr[13];
    immutable FloatType m2 = mt.ptr[2], m6 = mt.ptr[6], m10 = mt.ptr[10], m14 = mt.ptr[14];

    // build rotation matrix
    immutable FloatType r0 = axis.x*axis.x*c1+c;
    immutable FloatType r1 = axis.x*axis.y*c1+axis.z*s;
    immutable FloatType r2 = axis.x*axis.z*c1-axis.y*s;
    immutable FloatType r4 = axis.x*axis.y*c1-axis.z*s;
    immutable FloatType r5 = axis.y*axis.y*c1+c;
    immutable FloatType r6 = axis.y*axis.z*c1+axis.x*s;
    immutable FloatType r8 = axis.x*axis.z*c1+axis.y*s;
    immutable FloatType r9 = axis.y*axis.z*c1-axis.x*s;
    immutable FloatType r10= axis.z*axis.z*c1+c;

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

  ref mat4 rotateX() (FloatType angle) {
    mixin(SinCosImportMixin);
    angle = deg2rad(angle);
    immutable FloatType c = cos(angle);
    immutable FloatType s = sin(angle);
    immutable FloatType m1 = mt.ptr[1], m2 = mt.ptr[2];
    immutable FloatType m5 = mt.ptr[5], m6 = mt.ptr[6];
    immutable FloatType m9 = mt.ptr[9], m10 = mt.ptr[10];
    immutable FloatType m13 = mt.ptr[13], m14 = mt.ptr[14];

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

  ref mat4 rotateY() (FloatType angle) {
    mixin(SinCosImportMixin);
    angle = deg2rad(angle);
    immutable FloatType c = cos(angle);
    immutable FloatType s = sin(angle);
    immutable FloatType m0 = mt.ptr[0], m2 = mt.ptr[2];
    immutable FloatType m4 = mt.ptr[4], m6 = mt.ptr[6];
    immutable FloatType m8 = mt.ptr[8], m10 = mt.ptr[10];
    immutable FloatType m12 = mt.ptr[12], m14 = mt.ptr[14];

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

  ref mat4 rotateZ() (FloatType angle) {
    mixin(SinCosImportMixin);
    angle = deg2rad(angle);
    immutable FloatType c = cos(angle);
    immutable FloatType s = sin(angle);
    immutable FloatType m0 = mt.ptr[0], m1 = mt.ptr[1];
    immutable FloatType m4 = mt.ptr[4], m5 = mt.ptr[5];
    immutable FloatType m8 = mt.ptr[8], m9 = mt.ptr[9];
    immutable FloatType m12 = mt.ptr[12], m13 = mt.ptr[13];

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

  mat4 rotated() (FloatType angle, in auto ref vec3 axis) const { pragma(inline, true); auto res = mat4(this); return res.rotate(angle, axis); }
  mat4 rotatedX() (FloatType angle) const { pragma(inline, true); auto res = mat4(this); return res.rotateX(angle); }
  mat4 rotatedY() (FloatType angle) const { pragma(inline, true); auto res = mat4(this); return res.rotateY(angle); }
  mat4 rotatedZ() (FloatType angle) const { pragma(inline, true); auto res = mat4(this); return res.rotateZ(angle); }
  mat4 translated() (in auto ref vec3 v) const { pragma(inline, true); auto res = mat4(this); return res.translate(v); }
  mat4 scaled() (in auto ref vec3 v) const { pragma(inline, true); auto res = mat4(this); return res.scale(v); }

  // retrieve angles in degree from rotation matrix, M = Rx*Ry*Rz
  // Rx: rotation about X-axis, pitch
  // Ry: rotation about Y-axis, yaw (heading)
  // Rz: rotation about Z-axis, roll
  vec3 getAngles () const {
    static if (is(FloatType == float)) {
      import core.stdc.math : atan2=atan2f, asin=asinf;
    } else static if (is(FloatType == double)) {
      import core.stdc.math : atan2, asin;
    } else {
      import std.math : atan2, asin;
    }
    FloatType pitch = void, roll = void;
    FloatType yaw = rad2deg(asin(mt.ptr[8]));
    if (mt.ptr[10] < 0) {
      if (yaw >= 0) yaw = 180-yaw; else yaw = -180-yaw;
    }
    if (mt.ptr[0] > -EPSILON!FloatType && mt.ptr[0] < EPSILON!FloatType) {
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

  mat4 opBinary(string op:"*") (FloatType a) const {
    auto res = mat4(this);
    res.mt[] *= a;
    return res;
  }

  mat4 opBinary(string op:"/") (FloatType a) const {
    import std.math : abs;
    auto res = mat4(this);
    if (abs(a) >= FLTEPS) {
      a = 1.0/a;
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

  FloatType determinant() () const {
    return mt.ptr[0]*getCofactor(mt.ptr[5], mt.ptr[6], mt.ptr[7], mt.ptr[9], mt.ptr[10], mt.ptr[11], mt.ptr[13], mt.ptr[14], mt.ptr[15])-
           mt.ptr[1]*getCofactor(mt.ptr[4], mt.ptr[6], mt.ptr[7], mt.ptr[8], mt.ptr[10], mt.ptr[11], mt.ptr[12], mt.ptr[14], mt.ptr[15])+
           mt.ptr[2]*getCofactor(mt.ptr[4], mt.ptr[5], mt.ptr[7], mt.ptr[8], mt.ptr[9], mt.ptr[11], mt.ptr[12], mt.ptr[13], mt.ptr[15])-
           mt.ptr[3]*getCofactor(mt.ptr[4], mt.ptr[5], mt.ptr[6], mt.ptr[8], mt.ptr[9], mt.ptr[10], mt.ptr[12], mt.ptr[13], mt.ptr[14]);
  }

  ///////////////////////////////////////////////////////////////////////////////
  // compute the inverse of 4x4 Euclidean transformation matrix
  //
  // Euclidean transformation is translation, rotation, and reflection.
  // With Euclidean transform, only the position and orientation of the object
  // will be changed. Euclidean transform does not change the shape of an object
  // (no scaling). Length and angle are reserved.
  //
  // Use inverseAffine() if the matrix has scale and shear transformation.
  ref mat4 invertedEuclidean() () {
    FloatType tmp = void;
    tmp = mt.ptr[1]; mt.ptr[1] = mt.ptr[4]; mt.ptr[4] = tmp;
    tmp = mt.ptr[2]; mt.ptr[2] = mt.ptr[8]; mt.ptr[8] = tmp;
    tmp = mt.ptr[6]; mt.ptr[6] = mt.ptr[9]; mt.ptr[9] = tmp;
    FloatType x = mt.ptr[12];
    FloatType y = mt.ptr[13];
    FloatType z = mt.ptr[14];
    mt.ptr[12] = -(mt.ptr[0]*x+mt.ptr[4]*y+mt.ptr[8]*z);
    mt.ptr[13] = -(mt.ptr[1]*x+mt.ptr[5]*y+mt.ptr[9]*z);
    mt.ptr[14] = -(mt.ptr[2]*x+mt.ptr[6]*y+mt.ptr[10]*z);
    return this;
  }

  ref mat4 inverted() () {
    // If the 4th row is [0,0,0,1] then it is affine matrix and
    // it has no projective transformation.
    if (mt.ptr[3] == 0 && mt.ptr[7] == 0 && mt.ptr[11] == 0 && mt.ptr[15] == 1) {
      invertedAffine();
    } else {
      invertedGeneral();
    }
    return this;
  }

  ///////////////////////////////////////////////////////////////////////////////
  // compute the inverse of a general 4x4 matrix using Cramer's Rule
  // If cannot find inverse, return indentity matrix
  ref mat4 invertedGeneral() () {
    static if (is(FloatType == float)) {
      import core.stdc.math : abs=fabsf;
    } else static if (is(FloatType == double)) {
      import core.stdc.math : abs=fabs;
    } else {
      import std.math : abs;
    }

    FloatType cofactor0 = getCofactor(mt.ptr[5], mt.ptr[6], mt.ptr[7], mt.ptr[9], mt.ptr[10], mt.ptr[11], mt.ptr[13], mt.ptr[14], mt.ptr[15]);
    FloatType cofactor1 = getCofactor(mt.ptr[4], mt.ptr[6], mt.ptr[7], mt.ptr[8], mt.ptr[10], mt.ptr[11], mt.ptr[12], mt.ptr[14], mt.ptr[15]);
    FloatType cofactor2 = getCofactor(mt.ptr[4], mt.ptr[5], mt.ptr[7], mt.ptr[8], mt.ptr[9], mt.ptr[11], mt.ptr[12], mt.ptr[13], mt.ptr[15]);
    FloatType cofactor3 = getCofactor(mt.ptr[4], mt.ptr[5], mt.ptr[6], mt.ptr[8], mt.ptr[9], mt.ptr[10], mt.ptr[12], mt.ptr[13], mt.ptr[14]);

    FloatType determinant = mt.ptr[0]*cofactor0-mt.ptr[1]*cofactor1+mt.ptr[2]*cofactor2-mt.ptr[3]*cofactor3;
    if (abs(determinant) <= EPSILON!FloatType) { this = Identity; return this; }

    FloatType cofactor4 = getCofactor(mt.ptr[1], mt.ptr[2], mt.ptr[3], mt.ptr[9], mt.ptr[10], mt.ptr[11], mt.ptr[13], mt.ptr[14], mt.ptr[15]);
    FloatType cofactor5 = getCofactor(mt.ptr[0], mt.ptr[2], mt.ptr[3], mt.ptr[8], mt.ptr[10], mt.ptr[11], mt.ptr[12], mt.ptr[14], mt.ptr[15]);
    FloatType cofactor6 = getCofactor(mt.ptr[0], mt.ptr[1], mt.ptr[3], mt.ptr[8], mt.ptr[9], mt.ptr[11], mt.ptr[12], mt.ptr[13], mt.ptr[15]);
    FloatType cofactor7 = getCofactor(mt.ptr[0], mt.ptr[1], mt.ptr[2], mt.ptr[8], mt.ptr[9], mt.ptr[10], mt.ptr[12], mt.ptr[13], mt.ptr[14]);

    FloatType cofactor8 = getCofactor(mt.ptr[1], mt.ptr[2], mt.ptr[3], mt.ptr[5], mt.ptr[6], mt.ptr[7],  mt.ptr[13], mt.ptr[14], mt.ptr[15]);
    FloatType cofactor9 = getCofactor(mt.ptr[0], mt.ptr[2], mt.ptr[3], mt.ptr[4], mt.ptr[6], mt.ptr[7],  mt.ptr[12], mt.ptr[14], mt.ptr[15]);
    FloatType cofactor10= getCofactor(mt.ptr[0], mt.ptr[1], mt.ptr[3], mt.ptr[4], mt.ptr[5], mt.ptr[7],  mt.ptr[12], mt.ptr[13], mt.ptr[15]);
    FloatType cofactor11= getCofactor(mt.ptr[0], mt.ptr[1], mt.ptr[2], mt.ptr[4], mt.ptr[5], mt.ptr[6],  mt.ptr[12], mt.ptr[13], mt.ptr[14]);

    FloatType cofactor12= getCofactor(mt.ptr[1], mt.ptr[2], mt.ptr[3], mt.ptr[5], mt.ptr[6], mt.ptr[7],  mt.ptr[9], mt.ptr[10], mt.ptr[11]);
    FloatType cofactor13= getCofactor(mt.ptr[0], mt.ptr[2], mt.ptr[3], mt.ptr[4], mt.ptr[6], mt.ptr[7],  mt.ptr[8], mt.ptr[10], mt.ptr[11]);
    FloatType cofactor14= getCofactor(mt.ptr[0], mt.ptr[1], mt.ptr[3], mt.ptr[4], mt.ptr[5], mt.ptr[7],  mt.ptr[8], mt.ptr[9], mt.ptr[11]);
    FloatType cofactor15= getCofactor(mt.ptr[0], mt.ptr[1], mt.ptr[2], mt.ptr[4], mt.ptr[5], mt.ptr[6],  mt.ptr[8], mt.ptr[9], mt.ptr[10]);

    FloatType invDeterminant = cast(FloatType)1.0/determinant;
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
  // NOTE: The caller must know its sign.
  private static FloatType getCofactor() (FloatType m0, FloatType m1, FloatType m2, FloatType m3, FloatType m4, FloatType m5, FloatType m6, FloatType m7, FloatType m8) {
    pragma(inline, true);
    return m0*(m4*m8-m5*m7)-m1*(m3*m8-m5*m6)+m2*(m3*m7-m4*m6);
  }

  Quat4!FloatType toQuaternion () const nothrow @trusted @nogc {
    static if (is(FloatType == float)) {
      import core.stdc.math : sqrt=sqrtf;
    } else static if (is(FloatType == double)) {
      import core.stdc.math : sqrt;
    } else {
      import std.math : sqrt;
    }
    Quat4!FloatType res = void;
    FloatType tr = mt.ptr[0*4+0]+mt.ptr[1*4+1]+mt.ptr[2*4+2];
    // check the diagonal
    if (tr > 0) {
      FloatType s = sqrt(tr+1.0);
      res.w = s/cast(FloatType)2;
      s = cast(FloatType)0.5/s;
      res.x = (mt.ptr[2*4+1]-mt.ptr[1*4+2])*s;
      res.y = (mt.ptr[0*4+2]-mt.ptr[2*4+0])*s;
      res.z = (mt.ptr[1*4+0]-mt.ptr[0*4+1])*s;
    } else {
      // diagonal is negative
      int i, j, k;
      int[3] nxt = [1, 2, 0];
      FloatType s = void;
      FloatType[4] q = void;
      i = 0;
      if (mt.ptr[1*4+1] > mt.ptr[0*4+0]) i = 1;
      if (mt.ptr[2*4+2] > mt.ptr[i*4+i]) i = 2;
      j = nxt.ptr[i];
      k = nxt.ptr[j];
      s = sqrt((mt.ptr[i*4+i]-(mt.ptr[j*4+j]+mt.ptr[k*4+k]))+cast(FloatType)1);
      q[i] = s*cast(FloatType)0.5;
      if (s != 0) s = cast(FloatType)0.5/s;
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
alias quat4 = Quat4!float;

align(1) struct Quat4(FloatType=VFloat) {
align(1):
  alias quat4 = Quat4!FloatType;

  FloatType w=1, x=0, y=0, z=0;

  this (FloatType aw, FloatType ax, FloatType ay, FloatType az) nothrow @trusted @nogc {
    w = aw;
    x = ax;
    y = ay;
    z = az;
  }

  static quat4 Identity () nothrow @trusted @nogc { pragma(inline, true); return quat4(1, 0, 0, 0); }

  static quat4 fromAngles (FloatType roll, FloatType pitch, FloatType yaw) nothrow @trusted @nogc {
    static if (is(FloatType == float)) {
      import core.stdc.math : cos=cosf, sin=sinf;
    } else static if (is(FloatType == double)) {
      import core.stdc.math : cos, sin;
    } else {
      import std.math : cos, sin;
    }
    // calculate trig identities
    FloatType cr = cos(roll/2);
    FloatType cp = cos(pitch/2);
    FloatType cy = cos(yaw/2);
    FloatType sr = sin(roll/2);
    FloatType sp = sin(pitch/2);
    FloatType sy = sin(yaw/2);
    FloatType cpcy = cp*cy;
    FloatType spsy = sp*sy;
    return quat4(
      cr*cpcy+sr*spsy,
      sr*cpcy-cr*spsy,
      cr*sp*cy+sr*cp*sy,
      cr*cp*sy-sr*sp*cy,
    );
  }

  @property bool valid () const nothrow @safe @nogc { pragma(inline, true); import core.stdc.math : isnan; return !isnan(w) && !isnan(x) && !isnan(y) && !isnan(z); }

  Mat4!FloatType toMatrix () const nothrow @trusted @nogc {
    Mat4!FloatType res = void;
    FloatType wx = void, wy = void, wz = void, xx = void, yy = void, yz = void;
    FloatType xy = void, xz = void, zz = void, x2 = void, y2 = void, z2 = void;

    // calculate coefficients
    x2 = this.x+this.x; y2 = this.y+this.y;
    z2 = this.z+this.z;
    xx = this.x*x2; xy = this.x*y2; xz = this.x*z2;
    yy = this.y*y2; yz = this.y*z2; zz = this.z*z2;
    wx = this.w*x2; wy = this.w*y2; wz = this.w*z2;


    res.mt.ptr[0*4+0] = cast(FloatType)1-(yy+zz);
    res.mt.ptr[0*4+1] = xy-wz;
    res.mt.ptr[0*4+2] = xz+wy;
    res.mt.ptr[0*4+3] = 0;

    res.mt.ptr[1*4+0] = xy+wz;
    res.mt.ptr[1*4+1] = cast(FloatType)1-(xx+zz);
    res.mt.ptr[1*4+2] = yz-wx;
    res.mt.ptr[1*4+3] = 0;


    res.mt.ptr[2*4+0] = xz-wy;
    res.mt.ptr[2*4+1] = yz+wx;
    res.mt.ptr[2*4+2] = cast(FloatType)1-(xx+yy);
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
    FloatType A = (this.w+this.x)*(q2.w+q2.x);
    FloatType B = (this.z-this.y)*(q2.y-q2.z);
    FloatType C = (this.w-this.x)*(q2.y+q2.z);
    FloatType D = (this.y+this.z)*(q2.w-q2.x);
    FloatType E = (this.x+this.z)*(q2.x+q2.y);
    FloatType F = (this.x-this.z)*(q2.x-q2.y);
    FloatType G = (this.w+this.y)*(q2.w-q2.z);
    FloatType H = (this.w-this.y)*(q2.w+q2.z);
    this.w = B+(-E-F+G+H)/2;
    this.x = A-(E+F+G+H)/2;
    this.y = C+(E-F+G-H)/2;
    this.z = D+(E-F-G+H)/2;
    return this;
  }

  quat4 slerp() (in auto ref quat4 to, FloatType t) const nothrow @trusted @nogc {
    static if (is(FloatType == float)) {
      import core.stdc.math : acos, sin;
    } else static if (is(FloatType == double)) {
      import core.stdc.math : acos, sin;
    } else {
      import std.math : acos, sin;
    }
    FloatType[4] to1 = void;
    // calc cosine
    double cosom = this.x*to.x+this.y*to.y+this.z*to.z+this.w*to.w;
    // adjust signs (if necessary)
    if (cosom < 0.0) {
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
    double scale0 = void, scale1 = void;
    // calculate coefficients
    if (1.0-cosom > EPSILON!double) {
      // standard case (slerp)
      double omega = acos(cosom);
      double sinom = sin(omega);
      scale0 = sin((1.0-t)*omega)/sinom;
      scale1 = sin(t*omega)/sinom;
    } else {
      // "from" and "to" quaternions are very close
      //  ... so we can do a linear interpolation
      scale0 = 1.0-t;
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
// very simple (and mostly not tested) 3x3 matrix
align(1) struct Mat3F(FloatType=VFloat) if (is(FloatType == float) || is(FloatType == double)) {
align(1):

private:
  alias m3 = mat3!FloatType;
  alias v2 = VecN!(2, FloatType);
  alias v3 = VecN!(3, FloatType);

  enum isVector(VT) = (is(VT == VecN!(2, FloatType)) || is(VT == VecN!(3, FloatType)));
  enum isVector2(VT) = is(VT == VecN!(2, FloatType));
  enum isVector3(VT) = is(VT == VecN!(3, FloatType));

private:
  // 3x3 matrix components
  FloatType[3*3] m = [
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
  this (const(FloatType)[] vals...) {
    pragma(inline, true);
    if (vals.length >= 3*3) {
      m.ptr[0..9] = vals.ptr[0..9];
    } else {
      m.ptr[0..9] = 0;
      m.ptr[0..vals.length] = vals[];
    }
  }

  FloatType opIndex (usize x, usize y) const {
    pragma(inline, true);
    return (x < 3 && y < 3 ? m.ptr[y*3+x] : FloatType.nan);
  }

  void opIndexAssign (FloatType v, usize x, usize y) {
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

  auto opBinary(string op) (in FloatType b) const if (op == "*" || op == "/") {
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

  auto opBinaryRight(string op) (in FloatType b) const if (op == "*" || op == "/") {
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

  ref auto opOpAssign(string op) (in FloatType b) if (op == "*" || op == "/") {
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
  FloatType trace () const { pragma(inline, true); return m.ptr[3*0+0]+m.ptr[3*1+1]+m.ptr[3*2+2]; }

  // determinant
  FloatType det () const {
    pragma(inline, true);
    FloatType res = 0;
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

  auto Rotate (in FloatType angle) {
    pragma(inline, true);
    mixin(SinCosImportMixin);
    immutable FloatType c = cos(angle);
    immutable FloatType s = sin(angle);
    m3 res;
    res.m.ptr[3*0+0] =  c; res.m.ptr[3*0+1] = s;
    res.m.ptr[3*1+0] = -s; res.m.ptr[3*1+1] = c;
    return res;
  }

  auto Scale (in FloatType sx, in FloatType sy) {
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

  auto Translate (in FloatType dx, in FloatType dy) {
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
    static if (is(FloatType == float)) {
      import core.stdc.math : cos=cosf, sin=sinf;
    } else static if (is(FloatType == double)) {
      import core.stdc.math : cos, sin;
    } else {
      import std.math : cos, sin;
    }
  };
}

alias mat3 = Mat3F!VFloat;


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
private align(1) struct TreeNodeBase(VT, BodyBase) {
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
  // height of the node in the tree
  short height;
  // fat axis aligned bounding box (AABB) corresponding to the node
  AABBImpl!VT aabb;
  // return true if the node is a leaf of the tree
  @property bool leaf () const pure nothrow @safe @nogc { pragma(inline, true); return (height == 0); }
}


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
  alias FType = VT.Float;
  alias Me = typeof(this);
  alias AABB = AABBImpl!VT;
  alias TreeNode = TreeNodeBase!(VT, BodyBase);

  enum FloatNum(FType v) = cast(FType)v;

public:
  // in the broad-phase collision detection (dynamic AABB tree), the AABBs are
  // also inflated in direction of the linear motion of the body by mutliplying the
  // followin constant with the linear velocity and the elapsed time between two frames
  enum FType LinearMotionGapMultiplier = FloatNum!(1.7);

public:
  // called when a overlapping node has been found during the call to forEachAABBOverlap()
  // return `true` to stop
  alias OverlapCallback = void delegate (BodyBase abody);
  alias SimpleQueryCallback = bool delegate (BodyBase abody);
  alias SegQueryCallback = FType delegate (BodyBase abody, in ref VT a, in ref VT b); // return dist from a to abody

private:
  TreeNode* mNodes; // pointer to the memory location of the nodes of the tree
  int mRootNodeId; // id of the root node of the tree
  int mFreeNodeId; // id of the first node of the list of free (allocated) nodes in the tree that we can use
  int mAllocCount; // number of allocated nodes in the tree
  int mNodeCount; // number of nodes in the tree

  // extra AABB Gap used to allow the collision shape to move a little bit
  // without triggering a large modification of the tree which can be costly
  FType mExtraGap;

private:
  // allocate and return a node to use in the tree
  int allocateNode () {
    // if there is no more allocated node to use
    if (mFreeNodeId == TreeNode.NullTreeNode) {
      import core.stdc.stdlib : realloc;
      version(aabbtree_many_asserts) assert(mNodeCount == mAllocCount);
      // allocate more nodes in the tree
      auto newsz = (mAllocCount < 4096 ? mAllocCount*2 : mAllocCount+4096);
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
      FType volumeAABB = mNodes[currentNodeId].aabb.volume;
      AABB mergedAABBs = AABB.mergeAABBs(mNodes[currentNodeId].aabb, newNodeAABB);
      FType mergedVolume = mergedAABBs.volume;

      // compute the cost of making the current node the sibling of the new node
      FType costS = FloatNum!2*mergedVolume;

      // compute the minimum cost of pushing the new node further down the tree (inheritance cost)
      FType costI = FloatNum!2*(mergedVolume-volumeAABB);

      // compute the cost of descending into the left child
      FType costLeft;
      AABB currentAndLeftAABB = AABB.mergeAABBs(newNodeAABB, mNodes[leftChild].aabb);
      if (mNodes[leftChild].leaf) {
        costLeft = currentAndLeftAABB.volume+costI;
      } else {
        FType leftChildVolume = mNodes[leftChild].aabb.volume;
        costLeft = costI+currentAndLeftAABB.volume-leftChildVolume;
      }

      // compute the cost of descending into the right child
      FType costRight;
      AABB currentAndRightAABB = AABB.mergeAABBs(newNodeAABB, mNodes[rightChild].aabb);
      if (mNodes[rightChild].leaf) {
        costRight = currentAndRightAABB.volume+costI;
      } else {
        FType rightChildVolume = mNodes[rightChild].aabb.volume;
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

    // If the sibling node was not the root node
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

    // If we are removing the root node (root node is a leaf in this case)
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
  // this method returns the new root node Id
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

    // If the node is a leaf, its height is zero
    if (node.leaf) return 0;

    // Compute the height of the left and right sub-tree
    int leftHeight = computeHeight(node.children.ptr[TreeNode.Left]);
    int rightHeight = computeHeight(node.children.ptr[TreeNode.Right]);

    // Return the height of the node
    return 1+max(leftHeight, rightHeight);
  }

  // internally add an object into the tree
  int insertObjectInternal() (in auto ref AABB aabb) {
    // get the next available node (or allocate new ones if necessary)
    int nodeId = allocateNode();

    // create the fat aabb to use in the tree
    immutable gap = AABB.VType(mExtraGap, mExtraGap, mExtraGap);
    mNodes[nodeId].aabb.min = aabb.min-gap;
    mNodes[nodeId].aabb.max = aabb.max+gap;

    // set the height of the node in the tree
    mNodes[nodeId].height = 0;

    // insert the new leaf node in the tree
    insertLeafNode(nodeId);
    version(aabbtree_many_asserts) assert(mNodes[nodeId].leaf);

    version(aabbtree_many_asserts) assert(nodeId >= 0);

    // return the Id of the node
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
  public void forEachLeaf (scope void delegate (/*int nodeId*/BodyBase abody, in ref AABB aabb) dg) {
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
        if (dg !is null) dg(/*nodeId*/pNode.flesh, pNode.aabb);
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

  // return `true` from visitor to stop immediately
  // checker should check if this node should be considered to further checking
  // returns tree node if visitor says stop or -1
  private int visit (scope bool delegate (TreeNode* node) checker, scope bool delegate (BodyBase abody) visitor) {
    int[256] stack = void; // stack with the nodes to visit
    int sp = 0;

    void spush (int id) {
      if (sp >= stack.length) throw new Exception("stack overflow");
      stack.ptr[sp++] = id;
    }

    int spop () {
      if (sp == 0) throw new Exception("stack underflow");
      return stack.ptr[--sp];
    }

    // start from root node
    spush(mRootNodeId);

    // while there are still nodes to visit
    while (sp > 0) {
      // get the next node id to visit
      int nodeId = spop();
      // skip it if it is a null node
      if (nodeId == TreeNode.NullTreeNode) continue;
      // get the corresponding node
      TreeNode* node = mNodes+nodeId;
      // should we investigate this node?
      if (checker(node)) {
        // if the node is a leaf
        if (node.leaf) {
          // call visitor on it
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
  this (FType extraAABBGap=FloatNum!0) {
    mExtraGap = extraAABBGap;
    setup();
  }

  ~this () {
    import core.stdc.stdlib : free;
    static if (GCAnchor) gcRelease();
    free(mNodes);
  }

  // return the root AABB of the tree
  AABB getRootAABB () {
    pragma(inline, true);
    version(aabbtree_many_asserts) assert(mRootNodeId >= 0 && mRootNodeId < mNodeCount);
    return mNodes[mRootNodeId].aabb;
  }

  /// insert an object into the tree
  /// this method creates a new leaf node in the tree and returns the Id of the corresponding node
  int insertObject (BodyBase flesh) {
    auto aabb = flesh.getAABB(); // can be passed as argument
    int nodeId = insertObjectInternal(aabb);
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
  void removeObject (int nodeId) {
    if (nodeId < 0) return;
    if (nodeId >= mNodeCount) assert(0, "node id out of bounds");
    version(aabbtree_many_asserts) assert(nodeId >= 0 && nodeId < mNodeCount);
    version(aabbtree_many_asserts) assert(mNodes[nodeId].leaf);
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
   * return `true` if the tree was modified.
   */
  bool updateObject() (int nodeId, in auto ref AABB.VType displacement, bool forceReinsert=false) {
    version(aabbtree_many_asserts) assert(nodeId >= 0 && nodeId < mAllocCount);
    version(aabbtree_many_asserts) assert(mNodes[nodeId].leaf);
    version(aabbtree_many_asserts) assert(mNodes[nodeId].height >= 0);

    auto newAABB = mNodes[nodeId].flesh.getAABB(); // can be passed as argument

    // if the new AABB is still inside the fat AABB of the node
    if (!forceReinsert && mNodes[nodeId].aabb.contains(newAABB)) return false;

    // if the new AABB is outside the fat AABB, we remove the corresponding node
    removeLeafNode(nodeId);

    // compute the fat AABB by inflating the AABB with a constant gap
    mNodes[nodeId].aabb = newAABB;
    static if (VT.Dims == 2) {
      immutable gap = VT(mExtraGap, mExtraGap);
    } else {
      immutable gap = VT(mExtraGap, mExtraGap, mExtraGap);
    }
    mNodes[nodeId].aabb.mMin -= gap;
    mNodes[nodeId].aabb.mMax += gap;

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
    static if (AABB.VType.isVector3!(AABB.VType)) {
      if (displacement.z < FloatNum!0) {
        mNodes[nodeId].aabb.mMin.z += LinearMotionGapMultiplier *displacement.z;
      } else {
        mNodes[nodeId].aabb.mMax.z += LinearMotionGapMultiplier *displacement.z;
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

  ///
  static struct SegmentQueryResult {
    FType dist = -1; /// <0: nothing was hit
    BodyBase flesh; ///

    @property bool valid () const pure nothrow @safe @nogc { pragma(inline, true); return (dist >= 0 && flesh !is null); } ///
  }

  /// segment querying method
  SegmentQueryResult segmentQuery() (in auto ref VT a, in auto ref VT b, scope SegQueryCallback cb) {
    SegmentQueryResult res;
    FType maxFraction = FType.infinity;

    immutable VT cura = a;
    VT curb = b;
    immutable VT dir = (curb-cura).normalized;

    visit(
      // checker
      (node) => node.aabb.isIntersect(cura, curb),
      // visitor
      (flesh) {
        FType hitFraction = cb(flesh, a, b);
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

  auto res = tree.segmentQuery(ro, re, delegate (int nodeId, in ref vec2 a, in ref vec2 b) {
    auto dst = flesh.aabb.segIntersectMin(a, b);
    writeln("a=", a, "; b=", b, "; dst=", dst);
    if (dst < 0) return -1;
    return dst;
  });

  writeln(res);
}
*/
