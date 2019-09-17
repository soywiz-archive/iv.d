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
// PCG32 / (c) 2014 M.E. O'Neill / pcg-random.org
// Original code: Licensed under Apache License 2.0 (NO WARRANTY, etc. see website)
module iv.prng.pcg32 /*is aliced*/;
import iv.alice;


struct PCG32 {
private:
  // for 0x29a, 42
  // state
  ulong state = 0x83a6d64d022268cdUL; // current state: PCG32 iterates through all 2^^64 possible internal states
  ulong inc = 0x00000055UL; // sequence constant: a value that defines which of 2^^63 possible random sequences the current state is iterating through; it holds the same value over the lifetime of the PCG32
  // current value
  uint s = 0xe1ad5be5UL;

public:
pure nothrow @trusted @nogc:
  enum bool isUniformRandom = true;
  enum uint min = 0;
  enum uint max = 0xffff_ffffu; // 32 bits

  enum bool empty = false;

  // seed the rng: specified in two parts, state initializer and a sequence selection constant (a.k.a. stream id)
  this (ulong initstate, ulong initseq=42) { pragma(inline, true); seed(initstate, initseq); }

  private this() (in auto ref PCG32 src) { pragma(inline, true); state = src.state; inc = src.inc; s = src.s; }

  @property uint front () const { pragma(inline, true); return s; }

  auto save () const { pragma(inline, true); return PCG32(this); }

  void popFront () {
    immutable ulong oldstate = state;
    // advance internal state
    state = oldstate*6364136223846793005UL+(inc|1);
    // calculate output function (XSH RR), uses old state for max ILP
    immutable uint xorshifted = cast(uint)(((oldstate>>18u)^oldstate)>>27u);
    immutable uint rot = oldstate>>59u;
    s = (xorshifted>>rot)|(xorshifted<<((-rot)&31));
  }

  // seed the rng: specified in two parts, state initializer and a sequence selection constant (a.k.a. stream id)
  void seed (ulong initstate, ulong initseq) {
    state = 0u;
    inc = (initseq<<1u)|1u;
    popFront();
    state += initstate;
    popFront();
    // and current value
    popFront();
  }
}


version(test_pcg32) unittest {
  static immutable uint[8] checkValues = [
    1062842430u,
    3170867712u,
    3675510485u,
    1618657033u,
    1785850257u,
    269545398u,
    2793572921u,
    3477214955u,
  ];
  /*
  {
    auto rng = PCG32(0x29a);
    import std.stdio;
    writefln("ulong state = 0x%08xUL;", rng.state);
    writefln("ulong inc = 0x%08xUL;", rng.inc);
    writefln("uint s = 0x%08xUL;", rng.s);
  }
  */
  {
    auto rng = PCG32(0);
    foreach (uint v; checkValues) {
      if (v != rng.front) assert(0);
      //import std.stdio; writeln(rng.front, "u,");
      rng.popFront();
    }
  }
  // std.random test
  {
    import std.random : uniform;
    auto rng = PCG32(0);
    foreach (immutable _; 0..8) {
      import std.stdio;
      auto v = uniform!"[)"(0, 4, rng);
      writeln(v, "uL");
    }
  }
}


/*
// *Really* minimal PCG32 code / (c) 2014 M.E. O'Neill / pcg-random.org
// Licensed under Apache License 2.0 (NO WARRANTY, etc. see website)

struct pcg32_random_t { ulong state, inc; }

uint pcg32_random_r (ref pcg32_random_t rng) {
  ulong oldstate = rng.state;
  // advance internal state
  rng.state = oldstate*6364136223846793005UL+(rng.inc|1);
  // calculate output function (XSH RR), uses old state for max ILP
  immutable uint xorshifted = ((oldstate>>18u)^oldstate)>>27u;
  immutable uint rot = oldstate>>59u;
  return (xorshifted>>rot)|(xorshifted<<((-rot)&31));
}

// pcg32_srandom_r(rng, initstate, initseq):
//     Seed the rng.  Specified in two parts, state initializer and a
//     sequence selection constant (a.k.a. stream id)
void pcg32_srandom_r (ref pcg32_random_t rng, ulong initstate, ulong initseq) {
  rng.state = 0U;
  rng.inc = (initseq<<1u)|1u;
  pcg32_random_r(rng);
  rng.state += initstate;
  pcg32_random_r(rng);
}
*/
