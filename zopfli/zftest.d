import std.stdio;
import iv.zopfli;


void main (string[] args) {
  if (args.length != 3) assert(0, "args?!");

  ubyte[] indata;
  void* odata;
  size_t osize;
  {
    auto fl = File(args[1]);
    indata.length = cast(uint)fl.size;
    fl.rawRead(indata[]);
  }

  ZopfliOptions opts;
  ZopfliCompress(opts, ZOPFLI_FORMAT_ZLIB, indata.ptr, indata.length, &odata, &osize);
  writeln("osize=", osize);

  {
    auto fo = File(args[2], "w");
    fo.rawWrite(odata[0..osize]);
  }

  ZopfliFree(odata);
}
