/*
 * SipHash: a fast short-input PRF
 *
 * Example:
 * -----
 * // Create key
 * ubyte[16] key = cast(ubyte[])"To be|not to be!";
 * // Compute hash with key and arbitrary message
 * ulong  hashed = sipHash24Of(key, cast(ubyte[])"that is the question.");
 * assert(hashed == 17352353082512417190);
 * -----
 *
 * See_Also:
 *  https://www.131002.net/siphash/ -- SipHash: a fast short-input PRF
 *
 * Copyright: Copyright Masahiro Nakagawa 2012-.
 * License:   Boost License 1.0
 * Authors:   Masahiro Nakagawa
 *
 * modifications, CTFEcation, etc. by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 */
///WARNING: not conforming to hash API!
module iv.hash.siphash;
private:

/**
 * siphash template, which takes SipRound C and D parameters
 */
public template SipHashImpl(usize C, usize D) {
  /**
   * Computes SipHash hashes of arbitrary data.
   *
   * Params:
   *  key     = 16 byte key to hash
   *  message = an arbitrary message
   *
   * Returns:
   *  a 8 byte hash value.
   */
  ulong sipHashOf(TK, TM) (auto ref in TK[16] key, in TM[] message) pure nothrow @trusted @nogc
  if (TK.sizeof == 1 && TM.sizeof == 1)
  {
    return sipHashOf(SipHashU8to64LE(key.ptr), SipHashU8to64LE(key.ptr, SipHashBlockSize), message);
  }

  /// ditto
  ulong sipHashOf(TM) (in ulong k0, in ulong k1, in TM[] message) pure nothrow @trusted @nogc
  if (TM.sizeof == 1)
  {
    ulong v0 = k0^0x736f6d6570736575UL;
    ulong v1 = k1^0x646f72616e646f6dUL;
    ulong v2 = k0^0x6c7967656e657261UL;
    ulong v3 = k1^0x7465646279746573UL;

    usize index;
    usize blocks = message.length&~7;
    while (index < blocks) {
      immutable mi = SipHashU8to64LE(message.ptr, index);
      v3 ^= mi;
      foreach (immutable _; 0..C) mixin(SipRound);
      v0 ^= mi;
      index += SipHashBlockSize;
    }

    ulong tail = cast(ulong)(message.length&0xff)<<56;
    switch (message.length%SipHashBlockSize) {
      case 7: tail |= cast(ulong)message[index+6]<<48; goto case 6;
      case 6: tail |= cast(ulong)message[index+5]<<40; goto case 5;
      case 5: tail |= cast(ulong)message[index+4]<<32; goto case 4;
      case 4: tail |= cast(ulong)message[index+3]<<24; goto case 3;
      case 3: tail |= cast(ulong)message[index+2]<<16; goto case 2;
      case 2: tail |= cast(ulong)message[index+1]<< 8; goto case 1;
      case 1: tail |= cast(ulong)message[index+0]; break;
      default: break;
    }

    v3 ^= tail;
    foreach (immutable _; 0..C) mixin(SipRound);
    v0 ^= tail;

    v2 ^= 0xff;
    foreach (immutable _; 0..D) mixin(SipRound);

    return v0^v1^v2^v3;
  }
}

public alias SipHashImpl!(2, 4).sipHashOf sipHash24Of;
public alias SipHashImpl!(4, 8).sipHashOf sipHash48Of;


/**
 * SipHash object implements std.digest like API for supporting streaming update.
 *
 * Example:
 * -----
 * char[16] key = "To be|not to be!";
 * auto sh = SipHash!(2, 4)(key);
 *
 * sh.reset();
 * foreach (chunk; chunks(cast(ubyte[])"that is the question.", 2)) sh.put(chunk);
 * auto hashed = sh.finish();
 * -----
 */
public struct SipHash(usize C, usize D) {
private:
  immutable ulong k0, k1;
  ulong v0, v1, v2, v3;

