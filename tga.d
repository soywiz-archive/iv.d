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
// severely outdated Targa reader and writer
module iv.tga is aliced;

final class Targa {
  private import iv.stream;

  private static align(1) struct TGAHeader {
  align(1):
    ubyte idlen; // after header
    ubyte cmaptype;
    ubyte imgtype; // should be 2
    ushort cmapfirst;
    ushort cmapcount;
    ubyte cmapesize; // entry size, in bits
    ushort xorig;
    ushort yorig;
    ushort width;
    ushort height;
    ubyte bpp; // in bits
    ubyte flags; // bit 5 set: top-down; bits 6-7 should be 0
  }
  static assert(TGAHeader.sizeof == 18);

  static align(1) struct Color {
    align(1) union {
      align(1) struct {
        align(1):
        ubyte b, g, r, a;
      }
      uint val;
    }
    this (ubyte ar, ubyte ag, ubyte ab, ubyte aa=0) {
      b = ab;
      r = ar;
      g = ag;
      a = aa;
    }
  }
  static assert(Color.sizeof == 4);

  // first two is width and height
  Color* image;
  private uint mWidth, mHeight;

  void load (string fname) @trusted {
    import std.stdio : File;
    //writeln("loading ", fname, "...");
    load(File(fname, "r"));
  }

  void load(ST) (auto ref ST fl) @trusted if (isReadableStream!ST) {
    scope(failure) clear();
    TGAHeader hdr = void;
    hdr.idlen = fl.readNum!ubyte();
    hdr.cmaptype = fl.readNum!ubyte();
    if (hdr.cmaptype != 0) throw new Exception("TGA with colormap");
    hdr.imgtype = fl.readNum!ubyte();
    if (hdr.imgtype != 2) throw new Exception("invalid TGA image type");
    hdr.cmapfirst = fl.readNum!ushort();
    hdr.cmapcount = fl.readNum!ushort();
    hdr.cmapesize = fl.readNum!ubyte();
    hdr.xorig = fl.readNum!ushort();
    hdr.yorig = fl.readNum!ushort();
    hdr.width = fl.readNum!ushort();
    if (hdr.width < 1 || hdr.width > 32768) throw new Exception("invalid TGA width");
    hdr.height = fl.readNum!ushort();
    if (hdr.height < 1 || hdr.height > 32768) throw new Exception("invalid TGA height");
    hdr.bpp = fl.readNum!ubyte();
    if (hdr.bpp != 24 && hdr.bpp != 32) throw new Exception("invalid TGA BPP");
    hdr.flags = fl.readNum!ubyte();
    if (hdr.flags&0b1100_0000) throw new Exception("interleaved TGA");
    clear(hdr.width, hdr.height);
    // skip id
    if (hdr.idlen) {
      ubyte[256] b;
      fl.rawReadExact(b[0..hdr.idlen]);
    }
    // image
    //  24: BGR
    //  32: BGRA
    bool downup = !(hdr.flags&0b0010_0000);
    // load image
    foreach (immutable y; 0..mHeight) {
      foreach (immutable x; 0..mWidth) {
        ubyte[4] rgba = void;
        rgba[3] = 255; // opaque
        fl.rawRead(rgba[0..hdr.bpp/8]);
        this[x, (downup ? mWidth-y-1 : y)] = Color(rgba[2], rgba[1], rgba[0], rgba[3]);
      }
    }
  }

  void save (string fname) @trusted {
    import std.stdio : File;
    //writeln("saving ", fname, "...");
    save(File(fname, "w"));
  }

  void save(ST) (auto ref ST fl) @trusted if (isWriteableStream!ST) {
    if (mWidth > 65535 || mHeight > 65535) throw new Exception("TGA too big");
    TGAHeader hdr;
    hdr.imgtype = 2;
    hdr.width = cast(ushort)mWidth;
    hdr.height = cast(ushort)mHeight;
    hdr.bpp = 32;
    // write header
    fl.writeNum!ubyte(hdr.idlen);
    fl.writeNum!ubyte(hdr.cmaptype);
    fl.writeNum!ubyte(hdr.imgtype);
    fl.writeNum!ushort(hdr.cmapfirst);
    fl.writeNum!ushort(hdr.cmapcount);
    fl.writeNum!ubyte(hdr.cmapesize);
    fl.writeNum!ushort(hdr.xorig);
    fl.writeNum!ushort(hdr.yorig);
    fl.writeNum!ushort(hdr.width);
    fl.writeNum!ushort(hdr.height);
    fl.writeNum!ubyte(hdr.bpp);
    fl.writeNum!ubyte(hdr.flags);
    //fl.rawWrite((&hdr)[0..1]);
    // image
    //  24: BGR
    //  32: BGRA
    // save image
    foreach (immutable y; 0..mHeight) {
      foreach (immutable x; 0..mWidth) {
        ubyte[4] rgba = void;
        immutable clr = this[x, mHeight-y-1];
        rgba[0] = clr.b;
        rgba[1] = clr.g;
        rgba[2] = clr.r;
        rgba[3] = clr.a;
        fl.rawWrite(rgba[0..hdr.bpp/8]);
      }
    }
  }

  this (string fname) @trusted => load(fname);

@nogc:
nothrow:
  this (uint wdt, uint hgt) @trusted => clear(wdt, hgt);
  ~this () @trusted => clear();

  void clear (uint wdt=0, uint hgt=0) @trusted {
    import core.exception : onOutOfMemoryError;
    import core.stdc.stdlib : free, realloc;
    if (wdt == 0 || hgt == 0) {
      if (image !is null) {
        free(image);
        image = null;
      }
      mWidth = mHeight = 0;
    } else {
      if (mWidth != wdt || mHeight != hgt || image is null) {
        scope(failure) {
          if (image !is null) {
            free(image);
            image = null;
          }
          mWidth = mHeight = 0;
        }
        auto inew = cast(Color*)realloc(image, wdt*hgt*Color.sizeof+4*2);
        if (inew is null) onOutOfMemoryError();
        image = inew;
        image[0].val = wdt;
        image[1].val = hgt;
      }
      mWidth = wdt;
      mHeight = hgt;
    }
  }

  @property uint width () const @safe pure nothrow @nogc => mWidth;
  @property uint height () const @safe pure nothrow @nogc => mHeight;

  Color opIndex (uint x, uint y) const @trusted pure =>
    (x < 0 || y < 0 || x >= mWidth || y >= mHeight ? Color() : image[y*mWidth+x+2]);

  void opIndexAssign (in Color value, uint x, uint y) @trusted {
    if (x >= 0 && y >= 0 || x < mWidth || y < mHeight) image[y*mWidth+x+2] = value;
  }
}
