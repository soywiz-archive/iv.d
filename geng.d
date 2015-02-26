/* coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * Understanding is not required. Only obedience.
 *
 *                   INVISIBLE VECTOR PUBLIC LICENSE
 *                       Version 0, August 2014
 *
 * Copyright (C) 2014 Ketmar Dark <ketmar@ketmar.no-ip.org>
 *
 * Everyone is permitted to copy and distribute verbatim or modified
 * copies of this license document, and changing it is allowed as long
 * as the name is changed.
 *
 *                   INVISIBLE VECTOR PUBLIC LICENSE
 *   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
 *
 * 0. You may not use this software in either source or binary form, any
 *    software derived from this software, any library which uses either
 *    this software or code derived from this software in any other
 *    software which uses Windows API, either directly or indirectly
 *    via any chain of libraries.
 *
 * 1. You may not use this software in either source or binary form, any
 *    software derived from this software, any library which uses either
 *    this software or code derived from this software in any other
 *    software which uses MacOS X API, either directly or indirectly via
 *    any chain of libraries.
 *
 * 2. You may not use this software in either source or binary form, any
 *    software derived from this software, any library which uses either
 *    this software or code derived from this software in any other
 *    software on the territory of Russian Federation, either directly or
 *    indirectly via any chain of libraries.
 *
 * 3. Redistributions of this software in either source or binary form must
 *    retain this list of conditions and the following disclaimer.
 *
 * 4. Otherwise, you are allowed to use this software in any way that will
 *    not violate paragraphs 0, 1, 2 and 3 of this license.
 *
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 * Authors: Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * License: IVPLv0
 */
/*
 * Protractor recognizer
 */
module iv.geng is aliced;
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
  string mName;

public:
  this () @safe nothrow @nogc {}
  this (string aname) @safe nothrow @nogc { mName = aname; }
  this (string aname, in GengPatternPoints apat) @safe nothrow @nogc {
    mName = aname;
    patpoints[] = apat[];
    mNormalized = true;
  }

