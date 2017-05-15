/* -*- c -*-
 * Copyright (C) 2000-2012 Free Software Foundation, Inc.
 *
 * Author: Nikos Mavrogiannopoulos
 *
 * This file is part of GnuTLS.
 *
 * The GnuTLS is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public License
 * as published by the Free Software Foundation; either version 2.1 of
 * the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>
 *
 */

/* This file contains the types and prototypes for all the
 * high level functionality of the gnutls main library.
 *
 * If the optional C++ binding was built, it is available in
 * gnutls/gnutlsxx.h.
 *
 * The openssl compatibility layer (which is under the GNU GPL
 * license) is in gnutls/openssl.h.
 *
 * The low level cipher functionality is in gnutls/crypto.h.
 */
module iv.gnutls is aliced;
pragma(lib, "gnutls");
pragma(lib, "gcrypt");

import core.sys.posix.sys.types : time_t;


extern(C) nothrow:

alias gnutls_params_function = int function (gnutls_session_t, gnutls_params_type_t, gnutls_params_st *);
alias gnutls_certificate_verify_function = int function (gnutls_session_t);
alias gnutls_db_store_func = int function (void *, gnutls_datum_t key, gnutls_datum_t data);
alias gnutls_db_remove_func = int function (void *, gnutls_datum_t key);
alias gnutls_db_retr_func = gnutls_datum_t function (void *, gnutls_datum_t key);
alias gnutls_handshake_post_client_hello_func = int function (gnutls_session_t);
alias gnutls_handshake_hook_func = int function (gnutls_session_t, uint htype, uint post, uint incoming, const(gnutls_datum_t)* msg);
alias gnutls_time_func = time_t function (time_t * t);
alias mutex_init_func = int function (void **mutex);
alias mutex_lock_func = int function (void **mutex);
alias mutex_unlock_func = int function (void **mutex);
alias mutex_deinit_func = int function (void **mutex);
alias gnutls_alloc_function = void * function (usize);
alias gnutls_calloc_function = void * function (usize, usize);
alias gnutls_is_secure_function = int function (const(void)* );
alias gnutls_free_function = void function (void *);
alias gnutls_realloc_function = void * function (void *, usize);
alias gnutls_log_func = void function (int, const(char)* );
alias gnutls_audit_log_func = void function (gnutls_session_t, const(char)* );
alias gnutls_pull_func = ssize function (gnutls_transport_ptr_t, void *, usize);
alias gnutls_push_func = ssize function (gnutls_transport_ptr_t, const(void)* , usize);
alias gnutls_pull_timeout_func = int function (gnutls_transport_ptr_t, uint ms);
alias gnutls_vec_push_func = ssize function (gnutls_transport_ptr_t, const(giovec_t)* iov, int iovcnt);
alias gnutls_errno_func = int function (gnutls_transport_ptr_t);
alias gnutls_srp_server_credentials_function = int function (gnutls_session_t, const(char)* username, gnutls_datum_t* salt, gnutls_datum_t* verifier, gnutls_datum_t* generator, gnutls_datum_t* prime);
alias gnutls_srp_client_credentials_function = int function (gnutls_session_t, char **, char **);
alias gnutls_psk_server_credentials_function = int function (gnutls_session_t, const(char)* username, gnutls_datum_t* key);
alias gnutls_psk_client_credentials_function = int function (gnutls_session_t, char** username, gnutls_datum_t* key);
alias gnutls_certificate_retrieve_function = int function (gnutls_session_t, const(gnutls_datum_t)* req_ca_rdn, int nreqs, const(gnutls_pk_algorithm_t)* pk_algos, int pk_algos_length, gnutls_retr2_st*);
alias gnutls_tdb_store_func = int function (const(char)* db_name, const(char)* host, const(char)* service, time_t expiration, const(gnutls_datum_t)* pubkey);
alias gnutls_tdb_store_commitment_func = int function (const(char)* db_name, const(char)* host, const(char)* service, time_t expiration, gnutls_digest_algorithm_t hash_algo, const(gnutls_datum_t)* hash);
alias gnutls_tdb_verify_func = int function (const(char)* db_name, const(char)* host, const(char)* service, const(gnutls_datum_t)* pubkey);
alias gnutls_pin_callback_t = int function (void *userdata, int attempt, const(char)* token_url, const(char)* token_label, uint flags, char* pin, usize pin_max);
alias gnutls_ext_recv_func = int function (gnutls_session_t session, const(ubyte)* data, usize len);
alias gnutls_ext_send_func = int function (gnutls_session_t session, gnutls_buffer_t extdata);
alias gnutls_ext_deinit_data_func = void function (gnutls_ext_priv_data_t data);
alias gnutls_ext_pack_func = int function (gnutls_ext_priv_data_t data, gnutls_buffer_t packed_data);
alias gnutls_ext_unpack_func = int function (gnutls_buffer_t packed_data, gnutls_ext_priv_data_t *data);
alias gnutls_supp_recv_func = int function (gnutls_session_t session, const(ubyte)* data, usize data_size);
alias gnutls_supp_send_func = int function (gnutls_session_t session, gnutls_buffer_t buf);


@nogc:
enum GNUTLS_VERSION = "3.4.10";

enum GNUTLS_VERSION_MAJOR = 3;
enum GNUTLS_VERSION_MINOR = 4;
enum GNUTLS_VERSION_PATCH = 10;

enum GNUTLS_VERSION_NUMBER = 0x03040a;

enum GNUTLS_CIPHER_RIJNDAEL_128_CBC = GNUTLS_CIPHER_AES_128_CBC;
enum GNUTLS_CIPHER_RIJNDAEL_256_CBC = GNUTLS_CIPHER_AES_256_CBC;
enum GNUTLS_CIPHER_RIJNDAEL_CBC = GNUTLS_CIPHER_AES_128_CBC;
enum GNUTLS_CIPHER_ARCFOUR = GNUTLS_CIPHER_ARCFOUR_128;

/* Use the following definition globally in your program to disable
 * implicit initialization of gnutls. */
/*???
#define GNUTLS_SKIP_GLOBAL_INIT int _gnutls_global_init_skip() @nogc; \
    int _gnutls_global_init_skip(void) {return 1;}
*/

/**
 * gnutls_cipher_algorithm_t:
 * @GNUTLS_CIPHER_UNKNOWN: Value to identify an unknown/unsupported algorithm.
 * @GNUTLS_CIPHER_NULL: The NULL (identity) encryption algorithm.
 * @GNUTLS_CIPHER_ARCFOUR_128: ARCFOUR stream cipher with 128-bit keys.
 * @GNUTLS_CIPHER_3DES_CBC: 3DES in CBC mode.
 * @GNUTLS_CIPHER_AES_128_CBC: AES in CBC mode with 128-bit keys.
 * @GNUTLS_CIPHER_AES_192_CBC: AES in CBC mode with 192-bit keys.
 * @GNUTLS_CIPHER_AES_256_CBC: AES in CBC mode with 256-bit keys.
 * @GNUTLS_CIPHER_ARCFOUR_40: ARCFOUR stream cipher with 40-bit keys.
 * @GNUTLS_CIPHER_CAMELLIA_128_CBC: Camellia in CBC mode with 128-bit keys.
 * @GNUTLS_CIPHER_CAMELLIA_192_CBC: Camellia in CBC mode with 192-bit keys.
 * @GNUTLS_CIPHER_CAMELLIA_256_CBC: Camellia in CBC mode with 256-bit keys.
 * @GNUTLS_CIPHER_RC2_40_CBC: RC2 in CBC mode with 40-bit keys.
 * @GNUTLS_CIPHER_DES_CBC: DES in CBC mode (56-bit keys).
 * @GNUTLS_CIPHER_AES_128_GCM: AES in GCM mode with 128-bit keys.
 * @GNUTLS_CIPHER_AES_256_GCM: AES in GCM mode with 256-bit keys.
 * @GNUTLS_CIPHER_AES_128_CCM: AES in CCM mode with 128-bit keys.
 * @GNUTLS_CIPHER_AES_256_CCM: AES in CCM mode with 256-bit keys.
 * @GNUTLS_CIPHER_AES_128_CCM_8: AES in CCM mode with 64-bit tag and 128-bit keys.
 * @GNUTLS_CIPHER_AES_256_CCM_8: AES in CCM mode with 64-bit tag and 256-bit keys.
 * @GNUTLS_CIPHER_CAMELLIA_128_GCM: CAMELLIA in GCM mode with 128-bit keys.
 * @GNUTLS_CIPHER_CAMELLIA_256_GCM: CAMELLIA in GCM mode with 256-bit keys.
 * @GNUTLS_CIPHER_SALSA20_256: Salsa20 with 256-bit keys.
 * @GNUTLS_CIPHER_ESTREAM_SALSA20_256: Estream's Salsa20 variant with 256-bit keys.
 * @GNUTLS_CIPHER_CHACHA20_POLY1305: The Chacha20 cipher with the Poly1305 authenticator (AEAD).
 * @GNUTLS_CIPHER_IDEA_PGP_CFB: IDEA in CFB mode (placeholder - unsupported).
 * @GNUTLS_CIPHER_3DES_PGP_CFB: 3DES in CFB mode (placeholder - unsupported).
 * @GNUTLS_CIPHER_CAST5_PGP_CFB: CAST5 in CFB mode (placeholder - unsupported).
 * @GNUTLS_CIPHER_BLOWFISH_PGP_CFB: Blowfish in CFB mode (placeholder - unsupported).
 * @GNUTLS_CIPHER_SAFER_SK128_PGP_CFB: Safer-SK in CFB mode with 128-bit keys (placeholder - unsupported).
 * @GNUTLS_CIPHER_AES128_PGP_CFB: AES in CFB mode with 128-bit keys (placeholder - unsupported).
 * @GNUTLS_CIPHER_AES192_PGP_CFB: AES in CFB mode with 192-bit keys (placeholder - unsupported).
 * @GNUTLS_CIPHER_AES256_PGP_CFB: AES in CFB mode with 256-bit keys (placeholder - unsupported).
 * @GNUTLS_CIPHER_TWOFISH_PGP_CFB: Twofish in CFB mode (placeholder - unsupported).
 *
 * Enumeration of different symmetric encryption algorithms.
 */
alias gnutls_cipher_algorithm = gnutls_cipher_algorithm_t;
alias gnutls_cipher_algorithm_t = int;
enum : int {
  GNUTLS_CIPHER_UNKNOWN = 0,
  GNUTLS_CIPHER_NULL = 1,
  GNUTLS_CIPHER_ARCFOUR_128 = 2,
  GNUTLS_CIPHER_3DES_CBC = 3,
  GNUTLS_CIPHER_AES_128_CBC = 4,
  GNUTLS_CIPHER_AES_256_CBC = 5,
  GNUTLS_CIPHER_ARCFOUR_40 = 6,
  GNUTLS_CIPHER_CAMELLIA_128_CBC = 7,
  GNUTLS_CIPHER_CAMELLIA_256_CBC = 8,
  GNUTLS_CIPHER_AES_192_CBC = 9,
  GNUTLS_CIPHER_AES_128_GCM = 10,
  GNUTLS_CIPHER_AES_256_GCM = 11,
  GNUTLS_CIPHER_CAMELLIA_192_CBC = 12,
  GNUTLS_CIPHER_SALSA20_256 = 13,
  GNUTLS_CIPHER_ESTREAM_SALSA20_256 = 14,
  GNUTLS_CIPHER_CAMELLIA_128_GCM = 15,
  GNUTLS_CIPHER_CAMELLIA_256_GCM = 16,
  GNUTLS_CIPHER_RC2_40_CBC = 17,
  GNUTLS_CIPHER_DES_CBC = 18,
  GNUTLS_CIPHER_AES_128_CCM = 19,
  GNUTLS_CIPHER_AES_256_CCM = 20,
  GNUTLS_CIPHER_AES_128_CCM_8 = 21,
  GNUTLS_CIPHER_AES_256_CCM_8 = 22,
  GNUTLS_CIPHER_CHACHA20_POLY1305 = 23,

  /* used only for PGP internals. Ignored in TLS/SSL
   */
  GNUTLS_CIPHER_IDEA_PGP_CFB = 200,
  GNUTLS_CIPHER_3DES_PGP_CFB = 201,
  GNUTLS_CIPHER_CAST5_PGP_CFB = 202,
  GNUTLS_CIPHER_BLOWFISH_PGP_CFB = 203,
  GNUTLS_CIPHER_SAFER_SK128_PGP_CFB = 204,
  GNUTLS_CIPHER_AES128_PGP_CFB = 205,
  GNUTLS_CIPHER_AES192_PGP_CFB = 206,
  GNUTLS_CIPHER_AES256_PGP_CFB = 207,
  GNUTLS_CIPHER_TWOFISH_PGP_CFB = 208
}

/**
 * gnutls_kx_algorithm_t:
 * @GNUTLS_KX_UNKNOWN: Unknown key-exchange algorithm.
 * @GNUTLS_KX_RSA: RSA key-exchange algorithm.
 * @GNUTLS_KX_DHE_DSS: DHE-DSS key-exchange algorithm.
 * @GNUTLS_KX_DHE_RSA: DHE-RSA key-exchange algorithm.
 * @GNUTLS_KX_ECDHE_RSA: ECDHE-RSA key-exchange algorithm.
 * @GNUTLS_KX_ECDHE_ECDSA: ECDHE-ECDSA key-exchange algorithm.
 * @GNUTLS_KX_ANON_DH: Anon-DH key-exchange algorithm.
 * @GNUTLS_KX_ANON_ECDH: Anon-ECDH key-exchange algorithm.
 * @GNUTLS_KX_SRP: SRP key-exchange algorithm.
 * @GNUTLS_KX_RSA_EXPORT: RSA-EXPORT key-exchange algorithm (defunc).
 * @GNUTLS_KX_SRP_RSA: SRP-RSA key-exchange algorithm.
 * @GNUTLS_KX_SRP_DSS: SRP-DSS key-exchange algorithm.
 * @GNUTLS_KX_PSK: PSK key-exchange algorithm.
 * @GNUTLS_KX_DHE_PSK: DHE-PSK key-exchange algorithm.
 * @GNUTLS_KX_ECDHE_PSK: ECDHE-PSK key-exchange algorithm.
 * @GNUTLS_KX_RSA_PSK: RSA-PSK key-exchange algorithm.
 *
 * Enumeration of different key exchange algorithms.
 */
alias gnutls_kx_algorithm_t = int;
enum : int {
  GNUTLS_KX_UNKNOWN = 0,
  GNUTLS_KX_RSA = 1,
  GNUTLS_KX_DHE_DSS = 2,
  GNUTLS_KX_DHE_RSA = 3,
  GNUTLS_KX_ANON_DH = 4,
  GNUTLS_KX_SRP = 5,
  GNUTLS_KX_RSA_EXPORT = 6,
  GNUTLS_KX_SRP_RSA = 7,
  GNUTLS_KX_SRP_DSS = 8,
  GNUTLS_KX_PSK = 9,
  GNUTLS_KX_DHE_PSK = 10,
  GNUTLS_KX_ANON_ECDH = 11,
  GNUTLS_KX_ECDHE_RSA = 12,
  GNUTLS_KX_ECDHE_ECDSA = 13,
  GNUTLS_KX_ECDHE_PSK = 14,
  GNUTLS_KX_RSA_PSK = 15
}

/**
 * gnutls_params_type_t:
 * @GNUTLS_PARAMS_RSA_EXPORT: Session RSA-EXPORT parameters (defunc).
 * @GNUTLS_PARAMS_DH: Session Diffie-Hellman parameters.
 * @GNUTLS_PARAMS_ECDH: Session Elliptic-Curve Diffie-Hellman parameters.
 *
 * Enumeration of different TLS session parameter types.
 */
alias gnutls_params_type_t = int;
enum : int {
  GNUTLS_PARAMS_RSA_EXPORT = 1,
  GNUTLS_PARAMS_DH = 2,
  GNUTLS_PARAMS_ECDH = 3
}

/**
 * gnutls_credentials_type_t:
 * @GNUTLS_CRD_CERTIFICATE: Certificate credential.
 * @GNUTLS_CRD_ANON: Anonymous credential.
 * @GNUTLS_CRD_SRP: SRP credential.
 * @GNUTLS_CRD_PSK: PSK credential.
 * @GNUTLS_CRD_IA: IA credential.
 *
 * Enumeration of different credential types.
 */
alias gnutls_credentials_type_t = int;
enum : int {
  GNUTLS_CRD_CERTIFICATE = 1,
  GNUTLS_CRD_ANON,
  GNUTLS_CRD_SRP,
  GNUTLS_CRD_PSK,
  GNUTLS_CRD_IA
}

enum GNUTLS_MAC_SHA = GNUTLS_MAC_SHA1;
enum GNUTLS_DIG_SHA = GNUTLS_DIG_SHA1;

