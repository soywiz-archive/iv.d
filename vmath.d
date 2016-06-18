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
enum FLTEPS = 0.000001f;

float deg2rad() (float v) pure nothrow @safe @nogc { pragma(inline, true); import std.math : PI; return v*PI/180.0f; }
float rad2deg() (float v) pure nothrow @safe @nogc { pragma(inline, true); import std.math : PI; return v*180.0f/PI; }


// ////////////////////////////////////////////////////////////////////////// //
struct vec2 {
  float x = 0.0f, y = 0.0f;

nothrow @safe:
  string toString () const {
    import std.string : format;
    try {
      return "(%s,%s)".format(x, y);
    } catch (Exception) {
      assert(0);
    }
  }

@nogc:
  this (float nx, float ny) pure { /*pragma(inline, true);*/ x = nx; y = ny; }

  static vec2 fromAngle (float a) pure {
    pragma(inline, true);
    import std.math : cos, sin;
    return vec2(cos(a), sin(a));
  }

  float opIndex (usize idx) const pure {
    pragma(inline, true);
    return (idx == 0 ? x : idx == 1 ? y : float.nan);
  }

  void opIndexAssign (float v, usize idx) pure {
    pragma(inline, true);
    if (idx == 0) x = v; else if (idx == 1) y = v;
  }

  ref vec2 normalize () pure {
    //pragma(inline, true);
    import std.math : sqrt;
    immutable float invlength = 1.0f/sqrt(x*x+y*y);
    x *= invlength;
    y *= invlength;
    return this;
  }

  ref vec2 safeNormalize () pure {
    //pragma(inline, true);
    import std.math : sqrt;
    float invlength = sqrt(x*x+y*y);
    if (invlength >= FLTEPS) {
      invlength = 1.0f/invlength;
      x *= invlength;
      y *= invlength;
    } else {
      x = 1;
      y = 0;
    }
    return this;
  }

  ref vec2 opOpAssign(string op) (in auto ref vec2 a) if (op == "+" || op == "-" || op == "*") {
    //pragma(inline, true);
    mixin("x "~op~"= a.x;");
    mixin("y "~op~"= a.y;");
    return this;
  }

  ref vec2 opOpAssign(string op) (float a) if (op == "+" || op == "-" || op == "*") {
    //pragma(inline, true);
    mixin("x "~op~"= a;");
    mixin("y "~op~"= a;");
    return this;
  }

  ref vec2 opOpAssign(string op : "/") (float a) {
    //pragma(inline, true);
    import std.math : abs;
    a = (abs(a) >= FLTEPS ? 1.0f/a : float.nan);
    x *= a;
    y *= a;
    return this;
  }

const pure:
  vec2 normalized () { pragma(inline, true); return vec2(x, y).normalize; }
  vec2 safeNormalized () { pragma(inline, true); return vec2(x, y).safeNormalize; }

  @property float length () {
    pragma(inline, true);
    import std.math : sqrt;
    return sqrt(x*x+y*y);
  }

  @property float lengthSquared () { pragma(inline, true); return x*x+y*y; }

  @property vec2 tangent () { pragma(inline, true); return vec2(-y, x); }

  // normalized ;-)
  @property vec2 normal() (in auto ref vec2 v1) {
    pragma(inline, true);
    import std.math : sqrt;
    immutable float dx = v1.x-x, dy = v1.y-dy;
    float len = sqrt(dx*dx+dy*dy);
    if (len >= FLTEPS) {
      len = 1.0f/len;
      return vec2(-dy*len, dx*len);
    } else {
      return vec2(0, 0);
    }
  }

  // distance
  float distance() (in auto ref vec2 a) {
    pragma(inline, true);
    import std.math : sqrt;
    return sqrt((x-a.x)*(x-a.x)+(y-a.y)*(y-a.y));
  }

  @property float angle () {
    pragma(inline, true);
    import std.math : atan2;
    return atan2(y, x);
  }

