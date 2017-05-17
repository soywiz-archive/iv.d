/* roster.c
** libstrophe XMPP client library -- handler example
**
** Copyright (C) 2005-2009 Collecta, Inc.
**
**  This software is provided AS-IS with no warranty, either express
**  or implied.
**
** This program is dual licensed under the MIT and GPLv3 licenses.
*/

/* This example demonstrates basic handler functions by printing out
** the user's roster.
*/
module roster /*is aliced*/;

import iv.alice;
import iv.libstrophe;
import iv.vfs.io;


extern(C) int handle_reply (xmpp_conn_t* conn, const(xmpp_stanza_t)* stanza, void* userdata) nothrow {
  try {
    auto type = xmpp_stanza_get_type(stanza).xmpp_fromStrz;
    if (type == "error") {
      stderr.writeln("ERROR: query failed");
    } else {
      auto query = xmpp_stanza_get_child_by_name(stanza, "query");
      writeln("Roster:");
      for (auto item = xmpp_stanza_get_children(query); item !is null; item = xmpp_stanza_get_next(item)) {
        if (auto namez = xmpp_stanza_get_attribute(item, "name")) {
          auto name = namez.xmpp_fromStrz;
          writefln("  name:%s (jid:%s) subscription:%s", name, xmpp_stanza_get_attribute(item, "jid").xmpp_fromStrz, xmpp_stanza_get_attribute(item, "subscription").xmpp_fromStrz);
        } else {
          writefln("    jid:%s subscription:%s", xmpp_stanza_get_attribute(item, "jid").xmpp_fromStrz, xmpp_stanza_get_attribute(item, "subscription").xmpp_fromStrz);
        }
      }
      writeln("END OF LIST");
    }
    // disconnect
    xmpp_disconnect(conn);
  } catch (Exception e) {
    assert(0, e.msg);
  }
  return 0;
}


extern(C) void conn_handler (xmpp_conn_t* conn, xmpp_conn_event_t status, int error, xmpp_stream_error_t* stream_error, void* userdata) nothrow {
  try {
    xmpp_ctx_t* ctx = cast(xmpp_ctx_t *)userdata;
    if (status == XMPP_CONN_CONNECT) {
      stderr.writeln("DEBUG: connected");

      // create iq stanza for request
      auto iq = xmpp_stanza_new(ctx);
      xmpp_stanza_set_name(iq, "iq");
      xmpp_stanza_set_type(iq, "get");
      xmpp_stanza_set_id(iq, "roster1");

      auto query = xmpp_stanza_new(ctx);
      xmpp_stanza_set_name(query, "query");
      xmpp_stanza_set_ns(query, XMPP_NS_ROSTER);

      xmpp_stanza_add_child(iq, query);

      // we can release the stanza since it belongs to iq now
      xmpp_stanza_release(query);

      // set up reply handler
      xmpp_id_handler_add(conn, &handle_reply, "roster1", ctx);

      // send out the stanza
      xmpp_send(conn, iq);

      // release the stanza
      xmpp_stanza_release(iq);
    } else {
      stderr.writeln("DEBUG: disconnected");
      xmpp_stop(ctx);
    }
  } catch (Exception e) {
    assert(0, e.msg);
  }
}


int main (string[] args) {
  xmpp_ctx_t* ctx;
  xmpp_conn_t* conn;

  if (args.length != 3) {
    stderr.writeln("Usage: roster <jid> <pass>");
    return 1;
  }

  // initialize lib
  xmpp_initialize();
  scope(exit) xmpp_shutdown(); // shutdown lib

  // create a context
  ctx = xmpp_ctx_new(null, null);
  scope(exit) xmpp_ctx_free(ctx);

  // create a connection
  conn = xmpp_conn_new(ctx);
  scope(exit) xmpp_conn_release(conn); // release our connection and context

  /*
   * also you can disable TLS support or force legacy SSL
   * connection without STARTTLS
   *
   * see xmpp_conn_set_flags() or examples/basic.c
   */

  // setup authentication information
  xmpp_conn_set_jid(conn, args[1].xmpp_toStrz);
  xmpp_conn_set_pass(conn, args[2].xmpp_toStrz);

  // initiate connection
  xmpp_connect_client(conn, null, 0, &conn_handler, ctx);

  // start the event loop
  xmpp_run(ctx);

  return 0;
}
