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

version = csg_new_bsp_score_algo;

//static assert(is(Float == double), "compile this with -version=vmath_double");
alias Vec3 = VecN!(3, double);


// ////////////////////////////////////////////////////////////////////////// //
// Represents a vertex of a polygon. This class provides `normal` so convenience
// functions like `CSG.sphere()` can return a smooth vertex normal, but `normal`
// is not used anywhere else.
struct Vertex {
public:
  string toString () const {
    import std.string : format;
    return "(%s,%s,%s|%s,%s,%s)".format(pos.x, pos.y, pos.z, normal.x, normal.y, normal.z);
  }

public:
  Vec3 pos, normal;

public:
/*pure*/ nothrow @safe @nogc:
  this() (in auto ref Vec3 apos, in auto ref Vec3 anormal) {
    pos = apos;
    normal = anormal;
  }

  // Invert all orientation-specific data (e.g. vertex normal).
  // Called when the orientation of a polygon is flipped.
  void flip () {
    pragma(inline, true);
    normal = -normal;
  }

  // Create a new vertex between this vertex and `other` by linearly
  // interpolating all properties using a parameter of `t`.
  Vertex interpolate() (in auto ref Vertex other, Vec3.Float t) const {
    pragma(inline, true);
    return Vertex(
      pos.lerp(other.pos, t),
      normal.lerp(other.normal, t)
    );
  }
}


// ////////////////////////////////////////////////////////////////////////// //
// Represents a plane in 3D space.
alias Plane = Plane3!(Vec3.Float, 0.00001f, false); // EPS is 0.00001f, no swizzling


// classify each point as well as the entire polygon into one of the four classes:
//   Coplanar
//   Front
//   Back
//   Spanning
Plane.PType polySide (in ref Plane plane, in Polygon pl) {
  Plane.PType polygonType = Plane.Coplanar;
  foreach (const ref Vertex v; pl.vertices) {
    Plane.PType type = plane.pointSide(v.pos);
    polygonType |= type;
  }
  return polygonType;
}


