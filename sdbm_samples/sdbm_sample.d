// GNU GPL v3
import iv.sdbm;
import iv.vfs.io;


void create () {
  auto db = new SDBM("zdb.sdb", SDBM.WRITER|SDBM.CREAT|SDBM.NOLCK);
  scope(exit) delete db;
  db.put("key0", "value0");
  db.put("key1", "value1");
}


void read () {
  auto db = new SDBM("zdb.sdb", SDBM.READER|SDBM.NOLCK);
  scope(exit) delete db;
  writeln(db.get!string("key0"));
  writeln(db.get!string("key1"));
}


void main () {
  create();
  read();
}
