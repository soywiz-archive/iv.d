import iv.keystone;
import std.stdio;


// separate assembly instructions by ; or \n
immutable string CODE = "INC ecx; DEC edx";

void main () {
  ks_engine *ks;
  ks_err err;
  usize count;
  ubyte* encode;
  usize size;

  err = ks_open(KS_ARCH_X86, KS_MODE_32, &ks);
  if (err != KS_ERR_OK) assert(0, "FATAL: can't init keystone");

  if (ks_asm(ks, CODE.ptr, 0, &encode, &size, &count) != KS_ERR_OK) {
    import std.string : fromStringz;
    writefln("ERROR: ks_asm() failed & count = %s, error = %s (%s)", count, ks_errno(ks), ks_strerror(ks_errno(ks)).fromStringz);
  } else {
    writefln("%s = ", CODE);
    foreach (immutable i; 0..size) writef("%02x ", encode[i]);
    writeln();
    writefln("Compiled: %s bytes, statements: %s", size, count);
  }

  // NOTE: free encode after usage to avoid leaking memory
  ks_free(encode);

  // close Keystone instance when done
  ks_close(ks);
}
