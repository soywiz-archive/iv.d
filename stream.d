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
module iv.stream is aliced;

import std.conv : ConvOverflowException;
import std.traits : isMutable;
public import core.stdc.stdio : SEEK_SET, SEEK_CUR, SEEK_END;


// ////////////////////////////////////////////////////////////////////////// //
class StreamException : Exception {
  this (string msg, string file=__FILE__, usize line=__LINE__, Throwable next=null) => super(msg, file, line, next);
}


// ////////////////////////////////////////////////////////////////////////// //
enum isReadableStream(T) = is(typeof((inout int=0) {
  auto t = T.default;
  ubyte[1] b;
  auto v = cast(void[])b;
  t.rawRead(v);
}));

enum isWriteableStream(T) = is(typeof((inout int=0) {
  auto t = T.default;
  ubyte[1] b;
  t.rawWrite(cast(void[])b);
}));

enum isRWStream(T) = isReadableStream!T && isWriteableStream!T;

template isSeekableStream(T) {
  enum isSeekableStream = is(typeof((inout int=0) {
    import core.stdc.stdio : SEEK_END;
    auto t = T.default;
    t.seek(0, SEEK_END);
    ulong pos = t.tell;
  }));
}

// bad name!
enum isClosableStream(T) = is(typeof((inout int=0) {
  auto t = T.default;
  t.close();
}));

// bad name!
enum streamHasEOF(T) = is(typeof((inout int=0) {
  auto t = T.default;
  bool n = t.eof;
}));

enum streamHasSeek(T) = is(typeof((inout int=0) {
  import core.stdc.stdio : SEEK_END;
  auto t = T.default;
  t.seek(0, SEEK_END);
}));

enum streamHasTell(T) = is(typeof((inout int=0) {
  auto t = T.default;
  ulong pos = t.tell;
}));

enum streamHasName(T) = is(typeof((inout int=0) {
  auto t = T.default;
  string n = t.name;
}));

enum streamHasSize(T) = is(typeof((inout int=0) {
  auto t = T.default;
  ulong pos = t.size;
}));


version(unittest_stream)
unittest {
  import std.stdio;
  static assert(isReadableStream!File);
  static assert(isWriteableStream!File);
  static assert(isRWStream!File);
  static assert(isSeekableStream!File);
  static assert(streamHasEOF!File);
  static assert(streamHasSeek!File);
  static assert(streamHasTell!File);
  static assert(streamHasName!File);
  static assert(streamHasSize!File);
  struct S {}
  static assert(!isReadableStream!S);
  static assert(!isWriteableStream!S);
  static assert(!isRWStream!S);
  static assert(!isSeekableStream!S);
  static assert(!streamHasEOF!S);
  static assert(!streamHasSeek!S);
  static assert(!streamHasTell!S);
  static assert(!streamHasName!S);
  static assert(!streamHasSize!S);
}


// ////////////////////////////////////////////////////////////////////////// //
T[] rawReadExact(TF, T)(auto ref TF fl, T[] buf)
if (isReadableStream!TF && isMutable!T)
{
  import std.exception : enforce;
  auto res = fl.rawRead(cast(void[])buf);
  enforce(res.length == T.sizeof*buf.length, "reading error");
  return buf;
}


// just for convience
void rawWriteExact(TF, T) (auto ref TF fl, in T[] buf)
if (isWriteableStream!TF)
{
  fl.rawWrite(cast(void[])buf);
}


// ////////////////////////////////////////////////////////////////////////// //
private enum goodEndianness(string s) = (s == "LE" || s == "le" || s == "BE" || s == "be");


private template isLittleEndianness(string s) if (goodEndianness!s) {
  enum isLittleEndianness = (s == "LE" || s == "le");
}

private template isSystemEndianness(string s) if (goodEndianness!s) {
  version(LittleEndian) {
    enum isSystemEndianness = (s == "LE" || s == "le");
  } else {
    enum isSystemEndianness = (s == "BE" || s == "be");
  }
}


// ////////////////////////////////////////////////////////////////////////// //
// usage: write!ubyte(fl, 10)
void writeInt(TD, string es="LE", T, TF) (auto ref TF fl, T n) @trusted
if (goodEndianness!es && isWriteableStream!TF && __traits(isIntegral, TD) && __traits(isIntegral, T))
{
  static assert(T.sizeof <= 8);
  static assert(TD.sizeof <= 8);
  static if (__traits(isUnsigned, TD)) {
    // TD is unsigned
    static if (!__traits(isUnsigned, T)) {
      if (n < 0) throw new ConvOverflowException("writeInt overflow");
    }
  } else {
    // TD is signed
    static if (!__traits(isUnsigned, T)) {
      if (n < TD.min) throw new ConvOverflowException("writeInt overflow");
    }
  }
  if (n > TD.max) throw new ConvOverflowException("writeInt overflow");
  auto v = cast(TD)n;
  static if (isSystemEndianness!es) {
    fl.rawWriteExact((&v)[0..1]);
  } else {
    ubyte[TD.sizeof] b = void;
    version(LittleEndian) {
      // convert to big-endian
      foreach_reverse (immutable idx; 0..TD.sizeof) {
        b[idx] = v&0xff;
        v >>= 8;
      }
    } else {
      // convert to little-endian
      foreach (immutable idx; 0..TD.sizeof) {
        b[idx] = v&0xff;
        v >>= 8;
      }
    }
    fl.rawWriteExact(b);
  }
}


