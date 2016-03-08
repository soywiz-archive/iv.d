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

  override string toString () {
    import std.string : format;
    return "*** libjit error %s\n%s".format(result2str(result), super.toString());
  }
}


// ////////////////////////////////////////////////////////////////////////// //
struct JitValue {
private:
  jit_value_t value;

public:
  this (jit_value_t value) pure nothrow @safe @nogc { this.value = value; }
  this (JitValue value) pure nothrow @safe @nogc { this.value = value.value; }

final:
  ref JitValue opAssign() (in auto ref JitValue value) pure nothrow @safe @nogc { pragma(inline, true); this.value = value.value; return this; }

  @property inout(jit_value_t) raw () inout pure nothrow @safe @nogc { pragma(inline, true); return value; }
  @property bool valid () const pure nothrow @safe @nogc { pragma(inline, true); return (value !is null); }

  @property bool is_temporary () nothrow @nogc { pragma(inline, true); return (jit_value_is_temporary(value) != 0); }
  @property bool is_local () nothrow @nogc { pragma(inline, true); return (jit_value_is_local(value) != 0); }
  @property bool is_constant () nothrow @nogc { pragma(inline, true); return (jit_value_is_constant(value) != 0); }
  @property bool is_parameter () nothrow @nogc { pragma(inline, true); return (jit_value_is_parameter(value) != 0); }

  @property bool volatileValue () nothrow @nogc { pragma(inline, true); return (jit_value_is_volatile(value) != 0); }
  void setVolatileValue () nothrow @nogc { pragma(inline, true); jit_value_set_volatile(value); }
  @property void volatileValue (bool v) {
    if (!v) { if (jit_value_is_volatile(value)) throw new JitException(JIT_RESULT_COMPILE_ERROR); }
    jit_value_set_volatile(value);
  }

  @property bool addressable () nothrow @nogc { pragma(inline, true); return (jit_value_is_addressable(value) != 0); }
  void setAddressable () nothrow @nogc { pragma(inline, true); jit_value_set_addressable(value); }
  @property void addressable (bool v) {
    if (!v) { if (jit_value_is_addressable(value)) throw new JitException(JIT_RESULT_COMPILE_ERROR); }
    jit_value_set_addressable(value);
  }

  @property jit_type_t type () nothrow @nogc { pragma(inline, true); return jit_value_get_type(value); }
  @property jit_function_t func () nothrow @nogc { pragma(inline, true); return jit_value_get_function(value); }
  @property jit_block_t block () nothrow @nogc { pragma(inline, true); return jit_value_get_block(value); }
  @property jit_context_t context () nothrow @nogc { pragma(inline, true); return jit_value_get_context(value); }

  @property jit_constant_t constant () nothrow @nogc { pragma(inline, true); return jit_value_get_constant(value); }
  @property jit_nint nint_constant () nothrow @nogc { pragma(inline, true); return jit_value_get_nint_constant(value); }
  @property jit_long long_constant () nothrow @nogc { pragma(inline, true); return jit_value_get_long_constant(value); }
  @property jit_float32 float32_constant () nothrow @nogc { pragma(inline, true); return jit_value_get_float32_constant(value); }
  @property jit_float64 float64_constant () nothrow @nogc { pragma(inline, true); return jit_value_get_float64_constant(value); }
  @property jit_nfloat nfloat_constant () nothrow @nogc { pragma(inline, true); return jit_value_get_nfloat_constant(value); }

  private enum UnOpMixin(string op, string insn) =
    "JitValue opUnary(string op : "~op.stringof~") () {\n"~
    "  pragma(inline, true);\n"~
    "  return JitValue(jit_insn_"~insn~"(jit_value_get_function(this), this.raw));\n"~
    "}";

  mixin(UnOpMixin!("-", "neg"));
  mixin(UnOpMixin!("~", "not"));


  private enum BinOpMixin(string op, string insn, string opname="opBinary") =
    "JitValue "~opname~"(string op : "~op.stringof~") (JitValue rhs) {\n"~
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

