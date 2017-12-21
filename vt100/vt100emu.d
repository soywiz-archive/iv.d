/* coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
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
module iv.vt100.vt100emu;
private:

import iv.strex;
import iv.utfutil;
import iv.x11;

import iv.vt100.scrbuf;
import iv.vt100.vt100buf;


// ////////////////////////////////////////////////////////////////////////// //
// VT-100 emulator with Pty
public class VT100Emu : VT100Buf {
private:
  char* wrbuf;
  uint wrbufpos, wrbufsize;
  bool writeFucked;
  char[4096] rdbuf;
  int[2] readfds;
  int[2] writefds;

public:
  PtyInfo ptyi;

private:
  void wrbufFree () nothrow @trusted @nogc {
    if (wrbuf !is null) {
      import core.stdc.stdlib : free;
      free(wrbuf);
      wrbuf = null;
    }
    wrbufpos = wrbufsize = 0;
  }

  // ////////////////////////////////////////////////////////////////////// //
  public final @property bool canWriteData () nothrow @trusted @nogc {
    import core.sys.posix.sys.select;
    import core.sys.posix.sys.time : timeval;
    if (!ptyi.valid) return false;
    for (;;) {
      fd_set wrs;
      FD_ZERO(&wrs);
      FD_SET(ptyi.masterfd, &wrs);
      timeval tv;
      tv.tv_sec = 0;
      tv.tv_usec = 0;
      int sres = select(ptyi.masterfd+1, &wrs, null, null, &tv);
      if (sres < 0) {
        import core.stdc.errno;
        if (errno == EINTR) continue;
        return false;
      }
      return (sres != 0);
    }
  }

  final void writeBuf () nothrow @trusted @nogc {
    if (writeFucked || wrbufpos == 0 || !ptyi.valid) return;
    for (;;) {
      import core.sys.posix.unistd : write;
      auto wr = write(ptyi.masterfd, wrbuf, wrbufpos);
      if (wr < 0) {
        import core.stdc.errno;
        if (errno == EINTR) continue;
        writeFucked = true;
        return;
      }
      if (wr > 0) {
        if (wr == wrbufpos) {
          wrbufpos = 0;
        } else {
          import core.stdc.string : memmove;
          uint left = wrbufpos-cast(uint)wr;
          memmove(wrbuf, wrbuf+wr, left);
          wrbufpos = left;
        }
      }
      break;
    }
  }

  public final @property usize dataBufUsed () const pure nothrow @safe @nogc { pragma(inline, true); return wrbufpos; }
  public final @property bool wasWriteError () const pure nothrow @safe @nogc { pragma(inline, true); return writeFucked; }
  public final void resetWriteError () pure nothrow @safe @nogc { pragma(inline, true); writeFucked = false; }

  public override void putData (const(void)[] buf) nothrow @trusted @nogc {
    if (!ptyi.valid) return;
    if (wrbufpos && wrbufpos == wrbufsize && canWriteData) writeBuf();
    auto data = cast(const(ubyte)[])buf;
    while (data.length > 0) {
      import core.stdc.string : memcpy;
      if (wrbufpos == wrbufsize) {
        if (canWriteData) writeBuf();
        if (wrbufpos == wrbufsize) {
          import core.stdc.stdlib : realloc;
          if (wrbufsize+buf.length <= wrbufsize) assert(0, "fuck!");
          uint newsz = wrbufsize+data.length;
          if (newsz >= int.max/1024) {
            wrbufFree();
            writeFucked = true;
            return;
          }
          if (newsz&0x3ff) newsz = (newsz|0x3ff)+1;
          auto nbuf = cast(char*)realloc(wrbuf, newsz);
          if (nbuf is null) assert(0, "out of memory");
          wrbuf = nbuf;
          wrbufsize = newsz;
        }
      }
      uint chunk = cast(uint)(data.length > wrbufsize-wrbufpos ? wrbufsize-wrbufpos : data.length);
      memcpy(wrbuf+wrbufpos, data.ptr, chunk);
      wrbufpos += chunk;
      data = data[chunk..$];
    }
  }

  final @property bool canReadData () nothrow @trusted @nogc {
    import core.sys.posix.sys.select;
    import core.sys.posix.sys.time : timeval;
    if (!ptyi.valid) return false;
    for (;;) {
      fd_set rds;
      FD_ZERO(&rds);
      FD_SET(ptyi.masterfd, &rds);
      timeval tv;
      tv.tv_sec = 0;
      tv.tv_usec = 0;
      int sres = select(ptyi.masterfd+1, &rds, null, null, &tv);
      if (sres < 0) {
        import core.stdc.errno;
        if (errno == EINTR) continue;
        return false;
      }
      return (sres != 0);
    }
  }

  final void readData () nothrow {
    if (!ptyi.valid) return;
    int total = 0;
    while (canReadData) {
      import core.sys.posix.unistd : read;
      auto rd = read(ptyi.masterfd, rdbuf.ptr, rdbuf.length);
      if (rd < 0) {
        import core.stdc.errno;
        if (errno == EINTR) continue;
        return;
      }
      if (rd == 0) return;
      version(dump_output) {
        try {
          import std.stdio : File;
          auto fo = File("zdump.log", "a");
          fo.rawWrite(rdbuf[0..rd]);
        } catch (Exception) {}
      }
      putstr(rdbuf[0..rd]);
      total += cast(int)rd;
      if (total > 65535) break;
    }
  }

public:
  this (int aw, int ah, bool mIsUtfuck=true) nothrow @safe {
    super(aw, ah, mIsUtfuck);
  }

  ~this () { wrbufFree(); }

  // DO NOT CALL!
  override void intrClear () nothrow @trusted {
    super.intrClear();
    wrbufFree();
  }

  // for terminal emulator
  final @property int masterFD () nothrow @trusted @nogc { return ptyi.masterfd; }

  final const(int)[] getReadFDs () nothrow @trusted @nogc {
    if (!ptyi.valid) return null;
    readfds[0] = ptyi.masterfd;
    return readfds[0..1];
  }

  final const(int)[] getWriteFDs () nothrow @trusted @nogc {
    if (!ptyi.valid) return null;
    if (wasWriteError) {
      { import core.stdc.stdio; stderr.fprintf("WARNING! write error occured for masterfd %d!\n", ptyi.masterfd); }
      if (onBell !is null) onBell(this);
      resetWriteError();
    }
    if (!dataBufUsed) return null;
    writefds[0] = ptyi.masterfd;
    return writefds[0..1];
  }

  final void canWriteTo (int fd) {
    if (fd < 0 || fd != ptyi.masterfd) return;
    writeBuf();
  }

  final void canReadFrom (int fd) {
    if (fd < 0 || fd != ptyi.masterfd) return;
    readData();
  }

  final bool checkDeadChild (int pid, int exitcode) {
    if (!ptyi.valid) return false;
    if (ptyi.pid == pid) {
      ptyi.close();
      putstr("\r\n\x1b[0;33;1;41mDEAD CHILD");
      wrbufFree();
      return true;
    }
    return false;
  }

  override void sendTTYResizeSignal () {
    if (ptyi.valid) .sendTTYResizeSignal(ptyi.masterfd, mWidth, mHeight);
  }

  // ////////////////////////////////////////////////////////////////////// //
  final @property bool isPtyActive () const pure nothrow @safe @nogc { pragma(inline, true); return ptyi.valid; }

  final bool execPty (const(char[])[] args) nothrow @trusted @nogc {
    if (isPtyActive) return false;
    ptyi = executeInNewPty(args, mWidth, mHeight);
    return ptyi.valid;
  }

  final char[] getProcessName(bool fullname=false) (char[] obuf) nothrow @trusted @nogc {
    return .getProcessName(masterFD, obuf);
  }

  final char[] getProcessCwd (char[] obuf) nothrow @trusted @nogc {
    return .getProcessCwd(masterFD, obuf);
  }

  final char[] getFullProcessName (char[] obuf) nothrow @trusted @nogc {
    return .getFullProcessName(masterFD, obuf);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
private:
pragma(lib, "util");

import core.sys.posix.sys.ioctl : winsize;
import core.sys.posix.sys.types : pid_t;
import core.sys.posix.termios : termios;

extern(C) nothrow @nogc {
  int openpty (int* amaster, int* aslave, char* name, const(termios)* termp, const(winsize)* winp);
  pid_t forkpty (int* amaster, char* name, const(termios)* termp, const(winsize)* winp);
  int login_tty (int fd);

  // from unistd
  //enum O_CLOEXEC = 0o2000000; /* set close_on_exec */
  enum O_CLOEXEC = 524288; /* set close_on_exec */

  int pipe2 (int* pipefd, int flags);
}


