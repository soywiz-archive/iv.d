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
module iv.vfs.arc.internal /*is aliced*/;
import iv.alice;

//version = iv_vfs_arcs_debug_hash;
version = iv_vfs_arcs_nomodulo;


// ////////////////////////////////////////////////////////////////////////// //
package mixin template VFSSimpleArchiveDriverMixin() {
protected:
  static struct HashTableEntry {
    uint hash; // name hash; name is lowercased
    uint prev=uint.max; // previous name with the same reduced hash position
    uint didx=uint.max; // dir index
  }

  // returns lowercased string bytes, suitable for hash calculation
  static struct LoStringRange {
    const(char)[] s;
    usize pos;
  pure nothrow @trusted @nogc:
    this (const(char)[] as) { pragma(inline, true); s = as; pos = 0; }
    @property bool empty () const { pragma(inline, true); return (pos >= s.length); }
    @property ubyte front () const {
      pragma(inline, true);
      import iv.vfs.koi8;
      if (pos < s.length) {
        version(Windows) {
          return cast(ubyte)koi8tolowerTable.ptr[cast(ubyte)koi8from1251Table[s.ptr[pos]]];
        } else {
          return cast(ubyte)koi8tolowerTable.ptr[cast(ubyte)s.ptr[pos]];
        }
      } else {
        return 0;
      }
      return (pos < s.length ? cast(ubyte)s.ptr[pos] : 0);
    }
    void popFront () { pragma(inline, true); if (pos < s.length) ++pos; }
  }

  static uint hashStr (const(char)[] s) {
    //pragma(inline, true);
    if (auto res = mur3HashOf(LoStringRange(s))) return res; else return 1; // so we can use 0 as sentinel
    //return mur3HashOf(LoStringRange(s));
  }

protected:
  VFile st;
  FileInfo[] dir;
  HashTableEntry[] htable; // for names, in reverse order; so name lookups will be faster
    // the algo is:
    //   htable[hashStr(name)%htable.length]: check if hash is ok, and name is ok
    //   if not ok, jump to htable[curht.prev], repeat

protected:
  // call this after you done building `dir`; never modify `dir` after that (or call `buildNameHashTable()` again)
  final buildNameHashTable () @trusted {
    import core.memory : GC;
    if (dir.length == 0 || dir.length >= uint.max-8) { delete htable; return; } // just in case
    if (htable.length) htable.assumeSafeAppend;
    htable.length = dir.length;
    if (htable.ptr is GC.addrOf(htable.ptr)) GC.setAttr(htable.ptr, GC.BlkAttr.NO_INTERIOR);
    htable[] = HashTableEntry.init;
    version(iv_vfs_arcs_debug_hash) {
      uint chaincount = 0;
      uint maxchainlen = 0;
    }
    foreach_reverse (immutable idx, const ref FileInfo fi; dir) {
      uint nhash = hashStr(fi.name); // never zero
      version(iv_vfs_arcs_nomodulo) {
        uint hidx = cast(uint)((cast(ulong)nhash*cast(ulong)htable.length)>>32);
        assert(hidx < htable.length);
      } else {
        uint hidx = nhash%cast(uint)htable.length;
      }
      if (htable.ptr[hidx].didx == uint.max) {
        // first item
        htable.ptr[hidx].hash = nhash;
        htable.ptr[hidx].didx = cast(uint)idx;
        assert(htable.ptr[hidx].prev == uint.max);
        //version(iv_vfs_arcs_debug_hash) { import core.stdc.stdio; printf("H1: [%.*s] nhash=0x%08x; hidx=%u\n", cast(uint)fi.name.length, fi.name.ptr, nhash, hidx); }
      } else {
        version(iv_vfs_arcs_debug_hash) {
          uint chainlen = 0;
          ++chaincount;
        }
        // chain
        while (htable.ptr[hidx].prev != uint.max) {
          version(iv_vfs_arcs_debug_hash) ++chainlen;
          hidx = htable.ptr[hidx].prev;
        }
        version(iv_vfs_arcs_debug_hash) if (chainlen > maxchainlen) maxchainlen = chainlen;
        // find free slot
        uint freeslot = hidx;
        foreach (immutable uint count; 0..cast(uint)dir.length) {
          freeslot = (freeslot+1)%cast(uint)htable.length;
          if (htable.ptr[freeslot].hash == 0) break; // i found her!
        }
        if (htable.ptr[freeslot].hash != 0) assert(0, "wtf?!");
        htable.ptr[hidx].prev = freeslot;
        htable.ptr[freeslot].hash = nhash;
        htable.ptr[freeslot].didx = cast(uint)idx;
        assert(htable.ptr[freeslot].prev == uint.max);
      }
    }
    version(iv_vfs_arcs_debug_hash) { import core.stdc.stdio; printf("chaincount=%u; maxchainlen=%u; count=%u\n", chaincount, maxchainlen, cast(uint)htable.length); }
  }

public:
  this (VFile fl, const(char)[] prefixpath) {
    open(fl, prefixpath);
    st = fl;
  }

  override VFile tryOpen (const(char)[] fname, bool ignoreCase) {
    static bool xequ (const(char)[] s0, const(char)[] s1, bool icase) {
      version(Windows) {
        import iv.vfs.koi8;
        if (s0.length != s1.length) return false;
        foreach (immutable idx, char c0; s0) {
          char c1 = koi8from1251Table[s1.ptr[idx]];
          if (icase) {
            c0 = koi8tolowerTable.ptr[cast(ubyte)c0];
            c1 = koi8tolowerTable.ptr[cast(ubyte)c1];
          }
          if (c0 != c1) return false;
        }
        return true;
      } else {
        import iv.vfs.koi8 : koi8StrCaseEqu;
        return (icase ? koi8StrCaseEqu(s0, s1) : (s0 == s1));
      }
    }

    if (fname.length == 0 || dir.length == 0) return VFile.init;
    // try hashtable first
    if (htable.length == dir.length) {
      uint nhash = hashStr(fname);
      version(iv_vfs_arcs_debug_hash) { import core.stdc.stdio; printf("HL: [%.*s] nhash=0x%08x\n", cast(uint)fname.length, fname.ptr, nhash); }
      version(iv_vfs_arcs_nomodulo) {
        uint hidx = cast(uint)((cast(ulong)nhash*cast(ulong)htable.length)>>32);
      } else {
        uint hidx = nhash%cast(uint)htable.length;
      }
      while (hidx != uint.max && htable.ptr[hidx].hash != 0) {
        if (htable.ptr[hidx].hash == nhash) {
          uint didx = htable.ptr[hidx].didx;
          FileInfo* fi = dir.ptr+didx;
          if (xequ(fi.name, fname, ignoreCase)) {
            version(iv_vfs_arcs_debug_hash) { import core.stdc.stdio; printf("HH: [%.*s] nhash=0x%08x; hthash=0x%08x; hidx=%u\n", cast(uint)fi.name.length, fi.name.ptr, nhash, htable.ptr[hidx].hash, hidx); }
            return wrap(didx);
          }
        }
        version(iv_vfs_arcs_debug_hash) { import core.stdc.stdio; printf("HS: [%.*s] nhash=0x%08x; hthash=0x%08x; hidx=%u\n", cast(uint)dir.ptr[htable.ptr[hidx].didx].name.length, dir.ptr[htable.ptr[hidx].didx].name.ptr, nhash, htable.ptr[hidx].hash, hidx); }
        hidx = htable.ptr[hidx].prev;
      }
      // alas, and it is guaranteed that we have no such file here
      return VFile.init;
    }
    // fallback to linear search
    foreach_reverse (immutable idx, ref fi; dir) {
      if (xequ(fi.name, fname, ignoreCase)) return wrap(idx);
    }
    return VFile.init;
  }

  override @property usize dirLength () { return dir.length; }
  override DirEntry dirEntry (usize idx) { return (idx < dir.length ? DirEntry(idx, dir.ptr[idx].name, dir.ptr[idx].size) : DirEntry.init); }
}


// ////////////////////////////////////////////////////////////////////////// //
package enum VFSSimpleArchiveDetectorMixin(string drvname, string mode="normal") =
  "shared static this () { vfsRegisterDetector!"~mode.stringof~"(new "~drvname~"Detector()); }\n"~
  "private final class "~drvname~"Detector : VFSDriverDetector {\n"~
  "  override VFSDriver tryOpen (VFile fl, const(char)[] prefixpath) {\n"~
  "    try {\n"~
  "      return new VFSDriver"~drvname~"(fl, prefixpath);\n"~
  "    } catch (Exception) {}\n"~
  "    return null;\n"~
  "  }\n"~
  "}\n";
