/*
 * Stream cipher testing support.
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
module iv.stc.testing /*is aliced*/;

import iv.alice;
import std.stdio;
import std.range;


public uint count = 0;

public void test(alias T) (const(ubyte)[] key, const(ubyte)[] iv, const(ubyte)[] output, bool big=false) {
  ubyte[] res = new ubyte[!big ? 512 : 131072];
  auto ctx = T(key, iv);
  ctx.process(res, res);
  if (!big) {
    assert(res[0..64] == output[0..64]);
    assert(res[192..256] == output[64..128]);
    assert(res[256..320] == output[128..192]);
    assert(res[448..512] == output[192..256]);
  } else {
    assert(res[0..64] == output[0..64]);
    assert(res[65472..65536] == output[64..128]);
    assert(res[65536..65600] == output[128..192]);
    assert(res[131008..131072] == output[192..256]);
  }
  ++count;
}


public void processTVFile(alias T) (string tvs) {
  import std.algorithm;
  import std.string;
  ubyte[32] key = void;
  ubyte[32] iv = void;
  ubyte[256] output = void;

  void skipSpaces () {
    usize pos = 0;
    while (pos < tvs.length && (tvs[pos] == ' ' || tvs[pos] == '\t' || tvs[pos] == '\n' || tvs[pos] == '\r')) ++pos;
    tvs = tvs[pos..$];
  }

  usize h2x (ubyte[] arr, int len=16) {
    usize pos = 0;
    while (tvs.length) {
      if (tvs[0] < '0' || (tvs[0] > '9' && tvs[0] < 'A') || tvs[0] > 'F') break;
      uint n0 = tvs[0]-'0';
      if (n0 > 9) n0 -= 'A'-'9'-1;
      uint n1 = tvs[1]-'0';
      if (n1 > 9) n1 -= 'A'-'9'-1;
      arr[pos++] = cast(ubyte)(n0*16+n1);
      tvs = tvs[2..$];
      if (len != 666) {
        --len;
        assert(len >= 0);
      }
    }
    assert(len == 666 || len == 0);
    skipSpaces();
    return pos;
  }

  static immutable string[3][2] ranges = [
    ["stream[192..255] = ",
     "stream[256..319] = ",
     "stream[448..511] = "],
    ["stream[65472..65535] = ",
     "stream[65536..65599] = ",
     "stream[131008..131071] = "]
  ];

  auto xpos = tvs.indexOf("\nSet ");
  while (xpos >= 0) {
    usize keylen, ivlen;
    int rng = 0;
    // key
    xpos = tvs.indexOf("key = ");
    tvs = tvs[xpos+6..$];
    keylen = h2x(key, 666);
    if (!tvs.startsWith("IV = ")) {
      // 256-bit key
      keylen += h2x(key[keylen..$], 666);
    }
    // iv
    assert(tvs.skipOver("IV = "));
    ivlen = h2x(iv, 666);
    // first stream part
    assert(tvs.skipOver("stream[0..63] = "));
    h2x(output[0*16..$]);
    h2x(output[1*16..$]);
    h2x(output[2*16..$]);
    h2x(output[3*16..$]);
    rng = (tvs.startsWith(ranges[0][0]) ? 0 : 1);
    for (usize f = 1; f < 4; ++f) {
      assert(tvs.skipOver(ranges[rng][f-1]));
      h2x(output[64*f+0*16..$]);
      h2x(output[64*f+1*16..$]);
      h2x(output[64*f+2*16..$]);
      h2x(output[64*f+3*16..$]);
    }
    test!T(key[0..keylen], iv[0..ivlen], output, (rng > 0));
    xpos = tvs.indexOf("\nSet ");
  }
}
