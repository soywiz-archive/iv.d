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
module example;

import arsd.simpledisplay;
import arsd.color;
import arsd.image;

import iv.nanovega;
import iv.nanovega.blendish;
import iv.nanovega.perf;

version(aliced) {
  version = nanovg_demo_msfonts;
}


// ////////////////////////////////////////////////////////////////////////// //
enum GWidth = 1000;
enum GHeight = 600;


enum WidgetIdRaw = 1;
enum WidgetIdBlendish = 2;


// ////////////////////////////////////////////////////////////////////////// //
void fatal (string msg) {
  import std.stdio;
  stderr.writeln("FATAL: ", msg);
  stderr.flush();
  assert(0, msg);
}


// ////////////////////////////////////////////////////////////////////////// //
// demo modes
bool blowup = false;
bool screenshot = false;
bool premult = false;


// ////////////////////////////////////////////////////////////////////////// //
struct DemoData {
  int fontNormal, fontBold, fontIcons;
  NVGImage[12] images;

  @disable this (this); // no copies
}


// ////////////////////////////////////////////////////////////////////////// //
// blendish window position and flags
float bndX = 42.0f;
float bndY = 100.0f;
float bndW = 600.0f;
float bndH = 420.0f;
bool bndMoving = false;

// "raw widget" position and flags
float wgX = 50.0f;
float wgY = 50.0f;
enum wgW = 300.0f;
enum wgH = 400.0f;
bool wgMoving = false;

// common "raw widget" and blendish flags
bool wgOnTop = false;


// ////////////////////////////////////////////////////////////////////////// //
bool loadDemoData (NVGContext nvg, ref DemoData data) {
  import std.stdio;
  import std.string : format;

  if (nvg is null) return false;

  foreach (immutable idx, ref NVGImage img; data.images[]) {
    img = nvg.createImage("data/images/image%u.jpg".format(idx+1));
    if (!img.valid) { stderr.writeln("Could not load image #", idx+1, "."); return false; }
  }

  data.fontIcons = nvg.createFont("icons", "data/entypo.ttf");
  if (data.fontIcons == FONS_INVALID) { stderr.writeln("Could not add font icons."); return false; }

  version(nanovg_demo_msfonts) {
    enum FNN = "Tahoma:noaa";
    enum FNB = "Tahoma:bold:noaa";
  } else {
    enum FNN = "data/Roboto-Regular.ttf";
    enum FNB = "data/Roboto-Bold.ttf";
  }

  data.fontNormal = nvg.createFont("sans", FNN);
  if (data.fontNormal == FONS_INVALID) { stderr.writeln("Could not add font italic."); return false; }
  data.fontBold = nvg.createFont("sans-bold", FNB);
  if (data.fontBold == FONS_INVALID) { stderr.writeln("Could not add font bold."); return false; }

  //bndSetFont(vg.createFont("droidsans", "data/DroidSans.ttf"));
  bndSetFont(data.fontNormal);
  auto icons = nvg.createImage("data/images/blender_icons16.png");
  if (!icons.valid) { stderr.writeln("Could not load icons image."); return false; }
  bndSetIconImage(icons);

  return true;
}


void freeDemoData (NVGContext nvg, ref DemoData data) {
  if (nvg == null) return;
  foreach (ref NVGImage img; data.images[]) img.clear();
  bndClearIconImage();
}


// ////////////////////////////////////////////////////////////////////////// //
enum ICON_NONE = "";
enum ICON_SEARCH = "\u1F50";
enum ICON_CIRCLED_CROSS = "\u2716";
enum ICON_CHEVRON_RIGHT = "\uE75E";
enum ICON_CHECK = "\u2713";
enum ICON_LOGIN = "\uE740";
enum ICON_TRASH = "\uE729";


// ////////////////////////////////////////////////////////////////////////// //
void renderDemo (NVGContext nvg, float mx, float my, float width, float height, float t, int blowup, ref DemoData data) {
  drawEyes(nvg, width-250, 50, 150, 100, mx, my, t);
  drawParagraph(nvg, width-450, 50, 150, 100, mx, my);
  drawGraph(nvg, 0, height/2, width, height/2, t);
  drawColorWheel(nvg, width-300, height-300, 250.0f, 250.0f, t);

  // Line joints
  drawLines(nvg, 120, height-50, 600, 50, t);

  // Line caps
  drawWidths(nvg, 10, 50, 30);

  // Line caps
  drawCaps(nvg, 10, 300, 30);

  drawScissor(nvg, 50, height-80, t);

  nvg.save();
  scope(exit) nvg.restore();

  if (blowup) {
    import core.stdc.math : sinf;
    nvg.rotate(sinf(t*0.3f)*5.0f/180.0f*NVG_PI);
    nvg.scale(2.0f, 2.0f);
  }

  void drawWidget () {
    nvg.save();
    scope(exit) nvg.restore();

    nvg.translate(wgX-50, wgY-50);
    nvg.globalAlpha(wgMoving ? 0.4 : 0.9);

    // Widgets
    drawWindow(nvg, "Widgets `n Stuff", 50, 50, 300, 400);
    float x = 60;
    float y = 95;
    drawSearchBox(nvg, "Search", x, y, 280, 25); y += 40;
    float popy = y+14;
    drawDropDown(nvg, "Effects", x, y, 280, 28); y += 45;

    // Form
    drawLabel(nvg, "Login", x, y, 280, 20); y += 25;
    drawEditBox(nvg, "Email",  x, y, 280, 28); y += 35;
    drawEditBox(nvg, "Password", x, y, 280, 28); y += 38;
    drawCheckBox(nvg, "Remember me", x, y, 140, 28);
    drawButton(nvg, ICON_LOGIN, "Sign in", x+138, y, 140, 28, nvgRGBA(0, 96, 128, 255)); y += 45;

    // Slider
    drawLabel(nvg, "Diameter", x, y, 280, 20); y += 25;
    drawEditBoxNum(nvg, "123.00", "px", x+180, y, 100, 28);
    drawSlider(nvg, 0.4f, x, y, 170, 28); y += 55;

    drawButton(nvg, ICON_TRASH, "Delete", x, y, 160, 28, nvgRGBA(128, 16, 8, 255));
    drawButton(nvg, ICON_NONE, "Cancel", x+170, y, 110, 28, nvgRGBA(0, 0, 0, 0));

    // Thumbnails box
    drawThumbnails(nvg, 365, popy-30, 160, 300, data.images[], t);
  }

  void drawBnd () {
    drawBlendish(nvg, bndX, bndY, bndW, bndH, t);
  }

  if (wgOnTop) { drawBnd(); drawWidget(); } else { drawWidget(); drawBnd(); }

  nvg.pickid = NVGNoPick;
}


// ////////////////////////////////////////////////////////////////////////// //
void drawWindow (NVGContext nvg, const(char)[] title, float x, float y, float w, float h) {
  enum cornerRadius = 3.0f;

  nvg.save();
  scope(exit) nvg.restore();

  // Window
  nvg.beginPath();
  nvg.roundedRect(x, y, w, h, cornerRadius);
  nvg.currFillPickId = WidgetIdRaw;
  nvg.fillColor = nvgRGBA(28, 30, 34, 192);
  //vg.fillColor(nvgRGBA(0, 0, 0, 128));
  nvg.fill();

  // Drop shadow
  nvg.beginPath();
  nvg.rect(x-10, y-10, w+20, h+30);
  nvg.roundedRect(x, y, w, h, cornerRadius);
  nvg.pathWinding = NVGSolidity.Hole;
  nvg.fillPaint = nvg.boxGradient(x, y+2, w, h, cornerRadius*2, 10, nvgRGBA(0, 0, 0, 128), nvgRGBA(0, 0, 0, 0));
  nvg.fill();

  // Header
  nvg.beginPath();
  nvg.roundedRect(x+1, y+1, w-2, 30, cornerRadius-1);
  nvg.fillPaint = nvg.linearGradient(x, y, x, y+15, nvgRGBA(255, 255, 255, 8), nvgRGBA(0, 0, 0, 16));
  nvg.fill();

  nvg.beginPath();
  nvg.moveTo(x+0.5f, y+0.5f+30);
  nvg.lineTo(x+0.5f+w-1, y+0.5f+30);
  nvg.strokeColor = nvgRGBA(0, 0, 0, 32);
  nvg.stroke();

  nvg.fontSize = 18.0f;
  nvg.fontFace = "sans-bold";
  nvg.textAlign(NVGTextAlign.H.Center, NVGTextAlign.V.Middle);

  nvg.fontBlur = 2;
  nvg.fillColor = nvgRGBA(0, 0, 0, 128);
  nvg.text(x+w/2, y+16+1, title);

  nvg.fontBlur = 0;
  nvg.fillColor = nvgRGBA(220, 220, 220, 160);
  nvg.text(x+w/2, y+16, title);
}


