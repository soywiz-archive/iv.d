//
// based on NanoVG's example code by Mikko Mononen
import core.time;
import core.stdc.stdio : snprintf;
import iv.nanovg;
import iv.nanovg.oui;
import iv.nanovg.perf;

import arsd.simpledisplay;
import arsd.color;
import arsd.png;
import arsd.jpeg;

import std.functional : toDelegate;

// sdpy is missing that yet
static if (!is(typeof(GL_STENCIL_BUFFER_BIT))) enum uint GL_STENCIL_BUFFER_BIT = 0x00000400;

string toStr(T : const(char)[]) (T buf) {
  static if (is(T == string)) return buf; else return buf.idup;
}

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


////////////////////////////////////////////////////////////////////////////////
alias SubType = int;
enum {
  // label
  ST_LABEL = 0,
  // button
  ST_BUTTON = 1,
  // radio button
  ST_RADIO = 2,
  // progress slider
  ST_SLIDER = 3,
  // column
  ST_COLUMN = 4,
  // row
  ST_ROW = 5,
  // check button
  ST_CHECK = 6,
  // panel
  ST_PANEL = 7,
  // text
  ST_TEXT = 8,
  //
  ST_IGNORE = 9,

  ST_DEMOSTUFF = 10,
  // colored rectangle
  ST_RECT = 11,

  ST_HBOX = 12,
  ST_VBOX = 13,
}

struct UIData {
  int subtype;
  UIhandler handler;
}

struct UIRectData {
  UIData head;
  string label;
  NVGColor color;
}

struct UIButtonData {
  UIData head;
  int iconid;
  string label;
}

struct UICheckData {
  UIData head;
  string label;
  int* option;
}

struct UIRadioData {
  UIData head;
  int iconid;
  string label;
  int* value;
}

struct UISliderData {
  UIData head;
  string label;
  float* progress;
}

struct TextData {
  char[] text;
}

struct UITextData {
  UIData head;
  TextData* text;
  int maxsize;
}

// ////////////////////////////////////////////////////////////////////////// //
__gshared NVGContext _vg = null;

void ui_handler (int item, UIevent event) {
  auto data = uiGetHandle!UIData(item);
  if (data !is null && data.handler !is null) data.handler(item, event);
}

void init (NVGContext vg) {
  version(nanovg_demo_msfonts) {
    bndSetFont(vg.createFont("system", "/home/ketmar/ttf/ms/tahoma.ttf:noaa"));
  } else {
    bndSetFont(vg.createFont("system", "data/Roboto-Regular.ttf"));
  }
  bndSetIconImage(vg.createImage("data/images/blender_icons16.png", 0));
}

void testrect (NVGContext vg, UIrect rect) {
  version(none) {
    vg.beginPath();
    vg.rect(rect.x+0.5, rect.y+0.5, rect.w-1, rect.h-1);
    vg.strokeColor(nvgRGBf(1, 0, 0));
    vg.strokeWidth(1);
    vg.stroke();
  }
}


void drawUIItems (NVGContext vg, int item, int corners) {
  int kid = uiFirstChild(item);
  while (kid > 0) {
    drawUI(vg, kid, corners);
    kid = uiNextSibling(kid);
  }
}

void drawUIItemsHbox (NVGContext vg, int item) {
  int kid = uiFirstChild(item);
  if (kid < 0) return;
  int nextkid = uiNextSibling(kid);
  if (nextkid < 0) {
    drawUI(vg, kid, BND_CORNER_NONE);
  } else {
    drawUI(vg, kid, BND_CORNER_RIGHT);
    kid = nextkid;
    while (uiNextSibling(kid) > 0) {
      drawUI(vg, kid, BND_CORNER_ALL);
      kid = uiNextSibling(kid);
    }
    drawUI(vg, kid, BND_CORNER_LEFT);
  }
}

void drawUIItemsVbox (NVGContext vg, int item) {
  int kid = uiFirstChild(item);
  if (kid < 0) return;
  int nextkid = uiNextSibling(kid);
  if (nextkid < 0) {
    drawUI(vg, kid, BND_CORNER_NONE);
  } else {
    drawUI(vg, kid, BND_CORNER_DOWN);
    kid = nextkid;
    while (uiNextSibling(kid) > 0) {
      drawUI(vg, kid, BND_CORNER_ALL);
      kid = uiNextSibling(kid);
    }
    drawUI(vg, kid, BND_CORNER_TOP);
  }
}

