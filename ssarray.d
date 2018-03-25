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
module iv.ssarray /*is aliced*/;

version(aliced) {} else private alias usize = size_t;


/** Array implementation that doesn't fragment memory, and does no `realloc()`s.
 *
 * I.e. `SSArray` will never move its items on resizing.
 * Also, there is no need to "reserve" space in `SSArray`, it won't make your
 * code faster, 'cause total number of `malloc()`s will be the same.
 *
 * $(WARNING This completely ignores any postblits and dtors!)
 */
static struct SSArray(T, bool initNewElements=true, uint MemPageSize=4096) if (T.sizeof <= MemPageSize) {
//debug = debug_ssarray;
public nothrow @trusted @nogc:
  enum PageSize = MemPageSize;
  alias Me = SSArray!T;
  alias ValueT = T;

private:
  enum ItemsPerPage = cast(uint)(PageSize/T.sizeof); // items per one page

  static struct PageStore {
    enum RefsPerPage = cast(uint)(PageSize/(void*).sizeof); // page pointers per one page
  nothrow @trusted @nogc:
    uint rc; // refcounter
    void** mHugeDir; // 2nd level directory page (allocated if mHugeRefs > 0; points to 1st level directories), or 1st level directory page (if mHugeRefs == 0)
    uint mHugeRefs; // number of refs in hugedir page
    uint mAllocPages; // number of allocated data pages
    uint xcount; // we'll keep it here too, so range iterators can use it

    @disable this (this);
    void opAssign() (in auto ref typeof(this)) { static assert(0, `assigning disabled`); }

    @property uint allocedPages () const pure { pragma(inline, true); return mAllocPages; }

    // so i can easily override it
    void freePage(void* ptr) {
      pragma(inline, true);
      if (ptr !is null) {
        import core.stdc.stdlib : free;
        free(ptr);
      }
    }

    // so i can easily override it
    void* mallocPage(bool doClear) () {
      import core.stdc.stdlib : malloc;
      static if (doClear) {
        if (auto res = malloc(PageSize)) {
          import core.stdc.string : memset;
          memset(res, 0, PageSize);
          return res;
        } else {
          return null;
        }
      } else {
        pragma(inline, true);
        return malloc(PageSize);
      }
    }

    // allocate one new page
    bool allocNewPage(bool requireMem) () {
      if (mHugeRefs == 0 && mAllocPages == RefsPerPage) {
        // we need to create hugedir
        debug(debug_ssarray) {{ import core.stdc.stdio; printf("%p: creating hugedir (%p)\n", &this, mHugeDir); }}
        auto vv = cast(void**)mallocPage!true;
        static if (!requireMem) { if (vv is null) return false; } else
        if (vv is null) assert(0, "PageStore: out of memory");
        assert(mHugeDir !is null);
        vv[0] = mHugeDir; // first 1st level page
        mHugeDir = vv;
        mHugeRefs = 1;
      }
      // allocate new data page (we'll need it anyway)
      auto dp = mallocPage!false; // don't clear
      static if (!requireMem) { if (dp is null) return false; } else
      if (dp is null) assert(0, "PageStore: out of memory");
      // simple case?
      if (mHugeRefs == 0) {
        if (mAllocPages == 0 && mHugeDir is null) {
          // no dir page, allocate one
          debug(debug_ssarray) {{ import core.stdc.stdio; printf("%p: creating smalldir\n", &this); }}
          void** hd = cast(void**)mallocPage!true;
          static if (!requireMem) { if (hd is null) { freePage(dp); return false; } } else
          if (hd is null) assert(0, "PageStore: out of memory");
          mHugeDir = hd;
        }
        assert(mAllocPages+1 <= RefsPerPage);
        mHugeDir[mAllocPages++] = dp;
      } else {
        // allocate new 1st level directory page if necessary
        uint dirpgeidx = 0;
        void** dirpg = void;
        if (mAllocPages%RefsPerPage == 0) {
          debug(debug_ssarray) {{ import core.stdc.stdio; printf("%p: creating new 1st-level dir page (ap=%u; hr=%u)\n", &this, mAllocPages, mHugeRefs); }}
          // yep, last 1st level page is full, allocate new one
          if (mHugeRefs == RefsPerPage) assert(0, "PageStore: out of directory space");
          dirpg = cast(void**)mallocPage!true;
          static if (!requireMem) { if (dirpg is null) { freePage(dp); return false; } } else
          if (dirpg is null) assert(0, "PageStore: out of memory");
          mHugeDir[mHugeRefs++] = dirpg;
          debug(debug_ssarray) {{ import core.stdc.stdio; printf("%p: new huge item! pa=%u; hr=%u; ptr=%p\n", &this, mAllocPages, mHugeRefs, dirpg); }}
        } else {
          // there should be some room in last 1st level page
          assert(mHugeRefs > 0);
          dirpg = cast(void**)mHugeDir[mHugeRefs-1];
          dirpgeidx = mAllocPages%RefsPerPage;
          assert(dirpg[dirpgeidx] is null);
        }
        dirpg[dirpgeidx] = dp;
        ++mAllocPages;
      }
      return true;
    }

