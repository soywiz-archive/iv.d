/* Written in 2016 by David Blackman and Sebastiano Vigna (vigna@acm.org)
 * To the extent possible under law, the author has dedicated all copyright
 * and related and neighboring rights to this software to the public domain
 * worldwide. This software is distributed without any warranty.
 *
 * See <http://creativecommons.org/publicdomain/zero/1.0/>.
 */
// D port by Ketmar // Invisible Vector
// http://xoroshiro.di.unimi.it/xoroshiro128plus.c
module iv.prng.xs128p /*is aliced*/;
import iv.alice;

/* This is the successor to xorshift128+. It is the fastest full-period
 * generator passing BigCrush without systematic failures, but due to the
 * relatively short period it is acceptable only for applications with a
 * mild amount of parallelism; otherwise, use a xorshift1024* generator.
 *
 * Beside passing BigCrush, this generator passes the PractRand test suite
 * up to (and included) 16TB, with the exception of binary rank tests,
 * which fail due to the lowest bit being an LFSR; all other bits pass all
 * tests.
 *
 * Note that the generator uses a simulated rotate operation, which most C
 * compilers will turn into a single instruction. In Java, you can use
 * Long.rotateLeft(). In languages that do not make low-level rotation
 * instructions accessible xorshift128+ could be faster.
 *
 * The state must be seeded so that it is not everywhere zero. If you have
 * a 64-bit seed, we suggest to seed a splitmix64 generator and use its
 * output to fill s. */
struct XS128P {
private:
  enum si0 = 0x4d00000000a6829buL;
  enum si1 = 0x000029a000000000uL;
  ulong[2] s = [si0,si1];//[0x29a,0];

public:
pure nothrow @trusted @nogc:
  enum bool isUniformRandom = true;
  // tnx to Joseph Rushton Wakeling
  enum ulong min = ulong.min;
  enum ulong max = ulong.max;

  enum bool empty = false;

  this (ulong s0, ulong s1=0) { seed(s0, s1); }
  this() (auto ref ulong[2] as) { seed(as[]); }

  @property ulong front () const { pragma(inline, true); return s.ptr[0]+s.ptr[1]; }

  auto save () const { pragma(inline, true); return XS128P(s.ptr[0], s.ptr[1]); }

  void popFront () {
    immutable ulong s1 = s.ptr[1]^s.ptr[0];
    s.ptr[0] = mixin(rol!("s.ptr[0]", 55))^s1^(s1<<14); // a, b
    s.ptr[1] = mixin(rol!("s1", 36)); // c
  }

  void seed (ulong s0, ulong s1=0) { pragma(inline, true); s.ptr[0] = s0; s.ptr[1] = s1; if (!s.ptr[0] && !s.ptr[1]) { s.ptr[0] = si0; s.ptr[1] = si1; } }
  void seed() (auto ref ulong[2] as) { pragma(inline, true); s[] = as[]; if (!s.ptr[0] && !s.ptr[1]) { s.ptr[0] = si0; s.ptr[1] = si1; } }

  /* This is the jump function for the generator. It is equivalent
     to 2^64 calls to next(); it can be used to generate 2^64
     non-overlapping subsequences for parallel computations. */
  void jump () {
    ulong s0 = 0;
    ulong s1 = 0;
    foreach (ulong jmp; [0xbeac0467eba5facb, 0xd86b048b86aa9922]) {
      foreach (immutable b; 0..64) {
        if (cast(ulong)(jmp&1)<<b) {
          s0 ^= s.ptr[0];
          s1 ^= s.ptr[1];
        }
        popFront();
      }
    }
    s.ptr[0] = s0;
    s.ptr[1] = s1;
  }

private:
  static enum rol(string var, int count) /*if (count > 0 && count < 64)*/ = "("~var~"<<"~count.stringof~")|("~var~">>(64-"~count.stringof~"))";
}


version(test_xs128p) unittest {
  static immutable ulong[8] checkValues = [
    5548480508102869659uL,
    1528641388659518426uL,
    5608521991067537321uL,
    7624901879973463697uL,
    10149332692067980019uL,
    17875739269509510643uL,
    3809796149818962200uL,
    13627210250571023489uL,
  ];
  {
    auto rng = XS128P(0);
    foreach (ulong v; checkValues) {
      if (v != rng.front) assert(0);
      rng.popFront();
    }
  }
  // std.random test
  {
    import std.random : uniform;
    auto rng = XS128P(0);
    foreach (immutable _; 0..8) {
      import std.stdio;
      auto v = uniform!"[)"(0, 4, rng);
      writeln(v, "uL");
    }
  }
}