void drawUI (NVGContext vg, int item, int corners) {
  auto head = uiGetHandle!(const UIData)(item);
  UIrect rect = uiGetRect(item);
  if (uiGetState(item) == UI_FROZEN) vg.globalAlpha(BND_DISABLED_ALPHA);
  if (head) {
    switch (head.subtype) {
      default:
        testrect(vg, rect);
        drawUIItems(vg, item, corners);
        break;
      case ST_HBOX:
        drawUIItemsHbox(vg, item);
        break;
      case ST_VBOX:
        drawUIItemsVbox(vg, item);
        break;
      case ST_PANEL:
        bndBevel(vg, rect.x, rect.y, rect.w, rect.h);
        drawUIItems(vg, item, corners);
        break;
      case ST_LABEL:
        assert(head);
        auto data = cast(const(UIButtonData)*)head;
        bndLabel(vg, rect.x, rect.y, rect.w, rect.h, data.iconid, data.label);
        break;
      case ST_BUTTON:
        auto data = cast(const(UIButtonData)*)head;
        bndToolButton(vg, rect.x, rect.y, rect.w, rect.h, corners, cast(BNDwidgetState)uiGetState(item), data.iconid, data.label);
        break;
      case ST_CHECK:
        auto data = cast(const(UICheckData)*)head;
        BNDwidgetState state = cast(BNDwidgetState)uiGetState(item);
        if (*data.option) state = BND_ACTIVE;
        bndOptionButton(vg, rect.x, rect.y, rect.w, rect.h, state, data.label);
        break;
      case ST_RADIO:
        auto data = cast(const(UIRadioData)*)head;
        BNDwidgetState state = cast(BNDwidgetState)uiGetState(item);
        if (*data.value == item) state = BND_ACTIVE;
        bndRadioButton(vg, rect.x, rect.y, rect.w, rect.h, corners, state, data.iconid, data.label);
        break;
      case ST_SLIDER:
        auto data = cast(const(UISliderData)*)head;
        BNDwidgetState state = cast(BNDwidgetState)uiGetState(item);
        //static char[32] value;
        //sprintf(value.ptr, "%.0f%%", (*data.progress)*100.0f);
        import std.string : format;
        bndSlider(vg, rect.x, rect.y, rect.w, rect.h, corners, state, *data.progress, data.label, "%.0f%%".format((*data.progress)*100.0f));
        break;
      case ST_TEXT:
        auto data = cast(const(UITextData)*)head;
        BNDwidgetState state = cast(BNDwidgetState)uiGetState(item);
        int idx = cast(int)data.text.text.length;
        bndTextField(vg, rect.x, rect.y, rect.w, rect.h, corners, state, -1, data.text.text, idx, idx);
        break;
      case ST_DEMOSTUFF:
        draw_demostuff(vg, rect.x, rect.y, rect.w, rect.h);
        break;
      case ST_RECT:
        auto data = cast(const(UIRectData)*)head;
        if (rect.w && rect.h) {
          BNDwidgetState state = cast(BNDwidgetState)uiGetState(item);
          vg.save();
          scope(exit) vg.restore();
          vg.strokeColor(nvgRGBAf(data.color.r, data.color.g, data.color.b, 0.9f));
          if (state != BND_DEFAULT) {
            vg.fillColor(nvgRGBAf(data.color.r, data.color.g, data.color.b, 0.5f));
          } else {
            vg.fillColor(nvgRGBAf(data.color.r, data.color.g, data.color.b, 0.1f));
          }
          vg.strokeWidth(2);
          vg.beginPath();
          version(none) {
            vg.rect(rect.x, rect.y, rect.w, rect.h);
          } else {
            vg.roundedRect(rect.x, rect.y, rect.w, rect.h, 3);
          }
          vg.fill();
          vg.stroke();

          if (state != BND_DEFAULT) {
            vg.fillColor(nvgRGBAf(0.0f, 0.0f, 0.0f, 1.0f));
            vg.fontSize(15.0f);
            vg.beginPath();
            vg.textAlign(NVGAlign.Top|NVGAlign.Center);
            vg.textBox(rect.x, rect.y+rect.h*0.3f, rect.w, data.label);
          }
        }

        vg.save();
        scope(exit) vg.restore();
        vg.intersectScissor(rect.x, rect.y, rect.w, rect.h);

        drawUIItems(vg, item, corners);
        break;
    }
  } else {
    testrect(vg, rect);
    drawUIItems(vg, item, corners);
  }

  if (uiGetState(item) == UI_FROZEN) {
    vg.globalAlpha(1.0);
  }
}