void drawSearchBox (NVGContext nvg, const(char)[] text, float x, float y, float w, float h) {
  immutable float cornerRadius = h/2-1;

  // Edit
  nvg.beginPath();
  nvg.roundedRect(x, y, w, h, cornerRadius);
  nvg.fillPaint = nvg.boxGradient(x, y+1.5f, w, h, h/2, 5, nvgRGBA(0, 0, 0, 16), nvgRGBA(0, 0, 0, 92));
  nvg.fill();

  /*
  vg.beginPath();
  vg.roundedRect(x+0.5f, y+0.5f, w-1, h-1, cornerRadius-0.5f);
  vg.strokeColor = nvgRGBA(0, 0, 0, 48);
  vg.stroke();
  */

  nvg.fontSize = h*1.3f;
  nvg.fontFace = "icons";
  nvg.fillColor = nvgRGBA(255, 255, 255, 64);
  nvg.textAlign = NVGTextAlign.V.Middle;
  nvg.textAlign = NVGTextAlign.H.Center;
  nvg.text(x+h*0.55f, y+h*0.55f, ICON_SEARCH);

  nvg.fontSize = 20.0f;
  nvg.fontFace = "sans";
  nvg.fillColor = nvgRGBA(255, 255, 255, 32);
  nvg.textAlign = NVGTextAlign.H.Left;
  nvg.text(x+h*1.05f, y+h*0.5f, text);

  nvg.fontSize = h*1.3f;
  nvg.fontFace = "icons";
  nvg.fillColor = nvgRGBA(255, 255, 255, 32);
  nvg.textAlign = NVGTextAlign.H.Center;
  nvg.text(x+w-h*0.55f, y+h*0.55f, ICON_CIRCLED_CROSS);
}


void drawDropDown (NVGContext nvg, const(char)[] text, float x, float y, float w, float h) {
  enum cornerRadius = 4.0f;

  nvg.beginPath();
  nvg.roundedRect(x+1, y+1, w-2, h-2, cornerRadius-1);
  nvg.fillPaint = nvg.linearGradient(x, y, x, y+h, nvgRGBA(255, 255, 255, 16), nvgRGBA(0, 0, 0, 16));
  nvg.fill();

  nvg.beginPath();
  nvg.roundedRect(x+0.5f, y+0.5f, w-1, h-1, cornerRadius-0.5f);
  nvg.strokeColor = nvgRGBA(0, 0, 0, 48);
  nvg.stroke();

  nvg.fontSize = 20.0f;
  nvg.fontFace = "sans";
  nvg.fillColor = nvgRGBA(255, 255, 255, 160);
  nvg.textAlign(NVGTextAlign.H.Left, NVGTextAlign.V.Middle);
  nvg.text(x+h*0.3f, y+h*0.5f, text);

  nvg.fontSize = h*1.3f;
  nvg.fontFace = "icons";
  nvg.fillColor = nvgRGBA(255, 255, 255, 64);
  nvg.textAlign = NVGTextAlign.H.Center;
  nvg.text(x+w-h*0.5f, y+h*0.5f, ICON_CHEVRON_RIGHT);
}


void drawLabel (NVGContext nvg, const(char)[] text, float x, float y, float w, float h) {
  nvg.fontSize = 18.0f;
  nvg.fontFace = "sans";
  nvg.fillColor = nvgRGBA(255, 255, 255, 128);

  nvg.textAlign(NVGTextAlign.H.Left, NVGTextAlign.V.Middle);
  nvg.text(x, y+h*0.5f, text);
}


void drawEditBoxBase (NVGContext nvg, float x, float y, float w, float h) {
  // Edit
  nvg.beginPath();
  nvg.roundedRect(x+1, y+1, w-2, h-2, 4-1);
  nvg.fillPaint = nvg.boxGradient(x+1, y+1+1.5f, w-2, h-2, 3, 4, nvgRGBA(255, 255, 255, 32), nvgRGBA(32, 32, 32, 32));
  nvg.fill();

  nvg.beginPath();
  nvg.roundedRect(x+0.5f, y+0.5f, w-1, h-1, 4-0.5f);
  nvg.strokeColor = nvgRGBA(0, 0, 0, 48);
  nvg.stroke();
}


void drawEditBox (NVGContext nvg, const(char)[] text, float x, float y, float w, float h) {
  drawEditBoxBase(nvg, x, y, w, h);
  nvg.fontSize = 20.0f;
  nvg.fontFace = "sans";
  nvg.fillColor = nvgRGBA(255, 255, 255, 64);
  nvg.textAlign(NVGTextAlign.H.Left, NVGTextAlign.V.Middle);
  nvg.text(x+h*0.3f, y+h*0.5f, text);
}


public void drawEditBoxNum (NVGContext nvg, const(char)[] text, const(char)[] units, float x, float y, float w, float h) {
  drawEditBoxBase(nvg, x, y, w, h);

  immutable float uw = nvg.textBounds(0, 0, units, null);

  nvg.fontSize = 18.0f;
  nvg.fontFace = "sans";
  nvg.fillColor = nvgRGBA(255, 255, 255, 64);
  nvg.textAlign(NVGTextAlign.H.Right, NVGTextAlign.V.Middle);
  nvg.text(x+w-h*0.3f, y+h*0.5f, units);

  nvg.fontSize = 20.0f;
  nvg.fontFace = "sans";
  nvg.fillColor = nvgRGBA(255, 255, 255, 128);
  nvg.text(x+w-uw-h*0.5f, y+h*0.5f, text);
}


void drawCheckBox (NVGContext nvg, const(char)[] text, float x, float y, float w, float h) {
  nvg.fontSize = 18.0f;
  nvg.fontFace = "sans";
  nvg.fillColor = nvgRGBA(255, 255, 255, 160);

  nvg.textAlign(NVGTextAlign.H.Left, NVGTextAlign.V.Middle);
  nvg.text(x+28, y+h*0.5f, text);

  nvg.beginPath();
  nvg.roundedRect(x+1, y+cast(int)(h*0.5f)-9, 18, 18, 3);
  nvg.fillPaint = nvg.boxGradient(x+1, y+cast(int)(h*0.5f)-9+1, 18, 18, 3, 3, nvgRGBA(0, 0, 0, 32), nvgRGBA(0, 0, 0, 92));
  nvg.fill();

  nvg.fontSize = 40;
  nvg.fontFace = "icons";
  nvg.fillColor = nvgRGBA(255, 255, 255, 128);
  nvg.textAlign = NVGTextAlign.H.Center;
  nvg.text(x+9+2, y+h*0.5f, ICON_CHECK);
}


