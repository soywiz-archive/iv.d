/*
 * Pixel Graphics Library
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
module iv.sdpy.region;


// ////////////////////////////////////////////////////////////////////////// //
struct Region {
  @property nothrow @safe @nogc pure const {
    int width () { return rwdt; }
    int height () { return rhgt; }
    bool solid () { return (simple && simpleSolid); }
    bool empty () { return (simple && !simpleSolid); }
  }

  // this creates solid region
  this (int awidth, int aheight, bool solid=true) pure nothrow @safe @nogc { setSize(awidth, aheight, solid); }

  @disable this (this); // WARNING! this is essential!

  void setSize (int awidth, int aheight, bool solid=true) pure nothrow @safe @nogc {
    if (awidth <= 0 || aheight <= 0) awidth = aheight = 0;
    if (awidth > SpanType.max-1 || aheight > SpanType.max-1) assert(0, "Region internal error: region dimensions are too big");
    rwdt = awidth;
    rhgt = aheight;
    simpleSolid = solid;
    lineofs = null;
    data = null;
  }

  Region clone () nothrow @trusted {
    Region res = void;
    res.rwdt = this.rwdt;
    res.rhgt = this.rhgt;
    res.simple = this.simple;
    res.simpleSolid = this.simpleSolid;
    if (res.simple) {
      res.lineofs = null;
      res.data = null;
    } else {
      res.lineofs = this.lineofs.dup;
      res.data = this.data.dup;
    }
    return res;
  }

  // is given point visible?
  bool visible (int x, int y) const pure nothrow @safe @nogc {
    // easiest cases
    if (rwdt < 1 || rhgt < 1) return false;
    if (x < 0 || y < 0 || x >= rwdt || y >= rhgt) return false;
    if (simple) return simpleSolid; // ok, easy case here
    // now the hard one
    immutable ldofs = lineofs[y];
    immutable len = data[ldofs];
    debug assert(len > 1);
    auto line = data[ldofs+1..ldofs+len];
    int idx = void; // will be initied in mixin
    mixin(FindSpanMixinStr!"idx");
    debug assert(idx < line.length); // too far (the thing that should not be)
    return ((idx+(data[idx] == x))%2 == 0);
  }

  // punch a hole
  void punch (int x, int y, int w=1, int h=1) { doPunchPatch!"punch"(x, y, w, h); }

  // patch a hole
  void patch (int x, int y, int w=1, int h=1) { doPunchPatch!"patch"(x, y, w, h); }

  // ////////////////////////////////////////////////////////////////////////// //
  enum State { Mixed = -1, Empty, Solid } //WARNING! don't change the order!

  // return span state %-)
  State spanState (int y, int x0, int x1) const pure nothrow @safe @nogc {
    if (y < 0 || y >= rhgt || x1 < 0 || x0 >= rwdt || x1 < x0) return State.Empty;
    if (simple) {
      // if our span is not fully inside, it can be either Empty or Mixed
      if (simpleSolid) {
        return (x0 >= 0 && x1 < rwdt ? State.Solid : State.Mixed);
      } else {
        return State.Empty;
      }
    }
    immutable ldofs = lineofs[y];
    immutable len = data[ldofs];
    debug assert(len > 1);
    auto line = data[ldofs+1..ldofs+len];
    int idx = void; // will be initied in mixin
    immutable x = (x0 >= 0 ? x0 : 0);
    mixin(FindSpanMixinStr!"idx");
    debug assert(idx < line.length); // too far (the thing that should not be)
    // move to "real" span
    if (line[idx] == x) ++idx;
    // now, sx is line[idx-1], ex is line[idx]
    if (x1 >= (idx < line.length ? line[idx] : rwdt)) return State.Mixed;
    idx = (idx^1)&1; // we are interested only in last bit, and we converted it to State here
    // if our span is not fully inside, it can be either Empty or Mixed
    if (idx == State.Solid && x0 < 0) return State.Mixed;
    return cast(State)idx;
  }

  // call delegate for each solid or empty span
  // multiple declarations will allow us to use this in `@nogc` and `nothrow` contexts
  void spans(bool solids=true) (int y, int x0, int x1, scope void delegate (int x0, int x1) nothrow @nogc dg) { spansEnumerator!solids(y, x0, x1, dg); }
  void spans(bool solids=true) (int y, int x0, int x1, scope void delegate (int x0, int x1) @nogc dg) { spansEnumerator!solids(y, x0, x1, dg); }
  void spans(bool solids=true) (int y, int x0, int x1, scope void delegate (int x0, int x1) dg) { spansEnumerator!solids(y, x0, x1, dg); }

  //TODO: slab enumerator
private:
  // ////////////////////////////////////////////////////////////////////////// //
  void spansEnumerator(bool solids, T) (int y, int x0, int x1, scope /*void delegate (int x0, int x1)*/T dg) {
    assert(dg !is null);
    if (y < 0 || y >= rhgt || x1 < 0 || x0 >= rwdt || x1 < x0) {
      static if (!solids) dg(x0, x1);
      return;
    }
    if (simple) {
      if (simpleSolid) {
        static if (solids) {
          if (x0 < 0) x0 = 0;
          if (x1 >= rwdt) x1 = rwdt-1;
          if (x0 <= x1) dg(x0, x1);
        } else {
          if (x0 < 0) dg(x0, -1);
          if (x1 >= rwdt) dg(rwdt, x1);
        }
      } else {
        static if (!solids) dg(x0, x1);
      }
      return;
    }
    immutable ldofs = lineofs[y];
    immutable len = data[ldofs];
    debug assert(len > 1);
    auto line = data[ldofs+1..ldofs+len];
    // beyond left border? move to first solid span
    if (x0 < 0) {
      int ex = (data[ldofs+1] == 0 ? data[ldofs+2]-1 : -1);
      // is first span empty too?
      if (ex >= x1) { static if (!solids) dg(x0, x1); return; }
      static if (!solids) dg(x0, ex);
      x0 = ex+1;
    }
    static if (solids) { if (x1 >= rwdt) x1 = rwdt-1; }
    int idx = void; // will be initied in mixin
    alias x = x0; // for mixin
    mixin(FindSpanMixinStr!"idx");
    debug assert(idx < line.length); // too far (the thing that should not be)
    // move to "real" span, so sx is line[idx-1], ex+1 is line[idx]
    if (line[idx] == x) ++idx;
    // process spans
    while (x0 <= x1) {
      int ex = line[idx]-1;
      int cex = (ex < x1 ? ex : x1); // clipped ex
      // emit part from x0 to ex if necessary
      static if (solids) {
        // current span is solid?
        if (idx%2 == 0) dg(x0, cex);
      } else {
        // current span is empty?
        if (idx%2 == 1) {
          dg(x0, (ex < rwdt-1 ? cex : x1));
          if (ex == rwdt-1) return;
        } else {
          if (ex == rwdt-1) { x0 = rwdt; break; }
        }
      }
      x0 = ex+1;
      ++idx;
      //static if (!solids) { if (x0 == rwdt) break; }
    }
    static if (!solids) { if (x0 <= x1) dg(x0, x1); }
  }

  // ////////////////////////////////////////////////////////////////////////// //
  // find element index
  // always returns index of key which is >= `x`
  private enum FindSpanMixinStr(string minAndRes) = "{
    ("~minAndRes~") = 0;
    int max = cast(int)line.length;
    while (("~minAndRes~") < max) {
      int mid = (("~minAndRes~")+max)/2; // ignore possible overflow, it can't happen here
      debug assert(mid < max);
      if (line[mid] < x) ("~minAndRes~") = mid+1; else max = mid;
    }
    //return ("~minAndRes~"); // actually, key is found if (max == min/*always*/ && min < line.length && line[min] == x)
  }";

  // ////////////////////////////////////////////////////////////////////////// //
  // punch a hole, patch a hole
  // mode: "punch", "patch"
  //FIXME: overflows
  void doPunchPatch(string mode) (int x, int y, int w=1, int h=1) {
    static assert(mode == "punch" || mode == "patch", "Region: invalid mode: "~mode);
    static if (mode == "punch") {
      if (simple && !simpleSolid) return;
    } else {
      if (simple && simpleSolid) return;
    }
    if (w < 1 || h < 1) return;
    if (x >= rwdt || y >= rhgt) return;
    //TODO: overflow check
    if (x < 0) {
      if (x+w <= 0) return;
      w += x;
      x = 0;
    }
    if (y < 0) {
      if (y+h <= 0) return;
      h += y;
      y = 0;
    }
    int x1 = x+w-1;
    if (x1 >= rwdt) x1 = rwdt-1;
    debug assert(x <= x1);
    int y1 = y+h-1;
    if (y1 >= rhgt) y1 = rhgt-1;
    debug assert(y <= y1);
    foreach (int cy; y..y1+1) doPunchPatchLine!mode(cy, x, x1);
  }


  // ////////////////////////////////////////////////////////////////////////// //
  void makeRoom (usize ofs, ssize count) nothrow @trusted {
    import core.stdc.string : memmove;
    debug assert(ofs <= data.length);
    if (count > 0) {
      // make room
      // `assumeSafeAppend` was already called in caller
      //data.assumeSafeAppend.length += count;
      data.length += count;
      if (ofs+count < data.length) memmove(data.ptr+ofs+count, data.ptr+ofs, SpanType.sizeof*(data.length-ofs-count));
    } else if (count < 0) {
      // remove data
      count = -count;
      debug assert(ofs+count <= data.length);
      if (ofs+count == data.length) {
        data.length = ofs;
      } else {
        immutable auto left = data.length-ofs-count;
        memmove(data.ptr+ofs, data.ptr+ofs+count, SpanType.sizeof*(data.length-ofs-count));
        data.length -= count;
      }
      //data.assumeSafeAppend; // in case we will want to grow later
    }
  }

  // replace span data at plofs with another data from spofs, return # of bytes added (or removed, if negative)
  ssize replaceSpanData (usize plofs, usize spofs) nothrow @trusted {
    //import core.stdc.string : memcpy;
    debug assert(spofs < data.length && spofs+data[spofs] == data.length);
    debug assert(plofs <= spofs && plofs+data[plofs] <= spofs);
    if (plofs == spofs) return 0; // nothing to do; just in case
    auto oldlen = data[plofs];
    auto newlen = data[spofs];
    // same length?
    ssize ins = cast(ssize)newlen-cast(ssize)oldlen;
    if (ins) {
      makeRoom(plofs, ins);
      spofs += ins;
    }
    if (newlen > 0) data[plofs..plofs+newlen] = data[spofs..spofs+newlen]; //memcpy(data.ptr+plofs, data.ptr+spofs, SpanType.sizeof*newlen);
    return ins;
  }

  // insert span data from spofs at plofs
  void insertSpanData (usize plofs, usize spofs) nothrow @trusted {
    //import core.stdc.string : memcpy;
    debug assert(spofs < data.length && spofs+data[spofs] == data.length);
    debug assert(plofs <= spofs);
    if (plofs == spofs) return; // nothing to do; just in case
    auto newlen = data[spofs];
    makeRoom(plofs, newlen);
    spofs += newlen;
    data[plofs..plofs+newlen] = data[spofs..spofs+newlen];
    //memcpy(data.ptr+plofs, data.ptr+spofs, SpanType.sizeof*newlen);
  }

  bool isEqualLines (int y0, int y1) nothrow @trusted @nogc {
    import core.stdc.string : memcmp;
    if (y0 < 0 || y1 < 0 || y0 >= rhgt || y1 >= rhgt) return false;
    auto ofs0 = lineofs[y0];
    auto ofs1 = lineofs[y1];
    if (data[ofs0] != data[ofs1]) return false;
    return (memcmp(data.ptr+ofs0, data.ptr+ofs1, SpanType.sizeof*data[ofs0]) == 0);
  }

  // all args must be valid
  void doPunchPatchLine(string mode) (int y, int x0, int x1) {
    static if (mode == "patch") {
      if (simple && simpleSolid) return; // no need to patch completely solid region
    } else {
      if (simple && !simpleSolid) return; // no need to patch completely empty region
    }

    // check if we really have to do anything here
    static if (mode == "patch") {
      if (spanState(y, x0, x1) == State.Solid) return;
      enum psmode = true;
    } else {
      if (spanState(y, x0, x1) == State.Empty) return;
      enum psmode = false;
    }

    // bad luck, build new line
    if (simple) {
      // build complex region data
      if (lineofs is null) {
        lineofs.length = rhgt; // allocate and clear
      } else {
        if (lineofs.length < rhgt) lineofs.assumeSafeAppend;
        lineofs.length = rhgt;
        lineofs[] = 0; // clear
      }
      data.length = 0;
      if (simpleSolid) {
        data.assumeSafeAppend ~= 2; // length
      } else {
        data.assumeSafeAppend ~= 3; // length
        data ~= 0; // dummy solid
      }
      data ~= cast(SpanType)rwdt; // the only span
      simple = false;
    }

    auto lofs = lineofs[y]; // current line offset
    int lsize = data[lofs]; // current line size
    auto tmppos = cast(uint)data.length; // starting position of the new line data
    patchSpan!psmode(lofs+1, x0, x1);
    int newsize = data[tmppos]; // size of the new line

    // was this line first in slab?
    auto prevofs = (y > 0 ? lineofs[y-1] : -1);
    auto nextofs = (y+1 < rhgt ? lineofs[y+1] : -2);

    // place new line data, breaking span if necessary
    if (prevofs != lofs && nextofs != lofs) {
      // we were a slab on our own?
      // replace line
      auto delta = replaceSpanData(lofs, tmppos);
      tmppos += delta;
      if (delta) foreach (ref ofs; lineofs[y+1..$]) ofs += delta;
    } else if (prevofs != lofs && nextofs == lofs) {
      // we were a slab start
      // insert at lofs
      insertSpanData(lofs, tmppos);
      tmppos += newsize;
      foreach (ref ofs; lineofs[y+1..$]) ofs += newsize;
    } else if (prevofs == lofs && nextofs != lofs) {
      // we were a slab end
      // insert after lofs
      lofs += lsize;
      insertSpanData(lofs, tmppos);
      tmppos += newsize;
      lineofs[y] = lofs;
      foreach (ref ofs; lineofs[y+1..$]) ofs += newsize;
    } else {
      //import core.stdc.string : memcpy;
      // we were a slab brick
      debug assert(prevofs == lofs && nextofs == lofs);
      // the most complex case
      // insert us after lofs, insert slab start after us, fix slab and offsets
      // insert us
      lofs += lsize;
      insertSpanData(lofs, tmppos);
      tmppos += newsize;
      lineofs[y] = lofs;
      // insert old slab start
      lofs += newsize;
      lsize = data[prevofs];
      makeRoom(lofs, lsize);
      //memcpy(data.ptr+lofs, data.ptr+prevofs, SpanType.sizeof*lsize);
      data[lofs..lofs+lsize] = data[prevofs..prevofs+lsize];
      // fix current slab
      int ny = y+1;
      while (ny < rhgt && lineofs[ny] == prevofs) lineofs[ny++] = lofs;
      // fix offsets
      newsize += lsize; // simple optimization
      while (ny < rhgt) lineofs[ny++] += newsize;
      newsize -= lsize;
    }

    // remove extra data
    lofs = lineofs[$-1];
    data.length = lofs+data[lofs];

    // now check if we can join slabs
    // of course, this is somewhat wasteful, but if we'll combine this
    // check with previous code, the whole thing will explode to an
    // unmaintainable mess; anyway, we aren't on ZX Spectrum
    {
      bool upequ = isEqualLines(y-1, y);
      bool dnequ = isEqualLines(y+1, y);
      if (upequ || dnequ) {
        data.assumeSafeAppend; // we have to call it after shrinking
        lofs = lineofs[y];
        debug assert(data[lofs] == newsize);
        makeRoom(lofs, -newsize); // drop us
        if (upequ && dnequ) {
          // join prev and next slabs by removing two lines...
          auto pofs = lineofs[y-1];
          makeRoom(lofs, -newsize); // drop next line
          newsize *= 2;
          // and fixing offsets
          lineofs[y++] = pofs;
          auto sofs = lineofs[y];
          while (y < rhgt && lineofs[y] == sofs) lineofs[y++] = pofs;
        } else if (upequ) {
          // join prev slab
          lineofs[y] = lineofs[y-1];
          ++y;
        } else if (dnequ) {
          // lead next slab
          auto sofs = lineofs[++y];
          while (y < rhgt && lineofs[y] == sofs) lineofs[y++] = lofs;
        }
        // fix offsets
        foreach (ref ofs; lineofs[y..$]) ofs -= newsize;
      }
    }

    // check if we have a fully solid or fully empty region now
    static if (mode == "patch") {
      if (data.length != 2 || data[0] != 2 || data[1] != rwdt) return;
    } else {
      if (data.length != 3 || data[0] != 3 || data[1] != 0 || data[2] != rwdt) return;
    }
    foreach (immutable ofs; lineofs[1..$]) if (ofs != 0) return;

    simple = true;
    static if (mode == "patch") simpleSolid = true; else simpleSolid = false;
    lineofs.length = 0; // we may need it later, so keep it
  }

  // ////////////////////////////////////////////////////////////////////////// //
  // all args must be valid
  // [x0..x1]
  // destSolid: `true` to patch, `false` to cut
  // this will build a new valid line data, starting from data.length
  // (i.e. this line data will include length as first element)
  void patchSpan(bool destSolid) (uint a, int x0, int x1) {
    /*
    if (rwdt < 1) return;
    if (x1 < 0 || x0 >= rwdt || x1 < x0) return;
    if (x0 < 0) x0 = 0;
    if (x1 >= rwdt) x1 = rwdt-1;
    */
    debug assert(x0 <= x1);

    //int a = 0; // address in data
    int sx = 0, ex; // current span coords [sx..ex]
    bool solid = true; // current span type

    // load first span
    if (data[a] == 0) {
      // first span is empty
      solid = false;
      ++a;
    }
    debug assert(data[a] > 0);
    ex = data[a++]-1;
    debug assert(ex >= sx);

    // note that after `assumeSafeAppend` we can increase length without further `assumeSafeAppend` calls
    data.assumeSafeAppend ~= 0; // reserved for line length
    auto dnlen = data.length; // to avoid `.length -= 1`, as it require another `assumeSafeAppend`
    immutable sp0pos = dnlen;

    // the only function that does `~=`
    void putN() (int n) nothrow @safe {
      //DMD sux, it can't inline this
      //static if (__VERSION__ > 2067) pragma(inline, true);
      debug assert(n >= 0 && n <= SpanType.max);
      if (dnlen == data.length) data ~= cast(SpanType)n; else data[dnlen] = cast(SpanType)n;
      ++dnlen;
    }

    // now process spans
    for (;;) {
      if (x1 < 0 || x0 > ex) {
        // nothing to do, or current span is unaffected
       put_and_go_to_next_span:
        debug assert(sx <= ex);
        debug assert(ex < rwdt);
        // if this is first empty span, put zero-width soild first
        if (!solid && dnlen == sp0pos) putN(0);
        putN(ex+1); // put current span
        if (ex == rwdt-1) break; // no more spans
        sx = ex+1;
        ex = data[a++]-1;
        debug assert(ex < rwdt);
        debug assert(sx <= ex);
        solid = !solid;
        continue;
      }
      if (solid == destSolid) {
        // at destSolid span
        if (x1 <= ex) {
          // completely in current span
          x1 = -1; // no more checks
          goto put_and_go_to_next_span;
        } else {
          // partially in current span
          x0 = ex+1; // skip current span
          goto put_and_go_to_next_span;
        }
      } else {
        // at !destSolid span
        if (x0 == sx) {
          // empty space starts at current span start
          if (x1 >= ex) {
            // covers the whole current span
            if (x1 > ex) x0 = ex+1; else x1 = -1; // skip current span
            // drop next span (it's the same type as previous saved span, and we dropped span inbetween, so let's merge)
            int nextex = (ex < rwdt-1 ? data[a++]-1 : rwdt-1); // next span is consumed
            // previous stored span is destSolid (if any), drop it, it will be replaced with combined one
            if (dnlen > sp0pos) {
              dnlen -= 1;
            } else {
              // this is first span, nothing to drop
              debug assert(sx == 0);
            }
            sx = (dnlen > sp0pos ? data[dnlen-1] : 0);
            solid = destSolid; // previous span is destSolid
            ex = nextex;
            continue;
          } else {
            // cut left part: [sx..x1]
            if (dnlen == sp0pos) {
              // this is first span, and if we need first empty span, insert zero-width solid span
              debug assert(sx == 0);
              // put destSolid part
              static if (!destSolid) putN(0);
              putN(x1+1);
            } else {
              data[dnlen-1] = cast(SpanType)(x1+1); // extend previous span to x1
            }
            sx = x1+1; // current span starts here
            x1 = -1; // no more checks
            goto put_and_go_to_next_span;
          }
        } else {
          // empty space starts somewhere inside the current span
          if (x1 >= ex) {
            // covers whole right part of current span
            static if (destSolid) { if (dnlen == sp0pos) putN(0); } // put zero-width solid span
            putN(x0); // put current span
            // go to next span
            if (ex != rwdt-1) ex = (ex < rwdt-1 ? data[a++]-1 : rwdt-1);
            sx = x0; // fix span start
            debug assert(sx <= ex);
            solid = destSolid; // we are destSolid
            continue;
          } else {
            // cut hole in current span
            static if (destSolid) { if (dnlen == sp0pos) putN(0); } // put zero-width solid span
            putN(x0); // put left part of current span
            putN(x1+1); // put hole
            // process right part of current span
            sx = x1+1;
            x1 = -1;
            goto put_and_go_to_next_span;
          }
        }
      }
    }
    debug assert(ex == rwdt-1);
    debug assert(dnlen > 0 && data[dnlen-1] == rwdt); // check end-of-span flag

    // check if we covered the whole span
    debug {
      sx = 0;
      usize pp = sp0pos;
      if (data[pp] == 0) ++pp;
      while (sx != rwdt) {
        // check if span coords are increasing
        if (data[pp] == 0 || data[pp] <= sx) {
          //{ import std.stdio; foreach (immutable idx; sp0pos..data.length) writeln(idx-sp0pos, ": ", data[idx]); }
          debug assert(data[pp+1] != 0);
        }
        sx = data[pp++];
      }
      import std.conv : to;
      debug assert(sx == rwdt, "sx="~to!string(sx)~"; rwdt="~to!string(rwdt));
    }

    // fix line length
    if (data.length-sp0pos > SpanType.max-1) assert(0, "region internal error: span data is too long");
    data[sp0pos-1] = cast(SpanType)(data.length-sp0pos+1);

    // remove unused data, if any
    // this probably will never happen, but it's better to play safe %-)
    if (dnlen < data.length) {
      data.length = dnlen;
      data.assumeSafeAppend; // caller must be sure that no unnecessary realloc will happen
    }
  }

private:
  alias SpanType = ushort;

  int rwdt, rhgt; // width and height
  bool simple = true; // is this region a simple one (i.e. rectangular, without holes)?
  bool simpleSolid = true; // if it is simple, is it solid or empty?
  //WARNING! the following arrays should NEVER be shared!
  uint[] lineofs; // line data offset in data[]
  SpanType[] data;
    // data format for each line:
    //   len, data[len-1]
    // line items: list of increasing x coords; each coord marks start of next region
    // all even regions are solid, i.e.
    //   0..line[0]-1: solid region
    //   line[0]..line[1]-1: transparent (empty) region
    //   etc.
    // note that line[$-1] is always rwdt; it's used as sentinel too
    // `line[0] == 0` means that first span is transparent (empty)
    // (i.e. region starts from transparent span)
}
