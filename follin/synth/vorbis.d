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
module iv.follin.synth.vorbis /*is aliced*/;

import iv.alice;
import iv.follin.engine : TflChannel;

static if (__traits(compiles, () { import iv.stb.vorbis; })) {
import iv.stb.vorbis;


// ////////////////////////////////////////////////////////////////////////// //
class VorbisChannel : TflChannel {
  VorbisDecoder vf;
  // for stb
  const(float)* left, right;
  int hasframes; // 0: eof
  int frused;
  long vrtotalFrames = -666;

  this (string fname) {
    import core.stdc.stdio;

    vf = new VorbisDecoder(fname);
    if (vf.closed) {
      import core.stdc.stdio;
      printf("can't open file: '%.*s'\n", cast(uint)fname.length, fname.ptr);
      vf = null;
      return;
    }

    if (vf.sampleRate < 1024 || vf.sampleRate > 96000) {
      import core.stdc.stdio;
      printf("fucked file sample rate: '%.*s'\n", cast(uint)fname.length, fname.ptr);
      vf.close();
      vf = null;
      return;
    }

    if (vf.chans < 1 || vf.chans > 2) {
      import core.stdc.stdio;
      printf("fucked file channels: '%.*s'\n", cast(uint)fname.length, fname.ptr);
      vf.close();
      vf = null;
      return;
    }
    stereo = (vf.chans == 2);

    sampleRate = vf.sampleRate;
    { import core.stdc.stdio; printf("%uHz, %u channels\n", vf.sampleRate, vf.chans); }

    hasframes = 1;
    frused = 1; // hoax
    vrtotalFrames = -666;
  }

  ~this () {}

  override @property long totalMsecs () {
    if (vrtotalFrames == -666) {
      vrtotalFrames = (vf !is null ? vf.streamLengthInSamples : 0);
      //{ import core.stdc.stdio; printf("vorbis: got %u frames\n", cast(int)vrtotalFrames); }
      if (vrtotalFrames < 0) vrtotalFrames = -1;
    }
    return (vrtotalFrames >= 0 ? vrtotalFrames*1000/sampleRate : -1);
  }

  // `false`: no more frames
  final bool moreFrames () nothrow {
    if (hasframes == 0) return false;
    if (frused >= hasframes) {
      int haschans;
      float** frbuffer;
      frused = 0;
      hasframes = vf.getFrameFloat(&haschans, &frbuffer);
      //{ import core.stdc.stdio; printf("vorbis: got %u frames\n", hasframes); }
      if (hasframes <= 0) { hasframes = 0; vf.close(); vf = null; return false; } // eof
      // setup buffers
      left = frbuffer[0];
      right = frbuffer[haschans > 1 ? 1 : 0];
    }
    return true;
  }

  final @property uint framesLeft () nothrow @nogc { return (hasframes ? hasframes-frused : 0); }

  override uint fillFrames (float[] buf) nothrow {
    if (!moreFrames) return 0;
    auto fr2put = framesLeft;
    if (fr2put > buf.length/2) fr2put = cast(uint)(buf.length/2);
    //{ import core.stdc.stdio; printf("vorbis: writing %u frames; follin wanted %u frames\n", fr2put, cast(uint)(buf.length/2)); }
    frused += fr2put; // skip used frames
    auto d = buf.ptr;
    auto l = left;
    auto r = right;
    foreach (immutable _; 0..fr2put) {
      *d++ = (*l++);
      *d++ = (*r++);
    }
    left = l;
    right = r;
    return fr2put;
  }
}
}
