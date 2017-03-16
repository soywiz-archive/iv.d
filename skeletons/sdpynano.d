import arsd.color;
import arsd.simpledisplay;

import iv.cmdcon;
import iv.cmdcongl;
import iv.nanovg;
//import iv.nanovg.svg;


void main (string[] args) {
  sdpyWindowClass = "SDPY WINDOW";
  glconShowKey = "M-Grave";

  NVGContext nvg = null;

  conProcessQueue(); // load config
  conProcessArgs!true(args);


  auto sdwin = new SimpleWindow(800, 600, "My D App", OpenGlOptions.yes, Resizability.allowResizing);
  glconCtlWindow = sdwin;
  //sdwin.hideCursor();

  static if (is(typeof(&sdwin.closeQuery))) {
    sdwin.closeQuery = delegate () { concmd("quit"); glconPostDoConCommands(); };
  }

  sdwin.addEventListener((GLConScreenRebuildEvent evt) {
    if (sdwin.closed) return;
    if (isQuitRequested) { sdwin.close(); return; }
    // rebuild screen, reupload texture
    sdwin.redrawOpenGlSceneNow();
  });

  sdwin.addEventListener((GLConScreenRepaintEvent evt) {
    if (sdwin.closed) return;
    if (isQuitRequested) { sdwin.close(); return; }
    sdwin.redrawOpenGlSceneNow();
  });

  sdwin.addEventListener((GLConDoConsoleCommandsEvent evt) {
    bool sendAnother = false;
    bool prevVisible = isConsoleVisible;
    {
      consoleLock();
      scope(exit) consoleUnlock();
      conProcessQueue();
      sendAnother = !conQueueEmpty();
    }
    if (sdwin.closed) return;
    if (isQuitRequested) { sdwin.close(); return; }
    if (sendAnother) glconPostDoConCommands();
    if (prevVisible || isConsoleVisible) glconPostScreenRepaintDelayed();
  });


  sdwin.windowResized = delegate (int wdt, int hgt) {
    if (sdwin.closed) return;
    glconResize(wdt, hgt);
    glconPostScreenRebuild();
  };

  sdwin.redrawOpenGlScene = delegate () {
    if (sdwin.closed) return;

    {
      consoleLock();
      scope(exit) consoleUnlock();
      if (!conQueueEmpty()) glconPostDoConCommands();
    }

    // draw main screen
    glClearColor(0, 0, 0, 0);
    glClear(glNVGClearFlags|GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT|GL_ACCUM_BUFFER_BIT|GL_STENCIL_BUFFER_BIT);
    glViewport(0, 0, sdwin.width, sdwin.height);

    if (nvg !is null) {
      nvg.beginFrame(sdwin.width, sdwin.height, 1);

      nvg.beginPath();
      nvg.roundedRect(0, 0, sdwin.width, sdwin.height, 3);
      nvg.fillColor(nvgRGB(255, 127, 0));
      nvg.fill();

      nvg.fontSize(14);
      nvg.fontFace("sans");
      nvg.textAlign(NVGTextAlign.H.Center, NVGTextAlign.V.Middle);
      nvg.fillColor(nvgRGB(0, 0, 255));
      nvg.text(sdwin.width/2, sdwin.height/2, "Hello! Двощер молодых");

      nvg.endFrame();
    }

    glconDraw();

    //if (isQuitRequested()) sdwin.glconPostEvent(new QuitEvent());
  };

  sdwin.visibleForTheFirstTime = delegate () {
    sdwin.setAsCurrentOpenGlContext();
    sdwin.vsync = false;
    glconInit(sdwin.width, sdwin.height);

    // create and upload texture, rebuild screen
    nvg = createGL2NVG(NVG_FONT_NOAA|NVG_ANTIALIAS|NVG_STENCIL_STROKES/*|NVG_DEBUG*/);
    if (nvg is null) assert(0, "Could not init nanovg.");
    nvg.createFont("sans:noaa", "/home/ketmar/ttf/ms/arial.ttf");

    sdwin.redrawOpenGlSceneNow();
  };

  sdwin.eventLoop(0,
    delegate () {
      scope(exit) if (!conQueueEmpty()) glconPostDoConCommands();
      if (sdwin.closed) return;
      if (isQuitRequested) { sdwin.close(); return; }
    },
    delegate (KeyEvent event) {
      scope(exit) if (!conQueueEmpty()) glconPostDoConCommands();
      if (sdwin.closed) return;
      if (isQuitRequested) { sdwin.close(); return; }
      if (glconKeyEvent(event)) { glconPostScreenRepaint(); return; }
    },
    delegate (MouseEvent event) {
      scope(exit) if (!conQueueEmpty()) glconPostDoConCommands();
      if (sdwin.closed) return;
    },
    delegate (dchar ch) {
      if (sdwin.closed) return;
      scope(exit) if (!conQueueEmpty()) glconPostDoConCommands();
      if (glconCharEvent(ch)) { glconPostScreenRepaint(); return; }
    },
  );

  if (nvg !is null) { nvg.deleteGL2(); nvg = null; }
  flushGui();
  conProcessQueue(int.max/4);
}
