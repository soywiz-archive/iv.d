/*
 * Pixel Graphics Library
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
import iv.sdpy;


void main (string[] args) {
  import std.stdio;

  { import core.runtime : Runtime; Runtime.traceHandlerAllowTrace = true; }

  vlProcessArgs(args);
  vlWidth = 400;
  vlHeight = 300;

  sdpyCloseQueryCB = delegate () {
    sdpyPostQuitMessage();
  };

  sdpyClearOvlCB = delegate () {
    vlOvl.clear(VColor.black);
  };

  sdpyPreDrawCB = delegate () {
    import std.string : format;
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

    //vlOvl.drawTextProp(10, 10, "Text", VColor.rgb(255, 127, 0));
  };

  sdpyFrameCB = delegate () {
  };

  sdpyOnKeyCB = delegate (KeyEvent evt, bool eaten) {
    if (eaten) return;
    if (evt.key == Key.Escape) { sdpyPostQuitMessage(); return; }
  };

  sdpyOnMouseCB = delegate (MouseEvent evt, bool eaten) {
    if (eaten) return;
  };

  sdpyOnCharCB = delegate (dchar ch, bool eaten) {
    if (eaten) return;
  };

  sdpyMainLoop();
}
