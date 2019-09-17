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
// data files from Arcanum (conflicts with ToEE, so can't detect)
module iv.vfs.arc.arcanum /*is aliced*/;

import iv.alice;
import iv.vfs.types : Seek;
import iv.vfs.error;
import iv.vfs.main;
import iv.vfs.util;
import iv.vfs.vfile;
import iv.vfs.arc.internal;


// ////////////////////////////////////////////////////////////////////////// //
mixin(VFSSimpleArchiveDetectorMixin!"ArcanumDat");


// ////////////////////////////////////////////////////////////////////////// //
public final class VFSDriverArcanumDat : VFSDriver {
  mixin VFSSimpleArchiveDriverMixin;

private:
  static align(1) struct DatDirInfo {
  align(1):
    ubyte[16] guid; // guid, unique identifier for every module
    char[4] magic; // magic number, ascii "1TAD"
    uint poolSize; // size of filename pool, in bytes
    uint dirSize; // size of directory+sizeof(DatDirInfo)

    @property bool isGoodMagic () const nothrow @safe @nogc { return (magic[] == "1TAD"); }

    void read (VFile fl) {
      fl.seek(-cast(long)this.sizeof, Seek.End);
      fl.rawReadExact(guid[]);
      fl.rawReadExact(magic[]);
      poolSize = fl.readNum!uint;
      dirSize = fl.readNum!uint;
    }
  }

  static align(1) struct DatDirEntry {
  align(1):
    enum Flags {
      Unpacked = 0x01,
      Packed = 0x02,
      Dir = 0x400,
    }

    enum Size = DatDirEntry.sizeof-name.sizeof;

    string name;
    uint unused; // pointer to cstring, invalid when saved in file
    uint flags; // see `Flags`
    uint size; // decompressed size, in bytes
    uint packedSize; // compressed size, in bytes
    uint offset; // position of data in archive

    void read (VFile fl) {
      unused = fl.readNum!uint;
      flags = fl.readNum!uint;
      size = fl.readNum!uint;
      packedSize = fl.readNum!uint;
      offset = fl.readNum!uint;
    }
    static assert(DatDirEntry.Size == 5*4);
  }

private:
  static struct FileInfo {
    bool packed;
    long pksize;
    long size;
    long ofs; // offset in archive
    string name; // with path
  }

  /** query various file properties; driver-specific.
   * properties of interest:
   *   "packed" -- is file packed?
   *   "pksize" -- packed file size
   *   "offset" -- offset in wad
   *   "size"   -- file size (so we can get size without opening the file)
   */
  public override VFSVariant stat (usize idx, const(char)[] propname) {
    if (idx >= dir.length) return VFSVariant();
    if (propname == "arcname") return VFSVariant("arcanum");
    if (propname == "packed") return VFSVariant(dir[idx].packed);
    if (propname == "pksize") return VFSVariant(dir[idx].packed ? dir[idx].pksize : dir[idx].size);
    if (propname == "offset") return VFSVariant(dir[idx].ofs);
    if (propname == "size") return VFSVariant(dir[idx].size);
    return VFSVariant();
  }

  VFile wrap (usize idx) {
    assert(idx < dir.length);
    auto stpos = dir[idx].ofs;
    auto size = dir[idx].size;
    auto pksize = dir[idx].pksize;
    VFSZLibMode mode = (dir[idx].packed ? VFSZLibMode.ZLib : VFSZLibMode.Raw);
    return wrapZLibStreamRO(st, mode, size, stpos, pksize, dir[idx].name);
  }

  void open (VFile fl, const(char)[] prefixpath) {
    DatDirInfo di;
    DatDirEntry de;
    di.read(fl);
    if (!di.isGoodMagic || di.dirSize < DatDirInfo.sizeof+4) throw new /*VFSNamedException!"ArcanumDatArchive"*/VFSExceptionArc("invalid archive");
    debug(datToEE) {
      writeln("poolSize: ", di.poolSize, "; dirSize: ", di.dirSize);
      writefln("GUID: %02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
        di.guid[0], di.guid[1], di.guid[2], di.guid[3], di.guid[4], di.guid[5], di.guid[6], di.guid[7],
        di.guid[8], di.guid[9], di.guid[10], di.guid[11], di.guid[12], di.guid[13], di.guid[14], di.guid[15]);
    }
    fl.seek(-cast(long)di.dirSize, Seek.End); // seek to dir
    di.dirSize -= DatDirInfo.sizeof+4;
    auto total = fl.readNum!uint;
    debug(datToEE) writeln("total files: ", total);
    while (di.dirSize >= DatDirEntry.Size+4) {
      di.dirSize -= DatDirEntry.Size+4;
      auto nlen = fl.readNum!uint;
      if (nlen > 1024) throw new /*VFSNamedException!"ArcanumDatArchive"*/VFSExceptionArc("invalid archive (name too long)");
      if (nlen > di.dirSize) throw new /*VFSNamedException!"ArcanumDatArchive"*/VFSExceptionArc("invalid archive (name is out of dir)");
      di.dirSize -= nlen;
      if (nlen > 0) {
        auto nbuf = new char[](nlen);
        fl.rawReadExact(nbuf[]);
        nlen = 0;
        while (nlen < nbuf.length && nbuf.ptr[nlen]) {
          if (nbuf.ptr[nlen] == '\\') nbuf.ptr[nlen] = '/'; // that's it
          ++nlen;
        }
        de.name = cast(string)(nbuf[0..nlen]); // it's safe here
      } else {
        de.name = null;
      }
      de.read(fl);
      //debug(datToEE) writefln("%6s; flags=0x%04x; size=%10s; packedSize=%10s; offset=0x%08x; pdiridx=%6s; fcidx=%6s; nsidx=%6s  [%s]", flist.length, de.flags, de.size, de.packedSize, de.offset, de.pdiridx, de.fcidx, de.nsidx, de.name);
      if (de.name.length > 0 && (de.flags&DatDirEntry.Flags.Dir) == 0) {
        dir.arrayAppendUnsafe(FileInfo(
          (de.flags&DatDirEntry.Flags.Packed) != 0,
          de.packedSize,
          de.size,
          de.offset,
          de.name
        ));
      }
      --total;
      if ((de.flags&DatDirEntry.Flags.Dir) == 0) {
        if ((de.flags&(DatDirEntry.Flags.Packed|DatDirEntry.Flags.Unpacked)) == 0) throw new /*VFSNamedException!"ArcanumDatArchive"*/VFSExceptionArc("invalid ToEE file flags");
      }
    }
    if (total != 0) throw new /*VFSNamedException!"ArcanumDatArchive"*/VFSExceptionArc("invalid archive (invalid total file count)");
    if (di.dirSize != 0) throw new /*VFSNamedException!"ArcanumDatArchive"*/VFSExceptionArc("invalid archive (extra data in directory)");
    buildNameHashTable();
  }
}
