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
module iv.follin.synth.flac;

import iv.follin.engine : TflChannel;

static if (__traits(compiles, { import iv.drflac; })) {
import iv.drflac;


// ////////////////////////////////////////////////////////////////////////// //
class FlacChannel : TflChannel {
  drflac* ff;
  int* smpbuf;
  enum smpbufsize = 8192;
  int hasframes; // 0: eof
  float* frsmpbuf;
  int frused;
  long vrtotalFrames = -1;
  string[] comments;

  this (string fname) {
    import core.stdc.stdio;
    import std.string : toStringz;
    import core.stdc.stdlib : malloc, free;

    uint commentCount;
    char* fcmts;
    scope(exit) if (fcmts !is null) free(fcmts);

    ff = drflac_open_file_with_metadata(fname.toStringz, (void* pUserData, drflac_metadata* pMetadata) {
      if (pMetadata.type == DRFLAC_METADATA_BLOCK_TYPE_VORBIS_COMMENT) {
        /*
        */
        if (fcmts !is null) free(fcmts);
        auto csz = drflac_vorbis_comment_size(pMetadata.data.vorbis_comment.commentCount, pMetadata.data.vorbis_comment.comments);
        if (csz > 0 && csz < 0x100_0000) {
          fcmts = cast(char*)malloc(cast(uint)csz);
        } else {
          fcmts = null;
        }
        if (fcmts is null) {
          commentCount = 0;
        } else {
          import core.stdc.string : memcpy;
          commentCount = pMetadata.data.vorbis_comment.commentCount;
          memcpy(fcmts, pMetadata.data.vorbis_comment.comments, cast(uint)csz);
        }
      }
    });
    if (ff is null) {
      import core.stdc.stdio;
      printf("can't open file: '%.*s'\n", cast(uint)fname.length, fname.ptr);
      ff = null;
      return;
    }

    {
      drflac_vorbis_comment_iterator i;
      drflac_init_vorbis_comment_iterator(&i, commentCount, fcmts);
      uint commentLength;
      const(char)* pComment;
      while ((pComment = drflac_next_vorbis_comment(&i, &commentLength)) !is null) {
        if (commentLength > 1024*1024*2) break; // just in case
        comments ~= pComment[0..commentLength].idup;
      }
    }

    if (ff.sampleRate < 1024 || ff.sampleRate > 96000) {
      import core.stdc.stdio;
      printf("fucked file sample rate: '%.*s'\n", cast(uint)fname.length, fname.ptr);
      drflac_close(ff);
      ff = null;
      return;
    }

    if (ff.channels < 1 || ff.channels > 2) {
      import core.stdc.stdio;
      printf("fucked file channels: '%.*s'\n", cast(uint)fname.length, fname.ptr);
      drflac_close(ff);
      ff = null;
      return;
    }
    stereo = (ff.channels == 2);

    sampleRate = ff.sampleRate;
    { import core.stdc.stdio; printf("%uHz, %u channels\n", ff.sampleRate, ff.channels); }

    vrtotalFrames = ff.totalSampleCount/ff.channels;

    smpbuf = cast(int*)malloc(smpbufsize*int.sizeof);
    if (smpbuf is null) {
      drflac_close(ff);
      ff = null;
      return;
    }

    frsmpbuf = cast(float*)malloc(smpbufsize*float.sizeof);
    if (frsmpbuf is null) {
      free(smpbuf);
      smpbuf = null;
      drflac_close(ff);
      ff = null;
      return;
    }
  }

  ~this () {
    import core.stdc.stdlib : free;
    if (ff !is null) drflac_close(ff);
    if (smpbuf !is null) free(smpbuf);
    if (frsmpbuf !is null) free(frsmpbuf);
  }

  override @property long totalMsecs () { return (vrtotalFrames >= 0 ? vrtotalFrames*1000/sampleRate : -1); }

  // `false`: no more frames
  final bool moreFrames () nothrow @nogc {
    if (ff is null) return false;
    if (frused >= hasframes) {
      auto rd = drflac_read_s32(ff, smpbufsize, smpbuf);
      if (rd <= 0) { hasframes = 0; frused = 0; drflac_close(ff); ff = null; return false; } // eof
      int* s = smpbuf;
      float* d = frsmpbuf;
      foreach (immutable _; 0..cast(uint)rd) {
        *d++ = (cast(float)cast(short)((*s++)>>16))/32768.0f;
      }
      hasframes = cast(int)rd;
      frused = 0;
    }
    return true;
  }

  final @property uint framesLeft () nothrow @nogc { return (ff !is null ? hasframes-frused : 0); }

  override uint fillFrames (float[] buf) nothrow @nogc {
    if (!moreFrames) return 0;
    auto fr2put = framesLeft;
    if (fr2put > buf.length) fr2put = cast(uint)(buf.length);
    //{ import core.stdc.stdio; printf("vorbis: writing %u frames; follin wanted %u frames\n", fr2put, cast(uint)(buf.length)); }
    buf[0..fr2put] = frsmpbuf[frused..frused+fr2put];
    frused += fr2put;
    return fr2put/2; // frames, not samples
  }
}
}