// usage: read!ubyte(fl)
T readInt(T, string es="LE", TF) (auto ref TF fl) @trusted
if (goodEndianness!es && isReadableStream!TF && __traits(isIntegral, T))
{
  static assert(T.sizeof <= 8);
  static if (isSystemEndianness!es) {
    T v = void;
    fl.rawReadExact((&v)[0..1]);
    return v;
  } else {
    ubyte[T.sizeof] b = void;
    fl.rawReadExact(b);
    ulong v = 0;
    version(LittleEndian) {
      // convert from big-endian
      foreach (immutable idx; 0..T.sizeof) {
        v <<= 8;
        v |= b[idx];
      }
    } else {
      // conver from little-endian
      foreach_reverse (immutable idx; 0..T.sizeof) {
        v <<= 8;
        v |= b[idx];
      }
    }
    return cast(T)v;
  }
}


private enum reverseBytesMixin = "
  foreach (idx; 0..b.length/2) {
    ubyte t = b[idx];
    b[idx] = b[b.length-idx-1];
    b[b.length-idx-1] = t;
  }
";


void writeFloat(TD, string es="LE", T, TF) (auto ref TF fl, T n) @trusted
if (goodEndianness!es && isWriteableStream!TF && __traits(isFloating, TD) && (__traits(isFloating, T) || __traits(isIntegral, T)))
{
  static assert(TD.sizeof <= 8);
  static if (__traits(isIntegral, T)) {
    static assert(T.sizeof <= 8);
    writeFloat!(TD, TD)(fl, cast(TD)n);
  } else static if (__traits(isFloating, T)) {
    static assert(T.sizeof <= 8);
    auto v = cast(TD)n;
    static if (isSystemEndianness!es) {
      fl.rawWriteExact((&v)[0..1]);
    } else {
      import core.stdc.string : memcpy;
      ubyte[TD.sizeof] b = void;
      memcpy(b.ptr, &v, TD.sizeof);
      mixin(reverseBytesMixin);
      fl.rawWriteExact(b);
    }
  } else {
    static assert(0);
  }
}


TD readFloat(TD, string es="LE", TF) (auto ref TF fl) @trusted
if (goodEndianness!es && isReadableStream!TF && __traits(isFloating, TD))
{
  static assert(TD.sizeof <= 8);
  TD v = void;
  static if (isSystemEndianness!es) {
    fl.rawReadExact((&v)[0..1]);
  } else {
    import core.stdc.string : memcpy;
    ubyte[TD.sizeof] b = void;
    fl.rawReadExact(b);
    mixin(reverseBytesMixin);
    memcpy(&v, b.ptr, TD.sizeof);
  }
  return v;
}


void writeNum(TD, string es="LE", T, TF) (auto ref TF fl, T n) @trusted if (__traits(isIntegral, TD)) => writeInt!(TD, es, T, TF)(fl, n);
void writeNum(TD, string es="LE", T, TF) (auto ref TF fl, T n) @trusted if (__traits(isFloating, TD)) => writeFloat!(TD, es, T, TF)(fl, n);

TD readNum(TD, string es="LE", TF) (auto ref TF fl) @trusted if (__traits(isIntegral, TD)) => readInt!(TD, es, TF)(fl);
TD readNum(TD, string es="LE", TF) (auto ref TF fl) @trusted if (__traits(isFloating, TD)) => readFloat!(TD, es, TF)(fl);


// ////////////////////////////////////////////////////////////////////////// //
void writeVULong(TF) (auto ref TF fl, ulong v) if (isWriteableStream!TF) {
  ubyte[16] buf = void; // actually, 10 is enough ;-)
  usize pos = 1; // anyway
  // now write as signed
  if (v == 0x8000_0000_0000_0000uL) {
    // special (negative zero)
    buf[0] = 0x80;
  } else {
    if (v&0x8000_0000_0000_0000uL) {
      v = (v^~0uL)+1; // negate v
      buf[0] = 0x80;
    } else {
      buf[0] = 0;
    }
    buf[0] |= v&0x3f;
    v >>= 6;
    if (v > 0) buf[0] |= 0x40;
    while (v != 0) {
      buf[pos] = v&0x7f;
      v >>= 7;
      if (v > 0) buf[pos] |= 0x80;
      ++pos;
    }
  }
  fl.rawWriteExact(buf[0..pos]);
}


