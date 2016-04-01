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
module iv.vfs.arcs.dunepak;

import iv.vfs : usize, ssize, Seek;
import iv.vfs.augs;
import iv.vfs.main;
import iv.vfs.vfile;


// ////////////////////////////////////////////////////////////////////////// //
private import iv.vfs.arcs : VFSSimpleArchiveDetectorMixin;
mixin(VFSSimpleArchiveDetectorMixin!"Dune2Pak");


// ////////////////////////////////////////////////////////////////////////// //
public final class VFSDriverDune2Pak : VFSDriver {
  private import iv.vfs.arcs : VFSSimpleArchiveDriverMixin;
  mixin VFSSimpleArchiveDriverMixin;

private:
  static struct FileInfo {
    long size;
    long ofs; // offset in archive
    string name; // with path
  }

  VFile wrap (usize idx) { return wrapStreamRO(st, dir[idx].ofs, dir[idx].size); }

  void open (VFile fl, const(char)[] prefixpath) {
    debug(dunepakarc) import std.stdio : writeln, writefln;
    ulong flsize = fl.size;
    if (flsize > 0xffff_ffffu) throw new VFSNamedException!"DunePakArchive"("file too big");
    // read directory
    uint prevofs = uint.max;
    for (;;) {
      auto ofs = fl.readNum!uint;
      if (ofs == 0) break;
      if (ofs >= flsize) throw new VFSNamedException!"DunePakArchive"("invalid directory");
      char[] name;
      {
        name = new char[](prefixpath.length+16);
        usize nbpos = prefixpath.length;
        if (nbpos) name[0..nbpos] = prefixpath[];
        char ch;
        int left = 12;
        for (;;) {
          fl.rawReadExact((&ch)[0..1]);
          if (ch == 0) break;
          if (--left < 0) throw new VFSNamedException!"DunePakArchive"("invalid directory");
          if (ch == '\\' || ch == '/' || ch > 127) throw new VFSNamedException!"DunePakArchive"("invalid directory");
          name.ptr[nbpos++] = ch;
        }
        if (left == 12) throw new VFSNamedException!"DunePakArchive"("invalid directory");
        name = name[0..nbpos];
      }
      debug(dunepakarc) writefln("[%s]: ofs=0x%08x", name, ofs);
      FileInfo fi;
      fi.ofs = ofs;
      if (prevofs != uint.max) {
        if (dir[$-1].ofs > ofs) throw new VFSNamedException!"DunePakArchive"("invalid directory");
        dir[$-1].size = ofs-dir[$-1].ofs;
        // some sanity checks
        if (dir[$-1].size > 0 && dir[$-1].ofs >= flsize || dir[$-1].size > flsize) throw new VFSNamedException!"DunePakArchive"("invalid directory");
        if (dir[$-1].ofs+dir[$-1].size > flsize) throw new VFSNamedException!"DunePakArchive"("invalid directory");
      }
      fi.name = cast(string)name; // it's safe here
      dir ~= fi;
      prevofs = ofs;
    }
    if (dir.length) {
      // fix last file
      if (dir[$-1].ofs > flsize) throw new VFSNamedException!"DunePakArchive"("invalid directory");
      dir[$-1].size = flsize-dir[$-1].ofs;
      // some sanity checks
      if (dir[$-1].size > 0 && dir[$-1].ofs >= flsize || dir[$-1].size > flsize) throw new VFSNamedException!"DunePakArchive"("invalid directory");
      if (dir[$-1].ofs+dir[$-1].size > flsize) throw new VFSNamedException!"DunePakArchive"("invalid directory");
    }
    debug(dunepakarc) writeln(dir.length, " files found");
  }
}
