import iv.ncrpc;
import iv.vfs.io;

import rpcapi;


public bool doQuit = false;


string[] delegate () listEndpoints;


void main () {
  rpcRegisterEndpoint!getList(delegate (int id, int di, string ds) {
    writeln("getList: id=", id);
    writeln("getList: di=", di);
    writeln("getList: ds=", ds);
    return ["boo"];
  });

  rpcRegisterEndpoint!quit(() { doQuit = true; });

  //rpcRegisterEndpoint!listEndpoints;
  rpcRegisterEndpoint!listEndpoints(() { return rpcEndpointNames; });

  writeln(rpcEndpointNames);
  UDSocket sk;
  sk.create("/k8/rpc-test");
  writeln("waiting for client...");
  auto cl = sk.accept();
  writeln("client comes.");
  for (;;) {
    auto cmd = cl.readNum!ushort;
    if (cmd != RPCommand.Call) throw new Exception("invalid command");
    cl.rpcProcessCall;
    if (doQuit) break;
  }
}
