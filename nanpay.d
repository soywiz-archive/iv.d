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
module iv.nanpay is aliced;


/**
 * Create a NaN, storing an integer inside the payload.
 *
 * The largest possible payload is 7_ffff_ffff_ffff (51 bit).
 * One bit is reserved to not turn nans into infinity.
 * But sign bit can be used to store sign, which allows to store signed values.
 * IDC about quiet and signaling nans: check your numbers!
 */
double makeNan (long pay) pure nothrow @trusted @nogc {
  pragma(inline, true);
  if (pay < -0x7_ffff_ffff_ffffL || pay > 0x7_ffff_ffff_ffffL) assert(0, "invalid payload");
  pay &= (0x7_ffff_ffff_ffffUL|0x8000_0000_0000_0000UL); // left only bits we are interested in
  pay |= 0x7ff8_0000_0000_0000UL; // set highest mantissa bit to ensure nan, and exponent to nan/inf
  // create double
  double res = void;
  *cast(long*)&res = pay;
  // done
  return res;
}


/// (rough) check if the given double contains "good nan" with payload.
bool hasNanPay (in double v) pure nothrow @trusted @nogc {
  pragma(inline, true);
  return (((*cast(const(ulong)*)&v)&0x7ff8_0000_0000_0000UL) == 0x7ff8_0000_0000_0000UL);
}


/**
 * Extract an integral payload from a NaN.
 *
 * Returns:
 *  the integer payload as a ulong.
 *
 * The largest possible payload is 7_ffff_ffff_ffff (51 bit).
 * One bit is reserved to not turn nans into infinity.
 * But sign bit can be used to store sign, which allows to store signed values.
 * Check if your number is "good nan" before extracting!
 */
long getNanPay (in double v) /*pure nothrow @trusted @nogc*/ {
  pragma(inline, true);
  long pay = (*cast(const(long)*)&v)&(0x7_ffff_ffff_ffffUL|0x8000_0000_0000_0000UL); // remove exponent
  // this bitors the missing "1" bits for negative numbers
  pay |= 0xfff8_0000_0000_0000UL<<((pay>>59)&0x10^0x10);
  return pay;
}
