/*
 * D binding for the JIT library.
 *
 * Copyright (C) 2004  Southern Storm Software, Pty Ltd.
 * Copyright (C) 2016  Ketmar Dark
 *
 * The libjit library is free software: you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public License
 * as published by the Free Software Foundation, either version 2.1 of
 * the License, or (at your option) any later version.
 *
 * The libjit library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with the libjit library.  If not, see
 * <http://www.gnu.org/licenses/>.
 */
module iv.libjit.d;

public import iv.libjit;


// ////////////////////////////////////////////////////////////////////////// //
public class JitException : Exception {
  //private import std.exception : basicExceptionCtors;
  //mixin basicExceptionCtors;
  this (int aresult, string file = __FILE__, usize line = __LINE__, Throwable next = null) @nogc @safe pure nothrow { result = aresult; super("libjit error", file, line, next); }
  this (int aresult, Throwable next, string file = __FILE__, usize line = __LINE__) @nogc @safe pure nothrow { result = aresult; super("libjit error", file, line, next); }

  int result;

  static string result2str (int res) {
    import std.conv : to;
    switch (res) {
      case JIT_RESULT_OK: return "no error";
      case JIT_RESULT_OVERFLOW: return "overflow";
      case JIT_RESULT_ARITHMETIC: return "arithmetic";
      case JIT_RESULT_DIVISION_BY_ZERO: return "division by zero";
      case JIT_RESULT_COMPILE_ERROR: return "compile error";
      case JIT_RESULT_OUT_OF_MEMORY: return "out of memory";
      case JIT_RESULT_NULL_REFERENCE: return "null reference";
      case JIT_RESULT_NULL_FUNCTION: return "null function";
      case JIT_RESULT_CALLED_NESTED: return "called nested";
      case JIT_RESULT_OUT_OF_BOUNDS: return "out of bounds";
      case JIT_RESULT_UNDEFINED_LABEL: return "undefined label";
      case JIT_RESULT_MEMORY_FULL: return "memory full";
      default:
    }
    return "unknown error #"~to!string(res);
  }

  override string toString() {
    import std.string : format;
    return "*** libjit error %s\n%s".format(result2str(result), super.toString());
  }
}


// ////////////////////////////////////////////////////////////////////////// //
struct JitValue {
private:
  jit_value_t value;

public:
  this (jit_value_t value) pure nothrow { this.value = value; }
  this (JitValue value) pure nothrow { this.value = value.value; }

final:
  ref JitValue opAssign() (in auto ref JitValue value) pure nothrow { this.value = value.value; return this; }

  @property inout(jit_value_t) raw () inout pure nothrow @safe @nogc { return value; }
  bool is_valid () const pure nothrow { return (value !is null); }

  bool is_temporary () nothrow { return (jit_value_is_temporary(value) != 0); }
  bool is_local () nothrow { return (jit_value_is_local(value) != 0); }
  bool is_constant () nothrow { return (jit_value_is_constant(value) != 0); }
  bool is_parameter () nothrow { return (jit_value_is_parameter(value) != 0); }

  void set_volatile () { jit_value_set_volatile(value); }
  bool is_volatile() nothrow { return (jit_value_is_volatile(value) != 0); }

  void set_addressable() { jit_value_set_addressable(value); }
  bool is_addressable () nothrow { return (jit_value_is_addressable(value) != 0); }

  jit_type_t type () { return jit_value_get_type(value); }
  jit_function_t func () { return jit_value_get_function(value); }
  jit_block_t block () { return jit_value_get_block(value); }
  jit_context_t context () { return jit_value_get_context(value); }

  jit_constant_t constant () { return jit_value_get_constant(value); }
  jit_nint nint_constant () { return jit_value_get_nint_constant(value); }
  jit_long long_constant () { return jit_value_get_long_constant(value); }
  jit_float32 float32_constant () { return jit_value_get_float32_constant(value); }
  jit_float64 float64_constant () { return jit_value_get_float64_constant(value); }
  jit_nfloat nfloat_constant () { return jit_value_get_nfloat_constant(value); }

  private enum UnOpMixin(string op, string insn) =
    "JitValue opUnary(string op : "~op.stringof~") () {\n"~
    "  pragma(inline, true);\n"~
    "  return JitValue(jit_insn_"~insn~"(jit_value_get_function(this), this.raw));\n"~
    "}";

