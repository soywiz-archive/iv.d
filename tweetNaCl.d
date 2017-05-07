/*
 * Contributors (alphabetical order)
 *  Daniel J. Bernstein, University of Illinois at Chicago and Technische Universiteit Eindhoven
 *  Wesley Janssen, Radboud Universiteit Nijmegen
 *  Tanja Lange, Technische Universiteit Eindhoven
 *  Peter Schwabe, Radboud Universiteit Nijmegen
 *
 * Ported by Ketmar // Invisible Vector ( ketmar@ketmar.no-ip.org )
 */
//k8: yes, i know that this code sux. i know that i should rewrite it to be more 'D-ish'.
//    i'll not do that. thank you.
module iv.tweetNaCl /*is aliced*/;

public nothrow:


// ////////////////////////////////////////////////////////////////////////// //
enum {
  crypto_auth_BYTES = 32,
  crypto_auth_KEYBYTES = 32,

  crypto_box_PUBLICKEYBYTES = 32,
  crypto_box_SECRETKEYBYTES = 32,
  crypto_box_BEFORENMBYTES = 32,
  crypto_box_NONCEBYTES = 24,
  crypto_box_ZEROBYTES = 32,
  crypto_box_BOXZEROBYTES = 16,

  crypto_core_salsa20_OUTPUTBYTES = 64,
  crypto_core_salsa20_INPUTBYTES = 16,
  crypto_core_salsa20_KEYBYTES = 32,
  crypto_core_salsa20_CONSTBYTES = 16,

  crypto_core_hsalsa20_OUTPUTBYTES = 32,
  crypto_core_hsalsa20_INPUTBYTES = 16,
  crypto_core_hsalsa20_KEYBYTES = 32,
  crypto_core_hsalsa20_CONSTBYTES = 16,

  crypto_hash_BYTES = 64,

  crypto_onetimeauth_BYTES = 16,
  crypto_onetimeauth_KEYBYTES = 32,

  crypto_scalarmult_BYTES = 32,
  crypto_scalarmult_SCALARBYTES = 32,

  crypto_secretbox_KEYBYTES = 32,
  crypto_secretbox_NONCEBYTES = 24,
  crypto_secretbox_ZEROBYTES = 32,
  crypto_secretbox_BOXZEROBYTES = 16,

  crypto_sign_BYTES = 64,
  crypto_sign_PUBLICKEYBYTES = 32,
  crypto_sign_SECRETKEYBYTES = 64,

  crypto_stream_xsalsa20_KEYBYTES = 32,
  crypto_stream_xsalsa20_NONCEBYTES = 24,

  crypto_stream_salsa20_KEYBYTES = 32,
  crypto_stream_salsa20_NONCEBYTES = 8,

  crypto_stream_KEYBYTES = 32,
  crypto_stream_NONCEBYTES = 24,

  crypto_verify_16_BYTES = 16,
  crypto_verify_32_BYTES = 32,
}


// ////////////////////////////////////////////////////////////////////////// //
/// set this callback to good (cryptograpic strong) random bytes generator
/// you can use /dev/urandom as prng
void delegate (ubyte[] dest) nothrow randombytes = null;


// ////////////////////////////////////////////////////////////////////////// //
/**
 * This function signs a message 'msg' using the sender's secret key 'sk'.
 * The function returns the resulting signed message.
 *
 * WARNING! This function allocates!
 *
 * Params:
 *  msg == message
 *  sk == secret key, slice size must be at least crypto_sign_SECRETKEYBYTES, extra ignored
 *  dest == destination buffer; leave `null` to allocate, or pass array of at least `msg.length+64` bytes
 *
 * Returns:
 *  signed message
 */
ubyte[] crypto_sign (const(ubyte)[] msg, const(ubyte)[] sk, ubyte[] dest=null) {
  if (sk.length < crypto_sign_SECRETKEYBYTES) assert(0, "sk too small");
  ubyte[] sm;
  if (dest.length >= msg.length+64) sm = dest[0..msg.length+64]; else sm.length = msg.length+64;
  crypto_sign(sm, msg, sk);
  return sm;
}


/**
 * This function verifies the signature in 'sm' using the receiver's public key 'pk'.
 * The function returns the message.
 *
 * WARNING! This function allocates!
 *
 * Params:
 *  sm == signed message
 *  pk == public key, slice size must be at least crypto_sign_PUBLICKEYBYTES, extra ignored
 *  dest == destination buffer; leave `null` to allocate, or pass array of at least `sm.length` bytes
 *
 * Returns:
 *  decrypted message or null on error
 */
ubyte[] crypto_sign_open (const(ubyte)[] sm, const(ubyte)[] pk, ubyte[] dest=null) {
  if (sm.length < crypto_sign_SECRETKEYBYTES) assert(0, "sm too small");
  ubyte[] msg;
  if (dest.length >= sm.length) msg = dest; else msg.length = sm.length;
  scope(exit) if (msg.length >= 64) msg[$-64..$] = 0; else if (msg.length) msg[] = 0;
  if (!crypto_sign_open(msg, sm, pk)) return null;
  return msg[0..sm.length-64]; // remove signature
}


// ////////////////////////////////////////////////////////////////////////// //
/**
 * This function checks that strings 'x' and 'y' has same content.
 *
 * Params:
 *  x = first string, slice length must be at least crypto_verify_16_BYTES, extra ignored
 *  y = second string, slice length must be at least crypto_verify_16_BYTES, extra ignored
 *
 * Returns:
 *  success flag
 */
bool crypto_verify_16 (const(ubyte)[] x, const(ubyte)[] y) @nogc {
  if (x.length < 16) assert(0, "x too small");
  if (y.length < 16) assert(0, "y too small");
  return vn(x[0..16], y[0..16]);
}

/**
 * This function checks that strings 'x' and 'y' has same content.
 *
 * Params:
 *  x = first string, slice length must be at least crypto_verify_32_BYTES, extra ignored
 *  y = second string, slice length must be at least crypto_verify_32_BYTES, extra ignored
 *
 * Returns:
 *  success flag
 */
bool crypto_verify_32 (const(ubyte)[] x, const(ubyte)[] y) @nogc {
  if (x.length < 16) assert(0, "x too small");
  if (y.length < 16) assert(0, "y too small");
  return vn(x[0..32], y[0..32]);
}