  @property float angleTo() (in auto ref vec2 v1) {
    pragma(inline, true);
    import std.math : atan2, PI;
    immutable a = atan2(v1.y, v1.x)-atan2(y, x);
    return (a > PI ? a-2*PI : (a < -PI ? a+2*PI : a));
  }

  vec2 opBinary(string op) (in auto ref vec2 a) if (op == "+" || op == "-") {
    pragma(inline, true);
    mixin("return vec2(x"~op~"a.x, y"~op~"a.y);");
  }

  // dot product
  float opBinary(string op : "*") (in auto ref vec2 a) { pragma(inline, true); return x*a.x+y*a.y; }

  vec2 opBinary(string op) (float a) if (op == "+" || op == "-" || op == "*") { pragma(inline, true); mixin("return vec2(x"~op~"a, y"~op~"a);"); }
  vec2 opBinary(string op : "/") (float a) { pragma(inline, true); import std.math : abs; a = (abs(a) >= FLTEPS ? 1.0f/a : float.nan); return vec2(x*a, y*a); }

  vec2 opUnary(string op : "-") () { pragma(inline, true); return vec2(-x, -y); }

  vec2 abs () { pragma(inline, true); return vec2((x < 0 ? -x : x), (y < 0 ? -y : y)); }

  bool opEquals() (in auto ref vec2 a) { pragma(inline, true); return (x == a.x && y == a.y); }

  // 2d stuff
  // test if a point (`this`) is left/on/right of an infinite 2d line
  // return:
  //   <0: on the right
  //   =0: on the line
  //   >0: on the left
  float side() (in auto ref vec2 v0, in auto ref vec2 v1) const {
    pragma(inline, true);
    return ((v1.x-v0.x)*(this.y-v0.y)-(this.x-v0.x)*(v1.y-v0.y));
  }

  @property float dot() (in auto ref vec2 v) const { pragma(inline, true); return x*v.x+y*v.y; }

