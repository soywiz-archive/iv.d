/*
 * Copyright (c) 2009, Thomas Jaeger <ThJaeger@gmail.com>
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
 *
 * adaptation by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 */
// DTW-based gesture recognizer
module iv.gengdtw is aliced;
private:

import iv.vfs;


// ////////////////////////////////////////////////////////////////////////// //
public alias DTWFloat = float;


// ////////////////////////////////////////////////////////////////////////// //
enum dtwInfinity = cast(DTWFloat)0.2;
enum EPS = cast(DTWFloat)0.000001;


// ////////////////////////////////////////////////////////////////////////// //
public final class DTWGlyph {
public:
  enum MinMatchScore = cast(DTWFloat)0.85;

private:
  static struct Point {
    DTWFloat x, y;
    DTWFloat t = 0.0, dt = 0.0;
    DTWFloat alpha = 0.0;
    @property bool valid () const pure nothrow @safe @nogc { pragma(inline, true); import std.math : isNaN; return (!x.isNaN && !y.isNaN); }
  }

private:
  Point[] points;
  bool mFinished;
  string mName;

private:
  static void unsafeArrayAppend(T) (ref T[] arr, auto ref T v) {
    auto optr = arr.ptr;
    arr ~= v;
    if (optr !is arr.ptr) {
      import core.memory : GC;
      optr = arr.ptr;
      if (optr !is null && optr is GC.addrOf(optr)) GC.setAttr(optr, GC.BlkAttr.NO_INTERIOR);
    }
  }

  static T[] unsafeArrayDup(T) (const(T)[] arr) {
    auto res = arr.dup;
    if (res.ptr) {
      import core.memory : GC;
      if (res.ptr !is null && res.ptr is GC.addrOf(res.ptr)) GC.setAttr(res.ptr, GC.BlkAttr.NO_INTERIOR);
    }
    return res;
  }

public:
  this () nothrow @safe @nogc {}
  this (string aname) nothrow @safe @nogc { mName = aname; }

  @property const pure nothrow @safe @nogc {
    bool valid () { pragma(inline, true); return (points.length >= 2); }
    bool finished () { pragma(inline, true); return (points.length >= 2 && mFinished); }
    string name () const { pragma(inline, true); return mName; }
    usize length () const pure nothrow @safe @nogc { return points.length; }
    alias opDollar = length;
    Point opIndex (usize idx) { pragma(inline, true); return (idx < points.length ? points[idx] : Point.default); }
  }

  @property void name(T:const(char)[]) (T v) nothrow @safe {
    static if (is(T == typeof(null))) mName = null;
    else static if (is(T == string)) mName = v;
    else { if (mName != v) mName = v.idup; }
  }

  // you can use this to "reset" points array without actually deleting it
  // otherwise it is identical to "clear"
  auto reset () nothrow @trusted {
    if (points.length) { points.length = 0; points.assumeSafeAppend; }
    mName = null;
    mFinished = false;
    return this;
  }

  auto clear () nothrow @trusted {
    delete points;
    mName = null;
    mFinished = false;
    return this;
  }

  auto clone () const @trusted {
    auto res = new DTWGlyph(mName);
    if (points.length > 0) res.points = unsafeArrayDup(points);
    res.mFinished = mFinished;
    return res;
  }

  // return new (cloned) glyph if `this` is not finished
  DTWGlyph getFinished () const @safe {
    if (mFinished) {
      return this.clone;
    } else {
      if (points.length < 2) throw new Exception("invalid glyph");
      return this.clone.finish;
    }
  }

  auto appendPoint (int x, int y) @trusted {
    if (mFinished) throw new Exception("can't append points to finished glyph");
    enum MinPointDistance = 4;
    if (points.length > 0) {
      // check distance and don't add points that are too close to each other
      immutable lx = x-points[$-1].x, ly = y-points[$-1].y;
      if (lx*lx+ly*ly < MinPointDistance*MinPointDistance) return this;
    }
    unsafeArrayAppend(points, Point(x, y));
    mFinished = false;
    return this;
  }

