/* Kevin's implementation of the Gilbert-Johnson-Keerthi intersection algorithm
 * and the Expanding Polytope Algorithm
 * Most useful references (Huge thanks to all the authors):
 *
 * "Implementing GJK" by Casey Muratori:
 * The best description of the algorithm from the ground up
 * https://www.youtube.com/watch?v=Qupqu1xe7Io
 *
 * "Implementing a GJK Intersection Query" by Phill Djonov
 * Interesting tips for implementing the algorithm
 * http://vec3.ca/gjk/implementation/
 *
 * "GJK Algorithm 3D" by Sergiu Craitoiu
 * Has nice diagrams to visualise the tetrahedral case
 * http://in2gpu.com/2014/05/18/gjk-algorithm-3d/
 *
 * "GJK + Expanding Polytope Algorithm - Implementation and Visualization"
 * Good breakdown of EPA with demo for visualisation
 * https://www.youtube.com/watch?v=6rgiPrzqt9w
 *
 * D translation by Ketmar // Invisible Vector
 *
 * see bottom of this file for licensing info
 */
module iv.vmath_gjk3d_simple;

import iv.vmath;

// ////////////////////////////////////////////////////////////////////////// //
/* GJK object should support:
 *   Vec3 position
 *   Vec3 support (Vec3 dir) -- in world space
 *
 * for polyhedra:
 *
 * vec3 position () const { return centroid; }
 *
 * // dumb O(n) support function, just brute force check all points
 * vec3 support() (in auto ref vec3 dir) const {
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
public template IsGoodGJKObject(T, VT) if ((is(T == struct) || is(T == class)) && IsVectorDim!(VT, 3)) {
  enum IsGoodGJKObject = is(typeof((inout int=0) {
    const o = T.init;
    VT v = o.position;
    v = o.support(VT(0, 0, 0));
  }));
}


// ////////////////////////////////////////////////////////////////////////// //
/// Returns true if two colliders are intersecting. Has optional Minimum Translation Vector output param.
/// If `mtv` is supplied, the EPA will be used to find the vector to separate coll1 from coll2.
public bool gjk(CT, VT) (in auto ref CT coll1, in auto ref CT coll2, VT* mtv=null) if (IsGoodGJKObject!(CT, VT)) {
  enum GJK_MAX_NUM_ITERATIONS = 64;

  VT a, b, c, d; // simplex: just a set of points (a is always most recently added)
  VT searchDir = coll1.position-coll2.position; // initial search direction between colliders

  // get initial point for simplex
  c = coll2.support(searchDir)-coll1.support(-searchDir);
  searchDir = -c; // search in direction of origin

  // get second point for a line segment simplex
  b = coll2.support(searchDir)-coll1.support(-searchDir);

  if (b.dot(searchDir) < 0) return false; // we didn't reach the origin, won't enclose it

  searchDir = (c-b).cross(-b).cross(c-b); // search perpendicular to line segment towards origin
  if (searchDir.isZero) {
    // origin is on this line segment
    // apparently any normal search vector will do?
    searchDir = (c-b).cross(VT(1, 0, 0)); // normal with x-axis
    if (searchDir.isZero) searchDir = (c-b).cross(VT(0, 0, -1)); // normal with z-axis
  }

  int simpDim = 2; // simplex dimension

  foreach (immutable iterations; 0..GJK_MAX_NUM_ITERATIONS) {
    a = coll2.support(searchDir)-coll1.support(-searchDir);
    if (a.dot(searchDir) < 0) return false; // we didn't reach the origin, won't enclose it
    ++simpDim;
    if (simpDim == 3) {
      updateSimplex3(a, b, c, d, simpDim, searchDir);
    } else if (updateSimplex4(a, b, c, d, simpDim, searchDir)) {
      if (mtv !is null) *mtv = EPA(a, b, c, d, coll1, coll2);
      return true;
    }
  }

  return false;
}


// triangle case
private void updateSimplex3(VT) (ref VT a, ref VT b, ref VT c, ref VT d, ref int simpDim, ref VT searchDir) {
  /* Required winding order:
  //  b
  //  | \
  //  |   \
  //  |    a
  //  |   /
  //  | /
  //  c
  */
  VT n = (b-a).cross(c-a); // triangle's normal
  VT AO = -a; // direction to origin

  // determine which feature is closest to origin, make that the new simplex

  simpDim = 2;
  if ((b-a).cross(n).dot(AO) > 0) {
    // closest to edge AB
    c = a;
    // simp_dim = 2;
    searchDir = (b-a).cross(AO).cross(b-a);
    return;
  }

  if (n.cross(c-a).dot(AO) > 0) {
    // closest to edge AC
    b = a;
    // simp_dim = 2;
    searchDir = (c-a).cross(AO).cross(c-a);
    return;
  }

  simpDim = 3;
  if (n.dot(AO) > 0) {
    // above triangle
    d = c;
    c = b;
    b = a;
    // simp_dim = 3;
    searchDir = n;
    return;
  }
  // else // below triangle
  d = b;
  b = a;
  // simp_dim = 3;
  searchDir = -n;
}


