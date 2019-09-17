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
module iv.vmath2d.math2d;

public import iv.vmath;


// ////////////////////////////////////////////////////////////////////////// //
public struct Math2D {
  @disable this ();
  @disable this (this);

public static:
  static T nmin(T) (in T a, in T b) { pragma(inline, true); return (a < b ? a : b); }
  static T nmax(T) (in T a, in T b) { pragma(inline, true); return (a > b ? a : b); }

  // gets the signed area
  // if the area is less than 0, it indicates that the polygon is clockwise winded
  auto signedArea(VT) (const(VT)[] verts) @trusted if (IsVectorDim!(VT, 2)) {
    VT.Float area = 0;
    if (verts.length < 3) return area;
    auto j = verts.length-1;
    typeof(j) i = 0;
    for (; i < verts.length; j = i, ++i) {
      area += verts.ptr[j].x*verts.ptr[i].y;
      area -= verts.ptr[j].y*verts.ptr[i].x;
    }
    return area/cast(VT.Float)2;
  }

  // indicates if the vertices are in counter clockwise order
  // warning: If the area of the polygon is 0, it is unable to determine the winding
  bool isCCW(VT) (const(VT)[] verts) if (IsVectorDim!(VT, 2)) {
    return (verts.length > 2 && signedArea(verts) > 0);
  }

  bool isCollinear(VT, T:double) (in auto ref VT a, in auto ref VT b, in auto ref VT c, T tolerance=0) if (IsVectorDim!(VT, 2)) {
    pragma(inline, true);
    mixin(ImportCoreMath!(VT.Float, "fabs"));
    return (fabs((b.x-a.x)*(c.y-a.y)-(c.x-a.x)*(b.y-a.y)) <= EPSILON!(VT.Float)+tolerance);
  }

  // *signed* area; can be used to check on which side `b` is
  auto area(VT) (in auto ref VT a, in auto ref VT b, in auto ref VT c) if (IsVectorDim!(VT, 2)) {
    pragma(inline, true);
    return (b.x-a.x)*(c.y-a.y)-(c.x-a.x)*(b.y-a.y);
  }

  VT lineIntersect(VT) (in auto ref VT p1, in auto ref VT p2, in auto ref VT q1, in auto ref VT q2) if (IsVectorDim!(VT, 2)) {
    pragma(inline, true);
    mixin(ImportCoreMath!(VT.Float, "fabs"));
    immutable VT.Float a1 = p2.y-p1.y;
    immutable VT.Float b1 = p1.x-p2.x;
    immutable VT.Float c1 = a1*p1.x+b1*p1.y;
    immutable VT.Float a2 = q2.y-q1.y;
    immutable VT.Float b2 = q1.x-q2.x;
    immutable VT.Float c2 = a2*q1.x+b2*q1.y;
    immutable VT.Float det = a1*b2-a2*b1;
    if (fabs(det) > EPSILON!(VT.Float)) {
      // lines are not parallel
      immutable VT.Float invdet = cast(VT.Float)1/det;
      return VT((b2*c1-b1*c2)*invdet, (a1*c2-a2*c1)*invdet);
    }
    return VT.Invalid;
  }

  VT segIntersect(bool firstIsSeg=true, bool secondIsSeg=true, VT) (in auto ref VT point0, in auto ref VT point1, in auto ref VT point2, in auto ref VT point3) if (IsVectorDim!(VT, 2)) {
    mixin(ImportCoreMath!(VT.Float, "fabs"));
    static if (firstIsSeg && secondIsSeg) {
      // fast aabb test for possible early exit
      if (nmax(point0.x, point1.x) < nmin(point2.x, point3.x) || nmax(point2.x, point3.x) < nmin(point0.x, point1.x)) return VT.Invalid;
      if (nmax(point0.y, point1.y) < nmin(point2.y, point3.y) || nmax(point2.y, point3.y) < nmin(point0.y, point1.y)) return VT.Invalid;
    }
    immutable VT.Float den = ((point3.y-point2.y)*(point1.x-point0.x))-((point3.x-point2.x)*(point1.y-point0.y));
    if (fabs(den) > EPSILON!(VT.Float)) {
      immutable VT.Float e = point0.y-point2.y;
      immutable VT.Float f = point0.x-point2.x;
      immutable VT.Float invden = cast(VT.Float)1/den;
      immutable VT.Float ua = (((point3.x-point2.x)*e)-((point3.y-point2.y)*f))*invden;
      static if (firstIsSeg) { if (ua < 0 || ua > 1) return VT.Invalid; }
      if (ua >= 0 && ua <= 1) {
        immutable VT.Float ub = (((point1.x-point0.x)*e)-((point1.y-point0.y)*f))*invden;
        static if (secondIsSeg) { if (ub < 0 || ub > 1) return VT.Invalid; }
        if (ua != 0 || ub != 0) return VT(point0.x+ua*(point1.x-point0.x), point0.y+ua*(point1.y-point0.y));
      }
    }
    return VT.Invalid;
  }
}
