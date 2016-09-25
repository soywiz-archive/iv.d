/* Invisible Vector Library
 * simple FlexBox-based TUI engine
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
// horizontal line
module iv.tuing.controls.hline;

import iv.strex;
import iv.rawtty2;

import iv.tuing.eventbus;
import iv.tuing.events;
import iv.tuing.layout;
import iv.tuing.tty;
import iv.tuing.tui;
import iv.tuing.types;


// ////////////////////////////////////////////////////////////////////////// //
public class FuiHLine : FuiControl {
  alias onMyEvent = super.onMyEvent;

  this (FuiControl aparent) {
    this.connectListeners();
    FuiControl ctl = (aparent !is null ? aparent.lastChild : null);
    if (ctl !is null) ctl.lp.lineBreak = true;
    super(aparent);
    lp.orientation = lp.Orientation.Horizontal;
    lp.aligning = lp.Align.Stretch;
    lp.minSize.h = lp.maxSize.h = 1;
    lp.lineBreak = true;
    lp.ignoreSpacing = true;
  }

  protected override void drawSelfPre (XtWindow win) {
    win.color = palColor!"def"();
    if (auto w = cast(FuiWindow)parent) {
      final switch (w.frame) {
        case FuiWindow.Frame.Normal:
          win.x0 = win.x0-2;
          win.width = win.width+4;
          break;
        case FuiWindow.Frame.Small:
          win.x0 = win.x0-1;
          win.width = win.width+1;
          break;
        case FuiWindow.Frame.None: break;
      }
    }
    win.hline(0, 0, win.width);
  }

  protected override void drawSelf (XtWindow win) {}
}
