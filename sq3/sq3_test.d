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
module sq3_test /*is aliced*/;

import std.stdio;

import iv.alice;
import iv.sq3;


////////////////////////////////////////////////////////////////////////////////
void main () {
  auto db = Database("/tmp/pktool.db");
  foreach (ref row; db.statement("SELECT * FROM packages WHERE id >= :idl AND id <= :idh").bind("idl", 1).bind("idh", 5).range) {
    writeln("index=", row.index_, "; id=", row.id!uint, "; name=", row.name);
  }
  auto rng = db.statement("SELECT * FROM packages WHERE id=:id").bind("id", 1).range;
  if (rng.empty) {
    writeln("NO 1!");
  } else {
    writeln(rng.front.name!stringc);
    rng.popFront();
    assert(rng.empty);
  }
}
