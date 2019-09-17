/* Invisible Vector Library
 * coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * Understanding is not required. Only obedience.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 3 of the License ONLY.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */
module gesturespt_test /*is aliced*/;
private:

import std.stdio;

import iv.alice;
import iv.videolib;
import iv.geng;


// ////////////////////////////////////////////////////////////////////////// //
PTGlyph[] glib;
int nameMaxLen = 0;
int curPattern = -1;
PTGlyph drawnGlyph;
PTGlyph detectedGlyph;


void fixNameMaxLen () {
  nameMaxLen = 0;
  foreach (auto g; glib) if (g.name.length > nameMaxLen) nameMaxLen = cast(int)g.name.length;
}


// ////////////////////////////////////////////////////////////////////////// //
void drawStroke (const(PTGlyph) stk) {
  auto col = rgb2col(255, 255, 0);
  foreach (uint idx; 1..stk.length) {
    double x0 = stk.x(idx-1), y0 = stk.y(idx-1);
    double x1 = stk.x(idx), y1 = stk.y(idx);
    vscrOvl.line(cast(int)x0, cast(int)y0, cast(int)x1, cast(int)y1, col);
  }
}


void drawTemplate (const(PTGlyph) stk) {
  foreach (uint idx; 1..stk.length) {
    auto g = cast(ubyte)(255*idx/(stk.length-1));
    auto b = cast(ubyte)(255-(255*idx/(stk.length-1)));
    double x0 = stk.x(idx-1), y0 = stk.y(idx-1);
    double x1 = stk.x(idx), y1 = stk.y(idx);
    x0 = x0*200+400;
    y0 = y0*200+300;
    x1 = x1*200+400;
    y1 = y1*200+300;
    vscrOvl.line(cast(int)x0, cast(int)y0, cast(int)x1, cast(int)y1, rgb2col(0, g, b));
  }
}


