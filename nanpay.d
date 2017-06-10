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
module iv.nanpay /*is aliced*/;


// doubles
enum MinSignedNanPay = -0x7_ffff_ffff_ffffL; // 51 bits
enum MaxSignedNanPay = +0x7_ffff_ffff_ffffL; // 51 bits

enum MinUnsignedNanPay = 0UL;
enum MaxUnsignedNanPay = 0x7_ffff_ffff_ffffUL; // 51 bits

// floats
enum MinSignedNanPayF = -0x3f_ffff; // 22 bits
enum MaxSignedNanPayF = +0x3f_ffff; // 22 bits

enum MinUnsignedNanPayF = 0U;
enum MaxUnsignedNanPayF = 0x3f_ffffU; // 22 bits


// ////////////////////////////////////////////////////////////////////////// //
/**
 * Create a NaN, storing an integer inside the payload.
 *
 * The largest possible payload is 0x7_ffff_ffff_ffff (51 bits).
 * One bit is reserved to not turn nans into infinity.
 * But sign bit can be used to store sign, which allows to store signed values.
 * IDC about quiet and signaling nans: check your numbers!
 */
double makeNanPay(bool doChecking=false) (long pay) pure nothrow @trusted @nogc {
  pragma(inline, true);
  static if (doChecking) {
    if (pay < MinSignedNanPay || pay > MaxSignedNanPay) assert(0, "invalid payload");
  }
  pay &= 0x8007_ffff_ffff_ffffUL; // left only bits we are interested in
  pay |= 0x7ff8_0000_0000_0000UL; // set highest mantissa bit to ensure nan, and exponent to nan/inf
  // create double
  return *cast(double*)&pay;
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
 * The largest possible payload is 0x7_ffff_ffff_ffff (51 bits).
 * One bit is reserved to not turn nans into infinity.
 * But sign bit can be used to store sign, which allows to store signed values.
 * Check if your number is "good nan" before extracting!
 */
long getNanPay (in double v) pure nothrow @trusted @nogc {
  pragma(inline, true);
  long pay = (*cast(const(long)*)&v)&0x8007_ffff_ffff_ffffUL; // remove exponent
  // this bitors the missing "1" bits for negative numbers
  // shift either by 16 (effectively removing the mask) or by 0
  pay |= 0xfff8_0000_0000_0000UL<<(((pay>>59)&0x10)^0x10);
  return pay;
}


// ////////////////////////////////////////////////////////////////////////// //
/**
 * Create a NaN, storing an integer inside the payload.
 *
 * The largest possible payload is 0x7_ffff_ffff_ffff (51 bits).
 * One bit is reserved to not turn nans into infinity.
 * Sign bit is unused, and should be zero.
 * IDC about quiet and signaling nans: check your numbers!
 */
double makeNanPayU(bool doChecking=false) (ulong pay) pure nothrow @trusted @nogc {
  pragma(inline, true);
  static if (doChecking) {
    if (pay > MaxUnsignedNanPay) assert(0, "invalid payload");
  }
  pay &= 0x0007_ffff_ffff_ffffUL; // left only bits we are interested in
  pay |= 0x7ff8_0000_0000_0000UL; // set highest mantissa bit to ensure nan, and exponent to nan/inf
  // create double
  return *cast(double*)&pay;
}


/// (rough) check if the given double contains "good nan" with payload. sign bit should not be set.
bool hasNanPayU (in double v) pure nothrow @trusted @nogc {
  pragma(inline, true);
  return (((*cast(const(ulong)*)&v)&0xfff8_0000_0000_0000UL) == 0x7ff8_0000_0000_0000UL);
}


/**
 * Extract an integral payload from a NaN.
 *
 * Returns:
 *  the integer payload as a ulong.
 *
 * The largest possible payload is 0x7_ffff_ffff_ffff (51 bits).
 * One bit is reserved to not turn nans into infinity.
 * Sign bit is unused, and should be zero.
 * Check if your number is "good nan" before extracting!
 */
ulong getNanPayU (in double v) pure nothrow @trusted @nogc {
  pragma(inline, true);
  return (*cast(const(ulong)*)&v)&0x0007_ffff_ffff_ffffUL; // remove exponent
}


// ////////////////////////////////////////////////////////////////////////// //
// return 0, something <0, or something >0
int getDoubleXSign (in double v) pure nothrow @trusted @nogc {
  pragma(inline, true);
  version(LittleEndian) {
    return ((*cast(const(ulong)*)&v)&(0x7fff_ffff_ffff_ffffUL) ? *((cast(const(int)*)&v)+1) : 0);
  } else {
    static assert(0, "unimplemented arch");
  }
}


// ////////////////////////////////////////////////////////////////////////// //
/**
 * Create a NaN, storing an integer inside the payload.
 *
 * The largest possible payload is 0x3f_ffff (22 bits).
 * One bit is reserved to not turn nans into infinity.
 * But sign bit can be used to store sign, which allows to store signed values.
 * IDC about quiet and signaling nans: check your numbers!
 */
float makeNanPayF(bool doChecking=false) (int pay) pure nothrow @trusted @nogc {
  pragma(inline, true);
  static if (doChecking) {
    if (pay < MinSignedNanPayF || pay > MaxSignedNanPayF) assert(0, "invalid payload");
  }
  pay &= 0x803f_ffffU; // left only bits we are interested in
  pay |= 0x7fc0_0000U; // set highest mantissa bit to ensure nan, and exponent to nan/inf
  // create float
  return *cast(float*)&pay;
}


/// (rough) check if the given float contains "good nan" with payload.
bool hasNanPayF (in float v) pure nothrow @trusted @nogc {
  pragma(inline, true);
  return (((*cast(const(uint)*)&v)&0x7fc0_0000U) == 0x7fc0_0000U);
}


/**
 * Extract an integral payload from a NaN.
 *
 * Returns:
 *  the integer payload as a uint.
 *
 * The largest possible payload is 0x3f_ffff (22 bits).
 * One bit is reserved to not turn nans into infinity.
 * But sign bit can be used to store sign, which allows to store signed values.
 * Check if your number is "good nan" before extracting!
 */
int getNanPayF (in float v) pure nothrow @trusted @nogc {
  pragma(inline, true);
  int pay = (*cast(const(int)*)&v)&0x803f_ffffU; // remove exponent
  // this bitors the missing "1" bits for negative numbers
  // shift either by 8 (effectively removing the mask) or by 0
  pay |= 0xfc00_0000U<<(((pay>>28)&0x08)^0x08);
  return pay;
}


// ////////////////////////////////////////////////////////////////////////// //
/**
 * Create a NaN, storing an integer inside the payload.
 *
 * The largest possible payload is 0x3f_ffff (22 bits).
 * One bit is reserved to not turn nans into infinity.
 * Sign bit is unused, and should be zero.
 * IDC about quiet and signaling nans: check your numbers!
 */
float makeNanPayUF(bool doChecking=false) (uint pay) pure nothrow @trusted @nogc {
  pragma(inline, true);
  static if (doChecking) {
    if (pay > MaxUnsignedNanPayF) assert(0, "invalid payload");
  }
  pay &= 0x003f_ffffU; // left only bits we are interested in
  pay |= 0x7fc0_0000U; // set highest mantissa bit to ensure nan, and exponent to nan/inf
  // create float
  return *cast(float*)&pay;
}


/// (rough) check if the given float contains "good nan" with payload. sign bit should not be set.
bool hasNanPayUF (in float v) pure nothrow @trusted @nogc {
  pragma(inline, true);
  return (((*cast(const(uint)*)&v)&0xffc0_0000U) == 0x7fc0_0000U);
}


/**
 * Extract an integral payload from a NaN.
 *
 * Returns:
 *  the integer payload as a uint.
 *
 * The largest possible payload is 0x3f_ffff (22 bits).
 * One bit is reserved to not turn nans into infinity.
 * Sign bit is unused, and should be zero.
 * Check if your number is "good nan" before extracting!
 */
uint getNanPayUF (in float v) pure nothrow @trusted @nogc {
  pragma(inline, true);
  return (*cast(const(uint)*)&v)&0x003f_ffffU; // remove exponent
}


// ////////////////////////////////////////////////////////////////////////// //
// return 0, something <0, or something >0
int getFloatXSign (in float v) pure nothrow @trusted @nogc {
  pragma(inline, true);
  version(LittleEndian) {
    return ((*cast(const(uint)*)&v)&0x7fff_ffffU ? *(cast(const(int)*)&v) : 0);
  } else {
    static assert(0, "unimplemented arch");
  }
}
