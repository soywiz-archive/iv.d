/*
 * coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * Understanding is not required. Only obedience.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 3 of the License ONLY.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */
module iv.vmath2d.vxstore;

import iv.alice;
import iv.vmath2d.math2d;


// ////////////////////////////////////////////////////////////////////////// //
public template IsGoodVertexStorage(T, VT) if ((is(T == struct) || is(T == class)) && IsVectorDim!(VT, 2)) {
  enum IsGoodVertexStorage = is(typeof((inout int=0) {
    T o = T.init;
    VT v = o[0];
    o[0] = v;
    v = o.centroid;
    int len = o.length;
    const(VT)[] vs = o[0..2];
    vs = o[];
    vs = o[1..$];
    // sadly, we can't check for `opIndex()` wrapping here
    o.swap(1, 2);
    // sadly, we can't check for `swap()` wrapping here
    o.remove(1);
    bool ins = o.inside(VT(0, 0));
    ins = o.inside(0, 0);
  }));
}

public template IsGoodVertexStorage(T) if (is(T == struct) || is(T == class)) {
  static import std.traits;
  static if (is(std.traits.Unqual!(typeof(T.init.centroid)))) {
    enum IsGoodVertexStorage = IsGoodVertexStorage!(T, std.traits.Unqual!(typeof(T.init.centroid)));
  } else {
    enum IsGoodVertexStorage = false;
  }
}

public template VertexStorageVT(T) if (IsGoodVertexStorage!T) {
  static import std.traits;
  alias VertexStorageVT = std.traits.Unqual!(typeof(T.init.centroid));
}

//static assert(IsGoodVertexStorage!(VertexStorage!vec2));
//pragma(msg, VertexStorageVT!(VertexStorage!vec2));


// ////////////////////////////////////////////////////////////////////////// //
public enum VertexStorageCommon = q{
  void moveBy() (VT.Float dx, VT.Float dy) { moveBy(VT(dx, dy)); }

  void moveTo() (in auto ref VT pos) { moveBy(pos-centroid); }
  void moveTo() (VT.Float x, VT.Float y) { moveBy(VT(x, y)-centroid); }

  bool inside() (VT.Float x, VT.Float y) { return inside(VT(x, y)); }
};


// ////////////////////////////////////////////////////////////////////////// //
public struct VertexStorage(VT) if (IsVectorDim!(VT, 2)) {
private:
  VT[] vtx;
  VT center = VT.Zero;
  int vtxUsed;

public:
  mixin(VertexStorageCommon);

  // WARNING! all slices will become UB!
  void clear(bool complete=false) () {
    vtxUsed = 0;
    static if (complete) {
      if (vtx !is null) delete vtx;
    }
    center = VT.Zero;
  }

  @property bool empty () const pure nothrow @safe @nogc { pragma(inline, true); return (vtxUsed == 0); }

  @property int length () const pure nothrow @safe @nogc { pragma(inline, true); return vtxUsed; }
  alias opDollar = length;

  @property VT centroid () nothrow @safe @nogc {
    //pragma(inline, true);
    if (!center.isFinite) {
      center = VT.Zero;
      if (vtxUsed > 0) {
        foreach (const ref v; vtx[0..vtxUsed]) center += v;
        center /= cast(VT.Float)vtxUsed;
      }
    }
    return center;
  }

  bool sameIndex (int i0, int i1) const pure nothrow @safe @nogc {
    pragma(inline, true);
    return (((i0%vtxUsed)+vtxUsed)%vtxUsed == ((i1%vtxUsed)+vtxUsed)%vtxUsed);
  }

  VT opIndex (int idx) const pure nothrow @trusted @nogc {
    pragma(inline, true);
    if (vtxUsed == 0) assert(0, "no vertices in storage");
    return vtx.ptr[((idx%vtxUsed)+vtxUsed)%vtxUsed];
  }

  void opIndexAssign() (in auto ref VT v, int idx) nothrow @trusted @nogc {
    pragma(inline, true);
    if (vtxUsed == 0) assert(0, "no vertices in storage");
    vtx.ptr[((idx%vtxUsed)+vtxUsed)%vtxUsed] = v;
    center = VT.Invalid;
  }

