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
// Protractor gesture recognizer, v0
module iv.gengpro0 is aliced;
private:

// ////////////////////////////////////////////////////////////////////////// //
import std.range;


// ////////////////////////////////////////////////////////////////////////// //
public alias GengFloat = float;


// ////////////////////////////////////////////////////////////////////////// //
public enum MinGestureMatch = 1.5;


// ////////////////////////////////////////////////////////////////////////// //
// DO NOT CHANGE!
enum NormalizedPoints = 16; // the paper says that this is enough for protractor to work ok
alias GengPatternPoints = GengFloat[NormalizedPoints*2];


// ////////////////////////////////////////////////////////////////////////// //
enum MinPointDistance = 4;


// ////////////////////////////////////////////////////////////////////////// //
// ignore possible overflows here
import std.traits : isFloatingPoint;

GengFloat distance(FP) (in FP x0, in FP y0, in FP x1, in FP y1) if (isFloatingPoint!FP) {
  import std.math : sqrt;
  immutable dx = x1-x0;
  immutable dy = y1-y0;
  return sqrt(dx*dx+dy*dy);
}


// ////////////////////////////////////////////////////////////////////////// //
public class PTGlyph {
private:
  GengPatternPoints patpoints;
  GengFloat[] points; // [0]:x, [1]:y, [2]:x, [3]:y, etc...
  bool mNormalized; // true: `patpoints` is ok
  bool mOriented = true;
  string mName;

  private static normBlkAttr (void* ptr) {
    import core.memory : GC;
    pragma(inline, true);
    if (ptr !is null && ptr is GC.addrOf(ptr)) GC.setAttr(ptr, GC.BlkAttr.NO_INTERIOR);
  }

public:
  this () nothrow @safe @nogc {}
  this (string aname, bool aoriented=true) nothrow @safe @nogc { mName = aname; mOriented = aoriented; }
  this (string aname, in GengPatternPoints apat, bool aoriented) nothrow @safe @nogc {
    mName = aname;
    patpoints[] = apat[];
    mNormalized = true;
    mOriented = aoriented;
  }

final:
  @property bool valid () const pure nothrow @safe @nogc { pragma(inline, true); return (mNormalized || points.length >= 4); }
  @property bool normalized () const pure nothrow @safe @nogc { pragma(inline, true); return mNormalized; }
  @property bool oriented () const pure nothrow @safe @nogc { pragma(inline, true); return mOriented; }
  @property void oriented (bool v) pure nothrow @safe @nogc { pragma(inline, true); if (!mNormalized) mOriented = v; } // can't be changed for normalized glyphs

  @property string name () const pure nothrow @safe @nogc { pragma(inline, true); return mName; }
  @property void name (string v) @safe nothrow @nogc { pragma(inline, true); mName = v; }

  usize length () const pure nothrow @safe @nogc { pragma(inline, true); return (mNormalized ? NormalizedPoints : points.length/2); }
  alias opDollar = length;

  auto x (usize idx) const pure nothrow @safe @nogc {
    pragma(inline, true);
    if (!mNormalized) {
      return (idx*2 < points.length ? points[idx*2] : typeof(points[0]).nan);
    } else {
      return (idx < NormalizedPoints ? patpoints[idx*2] : typeof(points[0]).nan);
    }
  }

  auto y (usize idx) const pure nothrow @safe @nogc {
    pragma(inline, true);
    if (!mNormalized) {
      return (idx*2 < points.length ? points[idx*2+1] : typeof(points[0]).nan);
    } else {
      return (idx < NormalizedPoints ? patpoints[idx*2+1] : typeof(points[0]).nan);
    }
  }

  auto clear () nothrow {
    if (points.length) { points.length = 0; points.assumeSafeAppend; }
    mNormalized = false;
    mName = null;
    return this;
  }

  auto clone () const {
    auto res = new PTGlyph(mName);
    res.mNormalized = mNormalized;
    res.mOriented = mOriented;
    res.patpoints[] = patpoints[];
    if (points.length > 0) {
      res.points = points.dup;
      normBlkAttr(res.points.ptr);
    }
    return res;
  }

  auto addPoint (int x, int y) {
    if (mNormalized) throw new Exception("can't add point to normalized glyph");
    if (points.length > 0) {
      // check distance and don't add points that are too close to each other
      immutable lx = x-points[$-2], ly = y-points[$-1];
      if (lx*lx+ly*ly < MinPointDistance*MinPointDistance) return this;
    }
    auto optr = points.ptr;
    points ~= x;
    if (optr != points.ptr) { normBlkAttr(points.ptr); optr = points.ptr; }
    points ~= y;
    if (optr != points.ptr) { normBlkAttr(points.ptr); optr = points.ptr; }
    mNormalized = false;
    return this;
  }

