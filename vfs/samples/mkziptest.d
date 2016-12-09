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
module mkziptest;

import iv.strex;
import iv.vfs.io;
import iv.vfs.writers.zip;


void main () {
  auto fo = VFile("z00.zip", "w");
  vfsRegister!"first"(new VFSDriverDiskListed(".", true)); // data dir, will be looked last

  auto zw = new ZipWriter(fo);
  scope(failure) if (zw.isOpen) zw.abort();

  foreach (const ref de; vfsAllFiles()) {
    if (de.name.endsWithCI(".zip")) continue;
    writeln(de.name);
    zw.pack(VFile(de.name), de.name, ZipFileTime(de.modtime));
  }
  zw.finish();
}
