module perf;
private:

import iv.nanovg;

import core.stdc.stdio : sprintf;
import core.stdc.string : memset, strncpy;


public alias GraphrenderStyle = int;
public enum /*GraphrenderStyle*/ {
  GRAPH_RENDER_FPS,
  GRAPH_RENDER_MS,
  GRAPH_RENDER_PERCENT,
}

enum GRAPH_HISTORY_COUNT = 100;
public struct PerfGraph {
  int style;
  char[32] name;
  float[GRAPH_HISTORY_COUNT] values;
  string fontname;
  int head;
}


public void initGraph (PerfGraph* fps, int style, const(char)[] name, string fontname="sans") {
  memset(fps, 0, PerfGraph.sizeof);
  fps.style = style;
  if (name.length > fps.name.length) name = name[0..fps.name.length];
  fps.name[] = 0;
  if (name.length) fps.name[0..name.length] = name[];
  fps.fontname = fontname;
}


public void updateGraph (PerfGraph* fps, float frameTime) {
  fps.head = (fps.head+1)%GRAPH_HISTORY_COUNT;
  fps.values[fps.head] = frameTime;
}


public float getGraphAverage (PerfGraph* fps) {
  float avg = 0;
  foreach (float v; fps.values) avg += v;
  return avg/cast(float)GRAPH_HISTORY_COUNT;
}


public void renderGraph (NVGcontext* vg, float x, float y, PerfGraph* fps) {
  int i;
  float avg, w, h;
  char[64] str;

  avg = getGraphAverage(fps);

  w = 200;
  h = 35;

  nvgBeginPath(vg);
  nvgRect(vg, x, y, w, h);
  nvgFillColor(vg, nvgRGBA(0, 0, 0, 128));
  nvgFill(vg);

  nvgBeginPath(vg);
  nvgMoveTo(vg, x, y+h);
  if (fps.style == GRAPH_RENDER_FPS) {
    for (i = 0; i < GRAPH_HISTORY_COUNT; i++) {
      float v = 1.0f / (0.00001f + fps.values[(fps.head+i) % GRAPH_HISTORY_COUNT]);
      float vx, vy;
      if (v > 80.0f) v = 80.0f;
      vx = x + (cast(float)i/(GRAPH_HISTORY_COUNT-1)) * w;
      vy = y + h - ((v / 80.0f) * h);
      nvgLineTo(vg, vx, vy);
    }
  } else if (fps.style == GRAPH_RENDER_PERCENT) {
    for (i = 0; i < GRAPH_HISTORY_COUNT; i++) {
      float v = fps.values[(fps.head+i) % GRAPH_HISTORY_COUNT] * 1.0f;
      float vx, vy;
      if (v > 100.0f) v = 100.0f;
      vx = x + (cast(float)i/(GRAPH_HISTORY_COUNT-1)) * w;
      vy = y + h - ((v / 100.0f) * h);
      nvgLineTo(vg, vx, vy);
    }
  } else {
    for (i = 0; i < GRAPH_HISTORY_COUNT; i++) {
      float v = fps.values[(fps.head+i) % GRAPH_HISTORY_COUNT] * 1000.0f;
      float vx, vy;
      if (v > 20.0f) v = 20.0f;
      vx = x + (cast(float)i/(GRAPH_HISTORY_COUNT-1)) * w;
      vy = y + h - ((v / 20.0f) * h);
      nvgLineTo(vg, vx, vy);
    }
  }
  nvgLineTo(vg, x+w, y+h);
  nvgFillColor(vg, nvgRGBA(255, 192, 0, 128));
  nvgFill(vg);

  nvgFontFace(vg, fps.fontname);

  if (fps.name[0] != '\0') {
    nvgFontSize(vg, 14.0f);
    nvgTextAlign(vg, NVGalign.Left|NVGalign.Top);
    nvgFillColor(vg, nvgRGBA(240, 240, 240, 192));
    uint len = 0; while (len < fps.name.length && fps.name.ptr[len]) ++len;
    nvgText(vg, x+3, y+1, fps.name[0..len]);
  }

  if (fps.style == GRAPH_RENDER_FPS) {
    nvgFontSize(vg, 18.0f);
    nvgTextAlign(vg, NVGalign.Right|NVGalign.Top);
    nvgFillColor(vg, nvgRGBA(240, 240, 240, 255));
    sprintf(str.ptr, "%.2f FPS", 1.0f / avg);
    nvgText(vg, x+w-3, y+1, str.ptr, null);

    nvgFontSize(vg, 15.0f);
    nvgTextAlign(vg, NVGalign.Right|NVGalign.Bottom);
    nvgFillColor(vg, nvgRGBA(240, 240, 240, 160));
    sprintf(str.ptr, "%.2f ms", avg * 1000.0f);
    nvgText(vg, x+w-3, y+h-1, str.ptr, null);
  }
  else if (fps.style == GRAPH_RENDER_PERCENT) {
    nvgFontSize(vg, 18.0f);
    nvgTextAlign(vg, NVGalign.Right|NVGalign.Top);
    nvgFillColor(vg, nvgRGBA(240, 240, 240, 255));
    sprintf(str.ptr, "%.1f %%", avg * 1.0f);
    nvgText(vg, x+w-3, y+1, str.ptr, null);
  } else {
    nvgFontSize(vg, 18.0f);
    nvgTextAlign(vg, NVGalign.Right|NVGalign.Top);
    nvgFillColor(vg, nvgRGBA(240, 240, 240, 255));
    sprintf(str.ptr, "%.2f ms", avg * 1000.0f);
    nvgText(vg, x+w-3, y+1, str.ptr, null);
  }
}