  mixin(UnOpMixin!("-", "neg"));
  mixin(UnOpMixin!("~", "not"));


  private enum BinOpMixin(string op, string insn) =
    "JitValue opBinary(string op : "~op.stringof~") (JitValue rhs) {\n"~
    "  pragma(inline, true);\n"~
    "  return JitValue(jit_insn_"~insn~"(value_owner(this, rhs), this.raw, rhs.raw));\n"~
    "}";

  mixin(BinOpMixin!("+", "add"));
  mixin(BinOpMixin!("-", "sub"));
  mixin(BinOpMixin!("*", "mul"));
  mixin(BinOpMixin!("/", "div"));
  mixin(BinOpMixin!("%", "rem"));
  mixin(BinOpMixin!("&", "and"));
  mixin(BinOpMixin!("|", "or"));
  mixin(BinOpMixin!("^", "xor"));
  mixin(BinOpMixin!("<<", "shl"));
  mixin(BinOpMixin!(">>", "shr"));

  // the following should be explicitly instantiated, like `l.opBinary!"<"(r)`
  mixin(BinOpMixin!("<", "lt"));
  mixin(BinOpMixin!(">", "gt"));
  mixin(BinOpMixin!("==", "eq"));
  mixin(BinOpMixin!("!=", "ne"));
  mixin(BinOpMixin!("<=", "le"));
  mixin(BinOpMixin!(">=", "ge"));

private:
  // Get the function that owns a pair of values.  It will choose
  // the function for the first value, unless it is NULL (e.g. for
  // global values).  In that case, it will choose the function
  // for the second value.
  static jit_function_t value_owner (JitValue value1, JitValue value2) {
    pragma(inline, true);
    jit_function_t func = jit_value_get_function(value1.raw);
    return (func !is null ? func : jit_value_get_function(value2.raw));
  }
}


// ////////////////////////////////////////////////////////////////////////// //
struct JitLabel {
private:
  jit_label_t label = jit_label_undefined;

public:
  this (jit_label_t label) { this.label = label; }
  this (JitLabel label) { this.label = label.label; }

final:
  @property inout(jit_label_t) raw () inout const pure nothrow @safe @nogc { return label; }
  @property jit_label_t* rawp () pure nothrow @nogc { return &label; }
  bool is_valid () const pure nothrow @safe @nogc { return (label != jit_label_undefined); }

  ref JitLabel opAssign (JitLabel value) pure nothrow { this.label = value.label; return this; }
}


// ////////////////////////////////////////////////////////////////////////// //
struct JitJumpTable {
private:
  jit_label_t[] labels;

public:
  this (int size) {
    assert(size > 0);
    labels = new jit_label_t[](size);
    labels[] = jit_label_undefined;
  }

  @property int size () const pure nothrow @nogc { return cast(int)labels.length; }
  jit_label_t* raw () pure nothrow @nogc { return labels.ptr; }

  JitLabel get (usize index) {
    if (index >= labels.length) throw new JitException(JIT_RESULT_COMPILE_ERROR);
    return JitLabel(labels.ptr[index]);
  }

  void set (usize index, JitLabel label) {
    if (index >= labels.length) throw new JitException(JIT_RESULT_COMPILE_ERROR);
    labels.ptr[index] = label.raw;
  }

  JitLabel opIndex (usize index) { return get(index); }
  void opIndexAssign (JitLabel value, usize index) { set(index, value); }
}


// ////////////////////////////////////////////////////////////////////////// //
class JitContext {
private:
  jit_context_t context;
  bool copied;

public:
  this () {
    jit_init();
    context = jit_context_create();
    copied = false;
  }

  this (jit_context_t context) {
    assert(context !is null);
    this.context = context;
    this.copied = true;
  }

  ~this () { release(); }

  void release () {
    if (context !is null) {
      if (!copied) jit_context_destroy(context);
      context = null;
    }
  }

  void build_start () { assert(context !is null); jit_context_build_start(context); }
  void build_end () { assert(context !is null); jit_context_build_end(context); }
  @property jit_context_t raw () { return context; }
}