  // "finish" (finalize) gesture in-place
  auto finish () nothrow @trusted @nogc {
    import std.math : hypot, atan2, PI;
    if (mFinished || points.length < 2) return this;
    DTWFloat total = 0.0;
    DTWFloat minX, minY, maxX, maxY;
    DTWFloat scaleX, scaleY, scale;
    points[0].t = 0.0;
    foreach (immutable idx; 0..points.length-1) {
      total += hypot(points.ptr[idx+1].x-points.ptr[idx].x, points.ptr[idx+1].y-points.ptr[idx].y);
      points.ptr[idx+1].t = total;
    }
    foreach (ref Point v; points[]) v.t /= total;
    minX = maxX = points.ptr[0].x;
    minY = maxY = points.ptr[0].y;
    foreach (immutable idx; 1..points.length) {
      if (points.ptr[idx].x < minX) minX = points.ptr[idx].x;
      if (points.ptr[idx].x > maxX) maxX = points.ptr[idx].x;
      if (points.ptr[idx].y < minY) minY = points.ptr[idx].y;
      if (points.ptr[idx].y > maxY) maxY = points.ptr[idx].y;
    }
    scaleX = maxX-minX;
    scaleY = maxY-minY;
    scale = (scaleX > scaleY ? scaleX : scaleY);
    if (scale < 0.001) scale = 1;
    immutable DTWFloat mx2 = (minX+maxX)/2.0;
    immutable DTWFloat my2 = (minY+maxY)/2.0;
    foreach (immutable idx; 0..points.length) {
      points.ptr[idx].x = (points.ptr[idx].x-mx2)/scale+0.5;
      points.ptr[idx].y = (points.ptr[idx].y-my2)/scale+0.5;
    }
    foreach (immutable idx; 1..points.length-1) {
      points.ptr[idx].dt = points.ptr[idx+1].t-points.ptr[idx].t;
      points.ptr[idx].alpha = atan2(points.ptr[idx+1].y-points.ptr[idx].y, points.ptr[idx+1].x-points.ptr[idx].x)/PI;
    }
    mFinished = true;
    return this;
  }

  /* To compare two gestures, we use dynamic programming to minimize (an approximation)
   * of the integral over square of the angle difference among (roughly) all
   * reparametrizations whose slope is always between 1/2 and 2.
   * Use `isGoodScore()` to check if something was (somewhat) reliably matched.
   */
  DTWFloat compare (const(DTWGlyph) b) const nothrow @nogc {
    static struct A2D(T) {
    private:
      usize dim0, dim1;
      T* data;

    public nothrow @nogc:
      @disable this ();
      @disable this (this);

      this (usize d0, usize d1, T initV=T.default) {
        import core.stdc.stdlib : malloc;
        import core.exception : onOutOfMemoryError;
        if (d0 < 1) d0 = 1;
        if (d1 < 1) d1 = 1;
        data = cast(T*)malloc(T.sizeof*d0*d1);
        if (data is null) onOutOfMemoryError();
        dim0 = d0;
        dim1 = d1;
        data[0..d0*d1] = initV;
      }

      ~this () {
        if (data !is null) {
          import core.stdc.stdlib : free;
          free(data);
          // just in case
          data = null;
          dim0 = dim1 = 0;
        }
      }

      T opIndex (in usize i0, in usize i1) const {
        //pragma(inline, true);
        if (i0 >= dim0 || i1 >= dim1) assert(0); // the thing that should not be
        return data[i1*dim0+i0];
      }

      T opIndexAssign (in T v, in usize i0, in usize i1) {
        //pragma(inline, true);
        if (i0 >= dim0 || i1 >= dim1) assert(0); // the thing that should not be
        return (data[i1*dim0+i0] = v);
      }
    }

    const(DTWGlyph) a = this;
    if (!finished || b is null || !b.finished) return dtwInfinity;
    immutable m = a.points.length-1;
    immutable n = b.points.length-1;
    DTWFloat cost = dtwInfinity;
    auto dist = A2D!DTWFloat(m+1, n+1, dtwInfinity);
    auto prevx = A2D!usize(m+1, n+1);
    auto prevy = A2D!usize(m+1, n+1);
    //foreach (auto idx; 0..m+1) foreach (auto idx1; 0..n+1) dist[idx, idx1] = dtwInfinity;
    //dist[m, n] = dtwInfinity;
    dist[0, 0] = 0.0;
    foreach (immutable x; 0..m) {
      foreach (immutable y; 0..n) {
        if (dist[x, y] >= dtwInfinity) continue;
        DTWFloat tx = a.points[x].t;
        DTWFloat ty = b.points[y].t;
        usize maxX = x, maxY = y;
        usize k = 0;
        while (k < 4) {
          void step (usize x2, usize y2) nothrow @nogc {
            DTWFloat dtx = a.points[x2].t-tx;
            DTWFloat dty = b.points[y2].t-ty;
            if (dtx >= dty*2.2 || dty >= dtx*2.2 || dtx < EPS || dty < EPS) return;
            ++k;
            DTWFloat d = 0.0;
            usize i = x, j = y;
            DTWFloat nexttx = (a.points[i+1].t-tx)/dtx;
            DTWFloat nextty = (b.points[j+1].t-ty)/dty;
            DTWFloat curT = 0.0;
            for (;;) {
              immutable DTWFloat ad = sqr(angleDiff(a.points[i].alpha, b.points[j].alpha));
              DTWFloat nextt = (nexttx < nextty ? nexttx : nextty);
              bool done = (nextt >= 1.0-EPS);
              if (done) nextt = 1.0;
              d += (nextt-curT)*ad;
              if (done) break;
              curT = nextt;
              if (nexttx < nextty) {
                nexttx = (a.points[++i+1].t-tx)/dtx;
              } else {
                nextty = (b.points[++j+1].t-ty)/dty;
              }
            }
            DTWFloat newDist = dist[x, y]+d*(dtx+dty);
            if (newDist != newDist) assert(0); /*???*/
            if (newDist >= dist[x2, y2]) return;
            prevx[x2, y2] = x;
            prevy[x2, y2] = y;
            dist[x2, y2] = newDist;
          }

          if (a.points[maxX+1].t-tx > b.points[maxY+1].t-ty) {
            ++maxY;
            if (maxY == n) { step(m, n); break; }
            foreach (usize x2; x+1..maxX+1) step(x2, maxY);
          } else {
            ++maxX;
            if (maxX == m) { step(m, n); break; }
            foreach (usize y2; y+1..maxY+1) step(maxX, y2);
          }
        }
      }
    }
    return dist[m, n]; // cost
  }

