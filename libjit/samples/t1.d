/*
Tutorial 1 - mul_add

Builds and compiles the following function:

int mul_add(int x, int y, int z)
{
  return x * y + z;
}
*/
import core.stdc.stdio;
import iv.libjit;


void main () {
  jit_context_t context;
  jit_type_t[3] params;
  jit_type_t signature;
  jit_function_t function_;
  jit_value_t x, y, z;
  jit_value_t temp1, temp2;
  jit_int arg1, arg2, arg3;
  void*[3] args;
  jit_int result;

  /* Create a context to hold the JIT's primary state */
  context = jit_context_create();

  /* Lock the context while we build and compile the function */
  jit_context_build_start(context);

  /* Build the function signature */
  params[0] = jit_type_int;
  params[1] = jit_type_int;
  params[2] = jit_type_int;
  signature = jit_type_create_signature(jit_abi_cdecl, jit_type_int, params.ptr, 3, 1);

  /* Create the function object */
  function_ = jit_function_create(context, signature);
  jit_type_free(signature);

  /* Construct the function body */
  x = jit_value_get_param(function_, 0);
  y = jit_value_get_param(function_, 1);
  z = jit_value_get_param(function_, 2);
  temp1 = jit_insn_mul(function_, x, y);
  temp2 = jit_insn_add(function_, temp1, z);
  jit_insn_return(function_, temp2);

  /* Compile the function */
  jit_function_compile(function_);

  /* Unlock the context */
  jit_context_build_end(context);

  /* Execute the function and print the result */
  arg1 = 3;
  arg2 = 5;
  arg3 = 2;
  args[0] = &arg1;
  args[1] = &arg2;
  args[2] = &arg3;
  jit_function_apply(function_, args.ptr, &result);
  printf("mul_add(3, 5, 2) = %d\n", cast(int)result);

  /* Clean up */
  jit_context_destroy(context);
}
