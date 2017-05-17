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
module ogg_follin /*is aliced*/;

import iv.alice;
import iv.follin;
import iv.stb.vorbis;


// ////////////////////////////////////////////////////////////////////////// //
string[] playlist;
usize plidx;


// ////////////////////////////////////////////////////////////////////////// //
__gshared uint vrTotalTimeMsec = 0;
__gshared uint vrNextTimeMsec = 0;
__gshared bool vrPaused = false;


void showProgress () {
  auto curTime = tflChannelPlayTimeMsec("ogg");
  if (curTime >= vrNextTimeMsec || tflPaused != vrPaused) {
    vrNextTimeMsec = curTime+1000;
    vrPaused = tflPaused;
    import core.sys.posix.unistd : write;
    import std.string : format;
    auto pstr = "\r%02s:%02s/%02s:%02s%s\e[K".format(curTime/1000/60, curTime/1000%60, vrTotalTimeMsec/1000/60, vrTotalTimeMsec/1000%60, (vrPaused ? " [P]" : ""));
    write(1/*stdout*/, pstr.ptr, cast(uint)pstr.length);
  }
}


int quality = TflChannel.QualityMusic;

bool playOgg() () {
  if (plidx >= playlist.length) return false;

  auto chan = new VorbisChannel(playlist[plidx]);

  if (chan.totalFrames == 0 || chan.vf is null) {
    foreach (immutable c; plidx+1..playlist.length) playlist[c-1] = playlist[c];
    playlist.length -= 1;
    return true;
  }

  if (chan.vf) {
    import core.stdc.stdio;
    import std.path : baseName;
    auto bn = playlist[plidx].baseName;
    printf("=== [%u/%u] %.*s (%d) ===\n", cast(uint)(plidx+1), cast(uint)playlist.length, cast(uint)bn.length, bn.ptr, quality);
    for (;;) {
      import std.stdio;
      auto name = chan.vf.comment_name;
      auto value = chan.vf.comment_value;
      if (name is null) break;
      writeln(name, "=", value);
      chan.vf.comment_skip();
    }
  }

  chan.volume = 200;
  vrTotalTimeMsec = cast(uint)(cast(ulong)chan.totalFrames*1000/chan.sampleRate);
  vrNextTimeMsec = 0;

  if (!tflAddChannel("ogg", chan, TFLmusic, quality)) {
    import core.stdc.stdio;
    fprintf(stderr, "ERROR: can't add ogg channel!\n");
    return true;
  }
  { import core.stdc.stdio; printf("active channels: %u\n", tflActiveChannels); }
  while (tflIsChannelAlive("ogg")) {
    showProgress();
    import core.sys.posix.unistd : usleep;
    usleep(5000);
  }
  assert(!tflIsChannelAlive("ogg"));
  { import core.stdc.stdio; printf("\nogg complete\n"); }
  // sleep 100 ms
  foreach (immutable _; 0..100) { import core.sys.posix.unistd : usleep; usleep(1000); }
  return true;
}


// ////////////////////////////////////////////////////////////////////////// //
void main (string[] args) {
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

  while (playOgg()) ++plidx;
}
