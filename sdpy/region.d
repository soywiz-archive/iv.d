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
// regions are copy-on-write shared, yay
struct Region {
  alias SpanType = ushort; // you probably will never need this, but...

  @property pure const nothrow @safe @nogc {
    int width () { static if (__VERSION__ > 2067) pragma(inline, true); return (rdatap ? rdata.rwdt : 0); }
    int height () { static if (__VERSION__ > 2067) pragma(inline, true); return (rdatap ? rdata.rhgt : 0); }
    bool solid () { static if (__VERSION__ > 2067) pragma(inline, true); return (rdatap ? rdata.simple && rdata.rwdt > 0 && rdata.rhgt > 0 && rdata.simpleSolid : false); }
    bool empty () { static if (__VERSION__ > 2067) pragma(inline, true); return (rdatap ? rdata.rwdt < 1 || rdata.rhgt < 1 || (rdata.simple && !rdata.simpleSolid) : true); }
  }

  @property uint[] getData () const nothrow @safe {
    uint[] res;
    if (rdata.simple) {
      res ~= 1|(rdata.simpleSolid ? 2 : 0);
    } else {
      res ~= 0;
    }
    res[0] |= cast(int)(SpanType.sizeof<<4);
    res ~= rdata.rwdt;
    res ~= rdata.rhgt;
    if (!rdata.simple) {
      res ~= rdata.lineofs;
      foreach (SpanType d; rdata.data) res ~= d;
    }
    return res;
  }

  void setData (const(int)[] data) nothrow @safe {
    cow!false();
    if (data.length < 3 || (data[0]>>4) != SpanType.sizeof) assert(0, "invalid region data");
    rdata.rwdt = data[1];
    rdata.rhgt = data[2];
    rdata.simple = ((data[0]&0x01) != 0);
    rdata.lineofs = null;
    rdata.data = null;
    if (rdata.simple) {
      rdata.simpleSolid = ((data[0]&0x02) != 0);
    } else {
      foreach (int d; data[3..3+rdata.rhgt]) rdata.lineofs ~= d;
      foreach (int d; data[3+rdata.rhgt..$]) rdata.data ~= cast(SpanType)d;
    }
  }

  // this creates solid region
  this (int awidth, int aheight, bool solid=true) nothrow @safe @nogc { setSize(awidth, aheight, solid); }
  ~this () nothrow @safe @nogc { decRC(); } // release this region data
  this (this) nothrow @safe @nogc { if (rdatap) ++rdata.rc; } // share this region data

  void setSize (int awidth, int aheight, bool solid=true) nothrow @safe @nogc {
    if (awidth <= 0 || aheight <= 0) awidth = aheight = 0;
    if (awidth > SpanType.max-1 || aheight > SpanType.max-1) assert(0, "Region internal error: region dimensions are too big");
    cow!false();
    rdata.rwdt = awidth;
    rdata.rhgt = aheight;
    rdata.simpleSolid = solid;
    rdata.lineofs = null;
    rdata.data = null;
  }

  // is given point visible?
  bool visible (int x, int y) const pure nothrow @safe @nogc {
    // easiest cases
    if (!rdatap) return false;
    if (rdata.rwdt < 1 || rdata.rhgt < 1) return false;
    if (x < 0 || y < 0 || x >= rdata.rwdt || y >= rdata.rhgt) return false;
    if (rdata.simple) return true; // ok, easy case here
    // now the hard one
    immutable ldofs = rdata.lineofs[y];
    immutable len = rdata.data[ldofs];
    debug assert(len > 1);
    auto line = rdata.data[ldofs+1..ldofs+len];
    int idx = void; // will be initied in mixin
    mixin(FindSpanMixinStr!"idx");
    debug assert(idx < line.length); // too far (the thing that should not be)
    return ((idx+(line[idx] == x))%2 == 0);
  }

  // punch a hole
  void punch (int x, int y, int w=1, int h=1) nothrow @trusted { doPunchPatch!"punch"(x, y, w, h); }

  // patch a hole
  void patch (int x, int y, int w=1, int h=1) nothrow @trusted { doPunchPatch!"patch"(x, y, w, h); }

  // ////////////////////////////////////////////////////////////////////////// //
  enum State { Mixed = -1, Empty, Solid } //WARNING! don't change the order!

