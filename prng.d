/* coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * Understanding is not required. Only obedience.
 *
 *                   INVISIBLE VECTOR PUBLIC LICENSE
 *                       Version 0, August 2014
 *
 * Copyright (C) 2014 Ketmar Dark <ketmar@ketmar.no-ip.org>
 *
 * Everyone is permitted to copy and distribute verbatim or modified
 * copies of this license document, and changing it is allowed as long
 * as the name is changed.
 *
 *                   INVISIBLE VECTOR PUBLIC LICENSE
 *   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
 *
 * 0. You may not use this software in either source or binary form, any
 *    software derived from this software, any library which uses either
 *    this software or code derived from this software in any other
 *    software which uses Windows API, either directly or indirectly
 *    via any chain of libraries.
 *
 * 1. You may not use this software in either source or binary form, any
 *    software derived from this software, any library which uses either
 *    this software or code derived from this software in any other
 *    software which uses MacOS X API, either directly or indirectly via
 *    any chain of libraries.
 *
 * 2. You may not use this software in either source or binary form, any
 *    software derived from this software, any library which uses either
 *    this software or code derived from this software in any other
 *    software on the territory of Russian Federation, either directly or
 *    indirectly via any chain of libraries.
 *
 * 3. Redistributions of this software in either source or binary form must
 *    retain this list of conditions and the following disclaimer.
 *
 * 4. Otherwise, you are allowed to use this software in any way that will
 *    not violate paragraphs 0, 1, 2 and 3 of this license.
 *
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 * Authors: Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * License: IVPLv0
 */
module iv.prng is aliced;


private uint xyzzyPRNGHashU32() (uint a) {
  a -= (a<<6);
  a ^= (a>>17);
  a -= (a<<9);
  a ^= (a<<4);
  a -= (a<<3);
  a ^= (a<<10);
  a ^= (a>>15);
  return a;
}


// ////////////////////////////////////////////////////////////////////////// //
// by Bob Jenkins
// public domain
// http://burtleburtle.net/bob/rand/smallprng.html
struct BJRng {
private:
  // seeded with 0xdeadf00du
  uint a = 0xe5595c3bu;
  uint b = 0xe60c3611u;
  uint c = 0x1ceca1b1u;
  uint d = 0x32744417u;

nothrow: @nogc:
public:
  void randomize () @trusted {
    version(Windows) {
      import win32.windef, win32.winbase;
      uint s0 = xyzzyPRNGHashU32(cast(uint)GetCurrentProcessId());
      uint s1 = xyzzyPRNGHashU32(cast(uint)GetTickCount());
      seed(s0^s1);
    } else {
      // assume POSIX
      import core.sys.posix.fcntl;
      import core.sys.posix.unistd;
      uint s0 = 0xdeadf00du;
      int fd = open("/dev/urandom", O_RDONLY);
      if (fd >= 0) {
        read(fd, &s0, s0.sizeof);
        close(fd);
      }
      seed(s0);
    }
  }

@safe:
  enum empty = false;
  @property uint front () const => d;
  alias popFront = next;
  @property auto save () inout => this;

  this (uint aseed) => seed(aseed);

  void seed (uint seed) {
    a = 0xf1ea5eed;
    b = c = d = seed;
    foreach (; 0..20) next;
  }

