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
/**
 * wrap any low-level (or high-level) stream into refcounted struct.
 * this struct can be used instead of `std.stdio.File` when you need
 * a concrete type instead of working with generic stream templates.
 * wrapped stream is thread-safe (i.e. reads, writes, etc), but
 * wrapper itself isn't.
 */
module iv.vfs.io;
private:

import iv.vfs.augs;
import iv.vfs.error;
import iv.vfs.vfile;


// ////////////////////////////////////////////////////////////////////////// //
/// read 0-terminated string from stream. very slow, no recoding.
/// eolhit will be set on EOF too.
public string readZString(ST) (auto ref ST fl, bool* eolhit=null, usize maxSize=1024*1024) if (isReadableStream!ST) {
  import std.array : appender;
  bool eh;
  if (eolhit is null) eolhit = &eh;
  *eolhit = false;
  if (maxSize == 0) return null;
  auto res = appender!string();
  ubyte ch;
  for (;;) {
    if (fl.rawRead((&ch)[0..1]).length == 0) { *eolhit = true; break; }
    if (ch == 0) { *eolhit = true; break; }
    if (maxSize == 0) break;
    res.put(cast(char)ch);
    --maxSize;
  }
  return res.data;
}


// ////////////////////////////////////////////////////////////////////////// //
/// read stream line by line. very slow, no recoding.
// hack around "has scoped destruction, cannot build closure"
public auto byLineCopy(bool keepTerm=false) (VFile fl) { return byLineCopyImpl!keepTerm(fl); }
public auto byLineCopy(bool keepTerm=false, ST) (auto ref ST fl) if (!is(ST == VFile) && isReadableStream!ST) { return byLineCopyImpl!keepTerm(fl); }

public auto byLine(bool keepTerm=false) (VFile fl) { return byLineCopyImpl!(keepTerm, true)(fl); }
public auto byLine(bool keepTerm=false, ST) (auto ref ST fl) if (!is(ST == VFile) && isReadableStream!ST) { return byLineCopyImpl!(keepTerm, true)(fl); }

private auto byLineCopyImpl(bool keepTerm=false, bool reuseBuffer=false, ST) (auto ref ST fl) {
  static struct BLR(bool keepTerm, bool reuse, ST) {
  private:
    ST st;
    bool eof, futureeof;
    static if (reuse) {
      char[] buf;
      size_t bufused;
    } else {
      string fs;
    }
  private:
    this() (auto ref ST ast) {
      st = ast;
      if (st.eof) eof = true; else popFront();
    }
  public:
    @property bool empty () const pure nothrow @safe @nogc { pragma(inline, true); return eof; }
    @property auto front () { static if (reuse) return buf[0..bufused]; else return fs; }
    void popFront () {
      if (futureeof) { eof = futureeof; futureeof = false; return; }
      if (!eof) {
        char ch;
        static if (reuse) bufused = 0; else char[] buf;
        for (;;) {
          if (st.rawRead((&ch)[0..1]).length == 0) {
            static if (reuse) {
              if (bufused == 0) { eof = true; return; }
            } else {
              if (buf.length == 0) { eof = true; return; }
            }
            break;
          }
          if (ch == '\r') {
            // fuck macs
            if (st.rawRead((&ch)[0..1]).length == 0) {
              static if (keepTerm) {
                static if (reuse) { if (bufused == buf.length) { buf ~= ch; ++bufused; } else buf.ptr[bufused++] = ch; } else buf ~= ch;
              }
              break;
            }
            if (ch == '\n') {
              static if (keepTerm) {
                static if (reuse) { if (bufused == buf.length) { buf ~= ch; ++bufused; } else buf.ptr[bufused++] = ch; } else buf ~= ch;
              }
              break;
            }
            buf ~= ch;
          } else if (ch == '\n') {
            static if (keepTerm) {
              static if (reuse) { if (bufused == buf.length) { buf ~= ch; ++bufused; } else buf.ptr[bufused++] = ch; } else buf ~= ch;
            }
            break;
          }
          static if (reuse) { if (bufused == buf.length) { buf ~= ch; ++bufused; } else buf.ptr[bufused++] = ch; } else buf ~= ch;
        }
        static if (!reuse) fs = cast(string)buf; // it is safe to cast here
      }
    }
  }
  return BLR!(keepTerm, reuseBuffer, ST)(fl);
}