/**
 * This function encrypts a message 'msg' using a secret key 'key' and a nonce 'nonce'.
 * The function returns the ciphertext 'output'.
 *
 * Params:
 *  output = resulting ciphertext
 *  msg = message
 *  nonce = nonce
 *  key = secret key
 *
 * Returns:
 *  ciphertext in 'output'
 */
void crypto_stream_salsa20_xor (ubyte[] output, const(ubyte)[] msg, const(ubyte)[] nonce, const(ubyte)[] key) nothrow @trusted @nogc {
  if (nonce.length < crypto_stream_salsa20_NONCEBYTES) assert(0, "invalid nonce size");
  if (key.length < crypto_stream_salsa20_KEYBYTES) assert(0, "invalid key size");
  //??? msg.length == 0 || output.length <= msg.length
  ubyte[16] z; // autoclear
  ubyte[64] x = void;
  uint u;
  uint cpos = 0, mpos = 0;
  auto b = output.length;
  if (!b) return;
  z[0..8] = nonce[0..8];
  while (b >= 64) {
    crypto_core_salsa20(x[], z[], key, sigma[]);
    if (msg.length) {
      foreach (immutable v; x) output[cpos++] = msg[mpos++]^v;
    } else {
      output[cpos..cpos+64] = x[];
      cpos += 64;
    }
    u = 1;
    foreach (immutable i; 8..16) {
      u += cast(uint)z[i];
      z[i] = u&0xff;
      u >>= 8;
    }
    b -= 64;
  }
  if (b) {
    crypto_core_salsa20(x[], z[], key, sigma[]);
    if (msg !is null) {
      foreach (immutable i; 0..b) output[cpos++] = msg[mpos++]^x[i];
    } else {
      output[cpos..cpos+b] = x[0..b];
    }
  }
}

/**
 * This function produces a stream 'c' as a function of a secret key 'key'
 * and a nonce 'nonce'.
 *
 * Params:
 *  c = resulting stream
 *  nonce = nonce
 *  key = secret key
 *
 * Returns:
 *  ciphertext in 'c'
 */
void crypto_stream_salsa20 (ubyte[] c, const(ubyte)[] nonce, const(ubyte)[] key) @nogc {
  if (nonce.length < crypto_stream_salsa20_NONCEBYTES) assert(0, "invalid nonce size");
  if (key.length < crypto_stream_salsa20_KEYBYTES) assert(0, "invalid key size");
  crypto_stream_salsa20_xor(c, null, nonce, key);
}

/**
 * This function produces a stream 'c' as a function of a secret key 'key'
 * and a nonce 'nonce'.
 *
 * Params:
 *  c = output slice
 *  nonce = nonce
 *  key = secret key
 *
 * Returns:
 *  stream in 'c'
 */
void crypto_stream (ubyte[] c, const(ubyte)[] nonce, const(ubyte)[] key) @nogc {
  if (c.length == 0) assert(0, "invalid c");
  if (nonce.length < crypto_stream_NONCEBYTES) assert(0, "invalid nonce size");
  if (key.length < crypto_stream_KEYBYTES) assert(0, "invalid key size");
  ubyte[32] s = void;
  crypto_core_hsalsa20(s[], nonce, key, sigma[]);
  crypto_stream_salsa20(c, nonce[16..$], s[]);
}

/**
 * This function encrypts a message 'msg' using a secret key 'key' and a nonce 'nonce'.
 * The function returns the ciphertext 'c'.
 *
 * Params:
 *  c = output slice
 *  msg = message
 *  nonce = nonce
 *  key = secret key
 *
 * Returns:
 *  ciphertext in 'c'
 */
void crypto_stream_xor (ubyte[] c, const(ubyte)[] msg, const(ubyte)[] nonce, const(ubyte)[] key) @nogc {
  if (msg.length < c.length) assert(0, "invalid msg size");
  if (nonce.length < crypto_stream_NONCEBYTES) assert(0, "invalid nonce size");
  if (key.length < crypto_stream_KEYBYTES) assert(0, "invalid key size");
  ubyte[32] s = void;
  crypto_core_hsalsa20(s[], nonce, key, sigma[]);
  crypto_stream_salsa20_xor(c, msg, nonce[16..$], s);
}

/**
 * This function authenticates a message 'msg' using a secret key 'key'.
 * The function returns an authenticator 'output'.
 *
 * Params:
 *  output = authenticator, slice size must be at least crypto_onetimeauth_BYTES, extra ignored
 *  msg == message
 *  key == secret key, slice size must be at least crypto_onetimeauth_KEYBYTES, extra ignored
 *
 * Returns:
 *  authenticator in 'output'
 */
void crypto_onetimeauth (ubyte[] output, const(ubyte)[] msg, const(ubyte)[] key) @nogc {
  if (key.length < crypto_onetimeauth_KEYBYTES) assert(0, "invalid key size");
  if (output.length < crypto_onetimeauth_BYTES) assert(0, "invalid output size");

  uint s, u;
  uint[17] x = void, r = void, h/*autoclear*/, c = void, g = void;
  uint mpos = 0;
  auto n = msg.length;

  foreach (immutable i; 0..16) r[i] = key[i];
  r[16..17] = 0;

  r[3] &= 15;
  r[4] &= 252;
  r[7] &= 15;
  r[8] &= 252;
  r[11] &= 15;
  r[12] &= 252;
  r[15] &= 15;

  while (n > 0) {
    c[0..17] = 0;
    {
      size_t jj;
      for (jj = 0; jj < 16 && jj < n; ++jj) c[jj] = msg[mpos+jj];
      c[jj] = 1;
      mpos += jj;
      n -= jj;
    }
    add1305(h, c);
    foreach (immutable i; 0..17) {
      x[i] = 0;
      foreach (immutable j; 0..17) x[i] += h[j]*(j <= i ? r[i-j] : 320*r[i+17-j]);
    }
    h[] = x[];
    u = 0;
    foreach (immutable j; 0..16) {
      u += h[j];
      h[j] = u&255;
      u >>= 8;
    }
    u += h[16];
    h[16] = u&3;
    u = 5*(u>>2);
    foreach (immutable j; 0..16) {
      u += h[j];
      h[j] = u&255;
      u >>= 8;
    }
    u += h[16];
    h[16] = u;
  }

  g[] = h[];
  add1305(h, minusp);
  s = -(h[16]>>7);
  foreach (immutable j; 0..17) h[j] ^= s&(g[j]^h[j]);

  foreach (immutable j; 0..16) c[j] = key[j+16];
  c[16] = 0;
  add1305(h, c);
  foreach (immutable j; 0..16) output[j] = cast(ubyte)(h[j]&0xff);
}

