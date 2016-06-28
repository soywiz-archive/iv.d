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
module iv.vmath is aliced;


// ////////////////////////////////////////////////////////////////////////// //
private template isGoodSwizzling(string s, string comps, int minlen, int maxlen) {
  private static template hasChar(string str, char ch, usize idx=0) {
         static if (idx >= str.length) enum hasChar = false;
    else static if (str[idx] == ch) enum hasChar = true;
    else enum hasChar = hasChar!(str, ch, idx+1);
  }
  private static template swz(string str, string comps, uint idx=0) {
         static if (idx >= str.length) enum swz = true;
    else static if (hasChar!(str, comps)) enum swz = swz(str, comps, idx+1);
    else enum swz = false;
  }
  static if (s.length >= minlen && s.length <= maxlen) enum isGoodSwizzling = swz!(s, comps);
  else enum isGoodSwizzling = false;
}

private template SwizzleCtor(string stn, string s) {
  private static template buildCtor (string s, uint idx) {
    static if (idx >= s.length) enum buildCtor = "";
    else enum buildCtor = s[0]~","~buildCtor!(s, idx+1);
  }
  enum SwizzleCtor = stn~"("~buildCtor!(s)~")";
}


// ////////////////////////////////////////////////////////////////////////// //
enum FLTEPS = 1e-6f;
enum DBLEPS = 1e-18f;
template EPSILON(T) if (is(T == float) || is(T == double)) {
       static if (is(T == float)) enum EPSILON = FLTEPS;
  else static if (is(T == double)) enum EPSILON = DBLEPS;
  else static assert(0, "wtf?!");
}

auto deg2rad(T) (T v) pure nothrow @safe @nogc if (is(T == float) || is(T == double)) { pragma(inline, true); import std.math : PI; return v*PI/180.0; }
auto rad2deg(T) (T v) pure nothrow @safe @nogc if (is(T == float) || is(T == double)) { pragma(inline, true); import std.math : PI; return v*180.0/PI; }


// ////////////////////////////////////////////////////////////////////////// //
alias vec2 = VecN!2;
alias vec3 = VecN!3;


// ////////////////////////////////////////////////////////////////////////// //
struct VecN(ubyte dims, FloatType=float) if (dims >= 2 && dims <= 3 && (is(FloatType == float) || is(FloatType == double))) {
public:
  alias VFloat = FloatType;

  enum isVector(VT) = (is(VT == VecN!(2, FloatType)) || is(VT == VecN!(3, FloatType)));
  enum isVector2(VT) = is(VT == VecN!(2, FloatType));
  enum isVector3(VT) = is(VT == VecN!(3, FloatType));

  alias v2 = VecN!(2, FloatType);
  alias v3 = VecN!(3, FloatType);

