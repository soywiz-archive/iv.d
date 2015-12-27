/*
 * Pixel Graphics Library
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
module iv.sdpy.sdpycore;

private:
static if (__traits(compiles, () { import arsd.simpledisplay; })) {
  public import arsd.simpledisplay;
} else {
  public import simpledisplay;
}

static if (__traits(compiles, () { import iv.ticks; })) {
  import iv.ticks;
  enum use_fps = true;
} else {
  enum use_fps = false;
}

import iv.sdpy.compat;
import iv.sdpy.color;
import iv.sdpy.core;
import iv.sdpy.font6;
import iv.sdpy.vlo;


// ////////////////////////////////////////////////////////////////////////// //
public:
__gshared void delegate () sdpyClearOvlCB;
__gshared void delegate () sdpyPreDrawCB;
__gshared void delegate () sdpyPostDrawCB;
__gshared void delegate () sdpyCloseQueryCB;
__gshared void delegate () sdpyFocusCB;
__gshared void delegate () sdpyBlurCB;
__gshared void delegate () sdpyFrameCB; // called on the start of each frame
__gshared void delegate (KeyEvent evt, bool active=true) sdpyOnKeyCB;
__gshared void delegate (MouseEvent evt, bool active=true) sdpyOnMouseCB;
__gshared void delegate (dchar ch, bool active=true) sdpyOnCharCB;

void sdpyPostQuitMessage () {
  if (!sdwindow.closed) {
    flushGui();
    sdwindow.close();
    flushGui();
  }
}


enum {
  SdpyButtonDownLeft = 1<<0,
  SdpyButtonDownMiddle = 1<<1,
  SdpyButtonDownRight = 1<<2,
}

// changed before event callback
@property int sdpyMouseX() () nothrow @trusted @nogc {
  static if (__VERSION__ > 2067) pragma(inline, true);
  return lastMouseX;
}

// changed before event callback
@property int sdpyMouseY() () nothrow @trusted @nogc {
  static if (__VERSION__ > 2067) pragma(inline, true);
  return lastMouseY;
}

// changed before event callback
@property ubyte sdpyMouseButts() () nothrow @trusted @nogc {
  static if (__VERSION__ > 2067) pragma(inline, true);
  return lastMouseButts;
}


enum {
  SdpyKeyCtrlDown = 1<<0,
  SdpyKeyAltDown = 1<<1,
  SdpyKeyShiftDown = 1<<2,
  SdpyKeyMetaDown = 1<<3,
}

// changed before event callback
@property ubyte sdpyKeyMods() () nothrow @trusted @nogc {
  static if (__VERSION__ > 2067) pragma(inline, true);
  return lastKeyMods;
}


@property bool sdpyCursorVisible () nothrow @trusted @nogc { return (sdpyCurVisible == 1); }
void sdpyHideCursor () nothrow @trusted @nogc { --sdpyCurVisible; }
void sdpyShowCursor () nothrow @trusted @nogc { ++sdpyCurVisible; }


// ////////////////////////////////////////////////////////////////////////// //
private:
__gshared bool intrSdpyUseOpenGL;
__gshared int sdpyCurVisible = 1;
__gshared uint intrFPS;


// ////////////////////////////////////////////////////////////////////////// //
// cursor (hi, Death Track!)
public enum curWidth = 17;
public enum curHeight = 23;
static immutable ubyte[curWidth*curHeight] curImg = [
  0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,3,2,0,0,0,0,0,0,0,0,0,0,0,0,0,
  1,0,3,2,2,0,0,0,0,0,0,0,0,0,0,0,0,
  1,1,3,3,2,2,0,0,0,0,0,0,0,0,0,0,0,
  1,1,3,3,4,2,2,0,0,0,0,0,0,0,0,0,0,
  1,1,3,3,4,4,2,2,0,0,0,0,0,0,0,0,0,
  1,1,3,3,4,4,4,2,2,0,0,0,0,0,0,0,0,
  1,1,3,3,4,4,4,4,2,2,0,0,0,0,0,0,0,
  1,1,3,3,4,4,4,5,6,2,2,0,0,0,0,0,0,
  1,1,3,3,4,4,5,6,7,5,2,2,0,0,0,0,0,
  1,1,3,3,4,5,6,7,5,4,5,2,2,0,0,0,0,
  1,1,3,3,5,6,7,5,4,5,6,7,2,2,0,0,0,
  1,1,3,3,6,7,5,4,5,6,7,7,7,2,2,0,0,
  1,1,3,3,7,5,4,5,6,7,7,7,7,7,2,2,0,
  1,1,3,3,5,4,5,6,8,8,8,8,8,8,8,8,2,
  1,1,3,3,4,5,6,3,8,8,8,8,8,8,8,8,8,
  1,1,3,3,5,6,3,3,1,1,1,1,1,1,1,0,0,
  1,1,3,3,6,3,3,1,1,1,1,1,1,1,1,0,0,
  1,1,3,3,3,3,0,0,0,0,0,0,0,0,0,0,0,
  1,1,3,3,3,0,0,0,0,0,0,0,0,0,0,0,0,
  1,1,3,3,0,0,0,0,0,0,0,0,0,0,0,0,0,
  1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
];
static immutable VColor[9] curPal = [
  VColor.rgba(  0,  0,  0,255),
  VColor.rgba(  0,  0,  0, 92),
  VColor.rgba( 85,255,255,  0),
  VColor.rgba( 85, 85,255,  0),
  VColor.rgba(255, 85, 85,  0),
  VColor.rgba(170,  0,170,  0),
  VColor.rgba( 85, 85, 85,  0),
  VColor.rgba(  0,  0,  0,  0),
  VColor.rgba(  0,  0,170,  0),
];


void drawCursor (int x, int y) {
  bool pressed = (lastMouseButts != 0);
  foreach (immutable dy; 0..curHeight) {
    foreach (immutable dx; 0..curWidth) {
      auto clr = curPal[curImg[dy*curWidth+dx]];
      if (pressed && clr.a != 0) continue;
      vlOvl.putPixel(x+dx-2, y+dy, clr);
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
static if (use_fps) {
  uint updateFPS () {
    __gshared ulong fpsStTicks = 0;
    __gshared uint fpsFrameCount = 0;
    __gshared uint fpsLastFPS = 0;

    immutable stt = getTicks();
    if (fpsStTicks == 0) fpsStTicks = stt;
    immutable stdiff = stt-fpsStTicks;

    ++fpsFrameCount;
    if (stdiff >= 2000) {
      fpsLastFPS = cast(uint)(cast(double)fpsFrameCount*1000.0/cast(double)stdiff+0.5);
      fpsStTicks = stt;
      fpsFrameCount = 0;
    }
    return fpsLastFPS;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
public __gshared SimpleWindow sdwindow;


// ////////////////////////////////////////////////////////////////////////// //
uint nextPowerOf2 (uint n) {
  static if (__VERSION__ > 2067) pragma(inline, true);
  --n;
  n |= n>>1;
  n |= n>>2;
  n |= n>>4;
  n |= n>>8;
  n |= n>>16;
  ++n;
  return n;
}


// ////////////////////////////////////////////////////////////////////////// //
__gshared uint texId = 0;
__gshared int texWidth = 1024;
__gshared int texHeight = 1024;
__gshared Image texImage;

shared static ~this () {
  destroy(texImage);
}


void initOpenGL () {
  if (texId != 0) return;
  if (sdwindow is null) return;

  if (intrSdpyUseOpenGL) {
    sdwindow.setAsCurrentOpenGlContext(); // make this window active
    sdwindow.vsync = false;
    //sdwindow.useGLFinish = false;
    glEnable(GL_TEXTURE_2D);

    glGenTextures(1, &texId);
    glBindTexture(GL_TEXTURE_2D, texId);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, /*GL_REPEAT*/GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, /*GL_REPEAT*/GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    //glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);
    glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);

    {
      import core.stdc.stdlib : malloc, free;
      texWidth = nextPowerOf2(vlEffectiveWidth);
      texHeight = nextPowerOf2(vlEffectiveHeight);
      void* p = malloc(texWidth*texHeight*4);
      glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, texWidth, texHeight, 0, GL_BGRA, GL_UNSIGNED_BYTE, p);
      free(p);
    }


    glDisable(GL_LIGHTING);
    glDisable(GL_DITHER);
    glDisable(GL_BLEND);
    glDisable(GL_DEPTH_TEST);

    /+
    glEnable(GL_BLEND);
    //glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glBlendFunc(GL_ONE_MINUS_SRC_ALPHA, GL_SRC_ALPHA);
    +/

    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glOrtho(0, sdwindow.width, sdwindow.height, 0, -1, 1);

    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
    glTranslatef(0.375, 0.375, 0); // to be pixel-perfect
  }
}


