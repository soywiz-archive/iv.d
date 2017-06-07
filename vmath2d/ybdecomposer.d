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
// convex decomposition algorithm originally created by Mark Bayazit (http://mnbayazit.com/)
// for more information about this algorithm, see http://mnbayazit.com/406/bayazit
// modified by Yogesh (http://yogeshkulkarni.com)
// D port and further modifications by Ketmar // Invisible Vector
//
// decompose simple polygon (i.e. polygon without holes and self-intersections) into set of convex polygons
module iv.vmath2d.ybdecomposer;

import iv.alice;
import iv.vmath2d.math2d;
import iv.vmath2d.vxstore;


// ////////////////////////////////////////////////////////////////////////// //
public struct YBDecomposer(VT) if (IsVectorDim!(VT, 2)) {
private:
  // precondition: ccw
  static bool reflex() (in auto ref VT prev, in auto ref VT on, in auto ref VT next) {
    pragma(inline, true);
    // YOGESH: Added following condition of collinearity
    if (Math2D.isCollinear(prev, on, next)) return false;
    return right(prev, on, next);
  }

  // if i is on the left of i-1 and i+1 line in the polygon vertices; checks area -ve
  static bool left() (in auto ref VT a, in auto ref VT b, in auto ref VT c) { pragma(inline, true); return (Math2D.area(a, b, c) > 0); }

  // if i is on the left or ON of i-1 and i+1 line in the polygon vertices; checks area -ve and 0
  static bool leftOn() (in auto ref VT a, in auto ref VT b, in auto ref VT c) { pragma(inline, true); return (Math2D.area(a, b, c) >= 0); }

  // if i is on the right of i-1 and i+1 line in the polygon vertices; checks area +ve
  static bool right() (in auto ref VT a, in auto ref VT b, in auto ref VT c) { pragma(inline, true); return (Math2D.area(a, b, c) < 0); }

