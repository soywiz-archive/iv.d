/*-----------------------------------------------------------------------------
 * MurmurHash3 was written by Austin Appleby, and is placed in the public
 * domain.
 *
 * This implementation was written by Shane Day, and is also public domain.
 * Translated to D by Ketmar // Invisible Vector
 *
 * This is a D implementation of MurmurHash3_x86_32 (Murmur3A) with support
 * for progressive processing.
 */
module iv.hash.murhash;

/*-----------------------------------------------------------------------------

If you want to understand the MurmurHash algorithm you would be much better
off reading the original source. Just point your browser at:
http://code.google.com/p/smhasher/source/browse/trunk/MurmurHash3.cpp


What this version provides?

Progressive data feeding. Useful when the entire payload to be hashed
does not fit in memory or when the data is streamed through the application.
Also useful when hashing a number of strings with a common prefix. A partial
hash of a prefix string can be generated and reused for each suffix string.


How does it work?

We can only process entire 32 bit chunks of input, except for the very end
that may be shorter. So along with the partial hash we need to give back to
the caller a carry containing up to 3 bytes that we were unable to process.
This carry also needs to record the number of bytes the carry holds. I use
the low 2 bits as a count (0..3) and the carry bytes are shifted into the
high byte in stream order.

To handle endianess I simply use a macro that reads a uint32_t and define
that macro to be a direct read on little endian machines, a read and swap
on big endian machines, or a byte-by-byte read if the endianess is unknown.

-----------------------------------------------------------------------------*/

public struct MurHash {
private:
  enum C1 = 0xcc9e2d51u;
  enum C2 = 0x1b873593u;

private:
  uint accum; // we operate 32-bit chunks; low 2 bits of accum used as counter
  uint hash; // current value
  uint totallen; // to match the original Murmur3A

public:
@trusted:
nothrow:
@nogc:
  /// construct state with seed
  this (uint seed) { hash = seed; }

  /// reset state
  void reset (uint seed=0) { accum = totallen = 0; hash = seed; }

  /// process data block
  void put(T) (scope const(T)[] data...) if (T.sizeof == 1) {
    if (data.length == 0) return; // nothing to do
    uint acc = accum;
    uint hh = hash;
    auto bytes = cast(const(ubyte)*)data.ptr;
    auto len = data.length;
    static if (len.sizeof > uint.sizeof) {
      if (len > uint.max) assert(0, "MurHash: too much data");
    }
    if (uint.max-totallen < len) assert(0, "MurHash: too much data"); // overflow
    totallen += len;
    // extract carry count from low 2 bits of accum value
    ubyte n = acc&3;
    // consume any carry bytes
    ubyte i = (4-n)&3;
    if (i && i <= len) {
      while (i--) {
        acc = (acc>>8)|(*bytes++<<24);
        --len;
        if (++n == 4) {
          n = 0;
          acc *= C1;
          acc = (acc<<15)|(acc>>(32-15));
          acc *= C2;
          hh ^= acc;
          hh = (hh<<13)|(hh>>(32-13));
          hh = hh*5+0xe6546b64;
        }
      }
    }
    // process 32-bit chunks
    uint k1;
    foreach (immutable _; 0..len/4) {
      version(LittleEndian) {
        if (__ctfe) {
          k1 = (bytes[0])|(bytes[1]<<8)|(bytes[2]<<16)|(bytes[3]<<24);
        } else {
          k1 = *cast(uint*)bytes;
        }
      } else {
        if (__ctfe) {
          k1 = (bytes[3])|(bytes[2]<<8)|(bytes[1]<<16)|(bytes[0]<<24);
        } else {
          import core.bitop : bswap;
          k1 = bswap(*cast(uint*)bytes);
        }
      }
      bytes += 4;
      k1 *= C1;
      k1 = (k1<<15)|(k1>>(32-15));
      k1 *= C2;
      hh ^= k1;
      hh = (hh<<13)|(hh>>(32-13));
      hh = hh*5+0xe6546b64;
    }
    // advance over whole 32-bit chunks, possibly leaving 1..3 bytes
    len -= len/4*4;
    // append any remaining bytes into carry
    while (len--) {
      acc = (acc>>8)|(*bytes++<<24);
      if (++n == 4) {
        n = 0;
        acc *= C1;
        acc = (acc<<15)|(acc>>(32-15));
        acc *= C2;
        hh ^= acc;
        hh = (hh<<13)|(hh>>(32-13));
        hh = hh*5+0xe6546b64;
      }
    }
    // store accum counter
    acc = (acc&~0xff)|n;
    // update state
    hash = hh;
    accum = acc;
  }

  /// process data block
  void put(T) (const(T)[] data) if (T.sizeof != 1) { put!ubyte(cast(const(ubyte)[])data); }

  /// finalize a hash (i.e. return current result).
  /// note that you can continue putting data to MurHash, as this is not destructive
  uint result () const {
    uint acc = accum;
    uint hh = hash;
    immutable n = acc&3;
    if (n) {
      uint k1 = acc>>(4-n)*8;
      k1 *= C1;
      k1 = (k1<<15)|(k1>>(32-15));
      k1 *= C2;
      hh ^= k1;
    }
    hh ^= totallen;
    // fmix
    hh ^= hh>>16;
    hh *= 0x85ebca6bu;
    hh ^= hh>>13;
    hh *= 0xc2b2ae35u;
    hh ^= hh>>16;
    return hh;
  }

  /// very clever hack
  static uint opIndex(T) (const(T)[] data, uint seed=0) if (T.sizeof == 1) {
    auto mur = MurHash(seed);
    mur.put(data);
    return mur.result;
  }

  /// very clever hack
  static uint opIndex(T) (const(T)[] data, uint seed=0) if (T.sizeof != 1) {
    return MurHash.opIndex!ubyte(cast(const(ubyte)[])data);
  }
}


unittest {
  // wow, we can do this in compile time!
  static assert(MurHash["Alice & Miriel"] == 0x295db5e7u);
  // and in runtime
  auto mur = MurHash();
  mur.put("Alice & Miriel");
  assert(mur.result == 0x295db5e7u);
}