/**
 * gnutls_mac_algorithm_t:
 * @GNUTLS_MAC_UNKNOWN: Unknown MAC algorithm.
 * @GNUTLS_MAC_NULL: NULL MAC algorithm (empty output).
 * @GNUTLS_MAC_MD5: HMAC-MD5 algorithm.
 * @GNUTLS_MAC_SHA1: HMAC-SHA-1 algorithm.
 * @GNUTLS_MAC_RMD160: HMAC-RMD160 algorithm.
 * @GNUTLS_MAC_MD2: HMAC-MD2 algorithm.
 * @GNUTLS_MAC_SHA256: HMAC-SHA-256 algorithm.
 * @GNUTLS_MAC_SHA384: HMAC-SHA-384 algorithm.
 * @GNUTLS_MAC_SHA512: HMAC-SHA-512 algorithm.
 * @GNUTLS_MAC_SHA224: HMAC-SHA-224 algorithm.
 * @GNUTLS_MAC_AEAD: MAC implicit through AEAD cipher.
 * @GNUTLS_MAC_UMAC_96: The UMAC-96 MAC algorithm.
 * @GNUTLS_MAC_UMAC_128: The UMAC-128 MAC algorithm.
 *
 * Enumeration of different Message Authentication Code (MAC)
 * algorithms.
 */
alias gnutls_mac_algorithm_t = int;
enum : int {
  GNUTLS_MAC_UNKNOWN = 0,
  GNUTLS_MAC_NULL = 1,
  GNUTLS_MAC_MD5 = 2,
  GNUTLS_MAC_SHA1 = 3,
  GNUTLS_MAC_RMD160 = 4,
  GNUTLS_MAC_MD2 = 5,
  GNUTLS_MAC_SHA256 = 6,
  GNUTLS_MAC_SHA384 = 7,
  GNUTLS_MAC_SHA512 = 8,
  GNUTLS_MAC_SHA224 = 9,
  /* If you add anything here, make sure you align with
     gnutls_digest_algorithm_t. */
  GNUTLS_MAC_AEAD = 200,  /* indicates that MAC is on the cipher */
  GNUTLS_MAC_UMAC_96 = 201,
  GNUTLS_MAC_UMAC_128 = 202
}

/**
 * gnutls_digest_algorithm_t:
 * @GNUTLS_DIG_UNKNOWN: Unknown hash algorithm.
 * @GNUTLS_DIG_NULL: NULL hash algorithm (empty output).
 * @GNUTLS_DIG_MD5: MD5 algorithm.
 * @GNUTLS_DIG_SHA1: SHA-1 algorithm.
 * @GNUTLS_DIG_RMD160: RMD160 algorithm.
 * @GNUTLS_DIG_MD2: MD2 algorithm.
 * @GNUTLS_DIG_SHA256: SHA-256 algorithm.
 * @GNUTLS_DIG_SHA384: SHA-384 algorithm.
 * @GNUTLS_DIG_SHA512: SHA-512 algorithm.
 * @GNUTLS_DIG_SHA224: SHA-224 algorithm.
 *
 * Enumeration of different digest (hash) algorithms.
 */
alias gnutls_digest_algorithm_t = int;
enum : int {
  GNUTLS_DIG_UNKNOWN = GNUTLS_MAC_UNKNOWN,
  GNUTLS_DIG_NULL = GNUTLS_MAC_NULL,
  GNUTLS_DIG_MD5 = GNUTLS_MAC_MD5,
  GNUTLS_DIG_SHA1 = GNUTLS_MAC_SHA1,
  GNUTLS_DIG_RMD160 = GNUTLS_MAC_RMD160,
  GNUTLS_DIG_MD2 = GNUTLS_MAC_MD2,
  GNUTLS_DIG_SHA256 = GNUTLS_MAC_SHA256,
  GNUTLS_DIG_SHA384 = GNUTLS_MAC_SHA384,
  GNUTLS_DIG_SHA512 = GNUTLS_MAC_SHA512,
  GNUTLS_DIG_SHA224 = GNUTLS_MAC_SHA224
      /* If you add anything here, make sure you align with
         gnutls_mac_algorithm_t. */
}

  /* exported for other gnutls headers. This is the maximum number of
   * algorithms (ciphers, kx or macs).
   */
enum GNUTLS_MAX_ALGORITHM_NUM = 32;
enum GNUTLS_MAX_SESSION_ID_SIZE = 32;


/**
 * gnutls_compression_method_t:
 * @GNUTLS_COMP_UNKNOWN: Unknown compression method.
 * @GNUTLS_COMP_NULL: The NULL compression method (no compression).
 * @GNUTLS_COMP_DEFLATE: The DEFLATE compression method from zlib.
 * @GNUTLS_COMP_ZLIB: Same as %GNUTLS_COMP_DEFLATE.
 *
 * Enumeration of different TLS compression methods.
 */
alias gnutls_compression_method_t = int;
enum : int {
  GNUTLS_COMP_UNKNOWN = 0,
  GNUTLS_COMP_NULL = 1,
  GNUTLS_COMP_DEFLATE = 2,
  GNUTLS_COMP_ZLIB = GNUTLS_COMP_DEFLATE
}

  /*
   * Flags for gnutls_init()
   *
   * @GNUTLS_SERVER: Connection end is a server.
   * @GNUTLS_CLIENT: Connection end is a client.
   * @GNUTLS_DATAGRAM: Connection is datagram oriented (DTLS).
   * @GNUTLS_NONBLOCK: Connection should not block.
   * @GNUTLS_NO_SIGNAL: In systems where SIGPIPE is delivered on send, it will be disabled. That flag has effect in systems which support the MSG_NOSIGNAL sockets flag.
   * @GNUTLS_NO_EXTENSIONS: Do not enable any TLS extensions by default.
   * @GNUTLS_NO_REPLAY_PROTECTION: Disable any replay protection in DTLS.
   *
   */
enum GNUTLS_SERVER = 1;
enum GNUTLS_CLIENT = (1<<1);
enum GNUTLS_DATAGRAM = (1<<2);
enum GNUTLS_NONBLOCK = (1<<3);
enum GNUTLS_NO_EXTENSIONS = (1<<4);
enum GNUTLS_NO_REPLAY_PROTECTION = (1<<5);
enum GNUTLS_NO_SIGNAL = (1<<6);

/**
 * gnutls_alert_level_t:
 * @GNUTLS_AL_WARNING: Alert of warning severity.
 * @GNUTLS_AL_FATAL: Alert of fatal severity.
 *
 * Enumeration of different TLS alert severities.
 */
alias gnutls_alert_level_t = int;
enum : int {
  GNUTLS_AL_WARNING = 1,
  GNUTLS_AL_FATAL
}

/**
 * gnutls_alert_description_t:
 * @GNUTLS_A_CLOSE_NOTIFY: Close notify.
 * @GNUTLS_A_UNEXPECTED_MESSAGE: Unexpected message.
 * @GNUTLS_A_BAD_RECORD_MAC: Bad record MAC.
 * @GNUTLS_A_DECRYPTION_FAILED: Decryption failed.
 * @GNUTLS_A_RECORD_OVERFLOW: Record overflow.
 * @GNUTLS_A_DECOMPRESSION_FAILURE: Decompression failed.
 * @GNUTLS_A_HANDSHAKE_FAILURE: Handshake failed.
 * @GNUTLS_A_SSL3_NO_CERTIFICATE: No certificate.
 * @GNUTLS_A_BAD_CERTIFICATE: Certificate is bad.
 * @GNUTLS_A_UNSUPPORTED_CERTIFICATE: Certificate is not supported.
 * @GNUTLS_A_CERTIFICATE_REVOKED: Certificate was revoked.
 * @GNUTLS_A_CERTIFICATE_EXPIRED: Certificate is expired.
 * @GNUTLS_A_CERTIFICATE_UNKNOWN: Unknown certificate.
 * @GNUTLS_A_ILLEGAL_PARAMETER: Illegal parameter.
 * @GNUTLS_A_UNKNOWN_CA: CA is unknown.
 * @GNUTLS_A_ACCESS_DENIED: Access was denied.
 * @GNUTLS_A_DECODE_ERROR: Decode error.
 * @GNUTLS_A_DECRYPT_ERROR: Decrypt error.
 * @GNUTLS_A_EXPORT_RESTRICTION: Export restriction.
 * @GNUTLS_A_PROTOCOL_VERSION: Error in protocol version.
 * @GNUTLS_A_INSUFFICIENT_SECURITY: Insufficient security.
 * @GNUTLS_A_USER_CANCELED: User canceled.
 * @GNUTLS_A_INTERNAL_ERROR: Internal error.
 * @GNUTLS_A_INAPPROPRIATE_FALLBACK: Inappropriate fallback,
 * @GNUTLS_A_NO_RENEGOTIATION: No renegotiation is allowed.
 * @GNUTLS_A_CERTIFICATE_UNOBTAINABLE: Could not retrieve the
 *   specified certificate.
 * @GNUTLS_A_UNSUPPORTED_EXTENSION: An unsupported extension was
 *   sent.
 * @GNUTLS_A_UNRECOGNIZED_NAME: The server name sent was not
 *   recognized.
 * @GNUTLS_A_UNKNOWN_PSK_IDENTITY: The SRP/PSK username is missing
 *   or not known.
 * @GNUTLS_A_NO_APPLICATION_PROTOCOL: The ALPN protocol requested is
 *   not supported by the peer.
 *
 * Enumeration of different TLS alerts.
 */
alias gnutls_alert_description_t = int;
enum : int {
  GNUTLS_A_CLOSE_NOTIFY,
  GNUTLS_A_UNEXPECTED_MESSAGE = 10,
  GNUTLS_A_BAD_RECORD_MAC = 20,
  GNUTLS_A_DECRYPTION_FAILED,
  GNUTLS_A_RECORD_OVERFLOW,
  GNUTLS_A_DECOMPRESSION_FAILURE = 30,
  GNUTLS_A_HANDSHAKE_FAILURE = 40,
  GNUTLS_A_SSL3_NO_CERTIFICATE = 41,
  GNUTLS_A_BAD_CERTIFICATE = 42,
  GNUTLS_A_UNSUPPORTED_CERTIFICATE,
  GNUTLS_A_CERTIFICATE_REVOKED,
  GNUTLS_A_CERTIFICATE_EXPIRED,
  GNUTLS_A_CERTIFICATE_UNKNOWN,
  GNUTLS_A_ILLEGAL_PARAMETER,
  GNUTLS_A_UNKNOWN_CA,
  GNUTLS_A_ACCESS_DENIED,
  GNUTLS_A_DECODE_ERROR = 50,
  GNUTLS_A_DECRYPT_ERROR,
  GNUTLS_A_EXPORT_RESTRICTION = 60,
  GNUTLS_A_PROTOCOL_VERSION = 70,
  GNUTLS_A_INSUFFICIENT_SECURITY,
  GNUTLS_A_INTERNAL_ERROR = 80,
  GNUTLS_A_INAPPROPRIATE_FALLBACK = 86,
  GNUTLS_A_USER_CANCELED = 90,
  GNUTLS_A_NO_RENEGOTIATION = 100,
  GNUTLS_A_UNSUPPORTED_EXTENSION = 110,
  GNUTLS_A_CERTIFICATE_UNOBTAINABLE = 111,
  GNUTLS_A_UNRECOGNIZED_NAME = 112,
  GNUTLS_A_UNKNOWN_PSK_IDENTITY = 115,
  GNUTLS_A_NO_APPLICATION_PROTOCOL = 120
}

/**
 * gnutls_handshake_description_t:
 * @GNUTLS_HANDSHAKE_HELLO_REQUEST: Hello request.
 * @GNUTLS_HANDSHAKE_HELLO_VERIFY_REQUEST: DTLS Hello verify request.
 * @GNUTLS_HANDSHAKE_CLIENT_HELLO: Client hello.
 * @GNUTLS_HANDSHAKE_SERVER_HELLO: Server hello.
 * @GNUTLS_HANDSHAKE_NEW_SESSION_TICKET: New session ticket.
 * @GNUTLS_HANDSHAKE_CERTIFICATE_PKT: Certificate packet.
 * @GNUTLS_HANDSHAKE_SERVER_KEY_EXCHANGE: Server key exchange.
 * @GNUTLS_HANDSHAKE_CERTIFICATE_REQUEST: Certificate request.
 * @GNUTLS_HANDSHAKE_SERVER_HELLO_DONE: Server hello done.
 * @GNUTLS_HANDSHAKE_CERTIFICATE_VERIFY: Certificate verify.
 * @GNUTLS_HANDSHAKE_CLIENT_KEY_EXCHANGE: Client key exchange.
 * @GNUTLS_HANDSHAKE_FINISHED: Finished.
 * @GNUTLS_HANDSHAKE_CERTIFICATE_STATUS: Certificate status (OCSP).
 * @GNUTLS_HANDSHAKE_SUPPLEMENTAL: Supplemental.
 * @GNUTLS_HANDSHAKE_CHANGE_CIPHER_SPEC: Change Cipher Spec.
 * @GNUTLS_HANDSHAKE_CLIENT_HELLO_V2: SSLv2 Client Hello.
 *
 * Enumeration of different TLS handshake packets.
 */
alias gnutls_handshake_description_t = int;
enum : int {
  GNUTLS_HANDSHAKE_HELLO_REQUEST = 0,
  GNUTLS_HANDSHAKE_CLIENT_HELLO = 1,
  GNUTLS_HANDSHAKE_SERVER_HELLO = 2,
  GNUTLS_HANDSHAKE_HELLO_VERIFY_REQUEST = 3,
  GNUTLS_HANDSHAKE_NEW_SESSION_TICKET = 4,
  GNUTLS_HANDSHAKE_CERTIFICATE_PKT = 11,
  GNUTLS_HANDSHAKE_SERVER_KEY_EXCHANGE = 12,
  GNUTLS_HANDSHAKE_CERTIFICATE_REQUEST = 13,
  GNUTLS_HANDSHAKE_SERVER_HELLO_DONE = 14,
  GNUTLS_HANDSHAKE_CERTIFICATE_VERIFY = 15,
  GNUTLS_HANDSHAKE_CLIENT_KEY_EXCHANGE = 16,
  GNUTLS_HANDSHAKE_FINISHED = 20,
  GNUTLS_HANDSHAKE_CERTIFICATE_STATUS = 22,
  GNUTLS_HANDSHAKE_SUPPLEMENTAL = 23,
  GNUTLS_HANDSHAKE_CHANGE_CIPHER_SPEC = 254,
  GNUTLS_HANDSHAKE_CLIENT_HELLO_V2 = 1024
}

enum GNUTLS_HANDSHAKE_ANY = (cast(uint)-1);

const(char)
    *gnutls_handshake_description_get_name(gnutls_handshake_description_t
             type) @nogc;

/**
 * gnutls_certificate_status_t:
 * @GNUTLS_CERT_INVALID: The certificate is not signed by one of the
 *   known authorities or the signature is invalid (deprecated by the flags
 *   %GNUTLS_CERT_SIGNATURE_FAILURE and %GNUTLS_CERT_SIGNER_NOT_FOUND).
 * @GNUTLS_CERT_SIGNATURE_FAILURE: The signature verification failed.
 * @GNUTLS_CERT_REVOKED: Certificate is revoked by its authority.  In X.509 this will be
 *   set only if CRLs are checked.
 * @GNUTLS_CERT_SIGNER_NOT_FOUND: The certificate's issuer is not known.
 *   This is the case if the issuer is not included in the trusted certificate list.
 * @GNUTLS_CERT_SIGNER_NOT_CA: The certificate's signer was not a CA. This
 *   may happen if this was a version 1 certificate, which is common with
 *   some CAs, or a version 3 certificate without the basic constrains extension.
 * @GNUTLS_CERT_SIGNER_CONSTRAINTS_FAILURE: The certificate's signer constraints were
 *   violated.
 * @GNUTLS_CERT_INSECURE_ALGORITHM:  The certificate was signed using an insecure
 *   algorithm such as MD2 or MD5. These algorithms have been broken and
 *   should not be trusted.
 * @GNUTLS_CERT_NOT_ACTIVATED: The certificate is not yet activated.
 * @GNUTLS_CERT_EXPIRED: The certificate has expired.
 * @GNUTLS_CERT_REVOCATION_DATA_SUPERSEDED: The revocation data are old and have been superseded.
 * @GNUTLS_CERT_REVOCATION_DATA_ISSUED_IN_FUTURE: The revocation data have a future issue date.
 * @GNUTLS_CERT_UNEXPECTED_OWNER: The owner is not the expected one.
 * @GNUTLS_CERT_MISMATCH: The certificate presented isn't the expected one (TOFU)
 * @GNUTLS_CERT_PURPOSE_MISMATCH: The certificate or an intermediate does not match the intended purpose (extended key usage).
 *
 * Enumeration of certificate status codes.  Note that the status
 * bits may have different meanings in OpenPGP keys and X.509
 * certificate verification.
 */
