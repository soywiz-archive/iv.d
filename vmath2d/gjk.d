/* Gilbert-Johnson-Keerthi intersection algorithm with Expanding Polytope Algorithm
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
module iv.vmath2d.gjk;

import iv.alice;
import iv.vmath2d;

version = vm2d_debug_gjk_warnings;
//version = vm2d_debug_save_minkowski_points;
//version = vm2d_debug_count_iterations;

version(vm2d_debug_count_iterations) int gjkIterationCount, epaIterationCount;


// ////////////////////////////////////////////////////////////////////////// //
/* GJK object should support:
 *   Vec2 centroid
 *   Vec2 support (Vec2 dir) -- in world space
 *   bool inside (Vec2 pt) -- is point inside body?
 *
 * for polyhedra:
 *
 * // dumb O(n) support function, just brute force check all points
 * vec2 support() (in auto ref vec2 dir) const {
 *   VT furthestPoint = verts[0];
 *   auto maxDot = furthestPoint.dot(dir);
 *   foreach (const ref v; verts[1..$]) {
 *     auto d = v.dot(dir);
 *     if (d > maxDot) {
 *       maxDot = d;
 *       furthestPoint = v;
 *     }
 *   }
 *   return furthestPoint;
 * }
 */


// ////////////////////////////////////////////////////////////////////////// //
/// check if two convex shapes are colliding. can optionally return separating vector in `sepmove`.
public bool gjkcollide(CT, VT) (auto ref CT body0, auto ref CT body1, VT* sepmove=null) if (IsGoodVertexStorage!(CT, VT)) {
  VT sdir = body1.centroid-body0.centroid; // initial search direction
  if (sdir.isZero) sdir = VT(1, 0); // use arbitrary normal if initial direction is zero
  VT[3] spx = void; // simplex; [0] is most recently added, [2] is oldest
  spx.ptr[2] = getSupportPoint(body0, body1, sdir);
  if (spx.ptr[2].dot(sdir) <= 0) return false; // past the origin
  sdir = -sdir; // change search direction
  int spxidx = 1;
  version(vm2d_debug_count_iterations) gjkIterationCount = 0;
  for (;;) {
    version(vm2d_debug_count_iterations) ++gjkIterationCount;
    spx.ptr[spxidx] = getSupportPoint(body0, body1, sdir);
    if (spx.ptr[spxidx].dot(sdir) <= 0) return false; // past the origin
    if (checkSimplex(sdir, spx[spxidx..$])) {
      if (sepmove !is null) *sepmove = EPA(body0, body1, spx[spxidx..$]);
      return true;
    }
    spxidx = 0;
  }
  return false;
}