void drawButton (NVGContext nvg, const(char)[] preicon, const(char)[] text, float x, float y, float w, float h, NVGColor col) {
  enum float cornerRadius = 4.0f;

  nvg.beginPath();
  nvg.roundedRect(x+1, y+1, w-2, h-2, cornerRadius-1);
  if (!col.isTransparent) {
    nvg.fillColor = col;
    nvg.fill();
  }
  nvg.fillPaint = nvg.linearGradient(x, y, x, y+h, nvgRGBA(255, 255, 255, col.isTransparent ? 16 : 32), nvgRGBA(0, 0, 0, col.isTransparent ? 16 : 32));
  nvg.fill();

  nvg.beginPath();
  nvg.roundedRect(x+0.5f, y+0.5f, w-1, h-1, cornerRadius-0.5f);
  nvg.strokeColor = nvgRGBA(0, 0, 0, 48);
  nvg.stroke();

  nvg.fontSize = 20.0f;
  nvg.fontFace = "sans-bold";

  immutable float tw = nvg.textBounds(0, 0, text, null);
  float iw = 0;

  if (preicon.length) {
    nvg.fontSize = h*1.3f;
    nvg.fontFace = "icons";
    iw = nvg.textBounds(0, 0, preicon, null);
    iw += h*0.15f;
  }

  if (preicon.length) {
    nvg.fontSize = h*1.3f;
    nvg.fontFace = "icons";
    nvg.fillColor = nvgRGBA(255, 255, 255, 96);
    nvg.textAlign(NVGTextAlign.H.Left, NVGTextAlign.V.Middle);
    nvg.text(x+w*0.5f-tw*0.5f-iw*0.75f, y+h*0.5f, preicon);
  }

  nvg.fontSize = 20.0f;
  nvg.fontFace = "sans-bold";
  nvg.textAlign(NVGTextAlign.H.Left, NVGTextAlign.V.Middle);
  nvg.fillColor = nvgRGBA(0, 0, 0, 160);
  nvg.text(x+w*0.5f-tw*0.5f+iw*0.25f, y+h*0.5f-1, text);
  nvg.fillColor = nvgRGBA(255, 255, 255, 160);
  nvg.text(x+w*0.5f-tw*0.5f+iw*0.25f, y+h*0.5f, text);
}


void drawSlider (NVGContext nvg, float pos, float x, float y, float w, float h) {
  immutable float cy = y+cast(int)(h*0.5f);
  immutable float kr = cast(int)(h*0.25f);

  nvg.save();
  scope(exit) nvg.restore();

  // Slot
  nvg.beginPath();
  nvg.roundedRect(x, cy-2, w, 4, 2);
  nvg.fillPaint = nvg.boxGradient(x, cy-2+1, w, 4, 2, 2, nvgRGBA(0, 0, 0, 32), nvgRGBA(0, 0, 0, 128));
  nvg.fill();

  // Knob Shadow
  nvg.beginPath();
  nvg.rect(x+cast(int)(pos*w)-kr-5, cy-kr-5, kr*2+5+5, kr*2+5+5+3);
  nvg.circle(x+cast(int)(pos*w), cy, kr);
  nvg.pathWinding = NVGSolidity.Hole;
  nvg.fillPaint = nvg.radialGradient(x+cast(int)(pos*w), cy+1, kr-3, kr+3, nvgRGBA(0, 0, 0, 64), nvgRGBA(0, 0, 0, 0));
  nvg.fill();

  // Knob
  nvg.beginPath();
  nvg.circle(x+cast(int)(pos*w), cy, kr-1);
  nvg.fillColor = nvgRGBA(40, 43, 48, 255);
  nvg.fill();
  nvg.fillPaint = nvg.linearGradient(x, cy-kr, x, cy+kr, nvgRGBA(255, 255, 255, 16), nvgRGBA(0, 0, 0, 16));
  nvg.fill();

  nvg.beginPath();
  nvg.circle(x+cast(int)(pos*w), cy, kr-0.5f);
  nvg.strokeColor = nvgRGBA(0, 0, 0, 92);
  nvg.stroke();
}


void drawEyes (NVGContext nvg, float x, float y, float w, float h, float mx, float my, float t) {
  import core.stdc.math : pow, sinf, sqrtf;

  immutable float ex = w*0.23f;
  immutable float ey = h*0.5f;
  immutable float lx = x+ex;
  immutable float ly = y+ey;
  immutable float rx = x+w-ex;
  immutable float ry = y+ey;
  immutable float br = (ex < ey ? ex : ey)*0.5f;
  immutable float blink = 1-pow(sinf(t*0.5f), 200)*0.8f;

  nvg.beginPath();
  nvg.ellipse(lx+3.0f, ly+16.0f, ex, ey);
  nvg.ellipse(rx+3.0f, ry+16.0f, ex, ey);
  nvg.fillPaint = nvg.linearGradient(x, y+h*0.5f, x+w*0.1f, y+h, nvgRGBA(0, 0, 0, 32), nvgRGBA(0, 0, 0, 16));
  nvg.fill();

  nvg.beginPath();
  nvg.ellipse(lx, ly, ex, ey);
  nvg.ellipse(rx, ry, ex, ey);
  nvg.fillPaint = nvg.linearGradient(x, y+h*0.25f, x+w*0.1f, y+h, nvgRGBA(220, 220, 220, 255), nvgRGBA(128, 128, 128, 255));
  nvg.fill();

  void drawPupil (in float px, in float py) {
    float dx = (mx-px)/(ex*10);
    float dy = (my-py)/(ey*10);
    immutable float d = sqrtf(dx*dx+dy*dy);
    if (d > 1.0f) { dx /= d; dy /= d; }
    dx *= ex*0.4f;
    dy *= ey*0.5f;
    nvg.beginPath();
    nvg.ellipse(px+dx, py+dy+ey*0.25f*(1-blink), br, br*blink);
    nvg.fillColor = nvgRGBA(32, 32, 32, 255);
    nvg.fill();
  }

  drawPupil(lx, ly);
  drawPupil(rx, ry);

  nvg.beginPath();
  nvg.ellipse(lx, ly, ex, ey);
  nvg.fillPaint = nvg.radialGradient(lx-ex*0.25f, ly-ey*0.5f, ex*0.1f, ex*0.75f, nvgRGBA(255, 255, 255, 128), nvgRGBA(255, 255, 255, 0));
  nvg.fill();

  nvg.beginPath();
  nvg.ellipse(rx, ry, ex, ey);
  nvg.fillPaint = nvg.radialGradient(rx-ex*0.25f, ry-ey*0.5f, ex*0.1f, ex*0.75f, nvgRGBA(255, 255, 255, 128), nvgRGBA(255, 255, 255, 0));
  nvg.fill();
}