  void swap (int i0, int i1) pure nothrow @trusted @nogc {
    if (vtxUsed == 0) assert(0, "no vertices in storage");
    if (i0 == i1) return;
    i0 = ((i0%vtxUsed)+vtxUsed)%vtxUsed;
    i1 = ((i1%vtxUsed)+vtxUsed)%vtxUsed;
    auto tmp = vtx.ptr[i0];
    vtx.ptr[i0] = vtx.ptr[i1];
    vtx.ptr[i1] = tmp;
  }

  // WILL become UB if storage will go out of scope when the result is still alive
  const(VT)[] opSlice (int lo, int hi) inout pure nothrow @trusted @nogc {
    pragma(inline, true);
    if (lo < 0 || hi < 0 || lo > hi || lo > vtxUsed || hi > vtxUsed) assert(0, "invalid slicing");
    return vtx[lo..hi];
  }

  // WILL become UB if storage will go out of scope when the result is still alive
  const(VT)[] opSlice () inout pure nothrow @trusted @nogc {
    pragma(inline, true);
    return vtx[0..vtxUsed];
  }

  void opOpAssign(string op:"~") (in auto ref VT v) nothrow @trusted {
    if (vtxUsed >= int.max/2) assert(0, "out of memory for vertices");
    if (vtxUsed < vtx.length) {
      vtx.ptr[vtxUsed] = v;
    } else {
      assert(vtxUsed == vtx.length);
      auto optr = vtx.ptr;
      vtx ~= v;
      if (vtx.ptr !is optr) {
        import core.memory : GC;
        optr = vtx.ptr;
        if (optr is GC.addrOf(optr)) GC.setAttr(optr, GC.BlkAttr.NO_INTERIOR);
      }
    }
    ++vtxUsed;
    center = VT.Invalid;
  }

  void remove (int idx) nothrow @trusted {
    import core.stdc.string : memmove;
    if (vtxUsed == 0) assert(0, "no vertices in storage");
    auto i = ((idx%vtxUsed)+vtxUsed)%vtxUsed;
    if (i < vtxUsed-1) memmove(vtx.ptr+i, vtx.ptr+i+1, (vtxUsed-i-1)*vtx[0].sizeof);
    --vtxUsed;
    center = VT.Invalid;
  }

  void moveBy() (in auto ref VT ofs) nothrow @trusted {
    foreach (ref v; vtx[0..vtxUsed]) v += ofs;
    if (center.isFinite) center += ofs;
  }

  bool inside() (in auto ref VT p) { return insideConvexHelper(this, p); }
}

//static assert(IsGoodVertexStorage!(VertexStorage!vec2, vec2));
/*
void foo () {
  VertexStorage!vec2 vs;
  vs.moveTo(vec2(0, 0));
  auto v0 = vs[0];
  vs ~= v0;
  vs[0] = v0;
  auto c = vs.centroid;
  auto s0 = vs[];
  auto s1 = vs[1..$];
}
*/


// ////////////////////////////////////////////////////////////////////////// //
private int sign(T) (T v) { pragma(inline, true); return (v < 0 ? -1 : v > 0 ? 1 : 0); }


// ////////////////////////////////////////////////////////////////////////// //
// dumb O(n) support function, just brute force check all points
public VT supportDumb(VS, VT) (ref VS vstore, in auto ref VT dir) if (IsGoodVertexStorage!(VS, VT)) {
  if (vstore.length == 0) return VT.Invalid; // dunno, something
  VT sup = vstore[0];
  auto maxDot = sup.dot(dir);
  foreach (const ref v; vstore[1..$]) {
    immutable d = v.dot(dir);
    if (d > maxDot) { maxDot = d; sup = v; }
  }
  return sup;
}


// support function using hill climbing
public VT support(VS, VT) (ref VS vstore, in auto ref VT dir) if (IsGoodVertexStorage!(VS, VT)) {
  if (vstore.length <= 4) return supportDumb(vstore, dir); // we will check all vertices in those cases anyway

  int vidx = 1, vtxdir = 1;
  auto maxDot = vstore[1].dot(dir);

  // check backward direction
  immutable dot0delta = vstore[0].dot(dir)-maxDot;
  // if dot0delta is negative, there is no reason to go backwards
  if (dot0delta > 0) {
    // check forward direction
    immutable dot2delta = vstore[2].dot(dir)-maxDot;
    vtxdir = (dot2delta > dot0delta ? 1 : -1);
  }

  // this loop is guaranteed to stop (obviously), but only for good convexes, so limit iteration count
  foreach (immutable itrcount; 0..vstore.length) {
    immutable d = vstore[vidx+vtxdir].dot(dir);
    if (d < maxDot) return vstore[vidx]; // i found her!
    // advance
    maxDot = d;
    vidx += vtxdir;
  }

  // degenerate poly
  return vstore[vidx];
}


