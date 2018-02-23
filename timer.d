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
// this essentially duplicates std.datetime.StopWatch, but meh...
module iv.timer;

import iv.pxclock;


struct Timer {
private:
  ulong mSTimeMicro;
  ulong mAccumMicro;
  State mState = State.Stopped;

public:
  enum State {
    Stopped,
    Running,
    Paused,
  }

public:
  string toString () const @trusted {
    char[128] buf = void;
    auto t = toBuffer(buf[]);
    return t.idup;
  }

nothrow @trusted @nogc:
  this (State initState) @trusted {
    if (initState == State.Running) start();
  }

  this (bool startit) @trusted {
    if (startit) start();
  }

  @property const pure {
    auto state () { pragma(inline, true); return mState; }
    bool stopped () { pragma(inline, true); return (mState == State.Stopped); }
    bool running () { pragma(inline, true); return (mState == State.Running); }
    bool paused () { pragma(inline, true); return (mState == State.Paused); }
  }

  @property ulong micro () const {
    final switch (mState) {
      case State.Stopped: case State.Paused: return mAccumMicro;
      case State.Running: return mAccumMicro+(clockMicro-mSTimeMicro);
    }
  }

  @property ulong milli () const { pragma(inline, true); return micro/1000; }

  void reset () {
    mAccumMicro = 0;
    mSTimeMicro = clockMicro;
  }

  void restart () {
    mAccumMicro = 0;
    mState = State.Running;
    mSTimeMicro = clockMicro;
  }

  void start () {
    mAccumMicro = 0;
    mState = State.Running;
    mSTimeMicro = clockMicro;
  }

  void stop () {
    if (mState == State.Running) {
      mAccumMicro += clockMicro-mSTimeMicro;
      mState = State.Stopped;
    }
  }

  void pause () {
    if (mState == State.Running) {
      mAccumMicro += clockMicro-mSTimeMicro;
      mState = State.Paused;
    }
  }

  void resume () {
    if (mState == State.Paused) {
      mState = State.Running;
      mSTimeMicro = clockMicro;
    } else if (mState == State.Stopped) {
      start();
    }
  }

  // 128 chars should be enough for everyone
  char[] toBuffer (char[] dest) const nothrow @trusted @nogc {
    import core.stdc.stdio : snprintf;
    char[128] buf = void;
    ulong d;
    final switch (mState) {
      case State.Stopped: case State.Paused: d = mAccumMicro; break;
      case State.Running: d = mAccumMicro+(clockMicro-mSTimeMicro); break;
    }
    immutable uint micro = cast(uint)(d%1000);
    d /= 1000;
    immutable uint milli = cast(uint)(d%1000);
    d /= 1000;
    immutable uint seconds = cast(uint)(d%60);
    d /= 60;
    immutable uint minutes = cast(uint)(d%60);
    d /= 60;
    immutable uint hours = cast(uint)d;
    uint len;
         if (hours) len = cast(uint)snprintf(buf.ptr, buf.length, "%u:%02u:%02u.%03u", hours, minutes, seconds, milli);
    else if (minutes) len = cast(uint)snprintf(buf.ptr, buf.length, "%u:%02u.%03u", minutes, seconds, milli);
    else if (seconds) len = cast(uint)snprintf(buf.ptr, buf.length, "%u.%03u", seconds, milli);
    else if (micro != 0) len = cast(uint)snprintf(buf.ptr, buf.length, "%ums:%umcs", milli, micro);
    else len = cast(uint)snprintf(buf.ptr, buf.length, "%ums", milli);
    if (len > dest.length) len = dest.length;
    dest.ptr[0..len] = buf.ptr[0..len];
    return dest.ptr[0..len];
  }
}
