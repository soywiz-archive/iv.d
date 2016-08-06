import iv.olly.disasm2;
import iv.olly.asm1;
import iv.vfs.io;


void dasmOne (const(void)[] code, uint ip) {
  DisasmData da;
  auto len = disasm(code, ip, &da, DA_DUMP|DA_TEXT|DA_HILITE, null);
  if (len == 0) {
    writeln("ERROR: ", disErrMessage(da.errors, da.warnings));
    return;
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
}


void assit (const(char)[] cmd, uint csize, bool ideal=false) {
  import core.stdc.stdio : printf, sprintf;

  AsmModel am;
  AsmOptions opts;
  opts.ideal = ideal;
  char[1024] errtext = 0;
  char[1024] s = 0;

  foreach (uint attempt; 0..int.max) {
    writeln(cmd, ":");
    auto res = assemble(cmd, 0x400000, &am, opts, attempt, csize, errtext[]);
    auto n = sprintf(s.ptr, "%3i  ", res);
    foreach (immutable int i; 0..res) n += sprintf(s.ptr+n, "%02X ", am.code[i]);
    if (res <= 0) sprintf(s.ptr+n, "  error=\"%s\"", errtext.ptr);
    printf("%s\n", s.ptr);
    if (res <= 0) {
      writeln(cmd);
      foreach (immutable _; 0..-res-1) write('^');
      writeln('^');
      break;
    } else {
      dasmOne(am.code[], 0x400000);
    }
  }
}


void main () {
  // first try form with 32-bit immediate
  assit("Add [Dword 0x475AE0], 1", 0);

  // then variant with 8-bit immediate constant
  assit("ADD [dword 475AE0], 1", 2);

  // error, unable to determine size of operands.
  assit("MOV [475AE0],1", 4);
}