  usize processedLength;
  ubyte[SipHashBlockSize] message; // actually, this is an accummulator; bits 0..2 of [$-1] is a counter

public:
pure nothrow @trusted @nogc:
  /// Constructs SipHash with 16 byte key.
  this(TK) (auto ref in TK[16] key) @nogc if (TK.sizeof == 1) {
    this(SipHashU8to64LE(key.ptr), SipHashU8to64LE(key.ptr, SipHashBlockSize));
  }

  /// Constructs SipHash with two 8 byte key numbers.
  this (in ulong key0, in ulong key1) { k0 = key0; k1 = key1; reset(); }

  /// Used to initialize the SipHash.
  void reset () {
    v0 = k0^0x736f6d6570736575UL;
    v1 = k1^0x646f72616e646f6dUL;
    v2 = k0^0x6c7967656e657261UL;
    v3 = k1^0x7465646279746573UL;
    processedLength = 0;
    message[$-1] = 0; // reset counter
  }

  /**
   * Use this to feed the digest with data.
   * Also implements the `OutputRange` interface for `ubyte` and `const(ubyte)[])`.
   */
  void put(T) (scope const(T)[] data...) if (T.sizeof == 1) {
    usize didx = 0;
    usize dlen = data.length;
    ubyte left = (SipHashBlockSize-message[$-1])%SipHashBlockSize;
    // complete incomplete block, if any
    if (left) {
      ubyte midx = message[$-1];
      if (left > dlen) {
        // no data to fill the block, keep accumulating
        while (dlen--) message[midx++] = cast(ubyte)(data[didx++]);
        // fix pointer
        assert(midx < SipHashBlockSize);
        message[$-1] = midx;
        return;
      } else {
        // enough data to fill the block, fill it
        dlen -= left;
        while (left--) message[midx++] = cast(ubyte)(data[didx++]);
        // update hash
        immutable mi = SipHashU8to64LE(message.ptr);
        v3 ^= mi;
        foreach (immutable _; 0..C) mixin(SipRound);
        v0 ^= mi;
        processedLength += SipHashBlockSize;
        // clear accummulator
        message[$-1] = 0;
      }
    }
    // accummulator is empty, process full blocks
    foreach (immutable _0; 0..dlen/SipHashBlockSize) {
      if (__ctfe) {
        foreach (immutable idx; 0..SipHashBlockSize) message[idx] = cast(ubyte)data[didx+idx];
      } else {
        message[] = (cast(const(ubyte)[])data)[didx..didx+SipHashBlockSize];
      }
      immutable mi = SipHashU8to64LE(message.ptr);
      v3 ^= mi;
      foreach (immutable _1; 0..C) mixin(SipRound);
      v0 ^= mi;
      didx += SipHashBlockSize;
      processedLength += SipHashBlockSize;
    }
    // check if we have some incomplete data
    if ((dlen %= SipHashBlockSize) != 0) {
      // accumulate it
      message[$-1] = cast(ubyte)dlen;
      if (__ctfe) {
        foreach (immutable idx; 0..dlen) message[idx] = cast(ubyte)data[didx+idx];
      } else {
        message[0..dlen] = (cast(const(ubyte)[])data)[didx..didx+dlen];
      }
    }
  }

  /**
   * Returns the finished SipHash hash as ubyte[8], not ulong.
   * This also calls `reset` to reset the internal state.
   */
  ubyte[8] resultUB(bool finishIt=false) () {
    import std.bitmanip : nativeToLittleEndian;
    return nativeToLittleEndian(result!finishIt);
  }

  /**
   * Returns the finished SipHash hash as ubyte[8], not ulong.
   * This also calls `reset` to reset the internal state.
   */
  //ubyte[8] finish () { return result!true(); }
  alias finish = resultUB!true;

