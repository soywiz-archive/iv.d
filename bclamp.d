/* Invisible Vector Library
 * coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * Understanding is not required. Only obedience.
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
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */
// just `clampToByte()`, so i can easily find and copypaste it
module iv.bclamp is aliced;


// this is actually branch-less for ints on x86, and even for longs on x86_64
ubyte clampToByte(T) (T n) pure nothrow @safe @nogc if (__traits(isIntegral, T)) {
  pragma(inline, true);
  static if (T.sizeof == 2 || T.sizeof == 4) {
    static if (__traits(isUnsigned, T)) {
      return cast(ubyte)(n&0xff|(255-((-cast(int)(n < 256))>>24)));
    } else {
      n &= -cast(int)(n >= 0);
      return cast(ubyte)(n|((255-cast(int)n)>>31));
    }
  } else static if (T.sizeof == 1) {
    static assert(__traits(isUnsigned, T), "clampToByte: signed byte? no, really?");
    return cast(ubyte)n;
  } else static if (T.sizeof == 8) {
    static if (__traits(isUnsigned, T)) {
      return cast(ubyte)(n&0xff|(255-((-cast(long)(n < 256))>>56)));
    } else {
      n &= -cast(long)(n >= 0);
      return cast(ubyte)(n|((255-cast(long)n)>>63));
    }
  } else {
    static assert(false, "clampToByte: integer too big");
  }
}


unittest {
  static assert(clampToByte(666) == 255);
  static assert(clampToByte(-666) == 0);
  static assert(clampToByte(250) == 250);
  static assert(clampToByte(-250) == 0);
  static assert(clampToByte(cast(uint)250) == 250);
  static assert(clampToByte(cast(uint)1000) == 255);
  static assert(clampToByte(cast(uint)0xfffffff0) == 255);
  static assert(clampToByte(false) == 0);
  static assert(clampToByte(true) == 1);
  static assert(clampToByte('A') == 65);

  static assert(clampToByte(666L) == 255);
  static assert(clampToByte(-666L) == 0);
  static assert(clampToByte(250L) == 250);
  static assert(clampToByte(-250L) == 0);
  static assert(clampToByte(-666UL) == 255);
}