  @property uint next () {
    enum ROT(string var, string cnt) = `cast(uint)(((`~var~`)<<(`~cnt~`))|((`~var~`)>>(32-(`~cnt~`))))`;
    uint e;
    /* original:
      e = a-BJPRNG_ROT(b, 27);
      a = b^BJPRNG_ROT(c, 17);
      b = c+d;
      c = d+e;
      d = e+a;
    */
    /* better, but slower at least in idiotic m$vc */
    e = a-mixin(ROT!("b", "23"));
    a = b^mixin(ROT!("c", "16"));
    b = c+mixin(ROT!("d", "11"));
    c = d+e;
    d = e+a;
    return d;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
// One of the by George Marsaglia's prng generators.
// It is based on George Marsaglia's MWC (multiply with carry) generator.
// Although it is very simple, it passes Marsaglia's DIEHARD series of random
// number generator tests.
struct GMRngSeed64 {
private:
  // These values are not magical, just the default values Marsaglia used.
  // Any pair of unsigned integers should be fine.
  enum uint DefaultW = 521288629u;
  enum uint DefaultZ = 362436069u;

  uint w = DefaultW;
  uint z = DefaultZ;
  uint lastnum = (DefaultZ<<16)+DefaultW;

nothrow: @nogc:
public:
  void randomize () @trusted {
    version(Windows) {
      import win32.windef, win32.winbase;
      w = xyzzyPRNGHashU32(cast(uint)GetCurrentProcessId());
      z = xyzzyPRNGHashU32(cast(uint)GetTickCount());
    } else {
      // assume POSIX
      import core.sys.posix.fcntl;
      import core.sys.posix.unistd;
      w = DefaultW;
      z = DefaultZ;
      int fd = open("/dev/urandom", O_RDONLY);
      if (fd >= 0) {
        read(fd, &w, w.sizeof);
        read(fd, &z, z.sizeof);
        close(fd);
      }
    }
  }

@safe:
  enum empty = false;
  @property uint front () const => lastnum;
  alias popFront = next;
  @property auto save () inout => this;

  this (ulong aseed) => seed(aseed);

  void seed (ulong seed) {
    z = cast(uint)(seed>>32);
    w = cast(uint)(seed&0xffffffffu);
    if (w == 0) w = DefaultW;
    if (z == 0) z = DefaultZ;
    lastnum = (z<<16)+w;
  }

  @property uint next () {
    if (w == 0) w = DefaultW;
    if (z == 0) z = DefaultZ;
    z = 36969*(z&0xffff)+(z>>16);
    w = 18000*(w&0xffff)+(w>>16);
    return (lastnum = (z<<16)+w);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
// one of the by George Marsaglia's prng generators, period about 2^160. fast.
struct GMRng {
private:
  // seeded with 0xdeadf00du
  uint x = 0xdeadf00du;
  uint y = 0xe3324aa1u;
  uint z = 0x7ed1c277u;
  uint w = 0x89574524u;
  uint v = 0x359c34a7u;
  uint lastnum = 0x4d00381eu; // almost arbitrary

nothrow: @nogc:
public:
  void randomize () @trusted {
    version(Windows) {
      import win32.windef, win32.winbase;
      uint[5] s0;
      s0[0] = xyzzyPRNGHashU32(cast(uint)GetCurrentProcessId());
      s0[1] = xyzzyPRNGHashU32(cast(uint)GetTickCount());
      seed(s0[]);
    } else {
      // assume POSIX
      import core.sys.posix.fcntl;
      import core.sys.posix.unistd;
      uint[5] s0;
      int fd = open("/dev/urandom", O_RDONLY);
      if (fd >= 0) {
        read(fd, s0.ptr, s0.sizeof);
        close(fd);
      }
      seed(s0[]);
    }
  }

@safe:
  enum empty = false;
  @property uint front () const => lastnum;
  alias popFront = next;
  @property auto save () inout => this;

  this (uint aseed) => seed(aseed);

  void seed (uint seed) {
    x = (seed ? seed : 0xdeadf00du);
    y = xyzzyPRNGHashU32(x+1);
    z = xyzzyPRNGHashU32(y+1);
    w = xyzzyPRNGHashU32(z+1);
    v = xyzzyPRNGHashU32(w+1);
    next;
  }

  void seed (uint s0, uint s1, uint s2, uint s3, uint s4) {
    x = s0;
    y = s1;
    z = s2;
    w = s3;
    v = s4;
    if (x == 0) x = 0xdeadf00du;
    if (y == 0) y = xyzzyPRNGHashU32(x+1);
    if (z == 0) z = xyzzyPRNGHashU32(y+1);
    if (w == 0) w = xyzzyPRNGHashU32(z+1);
    if (v == 0) v = xyzzyPRNGHashU32(w+1);
    next;
  }

  void seed (in uint[] seed) {
    x = (seed.length > 0 ? seed[0] : 0xdeadf00du);
    y = (seed.length > 1 ? seed[1] : xyzzyPRNGHashU32(x+1));
    z = (seed.length > 2 ? seed[2] : xyzzyPRNGHashU32(y+1));
    w = (seed.length > 3 ? seed[3] : xyzzyPRNGHashU32(z+1));
    v = (seed.length > 4 ? seed[4] : xyzzyPRNGHashU32(w+1));
    if (x == 0) x = 0xdeadf00du;
    if (y == 0) y = xyzzyPRNGHashU32(x+1);
    if (z == 0) z = xyzzyPRNGHashU32(y+1);
    if (w == 0) w = xyzzyPRNGHashU32(z+1);
    if (v == 0) v = xyzzyPRNGHashU32(w+1);
    next;
  }

  @property uint next () {
    uint t;
    t = (x^(x>>7));
    x = y;
    y = z;
    z = w;
    w = v;
    v = (v^(v<<6))^(t^(t<<13));
    return (lastnum = (y+y+1)*v);
  }
}


version(test_prng)
unittest {
  import std.range;
  template checkRng(T) {
    static assert(isInfinite!T, T.stringof~" is not infinite range");
    static assert(isInputRange!T, T.stringof~" is not inpute range");
    static assert(isForwardRange!T, T.stringof~" is not forward range");
    enum checkRng = true;
  }
  static assert(checkRng!BJRng);
  static assert(checkRng!GMRngSeed64);
  static assert(checkRng!GMRng);

  import iv.writer;
  /*
  {
    BJRng r;
    r.seed(0xdeadf00du);
    writefln!"  uint a = 0x%08xu;"(r.a);
    writefln!"  uint b = 0x%08xu;"(r.b);
    writefln!"  uint c = 0x%08xu;"(r.c);
    writefln!"  uint d = 0x%08xu;"(r.d);
  }
  */
  /*
  {
    GMRngSeed64 r;
    r.seed(0xdeadf00d_fee1deadul);
    writefln!"  uint w = 0x%08xu;"(r.w);
    writefln!"  uint z = 0x%08xu;"(r.z);
  }
  */
  /*
  {
    GMRng r;
    r.seed(0xdeadf00du);
    writefln!"  uint x = 0x%08xu;"(r.x);
    writefln!"  uint y = 0x%08xu;"(r.y);
    writefln!"  uint z = 0x%08xu;"(r.z);
    writefln!"  uint w = 0x%08xu;"(r.w);
    writefln!"  uint v = 0x%08xu;"(r.v);
  }
  */
  {
    BJRng r;
    r.randomize();
    writefln!"0x%08x"(r.next);
  }
  {
    GMRngSeed64 r;
    r.randomize();
    writefln!"0x%08x"(r.next);
  }
  {
    GMRng r;
    r.randomize();
    writefln!"0x%08x"(r.next);
  }
}
