/*
 * Salsa20 engine by D. J. Bernstein.
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
module iv.stc.salsa;

import std.range;
import iv.stc.core;


public struct Salsa20 {
  // base stream cipher interface
  mixin StreamCipherCore;

public:
  // cipher parameters
  enum BlockSize = 64;
  enum IVSize = 8; // in bytes
  enum KeySize = 32; // in bytes
  enum SupportIV = true;

private:
  enum sigma = "expand 32-byte k";
  enum tau = "expand 16-byte k";

private:
  void resetState(KR, IR) (KR key, IR iv) @trusted {
    static if (hasLength!KR) assert(key.length == 16 || key.length == 32); else assert(!key.empty);
    static if (hasLength!IR) assert(iv.length == 0 || iv.length == 8);
    static if (isRandomAccessRange!KR && hasLength!KR) {
      alias keybuf = key;
    } else {
      ubyte[KeySize] kb = void;
      size_t len = 0;
      while (!key.empty && len < kb.length) {
        kb.ptr[len++] = cast(ubyte)key.front;
        key.popFront;
      }
      if (len != 16 && len != 32) key.popFront; // this should throw exception
      ubyte[] keybuf = kb[0..len];
    }
    static if (isRandomAccessRange!IR && hasLength!IR) {
      alias ivbuf = iv;
    } else {
      ubyte[IVSize] ib = void;
      size_t len = 0;
      while (!iv.empty && len < ib.length) {
        ib.ptr[len++] = cast(ubyte)iv.front;
        iv.popFront;
      }
      if (len && len != IVSize) iv.popFront; // this should throw exception
      ubyte[] ivbuf = ib[0..len];
    }
    // setup key
    uint offset, n;
    string constants;
    if (keybuf.length == 32) {
      constants = sigma;
      offset = 16;
    } else {
      offset = 0;
      constants = tau;
    }
    foreach (immutable i; 0..4) {
      n = cast(ubyte)keybuf.ptr[i*4+3];
      n = (n<<8)|cast(ubyte)keybuf.ptr[i*4+2];
      n = (n<<8)|cast(ubyte)keybuf.ptr[i*4+1];
      n = (n<<8)|cast(ubyte)keybuf.ptr[i*4];
      state.ptr[i+1] = n;
      n = cast(ubyte)keybuf.ptr[offset+i*4+3];
      n = (n<<8)|cast(ubyte)keybuf.ptr[offset+i*4+2];
      n = (n<<8)|cast(ubyte)keybuf.ptr[offset+i*4+1];
      n = (n<<8)|cast(ubyte)keybuf.ptr[offset+i*4];
      state.ptr[i+11] = n;
      n = cast(ubyte)constants.ptr[i*4+3];
      n = (n<<8)|cast(ubyte)constants.ptr[i*4+2];
      n = (n<<8)|cast(ubyte)constants.ptr[i*4+1];
      n = (n<<8)|cast(ubyte)constants.ptr[i*4];
      state.ptr[i*5] = n;
      // setup IV
      if (ivbuf.length >= i*4+4) {
        n = cast(ubyte)ivbuf[i*4+3];
        n = (n<<8)|cast(ubyte)ivbuf[i*4+2];
        n = (n<<8)|cast(ubyte)ivbuf[i*4+1];
        n = (n<<8)|cast(ubyte)ivbuf[i*4];
      } else {
        n = 0;
      }
      state.ptr[i+6] = n;
    }
  }

  void cleanState () nothrow @trusted @nogc {
    state[] = 0;
  }

  // output: 64 bytes
  // input: 16 uints
  static void nextState (ubyte[] output, const(uint)[] input) nothrow @trusted @nogc {
    assert(output.length == 64);
    assert(input.length == 16);
    uint[16] x = input[0..16];
    foreach (immutable i; 0..10) {
      x.ptr[ 4] ^= bitRotLeft(x.ptr[ 0]+x.ptr[12], 7);
      x.ptr[ 8] ^= bitRotLeft(x.ptr[ 4]+x.ptr[ 0], 9);
      x.ptr[12] ^= bitRotLeft(x.ptr[ 8]+x.ptr[ 4],13);
      x.ptr[ 0] ^= bitRotLeft(x.ptr[12]+x.ptr[ 8],18);
      x.ptr[ 9] ^= bitRotLeft(x.ptr[ 5]+x.ptr[ 1], 7);
      x.ptr[13] ^= bitRotLeft(x.ptr[ 9]+x.ptr[ 5], 9);
      x.ptr[ 1] ^= bitRotLeft(x.ptr[13]+x.ptr[ 9],13);
      x.ptr[ 5] ^= bitRotLeft(x.ptr[ 1]+x.ptr[13],18);
      x.ptr[14] ^= bitRotLeft(x.ptr[10]+x.ptr[ 6], 7);
      x.ptr[ 2] ^= bitRotLeft(x.ptr[14]+x.ptr[10], 9);
      x.ptr[ 6] ^= bitRotLeft(x.ptr[ 2]+x.ptr[14],13);
      x.ptr[10] ^= bitRotLeft(x.ptr[ 6]+x.ptr[ 2],18);
      x.ptr[ 3] ^= bitRotLeft(x.ptr[15]+x.ptr[11], 7);
      x.ptr[ 7] ^= bitRotLeft(x.ptr[ 3]+x.ptr[15], 9);
      x.ptr[11] ^= bitRotLeft(x.ptr[ 7]+x.ptr[ 3],13);
      x.ptr[15] ^= bitRotLeft(x.ptr[11]+x.ptr[ 7],18);
      x.ptr[ 1] ^= bitRotLeft(x.ptr[ 0]+x.ptr[ 3], 7);
      x.ptr[ 2] ^= bitRotLeft(x.ptr[ 1]+x.ptr[ 0], 9);
      x.ptr[ 3] ^= bitRotLeft(x.ptr[ 2]+x.ptr[ 1],13);
      x.ptr[ 0] ^= bitRotLeft(x.ptr[ 3]+x.ptr[ 2],18);
      x.ptr[ 6] ^= bitRotLeft(x.ptr[ 5]+x.ptr[ 4], 7);
      x.ptr[ 7] ^= bitRotLeft(x.ptr[ 6]+x.ptr[ 5], 9);
      x.ptr[ 4] ^= bitRotLeft(x.ptr[ 7]+x.ptr[ 6],13);
      x.ptr[ 5] ^= bitRotLeft(x.ptr[ 4]+x.ptr[ 7],18);
      x.ptr[11] ^= bitRotLeft(x.ptr[10]+x.ptr[ 9], 7);
      x.ptr[ 8] ^= bitRotLeft(x.ptr[11]+x.ptr[10], 9);
      x.ptr[ 9] ^= bitRotLeft(x.ptr[ 8]+x.ptr[11],13);
      x.ptr[10] ^= bitRotLeft(x.ptr[ 9]+x.ptr[ 8],18);
      x.ptr[12] ^= bitRotLeft(x.ptr[15]+x.ptr[14], 7);
      x.ptr[13] ^= bitRotLeft(x.ptr[12]+x.ptr[15], 9);
      x.ptr[14] ^= bitRotLeft(x.ptr[13]+x.ptr[12],13);
      x.ptr[15] ^= bitRotLeft(x.ptr[14]+x.ptr[13],18);
    }
    foreach (immutable i, ref n; x) n += input.ptr[i];
    foreach (immutable i, uint n; x) {
      output.ptr[i*4] = n&0xff;
      output.ptr[i*4+1] = (n>>8)&0xff;
      output.ptr[i*4+2] = (n>>16)&0xff;
      output.ptr[i*4+3] = (n>>24)&0xff;
    }
  }

  void getBuf () nothrow @trusted @nogc {
    nextState(buf, state);
    if (++state.ptr[8] == 0) ++state.ptr[9]; // stopping at 2^70 bytes per nonce is user's responsibility
  }

private:
  uint[16] state;
}


unittest {
  import std.stdio;
  import iv.stc.testing;
  writeln("testing Salsa20...");
  processTVFile!Salsa20(import("salsa-verified.test-vectors"));
  writeln(count, " tests passed.");
}