  /**
   * Returns the finished SipHash hash as ubyte[8], not ulong.
   * This also calls `reset` to reset the internal state.
   */
  ulong result(bool finishIt=false) () {
    static if (!finishIt) {
      immutable sv0 = v0;
      immutable sv1 = v1;
      immutable sv2 = v2;
      immutable sv3 = v3;
    }

    // process accumulated data, if any
    ulong tail = cast(ulong)((processedLength+message[$-1])&0xff)<<56;
    switch (message[$-1]) {
      case 7: tail |= cast(ulong)message[6]<<48; goto case 6;
      case 6: tail |= cast(ulong)message[5]<<40; goto case 5;
      case 5: tail |= cast(ulong)message[4]<<32; goto case 4;
      case 4: tail |= cast(ulong)message[3]<<24; goto case 3;
      case 3: tail |= cast(ulong)message[2]<<16; goto case 2;
      case 2: tail |= cast(ulong)message[1]<<8; goto case 1;
      case 1: tail |= cast(ulong)message[0]; break;
      default: break;
    }

    v3 ^= tail;
    foreach (immutable _; 0..C) mixin(SipRound);
    v0 ^= tail;

    v2 ^= 0xff;
    foreach (immutable _; 0..D) mixin(SipRound);

    static if (!finishIt) {
      ulong res = v0^v1^v2^v3;
      v0 = sv0;
      v1 = sv1;
      v2 = sv2;
      v3 = sv3;
      return res;
    } else {
      return v0^v1^v2^v3;
    }
  }

  /// very clever hack
  static ulong opIndex(TK, TD) (auto ref in TK[16] key, in TD[] data)
  if (TK.sizeof == 1 && TD.sizeof == 1)
  {
    return SipHashImpl!(C, D).sipHashOf(SipHashU8to64LE(key.ptr), SipHashU8to64LE(key.ptr, SipHashBlockSize), data);
  }
}


ulong SipHashU8to64LE(T) (in T* ptr, in usize i=0) pure nothrow @trusted @nogc if (T.sizeof == 1) {
  if (__ctfe) {
    version(LittleEndian) {
      return
        cast(ulong)ptr[i+0]|
        ((cast(ulong)ptr[i+1])<<8)|
        ((cast(ulong)ptr[i+2])<<16)|
        ((cast(ulong)ptr[i+3])<<24)|
        ((cast(ulong)ptr[i+4])<<32)|
        ((cast(ulong)ptr[i+5])<<40)|
        ((cast(ulong)ptr[i+6])<<48)|
        ((cast(ulong)ptr[i+7])<<56);
    } else {
      return
        cast(ulong)ptr[i+7]|
        ((cast(ulong)ptr[i+6])<<8)|
        ((cast(ulong)ptr[i+5])<<16)|
        ((cast(ulong)ptr[i+4])<<24)|
        ((cast(ulong)ptr[i+3])<<32)|
        ((cast(ulong)ptr[i+2])<<40)|
        ((cast(ulong)ptr[i+1])<<48)|
        ((cast(ulong)ptr[i+0])<<56);
    }
  } else {
    return *cast(ulong*)(ptr+i);
  }
}

ulong sipHashROTL (in ulong u, in uint s) pure nothrow @trusted @nogc { pragma(inline, true); return (u<<s)|(u>>(64-s)); }

enum SipHashBlockSize = ulong.sizeof;

enum SipRound = q{
  v0 += v1;
  v1  = sipHashROTL(v1, 13);
  v1 ^= v0;
  v0  = sipHashROTL(v0, 32);

  v2 += v3;
  v3  = sipHashROTL(v3, 16);
  v3 ^= v2;

  v2 += v1;
  v1  = sipHashROTL(v1, 17);
  v1 ^= v2;
  v2  = sipHashROTL(v2, 32);

  v0 += v3;
  v3  = sipHashROTL(v3, 21);
  v3 ^= v0;
};