// gets the signed area
// if the area is less than 0, it indicates that the polygon is clockwise winded
public auto signedArea(VS) (ref VS vstore) if (IsGoodVertexStorage!VS) {
  alias VT = VertexStorageVT!VS;
  if (vstore.length < 3) return 0;
  VT.Float area = 0;
  foreach (immutable i; 0..vstore.length) {
    area += vstore[i].x*vstore[i+1].y;
    area -= vstore[i].y*vstore[i+1].x;
  }
  return area/cast(VT.Float)2;
}


// indicates if the vertices are in counter clockwise order
// warning: If the area of the polygon is 0, it is unable to determine the winding
public bool isCCW(VS) (ref VS vstore) if (IsGoodVertexStorage!VS) {
  return (vstore.length > 2 && signedArea(vstore) > 0);
}


// forces the vertices to be counter clock wise order
public void forceCCW(VS) (ref VS vstore) if (IsGoodVertexStorage!VS) {
  if (vstore.length < 3) return;
  if (!isCCW(vstore)) {
    foreach (immutable idx; 0..vstore.length/2) vstore.swap(idx, vstore.length-idx-1);
    assert(isCCW(vstore));
  }
}


// removes all collinear points
public void collinearSimplify(VS, FT:double) (ref VS vstore, FT tolerance=0) if (IsGoodVertexStorage!VS) {
  alias VT = VertexStorageVT!VS;
  int idx = 0;
  while (vstore.length > 3 && idx < vstore.length) {
    if (Math2D.isCollinear(vstore[idx-1], vstore[idx], vstore[idx+1], cast(VT.Float)tolerance)) {
      vstore.remove(idx);
    } else {
      ++idx;
    }
  }
}


// shapes with collinear/identical points aren't "convex"
public bool isConvex(VS) (ref VS vstore) if (IsGoodVertexStorage!VS) {
  if (vstore.length < 3) return false;
  if (vstore.length == 3) return true; // nothing to check here
  int dir;
  foreach (immutable idx, const ref v0; vstore[]) {
    //immutable v0 = vstore[idx];
    immutable v1 = vstore[idx+1]-v0;
    immutable v2 = vstore[idx+2];
    int d = sign(v2.x*v1.y-v2.y*v1.x+v1.x*v0.y-v1.y*v0.x);
    if (d == 0) return false;
    if (idx) {
      if (dir != d) return false;
    } else {
      dir = d;
    }
  }
  return true;
}


public bool insideConvexHelper(VS, VT) (ref VS vstore, in auto ref VT p) /*if (IsGoodVertexStorage!(VS, VT))*/ {
  if (vstore.length < 3) return false;
  int side = 0;
  foreach (immutable idx, const ref v; vstore[]) {
    int d = sign((vstore[idx+1]-v).cross(p-v));
    if (d != 0) {
      if (side == 0) side = d; else if (side != d) return false;
    }
  }
  return true;
}


/*
// use centroid
public void moveTo(VS, VT) (ref VS vstore, in auto ref VT pos) if (IsGoodVertexStorage!(VS, VT)) {
  static if (is(typeof(&vstore.moveTo))) {
    vstore.moveTo(pos);
  } else {
    immutable ofs = pos-vstore.centroid;
    foreach (immutable idx, const ref v; vstore[]) vstore[idx] = v+ofs;
  }
}


public void moveTo(VS, FT:double) (ref VS vstore, FT x, FT y) if (IsGoodVertexStorage!VS) {
  alias VT = VertexStorageVT!VS;
  moveTo!VS(vstore, VT(cast(VT.Float)x, cast(VT.Float)y));
}


public void moveByHelper(VS, VT) (ref VS vstore, in auto ref VT ofs) if (IsGoodVertexStorage!(VS, VT)) {
  static if (is(typeof(&vstore.moveBy))) {
    vstore.moveBy(ofs);
  } else {
    foreach (immutable idx, const ref v; vstore[]) vstore[idx] = v+ofs;
  }
}


public void moveByHelper(VS, FT:double) (ref VS vstore, FT x, FT y) if (IsGoodVertexStorage!VS) {
  alias VT = VertexStorageVT!VS;
  .moveByHelper!VS(vstore, VT(cast(VT.Float)x, cast(VT.Float)y));
}
*/


