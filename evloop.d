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
module iv.evloop is aliced;
private:

public import core.time; // for timers, Duration
//import core.time : MonoTime, TimeException;


// ////////////////////////////////////////////////////////////////////////// //
public long mtimeToMSecs (in MonoTime mt) @safe pure nothrow {
  return convClockFreq(mt.ticks, MonoTime.ticksPerSecond, 1_000);
}


public long currentMSecs () @safe nothrow { return mtimeToMSecs(MonoTime.currTime); }


// ////////////////////////////////////////////////////////////////////////// //
enum SIGWINCH = 28;


__gshared int csigfd = -1;

__gshared bool doQuit = false;
__gshared bool doGlobalQuit = false;


// ////////////////////////////////////////////////////////////////////////// //
public bool isGlobalQuit () @trusted nothrow @nogc { return doGlobalQuit; }

public void sendQuitSignal (bool global=false) @trusted @nogc {
  import core.sys.posix.signal : raise, SIGINT;
  doQuit = true;
  if (global) doGlobalQuit = true;
  raise(SIGINT);
}


// ////////////////////////////////////////////////////////////////////////// //
// register signals
void installSignalHandlers () @trusted /*nothrow*/ /*@nogc*/ {
  if (csigfd < 0) {
    import core.sys.posix.signal;
    import core.sys.linux.sys.signalfd;
    sigset_t mask;
    sigemptyset(&mask);
    sigaddset(&mask, SIGTERM);
    sigaddset(&mask, SIGHUP);
    sigaddset(&mask, SIGQUIT);
    sigaddset(&mask, SIGINT);
    sigaddset(&mask, SIGWINCH);
    sigprocmask(SIG_BLOCK, &mask, null); //we block the signals
    csigfd = signalfd(-1, &mask, SFD_NONBLOCK); // sorry
  }
}


// ////////////////////////////////////////////////////////////////////////// //
__gshared curChangeCount = 0;


// ////////////////////////////////////////////////////////////////////////// //
public enum TimerType {
  Periodic,
  Oneshot
}


struct Timer {
  ulong id;
  long interval; // <0: oneshot
  long shotTime; // time when it should shot, in msecs
  void delegate (ulong id) onTimer;
  ulong changeCount; // process this only if changeCount < curChangeCount
}

__gshared Timer[] timers;
__gshared uint timersUsed;
__gshared uint[ulong] timerId2Idx;
__gshared ulong lastTimerId;


/**
 * add new timer.
 *
 * Params:
 *  interval = timer interval
 *  onTimer = callback
 *  type = timer type
 *
 * Returns:
 *  timer id (always positive)
 *
 * Throws:
 *  TimeException on invalid interval
 */
public ulong addTimer (Duration interval, void delegate (ulong id) onTimer, TimerType type=TimerType.Periodic) @trusted
in {
  assert(type >= TimerType.min && type <= TimerType.max);
}
body {
  long iv = interval.total!"msecs";
  if (iv < 1) throw new TimeException("invalid timer interval");
  ulong res;
  Timer tm;
  res = tm.id = ++lastTimerId;
  if (lastTimerId < res) assert(0); // overflow, fuck it
  tm.interval = (type == TimerType.Periodic ? iv : -1);
  tm.shotTime = currentMSecs()+iv;
  tm.onTimer = onTimer;
  tm.changeCount = curChangeCount;
  // add to list
  uint idx = uint.max;
  foreach (auto i; 0..timersUsed) if (timers[i].id == 0) { idx = i; break; }
  if (idx == uint.max) {
    if (timersUsed >= timers.length) timers.length = timers.length+32;
    idx = timersUsed++;
  }
  timers[idx] = tm;
  timerId2Idx[res] = idx;
  return res;
}


