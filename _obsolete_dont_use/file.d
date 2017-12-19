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
// severely outdated case-insensitive filesystem interface
// use iv.vfs instead
module iv.file /*is aliced*/;

import iv.alice;
private import std.stdio : File;
private import iv.strex : indexOf; // rdmd sux!


/**
 * get path to real disk file, do case-insensitive search if necessary.
 * assuming that disk names are in koi8-u.
 * expands tilde too.
 *
 * Params:
 *  path = source path
 *  allOk = success flag
 *
 * Returns:
 *  found path (full or partial if `allOk` is not null)
 *  null path (if there is no such path and `allOk` is null)
 *
 * Throws:
 *  it shouldn't, but expandTilde() is not nothrow, for example
 */
string getPathCI (string path, bool* allOk=null) @trusted {
  import std.file : dirEntries, exists, SpanMode;
  import std.path : baseName, buildNormalizedPath, buildPath, CaseSensitive;
  import std.path : dirName, expandTilde, filenameCmp, isRooted, pathSplitter;

  if (allOk !is null) *allOk = false;
  path = path.expandTilde;

  // try 'as is'
  if (path.exists) {
    if (allOk !is null) *allOk = true;
    return path;
  }

  // alas, traverse dirs
  string dir;
  foreach (/*auto*/ d; path.dirName.expandTilde.buildNormalizedPath.pathSplitter) {
    if (dir.length == 0 && d.isRooted) {
      dir = d.idup;
    } else {
      string realDir = findNameCI(dir, d, true);
      if (realDir is null) return (allOk !is null ? dir : null);
      dir = buildPath(dir, realDir);
    }
  }

  // now try the last part, filename
  string pn = path.baseName;
  foreach (string fn; dirEntries((dir.length > 0 ? dir : "."), SpanMode.shallow)) {
    string n = fn.baseName;
    if (filenameCmp!(CaseSensitive.no)(n, pn) == 0) {
      if (allOk !is null) *allOk = true;
      return (dir.length == 0 ? n : fn);
    }
  }

  // no filename was found
  return (allOk !is null ? dir : null);
}


// ////////////////////////////////////////////////////////////////////////// //
// returns only file name, without path
private string findNameCI (string dir, in char[] name, bool wantDir) @trusted {
  import std.file : exists, dirEntries, SpanMode, isFile, isDir;
  import std.path : baseName, buildPath, filenameCmp, CaseSensitive;
  if (dir.length == 0) dir = ".";
  string fullName = buildPath(dir, name);
  if (fullName.exists) {
    if ((wantDir && fullName.isDir) || (!wantDir && fullName.isFile)) return name.idup;
  }
  foreach (string fn; dirEntries(dir, SpanMode.shallow)) {
    string n = fn.baseName;
    if (filenameCmp!(CaseSensitive.no)(n, name) == 0) {
      if ((wantDir && fn.isDir) || (!wantDir && fn.isFile)) return n;
    }
  }
  return null;
}


/**
 * open file using case-insensitive name in read-only mode.
 *
 * Params:
 *  fileName = file name
 *  diskName = found disk file name on success (can be relative or absolute)
 *
 * Returns:
 *  std.stdio.File
 *
 * Throws:
 *  Exception on 'file not found'
 */
File openCI (string fileName, out string diskName) @trusted {
  import std.file : exists, isFile;
  import std.path;

  // try 'as is'
  diskName = fileName;
  if (fileName.exists && fileName.isFile) {
    try return File(fileName); catch (Exception) {}
  }

  // traverse dirs
  string dir;
  foreach (/*auto*/ d; fileName.dirName.expandTilde.buildNormalizedPath.pathSplitter) {
    if (dir.length == 0 && d.isRooted) {
      dir = d.idup;
    } else {
      string realDir = findNameCI(dir, d, true);
      if (realDir is null) return File(fileName); // throw error
      dir = buildPath(dir, realDir);
    }
  }

  string name = findNameCI(dir, fileName.baseName, false);
  if (name is null) return File(fileName); // throw error

  diskName = buildPath(dir, name);
  return File(diskName);
}


/**
 * open file using case-insensitive name in read-only mode.
 *
 * Params:
 *  fileName = file name
 *
 * Returns:
 *  std.stdio.File
 *
 * Throws:
 *  Exception on 'file not found'
 */
File openCI (string fileName) @trusted {
  string dn;
  return openCI(fileName, dn);
}


version(test_file) unittest {
  import std.file, std.path, std.stdio;
  string md = getcwd().dirName;
  writeln(md);
  bool ok;
  string r;
  r = getPathCI(md~"/IV/file.D", &ok);
  writeln(ok, " ", r);
  r = getPathCI(md~"/IV/filez.D", &ok);
  writeln(ok, " ", r);
  r = getPathCI(md~"/IVz/file.D", &ok);
  writeln(ok, " ", r);
  writeln(getPathCI(md~"/IV/file.D"));
  writeln(getPathCI(md~"/IV/filez.D"));
  writeln(getPathCI(md~"/IVz/file.D"));
}