// Split `polygon` by this plane if needed, then put the polygon or polygon
// fragments in the appropriate lists. Coplanar polygons go into either
// `coplanarFront` or `coplanarBack` depending on their orientation with
// respect to this plane. Polygons in front or in back of this plane go into
// either `front` or `back`.
void splitPolygon (in ref Plane plane, Polygon polygon, ref Polygon[] coplanarFront, ref Polygon[] coplanarBack, ref Polygon[] front, ref Polygon[] back) {
  import std.math : abs;
  assert(plane.valid);

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
      foreach (immutable i; 0..polygon.vertices.length) {
        immutable j = (i+1)%polygon.vertices.length;
        auto ti = types[i];
        auto tj = types[j];
        auto vi = polygon.vertices[i];
        auto vj = polygon.vertices[j];
        if (ti != Plane.Back) f.unsafeArrayAppend(vi);
        if (ti != Plane.Front) b.unsafeArrayAppend(vi); //(ti != Back ? vi.dup : vi);
        if ((ti|tj) == Plane.Spanning) {
          auto t = (plane.w-(plane.normal*vi.pos))/(plane.normal*(vj.pos-vi.pos));
          assert(abs(t) > Plane.EPS);
          auto v = vi.interpolate(vj, t);
          f.unsafeArrayAppend(v);
          b.unsafeArrayAppend(v); //v.dup;
        }
      }
      if (f.length >= 3) front.unsafeArrayAppend(new Polygon(f, cast(Object[])polygon.mshared));
      if (b.length >= 3) back.unsafeArrayAppend(new Polygon(b, cast(Object[])polygon.mshared));
      break;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
// Represents a convex polygon. The vertices used to initialize a polygon must
// be coplanar and form a convex loop. They do not have to be `Vertex`
// instances but they must behave similarly (duck typing can be used for
// customization).
//
// Each convex polygon has a `mshared` property, which is shared between all
// polygons that are clones of each other or were split from the same polygon.
// This can be used to define per-polygon properties (such as surface color).
final class Polygon {
public:
  override string toString () const {
    import std.string : format;
    string res = "=== VERTS (%s) ===".format(vertices.length);
    foreach (immutable idx, const ref v; vertices) res ~= "\n  %s: %s".format(idx, v.toString);
    return res;
  }

public:
  Vertex[] vertices;
  Object[] mshared;
  Plane plane;
  AABBImpl!Vec3 aabb;

public:
/*pure*/ nothrow @safe:
  Polygon dup () /*pure*/ const @trusted {
    pragma(inline, true);
    return new Polygon(vertices.dup, cast(Object[])mshared);
  }

  this (Vertex[] avertices, Object[] ashared=null) @trusted {
    assert(avertices.length > 2);
    vertices = avertices;
    mshared = ashared;
    plane.setFromPoints(vertices[0].pos, vertices[1].pos, vertices[2].pos);
    aabb.reset();
    foreach (immutable idx, const ref v; vertices) {
      if (plane.pointSide(v.pos) != plane.Coplanar) {
        { import core.stdc.stdio : printf; printf("invalid polygon: vertex #%u is bad! (%g, %g)\n", cast(uint)idx, cast(double)plane.pointSideF(v.pos), cast(double)Plane.EPS); }
        assert(0, "invalid polygon");
      }
      aabb ~= v.pos;
    }
  }

  void flip () /*pure*/ @nogc {
    //import std.algorithm : reverse;
    //vertices.reverse;
    foreach (immutable idx; 0..vertices.length/2) {
      auto vt = vertices[idx];
      vertices[idx] = vertices[$-idx-1];
      vertices[$-idx-1] = vt;
    }
    foreach (ref Vertex v; vertices) v.flip();
    plane.flip();
  }
}


// ////////////////////////////////////////////////////////////////////////// //
// Holds a node in a BSP tree. A BSP tree is built from a collection of polygons
// by picking a polygon to split along. That polygon (and all other coplanar
// polygons) are added directly to that node and the other polygons are added to
// the front and/or back subtrees. This is not a leafy BSP tree since there is
// no distinction between internal and leaf nodes.
final class Node {
public:
  Plane plane;
  Node front;
  Node back;
  Polygon[] polygons;

public:
//pure nothrow @safe:

public:
  private this () {}

  this (Polygon[] apolygons) {
    if (apolygons.length) {
      build(apolygons);
      { import core.stdc.stdio; printf("polys=%u; nodes=%u; maxdepth=%u\n", cast(uint)apolygons.length, calcNodeCount, calcMaxDepth); }
    }
  }

  // Convert solid space to empty space and empty space to solid space.
  void invert () {
    foreach (Polygon p; polygons) p.flip();
    plane.flip();
    if (front !is null) front.invert();
    if (back !is null) back.invert();
    auto temp = front;
    front = back;
    back = temp;
  }

  // Recursively remove all polygons in `plys` that are inside this BSP tree.
  Polygon[] clipPolygons (Polygon[] plys) {
    if (!plane.valid) return plys;
    Polygon[] f, b;
    bool keepf = false, keepb = false;
    scope(exit) { if (!keepf) delete f; if (!keepb) delete b; }
    foreach (Polygon p; plys) plane.splitPolygon(p, f, b, f, b);
    if (front !is null) f = front.clipPolygons(f);
    if (back !is null) b = back.clipPolygons(b); else b = null;
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

  // Remove all polygons in this BSP tree that are inside the other BSP tree `bsp`.
  void clipTo (Node bsp) {
    polygons = bsp.clipPolygons(polygons);
    if (front !is null) front.clipTo(bsp);
    if (back !is null) back.clipTo(bsp);
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

  uint calcNodeCount () {
    uint res = 1;
    if (front !is null) res += front.calcNodeCount();
    if (back !is null) res += back.calcNodeCount();
    return res;
  }

  uint calcMaxDepth () {
    uint maxdepth = 0, curdepth = 0;
    void walk (Node n) {
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

  // Return a list of all polygons in this BSP tree.
  Polygon[] allPolygons () {
    Polygon[] res;
    collectPolys(res);
    return res;
  }

  // Build a BSP tree out of `polygons`. When called on an existing tree, the
  // new polygons are filtered down to the bottom of the tree and become new
  // nodes there. Each set of polygons is partitioned using the first polygon
  // (no heuristic is used to pick a good split).
  static struct BuildInfo {
    Node node;
    Polygon[] plys;
  }

  private void build (Polygon[] plys) {
    if (plys.length == 0) return;
    BuildInfo[] nodes;
    nodes.unsafeArrayAppend(BuildInfo(this, plys));
    buildInternal(nodes);
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
        foreach (Polygon p; plys) node.plane.splitPolygon(p, node.polygons, node.polygons, f, b);
        //{ import std.stdio; stdout.writeln(" polys=", node.polygons.length, "; back=", b.length, "; front=", f.length); }
        if (f.length != 0) {
          if (node.front is null) node.front = new Node();
          nodes.unsafeArrayAppend(BuildInfo(node.front, f));
          //{ import std.stdio; stdout.writeln("  added front node"); }
        }
        if (b.length != 0) {
          if (node.back is null) node.back = new Node();
          nodes.unsafeArrayAppend(BuildInfo(node.back, b));
          //{ import std.stdio; stdout.writeln("  added back node"); }
        }
      } else {
        Polygon[] fbest, bbest;
        if (!node.plane.valid) {
          version(csg_new_bsp_score_algo) {
            mixin(ImportCoreMath!(float, "fabs"));
            enum balance = 50; // [0..100]; lower prefers less splits, higher prefers more balance
            float bestScore = float.infinity;
          }
          int bestl = 0, bestr = 0, bests = 0, bestc = 0;
          uint bestidx = 0;
          if (plys.length > 2) {
            foreach (immutable idx, Polygon px; plys) {
              auto pl = px.plane;
              int l = 0, r = 0, s = 0, c = 0;
              foreach (Polygon p; plys) {
                auto side = pl.polySide(p);
                     if (side == Plane.Back) ++l;
                else if (side == Plane.Front) ++r;
                else if (side == Plane.Spanning) ++s;
                else if (side == Plane.Coplanar) ++c;
              }
              version(csg_new_bsp_score_algo) {
                float score = (100.0f-cast(float)balance)*cast(float)s+cast(float)balance*fabs(cast(float)(r-l));
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
        foreach (Polygon p; plys) node.plane.splitPolygon(p, node.polygons, node.polygons, fbest, bbest);
        if (fbest.length != 0) {
          if (node.front is null) node.front = new Node();
          nodes.unsafeArrayAppend(BuildInfo(node.front, fbest));
        }
        if (bbest.length != 0) {
          if (node.back is null) node.back = new Node();
          nodes.unsafeArrayAppend(BuildInfo(node.back, bbest));
        }
      }
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
// Holds a binary space partition tree representing a 3D solid. Two solids can
// be combined using the `union()`, `subtract()`, and `intersect()` methods.
final class CSG {
public:
  override string toString () const {
    import std.string : format;
    string res = "=== CSG (%s) ===".format(polygons.length);
    foreach (immutable pidx, const Polygon p; polygons) {
      res ~= "\nPOLY #%s\n".format(pidx);
      res ~= p.toString();
    }
    return res;
  }

public:
  Polygon[] polygons;

public:
  this () {}

  // Construct a CSG solid from a list of `Polygon` instances.
  static auto fromPolygons (Polygon[] plys) {
    auto csg = new CSG();
    csg.polygons = plys;
    return csg;
  }

  /+
  CSG dup () const {
    auto csg = new CSG();
    csg.polygons = (cast(Polygon[])polygons).dup;
    foreach (ref p; csg.polygons) p = p.dup;
    return csg;
  }
  +/

  Polygon[] toPolygons () { pragma(inline, true); return polygons; }

  // Return a new CSG solid representing space in either this solid or in the
  // solid `csg`. Neither this solid nor the solid `csg` are modified.
  //
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
  CSG opunion (CSG csg) {
    auto a = new Node(this.polygons);
    auto b = new Node(csg.polygons);
    a.clipTo(b);
    b.clipTo(a);
    b.invert();
    b.clipTo(a);
    b.invert();
    a.build(b.allPolygons());
    return CSG.fromPolygons(a.allPolygons());
  }

  // Return a new CSG solid representing space in this solid but not in the
  // solid `csg`. Neither this solid nor the solid `csg` are modified.
  //
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
  CSG opsubtract (CSG csg) {
    auto a = new Node(this.polygons);
    auto b = new Node(csg.polygons);
    a.invert();
    a.clipTo(b);
    b.clipTo(a);
    b.invert();
    b.clipTo(a);
    b.invert();
    a.build(b.allPolygons());
    a.invert();
    return CSG.fromPolygons(a.allPolygons());
  }

  // Return a new CSG solid representing space both this solid and in the
  // solid `csg`. Neither this solid nor the solid `csg` are modified.
  //
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
  CSG opintersect (CSG csg) {
    auto a = new Node(this.polygons);
    auto b = new Node(csg.polygons);
    a.invert();
    b.clipTo(a);
    b.invert();
    a.clipTo(b);
    b.clipTo(a);
    a.build(b.allPolygons());
    a.invert();
    return CSG.fromPolygons(a.allPolygons());
  }

  // Return a new CSG solid with solid and empty space switched. This solid is not modified.
  CSG opinverse () {
    auto csg = new CSG();
    /*
    foreach (Polygon p; polygons) {
      csg.polygons ~= new Polygon(p.vertices.dup, p.mshared);
      csg.polygons[$-1].flip();
    }
    */
    csg.polygons = polygons.dup;
    foreach (ref p; csg.polygons) p = p.dup;
    return csg;
  }

static:
  // Construct an axis-aligned solid cuboid. Optional parameters are `center` and
  // `radius`, which default to `[0, 0, 0]` and `[1, 1, 1]`. The radius can be
  // specified using a single number or a list of three numbers, one for each axis.
  //
  // Example code:
  //
  //     var cube = CSG.cube({
  //       center: [0, 0, 0],
  //       radius: 1
  //     });
  CSG cube (Vec3 center=Vec3(0, 0, 0), Vec3.Float radius=1) {
    import std.algorithm : map;
    import std.array : array;
    auto c = center;
    auto r = (radius > 0 ? Vec3(radius, radius, radius) : Vec3(1, 1, 1));
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
          c.x+cast(Vec3.Float)r[0]*cast(Vec3.Float)(2*(cast(int)i&1 ? 1 : 0)-1),
          c.y+cast(Vec3.Float)r[1]*cast(Vec3.Float)(2*(cast(int)i&2 ? 1 : 0)-1),
          c.z+cast(Vec3.Float)r[2]*cast(Vec3.Float)(2*(cast(int)i&4 ? 1 : 0)-1),
        );
        return Vertex(pos, Vec3(cast(Vec3.Float)info[1][0], cast(Vec3.Float)info[1][1], cast(Vec3.Float)info[1][2]));
      }).array);
    }).array);
  }

  // Construct a solid sphere. Optional parameters are `center`, `radius`,
  // `slices`, and `stacks`, which default to `[0, 0, 0]`, `1`, `16`, and `8`.
  // The `slices` and `stacks` parameters control the tessellation along the
  // longitude and latitude directions.
  //
  // Example usage:
  //
  //     var sphere = CSG.sphere({
  //       center: [0, 0, 0],
  //       radius: 1,
  //       slices: 16,
  //       stacks: 8
  //     });
  CSG sphere (Vec3 center=Vec3(0, 0, 0), Vec3.Float radius=1, int slices=16, int stacks=8) {
    import std.math;
    auto c = center;
    Polygon[] polygons;
    Vertex[] vertices;
    void vertex (Vec3.Float theta, Vec3.Float phi) {
      theta *= PI*2;
      phi *= PI;
      auto dir = Vec3(
        cos(theta)*sin(phi),
        cos(phi),
        sin(theta)*sin(phi),
      );
      vertices.unsafeArrayAppend(Vertex(c+(dir*radius), dir));
    }
    foreach (int i; 0..slices) {
      foreach (int j; 0..stacks) {
        vertices = [];
        vertex(cast(Vec3.Float)i/slices, cast(Vec3.Float)j/stacks);
        if (j > 0) vertex(cast(Vec3.Float)(i+1)/slices, cast(Vec3.Float)j/stacks);
        if (j < stacks-1) vertex(cast(Vec3.Float)(i+1)/slices, cast(Vec3.Float)(j+1)/stacks);
        vertex(cast(Vec3.Float)i/slices, cast(Vec3.Float)(j+1)/stacks);
        polygons.unsafeArrayAppend(new Polygon(vertices));
      }
    }
    return CSG.fromPolygons(polygons);
  }

  // Construct a solid cylinder. Optional parameters are `start`, `end`,
  // `radius`, and `slices`, which default to `[0, -1, 0]`, `[0, 1, 0]`, `1`, and
  // `16`. The `slices` parameter controls the tessellation.
  //
  // Example usage:
  //
  //     var cylinder = CSG.cylinder({
  //       start: [0, -1, 0],
  //       end: [0, 1, 0],
  //       radius: 1,
  //       slices: 16
  //     });
  CSG cylinder (Vec3 start=Vec3(0, -1, 0), Vec3 end=Vec3(0, 1, 0), Vec3.Float radius=1, int slices=16) {
    import std.math;
    auto s = start;
    auto e = end;
    auto ray = e-s;
    auto axisZ = ray.normalized;
    auto isY = (abs(axisZ.y) > 0.5 ? 1 : 0);
    auto axisX = (Vec3(isY, !isY, 0)%axisZ).normalized;
    auto axisY = (axisX%axisZ).normalized;
    auto sv = Vertex(s, -axisZ);
    auto ev = Vertex(e, axisZ.normalized);
    Polygon[] polygons;
    Vertex point (Vec3.Float stack, Vec3.Float slice, Vec3.Float normalBlend) {
      auto angle = slice*PI*2;
      auto o = (axisX*cos(angle))+(axisY*sin(angle));
      auto pos = s+(ray*stack)+(o*radius);
      auto normal = o*(1-abs(normalBlend))+(axisZ*normalBlend);
      return Vertex(pos, normal);
    }
    foreach (int i; 0..slices) {
      auto t0 = cast(Vec3.Float)i/slices;
      auto t1 = cast(Vec3.Float)(i+1)/slices;
      polygons.unsafeArrayAppend(new Polygon([sv, point(0, t0, -1), point(0, t1, -1)]));
      polygons.unsafeArrayAppend(new Polygon([point(0, t1, 0), point(0, t0, 0), point(1, t0, 0), point(1, t1, 0)]));
      polygons.unsafeArrayAppend(new Polygon([ev, point(1, t1, 1), point(1, t0, 1)]));
    }
    return CSG.fromPolygons(polygons);
  }
}


version(csg_test) unittest {
  auto a = CSG.cube();
  auto b = CSG.sphere(radius:1.35, stacks:12);
  auto c = CSG.cylinder(radius: 0.7, start:Vec3(-1, 0, 0), end:Vec3(1, 0, 0));
  auto d = CSG.cylinder(radius: 0.7, start:Vec3(0, -1, 0), end:Vec3(0, 1, 0));
  auto e = CSG.cylinder(radius: 0.7, start:Vec3(0, 0, -1), end:Vec3(0, 0, 1));
  auto mesh = a.opintersect(b).opsubtract(c.opunion(d).opunion(e));
}
