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
import iv.strex;
import iv.vfs;
import iv.vfs.util;

import arsd.simpledisplay;
import arsd.color;
import arsd.png;
import arsd.jpeg;


// ////////////////////////////////////////////////////////////////////////// //
__gshared int bezierCount = 0;
__gshared bool nativeGradients = true;
__gshared bool nativeFill = true;
__gshared bool nativeStroke = true;
__gshared bool nativeOnlyBeziers = false;

enum PathMode { Original, EvenOdd, Flipping, AllHoles, NoHoles }

void render (NVGContext nvg, const(NSVG)* image, PathMode pathMode=PathMode.Flipping) {
  NVGColor xcolor (uint clr, float a) {
    if (a <= 0 || (clr>>24) == 0) return NVGColor.transparent;
    if (a > 1) a = 1;
    float ca = (clr>>24)/255.0f;
    a *= ca;
    if (a <= 0) return NVGColor.transparent;
    if (a > 1) a = 1;
    uint aa = cast(uint)(0xff*a)<<24;
    return NVGColor.fromUint((clr&0xffffff)|aa);
  }

  NVGPaint createLinearGradient (const(NSVG.Gradient)* gradient, float a) {
    float[6] inverse = void;
    float sx, sy, ex, ey;

    nvgTransformInverse(inverse[], gradient.xform[]);
    nvgTransformPoint(&sx, &sy, inverse[], 0, 0);
    nvgTransformPoint(&ex, &ey, inverse[], 0, 1);

    return nvg.linearGradient(sx, sy, ex, ey,
             xcolor(gradient.stops.ptr[0].color, a),
             xcolor(gradient.stops.ptr[gradient.nstops-1].color, a));
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
             xcolor(gradient.stops.ptr[0].color, a),
             xcolor(gradient.stops.ptr[gradient.nstops-1].color, a));
  }

  nvg.save();
  scope(exit) nvg.restore();

  switch (pathMode) {
    case PathMode.Original: break;
    case PathMode.EvenOdd: nvg.evenOddFill(); break;
    default: nvg.nonZeroFill(); break;
  }

  // iterate shapes
  image.forEachShape((in ref NSVG.Shape shape) {
    // skip invisible shape
    if (!shape.visible) return;

    if (shape.fill.type == NSVG.PaintType.None && shape.stroke.type == NSVG.PaintType.None) return;
    if (shape.opacity <= 0) return;

    if (pathMode == PathMode.Original) {
      //{ import iv.vfs.io; writeln(shape.fillRule); }
      final switch (shape.fillRule) {
        case NSVG.FillRule.NonZero: nvg.nonZeroFill(); break;
        case NSVG.FillRule.EvenOdd: nvg.evenOddFill(); break;
      }
    }

    // draw paths
    nvg.beginPath();
    bool pathHole = false;
    shape.forEachPath((in ref NSVG.Path path) {
      if (nativeOnlyBeziers) {
        // get 2-arg for `moveTo` and 6-arg for `bezierTo`
        path.asCubics!true(delegate (const(float)[] args) nothrow @trusted @nogc {
          assert(args.length == 2 || args.length == 6);
          if (args.length == 2) {
            nvg.moveTo(args);
          } else {
            ++bezierCount;
            nvg.bezierTo(args);
          }
        });
        if (path.closed) nvg.lineTo(path.startX, path.startY);
      } else {
        path.forEachCommand!true(delegate (NSVG.Command cmd, const(float)[] args) nothrow @trusted @nogc {
          final switch (cmd) {
            case NSVG.Command.MoveTo: nvg.moveTo(args); break;
            case NSVG.Command.LineTo: nvg.lineTo(args); break;
            case NSVG.Command.QuadTo: nvg.quadTo(args); ++bezierCount; break;
            case NSVG.Command.BezierTo: nvg.bezierTo(args); ++bezierCount; break;
          }
        });
      }

      if (pathMode != PathMode.Original) {
        if (pathMode != PathMode.EvenOdd && pathHole) nvg.pathWinding(NVGSolidity.Hole); else nvg.pathWinding(NVGSolidity.Solid);
        final switch (pathMode) {
          case PathMode.Original: break;
          case PathMode.EvenOdd: break;
          case PathMode.Flipping: pathHole = !pathHole; break;
          case PathMode.AllHoles: pathHole = true; break;
          case PathMode.NoHoles: break;
        }
      }
    });

    // fill
    if (nativeFill) {
      switch (shape.fill.type) {
        case NSVG.PaintType.Color:
          nvg.fillColor(xcolor(shape.fill.color, shape.opacity));
          nvg.fill();
          break;
        case NSVG.PaintType.LinearGradient:
          if (nativeGradients) {
            nvg.fillPaint(createLinearGradient(shape.fill.gradient, shape.opacity));
            nvg.fill();
          }
          break;
        case NSVG.PaintType.RadialGradient:
          if (nativeGradients) {
            nvg.fillPaint(createRadialGradient(shape.fill.gradient, shape.opacity));
            nvg.fill();
          }
          break;
        default:
          break;
      }
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
    if (nativeStroke) {
      switch (shape.stroke.type) {
        case NSVG.PaintType.Color:
          nvg.strokeColor(xcolor(shape.stroke.color, shape.opacity));
          nvg.stroke();
          break;
        case NSVG.PaintType.LinearGradient:
          if (nativeGradients) {
            nvg.strokePaint(createLinearGradient(shape.stroke.gradient, shape.opacity));
            nvg.stroke();
          }
          break;
        case NSVG.PaintType.RadialGradient:
          if (nativeGradients) {
            nvg.strokePaint(createRadialGradient(shape.stroke.gradient, shape.opacity));
            nvg.stroke();
          }
          break;
        default:
          break;
      }
    }
  });
}


