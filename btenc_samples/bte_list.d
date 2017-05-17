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
module list /*is aliced*/;

import iv.alice;
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
  import core.exception : ExitException;
  throw new ExitException();
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
