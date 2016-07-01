//
// based on NanoVG's example code by Mikko Mononen
import core.time;
import core.stdc.stdio : snprintf;
import iv.nanovg;
import iv.nanovg.oui;
import perf;

import arsd.simpledisplay;
import arsd.color;
import arsd.png;
import arsd.jpeg;

import std.functional : toDelegate;

// sdpy is missing that yet
static if (!is(typeof(GL_STENCIL_BUFFER_BIT))) enum uint GL_STENCIL_BUFFER_BIT = 0x00000400;


////////////////////////////////////////////////////////////////////////////////
enum GWidth = 650;
enum GHeight = 650;


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
  version(nanovg_demo_msfonts) {
    bndSetFont(nvgCreateFont(vg, "system", "/home/ketmar/ttf/ms/tahoma.ttf"));
  } else {
    bndSetFont(nvgCreateFont(vg, "system", "data/Roboto-Regular.ttf"));
  }
  bndSetIconImage(nvgCreateImage(vg, "data/images/blender_icons16.png", 0));
}


// ////////////////////////////////////////////////////////////////////////// //
void demohandler (int item, UIevent event) {
  import std.stdio;
  writefln("clicked: %s %s", uiGetHandle(item), ctlGetButtonLabel(item));
}


// ////////////////////////////////////////////////////////////////////////// //
void draw_noodles (NVGcontext* vg, int x, int y) {
  int w = 200;
  int s = 70;

  bndNodeBackground(vg, x+w, y-50, 100, 200, BND_DEFAULT, BND_ICONID!(6, 3), "Default", nvgRGBf(0.392f, 0.392f, 0.392f));
  bndNodeBackground(vg, x+w+120, y-50, 100, 200, BND_HOVER, BND_ICONID!(6, 3), "Hover", nvgRGBf(0.392f, 0.392f, 0.392f));
  bndNodeBackground(vg, x+w+240, y-50, 100, 200, BND_ACTIVE, BND_ICONID!(6, 3), "Active", nvgRGBf(0.392f, 0.392f, 0.392f));

  for (int i = 0; i < 9; ++i) {
    int a = i%3;
    int b = i/3;
    bndNodeWire(vg, x, y+s*a, x+w, y+s*b, cast(BNDwidgetState)a, cast(BNDwidgetState)b);
  }

  bndNodePort(vg, x, y, BND_DEFAULT, nvgRGBf(0.5f, 0.5f, 0.5f));
  bndNodePort(vg, x+w, y, BND_DEFAULT, nvgRGBf(0.5f, 0.5f, 0.5f));
  bndNodePort(vg, x, y+s, BND_HOVER, nvgRGBf(0.5f, 0.5f, 0.5f));
  bndNodePort(vg, x+w, y+s, BND_HOVER, nvgRGBf(0.5f, 0.5f, 0.5f));
  bndNodePort(vg, x, y+2*s, BND_ACTIVE, nvgRGBf(0.5f, 0.5f, 0.5f));
  bndNodePort(vg, x+w, y+2*s, BND_ACTIVE, nvgRGBf(0.5f, 0.5f, 0.5f));
}