// ////////////////////////////////////////////////////////////////////////// //
/// return distance between two convex shapes, and separation normal
/// negative distance means that shapes are overlapping, and zero distance means touching (and ops are invalid)
public auto gjkdistance(CT, VT) (auto ref CT body0, auto ref CT body1, VT* op0=null, VT* op1=null, VT* sepnorm=null) if (IsGoodVertexStorage!(CT, VT)) {
  static VT segClosestToOrigin() (in auto ref VT segp0, in auto ref VT segp1) {
    immutable oseg = segp1-segp0;
    immutable ab2 = oseg.dot(oseg);
    immutable apab = (-segp0).dot(oseg);
    if (ab2 <= EPSILON!(VT.Float)) return segp0;
    VT.Float t = apab/ab2;
    if (t < 0) t = 0; else if (t > 1) t = 1;
    return segp0+oseg*t;
  }

  enum GetSupport(string smpx) =
    smpx~"p0 = body0.support(d);\n"~
    smpx~"p1 = body1.support(-d);\n"~
    smpx~" = "~smpx~"p0-"~smpx~"p1;";

  if (sepnorm !is null) *sepnorm = VT(0, 0);
  if (op0 !is null) *op0 = VT(0, 0);
  if (op1 !is null) *op1 = VT(0, 0);

  VT a, b, c; // simplex
  VT ap0, bp0, cp0; // simplex support points, needed for closest points calculation
  VT ap1, bp1, cp1; // simplex support points, needed for closest points calculation
  // centroid is centroid, use that fact
  auto d = body1.centroid-body0.centroid;
  // check for a zero direction vector
  if (d.isZero) return cast(VT.Float)-1; // centroids are the same, not separated
  //getSupport(a, ap0, ap1, d);
  mixin(GetSupport!"a");
  d = -d;
  mixin(GetSupport!"b");
  d = segClosestToOrigin(b, a);
  version(vm2d_debug_count_iterations) gjkIterationCount = 0;
  foreach (immutable iter; 0..32) {
    if (d.lengthSquared <= EPSILON!(VT.Float)*EPSILON!(VT.Float)) return cast(VT.Float)-1; // if the closest point is the origin, not separated
    version(vm2d_debug_count_iterations) ++gjkIterationCount;
    d = -d;
    mixin(GetSupport!"c");
    // is simplex triangle contains origin?
    immutable sa = a.cross(b);
    if (sa*b.cross(c) > 0 && sa*c.cross(a) > 0) return cast(VT.Float)-1; // yes, not separated
    if (c.dot(d)-a.dot(d) < EPSILON!(VT.Float)*EPSILON!(VT.Float)) break; // new point is not far enough, we found her!
    auto p0 = segClosestToOrigin(a, c);
    auto p1 = segClosestToOrigin(c, b);
    immutable p0sqlen = p0.lengthSquared;
    immutable p1sqlen = p1.lengthSquared;
    if (p0sqlen <= EPSILON!(VT.Float)*EPSILON!(VT.Float) || p1sqlen <= EPSILON!(VT.Float)*EPSILON!(VT.Float)) {
      // origin is very close, but not exactly on edge; assume zero distance (special case)
      if (sepnorm !is null) *sepnorm = d.normalized;
      return cast(VT.Float)0;
    }
    if (p0sqlen < p1sqlen) { b = c; bp0 = cp0; bp1 = cp1; d = p0; } else { a = c; ap0 = cp0; ap1 = cp1; d = p1; }
  }
  // either out of iterations, or new point was not far enough
  d.normalize;
  auto dist = -c.dot(d);
  // get closest points
  if (op0 !is null || op1 !is null) {
    auto l = b-a;
    if (l.isZero) {
      if (op0 !is null) *op0 = ap0;
      if (op1 !is null) *op1 = ap1;
    } else {
      immutable ll = l.dot(l);
      immutable l2 = -l.dot(a)/ll;
      immutable l1 = cast(VT.Float)1-l2;
      if (l1 < 0) {
        if (op0 !is null) *op0 = bp0;
        if (op1 !is null) *op1 = bp1;
      } else if (l2 < 0) {
        if (op0 !is null) *op0 = ap0;
        if (op1 !is null) *op1 = ap1;
      } else {
        if (op0 !is null) *op0 = ap0*l1+bp0*l2;
        if (op1 !is null) *op1 = ap1*l1+bp1*l2;
      }
    }
  }
  if (dist < 0) { d = -d; dist = -dist; }
  if (sepnorm !is null) *sepnorm = d;
  return dist;
}


// ////////////////////////////////////////////////////////////////////////// //
// return the Minkowski sum point (ok, something *like* it, but not Minkowski difference yet ;-)
private VT getSupportPoint(CT, VT) (ref CT body0, ref CT body1, in ref VT sdir) {
  pragma(inline, true);
  return body0.support(sdir)-body1.support(-sdir);
}