void drawGraph (NVGContext nvg, float x, float y, float w, float h, float t) {
  import core.stdc.math : cosf, sinf;

  immutable float[6] samples = [
    (1+sinf(t*1.2345f+cosf(t*0.33457f)*0.44f))*0.5f,
    (1+sinf(t*0.68363f+cosf(t*1.3f)*1.55f))*0.5f,
    (1+sinf(t*1.1642f+cosf(t*0.33457)*1.24f))*0.5f,
    (1+sinf(t*0.56345f+cosf(t*1.63f)*0.14f))*0.5f,
    (1+sinf(t*1.6245f+cosf(t*0.254f)*0.3f))*0.5f,
    (1+sinf(t*0.345f+cosf(t*0.03f)*0.6f))*0.5f,
  ];

  immutable float dx = w/5.0f;
  float[6] sx, sy;
  foreach (immutable i, immutable float sm; samples[]) {
    sx[i] = x+i*dx;
    sy[i] = y+h*sm*0.8f;
  }

  // Graph background
  nvg.beginPath();
  nvg.moveTo(sx[0], sy[0]);
  foreach (immutable i; 1..6) nvg.bezierTo(sx[i-1]+dx*0.5f, sy[i-1], sx[i]-dx*0.5f, sy[i], sx[i], sy[i]);
  nvg.lineTo(x+w, y+h);
  nvg.lineTo(x, y+h);
  nvg.fillPaint = nvg.linearGradient(x, y, x, y+h, nvgRGBA(0, 160, 192, 0), nvgRGBA(0, 160, 192, 64));
  nvg.fill();

  // Graph line
  nvg.beginPath();
  nvg.moveTo(sx[0], sy[0]+2);
  foreach (immutable i; 1..6) nvg.bezierTo(sx[i-1]+dx*0.5f, sy[i-1]+2, sx[i]-dx*0.5f, sy[i]+2, sx[i], sy[i]+2);
  nvg.strokeColor = nvgRGBA(0, 0, 0, 32);
  nvg.strokeWidth = 3.0f;
  nvg.stroke();

  nvg.beginPath();
  nvg.moveTo(sx[0], sy[0]);
  foreach (immutable i; 1..6) nvg.bezierTo(sx[i-1]+dx*0.5f, sy[i-1], sx[i]-dx*0.5f, sy[i], sx[i], sy[i]);
  nvg.strokeColor = nvgRGBA(0, 160, 192, 255);
  nvg.strokeWidth = 3.0f;
  nvg.stroke();

  // Graph sample pos
  foreach (immutable i; 0..6) {
    nvg.beginPath();
    nvg.rect(sx[i]-10, sy[i]-10+2, 20, 20);
    nvg.fillPaint = nvg.radialGradient(sx[i], sy[i]+2, 3.0f, 8.0f, nvgRGBA(0, 0, 0, 32), nvgRGBA(0, 0, 0, 0));
    nvg.fill();
  }

  nvg.beginPath();
  foreach (immutable i; 0..6) nvg.circle(sx[i], sy[i], 4.0f);
  nvg.fillColor = nvgRGBA(0, 160, 192, 255);
  nvg.fill();

  nvg.beginPath();
  foreach (immutable i; 0..6) nvg.circle(sx[i], sy[i], 2.0f);
  nvg.fillColor = nvgRGBA(220, 220, 220, 255);
  nvg.fill();

  nvg.strokeWidth = 1.0f;
}


void drawSpinner (NVGContext nvg, float cx, float cy, float r, float t) {
  import core.stdc.math : cosf, sinf;

  immutable float a0 = 0.0f+t*6;
  immutable float a1 = NVG_PI+t*6;
  immutable float r0 = r;
  immutable float r1 = r*0.75f;

  nvg.save();
  scope(exit) nvg.restore();

  nvg.beginPath();
  nvg.arc(NVGWinding.CW, cx, cy, r0, a0, a1);
  nvg.arc(NVGWinding.CCW, cx, cy, r1, a1, a0);
  nvg.closePath();

  immutable float ax = cx+cosf(a0)*(r0+r1)*0.5f;
  immutable float ay = cy+sinf(a0)*(r0+r1)*0.5f;
  immutable float bx = cx+cosf(a1)*(r0+r1)*0.5f;
  immutable float by = cy+sinf(a1)*(r0+r1)*0.5f;
  nvg.fillPaint = nvg.linearGradient(ax, ay, bx, by, nvgRGBA(0, 0, 0, 0), nvgRGBA(0, 0, 0, 128));
  nvg.fill();
}


void drawThumbnails (NVGContext nvg, float x, float y, float w, float h, NVGImage[] images, float t) {
  import core.stdc.math : cosf;

  enum cornerRadius = 3.0f;
  //float ix, iy, iw, ih;
  enum thumb = 60.0f;
  enum arry = 30.5f;
  //int imgw, imgh;
  immutable float stackh = (images.length/2)*(thumb+10)+10;
  immutable float u = (1+cosf(t*0.5f))*0.5f;
  immutable float u2 = (1-cosf(t*0.2f))*0.5f;
  //float scrollh, dv;

  nvg.save();
  scope(exit) nvg.restore();

  // Drop shadow
  nvg.beginPath();
  nvg.rect(x-10, y-10, w+20, h+30);
  nvg.roundedRect(x, y, w, h, cornerRadius);
  nvg.pathWinding = NVGSolidity.Hole;
  nvg.fillPaint = nvg.boxGradient(x, y+4, w, h, cornerRadius*2, 20, nvgRGBA(0, 0, 0, 128), nvgRGBA(0, 0, 0, 0));
  nvg.fill();

  // Window
  nvg.beginPath();
  nvg.roundedRect(x, y, w, h, cornerRadius);
  nvg.moveTo(x-10, y+arry);
  nvg.lineTo(x+1, y+arry-11);
  nvg.lineTo(x+1, y+arry+11);
  //nvg.closePath();
  nvg.currFillPickId = WidgetIdRaw;
  nvg.fillColor = nvgRGBA(200, 200, 200, 255);
  nvg.fill();

  {
    nvg.save();
    scope(exit) nvg.restore();

    nvg.scissor(x, y, w, h);
    nvg.translate(0, -(stackh-h)*u);

    immutable float dv = 1.0f/cast(float)(images.length-1);

    foreach (immutable int i; 0..cast(int)images.length) {
      float tx = x+10;
      float ty = y+10;
      tx += (i%2)*(thumb+10);
      ty += (i/2)*(thumb+10);

      float iw, ih, ix, iy;
      int imgw = images[i].width;
      int imgh = images[i].height;
      if (imgw < imgh) {
        iw = thumb;
        ih = iw*cast(float)imgh/cast(float)imgw;
        ix = 0;
        iy = -(ih-thumb)*0.5f;
      } else {
        ih = thumb;
        iw = ih*cast(float)imgw/cast(float)imgh;
        ix = -(iw-thumb)*0.5f;
        iy = 0;
      }

      immutable float v = i*dv;
      immutable float a = nvg__clamp((u2-v)/dv, 0, 1);

      if (a < 1.0f) drawSpinner(nvg, tx+thumb/2, ty+thumb/2, thumb*0.25f, t);

      nvg.beginPath();
      nvg.roundedRect(tx, ty, thumb, thumb, 5);
      nvg.fillPaint = nvg.imagePattern(tx+ix, ty+iy, iw, ih, 0.0f/180.0f*NVG_PI, images[i], a);
      nvg.fill();

      nvg.beginPath();
      nvg.rect(tx-5, ty-5, thumb+10, thumb+10);
      nvg.roundedRect(tx, ty, thumb, thumb, 6);
      nvg.pathWinding = NVGSolidity.Hole;
      nvg.fillPaint = nvg.boxGradient(tx-1, ty, thumb+2, thumb+2, 5, 3, nvgRGBA(0, 0, 0, 128), nvgRGBA(0, 0, 0, 0));
      nvg.fill();

      nvg.beginPath();
      nvg.roundedRect(tx+0.5f, ty+0.5f, thumb-1, thumb-1, 4-0.5f);
      nvg.strokeWidth = 1.0f;
      nvg.strokeColor = nvgRGBA(255, 255, 255, 192);
      nvg.stroke();
    }
  }

  // Hide fades
  nvg.beginPath();
  nvg.rect(x+4, y, w-8, 6);
  nvg.fillPaint = nvg.linearGradient(x, y, x, y+6, nvgRGBA(200, 200, 200, 255), nvgRGBA(200, 200, 200, 0));
  nvg.fill();

  nvg.beginPath();
  nvg.rect(x+4, y+h-6, w-8, 6);
  nvg.fillPaint = nvg.linearGradient(x, y+h, x, y+h-6, nvgRGBA(200, 200, 200, 255), nvgRGBA(200, 200, 200, 0));
  nvg.fill();

  // Scroll bar
  nvg.beginPath();
  nvg.roundedRect(x+w-12, y+4, 8, h-8, 3);
  nvg.fillPaint = nvg.boxGradient(x+w-12+1, y+4+1, 8, h-8, 3, 4, nvgRGBA(0, 0, 0, 32), nvgRGBA(0, 0, 0, 92));
  //vg.fillColor = nvgRGBA(255, 0, 0, 128);
  nvg.fill();

  immutable float scrollh = (h/stackh)*(h-8);
  nvg.beginPath();
  nvg.roundedRect(x+w-12+1, y+4+1+(h-8-scrollh)*u, 8-2, scrollh-2, 2);
  nvg.fillPaint = nvg.boxGradient(x+w-12-1, y+4+(h-8-scrollh)*u-1, 8, scrollh, 3, 4, nvgRGBA(220, 220, 220, 255), nvgRGBA(128, 128, 128, 255));
  //vg.fillColor = nvgRGBA(0, 0, 0, 128);
  nvg.fill();
}


