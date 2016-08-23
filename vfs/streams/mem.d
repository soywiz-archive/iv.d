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
module iv.vfs.streams.mem;

private import iv.vfs.internal : ssize, usize, Seek;
private import iv.vfs.error;
private import iv.vfs.augs;


// ////////////////////////////////////////////////////////////////////////// //
// not thread-safe
public struct MemoryStreamRW {
private:
  ubyte[] data;
  usize curpos;
  bool eofhit;
  bool closed = false;

public:
  static if (usize.sizeof == 4) {
    enum MaxSize = 0x7fff_ffffU;
  } else {
    enum MaxSize = 0x7fff_ffff_ffff_ffffUL;
  }

public:
  this (const(void)[] adata) @trusted {
    if (adata.length > MaxSize) throw new VFSException("buffer too big");
    data = cast(typeof(data))(adata.dup);
  }

  @property const(ubyte)[] bytes () pure nothrow @safe @nogc { pragma(inline, true); return data; }

  @property long size () const pure nothrow @safe @nogc { pragma(inline, true); return data.length; }
  @property long tell () const pure nothrow @safe @nogc { pragma(inline, true); return curpos; }
  @property bool eof () const pure nothrow @trusted @nogc { pragma(inline, true); return eofhit; }
  @property bool isOpen () const pure nothrow @trusted @nogc { pragma(inline, true); return !closed; }

  void seek (long offset, int origin=Seek.Set) @trusted {
    if (closed) throw new VFSException("can't seek in closed stream");
    switch (origin) {
      case Seek.Set:
        if (offset < 0 || offset > MaxSize) throw new VFSException("invalid offset");
        curpos = cast(usize)offset;
        break;
      case Seek.Cur:
        if (offset < -cast(long)curpos || offset > MaxSize-curpos) throw new VFSException("invalid offset");
        curpos += offset;
        break;
      case Seek.End:
        if (offset < -cast(long)data.length || offset > MaxSize-data.length) throw new VFSException("invalid offset");
        curpos = cast(usize)(cast(long)data.length+offset);
        break;
      default: throw new VFSException("invalid offset origin");
    }
    eofhit = false;
  }

  ssize read (void* buf, usize count) {
    if (closed) return -1;
    if (curpos >= data.length) { eofhit = true; return 0; }
    if (count > 0) {
      import core.stdc.string : memcpy;
      usize rlen = data.length-curpos;
      if (rlen >= count) rlen = count; else eofhit = true;
      assert(rlen != 0);
      memcpy(buf, data.ptr+curpos, rlen);
      curpos += rlen;
      return cast(ssize)rlen;
    } else {
      return 0;
    }
  }

  ssize write (in void* buf, usize count) {
    import core.stdc.string : memcpy;
    if (closed) return -1;
    if (count == 0) return 0;
    if (count > MaxSize-curpos) return -1;
    if (data.length < curpos+count) data.length = curpos+count;
    memcpy(data.ptr+curpos, buf, count);
    curpos += count;
    return count;
  }

  void close () pure nothrow @safe @nogc { curpos = 0; data = null; eofhit = true; closed = true; }
}


// ////////////////////////////////////////////////////////////////////////// //
// not thread-safe
public struct MemoryStreamRO {
private:
  const(ubyte)[] data;
  usize curpos;
  bool eofhit;

public:
  static if (usize.sizeof == 4) {
    enum MaxSize = 0x7fff_ffffU;
  } else {
    enum MaxSize = 0x7fff_ffff_ffff_ffffUL;
  }

public:
  this (const(void)[] adata) @trusted {
    if (adata.length > MaxSize) throw new VFSException("buffer too big");
    data = cast(typeof(data))adata;
  }

  @property const(ubyte)[] bytes () pure nothrow @safe @nogc { pragma(inline, true); return data; }

