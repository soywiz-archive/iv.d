/* coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
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
module simpleterm;
private:

import core.time : MonoTime, Duration;

import iv.strex;
import iv.termrgb;
import iv.utfutil;
import iv.vfs.io;
import iv.vt100;
import iv.x11;


// ////////////////////////////////////////////////////////////////////////// //
enum fontNorm = "-*-terminus-bold-*-*-*-20-*-*-*-*-*-*-*";
enum fontBold = "-*-terminus-bold-*-*-*-20-*-*-*-*-*-*-*";

enum OptPtrBlankTime = 1500;
enum OptPtrBlinkTime = 700;


// ////////////////////////////////////////////////////////////////////////// //
class ExitException : Exception { this () { super("exit"); } }
class ExitError : ExitException { this () { super(); } }


void die(AA...) (string fmt, AA args) {
  stderr.write("FATAL: ");
  stderr.writeln(fmt, args);
  throw new ExitError();
}


// ////////////////////////////////////////////////////////////////////////// //
public bool isUTF8Locale () nothrow @trusted @nogc {
  import core.atomic;

  static char tolower (char ch) pure nothrow @safe @nogc { return (ch >= 'A' && ch <= 'Z' ? cast(char)(ch-'A'+'a') : ch); }

  __gshared bool res = false;
  __gshared bool checked = false;
  static shared int waiting = 0; // 0: not inited; 1: initializing; 2: done

  if (!checked) {
    if (cas(&waiting, 0, 1)) {
      // not inited -> inited
      import core.stdc.locale;
      char* lct = setlocale(LC_CTYPE, null);
      if (lct !is null) {
        //auto lang = getenv("LANG");
        //if (lang is null) return;
        auto lang = lct;
        while (*lang) {
          if (tolower(lang[0]) == 'u' && tolower(lang[1]) == 't' && tolower(lang[2]) == 'f') { res = true; break; }
          ++lang;
        }
        //res = (strcasestr(lct, "utf") !is null);
      } else {
        res = false;
      }
      checked = true;
      // just in case
      atomicFence();
      if (!cas(&waiting, 1, 2)) assert(0, "wtf?!");
    } else {
      // either inited, or initializing
      while (atomicLoad(waiting) != 2) {}
      // just in case
      atomicFence();
      if (!checked) assert(0, "wtf?!");
    }
  }
  return res;
}


// ////////////////////////////////////////////////////////////////////////// //
final class DiWindow {
private:
  private import core.stdc.config : c_long;

private:
  enum RedrawRateActive = 40; // each 40 msecs
  enum RedrawRateInactive = 100; // each 100 msecs

  enum DefaultBGColorIdx = 0;
  enum DefaultFGColorIdx = 7;
  enum ActiveCursorColorBGIdx = 256; // +1 for blink
  enum ActiveCursorColorFGIdx = 258; // same for both blink stages
  enum InactiveCursorColorFGIdx = 259; // same for both blink stages
  enum BoldFGIdx = 260;
  enum UnderlineFGIdx = 260;

  enum { FONTDEF, FONTBOLD }
  bool mOneFont; // FONTDEF is the same as FONTBOLD?

  Window mXEmbed; // do xembed with this wid

  int csigfd = -1; // signals fd

  Display *dpy;
  Colormap cmap;
  Window win;
  Cursor mXTextCursor; // text cursor
  Cursor mXDefaultCursor; // 'default' cursor
  Cursor mXBlankCursor;
  XIM xim;
  XIC xic;
  int scr;
  int winWidth; // window width in pixels
  int winHeight; // window height in pixels
  int charWidth; // char width
  int charHeight; // char height

  bool mForceRedraw; // force full terminal redraw
  bool mForceDirtyRedraw; // force update of dirty areas

  char[1024] mLastTitle = 0;
  int mLastTitleLength = int.max;
  MonoTime mLastTitleChangeTime;

  bool mDoSelection;
  int mSelLastX, mSelLastY; // last mouse position if mDoSelection is true
  string mCurSelection;

  // for blinking
  MonoTime mCurLastPhaseChange;
  MonoTime mCurLastMove;
  int mCurPhase; // 0/1

  MonoTime mLastInputTime; // for pointer blanking
  bool mPointerVisible;

  MonoTime mLastDrawTime;

  enum {
    wsVisible = 0x01,
    wsFocused = 0x02,
  }
  ubyte mWinState; // focus, visible

  @property bool isVisible () const pure @safe nothrow @nogc { pragma(inline, true); return ((mWinState&wsVisible) != 0); }
  @property bool isFocused () const pure @safe nothrow @nogc { pragma(inline, true); return ((mWinState&wsFocused) != 0); }

  Atom xaXEmbed;
  Atom xaVTSelection;
  Atom xaClipboard;
  Atom xaUTF8;
  Atom xaTargets;
  Atom xaNetWMName;
  Atom xaWMProtocols;
  Atom xaWMDeleteWindow;
  Atom xaTerminalMessage;

  enum {
    WinMsgDirty = 1,
  }

  // Drawing Context
  enum { CLNORMAL, CLBW, CLGREEN }
  c_ulong[512][3] clrs;
  GC gc;
  static struct XFont {
    int ascent;
    int descent;
    short lbearing;
    short rbearing;
    XFontSet set;
    Font fid;
  }
  XFont[2] font;

  static final class DittyTab {
    DiWindow xw;
    VT100Emu appbuf;
    bool prevcurVis = false;
    int prevcurX, prevcurY;
    bool reversed; // is everything reversed?

    char[1024] mLastTitle = 0;
    int mLastTitleLength = int.max;
    MonoTime mLastTitleChangeTime;

    char[1024] mLastProcess = 0;
    int mLastProcessLength;

    char[1024] mLastFullProcess = 0;
    int mLastFullProcessLength;

    this (DiWindow axw, int aw, int ah) {
      import std.algorithm : max, min;
      assert(axw !is null);
      xw = axw;
      aw = max(MinBufferWidth, min(aw, MaxBufferWidth));
      ah = max(MinBufferHeight, min(ah, MaxBufferHeight));
      // create application buffer
      appbuf = new VT100Emu(aw, ah, isUTF8Locale);
      appbuf.onScrollUp = &axw.onScrollUp;
      appbuf.onScrollDown = &axw.onScrollDown;
      appbuf.onBell = &axw.onBell;
      appbuf.onNewTitleEvent = &axw.onNewTitleEvent;
      appbuf.onReverseEvent = &axw.onReverseEvent;
    }

    @property ScreenBuffer activebuf () nothrow @safe @nogc { pragma(inline, true); return appbuf; }
    // title is always 0-terminated
    @property const(char)[] title () nothrow @safe @nogc { pragma(inline, true); return mLastTitle[0..mLastTitleLength]; }
    @property const(char)[] appname () nothrow @safe @nogc { pragma(inline, true); return mLastProcess[0..mLastProcessLength]; }
    @property const(char)[] fullappname () nothrow @safe @nogc { pragma(inline, true); return mLastFullProcess[0..mLastFullProcessLength]; }

    void close () {
    }

    void onResize (int aw, int ah) {
      appbuf.resize(aw, ah);
      appbuf.setFullDirty();
    }

    void keypressEvent (dchar dch, KeySym ksym, X11ModState modstate) {
      activebuf.keypressEvent(dch, ksym, modstate);
    }

    // return `true` if process name was changed
    bool checkFixProcess () nothrow @nogc {
      bool res = false;
      char[1024] buf = void;
      auto nm = appbuf.getFullProcessName(buf[]);
      if (nm.length != mLastFullProcessLength || mLastFullProcess[0..mLastFullProcessLength] != nm[0..$]) {
        mLastFullProcess[0..nm.length] = nm[];
        mLastFullProcessLength = cast(int)nm.length;
      }
      nm = appbuf.getProcessName(buf[]);
      if (nm.length != mLastProcessLength || mLastProcess[0..mLastProcessLength] != nm[0..$]) {
        res = true;
        mLastProcess[0..nm.length] = nm[];
        mLastProcessLength = cast(int)nm.length;
        setTitle(nm);
      }
      return res;
    }

    // return `true` if process name was changed
    void setTitle (const(char)[] atitle) nothrow @nogc {
      if (atitle.length > mLastTitle.length-1) atitle = atitle[0..mLastTitle.length-1]; //FIXME
      mLastTitle[0..atitle.length] = atitle[];
      mLastTitleLength = cast(int)atitle.length;
      mLastTitle[mLastTitleLength] = 0;
    }
  }

  DittyTab mTab;

  final @property DittyTab tab () nothrow @safe @nogc { pragma(inline, true); return mTab; }
  final @property VT100Emu appbuf () nothrow @safe @nogc { pragma(inline, true); return mTab.appbuf; }
  final @property ScreenBuffer scrbuf () nothrow @safe @nogc { pragma(inline, true); return mTab.activebuf; }

  dchar[MaxBufferWidth+8] mDrawBuf = void;

  c_ulong getColor (usize idx) const nothrow @trusted @nogc {
    //if (globalBW && (curterm == NULL || !curterm->blackandwhite)) return dc.clrs[globalBW][idx];
    //if (curterm != NULL) return dc.clrs[curterm->blackandwhite%3][idx];
    //return dc.clrs[0][idx];
    return (idx < clrs[0].length ? clrs[CLNORMAL][idx] : clrs[0][0]);
  }

  //~this () { close(); } //oops

private:
  void postMessage (c_long type, c_long l1=0, c_long l2=0, c_long l3=0, c_long l4=0) {
    //{ import iv.writer; writeln("posting message..."); }
    XEvent ev;
    ev.type = ClientMessage;
    ev.xclient.window = win;
    ev.xclient.message_type = xaTerminalMessage;
    ev.xclient.format = 32;
    ev.xclient.data.l[0] = type;
    ev.xclient.data.l[1] = l1;
    ev.xclient.data.l[2] = l2;
    ev.xclient.data.l[3] = l3;
    ev.xclient.data.l[4] = l4;
    XSendEvent(dpy, win, False, 0, &ev);
  }

private:
  void initAtoms () {
    xaXEmbed = XInternAtom(dpy, "_XEMBED", False);
    xaVTSelection = XInternAtom(dpy, "_STERM_SELECTION_", 0);
    xaClipboard = XInternAtom(dpy, "CLIPBOARD", 0);
    xaUTF8 = XInternAtom(dpy, "UTF8_STRING", 0);
    xaNetWMName = XInternAtom(dpy, "_NET_WM_NAME", 0);
    xaTargets = XInternAtom(dpy, "TARGETS", 0);
    xaWMProtocols = XInternAtom(dpy, "WM_PROTOCOLS", 0);
    xaWMDeleteWindow = XInternAtom(dpy, "WM_DELETE_WINDOW", 0);
    xaTerminalMessage = XInternAtom(dpy, "K8_DITTY_MESSAGE", 0);
  }

  void xhints () {
    XClassHint klass;
    klass.res_class = "DiTTY_SAMPLE_TERMINAL";
    klass.res_name = "DiTTY_SAMPLE_TERMINAL";
    XWMHints wm;
    wm.flags = InputHint;
    wm.input = 1;
    XSizeHints size;
    size.flags = PMinSize|PMaxSize|PSize|PResizeInc|PBaseSize;
    size.min_width = MinBufferWidth*charWidth;
    size.min_height = (MinBufferHeight+1)*charHeight; // one more row for tabs and status info
    size.max_width = MaxBufferWidth*charWidth;
    size.max_height = (MaxBufferHeight+1)*charHeight;
    size.width_inc = charWidth;
    size.height_inc = charHeight;
    /* if we'll do it this way, FluxBox will assume that minimal window size is equal to base size
    size.width = winWidth;
    size.height = winHeight;
    size.base_width = winWidth;
    size.base_height = winHeight;
    */
    size.width = size.min_width;
    size.height = size.min_height;
    size.base_width = size.min_width;
    size.base_height = size.min_height;
    XSetWMNormalHints(dpy, win, &size);
    XSetWMProperties(dpy, win, null, null, null, 0, &size, &wm, &klass);
    XSetWMProtocols(dpy, win, &xaWMDeleteWindow, 1);
    XResizeWindow(dpy, win, winWidth, winHeight);
  }

  XFontSet xinitfont (string fontstr) {
    import std.string : toStringz, fromStringz;
    XFontSet set;
    char *def;
    char **missing;
    int n;
    missing = null;
    set = XCreateFontSet(dpy, cast(char*)(fontstr.toStringz), &missing, &n, &def);
    if (missing) {
      //!!!:while (n--) errwriteln("diterm: missing fontset: ", missing[n].fromStringz);
      XFreeStringList(missing);
    }
    return set;
  }

  void xgetfontinfo (XFontSet set, int *ascent, int *descent, short *lbearing, short *rbearing, Font *fid) {
    import std.algorithm : max;
    XFontStruct **xfonts; // owned by Xlib
    char **fontNames; // owned by Xlib
    *ascent = *descent = *lbearing = *rbearing = 0;
    /*int n =*/ XFontsOfFontSet(set, &xfonts, &fontNames);
    /*HACK: use only first font in set; this is due to possible extra-wide fonts*/
    *fid = (*xfonts).fid;
    *ascent = max(*ascent, (*xfonts).ascent);
    *descent = max(*descent, (*xfonts).descent);
    *lbearing = max(*lbearing, (*xfonts).min_bounds.lbearing);
    *rbearing = max(*rbearing, (*xfonts).max_bounds.rbearing);
  }

  void initfonts (string fontstr, string bfontstr) {
    import core.stdc.stdlib : malloc, free;
    import core.stdc.string : strdup;
    import core.stdc.locale;
    char *olocale;
    /* X Core Fonts fix */
    /* sorry, we HAVE to do this shit here!
     * braindamaged X11 will not work with utf-8 in Xmb*() correctly if we have, for example,
     * koi8 as system locale unless we first create font set in system locale. don't even ask
     * me why X.Org is so fuckin' broken. */
    XFontSet tmp_fs;
    char** missing;
    int missing_count;
    olocale = strdup(setlocale(LC_ALL, null)); /*FIXME: this can fail if we have no memory; fuck it*/
    setlocale(LC_ALL, "");
    tmp_fs = XCreateFontSet(dpy, cast(char*)"-*-*-*-*-*-*-*-*-*-*-*-*-*", &missing, &missing_count, null);
    if (!tmp_fs) die("FATAL: can't apply workarount for X Core FontSets!");
    if (missing) XFreeStringList(missing);
    // throw out unused fontset
    XFreeFontSet(dpy, tmp_fs);
    //setlocale(LC_ALL, "ru_RU.utf-8");
    //TODO: find suitable utf-8 encoding
    setlocale(LC_ALL, "en_US.UTF-8");
    // create fonts for utf-8 locale
    if ((font[0].set = xinitfont(fontstr)) is null) {
      /*if ((font[0].set = xinitfont(FONT)) is null)*/ die("can't load font %s", fontstr);
    }
    xgetfontinfo(font[0].set, &font[0].ascent, &font[0].descent, &font[0].lbearing, &font[0].rbearing, &font[0].fid);
    if ((font[1].set = xinitfont(bfontstr)) is null) {
      /*if ((font[1].set = xinitfont(FONTBOLD)) is null)*/ die("can't load font %s", bfontstr);
    }
    xgetfontinfo(font[1].set, &font[1].ascent, &font[1].descent, &font[1].lbearing, &font[1].rbearing, &font[1].fid);
    /+
    if ((font[2].set = xinitfont(tabfont)) is null) {
      /*if ((font[2].set = xinitfont(FONTTAB)) is null)*/ die("can't load font %s", tabfont);
    }
    xgetfontinfo(font[2].set, &font[2].ascent, &font[2].descent, &font[2].lbearing, &font[2].rbearing, &font[2].fid);
    +/
    // restore locale
    setlocale(LC_ALL, olocale);
    free(olocale);
    // same fonts for normal and bold?
    mOneFont = (fontstr == bfontstr);
  }

  void xallocbwclr (usize idx, XColor *color) {
    XQueryColor(dpy, cmap, color);
    double lumi = 0.3*(cast(double)color.red/65535.0)+0.59*(cast(double)color.green/65535.0)+0.11*(cast(double)color.blue/65535.0);
    color.red = color.green = color.blue = cast(ushort)(lumi*65535.0);
    if (!XAllocColor(dpy, cmap, color)) {
      import core.stdc.stdio;
      stderr.fprintf("WARNING: could not allocate b/w color #%u\n", cast(uint)idx);
      return;
    }
    clrs[CLBW][idx] = color.pixel;
    color.red = color.blue = 0;
    if (!XAllocColor(dpy, cmap, color)) {
      import core.stdc.stdio;
      stderr.fprintf("WARNING: could not allocate b/w color #%u\n", cast(uint)idx);
      return;
    }
    clrs[CLGREEN][idx] = color.pixel;
  }

  void xallocnamedclr (usize idx, string cname) {
    import std.string : toStringz;
    XColor color;
    if (!XAllocNamedColor(dpy, cmap, cname.toStringz, &color, &color)) {
      import core.stdc.stdio;
      stderr.fprintf("WARNING: could not allocate color #%u: '%.s'", cast(uint)idx, cast(uint)cname.length, cname.ptr);
      return;
    }
    clrs[CLNORMAL][idx] = color.pixel;
    xallocbwclr(idx, &color);
  }

  void xloadcols () {
    static immutable string[16] defclr = [
      // 8 normal colors
      "#000000",
      "#b21818",
      "#18b218",
      "#b26818",
      "#1818b2",
      "#b218b2",
      "#18b2b2",
      "#b2b2b2",
      // 8 bright colors
      "#686868",
      "#ff5454",
      "#54ff54",
      "#ffff54",
      "#5454ff",
      "#ff54ff",
      "#54ffff",
      "#ffffff",
    ];

    XColor color;
    uint white = WhitePixel(dpy, scr);
    clrs[0] = white;
    clrs[1] = white;
    clrs[2] = white;

    // load colors [0-15]
    foreach (immutable idx; 0..defclr.length) {
      //const char *cname = opt_colornames[f]!=NULL?opt_colornames[f]:defcolornames[f];
      xallocnamedclr(idx, defclr[idx]);
    }

    // load colors [256-...]
    foreach (immutable idx; 256..clrs.length) xallocnamedclr(idx, "#fff700");

    // load colors [16-255]; same colors as xterm
    usize idx = 16;
    foreach (immutable r; 0..6) {
      foreach (immutable g; 0..6) {
        foreach (immutable b; 0..6) {
          color.red = cast(ushort)(r == 0 ? 0 : 0x3737+0x2828*r);
          color.green = cast(ushort)(g == 0 ? 0 : 0x3737+0x2828*g);
          color.blue = cast(ushort)(b == 0 ? 0 : 0x3737+0x2828*b);
          if (!XAllocColor(dpy, cmap, &color)) {
            import core.stdc.stdio;
            stderr.fprintf("WARNING: could not allocate color #%u\n", cast(uint)idx);
          } else {
            clrs[CLNORMAL][idx] = color.pixel;
            xallocbwclr(idx, &color);
          }
          ++idx;
        }
      }
    }
    foreach (immutable r; 0..24) {
      color.red = color.green = color.blue = cast(ushort)(0x0808+0x0a0a*r);
      if (!XAllocColor(dpy, cmap, &color)) {
        import core.stdc.stdio;
        stderr.fprintf("WARNING: could not allocate color #%u\n", cast(uint)idx);
      } else {
        clrs[CLNORMAL][idx] = color.pixel;
        xallocbwclr(idx, &color);
      }
      ++idx;
    }
    assert(idx == 256);
    // blinking cursor bg
    xallocnamedclr(256, "#00ff00");
    xallocnamedclr(257, "#00cc00");
    // active cursor fg
    xallocnamedclr(258, "#005500");
    // inactive cursor
    xallocnamedclr(259, "#009900");
    // bold
    xallocnamedclr(260, "#00afaf");
    // underline
    xallocnamedclr(261, "#00af00");
  }

  void changeTitle (const(char)[] s) nothrow @trusted @nogc {
    if (s.length == 0) s = "";
    usize len = s.length;
    if (len >= mLastTitle.length) len = mLastTitle.length-1;
    if (mLastTitleLength != len || mLastTitle[0..len] != s[0..len]) {
      mLastTitle[0..len] = s[0..len];
      mLastTitle[len] = 0;
      mLastTitleLength = len;
      XStoreName(dpy, win, mLastTitle.ptr);
      XChangeProperty(dpy, win, xaNetWMName, xaUTF8, 8, PropModeReplace, cast(ubyte*)mLastTitle.ptr, cast(uint)mLastTitleLength);
      XFlush(dpy); // immediate update
    }
  }

  string atomName (Atom a) {
    import std.string : fromStringz;
    auto nm = XGetAtomName(dpy, a);
    auto res = nm.fromStringz.idup;
    XFree(nm);
    return res;
  }

  // ////////////////////////////////////////////////////////////////////// //
  private void setupSignals () {
    if (csigfd < 0) {
      import core.sys.linux.sys.signalfd : signalfd, SFD_NONBLOCK, SFD_CLOEXEC;
      import core.sys.posix.signal : sigset_t, sigemptyset, sigaddset, sigprocmask;
      import core.sys.posix.signal : SIG_BLOCK, SIGTERM, SIGHUP, SIGQUIT, SIGINT, SIGCHLD;
      sigset_t mask;
      sigemptyset(&mask);
      //sigaddset(&mask, SIGTERM);
      //sigaddset(&mask, SIGHUP);
      //sigaddset(&mask, SIGQUIT);
      //sigaddset(&mask, SIGINT);
      sigaddset(&mask, SIGCHLD);
      sigprocmask(SIG_BLOCK, &mask, null); // we block the signals
      //pthread_sigmask(SIG_BLOCK, &mask, NULL); // we block the signal
      csigfd = signalfd(-1, &mask, SFD_NONBLOCK|SFD_CLOEXEC);
      if (csigfd < 0) die("can't setup signal handler");
    }
  }

  void processDeadChildren () {
    import core.sys.linux.sys.signalfd : signalfd_siginfo;
    import core.sys.posix.unistd : read;
    signalfd_siginfo si = void;
    while (read(csigfd, &si, si.sizeof) > 0) {} // ignore errors here
    mainloop: for (;;) {
      import core.sys.posix.sys.wait : waitpid, WNOHANG, WIFEXITED, WEXITSTATUS;
      int status;
      auto pid = waitpid(-1, &status, WNOHANG);
      if (pid <= 0) break; // no more dead children
      if (tab.appbuf.checkDeadChild(pid, WEXITSTATUS(status))) continue mainloop;
      if (onDeadChildren !is null) onDeadChildren(cast(int)pid, WEXITSTATUS(status));
    }
  }

  import core.sys.posix.sys.types : pid_t;
  static assert(pid_t.sizeof == int.sizeof);

