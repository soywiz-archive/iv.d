/* coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
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
module iv.gxx.color /*is aliced*/;
private:

import arsd.color;

import iv.alice;
import iv.bclamp;


// ////////////////////////////////////////////////////////////////////////// //
// swaps 'R' and 'B' color components
public uint gxColor (in Color c) pure nothrow @safe @nogc {
  pragma(inline, true);
  return
    ((c.asUint&0xff)<<16)|
    (c.asUint&0xff_00ff00)|
    ((c.asUint>>16)&0xff);
}


public Color gxToColor (uint clr) pure nothrow @safe @nogc {
  pragma(inline, true);
  return Color((clr>>16)&0xff, (clr>>8)&0xff, clr&0xff, (clr>>24)&0xff);
}


// just swap 'R' and 'B' color components
public uint gxSwapRB (uint c) pure nothrow @safe @nogc {
  pragma(inline, true);
  return
    ((c&0xff)<<16)|
    (c&0xff_00ff00)|
    ((c>>16)&0xff);
}


// ////////////////////////////////////////////////////////////////////////// //
public bool gxIsTransparent (uint clr) pure nothrow @safe @nogc { pragma(inline, true); return ((clr&0xff000000) == 0xff000000); }
public bool gxIsSolid (uint clr) pure nothrow @safe @nogc { pragma(inline, true); return ((clr&0xff000000) == 0x00_000000); }

public enum gxTransparent = 0xff000000;


// ////////////////////////////////////////////////////////////////////////// //
private template isGoodRGBInt(T) {
  import std.traits : Unqual;
  alias TT = Unqual!T;
  enum isGoodRGBInt =
    is(TT == ubyte) ||
    is(TT == short) || is(TT == ushort) ||
    is(TT == int) || is(TT == uint) ||
    is(TT == long) || is(TT == ulong);
}


// ////////////////////////////////////////////////////////////////////////// //
public uint gxrgb(T0, T1, T2) (T0 r, T1 g, T2 b) pure nothrow @trusted @nogc if (isGoodRGBInt!T0 && isGoodRGBInt!T1 && isGoodRGBInt!T2) {
  pragma(inline, true);
  return (clampToByte(r)<<16)|(clampToByte(g)<<8)|clampToByte(b);
}


public template gxRGB(int r, int g, int b) {
  enum gxRGB = (clampToByte(r)<<16)|(clampToByte(g)<<8)|clampToByte(b);
}

public template gxRGBA(int r, int g, int b, int a) {
  enum gxRGBA = (clampToByte(a)<<24)|(clampToByte(r)<<16)|(clampToByte(g)<<8)|clampToByte(b);
}