  // Aliced extension
  mixin(BinOpMixin!("<", "lt", "opBinaryCmp"));
  mixin(BinOpMixin!(">", "gt", "opBinaryCmp"));
  mixin(BinOpMixin!("==", "eq", "opBinaryCmp"));
  mixin(BinOpMixin!("!=", "ne", "opBinaryCmp"));
  mixin(BinOpMixin!("<=", "le", "opBinaryCmp"));
  mixin(BinOpMixin!(">=", "ge", "opBinaryCmp"));

private:
  // Get the function that owns a pair of values.  It will choose
  // the function for the first value, unless it is NULL (e.g. for
  // global values).  In that case, it will choose the function
  // for the second value.
  static jit_function_t value_owner (JitValue value1, JitValue value2) nothrow @nogc {
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
  this (jit_label_t label) pure nothrow @safe @nogc { this.label = label; }
  this (JitLabel label) pure nothrow @safe @nogc { this.label = label.label; }

final:
  @property inout(jit_label_t) raw () inout const pure nothrow @safe @nogc { pragma(inline, true); return label; }
  @property jit_label_t* rawp () pure nothrow @nogc { pragma(inline, true); return &label; }
  bool valid () const pure nothrow @safe @nogc { pragma(inline, true); return (label != jit_label_undefined); }

  ref JitLabel opAssign (JitLabel value) pure nothrow @safe @nogc { this.label = value.label; return this; }
}


// ////////////////////////////////////////////////////////////////////////// //
struct JitJumpTable {
private:
  jit_label_t[] labels;

public:
  this (int size) nothrow @safe {
    assert(size > 0);
    labels = new jit_label_t[](size);
    labels[] = jit_label_undefined;
  }

  @property bool valid () const pure nothrow @safe @nogc { pragma(inline, true); return (labels.length > 0); }

  @property int size () const pure nothrow @safe @nogc { pragma(inline, true); return cast(int)labels.length; }
  jit_label_t* raw () pure nothrow @nogc { pragma(inline, true); return labels.ptr; }

  JitLabel get (usize index) {
    if (index >= labels.length) throw new JitException(JIT_RESULT_COMPILE_ERROR);
    return JitLabel(labels.ptr[index]);
  }

  void set (usize index, JitLabel label) {
    if (index >= labels.length) throw new JitException(JIT_RESULT_COMPILE_ERROR);
    labels.ptr[index] = label.raw;
  }

  JitLabel opIndex (usize index) { pragma(inline, true); return get(index); }
  void opIndexAssign (JitLabel value, usize index) { pragma(inline, true); set(index, value); }
}


// ////////////////////////////////////////////////////////////////////////// //
class JitContext {
private:
  jit_context_t context;
  bool copied;

public:
  this () nothrow @nogc {
    jit_init();
    context = jit_context_create();
    copied = false;
  }

  this (jit_context_t context) nothrow @nogc {
    assert(context !is null);
    this.context = context;
    this.copied = true;
  }

  ~this () nothrow @nogc { release(); }

  @property bool valid () const pure nothrow @safe @nogc { pragma(inline, true); return (context !is null); }

  @property jit_context_t raw () pure nothrow @safe @nogc { /*pragma(inline, true);bug*/ return context; }

  void release () nothrow @nogc {
    if (context !is null) {
      if (!copied) jit_context_destroy(context);
      context = null;
    }
  }

  void buildStart () nothrow @nogc { pragma(inline, true); assert(context !is null); jit_context_build_start(context); }
  void buildEnd () nothrow @nogc { pragma(inline, true); assert(context !is null); jit_context_build_end(context); }
}


// ////////////////////////////////////////////////////////////////////////// //
class JitFunction {
private:
  private import std.traits;

  enum JITD_MAPPING = 20001; // it's in reserved tange, but meh...
  alias jit_byte = jit_sbyte; // for mixin trick

private:
  jit_function_t func;
  jit_context_t context;

protected:
  static JitValue wrapValue() (jit_value_t x) {
    auto val = JitValue(x);
    if (val.raw is null) out_of_memory();
    return val;
  }

  void build () {
    // normally overridden by subclasses
    if (builder !is null) {
      builder(this);
    } else {
      fail();
    }
  }

