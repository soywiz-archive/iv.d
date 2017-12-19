/*
 * The $P Point-Cloud Recognizer
 *
 *  Radu-Daniel Vatavu, Ph.D.
 *  University Stefan cel Mare of Suceava
 *  Suceava 720229, Romania
 *  vatavu@eed.usv.ro
 *
 *  Lisa Anthony, Ph.D.
 *      UMBC
 *      Information Systems Department
 *      1000 Hilltop Circle
 *      Baltimore, MD 21250
 *      lanthony@umbc.edu
 *
 *  Jacob O. Wobbrock, Ph.D.
 *  The Information School
 *  University of Washington
 *  Seattle, WA 98195-2840
 *  wobbrock@uw.edu
 *
 * The academic publication for the $P recognizer, and what should be
 * used to cite it, is:
 *
 *  Vatavu, R.-D., Anthony, L. and Wobbrock, J.O. (2012).
 *    Gestures as point clouds: A $P recognizer for user interface
 *    prototypes. Proceedings of the ACM Int'l Conference on
 *    Multimodal Interfaces (ICMI '12). Santa Monica, California
 *    (October 22-26, 2012). New York: ACM Press, pp. 273-280.
 *
 * This software is distributed under the "New BSD License" agreement:
 *
 * Copyright (c) 2012, Radu-Daniel Vatavu, Lisa Anthony, and
 * Jacob O. Wobbrock. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *    * Redistributions of source code must retain the above copyright
 *      notice, this list of conditions and the following disclaimer.
 *    * Redistributions in binary form must reproduce the above copyright
 *      notice, this list of conditions and the following disclaimer in the
 *      documentation and/or other materials provided with the distribution.
 *    * Neither the names of the University Stefan cel Mare of Suceava,
 *  University of Washington, nor UMBC, nor the names of its contributors
 *  may be used to endorse or promote products derived from this software
 *  without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
 * IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Radu-Daniel Vatavu OR Lisa Anthony
 * OR Jacob O. Wobbrock BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
 * OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */
module iv.pdollar0;

import iv.alice;
import iv.cmdcon;
import iv.vfs;


// ////////////////////////////////////////////////////////////////////////// //
alias DPFloat = float;


// ////////////////////////////////////////////////////////////////////////// //
struct DPResult {
  string name;
  DPFloat score;
  @property bool valid () const nothrow @safe @nogc { pragma(inline, true); import std.math : isNaN; return !score.isNaN; }
}


// ////////////////////////////////////////////////////////////////////////// //
struct DPPoint {
  DPFloat x=0, y=0;
  uint id; // stroke ID to which this point belongs (1,2,...)
}


final class DPPointCloud {
public:
  enum NumPoints = 32;

public:
  string mName;
  DPPoint[NumPoints] mPoints = DPPoint(0, 0, 0);

private:
  this () {}

public:
  this (string aname, const(DPPoint)[] pts...) nothrow @nogc {
    mName = aname;
    resample(mPoints, pts);
    scale(mPoints);
    translateTo(mPoints, DPPoint(0, 0));
  }

  final @property const(DPPoint)[] points () const pure nothrow @safe @nogc { pragma(inline, true); return mPoints[]; }
  final @property string name () const pure nothrow @safe @nogc { pragma(inline, true); return mName; }

  void save (VFile fl) const {
    string nn = mName;
    if (nn.length > 65535) nn = nn[0..65535]; // fuck you
    if (nn.length > 254) {
      fl.writeNum!ubyte(255);
      fl.writeNum!ushort(cast(ushort)nn.length);
    } else {
      fl.writeNum!ubyte(cast(ubyte)nn.length);
    }
    fl.rawWriteExact(nn);
    fl.writeNum!ubyte(NumPoints);
    foreach (const ref DPPoint pt; mPoints[]) {
      fl.writeNum!float(cast(float)pt.x);
      fl.writeNum!float(cast(float)pt.y);
      fl.writeNum!uint(pt.id);
    }
  }

  void load (VFile fl) {
    char[] nn;
    ubyte len = fl.readNum!ubyte;
    if (len == 255) {
      ushort xlen = fl.readNum!ushort;
      nn.length = xlen;
    } else {
      nn.length = len;
    }
    fl.rawReadExact(nn);
    mName = cast(string)nn; // it is safe to cast here
    if (fl.readNum!ubyte != NumPoints) throw new Exception("invalid number of points in cloud");
    foreach (ref DPPoint pt; mPoints[]) {
      pt.x = cast(DPFloat)fl.readNum!float;
      pt.y = cast(DPFloat)fl.readNum!float;
      pt.id = fl.readNum!uint;
    }
  }

