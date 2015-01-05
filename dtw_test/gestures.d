/* coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * Understanding is not required. Only obedience.
 *
 *                   INVISIBLE VECTOR PUBLIC LICENSE
 *                       Version 0, August 2014
 *
 * Copyright (C) 2014 Ketmar Dark <ketmar@ketmar.no-ip.org>
 *
 * Everyone is permitted to copy and distribute verbatim or modified
 * copies of this license document, and changing it is allowed as long
 * as the name is changed.
 *
 *                   INVISIBLE VECTOR PUBLIC LICENSE
 *   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
 *
 * 0. You may not use this software in either source or binary form, any
 *    software derived from this software, any library which uses either
 *    this software or code derived from this software in any other
 *    software which uses Windows API, either directly or indirectly
 *    via any chain of libraries.
 *
 * 1. You may not use this software in either source or binary form, any
 *    software derived from this software, any library which uses either
 *    this software or code derived from this software in any other
 *    software which uses MacOS X API, either directly or indirectly via
 *    any chain of libraries.
 *
 * 2. You may not use this software in either source or binary form, any
 *    software derived from this software, any library which uses either
 *    this software or code derived from this software in any other
 *    software on the territory of Russian Federation, either directly or
 *    indirectly via any chain of libraries.
 *
 * 3. Redistributions of this software in either source or binary form must
 *    retain this list of conditions and the following disclaimer.
 *
 * 4. Otherwise, you are allowed to use this software in any way that will
 *    not violate paragraphs 0, 1, 2 and 3 of this license.
 *
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 * Authors: Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * License: IVPLv0
 */
module gestures;
private:

import std.stdio;

import iv.videolib;

import iv.gengdtw;


// ////////////////////////////////////////////////////////////////////////// //
ulong msgHideTime = 0;
VLOverlay ovlMsg;
int msgAlpha = -1;


void updateMsg () {
  if (msgAlpha >= 0) {
    if (msgAlpha > 0) {
      if ((msgAlpha += 10) > 255) {
        msgAlpha = -1;
        ovlMsg = null;
      }
    } else {
      if (getTicks() >= msgHideTime) {
        msgAlpha = 1;
      }
    }
    frameChanged();
  }
}


void showMessage (string msg) {
  if (msg.length == 0) return;
  ovlMsg = new VLOverlay(msg.length*6+6, 8+6);
  ovlMsg.fillRect(0, 0, ovlMsg.width, ovlMsg.height, rgb2col(25, 69, 247));
  ovlMsg.rect(0, 0, ovlMsg.width, ovlMsg.height, rgb2col(255, 255, 255));
  ovlMsg.rect(1, 1, ovlMsg.width-2, ovlMsg.height-2, rgb2col(0, 0, 0));
  Color fg = rgb2col(255, 255, 255);
  int x = 3;
  foreach (auto ch; msg) {
    /*
    switch (ch) {
      case 1: fg = rgb2col(255, 255, 255); break;
      case 2: fg = rgb2col(0, 255, 0); break;
      case 3: fg = rgb2col(255, 255, 0); break;
      case 4: fg = rgb2col(255, 127, 0); break;
      default: break;
    }
    if (ch < 32) continue;
    */
    ovlMsg.drawChar(x, 3, ch, fg);
    x += 6;
  }
  msgHideTime = getTicks()+5000;
  msgAlpha = 0;
  frameChanged();
}


// ////////////////////////////////////////////////////////////////////////// //
VLOverlay helpOverlay () {
  static immutable string[] helpText = [
    "\x1fDemo actions",
    "\x1f------------",
    "\3keyboard:\1",
    " \2F1\1: toggle help",
    " \2F2\1: save library to '\4strokes.dat\1'",
    " \2F3\1: replace library with '\4strokes.dat\1'",
    " \2ESC\1: quit",
    " \2DEL\1: delete selected stroke",
    "",
    "\3mouse:\1",
    " \2LMB\1: select name or start drawing",
    " \2RMB\1: register current stroke as template",
  ];

  static auto stlen (string s) {
    usize res = 0;
    foreach (immutable char ch; s) if (ch >= 32) ++res;
    return res;
  }

  static VLOverlay ovlHelp = null;

  if (ovlHelp is null) {
    usize maxlen = 0;
    foreach (auto s; helpText) {
      auto ln = stlen(s);
      if (ln > maxlen) maxlen = ln;
    }
    ovlHelp = new VLOverlay(maxlen*6+6, helpText.length*8+6);
    ovlHelp.fillRect(0, 0, ovlHelp.width, ovlHelp.height, rgb2col(25, 69, 247));
    ovlHelp.rect(0, 0, ovlHelp.width, ovlHelp.height, rgb2col(255, 255, 255));
    ovlHelp.rect(1, 1, ovlHelp.width-2, ovlHelp.height-2, rgb2col(0, 0, 0));
    foreach (auto idx, auto s; helpText) {
      if (s.length == 0) continue;
      auto ln = stlen(s)*6;
      auto x = (ovlHelp.width-ln)/2;
      auto y = idx*8+3;
      string st = s;
      if (s[0] == '\x1f') {
        st = s[1..$];
      } else {
        x = 3;
      }
      Color fg = rgb2col(255, 255, 255);
      foreach (auto ch; st) {
        switch (ch) {
          case 1: fg = rgb2col(255, 255, 255); break;
          case 2: fg = rgb2col(0, 255, 0); break;
          case 3: fg = rgb2col(255, 255, 0); break;
          case 4: fg = rgb2col(255, 127, 0); break;
          default: break;
        }
        if (ch < 32) continue;
        ovlHelp.drawChar(x, y, ch, fg);
        x += 6;
      }
    }
  }

  return ovlHelp;
}


