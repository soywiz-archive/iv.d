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
// loosely based on opticron and Adam D. Ruppe work
module iv.sslsocket is aliced;

public import std.socket;
import iv.gnutls;


// ///////////////////////////////////////////////////////////////////////// //
shared static this () { gnutls_global_init(); }
shared static ~this () { gnutls_global_deinit(); }


// ///////////////////////////////////////////////////////////////////////// //
/// deprecated!
class SSLClientSocket : Socket {
  gnutls_certificate_credentials_t xcred;
  gnutls_session_t session;
  private bool sslInitialized;
  bool manualHandshake = false; // for non-blocking sockets this should be `true`

  // take care of pre-connection TLS stuff
  //FIXME: possible memory leak on exception? (sholdn't be, as `close()` will free the things)
  private void sslInit () {
    if (sslInitialized) return;
    sslInitialized = true;

    // x509 stuff
    gnutls_certificate_allocate_credentials(&xcred);

    // sets the trusted certificate authority file (no need for us, as we aren't checking any certificate)
    //gnutls_certificate_set_x509_trust_file(xcred, CAFILE, GNUTLS_X509_FMT_PEM);

    // initialize TLS session
    gnutls_init(&session, GNUTLS_CLIENT);

    // use default priorities
    const(char)* err;
    auto ret = gnutls_priority_set_direct(session, "PERFORMANCE", &err);
    if (ret < 0) {
      import std.string : fromStringz;
      import std.conv : to;
      if (ret == GNUTLS_E_INVALID_REQUEST) throw new Exception("Syntax error at: "~err.fromStringz.idup);
      throw new Exception("TLS Error: returned with "~ret.to!string);
    }

    // put the x509 credentials to the current session
    gnutls_credentials_set(session, GNUTLS_CRD_CERTIFICATE, xcred);
  }

  public void sslHandshake () {
    // lob the socket handle off to gnutls
    gnutls_transport_set_ptr(session, cast(gnutls_transport_ptr_t)handle);
    // perform the TLS handshake
    auto ret = gnutls_handshake(session);
    if (ret < 0) {
      import std.string : fromStringz;
      throw new Exception("Handshake failed: "~gnutls_strerror(ret).fromStringz.idup);
    }
  }

  override void connect (Address to) @trusted {
    super.connect(to);
    if (!manualHandshake) sslHandshake();
  }

  // close the encrypted connection
  override void close () @trusted {
    scope(exit) sslInitialized = false;
    if (sslInitialized) {
      //{ import core.stdc.stdio : printf; printf("deiniting\n"); }
      gnutls_bye(session, GNUTLS_SHUT_RDWR);
      gnutls_deinit(session);
      gnutls_certificate_free_credentials(xcred);
    }
    super.close();
  }

  override ptrdiff_t send (const(void)[] buf, SocketFlags flags) @trusted {
    return gnutls_record_send(session, buf.ptr, buf.length);
  }

  override ptrdiff_t send (const(void)[] buf) {
    import core.sys.posix.sys.socket;
    static if (is(typeof(MSG_NOSIGNAL))) {
      return send(buf, cast(SocketFlags)MSG_NOSIGNAL);
    } else {
      return send(buf, SocketFlags.NOSIGNAL);
    }
  }

  override ptrdiff_t receive (void[] buf, SocketFlags flags) @trusted {
    return gnutls_record_recv(session, buf.ptr, buf.length);
  }

  override ptrdiff_t receive (void[] buf) { return receive(buf, SocketFlags.NONE); }

  this (AddressFamily af, SocketType type=SocketType.STREAM) {
    sslInit();
    super(af, type);
  }

  this (socket_t sock, AddressFamily af) {
    sslInit();
    super(sock, af);
  }
}


// ///////////////////////////////////////////////////////////////////////// //
// this can be used as both client and server socket
// don't forget to set certificate file (and key file, if you have both) for server!
// `connect()` will do client mode, `accept()` will do server mode (and will return `SSLSocket` instance)
class SSLSocket : Socket {
  gnutls_certificate_credentials_t xcred;
  gnutls_session_t session;
  private bool sslInitialized = false;
  bool manualHandshake = false; // for non-blocking sockets this should be `true`
  private bool thisIsServer = false;
  // server
  private string certfilez; // "cert.pem"
  private string keyfilez; // "key.pem"

  // both key and cert can be in one file
  void setKeyCertFile (const(char)[] certname, const(char)[] keyname=null) {
    if (certname.length == 0) { certname = keyname; keyname = null; }
    if (certname.length == 0) {
      certfilez = keyfilez = "";
    } else {
      auto buf = new char[](certname.length+1);
      buf[] = 0;
      buf[0..certname.length] = certname;
      certfilez = cast(string)buf;
      if (keyname.length != 0) {
        buf = new char[](keyname.length+1);
        buf[] = 0;
        buf[0..keyname.length] = keyname;
      }
      keyfilez = cast(string)buf;
    }
  }

