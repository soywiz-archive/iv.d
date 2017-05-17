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
module sfxr_follin /*is aliced*/;

import iv.alice;
import iv.follin;


// ////////////////////////////////////////////////////////////////////////// //
void playSfx() (in auto ref Sfxr sfx) {
  import core.sys.posix.unistd : usleep;

  foreach (immutable count; 0..1) {
    auto chan = new SfxChannel(sfx);
    chan.volume = 128;
    if (!tflAddChannel("sfx", chan, TFLdefault, TflChannel.QualitySfx)) {
      import core.stdc.stdio;
      fprintf(stderr, "ERROR: can't add sfx channel!\n");
      return;
    }
    //tflPaused = false; // play it!
    while (tflIsChannelAlive("sfx")) {
      usleep(5*1000); // 5 ms
      //import core.memory : GC;
      //GC.collect();
      //usleep(1000);
    }
    assert(!tflIsChannelAlive("sfx"));
  }
  //{ import core.stdc.stdio; printf("sfx complete\n"); }
  // sleep 300 ms
  foreach (immutable _; 0..300) usleep(1000);
  //tflPaused = true; // just in case
}


// ////////////////////////////////////////////////////////////////////////// //
void main (string[] args) {
  import std.random;

  tflInit();
  scope(exit) tflDeinit();

  Sfxr sfxr;
  sfxr.setSeed(uniform!"[]"(int.min, int.max));

  if (args.length > 1) {
    import std.stdio;
    bool wantHelp = (args[1] == "-h" || args[1] == "--help");
    int count = 0;
    foreach (string mem; __traits(allMembers, Sfxr)) {
      static if (mem.length > 3 && mem[0..3] == "rnd" && mem[3] >= 'A' && mem[3] <= 'Z') {
        string s = cast(char)(mem[3]+32)~mem[4..$];
        if (wantHelp) {
          writeln(s);
        } else {
          if (s == args[1]) {
            writeln("generating ", s);
            mixin("sfxr."~mem~"();");
            sfxr.save(File("000.snd", "w"));
            sfxr.playSfx();
            return;
          } else if (args[1] == "rnd" || args[1] == "random") {
            ++count;
          }
        }
      }
    }
    if (wantHelp) return;
    if (args[1] == "rnd") {
      int seed = uniform!"[]"(int.min, int.max);
      int n = Sfxr.nextrand32(seed)%count;
      foreach (string mem; __traits(allMembers, Sfxr)) {
        static if (mem.length > 3 && mem[0..3] == "rnd" && mem[3] >= 'A' && mem[3] <= 'Z') {
          if (n-- == 0) {
            string s = cast(char)(mem[3]+32)~mem[4..$];
            writeln("generating ", s);
            mixin("sfxr."~mem~"();");
            sfxr.save(File("000.snd", "w"));
            sfxr.playSfx();
            return;
          }
        }
      }
    }
    sfxr.load(File(args[1]));
  } else {
    //sfxr.rndExplosion();
    sfxr.load(import("zpick1.snd"));
  }
  sfxr.playSfx();
}
