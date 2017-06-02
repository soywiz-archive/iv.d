import arsd.simpledisplay;
import iv.vfs.io;
import iv.vmath;
import iv.vmath_gjk2d_simple;


// ////////////////////////////////////////////////////////////////////////// //
final class Body2D(VT) if (IsVectorDim!(VT, 2)) {
  VT[] verts; // vertices
  VT[] norms; // normals
  VT centroid;

  // GJK interface
  VT position () const { return centroid; }

  // dumb O(n) support function, just brute force check all points
  VT support() (in auto ref VT dir) const {
    //dir = matRS_inverse*dir;
    VT furthestPoint = verts[0];
    auto maxDot = furthestPoint.dot(dir);
    foreach (const ref v; verts[1..$]) {
      auto d = v.dot(dir);
      if (d > maxDot) {
        maxDot = d;
        furthestPoint = v;
      }
    }
    //auto res = matRS*furthestPoint+pos; // convert support to world space
    return furthestPoint;
  }

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

    centroid = VT(0, 0, 0);
    // compute face normals
    norms.reserve(verts.length);
    foreach (immutable i1; 0..verts.length) {
      centroid += verts[i1];
      immutable i2 = (i1+1)%verts.length;
      auto face = verts[i2]-verts[i1];
      // ensure no zero-length edges, because that's bad
      assert(face.lengthSquared > EPSILON!(VT.Float)*EPSILON!(VT.Float));
      // calculate normal with 2D cross product between vector and scalar
      norms ~= VT(face.y, -face.x).normalized;
    }
    centroid /= cast(VT.Float)verts.length;
    assert(isConvex);
  }

  bool isConvex () const {
    static int sign() (VT.Float v) { pragma(inline, true); return (v < 0 ? -1 : v > 0 ? 1 : 0); }
    if (verts.length < 3) return false;
    if (verts.length == 3) return true; // nothing to check here
    int dir;
    foreach (immutable idx, const ref v; verts) {
      immutable v1 = VT(verts[(idx+1)%verts.length])-v;
      immutable v2 = VT(verts[(idx+2)%verts.length]);
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
    centroid += delta;
  }

  void moveBy() (VT.Float dx, VT.Float dy, VT.Float dz=0) { moveBy(VT(dx, dy, dz)); }

  bool inside() (in auto ref VT p) const {
    static int sign() (VT.Float v) { pragma(inline, true); return (v < 0 ? -1 : v > 0 ? 1 : 0); }
    if (verts.length < 3) return false;
    int side = 0;
    foreach (immutable idx, const ref v; verts) {
      immutable as = verts[(idx+1)%verts.length]-v;
      immutable ap = p-v;
      int d = sign(as.cross(ap));
      if (d != 0) {
        if (side == 0) side = d; else if (side != d) return false;
      }
    }
    return true;
  }

  bool inside() (VT.Float x, VT.Float y) const { return inside(VT(x, y)); }
}