  DTWFloat score (const(DTWGlyph) pat) const nothrow {
    if (!finished || pat is null || !pat.finished) return -1.0;
    DTWFloat cost = pat.compare(this), score;
    if (cost >= dtwInfinity) return -1.0;
    score = 1.0-2.5*cost;
    if (score <= 0.0) return 0.0;
    return score;
  }

  bool match (const(DTWGlyph) pat) const nothrow { return (pat !is null ? pat.score(this) >= MinMatchScore : false); }

  static bool isGoodScore (DTWFloat score) {
    pragma(inline, true);
    import std.math : isNaN;
    return (!score.isNaN ? score >= MinMatchScore : false);
  }

private:
  DTWFloat angle (usize idx) const pure nothrow @safe @nogc { return (idx < points.length ? points[idx].alpha : 0.0); }

  DTWFloat angleDiff (const(DTWGlyph) b, usize idx0, usize idx1) const pure nothrow @safe @nogc {
    import std.math : abs;
    return (b !is null && idx0 < points.length && idx1 < b.points.length ? abs(angleDiff(angle(idx0), b.angle(idx1))) : DTWFloat.nan);
  }

  static DTWFloat sqr (in DTWFloat x) pure nothrow @safe @nogc { pragma(inline, true); return x*x; }

  static DTWFloat angleDiff (in DTWFloat alpha, in DTWFloat beta) pure nothrow @safe @nogc {
    // return 1.0-cos((alpha-beta)*PI);
    pragma(inline, true);
    DTWFloat d = alpha-beta;
    if (d < cast(DTWFloat)-1.0) d += cast(DTWFloat)2.0; else if (d > cast(DTWFloat)1.0) d -= cast(DTWFloat)2.0;
    return d;
  }

public:
  const(DTWGlyph) findMatch (const(DTWGlyph)[] list, DTWFloat* outscore=null) const {
    DTWFloat bestScore = cast(DTWFloat)-1.0;
    DTWGlyph res = null;
    if (outscore !is null) *outscore = DTWFloat.nan;
    if (valid) {
      auto me = getFinished;
      scope(exit) delete me;
      foreach (const DTWGlyph gs; list) {
        if (gs is null || !gs.valid) continue;
        auto g = gs.getFinished;
        scope(exit) delete g;
        DTWFloat score = g.score(me);
        if (score >= MinMatchScore && score > bestScore) {
          bestScore = score;
          res = cast(DTWGlyph)gs; // sorry
        }
      }
    }
    if (res !is null && outscore !is null) *outscore = bestScore;
    return res;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
public DTWGlyph[] gstLibLoad (VFile fl) {
  DTWGlyph loadGlyph () {
    uint ver;
    auto res = new DTWGlyph();
    auto cnt = fl.readNum!uint;
    uint finished = fl.readNum!uint;
    if (finished&0x80) {
      // cnt is version; ignore for now, but it is 1
      if (cnt != 1 && cnt != 2) throw new Exception("invalid glyph version");
      ver = cnt;
      finished &= 0x01;
      cnt = fl.readNum!uint;
    } else {
      ver = 0;
    }
    if (cnt > 0x7fff_ffff) throw new Exception("invalid glyph point count");
    res.points.length = cnt;
    res.mFinished = (res.points.length > 1 && finished);
    foreach (ref pt; res.points) {
      if (ver == 0) {
        pt.x = fl.readNum!double;
        pt.y = fl.readNum!double;
        pt.t = fl.readNum!double;
        pt.dt = fl.readNum!double;
        pt.alpha = fl.readNum!double;
      } else {
        // v1 and v2
        pt.x = fl.readNum!float;
        pt.y = fl.readNum!float;
        if (ver == 1 || finished) {
          pt.t = fl.readNum!float;
          pt.dt = fl.readNum!float;
          pt.alpha = fl.readNum!float;
        }
      }
    }
    return res;
  }

  DTWGlyph[] res;
  auto sign = fl.readNum!uint;
  if (sign != 0x4C53384Bu) throw new Exception("invalid glyph library signature"); // "K8SL"
  auto ver = fl.readNum!ubyte;
  if (ver != 0) throw new Exception("invalid glyph library version");
  auto count = fl.readNum!uint;
  if (count > 0x7fff_ffff) throw new Exception("too many glyphs in library");
  while (count-- > 0) {
    // name
    auto len = fl.readNum!uint();
    if (len > 1024) throw new Exception("glyph name too long");
    string name;
    if (len > 0) {
      auto buf = new char[](len);
      fl.rawReadExact(buf);
      name = cast(string)buf; // it is safe to cast here
    }
    // glyph
    auto g = loadGlyph();
    g.mName = name;
    res ~= g;
  }
  return res;
}


// ////////////////////////////////////////////////////////////////////////// //
public void gstLibSave (VFile fl, const(DTWGlyph)[] list) {
  if (list.length > uint.max/16) throw new Exception("too many glyphs");
  fl.rawWriteExact("K8SL");
  fl.writeNum!ubyte(0); // version
  fl.writeNum!uint(cast(uint)list.length);
  foreach (const DTWGlyph g; list) {
    if (g is null || !g.valid) throw new Exception("can't save invalid glyph");
    // name
    if (g.name.length > 1024) throw new Exception("glyph name too long");
    fl.writeNum!uint(cast(uint)g.name.length);
    fl.rawWriteExact(g.name);
    // points
    if (g.points.length > uint.max/64) throw new Exception("too many points in glyph");
    ubyte ptver;
    static if (DTWFloat.sizeof == float.sizeof) {
      // v1 or v2
      if (!g.finished) {
        // v2
        ptver = 2;
        fl.writeNum!uint(2);
        fl.writeNum!uint(0x80);
      } else {
        // v1
        ptver = 1;
        fl.writeNum!uint(1);
        fl.writeNum!uint(0x81);
      }
      fl.writeNum!uint(cast(uint)g.points.length);
    } else {
      // v0
      ptver = 0;
      fl.writeNum!uint(cast(uint)g.points.length);
      fl.writeNum!uint(g.finished ? 1 : 0);
    }
    foreach (immutable pt; g.points) {
      if (ptver == 0) {
        fl.writeNum!double(pt.x);
        fl.writeNum!double(pt.y);
        fl.writeNum!double(pt.t);
        fl.writeNum!double(pt.dt);
        fl.writeNum!double(pt.alpha);
      } else {
        fl.writeNum!float(pt.x);
        fl.writeNum!float(pt.y);
        if (ptver == 1) {
          fl.writeNum!float(pt.t);
          fl.writeNum!float(pt.dt);
          fl.writeNum!float(pt.alpha);
        }
      }
    }
  }
}