  jit_type_t createSignature () {
    // normally overridden by subclasses
    return signatureHelper(jit_type_void);
  }

public:
  static jit_type_t signatureHelper (jit_type_t return_type, jit_type_t[] args...) {
    return jit_type_create_signature(jit_abi_cdecl, return_type, args.ptr, cast(uint)args.length, 1);
  }

  static void fail (string file=__FILE__, usize line=__LINE__) { throw new JitException(JIT_RESULT_COMPILE_ERROR, file, line); }
  static void out_of_memory (string file=__FILE__, usize line=__LINE__) { throw new JitException(JIT_RESULT_OUT_OF_MEMORY, file, line); }

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

  this (JitContext context) nothrow @nogc {
    // save the context, but don't create the function yet.
    this.context = context.raw;
    this.func = null;
  }

  this (jit_function_t func) {
    this.context = jit_function_get_context(func);
    this.func = func;
    if (func !is null) {
      jit_context_build_start(context);
      jit_function_set_meta(func, JITD_MAPPING, cast(void*)this, &freeMapping, 0);
      registerOnDemand();
      jit_context_build_end(context);
    }
  }

  ~this () nothrow @nogc { release(); }

final:
  void release () nothrow @nogc {
    if (func !is null) {
      jit_context_build_start(context);
      jit_function_free_meta(func, JITD_MAPPING);
      jit_context_build_end(context);
      func = null;
    }
  }

  @property jit_function_t raw () pure nothrow @safe @nogc { pragma(inline, true); return func; }
  @property bool valid () const pure nothrow @safe @nogc { pragma(inline, true); return (func !is null); }

  static JitFunction getFuncObjFromRaw (jit_function_t func) nothrow @nogc {
    assert(func !is null);
    return cast(JitFunction)jit_function_get_meta(func, JITD_MAPPING);
  }

  jit_type_t signature () nothrow @nogc { assert(this.valid); return jit_function_get_signature(func); }

  void create (jit_type_t signature) {
    // bail out if the function is already created
    if (this.valid) return;
    // lock down the context
    jit_context_build_start(context);
    // create the new function
    func = jit_function_create(context, signature);
    if (func is null) { jit_context_build_end(context); return; }
    // store this object's pointer on the raw function so that we can
    // map the raw function back to this object later
    jit_function_set_meta(func, JITD_MAPPING, cast(void*)this, &freeMapping, 0);
    // register us as the on-demand compiler
    registerOnDemand();
    // unlock the context
    jit_context_build_end(context);
  }

  void create () {
    if (func is null) {
      jit_type_t signature = createSignature();
      create(signature);
      jit_type_free(signature);
    }
  }

  int compile () nothrow @nogc { return (func is null ? 0 : jit_function_compile(func)); }

  @property bool compiled () nothrow @nogc { assert(this.valid); return (jit_function_is_compiled(func) != 0); }

  @property bool recompilable () nothrow @nogc { assert(this.valid); return (jit_function_is_recompilable(func) != 0); }
  @property void recompilable (bool flag) nothrow @nogc { assert(this.valid); if (flag) jit_function_set_recompilable(func); else jit_function_clear_recompilable(func); }

  @property uint optimizationLevel () nothrow @nogc { assert(this.valid); return jit_function_get_optimization_level(func); }
  @property void optimizationLevel (uint level) nothrow @nogc { assert(this.valid); jit_function_set_optimization_level(func, level); }

  static @property uint maxOptimizationLevel () nothrow @nogc { return jit_function_get_max_optimization_level(); }

  @property void* closure () nothrow @nogc { assert(this.valid); return jit_function_to_closure(func); }
  @property void* vtablePointer () nothrow @nogc { assert(this.valid); return jit_function_to_vtable_pointer(func); }

  int apply (void*[] args, void* result) nothrow { assert(this.valid); return jit_function_apply(func, args.ptr, result); }
  int apply (jit_type_t signature, void*[] args, void* return_area) nothrow { assert(this.valid); return jit_function_apply_vararg(func, signature, args.ptr, return_area); }

  void buildStart () { assert(this.valid); jit_context_build_start(jit_function_get_context(func)); }
  void buildEnd () { assert(this.valid); jit_context_build_end(jit_function_get_context(func)); }

  JitValue newValue (jit_type_t type) { assert(this.valid); return wrapValue(jit_value_create(func, type)); }

