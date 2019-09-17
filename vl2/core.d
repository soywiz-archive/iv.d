/* Invisible Vector Library
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
module iv.vl2.core /*is aliced*/;

import iv.alice;
public import iv.sdl2.sdl;

private import core.sys.posix.time;
// idiotic phobos forgets 'nothrow' at it
extern(C) private int clock_gettime (clockid_t, timespec*) @trusted nothrow @nogc;


version(GNU) {
  static import gcc.attribute;
  private enum gcc_inline = gcc.attribute.attribute("forceinline");
  private enum gcc_noinline = gcc.attribute.attribute("noinline");
  private enum gcc_flatten = gcc.attribute.attribute("flatten");
} else {
  // hackery for non-gcc compilers
  private enum gcc_inline;
  private enum gcc_noinline;
  private enum gcc_flatten;
}


// ////////////////////////////////////////////////////////////////////////// //
/// generic VideoLib exception
class VideoLibError : Exception {
  this (string msg, string file=__FILE__, usize line=__LINE__, Throwable next=null) @safe pure nothrow @nogc {
    super(msg, file, line, next);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
/// output filter
enum VLFilter {
  None,
  Green,
  BlackNWhite
}


/// is videolib initialized?
enum VLInitState {
  Not, /// no
  Partial, /// not fully (i.e. `vlInit()` failed in the middle)
  Done /// completely initialized
}


// ////////////////////////////////////////////////////////////////////////// //
private shared VLInitState pvInited = VLInitState.Not;

/// is VideoLib properly initialized and videomode set?
@property VLInitState vlInitState () @trusted nothrow @nogc {
  import core.atomic : atomicLoad;
  return atomicLoad(pvInited);
}

// ////////////////////////////////////////////////////////////////////////// //
shared bool vlFullscreen = false; /// use fullscreen mode? this can be set to true before calling vlInit()
shared bool vlRealFullscreen = false; /// use 'real' fullscreen? defaul: false
shared bool vlVSync = false; /// wait VBL? this can be set to true before calling initVideo()
shared bool vlMag2x = true; // set to true to create double-sized window; default: true; have no effect after calling vlInit()
shared bool vlScanlines = true; // set to true to use 'scanline' filter in mag2x mode; default: true
shared VLFilter vlFilter = VLFilter.None; /// output filter; default: VLFilter.None

__gshared SDL_Window* sdlWindow = null; /// current SDL window; DON'T CHANGE THIS!


// ////////////////////////////////////////////////////////////////////////// //
private __gshared SDL_Renderer* sdlRenderer = null; // current SDL rendering context
private __gshared SDL_Texture* sdlScreen = null; // current SDL screen

private shared bool sdlFrameChangedFlag = false; // this will be set to false by vlPaintFrame()

package __gshared void function () vlInitHook = null;
package __gshared void function () vlDeinitHook = null;


// ////////////////////////////////////////////////////////////////////////// //
/// call this if you want VideoLib to call rebuild callback
void vlFrameChanged () @trusted nothrow @nogc {
  import core.atomic : atomicStore;
  atomicStore(sdlFrameChangedFlag, true);
}

@property bool vlIsFrameChanged () @trusted nothrow @nogc {
  import core.atomic : atomicLoad;
  return atomicLoad(sdlFrameChangedFlag);
}

/// screen dimensions, should be changed prior to calling vlInit()
private shared uint vsWidth = 320;
private shared uint vsHeight = 240;

/// get current screen width
@property uint vlWidth() () @trusted nothrow @nogc {
  import core.atomic : atomicLoad;
  return atomicLoad(vsWidth);
}

/// get current screen height
@property uint vlHeight() () @trusted nothrow @nogc {
  import core.atomic : atomicLoad;
  return atomicLoad(vsHeight);
}

/// set screen width; must be used before vlInit()
@property void vlWidth (int wdt) @trusted {
  import core.atomic : atomicLoad, atomicStore;
  if (atomicLoad(pvInited) != VLInitState.Not) throw new VideoLibError("trying to change screen width after initialization");
  if (wdt < 1 || wdt > 8192) throw new VideoLibError("invalid screen width");
  atomicStore(vsWidth, wdt);
}

/// set screen height; must be used before vlInit()
@property void vlHeight (int hgt) @trusted {
  import core.atomic : atomicLoad, atomicStore;
  if (atomicLoad(pvInited) != VLInitState.Not) throw new VideoLibError("trying to change screen height after initialization");
  if (hgt < 1 || hgt > 8192) throw new VideoLibError("invalid screen height");
  atomicStore(vsHeight, hgt);
}

private __gshared int effectiveMag2x; // effective vlMag2x
private __gshared SDL_Texture* sdlScr2x = null;
private __gshared int prevLogSizeWas1x = 0; // DON'T change to bool!

__gshared uint* vlVScr = null; /// current SDL 'virtual screen', ARGB format for LE
private __gshared uint* vscr2x = null; // this is used in magnifying blitters


// ////////////////////////////////////////////////////////////////////////// //
/**
 * Process CLI args from main().
 *
 * Params:
 *  args = command line arguments
 *
 * Returns:
 *  command line with processed arguments removed
 */
void vlProcessArgs (ref string[] args) @trusted nothrow {
 main_loop:
  for (uint idx = 1; idx < args.length; ++idx) {
    auto arg = args[idx];
    if (arg == "--") break;
    if (arg.length < 3 || arg[0] != '-' || arg[1] != '-') continue;
    bool yes = true;
    if (arg.length > 5 && arg[2..5] == "no-") {
      yes = false;
      arg = arg[5..$];
    } else {
      arg = arg[2..$];
    }
    switch (arg) {
      case "fs": vlFullscreen = yes; break;
      case "win": vlFullscreen = !yes; break;
      case "realfs": vlRealFullscreen = yes; break;
      case "winfs": vlRealFullscreen = !yes; break;
      case "tv": vlScanlines = yes; break;
      case "bw": if (yes) vlFilter = VLFilter.BlackNWhite; break;
      case "green": if (yes) vlFilter = VLFilter.Green; break;
      case "1x": vlMag2x = !yes; break;
      case "2x": vlMag2x = yes; break;
      case "vbl": vlVSync = yes; break;
      case "vhelp":
        if (yes) {
          import core.stdc.stdlib : exit;
          import std.exception : collectException;
          import std.stdio : stdout;
          collectException(stdout.write(
            "video options (add \"no-\" to negate):\n"~
            "  --fs      fullscreen\n"
            "  --win     windowed\n"
            "  --realfs  use \"real\" fullscreen\n"
            "  --winfs   use \"windowed\" fullscreen\n"
            "  --tv      scanlines filter\n"
            "  --bw      black-and-white filter\n"
            "  --green   green filter\n"
            "  --1x      normal size\n"
            "  --2x      magnify\n"
            "  --vbl     vsync\n"));
          exit(0);
        }
        break;
      default: continue main_loop;
    }
    // remove option
    foreach (immutable c; idx+1..args.length) args[c-1] = args[c];
    args.length -= 1;
    --idx; // compensate for removed element
  }
}


private void sdlPrintError () @trusted nothrow @nogc {
  import core.stdc.stdio : stderr, fprintf;
  auto sdlError = SDL_GetError();
  fprintf(stderr, "SDL ERROR: %s\n", sdlError);
}


private void sdlError (bool raise) @trusted {
  if (raise) {
    sdlPrintError();
    throw new VideoLibError("SDL fucked");
  }
}


/**
 * Initialize SDL, create drawing window and buffers, init other shit.
 *
 * Params:
 *  windowName = window caption
 *
 * Returns:
 *  nothing
 *
 * Throws:
 *  VideoLibError on error
 */
void vlInit (string windowName=null) @trusted {
  import core.atomic : atomicLoad, atomicStore;

  final switch (atomicLoad(pvInited)) with (VLInitState) {
    case Not: break;
    case Partial: throw new VideoLibError("can't continue initialization");
    case Done: return;
  }

  import core.exception : onOutOfMemoryError;
  import core.stdc.stdlib : malloc, free;
  import std.string : toStringz;

  vlDeinitInternal();
  if (windowName is null) windowName = "SDL Application";

  effectiveMag2x = (vlMag2x ? 2 : 1);
  prevLogSizeWas1x = 1;

  if (vlVScr !is null) free(vlVScr);
  vlVScr = cast(uint*)malloc(vsWidth*vsHeight*vlVScr[0].sizeof);
  if (vlVScr is null) onOutOfMemoryError();

  if (vscr2x !is null) free(vscr2x);
  vscr2x = cast(uint*)malloc(vsWidth*effectiveMag2x*vsHeight*effectiveMag2x*vscr2x[0].sizeof);
  if (vscr2x is null) onOutOfMemoryError();

  SDL_Init(SDL_INIT_VIDEO|SDL_INIT_EVENTS|SDL_INIT_TIMER);
  atomicStore(pvInited, VLInitState.Partial);

  sdlWindow = SDL_CreateWindow(
    windowName.toStringz,
    SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
    vsWidth*effectiveMag2x, vsHeight*effectiveMag2x,
    (vlFullscreen ? (vlRealFullscreen ? SDL_WINDOW_FULLSCREEN : SDL_WINDOW_FULLSCREEN_DESKTOP) : 0));
  sdlError(!sdlWindow);

  sdlRenderer = SDL_CreateRenderer(sdlWindow, -1, (vlVSync ? SDL_RENDERER_PRESENTVSYNC : 0));
  sdlError(!sdlRenderer);

  SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, "nearest"); // "nearest" or "linear"
  SDL_RenderSetLogicalSize(sdlRenderer, vsWidth*(2-prevLogSizeWas1x), vsHeight*(2-prevLogSizeWas1x));

  sdlScreen = SDL_CreateTexture(sdlRenderer, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STREAMING, vsWidth, vsHeight);
  sdlError(!sdlScreen);

  if (effectiveMag2x == 2) {
    sdlScr2x = SDL_CreateTexture(sdlRenderer, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STREAMING, vsWidth*2, vsHeight*2);
    sdlError(!sdlScr2x);
  } else {
    sdlScr2x = null;
  }

  if (vlInitHook !is null) vlInitHook();

  atomicStore(pvInited, VLInitState.Done);
}


/*
 * Deinitialize SDL, free resources.
 *
 * Params:
 *  none
 *
 * Returns:
 *  nothing
 */
private void vlDeinitInternal () /*@trusted nothrow @nogc*/ {
  import core.atomic : atomicLoad, atomicStore;
  import core.stdc.stdlib : free;

  if (atomicLoad(pvInited) == VLInitState.Not) return;

  if (vlDeinitHook !is null) vlDeinitHook();

  if (sdlScreen !is null) { SDL_DestroyTexture(sdlScreen); sdlScreen = null; }
  if (sdlScr2x !is null) { SDL_DestroyTexture(sdlScr2x); sdlScr2x = null; }
  if (sdlRenderer !is null) { SDL_DestroyRenderer(sdlRenderer); sdlRenderer = null; }
  if (sdlWindow) { SDL_DestroyWindow(sdlWindow); sdlWindow = null; }
  if (vlVScr !is null) { free(vlVScr); vlVScr = null; }
  if (vscr2x !is null) { free(vscr2x); vscr2x = null; }

  atomicStore(pvInited, VLInitState.Not);
}


/**
 * Shutdown SDL, free resources. You don't need to call this explicitely.
 *
 * Params:
 *  none
 *
 * Returns:
 *  nothing
 */
void vlDeinit () /*@trusted nothrow @nogc*/ {
  import core.atomic : atomicLoad;
  if (atomicLoad(pvInited) != VLInitState.Not) {
    vlDeinitInternal();
    SDL_Quit();
  }
}


/**
 * Switches between fullscreen and windowed modes.
 *
 * Params:
 *  none
 *
 * Returns:
 *  nothing
 */
void vlSwitchFullscreen () @trusted nothrow {
  import core.atomic : atomicLoad, atomicStore;
  bool ns = !atomicLoad(vlFullscreen);
  if (SDL_SetWindowFullscreen(sdlWindow, (ns ? (atomicLoad(vlRealFullscreen) ? SDL_WINDOW_FULLSCREEN : SDL_WINDOW_FULLSCREEN_DESKTOP) : 0)) != 0) {
    sdlPrintError();
    return;
  }
  if (!ns) {
    SDL_SetWindowSize(sdlWindow, vsWidth*effectiveMag2x, vsHeight*effectiveMag2x);
    SDL_SetWindowPosition(sdlWindow, SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED);
  }
  atomicStore(vlFullscreen, ns);
}


/**
 * Post SDL_QUIT message. Can be called to initiate clean exit from main loop.
 *
 * Params:
 *  none
 *
 * Returns:
 *  nothing
 */
void vlPostQuitMessage () @trusted nothrow @nogc {
  import core.stdc.string : memset;
  SDL_Event evt = void;
  memset(&evt, 0, evt.sizeof);
  evt.type = SDL_QUIT;
  SDL_PushEvent(&evt);
}


// ////////////////////////////////////////////////////////////////////////// //
@gcc_inline ubyte clampToByte(T) (T n) @safe pure nothrow @nogc
if (__traits(isIntegral, T) && (T.sizeof == 2 || T.sizeof == 4))
{
  static if (__VERSION__ > 2067) pragma(inline, true);
  n &= -cast(int)(n >= 0);
  return cast(ubyte)(n|((255-cast(int)n)>>31));
}

@gcc_inline ubyte clampToByte(T) (T n) @safe pure nothrow @nogc
if (__traits(isIntegral, T) && T.sizeof == 1)
{
  static if (__VERSION__ > 2067) pragma(inline, true);
  return cast(ubyte)n;
}


// ////////////////////////////////////////////////////////////////////////// //
alias Color = uint;

version(LittleEndian) {
  /// vlRGBA struct to ease color components extraction/replacing
  align(1) struct vlRGBA {
  align(1):
    ubyte b, g, r, a;
  }
} else version(BigEndian) {
  /// vlRGBA struct to ease color components extraction/replacing
  align(1) struct vlRGBA {
  align(1):
    ubyte a, r, g, b;
  }
} else {
  static assert(0, "WTF?!");
}

static assert(vlRGBA.sizeof == Color.sizeof);


enum : Color {
  vlAMask = 0xff000000u,
  vlRMask = 0x00ff0000u,
  vlGMask = 0x0000ff00u,
  vlBMask = 0x000000ffu
}

enum : Color {
  vlAShift = 24,
  vlRShift = 16,
  vlGShift = 8,
  vlBShift = 0
}


enum Color vlcTransparent = vlAMask; /// completely transparent pixel color


/**
 * Is color completely transparent?
 *
 * Params:
 *  col = rgba color
 *
 * Returns:
 *  'transparent' flag
 */
@gcc_inline bool vlcIsTransparent(T : Color) (T col) @safe pure nothrow @nogc {
  static if (__VERSION__ > 2067) pragma(inline, true);
  return ((col&vlAMask) == vlAMask);
}

/**
 * Is color completely non-transparent?
 *
 * Params:
 *  col = rgba color
 *
 * Returns:
 *  'transparent' flag
 */
@gcc_inline bool isOpaque(T : Color) (T col) @safe pure nothrow @nogc {
  static if (__VERSION__ > 2067) pragma(inline, true);
  return ((col&vlAMask) == 0);
}

/**
 * Build opaque non-transparent rgb color from components.
 *
 * Params:
 *  r = red component [0..255]
 *  g = green component [0..255]
 *  b = blue component [0..255]
 *  a = transparency [0..255] (0: completely opaque; 255: completely transparent)
 *
 * Returns:
 *  rgba color
 */
@gcc_inline Color rgb2col(TR, TG, TB, TA=ubyte) (TR r, TG g, TB b, TA a=0) @safe pure nothrow @nogc
if (__traits(isIntegral, TR) && __traits(isIntegral, TG) && __traits(isIntegral, TB) && __traits(isIntegral, TA)) {
  static if (__VERSION__ > 2067) pragma(inline, true);
  return
    (clampToByte(a)<<vlAShift)|
    (clampToByte(r)<<vlRShift)|
    (clampToByte(g)<<vlGShift)|
    (clampToByte(b)<<vlBShift);
}

/**
 * Build rgba color from components.
 *
 * Params:
 *  r = red component [0..255]
 *  g = green component [0..255]
 *  b = blue component [0..255]
 *  a = transparency [0..255] (0: completely opaque; 255: completely transparent)
 *
 * Returns:
 *  rgba color
 */
alias rgba2col = rgb2col;


// generate some templates
private enum genRGBGetSet(string cname) =
  "@gcc_inline ubyte rgb"~cname~"() (Color clr) @safe pure nothrow @nogc {\n"~
  "  static if (__VERSION__ > 2067) pragma(inline, true);\n"~
  "  return ((clr>>vl"~cname[0]~"Shift)&0xff);\n"~
  "}\n"~
  "@gcc_inline Color rgbSet"~cname~"(T) (Color clr, T v) @safe pure nothrow @nogc if (__traits(isIntegral, T)) {\n"~
  "  static if (__VERSION__ > 2067) pragma(inline, true);\n"~
  "  return (clr&~vl"~cname[0]~"Mask)|(clampToByte(v)<<vl"~cname[0]~"Shift);\n"~
  "}\n";

mixin(genRGBGetSet!"Alpha");
mixin(genRGBGetSet!"Red");
mixin(genRGBGetSet!"Green");
mixin(genRGBGetSet!"Blue");


// ////////////////////////////////////////////////////////////////////////// //
private enum buildBlit1x(string name, string op, string wrt) =
`private void `~name~` () @trusted nothrow @nogc {`~
`  auto s = cast(const(ubyte)*)vlVScr;`~
`  auto d = cast(ubyte*)vscr2x;`~
`  foreach (immutable _; 0..vsWidth*vsHeight) {`~
`    ubyte i = `~op~`;`~
`    `~wrt~`;`~
`    s += 4;`~
`    d += 4;`~
`  }`~
`}`;


mixin(buildBlit1x!("blit1xBW", "(s[0]*28+s[1]*151+s[2]*77)/256", "d[0] = d[1] = d[2] = i"));
mixin(buildBlit1x!("blit1xGreen", "(s[0]*28+s[1]*151+s[2]*77)/256", "d[0] = d[2] = 0; d[1] = i"));


private enum buildBlit2x(string name, string op) =
`private void `~name~` () @trusted nothrow @nogc {`~
`  auto s = cast(const(ubyte)*)vlVScr;`~
`  auto d = cast(uint*)vscr2x;`~
`  immutable auto wdt = vsWidth;`~
`  immutable auto wdt2x = vsWidth*2;`~
`  foreach (immutable y; 0..vsHeight) {`~
`    foreach (immutable x; 0..wdt) {`~
       op~
`      immutable uint c1 = ((((c0&0x00ff00ff)*6)>>3)&0x00ff00ff)|(((c0&0x0000ff00)*6)>>3)&0x0000ff00;`~
`      d[0] = d[1] = c0;`~
`      d[wdt2x] = d[wdt2x+1] = c1;`~
`      s += 4;`~
`      d += 2;`~
`    }`~
     // fix d: skip one scanline
`    d += wdt2x;`~
`  }`~
`}`;


mixin(buildBlit2x!("blit2xTV", "immutable uint c0 = (cast(immutable(uint)*)s)[0];"));
mixin(buildBlit2x!("blit2xTVBW", "immutable ubyte i = cast(ubyte)((s[0]*28+s[1]*151+s[2]*77)/256); immutable uint c0 = (i<<16)|(i<<8)|i;"));
mixin(buildBlit2x!("blit2xTVGreen", "immutable ubyte i = cast(ubyte)((s[0]*28+s[1]*151+s[2]*77)/256); immutable uint c0 = i<<8;"));


// ////////////////////////////////////////////////////////////////////////// //
/**
 * Paint frame contents.
 *
 * Params:
 *  none
 *
 * Returns:
 *  nothing
 */
void vlPaintFrame () @trusted nothrow @nogc {
  import core.atomic : atomicStore;
  vlPaintFrameDefault();
  atomicStore(sdlFrameChangedFlag, false);
}


/**
 * Paint virtual screen onto real screen or window.
 *
 * Params:
 *  none
 *
 * Returns:
 *  nothing
 */
void vlPaintFrameDefault () @trusted nothrow @nogc {
  import core.atomic : atomicLoad;
  // fix 'logical size'
  immutable flt = atomicLoad(vlFilter);
  if (effectiveMag2x == 2 && atomicLoad(vlScanlines)) {
    // mag2x and scanlines: size is 2x
    if (prevLogSizeWas1x) {
      prevLogSizeWas1x = 0;
      SDL_RenderSetLogicalSize(sdlRenderer, vsWidth*2, vsHeight*2);
    }
  } else {
    // any other case: size is 2x
    if (!prevLogSizeWas1x) {
      prevLogSizeWas1x = 1;
      SDL_RenderSetLogicalSize(sdlRenderer, vsWidth, vsHeight);
    }
  }
  // apply filters if any
  if (effectiveMag2x == 2 && atomicLoad(vlScanlines)) {
    // heavy case: scanline filter turned on
    final switch (flt) with (VLFilter) {
      case None: blit2xTV(); break;
      case BlackNWhite: blit2xTVBW(); break;
      case Green: blit2xTVGreen(); break;
    }
    SDL_UpdateTexture(sdlScr2x, null, vscr2x, cast(uint)(vsWidth*2*vscr2x[0].sizeof));
    SDL_RenderCopy(sdlRenderer, sdlScr2x, null, null);
  } else {
    // light cases
    if (flt == VLFilter.None) {
      // easiest case
      SDL_UpdateTexture(sdlScreen, null, vlVScr, cast(uint)(vsWidth*vlVScr[0].sizeof));
    } else {
      import core.stdc.string : memcpy;
      final switch (flt) with (VLFilter) {
        case None: memcpy(vscr2x, vlVScr, vsWidth*vsHeight*vlVScr[0].sizeof); break; // just in case
        case BlackNWhite: blit1xBW(); break;
        case Green: blit1xGreen(); break;
      }
      SDL_UpdateTexture(sdlScreen, null, vscr2x, cast(uint)(vsWidth*vscr2x[0].sizeof));
    }
    SDL_RenderCopy(sdlRenderer, sdlScreen, null, null);
  }
  SDL_RenderPresent(sdlRenderer);
}


// ////////////////////////////////////////////////////////////////////////// //
version(linux) {
  private enum CLOCK_MONOTONIC_RAW = 4;
  private enum CLOCK_MONOTONIC_COARSE = 6;
} else {
  static assert(0, "sorry, only GNU/Linux for now; please, fix `vlGetTicks()` and company for your OS!");
}


shared static this () {
  vlInitializeClock();
}


private __gshared timespec videolib_clock_stt;
private __gshared int vlClockType = CLOCK_MONOTONIC_COARSE;


private void vlInitializeClock () @trusted nothrow @nogc {
  timespec cres = void;
  bool inited = false;
  if (clock_getres(vlClockType, &cres) == 0) {
    if (cres.tv_sec == 0 && cres.tv_nsec <= cast(long)1000000*1 /*1 ms*/) inited = true;
  }
  if (!inited) {
    vlClockType = CLOCK_MONOTONIC_RAW;
    if (clock_getres(vlClockType, &cres) == 0) {
      if (cres.tv_sec == 0 && cres.tv_nsec <= cast(long)1000000*1 /*1 ms*/) inited = true;
    }
  }
  if (!inited) assert(0, "FATAL: can't initialize clock subsystem!");
  if (clock_gettime(vlClockType, &videolib_clock_stt) != 0) {
    assert(0, "FATAL: can't initialize clock subsystem!");
  }
}


/** returns monitonically increasing time; starting value is UNDEFINED (i.e. can be any number)
 * milliseconds; (0: no timer available) */
@gcc_inline ulong vlGetTicks () @trusted nothrow @nogc {
  static if (__VERSION__ > 2067) pragma(inline, true);
  timespec ts = void;
  if (clock_gettime(vlClockType, &ts) != 0) assert(0, "FATAL: can't get real-time clock value!\n");
  // ah, ignore nanoseconds in videolib_clock_stt->stt here: we need only 'differential' time, and it can start with something weird
  return (cast(ulong)(ts.tv_sec-videolib_clock_stt.tv_sec))*1000+ts.tv_nsec/1000000+1;
}


/** returns monitonically increasing time; starting value is UNDEFINED (i.e. can be any number)
 * microseconds; (0: no timer available) */
@gcc_inline ulong vlGetTicksMicro () @trusted nothrow @nogc {
  static if (__VERSION__ > 2067) pragma(inline, true);
  timespec ts = void;
  if (clock_gettime(vlClockType, &ts) != 0) assert(0, "FATAL: can't get real-time clock value!\n");
  // ah, ignore nanoseconds in videolib_clock_stt->stt here: we need only 'differential' time, and it can start with something weird
  return (cast(ulong)(ts.tv_sec-videolib_clock_stt.tv_sec))*1000000+ts.tv_nsec/1000+1;
}


// ////////////////////////////////////////////////////////////////////////// //
// main loop

enum SDL_MOUSEDOUBLE = SDL_USEREVENT+1; /// same as SDL_MouseButtonEvent
enum SDL_FREEEVENT = SDL_USEREVENT+42; /// first event available for user


// ////////////////////////////////////////////////////////////////////////// //
/**
 * mechanics is like this:
 * when it's time to show new frame, videolib will call vlOnUpdateCB().
 * if vlFrameChanged is set (either from previous frame, or by vlOnUpdateCB(),
 * videolib will call vlOnRebuildCB() and vlPaintFrame().
 * note that videolib will reset vlFrameChanged after vlOnRebuildCB() called.
 * also note that if vlOnUpdateCB() or vlOnRebuildCB() will not set vlFrameChanged,
 * frame visuals will not be updated properly.
 * you can either update and vlOnRebuildCB screen in vlOnUpdateCB(), or update state in
 * vlOnUpdateCB() and rebuild virtual screen in vlOnRebuildCB().
 * you can count on videolib never changes virtual screen contents by itself.
 */
/** elapsedTicks: ms elapsed from the last call; will try to keep up with FPS; 0: first call in vlMainLoop()
 * can call vlFrameChanged() flag so vlMainLoop() will call vlOnRebuildCB() or call vlOnRebuildCB() itself */
private {
  __gshared void delegate (int elapsedTicks) vlOnUpdateCB = null;
  __gshared void delegate () vlOnRebuildCB = null;

  __gshared void delegate (in ref SDL_KeyboardEvent ev) vlOnKeyDownCB = null;
  __gshared void delegate (in ref SDL_KeyboardEvent ev) vlOnKeyUpCB = null;
  __gshared void delegate (dchar ch) vlOnTextInputCB = null;

  __gshared void delegate (in ref SDL_MouseButtonEvent ev) vlOnMouseDownCB = null;
  __gshared void delegate (in ref SDL_MouseButtonEvent ev) vlOnMouseUpCB = null;
  __gshared void delegate (in ref SDL_MouseButtonEvent ev) vlOnMouseClickCB = null;
  __gshared void delegate (in ref SDL_MouseButtonEvent ev) vlOnMouseDoubleCB = null; /// mouse double-click
  __gshared void delegate (in ref SDL_MouseMotionEvent ev) vlOnMouseMotionCB = null;
  __gshared void delegate (in ref SDL_MouseWheelEvent ev) vlOnMouseWheelCB = null;
}


@trusted nothrow @nogc {
  private import std.functional : toDelegate;
  @property void vlOnUpdate (void function (int elapsedTicks) cb) { vlOnUpdateCB = toDelegate(cb); }
  @property void vlOnRebuild (void function () cb) { vlOnRebuildCB = toDelegate(cb); }
  @property void vlOnKeyDown (void function (in ref SDL_KeyboardEvent ev) cb) { vlOnKeyDownCB = toDelegate(cb); }
  @property void vlOnKeyUp (void function (in ref SDL_KeyboardEvent ev) cb) { vlOnKeyUpCB = toDelegate(cb); }
  @property void vlOnTextInput (void function (dchar ch) cb) { vlOnTextInputCB = toDelegate(cb); }
  @property void vlOnMouseDown (void function (in ref SDL_MouseButtonEvent ev) cb) { vlOnMouseDownCB = toDelegate(cb); }
  @property void vlOnMouseUp (void function (in ref SDL_MouseButtonEvent ev) cb) { vlOnMouseUpCB = toDelegate(cb); }
  @property void vlOnMouseClick (void function (in ref SDL_MouseButtonEvent ev) cb) { vlOnMouseClickCB = toDelegate(cb); }
  @property void vlOnMouseDouble (void function (in ref SDL_MouseButtonEvent ev) cb) { vlOnMouseDoubleCB = toDelegate(cb); }
  @property void vlOnMouseMotion (void function (in ref SDL_MouseMotionEvent ev) cb) { vlOnMouseMotionCB = toDelegate(cb); }
  @property void vlOnMouseWheel (void function (in ref SDL_MouseWheelEvent ev) cb) { vlOnMouseWheelCB = toDelegate(cb); }

  @property void vlOnUpdate (void delegate (int elapsedTicks) cb) { vlOnUpdateCB = cb; }
  @property void vlOnRebuild (void delegate () cb) { vlOnRebuildCB = cb; }
  @property void vlOnKeyDown (void delegate (in ref SDL_KeyboardEvent ev) cb) { vlOnKeyDownCB = cb; }
  @property void vlOnKeyUp (void delegate (in ref SDL_KeyboardEvent ev) cb) { vlOnKeyUpCB = cb; }
  @property void vlOnTextInput (void delegate (dchar ch) cb) { vlOnTextInputCB = cb; }
  @property void vlOnMouseDown (void delegate (in ref SDL_MouseButtonEvent ev) cb) { vlOnMouseDownCB = cb; }
  @property void vlOnMouseUp (void delegate (in ref SDL_MouseButtonEvent ev) cb) { vlOnMouseUpCB = cb; }
  @property void vlOnMouseClick (void delegate (in ref SDL_MouseButtonEvent ev) cb) { vlOnMouseClickCB = cb; }
  @property void vlOnMouseDouble (void delegate (in ref SDL_MouseButtonEvent ev) cb) { vlOnMouseDoubleCB = cb; }
  @property void vlOnMouseMotion (void delegate (in ref SDL_MouseMotionEvent ev) cb) { vlOnMouseMotionCB = cb; }
  @property void vlOnMouseWheel (void delegate (in ref SDL_MouseWheelEvent ev) cb) { vlOnMouseWheelCB = cb; }

  @property auto vlOnUpdate () { return vlOnUpdateCB; }
  @property auto vlOnRebuild () { return vlOnRebuildCB; }
  @property auto vlOnKeyDown () { return vlOnKeyDownCB; }
  @property auto vlOnKeyUp () { return vlOnKeyUpCB; }
  @property auto vlOnTextInput () { return vlOnTextInputCB; }
  @property auto vlOnMouseDown () { return vlOnMouseDownCB; }
  @property auto vlOnMouseUp () { return vlOnMouseUpCB; }
  @property auto vlOnMouseClick () { return vlOnMouseClickCB; }
  @property auto vlOnMouseDouble () { return vlOnMouseDoubleCB; }
  @property auto vlOnMouseMotion () { return vlOnMouseMotionCB; }
  @property auto vlOnMouseWheel () { return vlOnMouseWheelCB; }
}

/// start receiving text input events
void startTextInput() () { SDL_StartTextInput(); }

/// stop receiving text input events
void stopTextInput() () { SDL_StopTextInput(); }


// ////////////////////////////////////////////////////////////////////////// //
/* doubleclick processing */
// first press (count is 0):
//   start it, set count to 1, send "press"
// first release (count is 1):
//  checkCond pass: set count to 2, send "release", send "clicked"
//  checkCond fail: set count to 0, send "release"
// second press (count is 2):
//  checkCond pass: set count to 3, eat press
//  checkCond fail: start it, set count to 1, send "press"
// second release (count is 3):
//  checkCond pass: set count to 0, eat release, send "double"
//  checkCond fail: set count to 0, eat release
private struct VLDblClickInfo {
  enum Action {
    Pass, // send normal event
    Eat, // don't send any event
    Click, // send normal event, then click
    Double // send double
  }

