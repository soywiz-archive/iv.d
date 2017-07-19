/* coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
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
/* contains very simple compile-time format writer
 * understands [+|-]width[.maxlen]
 *   negative width: add spaces to right
 *   + signed width: center
 *   negative maxlen: get right part
 * specifiers:
 *   's': use to!string to write argument
 *        note that writer can print strings, bools, integrals and floats without allocation
 *   'x': write integer as hex
 *   'X': write integer as HEX
 *   '!': skip all arguments that's left, no width allowed
 *   '%': just a percent sign, no width allowed
 *   '|': print all arguments that's left with simple "%s", no width allowed
 *   '<...>': print all arguments that's left with simple "%s", delimited with "...", no width allowed
 * options (must immediately follow '%'):
 *   '~': fill with the following char instead of space
 *        second '~': right filling char for 'center'
 */
module iv.cmdcon /*is aliced*/;

public import iv.cmdcon.core;
