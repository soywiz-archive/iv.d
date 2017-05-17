/* strophe.h
** strophe XMPP client library C API
**
** Copyright (C) 2005-2009 Collecta, Inc.
**
**  This software is provided AS-IS with no warranty, either express or
**  implied.
**
**  This software is dual licensed under the MIT and GPLv3 licenses.
*/
module iv.libstrophe.bindings /*is aliced*/;
pragma(lib, "strophe");
// consts are probably fucked all the way
import core.stdc.config : c_long, c_ulong;
import iv.alice;

alias xmpp_long = c_long;
alias xmpp_ulong = c_ulong;

extern(C) nothrow:

/** @file
 *  Strophe public C API definitions.
 */

/* namespace defines */
/** @def XMPP_NS_CLIENT
 *  Namespace definition for 'jabber:client'.
 */
enum XMPP_NS_CLIENT = "jabber:client";
/** @def XMPP_NS_COMPONENT
 *  Namespace definition for 'jabber:component:accept'.
 */
enum XMPP_NS_COMPONENT = "jabber:component:accept";
/** @def XMPP_NS_STREAMS
 *  Namespace definition for 'http://etherx.jabber.org/streams'.
 */
enum XMPP_NS_STREAMS = "http://etherx.jabber.org/streams";
/** @def XMPP_NS_STREAMS_IETF
 *  Namespace definition for 'urn:ietf:params:xml:ns:xmpp-streams'.
 */
enum XMPP_NS_STREAMS_IETF = "urn:ietf:params:xml:ns:xmpp-streams";
/** @def XMPP_NS_TLS
 *  Namespace definition for 'url:ietf:params:xml:ns:xmpp-tls'.
 */
enum XMPP_NS_TLS = "urn:ietf:params:xml:ns:xmpp-tls";
/** @def XMPP_NS_SASL
 *  Namespace definition for 'urn:ietf:params:xml:ns:xmpp-sasl'.
 */
enum XMPP_NS_SASL = "urn:ietf:params:xml:ns:xmpp-sasl";
/** @def XMPP_NS_BIND
 *  Namespace definition for 'urn:ietf:params:xml:ns:xmpp-bind'.
 */
enum XMPP_NS_BIND = "urn:ietf:params:xml:ns:xmpp-bind";
/** @def XMPP_NS_SESSION
 *  Namespace definition for 'urn:ietf:params:xml:ns:xmpp-session'.
 */
enum XMPP_NS_SESSION = "urn:ietf:params:xml:ns:xmpp-session";
/** @def XMPP_NS_AUTH
 *  Namespace definition for 'jabber:iq:auth'.
 */
enum XMPP_NS_AUTH = "jabber:iq:auth";
/** @def XMPP_NS_DISCO_INFO
 *  Namespace definition for 'http://jabber.org/protocol/disco#info'.
 */
enum XMPP_NS_DISCO_INFO = "http://jabber.org/protocol/disco#info";
/** @def XMPP_NS_DISCO_ITEMS
 *  Namespace definition for 'http://jabber.org/protocol/disco#items'.
 */
enum XMPP_NS_DISCO_ITEMS = "http://jabber.org/protocol/disco#items";
/** @def XMPP_NS_ROSTER
 *  Namespace definition for 'jabber:iq:roster'.
 */
enum XMPP_NS_ROSTER = "jabber:iq:roster";

/* error defines */
/** @def XMPP_EOK
 *  Success error code.
 */
enum XMPP_EOK = 0;
/** @def XMPP_EMEM
 *  Memory related failure error code.
 *
 *  This is returned on allocation errors and signals that the host may
 *  be out of memory.
 */
enum XMPP_EMEM = -1;
/** @def XMPP_EINVOP
 *  Invalid operation error code.
 *
 *  This error code is returned when the operation was invalid and signals
 *  that the Strophe API is being used incorrectly.
 */
enum XMPP_EINVOP = -2;
/** @def XMPP_EINT
 *  Internal failure error code.
 */
enum XMPP_EINT = -3;

/* initialization and shutdown */
void xmpp_initialize ();
void xmpp_shutdown ();

/* version */
int xmpp_version_check(int major, int minor);

/* run-time contexts */

/* opaque run time context containing the above hooks */
struct xmpp_ctx_t;

xmpp_ctx_t* xmpp_ctx_new (xmpp_mem_t* mem, xmpp_log_t* log);
void xmpp_ctx_free (xmpp_ctx_t* ctx);

/* free some blocks returned by other APIs, for example the
   buffer you get from xmpp_stanza_to_text */
