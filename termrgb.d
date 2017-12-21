/* Invisible Vector Library
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
// 256-color terminal utilities
module iv.termrgb /*is aliced*/;
private:

//version = termrgb_weighted_colors;
//version = termrgb_disable_256_colors;
//version = termrgb_gamma_correct;


// ////////////////////////////////////////////////////////////////////////// //
/// Terminal type (yeah, i know alot of 'em)
public enum TermType {
  other,
  rxvt,
  xterm,
  linux, // linux console
}


public __gshared TermType termType = TermType.other; ///
__gshared bool isTermRedirected = true; ///


/// is TTY stdin or stdout redirected? note that stderr *can* be redirected.
public @property bool ttyIsRedirected () nothrow @trusted @nogc { pragma(inline, true); return isTermRedirected; }


shared static this () nothrow @trusted @nogc {
  {
    import core.stdc.stdlib : getenv;
    import core.stdc.string : strcmp;
    auto tt = getenv("TERM");
    if (tt !is null) {
      auto len = 0;
      while (len < 5 && tt[len]) ++len;
           if (len >= 4 && tt[0..4] == "rxvt") termType = TermType.rxvt;
      else if (len >= 5 && tt[0..5] == "xterm") termType = TermType.xterm;
      else if (len >= 5 && tt[0..5] == "linux") termType = TermType.linux;
    }
  }
  {
    import core.sys.posix.unistd : isatty, STDIN_FILENO, STDOUT_FILENO;
    import core.sys.posix.termios : tcgetattr;
    import core.sys.posix.termios : termios;
    if (isatty(STDIN_FILENO) && isatty(STDOUT_FILENO)) {
      termios origMode = void;
      if (tcgetattr(STDIN_FILENO, &origMode) == 0) isTermRedirected = false;
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
/// k8sterm color table, lol
static immutable uint[256] ttyRGBTable = {
  uint[256] res;
  // standard terminal colors
  res[0] = 0x000000;
  res[1] = 0xb21818;
  res[2] = 0x18b218;
  res[3] = 0xb26818;
  res[4] = 0x1818b2;
  res[5] = 0xb218b2;
  res[6] = 0x18b2b2;
  res[7] = 0xb2b2b2;
  res[8] = 0x686868;
  res[9] = 0xff5454;
  res[10] = 0x54ff54;
  res[11] = 0xffff54;
  res[12] = 0x5454ff;
  res[13] = 0xff54ff;
  res[14] = 0x54ffff;
  res[15] = 0xffffff;
  // rgb colors [16..231]
  int f = 16;
  foreach (ubyte r; 0..6) {
    foreach (ubyte g; 0..6) {
      foreach (ubyte b; 0..6) {
        uint cr = (r == 0 ? 0 : 0x37+0x28*r); assert(cr <= 255);
        uint cg = (g == 0 ? 0 : 0x37+0x28*g); assert(cg <= 255);
        uint cb = (b == 0 ? 0 : 0x37+0x28*b); assert(cb <= 255);
        res[f++] = (cr<<16)|(cg<<8)|cb;
      }
    }
  }
  assert(f == 232);
  // b/w shades [232..255]
  foreach (ubyte n; 0..24) {
    uint c = 0x08+0x0a*n; assert(c <= 255);
    res[f++] = (c<<16)|(c<<8)|c;
  }
  assert(f == 256);
  return res;
}();


static immutable uint[16] ttyRGB16 = {
  uint[16] res;
  // standard terminal colors
  version(tty_linux_dumb) {
    res[0] = 0x000000;
    res[1] = 0x800000;
    res[2] = 0x008000;
    res[3] = 0x808000;
    res[4] = 0x000080;
    res[5] = 0x800080;
    res[6] = 0x008080;
    res[7] = 0xc0c0c0;
    res[8] = 0x808080;
    res[9] = 0xff0000;
    res[10] = 0x00ff00;
    res[11] = 0xffff00;
    res[12] = 0x0000ff;
    res[13] = 0xff00ff;
    res[14] = 0x00ffff;
    res[15] = 0xffffff;
  } else version(tty_linux_hi) {
    res[0] = 0x000000;
    res[1] = 0xc00000;
    res[2] = 0x00c000;
    res[3] = 0xc0c000;
    res[4] = 0x0000c0;
    res[5] = 0xc000c0;
    res[6] = 0x00c0c0;
    res[7] = 0xc0c0c0;
    res[8] = 0x808080;
    res[9] = 0xff0000;
    res[10] = 0x00ff00;
    res[11] = 0xffff00;
    res[12] = 0x0000ff;
    res[13] = 0xff00ff;
    res[14] = 0x00ffff;
    res[15] = 0xffffff;
  } else {
    res[0] = 0x000000;
    res[1] = 0xb21818;
    res[2] = 0x18b218;
    res[3] = 0xb26818;
    res[4] = 0x1818b2;
    res[5] = 0xb218b2;
    res[6] = 0x18b2b2;
    res[7] = 0xb2b2b2;
    res[8] = 0x686868;
    res[9] = 0xff5454;
    res[10] = 0x54ff54;
    res[11] = 0xffff54;
    res[12] = 0x5454ff;
    res[13] = 0xff54ff;
    res[14] = 0x54ffff;
    res[15] = 0xffffff;
  }
  return res;
}();


version(termrgb_gamma_correct) {
  // color in sRGB space
  struct SRGB {
    float r=0, g=0, b=0; // [0..1]
    //alias x = r, y = g, z = b;
    this (float ar, float ag, float ab) pure nothrow @safe @nogc { r = ar; g = ag; b = ab; }
    this() (in auto ref FXYZ c) pure nothrow @safe @nogc {
      version(tty_XYZ) {
        immutable float xs = c.x* 3.2406+c.y*-1.5372+c.z*-0.4986;
        immutable float ys = c.x*-0.9689+c.y* 1.8758+c.z* 0.0415;
        immutable float zs = c.x* 0.0557+c.y*-0.2040+c.z* 1.0570;
        r = valueFromLinear(xs);
        g = valueFromLinear(ys);
        b = valueFromLinear(zs);
      } else {
        r = valueFromLinear(c.x);
        g = valueFromLinear(c.y);
        b = valueFromLinear(c.z);
      }
    }

    // linear to gamma conversion
    // value should be in [0..1] range
    static T valueFromLinear(T : real) (T v) pure nothrow @safe @nogc {
      import std.math : pow;
      return (v > 0.0031308 ? 1.055*pow(v, (1.0/2.4))-0.055 : 12.92*v);
    }
  }

  // color in linear space
  struct FXYZ {
    float x=0, y=0, z=0; // [0..1]
    this (float ax, float ay, float az) pure nothrow @safe @nogc { x = ax; y = ay; z = az; }
    this() (in auto ref SRGB c) pure nothrow @safe @nogc {
      version(tty_XYZ) {
        immutable float rl = valueFromGamma(c.r);
        immutable float gl = valueFromGamma(c.g);
        immutable float bl = valueFromGamma(c.b);
        // observer. = 2degs, Illuminant = D65
        x = rl*0.4124+gl*0.3576+bl*0.1805;
        y = rl*0.2126+gl*0.7152+bl*0.0722;
        z = rl*0.0193+gl*0.1192+bl*0.9505;
      } else {
        x = valueFromGamma(c.r);
        y = valueFromGamma(c.g);
        z = valueFromGamma(c.b);
      }
    }

    // gamma to linear conversion
    // value should be in [0..1] range
    static T valueFromGamma(T : real) (T v) pure nothrow @safe @nogc {
      import std.math : pow;
      return (v > 0.04045 ? pow((v+0.055)/1.055, 2.4) : v/12.92);
    }
  }
}


/// Convert 256-color terminal color number to approximate rgb values
public void ttyColor2rgb (ubyte cnum, out ubyte r, out ubyte g, out ubyte b) pure nothrow @trusted @nogc {
  pragma(inline, true);
  r = cast(ubyte)(ttyRGBTable.ptr[cnum]>>16);
  g = cast(ubyte)(ttyRGBTable.ptr[cnum]>>8);
  b = cast(ubyte)(ttyRGBTable.ptr[cnum]);
  /*
  if (cnum == 0) {
    r = g = b = 0;
  } else if (cnum == 8) {
    r = g = b = 0x80;
  } else if (cnum >= 0 && cnum < 16) {
    r = (cnum&(1<<0) ? (cnum&(1<<3) ? 0xff : 0x80) : 0x00);
    g = (cnum&(1<<1) ? (cnum&(1<<3) ? 0xff : 0x80) : 0x00);
    b = (cnum&(1<<2) ? (cnum&(1<<3) ? 0xff : 0x80) : 0x00);
  } else if (cnum >= 16 && cnum < 232) {
    // [0..5] -> [0..255]
    b = cast(ubyte)(((cnum-16)%6)*51);
    g = cast(ubyte)((((cnum-16)/6)%6)*51);
    r = cast(ubyte)((((cnum-16)/6/6)%6)*51);
  } else if (cnum >= 232 && cnum <= 255) {
    // [0..23] (0 is very dark gray; 23 is *almost* white)
    b = g = r = cast(ubyte)(8+(cnum-232)*10);
  }
  */
}

/// Ditto.
public alias ttyColor2RGB = ttyColor2rgb;

/// Ditto.
public alias ttyColor2Rgb = ttyColor2rgb;


immutable static ubyte[256] tty256to16tbl = () {
  ubyte[256] res;
  foreach (ubyte idx; 0..256) {
    immutable cc = ttyRGBTable[idx];
    immutable r = (cc>>16)&0xff;
    immutable g = (cc>>8)&0xff;
    immutable b = cc&0xff;
    res[idx] = ttyRGB!false(r, g, b);
  }
  foreach (ubyte idx; 0..16) res[idx] = idx;
  return res;
}();


immutable static ubyte[256] tty256to8tbl = () {
  ubyte[256] res;
  foreach (ubyte idx; 0..256) {
    immutable cc = ttyRGBTable[idx];
    immutable r = (cc>>16)&0xff;
    immutable g = (cc>>8)&0xff;
    immutable b = cc&0xff;
    res[idx] = ttyRGB!(false, true)(r, g, b);
  }
  foreach (ubyte idx; 0..8) { res[idx] = idx; res[idx+8] = idx; }
  return res;
}();


/// convert 256-color code to 16-color Linux console code
public ubyte tty2linux (ubyte ttyc) nothrow @trusted @nogc {
  pragma(inline, true);
  return (termType != TermType.linux ? ttyc : tty256to16tbl[ttyc]);
}


/// convert 256-color code to 8-color Linux console code
public ubyte tty2linux8 (ubyte ttyc) nothrow @trusted @nogc {
  pragma(inline, true);
  return (termType != TermType.linux ? ttyc : tty256to8tbl[ttyc]);
}


/// Force CTFE
public enum TtyRGB(ubyte r, ubyte g, ubyte b, bool allow256=true) = ttyRGB!allow256(r, g, b);

/// Ditto.
public enum TtyRGB(string rgb, bool allow256=true) = ttyRGB!allow256(rgb);

public alias TtyRgb = TtyRGB; /// Ditto.


/// Convert rgb values to approximate 256-color (or 16-color) teminal color number
public ubyte ttyRGB(bool allow256=true, bool only8=false) (const(char)[] rgb) pure nothrow @trusted @nogc {
  static int c2h (immutable char ch) pure nothrow @trusted @nogc {
         if (ch >= '0' && ch <= '9') return ch-'0';
    else if (ch >= 'A' && ch <= 'F') return ch-'A'+10;
    else if (ch >= 'a' && ch <= 'f') return ch-'a'+10;
    else return -1;
  }

  auto anchor = rgb;
  while (rgb.length && (rgb[0] <= ' ' || rgb[0] == '#')) rgb = rgb[1..$];
  while (rgb.length && rgb[$-1] <= ' ') rgb = rgb[0..$-1];
  if (rgb.length == 3) {
    foreach (immutable char ch; rgb) if (c2h(ch) < 0) return 7; // normal gray
    return ttyRGB(
      cast(ubyte)(255*c2h(rgb[0])/15),
      cast(ubyte)(255*c2h(rgb[1])/15),
      cast(ubyte)(255*c2h(rgb[2])/15),
    );
  } else if (rgb.length == 6) {
    foreach (immutable char ch; rgb) if (c2h(ch) < 0) return 7; // normal gray
    return ttyRGB(
      cast(ubyte)(16*c2h(rgb[0])+c2h(rgb[1])),
      cast(ubyte)(16*c2h(rgb[2])+c2h(rgb[3])),
      cast(ubyte)(16*c2h(rgb[4])+c2h(rgb[5])),
    );
  } else {
    return 7; // normal gray
  }
}


/// Convert rgb values to approximate 256-color (or 16-color) teminal color number
public ubyte ttyRGB(bool allow256=true, bool only8=false) (ubyte r, ubyte g, ubyte b) pure nothrow @trusted @nogc {
  // use standard (weighted) color distance function to find the closest match
  // d = ((r2-r1)*0.30)^^2+((g2-g1)*0.59)^^2+((b2-b1)*0.11)^^2
  version(termrgb_gamma_correct) {
    static if (only8) { enum lastc = 8; alias rgbtbl = ttyRGB16; }
    else {
      version(termrgb_disable_256_colors) { enum lastc = 16; alias rgbtbl = ttyRGB16; }
      else { static if (allow256) { enum lastc = 256; alias rgbtbl = ttyRGBTable;} else { enum lastc = 16; alias rgbtbl = ttyRGB16; } }
    }
    double dist = double.max;
    ubyte resclr = 0;
    immutable l0 = FXYZ(SRGB(r/255.0f, g/255.0f, b/255.0f));
    foreach (immutable idx, uint cc; rgbtbl[0..lastc]) {
      auto linear = FXYZ(SRGB(((cc>>16)&0xff)/255.0f, ((cc>>8)&0xff)/255.0f, (cc&0xff)/255.0f));
      linear.x -= l0.x;
      linear.y -= l0.y;
      linear.z -= l0.z;
      //double dd = linear.x*linear.x+linear.y*linear.y+linear.z*linear.z;
      double dd = (linear.x*linear.x)*0.30+(linear.y*linear.y)*0.59+(linear.z*linear.z)*0.11;
      if (dd < dist) {
        resclr = cast(ubyte)idx;
        dist = dd;
      }
    }
    return resclr;
  } else {
    enum n = 16384; // scale
    enum m0 = 4916; // 0.30*16384
    enum m1 = 9666; // 0.59*16384
    enum m2 = 1802; // 0.11*16384
    long dist = long.max;
    ubyte resclr = 0;
    static if (only8) { enum lastc = 8; alias rgbtbl = ttyRGB16; }
    else {
      version(termrgb_disable_256_colors) { enum lastc = 16; alias rgbtbl = ttyRGB16; }
      else { static if (allow256) { enum lastc = 256; alias rgbtbl = ttyRGBTable;} else { enum lastc = 16; alias rgbtbl = ttyRGB16; } }
    }
    foreach (immutable idx, uint cc; rgbtbl[0..lastc]) {
      version(termrgb_weighted_colors) {
        long dr = cast(int)((cc>>16)&0xff)-cast(int)r;
        dr = ((dr*m0)*(dr*m0))/n;
        assert(dr >= 0);
        long dg = cast(int)((cc>>8)&0xff)-cast(int)g;
        dg = ((dg*m1)*(dg*m1))/n;
        assert(dg >= 0);
        long db = cast(int)(cc&0xff)-cast(int)b;
        db = ((db*m2)*(db*m2))/n;
        assert(db >= 0);
        long d = dr+dg+db;
        assert(d >= 0);
      } else {
        long dr = cast(int)((cc>>16)&0xff)-cast(int)r;
        dr = dr*dr;
        assert(dr >= 0);
        long dg = cast(int)((cc>>8)&0xff)-cast(int)g;
        dg = dg*dg;
        assert(dg >= 0);
        long db = cast(int)(cc&0xff)-cast(int)b;
        db = db*db;
        assert(db >= 0);
        long d = dr+dg+db;
        assert(d >= 0);
      }
      if (d < dist) {
        resclr = cast(ubyte)idx;
        dist = d;
        if (d == 0) break; // no better match is possible
      }
    }
    return resclr;
  }
}

public alias ttyRgb = ttyRGB; /// Ditto.
