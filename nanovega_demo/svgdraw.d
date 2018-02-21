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
import iv.nanovega;
import iv.nanovega.svg;
import iv.nanovega.perf;

import arsd.simpledisplay;
import arsd.color;
import arsd.png;
import arsd.jpeg;


// ////////////////////////////////////////////////////////////////////////// //
enum PathMode { EvenOdd, Flipping, AllHoles, NoHoles }

void render (NVGContext nvg, const(NSVG)* image, PathMode pathMode=PathMode.Flipping) {
  NVGPaint createLinearGradient (const(NSVG.Gradient)* gradient, float a) {
    float[6] inverse = void;
    float sx, sy, ex, ey;

    nvgTransformInverse(inverse[], gradient.xform[]);
    nvgTransformPoint(&sx, &sy, inverse[], 0, 0);
    nvgTransformPoint(&ex, &ey, inverse[], 0, 1);

    if (a < 0) a = 0; else if (a > 1) a = 1;
    uint aa = cast(uint)(0xff*a)<<24;
    return nvg.linearGradient(sx, sy, ex, ey,
      NVGColor.fromUint((gradient.stops.ptr[0].color&0xffffff)|aa),
      NVGColor.fromUint((gradient.stops.ptr[gradient.nstops-1].color&0xffffff)|aa));
  }

  NVGPaint createRadialGradient (const(NSVG.Gradient)* gradient, float a) {
    float[6] inverse = void;
    float cx, cy, r1, r2;

    nvgTransformInverse(inverse[], gradient.xform[]);
    nvgTransformPoint(&cx, &cy, inverse[], 0, 0);
    nvgTransformPoint(&r1, &r2, inverse[], 0, 1);
    immutable float outr = r2-cy;
    immutable float inr = (gradient.nstops == 3 ? gradient.stops.ptr[1].offset*outr : 0);

    if (a < 0) a = 0; else if (a > 1) a = 1;
    uint aa = cast(uint)(0xff*a)<<24;
    return nvg.radialGradient(cx, cy, inr, outr,
      NVGColor.fromUint((gradient.stops.ptr[0].color&0xffffff)|aa),
      NVGColor.fromUint((gradient.stops.ptr[gradient.nstops-1].color&0xffffff)|aa));
  }

  nvg.save();
  scope(exit) nvg.restore();
  if (pathMode == PathMode.EvenOdd) nvg.evenOddFill(); else nvg.nonZeroFill();

  // iterate shapes
  image.forEachShape((in ref NSVG.Shape shape) {
    // skip invisible shape
    if (!shape.visible) return;

    // draw paths
    nvg.beginPath();
    bool pathHole = false;
    shape.forEachPath((in ref NSVG.Path path) {
      nvg.moveTo(path.pts[0], path.pts[1]);
      for (int i = 0; i < path.npts-1; i += 3) {
        const(float)* p = &path.pts[i*2];
        nvg.bezierTo(p[2], p[3], p[4], p[5], p[6], p[7]);
      }
      if (path.closed) nvg.lineTo(path.pts[0], path.pts[1]);
      if (pathMode != PathMode.EvenOdd && pathHole) nvg.pathWinding(NVGSolidity.Hole); else nvg.pathWinding(NVGSolidity.Solid);
      final switch (pathMode) {
        case PathMode.EvenOdd: break;
        case PathMode.Flipping: pathHole = !pathHole; break;
        case PathMode.AllHoles: pathHole = true; break;
        case PathMode.NoHoles: break;
      }
    });

    // fill
    switch (shape.fill.type) {
      case NSVG.PaintType.Color:
        if (shape.opacity > 0) {
          nvg.fillColor(NVGColor.fromUint(shape.fill.color));
          nvg.fill();
        }
        break;
      case NSVG.PaintType.LinearGradient:
        if (shape.opacity > 0) {
          nvg.fillPaint(createLinearGradient(shape.fill.gradient, shape.opacity));
          nvg.fill();
        }
        break;
      case NSVG.PaintType.RadialGradient:
        if (shape.opacity > 0) {
          nvg.fillPaint(createRadialGradient(shape.fill.gradient, shape.opacity));
          nvg.fill();
        }
        break;
      default:
        break;
    }

    // set stroke/line
    NVGLineCap join;
    switch (shape.strokeLineJoin) {
      case NSVG.LineJoin.Round: join = NVGLineCap.Round; break;
      case NSVG.LineJoin.Bevel: join = NVGLineCap.Bevel; break;
      case NSVG.LineJoin.Miter: goto default;
      default: join = NVGLineCap.Miter; break;
    }
    NVGLineCap cap;
    switch (shape.strokeLineCap) {
      case NSVG.LineCap.Butt: cap = NVGLineCap.Butt; break;
      case NSVG.LineCap.Round: cap = NVGLineCap.Round; break;
      case NSVG.LineCap.Square: cap = NVGLineCap.Square; break;
      default: cap = NVGLineCap.Square; break;
    }

    nvg.lineJoin(join);
    nvg.lineCap(cap);
    nvg.strokeWidth(shape.strokeWidth);

    // draw line
    switch (shape.stroke.type) {
      case NSVG.PaintType.Color:
        if (shape.opacity > 0) {
          nvg.strokeColor(NVGColor.fromUint(shape.stroke.color));
          nvg.stroke();
        }
        break;
      case NSVG.PaintType.LinearGradient:
        if (shape.opacity > 0) {
          nvg.strokePaint(createLinearGradient(shape.stroke.gradient, shape.opacity));
          nvg.stroke();
        }
        break;
      case NSVG.PaintType.RadialGradient:
        if (shape.opacity > 0) {
          nvg.strokePaint(createRadialGradient(shape.stroke.gradient, shape.opacity));
          nvg.stroke();
        }
        break;
      default:
        break;
    }
  });
}


