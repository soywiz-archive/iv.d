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
import iv.tuing.ttyeditor : TtyEditor;


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


// ////////////////////////////////////////////////////////////////////////// //
public class EventEditorMessage : Event {
  string msg;
  this (TtyEditor aed, string amsg) { super(aed); msg = amsg; }
  final @property pure nothrow @trusted @nogc {
    inout(TtyEditor) sourceed () inout { return cast(typeof(return))osource; }
  }
}

public class EventEditorQuery : Event {
  this (TtyEditor aed) { super(aed); }
  final @property pure nothrow @trusted @nogc {
    inout(TtyEditor) sourceed () inout { return cast(typeof(return))osource; }
  }
}

// yes, source
public class EventEditorReply : Event {
  this (TtyEditor aed) { super(aed); }
  final @property pure nothrow @trusted @nogc {
    inout(TtyEditor) sourceed () inout { return cast(typeof(return))osource; }
  }
}


// reply: <0: cancel; =0: no; >0: yes
public class EventEditorQueryOverwriteModified : EventEditorQuery { this (TtyEditor aed) { super(aed); } }
public class EventEditorReplyOverwriteModified : EventEditorReply { int res; this (TtyEditor aed, int ares) { super(aed); res = ares; } }

// reply: <0: cancel; =0: no; >0: yes
public class EventEditorQueryReloadModified : EventEditorQuery { this (TtyEditor aed) { super(aed); } }
public class EventEditorReplyReloadModified : EventEditorReply { int res; this (TtyEditor aed, int ares) { super(aed); res = ares; } }

public class EventEditorQueryAutocompletion : EventEditorQuery {
  const(char)[][] list;
  int pos, len;
  FuiPoint pt;
  this (TtyEditor aed, int apos, int alen, FuiPoint apt, const(char)[][] alist) { super(aed); pos = apos; len = alen; pt = apt; list = alist; }
}
public class EventEditorReplyAutocompletion : EventEditorReply {
  const(char)[] res;
  int pos, len;
  this (TtyEditor aed, int apos, int alen, const(char)[] ares) { super(aed); pos = apos; len = alen; res = ares; }
}

public class EventEditorQueryReplacement : EventEditorQuery {
  void* opt; // SROptions
  this (TtyEditor aed, void* aopt) { super(aed); opt = aopt; }
}
public class EventEditorReplyReplacement : EventEditorReply {
  void* opt; // SROptions
  this (TtyEditor aed, void* aopt) { super(aed); opt = aopt; }
}

// show search-and-replace dialog
public class EventEditorQuerySR : EventEditorQuery {
  void* opt; // SROptions
  this (TtyEditor aed, void* aopt) { super(aed); opt = aopt; }
}
public class EventEditorReplySR : EventEditorReply {
  void* opt; // SROptions
  bool cancel;
  this (TtyEditor aed, void* aopt, bool acancel) { super(aed); opt = aopt; cancel = acancel; }
}

public class EventEditorQueryGotoLine : EventEditorQuery {
  this (TtyEditor aed) { super(aed); }
}
public class EventEditorReplyGotoLine : EventEditorReply {
  int line;
  this (TtyEditor aed, int aline) { super(aed); line = aline; }
}

public class EventEditorQueryCodePage : EventEditorQuery {
  int cp;
  this (TtyEditor aed, int acp) { super(aed); cp = acp; }
}
public class EventEditorReplyCodePage : EventEditorReply {
  int cp;
  this (TtyEditor aed, int acp) { super(aed); cp = acp; }
}