// check if simplex contains origin, update sdir, and possibly update simplex
private bool checkSimplex(VT) (ref VT sdir, VT[] spx) {
  assert(spx.length == 2 || spx.length == 3);
  if (spx.length == 3) {
    // simplex has 3 elements
    auto a = spx.ptr[0]; // last added point
    auto ao = -a; // to origin
    // get the edges
    auto ab = spx.ptr[1]-a;
    auto ac = spx.ptr[2]-a;
    // get the edge normals
    auto abn = ac.tripleProduct(ab, ab);
    auto acn = ab.tripleProduct(ac, ac);
    // see where the origin is at
    auto acloc = acn.dot(ao);
    if (acloc >= 0) {
      // remove middle element
      spx.ptr[1] = spx.ptr[0];
      sdir = acn;
    } else {
      auto abloc = abn.dot(ao);
      if (abloc < 0) return true; // intersection
      // remove last element
      spx.ptr[2] = spx.ptr[1];
      spx.ptr[1] = spx.ptr[0];
      sdir = abn;
    }
  } else {
    // simplex has 2 elements
    auto a = spx.ptr[0]; // last added point
    auto ao = -a; // to origin
    auto ab = spx.ptr[1]-a;
    sdir = ab.tripleProduct(ao, ab);
    if (sdir.lengthSquared <= EPSILON!(VT.Float)*EPSILON!(VT.Float)) sdir = sdir.rperp; // bad direction, use any normal
  }
  return false;
}


// ////////////////////////////////////////////////////////////////////////// //
// Expanding Polytope Algorithm
// find minimum translation vector to resolve collision
// using the final simplex obtained with the GJK algorithm
private VT EPA(CT, VT) (ref CT body0, ref CT body1, const(VT)[] spx...) {
  enum MaxIterations = 128;
  enum MaxFaces = MaxIterations*3;
  assert(MaxIterations >= body0.length*body1.length);

  static struct SxEdge {
    VT p0, p1;
    VT normal;
    VT.Float dist;
    usize nextFree; // will be used to store my temp index too

    @disable this (this);

  nothrow @safe @nogc:
    void calcNormDist (int winding) {
      pragma(inline, true);
      mixin(ImportCoreMath!(VT.Float, "fabs"));
      normal = p1-p0;
      if (winding < 0) normal = normal.perp; else normal = normal.rperp;
      normal.normalize();
      dist = fabs(p0.dot(normal));
    }

    void set (in ref VT ap0, in ref VT ap1, int winding) {
      p0 = ap0;
      p1 = ap1;
      calcNormDist(winding);
    }
  }

  // as this cannot be called recursive, we can use thread-local static here
  // use binary heap to store faces
  static SxEdge[MaxFaces+2] faces = void;
  static usize[MaxFaces+2] faceMap = void;

  usize freeFaceIdx = usize.max;
  usize facesUsed = 0;
  usize faceCount = 0;
  int winding = 0;

  void heapify (usize root) {
    for (;;) {
      auto smallest = 2*root+1; // left child
      if (smallest >= faceCount) break; // anyway
      immutable right = smallest+1; // right child
      if (!(faces.ptr[faceMap.ptr[smallest]].dist < faces.ptr[faceMap.ptr[root]].dist)) smallest = root;
      if (right < faceCount && faces.ptr[faceMap.ptr[right]].dist < faces.ptr[faceMap.ptr[smallest]].dist) smallest = right;
      if (smallest == root) break;
      // swap
      auto tmp = faceMap.ptr[root];
      faceMap.ptr[root] = faceMap.ptr[smallest];
      faceMap.ptr[smallest] = tmp;
      root = smallest;
    }
  }

  void insertFace (in ref VT p0, in ref VT p1) {
    if (faceCount == faces.length) assert(0, "too many elements in heap");
    auto i = faceCount;
    usize ffidx = freeFaceIdx; // allocated face index in `faces[]`
    if (ffidx != usize.max) {
      // had free face in free list, fix free list
      freeFaceIdx = faces.ptr[ffidx].nextFree;
    } else {
      // no free faces, use next unallocated
      ffidx = facesUsed++;
    }
    assert(ffidx < faces.length);
    ++faceCount;
    faces.ptr[ffidx].set(p0, p1, winding);
    immutable nfdist = faces.ptr[ffidx].dist;
    // fix heap, and find place for new face
    while (i != 0) {
      auto par = (i-1)/2; // parent
      if (!(nfdist < faces.ptr[faceMap.ptr[par]].dist)) break;
      faceMap.ptr[i] = faceMap.ptr[par];
      i = par;
    }
    faceMap.ptr[i] = ffidx;
  }

  // remove face from heap, but don't add it to free list yet
  SxEdge* popSmallestFace () {
    assert(faceCount > 0);
    usize fidx = faceMap.ptr[0];
    SxEdge* res = faces.ptr+fidx;
    res.nextFree = fidx; // store face index; it will be used in `freeFace()`
    // remove from heap (but don't add to free list yet)
    faceMap.ptr[0] = faceMap.ptr[--faceCount];
    heapify(0);
    return res;
  }

  // add face to free list
  void freeFace (SxEdge* e) {
    assert(e !is null);
    auto fidx = e.nextFree;
    e.nextFree = freeFaceIdx;
    freeFaceIdx = fidx;
  }

  // compute the winding
  VT prevv = spx[$-1];
  foreach (const ref v; spx[]) {
    auto cp = prevv.cross(v);
    if (cp > 0) { winding = 1; break; }
    if (cp < 0) { winding = -1; break; }
    prevv = v;
  }

  // build the initial edge queue
  prevv = spx[$-1];
  foreach (const ref v; spx[]) {
    insertFace(prevv, v);
    prevv = v;
  }

  SxEdge* e;
  VT p;
  version(vm2d_debug_count_iterations) epaIterationCount = 0;
  foreach (immutable i; 0..body0.length*body1.length) {
    version(vm2d_debug_count_iterations) ++epaIterationCount;
    e = popSmallestFace();
    p = getSupportPoint(body0, body1, e.normal);
    immutable proj = p.dot(e.normal);
    if (proj-e.dist < EPSILON!(VT.Float)) return e.normal*proj;
    insertFace(e.p0, p);
    insertFace(p, e.p1);
    freeFace(e);
  }
  assert(e !is null); // just in case
  version(vm2d_debug_gjk_warnings) { import core.stdc.stdio; stderr.fprintf("EPA: out of iterations!\n"); }
  return e.normal*p.dot(e.normal);
}


