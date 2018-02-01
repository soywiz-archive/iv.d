// original code: https://github.com/evanw/csg.js/
//
// Constructive Solid Geometry (CSG) is a modeling technique that uses Boolean
// operations like union and intersection to combine 3D solids. This library
// implements CSG operations on meshes elegantly and concisely using BSP trees,
// and is meant to serve as an easily understandable implementation of the
// algorithm. All edge cases involving overlapping coplanar polygons in both
// solids are correctly handled.
//
// Example usage:
//     auto cube = CSG.cube();
//     auto sphere = CSG.sphere(radius:1.3);
//     auto polygons = cube.opsubtract(sphere).toPolygons();
//
// ## Implementation Details
//
// All CSG operations are implemented in terms of two functions, `clipTo()` and
// `invert()`, which remove parts of a BSP tree inside another BSP tree and swap
// solid and empty space, respectively. To find the union of `a` and `b`, we
// want to remove everything in `a` inside `b` and everything in `b` inside `a`,
// then combine polygons from `a` and `b` into one solid:
//
//     a.clipTo(b);
//     b.clipTo(a);
//     a.build(b.allPolygons());
//
// The only tricky part is handling overlapping coplanar polygons in both trees.
// The code above keeps both copies, but we need to keep them in one tree and
// remove them in the other tree. To remove them from `b` we can clip the
// inverse of `b` against `a`. The code for union now looks like this:
//
//     a.clipTo(b);
//     b.clipTo(a);
//     b.invert();
//     b.clipTo(a);
//     b.invert();
//     a.build(b.allPolygons());
//
// Subtraction and intersection naturally follow from set operations. If
// union is `A | B`, subtraction is `A - B = ~(~A | B)` and intersection is
// `A & B = ~(~A | ~B)` where `~` is the complement operator.
//
// ## License
//
// Copyright (c) 2011 Evan Wallace (http://madebyevan.com/), under the MIT license.
module csg /*is aliced*/;

import iv.alice;
import iv.unarray;
import iv.vmath;

public __gshared bool csg_dump_bsp_stats = false;

version = csg_new_bsp_score_algo;
//version = csg_vertex_has_normal; // provide `normal` member for `Vertex`; it is not used in BSP building or CSG, though
//version = csg_nonrobust_split; // uncomment this to use non-robust spliting (why?)
//version = csg_use_doubles;

version(csg_use_doubles) {
  alias Vec3 = VecN!(3, double);
  alias Float = Vec3.Float;
  // represents a plane in 3D space
  alias Plane = Plane3!(Float, 0.000001f, false);
} else {
  alias Vec3 = VecN!(3, float);
  alias Float = Vec3.Float;
  // represents a plane in 3D space
  alias Plane = Plane3!(Float, 0.0001f, false); // EPS is 0.0001f, no swizzling
}


public __gshared int BSPBalance = 50; // [0..100]; lower prefers less splits, higher prefers more balance


// ////////////////////////////////////////////////////////////////////////// //
/** Represents a vertex of a polygon.
 *
 * This class provides `normal` so convenience functions like `CSG.sphere()`
 * can return a smooth vertex normal, but `normal` is not used anywhere else. */
struct Vertex {
public:
  string toString () const {
    import std.string : format;
    version(csg_vertex_has_normal) {
      return "(%s,%s,%s{%s,%s,%s})".format(pos.x, pos.y, pos.z, normal.x, normal.y, normal.z);
    } else {
      return "(%s,%s,%s)".format(pos.x, pos.y, pos.z);
    }
  }

public:
  Vec3 pos;
  version(csg_vertex_has_normal) {
    Vec3 normal;
    enum HasNormal = true;
  } else {
    enum HasNormal = false;
  }

public:
nothrow @safe @nogc:
  ///
  this() (in auto ref Vec3 apos) {
    pragma(inline, true);
    pos = apos;
  }

  version(csg_vertex_has_normal) {
    ///
    this() (in auto ref Vec3 apos, in auto ref Vec3 anormal) {
      pragma(inline, true);
      pos = apos;
      normal = anormal;
    }

    ///
    void setNormal() (in auto ref Vec3 anorm) {
      pragma(inline, true);
      normal = anorm;
    }
  } else {
    ///
    void setNormal() (in auto ref Vec3 anorm) {
      pragma(inline, true);
    }
  }

  /** Invert all orientation-specific data (e.g. vertex normal).
   *
   * Called when the orientation of a polygon is flipped.
   */
  void flip () {
    pragma(inline, true);
    version(csg_vertex_has_normal) normal = -normal;
  }

