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
module iv.tuing.events /*is aliced*/;

import iv.alice;
import iv.eventbus;
import iv.flexlayout : FuiPoint;
import iv.rawtty : TtyEvent;

import iv.tuing.controls.button : FuiCheckBox, FuiRadio;
import iv.tuing.controls.listbox : FuiListBox;
import iv.tuing.controls.window : FuiDeskWindow;
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

// ////////////////////////////////////////////////////////////////////////// //
// broadcast this event to stop event loop
public class FuiEventQuit : FuiEvent { this () {} }


// ////////////////////////////////////////////////////////////////////////// //
// post this event to close current window; `ares` is the control that caused it; may be null
public class FuiEventClose : FuiEvent {
  FuiControl res;
  this (FuiDeskWindow awin, FuiControl ares=null) { super(awin); res = ares; }
  final @property pure nothrow @trusted @nogc {
    inout(FuiDeskWindow) win () inout { return cast(typeof(return))osource; }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
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


// ////////////////////////////////////////////////////////////////////////// //
// all other rawtty events
public class FuiEventKey : FuiEvent {
  TtyEvent key;
  this (FuiControl adest, TtyEvent akey) { key = akey; super(null, adest); }
}

// mouse clicks and doubleclicks
public class FuiEventAnyClick : FuiEvent {
  FuiPoint pt;
  TtyEvent.MButton bt;
  this (FuiControl adest, FuiPoint apt, TtyEvent.MButton abt) { super(null, adest); pt = apt; bt = abt; }
  final @property const pure nothrow @trusted @nogc {
    int bidx () { return (bt-TtyEvent.MButton.First); }
    bool left () { return (bt == TtyEvent.MButton.Left); }
    bool right () { return (bt == TtyEvent.MButton.Right); }
    bool middle () { return (bt == TtyEvent.MButton.Middle); }
    bool wheelup () { return (bt == TtyEvent.MButton.WheelUp); }
    bool wheeldown () { return (bt == TtyEvent.MButton.WheelDown); }
  }
}
public class FuiEventClick : FuiEventAnyClick { this (FuiControl adest, FuiPoint apt, TtyEvent.MButton abt) { super(adest, apt, abt); } }
public class FuiEventDouble : FuiEventAnyClick { this (FuiControl adest, FuiPoint apt, TtyEvent.MButton abt) { super(adest, apt, abt); } }


// ////////////////////////////////////////////////////////////////////////// //
public class FuiEventCheckBoxChanged : FuiEvent {
  string gid; // group id
  bool val; // new value
  this (FuiCheckBox abt, string agid, bool aval) { super(abt); gid = agid; val = aval; }
  final @property pure nothrow @trusted @nogc {
    inout(FuiCheckBox) bt () inout { return cast(typeof(return))osource; }
  }
}

public class FuiEventRadioChanged : FuiEvent {
  string gid; // group id
  int val; // new value
  this (FuiRadio abt, string agid, int aval) { super(abt); gid = agid; val = aval; }
  final @property pure nothrow @trusted @nogc {
    inout(FuiRadio) bt () inout { return cast(typeof(return))osource; }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
public class FuiEventWinFocusNextPrev : FuiEvent {
  this (FuiDeskWindow awin) { super(awin); }
  final @property pure nothrow @trusted @nogc {
    inout(FuiDeskWindow) sourcewin () inout { return cast(typeof(return))osource; }
  }
}

public class FuiEventWinFocusNext : FuiEventWinFocusNextPrev { this (FuiDeskWindow awin) { super(awin); } }
public class FuiEventWinFocusPrev : FuiEventWinFocusNextPrev { this (FuiDeskWindow awin) { super(awin); } }


// ////////////////////////////////////////////////////////////////////////// //
// sent when control wants to show history selection (broadcast)
// control should not block (event handler will take care of that)
public class FuiEventHistoryQuery : FuiEvent { this (FuiControl asrc) { super(asrc); } }

// control should update itself with this new string
// this even may be omited if history manager did all the work itself
public class FuiEventHistoryReply : FuiEvent {
  const(char)[] text;
  this (FuiControl adest, const(char)[] atext) { super(null, adest); text = atext; }
}


// ////////////////////////////////////////////////////////////////////////// //
public class FuiEventListBoxEvent : FuiEvent {
  this (FuiListBox alb) { super(alb); }
  final @property pure nothrow @trusted @nogc {
    inout(FuiListBox) sourcelb () inout { return cast(typeof(return))osource; }
  }
}

public class FuiEventListBoxCurIndexChanged : FuiEventListBoxEvent {
  int idx; // new index (can be negative)
  this (FuiListBox alb, int aidx) { super(alb); idx = aidx; }
}

public class FuiEventListBoxMarkChanged : FuiEventListBoxEvent {
  int idx; // item index
  this (FuiListBox alb, int aidx) { super(alb); idx = aidx; }
}


// ////////////////////////////////////////////////////////////////////////// //
public class EventEditorEvent : Event {
  string msg;
  this (TtyEditor aed) { super(aed); }
  final @property pure nothrow @trusted @nogc {
    inout(TtyEditor) sourceed () inout { return cast(typeof(return))osource; }
    inout(TtyEditor) ed () inout { return cast(typeof(return))osource; }
  }
}

public class EventEditorMessage : EventEditorEvent {
  string msg;
  this (TtyEditor aed, string amsg) { super(aed); msg = amsg; }
}

public class EventEditorQuery : EventEditorEvent {
  this (TtyEditor aed) { super(aed); }
}

// yes, source
public class EventEditorReply : EventEditorEvent {
  this (TtyEditor aed) { super(aed); }
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
  bool proceed;
  this (TtyEditor aed, void* aopt, bool aproceed) { super(aed); opt = aopt; proceed = aproceed; }
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

public class EventEditorQueryTabSize : EventEditorQuery {
  int tabsize;
  this (TtyEditor aed, int atabsize) { super(aed); tabsize = atabsize; }
}
public class EventEditorReplyTabSize : EventEditorReply {
  int tabsize;
  this (TtyEditor aed, int atabsize) { super(aed); tabsize = atabsize; }
}
