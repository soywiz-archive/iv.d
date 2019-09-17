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
import std.stdio;

import iv.glob;


void main () {
  writeln("====================");
  foreach (Glob.Item it; Glob("../*", GLOB_BRACE|GLOB_TILDE_CHECK|GLOB_MARK)) {
    writeln(it.index, ": [", it.name, "]");
  }

  writeln("====================");
  foreach (uint idx, ref Glob.Item it; Glob("../*", GLOB_BRACE|GLOB_TILDE_CHECK|GLOB_MARK)) {
    writeln(idx, ": [", it.name, "]");
  }

  writeln("====================");
  foreach_reverse (Glob.Item it; Glob("../*", GLOB_BRACE|GLOB_TILDE_CHECK|GLOB_MARK)) {
    writeln(it.index, ": [", it.name, "]");
  }

  writeln("====================");
  foreach_reverse (uint idx, ref Glob.Item it; Glob("../*", GLOB_BRACE|GLOB_TILDE_CHECK|GLOB_MARK)) {
    writeln(idx, ": [", it.name, "]");
  }

  auto it = Glob("*")[0];
  writeln("[0]=", it.name);
}
