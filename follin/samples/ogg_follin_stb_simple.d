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
module ogg_follin is aliced;

import iv.follin;
import iv.stb.vorbis;


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


void playOgg() (string fname, bool asMusic) {
  auto chan = new VorbisChannel(fname);

  if (chan.vf) {
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

  if (!tflAddChannel("ogg", chan, TFLmusic, (asMusic ? TflChannel.QualityMusic : -1))) {
    import core.stdc.stdio;
    fprintf(stderr, "ERROR: can't add ogg channel!\n");
    return;
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
}


// ////////////////////////////////////////////////////////////////////////// //
void main (string[] args) {
  if (args.length < 2) throw new Exception("filename?");

  tflInit();
  scope(exit) tflDeinit();
  { import std.stdio; writeln("latency: ", tflLatency); }

  playOgg(args[1], (args.length == 2));
}