// tetrahedral case
private bool updateSimplex4(VT) (ref VT a, ref VT b, ref VT c, ref VT d, ref int simpDim, ref VT searchDir) {
  // a is peak/tip of pyramid, BCD is the base (counterclockwise winding order)
  // we know a priori that origin is above BCD and below a

  // get normals of three new faces
  VT ABC = (b-a).cross(c-a);
  VT ACD = (c-a).cross(d-a);
  VT ADB = (d-a).cross(b-a);

  VT AO = -a; // dir to origin
  simpDim = 3; // hoisting this just cause

  // plane-test origin with 3 faces
  /*
  // Note: Kind of primitive approach used here; If origin is in front of a face, just use it as the new simplex.
  // We just go through the faces sequentially and exit at the first one which satisfies dot product. Not sure this
  // is optimal or if edges should be considered as possible simplices? Thinking this through in my head I feel like
  // this method is good enough. Makes no difference for AABBS, should test with more complex colliders.
  */
  if (ABC.dot(AO) > 0) {
    // in front of ABC
    d = c;
    c = b;
    b = a;
    searchDir = ABC;
    return false;
  }

  if (ACD.dot(AO) > 0) {
    // in front of ACD
    b = a;
    searchDir = ACD;
    return false;
  }

  if (ADB.dot(AO) > 0) {
    // in front of ADB
    c = d;
    d = b;
    b = a;
    searchDir = ADB;
    return false;
  }

  // else inside tetrahedron; enclosed!
  return true;

  // note: in the case where two of the faces have similar normals,
  // the origin could conceivably be closest to an edge on the tetrahedron
  // right now I don't think it'll make a difference to limit our new simplices
  // to just one of the faces, maybe test it later.
}


