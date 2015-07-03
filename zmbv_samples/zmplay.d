module zmplay is aliced;

import std.stdio : File;

import iv.exex;
import iv.stream;
import iv.vl2;
import iv.zmbv;
import iv.writer;


////////////////////////////////////////////////////////////////////////////////
mixin(MyException!"PlayerError");


////////////////////////////////////////////////////////////////////////////////
File aviFl;
uint fps;
bool hasIndex;
uint framesTotal;
uint streamCount;
uint videoW, videoH;
ulong movieOfs;
uint movieSize;
ulong moviePos;
Decoder zmd;


// in: st.tell == 0
void loadHeader(ST) (auto ref ST st) if (isReadableStream!ST && isSeekableStream!ST) {
  char[4] sign;
  st.rawReadExact(sign[]);
  if (sign != "RIFF") throw new PlayerError("not a RIFF");
  uint riffsize = st.readNum!uint();
  st.rawReadExact(sign[]);
  if (sign != "AVI ") throw new PlayerError("not an AVI");
  st.rawReadExact(sign[]);
  if (sign != "LIST") throw new PlayerError("not an AVI");
  uint listsize = st.readNum!uint();
  if (listsize > 512) throw new PlayerError("AVI header too big");
  ulong hepos = st.tell+listsize;
  // load headers
  st.rawReadExact(sign[]);
  if (sign != "hdrl") throw new PlayerError("invalid AVI");
  st.rawReadExact(sign[]);
  if (sign != "avih") throw new PlayerError("no AVI header");
  uint sz = st.readNum!uint();
  if (sz < 56) throw new PlayerError("invalid AVI header");
  ulong npos = st.tell+sz;
  fps = 1000000/st.readNum!uint(); // microseconds per frame --> FPS
  if (fps < 1 || fps > 255) throw new PlayerError("invalid FPS");
  st.readNum!uint();
  st.readNum!uint();
  uint flags = st.readNum!uint();
  if ((flags&0x100) == 0) throw new PlayerError("non-interleaved AVI");
  hasIndex = ((flags&0x10) != 0);
  framesTotal = st.readNum!uint();
  st.readNum!uint(); // initial frames
  streamCount = st.readNum!uint();
  if (streamCount < 1 || streamCount > 2) throw new PlayerError("invalid number of streams");
  st.readNum!uint();
  videoW = st.readNum!uint();
  videoH = st.readNum!uint();
  if (videoW < 32 || videoH < 32 || videoW > 4096 || videoH > 4096) throw new PlayerError("invalid video dimensions");
  // now load stream list
  st.seek(npos);
  st.rawReadExact(sign[]);
  if (sign != "LIST") throw new PlayerError("not an AVI");
  st.readNum!uint();
  st.rawReadExact(sign[]);
  if (sign != "strl") throw new PlayerError("no stream list found");
  st.rawReadExact(sign[]);
  if (sign != "strh") throw new PlayerError("no stream list found");
  sz = st.readNum!uint();
  if (sz < 56) throw new PlayerError("invalid AVI header");
  npos = st.tell+sz;
  st.rawReadExact(sign[]);
  if (sign != "vids") throw new PlayerError("first stream is not video");
  st.rawReadExact(sign[]);
  if (sign != "ZMBV") throw new PlayerError("first stream is ZMBV");
  // now look for actual data
  st.seek(hepos);
  for (;;) {
    st.rawReadExact(sign[]);
    sz = st.readNum!uint();
    npos = st.tell+sz;
    if (sz >= 3*4 && sign == "LIST") {
      st.rawReadExact(sign[]);
      if (sign == "movi") {
        movieOfs = st.tell;
        movieSize = sz-4;
        moviePos = movieOfs;
        break;
      }
    }
    st.seek(npos);
  }
  writeln("FPS: ", fps);
  writeln("hasIndex: ", hasIndex);
  writeln("framesTotal: ", framesTotal);
  writeln(videoW, "x", videoH);
  //TODO: index
  zmd = new Decoder(videoW, videoH);
}


ubyte[] encframe;
Color[256] framepal;
bool paused;
bool videoDone = false;
uint curFrame;


