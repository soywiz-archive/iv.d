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