int colorrect(T : const(char)[]) (T label, NVGColor color) {
  int item = uiItem();
  UIRectData *data = uiAllocHandle!UIRectData(item);
  data.head.subtype = ST_RECT;
  data.head.handler = null;
  data.label = label.toStr;
  data.color = color;
  uiSetEvents(item, UI_BUTTON0_DOWN);
  return item;
}

int label(T : const(char)[]) (int iconid, T label) {
  int item = uiItem();
  uiSetSize(item, 0, BND_WIDGET_HEIGHT);
  UIButtonData *data = uiAllocHandle!UIButtonData(item);
  data.head.subtype = ST_LABEL;
  data.head.handler = null;
  data.iconid = iconid;
  data.label = label.toStr;
  return item;
}

void demohandler (int item, UIevent event) {
  import std.stdio;
  auto data = uiGetHandle!(const UIButtonData)(item);
  writefln("clicked: %s %s", uiGetHandle(item), data.label);
}

int button(T : const(char)[]) (int iconid, T label, UIhandler handler) {
  // create new ui item
  int item = uiItem();
  // set size of wiget; horizontal size is dynamic, vertical is fixed
  uiSetSize(item, 0, BND_WIDGET_HEIGHT);
  uiSetEvents(item, UI_BUTTON0_HOT_UP);
  // store some custom data with the button that we use for styling
  UIButtonData *data = uiAllocHandle!UIButtonData(item);
  data.head.subtype = ST_BUTTON;
  data.head.handler = handler;
  data.iconid = iconid;
  data.label = label.toStr;
  return item;
}

void checkhandler (int item, UIevent event) {
  auto data = uiGetHandle!UICheckData(item);
  *data.option = !(*data.option);
}

int check(T : const(char)[]) (T label, int* option) {
  // create new ui item
  int item = uiItem();
  // set size of wiget; horizontal size is dynamic, vertical is fixed
  uiSetSize(item, 0, BND_WIDGET_HEIGHT);
  // attach event handler e.g. demohandler above
  uiSetEvents(item, UI_BUTTON0_DOWN);
  // store some custom data with the button that we use for styling
  UICheckData *data = uiAllocHandle!UICheckData(item);
  data.head.subtype = ST_CHECK;
  data.head.handler = toDelegate(&checkhandler);
  data.label = label.toStr;
  data.option = option;
  return item;
}

// simple logic for a slider

// starting offset of the currently active slider
__gshared float sliderstart = 0.0;

// event handler for slider (same handler for all sliders)
void sliderhandler (int item, UIevent event) {
  // retrieve the custom data we saved with the slider
  UISliderData *data = uiGetHandle!UISliderData(item);
  switch (event) {
    default: break;
    case UI_BUTTON0_DOWN:
      // button was pressed for the first time; capture initial slider value.
      sliderstart = *data.progress;
      break;
    case UI_BUTTON0_CAPTURE:
      // called for every frame that the button is pressed.
      // get the delta between the click point and the current mouse position
      UIvec2 pos = uiGetCursorStartDelta();
      // get the items layouted rectangle
      UIrect rc = uiGetRect(item);
      // calculate our new offset and clamp
      float value = sliderstart+(cast(float)pos.x/cast(float)rc.w);
      value = (value < 0 ? 0 : (value > 1 ? 1 : value));
      // assign the new value
      *data.progress = value;
      break;
  }
}

int slider(T : const(char)[]) (T label, float* progress) {
  // create new ui item
  int item = uiItem();
  // set size of wiget; horizontal size is dynamic, vertical is fixed
  uiSetSize(item, 0, BND_WIDGET_HEIGHT);
  // attach our slider event handler and capture two classes of events
  uiSetEvents(item, UI_BUTTON0_DOWN|UI_BUTTON0_CAPTURE);
  // store some custom data with the button that we use for styling
  // and logic, e.g. the pointer to the data we want to alter.
  UISliderData *data = uiAllocHandle!UISliderData(item);
  data.head.subtype = ST_SLIDER;
  data.head.handler = toDelegate(&sliderhandler);
  data.label = label.toStr;
  data.progress = progress;
  return item;
}

