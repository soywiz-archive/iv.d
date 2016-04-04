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
module iv.stc.chacha;

import std.range;
import iv.stc.core;


public struct ChaCha20 {
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
    static assert(IVSize == 8);
    static if (hasLength!KR) assert(key.length == 16 || key.length == 32); else assert(!key.empty);
    static if (hasLength!IR) assert(iv.length == 0 || iv.length == 8 || iv.length == 12);
    ubyte[KeySize] kb = 0;
    ubyte[] keybuf;
    {
      size_t len = 0;
      while (!key.empty && len < kb.length) {
        kb.ptr[len++] = cast(ubyte)key.front;
        key.popFront;
      }
      if (len != 16 && len != 32) key.popFront; // this should throw exception
      keybuf = kb[0..len];
    }
    ubyte[12] ib = 0;
    ubyte[] ivbuf;
    {
      size_t len = 0;
      while (!iv.empty && len < ib.length) {
        ib.ptr[len++] = cast(ubyte)iv.front;
        iv.popFront;
      }
      if (len && len != IVSize) iv.popFront; // this should throw exception
      ivbuf = ib[0..len];
    }

    static uint U8TO32_LITTLE (const(ubyte)* n) nothrow @trusted @nogc {
      uint res = 0;
      res |= cast(uint)n[0];
      res |= cast(uint)n[1]<<8;
      res |= cast(uint)n[2]<<16;
      res |= cast(uint)n[3]<<24;
      return res;
    }

    // setup key
    state.ptr[4] = U8TO32_LITTLE(kb.ptr+0);
    state.ptr[5] = U8TO32_LITTLE(kb.ptr+4);
    state.ptr[6] = U8TO32_LITTLE(kb.ptr+8);
    state.ptr[7] = U8TO32_LITTLE(kb.ptr+12);
    uint ofs = 0;
    string constants;
    if (keybuf.length == 32) {
      /* recommended */
      ofs = 16;
      constants = sigma;
    } else {
      /* kbits == 128 */
      constants = tau;
    }
    state.ptr[8] = U8TO32_LITTLE(kb.ptr+ofs+0);
    state.ptr[9] = U8TO32_LITTLE(kb.ptr+ofs+4);
    state.ptr[10] = U8TO32_LITTLE(kb.ptr+ofs+8);
    state.ptr[11] = U8TO32_LITTLE(kb.ptr+ofs+12);
    state.ptr[0] = U8TO32_LITTLE(cast(immutable(ubyte*))constants.ptr+0);
    state.ptr[1] = U8TO32_LITTLE(cast(immutable(ubyte*))constants.ptr+4);
    state.ptr[2] = U8TO32_LITTLE(cast(immutable(ubyte*))constants.ptr+8);
    state.ptr[3] = U8TO32_LITTLE(cast(immutable(ubyte*))constants.ptr+12);

    // setup iv
    state.ptr[12] = 0;
    if (ivbuf.length == 12) {
      state.ptr[13] = U8TO32_LITTLE(ivbuf.ptr+0);
      state.ptr[14] = U8TO32_LITTLE(ivbuf.ptr+4);
      state.ptr[15] = U8TO32_LITTLE(ivbuf.ptr+8);
    } else {
      state.ptr[13] = 0;
      if (ivbuf.length >= 4) state.ptr[14] = U8TO32_LITTLE(ivbuf.ptr+0);
      if (ivbuf.length >= 8) state.ptr[15] = U8TO32_LITTLE(ivbuf.ptr+4);
    }
  }

  void clearState () nothrow @trusted @nogc {
    state[] = 0;
  }

  // output: 64 bytes
  // input: 16 uints
  static void nextState (ubyte[] output, const(uint)[] input) nothrow @trusted @nogc {
    assert(output.length == 64);
    assert(input.length == 16);

    enum QUARTERROUND(int a, int b, int c, int d) =
      "x.ptr["~a.stringof~"] = cast(uint)x.ptr["~a.stringof~"]+x.ptr["~b.stringof~"]; x.ptr["~d.stringof~"] = bitRotLeft(x.ptr["~d.stringof~"]^x.ptr["~a.stringof~"],16);\n"~
      "x.ptr["~c.stringof~"] = cast(uint)x.ptr["~c.stringof~"]+x.ptr["~d.stringof~"]; x.ptr["~b.stringof~"] = bitRotLeft(x.ptr["~b.stringof~"]^x.ptr["~c.stringof~"],12);\n"~
      "x.ptr["~a.stringof~"] = cast(uint)x.ptr["~a.stringof~"]+x.ptr["~b.stringof~"]; x.ptr["~d.stringof~"] = bitRotLeft(x.ptr["~d.stringof~"]^x.ptr["~a.stringof~"], 8);\n"~
      "x.ptr["~c.stringof~"] = cast(uint)x.ptr["~c.stringof~"]+x.ptr["~d.stringof~"]; x.ptr["~b.stringof~"] = bitRotLeft(x.ptr["~b.stringof~"]^x.ptr["~c.stringof~"], 7);\n";

    uint[16] x = input[0..16];

    foreach (immutable _; 0..10) {
      mixin(QUARTERROUND!( 0, 4, 8,12));
      mixin(QUARTERROUND!( 1, 5, 9,13));
      mixin(QUARTERROUND!( 2, 6,10,14));
      mixin(QUARTERROUND!( 3, 7,11,15));
      mixin(QUARTERROUND!( 0, 5,10,15));
      mixin(QUARTERROUND!( 1, 6,11,12));
      mixin(QUARTERROUND!( 2, 7, 8,13));
      mixin(QUARTERROUND!( 3, 4, 9,14));
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
    if (++state.ptr[12] == 0) ++state.ptr[13]; // stopping at 2^70 bytes per nonce is user's responsibility
  }

  public @property uint[16] getState () nothrow @trusted @nogc { return state[]; }

private:
  uint[16] state;
}
