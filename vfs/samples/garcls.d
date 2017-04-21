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

public import iv.vfs.arcs.abuse;
public import iv.vfs.arcs.arcanum;
public import iv.vfs.arcs.arcz;
public import iv.vfs.arcs.bsa;
//public import iv.vfs.arcs.dfwad; // just get lost
//public import iv.vfs.arcs.dunepak; no signature
//public import iv.vfs.arcs.f2dat; // no signature
//public import iv.vfs.arcs.toeedat; // conflicts with arcanum
public import iv.vfs.arcs.wad2;


void main (string[] args) {
  if (args.length == 1) assert(0, "PAK?");

  foreach (immutable idx, string aname; args[1..$]) {
    import std.format : format;
    try {
      vfsAddPak(aname, "a%03s:".format(idx));
    } catch (Exception e) {
      writeln("ERROR adding archive '", aname, "'!");
      throw e;
    }
  }

  writeln("   size     packedsz   name");
  writeln("---------- ----------  -------");

  vfsForEachFile((in ref de) {
    writefln("%10s %10s  %s", de.size, de.stat("pksize").get!long, de.name);
  });
}