// ////////////////////////////////////////////////////////////////////////// //
DTWGlyph[] glib;
int nameMaxLen = 0;
int curPattern = -1;
DTWGlyph drawnGlyph;
DTWGlyph detectedGlyph;
bool helpVisible;


void fixNameMaxLen () {
  nameMaxLen = 0;
  foreach (auto g; glib) if (g.name.length > nameMaxLen) nameMaxLen = cast(int)g.name.length;
}


// ////////////////////////////////////////////////////////////////////////// //
void drawStroke (const(DTWGlyph) stk) {
  auto col = rgb2col(255, 255, 0);
  foreach (uint idx; 1..stk.length) {
    immutable p0 = stk[idx-1], p1 = stk[idx];
    double x0 = p0.x, y0 = p0.y;
    double x1 = p1.x, y1 = p1.y;
    vscrOvl.line(cast(int)x0, cast(int)y0, cast(int)x1, cast(int)y1, col);
  }
}


void drawTemplate (const(DTWGlyph) stk) {
  foreach (uint idx; 1..stk.length) {
    auto g = cast(ubyte)(255*idx/(stk.length-1));
    auto b = cast(ubyte)(255-(255*idx/(stk.length-1)));
    immutable p0 = stk[idx-1], p1 = stk[idx];
    double x0 = p0.x, y0 = p0.y;
    double x1 = p1.x, y1 = p1.y;
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
  with (vscrOvl) {
    rect(0, 0, wdt, hgt, rgb2col(255, 255, 255));
    rect(1, 1, wdt-2, hgt-2, 0);
    fillRect(2, 2, wdt-4, hgt-4, rgb2col(0, 0, 127));
  }
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
    with (vscrOvl) {
      fillRect(2, idx*8+2, wdt-4, 8, bkcol);
      drawStr(2, idx*8+2, g.name, col);
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
void updateCB (int elapsedTicks) {
  updateMsg();
}


// ////////////////////////////////////////////////////////////////////////// //
int curGlyph = -1;
string curGlyphName;
bool editingName;
string yesNoMessage;


void registerGlyph () {
  if (drawnGlyph !is null && drawnGlyph.valid && curGlyphName.length > 0) {
    auto gg = drawnGlyph.clone;
    gg.finish;
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
    with (vscrOvl) {
      fillRect(0, vlHeight-8, vlWidth, 8, rgb2col(128, 0, 0));
      drawStr(0, vlHeight-8, yesNoMessage, rgb2col(255, 255, 0));
    }
  } else if (editingName) {
    with (vscrOvl) {
      fillRect(0, vlHeight-8, vlWidth, 8, rgb2col(0, 0, 190));
      drawStr(0, vlHeight-8, curGlyphName, rgb2col(255, 127, 0));
      fillRect(curGlyphName.length*6, vlHeight-8, 6, 8, rgb2col(255, 255, 0));
    }
  }
  if (msgAlpha >= 0 && ovlMsg !is null) {
    auto ho = ovlMsg;
    ho.blit(vscrOvl, (vlWidth-ho.width)/2, 2, msgAlpha&0xff);
  }
  if (helpVisible) {
    auto ho = helpOverlay;
    ho.blit(vscrOvl, (vlWidth-ho.width)/2, (vlHeight-ho.height)/2, 32);
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
  if (helpVisible) {
    if (ev.keysym.sym == SDLK_ESCAPE || ev.keysym.sym == SDLK_F1) {
      helpVisible = false;
      frameChanged();
    }
    return;
  }
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
  if (ev.keysym.sym == SDLK_F1) {
    helpVisible = true;
    frameChanged();
    return;
  }
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
      drawnGlyph = new DTWGlyph();
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
        if (detectedGlyph !is null && detectedGlyph.name.length > 0) {
          showMessage("glyph: '"~detectedGlyph.name~"'");
        }
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
  update = &updateCB;
  rebuild = &rebuildCB;
  onKeyDown = &onKeyDownCB;
  onTextInput = &onTextInputCB;
  onMouseDown = &onMouseDownCB;
  onMouseUp = &onMouseUpCB;
  onMouseDouble = &onMouseDoubleCB;
  onMouseMotion = &onMouseMotionCB;
  mainLoop();
}