// ////////////////////////////////////////////////////////////////////////// //
__gshared int lastMouseX = 0, lastMouseY = 0;
__gshared ubyte lastMouseButts = 0;
__gshared ubyte lastKeyMods = 0;


void fixMouseVars() (in ref MouseEvent ev) {
  immutable mag = vlEffectiveMag;
  lastMouseX = ev.x/mag;
  lastMouseY = ev.y/mag;
  ubyte bmask = 0;
  switch (ev.button) with (MouseButton) {
    case left: bmask = SdpyButtonDownLeft; break;
    case middle: bmask = SdpyButtonDownMiddle; break;
    case right: bmask = SdpyButtonDownRight; break;
    default:
  }
  switch (ev.type) {
    case MouseEventType.buttonPressed: lastMouseButts |= bmask; break;
    case MouseEventType.buttonReleased: lastMouseButts &= ~bmask; break;
    default:
  }
  // fix keymods
  ubyte res = 0;
  if (ev.modifierState&ModifierState.ctrl) res |= SdpyKeyCtrlDown;
  if (ev.modifierState&ModifierState.alt) res |= SdpyKeyAltDown;
  if (ev.modifierState&ModifierState.shift) res |= SdpyKeyShiftDown;
  if (ev.modifierState&ModifierState.windows) res |= SdpyKeyMetaDown;
  lastKeyMods = res;
}