alias gnutls_certificate_status_t = int;
enum : int {
  GNUTLS_CERT_INVALID = 1 << 1,
  GNUTLS_CERT_REVOKED = 1 << 5,
  GNUTLS_CERT_SIGNER_NOT_FOUND = 1 << 6,
  GNUTLS_CERT_SIGNER_NOT_CA = 1 << 7,
  GNUTLS_CERT_INSECURE_ALGORITHM = 1 << 8,
  GNUTLS_CERT_NOT_ACTIVATED = 1 << 9,
  GNUTLS_CERT_EXPIRED = 1 << 10,
  GNUTLS_CERT_SIGNATURE_FAILURE = 1 << 11,
  GNUTLS_CERT_REVOCATION_DATA_SUPERSEDED = 1 << 12,
  GNUTLS_CERT_UNEXPECTED_OWNER = 1 << 14,
  GNUTLS_CERT_REVOCATION_DATA_ISSUED_IN_FUTURE = 1 << 15,
  GNUTLS_CERT_SIGNER_CONSTRAINTS_FAILURE = 1 << 16,
  GNUTLS_CERT_MISMATCH = 1 << 17,
  GNUTLS_CERT_PURPOSE_MISMATCH = 1 << 18
}

/**
 * gnutls_certificate_request_t:
 * @GNUTLS_CERT_IGNORE: Ignore certificate.
 * @GNUTLS_CERT_REQUEST: Request certificate.
 * @GNUTLS_CERT_REQUIRE: Require certificate.
 *
 * Enumeration of certificate request types.
 */
alias gnutls_certificate_request_t = int;
enum : int {
  GNUTLS_CERT_IGNORE = 0,
  GNUTLS_CERT_REQUEST = 1,
  GNUTLS_CERT_REQUIRE = 2
}

/**
 * gnutls_openpgp_crt_status_t:
 * @GNUTLS_OPENPGP_CERT: Send entire certificate.
 * @GNUTLS_OPENPGP_CERT_FINGERPRINT: Send only certificate fingerprint.
 *
 * Enumeration of ways to send OpenPGP certificate.
 */
alias gnutls_openpgp_crt_status_t = int;
enum : int {
  GNUTLS_OPENPGP_CERT = 0,
  GNUTLS_OPENPGP_CERT_FINGERPRINT = 1
}

/**
 * gnutls_close_request_t:
 * @GNUTLS_SHUT_RDWR: Disallow further receives/sends.
 * @GNUTLS_SHUT_WR: Disallow further sends.
 *
 * Enumeration of how TLS session should be terminated.  See gnutls_bye().
 */
alias gnutls_close_request_t = int;
enum : int {
  GNUTLS_SHUT_RDWR = 0,
  GNUTLS_SHUT_WR = 1
}

/**
 * gnutls_protocol_t:
 * @GNUTLS_SSL3: SSL version 3.0.
 * @GNUTLS_TLS1_0: TLS version 1.0.
 * @GNUTLS_TLS1: Same as %GNUTLS_TLS1_0.
 * @GNUTLS_TLS1_1: TLS version 1.1.
 * @GNUTLS_TLS1_2: TLS version 1.2.
 * @GNUTLS_DTLS1_0: DTLS version 1.0.
 * @GNUTLS_DTLS1_2: DTLS version 1.2.
 * @GNUTLS_DTLS0_9: DTLS version 0.9 (Cisco AnyConnect / OpenSSL 0.9.8e).
 * @GNUTLS_VERSION_MAX: Maps to the highest supported TLS version.
 * @GNUTLS_VERSION_UNKNOWN: Unknown SSL/TLS version.
 *
 * Enumeration of different SSL/TLS protocol versions.
 */
alias gnutls_protocol_t = int;
enum : int {
  GNUTLS_SSL3 = 1,
  GNUTLS_TLS1_0 = 2,
  GNUTLS_TLS1 = GNUTLS_TLS1_0,
  GNUTLS_TLS1_1 = 3,
  GNUTLS_TLS1_2 = 4,

  GNUTLS_DTLS0_9 = 200,
  GNUTLS_DTLS1_0 = 201, /* 201 */
  GNUTLS_DTLS1_2 = 202,
  GNUTLS_DTLS_VERSION_MIN = GNUTLS_DTLS0_9,
  GNUTLS_DTLS_VERSION_MAX = GNUTLS_DTLS1_2,
  GNUTLS_TLS_VERSION_MAX = GNUTLS_TLS1_2,
  GNUTLS_VERSION_UNKNOWN = 0xff /* change it to 0xffff */
}

/**
 * gnutls_certificate_type_t:
 * @GNUTLS_CRT_UNKNOWN: Unknown certificate type.
 * @GNUTLS_CRT_X509: X.509 Certificate.
 * @GNUTLS_CRT_OPENPGP: OpenPGP certificate.
 * @GNUTLS_CRT_RAW: Raw public key (SubjectPublicKey)
 *
 * Enumeration of different certificate types.
 */
alias gnutls_certificate_type_t = int;
enum : int {
  GNUTLS_CRT_UNKNOWN = 0,
  GNUTLS_CRT_X509 = 1,
  GNUTLS_CRT_OPENPGP = 2,
  GNUTLS_CRT_RAW = 3
}

/**
 * gnutls_x509_crt_fmt_t:
 * @GNUTLS_X509_FMT_DER: X.509 certificate in DER format (binary).
 * @GNUTLS_X509_FMT_PEM: X.509 certificate in PEM format (text).
 *
 * Enumeration of different certificate encoding formats.
 */
alias gnutls_x509_crt_fmt_t = int;
enum : int {
  GNUTLS_X509_FMT_DER = 0,
  GNUTLS_X509_FMT_PEM = 1
}

/**
 * gnutls_certificate_print_formats_t:
 * @GNUTLS_CRT_PRINT_FULL: Full information about certificate.
 * @GNUTLS_CRT_PRINT_FULL_NUMBERS: Full information about certificate and include easy to parse public key parameters.
 * @GNUTLS_CRT_PRINT_COMPACT: Information about certificate name in one line, plus identification of the public key.
 * @GNUTLS_CRT_PRINT_ONELINE: Information about certificate in one line.
 * @GNUTLS_CRT_PRINT_UNSIGNED_FULL: All info for an unsigned certificate.
 *
 * Enumeration of different certificate printing variants.
 */
alias gnutls_certificate_print_formats = gnutls_certificate_print_formats_t;
alias gnutls_certificate_print_formats_t = int;
enum : int {
  GNUTLS_CRT_PRINT_FULL = 0,
  GNUTLS_CRT_PRINT_ONELINE = 1,
  GNUTLS_CRT_PRINT_UNSIGNED_FULL = 2,
  GNUTLS_CRT_PRINT_COMPACT = 3,
  GNUTLS_CRT_PRINT_FULL_NUMBERS = 4
}

enum GNUTLS_PK_ECC = GNUTLS_PK_EC;
/**
 * gnutls_pk_algorithm_t:
 * @GNUTLS_PK_UNKNOWN: Unknown public-key algorithm.
 * @GNUTLS_PK_RSA: RSA public-key algorithm.
 * @GNUTLS_PK_DSA: DSA public-key algorithm.
 * @GNUTLS_PK_DH: Diffie-Hellman algorithm. Used to generate parameters.
 * @GNUTLS_PK_EC: Elliptic curve algorithm. Used to generate parameters.
 *
 * Enumeration of different public-key algorithms.
 */
alias gnutls_pk_algorithm_t = int;
enum : int {
  GNUTLS_PK_UNKNOWN = 0,
  GNUTLS_PK_RSA = 1,
  GNUTLS_PK_DSA = 2,
  GNUTLS_PK_DH = 3,
  GNUTLS_PK_EC = 4
}

const(char)* gnutls_pk_algorithm_get_name(gnutls_pk_algorithm_t algorithm) @nogc;

/**
 * gnutls_sign_algorithm_t:
 * @GNUTLS_SIGN_UNKNOWN: Unknown signature algorithm.
 * @GNUTLS_SIGN_RSA_SHA1: Digital signature algorithm RSA with SHA-1
 * @GNUTLS_SIGN_RSA_SHA: Same as %GNUTLS_SIGN_RSA_SHA1.
 * @GNUTLS_SIGN_DSA_SHA1: Digital signature algorithm DSA with SHA-1
 * @GNUTLS_SIGN_DSA_SHA224: Digital signature algorithm DSA with SHA-224
 * @GNUTLS_SIGN_DSA_SHA256: Digital signature algorithm DSA with SHA-256
 * @GNUTLS_SIGN_DSA_SHA384: Digital signature algorithm DSA with SHA-384
 * @GNUTLS_SIGN_DSA_SHA512: Digital signature algorithm DSA with SHA-512
 * @GNUTLS_SIGN_DSA_SHA: Same as %GNUTLS_SIGN_DSA_SHA1.
 * @GNUTLS_SIGN_RSA_MD5: Digital signature algorithm RSA with MD5.
 * @GNUTLS_SIGN_RSA_MD2: Digital signature algorithm RSA with MD2.
 * @GNUTLS_SIGN_RSA_RMD160: Digital signature algorithm RSA with RMD-160.
 * @GNUTLS_SIGN_RSA_SHA256: Digital signature algorithm RSA with SHA-256.
 * @GNUTLS_SIGN_RSA_SHA384: Digital signature algorithm RSA with SHA-384.
 * @GNUTLS_SIGN_RSA_SHA512: Digital signature algorithm RSA with SHA-512.
 * @GNUTLS_SIGN_RSA_SHA224: Digital signature algorithm RSA with SHA-224.
 * @GNUTLS_SIGN_ECDSA_SHA1: ECDSA with SHA1.
 * @GNUTLS_SIGN_ECDSA_SHA256: Digital signature algorithm ECDSA with SHA-256.
 * @GNUTLS_SIGN_ECDSA_SHA384: Digital signature algorithm ECDSA with SHA-384.
 * @GNUTLS_SIGN_ECDSA_SHA512: Digital signature algorithm ECDSA with SHA-512.
 * @GNUTLS_SIGN_ECDSA_SHA224: Digital signature algorithm ECDSA with SHA-224.
 *
 * Enumeration of different digital signature algorithms.
 */
alias gnutls_sign_algorithm_t = int;
enum : int {
  GNUTLS_SIGN_UNKNOWN = 0,
  GNUTLS_SIGN_RSA_SHA1 = 1,
  GNUTLS_SIGN_RSA_SHA = GNUTLS_SIGN_RSA_SHA1,
  GNUTLS_SIGN_DSA_SHA1 = 2,
  GNUTLS_SIGN_DSA_SHA = GNUTLS_SIGN_DSA_SHA1,
  GNUTLS_SIGN_RSA_MD5 = 3,
  GNUTLS_SIGN_RSA_MD2 = 4,
  GNUTLS_SIGN_RSA_RMD160 = 5,
  GNUTLS_SIGN_RSA_SHA256 = 6,
  GNUTLS_SIGN_RSA_SHA384 = 7,
  GNUTLS_SIGN_RSA_SHA512 = 8,
  GNUTLS_SIGN_RSA_SHA224 = 9,
  GNUTLS_SIGN_DSA_SHA224 = 10,
  GNUTLS_SIGN_DSA_SHA256 = 11,
  GNUTLS_SIGN_ECDSA_SHA1 = 12,
  GNUTLS_SIGN_ECDSA_SHA224 = 13,
  GNUTLS_SIGN_ECDSA_SHA256 = 14,
  GNUTLS_SIGN_ECDSA_SHA384 = 15,
  GNUTLS_SIGN_ECDSA_SHA512 = 16,
  GNUTLS_SIGN_DSA_SHA384 = 17,
  GNUTLS_SIGN_DSA_SHA512 = 18
}

/**
 * gnutls_ecc_curve_t:
 * @GNUTLS_ECC_CURVE_INVALID: Cannot be known
 * @GNUTLS_ECC_CURVE_SECP192R1: the SECP192R1 curve
 * @GNUTLS_ECC_CURVE_SECP224R1: the SECP224R1 curve
 * @GNUTLS_ECC_CURVE_SECP256R1: the SECP256R1 curve
 * @GNUTLS_ECC_CURVE_SECP384R1: the SECP384R1 curve
 * @GNUTLS_ECC_CURVE_SECP521R1: the SECP521R1 curve
 *
 * Enumeration of ECC curves.
 */
alias gnutls_ecc_curve_t = int;
enum : int {
  GNUTLS_ECC_CURVE_INVALID = 0,
  GNUTLS_ECC_CURVE_SECP224R1,
  GNUTLS_ECC_CURVE_SECP256R1,
  GNUTLS_ECC_CURVE_SECP384R1,
  GNUTLS_ECC_CURVE_SECP521R1,
  GNUTLS_ECC_CURVE_SECP192R1
}

/* macros to allow specifying a specific curve in gnutls_privkey_generate()
 * and gnutls_x509_privkey_generate() */
uint GNUTLS_CURVE_TO_BITS() (uint curve) { return cast(uint)((1U<<31)|(cast(uint)(curve))); }
uint GNUTLS_BITS_TO_CURVE() (uint bits) { return ((cast(uint)(bits)) & 0x7FFFFFFFU); }
uint GNUTLS_BITS_ARE_CURVE() (uint bits) { return ((cast(uint)(bits)) & 0x80000000U); }

/**
 * gnutls_sec_param_t:
 * @GNUTLS_SEC_PARAM_UNKNOWN: Cannot be known
 * @GNUTLS_SEC_PARAM_INSECURE: Less than 42 bits of security
 * @GNUTLS_SEC_PARAM_EXPORT: 42 bits of security
 * @GNUTLS_SEC_PARAM_VERY_WEAK: 64 bits of security
 * @GNUTLS_SEC_PARAM_WEAK: 72 bits of security
 * @GNUTLS_SEC_PARAM_LOW: 80 bits of security
 * @GNUTLS_SEC_PARAM_LEGACY: 96 bits of security
 * @GNUTLS_SEC_PARAM_MEDIUM: 112 bits of security (used to be %GNUTLS_SEC_PARAM_NORMAL)
 * @GNUTLS_SEC_PARAM_HIGH: 128 bits of security
 * @GNUTLS_SEC_PARAM_ULTRA: 192 bits of security
 * @GNUTLS_SEC_PARAM_FUTURE: 256 bits of security
 *
 * Enumeration of security parameters for passive attacks.
 */
alias gnutls_sec_param_t = int;
enum : int {
  GNUTLS_SEC_PARAM_UNKNOWN = 0,
  GNUTLS_SEC_PARAM_INSECURE = 5,
  GNUTLS_SEC_PARAM_EXPORT = 10,
  GNUTLS_SEC_PARAM_VERY_WEAK = 15,
  GNUTLS_SEC_PARAM_WEAK = 20,
  GNUTLS_SEC_PARAM_LOW = 25,
  GNUTLS_SEC_PARAM_LEGACY = 30,
  GNUTLS_SEC_PARAM_MEDIUM = 35,
  GNUTLS_SEC_PARAM_HIGH = 40,
  GNUTLS_SEC_PARAM_ULTRA = 45,
  GNUTLS_SEC_PARAM_FUTURE = 50
}

/* old name */
enum GNUTLS_SEC_PARAM_NORMAL = GNUTLS_SEC_PARAM_MEDIUM;

/**
 * gnutls_channel_binding_t:
 * @GNUTLS_CB_TLS_UNIQUE: "tls-unique" (RFC 5929) channel binding
 *
 * Enumeration of support channel binding types.
 */
alias gnutls_channel_binding_t = int;
enum : int {
  GNUTLS_CB_TLS_UNIQUE
}


/* If you want to change this, then also change the define in
 * gnutls_int.h, and recompile.
 */
struct gnutls_transport_ptr_t_s {}
alias gnutls_transport_ptr_t = gnutls_transport_ptr_t_s*;

struct gnutls_session_int {}
alias gnutls_session_t = gnutls_session_int*;

struct gnutls_dh_params_int {}
alias gnutls_dh_params_t = gnutls_dh_params_int*;

  /* XXX ugly. */
struct gnutls_x509_privkey_int {}
alias gnutls_rsa_params_t = gnutls_x509_privkey_int*;

struct gnutls_priority_st {}
alias gnutls_priority_t = gnutls_priority_st*;

struct gnutls_datum_t {
  ubyte* data;
  uint size;
}


union gnutls_params_st_params_union {
  gnutls_dh_params_t dh;
  gnutls_rsa_params_t rsa_export;
}

struct gnutls_params_st {
  gnutls_params_type_t type;
  gnutls_params_st_params_union params;
  int deinit;
}

