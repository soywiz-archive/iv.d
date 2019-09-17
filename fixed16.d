/* Invisible Vector Library
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
// UNFINISHED! DO NOT USE!
module iv.fixed16;

// ////////////////////////////////////////////////////////////////////////// //
alias Fixnum = FixnumN!(int, 16);
enum Fixed(int v) = Fixnum(v);
enum Fixed(float v) = Fixnum(cast(double)v);
enum Fixed(double v) = Fixnum(v);


// ////////////////////////////////////////////////////////////////////////// //
struct FixnumN(T=int, ubyte scl=16) if ((is(T == byte) || is(T == int) || is(T == long)) && scl > 0 && scl < T.sizeof*8-1) {
private:
  alias Me = typeof(this);

public:
  enum mpl = cast(T)1<<scale;
  enum scale = scl;
  T value;
  static FixnumN make (T v) nothrow @safe @nogc { FixnumN fixed; fixed.value = v; return fixed; }

public:
  string toString () const { import std.format : format; return "%f".format(cast(double)value/mpl); }

public nothrow @safe @nogc:
  // min and max represent the smallest and larget possible values respectively
  enum min = make(-T.max);
  enum max = make(T.max);
  static if (is(T == int) && scl == 16) {
    enum One = make(1<<16);
    enum Half = make(1<<15);
    enum Nan = make(0x80000000);
    enum Inf = make(int.max);
    enum PI = make(0x3243f);
    enum PId2 = make(0x3243f>>1);
    enum PIx2 = make(0x3243f<<1);
    enum Sqrt2 = make(92682);
  }

  this (T v) { pragma(inline, true); value = v*mpl; }
  this (double v) { pragma(inline, true); import core.math : rndtol; value = cast(T)rndtol(v*mpl); }

  Me opUnary(string op:"++") () pure { pragma(inline, true); value += mpl; return this; }
  Me opUnary(string op:"--") () pure { pragma(inline, true); value -= mpl; return this; }

  Me opUnary(string op) () const pure { pragma(inline, true); mixin("return make("~op~"value);"); }

  bool opEquals (Me b) const pure { pragma(inline, true); return (value == b.value); }
  bool opEquals (T b) const pure { pragma(inline, true); return (value == b*mpl); }
  bool opEquals (double b) const pure { pragma(inline, true); return ((cast(double)value/mpl) == b); }

  int opCmp (const Me b) const pure { pragma(inline, true); return (value < b.value ? -1 : value > b.value ? 1 : 0); }
  int opCmp (const T b) const pure { pragma(inline, true); return (value < b*mpl ? -1 : value > b*mpl ? 1 : 0); }
  int opCmp (const double b) const pure { pragma(inline, true); return (value < b*mpl ? -1 : value > b*mpl ? 1 : 0); }

  void opAssign (Me v) pure { pragma(inline, true); value = v.value; }
  void opAssign (T v) pure { pragma(inline, true); value = v*mpl; }
  void opAssign (double v) pure { pragma(inline, true); value = cast(T)(v*mpl); }

  void opOpAssign (string op) (Me v) pure if (op == "+" || op == "-") { pragma(inline, true); mixin("value "~op~"= v.value;"); }
  void opOpAssign (string op) (Me v) pure if (op == "*" || op == "/") { pragma(inline, true); mixin("value = cast(T)(cast(long)value"~op~"cast(long)v.value/mpl);"); }

  void opOpAssign (string op) (T v) pure if (op == "+" || op == "-") { pragma(inline, true); mixin("value "~op~"= v*mpl;"); }
  void opOpAssign (string op) (T v) pure if (op == "*" || op == "/") { pragma(inline, true); mixin("value "~op~"= v;"); }

  void opOpAssign (string op) (double v) pure if (op == "+" || op == "-") { pragma(inline, true); import core.math : rndtol; mixin("value "~op~"= rndtol(v*mpl);"); }
  void opOpAssign (string op) (double v) pure if (op == "*" || op == "/") { pragma(inline, true); import core.math : rndtol; mixin("value "~op~"= rndtol(v);"); }

  T opCast(DT) () const pure if (is(DT == byte) || is(DT == ubyte) || is(DT == short) || is(DT == ushort) || is(DT == int) || is(DT == uint) || is(DT == long) || is(DT == ulong)) { pragma(inline, true); return cast(DT)(value/mpl); }
  T opCast(DT) () const pure if (is(DT == float) || is(DT == double)) { pragma(inline, true); return cast(DT)((cast(double)value)/mpl); }
  T opCast(DT) () const pure if (is(DT == bool)) { pragma(inline, true); return value != 0; }


  Me opBinary(string op) (Me b) const pure if (op == "+" || op == "-") { pragma(inline, true); mixin("return make(value"~op~"b.value);"); }
  Me opBinary(string op) (Me b) const pure if (op == "*" || op == "/") { pragma(inline, true); mixin("return make(cast(T)(cast(long)value"~op~"cast(long)b.value/mpl));"); }

  Me opBinary(string op) (T b) const pure if (op == "+" || op == "-" || op == "%") { pragma(inline, true); mixin("return make(value"~op~"(b*mpl));"); }
  Me opBinary(string op) (T b) const pure if (op == "*" || op == "/") { pragma(inline, true); mixin("return make(value"~op~"b);"); }

  Me opBinaryRight(string op) (T b) const pure if (op == "+" || op == "-" || op == "%") { pragma(inline, true); mixin("return make((b*mpl)"~op~"value);"); }
  Me opBinaryRight(string op) (T b) const pure if (op == "*") { pragma(inline, true); return make(cast(T)(b*value)); }
  Me opBinaryRight(string op) (T b) const pure if (op == "/") { pragma(inline, true); return make(cast(T)(cast(long)(b*mpl*mpl)/value)); }


  Me opBinary(string op) (double b) const pure if (op == "+" || op == "-" || op == "%") { pragma(inline, true); import core.math : rndtol; mixin("return make(value"~op~"cast(T)rndtol(b*mpl));"); }
  Me opBinary(string op) (double b) const pure if (op == "*" || op == "/") { pragma(inline, true); import core.math : rndtol; mixin("return make(value"~op~"cast(T)rndtol(b));"); }

  Me opBinaryRight(string op) (double b) const pure if (op == "+" || op == "-" || op == "%") { pragma(inline, true); import core.math : rndtol; mixin("return make(cast(T)rndtol(b*mpl)"~op~"value);"); }
  Me opBinaryRight(string op) (double b) const pure if (op == "*") { pragma(inline, true); import core.math : rndtol; return make(cast(T)(cast(T)rndtol(b)*value)); }
  Me opBinaryRight(string op) (double b) const pure if (op == "/") { pragma(inline, true); import core.math : rndtol; return make(cast(T)(rndtol(b*mpl*mpl)/value)); }

  @property Me abs () const pure { pragma(inline, true); return make(value >= 0 ? value : -value); }
  @property int sign () const pure { pragma(inline, true); return (value < 0 ? -1 : value > 0 ? 1 : 0); }
  @property isnan () const pure { pragma(inline, true); return (value == T.min); }

  static if (is(T == int) && scl == 16) {
    static Me cos (Me rads) { pragma(inline, true); Me res; calcSinCosF16(rads.value, null, &res.value); return res; }
    static Me sin (Me rads) { pragma(inline, true); Me res; calcSinCosF16(rads.value, &res.value, null); return res; }
    static void sincos (Me rads, ref Me s, ref Me c) { pragma(inline, true); calcSinCosF16(rads.value, &s.value, &c.value); }
    static Me atan2 (Me y, Me x) { pragma(inline, true); return make(calcAtan2F16(y.value, x.value)); }
    static Me atan (Me x) { pragma(inline, true); return make(calcAtanF16(x.value)); }
    static Me asin (Me x) { pragma(inline, true); return make(calcAsinF16(x.value)); }
  }

private static:
  // code taken from tbox
  void calcSinCosF16 (int x, int* s, int* c) @trusted {
    // |angle| < 90 degrees
    // x0,y0: fixed30
    static void cordicRotation (int* x0, int* y0, int z0) {
      int i = 0;
      int atan2i = 0;
      int z = z0;
      int x = *x0; // fixed30
      int y = *y0; // fixed30
      int xi = 0; // fixed30
      int yi = 0; // fixed30
      immutable(int)* patan2i = tb_fixed16_cordic_atan2i_table.ptr;
      do {
        xi = x>>i;
        yi = y>>i;
        atan2i = *patan2i++;
        if (z >= 0) {
          x -= yi;
          y += xi;
          z -= atan2i;
        } else {
          x += yi;
          y -= xi;
          z += atan2i;
        }
      } while (++i < 16);
      *x0 = x;
      *y0 = y;
    }

    // main

    // (x0, y0) = (k, 0), k = 0.607252935 => fixed30
    int cos = 0x26dd3b6a; // fixed30
    int sin = 0; // fixed30

    /* scale to 65536 degrees from x radians: x * 65536 / (2 * pi)
     *
     * 90:  0x40000000
     * 180: 0x80000000
     * 270: 0xc0000000
     */
    int ang = x*0x28be;

    /* quadrant
     *
     * 1: 00 ...
     * 2: 01 ...
     * 3: 10 ...
     * 4: 11 ...
     *
     * quadrant++
     *
     * 1: 01 ...
     * 2: 10 ...
     * 3: 11 ...
     * 4: 00 ...
     *
     */
    int quadrant = ang>>30;
    ++quadrant;

    /* quadrant == 2, 3, |angle| < 90
     *
     * 100 => -100 + 180 => 80
     * -200 => 200 + 180 => -20
     */
    if (quadrant&0x2) ang = -ang+0x80000000;

    // rotation
    cordicRotation(&cos, &sin, ang);

    // result
    if (s !is null) *s = sin>>14; // fixed30->fixed16
    if (c !is null) {
      // quadrant == 2, 3
      if (quadrant&0x2) cos = -cos;
      *c = cos>>14; // fixed30->fixed16
    }
  }

  // |angle| < 90 degrees
  int cordicVectorAtan2 (int y0, int x0) @trusted {
    int i = 0;
    int atan2i = 0;
    int z = 0;
    int x = x0;
    int y = y0;
    int xi = 0;
    int yi = 0;
    immutable(int)* patan2i = tb_fixed16_cordic_atan2i_table.ptr;
    do {
      xi = x>>i;
      yi = y>>i;
      atan2i = *patan2i++;
      if (y < 0) {
        x -= yi;
        y += xi;
        z -= atan2i;
      } else {
        x += yi;
        y -= xi;
        z += atan2i;
      }
    } while (++i < 16);
    return z / 0x28be;
  }

  // slope angle: [-180, 180]
  // the precision will be pool if x, y is too small
  int calcAtan2F16 (int y, int x) {
    if (!(x|y)) return 0;
    // abs
    int xs = tbGetSign(x);
    x = (x >= 0 ? x : -x); //tb_fixed30_abs(x);
    // quadrant: 1, 4
    int z = cordicVectorAtan2(y, x);
    // for quadrant: 2, 3
    if (xs) {
      int zs = tbGetSign(z);
      if (y == 0) zs = 0;
      int pi = tbSetSign(0x3243f/*TB_FIXED16_PI*/, zs);
      z = pi-z;
    }
    return z;
  }

  // |angle| < 90
  // the precision will be pool if x is too large.
  int calcAtanF16 (int x) {
    if (!x) return 0;
    return cordicVectorAtan2(x, 1<<16/*TB_FIXED16_ONE*/);
  }

  int calcAsinF16 (int x) {
    // |angle| < 90 degrees
    static int tb_fixed16_cordic_vector_asin (int m) @trusted {
      int i = 0;
      int atan2i = 0;
      int z = 0;
      int x = 0x18bde0bb; // k = 0.607252935
      int y = 0;
      int xi = 0;
      int yi = 0;
      immutable(int)* patan2i = tb_fixed16_cordic_atan2i_table.ptr;
      do {
        xi = x>>i;
        yi = y>>i;
        atan2i = *patan2i++;
        if (y < m) {
          x -= yi;
          y += xi;
          z -= atan2i;
        } else {
          x += yi;
          y -= xi;
          z += atan2i;
        }
      } while (++i < 16);
      return z / 0x28be;
    }

    // abs
    int s = tbGetSign(x);
    x = (x >= 0 ? x : -1); //tb_fixed16_abs(x);
    if (x >= 1<<16/*TB_FIXED16_ONE*/) return tbSetSign((0x3243f/*TB_FIXED16_PI*/) >> 1, s);
    int z = tb_fixed16_cordic_vector_asin(x * 0x28be);
    return tbSetSign(z, ~s);
  }

  // return -1 if x < 0, else return 0
  int tbGetSign (int x) pure nothrow @safe @nogc {
    pragma(inline, true);
    int s = (cast(int)(x) >> 31);
    //tb_assert((x < 0 && s == -1) || (x >= 0 && !s));
    return s;
  }

  // if s == -1, return -x, else s must be 0, and return x.
  int tbSetSign (int x, int s) pure nothrow @safe @nogc {
    pragma(inline, true);
    //tb_assert(s == 0 || s == -1);
    return (x ^ s) - s;
  }

  /+
  int invert (int x) {
    // is one?
    if (x == 1<<16/*TB_FIXED16_ONE*/) return 1<<16/*TB_FIXED16_ONE*/;
    // get sign
    int s = tbGetSign(x);
    // abs(x)
    x = (x >= 0 ? x : -x);
    // is infinity?
    if (x <= 2) return (s < 0 ? -T.max : T.max); //return tbSetSign(TB_FIXED16_MAX, s);

    // normalize
    int cl0 = cast(int)tb_bits_cl0_u32_be(x);
    x = x << cl0 >> 16;

    // compute 1 / x approximation (0.5 <= x < 1.0)
    // (2.90625 (~2.914) - 2 * x) >> 1
    uint r = 0x17400-x;

    // newton-raphson iteration:
    // x = r * (2 - x * r) = ((r / 2) * (1 - x * r / 2)) * 4
    r = ((0x10000 - ((x * r) >> 16)) * r) >> 15;
    r = ((0x10000 - ((x * r) >> 16)) * r) >> (30 - cl0);

    return tbSetSign(r, s);
  }
  +/