unittest {
  import std.conv : to;
  import std.range : chunks;
  import std.bitmanip : littleEndianToNative, nativeToLittleEndian;

  /*
    SipHash-2-4 output with
    key = 00 01 02 ...
    and
    message = (empty string)
    message = 00 (1 byte)
    message = 00 01 (2 bytes)
    message = 00 01 02 (3 bytes)
    ...
    message = 00 01 02 ... 3e (63 bytes)
  */
  static immutable ulong[64] testVectors = [
    0x726fdb47dd0e0e31UL, 0x74f839c593dc67fdUL, 0x0d6c8009d9a94f5aUL, 0x85676696d7fb7e2dUL,
    0xcf2794e0277187b7UL, 0x18765564cd99a68dUL, 0xcbc9466e58fee3ceUL, 0xab0200f58b01d137UL,
    0x93f5f5799a932462UL, 0x9e0082df0ba9e4b0UL, 0x7a5dbbc594ddb9f3UL, 0xf4b32f46226bada7UL,
    0x751e8fbc860ee5fbUL, 0x14ea5627c0843d90UL, 0xf723ca908e7af2eeUL, 0xa129ca6149be45e5UL,
    0x3f2acc7f57c29bdbUL, 0x699ae9f52cbe4794UL, 0x4bc1b3f0968dd39cUL, 0xbb6dc91da77961bdUL,
    0xbed65cf21aa2ee98UL, 0xd0f2cbb02e3b67c7UL, 0x93536795e3a33e88UL, 0xa80c038ccd5ccec8UL,
    0xb8ad50c6f649af94UL, 0xbce192de8a85b8eaUL, 0x17d835b85bbb15f3UL, 0x2f2e6163076bcfadUL,
    0xde4daaaca71dc9a5UL, 0xa6a2506687956571UL, 0xad87a3535c49ef28UL, 0x32d892fad841c342UL,
    0x7127512f72f27cceUL, 0xa7f32346f95978e3UL, 0x12e0b01abb051238UL, 0x15e034d40fa197aeUL,
    0x314dffbe0815a3b4UL, 0x027990f029623981UL, 0xcadcd4e59ef40c4dUL, 0x9abfd8766a33735cUL,
    0x0e3ea96b5304a7d0UL, 0xad0c42d6fc585992UL, 0x187306c89bc215a9UL, 0xd4a60abcf3792b95UL,
    0xf935451de4f21df2UL, 0xa9538f0419755787UL, 0xdb9acddff56ca510UL, 0xd06c98cd5c0975ebUL,
    0xe612a3cb9ecba951UL, 0xc766e62cfcadaf96UL, 0xee64435a9752fe72UL, 0xa192d576b245165aUL,
    0x0a8787bf8ecb74b2UL, 0x81b3e73d20b49b6fUL, 0x7fa8220ba3b2eceaUL, 0x245731c13ca42499UL,
    0xb78dbfaf3a8d83bdUL, 0xea1ad565322a1a0bUL, 0x60e61c23a3795013UL, 0x6606d7e446282b93UL,
    0x6ca4ecb15c5f91e1UL, 0x9f626da15c9625f3UL, 0xe51b38608ef25f57UL, 0x958a324ceb064572UL
  ];

  char[16] key;
  foreach (ubyte i; 0..16) key[i] = i;

  auto sh = SipHash!(2, 4)(key);
  ulong calcViaStreaming (ubyte[] message) {
    sh.reset();
    foreach (chunk; chunks(message, 3)) sh.put(chunk);
    return littleEndianToNative!ulong(sh.finish());
  }

  ubyte[] message;
  foreach (ubyte i; 0..64) {
    auto result = sipHash24Of(key, message);
    assert(result == testVectors[i], "test vector failed for "~to!string(i));
    assert(calcViaStreaming(message) == testVectors[i], "test vector failed for "~to!string(i)~" in streaming");
    message ~= i;
  }
  // wow, we can do CTFE!
  //pragma(msg, sipHash24Of("0123456789abcdef", "Alice & Miriel"));
  static assert(sipHash24Of("0123456789abcdef", "Alice & Miriel") == 12689084848626545050LU);
  static assert(SipHash!(2, 4)["0123456789abcdef", "Alice & Miriel"] == 12689084848626545050LU);
}