//alias gnutls_params_function = int function (gnutls_session_t, gnutls_params_type_t, gnutls_params_st *) @nogc;

/* internal functions */

int gnutls_init(gnutls_session_t * session, uint flags) @nogc;
void gnutls_deinit(gnutls_session_t session) @nogc;
//#define _gnutls_deinit(x) gnutls_deinit(x)

int gnutls_bye(gnutls_session_t session, gnutls_close_request_t how) @nogc;

int gnutls_handshake(gnutls_session_t session) @nogc;

enum GNUTLS_DEFAULT_HANDSHAKE_TIMEOUT = (cast(uint)-1);
void gnutls_handshake_set_timeout(gnutls_session_t session,
          uint ms) @nogc;
int gnutls_rehandshake(gnutls_session_t session) @nogc;

gnutls_alert_description_t gnutls_alert_get(gnutls_session_t session) @nogc;
int gnutls_alert_send(gnutls_session_t session,
          gnutls_alert_level_t level,
          gnutls_alert_description_t desc) @nogc;
int gnutls_alert_send_appropriate(gnutls_session_t session, int err) @nogc;
const(char)* gnutls_alert_get_name(gnutls_alert_description_t alert) @nogc;
const(char)* gnutls_alert_get_strname(gnutls_alert_description_t alert) @nogc;

gnutls_sec_param_t gnutls_pk_bits_to_sec_param(gnutls_pk_algorithm_t algo,
                 uint bits) @nogc;
const(char)* gnutls_sec_param_get_name(gnutls_sec_param_t param) @nogc;
uint gnutls_sec_param_to_pk_bits(gnutls_pk_algorithm_t algo,
           gnutls_sec_param_t param) @nogc;
uint
gnutls_sec_param_to_symmetric_bits(gnutls_sec_param_t param) @nogc;

/* Elliptic curves */
const(char)* gnutls_ecc_curve_get_name(gnutls_ecc_curve_t curve) @nogc;
const(char)* gnutls_ecc_curve_get_oid(gnutls_ecc_curve_t curve) @nogc;

int gnutls_ecc_curve_get_size(gnutls_ecc_curve_t curve) @nogc;
gnutls_ecc_curve_t gnutls_ecc_curve_get(gnutls_session_t session) @nogc;

/* get information on the current session */
gnutls_cipher_algorithm_t gnutls_cipher_get(gnutls_session_t session) @nogc;
gnutls_kx_algorithm_t gnutls_kx_get(gnutls_session_t session) @nogc;
gnutls_mac_algorithm_t gnutls_mac_get(gnutls_session_t session) @nogc;
gnutls_compression_method_t
gnutls_compression_get(gnutls_session_t session) @nogc;
gnutls_certificate_type_t
gnutls_certificate_type_get(gnutls_session_t session) @nogc;

int gnutls_sign_algorithm_get(gnutls_session_t session) @nogc;
int gnutls_sign_algorithm_get_client(gnutls_session_t session) @nogc;

int gnutls_sign_algorithm_get_requested(gnutls_session_t session,
          usize indx,
          gnutls_sign_algorithm_t * algo) @nogc;

/* the name of the specified algorithms */
const(char)* gnutls_cipher_get_name(gnutls_cipher_algorithm_t algorithm) @nogc;
const(char)* gnutls_mac_get_name(gnutls_mac_algorithm_t algorithm) @nogc;

const(char)* gnutls_digest_get_name(gnutls_digest_algorithm_t algorithm) @nogc;
const(char)* gnutls_digest_get_oid(gnutls_digest_algorithm_t algorithm) @nogc;

const(char)* gnutls_compression_get_name(gnutls_compression_method_t
          algorithm) @nogc;
const(char)* gnutls_kx_get_name(gnutls_kx_algorithm_t algorithm) @nogc;
const(char)* gnutls_certificate_type_get_name(gnutls_certificate_type_t
               type) @nogc;
const(char)* gnutls_pk_get_name(gnutls_pk_algorithm_t algorithm) @nogc;
const(char)* gnutls_pk_get_oid(gnutls_pk_algorithm_t algorithm) @nogc;

const(char)* gnutls_sign_get_name(gnutls_sign_algorithm_t algorithm) @nogc;
const(char)* gnutls_sign_get_oid(gnutls_sign_algorithm_t algorithm) @nogc;

usize gnutls_cipher_get_key_size(gnutls_cipher_algorithm_t algorithm) @nogc;
usize gnutls_mac_get_key_size(gnutls_mac_algorithm_t algorithm) @nogc;

int gnutls_sign_is_secure(gnutls_sign_algorithm_t algorithm) @nogc;
gnutls_digest_algorithm_t
gnutls_sign_get_hash_algorithm(gnutls_sign_algorithm_t sign) @nogc;
gnutls_pk_algorithm_t
gnutls_sign_get_pk_algorithm(gnutls_sign_algorithm_t sign) @nogc;
gnutls_sign_algorithm_t
gnutls_pk_to_sign(gnutls_pk_algorithm_t pk,
      gnutls_digest_algorithm_t hash) @nogc;

//#define gnutls_sign_algorithm_get_name gnutls_sign_get_name
alias gnutls_sign_algorithm_get_name = gnutls_sign_get_name;

gnutls_mac_algorithm_t gnutls_mac_get_id(const(char)* name) @nogc;
gnutls_digest_algorithm_t gnutls_digest_get_id(const(char)* name) @nogc;

gnutls_compression_method_t gnutls_compression_get_id(const(char)* name) @nogc;
gnutls_cipher_algorithm_t gnutls_cipher_get_id(const(char)* name) @nogc;
gnutls_kx_algorithm_t gnutls_kx_get_id(const(char)* name) @nogc;
gnutls_protocol_t gnutls_protocol_get_id(const(char)* name) @nogc;
gnutls_certificate_type_t gnutls_certificate_type_get_id(const(char)* name) @nogc;
gnutls_pk_algorithm_t gnutls_pk_get_id(const(char)* name) @nogc;
gnutls_sign_algorithm_t gnutls_sign_get_id(const(char)* name) @nogc;
gnutls_ecc_curve_t gnutls_ecc_curve_get_id(const(char)* name) @nogc;

gnutls_digest_algorithm_t gnutls_oid_to_digest(const(char)* oid) @nogc;
gnutls_pk_algorithm_t gnutls_oid_to_pk(const(char)* oid) @nogc;
gnutls_sign_algorithm_t gnutls_oid_to_sign(const(char)* oid) @nogc;
gnutls_ecc_curve_t gnutls_oid_to_ecc_curve(const(char)* oid) @nogc;

  /* list supported algorithms */
const(gnutls_ecc_curve_t)* gnutls_ecc_curve_list() @nogc;
const(gnutls_cipher_algorithm_t)* gnutls_cipher_list() @nogc;
const(gnutls_mac_algorithm_t)* gnutls_mac_list() @nogc;
const(gnutls_digest_algorithm_t)* gnutls_digest_list() @nogc;
const(gnutls_compression_method_t)* gnutls_compression_list() @nogc;
const(gnutls_protocol_t)* gnutls_protocol_list() @nogc;
const(gnutls_certificate_type_t)* gnutls_certificate_type_list() @nogc;
const(gnutls_kx_algorithm_t)* gnutls_kx_list() @nogc;
const(gnutls_pk_algorithm_t)* gnutls_pk_list() @nogc;
const(gnutls_sign_algorithm_t)* gnutls_sign_list() @nogc;
const(char)* gnutls_cipher_suite_info(usize idx,
             ubyte *cs_id,
             gnutls_kx_algorithm_t * kx,
             gnutls_cipher_algorithm_t * cipher,
             gnutls_mac_algorithm_t * mac,
             gnutls_protocol_t * min_version) @nogc;

  /* error functions */
int gnutls_error_is_fatal(int error) @nogc;
int gnutls_error_to_alert(int err, int *level) @nogc;

void gnutls_perror(int error) @nogc;
const(char)* gnutls_strerror(int error) @nogc;
const(char)* gnutls_strerror_name(int error) @nogc;

/* Semi-internal functions.
 */
void gnutls_handshake_set_private_extensions(gnutls_session_t session,
               int allow) @nogc;
int gnutls_handshake_set_random(gnutls_session_t session,
        const(gnutls_datum_t)* random) @nogc;

gnutls_handshake_description_t
gnutls_handshake_get_last_out(gnutls_session_t session) @nogc;
gnutls_handshake_description_t
gnutls_handshake_get_last_in(gnutls_session_t session) @nogc;

/* Record layer functions.
 */
enum GNUTLS_HEARTBEAT_WAIT = 1;
int gnutls_heartbeat_ping(gnutls_session_t session, usize data_size,
        uint max_tries, uint flags) @nogc;
int gnutls_heartbeat_pong(gnutls_session_t session, uint flags) @nogc;

void gnutls_record_set_timeout(gnutls_session_t session, uint ms) @nogc;
void gnutls_record_disable_padding(gnutls_session_t session) @nogc;

void gnutls_record_cork(gnutls_session_t session) @nogc;
enum GNUTLS_RECORD_WAIT = 1;
int gnutls_record_uncork(gnutls_session_t session, uint flags) @nogc;
usize gnutls_record_discard_queued(gnutls_session_t session) @nogc;

int
gnutls_record_get_state(gnutls_session_t session,
      uint read,
      gnutls_datum_t *mac_key,
      gnutls_datum_t *IV,
      gnutls_datum_t *cipher_key,
      ubyte* seq_number/*[8]*/) @nogc;

int
gnutls_record_set_state(gnutls_session_t session,
      uint read,
      ubyte* seq_number/*[8]*/) @nogc;

struct gnutls_range_st {
  usize low;
  usize high;
}

int gnutls_range_split(gnutls_session_t session,
           const(gnutls_range_st)* orig,
           gnutls_range_st * small_range,
           gnutls_range_st * rem_range) @nogc;

ssize gnutls_record_send(gnutls_session_t session, const(void)* data,
         usize data_size) @nogc;
ssize gnutls_record_send_range(gnutls_session_t session,
         const(void)* data, usize data_size,
         const(gnutls_range_st)* range) @nogc;
ssize gnutls_record_recv(gnutls_session_t session, void *data,
         usize data_size) @nogc;

struct mbuffer_st;
alias gnutls_packet_t = mbuffer_st*;

ssize
gnutls_record_recv_packet(gnutls_session_t session,
          gnutls_packet_t *packet) @nogc;

void gnutls_packet_get(gnutls_packet_t packet, gnutls_datum_t *data, ubyte *sequence) @nogc;
void gnutls_packet_deinit(gnutls_packet_t packet) @nogc;

alias gnutls_read = gnutls_record_recv;
alias gnutls_write = gnutls_record_send;
ssize gnutls_record_recv_seq(gnutls_session_t session, void *data,
             usize data_size, ubyte *seq) @nogc;

usize gnutls_record_overhead_size(gnutls_session_t session) @nogc;

usize gnutls_est_record_overhead_size(gnutls_protocol_t version_,
               gnutls_cipher_algorithm_t cipher,
               gnutls_mac_algorithm_t mac,
               gnutls_compression_method_t comp,
               uint flags) @nogc;

void gnutls_session_enable_compatibility_mode(gnutls_session_t session) @nogc;
//???#define gnutls_record_set_max_empty_records(session, x)
void gnutls_record_set_max_empty_records(gnutls_session_t session, int x) {}

int gnutls_record_can_use_length_hiding(gnutls_session_t session) @nogc;

int gnutls_record_get_direction(gnutls_session_t session) @nogc;

usize gnutls_record_get_max_size(gnutls_session_t session) @nogc;
ssize gnutls_record_set_max_size(gnutls_session_t session, usize size) @nogc;

usize gnutls_record_check_pending(gnutls_session_t session) @nogc;
usize gnutls_record_check_corked(gnutls_session_t session) @nogc;

void gnutls_session_force_valid(gnutls_session_t session) @nogc;

int gnutls_prf(gnutls_session_t session,
         usize label_size, const(char)* label,
         int server_random_first,
         usize extra_size, const(char)* extra,
         usize outsize, char *out_) @nogc;
int gnutls_prf_rfc5705(gnutls_session_t session,
         usize label_size, const(char)* label,
         usize context_size, const(char)* context,
         usize outsize, char *out_) @nogc;

int gnutls_prf_raw(gnutls_session_t session,
       usize label_size, const(char)* label,
       usize seed_size, const(char)* seed,
       usize outsize, char *out_) @nogc;

/**
 * gnutls_server_name_type_t:
 * @GNUTLS_NAME_DNS: Domain Name System name type.
 *
 * Enumeration of different server name types.
 */
alias gnutls_server_name_type_t = int;
enum : int {
  GNUTLS_NAME_DNS = 1
}

int gnutls_server_name_set(gnutls_session_t session,
         gnutls_server_name_type_t type,
         const(void)* name, usize name_length) @nogc;

int gnutls_server_name_get(gnutls_session_t session,
         void *data, usize * data_length,
         uint *type, uint indx) @nogc;

uint gnutls_heartbeat_get_timeout(gnutls_session_t session) @nogc;
void gnutls_heartbeat_set_timeouts(gnutls_session_t session,
           uint retrans_timeout,
           uint total_timeout) @nogc;

enum GNUTLS_HB_PEER_ALLOWED_TO_SEND = (1);
enum GNUTLS_HB_PEER_NOT_ALLOWED_TO_SEND = (1<<1);

  /* Heartbeat */
void gnutls_heartbeat_enable(gnutls_session_t session, uint type) @nogc;

enum GNUTLS_HB_LOCAL_ALLOWED_TO_SEND = (1<<2);
int gnutls_heartbeat_allowed(gnutls_session_t session, uint type) @nogc;

  /* Safe renegotiation */
int gnutls_safe_renegotiation_status(gnutls_session_t session) @nogc;
uint gnutls_session_ext_master_secret_status(gnutls_session_t session) @nogc;
uint gnutls_session_etm_status(gnutls_session_t session) @nogc;

/**
 * gnutls_supplemental_data_format_type_t:
 * @GNUTLS_SUPPLEMENTAL_UNKNOWN: Unknown data format
 *
 * Enumeration of different supplemental data types (RFC 4680).
 */
alias gnutls_supplemental_data_format_type_t = int;
enum : int {
  GNUTLS_SUPPLEMENTAL_UNKNOWN = 0,
}

const(char)* gnutls_supplemental_get_name(gnutls_supplemental_data_format_type_t type) @nogc;

  /* SessionTicket, RFC 5077. */
int gnutls_session_ticket_key_generate(gnutls_datum_t * key) @nogc;
int gnutls_session_ticket_enable_client(gnutls_session_t session) @nogc;
int gnutls_session_ticket_enable_server(gnutls_session_t session,
          const(gnutls_datum_t)* key) @nogc;

  /* SRTP, RFC 5764 */

/**
 * gnutls_srtp_profile_t:
 * @GNUTLS_SRTP_AES128_CM_HMAC_SHA1_80: 128 bit AES with a 80 bit HMAC-SHA1
 * @GNUTLS_SRTP_AES128_CM_HMAC_SHA1_32: 128 bit AES with a 32 bit HMAC-SHA1
 * @GNUTLS_SRTP_NULL_HMAC_SHA1_80: NULL cipher with a 80 bit HMAC-SHA1
 * @GNUTLS_SRTP_NULL_HMAC_SHA1_32: NULL cipher with a 32 bit HMAC-SHA1
 *
 * Enumeration of different SRTP protection profiles.
 */
alias gnutls_srtp_profile_t = int;
enum : int {
  GNUTLS_SRTP_AES128_CM_HMAC_SHA1_80 = 0x0001,
  GNUTLS_SRTP_AES128_CM_HMAC_SHA1_32 = 0x0002,
  GNUTLS_SRTP_NULL_HMAC_SHA1_80 = 0x0005,
  GNUTLS_SRTP_NULL_HMAC_SHA1_32 = 0x0006
}

int gnutls_srtp_set_profile(gnutls_session_t session,
          gnutls_srtp_profile_t profile) @nogc;
int gnutls_srtp_set_profile_direct(gnutls_session_t session,
           const(char)* profiles,
           const(char)* *err_pos) @nogc;
int gnutls_srtp_get_selected_profile(gnutls_session_t session,
             gnutls_srtp_profile_t * profile) @nogc;

const(char)* gnutls_srtp_get_profile_name(gnutls_srtp_profile_t profile) @nogc;
int gnutls_srtp_get_profile_id(const(char)* name,
             gnutls_srtp_profile_t * profile) @nogc;
int gnutls_srtp_get_keys(gnutls_session_t session,
       void *key_material,
       uint key_material_size,
       gnutls_datum_t * client_key,
       gnutls_datum_t * client_salt,
       gnutls_datum_t * server_key,
       gnutls_datum_t * server_salt) @nogc;

int gnutls_srtp_set_mki(gnutls_session_t session,
      const(gnutls_datum_t)* mki) @nogc;
