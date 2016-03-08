/*

Tutorial 4 - mul_add, C++ version

Builds and compiles the following function:

int mul_add(int x, int y, int z)
{
  return x * y + z;
}

Differs from Tutorial 3 in that this version is written in C++.

*/
import core.stdc.stdio;
import iv.libjit.d;


class mul_add_function : JitFunction {
public:
  this (JitContext context) {
    super(context);
    create();
    recompilable = true;
  }

  override void build () {
    printf("Compiling mul_add on demand\n");

    JitValue x = getParam(0);
    JitValue y = getParam(1);
    JitValue z = getParam(2);

    insn_return(x*y+z);
  }

protected:
  override jit_type_t createSignature () {
    // Return type, followed by three parameters.
    return signatureHelper(jit_type_int, jit_type_int, jit_type_int, jit_type_int);
  }
}


void main () {
  jit_int arg1, arg2, arg3;
  void*[3] args;
  jit_int result;

  // Create a context to hold the JIT's primary state.
  auto context = new JitContext();

  // Create the function object.
  auto mul_add = new mul_add_function(context);

  // Execute the function and print the result.  This will arrange
  // to call "mul_add_function::build" to build the function's body.
  arg1 = 3;
  arg2 = 5;
  arg3 = 2;
  args[0] = &arg1;
  args[1] = &arg2;
  args[2] = &arg3;
  mul_add.apply(args, &result);
  printf("mul_add(3, 5, 2) = %d\n", cast(int)result);

  // Execute the function again, to demonstrate that the
  // on-demand compiler is not invoked a second time.
  arg1 = 13;
  arg2 = 5;
  arg3 = 7;
  args[0] = &arg1;
  args[1] = &arg2;
  args[2] = &arg3;
  mul_add.apply(args, &result);
  printf("mul_add(13, 5, 7) = %d\n", cast(int)result);

  // Force the function to be recompiled.
  mul_add.buildStart();
  mul_add.build();
  mul_add.compile();
  mul_add.buildEnd();

  // Execute the function a third time, after it is recompiled.
  arg1 = 2;
  arg2 = 18;
  arg3 = -3;
  args[0] = &arg1;
  args[1] = &arg2;
  args[2] = &arg3;
  mul_add.apply(args, &result);
  printf("mul_add(2, 18, -3) = %d\n", cast(int)result);
}