// ////////////////////////////////////////////////////////////////////////// //
class JitFunction {
private:
  enum JITD_MAPPING = 20001;

private:
  jit_function_t func;
  jit_context_t context;

public:
  // you can set this delegate if you don't want to override `build()` method
  void delegate (JitFunction me) builder;

public:
  this (JitContext context, jit_type_t signature) {
    // save the context for the "create" method
    this.context = context.raw;
    this.func = null;
    // create the function
    create(signature);
  }

  this (JitContext context) {
    // save the context, but don't create the function yet.
    this.context = context.raw;
    this.func = null;
  }

  this (jit_function_t func) {
    this.context = jit_function_get_context(func);
    this.func = func;
    if (func !is null) {
      jit_context_build_start(context);
      jit_function_set_meta(func, JITD_MAPPING, cast(void*)this, /*&free_mapping*/null, 0);
      register_on_demand();
      jit_context_build_end(context);
    }
  }

  ~this () { release(); }

 final {
  void release () {
    if (func !is null) {
      jit_context_build_start(context);
      jit_function_free_meta(func, JITD_MAPPING);
      jit_context_build_end(context);
      func = null;
    }
  }

  @property jit_function_t raw () pure nothrow @safe @nogc { return func; }
  bool is_valid () const { return (func !is null); }

  static JitFunction from_raw (jit_function_t func) nothrow {
    assert(func !is null);
    return cast(JitFunction)jit_function_get_meta(func, JITD_MAPPING);
  }

  jit_type_t signature () { assert(func !is null); return jit_function_get_signature(func); }

  void create (jit_type_t signature) {
    // bail out if the function is already created
    if (func !is null) return;
    // lock down the context
    jit_context_build_start(context);
    // create the new function
    func = jit_function_create(context, signature);
    if (func is null) { jit_context_build_end(context); return; }
    // store this object's pointer on the raw function so that we can
    // map the raw function back to this object later
    jit_function_set_meta(func, JITD_MAPPING, cast(void*)this, /*&free_mapping*/null, 0);
    // register us as the on-demand compiler
    register_on_demand();
    // unlock the context
    jit_context_build_end(context);
  }

  void create () {
    if (func is null) {
      jit_type_t signature = create_signature();
      create(signature);
      jit_type_free(signature);
    }
  }

  int compile () {
    return (func is null ? 0 : jit_function_compile(func));
  }

  bool is_compiled () { assert(func !is null); return (jit_function_is_compiled(func) != 0); }

  bool is_recompilable () { assert(func !is null); return (jit_function_is_recompilable(func) != 0); }

  void set_recompilable () { assert(func !is null); jit_function_set_recompilable(func); }
  void clear_recompilable() { assert(func !is null); jit_function_clear_recompilable(func); }
  void set_recompilable (bool flag) { assert(func !is null); if (flag) set_recompilable(); else clear_recompilable(); }

  void set_optimization_level (uint level) { assert(func !is null); jit_function_set_optimization_level(func, level); }
  @property uint optimization_level ()  { assert(func !is null); return jit_function_get_optimization_level(func); }
  static @property uint max_optimization_level () { return jit_function_get_max_optimization_level(); }

  void* closure () { assert(func !is null); return jit_function_to_closure(func); }
  void* vtable_pointer() { assert(func !is null); return jit_function_to_vtable_pointer(func); }

  int apply (void*[] args, void* result) { assert(func !is null); return jit_function_apply(func, args.ptr, result); }
  int apply (jit_type_t signature, void*[] args, void* return_area) { assert(func !is null); return jit_function_apply_vararg(func, signature, args.ptr, return_area); }

  static jit_type_t signature_helper (jit_type_t return_type, jit_type_t[] args...) {
    return jit_type_create_signature(jit_abi_cdecl, return_type, args.ptr, cast(uint)args.length, 1);
  }
 }

protected:
  alias jit_byte = jit_sbyte;

  void build () {
    // normally overridden by subclasses
    if (builder !is null) {
      builder(this);
    } else {
      fail();
    }
  }

  jit_type_t create_signature () {
    // normally overridden by subclasses
    return signature_helper(jit_type_void);
  }

final:
  static void fail (string file=__FILE__, usize line=__LINE__) { throw new JitException(JIT_RESULT_COMPILE_ERROR, file, line); }

