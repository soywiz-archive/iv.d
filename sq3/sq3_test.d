module sq3_test is aliced;

import std.stdio;

import iv.sq3;


////////////////////////////////////////////////////////////////////////////////
void main () {
  auto db = Database("/tmp/pktool.db");
  foreach (ref row; db.statement("SELECT * FROM packages WHERE id >= :idl AND id <= :idh").bind("idl", 1).bind("idh", 5).range) {
    writeln("index=", row.index_, "; id=", row.id!uint, "; name=", row.name!stringc);
  }
  auto rng = db.statement("SELECT * FROM packages WHERE id=:id").bind("id", 1).range;
  if (rng.empty) {
    writeln("NO 1!");
  } else {
    writeln(rng.front.name!stringc);
    rng.popFront();
    assert(rng.empty);
  }
}
