/*
OUI - A minimal semi-immediate GUI handling & layouting library

Copyright (c) 2014 Leonard Ritter <leonard.ritter@duangle.com>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
 */
/* Invisible Vector Library
 * ported by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * Understanding is not required. Only obedience.
 * yes, this D port is GPLed. thanks to all "active" members of D
 * community, and for all (zero) feedback posts.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */
module iv.nanovg.oui.controls;

import core.stdc.stdio : snprintf;
import iv.nanovg;
import iv.nanovg.oui.engine;
import iv.nanovg.oui.blendish;

import std.functional : toDelegate;

import arsd.simpledisplay : Key;


private string toStr(T : const(char)[]) (T buf) {
  static if (is(T == string)) return buf; else return buf.idup;
}


////////////////////////////////////////////////////////////////////////////////
private:
alias SubType = int;
enum {
  // label
  ST_LABEL,
  // button
  ST_BUTTON,
  // radio button
  ST_RADIO,
  // progress slider
  ST_SLIDER,
  // column
  ST_COLUMN,
  // row
  ST_ROW,
  // check button
  ST_CHECK,
  // panel
  ST_PANEL,
  // text
  ST_TEXT,
  //
  ST_IGNORE,

  // colored rectangle
  ST_RECT,

  ST_HBOX,
  ST_VBOX,

  //ST_DEMOSTUFF,
  ST_USER,
}

struct UIData {
  int subtype;
  UIhandler handler;
}

struct UIUserData {
  UIData head;
  void delegate (NVGcontext* vg, int item) onPaint;
  void delegate (int item, UIevent event) onClick;
}

