/*
 * Rabbit engine by Cryptico A/S.
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
/****************************************************************************************************/
/* Developed by Cryptico A/S.                                                                       */
/*                                                                                                  */
/* "Rabbit has been released into the public domain and may be used freely for any purpose."        */
/* http://web.archive.org/web/20121114021058/http://www.ecrypt.eu.org/stream/phorum/read.php?1,1244 */
/*                                                                                                  */
/* Rabbit claims 128-bit security against attackers whose target is one specific key. If, however,  */
/* the attacker targets a large number of keys at once and does not really care which one he breaks,*/
/* then the small IV size results in a reduced security level of 96 bit. This is due to generic TMD */
/* trade-off attacks.                                                                               */
/****************************************************************************************************/
module iv.stc.rabbit /*is aliced*/;

import std.range;
import iv.alice;
import iv.stc.core;


public struct Rabbit {
  // base stream cipher interface
  mixin StreamCipherCore;

public:
  // cipher parameters
  enum BlockSize = 16;
  enum IVSize = 8; // in bytes
  enum KeySize = 16; // in bytes
  enum SupportIV = true;

private:
  void resetState(KR, IR) (KR key, IR iv) @trusted {
    static if (hasLength!KR) assert(key.length == 16); else assert(!key.empty);
    static if (hasLength!IR) assert(iv.length == 0 || iv.length == 8);
    ubyte[KeySize] kb = void;
    {
      usize len = 0;
      while (!key.empty && len < kb.length) {
        kb.ptr[len++] = cast(ubyte)key.front;
        key.popFront;
      }
      if (len != KeySize) key.popFront; // this should throw exception
    }
    ubyte[] keybuf = kb[0..KeySize];
    ubyte[IVSize] ib = void;
    ubyte[] ivbuf;
    {
      usize len = 0;
      while (!iv.empty && len < ib.length) {
        ib.ptr[len++] = cast(ubyte)iv.front;
        iv.popFront;
      }
      if (len && len != IVSize) iv.popFront; // this should throw exception
      ivbuf = ib[0..IVSize];
    }
    uint k0, k1, k2, k3;
    // generate four subkeys
    k0 = cast(ubyte)keybuf.ptr[3];
    k0 = (k0<<8)|cast(ubyte)keybuf.ptr[2];
    k0 = (k0<<8)|cast(ubyte)keybuf.ptr[1];
    k0 = (k0<<8)|cast(ubyte)keybuf.ptr[0];
    // second
    k1 = cast(ubyte)keybuf.ptr[7];
    k1 = (k1<<8)|cast(ubyte)keybuf.ptr[6];
    k1 = (k1<<8)|cast(ubyte)keybuf.ptr[5];
    k1 = (k1<<8)|cast(ubyte)keybuf.ptr[4];
    // third
    k2 = cast(ubyte)keybuf.ptr[11];
    k2 = (k2<<8)|cast(ubyte)keybuf.ptr[10];
    k2 = (k2<<8)|cast(ubyte)keybuf.ptr[9];
    k2 = (k2<<8)|cast(ubyte)keybuf.ptr[8];
    // fourth
    k3 = cast(ubyte)keybuf.ptr[15];
    k3 = (k3<<8)|cast(ubyte)keybuf.ptr[14];
    k3 = (k3<<8)|cast(ubyte)keybuf.ptr[13];
    k3 = (k3<<8)|cast(ubyte)keybuf.ptr[12];
    // generate initial state variables
    statex.ptr[0] = k0;
    statex.ptr[2] = k1;
    statex.ptr[4] = k2;
    statex.ptr[6] = k3;
    statex.ptr[1] = (k3<<16)|(k2>>16);
    statex.ptr[3] = (k0<<16)|(k3>>16);
    statex.ptr[5] = (k1<<16)|(k0>>16);
    statex.ptr[7] = (k2<<16)|(k1>>16);
    // generate initial counter values
    statec.ptr[0] = bitRotLeft(k2, 16);
    statec.ptr[2] = bitRotLeft(k3, 16);
    statec.ptr[4] = bitRotLeft(k0, 16);
    statec.ptr[6] = bitRotLeft(k1, 16);
    statec.ptr[1] = (k0&0xFFFF0000U)|(k1&0xFFFF);
    statec.ptr[3] = (k1&0xFFFF0000U)|(k2&0xFFFF);
    statec.ptr[5] = (k2&0xFFFF0000U)|(k3&0xFFFF);
    statec.ptr[7] = (k3&0xFFFF0000U)|(k0&0xFFFF);
    // clear carry bit
    statecarry = 0;
    // iterate the system four times
    foreach (immutable i; 0..4) nextState();
    // modify the counters
    foreach (immutable i; 0..8) statec.ptr[i] ^= statex.ptr[(i+4)&0x7];
    if (ivbuf.length) {
      uint i0, i1, i2, i3;
      // generate four subvectors
      i0 = cast(ubyte)ivbuf.ptr[3];
      i0 = (i0<<8)|cast(ubyte)ivbuf.ptr[2];
      i0 = (i0<<8)|cast(ubyte)ivbuf.ptr[1];
      i0 = (i0<<8)|cast(ubyte)ivbuf.ptr[0];
      // third
      i2 = cast(ubyte)ivbuf.ptr[7];
      i2 = (i2<<8)|cast(ubyte)ivbuf.ptr[6];
      i2 = (i2<<8)|cast(ubyte)ivbuf.ptr[5];
      i2 = (i2<<8)|cast(ubyte)ivbuf.ptr[4];
      // second
      i1 = (i0>>16)|(i2&0xFFFF0000U);
      // fourth
      i3 = (i2<<16)|(i0&0x0000FFFFU);
      // modify counter values
      statec.ptr[0] ^= i0;
      statec.ptr[1] ^= i1;
      statec.ptr[2] ^= i2;
      statec.ptr[3] ^= i3;
      statec.ptr[4] ^= i0;
      statec.ptr[5] ^= i1;
      statec.ptr[6] ^= i2;
      statec.ptr[7] ^= i3;
      // iterate the system four times
      foreach (immutable i; 0..4) nextState();
    }
  }

