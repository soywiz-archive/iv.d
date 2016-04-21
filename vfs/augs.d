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
module iv.vfs.augs;

private import std.traits : isMutable;

public import iv.vfs : Seek;
public import iv.vfs.error;


// ////////////////////////////////////////////////////////////////////////// //
// augmentation checks
private import iv.vfs : ssize, usize;

/// is this "low-level" stream that can be read?
enum isLowLevelStreamR(T) = is(typeof((inout int=0) {
  auto t = T.init;
  ubyte[1] b;
  ssize r = t.read(b.ptr, 1);
}));

/// is this "low-level" stream that can be written?
enum isLowLevelStreamW(T) = is(typeof((inout int=0) {
  auto t = T.init;
  ubyte[1] b;
  ssize w = t.write(b.ptr, 1);
}));


/// is this "low-level" stream that can be seeked?
enum isLowLevelStreamS(T) = is(typeof((inout int=0) {
  auto t = T.init;
  long p = t.lseek(0, 0);
}));


// ////////////////////////////////////////////////////////////////////////// //
/// augment low-level streams with `rawRead`
T[] rawRead(ST, T) (auto ref ST st, T[] buf) if (isLowLevelStreamR!ST && isMutable!T) {
  if (buf.length > 0) {
    auto res = st.read(buf.ptr, buf.length*T.sizeof);
    if (res == -1 || res%T.sizeof != 0) throw new VFSException("read error");
    return buf[0..res/T.sizeof];
  } else {
    return buf[0..0];
  }
}

/// augment low-level streams with `rawWrite`
void rawWrite(ST, T) (auto ref ST st, in T[] buf) if (isLowLevelStreamW!ST) {
  if (buf.length > 0) {
    auto res = st.write(buf.ptr, buf.length*T.sizeof);
    if (res == -1 || res%T.sizeof != 0) throw new VFSException("write error");
  }
}

/// read exact size or throw error
T[] rawReadExact(ST, T) (auto ref ST st, T[] buf) if (isReadableStream!ST && isMutable!T) {
  auto res = st.rawRead(buf);
  if (res.length != buf.length) throw new VFSException("read error");
  return buf;
}

/// write exact size or throw error (just for convenience)
void rawWriteExact(ST, T) (auto ref ST st, in T[] buf) if (isWriteableStream!ST) { st.rawWrite(buf); }


// ////////////////////////////////////////////////////////////////////////// //
/// check if a given stream supports `eof`
enum streamHasEof(T) = is(typeof((inout int=0) {
  auto t = T.init;
  bool n = t.eof;
}));

/// check if a given stream supports `seek`
enum streamHasSeek(T) = is(typeof((inout int=0) {
  import core.stdc.stdio : SEEK_END;
  auto t = T.init;
  t.seek(0);
  t.seek(0, SEEK_END);
}));

/// check if a given stream supports `tell`
enum streamHasTell(T) = is(typeof((inout int=0) {
  auto t = T.init;
  long pos = t.tell;
}));

/// check if a given stream supports `tell`
enum streamHasClose(T) = is(typeof((inout int=0) {
  auto t = T.init;
  t.close();
}));

/// check if a given stream supports `name`
enum streamHasName(T) = is(typeof((inout int=0) {
  auto t = T.init;
  const(char)[] n = t.name;
}));

/// check if a given stream supports `size`
enum streamHasSize(T) = is(typeof((inout int=0) {
  auto t = T.init;
  long pos = t.size;
}));

/// check if a given stream supports `isOpen`
enum streamHasIsOpen(T) = is(typeof((inout int=0) {
  auto t = T.init;
  bool op = t.isOpen;
}));

/// check if a given stream supports `rawRead()`.
/// it's enough to support `void[] rawRead (void[] buf)`
enum isReadableStream(T) = is(typeof((inout int=0) {
  auto t = T.init;
  ubyte[1] b;
  auto v = cast(void[])b;
  t.rawRead(v);
}));

/// check if a given stream supports `rawWrite()`.
/// it's enough to support `inout(void)[] rawWrite (inout(void)[] buf)`
enum isWriteableStream(T) = is(typeof((inout int=0) {
  auto t = T.init;
  ubyte[1] b;
  t.rawWrite(cast(void[])b);
}));

/// check if a given stream supports both reading and writing
enum isRWStream(T) = isReadableStream!T && isWriteableStream!T;

/// check if a given stream supports `.seek(ofs, [whence])`, and `.tell`
enum isSeekableStream(T) = (streamHasSeek!T && streamHasTell!T);

/// check if we can get size of a given stream.
/// this can be done either with `.size`, or with `.seek` and `.tell`
enum isSizedStream(T) = (streamHasSize!T || isSeekableStream!T);

