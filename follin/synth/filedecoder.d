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
module iv.follin.synth.filedecoder is aliced;

import iv.vfs;

import iv.follin.engine : TflChannel;

import iv.follin.synth.vorbis;
import iv.follin.synth.flac;
import iv.follin.synth.mp3;

static if (__traits(compiles, { import iv.drflac; })) {
  enum IFSF_FLAC_IS_HERE = true;
  import iv.drflac;
} else {
  enum IFSF_FLAC_IS_HERE = false;
}

static if (__traits(compiles, () { import iv.stb.vorbis; })) {
  enum IFSF_VORBIS_IS_HERE = true;
  import iv.stb.vorbis;
} else {
  enum IFSF_VORBIS_IS_HERE = false;
}

static if (__traits(compiles, { import iv.minimp3; })) {
  enum IFSF_MP3_IS_HERE = true;
  import iv.minimp3;
} else {
  enum IFSF_MP3_IS_HERE = false;
}


// ////////////////////////////////////////////////////////////////////////// //
class FileChannel : TflChannel {
  enum Type {
    unknown,
    vorbis,
    flac,
    mp3,
  }

  static FileChannel detect(T:const(char)[]) (T fname) {
    static if (is(T == typeof(null))) {
      return null;
    } else {
      string namestr () { static if (is(T == string)) return fname; else return fname.idup; }
      import std.string : toStringz;
      try {
        FileChannel chan = null;
        // determine format
        static if (IFSF_FLAC_IS_HERE) {
          if (auto flc = drflac_open_file(VFile(fname))) {
            drflac_close(flc);
            return new FileChannelImpl(new FlacChannel(namestr));
          }
        }
        static if (IFSF_VORBIS_IS_HERE) {
          auto vf = new VorbisDecoder(fname);
          if (!vf.closed) {
            vf.destroy;
            return new FileChannelImpl(new VorbisChannel(namestr));
          }
          vf.destroy;
        }
        static if (IFSF_MP3_IS_HERE) {
          auto mp3 = new MP3Channel(namestr);
          if (!mp3.closed) return new FileChannelImpl(mp3);
          mp3.destroy;
        }
      } catch (Exception) {}
      return null;
    }
  }

  @property Type type () const nothrow @nogc { return Type.unknown; }

  @property TflChannel srcchan () { return null; }
}


// ////////////////////////////////////////////////////////////////////////// //
class FileChannelImpl : FileChannel {
private:
  TflChannel chan;

  this (TflChannel achan) {
    chan = achan;
  }

public:
  override @property TflChannel srcchan () { return chan; }

  override @property Type type () const nothrow @nogc {
    if (cast(VorbisChannel)chan) return Type.vorbis;
    if (cast(FlacChannel)chan) return Type.flac;
    if (cast(MP3Channel)chan) return Type.mp3;
    return Type.unknown;
  }

  // in milliseconds; -1: unknown
  override long totalMsecs () { return (chan !is null ? chan.totalMsecs : -1); }

  override uint fillFrames (float[] buf) nothrow {
    if (chan is null) { buf[] = 0; return 0; }
    return chan.fillFrames(buf);
  }
}
