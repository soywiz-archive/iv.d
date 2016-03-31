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
module iv.vfs.arcs;

public import iv.vfs.arcs.zip;
public import iv.vfs.arcs.q1pak;


// ////////////////////////////////////////////////////////////////////////// //
package mixin template VFSSimpleArchiveDriverMixin() {
protected:
  VFile st;
  FileInfo[] dir;

public:
  this (VFile fl) {
    open(fl);
    st = fl;
  }

  override VFile tryOpen (const(char)[] fname, bool ignoreCase) {
    if (fname.length == 0) return VFile.init;
    import iv.vfs.koi8 : koi8StrCaseEqu;
    foreach_reverse (immutable idx, ref fi; dir) {
      if (ignoreCase) {
        if (koi8StrCaseEqu(fi.name, fname)) return wrap(idx);
      } else {
        if (fi.name == fname) return wrap(idx);
      }
    }
    return VFile.init;
  }

  override @property usize dirLength () { return dir.length; }
  override DirEntry dirEntry (uint idx) { return (idx < dir.length ? DirEntry(dir.ptr[idx].name, dir.ptr[idx].size) : DirEntry.init); }
}


// ////////////////////////////////////////////////////////////////////////// //
package enum VFSSimpleArchiveDetectorMixin(string drvname) =
  "shared static this () { vfsRegisterDetector(new "~drvname~"Detector()); }\n"~
  "private final class "~drvname~"Detector : VFSDriverDetector {\n"~
  "  override VFSDriver tryOpen (VFile fl) {\n"~
  "    try {\n"~
  "      return new VFSDriver"~drvname~"(fl);\n"~
  "    } catch (Exception) {}\n"~
  "    return null;\n"~
  "  }\n"~
  "}\n";
