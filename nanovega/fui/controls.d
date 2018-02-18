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
module iv.nanovega.fui.controls /*is aliced*/;

import arsd.simpledisplay;

import iv.alice;
import iv.nanovega.nanovega;
import iv.nanovega.blendish;

import iv.nanovega.fui.engine;


// ////////////////////////////////////////////////////////////////////////// //
__gshared auto fuiFocusColor = BND_COLOR_ACTIVE; //nvgRGB(86, 128, 194);


// ////////////////////////////////////////////////////////////////////////// //
enum FuiCtlType : ubyte {
  Invisible,
  Box,
  Panel,
  Label,
  Button,
  Check,
  Radio,
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
private int buttonLike(T, FuiCtlType type) (FuiContext ctx, int parent, string text, int iconid=-1) {
  if (!ctx.valid) return -1;
  auto item = ctx.addItem!T(parent);
  auto data = ctx.item!T(item);
  data.type = type;
  static if (is(typeof(T.htaligh))) {
    data.htaligh = BND_LEFT;
    if (text.length && text[0] == '\x01') {
      text = text[1..$];
      data.htaligh = BND_CENTER;
    } else if (text.length && text[0] == '\x02') {
      text = text[1..$];
      data.htaligh = BND_RIGHT;
    }
  }
  data.text = text;
  data.iconid = iconid;
  auto font = bndGetFont();
  if (font >= 0 && ctx.vg !is null) {
    /*
    float[4] bounds;
    ctx.vg.textBounds(0, 0, text, bounds);
    ctx.layprops(item).minSize = FuiSize(cast(int)(bounds[2]-bounds[0])+4, cast(int)(bounds[3]-bounds[1])+4);
    */
    auto w = cast(int)bndLabelWidth(ctx.vg, iconid, text);
    auto h = cast(int)bndLabelHeight(ctx.vg, iconid, text, w);
    ctx.layprops(item).minSize = FuiSize(w+2, h);
  } else {
    ctx.layprops(item).minSize = FuiSize(cast(int)text.length*8+4, 10);
  }
  with (ctx.layprops(item)) {
    flex = 1;
  }
  return item;
}


// ////////////////////////////////////////////////////////////////////////// //
align(1) struct FuiCtlLabel {
align(1):
  mixin FuiCtlHead;

  string text;
  int iconid;
  int htaligh;
}

int label (FuiContext ctx, int parent, string text, int iconid=-1) {
  return ctx.buttonLike!(FuiCtlLabel, FuiCtlType.Label)(parent, text, iconid);
}


// ////////////////////////////////////////////////////////////////////////// //
align(1) struct FuiCtlButton {
align(1):
  mixin FuiCtlHead;

  string text;
  int iconid;
}

int button (FuiContext ctx, int parent, string text, int iconid=-1) {
  auto item = ctx.buttonLike!(FuiCtlButton, FuiCtlType.Button)(parent, text, iconid);
  if (item >= 0) {
    with (ctx.layprops(item)) {
      flex = 1;
      clickMask |= FuiLayoutProps.Buttons.Left;
      canBeFocused = true;
    }
  }
  return item;
}


// ////////////////////////////////////////////////////////////////////////// //
align(1) struct FuiCtlCheck {
align(1):
  mixin FuiCtlHead;

  string text;
  int iconid;
  bool* var;
}

int checkbox (FuiContext ctx, int parent, string text, bool* var=null, int iconid=-1) {
  auto item = ctx.buttonLike!(FuiCtlCheck, FuiCtlType.Check)(parent, text, iconid);
  if (item >= 0) {
    auto data = ctx.item!FuiCtlCheck(item);
    data.var = var;
    with (ctx.layprops(item)) {
      flex = 1;
      clickMask |= FuiLayoutProps.Buttons.Left;
      canBeFocused = true;
      minSize.w += cast(int)BND_OPTION_WIDTH;
      if (minSize.h < BND_OPTION_HEIGHT) minSize.h = cast(int)BND_OPTION_HEIGHT;
    }
  }
  return item;
}


// ////////////////////////////////////////////////////////////////////////// //
align(1) struct FuiCtlRadio {
align(1):
  mixin FuiCtlHead;

  string text;
  int iconid;
  int* var;
}

int radio (FuiContext ctx, int parent, string text, int* var=null, int iconid=-1) {
  auto item = ctx.buttonLike!(FuiCtlRadio, FuiCtlType.Radio)(parent, text, iconid);
  if (item >= 0) {
    auto data = ctx.item!FuiCtlRadio(item);
    data.var = var;
    with (ctx.layprops(item)) {
      flex = 1;
      clickMask |= FuiLayoutProps.Buttons.Left;
      canBeFocused = true;
      minSize.w += 14;
    }
  }
  return item;
}


// ////////////////////////////////////////////////////////////////////////// //
void draw (FuiContext ctx, NVGContext avg=null) {
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

    if (!lp.enabled) nvg.globalAlpha(0.5); //else if (item == ctx.focused) nvg.globalAlpha(0.7);
    scope(exit) nvg.globalAlpha(1.0);

    if (item == 0) {
      bndBackground(nvg, rc.x, rc.y, rc.w, rc.h);
      nvg.scissor(rc.x, rc.y, rc.w, rc.h);
    } else {
      final switch (ctx.item!FuiCtlSpan(item).type) {
        case FuiCtlType.Invisible: break;
        case FuiCtlType.Box: break;
        case FuiCtlType.Panel:
          bndBevel(nvg, rc.x, rc.y, rc.w, rc.h);
          break;
        case FuiCtlType.Label:
          auto data = ctx.item!FuiCtlLabel(item);
          bndLabel(nvg, rc.x, rc.y, rc.w, rc.h, data.iconid, data.text, data.htaligh);
          break;
        case FuiCtlType.Button:
          auto data = ctx.item!FuiCtlButton(item);
          auto oic = bndGetTheme.toolTheme.innerColor;
          scope(exit) bndGetTheme.toolTheme.innerColor = oic;
          if (ctx.focused == item) bndGetTheme.toolTheme.innerColor = fuiFocusColor;
          bndToolButton(nvg, rc.x, rc.y, rc.w, rc.h, BND_CORNER_NONE, (lp.active ? BND_ACTIVE : lp.hovered ? BND_HOVER : BND_DEFAULT), data.iconid, data.text);
          break;
        case FuiCtlType.Check:
          auto data = ctx.item!FuiCtlCheck(item);
          auto oic0 = bndGetTheme.optionTheme.innerColor;
          auto oic1 = bndGetTheme.optionTheme.innerSelectedColor;
          scope(exit) {
            bndGetTheme.optionTheme.innerColor = oic0;
            bndGetTheme.optionTheme.innerSelectedColor = oic1;
          }
          if (ctx.focused == item) {
            bndGetTheme.optionTheme.innerColor = fuiFocusColor;
            bndGetTheme.optionTheme.innerSelectedColor = fuiFocusColor;
          }
          bndOptionButton(nvg, rc.x, rc.y, rc.w, rc.h, (data.var !is null && *data.var ? BND_ACTIVE : lp.hovered ? BND_HOVER : BND_DEFAULT), data.text);
          break;
        case FuiCtlType.Radio:
          auto data = ctx.item!FuiCtlCheck(item);
          auto oic0 = bndGetTheme.optionTheme.innerColor;
          auto oic1 = bndGetTheme.optionTheme.innerSelectedColor;
          scope(exit) {
            bndGetTheme.optionTheme.innerColor = oic0;
            bndGetTheme.optionTheme.innerSelectedColor = oic1;
          }
          if (ctx.focused == item) {
            bndGetTheme.optionTheme.innerColor = fuiFocusColor;
            bndGetTheme.optionTheme.innerSelectedColor = fuiFocusColor;
          }
          bndRadioButton2(nvg, rc.x, rc.y, rc.w, rc.h, BND_CORNER_NONE, (/*lp.active ? BND_ACTIVE :*/ lp.hovered ? BND_HOVER : BND_DEFAULT), data.iconid, data.text);
          break;
      }
    }
    // draw children
    item = lp.firstChild;
    lp = ctx.layprops(item);
    if (lp is null) return;
    // as we will setup scissors, we need to save and restore state
    nvg.save();
    scope(exit) nvg.restore();
    // setup scissors
    nvg.intersectScissor(rc.x, rc.y, rc.w, rc.h);
    while (lp !is null) {
      drawItem(item, rc.pos);
      item = lp.nextSibling;
      lp = ctx.layprops(item);
    }
  }

