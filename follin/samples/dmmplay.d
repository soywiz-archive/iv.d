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
module dmmplay /*is aliced*/;

import std.stdio;

import iv.alice;
import iv.follin;
import iv.follin.synth.dmm;


// ////////////////////////////////////////////////////////////////////////// //
__gshared uint vrTotalTimeMsec = 0;
__gshared uint vrNextTimeMsec = 0;
__gshared bool vrPaused = false;


void showProgress () {
  auto curTime = tflChannelPlayTimeMsec("dmm");
  if (curTime >= vrNextTimeMsec || tflPaused != vrPaused) {
    vrNextTimeMsec = curTime+1000;
    vrPaused = tflPaused;
    import core.sys.posix.unistd : write;
    import std.string : format;
    auto pstr = "\r%02s:%02s/%02s:%02s%s\e[K".format(curTime/1000/60, curTime/1000%60, vrTotalTimeMsec/1000/60, vrTotalTimeMsec/1000%60, (vrPaused ? " [P]" : ""));
    write(1/*stdout*/, pstr.ptr, cast(uint)pstr.length);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
void main (string[] args) {
  //auto mod = new DmmModule("dmm1/doom2.dmm");
  auto mod = new DmmModule(args.length > 1 ? args[1] : "dmm0/atas.dmm");
  { import core.stdc.stdio; printf("song length: %02u:%02u\n", mod.songLengthMsecs/1000/60, mod.songLengthMsecs/1000%60); }
  vrTotalTimeMsec = mod.songLengthMsecs;

  version(writefile) {
    float[1024] fbuf;
    short[1024] sbuf;

    mod.destRate = 48000;
    auto chan = new DmmChannel(mod);

    import std.stdio;
    auto fo = File("zraw.bin", "w");
    for (;;) {
      auto frames = chan.fillFrames(fbuf[]);
      if (frames == 0) break;
      tflFloat2Short(fbuf[0..frames], sbuf[0..frames]);
      fo.rawWrite(sbuf[0..frames]);
    }
  } else {
    tflInit();
    scope(exit) tflDeinit();
    { import core.stdc.stdio; printf("sampling rate: %uHz\n", tflSampleRate); }
    mod.destRate = tflSampleRate;

    auto chan = new DmmChannel(mod);

    if (!tflAddChannel("dmm", chan, TFLmusic, /*TflChannel.QualityMusic*/3)) {
      import core.stdc.stdio;
      fprintf(stderr, "ERROR: can't add dmm channel!\n");
      return;
    }

    writeln("playing...");
    while (tflIsChannelAlive("dmm")) {
      showProgress();
      import core.sys.posix.unistd : usleep;
      usleep(5000);
    }
    { import core.stdc.stdio; printf("\ndone\n"); }
  }
}
