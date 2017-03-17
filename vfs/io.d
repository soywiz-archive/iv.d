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

public import iv.vfs;
//import iv.vfs.augs;
//import iv.vfs.error;
//import iv.vfs.vfile;


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
public auto byLineCopy(bool keepTerm=false, ST) (auto ref ST fl) if (!is(ST == VFile) && isRorWStream!ST) { return byLineCopyImpl!keepTerm(fl); }

public auto byLine(bool keepTerm=false) (VFile fl) { return byLineCopyImpl!(keepTerm, true)(fl); }
public auto byLine(bool keepTerm=false, ST) (auto ref ST fl) if (!is(ST == VFile) && isRorWStream!ST) { return byLineCopyImpl!(keepTerm, true)(fl); }

private auto byLineCopyImpl(bool keepTerm=false, bool reuseBuffer=false, ST) (auto ref ST fl) {
  static struct BLR(bool keepTerm, bool reuse, ST) {
  private:
    ST st;
    bool eof, futureeof;
    char[128] rdbuf;
    int rdpos, rdsize;
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
    @property auto front () inout nothrow @safe @nogc { static if (reuse) return buf[0..bufused]; else return fs; }
    void popFront () {
      char getch () {
        assert(!futureeof);
        if (rdpos >= rdsize) {
          rdpos = rdsize = 0;
          auto rd = st.rawRead(rdbuf[]);
          if (rd.length == 0) { futureeof = true; return 0; }
          rdsize = cast(int)rd.length;
        }
        assert(rdpos < rdsize);
        return rdbuf.ptr[rdpos++];
      }
      void putch (char ch) {
        static if (reuse) {
          if (bufused == buf.length) {
            auto optr = buf.ptr;
            buf ~= ch;
            if (buf.ptr !is optr) {
              import core.memory : GC;
              if (buf.ptr is GC.addrOf(buf.ptr)) GC.setAttr(buf.ptr, GC.BlkAttr.NO_INTERIOR);
            }
            ++bufused;
          } else {
            buf.ptr[bufused++] = ch;
          }
        } else {
          s ~= ch;
        }
      }
      if (futureeof) { eof = true; futureeof = false; }
      static if (reuse) bufused = 0; else s = null;
      if (eof) return;
      bool wasChar = false;
      for (;;) {
        char ch = getch();
        if (futureeof) break;
        wasChar = true;
        if (ch == '\r') {
          // cr
          ch = getch();
          if (futureeof) {
            static if (keepTerm) putch('\r');
            break;
          }
          if (ch == '\n') {
            static if (keepTerm) { putch('\r'); putch('\n'); }
            break;
          }
        } else if (ch == '\n') {
          // lf
          static if (keepTerm) putch('\n');
          break;
        }
        putch(ch);
      }
      if (!wasChar) { assert(futureeof); futureeof = false; eof = true; }
    }
  }
  return BLR!(keepTerm, reuseBuffer, ST)(fl);
}


// ////////////////////////////////////////////////////////////////////////// //
// hack around "has scoped destruction, cannot build closure"
public void write(A...) (VFile fl, A args) { writeImpl!(false)(fl, args); }
public void write(ST, A...) (auto ref ST fl, A args) if (!is(ST == VFile) && isRorWStream!ST) { writeImpl!(false, ST)(fl, args); }
public void writeln(A...) (VFile fl, A args) { writeImpl!(true)(fl, args); }
public void writeln(ST, A...) (auto ref ST fl, A args) if (!is(ST == VFile) && isRorWStream!ST) { writeImpl!(true, ST)(fl, args); }

public void writef(Char:dchar, A...) (VFile fl, const(Char)[] fmt, A args) { writefImpl!(false, Char)(fl, fmt, args); }
public void writef(ST, Char:dchar, A...) (auto ref ST fl, const(Char)[] fmt, A args) if (!is(ST == VFile) && isRorWStream!ST) { writefImpl!(false, Char, ST)(fl, fmt, args); }
public void writefln(Char:dchar, A...) (VFile fl, const(Char)[] fmt, A args) { writefImpl!(true, Char)(fl, fmt, args); }
public void writefln(ST, Char:dchar, A...) (auto ref ST fl, const(Char)[] fmt, A args) if (!is(ST == VFile) && isRorWStream!ST) { writefImpl!(true, Char, ST)(fl, fmt, args); }


