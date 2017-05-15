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
// Protractor gesture recognizer, v1
module iv.gengpro1 is aliced;
private:

import iv.vfs;


// ////////////////////////////////////////////////////////////////////////// //
public alias GengFloat = float; ///


// ////////////////////////////////////////////////////////////////////////// //
// DO NOT CHANGE!
enum NormalizedPoints = 16; // the paper says that this is enough for protractor to work ok
static assert(NormalizedPoints > 2 && NormalizedPoints < ushort.max);
alias GengPatternPoints = GengFloat[NormalizedPoints*2];
enum MinPointDistance = 4;


// ////////////////////////////////////////////////////////////////////////// //
///
public class PTGlyph {
  public enum MinMatchScore = 1.5; ///

public:
  ///
  static struct Point {
    GengFloat x, y;
    @property bool valid () const pure nothrow @safe @nogc { pragma(inline, true); import std.math : isNaN; return (!x.isNaN && !y.isNaN); }
  }

private:
  GengPatternPoints patpoints;
  GengFloat[] points; // [0]:x, [1]:y, [2]:x, [3]:y, etc...
  bool mNormalized; // true: `patpoints` is ok
  bool mOriented = true;
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

  static normBlkAttr(T) (T[] arr) {
    pragma(inline, true);
    import core.memory : GC;
    if (arr.ptr !is null && arr.ptr is GC.addrOf(arr.ptr)) GC.setAttr(arr.ptr, GC.BlkAttr.NO_INTERIOR);
  }

public:
  this () nothrow @safe @nogc {}

  this (string aname, bool aoriented=true) nothrow @safe @nogc { mName = aname; mOriented = aoriented; } ///

  ///
  this (string aname, in GengPatternPoints apat, bool aoriented=true) nothrow @safe @nogc {
    mName = aname;
    patpoints[] = apat[];
    mNormalized = true;
    mOriented = aoriented;
  }

final:
  @property const pure nothrow @safe @nogc {
    bool valid () { pragma(inline, true); return (mNormalized || points.length >= 4); } ///
    bool normalized () { pragma(inline, true); return mNormalized; } ///
    bool oriented () { pragma(inline, true); return mOriented; } ///
    string name () { pragma(inline, true); return mName; } ///
    bool hasOriginalPoints () { pragma(inline, true); return (points.length != 0); } ///
    usize length () { pragma(inline, true); return points.length/2; } /// number of original points
    alias opDollar = length;
    /// return normalized points
    GengPatternPoints normPoints () {
      GengPatternPoints res = patpoints[];
      if (!mNormalized && points.length >= 4) resample(res, points);
      return res;
    }
    enum normLength = NormalizedPoints;
    Point normPoint (usize idx) {
      if (!valid || idx >= NormalizedPoints) return Point.default;
      if (mNormalized) {
        return Point(patpoints[idx*2+0], patpoints[idx*2+1]);
      } else {
        GengPatternPoints rpt = void;
        resample(rpt, points);
        return Point(patpoints[idx*2+0], patpoints[idx*2+1]);
      }
    }
    /// return original point
    Point opIndex (usize idx) { pragma(inline, true); return (idx < points.length/2 ? Point(points[idx*2], points[idx*2+1]) : Point.default); }
  }

  /// can't be changed for normalized glyphs with original points dropped
  @property void oriented (bool v) pure nothrow @safe @nogc {
    if (mNormalized && points.length < 4) return;
    if (mOriented != v) {
      mOriented = v;
      mNormalized = false;
    }
  }

  ///
  @property void name(T:const(char)[]) (T v) nothrow @safe {
    static if (is(T == typeof(null))) mName = null;
    else static if (is(T == string)) mName = v;
    else { if (mName != v) mName = v.idup; }
  }

  /// will not clear orientation
  auto clear () nothrow @trusted {
    delete points;
    mNormalized = false;
    mName = null;
    return this;
  }

  ///
  auto clone () const @trusted {
    auto res = new PTGlyph();
    res.mName = mName;
    res.mNormalized = mNormalized;
    res.mOriented = mOriented;
    res.patpoints[] = patpoints[];
    res.points = unsafeArrayDup(points);
    return res;
  }

  ///
  auto appendPoint (int x, int y) nothrow @trusted {
    immutable GengFloat fx = cast(GengFloat)x;
    immutable GengFloat fy = cast(GengFloat)y;
    if (points.length > 0) {
      // check distance and don't add points that are too close to each other
      immutable lx = fx-points[$-2], ly = fy-points[$-1];
      if (lx*lx+ly*ly < MinPointDistance*MinPointDistance) return this;
    }
    unsafeArrayAppend(points, cast(GengFloat)fx);
    unsafeArrayAppend(points, cast(GengFloat)fy);
    mNormalized = false;
    return this;
  }