  static void out_of_memory (string file=__FILE__, usize line=__LINE__) { throw new JitException(JIT_RESULT_OUT_OF_MEMORY, file, line); }

  static JitValue value_wrap() (jit_value_t x) {
    auto val = JitValue(x);
    if (val.raw is null) out_of_memory();
    return val;
  }

public:
  void build_start () { assert(func !is null); jit_context_build_start(jit_function_get_context(func)); }
  void build_end () { assert(func !is null); jit_context_build_end(jit_function_get_context(func)); }

  JitValue new_value (jit_type_t type) { assert(func !is null); return value_wrap(jit_value_create(func, type)); }

  private import std.traits;

  JitValue new_constant(T) (T value, jit_type_t type=null) if (isIntegral!T || is(T == float) || is(T == double) || is(T == real)) {
    assert(func !is null);
    static if (isIntegral!T) {
      if (type is null) type = mixin("jit_type_"~T.stringof);
      static if (T.sizeof <= jit_nint.sizeof) {
        return value_wrap(jit_value_create_nint_constant(func, type, cast(jit_nint)value));
      } else {
        return value_wrap(jit_value_create_long_constant(func, type, value));
      }
    } else static if (is(T == float)) {
      if (type is null) type = jit_type_float32;
      return value_wrap(jit_value_create_float32_constant(func, type, value));
    } else static if (is(T == double)) {
      if (type is null) type = jit_type_float64;
      return value_wrap(jit_value_create_float64_constant(func, type, value));
    } else static if (is(T == real)) {
      if (type is null) type = jit_type_nfloat;
      return value_wrap(jit_value_create_nfloat_constant(func, type, value));
    } else {
      static assert(0, "wtf?!");
    }
  }

  JitValue new_constant (void* value, jit_type_t type=null) {
    assert(func !is null);
    if (type is null) type = jit_type_void_ptr;
    return value_wrap(jit_value_create_nint_constant(func, type, cast(jit_nint)value));
  }

  JitValue new_constant (jit_constant_t* value) {
    assert(func !is null);
    assert(value !is null);
    return value_wrap(jit_value_create_constant(func, value));
  }

  JitValue get_param (uint param) {
    assert(func !is null);
    return value_wrap(jit_value_get_param(func, param));
  }

  JitValue get_struct_pointer () {
    assert(func !is null);
    return value_wrap(jit_value_get_struct_pointer(func));
  }

  JitLabel new_label () {
    assert(func !is null);
    return JitLabel(jit_function_reserve_label(func));
  }

  void insn_label (JitLabel label) {
    assert(func !is null);
    assert(label.is_valid);
    if (!jit_insn_label(func, label.rawp)) out_of_memory();
  }

  void insn_new_block () {
    assert(func !is null);
    if (!jit_insn_new_block(func)) out_of_memory();
  }

  JitValue insn_load (JitValue value) { assert(func !is null); return value_wrap(jit_insn_load(func, value.raw)); }
  JitValue insn_dup (JitValue value) { assert(func !is null); return value_wrap(jit_insn_dup(func, value.raw)); }
  JitValue insn_load_small (JitValue value) { assert(func !is null); return value_wrap(jit_insn_load_small(func, value.raw)); }

  void store (JitValue dest, JitValue value) {
    assert(func !is null);
    assert(dest.raw !is null && value.raw !is null);
    if (!jit_insn_store(func, dest.raw, value.raw)) out_of_memory();
  }

  JitValue insn_load_relative (JitValue value, jit_nint offset, jit_type_t type) {
    assert(func !is null);
    assert(value.raw !is null);
    assert(type !is null);
    return value_wrap(jit_insn_load_relative(func, value.raw, offset, type));
  }

  void insn_store_relative (JitValue dest, jit_nint offset, JitValue value) {
    assert(func !is null);
    assert(dest.raw !is null && value.raw !is null);
    if (!jit_insn_store_relative(func, dest.raw, offset, value.raw)) out_of_memory();
  }

  JitValue insn_add_relative (JitValue value, jit_nint offset) {
    assert(func !is null);
    assert(value.raw !is null);
    return value_wrap(jit_insn_add_relative(func, value.raw, offset));
  }