ulong readVULong(TF) (auto ref TF fl) @trusted if (isWriteableStream!TF) {
  ulong v = 0;
  ubyte[1] c = void;
  // first byte contains sign flag
  fl.rawReadExact(c);
  if (c[0] == 0x80) return 0x8000_0000_0000_0000uL; // special (negative zero)
  bool neg = (c[0]&0x80) != 0;
  v = c[0]&0x3f;
  c[0] <<= 1;
  // 63/7 == 9, so we can shift at most 56==(7*8) bits
  ubyte shift = 6;
  while (c[0]&0x80) {
    if (shift > 62) throw new ConvOverflowException("readVULong overflow");
    fl.rawReadExact(c);
    ulong n = c[0]&0x7f;
    if (shift == 62 && n > 1) throw new ConvOverflowException("readVULong overflow");
    n <<= shift;
    v |= n;
    shift += 7;
  }
  if (neg) v = (v^~0uL)+1; // negate v
  return v;
}


// write variable-length signed integer
void writeVInt(T, TF) (auto ref TF fl, T n) @trusted if (isWriteableStream!TF && __traits(isIntegral, T)) {
  static assert(T.sizeof <= 8);
  static if (__traits(isUnsigned, T)) {
    // output type is unsigned
    writeVULong(fl, n);
  } else {
    // output type is signed
    writeVULong(fl, cast(ulong)(cast(long)n));
  }
}


// read variable-length integer
T readVInt(T, TF) (auto ref TF fl) @trusted if (isReadableStream!TF && __traits(isIntegral, T)) {
  static assert(T.sizeof <= 8);
  ulong v = readVULong(fl);
  static if (__traits(isUnsigned, T)) {
    // output type is unsigned
    static if (!is(T == ulong)) {
      if (v > T.max) throw new ConvOverflowException("readVInt overflow");
    }
  } else {
    // output type is signed
    static if (!is(T == long)) {
      if (cast(long)v < T.min || cast(long)v > T.max) throw new ConvOverflowException("readVInt overflow");
    }
  }
  return cast(T)v;
}


// ////////////////////////////////////////////////////////////////////////// //
// slow, no recoding
string readZString(TF) (auto ref TF fl, bool* eolhit=null, usize maxSize=1024*1024) @trusted if (isReadableStream!TF) {
  import std.array : appender;
  bool eh;
  if (eolhit is null) eolhit = &eh;
  *eolhit = false;
  if (maxSize == 0) return null;
  auto res = appender!string();
  for (;;) {
    ubyte ch = fl.readNum!ubyte();
    if (ch == 0) { *eolhit = true; break; }
    if (maxSize == 0) break;
    res.put(cast(char)ch);
    --maxSize;
  }
  return res.data;
}


// ////////////////////////////////////////////////////////////////////////// //
// slow, no recoding
// eolhit will be set on EOF too
string readLine(TF) (auto ref TF fl, bool* eolhit=null, usize maxSize=1024*1024) @trusted if (isReadableStream!TF) {
  import std.array : appender;
  bool eh;
  if (eolhit is null) eolhit = &eh;
  *eolhit = false;
  if (maxSize == 0) return null;
  auto res = appender!string();
  for (;;) {
    static if (streamHasEOF!TF) if (fl.eof) { *eolhit = true; break; }
    ubyte ch = fl.readNum!ubyte();
    if (ch == '\r') {
      static if (streamHasEOF!TF) if (fl.eof) { *eolhit = true; break; }
      ch = fl.readNum!ubyte();
      if (ch == '\n') { *eolhit = true; break; }
      if (maxSize == 0) break;
      res.put('\n');
    } else if (ch == '\n') {
      *eolhit = true;
      break;
    }
    if (maxSize == 0) break;
    res.put(cast(char)ch);
    --maxSize;
  }
  return res.data;
}


// ////////////////////////////////////////////////////////////////////////// //
public final class MemoryStream {
private:
  import core.stdc.stdio : SEEK_SET, SEEK_CUR, SEEK_END;

  ubyte[] data;
  uint curpos;

public:
  @property ubyte[] bytes () @safe pure nothrow @nogc => data;

  @property uint size () const @safe pure nothrow @nogc => data.length;
  @property uint tell () const @safe pure nothrow @nogc => curpos;

