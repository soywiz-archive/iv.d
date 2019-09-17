/*
 * Pixel Graphics Library
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
import iv.sdpy;

import iv.writer;


void main (string[] args) {
  import std.stdio;

  { import core.runtime : Runtime; Runtime.traceHandlerAllowTrace = true; }

  vlProcessArgs(args);
  vlWidth = 400;
  vlHeight = 300;

  auto chr = new BgiChr("chrfonts/v1/thin.chr");
  writeln("baseline: ", chr.baseline, "; ascent: ", chr.ascent, "; descent: ", chr.descent, "; height: ", chr.height);

  int gbx = 3, gby = 3;
  bool gbvis = false;

  auto gb = GfxBuf(92, 48);
  gb.clear(VColor.green);
  gb.region.punch(0, 0);
  gb.region.punch(gb.width-1, 0);
  gb.region.punch(0, gb.height-1);
  gb.region.punch(gb.width-1, gb.height-1);

  sdpyCloseQueryCB = delegate () {
    sdpyPostQuitMessage();
  };

  sdpyClearVScrCB = delegate () {
    auto vlOvl = GfxBuf.vlVScrBuf;
    vlOvl.clear(VColor.black);
  };

  sdpyPreDrawCB = delegate () {
    import std.string : format;

    auto vlOvl = GfxBuf.vlVScrBuf;

    vlOvl.drawText(10, 10, "Text!", VColor.rgb(255, 0, 0));

    auto s = "%03s,%03s".format(sdpyMouseX, sdpyMouseY);
    vlOvl.drawText(10, 20, s, VColor.rgb(255, 0, 0));

    {
      char[3] buf = ' ';
      if (sdpyMouseButts&SdpyButtonDownLeft) buf[0] = 'L';
      if (sdpyMouseButts&SdpyButtonDownMiddle) buf[1] = 'M';
      if (sdpyMouseButts&SdpyButtonDownRight) buf[2] = 'R';
      vlOvl.drawText(10, 30, buf, VColor.rgb(255, 0, 0));
    }

    {
      char[4] buf = ' ';
      if (sdpyKeyMods&SdpyKeyCtrlDown) buf[0] = 'C';
      if (sdpyKeyMods&SdpyKeyAltDown) buf[1] = 'A';
      if (sdpyKeyMods&SdpyKeyShiftDown) buf[2] = 'S';
      if (sdpyKeyMods&SdpyKeyMetaDown) buf[3] = 'M';
      vlOvl.drawText(10, 40, buf, VColor.rgb(255, 0, 0));
    }

    int cy = 60;
    chr.drawText(vlOvl, 10, cy, "Hello from BGI!", VColor.rgb(255, 255, 0));
    vlOvl.hline(0, cy, 400, VColor.rgb(255, 0, 0));
    vlOvl.hline(0, cy-chr.height, 400, VColor.rgb(255, 127, 0));
    vlOvl.hline(0, cy-chr.baseline, 400, VColor.rgb(0, 255, 0));
    vlOvl.hline(0, cy-chr.ascent, 400, VColor.rgb(0, 127, 0));
    vlOvl.hline(0, cy-chr.descent, 400, VColor.rgb(127, 127, 0));

    foreach (int dy; 0..16) {
      foreach (int dx; 0..16) {
        int x = dx*14+4;
        int y = dy*14+cy;
        chr.drawChar(vlOvl, x, y, cast(char)(dy*16+dx), VColor.white, 1);
      }
    }

    //vlOvl.drawTextProp(10, 10, "Text", VColor.rgb(255, 127, 0));
  };

  sdpyPostDrawCB = delegate () {
    if (gbvis) gb.blitToVScr(gbx, gby);
  };

  sdpyFrameCB = delegate () {
  };

  sdpyOnKeyCB = delegate (KeyEvent evt, bool active) {
    if (!active) return;
    if (evt.key == Key.Escape) { sdpyPostQuitMessage(); return; }
    if (!evt.pressed) return;
    if (!gbvis) return;
    switch (evt.key) with (Key) {
      case Left: gbx -= 1; break;
      case Right: gbx += 1; break;
      case Up: gby -= 1; break;
      case Down: gby += 1; break;
      default:
    }
  };

  sdpyOnMouseCB = delegate (MouseEvent evt, bool active) {
  };

  sdpyOnCharCB = delegate (dchar ch, bool active) {
    if (ch == ' ') gbvis = !gbvis;
  };

  sdpyMainLoop();
}
