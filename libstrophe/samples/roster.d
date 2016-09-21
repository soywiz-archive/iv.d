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
import iv.libstrophe;

import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;


extern(C) int handle_reply (xmpp_conn_t* conn, const(xmpp_stanza_t)* stanza, void* userdata) nothrow {
  xmpp_stanza_t* query, item;
  const(char)* type, name;

  type = xmpp_stanza_get_type(stanza);
  if (strcmp(type, "error") == 0) {
    fprintf(stderr, "ERROR: query failed\n");
  } else {
    query = xmpp_stanza_get_child_by_name(stanza, "query");
    printf("Roster:\n");
    for (item = xmpp_stanza_get_children(query); item !is null; item = xmpp_stanza_get_next(item)) {
      if ((name = xmpp_stanza_get_attribute(item, "name")) !is null) {
        printf("\t %s (%s) sub=%s\n", name, xmpp_stanza_get_attribute(item, "jid"), xmpp_stanza_get_attribute(item, "subscription"));
      } else {
        printf("\t %s sub=%s\n", xmpp_stanza_get_attribute(item, "jid"), xmpp_stanza_get_attribute(item, "subscription"));
      }
    }
    printf("END OF LIST\n");
  }

  /* disconnect */
  xmpp_disconnect(conn);

  return 0;
}


extern(C) void conn_handler (xmpp_conn_t* conn, xmpp_conn_event_t status, int error, xmpp_stream_error_t* stream_error, void* userdata) nothrow {
  xmpp_ctx_t* ctx = cast(xmpp_ctx_t *)userdata;
  xmpp_stanza_t* iq, query;

  if (status == XMPP_CONN_CONNECT) {
    fprintf(stderr, "DEBUG: connected\n");

    /* create iq stanza for request */
    iq = xmpp_stanza_new(ctx);
    xmpp_stanza_set_name(iq, "iq");
    xmpp_stanza_set_type(iq, "get");
    xmpp_stanza_set_id(iq, "roster1");

    query = xmpp_stanza_new(ctx);
    xmpp_stanza_set_name(query, "query");
    xmpp_stanza_set_ns(query, XMPP_NS_ROSTER);

    xmpp_stanza_add_child(iq, query);

    /* we can release the stanza since it belongs to iq now */
    xmpp_stanza_release(query);

    /* set up reply handler */
    xmpp_id_handler_add(conn, &handle_reply, "roster1", ctx);

    /* send out the stanza */
    xmpp_send(conn, iq);

    /* release the stanza */
    xmpp_stanza_release(iq);
  } else {
    fprintf(stderr, "DEBUG: disconnected\n");
    xmpp_stop(ctx);
  }
}


int main (string[] args) {
  xmpp_ctx_t* ctx;
  xmpp_conn_t* conn;

  if (args.length != 3) {
    fprintf(stderr, "Usage: roster <jid> <pass>\n\n");
    return 1;
  }

  /* initialize lib */
  xmpp_initialize();

  /* create a context */
  ctx = xmpp_ctx_new(null, null);

  /* create a connection */
  conn = xmpp_conn_new(ctx);

  /*
   * also you can disable TLS support or force legacy SSL
   * connection without STARTTLS
   *
   * see xmpp_conn_set_flags() or examples/basic.c
   */

  /* setup authentication information */
  xmpp_conn_set_jid(conn, args[1].xmpp_toStrz);
  xmpp_conn_set_pass(conn, args[2].xmpp_toStrz);

  /* initiate connection */
  xmpp_connect_client(conn, null, 0, &conn_handler, ctx);

  /* start the event loop */
  xmpp_run(ctx);

  /* release our connection and context */
  xmpp_conn_release(conn);
  xmpp_ctx_free(ctx);

  /* shutdown lib */
  xmpp_shutdown();

  return 0;
}