  ///
  auto normalize (bool dropOriginalPoints=true) {
    if (!mNormalized) {
      if (points.length < 4) throw new Exception("glyph must have at least two points");
      buildNormPoints(patpoints, points, mOriented);
      mNormalized = true;
    }
    if (dropOriginalPoints) { assert(mNormalized); delete points; }
    return this;
  }

  ///
  static bool isGoodScore (GengFloat score) {
    pragma(inline, true);
    import std.math : isNaN;
    return (!score.isNaN ? score >= MinMatchScore : false);
  }

  /// this: template; you can use `isGoodScore()` to see if it is a good score to detect a match
  GengFloat match (const(PTGlyph) sample) const pure nothrow @safe @nogc {
    if (sample is null || !sample.valid || !valid) return -GengFloat.infinity;
    GengPatternPoints me = patpoints[];
    GengPatternPoints it = sample.patpoints[];
    if (!mNormalized) buildNormPoints(me, points, mOriented);
    if (!sample.mNormalized) buildNormPoints(it, sample.points, sample.mOriented);
    return match(me, it);
  }

private:
  // ignore possible overflows here
  static GengFloat distance (in GengFloat x0, in GengFloat y0, in GengFloat x1, in GengFloat y1) pure nothrow @safe @nogc {
    pragma(inline, true);
    import std.math : sqrt;
    immutable dx = x1-x0, dy = y1-y0;
    return sqrt(dx*dx+dy*dy);
  }

  static GengFloat match (in ref GengPatternPoints tpl, in ref GengPatternPoints v1) pure nothrow @safe @nogc {
    pragma(inline, true);
    return cast(GengFloat)1.0/optimalCosineDistance(tpl, v1);
  }

  static GengFloat optimalCosineDistance (in ref GengPatternPoints v0, in ref GengPatternPoints v1) pure nothrow @trusted @nogc {
    import std.math : atan, acos, cos, sin;
    GengFloat a = 0, b = 0;
    foreach (immutable idx; 0..NormalizedPoints) {
      a += v0.ptr[idx*2+0]*v1.ptr[idx*2+0]+v0.ptr[idx*2+1]*v1.ptr[idx*2+1];
      b += v0.ptr[idx*2+0]*v1.ptr[idx*2+1]-v0.ptr[idx*2+1]*v1.ptr[idx*2+0];
    }
    immutable GengFloat angle = atan(b/a);
    return acos(a*cos(angle)+b*sin(angle));
  }

  // glyph length (not point counter!)
  static GengFloat glyphLength (in GengFloat[] points) pure nothrow @trusted @nogc {
    GengFloat res = 0.0;
    if (points.length >= 4) {
      // don't want to bring std.algo here
      GengFloat px = points.ptr[0], py = points.ptr[1];
      foreach (immutable idx; 2..points.length/2) {
        immutable cx = points.ptr[idx*2+0], cy = points.ptr[idx*2+1];
        res += distance(px, py, cx, cy);
        px = cx;
        py = cy;
      }
    }
    return res;
  }

