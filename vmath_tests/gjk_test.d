import arsd.simpledisplay;
import iv.vfs.io;
import iv.vmath;
import iv.vmath_gjk;


// ////////////////////////////////////////////////////////////////////////// //
alias GJK = GJKImpl!vec2;


// ////////////////////////////////////////////////////////////////////////// //
final class Body2D(VT) if (IsVectorDim!(VT, 2)) {
  VT[] verts; // vertices
  VT[] norms; // normals

  // GJK interface
  int vertCount () const nothrow @nogc { pragma(inline, true); return cast(int)verts.length; }
  VT vert (int idx) const nothrow @nogc { pragma(inline, true); return verts[idx]; }
  int ringCount () const nothrow @nogc { pragma(inline, true); return cast(int)(verts.length+1); }
  int ring (int idx) const nothrow @nogc { pragma(inline, true); return (idx < verts.length ? idx : -1); }

  void setVerts (const(VT)[] aaverts, VT.Float arot=0) {
    // no hulls with less than 3 vertices (ensure actual polygon)
    if (aaverts.length < 3) throw new Exception("degenerate body");

    // rotate vertices
    VT[] averts;
    averts.reserve(aaverts.length);
    auto rmat = Mat3!VT.Rotate(arot);
    foreach (const ref v; aaverts) averts ~= rmat*v;

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

    auto hull = new int[](averts.length);
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
        if (nextHullIndex == indexHull) {
          nextHullIndex = i;
          continue;
        }
        // cross every set of three unique vertices
        // record each counter clockwise third vertex and add to the output hull
        // See : http://www.oocities.org/pcgpe/math2d.html
        auto e1 = averts[nextHullIndex]-averts[hull[outCount]];
        auto e2 = averts[i]-averts[hull[outCount]];
        auto c = e1.cross(e2);
        if (c < 0.0f) nextHullIndex = i;

        // cross product is zero then e vectors are on same line
        // therefore want to record vertex farthest along that line
        if (c == 0.0f && e2.lengthSquared > e1.lengthSquared) nextHullIndex = i;
      }

      ++outCount;
      indexHull = nextHullIndex;

      // conclude algorithm upon wrap-around
      if (nextHullIndex == rightMost) {
        vcount = outCount;
        break;
      }
    }
    if (vcount < 3) throw new Exception("degenerate body");

    // copy vertices into shape's vertices
    verts.reserve(vcount);
    foreach (immutable i; 0..vcount) verts ~= averts[hull[i]];
    if (!isConvex()) throw new Exception("non-convex body");

    // compute face normals
    norms.reserve(verts.length);
    foreach (immutable i1; 0..verts.length) {
      immutable i2 = (i1+1)%verts.length;
      auto face = verts[i2]-verts[i1];
      // ensure no zero-length edges, because that's bad
      assert(face.lengthSquared > EPSILON!(VT.Float)*EPSILON!(VT.Float));
      // calculate normal with 2D cross product between vector and scalar
      norms ~= VT(face.y, -face.x).normalized;
    }
    assert(isConvex);
  }

  bool isConvex () {
    static int sign() (VT.Float v) { pragma(inline, true); return (v < 0 ? -1 : v > 0 ? 1 : 0); }
    if (verts.length < 3) return false;
    if (verts.length == 3) return true; // nothing to check here
    int dir;
    foreach (immutable idx, const ref v; verts) {
      auto v1 = VT(verts[(idx+1)%verts.length])-v;
      auto v2 = VT(verts[(idx+2)%verts.length]);
      int d = sign(v2.x*v1.y-v2.y*v1.x+v1.x*v.y-v1.y*v.x);
      if (d == 0) return false;
      if (idx) {
        if (dir != d) return false;
      } else {
        dir = d;
      }
    }
    return true;
  }

  void moveBy() (in auto ref VT delta) {
    foreach (ref v; verts) v += delta;
  }

  void moveBy() (VT.Float dx, VT.Float dy, VT.Float dz=0) { moveBy(VT(dx, dy, dz)); }
}