void textboxhandler (int item, UIevent event) {
  UITextData *data = uiGetHandle!UITextData(item);
  switch (event) {
    default: break;
    case UI_BUTTON0_DOWN:
      uiFocus(item);
      break;
    case UI_KEY_DOWN:
      uint key = uiGetKey();
      switch (key) {
        default: break;
        case Key.Backspace:
          if (data.text.text.length == 0) return;
          data.text.text.length -= 1;
          break;
        case Key.Enter:
          uiFocus(-1);
          break;
      }
      break;
    case UI_CHAR:
      uint key = uiGetKey();
      if (key > 255 || key < 32) return;
      if (data.text.text.length < data.maxsize) data.text.text ~= cast(char)key;
      break;
  }
}

int textbox (TextData* text, int maxsize) {
  int item = uiItem();
  uiSetSize(item, 0, BND_WIDGET_HEIGHT);
  uiSetEvents(item, UI_BUTTON0_DOWN|UI_KEY_DOWN|UI_CHAR);
  // store some custom data with the button that we use for styling
  // and logic, e.g. the pointer to the data we want to alter.
  UITextData *data = uiAllocHandle!UITextData(item);
  data.head.subtype = ST_TEXT;
  data.head.handler = toDelegate(&textboxhandler);
  data.text = text;
  data.maxsize = maxsize;
  return item;
}

// simple logic for a radio button
void radiohandler (int item, UIevent event) {
  UIRadioData *data = uiGetHandle!UIRadioData(item);
  *data.value = item;
}

int radio(T : const(char)[]) (int iconid, T label, int *value) {
  int item = uiItem();
  uiSetSize(item, (label.length ? 0 : BND_TOOL_WIDTH), BND_WIDGET_HEIGHT);
  UIRadioData *data = uiAllocHandle!UIRadioData(item);
  data.head.subtype = ST_RADIO;
  data.head.handler = toDelegate(&radiohandler);
  data.iconid = iconid;
  data.label = label;
  data.value = value;
  uiSetEvents(item, UI_BUTTON0_DOWN);
  return item;
}

int panel () {
  int item = uiItem();
  UIData *data = uiAllocHandle!UIData(item);
  data.subtype = ST_PANEL;
  data.handler = null;
  return item;
}

int hbox () {
  int item = uiItem();
  UIData *data = uiAllocHandle!UIData(item);
  data.subtype = ST_HBOX;
  data.handler = null;
  uiSetBox(item, UI_ROW);
  return item;
}


int vbox () {
  int item = uiItem();
  UIData *data = uiAllocHandle!UIData(item);
  data.subtype = ST_VBOX;
  data.handler = null;
  uiSetBox(item, UI_COLUMN);
  return item;
}


int column_append (int parent, int item) {
  uiInsert(parent, item);
  // fill parent horizontally, anchor to previous item vertically
  uiSetLayout(item, UI_HFILL);
  uiSetMargins(item, 0, 1, 0, 0);
  return item;
}

int column () {
  int item = uiItem();
  uiSetBox(item, UI_COLUMN);
  return item;
}

int vgroup_append (int parent, int item) {
  uiInsert(parent, item);
  // fill parent horizontally, anchor to previous item vertically
  uiSetLayout(item, UI_HFILL);
  return item;
}

int vgroup () {
  int item = uiItem();
  uiSetBox(item, UI_COLUMN);
  return item;
}

int hgroup_append (int parent, int item) {
  uiInsert(parent, item);
  uiSetLayout(item, UI_HFILL);
  return item;
}

int hgroup_append_fixed (int parent, int item) {
  uiInsert(parent, item);
  return item;
}

int hgroup () {
  int item = uiItem();
  uiSetBox(item, UI_ROW);
  return item;
}

int row_append (int parent, int item) {
  uiInsert(parent, item);
  uiSetLayout(item, UI_HFILL);
  return item;
}

int row () {
  int item = uiItem();
  uiSetBox(item, UI_ROW);
  return item;
}

