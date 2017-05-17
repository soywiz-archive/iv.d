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
module oh440 /*is aliced*/;

import iv.alice;
import iv.follin;


// ////////////////////////////////////////////////////////////////////////// //
public class Oh440Hertz : TflChannel {
  enum Freq = 440;
  //enum Rate = 48000;

  int smpnum;

  this() () {
    //sampleRate = Rate;
    stereo = false;
    volume = 128;
  }

  override uint fillFrames (float[] buf) nothrow {
    foreach (ref f; buf) {
      import std.math : sin, PI;
      float t = cast(float)smpnum/sampleRate;
      t = sin(Freq*2*PI*t);
      f = t;
      //f *= (1-t); // fade effect
      ++smpnum;
    }
    return buf.length; // return number of frames
  }
}


// ////////////////////////////////////////////////////////////////////////// //
void playSfx () {
  import core.sys.posix.unistd : usleep;

  auto chan = new Oh440Hertz();
  chan.volume = 128;
  if (!tflAddChannel("sfx", chan, TFLdefault, TflChannel.QualitySfx)) {
    import core.stdc.stdio;
    fprintf(stderr, "ERROR: can't add sfx channel!\n");
    return;
  }
  //tflPaused = false; // play it!
  foreach (immutable _; 0..1000/10*3) {
    if (!tflIsChannelAlive("sfx")) break;
    usleep(10*1000); // 10 ms
  }
  //tflPaused = true; // just in case
}


// ////////////////////////////////////////////////////////////////////////// //
void main (string[] args) {
  import std.random;

  tflInit();
  scope(exit) tflDeinit();

  playSfx();
}
