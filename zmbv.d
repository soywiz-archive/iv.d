/*
 * Copyright (C) 2002-2013  The DOSBox Team
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
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * D translation by Ketmar // Invisible Vector
 */
module iv.zmbv is aliced;


// ////////////////////////////////////////////////////////////////////////// //
import iv.exex;

mixin(MyException!"ZMBVError");


// ////////////////////////////////////////////////////////////////////////// //
class Codec {
public:
  enum Format {
    None  = 0x00,
    //bpp1  = 0x01,
    //bpp2  = 0x02,
    //bpp4  = 0x03,
    bpp8  = 0x04,
    bpp15 = 0x05,
    bpp16 = 0x06,
    //bpp24 = 0x07,
    bpp32 = 0x08
  }

  // ZMBV compression
  enum Compression {
    None = 0,
    ZLib = 1
  }


  // returns Format.None for unknown bpp
  static Format bpp2format(T) (T bpp) @safe pure nothrow @nogc
  if (__traits(isIntegral, T))
  {
    switch (bpp) {
      case 8: return Format.bpp8;
      case 15: return Format.bpp15;
      case 16: return Format.bpp16;
      case 32: return Format.bpp32;
      default: return Format.None;
    }
    assert(0);
  }

  // returns 0 for unknown format
  static ubyte format2bpp (Format fmt) @safe pure nothrow @nogc {
    switch (fmt) {
      case Format.bpp8: return 8;
      case Format.bpp15: return 15;
      case Format.bpp16: return 16;
      case Format.bpp32: return 32;
      default: return 0;
    }
    assert(0);
  }

  // returns 0 for unknown format
  static ubyte format2pixelSize (Format fmt) @safe pure nothrow @nogc {
    switch (fmt) {
      case Format.bpp8: return 1;
      case Format.bpp15: case Format.bpp16: return 2;
      case Format.bpp32: return 4;
      default: return 0;
    }
    assert(0);
  }

  static bool isValidFormat (Format fmt) @safe pure nothrow @nogc {
    switch (fmt) {
      case Format.bpp8:
      case Format.bpp15:
      case Format.bpp16:
      case Format.bpp32:
        return true;
      default:
        return false;
    }
    assert(0);
  }

private:
  import etc.c.zlib : z_stream;

  enum MaxVector = 16;

  // ZMBV format version
  enum Version {
    High = 0,
    Low = 1
  }

  enum FrameMask {
    Keyframe = 0x01,
    DeltaPalette = 0x02
  }

  struct FrameBlock {
    int start;
    int dx, dy;
  }

  align(1) struct KeyframeHeader {
  align(1):
    ubyte versionHi;
    ubyte versionLo;
    ubyte compression;
    ubyte format;
    ubyte blockWidth;
    ubyte blockHeight;
  }

  Compression mCompression = Compression.ZLib;

  ubyte* oldFrame, newFrame;
  ubyte* buf1, buf2, work;
  usize bufSize;
  usize workUsed;

  usize blockCount;
  FrameBlock* blocks;

  ushort palSize;
  ubyte[256*3] mPalette;

  uint mHeight, mWidth, mPitch;

  Format mFormat;
  uint pixelSize;

  z_stream zstream;
  bool zstreamInited;

  // used in encoder only, but moved here for freeBuffers()
  usize outbufSize;
  ubyte* outbuf;

public:
  this (uint width, uint height) @trusted {
    if (width < 1 || height < 1 || width > 32768 || height > 32768) throw new ZMBVError("invalid ZMBV dimensions");
    mWidth = width;
    mHeight = height;
    mPitch = mWidth+2*MaxVector;
  }

  ~this () @safe nothrow /*@nogc*/ {
    clear();
  }

  // release all allocated memory, finish zstream, etc
  final void clear () @trusted nothrow /*@nogc*/ {
    zlibDeinit();
    freeBuffers();
  }

  protected abstract void zlibDeinit () @trusted nothrow /*@nogc*/;

final:
  @property uint width () const @safe pure nothrow @nogc => mWidth;
  @property uint height () const @safe pure nothrow @nogc => mHeight;
  @property Format format () const @safe pure nothrow @nogc => mFormat;

protected:
  void freeBuffers () @trusted nothrow @nogc {
    import core.stdc.stdlib : free;
    if (outbuf !is null) free(outbuf);
    if (blocks !is null) free(blocks);
    if (buf1 !is null) free(buf1);
    if (buf2 !is null) free(buf2);
    if (work !is null) free(work);
    outbuf = null;
    outbufSize = 0;
    blocks = null;
    buf1 = null;
    buf2 = null;
    work = null;
  }