  JitValue newConstant(T) (T value, jit_type_t type=null) if (isIntegral!T || is(T == float) || is(T == double) || is(T == real)) {
    assert(this.valid);
    static if (isIntegral!T) {
      if (type is null) type = mixin("jit_type_"~T.stringof);
      static if (T.sizeof <= jit_nint.sizeof) {
        return wrapValue(jit_value_create_nint_constant(func, type, cast(jit_nint)value));
      } else {
        return wrapValue(jit_value_create_long_constant(func, type, value));
      }
    } else static if (is(T == float)) {
      if (type is null) type = jit_type_float32;
      return wrapValue(jit_value_create_float32_constant(func, type, value));
    } else static if (is(T == double)) {
      if (type is null) type = jit_type_float64;
      return wrapValue(jit_value_create_float64_constant(func, type, value));
    } else static if (is(T == real)) {
      if (type is null) type = jit_type_nfloat;
      return wrapValue(jit_value_create_nfloat_constant(func, type, value));
    } else {
      static assert(0, "wtf?!");
    }
  }

  JitValue newConstant (void* value, jit_type_t type=null) {
    assert(this.valid);
    if (type is null) type = jit_type_void_ptr;
    return wrapValue(jit_value_create_nint_constant(func, type, cast(jit_nint)value));
  }

  JitValue newConstant (jit_constant_t* value) {
    assert(this.valid);
    assert(value !is null);
    return wrapValue(jit_value_create_constant(func, value));
  }

  JitValue getParam (uint param) {
    assert(this.valid);
    return wrapValue(jit_value_get_param(func, param));
  }

  JitValue getStructPointer () {
    assert(this.valid);
    return wrapValue(jit_value_get_struct_pointer(func));
  }

  JitLabel newLabel () {
    assert(this.valid);
    return JitLabel(jit_function_reserve_label(func));
  }

  void insn_label (JitLabel label) {
    assert(this.valid);
    assert(label.valid);
    if (!jit_insn_label(func, label.rawp)) out_of_memory();
  }

  void insn_new_block () {
    assert(this.valid);
    if (!jit_insn_new_block(func)) out_of_memory();
  }

  void store (JitValue dest, JitValue value) {
    assert(this.valid);
    assert(dest.valid && value.valid);
    if (!jit_insn_store(func, dest.raw, value.raw)) out_of_memory();
  }

  JitValue insn_load_relative (JitValue value, jit_nint offset, jit_type_t type) {
    assert(this.valid);
    assert(value.valid);
    assert(type !is null);
    return wrapValue(jit_insn_load_relative(func, value.raw, offset, type));
  }

  void insn_store_relative (JitValue dest, jit_nint offset, JitValue value) {
    assert(this.valid);
    assert(dest.valid && value.valid);
    if (!jit_insn_store_relative(func, dest.raw, offset, value.raw)) out_of_memory();
  }

  JitValue insn_add_relative (JitValue value, jit_nint offset) {
    assert(this.valid);
    assert(value.valid);
    return wrapValue(jit_insn_add_relative(func, value.raw, offset));
  }

  JitValue insn_load_elem (JitValue base_addr, JitValue index, jit_type_t elem_type) {
    assert(this.valid);
    assert(base_addr.valid && index.valid && elem_type !is null);
    return wrapValue(jit_insn_load_elem(func, base_addr.raw, index.raw, elem_type));
  }

  JitValue insn_load_elem_address (JitValue base_addr, JitValue index, jit_type_t elem_type) {
    assert(this.valid);
    assert(base_addr.valid && index.valid && elem_type !is null);
    return wrapValue(jit_insn_load_elem_address(func, base_addr.raw, index.raw, elem_type));
  }

  void insn_store_elem (JitValue base_addr, JitValue index, JitValue value) {
    assert(this.valid);
    assert(base_addr.valid && index.valid && value.valid);
    if (!jit_insn_store_elem(func, base_addr.raw, index.raw, value.raw)) out_of_memory();
  }

  void insn_check_null (JitValue value) {
    assert(this.valid);
    assert(value.valid);
    if (!jit_insn_check_null(func, value.raw)) out_of_memory();
  }

