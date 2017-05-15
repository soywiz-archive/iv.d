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
module iv.sdpyutil is aliced;

import arsd.color;
import arsd.simpledisplay;

//version = krc_debug;


// ////////////////////////////////////////////////////////////////////////// //
public bool sdpyHasXShm () {
  static if (UsingSimpledisplayX11) {
    __gshared int xshmAvailable = -1;
    if (xshmAvailable < 0) {
      int i1, i2, i3;
      xshmAvailable = (XQueryExtension(XDisplayConnection.get(), "MIT-SHM", &i1, &i2, &i3) != 0 ? 1 : 0);
    }
    return (xshmAvailable > 0);
  } else {
    return false;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
/// get desktop number for the given window; -1: unknown
public int getWindowDesktop (SimpleWindow sw) {
  static if (UsingSimpledisplayX11) {
    import core.stdc.config;
    if (sw is null || sw.closed) return -1;
    auto dpy = sw.impl.display;
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
    auto dpy = sw.impl.display;
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
    auto dpy = sw.impl.display;
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
  XTranslateCoordinates(sw.impl.display, sw.impl.window, RootWindow(sw.impl.display, DefaultScreen(sw.impl.display)), x, y, &x, &y, &dummyw);
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


// ////////////////////////////////////////////////////////////////////////// //
enum _NET_WM_MOVERESIZE_SIZE_TOPLEFT = 0;
enum _NET_WM_MOVERESIZE_SIZE_TOP = 1;
enum _NET_WM_MOVERESIZE_SIZE_TOPRIGHT = 2;
enum _NET_WM_MOVERESIZE_SIZE_RIGHT = 3;
enum _NET_WM_MOVERESIZE_SIZE_BOTTOMRIGHT = 4;
enum _NET_WM_MOVERESIZE_SIZE_BOTTOM = 5;
enum _NET_WM_MOVERESIZE_SIZE_BOTTOMLEFT = 6;
enum _NET_WM_MOVERESIZE_SIZE_LEFT = 7;
enum _NET_WM_MOVERESIZE_MOVE = 8; /* movement only */
enum _NET_WM_MOVERESIZE_SIZE_KEYBOARD = 9; /* size via keyboard */
enum _NET_WM_MOVERESIZE_MOVE_KEYBOARD = 10; /* move via keyboard */
enum _NET_WM_MOVERESIZE_CANCEL = 11; /* cancel operation */


public void wmInitiateMoving (SimpleWindow sw, int localx, int localy) {
  static if (UsingSimpledisplayX11) {
    if (sw is null || sw.closed || sw.hidden) return;
    Window dummyw;
    auto dpy = sw.impl.display;
    auto xwin = sw.impl.window;
    auto root = RootWindow(dpy, DefaultScreen(dpy));
    // convert local to global
    //{ import core.stdc.stdio; printf("local: %d,%d\n", localx, localy); }
    XTranslateCoordinates(dpy, xwin, root, localx, localy, &localx, &localy, &dummyw);
    //{ import core.stdc.stdio; printf("global: %d,%d\n", localx, localy); }
    // send event
    XEvent e;
    e.xclient.type = EventType.ClientMessage;
    e.xclient.serial = 0;
    e.xclient.send_event = 1/*True*/;
    e.xclient.message_type = GetAtom!("_NET_WM_MOVERESIZE", true)(dpy);
    e.xclient.window = xwin;
    e.xclient.format = 32;
    e.xclient.data.l[0] = localx; // root_x
    e.xclient.data.l[1] = localy; // root_y
    e.xclient.data.l[2] = _NET_WM_MOVERESIZE_MOVE;
    e.xclient.data.l[3] = 0; // left button
    e.xclient.data.l[4] = 1; // application request
    XSendEvent(dpy, root, false, EventMask.SubstructureRedirectMask|EventMask.SubstructureNotifyMask, &e);
    flushGui();
  }
}


public void wmCancelMoving (SimpleWindow sw, int localx, int localy) {
  static if (UsingSimpledisplayX11) {
    if (sw is null || sw.closed || sw.hidden) return;
    Window dummyw;
    auto dpy = sw.impl.display;
    auto xwin = sw.impl.window;
    auto root = RootWindow(dpy, DefaultScreen(dpy));
    // convert local to global
    XTranslateCoordinates(dpy, xwin, root, localx, localy, &localx, &localy, &dummyw);
    // send event
    XEvent e;
    e.xclient.type = EventType.ClientMessage;
    e.xclient.serial = 0;
    e.xclient.send_event = 1/*True*/;
    e.xclient.message_type = GetAtom!("_NET_WM_MOVERESIZE", true)(dpy);
    e.xclient.window = xwin;
    e.xclient.format = 32;
    e.xclient.data.l[0] = localx; // root_x
    e.xclient.data.l[1] = localy; // root_y
    e.xclient.data.l[2] = _NET_WM_MOVERESIZE_CANCEL;
    e.xclient.data.l[3] = 0; // left button
    e.xclient.data.l[4] = 1; // application request
    XSendEvent(dpy, root, false, EventMask.SubstructureRedirectMask|EventMask.SubstructureNotifyMask, &e);
    flushGui();
  }
}


// ////////////////////////////////////////////////////////////////////////// //
public struct XRefCounted(T) if (is(T == struct)) {
private:
  usize intrp__;

private:
  static void doIncRef (usize ox) nothrow @trusted @nogc {
    pragma(inline, true);
    if (ox) {
      *cast(uint*)(ox-uint.sizeof) += 1;
      version(krc_debug) { import core.stdc.stdio : printf; printf("doIncRef for 0x%08x (%u)\n", cast(uint)ox, *cast(uint*)(ox-uint.sizeof)); }
    }
  }

  static void doDecRef() (ref usize ox) {
    if (ox) {
      version(krc_debug) { import core.stdc.stdio : printf; printf("doDecRef for 0x%08x (%u)\n", cast(uint)ox, *cast(uint*)(ox-uint.sizeof)); }
      if ((*cast(uint*)(ox-uint.sizeof) -= 1) == 0) {
        // kill and free
        scope(exit) {
          import core.stdc.stdlib : free;
          import core.memory : GC;

          version(krc_debug) { import core.stdc.stdio : printf; printf("CG CLEANUP FOR WRAPPER 0x%08x\n", cast(uint)ox); }
          version(krc_debug) import core.stdc.stdio : printf;
          void* mem = cast(void*)ox;
          version(krc_debug) { import core.stdc.stdio : printf; printf("DESTROYING WRAPPER 0x%08x\n", cast(uint)mem); }
          enum instSize = T.sizeof;
          auto pbm = __traits(getPointerBitmap, T);
          version(krc_debug) printf("[%.*s]: size=%u (%u) (%u)\n", cast(uint)T.stringof.length, T.stringof.ptr, cast(uint)pbm[0], cast(uint)instSize, cast(uint)(pbm[0]/usize.sizeof));
          immutable(ubyte)* p = cast(immutable(ubyte)*)(pbm.ptr+1);
          usize bitnum = 0;
          immutable end = pbm[0]/usize.sizeof;
          while (bitnum < end) {
            if (p[bitnum/8]&(1U<<(bitnum%8))) {
              usize len = 1;
              while (bitnum+len < end && (p[(bitnum+len)/8]&(1U<<((bitnum+len)%8))) != 0) ++len;
              version(krc_debug) printf("  #%u (%u)\n", cast(uint)(bitnum*usize.sizeof), cast(uint)len);
              GC.removeRange((cast(usize*)mem)+bitnum);
              bitnum += len;
            } else {
              ++bitnum;
            }
          }

          free(cast(void*)(ox-uint.sizeof));
          ox = 0;
        }
        (*cast(T*)ox).destroy;
      }
    }
  }

public:
  this(A...) (auto ref A args) {
    intrp__ = newOx!T(args);
  }

  this() (auto ref typeof(this) src) nothrow @trusted @nogc {
    intrp__ = src.intrp__;
    doIncRef(intrp__);
  }

  ~this () { doDecRef(intrp__); }

  this (this) nothrow @trusted @nogc { doIncRef(intrp__); }

  void opAssign() (typeof(this) src) {
    if (!intrp__ && !src.intrp__) return;
    version(krc_debug) { import core.stdc.stdio : printf; printf("***OPASSIGN(0x%08x -> 0x%08x)\n", cast(void*)src.intrp__, cast(void*)intrp__); }
    if (intrp__) {
      // assigning to non-empty
      if (src.intrp__) {
        // both streams are active
        if (intrp__ == src.intrp__) return; // nothing to do
        auto oldo = intrp__;
        auto newo = src.intrp__;
        // first increase rc for new object
        doIncRef(newo);
        // replace object for this
        intrp__ = newo;
        // release old object
        doDecRef(oldo);
      } else {
        // just close this one
        scope(exit) intrp__ = 0;
        doDecRef(intrp__);
      }
    } else if (src.intrp__) {
      // this is empty, but other is not; easy deal
      intrp__ = src.intrp__;
      doIncRef(intrp__);
    }
  }

  usize toHash () const pure nothrow @safe @nogc { pragma(inline, true); return intrp__; } // yeah, so simple
  bool opEquals() (auto ref typeof(this) s) const { pragma(inline, true); return (intrp__ == s.intrp__); }

  @property bool hasObject () const pure nothrow @trusted @nogc { pragma(inline, true); return (intrp__ != 0); }

  @property inout(T)* intr_ () inout pure nothrow @trusted @nogc { pragma(inline, true); return cast(typeof(return))intrp__; }

  // hack!
  static if (__traits(compiles, ((){T s; bool v = s.valid;}))) {
    @property bool valid () const nothrow @trusted @nogc { pragma(inline, true); return (intrp__ ? intr_.valid : false); }
  }

  alias intr_ this;

static private:
  usize newOx (CT, A...) (auto ref A args) if (is(CT == struct)) {
    import core.exception : onOutOfMemoryErrorNoGC;
    import core.memory : GC;
    import core.stdc.stdlib : malloc, free;
    import core.stdc.string : memset;
    import std.conv : emplace;
    enum instSize = CT.sizeof;
    // let's hope that malloc() aligns returned memory right
    auto memx = malloc(instSize+uint.sizeof);
    if (memx is null) onOutOfMemoryErrorNoGC(); // oops
    scope(failure) free(memx);
    memset(memx, 0, instSize+uint.sizeof);
    *cast(uint*)memx = 1;
    auto mem = memx+uint.sizeof;
    emplace!CT(mem[0..instSize], args);

    version(krc_debug) import core.stdc.stdio : printf;
    auto pbm = __traits(getPointerBitmap, CT);
    version(krc_debug) printf("[%.*s]: size=%u (%u) (%u)\n", cast(uint)CT.stringof.length, CT.stringof.ptr, cast(uint)pbm[0], cast(uint)instSize, cast(uint)(pbm[0]/usize.sizeof));
    immutable(ubyte)* p = cast(immutable(ubyte)*)(pbm.ptr+1);
    usize bitnum = 0;
    immutable end = pbm[0]/usize.sizeof;
    while (bitnum < end) {
      if (p[bitnum/8]&(1U<<(bitnum%8))) {
        usize len = 1;
        while (bitnum+len < end && (p[(bitnum+len)/8]&(1U<<((bitnum+len)%8))) != 0) ++len;
        version(krc_debug) printf("  #%u (%u)\n", cast(uint)(bitnum*usize.sizeof), cast(uint)len);
        GC.addRange((cast(usize*)mem)+bitnum, usize.sizeof*len);
        bitnum += len;
      } else {
        ++bitnum;
      }
    }
    version(krc_debug) { import core.stdc.stdio : printf; printf("CREATED WRAPPER 0x%08x\n", mem); }
    return cast(usize)mem;
  }
}


static if (UsingSimpledisplayX11) {
// ////////////////////////////////////////////////////////////////////////// //
// for X11 we will keep all XShm-allocated images in this list, so we can free 'em on connection closing.
// we'll use glibc malloc()/free(), 'cause `unregisterImage()` can be called from object dtor.
private struct XShmSeg {
private:
  __gshared usize headp = 0, tailp = 0;

  static @property XShmSeg* head () nothrow @trusted @nogc { pragma(inline, true); return cast(XShmSeg*)headp; }
  static @property void head (XShmSeg* v) nothrow @trusted @nogc { pragma(inline, true); headp = cast(usize)v; }

  static @property XShmSeg* tail () nothrow @trusted @nogc { pragma(inline, true); return cast(XShmSeg*)tailp; }
  static @property void tail (XShmSeg* v) nothrow @trusted @nogc { pragma(inline, true); tailp = cast(usize)v; }

private:
  usize segp; // XShmSegmentInfo*; hide it from GC
  usize prevp; // next link; hide it from GC
  usize nextp; // next link; hide it from GC

private:
  @property bool valid () const pure nothrow @trusted @nogc { pragma(inline, true); return (segp != 0); }

  @property XShmSeg* next () pure nothrow @trusted @nogc { pragma(inline, true); return cast(XShmSeg*)nextp; }
  @property void next (XShmSeg* v) pure nothrow @trusted @nogc { pragma(inline, true); nextp = cast(usize)v; }

  @property XShmSeg* prev () pure nothrow @trusted @nogc { pragma(inline, true); return cast(XShmSeg*)prevp; }
  @property void prev (XShmSeg* v) pure nothrow @trusted @nogc { pragma(inline, true); prevp = cast(usize)v; }

  @property XShmSegmentInfo* seg () pure nothrow @trusted @nogc { pragma(inline, true); return cast(XShmSegmentInfo*)segp; }
  @property void seg (XShmSegmentInfo* v) pure nothrow @trusted @nogc { pragma(inline, true); segp = cast(usize)v; }

static:
  XShmSeg* alloc () nothrow @trusted @nogc {
    import core.stdc.stdlib : malloc, free;
    XShmSeg* res = cast(XShmSeg*)malloc(XShmSeg.sizeof);
    if (res !is null) {
      res.seg = cast(XShmSegmentInfo*)malloc(XShmSegmentInfo.sizeof);
      if (res.seg is null) { free(res); return null; }
      res.prev = tail;
      res.next = null;
      if (tail !is null) tail.next = res; else { assert(head is null); head = res; }
      tail = res;
    }
    return res;
  }

  void free (XShmSeg* seg, bool unregister) {
    if (seg !is null) {
      //{ import core.stdc.stdio; printf("00: freeing...\n"); }
      import core.stdc.stdlib : free;
      if (seg.prev !is null) seg.prev.next = seg.next; else { assert(head is seg); head = head.next; if (head !is null) head.prev = null; }
      if (seg.next !is null) seg.next.prev = seg.prev; else { assert(tail is seg); tail = tail.prev; if (tail !is null) tail.next = null; }
      if (seg.seg) {
        if (unregister) {
          //{ import core.stdc.stdio; printf("00: freeing-unreg...\n"); }
          shmdt(seg.seg.shmaddr);
          shmctl(seg.seg.shmid, IPC_RMID, null);
        }
        free(seg.seg);
      }
      free(seg);
    }
  }

  void freeList () {
    import core.stdc.stdlib : free;
    while (head !is null) {
      //{ import core.stdc.stdio; printf("01: freeing...\n"); }
      if (head.seg) {
        //{ import core.stdc.stdio; printf("01: freeing-unreg...\n"); }
        shmdt(head.seg.shmaddr);
        shmctl(head.seg.shmid, IPC_RMID, null);
        free(head.seg);
      }
      auto p = head;
      head = head.next;
      free(p);
    }
    tail = null;
  }

  shared static ~this () { freeList(); }
}


// ////////////////////////////////////////////////////////////////////////// //
public alias XImageTC = XRefCounted!XlibImageTC;

public struct XlibImageTC {
  private bool thisIsXShm;
  private union {
    XImage handle;
    XImage* handleshm;
  }
  private XShmSeg* shminfo;

  @disable this (this);

  this (MemoryImage img, bool xshm=false) {
    if (img is null || img.width < 1 || img.height < 1) throw new Exception("can't create xlib image from empty MemoryImage");
    create(img.width, img.height, img, xshm);
  }

  this (int wdt, int hgt, bool xshm=false) {
    if (wdt < 1 || hgt < 1) throw new Exception("invalid xlib image");
    create(wdt, hgt, null, xshm);
  }

  this (int wdt, int hgt, MemoryImage aimg, bool xshm=false) {
    if (wdt < 1 || hgt < 1) throw new Exception("invalid xlib image");
    create(wdt, hgt, aimg, xshm);
  }

  ~this () { dispose(); }

  @property bool valid () const pure nothrow @trusted @nogc { pragma(inline, true); return (thisIsXShm ? handleshm !is null : handle.data !is null); }
  @property bool xshm () const pure nothrow @trusted @nogc { pragma(inline, true); return thisIsXShm; }

  @property int width () const pure nothrow @trusted @nogc { pragma(inline, true); return (thisIsXShm ? handleshm.width : handle.width); }
  @property int height () const pure nothrow @trusted @nogc { pragma(inline, true); return (thisIsXShm ? handleshm.height : handle.height); }

  inout(uint)* data () inout nothrow @trusted @nogc { pragma(inline, true); return cast(typeof(return))(thisIsXShm ? handleshm.data : handle.data); }

  void setup (MemoryImage aimg, bool xshm=false) {
    dispose();
    if (aimg is null || aimg.width < 1 || aimg.height < 1) throw new Exception("can't create xlib image from empty MemoryImage");
    create(aimg.width, aimg.height, aimg, xshm);
  }

  void setup (int wdt, int hgt, MemoryImage aimg=null, bool xshm=false) {
    dispose();
    if (wdt < 1 || hgt < 1) throw new Exception("invalid xlib image");
    create(wdt, hgt, aimg, xshm);
  }

  private void create (int width, int height, MemoryImage ximg, bool xshm) {
    import core.stdc.stdlib : malloc, free;
    if (xshm && !sdpyHasXShm) xshm = false;
    thisIsXShm = xshm;
    if (xshm) {
      auto dpy = XDisplayConnection.get();
      if (dpy is null) throw new Exception("can't create XShmImage");

      shminfo = XShmSeg.alloc();
      if (shminfo is null) throw new Exception("can't create XShmImage");
      bool registered = false;
      scope(failure) { XShmSeg.free(shminfo, registered); shminfo = null; }

      handleshm = XShmCreateImage(dpy, DefaultVisual(dpy, DefaultScreen(dpy)), 24, ImageFormat.ZPixmap, null, shminfo.seg, width, height);
      if (handleshm is null) throw new Exception("can't create XShmImage");
      assert(handleshm.bytes_per_line == 4*width);

      shminfo.seg.shmid = shmget(IPC_PRIVATE, handleshm.bytes_per_line*height, IPC_CREAT|511 /* 0777 */);
      assert(shminfo.seg.shmid >= 0);
      registered = true;
      handleshm.data = shminfo.seg.shmaddr = cast(ubyte*)shmat(shminfo.seg.shmid, null, 0);
      assert(handleshm.data != cast(ubyte*)-1);

      auto rawData = cast(uint*)handleshm.data;
      if (ximg is null || ximg.width < width || ximg.height < height) rawData[0..width*height] = 0;
      if (ximg !is null && ximg.width > 0 && ximg.height > 0) {
        foreach (immutable int y; 0..height) {
          foreach (immutable int x; 0..width) {
            rawData[y*width+x] = c2img(ximg.getPixel(x, y));
          }
        }
      }

      shminfo.seg.readOnly = 0;
      XShmAttach(dpy, shminfo.seg);
    } else {
      auto rawData = cast(uint*)malloc(width*height*4);
      scope(failure) free(rawData);
      if (ximg is null || ximg.width < width || ximg.height < height) rawData[0..width*height] = 0;
      if (ximg !is null && ximg.width > 0 && ximg.height > 0) {
        foreach (immutable int y; 0..height) {
          foreach (immutable int x; 0..width) {
            rawData[y*width+x] = c2img(ximg.getPixel(x, y));
          }
        }
      }
      //handle = XCreateImage(dpy, DefaultVisual(dpy, screen), 24/*bpp*/, ImageFormat.ZPixmap, 0/*offset*/, cast(ubyte*)rawData, width, height, 8/*FIXME*/, 4*width); // padding, bytes per line
      handle.width = width;
      handle.height = height;
      handle.xoffset = 0;
      handle.format = ImageFormat.ZPixmap;
      handle.data = rawData;
      handle.byte_order = 0;
      handle.bitmap_unit = 32;
      handle.bitmap_bit_order = 0;
      handle.bitmap_pad = 8;
      handle.depth = 24;
      handle.bytes_per_line = 0;
      handle.bits_per_pixel = 32; // THIS MATTERS!
      handle.red_mask = 0x00ff0000;
      handle.green_mask = 0x0000ff00;
      handle.blue_mask = 0x000000ff;
      XInitImage(&handle);
    }
  }

  void dispose () {
    if (thisIsXShm) {
      if (auto dpy = XDisplayConnection.get()) XShmDetach(dpy, shminfo.seg);
      XDestroyImage(handleshm);
      //shmdt(shminfo.seg.shmaddr);
      //shmctl(shminfo.seg.shmid, IPC_RMID, null);
      XShmSeg.free(shminfo, true);
      shminfo = null;
      handleshm = null;
    } else {
      if (handle.data !is null) {
        import core.stdc.stdlib : free;
        if (handle.data !is null) free(handle.data);
        handle = XImage.init;
      }
    }
  }

  void putPixel (int x, int y, Color c) nothrow @trusted @nogc {
    pragma(inline, true);
    if (valid && x >= 0 && y >= 0 && x < width && y < height) {
      data[y*width+x] = c2img(c);
    }
  }

  Color getPixel (int x, int y, Color c) nothrow @trusted @nogc {
    pragma(inline, true);
    return (valid && x >= 0 && y >= 0 && x < width && y < height ? img2c(data[y*width+x]) : Color.transparent);
  }

  uint* row (int y) nothrow @trusted @nogc {
    pragma(inline, true);
    return (valid && y >= 0 && y < height ? data+y*width : null);
  }

  // blit to window buffer
  void blitAt (SimpleWindow w, int destx, int desty) { blitRect(w, destx, desty, 0, 0, width, height); }

  // blit to window buffer
  void blitRect (SimpleWindow w, int destx, int desty, int sx0, int sy0, int swdt, int shgt) {
    if (w is null || !valid || w.closed) return;
    if (thisIsXShm) {
      XShmPutImage(w.impl.display, cast(Drawable)w.impl.buffer, w.impl.gc, handleshm, sx0, sy0, destx, desty, swdt, shgt, 0);
    } else {
      XPutImage(w.impl.display, cast(Drawable)w.impl.buffer, w.impl.gc, &handle, sx0, sy0, destx, desty, swdt, shgt);
    }
  }

  // blit to window
  void blitAtWin (SimpleWindow w, int destx, int desty) { blitRectWin(w, destx, desty, 0, 0, width, height); }

  // blit to window
  void blitRectWin (SimpleWindow w, int destx, int desty, int sx0, int sy0, int swdt, int shgt) {
    if (w is null || !valid || w.closed) return;
    if (thisIsXShm) {
      XShmPutImage(w.impl.display, cast(Drawable)w.impl.window, w.impl.gc, handleshm, sx0, sy0, destx, desty, swdt, shgt, 0);
    } else {
      XPutImage(w.impl.display, cast(Drawable)w.impl.window, w.impl.gc, &handle, sx0, sy0, destx, desty, swdt, shgt);
    }
  }

static:
  public uint c2img (in Color c) pure nothrow @safe @nogc {
    pragma(inline, true);
    return
      ((c.asUint&0xff)<<16)|
      (c.asUint&0x00ff00)|
      ((c.asUint>>16)&0xff);
  }

  public uint c2img (uint c) pure nothrow @safe @nogc {
    pragma(inline, true);
    return
      ((c&0xff)<<16)|
      (c&0x00ff00)|
      ((c>>16)&0xff);
  }

  public Color img2c (uint clr) pure nothrow @safe @nogc {
    pragma(inline, true);
    return Color((clr>>16)&0xff, (clr>>8)&0xff, clr&0xff);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
public alias XPixmap = XRefCounted!XlibPixmap;

public struct XlibPixmap {
  Pixmap xpm;
  private int mWidth, mHeight;

  this (SimpleWindow w) {}

  this (SimpleWindow w, int wdt, int hgt) { setup(w, wdt, hgt); }
  this (SimpleWindow w, ref XlibImageTC xtc) { setup(w, xtc); }
  this (SimpleWindow w, XImageTC xtc) { if (!xtc.hasObject) throw new Exception("can't create pixmap from empty object"); setup(w, *xtc.intr_); }

  this (SimpleWindow w, ref XlibPixmap xpm) { setup(w, xpm); }
  this (SimpleWindow w, XPixmap xpm) { if (!xpm.hasObject) throw new Exception("can't create pixmap from empty object"); setup(w, *xpm.intr_); }

  @disable this (this);

  ~this () { dispose(); }

  @property bool valid () const pure nothrow @trusted @nogc { pragma(inline, true); return (xpm != 0); }

  @property int width () const pure nothrow @trusted @nogc { pragma(inline, true); return mWidth; }
  @property int height () const pure nothrow @trusted @nogc { pragma(inline, true); return mHeight; }

  void copyFromWinBuf (SimpleWindow w) {
    if (w is null || w.closed) throw new Exception("can't copy pixmap without window");
    if (!valid || mWidth != w.width || mHeight != w.height) {
      dispose();
      xpm = XCreatePixmap(w.impl.display, cast(Drawable)w.impl.window, w.width, w.height, 24);
      mWidth = w.width;
      mHeight = w.height;
    }
    XCopyArea(w.impl.display, cast(Drawable)w.impl.buffer, cast(Drawable)xpm, w.impl.gc, 0, 0, mWidth, mHeight, 0, 0);
  }

  void copyFrom (SimpleWindow w, ref XlibPixmap axpm) {
    if (!valid) return;
    if (!axpm.valid) return;
    if (w is null || w.closed) throw new Exception("can't copy pixmap without window");
    XCopyArea(w.impl.display, cast(Drawable)axpm.xpm, cast(Drawable)xpm, w.impl.gc, 0, 0, axpm.width, axpm.height, 0, 0);
  }

  void copyFrom (SimpleWindow w, XPixmap axpm) {
    if (!axpm.hasObject) return;
    copyFrom(w, *axpm.intr_);
  }

  void setup (SimpleWindow w, int wdt, int hgt) {
    dispose();
    if (w is null || w.closed) throw new Exception("can't create pixmap without window");
    if (wdt < 1) wdt = 1;
    if (hgt < 1) hgt = 1;
    if (wdt > 16384) wdt = 16384;
    if (hgt > 16384) hgt = 16384;
    xpm = XCreatePixmap(w.impl.display, cast(Drawable)w.impl.window, wdt, hgt, 24);
    mWidth = wdt;
    mHeight = hgt;
  }

  void setup (SimpleWindow w, XPixmap xpm) {
    if (!xpm.hasObject) throw new Exception("can't create pixmap from empty xlib image");
    setup(w, *xpm.intr_);
  }

  void setup (SimpleWindow w, ref XlibPixmap axpm) {
    if (!axpm.valid) throw new Exception("can't create pixmap from empty xlib pixmap");
    dispose();
    if (w is null || w.closed) throw new Exception("can't create pixmap without window");
    int wdt = axpm.width;
    int hgt = axpm.height;
    if (wdt < 1) wdt = 1;
    if (hgt < 1) hgt = 1;
    if (wdt > 16384) wdt = 16384;
    if (hgt > 16384) hgt = 16384;
    xpm = XCreatePixmap(w.impl.display, cast(Drawable)w.impl.window, wdt, hgt, 24);
    XCopyArea(w.impl.display, cast(Drawable)axpm.xpm, cast(Drawable)xpm, w.impl.gc, 0, 0, wdt, hgt, 0, 0);
    mWidth = wdt;
    mHeight = hgt;
  }

  void setup (SimpleWindow w, XImageTC xtc) {
    if (!xtc.hasObject) throw new Exception("can't create pixmap from empty xlib image");
    setup(w, *xtc.intr_);
  }

  void setup (SimpleWindow w, ref XlibImageTC xtc) {
    if (!xtc.valid) throw new Exception("can't create pixmap from empty xlib image");
    dispose();
    if (w is null || w.closed) throw new Exception("can't create pixmap without window");
    int wdt = xtc.width;
    int hgt = xtc.height;
    if (wdt < 1) wdt = 1;
    if (hgt < 1) hgt = 1;
    if (wdt > 16384) wdt = 16384;
    if (hgt > 16384) hgt = 16384;
    xpm = XCreatePixmap(w.impl.display, cast(Drawable)w.impl.window, wdt, hgt, 24);
    // source x, source y
    if (xtc.thisIsXShm) {
      XShmPutImage(w.impl.display, cast(Drawable)xpm, w.impl.gc, xtc.handleshm, 0, 0, 0, 0, wdt, hgt, 0);
    } else {
      XPutImage(w.impl.display, cast(Drawable)xpm, w.impl.gc, &xtc.handle, 0, 0, 0, 0, wdt, hgt);
    }
    mWidth = wdt;
    mHeight = hgt;
  }

  void dispose () {
    if (xpm) {
      XFreePixmap(XDisplayConnection.get(), xpm);
      xpm = 0;
    }
    mWidth = mHeight = 0;
  }

  // blit to window buffer
  void blitAt (SimpleWindow w, int x, int y) {
    blitRect(w, x, y, 0, 0, width, height);
  }

  // blit to window buffer
  void blitRect (SimpleWindow w, int destx, int desty, int sx0, int sy0, int swdt, int shgt) {
    if (w is null || !xpm || w.closed) return;
    XCopyArea(w.impl.display, cast(Drawable)xpm, cast(Drawable)w.impl.buffer, w.impl.gc, sx0, sy0, swdt, shgt, destx, desty);
  }

  // blit to window buffer
  void blitAtWin (SimpleWindow w, int x, int y) {
    blitRectWin(w, x, y, 0, 0, width, height);
  }

  // blit to window buffer
  void blitRectWin (SimpleWindow w, int destx, int desty, int sx0, int sy0, int swdt, int shgt) {
    if (w is null || !xpm || w.closed) return;
    XCopyArea(w.impl.display, cast(Drawable)xpm, cast(Drawable)w.impl.window, w.impl.gc, sx0, sy0, swdt, shgt, destx, desty);
  }
}

// ////////////////////////////////////////////////////////////////////////// //
}


void sdpyNormalizeArrowKeys (ref KeyEvent event) {
  if ((event.modifierState&ModifierState.numLock) == 0) {
    switch (event.key) {
      case Key.PadEnter: event.key = Key.Enter; break;
      case Key.Pad1: event.key = Key.End; break;
      case Key.Pad2: event.key = Key.Down; break;
      case Key.Pad3: event.key = Key.PageDown; break;
      case Key.Pad4: event.key = Key.Left; break;
      //case Key.Pad5: event.key = Key.; break;
      case Key.Pad6: event.key = Key.Right; break;
      case Key.Pad7: event.key = Key.Home; break;
      case Key.Pad8: event.key = Key.Up; break;
      case Key.Pad9: event.key = Key.PageUp; break;
      case Key.Pad0: event.key = Key.Insert; break;
      default: break;
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
// this mixin can be used to alphablend two `uint` colors
// `colu32name` is variable that holds color to blend,
// `destu32name` is variable that holds "current" color (from surface, for example)
// alpha value of `destu32name` doesn't matter
// alpha value of `colu32name` means: 255 for replace color, 0 for keep `destu32name` (was reversed)
private enum ColorBlendMixinStr(string colu32name, string destu32name) = "{
  immutable uint a_tmp_ = 256-((256-(("~colu32name~")>>24))&(-(1-(((("~colu32name~")>>24)+1)>>8)))); // to not loose bits, but 255 should become 0
  immutable uint dc_tmp_ = ("~destu32name~")&0xffffff;
  immutable uint srb_tmp_ = (("~colu32name~")&0xff00ff);
  immutable uint sg_tmp_ = (("~colu32name~")&0x00ff00);
  immutable uint drb_tmp_ = (dc_tmp_&0xff00ff);
  immutable uint dg_tmp_ = (dc_tmp_&0x00ff00);
  immutable uint orb_tmp_ = (drb_tmp_+(((srb_tmp_-drb_tmp_)*a_tmp_+0x800080)>>8))&0xff00ff;
  immutable uint og_tmp_ = (dg_tmp_+(((sg_tmp_-dg_tmp_)*a_tmp_+0x008000)>>8))&0x00ff00;
  ("~destu32name~") = (orb_tmp_|og_tmp_)|0xff000000; /*&0xffffff;*/
}";


Color blend (Color dst, Color src) nothrow @trusted @nogc {
  if (src.a != 0) {
    mixin(ColorBlendMixinStr!("src.asUint", "dst.asUint"));
  }
  return dst;
}
