/*
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
// some "unsafe" array operations
// such arrays should be always anchored to first element
module iv.unarray /*is aliced*/;
import iv.alice;


// ////////////////////////////////////////////////////////////////////////// //
public void unsafeArrayReserve(T) (ref T[] arr, int newlen) /*nothrow*/ {
  if (newlen < 0 || newlen >= int.max/2) assert(0, "invalid number of elements in array");
  if (arr.length < newlen) {
    auto optr = arr.ptr;
    arr.reserve(newlen);
    if (arr.ptr !is optr) {
      import core.memory : GC;
      optr = arr.ptr;
      if (optr is GC.addrOf(optr)) GC.setAttr(optr, GC.BlkAttr.NO_INTERIOR);
    }
  }
}


public void unsafeArraySetLength(T) (ref T[] arr, int newlen) /*nothrow*/ {
  if (newlen < 0 || newlen >= int.max/2) assert(0, "invalid number of elements in array");
  if (arr.length > newlen) {
    arr.length = newlen;
    arr.assumeSafeAppend;
  } else if (arr.length < newlen) {
    auto optr = arr.ptr;
    arr.length = newlen;
    if (arr.ptr !is optr) {
      import core.memory : GC;
      optr = arr.ptr;
      if (optr is GC.addrOf(optr)) GC.setAttr(optr, GC.BlkAttr.NO_INTERIOR);
    }
  }
}


public void unsafeArrayAppend(T) (ref T[] arr, auto ref T v) /*nothrow*/ {
  if (arr.length >= int.max/2) assert(0, "too many elements in array");
  auto optr = arr.ptr;
  arr ~= v;
  if (arr.ptr !is optr) {
    import core.memory : GC;
    optr = arr.ptr;
    if (optr is GC.addrOf(optr)) GC.setAttr(optr, GC.BlkAttr.NO_INTERIOR);
  }
}


public void unsafeArrayClear(T) (ref T[] arr) /*nothrow*/ {
  if (arr.length) {
    import core.stdc.string : memset;
    static if (is(T == class)) arr[] = null; /*else arr[] = T.init;*/
    memset(arr.ptr, 0, arr.length*T.sizeof);
    arr.length = 0;
    arr.assumeSafeAppend;
  }
}


public void unsafeArrayRemove(T) (ref T[] arr, int idx) /*nothrow*/ {
  if (idx < 0 || idx >= arr.length) assert(0, "invalid index in `unsafeArrayRemove()`");
  static if (is(T == class)) arr[idx] = null; else arr[idx] = T.init;
  if (arr.length-idx > 1) {
    import core.stdc.string : memset, memmove;
    memmove(arr.ptr+idx, arr.ptr+idx+1, (arr.length-idx-1)*T.sizeof);
    memset(arr.ptr+arr.length-1, 0, T.sizeof);
  }
  arr.length -= 1;
  arr.assumeSafeAppend;
}


public void unsafeArrayInsertBefore(T) (ref T[] arr, int idx, auto ref T v) /*nothrow*/ {
  if (idx < 0 || idx > arr.length) assert(0, "invalid index in `unsafeArrayRemove()`");
  auto olen = cast(int)arr.length;
  if (olen >= int.max/2) assert(0, "too many elements in array");
  auto optr = arr.ptr;
  arr.length += 1;
  if (arr.ptr != optr) {
    import core.memory : GC;
    optr = arr.ptr;
    if (optr is GC.addrOf(optr)) GC.setAttr(optr, GC.BlkAttr.NO_INTERIOR);
  }
  // move elements down
  if (idx < olen) {
    import core.stdc.string : memset, memmove;
    memmove(arr.ptr+idx+1, arr.ptr+idx, (olen-idx)*T.sizeof);
    memset(arr.ptr+idx, 0, T.sizeof);
  }
  arr[idx] = v;
}