private:
  void onScrollUp (ScreenBuffer self, int y0, int y1, int count, bool wasDirty) nothrow {
    if (!isVisible) return;
    if (wasDirty) return;
    bool restcur = (tab.prevcurVis && tab.prevcurX >= 0 && tab.prevcurX < self.width && tab.prevcurY >= y0 && tab.prevcurY <= y1);
    if (restcur) undrawCursor();
    xcopytty(
      0, y0, // dest
      0, y0+count,
      self.width, y1-y0+1-count);
    if (restcur) drawCursor();
    // mark scrolled lines non-dirty
    //{ import core.stdc.stdio; printf("from %d to %d (y0=%d; y1=%d)\n", y0, y1-count+1-1, y0, y1); }
    foreach (immutable y; y0..y1-count+1) self.resetDirtyLine(y);
  }

  void onScrollDown (ScreenBuffer self, int y0, int y1, int count, bool wasDirty) nothrow {
    if (!isVisible) return;
    if (wasDirty) return;
    // down
    bool restcur = (tab.prevcurVis && tab.prevcurX >= 0 && tab.prevcurX < self.width && tab.prevcurY >= y0 && tab.prevcurY <= y1);
    if (restcur) undrawCursor();
    xcopytty(
      0, y0+count, // dest
      0, y0,
      self.width, y1-y0+1-count);
    if (restcur) drawCursor();
    // mark scrolled lines non-dirty
    foreach (immutable y; y0+count..y1+1) self.resetDirtyLine(y);
  }

  // ring a bell
  final void onBell (ScreenBuffer self) nothrow @trusted @nogc {
    XBell(dpy, 100);
  }

  // new title was set; we don't check if it's the same as old title
  final void onNewTitleEvent (ScreenBuffer self, const(char)[] title) nothrow {
    if (self is tab.appbuf) {
      tab.checkFixProcess();
      tab.setTitle(title);
      changeTitle(title);
      return;
    }
  }

  // inverse mode changed; it should be in effect immediately
  final void onReverseEvent (ScreenBuffer self) nothrow @trusted @nogc {
    if (self is tab.appbuf) {
      tab.reversed = !tab.reversed;
      self.setFullDirty();
      return;
    }
  }