void drawColorWheel (NVGContext nvg, float x, float y, float w, float h, float t) {
  import core.stdc.math : cosf, sinf;

  immutable float hue = sinf(t*0.12f);

  nvg.save();
  scope(exit) nvg.restore();

  /*
  vg.beginPath();
  vg.rect(x, y, w, h);
  vg.fillColor(nvgRGBA(255, 0, 0, 128));
  vg.fill();
  */

  immutable float cx = x+w*0.5f;
  immutable float cy = y+h*0.5f;
  immutable float r1 = (w < h ? w : h)*0.5f-5.0f;
  immutable float r0 = r1-20.0f;
  immutable float aeps = 0.5f/r1; // half a pixel arc length in radians (2pi cancels out).

  foreach (immutable int i; 0..6) {
    float a0 = cast(float)i/6.0f*NVG_PI*2.0f-aeps;
    float a1 = cast(float)(i+1.0f)/6.0f*NVG_PI*2.0f+aeps;
    nvg.beginPath();
    nvg.arc(NVGWinding.CW, cx, cy, r0, a0, a1);
    nvg.arc(NVGWinding.CCW, cx, cy, r1, a1, a0);
    nvg.closePath();
    immutable float ax = cx+cosf(a0)*(r0+r1)*0.5f;
    immutable float ay = cy+sinf(a0)*(r0+r1)*0.5f;
    immutable float bx = cx+cosf(a1)*(r0+r1)*0.5f;
    immutable float by = cy+sinf(a1)*(r0+r1)*0.5f;
    nvg.fillPaint = nvg.linearGradient(ax, ay, bx, by, nvgHSLA(a0/(NVG_PI*2), 1.0f, 0.55f, 255), nvgHSLA(a1/(NVG_PI*2), 1.0f, 0.55f, 255));
    nvg.fill();
  }

  nvg.beginPath();
  nvg.circle(cx, cy, r0-0.5f);
  nvg.circle(cx, cy, r1+0.5f);
  nvg.strokeColor = nvgRGBA(0, 0, 0, 64);
  nvg.strokeWidth = 1.0f;
  nvg.stroke();

  // Selector
  {
    nvg.save();
    scope(exit) nvg.restore();

    nvg.translate(cx, cy);
    nvg.rotate(hue*NVG_PI*2);

    // Marker on
    nvg.strokeWidth = 2.0f;
    nvg.beginPath();
    nvg.rect(r0-1, -3, r1-r0+2, 6);
    nvg.strokeColor = nvgRGBA(255, 255, 255, 192);
    nvg.stroke();

    nvg.beginPath();
    nvg.rect(r0-2-10, -4-10, r1-r0+4+20, 8+20);
    nvg.rect(r0-2, -4, r1-r0+4, 8);
    nvg.pathWinding = NVGSolidity.Hole;
    nvg.fillPaint = nvg.boxGradient(r0-3, -5, r1-r0+6, 10, 2, 4, nvgRGBA(0, 0, 0, 128), nvgRGBA(0, 0, 0, 0));
    nvg.fill();

    // Center triangle
    immutable float r = r0-6;
    immutable float ax = cosf(120.0f/180.0f*NVG_PI)*r;
    immutable float ay = sinf(120.0f/180.0f*NVG_PI)*r;
    immutable float bx = cosf(-120.0f/180.0f*NVG_PI)*r;
    immutable float by = sinf(-120.0f/180.0f*NVG_PI)*r;

    nvg.beginPath();
    nvg.moveTo(r, 0);
    nvg.lineTo(ax, ay);
    nvg.lineTo(bx, by);
    nvg.closePath();
    nvg.fillPaint = nvg.linearGradient(r, 0, ax, ay, nvgHSLA(hue, 1.0f, 0.5f, 255), nvgRGBA(255, 255, 255, 255));
    nvg.fill();
    nvg.fillPaint = nvg.linearGradient((r+ax)*0.5f, (0+ay)*0.5f, bx, by, nvgRGBA(0, 0, 0, 0), nvgRGBA(0, 0, 0, 255));
    nvg.fill();
    nvg.strokeColor = nvgRGBA(0, 0, 0, 64);
    nvg.stroke();

    // Select circle on triangle
    immutable float aax = cosf(120.0f/180.0f*NVG_PI)*r*0.3f;
    immutable float aay = sinf(120.0f/180.0f*NVG_PI)*r*0.4f;
    nvg.strokeWidth = 2.0f;
    nvg.beginPath();
    nvg.circle(aax, aay, 5);
    nvg.strokeColor = nvgRGBA(255, 255, 255, 192);
    nvg.stroke();

    nvg.beginPath();
    nvg.rect(aax-20, aay-20, 40, 40);
    nvg.circle(aax, aay, 7);
    nvg.pathWinding = NVGSolidity.Hole;
    nvg.fillPaint = nvg.radialGradient(aax, aay, 7, 9, nvgRGBA(0, 0, 0, 64), nvgRGBA(0, 0, 0, 0));
    nvg.fill();
  }
}


void drawLines (NVGContext nvg, float x, float y, float w, float h, float t) {
  import core.stdc.math : cosf, sinf;

  static immutable NVGLineCap[3] joins = [NVGLineCap.Miter, NVGLineCap.Round, NVGLineCap.Bevel];
  static immutable NVGLineCap[3] caps = [NVGLineCap.Butt, NVGLineCap.Round, NVGLineCap.Square];

  enum pad = 5.0f;
  immutable float s = w/9.0f-pad*2;

  nvg.save();
  scope(exit) nvg.restore();

  immutable float[4*2] pts = [
    -s*0.25f+cosf(t*0.3f)*s*0.5f,
    sinf(t*0.3f)*s*0.5f,
    -s*0.25,
    0,
    s*0.25f,
    0,
    s*0.25f+cosf(-t*0.3f)*s*0.5f,
    sinf(-t*0.3f)*s*0.5f,
  ];

  foreach (immutable int i; 0..3) {
    foreach (immutable int j; 0..3) {
      immutable float fx = x+s*0.5f+(i*3+j)/9.0f*w+pad;
      immutable float fy = y-s*0.5f+pad;

      nvg.lineCap = caps[i];
      nvg.lineJoin = joins[j];

      nvg.strokeWidth = s*0.3f;
      nvg.strokeColor = nvgRGBA(0, 0, 0, 160);
      nvg.beginPath();
      nvg.moveTo(fx+pts[0], fy+pts[1]);
      nvg.lineTo(fx+pts[2], fy+pts[3]);
      nvg.lineTo(fx+pts[4], fy+pts[5]);
      nvg.lineTo(fx+pts[6], fy+pts[7]);
      nvg.stroke();

      nvg.lineCap = NVGLineCap.Butt;
      nvg.lineJoin = NVGLineCap.Bevel;

      nvg.strokeWidth = 1.0f;
      nvg.strokeColor = nvgRGBA(0, 192, 255, 255);
      nvg.beginPath();
      nvg.moveTo(fx+pts[0], fy+pts[1]);
      nvg.lineTo(fx+pts[2], fy+pts[3]);
      nvg.lineTo(fx+pts[4], fy+pts[5]);
      nvg.lineTo(fx+pts[6], fy+pts[7]);
      nvg.stroke();
    }
  }
}


