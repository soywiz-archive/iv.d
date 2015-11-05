import std.stdio;
import iv.gcrypt;

enum KEY = "Secret";


void main () {
  import core.stdc.stdlib : malloc, free;
  import core.stdc.string : strlen, strcpy;
  import core.stdc.stdio : stderr, printf, fprintf;

  gcry_cipher_hd_t handle;
  gcry_cipher_hd_t handle2;
  gcry_error_t err = 0;
  char* plain_text;
  char* outbuf;
  char* deout;

  plain_text = cast(char*)malloc(1024);
  strcpy(plain_text, "Attack at dawn");

  outbuf = cast(char*)malloc(strlen(plain_text)+1);
  deout = cast(char*)malloc(strlen(plain_text)+1);

  gcry_check_version(null);
  gcry_control(GCRYCTL_DISABLE_SECMEM_WARN);
  gcry_control(GCRYCTL_INIT_SECMEM, 16384, 0);

  err = gcry_cipher_open(&handle2, GCRY_CIPHER_ARCFOUR, GCRY_CIPHER_MODE_STREAM, 0);
  if (err) fprintf(stderr, "Failure: %s/%s\n", gcry_strsource(err), gcry_strerror(err));

  err = gcry_cipher_open(&handle, GCRY_CIPHER_ARCFOUR, GCRY_CIPHER_MODE_STREAM, 0);
  if (err) fprintf(stderr, "Failure: %s/%s\n", gcry_strsource(err), gcry_strerror(err));

  err = gcry_cipher_setkey(handle, KEY.ptr, KEY.length);
  if (err) fprintf(stderr, "Failure: %s/%s\n", gcry_strsource(err), gcry_strerror(err));

  err = gcry_cipher_setkey(handle2, KEY.ptr, KEY.length);
  if (err) fprintf(stderr, "Failure: %s/%s\n", gcry_strsource(err), gcry_strerror(err));

  err = gcry_cipher_encrypt(handle, cast(ubyte*)outbuf, strlen(plain_text)+1, cast(const(ubyte)*)plain_text, strlen(plain_text)+1);
  if (err) fprintf(stderr, "Failure: %s/%s\n", gcry_strsource(err), gcry_strerror(err));

  for (int idx = 0; idx < strlen(plain_text); ++idx) {
    uint ch = outbuf[idx];
    printf("%02X", ch);
  }
  printf("\n");
  // 45A01F645FC35B383552544B9BF5
  // 45A01F645FC35B383552544B9BF5

  err = gcry_cipher_encrypt(handle2, cast(ubyte*)deout, strlen(plain_text)+1, cast(const(ubyte)*)outbuf, strlen(plain_text)+1);
  if (err) fprintf(stderr, "Failure: %s/%s\n", gcry_strsource(err), gcry_strerror(err));
  printf("%s|\n", deout);

  free(plain_text);
  free(outbuf);
  free(deout);

  gcry_cipher_close(handle);
  gcry_cipher_close(handle2);
}
