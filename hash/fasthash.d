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
module iv.hash.fasthash;


/**
 * fasthash64 - 64-bit implementation of fasthash
 *
 * Params:
 *   buf =  data buffer
 *   seed = the seed
 */
ulong fasthash64(T) (const(T)[] buf, ulong seed=0) @trusted nothrow @nogc
if (T.sizeof == 1)
{
  enum m = 0x880355f21e6d1965UL;
  ulong h = seed^(buf.length*m);

  ulong t;
  foreach (immutable _; 0..buf.length/8) {
    if (__ctfe) {
      t =
        cast(ulong)buf[0]|
        (cast(ulong)buf[1]<<8)|
        (cast(ulong)buf[2]<<16)|
        (cast(ulong)buf[3]<<24)|
        (cast(ulong)buf[4]<<32)|
        (cast(ulong)buf[5]<<40)|
        (cast(ulong)buf[6]<<48)|
        (cast(ulong)buf[7]<<56);
    } else {
      t = *cast(ulong*)buf.ptr;
    }
    buf = buf[8..$];
    t ^= t>>23;
    t *= 0x2127599bf4325c37UL;
    t ^= t>>47;
    h ^= t;
    h *= m;
  }

  t = 0;
  switch (buf.length&7) {
    case 7: t ^= cast(ulong)buf[6]<<48; goto case 6;
    case 6: t ^= cast(ulong)buf[5]<<40; goto case 5;
    case 5: t ^= cast(ulong)buf[4]<<32; goto case 4;
    case 4: t ^= cast(ulong)buf[3]<<24; goto case 3;
    case 3: t ^= cast(ulong)buf[2]<<16; goto case 2;
    case 2: t ^= cast(ulong)buf[1]<<8; goto case 1;
    case 1: t ^= cast(ulong)buf[0]; goto default;
    default:
      t ^= t>>23;
      t *= 0x2127599bf4325c37UL;
      t ^= t>>47;
      h ^= t;
      h *= m;
      break;
  }

  h ^= h>>23;
  h *= 0x2127599bf4325c37UL;
  h ^= h>>47;
  return h;
}

ulong fasthash64(T) (const(T)[] buf, uint seed=0) @trusted nothrow @nogc if (T.sizeof > 1) {
  return fasthash64(cast(const(ubyte)[])buf, seed);
}


uint fasthash32(T) (const(T)[] buf, uint seed=0) @trusted nothrow @nogc
if (T.sizeof == 1)
{
  // the following trick converts the 64-bit hashcode to Fermat
  // residue, which shall retain information from both the higher
  // and lower parts of hashcode.
  ulong h = fasthash64(buf, seed);
  return cast(uint)(h-(h>>32));
}

ulong fasthash32(T) (const(T)[] buf, uint seed=0) @trusted nothrow @nogc if (T.sizeof > 1) {
  return fasthash32(cast(const(ubyte)[])buf, seed);
}


unittest {
  static assert(fasthash32("Alice & Miriel"), 0xed6586a5);
  static assert(fasthash32("Alice & Miriel"), 0xa8ed28359652aedaUL);
}
