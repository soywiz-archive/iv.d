import std.stdio;

import iv.vfs;

void main () {
  vfsRegister!"first"(new VFSDriverDisk("data")); // data dir, will be looked last
  vfsAddPak("data/base.pk3"); // disk name, will not be looked in VFS

  {
    auto fl = vfsOpenFile("./ztest00.d"); // disk name, will not be looked in VFS -- due to "./"
    writeln(fl.size);
    fl.seek(1);
    char[4] s;
    fl.rawReadExact(s[]);
    writeln(s);
    fl.close();
  }

  {
    auto fl = vfsOpenFile("shaders/srscanlines.frag");
    writeln(fl.size);
    writeln(fl.tell);
    fl.seek(1);
    char[4] s;
    fl.rawReadExact(s[]);
    writeln(s);
    writeln(fl.tell);
    fl.close();
  }

  {
    auto fl = vfsOpenFile("playpal.pal");
    writeln(fl.size);
    writeln(fl.tell);
    fl.seek(1);
    ubyte[3] s;
    fl.rawReadExact(s[]);
    writeln(fl.tell);
    assert(s[] == [0, 0, 7]);
    fl.close();
  }
}