  enum VFloatNum(real v) = cast(FloatType)v;

public:
  FloatType x = 0.0;
  FloatType y = 0.0;
  static if (dims >= 3) FloatType z = 0.0;

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
         static if (dims == 2) immutable FloatType invlength = 1.0/sqrt(x*x+y*y);
    else static if (dims == 3) immutable FloatType invlength = 1.0/sqrt(x*x+y*y+z*z);
    else static assert(0, "invalid dimension count for vector");
    x *= invlength;
    y *= invlength;
    static if (dims == 3) z *= invlength;
    return this;
  }

  ref auto safeNormalize () pure {
    //pragma(inline, true);
    import std.math : sqrt;
         static if (dims == 2) FloatType invlength = 1.0/sqrt(x*x+y*y);
    else static if (dims == 3) FloatType invlength = 1.0/sqrt(x*x+y*y+z*z);
    else static assert(0, "invalid dimension count for vector");
    if (invlength >= EPSILON!FloatType) {
      invlength = 1.0/invlength;
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
    import std.math : abs;
    //pragma(inline, true);
    a = (abs(a) >= EPSILON!FloatType ? 1.0/a : FloatType.nan);
    x *= a;
    y *= a;
    static if (dims == 3) z *= a;
    return this;
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

  auto safeNormalized () {
    pragma(inline, true);
    static if (dims == 2) return v2(x, y).safeNormalize; else return v3(x, y, z).safeNormalize;
  }

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

  auto opBinary(string op, VT) (in auto ref VT a) if (isVector!VT && (op == "+" || op == "-")) {
    pragma(inline, true);
         static if (dims == 2 && isVector2!VT) mixin("return v2(x"~op~"a.x, y"~op~"a.y);");
    else static if (dims == 2 && isVector3!VT) mixin("return v3(x"~op~"a.x, y"~op~"a.y, 0);");
    else static if (dims == 3 && isVector2!VT) mixin("return v3(x"~op~"a.x, y"~op~"a.y, 0);");
    else static if (dims == 3 && isVector3!VT) mixin("return v3(x"~op~"a.x, y"~op~"a.y, z"~op~"a.z);");
    else static assert(0, "invalid dimension count for vector");
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
         static if (dims == 2 && isVector2!VT) return v3(0, 0, x*a.y-y*a.x);
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
    import std.math : abs;
    immutable FloatType a = (abs(a) >= EPSILON!FloatType ? 1.0/a : FloatType.nan);
         static if (dims == 2) return v2(x*a, y*a);
    else static if (dims == 3) return v3(x*a, y*a, z*a);
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
}


// ////////////////////////////////////////////////////////////////////////// //
// plane in 3D space: Ax+By+Cz+D=0
struct Plane3(FloatType=float, FloatType PlaneEps=-1.0, bool enableSwizzling=true) if (is(FloatType == float) || is(FloatType == double)) {
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
  ref VT opIndex (usize idx) const {
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
struct Mat4(FloatType=float) if (is(FloatType == FloatType) || is(FloatType == double)) {
public:
  alias mat4 = Mat4!FloatType;
  alias vec3 = VecN!(3, FloatType);

public:
  FloatType[4*4] mt = 0; // OpenGL-compatible, row by row

nothrow @safe:
  string toString () const @trusted {
    import std.string : format;
    try {
      return "[%s,%s,%s,%s]\n[%s,%s,%s,%s]\n[%s,%s,%s,%s]\n[%s,%s,%s,%s]".format(
        mt.ptr[ 0], mt.ptr[ 1], mt.ptr[ 2], mt.ptr[ 3],
        mt.ptr[ 4], mt.ptr[ 5], mt.ptr[ 6], mt.ptr[ 7],
        mt.ptr[ 8], mt.ptr[ 9], mt.ptr[10], mt.ptr[11],
        mt.ptr[12], mt.ptr[13], mt.ptr[14], mt.ptr[15],
      );
    } catch (Exception) {
      assert(0);
    }
  }

  @property ref FloatType opIndex (usize r, usize c) @trusted @nogc { pragma(inline, true); return (r < 4 && c < 4 ? mt.ptr[c*4+r] : mt.ptr[0]); }

pure @nogc:
  this() (in auto ref mat4 m) { mt[] = m.mt[]; }
  this() (in auto ref vec3 v) {
    mt[] = 0;
    mt.ptr[0*4+0] = v.x;
    mt.ptr[1*4+1] = v.y;
    mt.ptr[2*4+2] = v.z;
    mt.ptr[3*4+3] = 1; // just in case
  }

  static mat4 zero () { pragma(inline, true); return mat4(); }
  static mat4 identity () @trusted { pragma(inline, true); mat4 res; res.mt.ptr[0*4+0] = res.mt.ptr[1*4+1] = res.mt.ptr[2*4+2] = res.mt.ptr[3*4+3] = 1; return res; }

  static mat4 rotateX (FloatType angle) @trusted {
    import std.math : cos, sin;
    mat4 res;
    res.mt.ptr[0*4+0] = 1.0;
    res.mt.ptr[1*4+1] = cos(angle);
    res.mt.ptr[2*4+1] = -sin(angle);
    res.mt.ptr[1*4+2] = sin(angle);
    res.mt.ptr[2*4+2] = cos(angle);
    res.mt.ptr[3*4+3] = 1.0;
    return res;
  }

  static mat4 rotateY (FloatType angle) @trusted {
    import std.math : cos, sin;
    mat4 res;
    res.mt.ptr[0*4+0] = cos(angle);
    res.mt.ptr[2*4+0] = sin(angle);
    res.mt.ptr[1*4+1] = 1.0;
    res.mt.ptr[0*4+2] = -sin(angle);
    res.mt.ptr[2*4+2] = cos(angle);
    res.mt.ptr[3*4+3] = 1.0;
    return res;
  }

  static mat4 rotateZ (FloatType angle) @trusted {
    import std.math : cos, sin;
    mat4 res;
    res.mt.ptr[0*4+0] = cos(angle);
    res.mt.ptr[1*4+0] = -sin(angle);
    res.mt.ptr[0*4+1] = sin(angle);
    res.mt.ptr[1*4+1] = cos(angle);
    res.mt.ptr[2*4+2] = 1.0;
    res.mt.ptr[3*4+3] = 1.0;
    return res;
  }

  static mat4 translate() (in auto ref vec3 v) @trusted {
    mat4 res;
    res.mt.ptr[0*4+0] = res.mt.ptr[1*4+1] = res.mt.ptr[2*4+2] = 1;
    res.mt.ptr[3*4+0] = v.x;
    res.mt.ptr[3*4+1] = v.y;
    res.mt.ptr[3*4+2] = v.z;
    res.mt.ptr[3*4+3] = 1;
    return res;
  }

  static mat4 scale() (in auto ref vec3 v) @trusted {
    mat4 res;
    res.mt.ptr[0*4+0] = v.x;
    res.mt.ptr[1*4+1] = v.y;
    res.mt.ptr[2*4+2] = v.z;
    res.mt.ptr[3*4+3] = 1;
    return res;
  }

  static mat4 rotate() (in auto ref vec3 v) {
    auto mx = mat4.rotateX(v.x);
    auto my = mat4.rotateY(v.y);
    auto mz = mat4.rotateZ(v.z);
    return mz*my*mx;
  }

  static mat4 camera() (in auto ref vec3 eye, in auto ref vec3 point, in auto ref vec3 up) {
    mat4 res;
    vec3 f, u, s;
    f = point-eye;
    f.normalize;
    u = up;
    u.normalize;
    s = f.cross(u);
    u = s.cross(f);
    res.mt.ptr[0*4+0] = s.x;
    res.mt.ptr[1*4+0] = s.y;
    res.mt.ptr[2*4+0] = s.z;
    res.mt.ptr[3*4+0] = 0.0;
    res.mt.ptr[0*4+1] = u.x;
    res.mt.ptr[1*4+1] = u.y;
    res.mt.ptr[2*4+1] = u.z;
    res.mt.ptr[3*4+1] = 0.0;
    res.mt.ptr[0*4+2] = -f.x;
    res.mt.ptr[1*4+2] = -f.y;
    res.mt.ptr[2*4+2] = -f.z;
    res.mt.ptr[3*4+2] = 0.0;
    res.mt.ptr[0*4+3] = 0.0;
    res.mt.ptr[1*4+3] = 0.0;
    res.mt.ptr[2*4+3] = 0.0;
    res.mt.ptr[3*4+3] = 1.0;
    return res;
  }

@trusted:
  vec3 opBinary(string op : "*") (in auto ref vec3 v) const {
    pragma(inline, true);
    return vec3(
      mt.ptr[0*4+0]*v.x+mt.ptr[1*4+0]*v.y+mt.ptr[2*4+0]*v.z+mt.ptr[3*4+0],
      mt.ptr[0*4+1]*v.x+mt.ptr[1*4+1]*v.y+mt.ptr[2*4+1]*v.z+mt.ptr[3*4+1],
      mt.ptr[0*4+2]*v.x+mt.ptr[1*4+2]*v.y+mt.ptr[2*4+2]*v.z+mt.ptr[3*4+2]);
  }


  vec3 opBinaryRight(string op : "*") (in auto ref vec3 v) const {
    pragma(inline, true);
    return vec3(
      mt.ptr[0*4+0]*v.x+mt.ptr[0*4+1]*v.y+mt.ptr[0*4+2]*v.z+mt.ptr[0*4+3],
      mt.ptr[1*4+0]*v.x+mt.ptr[1*4+1]*v.y+mt.ptr[1*4+2]*v.z+mt.ptr[1*4+3],
      mt.ptr[2*4+0]*v.x+mt.ptr[2*4+1]*v.y+mt.ptr[2*4+2]*v.z+mt.ptr[2*4+3]);
  }


  mat4 opBinary(string op : "*") (in auto ref mat4 m) const {
    mat4 res;
    foreach (immutable i; 0..4) {
      foreach (immutable j; 0..4) {
        foreach (immutable k; 0..4) {
          res.mt.ptr[i+j*4] += mt.ptr[i+k*4]*m.mt.ptr[k+j*4];
        }
      }
    }
    return res;
  }

  mat4 opBinary(string op : "+") (in auto ref mat4 m) const {
    auto res = mat4(this);
    res.mt[] += m.mt[];
    return res;
  }

  mat4 opBinary(string op : "*") (FloatType a) const {
    auto res = mat4(this);
    //foreach (ref v; res.mt) v *= a;
    res.mt[] *= a;
    return res;
  }

  mat4 opBinary(string op : "/") (FloatType a) const {
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

  ref vec2 opOpAssign(string op : "*") (in auto ref mat4 m) {
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
    mat4 res;
    foreach (immutable i; 0..4) {
      foreach (immutable j; 0..4) {
        res.mt.ptr[i+j*4] = mt.ptr[j+i*4];
      }
    }
    return res;
  }

  // returns determinant of matrix without given column and row
  FloatType cofactor (int x, int y) const {
    int[3] xx, yy;
    foreach (int i; 0..3) {
      if (i < x) xx.ptr[i] = i; else xx.ptr[i] = i+1;
      if (i < y) yy.ptr[i] = i; else yy.ptr[i] = i+1;
    }
    FloatType det = 0;
    foreach (int i; 0..3) {
      FloatType plus = 1, minus = 1;
      foreach (int j; 0..3) {
        plus = plus*mt.ptr[xx.ptr[j]+(yy.ptr[(i+j)%3])*4];
        minus = minus*mt.ptr[xx.ptr[2-j]+(yy.ptr[(i+j)%3])*4];
      }
      det = det+plus-minus;
    }
    return det;
  }

  FloatType determinant () const {
    FloatType det = 0;
    foreach (int i; 0..4) {
      foreach (int j; 0..4) {
        det += mt.ptr[i+j*4]*cofactor(i, j);
      }
    }
    return det;
  }

  mat4 adjoint () const {
    mat4 res;
    foreach (int i; 0..4) {
      foreach (int j; 0..4) {
        res.mt.ptr[i+j*4] = cofactor(i, j);
      }
    }
    return res.transpose();
  }

  mat4 invert () const {
    import std.math : abs;
    FloatType det = determinant;
    if (abs(det) >= FLTEPS) {
      return adjoint/det;
    } else {
      return mat4();
    }
  }

  void negate () {
    foreach (ref v; mt) v = -v;
  }

  mat4 opUnary(string op : "-") () const {
    mat4 res = void;
    res.mt[] = mt[];
    foreach (ref v; res.mt) v = -v;
    return res;
  }

/+
  ////////////////////////////////////////////////////////////////////////////////
  void mat4::addColumns (int c1, int c2, FloatType *a) const {
    a[0] = mt.ptr[c1][0]+mt.ptr[c2][0];
    a[1] = mt.ptr[c1][1]+mt.ptr[c2][1];
    a[2] = mt.ptr[c1][2]+mt.ptr[c2][2];
    a[3] = mt.ptr[c1][3]+mt.ptr[c2][3];
  }


  void mat4::subColumns (int c1, int c2, FloatType *a) const {
    a[0] = mt.ptr[c1][0]-mt.ptr[c2][0];
    a[1] = mt.ptr[c1][1]-mt.ptr[c2][1];
    a[2] = mt.ptr[c1][2]-mt.ptr[c2][2];
    a[3] = mt.ptr[c1][3]-mt.ptr[c2][3];
  }


  ////////////////////////////////////////////////////////////////////////////////
  // *** GL STUFF ***

  //  m1 m5 (...)
  //  m2
  //  m3
  //  m4

  void mat4::glGetProjectionMatrix () {
    FloatType a[16];
    //
    glGetDoublev(GL_PROJECTION_MATRIX, a);
    for (int i = 0; i < 4; ++i)
      for (int j = 0; j < 4; ++j)
        mt.ptr[i][j] = a[j*4+i];
  }


  void mat4::glGetModelviewMatrix () {
    FloatType a[16];
    //
    glGetDoublev(GL_MODELVIEW_MATRIX, a);
    for (int i = 0; i < 4; ++i)
      for (int j = 0; j < 4; ++j)
        mt.ptr[i][j] = a[j*4+i];
  }


  void mat4::glLoadMatrix () const {
    FloatType a[16];
    //
    for (int i = 0; i < 4; ++i)
      for (int j = 0; j < 4; ++j)
        a[j*4+i] = mt.ptr[i][j];
    glLoadMatrixd(a);
  }


  void mat4::glMultMatrix () const {
    FloatType a[16];
    //
    for (int i = 0; i < 4; ++i)
      for (int j = 0; j < 4; ++j)
        a[j*4+i] = mt.ptr[i][j];
    glMultMatrixd(a);
  }
+/
}