    void freeLastPage () {
      if (mAllocPages == 0) return;
      --mAllocPages; // little optimization: avoid `-1` everywhere
      if (mHugeRefs == 0) {
        // easy case
        // free last data page
        freePage(mHugeDir[mAllocPages]);
        mHugeDir[mAllocPages] = null; // why not?
        if (mAllocPages == 0) {
          // free catalog page too
          debug(debug_ssarray) {{ import core.stdc.stdio; printf("%p: freeing smalldir\n", &this); }}
          freePage(mHugeDir);
          mHugeDir = null;
        }
      } else {
        // hard case
        assert(mAllocPages != 0);
        immutable uint lv1pgidx = mAllocPages/RefsPerPage;
        immutable uint dtpgidx = mAllocPages%RefsPerPage;
        // free last data page
        void** pp = cast(void**)mHugeDir[lv1pgidx];
        freePage(pp[dtpgidx]);
        pp[dtpgidx] = null; // required
        if (dtpgidx == 0) {
          debug(debug_ssarray) {{ import core.stdc.stdio; printf("%p: freeing last 1st-level dir page (ap=%u)\n", &this, mAllocPages); }}
          // we should free this catalog page too
          freePage(pp);
          --mHugeRefs;
          // convert to one-level?
          if (mAllocPages == RefsPerPage) {
            assert(mHugeRefs == 1);
            debug(debug_ssarray) {{ import core.stdc.stdio; printf("%p: converting to smalldir\n", &this); }}
            pp = cast(void**)mHugeDir[0];
            // drop huge catalog page
            freePage(mHugeDir);
            mHugeDir = pp;
            mHugeRefs = 0;
          }
        }
      }
    }

    // ensure that we have at least this number of bytes
    void ensureSize(bool requireMem) (uint size) {
      if (size >= uint.max/2) assert(0, "PageStore: out of memory"); // 2GB is enough for everyone!
      while (size > mAllocPages*PageSize) {
        if (!allocNewPage!requireMem()) {
          static if (!requireMem) break; else assert(0, "PageStore: out of memory");
        }
      }
    }

    // ensure that we have at least this number of pages
    void ensurePages(bool requireMem) (uint pgcount) {
      if (pgcount >= uint.max/2/PageSize) assert(0, "PageStore: out of memory"); // 2GB is enough for everyone!
      while (pgcount > mAllocPages) {
        if (!allocNewPage!requireMem()) {
          static if (!requireMem) break; else assert(0, "PageStore: out of memory");
        }
      }
    }

    // free everything
    void clear () {
      import core.stdc.string : memset;
      if (mHugeRefs == 0) {
        foreach (void* pg1; mHugeDir[0..mAllocPages]) freePage(pg1);
      } else {
        // for each 1st level dir page
        foreach (void* pg1; mHugeDir[0..mHugeRefs]) {
          // for each page in 1st level dir page
          foreach (void* dpg; (cast(void**)pg1)[0..RefsPerPage]) freePage(dpg);
          freePage(pg1);
        }
      }
      freePage(mHugeDir);
      memset(&this, 0, this.sizeof);
    }

