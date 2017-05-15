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
// Park-Miller-Carta Pseudo-Random Number Generator, based on David G. Carta paper
// 31 bit of randomness
// seed is previous result, as usual
module iv.prng.pmc31 is aliced;


struct PMC31 {
private:
  enum si0 = 0x00aacc76u; //next step from 0x29au;
  uint s = si0;

public:
pure nothrow @trusted @nogc:
  enum bool isUniformRandom = true;
  enum uint min = 0;
  enum uint max = 0x7fff_ffffu; // 31 bit

  enum bool empty = false;

  this (uint s0) { pragma(inline, true); seed(s0); }

  @property uint front () const { pragma(inline, true); return s; }

  auto save () const { pragma(inline, true); return PMC31(s); }

  void popFront () {
    if (s == 0) s = si0;
    uint lo = 16807*(s&0xffff);
    immutable uint hi = 16807*(s>>16);
    lo += (hi&0x7fff)<<16;
    lo += hi>>15;
    //if (lo > 0x7fffffff) lo -= 0x7fffffff; // should be >=, actually
    s = (lo&0x7FFFFFFF)+(lo>>31); // same as previous code, but branch-less
  }

  void seed (uint s0) { pragma(inline, true); s = (s0 ? s0 : si0); }
}


version(test_pmc31) unittest {
  static immutable uint[8] checkValues = [
    11193462u,
    1297438545u,
    500674177u,
    989963893u,
    1767336342u,
    1775578337u,
    712351247u,
    266076304u,
  ];
  {
    auto rng = PMC31(0);
    foreach (ulong v; checkValues) {
      if (v != rng.front) assert(0);
      //import std.stdio; writeln(rng.front, "u");
      rng.popFront();
    }
  }
  // std.random test
  {
    import std.random : uniform;
    auto rng = PMC31(0);
    foreach (immutable _; 0..8) {
      import std.stdio;
      auto v = uniform!"[)"(0, 4, rng);
      writeln(v, "uL");
    }
  }
}