  // if i is on the right or ON of i-1 and i+1 line in the polygon vertices; checks area +ve and 0
  static bool rightOn() (in auto ref VT a, in auto ref VT b, in auto ref VT c) { pragma(inline, true); return (Math2D.area(a, b, c) <= 0); }

public:
  // decompose the polygon into several smaller non-concave polygon
  // if the polygon is already convex, it will return the original polygon
  // returned polygons are CCW
  static void convexPartition(VS) (ref VS[] accum, ref VS poly) if (IsGoodVertexStorage!(VS, VT)) {
    // can you see j from i in the polygon vertices without any obstructions?
    bool canSee (int i, int j) {
      VT prev = poly[i-1];
      VT on = poly[i];
      VT next = poly[i+1];

      if (reflex(prev, on, next)) {
        if (leftOn(poly[i], poly[i-1], poly[j]) && rightOn(poly[i], poly[i+1], poly[j])) return false;
      } else {
        if (rightOn(poly[i], poly[i+1], poly[j]) || leftOn(poly[i], poly[i-1], poly[j])) return false;
      }

      VT prevj = poly[j-1];
      VT onj = poly[j];
      VT nextj = poly[j+1];

      if (reflex(prevj, onj, nextj)) {
        if (leftOn(poly[j], poly[j-1], poly[i]) && rightOn(poly[j], poly[j+1], poly[i])) return false;
      } else {
        if (rightOn(poly[j], poly[j+1], poly[i]) || leftOn(poly[j], poly[j-1], poly[i])) return false;
      }

      foreach (immutable k; 0..poly.length) {
        //if ((k + 1) % vertices.Count == i || k == i || (k + 1) % vertices.Count == j || k == j) continue; // ignore incident edges

        // YOGESH: changed from Line-Line intersection to Segment-Segment Intersection
        VT p1 = poly[i];
        VT p2 = poly[j];
        VT q1 = poly[k];
        VT q2 = poly[k+1];

        // ignore incident edges
        if (p1 == q1 || p1 == q2 || p2 == q1 || p2 == q2) continue;

        auto intPoint = Math2D.segIntersect(p1, p2, q1, q2);
        //Debug.Print("Line from point {0} to {1} is tested against [{2},{3} to see if they intersect]", i, j, k, k+1);
        if (intPoint.valid) {
          // intPoint is not any of the j line then false, else continue. Intersection has to be interior to qualify s 'false' from here
          //if (intPoint != poly.verts[k] || intPoint != poly.verts[k+1]) return false;
          if (intPoint.equals(poly[k]) || intPoint.equals(poly[k+1])) return false;
        }
      }

      return true;
    }

    void copyPolyPartTo (ref VS dest, int i, int j) {
      while (j < i) j += poly.length;
      for (; i <= j; ++i) dest ~= poly[i];
    }

    // main
    poly.collinearSimplify();
    if (poly.length < 3) return;

    // we force it to CCW as it is a precondition in this algorithm
    poly.forceCCW();

    //VT.Float lowerDist = 0.0, upperDist = 0.0;
    //int lowerIndex = 0, upperIndex = 0;
    VT lowerInt, upperInt; // intersection points

    // go thru all Verices until we find a reflex vertex i
    // extend the edges incident at i until they hit an edge
    // find BEST vertex within the range, that the partitioning chord

    // a polygon can be broken into convex regions by eliminating all reflex vertices
    // eliminating two reflex vertices with one diagonal is better than eliminating just one
    // a reflex vertex can only be removed if the diagonal connecting to it is within the range given by extending its neighbouring edges;
    // otherwise, its angle is only reduced
    foreach (immutable i; 0..poly.length) {
      if (reflex(poly[i-1], poly[i], poly[i+1])) {
        VT.Float lowerDist = VT.Float.infinity;
        VT.Float upperDist = VT.Float.infinity;
        int lowerIndex = 0, upperIndex = 0;
        for (int j = 0; j < poly.length; ++j) {
          // YOGESH: if any of j line's endpoints matches with reflex i, skip
          if (poly.sameIndex(i, j) || poly.sameIndex(i, j-1) || poly.sameIndex(i, j+1)) continue; // no self and prev and next, for testing

          // testing incoming edge:
          // if line coming into i vertex (i-1 to i) has j vertex of the test-line on left
          // AND have j-i on right, then they will be intersecting

          VT iPrev = poly[i-1];
          VT iSelf = poly[i];
          VT jSelf = poly[j];
          VT jPrev = poly[j-1];

          bool leftOK = left(iPrev, iSelf, jSelf);
          bool rightOK = right(iPrev, iSelf, jPrev);

          bool leftOnOK = Math2D.isCollinear(iPrev, iSelf, jSelf); // YOGESH: cached into variables for better debugging
          bool rightOnOK = Math2D.isCollinear(iPrev, iSelf, jPrev); // YOGESH: cached into variables for better debugging

          if (leftOnOK || rightOnOK) {
            // YOGESH: Checked "ON" condition as well, collinearity
            // lines are colinear, they can not be overlapping as polygon is simple
            // find closest point which is not internal to incoming line i , i -1
            VT.Float d = iSelf.distanceSquared(jSelf);

            // this lower* is the point got from incoming edge into the i vertex,
            // lowerInt incoming edge intersection point
            // lowerIndex incoming edge intersection edge
            if (d < lowerDist) {
              // keep only the closest intersection
              lowerDist = d;
              lowerInt = jSelf;
              lowerIndex = j-1;
            }

            d = iSelf.distanceSquared(jPrev);

            // this lower* is the point got from incoming edge into the i vertex,
            // lowerInt incoming edge intersection point
            // lowerIndex incoming edge intersection edge
            if (d < lowerDist) {
              // keep only the closest intersection
              lowerDist = d;
              lowerInt = jPrev;
              lowerIndex = j;
            }
          } else if (leftOK && rightOK) {
            // YOGESH: Intersection in-between. Bayazit had ON condition in built here, which I have taken care above.
            // find the point of intersection
            VT p = Math2D.lineIntersect(poly[i-1], poly[i], poly[j], poly[j-1]);
            // make sure it's inside the poly,
            if (right(poly[i+1], poly[i], p)) {
              VT.Float d = poly[i].distanceSquared(p);
              // this lower* is the point got from incoming edge into the i vertex,
              // lowerInt incoming edge intersection point
              // lowerIndex incoming edge intersection edge
              if (d < lowerDist) {
                // keep only the closest intersection
                lowerDist = d;
                lowerInt = p;
                lowerIndex = j;
              }
            }
          }

          // testing outgoing edge:
          // if line outgoing from i vertex (i to i+1) has j vertex of the test-line on right
          // AND has j+1 on left, they they will be intersecting

          VT iNext = poly[i+1];
          VT jNext = poly[j+1];

          bool leftOKn = left(iNext, iSelf, jNext);
          bool rightOKn = right(iNext, iSelf, jSelf);

          bool leftOnOKn = Math2D.isCollinear(iNext, iSelf, jNext); // YOGESH: cached into variables for better debugging
          bool rightOnOKn = Math2D.isCollinear(iNext, iSelf, jSelf);

          if (leftOnOKn || rightOnOKn) {
            // YOGESH: Checked "ON" condition as well, collinearity
            // lines are colinear, they can not be overlapping as polygon is simple
            // find closest point which is not internal to incoming line i , i -1
            VT.Float d = iSelf.distanceSquared(jNext);

            // this upper* is the point got from outgoing edge into the i vertex,
            // upperInt outgoing edge intersection point
            // upperIndex outgoing edge intersection edge
            if (d < upperDist) {
              // keep only the closest intersection
              upperDist = d;
              upperInt = jNext;
              upperIndex = j+1;
            }

            d = poly[i].distanceSquared(poly[j]);

            // this upper* is the point got from outgoing edge into the i vertex,
            // upperInt outgoing edge intersection point
            // upperIndex outgoing edge intersection edge
            if (d < upperDist) {
              // keep only the closest intersection
              upperDist = d;
              upperInt = jSelf;
              upperIndex = j;
            }
          } else if (leftOKn && rightOKn) {
            // YOGESH: Intersection in-between. Bayazit had ON condition in built here, which I have taken care above.
            VT p = Math2D.lineIntersect(poly[i+1], poly[i], poly[j], poly[j+1]);
            if (left(poly[i-1], poly[i], p)) {
              VT.Float d = poly[i].distanceSquared(p);
              // this upper* is the point got from outgoing edge from the i vertex,
              // upperInt outgoing edge intersection point
              // upperIndex outgoing edge intersection edge
              if (d < upperDist) {
                upperDist = d;
                upperIndex = j;
                upperInt = p;
              }
            }
          }
        }

        VS lowerPoly, upperPoly;
        static if (is(VS == class)) {
          lowerPoly = new VS();
          upperPoly = new VS();
        }

        // YOGESH: If no vertices in the range, lets not choose midpoint but closet point of that segment
        // if there are no vertices to connect to, choose a point in the middle
        if (lowerIndex == (upperIndex+1)%poly.length) {
          VT sp = ((lowerInt+upperInt)/cast(VT.Float)2);
          copyPolyPartTo(lowerPoly, i, upperIndex);
          lowerPoly ~= sp;
          copyPolyPartTo(upperPoly, lowerIndex, i);
          upperPoly ~= sp;
        } else {
          // find vertex to connect to
          VT.Float highestScore = 0, bestIndex = lowerIndex;
          while (upperIndex < lowerIndex) upperIndex += poly.length;

          // go through all the vertices between the range of lower and upper
          for (int j = lowerIndex; j <= upperIndex; ++j) {
            if (canSee(i, j)) {
              VT.Float score = cast(VT.Float)1/(poly[i].distanceSquared(poly[j])+1);

              // if another vertex is reflex, choosing it has highest score
              VT prevj = poly[j-1];
              VT onj = poly[j];
              VT nextj = poly[j+1];

              if (reflex(prevj, onj, nextj)) {
                if (rightOn(poly[j-1], poly[j], poly[i]) && leftOn(poly[j+1], poly[j], poly[i])) {
                  score += 3;
                } else {
                  score += 2;
                }
              } else {
                score += 1;
              }
              if (score > highestScore) {
                bestIndex = j;
                highestScore = score;
              }
            }
          }

          // YOGESH : Pending: if there are 2 vertices as 'bestIndex', its better to disregard both and put midpoint (M case)
          copyPolyPartTo(lowerPoly, i, cast(int)bestIndex);
          copyPolyPartTo(upperPoly, cast(int)bestIndex, i);
        }

        // solve smallest poly first (SAW in Bayazit's C++ code)
        if (lowerPoly.length < upperPoly.length) {
          convexPartition(accum, lowerPoly);
          convexPartition(accum, upperPoly);
        } else {
          convexPartition(accum, upperPoly);
          convexPartition(accum, lowerPoly);
        }
        return;
      }
    }

    // polygon is already convex
    accum ~= poly;
  }
}
