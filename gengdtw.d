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
 * adaptation by Ketmar // Vampire Avalon
 */
// DTW-based gesture recognizer
module iv.gengdtw is aliced;
private:

// ////////////////////////////////////////////////////////////////////////// //
import std.range;


// ////////////////////////////////////////////////////////////////////////// //
public alias DTWFloat = float;
public enum DTWMinGestureMatch = 0.85;


// ////////////////////////////////////////////////////////////////////////// //
enum dtwInfinity = 0.2;
enum EPS = 0.000001;


// ////////////////////////////////////////////////////////////////////////// //
import std.traits;


FP angleDiff(FP) (in FP alpha, in FP beta) if (isFloatingPoint!FP) {
  // return 1.0-cos((alpha-beta)*PI);
  DTWFloat d = alpha-beta;
  if (d < -1.0) d += 2.0; else if (d > 1.0) d -= 2.0;
  return d;
}


FP sqr(FP) (in FP x) if (isFloatingPoint!FP) => x*x;


// ////////////////////////////////////////////////////////////////////////// //
public class DTWGlyph {
private:
  static struct Point {
    DTWFloat x, y;
    DTWFloat t = 0.0, dt = 0.0;
    DTWFloat alpha = 0.0;
  }

  Point[] points;
  bool mFinished;
  string mName;

public:
  this () @safe nothrow @nogc {}
  this (string aname) @safe nothrow @nogc => mName = aname;

final:
  @property bool valid () const @safe pure nothrow @nogc => (points.length >= 2);
  @property bool finished () const @safe pure nothrow @nogc => (points.length >= 2 && mFinished);

  auto clear () @safe nothrow @nogc {
    points = points.default;
    mName = null;
    return this;
  }

  auto clone () const @safe {
    auto res = new DTWGlyph(mName);
    if (points.length > 0) res.points = points.dup;
    res.mFinished = mFinished;
    return res;
  }

  // return new glyph if `this` is not finished
  auto getFinished () @safe {
    if (mFinished) {
      return this;
    } else {
      if (points.length < 2) throw new Exception("invalid glyph");
      return this.clone.finish;
    }
  }

  // return new glyph if `this` is not finished
  auto getFinished () @safe const {
    if (mFinished) {
      return this;
    } else {
      if (points.length < 2) throw new Exception("invalid glyph");
      auto g = this.clone;
      g.finish;
      return g;
    }
  }

  auto addPoint (int x, int y) {
    if (mFinished) throw new Exception("can't add points to finished glyph");
    enum MinPointDistance = 4;
    if (points.length > 0) {
      // check distance and don't add points that are too close to each other
      immutable lx = x-points[$-1].x, ly = y-points[$-1].y;
      if (lx*lx+ly*ly < MinPointDistance*MinPointDistance) return this;
    }
    points ~= Point(x, y);
    mFinished = false;
    return this;
  }

  @property string name () const @safe pure nothrow @nogc => mName;
  @property void name (string v) @safe nothrow @nogc => mName = v;

  usize length () const @safe pure nothrow @nogc => points.length;
  alias opDollar = length;

  auto opIndex (usize idx) const @safe pure nothrow @nogc => (idx < points.length ? points[idx] : Point.default);

  auto finish () @safe nothrow @nogc {
    import std.math : hypot, atan2, PI;
    if (mFinished || points.length < 2) return this;
    DTWFloat total = 0.0;
    DTWFloat minX, minY, maxX, maxY;
    DTWFloat scaleX, scaleY, scale;
    points[0].t = 0.0;
    foreach (auto idx; 0..points.length-1) {
      total += hypot(points[idx+1].x-points[idx].x, points[idx+1].y-points[idx].y);
      points[idx+1].t = total;
    }
    foreach (auto idx; 0..points.length) points[idx].t /= total;
    minX = maxX = points[0].x;
    minY = maxY = points[0].y;
    foreach (auto idx; 1..points.length) {
      if (points[idx].x < minX) minX = points[idx].x;
      if (points[idx].x > maxX) maxX = points[idx].x;
      if (points[idx].y < minY) minY = points[idx].y;
      if (points[idx].y > maxY) maxY = points[idx].y;
    }
    scaleX = maxX-minX;
    scaleY = maxY-minY;
    scale = (scaleX > scaleY ? scaleX : scaleY);
    if (scale < 0.001) scale = 1;
    foreach (auto idx; 0..points.length) {
      points[idx].x = (points[idx].x-(minX+maxX)/2.0)/scale+0.5;
      points[idx].y = (points[idx].y-(minY+maxY)/2.0)/scale+0.5;
    }
    foreach (auto idx; 1..points.length-1) {
      points[idx].dt = points[idx+1].t-points[idx].t;
      points[idx].alpha = atan2(points[idx+1].y-points[idx].y, points[idx+1].x-points[idx].x)/PI;
    }
    mFinished = true;
    return this;
  }