    // get pointer to the first byte of the page with the given index
    inout(ubyte)* pagePtr (uint pgidx) inout pure {
      pragma(inline, true);
      return
        pgidx < mAllocPages ?
        (mHugeRefs == 0 ?
          cast(inout(ubyte)*)mHugeDir[pgidx] :
          cast(inout(ubyte)*)(cast(void**)mHugeDir[pgidx/RefsPerPage])[pgidx%RefsPerPage]) :
        null;
    }
  }

private:
  usize psptr;

  @property inout(PageStore)* psp () inout pure { pragma(inline, true); return cast(inout(PageStore*))psptr; }

  // ugly hack, but it never returns anyway
  static void boundsError (uint idx, uint len) pure {
    import std.traits : functionAttributes, FunctionAttribute, functionLinkage, SetFunctionAttributes, isFunctionPointer, isDelegate;
    static auto assumePure(T) (scope T t) if (isFunctionPointer!T || isDelegate!T) {
      enum attrs = functionAttributes!T|FunctionAttribute.pure_;
      return cast(SetFunctionAttributes!(T, functionLinkage!T, attrs))t;
    }
    assumePure((){
      import core.stdc.stdlib : malloc;
      import core.stdc.stdio : snprintf;
      char* msg = cast(char*)malloc(1024);
      auto len = snprintf(msg, 1024, "SSArray: out of bounds access; index=%u; length=%u", idx, len);
      assert(0, msg[0..len]);
    })();
  }

  uint lengthInFullPages () const pure {
    pragma(inline, true);
    if (psptr) {
      uint len = (cast(PageStore*)psptr).xcount;
      return (len+ItemsPerPage-1)/ItemsPerPage;
    } else {
      return 0;
    }
  }

  static uint lengthInFullPages (uint count) pure {
    pragma(inline, true);
    return (count+ItemsPerPage-1)/ItemsPerPage;
  }

public:
  this (this) pure { pragma(inline, true); if (psptr) ++(cast(PageStore*)psptr).rc; }

  ~this () {
    pragma(inline, true);
    if (psptr) {
      if (--(cast(PageStore*)psptr).rc == 0) (cast(PageStore*)psptr).clear();
    }
  }

  void opAssign() (in auto ref Me src) pure {
    pragma(inline, true);
    if (src.psptr) ++(cast(PageStore*)src.psptr).rc;
    if (psptr) {
      if (--(cast(PageStore*)psptr).rc == 0) (cast(PageStore*)psptr).clear();
    }
    psptr = src.psptr;
  }

  /// remove all elements, free all memory
  void clear () {
    pragma(inline, true);
    if (psptr) {
      if (--(cast(PageStore*)psptr).rc == 0) (cast(PageStore*)psptr).clear();
    }
  }

  ref inout(T) currWrap (uint idx) inout pure { pragma(inline, true); if (length == 0) assert(0, "SSArray: bounds error"); return this[idx%length]; } /// does wraparound
  ref inout(T) prevWrap (uint idx) inout pure { pragma(inline, true); if (length == 0) assert(0, "SSArray: bounds error"); return this[(idx+length-1)%length]; } /// does wraparound
  ref inout(T) nextWrap (uint idx) inout pure { pragma(inline, true); if (length == 0) assert(0, "SSArray: bounds error"); return this[(idx+1)%length]; } /// does wraparound

  /// returns number of elements in the array
  @property uint length () const pure { pragma(inline, true); return (psptr ? (cast(PageStore*)psptr).xcount : 0); }
  /// sets new number of elements in the array (will free memory on shrinking)
  @property void length (usize count) {
    pragma(inline, true);
    static if (usize.sizeof == 4) {
      setLength(count);
    } else {
      if (count > uint.max/2) assert(0, "SSArray: out of memory");
      setLength(cast(uint)count);
    }
  }
  alias opDollar = length;

  ///
  ref inout(T) opIndex (uint idx) inout pure {
    pragma(inline, true);
    if (idx >= length) boundsError(idx, length);
    return *((cast(inout(T)*)((cast(PageStore*)psptr).pagePtr(idx/ItemsPerPage)))+idx%ItemsPerPage);
  }

