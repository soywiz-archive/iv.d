/* bot.c
** libstrophe XMPP client library -- basic usage example
**
** Copyright (C) 2005-2009 Collecta, Inc.
**
**  This software is provided AS-IS with no warranty, either express
**  or implied.
**
** This program is dual licensed under the MIT and GPLv3 licenses.
*/

/* simple bot example
**
** This example was provided by Matthew Wild <mwild1@gmail.com>.
**
** This bot responds to basic messages and iq version requests.
*/
module bot is aliced;

import iv.libstrophe;
import iv.vfs.io;


extern(C) int version_handler (xmpp_conn_t* conn, const(xmpp_stanza_t)* stanza, void* userdata) nothrow {
  try {
    //xmpp_stanza_t* reply, query, name, ver, text;
    //const(char)* ns;
    auto* ctx = cast(xmpp_ctx_t*)userdata;

    writefln("Received version request from %s", xmpp_stanza_get_from(stanza).xmpp_fromStrz);

    auto reply = xmpp_stanza_reply(stanza);
    xmpp_stanza_set_type(reply, "result");

    auto query = xmpp_stanza_new(ctx);
    xmpp_stanza_set_name(query, "query");
    if (auto ns = xmpp_stanza_get_ns(xmpp_stanza_get_children(stanza))) xmpp_stanza_set_ns(query, ns);

    auto name = xmpp_stanza_new(ctx);
    xmpp_stanza_set_name(name, "name");
    xmpp_stanza_add_child(query, name);
    xmpp_stanza_release(name);

    auto text = xmpp_stanza_new(ctx);
    xmpp_stanza_set_text(text, "libstrophe example bot");
    xmpp_stanza_add_child(name, text);
    xmpp_stanza_release(text);

    auto ver = xmpp_stanza_new(ctx);
    xmpp_stanza_set_name(ver, "version");
    xmpp_stanza_add_child(query, ver);
    xmpp_stanza_release(ver);

    text = xmpp_stanza_new(ctx);
    xmpp_stanza_set_text(text, "1.0");
    xmpp_stanza_add_child(ver, text);
    xmpp_stanza_release(text);

    xmpp_stanza_add_child(reply, query);
    xmpp_stanza_release(query);

    xmpp_send(conn, reply);
    xmpp_stanza_release(reply);
  } catch (Exception e) {
    assert(0, e.msg);
  }

  return 1;
}


extern(C) int message_handler (xmpp_conn_t* conn, const(xmpp_stanza_t)* stanza, void* userdata) nothrow {
  import std.algorithm : startsWith;
  import std.format : format;

  try {
    xmpp_ctx_t* ctx = cast(xmpp_ctx_t*)userdata;
    //xmpp_stanza_t* reply;
    //char* intext, replytext;

    if (xmpp_stanza_get_child_by_name(stanza, "body") is null) return 1;
    if (xmpp_stanza_get_type(stanza) !is null && xmpp_stanza_get_type(stanza).xmpp_fromStrz == "error") return 1;

    auto intext = xmpp_stanza_get_text(xmpp_stanza_get_child_by_name(stanza, "body"));
    scope(exit) xmpp_free(ctx, intext);
    auto tx = intext.xmpp_fromStrz;

    writefln("Incoming message from %s: %s", xmpp_stanza_get_from(stanza).xmpp_fromStrz, tx);

    if (tx == "quit") {
      xmpp_disconnect(conn);
    } else if (!tx.startsWith("Commands:")) {
      auto reply = xmpp_stanza_reply(stanza);
      if (xmpp_stanza_get_type(reply) is null) xmpp_stanza_set_type(reply, "chat");

      auto replytext = "%s to you too!\0".format(tx); // explicitly 0-terminated
      xmpp_message_set_body(reply, replytext.ptr);

      xmpp_send(conn, reply);
      xmpp_stanza_release(reply);
    }
  } catch (Exception e) {
    assert(0, e.msg);
  }

  return 1;
}


/* define a handler for connection events */
extern(C) void conn_handler (xmpp_conn_t* conn, xmpp_conn_event_t status, int error, xmpp_stream_error_t* stream_error, void* userdata) nothrow {
  try {
    auto* ctx = cast(xmpp_ctx_t*)userdata;
    if (status == XMPP_CONN_CONNECT) {
      stderr.writeln("DEBUG: connected");

      xmpp_handler_add(conn, &version_handler, "jabber:iq:version", "iq", null, ctx);
      xmpp_handler_add(conn, &message_handler, null, "message", null, ctx);

      /* Send initial <presence/> so that we appear online to contacts */
      auto pres = xmpp_presence_new(ctx);
      scope(exit) xmpp_stanza_release(pres);
      xmpp_send(conn, pres);
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
  xmpp_log_t* log;
  char* jid, pass, host;

  // take a jid and password on the command line
  if (args.length < 3 || args.length > 4) {
    stderr.writeln("Usage: bot <jid> <pass> [host]");
    return 1;
  }

  jid = args[1].xmpp_toStrz;
  pass = args[2].xmpp_toStrz;
  if (args.length > 3) host = args[3].xmpp_toStrz;

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

  /*
   * also you can disable TLS support or force legacy SSL
   * connection without STARTTLS
   *
   * see xmpp_conn_set_flags() or examples/basic.c
   */

  // setup authentication information
  xmpp_conn_set_jid(conn, jid);
  xmpp_conn_set_pass(conn, pass);

  // initiate connection
  xmpp_connect_client(conn, host, 0, &conn_handler, ctx);

  // enter the event loop -- our connect handler will trigger an exit
  xmpp_run(ctx);

  return 0;
}