final:
  @property bool valid () const @safe pure nothrow @nogc { return (mNormalized || points.length >= 4); }
  @property bool normalized () const @safe pure nothrow @nogc { return mNormalized; }

  @property string name () const @safe pure nothrow @nogc { return mName; }
  @property void name (string v) @safe nothrow @nogc { mName = v; }

  usize length () const @safe pure nothrow @nogc { return (mNormalized ? NormalizedPoints : points.length/2); }
  alias opDollar = length;

  auto x (usize idx) const @safe pure nothrow @nogc {
    if (!mNormalized) {
      return (idx*2 < points.length ? points[idx*2] : typeof(points[0]).nan);
    } else {
      return (idx < NormalizedPoints ? patpoints[idx*2] : typeof(points[0]).nan);
    }
  }
  auto y (usize idx) const @safe pure nothrow @nogc {
    if (!mNormalized) {
      return (idx*2 < points.length ? points[idx*2+1] : typeof(points[0]).nan);
    } else {
      return (idx < NormalizedPoints ? patpoints[idx*2+1] : typeof(points[0]).nan);
    }
  }

  auto clear () @safe nothrow @nogc {
    points = null;
    mNormalized = false;
    mName = null;
    return this;
  }

  auto clone () const @safe {
    auto res = new PTGlyph(mName);
    res.mNormalized = mNormalized;
    if (mNormalized) {
      res.patpoints[] = patpoints[];
    } else {
      if (points.length > 0) res.points = points.dup;
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
    points ~= x;
    points ~= y;
    mNormalized = false;
    return this;
  }

  auto normalize () @safe {
    if (!mNormalized) {
      if (points.length < 4) throw new Exception("glyph must have at least two points");
      buildNormPoints(patpoints, points);
      mNormalized = true;
      points.length = 0;
    }
    return this;
  }

  // this: template
  GengFloat match (const(PTGlyph) sample) const @safe pure nothrow @nogc {
    if (sample is null || !sample.valid || !valid) return -GengFloat.infinity;
    if (mNormalized) {
      // this is normalized
      return match(patpoints, sample);
    } else {
      // this is not normalized
      GengPatternPoints v1 = void;
      buildNormPoints(v1, points);
      return match(v1, sample);
    }
  }

private:
  // this: template
  static GengFloat match (in GengPatternPoints tpl, const(PTGlyph) sample) @safe pure nothrow @nogc {
    if (sample is null || !sample.valid) return -GengFloat.infinity;
    if (sample.mNormalized) {
      return match(tpl, sample.patpoints);
    } else {
      GengPatternPoints spts = void;
      buildNormPoints(spts, sample.points);
      return match(tpl, spts);
    }
  }

  static GengFloat match (in GengPatternPoints v0, in GengPatternPoints v1) @safe pure nothrow @nogc {
    return 1.0/optimalCosineDistance(v0, v1);
  }

  static GengFloat optimalCosineDistance (in GengPatternPoints v0, in GengPatternPoints v1) @safe pure nothrow @nogc {
    import std.math : atan, acos, cos, sin;
    GengFloat a = 0.0, b = 0.0;
    foreach (auto idx; 0..NormalizedPoints) {
      a += v0[idx*2+0]*v1[idx*2+0]+v0[idx*2+1]*v1[idx*2+1];
      b += v0[idx*2+0]*v1[idx*2+1]-v0[idx*2+1]*v1[idx*2+0];
    }
    immutable GengFloat angle = atan(b/a);
    return acos(a*cos(angle)+b*sin(angle));
  }

  // glyph length (not point counter!)
  static GengFloat glyphLength (in GengFloat[] points) @safe pure nothrow @nogc {
    GengFloat res = 0.0;
    if (points.length >= 4) {
      // don't want to bring std.algo here
      GengFloat px = points[0], py = points[1];
      foreach (auto idx; 2..points.length/2) {
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
  static void vectorize (out GengPatternPoints vres, in GengPatternPoints ptx, bool orientationSensitive=true)
  @safe pure nothrow @nogc
  {
    import std.math : atan2, cos, sin, floor, sqrt, PI;
    GengPatternPoints pts;
    GengFloat indAngle, delta;
    GengFloat cx = 0.0, cy = 0.0;
    // center it
    foreach (auto idx; 0..NormalizedPoints) {
      cx += ptx[idx*2+0];
      cy += ptx[idx*2+1];
    }
    cx /= NormalizedPoints;
    cy /= NormalizedPoints;
    foreach (auto idx; 0..NormalizedPoints) {
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
    foreach (auto idx; 0..NormalizedPoints) {
      immutable nx = pts[idx*2+0]*cosd-pts[idx*2+1]*sind;
      immutable ny = pts[idx*2+1]*cosd+pts[idx*2+0]*sind;
      vres[idx*2+0] = nx;
      vres[idx*2+1] = ny;
      sum += nx*nx+ny*ny;
    }
    immutable GengFloat magnitude = sqrt(sum);
    foreach (auto idx; 0..NormalizedPoints*2) vres[idx] /= magnitude;
  }

  static void buildNormPoints (out GengPatternPoints vres, in GengFloat[] points, bool orientationSensitive=true)
  @safe pure nothrow @nogc
  {
    assert(points.length >= 4);
    GengPatternPoints tmp = void;
    resample(tmp, points);
    vectorize(vres, tmp);
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
        buildNormPoints(pts, points);
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
import iv.stream;


public void gstLibLoad(R, ST) (auto ref R orng, auto ref ST st)
if (isOutputRange!(R, PTGlyph) && isReadableStream!ST)
{
  auto sign = st.readNum!ulong();
  if (sign != 0x304244525450384BuL) throw new Exception("invalid library signature"); // "K8PTRDB0"
  auto cnt = st.readNum!uint();
  if (cnt > 0x7fff_ffff) throw new Exception("too many glyphs");
  if (cnt == 0) return;
  foreach (auto idx; 0..cnt) {
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
    // template
    GengPatternPoints pts = void;
    foreach (ref pt; pts) {
      pt = st.readNum!float();
      if (pt != pt) throw new Exception("invalid number"); // nan check
    }
    //
    auto g = new PTGlyph(name, pts);
    put(orng, g);
  }
}


public PTGlyph[] gstLibLoad(ST) (auto ref ST st) if (isReadableStream!ST) {
  static struct ORng {
    PTGlyph[] gls;
    void put (PTGlyph g) nothrow { if (g !is null && g.valid) gls ~= g; }
  }
  auto r = ORng();
  gstLibLoad(r, st);
  return (r.gls.length ? r.gls : null);
}


// ////////////////////////////////////////////////////////////////////////// //
public void gstLibSave(ST, R) (auto ref ST st, auto ref R grng)
if (isWriteableStream!ST && isInputRange!R && !isInfinite!R && is(ElementType!R : PTGlyph) &&
    (hasLength!R || isSeekableStream!ST))
{
  st.writeNum!ulong(0x304244525450384BuL); // "K8PTRDB0"
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
      g.buildNormPoints(pts, g.points);
    }
    foreach (immutable pt; pts) st.writeNum!float(cast(float)pt);
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
