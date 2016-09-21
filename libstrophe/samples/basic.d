/* basic.c
** libstrophe XMPP client library -- basic usage example
**
** Copyright (C) 2005-2009 Collecta, Inc.
**
**  This software is provided AS-IS with no warranty, either express
**  or implied.
**
** This program is dual licensed under the MIT and GPLv3 licenses.
*/
import iv.libstrophe;

import iv.vfs.io;


// hardcoded TCP keepalive timeout and interval
enum KA_TIMEOUT = 60;
enum KA_INTERVAL = 1;


// define a handler for connection events
extern(C) void conn_handler (xmpp_conn_t* conn, xmpp_conn_event_t status, int error, xmpp_stream_error_t* stream_error, void* userdata) nothrow {
  try {
    xmpp_ctx_t* ctx = cast(xmpp_ctx_t*)userdata;
    int secured;
    if (status == XMPP_CONN_CONNECT) {
      stderr.writeln("DEBUG: connected");
      secured = xmpp_conn_is_secured(conn);
      stderr.writefln("DEBUG: connection is %ssecured.", (secured ? "" : "NOT "));
      xmpp_disconnect(conn);
    } else {
      stderr.writeln("DEBUG: disconnected");
      xmpp_stop(ctx);
    }
  } catch (Exception e) {}
}


int main (string[] args) {
  xmpp_ctx_t* ctx;
  xmpp_conn_t* conn;
  xmpp_log_t* log;
  char* jid, pass, host;
  xmpp_long flags = 0;
  int tcp_keepalive = 0;
  int i;

  // take a jid and password on the command line
  for (i = 1; i < args.length; ++i) {
         if (args[i] == "--disable-tls") flags |= XMPP_CONN_FLAG_DISABLE_TLS;
    else if (args[i] == "--mandatory-tls") flags |= XMPP_CONN_FLAG_MANDATORY_TLS;
    else if (args[i] == "--legacy-ssl") flags |= XMPP_CONN_FLAG_LEGACY_SSL;
    else if (args[i] == "--tcp-keepalive") tcp_keepalive = 1;
    else break;
  }
  if (args.length-i < 2 || args.length-i > 3) {
    stderr.writeln(
      "Usage: basic [options] <jid> <pass> [<host>]\n\n",
      "Options:\n",
      "  --disable-tls        Disable TLS.\n",
      "  --mandatory-tls      Deny plaintext connection.\n",
      "  --legacy-ssl         Use old style SSL.\n",
      "  --tcp-keepalive      Configure TCP keepalive.\n\n",
      "Note: --disable-tls conflicts with --mandatory-tls or --legacy-ssl");
    return 1;
  }


  jid = args[i].xmpp_toStrz;
  pass = args[i+1].xmpp_toStrz;
  if (i+2 < args.length) host = args[i+2].xmpp_toStrz;

  /*
   * Note, this example doesn't handle errors. Applications should check
   * return values of non-void functions.
   */

  // init library
  xmpp_initialize();
  scope(exit) xmpp_shutdown(); // final shutdown of the library

  // create a context
  log = xmpp_get_default_logger(XMPP_LEVEL_DEBUG); // pass null instead to silence output
  ctx = xmpp_ctx_new(null, log);
  scope(exit) xmpp_ctx_free(ctx);

  // create a connection
  conn = xmpp_conn_new(ctx);
  scope(exit) xmpp_conn_release(conn);

  // configure connection properties (optional)
  xmpp_conn_set_flags(conn, flags);
  // configure TCP keepalive (optional)
  if (tcp_keepalive) xmpp_conn_set_keepalive(conn, KA_TIMEOUT, KA_INTERVAL);

  // setup authentication information
  xmpp_conn_set_jid(conn, jid);
  xmpp_conn_set_pass(conn, pass);

  // initiate connection
  xmpp_connect_client(conn, host, 0, &conn_handler, ctx);

  // enter the event loop -- our connect handler will trigger an exit
  xmpp_run(ctx);

  return 0;
}
