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
module iv.tuing.events;

import iv.rawtty2 : TtyEvent;
import iv.tuing.controls.window : FuiWindow;
import iv.tuing.eventbus;
import iv.tuing.layout : FuiPoint;
import iv.tuing.tui : FuiControl;


// ////////////////////////////////////////////////////////////////////////// //
public class FuiEvent : Event {
  this () { super(); }
  this (FuiControl asrc) { super(asrc); }
  this (FuiControl asrc, FuiControl adest) { super(asrc, adest); }

  final @property pure nothrow @trusted @nogc {
    inout(FuiControl) sourcectl () inout { return cast(typeof(return))osource; }
    inout(FuiControl) destctl () inout { return cast(typeof(return))odest; }
  }
}

public class FuiEventQuit : FuiEvent { this () {} }

public class FuiEventClose : FuiEvent {
  FuiControl res;
  this (FuiControl asrc, FuiControl ares) { super(asrc, null); res = ares; }
}


// can be unbalanced
public class FuiEventHover : FuiEvent { this (FuiControl adest) { super(null, adest); } }
public class FuiEventEnter : FuiEventHover { this (FuiControl adest) { super(adest); } }
public class FuiEventLeave : FuiEventHover { this (FuiControl adest) { super(adest); } }

// can be unbalanced
public class FuiEventFocusBlur : FuiEvent { this (FuiControl adest) { super(null, adest); } }
public class FuiEventFocus : FuiEventFocusBlur { this (FuiControl adest) { super(adest); } }
public class FuiEventBlur : FuiEventFocusBlur { this (FuiControl adest) { super(adest); } }

// "active" means "some mouse button pressed, but not released"; can be unbalanced
public class FuiEventActiveStateChanged : FuiEvent { this (FuiControl adest) { super(null, adest); } }
public class FuiEventActive : FuiEventActiveStateChanged { this (FuiControl adest) { super(adest); } }
public class FuiEventInactive : FuiEventActiveStateChanged { this (FuiControl adest) { super(adest); } }

// all other rawtty2 events
public class FuiEventKey : FuiEvent {
  TtyEvent key;
  this (FuiControl adest, TtyEvent akey) { key = akey; super(null, adest); }
}

// mouse clicks and doubleclicks
public class FuiEventAnyClick : FuiEvent {
  FuiPoint pt;
  this (FuiControl adest, FuiPoint apt) { super(null, adest); pt = apt; }
}
public class FuiEventClick : FuiEventAnyClick { this (FuiControl adest, FuiPoint apt) { super(adest, apt); } }
public class FuiEventDouble : FuiEventAnyClick { this (FuiControl adest, FuiPoint apt) { super(adest, apt); } }


// ////////////////////////////////////////////////////////////////////////// //
public class FuiEventWinFocusNextPrev : FuiEvent {
  this (FuiWindow awin) { super(awin); }
  final @property pure nothrow @trusted @nogc {
    inout(FuiWindow) sourcewin () inout { return cast(typeof(return))osource; }
  }
}

public class FuiEventWinFocusNext : FuiEventWinFocusNextPrev { this (FuiWindow awin) { super(awin); } }
public class FuiEventWinFocusPrev : FuiEventWinFocusNextPrev { this (FuiWindow awin) { super(awin); } }
