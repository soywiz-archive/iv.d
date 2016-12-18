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
// Synthesizing a Plucked String Sound With the Karplus-Strong Algorithm
// http://blog.demofox.org/2016/06/16/synthesizing-a-pluked-string-sound-with-the-karplus-strong-algorithm/
module ksss;

import iv.follin;
import iv.rawtty;


// ////////////////////////////////////////////////////////////////////////// //
struct KarplusStrongString {
private:
  float* buffer;
  uint bufsize;
  uint bufused;
  uint index;
  float feedback;
  int seed;

private:
  static uint nextrand32 (ref int seed) nothrow @trusted @nogc {
    static if (__VERSION__ > 2067) pragma(inline, true);
    if (!seed) seed = 0x29a; // arbitrary number
    seed *= 16807;
    return cast(uint)seed;
  }

  // gives [0..1] result (wow!)
  static float nextfrand (ref int seed) nothrow @trusted @nogc {
    // fast floating point rand, suitable for noise
    align(1) static union FITrick {
    align(1):
      float fres;
      uint ires;
    }
    //static if (__VERSION__ > 2067) pragma(inline, true);
    if (!seed) seed = 0x29a; // arbitrary number
    seed *= 16807;
    FITrick fi = void;
    fi.ires = (((cast(uint)seed)>>9)|0x3f800000);
    return fi.fres-1.0f;
  }

public:
  void setup (float aFreq, uint aSRate, float aFeedback) nothrow @nogc {
    feedback = aFeedback;
    index = 0;
    bufused = cast(uint)(cast(float)aSRate/aFreq);
    assert(bufused > 0);
    if (bufused > bufsize) {
      import core.stdc.stdlib : realloc;
      buffer = cast(float*)realloc(buffer, bufused*buffer[0].sizeof); //FIXME: check for errors here!
      bufsize = bufused;
    }
    foreach (immutable idx, ref v; buffer[0..bufused]) {
      //import std.random : uniform;
      //v = uniform!"[)"(0.0f, 1.0f)*2.0f-1.0f; //((float)rand()) / ((float)RAND_MAX) * 2.0f - 1.0f;  // noise
      v = nextfrand(seed)*2.0f-1.0f;
      //v = cast(float)idx/cast(float)bufused; // saw wave
    }
  }

  @property float nextSample() () {
    int previdx = (index-1+bufused)%bufused;
    int nextidx = (index+1)%bufused;
    // get our sample to return
    float res = buffer[index];
    // low pass filter (average) some samples
    buffer[index] = (buffer[index]+buffer[nextidx])*0.5f*feedback;
    //buffer[index] = (buffer[previdx]+buffer[index]+buffer[nextidx])/3.0f*feedback;
    // move to the next sample
    index = nextidx;
    // return the sample from the buffer
    return res;
  }

  /* calculate the aFreq of the specified note.
   * fractional notes allowed!
   * aFreq = 440x(2^(n/12))
   *
   * N=0 is A4
   * N=1 is A#4
   * etc...
   *
   * notes go like so...
   * 0  = A
   * 1  = A#
   * 2  = B
   * 3  = C
   * 4  = C#
   * 5  = D
   * 6  = D#
   * 7  = E
   * 8  = F
   * 9  = F#
   * 10 = G
   * 11 = G#
   *
   * octave is just a freq if note < 0
   */
  static float calcFrequency() (float octave, float note) {
    if (note < 0) {
      return octave;
    } else {
      import std.math : pow;
      return cast(float)(440*pow(2.0, (cast(double)((octave-4)*12+note))/12.0));
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
struct SongPart {
  float octave; // or freq if note < 0
  float note;
  float feedback;
  float duration; // in seconds
}

static immutable SongPart[$] song = [
  // twinkle
  SongPart(3, 0, 0.996f, 0.5),
  SongPart(3, 0, 0.996f, 0.5),
  SongPart(3, 7, 0.996f, 0.5),
  SongPart(3, 7, 0.996f, 0.5),
  SongPart(3, 9, 0.996f, 0.5),
  SongPart(3, 9, 0.996f, 0.5),
  SongPart(3, 7, 0.996f, 0.7),
  SongPart(-1, -1, 0.996f, 0.5), // silence
  // strum
  //SongPart(0, 0, 0, 0), // loop mark
  SongPart(55,     -1, 0.996f, 5.0),
  //SongPart(55+110, -1, 0.996f, 1.0),
  //SongPart(55+220, -1, 0.996f, 1.0),
  //SongPart(55+330, -1, 0.996f, 1.0),
];


// ////////////////////////////////////////////////////////////////////////// //
public class KSSString : TflChannel {
  KarplusStrongString str;
  int timeleft;
  int songlooppos = -1;
  int songnext;
  bool silence;
  const(SongPart)[] song;

  this (const(SongPart)[] asong) {
    song = asong;
    stereo = false;
  }

  override uint fillFrames (float[] buf) nothrow {
    uint pos = 0;
    while (pos < buf.length) {
      if (timeleft <= 0) {
        if (songnext < 0 || songnext >= song.length) {
          songnext = songlooppos;
          if (songnext < 0 || songnext >= song.length) return pos; // no more
        }
        if (song[songnext].duration == 0) {
          songlooppos = songnext+1;
        } else {
          timeleft = cast(int)(cast(float)sampleRate*song[songnext].duration);
          // setup new string
          if (song[songnext].octave < 0) {
            silence = true;
          } else {
            silence = false;
            str.setup(str.calcFrequency(song[songnext].octave, song[songnext].note), sampleRate, song[songnext].feedback);
          }
          //{ import core.stdc.stdio : printf; printf("part #%u; time=%u; octave=%g; note=%g\n", cast(uint)songnext, cast(uint)timeleft, cast(double)song[songnext].octave, cast(double)song[songnext].note); }
        }
        ++songnext;
      } else {
        buf[pos++] = (silence ? 0.0f : str.nextSample()); //*0.5f; // multiply to keep from clipping
        --timeleft;
      }
    }
    return pos; // return number of frames
  }
}


// ////////////////////////////////////////////////////////////////////////// //
void playSfx () {
  import core.sys.posix.unistd : usleep;

  auto chan = new KSSString(song[]);
  chan.volume = 220;
  if (!tflAddChannel("sfx", chan, TFLdefault, TflChannel.QualitySfx)) {
    import core.stdc.stdio;
    fprintf(stderr, "ERROR: can't add sfx channel!\n");
    return;
  }

  ttySetRaw();
  scope(exit) ttySetNormal();

  //tflPaused = false; // play it!
  while (tflIsChannelAlive("sfx")) {
    // process keys
    if (ttyWaitKey(200)) {
      auto key = ttyReadKey();
      switch (key) {
        case " ":
          tflPaused = !tflPaused;
          break;
        case "q":
          tflKillChannel("sfx");
          break;
        default:
      }
    }
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