  void setupBuffers (Format fmt, uint blockWidth, uint blockHeight) @trusted {
    import core.stdc.stdlib : malloc;
    import std.exception : enforce;
    freeBuffers();
    pixelSize = format2pixelSize(fmt);
    if (pixelSize == 0) throw new ZMBVError("invalid ZMBV format");
    if (blockWidth < 1 || blockHeight < 1) throw new ZMBVError("invalid ZMBV block size");
    palSize = (fmt == Format.bpp8 ? 256 : 0);
    bufSize = (mHeight+2*MaxVector)*mPitch*pixelSize+2048;
    buf1 = cast(ubyte*)malloc(bufSize);
    buf2 = cast(ubyte*)malloc(bufSize);
    work = cast(ubyte*)malloc(bufSize);
    scope(failure) freeBuffers();
    enforce(buf1 !is null && buf2 !is null && work !is null);

    uint xblocks = (mWidth/blockWidth);
    uint xleft = mWidth%blockWidth;
    if (xleft) ++xblocks;

    uint yblocks = (mHeight/blockHeight);
    uint yleft = mHeight%blockHeight;
    if (yleft) ++yblocks;

    blockCount = yblocks*xblocks;
    blocks = cast(FrameBlock*)malloc(FrameBlock.sizeof*blockCount);
    enforce(blocks !is null);

    uint i = 0;
    foreach (immutable y; 0..yblocks) {
      foreach (immutable x; 0..xblocks) {
        blocks[i].start = ((y*blockHeight)+MaxVector)*mPitch+(x*blockWidth)+MaxVector;
        blocks[i].dx = (xleft && x == xblocks-1 ? xleft : blockWidth);
        blocks[i].dy = (yleft && y == yblocks-1 ? yleft : blockHeight);
        ++i;
      }
    }

    buf1[0..bufSize] = 0;
    buf2[0..bufSize] = 0;
    work[0..bufSize] = 0;
    oldFrame = buf1;
    newFrame = buf2;
    mFormat = fmt;
  }