void fixKeyevMods() (in ref KeyEvent ev) {
  ubyte res = 0;
  if (ev.modifierState&ModifierState.ctrl) res |= SdpyKeyCtrlDown;
  if (ev.modifierState&ModifierState.alt) res |= SdpyKeyAltDown;
  if (ev.modifierState&ModifierState.shift) res |= SdpyKeyShiftDown;
  if (ev.modifierState&ModifierState.windows) res |= SdpyKeyMetaDown;
  switch (ev.key) with (Key) {
    case Ctrl: case Ctrl_r:
      if (ev.pressed) res |= SdpyKeyCtrlDown; else res &= ~SdpyKeyCtrlDown;
      break;
    case Alt: case Alt_r:
      if (ev.pressed) res |= SdpyKeyAltDown; else res &= ~SdpyKeyAltDown;
      break;
    case Shift: case Shift_r:
      if (ev.pressed) res |= SdpyKeyShiftDown; else res &= ~SdpyKeyShiftDown;
      break;
    case Windows: case Windows_r:
      if (ev.pressed) res |= SdpyKeyMetaDown; else res &= ~SdpyKeyMetaDown;
      break;
    default:
  }
  lastKeyMods = res;
}


private void updateCB () {
  if (sdpyClearOvlCB !is null) {
    sdpyClearOvlCB();
  } else {
    vlOvl.clear(VColor.black);
  }

  if (sdpyPreDrawCB !is null) sdpyPreDrawCB();

  static if (use_fps) {
    if (sdpyShowFPS) {
      // do manual number conversion to avoid allocations
      char[64] buf;
      usize pos = buf.length;
      auto fps = updateFPS();
      do {
        buf[--pos] = cast(char)('0'+fps%10);
        fps /= 10;
      } while (fps > 0);
      while (buf.length-pos < 2) buf[--pos] = '0';
      buf[--pos] = ' ';
      buf[--pos] = ':';
      buf[--pos] = 'S';
      buf[--pos] = 'P';
      buf[--pos] = 'F';
      auto s = buf[pos..$];
      immutable sw = vlOvl.textWidthProp(s);
      vlOvl.drawTextPropOut(vlOvl.width-sw-3, 2, s, VColor.rgb(255, 127, 0), VColor.black);
    }
  }

  if (sdpyCurVisible) drawCursor(lastMouseX, lastMouseY);
  if (sdpyPostDrawCB !is null) sdpyPostDrawCB();
}


