/* coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * Understanding is not required. Only obedience.
 *
 *                   INVISIBLE VECTOR PUBLIC LICENSE
 *                       Version 0, August 2014
 *
 * Copyright (C) 2014 Ketmar Dark <ketmar@ketmar.no-ip.org>
 *
 * Everyone is permitted to copy and distribute verbatim or modified
 * copies of this license document, and changing it is allowed as long
 * as the name is changed.
 *
 *                   INVISIBLE VECTOR PUBLIC LICENSE
 *   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
 *
 * 0. You may not use this software in either source or binary form, any
 *    software derived from this software, any library which uses either
 *    this software or code derived from this software in any other
 *    software which uses Windows API, either directly or indirectly
 *    via any chain of libraries.
 *
 * 1. You may not use this software in either source or binary form, any
 *    software derived from this software, any library which uses either
 *    this software or code derived from this software in any other
 *    software which uses MacOS X API, either directly or indirectly via
 *    any chain of libraries.
 *
 * 2. You may not use this software in either source or binary form, any
 *    software derived from this software, any library which uses either
 *    this software or code derived from this software in any other
 *    software on the territory of Russian Federation, either directly or
 *    indirectly via any chain of libraries.
 *
 * 3. Redistributions of this software in either source or binary form must
 *    retain this list of conditions and the following disclaimer.
 *
 * 4. Otherwise, you are allowed to use this software in any way that will
 *    not violate paragraphs 0, 1, 2 and 3 of this license.
 *
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 * Authors: Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * License: IVPLv0
 */
module iv.tga is aliced;

final class Targa {
  private import iv.stream;

  private static struct TGAHeader {
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
    hdr.bpp = 24;
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
        immutable clr = this[x, mWidth-y-1];
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