// ////////////////////////////////////////////////////////////////////////// //
public static struct Raycast(VT) {
  VT p = VT.Invalid, n = VT.Invalid; // point and normal
  VT.Float dist;
  @property bool valid () const nothrow @safe @nogc { pragma(inline, true); return n.isFinite; }
}


// ////////////////////////////////////////////////////////////////////////// //
// see Gino van den Bergen's "Ray Casting against General Convex Objects with Application to Continuous Collision Detection" paper
// http://www.dtecta.com/papers/jgt04raycast.pdf
public Raycast!VT gjkraycast(bool checkRayStart=true, int maxiters=32, double distEps=0.0001, VT, CT) (auto ref CT abody, in auto ref VT rayO, in auto ref VT rayD) if (IsGoodVertexStorage!(CT, VT)) {
  Raycast!VT res;

  VT.Float lambda = 0;
  VT.Float maxlen = rayD.length;
  bool isseg = (maxlen > 1);

  immutable VT start = rayO;
  VT r = rayD;
  if (maxlen != 1) r.normalize;

  static if (checkRayStart) {
    if (abody.inside(start)) return res; // the start point is inside the body, oops
  }

  VT n; // normal at the hit point
  VT x = start; // current closest point on the ray
  VT a = VT.Invalid, b = VT.Invalid; // simplex
  VT v = x-abody.centroid;
  VT.Float distsq = VT.Float.infinity;
  int itersLeft = maxiters;

  version(vm2d_debug_count_iterations) gjkIterationCount = 0;
  while (itersLeft > 0) {
    version(vm2d_debug_count_iterations) ++gjkIterationCount;
    VT p = abody.support(v);
    VT w = x-p;
    VT.Float dvw = v.dot(w);
    if (dvw > 0) {
      VT.Float dvr = v.dot(r);
      if (dvr >= -(EPSILON!(VT.Float)*EPSILON!(VT.Float))) return res;
      lambda = lambda-dvw/dvr;
      if (isseg && lambda > maxlen) return res; // we don't really know vk for warm start in this case
      x = start+r*lambda;
      n = v;
    }
    // reduce simplex
    if (a.valid) {
      if (b.valid) {
        VT p1 = x.projectToSeg(a, p);
        VT p2 = x.projectToSeg(p, b);
        if (p1.distanceSquared(x) < p2.distanceSquared(x)) {
          b = p;
          distsq = p1.distanceSquared(x);
        } else {
          a = p;
          distsq = p2.distanceSquared(x);
        }
        VT ab = b-a;
        VT ax = x-a;
        v = ab.tripleProduct(ax, ab);
      } else {
        b = p;
        VT ab = b-a;
        VT ax = x-a;
        v = ab.tripleProduct(ax, ab);
      }
    } else {
      a = p;
      v = -v;
    }
    if (distsq <= cast(VT.Float)distEps) break;
    --itersLeft;
  }

  if (itersLeft < 1) return res; // alas, out of iterations

  // result
  res.p = x;
  res.n = n.normalized;
  res.dist = lambda;
  return res;
}