  @property long size () const pure nothrow @safe @nogc { pragma(inline, true); return data.length; }
  @property long tell () const pure nothrow @safe @nogc { pragma(inline, true); return curpos; }
  @property bool eof () const pure nothrow @trusted @nogc { pragma(inline, true); return eofhit; }
  @property bool isOpen () const pure nothrow @trusted @nogc { pragma(inline, true); return (data !is null); }

  void seek (long offset, int origin=Seek.Set) @trusted {
    switch (origin) {
      case Seek.Set:
        if (offset < 0 || offset > MaxSize) throw new VFSException("invalid offset");
        curpos = cast(usize)offset;
        break;
      case Seek.Cur:
        if (offset < -cast(long)curpos || offset > MaxSize-curpos) throw new VFSException("invalid offset");
        curpos += offset;
        break;
      case Seek.End:
        if (offset < -cast(long)data.length || offset > MaxSize-data.length) throw new VFSException("invalid offset");
        curpos = cast(usize)(cast(long)data.length+offset);
        break;
      default: throw new VFSException("invalid offset origin");
    }
    eofhit = false;
  }

  ssize read (void* buf, usize count) {
    if (curpos >= data.length) { eofhit = true; return 0; }
    if (count > 0) {
      import core.stdc.string : memcpy;
      usize rlen = data.length-curpos;
      if (rlen >= count) rlen = count; else eofhit = true;
      assert(rlen != 0);
      memcpy(buf, data.ptr+curpos, rlen);
      curpos += rlen;
      return cast(ssize)rlen;
    } else {
      return 0;
    }
  }

  void close () pure nothrow @safe @nogc { curpos = 0; data = null; }
}


// ////////////////////////////////////////////////////////////////////////// //
version(vfs_test_stream) {
  import std.stdio : File, stdout;

  private void dump (const(ubyte)[] data, File fl=stdout) @trusted {
    for (usize ofs = 0; ofs < data.length; ofs += 16) {
      fl.writef("%04X:", ofs);
      foreach (immutable i; 0..16) {
        if (i == 8) fl.write(' ');
        if (ofs+i < data.length) fl.writef(" %02X", data[ofs+i]); else fl.write("   ");
      }
      fl.write(" ");
      foreach (immutable i; 0..16) {
        if (ofs+i >= data.length) break;
        if (i == 8) fl.write(' ');
        ubyte b = data[ofs+i];
        if (b <= 32 || b >= 127) fl.write('.'); else fl.writef("%c", cast(char)b);
      }
      fl.writeln();
    }
  }

  static assert(isReadableStream!MemoryStreamRO);
  static assert(!isWriteableStream!MemoryStreamRO);
  static assert(!isRWStream!MemoryStreamRO);
  static assert(isSeekableStream!MemoryStreamRO);
  static assert(streamHasClose!MemoryStreamRO);
  static assert(streamHasEof!MemoryStreamRO);
  static assert(streamHasSeek!MemoryStreamRO);
  static assert(streamHasTell!MemoryStreamRO);
  static assert(streamHasSize!MemoryStreamRO);

  unittest {
    {
      auto ms = MemoryStreamRW();
      ms.rawWrite("hello");
      assert(!ms.eof);
      assert(ms.data == cast(ubyte[])"hello");
      //dump(ms.data);
      ushort[3] d;
      ms.seek(0);
      assert(!ms.eof);
      assert(ms.rawRead(d[0..2]).length == 2);
      assert(!ms.eof);
      assert(d == [0x6568, 0x6c6c, 0]);
      ms.seek(1);
      assert(ms.rawRead(d[0..2]).length == 2);
      assert(d == [0x6c65, 0x6f6c, 0]);
      assert(!ms.eof);
      //dump(cast(ubyte[])d);
    }
    {
      auto ms = new MemoryStreamRW();
      wchar[] a = ['\u0401', '\u0280', '\u089e'];
      ms.rawWrite(a);
      assert(ms.bytes == cast(const(ubyte)[])x"01 04 80 02 9E 08");
      //dump(ms.data);
    }
    {
      auto ms = MemoryStreamRO("hello");
      assert(ms.data == cast(const(ubyte)[])"hello");
    }
  }
}
