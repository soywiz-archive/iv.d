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
module iv.vfs.arcs.internal;


// ////////////////////////////////////////////////////////////////////////// //
package mixin template VFSSimpleArchiveDriverMixin() {
protected:
  VFile st;
  FileInfo[] dir;

public:
  this (VFile fl, const(char)[] prefixpath) {
    open(fl, prefixpath);
    st = fl;
  }

  override VFile tryOpen (const(char)[] fname, bool ignoreCase) {
    if (fname.length == 0) return VFile.init;
    import iv.vfs.koi8 : koi8StrCaseEqu;
    foreach_reverse (immutable idx, ref fi; dir) {
      version(Windows) {
        static bool xequ (const(char)[] s0, const(char)[] s1, bool icase) {
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
        }
        if (xequ(fi.name, fname, ignoreCase)) return wrap(idx);
      } else {
        if (ignoreCase) {
          if (koi8StrCaseEqu(fi.name, fname)) return wrap(idx);
        } else {
          if (fi.name == fname) return wrap(idx);
        }
      }
    }
    return VFile.init;
  }

  override @property usize dirLength () { return dir.length; }
  override DirEntry dirEntry (usize idx) {
    static if (is(typeof(dir.ptr[idx].modtime))) ulong modtime = dir.ptr[idx].modtime; else enum modtime = 0;
    static if (is(typeof(dir.ptr[idx].crtime))) ulong crtime = dir.ptr[idx].modtime; else enum crtime = 0;
    static if (is(typeof(dir.ptr[idx].pksize))) long pksize = dir.ptr[idx].pksize; else enum pksize = -1;
    return (idx < dir.length ? DirEntry(dir.ptr[idx].name, dir.ptr[idx].size, crtime, modtime, pksize) : DirEntry.init); }
}


// ////////////////////////////////////////////////////////////////////////// //
package enum VFSSimpleArchiveDetectorMixin(string drvname) =
  "shared static this () { vfsRegisterDetector(new "~drvname~"Detector()); }\n"~
  "private final class "~drvname~"Detector : VFSDriverDetector {\n"~
  "  override VFSDriver tryOpen (VFile fl, const(char)[] prefixpath) {\n"~
  "    try {\n"~
  "      return new VFSDriver"~drvname~"(fl, prefixpath);\n"~
  "    } catch (Exception) {}\n"~
  "    return null;\n"~
  "  }\n"~
  "}\n";