// ////////////////////////////////////////////////////////////////////////// //
// see Gino van den Bergen's "Ray Casting against General Convex Objects with Application to Continuous Collision Detection" paper
// http://www.dtecta.com/papers/jgt04raycast.pdf
// this inflates *bbody*, and traces ray from *abody* origin to *bbody*. it is IMPORTANT! ;-)
// if result is valid, body a can move by `res.p-abody.origin` before hit
public Raycast!VT gjksweep(bool checkRayStart=true, int maxiters=32, double distEps=0.0001, VT, CT) (auto ref CT abody, auto ref CT bbody, in auto ref VT lvelA, in auto ref VT lvelB) {
  Raycast!VT res;
  version(vm2d_debug_save_minkowski_points)mink = null;

  immutable VT start = abody.centroid; // trace from abody
  if (start.equals(bbody.centroid)) return res; // obviously collided
  static if (checkRayStart) {
    if (bbody.inside(start)) return res; // the start point is inside the destination body, oops
  }

  VT r = lvelA-lvelB; // relative motion
  VT.Float maxlen = r.length;
  r.normalize;

  VT x = start; // current closest point on the ray
  VT.Float lambda = 0;
  VT n; // normal at the hit point
  VT a = VT.Invalid, b = VT.Invalid; // simplex
  VT v = x-bbody.centroid;
  VT.Float distsq = VT.Float.infinity;
  int itersLeft = maxiters;

  version(vm2d_debug_count_iterations) gjkIterationCount = 0;
  while (itersLeft > 0) {
    version(vm2d_debug_count_iterations) ++gjkIterationCount;
    VT p = bbody.support(v)-(abody.support(-v)-abody.centroid);
    VT w = x-p;
    version(vm2d_debug_save_minkowski_points)mink ~= w;
    VT.Float dvw = v.dot(w);
    if (dvw > 0) {
      VT.Float dvr = v.dot(r);
      if (dvr >= -(EPSILON!(VT.Float)*EPSILON!(VT.Float))) return res;
      lambda = lambda-dvw/dvr;
      if (lambda > maxlen) return res; // we don't really know vk for warm start in this case
      x = start+r*lambda;
      n = v;
    }
    // reduce simplex
    if (a.valid) {
      if (b.valid) {
        VT p1 = x.projectToSeg(a, p);
        VT p2 = x.projectToSeg(p, b);
        if (p1.distanceSquared(x) < p2.distanceSquared(x)) {
          b = p;
          distsq = p1.distanceSquared(x);
        } else {
          a = p;
          distsq = p2.distanceSquared(x);
        }
        VT ab = b-a;
        VT ax = x-a;
        v = ab.tripleProduct(ax, ab);
      } else {
        b = p;
        VT ab = b-a;
        VT ax = x-a;
        v = ab.tripleProduct(ax, ab);
      }
    } else {
      a = p;
      v = -v;
    }
    if (distsq <= cast(VT.Float)distEps) break;
    --itersLeft;
  }

  if (itersLeft < 1) return res; // alas, out of iterations

  // result
  res.p = x;
  res.n = n.normalized;
  res.dist = lambda;
  return res;
}
