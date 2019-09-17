/* Written by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * Understanding is not required. Only obedience.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 3 of the License ONLY.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */
module iv.lockfile /*is aliced*/;

import iv.alice;


// ////////////////////////////////////////////////////////////////////////// //
private struct LockFileImpl {
private:
  uint rc;
  char[] fname; // malloced, 0-terminated (but 0 is not in slice)
  int fd;
  bool locked;

public nothrow @nogc:
  void kill () {
    import core.stdc.stdlib : free;
    import core.sys.posix.unistd : getpid, close;
    assert(fd >= 0);
    bool dorm = false;
    if (locked) {
      import core.sys.posix.fcntl;
      flock lk;
      lk.l_type = F_UNLCK;
      lk.l_whence = 0/*SEEK_SET*/;
      lk.l_start = 0;
      lk.l_len = 0;
      lk.l_pid = getpid();
      fcntl(fd, F_SETLK, &lk);
      locked = false;
      dorm = true;
    }
    close(fd);
    fd = -1;
    if (dorm) {
      import core.stdc.stdio : remove;
      remove(fname.ptr);
    }
    free(fname.ptr);
    fname = null;
  }

  // this will return `false` for already locked file!
  bool tryLock () {
    import core.sys.posix.fcntl;
    import core.sys.posix.unistd : getpid;
    assert(fd >= 0);
    if (locked) return false;
    flock lk;
    lk.l_type = F_WRLCK;
    lk.l_whence = 0/*SEEK_SET*/;
    lk.l_start = 0;
    lk.l_len = 0;
    lk.l_pid = getpid();
    if (fcntl(fd, F_SETLK/*W*/, &lk) == 0) locked = true;
    return locked;
  }

static:
  usize create (const(char)[] afname) {
    import core.sys.posix.fcntl /*: open*/;
    import core.sys.posix.unistd : close;
    import core.sys.posix.stdlib : malloc, free;
    if (afname.length == 0) return 0;
    auto namep = cast(char*)malloc(afname.length+1);
    if (namep is null) return 0;
    namep[0..afname.length+1] = 0;
    namep[0..afname.length] = afname[];
    auto xfd = open(namep, O_RDWR|O_CREAT/*|O_CLOEXEC*/, 0x1b6/*0o666*/);
    if (xfd < 0) { free(namep); return 0; }
    auto fimp = cast(ubyte*)malloc(LockFileImpl.sizeof);
    if (fimp is null) { close(xfd); free(namep); return 0; }
    fimp[0..LockFileImpl.sizeof] = 0;
    auto res = cast(LockFileImpl*)fimp;
    res.fname = namep[0..afname.length];
    res.fd = xfd;
    res.rc = 1;
    return cast(usize)fimp;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
public struct LockFile {
private:
  usize lci;

nothrow @trusted @nogc:
  void decref () {
    if (lci) {
      auto lcp = cast(LockFileImpl*)lci;
      if (--lcp.rc == 0) lcp.kill;
      lci = 0;
    }
  }

public:
  this (const(char)[] fname) { lci = LockFileImpl.create(fname); }
  ~this () { pragma(inline, true); if (lci) decref(); }
  this (this) { pragma(inline, true); if (lci) { ++(cast(LockFileImpl*)lci).rc; } }
  void opAssign (in LockFile fl) {
    if (fl.lci) ++(cast(LockFileImpl*)fl.lci).rc;
    decref();
    lci = fl.lci;
  }

  void close () { pragma(inline, true); if (lci != 0) decref(); }

  @property bool valid () const pure { pragma(inline, true); return (lci != 0); }
  @property bool locked () const pure { pragma(inline, true); return (lci != 0 ? (cast(LockFileImpl*)lci).locked : false); }

  // this will return `false` for already locked file!
  bool tryLock () { pragma(inline, true); return (lci == 0 ? false : (cast(LockFileImpl*)lci).tryLock); }
}


// ////////////////////////////////////////////////////////////////////////// //
/*
__gshared LockFile prjLockFile;
  prjLockFile = LockFile(pfn~".lock");
  if (!prjLockFile.tryLock) {
    prjLockFile.close();
    return false;
  }
*/