struct UIRectData {
  UIData head;
  string label;
  NVGcolor color;
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

public struct CtlTextData {
  char[] text;
}

struct UITextData {
  UIData head;
  CtlTextData* text;
  int maxsize;
}


// ////////////////////////////////////////////////////////////////////////// //
private:
public void ui_handler (int item, UIevent event) {
  auto data = uiGetHandle!UIData(item);
  if (data !is null && data.handler !is null) data.handler(item, event);
}


// ////////////////////////////////////////////////////////////////////////// //
public string ctlGetButtonLabel (int item) {
  auto data = uiGetHandle!(const UIButtonData)(item);
  return data.label;
}


public void ctlSetPanelHandler (int item, UIhandler h) {
  (uiGetHandle!UIData(item)).handler = h;
}


// ////////////////////////////////////////////////////////////////////////// //
void drawUIItems (NVGcontext* vg, int item, int corners) {
  int kid = uiFirstChild(item);
  while (kid > 0) {
    drawUI(vg, kid, corners);
    kid = uiNextSibling(kid);
  }
}

void drawUIItemsHbox (NVGcontext* vg, int item) {
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


void drawUIItemsVbox (NVGcontext* vg, int item) {
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


public void drawUI (NVGcontext* vg, int item, int corners) {
  auto head = uiGetHandle!(UIData)(item);
  UIrect rect = uiGetRect(item);
  if (uiGetState(item) == UI_FROZEN) nvgGlobalAlpha(vg, BND_DISABLED_ALPHA);
  if (head) {
    switch (head.subtype) {
      default:
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
        char[32] value;
        auto len = snprintf(value.ptr, value.length, "%.0f%%", cast(double)((*data.progress)*100.0f));
        bndSlider(vg, rect.x, rect.y, rect.w, rect.h, corners, state, *data.progress, data.label, value[0..len]);
        break;
      case ST_TEXT:
        auto data = cast(const(UITextData)*)head;
        BNDwidgetState state = cast(BNDwidgetState)uiGetState(item);
        int idx = cast(int)data.text.text.length;
        bndTextField(vg, rect.x, rect.y, rect.w, rect.h, corners, state, -1, data.text.text, idx, idx);
        break;
      //case ST_DEMOSTUFF:
      //  draw_demostuff(vg, rect.x, rect.y, rect.w, rect.h);
      //  break;
      case ST_USER:
        auto data = cast(UIUserData*)head;
        if (data.onPaint !is null) data.onPaint(vg, item);
        break;
      case ST_RECT:
        auto data = cast(const(UIRectData)*)head;
        if (rect.w && rect.h) {
          BNDwidgetState state = cast(BNDwidgetState)uiGetState(item);
          nvgSave(vg);
          scope(exit) nvgRestore(vg);
          nvgStrokeColor(vg, nvgRGBAf(data.color.r, data.color.g, data.color.b, 0.9f));
          if (state != BND_DEFAULT) {
            nvgFillColor(vg, nvgRGBAf(data.color.r, data.color.g, data.color.b, 0.5f));
          } else {
            nvgFillColor(vg, nvgRGBAf(data.color.r, data.color.g, data.color.b, 0.1f));
          }
          nvgStrokeWidth(vg, 2);
          nvgBeginPath(vg);
          version(none) {
            nvgRect(vg, rect.x, rect.y, rect.w, rect.h);
          } else {
            nvgRoundedRect(vg, rect.x, rect.y, rect.w, rect.h, 3);
          }
          nvgFill(vg);
          nvgStroke(vg);

          if (state != BND_DEFAULT) {
            nvgFillColor(vg, nvgRGBAf(0.0f, 0.0f, 0.0f, 1.0f));
            nvgFontSize(vg, 15.0f);
            nvgBeginPath(vg);
            nvgTextAlign(vg, NVGalign.Top|NVGalign.Center);
            nvgTextBox(vg, rect.x, rect.y+rect.h*0.3f, rect.w, data.label);
          }
        }

        nvgSave(vg);
        scope(exit) nvgRestore(vg);
        nvgIntersectScissor(vg, rect.x, rect.y, rect.w, rect.h);

        drawUIItems(vg, item, corners);
        break;
    }
  } else {
    drawUIItems(vg, item, corners);
  }

  if (uiGetState(item) == UI_FROZEN) nvgGlobalAlpha(vg, 1.0);
}


// ////////////////////////////////////////////////////////////////////////// //
void user_handler (int item, UIevent event) {
  auto data = uiGetHandle!UIUserData(item);
  if (data.onClick !is null) data.onClick(item, event);
}


public int userCtl (void delegate (NVGcontext* vg, int item) onPaint, void delegate (int item, UIevent event) onClick=null) {
  int item = uiItem();
  UIUserData *data = uiAllocHandle!UIUserData(item);
  data.head.subtype = ST_USER;
  data.head.handler = null;
  data.onPaint = onPaint;
  data.onClick = onClick;
  uiSetEvents(item, UI_BUTTON0_DOWN);
  return item;
}


// ////////////////////////////////////////////////////////////////////////// //
public int colorrect(T : const(char)[]) (T label, NVGcolor color) {
  int item = uiItem();
  UIRectData *data = uiAllocHandle!UIRectData(item);
  data.head.subtype = ST_RECT;
  data.head.handler = null;
  data.label = label.toStr;
  data.color = color;
  uiSetEvents(item, UI_BUTTON0_DOWN);
  return item;
}


// ////////////////////////////////////////////////////////////////////////// //
public int label(T : const(char)[]) (int iconid, T label) {
  int item = uiItem();
  uiSetSize(item, 0, BND_WIDGET_HEIGHT);
  UIButtonData *data = uiAllocHandle!UIButtonData(item);
  data.head.subtype = ST_LABEL;
  data.head.handler = null;
  data.iconid = iconid;
  data.label = label.toStr;
  return item;
}


// ////////////////////////////////////////////////////////////////////////// //
public int button(T : const(char)[]) (int iconid, T label, UIhandler handler) {
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


// ////////////////////////////////////////////////////////////////////////// //
void checkhandler (int item, UIevent event) {
  auto data = uiGetHandle!UICheckData(item);
  *data.option = !(*data.option);
}


public int check(T : const(char)[]) (T label, int* option) {
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


// ////////////////////////////////////////////////////////////////////////// //
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


public int slider(T : const(char)[]) (T label, float* progress) {
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


// ////////////////////////////////////////////////////////////////////////// //
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


public int textbox (CtlTextData* text, int maxsize) {
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


// ////////////////////////////////////////////////////////////////////////// //
// simple logic for a radio button
void radiohandler (int item, UIevent event) {
  UIRadioData *data = uiGetHandle!UIRadioData(item);
  *data.value = item;
}


public int radio(T : const(char)[]) (int iconid, T label, int *value) {
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


// ////////////////////////////////////////////////////////////////////////// //
public int panel () {
  int item = uiItem();
  UIData *data = uiAllocHandle!UIData(item);
  data.subtype = ST_PANEL;
  data.handler = null;
  return item;
}


// ////////////////////////////////////////////////////////////////////////// //
public int hbox () {
  int item = uiItem();
  UIData *data = uiAllocHandle!UIData(item);
  data.subtype = ST_HBOX;
  data.handler = null;
  uiSetBox(item, UI_ROW);
  return item;
}


// ////////////////////////////////////////////////////////////////////////// //
public int vbox () {
  int item = uiItem();
  UIData *data = uiAllocHandle!UIData(item);
  data.subtype = ST_VBOX;
  data.handler = null;
  uiSetBox(item, UI_COLUMN);
  return item;
}


// ////////////////////////////////////////////////////////////////////////// //
public int column_append (int parent, int item) {
  uiInsert(parent, item);
  // fill parent horizontally, anchor to previous item vertically
  uiSetLayout(item, UI_HFILL);
  uiSetMargins(item, 0, 1, 0, 0);
  return item;
}

public int column () {
  int item = uiItem();
  uiSetBox(item, UI_COLUMN);
  return item;
}


// ////////////////////////////////////////////////////////////////////////// //
public int vgroup_append (int parent, int item) {
  uiInsert(parent, item);
  // fill parent horizontally, anchor to previous item vertically
  uiSetLayout(item, UI_HFILL);
  return item;
}


public int vgroup () {
  int item = uiItem();
  uiSetBox(item, UI_COLUMN);
  return item;
}


// ////////////////////////////////////////////////////////////////////////// //
public int hgroup_append (int parent, int item) {
  uiInsert(parent, item);
  uiSetLayout(item, UI_HFILL);
  return item;
}


public int hgroup_append_fixed (int parent, int item) {
  uiInsert(parent, item);
  return item;
}


public int hgroup () {
  int item = uiItem();
  uiSetBox(item, UI_ROW);
  return item;
}


// ////////////////////////////////////////////////////////////////////////// //
public int row_append (int parent, int item) {
  uiInsert(parent, item);
  uiSetLayout(item, UI_HFILL);
  return item;
}


public int row () {
  int item = uiItem();
  uiSetBox(item, UI_ROW);
  return item;
}