  // return span state %-)
  State spanState (int y, int x0, int x1) const pure nothrow @safe @nogc {
    if (rdata is null) return State.Empty;
    if (y < 0 || y >= rdata.rhgt || x1 < 0 || x0 >= rdata.rwdt || x1 < x0) return State.Empty;
    if (rdata.simple) {
      // if our span is not fully inside, it can be either Empty or Mixed
      if (rdata.simpleSolid) {
        return (x0 >= 0 && x1 < rdata.rwdt ? State.Solid : State.Mixed);
      } else {
        return State.Empty;
      }
    }
    immutable ldofs = rdata.lineofs[y];
    immutable len = rdata.data[ldofs];
    debug assert(len > 1);
    auto line = rdata.data[ldofs+1..ldofs+len];
    int idx = void; // will be initied in mixin
    immutable x = (x0 >= 0 ? x0 : 0);
    mixin(FindSpanMixinStr!"idx");
    debug assert(idx < line.length); // too far (the thing that should not be)
    // move to "real" span
    if (line[idx] == x) ++idx;
    // now, sx is line[idx-1], ex is line[idx]
    if (x1 >= (idx < line.length ? line[idx] : rdata.rwdt)) return State.Mixed;
    idx = (idx^1)&1; // we are interested only in last bit, and we converted it to State here
    // if our span is not fully inside, it can be either Empty or Mixed
    if (idx == State.Solid && x0 < 0) return State.Mixed;
    return cast(State)idx;
  }

  // call delegate for each solid or empty span
  // multiple declarations will allow us to use this in `@nogc` and `nothrow` contexts
  void spans(bool solids=true) (int y, int x0, int x1, scope void delegate (int x0, int x1) nothrow @nogc dg) const nothrow @nogc { spansEnumerator!solids(y, 0, x0, x1, dg); }
  void spans(bool solids=true) (int y, int x0, int x1, scope void delegate (int x0, int x1) @nogc dg) const @nogc { spansEnumerator!solids(y, 0, x0, x1, dg); }
  void spans(bool solids=true) (int y, int x0, int x1, scope void delegate (int x0, int x1) dg) const { spansEnumerator!solids(y, 0, x0, x1, dg); }

  // `ofsx` will be automatically subtracted from `x0` and `x1` args, and added to `x0` and `x1` delegate args
  void spans(bool solids=true) (int y, int ofsx, int x0, int x1, scope void delegate (int x0, int x1) nothrow @nogc dg) const nothrow @nogc { spansEnumerator!solids(y, ofsx, x0, x1, dg); }
  void spans(bool solids=true) (int y, int ofsx, int x0, int x1, scope void delegate (int x0, int x1) @nogc dg) const @nogc { spansEnumerator!solids(y, ofsx, x0, x1, dg); }
  void spans(bool solids=true) (int y, int ofsx, int x0, int x1, scope void delegate (int x0, int x1) dg) const { spansEnumerator!solids(y, ofsx, x0, x1, dg); }

  static struct XPair { int x0, x1; }