// ////////////////////////////////////////////////////////////////////////// //
auto generateBody () {
  import std.random;
  vec2[] vtx;
  foreach (immutable _; 0..uniform!"[]"(3, 20)) vtx ~= vec2(uniform!"[]"(-50, 50), uniform!"[]"(-50, 50));
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

  int fhigh = -1;
  bool checkCollision = true;

  void repaint () {
    auto pt = sdwin.draw();
    pt.fillColor = Color.black;
    pt.outlineColor = Color.black;
    pt.drawRectangle(Point(0, 0), sdwin.width, sdwin.height);
    pt.outlineColor = Color.white;

    void drawVL(VT) (in auto ref VT v0, in auto ref VT v1) if (IsVectorDim!(VT, 2)) {
      pt.drawLine(Point(cast(int)v0.x, cast(int)v0.y), Point(cast(int)v1.x, cast(int)v1.y));
    }

    void drawPoint(VT) (in auto ref VT v) if (IsVector!VT) {
      immutable v0 = v-2;
      immutable v1 = v+2;
      pt.drawEllipse(Point(cast(int)v0.x, cast(int)v0.y), Point(cast(int)v1.x, cast(int)v1.y));
    }

    void drawBody(BT) (BT flesh) if (is(BT == Body2D!VT, VT)) {
      foreach (immutable int idx; 0..cast(int)flesh.verts.length) {
        immutable v0 = flesh.verts[idx];
        immutable v1 = flesh.verts[(idx+1)%cast(int)flesh.verts.length];
        drawVL(v0, v1);
      }
      drawPoint(flesh.centroid);
    }

    bool collided = false;
    vec2 mtv;
    vec2 snorm, p0, p1;

    if (checkCollision) {
      collided = gjk(flesh0, flesh1, &mtv);
      if (collided) {
        writeln("COLLISION! mtv=", mtv);
      } else {
        auto dist = gjkdist(flesh0, flesh1, &p0, &p1, &snorm);
        if (dist < 0) {
          writeln("FUCKED DIST! dist=", dist);
        } else {
          writeln("distance=", dist);
          pt.outlineColor = Color.green;
          drawVL(flesh0.position, flesh0.position+snorm*dist);
        }
      }
    }

    pt.outlineColor = (fhigh == 0 ? Color.green : collided ? Color.red : Color.white);
    drawBody(flesh0);
    pt.outlineColor = (fhigh == 1 ? Color.green : collided ? Color.red : Color.white);
    drawBody(flesh1);

    if (collided) {
      pt.outlineColor = Color(128, 0, 0);
      flesh0.moveBy(-mtv);
      drawBody(flesh0);
      flesh0.moveBy(mtv);

      pt.outlineColor = Color(64, 0, 0);
      flesh1.moveBy(mtv);
      drawBody(flesh1);
      flesh1.moveBy(-mtv);
    } else {
      pt.outlineColor = Color.green;
      drawPoint(p0);
      drawPoint(p1);
    }
  }

  repaint();
  sdwin.eventLoop(0,
    delegate (KeyEvent event) {
      if (!event.pressed) return;
      if (event == "C-Q") { sdwin.close(); return; }
      if (event == "C-R") {
        // regenerate bodies
        fhigh = -1;
        flesh0 = generateBody();
        flesh1 = generateBody();
        flesh0.moveBy(350, 450);
        flesh1.moveBy(250, 350);
        repaint();
        return;
      }
    },
    delegate (MouseEvent event) {
      int oldhi = fhigh;
      if (event.type == MouseEventType.buttonPressed && event.button == MouseButton.left) {
        ubyte hp = 0;
        if (flesh0.inside(event.x, event.y)) hp |= 1;
        if (flesh1.inside(event.x, event.y)) hp |= 2;
        if (hp) {
               if (hp == 1) fhigh = 0;
          else if (hp == 2) fhigh = 1;
          else {
            assert(hp == 3);
            // choose one with the closest centroid
            fhigh = (flesh0.centroid.distanceSquared(vec2(event.x, event.y)) < flesh1.centroid.distanceSquared(vec2(event.x, event.y)) ? 0 : 1);
          }
        } else {
          fhigh = -1;
        }
        if (oldhi != fhigh) {
          checkCollision = (fhigh == -1);
          repaint();
        }
        return;
      }
      if (fhigh != -1 && event.type == MouseEventType.motion && (event.modifierState&ModifierState.leftButtonDown) != 0) {
             if (fhigh == 0) flesh0.moveBy(event.dx, event.dy);
        else if (fhigh == 1) flesh1.moveBy(event.dx, event.dy);
        checkCollision = (fhigh == -1);
        repaint();
        return;
      }
      if (event.type == MouseEventType.buttonReleased && event.button == MouseButton.left) {
        if (fhigh != -1) {
          fhigh = -1;
          checkCollision = true;
          repaint();
        }
      }
    },
  );
}
