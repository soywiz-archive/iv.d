/* Written by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
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
module iv.sdpyutil;

import arsd.simpledisplay;


// ////////////////////////////////////////////////////////////////////////// //
/// get desktop number for the given window; -1: unknown
public int getWindowDesktop (SimpleWindow sw) {
  static if (UsingSimpledisplayX11) {
    import core.stdc.config;
    if (sw is null || sw.closed) return -1;
    auto dpy = sw.display;
    auto xwin = sw.impl.window;
    auto atomWTF = GetAtom!("_NET_WM_DESKTOP", true)(dpy);
    Atom aType;
    int format;
    c_ulong itemCount;
    c_ulong bytesAfter;
    void* propRes;
    int desktop = -1;
    auto status = XGetWindowProperty(dpy, xwin, atomWTF, 0, 1, /*False*/0, AnyPropertyType, &aType, &format, &itemCount, &bytesAfter, &propRes);
    if (status >= Success) {
      if (propRes !is null) {
        if (itemCount > 0 && format == 32) desktop = *cast(int*)propRes;
        XFree(propRes);
      }
    }
    return desktop;
  } else {
    return -1;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
/// switch to desktop with the given window
public void switchToWindowDesktop(bool doflush=true) (SimpleWindow sw) {
  static if (UsingSimpledisplayX11) {
    if (sw is null || sw.closed) return;
    auto desktop = sw.getWindowDesktop();
    if (desktop < 0) return;
    auto dpy = sw.display;
    XEvent e;
    e.xclient.type = EventType.ClientMessage;
    e.xclient.serial = 0;
    e.xclient.send_event = 1/*True*/;
    e.xclient.message_type = GetAtom!("_NET_CURRENT_DESKTOP", true)(dpy);
    e.xclient.window = RootWindow(dpy, DefaultScreen(dpy));
    e.xclient.format = 32;
    e.xclient.data.l[0] = desktop;
    XSendEvent(dpy, RootWindow(dpy, DefaultScreen(dpy)), false, EventMask.SubstructureRedirectMask|EventMask.SubstructureNotifyMask, &e);
    static if (doflush) flushGui();
  }
}


// ////////////////////////////////////////////////////////////////////////// //
/// switch to the given window
public void switchToWindow(string src="normal") (SimpleWindow sw) if (src == "normal" || src == "pager") {
  static if (UsingSimpledisplayX11) {
    if (sw is null || sw.closed) return;
    switchToWindowDesktop!false(sw);
    auto dpy = sw.display;
    auto xwin = sw.impl.window;
    XEvent e;
    e.xclient.type = EventType.ClientMessage;
    e.xclient.serial = 0;
    e.xclient.send_event = 1/*True*/;
    e.xclient.message_type = GetAtom!("_NET_ACTIVE_WINDOW", true)(dpy);
    e.xclient.window = xwin;
    e.xclient.format = 32;
    static if (src == "pager") {
      e.xclient.data.l[0] = 2; // pretend to be a pager
    } else {
      e.xclient.data.l[0] = 1; // application request
    }
    XSendEvent(dpy, RootWindow(dpy, DefaultScreen(dpy)), false, EventMask.SubstructureRedirectMask|EventMask.SubstructureNotifyMask, &e);
    flushGui();
  }
}


// ////////////////////////////////////////////////////////////////////////// //
/// Get global window coordinates and size. This can be used to show various notifications.
void getWindowRect (SimpleWindow sw, out int x, out int y, out int width, out int height) {
  if (sw is null || sw.closed) { width = 1; height = 1; return; } // 1: just in case
  Window dummyw;
  //XWindowAttributes xwa;
  //XGetWindowAttributes(dpy, nativeHandle, &xwa);
  //XTranslateCoordinates(dpy, nativeHandle, RootWindow(dpy, DefaultScreen(dpy)), xwa.x, xwa.y, &x, &y, &dummyw);
  XTranslateCoordinates(sw.display, sw.impl.window, RootWindow(sw.display, DefaultScreen(sw.display)), x, y, &x, &y, &dummyw);
  width = sw.width;
  height = sw.height;
}


// ////////////////////////////////////////////////////////////////////////// //
public void getWorkAreaRect (out int x, out int y, out int width, out int height) {
  static if (UsingSimpledisplayX11) {
    import core.stdc.config;
    width = 800;
    height = 600;
    auto dpy = XDisplayConnection.get;
    if (dpy is null) return;
    auto root = RootWindow(dpy, DefaultScreen(dpy));
    auto atomWTF = GetAtom!("_NET_WORKAREA", true)(dpy);
    Atom aType;
    int format;
    c_ulong itemCount;
    c_ulong bytesAfter;
    int* propRes;
    auto status = XGetWindowProperty(dpy, root, atomWTF, 0, 4, /*False*/0, AnyPropertyType, &aType, &format, &itemCount, &bytesAfter, cast(void**)&propRes);
    if (status >= Success) {
      if (propRes !is null) {
        x = propRes[0];
        y = propRes[1];
        width = propRes[2];
        height = propRes[3];
        XFree(propRes);
      }
    }
  } else {
    width = 800;
    height = 600;
  }
}