  // take care of pre-connection TLS stuff
  //FIXME: possible memory leak on exception? (sholdn't be, as `close()` will free the things)
  private void sslInit () {
    if (sslInitialized) return;
    sslInitialized = true;

    // x509 stuff
    gnutls_certificate_allocate_credentials(&xcred);

    // sets the trusted certificate authority file (no need for us, as we aren't checking any certificate)
    //gnutls_certificate_set_x509_trust_file(xcred, CAFILE, GNUTLS_X509_FMT_PEM);

    if (thisIsServer) {
      // server
      if (certfilez.length < 1) throw new SocketException("TLS Error: certificate file not set");
      if (keyfilez.length < 1) throw new SocketException("TLS Error: key file not set");
      auto res = gnutls_certificate_set_x509_key_file(xcred, certfilez.ptr, keyfilez.ptr, GNUTLS_X509_FMT_PEM);
      if (res < 0) {
        import std.conv : to;
        throw new SocketException("TLS Error: returned with "~res.to!string);
      }
      gnutls_init(&session, GNUTLS_SERVER);
      gnutls_certificate_server_set_request(session, GNUTLS_CERT_IGNORE);
      gnutls_handshake_set_timeout(session, /*GNUTLS_DEFAULT_HANDSHAKE_TIMEOUT*/2300);
    } else {
      // client
      // initialize TLS session
      gnutls_init(&session, GNUTLS_CLIENT);
    }

    // use default priorities
    const(char)* err;
    auto ret = gnutls_priority_set_direct(session, "PERFORMANCE", &err);
    if (ret < 0) {
      import std.string : fromStringz;
      import std.conv : to;
      if (ret == GNUTLS_E_INVALID_REQUEST) throw new SocketException("Syntax error at: "~err.fromStringz.idup);
      throw new SocketException("TLS Error: returned with "~ret.to!string);
    }

    // put the x509 credentials to the current session
    gnutls_credentials_set(session, GNUTLS_CRD_CERTIFICATE, xcred);
  }

  public void sslHandshake () {
    sslInit();
    // lob the socket handle off to gnutls
    gnutls_transport_set_ptr(session, cast(gnutls_transport_ptr_t)handle);
    // perform the TLS handshake
    auto ret = gnutls_handshake(session);
    if (ret < 0) {
      import std.string : fromStringz;
      throw new Exception("Handshake failed: "~gnutls_strerror(ret).fromStringz.idup);
    }
  }

  override @property void blocking (bool byes) @trusted {
    super.blocking(byes);
    manualHandshake = !byes;
  }

  override void connect (Address to) @trusted {
    if (sslInitialized && thisIsServer) throw new SocketException("wtf?!");
    thisIsServer = false;
    sslInit();
    super.connect(to);
    if (!manualHandshake) sslHandshake();
  }

  protected override Socket accepting () pure nothrow {
    return new SSLSocket();
  }

  override Socket accept () @trusted {
    auto sk = super.accept();
    if (auto ssk = cast(SSLSocket)sk) {
      ssk.keyfilez = keyfilez;
      ssk.certfilez = certfilez;
      ssk.manualHandshake = manualHandshake;
      ssk.thisIsServer = true;
      ssk.sslInit();
      if (!ssk.manualHandshake) ssk.sslHandshake();
    } else {
      throw new SocketAcceptException("failed to create ssl socket");
    }
    return sk;
  }

  // close the encrypted connection
  override void close () @trusted {
    scope(exit) sslInitialized = false;
    if (sslInitialized) {
      //{ import core.stdc.stdio : printf; printf("deiniting\n"); }
      gnutls_bye(session, GNUTLS_SHUT_RDWR);
      gnutls_deinit(session);
      gnutls_certificate_free_credentials(xcred);
    }
    super.close();
  }

  override ptrdiff_t send (const(void)[] buf, SocketFlags flags) @trusted {
    if (session is null || !sslInitialized) throw new SocketException("not initialized");
    return gnutls_record_send(session, buf.ptr, buf.length);
  }

  override ptrdiff_t send (const(void)[] buf) {
    import core.sys.posix.sys.socket;
    static if (is(typeof(MSG_NOSIGNAL))) {
      return send(buf, cast(SocketFlags)MSG_NOSIGNAL);
    } else {
      return send(buf, SocketFlags.NOSIGNAL);
    }
  }

  override ptrdiff_t receive (void[] buf, SocketFlags flags) @trusted {
    if (session is null || !sslInitialized) throw new SocketException("not initialized");
    return gnutls_record_recv(session, buf.ptr, buf.length);
  }

  override ptrdiff_t receive (void[] buf) { return receive(buf, SocketFlags.NONE); }

  private this () pure nothrow @safe {}

  this (AddressFamily af, SocketType type=SocketType.STREAM) {
    super(af, type);
  }

  this (socket_t sock, AddressFamily af) {
    super(sock, af);
  }
}
