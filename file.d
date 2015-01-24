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
module iv.file is aliced;

public import std.stdio : File;


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
  foreach (auto d; path.dirName.expandTilde.buildNormalizedPath.pathSplitter) {
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
  foreach (auto d; fileName.dirName.expandTilde.buildNormalizedPath.pathSplitter) {
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


unittest {
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