  private enum UnInsnMixin(string name) =
    "JitValue insn_"~name~" (JitValue value1) {\n"~
    "  assert(this.valid);\n"~
    "  assert(value1.valid);\n"~
    "  return wrapValue(jit_insn_"~name~"(func, value1.raw));\n"
    "}";

  mixin(UnInsnMixin!"load");
  mixin(UnInsnMixin!"dup");
  mixin(UnInsnMixin!"load_small");

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
    "  assert(this.valid);\n"~
    "  assert(value1.valid && value2.valid);\n"~
    "  return wrapValue(jit_insn_"~name~"(func, value1.raw, value2.raw));\n"
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
    assert(this.valid);
    assert(label.valid);
    if (!jit_insn_branch(func, label.rawp)) out_of_memory();
  }

  void insn_branch_if (JitValue value, JitLabel label) {
    assert(this.valid);
    assert(label.valid);
    if (!jit_insn_branch_if(func, value.raw, label.rawp)) out_of_memory();
  }

  void insn_branch_if_not (JitValue value, JitLabel label) {
    assert(this.valid);
    assert(value.valid && label.valid);
    if (!jit_insn_branch_if_not(func, value.raw, label.rawp)) out_of_memory();
  }

  void insn_jump_table (JitValue value, JitJumpTable jump_table) {
    assert(this.valid);
    assert(jump_table.valid && jump_table.size > 0);
    if (!jit_insn_jump_table(func, value.raw, jump_table.raw, jump_table.size)) out_of_memory();
  }

  JitValue insn_address_of_label (JitLabel label) {
    assert(this.valid);
    assert(label.valid);
    return wrapValue(jit_insn_address_of_label(func, label.rawp));
  }

  JitValue insn_convert (JitValue value, jit_type_t type, bool overflow_check=false) {
    assert(this.valid);
    assert(value.valid && type !is null);
    return wrapValue(jit_insn_convert(func, value.raw, type, overflow_check));
  }

  JitValue insn_call (string name, jit_function_t jit_func, jit_type_t signature, jit_value_t[] args, int flags=0) {
    import std.string : toStringz;
    assert(this.valid);
    assert(jit_func !is null && signature !is null);
    assert(args.length <= uint.max);
    return wrapValue(jit_insn_call(func, name.toStringz, jit_func, signature, args.ptr, cast(uint)args.length, flags));
  }

  JitValue insn_call_indirect (JitValue value, jit_type_t signature, jit_value_t[] args, int flags=0) {
    assert(this.valid);
    assert(value.valid && signature !is null);
    assert(args.length <= uint.max);
    return wrapValue(jit_insn_call_indirect(func, value.raw, signature, args.ptr, cast(uint)args.length, flags));
  }

  JitValue insn_call_indirect_vtable (JitValue value, jit_type_t signature, jit_value_t[] args, int flags=0) {
    assert(this.valid);
    assert(value.valid && signature !is null);
    assert(args.length <= uint.max);
    return wrapValue(jit_insn_call_indirect_vtable(func, value.raw, signature, args.ptr, cast(uint)args.length, flags));
  }

  JitValue insn_call_native (string name, void* native_func, jit_type_t signature, jit_value_t[] args, int flags=0) {
    import std.string : toStringz;
    assert(this.valid);
    assert(native_func !is null && signature !is null);
    assert(args.length <= uint.max);
    return wrapValue(jit_insn_call_native(func, name.toStringz, native_func, signature, args.ptr, cast(uint)args.length, flags));
  }

  JitValue insn_call_intrinsic (string name, void* intrinsic_func, jit_intrinsic_descr_t* descriptor, JitValue arg1) {
    import std.string : toStringz;
    assert(this.valid);
    assert(intrinsic_func !is null && descriptor !is null);
    assert(arg1.valid);
    return wrapValue(jit_insn_call_intrinsic(func, name.toStringz, intrinsic_func, descriptor, arg1.raw, null));
  }