int gnutls_srtp_get_mki(gnutls_session_t session, gnutls_datum_t * mki) @nogc;

/* ALPN TLS extension */
enum GNUTLS_ALPN_MAND = 1;
int gnutls_alpn_get_selected_protocol(gnutls_session_t session,
              gnutls_datum_t * protocol) @nogc;
int gnutls_alpn_set_protocols(gnutls_session_t session,
            const(gnutls_datum_t)* protocols,
            uint protocols_size, uint flags) @nogc;

int gnutls_key_generate(gnutls_datum_t * key, uint key_size) @nogc;

/* if you just want some defaults, use the following.
 */

int gnutls_priority_init(gnutls_priority_t * priority_cache,
       const(char)* priorities, const(char)* *err_pos) @nogc;
void gnutls_priority_deinit(gnutls_priority_t priority_cache) @nogc;
int gnutls_priority_get_cipher_suite_index(gnutls_priority_t pcache,
             uint idx,
             uint *sidx) @nogc;

enum GNUTLS_PRIORITY_LIST_INIT_KEYWORDS = 1;
enum GNUTLS_PRIORITY_LIST_SPECIAL = 2;
const(char)*
gnutls_priority_string_list(uint iter, uint flags) @nogc;

int gnutls_priority_set(gnutls_session_t session,
      gnutls_priority_t priority) @nogc;
int gnutls_priority_set_direct(gnutls_session_t session,
             const(char)* priorities,
             const(char)* *err_pos) @nogc;

int gnutls_priority_certificate_type_list(gnutls_priority_t pcache,
            const(uint)* *list) @nogc;
int gnutls_priority_sign_list(gnutls_priority_t pcache,
            const(uint)* *list) @nogc;
int gnutls_priority_protocol_list(gnutls_priority_t pcache,
          const(uint)* *list) @nogc;
int gnutls_priority_compression_list(gnutls_priority_t pcache,
             const(uint)* *list) @nogc;
int gnutls_priority_ecc_curve_list(gnutls_priority_t pcache,
           const(uint)* *list) @nogc;

int gnutls_priority_kx_list(gnutls_priority_t pcache,
          const(uint)* *list) @nogc;
int gnutls_priority_cipher_list(gnutls_priority_t pcache,
        const(uint)* *list) @nogc;
int gnutls_priority_mac_list(gnutls_priority_t pcache,
           const(uint)* *list) @nogc;

  /* for compatibility
   */
int gnutls_set_default_priority(gnutls_session_t session) @nogc;

/* Returns the name of a cipher suite */
const(char)* gnutls_cipher_suite_get_name(gnutls_kx_algorithm_t
           kx_algorithm,
           gnutls_cipher_algorithm_t
           cipher_algorithm,
           gnutls_mac_algorithm_t
           mac_algorithm) @nogc;

/* get the currently used protocol version */
gnutls_protocol_t gnutls_protocol_get_version(gnutls_session_t session) @nogc;

const(char)* gnutls_protocol_get_name(gnutls_protocol_t version_) @nogc;


/* get/set session
 */
int gnutls_session_set_data(gnutls_session_t session,
          const(void)* session_data,
          usize session_data_size) @nogc;
int gnutls_session_get_data(gnutls_session_t session, void *session_data,
          usize * session_data_size) @nogc;
int gnutls_session_get_data2(gnutls_session_t session,
           gnutls_datum_t * data) @nogc;
void gnutls_session_get_random(gnutls_session_t session,
             gnutls_datum_t * client,
             gnutls_datum_t * server) @nogc;
char *gnutls_session_get_desc(gnutls_session_t session) @nogc;

//alias gnutls_certificate_verify_function = int function (gnutls_session_t) @nogc;
void gnutls_session_set_verify_function(gnutls_session_t session, gnutls_certificate_verify_function func) /*@nogc*/;

/**
 * gnutls_vdata_types_t:
 * @GNUTLS_DT_UNKNOWN: Unknown data type.
 * @GNUTLS_DT_DNS_HOSTNAME: The data contain a null-terminated DNS hostname; the hostname will be
 *   matched using the RFC6125 rules.
 * @GNUTLS_DT_RFC822NAME: The data contain a null-terminated email address; the email will be
 *   matched against the RFC822Name field of the certificate, or the EMAIL DN component if the
 *   former isn't available. Prior to matching the email address will be converted to ACE
 *   (ASCII-compatible-encoding).
 * @GNUTLS_DT_KEY_PURPOSE_OID: The data contain a null-terminated key purpose OID. It will be matched
 *   against the certificate's Extended Key Usage extension.
 *
 * Enumeration of different typed-data options. They are used as input to certificate
 * verification functions to provide information about the name and purpose of the
 * certificate. Only a single option of a type can be provided to the relevant functions.
 */
alias gnutls_vdata_types_t = int;
enum : int {
  GNUTLS_DT_UNKNOWN = 0,
  GNUTLS_DT_DNS_HOSTNAME = 1,
  GNUTLS_DT_KEY_PURPOSE_OID = 2,
  GNUTLS_DT_RFC822NAME = 3
}


struct gnutls_typed_vdata_st {
  gnutls_vdata_types_t type;
  ubyte *data;
  uint size;
}

void gnutls_session_set_verify_cert(gnutls_session_t session,
             const(char)* hostname, uint flags) @nogc;

void
gnutls_session_set_verify_cert2(gnutls_session_t session,
        gnutls_typed_vdata_st * data,
        uint elements, uint flags) @nogc;

uint gnutls_session_get_verify_cert_status(gnutls_session_t) @nogc;

int gnutls_session_set_premaster(gnutls_session_t session,
         uint entity,
         gnutls_protocol_t version_,
         gnutls_kx_algorithm_t kx,
         gnutls_cipher_algorithm_t cipher,
         gnutls_mac_algorithm_t mac,
         gnutls_compression_method_t comp,
         const(gnutls_datum_t)* master,
         const(gnutls_datum_t)* session_id) @nogc;

/* returns the session ID */
enum GNUTLS_MAX_SESSION_ID = 32;
int gnutls_session_get_id(gnutls_session_t session, void *session_id,
        usize * session_id_size) @nogc;
int gnutls_session_get_id2(gnutls_session_t session,
         gnutls_datum_t * session_id) @nogc;

int gnutls_session_set_id(gnutls_session_t session,
        const(gnutls_datum_t)* sid) @nogc;

int gnutls_session_channel_binding(gnutls_session_t session,
           gnutls_channel_binding_t cbtype,
           gnutls_datum_t * cb) @nogc;

/* checks if this session is a resumed one
 */
int gnutls_session_is_resumed(gnutls_session_t session) @nogc;
int gnutls_session_resumption_requested(gnutls_session_t session) @nogc;

//alias gnutls_db_store_func = int function (void *, gnutls_datum_t key, gnutls_datum_t data) @nogc;
//alias gnutls_db_remove_func = int function (void *, gnutls_datum_t key) @nogc;
//alias gnutls_db_retr_func = gnutls_datum_t function (void *, gnutls_datum_t key) @nogc;

void gnutls_db_set_cache_expiration(gnutls_session_t session, int seconds) @nogc;
uint gnutls_db_get_default_cache_expiration() @nogc;

void gnutls_db_remove_session(gnutls_session_t session) @nogc;
void gnutls_db_set_retrieve_function(gnutls_session_t session,
             gnutls_db_retr_func retr_func) /*@nogc*/;
void gnutls_db_set_remove_function(gnutls_session_t session,
           gnutls_db_remove_func rem_func) /*@nogc*/;
void gnutls_db_set_store_function(gnutls_session_t session,
          gnutls_db_store_func store_func) /*@nogc*/;
void gnutls_db_set_ptr(gnutls_session_t session, void *ptr) @nogc;
void *gnutls_db_get_ptr(gnutls_session_t session) @nogc;
int gnutls_db_check_entry(gnutls_session_t session,
        gnutls_datum_t session_entry) @nogc;
time_t gnutls_db_check_entry_time(gnutls_datum_t * entry) @nogc;

  /**
   * gnutls_handshake_hook_func:
   * @session: the current session
   * @htype: the type of the handshake message (%gnutls_handshake_description_t)
   * @post: non zero if this is a post-process/generation call and zero otherwise
   * @incoming: non zero if this is an incoming message and zero if this is an outgoing message
   * @msg: the (const) data of the handshake message without the handshake headers.
   *
   * Function prototype for handshake hooks. It is set using
   * gnutls_handshake_set_hook_function().
   *
   * Returns: Non zero on error.
   */
enum GNUTLS_HOOK_POST = (1);
enum GNUTLS_HOOK_PRE = (0);
enum GNUTLS_HOOK_BOTH = (-1);

//alias gnutls_handshake_hook_func = int function (gnutls_session_t, uint htype, uint post, uint incoming, const(gnutls_datum_t)* msg) @nogc;
void gnutls_handshake_set_hook_function(gnutls_session_t session,
          uint htype, int post,
          gnutls_handshake_hook_func func) /*@nogc*/;

//alias gnutls_handshake_post_client_hello_func = int function (gnutls_session_t) @nogc;
void
gnutls_handshake_set_post_client_hello_function(gnutls_session_t session,
            gnutls_handshake_post_client_hello_func
            func) /*@nogc*/;

void gnutls_handshake_set_max_packet_length(gnutls_session_t session,
              usize max) @nogc;

/* returns libgnutls version (call it with a NULL argument)
 */
const(char)* gnutls_check_version(const(char)* req_version) @nogc;

/* Functions for setting/clearing credentials
 */
void gnutls_credentials_clear(gnutls_session_t session) @nogc;

/* cred is a structure defined by the kx algorithm
 */
int gnutls_credentials_set(gnutls_session_t session,
         gnutls_credentials_type_t type, void *cred) @nogc;
int gnutls_credentials_get(gnutls_session_t session,
         gnutls_credentials_type_t type, void **cred) @nogc;
alias gnutls_cred_set = gnutls_credentials_set;

/* x.509 types */

struct gnutls_pubkey_st {}
alias gnutls_pubkey_t = gnutls_pubkey_st*;

struct gnutls_privkey_st {}
alias gnutls_privkey_t = gnutls_privkey_st*;

//struct gnutls_x509_privkey_int {}
alias gnutls_x509_privkey_t = gnutls_x509_privkey_int*;

struct gnutls_x509_crl_int {}
alias gnutls_x509_crl_t = gnutls_x509_crl_int*;

struct gnutls_x509_crt_int {}
alias gnutls_x509_crt_t = gnutls_x509_crt_int*;

struct gnutls_x509_crq_int {}
alias gnutls_x509_crq_t = gnutls_x509_crq_int*;

struct gnutls_openpgp_keyring_int {}
alias gnutls_openpgp_keyring_t = gnutls_openpgp_keyring_int*;


/* Credential structures - used in gnutls_credentials_set() @nogc; */

struct gnutls_certificate_credentials_st {}
alias gnutls_certificate_credentials_t = gnutls_certificate_credentials_st*;
alias gnutls_certificate_server_credentials = gnutls_certificate_credentials_t;
alias gnutls_certificate_client_credentials = gnutls_certificate_credentials_t;

struct gnutls_anon_server_credentials_st {}
struct gnutls_anon_client_credentials_st {}
alias gnutls_anon_server_credentials_t = gnutls_anon_server_credentials_st*;
alias gnutls_anon_client_credentials_t = gnutls_anon_client_credentials_st*;

void gnutls_anon_free_server_credentials(gnutls_anon_server_credentials_t
           sc) @nogc;
int
gnutls_anon_allocate_server_credentials(gnutls_anon_server_credentials_t
          * sc) @nogc;

void gnutls_anon_set_server_dh_params(gnutls_anon_server_credentials_t res,
              gnutls_dh_params_t dh_params) @nogc;

void
gnutls_anon_set_server_params_function(gnutls_anon_server_credentials_t
               res, gnutls_params_function func) /*@nogc*/;

void
gnutls_anon_free_client_credentials(gnutls_anon_client_credentials_t sc) @nogc;
int
gnutls_anon_allocate_client_credentials(gnutls_anon_client_credentials_t
          * sc) @nogc;

/* CERTFILE is an x509 certificate in PEM form.
 * KEYFILE is a pkcs-1 private key in PEM form (for RSA keys).
 */
void
gnutls_certificate_free_credentials(gnutls_certificate_credentials_t sc) @nogc;
int
gnutls_certificate_allocate_credentials(gnutls_certificate_credentials_t
          * res) @nogc;

int
gnutls_certificate_get_issuer(gnutls_certificate_credentials_t sc,
            gnutls_x509_crt_t cert,
            gnutls_x509_crt_t * issuer,
            uint flags) @nogc;

int gnutls_certificate_get_crt_raw(gnutls_certificate_credentials_t sc,
           uint idx1, uint idx2,
           gnutls_datum_t * cert) @nogc;

int
gnutls_certificate_get_x509_crt(gnutls_certificate_credentials_t res,
                                uint index,
                                gnutls_x509_crt_t **crt_list,
                                uint *crt_list_size) @nogc;

int
gnutls_certificate_get_x509_key(gnutls_certificate_credentials_t res,
                                uint index,
                                gnutls_x509_privkey_t *key) @nogc;

void gnutls_certificate_free_keys(gnutls_certificate_credentials_t sc) @nogc;
void gnutls_certificate_free_cas(gnutls_certificate_credentials_t sc) @nogc;
void gnutls_certificate_free_ca_names(gnutls_certificate_credentials_t sc) @nogc;
void gnutls_certificate_free_crls(gnutls_certificate_credentials_t sc) @nogc;

void gnutls_certificate_set_dh_params(gnutls_certificate_credentials_t res,
              gnutls_dh_params_t dh_params) @nogc;
void gnutls_certificate_set_verify_flags(gnutls_certificate_credentials_t
           res, uint flags) @nogc;
uint
gnutls_certificate_get_verify_flags(gnutls_certificate_credentials_t res) @nogc;

/**
 * gnutls_certificate_flags:
 * @GNUTLS_CERTIFICATE_SKIP_KEY_CERT_MATCH: Skip the key and certificate matching check.
 *
 * Enumeration of different certificate credentials flags.
 */
alias gnutls_certificate_flags = int;
enum : int {
  GNUTLS_CERTIFICATE_SKIP_KEY_CERT_MATCH = 1
}

void gnutls_certificate_set_flags(gnutls_certificate_credentials_t,
          uint flags) @nogc;

void gnutls_certificate_set_verify_limits(gnutls_certificate_credentials_t
            res, uint max_bits,
            uint max_depth) @nogc;

uint
gnutls_certificate_get_verify_flags(gnutls_certificate_credentials_t) @nogc;

int
gnutls_certificate_set_x509_system_trust(gnutls_certificate_credentials_t
           cred) @nogc;

int
gnutls_certificate_set_x509_trust_file(gnutls_certificate_credentials_t
               cred, const(char)* cafile,
               gnutls_x509_crt_fmt_t type) @nogc;
int
gnutls_certificate_set_x509_trust_dir(gnutls_certificate_credentials_t cred,
              const(char)* ca_dir,
              gnutls_x509_crt_fmt_t type) @nogc;

int gnutls_certificate_set_x509_trust_mem(gnutls_certificate_credentials_t
            res, const(gnutls_datum_t)* ca,
            gnutls_x509_crt_fmt_t type) @nogc;

int
gnutls_certificate_set_x509_crl_file(gnutls_certificate_credentials_t
             res, const(char)* crlfile,
             gnutls_x509_crt_fmt_t type) @nogc;
int gnutls_certificate_set_x509_crl_mem(gnutls_certificate_credentials_t
          res, const(gnutls_datum_t)* CRL,
          gnutls_x509_crt_fmt_t type) @nogc;

int
gnutls_certificate_set_x509_key_file(gnutls_certificate_credentials_t
             res, const(char)* certfile,
             const(char)* keyfile,
             gnutls_x509_crt_fmt_t type) @nogc;

int
gnutls_certificate_set_x509_key_file2(gnutls_certificate_credentials_t
              res, const(char)* certfile,
              const(char)* keyfile,
              gnutls_x509_crt_fmt_t type,
              const(char)* pass,
              uint flags) @nogc;

int gnutls_certificate_set_x509_key_mem(gnutls_certificate_credentials_t
          res, const(gnutls_datum_t)* cert,
          const(gnutls_datum_t)* key,
          gnutls_x509_crt_fmt_t type) @nogc;

int gnutls_certificate_set_x509_key_mem2(gnutls_certificate_credentials_t
           res, const(gnutls_datum_t)* cert,
           const(gnutls_datum_t)* key,
           gnutls_x509_crt_fmt_t type,
           const(char)* pass,
           uint flags) @nogc;

void gnutls_certificate_send_x509_rdn_sequence(gnutls_session_t session,
                 int status) @nogc;