/**
 * This function checks that 'h' is a correct authenticator of a message 'msg'
 * under the secret key 'key'.
 *
 * Params:
 *  h = authenticator, slice size must be at least crypto_onetimeauth_BYTES, extra ignored
 *  msg == message
 *  key == secret key, slice size must be at least crypto_onetimeauth_KEYBYTES, extra ignored
 *
 * Returns:
 *  success flag
 */
bool crypto_onetimeauth_verify (const(ubyte)[] h, const(ubyte)[] msg, const(ubyte)[] key) @nogc {
  if (h.length < crypto_onetimeauth_BYTES) assert(0, "invalid h size");
  if (key.length < crypto_onetimeauth_KEYBYTES) assert(0, "invalid key size");
  ubyte[16] x = void;
  crypto_onetimeauth(x, msg, key);
  return crypto_verify_16(h, x);
}

/**
 * This function encrypts and authenticates a message 'msg' using a secret
 * key 'key' and a nonce 'nonce'.
 * The function returns the resulting ciphertext 'c'.
 * Note that first 'crypto_secretbox_ZEROBYTES' in source buffer SHOULD always contains zeroes.
 * Note that first 'crypto_secretbox_BOXZEROBYTES' in destination buffer will always contains zeroes.
 *
 * Params:
 *  c = resulting cyphertext ('c' size should be at least msg.length+crypto_secretbox_ZEROBYTES)
 *  msg = message
 *  key = secret key
 *  nonce = nonce
 *
 * Returns:
 *  success flag and cyphertext in 'c' (on success)
 */
bool crypto_secretbox (ubyte[] c, const(ubyte)[] msg, const(ubyte)[] nonce, const(ubyte)[] key) @nogc {
  if (nonce.length < crypto_secretbox_NONCEBYTES) assert(0, "invalid nonce size");
  if (key.length < crypto_secretbox_KEYBYTES) assert(0, "invalid key size");
  if (msg.length > int.max/2) assert(0, "message too big");
  if (msg.length < crypto_secretbox_BOXZEROBYTES) return false;
  if (c.length < msg.length) return false;
  ubyte b = 0;
  foreach (immutable ubyte mb; msg[0..crypto_secretbox_ZEROBYTES]) b |= mb;
  if (b != 0) return false;
  crypto_stream_xor(c, msg, nonce, key);
  crypto_onetimeauth(c[16..$], c[32..$], c);
  c[0..crypto_secretbox_BOXZEROBYTES] = 0;
  return true;
}

/**
 * This function verifies and decrypts a ciphertext 'c' using a secret
 * key 'key' and a nonce 'nonce'.
 * The function returns the resulting plaintext 'output'.
 * Note that first 'crypto_secretbox_BOXZEROBYTES' in source buffer SHOULD always contains zeroes.
 * Note that first 'crypto_secretbox_ZEROBYTES' in destination buffer will always contains zeroes.
 *
 * Params:
 *  output = resulting message ('output' size should be at least msg.length+crypto_secretbox_ZEROBYTES)
 *  c = cyphertext
 *  key = secret key
 *  nonce = nonce
 *
 * Returns:
 *  success flag and message in 'output' (on success)
 */
bool crypto_secretbox_open (ubyte[] output, const(ubyte)[] c, const(ubyte)[] nonce, const(ubyte)[] key) @nogc {
  if (nonce.length < crypto_secretbox_NONCEBYTES) assert(0, "invalid nonce size");
  if (key.length < crypto_secretbox_KEYBYTES) assert(0, "invalid key size");
  if (c.length > int.max/2) assert(0, "message too big");
  if (output.length < c.length) return false;
  ubyte b = 0;
  foreach (immutable ubyte mb; c[0..crypto_secretbox_BOXZEROBYTES]) b |= mb;
  if (b != 0) return false;
  ubyte[32] x = void;
  crypto_stream(x, nonce, key);
  if (!crypto_onetimeauth_verify(c[16..$], c[32../*$*/32+(output.length-32)], x)) return false;
  crypto_stream_xor(output, c, nonce, key);
  output[0..crypto_secretbox_ZEROBYTES] = 0;
  return true;
}

/**
 * This function randomly generates a secret key and a corresponding public key.
 *
 * Params:
 *  pk = slice to put generated public key into
 *  sk = slice to put generated secret key into
 *
 * Returns:
 *  pair of new keys
 */
void crypto_box_keypair (ubyte[] pk, ubyte[] sk) {
  if (pk.length < crypto_box_PUBLICKEYBYTES) assert(0, "invalid pk size");
  if (sk.length < crypto_box_SECRETKEYBYTES) assert(0, "invalid sk size");
  randombytes(sk[0..32]);
  crypto_scalarmult_base(pk, sk);
}

/**
 * This function computes a shared secret 's' from public key 'pk' and secret key 'sk'.
 *
 * Params:
 *  skey = slice to put secret into (crypto_box_BEFORENMBYTES)
 *  pk = public
 *  sk = secret
 *
 * Returns:
 *  generated secret
 */
void crypto_box_beforenm (ubyte[] skey, const(ubyte)[] pk, const(ubyte)[] sk) @nogc {
  if (skey.length < crypto_box_BEFORENMBYTES) assert(0, "invalid skey size");
  if (pk.length < crypto_box_PUBLICKEYBYTES) assert(0, "invalid pk size");
  if (sk.length < crypto_box_SECRETKEYBYTES) assert(0, "invalid sk size");
  ubyte[32] s = void;
  crypto_scalarmult(s, sk, pk);
  crypto_core_hsalsa20(skey, zero_[], s[], sigma[]);
}

/**
 * This function encrypts and authenticates a message 'msg' using a secret
 * key 'key' and a nonce 'nonce'.
 * The function returns the resulting ciphertext 'c'.
 * Note that first 'crypto_secretbox_ZEROBYTES' in source buffer SHOULD always contains zeroes.
 * Note that first 'crypto_secretbox_BOXZEROBYTES' in destination buffer will always contains zeroes.
 *
 * Params:
 *  c = resulting cyphertext ('c' size should be at least msg.length+crypto_secretbox_ZEROBYTES)
 *  msg = message
 *  nonce = nonce
 *  key = secret
 *
 * Returns:
 *  success flag and cyphertext in 'c' (on success)
 */