  JitValue insn_call_intrinsic (string name, void* intrinsic_func, jit_intrinsic_descr_t* descriptor, JitValue arg1, JitValue arg2) {
    import std.string : toStringz;
    assert(this.valid);
    assert(intrinsic_func !is null && descriptor !is null);
    assert(arg1.valid);
    assert(arg2.valid);
    return wrapValue(jit_insn_call_intrinsic(func, name.toStringz, intrinsic_func, descriptor, arg1.raw, arg2.raw));
  }

  void insn_incoming_reg (JitValue value, int reg) {
    assert(this.valid);
    assert(value.valid);
    if (!jit_insn_incoming_reg(func, value.raw, reg)) out_of_memory();
  }

  void insn_incoming_frame_posn (JitValue value, jit_nint posn) {
    assert(this.valid);
    assert(value.valid);
    if (!jit_insn_incoming_frame_posn(func, value.raw, posn)) out_of_memory();
  }

  void insn_outgoing_reg (JitValue value, int reg) {
    assert(this.valid);
    assert(value.valid);
    if (!jit_insn_outgoing_reg(func, value.raw, reg)) out_of_memory();
  }

  void insn_outgoing_frame_posn (JitValue value, jit_nint posn) {
    assert(this.valid);
    assert(value.valid);
    if (!jit_insn_outgoing_frame_posn(func, value.raw, posn)) out_of_memory();
  }

  void insn_return_reg (JitValue value, int reg) {
    assert(this.valid);
    assert(value.valid);
    if (!jit_insn_return_reg(func, value.raw, reg)) out_of_memory();
  }

  void insn_setup_for_nested (int nested_level, int reg) {
    assert(this.valid);
    if (!jit_insn_setup_for_nested(func, nested_level, reg)) out_of_memory();
  }

  void insn_flush_struct (JitValue value) {
    assert(this.valid);
    assert(value.valid);
    if (!jit_insn_flush_struct(func, value.raw)) out_of_memory();
  }

  JitValue insn_import (JitValue value) {
    assert(this.valid);
    assert(value.valid);
    return wrapValue(jit_insn_import(func, value.raw));
  }

  void insn_push (JitValue value) {
    assert(this.valid);
    assert(value.valid);
    if (!jit_insn_push(func, value.raw)) out_of_memory();
  }

  void insn_push_ptr (JitValue value, jit_type_t type) {
    assert(this.valid);
    assert(value.valid && type !is null);
    if (!jit_insn_push_ptr(func, value.raw, type)) out_of_memory();
  }

  void insn_set_param (JitValue value, jit_nint offset) {
    assert(this.valid);
    assert(value.valid);
    if (!jit_insn_set_param(func, value.raw, offset)) out_of_memory();
  }

  void insn_set_param_ptr (JitValue value, jit_type_t type, jit_nint offset) {
    assert(this.valid);
    assert(value.valid && type !is null);
    if (!jit_insn_set_param_ptr(func, value.raw, type, offset)) out_of_memory();
  }

  void insn_push_return_area_ptr () {
    assert(this.valid);
    if (!jit_insn_push_return_area_ptr(func)) out_of_memory();
  }

  void insn_return (JitValue value) {
    assert(this.valid);
    assert(value.valid);
    if (!jit_insn_return(func, value.raw)) out_of_memory();
  }

  void insn_return () {
    assert(this.valid);
    if (!jit_insn_return(func, null)) out_of_memory();
  }

  void insn_return_ptr (JitValue value, jit_type_t type) {
    assert(this.valid);
    assert(value.valid && type !is null);
    if (!jit_insn_return_ptr(func, value.raw, type)) out_of_memory();
  }

  void insn_default_return () {
    assert(this.valid);
    if (!jit_insn_default_return(func)) out_of_memory();
  }

  void insn_throw (JitValue value) {
    assert(this.valid);
    assert(value.valid);
    if (!jit_insn_throw(func, value.raw)) out_of_memory();
  }

  JitValue insn_get_call_stack () {
    assert(this.valid);
    return wrapValue(jit_insn_get_call_stack(func));
  }

  JitValue insn_thrown_exception () {
    assert(this.valid);
    return wrapValue(jit_insn_thrown_exception(func));
  }

  void insn_uses_catcher () {
    assert(this.valid);
    if (!jit_insn_uses_catcher(func)) out_of_memory();
  }

