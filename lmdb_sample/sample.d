/* Invisible Vector Library
 * coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * Understanding is not required. Only obedience.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 3 of the License ONLY.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */
pragma(lib, "lmdb");
import iv.lmdb;


private void lmdbDo (int rc, string msg) {
  if (rc) {
    import core.exception : ExitException;
    import std.stdio : stderr;
    import std.string : fromStringz;
    stderr.writeln("FATAL(", rc, "): ", msg, "() failed: ", mdb_strerror(rc).fromStringz);
    throw new ExitException();
  }
}


void main () {
  import std.exception : collectException;
  import std.file : mkdir;

  int rc;
  MDB_envp env;
  MDB_dbi dbi;
  MDB_val key, data;
  MDB_txnp txn;
  MDB_cursorp cursor;
  char[32] sval;

  {
    import std.stdio : writeln;
    import std.string : fromStringz;
    int major, minor, patch;
    auto ver = mdb_version(&major, &minor, &patch);
    writeln("ver=", ver.fromStringz, "; major=", major, "; minor=", minor, "; patch=", patch);
  }

  lmdbDo(mdb_env_create(&env), "mdb_env_create");

  collectException(mkdir("testdb"));
  lmdbDo(env.mdb_env_open("./testdb", 0, 0o664), "mdb_env_open");
  scope(exit) env.mdb_env_close();

  lmdbDo(env.mdb_txn_begin(null, 0, &txn), "mdb_txn_begin");
  scope(exit) txn.mdb_txn_abort();

  lmdbDo(txn.mdb_dbi_open(null, 0, &dbi), "mdb_dbi_open");
  scope(exit) env.mdb_dbi_close(dbi);

  key.mv_size = int.sizeof;
  key.mv_data = cast(void *)sval;
  data.mv_size = sval.sizeof;
  data.mv_data = cast(void *)sval;

  {
    import core.stdc.stdio : sprintf;
    sprintf(cast(char *)sval, "%03x %d foo bar", 32, 3141592);
  }

  lmdbDo(txn.mdb_put(dbi, &key, &data, 0), "mdb_put");
  lmdbDo(txn.mdb_txn_commit(), "mdb_txn_commit");

  lmdbDo(env.mdb_txn_begin(null, MDB_RDONLY, &txn), "mdb_txn_begin");

  lmdbDo(txn.mdb_cursor_open(dbi, &cursor), "mdb_cursor_open");
  scope(exit) cursor.mdb_cursor_close();

  while ((rc = cursor.mdb_cursor_get(&key, &data, MDB_NEXT)) == 0) {
    import core.stdc.stdio : printf;
    printf("key: %p %.*s, data: %p %.*s\n",
      key.mv_data,  cast(int) key.mv_size,  cast(char *) key.mv_data,
      data.mv_data, cast(int) data.mv_size, cast(char *) data.mv_data);
  }
}
