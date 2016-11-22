/* coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
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
module xmain_fed;

import std.random : uniform;

import iv.glkgi;


void main (string[] args) {
  if (conProcessArgs(args)) while (conProcessQueue()) {}

  //kgiInit(640, 480, "KGI Test", scale2x);
  kgiInit();
  //scope(exit) kgiDeinit();

  kgiSetDefaultCursor();
  kgiShowCursor();

  void buildScreen () {
    cls(0);
    drawCircle(kgiWidth/2, kgiHeight/2, 100, rgbcol(255, 255, 255));
    foreach (immutable _; 0.. 10) {
      drawCircle(uniform(0, kgiWidth), uniform(0, kgiHeight), uniform!"[]"(10, 50), rgbcol(255, 255, 255));
    }
  }

  kgiMotionEvents = true;
  for (;;) {
    auto ev = kgiGetEvent();
    if (ev.isClose) break;
    if (ev.isKey && ev.k.pressed && ev.k.key == Key.Escape) break;
    if (ev.isKey && ev.k.pressed && ev.k.key == Key.R) { buildScreen(); continue; }
    if (ev.isKey && ev.k.pressed && ev.k.key == Key.C) { drawCircle(uniform(0, kgiWidth), uniform(0, kgiHeight), uniform!"[]"(10, 50), rgbcol(255, 255, 255)); continue; }
    if (ev.isKey && ev.k.pressed) {
      import std.random : uniform;
      drawStr(uniform!"[]"(0, kgiWidth), uniform!"[]"(0, kgiHeight), "Boo!", rgbcol(255, 127, 0));
    }
    if (ev.isMouse && ev.m.type == MouseEventType.buttonPressed && ev.m.button == MouseButton.left) {
      fillCircle(ev.m.x, ev.m.y, 4, rgbcol(255, 255, 0, 127));
    }
    if (ev.isMouse && ev.m.type == MouseEventType.buttonPressed && ev.m.button == MouseButton.right) {
      floodFillEx(ev.m.x, ev.m.y,
        // isBorder
        (int x, int y) {
          return (getPixel(x, y) == rgbcol(255, 255, 255));
        },
        // patColor
        (int x, int y) {
          return rgbcol(255, 127, 0, 127);
        },
      );
    }
    if (ev.isMouse && ev.m.type == MouseEventType.motion && ev.m.modifierState&ModifierState.leftButtonDown) {
      fillCircle(ev.m.x, ev.m.y, 4, rgbcol(255, 255, 255, 127));
    }
    //conwriteln(ev.type);
  }
}