  int count;
  int x, y;
  ulong pressTime; // in msecs

  void reset () @safe nothrow @nogc { count = 0; }

  bool checkConds (in ref SDL_Event ev) @trusted nothrow @nogc {
    if (count) {
      import std.math : abs;
      return
        abs(ev.button.x-x) <= vlDblTreshold &&
        abs(ev.button.y-y) <= vlDblTreshold &&
        vlGetTicks()-pressTime <= vlDblTimeout;
    } else {
      return false;
    }
  }

  Action processDown (in ref SDL_Event ev) @trusted nothrow @nogc {
    void register () @trusted nothrow @nogc {
      count = 1;
      x = ev.button.x;
      y = ev.button.y;
      pressTime = vlGetTicks();
    }

    if (count == 0) {
      // first press
      register();
      return Action.Pass;
    } else {
      // second press
      assert(count == 2);
      if (checkConds(ev)) {
        count = 3;
        return Action.Eat;
      } else {
        register();
        return Action.Pass;
      }
    }
  }

  Action processUp (in ref SDL_Event ev) @trusted nothrow @nogc {
    if (count == 0) {
      return Action.Pass;
    } else if (checkConds(ev)) {
      if (count == 1) {
        //if (w.mWantDouble) count = 2; else reset();
        count = 2;
        return Action.Click;
      } else if (count == 3) {
        reset();
        return Action.Double;
      } else {
        assert(0);
      }
    } else {
      Action res = (count == 1 ? Action.Pass : Action.Eat);
      reset();
      return res;
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
private __gshared VLDblClickInfo[32] vlDblClickInfo; // button_number-1
public __gshared uint vlDblTimeout = 400; /// milliseconds; set to 0 to disable doubleclicks
public __gshared uint vlDblTreshold = 4; /// mouse cursor should not move more than `vlDblTreshold` pixels to register dblclick


// return `true` if event was eaten
private bool vlProcessDblClick (in ref SDL_Event ev) {
  if (vlDblTimeout < 1) return false;
  if (ev.type != SDL_MOUSEBUTTONDOWN && ev.type != SDL_MOUSEBUTTONUP) return false;
  if (ev.button.button < 1 || ev.button.button >= vlDblClickInfo.length) return false;
  if (ev.type == SDL_MOUSEBUTTONDOWN) {
    // button pressed
    immutable act = vlDblClickInfo[ev.button.button-1].processDown(ev);
    bool doEat = true;
    switch (act) with (VLDblClickInfo.Action) {
      case Eat:
        break;
      case Click:
        if (vlOnMouseDownCB !is null) vlOnMouseDownCB(ev.button);
        if (vlOnMouseClickCB !is null) vlOnMouseClickCB(ev.button);
        break;
      case Double:
        if (vlOnMouseDoubleCB !is null) vlOnMouseDoubleCB(ev.button);
        break;
      default:
        doEat = false;
        break;
    }
    if (!doEat && vlOnMouseDownCB !is null) vlOnMouseDownCB(ev.button);
  } else {
    // button released
    immutable act = vlDblClickInfo[ev.button.button-1].processUp(ev);
    bool doEat = true;
    switch (act) with (VLDblClickInfo.Action) {
      case Eat:
        break;
      case Click:
        if (vlOnMouseUpCB !is null) vlOnMouseUpCB(ev.button);
        if (vlOnMouseClickCB !is null) vlOnMouseClickCB(ev.button);
        break;
      case Double:
        if (vlOnMouseDoubleCB !is null) vlOnMouseDoubleCB(ev.button);
        break;
      default:
        doEat = false;
        break;
    }
    if (!doEat && vlOnMouseUpCB !is null) vlOnMouseUpCB(ev.button);
  }
  return true;
}


// ////////////////////////////////////////////////////////////////////////// //
/** returns !0 to stop event loop; <0: from event preprocessor; >0: from SDL_QUIT */
int vlProcessEvent (ref SDL_Event ev) {
  if (vlMag2x) {
    if (ev.type == SDL_MOUSEBUTTONDOWN || ev.type == SDL_MOUSEBUTTONUP) {
      ev.button.x /= 2;
      ev.button.y /= 2;
    } else if (ev.type == SDL_MOUSEMOTION) {
      ev.motion.x /= 2;
      ev.motion.y /= 2;
    }
  }
  if (vlProcessDblClick(ev)) return 0; // process mouse
  if (ev.type == SDL_QUIT) return 1;
  switch (ev.type) {
    case SDL_KEYDOWN: if (vlOnKeyDownCB !is null) vlOnKeyDownCB(ev.key); break;
    case SDL_KEYUP: if (vlOnKeyUpCB !is null) vlOnKeyUpCB(ev.key); break;
    case SDL_MOUSEBUTTONDOWN: if (vlOnMouseDownCB !is null) vlOnMouseDownCB(ev.button); break;
    case SDL_MOUSEBUTTONUP: if (vlOnMouseUpCB !is null) vlOnMouseUpCB(ev.button); break;
    //case SDL_MOUSEDOUBLE: if (vlOnMouseDoubleCB !is null) vlOnMouseDoubleCB(ev.button); break;
    case SDL_MOUSEMOTION: if (vlOnMouseMotionCB !is null) vlOnMouseMotionCB(ev.motion); break;
    case SDL_MOUSEWHEEL: if (vlOnMouseWheelCB !is null) vlOnMouseWheelCB(ev.wheel); break;
    case SDL_TEXTINPUT:
      if (vlOnTextInputCB !is null) {
        //TODO: UTF-8 decode!
        if (ev.text.text[0] && ev.text.text[0] < 127) {
          vlOnTextInputCB(ev.text.text[0]);
        }
      }
      break;
    case SDL_USEREVENT:
      //TODO: forward other user events
      //(ev.user.code)
      break;
    case SDL_WINDOWEVENT:
      switch (ev.window.event) {
        case SDL_WINDOWEVENT_EXPOSED:
          vlFrameChanged(); // this will force repaint
          break;
        default:
      }
      break;
    default:
  }
  return 0;
}


private __gshared int pvCurFPS = 35; /// desired FPS (default: 35)
private __gshared ulong pvLastUpdateCall = 0;
private __gshared ulong pvNextUpdateCall = 0;
private __gshared uint pvMSecsInFrame = 1000/35;

@property uint vlMSecsPerFrame () @trusted nothrow @nogc { return pvMSecsInFrame; } /// return number of milliseconds in frame

@property uint vlFPS () @trusted nothrow @nogc { return pvCurFPS; } /// return current FPS

/// set desired FPS
@property void vlFPS (uint newfps) @trusted nothrow @nogc {
  if (newfps < 1) newfps = 1;
  if (newfps > 500) newfps = 500;
  pvMSecsInFrame = 1000/newfps;
  if (pvMSecsInFrame == 0) pvMSecsInFrame = 1;
  pvCurFPS = newfps;
}


/// update and rebuild frame if necessary
/// will not paint frame to screen
void vlCheckFrameUpdate () {
  auto tm = vlGetTicks();
  if (tm >= pvNextUpdateCall) {
    if (vlOnUpdateCB !is null) vlOnUpdateCB(cast(int)(tm-pvLastUpdateCall));
    pvLastUpdateCall = tm;//vlGetTicks();
    while (tm >= pvNextUpdateCall) {
      // do something with skipped frames
      pvNextUpdateCall += pvMSecsInFrame;
    }
  }
  import core.atomic : cas;
  bool cf = cas(&sdlFrameChangedFlag, true, false); // cf is true if sdlFrameChangedFlag was true
  if (cf) {
    vlFrameChanged();
    if (vlOnRebuildCB !is null) vlOnRebuildCB();
  }
}


/** will start and stop FPS timer automatically */
void vlMainLoop () {
  bool doQuit = false;
  SDL_Event ev;
  pvLastUpdateCall = vlGetTicks();
  pvNextUpdateCall = pvLastUpdateCall+pvMSecsInFrame;
  if (vlOnUpdateCB !is null) vlOnUpdateCB(0);
  if (vlOnRebuildCB !is null) vlOnRebuildCB();
  vlPaintFrame();
  while (!doQuit) {
    if (!SDL_PollEvent(null)) {
      // no events, see if we have to wait for the next frame
      auto now = vlGetTicks();
      if (now < pvNextUpdateCall) {
        // have some time to waste
        int n = cast(int)(pvNextUpdateCall-now);
        if (!SDL_WaitEventTimeout(null, n)) goto noevent;
      }
    }
    while (SDL_PollEvent(&ev)) {
      if (vlProcessEvent(ev)) { doQuit = true; break; }
    }
    if (doQuit) break;
noevent:
    vlCheckFrameUpdate();
    if (vlIsFrameChanged) vlPaintFrame(); // this will reset sdlFrameChangedFlag again
  }
}


// ////////////////////////////////////////////////////////////////////////// //
shared static ~this () {
  vlDeinit();
}
