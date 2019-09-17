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
module gcccompat /*is aliced*/;
import iv.alice;

version(GNU) {
  import gcc.attribute;
} else {
  private struct Attribute(A...) { A args; }
  auto attribute(A...) (A args) if (A.length > 0 && is(A[0] == string)) => Attribute!A(args);
}

/*
@attribute("forceinline") int test () => 42;


void main () {
  import iv.writer;
  writeln(test);
}
*/