  //TODO: check for overflow
  void seek (long offset, int origin=SEEK_SET) @trusted {
    if (origin == SEEK_CUR) {
      offset += curpos;
    } else if (origin == SEEK_END) {
      offset = cast(long)data.length+offset;
    }
    if (offset < 0 || offset > data.length) throw new StreamException("invalid offset");
    curpos = cast(uint)offset;
  }

  T[] rawRead(T)(T[] buf) @trusted nothrow @nogc if (isMutable!T) {
    if (buf.length > 0) {
      //TODO: check for overflow
      usize rlen = (data.length-curpos)/T.sizeof;
      if (rlen > buf.length) rlen = buf.length;
      if (rlen) {
        import core.stdc.string : memcpy;
        auto src = cast(const(ubyte)*)data.ptr;
        auto dest = cast(ubyte*)buf.ptr;
        memcpy(cast(ubyte*)buf.ptr, data.ptr+curpos, rlen*T.sizeof);
        curpos += rlen*T.sizeof;
      }
      return buf[0..rlen];
    } else {
      return buf;
    }
  }

  void rawWrite(T) (in T[] buf) @trusted nothrow {
    if (buf.length != 0) {
      //TODO: check for overflow
      import core.stdc.string : memcpy;
      // fix size
      usize bsz = T.sizeof*buf.length;
      usize nsz = curpos+bsz;
      if (nsz > data.length) data.length = nsz;
      // copy data
      memcpy(data.ptr+curpos, cast(const(void*))buf.ptr, bsz);
      curpos += bsz;
    }
  }

  @property bool eof () const @trusted pure nothrow @nogc => (curpos >= data.length);

  void close () @safe pure nothrow @nogc {
    curpos = 0;
    data = null;
  }
}


static assert(isReadableStream!MemoryStream);
static assert(isWriteableStream!MemoryStream);
static assert(isRWStream!MemoryStream);
static assert(isSeekableStream!MemoryStream);
static assert(isClosableStream!MemoryStream);
static assert(streamHasEOF!MemoryStream);
static assert(streamHasSeek!MemoryStream);
static assert(streamHasTell!MemoryStream);


// ////////////////////////////////////////////////////////////////////////// //
public final class MemoryStreamRO {
private:
  import core.stdc.stdio : SEEK_SET, SEEK_CUR, SEEK_END;

  const(ubyte)[] data;
  uint curpos;

public:
  this (const(void)[] adata) @trusted nothrow @nogc {
    data = cast(typeof(data))adata;
  }

  @property const(ubyte)[] bytes () @safe pure nothrow @nogc => data;

  @property uint size () const @safe pure nothrow @nogc => data.length;
  @property uint tell () const @safe pure nothrow @nogc => curpos;

  //TODO: check for overflow
  void seek (long offset, int origin=SEEK_SET) @trusted {
    if (origin == SEEK_CUR) {
      offset += curpos;
    } else if (origin == SEEK_END) {
      offset = cast(long)data.length+offset;
    }
    if (offset < 0 || offset > data.length) throw new StreamException("invalid offset");
    curpos = cast(uint)offset;
  }

  T[] rawRead(T)(T[] buf) @trusted nothrow @nogc if (isMutable!T) {
    if (buf.length > 0) {
      //TODO: check for overflow
      usize rlen = (data.length-curpos)/T.sizeof;
      if (rlen > buf.length) rlen = buf.length;
      if (rlen) {
        import core.stdc.string : memcpy;
        auto src = cast(const(ubyte)*)data.ptr;
        auto dest = cast(ubyte*)buf.ptr;
        memcpy(cast(ubyte*)buf.ptr, data.ptr+curpos, rlen*T.sizeof);
        curpos += rlen*T.sizeof;
      }
      return buf[0..rlen];
    } else {
      return buf;
    }
  }

  @property bool eof () const @trusted pure nothrow @nogc => (curpos >= data.length);

  void close () @safe pure nothrow @nogc {
    curpos = 0;
    data = null;
  }
}


static assert(isReadableStream!MemoryStreamRO);
static assert(!isWriteableStream!MemoryStreamRO);
static assert(!isRWStream!MemoryStreamRO);
static assert(isSeekableStream!MemoryStreamRO);
static assert(isClosableStream!MemoryStreamRO);
static assert(streamHasEOF!MemoryStreamRO);
static assert(streamHasSeek!MemoryStreamRO);
static assert(streamHasTell!MemoryStreamRO);
static assert(streamHasSize!MemoryStreamRO);


// ////////////////////////////////////////////////////////////////////////// //
version(unittest_stream) {
  import std.stdio;

  private void dump (const(ubyte)[] data, File fl=stdout) @trusted {
    for (usize ofs = 0; ofs < data.length; ofs += 16) {
      writef("%04X:", ofs);
      foreach (immutable i; 0..16) {
        if (i == 8) write(' ');
        if (ofs+i < data.length) writef(" %02X", data[ofs+i]); else write("   ");
      }
      write(" ");
      foreach (immutable i; 0..16) {
        if (ofs+i >= data.length) break;
        if (i == 8) write(' ');
        ubyte b = data[ofs+i];
        if (b <= 32 || b >= 127) write('.'); else writef("%c", cast(char)b);
      }
      writeln();
    }
  }
}