  JitValue insn_start_catcher () {
    assert(this.valid);
    return wrapValue(jit_insn_start_catcher(func));
  }

  void insn_branch_if_pc_not_in_range (JitLabel start_label, JitLabel end_label, JitLabel label) {
    assert(this.valid);
    assert(start_label.valid && end_label.valid && label.valid);
    if (!jit_insn_branch_if_pc_not_in_range(func, start_label.raw, end_label.raw, label.rawp)) out_of_memory();
  }

  void insn_rethrow_unhandled () {
    assert(this.valid);
    if (!jit_insn_rethrow_unhandled(func)) out_of_memory();
  }

  void insn_start_finally (JitLabel label) {
    assert(this.valid);
    assert(label.valid);
    if (!jit_insn_start_finally(func, label.rawp)) out_of_memory();
  }

  void insn_return_from_finally () {
    assert(this.valid);
    if (!jit_insn_return_from_finally(func)) out_of_memory();
  }

  void insn_call_finally (JitLabel label) {
    assert(this.valid);
    assert(label.valid);
    if (!jit_insn_call_finally(func, label.rawp)) out_of_memory();
  }

  JitValue insn_start_filter (JitLabel label, jit_type_t type) {
    assert(this.valid);
    assert(label.valid && type !is null);
    return wrapValue(jit_insn_start_filter(func, label.rawp, type));
  }

  void insn_return_from_filter (JitValue value) {
    assert(this.valid);
    assert(value.valid);
    if (!jit_insn_return_from_filter(func, value.raw)) out_of_memory();
  }

  JitValue insn_call_filter (JitLabel label, JitValue value, jit_type_t type) {
    assert(this.valid);
    assert(label.valid && value.valid && type !is null);
    return wrapValue(jit_insn_call_filter(func, label.rawp, value.raw, type));
  }

  void insn_memcpy (JitValue dest, JitValue src, JitValue size) {
    assert(this.valid);
    assert(dest.valid && src.valid && size.valid);
    if (!jit_insn_memcpy(func, dest.raw, src.raw, size.raw)) out_of_memory();
  }

  void insn_memmove (JitValue dest, JitValue src, JitValue size) {
    assert(this.valid);
    assert(dest.valid && src.valid && size.valid);
    if (!jit_insn_memmove(func, dest.raw, src.raw, size.raw)) out_of_memory();
  }

  void insn_memset (JitValue dest, JitValue value, JitValue size) {
    assert(this.valid);
    assert(dest.valid && value.valid && size.valid);
    if (!jit_insn_memset(func, dest.raw, value.raw, size.raw)) out_of_memory();
  }

  JitValue insn_alloca (JitValue size) {
    assert(this.valid);
    assert(size.valid);
    return wrapValue(jit_insn_alloca(func, size.raw));
  }

  void insn_move_blocks_to_end (JitLabel from_label, JitLabel to_label) {
    assert(this.valid);
    assert(from_label.valid && to_label.valid);
    if (!jit_insn_move_blocks_to_end(func, from_label.raw, to_label.raw)) out_of_memory();
  }

  void insn_move_blocks_to_start (JitLabel from_label, JitLabel to_label) {
    assert(this.valid);
    assert(from_label.valid && to_label.valid);
    if (!jit_insn_move_blocks_to_start(func, from_label.raw, to_label.raw)) out_of_memory();
  }

  void insn_mark_offset (jit_int offset) {
    assert(this.valid);
    if (!jit_insn_mark_offset(func, offset)) out_of_memory();
  }

  void insn_mark_breakpoint (jit_nint data1, jit_nint data2) {
    assert(this.valid);
    if (!jit_insn_mark_breakpoint(func, data1, data2)) out_of_memory();
  }

private:
  void registerOnDemand () {
    jit_function_set_on_demand_compiler(func, &onDemandCompiler);
  }

  static extern(C) int onDemandCompiler (jit_function_t func) nothrow {
    // get the object that corresponds to the raw function
    auto func_object = getFuncObjFromRaw(func);
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

  static extern(C) void freeMapping (void* data) nothrow {
    // If we were called during the context's shutdown,
    // then the raw function pointer is no longer valid.
    (cast(JitFunction)data).func = null;
  }
}