void xmpp_free(xmpp_ctx_t* /*const*/ ctx, void* p);

/* user-replaceable memory allocator */
struct xmpp_mem_t {
  void* function (usize size, void* userdata) alloc;
  void function (void*p, void* userdata) free;
  void* function (void* p, usize size, void* userdata) realloc;
  void* userdata;
}

alias xmpp_log_level_t = int;
enum : int {
  XMPP_LEVEL_DEBUG,
  XMPP_LEVEL_INFO,
  XMPP_LEVEL_WARN,
  XMPP_LEVEL_ERROR,
}

alias xmpp_conn_type_t = int;
enum {
  XMPP_UNKNOWN,
  XMPP_CLIENT,
  XMPP_COMPONENT,
}

alias xmpp_log_handler = void function (void* userdata, xmpp_log_level_t level, const(char)* area, const(char)* msg);

/* user-replaceable log object */
struct xmpp_log_t {
  xmpp_log_handler handler;
  void* userdata;
}

/* return a default logger filtering at a given level */
xmpp_log_t* xmpp_get_default_logger (xmpp_log_level_t level);

/* connection */

/* opaque connection object */
struct xmpp_conn_t;
struct xmpp_stanza_t;

/* connection flags */
enum XMPP_CONN_FLAG_DISABLE_TLS = (1UL << 0);
enum XMPP_CONN_FLAG_MANDATORY_TLS = (1UL << 1);
enum XMPP_CONN_FLAG_LEGACY_SSL = (1UL << 2);

/* connect callback */
alias xmpp_conn_event_t = int;
enum : int {
  XMPP_CONN_CONNECT,
  XMPP_CONN_RAW_CONNECT,
  XMPP_CONN_DISCONNECT,
  XMPP_CONN_FAIL,
}

alias xmpp_error_type_t = int;
enum : int {
  XMPP_SE_BAD_FORMAT,
  XMPP_SE_BAD_NS_PREFIX,
  XMPP_SE_CONFLICT,
  XMPP_SE_CONN_TIMEOUT,
  XMPP_SE_HOST_GONE,
  XMPP_SE_HOST_UNKNOWN,
  XMPP_SE_IMPROPER_ADDR,
  XMPP_SE_INTERNAL_SERVER_ERROR,
  XMPP_SE_INVALID_FROM,
  XMPP_SE_INVALID_ID,
  XMPP_SE_INVALID_NS,
  XMPP_SE_INVALID_XML,
  XMPP_SE_NOT_AUTHORIZED,
  XMPP_SE_POLICY_VIOLATION,
  XMPP_SE_REMOTE_CONN_FAILED,
  XMPP_SE_RESOURCE_CONSTRAINT,
  XMPP_SE_RESTRICTED_XML,
  XMPP_SE_SEE_OTHER_HOST,
  XMPP_SE_SYSTEM_SHUTDOWN,
  XMPP_SE_UNDEFINED_CONDITION,
  XMPP_SE_UNSUPPORTED_ENCODING,
  XMPP_SE_UNSUPPORTED_STANZA_TYPE,
  XMPP_SE_UNSUPPORTED_VERSION,
  XMPP_SE_XML_NOT_WELL_FORMED
}

struct xmpp_stream_error_t {
  xmpp_error_type_t type;
  char* text;
  xmpp_stanza_t* stanza;
}

alias xmpp_conn_handler = void function (xmpp_conn_t* conn, xmpp_conn_event_t event, int error, xmpp_stream_error_t* stream_error, void* userdata);

xmpp_conn_t* xmpp_conn_new (xmpp_ctx_t* ctx);
xmpp_conn_t* xmpp_conn_clone (xmpp_conn_t* conn);
int xmpp_conn_release (xmpp_conn_t* conn);

c_long xmpp_conn_get_flags (xmpp_conn_t* conn);
int xmpp_conn_set_flags (xmpp_conn_t* conn, c_long flags);
const(char)* xmpp_conn_get_jid (xmpp_conn_t* conn);
const(char)* xmpp_conn_get_bound_jid (xmpp_conn_t* conn);
void xmpp_conn_set_jid (xmpp_conn_t* conn, const(char)* jid);
const(char)* xmpp_conn_get_pass(xmpp_conn_t* conn);
void xmpp_conn_set_pass (xmpp_conn_t* conn, const(char)* pass);
xmpp_ctx_t* xmpp_conn_get_context (xmpp_conn_t* conn);
void xmpp_conn_disable_tls (xmpp_conn_t* conn);
int xmpp_conn_is_secured (xmpp_conn_t* conn);
void xmpp_conn_set_keepalive (xmpp_conn_t* conn, int timeout, int interval);