void drawParagraph (NVGContext nvg, float x, float y, float width, float height, float mx, float my) {
  static immutable string text = "This is longer chunk of text.\n  \n  Would have used lorem ipsum but she    was busy jumping over the lazy dog with the fox and all the men who came to the aid of the party.";

  float lineh;
  //float caretx, px;
  //float[4] bounds;
  //float a;
  //float gx, gy;
  int gutter = 0;

  nvg.save();
  scope(exit) nvg.restore();

  nvg.fontSize = 18.0f;
  nvg.fontFace = "sans";
  nvg.textAlign(NVGTextAlign.H.Left, NVGTextAlign.V.Top);
  nvg.textMetrics(null, null, &lineh);

  float gx = 0, gy = 0;
  int lnum = 0;
  nvg.textBreakLines(text, width, (in ref NVGTextRow!char row) {
    NVGGlyphPosition[100] glyphs = void;
    immutable bool hit = (mx > x && mx < x+width && my >= y && my < y+lineh);

    nvg.beginPath();
    nvg.fillColor(nvgRGBA(255, 255, 255, (hit ? 64 : 16)));
    nvg.rect(x, y, row.width, lineh);
    nvg.fill();

    nvg.fillColor(nvgRGBA(255, 255, 255, 255));
    nvg.text(x, y, row.row);

    if (hit) {
      float caretx = (mx < x+row.width/2 ? x : x+row.width);
      float px = x;
      auto rglyphs = nvg.textGlyphPositions(x, y, row.row, glyphs[]);
      foreach (immutable j, const ref glx; rglyphs) {
        float x0 = glx.x;
        float x1 = (j+1 < rglyphs.length ? glyphs[j+1].x : x+row.width);
        float gx_ = x0*0.3f+x1*0.7f;
        if (mx >= px && mx < gx_) caretx = glx.x;
        px = gx_;
      }
      nvg.beginPath();
      nvg.rect(caretx, y, 1, lineh);
      nvg.fillColor = nvgRGBA(255, 192, 0, 255);
      nvg.fill();

      gutter = lnum+1;
      gx = x-10;
      gy = y+lineh/2;
    }
    ++lnum;
    y += lineh;
    // return false; // to stop
  });

  float[4] bounds;

  if (gutter) {
    import core.stdc.stdio : snprintf;
    char[16] txt;
    auto len = snprintf(txt.ptr, (txt).sizeof, "%d", gutter);

    nvg.fontSize = 13.0f;
    nvg.textAlign(NVGTextAlign.H.Right, NVGTextAlign.V.Middle);
    nvg.textBounds(gx, gy, txt[0..len], bounds[]);

    nvg.beginPath();
    nvg.roundedRect(cast(int)bounds[0]-4, cast(int)bounds[1]-2, cast(int)(bounds[2]-bounds[0])+8, cast(int)(bounds[3]-bounds[1])+4, (cast(int)(bounds[3]-bounds[1])+4)/2-1);
    nvg.fillColor = nvgRGBA(255, 192, 0, 255);
    nvg.fill();

    nvg.fillColor = nvgRGBA(32, 32, 32, 255);
    nvg.text(gx, gy, txt[0..len]);
  }

  y += 20.0f;

  nvg.fontSize = 13.0f;
  nvg.textAlign(NVGTextAlign.H.Left, NVGTextAlign.V.Top);
  nvg.textLineHeight = 1.2f;

  nvg.textBoxBounds(x, y, 150, "Hover your mouse over the text to see calculated caret position.", bounds[]);

  // Fade the tooltip out when close to it.
  {
    immutable float ggx = nvg__absf((mx-(bounds[0]+bounds[2])*0.5f)/(bounds[0]-bounds[2]));
    immutable float ggy = nvg__absf((my-(bounds[1]+bounds[3])*0.5f)/(bounds[1]-bounds[3]));

    immutable float a = nvg__clamp(nvg__max(ggx, ggy)-0.5f, 0, 1);
    nvg.globalAlpha(a);

    nvg.beginPath();
    nvg.fillColor = nvgRGBA(220, 220, 220, 255);
    nvg.roundedRect(bounds[0]-2, bounds[1]-2, cast(int)(bounds[2]-bounds[0])+4, cast(int)(bounds[3]-bounds[1])+4, 3);
    immutable int px = cast(int)((bounds[2]+bounds[0])/2);
    nvg.moveTo(px, bounds[1]-10);
    nvg.lineTo(px+7, bounds[1]+1);
    nvg.lineTo(px-7, bounds[1]+1);
    nvg.fill();

    nvg.fillColor = nvgRGBA(0, 0, 0, 220);
    nvg.textBox(x, y, 150, "Hover your mouse over the text to see calculated caret position.");
  }
}


void drawWidths(NVGContext nvg, float x, float y, float width) {
  nvg.save();
  scope(exit) nvg.restore();

  nvg.strokeColor = nvgRGBA(0, 0, 0, 255);
  foreach (int i; 0..20) {
    nvg.strokeWidth = (i+0.5f)*0.1f;
    nvg.beginPath();
    nvg.moveTo(x, y);
    nvg.lineTo(x+width, y+width*0.3f);
    nvg.stroke();
    y += 10;
  }
}


void drawCaps (NVGContext nvg, float x, float y, float width) {
  static immutable NVGLineCap[3] caps = [NVGLineCap.Butt, NVGLineCap.Round, NVGLineCap.Square];
  enum lineWidth = 8.0f;

  nvg.save();
  scope(exit) nvg.restore();

  nvg.beginPath();
  nvg.rect(x-lineWidth/2, y, width+lineWidth, 40);
  nvg.fillColor = nvgRGBA(255, 255, 255, 32);
  nvg.fill();

  nvg.beginPath();
  nvg.rect(x, y, width, 40);
  nvg.fillColor = nvgRGBA(255, 255, 255, 32);
  nvg.fill();

  nvg.strokeWidth = lineWidth;
  foreach (int i; 0..3) {
    nvg.lineCap = caps[i];
    nvg.strokeColor = nvgRGBA(0, 0, 0, 255);
    nvg.beginPath();
    nvg.moveTo(x, y+i*10+5);
    nvg.lineTo(x+width, y+i*10+5);
    nvg.stroke();
  }
}


void drawScissor (NVGContext nvg, float x, float y, float t) {
  nvg.save();
  scope(exit) nvg.restore();

  // Draw first rect and set scissor to it's area.
  nvg.translate(x, y);
  nvg.rotate(5.nvgDegrees);
  nvg.beginPath();
  nvg.rect(-20, -20, 60, 40);
  nvg.fillColor = nvgRGBA(255, 0, 0, 255);
  nvg.fill();
  nvg.scissor(-20, -20, 60, 40);

  // Draw second rectangle with offset and rotation.
  nvg.translate(40, 0);
  nvg.rotate(t);

  // Draw the intended second rectangle without any scissoring.
  {
    nvg.save();
    scope(exit) nvg.restore();
    nvg.resetScissor();
    nvg.beginPath();
    nvg.rect(-20, -10, 60, 30);
    nvg.fillColor = nvgRGBA(255, 128, 0, 64);
    nvg.fill();
  }

  // Draw second rectangle with combined scissoring.
  nvg.intersectScissor(-20, -10, 60, 30);
  nvg.beginPath();
  nvg.rect(-20, -10, 60, 30);
  nvg.fillColor = nvgRGBA(255, 128, 0, 255);
  nvg.fill();
}