  private void ensurePS () {
    if (psptr == 0) {
      // allocate new
      import core.stdc.stdlib : malloc;
      import core.stdc.string : memset;
      auto psx = cast(PageStore*)malloc(PageStore.sizeof);
      if (psx is null) assert(0, "SSArray: out of memory"); // anyway
      memset(psx, 0, PageStore.sizeof);
      psx.rc = 1;
      psptr = cast(usize)psx;
    }
  }

  /// reserve memory for the given number of elements (fail hard if `requireMem` is `true`)
  void reserve(bool requireMem=false) (uint count) {
    if (count == 0) return;
    if (uint.max/2/T.sizeof < count) {
      static if (requireMem) assert(0, "SSArray: out of memory");
      else count = uint.max/2/T.sizeof;
    }
    ensurePS();
    psp.ensureSize!requireMem(lengthInFullPages(cast(uint)(T.sizeof*count))*PageSize);
  }

  /// set new array length.
  /// if `doShrinkFree` is `true`, free memory on shrinking.
  /// if `doClear` is `true`, fill new elements with `.init` on grow.
  /// reserve memory for the given number of elements (fail hard if `requireMem` is `true`)
  void setLength(bool doShrinkFree=false, bool doClear=initNewElements) (uint count) {
    if (uint.max/2/T.sizeof < count) assert(0, "SSArray: out of memory");
    if (count == length) return;
    if (count == 0) { if (psptr) (cast(PageStore*)psptr).clear(); return; }
    uint newPageCount = lengthInFullPages(count);
    assert(newPageCount > 0);
    ensurePS();
    if (count < (cast(PageStore*)psptr).xcount) {
      // shrink
      static if (doShrinkFree) {
        while ((cast(PageStore*)psptr).allocedPages > newPageCount) (cast(PageStore*)psptr).freeLastPage();
      }
      (cast(PageStore*)psptr).xcount = count;
    } else {
      // grow
      debug(debug_ssarray) if (psptr) { import core.stdc.stdio; printf("%p: grow000: ap=%u; sz=%u; qsz=%u; itperpage=%u; count=%u; length=%u\n", &this, (cast(PageStore*)psptr).allocedPages, (cast(PageStore*)psptr).allocedPages*PageSize, count*T.sizeof, ItemsPerPage, count, length); }
      (cast(PageStore*)psptr).ensurePages!true(newPageCount);
      static if (doClear) {
        static if (__traits(isIntegral, T) && T.init == 0) {
        } else {
          static immutable it = T.init;
          static bool checked = false;
          static bool isZero = false;
          if (!checked) {
            ubyte b = 0;
            foreach (immutable ubyte v; (cast(immutable(ubyte)*)(&it))[0..it.sizeof]) b |= v;
            isZero = (b == 0);
            checked = true;
          }
        }
        // fill up previous last page
        if ((cast(PageStore*)psptr).xcount%ItemsPerPage != 0) {
          uint itemsLeft = ItemsPerPage-(cast(PageStore*)psptr).xcount%ItemsPerPage;
          if (itemsLeft > count-(cast(PageStore*)psptr).xcount) itemsLeft = count-(cast(PageStore*)psptr).xcount;
          auto cp = (cast(T*)((cast(PageStore*)psptr).pagePtr((cast(PageStore*)psptr).xcount/ItemsPerPage)))+(cast(PageStore*)psptr).xcount%ItemsPerPage;
          (cast(PageStore*)psptr).xcount += itemsLeft;
          static if (__traits(isIntegral, T) && T.init == 0) {
            import core.stdc.string : memset;
            //pragma(msg, "ZEROING! (000)");
            memset(cp, 0, itemsLeft*T.sizeof);
          } else {
            if (isZero) {
              import core.stdc.string : memset;
              debug(debug_ssarray) {{ import core.stdc.stdio; printf("%p: ZERO FILL(000)\n", psp); }}
              memset(cp, 0, itemsLeft*T.sizeof);
            } else {
              import core.stdc.string : memcpy;
              while (itemsLeft--) {
                memcpy(cp, &it, it.sizeof);
                ++cp;
              }
            }
          }
          if (count == (cast(PageStore*)psptr).xcount) return;
        }
        // fill full pages
        assert((cast(PageStore*)psptr).xcount%ItemsPerPage == 0);
        while ((cast(PageStore*)psptr).xcount < count) {
          uint ileft = count-(cast(PageStore*)psptr).xcount;
          if (ileft > ItemsPerPage) ileft = ItemsPerPage;
          auto cp = cast(T*)((cast(PageStore*)psptr).pagePtr((cast(PageStore*)psptr).xcount/ItemsPerPage));
          //debug(debug_ssarray) {{ import core.stdc.stdio; printf("%p: xcount=%u; cp=%p; ileft=%u\n", psp, xcount, cp, ileft); }}
          (cast(PageStore*)psptr).xcount += ileft;
          static if (__traits(isIntegral, T) && T.init == 0) {
            import core.stdc.string : memset;
            //pragma(msg, "ZEROING! (001)");
            memset(cp, 0, ileft*T.sizeof);
          } else {
            if (isZero) {
              import core.stdc.string : memset;
              debug(debug_ssarray) {{ import core.stdc.stdio; printf("%p: ZERO FILL(001)\n", psp); }}
              memset(cp, 0, ileft*T.sizeof);
            } else {
              import core.stdc.string : memcpy;
              while (ileft--) {
                memcpy(cp, &it, it.sizeof);
                ++cp;
              }
            }
          }
        }
      } else {
        (cast(PageStore*)psptr).xcount = count;
      }
    }
  }