version(vfs_test_stream) {
  import std.stdio;
  static assert(isReadableStream!File);
  static assert(isWriteableStream!File);
  static assert(isRWStream!File);
  static assert(isSeekableStream!File);
  static assert(streamHasEof!File);
  static assert(streamHasSeek!File);
  static assert(streamHasTell!File);
  static assert(streamHasName!File);
  static assert(streamHasSize!File);
  struct S {}
  static assert(!isReadableStream!S);
  static assert(!isWriteableStream!S);
  static assert(!isRWStream!S);
  static assert(!isSeekableStream!S);
  static assert(!streamHasEof!S);
  static assert(!streamHasSeek!S);
  static assert(!streamHasTell!S);
  static assert(!streamHasName!S);
  static assert(!streamHasSize!S);
}


// ////////////////////////////////////////////////////////////////////////// //
private enum isGoodEndianness(string s) = (s == "LE" || s == "le" || s == "BE" || s == "be");

private template isLittleEndianness(string s) if (isGoodEndianness!s) {
  enum isLittleEndianness = (s == "LE" || s == "le");
}

private template isBigEndianness(string s) if (isGoodEndianness!s) {
  enum isLittleEndianness = (s == "BE" || s == "be");
}

private template isSystemEndianness(string s) if (isGoodEndianness!s) {
  version(LittleEndian) {
    enum isSystemEndianness = isLittleEndianness!s;
  } else {
    enum isSystemEndianness = isBigEndianness!s;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
/// write integer value of the given type, with the given endianness (default: little-endian)
/// usage: st.writeNum!ubyte(10)
void writeNum(T, string es="LE", ST) (auto ref ST st, T n) if (isGoodEndianness!es && isWriteableStream!ST && __traits(isIntegral, T)) {
  static assert(T.sizeof <= 8); // just in case
  static if (isSystemEndianness!es) {
    st.rawWriteExact((&n)[0..1]);
  } else {
    ubyte[T.sizeof] b = void;
    version(LittleEndian) {
      // convert to big-endian
      foreach_reverse (ref x; b) { x = n&0xff; n >>= 8; }
    } else {
      // convert to little-endian
      foreach (ref x; b) { x = n&0xff; n >>= 8; }
    }
    st.rawWriteExact(b[]);
  }
}


/// read integer value of the given type, with the given endianness (default: little-endian)
/// usage: auto v = st.readNum!ubyte
T readNum(T, string es="LE", ST) (auto ref ST st) if (isGoodEndianness!es && isReadableStream!ST && __traits(isIntegral, T)) {
  static assert(T.sizeof <= 8); // just in case
  static if (isSystemEndianness!es) {
    T v = void;
    st.rawReadExact((&v)[0..1]);
    return v;
  } else {
    ubyte[T.sizeof] b = void;
    st.rawReadExact(b[]);
    T v = 0;
    version(LittleEndian) {
      // convert from big-endian
      foreach (ubyte x; b) { v <<= 8; v |= x; }
    } else {
      // conver from little-endian
      foreach_reverse (ubyte x; b) { v <<= 8; v |= x; }
    }
    return v;
  }
}


private enum reverseBytesMixin = "
  foreach (idx; 0..b.length/2) {
    ubyte t = b[idx];
    b[idx] = b[$-idx-1];
    b[$-idx-1] = t;
  }
";


/// write floating value of the given type, with the given endianness (default: little-endian)
/// usage: st.writeNum!float(10)
void writeNum(T, string es="LE", ST) (auto ref ST st, T n) if (isGoodEndianness!es && isWriteableStream!ST && __traits(isFloating, T)) {
  static assert(T.sizeof <= 8);
  static if (isSystemEndianness!es) {
    st.rawWriteExact((&n)[0..1]);
  } else {
    import core.stdc.string : memcpy;
    ubyte[T.sizeof] b = void;
    memcpy(b.ptr, &v, T.sizeof);
    mixin(reverseBytesMixin);
    st.rawWriteExact(b[]);
  }
}


/// read floating value of the given type, with the given endianness (default: little-endian)
/// usage: auto v = st.readNum!float
T readNum(T, string es="LE", ST) (auto ref ST st) if (isGoodEndianness!es && isReadableStream!ST && __traits(isFloating, T)) {
  static assert(T.sizeof <= 8);
  T v = void;
  static if (isSystemEndianness!es) {
    st.rawReadExact((&v)[0..1]);
  } else {
    import core.stdc.string : memcpy;
    ubyte[T.sizeof] b = void;
    st.rawReadExact(b[]);
    mixin(reverseBytesMixin);
    memcpy(&v, b.ptr, T.sizeof);
  }
  return v;
}
