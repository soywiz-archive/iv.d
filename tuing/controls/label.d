/* Invisible Vector Library
 * simple FlexBox-based TUI engine
 *
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
// label
module iv.tuing.controls.label /*is aliced*/;

import iv.alice;
import iv.eventbus;
import iv.flexlayout;
import iv.strex;
import iv.rawtty;

import iv.tuing.events;
import iv.tuing.tty;
import iv.tuing.tui;
import iv.tuing.types;


// ////////////////////////////////////////////////////////////////////////// //
public class FuiLabel : FuiControl {
  alias onMyEvent = super.onMyEvent;

  FuiControl dest; // this control will be activated by the label...
  string destid; // ...or the control with this id

  this (FuiControl aparent, string atext, FuiControl adest=null) {
    this.connectListeners();
    super(aparent);
    doInit(atext);
    dest = adest;
  }

  this (FuiControl aparent, string atext, string adestid) {
    this.connectListeners();
    super(aparent);
    doInit(atext);
    destid = adestid;
  }

  final void doInit (string atext) {
    caption = atext;
    minSize.w = XtWindow.hotStrLen(atext);
    horizontal = true;
    aligning = Align.Start;
    minSize.h = maxSize.h = 1;
    hotkeyed = true;
  }

  override void doAction () {
    if (onAction !is null) { onAction(this); return; }
    FuiControl dcc = dest;
    if (dcc is null) dcc = toplevel[destid];
    if (dcc !is null) {
      if (auto desk = getDesk) desk.switchFocusTo(dcc);
    }
  }

  protected override void drawSelf (XtWindow win) {
    win.color = (focused ? palColor!"sel"() : palColor!"def"());
    win.fill(0, 0, win.width, win.height);
    win.writeHotStrAt(0, 0, win.width, caption, (focused ? palColor!"hotsel"() : palColor!"hot"()), win.Align.Right, hotkeyed);
  }

  void onMyEvent (FuiEventKey evt) {
    if (evt.key == "Space") { evt.eat(); doAction(); return; }
    if (tryHotKey(evt.key)) { evt.eat(); doAction(); return; }
  }
}
