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
module ybdecomposer_sample;

import arsd.simpledisplay;

import iv.vfs.io;
import iv.vmath;

import iv.vmath2d.math2d;
import iv.vmath2d.vxstore;
import iv.vmath2d.creatori;
import iv.vmath2d.ybdecomposer;


enum winWidth = 1280;
enum winHeight = 1024;
VertexStorage!vec2 incPoly;
VertexStorage!vec2[] polys;
int mouseX, mouseY;
bool polyComplete = false;
vec2 splitA = vec2.Invalid, splitB = vec2.Invalid;


void glColor1i(int c, ubyte a) {
  glColor4ub((c >> 16) & 0xff, (c >> 8) & 0xff, c & 0xff, a);
}


void main () {
  //srand((unsigned) time(0));
  uint[$] colors = [0xff0000, 0x00ff00, 0x0000ff, 0xffff00, 0xff00ff, 0x00ffff, 0xff8800];

  auto sdwin = new SimpleWindow(winWidth, winHeight, "polytest", OpenGlOptions.yes);

  sdwin.visibleForTheFirstTime = delegate () {
    import iv.glbinds;
    // initialize opengl
    sdwin.setAsCurrentOpenGlContext();
    oglSetup2D(winWidth, winHeight);
    glLineWidth(1.5);
    glPointSize(5);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glEnable(GL_LINE_SMOOTH);
    glEnable(GL_POINT_SMOOTH);
  };

  sdwin.redrawOpenGlScene = delegate () {
    import iv.glbinds;

    oglSetup2D(winWidth, winHeight);
    glLineWidth(1.5);
    glPointSize(5);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glEnable(GL_LINE_SMOOTH);
    glEnable(GL_POINT_SMOOTH);

    // render
    glClear(GL_COLOR_BUFFER_BIT);

    if (!polyComplete) {
      if (incPoly.length > 0) {
        glColor3f(1, 1, 1);
        glPointSize(8);
        glLineWidth(3);

        glBegin(GL_LINE_STRIP);
        for (int i = 0; i < incPoly.length; ++i) {
          glVertex2f(incPoly[i].x, incPoly[i].y);
        }
        glEnd();

        glBegin(GL_POINTS);
        for (int i = 0; i < incPoly.length; ++i) {
          glVertex2f(incPoly[i].x, incPoly[i].y);
        }
        glEnd();

        // line to cursor
        glLineWidth(1.5);
        glColor4f(1, 1, 1, .5);
        glBegin(GL_LINES);
        glVertex2f(incPoly[-1].x, incPoly[-1].y);
        glVertex2f(mouseX, mouseY);
        glEnd();
      }
    } else {
      // colored polygons
      for (int i = 0; i < polys.length; ++i) {
        glColor1i(colors[i % colors.length], 64);
        glBegin(GL_POLYGON);
        for (int j = 0; j < polys[i].length; ++j) {
          glVertex2f(polys[i][j].x, polys[i][j].y);
        }
        glEnd();
      }

      // polygon outlines (thin)
      for (int i = 0; i < polys.length; ++i) {
        glColor3f(1, 1, 1);
        glLineWidth(1.5);
        glBegin(GL_LINE_LOOP);
        for (int j = 0; j < polys[i].length; ++j) {
          glVertex2f(polys[i][j].x, polys[i][j].y);
        }
        glEnd();
      }

      // original polygon and points
      glColor3f(1, 1, 1);
      glPointSize(8);
      glLineWidth(3);

      glBegin(GL_LINE_LOOP);
      for (int i = 0; i < incPoly.length; ++i) {
        glVertex2f(incPoly[i].x, incPoly[i].y);
      }
      glEnd();

      glBegin(GL_POINTS);
      for (int i = 0; i < incPoly.length; ++i) {
        glVertex2f(incPoly[i].x, incPoly[i].y);
      }
      glEnd();
    }

    if (splitA.valid) {
      glColor3f(1, 0, 0);
      glPointSize(8);
      glLineWidth(3);

      glBegin(GL_LINES);
      glVertex2f(splitA.x, splitA.y);
      if (splitB.valid) glVertex2f(splitB.x, splitB.y); else glVertex2f(mouseX, mouseY);
      glEnd();
    }
  };

  //sdwin.redrawOpenGlSceneNow();
  sdwin.eventLoop(1000/30,
    delegate () {
      sdwin.redrawOpenGlSceneNow();
    },
    delegate (KeyEvent event) {
      if (!event.pressed) return;
      if (event == "Escape" || event == "C-Q") { sdwin.close(); return; }
      if (event == "C-C") {
        incPoly.clear();
        polys = null;
        polyComplete = false;
        //steinerPoints = null;
        //reflexVertices = null;
      }
      if (event == "T") {
        polyComplete = true;
        polys = null;
        YBDecomposer!vec2.convexPartition(polys, incPoly);
        writeln("generated ", polys.length, " polygon", (polys.length != 1 ? "s" : ""));
        return;
      }
      if (event == "E") {
        polys = null;
        incPoly.clear();
        Creatori.ellipse(incPoly, 50, 110, 20);
        incPoly.moveTo(vec2(winWidth/2, winHeight/2));
        polyComplete = true;
        return;
      }
      if (event == "R") {
        polys = null;
        incPoly.clear();
        Creatori.roundedRect(incPoly, 110, 70, 10, 10, 6);
        incPoly.moveTo(vec2(winWidth/2, winHeight/2));
        polyComplete = true;
        return;
      }
      if (event == "C") {
        polys = null;
        incPoly.clear();
        Creatori.capsule(incPoly, 110, 20, 6);
        incPoly.moveTo(vec2(winWidth/2, winHeight/2));
        polyComplete = true;
        return;
      }
      if (event == "G") {
        polys = null;
        incPoly.clear();
        Creatori.gear(incPoly, 100, 8, 90, 18);
        incPoly.moveTo(vec2(winWidth/2, winHeight/2));
        polyComplete = true;
        return;
      }
    },
    delegate (MouseEvent event) {
      mouseX = event.x;
      mouseY = event.y;
      if (event.type == MouseEventType.buttonPressed && event.button == MouseButton.left) {
        if (!polyComplete) {
          if (incPoly.length < 3 || vec2(mouseX, mouseY).distanceSquared(incPoly[0]) > 100) {
            incPoly ~= vec2(mouseX, mouseY);
          }
        }
      }
      if (event.type == MouseEventType.buttonPressed && event.button == MouseButton.right) {
        polyComplete = true;
        polys = null;
        YBDecomposer!vec2.convexPartition(polys, incPoly);
        writeln("generated ", polys.length, " polygon", (polys.length != 1 ? "s" : ""));
      }
      if (event.type == MouseEventType.buttonPressed && event.button == MouseButton.middle) {
        if (!splitA.valid) {
          splitA = vec2(mouseX, mouseY);
        } else if (!splitB.valid) {
          splitB = vec2(mouseX, mouseY);
        } else {
          /*
          polyComplete = true;
          VertexStorage!vec2[] pp;
          foreach (ref px; polys) {
            auto first = Creatori!vec2.split(px, splitA, splitB);
            if (first.length) pp ~= first;
            if (px.length) pp ~= px;
          }
          polys = pp;
          */
          splitA = vec2.Invalid;
          splitB = vec2.Invalid;
        }
      }
    },
  );
}
