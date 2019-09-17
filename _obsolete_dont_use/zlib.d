/* Invisible Vector Library
 * coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * Understanding is not required. Only obedience.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 3 of the License ONLY.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */
// severely outdated ZLib streams
// use iv.vfs instead
module iv.zlib /*is aliced*/;
import iv.alice;


// ////////////////////////////////////////////////////////////////////////// //
//version=iv_zlib_malloc_compress;
//version=iv_zlib_malloc_decompress;


// ////////////////////////////////////////////////////////////////////////// //
enum ZlibMax = 666; // special constant for compression level


// ////////////////////////////////////////////////////////////////////////// //
/**
 * Errors throw a ZlibException.
 */
class ZlibException : Exception {
  this (int errnum, string file=__FILE__, usize line=__LINE__, Throwable next=null) @safe pure {
    import etc.c.zlib;
    string msg;
    switch (errnum) {
      case Z_OK: msg = "no error"; break;
      case Z_STREAM_END: msg = "stream end"; break;
      case Z_NEED_DICT: msg = "need dict"; break;
      case Z_ERRNO: msg = "errno"; break;
      case Z_STREAM_ERROR: msg = "stream error"; break;
      case Z_DATA_ERROR: msg = "data error"; break;
      case Z_MEM_ERROR: msg = "mem error"; break;
      case Z_BUF_ERROR: msg = "buf error"; break;
      case Z_VERSION_ERROR: msg = "version error"; break;
      default:
        // Эх, тачанка-ростовчанка,
        // Наша гордость и краса,
        // Конармейская тачанка,
        // Все четыре колеса.
        import std.conv : to;
        msg = "unknown error with code "~to!string(errnum);
        break;
    }
    super(msg, file, line, next);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
/**
 * Compute the Adler32 checksum of the data in buf[]. adler is the starting
 * value when computing a cumulative checksum.
 */
uint adler32 (const(void)[] buf, uint prevadler=0) {
  import etc.c.zlib : adler32;
  while (buf.length > 0) {
    uint len = (buf.length > 0xffff_0000u ? 0xffff_0000u : cast(uint)buf.length);
    prevadler = /*etc.c.zlib.*/adler32(prevadler, cast(ubyte*)buf.ptr, len);
    buf = buf[len..$];
  }
  return prevadler;
}


/**
 * Compute the CRC32 checksum of the data in buf[]. crc is the starting value
 * when computing a cumulative checksum.
 */
uint crc32 (const(void)[] buf, uint prevcrc=0) {
  import etc.c.zlib : crc32;
  while (buf.length > 0) {
    uint len = (buf.length > 0xffff_0000u ? 0xffff_0000u : cast(uint)buf.length);
    prevcrc = /*etc.c.zlib.*/crc32(prevcrc, cast(ubyte*)buf.ptr, len);
    buf = buf[len..$];
  }
  return prevcrc;
}


// ////////////////////////////////////////////////////////////////////////// //
import std.range : isInputRange, isOutputRange;


/// the header format the compressed stream is wrapped in
enum ZHeader {
  deflate, /// a standard zlib header
  gzip, /// a gzip file format header
  detect /// used when decompressing: try to automatically detect the stream format by looking at the data
}


/**
 * Compresses the data from `ri` to `ro`.
 *
 * Params:
 *   ri = finite input range with byte-sized elements
 *   ro = output range that can accept ubyte or ubyte[]
 *   level = compression level; -1: default, ZlibMax: maximum, [0..9]
 *   header = compressed stream header (deflate or gzip)
 */
void zcompress(RI, RO) (auto ref RI ri, auto ref RO ro, int level=ZlibMax, ZHeader header=ZHeader.deflate)
if (isInputRange!RI && (isOutputRange!(RO, ubyte) || isOutputRange!(RO, ubyte[])))
in {
  import std.range : isInfinite, ElementType;
  // check range types
  static assert(!isInfinite!RI, "ri should be finite range");
  static assert((ElementType!RI).sizeof == 1, "ri should be byte range");
  // check args
  assert(level == ZlibMax || (-1 <= level && level <= 9));
  assert(header == ZHeader.deflate || header == ZHeader.gzip);
}
body {
  import etc.c.zlib;
  version(test_zlib_log) import core.stdc.stdio : printf;

  if (ri.empty) return; // nothing to do

  z_stream zs;
  version(iv_zlib_malloc_compress) {
    enum ibuflen = 64*1024;
    enum obuflen = 64*1024;
    ubyte* ibuf = null, obuf = null;
    enum ibufptr = "ibuf";
    enum obufptr = "obuf";
  } else {
    enum ibuflen = 8*1024;
    enum obuflen = 8*1024;
    ubyte[ibuflen] ibuf = void;
    ubyte[obuflen] obuf = void;
    enum ibufptr = "ibuf.ptr";
    enum obufptr = "obuf.ptr";
  }

  void prepareOBuf() () {
    zs.next_out = cast(typeof(zs.next_out))mixin(obufptr);
    zs.avail_out = cast(uint)obuflen;
  }

  void writeOBuf() () {
    if (zs.avail_out < obuflen) {
      version(test_zlib_log) printf("writing %u packed bytes\n", cast(uint)(obuflen-zs.avail_out));
      static if (is(typeof((inout int=0) {
        auto r = RO.init;
        ubyte[2] b;
        r.put(b);
      }))) {
        // can put slices
        ro.put(obuf[0..obuflen-zs.avail_out]);
      } else {
        foreach (immutable pos; 0..obuflen-zs.avail_out) ro.put(obuf[pos]);
      }
    } else {
      version(test_zlib_log) printf("nothing to write\n");
    }
  }

  // init zlib stream
  if (level < 0) level = 6;
  else if (level == 0) level = 1;

  int err = deflateInit2(&zs,
              (level < 9 ? level : 9),
              Z_DEFLATED,
              15+(header == ZHeader.gzip ? 16 : 0),
              (level > 9 ? 9 : 8),
              Z_DEFAULT_STRATEGY);
  if (err) throw new ZlibException(err);
  scope(exit) deflateEnd(&zs);

  // allocate buffers
  version(iv_zlib_malloc_compress) {
    import core.exception : onOutOfMemoryError;
    import core.stdc.stdlib : malloc, free;
    if ((ibuf = cast(ubyte*)malloc(ibuflen)) is null) onOutOfMemoryError();
    if ((obuf = cast(ubyte*)malloc(obuflen)) is null) { free(ibuf); onOutOfMemoryError(); }
    scope(exit) { free(obuf); free(ibuf); }
  }

  // compress stream
  while (!ri.empty) {
    // fill input buffer
    zs.avail_in = 0;
    zs.next_in = cast(typeof(zs.next_in))mixin(ibufptr);
    while (zs.avail_in < cast(uint)ibuflen && !ri.empty) {
      // use `.ptr` to avoid range checking on array
      mixin(ibufptr)[zs.avail_in++] = cast(ubyte)ri.front;
      ri.popFront();
    }
    version(test_zlib_log) printf("read %u unpacked bytes\n", cast(uint)zs.avail_in);
    // process all data in input buffer
    while (zs.avail_in > 0) {
      prepareOBuf();
      err = deflate(&zs, Z_NO_FLUSH);
      if (err != Z_STREAM_END && err != Z_OK) throw new ZlibException(err);
      if (zs.avail_out == cast(uint)obuflen) {
        if (zs.avail_in != 0) throw new ZlibException(Z_BUF_ERROR); // something went wrong here
        break;
      }
      version(test_zlib_log) printf("got %u packed bytes; %u unpacked bytes left\n", cast(uint)(obuflen-zs.avail_out), cast(uint)zs.avail_in);
      writeOBuf();
    }
  }

  // stream compressed, flush zstream
  do {
    zs.avail_in = 0;
    prepareOBuf();
    err = deflate(&zs, Z_FINISH);
    if (err == Z_OK) {
      version(test_zlib_log) printf("Z_OK: got %u packed bytes\n", cast(uint)(obuflen-zs.avail_out));
      if (zs.avail_out == cast(uint)obuflen) throw new ZlibException(Z_BUF_ERROR); // something went wrong here
      writeOBuf();
    }
  } while (err == Z_OK);
  // succesfully flushed?
  if (err != Z_STREAM_END) {
    if (err == Z_OK) err = Z_BUF_ERROR; // out of output space; this is fatal for now
    throw new ZlibException(err);
  }
  writeOBuf();
}


version(test_zlib)
unittest {
  import iv.stream;
  import std.stdio;
  auto fi = File("iv.zlib.d", "r");
  auto fo = File("ztmp.bin.gz", "w");
  writeln("compressing...");
  zcompress(streamAsRange!"r"(fi), streamAsRange(fo), ZlibMax, ZHeader.gzip);
  writeln("done: ", fi.size, " -> ", fo.size);
}


// ////////////////////////////////////////////////////////////////////////// //
/**
 * Decompresses the data from `ri` to `ro`.
 *
 * Params:
 *   ri = finite input range with byte-sized elements
 *   ro = output range that can accept ubyte or ubyte[]
 *   format = compressed stream format (deflate or gzip)
 */
void zdecompress(RI, RO) (auto ref RI ri, auto ref RO ro, ZHeader format=ZHeader.detect)
if (isInputRange!RI && (isOutputRange!(RO, ubyte) || isOutputRange!(RO, ubyte[])))
in {
  import std.range : isInfinite, ElementType;
  // check range types
  static assert(!isInfinite!RI, "ri should be finite range");
  static assert((ElementType!RI).sizeof == 1, "ri should be byte range");
  // check args
  assert(format == ZHeader.deflate || format == ZHeader.gzip || format == ZHeader.detect);
}
body {
  import etc.c.zlib;
  version(test_zlib_log) import core.stdc.stdio : printf;

  if (ri.empty) return;

  z_stream zs;
  version(iv_zlib_malloc_decompress) {
    enum ibuflen = 64*1024;
    enum obuflen = 64*1024;
    ubyte* ibuf = null, obuf = null;
    enum ibufptr = "ibuf";
    enum obufptr = "obuf";
  } else {
    enum ibuflen = 8*1024;
    enum obuflen = 8*1024;
    ubyte[ibuflen] ibuf = void;
    ubyte[obuflen] obuf = void;
    enum ibufptr = "ibuf.ptr";
    enum obufptr = "obuf.ptr";
  }

  void prepareOBuf() () {
    zs.next_out = cast(typeof(zs.next_out))mixin(obufptr);
    zs.avail_out = cast(uint)obuflen;
  }

  void writeOBuf() () {
    if (zs.avail_out < obuflen) {
      version(test_zlib_log) printf("writing %u packed bytes\n", cast(uint)(obuflen-zs.avail_out));
      static if (is(typeof((inout int=0) {
        auto r = RO.init;
        ubyte[2] b;
        r.put(b);
      }))) {
        // can put slices
        ro.put(obuf[0..obuflen-zs.avail_out]);
      } else {
        foreach (immutable pos; 0..obuflen-zs.avail_out) ro.put(obuf[pos]);
      }
    } else {
      version(test_zlib_log) printf("nothing to write\n");
    }
  }

  // init zlib stream
  int windowBits = 15;
  switch (format) with (ZHeader) {
    case gzip: windowBits += 16; break;
    case detect: windowBits += 32; break;
    default:
  }

  int err = inflateInit2(&zs, windowBits);
  if (err) throw new ZlibException(err);
  scope(exit) inflateEnd(&zs);

  // allocate buffers
  version(iv_zlib_malloc_decompress) {
    import core.exception : onOutOfMemoryError;
    import core.stdc.stdlib : malloc, free;
    if ((ibuf = cast(ubyte*)malloc(ibuflen)) is null) onOutOfMemoryError();
    if ((obuf = cast(ubyte*)malloc(obuflen)) is null) { free(ibuf); onOutOfMemoryError(); }
    scope(exit) { free(obuf); free(ibuf); }
  }

  // decompress stream
  bool streamComplete = false;
  while (!streamComplete && !ri.empty) {
    // fill input buffer
    zs.avail_in = 0;
    zs.next_in = cast(typeof(zs.next_in))mixin(ibufptr);
    while (zs.avail_in < cast(uint)ibuflen && !ri.empty) {
      // use `.ptr` to avoid range checking on array
      mixin(ibufptr)[zs.avail_in++] = cast(ubyte)ri.front;
      ri.popFront();
    }
    version(test_zlib_log) printf("read %u packed bytes\n", cast(uint)zs.avail_in);
    // process all data in input buffer
    while (zs.avail_in > 0) {
      prepareOBuf();
      //err = inflate(&zs, (lastChunk ? Z_NO_FLUSH : Z_FINISH));
      err = inflate(&zs, Z_NO_FLUSH);
      if (err != Z_STREAM_END && err != Z_OK) throw new ZlibException(err);
      if (err == Z_STREAM_END) {
        assert(zs.avail_in == 0);
        streamComplete = true;
      }
      if (zs.avail_out == cast(uint)obuflen) {
        if (zs.avail_in != 0) throw new ZlibException(Z_BUF_ERROR); // something went wrong here
        break;
      }
      version(test_zlib_log) printf("got %u unpacked bytes; %u packed bytes left\n", cast(uint)(obuflen-zs.avail_out), cast(uint)zs.avail_in);
      writeOBuf();
    }
  }

  // finish him!
  if (!streamComplete) {
    zs.avail_in = 0;
    prepareOBuf();
    err = inflate(&zs, Z_FINISH);
    // succesfully flushed?
    if (err != Z_STREAM_END) {
      if (err == Z_OK) err = Z_BUF_ERROR; // out of output space; this is fatal for now
      throw new ZlibException(err);
    }
    writeOBuf();
  }
}


version(test_zlib)
unittest {
  import iv.stream;
  import std.stdio;
  auto fi = File("ztmp.bin.gz", "r");
  auto fo = File("ztmp.bin", "w");
  writeln("decompressing...");
  zdecompress(streamAsRange!"r"(fi), streamAsRange!"w"(fo));
  writeln("done: ", fi.size, " -> ", fo.size);
}
