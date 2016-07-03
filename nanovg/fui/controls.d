/* Invisible Vector Library
 * simple FlexBox-based UI layout engine, suitable for using in
 * immediate mode GUI libraries.
 *
 * coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * Understanding is not required. Only obedience.
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
module iv.nanovg.fui.controls;

import iv.nanovg;
import iv.nanovg.oui.blendish;

import iv.nanovg.fui.engine;


// ////////////////////////////////////////////////////////////////////////// //
enum FuiCtlType : ubyte {
  Invisible,
  Box,
  Label,
  Button,
  Panel,
}

mixin template FuiCtlHead() {
  FuiCtlType type;
}


// ////////////////////////////////////////////////////////////////////////// //
align(1) struct FuiCtlSpan {
align(1):
  mixin FuiCtlHead;
}


int span (FuiContext ctx, int parent, bool ahorizontal) {
  if (!ctx.valid) return -1;
  auto item = ctx.addItem!FuiCtlSpan(parent);
  with (ctx.layprops(item)) {
    flex = 1;
    visible = false;
    horizontal = ahorizontal;
    aligning = (ahorizontal ? FuiLayoutProps.Align.Stretch : FuiLayoutProps.Align.Start);
  }
  auto data = ctx.item!FuiCtlSpan(item);
  data.type = FuiCtlType.Invisible;
  return item;
}

int hspan (FuiContext ctx, int parent) { return ctx.span(parent, true); }
int vspan (FuiContext ctx, int parent) { return ctx.span(parent, false); }


// ////////////////////////////////////////////////////////////////////////// //
align(1) struct FuiCtlBox {
align(1):
  mixin FuiCtlHead;
}


int box (FuiContext ctx, int parent, bool ahorizontal) {
  if (!ctx.valid) return -1;
  auto item = ctx.addItem!FuiCtlBox(parent);
  with (ctx.layprops(item)) {
    flex = 1;
    horizontal = ahorizontal;
    aligning = (ahorizontal ? FuiLayoutProps.Align.Stretch : FuiLayoutProps.Align.Start);
  }
  auto data = ctx.item!FuiCtlBox(item);
  data.type = FuiCtlType.Box;
  return item;
}

int hbox (FuiContext ctx, int parent) { return ctx.box(parent, true); }
int vbox (FuiContext ctx, int parent) { return ctx.box(parent, false); }


// ////////////////////////////////////////////////////////////////////////// //
align(1) struct FuiCtlPanel {
align(1):
  mixin FuiCtlHead;
}


int panel (FuiContext ctx, int parent, bool ahorizontal) {
  if (!ctx.valid) return -1;
  auto item = ctx.addItem!FuiCtlPanel(parent);
  with (ctx.layprops(item)) {
    flex = 1;
    horizontal = ahorizontal;
    aligning = (ahorizontal ? FuiLayoutProps.Align.Stretch : FuiLayoutProps.Align.Start);
  }
  auto data = ctx.item!FuiCtlPanel(item);
  data.type = FuiCtlType.Panel;
  return item;
}

int hpanel (FuiContext ctx, int parent) { return ctx.panel(parent, true); }
int vpanel (FuiContext ctx, int parent) { return ctx.panel(parent, false); }


// ////////////////////////////////////////////////////////////////////////// //
align(1) struct FuiCtlLabel {
align(1):
  mixin FuiCtlHead;

  string text;
  int iconid;
  int htaligh;
}

int label (FuiContext ctx, int parent, string text, int iconid=-1) {
  if (!ctx.valid) return -1;
  auto item = ctx.addItem!FuiCtlLabel(parent);
  auto data = ctx.item!FuiCtlLabel(item);
  data.type = FuiCtlType.Label;
  data.htaligh = BND_LEFT;
  if (text.length && text[0] == '\x01') {
    text = text[1..$];
    data.htaligh = BND_CENTER;
  } else if (text.length && text[0] == '\x02') {
    text = text[1..$];
    data.htaligh = BND_RIGHT;
  }
  data.text = text;
  data.iconid = iconid;
  auto font = bndGetFont();
  if (font >= 0 && ctx.vg !is null) {
    float[4] bounds;
    nvgTextBounds(ctx.vg, 0, 0, text, bounds);
    ctx.layprops(item).minSize = FuiSize(cast(int)(bounds[2]-bounds[0])+4, cast(int)(bounds[3]-bounds[1])+4);
    //{ import std.stdio; writeln(bounds[]); }
  } else {
    ctx.layprops(item).minSize = FuiSize(cast(int)text.length*8+4, 10);
  }
  with (ctx.layprops(item)) {
    flex = 1;
  }
  return item;
}


// ////////////////////////////////////////////////////////////////////////// //
align(1) struct FuiCtlButton {
align(1):
  mixin FuiCtlHead;

  string text;
  int iconid;
}

int button (FuiContext ctx, int parent, string text, int iconid=-1) {
  if (!ctx.valid) return -1;
  auto item = ctx.addItem!FuiCtlButton(parent);
  auto data = ctx.item!FuiCtlButton(item);
  data.type = FuiCtlType.Button;
  data.text = text;
  data.iconid = iconid;
  auto font = bndGetFont();
  if (font >= 0 && ctx.vg !is null) {
    float[4] bounds;
    nvgTextBounds(ctx.vg, 0, 0, text, bounds);
    ctx.layprops(item).minSize = FuiSize(cast(int)(bounds[2]-bounds[0])+16, cast(int)(bounds[3]-bounds[1])+4);
    //{ import std.stdio; writeln(bounds[]); }
  } else {
    ctx.layprops(item).minSize = FuiSize(cast(int)text.length*8+4, 10);
  }
  with (ctx.layprops(item)) {
    flex = 1;
    clickMask |= FuiLayoutProps.Buttons.Left;
    canBeFocused = true;
  }
  return item;
}



// ////////////////////////////////////////////////////////////////////////// //
void draw (FuiContext ctx, NVGcontext* avg=null) {
  if (!ctx.valid) return;
  auto nvg = (avg !is null ? avg : ctx.vg);
  if (nvg is null) return;

  void drawItem (int item, FuiPoint g) {
    auto lp = ctx.layprops(item);
    if (lp is null) return;
    if (!lp.visible) return;

    // convert local coords to global coords
    auto rc = lp.position;
    rc.xp += g.x;
    rc.yp += g.y;

    if (!lp.enabled) nvgGlobalAlpha(nvg, 0.5); else if (item == ctx.focused) nvgGlobalAlpha(nvg, 0.7);
    scope(exit) nvgGlobalAlpha(nvg, 1.0);

    if (item == 0) {
      bndBackground(nvg, rc.x, rc.y, rc.w, rc.h);
      nvgScissor(nvg, rc.x, rc.y, rc.w, rc.h);
    } else {
      final switch (ctx.item!FuiCtlSpan(item).type) {
        case FuiCtlType.Invisible: break;
        case FuiCtlType.Box: break;
        case FuiCtlType.Label:
          auto data = ctx.item!FuiCtlLabel(item);
          bndLabel(nvg, rc.x, rc.y, rc.w, rc.h, data.iconid, data.text, data.htaligh);
          break;
        case FuiCtlType.Button:
          auto data = ctx.item!FuiCtlButton(item);
          bndToolButton(nvg, rc.x, rc.y, rc.w, rc.h, BND_CORNER_NONE, (lp.active ? BND_ACTIVE : lp.hovered ? BND_HOVER : BND_DEFAULT), data.iconid, data.text);
          break;
        case FuiCtlType.Panel:
          bndBevel(nvg, rc.x, rc.y, rc.w, rc.h);
          break;
      }
    }
    // draw children
    item = lp.firstChild;
    lp = ctx.layprops(item);
    if (lp is null) return;
    // as we will setup scissors, we need to save and restore state
    nvgSave(nvg);
    scope(exit) nvgRestore(nvg);
    // setup scissors
    nvgIntersectScissor(nvg, rc.x, rc.y, rc.w, rc.h);
    while (lp !is null) {
      drawItem(item, rc.pos);
      item = lp.nextSibling;
      lp = ctx.layprops(item);
    }
  }

  nvgSave(nvg);
  scope(exit) nvgRestore(nvg);
  drawItem(0, ctx.layprops(0).position.pos);
}


