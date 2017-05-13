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
// stream predicates
module iv.vfs.pred;

private import iv.vfs.types : ssize, usize;
public import iv.vfs.types : Seek;
public import iv.vfs.error;


// ////////////////////////////////////////////////////////////////////////// //
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

/// check if a given stream supports both reading and writing
enum isRorWStream(T) = isReadableStream!T || isWriteableStream!T;

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