  // swizzling
  auto opDispatch(string fld) () if (isGoodSwizzling!(fld, "xy", 2, 3)) {
    static if (fld.length == 2) {
      return mixin(SwizzleCtor!("vec2", fld));
    } else {
      return mixin(SwizzleCtor!("vec3", fld));
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
struct vec3 {
  float x = 0.0f, y = 0.0f, z = 0.0f;

nothrow @safe:
  string toString () const {
    import std.string : format;
    try {
      return "(%s,%s,%s)".format(x, y, z);
    } catch (Exception) {
      assert(0);
    }
  }

@nogc:
  this (float nx, float ny, float nz=0.0f) pure {
    pragma(inline, true);
    x = nx;
    y = ny;
    z = nz;
  }

  this() (in auto ref vec2 v) pure {
    pragma(inline, true);
    x = v.x;
    y = v.y;
    z = 0.0f;
  }

  float opIndex (usize idx) const pure {
    pragma(inline, true);
    return (idx == 0 ? x : idx == 1 ? y : idx == 2 ? z : float.nan);
  }

  void opIndexAssign (float v, usize idx) pure {
    pragma(inline, true);
    if (idx == 0) x = v; else if (idx == 1) y = v; else if (idx == 2) z = v;
  }

  ref vec3 normalize () pure {
    pragma(inline, true);
    import std.math : sqrt;
    immutable float invlength = 1.0f/sqrt(x*x+y*y+z*z);
    x *= invlength;
    y *= invlength;
    z *= invlength;
    return this;
  }

  ref vec3 safeNormalize () pure {
    pragma(inline, true);
    import std.math : sqrt;
    float invlength = sqrt(x*x+y*y+z*z);
    if (invlength >= FLTEPS) {
      invlength = 1.0f/invlength;
      x *= invlength;
      y *= invlength;
      z *= invlength;
    } else {
      x = 1;
      y = 0;
      z = 0;
    }
    return this;
  }

  ref vec3 opOpAssign(string op) (in auto ref vec3 a) if (op == "+" || op == "-" || op == "*") {
    pragma(inline, true);
    mixin("x "~op~"= a.x;");
    mixin("y "~op~"= a.y;");
    mixin("z "~op~"= a.z;");
    return this;
  }

  ref vec3 opOpAssign(string op) (float a) if (op == "+" || op == "-" || op == "*") {
    pragma(inline, true);
    mixin("x "~op~"= a;");
    mixin("y "~op~"= a;");
    mixin("z "~op~"= a;");
    return this;
  }

  ref vec3 opOpAssign(string op : "/") (float a) {
    import std.math : abs;
    pragma(inline, true);
    a = (abs(a) >= FLTEPS ? 1.0f/a : float.nan);
    x *= a;
    y *= a;
    z *= a;
    return this;
  }

const pure:
  vec3 normalized () { pragma(inline, true); return vec3(x, y, z).normalize; }
  vec3 safeNormalized () { pragma(inline, true); return vec3(x, y, z).safeNormalize; }

  @property float length () {
    pragma(inline, true);
    import std.math : sqrt;
    return sqrt(x*x+y*y+z*z);
  }

  @property float lengthSquared () { pragma(inline, true); return x*x+y*y+z*z; }

  // distance
  float distance() (in auto ref vec3 a) {
    pragma(inline, true);
    import std.math : sqrt;
    return sqrt((x-a.x)*(x-a.x)+(y-a.y)*(y-a.y)+(z-a.z)*(z-a.z));
  }

  vec3 opBinary(string op) (in auto ref vec3 a) if (op == "+" || op == "-") {
    pragma(inline, true);
    mixin("return vec3(x"~op~"a.x, y"~op~"a.y, z"~op~"a.z);");
  }

  // dot product
  float opBinary(string op : "*") (in auto ref vec3 a) { pragma(inline, true); return x*a.x+y*a.y+z*a.z; }

  // cross product
  vec3 opBinary(string op : "%") (in auto ref vec3 a) { pragma(inline, true); return vec3(y*a.z-z*a.y, z*a.x-x*a.z, x*a.y-y*a.x); }

  vec3 opBinary(string op) (float a) if (op == "+" || op == "-" || op == "*") { pragma(inline, true); mixin("return vec2(x"~op~"a, y"~op~"a, z"~op~"a);"); }
  vec3 opBinary(string op : "/") (float a) { pragma(inline, true); import std.math : abs; a = (abs(a) >= FLTEPS ? 1.0f/a : float.nan); return vec3(x*a, y*a, z*a); }

  vec3 opUnary(string op : "-") () { pragma(inline, true); return vec3(-x, -y, -z); }

  vec3 abs () { pragma(inline, true); return vec3((x < 0 ? -x : x), (y < 0 ? -y : y), (z < 0 ? -z : z)); }

  bool opEquals() (in auto ref vec3 a) { pragma(inline, true); return (x == a.x && y == a.y && z == a.z); }

  // this dot v
  @property float dot() (in auto ref vec2 v) const { pragma(inline, true); return x*v.x+y*v.y+z*v.z; }

  // this cross v
  vec3 cross() (in auto ref vec2 v) const {
    pragma(inline, true);
    return vec3(
      (y*v.z)-(z*v.y),
      (z*v.x)-(x*v.z),
      (x*v.y)-(y*v.x)
    );
  }

  // compute Euler angles from direction vector (this) (with zero roll)
  vec3 hpr () {
    import std.math : atan2, sqrt;
    auto tmp = this.normalized;
    /*hpr.x = -atan2(tmp.x, tmp.y);
      hpr.y = -atan2(tmp.z, sqrt(tmp.x*tmp.x+tmp.y*tmp.y));*/
    return vec3(
      atan2(tmp.x, tmp.z),
      -atan2(tmp.y, sqrt(tmp.x*tmp.x+tmp.z*tmp.z)),
      0
    );
  }

  // swizzling
  auto opDispatch(string fld) () if (isGoodSwizzling!(fld, "xyz", 2, 3)) {
    static if (fld.length == 2) {
      return mixin(SwizzleCtor!("vec2", fld));
    } else {
      return mixin(SwizzleCtor!("vec3", fld));
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
// plane in 3D space: Ax+By+Cz+D=0
struct plane3 {
  float a = 0, b = 0, c = 0, d = 0;

nothrow @safe:
  string toString () const {
    import std.string : format;
    try {
      return "(%s,%s,%s,%s)".format(a, b, c, d);
    } catch (Exception) {
      assert(0);
    }
  }

@nogc:
  this() (in auto ref plane3 p) pure { a = p.a; b = p.b; c = p.c; d = p.d; }

  float opIndex (usize idx) const pure {
    pragma(inline, true);
    return (idx == 0 ? a : idx == 1 ? b : idx == 2 ? c : idx == 3 ? d : float.nan);
  }

  void opIndexAssign (float v, usize idx) pure {
    pragma(inline, true);
    if (idx == 0) a = v; else if (idx == 1) b = v; else if (idx == 2) c = v; else if (idx == 3) d = v;
  }

  ref plane3 normalized () pure {
    import std.math : sqrt;
    float dd = sqrt(a*a+b*b+c*c);
    if (dd >= FLTEPS) {
      dd = 1.0f/dd;
      a *= dd;
      b *= dd;
      c *= dd;
      d *= dd;
    } else {
      a = b = c = d = 0;
    }
    return this;
  }

  bool pointSide() (in auto ref vec3 p) const pure { return (a*p.x+b*p.y+c*p.z+d >= 0); }
  //float distance() (in auto ref vec3 p) const pure { return a*p.x+b*p.y+c*p.z+d; }

  // swizzling
  auto opDispatch(string fld) () if (isGoodSwizzling!(fld, "abcd", 2, 3)) {
    static if (fld.length == 2) {
      return mixin(SwizzleCtor!("vec2", fld));
    } else {
      return mixin(SwizzleCtor!("vec3", fld));
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
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
  this (float x, float y, float angle) { pragma(inline, true); setOrgDir(x, y, angle); }
  this() (in auto ref vec2 aorg, float angle) { pragma(inline, true); setOrgDir(aorg, angle); }

  void setOrgDir (float x, float y, float angle) {
    pragma(inline, true);
    org.x = x;
    org.y = y;
    import std.math : cos, sin;
    dir.x = cos(angle);
    dir.y = sin(angle);
  }

  void setOrgDir() (in auto ref vec2 aorg, float angle) {
    pragma(inline, true);
    org.x = aorg.x;
    org.y = aorg.y;
    import std.math : cos, sin;
    dir.x = cos(angle);
    dir.y = sin(angle);
  }

  void setOrg (float x, float y) {
    pragma(inline, true);
    org.x = x;
    org.y = y;
  }

  void setOrg() (in auto ref vec2 aorg) {
    pragma(inline, true);
    org.x = aorg.x;
    org.y = aorg.y;
  }

  void setDir (float angle) {
    pragma(inline, true);
    import std.math : cos, sin;
    dir.x = cos(angle);
    dir.y = sin(angle);
  }

  @property vec2 right () const => vec2(dir.y, -dir.x);
}


// ////////////////////////////////////////////////////////////////////////// //
struct bbox(VT) if (is(VT == vec2) || is(VT == vec3)) {
  // vertexes
  VT v0, v1; // min and max respective

pure nothrow @safe @nogc:
  ref VT opIndex (usize idx) const {
    pragma(inline, true);
    return (idx == 0 ? v0 : v1);
  }

  void reset () {
    pragma(inline, true);
    v0.x = v0.y = float.infinity;
    v1.x = v1.y = -float.infinity;
  }

  void addPoint() (in auto ref VT v) {
    static if (is(VT == vec2)) enum vclen = 2; else enum vclen = 3;
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

  bool inside() (in auto ref VT p) const {
    pragma(inline, true);
    static if (is(VT == vec2)) {
      return (p.x >= v0.x && p.y >= v0.y && p.x <= v1.x && p.y <= v1.y);
    } else {
      return (p.x >= v0.x && p.y >= v0.y && p.z >= v0.z && p.x <= v1.x && p.y <= v1.y && p.z <= v1.z);
    }
  }

  // extrude bbox a little, to compensate floating point inexactness
  void extrude (float delta=0.0000015f) {
    v0.x -= delta;
    v0.y -= delta;
    static if (is(VT == vec3)) v0.z -= delta;
    v1.x += delta;
    v1.y += delta;
    static if (is(VT == vec3)) v0.z += delta;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
struct mat4 {
  float[4*4] mt = 0; // OpenGL-compatible, row by row

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

  @property ref float opIndex (usize r, usize c) @trusted @nogc { pragma(inline, true); return (r < 4 && c < 4 ? mt.ptr[c*4+r] : mt.ptr[0]); }

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

  static mat4 rotateX (float angle) @trusted {
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

  static mat4 rotateY (float angle) @trusted {
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

  static mat4 rotateZ (float angle) @trusted {
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

  mat4 opBinary(string op : "*") (float a) const {
    auto res = mat4(this);
    //foreach (ref v; res.mt) v *= a;
    res.mt[] *= a;
    return res;
  }

  mat4 opBinary(string op : "/") (float a) const {
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
  float cofactor (int x, int y) const {
    int[3] xx, yy;
    foreach (int i; 0..3) {
      if (i < x) xx.ptr[i] = i; else xx.ptr[i] = i+1;
      if (i < y) yy.ptr[i] = i; else yy.ptr[i] = i+1;
    }
    float det = 0;
    foreach (int i; 0..3) {
      float plus = 1, minus = 1;
      foreach (int j; 0..3) {
        plus = plus*mt.ptr[xx.ptr[j]+(yy.ptr[(i+j)%3])*4];
        minus = minus*mt.ptr[xx.ptr[2-j]+(yy.ptr[(i+j)%3])*4];
      }
      det = det+plus-minus;
    }
    return det;
  }

  float determinant () const {
    float det = 0;
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
    float det = determinant;
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
  void mat4::addColumns (int c1, int c2, float *a) const {
    a[0] = mt.ptr[c1][0]+mt.ptr[c2][0];
    a[1] = mt.ptr[c1][1]+mt.ptr[c2][1];
    a[2] = mt.ptr[c1][2]+mt.ptr[c2][2];
    a[3] = mt.ptr[c1][3]+mt.ptr[c2][3];
  }


  void mat4::subColumns (int c1, int c2, float *a) const {
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
    float a[16];
    //
    glGetDoublev(GL_PROJECTION_MATRIX, a);
    for (int i = 0; i < 4; ++i)
      for (int j = 0; j < 4; ++j)
        mt.ptr[i][j] = a[j*4+i];
  }


  void mat4::glGetModelviewMatrix () {
    float a[16];
    //
    glGetDoublev(GL_MODELVIEW_MATRIX, a);
    for (int i = 0; i < 4; ++i)
      for (int j = 0; j < 4; ++j)
        mt.ptr[i][j] = a[j*4+i];
  }


  void mat4::glLoadMatrix () const {
    float a[16];
    //
    for (int i = 0; i < 4; ++i)
      for (int j = 0; j < 4; ++j)
        a[j*4+i] = mt.ptr[i][j];
    glLoadMatrixd(a);
  }


  void mat4::glMultMatrix () const {
    float a[16];
    //
    for (int i = 0; i < 4; ++i)
      for (int j = 0; j < 4; ++j)
        a[j*4+i] = mt.ptr[i][j];
    glMultMatrixd(a);
  }
+/
}
