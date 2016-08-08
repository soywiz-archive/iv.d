import iv.olly.disasm2;
import iv.olly.asm1;
import iv.olly.assembler;
import iv.vfs.io;


static immutable string injectCode = q{
  ; choose the amount of memory to allocate with malloc() based on the size
  ; of the path to the shared library passed via ecx
  push 4096     ; 1st argument to malloc
  call malloc   ; call malloc
  add esp,4     ; as it is cdecl, we need to pop arguments
  push eax      ; save buffer address
  int3          ; break back in so that the injector can fill the buffer

  ; here we have buffer start address on the stack

  pop esi      ; buffer address
  push esi     ; save it again

  ; call __libc_dlopen_mode() to load the shared library
  push 1       ; 2nd argument to __libc_dlopen_mode(): flag = RTLD_LAZY
  push esi     ; 1st argument to __libc_dlopen_mode(): filename = the buffer we allocated earlier
  call dlopen  ; call __libc_dlopen_mode()
  add esp,8    ; as it is cdecl, we need to pop arguments
  int3         ; break back in so that the injector can check result and abort if necessary

  mov  edx,eax ; save lib handle

  ; skip first string (lib path)
  pop esi      ; buffer address
  push esi     ; we will need it later
  xor eax,eax
  mov ecx,4096
  repne scasb
  inc esi
  ; save address to continue skipping later
  push esi

  ; here we have buffer start address and buffer temp address on the stack

  ; call __libc_dlsym() to find the symbol
  push esi     ; 2nd argument to __libc_dlsym() -- function name
  push edx     ; 1st argument to __libc_dlsym() -- library handle
  call dlsym   ; call __libc_dlsym()
  add esp,8    ; as it is cdecl, we need to pop arguments

  ; call the function (injector will skip it if eax is 0)
  or eax,eax
  jz skipcall
  mov edx,eax  ; edx is init function address now

  ; skip function name
  pop esi      ; buffer address
  push esi     ; we will need it later
  xor eax,eax
  mov ecx,4096
  repne scasb
  inc esi

  push esi     ; argument
  call edx     ; call init function
  add esp,4    ; as it is cdecl, we need to pop arguments

skipcall:
  ; here we have buffer start address and buffer temp address on the stack
  add esp,4    ; drop temporary buffer address

  ; call free() on the previously malloced buffer; argument is already on the stack
  call free    ; call free()
  add esp,4    ; as it is cdecl, we need to pop arguments
  int3         ; final out
};


void main (string[] args) {
  enum ijAddr = 0x400000;
  auto ass = new Assembler(ijAddr);
  writeln("collecting...");
  ass.addLabel("malloc", 666);
  ass.addLabel("free", 667);
  ass.addLabel("dlopen", 668);
  ass.addLabel("dlsym", 669);
  if (args.length > 1) {
    auto fl = VFile(args[1]);
    auto tx = new char[](cast(uint)fl.size);
    fl.rawReadExact(tx);
    ass.addLines(tx);
  } else {
    ass.addLines(injectCode);
  }
  writeln("assembling...");
  auto ijcode = ass.getCode();
  writeln("assembled to ", ijcode.length, " bytes");
  ass.disasmCode(ijcode, ass.orgpc);
}
