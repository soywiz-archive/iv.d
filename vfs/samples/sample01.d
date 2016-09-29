import std.stdio;

import iv.vfs;

void main () {
  vfsRegister!"first"(new VFSDriverDiskListed("..")); // data dir, will be looked last
  //vfsAddPak("data/base.pk3"); // disk name, will not be looked in VFS

  vfsForEachFile((in ref de) {
    writeln("FILE: ", de.size, " : ", de.name);
    return 0;
  });
}
