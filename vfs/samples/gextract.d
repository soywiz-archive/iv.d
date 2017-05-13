#!/usr/bin/env rdmd
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
import iv.vfs.io;

public import iv.vfs.arc.abuse;
public import iv.vfs.arc.arcanum;
public import iv.vfs.arc.arcz;
public import iv.vfs.arc.bsa;
//public import iv.vfs.arc.dfwad; // just get lost
//public import iv.vfs.arc.dunepak; no signature
//public import iv.vfs.arc.f2dat; // no signature
//public import iv.vfs.arc.toeedat; // conflicts with arcanum
public import iv.vfs.arc.wad2;


void main (string[] args) {
  import std.file : mkdirRecurse;
  import std.path : dirName;

  if (args.length < 3) assert(0, "PAK?");

  string aname = args[1];
  try {
    vfsAddPak(aname);
  } catch (Exception e) {
    writeln("ERROR adding archive '", aname, "'!");
    throw e;
  }

  auto buf = new ubyte[](1024*1024);

  foreach (string fname; args[2..$]) {
    write("extracting '", fname, "' ... ");
    try {
      auto fl = VFile(fname);
      write(fl.size, " ");
      string destname = "_unp/"~fname;
      mkdirRecurse(destname.dirName);
      auto fo = VFile(destname, "w");
      for (;;) {
        auto rd = fl.rawRead(buf);
        if (rd.length == 0) break;
        fo.rawWriteExact(rd);
      }
      writeln("OK");
    } catch (Exception e) {
      writeln("ERROR!");
      writeln(e.toString);
    }
  }
}