int xmpp_connect_client (xmpp_conn_t* conn, const(char)* altdomain, ushort altport, xmpp_conn_handler callback, void* userdata);

int xmpp_connect_component (xmpp_conn_t* conn, const(char)* server, ushort port, xmpp_conn_handler callback, void* userdata);

int xmpp_connect_raw (xmpp_conn_t* conn, const(char)* altdomain, ushort altport, xmpp_conn_handler callback, void* userdata);
int xmpp_conn_open_stream_default (xmpp_conn_t* conn);
int xmpp_conn_open_stream (xmpp_conn_t* conn, char** attributes, usize attributes_len);
int xmpp_conn_tls_start (xmpp_conn_t* conn);

void xmpp_disconnect (xmpp_conn_t* conn);

void xmpp_send (xmpp_conn_t* conn, const(xmpp_stanza_t)* stanza);

void xmpp_send_raw_string (xmpp_conn_t* conn, const(char)* fmt, ...);
void xmpp_send_raw (xmpp_conn_t* conn, const(char)* data, usize len);


/* handlers */

/* if the handle returns false it is removed */
alias xmpp_timed_handler = int function (xmpp_conn_t* conn, void* userdata);

void xmpp_timed_handler_add (xmpp_conn_t* conn, xmpp_timed_handler handler, c_ulong period, void* userdata);
void xmpp_timed_handler_delete (xmpp_conn_t* conn, xmpp_timed_handler handler);


/* if the handler returns false it is removed */
alias xmpp_handler = int function (xmpp_conn_t* conn, const(xmpp_stanza_t)* stanza, void* userdata);

void xmpp_handler_add (xmpp_conn_t* conn, xmpp_handler handler, const(char)* ns, const(char)* name, const(char)* type, void* userdata);
void xmpp_handler_delete (xmpp_conn_t* conn, xmpp_handler handler);

void xmpp_id_handler_add (xmpp_conn_t* conn, xmpp_handler handler, const(char)* id, void* userdata);
void xmpp_id_handler_delete (xmpp_conn_t* conn, xmpp_handler handler, const(char)* id);

/*
void xmpp_register_stanza_handler(conn, stanza, xmlns, type, handler)
*/

/* stanzas */

/* allocate and initialize a blank stanza */
xmpp_stanza_t* xmpp_stanza_new (xmpp_ctx_t* ctx);

/* clone a stanza */
xmpp_stanza_t* xmpp_stanza_clone (const(xmpp_stanza_t)* stanza);

/* copies a stanza and all children */
xmpp_stanza_t* xmpp_stanza_copy (const(xmpp_stanza_t)* stanza);

/* free a stanza object and it's contents */
int xmpp_stanza_release (const(xmpp_stanza_t)* stanza);

int xmpp_stanza_is_text (const(xmpp_stanza_t)* stanza);
int xmpp_stanza_is_tag (const(xmpp_stanza_t)* stanza);

/* marshall a stanza into text for transmission or display */
int xmpp_stanza_to_text (xmpp_stanza_t* stanza, const(char)** buf, const(usize)* buflen);

xmpp_stanza_t* xmpp_stanza_get_children (const(xmpp_stanza_t)* stanza);
xmpp_stanza_t* xmpp_stanza_get_child_by_name (const(xmpp_stanza_t)* stanza, const(char)* name);
xmpp_stanza_t *xmpp_stanza_get_child_by_ns (const(xmpp_stanza_t)* stanza, const(char)* ns);
xmpp_stanza_t *xmpp_stanza_get_next (const(xmpp_stanza_t)* stanza);
int xmpp_stanza_add_child (xmpp_stanza_t* stanza, xmpp_stanza_t* child);

const(char)* xmpp_stanza_get_attribute (const(xmpp_stanza_t)* stanza, const(char)* name);
int xmpp_stanza_get_attribute_count (const(xmpp_stanza_t)* stanza);
int xmpp_stanza_get_attributes (const(xmpp_stanza_t)* stanza, const(char)** attr, int attrlen);
/* concatenate all child text nodes.  this function
 * returns a string that must be freed by the caller */
