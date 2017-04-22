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
module iv.hash.joaat;
// Bob Jenkins' One-At-A-Time hash function


// this seems to give worser results
//version = JoaatMixLength;


/**
 * 32-bit implementation of joaat
 *
 * Params:
 *   buf =  data buffer
 *   seed = the seed
 */
public struct JoaatHash {
public:
  enum has64bit = false;
  enum has32bit = true;

private:
  uint seed; // initial seed value; MUST BE FIRST
  uint hash; // current value
  version(JoaatMixLength) {
    ulong totallen;
  } else {
    ubyte totallen;
  }

public:
nothrow @trusted @nogc:
  /// construct state with seed
  this (uint aseed) pure { hash = seed = aseed; }

  /// reset state
  void reset () pure { totallen = 0; hash = seed; }

  /// reset state
  void reset (uint aseed) pure { totallen = 0; hash = seed = aseed; }

  /// process data block
  void put(T) (scope const(T)[] data...) if (T.sizeof == 1) {
    if (data.length == 0) return; // nothing to do
    if (totallen == 0) hash = seed;
    auto bytes = cast(const(ubyte)*)data.ptr;
    auto len = data.length;
    version(JoaatMixLength) {
      if (totallen+len < totallen) assert(0, "FastHash: too much data"); // overflow
      totallen += len;
    } else {
      totallen = 1;
    }
    auto h = hash;
    foreach (immutable _; 0..len) {
      h += *bytes++;
      h += (h<<10);
      h ^= (h>>6);
    }
    hash = h;
  }

  /// finalize a hash (i.e. return current result).
  /// note that you can continue putting data, as this is not destructive
  @property uint result32 () const pure {
    uint h = hash;
    if (totallen == 0) h = seed;
    version(JoaatMixLength) {
      ulong len = totallen;
      while (len != 0) {
        h += len&0xff;
        h += (h<<10);
        h ^= (h>>6);
        len >>= 8;
      }
    }
    h += (h<<3);
    h ^= (h>>11);
    h += (h<<15);
    return h;
  }

  uint finish32 () pure { auto res = result32; reset(); return res; } /// resets state
}


/**
 * 32-bit implementation of joaathash
 *
 * Params:
 *   buf =  data buffer
 *   seed = the seed
 */
uint joaatHash32(T) (const(T)[] buf, uint seed=0) nothrow @trusted @nogc if (T.sizeof == 1) {
  auto hh = JoaatHash(seed);
  hh.put(buf);
  return hh.result32;
}


unittest {
  version(JoaatMixLength) {
    enum HashValue = 0x17fa5136U;
  } else {
    enum HashValue = 0xb8519b5bU;
  }
  static assert(joaatHash32("Alice & Miriel") == HashValue);

  /*{
    import std.stdio;
    writefln("0x%08xU", joaatHash32("Alice & Miriel"));
  }*/

  mixin(import("test.d"));
  doTest!(32, "JoaatHash")("Alice & Miriel", HashValue);
}
