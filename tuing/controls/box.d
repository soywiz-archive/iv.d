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
// boxes
module iv.tuing.controls.box;

import iv.eventbus;
import iv.flexlayout;
import iv.strex;
import iv.rawtty2;

import iv.tuing.events;
import iv.tuing.tty;
import iv.tuing.tui;
import iv.tuing.types;
import iv.tuing.controls.window : FuiWindow;


// ////////////////////////////////////////////////////////////////////////// //
public class FuiBox : FuiControl {
  alias onMyEvent = super.onMyEvent;
  this (FuiControl aparent) {
    this.connectListeners();
    super(aparent);
    vertical = true;
  }
}

public class FuiHBox : FuiBox {
  alias onMyEvent = super.onMyEvent;
  this (FuiControl aparent) { this.connectListeners(); super(aparent); horizontal = true; aligning = Align.Stretch; spacing = 1; }
}

public class FuiVBox : FuiBox {
  alias onMyEvent = super.onMyEvent;
  this (FuiControl aparent) { this.connectListeners(); super(aparent); vertical = true; }
}


// ////////////////////////////////////////////////////////////////////////// //
public class FuiPanel : FuiControl {
  alias onMyEvent = super.onMyEvent;

  this (FuiControl aparent, string acaption) {
    this.connectListeners();
    super(aparent);
    caption = acaption;
    vertical = true;
    aligning = Align.Start;
    padding = FuiMargin(1, 1, 1, 1);
  }

  protected override void drawSelf (XtWindow win) {
    win.color = (enabled ? palColor!"def"() : palColor!"disabled"());
    win.frame!true(0, 0, win.width, win.height);
    if (caption.length) {
      win.x0 = win.x0+1;
      win.width = win.width-2;
      win.writeCharsAt(0, 0, cast(int)caption.length+2, ' ');
      if (enabled) win.color = palColor!"title"();
      win.x0 = win.x0+1;
      win.width = win.width-2;
      win.writeStrAt(0, 0, caption);
    }
  }
}

public class FuiHPanel : FuiPanel {
  alias onMyEvent = super.onMyEvent;
  this (FuiControl aparent, string acaption) { this.connectListeners(); super(aparent, acaption); horizontal = true; }
}

public class FuiVPanel : FuiPanel {
  alias onMyEvent = super.onMyEvent;
  this (FuiControl aparent, string acaption) { this.connectListeners(); super(aparent, acaption); vertical = true; }
}


// ////////////////////////////////////////////////////////////////////////// //
// just cosmetix
public class FuiSpan : FuiControl {
  alias onMyEvent = super.onMyEvent;
  this (FuiControl aparent) {
    this.connectListeners();
    super(aparent);
    vertical = true;
    aligning = Align.Start;
    ignoreSpacing = true;
    flex = 1;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
public class FuiHLine : FuiControl {
  alias onMyEvent = super.onMyEvent;

  this (FuiControl aparent) {
    this.connectListeners();
    FuiControl ctl = (aparent !is null ? aparent.lastChild : null);
    if (ctl !is null) ctl.lineBreak = true;
    super(aparent);
    horizontal = true;
    aligning = Align.Stretch;
    minSize.h = maxSize.h = 1;
    lineBreak = true;
    ignoreSpacing = true;
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