void drawStrokeList (int curptr) {
  int wdt = nameMaxLen*6+4;
  int hgt = cast(int)(glib.length*8+4);
  vscrOvl.rect(0, 0, wdt, hgt, rgb2col(255, 255, 255));
  vscrOvl.rect(1, 1, wdt-2, hgt-2, 0);
  vscrOvl.fillRect(2, 2, wdt-4, hgt-4, rgb2col(0, 0, 127));
  foreach (auto idx, auto g; glib) {
    Color col, bkcol;
    if (g is detectedGlyph) {
      // highlighted
      col = rgb2col(255, 255, 255);
      //bkcol = rgb2col(0, 0, 255);
      bkcol = rgb2col(0, 100, 0);
    } else {
      col = rgb2col(255, 127, 0);
      bkcol = rgb2col(0, 0, 127);
    }
    if (curptr == idx) bkcol = rgb2col(0, 127, 0);
    if (idx == curPattern) col = rgb2col(255, 255, 0);
    vscrOvl.fillRect(2, idx*8+2, wdt-4, 8, bkcol);
    vscrOvl.drawStr(2, idx*8+2, g.name, col);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
void updateCB (int elapsedTicks) {
  //frameChanged();
}


// ////////////////////////////////////////////////////////////////////////// //
int curGlyph = -1;
string curGlyphName;
bool editingName;
string yesNoMessage;


void registerGlyph () {
  if (drawnGlyph !is null && drawnGlyph.valid && curGlyphName.length > 0) {
    auto gg = drawnGlyph.clone.normalize;
    gg.name = curGlyphName;
    usize gpos = usize.max;
    foreach (auto idx, auto g; glib) if (g.name == curGlyphName) { gpos = idx; break; }
    if (gpos != usize.max) {
      glib[gpos] = gg;
    } else {
      gpos = glib.length;
      glib ~= gg;
    }
    fixNameMaxLen();
    curPattern = cast(int)gpos;
  }
}


void rebuildCB () {
  vscrOvl.clear(0);
  if (curPattern >= 0 && curPattern < cast(int)glib.length) drawTemplate(glib[curPattern]);
  drawStrokeList(curGlyph);
  if (drawnGlyph !is null && drawnGlyph.valid) drawStroke(drawnGlyph);
  if (yesNoMessage.length > 0) {
    vscrOvl.fillRect(0, vlHeight-8, vlWidth, 8, rgb2col(128, 0, 0));
    vscrOvl.drawStr(0, vlHeight-8, yesNoMessage, rgb2col(255, 255, 0));
  } else if (editingName) {
    vscrOvl.fillRect(0, vlHeight-8, vlWidth, 8, rgb2col(0, 0, 190));
    vscrOvl.drawStr(0, vlHeight-8, curGlyphName, rgb2col(255, 127, 0));
    vscrOvl.fillRect(curGlyphName.length*6, vlHeight-8, 6, 8, rgb2col(255, 255, 0));
  }
}


// ////////////////////////////////////////////////////////////////////////// //
void onTextInputCB (dchar ch) {
  if (ch >= ' ' && ch <= 255) {
    curGlyphName ~= cast(char)ch;
    frameChanged();
    return;
  }
}


void onKeyDownCB (in ref SDL_KeyboardEvent ev) {
  if (ev.keysym.sym == SDLK_RETURN && (ev.keysym.mod&KMOD_ALT)) { switchFullscreen(); return; }
  if (yesNoMessage.length > 0) {
    switch (ev.keysym.sym) {
      case SDLK_ESCAPE: yesNoMessage = null; break;
      case SDLK_RETURN:
        glib = glib[0..curPattern]~glib[curPattern+1..$];
        detectedGlyph = null;
        curPattern = -1;
        yesNoMessage = null;
        break;
      default: break;
    }
    frameChanged();
    return;
  }
  if (editingName) {
    switch (ev.keysym.sym) {
      case SDLK_ESCAPE: editingName = false; break;
      case SDLK_BACKSPACE:
        if (curGlyphName.length > 0) curGlyphName = curGlyphName[0..$-1];
        break;
      case SDLK_RETURN: registerGlyph(); editingName = false; break;
      default: break;
    }
    if (!editingName) stopTextInput();
    frameChanged();
    return;
  }
  if (ev.keysym.sym == SDLK_ESCAPE) { postQuitMessage(); return; }
  if (ev.keysym.sym == SDLK_F2) {
    gstLibSave(File("strokes.dat", "w"), glib[]);
    writefln("%s strokes saved", glib.length);
    frameChanged();
    return;
  }
  if (ev.keysym.sym == SDLK_F3) {
    glib = gstLibLoad(File("strokes.dat"));
    fixNameMaxLen();
    writefln("%s strokes loaded", glib.length);
    detectedGlyph = null;
    curPattern = -1;
    drawnGlyph = null;
    frameChanged();
    return;
  }
  if (ev.keysym.sym == SDLK_DELETE) {
    if (curPattern >= 0) {
      yesNoMessage = "Remove '"~glib[curPattern].name~"'?";
      frameChanged();
      return;
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
int mdown = 0;


int getSelectedGlyph (int x, int y) {
  int wdt = nameMaxLen*6+4;
  int hgt = cast(int)(glib.length*8+4);
  if (x >= 2 && y >= 2 && x < wdt-4 && y < hgt-4) {
    return cast(int)((y-2)/8);
  } else {
    return -1;
  }
}


void onMouseDownCB (in ref SDL_MouseButtonEvent ev) {
  if (yesNoMessage.length > 0 || editingName) return;
  if (mdown == 0) {
    if (ev.button == SDL_BUTTON_LEFT) {
      auto ng = getSelectedGlyph(ev.x, ev.y);
      if (ng >= 0) {
        curPattern = ng;
        frameChanged();
        return;
      }
    }
    if (ev.button == SDL_BUTTON_LEFT || ev.button == SDL_BUTTON_RIGHT) {
      mdown = (ev.button == SDL_BUTTON_LEFT ? 1 : 2);
      detectedGlyph = null;
      drawnGlyph = new PTGlyph();
      drawnGlyph.addPoint(ev.x, ev.y);
      frameChanged();
    }
  }
}


void onMouseUpCB (in ref SDL_MouseButtonEvent ev) {
  if (yesNoMessage.length > 0 || editingName) return;
  if (mdown != 0) {
    if (drawnGlyph.valid) {
      if (mdown == 1) {
        detectedGlyph = drawnGlyph.findMatch(glib[]);
      } else {
        curGlyphName = (curPattern >= 0 ? glib[curPattern].name : "");
        editingName = true;
        startTextInput();
      }
    } else {
      drawnGlyph = null;
    }
    frameChanged();
  }
  mdown = 0;
}


void onMouseDoubleCB (in ref SDL_MouseButtonEvent ev) {
  //writeln("double button", ev.button, " at (", ev.x, ",", ev.y, ")");
}


void onMouseMotionCB (in ref SDL_MouseMotionEvent ev) {
  if (yesNoMessage.length > 0 || editingName) return;
  if (mdown == 0) {
    auto ng = getSelectedGlyph(ev.x, ev.y);
    if (ng != curGlyph) {
      curGlyph = ng;
      frameChanged();
    }
  } else if (mdown != 0) {
    drawnGlyph.addPoint(ev.x, ev.y);
    frameChanged();
  }
}


// ////////////////////////////////////////////////////////////////////////// //
void main (string[] args) {
  glib = gstLibLoad(File("strokes.dat"));
  fixNameMaxLen();
  writefln("%s strokes loaded", glib.length);
  //gstLibSave(File("strokes_new.dat", "w"), glib[]);
  vlWidth = 800;
  vlHeight = 600;
  useMag2x = false;
  processArgs(args);
  try {
    initVideo("Gestures/SDL");
  } catch (Throwable e) {
    writeln("FATAL: ", e.msg);
    return;
  }
  //
  setFPS(35);
  onUpdate = &updateCB;
  onRebuild = &rebuildCB;
  onKeyDown = &onKeyDownCB;
  onTextInput = &onTextInputCB;
  onMouseDown = &onMouseDownCB;
  onMouseUp = &onMouseUpCB;
  onMouseDouble = &onMouseDoubleCB;
  onMouseMotion = &onMouseMotionCB;
  mainLoop();
}