  auto normalize (bool dropPoints=true) {
    if (!mNormalized) {
      if (points.length < 4) throw new Exception("glyph must have at least two points");
      buildNormPoints(patpoints, points, mOriented);
      mNormalized = true;
      if (dropPoints) {
        points.length = 0;
        points.assumeSafeAppend;
      }
    }
    return this;
  }

  // this: template
  GengFloat match (const(PTGlyph) sample) const pure nothrow @safe @nogc {
    if (sample is null || !sample.valid || !valid) return -GengFloat.infinity;
    if (mNormalized) {
      // this is normalized
      return match(patpoints, sample);
    } else {
      // this is not normalized
      GengPatternPoints v1 = void;
      buildNormPoints(v1, points, mOriented);
      return match(v1, sample);
    }
  }

  string patpointsToString () {
    import std.string : format;
    return format("%s", patpoints);
  }

private:
  // this: template
  static GengFloat match (in GengPatternPoints tpl, const(PTGlyph) sample) pure nothrow @safe @nogc {
    if (sample is null || !sample.valid) return -GengFloat.infinity;
    if (sample.mNormalized) {
      return match(tpl, sample.patpoints);
    } else {
      GengPatternPoints spts = void;
      buildNormPoints(spts, sample.points, sample.mOriented);
      return match(tpl, spts);
    }
  }

  static GengFloat match (in GengPatternPoints v0, in GengPatternPoints v1) pure nothrow @safe @nogc {
    return 1.0/optimalCosineDistance(v0, v1);
  }

  static GengFloat optimalCosineDistance (in GengPatternPoints v0, in GengPatternPoints v1) pure nothrow @safe @nogc {
    import std.math : atan, acos, cos, sin;
    GengFloat a = 0.0, b = 0.0;
    foreach (immutable idx; 0..NormalizedPoints) {
      a += v0[idx*2+0]*v1[idx*2+0]+v0[idx*2+1]*v1[idx*2+1];
      b += v0[idx*2+0]*v1[idx*2+1]-v0[idx*2+1]*v1[idx*2+0];
    }
    immutable GengFloat angle = atan(b/a);
    return acos(a*cos(angle)+b*sin(angle));
  }

  // glyph length (not point counter!)
  static GengFloat glyphLength (in GengFloat[] points) pure nothrow @safe @nogc {
    GengFloat res = 0.0;
    if (points.length >= 4) {
      // don't want to bring std.algo here
      GengFloat px = points[0], py = points[1];
      foreach (immutable idx; 2..points.length/2) {
        immutable cx = points[idx*2+0], cy = points[idx*2+1];
        res += distance(px, py, cx, cy);
        px = cx;
        py = cy;
      }
    }
    return res;
  }

  static void resample (out GengPatternPoints ptres, in GengFloat[] points) pure @safe nothrow @nogc {
    assert(points.length >= 4);
    immutable GengFloat I = glyphLength(points)/(NormalizedPoints-1); // interval length
    GengFloat D = 0.0;
    GengFloat prx = points[0];
    GengFloat pry = points[1];
    // add first point as-is
    ptres[0] = prx;
    ptres[1] = pry;
    usize ptpos = 2, oppos = 2;
    while (oppos < points.length) {
      immutable GengFloat cx = points[oppos], cy = points[oppos+1];
      immutable d = distance(prx, pry, cx, cy);
      if (D+d >= I) {
        immutable dd = (I-D)/d;
        immutable qx = prx+dd*(cx-prx);
        immutable qy = pry+dd*(cy-pry);
        assert(ptpos < NormalizedPoints*2);
        ptres[ptpos++] = qx;
        ptres[ptpos++] = qy;
        // use 'q' as previous point
        prx = qx;
        pry = qy;
        D = 0.0;
      } else {
        D += d;
        prx = cx;
        pry = cy;
        oppos += 2;
      }
    }
    // somtimes we fall a rounding-error short of adding the last point, so add it if so
    if (ptpos/2 == NormalizedPoints-1) {
      ptres[ptpos++] = points[$-2];
      ptres[ptpos++] = points[$-1];
    }
    assert(ptpos == NormalizedPoints*2);
  }