bool crypto_box_afternm (ubyte[] c, const(ubyte)[] msg, const(ubyte)[] nonce, const(ubyte)[] key) @nogc {
  if (nonce.length < crypto_box_NONCEBYTES) assert(0, "invalid nonce size");
  if (key.length < crypto_box_BEFORENMBYTES) assert(0, "invalid key size");
  return crypto_secretbox(c, msg, nonce, key);
}

/**
 * This function verifies and decrypts a ciphertext 'c' using a secret
 * key 'key' and a nonce 'nonce'.
 * The function returns the resulting message 'msg'.
 * Note that first 'crypto_secretbox_ZEROBYTES' in destination buffer will always contains zeroes.
 *
 * Params:
 *  msg = resulting message ('msg' size should be at least msg.length+crypto_secretbox_ZEROBYTES)
 *  c = cyphertext
 *  nonce = nonce
 *  key = secret
 *
 * Returns:
 *  success flag and resulting message in 'msg'
 */
bool crypto_box_open_afternm (ubyte[] msg, const(ubyte)[] c, const(ubyte)[] nonce, const(ubyte)[] key) @nogc {
  if (nonce.length < crypto_box_NONCEBYTES) assert(0, "invalid nonce size");
  if (key.length < crypto_box_BEFORENMBYTES) assert(0, "invalid key size");
  return crypto_secretbox_open(msg, c, nonce, key);
}

/**
 * This function encrypts and authenticates a message 'msg' using the sender's secret
 * key 'sk', the receiver's public key 'pk', and a nonce 'nonce'.
 * The function returns the resulting ciphertext 'c'.
 * Note that first 'crypto_secretbox_ZEROBYTES' in source buffer SHOULD always contains zeroes.
 * Note that first 'crypto_secretbox_ZEROBYTES' in destination buffer will always contains zeroes.
 *
 * Params:
 *  c = resulting cyphertext ('c' size should be at least msg.length+crypto_secretbox_ZEROBYTES)
 *  msg = message
 *  nonce = nonce
 *  pk = receiver's public key
 *  sk = sender's secret key
 *
 * Returns:
 *  success flag and cyphertext in 'c'
 */
bool crypto_box (ubyte[] c, const(ubyte)[] msg, const(ubyte)[] nonce, const(ubyte)[] pk, const(ubyte)[] sk) @nogc {
  if (nonce.length < crypto_box_NONCEBYTES) assert(0, "invalid nonce size");
  if (pk.length < crypto_box_PUBLICKEYBYTES) assert(0, "invalid pk size");
  if (sk.length < crypto_box_SECRETKEYBYTES) assert(0, "invalid sk size");
  ubyte[32] k = void;
  crypto_box_beforenm(k, pk, sk);
  return crypto_box_afternm(c, msg, nonce, k);
}

/**
 * This function verifies and decrypts a ciphertext 'c' using the receiver's secret
 * key 'sk', the sender's public key 'pk', and a nonce 'nonce'.
 * The function returns the resulting message 'msg'.
 * Note that first 'crypto_secretbox_ZEROBYTES' in source buffer SHOULD always contains zeroes.
 * Note that first 'crypto_secretbox_ZEROBYTES' in destination buffer will always contains zeroes.
 *
 * Params:
 *  msg = resulting message ('msg' size should be at least msg.length+crypto_secretbox_ZEROBYTES)
 *  c = cyphertext
 *  nonce = nonce
 *  pk = receiver's public key
 *  sk = sender's secret key
 *
 * Returns:
 *  success flag and message in 'msg'
 */
bool crypto_box_open (ubyte[] msg, const(ubyte)[] c, const(ubyte)[] nonce, const(ubyte)[] pk, const(ubyte)[] sk) @nogc {
  if (nonce.length < crypto_box_NONCEBYTES) assert(0, "invalid nonce size");
  if (pk.length < crypto_box_PUBLICKEYBYTES) assert(0, "invalid pk size");
  if (sk.length < crypto_box_SECRETKEYBYTES) assert(0, "invalid sk size");
  ubyte[32] k = void;
  crypto_box_beforenm(k, pk, sk);
  return crypto_box_open_afternm(msg, c, nonce, k);
}

/**
 * This function signs a message 'msg' using the sender's secret key 'sk'.
 * The function returns the resulting signed message.
 *
 * Params:
 *  sm = buffer to receive signed message, must be of size at least msg.length+crypto_sign_BYTES
 *  msg = message
 *  sk = secret key, slice size must be at least crypto_sign_SECRETKEYBYTES, extra ignored
 *
 * Returns:
 *  signed message
 */
void crypto_sign (ubyte[] sm, const(ubyte)[] msg, const(ubyte)[] sk) @nogc {
  if (sk.length < crypto_sign_SECRETKEYBYTES) assert(0, "invalid sk size");
  if (sm.length < msg.length+64) assert(0, "invalid sm size");

  ubyte[64] d = void, h = void, r = void;
  ulong[64] x;/*autoinit*/
  long[16][4] p = void;
  auto n = msg.length;
  auto smlen = n+64;

  crypto_hash(d, sk[0..32]);
  d[0] &= 248;
  d[31] &= 127;
  d[31] |= 64;

  sm[64..64+n] = msg[];
  sm[32..64] = d[32..64];

  crypto_hash(r, sm[32..32+n+32]);
  reduce(r);
  scalarbase(p, r);
  pack(sm, p);

  sm[32..64] = sk[32..64];
  crypto_hash(h, sm[0..n+64]);
  reduce(h);

  foreach (immutable i; 0..32) x[i] = cast(ulong)r[i];
  foreach (immutable i; 0..32) foreach (immutable j; 0..32) x[i+j] += h[i]*cast(ulong)d[j];
  modL(sm[32..$], cast(long[])x);
}

/**
 * This function verifies the signature in 'sm' using the receiver's public key 'pk'.
 *
 * Params:
 *  msg = decrypted message, last crypto_sign_BYTES bytes are useless zeroes, must be of size at least sm.length-crypto_sign_BYTES
 *  sm = signed message
 *  pk = public key, slice size must be at least crypto_sign_PUBLICKEYBYTES, extra ignored
 *
 * Returns:
 *  success flag
 */
