import iv.ncserial;
import iv.vfs.io;

import sockchan;
import rpcapi;

/*export*/ string[] listEndpoints () {
  return rpcEndpointNames;
}


void main () {
  rpcRegisterModuleEndpoints!rpcapi;
  rpcRegisterEndpoint!listEndpoints;
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
