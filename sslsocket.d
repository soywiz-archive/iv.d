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
// This is CLIENT only at this point. Don't try to bind/accept with these.
module iv.sslsocket;

public import std.socket;
import iv.gnutls;


// ///////////////////////////////////////////////////////////////////////// //
shared static this () { gnutls_global_init(); }
shared static ~this () { gnutls_global_deinit(); }


// ///////////////////////////////////////////////////////////////////////// //
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
