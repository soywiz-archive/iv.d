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
/*
 * A tiny hack to redirect all GC allocations to a fixed size arena.
 *
 * Say, you've got an operation that actively allocates in GC'ed heap but
 * after it's complete you don't need anything it allocated. And you need
 * to do it in a loop many times, potentially allocating lots of memory.
 * Just add one line in the beginning of loop's scope and each iteration
 * will reuse the same fixed size buffer.
 * Like this:
 *
 *   foreach (fname; files) {
 *     auto ar = useCleanArena(); // (1)
 *     auto img = readPng(fname).getAsTrueColorImage();
 *     process(img);
 *     // (2)
 *   }
 *
 * Between points (1) and (2) all GC allocations will happen inside
 * an arena which will be reused on each iteration. No GC will happen,
 * no garbage accumulated.
 *
 * If you need some data created inbetween, you can temporarily pause
 * using the arena and allocate something on main GC heap:
 *
 *   void testArena () {
 *     auto ar = useCleanArena();
 *     auto s = new ubyte[100]; // allocated in arena
 *     {
 *       auto pause = pauseArena();  // in this scope it's not used
 *       auto t = new ubyte[200];    // allocated in main GC heap
 *     }
 *     auto v = new ubyte[300];   // allocated in arena again
 *     writeln("hi");
 *     // end of scope, stop using arena
 *   }
 *
 * You can set size for arena by calling setArenaSize() before its first use.
 * Default size is 64 MB.
 */
module iv.gcarena /*is aliced*/;
import iv.alice;


// ////////////////////////////////////////////////////////////////////////// //
void setArenaSize (usize totalSize) {
  gcaData.arena_size = totalSize;
}


struct ArenaHandler {
private:
  bool stopped = false;

public:
  @disable this (this);
  ~this () @trusted nothrow => stop();

  void stop () @trusted nothrow {
    if (stopped) return;
    gcaData.clearProxy();
    stopped = true;
  }

  @property usize allocated () const @trusted nothrow @nogc => gcaData.arena_pos;
  @property isStopped () pure const @safe nothrow @nogc => stopped;
}


// use template to autodeduce attributes
auto useCleanArena() () {
  gcaData.arena_pos = 0;
  gcaData.installProxy();
  return ArenaHandler();
}


// use template to autodeduce attributes
auto pauseArena() () {
  gcaData.clearProxy();
  struct ArenaPause {
    @disable this (this);
    ~this () @trusted nothrow @nogc => gcaData.installProxy();
  }
  return ArenaPause();
}


// ////////////////////////////////////////////////////////////////////////// //
private:
import core.memory;

alias BlkInfo = GC.BlkInfo;

// copied from proxy.d (d runtime)
struct Proxy {
extern (C):
  void function () @trusted nothrow  gc_enable;
  void function () @trusted nothrow  gc_disable;
  void function () @trusted nothrow  gc_collect;
  void function () @trusted nothrow  gc_minimize;

  uint function (void*) @trusted nothrow  gc_getAttr;
  uint function (void*, uint) @trusted nothrow  gc_setAttr;
  uint function (void*, uint) @trusted nothrow  gc_clrAttr;

  void* function (usize, uint, const TypeInfo) @trusted nothrow  gc_malloc;
  BlkInfo function (usize, uint, const TypeInfo) @trusted nothrow  gc_qalloc;
  void* function (usize, uint, const TypeInfo) @trusted nothrow  gc_calloc;
  void* function (void*, usize, uint ba, const TypeInfo) @trusted nothrow  gc_realloc;
  usize function (void*, usize, usize, const TypeInfo) @trusted nothrow  gc_extend;
  usize function (usize) @trusted nothrow  gc_reserve;
  void function (void*) @trusted nothrow  gc_free;

  void* function (void*) @trusted nothrow  gc_addrOf;
  usize function (void*) @trusted nothrow  gc_sizeOf;

  BlkInfo function (void*) @trusted nothrow  gc_query;

  void function (void*) @trusted nothrow  gc_addRoot;
  void function (void*, usize, const TypeInfo) @trusted nothrow  gc_addRange;

  void function (void*) @trusted nothrow  gc_removeRoot;
  void function (void*) @trusted nothrow  gc_removeRange;
  void function (in void[]) @trusted nothrow  gc_runFinalizers;
}


// ////////////////////////////////////////////////////////////////////////// //
struct GCAData {
  Proxy myProxy;
  Proxy* pOrg; // pointer to original Proxy of runtime
  Proxy** pproxy;