public:
  void delegate (int pid, int exitcode) onDeadChildren;

public:
  // width and height in cells
  this (int awdt, int ahgt) {
    mTab = new DittyTab(this, awdt, ahgt);
    setupSignals();
    initialize(mTab.appbuf.width, mTab.appbuf.height);
  }

  private void initialize (int awdt, int ahgt) {
    if (win) assert(0, "already initialized");

    XSetWindowAttributes attrs;
    Window parent;
    XColor blackcolor;// = { 0, 0, 0, 0, 0, 0 };
    int wwdt, whgt;

    {
      import core.stdc.locale;
      import core.stdc.stdlib : free;
      import core.stdc.string : strdup;
      auto olocale = strdup(setlocale(LC_ALL, null));
      //{ import std.string : fromStringz; import iv.writer; writeln("[", olocale.fromStringz, "]"); }
      if (isUTF8Locale()) {
        if (!setlocale(LC_ALL, "")) die("can't set locale");
      } else {
        if (!setlocale(LC_ALL, "en_US.UTF-8")) die("can't set UTF locale");
      }
      if (!XSupportsLocale()) die("X server doesn't support locale");
      if (XSetLocaleModifiers("@im=local") is null) die("XSetLocaleModifiers failed");
      setlocale(LC_ALL, olocale);
      free(olocale);
    }

    dpy = XOpenDisplay();
    if (!dpy) die("can't open display");
    scr = XDefaultScreen(dpy);

    initAtoms();

    // fonts
    initfonts(fontNorm, fontBold);
    /* XXX: Assuming same size for bold font */
    charWidth = font[0].rbearing-font[0].lbearing;
    charHeight = font[0].ascent+font[0].descent;
    //tch = font[2].ascent+font[2].descent;

    // colors
    cmap = XDefaultColormap(dpy, scr);
    xloadcols();

    // window - default size
    wwdt = awdt*charWidth;
    whgt = ahgt*charHeight;
    //
    winWidth = wwdt;
    winHeight = whgt; // one more row for tabs and status info
    //
    attrs.background_pixel = None;//getColor(/*defaultBG*/0);
    attrs.border_pixel = None;//getColor(/*defaultBG*/0);
    attrs.bit_gravity = NorthWestGravity;
    attrs.event_mask =
      FocusChangeMask|
      KeyPressMask|KeyReleaseMask|KeymapStateMask|
      ExposureMask|VisibilityChangeMask|StructureNotifyMask|
      ButtonMotionMask|
      PointerMotionMask| //TODO: do we need motion reports at all?
      ButtonPressMask|ButtonReleaseMask|
      /*EnterWindowMask|LeaveWindowMask|*/
      0;
    attrs.colormap = cmap;
    parent = XRootWindow(dpy, scr);
    if (mXEmbed) parent = mXEmbed;
    win = XCreateWindow(dpy, parent, 0, 0,
        winWidth, winHeight, 0, XDefaultDepth(dpy, scr), InputOutput,
        XDefaultVisual(dpy, scr),
        CWBackPixel|CWBorderPixel|CWBitGravity|CWEventMask|CWColormap,
        &attrs);
    xhints();

    // input method
    // force locale for correct XIM
    {
      import core.stdc.locale;
      import core.stdc.stdlib : free;
      import core.stdc.string : strdup;
      auto olocale = strdup(setlocale(LC_ALL, null));
      //{ import std.string : fromStringz; import iv.writer; writeln("[", olocale.fromStringz, "]"); }
      if (isUTF8Locale()) {
        if (!setlocale(LC_ALL, "")) die("can't set locale");
      } else {
        if (!setlocale(LC_ALL, "en_US.UTF-8")) die("can't set UTF locale");
      }

      if ((xim = XOpenIM(dpy, null, null, null)) is null) {
        if (XSetLocaleModifiers("@im=local") is null) die("XSetLocaleModifiers failed");
        if ((xim = XOpenIM(dpy, null, null, null)) is null) {
          if (XSetLocaleModifiers("@im=") is null) die("XSetLocaleModifiers failed");
          if ((xim = XOpenIM(dpy, null, null, null)) is null) die("XOpenIM() failed");
        }
      }
      xic = XCreateIC(xim,
        XNInputStyle.ptr, XIMPreeditNothing|XIMStatusNothing,
        XNClientWindow.ptr, win,
        XNFocusWindow.ptr, win,
        null);
      if (xic is null) die("XCreateIC failed");

      setlocale(LC_ALL, olocale);
      free(olocale);
    }

    // gc
    gc = XCreateGC(dpy, cast(Drawable)win, 0, null);
    XSetGraphicsExposures(dpy, gc, True);

    mXTextCursor = XCreateFontCursor(dpy, XC_xterm);
    //mXTextCursor = XCreateFontCursor(dpy, XC_arrow);
    /* green cursor, black outline */
    /*
    XRecolorCursor(dpy, mXTextCursor,
      &(XColor){.red = 0x0000, .green = 0xffff, .blue = 0x0000},
      &(XColor){.red = 0x0000, .green = 0x0000, .blue = 0x0000});
    */
    mXDefaultCursor = XCreateFontCursor(dpy, /*XC_X_cursor*/XC_left_ptr);
    /*
    XRecolorCursor(dpy, mXDefaultCursor,
      &(XColor){.red = 0x0000, .green = 0xffff, .blue = 0x0000},
      &(XColor){.red = 0x0000, .green = 0x0000, .blue = 0x0000});
    */
    XDefineCursor(dpy, win, mXTextCursor);
    XStoreName(dpy, win, "Ditty");

    XSetForeground(dpy, gc, 0);

    XMapWindow(dpy, win);

    version(BLANKPTR_USE_GLYPH_CURSOR) {
      mXBlankCursor = XCreateGlyphCursor(dpy, font[0].fid, font[0].fid, ' ', ' ', &blackcolor, &blackcolor);
    } else {
      char[1] cmbmp = 0;
      Pixmap pm;
      pm = XCreateBitmapFromData(dpy, cast(Drawable)win, cmbmp.ptr, 1, 1);
      mXBlankCursor = XCreatePixmapCursor(dpy, pm, pm, &blackcolor, &blackcolor, 0, 0);
      XFreePixmap(dpy, pm);
    }

    //XSetICFocus(xic);

    XSync(dpy, 0);
  }

  void close () {
    tab.close();
    if (win) {
      XFreeGC(dpy, gc);
      XUnmapWindow(dpy, win);
      XDestroyWindow(dpy, win);
      win = cast(Window)0;
    }
    if (dpy) {
      XCloseDisplay(dpy);
      dpy = null;
    }
  }

  // ////////////////////////////////////////////////////////////////////// //
  void blankPointer () {
    if (mPointerVisible && mXBlankCursor != None) {
      mPointerVisible = false;
      XDefineCursor(dpy, win, mXBlankCursor);
      XFlush(dpy);
    }
  }

  void unblankPointer () {
    if (!mPointerVisible && mXTextCursor != None) {
      mPointerVisible = true;
      XDefineCursor(dpy, win, mXTextCursor);
      XFlush(dpy);
    }
    mLastInputTime = MonoTime.currTime;
  }

  // ////////////////////////////////////////////////////////////////////// //
  void drawString (int x, int y, const(char)[] str, usize fontset=FONTDEF) {
    if (charHeight < 1 || charWidth < 1) return;
    if (y < 0 || y*charHeight >= winHeight || str.length == 0 || x/charWidth >= winWidth) return;
    Utf8DecoderFast dc;
    int dlen = 0;
    foreach (char ch; str) {
      if (dc.decodeSafe(ch)) {
        if (dlen == mDrawBuf.length) break;
        mDrawBuf.ptr[dlen++] = dc.codepoint;
      }
    }
    //{ import core.stdc.stdio; stderr.fprintf("dlen=%d\n", dlen); }
    auto xbuf = mDrawBuf[0..dlen];
    if (dlen == 0) return;
    if (x < 0) {
      x = -x;
      if (x >= dlen) return;
      xbuf = xbuf[x..$];
      x = 0;
      if (dlen == 0) return;
    }
    XFontSet xfontset = font[fontset].set;
    int winx = x*charWidth;
    int winy = y*charHeight+font[fontset].ascent;
    // XwcDrawString will not fill background
    XwcDrawImageString(dpy, cast(Drawable)win, xfontset, gc, winx, winy, xbuf.ptr, cast(uint)dlen);
  }

  void drawString (int x, int y, const(dchar)[] str, usize fontset=FONTDEF) {
    if (charHeight < 1 || charWidth < 1) return;
    if (y < 0 || y*charHeight >= winHeight || str.length == 0 || x/charWidth >= winWidth) return;
    if (x < 0) {
      x = -x;
      if (x >= str.length) return;
      str = str[x..$];
      x = 0;
    }
    XFontSet xfontset = font[fontset].set;
    int winx = x*charWidth;
    int winy = y*charHeight+font[fontset].ascent;
    // XwcDrawString will not fill background
    XwcDrawImageString(dpy, cast(Drawable)win, xfontset, gc, winx, winy, str.ptr, cast(uint)str.length);
  }

  // ////////////////////////////////////////////////////////////////////// //
  void drawTermChar (int cx, int cy, bool asCursor=false) nothrow @trusted @nogc {
    if (cx >= 0 && cy >= 0 && cx < scrbuf.width && cy < scrbuf.height) {
      auto gl = scrbuf[cx, cy];
      ushort bg, fg, fontidx;
      getAttrBGFGFont(gl.attr, tab.reversed, bg, fg, fontidx);
      if (asCursor && isFocused) {
        ushort cbg = cast(ushort)(ActiveCursorColorBGIdx+mCurPhase);
        ushort cfg = ActiveCursorColorFGIdx;
        if (cbg < clrs[0].length) bg = cbg;
        if (cfg < clrs[0].length) fg = cfg;
      } else {
        if (scrbuf.isInSelection(cx, cy)) {
          immutable t = bg;
          bg = fg;
          fg = t;
        }
      }
      XSetBackground(dpy, gc, getColor(bg));
      XSetForeground(dpy, gc, getColor(fg));
      XFontSet xfontset = font[fontidx].set;
      auto ascent = font[fontidx].ascent;
      mDrawBuf.ptr[0] = gl.ch;
      XwcDrawImageString(dpy, cast(Drawable)win, xfontset, gc, cx*charWidth, cy*charHeight+ascent, mDrawBuf.ptr, 1);
      // draw rect
      if (asCursor && !isFocused && InactiveCursorColorFGIdx < clrs[0].length) {
        XSetForeground(dpy, gc, getColor(InactiveCursorColorFGIdx));
        XDrawRectangle(dpy, cast(Drawable)win, gc, cx*charWidth, cy*charHeight, charWidth-1, charHeight-1);
      }
      scrbuf.setDirtyAt(cx, cy, false);
    }
  }

  // ////////////////////////////////////////////////////////////////////// //
  void getAttrBGFGFont() (in Attr a, bool reversed, out ushort bg, out ushort fg, out ushort fontidx) {
    fontidx = (mOneFont ? FONTDEF : (a.bold ? FONTBOLD : FONTDEF));
    bg = (a.defaultBG ? DefaultBGColorIdx : a.bg);
    fg = (a.defaultFG ? DefaultFGColorIdx : a.fg);
    if (a.defaultFG) {
      if (a.bold) fg = BoldFGIdx;
      else if (a.underline) fg = UnderlineFGIdx;
    } else {
      // bold means "intensity" too
      if (a.bold && fg < 8) fg += 8;
    }
    if (a.reversed != reversed) {
      immutable t = bg;
      bg = fg;
      fg = t;
    }
  }

  // ////////////////////////////////////////////////////////////////////// //
  void drawGlyphsInLine (int x, int y, usize len, bool cursor=true) nothrow @trusted @nogc {
    if (y < 0 || y >= scrbuf.height || x >= scrbuf.width || len == 0) return;
    if (len > int.max/1024) len = int.max/1024;
    if (x < 0) {
      x = -x;
      if (x >= len) return;
      len -= x;
      x = 0;
    }
    if (x+len > scrbuf.width) {
      len = scrbuf.width-x;
      if (len == 0) return;
    }
    // now draw chars
    int winx = x*charWidth;
    immutable winy = y*charHeight;
    immutable int curx = scrbuf.curX;
    immutable int cury = scrbuf.curY;
    immutable bool curvis = scrbuf.curVisible;
    bool doSelection = scrbuf.lineHasSelection(y);
    bool cursorLine = (cursor && curvis && y == cury);
    while (len > 0) {
      // draw cursor char if we hit it
      if (cursorLine && x == curx) {
        drawTermChar(curx, cury, /*asCursor:*/true);
        ++x;
        winx += charWidth;
        --len;
        continue;
      }
      // get first char attributes
      ushort bg, fg, fontidx;
      auto gss = scrbuf[x, y];
      getAttrBGFGFont(gss.attr, tab.reversed, bg, fg, fontidx);
      XFontSet xfontset = font[fontidx].set;
      auto ascent = font[fontidx].ascent;
      if (doSelection && scrbuf.isInSelection(x, y)) {
        immutable t = fg;
        fg = bg;
        bg = t;
      }
      // now scan until something changed
      usize bpos = 0;
      immutable sx = x;
      uint ex = cast(uint)(x+len);
      if (cursor && curvis && y == cury && x < curx && ex > curx) ex = curx;
      while (bpos < ex-sx) {
        ushort bg1 = void, fg1 = void, fontidx1 = void;
        auto gg = scrbuf[x, y];
        getAttrBGFGFont(gg.attr, tab.reversed, bg1, fg1, fontidx1);
        if (doSelection && scrbuf.isInSelection(x, y)) {
          immutable t = fg1;
          fg1 = bg1;
          bg1 = t;
        }
        if (bg1 != bg || fg1 != fg || fontidx1 != fontidx) break;
        mDrawBuf.ptr[bpos++] = gg.ch;
        //ln.changeDirtyX(x, false);
        scrbuf.setDirtyAt(x, y, false);
        ++x;
      }
      assert(bpos <= len);
      // draw it
      XSetBackground(dpy, gc, getColor(bg));
      XSetForeground(dpy, gc, getColor(fg));
      XwcDrawImageString(dpy, cast(Drawable)win, xfontset, gc, winx, winy+ascent, mDrawBuf.ptr, cast(uint)bpos);
      // draw underline here
      winx += bpos*charWidth;
      len -= bpos;
    }
  }

  // ////////////////////////////////////////////////////////////////////// //
  // force redrawing
  void drawTermPixRect (int x, int y, int wdt, int hgt) nothrow @trusted @nogc {
    import std.algorithm : max, min;
    if (wdt < 1 || hgt < 1) return;
    // the following can overflow; idc
    if (x < 0) { wdt += x; x = 0; }
    if (y < 0) { hgt += y; y = 0; }
    // check it again
    if (wdt < 1 || hgt < 1) return;
    // default tty bg color
    XSetForeground(dpy, gc, getColor(DefaultBGColorIdx));
    // fill right part of the window if necessary
    if (x+wdt-1 >= scrbuf.width*charWidth) {
      XFillRectangle(dpy, cast(Drawable)win, gc, scrbuf.width*charWidth, y, x+wdt-scrbuf.width*charWidth, hgt);
    }
    // fill bottom part of the window if necessary
    if (y+hgt-1 >= scrbuf.height*charHeight) {
      XFillRectangle(dpy, cast(Drawable)win, gc, x, scrbuf.height*charWidth, wdt, y+hgt-scrbuf.height*charHeight);
    }
    // should we draw glyphs?
    if (x >= scrbuf.width*charWidth || y >= scrbuf.height*charHeight) return;
    int x0 = x/charWidth;
    int y0 = y/charHeight;
    int x1 = min((x+wdt-1)/charWidth, scrbuf.width-1);
    int y1 = min((y+hgt-1)/charHeight, scrbuf.height-1);
    foreach (immutable yy; y0..y1+1) drawGlyphsInLine(x0, yy, x1-x0+1);
  }

  void drawTermDirty () nothrow @trusted @nogc {
    //{ import core.stdc.stdio; printf("REDRAW! dc=%d\n", mScrBuf.mDirtyCount); }
    foreach (immutable y; 0..scrbuf.height) {
      if (!scrbuf.isDirtyLine(y)) continue;
      //{ import core.stdc.stdio; printf("REDRAW! y=%d\n", y); }
      uint x0 = 0;
      while (x0 < scrbuf.width) {
        // find first dirty glyph
        while (x0 < scrbuf.width && !scrbuf.isDirtyAt(x0, y)) ++x0;
        if (x0 >= scrbuf.width) break;
        // find last dirty glyph
        uint x1 = x0+1;
        while (x1 < scrbuf.width && !scrbuf.isDirtyAt(x1, y)) ++x1;
        drawGlyphsInLine(x0, y, x1-x0, /*cursor:*/true);
        x0 = x1;
      }
    }
  }

  // ////////////////////////////////////////////////////////////////////// //
  // operates in character cells
  // WARNING! don't pass invalid args!
  void xcopytty (int dx, int dy, int sx, int sy, int wdt, int hgt) nothrow @trusted @nogc {
    if (wdt < 1 || hgt < 1 || (sx == dx && sy == dy)) return;
    dx *= charWidth;
    dy *= charHeight;
    sx *= charWidth;
    sy *= charHeight;
    wdt *= charWidth;
    hgt *= charHeight;
    XCopyArea(dpy, cast(Drawable)win, cast(Drawable)win, gc,
      // src
      sx, sy, wdt, hgt,
      // dst
      dx, dy);
  }

  void undrawCursor () nothrow @trusted @nogc {
    if (!tab.prevcurVis) return;
    drawTermChar(tab.prevcurX, tab.prevcurY, /*asCursor:*/false);
  }

  void drawCursor () nothrow @trusted @nogc {
    if (!tab.prevcurVis) return;
    drawTermChar(tab.prevcurX, tab.prevcurY, /*asCursor:*/true);
  }

  // ////////////////////////////////////////////////////////////////////// //
  void doneSelection () {
    if (mDoSelection) {
      mDoSelection = false;
      mCurSelection = scrbuf.getSelectionText();
      if (mCurSelection.length == 0) mCurSelection = null;
      // own selection
      XSetSelectionOwner(dpy, XA_PRIMARY, win, CurrentTime);
      XSetSelectionOwner(dpy, xaClipboard, win, CurrentTime);
      XFlush(dpy);
    }
    scrbuf.doneSelection();
  }

  void xdoMouseReport (ref XEvent e) {
    uint x = e.xbutton.x/charWidth;
    uint y = e.xbutton.y/charHeight;
    e.xbutton.state &= (Mod1Mask|Mod4Mask|ControlMask|ShiftMask);

    if (mDoSelection) {
      if (x >= scrbuf.width) x = scrbuf.width-1;
      if (y >= scrbuf.height) y = scrbuf.height-1;
      mSelLastX = x;
      mSelLastY = y;
      scrbuf.selectionChanged(x, y);
      if (e.xbutton.type == ButtonRelease && e.xbutton.button == 1) doneSelection();
      return;
    }

    if (e.xbutton.state == ShiftMask && e.xbutton.type == ButtonPress && e.xbutton.button == 1) {
      // selection
      if (x >= scrbuf.width) x = scrbuf.width-1;
      if (y >= scrbuf.height) y = scrbuf.height-1;
      mSelLastX = x;
      mSelLastY = y;
      scrbuf.resetSelection();
      scrbuf.selectionChanged(x, y);
      mDoSelection = true;
      return;
    }

    auto button = cast(ubyte)(e.xbutton.button-Button1+1);
    uint mods;
    VT100Emu.MouseEvent event;

    switch (e.xbutton.type) {
      case MotionNotify: event = VT100Emu.MouseEvent.Motion; break;
      case ButtonPress: event = VT100Emu.MouseEvent.Down; break;
      case ButtonRelease: event = VT100Emu.MouseEvent.Up; break;
      default: return;
    }

    mods =
      (e.xbutton.state&ShiftMask ? VT100Emu.MouseMods.Shift : 0) |
      (e.xbutton.state&Mod1Mask ? VT100Emu.MouseMods.Meta : 0) |
      (e.xbutton.state&ControlMask ? VT100Emu.MouseMods.Ctrl : 0) |
      (e.xbutton.state&Mod4Mask ? VT100Emu.MouseMods.Hyper : 0);

    scrbuf.doMouseReport(x, y, event, button, mods);
  }

  void processResize (XConfigureEvent *e) {
    import std.algorithm : max, min;
    if (e.width < 1 || e.height < 1) return;
    winWidth = e.width;
    winHeight = e.height;
    int cols = max(MinBufferWidth, min(MaxBufferWidth, e.width/charWidth));
    int rows = max(MinBufferHeight, min(MaxBufferHeight, (e.height-charHeight)/charHeight));
    if (cols == scrbuf.width && rows == scrbuf.height) return;
    // do terminal resize
    tab.onResize(cols, rows);
  }

  void selRequest (Atom which) {
    if (XGetSelectionOwner(dpy, which) != None) {
      XConvertSelection(dpy, which, xaTargets, xaVTSelection, win, CurrentTime);
    }
  }

  void preparePaste (XSelectionEvent* ev) {
    import core.stdc.config;
    c_ulong nitems, ofs, rem;
    int format;
    ubyte* data;
    Atom type;
    bool isutf8;
    int wasbrk = 0;
    ubyte[4] ucbuf;
    usize ucbufused;
    if (ev.property != xaVTSelection) return;
    if (ev.target == xaUTF8) {
      isutf8 = true;
    } else if (ev.target == XA_STRING) {
      isutf8 = false;
    } else if (ev.target == xaTargets) {
      // list of targets arrived, select appropriate one
      Atom rqtype = cast(Atom)None;
      Atom* targ;
      if (XGetWindowProperty(dpy, win, ev.property, 0, 65536, False, XA_ATOM, &type, &format, &nitems, &rem, &data)) {
        rqtype = XA_STRING;
      } else {
        // prefer UTF-8
        for (targ = cast(Atom*)data; nitems > 0; --nitems, ++targ) {
          if (*targ == xaUTF8) rqtype = xaUTF8;
          else if (*targ == XA_STRING && rqtype == None) rqtype = XA_STRING;
        }
        XFree(data);
      }
      if (rqtype != None) XConvertSelection(dpy, ev.selection, rqtype, xaVTSelection, win, CurrentTime);
      return;
    } else {
      { import core.stdc.stdio; auto aname = atomName(ev.target); stderr.fprintf("unknown selection comes: '%.*s'", cast(uint)aname.length, aname.ptr); }
      return;
    }
    // got it
    enum BUFSIZ = 8192;
    ofs = 0;
    enum doconv = false; //(isutf8 ? !curterm.isUTF8 : curterm.isUTF8);
    //{ import iv.writer; writeln("isutf8: ", isutf8, "; doconv: ", doconv); }
    bool wasbrp = false;
    /+!!!
    if (curterm.bracketPaste && !wasbrp) {
      wasbrp = true;
      curterm.putData("\x1b[200~");
    }
    +/
    do {
      int blen;
      //char *str;
      if (XGetWindowProperty(dpy, win, ev.property, ofs, BUFSIZ/4, False, AnyPropertyType, &type, &format, &nitems, &rem, &data)) {
        //fprintf(stderr, "Clipboard allocation failed\n");
        break;
      }
      blen = cast(int)(nitems*format/8);
      if (blen) {
        //{ import iv.writer; writeln("data: [", (cast(const(char)*)data)[0..blen], "]"); }
        static if (doconv) {
          // we must convert data first
          if (isutf8) {
            //{ import iv.writer; writeln("utf->koi: data: [", (cast(const(char)*)data)[0..blen], "]"); }
            // we receiving utf8 text which must be converted to koi
            usize pos = 0;
            while (pos < blen) {
              if (ucbufused) {
                // we have partial utf char, try to complete it
                wchar wch;
                //{ import iv.writer; writefln!"utf continues (0x%02X); valid cont: %s"(data[pos], isValidUtf8Cont(cast(char)data[pos])); }
                if (isValidUtf8Cont(cast(char)data[pos])) {
                  ucbuf[ucbufused++] = cast(char)data[pos++];
                  if (utf8Decode(&wch, ucbuf[0..ucbufused])) {
                    // valid UTF
                    //{ import iv.writer; writeln("good utf, len=", ucbufused); }
                    char[1] ch = uni2koi(wch);
                    curterm.putData(ch);
                    ucbufused = 0;
                  } else if (ucbufused == ucbuf.length) {
                    // invalid UTF
                    curterm.putData(cast(char[])ucbuf[]);
                    ucbufused = 0;
                  }
                  continue;
                } else {
                  // this is not valid UTF continuation char, flush buffer
                  curterm.putData(cast(char[])ucbuf[0..ucbufused]);
                  ucbufused = 0;
                }
              }
              assert(ucbufused == 0);
              usize end = pos;
              while (end < blen && !isValidUtf8Start(data[end])) ++end;
              if (end > pos) {
                curterm.putData((cast(const(char)*)data)[pos..end]);
                pos = end;
                if (pos >= blen) break;
              }
              //{ import iv.writer; writeln("utf start at ", pos); }
              // this is valid UTF start char
              ucbuf[ucbufused++] = data[pos++];
            }
          } else {
            // we receiving non-utf8 text which must be converted to utf
            usize pos = 0;
            while (pos < blen) {
              usize end = pos;
              while (end < blen && data[end] < 0x80) ++end;
              if (end > pos) {
                curterm.putData((cast(const(char)*)data)[pos..end]);
                pos = end;
                continue;
              }
              // got koi char
              wchar ch = koi2uni(cast(char)data[pos++]);
              curterm.putData(utf8Encode(ucbuf[], ch));
            }
          }
        } else {
          //!!!curterm.putData((cast(const(char)*)data)[0..blen]);
        }
      }
      XFree(data);
      // number of 32-bit chunks returned
      ofs += nitems*format/32;
    } while (rem > 0);
    //!!!if (ucbufused > 0) curterm.putData(cast(char[])ucbuf[0..ucbufused]);
    //{ import iv.writer; writeln("no more data!"); }
    //!!!if (wasbrp) curterm.putData("\x1b[201~");
  }

  void prepareCopy (XSelectionRequestEvent* ev) {
    XSelectionEvent xev;
    string text = mCurSelection;
    if (text.length == 0) text = ""; // let it point to something
    xev.type = SelectionNotify;
    xev.requestor = ev.requestor;
    xev.selection = ev.selection;
    xev.target = ev.target;
    xev.time = ev.time;
    // reject
    xev.property = cast(Atom)None;
    if (ev.target == xaTargets) {
      // respond with the supported type
      Atom[3] tlist = [xaUTF8, XA_STRING, xaTargets];
      XChangeProperty(ev.display, ev.requestor, ev.property, XA_ATOM, 32, PropModeReplace, cast(ubyte*)tlist.ptr, 3);
      xev.property = ev.property;
    } else if (ev.target == xaUTF8 || ev.target == XA_STRING) {
      // maybe i should convert from utf for XA_STRING, but i don't care
      XChangeProperty(ev.display, ev.requestor, ev.property, ev.target, 8, PropModeReplace,
        cast(ubyte*)text.ptr, cast(uint)text.length);
      xev.property = ev.property;
    }
    /* all done, send a notification to the listener */
    if (!XSendEvent(ev.display, ev.requestor, True, 0, cast(XEvent*)&xev)) {
      //fprintf(stderr, "Error sending SelectionNotify event\n");
    }
  }

  void clearSelection (XSelectionClearEvent* ev) {
    // do nothing
  }

  bool processXEvents () {
    void keypressEvent (ref XKeyEvent e) {
      // blank pointer on any keyboard event
      if (OptPtrBlankTime > 0) blankPointer();
      KeySym ksym = NoSymbol;
      Status status;
      //immutable meta = ((e.state&Mod1Mask) != 0);
      //immutable shift = ((e.state&ShiftMask) != 0);
      dchar ch;
      auto len = XwcLookupString(xic, &e, &ch, 1, &ksym, &status);
      // if "alt" (aka "meta") is pressed, get keysym name with ignored language switches
      if (e.state&(Mod1Mask|ControlMask)) ksym = XLookupKeysym(&e, 0);
      if (len != 1) ch = 0;
      // leave only known mods
      //e.state &= ~Mod2Mask; // numlock
      e.state &= (Mod1Mask|Mod4Mask|ControlMask|ShiftMask);
      // paste selections
      if (ksym == XK_Insert && (e.state&(Mod1Mask|ShiftMask)) != 0 && (e.state&~(Mod1Mask|ShiftMask)) == 0) {
        // shift: primary
        // alt: clipboard
        // alt+shift: secondary
             if (e.state == ShiftMask) selRequest(XA_PRIMARY);
        else if (e.state == Mod1Mask) selRequest(xaClipboard);
        else selRequest(XA_SECONDARY);
        return;
      }
      tab.keypressEvent(ch, ksym, X11ModState(e.state));
    }

    // event processing loop
    bool quit = false;
    XEvent event = void;
    while (!quit && XPending(dpy)) {
      XNextEvent(dpy, &event);
      if (XFilterEvent(&event, cast(Window)0)) continue;
      if (event.type == KeymapNotify) {
        XRefreshKeyboardMapping(&event.xmapping);
        continue;
      }
      if (event.xany.window != win) {
        //{ import iv.writer; writeln("CRAP!"); }
        continue;
      }

      switch (event.type) {
        case ClientMessage:
          if (event.xclient.message_type == xaWMProtocols) {
            if (cast(Atom)event.xclient.data.l[0] == xaWMDeleteWindow) {
              quit = true;
            }
          } else if (event.xclient.message_type == xaTerminalMessage) {
            if (event.xclient.data.l[0] == WinMsgDirty) {
              drawTermDirty();
            }
          }
          break;
        case KeyPress:
          keypressEvent(event.xkey);
          break;
        case Expose:
          if (!mForceRedraw) {
            auto ee = cast(XExposeEvent*)&event;
            drawTermPixRect(ee.x, ee.y, ee.width, ee.height);
            // fix last redraw time if no dirty areas left
            if (!scrbuf.isDirty) resetRedrawInfo();
          }
          break;
        case GraphicsExpose:
          if (!mForceRedraw) {
            drawTermPixRect(event.xgraphicsexpose.x, event.xgraphicsexpose.y, event.xgraphicsexpose.width, event.xgraphicsexpose.height);
            // fix last redraw time if no dirty areas left
            if (!scrbuf.isDirty) resetRedrawInfo();
          }
          //event.xgraphicsexpose.count
          break;
        case VisibilityNotify:
          if (event.xvisibility.state == VisibilityFullyObscured) {
            mWinState &= ~wsVisible;
          } else {
            mWinState |= wsVisible;
          }
          break;
        case FocusIn:
          XSetICFocus(xic);
          if (!(mWinState&wsFocused)) {
            mWinState |= wsFocused;
            scrbuf.onBlurFocus(true);
          }
          break;
        case FocusOut:
          doneSelection();
          XUnsetICFocus(xic);
          if (mWinState&wsFocused) {
            mWinState &= ~wsFocused;
            scrbuf.onBlurFocus(false);
          }
          break;
        case MotionNotify:
        case ButtonPress:
        case ButtonRelease:
          unblankPointer();
          xdoMouseReport(event);
          break;
        case SelectionNotify:
          // we got our requested selection, and should paste it
          preparePaste(&event.xselection);
          break;
        case SelectionRequest:
          prepareCopy(&event.xselectionrequest);
          break;
        case SelectionClear:
          clearSelection(&event.xselectionclear);
          break;
        case ConfigureNotify:
          processResize(&event.xconfigure);
          break;
        default:
      }
    }
    return quit;
  }

  // ////////////////////////////////////////////////////////////////////// //
  void resetRedrawInfo () nothrow @trusted @nogc {
    mLastDrawTime = MonoTime.currTime;
    mForceRedraw = false;
    mForceDirtyRedraw = false;
  }

  void fullRedraw () nothrow @trusted @nogc {
    drawTermPixRect(0, 0, winWidth, winHeight);
    resetRedrawInfo();
  }

  // ////////////////////////////////////////////////////////////////////// //
  void mainLoop () {
    import std.algorithm : max;
    import core.sys.posix.sys.select;
    import core.sys.posix.sys.time : timeval;
    fd_set rds, wrs;
    int maxfd;
    bool mPrevFocused = false;

    void addRFD (int fd) {
      if (fd >= 0) {
        if (fd+1 > maxfd) maxfd = fd+1;
        FD_SET(fd, &rds);
      }
    }

    void addWFD (int fd) {
      if (fd >= 0) {
        if (fd+1 > maxfd) maxfd = fd+1;
        FD_SET(fd, &wrs);
      }
    }

    bool timeToHidePointer () {
      return (OptPtrBlankTime > 0 ? (MonoTime.currTime-mLastInputTime).total!"msecs" >= OptPtrBlankTime : false);
    }

    // <0: no blinking
    int msUntilNextCursorBlink () {
      if (!isVisible) return -1;
      if (isFocused != mPrevFocused) return 0; // must update cursor NOW!
      if (!scrbuf.curVisible && !tab.prevcurVis) return -1; // nothing was changed
      auto now = MonoTime.currTime;
      if (isFocused) {
        // blinking
        auto ntt = (now-mCurLastPhaseChange).total!"msecs";
        if (ntt >= OptPtrBlinkTime) return 0; // NOW!
        if (scrbuf.curVisible != tab.prevcurVis || scrbuf.curX != tab.prevcurX || scrbuf.curY != tab.prevcurY) {
          ntt = OptPtrBlinkTime-ntt;
          // check last move time
          auto lmt = (now-mCurLastMove).total!"msecs";
          if (lmt >= 50) return 0; // NOW! -- cursor state changed
          if (50-lmt < ntt) return cast(int)(50-lmt);
        }
        return cast(int)ntt;
      } else {
        // not blinking, check last move time
        if (scrbuf.curVisible == tab.prevcurVis && scrbuf.curX == tab.prevcurX && scrbuf.curY == tab.prevcurY) return -1; // never
        auto lmt = (now-mCurLastMove).total!"msecs";
        if (lmt >= 150) return 0; // NOW! -- cursor state changed
        return cast(int)(150-lmt);
      }
    }

    // <0: already hidden, or not required
    int msUntilPointerHiding () {
      if (!isVisible || !isFocused || !mPointerVisible || OptPtrBlankTime < 1) return -1;
      auto now = MonoTime.currTime;
      auto ntt = (now-mLastInputTime).total!"msecs";
      if (ntt >= OptPtrBlankTime) return 0; // NOW!
      return cast(int)(OptPtrBlankTime-ntt);
    }

    @property int redrawDelay () nothrow @trusted @nogc { return (isFocused ? RedrawRateActive : RedrawRateInactive); }

    // <0: no redraw required
    int msUntilRedraw () {
      if (!isVisible || !scrbuf.isDirty) return -1;
      auto now = MonoTime.currTime;
      auto ntt = (now-mLastDrawTime).total!"msecs";
      if (ntt >= redrawDelay) return 0; // NOW!
      return cast(int)(redrawDelay-ntt);
    }

    void doCursorBlink () {
      bool doCursorRedraw = false;
      auto now = MonoTime.currTime;
      if (scrbuf.curVisible != tab.prevcurVis || scrbuf.curX != tab.prevcurX || scrbuf.curY != tab.prevcurY) {
        if (tab.prevcurVis) {
          if (!scrbuf.isDirty) {
            drawTermChar(tab.prevcurX, tab.prevcurY, /*asCursor:*/false);
          } else {
            scrbuf.setDirtyAt(tab.prevcurX, tab.prevcurY, true);
          }
        }
        tab.prevcurVis = scrbuf.curVisible;
        if (tab.prevcurVis) doCursorRedraw = true;
        tab.prevcurX = scrbuf.curX;
        tab.prevcurY = scrbuf.curY;
        mCurLastMove = now;
      }
      if (isFocused) {
        if (!mPrevFocused) {
          // window was not focused, force cursor redraw
          doCursorRedraw = true;
          mCurPhase = 0;
        } else if ((now-mCurLastPhaseChange).total!"msecs" >= OptPtrBlinkTime) {
          // window was focused and cursor must blink
          mCurPhase ^= 1;
          doCursorRedraw = true;
        }
      } else {
        // not focused
        doCursorRedraw = (scrbuf.curVisible && (mPrevFocused || mCurPhase != 0));
        mCurPhase = 0;
      }
      if (scrbuf.curVisible && doCursorRedraw) {
        if (isFocused == mPrevFocused && scrbuf.isDirty || msUntilRedraw == 0) {
          // mark current cursor cell as dirty, redraw will follow
          scrbuf.setDirtyAt(scrbuf.curX, scrbuf.curY, true);
        } else {
          // immediate redraw
          drawTermChar(scrbuf.curX, scrbuf.curY, /*asCursor:*/true);
          XFlush(dpy);
        }
      }
      if (doCursorRedraw) mCurLastPhaseChange = now;
      mPrevFocused = isFocused;
    }

    // return true if we should exit
    bool doXEvents () {
      immutable ovs = isVisible;
      if (processXEvents()) return true;
      if (ovs != isVisible) {
        // visibility changed
        if (!isVisible) {
          // becomes hidden, cancel any pending redraw
          mForceRedraw = false;
        } else {
          // becomes visible, do full redraw
          // don't need that, as Expose will redraw damaged areas
          /*
          mForceRedraw = true;
          */
        }
      }
      return false;
    }

    // find max possible wait interval (0: don't wait at all; -1: forever)
    int calcMaxWaitTime () {
      if (isVisible) {
        if (isFocused != mPrevFocused) return 0; // now!
        int ntt = msUntilNextCursorBlink();
        //{ import core.stdc.stdio; printf("until blink: %d\n", ntt); }
        if (ntt == 0) return 0; // now!
        {
          int ntt1 = msUntilPointerHiding();
          //{ import core.stdc.stdio; printf("until hide: %d\n", ntt1); }
          if (ntt1 == 0) return 0; // now!
          if (ntt < 0 || (ntt1 >= 0 && ntt > ntt1)) ntt = ntt1;
        }
        {
          int ntt1 = msUntilRedraw();
          //{ import core.stdc.stdio; printf("until redraw: %d\n", ntt1); }
          if (ntt1 == 0) return 0; // now!
          if (ntt < 0 || (ntt1 >= 0 && ntt > ntt1)) ntt = ntt1;
        }
        //{ import core.stdc.stdio; printf("RES: %d\n", ntt); }
        return (ntt > 0 ? ntt+1 : ntt); // add one msec to really trigger the event
      } else {
        // window is invisible, we can ignore any timed events
        return -1; // forever
      }
    }

    mCurLastPhaseChange = MonoTime.currTime;
    mCurLastMove = mCurLastPhaseChange;
    mCurPhase = 0;
    mPrevFocused = isFocused;
    if (tab.checkFixProcess()) changeTitle(tab.mLastProcess[0..tab.mLastProcessLength]);
    fullRedraw();
    XFlush(dpy);
    mPointerVisible = false;
    unblankPointer();
    int xfd = XConnectionNumber(dpy);
    main_loop: for (;;) {
      immutable waitTimeMS = calcMaxWaitTime();
      maxfd = 0;
      FD_ZERO(&rds);
      FD_ZERO(&wrs);
      // setup misc sockets
      addRFD(xfd);
      addRFD(csigfd);
      foreach (immutable int fd; tab.appbuf.getReadFDs) if (fd >= 0) addRFD(fd);
      foreach (immutable int fd; tab.appbuf.getWriteFDs) if (fd >= 0) addWFD(fd);
      int sres = 0;
      if (waitTimeMS >= 0) {
        timeval tv;
        tv.tv_sec = waitTimeMS/1000;
        tv.tv_usec = (waitTimeMS%1000)*1000;
        //{ import core.stdc.stdio; printf("wait(0:%d)\n", waitTimeMS); }
        sres = select(maxfd, &rds, &wrs, null, &tv);
        //{ import core.stdc.stdio; printf("wait(1:%d)\n", waitTimeMS); }
      } else {
        // forever
        //{ import core.stdc.stdio; printf("forever(0)\n"); }
        sres = select(maxfd, &rds, &wrs, null, null);
        //{ import core.stdc.stdio; printf("forever(1)\n"); }
      }
      if (sres < 0) {
        import core.stdc.errno;
        if (errno == EINTR) continue;
        die("select() error");
      }
      if (sres == 0) {
        // timeout
        //continue;
      }
      // check if terminal is dead
      if (csigfd >= 0 && FD_ISSET(csigfd, &rds)) processDeadChildren();
      // blink cursor
      doCursorBlink();
      // process X events
      if (doXEvents()) break;
      // send generated data to app; this can't trigger updates
      // also, read data from app and write it to terminal
      foreach (immutable int fd; tab.appbuf.getWriteFDs) if (fd >= 0 && FD_ISSET(fd, &wrs)) tab.appbuf.canWriteTo(fd);
      foreach (immutable int fd; tab.appbuf.getReadFDs) if (fd >= 0 && FD_ISSET(fd, &rds)) tab.appbuf.canReadFrom(fd);
      // update window
      auto nowTime = MonoTime.currTime;
      bool doFlush = false;
      // do immediate full redraw only if we are focused
      if (mForceRedraw && !isFocused) {
        mForceRedraw = false;
        scrbuf.setFullDirty();
      }
      if (mForceRedraw) {
        //{ import core.stdc.stdio; stderr.fprintf("FORCE REDRAW!\n"); }
        fullRedraw();
        doFlush = true;
      } else {
        if (mForceDirtyRedraw || msUntilRedraw == 0) {
          if (scrbuf.isDirty) {
            //{ import core.stdc.stdio; stderr.fprintf("DIRTY REDRAW!\n"); }
            drawTermDirty();
            resetRedrawInfo();
            doFlush = true;
          } else {
            resetRedrawInfo();
          }
        }
      }
      if (timeToHidePointer) blankPointer();
      // fix title
      if ((nowTime-mLastTitleChangeTime).total!"msecs" >= 500) {
        if (tab.checkFixProcess()) {
          changeTitle(tab.mLastProcess[0..tab.mLastProcessLength]);
          doFlush = false; // flush already done
        }
        mLastTitleChangeTime = nowTime;
      }
      if (doFlush) XFlush(dpy);
      // exit on dead pty
      if (!tab.appbuf.isPtyActive) break;
    }
  }
}


void usage () {
  write("usage: sampleterm [runcmd...]\n");
  throw new ExitException();
}


string[] processCLIArgs (string[] args) {
  string[] res = [args[0]];
  bool noMoreArgs = false;
  for (usize aidx = 1; aidx < args.length; ++aidx) {
    auto arg = args[aidx];
    if (noMoreArgs || arg.length == 0 || arg[0] != '-') {
      res ~= args[aidx];
      continue;
    }
    if (arg == "--") { noMoreArgs = true; continue; }
    stderr.writeln("FATAL: unknown option: ", arg.quote);
    throw new ExitError();
  }
  return res;
}


int main (string[] args) {
  try {
    args = processCLIArgs(args);
    auto xw = new DiWindow(80, 24);
    xw.changeTitle("DiTTY sample terminal");
    xw.appbuf.execPty(args[1..$]);
    xw.mainLoop();
    xw.close();
    return 0;
  } catch (ExitException e) {
    if (cast(ExitError)e) return -1;
    return 0;
  }
}
