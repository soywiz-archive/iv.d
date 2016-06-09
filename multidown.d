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
module iv.multidown /*is aliced*/;
private:

pragma(lib, "curl");
import std.concurrency;
import std.net.curl;

import iv.writer;
import iv.rawtty;
import iv.timer;

static if (!is(typeof(usize))) private alias usize = size_t;


// ////////////////////////////////////////////////////////////////////////// //
// pbar0: fast changing (current file download, for example)
// pbar1: slow changing (total number of files to download, for example)
struct PBar2 {
  immutable usize ttyWdt;

  string text;
  usize[2] total;
  usize[2] cur;
  usize[2] len; // for tty
  usize prc0;
  bool dirty;

  @disable this ();
  this (string atext, usize cur1, usize tot1) {
    import std.algorithm : min, max;
    ttyWdt = max(6, min(ttyWidth, 512));
    text = atext;
    if (text.length > ttyWdt+5) text = text[0..ttyWdt-5];
    total[0] = 0;
    total[1] = tot1;
    cur[0] = 0;
    cur[1] = cur1+1;
    len[] = 0;
    prc0 = 0;
    dirty = true;
    this[1] = cur1;
  }

  void setTotal0 (usize tot0) {
    if (total[0] != tot0) {
      dirty = true;
      total[0] = tot0;
      immutable c0 = cur[0];
      ++cur[0];
      this[0] = c0;
    }
  }

  void setTotal1 (usize tot1) {
    if (total[1] != tot1) {
      dirty = true;
      total[1] = tot1;
      immutable c0 = cur[1];
      ++cur[1];
      this[1] = c0;
    }
  }

  void opIndexAssign (usize acur, usize idx) {
    if (acur > total[idx]) acur = total[idx];
    if (cur[idx] == acur) return; // nothing to do
    cur[idx] = acur;
    if (total[idx] == 0) return; // total is unknown
    if (idx == 0) {
      // percents for first counter
      usize newprc = 100*cur[idx]/total[idx];
      if (newprc != prc0) {
        prc0 = newprc;
        dirty = true;
      }
    }
    // len
    usize newlen = ttyWdt*cur[idx]/total[idx];
    if (newlen != len[idx]) {
      len[idx] = newlen;
      dirty = true;
    }
  }

  void draw () nothrow @nogc {
    import std.algorithm : min;
    if (!dirty) return;
    dirty = false;
    char[1024] buf = ' ';
    buf[0..text.length] = text[];
    usize bufpos = text.length;
    // pad percents
    usize prc = prc0;
    foreach_reverse (immutable idx; 0..3) {
      buf[bufpos+idx] = '0'+prc%10;
      if ((prc /= 10) == 0) break;
    }
    buf[bufpos+3] = '%';
    const wrt = buf[0..ttyWdt];
    // first write [0] and [1] progress
    usize cpos = min(len[0], len[1]);
    // no cursor
    write("\x1b[?25l");
    // green
    write("\r\x1b[0;1;42m", wrt[0..cpos]);
    if (cpos < len[0]) {
      // haz more [0]
      // magenta
      write("\x1b[1;45m", wrt[cpos..len[0]]);
      cpos = len[0];
    } else if (cpos < len[1]) {
      // haz more [1]
      // brown
      write("\x1b[1;43m", wrt[cpos..len[1]]);
      cpos = len[1];
    }
    // what is left is emptiness
    write("\x1b[0m", wrt[cpos..$]);
    // and return cursor
    //write("\x1b[K\r\x1b[", text.length+4, "C");
  }
}


// ////////////////////////////////////////////////////////////////////////// //
// move cursor to tnum's thread info line
__gshared usize threadCount; // # of running threads
__gshared usize prevThreadCount; // # of running threads on previous call
__gshared usize curInfoLine = usize.max; // 0: bottom; 1: one before bottom; etc.


