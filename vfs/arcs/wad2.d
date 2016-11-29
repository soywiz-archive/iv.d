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
module iv.vfs.arcs.wad2;

import iv.vfs.types : usize, ssize, Seek;
import iv.vfs.augs;
import iv.vfs.main;
import iv.vfs.vfile;


// ////////////////////////////////////////////////////////////////////////// //
private import iv.vfs.arcs.internal : VFSSimpleArchiveDetectorMixin;
mixin(VFSSimpleArchiveDetectorMixin!"Wad2");


// ////////////////////////////////////////////////////////////////////////// //
public final class VFSDriverWad2 : VFSDriver {
  private import iv.vfs.arcs.internal : VFSSimpleArchiveDriverMixin;
  mixin VFSSimpleArchiveDriverMixin;

private:
  static struct FileInfo {
    long size;
    long ofs; // offset in archive
    string name; // with path
  }

  VFile wrap (usize idx) { return wrapStreamRO(st, dir[idx].ofs, dir[idx].size, dir[idx].name); }

  void open (VFile fl, const(char)[] prefixpath) {
    ulong flsize = fl.size;
    if (flsize > 0xffff_ffffu) throw new VFSNamedException!"Wad2Archive"("file too big");
    char[4] sign;
    fl.rawReadExact(sign[]);
    if (sign != "WAD2") throw new VFSNamedException!"Wad2Archive"("not a PAK file");
    auto flCount = fl.readNum!uint;
    auto dirOfs = fl.readNum!uint;
    if (flCount > 0x3fff_ffff || dirOfs >= flsize || dirOfs+flCount*32 > flsize) throw new VFSNamedException!"Wad2Archive"("invalid archive file");
    // read directory
    fl.seek(dirOfs);
    char[16] nbuf;
    while (flCount-- > 0) {
      FileInfo fi;
      fi.ofs = fl.readNum!uint;
      fi.size = fl.readNum!uint;
      fl.readNum!uint; // size of entry in memory, not used
      ubyte type = fl.readNum!ubyte;
      if (type == '/') type = '_'; // oops
      auto compr = fl.readNum!ubyte; // 0: none
      fl.readNum!ushort; // not used
      fl.rawReadExact(nbuf[0..16]);
      char[] name;
      {
        name = new char[](prefixpath.length+16+2);
        usize nbpos = prefixpath.length;
        if (nbpos) name[0..nbpos] = prefixpath[];
        foreach (char ch; nbuf[0..16]) {
          if (ch == 0) break;
          if (ch == '\\') ch = '/';
          if (ch == '/' && (nbpos == 0 || name.ptr[nbpos-1] == '/')) continue;
          name.ptr[nbpos++] = ch;
        }
        if (type) { name.ptr[nbpos++] = '.'; name.ptr[nbpos++] = cast(char)type; }
        name = name[0..nbpos];
        if (name.length && name[$-1] == '/') name = null;
      }
      // some sanity checks
      if (fi.size > 0 && fi.ofs >= flsize || fi.size > flsize) throw new VFSNamedException!"Wad2Archive"("invalid archive directory");
      if (fi.ofs+fi.size > flsize) throw new VFSNamedException!"Wad2Archive"("invalid archive directory");
      if (compr != 0) throw new VFSNamedException!"Wad2Archive"("invalid compression type");
      if (name.length) {
        fi.name = cast(string)name; // it's safe here
        dir ~= fi;
      }
    }
  }
}
