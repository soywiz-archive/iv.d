/*
 * Base template for stream ciphers.
 * Copyright (C) 2014 Ketmar Dark // Invisible Vector (ketmar@ketmar.no-ip.org)
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
 * Get a copy of the GNU GPL from <http://www.gnu.org/licenses/>.
 */
module iv.stc.core;

import std.range;

package(iv.stc) template isValidRE(R) { enum isValidRE = is(ElementEncodingType!R : ubyte); }
package(iv.stc) template isValidIR(R) { enum isValidIR = isInputRange!R && isValidRE!R; }
package(iv.stc) template isValidOR(R) { enum isValidOR = isOutputRange!(R, ubyte) || isOutputRange!(R, char); }


/// cipher parameters:
/// enum BlockSize = 16; // in bytes
/// enum IVSize = 8; // in bytes
/// enum KeySize = 16; // in bytes
/// enum SupportIV = true; // or false

mixin template StreamCipherCore() {
public:
  /**
   * Initialize ciper context and setup key.
   *
   * Params:
   *  key = key
   */
  this(R0) (R0 key) @trusted if (isValidIR!R0) { reset(key); }

  /**
   * Initialize ciper context and setup key.
   *
   * Params:
   *  key = key
   *  iv = initial vector
   */
  this(R0, R1) (R0 key, R1 iv) @trusted if (isValidIR!R0 && isValidIR!R1) { reset(key, iv); }

  ~this () nothrow @trusted @nogc { cleanup(); }

  /**
   * Reinitialize ciper context and setup key.
   *
   * Params:
   *  key = key
   */
  void reset(R0) (R0 key) @trusted if (isValidIR!R0) {
    clearBuf();
    ubyte[] iv;
    resetState(key, iv);
  }

  /**
   * Reinitialize ciper context and setup key.
   *
   * Params:
   *  key = key
   *  iv = initial vector
   */
  void reset(R0, R1) (R0 key, R1 iv) @trusted if (isValidIR!R0 && isValidIR!R1) {
    clearBuf();
    resetState(key, iv);
  }

  /**
   * Regenerate xor buffer if necessary. Regenerates only if some bytes
   * from buffer was already used (i.e. second and following calls to
   * flush() without any stream processing will have no effect if
   * 'force' flag is not true).
   *
   * Params:
   *  force = regenerate xor buffer even if it's not necessary
   *
   * Returns:
   *  nothing
   */
  void flush() (bool force=false) @trusted {
    if (bufpos != 0 || force) {
      getBuf();
      bufpos = 0;
    }
  }

  /**
   * Process byte stream. This function can be called continuously
   * to encrypt or decrypt byte stream (much like RC4).
   *
   * Params:
   *  output = output buffer, it's size must be at least the same as input bufer size
   *  input = input buffer
   *
   * Returns:
   *  nothing
   */
  void process(R0, R1) (R0 output, R1 input) @trusted if (isValidOR!R0 && isValidIR!R1) {
    while (!input.empty) {
      static if (isOutputRange!(R0, ubyte)) {
        output.put(cast(ubyte)(cast(ubyte)input.front^this.front));
      } else {
        output.put(cast(char)(cast(ubyte)input.front^this.front));
      }
      input.popFront;
      this.popFront;
    }
  }

  // let this thing be input range
  @property ubyte front() () @trusted {
    if (bufpos >= BlockSize) {
      getBuf();
      bufpos = 0;
    }
    return buf.ptr[bufpos];
  }

  void popFront() () @trusted {
    if (bufpos >= BlockSize) {
      getBuf();
      bufpos = 0;
    }
    ++bufpos;
  }

  /// make snapshot
  @property typeof(this) save() () @trusted {
    return this;
  }

  /**
   * Always $(D false) (ciphers are infinite ranges).
   */
  enum bool empty = false;

  /**
   * Clean state, so there will be no cipher-related bytes in memory.
   */
  void cleanup() () @trusted {
    clearBuf();
    clearState();
  }

private:
  static uint bitRotLeft (uint v, uint n) pure nothrow @safe @nogc { pragma(inline, true); return (v<<n)|(v>>(32-n)); }
  static uint bitRotRight (uint v, uint n) pure nothrow @safe @nogc { pragma(inline, true); return (v<<(32-n))|(v>>n); }

  void clearBuf () nothrow @trusted @nogc {
    buf[] = 0;
    bufpos = BlockSize;
  }

  // this should generate new 'buf'
  //void getBuf () nothrow @trusted;

  // this should clear state
  //void clearState () nothrow @trusted;

  // this should reset cipher state
  // must understand empty iv
  // note that there is no need to check if R0 and R1 are
  // input ranges with correct element types
  //@trusted void resetState(R0, R1) (R0 key, R1 iv)

private:
  ubyte[BlockSize] buf;
  size_t bufpos;
}


/**
 * Compare two ranges in constant time.
 * Ranges must be of the same length.
 */
private import std.range : isInputRange, ElementEncodingType;
public bool cryptoEqu(R0, R1) (R0 r0, R1 r1) @trusted
if (isInputRange!R0 && isInputRange!R1 && is(ElementEncodingType!R0 == ElementEncodingType!R1) && is(ElementEncodingType!R0 : ubyte))
{
  uint d = 0;
  while (!r0.empty && !r1.empty) {
    d |= r0.front^r1.front;
    r0.popFront;
    r1.popFront;
  }
  // just in case
  if (!r0.empty || !r1.empty) d |= 0xff;
  while (!r0.empty) r0.popFront;
  while (!r1.empty) r1.popFront;
  return (1&((d-1)>>8)) != 0;
}


unittest {
  import std.stdio;
  ubyte[] a = [1,2,3,4];
  ubyte[] b = [1,2,3,5];
  assert(!cryptoEqu(a, b));
  assert(!cryptoEqu(b, a));
  assert(cryptoEqu(a, a));
  assert(cryptoEqu(b, b));
  assert(a == [1,2,3,4]);
  assert(b == [1,2,3,5]);
}
