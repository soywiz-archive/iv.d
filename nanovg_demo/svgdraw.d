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
import iv.nanovg.svg;
import iv.nanovg.perf;

import arsd.simpledisplay;
import arsd.color;
import arsd.png;
import arsd.jpeg;


__gshared int GWidth = 640;
__gshared int GHeight = 480;


void main (string[] args) {
  import core.time;

  NVGContext vg = null;
  PerfGraph fps;

  NSVG* svg = nsvgParseFromFile(args.length > 1 ? args[1] : "data/svg/tiger.svg");
  scope(exit) svg.kill();

  //writefln("size: %f x %f", svg.width, svg.height);
  GWidth = cast(int)svg.width;
  GHeight = cast(int)svg.height;
  if (GWidth < 32) GWidth = 32;
  if (GHeight < 32) GHeight = 32;

  int vgimg;


  bool doQuit = false;

  //setOpenGLContextVersion(3, 2); // up to GLSL 150
  setOpenGLContextVersion(2, 0); // it's enough
  //openGLContextCompatible = false;

  auto sdwindow = new SimpleWindow(GWidth, GHeight, "NanoSVG", OpenGlOptions.yes, Resizablity.fixedSize);
  //sdwindow.hideCursor();

  sdwindow.closeQuery = delegate () { doQuit = true; };

  void closeWindow () {
    if (!sdwindow.closed && vg !is null) {
      vg.deleteImage(vgimg);
      vgimg = -1;
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
    //glClearColor(0, 0, 0, 0);
    glClearColor(0.3, 0.3, 0.3, 0);
    glClear(glNVGClearFlags);

    if (vg !is null) {
      if (fps !is null) fps.update(dt);
      vg.beginFrame(GWidth, GHeight);
      { // draw image
        vg.beginPath();
        vg.rect(0, 0, GWidth, GHeight);
        vg.fillPaint(vg.imagePattern(0, 0, GWidth, GHeight, 0, vgimg, 1));
        vg.fill();
      }
      if (fps !is null) fps.render(vg, 5, 5);
      vg.endFrame();
    }
  };

  sdwindow.visibleForTheFirstTime = delegate () {
    sdwindow.setAsCurrentOpenGlContext(); // make this window active
    sdwindow.vsync = false;
    //sdwindow.useGLFinish = false;
    //glbindLoadFunctions();

    vg = createGL2NVG(NVG_ANTIALIAS|NVG_STENCIL_STROKES|NVG_DEBUG);
    if (vg is null) {
      import std.stdio;
      writeln("Could not init nanovg.");
      //sdwindow.close();
    }
    enum FNN = "/home/ketmar/ttf/ms/arial.ttf";
    vg.createFont("sans", FNN);
    {
      ubyte[] svgraster;
      scope(exit) svgraster.destroy;
      {
        auto rst = nsvgCreateRasterizer();
        scope(exit) rst.kill();
        svgraster = new ubyte[](GWidth*GHeight*4);
        rst.rasterize(svg,
          0, 0, // ofs
          1, // scale
          svgraster.ptr, GWidth, GHeight);
      }
      vgimg = vg.createImageRGBA(GWidth, GHeight, 0, svgraster.ptr);
    }
    fps = new PerfGraph("Frame Time", PerfGraph.Style.FPS, "sans");
    sdwindow.redrawOpenGlScene();
  };

  sdwindow.eventLoop(1000/62,
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
        default:
      }
    },
    delegate (MouseEvent event) {
    },
    delegate (dchar ch) {
      if (ch == 'q') { doQuit = true; return; }
    },
  );
  closeWindow();
}
