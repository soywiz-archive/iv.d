import core.time;
import std.stdio;
import iv.nanovg;
import iv.nanovg.fui;
import iv.nanovg.perf;

import arsd.simpledisplay;
import arsd.color;
import arsd.png;
import arsd.jpeg;

import std.functional : toDelegate;


////////////////////////////////////////////////////////////////////////////////
//version = LineBreakTest;


////////////////////////////////////////////////////////////////////////////////
__gshared int GWidth = 800;
__gshared int GHeight = 600;


////////////////////////////////////////////////////////////////////////////////
float getSeconds () {
  import core.time;
  __gshared bool inited = false;
  __gshared MonoTime stt;
  if (!inited) { stt = MonoTime.currTime; inited = true; }
  auto ct = MonoTime.currTime;
  return cast(float)((ct-stt).total!"msecs")/1000.0;
}


// ////////////////////////////////////////////////////////////////////////// //
__gshared NVGcontext* nvg = null;


// ////////////////////////////////////////////////////////////////////////// //
void init (NVGcontext* vg) {
  bndSetFont(nvgCreateFont(vg, "system", "/home/ketmar/ttf/ms/tahoma.ttf"));
  bndSetIconImage(nvgCreateImage(vg, "../data/images/blender_icons16.png", 0));
}


// ////////////////////////////////////////////////////////////////////////// //
void buildWindow0 (FuiContext ctx) {
  ctx.clear();
  with (ctx.layprops(0)) {
    vertical = true;
    padding.left = 1;
    padding.right = 8;
    padding.top = 4;
    padding.bottom = 6;
    spacing = 0;
    lineSpacing = 1;
    version(LineBreakTest) {
      minSize = FuiSize(105, 56);
    }
  }

  // horizontal box for the first two lines
  auto hbox = ctx.hbox(0);
  with (ctx.layprops(hbox)) flex = 0;

    // left span to push buttons to center
    ctx.hspan(hbox);
    // button
    with (ctx.layprops(ctx.button(hbox, "button 0"))) {
      flex = 0;
      //minSize = FuiSize(64, 16);
    }
    // button
    ctx.button(hbox, "button 1");
    // right span to push buttons to center, line break
    with (ctx.layprops(ctx.hspan(hbox))) {
      lineBreak = true;
    }

    // left span to push buttons to right
    ctx.hspan(hbox);
    // button
    with (ctx.layprops(ctx.button(hbox, "long button 2"))) {
      flex = 0;
      //clickMask |= FuiLayoutProps.Buttons.Left;
      doubleMask |= FuiLayoutProps.Buttons.Left;
    }

  // horizontal box for the first text line
  hbox = ctx.hbox(0);
  with (ctx.layprops(hbox)) flex = 0;

    // label
    auto lbl0 = ctx.label(hbox, "\x02first label:");
    with (ctx.layprops(lbl0)) {
      flex = 0;
      hgroup = lbl0;
      vgroup = lbl0;
    }
    // button
    auto but0 = ctx.button(hbox, "button for first label");
    with (ctx.layprops(but0)) {
      flex = 0;
      hgroup = but0;
      vgroup = lbl0;
    }

  // horizontal box for the second text line
  hbox = ctx.hbox(0);
  with (ctx.layprops(hbox)) flex = 0;

    // label
    with (ctx.layprops(ctx.label(hbox, "\x02second label:"))) {
      flex = 0;
      hgroup = lbl0;
      vgroup = lbl0;
    }
    // button
    with (ctx.layprops(ctx.button(hbox, "button for second label"))) {
      flex = 0;
      hgroup = but0;
      vgroup = lbl0;
    }

  // horizontal box to push last line down
  hbox = ctx.hbox(0);
  with (ctx.layprops(hbox)) flex = 1;

  // horizontal box for the last line
  hbox = ctx.hbox(0);
  with (ctx.layprops(hbox)) flex = 0;

    // left span to push button to right
    ctx.hspan(hbox);
    // button
    with (ctx.layprops(ctx.button(hbox, "last long button"))) {
      flex = 0;
      //clickMask |= FuiLayoutProps.Buttons.Left;
      doubleMask |= FuiLayoutProps.Buttons.Left;
    }
}