// ////////////////////////////////////////////////////////////////////////// //
void drawBlendish (NVGContext nvg, float _x, float _y, float _w, float _h, float _t) {
  import core.stdc.math : fmodf, cosf, sinf;
  import core.stdc.stdio : printf, snprintf;

  float x = _x;
  float y = _y;

  nvg.save();
  scope(exit) nvg.restore();

  nvg.globalAlpha(bndMoving ? 0.4 : 0.9);

  nvg.bndBackground(_x-10.0f, _y-10.0f, _w, _h);
  nvg.currFillPickId = WidgetIdBlendish;

  nvg.bndToolButton(x, y, 120.0f, BND_WIDGET_HEIGHT, BND_CORNER_NONE, BND_DEFAULT, BND_ICONID!(6, 3), "Default"); y += 25.0f;
  nvg.bndToolButton(x, y, 120.0f, BND_WIDGET_HEIGHT, BND_CORNER_NONE, BND_HOVER, BND_ICONID!(6, 3), "Hovered item"); y += 25.0f;
  nvg.bndToolButton(x, y, 120.0f, BND_WIDGET_HEIGHT, BND_CORNER_NONE, BND_ACTIVE, BND_ICONID!(6, 3), "Active"); y += 40.0f;

  nvg.bndRadioButton(x, y, 80.0f, BND_WIDGET_HEIGHT, BND_CORNER_NONE, BND_DEFAULT, -1, "Default"); y += 25.0f;
  nvg.bndRadioButton(x, y, 80.0f, BND_WIDGET_HEIGHT, BND_CORNER_NONE, BND_HOVER, -1, "Hovered item"); y += 25.0f;
  nvg.bndRadioButton(x, y, 80.0f, BND_WIDGET_HEIGHT, BND_CORNER_NONE, BND_ACTIVE, -1, "Active"); y += 25.0f;

  nvg.bndLabel(x, y, 120.0f, BND_WIDGET_HEIGHT, -1, "Label:"); y += BND_WIDGET_HEIGHT;
  nvg.bndChoiceButton(x, y, 80.0f, BND_WIDGET_HEIGHT, BND_CORNER_NONE, BND_DEFAULT, -1, "Default"); y += 25.0f;
  nvg.bndChoiceButton(x, y, 80.0f, BND_WIDGET_HEIGHT, BND_CORNER_NONE, BND_HOVER, -1, "Hovered item"); y += 25.0f;
  nvg.bndChoiceButton(x, y, 80.0f, BND_WIDGET_HEIGHT, BND_CORNER_NONE, BND_ACTIVE, -1, "Active"); y += 25.0f;

  float ry = y;
  float rx = x;

  y = _y;
  x += 130.0f;
  nvg.bndOptionButton(x, y, 120.0f, BND_WIDGET_HEIGHT, BND_DEFAULT, "Default"); y += 25.0f;
  nvg.bndOptionButton(x, y, 120.0f, BND_WIDGET_HEIGHT, BND_HOVER, "Hovered item"); y += 25.0f;
  nvg.bndOptionButton(x, y, 120.0f, BND_WIDGET_HEIGHT, BND_ACTIVE, "Active"); y += 40.0f;

  nvg.bndNumberField(x, y, 120.0f, BND_WIDGET_HEIGHT, BND_CORNER_DOWN, BND_DEFAULT, "Top", "100"); y += BND_WIDGET_HEIGHT-2.0f;
  nvg.bndNumberField(x, y, 120.0f, BND_WIDGET_HEIGHT, BND_CORNER_ALL, BND_DEFAULT, "Center", "100"); y += BND_WIDGET_HEIGHT-2.0f;
  nvg.bndNumberField(x, y, 120.0f, BND_WIDGET_HEIGHT, BND_CORNER_TOP, BND_DEFAULT, "Bottom", "100");

  float mx = x-30.0f;
  float my = y-12.0f;
  float mw = 120.0f;

  nvg.bndMenuBackground(mx, my, mw, 120.0f, BND_CORNER_TOP);
  nvg.bndMenuLabel(mx, my, mw, BND_WIDGET_HEIGHT, -1, "Menu Title"); my += BND_WIDGET_HEIGHT-2.0f;
  nvg.bndMenuItem(mx, my, mw, BND_WIDGET_HEIGHT, BND_DEFAULT, BND_ICONID!(17, 3), "Default"); my += BND_WIDGET_HEIGHT-2.0f;
  nvg.bndMenuItem(mx, my, mw, BND_WIDGET_HEIGHT, BND_HOVER, BND_ICONID!(18, 3), "Hovered item!"); my += BND_WIDGET_HEIGHT-2.0f;
  nvg.bndMenuItem(mx, my, mw, BND_WIDGET_HEIGHT, BND_ACTIVE, BND_ICONID!(19, 3), "Active");

  y = _y;
  x += 130.0f;
  float ox = x;
  nvg.bndNumberField(x, y, 120.0f, BND_WIDGET_HEIGHT, BND_CORNER_NONE, BND_DEFAULT, "Default", "100"); y += 25.0f;
  nvg.bndNumberField(x, y, 120.0f, BND_WIDGET_HEIGHT, BND_CORNER_NONE, BND_HOVER, "Hovered", "100"); y += 25.0f;
  nvg.bndNumberField(x, y, 120.0f, BND_WIDGET_HEIGHT, BND_CORNER_NONE, BND_ACTIVE, "Active", "100"); y += 40.0f;

  nvg.bndRadioButton(x, y, 60.0f, BND_WIDGET_HEIGHT, BND_CORNER_RIGHT, BND_DEFAULT, -1, "One"); x += 60.0f-1.0f;
  nvg.bndRadioButton(x, y, 60.0f, BND_WIDGET_HEIGHT, BND_CORNER_ALL, BND_DEFAULT, -1, "Two"); x += 60.0f-1.0f;
  nvg.bndRadioButton(x, y, 60.0f, BND_WIDGET_HEIGHT, BND_CORNER_ALL, BND_DEFAULT, -1, "Three"); x += 60.0f-1.0f;
  nvg.bndRadioButton(x, y, 60.0f, BND_WIDGET_HEIGHT, BND_CORNER_LEFT, BND_ACTIVE, -1, "Butts");

  x = ox;
  y += 40.0f;
  float progress_value = fmodf(_t/10.0f, 1.0f);
  char[32] progressLabel;
  int len = cast(int)snprintf(progressLabel.ptr, progressLabel.length, "%d%%", cast(int)(progress_value*100+0.5f));

  nvg.bndSlider(x, y, 240, BND_WIDGET_HEIGHT, BND_CORNER_NONE, BND_DEFAULT, progress_value, "Default", progressLabel[0..len]); y += 25.0f;
  nvg.bndSlider(x, y, 240, BND_WIDGET_HEIGHT, BND_CORNER_NONE, BND_HOVER, progress_value, "Hovered", progressLabel[0..len]); y += 25.0f;
  nvg.bndSlider(x, y, 240, BND_WIDGET_HEIGHT, BND_CORNER_NONE, BND_ACTIVE, progress_value, "Active", progressLabel[0..len]);

  float rw = x+240.0f-rx;
  float s_offset = sinf(_t/2.0f)*0.5f+0.5f;
  float s_size = cosf(_t/3.11f)*0.5f+0.5f;

  nvg.bndScrollBar(rx, ry, rw, BND_SCROLLBAR_HEIGHT, BND_DEFAULT, s_offset, s_size); ry += 20.0f;
  nvg.bndScrollBar(rx, ry, rw, BND_SCROLLBAR_HEIGHT, BND_HOVER, s_offset, s_size); ry += 20.0f;
  nvg.bndScrollBar(rx, ry, rw, BND_SCROLLBAR_HEIGHT, BND_ACTIVE, s_offset, s_size);

  static immutable string edit_text = "The quick brown fox";
  int textlen = cast(int)edit_text.length+1;
  int t = cast(int)(_t*2);
  int idx1 = (t/textlen)%textlen;
  int idx2 = idx1+(t%(textlen-idx1));

  ry += 25.0f;
  nvg.bndTextField(rx, ry, 240.0f, BND_WIDGET_HEIGHT, BND_CORNER_NONE, BND_DEFAULT, -1, edit_text, idx1, idx2); ry += 25.0f;
  nvg.bndTextField(rx, ry, 240.0f, BND_WIDGET_HEIGHT, BND_CORNER_NONE, BND_HOVER, -1, edit_text, idx1, idx2); ry += 25.0f;
  nvg.bndTextField(rx, ry, 240.0f, BND_WIDGET_HEIGHT, BND_CORNER_NONE, BND_ACTIVE, -1, edit_text, idx1, idx2);

  rx += rw+20.0f;
  ry = _y;
  nvg.bndScrollBar(rx, ry, BND_SCROLLBAR_WIDTH, 240.0f, BND_DEFAULT, s_offset, s_size); rx += 20.0f;
  nvg.bndScrollBar(rx, ry, BND_SCROLLBAR_WIDTH, 240.0f, BND_HOVER, s_offset, s_size); rx += 20.0f;
  nvg.bndScrollBar(rx, ry, BND_SCROLLBAR_WIDTH, 240.0f, BND_ACTIVE, s_offset, s_size);

  x = ox;
  y += 40.0f;
  nvg.bndToolButton(x, y, BND_TOOL_WIDTH, BND_WIDGET_HEIGHT, BND_CORNER_RIGHT, BND_DEFAULT, BND_ICONID!(0, 10), null); x += BND_TOOL_WIDTH-1;
  nvg.bndToolButton(x, y, BND_TOOL_WIDTH, BND_WIDGET_HEIGHT, BND_CORNER_ALL, BND_DEFAULT, BND_ICONID!(1, 10), null); x += BND_TOOL_WIDTH-1;
  nvg.bndToolButton(x, y, BND_TOOL_WIDTH, BND_WIDGET_HEIGHT, BND_CORNER_ALL, BND_DEFAULT, BND_ICONID!(2, 10), null); x += BND_TOOL_WIDTH-1;
  nvg.bndToolButton(x, y, BND_TOOL_WIDTH, BND_WIDGET_HEIGHT, BND_CORNER_ALL, BND_DEFAULT, BND_ICONID!(3, 10), null); x += BND_TOOL_WIDTH-1;
  nvg.bndToolButton(x, y, BND_TOOL_WIDTH, BND_WIDGET_HEIGHT, BND_CORNER_ALL, BND_DEFAULT, BND_ICONID!(4, 10), null); x += BND_TOOL_WIDTH-1;
  nvg.bndToolButton(x, y, BND_TOOL_WIDTH, BND_WIDGET_HEIGHT, BND_CORNER_LEFT, BND_DEFAULT, BND_ICONID!(5, 10), null); x += BND_TOOL_WIDTH-1;

  x += 5.0f;
  nvg.bndRadioButton(x, y, BND_TOOL_WIDTH, BND_WIDGET_HEIGHT, BND_CORNER_RIGHT, BND_DEFAULT, BND_ICONID!(0, 11), null); x += BND_TOOL_WIDTH-1;
  nvg.bndRadioButton(x, y, BND_TOOL_WIDTH, BND_WIDGET_HEIGHT, BND_CORNER_ALL, BND_DEFAULT, BND_ICONID!(1, 11), null); x += BND_TOOL_WIDTH-1;
  nvg.bndRadioButton(x, y, BND_TOOL_WIDTH, BND_WIDGET_HEIGHT, BND_CORNER_ALL, BND_DEFAULT, BND_ICONID!(2, 11), null); x += BND_TOOL_WIDTH-1;
  nvg.bndRadioButton(x, y, BND_TOOL_WIDTH, BND_WIDGET_HEIGHT, BND_CORNER_ALL, BND_DEFAULT, BND_ICONID!(3, 11), null); x += BND_TOOL_WIDTH-1;
  nvg.bndRadioButton(x, y, BND_TOOL_WIDTH, BND_WIDGET_HEIGHT, BND_CORNER_ALL, BND_ACTIVE, BND_ICONID!(4, 11), null); x += BND_TOOL_WIDTH-1;
  nvg.bndRadioButton(x, y, BND_TOOL_WIDTH, BND_WIDGET_HEIGHT, BND_CORNER_LEFT, BND_DEFAULT, BND_ICONID!(5, 11), null);
}