// ////////////////////////////////////////////////////////////////////////// //
private void closeAllFDs () nothrow @trusted @nogc {
  // close FDs
  import core.sys.posix.sys.resource : getrlimit, rlimit, rlim_t, RLIMIT_NOFILE;
  import core.sys.posix.unistd : close;
  rlimit r = void;
  getrlimit(RLIMIT_NOFILE, &r);
  foreach (rlim_t idx; 3..r.rlim_cur) close(cast(int)idx);
}


void exec (const(char[])[] args) nothrow @trusted @nogc {
  import core.sys.posix.stdlib : getenv;
  static char[65536] cmdline = void;
  static const(char)*[32768] argv = void;
  usize argc = 0;
  usize cmpos = 0;
  usize stidx = 0;
  // if no args or first arg is empty, get default shell
  if (args.length == 0 || args[0].length == 0) {
    const(char)* envshell = getenv("SHELL");
    if (envshell is null || !envshell[0]) envshell = "/bin/sh";
    //setenv("TERM", "rxvt", 1); // should be done on program start
    argv[0] = envshell;
    if (args.length == 0) {
      // interactive shell
      argv[1] = "-i";
      argc = 2;
    } else {
      argc = 1;
    }
    ++stidx;
  }
  foreach (immutable idx; stidx..args.length) {
    import core.stdc.string : memcpy;
    if (args[idx].length >= cmdline.length-cmpos) break;
    if (argc+1 >= argv.length) break;
    argv[argc++] = cmdline.ptr+cmpos;
    if (args[idx].length) {
      memcpy(cmdline.ptr+cmpos, args[idx].ptr, args[idx].length);
      cmpos += args[idx].length;
    }
    cmdline[cmpos++] = 0;
  }
  argv[argc] = null;
  closeAllFDs();
  import core.sys.posix.unistd : execvp;
  execvp(argv[0], argv.ptr);
  {
    import core.stdc.stdlib : exit, EXIT_FAILURE;
    exit(EXIT_FAILURE);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
void sendTTYResizeSignal (int masterfd, int width, int height) nothrow @trusted @nogc {
  if (masterfd < 0) return;
  width = ScreenBuffer.max(1, ScreenBuffer.min(width, ushort.max-1));
  height = ScreenBuffer.max(1, ScreenBuffer.min(height, ushort.max-1));
  import core.sys.posix.sys.ioctl : winsize, ioctl, TIOCSWINSZ;
  winsize w = void;
  w.ws_row = cast(ushort)height;
  w.ws_col = cast(ushort)width;
  w.ws_xpixel = w.ws_ypixel = 0;
  if (ioctl(masterfd, TIOCSWINSZ, &w) < 0) {
    import core.stdc.errno;
    import core.stdc.stdio;
    import core.stdc.string;
    fprintf(stderr, "Warning: couldn't set window size: %s\n", strerror(errno));
  }
}


// ////////////////////////////////////////////////////////////////////////// //
struct PtyInfo {
  int masterfd = -1;
  int pid = -1;

  @property bool valid () const pure nothrow @safe @nogc { pragma(inline, true); return (masterfd >= 0 && pid >= 0); }

  void close () {
    if (masterfd >= 0) {
      import core.sys.posix.unistd : close;
      close(masterfd);
      masterfd = -1;
    }
    pid = -1;
  }
}


PtyInfo executeInNewPty (const(char[])[] args, int width, int height) nothrow @trusted @nogc {
  import core.sys.posix.stdlib : setenv;
  import core.sys.posix.sys.ioctl : winsize;
  PtyInfo ptyi;
  width = ScreenBuffer.max(1, ScreenBuffer.min(width, ushort.max-1));
  height = ScreenBuffer.max(1, ScreenBuffer.min(height, ushort.max-1));
  winsize w = void;
  w.ws_col = cast(ushort)width;
  w.ws_row = cast(ushort)height;
  w.ws_xpixel = w.ws_ypixel = 0;
  auto mPId = forkpty(&ptyi.masterfd, null, null, &w);
  // failed?
  if (mPId < 0) {
    if (ptyi.masterfd >= 0) {
      import core.sys.posix.unistd : close;
      close(ptyi.masterfd);
      ptyi.masterfd = -1;
    }
    ptyi.pid = -1;
    return ptyi;
  }
  // child?
  if (mPId == 0) {
    import core.sys.posix.unistd : setsid;
    setenv("TERM", "rxvt", 1);
    setsid(); // create a new process group
    exec(args);
    // will never return
    assert(0);
  }
  // master
  ptyi.pid = mPId;
  // no need to set terminal size here, as `forkpty()` did that for us
  return ptyi;
}


// ////////////////////////////////////////////////////////////////////////// //
char[] getProcessName(bool fullname=false) (int masterfd, char[] obuf) nothrow @trusted @nogc {
  import core.stdc.stdio : snprintf;
  import core.sys.posix.fcntl : open, O_RDONLY;
  import core.sys.posix.unistd : close, read, tcgetpgrp;
  import core.sys.posix.sys.types : pid_t;
  char[128] path = void;
  char[4096] res = void;
  //static char path[256], res[4097], *c;
  if (masterfd < 0 || obuf.length < 1) return null;
  pid_t pgrp = tcgetpgrp(masterfd);
  if (pgrp == -1) return null;
  snprintf(path.ptr, cast(uint)path.length, "/proc/%d/cmdline", pgrp);
  int fd = open(path.ptr, O_RDONLY);
  if (fd < 0) return null;
  auto rd = read(fd, res.ptr, res.length);
  close(fd);
  if (rd <= 0) return null;
  static if (fullname) {
    usize pos = 0;
    while (pos < rd && res[pos]) ++pos;
    auto sb = res[0..pos];
    //FIXME!
    while (sb.length > obuf.length) sb = sb[1..$];
    obuf[0..sb.length] = sb[];
    return obuf[0..sb.length];
  } else {
    usize pos = rd;
    while (pos > 0 && res[pos-1] != '/') --pos;
    if (pos >= rd) return null;
    if (rd-pos > obuf.length) pos = rd-obuf.length;
    obuf[0..rd-pos] = res[pos..rd];
    return obuf[0..rd-pos];
  }
}


char[] getFullProcessName (int masterfd, char[] obuf) nothrow @trusted @nogc {
  import core.stdc.stdio : snprintf;
  import core.sys.posix.fcntl : open, O_RDONLY;
  import core.sys.posix.unistd : close, read, tcgetpgrp, readlink;
  import core.sys.posix.sys.types : pid_t;
  char[128] path = void;
  char[4096] res = void;
  if (masterfd < 0 || obuf.length < 1) return null;
  pid_t pgrp = tcgetpgrp(masterfd);
  if (pgrp == -1) return null;
  snprintf(path.ptr, cast(uint)path.length, "/proc/%d/exe", pgrp);
  auto rd = readlink(path.ptr, res.ptr, res.length);
  if (rd <= 0) return null;
  usize pos = 0;
  while (pos < rd && res[pos]) ++pos;
  auto sb = res[0..pos];
  //FIXME!
  while (sb.length > obuf.length) sb = sb[1..$];
  obuf[0..sb.length] = sb[];
  return obuf[0..sb.length];
}


char[] getProcessCwd (int masterfd, char[] obuf) nothrow @trusted @nogc {
  import core.stdc.stdio : snprintf;
  import core.sys.posix.fcntl : open, O_RDONLY;
  import core.sys.posix.unistd : close, read, tcgetpgrp, readlink;
  import core.sys.posix.sys.types : pid_t;
  char[128] path = void;
  char[4096] res = void;
  if (masterfd < 0 || obuf.length < 1) return null;
  pid_t pgrp = tcgetpgrp(masterfd);
  if (pgrp == -1) return null;
  snprintf(path.ptr, cast(uint)path.length, "/proc/%d/cwd", pgrp);
  auto rd = readlink(path.ptr, res.ptr, res.length);
  if (rd <= 0) return null;
  usize pos = 0;
  while (pos < rd && res[pos]) ++pos;
  auto sb = res[0..pos];
  //FIXME!
  while (sb.length > obuf.length) sb = sb[1..$];
  obuf[0..sb.length] = sb[];
  return obuf[0..sb.length];
}