  JitValue insn_load_elem (JitValue base_addr, JitValue index, jit_type_t elem_type) {
    assert(func !is null);
    assert(base_addr.raw !is null && index.raw !is null && elem_type !is null);
    return value_wrap(jit_insn_load_elem(func, base_addr.raw, index.raw, elem_type));
  }

  JitValue insn_load_elem_address (JitValue base_addr, JitValue index, jit_type_t elem_type) {
    assert(func !is null);
    assert(base_addr.raw !is null && index.raw !is null && elem_type !is null);
    return value_wrap(jit_insn_load_elem_address(func, base_addr.raw, index.raw, elem_type));
  }

  void insn_store_elem (JitValue base_addr, JitValue index, JitValue value) {
    assert(func !is null);
    assert(base_addr.raw !is null && index.raw !is null && value.raw !is null);
    if (!jit_insn_store_elem(func, base_addr.raw, index.raw, value.raw)) out_of_memory();
  }

  void insn_check_null (JitValue value) {
    assert(func !is null);
    assert(value.raw !is null);
    if (!jit_insn_check_null(func, value.raw)) out_of_memory();
  }

  private enum UnInsnMixin(string name) =
    "JitValue insn_"~name~" (JitValue value1) {\n"~
    "  assert(func !is null);\n"~
    "  assert(value1.raw !is null);\n"~
    "  return value_wrap(jit_insn_"~name~"(func, value1.raw));\n"
    "}";

  mixin(UnInsnMixin!"neg");
  mixin(UnInsnMixin!"not");
  mixin(UnInsnMixin!"to_bool");
  mixin(UnInsnMixin!"to_not_bool");
  mixin(UnInsnMixin!"acos");
  mixin(UnInsnMixin!"asin");
  mixin(UnInsnMixin!"atan");
  mixin(UnInsnMixin!"ceil");
  mixin(UnInsnMixin!"cos");
  mixin(UnInsnMixin!"cosh");
  mixin(UnInsnMixin!"exp");
  mixin(UnInsnMixin!"floor");
  mixin(UnInsnMixin!"log");
  mixin(UnInsnMixin!"log10");
  mixin(UnInsnMixin!"rint");
  mixin(UnInsnMixin!"round");
  mixin(UnInsnMixin!"sin");
  mixin(UnInsnMixin!"sinh");
  mixin(UnInsnMixin!"sqrt");
  mixin(UnInsnMixin!"tan");
  mixin(UnInsnMixin!"tanh");
  mixin(UnInsnMixin!"trunc");
  mixin(UnInsnMixin!"is_nan");
  mixin(UnInsnMixin!"is_finite");
  mixin(UnInsnMixin!"is_inf");
  mixin(UnInsnMixin!"abs");
  mixin(UnInsnMixin!"sign");
  mixin(UnInsnMixin!"address_of");

  private enum BinInsnMixin(string name) =
    "JitValue insn_"~name~" (JitValue value1, JitValue value2) {\n"~
    "  assert(func !is null);\n"~
    "  assert(value1.raw !is null && value2.raw !is null);\n"~
    "  return value_wrap(jit_insn_"~name~"(func, value1.raw, value2.raw));\n"
    "}";

  mixin(BinInsnMixin!"add");
  mixin(BinInsnMixin!"add_ovf");
  mixin(BinInsnMixin!"sub");
  mixin(BinInsnMixin!"sub_ovf");
  mixin(BinInsnMixin!"mul");
  mixin(BinInsnMixin!"mul_ovf");
  mixin(BinInsnMixin!"div");
  mixin(BinInsnMixin!"rem");
  mixin(BinInsnMixin!"rem_ieee");
  mixin(BinInsnMixin!"and");
  mixin(BinInsnMixin!"or");
  mixin(BinInsnMixin!"xor");
  mixin(BinInsnMixin!"shl");
  mixin(BinInsnMixin!"shr");
  mixin(BinInsnMixin!"ushr");
  mixin(BinInsnMixin!"sshr");
  mixin(BinInsnMixin!"eq");
  mixin(BinInsnMixin!"ne");
  mixin(BinInsnMixin!"lt");
  mixin(BinInsnMixin!"le");
  mixin(BinInsnMixin!"gt");
  mixin(BinInsnMixin!"ge");
  mixin(BinInsnMixin!"cmpl");
  mixin(BinInsnMixin!"cmpg");
  mixin(BinInsnMixin!"atan2");
  mixin(BinInsnMixin!"pow");
  mixin(BinInsnMixin!"min");
  mixin(BinInsnMixin!"max");