  auto spanRange(bool solids=true) (int y, int x0, int x1) nothrow @safe @nogc { return spanRange!solids(y, 0, x0, x1); }
  auto spanRange(bool solids=true) (int y, int ofsx, int x0, int x1) nothrow @safe @nogc {
    static struct SpanRange(bool solids) {
      int ofsx, x0, x1, rwdt, idx;
      ubyte eosNM; // empty(bit0), nomore(bit1) ;-)
      XPair fpair; // front
      const(SpanType)[] line;

    nothrow @safe @nogc: @trusted:
      this (ref Region reg, int y, int aofsx, int ax0, int ax1) {
        ofsx = aofsx;
        x0 = ax0;
        x1 = ax1;
        if (x0 > x1) { eosNM = 0x01; return; }
        if (reg.rdata is null) {
          static if (!solids) {
            fpair.x0 = x0;
            fpair.x1 = x1;
            eosNM = 0x02;
          } else {
            eosNM = 0x01;
          }
          return;
        }
        rwdt = reg.rdata.rwdt;
        x0 -= ofsx;
        x1 -= ofsx;
        if (y < 0 || y >= reg.rdata.rhgt || x1 < 0 || x0 >= rwdt || x1 < x0) {
          static if (!solids) {
            fpair.x0 = x0+ofsx;
            fpair.x1 = x1+ofsx;
            eosNM = 0x02;
          } else {
            eosNM = 0x01;
          }
          return;
        }
        if (reg.rdata.simple) {
          if (reg.rdata.simpleSolid) {
            static if (solids) {
              if (x0 < 0) x0 = 0;
              if (x1 >= rwdt) x1 = rwdt-1;
              if (x0 <= x1) {
                fpair.x0 = x0+ofsx;
                fpair.x1 = x1+ofsx;
                eosNM = 0x02;
              } else {
                eosNM = 0x01;
              }
            } else {
              if (x0 < 0) {
                fpair.x0 = x0+ofsx;
                fpair.x1 = -1+ofsx;
                eosNM = (x1 < rwdt ? 0x02 : 0x04);
              } else {
                if (x1 >= rwdt) {
                  fpair.x0 = rwdt+ofsx;
                  fpair.x1 = x1+ofsx;
                  eosNM = 0x02;
                } else {
                  eosNM = 0x01;
                }
              }
            }
          } else {
            static if (!solids) {
              fpair.x0 = x0+ofsx;
              fpair.x1 = x1+ofsx;
              eosNM = 0x02;
            } else {
              eosNM = 0x01;
            }
          }
          return;
        }
        // edge cases are checked
        immutable ldofs = reg.rdata.lineofs[y];
        immutable len = reg.rdata.data[ldofs];
        debug assert(len > 1);
        line = reg.rdata.data[ldofs+1..ldofs+len];
        // beyond left border? move to first solid span
        bool hasOne = false;
        if (x0 < 0) {
          int ex = (line[0] == 0 ? line[1]-1 : -1);
          // is first span empty too?
          if (ex >= x1) {
            static if (!solids) {
              fpair.x0 = x0+ofsx;
              fpair.x1 = x1+ofsx;
              eosNM = 0x02;
            } else {
              eosNM = 0x01;
            }
            return;
          }
          static if (!solids) {
            fpair.x0 = x0+ofsx;
            fpair.x1 = ex+ofsx;
            hasOne = true;
            if (x0 == -9) {
              //import iv.writer; writeln("*");
            }
          }
          x0 = ex+1;
        }
        static if (solids) { if (x1 >= rwdt) x1 = rwdt-1; }
        //int idx = void; // will be initied in mixin
        alias x = x0; // for mixin
        mixin(FindSpanMixinStr!"idx");
        debug assert(idx < line.length); // too far (the thing that should not be)
        // move to "real" span, so sx is line[idx-1], ex+1 is line[idx]
        if (line[idx] == x) ++idx;
        if (!hasOne) popFront();
      }

      @property auto save () pure {
        SpanRange!solids res;
        res.ofsx = ofsx;
        res.x0 = x0;
        res.x1 = x1;
        res.rwdt = rwdt;
        res.idx = idx;
        res.eosNM = eosNM;
        res.fpair = fpair;
        res.line = line;
        return res;
      }

      @property bool empty () const pure { return ((eosNM&0x01) != 0); }
      @property XPair front () const pure { return XPair(fpair.x0, fpair.x1); }

      void popFront () {
        if (eosNM&0x02) eosNM = 0x01;
        if (eosNM&0x01) return;
        // edge case
        if (eosNM&0x04) {
          if (x1 >= rwdt) {
            static if (!solids) {
              fpair.x0 = rwdt+ofsx;
              fpair.x1 = x1+ofsx;
              eosNM = 0x02;
            } else {
              eosNM = 0x01;
            }
          } else {
            eosNM = 0x01;
          }
          return;
        }
        bool hasOne = false;
        // process spans
        while (x0 <= x1) {
          int ex = line[idx]-1;
          int cex = (ex < x1 ? ex : x1); // clipped ex
          // emit part from x0 to ex if necessary
          static if (solids) {
            // current span is solid?
            if (idx%2 == 0) {
              fpair.x0 = x0+ofsx;
              fpair.x1 = cex+ofsx;
              hasOne = true;
            }
          } else {
            // current span is empty?
            if (idx%2 == 1) {
              fpair.x0 = x0+ofsx;
              fpair.x1 = (ex < rwdt-1 ? cex : x1)+ofsx;
              hasOne = true;
              if (ex == rwdt-1) { eosNM = 0x02; return; }
            } else {
              if (ex == rwdt-1) { x0 = rwdt; break; }
            }
          }
          x0 = ex+1;
          ++idx;
          if (hasOne) return;
        }
        if (hasOne) return;
        static if (!solids) {
          if (x0 <= x1) {
            fpair.x0 = x0+ofsx;
            fpair.x1 = x1+ofsx;
            eosNM = 0x02;
            return;
          }
        }
        eosNM = 0x01;
      }
    }

    return SpanRange!solids(this, y, ofsx, x0, x1);
  }