  static void resample (ref GengPatternPoints ptres, in GengFloat[] points) pure @trusted nothrow @nogc {
    assert(points.length >= 4);
    immutable GengFloat I = glyphLength(points)/(NormalizedPoints-1); // interval length
    GengFloat D = 0.0;
    GengFloat prx = points.ptr[0];
    GengFloat pry = points.ptr[1];
    // add first point as-is
    ptres.ptr[0] = prx;
    ptres.ptr[1] = pry;
    usize ptpos = 2, oppos = 2;
    while (oppos < points.length && points.length-oppos >= 2) {
      immutable GengFloat cx = points.ptr[oppos], cy = points.ptr[oppos+1];
      immutable d = distance(prx, pry, cx, cy);
      if (D+d >= I) {
        immutable dd = (I-D)/d;
        immutable qx = prx+dd*(cx-prx);
        immutable qy = pry+dd*(cy-pry);
        assert(ptpos < NormalizedPoints*2);
        ptres.ptr[ptpos++] = qx;
        ptres.ptr[ptpos++] = qy;
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
      ptres.ptr[ptpos++] = points[$-2];
      ptres.ptr[ptpos++] = points[$-1];
    }
    assert(ptpos == NormalizedPoints*2);
  }

  // stroke is not required to be centered, but it must be resampled
  static void vectorize (ref GengPatternPoints vres, in ref GengPatternPoints ptx, bool orientationSensitive) pure nothrow @trusted @nogc {
    import std.math : atan2, cos, sin, floor, sqrt, PI;
    GengPatternPoints pts = void;
    GengFloat cx = 0, cy = 0;
    // center it
    foreach (immutable idx; 0..NormalizedPoints) {
      cx += ptx.ptr[idx*2+0];
      cy += ptx.ptr[idx*2+1];
    }
    cx /= NormalizedPoints;
    cy /= NormalizedPoints;
    foreach (immutable idx; 0..NormalizedPoints) {
      pts.ptr[idx*2+0] = ptx.ptr[idx*2+0]-cx;
      pts.ptr[idx*2+1] = ptx.ptr[idx*2+1]-cy;
    }
    immutable GengFloat indAngle = atan2(pts.ptr[1], pts.ptr[0]); // always must be done for centered stroke
    GengFloat delta = indAngle;
    if (orientationSensitive) {
      immutable baseOrientation = (PI/4.0)*floor((indAngle+PI/8.0)/(PI/4.0));
      delta = baseOrientation-indAngle;
    }
    immutable GengFloat cosd = cos(delta);
    immutable GengFloat sind = sin(delta);
    GengFloat sum = 0;
    foreach (immutable idx; 0..NormalizedPoints) {
      immutable nx = pts.ptr[idx*2+0]*cosd-pts.ptr[idx*2+1]*sind;
      immutable ny = pts.ptr[idx*2+1]*cosd+pts.ptr[idx*2+0]*sind;
      vres.ptr[idx*2+0] = nx;
      vres.ptr[idx*2+1] = ny;
      sum += nx*nx+ny*ny;
    }
    immutable GengFloat magnitude = sqrt(sum);
    foreach (ref GengFloat v; vres[]) v /= magnitude;
  }

  static void buildNormPoints (out GengPatternPoints vres, in GengFloat[] points, bool orientationSensitive) pure nothrow @safe @nogc {
    assert(points.length >= 4);
    GengPatternPoints tmp = void;
    resample(tmp, points);
    vectorize(vres, tmp, orientationSensitive);
  }

public:
  // find matching gesture for this one
  // outscore is NaN if match wasn't found
  const(PTGlyph) findMatch (const(PTGlyph)[] list, GengFloat* outscore=null) const nothrow @trusted @nogc {
    GengFloat bestScore = -GengFloat.infinity;
    PTGlyph res = null;
    if (outscore !is null) *outscore = GengFloat.nan;
    if (valid) {
      // build normalized `this` glyph in pts
      GengPatternPoints pts = patpoints[];
      if (!mNormalized) buildNormPoints(pts, points, mOriented);
      GengPatternPoints gspts = void;
      foreach (const PTGlyph gs; list) {
        if (gs is null || !gs.valid) continue;
        gspts = gs.patpoints[];
        if (!gs.mNormalized) buildNormPoints(gspts, gs.points, gs.mOriented);
        GengFloat score = match(gspts, pts);
        //{ import core.stdc.stdio; printf("tested: '%.*s'; score=%f\n", cast(int)gs.mName.length, gs.mName.ptr, cast(double)score); }
        if (score >= MinMatchScore && score > bestScore) {
          bestScore = score;
          res = cast(PTGlyph)gs; // sorry
        }
      }
    }
    if (res !is null && outscore !is null) *outscore = bestScore;
    return res;
  }

private:
  static void wrXNum (VFile fl, usize n) {
    if (n < 254) {
      fl.writeNum!ubyte(cast(ubyte)n);
    } else {
      static if (n.sizeof == 8) {
        fl.writeNum!ubyte(254);
        fl.writeNum!ulong(n);
      } else {
        fl.writeNum!ubyte(255);
        fl.writeNum!uint(cast(uint)n);
      }
    }
  }

  static usize rdXNum (VFile fl) {
    ubyte v = fl.readNum!ubyte;
    if (v < 254) return cast(usize)v;
    if (v == 254) {
      ulong nv = fl.readNum!ulong;
      if (nv > usize.max) throw new Exception("number too big");
      return cast(usize)nv;
    } else {
      assert(v == 255);
      return cast(usize)fl.readNum!uint;
    }
  }

public:
  void save (VFile fl) const {
    // name
    wrXNum(fl, mName.length);
    fl.rawWriteExact(mName);
    // "oriented" flag
    fl.writeNum!ubyte(mOriented ? 1 : 0);
    // normalized points
    if (mNormalized) {
      static assert(NormalizedPoints > 1 && NormalizedPoints < 254);
      fl.writeNum!ubyte(NormalizedPoints);
      foreach (immutable pt; patpoints[]) fl.writeNum!float(cast(float)pt);
    }
    // points
    wrXNum(fl, points.length);
    foreach (immutable v; points) fl.writeNum!float(cast(float)v);
  }

  static PTGlyph loadNew (VFile fl, ubyte ver=2) {
    GengFloat rdFloat () {
      float fv = fl.readNum!float;
      if (fv != fv) throw new Exception("invalid floating number"); // nan check
      return cast(GengFloat)fv;
    }

    if (ver == 0 || ver == 1) {
      // name
      auto len = fl.readNum!uint();
      if (len > 1024) throw new Exception("glyph name too long");
      auto res = new PTGlyph();
      if (len > 0) {
        auto buf = new char[](len);
        fl.rawReadExact(buf);
        res.mName = cast(string)buf; // it is safe to cast here
      }
      // template
      static if (NormalizedPoints == 16) {
        foreach (ref pt; res.patpoints[]) pt = rdFloat();
      } else {
        // load and resample
        GengFloat[] opts;
        scope(exit) delete opts;
        opts.reserve(16*2);
        normBlkAttr(opts);
        foreach (immutable pidx; 0..nplen*2) opts ~= rdFloat();
        resample(res.patpoints, opts);
      }
      res.mNormalized = true;
      res.mOriented = true;
      if (ver == 1) res.mOriented = (fl.readNum!ubyte != 0);
      return res;
    } else if (ver == 2) {
      // name
      auto nlen = rdXNum(fl);
      if (nlen > int.max/4) throw new Exception("glyph name too long");
      auto res = new PTGlyph();
      if (nlen) {
        auto nbuf = new char[](nlen);
        fl.rawReadExact(nbuf);
        res.mName = cast(string)nbuf; // it is safe to cast here
      }
      // "oriented" flag
      res.mOriented = (fl.readNum!ubyte != 0);
      // normalized points
      auto nplen = rdXNum(fl);
      if (nplen != 0) {
        if (nplen < 3 || nplen > ushort.max) throw new Exception("invalid number of resampled points");
        if (nplen != NormalizedPoints) {
          // load and resample -- this is all we can do
          GengFloat[] opts;
          scope(exit) delete opts;
          opts.reserve(nplen*2);
          normBlkAttr(opts);
          foreach (immutable pidx; 0..nplen*2) opts ~= rdFloat();
          resample(res.patpoints, opts);
        } else {
          // direct loading
          foreach (ref GengFloat fv; res.patpoints[]) fv = rdFloat();
        }
        res.mNormalized = true;
      }
      // original points
      auto plen = rdXNum(fl);
      if (plen) {
        if (plen%2 != 0) throw new Exception("invalid number of points");
        res.points.reserve(plen);
        normBlkAttr(res.points);
        foreach (immutable c; 0..plen) res.points ~= rdFloat();
      }
      return res;
    } else {
      assert(0, "wtf?!");
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
public void gstLibLoadEx (VFile fl, scope void delegate (PTGlyph) appendGlyph) {
  PTGlyph[] res;
  char[8] sign;
  fl.rawReadExact(sign[]);
  if (sign[0..$-1] != "K8PTRDB") throw new Exception("invalid gesture library signature");
  ubyte ver = cast(ubyte)sign[$-1];
  if (ver < '0' || ver > '9') throw new Exception("invalid gesture library signature");
  ver -= '0';
  if (ver > 2) throw new Exception("invalid gesture library version");
  if (ver == 0 || ver == 1) {
    // versions 0 and 1
    uint count = fl.readNum!uint;
    if (count > uint.max/8) throw new Exception("too many glyphs");
    foreach (immutable c; 0..count) {
      auto g = PTGlyph.loadNew(fl, ver);
      if (appendGlyph !is null) appendGlyph(g);
    }
  } else {
    // version 2
    while (fl.tell < fl.size) {
      auto g = PTGlyph.loadNew(fl, ver);
      if (appendGlyph !is null) appendGlyph(g);
    }
  }
}


public PTGlyph[] gstLibLoad (VFile fl) {
  PTGlyph[] res;
  fl.gstLibLoadEx(delegate (PTGlyph g) { res ~= g; });
  return res;
}


// ////////////////////////////////////////////////////////////////////////// //
// return `null` from `nextGlyph` to indicate EOF
public void gstLibSaveEx (VFile fl, scope const(PTGlyph) delegate () nextGlyph) {
  fl.rawWriteExact("K8PTRDB2");
  if (nextGlyph !is null) {
    for (;;) {
      auto g = nextGlyph();
      if (g is null) break;
      g.save(fl);
    }
  }
}


public void gstLibSave (VFile fl, const(PTGlyph)[] list) {
  usize pos = 0;
  fl.gstLibSaveEx(delegate () => (pos < list.length ? list[pos++] : null));
}
