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
module iv.timer /*is aliced*/;


struct Timer {
private:
  import core.time : Duration, MonoTime;

  State mState = State.Stopped;
  MonoTime mSTime;
  Duration mAccum;

public:
  enum State {
    Stopped,
    Running,
    Paused,
  }

public:
  string toString () @trusted const {
    import std.string : format;
    Duration d;
    final switch (mState) {
      case State.Stopped: case State.Paused: d = mAccum; break;
      case State.Running: d = mAccum+(MonoTime.currTime-mSTime); break;
    }
    auto tm = d.split!("hours", "minutes", "seconds", "msecs")();
    if (tm.hours) return format("%s:%02d:%02d.%03d", tm.hours, tm.minutes, tm.seconds, tm.msecs);
    if (tm.minutes) return format("%s:%02d.%03d", tm.minutes, tm.seconds, tm.msecs);
    return format("%s.%03d", tm.seconds, tm.msecs);
  }

nothrow @safe @nogc:
  this (State initState) @trusted {
    if (initState == State.Running) start();
  }

  @property const pure {
    auto state () { pragma(inline, true); return mState; }
    bool stopped () { pragma(inline, true); return (mState == State.Stopped); }
    bool running () { pragma(inline, true); return (mState == State.Running); }
    bool paused () { pragma(inline, true); return (mState == State.Paused); }
  }

  void reset () {
    mAccum = Duration.zero;
    mSTime = MonoTime.currTime;
  }

  void start () {
    if (mState != State.Stopped) assert(0, "Timer.start(): invalid timer state");
    mAccum = Duration.zero;
    mState = State.Running;
    mSTime = MonoTime.currTime;
  }

  void stop () {
    if (mState != State.Running) assert(0, "Timer.stop(): invalid timer state");
    mAccum += MonoTime.currTime-mSTime;
    mState = State.Stopped;
  }

  void pause () {
    if (mState != State.Running) assert(0, "Timer.pause(): invalid timer state");
    mAccum += MonoTime.currTime-mSTime;
    mState = State.Paused;
  }

  void resume () {
    if (mState != State.Paused) assert(0, "Timer.resume(): invalid timer state");
    mState = State.Running;
    mSTime = MonoTime.currTime;
  }
}