// ////////////////////////////////////////////////////////////////////////// //
__gshared int GWidth = 640;
__gshared int GHeight = 480;
__gshared bool useDirectRendering = true;


// ////////////////////////////////////////////////////////////////////////// //
void main (string[] args) {
  import core.time;

  NVGContext nvg = null;

  int minw = 32, minh = 32;
  int defw = 256, defh = 256;
  int addw = 0, addh = 0;
  bool stencilStrokes = true;
  bool contextAA = true;
  bool maxSize = false;
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
    } else if (a == "--nvg" || a == "--native") {
      useDirectRendering = true;
    } else if (a == "--svg" || a == "--raster") {
      useDirectRendering = false;
    } else if (a == "--stencil") {
      stencilStrokes = true;
    } else if (a == "--fast") {
      stencilStrokes = false;
    } else if (a == "--aa") {
      contextAA = true;
    } else if (a == "--noaa" || a == "--sharp") {
      contextAA = false;
    } else if (a == "--max") {
      maxSize = true;
    } else if (a == "--normal") {
      maxSize = false;
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

  static if (NanoSVGHasIVVFS) {
    VFile infile;

    if (fname.getExtension.strEquCI(".zip")) {
      auto did = vfsAddPak!("normal", true)(fname, ":::");
      vfsForEachFileInPak(did, delegate (in ref de) {
        if (de.name.getExtension.strEquCI(".svg")) {
          //{ import iv.vfs.io; writeln(de.name); }
          infile = VFile(de.name);
          return 1;
        }
        return 0;
      });
    } else {
      infile = VFile(fname);
    }
  }

  NSVG* svg;
  scope(exit) svg.kill();
  {
    import std.stdio : writeln;
    import core.time, std.datetime;
    auto stt = MonoTime.currTime;
    static if (NanoSVGHasIVVFS) {
      svg = nsvgParseFromFile(infile, "px", 96, defw, defh);
    } else {
      svg = nsvgParseFromFile(fname, "px", 96, defw, defh);
    }
    if (svg is null) assert(0, "svg parsing error");
    auto dur = (MonoTime.currTime-stt).total!"msecs";
    writeln("loading took ", dur, " milliseconds (", dur/1000.0, " seconds)");
    { import std.stdio; writeln(args.length > 1 ? args[1] : "data/svg/tiger.svg"); }
  }

  printf("size: %f x %f\n", cast(double)svg.width, cast(double)svg.height);
  GWidth = cast(int)svg.width+addw;
  GHeight = cast(int)svg.height+addh;
  float scale = 1;

  enum MaxWidth = 1900;
  enum MaxHeight = 1100;

  if (GWidth > MaxWidth || GHeight > MaxHeight || maxSize) {
    float sx = cast(float)(MaxWidth-4)/GWidth;
    float sy = cast(float)(MaxHeight-4)/GHeight;
    scale = (GWidth*sx <= MaxWidth && GHeight*sx < MaxHeight ? sx : sy);
  }

  if (scale != 1) {
    GWidth = cast(int)(GWidth*scale);
    GHeight = cast(int)(GHeight*scale);
    printf("new size: %d x %d\n", GWidth, GHeight);
  }

  if (GWidth < minw) GWidth = minw;
  if (GHeight < minh) GHeight = minh;

  int vgimg = 0;

  bool doQuit = false;
  bool drawFPS = false;

  //setOpenGLContextVersion(3, 2); // up to GLSL 150
  setOpenGLContextVersion(2, 0); // it's enough
  //openGLContextCompatible = false;

  auto sdwindow = new SimpleWindow(GWidth, GHeight, "NanoSVG", OpenGlOptions.yes, Resizability.fixedSize);
  //sdwindow.hideCursor();

  static if (is(typeof(&sdwindow.closeQuery))) {
    sdwindow.closeQuery = delegate () { doQuit = true; };
  }

  void closeWindow () {
    if (!sdwindow.closed && nvg !is null) {
      nvg.deleteImage(vgimg);
      vgimg = 0;
      nvg.kill();
      nvg = null;
      sdwindow.close();
    }
  }

  auto stt = MonoTime.currTime;
  auto prevt = MonoTime.currTime;
  auto curt = prevt;
  float dt = 0, secs = 0;
  //int mxOld = -1, myOld = -1;
  PathMode pathMode = PathMode.min;
  bool svgAA = false;
  bool help = true;

  sdwindow.visibleForTheFirstTime = delegate () {
    sdwindow.setAsCurrentOpenGlContext(); // make this window active
    sdwindow.vsync = false;

    nvg = nvgCreateContext(
      (contextAA ? NVGContextFlag.Antialias : NVGContextFlag.None)|
      (stencilStrokes ? NVGContextFlag.StencilStrokes : NVGContextFlag.None)|
      NVGContextFlag.None
    );
    if (nvg is null) assert(0, "Could not init nanovg.");

    nvg.createFont("sans", "Tahoma");
    { import iv.vfs.io; writeln("bezier tesselator: ", nvg.tesselation); }
    sdwindow.redrawOpenGlScene();
  };

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

    if (nvg !is null) {
      nvg.beginFrame(GWidth, GHeight);
      scope(exit) nvg.endFrame();

      if (useDirectRendering) {
        nvg.save();
        scope(exit) nvg.restore();
        nvg.shapeAntiAlias = svgAA;
        //vg.translate(0.5, 0.5);
        import std.stdio : writeln;
        import core.time, std.datetime;
        auto stt = MonoTime.currTime;
        nvg.translate(addw, addh);
        nvg.scale(scale, scale);
        bezierCount = 0;
        nvg.render(svg, pathMode);
        auto dur = (MonoTime.currTime-stt).total!"msecs";
        writeln("*** rendering took ", dur, " milliseconds (", dur/1000.0, " seconds), ", bezierCount, " beziers rendered.");
      } else {
        // draw image
        if (vgimg == 0) {
          // image is not rasterized, do it now
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
              scale, // scale
              svgraster.ptr, GWidth, GHeight);
            auto dur = (MonoTime.currTime-stt).total!"msecs";
            writeln("rasterizing took ", dur, " milliseconds (", dur/1000.0, " seconds)");
          }
          vgimg = nvg.createImageRGBA(GWidth, GHeight, svgraster[]);
        }
        nvg.save();
        scope(exit) nvg.restore();
        nvg.beginPath();
        nvg.rect(0, 0, GWidth, GHeight);
        nvg.fillPaint(nvg.imagePattern(0, 0, GWidth, GHeight, 0, vgimg, 1));
        nvg.fill();
      }

      //vg.endFrame(); // flush rendering
      //vg.beginFrame(GWidth, GHeight); // restart frame

      if (help) {
        nvg.save();
        scope(exit) nvg.restore();

        nvg.fontFace = "sans";
        nvg.fontSize = 14;
        nvg.textAlign(NVGTextAlign(NVGTextAlign.H.Left, NVGTextAlign.V.Top));

        auto tw = nvg__max(nvg.textWidth("Direct"), nvg.textWidth("Image"));
        foreach (string mn; __traits(allMembers, PathMode)) tw = nvg__max(tw, nvg.textWidth(mn));
        auto th = nvg.textFontHeight;
        auto rw = tw+10;
        auto rh = (th+3)*3+10;

        nvg.translate(nvg.width-rw-2, nvg.height-rh-2);

        {
          nvg.newPath();
          nvg.save();
          scope(exit) nvg.restore();
          //vg.globalCompositeBlendFunc(NVGBlendFactor.ZERO, NVGBlendFactor.SRC_ALPHA);
          //vg.scissor(0, 0, tw+1, 71);
          nvg.rect(0.5, 0.5, rw, rh);
          nvg.fillColor(NVGColor("#8000"));
          nvg.fill();
          //printf("tw=%g\n", cast(double)tw);
        }

        nvg.fillColor(NVGColor.white);
        nvg.text(5, 5+(th+3)*0, (useDirectRendering ? "Direct" : "Image"));
        nvg.text(5, 5+(th+3)*1, (svgAA ? "AA" : "NO AA"));
        import std.conv : to;
        nvg.text(5, 5+(th+3)*2, pathMode.to!string);
      }
    }
  };

  sdwindow.eventLoop(0/*1000/30*/,
    delegate () {
      if (sdwindow.closed) return;
      if (doQuit) { closeWindow(); return; }
      sdwindow.redrawOpenGlSceneNow();
    },
    delegate (KeyEvent event) {
      if (sdwindow.closed) return;
      if (!event.pressed) return;
      if (event == "Escape" || event == "C-Q") { sdwindow.close(); return; }
      if (event == "D" || event == "V") { useDirectRendering = !useDirectRendering; sdwindow.redrawOpenGlSceneNow(); return; }
      if (event == "A") { svgAA = !svgAA; if (useDirectRendering) sdwindow.redrawOpenGlSceneNow(); return; }
      if (event == "M") {
        if (pathMode == PathMode.max) pathMode = PathMode.min; else ++pathMode;
        if (useDirectRendering) sdwindow.redrawOpenGlSceneNow();
        return;
      }
      if (event == "G") { nativeGradients = !nativeGradients; sdwindow.redrawOpenGlSceneNow(); return; }
      if (event == "F") { nativeFill = !nativeFill; sdwindow.redrawOpenGlSceneNow(); return; }
      if (event == "S") { nativeStroke = !nativeStroke; sdwindow.redrawOpenGlSceneNow(); return; }
      if (event == "B") { nativeOnlyBeziers = !nativeOnlyBeziers; sdwindow.redrawOpenGlSceneNow(); return; }
      if (event == "T") {
        nvg.tesselation = cast(NVGTesselation)(nvg.tesselation == NVGTesselation.max ? NVGTesselation.min : nvg.tesselation+1);
        { import iv.vfs.io; writeln("bezier tesselator: ", nvg.tesselation); }
        sdwindow.redrawOpenGlSceneNow();
        return;
      }
      //if (event == "Space") { drawFPS = !drawFPS; return; }
      if (event == "Space") { help = !help; sdwindow.redrawOpenGlSceneNow(); return; }
    },
    delegate (MouseEvent event) {
    },
    delegate (dchar ch) {
      //if (ch == 'q') { doQuit = true; return; }
    },
  );
  closeWindow();
}