  /** Create a new vertex between this vertex and `other` by linearly
   * interpolating all properties using a parameter of `t`.
   */
  Vertex interpolate() (in auto ref Vertex other, Float t) const {
    pragma(inline, true);
    version(csg_vertex_has_normal) {
      return Vertex(
        pos.lerp(other.pos, t),
        normal.lerp(other.normal, t),
      );
    } else {
      return Vertex(
        pos.lerp(other.pos, t),
      );
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
/** Represents a convex polygon. The vertices used to initialize a polygon must
 * be coplanar and form a convex loop.
 *
 * Each convex polygon has a `mshared` property, which is shared between all
 * polygons that are clones of each other or were split from the same polygon.
 * This can be used to define per-polygon properties (such as surface color).
 */
final class Polygon {
public:
  override string toString () const {
    import std.string : format;
    string res = "=== VERTS (%s) ===".format(vertices.length);
    foreach (immutable idx, const ref v; vertices) res ~= "\n  %s: %s".format(idx, v.toString);
    return res;
  }

public:
  version(csg_vertex_has_normal) {
    enum HasNormal = true;
  } else {
    enum HasNormal = false;
  }
  Vertex[] vertices;
  Object mshared;
  Plane plane;
  //AABBImpl!Vec3 aabb;

public:
  this (Vertex[] avertices, Object ashared=null) nothrow @trusted {
    assert(avertices.length > 2);
    vertices = avertices;
    mshared = ashared;
    plane.setFromPoints(vertices[0].pos, vertices[1].pos, vertices[2].pos);
    //aabb.reset();
    foreach (immutable idx, const ref v; vertices) {
      if (plane.pointSide(v.pos) != plane.Coplanar) {
        { import core.stdc.stdio : printf; printf("invalid polygon: vertex #%u is bad! (%g, %g)\n", cast(uint)idx, cast(double)plane.pointSideF(v.pos), cast(double)Plane.EPS); }
        assert(0, "invalid polygon");
      }
      //aabb ~= v.pos;
    }
  }

  /// Clone polygon.
  Polygon clone () nothrow @trusted {
    Vertex[] nv;
    nv.unsafeArraySetLength(vertices.length);
    nv[] = vertices[];
    return new Polygon(nv, mshared);
  }

  /// Flip vertices and reverse vertice order. Return new polygon.
  Polygon flipClone () nothrow @trusted {
    auto res = this.clone();
    res.flip();
    return res;
  }

  /// Flip vertices and reverse vertice order. In-place.
  void flip () nothrow @safe @nogc {
    foreach (immutable idx; 0..vertices.length/2) {
      auto vt = vertices[idx];
      vertices[idx] = vertices[$-idx-1];
      vertices[$-idx-1] = vt;
    }
    foreach (ref Vertex v; vertices) v.flip();
    plane.flip();
  }

  /** Classify polygon into one of the four classes.
   *
   * Classes are:
   *   Coplanar
   *   Front
   *   Back
   *   Spanning
   */
  Plane.PType classify() (in auto ref Plane plane) const nothrow @safe @nogc {
    Plane.PType polygonType = Plane.Coplanar;
    foreach (const ref Vertex v; vertices) {
      Plane.PType type = plane.pointSide(v.pos);
      polygonType |= type;
    }
    return polygonType;
  }

  /** Split this polygon by the given plane.
   *
   * Splits this polygon by the given plane if needed, then put the polygon or polygon
   * fragments in the appropriate lists. Coplanar polygons go into either
   * `coplanarFront` or `coplanarBack` depending on their orientation with
   * respect to this plane. Polygons in front or in back of this plane go into
   * either `front` or `back`.
   */
  void splitPolygon (in ref Plane plane, ref Polygon[] coplanarFront, ref Polygon[] coplanarBack, ref Polygon[] front, ref Polygon[] back) nothrow @trusted {
    alias polygon = this;
    mixin(ImportCoreMath!(Plane.Float, "fabs"));
    assert(plane.valid);

    if (polygon.vertices.length < 3) return;

    // classify each point as well as the entire polygon into one of the above four classes
    Plane.PType polygonType = Plane.Coplanar;
    Plane.PType[] types;
    scope(exit) delete types;
    types.unsafeArraySetLength(polygon.vertices.length);

    foreach (immutable vidx, const ref Vertex v; polygon.vertices) {
      Plane.PType type = plane.pointSide(v.pos);
      polygonType |= type;
      //types.unsafeArrayAppend(type);
      types.ptr[vidx] = type;
    }

    Vertex intersectEdgeAgainstPlane() (in auto ref Vertex a, in auto ref Vertex b) {
      Plane.Float t = (plane.w-(plane.normal*a.pos))/(plane.normal*(b.pos-a.pos));
      assert(fabs(t) > Plane.EPS);
      return a.interpolate(b, t);
    }

    // put the polygon in the correct list, splitting it when necessary
    final switch (polygonType) {
      case Plane.Coplanar:
        // dot
        if (plane.normal*polygon.plane.normal > 0) {
          coplanarFront.unsafeArrayAppend(polygon);
        } else {
          coplanarBack.unsafeArrayAppend(polygon);
        }
        break;
      case Plane.Front:
        front.unsafeArrayAppend(polygon);
        break;
      case Plane.Back:
        back.unsafeArrayAppend(polygon);
        break;
      case Plane.Spanning:
        Vertex[] f, b;
        version(csg_nonrobust_split) {
          // non-robust spliting
          foreach (immutable i; 0..polygon.vertices.length) {
            immutable j = (i+1)%polygon.vertices.length;
            auto ti = types[i];
            auto tj = types[j];
            auto vi = polygon.vertices[i];
            auto vj = polygon.vertices[j];
            if (ti != Plane.Back) f.unsafeArrayAppend(vi);
            if (ti != Plane.Front) b.unsafeArrayAppend(vi); //(ti != Back ? vi.dup : vi);
            if ((ti|tj) == Plane.Spanning) {
              Plane.Float t = (plane.w-(plane.normal*vi.pos))/(plane.normal*(vj.pos-vi.pos));
              assert(fabs(t) > Plane.EPS);
              auto v = vi.interpolate(vj, t);
              f.unsafeArrayAppend(v);
              b.unsafeArrayAppend(v); //v.dup;
            }
          }
        } else {
          // robust spliting, taken from "Real-Time Collision Detection" book
          immutable vlen = cast(int)polygon.vertices.length;
          int aidx = cast(int)polygon.vertices.length-1;
          for (int bidx = 0; bidx < vlen; aidx = bidx, ++bidx) {
            immutable atype = types[aidx];
            immutable btype = types[bidx];
            auto va = polygon.vertices[aidx];
            auto vb = polygon.vertices[bidx];
            if (btype == Plane.Front) {
              if (atype == Plane.Back) {
                // edge (a, b) straddles, output intersection point to both sides
                auto i = intersectEdgeAgainstPlane(vb, va); // `(b, a)` for robustness; was (a, b)
                // consistently clip edge as ordered going from in front -> behind
                assert(plane.pointSide(i.pos) == Plane.Coplanar);
                f.unsafeArrayAppend(i);
                b.unsafeArrayAppend(i);
              }
              // in all three cases, output b to the front side
              f.unsafeArrayAppend(vb);
            } else if (btype == Plane.Back) {
              if (atype == Plane.Front) {
                // edge (a, b) straddles plane, output intersection point
                auto i = intersectEdgeAgainstPlane(va, vb);
                assert(plane.pointSide(i.pos) == Plane.Coplanar);
                f.unsafeArrayAppend(i);
                b.unsafeArrayAppend(i);
              } else if (atype == Plane.Coplanar) {
                // output a when edge (a, b) goes from 'on' to 'behind' plane
                b.unsafeArrayAppend(va);
              }
              // in all three cases, output b to the back side
              b.unsafeArrayAppend(vb);
            } else {
              // b is on the plane. In all three cases output b to the front side
              f.unsafeArrayAppend(vb);
              // in one case, also output b to back side
              if (atype == Plane.Back) b.unsafeArrayAppend(vb);
            }
          }
        }
        if (f.length >= 3) front.unsafeArrayAppend(new Polygon(f, polygon.mshared));
        if (b.length >= 3) back.unsafeArrayAppend(new Polygon(b, polygon.mshared));
        break;
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
/** Holds a node in a BSP tree.
 *
 * A BSP tree is built from a collection of polygons by picking a polygon
 * to split along. That polygon (and all other coplanar polygons) are added
 * directly to that node and the other polygons are added to the front and/or
 * back subtrees. This is not a leafy BSP tree since there is no distinction
 * between internal and leaf nodes.
 */
final class BSPNode {
public:
  Plane plane;
  BSPNode front;
  BSPNode back;
  Polygon[] polygons;
  int polyCount; // all polys in this node and in all children

private:
  // WARNING! UNSAFE!
  static void deleteTree (ref BSPNode node) {
    if (node is null) return;
    //foreach (ref Polygon pg; node.polygons) delete pg;
    delete node.polygons;
    if (node.front !is null) deleteTree(node.front);
    if (node.back !is null) deleteTree(node.back);
    delete node;
  }

public:
  private this () {}

  ///
  this (Polygon[] apolygons) {
    if (apolygons.length) {
      build(apolygons);
      if (csg_dump_bsp_stats) {
        import core.stdc.stdio;
        printf("polys=%u(%d:%u); nodes=%u; maxdepth=%u\n", cast(uint)apolygons.length, polyCount, calcPolyCountSlow, calcNodeCount, calcMaxDepth);
      }
    }
  }

  /// Clone this node and all its subnodes.
  /// Will clone `polygons` array, bit not polygons themselves.
  BSPNode clone () {
    auto res = new BSPNode();
    res.plane = this.plane;
    //res.polygons.reserve(this.polygons.length);
    //foreach (Polygon pg; this.polygons) res.polygons ~= pg.clone();
    res.polygons.length = this.polygons.length;
    res.polygons[] = this.polygons[];
    res.polyCount = this.polyCount;
    if (this.front !is null) res.front = this.front.clone();
    if (this.back !is null) res.back = this.back.clone();
    return res;
  }

  /// Clone this node and all its subnodes.
  /// Will clone `polygons` array, and polygons themselves.
  BSPNode deepClone () {
    auto res = new BSPNode();
    res.plane = this.plane;
    res.polygons.reserve(this.polygons.length);
    foreach (Polygon pg; this.polygons) res.polygons ~= pg.clone();
    res.polyCount = this.polyCount;
    if (this.front !is null) res.front = this.front.clone();
    if (this.back !is null) res.back = this.back.clone();
    return res;
  }

  ///
  uint calcPolyCount () const nothrow @safe @nogc { pragma(inline, true); return polyCount; }

  ///
  uint calcPolyCountSlow () const nothrow @safe @nogc {
    uint res = cast(uint)polygons.length;
    if (front !is null) res += front.calcPolyCountSlow();
    if (back !is null) res += back.calcPolyCountSlow();
    return res;
  }

  ///
  uint calcNodeCount () const nothrow @safe @nogc {
    uint res = 1;
    if (front !is null) res += front.calcNodeCount();
    if (back !is null) res += back.calcNodeCount();
    return res;
  }

  ///
  uint calcMaxDepth () const nothrow @safe @nogc {
    uint maxdepth = 0, curdepth = 0;
    void walk (const(BSPNode) n) {
      if (n is null) return;
      ++curdepth;
      if (curdepth > maxdepth) maxdepth = curdepth;
      walk(n.front);
      walk(n.back);
      --curdepth;
    }
    walk(this);
    assert(curdepth == 0);
    return maxdepth;
  }

  /// Convert solid space to empty space and empty space to solid space.
  void invert () {
    foreach (Polygon p; polygons) p.flip();
    plane.flip();
    if (front !is null) front.invert();
    if (back !is null) back.invert();
    // swap back and front nodes
    auto temp = front;
    front = back;
    back = temp;
  }

  /// Recursively remove all polygons in `plys` that are inside this BSP tree.
  /// `plys` is not modified.
  Polygon[] clipPolygons (Polygon[] plys) {
    if (!plane.valid) return plys;
    Polygon[] f, b;
    bool keepf = false, keepb = false;
    scope(exit) { if (!keepf) delete f; if (!keepb) delete b; }
    foreach (Polygon p; plys) p.splitPolygon(plane, f, b, f, b);
    if (front !is null) f = front.clipPolygons(f);
    if (back !is null) b = back.clipPolygons(b); else delete b;
    // return concatenation of `f` and `b`
    if (f.length == 0 && b.length == 0) return null;
    // is `f` empty?
    if (f.length == 0) {
      assert(b.length != 0);
      keepb = true;
      return b;
    }
    // is `b` empty?
    if (b.length == 0) {
      assert(f.length != 0);
      keepf = true;
      return f;
    }
    // build new array
    Polygon[] res;
    res.unsafeArraySetLength(f.length+b.length);
    res[0..f.length] = f[];
    res[f.length..$] = b[];
    return res;
  }

  /// Remove all polygons in this BSP tree that are inside the other BSP tree `bsp`.
  /// Will not modify or destroy old polygon list.
  void clipTo (BSPNode bsp) {
    if (bsp is null) return;
    polygons = bsp.clipPolygons(polygons);
    polyCount = cast(int)polygons.length;
    if (front !is null) { front.clipTo(bsp); polyCount += front.polyCount; }
    if (back !is null) { back.clipTo(bsp); polyCount += back.polyCount; }
    assert(calcPolyCountSlow == polyCount);
  }

  private void merge (BSPNode bsp) {
    if (bsp is null) return;
    build(bsp.allPolygons);
  }

  private void collectPolys (ref Polygon[] plys) {
    if (polygons.length) {
      auto clen = plys.length;
      plys.unsafeArraySetLength(clen+polygons.length);
      plys[clen..$] = polygons[];
    }
    if (front !is null) front.collectPolys(plys);
    if (back !is null) back.collectPolys(plys);
  }

  /// Return a list of all polygons in this BSP tree.
  Polygon[] allPolygons () {
    Polygon[] res;
    collectPolys(res);
    return res;
  }

  ///
  void forEachPoly (scope void delegate (const(Polygon) pg) dg) const {
    if (dg is null) return;
    foreach (const Polygon pg; polygons) dg(pg);
    if (front !is null) front.forEachPoly(dg);
    if (back !is null) back.forEachPoly(dg);
  }

  ///
  void forEachPolyNC (scope void delegate (Polygon pg) dg) {
    if (dg is null) return;
    foreach (Polygon pg; polygons) dg(pg);
    if (front !is null) front.forEachPolyNC(dg);
    if (back !is null) back.forEachPolyNC(dg);
  }

  // Build a BSP tree out of `polygons`. When called on an existing tree, the new
  // polygons are filtered down to the bottom of the tree and become new nodes there.
  private static struct BuildInfo {
    BSPNode node;
    Polygon[] plys;
  }

  // Used in CSG class.
  private void buildAndKill (Polygon[] plys) {
    scope(exit) {
      //foreach (ref Polygon pg; plys) delete pg;
      delete plys;
    }
    build(plys);
  }

  // Used in CSG class.
  private void build (Polygon[] plys) {
    if (plys.length == 0) return;
    BuildInfo[] nodes;
    nodes.unsafeArrayAppend(BuildInfo(this, plys));
    buildInternal(nodes);
    updatePolyCount();
  }

  private void updatePolyCount () nothrow @safe @nogc {
    polyCount = cast(int)polygons.length;
    if (front !is null) { front.updatePolyCount(); polyCount += front.polyCount; }
    if (back !is null) { back.updatePolyCount();  polyCount += back.polyCount; }
  }

  private static void buildInternal (ref BuildInfo[] nodes) {
    while (nodes.length > 0) {
      auto node = nodes[0].node;
      Polygon[] plys = nodes[0].plys;
      //nodes = nodes[1..$];
      if (nodes.length > 1) {
        import core.stdc.string : memmove;
        memmove(&nodes[0], &nodes[1], nodes[0].sizeof*(nodes.length-1));
        //nodes.length -= 1;
        nodes.unsafeArraySetLength(nodes.length-1);
      } else {
        //nodes.length = 0;
        nodes.unsafeArraySetLength(0);
      }
      //nodes.assumeSafeAppend;
      if (plys.length == 0) continue;
      //assert(node.front is null);
      //assert(node.back is null);
      version(csg_simple_bsp) {
        if (!node.plane.valid) node.plane = plys[0].plane;
        Polygon[] f, b;
        foreach (Polygon p; plys) p.splitPolygon(node.plane, node.polygons, node.polygons, f, b);
        //{ import std.stdio; stdout.writeln(" polys=", node.polygons.length, "; back=", b.length, "; front=", f.length); }
        if (f.length != 0) {
          if (node.front is null) node.front = new BSPNode();
          nodes.unsafeArrayAppend(BuildInfo(node.front, f));
          //{ import std.stdio; stdout.writeln("  added front node"); }
        }
        if (b.length != 0) {
          if (node.back is null) node.back = new BSPNode();
          nodes.unsafeArrayAppend(BuildInfo(node.back, b));
          //{ import std.stdio; stdout.writeln("  added back node"); }
        }
      } else {
        Polygon[] fbest, bbest;
        if (!node.plane.valid) {
          version(csg_new_bsp_score_algo) {
            mixin(ImportCoreMath!(float, "fabs"));
            //enum BSPBalance = 50; // [0..100]; lower prefers less splits, higher prefers more balance
            float bestScore = float.infinity;
          }
          int bestl = 0, bestr = 0, bests = 0, bestc = 0;
          uint bestidx = 0;
          if (plys.length > 2) {
            foreach (immutable idx, Polygon px; plys) {
              auto pl = px.plane;
              int l = 0, r = 0, s = 0, c = 0;
              foreach (Polygon p; plys) {
                auto side = p.classify(pl);
                     if (side == Plane.Back) ++l;
                else if (side == Plane.Front) ++r;
                else if (side == Plane.Spanning) ++s;
                else if (side == Plane.Coplanar) ++c;
              }
              version(csg_new_bsp_score_algo) {
                float score = (100.0f-cast(float)BSPBalance)*cast(float)s+cast(float)BSPBalance*fabs(cast(float)(r-l));
                if (score < bestScore) {
                  bestidx = cast(uint)idx;
                  bestScore = score;
                  bestl = l;
                  bestr = r;
                  bests = s;
                  bestc = c;
                }
              } else {
                import std.math : abs;
                if (idx == 0 || (/*s < bests ||*/ abs(l-r) < abs(bestl-bestr))) {
                  bestidx = cast(uint)idx;
                  bestl = l;
                  bestr = r;
                  bests = s;
                  bestc = c;
                }
              }
            }
            node.plane = plys[bestidx].plane;
            // if we have highly unbalanced tree (no polys at one side), split it by half to maintain at least *some* balance
            version(none) {
              if ((bestl == 0 || bestr == 0) && bestl+bestr > 16) {
                // find bounding box
                auto bbox = plys[0].aabb;
                foreach (Polygon px; plys[1..$]) bbox ~= px.aabb;
                // and split it in half
                //node.plane = Plane.setFromPoints(bbox.min, bbox.max, vec3(bbox.bbox.max.z));
                //{ import iv.vfs.io; writeln("bestidx=", bestidx, " of ", plys.length, "; l=", bestl, "; r=", bests, "; s=", bests, "; bestc=", bestc); }
                //{ import iv.vfs.io; writeln("bbox=", bbox); }
                node.plane.setFromPoints(
                  Vec3(bbox.min.x, bbox.center.y, bbox.min.z),
                  Vec3(bbox.min.x, bbox.center.y, bbox.max.z),
                  Vec3(bbox.max.x, bbox.center.y, bbox.min.z));
              }
            }
          } else {
            node.plane = plys[bestidx].plane;
          }
        }
        foreach (Polygon p; plys) p.splitPolygon(node.plane, node.polygons, node.polygons, fbest, bbest);
        if (fbest.length != 0) {
          if (node.front is null) node.front = new BSPNode();
          nodes.unsafeArrayAppend(BuildInfo(node.front, fbest));
        }
        if (bbest.length != 0) {
          if (node.back is null) node.back = new BSPNode();
          nodes.unsafeArrayAppend(BuildInfo(node.back, bbest));
        }
      }
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
/** Holds a binary space partition tree representing a 3D solid.
 *
 * Two solids can be combined using the `doUnion()`, `doSubtract()`, and `doIntersect()` methods.
 */
final class CSG {
public:
  override string toString () const {
    import std.string : format;
    const(Polygon)[] list;
    scope(exit) delete list;
    int count = 0;
    if (tree !is null) {
      list.reserve(tree.calcPolyCount);
      tree.forEachPoly(delegate (const(Polygon) p) { list ~= p; });
    }
    string res = "=== CSG (%s) ===".format(list.length);
    foreach (immutable pidx, const Polygon p; list) {
      res ~= "\nPOLY #%s\n".format(pidx);
      res ~= p.toString();
    }
    return res;
  }

private:
  BSPNode tree = null;

private:
  // Takes ownership of `atree`.
  this (BSPNode atree) {
    assert(atree !is null);
    tree = atree;
  }

  this () {}

public:
  /// Construct a CSG solid from a list of `Polygon` instances.
  /// Takes ownership of polygons (but not `aplys`).
  static auto fromPolygons (Polygon[] aplys) {
    assert(aplys.length > 0);
    auto csg = new CSG();
    csg.tree = new BSPNode(aplys);
    return csg;
  }

  /// Clone solid. Will not clone BSP tree.
  /// Will clone polygons themselves.
  CSG clone () {
    assert(tree !is null);
    auto csg = new CSG();
    csg.tree = tree.deepClone();
    return csg;
  }

  void forEachPoly (scope void delegate (const(Polygon) pg) dg) const {
    if (dg is null || tree is null) return;
    tree.forEachPoly(dg);
  }

  // Will not clone polygons themselves.
  private BSPNode getClonedBSP () {
    assert(tree !is null);
    return tree.clone();
  }

  // `a` is always a result, `b` can be deleted
  private static void mergeBSP (ref BSPNode a, ref BSPNode b) {
    // always merge smaller tree to the bigger one
    { import iv.cmdcon; conwriteln("apc=", a.calcPolyCountSlow, "; apcFast=", a.polyCount, "; bpc=", b.calcPolyCountSlow, "; bpcFast=", b.polyCount); }
    if (a.calcPolyCount < b.calcPolyCount) {
      auto tmp = a;
      a = b;
      b = tmp;
    }
    a.merge(b);
  }

  //     A.union(B)
  //
  //     +-------+            +-------+
  //     |       |            |       |
  //     |   A   |            |       |
  //     |    +--+----+   =   |       +----+
  //     +----+--+    |       +----+       |
  //          |   B   |            |       |
  //          |       |            |       |
  //          +-------+            +-------+
  //
  /** Return a new CSG solid representing space in either this solid or in the
   * solid `csg`. Neither this solid nor the solid `csg` are modified. */
  CSG doUnion (CSG csg) {
    auto a = this.getClonedBSP(); // this will be used as new CSG
    //scope(exit) BSPNode.deleteTree(a);
    auto b = csg.getClonedBSP(); // temporary tree, will be used to do CSG and then discarded
    scope(exit) BSPNode.deleteTree(b);
    a.clipTo(b);
    b.clipTo(a);
    b.invert();
    b.clipTo(a);
    b.invert();
    mergeBSP(a, b);
    return new CSG(a);
  }

  //     A.subtract(B)
  //
  //     +-------+            +-------+
  //     |       |            |       |
  //     |   A   |            |       |
  //     |    +--+----+   =   |    +--+
  //     +----+--+    |       +----+
  //          |   B   |
  //          |       |
  //          +-------+
  //
  /** Return a new CSG solid representing space in this solid but not in the
   * solid `csg`. Neither this solid nor the solid `csg` are modified. */
  CSG doSubtract (CSG csg) {
    auto a = this.getClonedBSP(); // this will be used as new CSG
    //scope(exit) BSPNode.deleteTree(a);
    auto b = csg.getClonedBSP(); // temporary tree, will be used to do CSG and then discarded
    scope(exit) BSPNode.deleteTree(b);
    a.invert();
    a.clipTo(b);
    b.clipTo(a);
    b.invert();
    b.clipTo(a);
    b.invert();
    mergeBSP(a, b);
    a.invert();
    return new CSG(a);
  }

  //     A.intersect(B)
  //
  //     +-------+
  //     |       |
  //     |   A   |
  //     |    +--+----+   =   +--+
  //     +----+--+    |       +--+
  //          |   B   |
  //          |       |
  //          +-------+
  //
  /** Return a new CSG solid representing space both this solid and in the
   * solid `csg`. Neither this solid nor the solid `csg` are modified. */
  CSG doIntersect (CSG csg) {
    auto a = this.getClonedBSP(); // this will be used as new CSG
    //scope(exit) BSPNode.deleteTree(a);
    auto b = csg.getClonedBSP(); // temporary tree, will be used to do CSG and then discarded
    scope(exit) BSPNode.deleteTree(b);
    a.invert();
    b.clipTo(a);
    b.invert();
    a.clipTo(b);
    b.clipTo(a);
    mergeBSP(a, b);
    a.invert();
    return new CSG(a);
  }

  /// Return a new CSG solid with solid and empty space switched. This solid is not modified.
  CSG doInverse () {
    assert(tree !is null);
    uint count = tree.calcPolyCount();
    Polygon[] plys;
    plys.reserve(count);
    scope(exit) delete plys;
    tree.forEachPolyNC(delegate (Polygon pg) { plys ~= pg.flipClone(); });
    return fromPolygons(plys);
    //auto csg = new CSG();
    //csg.tree = tree.deepClone();
    //csg.tree.invert();
    /*
    csg.plys.unsafeArraySetLength(plys.length);
    csg.plys[] = plys[];
    foreach (ref p; csg.plys) p = p.flipClone();
    */
    //return csg;
  }

static:
  /** Construct an axis-aligned solid cuboid.
   *
   * Optional parameters are `center` and `radius`, which default to `[0, 0, 0]` and `[1, 1, 1]`.
   * The radius can be specified using a single number or a list of three numbers, one for each axis.
   */
  CSG Cube (Vec3 center, const(Float)[] radius...) {
    import std.algorithm : map;
    import std.array : array;
    auto c = center;
    Vec3 r = Vec3(1, 1, 1);
    foreach (immutable n, Float f; radius) {
      if (n >= 3) break;
      r[cast(int)n] = f;
    }
    //auto r = (radius > 0 ? Vec3(radius, radius, radius) : Vec3(1, 1, 1));
    return CSG.fromPolygons([
      [[0.0, 4.0, 6.0, 2.0], [-1.0, 0.0, 0.0]],
      [[1.0, 3.0, 7.0, 5.0], [+1.0, 0.0, 0.0]],
      [[0.0, 1.0, 5.0, 4.0], [0.0, -1.0, 0.0]],
      [[2.0, 6.0, 7.0, 3.0], [0.0, +1.0, 0.0]],
      [[0.0, 2.0, 3.0, 1.0], [0.0, 0.0, -1.0]],
      [[4.0, 5.0, 7.0, 6.0], [0.0, 0.0, +1.0]]
    ].map!((info) {
      return new Polygon(info[0].map!((i) {
        auto pos = Vec3(
          c.x+cast(Float)r[0]*cast(Float)(2*(cast(int)i&1 ? 1 : 0)-1),
          c.y+cast(Float)r[1]*cast(Float)(2*(cast(int)i&2 ? 1 : 0)-1),
          c.z+cast(Float)r[2]*cast(Float)(2*(cast(int)i&4 ? 1 : 0)-1),
        );
        version(csg_vertex_has_normal) {
          return Vertex(pos, Vec3(cast(Float)info[1][0], cast(Float)info[1][1], cast(Float)info[1][2]));
        } else {
          return Vertex(pos);
        }
      }).array);
    }).array);
  }

  /// Construct an axis-aligned solid cuboid at origin, and with raduis of 1.
  CSG Cube () { return Cube(Vec3(0, 0, 0)); }

  /** Construct a solid sphere.
   *
   * Optional parameters are `center`, `radius`, `slices`, and `stacks`,
   * which default to `[0, 0, 0]`, `1`, `16`, and `8`.
   * The `slices` and `stacks` parameters control the tessellation along the
   * longitude and latitude directions.
   */
  CSG Sphere (Vec3 center=Vec3(0, 0, 0), Float radius=1, int slices=16, int stacks=8) {
    import std.math;
    auto c = center;
    Polygon[] polygons;
    Vertex[] vertices;
    void vertex (Float theta, Float phi) {
      theta *= PI*2;
      phi *= PI;
      auto dir = Vec3(
        cos(theta)*sin(phi),
        cos(phi),
        sin(theta)*sin(phi),
      );
      version(csg_vertex_has_normal) {
        vertices.unsafeArrayAppend(Vertex(c+(dir*radius), dir));
      } else {
        vertices.unsafeArrayAppend(Vertex(c+(dir*radius)));
      }
    }
    foreach (int i; 0..slices) {
      foreach (int j; 0..stacks) {
        vertices = [];
        vertex(cast(Float)i/slices, cast(Float)j/stacks);
        if (j > 0) vertex(cast(Float)(i+1)/slices, cast(Float)j/stacks);
        if (j < stacks-1) vertex(cast(Float)(i+1)/slices, cast(Float)(j+1)/stacks);
        vertex(cast(Float)i/slices, cast(Float)(j+1)/stacks);
        polygons.unsafeArrayAppend(new Polygon(vertices));
      }
    }
    return CSG.fromPolygons(polygons);
  }

  /** Construct a solid cylinder.
   *
   * Optional parameters are `start`, `end`, `radius`, and `slices`,
   * which default to `[0, -1, 0]`, `[0, 1, 0]`, `1`, and `16`.
   * The `slices` parameter controls the tessellation.
   */
  CSG Cylinder (Vec3 start=Vec3(0, -1, 0), Vec3 end=Vec3(0, 1, 0), Float radius=1, int slices=16) {
    import std.math;
    auto s = start;
    auto e = end;
    auto ray = e-s;
    auto axisZ = ray.normalized;
    auto isY = (abs(axisZ.y) > 0.5 ? 1 : 0);
    auto axisX = (Vec3(isY, !isY, 0)%axisZ).normalized;
    auto axisY = (axisX%axisZ).normalized;
    auto sv = Vertex(s);
    auto ev = Vertex(e);
    version(csg_vertex_has_normal) {
      sv.setNormal(-axisZ);
      ev.setNormal(axisZ.normalized);
    }
    Polygon[] polygons;
    Vertex point (Float stack, Float slice, Float normalBlend) {
      auto angle = slice*PI*2;
      auto o = (axisX*cos(angle))+(axisY*sin(angle));
      auto pos = s+(ray*stack)+(o*radius);
      auto normal = o*(1-abs(normalBlend))+(axisZ*normalBlend);
      auto res = Vertex(pos);
      version(csg_vertex_has_normal) res.setNormal(normal);
      return res;
    }
    foreach (int i; 0..slices) {
      auto t0 = cast(Float)i/slices;
      auto t1 = cast(Float)(i+1)/slices;
      polygons.unsafeArrayAppend(new Polygon([sv, point(0, t0, -1), point(0, t1, -1)]));
      polygons.unsafeArrayAppend(new Polygon([point(0, t1, 0), point(0, t0, 0), point(1, t0, 0), point(1, t1, 0)]));
      polygons.unsafeArrayAppend(new Polygon([ev, point(1, t1, 1), point(1, t0, 1)]));
    }
    return CSG.fromPolygons(polygons);
  }
}


version(csg_test) unittest {
  auto a = CSG.Cube();
  auto b = CSG.Sphere(radius:1.35, stacks:12);
  auto c = CSG.Cylinder(radius: 0.7, start:Vec3(-1, 0, 0), end:Vec3(1, 0, 0));
  auto d = CSG.Cylinder(radius: 0.7, start:Vec3(0, -1, 0), end:Vec3(0, 1, 0));
  auto e = CSG.Cylinder(radius: 0.7, start:Vec3(0, 0, -1), end:Vec3(0, 0, 1));
  auto mesh = a.doIntersect(b).doSubtract(c.doUnion(d).doUnion(e));
}
