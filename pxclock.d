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
module iv.pxclock is aliced;


// ////////////////////////////////////////////////////////////////////////// //
version(Posix) {
import core.sys.posix.time;

__gshared timespec stt;

shared static this () {
  if (clock_getres(CLOCK_MONOTONIC, &stt) != 0) assert(0, "cannot get clock resolution");
  if (stt.tv_sec != 0 || stt.tv_nsec > 1_000_000) assert(0, "clock resolution too big"); // at least millisecond
  if (clock_gettime(CLOCK_MONOTONIC, &stt) != 0) assert(0, "cannot get clock starting time");
}


///
public ulong clockMicro () nothrow @trusted @nogc {
  timespec ts;
  if (clock_gettime(CLOCK_MONOTONIC, &ts) != 0) assert(0, "cannot get clock time");
  // ignore nanoseconds in stt here: we need only 'differential' time, and it can start with something weird
  return (cast(ulong)(ts.tv_sec-stt.tv_sec))*1000000+ts.tv_nsec/1000;
}


///
public ulong clockMilli () nothrow @trusted @nogc {
  timespec ts;
  if (clock_gettime(CLOCK_MONOTONIC, &ts) != 0) assert(0, "cannot get clock time");
  // ignore nanoseconds in stt here: we need only 'differential' time, and it can start with something weird
  return (cast(ulong)(ts.tv_sec-stt.tv_sec))*1000+ts.tv_nsec/1000000;
}


extern(C) int clock_nanosleep (clockid_t clock_id, int flags, const(timespec)* request, const(timespec)* remain) nothrow @trusted @nogc;

void clockDoSleep (ref timespec rq) nothrow @trusted @nogc {
  timespec rem;
  for (;;) {
    if (rq.tv_sec == 0 && rq.tv_nsec == 0) break;
    import core.stdc.errno;
    auto err = clock_nanosleep(CLOCK_MONOTONIC, 0, &rq, &rem);
    if (err == 0) break;
    if (err != EINTR) assert(0, "sleeping error");
    // continue sleeping
    rq = rem;
  }
}


///
public void clockSleepMicro (uint microsecs) nothrow @trusted @nogc {
  if (microsecs == 0) return;
  timespec rq;
  rq.tv_sec = cast(uint)microsecs/1000000;
  rq.tv_nsec = cast(ulong)(microsecs%1000000)*1000;
  clockDoSleep(rq);
}


///
public void clockSleepMilli (uint millisecs) nothrow @trusted @nogc {
  if (millisecs == 0) return;
  timespec rq;
  rq.tv_sec = cast(uint)millisecs/1000;
  rq.tv_nsec = cast(ulong)(millisecs%1000)*1000000;
  clockDoSleep(rq);
}

} else {
  pragma(msg, "please, use real OS");

  import core.sys.windows.winbase : GetTickCount, Sleep, QueryPerformanceCounter, QueryPerformanceFrequency;

  __gshared long pcfreq;

  shared static this () { QueryPerformanceFrequency(&pcfreq); }

  public ulong clockMicro () nothrow @trusted @nogc {
    long c;
    if (!QueryPerformanceCounter(&c)) return cast(ulong)GetTickCount*1000;
    return c*1000*1000/pcfreq;
  }
  public ulong clockMilli () nothrow @trusted @nogc {
    long c;
    if (!QueryPerformanceCounter(&c)) return cast(ulong)GetTickCount*1000;
    return c*1000/pcfreq;
  }
  public void clockSleepMicro (uint microsecs) nothrow @trusted @nogc {
    auto start = clockMicro();
    while (clockMicro-start < microsecs) {}
  }
  public void clockSleepMilli (uint millisecs) nothrow @trusted @nogc {
    if (millisecs >= 50) { Sleep(millisecs); return; }
    auto start = clockMilli();
    while (clockMilli-start < millisecs) {}
  }
}
