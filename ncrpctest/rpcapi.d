module rpcapi is aliced;


// ////////////////////////////////////////////////////////////////////////// //
string[] delegate (int id, int di=42, string ds="Alice") getList;
void delegate () quit;