int
gnutls_certificate_set_x509_simple_pkcs12_file
(gnutls_certificate_credentials_t res, const(char)* pkcs12file,
 gnutls_x509_crt_fmt_t type, const(char)* password) @nogc;
int
gnutls_certificate_set_x509_simple_pkcs12_mem
(gnutls_certificate_credentials_t res, const(gnutls_datum_t)* p12blob,
 gnutls_x509_crt_fmt_t type, const(char)* password) @nogc;

/* New functions to allow setting already parsed X.509 stuff.
 */

int gnutls_certificate_set_x509_key(gnutls_certificate_credentials_t res,
            gnutls_x509_crt_t * cert_list,
            int cert_list_size,
            gnutls_x509_privkey_t key) @nogc;
int gnutls_certificate_set_x509_trust(gnutls_certificate_credentials_t res,
              gnutls_x509_crt_t * ca_list,
              int ca_list_size) @nogc;
int gnutls_certificate_set_x509_crl(gnutls_certificate_credentials_t res,
            gnutls_x509_crl_t * crl_list,
            int crl_list_size) @nogc;

int gnutls_certificate_get_x509_key(gnutls_certificate_credentials_t res,
                                    uint index,
                                    gnutls_x509_privkey_t *key) @nogc;
int gnutls_certificate_get_x509_crt(gnutls_certificate_credentials_t res,
                                    uint index,
                                    gnutls_x509_crt_t **crt_list,
                                    uint *crt_list_size) @nogc;

  /* OCSP status request extension, RFC 6066 */
alias gnutls_status_request_ocsp_func = int function
 (gnutls_session_t session, void *ptr, gnutls_datum_t * ocsp_response) @nogc;

void
gnutls_certificate_set_ocsp_status_request_function
(gnutls_certificate_credentials_t res,
gnutls_status_request_ocsp_func ocsp_func, void *ptr) /*@nogc*/;

int
gnutls_certificate_set_ocsp_status_request_file
(gnutls_certificate_credentials_t res, const(char)* response_file,
 uint flags) @nogc;

int gnutls_ocsp_status_request_enable_client(gnutls_session_t session,
               gnutls_datum_t * responder_id,
               usize responder_id_size,
               gnutls_datum_t *
               request_extensions) @nogc;

int gnutls_ocsp_status_request_get(gnutls_session_t session,
           gnutls_datum_t * response) @nogc;

enum GNUTLS_OCSP_SR_IS_AVAIL = 1;
int gnutls_ocsp_status_request_is_checked(gnutls_session_t session,
            uint flags) @nogc;

/* global state functions
 */
int gnutls_global_init() @nogc;
void gnutls_global_deinit() @nogc;

  /**
   * gnutls_time_func:
   * @t: where to store time.
   *
   * Function prototype for time()-like function.  Set with
   * gnutls_global_set_time_function().
   *
   * Returns: Number of seconds since the epoch, or (time_t)-1 on errors.
   */
//alias gnutls_time_func = time_t function (time_t * t) @nogc;

//alias mutex_init_func = int function (void **mutex) @nogc;
//alias mutex_lock_func = int function (void **mutex) @nogc;
//alias mutex_unlock_func = int function (void **mutex) @nogc;
//alias mutex_deinit_func = int function (void **mutex) @nogc;

void gnutls_global_set_mutex(mutex_init_func init,
           mutex_deinit_func deinit,
           mutex_lock_func lock,
           mutex_unlock_func unlock) /*@nogc*/;

//alias gnutls_alloc_function = void * function (usize) @nogc;
//alias gnutls_calloc_function = void * function (usize, usize) @nogc;
//alias gnutls_is_secure_function = int function (const(void)* ) @nogc;
//alias gnutls_free_function = void function (void *) @nogc;
//alias gnutls_realloc_function = void * function (void *, usize) @nogc;

void gnutls_global_set_time_function(gnutls_time_func time_func) /*@nogc*/;

/* For use in callbacks */
extern __gshared /*_SYM_EXPORT*/ gnutls_alloc_function gnutls_malloc;
extern __gshared /*_SYM_EXPORT*/ gnutls_realloc_function gnutls_realloc;
extern __gshared /*_SYM_EXPORT*/ gnutls_calloc_function gnutls_calloc;
extern __gshared /*_SYM_EXPORT*/ gnutls_free_function gnutls_free;

extern __gshared /*_SYM_EXPORT*/ char * function (const(char)* ) gnutls_strdup;

/* a variant of memset that doesn't get optimized out */
void gnutls_memset(void *data, int c, usize size) @nogc;

/* constant time memcmp */
int gnutls_memcmp(const(void)* s1, const(void)* s2, usize n) @nogc;

//alias gnutls_log_func = void function (int, const(char)* ) @nogc;
//alias gnutls_audit_log_func = void function (gnutls_session_t, const(char)* ) @nogc;
void gnutls_global_set_log_function(gnutls_log_func log_func) /*@nogc*/;
void gnutls_global_set_audit_log_function(gnutls_audit_log_func log_func) /*@nogc*/;
void gnutls_global_set_log_level(int level) @nogc;

/* Diffie-Hellman parameter handling.
 */
int gnutls_dh_params_init(gnutls_dh_params_t * dh_params) @nogc;
void gnutls_dh_params_deinit(gnutls_dh_params_t dh_params) @nogc;
int gnutls_dh_params_import_raw(gnutls_dh_params_t dh_params,
        const(gnutls_datum_t)* prime,
        const(gnutls_datum_t)* generator) @nogc;
int gnutls_dh_params_import_raw2(gnutls_dh_params_t dh_params,
         const(gnutls_datum_t)* prime,
         const(gnutls_datum_t)* generator,
         uint key_bits) @nogc;
int gnutls_dh_params_import_pkcs3(gnutls_dh_params_t params,
          const(gnutls_datum_t)* pkcs3_params,
          gnutls_x509_crt_fmt_t format) @nogc;
int gnutls_dh_params_generate2(gnutls_dh_params_t params,
             uint bits) @nogc;
int gnutls_dh_params_export_pkcs3(gnutls_dh_params_t params,
          gnutls_x509_crt_fmt_t format,
          ubyte *params_data,
          usize * params_data_size) @nogc;
int gnutls_dh_params_export2_pkcs3(gnutls_dh_params_t params,
           gnutls_x509_crt_fmt_t format,
           gnutls_datum_t * out_) @nogc;
int gnutls_dh_params_export_raw(gnutls_dh_params_t params,
        gnutls_datum_t * prime,
        gnutls_datum_t * generator,
        uint *bits) @nogc;
int gnutls_dh_params_cpy(gnutls_dh_params_t dst, gnutls_dh_params_t src) @nogc;



/* Session stuff
 */
struct giovec_t {
  void *iov_base;   /* Starting address */
  usize iov_len;   /* Number of bytes to transfer */
}

//alias gnutls_pull_func = ssize function (gnutls_transport_ptr_t, void *, usize) @nogc;
//alias gnutls_push_func = ssize function (gnutls_transport_ptr_t, const(void)* , usize) @nogc;

int gnutls_system_recv_timeout(gnutls_transport_ptr_t ptr, uint ms) @nogc;
//alias gnutls_pull_timeout_func = int function (gnutls_transport_ptr_t, uint ms) @nogc;

//alias gnutls_vec_push_func = ssize function (gnutls_transport_ptr_t, const(giovec_t)* iov, int iovcnt) @nogc;

//alias gnutls_errno_func = int function (gnutls_transport_ptr_t) @nogc;

/+
#if 0
 /* This will be defined as macro. */
  void gnutls_transport_set_int (gnutls_session_t session, int r) @nogc;
#endif
+/

void gnutls_transport_set_int2(gnutls_session_t session, int r, int s) @nogc;
//#define gnutls_transport_set_int(s, i) gnutls_transport_set_int2(s, i, i)
void gnutls_transport_set_int(gnutls_session_t session, int i) { gnutls_transport_set_int2(session, i, i); }

void gnutls_transport_get_int2(gnutls_session_t session, int *r, int *s) @nogc;
int gnutls_transport_get_int(gnutls_session_t session) @nogc;

void gnutls_transport_set_ptr(gnutls_session_t session,
            gnutls_transport_ptr_t ptr) @nogc;
void gnutls_transport_set_ptr2(gnutls_session_t session,
             gnutls_transport_ptr_t recv_ptr,
             gnutls_transport_ptr_t send_ptr) @nogc;

gnutls_transport_ptr_t gnutls_transport_get_ptr(gnutls_session_t session) @nogc;
void gnutls_transport_get_ptr2(gnutls_session_t session,
             gnutls_transport_ptr_t * recv_ptr,
             gnutls_transport_ptr_t * send_ptr) @nogc;

void gnutls_transport_set_vec_push_function(gnutls_session_t session,
              gnutls_vec_push_func vec_func) /*@nogc*/;
void gnutls_transport_set_push_function(gnutls_session_t session,
          gnutls_push_func push_func) /*@nogc*/;
void gnutls_transport_set_pull_function(gnutls_session_t session,
          gnutls_pull_func pull_func) /*@nogc*/;

void gnutls_transport_set_pull_timeout_function(gnutls_session_t session,
            gnutls_pull_timeout_func
            func) /*@nogc*/;

void gnutls_transport_set_errno_function(gnutls_session_t session,
           gnutls_errno_func errno_func) /*@nogc*/;

void gnutls_transport_set_errno(gnutls_session_t session, int err) @nogc;

/* session specific
 */
void gnutls_session_set_ptr(gnutls_session_t session, void *ptr) @nogc;
void *gnutls_session_get_ptr(gnutls_session_t session) @nogc;

void gnutls_openpgp_send_cert(gnutls_session_t session,
            gnutls_openpgp_crt_status_t status) @nogc;

/* This function returns the hash of the given data.
 */
int gnutls_fingerprint(gnutls_digest_algorithm_t algo,
           const(gnutls_datum_t)* data, void *result,
           usize * result_size) @nogc;

  /**
   * gnutls_random_art_t:
   * @GNUTLS_RANDOM_ART_OPENSSH: OpenSSH-style random art.
   *
   * Enumeration of different random art types.
   */
//alias gnutls_random_art = gnutls_random_art_t;
alias gnutls_random_art_t = int;
enum : int {
  GNUTLS_RANDOM_ART_OPENSSH = 1
}

int gnutls_random_art(gnutls_random_art_t type,
          const(char)* key_type, uint key_size,
          void *fpr, usize fpr_size, gnutls_datum_t * art) @nogc;

/* SRP
 */

struct gnutls_srp_server_credentials_st {}
struct gnutls_srp_client_credentials_st {}
alias gnutls_srp_server_credentials_t = gnutls_srp_server_credentials_st*;
alias gnutls_srp_client_credentials_t = gnutls_srp_client_credentials_st*;

void
gnutls_srp_free_client_credentials(gnutls_srp_client_credentials_t sc) @nogc;
int
gnutls_srp_allocate_client_credentials(gnutls_srp_client_credentials_t *
               sc) @nogc;
int gnutls_srp_set_client_credentials(gnutls_srp_client_credentials_t res,
              const(char)* username,
              const(char)* password) @nogc;

void
gnutls_srp_free_server_credentials(gnutls_srp_server_credentials_t sc) @nogc;
int
gnutls_srp_allocate_server_credentials(gnutls_srp_server_credentials_t *
               sc) @nogc;
int gnutls_srp_set_server_credentials_file(gnutls_srp_server_credentials_t
             res, const(char)* password_file,
             const(char)* password_conf_file) @nogc;

const(char)* gnutls_srp_server_get_username(gnutls_session_t session) @nogc;

void gnutls_srp_set_prime_bits(gnutls_session_t session,
                               uint bits) @nogc;

int gnutls_srp_verifier(const(char)* username,
      const(char)* password,
      const(gnutls_datum_t)* salt,
      const(gnutls_datum_t)* generator,
      const(gnutls_datum_t)* prime,
      gnutls_datum_t * res) @nogc;

/* The static parameters defined in draft-ietf-tls-srp-05
 * Those should be used as input to gnutls_srp_verifier().
 */
extern __gshared /*_SYM_EXPORT*/ const gnutls_datum_t gnutls_srp_4096_group_prime;
extern __gshared /*_SYM_EXPORT*/ const gnutls_datum_t gnutls_srp_4096_group_generator;

extern __gshared /*_SYM_EXPORT*/ const gnutls_datum_t gnutls_srp_3072_group_prime;
extern __gshared /*_SYM_EXPORT*/ const gnutls_datum_t gnutls_srp_3072_group_generator;

extern __gshared /*_SYM_EXPORT*/ const gnutls_datum_t gnutls_srp_2048_group_prime;
extern __gshared /*_SYM_EXPORT*/ const gnutls_datum_t gnutls_srp_2048_group_generator;

extern __gshared /*_SYM_EXPORT*/ const gnutls_datum_t gnutls_srp_1536_group_prime;
extern __gshared /*_SYM_EXPORT*/ const gnutls_datum_t gnutls_srp_1536_group_generator;

extern __gshared /*_SYM_EXPORT*/ const gnutls_datum_t gnutls_srp_1024_group_prime;
extern __gshared /*_SYM_EXPORT*/ const gnutls_datum_t gnutls_srp_1024_group_generator;

/*alias gnutls_srp_server_credentials_function = int function (gnutls_session_t,
               const(char)* username,
               gnutls_datum_t * salt,
               gnutls_datum_t *
               verifier,
               gnutls_datum_t *
               generator,
               gnutls_datum_t * prime) @nogc;*/
void
gnutls_srp_set_server_credentials_function(gnutls_srp_server_credentials_t
             cred,
             gnutls_srp_server_credentials_function func) /*@nogc*/;

//alias gnutls_srp_client_credentials_function = int function (gnutls_session_t, char **, char **) @nogc;
void
gnutls_srp_set_client_credentials_function(gnutls_srp_client_credentials_t
             cred,
             gnutls_srp_client_credentials_function func) /*@nogc*/;

int gnutls_srp_base64_encode(const(gnutls_datum_t)* data, char *result,
           usize * result_size) @nogc;
int gnutls_srp_base64_encode2(const(gnutls_datum_t)* data,
           gnutls_datum_t * result) @nogc;

int gnutls_srp_base64_decode(const(gnutls_datum_t)* b64_data, char *result,
           usize * result_size) @nogc;
int gnutls_srp_base64_decode2(const(gnutls_datum_t)* b64_data,
           gnutls_datum_t * result) @nogc;

alias gnutls_srp_base64_encode_alloc = gnutls_srp_base64_encode2;
alias gnutls_srp_base64_decode_alloc = gnutls_srp_base64_decode2;

void
gnutls_srp_set_server_fake_salt_seed(gnutls_srp_server_credentials_t
             sc,
             const(gnutls_datum_t)* seed,
             uint salt_length) @nogc;

/* PSK stuff */
struct gnutls_psk_server_credentials_st {}
struct gnutls_psk_client_credentials_st {}
alias gnutls_psk_server_credentials_t = gnutls_psk_server_credentials_st*;
alias gnutls_psk_client_credentials_t = gnutls_psk_client_credentials_st*;

/**
 * gnutls_psk_key_flags:
 * @GNUTLS_PSK_KEY_RAW: PSK-key in raw format.
 * @GNUTLS_PSK_KEY_HEX: PSK-key in hex format.
 *
 * Enumeration of different PSK key flags.
 */
alias gnutls_psk_key_flags = int;
enum : int {
  GNUTLS_PSK_KEY_RAW = 0,
  GNUTLS_PSK_KEY_HEX
}

void
gnutls_psk_free_client_credentials(gnutls_psk_client_credentials_t sc) @nogc;
int
gnutls_psk_allocate_client_credentials(gnutls_psk_client_credentials_t *
               sc) @nogc;
int gnutls_psk_set_client_credentials(gnutls_psk_client_credentials_t res,
              const(char)* username,
              const(gnutls_datum_t)* key,
              gnutls_psk_key_flags flags) @nogc;

void
gnutls_psk_free_server_credentials(gnutls_psk_server_credentials_t sc) @nogc;
int
gnutls_psk_allocate_server_credentials(gnutls_psk_server_credentials_t *
               sc) @nogc;
int gnutls_psk_set_server_credentials_file(gnutls_psk_server_credentials_t
             res, const(char)* password_file) @nogc;

int
gnutls_psk_set_server_credentials_hint(gnutls_psk_server_credentials_t
               res, const(char)* hint) @nogc;

const(char)* gnutls_psk_server_get_username(gnutls_session_t session) @nogc;
const(char)* gnutls_psk_client_get_hint(gnutls_session_t session) @nogc;

//alias gnutls_psk_server_credentials_function = int function (gnutls_session_t, const(char)* username, gnutls_datum_t* key) @nogc;
void
gnutls_psk_set_server_credentials_function(gnutls_psk_server_credentials_t
             cred,
             gnutls_psk_server_credentials_function func) /*@nogc*/;