// ////////////////////////////////////////////////////////////////////////// //
void roothandler (int parent, UIevent event) {
  import std.stdio;
  switch (event) {
    default: break;
    case UI_SCROLL:
      UIvec2 pos = uiGetScroll();
      writefln("scroll! %d %d", pos.x, pos.y);
      break;
    case UI_BUTTON0_DOWN:
      writefln("%d clicks", uiGetClicks());
      break;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
void draw_demostuff (NVGcontext* vg, int x, int y, float w, float h) {
  import core.stdc.math : fmodf, cosf, sinf;

  nvgSave(vg);
  scope(exit) nvgRestore(vg);

  nvgTranslate(vg, x, y);

  bndSplitterWidgets(vg, 0, 0, w, h);

  x = 10;
  y = 10;

  bndToolButton(vg, x, y, 120, BND_WIDGET_HEIGHT, BND_CORNER_NONE, BND_DEFAULT, BND_ICONID!(6, 3), "Default");
  y += 25;
  bndToolButton(vg, x, y, 120, BND_WIDGET_HEIGHT, BND_CORNER_NONE, BND_HOVER, BND_ICONID!(6, 3), "Hovered");
  y += 25;
  bndToolButton(vg, x, y, 120, BND_WIDGET_HEIGHT, BND_CORNER_NONE, BND_ACTIVE, BND_ICONID!(6, 3), "Active");

  y += 40;
  bndRadioButton(vg, x, y, 80, BND_WIDGET_HEIGHT, BND_CORNER_NONE, BND_DEFAULT, -1, "Default");
  y += 25;
  bndRadioButton(vg, x, y, 80, BND_WIDGET_HEIGHT, BND_CORNER_NONE, BND_HOVER, -1, "Hovered");
  y += 25;
  bndRadioButton(vg, x, y, 80, BND_WIDGET_HEIGHT, BND_CORNER_NONE, BND_ACTIVE, -1, "Active");

  y += 25;
  bndLabel(vg, x, y, 120, BND_WIDGET_HEIGHT, -1, "Label:");
  y += BND_WIDGET_HEIGHT;
  bndChoiceButton(vg, x, y, 80, BND_WIDGET_HEIGHT, BND_CORNER_NONE, BND_DEFAULT, -1, "Default");
  y += 25;
  bndChoiceButton(vg, x, y, 80, BND_WIDGET_HEIGHT, BND_CORNER_NONE, BND_HOVER, -1, "Hovered");
  y += 25;
  bndChoiceButton(vg, x, y, 80, BND_WIDGET_HEIGHT, BND_CORNER_NONE, BND_ACTIVE, -1, "Active");

  y += 25;
  int ry = y;
  int rx = x;

  y = 10;
  x += 130;
  bndOptionButton(vg, x, y, 120, BND_WIDGET_HEIGHT, BND_DEFAULT, "Default");
  y += 25;
  bndOptionButton(vg, x, y, 120, BND_WIDGET_HEIGHT, BND_HOVER, "Hovered");
  y += 25;
  bndOptionButton(vg, x, y, 120, BND_WIDGET_HEIGHT, BND_ACTIVE, "Active");

  y += 40;
  bndNumberField(vg, x, y, 120, BND_WIDGET_HEIGHT, BND_CORNER_DOWN, BND_DEFAULT, "Top", "100");
  y += BND_WIDGET_HEIGHT-2;
  bndNumberField(vg, x, y, 120, BND_WIDGET_HEIGHT, BND_CORNER_ALL, BND_DEFAULT, "Center", "100");
  y += BND_WIDGET_HEIGHT-2;
  bndNumberField(vg, x, y, 120, BND_WIDGET_HEIGHT, BND_CORNER_TOP, BND_DEFAULT, "Bottom", "100");

  int mx = x-30;
  int my = y-12;
  int mw = 120;
  bndMenuBackground(vg, mx, my, mw, 120, BND_CORNER_TOP);
  bndMenuLabel(vg, mx, my, mw, BND_WIDGET_HEIGHT, -1, "Menu Title");
  my += BND_WIDGET_HEIGHT-2;
  bndMenuItem(vg, mx, my, mw, BND_WIDGET_HEIGHT, BND_DEFAULT, BND_ICONID!(17, 3), "Default");
  my += BND_WIDGET_HEIGHT-2;
  bndMenuItem(vg, mx, my, mw, BND_WIDGET_HEIGHT, BND_HOVER, BND_ICONID!(18, 3), "Hovered");
  my += BND_WIDGET_HEIGHT-2;
  bndMenuItem(vg, mx, my, mw, BND_WIDGET_HEIGHT, BND_ACTIVE, BND_ICONID!(19, 3), "Active");

  y = 10;
  x += 130;
  int ox = x;
  bndNumberField(vg, x, y, 120, BND_WIDGET_HEIGHT, BND_CORNER_NONE, BND_DEFAULT, "Default", "100");
  y += 25;
  bndNumberField(vg, x, y, 120, BND_WIDGET_HEIGHT, BND_CORNER_NONE, BND_HOVER, "Hovered", "100");
  y += 25;
  bndNumberField(vg, x, y, 120, BND_WIDGET_HEIGHT, BND_CORNER_NONE, BND_ACTIVE, "Active", "100");

  y += 40;
  bndRadioButton(vg, x, y, 60, BND_WIDGET_HEIGHT, BND_CORNER_RIGHT, BND_DEFAULT, -1, "One");
  x += 60-1;
  bndRadioButton(vg, x, y, 60, BND_WIDGET_HEIGHT, BND_CORNER_ALL, BND_DEFAULT, -1, "Two");
  x += 60-1;
  bndRadioButton(vg, x, y, 60, BND_WIDGET_HEIGHT, BND_CORNER_ALL, BND_DEFAULT, -1, "Three");
  x += 60-1;
  bndRadioButton(vg, x, y, 60, BND_WIDGET_HEIGHT, BND_CORNER_LEFT, BND_ACTIVE, -1, "Butts");

  x = ox;
  y += 40;
  float progress_value = fmodf(getSeconds()/10.0, 1.0);
  char[32] progress_label;
  int len = cast(int)snprintf(progress_label.ptr, progress_label.length, "%d%%", cast(int)(progress_value*100+0.5f));
  bndSlider(vg, x, y, 240, BND_WIDGET_HEIGHT, BND_CORNER_NONE, BND_DEFAULT, progress_value, "Default", progress_label[0..len]);
  y += 25;
  bndSlider(vg, x, y, 240, BND_WIDGET_HEIGHT, BND_CORNER_NONE, BND_HOVER, progress_value, "Hovered", progress_label[0..len]);
  y += 25;
  bndSlider(vg, x, y, 240, BND_WIDGET_HEIGHT, BND_CORNER_NONE, BND_ACTIVE, progress_value, "Active", progress_label[0..len]);

  int rw = x+240-rx;
  float s_offset = sinf(getSeconds()/2.0)*0.5+0.5;
  float s_size = cosf(getSeconds()/3.11)*0.5+0.5;

  bndScrollBar(vg, rx, ry, rw, BND_SCROLLBAR_HEIGHT, BND_DEFAULT, s_offset, s_size);
  ry += 20;
  bndScrollBar(vg, rx, ry, rw, BND_SCROLLBAR_HEIGHT, BND_HOVER, s_offset, s_size);
  ry += 20;
  bndScrollBar(vg, rx, ry, rw, BND_SCROLLBAR_HEIGHT, BND_ACTIVE, s_offset, s_size);

  string edit_text = "The quick brown fox";
  int textlen = cast(int)edit_text.length+1;
  int t = cast(int)(getSeconds()*2);
  int idx1 = (t/textlen)%textlen;
  int idx2 = idx1 + (t%(textlen-idx1));

  ry += 25;
  bndTextField(vg, rx, ry, 240, BND_WIDGET_HEIGHT, BND_CORNER_NONE, BND_DEFAULT, -1, edit_text, idx1, idx2);
  ry += 25;
  bndTextField(vg, rx, ry, 240, BND_WIDGET_HEIGHT, BND_CORNER_NONE, BND_HOVER, -1, edit_text, idx1, idx2);
  ry += 25;
  bndTextField(vg, rx, ry, 240, BND_WIDGET_HEIGHT, BND_CORNER_NONE, BND_ACTIVE, -1, edit_text, idx1, idx2);

  draw_noodles(vg, 20, ry+50);

  rx += rw + 20;
  ry = 10;
  bndScrollBar(vg, rx, ry, BND_SCROLLBAR_WIDTH, 240, BND_DEFAULT, s_offset, s_size);
  rx += 20;
  bndScrollBar(vg, rx, ry, BND_SCROLLBAR_WIDTH, 240, BND_HOVER, s_offset, s_size);
  rx += 20;
  bndScrollBar(vg, rx, ry, BND_SCROLLBAR_WIDTH, 240, BND_ACTIVE, s_offset, s_size);

  x = ox;
  y += 40;
  bndToolButton(vg, x, y, BND_TOOL_WIDTH, BND_WIDGET_HEIGHT, BND_CORNER_RIGHT, BND_DEFAULT, BND_ICONID!(0, 10), null);
  x += BND_TOOL_WIDTH-1;
  bndToolButton(vg, x, y, BND_TOOL_WIDTH, BND_WIDGET_HEIGHT, BND_CORNER_ALL, BND_DEFAULT, BND_ICONID!(1, 10), null);
  x += BND_TOOL_WIDTH-1;
  bndToolButton(vg, x, y, BND_TOOL_WIDTH, BND_WIDGET_HEIGHT, BND_CORNER_ALL, BND_DEFAULT, BND_ICONID!(2, 10), null);
  x += BND_TOOL_WIDTH-1;
  bndToolButton(vg, x, y, BND_TOOL_WIDTH, BND_WIDGET_HEIGHT, BND_CORNER_ALL, BND_DEFAULT, BND_ICONID!(3, 10), null);
  x += BND_TOOL_WIDTH-1;
  bndToolButton(vg, x, y, BND_TOOL_WIDTH, BND_WIDGET_HEIGHT, BND_CORNER_ALL, BND_DEFAULT, BND_ICONID!(4, 10), null);
  x += BND_TOOL_WIDTH-1;
  bndToolButton(vg, x, y, BND_TOOL_WIDTH, BND_WIDGET_HEIGHT, BND_CORNER_LEFT, BND_DEFAULT, BND_ICONID!(5, 10), null);
  x += BND_TOOL_WIDTH-1;
  x += 5;
  bndRadioButton(vg, x, y, BND_TOOL_WIDTH, BND_WIDGET_HEIGHT, BND_CORNER_RIGHT, BND_DEFAULT, BND_ICONID!(0, 11), null);
  x += BND_TOOL_WIDTH-1;
  bndRadioButton(vg, x, y, BND_TOOL_WIDTH, BND_WIDGET_HEIGHT, BND_CORNER_ALL, BND_DEFAULT, BND_ICONID!(1, 11), null);
  x += BND_TOOL_WIDTH-1;
  bndRadioButton(vg, x, y, BND_TOOL_WIDTH, BND_WIDGET_HEIGHT, BND_CORNER_ALL, BND_DEFAULT, BND_ICONID!(2, 11), null);
  x += BND_TOOL_WIDTH-1;
  bndRadioButton(vg, x, y, BND_TOOL_WIDTH, BND_WIDGET_HEIGHT, BND_CORNER_ALL, BND_DEFAULT, BND_ICONID!(3, 11), null);
  x += BND_TOOL_WIDTH-1;
  bndRadioButton(vg, x, y, BND_TOOL_WIDTH, BND_WIDGET_HEIGHT, BND_CORNER_ALL, BND_ACTIVE, BND_ICONID!(4, 11), null);
  x += BND_TOOL_WIDTH-1;
  bndRadioButton(vg, x, y, BND_TOOL_WIDTH, BND_WIDGET_HEIGHT, BND_CORNER_LEFT, BND_DEFAULT, BND_ICONID!(5, 11), null);
}


// ////////////////////////////////////////////////////////////////////////// //
__gshared int enum1 = -1;


// ////////////////////////////////////////////////////////////////////////// //
void build_democontent (int parent) {
  // some persistent variables for demonstration
  __gshared float progress1 = 0.25f;
  __gshared float progress2 = 0.75f;
  __gshared int option1 = 1;
  __gshared int option2 = 0;
  __gshared int option3 = 0;

  int col = column();
  uiInsert(parent, col);
  uiSetMargins(col, 10, 10, 10, 10);
  uiSetLayout(col, UI_TOP|UI_HFILL);

  column_append(col, button(BND_ICON_GHOST, "Item 1", toDelegate(&demohandler)));
  if (option3) column_append(col, button(BND_ICON_GHOST, "Item 2", toDelegate(&demohandler)));
  {
    int h = column_append(col, hbox());
    hgroup_append(h, radio(BND_ICON_GHOST, "Item 3.0", &enum1));
    if (option2) uiSetMargins(hgroup_append_fixed(h, radio(BND_ICON_REC, "", &enum1)), -1, 0, 0, 0);
    uiSetMargins(hgroup_append_fixed(h, radio(BND_ICON_PLAY, "", &enum1)), -1, 0, 0, 0);
    uiSetMargins(hgroup_append(h, radio(BND_ICON_GHOST, "Item 3.3", &enum1)), -1, 0, 0, 0);
  }
  {
    int rows = column_append(col, row());
    int coll = row_append(rows, vgroup());
    vgroup_append(coll, label(-1, "Items 4.0:"));
    coll = vgroup_append(coll, vbox());
    vgroup_append(coll, button(BND_ICON_GHOST, "Item 4.0.0", toDelegate(&demohandler)));
    uiSetMargins(vgroup_append(coll, button(BND_ICON_GHOST, "Item 4.0.1", toDelegate(&demohandler))), 0, -2, 0, 0);
    int colr = row_append(rows, vgroup());
    uiSetMargins(colr, 8, 0, 0, 0);
    uiSetFrozen(colr, option1);
    vgroup_append(colr, label(-1, "Items 4.1:"));
    colr = vgroup_append(colr, vbox());
    vgroup_append(colr, slider("Item 4.1.0", &progress1));
    uiSetMargins(vgroup_append(colr, slider("Item 4.1.1", &progress2)), 0, -2, 0, 0);
  }

  column_append(col, button(BND_ICON_GHOST, "Item 5", null));

  __gshared CtlTextData text;
  __gshared bool inited = false;
  if (!inited) {
    inited = true;
    text.text = "The quick brown fox.".dup;
  }
  column_append(col, textbox(&text, 1024));

  column_append(col, check("Frozen", &option1));
  column_append(col, check("Item 7", &option2));
  column_append(col, check("Item 8", &option3));
}


// ////////////////////////////////////////////////////////////////////////// //
int demorect(T : const(char)[]) (int parent, T label, float hue, int box, int layout, int w, int h, int m1, int m2, int m3, int m4) {
  int item = colorrect(label, nvgHSL(hue, 1.0f, 0.8f));
  uiSetLayout(item, layout);
  uiSetBox(item, box);
  uiSetMargins(item, cast(short)m1, cast(short)m2, cast(short)m3, cast(short)m4);
  uiSetSize(item, w, h);
  uiInsert(parent, item);
  return item;
}


// ////////////////////////////////////////////////////////////////////////// //
void build_layoutdemo (int parent) {
  enum int M = 10;
  enum int S = 150;

  int box = demorect(parent, "Box( UI_LAYOUT )\nLayout( UI_FILL )", 0.6f, UI_LAYOUT, UI_FILL, 0, 0, M, M, M, M);
  demorect(box, "Layout( UI_HFILL | UI_TOP )", 0.7f, 0, UI_HFILL|UI_TOP, S, S+M, M, M, M, 0);
  demorect(box, "Layout( UI_HFILL )", 0.7f, 0, UI_HFILL, S, S+2*M, M, 0, M, 0);
  demorect(box, "Layout( UI_HFILL | UI_DOWN )", 0.7f, 0, UI_HFILL|UI_DOWN, S, S+M, M, 0, M, M);

  demorect(box, "Layout( UI_LEFT | UI_VFILL )", 0.7f, 0, UI_LEFT|UI_VFILL, S+M, S, M, M, 0, M);
  demorect(box, "Layout( UI_VFILL )", 0.7f, 0, UI_VFILL, S+2*M, S, 0, M, 0, M);
  demorect(box, "Layout( UI_RIGHT | UI_VFILL )", 0.7f, 0, UI_RIGHT|UI_VFILL, S+M, S, 0, M, M, M);

  demorect(box, "Layout( UI_LEFT | UI_TOP )", 0.55f, 0, UI_LEFT|UI_TOP, S, S, M, M, 0, 0);
  demorect(box, "Layout( UI_TOP )", 0.57f, 0, UI_TOP, S, S, 0, M, 0, 0);
  demorect(box, "Layout( UI_RIGHT | UI_TOP )", 0.55f, 0, UI_RIGHT|UI_TOP, S, S, 0, M, M, 0);
  demorect(box, "Layout( UI_LEFT )", 0.57f, 0, UI_LEFT, S, S, M, 0, 0, 0);
  demorect(box, "Layout( UI_CENTER )", 0.59f, 0, UI_CENTER, S, S, 0, 0, 0, 0);
  demorect(box, "Layout( UI_RIGHT )", 0.57f, 0, UI_RIGHT, S, S, 0, 0, M, 0);
  demorect(box, "Layout( UI_LEFT | UI_DOWN )", 0.55f, 0, UI_LEFT|UI_DOWN, S, S, M, 0, 0, M);
  demorect(box, "Layout( UI_DOWN)", 0.57f, 0, UI_DOWN, S, S, 0, 0, 0, M);
  demorect(box, "Layout( UI_RIGHT | UI_DOWN )", 0.55f, 0, UI_RIGHT|UI_DOWN, S, S, 0, 0, M, M);
}


// ////////////////////////////////////////////////////////////////////////// //
void build_rowdemo (int parent) {
  uiSetBox(parent, UI_COLUMN);

  enum int M = 10;
  enum int S = 200;
  enum int T = 100;

  {
    int box = demorect(parent, "Box( UI_ROW )\nLayout( UI_LEFT | UI_VFILL )", 0.6f, UI_ROW, UI_LEFT|UI_VFILL, 0, S, M, M, M, M);
    demorect(box, "Layout( UI_TOP )", 0.05f, 0, UI_TOP, T, T, M, M, M, 0);
    demorect(box, "Layout( UI_VCENTER )", 0.1f, 0, UI_VCENTER, T, T, 0, 0, M, 0);
    demorect(box, "Layout( UI_VFILL )", 0.15f, 0, UI_VFILL, T, T, 0, M, M, M);
    demorect(box, "Layout( UI_DOWN )", 0.25f, 0, UI_DOWN, T, T, 0, 0, M, M);
  }
  {
    int box = demorect(parent, "Box( UI_ROW | UI_JUSTIFY )\nLayout( UI_FILL )", 0.6f, UI_ROW|UI_JUSTIFY, UI_FILL, 0, S, M, 0, M, M);
    demorect(box, "Layout( UI_TOP )", 0.05f, 0, UI_TOP, T, T, M, M, M, 0);
    demorect(box, "Layout( UI_VCENTER )", 0.1f, 0, UI_VCENTER, T, T, 0, 0, M, 0);
    demorect(box, "Layout( UI_VFILL )", 0.15f, 0, UI_VFILL, T, T, 0, M, M, M);
    demorect(box, "Layout( UI_DOWN )", 0.25f, 0, UI_DOWN, T, T, 0, 0, M, M);
  }
  {
    int box = demorect(parent, "Box( UI_ROW )\nLayout( UI_FILL )", 0.6f, UI_ROW, UI_FILL, 0, S, M, 0, M, M);
    demorect(box, "Layout( UI_TOP )", 0.05f, 0, UI_TOP, T, T, M, M, M, 0);
    demorect(box, "Layout( UI_VCENTER )", 0.1f, 0, UI_VCENTER, T, T, 0, 0, M, 0);
    demorect(box, "Layout( UI_VFILL )", 0.15f, 0, UI_VFILL, T, T, 0, M, M, M);
    demorect(box, "Layout( UI_HFILL )", 0.2f, 0, UI_HFILL, T, T, 0, 0, M, 0);
    demorect(box, "Layout( UI_HFILL )", 0.2f, 0, UI_HFILL, T, T, 0, 0, M, 0);
    demorect(box, "Layout( UI_HFILL )", 0.2f, 0, UI_HFILL, T, T, 0, 0, M, 0);
    demorect(box, "Layout( UI_DOWN )", 0.25f, 0, UI_DOWN, T, T, 0, 0, M, M);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
void build_columndemo (int parent) {
  uiSetBox(parent, UI_ROW);

  enum int M = 10;
  enum int S = 200;
  enum int T = 100;

  {
    int box = demorect(parent, "Box( UI_COLUMN )\nLayout( UI_TOP | UI_HFILL )", 0.6f, UI_COLUMN, UI_TOP|UI_HFILL, S, 0, M, M, M, M);
    demorect(box, "Layout( UI_LEFT )", 0.05f, 0, UI_LEFT, T, T, M, M, 0, M);
    demorect(box, "Layout( UI_HCENTER )", 0.1f, 0, UI_HCENTER, T, T, 0, 0, 0, M);
    demorect(box, "Layout( UI_HFILL )", 0.15f, 0, UI_HFILL, T, T, M, 0, M, M);
    demorect(box, "Layout( UI_RIGHT )", 0.25f, 0, UI_RIGHT, T, T, 0, 0, M, M);
  }
  {
    int box = demorect(parent, "Box( UI_COLUMN )\nLayout( UI_FILL )", 0.6f, UI_COLUMN, UI_FILL, S, 0, 0, M, M, M);
    demorect(box, "Layout( UI_LEFT )", 0.05f, 0, UI_LEFT, T, T, M, M, 0, M);
    demorect(box, "Layout( UI_HCENTER )", 0.1f, 0, UI_HCENTER, T, T, 0, 0, 0, M);
    demorect(box, "Layout( UI_HFILL )", 0.15f, 0, UI_HFILL, T, T, M, 0, M, M);
    demorect(box, "Layout( UI_RIGHT )", 0.25f, 0, UI_RIGHT, T, T, 0, 0, M, M);
  }
  {
    int box = demorect(parent, "Box( UI_COLUMN )\nLayout( UI_FILL )", 0.6f, UI_COLUMN, UI_FILL, S, 0, 0, M, M, M);
    demorect(box, "Layout( UI_LEFT )", 0.05f, 0, UI_LEFT, T, T, M, M, 0, M);
    demorect(box, "Layout( UI_HCENTER )", 0.1f, 0, UI_HCENTER, T, T, 0, 0, 0, M);
    demorect(box, "Layout( UI_HFILL )", 0.15f, 0, UI_HFILL, T, T, M, 0, M, M);
    demorect(box, "Layout( UI_VFILL )", 0.2f, 0, UI_VFILL, T, T, 0, 0, 0, M);
    demorect(box, "Layout( UI_VFILL )", 0.2f, 0, UI_VFILL, T, T, 0, 0, 0, M);
    demorect(box, "Layout( UI_VFILL )", 0.2f, 0, UI_VFILL, T, T, 0, 0, 0, M);
    demorect(box, "Layout( UI_RIGHT )", 0.25f, 0, UI_RIGHT, T, T, 0, 0, M, M);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
void fill_wrap_row_box (int box) {
  enum int M = 5;
  enum int S = 100;
  enum int T = 50;

  import std.random;
  rndGen.seed(666);
  for (int i = 0; i < 20; ++i) {
    float hue = cast(float)(uniform!"[)"(0, 360))/360.0f;
    int width = 10 + (uniform!"[)"(0, 5))*10;

    int u;
    switch (uniform!"[)"(0, 4)) {
      default: break;
      case 0:
        u = demorect(box, "Layout( UI_TOP )", hue, 0, UI_TOP, width, T, M, M, M, M);
        break;
      case 1:
        u = demorect(box, "Layout( UI_VCENTER )", hue, 0, UI_VCENTER, width, T/2, M, M, M, M);
        break;
      case 2:
        u = demorect(box, "Layout( UI_VFILL )", hue, 0, UI_VFILL, width, T, M, M, M, M);
        break;
      case 3:
        u = demorect(box, "Layout( UI_DOWN )", hue, 0, UI_DOWN, width, T/2, M, M, M, M);
        break;
    }

    if (uniform!"[)"(0, 10) == 0) uiSetLayout(u, uiGetLayout(u)|UI_BREAK);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
void fill_wrap_column_box (int box) {
  enum int M = 5;
  enum int S = 100;
  enum int T = 50;

  import std.random;
  rndGen.seed(666);
  for (int i = 0; i < 20; ++i) {
    float hue = cast(float)(uniform!"[)"(0, 360))/360.0f;
    int height = 10 + (uniform!"[)"(0, 5))*10;

    int u;
    switch (uniform!"[)"(0, 4)) {
      default: break;
      case 0:
        u = demorect(box, "Layout( UI_LEFT )", hue, 0, UI_LEFT, T, height, M, M, M, M);
        break;
      case 1:
        u = demorect(box, "Layout( UI_HCENTER )", hue, 0, UI_HCENTER, T/2, height, M, M, M, M);
        break;
      case 2:
        u = demorect(box, "Layout( UI_HFILL )", hue, 0, UI_HFILL, T, height, M, M, M, M);
        break;
      case 3:
        u = demorect(box, "Layout( UI_RIGHT )", hue, 0, UI_RIGHT, T/2, height, M, M, M, M);
        break;
    }

    if (uniform!"[)"(0, 10) == 0) uiSetLayout(u, uiGetLayout(u)|UI_BREAK);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
void build_wrapdemo (int parent) {
  int col = uiItem();
  uiInsert(parent, col);
  uiSetBox(col, UI_COLUMN);
  uiSetLayout(col, UI_FILL);

  enum int M = 5;
  enum int S = 100;
  enum int T = 50;

  int box;
  box = demorect(col, "Box( UI_ROW | UI_WRAP | UI_START )\nLayout( UI_HFILL | UI_TOP )", 0.6f, UI_ROW | UI_WRAP | UI_START, UI_TOP, 0, 0, M, M, M, M);
  fill_wrap_row_box(box);

  box = demorect(col, "Box( UI_ROW | UI_WRAP | UI_MIDDLE )\nLayout( UI_HFILL | UI_TOP )", 0.6f, UI_ROW | UI_WRAP, UI_HFILL | UI_TOP, 0, 0, M, M, M, M);
  fill_wrap_row_box(box);

  box = demorect(col, "Box( UI_ROW | UI_WRAP | UI_END )\nLayout( UI_HFILL | UI_TOP )", 0.6f, UI_ROW | UI_WRAP | UI_END, UI_HFILL | UI_TOP, 0, 0, M, M, M, M);
  fill_wrap_row_box(box);

  box = demorect(col, "Box( UI_ROW | UI_WRAP | UI_JUSTIFY )\nLayout( UI_HFILL | UI_TOP )", 0.6f, UI_ROW | UI_WRAP | UI_JUSTIFY, UI_HFILL | UI_TOP, 0, 0, M, M, M, M);
  fill_wrap_row_box(box);

  box = demorect(col, "Box( UI_COLUMN | UI_WRAP | UI_START )\nLayout( UI_LEFT | UI_VFILL )", 0.6f, UI_COLUMN | UI_WRAP | UI_START, UI_LEFT | UI_VFILL, 0, 0, M, M, M, M);
  fill_wrap_column_box(box);
}


// ////////////////////////////////////////////////////////////////////////// //
int add_menu_option(T : const(char)[]) (int parent, T name, int* choice) {
  int opt = radio(-1, name, choice);
  uiInsert(parent, opt);
  uiSetLayout(opt, UI_HFILL|UI_TOP);
  uiSetMargins(opt, 1, 1, 1, 1);
  return opt;
}


// ////////////////////////////////////////////////////////////////////////// //
void draw (NVGcontext *vg, float w, float h) {
  bndBackground(vg, 0, 0, w, h);

  // some OUI stuff

  uiBeginLayout();

  int root = panel();
  // position root element
  uiSetSize(0, cast(int)w, cast(int)h);
  root.ctlSetPanelHandler(toDelegate(&roothandler));
  uiSetEvents(root, UI_SCROLL|UI_BUTTON0_DOWN);
  uiSetBox(root, UI_COLUMN);

  __gshared int choice = -1;

  int menu = uiItem();
  uiSetLayout(menu, UI_HFILL|UI_TOP);
  uiSetBox(menu, UI_ROW);
  uiInsert(root, menu);

  int opt_blendish_demo = add_menu_option(menu, "Blendish Demo", &choice);
  int opt_oui_demo = add_menu_option(menu, "OUI Demo", &choice);
  int opt_layouts = add_menu_option(menu, "UI_LAYOUT", &choice);
  int opt_row = add_menu_option(menu, "UI_ROW", &choice);
  int opt_column = add_menu_option(menu, "UI_COLUMN", &choice);
  int opt_wrap = add_menu_option(menu, "UI_WRAP", &choice);
  if (choice < 0) choice = opt_blendish_demo;

  int content = uiItem();
  uiSetLayout(content, UI_FILL);
  uiInsert(root, content);

  if (choice == opt_blendish_demo) {
    int democontent = userCtl(
      (NVGcontext* vg, int item) {
        UIrect rect = uiGetRect(item);
        draw_demostuff(vg, rect.x, rect.y, rect.w, rect.h);
      },
      (int item, UIevent event) {
      },
    );
    uiSetLayout(democontent, UI_FILL);
    uiInsert(content, democontent);
    /*
    int democontent = uiItem();
    uiSetLayout(democontent, UI_FILL);
    uiInsert(content, democontent);
    UIData *data = uiAllocHandle!UIData(democontent);
    data.handler = null;
    data.subtype = ST_DEMOSTUFF;
    */
  } else if (choice == opt_oui_demo) {
    int democontent = uiItem();
    uiSetLayout(democontent, UI_TOP);
    uiSetSize(democontent, 250, 0);
    uiInsert(content, democontent);
    build_democontent(democontent);
  } else if (choice == opt_layouts) {
    build_layoutdemo(content);
  } else if (choice == opt_row) {
    build_rowdemo(content);
  } else if (choice == opt_column) {
    build_columndemo(content);
  } else if (choice == opt_wrap) {
    build_wrapdemo(content);
  }

  uiEndLayout();

  drawUI(vg, 0, BND_CORNER_NONE);

  version(none) {
    for (int i = 0; i < uiGetLastItemCount(); ++i) {
      if (uiRecoverItem(i) == -1) {
        UIitem *pitem = uiLastItemPtr(i);
        nvgBeginPath(vg);
        nvgRect(vg, pitem.margins[0], pitem.margins[1], pitem.size[0], pitem.size[1]);
        nvgStrokeWidth(vg, 2);
        nvgStrokeColor(vg, nvgRGBAf(1.0f, 0.0f, 0.0f, 0.5f));
        nvgStroke(vg);
      }
    }
  }

  if (choice == opt_blendish_demo) {
    import std.math : abs;
    UIvec2 cursor = uiGetCursor();
    cursor.x -= cast(int)(w/2);
    cursor.y -= cast(int)(h/2);
    if (abs(cursor.x) > (w/3)) {
      bndJoinAreaOverlay(vg, 0, 0, w, h, 0, (cursor.x > 0));
    } else if (abs(cursor.y) > (h/3)) {
      bndJoinAreaOverlay(vg, 0, 0, w, h, 1, (cursor.y > 0));
    }
  }

  __gshared int prevTime = 0;
  int curTime = cast(int)(getSeconds()*1000.0);
  uiProcess(curTime-prevTime);
  prevTime = curTime;
}


////////////////////////////////////////////////////////////////////////////////
void main () {
  PerfGraph fps;
  int owdt = -1, ohgt = -1;

  double mx = 0, my = 0;
  bool doQuit = false;

  //setOpenGLContextVersion(3, 2); // up to GLSL 150
  setOpenGLContextVersion(2, 0); // it's enough
  //openGLContextCompatible = false;

  UIcontextP uictx = uiCreateContext(4096, 1<<20);
  uiMakeCurrent(uictx);
  uiSetHandler(toDelegate(&ui_handler));

  auto sdwindow = new SimpleWindow(GWidth, GHeight, "OUI", OpenGlOptions.yes, Resizablity.fixedSize);
  //sdwindow.hideCursor();

  void clearWindowData () {
    if (uictx !is null) uiDestroyContext(uictx);
    uictx = null;
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
  float dt = 0, secs = 0;

  //int peak_items = 0;
  //uint peak_alloc = 0;

  sdwindow.redrawOpenGlScene = delegate () {
    if (owdt != sdwindow.width || ohgt != sdwindow.height) {
      owdt = sdwindow.width;
      ohgt = sdwindow.height;
      glViewport(0, 0, owdt, ohgt);
    }

    // timers
    prevt = curt;
    curt = MonoTime.currTime;
    secs = cast(double)((curt-stt).total!"msecs")/1000.0;
    dt = cast(double)((curt-prevt).total!"msecs")/1000.0;

    // Update and render
    glClearColor(0, 0, 0, 1);
    glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT|GL_STENCIL_BUFFER_BIT);

    if (nvg !is null) {
      updateGraph(&fps, dt);
      nvgBeginFrame(nvg, owdt, ohgt);
      draw(nvg, owdt, ohgt);
      //peak_items = (peak_items > uiGetItemCount() ? peak_items : uiGetItemCount());
      //peak_alloc = (peak_alloc > uiGetAllocSize() ? peak_alloc : uiGetAllocSize());
      renderGraph(nvg, owdt-200-5, ohgt-35-5, &fps);
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

    version(DEMO_MSAA) {
      nvg = nvgCreateGL2(NVG_STENCIL_STROKES | NVG_DEBUG);
    } else {
      nvg = nvgCreateGL2(NVG_ANTIALIAS | NVG_STENCIL_STROKES | NVG_DEBUG);
    }
    if (nvg is null) {
      import std.stdio;
      writeln("Could not init nanovg.");
      //sdwindow.close();
    }
    init(nvg);
    initGraph(&fps, GRAPH_RENDER_FPS, "Frame Time", "system");
    sdwindow.redrawOpenGlScene();
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
      uiSetKey(cast(uint)event.key, 0/*mods*/, event.pressed);
    },
    delegate (MouseEvent event) {
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
    },
    delegate (dchar ch) {
      //if (ch == 'q') { doQuit = true; return; }
      uiSetChar(cast(uint)ch);
    },
  );
  closeWindow();
  uiDestroyContext(uictx);
}
