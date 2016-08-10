/* Written by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
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
module sockchan is aliced;

import iv.vfs;


// ////////////////////////////////////////////////////////////////////////// //
struct UDSocket {
private:
  static struct UDSData {
    uint rc;
    int fd;
    uint bytesSent;
    uint bytesReceived;
    bool didlisten;
    bool dontclose;
    @disable this (this);
  }

private:
  usize udsp;

  void decRef () nothrow @nogc {
    if (!udsp) return;
    auto uds = cast(UDSData*)udsp;
    if (--uds.rc == 0) {
      import core.stdc.stdlib : free;
      import core.sys.posix.unistd : close;
      if (!uds.dontclose) close(uds.fd);
      free(uds);
    }
    udsp = 0;
  }

public:
  this (this) nothrow @nogc { pragma(inline, true); if (udsp) ++(cast(UDSData*)udsp).rc; }
  ~this () nothrow @nogc { pragma(inline, true); if (udsp) close(); }

  void opAssign (UDSocket sk) {
    pragma(inline, true);
    if (sk.udsp) ++(cast(UDSData*)sk.udsp).rc;
    close();
    udsp = sk.udsp;
  }

  @property bool isOpen () const nothrow @trusted @nogc { pragma(inline, true); return (udsp != 0); }
  @property int fd () const nothrow @trusted @nogc { pragma(inline, true); return (udsp != 0 ? (cast(UDSData*)udsp).fd : -1); }

  void close () nothrow @nogc { pragma(inline, true); if (udsp) decRef(); }
  void create (const(char)[] name) { doCC!"server"(name); }
  void connect (const(char)[] name) { doCC!"client"(name); }

  @property uint bytesSent () const nothrow @trusted @nogc { pragma(inline, true); return (udsp != 0 ? (cast(UDSData*)udsp).bytesSent : 0); }
  @property uint bytesReceived () const nothrow @trusted @nogc { pragma(inline, true); return (udsp != 0 ? (cast(UDSData*)udsp).bytesReceived : 0); }

  @property void resetBytesSent () nothrow @trusted @nogc { pragma(inline, true); if (udsp != 0) (cast(UDSData*)udsp).bytesSent = 0; }
  @property void resetBytesReceived () nothrow @trusted @nogc { pragma(inline, true); if (udsp != 0) (cast(UDSData*)udsp).bytesReceived = 0; }

  void listen () {
    if (!udsp) throw new Exception("can't listen on closed socket");
    auto uds = cast(UDSData*)udsp;
    if (!uds.didlisten) {
      import core.sys.posix.sys.socket : listen;
      if (listen(uds.fd, 1) != 0) throw new Exception("listen failed");
      uds.didlisten = true;
    }
  }

  UDSocket accept () {
    listen();
    auto uds = cast(UDSData*)udsp;
    assert(uds.didlisten);
    import core.sys.posix.sys.socket : accept;
    int cfd = accept(uds.fd, null, null);
    if (cfd == -1) throw new Exception("accept failed");
    UDSocket res;
    res.assignFD(cfd);
    return res;
  }

  // detach fd
  int detach () {
    if (!udsp) throw new Exception("can't detach closed socket");
    auto uds = cast(UDSData*)udsp;
    int rfd = uds.fd;
    uds.dontclose = true;
    close();
    return rfd;
  }

  void[] rawRead (void[] buf) {
    import core.sys.posix.sys.socket : recv;
    if (!udsp) throw new Exception("can't read from closed socket");
    auto uds = cast(UDSData*)udsp;
    if (buf.length == 0) return buf[];
    auto rd = recv(uds.fd, buf.ptr, buf.length, 0);
    if (rd < 0) throw new Exception("socket read error");
    uds.bytesReceived += rd;
    return buf[0..rd];
  }

  void rawWrite (const(void)[] buf) {
    import core.sys.posix.sys.socket : send, MSG_NOSIGNAL;
    if (!udsp) throw new Exception("can't write to closed socket");
    auto uds = cast(UDSData*)udsp;
    auto dp = cast(const(ubyte)*)buf.ptr;
    auto left = buf.length;
    while (left > 0) {
      auto wr = send(uds.fd, dp, left, 0);
      if (wr <= 0) throw new Exception("socket write error");
      uds.bytesSent += wr;
      dp += wr;
      left -= wr;
    }
  }

private:
  void assignFD (int fd) {
    import core.stdc.stdlib : malloc;
    import core.stdc.string : memset;
    close();
    if (fd >= 0) {
      auto uds = cast(UDSData*)malloc(UDSData.sizeof);
      if (uds is null) {
        import core.sys.posix.unistd : close;
        close(fd);
        throw new Exception("out of memory"); // let's hope that we can do it
      }
      memset(uds, 0, (*uds).sizeof);
      uds.rc = 1;
      uds.fd = fd;
      udsp = cast(usize)uds;
    }
  }

  void doCC(string mode) (const(char)[] name) {
    static assert(mode == "client" || mode == "server", "invalid mode");
    import core.stdc.stdlib : malloc;
    import core.stdc.string : memset;
    close();
    int fd = makeUADS!mode(name);
    auto uds = cast(UDSData*)malloc(UDSData.sizeof);
    if (uds is null) {
      import core.sys.posix.unistd : close;
      close(fd);
      throw new Exception("out of memory"); // let's hope that we can do it
    }
    memset(uds, 0, (*uds).sizeof);
    uds.rc = 1;
    uds.fd = fd;
    udsp = cast(usize)uds;
  }

  static int makeUADS(string mode) (const(char)[] name) {
    static assert(mode == "client" || mode == "server", "invalid mode");
    import core.stdc.string : memset;
    import core.sys.posix.sys.socket;
    import core.sys.posix.sys.un : sockaddr_un;
    import core.sys.posix.unistd : close;
    // max name length is 108, so be safe here
    if (name.length == 0 || name.length > 100) throw new Exception("invalid name");
    sockaddr_un sun = void;
    memset(&sun, 0, sun.sizeof);
    sun.sun_family = AF_UNIX;
    // create domain socket without FS inode (first byte of name buffer should be zero)
    sun.sun_path[1..1+name.length] = cast(byte[])name[];
    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) throw new Exception("can't create unix domain socket");
    static if (mode == "server") {
      import core.sys.posix.sys.socket : bind;
      if (bind(fd, cast(sockaddr*)&sun, sun.sizeof) != 0) { close(fd); throw new Exception("can't bind unix domain socket"); }
    } else {
      import core.sys.posix.sys.socket : connect;
      if (connect(fd, cast(sockaddr*)&sun, sun.sizeof) != 0) {
        import core.stdc.errno;
        auto err = errno;
        close(fd);
        //{ import std.stdio; writeln("ERRNO: ", err); }
        throw new Exception("can't connect to unix domain socket");
      }
    }
    return fd;
  }
}
