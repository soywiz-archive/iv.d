//
// Copyright (c) 2013 Mikko Mononen memon@inside.org
//
// This software is provided 'as-is', without any express or implied
// warranty.  In no event will the authors be held liable for any damages
// arising from the use of this software.
// Permission is granted to anyone to use this software for any purpose,
// including commercial applications, and to alter it and redistribute it
// freely, subject to the following restrictions:
// 1. The origin of this software must not be misrepresented; you must not
//    claim that you wrote the original software. If you use this software
//    in a product, an acknowledgment in the product documentation would be
//    appreciated but is not required.
// 2. Altered source versions must be plainly marked as such, and must not be
//    misrepresented as being the original software.
// 3. This notice may not be removed or altered from any source distribution.
//
import core.stdc.stdio;
import iv.nanovg;
import iv.nanovg.perf;
import demo;

import arsd.simpledisplay;
import arsd.color;
import arsd.png;
import arsd.jpeg;

version = nanovg_demo_msfonts;

enum GWidth = 1000;
enum GHeight = 600;


bool blowup = false;
bool screenshot = false;
bool premult = false;


void main () {
  import core.time;

  //auto c = nvgHSLA(0.5, 0.5, 0.5, 255);

  DemoData data;
  NVGContext vg = null;
  PerfGraph fps;

  double mx = 0, my = 0;
  bool doQuit = false;

  //setOpenGLContextVersion(3, 2); // up to GLSL 150
  setOpenGLContextVersion(2, 0); // it's enough
  //openGLContextCompatible = false;

  auto sdwindow = new SimpleWindow(GWidth, GHeight, "NanoVG", OpenGlOptions.yes, Resizability.fixedSize);
  //sdwindow.hideCursor();

  version(X11) sdwindow.closeQuery = delegate () { doQuit = true; };

  void closeWindow () {
    if (!sdwindow.closed && vg !is null) {
      freeDemoData(vg, &data);
      vg.deleteGL2();
      vg = null;
      sdwindow.close();
    }
  }

  auto stt = MonoTime.currTime;
  auto prevt = MonoTime.currTime;
  auto curt = prevt;
  float dt = 0, secs = 0;
  //int mxOld = -1, myOld = -1;

  sdwindow.redrawOpenGlScene = delegate () {
    // timers
    prevt = curt;
    curt = MonoTime.currTime;
    secs = cast(double)((curt-stt).total!"msecs")/1000.0;
    dt = cast(double)((curt-prevt).total!"msecs")/1000.0;

    // Update and render
    //glViewport(0, 0, fbWidth, fbHeight);
    if (premult) glClearColor(0, 0, 0, 0); else glClearColor(0.3f, 0.3f, 0.32f, 1.0f);
    glClear(glNVGClearFlags);

    if (vg !is null) {
      if (fps !is null) fps.update(dt);
      vg.beginFrame(GWidth, GHeight, 1);
      renderDemo(vg, mx, my, GWidth, GHeight, secs, blowup, &data);
      if (fps !is null) fps.render(vg, 5, 5);
      vg.endFrame();
    }
  };

  sdwindow.visibleForTheFirstTime = delegate () {
    sdwindow.setAsCurrentOpenGlContext(); // make this window active
    sdwindow.vsync = false;
    //sdwindow.useGLFinish = false;
    //glbindLoadFunctions();

    vg = createGL2NVG(
      NVG_ANTIALIAS|
      NVG_STENCIL_STROKES|
      NVG_FONT_NOAA|
      //NVG_DEBUG|
      0);
    if (vg is null) assert(0, "Could not init nanovg.");
    if (loadDemoData(vg, &data) == -1) {
      //sdwindow.close();
      import std.stdio;
      writeln("cannot load demo data");
      freeDemoData(vg, &data);
      vg.deleteGL2();
      vg = null;
      return;
    }
    fps = new PerfGraph("Frame Time", PerfGraph.Style.FPS, "sans");
    sdwindow.redrawOpenGlScene();
  };

  sdwindow.eventLoop(1000/35,
    delegate () {
      if (sdwindow.closed) return;
      if (doQuit) { closeWindow(); return; }
      sdwindow.redrawOpenGlSceneNow();
    },
    delegate (KeyEvent event) {
      if (sdwindow.closed) return;
      if (!event.pressed) return;
      switch (event.key) {
        case Key.Escape: sdwindow.close(); break;
        case Key.Space: blowup = !blowup; break;
        case Key.P: premult = !premult; break;
        default:
      }
    },
    delegate (MouseEvent event) {
      mx = event.x;
      my = event.y;
      if (event.type == MouseEventType.buttonPressed) {
        if (event.button == MouseButton.right) {
          if (wgOnTop) {
                 if (inWidget(mx, my)) { wgMoving = true; bndMoving = false; wgOnTop = true; }
            else if (inBnd(mx, my)) { wgMoving = false; bndMoving = true; wgOnTop = false; }
            else { wgMoving = false; bndMoving = false; }
          } else {
                 if (inBnd(mx, my)) { wgMoving = false; bndMoving = true; wgOnTop = false; }
            else if (inWidget(mx, my)) { wgMoving = true; bndMoving = false; wgOnTop = true; }
            else { wgMoving = false; bndMoving = false; }
          }
        }
        if (event.button == MouseButton.left) {
          if (wgOnTop) {
                 if (inWidget(mx, my)) wgOnTop = true;
            else if (inBnd(mx, my)) wgOnTop = false;
          } else {
                 if (inBnd(mx, my)) wgOnTop = false;
            else if (inWidget(mx, my)) wgOnTop = true;
          }
        }
      } else if (event.type == MouseEventType.buttonReleased) {
        if (event.button == MouseButton.right) { wgMoving = false; bndMoving = false; }
      } else if (event.type == MouseEventType.motion) {
        if (bndMoving) { bndX += event.dx; bndY += event.dy; }
        if (wgMoving) { wgX += event.dx; wgY += event.dy; }
      }
      if (inBnd(mx, my) || inWidget(mx, my)) mx = my = -666;
    },
    delegate (dchar ch) {
      if (ch == 'q') { doQuit = true; return; }
    },
  );
  closeWindow();
}