  /* To compare two gestures, we use dynamic programming to minimize (an
   * approximation) of the integral over square of the angle difference among
   * (roughly) all reparametrizations whose slope is always between 1/2 and 2.
   */
  DTWFloat compare (const(DTWGlyph) b) const nothrow @nogc {
    static struct A2D(T) {
    private:
      usize dim0, dim1;
      T* data;

    public:
      @disable this ();
      @disable this (this);

      this (usize d0, usize d1, T initV=T.default) nothrow @nogc {
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

      ~this () nothrow @nogc {
        if (data !is null) {
          import core.stdc.stdlib : free;
          free(data);
          // just in case
          data = null;
          dim0 = dim1 = 0;
        }
      }

      T opIndex (in usize i0, in usize i1) const nothrow @nogc {
        if (i0 >= dim0 || i1 >= dim1) assert(0); // the thing that should not be
        return data[i1*dim0+i0];
      }

      T opIndexAssign (in T v, in usize i0, in usize i1) nothrow @nogc {
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
    foreach (auto x; 0..m) {
      foreach (auto y; 0..n) {
        if (dist[x, y] >= dtwInfinity) continue;
        DTWFloat tx = a.points[x].t;
        DTWFloat ty = b.points[y].t;
        auto maxX = x, maxY = y;
        usize k = 0;
        while (k < 4) {
          void step (usize x2, usize y2) nothrow @nogc {
            DTWFloat dtx = a.points[x2].t-tx;
            DTWFloat dty = b.points[y2].t-ty;
            if (dtx >= dty*2.2 || dty >= dtx*2.2 || dtx < EPS || dty < EPS) return;
            ++k;
            DTWFloat d = 0.0;
            auto i = x, j = y;
            DTWFloat nexttx = (a.points[i+1].t-tx)/dtx;
            DTWFloat nextty = (b.points[j+1].t-ty)/dty;
            DTWFloat curT = 0.0;
            for (;;) {
              immutable DTWFloat ad = sqr(.angleDiff(a.points[i].alpha, b.points[j].alpha));
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

  bool match (const(DTWGlyph) pat) const nothrow => (pat !is null ? pat.score(this) >= DTWMinGestureMatch : false);

private:
  DTWFloat angle (usize idx) const @safe pure nothrow @nogc => (idx < points.length ? points[idx].alpha : 0.0);

  DTWFloat angleDiff (const(DTWGlyph) b, usize idx0, usize idx1) const @safe pure nothrow @nogc {
    import std.math : abs;
    return (b !is null && idx0 < points.length && idx1 < b.points.length ? abs(.angleDiff(angle(idx0), b.angle(idx1))) : DTWFloat.nan);
  }

public:
  DTWGlyph findMatch(R) (auto ref R grng, DTWFloat* outscore=null) const
  if (isInputRange!R && !isInfinite!R && is(ElementType!R : DTWGlyph))
  {
    DTWFloat bestScore = -1.0;
    DTWGlyph res = null;
    if (outscore !is null) *outscore = DTWFloat.nan;
    auto me = getFinished;
    if (valid) {
      while (!grng.empty) {
        auto gs = grng.front;
        grng.popFront;
        if (gs is null || !gs.valid) continue;
        auto g = gs.getFinished;
        DTWFloat score = g.score(me);
        if (score >= DTWMinGestureMatch && score > bestScore) {
          bestScore = score;
          res = gs;
        }
      }
    }
    if (res !is null && outscore !is null) *outscore = bestScore;
    return res;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
import iv.stream;


public void gstLibLoad(R, ST) (auto ref R orng, auto ref ST st)
if (isOutputRange!(R, DTWGlyph) && isReadableStream!ST)
{
  DTWGlyph loadGlyph () {
    uint ver;
    auto res = new DTWGlyph();
    auto cnt = st.readNum!uint();
    uint finished = st.readNum!uint();
    if (finished&0x80) {
      // cnt is version; ignore for now, but it is 1
      if (cnt != 1 && cnt != 2) throw new Exception("invalid glyph version");
      ver = cnt;
      finished &= 0x01;
      cnt = st.readNum!uint();
    } else {
      ver = 0;
    }
    if (cnt > 0x7fff_ffff) throw new Exception("invalid glyph point count");
    res.points.length = cnt;
    res.mFinished = (res.points.length > 1 && finished);
    foreach (ref pt; res.points) {
      if (ver == 0) {
        pt.x = st.readNum!double();
        pt.y = st.readNum!double();
        pt.t = st.readNum!double();
        pt.dt = st.readNum!double();
        pt.alpha = st.readNum!double();
      } else {
        // v1 and v2
        pt.x = st.readNum!float();
        pt.y = st.readNum!float();
        if (ver == 1 || finished) {
          pt.t = st.readNum!float();
          pt.dt = st.readNum!float();
          pt.alpha = st.readNum!float();
        }
      }
    }
    return res;
  }

  auto sign = st.readNum!uint();
  if (sign != 0x4C53384Bu) throw new Exception("invalid glyph library signature"); // "K8SL"
  auto ver = st.readNum!ubyte();
  if (ver != 0) throw new Exception("invalid glyph library version");
  auto count = st.readNum!uint();
  if (count > 0x7fff_ffff) throw new Exception("too many glyphs in library");
  while (count-- > 0) {
    // name
    auto len = st.readNum!uint();
    if (len > 1024) throw new Exception("glyph name too long");
    string name;
    if (len > 0) {
      import std.exception : assumeUnique;
      auto buf = new char[](len);
      st.rawReadExact(buf);
      name = buf.assumeUnique;
    }
    // glyph
    auto g = loadGlyph();
    g.mName = name;
    put(orng, g);
  }
}


public DTWGlyph[] gstLibLoad(ST) (auto ref ST st) if (isReadableStream!ST) {
  static struct ORng {
    DTWGlyph[] gls;
    void put (DTWGlyph g) nothrow { if (g !is null && g.valid) gls ~= g; }
  }
  auto r = ORng();
  gstLibLoad(r, st);
  return (r.gls.length ? r.gls : null);
}


// ////////////////////////////////////////////////////////////////////////// //
public void gstLibSave(ST, R) (auto ref ST st, auto ref R grng)
if (isWriteableStream!ST && isInputRange!R && !isInfinite!R && is(ElementType!R : DTWGlyph) &&
    (hasLength!R || isSeekableStream!ST))
{
  st.writeNum!uint(0x4C53384Bu); // "K8SL"
  st.writeNum!ubyte(0); // version
  static if (hasLength!R) {
    auto cnt = grng.length;
    if (cnt > 0x7fff_ffff) throw new Exception("too many glyphs");
    st.writeNum!uint(cast(uint)cnt);
  } else {
    usize cnt = 0;
    auto cntpos = st.tell;
    st.writeNum!uint(0);
  }
  while (!grng.empty) {
    auto g = grng.front;
    grng.popFront;
    if (g is null || !g.valid) throw new Exception("can't save invalid glyph");
    // name
    if (g.name.length > 1024) throw new Exception("glyph name too long");
    st.writeNum!uint(cast(uint)g.name.length);
    st.rawWriteExact(g.name);
    // points
    if (g.points.length > 0x7fff_ffff) throw new Exception("too many points in glyph");
    ubyte ptver;
    static if (DTWFloat.sizeof == float.sizeof) {
      // v1 or v2
      if (!g.finished) {
        // v2
        ptver = 2;
        st.writeNum!uint(2);
        st.writeNum!uint(0x80);
      } else {
        // v1
        ptver = 1;
        st.writeNum!uint(1);
        st.writeNum!uint(0x81);
      }
      st.writeNum!uint(cast(uint)g.points.length);
    } else {
      // v0
      ptver = 0;
      st.writeNum!uint(cast(uint)g.points.length);
      st.writeNum!uint(g.finished ? 1 : 0);
    }
    foreach (immutable pt; g.points) {
      if (ptver == 0) {
        st.writeNum!double(pt.x);
        st.writeNum!double(pt.y);
        st.writeNum!double(pt.t);
        st.writeNum!double(pt.dt);
        st.writeNum!double(pt.alpha);
      } else {
        st.writeNum!float(pt.x);
        st.writeNum!float(pt.y);
        if (ptver == 1) {
          st.writeNum!float(pt.t);
          st.writeNum!float(pt.dt);
          st.writeNum!float(pt.alpha);
        }
      }
    }
    static if (!hasLength!R) {
      if (cnt == 0x7fff_ffff) throw new Exception("too many glyphs");
      ++cnt;
    }
  }
  static if (!hasLength!R) {
    auto cpos = st.tell;
    st.seek(cntpos);
    st.writeNum!uint(cast(uint)cnt);
    st.seek(cpos);
  }
}
