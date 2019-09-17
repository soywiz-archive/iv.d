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
import iv.depot;


void fatal (string msg) {
  import core.exception : ExitException;
  import std.stdio : stderr;
  stderr.writeln("FATAL: ", msg);
  throw new ExitException();
}


void main (string[] args) {
  import std.stdio;
  char[1024] buf;

  if (args.length < 2) fatal("wut?");

  try {
    auto db = new Depot("zphones.qdbm", Depot.WRITER|Depot.CREAT);
    scope(exit) delete db;

    if (args[1] == "put") {
      if (args.length != 4) fatal("put <name> <phone>");
      db.put(args[2], args[3], Depot.WMode.OVER);
    } else if (args[1] == "get") {
      if (args.length != 3) fatal("get <name>");
      auto rs = db.getwb(buf[], args[2]);
      if (rs is null) fatal("can't read record");
      writeln(args[2], " (", rs, ")");
    } else if (args[1] == "list") {
      import std.string : fromStringz;
      if (args.length != 2) fatal("list");
      // initialize the iterator
      db.itInit();
      // scan with the iterator
      char* key = null;
      usize klen;
      scope(exit) Depot.freeptr(key);
      while ((key = db.itNext(&klen)) !is null) {
        auto rs = db.getwb(buf, key[0..klen]);
        if (rs is null) fatal("can't read record");
        writeln(key[0..klen], " (", rs, ")");
        Depot.freeptr(key);
      }
    } else {
      fatal("unknown command");
    }
  } catch (DepotException de) {
    import core.exception : ExitException;
    import std.stdio : stderr;
    stderr.writeln("DEPOT FATAL: ", de.msg);
    throw new ExitException();
  }
}