  /// remove `size` last elements, but don't free memory.
  /// won't fail if `size` > `length`.
  void chop (uint size) {
    pragma(inline, true);
    if (psptr) {
      if (size > length) {
        (cast(PageStore*)psptr).xcount = 0;
      } else {
        (cast(PageStore*)psptr).xcount -= size;
      }
    }
  }

  /// remove all array elements, but don't free any memory.
  void chopAll () { pragma(inline, true); if (psptr) (cast(PageStore*)psptr).xcount = 0; }

  /// append new element to the array. uses `memcpy()` to copy data.
  void append() (in auto ref T t) {
    import core.stdc.string : memcpy;
    setLength!(false, false)(length+1); // don't clear, don't shrink
    memcpy(&this[$-1], &t, T.sizeof);
  }

  /// append new element to the array. uses `memcpy()` to copy data.
  void opOpAssign(string op:"~") (in auto ref T t) { pragma(inline, true); append(t); }

  // i HAET it!
  private import std.traits : ParameterTypeTuple;

  int opApply(DG) (scope DG dg) if (ParameterTypeTuple!DG.length == 1 || ParameterTypeTuple!DG.length == 2) {
    // don't use `foreach` here, we *really* want to re-check length on each iteration
    for (uint idx = 0; idx < (cast(PageStore*)psptr).xcount; ++idx) {
      static if (ParameterTypeTuple!DG.length == 1) {
        // one arg
        if (auto res = dg(this[idx])) return res;
      } else {
        // two args
        uint xidx = idx;
        if (auto res = dg(xidx, this[idx])) return res;
      }
    }
    return 0;
  }

  int opApplyReverse(DG) (scope DG dg) if (ParameterTypeTuple!DG.length == 1 || ParameterTypeTuple!DG.length == 2) {
    foreach_reverse (immutable uint idx; 0..length) {
      if (idx >= length) return 0; // yeah, recheck it
      static if (ParameterTypeTuple!DG.length == 1) {
        // one arg
        if (auto res = dg(this[idx])) return res;
      } else {
        // two args
        uint xidx = idx;
        if (auto res = dg(xidx, this[idx])) return res;
      }
    }
    return 0;
  }

  /// range iterator
  static struct Range {
  public nothrow @trusted @nogc:
    alias ItemT = T;
  private:
    uint psptr;
    uint pos;
    uint xend;

  private:
    this (uint a, uint b, uint c) pure { pragma(inline, true); psptr = a; pos = b; xend = c; if (psptr) ++(cast(PageStore*)psptr).rc; }

