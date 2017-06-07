/* Gilbert-Johnson-Keerthi intersection algorithm with Expanding Polytope Algorithm
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
module gjk_sample;

import arsd.simpledisplay;

import iv.vfs.io;
import iv.vmath2d;


// ////////////////////////////////////////////////////////////////////////// //
void generateBody(VS) (ref VS flesh) if (IsGoodVertexStorage!VS) {
  alias VT = VertexStorageVT!VS;
  import std.random;
  flesh.clear();
  foreach (immutable _; 0..uniform!"[]"(3, 20)) flesh ~= VT(uniform!"[]"(-50, 50), uniform!"[]"(-50, 50));
  flesh.buildConvex();
}


static assert(IsGoodVertexStorage!(VertexStorage!vec2, vec2));


// ////////////////////////////////////////////////////////////////////////// //
void main () {
  VertexStorage!vec2 flesh0, flesh1;
  flesh0.generateBody();
  flesh1.generateBody();

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

    void drawBody(VS) (ref VS flesh) if (IsGoodVertexStorage!VS) {
      foreach (immutable int idx; 0..flesh.length) {
        immutable v0 = flesh[idx];
        immutable v1 = flesh[(idx+1)%cast(int)flesh.length];
        drawVL(v0, v1);
      }
      drawPoint(flesh.centroid);
    }

    bool collided = false;
    vec2 mtv;
    vec2 snorm, p0, p1;

    if (checkCollision) {
      collided = gjkcollide(flesh0, flesh1, &mtv);
      if (collided) {
        writeln("COLLISION! mtv=", mtv);
      } else {
        auto dist = gjkdistance(flesh0, flesh1, &p0, &p1, &snorm);
        if (dist < 0) {
          writeln("FUCKED DIST! dist=", dist);
        } else {
          writeln("distance=", dist);
          pt.outlineColor = Color.green;
          drawVL(flesh0.centroid, flesh0.centroid+snorm*dist);
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
      if (event == "C-Q" || event == "Escape") { sdwin.close(); return; }
      if (event == "C-R") {
        // regenerate bodies
        fhigh = -1;
        generateBody(flesh0);
        generateBody(flesh1);
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