bool crypto_sign_open (ubyte[] msg, const(ubyte)[] sm, const(ubyte)[] pk) @nogc {
  if (pk.length < crypto_sign_PUBLICKEYBYTES) assert(0, "invalid pk size");
  if (msg.length < sm.length) assert(0, "invalid sm size");

  ubyte[32] t = void;
  ubyte[64] h = void;
  long[16][4] p = void, q = void;
  auto n = sm.length;

  if (n < 64) return false;

  if (!unpackneg(q, pk)) return false;
  msg[0..n] = sm[];
  msg[32..64] = pk[0..32];
  crypto_hash(h, msg);
  reduce(h);
  scalarmult(p, q, h);

  scalarbase(q, sm[32..$]);
  add(p, q);
  pack(t, p);

  n -= 64;
  if (!crypto_verify_32(sm, t)) {
    msg[0..$/*n*/] = 0;
    return false;
  }

  msg[0..n] = sm[64..64+n];
  if (msg.length > n) msg[n..$] = 0;

  return true;
}

/**
 * This function randomly generates a secret key and a corresponding public key.
 *
 * Params:
 *  pk = slice to put generated public key into
 *  sk = slice to put generated secret key into
 *
 * Returns:
 *  pair of new keys (in pk and sk)
 */
void crypto_sign_keypair (ubyte[] pk, ubyte[] sk) {
  if (pk.length < crypto_sign_PUBLICKEYBYTES) assert(0, "invalid pk size");
  if (sk.length < crypto_sign_SECRETKEYBYTES) assert(0, "invalid sk size");

  ubyte[64] d = void;
  long[16][4] p = void;

  randombytes(sk[0..32]);
  crypto_hash(d, sk[0..32]);
  d[0] &= 248;
  d[31] &= 127;
  d[31] |= 64;

  scalarbase(p, d);
  pack(pk, p);

  sk[32..64] = pk[0..32];
}


// ////////////////////////////////////////////////////////////////////////// //
private @trusted @nogc:

static immutable ubyte[16] zero_ = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0];
static immutable ubyte[32] nine_ = [9,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0];