  static DPPointCloud loadNew (VFile fl) {
    auto res = new DPPointCloud();
    res.load(fl);
    return res;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
final class DPGestureList {
private:
  DPPointCloud[] mGestures;

public:
  this () nothrow @nogc {}

  void clear () {
    delete mGestures;
  }

  final @property const(DPPointCloud)[] gestures () const pure nothrow @safe @nogc { pragma(inline, true); return mGestures; }

  string[] knownGestureNames () {
    string[] res;
    mainloop: foreach (DPPointCloud gst; mGestures) {
      foreach (string s; res) if (s == gst.mName) continue mainloop;
      res ~= gst.mName;
    }
    return res;
  }

  void appendGesture (string aname, const(DPPoint)[] pts...) {
    appendGesture(new DPPointCloud(aname, pts));
  }

  // you can add as many gestures with same name as you want to
  void appendGesture (DPPointCloud gg) {
    import core.memory : GC;
    if (gg is null) return;
    auto optr = mGestures.ptr;
    mGestures ~= gg;
    if (mGestures.ptr !is optr) {
      optr = mGestures.ptr;
      if (optr is GC.addrOf(optr)) GC.setAttr(optr, GC.BlkAttr.NO_INTERIOR);
    }
  }

  // remove *ALL* gestures with the given name
  void removeGesture (const(char)[] name) {
    usize idx = 0;
    while (idx < mGestures.length) {
      if (mGestures[idx].mName == name) {
        foreach (immutable c; idx+1..mGestures.length) mGestures[c-1] = mGestures[c];
        mGestures[$-1] = null;
        mGestures.length -= 1;
        mGestures.assumeSafeAppend;
      } else {
        ++idx;
      }
    }
  }

  // if you have more than one gesture with the same name, keep increasing `idx` to get more, until you'll get `null`
  DPPointCloud findGesture (const(char)[] name, uint idx=0) nothrow @nogc {
    foreach (DPPointCloud g; mGestures) {
      if (g.mName == name) {
        if (idx-- == 0) return g;
      }
    }
    return null;
  }

  DPResult recognize (const(DPPoint)[] origpoints) nothrow @nogc {
    import std.algorithm : max;
    if (origpoints.length < 2) return DPResult.init;
    DPPoint[DPPointCloud.NumPoints] points;
    resample(points, origpoints);
    scale(points);
    translateTo(points, DPPoint(0, 0));
    DPFloat b = DPFloat.infinity;
    int u = -1;
    foreach (immutable idx, DPPointCloud gst; mGestures) {
      auto d = greedyCloudMatch(points, gst);
      if (d < b) {
        b = d; // best (least) distance
        u = cast(int)idx; // point-cloud
      }
    }
    if (u == -1) return DPResult();
    //{ import core.stdc.stdio; printf("b=%f (%f)\n", b, (b-2.0)/-2.0); }
    return (u != -1 ? DPResult(mGestures[u].mName, max((b-2.0)/-2.0, 0.0)) : DPResult.init);
  }

public:
  enum Signature = "DOLP8LB0";

  void save (VFile fl) const {
    fl.rawWriteExact(Signature);
    fl.writeNum!uint(cast(uint)mGestures.length);
    foreach (const DPPointCloud gst; mGestures) gst.save(fl);
  }

  void load (VFile fl) {
    delete mGestures;
    char[Signature.length] sign;
    fl.rawReadExact(sign);
    if (sign[0..$-1] != Signature[0..$-1]) throw new Exception("invalid $P library signature");
    if (sign[$-1] != Signature[$-1]) throw new Exception("invalid $P library version");
    uint count = fl.readNum!uint;
    if (count > uint.max/16) throw new Exception("too many gestures in library");
    mGestures.reserve(count);
    foreach (immutable idx; 0..count) appendGesture(DPPointCloud.loadNew(fl));
  }
}


// ////////////////////////////////////////////////////////////////////////// //
private:

DPFloat greedyCloudMatch(usize n) (in ref DPPoint[n] points, in DPPointCloud P) nothrow @nogc {
  import std.algorithm : min;
  import std.math : floor, pow;
  enum e = cast(DPFloat)0.50;
  int step = cast(int)floor(pow(points.length, 1-e));
  assert(step > 0);
  DPFloat minv = DPFloat.infinity;
  for (int i = 0; i < points.length; i += step) {
    auto d1 = cloudDistance(points, P.mPoints, i);
    auto d2 = cloudDistance(P.mPoints, points, i);
    minv = min(minv, d1, d2);
  }
  return minv;
}


DPFloat cloudDistance(usize n) (in ref DPPoint[n] pts1, in ref DPPoint[n] pts2, int start) nothrow @nogc {
  import std.math : sqrt;
  bool[n] matched = false;
  DPFloat sum = 0;
  int i = start;
  do {
    int index = -1;
    DPFloat minv = DPFloat.infinity;
    foreach (immutable j, bool mtv; matched[]) {
      if (!mtv) {
        auto d = distanceSqr(pts1[i], pts2[j]);
        if (d < minv) { minv = d; index = cast(int)j; }
      }
    }
    assert(index >= 0);
    matched[index] = true;
    DPFloat weight = cast(DPFloat)1-((i-start+cast(int)pts1.length)%cast(int)pts1.length)/cast(DPFloat)pts1.length;
    sum += weight*sqrt(minv);
    i = (i+1)%cast(int)pts1.length;
  } while (i != start);
  return sum;
}


void resample(usize n) (ref DPPoint[n] newpoints, in DPPoint[] points) nothrow @nogc {
  import std.algorithm : max, min;
  import std.math : isNaN;
  assert(n > 0);
  assert(points.length > 1);
  immutable DPFloat I = pathLength(points)/(n-1); // interval length
  DPFloat D = 0;
  uint nppos = 0;
  newpoints[nppos++] = points[0];
  foreach (immutable idx; 1..points.length) {
    if (points[idx].id == points[idx-1].id) {
      auto d = distance(points[idx-1], points[idx]);
      if (D+d >= I) {
        DPPoint firstPoint = points[idx-1];
        while (D+d >= I) {
          // add interpolated point
          DPFloat t = min(max((I-D)/d, cast(DPFloat)0), cast(DPFloat)1);
          if (isNaN(t)) t = cast(DPFloat)0.5;
          newpoints[nppos++] = DPPoint((cast(DPFloat)1-t)*firstPoint.x+t*points[idx].x,
                                       (cast(DPFloat)1-t)*firstPoint.y+t*points[idx].y, points[idx].id);
          // update partial length
          d = D+d-I;
          D = 0;
          firstPoint = newpoints[nppos-1];
        }
        D = d;
      } else {
        D += d;
      }
    }
  }
  if (nppos == n-1) {
    // sometimes we fall a rounding-error short of adding the last point, so add it if so
    newpoints[nppos++] = DPPoint(points[$-1].x, points[$-1].y, points[$-1].id);
  }
  assert(nppos == n);
}


void scale(usize n) (ref DPPoint[n] points) nothrow @nogc {
  import std.algorithm : max, min;
  DPFloat minX = DPFloat.infinity;
  DPFloat minY = DPFloat.infinity;
  DPFloat maxX = -DPFloat.infinity;
  DPFloat maxY = -DPFloat.infinity;
  foreach (ref DPPoint p; points[]) {
    minX = min(minX, p.x);
    minY = min(minY, p.y);
    maxX = max(maxX, p.x);
    maxY = max(maxY, p.y);
  }
  DPFloat size = max(maxX-minX, maxY-minY);
  foreach (ref DPPoint p; points[]) {
    p.x = (p.x-minX)/size;
    p.y = (p.y-minY)/size;
  }
}


// translates points' centroid
void translateTo(usize n) (ref DPPoint[n] points, DPPoint pt) nothrow @nogc {
  auto c = centroid(points);
  foreach (ref DPPoint p; points[]) {
    p.x = p.x+pt.x-c.x;
    p.y = p.y+pt.y-c.y;
  }
}


DPPoint centroid(usize n) (in ref DPPoint[n] points) nothrow @nogc {
  DPFloat x = 0, y = 0;
  foreach (const ref DPPoint p; points[]) {
    x += p.x;
    y += p.y;
  }
  immutable DPFloat pl = cast(DPFloat)1/cast(DPFloat)points.length;
  return DPPoint(x*pl, y*pl);
}


// length traversed by a point path
DPFloat pathLength (const(DPPoint)[] points) nothrow @nogc {
  DPFloat d = 0;
  foreach (immutable idx; 1..points.length) {
    if (points[idx].id == points[idx-1].id) d += distance(points[idx-1], points[idx]);
  }
  return d;
}


// Euclidean distance between two points
DPFloat distance() (in auto ref DPPoint p1, in auto ref DPPoint p2) nothrow @nogc {
  import std.math : sqrt;
  immutable DPFloat dx = p2.x-p1.x;
  immutable DPFloat dy = p2.y-p1.y;
  return cast(DPFloat)sqrt(dx*dx+dy*dy);
}


// Euclidean distance between two points
DPFloat distanceSqr() (in auto ref DPPoint p1, in auto ref DPPoint p2) nothrow @nogc {
  immutable DPFloat dx = p2.x-p1.x;
  immutable DPFloat dy = p2.y-p1.y;
  return cast(DPFloat)(dx*dx+dy*dy);
}