version(unittest_stream)
unittest {
  {
    auto ms = new MemoryStream();
    ms.rawWrite(cast(ubyte[])"hello");
    assert(ms.data == cast(ubyte[])"hello");
    //dump(ms.data);
    ushort[3] d;
    ms.seek(0);
    assert(ms.rawRead(d).length == 2);
    assert(d == [0x6568, 0x6c6c, 0]);
    //dump(cast(ubyte[])d);
  }
  {
    auto ms = new MemoryStream();
    wchar[] a = ['\u0401', '\u0280', '\u089e'];
    ms.rawWrite(a);
    //dump(ms.data);
  }
  {
    auto ms = new MemoryStreamRO(cast(const(void)[])"hello");
    assert(ms.data == cast(ubyte[])"hello");
  }
}


version(unittest_stream)
unittest {
  import std.exception : enforce;

  {
    auto fl = new MemoryStream();
    {
      fl.seek(0);
      fl.writeVInt(1);
      fl.writeVInt(-1);
      fl.writeVInt(128000);
      fl.writeVInt(-32000);
    }
    //dump(fl.data);
    assert(fl.data == [0x01,0x81,0x40,0xD0,0x0F,0xC0,0xF4,0x03]);

    try {
      fl.seek(0);
      assert(fl.readVInt!sbyte() == 1);
      assert(fl.readVInt!sbyte() == -1);
      assert(fl.readVInt!int() == 128000);
      assert(fl.readVInt!int() == -32000);
      assert(fl.tell() == fl.size);
    } catch (StreamException) {
      enforce(false, "FUCK! RANGE!");
    }

    try {
      fl.seek(0);
      assert(fl.readVInt!sbyte() == 1);
      assert(fl.readVInt!sbyte() == -1);
      assert(fl.readVInt!int() == 128000);
      assert(fl.readVInt!short() == -32000);
      assert(fl.tell() == fl.size);
    } catch (StreamException) {
      enforce(false, "FUCK! RANGE!");
    }

    auto cnt = 0;
    try {
      fl.seek(0);
      assert(fl.readVInt!sbyte() == 1);
      ++cnt;
      assert(fl.readVInt!sbyte() == -1);
      ++cnt;
      assert(fl.readVInt!sbyte() == 128000);
      ++cnt;
      assert(fl.readVInt!sbyte() == -32000);
      ++cnt;
      assert(fl.tell() == fl.size);
      ++cnt;
      enforce(false, "SHIT!");
    } catch (Exception) {
      enforce(cnt == 2, "FUCK RANGE");
    }

    cnt = 0;
    try {
      fl.seek(0);
      assert(fl.readVInt!sbyte() == 1);
      ++cnt;
      assert(fl.readVInt!ubyte() == -1);
      ++cnt;
      assert(fl.readVInt!sbyte() == 128000);
      ++cnt;
      assert(fl.readVInt!sbyte() == -32000);
      ++cnt;
      assert(fl.tell() == fl.size);
      ++cnt;
      enforce(false, "SHIT!");
    } catch (Exception) {
      enforce(cnt == 1, "FUCK RANGE");
    }

    cnt = 0;
    try {
      fl.seek(0);
      assert(fl.readVInt!sbyte() == 1);
      ++cnt;
      assert(fl.readVInt!sbyte() == -1);
      ++cnt;
      assert(fl.readVInt!int() == 128000);
      ++cnt;
      assert(fl.readVInt!ushort() == -32000);
      ++cnt;
      assert(fl.tell() == fl.size);
      ++cnt;
      enforce(false, "SHIT!");
    } catch (Exception) {
      enforce(cnt == 3, "FUCK RANGE");
    }
  }

  version(LittleEndian) {
    {
      auto fl = new MemoryStream();
      fl.writeInt!long(1);
      fl.writeInt!(long, "BE")(1);
      fl.writeNum!long(1);
      fl.writeNum!long(-2);
      fl.writeNum!(long, "BE")(1);
      fl.writeNum!(long, "BE")(-2);
      fl.writeNum!float(1.0f);
      fl.writeNum!(float, "BE")(1.0f);
      //dump(fl.data);
      assert(fl.data == [
        0x01,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
        0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x01,
        0x01,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
        0xFE,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
        0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x01,
        0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFE,
        0x00,0x00,0x80,0x3F, 0x3F,0x80,0x00,0x00,
      ]);

      fl.seek(0);
      assert(fl.readInt!long() == 1);
      assert(fl.readInt!(long, "BE")() == 1);
      assert(fl.readNum!long() == 1);
      assert(fl.readNum!long() == -2);
      assert(fl.readNum!(long, "BE")() == 1);
      assert(fl.readNum!(long, "BE")() == -2);
      assert(fl.readNum!float() == 1.0f);
      assert(fl.readNum!(float, "BE")() == 1.0f);
      assert(fl.tell() == fl.size);
      //writeln("IO: done");
    }
  }

  {
    auto fl = new MemoryStream();
    fl.rawWrite("loves\nalice\n");
    fl.seek(0);
    bool eol = false;
    assert(fl.readLine(&eol) == "loves" && eol == true && !fl.eof);
    assert(fl.readLine(&eol) == "alice" && eol == true && fl.eof);
  }

  {
    auto fl = new MemoryStream();
    fl.rawWrite("loves\0alice\0");
    fl.seek(0);
    bool eol = false;
    assert(fl.readZString(&eol) == "loves" && eol == true && !fl.eof);
    assert(fl.readZString(&eol) == "alice" && eol == true && fl.eof);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
private class PartialStreamROData {
private:
  ulong rc = 1;
  immutable bool gcrange; // do `GC.removeRange()`?
  immutable long start;
  immutable long size;
  long curpos; // current position
  usize gcroot; // allocated memory that must be free()d

  this (long astart, long asize, usize agcroot, bool arange) @safe nothrow @nogc
  in {
    assert(astart >= 0);
    assert(asize >= 0);
  }
  body {
    gcrange = arange;
    start = astart;
    size = asize;
    gcroot = agcroot;
    //{ import std.stdio; stderr.writefln("0x%08x: ctor, rc=%s", gcroot, rc); }
  }

  // this should never be called
  ~this () @safe nothrow @nogc {
    if (rc != 0) assert(0); // the thing that should not be
    assert(0); // why we are here?!
  }

  void incRef () @safe nothrow @nogc {
    if (++rc == 0) assert(0); // hey, this is definitely a bug!
    //{ import std.stdio; stderr.writefln("0x%08x: incRef, rc=%s", gcroot, rc); }
  }

  // return true if this class is dead
  bool decRef () {
    if (rc-- == 0) assert(0); // hey, this is definitely a bug!
    //{ import std.stdio; stderr.writefln("0x%08x: decRef, rc=%s", gcroot, rc); }
    if (rc == 0) {
      import core.memory : GC;
      import core.stdc.stdlib : free;
      clear(); // finalize stream
      if (gcroot == 0) assert(0); // the thing that should not be
      // remove roots
      if (gcrange) {
        GC.removeRange(cast(void*)gcroot);
        GC.removeRoot(cast(void*)gcroot);
      }
      // free allocated memory
      free(cast(void*)gcroot);
      // just in case
      //{ import std.stdio; stderr.writefln("0x%08x: dead, rc=%s", gcroot, rc); }
      gcroot = 0;
      return true;
    } else {
      return false;
    }
  }

protected:
  abstract void clear ();
  abstract void[] read (void[] buf);
}


private final class PartialStreamDataImpl(ST) : PartialStreamROData {
  ST stream;

  this(ST) (auto ref ST astrm, long astart, long asize, usize agcroot, bool arange) {
    super(astart, asize, agcroot, arange);
    stream = astrm;
  }

protected:
  override void clear () => stream = stream.default;

  override void[] read (void[] buf) {
    assert(curpos >= 0 && curpos <= size);
    usize len = buf.length;
    if (len > size-curpos) len = cast(usize)(size-curpos);
    if (len > 0) {
      stream.seek(start+curpos);
      auto res = stream.rawRead(buf[0..len]);
      curpos += res.length;
      return res;
    } else {
      return buf[0..0];
    }
  }
}


public struct PartialStreamRO {
private:
  PartialStreamROData mStData;

  void initialize(ST) (auto ref ST astrm, long astart, long asize)
  if (isReadableStream!ST && isSeekableStream!ST)
  {
    if (astart < 0) astart = astrm.tell;
    if (astart < 0) throw new StreamException("invalid partial stream parameters");
    if (asize < 0) {
      astrm.seek(0, SEEK_END);
      asize = astrm.tell;
      if (asize < 0) throw new StreamException("invalid partial stream parameters");
      if (astart > asize) throw new StreamException("invalid partial stream parameters");
      asize -= astart;
    }
    astrm.seek(astart);
    // and now... rock-a-rolla!
    {
      // actually, we shouldn't use malloc() here, 'cause we can have alot of
      // free memory in GC and no memory for malloc(), but... let's be realistic:
      // we aren't aiming at constrained systems
      import core.exception : onOutOfMemoryError;
      import core.memory : GC;
      import core.stdc.stdlib : malloc;
      import std.conv : emplace;
      import std.traits : hasIndirections;
      alias CT = PartialStreamDataImpl!ST; // i'm lazy
      enum instSize = __traits(classInstanceSize, CT);
      // let's hope that malloc() aligns returned memory right
      auto mem = malloc(instSize);
      if (mem is null) onOutOfMemoryError(); // oops
      usize root = cast(usize)mem;
      static if (hasIndirections!ST) {
        // ouch, ST has some pointers; register it as gc root and range
        GC.addRoot(cast(void*)root);
        GC.addRange(cast(void*)root, instSize);
        enum isrng = true;
      } else {
        enum isrng = false;
      }
      mStData = emplace!CT(mem[0..instSize], astrm, astart, asize, root, isrng);
    }
  }

public:
  import core.stdc.stdio : SEEK_SET, SEEK_CUR, SEEK_END;

  immutable string name;

  // ST must support copying!
  this(ST) (string aname, auto ref ST astrm, long astart=-1, long asize=-1)
  if (isReadableStream!ST && isSeekableStream!ST)
  {
    initialize(astrm, astart, asize);
    name = aname;
  }

  this(ST) (auto ref ST astrm, long astart=-1, long asize=-1)
  if (isReadableStream!ST && isSeekableStream!ST)
  {
    initialize(astrm, astart, asize);
    name = null;
  }

  this (this) @safe nothrow @nogc { if (isOpen) mStData.incRef(); }
  ~this () => close();

  void opAssign() (auto ref PartialStreamRO src) {
    if (isOpen) {
      // assigning to opened stream
      if (src.isOpen) {
        // both streams are opened
        // we don't care if internal streams are different, our rc scheme will took care of this
        auto old = mStData; // decRef() can throw, so be on the safe side
        mStData = src.mStData;
        mStData.incRef(); // this can't throw
        old.decRef(); // release old stream
      } else {
        // just close this one
        close();
      }
    } else if (src.isOpen) {
      // this stream is closed, but other is open; easy deal
      mStData = src.mStData;
      mStData.incRef();
    }
  }

  @property bool isOpen () const pure @safe nothrow @nogc => (mStData !is null);

  void close () {
    if (isOpen) {
      mStData.decRef();
      mStData = null;
    }
  }

  @property long stofs () const @safe pure nothrow @nogc => (isOpen ? mStData.start : 0);
  @property long tell () const @safe pure nothrow @nogc => (isOpen ? mStData.curpos : 0);
  @property bool eof () const @trusted pure nothrow @nogc => (isOpen ? mStData.curpos >= mStData.size : true);

  //TODO: check for overflow
  void seek (long offset, int origin=SEEK_SET) @trusted {
    if (!isOpen) throw new StreamException("can't seek in closed partial stream");
    if (origin == SEEK_CUR) {
      offset += mStData.curpos;
    } else if (origin == SEEK_END) {
      offset = mStData.size+offset;
    }
    if (offset < 0 || offset > mStData.size) throw new StreamException("invalid offset");
    mStData.curpos = offset;
  }

  T[] rawRead(T)(T[] buf) @trusted if (isMutable!T) {
    if (!isOpen) throw new StreamException("can't read from closed partial stream");
    if (buf.length > 0) {
      auto res = mStData.read(cast(void[])buf);
      return buf[0..res.length/T.sizeof];
    } else {
      return buf[0..0];
    }
  }
}


static assert(isReadableStream!PartialStreamRO);
static assert(!isWriteableStream!PartialStreamRO);
static assert(!isRWStream!PartialStreamRO);
static assert(isSeekableStream!PartialStreamRO);
static assert(isClosableStream!PartialStreamRO);
static assert(streamHasEOF!PartialStreamRO);
static assert(streamHasSeek!PartialStreamRO);
static assert(streamHasTell!PartialStreamRO);


version(unittest_stream)
unittest {
  void rwc(T) (T stream, long pos, char ch) {
    char[1] b;
    t.seek(pos);
    auto r = t.rawRead(b);
    assert(r.length == b.length);
    assert(b[0] == ch);
  }

  auto ms = new MemoryStream();
  ms.rawWrite(cast(void[])"test");
  auto t = PartialStreamRO(ms, 1);
  {
    ubyte[1] b;
    t.seek(1);
    auto r = t.rawRead(b);
    assert(r.length == b.length);
    assert(b[0] == 's');
  }
  rwc(t, 2, 't');
  rwc(t, 0, 'e');
  t.close();
}


// ////////////////////////////////////////////////////////////////////////// //
// turn streams to ranges
// rngtype can be: "any", "read", "write"
// you can add ",indexable" to rngtype to include `opIndex()`
auto streamAsRange(string rngtype="any", STP) (auto ref STP st) if (isReadableStream!STP || isWriteableStream|STP) {
  enum {
    HasR = 0x01,
    HasW = 0x02,
    HasRW = HasR|HasW,
    HasI = 0x04
  }
  template ParseType (string s) {
    private static string get (string str) {
      usize spos = 0;
      while (spos < str.length && str[spos] <= ' ') ++spos;
      usize epos = spos;
      while (epos < str.length && str[epos] != ',') ++epos;
      while (epos > 0 && str[epos-1] <= ' ') --epos;
      return str[spos..epos];
    }
    private static string skip (string str) {
      usize spos = 0;
      while (spos < str.length && str[spos] != ',') ++spos;
      if (spos < str.length) ++spos;
      while (spos < str.length && str[spos] <= ' ') ++spos;
      return str[spos..$];
    }
    private ubyte parse (string str) {
      ubyte has;
      while (str.length > 0) {
        auto w = get(str);
        switch (w) {
          case "read": has |= HasR; break;
          case "write": has |= HasW; break;
          case "any": has |= HasR|HasW; break;
          case "indexable": has |= HasI; break;
          default:
            foreach (immutable char ch; w) {
              switch (ch) {
                case 'r': has |= HasR; break;
                case 'w': has |= HasW; break;
                case 'i': has |= HasI; break;
                default: assert(0, "invalid mode word: '"~w~"'");
              }
            }
            break;
        }
        str = skip(str);
      }
      if (has == 0) has = HasR|HasW; // any
      return has;
    }
    enum ParseType = parse(s);
  }

  enum typeflags = ParseType!(rngtype);
  // setup stream type
  static if ((typeflags&HasRW) == HasRW) {
    enum rdStream = isReadableStream!STP;
    enum wrStream = isWriteableStream!STP;
  } else static if (typeflags&HasR) {
    static assert(isReadableStream!STP, "stream must be readable");
    enum rdStream = isReadableStream!STP;
    enum wrStream = false;
  } else static if (typeflags&HasW) {
    static assert(isWriteableStream!STP, "stream must be writeable");
    enum rdStream = false;
    enum wrStream = isWriteableStream!STP;
  } else {
    static assert(0, "invalid range type: "~rngtype);
  }

  import core.stdc.stdio : SEEK_SET, SEEK_CUR, SEEK_END;

  static struct StreamRange(ST) {
  private:
    ST strm;
    static if (rdStream) {
      ubyte[1] curByte;
      bool atEof;
    }

    this(STX) (auto ref STX ast) {
      strm = ast;
      static if (rdStream) {
        atEof = true;
        // catch errors here, as `std.stdio.File` throws exception on reading from "w" files
        try {
          auto rd = strm.rawRead(curByte);
          if (rd.length != 0) atEof = false;
        } catch (Exception) {}
      }
    }

  public:
    // output range part
    static if (wrStream) {
      // `put`
      void put (in ubyte data) => strm.rawWriteExact((&data)[0..1]);
      void put (const(ubyte)[] data) => strm.rawWriteExact(data);
    }

    // input range part
    static if (rdStream) {
      // `empty`
      @property bool empty () const => atEof;

      // `length`
      static if (streamHasTell!ST && (streamHasSeek!ST || streamHasSize!ST)) {
        private enum hasRealLength = true;
        @property usize length () {
          immutable cpos = strm.tell;
          static if (streamHasSize!ST) {
            immutable sz = strm.size;
          } else {
            strm.seek(0, SEEK_END);
            immutable sz = strm.tell;
            strm.seek(cpos, SEEK_SET);
          }
          if (cpos >= sz) return 0;
          immutable len = sz-cpos;
          if (len > usize.max) {
            import core.exception : onRangeError;
            onRangeError();
          }
          return cast(usize)len;
        }
      } else {
        private enum hasRealLength = false;
      }

      // `front`
      @property ubyte front () const => curByte[0];

      // `popFront`
      void popFront () {
        curByte[0] = 0;
        if (!atEof) {
          auto res = strm.rawRead(curByte[]);
          if (res.length == 0) atEof = true;
        }
      }

      // `opIndex`
      // it's slow and unreliable
      static if ((typeflags&HasI) && streamHasTell!ST && streamHasSeek!ST && hasRealLength) {
        ubyte opIndex (usize pos) {
          import core.exception : onRangeError;
          if (pos >= this.length) onRangeError();
          immutable cpos = strm.tell;
          strm.seek(pos, SEEK_CUR);
          ubyte[1] res;
          strm.rawReadExact(res[]);
          strm.seek(cpos, SEEK_SET);
          return res[0];
        }
      }
    }
  }

  return StreamRange!STP(st);
}