//alias gnutls_psk_client_credentials_function = int function (gnutls_session_t, char** username, gnutls_datum_t* key) @nogc;
void
gnutls_psk_set_client_credentials_function(gnutls_psk_client_credentials_t
             cred,
             gnutls_psk_client_credentials_function func) /*@nogc*/;

int gnutls_hex_encode(const(gnutls_datum_t)* data, char *result,
          usize * result_size) @nogc;
int gnutls_hex_decode(const(gnutls_datum_t)* hex_data, void *result,
          usize * result_size) @nogc;

int gnutls_hex_encode2(const(gnutls_datum_t)* data, gnutls_datum_t *result) @nogc;
int gnutls_hex_decode2(const(gnutls_datum_t)* data, gnutls_datum_t *result) @nogc;

void
gnutls_psk_set_server_dh_params(gnutls_psk_server_credentials_t res,
        gnutls_dh_params_t dh_params) @nogc;

void
gnutls_psk_set_server_params_function(gnutls_psk_server_credentials_t
              res, gnutls_params_function func) /*@nogc*/;

/**
 * gnutls_x509_subject_alt_name_t:
 * @GNUTLS_SAN_DNSNAME: DNS-name SAN.
 * @GNUTLS_SAN_RFC822NAME: E-mail address SAN.
 * @GNUTLS_SAN_URI: URI SAN.
 * @GNUTLS_SAN_IPADDRESS: IP address SAN.
 * @GNUTLS_SAN_OTHERNAME: OtherName SAN.
 * @GNUTLS_SAN_DN: DN SAN.
 * @GNUTLS_SAN_OTHERNAME_XMPP: Virtual SAN, used by
 *   gnutls_x509_crt_get_subject_alt_othername_oid.
 *
 * Enumeration of different subject alternative names types.
 */
alias gnutls_x509_subject_alt_name_t = int;
enum : int {
  GNUTLS_SAN_DNSNAME = 1,
  GNUTLS_SAN_RFC822NAME = 2,
  GNUTLS_SAN_URI = 3,
  GNUTLS_SAN_IPADDRESS = 4,
  GNUTLS_SAN_OTHERNAME = 5,
  GNUTLS_SAN_DN = 6,
  /* The following are "virtual" subject alternative name types, in
     that they are represented by an otherName value and an OID.
     Used by gnutls_x509_crt_get_subject_alt_othername_oid.  */
  GNUTLS_SAN_OTHERNAME_XMPP = 1000
}

struct gnutls_openpgp_crt_int;
alias gnutls_openpgp_crt_t = gnutls_openpgp_crt_int*;

struct gnutls_openpgp_privkey_int;
alias gnutls_openpgp_privkey_t = gnutls_openpgp_privkey_int*;

struct gnutls_pkcs11_privkey_st;
alias gnutls_pkcs11_privkey_t = gnutls_pkcs11_privkey_st*;

/**
 * gnutls_privkey_type_t:
 * @GNUTLS_PRIVKEY_X509: X.509 private key, #gnutls_x509_privkey_t.
 * @GNUTLS_PRIVKEY_OPENPGP: OpenPGP private key, #gnutls_openpgp_privkey_t.
 * @GNUTLS_PRIVKEY_PKCS11: PKCS11 private key, #gnutls_pkcs11_privkey_t.
 * @GNUTLS_PRIVKEY_EXT: External private key, operating using callbacks.
 *
 * Enumeration of different private key types.
 */
alias gnutls_privkey_type_t = int;
enum : int {
  GNUTLS_PRIVKEY_X509,
  GNUTLS_PRIVKEY_OPENPGP,
  GNUTLS_PRIVKEY_PKCS11,
  GNUTLS_PRIVKEY_EXT
}

union gnutls_retr2_st_cert_union {
  gnutls_x509_crt_t *x509;
  gnutls_openpgp_crt_t pgp;
}

union gnutls_retr2_st_key_union {
  gnutls_x509_privkey_t x509;
  gnutls_openpgp_privkey_t pgp;
  gnutls_pkcs11_privkey_t pkcs11;
}

struct gnutls_retr2_st {
  gnutls_certificate_type_t cert_type;
  gnutls_privkey_type_t key_type;

  gnutls_retr2_st_cert_union cert;
  uint ncerts;  /* one for pgp keys */

  gnutls_retr2_st_key_union key;

  uint deinit_all;  /* if non zero all keys will be deinited */
}


  /* Functions that allow auth_info_t structures handling
   */

gnutls_credentials_type_t gnutls_auth_get_type(gnutls_session_t session) @nogc;
gnutls_credentials_type_t
gnutls_auth_server_get_type(gnutls_session_t session) @nogc;
gnutls_credentials_type_t
gnutls_auth_client_get_type(gnutls_session_t session) @nogc;

  /* DH */

void gnutls_dh_set_prime_bits(gnutls_session_t session, uint bits) @nogc;
int gnutls_dh_get_secret_bits(gnutls_session_t session) @nogc;
int gnutls_dh_get_peers_public_bits(gnutls_session_t session) @nogc;
int gnutls_dh_get_prime_bits(gnutls_session_t session) @nogc;

int gnutls_dh_get_group(gnutls_session_t session, gnutls_datum_t * raw_gen,
      gnutls_datum_t * raw_prime) @nogc;
int gnutls_dh_get_pubkey(gnutls_session_t session,
       gnutls_datum_t * raw_key) @nogc;

  /* X509PKI */


  /* These are set on the credentials structure.
   */

  /* use gnutls_certificate_set_retrieve_function2() in abstract.h
   * instead. It's much more efficient.
   */

//alias gnutls_certificate_retrieve_function = int function (gnutls_session_t, const(gnutls_datum_t)* req_ca_rdn, int nreqs, const(gnutls_pk_algorithm_t)* pk_algos, int pk_algos_length, gnutls_retr2_st*) @nogc;

void
gnutls_certificate_set_retrieve_function(gnutls_certificate_credentials_t
           cred,
           gnutls_certificate_retrieve_function func) /*@nogc*/;

void
gnutls_certificate_set_verify_function(gnutls_certificate_credentials_t
               cred,
               gnutls_certificate_verify_function func) /*@nogc*/;

void
gnutls_certificate_server_set_request(gnutls_session_t session,
              gnutls_certificate_request_t req) @nogc;

  /* get data from the session
   */
const(gnutls_datum_t)* gnutls_certificate_get_peers(gnutls_session_t
               session, uint
               *list_size) @nogc;
const(gnutls_datum_t)* gnutls_certificate_get_ours(gnutls_session_t
              session) @nogc;

int gnutls_certificate_get_peers_subkey_id(gnutls_session_t session,
             gnutls_datum_t * id) @nogc;

time_t gnutls_certificate_activation_time_peers(gnutls_session_t session) @nogc;
time_t gnutls_certificate_expiration_time_peers(gnutls_session_t session) @nogc;

int gnutls_certificate_client_get_request_status(gnutls_session_t session) @nogc;
int gnutls_certificate_verify_peers2(gnutls_session_t session,
             uint *status) @nogc;
int gnutls_certificate_verify_peers3(gnutls_session_t session,
             const(char)* hostname,
             uint *status) @nogc;

int
gnutls_certificate_verify_peers(gnutls_session_t session,
        gnutls_typed_vdata_st * data,
        uint elements,
        uint *status) @nogc;

int gnutls_certificate_verification_status_print(uint status,
             gnutls_certificate_type_t
             type,
             gnutls_datum_t * out_,
             uint flags) @nogc;

int gnutls_pem_base64_encode(const(char)* msg, const(gnutls_datum_t)* data,
           char *result, usize * result_size) @nogc;
int gnutls_pem_base64_decode(const(char)* header,
           const(gnutls_datum_t)* b64_data,
           ubyte *result, usize * result_size) @nogc;

int gnutls_pem_base64_encode2(const(char)* msg,
           const(gnutls_datum_t)* data,
           gnutls_datum_t * result) @nogc;
int gnutls_pem_base64_decode2(const(char)* header,
           const(gnutls_datum_t)* b64_data,
           gnutls_datum_t * result) @nogc;

alias gnutls_pem_base64_encode_alloc = gnutls_pem_base64_encode2;
alias gnutls_pem_base64_decode_alloc = gnutls_pem_base64_decode2;

  /* key_usage will be an OR of the following values:
   */

  /* when the key is to be used for signing: */
enum GNUTLS_KEY_DIGITAL_SIGNATURE = 128;
enum GNUTLS_KEY_NON_REPUDIATION = 64;
  /* when the key is to be used for encryption: */
enum GNUTLS_KEY_KEY_ENCIPHERMENT = 32;
enum GNUTLS_KEY_DATA_ENCIPHERMENT = 16;
enum GNUTLS_KEY_KEY_AGREEMENT = 8;
enum GNUTLS_KEY_KEY_CERT_SIGN = 4;
enum GNUTLS_KEY_CRL_SIGN = 2;
enum GNUTLS_KEY_ENCIPHER_ONLY = 1;
enum GNUTLS_KEY_DECIPHER_ONLY = 32768;

void
gnutls_certificate_set_params_function(gnutls_certificate_credentials_t
               res, gnutls_params_function func) /*@nogc*/;
void gnutls_anon_set_params_function(gnutls_anon_server_credentials_t res,
             gnutls_params_function func) /*@nogc*/;
void gnutls_psk_set_params_function(gnutls_psk_server_credentials_t res,
            gnutls_params_function func) /*@nogc*/;

int gnutls_hex2bin(const(char)* hex_data, usize hex_size,
       void *bin_data, usize * bin_size) @nogc;

  /* Trust on first use (or ssh like) functions */

  /* stores the provided information to a database
   */
//alias gnutls_tdb_store_func = int function (const(char)* db_name, const(char)* host, const(char)* service, time_t expiration, const(gnutls_datum_t)* pubkey) @nogc;
//alias gnutls_tdb_store_commitment_func = int function (const(char)* db_name, const(char)* host, const(char)* service, time_t expiration, gnutls_digest_algorithm_t hash_algo, const(gnutls_datum_t)* hash) @nogc;

  /* searches for the provided host/service pair that match the
   * provided public key in the database. */
//alias gnutls_tdb_verify_func = int function (const(char)* db_name, const(char)* host, const(char)* service, const(gnutls_datum_t)* pubkey) @nogc;


struct gnutls_tdb_int;
alias gnutls_tdb_t = gnutls_tdb_int*;

int gnutls_tdb_init(gnutls_tdb_t * tdb) @nogc;
void gnutls_tdb_set_store_func(gnutls_tdb_t tdb,
             gnutls_tdb_store_func store) /*@nogc*/;
void gnutls_tdb_set_store_commitment_func(gnutls_tdb_t tdb,
            gnutls_tdb_store_commitment_func
            cstore) /*@nogc*/;
void gnutls_tdb_set_verify_func(gnutls_tdb_t tdb,
        gnutls_tdb_verify_func verify) /*@nogc*/;
void gnutls_tdb_deinit(gnutls_tdb_t tdb) @nogc;

int gnutls_verify_stored_pubkey(const(char)* db_name,
        gnutls_tdb_t tdb,
        const(char)* host,
        const(char)* service,
        gnutls_certificate_type_t cert_type,
        const(gnutls_datum_t)* cert,
        uint flags) @nogc;

int gnutls_store_commitment(const(char)* db_name,
          gnutls_tdb_t tdb,
          const(char)* host,
          const(char)* service,
          gnutls_digest_algorithm_t hash_algo,
          const(gnutls_datum_t)* hash,
          time_t expiration, uint flags) @nogc;

int gnutls_store_pubkey(const(char)* db_name,
      gnutls_tdb_t tdb,
      const(char)* host,
      const(char)* service,
      gnutls_certificate_type_t cert_type,
      const(gnutls_datum_t)* cert,
      time_t expiration, uint flags) @nogc;

  /* Other helper functions */
int gnutls_load_file(const(char)* filename, gnutls_datum_t * data) @nogc;

int gnutls_url_is_supported(const(char)* url) @nogc;

  /* PIN callback */

/**
 * gnutls_pin_flag_t:
 * @GNUTLS_PIN_USER: The PIN for the user.
 * @GNUTLS_PIN_SO: The PIN for the security officer (admin).
 * @GNUTLS_PIN_CONTEXT_SPECIFIC: The PIN is for a specific action and key like signing.
 * @GNUTLS_PIN_FINAL_TRY: This is the final try before blocking.
 * @GNUTLS_PIN_COUNT_LOW: Few tries remain before token blocks.
 * @GNUTLS_PIN_WRONG: Last given PIN was not correct.
 *
 * Enumeration of different flags that are input to the PIN function.
 */
alias gnutls_pin_flag_t = int;
enum : int {
  GNUTLS_PIN_USER = (1 << 0),
  GNUTLS_PIN_SO = (1 << 1),
  GNUTLS_PIN_FINAL_TRY = (1 << 2),
  GNUTLS_PIN_COUNT_LOW = (1 << 3),
  GNUTLS_PIN_CONTEXT_SPECIFIC = (1 << 4),
  GNUTLS_PIN_WRONG = (1 << 5)
}

enum GNUTLS_PKCS11_PIN_USER = GNUTLS_PIN_USER;
enum GNUTLS_PKCS11_PIN_SO = GNUTLS_PIN_SO;
enum GNUTLS_PKCS11_PIN_FINAL_TRY = GNUTLS_PIN_FINAL_TRY;
enum GNUTLS_PKCS11_PIN_COUNT_LOW = GNUTLS_PIN_COUNT_LOW;
enum GNUTLS_PKCS11_PIN_CONTEXT_SPECIFIC = GNUTLS_PIN_CONTEXT_SPECIFIC;
enum GNUTLS_PKCS11_PIN_WRONG = GNUTLS_PIN_WRONG;

/**
 * gnutls_pin_callback_t:
 * @userdata: user-controlled data from gnutls_pkcs11_set_pin_function().
 * @attempt: pin-attempt counter, initially 0.
 * @token_url: URL of token.
 * @token_label: label of token.
 * @flags: a #gnutls_pin_flag_t flag.
 * @pin: buffer to hold PIN, of size @pin_max.
 * @pin_max: size of @pin buffer.
 *
 * Callback function type for PKCS#11 or TPM PIN entry.  It is set by
 * functions like gnutls_pkcs11_set_pin_function().
 *
 * The callback should provides the PIN code to unlock the token with
 * label @token_label, specified by the URL @token_url.
 *
 * The PIN code, as a NUL-terminated ASCII string, should be copied
 * into the @pin buffer (of maximum size @pin_max), and return 0 to
 * indicate success.  Alternatively, the callback may return a
 * negative gnutls error code to indicate failure and cancel PIN entry
 * (in which case, the contents of the @pin parameter are ignored).
 *
 * When a PIN is required, the callback will be invoked repeatedly
 * (and indefinitely) until either the returned PIN code is correct,
 * the callback returns failure, or the token refuses login (e.g. when
 * the token is locked due to too many incorrect PINs!).  For the
 * first such invocation, the @attempt counter will have value zero;
 * it will increase by one for each subsequent attempt.
 *
 * Returns: %GNUTLS_E_SUCCESS (0) on success or a negative error code on error.
 *
 * Since: 2.12.0
 **/
//alias gnutls_pin_callback_t = int function (void *userdata, int attempt, const(char)* token_url, const(char)* token_label, uint flags, char* pin, usize pin_max) @nogc;

void gnutls_certificate_set_pin_function(gnutls_certificate_credentials_t,
           gnutls_pin_callback_t fn,
           void *userdata) /*@nogc*/;

/* Public string related functions */
struct gnutls_buffer_st {}
alias gnutls_buffer_t = gnutls_buffer_st*;

int gnutls_buffer_append_data(gnutls_buffer_t, const(void)* data, usize data_size) @nogc;

/* Public extensions related functions */

alias gnutls_ext_priv_data_t = void *;

void gnutls_ext_set_data(gnutls_session_t session, uint type,
       gnutls_ext_priv_data_t) @nogc;
int gnutls_ext_get_data(gnutls_session_t session, uint type,
      gnutls_ext_priv_data_t *) @nogc;

//alias gnutls_ext_recv_func = int function (gnutls_session_t session, const(ubyte)* data, usize len) @nogc;
//alias gnutls_ext_send_func = int function (gnutls_session_t session, gnutls_buffer_t extdata) @nogc;
//alias gnutls_ext_deinit_data_func = void function (gnutls_ext_priv_data_t data) @nogc;
//alias gnutls_ext_pack_func = int function (gnutls_ext_priv_data_t data, gnutls_buffer_t packed_data) @nogc;
//alias gnutls_ext_unpack_func = int function (gnutls_buffer_t packed_data, gnutls_ext_priv_data_t *data) @nogc;