// ////////////////////////////////////////////////////////////////////////// //
auto generateBody () {
  import std.random;
  vec2[] vtx;
  foreach (immutable _; 0..uniform!"[]"(10, 50)) vtx ~= vec2(uniform!"[]"(-50, 50), uniform!"[]"(-50, 50));
  auto flesh = new Body2D!vec2();
  flesh.setVerts(vtx);
  return flesh;
}


static assert(IsGoodGJKObject!(Body2D!vec2, vec2));


// ////////////////////////////////////////////////////////////////////////// //
void main () {
  auto flesh0 = generateBody();
  auto flesh1 = generateBody();

  flesh0.moveBy(350, 450);
  flesh1.moveBy(250, 350);

  auto sdwin = new SimpleWindow(1024, 768, "GJK Test");

  void repaint () {
    auto pt = sdwin.draw();
    pt.fillColor = Color.black;
    pt.outlineColor = Color.black;
    pt.drawRectangle(Point(0, 0), sdwin.width, sdwin.height);
    pt.outlineColor = Color.white;

    void drawVL(VT) (in auto ref VT v0, in auto ref VT v1) if (IsVectorDim!(VT, 2)) {
      pt.drawLine(Point(cast(int)v0.x, cast(int)v0.y), Point(cast(int)v1.x, cast(int)v1.y));
    }

    void drawBody(BT) (BT flesh) if (is(BT == Body2D!VT, VT)) {
      foreach (immutable int idx; 0..cast(int)flesh.verts.length) {
        immutable v0 = flesh.verts[idx];
        immutable v1 = flesh.verts[(idx+1)%cast(int)flesh.verts.length];
        drawVL(v0, v1);
      }
    }

    void drawPoint(VT) (in auto ref VT v) if (IsVector!VT) {
      immutable v0 = v-2;
      immutable v1 = v+2;
      pt.drawEllipse(Point(cast(int)v0.x, cast(int)v0.y), Point(cast(int)v1.x, cast(int)v1.y));
    }

    {
      GJK gjk;

      /*
      GJK.VObject buildVObject(BT) (BT flesh) if (is(BT == Body2D!VT, VT)) {
        GJK.VObject obj;
        static if (GJK.Dims == 2) {
          obj.vertices = flesh.verts;
        } else {
          GJK.Vec[] vc;
          vc.length = flesh.verts.length;
          foreach (immutable idx, const ref v; flesh.verts) vc[idx] = GJK.Vec(v.x, v.y, 0);
          obj.vertices = vc;
        }
        version(all) {
          obj.rings.length = obj.vertices.length+1;
          foreach (immutable idx; 0..flesh.verts.length) obj.rings[idx] = cast(int)idx;
          obj.rings[$-1] = -1;
        }
        return obj;
      }
      auto o0 = buildVObject(flesh0);
      auto o1 = buildVObject(flesh1);
      */
      GJK.Vec wpt1, wpt2;
      auto res = gjk.distance(flesh0, flesh1, &wpt1, &wpt2);
      writeln("res=", res, "; wpt1=", wpt1, "; wpt2=", wpt2);
      writeln("  disp: ", gjk.simplex.disp);
      if (res < GJK.EPS) pt.outlineColor = Color.red;
      drawPoint(wpt1);
      drawPoint(wpt2);
    }

    drawBody(flesh0);
    drawBody(flesh1);

    /*
    pt.outlineColor = Color.yellow;
    drawPoint(GJK.extractPoint(0));
    drawPoint(GJK.extractPoint(1));
    */
  }

  repaint();
  sdwin.eventLoop(0,
    delegate (KeyEvent event) {
      if (!event.pressed) return;
      if (event == "C-Q") { sdwin.close(); return; }
    },
  );
}
