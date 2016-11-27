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
enum DBLEPS = 1e-18f;
template EPSILON(T) if (is(T == float) || is(T == double)) {
       static if (is(T == float)) enum EPSILON = FLTEPS;
  else static if (is(T == double)) enum EPSILON = DBLEPS;
  else static assert(0, "wtf?!");
}

auto deg2rad(T : double) (T v) pure nothrow @safe @nogc { pragma(inline, true); import std.math : PI; return v*PI/180.0; }
auto rad2deg(T : double) (T v) pure nothrow @safe @nogc { pragma(inline, true); import std.math : PI; return v*180.0/PI; }


// ////////////////////////////////////////////////////////////////////////// //
alias vec2 = VecN!2;
alias vec3 = VecN!3;


template IsVector(VT) {
  static if (is(VT == VecN!(D, T), ubyte D, T)) {
    enum IsVector = true;
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

  FloatType opIndex (size_t idx) const pure {
    pragma(inline, true);
         static if (dims == 2) return (idx == 0 ? x : idx == 1 ? y : FloatType.nan);
    else static if (dims == 3) return (idx == 0 ? x : idx == 1 ? y : idx == 2 ? z : FloatType.nan);
    else static assert(0, "invalid dimension count for vector");
  }

  void opIndexAssign (FloatType v, size_t idx) pure {
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
    FloatType toAngle() (in auto ref v2 v) { pragma(inline, true); import std.math : atan2; return atan2(y, x); }

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

  FloatType opIndex (size_t idx) const {
    pragma(inline, true);
    return (idx == 0 ? normal.x : idx == 1 ? normal.y : idx == 2 ? normal.z : idx == 3 ? w : FloatType.nan);
  }

  void opIndexAssign (FloatType v, size_t idx) {
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
/+TODO:
struct ray2 {
  vec2 org;
  vec2 dir;

nothrow @safe:
  string toString () const {
    import std.string : format;
    try {
      return "[(%s,%s):(%s,%s)]".format(org.x, org.y, dir.x, dir.y);
    } catch (Exception) {
      assert(0);
    }
  }

pure @nogc:
  this (FloatType x, FloatType y, FloatType angle) { pragma(inline, true); setOrgDir(x, y, angle); }
  this() (in auto ref vec2 aorg, FloatType angle) { pragma(inline, true); setOrgDir(aorg, angle); }

  void setOrgDir (FloatType x, FloatType y, FloatType angle) {
    pragma(inline, true);
    org.x = x;
    org.y = y;
    import std.math : cos, sin;
    dir.x = cos(angle);
    dir.y = sin(angle);
  }

  void setOrgDir() (in auto ref vec2 aorg, FloatType angle) {
    pragma(inline, true);
    org.x = aorg.x;
    org.y = aorg.y;
    import std.math : cos, sin;
    dir.x = cos(angle);
    dir.y = sin(angle);
  }

  void setOrg (FloatType x, FloatType y) {
    pragma(inline, true);
    org.x = x;
    org.y = y;
  }

  void setOrg() (in auto ref vec2 aorg) {
    pragma(inline, true);
    org.x = aorg.x;
    org.y = aorg.y;
  }

  void setDir (FloatType angle) {
    pragma(inline, true);
    import std.math : cos, sin;
    dir.x = cos(angle);
    dir.y = sin(angle);
  }

  @property vec2 right () const => vec2(dir.y, -dir.x);
}
+/


// ////////////////////////////////////////////////////////////////////////// //
/+TODO:
struct bbox(VT) if (isVector!VT) {
  // vertexes
  VT v0, v1; // min and max respective

pure nothrow @safe @nogc:
  ref VT opIndex (size_t idx) const {
    pragma(inline, true);
    return (idx == 0 ? v0 : v1);
  }

  void reset () {
    pragma(inline, true);
    v0.x = v0.y = double.infinity;
    v1.x = v1.y = -double.infinity;
    static if (isVector3!VT) v1.z = v1.z = -double.infinity;
  }

  void addPoint() (in auto ref VT v) if (isVector!VT) {
    static if (isVector2!VT) enum vclen = 2; else enum vclen = 3;
    import std.algorithm : min, max;
    foreach (immutable cidx; 0..vclen) {
      v0[cidx] = min(v0[cidx], v[cidx]);
      v1[cidx] = max(v1[cidx], v[cidx]);
    }
  }

  void addBBox() (in auto ref typeof(this) b) {
    addPoint(b.v0);
    addPoint(b.v1);
  }

  bool inside() (in auto ref VT p) const if (isVector!VT) {
    pragma(inline, true);
    static if (isVector2!VT) {
      return (p.x >= v0.x && p.y >= v0.y && p.x <= v1.x && p.y <= v1.y);
    } else {
      return (p.x >= v0.x && p.y >= v0.y && p.z >= v0.z && p.x <= v1.x && p.y <= v1.y && p.z <= v1.z);
    }
  }

  // extrude bbox a little, to compensate floating point inexactness
  void extrude (double delta=0.0000015) {
    v0.x -= delta;
    v0.y -= delta;
    static if (isVector3!VT) v0.z -= delta;
    v1.x += delta;
    v1.y += delta;
    static if (isVector3!VT) v0.z += delta;
  }
}
+/


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

  @property FloatType opIndex (size_t x, size_t y) @trusted @nogc { pragma(inline, true); return (x < 4 && y < 4 ? mt.ptr[y*4+x] : FloatType.nan); }

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