  public:
    this() (in auto ref Me arr) pure { pragma(inline, true); psptr = arr.psptr; xend = arr.length; if (psptr) ++(cast(PageStore*)psptr).rc; }
    this (this) pure { if (psptr) ++(cast(PageStore*)psptr).rc; }
    ~this () {
      pragma(inline, true);
      if (psptr) {
        if (--(cast(PageStore*)psptr).rc == 0) (cast(PageStore*)psptr).clear();
      }
    }
    void opAssign() (in auto ref Range src) pure {
      pragma(inline, true);
      if (src.psptr) ++(cast(PageStore*)src.psptr).rc;
      if (psptr) {
        if (--(cast(PageStore*)psptr).rc == 0) (cast(PageStore*)psptr).clear();
      }
      psptr = src.psptr;
      pos = src.pos;
      xend = src.xend;
    }
    Range save () const { pragma(inline, true); return (empty ? Range.init : Range(psptr, pos, xend)); }
    @property bool empty () const pure { pragma(inline, true); return (psptr == 0 || pos >= xend || pos >= (cast(PageStore*)psptr).xcount); }
    @property ref inout(T) front () inout pure {
      version(aliced) pragma(inline, true);
      if (psptr && pos < xend && pos < (cast(PageStore*)psptr).xcount) {
        return *((cast(inout(T)*)((cast(PageStore*)psptr).pagePtr(pos/ItemsPerPage)))+pos%ItemsPerPage);
      } else {
        boundsError(pos, length);
        assert(0); // make compiler happy
      }
    }
    void popFront () pure { pragma(inline, true); if (!empty) ++pos; }
    uint length () const pure { pragma(inline, true); return (empty ? 0 : (xend < (cast(PageStore*)psptr).xcount ? xend : (cast(PageStore*)psptr).xcount)-pos); }
    alias opDollar = length;

    Range opSlice () const { version(aliced) pragma(inline, true); return (empty ? Range.init : Range(psptr, pos, xend)); }
    Range opSlice (uint lo, uint hi) const {
      version(aliced) pragma(inline, true);
      if (lo > length) boundsError(lo, length);
      if (hi > length) boundsError(hi, length);
      if (lo >= hi) return Range.init;
      return Range(psptr, pos+lo, pos+hi);
    }

    ref inout(T) opIndex (uint idx) inout pure {
      version(aliced) pragma(inline, true);
      if (psptr && idx >= 0 && idx < length) {
        return *((cast(inout(T)*)((cast(PageStore*)psptr).pagePtr((pos+idx)/ItemsPerPage)))+(pos+idx)%ItemsPerPage);
      } else {
        boundsError(idx, length);
        assert(0); // make compiler happy
      }
    }
  }

  ///
  Range opSlice () const { version(aliced) pragma(inline, true); return Range(this); }

  ///
  Range opSlice (uint lo, uint hi) const {
    version(aliced) pragma(inline, true);
    if (lo > length) boundsError(lo, length);
    if (hi > length) boundsError(hi, length);
    if (lo >= hi) return Range.init;
    return Range(psptr, lo, hi);
  }
}


version(test_ssarray) unittest {
  import iv.vfs.io;

  void testPostBlit (SSArray!int ssa) {
    writefln("T000: ssa ptr/rc: %x/%u/%u", ssa.psp, ssa.psp.rc, ssa.length);
    foreach (uint idx, int v; ssa) {
      assert(v == idx);
    }
  }

  {
    SSArray!int ssa;
    ssa.length = 8;
    writefln("001: ssa ptr/rc: %x/%u/%u", ssa.psp, ssa.psp.rc, ssa.length);
    foreach (uint idx, ref int v; ssa) {
      assert(v == 0);
      v = idx;
    }
    testPostBlit(ssa);

    ssa.length = ssa.PageSize/int.sizeof+128;
    writefln("002: ssa ptr/rc: %x/%u/%u; pages=%u", ssa.psp, ssa.psp.rc, ssa.length, ssa.psp.allocedPages);

    ssa.length = (ssa.PageSize/int.sizeof)*(ssa.PageSize/(void*).sizeof)+4096;
    writefln("003: ssa ptr/rc: %x/%u/%u; pages=%u", ssa.psp, ssa.psp.rc, ssa.length, ssa.psp.allocedPages);

    ssa.length = ssa.length/2;
    writefln("004: ssa ptr/rc: %x/%u/%u; pages=%u", ssa.psp, ssa.psp.rc, ssa.length, ssa.psp.allocedPages);

    uint n = 0;
    foreach (immutable uint v; ssa[2..6]) n += v;
    assert(n == 2+3+4+5);
  }
}
