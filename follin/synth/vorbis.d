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
module iv.follin.synth.vorbis;

import iv.follin.engine : TflChannel;

import iv.stb.vorbis;


// ////////////////////////////////////////////////////////////////////////// //
class VorbisChannel : TflChannel {
  stb_vorbis* vf;
  // for stb
  const(float)* left, right;
  int hasframes; // 0: eof
  int frused;
  long vrtotalFrames = -1;

  this (string fname) {
    import core.stdc.stdio;

    int error;
    vf = stb_vorbis_open_filename(fname, &error, null);
    if (vf is null) {
      import core.stdc.stdio;
      printf("can't open file: '%.*s'\n", cast(uint)fname.length, fname.ptr);
      return;
    }

    auto info = stb_vorbis_get_info(vf);

    if (info.sample_rate < 1024 || info.sample_rate > 96000) {
      import core.stdc.stdio;
      printf("fucked file sample rate: '%.*s'\n", cast(uint)fname.length, fname.ptr);
      stb_vorbis_close(vf);
      vf = null;
      return;
    }

    if (info.channels < 1 || info.channels > 2) {
      import core.stdc.stdio;
      printf("fucked file channels: '%.*s'\n", cast(uint)fname.length, fname.ptr);
      stb_vorbis_close(vf);
      vf = null;
      return;
    }

    //chans = info.channels;
    sampleRate = info.sample_rate;
    //{ import core.stdc.stdio; printf("%uHz, %u channels\n", sampleRate, chans); }

    hasframes = 1;
    frused = 1; // hoax
    vrtotalFrames = -1;
    //{ import core.stdc.stdio; printf("vorbis: got %u frames\n", hasframes); }
  }

  ~this () { if (vf !is null) stb_vorbis_close(vf); }

  final @property uint totalFrames () nothrow @nogc {
    if (vrtotalFrames < 0) {
      vrtotalFrames = (vf !is null ? stb_vorbis_stream_length_in_samples(vf) : 0);
      if (vrtotalFrames < 0) vrtotalFrames = 0;
    }
    return cast(uint)vrtotalFrames;
  }

  // `false`: no more frames
  final bool moreFrames () nothrow @nogc {
    if (hasframes == 0) return false;
    if (frused >= hasframes) {
      int haschans;
      float** frbuffer;
      frused = 0;
      hasframes = stb_vorbis_get_frame_float(vf, &haschans, &frbuffer);
      if (hasframes <= 0) { hasframes = 0; stb_vorbis_close(vf); vf = null; return false; } // eof
      //{ import core.stdc.stdio; printf("vorbis: got %u frames\n", hasframes); }
      // setup buffers
      left = frbuffer[0];
      right = frbuffer[haschans > 1 ? 1 : 0];
    }
    return true;
  }

  final @property uint framesLeft () nothrow @nogc { return (hasframes ? hasframes-frused : 0); }

  override uint fillFrames (float[] buf) nothrow @nogc {
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
