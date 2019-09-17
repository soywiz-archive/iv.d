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
module iv.gccattrs /*is aliced*/;


version(GNU) {
  static import gcc.attribute;
  enum gcc_inline = gcc.attribute.attribute("forceinline");
  enum gcc_noinline = gcc.attribute.attribute("noinline");
  enum gcc_flatten = gcc.attribute.attribute("flatten");
} else {
  // hackery for non-gcc compilers
  enum gcc_inline;
  enum gcc_noinline;
  enum gcc_flatten;
}