  ubyte[] arena_bytes;
  usize arena_pos = 0;
  usize arena_size = 64*1024*1024;

  void initProxy () @trusted nothrow @nogc {
    pOrg = gc_getProxy();
    pproxy = cast(Proxy**)(cast(byte*)pOrg+Proxy.sizeof);
    foreach (/*auto*/ funname; __traits(allMembers, Proxy)) __traits(getMember, myProxy, funname) = &genCall!funname;
    myProxy.gc_malloc = &gca_malloc;
    myProxy.gc_qalloc = &gca_qalloc;
    myProxy.gc_calloc = &gca_calloc;
  }

  void* alloc (usize size) @trusted nothrow {
    { import core.stdc.stdio : printf; printf("!!!\n"); }
    if (arena_bytes.length == 0) {
      auto oldproxy = *pproxy;
      *pproxy = null;
      arena_bytes = new ubyte[arena_size];
      *pproxy = oldproxy;
    }
    if (arena_pos+size > arena_bytes.length) {
      import core.stdc.stdio : stderr, fprintf;
      import core.exception : onOutOfMemoryError;
      stderr.fprintf("Arena too small! arena=%u, asked for %u, need %u", cast(uint)arena_bytes.length, cast(uint)size, cast(uint)(arena_pos+size));
      onOutOfMemoryError();
    }
    auto pos = arena_pos;
    arena_pos += size;
    arena_pos = (arena_pos+15)&~15;
    return &arena_bytes[pos];
  }

  void clearArena () @trusted nothrow @nogc {
    version(test_gcarena) {
      import core.stdc.stdio : printf;
      printf("clearArena: allocated %u\n", cast(uint)arena_pos);
    }
    arena_pos = 0;
  }

  void installProxy () @trusted nothrow @nogc {
    version(test_gcarena) {
      import core.stdc.stdio : printf;
      printf("using arena now\n");
    }
    *pproxy = &myProxy;
  }

  void clearProxy () @trusted nothrow {
    version(test_gcarena) {
      import core.stdc.stdio : printf;
      printf("using GC now\n");
    }
    *pproxy = null;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
extern(C) {
  Proxy* gc_getProxy () @trusted nothrow @nogc;

  auto genCall(string funname) (FunArgsTypes!funname args) {
    *gcaData.pproxy = null;
    scope(exit) *gcaData.pproxy = &gcaData.myProxy;
    return __traits(getMember, *gcaData.pOrg, funname)(args);
  }

  void* gca_malloc (usize sz, uint ba, const TypeInfo ti) @trusted nothrow {
    version(test_gcarena) {
      import core.stdc.stdio : printf;
      printf("gca_malloc %u\n", cast(uint)sz);
    }
    return gcaData.alloc(sz);
  }

  BlkInfo gca_qalloc (usize sz, uint ba, const TypeInfo ti) @trusted nothrow {
    version(test_gcarena) {
      import core.stdc.stdio : printf;
      printf("gca_qalloc %u\n", cast(uint)sz);
    }
    auto pos0 = gcaData.arena_pos;
    BlkInfo b;
    b.base = gcaData.alloc(sz);
    b.size = gcaData.arena_pos-pos0;
    b.attr = ba;
    return b;
  }

  void* gca_calloc (usize sz, uint ba, const TypeInfo ti) @trusted nothrow {
    import core.stdc.string : memset;
    version(test_gcarena) {
      import core.stdc.stdio : printf;
      printf("gca_calloc %u\n", cast(uint)sz);
    }
    void* p = gcaData.alloc(sz);
    memset(p, 0, sz);
    return p;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
template FunArgsTypes(string funname) {
  import std.traits : ParameterTypeTuple;
  alias FunType = typeof(*__traits(getMember, gcaData.myProxy, funname));
  alias FunArgsTypes = ParameterTypeTuple!FunType;
}


// ////////////////////////////////////////////////////////////////////////// //
GCAData gcaData; // thread local


static this () {
  gcaData.initProxy();
}


// ////////////////////////////////////////////////////////////////////////// //
version(test_gcarena)
unittest {
  import core.stdc.stdio : printf;
  auto ar = useCleanArena();
  auto s = new ubyte[100]; // allocated in arena
  {
    auto pause = pauseArena();  // in this scope it's not used
    auto t = new ubyte[200];    // allocated in main GC heap
  }
  auto v = new ubyte[300];   // allocated in arena again
  printf("hi\n");
  // end of scope, stop using arena
}