// WARNING! CALL MUST BE SYNCHRONIZED
void cursorToInfoLine (usize tnum) {
  if (curInfoLine == usize.max) {
    if (threadCount == 0) assert(0); // the thing that should not be
    curInfoLine = 0;
  }
  // move cursor to bottom
  if (curInfoLine) write("\x1b[", curInfoLine, "B");
  // add status lines if necessary
  while (prevThreadCount < threadCount) {
    // mark as idle
    write("\r\x1b[0;1;33mIDLE\x1b[0m\x1b[K\n");
    ++prevThreadCount;
  }
  // move cursor to required line from bottom
  if (tnum > 0) write("\x1b[", tnum, "A");
  curInfoLine = tnum;
}


void removeInfoLines () {
  if (curInfoLine != usize.max) {
    // move cursor to bottom
    if (curInfoLine) write("\x1b[", curInfoLine, "B");
    // erase info lines
    while (threadCount-- > 1) write("\r\x1b[0m\x1b[K\x1b[A");
    write("\r\x1b[0m\x1b[K\x1b[?25h");
  }
}


// ////////////////////////////////////////////////////////////////////////// //
import core.atomic;

// fill this with urls to download
public __gshared string[] urlList; // the following is protected by `synchronized`
shared usize urlDone;

// this will be called to get path from url
public __gshared string delegate (string url) url2path;

// this will be called when download is complete
// call is synchronized
// can be `null`
public __gshared void delegate (string url) urldone;