char* xmpp_stanza_get_text (const(xmpp_stanza_t)* stanza);
const(char)* xmpp_stanza_get_text_ptr (const(xmpp_stanza_t)* stanza);
const(char)* xmpp_stanza_get_name (const(xmpp_stanza_t)* stanza);
/* set_attribute adds/replaces attributes */
int xmpp_stanza_set_attribute (const(xmpp_stanza_t)* stanza, const(char)* key, const(char)* value);
int xmpp_stanza_set_name (xmpp_stanza_t* stanza, const(char)* name);
int xmpp_stanza_set_text (xmpp_stanza_t* stanza, const(char)* text);
int xmpp_stanza_set_text_with_size (xmpp_stanza_t* stanza, const(char)* text, usize size);
int xmpp_stanza_del_attribute (const(xmpp_stanza_t)* stanza, const(char)* name);

/* common stanza helpers */
const(char)* xmpp_stanza_get_ns (const(xmpp_stanza_t)* stanza);
const(char)* xmpp_stanza_get_type (const(xmpp_stanza_t)* stanza);
const(char)* xmpp_stanza_get_id (const(xmpp_stanza_t)* stanza);
const(char)* xmpp_stanza_get_to (const(xmpp_stanza_t)* stanza);
const(char)* xmpp_stanza_get_from (const(xmpp_stanza_t)* stanza);
int xmpp_stanza_set_ns (const(xmpp_stanza_t)* stanza, const(char)* ns);
int xmpp_stanza_set_id (const(xmpp_stanza_t)* stanza, const(char)* id);
int xmpp_stanza_set_type (const(xmpp_stanza_t)* stanza, const(char)* type);
int xmpp_stanza_set_to (const(xmpp_stanza_t)* stanza, const(char)* to);
int xmpp_stanza_set_from (const(xmpp_stanza_t)* stanza, const(char)* from);

/* allocate and initialize a stanza in reply to another */
xmpp_stanza_t* xmpp_stanza_reply (const(xmpp_stanza_t)* stanza);

/* stanza subclasses */
xmpp_stanza_t* xmpp_message_new (xmpp_ctx_t *ctx, const(char)* type, const(char)* to, const(char)* id);
char* xmpp_message_get_body (xmpp_stanza_t* msg);
int xmpp_message_set_body (xmpp_stanza_t* msg, const(char)* text);

xmpp_stanza_t* xmpp_iq_new (xmpp_ctx_t* ctx, const(char)* type, const(char)* id);
xmpp_stanza_t* xmpp_presence_new (xmpp_ctx_t* ctx);

/* jid */

/* these return new strings that must be xmpp_free()'d */
char* xmpp_jid_new (xmpp_ctx_t* ctx, const(char)* node, const(char)* domain, const(char)* resource);
char* xmpp_jid_bare(xmpp_ctx_t* ctx, const(char)* jid);
char* xmpp_jid_node(xmpp_ctx_t* ctx, const(char)* jid);
char* xmpp_jid_domain(xmpp_ctx_t* ctx, const(char)* jid);
char* xmpp_jid_resource(xmpp_ctx_t* ctx, const(char)* jid);

/* event loop */

void xmpp_run_once (xmpp_ctx_t* ctx, c_ulong timeout);
void xmpp_run (xmpp_ctx_t* ctx);
void xmpp_stop (xmpp_ctx_t* ctx);

/* UUID */

char* xmpp_uuid_gen (xmpp_ctx_t* ctx);

/* SHA1 */

/** @def XMPP_SHA1_DIGEST_SIZE
 *  Size of the SHA1 message digest.
 */
enum XMPP_SHA1_DIGEST_SIZE = 20;

struct xmpp_sha1_t;

char* xmpp_sha1 (xmpp_ctx_t* ctx, const(void)* data, usize len);

xmpp_sha1_t* xmpp_sha1_new (xmpp_ctx_t* ctx);
void xmpp_sha1_free (xmpp_sha1_t* sha1);
void xmpp_sha1_update (xmpp_sha1_t* sha1, const(void)* data, usize len);
void xmpp_sha1_final (xmpp_sha1_t* sha1);
char* xmpp_sha1_to_string (xmpp_sha1_t* sha1, char* s, usize slen);
char* xmpp_sha1_to_string_alloc (xmpp_sha1_t* sha1);
void xmpp_sha1_to_digest (xmpp_sha1_t* sha1, void* digest);

/* Base64 */

char* xmpp_base64_encode (xmpp_ctx_t* ctx, const(void)* data, usize len);
char* xmpp_base64_decode_str (xmpp_ctx_t* ctx, const(char)* base64, usize len);
void xmpp_base64_decode_bin (xmpp_ctx_t* ctx, const(char)* base64, usize len, void** out_, usize* outlen);
