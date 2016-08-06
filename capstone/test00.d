import iv.capstone;

immutable(ubyte)[] CODE = cast(immutable(ubyte)[])"\x55\x48\x8b\x05\xb8\x13\x00\x00";

void main () {
 csh handle;
 cs_insn* insn;
 usize count;

 if (cs_open(CS_ARCH_X86, CS_MODE_32, &handle) != CS_ERR_OK) assert(0, "can't initialize capstone");
 scope(exit) cs_close(&handle);

 count = cs_disasm(handle, CODE.ptr, CODE.length-1, 0x1000, 0, &insn);
 if (count > 0) {
   foreach (immutable j; 0..count) {
     import core.stdc.stdio : printf;
     printf("0x%08x: %-8s %s\n", cast(uint)insn[j].address, insn[j].mnemonic.ptr, insn[j].op_str.ptr);
   }
   cs_free(insn, count);
 } else {
   import core.stdc.stdio : printf;
   printf("ERROR: Failed to disassemble given code!\n");
  }
}
