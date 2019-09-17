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
module gesturespro_test /*is aliced*/;
private:

import arsd.color;
import arsd.simpledisplay;

import iv.alice;
import iv.cmdcongl;
import iv.pdollar0;
import iv.pxclock;
import iv.vfs.io;

import testgestures;


// ////////////////////////////////////////////////////////////////////////// //
SimpleWindow sdwin;


// ////////////////////////////////////////////////////////////////////////// //
ulong msgHideTime = 0;
int msgAlpha = -1;
string msgText;


void updateMsg () {
  if (msgAlpha >= 0) {
    if (msgAlpha > 0) {
      if ((msgAlpha += 10) > 255) {
        msgAlpha = -1;
        msgText = null;
      }
    } else {
      if (clockMilli() >= msgHideTime) {
        msgAlpha = 1;
      }
    }
    frameChanged();
  }
}


void showMessage (string msg) {
  if (msg.length == 0) return;
  /+
  ovlMsg = new VLOverlay(msg.length*6+6, 8+6);
  ovlMsg.fillRect(0, 0, ovlMsg.width, ovlMsg.height, rgb2col(25, 69, 247));
  ovlMsg.rect(0, 0, ovlMsg.width, ovlMsg.height, rgb2col(255, 255, 255));
  ovlMsg.rect(1, 1, ovlMsg.width-2, ovlMsg.height-2, rgb2col(0, 0, 0));
  Color fg = rgb2col(255, 255, 255);
  int x = 3;
  foreach (/+auto+/ ch; msg) {
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
  +/
  msgText = msg;
  msgHideTime = clockMilli()+5000;
  msgAlpha = 0;
  frameChanged();
}


// ////////////////////////////////////////////////////////////////////////// //
DPGestureList glib;
int nameMaxLen = 0;
DPPointCloud curPattern;
DPPoint[] drawnGlyph;
string detectedGlyph;
bool helpVisible;


void fixNameMaxLen () {
  nameMaxLen = 0;
  foreach (string name; glib.knownGestureNames) if (name.length > nameMaxLen) nameMaxLen = cast(int)name.length;
}


// ////////////////////////////////////////////////////////////////////////// //
int curGlyph = -1;
string curGlyphName;
bool editingName;
string yesNoMessage;


void registerGlyph () {
  if (drawnGlyph.length > 5 && curGlyphName.length > 0) {
    auto pc = new DPPointCloud(curGlyphName, drawnGlyph);
    glib.appendGesture(pc);
    fixNameMaxLen();
    curPattern = pc;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
enum CharWidth = 10;
enum CharHeight = 10;

void frameChanged () {
  if (sdwin is null || sdwin.closed) return;

  {
    auto painter = sdwin.draw();

    void drawText (int x, int y, const(char)[] str...) {
      foreach (immutable char ch; str) {
        foreach (immutable int dy; 0..CharHeight) {
          ushort v = glConFont10.ptr[cast(ubyte)ch*CharHeight+dy];
          foreach (immutable int dx; 0..CharWidth) {
            if (v&0x8000) {
              painter.drawPixel(Point(x+dx, y+dy));
              //painter.drawLine(Point(x+dx, y+dy), Point(x+dx+1, y+dy+1));
            }
            v <<= 1;
          }
        }
        x += CharWidth;
      }
    }

    void helpOverlay () {
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
        " \2Ctl\1: hold it to draw next segment",
      ];

      static int stlen (string s) {
        int res = 0;
        foreach (immutable char ch; s) if (ch >= 32) ++res;
        return res;
      }

      int maxlen = 0;
      foreach (/*auto*/ s; helpText) {
        auto ln = stlen(s);
        if (ln > maxlen) maxlen = ln;
      }

      int wdt = (maxlen*CharWidth+6);
      int hgt = (CharHeight*cast(int)helpText.length+6);
      int x0 = (sdwin.width-wdt)/2;
      int y0 = (sdwin.height-hgt)/2;

      painter.outlineColor = Color(25, 69, 247);
      painter.fillColor = Color(25, 69, 247);
      painter.drawRectangle(Point(x0, y0), wdt, hgt);
      painter.fillColor = Color.transparent;
      painter.outlineColor = Color(255, 255, 255);
      painter.drawRectangle(Point(x0, y0), wdt, hgt);
      painter.outlineColor = Color.black;
      painter.drawRectangle(Point(x0+1, y0+1), wdt-2, hgt-2);

      foreach (/*auto*/ idx, /*auto*/ s; helpText) {
        if (s.length == 0) continue;
        auto ln = stlen(s)*CharWidth;
        auto x = (wdt-ln)/2;
        auto y = idx*CharHeight+3;
        string st = s;
        if (s[0] == '\x1f') {
          st = s[1..$];
        } else {
          x = 3;
        }
        Color fg = Color(255, 255, 255);
        foreach (/*auto*/ ch; st) {
          switch (ch) {
            case 1: fg = Color(255, 255, 255); break;
            case 2: fg = Color(0, 255, 0); break;
            case 3: fg = Color(255, 255, 0); break;
            case 4: fg = Color(255, 127, 0); break;
            default: break;
          }
          if (ch < 32) continue;
          painter.outlineColor = fg;
          drawText(x0+x, y0+y, ch);
          x += CharWidth;
        }
      }
    }

    void drawStroke (const(DPPoint)[] stk) {
      painter.outlineColor = Color(255, 255, 0);
      bool first = true;
      uint lastid = uint.max;
      foreach (immutable pidx, const ref DPPoint p; stk) {
        if (first) {
          lastid = p.id;
          first = false;
        } else if (p.id == lastid) {
          painter.drawLine(Point(cast(int)stk[pidx-1].x, cast(int)stk[pidx-1].y), Point(cast(int)stk[pidx].x, cast(int)stk[pidx].y));
        } else {
          painter.drawLine(Point(cast(int)stk[pidx-1].x, cast(int)stk[pidx-1].y), Point(cast(int)stk[pidx-1].x+1, cast(int)stk[pidx-1].y+1));
          first = true;
        }
      }
    }

    void drawTemplate (DPPointCloud stk) {
      if (stk is null) return;
      auto pts = stk.points;
      if (pts.length < 2) return;
      bool first = true;
      uint lastid = uint.max;
      double x0, y0, x1, y1;
      foreach (uint idx, const ref DPPoint p; pts) {
        auto g = cast(ubyte)(255*idx/(pts.length-1));
        auto b = cast(ubyte)(255-(255*idx/(pts.length-1)));

        if (first) {
          lastid = p.id;
          first = false;
          continue;
        }
        if (p.id == lastid) {
          x0 = pts[idx-1].x;
          y0 = pts[idx-1].y;
          x1 = pts[idx].x;
          y1 = pts[idx].y;
        } else {
          x0 = x1 = pts[idx-1].x;
          y0 = y1 = pts[idx-1].y;
          first = true;
        }

        //immutable p0 = stk.normPoint(idx-1), p1 = stk.normPoint(idx);
        x0 = x0*200+400;
        y0 = y0*200+300;
        x1 = x1*200+400;
        y1 = y1*200+300;
        painter.outlineColor = Color(0, g, b);
        painter.drawLine(Point(cast(int)x0, cast(int)y0), Point(cast(int)x1, cast(int)y1));
      }
    }

    void drawStrokeList (int curptr) {
      auto names = glib.knownGestureNames; //WARNING: this allocates like crazy!
      int wdt = nameMaxLen*CharWidth+4;
      int hgt = cast(int)(names.length*CharHeight+4);
      painter.outlineColor = Color.white;
      painter.fillColor = Color.transparent;
      painter.drawRectangle(Point(0, 0), wdt, hgt);
      painter.outlineColor = Color.black;
      painter.drawRectangle(Point(1, 1), wdt-2, hgt-2);
      painter.fillColor = Color.white;
      painter.drawRectangle(Point(2, 2), wdt-4, hgt-4);
      painter.fillColor = Color.transparent;
      foreach (immutable idx, string name; names) {
        Color col, bkcol;
        if (name == detectedGlyph) {
          // highlighted
          col = Color(255, 255, 255);
          //bkcol = rgb2col(0, 0, 255);
          bkcol = Color(0, 100, 0);
        } else {
          col = Color(255, 127, 0);
          bkcol = Color(0, 0, 127);
        }
        if (curptr == idx) bkcol = Color(0, 127, 0);
        foreach (uint gidx; 0..uint.max) {
          auto fg = glib.findGesture(name, gidx);
          if (fg is null) break;
          if (fg is curPattern) { col = Color(255, 255, 0); break; }
        }
        painter.outlineColor = bkcol;
        painter.fillColor = bkcol;
        painter.drawRectangle(Point(2, idx*CharHeight+2), wdt-4, CharHeight);
        painter.outlineColor = col;
        painter.fillColor = Color.transparent;
        drawText(2, idx*CharHeight+2, name);
      }
    }

    painter.outlineColor = Color.black;
    painter.fillColor = Color.black;
    painter.drawRectangle(Point(0, 0), sdwin.width, sdwin.height);

    if (curPattern !is null) drawTemplate(curPattern);
    drawStrokeList(curGlyph);
    if (drawnGlyph.length) drawStroke(drawnGlyph);
    if (yesNoMessage.length > 0) {
      painter.outlineColor = Color(128, 0, 0);
      painter.fillColor = Color(128, 0, 0);
      painter.drawRectangle(Point(0, sdwin.height-CharHeight), sdwin.width, CharHeight);
      painter.outlineColor = Color(255, 255, 0);
      painter.fillColor = Color.transparent;
      drawText(0, sdwin.height-CharHeight, yesNoMessage);
    } else if (editingName) {
      painter.outlineColor = Color(0, 0, 190);
      painter.fillColor = Color(0, 0, 190);
      painter.drawRectangle(Point(0, sdwin.height-CharHeight), sdwin.width, CharHeight);
      painter.outlineColor = Color(255, 127, 0);
      painter.fillColor = Color.transparent;
      drawText(0, sdwin.height-CharHeight, curGlyphName);
      painter.outlineColor = Color(255, 255, 0);
      painter.fillColor = Color(255, 255, 0);
      painter.drawRectangle(Point(CharWidth*cast(int)curGlyphName.length, sdwin.height-CharHeight), CharWidth, CharHeight);
      painter.outlineColor = Color(255, 127, 0);
      painter.fillColor = Color.transparent;
    }
    if (msgAlpha >= 0 && msgText.length) {
      int y = sdwin.height-CharHeight;
      painter.outlineColor = Color(60, 60, 90);
      painter.fillColor = Color(60, 60, 90);
      painter.drawRectangle(Point(0, y), sdwin.width, CharHeight);
      painter.outlineColor = Color(255, 255, 255);
      painter.fillColor = Color.transparent;
      drawText((sdwin.width-CharWidth*cast(int)msgText.length)/2, y, msgText);
      painter.fillColor = Color.transparent;
    }
    if (helpVisible) {
      helpOverlay();
    }
  }
  flushGui();
}


// ////////////////////////////////////////////////////////////////////////// //
int mdown = 0;


int getSelectedGlyph (int x, int y) {
  int wdt = nameMaxLen*CharWidth+4;
  int hgt = cast(int)(glib.knownGestureNames.length*CharHeight+4);
  if (x >= 2 && y >= 2 && x < wdt-4 && y < hgt-4) {
    return cast(int)((y-2)/CharHeight);
  } else {
    return -1;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
void main (string[] args) {
  glib = new DPGestureList();
  glib.load(VFile("zgest.gsl"));
  fixNameMaxLen();
  writefln("%s strokes loaded", glib.knownGestureNames.length);
  //gstLibSave(File("strokes_new.dat", "w"), glib[]);
  sdwin = new SimpleWindow(800, 600, "Protractor Gesture Recognizer test");
  frameChanged();
  sdwin.eventLoop(100,
    // pulse timer
    delegate () {
      updateMsg();
    },
    // mouse events
    delegate (MouseEvent event) {
      switch (event.type) {
        case MouseEventType.buttonPressed:
          if (yesNoMessage.length > 0 || editingName) break;
          if (mdown == 0) {
            if (event.button == MouseButton.left) {
              auto ng = getSelectedGlyph(event.x, event.y);
              if (ng >= 0) {
                auto names = glib.knownGestureNames;
                if (ng < names.length) {
                  curPattern = glib.findGesture(names[ng]);
                  frameChanged();
                }
                return;
              }
            }
            if (event.button == MouseButton.left || event.button == MouseButton.right) {
              mdown = (event.button == MouseButton.left ? 1 : 2);
              if (detectedGlyph.length == 0 && (event.modifierState&ModifierState.ctrl)) {
                // new segment
                if (drawnGlyph.length > 0) {
                  drawnGlyph ~= DPPoint(event.x, event.y, drawnGlyph[$-1].id+1);
                } else {
                  drawnGlyph ~= DPPoint(event.x, event.y, 1);
                }
              } else {
                detectedGlyph = null;
                drawnGlyph.length = 0;
                drawnGlyph ~= DPPoint(event.x, event.y, 1);
              }
              frameChanged();
            }
          }
          break;
        case MouseEventType.buttonReleased:
          if (yesNoMessage.length > 0 || editingName) return;
          if (mdown != 0) {
            if (drawnGlyph.length > 0) {
              if (mdown == 1) {
                if (event.modifierState&ModifierState.ctrl) {
                  // segment end
                } else {
                  auto res = glib.recognize(drawnGlyph);
                  if (res.valid) {
                    detectedGlyph = res.name;
                    showMessage("glyph: '"~detectedGlyph~"'");
                    writeln("glyph: '", detectedGlyph, "'; score: ", res.score);
                  } else {
                    curGlyphName = (curPattern !is null ? curPattern.name : "");
                    editingName = true;
                  }
                }
              }
            } else {
              drawnGlyph = null;
            }
            frameChanged();
          }
          mdown = 0;
          break;
        case MouseEventType.motion:
          if (yesNoMessage.length > 0 || editingName) break;
          if (mdown == 0) {
            auto ng = getSelectedGlyph(event.x, event.y);
            if (ng != curGlyph) {
              curGlyph = ng;
              frameChanged();
            }
          } else if (mdown != 0) {
            if (drawnGlyph.length > 0) {
              drawnGlyph ~= DPPoint(event.x, event.y, drawnGlyph[$-1].id);
            }
            frameChanged();
          }
          break;
        default:
      }
    },
    // keyboard events
    delegate (KeyEvent event) {
      if (!event.pressed && event.key == Key.Ctrl) {
        if (drawnGlyph.length) {
          auto res = glib.recognize(drawnGlyph);
          if (res.valid) {
            detectedGlyph = res.name;
            showMessage("glyph: '"~detectedGlyph~"'");
            writeln("glyph: '", detectedGlyph, "'; score: ", res.score);
          } else {
            curGlyphName = (curPattern !is null ? curPattern.name : "");
            editingName = true;
          }
        }
        return;
      }
      if (!event.pressed) return;
      if (helpVisible) {
        if (event == "Escape" || event == "F1") {
          helpVisible = false;
          frameChanged();
        }
        return;
      }
      if (yesNoMessage.length > 0) {
        if (event == "Escape") {
          yesNoMessage = null;
        } else if (event == "Enter") {
          if (curPattern !is null) glib.removeGesture(curPattern.name);
          detectedGlyph = null;
          curPattern = null;
          yesNoMessage = null;
        }
        frameChanged();
        return;
      }
      if (event == "C-Q") { sdwin.close(); return; }
      if (event == "C-T") { addTestGestures(glib); fixNameMaxLen(); frameChanged(); return; }
      if (event == "F1") {
        helpVisible = true;
        frameChanged();
        return;
      }
      if (event == "F2") {
        glib.save(VFile("strokes.dat", "w"));
        //writefln("%s strokes saved", glib.length);
        frameChanged();
        return;
      }
      if (event == "F3") {
        glib.load(VFile("strokes.dat"));
        fixNameMaxLen();
        //writefln("%s strokes loaded", glib.length);
        detectedGlyph = null;
        curPattern = null;
        drawnGlyph = null;
        frameChanged();
        return;
      }
      if (event == "Delete") {
        if (curPattern !is null) {
          yesNoMessage = "Remove '"~curPattern.name~"'?";
          frameChanged();
          return;
        }
      }
    },
    // characters
    delegate (dchar ch) {
      if (!editingName) return;
      if (ch == 27) { editingName = false; frameChanged(); return; }
      if (ch == 8) {
        if (curGlyphName.length > 0) curGlyphName = curGlyphName[0..$-1];
        frameChanged();
        return;
      }
      if (ch == 25) {
        // C-Y
        curGlyphName = null;
        frameChanged();
        return;
      }
      if (ch == 10 || ch == 13) {
        registerGlyph();
        editingName = false;
        return;
      }
      if (ch >= ' ' && ch < 127) {
        curGlyphName ~= cast(char)ch;
        frameChanged();
        return;
      }
    },
  );
}