  void insn_branch (JitLabel label) {
    assert(func !is null);
    assert(label.is_valid);
    if (!jit_insn_branch(func, label.rawp)) out_of_memory();
  }

  void insn_branch_if (JitValue value, JitLabel label) {
    assert(func !is null);
    assert(label.is_valid);
    if (!jit_insn_branch_if(func, value.raw, label.rawp)) out_of_memory();
  }

  void insn_branch_if_not (JitValue value, JitLabel label) {
    assert(func !is null);
    assert(value.raw !is null && label.is_valid);
    if (!jit_insn_branch_if_not(func, value.raw, label.rawp)) out_of_memory();
  }

  void insn_jump_table (JitValue value, JitJumpTable jump_table) {
    assert(func !is null);
    assert(jump_table.raw !is null && jump_table.size > 0);
    if (!jit_insn_jump_table(func, value.raw, jump_table.raw, jump_table.size)) out_of_memory();
  }

  JitValue insn_address_of_label (JitLabel label) {
    assert(func !is null);
    assert(label.is_valid);
    return value_wrap(jit_insn_address_of_label(func, label.rawp));
  }

  JitValue insn_convert (JitValue value, jit_type_t type, bool overflow_check=false) {
    assert(func !is null);
    assert(value.raw !is null && type !is null);
    return value_wrap(jit_insn_convert(func, value.raw, type, overflow_check));
  }

  JitValue insn_call (string name, jit_function_t jit_func, jit_type_t signature, jit_value_t[] args, int flags=0) {
    import std.string : toStringz;
    assert(func !is null);
    assert(jit_func !is null && signature !is null);
    assert(args.length <= uint.max);
    return value_wrap(jit_insn_call(func, name.toStringz, jit_func, signature, args.ptr, cast(uint)args.length, flags));
  }

  JitValue insn_call_indirect (JitValue value, jit_type_t signature, jit_value_t[] args, int flags=0) {
    assert(func !is null);
    assert(value.raw !is null && signature !is null);
    assert(args.length <= uint.max);
    return value_wrap(jit_insn_call_indirect(func, value.raw, signature, args.ptr, cast(uint)args.length, flags));
  }

  JitValue insn_call_indirect_vtable (JitValue value, jit_type_t signature, jit_value_t[] args, int flags=0) {
    assert(func !is null);
    assert(value.raw !is null && signature !is null);
    assert(args.length <= uint.max);
    return value_wrap(jit_insn_call_indirect_vtable(func, value.raw, signature, args.ptr, cast(uint)args.length, flags));
  }

  JitValue insn_call_native (string name, void* native_func, jit_type_t signature, jit_value_t[] args, int flags=0) {
    import std.string : toStringz;
    assert(func !is null);
    assert(native_func !is null && signature !is null);
    assert(args.length <= uint.max);
    return value_wrap(jit_insn_call_native(func, name.toStringz, native_func, signature, args.ptr, cast(uint)args.length, flags));
  }

  JitValue insn_call_intrinsic (string name, void* intrinsic_func, jit_intrinsic_descr_t* descriptor, JitValue arg1) {
    import std.string : toStringz;
    assert(func !is null);
    assert(intrinsic_func !is null && descriptor !is null);
    assert(arg1.raw !is null);
    return value_wrap(jit_insn_call_intrinsic(func, name.toStringz, intrinsic_func, descriptor, arg1.raw, null));
  }

  JitValue insn_call_intrinsic (string name, void* intrinsic_func, jit_intrinsic_descr_t* descriptor, JitValue arg1, JitValue arg2) {
    import std.string : toStringz;
    assert(func !is null);
    assert(intrinsic_func !is null && descriptor !is null);
    assert(arg1.raw !is null);
    assert(arg2.raw !is null);
    return value_wrap(jit_insn_call_intrinsic(func, name.toStringz, intrinsic_func, descriptor, arg1.raw, arg2.raw));
  }

  void insn_incoming_reg (JitValue value, int reg) {
    assert(func !is null);
    assert(value.raw !is null);
    if (!jit_insn_incoming_reg(func, value.raw, reg)) out_of_memory();
  }

