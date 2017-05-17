module rpcapi /*is aliced*/;
import iv.alice;


// ////////////////////////////////////////////////////////////////////////// //
string[] delegate (int id, int di=42, string ds="Alice") getList;
void delegate () quit;
