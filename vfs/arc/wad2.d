/* Invisible Vector Library
 * coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * Understanding is not required. Only obedience.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 3 of the License ONLY.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */
module iv.vfs.arc.wad2 /*is aliced*/;

import iv.alice;
import iv.vfs.types : Seek;
import iv.vfs.error;
import iv.vfs.main;
import iv.vfs.util;
import iv.vfs.vfile;
import iv.vfs.arc.internal;


// ////////////////////////////////////////////////////////////////////////// //
mixin(VFSSimpleArchiveDetectorMixin!"Wad2");


// ////////////////////////////////////////////////////////////////////////// //
public final class VFSDriverWad2 : VFSDriver {
  mixin VFSSimpleArchiveDriverMixin;

private:
  static struct FileInfo {
    long size;
    long ofs; // offset in archive
    string name; // with path
    char type;
  }

  /** query various file properties; driver-specific.
   * properties of interest:
   *   "type" -- internal type
   *   "packed" -- is file packed?
   *   "pksize" -- packed file size (for archives)
   *   "offset" -- offset in wad
   *   "size"   -- file size (so we can get size without opening the file)
   */
  public override VFSVariant stat (usize idx, const(char)[] propname) {
    if (idx >= dir.length) return VFSVariant();
    if (propname == "arcname") return VFSVariant("wad2");
    if (propname == "type") return VFSVariant(dir[idx].type);
    if (propname == "packed") return VFSVariant(false);
    if (propname == "pksize") return VFSVariant(dir[idx].size);
    if (propname == "offset") return VFSVariant(dir[idx].ofs);
    if (propname == "size") return VFSVariant(dir[idx].size);
    return VFSVariant();
  }

  VFile wrap (usize idx) { return wrapStreamRO(st, dir[idx].ofs, dir[idx].size, dir[idx].name); }

  void open (VFile fl, const(char)[] prefixpath) {
    ulong flsize = fl.size;
    if (flsize > 0xffff_ffffu) throw new /*VFSNamedException!"Wad2Archive"*/VFSExceptionArc("file too big");
    char[4] sign;
    fl.rawReadExact(sign[]);
    if (sign != "WAD2") throw new /*VFSNamedException!"Wad2Archive"*/VFSExceptionArc("not a PAK file");
    auto flCount = fl.readNum!uint;
    auto dirOfs = fl.readNum!uint;
    if (flCount > 0x3fff_ffff || dirOfs >= flsize || dirOfs+flCount*32 > flsize) throw new /*VFSNamedException!"Wad2Archive"*/VFSExceptionArc("invalid archive file");
    // read directory
    fl.seek(dirOfs);
    char[16] nbuf;
    while (flCount-- > 0) {
      FileInfo fi;
      fi.ofs = fl.readNum!uint;
      fi.size = fl.readNum!uint;
      fl.readNum!uint; // size of entry in memory, not used
      ubyte type = fl.readNum!ubyte;
      ubyte origtype = type;
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
      if (fi.size > 0 && fi.ofs >= flsize || fi.size > flsize) throw new /*VFSNamedException!"Wad2Archive"*/VFSExceptionArc("invalid archive directory");
      if (fi.ofs+fi.size > flsize) throw new /*VFSNamedException!"Wad2Archive"*/VFSExceptionArc("invalid archive directory");
      if (compr != 0) throw new /*VFSNamedException!"Wad2Archive"*/VFSExceptionArc("invalid compression type");
      if (name.length) {
        fi.name = cast(string)name; // it's safe here
        fi.type = cast(char)origtype;
        dir.arrayAppendUnsafe(fi);
      }
    }
    buildNameHashTable();
  }
}