  void clearState () nothrow @trusted @nogc {
    statex[] = 0;
    statec[] = 0;
    statecarry = 0;
  }

  /* Square a 32-bit unsigned integer to obtain the 64-bit result and return */
  /* the upper 32 bits XOR the lower 32 bits */
  static uint gfunc (uint x) nothrow @trusted @nogc {
    pragma(inline, true);
    uint a, b, h, l;
    // construct high and low argument for squaring
    a = x&0xFFFF;
    b = x>>16;
    // calculate high and low result of squaring
    h = ((((a*a)>>17)+(a*b))>>15)+b*b;
    l = x*x;
    // return high XOR low
    return h^l;
  }

  /* Calculate the next internal state */
  void nextState () nothrow @trusted @nogc {
    uint[8] g = void, c_old = void;
    // save old counter values
    c_old[0..8] = statec.ptr[0..8];
    // calculate new counter values
    statec.ptr[0] = statec.ptr[0]+0x4D34D34DU+statecarry;
    statec.ptr[1] = statec.ptr[1]+0xD34D34D3U+(statec.ptr[0]<c_old[0]);
    statec.ptr[2] = statec.ptr[2]+0x34D34D34U+(statec.ptr[1]<c_old[1]);
    statec.ptr[3] = statec.ptr[3]+0x4D34D34DU+(statec.ptr[2]<c_old[2]);
    statec.ptr[4] = statec.ptr[4]+0xD34D34D3U+(statec.ptr[3]<c_old[3]);
    statec.ptr[5] = statec.ptr[5]+0x34D34D34U+(statec.ptr[4]<c_old[4]);
    statec.ptr[6] = statec.ptr[6]+0x4D34D34DU+(statec.ptr[5]<c_old[5]);
    statec.ptr[7] = statec.ptr[7]+0xD34D34D3U+(statec.ptr[6]<c_old[6]);
    statecarry = (statec.ptr[7] < c_old[7]);
    // calculate the g-values
    foreach (immutable i, ref n; g) n = gfunc(statex.ptr[i]+statec.ptr[i]);
    // calculate new state values
    statex.ptr[0] = g.ptr[0]+bitRotLeft(g.ptr[7],16)+bitRotLeft(g.ptr[6], 16);
    statex.ptr[1] = g.ptr[1]+bitRotLeft(g.ptr[0], 8)+g.ptr[7];
    statex.ptr[2] = g.ptr[2]+bitRotLeft(g.ptr[1],16)+bitRotLeft(g.ptr[0], 16);
    statex.ptr[3] = g.ptr[3]+bitRotLeft(g.ptr[2], 8)+g.ptr[1];
    statex.ptr[4] = g.ptr[4]+bitRotLeft(g.ptr[3],16)+bitRotLeft(g.ptr[2], 16);
    statex.ptr[5] = g.ptr[5]+bitRotLeft(g.ptr[4], 8)+g.ptr[3];
    statex.ptr[6] = g.ptr[6]+bitRotLeft(g.ptr[5],16)+bitRotLeft(g.ptr[4], 16);
    statex.ptr[7] = g.ptr[7]+bitRotLeft(g.ptr[6], 8)+g.ptr[5];
  }

  /* Generate buffer to xor later */
  void getBuf () nothrow @trusted @nogc {
    void putToBuf (usize pos, uint n) nothrow @trusted @nogc {
      buf.ptr[pos+0] = n&0xff;
      buf.ptr[pos+1] = (n>>8)&0xff;
      buf.ptr[pos+2] = (n>>16)&0xff;
      buf.ptr[pos+3] = (n>>24)&0xff;
    }
    // iterate the system
    nextState();
    // generate 16 bytes of pseudo-random data
    putToBuf( 0, statex.ptr[0]^(statex.ptr[5]>>16)^(statex.ptr[3]<<16));
    putToBuf( 4, statex.ptr[2]^(statex.ptr[7]>>16)^(statex.ptr[5]<<16));
    putToBuf( 8, statex.ptr[4]^(statex.ptr[1]>>16)^(statex.ptr[7]<<16));
    putToBuf(12, statex.ptr[6]^(statex.ptr[3]>>16)^(statex.ptr[1]<<16));
  }

private:
  uint[8] statex;
  uint[8] statec;
  uint statecarry;
}


unittest {
  import std.stdio;
  auto rb0 = Rabbit("thisiscipherkey!");
  auto rb1 = Rabbit("thisiscipherkey!");
  string s0 = "test";
  string s1 = "text";
  ubyte[] o0, o1;
  o0.length = 8;
  o1.length = 8;
  rb0.process(o0[0..4], s0);
  rb0.process(o0[4..8], s1);
  rb1.process(o1, s0~s1);
  assert(o0 == o1);
}


unittest {
  import std.stdio;
  import iv.stc.testing;
  writeln("testing Rabbit...");
  processTVFile!Rabbit(import("rabbit-verified.test-vectors"));
  writeln(count, " tests passed.");
}