void draw_noodles (NVGContext vg, int x, int y) {
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

static void roothandler (int parent, UIevent event) {
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

void draw_demostuff (NVGContext vg, int x, int y, float w, float h) {
  import core.stdc.math : fmodf, cosf, sinf;

  vg.save();
  scope(exit) vg.restore();

  vg.translate(x, y);

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
  int idx2 = idx1+(t%(textlen-idx1));

  ry += 25;
  bndTextField(vg, rx, ry, 240, BND_WIDGET_HEIGHT, BND_CORNER_NONE, BND_DEFAULT, -1, edit_text, idx1, idx2);
  ry += 25;
  bndTextField(vg, rx, ry, 240, BND_WIDGET_HEIGHT, BND_CORNER_NONE, BND_HOVER, -1, edit_text, idx1, idx2);
  ry += 25;
  bndTextField(vg, rx, ry, 240, BND_WIDGET_HEIGHT, BND_CORNER_NONE, BND_ACTIVE, -1, edit_text, idx1, idx2);

  draw_noodles(vg, 20, ry+50);

  rx += rw+20;
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

__gshared int enum1 = -1;

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

  __gshared TextData text;
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

int demorect(T : const(char)[]) (int parent, T label, float hue, int box, int layout, int w, int h, int m1, int m2, int m3, int m4) {
  int item = colorrect(label, nvgHSL(hue, 1.0f, 0.8f));
  uiSetLayout(item, layout);
  uiSetBox(item, box);
  uiSetMargins(item, cast(short)m1, cast(short)m2, cast(short)m3, cast(short)m4);
  uiSetSize(item, w, h);
  uiInsert(parent, item);
  return item;
}

void build_layoutdemo (int parent) {
  enum int M = 10;
  enum int S = 150;

  int box = demorect(parent, "Box(UI_LAYOUT)\nLayout(UI_FILL)", 0.6f, UI_LAYOUT, UI_FILL, 0, 0, M, M, M, M);
  demorect(box, "Layout(UI_HFILL|UI_TOP)", 0.7f, 0, UI_HFILL|UI_TOP, S, S+M, M, M, M, 0);
  demorect(box, "Layout(UI_HFILL)", 0.7f, 0, UI_HFILL, S, S+2*M, M, 0, M, 0);
  demorect(box, "Layout(UI_HFILL|UI_DOWN)", 0.7f, 0, UI_HFILL|UI_DOWN, S, S+M, M, 0, M, M);

  demorect(box, "Layout(UI_LEFT|UI_VFILL)", 0.7f, 0, UI_LEFT|UI_VFILL, S+M, S, M, M, 0, M);
  demorect(box, "Layout(UI_VFILL)", 0.7f, 0, UI_VFILL, S+2*M, S, 0, M, 0, M);
  demorect(box, "Layout(UI_RIGHT|UI_VFILL)", 0.7f, 0, UI_RIGHT|UI_VFILL, S+M, S, 0, M, M, M);

  demorect(box, "Layout(UI_LEFT|UI_TOP)", 0.55f, 0, UI_LEFT|UI_TOP, S, S, M, M, 0, 0);
  demorect(box, "Layout(UI_TOP)", 0.57f, 0, UI_TOP, S, S, 0, M, 0, 0);
  demorect(box, "Layout(UI_RIGHT|UI_TOP)", 0.55f, 0, UI_RIGHT|UI_TOP, S, S, 0, M, M, 0);
  demorect(box, "Layout(UI_LEFT)", 0.57f, 0, UI_LEFT, S, S, M, 0, 0, 0);
  demorect(box, "Layout(UI_CENTER)", 0.59f, 0, UI_CENTER, S, S, 0, 0, 0, 0);
  demorect(box, "Layout(UI_RIGHT)", 0.57f, 0, UI_RIGHT, S, S, 0, 0, M, 0);
  demorect(box, "Layout(UI_LEFT|UI_DOWN)", 0.55f, 0, UI_LEFT|UI_DOWN, S, S, M, 0, 0, M);
  demorect(box, "Layout( UI_DOWN)", 0.57f, 0, UI_DOWN, S, S, 0, 0, 0, M);
  demorect(box, "Layout(UI_RIGHT|UI_DOWN)", 0.55f, 0, UI_RIGHT|UI_DOWN, S, S, 0, 0, M, M);
}

void build_rowdemo (int parent) {
  uiSetBox(parent, UI_COLUMN);

  enum int M = 10;
  enum int S = 200;
  enum int T = 100;

  {
    int box = demorect(parent, "Box(UI_ROW)\nLayout(UI_LEFT|UI_VFILL)", 0.6f, UI_ROW, UI_LEFT|UI_VFILL, 0, S, M, M, M, M);
    demorect(box, "Layout(UI_TOP)", 0.05f, 0, UI_TOP, T, T, M, M, M, 0);
    demorect(box, "Layout(UI_VCENTER)", 0.1f, 0, UI_VCENTER, T, T, 0, 0, M, 0);
    demorect(box, "Layout(UI_VFILL)", 0.15f, 0, UI_VFILL, T, T, 0, M, M, M);
    demorect(box, "Layout(UI_DOWN)", 0.25f, 0, UI_DOWN, T, T, 0, 0, M, M);
  }
  {
    int box = demorect(parent, "Box(UI_ROW|UI_JUSTIFY)\nLayout(UI_FILL)", 0.6f, UI_ROW|UI_JUSTIFY, UI_FILL, 0, S, M, 0, M, M);
    demorect(box, "Layout(UI_TOP)", 0.05f, 0, UI_TOP, T, T, M, M, M, 0);
    demorect(box, "Layout(UI_VCENTER)", 0.1f, 0, UI_VCENTER, T, T, 0, 0, M, 0);
    demorect(box, "Layout(UI_VFILL)", 0.15f, 0, UI_VFILL, T, T, 0, M, M, M);
    demorect(box, "Layout(UI_DOWN)", 0.25f, 0, UI_DOWN, T, T, 0, 0, M, M);
  }
  {
    int box = demorect(parent, "Box(UI_ROW)\nLayout(UI_FILL)", 0.6f, UI_ROW, UI_FILL, 0, S, M, 0, M, M);
    demorect(box, "Layout(UI_TOP)", 0.05f, 0, UI_TOP, T, T, M, M, M, 0);
    demorect(box, "Layout(UI_VCENTER)", 0.1f, 0, UI_VCENTER, T, T, 0, 0, M, 0);
    demorect(box, "Layout(UI_VFILL)", 0.15f, 0, UI_VFILL, T, T, 0, M, M, M);
    demorect(box, "Layout(UI_HFILL)", 0.2f, 0, UI_HFILL, T, T, 0, 0, M, 0);
    demorect(box, "Layout(UI_HFILL)", 0.2f, 0, UI_HFILL, T, T, 0, 0, M, 0);
    demorect(box, "Layout(UI_HFILL)", 0.2f, 0, UI_HFILL, T, T, 0, 0, M, 0);
    demorect(box, "Layout(UI_DOWN)", 0.25f, 0, UI_DOWN, T, T, 0, 0, M, M);
  }
}

void build_columndemo (int parent) {
  uiSetBox(parent, UI_ROW);

  enum int M = 10;
  enum int S = 200;
  enum int T = 100;

  {
    int box = demorect(parent, "Box(UI_COLUMN)\nLayout(UI_TOP|UI_HFILL)", 0.6f, UI_COLUMN, UI_TOP|UI_HFILL, S, 0, M, M, M, M);
    demorect(box, "Layout(UI_LEFT)", 0.05f, 0, UI_LEFT, T, T, M, M, 0, M);
    demorect(box, "Layout(UI_HCENTER)", 0.1f, 0, UI_HCENTER, T, T, 0, 0, 0, M);
    demorect(box, "Layout(UI_HFILL)", 0.15f, 0, UI_HFILL, T, T, M, 0, M, M);
    demorect(box, "Layout(UI_RIGHT)", 0.25f, 0, UI_RIGHT, T, T, 0, 0, M, M);
  }
  {
    int box = demorect(parent, "Box(UI_COLUMN)\nLayout(UI_FILL)", 0.6f, UI_COLUMN, UI_FILL, S, 0, 0, M, M, M);
    demorect(box, "Layout(UI_LEFT)", 0.05f, 0, UI_LEFT, T, T, M, M, 0, M);
    demorect(box, "Layout(UI_HCENTER)", 0.1f, 0, UI_HCENTER, T, T, 0, 0, 0, M);
    demorect(box, "Layout(UI_HFILL)", 0.15f, 0, UI_HFILL, T, T, M, 0, M, M);
    demorect(box, "Layout(UI_RIGHT)", 0.25f, 0, UI_RIGHT, T, T, 0, 0, M, M);
  }
  {
    int box = demorect(parent, "Box(UI_COLUMN)\nLayout(UI_FILL)", 0.6f, UI_COLUMN, UI_FILL, S, 0, 0, M, M, M);
    demorect(box, "Layout(UI_LEFT)", 0.05f, 0, UI_LEFT, T, T, M, M, 0, M);
    demorect(box, "Layout(UI_HCENTER)", 0.1f, 0, UI_HCENTER, T, T, 0, 0, 0, M);
    demorect(box, "Layout(UI_HFILL)", 0.15f, 0, UI_HFILL, T, T, M, 0, M, M);
    demorect(box, "Layout(UI_VFILL)", 0.2f, 0, UI_VFILL, T, T, 0, 0, 0, M);
    demorect(box, "Layout(UI_VFILL)", 0.2f, 0, UI_VFILL, T, T, 0, 0, 0, M);
    demorect(box, "Layout(UI_VFILL)", 0.2f, 0, UI_VFILL, T, T, 0, 0, 0, M);
    demorect(box, "Layout(UI_RIGHT)", 0.25f, 0, UI_RIGHT, T, T, 0, 0, M, M);
  }
}

void fill_wrap_row_box (int box) {
  enum int M = 5;
  enum int S = 100;
  enum int T = 50;

  //srand(303);
  import std.random;
  rndGen.seed(303);
  for (int i = 0; i < 20; ++i) {
    float hue = cast(float)(uniform!"[)"(0, 360))/360.0f;
    int width = 10+(uniform!"[)"(0, 5))*10;

    int u;
    switch (uniform!"[)"(0, 4)) {
      default: break;
      case 0:
        u = demorect(box, "Layout(UI_TOP)", hue, 0, UI_TOP, width, T, M, M, M, M);
        break;
      case 1:
        u = demorect(box, "Layout(UI_VCENTER)", hue, 0, UI_VCENTER, width, T/2, M, M, M, M);
        break;
      case 2:
        u = demorect(box, "Layout(UI_VFILL)", hue, 0, UI_VFILL, width, T, M, M, M, M);
        break;
      case 3:
        u = demorect(box, "Layout(UI_DOWN)", hue, 0, UI_DOWN, width, T/2, M, M, M, M);
        break;
    }

    if (uniform!"[)"(0, 10) == 0) uiSetLayout(u, uiGetLayout(u)|UI_BREAK);
  }
}

void fill_wrap_column_box (int box) {
  enum int M = 5;
  enum int S = 100;
  enum int T = 50;

  import std.random;
  rndGen.seed(303);
  for (int i = 0; i < 20; ++i) {
    float hue = cast(float)(uniform!"[)"(0, 360))/360.0f;
    int height = 10+(uniform!"[)"(0, 5))*10;

    int u;
    switch (uniform!"[)"(0, 4)) {
      default: break;
      case 0:
        u = demorect(box, "Layout(UI_LEFT)", hue, 0, UI_LEFT, T, height, M, M, M, M);
        break;
      case 1:
        u = demorect(box, "Layout(UI_HCENTER)", hue, 0, UI_HCENTER, T/2, height, M, M, M, M);
        break;
      case 2:
        u = demorect(box, "Layout(UI_HFILL)", hue, 0, UI_HFILL, T, height, M, M, M, M);
        break;
      case 3:
        u = demorect(box, "Layout(UI_RIGHT)", hue, 0, UI_RIGHT, T/2, height, M, M, M, M);
        break;
    }

    if (uniform!"[)"(0, 10) == 0) uiSetLayout(u, uiGetLayout(u)|UI_BREAK);
  }
}

void build_wrapdemo (int parent) {
  int col = uiItem();
  uiInsert(parent, col);
  uiSetBox(col, UI_COLUMN);
  uiSetLayout(col, UI_FILL);

  enum int M = 5;
  enum int S = 100;
  enum int T = 50;

  int box;
  box = demorect(col, "Box(UI_ROW|UI_WRAP|UI_START)\nLayout(UI_HFILL|UI_TOP)", 0.6f, UI_ROW|UI_WRAP|UI_START, UI_TOP, 0, 0, M, M, M, M);
  fill_wrap_row_box(box);

  box = demorect(col, "Box(UI_ROW|UI_WRAP|UI_MIDDLE)\nLayout(UI_HFILL|UI_TOP)", 0.6f, UI_ROW|UI_WRAP, UI_HFILL|UI_TOP, 0, 0, M, M, M, M);
  fill_wrap_row_box(box);

  box = demorect(col, "Box(UI_ROW|UI_WRAP|UI_END)\nLayout(UI_HFILL|UI_TOP)", 0.6f, UI_ROW|UI_WRAP|UI_END, UI_HFILL|UI_TOP, 0, 0, M, M, M, M);
  fill_wrap_row_box(box);

  box = demorect(col, "Box(UI_ROW|UI_WRAP|UI_JUSTIFY)\nLayout(UI_HFILL|UI_TOP)", 0.6f, UI_ROW|UI_WRAP|UI_JUSTIFY, UI_HFILL|UI_TOP, 0, 0, M, M, M, M);
  fill_wrap_row_box(box);

  box = demorect(col, "Box(UI_COLUMN|UI_WRAP|UI_START)\nLayout(UI_LEFT|UI_VFILL)", 0.6f, UI_COLUMN|UI_WRAP|UI_START, UI_LEFT|UI_VFILL, 0, 0, M, M, M, M);
  fill_wrap_column_box(box);
}


int add_menu_option(T : const(char)[]) (int parent, T name, int* choice) {
  int opt = radio(-1, name, choice);
  uiInsert(parent, opt);
  uiSetLayout(opt, UI_HFILL|UI_TOP);
  uiSetMargins(opt, 1, 1, 1, 1);
  return opt;
}

void draw (NVGContext vg, float w, float h) {
  bndBackground(vg, 0, 0, w, h);

  // some OUI stuff

  uiBeginLayout();

  int root = panel();
  // position root element
  uiSetSize(0, cast(int)w, cast(int)h);
  (uiGetHandle!UIData(root)).handler = toDelegate(&roothandler);
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
    int democontent = uiItem();
    uiSetLayout(democontent, UI_FILL);
    uiInsert(content, democontent);
    UIData *data = uiAllocHandle!UIData(democontent);
    data.handler = null;
    data.subtype = ST_DEMOSTUFF;
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
        vg.beginPath();
        vg.rect(pitem.margins[0], pitem.margins[1], pitem.size[0], pitem.size[1]);
        vg.strokeWidth(2);
        vg.strokeColor(nvgRGBAf(1.0f, 0.0f, 0.0f, 0.5f));
        vg.stroke();
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

  uiProcess(cast(int)(getSeconds()*1000.0));
}


////////////////////////////////////////////////////////////////////////////////
void main () {
  PerfGraph fps;

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

  sdwindow.closeQuery = delegate () { doQuit = true; };

  void closeWindow () {
    if (!sdwindow.closed && _vg !is null) {
      if (uictx !is null) uiDestroyContext(uictx);
      uictx = null;
      _vg.deleteGL2();
      _vg = null;
      sdwindow.close();
    }
  }

  auto stt = MonoTime.currTime;
  auto prevt = MonoTime.currTime;
  auto curt = prevt;
  float dt = 0, secs = 0;

  int peak_items = 0;
  uint peak_alloc = 0;

  sdwindow.redrawOpenGlScene = delegate () {
    // timers
    prevt = curt;
    curt = MonoTime.currTime;
    secs = cast(double)((curt-stt).total!"msecs")/1000.0;
    dt = cast(double)((curt-prevt).total!"msecs")/1000.0;

    // Update and render
    //glViewport(0, 0, fbWidth, fbHeight);
    glClearColor(0, 0, 0, 1);
    glClear(glNVGClearFlags);

    if (_vg !is null) {
      if (fps !is null) fps.update(dt);
      _vg.beginFrame(GWidth, GHeight, 1);
      draw(_vg, GWidth, GHeight);
      peak_items = (peak_items > uiGetItemCount() ? peak_items : uiGetItemCount());
      peak_alloc = (peak_alloc > uiGetAllocSize() ? peak_alloc : uiGetAllocSize());
      if (fps !is null) fps.render(_vg, GWidth-200-5, GHeight-35-5);
      _vg.endFrame();
    }
  };

  sdwindow.visibleForTheFirstTime = delegate () {
    sdwindow.setAsCurrentOpenGlContext(); // make this window active
    sdwindow.vsync = false;
    //sdwindow.useGLFinish = false;
    //glbindLoadFunctions();

    version(DEMO_MSAA) {
      _vg = createGL2NVG(NVG_STENCIL_STROKES|NVG_DEBUG);
    } else {
      _vg = createGL2NVG(NVG_ANTIALIAS|NVG_STENCIL_STROKES|NVG_DEBUG);
    }
    if (_vg is null) {
      import std.stdio;
      writeln("Could not init nanovg.");
      //sdwindow.close();
    }
    init(_vg);
    fps = new PerfGraph("Frame Time", PerfGraph.Style.FPS, "system");
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
          //{ import std.stdio; writeln(event.x, ", ", event.y); }
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
