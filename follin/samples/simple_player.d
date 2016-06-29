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
module vorbis_player is aliced;

import core.atomic;

import iv.follin;
import iv.rawtty;
import iv.encoding;

import iv.drflac;
import iv.stb.vorbis;


long totalFrames (TflChannel chan) {
  if (chan is null) return 0;
  if (auto cc = cast(VorbisChannel)chan) return cc.totalFrames;
  if (auto cc = cast(FlacChannel)chan) return cc.totalFrames;
  if (auto cc = cast(MP3Channel)chan) return cc.totalFrames;
  return 0;
}


int quality = TflChannel.QualityMusic;

void playOgg (string fname) {
  import std.string : toStringz;

  enum {
    Unknown,
    Vorbis,
    Flac,
    MP3,
  }

  TflChannel chan = null;

  // determine format
  int ftype = Unknown;
  auto namez = fname.toStringz;
  if (auto flc = drflac_open_file(namez)) {
    drflac_close(flc);
    ftype = Flac;
    chan = new FlacChannel(fname);
    { import core.stdc.stdio : printf; printf("FLAC\n"); }
  } else {
    auto vf = new VorbisDecoder(fname);
    if (!vf.closed) {
      ftype = Vorbis;
      vf.destroy;
      chan = new VorbisChannel(fname);
      { import core.stdc.stdio : printf; printf("VORBIS\n"); }
    } else {
      vf.destroy;
      auto mp3 = new MP3Channel(fname);
      if (!mp3.closed) {
        ftype = MP3;
        chan = mp3;
        { import core.stdc.stdio : printf; printf("MP3\n"); }
      } else {
        mp3.destroy;
      }
    }
  }

  if (chan is null /*|| chan.totalFrames == 0*/) return;

  if (auto vc = cast(VorbisChannel)chan) {
    for (;;) {
      import std.stdio;
      auto name = vc.vf.comment_name;
      auto value = vc.vf.comment_value;
      if (name is null) break;
      if (utf8Valid(value)) value = recodeToKOI8(value);
      writeln("  ", name, "=", value);
      vc.vf.comment_skip();
    }
  } else if (auto fc = cast(FlacChannel)chan) {
    foreach (string val; fc.comments) {
      import std.stdio;
      if (utf8Valid(val)) val = recodeToKOI8(val);
      writeln("  ", val);
    }
  }

  auto vrTotalTimeMsec = cast(uint)(cast(ulong)chan.totalFrames*1000/chan.sampleRate);
  {
    import std.stdio;
    writefln("%2s:%02s", vrTotalTimeMsec/1000/60, (vrTotalTimeMsec/1000)%60);
  }

  if (!tflAddChannel("ogg", chan, TFLmusic, quality)) {
    import core.stdc.stdio;
    fprintf(stderr, "ERROR: can't add ogg channel!\n");
    return;
  }
  while (tflIsChannelAlive("ogg")) {
    import core.thread;
    import core.time;
    Thread.sleep(dur!"msecs"(500));
  }
  assert(!tflIsChannelAlive("ogg"));
}


// ////////////////////////////////////////////////////////////////////////// //
void main (string[] args) {
  string[] playlist;

  if (args.length < 2) throw new Exception("filename?");

  bool nomoreargs = false;

  foreach (string arg; args[1..$]) {
    if (args.length == 0) continue;
    if (!nomoreargs) {
      if (arg == "--") { nomoreargs = true; continue; }
      if (arg == "--cubic") { quality = -1; continue; }
      if (arg == "--best") { quality = 10; continue; }
      if (arg[0] == '-') {
        if (arg.length == 2 && arg[1] >= '0' && arg[1] <= '9') { quality = arg[1]-'0'; continue; }
        if (arg.length == 3 && arg[1] == 'q' && arg[2] >= '0' && arg[2] <= '9') { quality = arg[2]-'0'; continue; }
        throw new Exception("unknown option: '"~arg~"'");
      }
    }
    import std.file : exists;
    if (!arg.exists) {
      import core.stdc.stdio;
      printf("skipped '%.*s'\n", cast(uint)arg.length, arg.ptr);
    } else {
      playlist ~= arg;
    }
  }

  if (playlist.length == 0) throw new Exception("no files!");

  tflInit();
  scope(exit) tflDeinit();
  { import std.stdio; writeln("latency: ", tflLatency); }

  foreach (string fname; playlist) {
    import std.stdio;
    writeln(fname);
    playOgg(fname);
  }
}