  void insn_incoming_frame_posn (JitValue value, jit_nint posn) {
    assert(func !is null);
    assert(value.raw !is null);
    if (!jit_insn_incoming_frame_posn(func, value.raw, posn)) out_of_memory();
  }

  void insn_outgoing_reg (JitValue value, int reg) {
    assert(func !is null);
    assert(value.raw !is null);
    if (!jit_insn_outgoing_reg(func, value.raw, reg)) out_of_memory();
  }

  void insn_outgoing_frame_posn (JitValue value, jit_nint posn) {
    assert(func !is null);
    assert(value.raw !is null);
    if (!jit_insn_outgoing_frame_posn(func, value.raw, posn)) out_of_memory();
  }

  void insn_return_reg (JitValue value, int reg) {
    assert(func !is null);
    assert(value.raw !is null);
    if (!jit_insn_return_reg(func, value.raw, reg)) out_of_memory();
  }

  void insn_setup_for_nested (int nested_level, int reg) {
    assert(func !is null);
    //k8: ???
  }

  void insn_flush_struct (JitValue value) {
    assert(func !is null);
    assert(value.raw !is null);
    if (!jit_insn_flush_struct(func, value.raw)) out_of_memory();
  }

  JitValue insn_import (JitValue value) {
    assert(func !is null);
    assert(value.raw !is null);
    return value_wrap(jit_insn_import(func, value.raw));
  }

  void insn_push (JitValue value) {
    assert(func !is null);
    assert(value.raw !is null);
    if (!jit_insn_push(func, value.raw)) out_of_memory();
  }

  void insn_push_ptr (JitValue value, jit_type_t type) {
    assert(func !is null);
    assert(value.raw !is null && type !is null);
    if (!jit_insn_push_ptr(func, value.raw, type)) out_of_memory();
  }

  void insn_set_param (JitValue value, jit_nint offset) {
    assert(func !is null);
    assert(value.raw !is null);
    if (!jit_insn_set_param(func, value.raw, offset)) out_of_memory();
  }

  void insn_set_param_ptr (JitValue value, jit_type_t type, jit_nint offset) {
    assert(func !is null);
    assert(value.raw !is null && type !is null);
    if (!jit_insn_set_param_ptr(func, value.raw, type, offset)) out_of_memory();
  }

  void insn_push_return_area_ptr () {
    assert(func !is null);
    if (!jit_insn_push_return_area_ptr(func)) out_of_memory();
  }

  void insn_return (JitValue value) {
    assert(func !is null);
    assert(value.raw !is null);
    if (!jit_insn_return(func, value.raw)) out_of_memory();
  }

  void insn_return () {
    assert(func !is null);
    if (!jit_insn_return(func, null)) out_of_memory();
  }

  void insn_return_ptr (JitValue value, jit_type_t type) {
    assert(func !is null);
    assert(value.raw !is null && type !is null);
    if (!jit_insn_return_ptr(func, value.raw, type)) out_of_memory();
  }

  void insn_default_return () {
    assert(func !is null);
    if (!jit_insn_default_return(func)) out_of_memory();
  }

  void insn_throw (JitValue value) {
    assert(func !is null);
    assert(value.raw !is null);
    if (!jit_insn_throw(func, value.raw)) out_of_memory();
  }

  JitValue insn_get_call_stack () {
    assert(func !is null);
    return value_wrap(jit_insn_get_call_stack(func));
  }

  JitValue insn_thrown_exception () {
    assert(func !is null);
    return value_wrap(jit_insn_thrown_exception(func));
  }

  void insn_uses_catcher () {
    assert(func !is null);
    if (!jit_insn_uses_catcher(func)) out_of_memory();
  }

  JitValue insn_start_catcher () {
    assert(func !is null);
    return value_wrap(jit_insn_start_catcher(func));
  }

  void insn_branch_if_pc_not_in_range (JitLabel start_label, JitLabel end_label, JitLabel label) {
    assert(func !is null);
    assert(start_label.is_valid && end_label.is_valid && label.is_valid);
    if (!jit_insn_branch_if_pc_not_in_range(func, start_label.raw, end_label.raw, label.rawp)) out_of_memory();
  }

