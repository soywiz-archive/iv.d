/* Invisible Vector Library
 * ported by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * Understanding is not required. Only obedience.
 * yes, this D port is GPLed. thanks to all "active" members of D
 * community, and for all (zero) feedback posts.
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
module iv.nanovg.perf;
private:

import iv.nanovg.engine;

public final class PerfGraph {
public:
  enum Style {
    FPS,
    MSec,
    Percent,
  }

  enum width = 200;
  enum height = 35;

private:
  enum HistorySize = 100;

  Style gstyle;
  char[32] name;
  float[HistorySize] values;
  string fontname;
  int head;

public:
  this (const(char)[] aname, Style astyle=Style.FPS, string afontname="sans") {
    gstyle = astyle;
    values[] = 0;
    if (aname.length > name.length) aname = aname[0..name.length];
    name[] = 0;
    if (aname.length) name[0..aname.length] = aname[];
    fontname = afontname;
  }

  @property Style style () const pure nothrow @safe @nogc { pragma(inline, true); return gstyle; }
  @property void style (Style v) pure nothrow @safe @nogc { pragma(inline, true); gstyle = v; }

  // frameTime: in seconds
  void update (float frameTime) {
    import std.math : isNaN, isFinite;
    if (!isNaN(frameTime)) {
      if (!isFinite(frameTime)) frameTime = 0;
      head = (head+1)%HistorySize;
      values.ptr[head] = frameTime;
    }
  }

  float getAverage () const {
    float avg = 0;
    foreach (float v; values) avg += v;
    return avg/cast(float)HistorySize;
  }


  void render (NVGContext vg, float x, float y) {
    import core.stdc.stdio : snprintf;

    if (vg is null) return;
    float avg = getAverage();

    vg.beginPath();
    vg.rect(x, y, width, height);
    vg.fillColor(nvgRGBA(0, 0, 0, 128));
    vg.fill();

    vg.beginPath();
    vg.moveTo(x, y+height);
    final switch (gstyle) {
      case Style.FPS:
        foreach (int i; 0..HistorySize) {
          float v = 1.0f/(0.00001f+values.ptr[(head+i)%HistorySize]);
          if (v > 80.0f) v = 80.0f;
          float vx = x+(cast(float)i/(HistorySize-1))*width;
          float vy = y+height-((v/80.0f)*height);
          vg.lineTo(vx, vy);
        }
        break;
      case Style.Percent:
        foreach (int i; 0..HistorySize) {
          float v = values.ptr[(head+i)%HistorySize]*1.0f;
          if (v > 100.0f) v = 100.0f;
          float vx = x+(cast(float)i/(HistorySize-1))*width;
          float vy = y+height-((v/100.0f)*height);
          vg.lineTo(vx, vy);
        }
        break;
      case Style.MSec:
        foreach (int i; 0..HistorySize) {
          float v = values.ptr[(head+i)%HistorySize]*1000.0f;
          if (v > 20.0f) v = 20.0f;
          float vx = x+(cast(float)i/(HistorySize-1))*width;
          float vy = y+height-((v/20.0f)*height);
          vg.lineTo(vx, vy);
        }
        break;
    }
    vg.lineTo(x+width, y+height);
    vg.fillColor(nvgRGBA(255, 192, 0, 128));
    vg.fill();

    vg.fontFace(fontname);

    if (name[0] != '\0') {
      vg.fontSize(14.0f);
      vg.textAlign(NVGAlign.Left|NVGAlign.Top);
      vg.fillColor(nvgRGBA(240, 240, 240, 192));
      uint len = 0; while (len < name.length && name.ptr[len]) ++len;
      vg.text(x+3, y+1, name.ptr[0..len]);
    }

    char[64] str;
    final switch (gstyle) {
      case Style.FPS:
        vg.fontSize(18.0f);
        vg.textAlign(NVGAlign.Right|NVGAlign.Top);
        vg.fillColor(nvgRGBA(240, 240, 240, 255));
        auto len = snprintf(str.ptr, str.length, "%.2f FPS", 1.0f/avg);
        vg.text(x+width-3, y+1, str.ptr[0..len]);

        vg.fontSize(15.0f);
        vg.textAlign(NVGAlign.Right|NVGAlign.Bottom);
        vg.fillColor(nvgRGBA(240, 240, 240, 160));
        len = snprintf(str.ptr, str.length, "%.2f ms", avg*1000.0f);
        vg.text(x+width-3, y+height-1, str.ptr[0..len]);
        break;
      case Style.Percent:
        vg.fontSize(18.0f);
        vg.textAlign(NVGAlign.Right|NVGAlign.Top);
        vg.fillColor(nvgRGBA(240, 240, 240, 255));
        auto len = snprintf(str.ptr, str.length, "%.1f %%", avg*1.0f);
        vg.text(x+width-3, y+1, str.ptr[0..len]);
        break;
      case Style.MSec:
        vg.fontSize(18.0f);
        vg.textAlign(NVGAlign.Right|NVGAlign.Top);
        vg.fillColor(nvgRGBA(240, 240, 240, 255));
        auto len = snprintf(str.ptr, str.length, "%.2f ms", avg * 1000.0f);
        vg.text(x+width-3, y+1, str.ptr[0..len]);
        break;
    }
  }
}
