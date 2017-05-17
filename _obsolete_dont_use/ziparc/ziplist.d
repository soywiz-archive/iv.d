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
module ziplist /*is aliced*/;

import std.stdio;
import iv.alice;
import iv.ziparc;


// ////////////////////////////////////////////////////////////////////////// //
void main (string[] args) {
  auto zip = new ZipArchive(args[1]);
  foreach (ref de; zip.files) {
    stdout.writefln("%10s %s", de.size, de.name);
    if (de.name == "-" || de.name == "ziplist.d") {
      foreach (auto line; zip.fopen(de).byLine) {
        writeln("  [", line, "]");
      }
    }
  }
}
