import iv.olly.disasm2;
import iv.vfs.io;


int test () {
  return 42;
}


int decodeaddress (char* s, uint addr) {
  if (addr == cast(uint)&test) {
    import core.stdc.stdio;
    return sprintf(s, "fn_test");
  }
  return 0;
}


void main () {
  DisasmData da;
  auto code = cast(const(ubyte)*)&test;
  foreach (immutable _; 0..8) {
    auto len = disasm(code[0..64], cast(uint)&test, &da, DA_DUMP|DA_TEXT|DA_HILITE, null, (char *s, uint addr) => decodeaddress(s, addr));
    if (len == 0) {
      writeln("ERROR: ", disErrMessage(da.errors, da.warnings));
      break;
    }
    writeln("====== command length: ", len, " ======");
    writefln("ip=0x%08x", da.ip);
    writeln("size=", da.size);
    writefln("cmdtype=0x%08x", da.cmdtype);
    writefln("exttype=0x%08x", da.exttype);
    writefln("prefixes=0x%08x", da.prefixes);
    writefln("nprefix=%s", da.nprefix);
    writefln("memfixup=%s", da.memfixup);
    writefln("immfixup=%s", da.immfixup);
    writefln("errors=0x%08x", da.errors);
    writefln("warnings=0x%08x", da.warnings);
    writefln("uses=0x%08x", da.uses);
    writefln("modifies=0x%08x", da.modifies);
    writefln("memconst=0x%08x", da.memconst);
    writefln("stackinc=%s", da.stackinc);
    writeln("hex dump: [", da.dumpstr, "]");
    writeln("result: [", da.resstr, "]");
    writeln("mask: [", da.maskstr, "]");
    code += len;
  }
}
