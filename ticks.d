/*
 * Simple timer
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
// ////////////////////////////////////////////////////////////////////////// //
// severely outdated, do not use!
module iv.ticks is aliced;


private import core.sys.posix.time;
// idiotic phobos forgets 'nothrow' at it
extern(C) private int clock_gettime (clockid_t, timespec*) @trusted nothrow @nogc;


version(linux) {
  private enum CLOCK_MONOTONIC_RAW = 4;
  private enum CLOCK_MONOTONIC_COARSE = 6;

  shared static this () {
    initializeClock();
  }


  private __gshared timespec videolib_clock_stt;
  private __gshared int gtClockType = CLOCK_MONOTONIC_COARSE;


  nothrow @trusted @nogc:

  private void initializeClock () {
    timespec cres = void;
    bool inited = false;
    if (clock_getres(gtClockType, &cres) == 0) {
      if (cres.tv_sec == 0 && cres.tv_nsec <= cast(long)1000000*1 /*1 ms*/) inited = true;
    }
    if (!inited) {
      gtClockType = CLOCK_MONOTONIC_RAW;
      if (clock_getres(gtClockType, &cres) == 0) {
        if (cres.tv_sec == 0 && cres.tv_nsec <= cast(long)1000000*1 /*1 ms*/) inited = true;
      }
    }
    if (!inited) assert(0, "FATAL: can't initialize clock subsystem!");
    if (clock_gettime(gtClockType, &videolib_clock_stt) != 0) {
      assert(0, "FATAL: can't initialize clock subsystem!");
    }
  }


  /** returns monitonically increasing time; starting value is UNDEFINED (i.e. can be any number); milliseconds */
  ulong getTicks () {
    static if (__VERSION__ > 2067) pragma(inline, true);
    timespec ts = void;
    if (clock_gettime(gtClockType, &ts) != 0) assert(0, "FATAL: can't get real-time clock value!\n");
    // ah, ignore nanoseconds in videolib_clock_stt->stt here: we need only 'differential' time, and it can start with something weird
    return (cast(ulong)(ts.tv_sec-videolib_clock_stt.tv_sec))*1000+ts.tv_nsec/1000000+1;
  }


  /** returns monitonically increasing time; starting value is UNDEFINED (i.e. can be any number); microseconds */
  ulong getTicksMicro () {
    static if (__VERSION__ > 2067) pragma(inline, true);
    timespec ts = void;
    if (clock_gettime(gtClockType, &ts) != 0) assert(0, "FATAL: can't get real-time clock value!\n");
    // ah, ignore nanoseconds in videolib_clock_stt->stt here: we need only 'differential' time, and it can start with something weird
    return (cast(ulong)(ts.tv_sec-videolib_clock_stt.tv_sec))*1000000+ts.tv_nsec/1000+1;
  }
} else version(Windows) {
  private import core.sys.windows.winbase : GetTickCount;

  ulong getTicks () { return GetTickCount(); }

  ulong getTicksMicro () {
    static assert(0, "iv.ticks.getTicksMicro() is not implemented on windoze");
  }
} else {
  static assert(0, "sorry, only GNU/Linux for now; please, fix `getTicks()` and company for your OS!");
}
