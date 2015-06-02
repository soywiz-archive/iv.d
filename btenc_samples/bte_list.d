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
module list;

import iv.btenc;


void die(A...) (string fmt, A args) {
  import std.stdio : stderr;
  static if (args.length == 0) {
    stderr.writeln("FATAL: ", fmt);
  } else {
    import std.string : format;
    auto s = format(fmt, args);
    stderr.writeln("FATAL: ", s);
  }
  version(aliced) {
    import core.exception : ExitException;
    throw new ExitException();
  } else {
    assert(0);
  }
}


void main (string[] args) {
  import std.stdio : writeln;
  if (args.length != 2) die("one argument expected");
  auto btf = BTField.load(args[1]);
  if (!btf.isDict) die("benc file is not a dictionary");
  auto info = "info" in btf;
  if (info is null) die("no \"info\" entry");
  if (!info.isDict) die("invalid \"info\" entry");
  auto name = "name" in *info;
  if (name is null) die("no \"name\" entry");
  if (!name.isStr) die("invalid \"name\" entry");
  if (auto files = "files" in *info) {
    if (!files.isList) die("invalid \"files\" entry");
    foreach (ref fi; files.vlist) {
      string fpath = name.vstr;
      if (!fi.isDict) die("invalid file entry");
      if (auto pt = "path" in fi) {
        if (!pt.isList) die("invalid \"path\" entry");
        foreach (ref dd; pt.vlist) {
          if (!dd.isStr) die("invalid \"path\" entry");
          fpath ~= "/";
          fpath ~= dd.vstr;
        }
      } else {
        die("invalid file entry");
      }
      writeln(fpath);
    }
  } else {
    writeln(name.vstr);
  }
}
