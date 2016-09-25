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
// button
module iv.tuing.controls.button;

import iv.strex;
import iv.rawtty2;

import iv.tuing.eventbus;
import iv.tuing.events;
import iv.tuing.layout;
import iv.tuing.tty;
import iv.tuing.tui;
import iv.tuing.types;


// ////////////////////////////////////////////////////////////////////////// //
public class FuiButton : FuiControl {
  alias onMyEvent = super.onMyEvent;

  this (FuiControl aparent, string atext) {
    this.connectListeners();
    super(aparent);
    caption = atext;
    minSize.w = XtWindow.hotStrLen(atext)+4;
    horizontal = true;
    aligning = Align.Start;
    minSize.h = maxSize.h = 1;
    canBeFocused = true;
    hotkeyed = true;
    acceptClick(TtyEvent.MButton.Left);
  }

  override void doAction () {
    if (canBeFocused) {
      if (auto desk = getDesk) desk.switchFocusTo(this, false);
    }
    if (onAction !is null) { onAction(this); return; }
    (new FuiEventClose(toplevel, this)).post;
  }

  protected override void drawSelf (XtWindow win) {
    win.color = (focused ? palColor!"sel"() : palColor!"def"());
    win.fill(0, 0, win.width, win.height);
    if (defctl) {
      win.writeCharAt(0, 0, '<');
      win.writeCharAt(win.width-1, 0, '>');
    } else if (escctl) {
      win.writeCharAt(0, 0, '{');
      win.writeCharAt(win.width-1, 0, '}');
    } else {
      win.writeCharAt(0, 0, '[');
      win.writeCharAt(win.width-1, 0, ']');
    }
    win.writeHotStrAt(2, 0, win.width-4, caption, (focused ? palColor!"hotsel"() : palColor!"hot"()), win.Align.Center, hotkeyed, focused);
  }

  void onMyEvent (FuiEventKey evt) {
    if (evt.key == "Space") { evt.eat(); doAction(); return; }
    if (tryHotKey(evt.key)) { evt.eat(); doAction(); return; }
  }
}