// ////////////////////////////////////////////////////////////////////////// //
// Expanding Polytope Algorithm
// find minimum translation vector to resolve collision
// colliders using the final simplex obtained with the GJK algorithm
private VT EPA(CT, VT) (in auto ref VT a, in auto ref VT b, in auto ref VT c, in auto ref VT d, in auto ref CT coll1, in auto ref CT coll2) {
  enum EPA_TOLERANCE = 0.0001;
  enum EPA_MAX_NUM_FACES = 64;
  enum EPA_MAX_NUM_LOOSE_EDGES = 32;
  enum EPA_MAX_NUM_ITERATIONS = 64;

  VT[4][EPA_MAX_NUM_FACES] faces = void; // array of faces, each with 3 verts and a normal

  // init with final simplex from GJK
  faces.ptr[0].ptr[0] = a;
  faces.ptr[0].ptr[1] = b;
  faces.ptr[0].ptr[2] = c;
  faces.ptr[0].ptr[3] = (b-a).cross(c-a).normalized; // ABC
  faces.ptr[1].ptr[0] = a;
  faces.ptr[1].ptr[1] = c;
  faces.ptr[1].ptr[2] = d;
  faces.ptr[1].ptr[3] = (c-a).cross(d-a).normalized; // ACD
  faces.ptr[2].ptr[0] = a;
  faces.ptr[2].ptr[1] = d;
  faces.ptr[2].ptr[2] = b;
  faces.ptr[2].ptr[3] = (d-a).cross(b-a).normalized; // ADB
  faces.ptr[3].ptr[0] = b;
  faces.ptr[3].ptr[1] = d;
  faces.ptr[3].ptr[2] = c;
  faces.ptr[3].ptr[3] = (d-b).cross(c-b).normalized; // BDC

  int numFaces = 4;
  int closestFace;

  foreach (immutable iterations; 0..EPA_MAX_NUM_ITERATIONS) {
    // find face that's closest to origin
    auto minDist = faces.ptr[0].ptr[0].dot(faces.ptr[0].ptr[3]);
    closestFace = 0;
    foreach (immutable i; 1..numFaces) {
      auto dist = faces.ptr[i].ptr[0].dot(faces.ptr[i].ptr[3]);
      if (dist < minDist) {
        minDist = dist;
        closestFace = i;
      }
    }

    // search normal to face that's closest to origin
    VT searchDir = faces.ptr[closestFace].ptr[3];
    VT p = coll2.support(searchDir)-coll1.support(-searchDir);

    if (p.dot(searchDir)-minDist < EPA_TOLERANCE) {
      // convergence (new point is not significantly further from origin)
      return faces.ptr[closestFace].ptr[3]*p.dot(searchDir); // dot vertex with normal to resolve collision along normal!
    }

    VT[2][EPA_MAX_NUM_LOOSE_EDGES] looseEdges = void; // keep track of edges we need to fix after removing faces
    int numLooseEdges = 0;

    // find all triangles that are facing p
    for (int i = 0; i < numFaces; ++i) {
      if (faces.ptr[i].ptr[3].dot(p-faces.ptr[i].ptr[0]) > 0) {
        // triangle i faces p, remove it
        // add removed triangle's edges to loose edge list.
        // if it's already there, remove it (both triangles it belonged to are gone)
        foreach (immutable j; 0..3) {
          // three edges per face
          VT[2] currentEdge = [faces.ptr[i].ptr[j], faces.ptr[i].ptr[(j+1)%3]];
          bool foundEdge = false;
          foreach (immutable k; 0..numLooseEdges) {
            // check if current edge is already in list
            if (looseEdges[k].ptr[1] == currentEdge[0] && looseEdges[k].ptr[0] == currentEdge[1]) {
              // edge is already in the list, remove it
              // THIS ASSUMES EDGE CAN ONLY BE SHARED BY 2 TRIANGLES (which should be true)
              // THIS ALSO ASSUMES SHARED EDGE WILL BE REVERSED IN THE TRIANGLES (which
              // should be true provided every triangle is wound CCW)
              looseEdges[k].ptr[0] = looseEdges[numLooseEdges-1].ptr[0]; // overwrite current edge
              looseEdges[k].ptr[1] = looseEdges[numLooseEdges-1].ptr[1]; // with last edge in list
              --numLooseEdges;
              foundEdge = true;
              break; // exit loop because edge can only be shared once
            }
          }

          if (!foundEdge) {
            // add current edge to list
            // assert(num_loose_edges<EPA_MAX_NUM_LOOSE_EDGES);
            if (numLooseEdges >= EPA_MAX_NUM_LOOSE_EDGES) break;
            looseEdges[numLooseEdges].ptr[0] = currentEdge[0];
            looseEdges[numLooseEdges].ptr[1] = currentEdge[1];
            ++numLooseEdges;
          }
        }

        // remove triangle i from list
        faces.ptr[i].ptr[0] = faces.ptr[numFaces-1].ptr[0];
        faces.ptr[i].ptr[1] = faces.ptr[numFaces-1].ptr[1];
        faces.ptr[i].ptr[2] = faces.ptr[numFaces-1].ptr[2];
        faces.ptr[i].ptr[3] = faces.ptr[numFaces-1].ptr[3];
        --numFaces;
        --i;
      }
    }

    // reconstruct polytope with p added
    foreach (immutable i; 0..numLooseEdges) {
      // assert(num_faces<EPA_MAX_NUM_FACES);
      if (numFaces >= EPA_MAX_NUM_FACES) break;
      faces.ptr[numFaces].ptr[0] = looseEdges[i].ptr[0];
      faces.ptr[numFaces].ptr[1] = looseEdges[i].ptr[1];
      faces.ptr[numFaces].ptr[2] = p;
      faces.ptr[numFaces].ptr[3] = (looseEdges[i].ptr[0]-looseEdges[i].ptr[1]).cross(looseEdges[i].ptr[0]-p).normalized;

      // check for wrong normal to maintain CCW winding
      enum bias = EPSILON!(VT.Float); //0.000001; // in case dot result is only slightly < 0 (because origin is on face)
      if (faces.ptr[numFaces].ptr[0].dot(faces.ptr[numFaces].ptr[3])+bias < 0) {
        VT temp = faces.ptr[numFaces].ptr[0];
        faces.ptr[numFaces].ptr[0] = faces.ptr[numFaces].ptr[1];
        faces.ptr[numFaces].ptr[1] = temp;
        faces.ptr[numFaces].ptr[3] = -faces.ptr[numFaces].ptr[3];
      }
      ++numFaces;
    }
  }
  { import core.stdc.stdio; stderr.fprintf("EPA did not converge\n"); }
  // return most recent closest point
  return faces.ptr[closestFace].ptr[3]*faces.ptr[closestFace].ptr[0].dot(faces.ptr[closestFace].ptr[3]);
}


/*
License for Gilbert-Johnson-Keerthi Algorithm Implementation
No warranty is implied, use at your own risk
Kevin Moran
24 March 2017

------------------------------------------------------------------------------
This software is available under 2 licenses -- choose whichever you prefer.
------------------------------------------------------------------------------
ALTERNATIVE A - MIT License
Copyright (c) 2017 Kevin Moran
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
------------------------------------------------------------------------------
ALTERNATIVE B - Public Domain (www.unlicense.org)
This is free and unencumbered software released into the public domain.
Anyone is free to copy, modify, publish, use, compile, sell, or distribute this
software, either in source code form or as a compiled binary, for any purpose,
commercial or non-commercial, and by any means.
In jurisdictions that recognize copyright laws, the author or authors of this
software dedicate any and all copyright interest in the software to the public
domain. We make this dedication for the benefit of the public at large and to
the detriment of our heirs and successors. We intend this dedication to be an
overt act of relinquishment in perpetuity of all present and future rights to
this software under copyright law.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
------------------------------------------------------------------------------
*/