public void removeTimer (ulong id) @trusted {
  auto idx = id in timerId2Idx;
  if (idx !is null) {
    timers[*idx].id = 0; // mark as free
    timerId2Idx.remove(id);
    while (timersUsed > 0 && timers[timersUsed-1].id == 0) --timersUsed;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
public enum FDFlags {
  None = 0,
  CanRead = 0x01,
  CanWrite = 0x02,
  Timeout = 0x04,
  Error = 0x80
}


struct FDInfo {
  int fd;
  long toTime; // >=0: time when timeout comes (NOT timeout interval)
  long timeout; // <0: no timeout
  ushort events; // for poll; can be 0 if we need only timeout
  uint pfdIndex; // index in pfds
  void delegate (int fd, FDFlags flags) onEvent;
  ulong changeCount; // process this only if changeCount < curChangeCount
}


import core.sys.posix.poll : pollfd, poll, POLLIN, POLLOUT, POLLERR, POLLHUP, POLLNVAL/*, POLLRDHUP*/;

__gshared pollfd[] pfds;
__gshared uint pfdUsed;
__gshared FDInfo[int] fdset;

shared static this () {
  // [0] is reserved for csigfd
  pfds.length = 32;
  pfds[0].fd = -1;
  pfdUsed = 1;
}


void fixTimeout (ref FDInfo nfo, FDFlags flg, Duration timeout) @safe nothrow {
  if ((flg&FDFlags.Timeout) && timeout != Duration.max && timeout > Duration.zero) {
    nfo.timeout = timeout.total!"msecs";
    nfo.toTime = currentMSecs()+nfo.timeout;
  } else {
    // no timeout
    nfo.timeout = -1;
    nfo.toTime = -1;
  }
}


/**
 * add fd to event loop. can be called from event loop callbacks.
 *
 * Params:
 *  fd = file descriptor (fd); must not be negative
 *  flg = wanted events
 *  timeout = timeout interval if Timeout flag is set
 *  eventCB = event callback
 *
 * Returns:
 *  nothing
 *
 * Throws:
 *  Exception if fd is already in list
 */
public void addFD (int fd, FDFlags flg, Duration timeout, void delegate (int fd, FDFlags flags) eventCB) @trusted {
  if ((flg&(FDFlags.CanRead|FDFlags.CanWrite|FDFlags.Timeout)) == 0) throw new Exception("invalid flags");
  if (fd < 0 || fd == csigfd) throw new Exception("invalid fd");
  auto fi = fd in fdset;
  if (fi !is null) throw new Exception("duplicate fd");
  FDInfo nfo;
  nfo.fd = fd;
  nfo.onEvent = eventCB;
  nfo.changeCount = curChangeCount;
  ushort events = 0;
  if (flg&FDFlags.CanRead) events |= POLLIN;
  if (flg&FDFlags.CanWrite) events |= POLLOUT;
  nfo.events = events;
  fixTimeout(nfo, flg, timeout);
  if (events == 0 && nfo.timeout < 0) throw new Exception("invalid flags");
  uint idx = uint.max;
  foreach (auto i; 1..pfdUsed) if (pfds[i].fd < 0) { idx = i; break; }
  if (idx == uint.max) {
    if (pfdUsed >= pfds.length) pfds.length = pfds.length+32;
    idx = pfdUsed++;
  }
  nfo.pfdIndex = idx;
  pfds[idx].fd = fd;
  pfds[idx].events = nfo.events;
  pfds[idx].revents = 0;
  fdset[fd] = nfo;
}


/**
 * add fd to event loop. can be called from event loop callbacks.
 *
 * Params:
 *  fd = file descriptor (fd); must not be negative
 *  flg = wanted events
 *  eventCB = event callback
 *
 * Returns:
 *  nothing
 *
 * Throws:
 *  Exception if fd is already in list
 */
public void addFD (int fd, FDFlags flg, void delegate (int fd, FDFlags flags) eventCB) @trusted {
  flg &= ~FDFlags.Timeout;
  if ((flg&(FDFlags.CanRead|FDFlags.CanWrite|FDFlags.Timeout)) == 0) throw new Exception("invalid flags");
  if (fd < 0 || fd == csigfd) throw new Exception("invalid fd");
  auto fi = fd in fdset;
  if (fi !is null) throw new Exception("duplicate fd");
  FDInfo nfo;
  nfo.fd = fd;
  nfo.onEvent = eventCB;
  nfo.changeCount = curChangeCount;
  ushort events = 0;
  if (flg&FDFlags.CanRead) events |= POLLIN;
  if (flg&FDFlags.CanWrite) events |= POLLOUT;
  nfo.events = events;
  fixTimeout(nfo, flg, Duration.zero);
  if (events == 0 && nfo.timeout < 0) throw new Exception("invalid flags");
  uint idx = uint.max;
  foreach (auto i; 1..pfdUsed) if (pfds[i].fd < 0) { idx = i; break; }
  if (idx == uint.max) {
    if (pfdUsed >= pfds.length) pfds.length = pfds.length+32;
    idx = pfdUsed++;
  }
  nfo.pfdIndex = idx;
  pfds[idx].fd = fd;
  pfds[idx].events = nfo.events;
  pfds[idx].revents = 0;
  fdset[fd] = nfo;
  version(unittest) dumpFDs();
}


version(unittest)
void dumpFDs () {
  import std.stdio;
  writefln("=== used pfds: %s ===", pfdUsed);
  foreach (auto idx; 0..pfdUsed) {
    if (pfds[idx].fd < 0) continue;
    auto nfo = pfds[idx].fd in fdset;
    if (nfo is null) {
      writefln("idx=%s; fd=%s; events=0x%02x; revents=0x%02x", idx, pfds[idx].fd, pfds[idx].events, pfds[idx].revents);
    } else {
      writefln("idx=%s; fd=%s; events=0x%02x; revents=0x%02x; ev=0x%02x", idx, pfds[idx].fd, pfds[idx].events, pfds[idx].revents, nfo.events);
    }
  }
  writeln("=============================");
}


/**
 * set fd flags.
 *
 * Params:
 *  fd = file descriptor (fd); must not be negative
 *  flg = wanted events
 *  timeout = timeout interval if Timeout flag is set
 *
 * Returns:
 *  nothing
 *
 * Throws:
 *  Exception if fd is not in list
 */
public void setFDFlags (int fd, FDFlags flg, Duration timeout) @trusted {
  if ((flg&(FDFlags.CanRead|FDFlags.CanWrite|FDFlags.Timeout)) == 0) throw new Exception("invalid flags");
  if (fd < 0 || fd == csigfd) throw new Exception("invalid fd");
  auto fi = fd in fdset;
  if (fi is null) throw new Exception("unknown fd");
  ushort events = 0;
  if (flg&FDFlags.CanRead) events |= POLLIN;
  if (flg&FDFlags.CanWrite) events |= POLLOUT;
  fi.events = events;
  fixTimeout(*fi, flg, timeout);
  if (events == 0 && fi.timeout < 0) {
    // remove invalid fd
    removeFD(fd);
    throw new Exception("invalid flags");
  }
  pfds[fi.pfdIndex].events = fi.events;
  fi.changeCount = curChangeCount;
}


/**
 * set fd callback.
 *
 * Params:
 *  fd = file descriptor (fd); must not be negative
 *  eventCB = event callback
 *
 * Returns:
 *  nothing
 *
 * Throws:
 *  Exception if fd is not in list
 */
public void setFDCallback (int fd, void delegate (int fd, FDFlags flags) eventCB) @trusted {
  if (fd < 0 || fd == csigfd) throw new Exception("invalid fd");
  auto fi = fd in fdset;
  if (fi is null) throw new Exception("unknown fd");
  fi.onEvent = eventCB;
  fi.changeCount = curChangeCount;
}


/**
 * remove fd from event loop. can be called from event loop callbacks.
 *
 * Params:
 *  fd = file descriptor (fd); must not be negative
 *
 * Returns:
 *  true if fd was removed
 */
public bool removeFD (int fd) @trusted {
  if (fd < 0 || fd == csigfd) return false;
  auto fi = fd in fdset;
  if (fi !is null) {
    pfds[fi.pfdIndex].fd = -1; // mark as free
    while (pfdUsed > 0 && pfds[pfdUsed-1].fd < 0) --pfdUsed;
    fdset.remove(fd);
    return true;
  }
  return false;
}


/**
 * is fd in list?
 *
 * Params:
 *  fd = file descriptor (fd); must not be negative
 *
 * Returns:
 *  true if fd is in list
 */
public bool hasFD (int fd) @trusted nothrow {
  if (fd < 0 || fd == csigfd) return false;
  auto fi = fd in fdset;
  return (fi !is null);
}


// ////////////////////////////////////////////////////////////////////////// //
// return next poll timeout in milliseconds
// shots timers that needs to be shot
int processAll () /*@trusted nothrow*/ {
  auto curTime = currentMSecs();
  long tout = long.max;

  if (++curChangeCount == 0) {
    // wrapped, fix cc
    curChangeCount = 1;
    try { // for GDC
      foreach (ref fi; fdset.byValue) fi.changeCount = (fi.changeCount == ulong.max ? 1 : 0);
      foreach (ref tm; timers) if (tm.id > 0) tm.changeCount = (tm.changeCount == ulong.max ? 1 : 0);
    } catch (Exception) {}
  }

  // process and shot timers
  if (timersUsed > 0) {
    foreach (auto idx; 0..timersUsed) {
      if (timers[idx].id == 0) continue;
      // skip just added
      if (timers[idx].changeCount < curChangeCount) {
        if (timers[idx].shotTime <= curTime) {
          // shot it!
          auto tm = timers[idx];
          if (tm.interval < 0) {
            timers[idx].id = 0;
            timerId2Idx.remove(tm.id);
          }
          try { if (tm.onTimer !is null) tm.onTimer(tm.id); } catch (Exception) {}
          if (tm.id !in timerId2Idx) continue; // removed
          if (tm.id == timers[idx].id) {
            // try to keep the same interval
            while (timers[idx].shotTime <= curTime) timers[idx].shotTime += timers[idx].interval;
          }
        }
      }
      if (timers[idx].id != 0 && timers[idx].shotTime < tout) tout = timers[idx].shotTime;
    }
    while (timersUsed > 0 && timers[timersUsed-1].id == 0) --timersUsed;
  }

  version(unittest) dumpFDs();
  // process and shot fds
  auto end = pfdUsed;
  foreach (immutable uint idx; 1..pfdUsed) {
    if (pfds[idx].fd < 0) continue; // nothing to do
    FDFlags flg = FDFlags.None;
    auto rev = pfds[idx].revents;
    pfds[idx].revents = 0;
    if (rev&(/*POLLRDHUP|*/POLLERR|POLLHUP|POLLNVAL)) {
      flg = FDFlags.Error;
    } else if (rev&(POLLIN|POLLOUT)) {
      if (rev&POLLIN) flg |= FDFlags.CanRead;
      if (rev&POLLOUT) flg |= FDFlags.CanWrite;
    }
    // check timeout if necessary
    auto nfo = pfds[idx].fd in fdset;
    if (nfo is null) assert(0);
    if (nfo.timeout >= 0 && nfo.toTime <= curTime) flg |= FDFlags.Timeout;
    //{ import std.stdio; writefln("idx=%s; flg=0x%02x; cc=%s; ccc=%s; evs=0x%04x", idx, flg, nfo.changeCount, curChangeCount, rev); }
    if (flg == FDFlags.None) continue; // nothing to do with this one
    // skip just added
    if (nfo.changeCount < curChangeCount) {
      auto fd = nfo.fd;
      auto ev = nfo.onEvent;
      // autoremove on error
      if (flg&FDFlags.Error) removeFD(fd);
      // shot it
      if (ev !is null) try ev(fd, flg); catch (Exception) {}
    }
    if (pfds[idx].fd < 0) continue; // removed
    // nfo address can change, so refresh it
    nfo = pfds[idx].fd in fdset;
    if (nfo is null) continue;
    // fix timeout
    if (nfo.timeout >= 0) {
      if (nfo.timeout > 0) {
        while (nfo.toTime <= curTime) nfo.toTime += nfo.timeout;
      } else {
        nfo.toTime = curTime;
      }
      if (nfo.toTime < tout) tout = nfo.toTime;
    }
  }
  foreach (auto idx; end..pfdUsed) pfds[idx].revents = 0;
  while (pfdUsed > 0 && pfds[pfdUsed-1].fd < 0) --pfdUsed;

  if (tout != tout.max) {
    curTime = currentMSecs();
    return (tout <= curTime ? 0 : cast(int)(tout-curTime));
  }
  return -1; // infinite
}


// ////////////////////////////////////////////////////////////////////////// //
public __gshared void delegate () onSizeChanged;


// ////////////////////////////////////////////////////////////////////////// //
public void eventLoop () {
  import core.stdc.signal : SIGINT;
  import core.sys.linux.sys.signalfd : signalfd_siginfo;

  installSignalHandlers();
  pfds[0].fd = csigfd;
  pfds[0].events = POLLIN;

  scope(exit) doQuit = false;

  // loop
  while (!doQuit && !doGlobalQuit) {
    //foreach (auto idx; 0..pfdUsed) pfds[idx].revents = 0;
    auto tomsec = processAll();
    if (doQuit || doGlobalQuit) break;
    //{ import std.stdio; writeln("tomsec=", tomsec); }
    auto res = poll(pfds.ptr, pfdUsed, tomsec);
    if (res < 0) break; // some error occured, shit
    if (res == 0) continue; // timeout, do nothing
    version(unittest) dumpFDs();
    if (pfds[0].revents&POLLIN) {
      // signal arrived
      signalfd_siginfo si;
      bool wschanged = false;
      {
        import core.sys.posix.unistd : read;
        while (read(cast(int)csigfd, &si, si.sizeof) > 0) {
          if (si.ssi_signo == SIGWINCH) {
            wschanged = true;
          } else if (si.ssi_signo == SIGINT) {
            doQuit = true;
          } else {
            doGlobalQuit = true;
          }
        }
        if (wschanged && onSizeChanged !is null) {
          try onSizeChanged(); catch (Exception) {}
        }
        if (doGlobalQuit || doQuit) break; // just exit
      }
    }
  }
}


/*
unittest {
  import std.stdio;
  writeln("started...");
  addTimer(1500.msecs, (id) { writeln("*** timer ***"); } );
  eventLoop();
  writeln("done...");
}
*/


unittest {
  import core.sys.posix.unistd : STDIN_FILENO;
  import iv.rawtty;
  import std.stdio;
  writeln("started...");

  auto oldMode = ttySetRaw();
  if (oldMode == TTYMode.BAD) throw new Exception("not a tty");
  scope(exit) ttySetMode(oldMode);

  int count = 3;

  addTimer(1500.msecs, (id) {
    writeln("*** timer ***");
    if (--count <= 0) sendQuitSignal();
  } );

  removeFD(STDIN_FILENO);
  addFD(STDIN_FILENO, FDFlags.CanRead, (int fd, FDFlags flags) {
    // keyboard
    auto s = ttyReadKey();
    //if (s !is null && onKeyPressed !is null) onKeyPressed(s);
    writeln("+++ ", s, " +++");
  });
  eventLoop();

  writeln("done...");
}
