import iv.tinycdb, iv.tinycdbmk;
import std.stdio : writeln, writefln;


void fi (ref CDB cdb, string key) {
  writeln("=== ", key, " ===");
  auto it = cdb.findFirst(key);
  while (!it.empty) {
    writeln(" [", cast(const(char)[])it.front, "]");
    it.popFront();
  }
}


void fk (ref CDB cdb, string key) {
  auto val = cdb.find(key);
  if (val !is null) {
    writeln("[", key, "] = [", cast(const(char)[])val, "]");
  } else {
    writeln("[", key, "] = NOT FOUND!");
  }
}


void main () {
  writefln("0x%08x", CDB.hash("key0"));
  {
    auto mk = CDBMaker("z.cdb");
    mk.put("key0", "fuck");
    mk.put("key1", "ass");
    mk.put("key0", "shit");
    mk.put("key1", "piss", mk.PUT_INSERT);
    mk.put("key3", "urine", mk.PUT_INSERT);
    if (!mk.close()) assert(0, "CDB WRITE ERROR!");
  }
  {
    auto cdb = CDB("z.cdb");
    cdb.fi("key0");
    cdb.fk("key0");
    cdb.fk("key1");
    cdb.fk("key2");
    cdb.fk("key3");
  }
}
