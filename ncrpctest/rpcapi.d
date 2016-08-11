module rpcapi;

import iv.vfs.io;


// ////////////////////////////////////////////////////////////////////////// //
@NCRPCEP string[] getList (int id, int di=42, string ds="Alice") {
  writeln("getList: id=", id);
  writeln("getList: di=", di);
  writeln("getList: ds=", ds);
  return ["boo"];
}


// ////////////////////////////////////////////////////////////////////////// //
public bool doQuit = false;
@NCRPCEP void quit () { doQuit = true; }