public void scaleBy(VS, VT) (ref VS vstore, in auto ref VT scale) if (IsGoodVertexStorage!(VS, VT)) {
  foreach (immutable idx, const ref v; vstore[]) vstore[idx] = VT(v.x*scale.x, v.y*scale.y);
}


public void scaleBy(VS, FT:double) (ref VS vstore, FT scale) if (IsGoodVertexStorage!VS) {
  alias VT = VertexStorageVT!VS;
  scaleBy(vstore, VT(cast(VT.Float)scale, cast(VT.Float)scale));
}


// replace vstore points with convex hull (or nothing if it is not possible to build convex hull)
// returns `false` if convex hull cannot be built
public bool buildConvex(VS) (ref VS vstore) if (IsGoodVertexStorage!VS) {
  alias VT = VertexStorageVT!VS;

  // no hulls with less than 3 vertices (ensure actual polygon)
  if (vstore.length < 3) { vstore.clear(); return false; }

  // copy original vertices
  static VT[] averts;
  if (averts.length < vstore.length) {
    auto optr = averts.ptr;
    averts.length = vstore.length;
    if (averts.ptr !is optr) {
      import core.memory : GC;
      optr = averts.ptr;
      if (optr is GC.addrOf(optr)) GC.setAttr(optr, GC.BlkAttr.NO_INTERIOR);
    }
  }
  assert(averts.length >= vstore.length);
  foreach (immutable idx, const ref v; vstore[]) averts.ptr[idx] = v;

  // find the right most point on the hull
  int rightMost = 0;
  VT.Float highestXCoord = averts[0].x;
  foreach (immutable i; 1..averts.length) {
    VT.Float x = averts[i].x;
    if (x > highestXCoord) {
      highestXCoord = x;
      rightMost = cast(int)i;
    } else if (x == highestXCoord) {
      // if matching x then take farthest negative y
      if (averts[i].y < averts[rightMost].y) rightMost = cast(int)i;
    }
  }

  static int[] hull;
  if (hull.length < averts.length) {
    auto optr = hull.ptr;
    hull.length = averts.length;
    if (hull.ptr !is optr) {
      import core.memory : GC;
      optr = hull.ptr;
      if (optr is GC.addrOf(optr)) GC.setAttr(optr, GC.BlkAttr.NO_INTERIOR);
    }
  }
  hull.ptr[0..averts.length] = 0; // just in case, lol

  int outCount = 0;
  int indexHull = rightMost;
  int vcount = 0;

  for (;;) {
    hull[outCount] = indexHull;

    // search for next index that wraps around the hull by computing cross products to
    // find the most counter-clockwise vertex in the set, given the previos hull index
    int nextHullIndex = 0;
    foreach (immutable i; 1..averts.length) {
      // skip if same coordinate as we need three unique points in the set to perform a cross product
      if (nextHullIndex == indexHull) { nextHullIndex = i; continue; }
      // cross every set of three unique vertices
      // record each counter clockwise third vertex and add to the output hull
      immutable e1 = averts[nextHullIndex]-averts[hull[outCount]];
      immutable e2 = averts[i]-averts[hull[outCount]];
      immutable c = e1.cross(e2);
      if (c < 0) nextHullIndex = i;
      // cross product is zero then e vectors are on same line
      // therefore want to record vertex farthest along that line
      if (c == 0 && e2.lengthSquared > e1.lengthSquared) nextHullIndex = i;
    }
    ++outCount;
    indexHull = nextHullIndex;
    // conclude algorithm upon wrap-around
    if (nextHullIndex == rightMost) { vcount = outCount; break; }
  }
  if (vcount < 3) { vstore.clear(); return false; }

  // copy vertices into shape's vertices
  vstore.clear();
  foreach (immutable hidx; hull[0..vcount]) vstore ~= averts[hidx];
  if (!isConvex(vstore)) { vstore.clear(); return false; }

  return true;
}
