/* coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * Understanding is not required. Only obedience.
 *
 *                   INVISIBLE VECTOR PUBLIC LICENSE
 *                       Version 0, August 2014
 *
 * Copyright (C) 2014 Ketmar Dark <ketmar@ketmar.no-ip.org>
 *
 * Everyone is permitted to copy and distribute verbatim or modified
 * copies of this license document, and changing it is allowed as long
 * as the name is changed.
 *
 *                   INVISIBLE VECTOR PUBLIC LICENSE
 *   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
 *
 * 0. You may not use this software in either source or binary form, any
 *    software derived from this software, any library which uses either
 *    this software or code derived from this software in any other
 *    software which uses Windows API, either directly or indirectly
 *    via any chain of libraries.
 *
 * 1. You may not use this software in either source or binary form, any
 *    software derived from this software, any library which uses either
 *    this software or code derived from this software in any other
 *    software which uses MacOS X API, either directly or indirectly via
 *    any chain of libraries.
 *
 * 2. You may not use this software in either source or binary form, any
 *    software derived from this software, any library which uses either
 *    this software or code derived from this software in any other
 *    software on the territory of Russian Federation, either directly or
 *    indirectly via any chain of libraries.
 *
 * 3. Redistributions of this software in either source or binary form must
 *    retain this list of conditions and the following disclaimer.
 *
 * 4. Otherwise, you are allowed to use this software in any way that will
 *    not violate paragraphs 0, 1, 2 and 3 of this license.
 *
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 * Authors: Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * License: IVPLv0
 */
module iv.timer is aliced;


struct Timer {
  import core.time;

  enum { Stopped, Started }

  this (int initState=Stopped) @trusted {
    if (initState == Started) start();
  }

  enum State {
    Stopped,
    Running,
    Paused
  }

  @property auto state () @safe const nothrow @nogc => mState;

  @property bool stopped () @safe const nothrow @nogc => (mState == State.Stopped);
  @property bool running () @safe const nothrow @nogc => (mState == State.Running);
  @property bool paused () @safe const nothrow @nogc => (mState == State.Paused);

  void reset () @trusted nothrow {
    mAccum = Duration.zero;
    mSTime = MonoTime.currTime;
  }

  void start () @trusted {
    if (mState != State.Stopped) throw new Exception("Timer.start(): invalid timer state");
    mAccum = Duration.zero;
    mState = State.Running;
    mSTime = MonoTime.currTime;
  }

  void stop () @trusted {
    if (mState != State.Running) throw new Exception("Timer.stop(): invalid timer state");
    mAccum += MonoTime.currTime-mSTime;
    mState = State.Stopped;
  }

  void pause () @trusted {
    if (mState != State.Running) throw new Exception("Timer.pause(): invalid timer state");
    mAccum += MonoTime.currTime-mSTime;
    mState = State.Paused;
  }

  void resume () @trusted {
    if (mState != State.Paused) throw new Exception("Timer.resume(): invalid timer state");
    mState = State.Running;
    mSTime = MonoTime.currTime;
  }

  string toString () @trusted const {
    import std.string;
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

private:
  State mState = State.Stopped;
  MonoTime mSTime;
  Duration mAccum;
}
