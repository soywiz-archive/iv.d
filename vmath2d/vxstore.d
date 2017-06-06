/*
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
module iv.vmath2d.vxstore;

import iv.alice;
import iv.vmath2d.math2d;


// ////////////////////////////////////////////////////////////////////////// //
public template IsGoodVertexStorage(T, VT) if ((is(T == struct) || is(T == class)) && IsVectorDim!(VT, 2)) {
  enum IsGoodVertexStorage = is(typeof((inout int=0) {
    T o = T.init;
    VT v = o[0];
    int len = o.length;
    VT[] vs = o[0..2];
    vs = o[];
    // sadly, we can't check for `opIndex()` wrapping here
    o.swap(1, 2);
    // sadly, we can't check for `swap()` wrapping here
    o.remove(1);
  }));
}


// ////////////////////////////////////////////////////////////////////////// //
public struct VertexStorage(VT) if (IsVectorDim!(VT, 2)) {
private:
  VT[] vtx;
  int vtxUsed;

public:
  // WARNING! all slices will become UB!
  void clear(bool complete=false) () {
    vtxUsed = 0;
    static if (complete) {
      if (vtx !is null) delete vtx;
    }
  }

  @property bool empty () const pure nothrow @safe @nogc { pragma(inline, true); return (vtxUsed == 0); }

  @property int length () const pure nothrow @safe @nogc { pragma(inline, true); return vtxUsed; }

  bool sameIndex (int i0, int i1) const pure nothrow @safe @nogc {
    pragma(inline, true);
    return (((i0%vtxUsed)+vtxUsed)%vtxUsed == ((i1%vtxUsed)+vtxUsed)%vtxUsed);
  }

  ref inout(VT) opIndex (int idx) inout pure nothrow @trusted @nogc {
    pragma(inline, true);
    if (vtxUsed == 0) assert(0, "no vertices in storage");
    return vtx.ptr[((idx%vtxUsed)+vtxUsed)%vtxUsed];
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
  inout(VT)[] opSlice (int lo, int hi) inout pure nothrow @trusted @nogc {
    pragma(inline, true);
    if (lo < 0 || hi < 0 || lo > hi || lo > vtxUsed || hi > vtxUsed) assert(0, "invalid slicing");
    return vtx[lo..hi];
  }

  // WILL become UB if storage will go out of scope when the result is still alive
  inout(VT)[] opSlice () inout pure nothrow @trusted @nogc {
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
  }

  void remove (int idx) nothrow @trusted {
    import core.stdc.string : memmove;
    if (vtxUsed == 0) assert(0, "no vertices in storage");
    auto i = ((idx%vtxUsed)+vtxUsed)%vtxUsed;
    if (i < vtxUsed-1) memmove(vtx.ptr+i, vtx.ptr+i+1, (vtxUsed-i-1)*vtx[0].sizeof);
    --vtxUsed;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
public struct VertexHelper(VT) if (IsVectorDim!(VT, 2)) {
  @disable this ();
  @disable this (this);

public static:
  // gets the signed area
  // if the area is less than 0, it indicates that the polygon is clockwise winded
  VT.Float signedArea(VS) (ref VS verts) if (IsGoodVertexStorage!(VS, VT)) {
    if (verts.length < 3) return 0;
    VT.Float area = 0;
    foreach (immutable i; 0..verts.length) {
      area += verts[i].x*verts[i+1].y;
      area -= verts[i].y*verts[i+1].x;
    }
    return area/cast(VT.Float)2;
  }

  // indicates if the vertices are in counter clockwise order
  // warning: If the area of the polygon is 0, it is unable to determine the winding
  bool isCCW(VS) (ref VS verts) if (IsGoodVertexStorage!(VS, VT)) {
    return (verts.length > 2 && signedArea(verts) > 0);
  }

  // forces the vertices to be counter clock wise order
  void forceCCW(VS) (ref VS verts) if (IsGoodVertexStorage!(VS, VT)) {
    if (verts.length < 3) return;
    if (!isCCW(verts)) {
      foreach (immutable idx; 0..verts.length/2) verts.swap(idx, verts.length-idx-1);
      assert(isCCW(verts));
    }
  }

  // removes all collinear points
  void collinearSimplify(VS) (ref VS vstore, VT.Float tolerance=0) if (IsGoodVertexStorage!(VS, VT)) {
    int idx = 0;
    while (vstore.length > 3 && idx < vstore.length) {
      if (Math2D.isCollinear(vstore[idx-1], vstore[idx], vstore[idx+1], tolerance)) {
        vstore.remove(idx);
      } else {
        ++idx;
      }
    }
  }

  VT centroid(VS) (ref VS vstore) if (IsGoodVertexStorage!(VS, VT)) {
    auto res = VT.Zero;
    foreach (const ref v; vstore[]) res += v;
    res *= cast(VT.Float)1/vstore.length;
    return res;
  }

  // use centroid
  void moveTo(VS) (ref VS vstore, in auto ref VT pos) if (IsGoodVertexStorage!(VS, VT)) {
    immutable ofs = pos-centroid(vstore);
    foreach (ref v; vstore[]) v += ofs;
  }

  void moveBy(VS) (ref VS vstore, in auto ref VT ofs) if (IsGoodVertexStorage!(VS, VT)) {
    foreach (ref v; vstore[]) v += ofs;
  }

  void scaleBy(VS) (ref VS vstore, in auto ref VT scale) if (IsGoodVertexStorage!(VS, VT)) {
    foreach (ref v; vstore[]) { v.x *= scale.x; v.y *= scale.y; }
  }

  void scaleBy(VS) (ref VS vstore, VT.Float scale) if (IsGoodVertexStorage!(VS, VT)) {
    foreach (ref v; vstore[]) v.x *= scale;
  }
}