  void insn_rethrow_unhandled () {
    assert(func !is null);
    if (!jit_insn_rethrow_unhandled(func)) out_of_memory();
  }

  void insn_start_finally (JitLabel label) {
    assert(func !is null);
    assert(label.is_valid);
    if (!jit_insn_start_finally(func, label.rawp)) out_of_memory();
  }

  void insn_return_from_finally () {
    assert(func !is null);
    if (!jit_insn_return_from_finally(func)) out_of_memory();
  }

  void insn_call_finally (JitLabel label) {
    assert(func !is null);
    assert(label.is_valid);
    if (!jit_insn_call_finally(func, label.rawp)) out_of_memory();
  }

  JitValue insn_start_filter (JitLabel label, jit_type_t type) {
    assert(func !is null);
    assert(label.is_valid && type !is null);
    return value_wrap(jit_insn_start_filter(func, label.rawp, type));
  }

  void insn_return_from_filter (JitValue value) {
    assert(func !is null);
    assert(value.raw !is null);
    if (!jit_insn_return_from_filter(func, value.raw)) out_of_memory();
  }

  JitValue insn_call_filter (JitLabel label, JitValue value, jit_type_t type) {
    assert(func !is null);
    assert(label.is_valid && value.raw !is null && type !is null);
    return value_wrap(jit_insn_call_filter(func, label.rawp, value.raw, type));
  }

  void insn_memcpy (JitValue dest, JitValue src, JitValue size) {
    assert(func !is null);
    assert(dest.raw !is null && src.raw !is null && size.raw !is null);
    if (!jit_insn_memcpy(func, dest.raw, src.raw, size.raw)) out_of_memory();
  }

  void insn_memmove (JitValue dest, JitValue src, JitValue size) {
    assert(func !is null);
    assert(dest.raw !is null && src.raw !is null && size.raw !is null);
    if (!jit_insn_memmove(func, dest.raw, src.raw, size.raw)) out_of_memory();
  }

  void insn_memset (JitValue dest, JitValue value, JitValue size) {
    assert(func !is null);
    assert(dest.raw !is null && value.raw !is null && size.raw !is null);
    if (!jit_insn_memset(func, dest.raw, value.raw, size.raw)) out_of_memory();
  }

  JitValue insn_alloca (JitValue size) {
    assert(func !is null);
    assert(size.raw !is null);
    return value_wrap(jit_insn_alloca(func, size.raw));
  }

  void insn_move_blocks_to_end (JitLabel from_label, JitLabel to_label) {
    assert(func !is null);
    assert(from_label.is_valid && to_label.is_valid);
    if (!jit_insn_move_blocks_to_end(func, from_label.raw, to_label.raw)) out_of_memory();
  }

  void insn_move_blocks_to_start (JitLabel from_label, JitLabel to_label) {
    assert(func !is null);
    assert(from_label.is_valid && to_label.is_valid);
    if (!jit_insn_move_blocks_to_start(func, from_label.raw, to_label.raw)) out_of_memory();
  }

  void insn_mark_offset (jit_int offset) {
    assert(func !is null);
    if (!jit_insn_mark_offset(func, offset)) out_of_memory();
  }

  void insn_mark_breakpoint (jit_nint data1, jit_nint data2) {
    assert(func !is null);
    if (!jit_insn_mark_breakpoint(func, data1, data2)) out_of_memory();
  }

private:
  void register_on_demand () {
    jit_function_set_on_demand_compiler(func, &on_demand_compiler);
  }

  static extern(C) int on_demand_compiler (jit_function_t func) nothrow {
    // get the object that corresponds to the raw function
    auto func_object = from_raw(func);
    if (func_object is null) return JIT_RESULT_COMPILE_ERROR;
    // attempt to build the function's contents
    try {
      func_object.build();
      if (!jit_insn_default_return(func)) func_object.out_of_memory();
      return JIT_RESULT_OK;
    } catch (JitException e) {
      return e.result;
    } catch (Exception e) {
      return JIT_RESULT_COMPILE_ERROR;
    }
  }

  static extern(C) void free_mapping (void* data) {
    // If we were called during the context's shutdown,
    // then the raw function pointer is no longer valid.
    (cast(JitFunction)data).func = null;
  }
}