// ////////////////////////////////////////////////////////////////////////// //
public void sdpyMainLoop () {
  vlInit();

  intrSdpyUseOpenGL = sdpyUseOpenGL; // cache value
  intrFPS = sdpyFPS; // cache value
  if (intrFPS < 1) intrFPS = 1; else if (intrFPS > 200) intrFPS = 200;
  if (!intrSdpyUseOpenGL) texImage = new Image(vlEffectiveWidth, vlEffectiveHeight);

  sdwindow = new SimpleWindow(vlEffectiveWidth, vlEffectiveHeight, sdpyWindowTitle, (intrSdpyUseOpenGL ? OpenGlOptions.yes : OpenGlOptions.no), Resizablity.fixedSize);
  if (!intrSdpyUseOpenGL) {
    auto painter = sdwindow.draw();
    painter.outlineColor = Color.black;
    painter.fillColor = Color.black;
    painter.drawRectangle(Point(0, 0), vlEffectiveWidth, vlEffectiveHeight);
  }

  //sdwindow.setAsCurrentOpenGlContext(); // make this window active; can't call this here, or nvidia blocks event sending
  sdwindow.hideCursor(); // we will do our own

  sdwindow.closeQuery = delegate () {
    if (sdpyCloseQueryCB !is null) {
      sdpyCloseQueryCB();
    } else {
      sdwindow.close();
    }
  };

  sdwindow.visibleForTheFirstTime = delegate () {
    initOpenGL();
    if (!intrSdpyUseOpenGL) sdwindow.redrawOpenGlScene();
  };

  sdwindow.redrawOpenGlScene = delegate () {
    updateCB();
    if (sdwindow.closed) return;
    auto vbuf = vlBuildBuffer2Blit();
    if (intrSdpyUseOpenGL) {
      //glClear(GL_COLOR_BUFFER_BIT);
      glBindTexture(GL_TEXTURE_2D, texId);
      glTexSubImage2D(GL_TEXTURE_2D, 0,  0, 0, vlEffectiveWidth, vlEffectiveHeight, GL_BGRA, GL_UNSIGNED_BYTE, vbuf.ptr);
      glBegin(GL_QUADS);
        glTexCoord2f(0, 0); glVertex2i(0, 0); // top-left
        glTexCoord2f(1, 0); glVertex2i(texWidth, 0); // top-right
        glTexCoord2f(1, 1); glVertex2i(texWidth, texHeight); // bottom-right
        glTexCoord2f(0, 1); glVertex2i(0, texHeight); // bottom-left
      glEnd();
    } else {
      // copy vbuf data to image data
      auto apix0 = texImage.offsetForTopLeftPixel;
      auto alinelen = texImage.bytesPerLine;
      auto apixlen = texImage.bytesPerPixel;
      auto ro = texImage.redByteOffset;
      auto go = texImage.greenByteOffset;
      auto bo = texImage.blueByteOffset;
      auto data = texImage.getDataPointer;
      usize bptr = 0;
      foreach (immutable y; 0..vlEffectiveHeight) {
        auto curline = data+apix0+y*alinelen;
        foreach (immutable x; 0..vlEffectiveWidth) {
          uint c = vbuf[bptr++];
          curline[ro] = (c>>VColor.RShift)&0xff;
          curline[go] = (c>>VColor.GShift)&0xff;
          curline[bo] = (c>>VColor.BShift)&0xff;
          curline += apixlen;
        }
      }
      // additional scope to properly destroy painter in case we'll want to do anything else after that
      {
        auto painter = sdwindow.draw();
        painter.drawImage(Point(0, 0), texImage);
      }
    }
  };

  static void redrawWindow () {
    if (intrSdpyUseOpenGL) {
      sdwindow.redrawOpenGlSceneNow();
    } else {
      sdwindow.redrawOpenGlScene();
    }
  }

  sdwindow.onFocusChange = delegate (bool focused) {
    lastMouseButts = 0;
    lastKeyMods = 0;
    if (focused) {
      if (sdpyFocusCB !is null) sdpyFocusCB();
    } else {
      if (sdpyBlurCB !is null) sdpyBlurCB();
    }
  };

  sdwindow.eventLoop(/*30*/1000/intrFPS,
    delegate () {
      if (sdpyFrameCB !is null) sdpyFrameCB();
      if (sdwindow.closed) return;
      redrawWindow();
    },
    delegate (KeyEvent event) {
      if (sdwindow.closed) return;
      fixKeyevMods(event);
      if (sdpyOnKeyCB !is null) sdpyOnKeyCB(event);
    },
    delegate (MouseEvent event) {
      fixMouseVars(event);
      if (sdpyOnMouseCB !is null) sdpyOnMouseCB(event);
    },
    delegate (dchar ch) {
      if (sdpyOnCharCB !is null) sdpyOnCharCB(ch);
    },
  );
  if (!sdwindow.closed) {
    flushGui();
    sdwindow.close();
  }
  flushGui();

  if (intrSdpyUseOpenGL) {
    if (texId) {
      glBindTexture(GL_TEXTURE_2D, texId);
      glDeleteTextures(1, &texId);
      texId = 0;
    }
  }
}
