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
module iv.vfs.arcs.bsa;

import std.variant : Variant;
import iv.vfs.types : usize, ssize, Seek;
import iv.vfs.augs;
import iv.vfs.main;
import iv.vfs.util;
import iv.vfs.vfile;


// ////////////////////////////////////////////////////////////////////////// //
private import iv.vfs.arcs.internal : VFSSimpleArchiveDetectorMixin;
mixin(VFSSimpleArchiveDetectorMixin!"BSA");


// ////////////////////////////////////////////////////////////////////////// //
public final class VFSDriverBSA : VFSDriver {
  private import iv.vfs.arcs.internal : VFSSimpleArchiveDriverMixin;
  mixin VFSSimpleArchiveDriverMixin;

private:
  static struct FileInfo {
    long size;
    long ofs; // offset in archive
    string name; // with path
    long pksize;
    bool packed;
  }

  /** query various file properties; driver-specific.
   * properties of interest:
   *   "packed" -- is file packed?
   *   "pksize" -- packed file size (for archives)
   *   "offset" -- offset in wad
   *   "size"   -- file size (so we can get size without opening the file)
   */
  public override Variant stat (usize idx, const(char)[] propname) {
    if (idx >= dir.length) return Variant();
    if (propname == "packed") return Variant(dir[idx].packed);
    if (propname == "pksize") return Variant(dir[idx].pksize);
    if (propname == "offset") return Variant(dir[idx].ofs);
    if (propname == "size") return Variant(dir[idx].size);
    return Variant();
  }

  VFile wrap (usize idx) {
    if (dir[idx].packed) return wrapZLibStreamRO(st, VFSZLibMode.ZLib, dir[idx].size, dir[idx].ofs, dir[idx].pksize, dir[idx].name);
    return wrapStreamRO(st, dir[idx].ofs, dir[idx].size, dir[idx].name);
  }

  void open (VFile fl, const(char)[] prefixpath) {
    string loadBCStr(bool asdir) () {
      auto len = fl.readNum!ubyte;
      if (len == 0) return null; // oops
      auto res = new char[](len+1); // for '/'
      fl.rawReadExact(res[0..$-1]);
      res[$-1] = 0; // for now
      foreach (immutable idx, ref char ch; res) {
        if (ch == 0) {
          // asciiz
          static if (asdir) {
            ch = '/'; // 'cause dir name should end with slash
            res = res[0..idx+1];
          } else {
            res = res[0..idx];
          }
          break;
        }
        //if (ch >= 'A' && ch <= 'Z') ch += 32; // poor man's tolower
        if (ch == '\\') ch = '/'; // fuck off, shitdoze
      }
      while (res.length > 1 && res[$-1] == '/' && res[$-2] == '/') res = res[0..$-1];
      if (res == "/") return null; // just in case
      return cast(string)res; // it is safe to cast here
    }

    ulong flsize = fl.size;
    if (flsize > 0xffff_ffffu) throw new VFSNamedException!"BSAArchive"("file too big");
    char[4] sign;
    fl.rawReadExact(sign[]);
    if (sign != "BSA\x00") throw new VFSNamedException!"BSAArchive"("not a BSA file");
    auto ver = fl.readNum!uint;
    if (/*ver != 0x67 &&*/ ver != 0x68) throw new VFSNamedException!"BSAArchive"("invalid BSA version");
    auto fatofs = fl.readNum!uint;
    auto flags = fl.readNum!uint;
    version(bsa_dump) {
      writeln("flags:");
      if (flags&0x01) writeln("  has names for directories");
      if (flags&0x02) writeln("  has names for files");
      if (flags&0x04) writeln("  compressed by default");
      if (flags&0x40) writeln("  shitbox archive");
    }
    if ((flags&0x03) != 0x03) throw new VFSNamedException!"BSAArchive"("invalid BSA flags (no names)");
    auto dircount = fl.readNum!uint;
    auto filecount = fl.readNum!uint;
    auto dirnmsize = fl.readNum!uint;
    auto filenmsize = fl.readNum!uint;
    auto fileflags = fl.readNum!uint;

    version(bsa_dump) writefln("dirs=%u; files=%u; dirnmsize=%u; filenmsize=%u; fileflags=0x%08x", dircount, filecount, dirnmsize, filenmsize, fileflags);

    // load dir counts
    uint[] dircnt;
    fl.seek(fatofs);
    foreach (immutable didx; 0..dircount) {
      fl.readNum!ulong; // name hash, skip it
      uint fcount = fl.readNum!uint;
      fl.readNum!uint; // dir name offset
      dircnt.arrayAppendUnsafe(fcount);
    }

    // load file entries
    foreach (uint defcount; dircnt) {
      string dirname = loadBCStr!true();
      version(bsa_dump) writeln("directory [", dirname, "]: ", defcount, " files");
      // load actual file entries
      foreach (immutable _; 0..defcount) {
        FileInfo fe;
        fl.readNum!ulong; // name hash, skip it
        fe.size = fl.readNum!uint;
        fe.ofs = fl.readNum!uint;
        fe.name = dirname; // will be fixed later
        if (fe.size&0x8000_0000U) assert(0, "wtf?!");
        fe.packed = ((fe.size&0x4000_0000U) != 0);
        if (flags&0x04) fe.packed = !fe.packed;
        fe.size &= 0x3fff_ffffU;
        dir.arrayAppendUnsafe(fe);
      }
    }

    // load file names
    foreach (ref FileInfo fe; dir) {
      // asciiz
      for (;;) {
        char ch;
        fl.rawReadExact((&ch)[0..1]);
        if (ch == 0) break;
        //if (ch >= 'A' && ch <= 'Z') ch += 32; // poor man's tolower
        if (ch == '\\' || ch == '/') ch = '_'; // fuck off, shitdoze
        fe.name ~= ch;
      }
    }

    // load rest of the info
    foreach (immutable fidx, ref FileInfo fe; dir) {
      if (fe.size == 0) {
        fe.pksize = 0;
        fe.packed = false;
        continue;
      }
      if (fe.packed) {
        fl.seek(fe.ofs);
        if (fe.packed) {
          assert(fe.size >= 4);
          fe.pksize = fe.size-4;
          fe.ofs += 4;
          fe.size = fl.readNum!uint;
          if (fe.pksize == 0) {
            assert(fe.size == 0);
            fe.packed = false;
          }
        }
      }
    }
  }
}
