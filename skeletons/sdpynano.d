import arsd.color;
import arsd.simpledisplay;

import iv.cmdcon;
import iv.cmdcongl;
import iv.nanovg;


// ////////////////////////////////////////////////////////////////////////// //
__gshared string optEditorFont = "~/ttf/ms/arial.ttf:noaa";
__gshared int optEditorFontSize = 14;
__gshared NVGContext nvg = null;


// ////////////////////////////////////////////////////////////////////////// //
void main (string[] args) {
  glconShowKey = "M-Grave";

  conRegVar!optEditorFont("ed_font_path", "path to TTF font");
  conRegVar!optEditorFontSize(6, 72, "ed_font_size", "editor font size");

  conProcessQueue(); // load config
  conProcessArgs!true(args);


  // first time setup
  oglSetupDG = delegate () {
    // create and upload texture, rebuild screen
    nvg = createGL2NVG(NVG_FONT_NOAA|NVG_ANTIALIAS|NVG_STENCIL_STROKES/*|NVG_DEBUG*/);
    if (nvg is null) assert(0, "Could not init nanovg.");
    nvg.createFont("sans", optEditorFont);
  };


  resizeEventDG = delegate (int wdt, int hgt) {
  };


  // draw main screen
  redrawFrameDG = delegate () {
    // draw main screen
    glClearColor(0, 0, 0, 0);
    glClear(glNVGClearFlags|GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT|GL_ACCUM_BUFFER_BIT|GL_STENCIL_BUFFER_BIT);
    glViewport(0, 0, glconCtlWindow.width, glconCtlWindow.height);

    if (nvg !is null) {
      nvg.beginFrame(glconCtlWindow.width, glconCtlWindow.height, 1);

      nvg.beginPath();
      nvg.roundedRect(0, 0, glconCtlWindow.width, glconCtlWindow.height, 3);
      nvg.fillColor(nvgRGB(255, 127, 0));
      nvg.fill();

      nvg.fontSize(optEditorFontSize);
      nvg.fontFace("sans");
      nvg.textAlign(NVGTextAlign.H.Center, NVGTextAlign.V.Middle);
      nvg.fillColor(nvgRGB(0, 0, 255));
      nvg.text(glconCtlWindow.width/2, glconCtlWindow.height/2, "Hello! Двощер молодых");

      nvg.endFrame();
    }
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


  glconRunGLWindowResizeable(800, 600, "My D App", "SDPY WINDOW");
  if (nvg !is null) { nvg.deleteGL2(); nvg = null; }
}