void downloadThread (usize tnum, Tid ownerTid) {
  bool done = false;
  while (!done) {
    // update status
    /*
    synchronized {
      cursorToInfoLine(tnum);
      write("\r\x1b[0;1;33mIDLE\x1b[0m\x1b[K");
    }
    */
    string url;
    usize utotal;
    receive(
      // usize: url index to download
      (usize unum) {
        synchronized {
          if (unum >= urlList.length) {
            // url index too big? done with it all
            done = true;
            cursorToInfoLine(tnum);
            write("\r\x1b[0;1;31mDONE\x1b[0m\x1b[K");
          } else {
            url = urlList[unum];
            utotal = urlList.length;
          }
        }
      },
    );
    // download file
    if (!done) {
      import std.exception : collectException;
      import std.file : mkdirRecurse;
      import std.path : baseName, dirName;
      string line, upath, ddir, dname;
      upath = url2path(url);
      if (upath.length == 0) {
        static if (is(typeof(() { import core.exception : ExitError; }()))) {
          import core.exception : ExitError;
          throw new ExitError();
        } else {
          assert(0);
        }
      }
      ddir = upath.dirName;
      dname = upath.baseName;
      {
        import std.conv : to;
        line ~= to!string(tnum)~": [";
        auto cs = to!string(atomicLoad(urlDone)+1);
        auto ts = to!string(utotal);
        foreach (immutable _; cs.length..ts.length) line ~= ' ';
        line ~= cs~"/"~ts~"] "~upath~" ... ";
      }
      while (!done) {
        try {
          auto pbar = PBar2(line, atomicLoad(urlDone), utotal);
          //pbar.draw();
          //write("\r", line, "  0%");
          // down it
          int oldPrc = -1, oldPos = -1;
          auto conn = HTTP();
          conn.setUserAgent("Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.1; Trident/6.0)");
          conn.onProgress = (scope usize dlTotal, scope usize dlNow, scope usize ulTotal, scope usize ulNow) {
            if (dlTotal > 0) {
              pbar.setTotal0(dlTotal);
              pbar[0] = dlNow;
            }
            synchronized {
              pbar[1] = atomicLoad(urlDone);
              cursorToInfoLine(tnum);
              pbar.draw();
            }
            return 0;
          };
          collectException(mkdirRecurse(ddir));
          string fname = ddir~"/"~dname;
          int retries = 8;
          for (;;) {
            bool ok = false;
            try {
              download(url, fname, conn);
              ok = true;
            } catch (Exception e) {
              ok = false;
            }
            if (ok) break;
            if (--retries <= 0) {
              import iv.writer;
              errwriteln("\n\n\n\n\x1b[0mFUCK!");
              static if (is(typeof(() { import core.exception : ExitError; }()))) {
                import core.exception : ExitError;
                throw new ExitError();
              } else {
                assert(0);
              }
            }
          }
          if (urldone !is null) {
            synchronized urldone(url);
          }
          done = true;
        } catch (Exception e) {
        }
      }
      done = false;
    }
    // signal parent that we are idle
    ownerTid.send(tnum);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
struct ThreadInfo {
  Tid tid;
  bool idle;
  usize uindex;
}

ThreadInfo[] threads;


void startThreads () {
  foreach (immutable usize idx; 0..threads.length) {
    synchronized ++threadCount;
    threads[idx].idle = true;
    threads[idx].tid = spawn(&downloadThread, idx, thisTid);
    threads[idx].tid.setMaxMailboxSize(2, OnCrowding.block);
  }
}


void stopThreads () {
  usize idleCount = 0;
  foreach (ref trd; threads) if (trd.idle) ++idleCount;
  while (idleCount < threads.length) {
    receive(
      (uint tnum) {
        if (!threads[tnum].idle) {
          threads[tnum].idle = true;
          ++idleCount;
        }
      }
    );
  }
  // send 'stop' signal to all threads
  foreach (ref trd; threads) {
    trd.idle = false;
    trd.tid.send(usize.max); // 'stop' signal
  }
  // wait for completion
  idleCount = 0;
  while (idleCount < threads.length) {
    receive(
      (uint tnum) {
        if (!threads[tnum].idle) {
          threads[tnum].idle = true;
          ++idleCount;
        }
      }
    );
  }
  threads = null;
}


// ////////////////////////////////////////////////////////////////////////// //
shared bool ctrlC = false;

extern(C) void sigtermh (int snum) nothrow @nogc {
  atomicStore(ctrlC, true);
}


// ////////////////////////////////////////////////////////////////////////// //
// pass number of threads
// fill `urlList` first!
// WARNING! DON'T CALL THIS TWICE!
public string downloadAll (uint tcount=4) {
  if (tcount < 1 || tcount > 64) assert(0);
  if (urlList.length == 0) return "nothing to do";
  { import core.memory : GC; GC.collect(); }
  import core.stdc.signal;
  auto oldh = signal(SIGINT, &sigtermh);
  scope(exit) signal(SIGINT, oldh);
  scope(exit) { import iv.writer; write("\x1b[?25h"); }
  // do it!
  //auto oldTTYMode = ttySetRaw();
  //scope(exit) ttySetMode(oldTTYMode);
  threads = new ThreadInfo[](tcount);
  prevThreadCount = 1; // we already has one empty line
  startThreads();
  ulong toCollect = 0;
  auto timer = Timer(Timer.State.Running);
  atomicStore(urlDone, 0);
  while (atomicLoad(urlDone) < urlList.length) {
    // force periodical collect to keep CURL happy
    if (toCollect-- == 0) {
      import core.memory : GC;
      GC.collect();
      toCollect = 128;
    }
    if (atomicLoad(ctrlC)) break;
    // find idle thread and send it url index
    usize freeTNum;
    for (freeTNum = 0; freeTNum < threads.length; ++freeTNum) if (threads[freeTNum].idle) break;
    if (freeTNum == threads.length) {
      // no idle thread found, wait for completion message
      import core.time;
      for (;;) {
        bool got = receiveTimeout(500.msecs,
          (uint tnum) {
            threads[tnum].idle = true;
            freeTNum = tnum;
          }
        );
        if (got || atomicLoad(ctrlC)) break;
      }
      if (atomicLoad(ctrlC)) break;
    }
    usize uidx = atomicLoad(urlDone);
    atomicOp!"+="(urlDone, 1);
    with (threads[freeTNum]) {
      idle = false;
      uindex = uidx;
      tid.send(uidx);
    }
  }
  // all downloads sheduled; wait for completion
  stopThreads();
  timer.stop();
  removeInfoLines();
  { import iv.writer; write("\r\x1b[0m\x1b[K\x1b[?25h"); }
  {
    import std.string : format;
    return format("%s files downloaded; time: %s", atomicLoad(urlDone), timer.toString);
  }
}