bool loadNextFrame(ST) (auto ref ST st) if (isReadableStream!ST && isSeekableStream!ST) {
  //writeln(moviePos, " ", movieOfs+movieSize);
  while (moviePos < movieOfs+movieSize) {
    char[4] sign;
    st.seek(moviePos);
    st.rawReadExact(sign[]);
    uint sz = st.readNum!uint();
    //writeln(sz, " ", sign);
    moviePos += 8+sz;
    if (moviePos&0x01) ++moviePos;
    if (sign == "00dc") {
      if (encframe.length < sz) encframe.length = sz;
      st.rawReadExact(encframe[0..sz]);
      zmd.decodeFrame(encframe[0..sz]);
      //writeln(zmd.width, "x", zmd.height, " : ", zmd.format);
      if (zmd.format != Codec.Format.bpp8 && zmd.format != Codec.Format.bpp32) throw new PlayerError("invalid frame format");
      //if (zmd.width != videoW || zmd.height != videoH) throw new PlayerError("frame size changes are not supported yet");
      if (zmd.paletteChanged) {
        auto pal = zmd.palette;
        foreach (immutable idx; 0..256) framepal[idx] = rgb2col(pal[idx*3+0], pal[idx*3+1], pal[idx*3+2]);
      }
      ++curFrame;
      return true;
    }
  }
  return false;
}


////////////////////////////////////////////////////////////////////////////////
void realizeFrame () {
  foreach (immutable y; 0..zmd.height) {
    auto src = zmd.line(y).ptr;
    auto dst = vlVScr+y*vlWidth;
    uint wdt = zmd.width;
    if (wdt > vlWidth) wdt = vlWidth;
    if (zmd.format == Codec.Format.bpp8) {
      foreach (immutable x; 0..wdt) *dst++ = framepal[*src++];
    } else {
      import core.stdc.string : memcpy;
      memcpy(dst, src, wdt*4);
    }
  }
}


private void updateCB (int elapsedTicks) {
  if (!videoDone && !paused) videoDone = !loadNextFrame(aviFl);
  vlsOvl.fillRect(0, 0, vlsOvl.width, vlsOvl.height, 0);
  realizeFrame();
  if (!videoDone) {
    if (curFrame) vlsOvl.hline(0, 0, cast(uint)(cast(ulong)vlsOvl.width*curFrame/framesTotal), rgb2col(0, 255, 0));
    if (paused) vlsOvl.drawOutlineProp(3, 3, "paused", rgb2col(255, 127, 0), 0);
  } else {
    vlsOvl.drawOutlineProp(3, 3, "DONE!", rgb2col(255, 0, 0), 0);
  }
  vlFrameChanged();
}


////////////////////////////////////////////////////////////////////////////////
private void keyDownCB (in ref SDL_KeyboardEvent ev) {
  if (ev.keysym.sym == SDLK_RETURN && (ev.keysym.mod&KMOD_ALT)) { vlSwitchFullscreen(); return; }
  if (ev.keysym.sym == SDLK_ESCAPE) { vlPostQuitMessage(); return; }
  switch (ev.keysym.sym) {
    case SDLK_SPACE: paused = !paused; break;
    /*
    case SDLK_UP: case SDLK_KP_8:
    case SDLK_LEFT: case SDLK_KP_4:
      if (spmasked) {
        if (num > 0) num -= 2;
      } else {
        if (findByNum(--num) == uint.max) ++num;
      }
      break;
    case SDLK_DOWN: case SDLK_KP_2:
    case SDLK_RIGHT: case SDLK_KP_6:
      if (spmasked) {
        if (findByNum(num+1) != uint.max && findByNum(num+2) != uint.max) {
          num += 2;
        } else {
          if (findByNum(num+1) != uint.max) {  import iv.writer; writeln("extra sprite!"); }
        }
      } else {
        if (findByNum(++num) == uint.max) --num;
      }
      break;
    */
    default:
  }
}


////////////////////////////////////////////////////////////////////////////////
void main (string[] args) {
  vlProcessArgs(args);
  if (args.length != 2) {
    import iv.writer;
    writeln("WTF?!");
    return;
  }
  aviFl = File(args[1]);
  loadHeader(aviFl);
  vlWidth = videoW;
  vlHeight = videoH;
  if (videoW > 320 || videoH > 400) vlMag2x = false;
  try {
    vlInit("ZMBV Player/SDL");
  } catch (Throwable e) {
    import iv.writer;
    writeln("FATAL: ", e.msg);
    return;
  }
  vlFPS = fps;
  vlOnUpdate = &updateCB;
  vlOnKeyDown = &keyDownCB;
  vlMainLoop();
}