private:
  __gshared immutable int[30] tb_fixed16_cordic_atan2i_table = [
        0x20000000  // 45.000000
    ,   0x12e4051d  // 26.565051
    ,   0x9fb385b   // 14.036243
    ,   0x51111d4   // 7.125016
    ,   0x28b0d43   // 3.576334
    ,   0x145d7e1   // 1.789911
    ,   0xa2f61e    // 0.895174
    ,   0x517c55    // 0.447614
    ,   0x28be53    // 0.223811
    ,   0x145f2e    // 0.111906
    ,   0xa2f98     // 0.055953
    ,   0x517cc     // 0.027976
    ,   0x28be6     // 0.013988
    ,   0x145f3     // 0.006994
    ,   0xa2f9      // 0.003497
    ,   0x517c      // 0.001749
    ,   0x28be      // 0.000874
    ,   0x145f      // 0.000437
    ,   0xa2f       // 0.000219
    ,   0x517       // 0.000109
    ,   0x28b       // 0.000055
    ,   0x145       // 0.000027
    ,   0xa2        // 0.000014
    ,   0x51        // 0.000007
    ,   0x28        // 0.000003
    ,   0x14        // 0.000002
    ,   0xa         // 0.000001
    ,   0x5         // 0.000000
    ,   0x2         // 0.000000
    ,   0x1         // 0.000000
  ];
}


// ////////////////////////////////////////////////////////////////////////// //
/+
import iv.vfs.io;
import std.math;

void main () {
  writeln(Fixnum.PI);
  //auto n = Fixed!42;
  Fixnum n = 42;
  Fixnum n1 = 42.2;
  Fixnum nd1 = 0.1;
  writeln(n);
  writeln(n1);
  n += 0.1;
  writeln(n);
  n += nd1;
  writeln(n);

  writeln("sin=", Fixnum.sin(Fixnum(0.3)));
  writeln("dsin=", sin(0.3));
  writeln("cos=", Fixnum.cos(Fixnum(0.5)));
  writeln("dcos=", cos(0.5));
}
+/