  // swap old frame and new frame
  void swapFrames () @safe nothrow @nogc {
    auto copyFrame = newFrame;
    newFrame = oldFrame;
    oldFrame = copyFrame;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
class Encoder : Codec {
private:
  struct CodecVector {
    int x, y;
  }
  CodecVector[441] vectorTable = void;

  ubyte mCompressionLevel;
  ulong frameCount;
  usize linesDone;
  usize writeDone;

public:
  enum PrepareFlags {
    None = 0,
    Keyframe = 1
  }

  this (uint width, uint height, Format fmt=Format.None, int complevel=-1, Compression ctype=Compression.ZLib) @trusted {
    super(width, height);
    if (fmt != Format.None && !isValidFormat(fmt)) throw new ZMBVError("invalid ZMBV format");
    if (ctype != Compression.None && ctype != Compression.ZLib) throw new ZMBVError("invalid ZMBV compression");
    if (ctype == Compression.ZLib) {
      if (complevel < 0) complevel = 4;
      if (complevel > 9) complevel = 9;
    } else {
      complevel = 0;
    }
    mCompression = ctype;
    mCompressionLevel = cast(ubyte)complevel;
    mFormat = fmt;
    createVectorTable();
    frameCount = 0;
    if (mCompression == Compression.ZLib) {
      import etc.c.zlib : deflateInit, Z_OK;
      if (deflateInit(&zstream, complevel) != Z_OK) throw new ZMBVError("can't initialize ZLib stream");
      zstreamInited = true;
    }
    // allocate buffer here if we know the format
    if (fmt != Format.None) fixOutBuffer();
  }

  protected override void zlibDeinit () @trusted nothrow /*@nogc*/ {
    if (zstreamInited) {
      import etc.c.zlib : deflateEnd;
      try deflateEnd(&zstream); catch (Exception) {}
      zstreamInited = false;
    }
    frameCount = 0; // do it here as we have no other hooks in clear()
  }

  // (re)allocate buffer for compressed data
  private final fixOutBuffer () @trusted {
    usize nbs = workBufferSize();
    if (nbs == 0) throw new ZMBVError("internal error");
    if (nbs > outbufSize) {
      import core.stdc.stdlib : realloc;
      // we need bigger buffer
      void* nb = realloc(outbuf, nbs);
      if (nb is null) throw new ZMBVError("out of memory for compression buffer");
      outbufSize = nbs;
      outbuf = cast(ubyte*)nb;
    }
  }

final:
  @property Compression compression () const @safe pure nothrow @nogc => mCompression;
  @property ubyte compressionLevel () const @safe pure nothrow @nogc => mCompressionLevel;
  @property ulong processedFrames () const @safe pure nothrow @nogc => frameCount;

  void prepareFrame (PrepareFlags flags, const(ubyte)[] pal=null, Format fmt=Format.None) @trusted {
    import std.algorithm : min;

    if (flags != PrepareFlags.None && flags != PrepareFlags.Keyframe) throw new ZMBVError("invalid flags");
    if (fmt == Format.None) {
      if (mFormat == Format.None) throw new ZMBVError("invalid format");
      fmt = mFormat;
    }
    if (!isValidFormat(fmt)) throw new ZMBVError("invalid format");

    if (fmt != mFormat || frameCount == 0) {
      mFormat = fmt;
      setupBuffers(fmt, 16, 16);
      flags = PrepareFlags.Keyframe; // force a keyframe
    }

    swapFrames();

    // (re)allocate buffer for compressed data
    fixOutBuffer();
    linesDone = 0;
    writeDone = 1; // for firstByte

    // set a pointer to the first byte which will contain info about this frame
    ubyte* firstByte = outbuf;
    *firstByte = 0; // frame flags

    // reset the work buffer
    workUsed = 0;
    if (flags == PrepareFlags.Keyframe) {
      // make a keyframe
      *firstByte |= FrameMask.Keyframe;
      auto header = cast(KeyframeHeader*)(outbuf+writeDone);
      header.versionHi = Version.High;
      header.versionLo = Version.Low;
      header.compression = cast(sbyte)mCompression;
      header.format = cast(ubyte)mFormat;
      header.blockWidth = 16;
      header.blockHeight = 16;
      writeDone += KeyframeHeader.sizeof;
      if (palSize) {
        if (pal.length) {
          immutable usize end = min(pal.length, mPalette.length);
          mPalette[0..end] = pal[0..end];
          if (end < mPalette.length) mPalette[end..$] = 0;
        } else {
          mPalette[] = 0;
        }
        // keyframes get the full palette
        work[0..palSize*3] = mPalette[];
        workUsed += palSize*3;
      }
      // restart deflate
      if (mCompression == Compression.ZLib) {
        import etc.c.zlib : deflateReset, Z_OK;
        if (deflateReset(&zstream) != Z_OK) throw new ZMBVError("can't restart deflate stream");
      }
    } else {
      if (palSize && pal.length) {
        immutable usize end = min(pal.length, mPalette.length);
        if (pal != mPalette) {
          *firstByte |= FrameMask.DeltaPalette;
          foreach (immutable i; 0..end) work[workUsed++] = mPalette[i]^pal[i];
          mPalette[0..end] = pal[0..end];
        }
      }
    }
  }

  // return false when frame is full (and line is not encoded)
  void encodeLine (const(void)[] line) @trusted {
    if (linesDone >= mHeight) throw new ZMBVError("too many lines");
    immutable uint lineWidth = mWidth*pixelSize;
    if (line.length < lineWidth) throw new ZMBVError("line too short");
    immutable usize ofs = pixelSize*(MaxVector+(linesDone+MaxVector)*mPitch);
    newFrame[ofs..ofs+lineWidth] = (cast(const(ubyte*))line.ptr)[0..lineWidth];
    ++linesDone;
  }

  // return array with frame data
  const(void)[] finishFrame () @trusted {
    if (linesDone != mHeight) throw new ZMBVError("can't finish incomplete frame");
    ubyte firstByte = *outbuf;
    if (firstByte&FrameMask.Keyframe) {
      // add the full frame data
      usize ofs = pixelSize*(MaxVector+MaxVector*mPitch);
      immutable llen = mWidth*pixelSize;
      foreach (immutable i; 0..mHeight) {
        work[workUsed..workUsed+llen] = newFrame[ofs..ofs+llen];
        ofs += mPitch*pixelSize;
        workUsed += llen;
      }
    } else {
      // add the delta frame data
      switch (mFormat) {
        case Format.bpp8: addXorFrame!sbyte(); break;
        case Format.bpp15: case Format.bpp16: addXorFrame!short(); break;
        case Format.bpp32: addXorFrame!int(); break;
        default: throw new ZMBVError("internal error");
      }
    }
    if (mCompression == Compression.ZLib) {
      // create the actual frame with compression
      import etc.c.zlib : deflate, Z_OK, Z_SYNC_FLUSH;
      zstream.next_in = work;
      zstream.avail_in = cast(uint)workUsed;
      zstream.total_in = 0;
      zstream.next_out = outbuf+writeDone;
      zstream.avail_out = cast(uint)(outbufSize-writeDone);
      zstream.total_out = 0;
      if (deflate(&zstream, Z_SYNC_FLUSH) != Z_OK) throw new ZMBVError("deflate error"); // the thing that should not be
      ++frameCount;
      return (cast(const(void)*)outbuf)[0..writeDone+zstream.total_out];
    } else {
      outbuf[writeDone..writeDone+workUsed] = work[0..workUsed];
      ++frameCount;
      return (cast(const(void)*)outbuf)[0..workUsed+writeDone];
    }
  }

private:
  usize workBufferSize () const @safe pure nothrow @nogc {
    usize f = format2pixelSize(mFormat);
    return (f ? f*mWidth*mHeight+2*(1+(mWidth/8))*(1+(mHeight/8))+1024 : 0);
  }

  void createVectorTable () @safe pure nothrow @nogc {
    import std.math : abs;
    vectorTable[0].x = vectorTable[0].y = 0;
    usize vectorCount = 1;
    foreach (immutable s; 1..11) {
      foreach (immutable y; 0-s..0+s+1) {
        foreach (immutable x; 0-s..0+s+1) {
          if (abs(x) == s || abs(y) == s) {
            vectorTable[vectorCount].x = x;
            vectorTable[vectorCount].y = y;
            ++vectorCount;
          }
        }
      }
    }
  }

  // encoder templates
  int possibleBlock(P) (int vx, int vy, const(FrameBlock*) block) @trusted nothrow @nogc {
    int ret = 0;
    auto pold = (cast(const(P)*)oldFrame)+block.start+(vy*mPitch)+vx;
    auto pnew = (cast(const(P)*)newFrame)+block.start;
    for (usize y = 0; y < block.dy; y += 4) {
      for (usize x = 0; x < block.dx; x += 4) {
        int test = 0-((pold[x]-pnew[x])&0x00ffffff);
        ret -= (test>>31); // 0 or -1
      }
      pold += mPitch*4;
      pnew += mPitch*4;
    }
    return ret;
  }

  int compareBlock(P) (int vx, int vy, const(FrameBlock*) block) @trusted nothrow @nogc {
    int ret = 0;
    auto pold = (cast(const(P)*)oldFrame)+block.start+(vy*mPitch)+vx;
    auto pnew = (cast(const(P)*)newFrame)+block.start;
    foreach (immutable y; 0..block.dy) {
      foreach (immutable x; 0..block.dx) {
        int test = 0-((pold[x]-pnew[x])&0x00ffffff);
        ret -= (test>>31); // 0 or -1
      }
      pold += mPitch;
      pnew += mPitch;
    }
    return ret;
  }

  void addXorBlock(P) (int vx, int vy, const(FrameBlock*) block) @trusted nothrow @nogc {
    auto pold = (cast(const(P)*)oldFrame)+block.start+(vy*mPitch)+vx;
    auto pnew = (cast(const(P)*)newFrame)+block.start;
    auto dest = cast(P*)(work+workUsed);
    workUsed += P.sizeof*(block.dx*block.dy);
    foreach (immutable y; 0..block.dy) {
      foreach (immutable x; 0..block.dx) {
        *dest++ = pnew[x]^pold[x];
      }
      pold += mPitch;
      pnew += mPitch;
    }
  }

  void addXorFrame(P) () @trusted nothrow @nogc {
    ubyte* vectors = work+workUsed;
    // align the following xor data on 4 byte boundary
    workUsed = (workUsed+blockCount*2+3)&~3;
    const(FrameBlock)* block = blocks;
    foreach (immutable b; 0..blockCount) {
      int bestvx = 0, bestvy = 0;
      int bestchange = compareBlock!P(0, 0, block);
      if (bestchange >= 4) {
        auto possibles = 64;
        foreach (ref vi; vectorTable) {
          auto vx = vi.x, vy = vi.y;
          if (possibleBlock!P(vx, vy, block) < 4) {
            auto testchange = compareBlock!P(vx, vy, block);
            if (testchange < bestchange) {
              bestchange = testchange;
              bestvx = vx;
              bestvy = vy;
              if (bestchange < 4) break;
            }
            if (--possibles == 0) break;
          }
        }
      }
      vectors[b*2+0] = (bestvx<<1)&0xff;
      vectors[b*2+1] = (bestvy<<1)&0xff;
      if (bestchange) {
        vectors[b*2+0] |= 1;
        addXorBlock!P(bestvx, bestvy, block);
      }
      ++block;
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
class Decoder : Codec {
private:
  usize workPos;
  bool mPaletteChanged;
  Format mOldFormat;
  ubyte blockWidth;
  ubyte blockHeight;

public:
  this (uint width, uint height) @trusted {
    super(width, height);
    mCompression = Compression.None;
    mOldFormat = Format.None;
    blockWidth = blockHeight = 0;
  }

  protected override void zlibDeinit () @trusted nothrow /*@nogc*/ {
    if (zstreamInited) {
      import etc.c.zlib : inflateEnd;
      try inflateEnd(&zstream); catch (Exception) {}
      zstreamInited = false;
    }
  }

final:
  @property const(ubyte)[] palette () @trusted nothrow @nogc {
    return mPalette[0..768];
  }

  const(ubyte)[] line (usize idx) const @trusted nothrow @nogc {
    if (idx >= mHeight) return null;
    usize stpos = pixelSize*(MaxVector+MaxVector*mPitch)+mPitch*pixelSize*idx;
    return newFrame[stpos..stpos+mWidth*pixelSize];
  }

  // was pallette changed on currently decoded frame?
  bool paletteChanged () const @trusted nothrow @nogc => mPaletteChanged;

  void decodeFrame (const(void)[] frameData) @trusted {
    usize size = frameData.length;
    mPaletteChanged = false;
    if (frameData is null || size <= 1) throw new ZMBVError("invalid frame data");
    auto data = cast(const(ubyte)*)frameData.ptr;
    ubyte tag = *data++;
    --size;
    if (tag > 2) throw new ZMBVError("invalid frame data"); // for now we can have only 0, 1 or 2 in tag byte
    if (tag&FrameMask.Keyframe) {
      auto header = cast(const(KeyframeHeader*))data;
      if (size <= KeyframeHeader.sizeof) throw new ZMBVError("invalid frame data");
      size -= KeyframeHeader.sizeof;
      data += KeyframeHeader.sizeof;
      if (header.versionHi != Version.High || header.versionLo != Version.Low) throw new ZMBVError("invalid frame data");
      if (header.compression > Compression.max) throw new ZMBVError("invalid frame data"); // invalid compression mode
      if (!isValidFormat(cast(Format)header.format)) throw new ZMBVError("invalid frame data");
      if (header.blockWidth < 1 || header.blockHeight < 1) throw new ZMBVError("invalid frame data");
      if (mFormat != cast(Format)header.format || blockWidth != header.blockWidth || blockHeight != header.blockHeight) {
        // new format or block size
        mFormat = cast(Format)header.format;
        blockWidth = header.blockWidth;
        blockHeight = header.blockHeight;
        setupBuffers(mFormat, blockWidth, blockHeight);
      }
      mCompression = cast(Compression)header.compression;
      if (mCompression == Compression.ZLib) {
        import etc.c.zlib : inflateInit, inflateReset, Z_OK;
        if (!zstreamInited) {
          if (inflateInit(&zstream) != Z_OK) throw new ZMBVError("can't initialize ZLib stream");
          zstreamInited = true;
        } else {
          if (inflateReset(&zstream) != Z_OK) throw new ZMBVError("can't reset inflate stream");
        }
      }
    }
    if (size > bufSize) throw new ZMBVError("frame too big");
    if (mCompression == Compression.ZLib) {
      import etc.c.zlib : inflate, Z_OK, Z_SYNC_FLUSH;
      zstream.next_in = cast(ubyte*)data;
      zstream.avail_in = cast(uint)size;
      zstream.total_in = 0;
      zstream.next_out = work;
      zstream.avail_out = cast(uint)bufSize;
      zstream.total_out = 0;
      if (inflate(&zstream, Z_SYNC_FLUSH/*Z_NO_FLUSH*/) != Z_OK) throw new ZMBVError("can't read inflate stream"); // the thing that should not be
      workUsed = zstream.total_out;
    } else {
      if (size > 0) work[0..size] = data[0..size];
      workUsed = size;
    }
    workPos = 0;
    if (tag&FrameMask.Keyframe) {
      if (palSize) {
        if (workUsed < palSize*3) throw new ZMBVError("invalid frame data");
        mPaletteChanged = true;
        workPos = palSize*3;
        mPalette[0..workPos] = work[0..workPos];
      }
      newFrame = buf1;
      oldFrame = buf2;
      ubyte* writeframe = newFrame+pixelSize*(MaxVector+MaxVector*mPitch);
      foreach (; 0..mHeight) {
        if (workPos+mWidth*pixelSize > workUsed) throw new ZMBVError("invalid frame data");
        writeframe[0..mWidth*pixelSize] = work[workPos..workPos+mWidth*pixelSize];
        writeframe += mPitch*pixelSize;
        workPos += mWidth*pixelSize;
      }
    } else {
      swapFrames();
      if (tag&FrameMask.DeltaPalette) {
        if (workUsed < palSize*3) throw new ZMBVError("invalid frame data");
        mPaletteChanged = true;
        foreach (immutable i; 0..palSize*3) mPalette[i] ^= work[workPos++];
      }
      switch (mFormat) {
        case Format.bpp8: unxorFrame!ubyte(); break;
        case Format.bpp15: case Format.bpp16: unxorFrame!ushort(); break;
        case Format.bpp32: unxorFrame!uint(); break;
        default: throw new ZMBVError("invalid format");
      }
    }
  }

private:
  // decoder templates
  void unxorBlock(P) (int vx, int vy, const(FrameBlock*) block) @trusted nothrow @nogc {
    auto pold = (cast(const(P)*)oldFrame)+block.start+(vy*mPitch)+vx;
    auto pnew = (cast(P*)newFrame)+block.start;
    auto src = cast(const(P)*)(work+workPos);
    workPos += P.sizeof*(block.dx*block.dy);
    foreach (immutable y; 0..block.dy) {
      foreach (immutable x; 0..block.dx) {
        pnew[x] = pold[x]^(*src++);
      }
      pold += mPitch;
      pnew += mPitch;
    }
  }

  void copyBlock(P) (int vx, int vy, const(FrameBlock*) block) @trusted nothrow @nogc {
    auto pold = (cast(const(P)*)oldFrame)+block.start+(vy*mPitch)+vx;
    auto pnew = (cast(P*)newFrame)+block.start;
    foreach (immutable y; 0..block.dy) {
      pnew[0..block.dx] = pold[0..block.dx];
      pold += mPitch;
      pnew += mPitch;
    }
  }

  void unxorFrame(P) () @trusted nothrow @nogc {
    auto vectors = cast(sbyte*)work+workPos;
    workPos = (workPos+blockCount*2+3)&~3;
    const(FrameBlock)* block = blocks;
    foreach (immutable b; 0..blockCount) {
      int delta = vectors[b*2+0]&1;
      int vx = vectors[b*2+0]>>1;
      int vy = vectors[b*2+1]>>1;
      if (delta) unxorBlock!P(vx, vy, block); else copyBlock!P(vx, vy, block);
      ++block;
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
private enum AVI_HEADER_SIZE = 500;


final class AviWriter {
private:
  import std.stdio : File;

public:
  Encoder ec;

  File fl;
  ubyte* index;
  uint indexsize, indexused;
  uint fps;
  uint frames;
  uint written;
  uint audioused; // always 0 for now
  uint audiowritten;
  uint audiorate; // 44100?
  bool was_file_error;

  this (string fname, uint width, uint height, uint fps) @trusted {
    import core.stdc.stdlib : malloc;
    import std.exception : enforce;
    if (fps < 1 || fps > 255) throw new Exception("invalid fps");
    ec = new Encoder(width, height, Encoder.Format.None, 9);
    this.fps = fps;
    this.fl = File(fname, "w");
    {
      ubyte[AVI_HEADER_SIZE] hdr;
      fl.rawWrite(hdr);
    }
    indexsize = 16*4096;
    indexused = 8;
    index = cast(ubyte*)malloc(indexsize);
    enforce(index !is null);
  }

  ~this () @trusted {
    import core.stdc.stdlib : free;
    if (index !is null) free(index);
    index = null;
    indexused = 0;
  }

  void close () @trusted {
    import core.stdc.stdlib : free;
    fixHeader();
    fl.close();
    if (index !is null) free(index);
    index = null;
    indexused = 0;
  }

  void fixHeader () @trusted {
    ubyte[AVI_HEADER_SIZE] hdr;
    usize header_pos = 0;

    void AVIOUT4 (string s) @trusted {
      assert(s.length == 4);
      hdr[header_pos..header_pos+4] = cast(ubyte[])s;
      header_pos += 4;
    }

    void AVIOUTw (ulong w) @trusted {
      if (w > 0xffff) throw new Exception("invalid ushort");
      hdr[header_pos++] = (w&0xff);
      hdr[header_pos++] = ((w>>8)&0xff);
    }

    void AVIOUTd (ulong w, int line=__LINE__) @trusted {
      import std.string : format;
      if (w > 0xffffffffu) throw new Exception("invalid ulong: 0x%08x at line %s".format(w, line));
      hdr[header_pos++] = (w&0xff);
      hdr[header_pos++] = ((w>>8)&0xff);
      hdr[header_pos++] = ((w>>16)&0xff);
      hdr[header_pos++] = ((w>>24)&0xff);
    }

    uint main_list;

    AVIOUT4("RIFF"); // riff header
    AVIOUTd(AVI_HEADER_SIZE+written-8+indexused);
    AVIOUT4("AVI ");
    AVIOUT4("LIST"); // list header
    main_list = cast(uint)header_pos;
    AVIOUTd(0); // TODO size of list
    AVIOUT4("hdrl");

    AVIOUT4("avih");
    AVIOUTd(56); // # of bytes to follow
    AVIOUTd(1000000/fps); // microseconds per frame
    AVIOUTd(0);
    AVIOUTd(0); // PaddingGranularity (whatever that might be)
    AVIOUTd(0x110); // Flags, 0x10 has index, 0x100 interleaved
    AVIOUTd(frames); // TotalFrames
    AVIOUTd(0); // InitialFrames
    AVIOUTd(audiowritten > 0 ? 2 : 1); // Stream count
    AVIOUTd(0); // SuggestedBufferSize
    AVIOUTd(ec.width); // Width
    AVIOUTd(ec.height); // Height
    AVIOUTd(0); // TimeScale:  Unit used to measure time
    AVIOUTd(0); // DataRate:   Data rate of playback
    AVIOUTd(0); // StartTime:  Starting time of AVI data
    AVIOUTd(0); // DataLength: Size of AVI data chunk

    // video stream list
    AVIOUT4("LIST");
    AVIOUTd(4+8+56+8+40); // size of the list
    AVIOUT4("strl");
    // video stream header
    AVIOUT4("strh");
    AVIOUTd(56); // # of bytes to follow
    AVIOUT4("vids"); // type
    AVIOUT4("ZMBV"); // handler
    AVIOUTd(0); // Flags
    AVIOUTd(0); // Reserved, MS says: wPriority, wLanguage
    AVIOUTd(0); // InitialFrames
    AVIOUTd(1000000); // Scale
    AVIOUTd(1000000*fps); // Rate: Rate/Scale == samples/second
    AVIOUTd(0); // Start
    AVIOUTd(frames); // Length
    AVIOUTd(0); // SuggestedBufferSize
    AVIOUTd(0xffffffffu); // Quality
    AVIOUTd(0); // SampleSize
    AVIOUTd(0); // Frame
    AVIOUTd(0); // Frame
    // the video stream format
    AVIOUT4("strf");
    AVIOUTd(40); // # of bytes to follow
    AVIOUTd(40); // Size
    AVIOUTd(ec.width); // Width
    AVIOUTd(ec.height); // Height
    //OUTSHRT(1); OUTSHRT(24); // Planes, Count
    AVIOUTd(0);
    AVIOUT4("ZMBV"); // Compression
    AVIOUTd(ec.width*ec.height*4); // SizeImage (in bytes?)
    AVIOUTd(0); // XPelsPerMeter
    AVIOUTd(0); // YPelsPerMeter
    AVIOUTd(0); // ClrUsed: Number of colors used
    AVIOUTd(0); // ClrImportant: Number of colors important

    if (audiowritten > 0) {
      // audio stream list
      AVIOUT4("LIST");
      AVIOUTd(4+8+56+8+16); // Length of list in bytes
      AVIOUT4("strl");
      // the audio stream header
      AVIOUT4("strh");
      AVIOUTd(56); // # of bytes to follow
      AVIOUT4("auds");
      AVIOUTd(0); // Format (Optionally)
      AVIOUTd(0); // Flags
      AVIOUTd(0); // Reserved, MS says: wPriority, wLanguage
      AVIOUTd(0); // InitialFrames
      AVIOUTd(4); // Scale
      AVIOUTd(audiorate*4); // rate, actual rate is scale/rate
      AVIOUTd(0); // Start
      if (!audiorate) audiorate = 1;
      AVIOUTd(audiowritten/4); // Length
      AVIOUTd(0); // SuggestedBufferSize
      AVIOUTd(~0); // Quality
      AVIOUTd(4); // SampleSize
      AVIOUTd(0); // Frame
      AVIOUTd(0); // Frame
      // the audio stream format
      AVIOUT4("strf");
      AVIOUTd(16); // # of bytes to follow
      AVIOUTw(1); // Format, WAVE_ZMBV_FORMAT_PCM
      AVIOUTw(2); // Number of channels
      AVIOUTd(audiorate); // SamplesPerSec
      AVIOUTd(audiorate*4); // AvgBytesPerSec
      AVIOUTw(4); // BlockAlign
      AVIOUTw(16); // BitsPerSample
    }
    long nmain = header_pos-main_list-4;
    // finish stream list, i.e. put number of bytes in the list to proper pos
    long njunk = AVI_HEADER_SIZE-8-12-header_pos;
    AVIOUT4("JUNK");
    AVIOUTd(njunk);
    // fix the size of the main list
    header_pos = main_list;
    AVIOUTd(nmain);
    header_pos = AVI_HEADER_SIZE-12;
    AVIOUT4("LIST");
    AVIOUTd(written+4); // Length of list in bytes
    AVIOUT4("movi");
    // first add the index table to the end
    index[0] = 'i';
    index[1] = 'd';
    index[2] = 'x';
    index[3] = '1';
    {
      uint d = indexused-8;
      index[4] = (d&0xff);
      index[5] = ((d>>8)&0xff);
      index[6] = ((d>>16)&0xff);
      index[7] = ((d>>24)&0xff);
      fl.rawWrite(index[0..indexused]);
    }
    // now replace the header
    fl.seek(0);
    fl.rawWrite(hdr);
  }

  void writeChunk (string tag, const(void)[] data, uint flags, bool writeToIndex=false) @trusted {
    if (tag.length != 4) throw new Exception("invalid tag name");
    uint size = cast(uint)data.length;
    fl.rawWrite(tag);
    fl.rawWrite((&size)[0..1]);
    ubyte* idx;
    uint pos, d;
    // write the actual data
    uint writesize = (size+1)&~1;
    if (size > 0) fl.rawWrite(data);
    if (writesize != size) {
      ubyte[1] b;
      assert(writesize-size == 1); // just in case
      fl.rawWrite(b);
    }
    pos = written+4;
    written += writesize+8;
    if (indexused+16 >= indexsize) {
      import core.stdc.stdlib : realloc;
      import std.exception : enforce;
      void* ni = realloc(index, indexsize+16*4096);
      enforce(ni !is null);
      index = cast(ubyte*)ni;
      indexsize += 16*4096;
    }

    void putu32 (usize pos, ulong n) @trusted nothrow @nogc {
      idx[pos] = (n&0xff);
      idx[pos] = ((n>>8)&0xff);
      idx[pos] = ((n>>16)&0xff);
      idx[pos] = ((n>>24)&0xff);
    }

    if (writeToIndex) {
      idx = index+indexused;
      indexused += 16;
      idx[0] = tag[0];
      idx[1] = tag[1];
      idx[2] = tag[2];
      idx[3] = tag[3];
      putu32(4, flags);
      putu32(8, pos);
      putu32(12, size);
    }
  }

  void writeChunkVideo (const(void)[] framedata) @trusted {
    if (framedata.length == 0) throw new Exception("can't write empty frame");
    ubyte b = (cast(const(ubyte)[])framedata)[0];
    writeChunk("00dc", framedata, (b&0x01 ? 0x10 : 0), ((b&0x01) != 0));
    ++frames;
  }


  void writeChunkAudio (const(void)[] data) @trusted {
    if (data.length == 0) return;
    writeChunk("01wb", data, 0);
    audiowritten = cast(uint)data.length;
  }
}
