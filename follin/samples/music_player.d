/* Invisible Vector Library
 * coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * Understanding is not required. Only obedience.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 3 of the License ONLY.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */
module music_player /*is aliced*/;

import core.atomic;

import iv.alice;
import iv.follin;
import iv.rawtty;
import iv.encoding;

import iv.drflac;
import iv.stb.vorbis;


// ////////////////////////////////////////////////////////////////////////// //
string[] playlist;
usize plidx;


// ////////////////////////////////////////////////////////////////////////// //
__gshared uint vrTotalTimeMsec = 0;
__gshared uint vrNextTimeMsec = 0;
__gshared bool vrPaused = false;
__gshared ubyte vrVolume = 255;
__gshared bool forceUp = false;


void showProgress (bool endtime=false) {
  auto curTime = (endtime ? vrTotalTimeMsec : tflChannelPlayTimeMsec("music"));
  if (curTime >= vrNextTimeMsec || tflPaused != vrPaused || forceUp) {
    vrNextTimeMsec = curTime+1000;
    vrPaused = tflPaused;
    import core.sys.posix.unistd : write;
    import std.string : format;
    auto pstr = "\r%02s:%02s/%02s:%02s %3s%%%s\e[K".format(curTime/1000/60, curTime/1000%60, vrTotalTimeMsec/1000/60, vrTotalTimeMsec/1000%60,
      100*vrVolume/255, (vrPaused ? " [P]" : ""));
    write(1/*stdout*/, pstr.ptr, cast(uint)pstr.length);
    forceUp = false;
  }
}


long totalTimeMsec (FileChannel chan) {
  auto res = chan.totalMsecs;
  return (res >= 0 ? res : 0);
}


int quality = TflChannel.QualityMusic;

enum Action { Quit, Prev, Next }

Action playFile () {
  if (plidx >= playlist.length) return Action.Quit;

  Action res = Action.Next;
  FileChannel chan = FileChannel.detect(playlist[plidx]);

  if (chan is null) {
    foreach (immutable c; plidx+1..playlist.length) playlist[c-1] = playlist[c];
    playlist.length -= 1;
    return Action.Prev;
  }

  {
    import core.stdc.stdio;
    import std.path : baseName;
    auto bn = playlist[plidx].baseName;
    printf("=== [%u/%u] %.*s (%d) ===\n", cast(uint)(plidx+1), cast(uint)playlist.length, cast(uint)bn.length, bn.ptr, quality);
  }

  if (auto vc = cast(VorbisChannel)chan.srcchan) {
    for (;;) {
      import std.stdio;
      auto name = vc.vf.comment_name;
      auto value = vc.vf.comment_value;
      if (name is null) break;
      if (utf8Valid(value)) value = recodeToKOI8(value);
      writeln("  ", name, "=", value);
      vc.vf.comment_skip();
    }
  } else if (auto fc = cast(FlacChannel)chan.srcchan) {
    foreach (string val; fc.comments) {
      import std.stdio;
      if (utf8Valid(val)) val = recodeToKOI8(val);
      writeln("  ", val);
    }
  }

  vrTotalTimeMsec = cast(uint)chan.totalTimeMsec;
  vrNextTimeMsec = 0;

  if (!tflAddChannel("music", chan, TFLmusic, quality)) {
    import core.stdc.stdio;
    fprintf(stderr, "ERROR: can't add ogg channel!\n");
    return Action.Quit;
  }

  while (tflIsChannelAlive("music")) {
    showProgress();
    // process keys
    if (ttyWaitKey(200)) {
      auto key = ttyReadKey();
      if (key.key != TtyEvent.Key.Char) continue;
      if (key.ch > 127) continue;
      switch (cast(char)key.ch) {
        case ' ':
          tflPaused = !tflPaused;
          break;
        case 'p':
          if (auto oc = tflChannelObject("music")) {
            auto p = !oc.paused;
            oc.paused = p;
          }
          break;
        case 'q':
          tflKillChannel("music");
          res = Action.Quit;
          break;
        case '<':
          tflKillChannel("music");
          res = Action.Prev;
          break;
        case '>':
          tflKillChannel("music");
          res = Action.Next;
          break;
        case '9':
          if (vrVolume > 0) {
            --vrVolume;
            chan.volume = vrVolume;
            forceUp = true;
          }
          break;
        case '0':
          if (vrVolume < 255) {
            ++vrVolume;
            chan.volume = vrVolume;
            forceUp = true;
          }
          break;
        default:
      }
    }
  }
  assert(!tflIsChannelAlive("music"));
  forceUp = true;
  showProgress(true);
  { import core.stdc.stdio; printf("\n"); }
  // sleep 100 ms
  //foreach (immutable _; 0..100) { import core.sys.posix.unistd : usleep; usleep(1000); }
  return res;
}


// ////////////////////////////////////////////////////////////////////////// //
void main (string[] args) {
  if (ttyIsRedirected) throw new Exception("no redirects, please!");

  if (args.length < 2) throw new Exception("filename?");

  bool nomoreargs = false;
  bool shuffle = false;

  foreach (string arg; args[1..$]) {
    if (args.length == 0) continue;
    if (!nomoreargs) {
      if (arg == "--") { nomoreargs = true; continue; }
      if (arg == "--cubic") { quality = -1; continue; }
      if (arg == "--best") { quality = 10; continue; }
      if (arg == "--shuffle") { shuffle = true; continue; }
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
  if (shuffle) {
    import std.random;
    playlist.randomShuffle;
  }

  ttySetRaw();
  scope(exit) ttySetNormal();

  tflInit();
  scope(exit) tflDeinit();
  { import std.stdio; writeln("latency: ", tflLatency); }

  mainloop: for (;;) {
    final switch (playFile()) with (Action) {
      case Prev: if (plidx > 0) --plidx; break;
      case Next: ++plidx; break;
      case Quit: break mainloop;
    }
  }
}
