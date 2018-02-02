module gourd;

import iv.vfs;
import iv.unarray;

import csg;


// ////////////////////////////////////////////////////////////////////////// //
void writePolySoup (VFile fo, Polygon[] plys) {
  // no need to store polygon plane, it will be recalculated
  assert(plys.length < int.max/16);
  static if (Polygon.HasNormal) {
    fo.rawWriteExact("K8PLYSOUPv0");
  } else {
    fo.rawWriteExact("K8PLYSOUPv1");
  }
  fo.writeNum!ubyte(cast(ubyte)Float.sizeof);
  // number of polygons
  fo.writeNum!uint(cast(uint)plys.length);
  foreach (Polygon p; plys) {
    if (p.vertices.length < 3) assert(0, "degenerate polygon");
    if (p.vertices.length > short.max) assert(0, "polygon too big");
    // check it, just for fun
    /*
    foreach (ref Vertex v; p.vertices) {
      if (p.plane.pointSide(v.pos) != p.plane.Coplanar) assert(0, "invalid polygon");
    }
    */
    // number of vertices
    fo.writeNum!ushort(cast(ushort)p.vertices.length);
    // vertices
    foreach (ref Vertex v; p.vertices) {
      // coords
      fo.writeNum!(Float)(v.pos.x);
      fo.writeNum!(Float)(v.pos.y);
      fo.writeNum!(Float)(v.pos.z);
      // normal
      static if (Polygon.HasNormal) {
        fo.writeNum!(Float)(v.normal.x);
        fo.writeNum!(Float)(v.normal.y);
        fo.writeNum!(Float)(v.normal.z);
      }
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
CSG readPolySoup (VFile fi) {
  enum Signature = "K8PLYSOUPv"; // 0: with normals; 1: without normals
  char[Signature.length+1] sign = void;
  fi.rawReadExact(sign[]);
  if (sign[0..$-1] != Signature) throw new Exception("invalid polygon soup file signature");
  bool hasNorms;
       if (sign[$-1] == '0') hasNorms = true;
  else if (sign[$-1] == '1') hasNorms = false;
  else throw new Exception("invalid polygon soup file version");
  if (fi.readNum!ubyte != Float.sizeof) throw new Exception("invalid polygon soup file (float size)");
  // number of polygons
  uint pcount = fi.readNum!uint();
  if (pcount == 0 || pcount > int.max/16) throw new Exception("invalid polygon soup file");
  Polygon[] plys;
  plys.unsafeArraySetLength(pcount);
  static if (Polygon.HasNormal) bool normalWarning = false;
  // read polygons
  foreach (ref Polygon p; plys) {
    // number of vertices
    uint vcount = fi.readNum!ushort;
    if (vcount < 3) throw new Exception("invalid polygon soup file");
    Vertex[] pvt;
    pvt.unsafeArraySetLength(vcount);
    // vertices
    foreach (ref Vertex v; pvt) {
      // coords
      v.pos.x = fi.readNum!(Float)();
      v.pos.y = fi.readNum!(Float)();
      v.pos.z = fi.readNum!(Float)();
      // normal
      static if (Polygon.HasNormal) {
        if (hasNorms) {
          v.normal.x = fi.readNum!(Float)();
          v.normal.y = fi.readNum!(Float)();
          v.normal.z = fi.readNum!(Float)();
        } else {
          v.normal = Vec3(1, 0, 0);
          normalWarning = true;
        }
      } else {
        if (hasNorms) {
          // skip normal
          fi.readNum!(Float)();
          fi.readNum!(Float)();
          fi.readNum!(Float)();
        }
      }
    }
    p = new Polygon(pvt);
  }
  static if (Polygon.HasNormal) {
    if (normalWarning) {
      import core.stdc.stdio : stderr, fprintf;
      fprintf(stderr, "WARNING: CSG was compiled with normal support, but model contains no normals!");
    }
  }
  // done
  return CSG.fromPolygons(plys);
}


// ////////////////////////////////////////////////////////////////////////// //
CSG buildGourd () {
  return readPolySoup(VFile("gourd.pso.gz"));
}
