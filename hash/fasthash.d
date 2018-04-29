/* The MIT License
 * implementation of fasthash
 * http://code.google.com/p/fast-hash/
 *
 * Copyright (C) 2012 Zilong Tan (eric.zltan@gmail.com)
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use, copy,
 * modify, merge, publish, distribute, sublicense, and/or sell copies
 * of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
 * BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
 * ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */
module iv.hash.fasthash /*is aliced*/;
import iv.alice;


/**
 * 64-bit implementation of fasthash
 *
 * Params:
 *   buf =  data buffer
 *   seed = the seed
 */
public struct FastHash {
public:
  enum has64bit = true;
  enum has32bit = true;

private:
  enum M = 0x880355f21e6d1965UL;

private:
  ulong seed; // initial seed value; MUST BE FIRST
  ulong hash; // current value
  ulong accum; // we operate 64-bit chunks; high 3 bits of accum used as counter
  ulong totallen;

public:
nothrow @trusted @nogc:
  /// construct state with seed
  this (ulong aseed) pure { pragma(inline, true); hash = seed = aseed; }

  /// reset state
  void reset () pure { pragma(inline, true); accum = totallen = 0; hash = seed; }

  /// reset state
  void reset (ulong aseed) pure { pragma(inline, true); accum = totallen = 0; hash = seed = aseed; }

  /// process data block
  void put(T) (scope const(T)[] data...) if (T.sizeof == 1) {
    if (data.length == 0) return; // nothing to do
    if (totallen == 0) hash = seed;
    auto bytes = cast(const(ubyte)*)data.ptr;
    auto len = data.length;
    if (totallen+len < totallen) assert(0, "FastHash: too much data"); // overflow
    totallen += len;
    auto h = hash;
    auto acc = accum;
    // do we have something in accum?
    if (acc) {
      // consume any carry bytes
      ubyte i = (acc>>61)&7;
      assert(i != 0);
      acc &= ~(7UL<<61);
      while (i < 8 && len) {
        acc |= (cast(ulong)(*bytes++))<<(i*8);
        ++i;
        --len;
      }
      if (i == 8) {
        // got 8 bytes, process 'em
        acc ^= acc>>23;
        acc *= 0x2127599bf4325c37UL;
        acc ^= acc>>47;
        h ^= acc;
        h *= M;
        acc = 0;
      } else {
        // update counter
        assert(i < 8);
        assert(len == 0);
        acc |= (cast(ulong)i)<<61;
      }
    }
    // now process 8-byte blocks
    assert(len == 0 || acc == 0);
    ulong t;
    foreach (immutable _; 0..len/8) {
      if (__ctfe) {
        t = cast(ulong)bytes[0]|
           (cast(ulong)bytes[1]<<8)|
           (cast(ulong)bytes[2]<<16)|
           (cast(ulong)bytes[3]<<24)|
           (cast(ulong)bytes[4]<<32)|
           (cast(ulong)bytes[5]<<40)|
           (cast(ulong)bytes[6]<<48)|
           (cast(ulong)bytes[7]<<56);
      } else {
        version(LittleEndian) {
          t = *cast(const(ulong)*)bytes;
        } else {
          t = cast(ulong)bytes[0]|
             (cast(ulong)bytes[1]<<8)|
             (cast(ulong)bytes[2]<<16)|
             (cast(ulong)bytes[3]<<24)|
             (cast(ulong)bytes[4]<<32)|
             (cast(ulong)bytes[5]<<40)|
             (cast(ulong)bytes[6]<<48)|
             (cast(ulong)bytes[7]<<56);
        }
      }
      bytes += 8;
      t ^= t>>23;
      t *= 0x2127599bf4325c37UL;
      t ^= t>>47;
      h ^= t;
      h *= M;
    }
    // do we have something to push into accum?
    if ((len &= 7) != 0) {
      foreach (immutable shift; 0..len) {
        acc |= (cast(ulong)(*bytes++))<<(shift*8);
      }
      acc |= (cast(ulong)len)<<61;
    }
    hash = h;
    accum = acc;
  }

  /// finalize a hash (i.e. return current result).
  /// note that you can continue putting data, as this is not destructive
  @property ulong result64 () const pure {
    ulong h = hash;
    if (totallen == 0) h = seed;
    h ^= totallen*M;

    ulong acc = accum;
    if (acc) {
      acc &= ~(7UL<<61);
      h ^= acc&(7UL<<61);
    }
    acc ^= acc>>23;
    acc *= 0x2127599bf4325c37UL;
    acc ^= acc>>47;
    h ^= acc;
    h *= M;

    h ^= h>>23;
    h *= 0x2127599bf4325c37UL;
    h ^= h>>47;
    return h;
  }

  /// finalize a hash (i.e. return current result).
  /// note that you can continue putting data, as this is not destructive
  @property uint result32 () const pure {
    pragma(inline, true);
    auto h = result64;
    // the following trick converts the 64-bit hashcode to Fermat
    // residue, which shall retain information from both the higher
    // and lower parts of hashcode.
    return cast(uint)(h-(h>>32));
  }

  ulong finish64 () pure { auto res = result64; reset(); return res; } /// resets state
  ulong finish32 () pure { auto res = result32; reset(); return res; } /// resets state
}


/**
 * 64-bit implementation of fasthash
 *
 * Params:
 *   buf =  data buffer
 *   seed = the seed
 */
ulong fastHash64(T) (const(T)[] buf, ulong seed=0) nothrow @trusted @nogc if (T.sizeof == 1) {
  auto hh = FastHash(seed);
  hh.put(buf);
  return hh.result64;
}

/**
 * 32-bit implementation of fasthash
 *
 * Params:
 *   buf =  data buffer
 *   seed = the seed
 */
uint fastHash32(T) (const(T)[] buf, ulong seed=0) nothrow @trusted @nogc if (T.sizeof == 1) {
  auto hh = FastHash(seed);
  hh.put(buf);
  return hh.result32;
}


/**
 * 64-bit implementation of fasthash
 *
 * Params:
 *   buf =  data buffer
 *   seed = the seed
 */
ulong fastHash64(T) (const(T)[] buf, ulong seed=0) nothrow @trusted @nogc if (T.sizeof > 1) {
  auto hh = FastHash(seed);
  hh.put((cast(const(ubyte)*)buf.ptr)[0..buf.length*T.sizeof]);
  return hh.result64;
}

/**
 * 32-bit implementation of fasthash
 *
 * Params:
 *   buf =  data buffer
 *   seed = the seed
 */
uint fastHash32(T) (const(T)[] buf, ulong seed=0) nothrow @trusted @nogc if (T.sizeof > 1) {
  auto hh = FastHash(seed);
  hh.put((cast(const(ubyte)*)buf.ptr)[0..buf.length*T.sizeof]);
  return hh.result32;
}


version(iv_hash_unittest) unittest {
  static assert(fastHash32("Alice & Miriel") == 0x4773e2a3U);
  static assert(fastHash64("Alice & Miriel") == 0xfa02b41e417696c1UL);

  /*{
    import std.stdio;
    writefln("0x%08xU", fastHash32("Alice & Miriel"));
    writefln("0x%016xUL", fastHash64("Alice & Miriel"));
  }*/

  mixin(import("test.d"));
  doTest!(32, "FastHash")("Alice & Miriel", 0x4773e2a3U);
  doTest!(64, "FastHash")("Alice & Miriel", 0xfa02b41e417696c1UL);
}
