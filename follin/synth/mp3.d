/* Invisible Vector Library
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
module iv.follin.synth.mp3;

import iv.follin.engine : TflChannel, tflShort2Float;

static if (__traits(compiles, { import iv.minimp3; })) {
import iv.minimp3;


// ////////////////////////////////////////////////////////////////////////// //
class MP3Channel : TflChannel {
  private import core.stdc.stdio : FILE, fopen, fread, fclose, ftell, fseek;
  MP3DecoderNoGC mp3;
  int hasframes; // 0: eof
  int frused;
  long vrtotalFrames = -1;
  FILE* fi;

  this (string fname) {
    import core.stdc.stdio;
    import std.string : toStringz;

    fi = fopen(fname.toStringz, "rb");
    if (fi is null) return;

    mp3 = new MP3DecoderNoGC((void[] buf) {
      if (fi is null) return -1;
      auto rd = fread(buf.ptr, 1, buf.length, fi);
      //{ import core.stdc.stdio; printf("*** reading %u bytes, got %d bytes\n", cast(uint)buf.length, cast(int)rd); }
      if (rd < 0) return -1;
      return cast(int)rd;
    });
    if (!mp3.valid) { fclose(fi); fi = null; return; }

    // scan file to determine number of frames
    auto opos = ftell(fi);
    auto info = mp3Scan((void[] buf) {
      auto rd = fread(buf.ptr, 1, buf.length, fi);
      if (rd < 0) return -1;
      return cast(int)rd;
    });
    fseek(fi, opos, 0);

    if (!info.valid) {
      mp3.close();
      fclose(fi);
      fi = null;
      mp3.destroy;
      mp3 = null;
      return;
    }
    //writeln("sample rate: ", info.sampleRate);
    //writeln("channels   : ", info.channels);
    //writeln("samples    : ", info.samples);
    //auto seconds = info.samples/info.sampleRate;
    //writefln("time: %2s:%02s", seconds/60, seconds%60);

    sampleRate = mp3.sampleRate;
    { import core.stdc.stdio; printf("%uHz, %u channels\n", mp3.sampleRate, mp3.channels); }

    vrtotalFrames = info.samples;
    hasframes = cast(uint)mp3.frameSamples.length;
    stereo = (mp3.channels == 2);
  }

  ~this () {
    if (fi !is null) { fclose(fi); fi = null; }
  }

  final @property bool closed () const nothrow @nogc { return (mp3 is null || fi is null || !mp3.valid); }

  override @property long totalMsecs () { return (vrtotalFrames >= 0 ? vrtotalFrames*1000/sampleRate : -1); }

  override uint fillFrames (float[] buf) nothrow {
    if (closed) return 0;
    uint res = 0;
    auto dest = buf.ptr;
    auto left = cast(uint)buf.length;
    while (left > 0 && !closed) {
      //{ import core.stdc.stdio; printf("left=%u; frused=%u; hasframes=%u\n", left, frused, hasframes); }
      if (frused < hasframes) {
        uint cvt = hasframes-frused;
        if (cvt > left) cvt = left;
        auto smp = mp3.frameSamples.ptr+frused;
        tflShort2Float(smp[0..cvt], dest[0..cvt]);
        dest += cvt;
        frused += cvt;
        res += cvt;
        left -= cvt;
      } else {
        frused = 0;
        //{ import core.stdc.stdio; printf("*** decoding...\n"); }
        if (mp3.decodeNextFrame()) {
          //{ import core.stdc.stdio; printf("*** decoded!\n"); }
          hasframes = cast(uint)mp3.frameSamples.length;
        } else {
          hasframes = 0;
          fclose(fi);
          fi = null;
        }
      }
    }
    return res/(stereo ? 2 : 1); // frames, not samples
  }
}
}
