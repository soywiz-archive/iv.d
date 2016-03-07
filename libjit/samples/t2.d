/*
Tutorial 2 - gcd

Builds and compiles the following function:

unsigned int gcd(unsigned int x, unsigned int y)
{
    if(x == y)
    {
        return x;
    }
    else if(x < y)
    {
        return gcd(x, y - x);
    }
    else
    {
        return gcd(x - y, y);
    }
}
*/
import core.stdc.stdio;
import iv.libjit;


void main () {
  jit_context_t context;
  jit_type_t[2] params;
  jit_type_t signature;
  jit_function_t function_;
  jit_value_t x, y;
  jit_value_t temp1, temp2;
  jit_value_t temp3, temp4;
  jit_value_t[2] temp_args;
  jit_label_t label1 = jit_label_undefined;
  jit_label_t label2 = jit_label_undefined;
  jit_uint arg1, arg2;
  void*[2] args;
  jit_uint result;

  /* Create a context to hold the JIT's primary state */
  context = jit_context_create();

  /* Lock the context while we build and compile the function */
  jit_context_build_start(context);

  /* Build the function signature */
  params[0] = jit_type_uint;
  params[1] = jit_type_uint;
  signature = jit_type_create_signature(jit_abi_cdecl, jit_type_uint, params.ptr, 2, 1);

  /* Create the function object */
  function_ = jit_function_create(context, signature);
  jit_type_free(signature);

  /* Check the condition "if(x == y)" */
  x = jit_value_get_param(function_, 0);
  y = jit_value_get_param(function_, 1);
  temp1 = jit_insn_eq(function_, x, y);
  jit_insn_branch_if_not(function_, temp1, &label1);

  /* Implement "return x" */
  jit_insn_return(function_, x);

  /* Set "label1" at this position */
  jit_insn_label(function_, &label1);

  /* Check the condition "if(x < y)" */
  temp2 = jit_insn_lt(function_, x, y);
  jit_insn_branch_if_not(function_, temp2, &label2);

  /* Implement "return gcd(x, y - x)" */
  temp_args[0] = x;
  temp_args[1] = jit_insn_sub(function_, y, x);
  temp3 = jit_insn_call(function_, "gcd", function_, null, temp_args.ptr, 2, 0);
  jit_insn_return(function_, temp3);

  /* Set "label2" at this position */
  jit_insn_label(function_, &label2);

  /* Implement "return gcd(x - y, y)" */
  temp_args[0] = jit_insn_sub(function_, x, y);
  temp_args[1] = y;
  temp4 = jit_insn_call(function_, "gcd", function_, null, temp_args.ptr, 2, 0);
  jit_insn_return(function_, temp4);

  /* Compile the function */
  jit_function_compile(function_);

  /* Unlock the context */
  jit_context_build_end(context);

  /* Execute the function and print the result */
  arg1 = 27;
  arg2 = 14;
  args[0] = &arg1;
  args[1] = &arg2;
  jit_function_apply(function_, args.ptr, &result);
  printf("gcd(27, 14) = %u\n", cast(uint)result);

  /* Clean up */
  jit_context_destroy(context);
}