  // stroke is not required to be centered, but it must be resampled
  static void vectorize (out GengPatternPoints vres, in GengPatternPoints ptx, bool orientationSensitive)
  pure nothrow @safe @nogc
  {
    import std.math : atan2, cos, sin, floor, sqrt, PI;
    GengPatternPoints pts;
    GengFloat indAngle, delta;
    GengFloat cx = 0.0, cy = 0.0;
    // center it
    foreach (immutable idx; 0..NormalizedPoints) {
      cx += ptx[idx*2+0];
      cy += ptx[idx*2+1];
    }
    cx /= NormalizedPoints;
    cy /= NormalizedPoints;
    foreach (immutable idx; 0..NormalizedPoints) {
      pts[idx*2+0] = ptx[idx*2+0]-cx;
      pts[idx*2+1] = ptx[idx*2+1]-cy;
    }
    indAngle = atan2(pts[1], pts[0]); // always must be done for centered stroke
    if (orientationSensitive) {
      immutable base_orientation = (PI/4.0)*floor((indAngle+PI/8.0)/(PI/4.0));
      delta = base_orientation-indAngle;
    } else {
      delta = indAngle;
    }
    immutable GengFloat cosd = cos(delta);
    immutable GengFloat sind = sin(delta);
    GengFloat sum = 0.0;
    foreach (immutable idx; 0..NormalizedPoints) {
      immutable nx = pts[idx*2+0]*cosd-pts[idx*2+1]*sind;
      immutable ny = pts[idx*2+1]*cosd+pts[idx*2+0]*sind;
      vres[idx*2+0] = nx;
      vres[idx*2+1] = ny;
      sum += nx*nx+ny*ny;
    }
    immutable GengFloat magnitude = sqrt(sum);
    foreach (immutable idx; 0..NormalizedPoints*2) vres[idx] /= magnitude;
  }

  static void buildNormPoints (out GengPatternPoints vres, in GengFloat[] points, bool orientationSensitive)
  pure nothrow @safe @nogc
  {
    assert(points.length >= 4);
    GengPatternPoints tmp = void;
    resample(tmp, points);
    vectorize(vres, tmp, orientationSensitive);
  }

public:
  PTGlyph findMatch(R) (auto ref R grng, GengFloat* outscore=null) const
  if (isInputRange!R && !isInfinite!R && is(ElementType!R : PTGlyph))
  {
    GengFloat bestScore = -GengFloat.infinity;
    PTGlyph res = null;
    if (outscore !is null) *outscore = GengFloat.nan;
    if (valid) {
      // build normalized `this` glyph in pts
      GengPatternPoints pts = void;
      if (this.mNormalized) {
        pts[] = this.patpoints[];
      } else {
        buildNormPoints(pts, points, mOriented);
      }
      while (!grng.empty) {
        auto gs = grng.front;
        grng.popFront;
        if (gs is null || !gs.valid) continue;
        GengFloat score = match(pts, gs);
        if (score >= MinGestureMatch && score > bestScore) {
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
import iv.vfs;


public void gstLibLoad(R) (auto ref R orng, VFile st) if (isOutputRange!(R, PTGlyph)) {
  auto sign = st.readNum!ulong();
  if (sign != 0x304244525450384BUL && sign != 0x314244525450384BUL) throw new Exception("invalid library signature"); // "K8PTRDB0"/1
  ubyte ver = ((sign>>56)-0x30)&0xff;
  auto cnt = st.readNum!uint();
  if (cnt > 0x7fff_ffff) throw new Exception("too many glyphs");
  if (cnt == 0) return;
  foreach (immutable idx; 0..cnt) {
    // name
    auto len = st.readNum!uint();
    if (len > 1024) throw new Exception("glyph name too long");
    string name;
    if (len > 0) {
      auto buf = new char[](len);
      st.rawReadExact(buf);
      name = cast(string)buf; // it is safe to cast here
    }
    // template
    GengPatternPoints pts = void;
    foreach (ref pt; pts) {
      pt = st.readNum!float();
      if (pt != pt) throw new Exception("invalid number"); // nan check
    }
    bool oriented = true;
    if (ver == 1) oriented = (st.readNum!ubyte != 0);
    auto g = new PTGlyph(name, pts, oriented);
    put(orng, g);
  }
}


public PTGlyph[] gstLibLoad (VFile fl) {
  static struct ORng {
    PTGlyph[] gls;
    void put (PTGlyph g) nothrow { if (g !is null && g.valid) gls ~= g; }
  }
  auto r = ORng();
  gstLibLoad(r, fl);
  return (r.gls.length ? r.gls : null);
}


// ////////////////////////////////////////////////////////////////////////// //
public void gstLibSave(R) (VFile st, auto ref R grng) if (isInputRange!R && !isInfinite!R && is(ElementType!R : PTGlyph)) {
  st.writeNum!ulong(0x314244525450384BuL); // "K8PTRDB1"
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
    GengPatternPoints pts = void;
    if (g.mNormalized) {
      pts[] = g.patpoints[];
    } else {
      g.buildNormPoints(pts, g.points, g.mOriented);
    }
    foreach (immutable pt; pts) st.writeNum!float(cast(float)pt);
    st.writeNum!ubyte(g.mOriented ? 1 : 0);
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