/**
 * gnutls_ext_parse_type_t:
 * @GNUTLS_EXT_NONE: Never parsed
 * @GNUTLS_EXT_ANY: Any extension type.
 * @GNUTLS_EXT_APPLICATION: Application extension.
 * @GNUTLS_EXT_TLS: TLS-internal extension.
 * @GNUTLS_EXT_MANDATORY: Extension parsed even if resuming (or extensions are disabled).
 *
 * Enumeration of different TLS extension types.  This flag
 * indicates for an extension whether it is useful to application
 * level or TLS level only.  This is (only) used to parse the
 * application level extensions before the "client_hello" callback
 * is called.
 */
alias gnutls_ext_parse_type_t = int;
enum : int {
  GNUTLS_EXT_ANY = 0,
  GNUTLS_EXT_APPLICATION = 1,
  GNUTLS_EXT_TLS = 2,
  GNUTLS_EXT_MANDATORY = 3,
  GNUTLS_EXT_NONE = 4
}

  /* Register a custom tls extension
   */
int gnutls_ext_register(const(char)* name, int type, gnutls_ext_parse_type_t parse_type,
        gnutls_ext_recv_func recv_func, gnutls_ext_send_func send_func,
        gnutls_ext_deinit_data_func deinit_func, gnutls_ext_pack_func pack_func,
        gnutls_ext_unpack_func unpack_func) /*@nogc*/;

/* Public supplemental data related functions */

//alias gnutls_supp_recv_func = int function (gnutls_session_t session, const(ubyte)* data, usize data_size) @nogc;
//alias gnutls_supp_send_func = int function (gnutls_session_t session, gnutls_buffer_t buf) @nogc;

int gnutls_supplemental_register(const(char)* name,
        gnutls_supplemental_data_format_type_t type,
        gnutls_supp_recv_func supp_recv_func,
        gnutls_supp_send_func supp_send_func) /*@nogc*/;

void gnutls_supplemental_recv(gnutls_session_t session, uint do_recv_supplemental) @nogc;

void gnutls_supplemental_send(gnutls_session_t session, uint do_send_supplemental) @nogc;

/* FIPS140-2 related functions */
int gnutls_fips140_mode_enabled() @nogc;

  /* Gnutls error codes. The mapping to a TLS alert is also shown in
   * comments.
   */

enum GNUTLS_E_SUCCESS = 0;
enum GNUTLS_E_UNKNOWN_COMPRESSION_ALGORITHM = -3;
enum GNUTLS_E_UNKNOWN_CIPHER_TYPE = -6;
enum GNUTLS_E_LARGE_PACKET = -7;
enum GNUTLS_E_UNSUPPORTED_VERSION_PACKET = -8;  /* GNUTLS_A_PROTOCOL_VERSION */
enum GNUTLS_E_UNEXPECTED_PACKET_LENGTH = -9;  /* GNUTLS_A_RECORD_OVERFLOW */
enum GNUTLS_E_INVALID_SESSION = -10;
enum GNUTLS_E_FATAL_ALERT_RECEIVED = -12;
enum GNUTLS_E_UNEXPECTED_PACKET = -15;  /* GNUTLS_A_UNEXPECTED_MESSAGE */
enum GNUTLS_E_WARNING_ALERT_RECEIVED = -16;
enum GNUTLS_E_ERROR_IN_FINISHED_PACKET = -18;
enum GNUTLS_E_UNEXPECTED_HANDSHAKE_PACKET = -19;
enum GNUTLS_E_UNKNOWN_CIPHER_SUITE = -21; /* GNUTLS_A_HANDSHAKE_FAILURE */
enum GNUTLS_E_UNWANTED_ALGORITHM = -22;
enum GNUTLS_E_MPI_SCAN_FAILED = -23;
enum GNUTLS_E_DECRYPTION_FAILED = -24;  /* GNUTLS_A_DECRYPTION_FAILED, GNUTLS_A_BAD_RECORD_MAC */
enum GNUTLS_E_MEMORY_ERROR = -25;
enum GNUTLS_E_DECOMPRESSION_FAILED = -26; /* GNUTLS_A_DECOMPRESSION_FAILURE */
enum GNUTLS_E_COMPRESSION_FAILED = -27;
enum GNUTLS_E_AGAIN = -28;
enum GNUTLS_E_EXPIRED = -29;
enum GNUTLS_E_DB_ERROR = -30;
enum GNUTLS_E_SRP_PWD_ERROR = -31;
enum GNUTLS_E_INSUFFICIENT_CREDENTIALS = -32;
enum GNUTLS_E_INSUFICIENT_CREDENTIALS = GNUTLS_E_INSUFFICIENT_CREDENTIALS;  /* for backwards compatibility only */
enum GNUTLS_E_INSUFFICIENT_CRED = GNUTLS_E_INSUFFICIENT_CREDENTIALS;
enum GNUTLS_E_INSUFICIENT_CRED = GNUTLS_E_INSUFFICIENT_CREDENTIALS; /* for backwards compatibility only */

enum GNUTLS_E_HASH_FAILED = -33;
enum GNUTLS_E_BASE64_DECODING_ERROR = -34;

enum GNUTLS_E_MPI_PRINT_FAILED = -35;
enum GNUTLS_E_REHANDSHAKE = -37;  /* GNUTLS_A_NO_RENEGOTIATION */
enum GNUTLS_E_GOT_APPLICATION_DATA = -38;
enum GNUTLS_E_RECORD_LIMIT_REACHED = -39;
enum GNUTLS_E_ENCRYPTION_FAILED = -40;

enum GNUTLS_E_PK_ENCRYPTION_FAILED = -44;
enum GNUTLS_E_PK_DECRYPTION_FAILED = -45;
enum GNUTLS_E_PK_SIGN_FAILED = -46;
enum GNUTLS_E_X509_UNSUPPORTED_CRITICAL_EXTENSION = -47;
enum GNUTLS_E_KEY_USAGE_VIOLATION = -48;
enum GNUTLS_E_NO_CERTIFICATE_FOUND = -49; /* GNUTLS_A_BAD_CERTIFICATE */
enum GNUTLS_E_INVALID_REQUEST = -50;
enum GNUTLS_E_SHORT_MEMORY_BUFFER = -51;
enum GNUTLS_E_INTERRUPTED = -52;
enum GNUTLS_E_PUSH_ERROR = -53;
enum GNUTLS_E_PULL_ERROR = -54;
enum GNUTLS_E_RECEIVED_ILLEGAL_PARAMETER = -55; /* GNUTLS_A_ILLEGAL_PARAMETER */
enum GNUTLS_E_REQUESTED_DATA_NOT_AVAILABLE = -56;
enum GNUTLS_E_PKCS1_WRONG_PAD = -57;
enum GNUTLS_E_RECEIVED_ILLEGAL_EXTENSION = -58;
enum GNUTLS_E_INTERNAL_ERROR = -59;
enum GNUTLS_E_DH_PRIME_UNACCEPTABLE = -63;
enum GNUTLS_E_FILE_ERROR = -64;
enum GNUTLS_E_TOO_MANY_EMPTY_PACKETS = -78;
enum GNUTLS_E_UNKNOWN_PK_ALGORITHM = -80;
enum GNUTLS_E_TOO_MANY_HANDSHAKE_PACKETS = -81;

  /* returned if you need to generate temporary RSA
   * parameters. These are needed for export cipher suites.
   */
enum GNUTLS_E_NO_TEMPORARY_RSA_PARAMS = -84;

enum GNUTLS_E_NO_COMPRESSION_ALGORITHMS = -86;
enum GNUTLS_E_NO_CIPHER_SUITES = -87;

enum GNUTLS_E_OPENPGP_GETKEY_FAILED = -88;
enum GNUTLS_E_PK_SIG_VERIFY_FAILED = -89;

enum GNUTLS_E_ILLEGAL_SRP_USERNAME = -90;
enum GNUTLS_E_SRP_PWD_PARSING_ERROR = -91;
enum GNUTLS_E_NO_TEMPORARY_DH_PARAMS = -93;

  /* For certificate and key stuff
   */
enum GNUTLS_E_ASN1_ELEMENT_NOT_FOUND = -67;
enum GNUTLS_E_ASN1_IDENTIFIER_NOT_FOUND = -68;
enum GNUTLS_E_ASN1_DER_ERROR = -69;
enum GNUTLS_E_ASN1_VALUE_NOT_FOUND = -70;
enum GNUTLS_E_ASN1_GENERIC_ERROR = -71;
enum GNUTLS_E_ASN1_VALUE_NOT_VALID = -72;
enum GNUTLS_E_ASN1_TAG_ERROR = -73;
enum GNUTLS_E_ASN1_TAG_IMPLICIT = -74;
enum GNUTLS_E_ASN1_TYPE_ANY_ERROR = -75;
enum GNUTLS_E_ASN1_SYNTAX_ERROR = -76;
enum GNUTLS_E_ASN1_DER_OVERFLOW = -77;
enum GNUTLS_E_OPENPGP_UID_REVOKED = -79;
enum GNUTLS_E_CERTIFICATE_ERROR = -43;
enum GNUTLS_E_X509_CERTIFICATE_ERROR = GNUTLS_E_CERTIFICATE_ERROR;
enum GNUTLS_E_CERTIFICATE_KEY_MISMATCH = -60;
enum GNUTLS_E_UNSUPPORTED_CERTIFICATE_TYPE = -61; /* GNUTLS_A_UNSUPPORTED_CERTIFICATE */
enum GNUTLS_E_X509_UNKNOWN_SAN = -62;
enum GNUTLS_E_OPENPGP_FINGERPRINT_UNSUPPORTED = -94;
enum GNUTLS_E_X509_UNSUPPORTED_ATTRIBUTE = -95;
enum GNUTLS_E_UNKNOWN_HASH_ALGORITHM = -96;
enum GNUTLS_E_UNKNOWN_PKCS_CONTENT_TYPE = -97;
enum GNUTLS_E_UNKNOWN_PKCS_BAG_TYPE = -98;
enum GNUTLS_E_INVALID_PASSWORD = -99;
enum GNUTLS_E_MAC_VERIFY_FAILED = -100; /* for PKCS #12 MAC */
enum GNUTLS_E_CONSTRAINT_ERROR = -101;

enum GNUTLS_E_WARNING_IA_IPHF_RECEIVED = -102;
enum GNUTLS_E_WARNING_IA_FPHF_RECEIVED = -103;

enum GNUTLS_E_IA_VERIFY_FAILED = -104;
enum GNUTLS_E_UNKNOWN_ALGORITHM = -105;
enum GNUTLS_E_UNSUPPORTED_SIGNATURE_ALGORITHM = -106;
enum GNUTLS_E_SAFE_RENEGOTIATION_FAILED = -107;
enum GNUTLS_E_UNSAFE_RENEGOTIATION_DENIED = -108;
enum GNUTLS_E_UNKNOWN_SRP_USERNAME = -109;
enum GNUTLS_E_PREMATURE_TERMINATION = -110;

enum GNUTLS_E_BASE64_ENCODING_ERROR = -201;
enum GNUTLS_E_INCOMPATIBLE_GCRYPT_LIBRARY = -202; /* obsolete */
enum GNUTLS_E_INCOMPATIBLE_CRYPTO_LIBRARY = -202;
enum GNUTLS_E_INCOMPATIBLE_LIBTASN1_LIBRARY = -203;

enum GNUTLS_E_OPENPGP_KEYRING_ERROR = -204;
enum GNUTLS_E_X509_UNSUPPORTED_OID = -205;

enum GNUTLS_E_RANDOM_FAILED = -206;
enum GNUTLS_E_BASE64_UNEXPECTED_HEADER_ERROR = -207;

enum GNUTLS_E_OPENPGP_SUBKEY_ERROR = -208;

enum GNUTLS_E_CRYPTO_ALREADY_REGISTERED = GNUTLS_E_ALREADY_REGISTERED;
enum GNUTLS_E_ALREADY_REGISTERED = -209;

enum GNUTLS_E_HANDSHAKE_TOO_LARGE = -210;

enum GNUTLS_E_CRYPTODEV_IOCTL_ERROR = -211;
enum GNUTLS_E_CRYPTODEV_DEVICE_ERROR = -212;

enum GNUTLS_E_CHANNEL_BINDING_NOT_AVAILABLE = -213;
enum GNUTLS_E_BAD_COOKIE = -214;
enum GNUTLS_E_OPENPGP_PREFERRED_KEY_ERROR = -215;
enum GNUTLS_E_INCOMPAT_DSA_KEY_WITH_TLS_PROTOCOL = -216;
enum GNUTLS_E_INSUFFICIENT_SECURITY = -217;

enum GNUTLS_E_HEARTBEAT_PONG_RECEIVED = -292;
enum GNUTLS_E_HEARTBEAT_PING_RECEIVED = -293;

/* PKCS11 related */
enum GNUTLS_E_PKCS11_ERROR = -300;
enum GNUTLS_E_PKCS11_LOAD_ERROR = -301;
enum GNUTLS_E_PARSING_ERROR = -302;
enum GNUTLS_E_PKCS11_PIN_ERROR = -303;

enum GNUTLS_E_PKCS11_SLOT_ERROR = -305;
enum GNUTLS_E_LOCKING_ERROR = -306;
enum GNUTLS_E_PKCS11_ATTRIBUTE_ERROR = -307;
enum GNUTLS_E_PKCS11_DEVICE_ERROR = -308;
enum GNUTLS_E_PKCS11_DATA_ERROR = -309;
enum GNUTLS_E_PKCS11_UNSUPPORTED_FEATURE_ERROR = -310;
enum GNUTLS_E_PKCS11_KEY_ERROR = -311;
enum GNUTLS_E_PKCS11_PIN_EXPIRED = -312;
enum GNUTLS_E_PKCS11_PIN_LOCKED = -313;
enum GNUTLS_E_PKCS11_SESSION_ERROR = -314;
enum GNUTLS_E_PKCS11_SIGNATURE_ERROR = -315;
enum GNUTLS_E_PKCS11_TOKEN_ERROR = -316;
enum GNUTLS_E_PKCS11_USER_ERROR = -317;

enum GNUTLS_E_CRYPTO_INIT_FAILED = -318;
enum GNUTLS_E_TIMEDOUT = -319;
enum GNUTLS_E_USER_ERROR = -320;
enum GNUTLS_E_ECC_NO_SUPPORTED_CURVES = -321;
enum GNUTLS_E_ECC_UNSUPPORTED_CURVE = -322;
enum GNUTLS_E_PKCS11_REQUESTED_OBJECT_NOT_AVAILBLE = -323;
enum GNUTLS_E_CERTIFICATE_LIST_UNSORTED = -324;
enum GNUTLS_E_ILLEGAL_PARAMETER = -325;
enum GNUTLS_E_NO_PRIORITIES_WERE_SET = -326;
enum GNUTLS_E_X509_UNSUPPORTED_EXTENSION = -327;
enum GNUTLS_E_SESSION_EOF = -328;

enum GNUTLS_E_TPM_ERROR = -329;
enum GNUTLS_E_TPM_KEY_PASSWORD_ERROR = -330;
enum GNUTLS_E_TPM_SRK_PASSWORD_ERROR = -331;
enum GNUTLS_E_TPM_SESSION_ERROR = -332;
enum GNUTLS_E_TPM_KEY_NOT_FOUND = -333;
enum GNUTLS_E_TPM_UNINITIALIZED = -334;
enum GNUTLS_E_TPM_NO_LIB = -335;

enum GNUTLS_E_NO_CERTIFICATE_STATUS = -340;
enum GNUTLS_E_OCSP_RESPONSE_ERROR = -341;
enum GNUTLS_E_RANDOM_DEVICE_ERROR = -342;
enum GNUTLS_E_AUTH_ERROR = -343;
enum GNUTLS_E_NO_APPLICATION_PROTOCOL = -344;
enum GNUTLS_E_SOCKETS_INIT_ERROR = -345;
enum GNUTLS_E_KEY_IMPORT_FAILED = -346;
enum GNUTLS_E_INAPPROPRIATE_FALLBACK = -347; /*GNUTLS_A_INAPPROPRIATE_FALLBACK*/
enum GNUTLS_E_CERTIFICATE_VERIFICATION_ERROR = -348;

enum GNUTLS_E_SELF_TEST_ERROR = -400;
enum GNUTLS_E_NO_SELF_TEST = -401;
enum GNUTLS_E_LIB_IN_ERROR_STATE = -402;
enum GNUTLS_E_PK_GENERATION_ERROR = -403;
enum GNUTLS_E_IDNA_ERROR = -404;

enum GNUTLS_E_NEED_FALLBACK = -405;

enum GNUTLS_E_UNIMPLEMENTED_FEATURE = -1250;



enum GNUTLS_E_APPLICATION_ERROR_MAX = -65000;
enum GNUTLS_E_APPLICATION_ERROR_MIN = -65500;