  nvg.save();
  scope(exit) nvg.restore();
  drawItem(0, ctx.layprops(0).position.pos);
}


// ////////////////////////////////////////////////////////////////////////// //
// returns `true` if event was consumed
bool fuiProcessEvent (FuiContext ctx, FuiEvent ev) {
  final switch (ev.type) {
    case FuiEvent.Type.None:
      return false;
    case FuiEvent.Type.Char: // param0: dchar; param1: mods&buttons
      return false;
    case FuiEvent.Type.Key: // param0: sdpy keycode; param1: mods&buttons
      if (auto lp = ctx.layprops(ev.item)) {
        if (lp.disabled || !lp.canBeFocused) return false;
        switch (ctx.item!FuiCtlSpan(ev.item).type) {
          case FuiCtlType.Button:
            if (ev.key == Key.Space) {
              auto data = ctx.item!FuiCtlButton(ev.item);
              if (lp.clickMask) {
                uint bidx = uint.max;
                foreach (ubyte shift; 0..8) if (lp.clickMask&(1<<shift)) { bidx = shift; break; }
                if (bidx != uint.max) {
                  ctx.queueEvent(ev.item, FuiEvent.Type.Click, bidx, ctx.lastButtons|(ctx.lastMods<<8));
                  return true;
                }
              }
            }
            break;
          case FuiCtlType.Check:
            if (ev.key == Key.Space) {
              auto data = ctx.item!FuiCtlCheck(ev.item);
              if (lp.clickMask) {
                if (data.var !is null) {
                  *data.var = !*data.var;
                  return true;
                } else {
                  uint bidx = uint.max;
                  foreach (ubyte shift; 0..8) if (lp.clickMask&(1<<shift)) { bidx = shift; break; }
                  if (bidx != uint.max) {
                    ctx.queueEvent(ev.item, FuiEvent.Type.Click, bidx, ctx.lastButtons|(ctx.lastMods<<8));
                    return true;
                  }
                }
              }
            }
            break;
          default:
        }
      }
      return false;
    case FuiEvent.Type.Click: // mouse click; param0: buttton index; param1: mods&buttons
      if (auto lp = ctx.layprops(ev.item)) {
        if (lp.disabled || !lp.canBeFocused) return false;
        switch (ctx.item!FuiCtlSpan(ev.item).type) {
          case FuiCtlType.Check:
            auto data = ctx.item!FuiCtlCheck(ev.item);
            if (lp.clickMask) {
              if (data.var !is null) {
                *data.var = !*data.var;
                return true;
              }
            }
            break;
          default:
        }
      }
      return false;
    case FuiEvent.Type.Double: // mouse double-click; param0: buttton index; param1: mods&buttons
      return false;
  }
}
