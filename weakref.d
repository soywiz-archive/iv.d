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
// a thread-safe weak reference implementation
// http://forum.dlang.org/thread/jjote0$1cql$1@digitalmars.com
module iv.weakref is aliced;

import core.atomic, core.memory;


private alias void delegate (Object) DEvent;
private extern (C) void rt_attachDisposeEvent (Object h, DEvent e);
private extern (C) void rt_detachDisposeEvent (Object h, DEvent e);

final class Weak(T : Object) {
  enum PointerMask = 0xa5a5a5a5u;

  // Note: This class uses a clever trick which works fine for
  // a conservative GC that was never intended to do
  // compaction/copying in the first place. However, if compaction is
  // ever added to D's GC, this class will break horribly. If D ever
  // gets such a GC, we should push strongly for built-in weak
  // references.

  private usize mObject;
  private usize mPtr;
  private usize mHash;

  this (T obj=null) @trusted { hook(obj); }

  @property T object () const nothrow @trusted {
    auto obj = cast(T)cast(void*)(atomicLoad(*cast(shared)&mObject)^PointerMask);
    // we've moved obj into the GC-scanned stack space, so it's now
    // safe to ask the GC whether the object is still alive.
    // note that even if the cast and assignment of the obj local
    // doesn't put the object on the stack, this call will.
    // so, either way, this is safe.
    if (obj !is null && GC.addrOf(cast(void*)obj)) return obj;
    return null;
  }

  @property void object (T obj) @trusted {
    auto oobj = cast(T)cast(void*)(atomicLoad(*cast(shared)&mObject)^PointerMask);
    if (oobj !is null && GC.addrOf(cast(void*)oobj)) unhook(oobj);
    oobj = null;
    hook(obj);
  }

  @property bool empty () const pure nothrow @trusted { pragma(inline, true); return (object is null); }

  void clear () @trusted { object = null; }

  void opAssign (T obj) @trusted { object = obj; }

  private void hook (Object obj) @trusted {
    if (obj !is null) {
      //auto ptr = cast(usize)cast(void*)obj;
      // fix from Andrej Mitrovic
      auto ptr = cast(usize)*(cast(void**)&obj);
      ptr ^= PointerMask;
      // we use atomics because not all architectures may guarantee atomic store and load of these values
      atomicStore(*cast(shared)&mObject, ptr);
      // only assigned once, so no atomics
      mPtr = ptr;
      mHash = typeid(T).getHash(&obj);
      rt_attachDisposeEvent(obj, &unhook);
      GC.setAttr(cast(void*)this, GC.BlkAttr.NO_SCAN);
    } else {
      atomicStore(*cast(shared)&mObject, cast(usize)0^PointerMask);
    }
  }

  private void unhook (Object obj) @trusted {
    rt_detachDisposeEvent(obj, &unhook);
    // this assignment is important.
    // if we don't null mObject when it is collected, the check
    // in object could return false positives where the GC has
    // reused the memory for a new object.
    atomicStore(*cast(shared)&mObject, cast(usize)0^PointerMask);
  }

  override bool opEquals (Object o) nothrow @trusted {
    if (this is o) return true;
    if (auto weak = cast(Weak!T)o) return (mPtr == weak.mPtr);
    return false;
  }

  override int opCmp (Object o) nothrow @trusted {
    if (auto weak = cast(Weak!T)o) return (mPtr > weak.mPtr ? 1 : mPtr < weak.mPtr ? -1 : 0);
    return 1;
  }

  override usize toHash () nothrow @trusted {
    auto obj = object;
    return (obj ? typeid(T).getHash(&obj) : mHash);
  }

  override string toString () {
    auto obj = object;
    return (obj ? obj.toString() : toString());
  }
}


version(weakref_test) unittest {
  import core.memory;
  import std.stdio;

  static class A {
    int n;
    this (int nn) @trusted nothrow { n = nn; }
    ~this () @trusted @nogc { import core.stdc.stdio : printf; printf("A:~this()\n"); }
  }

  auto a = new A(42);
  //auto wr = new Weak!A(a);
  Weak!A wr = new Weak!A(a);
  writefln("w=%s", wr.empty);
  assert(!wr.empty);
  delete a;
  writefln("w=%s", wr.empty);
  GC.collect();
  writefln("w=%s", wr.empty);
  assert(wr.empty);

  a = new A(666);
  wr.object = a;
  writefln("w=%s", wr.empty);
  assert(!wr.empty);
  wr.clear();
  writefln("w=%s", wr.empty);
  assert(wr.empty);

  wr = a;
  writefln("w=%s", wr.empty);
  assert(!wr.empty);
  wr.object = null;
  writefln("w=%s", wr.empty);
  assert(wr.empty);
}