////////////////////////////////////////////////////////////////////////////////
void main () {
  bool doQuit = false;
  PerfGraph fps;

  //setOpenGLContextVersion(3, 2); // up to GLSL 150
  setOpenGLContextVersion(2, 0); // it's enough
  //openGLContextCompatible = false;

  auto ctx = FuiContext.create();
  /*
  buildWindow0(ctx);
  ctx.relayout();
  debug(fui_dump) ctx.dumpLayout();
  GWidth = ctx.layprops(0).position.w;
  GHeight = ctx.layprops(0).position.h;
  */
  int prevItemAt = -1;

  auto sdwindow = new SimpleWindow(GWidth, GHeight, "OUI", OpenGlOptions.yes, Resizablity.allowResizing);
  //sdwindow.hideCursor();

  void clearWindowData () {
    if (!sdwindow.closed && nvg !is null) {
      nvgDeleteGL2(nvg);
      nvg = null;
    }
  }

  sdwindow.closeQuery = delegate () {
    clearWindowData();
    doQuit = true;
  };

  void closeWindow () {
    clearWindowData();
    if (!sdwindow.closed) sdwindow.close();
  }

  auto stt = MonoTime.currTime;
  auto prevt = MonoTime.currTime;
  auto curt = prevt;
  int owdt = -1, ohgt = -1;

  sdwindow.windowResized = delegate (int w, int h) {
    writeln("w=", w, "; h=", h);
    owdt = w;
    ohgt = h;
    glViewport(0, 0, w, h);
    ctx.layprops(0).minSize = FuiSize(w, h);
    ctx.relayout();
  };

  sdwindow.redrawOpenGlScene = delegate () {
    // Calculate pixel ration for hi-dpi devices.
    //float pxRatio = cast(float)GWidth/cast(float)GHeight;
    ctx.update();

    // process events
    while (ctx.hasEvents) {
      auto ev = ctx.getEvent();
      { import std.stdio; writeln(ev); }
    }

    /*
    if (owdt != sdwindow.width || ohgt != sdwindow.height) {
      owdt = sdwindow.width;
      ohgt = sdwindow.height;
      //glViewport(0, 0, owdt, ohgt);
      // relayout widgets
      ctx.layprops(0).minSize = FuiSize(owdt, ohgt);
      ctx.relayout();
      debug(fui_dump) ctx.dumpLayoutBack();
    }
    */

    // timers
    prevt = curt;
    curt = MonoTime.currTime;
    float secs = cast(double)((curt-stt).total!"msecs")/1000.0;
    float dt = cast(double)((curt-prevt).total!"msecs")/1000.0;

    // Update and render
    glClearColor(0, 0, 0, 1);
    glClear(nvgGlClearFlags);

    if (nvg !is null) {
      if (fps !is null) fps.update(dt);
      nvgBeginFrame(nvg, owdt, ohgt);
      ctx.draw();
      if (fps !is null) fps.render(nvg, owdt-200-5, ohgt-35-5);
      nvgEndFrame(nvg);
    }
  };

  sdwindow.visibleForTheFirstTime = delegate () {
    sdwindow.setAsCurrentOpenGlContext(); // make this window active
    sdwindow.vsync = false;
    //sdwindow.useGLFinish = false;
    //glbindLoadFunctions();

    // init matrices
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glOrtho(0, GWidth, GHeight, 0, -1, 1);
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();

    nvg = nvgCreateGL2(NVG_ANTIALIAS | NVG_STENCIL_STROKES | NVG_DEBUG);
    if (nvg is null) {
      import std.stdio;
      writeln("Could not init nanovg.");
      //sdwindow.close();
    }
    init(nvg);
    ctx.vg = nvg;

    buildWindow0(ctx);
    // relayout widgets
    ctx.layprops(0).minSize = FuiSize(0, 0);
    ctx.relayout();

    GWidth = ctx.layprops(0).position.w;
    GHeight = ctx.layprops(0).position.h;
    //sdwindow.width = GWidth;
    //sdwindow.height = GHeight;
    sdwindow.resize(GWidth, GHeight);
    //glViewport(0, 0, owdt, ohgt);

    //ctx.layprops(0).minSize = FuiSize(GWidth, GHeight);
    //ctx.relayout();

    //if (fps is null) fps = new PerfGraph("Frame Time", PerfGraph.Style.FPS, "system");
    //sdwindow.redrawOpenGlScene();
  };

  sdwindow.eventLoop(1000/60,
    delegate () {
      if (sdwindow.closed) return;
      if (doQuit) { closeWindow(); return; }
      sdwindow.redrawOpenGlSceneNow();
    },
    delegate (KeyEvent event) {
      if (sdwindow.closed) return;
      if (!event.pressed) return;
      switch (event.key) {
        case Key.Escape: sdwindow.close(); return;
        default:
      }
      //uiSetKey(cast(uint)event.key, 0/*mods*/, event.pressed);
      ctx.keyboardEvent(event);
    },
    delegate (MouseEvent event) {
      /*
      auto iat = ctx.itemAt(FuiPoint(event.x, event.y));
      if (iat != prevItemAt) {
        prevItemAt = iat;
        writeln("hovering ", iat);
      }
      */
      ctx.mouseEvent(event);
      /+
      switch (event.type) {
        case MouseEventType.buttonPressed:
        case MouseEventType.buttonReleased:
          if (event.button == MouseButton.left) uiSetButton(0, /*mods*/0, (event.type == MouseEventType.buttonPressed));
          if (event.button == MouseButton.right) uiSetButton(2, /*mods*/0, (event.type == MouseEventType.buttonPressed));
          break;
        case MouseEventType.motion:
          //{ import std.stdio; writeln(event.x, ",", event.y); }
          uiSetCursor(event.x, event.y);
          break;
        default:
      }
      +/
    },
    delegate (dchar ch) {
      //if (ch == 'q') { doQuit = true; return; }
      //uiSetChar(cast(uint)ch);
      ctx.charEvent(ch);
    },
  );
  closeWindow();
}
