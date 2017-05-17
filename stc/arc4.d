/*
 * ARC4 engine by unknown.
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
module iv.stc.arc4 /*is aliced*/;

import std.range;
import iv.alice;
import iv.stc.core;


public struct ARC4Engine(uint NSkipBytes) {
  // base stream cipher interface
  mixin StreamCipherCore;

public:
  // cipher parameters
  enum BlockSize = 256; // arbitrary number
  enum IVSize = 8; // in bytes
  enum KeySize = 32; // in bytes
  enum SupportIV = false;
  //
  enum SkipBytes = NSkipBytes;

private:
  void resetState(KR, IR) (KR key, IR iv) @trusted {
    static if (hasLength!KR) assert(key.length > 0); else assert(!key.empty);
    static if (hasLength!IR) assert(iv.length == 0); else assert(iv.empty);
    ubyte[256] kb = void;
    ubyte[] keybuf;
    {
      usize len = 0;
      while (!key.empty && len < kb.length) {
        kb.ptr[len++] = cast(ubyte)key.front;
        key.popFront;
      }
      keybuf = kb[0..len];
    }
    // setup key
    ubyte a, c;
    statex = 0;
    statey = 0;
    foreach (ubyte i; 0..256) statem.ptr[i] = i;
    c = 0;
    foreach (ubyte i; 0..256) {
      a = statem.ptr[i];
      c = (c+a+cast(ubyte)keybuf.ptr[i%keybuf.length])&0xff;
      statem.ptr[i] = statem.ptr[c];
      statem.ptr[c] = a;
    }
    // setup IV (how?)
    // discard first skipbytes bytes
    static if (SkipBytes > 0) {
      ubyte b;
      ubyte x = statex;
      ubyte y = statey;
      foreach (immutable i; 0..SkipBytes) {
        x = (x+1)&0xff;
        a = statem.ptr[x];
        y = (y+a)&0xff;
        statem.ptr[x] = b = statem.ptr[y];
        statem.ptr[y] = a;
      }
      statex = x;
      statey = y;
    }
  }

  void clearState () nothrow @trusted @nogc {
    statem[] = 0;
    statex = statey = 0;
  }

  void getBuf () nothrow @trusted @nogc {
    ubyte a, b;
    ubyte x = statex;
    ubyte y = statey;
    foreach (immutable i; 0..BlockSize) {
      x = (x+1)&0xff;
      a = statem.ptr[x];
      y = (y+a)&0xff;
      statem.ptr[x] = b = statem.ptr[y];
      statem.ptr[y] = a;
      buf.ptr[i] = statem.ptr[(a+b)&0xff];
    }
    statex = x;
    statey = y;
  }

private:
  ubyte[256] statem; // permutation table
  ubyte statex, statey; // permutation indicies
}


// default ARC4 engine
alias ARC4 = ARC4Engine!3072;
