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
module iv.vfs.util;
private:

import iv.vfs : ssize, usize, Seek;
import iv.vfs.vfile;
import iv.vfs.error;
import iv.vfs.augs;


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
/// read line from stream. very slow, no recoding.
/// eolhit will be set on EOF too.
public string readLine(ST) (auto ref ST fl, bool* eolhit=null, usize maxSize=1024*1024) if (isReadableStream!ST) {
  import std.array : appender;
  bool eh;
  if (eolhit is null) eolhit = &eh;
  *eolhit = false;
  if (maxSize == 0) return null;
  auto res = appender!string();
  ubyte ch;
  for (;;) {
    static if (streamHasEof!ST) if (fl.eof) { *eolhit = true; break; }
    if (fl.rawRead((&ch)[0..1]).length == 0) { *eolhit = true; break; }
    if (ch == '\r') {
      // fuck macs
      static if (streamHasEof!ST) if (fl.eof) { *eolhit = true; break; }
      if (fl.rawRead((&ch)[0..1]).length == 0) { *eolhit = true; break; }
      if (ch == '\n') { *eolhit = true; break; }
      if (maxSize == 0) break;
      res.put('\r');
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
public VFile writef(A...) (VFile fl, const(char)[] fmt, /*lazy*/auto ref A args) {
  import std.format : formattedWrite;
  static struct Writer {
    VFile fl;
    void put (const(char)[] s...) { fl.rawWriteExact(s); }
  }
  formattedWrite(Writer(fl), fmt, args);
  return fl;
}

public VFile writefln(A...) (VFile fl, const(char)[] fmt, auto ref A args) {
  import std.format : formattedWrite;
  static struct Writer {
    VFile fl;
    void put (const(char)[] s...) { fl.rawWriteExact(s); }
  }
  formattedWrite(Writer(fl), fmt, args);
  fl.rawWriteExact("\n");
  return fl;
}

public VFile write(A...) (VFile fl, auto ref A args) {
  import std.format : formattedWrite;
  static struct Writer {
    VFile fl;
    void put (const(char)[] s...) { fl.rawWriteExact(s); }
  }
  foreach (ref a; args) formattedWrite(Writer(fl), "%s", a);
  return fl;
}

public VFile writeln(A...) (VFile fl, auto ref A args) {
  import std.format : formattedWrite;
  static struct Writer {
    VFile fl;
    void put (const(char)[] s...) { fl.rawWriteExact(s); }
  }
  foreach (ref a; args) formattedWrite(Writer(fl), "%s", a);
  fl.rawWriteExact("\n");
  return fl;
}


// ////////////////////////////////////////////////////////////////////////// //
public uint readf(A...) (VFile fl, const(char)[] fmt, A args) {
  import std.format : formattedRead;
  static struct Reader {
    VFile fl;
    char ch;
    bool eof;
    this (VFile afl) { fl = afl; if (fl.eof) eof = true; else popFront(); }
    @property bool empty () { return fl.eof; }
    @property char front () const pure nothrow @safe @nogc { pragma(inline, true); return ch; }
    void popFront() { if (!eof) { eof = (fl.rawRead((&ch)[0..1]).length == 0); } }
  }
  auto rd = Reader(fl);
  return formattedRead(rd, fmt, args);
}