static immutable long[16]
  gf0 = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
  gf1 = [1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
  xx121665 = [0xDB41,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
  D = [0x78a3, 0x1359, 0x4dca, 0x75eb, 0xd8ab, 0x4141, 0x0a4d, 0x0070, 0xe898, 0x7779, 0x4079, 0x8cc7, 0xfe73, 0x2b6f, 0x6cee, 0x5203],
  D2 =[0xf159, 0x26b2, 0x9b94, 0xebd6, 0xb156, 0x8283, 0x149a, 0x00e0, 0xd130, 0xeef3, 0x80f2, 0x198e, 0xfce7, 0x56df, 0xd9dc, 0x2406],
  X = [0xd51a, 0x8f25, 0x2d60, 0xc956, 0xa7b2, 0x9525, 0xc760, 0x692c, 0xdc5c, 0xfdd6, 0xe231, 0xc0a4, 0x53fe, 0xcd6e, 0x36d3, 0x2169],
  Y = [0x6658, 0x6666, 0x6666, 0x6666, 0x6666, 0x6666, 0x6666, 0x6666, 0x6666, 0x6666, 0x6666, 0x6666, 0x6666, 0x6666, 0x6666, 0x6666],
  I = [0xa0b0, 0x4a0e, 0x1b27, 0xc4ee, 0xe478, 0xad2f, 0x1806, 0x2f43, 0xd7a7, 0x3dfb, 0x0099, 0x2b4d, 0xdf0b, 0x4fc1, 0x2480, 0x2b83];

uint ld32 (const(ubyte)[] x)
in {
  assert(x.length >= 4);
}
body {
  uint u = x[3];
  u = (u<<8)|x[2];
  u = (u<<8)|x[1];
  return (u<<8)|x[0];
}

ulong dl64 (const(ubyte)[] x)
in {
  assert(x.length >= 8);
}
body {
  ulong u = x[0];
  u = (u<<8)|x[1];
  u = (u<<8)|x[2];
  u = (u<<8)|x[3];
  u = (u<<8)|x[4];
  u = (u<<8)|x[5];
  u = (u<<8)|x[6];
  return (u<<8)|x[7];
}

void st32 (ubyte[] x, uint u)
in {
  assert(x.length >= 4);
}
body {
  x[0] = u&0xff;
  x[1] = (u>>8)&0xff;
  x[2] = (u>>16)&0xff;
  x[3] = (u>>24)&0xff;
}

void ts64 (ubyte[] x, ulong u)
in {
  assert(x.length >= 8);
}
body {
  x[0] = (u>>56)&0xff;
  x[1] = (u>>48)&0xff;
  x[2] = (u>>40)&0xff;
  x[3] = (u>>32)&0xff;
  x[4] = (u>>24)&0xff;
  x[5] = (u>>16)&0xff;
  x[6] = (u>>8)&0xff;
  x[7] = u&0xff;
}

bool vn (const(ubyte)[] x, const(ubyte)[] y) @nogc
in {
  assert(x.length >= y.length);
}
body {
  uint d = 0;
  foreach (immutable i, immutable v; cast(const(ubyte)[])x) d |= v^y[i];
  return (1&((d-1)>>8)) != 0;
}

private void salsa_core(string type) (ubyte[] output, const(ubyte)[] input, const(ubyte)[] key, const(ubyte)[] constant)
if (type == "salsa" || type == "hsalsa") // constraint
in {
  // magic!
  assert(mixin(`output.length >= crypto_core_`~type~`20_OUTPUTBYTES`));
  assert(mixin(`input.length >= crypto_core_`~type~`20_INPUTBYTES`));
  assert(mixin(`key.length >= crypto_core_`~type~`20_KEYBYTES`));
  assert(mixin(`constant.length >= crypto_core_`~type~`20_CONSTBYTES`));
}
body {
  static uint ROTL32 (uint x, int c) pure @safe nothrow @nogc { return (x<<c)|((x&0xffffffff)>>(32-c)); }

  uint[16] w = void, x = void, y = void;
  uint[4] t = void;

  foreach (immutable i; 0..4) {
    x[5*i] = ld32(constant[4*i..$]);
    x[1+i] = ld32(key[4*i..$]);
    x[6+i] = ld32(input[4*i..$]);
    x[11+i] = ld32(key[16+4*i..$]);
  }

  y[] = x[];

  foreach (immutable i; 0..20) {
    foreach (immutable j; 0..4) {
      foreach (immutable m; 0..4) t[m] = x[(5*j+4*m)%16];
      t[1] ^= ROTL32(t[0]+t[3], 7);
      t[2] ^= ROTL32(t[1]+t[0], 9);
      t[3] ^= ROTL32(t[2]+t[1], 13);
      t[0] ^= ROTL32(t[3]+t[2], 18);
      for (auto m = 0; m < 4; ++m) w[4*j+(j+m)%4] = t[m];
    }
    for (auto m = 0; m < 16; ++m) x[m] = w[m];
  }

  static if (type == "hsalsa") {
    for (auto i = 0; i < 16; ++i) x[i] += y[i];
    for (auto i = 0; i < 4; ++i) {
      x[5*i] -= ld32(constant[4*i..$]);
      x[6+i] -= ld32(input[4*i..$]);
    }
    for (auto i = 0; i < 4; ++i) {
      st32(output[4*i..$], x[5*i]);
      st32(output[16+4*i..$], x[6+i]);
    }
  } else {
    for (auto i = 0; i < 16; ++i) st32(output[4*i..$], x[i]+y[i]);
  }
}

// public for testing
public void crypto_core_salsa20 (ubyte[] output, const(ubyte)[] input, const(ubyte)[] key, const(ubyte)[] constant)
{
  salsa_core!"salsa"(output, input, key, constant);
}

// public for testing
public void crypto_core_hsalsa20 (ubyte[] output, const(ubyte)[] input, const(ubyte)[] key, const(ubyte)[] constant)
{
  salsa_core!"hsalsa"(output, input, key, constant);
}

private immutable ubyte[] sigma = cast(immutable ubyte[])"expand 32-byte k";

private void add1305 (uint[] h, const(uint)[] c) {
  uint u = 0;
  foreach (immutable j; 0..17) {
    u += h[j]+c[j];
    h[j] = u&255;
    u >>= 8;
  }
}

private immutable uint[17] minusp = [5,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,252];

void car25519 (long[] o) {
  foreach (immutable i; 0..16) {
    o[i] += (1<<16);
    long c = o[i]>>16;
    o[(i+1)*(i<15)] += c-1+37*(c-1)*(i==15);
    o[i] -= c<<16;
  }
}

void sel25519 (long[] p,long[] q, int b) {
  long c = ~(b-1);
  foreach (immutable i; 0..16) {
    long t = c&(p[i]^q[i]);
    p[i] ^= t;
    q[i] ^= t;
  }
}

void pack25519 (ubyte[] o, const(long)[] n) {
  int b;
  long[16] m = void, t = void;
  t[0..16] = n[0..16];
  car25519(t);
  car25519(t);
  car25519(t);
  foreach (immutable j; 0..2) {
    m[0] = t[0]-0xffed;
    foreach (immutable i; 1..15) {
      m[i] = t[i]-0xffff-((m[i-1]>>16)&1);
      m[i-1] &= 0xffff;
    }
    m[15] = t[15]-0x7fff-((m[14]>>16)&1);
    b = (m[15]>>16)&1;
    m[14] &= 0xffff;
    sel25519(t, m, 1-b);
  }
  foreach (immutable i; 0..16) {
    o[2*i] = t[i]&0xff;
    o[2*i+1] = (t[i]>>8)&0xff;
  }
}

bool neq25519 (const(long)[] a, const(long)[] b) {
  ubyte[32] c = void, d = void;
  pack25519(c, a);
  pack25519(d, b);
  return crypto_verify_32(c, d);
}

ubyte par25519 (const(long)[] a) {
  ubyte[32] d = void;
  pack25519(d, a);
  return d[0]&1;
}

void unpack25519 (long[] o, const(ubyte)[] n) {
  foreach (immutable i; 0..16) o[i] = n[2*i]+(cast(long)n[2*i+1]<<8);
  o[15] &= 0x7fff;
}

void A (long[] o, const(long)[] a, const(long)[] b) {
  foreach (immutable i; 0..16) o[i] = a[i]+b[i];
}

void Z (long[] o, const(long)[] a, const(long)[] b) {
  foreach (immutable i; 0..16) o[i] = a[i]-b[i];
}

void M (long[] o, const(long)[] a, const(long)[] b) {
  long[31] t; // automatically becomes 0
  foreach (immutable i; 0..16) foreach (immutable j; 0..16) t[i+j] += a[i]*b[j];
  foreach (immutable i; 0..15) t[i] += 38*t[i+16];
  o[0..16] = t[0..16];
  car25519(o);
  car25519(o);
}

void S (long[] o, const(long)[] a) {
  M(o, a, a);
}

void inv25519 (long[] o, const(long)[] i) {
  long[16] c = void;
  c[] = i[0..16];
  for (auto a = 253; a >= 0; --a) {
    S(c, c);
    if (a != 2 && a != 4) M(c, c, i);
  }
  o[0..16] = c[];
}

void pow2523 (long[] o, const(long)[] i) {
  long[16] c = void;
  c[] = i[0..16];
  for(auto a = 250; a >= 0; --a) {
    S(c, c);
    if (a != 1) M(c, c, i);
  }
  o[0..16] = c[];
}

// public for testing
/* FIXME!
 * This function multiplies a group element 'p' by an integer 'n'.
 *
 * Params:
 *  p = group element
 *  n = number
 *
 * Returns:
 *  resulting group element 'q' of length crypto_scalarmult_BYTES.
 */
public void crypto_scalarmult (ubyte[] q, const(ubyte)[] n, const(ubyte)[] p) @safe nothrow @nogc
in {
  assert(q.length == crypto_scalarmult_BYTES);
  assert(n.length == crypto_scalarmult_BYTES);
  assert(p.length == crypto_scalarmult_BYTES);
}
body {
  ubyte[32] z = void;
  long[80] x = void;
  long r;
  long[16] a = void, b = void, c = void, d = void, e = void, f = void;
  z[] = n[0..32];
  z[31] = (n[31]&127)|64;
  z[0] &= 248;
  unpack25519(x, p);
  foreach (immutable i; 0..16) {
    b[i] = x[i];
    d[i] = a[i] = c[i] = 0;
  }
  a[0] = d[0] = 1;
  for (int i = 254; i >= 0; --i) {
    r = (z[i>>3]>>(i&7))&1;
    sel25519(a, b, cast(int)r);
    sel25519(c, d, cast(int)r);
    A(e, a, c);
    Z(a, a, c);
    A(c, b, d);
    Z(b, b, d);
    S(d, e);
    S(f, a);
    M(a, c, a);
    M(c, b, e);
    A(e, a, c);
    Z(a, a, c);
    S(b, a);
    Z(c, d, f);
    M(a, c, xx121665);
    A(a, a, d);
    M(c, c, a);
    M(a, d, f);
    M(d, b, x);
    S(b, e);
    sel25519(a, b, cast(int)r);
    sel25519(c, d, cast(int)r);
  }
  foreach (immutable i; 0..16) {
    x[i+16] = a[i];
    x[i+32] = c[i];
    x[i+48] = b[i];
    x[i+64] = d[i];
  }
  inv25519(x[32..$], x[32..$]);
  M(x[16..$], x[16..$], x[32..$]);
  pack25519(q, x[16..$]);
}

// public for testing
/* FIXME!
 * This function computes the scalar product of a standard group element
 * and an integer 'n'.
 *
 * Params:
 *  n = number
 *
 * Returns:
 *  resulting group element 'q' of length crypto_scalarmult_BYTES.
 */
public void crypto_scalarmult_base (ubyte[] q, const(ubyte)[] n)
in {
  assert(q.length == crypto_scalarmult_BYTES);
  assert(n.length == crypto_scalarmult_SCALARBYTES);
}
body {
  crypto_scalarmult(q, n, nine_);
}

private:
ulong R (ulong x, int c) { return (x>>c)|(x<<(64-c)); }
ulong Ch (ulong x, ulong y, ulong z) { return (x&y)^(~x&z); }
ulong Maj (ulong x, ulong y, ulong z) { return (x&y)^(x&z)^(y&z); }
ulong Sigma0 (ulong x) { return R(x, 28)^R(x, 34)^R(x, 39); }
ulong Sigma1 (ulong x) { return R(x, 14)^R(x, 18)^R(x, 41); }
ulong sigma0 (ulong x) { return R(x, 1)^R(x, 8)^(x>>7); }
ulong sigma1 (ulong x) { return R(x, 19)^R(x, 61)^(x>>6); }

immutable ulong[80] K = [
  0x428a2f98d728ae22UL, 0x7137449123ef65cdUL, 0xb5c0fbcfec4d3b2fUL, 0xe9b5dba58189dbbcUL,
  0x3956c25bf348b538UL, 0x59f111f1b605d019UL, 0x923f82a4af194f9bUL, 0xab1c5ed5da6d8118UL,
  0xd807aa98a3030242UL, 0x12835b0145706fbeUL, 0x243185be4ee4b28cUL, 0x550c7dc3d5ffb4e2UL,
  0x72be5d74f27b896fUL, 0x80deb1fe3b1696b1UL, 0x9bdc06a725c71235UL, 0xc19bf174cf692694UL,
  0xe49b69c19ef14ad2UL, 0xefbe4786384f25e3UL, 0x0fc19dc68b8cd5b5UL, 0x240ca1cc77ac9c65UL,
  0x2de92c6f592b0275UL, 0x4a7484aa6ea6e483UL, 0x5cb0a9dcbd41fbd4UL, 0x76f988da831153b5UL,
  0x983e5152ee66dfabUL, 0xa831c66d2db43210UL, 0xb00327c898fb213fUL, 0xbf597fc7beef0ee4UL,
  0xc6e00bf33da88fc2UL, 0xd5a79147930aa725UL, 0x06ca6351e003826fUL, 0x142929670a0e6e70UL,
  0x27b70a8546d22ffcUL, 0x2e1b21385c26c926UL, 0x4d2c6dfc5ac42aedUL, 0x53380d139d95b3dfUL,
  0x650a73548baf63deUL, 0x766a0abb3c77b2a8UL, 0x81c2c92e47edaee6UL, 0x92722c851482353bUL,
  0xa2bfe8a14cf10364UL, 0xa81a664bbc423001UL, 0xc24b8b70d0f89791UL, 0xc76c51a30654be30UL,
  0xd192e819d6ef5218UL, 0xd69906245565a910UL, 0xf40e35855771202aUL, 0x106aa07032bbd1b8UL,
  0x19a4c116b8d2d0c8UL, 0x1e376c085141ab53UL, 0x2748774cdf8eeb99UL, 0x34b0bcb5e19b48a8UL,
  0x391c0cb3c5c95a63UL, 0x4ed8aa4ae3418acbUL, 0x5b9cca4f7763e373UL, 0x682e6ff3d6b2b8a3UL,
  0x748f82ee5defb2fcUL, 0x78a5636f43172f60UL, 0x84c87814a1f0ab72UL, 0x8cc702081a6439ecUL,
  0x90befffa23631e28UL, 0xa4506cebde82bde9UL, 0xbef9a3f7b2c67915UL, 0xc67178f2e372532bUL,
  0xca273eceea26619cUL, 0xd186b8c721c0c207UL, 0xeada7dd6cde0eb1eUL, 0xf57d4f7fee6ed178UL,
  0x06f067aa72176fbaUL, 0x0a637dc5a2c898a6UL, 0x113f9804bef90daeUL, 0x1b710b35131c471bUL,
  0x28db77f523047d84UL, 0x32caab7b40c72493UL, 0x3c9ebe0a15c9bebcUL, 0x431d67c49c100d4cUL,
  0x4cc5d4becb3e42b6UL, 0x597f299cfc657e2aUL, 0x5fcb6fab3ad6faecUL, 0x6c44198c4a475817UL
];

void crypto_hashblocks (ubyte[] x, const(ubyte)[] m, ulong n) @safe nothrow @nogc {
  ulong[8] z = void, b = void, a = void;
  ulong[16] w = void;
  ulong t;
  uint mpos = 0;
  foreach (immutable i; 0..8) z[i] = a[i] = dl64(x[8*i..$]);
  while (n >= 128) {
    foreach (immutable i; 0..16) w[i] = dl64(m[mpos+8*i..$]);
    foreach (immutable i; 0..80) {
      b[0..8] = a[0..8];
      t = a[7]+Sigma1(a[4])+Ch(a[4], a[5], a[6])+K[i]+w[i%16];
      b[7] = t+Sigma0(a[0])+Maj(a[0], a[1], a[2]);
      b[3] += t;
      //foreach (immutable j; 0..8) a[(j+1)%8] = b[j];
      a[1..8] = b[0..7];
      a[0] = b[7];
      if (i%16 == 15) {
        foreach (immutable j; 0..16) w[j] += w[(j+9)%16]+sigma0(w[(j+1)%16])+sigma1(w[(j+14)%16]);
      }
    }
    foreach (immutable i; 0..8) { a[i] += z[i]; z[i] = a[i]; }
    mpos += 128;
    n -= 128;
  }
  foreach (immutable i; 0..8) ts64(x[8*i..$], z[i]);
}

immutable ubyte[64] iv = [
  0x6a, 0x09, 0xe6, 0x67, 0xf3, 0xbc, 0xc9, 0x08,
  0xbb, 0x67, 0xae, 0x85, 0x84, 0xca, 0xa7, 0x3b,
  0x3c, 0x6e, 0xf3, 0x72, 0xfe, 0x94, 0xf8, 0x2b,
  0xa5, 0x4f, 0xf5, 0x3a, 0x5f, 0x1d, 0x36, 0xf1,
  0x51, 0x0e, 0x52, 0x7f, 0xad, 0xe6, 0x82, 0xd1,
  0x9b, 0x05, 0x68, 0x8c, 0x2b, 0x3e, 0x6c, 0x1f,
  0x1f, 0x83, 0xd9, 0xab, 0xfb, 0x41, 0xbd, 0x6b,
  0x5b, 0xe0, 0xcd, 0x19, 0x13, 0x7e, 0x21, 0x79
];

/**
 * This function hashes a message 'msg'.
 * It returns a hash 'output'. The output length of 'output'
 * should be at least crypto_hash_BYTES.
 *
 * Params:
 *  output = resulting hash
 *  msg = message
 *
 * Returns:
 *  sha512 hash
 */
public void crypto_hash (ubyte[] output, const(ubyte)[] msg)
in {
  assert(output.length >= crypto_hash_BYTES);
}
body {
  ubyte[64] h = void;
  ubyte[256] x; /*autoinit*/
  auto n = msg.length;
  ulong b = n;
  uint mpos = 0;

  h[] = iv[];

  crypto_hashblocks(h, msg, n);
  mpos += n;
  n &= 127;
  mpos -= n;

  x[0..n] = msg[mpos..mpos+n];
  x[n] = 128;

  n = 256-128*(n<112);
  x[n-9] = b>>61;
  ts64(x[n-8..$], b<<3);
  crypto_hashblocks(h, x, n);

  output[0..64] = h;
}

private void add (ref long[16][4] p, ref long[16][4] q) {
  long[16] a = void, b = void, c = void, d = void, t = void, e = void, f = void, g = void, h = void;

  Z(a, p[1], p[0]);
  Z(t, q[1], q[0]);
  M(a, a, t);
  A(b, p[0], p[1]);
  A(t, q[0], q[1]);
  M(b, b, t);
  M(c, p[3], q[3]);
  M(c, c, D2);
  M(d, p[2], q[2]);
  A(d, d, d);
  Z(e, b, a);
  Z(f, d, c);
  A(g, d, c);
  A(h, b, a);

  M(p[0], e, f);
  M(p[1], h, g);
  M(p[2], g, f);
  M(p[3], e, h);
}

void cswap (ref long[16][4] p, ref long[16][4] q, ubyte b) {
  foreach (immutable i; 0..4) sel25519(p[i], q[i], b);
}

void pack (ubyte[] r, ref long[16][4] p) {
  long[16] tx = void, ty = void, zi = void;
  inv25519(zi, p[2]);
  M(tx, p[0], zi);
  M(ty, p[1], zi);
  pack25519(r, ty);
  r[31] ^= par25519(tx)<<7;
}

void scalarmult (ref long[16][4] p, ref long[16][4] q, const(ubyte)[] s) {
  p[0][] = gf0[];
  p[1][] = gf1[];
  p[2][] = gf1[];
  p[3][] = gf0[];
  for (int i = 255; i >= 0; --i) {
    ubyte b = (s[i/8]>>(i&7))&1;
    cswap(p, q, b);
    add(q, p);
    add(p, p);
    cswap(p, q, b);
  }
}

void scalarbase (ref long[16][4] p, const(ubyte)[] s) {
  long[16][4] q = void;
  q[0][] = X[];
  q[1][] = Y[];
  q[2][] = gf1[];
  M(q[3], X, Y);
  scalarmult(p, q, s);
}

immutable ulong[32] L = [
  0xed,0xd3,0xf5,0x5c,0x1a,0x63,0x12,0x58,0xd6,0x9c,0xf7,0xa2,0xde,0xf9,0xde,0x14,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0x10
];

void modL (ubyte[] r, long[] x) {
  long carry;
  for (auto i = 63; i >= 32; --i) {
    int j;
    carry = 0;
    for (j = i-32; j < i-12; ++j) {
      x[j] += carry-16*x[i]*L[j-(i-32)];
      carry = (x[j]+128)>>8;
      x[j] -= carry<<8;
    }
    x[j] += carry;
    x[i] = 0;
  }
  carry = 0;
  foreach (immutable j; 0..32) {
    x[j] += carry-(x[31]>>4)*L[j];
    carry = x[j]>>8;
    x[j] &= 255;
  }
  foreach (immutable j; 0..32) x[j] -= carry*L[j];
  foreach (immutable i; 0..32) {
    x[i+1] += x[i]>>8;
    r[i] = x[i]&255;
  }
}

void reduce (ubyte[] r) {
  long[64] x = void;
  foreach (immutable i; 0..64) x[i] = cast(ulong)r[i];
  r[0..64] = 0;
  modL(r, x);
}

private bool unpackneg (ref long[16][4] r, const(ubyte)[] p) {
  long[16] t = void, chk = void, num = void, den = void, den2 = void, den4 = void, den6 = void;
  r[2][] = gf1[];
  unpack25519(r[1], p);
  S(num, r[1]);
  M(den, num, D);
  Z(num, num, r[2]);
  A(den, r[2], den);

  S(den2, den);
  S(den4, den2);
  M(den6, den4, den2);
  M(t, den6, num);
  M(t, t, den);

  pow2523(t, t);
  M(t, t, num);
  M(t, t, den);
  M(t, t, den);
  M(r[0], t, den);

  S(chk, r[0]);
  M(chk, chk, den);
  if (!neq25519(chk, num)) M(r[0], r[0], I);

  S(chk, r[0]);
  M(chk, chk, den);
  if (!neq25519(chk, num)) return false;

  if (par25519(r[0]) == (p[31]>>7)) Z(r[0], gf0, r[0]);

  M(r[3], r[0], r[1]);
  return true;
}
