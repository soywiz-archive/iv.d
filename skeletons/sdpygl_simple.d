import arsd.color;
import arsd.simpledisplay;

//import iv.bclamp;
import iv.cmdcon;
import iv.cmdcongl;


// ////////////////////////////////////////////////////////////////////////// //
void main (string[] args) {
  glconShowKey = "M-Grave";

  conProcessQueue(); // load config
  conProcessArgs!true(args);

  // first time setup
  oglSetupDG = delegate () {
    // this will create texture
    //gxResize(glconCtlWindow.width, glconCtlWindow.height);
  };

  // draw main screen
  redrawFrameDG = delegate () {
    oglSetup2D(glconCtlWindow.width, glconCtlWindow.height);
    /+
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glOrtho(0, /*winWidth*/100, /*winHeight*/100, 0, -1, 1); // set origin to top left
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
    +/

    glClearColor(0, 0, 0, 0);
    glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT|GL_ACCUM_BUFFER_BIT|GL_STENCIL_BUFFER_BIT);

    // scale everything
    glMatrixMode(GL_MODELVIEW);
    //glScalef(2, 2, 2);

    glColor4f(1, 1, 1, 1);
    glBegin(GL_LINES);
      glVertex2f(10, 10);
      glVertex2f(90, 90);
    glEnd();

    glColor4f(1, 1, 0, 0.8);
    glEnable(GL_BLEND); // other things was set in `oglSetup2D()`

    glPointSize(6);
    glEnable(GL_POINT_SMOOTH); // so our point will be "smoothed" to circle

    glLineWidth(2);
    glDisable(GL_LINE_SMOOTH);

    glBegin(GL_POINTS);
      glVertex2f(30, 30);
    glEnd();
  };

  // rebuild main screen (do any calculations we might need)
  nextFrameDG = delegate () {
  };

  keyEventDG = delegate (KeyEvent event) {
    if (!event.pressed) return;
    switch (event.key) {
      case Key.Escape: concmd("quit"); break;
      default:
    }
  };

  mouseEventDG = delegate (MouseEvent event) {
  };

  charEventDG = delegate (dchar ch) {
    if (ch == 'q') { concmd("quit"); return; }
  };

  resizeEventDG = delegate (int wdt, int hgt) {
  };

  version(none) {
   // this...
    sdpyWindowClass = "SDPY WINDOW";
    auto sdwin = new SimpleWindow(VBufWidth, VBufHeight, "My D App", OpenGlOptions.yes, Resizability.allowResizing);
    //sdwin.hideCursor();
    glconSetupForGLWindow(sdwin);
    sdwin.eventLoop(0);
    flushGui();
    conProcessQueue(int.max/4);
  } else {
    // or this
    glconRunGLWindowResizeable(1024, 768, "My D App", "SDPY WINDOW");
  }
}
