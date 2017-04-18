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
// VFS utils
module iv.vfs.util;


public void arrayAppendUnsafe(T) (ref T[] arr, auto ref T val) {
  auto xptr = arr.ptr;
  arr ~= val;
  if (arr.ptr !is xptr) {
    import core.memory : GC;
    xptr = arr.ptr;
    if (xptr is GC.addrOf(xptr)) GC.setAttr(xptr, GC.BlkAttr.NO_INTERIOR);
  }
}


public uint crc32 (const(void)[] buf, uint crc=0) pure nothrow @trusted @nogc {
  /*
  static immutable uint[16] crctab = [
    0x00000000, 0x1db71064, 0x3b6e20c8, 0x26d930ac,
    0x76dc4190, 0x6b6b51f4, 0x4db26158, 0x5005713c,
    0xedb88320, 0xf00f9344, 0xd6d6a3e8, 0xcb61b38c,
    0x9b64c2b0, 0x86d3d2d4, 0xa00ae278, 0xbdbdf21c,
  ];
  */
  static immutable uint[16] crctab = {
    uint[16] res = void;
    // make exclusive-or pattern from polynomial (0xedb88320u)
    // terms of polynomial defining this crc (except x^32)
    //uint poly = 0; // polynomial exclusive-or pattern
    //foreach (immutable n; [0,1,2,4,5,7,8,10,11,12,16,22,23,26]) poly |= 1u<<(31-n);
    enum poly = 0xedb88320u;
    foreach (immutable n; 0..16) {
      uint c = cast(uint)n*16;
      foreach (immutable k; 0..8) c = (c&1 ? poly^(c>>1) : c>>1);
      res[n] = c;
    }
    return res;
  }();

  if (buf.length) {
    crc ^= 0xffff_ffffu;
    foreach (ubyte b; cast(const(ubyte)[])buf) {
      crc ^= b;
      crc = crctab.ptr[crc&0x0f]^(crc>>4);
      crc = crctab.ptr[crc&0x0f]^(crc>>4);
    }
    crc ^= 0xffff_ffffu;
  }
  return crc;
}