// ////////////////////////////////////////////////////////////////////////// //
__gshared int GWidth = 640;
__gshared int GHeight = 480;
__gshared bool useDirectRendering = false;


// ////////////////////////////////////////////////////////////////////////// //
void main (string[] args) {
  import core.time;

  NVGContext vg = null;
  PerfGraph fps;

  int minw = 32, minh = 32;
  int defw = 256, defh = 256;
  int addw = 0, addh = 0;
  string fname;
  for (usize idx = 1; idx < args.length; ++idx) {
    import std.conv : to;
    string a = args[idx];
    if (a == "-w" || a == "-h") {
      char d = a[1];
      a = a[2..$];
      if (a.length == 0) {
        ++idx;
        if (idx >= args.length) assert(0, "out of args");
        a = args[idx];
      }
      if (d == 'w') defw = minw = to!int(a); else defh = minh = to!int(a);
    } else if (a.length > 2 && a[0] == '0' && (a[1] == 'w' || a[1] == 'h')) {
      if (a[1] == 'w') defw = minw = to!int(a); else defh = minh = to!int(a);
    } else if (a == "--width") {
      ++idx;
      if (idx >= args.length) assert(0, "out of args");
      defw = minw = to!int(args[idx]);
    } else if (a == "--height") {
      ++idx;
      if (idx >= args.length) assert(0, "out of args");
      defh = minh = to!int(args[idx]);
    } else if (a == "--addw") {
      ++idx;
      if (idx >= args.length) assert(0, "out of args");
      addw = to!int(args[idx]);
    } else if (a == "--addh") {
      ++idx;
      if (idx >= args.length) assert(0, "out of args");
      addh = to!int(args[idx]);
    } else if (a == "--nvg") {
      useDirectRendering = true;
    } else if (a == "--svg") {
      useDirectRendering = false;
    } else if (a == "--") {
      ++idx;
      if (idx >= args.length) assert(0, "out of args");
      fname = args[idx];
      break;
    } else {
      if (fname !is null) assert(0, "too many filenames");
      fname = args[idx];
    }
  }
  if (fname.length == 0) assert(0, "no filename");

  NSVG* svg;
  scope(exit) svg.kill();
  {
    import std.stdio : writeln;
    import core.time, std.datetime;
    auto stt = MonoTime.currTime;
    svg = nsvgParseFromFile(fname, "px", 96, defw, defh);
    if (svg is null) assert(0, "svg parsing error");
    auto dur = (MonoTime.currTime-stt).total!"msecs";
    writeln("loading took ", dur, " milliseconds (", dur/1000.0, " seconds)");
    { import std.stdio; writeln(args.length > 1 ? args[1] : "data/svg/tiger.svg"); }
  }

  printf("size: %f x %f\n", cast(double)svg.width, cast(double)svg.height);
  GWidth = cast(int)svg.width+addw;
  GHeight = cast(int)svg.height+addh;
  if (GWidth < minw) GWidth = minw;
  if (GHeight < minh) GHeight = minh;

  int vgimg;


  bool doQuit = false;
  bool drawFPS = false;

  //setOpenGLContextVersion(3, 2); // up to GLSL 150
  setOpenGLContextVersion(2, 0); // it's enough
  //openGLContextCompatible = false;

  auto sdwindow = new SimpleWindow(GWidth, GHeight, "NanoSVG", OpenGlOptions.yes, Resizability.fixedSize);
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
  PathMode pathMode = PathMode.min;
  bool svgAA = true;

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
      scope(exit) vg.endFrame();

      if (useDirectRendering) {
        vg.save();
        scope(exit) vg.restore();
        vg.shapeAntiAlias = svgAA;
        vg.render(svg, pathMode);
      } else {
        // draw image
        vg.save();
        scope(exit) vg.restore();
        vg.beginPath();
        vg.rect(0, 0, GWidth, GHeight);
        vg.fillPaint(vg.imagePattern(0, 0, GWidth, GHeight, 0, vgimg, 1));
        vg.fill();
      }

      //vg.endFrame(); // flush rendering
      //vg.beginFrame(GWidth, GHeight); // restart frame

      vg.fontFace("sans");
      vg.fontSize(14);
      vg.textAlign(NVGTextAlign(NVGTextAlign.H.Left, NVGTextAlign.V.Top));

      {
        vg.newPath();
        float[4] b;
        //vg.textBounds(10, 10, "D", b[]);
        //printf("b=[%g, %g, %g, %g]\n", cast(double)b[0], cast(double)b[1], cast(double)b[2], cast(double)b[3]);
        //printf("tw=%g : %g\n", cast(double)vg.textWidth("Direct"), cast(double)vg.textWidth("Image"));
        auto tw = nvg__max(vg.textWidth("Direct"), vg.textWidth("Image"));
        foreach (string nn; __traits(allMembers, PathMode)) tw = nvg__max(tw, vg.textWidth(nn));
        vg.save();
        scope(exit) vg.restore();
        //vg.globalCompositeBlendFunc(NVGBlendFactor.ZERO, NVGBlendFactor.SRC_ALPHA);
        //vg.scissor(0, 0, tw+1, 71);
        vg.rect(0.5, 0.5, tw+20, 70);
        vg.fillColor(NVGColor("#8000"));
        vg.fill();
        //printf("tw=%g\n", cast(double)tw);
      }

      vg.fillColor(NVGColor.white);
      vg.text(10, 10, (useDirectRendering ? "Direct" : "Image"));
      vg.text(10, 30, (svgAA ? "AA" : "NO AA"));
      import std.conv : to;
      vg.text(10, 50, pathMode.to!string);

      if (fps !is null && drawFPS) fps.render(vg, 5, 5);
    }
  };

  sdwindow.visibleForTheFirstTime = delegate () {
    sdwindow.setAsCurrentOpenGlContext(); // make this window active
    sdwindow.vsync = false;
    //sdwindow.useGLFinish = false;
    //glbindLoadFunctions();

    vg = createGL2NVG(NVG_ANTIALIAS|NVG_STENCIL_STROKES);
    if (vg is null) {
      import std.stdio;
      writeln("Could not init nanovg.");
      //sdwindow.close();
    }
    enum FNN = "Verdana:noaa"; //"/home/ketmar/ttf/ms/verdana.ttf";
    vg.createFont("sans", FNN);
    {
      ubyte[] svgraster;
      scope(exit) svgraster.destroy;
      {
        import std.stdio : writeln;
        auto rst = nsvgCreateRasterizer();
        scope(exit) rst.kill();
        svgraster = new ubyte[](GWidth*GHeight*4);
        import core.time, std.datetime;
        auto stt = MonoTime.currTime;
        writeln("rasterizing...");
        rst.rasterize(svg,
          addw/2, addh/2, // ofs
          1, // scale
          svgraster.ptr, GWidth, GHeight);
        auto dur = (MonoTime.currTime-stt).total!"msecs";
        writeln("rasterizing took ", dur, " milliseconds (", dur/1000.0, " seconds)");
      }
      vgimg = vg.createImageRGBA(GWidth, GHeight, svgraster[]);
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
      if (event == "Escape" || event == "C-Q") { sdwindow.close(); return; }
      if (event == "D" || event == "V") { useDirectRendering = !useDirectRendering; sdwindow.redrawOpenGlScene(); return; }
      if (event == "A") { svgAA = !svgAA; if (useDirectRendering) sdwindow.redrawOpenGlScene(); return; }
      if (event == "F") {
        if (pathMode == PathMode.max) pathMode = PathMode.min; else ++pathMode;
        if (useDirectRendering) sdwindow.redrawOpenGlScene();
        return;
      }
      if (event == "Space") { drawFPS = !drawFPS; return; }
    },
    delegate (MouseEvent event) {
    },
    delegate (dchar ch) {
      //if (ch == 'q') { doQuit = true; return; }
    },
  );
  closeWindow();
}