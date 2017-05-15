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
module iv.follin.hash is aliced;


// ////////////////////////////////////////////////////////////////////////// //
version(X86) version = AnyX86;
version(X86_64) version = AnyX86;
version(AnyX86) version = HasUnalignedOps;


/**
 * 64-bit implementation of fasthash
 *
 * Params:
 *   buf =  data buffer
 *   seed = the seed
 *
 * Returns:
 *   32-bit or 64-bit hash
 */
package(iv.follin) usize hashBuffer (const(void)* buf, usize len, usize seed=0) pure nothrow @trusted @nogc {
  enum Get8Bytes = q{
    cast(ulong)data[0]|
    (cast(ulong)data[1]<<8)|
    (cast(ulong)data[2]<<16)|
    (cast(ulong)data[3]<<24)|
    (cast(ulong)data[4]<<32)|
    (cast(ulong)data[5]<<40)|
    (cast(ulong)data[6]<<48)|
    (cast(ulong)data[7]<<56)
  };
  enum m = 0x880355f21e6d1965UL;
  auto data = cast(const(ubyte)*)buf;
  ulong h = seed;
  ulong t;
  foreach (immutable _; 0..len/8) {
    version(HasUnalignedOps) {
      if (__ctfe) {
        t = mixin(Get8Bytes);
      } else {
        t = *cast(ulong*)data;
      }
    } else {
      t = mixin(Get8Bytes);
    }
    data += 8;
    t ^= t>>23;
    t *= 0x2127599bf4325c37UL;
    t ^= t>>47;
    h ^= t;
    h *= m;
  }

  h ^= len*m;
  t = 0;
  switch (len&7) {
    case 7: t ^= cast(ulong)data[6]<<48; goto case 6;
    case 6: t ^= cast(ulong)data[5]<<40; goto case 5;
    case 5: t ^= cast(ulong)data[4]<<32; goto case 4;
    case 4: t ^= cast(ulong)data[3]<<24; goto case 3;
    case 3: t ^= cast(ulong)data[2]<<16; goto case 2;
    case 2: t ^= cast(ulong)data[1]<<8; goto case 1;
    case 1: t ^= cast(ulong)data[0]; goto default;
    default:
      t ^= t>>23;
      t *= 0x2127599bf4325c37UL;
      t ^= t>>47;
      h ^= t;
      h *= m;
      break;
  }

  h ^= h>>23;
  h *= 0x2127599bf4325c37UL;
  h ^= h>>47;
  static if (usize.sizeof == 4) {
    // 32-bit hash
    // the following trick converts the 64-bit hashcode to Fermat
    // residue, which shall retain information from both the higher
    // and lower parts of hashcode.
    return cast(usize)(h-(h>>32));
  } else {
    return h;
  }
}