// ////////////////////////////////////////////////////////////////////////// //
// hack around "has scoped destruction, cannot build closure"
public void write(A...) (VFile fl, auto ref A args) { return writeImpl!(false)(fl, args); }
public void write(ST, A...) (auto ref ST fl, auto ref A args) if (!is(ST == VFile) && isReadableStream!ST) { return writeImpl!(false, ST)(fl, args); }
public void writeln(A...) (VFile fl, auto ref A args) { return writeImpl!(true)(fl, args); }
public void writeln(ST, A...) (auto ref ST fl, auto ref A args) if (!is(ST == VFile) && isReadableStream!ST) { return writeImpl!(true, ST)(fl, args); }

public void writef(Char:dchar, A...) (VFile fl, const(Char)[] fmt, auto ref A args) { return writefImpl!(false, Char)(fl, fmt, args); }
public void writef(ST, Char:dchar, A...) (auto ref ST fl, const(Char)[] fmt, auto ref A args) if (!is(ST == VFile) && isReadableStream!ST) { return writefImpl!(false, Char, ST)(fl, fmt, args); }
public void writefln(Char:dchar, A...) (VFile fl, const(Char)[] fmt, auto ref A args) { return writefImpl!(true, Char)(fl, fmt, args); }
public void writefln(ST, Char:dchar, A...) (auto ref ST fl, const(Char)[] fmt, auto ref A args) if (!is(ST == VFile) && isReadableStream!ST) { return writefImpl!(true, Char, ST)(fl, fmt, args); }


// ////////////////////////////////////////////////////////////////////////// //
private void writeImpl(bool donl, ST, A...) (auto ref ST fl, auto ref A args) {
  import std.format : formattedWrite;
  static struct Writer(ST) {
    ST fl;
    this() (auto ref ST afl) { fl = afl; }
    void put (const(char)[] s...) { fl.rawWriteExact(s); }
  }
  auto wr = Writer!ST(fl);
  foreach (ref a; args) formattedWrite(wr, "%s", a);
  static if (donl) fl.rawWriteExact("\n");
}

private void writefImpl(bool donl, Char, ST, A...) (auto ref ST fl, const(Char)[] fmt, auto ref A args) {
  import std.format : formattedWrite;
  static struct Writer(ST) {
    ST fl;
    this() (auto ref ST afl) { fl = afl; }
    void put (const(char)[] s...) { fl.rawWriteExact(s); }
  }
  auto wr = Writer!ST(fl);
  formattedWrite(wr, fmt, args);
  static if (donl) fl.rawWriteExact("\n");
}


// ////////////////////////////////////////////////////////////////////////// //
public auto readf(Char:dchar, A...) (VFile fl, const(Char)[] fmt, auto ref A args) { return readfImpl!(Char)(fl, fmt, args); }
public auto readf(ST, Char:dchar, A...) (auto ref ST fl, const(Char)[] fmt, auto ref A args) if (!is(ST == VFile) && isReadableStream!ST) { return readfImpl!(Char, ST)(fl, fmt, args); }

private auto readfImpl(Char:dchar, ST, A...) (auto ref ST fl, const(Char)[] fmt, A args) {
  import std.format : formattedRead;
  static struct Reader(ST) {
    ST fl;
    char ch;
    bool eof;
    this() (auto ref ST afl) { fl = afl; if (fl.eof) eof = true; else popFront(); }
    @property bool empty () const pure nothrow @safe @nogc { pragma(inline, true); return eof; }
    @property char front () const pure nothrow @safe @nogc { pragma(inline, true); return ch; }
    void popFront() { if (!eof) { eof = (fl.rawRead((&ch)[0..1]).length == 0); } }
  }
  auto rd = Reader!ST(fl);
  return formattedRead(rd, fmt, args);
}