  //TODO: slab enumerator
private:
  // ////////////////////////////////////////////////////////////////////////// //
  void spansEnumerator(bool solids, T) (int y, int ofsx, int x0, int x1, scope /*void delegate (int x0, int x1)*/T dg) const {
    if (x0 > x1) return;
    assert(dg !is null);
    if (rdata is null) {
      static if (!solids) dg(x0, x1);
      return;
    }
    x0 -= ofsx;
    x1 -= ofsx;
    if (y < 0 || y >= rdata.rhgt || x1 < 0 || x0 >= rdata.rwdt || x1 < x0) {
      static if (!solids) dg(x0+ofsx, x1+ofsx);
      return;
    }
    if (rdata.simple) {
      if (rdata.simpleSolid) {
        static if (solids) {
          if (x0 < 0) x0 = 0;
          if (x1 >= rdata.rwdt) x1 = rdata.rwdt-1;
          if (x0 <= x1) dg(x0+ofsx, x1+ofsx);
        } else {
          if (x0 < 0) dg(x0+ofsx, -1+ofsx);
          if (x1 >= rdata.rwdt) dg(rdata.rwdt+ofsx, x1+ofsx);
        }
      } else {
        static if (!solids) dg(x0+ofsx, x1+ofsx);
      }
      return;
    }
    immutable ldofs = rdata.lineofs[y];
    immutable len = rdata.data[ldofs];
    debug assert(len > 1);
    auto line = rdata.data[ldofs+1..ldofs+len];
    // beyond left border? move to first solid span
    if (x0 < 0) {
      int ex = (rdata.data[ldofs+1] == 0 ? rdata.data[ldofs+2]-1 : -1);
      // is first span empty too?
      if (ex >= x1) { static if (!solids) dg(x0+ofsx, x1+ofsx); return; }
      static if (!solids) dg(x0+ofsx, ex+ofsx);
      x0 = ex+1;
    }
    static if (solids) { if (x1 >= rdata.rwdt) x1 = rdata.rwdt-1; }
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
        if (idx%2 == 0) dg(x0+ofsx, cex+ofsx);
      } else {
        // current span is empty?
        if (idx%2 == 1) {
          dg(x0+ofsx, (ex < rdata.rwdt-1 ? cex : x1)+ofsx);
          if (ex == rdata.rwdt-1) return;
        } else {
          if (ex == rdata.rwdt-1) { x0 = rdata.rwdt; break; }
        }
      }
      x0 = ex+1;
      ++idx;
      //static if (!solids) { if (x0 == rdata.rwdt) break; }
    }
    static if (!solids) { if (x0 <= x1) dg(x0+ofsx, x1+ofsx); }
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
  void doPunchPatch(string mode) (int x, int y, int w=1, int h=1) nothrow @trusted {
    static assert(mode == "punch" || mode == "patch", "Region: invalid mode: "~mode);
    if (rdata is null) return;
    static if (mode == "punch") {
      if (empty) return;
    } else {
      if (solid) return;
    }
    if (w < 1 || h < 1) return;
    if (x >= rdata.rwdt || y >= rdata.rhgt) return;
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
    if (x1 >= rdata.rwdt) x1 = rdata.rwdt-1;
    debug assert(x <= x1);
    int y1 = y+h-1;
    if (y1 >= rdata.rhgt) y1 = rdata.rhgt-1;
    debug assert(y <= y1);
    foreach (int cy; y..y1+1) doPunchPatchLine!mode(cy, x, x1);
  }


  // ////////////////////////////////////////////////////////////////////////// //
  void makeRoom (usize ofs, ssize count) nothrow @trusted {
    import core.stdc.string : memmove;
    debug assert(ofs <= rdata.data.length);
    if (count > 0) {
      // make room
      // `assumeSafeAppend` was already called in caller
      //rdata.data.assumeSafeAppend.length += count;
      rdata.data.length += count;
      if (ofs+count < rdata.data.length) memmove(rdata.data.ptr+ofs+count, rdata.data.ptr+ofs, SpanType.sizeof*(rdata.data.length-ofs-count));
    } else if (count < 0) {
      // remove rdata.data
      count = -count;
      debug assert(ofs+count <= rdata.data.length);
      if (ofs+count == rdata.data.length) {
        rdata.data.length = ofs;
      } else {
        immutable auto left = rdata.data.length-ofs-count;
        memmove(rdata.data.ptr+ofs, rdata.data.ptr+ofs+count, SpanType.sizeof*(rdata.data.length-ofs-count));
        rdata.data.length -= count;
      }
      //rdata.data.assumeSafeAppend; // in case we will want to grow later
    }
  }

  // replace span data at plofs with another data from spofs, return # of bytes added (or removed, if negative)
  ssize replaceSpanData (usize plofs, usize spofs) nothrow @trusted {
    //import core.stdc.string : memcpy;
    debug assert(spofs < rdata.data.length && spofs+rdata.data[spofs] == rdata.data.length);
    debug assert(plofs <= spofs && plofs+rdata.data[plofs] <= spofs);
    if (plofs == spofs) return 0; // nothing to do; just in case
    auto oldlen = rdata.data[plofs];
    auto newlen = rdata.data[spofs];
    // same length?
    ssize ins = cast(ssize)newlen-cast(ssize)oldlen;
    if (ins) {
      makeRoom(plofs, ins);
      spofs += ins;
    }
    if (newlen > 0) rdata.data[plofs..plofs+newlen] = rdata.data[spofs..spofs+newlen]; //memcpy(rdata.data.ptr+plofs, rdata.data.ptr+spofs, SpanType.sizeof*newlen);
    return ins;
  }

  // insert span data from spofs at plofs
  void insertSpanData (usize plofs, usize spofs) nothrow @trusted {
    //import core.stdc.string : memcpy;
    debug assert(spofs < rdata.data.length && spofs+rdata.data[spofs] == rdata.data.length);
    debug assert(plofs <= spofs);
    if (plofs == spofs) return; // nothing to do; just in case
    auto newlen = rdata.data[spofs];
    makeRoom(plofs, newlen);
    spofs += newlen;
    rdata.data[plofs..plofs+newlen] = rdata.data[spofs..spofs+newlen];
    //memcpy(rdata.data.ptr+plofs, rdata.data.ptr+spofs, SpanType.sizeof*newlen);
  }

  bool isEqualLines (int y0, int y1) nothrow @trusted @nogc {
    import core.stdc.string : memcmp;
    if (y0 < 0 || y1 < 0 || y0 >= rdata.rhgt || y1 >= rdata.rhgt) return false;
    auto ofs0 = rdata.lineofs[y0];
    auto ofs1 = rdata.lineofs[y1];
    if (rdata.data[ofs0] != rdata.data[ofs1]) return false;
    return (memcmp(rdata.data.ptr+ofs0, rdata.data.ptr+ofs1, SpanType.sizeof*rdata.data[ofs0]) == 0);
  }

  // all args must be valid
  void doPunchPatchLine(string mode) (int y, int x0, int x1) nothrow @trusted {
    static if (mode == "patch") {
      if (rdata.simple && rdata.simpleSolid) return; // no need to patch completely solid region
    } else {
      if (rdata.simple && !rdata.simpleSolid) return; // no need to patch completely empty region
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
    cow!true();
    if (rdata.simple) {
      // build complex region rdata.data
      if (rdata.lineofs is null) {
        rdata.lineofs.length = rdata.rhgt; // allocate and clear
      } else {
        if (rdata.lineofs.length < rdata.rhgt) rdata.lineofs.assumeSafeAppend;
        rdata.lineofs.length = rdata.rhgt;
        rdata.lineofs[] = 0; // clear
      }
      rdata.data.length = 0;
      if (rdata.simpleSolid) {
        rdata.data.assumeSafeAppend ~= 2; // length
      } else {
        rdata.data.assumeSafeAppend ~= 3; // length
        rdata.data ~= 0; // dummy solid
      }
      rdata.data ~= cast(SpanType)rdata.rwdt; // the only span
      rdata.simple = false;
    }

    auto lofs = rdata.lineofs[y]; // current line offset
    int lsize = rdata.data[lofs]; // current line size
    auto tmppos = cast(uint)rdata.data.length; // starting position of the new line data
    patchSpan!psmode(lofs+1, x0, x1);
    int newsize = rdata.data[tmppos]; // size of the new line

    // was this line first in slab?
    auto prevofs = (y > 0 ? rdata.lineofs[y-1] : -1);
    auto nextofs = (y+1 < rdata.rhgt ? rdata.lineofs[y+1] : -2);

    // place new line data, breaking span if necessary
    if (prevofs != lofs && nextofs != lofs) {
      // we were a slab on our own?
      // replace line
      auto delta = replaceSpanData(lofs, tmppos);
      tmppos += delta;
      if (delta) foreach (ref ofs; rdata.lineofs[y+1..$]) ofs += delta;
    } else if (prevofs != lofs && nextofs == lofs) {
      // we were a slab start
      // insert at lofs
      insertSpanData(lofs, tmppos);
      tmppos += newsize;
      foreach (ref ofs; rdata.lineofs[y+1..$]) ofs += newsize;
    } else if (prevofs == lofs && nextofs != lofs) {
      // we were a slab end
      // insert after lofs
      lofs += lsize;
      insertSpanData(lofs, tmppos);
      tmppos += newsize;
      rdata.lineofs[y] = lofs;
      foreach (ref ofs; rdata.lineofs[y+1..$]) ofs += newsize;
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
      rdata.lineofs[y] = lofs;
      // insert old slab start
      lofs += newsize;
      lsize = rdata.data[prevofs];
      makeRoom(lofs, lsize);
      //memcpy(rdata.data.ptr+lofs, rdata.data.ptr+prevofs, SpanType.sizeof*lsize);
      rdata.data[lofs..lofs+lsize] = rdata.data[prevofs..prevofs+lsize];
      // fix current slab
      int ny = y+1;
      while (ny < rdata.rhgt && rdata.lineofs[ny] == prevofs) rdata.lineofs[ny++] = lofs;
      // fix offsets
      newsize += lsize; // simple optimization
      while (ny < rdata.rhgt) rdata.lineofs[ny++] += newsize;
      newsize -= lsize;
    }

    // remove extra data
    lofs = rdata.lineofs[$-1];
    rdata.data.length = lofs+rdata.data[lofs];

    // now check if we can join slabs
    // of course, this is somewhat wasteful, but if we'll combine this
    // check with previous code, the whole thing will explode to an
    // unmaintainable mess; anyway, we aren't on ZX Spectrum
    {
      bool upequ = isEqualLines(y-1, y);
      bool dnequ = isEqualLines(y+1, y);
      if (upequ || dnequ) {
        rdata.data.assumeSafeAppend; // we have to call it after shrinking
        lofs = rdata.lineofs[y];
        debug assert(rdata.data[lofs] == newsize);
        makeRoom(lofs, -newsize); // drop us
        if (upequ && dnequ) {
          // join prev and next slabs by removing two lines...
          auto pofs = rdata.lineofs[y-1];
          makeRoom(lofs, -newsize); // drop next line
          newsize *= 2;
          // and fixing offsets
          rdata.lineofs[y++] = pofs;
          auto sofs = rdata.lineofs[y];
          while (y < rdata.rhgt && rdata.lineofs[y] == sofs) rdata.lineofs[y++] = pofs;
        } else if (upequ) {
          // join prev slab
          rdata.lineofs[y] = rdata.lineofs[y-1];
          ++y;
        } else if (dnequ) {
          // lead next slab
          auto sofs = rdata.lineofs[++y];
          while (y < rdata.rhgt && rdata.lineofs[y] == sofs) rdata.lineofs[y++] = lofs;
        }
        // fix offsets
        foreach (ref ofs; rdata.lineofs[y..$]) ofs -= newsize;
      }
    }

    // check if we have a fully solid or fully empty region now
    static if (mode == "patch") {
      if (rdata.data.length != 2 || rdata.data[0] != 2 || rdata.data[1] != rdata.rwdt) return;
    } else {
      if (rdata.data.length != 3 || rdata.data[0] != 3 || rdata.data[1] != 0 || rdata.data[2] != rdata.rwdt) return;
    }
    foreach (immutable ofs; rdata.lineofs[1..$]) if (ofs != 0) return;

    rdata.simple = true;
    static if (mode == "patch") rdata.simpleSolid = true; else rdata.simpleSolid = false;
    rdata.lineofs.length = 0; // we may need it later, so keep it
  }

  // ////////////////////////////////////////////////////////////////////////// //
  // all args must be valid
  // [x0..x1]
  // destSolid: `true` to patch, `false` to cut
  // this will build a new valid line data, starting from data.length
  // (i.e. this line data will include length as first element)
  void patchSpan(bool destSolid) (uint a, int x0, int x1) nothrow @trusted {
    /*
    if (rdata.rwdt < 1) return;
    if (x1 < 0 || x0 >= rdata.rwdt || x1 < x0) return;
    if (x0 < 0) x0 = 0;
    if (x1 >= rdata.rwdt) x1 = rdata.rwdt-1;
    */
    debug assert(x0 <= x1);

    //int a = 0; // address in data
    int sx = 0, ex; // current span coords [sx..ex]
    bool solid = true; // current span type

    // load first span
    if (rdata.data[a] == 0) {
      // first span is empty
      solid = false;
      ++a;
    }
    debug assert(rdata.data[a] > 0);
    ex = rdata.data[a++]-1;
    debug assert(ex >= sx);

    // note that after `assumeSafeAppend` we can increase length without further `assumeSafeAppend` calls
    rdata.data.assumeSafeAppend ~= 0; // reserved for line length
    auto dnlen = rdata.data.length; // to avoid `.length -= 1`, as it require another `assumeSafeAppend`
    immutable sp0pos = dnlen;

    // the only function that does `~=`
    void putN() (int n) nothrow @safe {
      //DMD sux, it can't inline this
      //static if (__VERSION__ > 2067) pragma(inline, true);
      debug assert(n >= 0 && n <= SpanType.max);
      if (dnlen == rdata.data.length) rdata.data ~= cast(SpanType)n; else rdata.data[dnlen] = cast(SpanType)n;
      ++dnlen;
    }

    // now process spans
    for (;;) {
      if (x1 < 0 || x0 > ex) {
        // nothing to do, or current span is unaffected
       put_and_go_to_next_span:
        debug assert(sx <= ex);
        debug assert(ex < rdata.rwdt);
        // if this is first empty span, put zero-width soild first
        if (!solid && dnlen == sp0pos) putN(0);
        putN(ex+1); // put current span
        if (ex == rdata.rwdt-1) break; // no more spans
        sx = ex+1;
        ex = rdata.data[a++]-1;
        debug assert(ex < rdata.rwdt);
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
            int nextex = (ex < rdata.rwdt-1 ? rdata.data[a++]-1 : rdata.rwdt-1); // next span is consumed
            // previous stored span is destSolid (if any), drop it, it will be replaced with combined one
            if (dnlen > sp0pos) {
              dnlen -= 1;
            } else {
              // this is first span, nothing to drop
              debug assert(sx == 0);
            }
            sx = (dnlen > sp0pos ? rdata.data[dnlen-1] : 0);
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
              rdata.data[dnlen-1] = cast(SpanType)(x1+1); // extend previous span to x1
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
            if (ex != rdata.rwdt-1) ex = (ex < rdata.rwdt-1 ? rdata.data[a++]-1 : rdata.rwdt-1);
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
    debug assert(ex == rdata.rwdt-1);
    debug assert(dnlen > 0 && rdata.data[dnlen-1] == rdata.rwdt); // check end-of-span flag

    // check if we covered the whole span
    debug {
      sx = 0;
      usize pp = sp0pos;
      if (rdata.data[pp] == 0) ++pp;
      while (sx != rdata.rwdt) {
        // check if span coords are increasing
        if (rdata.data[pp] == 0 || rdata.data[pp] <= sx) {
          //{ import std.stdio; foreach (immutable idx; sp0pos..rdata.data.length) writeln(idx-sp0pos, ": ", rdata.data[idx]); }
          debug assert(rdata.data[pp+1] != 0);
        }
        sx = rdata.data[pp++];
      }
      import std.conv : to;
      debug assert(sx == rdata.rwdt, "sx="~to!string(sx)~"; rwdt="~to!string(rdata.rwdt));
    }

    // fix line length
    if (rdata.data.length-sp0pos > SpanType.max-1) assert(0, "region internal error: span data is too long");
    rdata.data[sp0pos-1] = cast(SpanType)(rdata.data.length-sp0pos+1);

    // remove unused data, if any
    // this probably will never happen, but it's better to play safe %-)
    if (dnlen < rdata.data.length) {
      rdata.data.length = dnlen;
      rdata.data.assumeSafeAppend; // caller must be sure that no unnecessary realloc will happen
    }
  }

private:
  size_t rdatap = 0; // hide from GC

  @property inout(RData)* rdata () inout pure const nothrow @trusted @nogc { static if (__VERSION__ > 2067) pragma(inline, true); return cast(RData*)rdatap; }

  void decRC () nothrow @trusted @nogc {
    if (rdatap != 0) {
      if (--rdata.rc == 0) {
        import core.memory : GC;
        import core.stdc.stdlib : free;
        GC.removeRange(rdata);
        free(rdata);
      }
      rdatap = 0; // just in case
    }
  }

  // copy-on-write mechanics
  void cow(bool doCopyData) () nothrow @trusted {
    auto srcd = rdata;
    if (srcd is null || srcd.rc != 1) {
      import core.memory : GC;
      import core.stdc.stdlib : malloc, free;
      import core.stdc.string : memcpy;
      auto dstd = cast(RData*)malloc(RData.sizeof);
      if (dstd is null) assert(0, "Region: out of memory"); // this is unlikely, and hey, just crash
      // init with default values
      //*dstd = RData.init;
      static immutable RData initr = RData.init;
      memcpy(dstd, &initr, RData.sizeof);
      //(*dstd).__ctor();
      if (srcd !is null) {
        // copy
        dstd.rwdt = srcd.rwdt;
        dstd.rhgt = srcd.rhgt;
        dstd.simple = srcd.simple;
        dstd.simpleSolid = srcd.simpleSolid;
        dstd.lineofs = null;
        dstd.data = null;
        dstd.rc = 1;
        static if (doCopyData) {
          if (!dstd.simple) {
            // copy complex region
            if (srcd.lineofs.length) dstd.lineofs = srcd.lineofs.dup;
            if (srcd.data.length) dstd.data = srcd.data.dup;
          }
        }
        --srcd.rc;
        assert(srcd.rc > 0);
      }
      rdatap = cast(size_t)dstd;
      GC.addRange(rdata, RData.sizeof, typeid(RData));
    }
  }

  // region data
  // all data is here, so passing region struct around is painless
  static struct RData {
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
    int rc = 1; // refcount
  }
}


// ////////////////////////////////////////////////////////////////////////// //
version(sdpy_region_test) {
//static assert(0);
import iv.writer;


void dumpData (ref Region reg) {
  import iv.writer;
  if (reg.rdata.simple) { writeln("simple ", (reg.rdata.simpleSolid ? "solid" : "empty"), " region"); return; }
  foreach (immutable y, uint ofs; reg.rdata.lineofs) {
    if (y > 0 && reg.rdata.lineofs[y-1] == ofs) {
      writefln!"%5s:%3s: ditto"(ofs, y);
    } else {
      writef!"%5s:%3s: len="(ofs, y);
      write(reg.rdata.data[ofs]);
      auto end = ofs+reg.rdata.data[ofs];
      ++ofs;
      while (ofs < end) write("; ", reg.rdata.data[ofs++]);
      writeln;
    }
  }
}


void checkLineOffsets (ref Region reg) {
  if (reg.rdata.simple) return;
  foreach (immutable idx; 1..reg.rdata.lineofs.length) {
    if (reg.rdata.lineofs[idx-1] > reg.rdata.lineofs[idx]) assert(0, "invalid line offset data");
    // check for two equal, but unmerged lines
    if (reg.rdata.lineofs[idx-1] != reg.rdata.lineofs[idx]) {
      import core.stdc.string : memcmp;
      if (reg.rdata.data[reg.rdata.lineofs[idx-1]] == reg.rdata.data[reg.rdata.lineofs[idx]] &&
          memcmp(reg.rdata.data.ptr+reg.rdata.lineofs[idx-1], reg.rdata.data.ptr+reg.rdata.lineofs[idx], reg.SpanType.sizeof*reg.rdata.data[reg.rdata.lineofs[idx]]) == 0)
      {
        dumpData(reg);
        assert(0, "found two identical, but not merged lines");
      }
      if (reg.rdata.data[reg.rdata.lineofs[idx-1]] < 2) assert(0, "bad data (0)");
      if (reg.rdata.data[reg.rdata.lineofs[idx]] < 2) assert(0, "bad data (1)");
    }
  }
}


void buildBitmap (ref Region reg, int[] bmp) {
  if (reg.rdata.simple) {
    bmp[0..reg.width*reg.height] = (reg.rdata.simpleSolid ? 1 : 0);
    return;
  }
  bmp[0..reg.width*reg.height] = 42;
  foreach (immutable y, uint ofs; reg.rdata.lineofs) {
    usize a = y*reg.width;
    usize len = reg.rdata.data[ofs++];
    if (len < 1) assert(0, "invalid span");
    int sx = 0;
    bool solid = true;
    if (reg.rdata.data[ofs] == 0) { solid = false; ++ofs; }
    while (sx != reg.width) {
      // we should not have two consecutive zero-width spans
      if (reg.rdata.data[ofs] == 0 || reg.rdata.data[ofs] <= sx) {
        //foreach (immutable idx; 0..reg.rdata.data.length) if (reg.rdata.data[idx] >= 0) writeln(idx, ": ", reg.rdata.data[idx]); else break;
        //assert(reg.rdata.data[ofs+1] != 0);
        assert(0, "invalid span");
      }
      int ex = reg.rdata.data[ofs++];
      bmp[a+sx..a+ex] = (solid ? 1 : 0);
      solid = !solid;
      sx = ex;
    }
    debug assert(sx == reg.width);
  }
  foreach (immutable v; bmp[0..reg.width*reg.height]) if (v == 42) assert(0, "invalid region data");
}


int[] buildCoords (int[] bmp, int type, int x0, int x1) {
  bool isSolid (int x) { return (x >= 0 && x < bmp.length && bmp[x] != 0); }
  int[] res;
  while (x0 <= x1) {
    while (x0 <= x1 && type != isSolid(x0)) ++x0;
    if (x0 > x1) break;
    res ~= x0; // start
    while (x0 <= x1 && type == isSolid(x0)) ++x0;
    res ~= x0-1;
  }
  return res;
}


void fuzzyEnumerator () {
  import std.random;
  auto reg = Region(uniform!"[]"(1, 128), 1);
  int[] bmp, ebmp;
  bmp.length = reg.width*reg.height;
  ebmp.length = reg.width*reg.height;
  if (uniform!"[]"(0, 1)) {
    reg.rdata.simpleSolid = false;
    ebmp[] = 0; // default is empty
  } else {
    ebmp[] = 1; // default is solid
  }
  foreach (immutable tx0; 0..1000) {
    checkLineOffsets(reg);
    buildBitmap(reg, bmp[]);
    assert(bmp[] == ebmp[]);
    foreach (immutable trx; 0..200) {
      //writeln("*");
      int x0 = uniform!"[)"(-10, reg.width+10);
      int x1 = uniform!"[)"(-10, reg.width+10);
      if (x0 > x1) { auto t = x0; x0 = x1; x1 = t; }
      int[] coords;
      int type = uniform!"[]"(0, 1);
      if (type == 0) {
        reg.spans!false(0, x0, x1, (x0, x1) { coords ~= x0; coords ~= x1; });
      } else {
        reg.spans!true(0, x0, x1, (x0, x1) { coords ~= x0; coords ~= x1; });
      }
      auto ecr = buildCoords(bmp[], type, x0, x1);
      assert(ecr[] == coords[]);
      // now check enumerator range
      coords.length = 0;
      if (type == 0) {
        foreach (ref pair; reg.spanRange!false(0, x0, x1)) { coords ~= pair.x0; coords ~= pair.x1; }
      } else {
        foreach (ref pair; reg.spanRange!true(0, x0, x1)) { coords ~= pair.x0; coords ~= pair.x1; }
      }
      if (ecr[] != coords[]) {
        import std.stdio : writeln;
        writeln("\ntype=", type);
        writeln("ecr=", ecr);
        writeln("crd=", coords);
      }
      assert(ecr[] == coords[]);
    }
    // now do random punch/patch
    {
      int x = uniform!"[)"(0, reg.width);
      int y = uniform!"[)"(0, reg.height);
      int w = uniform!"[]"(0, reg.width);
      int h = uniform!"[]"(0, reg.height);
      int patch = uniform!"[]"(0, 1);
      if (patch) reg.patch(x, y, w, h); else reg.punch(x, y, w, h);
      // fix ebmp
      foreach (int dy; y..y+h) {
        if (dy < 0) continue;
        if (dy >= reg.height) break;
        foreach (int dx; x..x+w) {
          if (dx < 0) continue;
          if (dx >= reg.width) break;
          ebmp[dy*reg.width+dx] = patch;
        }
      }
    }
  }
}

void main () {
  import iv.writer;
  import std.random;
  foreach (immutable trycount; 0..1000) {
    {
      auto seed = unpredictableSeed;
      //seed = 4098958554;
      rndGen.seed(seed);
      write("try: ", trycount, "; seed = ", seed, " ... ");
    }
    fuzzyEnumerator();
    writeln("OK");
  }
}
}
