import iv.ncserial;
import iv.vfs.io;

import sockchan;
import rpcapi;


void main () {
  UDSocket sk;
  sk.connect("/k8/rpc-test");
  auto res = sk.rpcall!getList(666);
  writeln("result: ", res);
  auto list = sk.rpcallany!(string[])("listEndpoints");
  writeln(list.length, " endpoints found");
  foreach (string s; list) writeln("  ", s);
  sk.rpcall!quit;
}
