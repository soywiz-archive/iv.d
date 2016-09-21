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
import iv.libstrophe;

import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;


extern(C) int version_handler (xmpp_conn_t* conn, const(xmpp_stanza_t)* stanza, void* userdata) nothrow {
  xmpp_stanza_t* reply, query, name, ver, text;
  const(char)* ns;
  xmpp_ctx_t* ctx = cast(xmpp_ctx_t*)userdata;

  printf("Received version request from %s\n", xmpp_stanza_get_from(stanza));

  reply = xmpp_stanza_reply(stanza);
  xmpp_stanza_set_type(reply, "result");

  query = xmpp_stanza_new(ctx);
  xmpp_stanza_set_name(query, "query");
  ns = xmpp_stanza_get_ns(xmpp_stanza_get_children(stanza));
  if (ns) {
    xmpp_stanza_set_ns(query, ns);
  }

  name = xmpp_stanza_new(ctx);
  xmpp_stanza_set_name(name, "name");
  xmpp_stanza_add_child(query, name);
  xmpp_stanza_release(name);

  text = xmpp_stanza_new(ctx);
  xmpp_stanza_set_text(text, "libstrophe example bot");
  xmpp_stanza_add_child(name, text);
  xmpp_stanza_release(text);

  ver = xmpp_stanza_new(ctx);
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

  return 1;
}


extern(C) int message_handler (xmpp_conn_t* conn, const(xmpp_stanza_t)* stanza, void* userdata) nothrow {
  xmpp_ctx_t* ctx = cast(xmpp_ctx_t*)userdata;
  xmpp_stanza_t* reply;
  char* intext, replytext;

  if (!xmpp_stanza_get_child_by_name(stanza, "body")) return 1;
  if (xmpp_stanza_get_type(stanza) !is null && strcmp(xmpp_stanza_get_type(stanza), "error") == 0) return 1;

  intext = xmpp_stanza_get_text(xmpp_stanza_get_child_by_name(stanza, "body"));

  printf("Incoming message from %s: %s\n", xmpp_stanza_get_from(stanza), intext);

  if (strncmp(intext, "Commands:", 9) != 0) {
    reply = xmpp_stanza_reply(stanza);
    if (xmpp_stanza_get_type(reply) is null) xmpp_stanza_set_type(reply, "chat");

    replytext = cast(char*)malloc(strlen(" to you too!")+strlen(intext)+1);
    strcpy(replytext, intext);
    strcat(replytext, " to you too!");
    xmpp_free(ctx, intext);
    xmpp_message_set_body(reply, replytext);

    xmpp_send(conn, reply);
    xmpp_stanza_release(reply);
  }

  free(replytext);

  return 1;
}


/* define a handler for connection events */
extern(C) void conn_handler (xmpp_conn_t* conn, xmpp_conn_event_t status, int error, xmpp_stream_error_t* stream_error, void* userdata) nothrow {
  xmpp_ctx_t* ctx = cast(xmpp_ctx_t*)userdata;

  if (status == XMPP_CONN_CONNECT) {
    xmpp_stanza_t* pres;
    fprintf(stderr, "DEBUG: connected\n");
    xmpp_handler_add(conn, &version_handler, "jabber:iq:version", "iq", null, ctx);
    xmpp_handler_add(conn, &message_handler, null, "message", null, ctx);

    /* Send initial <presence/> so that we appear online to contacts */
    pres = xmpp_presence_new(ctx);
    xmpp_send(conn, pres);
    xmpp_stanza_release(pres);
  } else {
    fprintf(stderr, "DEBUG: disconnected\n");
    xmpp_stop(ctx);
  }
}


int main (string[] args) {
  xmpp_ctx_t* ctx;
  xmpp_conn_t* conn;
  xmpp_log_t* log;
  char* jid, pass;

  /* take a jid and password on the command line */
  if (args.length != 3) {
    fprintf(stderr, "Usage: bot <jid> <pass>\n\n");
    return 1;
  }

  jid = args[1].xmpp_toStrz;
  pass = args[2].xmpp_toStrz;

  /* init library */
  xmpp_initialize();

  /* create a context */
  log = xmpp_get_default_logger(XMPP_LEVEL_DEBUG); /* pass null instead to silence output */
  ctx = xmpp_ctx_new(null, log);

  /* create a connection */
  conn = xmpp_conn_new(ctx);

  /*
   * also you can disable TLS support or force legacy SSL
   * connection without STARTTLS
   *
   * see xmpp_conn_set_flags() or examples/basic.c
   */

  /* setup authentication information */
  xmpp_conn_set_jid(conn, jid);
  xmpp_conn_set_pass(conn, pass);

  /* initiate connection */
  xmpp_connect_client(conn, null, 0, &conn_handler, ctx);

  /* enter the event loop -
     our connect handler will trigger an exit */
  xmpp_run(ctx);

  /* release our connection and context */
  xmpp_conn_release(conn);
  xmpp_ctx_free(ctx);

  /* final shutdown of the library */
  xmpp_shutdown();

  return 0;
}