// ////////////////////////////////////////////////////////////////////////// //
void main () {
  import core.time;

  DemoData data;
  NVGContext nvg = null;
  PerfGraph fps;

  double mx = 0, my = 0;
  bool doQuit = false;

  setOpenGLContextVersion(3, 0); // it's enough

  sdpyWindowClass = "NANOVEGA_EXAMPLE";
  auto sdwindow = new SimpleWindow(GWidth, GHeight, "NanoVega", OpenGlOptions.yes, Resizability.fixedSize);

  version(X11) sdwindow.closeQuery = delegate () { doQuit = true; };

  sdwindow.onClosing = delegate () {
    if (nvg !is null) {
      freeDemoData(nvg, data);
      bndClearIconImage();
      nvg.kill();
    }
  };

  auto stt = MonoTime.currTime;
  auto prevt = MonoTime.currTime;
  auto curt = prevt;
  float dt = 0, secs = 0;

  sdwindow.visibleForTheFirstTime = delegate () {
    //sdwindow.setAsCurrentOpenGlContext(); // make this window active
    sdwindow.vsync = false;

    nvg = nvgCreateContext();
    if (nvg is null) fatal("cannot init NanoVega");
    if (!nvg.loadDemoData(data)) fatal("cannot load demo data");

    fps = new PerfGraph("Frame Time", PerfGraph.Style.FPS, "sans");
  };

  sdwindow.redrawOpenGlScene = delegate () {
    // timers
    prevt = curt;
    curt = MonoTime.currTime;
    secs = cast(double)((curt-stt).total!"msecs")/1000.0;
    dt = cast(double)((curt-prevt).total!"msecs")/1000.0;

    // Update and render
    glViewport(0, 0, sdwindow.width, sdwindow.height);
    if (premult) glClearColor(0, 0, 0, 0); else glClearColor(0.3f, 0.3f, 0.32f, 1.0f);
    glClear(glNVGClearFlags);

    if (nvg !is null) {
      if (fps !is null) fps.update(dt);
      nvg.beginFrame(GWidth, GHeight, 1);
      renderDemo(nvg, mx, my, GWidth, GHeight, secs, blowup, data);
      if (fps !is null) fps.render(nvg, 5, 5);
      nvg.endFrame();
    }
  };

  sdwindow.eventLoop(1000/35,
    delegate () {
      if (sdwindow.closed) return;
      if (doQuit) { sdwindow.close(); return; }
      sdwindow.redrawOpenGlSceneNow();
    },

    delegate (KeyEvent event) {
      if (sdwindow.closed) return;
      if (event == "D-*-Q" || event == "D-Escape") { sdwindow.close(); return; }
      if (event == "D-Space") { blowup = !blowup; return; }
      if (event == "D-P") { premult = !premult; return; }
    },

    delegate (MouseEvent event) {
      mx = event.x;
      my = event.y;

      int wid = nvg.hitTest(mx, my, NVGPickKind.Fill);

      if (event == "RMB-Down") {
             if (wid == WidgetIdRaw) { wgOnTop = true; wgMoving = true; bndMoving = false; }
        else if (wid == WidgetIdBlendish) { wgOnTop = false; wgMoving = false; bndMoving = true; }
      }

      if (event == "RMB-Up") {
        wgMoving = false;
        bndMoving = false;
      }

      if (event == "LMB-Down") {
             if (wid == WidgetIdRaw) wgOnTop = true;
        else if (wid == WidgetIdBlendish) wgOnTop = false;
      }

      if (event == "Motion") {
        if (bndMoving) { bndX += event.dx; bndY += event.dy; }
        if (wgMoving) { wgX += event.dx; wgY += event.dy; }
      }

      if (wid == WidgetIdRaw || wid == WidgetIdBlendish) mx = my = -666;
    },
  );
}