// the following code was taken from https://github.com/nordlow/justd/blob/master/bylinefast.d
/**
 * Reads by line in an efficient way (10 times faster than File.byLine from
 * std.stdio).  This is accomplished by reading entire buffers (fgetc() is not
 * used), and allocating as little as possible.
 *
 * The char \n is considered as default separator, removing the previous \r if
 * it exists.
 *
 * The \n is never returned. The \r is not returned if it was
 * part of a \r\n (but it is returned if it was by itself).
 *
 * The returned string is always a substring of a temporary buffer, that must
 * not be stored. If necessary, you must use str[] or .dup or .idup to copy to
 * another string. DIP-25 return qualifier is used in front() to add extra
 * checks in @safe callers of front().
 *
 * Example:
 *
 * File f = File("file.txt");
 * foreach (string line; ByLineFast(f)) {
 * ...process line...
 * //Make a copy:
 * string copy = line[];
 * }
 *
 * The file isn't closed when done iterating, unless it was the only reference to
 * the file (same as std.stdio.byLine). (example: ByLineFast(File("file.txt"))).
 */
struct ByLineFast(Char, Terminator) {
  File file;
  char[] line;
  bool firstCall = true;
  char[] buffer;
  char[] strBuffer;
  const string separator;
  bool keepTerminator;

  this (File f, bool keepTerminator=false, string separator="\n", uint bufferSize=4096) @safe {
    assert(bufferSize > 0);
    file = f;
    this.separator = separator;
    this.keepTerminator = keepTerminator;
    buffer.length = bufferSize;
  }

  @property bool empty () const @trusted {
    import std.stdio : fgetc, ungetc;
    // Its important to check "line !is null" instead of
    // "line.length != 0", otherwise, no empty lines can
    // be returned, the iteration would be closed.
    if (line !is null) return false;
    if (!file.isOpen) {
      // Clean the buffer to avoid pointer false positives:
      (cast(char[])buffer)[] = 0;
      return true;
    }
    // First read. Determine if it's empty and put the char back.
    auto mutableFP = (cast(File*)&file).getFP();
    const c = fgetc(mutableFP);
    if (c == -1) {
      // Clean the buffer to avoid pointer false positives:
      (cast(char[])buffer)[] = 0;
      return true;
    }
    if (ungetc(c, mutableFP) != c) assert(false, "Bug in cstdlib implementation");
    return false;
  }

  @property char[] front() @safe /*return*//*DIP-25*/ {
    if (firstCall) {
      popFront();
      firstCall = false;
    }
    return line;
  }

  void popFront() @trusted {
    import iv.strex : indexOf;

    if (strBuffer.length == 0) {
      strBuffer = file.rawRead(buffer);
      if (strBuffer.length == 0) {
        file.detach();
        line = null;
        return;
      }
    }

    const pos = indexOf(strBuffer, this.separator);
    if (pos != -1) {
      if (pos != 0 && strBuffer[pos-1] == '\r') {
        line = strBuffer[0..pos-1];
      } else {
        line = strBuffer[0..pos];
      }
      // Pop the line, skipping the terminator:
      strBuffer = strBuffer[pos+1..$];
    } else {
      // More needs to be read here. Copy the tail of the buffer
      // to the beginning, and try to read with the empty part of
      // the buffer.
      // If no buffer was left, extend the size of the buffer before
      // reading. If the file has ended, then the line is the entire
      // buffer.
      if (strBuffer.ptr != buffer.ptr) {
        import core.stdc.string: memmove;
        // Must use memmove because there might be overlap
        memmove(buffer.ptr, strBuffer.ptr, strBuffer.length*char.sizeof);
      }
      const spaceBegin = strBuffer.length;
      if (strBuffer.length == buffer.length) {
        // Must extend the buffer to keep reading.
        assumeSafeAppend(buffer);
        buffer.length = buffer.length*2;
      }
      const readPart = file.rawRead(buffer[spaceBegin..$]);
      if (readPart.length == 0) {
        // End of the file. Return whats in the buffer.
        // The next popFront() will try to read again, and then
        // mark empty condition.
        if (spaceBegin != 0 && buffer[spaceBegin-1] == '\r') {
          line = buffer[0..spaceBegin-1];
        } else {
          line = buffer[0..spaceBegin];
        }
        strBuffer = null;
        return;
      }
      strBuffer = buffer[0..spaceBegin+readPart.length];
      // Now that we have new data in strBuffer, we can go on.
      // If a line isn't found, the buffer will be extended again to read more.
      popFront();
    }
  }
}

auto byLineFast(Terminator=char, Char=char) (File f,
                           bool keepTerminator=false,
                           string separator="\n",
                           uint bufferSize=4096) @safe // TODO lookup preferred block type
{
  return ByLineFast!(Char, Terminator)(f, keepTerminator, separator, bufferSize);
}


version(test_file) unittest {
  import std.stdio: File, writeln;
  import std.algorithm.searching: count;
  const path = "/etc/passwd";
  assert(File(path).byLineFast.count == File(path).byLine.count);
}

version(test_file) @safe unittest {
  import std.stdio: File;
  const path = "/etc/passwd";
  char[] mutable_line;
  foreach (line; File(path).byLineFast) {
    mutable_line = line; // TODO this should fail
  }
  {
    auto byline = File(path).byLineFast;
    mutable_line = byline.front; // TODO this should fail
  }
}

version(none) unittest {
  import std.stdio: File, writeln;
  import std.algorithm.searching: count;
  const path = "/home/ketmar/muldict.txt";
  import std.datetime: StopWatch;
  double d1, d2;
  {
    StopWatch sw;
    sw.start;
    const c1 = File(path).byLine.count;
    sw.stop;
    d1 = sw.peek.msecs;
    writeln("byLine: ", d1, "msecs");
  }
  {
    StopWatch sw;
    sw.start;
    const c2 = File(path).byLineFast.count;
    sw.stop;
    d2 = sw.peek.msecs;
    writeln("byLineFast: ", d2, "msecs");
  }
  writeln("Speed-Up: ", d1 / d2);
}