// ////////////////////////////////////////////////////////////////////////// //
private void writeImpl(bool donl, ST, A...) (auto ref ST fl, A args) {
  import std.format : formattedWrite;
  static struct Writer(ST) {
    ST fl;
    this() (auto ref ST afl) { fl = afl; }
    void put (const(char)[] s...) { fl.rawWriteExact(s); }
  }
  auto wr = Writer!ST(fl);
  foreach (a; args) formattedWrite(wr, "%s", a);
  static if (donl) fl.rawWriteExact("\n");
}

private void writefImpl(bool donl, Char, ST, A...) (auto ref ST fl, const(Char)[] fmt, A args) {
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
public auto readf(Char:dchar, A...) (VFile fl, const(Char)[] fmt, A args) { return readfImpl!(Char)(fl, fmt, args); }
public auto readf(ST, Char:dchar, A...) (auto ref ST fl, const(Char)[] fmt, A args) if (!is(ST == VFile) && isRorWStream!ST) { return readfImpl!(Char, ST)(fl, fmt, args); }

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


// ////////////////////////////////////////////////////////////////////////// //
public string readln() (VFile fl) { return readlnImpl(fl); }
public string readln(ST) (auto ref ST fl) if (!is(ST == VFile) && isRorWStream!ST) { return readlnImpl!ST(fl); }

// slow, but IDC
private string readlnImpl(ST) (auto ref ST fl) {
  enum MaxLen = 65536;
  if (fl.eof) return null;
  char[] res;
  char ch;
  for (;;) {
    if (fl.rawRead((&ch)[0..1]).length != 1) break;
    if (ch == '\n') break;
    if (ch == '\r') {
      if (fl.rawRead((&ch)[0..1]).length != 1) break;
      if (ch == '\n') break;
      if (res.length == MaxLen) throw new Exception("line too long");
      res ~= '\r';
    }
    if (res.length == MaxLen) throw new Exception("line too long");
    res ~= ch;
  }
  return cast(string)res; // it is safe to cast here
}


// ////////////////////////////////////////////////////////////////////////// //
// aaaaah, let's conflict with std.stdio!
public __gshared VFile stdin, stdout, stderr;

shared static this () {
  debug(vfs_rc) { import core.stdc.stdio : printf; printf("******** SHARED CTOR FOR iv.vfs.io\n"); }
  stdin = wrapStdin;
  stdout = wrapStdout;
  stderr = wrapStderr;
}


public void write(A...) (A args) if (A.length == 0) {}
public void write(A...) (A args) if (A.length > 0 && !isRorWStream!(A[0])) { writeImpl!false(stdout, args); }
public void writeln(A...) (A args) if (A.length == 0) { stdout.rawWriteExact("\n"); }
public void writeln(A...) (A args) if (A.length > 0 && !isRorWStream!(A[0])) { writeImpl!true(stdout, args); }

public void writef(Char:dchar, A...) (const(Char)[] fmt, A args) if (A.length == 0) {}
public void writef(Char:dchar, A...) (const(Char)[] fmt, A args) if (A.length > 0 && !isRorWStream!(A[0])) { return writefImpl!(false, Char)(stdout, fmt, args); }
public void writefln(Char:dchar, A...) (const(Char)[] fmt, A args) if (A.length == 0) { stdout.rawWriteExact("\n"); }
public void writefln(Char:dchar, A...) (const(Char)[] fmt, A args) if (A.length > 0 && !isRorWStream!(A[0])) { return writefImpl!(true, Char)(stdout, fmt, args); }

public string readln() () { return readlnImpl(stdin); }
