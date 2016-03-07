/*
 * jit.h - General definitions for JIT back-ends.
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
module iv.libjit;
pragma(lib, "jit");
extern(C) nothrow /*@nogc*/:
// "@nogc" removed due to callbacks -- there's no reason to forbid GC usage there


alias jit_sbyte = byte;
alias jit_ubyte = ubyte;
alias jit_short = short;
alias jit_ushort = ushort;
alias jit_int = int;
alias jit_uint = uint;
static if ((void*).sizeof == 4) {
  alias jit_nint = int; // "native"
  alias jit_nuint = uint; // "native"
} else {
  alias jit_nint = long; // "native"
  alias jit_nuint = ulong; // "native"
}
alias jit_long = long;
alias jit_ulong = ulong;
alias jit_float32 = float;
alias jit_float64 = double;
alias jit_nfloat = real/*long double*/; //k8: seems to be the same for x86
alias jit_ptr = void*;

static if ((void*).sizeof == 4) {
  enum JIT_NATIVE_INT32 = true;
} else {
  static assert((void*).sizeof == 8, "wtf?!");
  enum JIT_NATIVE_INT32 = false;
}


/*
#if defined(__cplusplus) && defined(__GNUC__)
#define JIT_NOTHROW   throw()
#else
#define JIT_NOTHROW
#endif
*/

enum jit_min_int   = ((cast(jit_int)1) << (jit_int.sizeof * 8 - 1));
enum jit_max_int   = (cast(jit_int)(~jit_min_int));
enum jit_max_uint  = (cast(jit_uint)(~(cast(jit_uint)0)));
enum jit_min_long  = ((cast(jit_long)1) << (jit_long.sizeof * 8 - 1));
enum jit_max_long  = (cast(jit_long)(~jit_min_long));
enum jit_max_ulong = (cast(jit_ulong)(~(cast(jit_ulong)0)));

/*
 * Opaque structure that represents a context.
 */
struct _jit_context {}
alias jit_context_t = _jit_context*;

/*
 * Opaque structure that represents a function.
 */
struct _jit_function {}
alias jit_function_t = _jit_function*;

/*
 * Opaque structure that represents a block.
 */
struct _jit_block {}
alias jit_block_t = _jit_block*;

/*
 * Opaque structure that represents an instruction.
 */
struct _jit_insn {}
alias jit_insn_t = _jit_insn*;

/*
 * Opaque structure that represents a value.
 */
struct _jit_value {}
alias jit_value_t = _jit_value*;

/*
 * Opaque structure that represents a type descriptor.
 */
struct _jit_type {}
alias jit_type_t = _jit_type*;

/*
 * Opaque type that represents an exception stack trace.
 */
struct jit_stack_trace {}
alias jit_stack_trace_t = jit_stack_trace*;

/*
 * Block label identifier.
 */
alias jit_label_t = jit_nuint;

/*
 * Value that represents an undefined label.
 */
enum jit_label_undefined = (cast(jit_label_t)~(cast(jit_uint)0));

/*
 * Value that represents an undefined offset.
 */
enum JIT_NO_OFFSET = (~(cast(uint)0));

/*
 * Function that is used to free user-supplied metadata.
 */
alias jit_meta_free_func = void function (void* data);

/*
 * Function that is used to compile a function on demand.
 * Returns zero if the compilation process failed for some reason.
 */
alias jit_on_demand_func = int function (jit_function_t func);

/*
 * Function that is used to control on demand compilation.
 * Typically, it should take care of the context locking and unlocking,
 * calling function's on demand compiler, and final compilation.
 */
alias jit_on_demand_driver_func = void* function (jit_function_t func);

jit_context_t jit_context_create() /*JIT_NOTHROW*/;
void jit_context_destroy(jit_context_t context) /*JIT_NOTHROW*/;

void jit_context_build_start(jit_context_t context) /*JIT_NOTHROW*/;
void jit_context_build_end(jit_context_t context) /*JIT_NOTHROW*/;

void jit_context_set_on_demand_driver(
  jit_context_t context,
  jit_on_demand_driver_func driver) /*JIT_NOTHROW*/;

void jit_context_set_memory_manager(
  jit_context_t context,
  jit_memory_manager_t manager) /*JIT_NOTHROW*/;

int jit_context_set_meta
  (jit_context_t context, int type, void* data,
   jit_meta_free_func free_data) /*JIT_NOTHROW*/;
int jit_context_set_meta_numeric
  (jit_context_t context, int type, jit_nuint data) /*JIT_NOTHROW*/;
void* jit_context_get_meta(jit_context_t context, int type) /*JIT_NOTHROW*/;
jit_nuint jit_context_get_meta_numeric
  (jit_context_t context, int type) /*JIT_NOTHROW*/;
void jit_context_free_meta(jit_context_t context, int type) /*JIT_NOTHROW*/;

/*
 * Standard meta values for builtin configurable options.
 */
enum JIT_OPTION_CACHE_LIMIT = 10000;
enum JIT_OPTION_CACHE_PAGE_SIZE = 10001;
enum JIT_OPTION_PRE_COMPILE = 10002;
enum JIT_OPTION_DONT_FOLD = 10003;
enum JIT_OPTION_POSITION_INDEPENDENT = 10004;
enum JIT_OPTION_CACHE_MAX_PAGE_FACTOR = 10005;


/*
 * Prototype for closure functions.
 */
alias jit_closure_func = void function (jit_type_t signature, void* result, void** args, void* user_data);

/*
 * Opaque type for accessing vararg parameters on closures.
 */
struct jit_closure_va_list {}
alias jit_closure_va_list_t = jit_closure_va_list*;

/*
 * External function declarations.
 */
void jit_apply(jit_type_t signature, void* func,
               void** args, uint num_fixed_args,
               void* return_value);
void jit_apply_raw(jit_type_t signature, void* func,
                   void* args, void* return_value);
int jit_raw_supported(jit_type_t signature);

void* jit_closure_create(jit_context_t context, jit_type_t signature,
       jit_closure_func func, void* user_data);

jit_nint jit_closure_va_get_nint(jit_closure_va_list_t va);
jit_nuint jit_closure_va_get_nuint(jit_closure_va_list_t va);
jit_long jit_closure_va_get_long(jit_closure_va_list_t va);
jit_ulong jit_closure_va_get_ulong(jit_closure_va_list_t va);
jit_float32 jit_closure_va_get_float32(jit_closure_va_list_t va);
jit_float64 jit_closure_va_get_float64(jit_closure_va_list_t va);
jit_nfloat jit_closure_va_get_nfloat(jit_closure_va_list_t va);
void* jit_closure_va_get_ptr(jit_closure_va_list_t va);
void jit_closure_va_get_struct(jit_closure_va_list_t va, void* buf, jit_type_t type);

jit_function_t jit_block_get_function(jit_block_t block) /*JIT_NOTHROW*/;
jit_context_t jit_block_get_context(jit_block_t block) /*JIT_NOTHROW*/;
jit_label_t jit_block_get_label(jit_block_t block) /*JIT_NOTHROW*/;
jit_label_t jit_block_get_next_label(jit_block_t block,
             jit_label_t label) /*JIT_NOTHROW*/;
jit_block_t jit_block_next(jit_function_t func,
         jit_block_t previous) /*JIT_NOTHROW*/;
jit_block_t jit_block_previous(jit_function_t func,
             jit_block_t previous) /*JIT_NOTHROW*/;
jit_block_t jit_block_from_label(jit_function_t func,
         jit_label_t label) /*JIT_NOTHROW*/;
int jit_block_set_meta(jit_block_t block, int type, void* data,
           jit_meta_free_func free_data) /*JIT_NOTHROW*/;
void* jit_block_get_meta(jit_block_t block, int type) /*JIT_NOTHROW*/;
void jit_block_free_meta(jit_block_t block, int type) /*JIT_NOTHROW*/;
int jit_block_is_reachable(jit_block_t block) /*JIT_NOTHROW*/;
int jit_block_ends_in_dead(jit_block_t block) /*JIT_NOTHROW*/;
int jit_block_current_is_dead(jit_function_t func) /*JIT_NOTHROW*/;

struct jit_debugger {}
alias jit_debugger_t = jit_debugger*;
alias jit_debugger_thread_id_t = jit_nint;
alias jit_debugger_breakpoint_id_t = jit_nint;

struct jit_debugger_event
{
  int               type;
  jit_debugger_thread_id_t    thread;
  jit_function_t          function_;
  jit_nint            data1;
  jit_nint            data2;
  jit_debugger_breakpoint_id_t  id;
  jit_stack_trace_t       trace;

}
alias jit_debugger_event_t = jit_debugger_event;

enum JIT_DEBUGGER_TYPE_QUIT = 0;
enum JIT_DEBUGGER_TYPE_HARD_BREAKPOINT = 1;
enum JIT_DEBUGGER_TYPE_SOFT_BREAKPOINT = 2;
enum JIT_DEBUGGER_TYPE_USER_BREAKPOINT = 3;
enum JIT_DEBUGGER_TYPE_ATTACH_THREAD = 4;
enum JIT_DEBUGGER_TYPE_DETACH_THREAD = 5;

struct jit_debugger_breakpoint_info
{
  int               flags;
  jit_debugger_thread_id_t    thread;
  jit_function_t          function_;
  jit_nint            data1;
  jit_nint            data2;

}
alias jit_debugger_breakpoint_info_t = jit_debugger_breakpoint_info*;

enum JIT_DEBUGGER_FLAG_THREAD = (1 << 0);
enum JIT_DEBUGGER_FLAG_FUNCTION = (1 << 1);
enum JIT_DEBUGGER_FLAG_DATA1 = (1 << 2);
enum JIT_DEBUGGER_FLAG_DATA2 = (1 << 3);

enum JIT_DEBUGGER_DATA1_FIRST = 10000;
enum JIT_DEBUGGER_DATA1_LINE = 10000;
enum JIT_DEBUGGER_DATA1_ENTER = 10001;
enum JIT_DEBUGGER_DATA1_LEAVE = 10002;
enum JIT_DEBUGGER_DATA1_THROW = 10003;

alias jit_debugger_hook_func = void function (jit_function_t func, jit_nint data1, jit_nint data2);

int jit_debugging_possible() /*JIT_NOTHROW*/;

jit_debugger_t jit_debugger_create(jit_context_t context) /*JIT_NOTHROW*/;
void jit_debugger_destroy(jit_debugger_t dbg) /*JIT_NOTHROW*/;

jit_context_t jit_debugger_get_context(jit_debugger_t dbg) /*JIT_NOTHROW*/;
jit_debugger_t jit_debugger_from_context(jit_context_t context) /*JIT_NOTHROW*/;

jit_debugger_thread_id_t jit_debugger_get_self(jit_debugger_t dbg) /*JIT_NOTHROW*/;
jit_debugger_thread_id_t jit_debugger_get_thread
    (jit_debugger_t dbg, const(void)* native_thread) /*JIT_NOTHROW*/;
int jit_debugger_get_native_thread
    (jit_debugger_t dbg, jit_debugger_thread_id_t thread,
     void* native_thread) /*JIT_NOTHROW*/;
void jit_debugger_set_breakable
    (jit_debugger_t dbg, const(void)* native_thread, int flag) /*JIT_NOTHROW*/;

void jit_debugger_attach_self
    (jit_debugger_t dbg, int stop_immediately) /*JIT_NOTHROW*/;
void jit_debugger_detach_self(jit_debugger_t dbg) /*JIT_NOTHROW*/;

int jit_debugger_wait_event
    (jit_debugger_t dbg, jit_debugger_event_t* event,
     jit_int timeout) /*JIT_NOTHROW*/;

jit_debugger_breakpoint_id_t jit_debugger_add_breakpoint
    (jit_debugger_t dbg, jit_debugger_breakpoint_info_t info) /*JIT_NOTHROW*/;
void jit_debugger_remove_breakpoint
    (jit_debugger_t dbg, jit_debugger_breakpoint_id_t id) /*JIT_NOTHROW*/;
void jit_debugger_remove_all_breakpoints(jit_debugger_t dbg) /*JIT_NOTHROW*/;

int jit_debugger_is_alive
    (jit_debugger_t dbg, jit_debugger_thread_id_t thread) /*JIT_NOTHROW*/;
int jit_debugger_is_running
    (jit_debugger_t dbg, jit_debugger_thread_id_t thread) /*JIT_NOTHROW*/;
void jit_debugger_run
    (jit_debugger_t dbg, jit_debugger_thread_id_t thread) /*JIT_NOTHROW*/;
void jit_debugger_step
    (jit_debugger_t dbg, jit_debugger_thread_id_t thread) /*JIT_NOTHROW*/;
void jit_debugger_next
    (jit_debugger_t dbg, jit_debugger_thread_id_t thread) /*JIT_NOTHROW*/;
void jit_debugger_finish
    (jit_debugger_t dbg, jit_debugger_thread_id_t thread) /*JIT_NOTHROW*/;

void jit_debugger_break(jit_debugger_t dbg) /*JIT_NOTHROW*/;

void jit_debugger_quit(jit_debugger_t dbg) /*JIT_NOTHROW*/;

jit_debugger_hook_func jit_debugger_set_hook (jit_context_t context, jit_debugger_hook_func hook);


/*
 * Opaque types that represent a loaded ELF binary in read or write mode.
 */
struct jit_readelf {}
alias jit_readelf_t = jit_readelf*;
struct jit_writeelf {}
alias jit_writeelf_t = jit_writeelf*;

/*
 * Flags for "jit_readelf_open".
 */
enum JIT_READELF_FLAG_FORCE = (1 << 0); /* Force file to load */
enum JIT_READELF_FLAG_DEBUG = (1 << 1); /* Print debugging information */

/*
 * Result codes from "jit_readelf_open".
 */
enum JIT_READELF_OK = 0; /* File was opened successfully */
enum JIT_READELF_CANNOT_OPEN = 1; /* Could not open the file */
enum JIT_READELF_NOT_ELF = 2; /* Not an ELF-format binary */
enum JIT_READELF_WRONG_ARCH = 3; /* Wrong architecture for local system */
enum JIT_READELF_BAD_FORMAT = 4; /* ELF file, but badly formatted */
enum JIT_READELF_MEMORY = 5; /* Insufficient memory to load the file */

/*
 * External function declarations.
 */
int jit_readelf_open
  (jit_readelf_t* readelf, const(char)* filename, int flags) /*JIT_NOTHROW*/;
void jit_readelf_close(jit_readelf_t readelf) /*JIT_NOTHROW*/;
const(char)* jit_readelf_get_name(jit_readelf_t readelf) /*JIT_NOTHROW*/;
void* jit_readelf_get_symbol
  (jit_readelf_t readelf, const(char)* name) /*JIT_NOTHROW*/;
void* jit_readelf_get_section
  (jit_readelf_t readelf, const(char)* name, jit_nuint* size) /*JIT_NOTHROW*/;
void* jit_readelf_get_section_by_type
  (jit_readelf_t readelf, jit_int type, jit_nuint* size) /*JIT_NOTHROW*/;
void* jit_readelf_map_vaddr
  (jit_readelf_t readelf, jit_nuint vaddr) /*JIT_NOTHROW*/;
uint jit_readelf_num_needed(jit_readelf_t readelf) /*JIT_NOTHROW*/;
const(char)* jit_readelf_get_needed
  (jit_readelf_t readelf, uint index) /*JIT_NOTHROW*/;
void jit_readelf_add_to_context
  (jit_readelf_t readelf, jit_context_t context) /*JIT_NOTHROW*/;
int jit_readelf_resolve_all
  (jit_context_t context, int print_failures) /*JIT_NOTHROW*/;
int jit_readelf_register_symbol
  (jit_context_t context, const(char)* name,
   void* value, int after) /*JIT_NOTHROW*/;

jit_writeelf_t jit_writeelf_create(const(char)* library_name) /*JIT_NOTHROW*/;
void jit_writeelf_destroy(jit_writeelf_t writeelf) /*JIT_NOTHROW*/;
int jit_writeelf_write
  (jit_writeelf_t writeelf, const(char)* filename) /*JIT_NOTHROW*/;
int jit_writeelf_add_function
  (jit_writeelf_t writeelf, jit_function_t func,
   const(char)* name) /*JIT_NOTHROW*/;
int jit_writeelf_add_needed
  (jit_writeelf_t writeelf, const(char)* library_name) /*JIT_NOTHROW*/;
int jit_writeelf_write_section
  (jit_writeelf_t writeelf, const(char)* name, jit_int type,
   const(void)* buf, uint len, int discardable) /*JIT_NOTHROW*/;

/*
 * Builtin exception type codes, and result values for intrinsic functions.
 */
enum JIT_RESULT_OK = (1);
enum JIT_RESULT_OVERFLOW = (0);
enum JIT_RESULT_ARITHMETIC = (-1);
enum JIT_RESULT_DIVISION_BY_ZERO = (-2);
enum JIT_RESULT_COMPILE_ERROR = (-3);
enum JIT_RESULT_OUT_OF_MEMORY = (-4);
enum JIT_RESULT_NULL_REFERENCE = (-5);
enum JIT_RESULT_NULL_FUNCTION = (-6);
enum JIT_RESULT_CALLED_NESTED = (-7);
enum JIT_RESULT_OUT_OF_BOUNDS = (-8);
enum JIT_RESULT_UNDEFINED_LABEL = (-9);
enum JIT_RESULT_MEMORY_FULL = (-10000);

/*
 * Exception handling function for builtin exceptions.
 */
alias jit_exception_func = void* function (int exception_type);

/*
 * External function declarations.
 */
void* jit_exception_get_last();
void* jit_exception_get_last_and_clear();
void jit_exception_set_last(void* object);
void jit_exception_clear_last();
void jit_exception_throw(void* object);
void jit_exception_builtin(int exception_type);
jit_exception_func jit_exception_set_handler(jit_exception_func handler);
jit_exception_func jit_exception_get_handler();
jit_stack_trace_t jit_exception_get_stack_trace();
uint jit_stack_trace_get_size(jit_stack_trace_t trace);
jit_function_t jit_stack_trace_get_function(jit_context_t context,
              jit_stack_trace_t trace,
              uint posn);
void* jit_stack_trace_get_pc(jit_stack_trace_t trace, uint posn);
uint jit_stack_trace_get_offset(jit_context_t context,
          jit_stack_trace_t trace,
          uint posn);
void jit_stack_trace_free(jit_stack_trace_t trace);


/* Optimization levels */
enum JIT_OPTLEVEL_NONE = 0;
enum JIT_OPTLEVEL_NORMAL = 1;

jit_function_t jit_function_create
  (jit_context_t context, jit_type_t signature) /*JIT_NOTHROW*/;
jit_function_t jit_function_create_nested
  (jit_context_t context, jit_type_t signature,
   jit_function_t parent) /*JIT_NOTHROW*/;
void jit_function_abandon(jit_function_t func) /*JIT_NOTHROW*/;
jit_context_t jit_function_get_context(jit_function_t func) /*JIT_NOTHROW*/;
jit_type_t jit_function_get_signature(jit_function_t func) /*JIT_NOTHROW*/;
int jit_function_set_meta
  (jit_function_t func, int type, void* data,
   jit_meta_free_func free_data, int build_only) /*JIT_NOTHROW*/;
void* jit_function_get_meta(jit_function_t func, int type) /*JIT_NOTHROW*/;
void jit_function_free_meta(jit_function_t func, int type) /*JIT_NOTHROW*/;
jit_function_t jit_function_next
  (jit_context_t context, jit_function_t prev) /*JIT_NOTHROW*/;
jit_function_t jit_function_previous
  (jit_context_t context, jit_function_t prev) /*JIT_NOTHROW*/;
jit_block_t jit_function_get_entry(jit_function_t func) /*JIT_NOTHROW*/;
jit_block_t jit_function_get_current(jit_function_t func) /*JIT_NOTHROW*/;
jit_function_t jit_function_get_nested_parent(jit_function_t func) /*JIT_NOTHROW*/;
int jit_function_compile(jit_function_t func) /*JIT_NOTHROW*/;
int jit_function_is_compiled(jit_function_t func) /*JIT_NOTHROW*/;
void jit_function_set_recompilable(jit_function_t func) /*JIT_NOTHROW*/;
void jit_function_clear_recompilable(jit_function_t func) /*JIT_NOTHROW*/;
int jit_function_is_recompilable(jit_function_t func) /*JIT_NOTHROW*/;
int jit_function_compile_entry(jit_function_t func, void** entry_point) /*JIT_NOTHROW*/;
void jit_function_setup_entry(jit_function_t func, void* entry_point) /*JIT_NOTHROW*/;
void* jit_function_to_closure(jit_function_t func) /*JIT_NOTHROW*/;
jit_function_t jit_function_from_closure
  (jit_context_t context, void* closure) /*JIT_NOTHROW*/;
jit_function_t jit_function_from_pc
  (jit_context_t context, void* pc, void** handler) /*JIT_NOTHROW*/;
void* jit_function_to_vtable_pointer(jit_function_t func) /*JIT_NOTHROW*/;
jit_function_t jit_function_from_vtable_pointer
  (jit_context_t context, void* vtable_pointer) /*JIT_NOTHROW*/;
void jit_function_set_on_demand_compiler
  (jit_function_t func, jit_on_demand_func on_demand) /*JIT_NOTHROW*/;
jit_on_demand_func jit_function_get_on_demand_compiler(jit_function_t func) /*JIT_NOTHROW*/;
int jit_function_apply
  (jit_function_t func, void** args, void* return_area);
int jit_function_apply_vararg
  (jit_function_t func, jit_type_t signature, void** args, void* return_area);
void jit_function_set_optimization_level
  (jit_function_t func, uint level) /*JIT_NOTHROW*/;
uint jit_function_get_optimization_level
  (jit_function_t func) /*JIT_NOTHROW*/;
uint jit_function_get_max_optimization_level() /*JIT_NOTHROW*/;
jit_label_t jit_function_reserve_label(jit_function_t func) /*JIT_NOTHROW*/;
int jit_function_labels_equal(jit_function_t func, jit_label_t label, jit_label_t label2);


void jit_init() /*JIT_NOTHROW*/;

int jit_uses_interpreter() /*JIT_NOTHROW*/;

int jit_supports_threads() /*JIT_NOTHROW*/;

int jit_supports_virtual_memory() /*JIT_NOTHROW*/;

int jit_supports_closures();

uint jit_get_closure_size();
uint jit_get_closure_alignment();
uint jit_get_trampoline_size();
uint jit_get_trampoline_alignment();


/*
 * Descriptor for an intrinsic function.
 */
struct jit_intrinsic_descr_t
{
  jit_type_t    return_type;
  jit_type_t    ptr_result_type;
  jit_type_t    arg1_type;
  jit_type_t    arg2_type;
}

/*
 * Structure for iterating over the instructions in a block.
 * This should be treated as opaque.
 */
struct jit_insn_iter_t
{
  jit_block_t   block;
  int       posn;
}

/*
 * Flags for "jit_insn_call" and friends.
 */
enum JIT_CALL_NOTHROW = (1 << 0);
enum JIT_CALL_NORETURN = (1 << 1);
enum JIT_CALL_TAIL = (1 << 2);

int jit_insn_get_opcode(jit_insn_t insn) /*JIT_NOTHROW*/;
jit_value_t jit_insn_get_dest(jit_insn_t insn) /*JIT_NOTHROW*/;
jit_value_t jit_insn_get_value1(jit_insn_t insn) /*JIT_NOTHROW*/;
jit_value_t jit_insn_get_value2(jit_insn_t insn) /*JIT_NOTHROW*/;
jit_label_t jit_insn_get_label(jit_insn_t insn) /*JIT_NOTHROW*/;
jit_function_t jit_insn_get_function(jit_insn_t insn) /*JIT_NOTHROW*/;
void* jit_insn_get_native(jit_insn_t insn) /*JIT_NOTHROW*/;
const(char)* jit_insn_get_name(jit_insn_t insn) /*JIT_NOTHROW*/;
jit_type_t jit_insn_get_signature(jit_insn_t insn) /*JIT_NOTHROW*/;
int jit_insn_dest_is_value(jit_insn_t insn) /*JIT_NOTHROW*/;

int jit_insn_label(jit_function_t func, jit_label_t* label) /*JIT_NOTHROW*/;
int jit_insn_new_block(jit_function_t func) /*JIT_NOTHROW*/;
jit_value_t jit_insn_load(jit_function_t func, jit_value_t value) /*JIT_NOTHROW*/;
jit_value_t jit_insn_dup(jit_function_t func, jit_value_t value) /*JIT_NOTHROW*/;
jit_value_t jit_insn_load_small
  (jit_function_t func, jit_value_t value) /*JIT_NOTHROW*/;
int jit_insn_store
  (jit_function_t func, jit_value_t dest, jit_value_t value) /*JIT_NOTHROW*/;
jit_value_t jit_insn_load_relative
  (jit_function_t func, jit_value_t value,
   jit_nint offset, jit_type_t type) /*JIT_NOTHROW*/;
int jit_insn_store_relative
  (jit_function_t func, jit_value_t dest,
   jit_nint offset, jit_value_t value) /*JIT_NOTHROW*/;
jit_value_t jit_insn_add_relative
  (jit_function_t func, jit_value_t value, jit_nint offset) /*JIT_NOTHROW*/;
jit_value_t jit_insn_load_elem
  (jit_function_t func, jit_value_t base_addr,
   jit_value_t index, jit_type_t elem_type) /*JIT_NOTHROW*/;
jit_value_t jit_insn_load_elem_address
  (jit_function_t func, jit_value_t base_addr,
   jit_value_t index, jit_type_t elem_type) /*JIT_NOTHROW*/;
int jit_insn_store_elem
  (jit_function_t func, jit_value_t base_addr,
   jit_value_t index, jit_value_t value) /*JIT_NOTHROW*/;
int jit_insn_check_null(jit_function_t func, jit_value_t value) /*JIT_NOTHROW*/;

jit_value_t jit_insn_add
  (jit_function_t func, jit_value_t value1, jit_value_t value2) /*JIT_NOTHROW*/;
jit_value_t jit_insn_add_ovf
  (jit_function_t func, jit_value_t value1, jit_value_t value2) /*JIT_NOTHROW*/;
jit_value_t jit_insn_sub
  (jit_function_t func, jit_value_t value1, jit_value_t value2) /*JIT_NOTHROW*/;
jit_value_t jit_insn_sub_ovf
  (jit_function_t func, jit_value_t value1, jit_value_t value2) /*JIT_NOTHROW*/;
jit_value_t jit_insn_mul
  (jit_function_t func, jit_value_t value1, jit_value_t value2) /*JIT_NOTHROW*/;
jit_value_t jit_insn_mul_ovf
  (jit_function_t func, jit_value_t value1, jit_value_t value2) /*JIT_NOTHROW*/;
jit_value_t jit_insn_div
  (jit_function_t func, jit_value_t value1, jit_value_t value2) /*JIT_NOTHROW*/;
jit_value_t jit_insn_rem
  (jit_function_t func, jit_value_t value1, jit_value_t value2) /*JIT_NOTHROW*/;
jit_value_t jit_insn_rem_ieee
  (jit_function_t func, jit_value_t value1, jit_value_t value2) /*JIT_NOTHROW*/;
jit_value_t jit_insn_neg
  (jit_function_t func, jit_value_t value1) /*JIT_NOTHROW*/;
jit_value_t jit_insn_and
  (jit_function_t func, jit_value_t value1, jit_value_t value2) /*JIT_NOTHROW*/;
jit_value_t jit_insn_or
  (jit_function_t func, jit_value_t value1, jit_value_t value2) /*JIT_NOTHROW*/;
jit_value_t jit_insn_xor
  (jit_function_t func, jit_value_t value1, jit_value_t value2) /*JIT_NOTHROW*/;
jit_value_t jit_insn_not
  (jit_function_t func, jit_value_t value1) /*JIT_NOTHROW*/;
jit_value_t jit_insn_shl
  (jit_function_t func, jit_value_t value1, jit_value_t value2) /*JIT_NOTHROW*/;
jit_value_t jit_insn_shr
  (jit_function_t func, jit_value_t value1, jit_value_t value2) /*JIT_NOTHROW*/;
jit_value_t jit_insn_ushr
  (jit_function_t func, jit_value_t value1, jit_value_t value2) /*JIT_NOTHROW*/;
jit_value_t jit_insn_sshr
  (jit_function_t func, jit_value_t value1, jit_value_t value2) /*JIT_NOTHROW*/;
jit_value_t jit_insn_eq
  (jit_function_t func, jit_value_t value1, jit_value_t value2) /*JIT_NOTHROW*/;
jit_value_t jit_insn_ne
  (jit_function_t func, jit_value_t value1, jit_value_t value2) /*JIT_NOTHROW*/;
jit_value_t jit_insn_lt
  (jit_function_t func, jit_value_t value1, jit_value_t value2) /*JIT_NOTHROW*/;
jit_value_t jit_insn_le
  (jit_function_t func, jit_value_t value1, jit_value_t value2) /*JIT_NOTHROW*/;
jit_value_t jit_insn_gt
  (jit_function_t func, jit_value_t value1, jit_value_t value2) /*JIT_NOTHROW*/;
jit_value_t jit_insn_ge
  (jit_function_t func, jit_value_t value1, jit_value_t value2) /*JIT_NOTHROW*/;
jit_value_t jit_insn_cmpl
  (jit_function_t func, jit_value_t value1, jit_value_t value2) /*JIT_NOTHROW*/;
jit_value_t jit_insn_cmpg
  (jit_function_t func, jit_value_t value1, jit_value_t value2) /*JIT_NOTHROW*/;
jit_value_t jit_insn_to_bool
  (jit_function_t func, jit_value_t value1) /*JIT_NOTHROW*/;
jit_value_t jit_insn_to_not_bool
  (jit_function_t func, jit_value_t value1) /*JIT_NOTHROW*/;
jit_value_t jit_insn_acos
  (jit_function_t func, jit_value_t value1) /*JIT_NOTHROW*/;
jit_value_t jit_insn_asin
  (jit_function_t func, jit_value_t value1) /*JIT_NOTHROW*/;
jit_value_t jit_insn_atan
  (jit_function_t func, jit_value_t value1) /*JIT_NOTHROW*/;
jit_value_t jit_insn_atan2
  (jit_function_t func, jit_value_t value1, jit_value_t value2) /*JIT_NOTHROW*/;
jit_value_t jit_insn_ceil
  (jit_function_t func, jit_value_t value1) /*JIT_NOTHROW*/;
jit_value_t jit_insn_cos
  (jit_function_t func, jit_value_t value1) /*JIT_NOTHROW*/;
jit_value_t jit_insn_cosh
  (jit_function_t func, jit_value_t value1) /*JIT_NOTHROW*/;
jit_value_t jit_insn_exp
  (jit_function_t func, jit_value_t value1) /*JIT_NOTHROW*/;
jit_value_t jit_insn_floor
  (jit_function_t func, jit_value_t value1) /*JIT_NOTHROW*/;
jit_value_t jit_insn_log
  (jit_function_t func, jit_value_t value1) /*JIT_NOTHROW*/;
jit_value_t jit_insn_log10
  (jit_function_t func, jit_value_t value1) /*JIT_NOTHROW*/;
jit_value_t jit_insn_pow
  (jit_function_t func, jit_value_t value1, jit_value_t value2) /*JIT_NOTHROW*/;
jit_value_t jit_insn_rint
  (jit_function_t func, jit_value_t value1) /*JIT_NOTHROW*/;
jit_value_t jit_insn_round
  (jit_function_t func, jit_value_t value1) /*JIT_NOTHROW*/;
jit_value_t jit_insn_sin
  (jit_function_t func, jit_value_t value1) /*JIT_NOTHROW*/;
jit_value_t jit_insn_sinh
  (jit_function_t func, jit_value_t value1) /*JIT_NOTHROW*/;
jit_value_t jit_insn_sqrt
  (jit_function_t func, jit_value_t value1) /*JIT_NOTHROW*/;
jit_value_t jit_insn_tan
  (jit_function_t func, jit_value_t value1) /*JIT_NOTHROW*/;
jit_value_t jit_insn_tanh
  (jit_function_t func, jit_value_t value1) /*JIT_NOTHROW*/;
jit_value_t jit_insn_trunc
  (jit_function_t func, jit_value_t value1) /*JIT_NOTHROW*/;
jit_value_t jit_insn_is_nan
  (jit_function_t func, jit_value_t value1) /*JIT_NOTHROW*/;
jit_value_t jit_insn_is_finite
  (jit_function_t func, jit_value_t value1) /*JIT_NOTHROW*/;
jit_value_t jit_insn_is_inf
  (jit_function_t func, jit_value_t value1) /*JIT_NOTHROW*/;
jit_value_t jit_insn_abs
  (jit_function_t func, jit_value_t value1) /*JIT_NOTHROW*/;
jit_value_t jit_insn_min
  (jit_function_t func, jit_value_t value1, jit_value_t value2) /*JIT_NOTHROW*/;
jit_value_t jit_insn_max
  (jit_function_t func, jit_value_t value1, jit_value_t value2) /*JIT_NOTHROW*/;
jit_value_t jit_insn_sign
  (jit_function_t func, jit_value_t value1) /*JIT_NOTHROW*/;
int jit_insn_branch
  (jit_function_t func, jit_label_t* label) /*JIT_NOTHROW*/;
int jit_insn_branch_if
  (jit_function_t func, jit_value_t value, jit_label_t* label) /*JIT_NOTHROW*/;
int jit_insn_branch_if_not
  (jit_function_t func, jit_value_t value, jit_label_t* label) /*JIT_NOTHROW*/;
int jit_insn_jump_table
  (jit_function_t func, jit_value_t value,
   jit_label_t* labels, uint num_labels) /*JIT_NOTHROW*/;
jit_value_t jit_insn_address_of
  (jit_function_t func, jit_value_t value1) /*JIT_NOTHROW*/;
jit_value_t jit_insn_address_of_label
  (jit_function_t func, jit_label_t* label) /*JIT_NOTHROW*/;
jit_value_t jit_insn_convert
  (jit_function_t func, jit_value_t value,
   jit_type_t type, int overflow_check) /*JIT_NOTHROW*/;

jit_value_t jit_insn_call
  (jit_function_t func, const(char)* name,
   jit_function_t jit_func, jit_type_t signature,
   jit_value_t* args, uint num_args, int flags) /*JIT_NOTHROW*/;
jit_value_t jit_insn_call_indirect
  (jit_function_t func, jit_value_t value, jit_type_t signature,
   jit_value_t* args, uint num_args, int flags) /*JIT_NOTHROW*/;
jit_value_t jit_insn_call_indirect_vtable
  (jit_function_t func, jit_value_t value, jit_type_t signature,
   jit_value_t* args, uint num_args, int flags) /*JIT_NOTHROW*/;
jit_value_t jit_insn_call_native
  (jit_function_t func, const(char)* name,
   void* native_func, jit_type_t signature,
   jit_value_t* args, uint num_args, int flags) /*JIT_NOTHROW*/;
jit_value_t jit_insn_call_intrinsic
  (jit_function_t func, const(char)* name, void* intrinsic_func,
   const jit_intrinsic_descr_t* descriptor,
   jit_value_t arg1, jit_value_t arg2) /*JIT_NOTHROW*/;
int jit_insn_incoming_reg
  (jit_function_t func, jit_value_t value, int reg) /*JIT_NOTHROW*/;
int jit_insn_incoming_frame_posn
  (jit_function_t func, jit_value_t value, jit_nint frame_offset) /*JIT_NOTHROW*/;
int jit_insn_outgoing_reg
  (jit_function_t func, jit_value_t value, int reg) /*JIT_NOTHROW*/;
int jit_insn_outgoing_frame_posn
  (jit_function_t func, jit_value_t value, jit_nint frame_offset) /*JIT_NOTHROW*/;
int jit_insn_return_reg
  (jit_function_t func, jit_value_t value, int reg) /*JIT_NOTHROW*/;
int jit_insn_setup_for_nested
  (jit_function_t func, int nested_level, int reg) /*JIT_NOTHROW*/;
int jit_insn_flush_struct(jit_function_t func, jit_value_t value) /*JIT_NOTHROW*/;
jit_value_t jit_insn_import
  (jit_function_t func, jit_value_t value) /*JIT_NOTHROW*/;
int jit_insn_push(jit_function_t func, jit_value_t value) /*JIT_NOTHROW*/;
int jit_insn_push_ptr
  (jit_function_t func, jit_value_t value, jit_type_t type) /*JIT_NOTHROW*/;
int jit_insn_set_param
  (jit_function_t func, jit_value_t value, jit_nint offset) /*JIT_NOTHROW*/;
int jit_insn_set_param_ptr
  (jit_function_t func, jit_value_t value, jit_type_t type,
   jit_nint offset) /*JIT_NOTHROW*/;
int jit_insn_push_return_area_ptr(jit_function_t func) /*JIT_NOTHROW*/;
int jit_insn_pop_stack(jit_function_t func, jit_nint num_items) /*JIT_NOTHROW*/;
int jit_insn_defer_pop_stack
  (jit_function_t func, jit_nint num_items) /*JIT_NOTHROW*/;
int jit_insn_flush_defer_pop
  (jit_function_t func, jit_nint num_items) /*JIT_NOTHROW*/;
int jit_insn_return(jit_function_t func, jit_value_t value) /*JIT_NOTHROW*/;
int jit_insn_return_ptr
  (jit_function_t func, jit_value_t value, jit_type_t type) /*JIT_NOTHROW*/;
int jit_insn_default_return(jit_function_t func) /*JIT_NOTHROW*/;
int jit_insn_throw(jit_function_t func, jit_value_t value) /*JIT_NOTHROW*/;
jit_value_t jit_insn_get_call_stack(jit_function_t func) /*JIT_NOTHROW*/;

jit_value_t jit_insn_thrown_exception(jit_function_t func) /*JIT_NOTHROW*/;
int jit_insn_uses_catcher(jit_function_t func) /*JIT_NOTHROW*/;
jit_value_t jit_insn_start_catcher(jit_function_t func) /*JIT_NOTHROW*/;
int jit_insn_branch_if_pc_not_in_range
  (jit_function_t func, jit_label_t start_label,
   jit_label_t end_label, jit_label_t* label) /*JIT_NOTHROW*/;
int jit_insn_rethrow_unhandled(jit_function_t func) /*JIT_NOTHROW*/;
int jit_insn_start_finally
  (jit_function_t func, jit_label_t* finally_label) /*JIT_NOTHROW*/;
int jit_insn_return_from_finally(jit_function_t func) /*JIT_NOTHROW*/;
int jit_insn_call_finally
  (jit_function_t func, jit_label_t* finally_label) /*JIT_NOTHROW*/;
jit_value_t jit_insn_start_filter
  (jit_function_t func, jit_label_t* label, jit_type_t type) /*JIT_NOTHROW*/;
int jit_insn_return_from_filter
  (jit_function_t func, jit_value_t value) /*JIT_NOTHROW*/;
jit_value_t jit_insn_call_filter
  (jit_function_t func, jit_label_t* label,
   jit_value_t value, jit_type_t type) /*JIT_NOTHROW*/;

int jit_insn_memcpy
  (jit_function_t func, jit_value_t dest,
   jit_value_t src, jit_value_t size) /*JIT_NOTHROW*/;
int jit_insn_memmove
  (jit_function_t func, jit_value_t dest,
   jit_value_t src, jit_value_t size) /*JIT_NOTHROW*/;
int jit_insn_memset
  (jit_function_t func, jit_value_t dest,
   jit_value_t value, jit_value_t size) /*JIT_NOTHROW*/;
jit_value_t jit_insn_alloca
  (jit_function_t func, jit_value_t size) /*JIT_NOTHROW*/;

int jit_insn_move_blocks_to_end
  (jit_function_t func, jit_label_t from_label, jit_label_t to_label)
    /*JIT_NOTHROW*/;
int jit_insn_move_blocks_to_start
  (jit_function_t func, jit_label_t from_label, jit_label_t to_label)
    /*JIT_NOTHROW*/;

int jit_insn_mark_offset
  (jit_function_t func, jit_int offset) /*JIT_NOTHROW*/;
int jit_insn_mark_breakpoint
  (jit_function_t func, jit_nint data1, jit_nint data2) /*JIT_NOTHROW*/;
int jit_insn_mark_breakpoint_variable
  (jit_function_t func, jit_value_t data1, jit_value_t data2) /*JIT_NOTHROW*/;

void jit_insn_iter_init(jit_insn_iter_t* iter, jit_block_t block) /*JIT_NOTHROW*/;
void jit_insn_iter_init_last
  (jit_insn_iter_t* iter, jit_block_t block) /*JIT_NOTHROW*/;
jit_insn_t jit_insn_iter_next(jit_insn_iter_t* iter) /*JIT_NOTHROW*/;
jit_insn_t jit_insn_iter_previous(jit_insn_iter_t* iter) /*JIT_NOTHROW*/;


/*
 * Perform operations on signed 32-bit integers.
 */
jit_int jit_int_add(jit_int value1, jit_int value2) /*JIT_NOTHROW*/;
jit_int jit_int_sub(jit_int value1, jit_int value2) /*JIT_NOTHROW*/;
jit_int jit_int_mul(jit_int value1, jit_int value2) /*JIT_NOTHROW*/;
jit_int jit_int_div
  (jit_int* result, jit_int value1, jit_int value2) /*JIT_NOTHROW*/;
jit_int jit_int_rem
  (jit_int* result, jit_int value1, jit_int value2) /*JIT_NOTHROW*/;
jit_int jit_int_add_ovf
  (jit_int* result, jit_int value1, jit_int value2) /*JIT_NOTHROW*/;
jit_int jit_int_sub_ovf
  (jit_int* result, jit_int value1, jit_int value2) /*JIT_NOTHROW*/;
jit_int jit_int_mul_ovf
  (jit_int* result, jit_int value1, jit_int value2) /*JIT_NOTHROW*/;
jit_int jit_int_neg(jit_int value1) /*JIT_NOTHROW*/;
jit_int jit_int_and(jit_int value1, jit_int value2) /*JIT_NOTHROW*/;
jit_int jit_int_or(jit_int value1, jit_int value2) /*JIT_NOTHROW*/;
jit_int jit_int_xor(jit_int value1, jit_int value2) /*JIT_NOTHROW*/;
jit_int jit_int_not(jit_int value1) /*JIT_NOTHROW*/;
jit_int jit_int_shl(jit_int value1, jit_uint value2) /*JIT_NOTHROW*/;
jit_int jit_int_shr(jit_int value1, jit_uint value2) /*JIT_NOTHROW*/;
jit_int jit_int_eq(jit_int value1, jit_int value2) /*JIT_NOTHROW*/;
jit_int jit_int_ne(jit_int value1, jit_int value2) /*JIT_NOTHROW*/;
jit_int jit_int_lt(jit_int value1, jit_int value2) /*JIT_NOTHROW*/;
jit_int jit_int_le(jit_int value1, jit_int value2) /*JIT_NOTHROW*/;
jit_int jit_int_gt(jit_int value1, jit_int value2) /*JIT_NOTHROW*/;
jit_int jit_int_ge(jit_int value1, jit_int value2) /*JIT_NOTHROW*/;
jit_int jit_int_cmp(jit_int value1, jit_int value2) /*JIT_NOTHROW*/;
jit_int jit_int_abs(jit_int value1) /*JIT_NOTHROW*/;
jit_int jit_int_min(jit_int value1, jit_int value2) /*JIT_NOTHROW*/;
jit_int jit_int_max(jit_int value1, jit_int value2) /*JIT_NOTHROW*/;
jit_int jit_int_sign(jit_int value1) /*JIT_NOTHROW*/;

/*
 * Perform operations on unsigned 32-bit integers.
 */
jit_uint jit_uint_add(jit_uint value1, jit_uint value2) /*JIT_NOTHROW*/;
jit_uint jit_uint_sub(jit_uint value1, jit_uint value2) /*JIT_NOTHROW*/;
jit_uint jit_uint_mul(jit_uint value1, jit_uint value2) /*JIT_NOTHROW*/;
jit_int jit_uint_div
  (jit_uint* result, jit_uint value1, jit_uint value2) /*JIT_NOTHROW*/;
jit_int jit_uint_rem
  (jit_uint* result, jit_uint value1, jit_uint value2) /*JIT_NOTHROW*/;
jit_int jit_uint_add_ovf
  (jit_uint* result, jit_uint value1, jit_uint value2) /*JIT_NOTHROW*/;
jit_int jit_uint_sub_ovf
  (jit_uint* result, jit_uint value1, jit_uint value2) /*JIT_NOTHROW*/;
jit_int jit_uint_mul_ovf
  (jit_uint* result, jit_uint value1, jit_uint value2) /*JIT_NOTHROW*/;
jit_uint jit_uint_neg(jit_uint value1) /*JIT_NOTHROW*/;
jit_uint jit_uint_and(jit_uint value1, jit_uint value2) /*JIT_NOTHROW*/;
jit_uint jit_uint_or(jit_uint value1, jit_uint value2) /*JIT_NOTHROW*/;
jit_uint jit_uint_xor(jit_uint value1, jit_uint value2) /*JIT_NOTHROW*/;
jit_uint jit_uint_not(jit_uint value1) /*JIT_NOTHROW*/;
jit_uint jit_uint_shl(jit_uint value1, jit_uint value2) /*JIT_NOTHROW*/;
jit_uint jit_uint_shr(jit_uint value1, jit_uint value2) /*JIT_NOTHROW*/;
jit_int jit_uint_eq(jit_uint value1, jit_uint value2) /*JIT_NOTHROW*/;
jit_int jit_uint_ne(jit_uint value1, jit_uint value2) /*JIT_NOTHROW*/;
jit_int jit_uint_lt(jit_uint value1, jit_uint value2) /*JIT_NOTHROW*/;
jit_int jit_uint_le(jit_uint value1, jit_uint value2) /*JIT_NOTHROW*/;
jit_int jit_uint_gt(jit_uint value1, jit_uint value2) /*JIT_NOTHROW*/;
jit_int jit_uint_ge(jit_uint value1, jit_uint value2) /*JIT_NOTHROW*/;
jit_int jit_uint_cmp(jit_uint value1, jit_uint value2) /*JIT_NOTHROW*/;
jit_uint jit_uint_min(jit_uint value1, jit_uint value2) /*JIT_NOTHROW*/;
jit_uint jit_uint_max(jit_uint value1, jit_uint value2) /*JIT_NOTHROW*/;

/*
 * Perform operations on signed 64-bit integers.
 */
jit_long jit_long_add(jit_long value1, jit_long value2) /*JIT_NOTHROW*/;
jit_long jit_long_sub(jit_long value1, jit_long value2) /*JIT_NOTHROW*/;
jit_long jit_long_mul(jit_long value1, jit_long value2) /*JIT_NOTHROW*/;
jit_int jit_long_div
  (jit_long* result, jit_long value1, jit_long value2) /*JIT_NOTHROW*/;
jit_int jit_long_rem
  (jit_long* result, jit_long value1, jit_long value2) /*JIT_NOTHROW*/;
jit_int jit_long_add_ovf
  (jit_long* result, jit_long value1, jit_long value2) /*JIT_NOTHROW*/;
jit_int jit_long_sub_ovf
  (jit_long* result, jit_long value1, jit_long value2) /*JIT_NOTHROW*/;
jit_int jit_long_mul_ovf
  (jit_long* result, jit_long value1, jit_long value2) /*JIT_NOTHROW*/;
jit_long jit_long_neg(jit_long value1) /*JIT_NOTHROW*/;
jit_long jit_long_and(jit_long value1, jit_long value2) /*JIT_NOTHROW*/;
jit_long jit_long_or(jit_long value1, jit_long value2) /*JIT_NOTHROW*/;
jit_long jit_long_xor(jit_long value1, jit_long value2) /*JIT_NOTHROW*/;
jit_long jit_long_not(jit_long value1) /*JIT_NOTHROW*/;
jit_long jit_long_shl(jit_long value1, jit_uint value2) /*JIT_NOTHROW*/;
jit_long jit_long_shr(jit_long value1, jit_uint value2) /*JIT_NOTHROW*/;
jit_int jit_long_eq(jit_long value1, jit_long value2) /*JIT_NOTHROW*/;
jit_int jit_long_ne(jit_long value1, jit_long value2) /*JIT_NOTHROW*/;
jit_int jit_long_lt(jit_long value1, jit_long value2) /*JIT_NOTHROW*/;
jit_int jit_long_le(jit_long value1, jit_long value2) /*JIT_NOTHROW*/;
jit_int jit_long_gt(jit_long value1, jit_long value2) /*JIT_NOTHROW*/;
jit_int jit_long_ge(jit_long value1, jit_long value2) /*JIT_NOTHROW*/;
jit_int jit_long_cmp(jit_long value1, jit_long value2) /*JIT_NOTHROW*/;
jit_long jit_long_abs(jit_long value1) /*JIT_NOTHROW*/;
jit_long jit_long_min(jit_long value1, jit_long value2) /*JIT_NOTHROW*/;
jit_long jit_long_max(jit_long value1, jit_long value2) /*JIT_NOTHROW*/;
jit_int jit_long_sign(jit_long value1) /*JIT_NOTHROW*/;

/*
 * Perform operations on unsigned 64-bit integers.
 */
jit_ulong jit_ulong_add(jit_ulong value1, jit_ulong value2) /*JIT_NOTHROW*/;
jit_ulong jit_ulong_sub(jit_ulong value1, jit_ulong value2) /*JIT_NOTHROW*/;
jit_ulong jit_ulong_mul(jit_ulong value1, jit_ulong value2) /*JIT_NOTHROW*/;
jit_int jit_ulong_div
  (jit_ulong* result, jit_ulong value1, jit_ulong value2) /*JIT_NOTHROW*/;
jit_int jit_ulong_rem
  (jit_ulong* result, jit_ulong value1, jit_ulong value2) /*JIT_NOTHROW*/;
jit_int jit_ulong_add_ovf
  (jit_ulong* result, jit_ulong value1, jit_ulong value2) /*JIT_NOTHROW*/;
jit_int jit_ulong_sub_ovf
  (jit_ulong* result, jit_ulong value1, jit_ulong value2) /*JIT_NOTHROW*/;
jit_int jit_ulong_mul_ovf
  (jit_ulong* result, jit_ulong value1, jit_ulong value2) /*JIT_NOTHROW*/;
jit_ulong jit_ulong_neg(jit_ulong value1) /*JIT_NOTHROW*/;
jit_ulong jit_ulong_and(jit_ulong value1, jit_ulong value2) /*JIT_NOTHROW*/;
jit_ulong jit_ulong_or(jit_ulong value1, jit_ulong value2) /*JIT_NOTHROW*/;
jit_ulong jit_ulong_xor(jit_ulong value1, jit_ulong value2) /*JIT_NOTHROW*/;
jit_ulong jit_ulong_not(jit_ulong value1) /*JIT_NOTHROW*/;
jit_ulong jit_ulong_shl(jit_ulong value1, jit_uint value2) /*JIT_NOTHROW*/;
jit_ulong jit_ulong_shr(jit_ulong value1, jit_uint value2) /*JIT_NOTHROW*/;
jit_int jit_ulong_eq(jit_ulong value1, jit_ulong value2) /*JIT_NOTHROW*/;
jit_int jit_ulong_ne(jit_ulong value1, jit_ulong value2) /*JIT_NOTHROW*/;
jit_int jit_ulong_lt(jit_ulong value1, jit_ulong value2) /*JIT_NOTHROW*/;
jit_int jit_ulong_le(jit_ulong value1, jit_ulong value2) /*JIT_NOTHROW*/;
jit_int jit_ulong_gt(jit_ulong value1, jit_ulong value2) /*JIT_NOTHROW*/;
jit_int jit_ulong_ge(jit_ulong value1, jit_ulong value2) /*JIT_NOTHROW*/;
jit_int jit_ulong_cmp(jit_ulong value1, jit_ulong value2) /*JIT_NOTHROW*/;
jit_ulong jit_ulong_min(jit_ulong value1, jit_ulong value2) /*JIT_NOTHROW*/;
jit_ulong jit_ulong_max(jit_ulong value1, jit_ulong value2) /*JIT_NOTHROW*/;

/*
 * Perform operations on 32-bit floating-point values.
 */
jit_float32 jit_float32_add
  (jit_float32 value1, jit_float32 value2) /*JIT_NOTHROW*/;
jit_float32 jit_float32_sub
  (jit_float32 value1, jit_float32 value2) /*JIT_NOTHROW*/;
jit_float32 jit_float32_mul
  (jit_float32 value1, jit_float32 value2) /*JIT_NOTHROW*/;
jit_float32 jit_float32_div
  (jit_float32 value1, jit_float32 value2) /*JIT_NOTHROW*/;
jit_float32 jit_float32_rem
  (jit_float32 value1, jit_float32 value2) /*JIT_NOTHROW*/;
jit_float32 jit_float32_ieee_rem
  (jit_float32 value1, jit_float32 value2) /*JIT_NOTHROW*/;
jit_float32 jit_float32_neg(jit_float32 value1) /*JIT_NOTHROW*/;
jit_int jit_float32_eq(jit_float32 value1, jit_float32 value2) /*JIT_NOTHROW*/;
jit_int jit_float32_ne(jit_float32 value1, jit_float32 value2) /*JIT_NOTHROW*/;
jit_int jit_float32_lt(jit_float32 value1, jit_float32 value2) /*JIT_NOTHROW*/;
jit_int jit_float32_le(jit_float32 value1, jit_float32 value2) /*JIT_NOTHROW*/;
jit_int jit_float32_gt(jit_float32 value1, jit_float32 value2) /*JIT_NOTHROW*/;
jit_int jit_float32_ge(jit_float32 value1, jit_float32 value2) /*JIT_NOTHROW*/;
jit_int jit_float32_cmpl(jit_float32 value1, jit_float32 value2) /*JIT_NOTHROW*/;
jit_int jit_float32_cmpg(jit_float32 value1, jit_float32 value2) /*JIT_NOTHROW*/;
jit_float32 jit_float32_acos(jit_float32 value1) /*JIT_NOTHROW*/;
jit_float32 jit_float32_asin(jit_float32 value1) /*JIT_NOTHROW*/;
jit_float32 jit_float32_atan(jit_float32 value1) /*JIT_NOTHROW*/;
jit_float32 jit_float32_atan2
  (jit_float32 value1, jit_float32 value2) /*JIT_NOTHROW*/;
jit_float32 jit_float32_ceil(jit_float32 value1) /*JIT_NOTHROW*/;
jit_float32 jit_float32_cos(jit_float32 value1) /*JIT_NOTHROW*/;
jit_float32 jit_float32_cosh(jit_float32 value1) /*JIT_NOTHROW*/;
jit_float32 jit_float32_exp(jit_float32 value1) /*JIT_NOTHROW*/;
jit_float32 jit_float32_floor(jit_float32 value1) /*JIT_NOTHROW*/;
jit_float32 jit_float32_log(jit_float32 value1) /*JIT_NOTHROW*/;
jit_float32 jit_float32_log10(jit_float32 value1) /*JIT_NOTHROW*/;
jit_float32 jit_float32_pow
  (jit_float32 value1, jit_float32 value2) /*JIT_NOTHROW*/;
jit_float32 jit_float32_rint(jit_float32 value1) /*JIT_NOTHROW*/;
jit_float32 jit_float32_round(jit_float32 value1) /*JIT_NOTHROW*/;
jit_float32 jit_float32_sin(jit_float32 value1) /*JIT_NOTHROW*/;
jit_float32 jit_float32_sinh(jit_float32 value1) /*JIT_NOTHROW*/;
jit_float32 jit_float32_sqrt(jit_float32 value1) /*JIT_NOTHROW*/;
jit_float32 jit_float32_tan(jit_float32 value1) /*JIT_NOTHROW*/;
jit_float32 jit_float32_tanh(jit_float32 value1) /*JIT_NOTHROW*/;
jit_float32 jit_float32_trunc(jit_float32 value1) /*JIT_NOTHROW*/;
jit_int jit_float32_is_finite(jit_float32 value) /*JIT_NOTHROW*/;
jit_int jit_float32_is_nan(jit_float32 value) /*JIT_NOTHROW*/;
jit_int jit_float32_is_inf(jit_float32 value) /*JIT_NOTHROW*/;
jit_float32 jit_float32_abs(jit_float32 value1) /*JIT_NOTHROW*/;
jit_float32 jit_float32_min
  (jit_float32 value1, jit_float32 value2) /*JIT_NOTHROW*/;
jit_float32 jit_float32_max
  (jit_float32 value1, jit_float32 value2) /*JIT_NOTHROW*/;
jit_int jit_float32_sign(jit_float32 value1) /*JIT_NOTHROW*/;

/*
 * Perform operations on 64-bit floating-point values.
 */
jit_float64 jit_float64_add
  (jit_float64 value1, jit_float64 value2) /*JIT_NOTHROW*/;
jit_float64 jit_float64_sub
  (jit_float64 value1, jit_float64 value2) /*JIT_NOTHROW*/;
jit_float64 jit_float64_mul
  (jit_float64 value1, jit_float64 value2) /*JIT_NOTHROW*/;
jit_float64 jit_float64_div
  (jit_float64 value1, jit_float64 value2) /*JIT_NOTHROW*/;
jit_float64 jit_float64_rem
  (jit_float64 value1, jit_float64 value2) /*JIT_NOTHROW*/;
jit_float64 jit_float64_ieee_rem
  (jit_float64 value1, jit_float64 value2) /*JIT_NOTHROW*/;
jit_float64 jit_float64_neg(jit_float64 value1) /*JIT_NOTHROW*/;
jit_int jit_float64_eq(jit_float64 value1, jit_float64 value2) /*JIT_NOTHROW*/;
jit_int jit_float64_ne(jit_float64 value1, jit_float64 value2) /*JIT_NOTHROW*/;
jit_int jit_float64_lt(jit_float64 value1, jit_float64 value2) /*JIT_NOTHROW*/;
jit_int jit_float64_le(jit_float64 value1, jit_float64 value2) /*JIT_NOTHROW*/;
jit_int jit_float64_gt(jit_float64 value1, jit_float64 value2) /*JIT_NOTHROW*/;
jit_int jit_float64_ge(jit_float64 value1, jit_float64 value2) /*JIT_NOTHROW*/;
jit_int jit_float64_cmpl(jit_float64 value1, jit_float64 value2) /*JIT_NOTHROW*/;
jit_int jit_float64_cmpg(jit_float64 value1, jit_float64 value2) /*JIT_NOTHROW*/;
jit_float64 jit_float64_acos(jit_float64 value1) /*JIT_NOTHROW*/;
jit_float64 jit_float64_asin(jit_float64 value1) /*JIT_NOTHROW*/;
jit_float64 jit_float64_atan(jit_float64 value1) /*JIT_NOTHROW*/;
jit_float64 jit_float64_atan2
  (jit_float64 value1, jit_float64 value2) /*JIT_NOTHROW*/;
jit_float64 jit_float64_ceil(jit_float64 value1) /*JIT_NOTHROW*/;
jit_float64 jit_float64_cos(jit_float64 value1) /*JIT_NOTHROW*/;
jit_float64 jit_float64_cosh(jit_float64 value1) /*JIT_NOTHROW*/;
jit_float64 jit_float64_exp(jit_float64 value1) /*JIT_NOTHROW*/;
jit_float64 jit_float64_floor(jit_float64 value1) /*JIT_NOTHROW*/;
jit_float64 jit_float64_log(jit_float64 value1) /*JIT_NOTHROW*/;
jit_float64 jit_float64_log10(jit_float64 value1) /*JIT_NOTHROW*/;
jit_float64 jit_float64_pow
  (jit_float64 value1, jit_float64 value2) /*JIT_NOTHROW*/;
jit_float64 jit_float64_rint(jit_float64 value1) /*JIT_NOTHROW*/;
jit_float64 jit_float64_round(jit_float64 value1) /*JIT_NOTHROW*/;
jit_float64 jit_float64_sin(jit_float64 value1) /*JIT_NOTHROW*/;
jit_float64 jit_float64_sinh(jit_float64 value1) /*JIT_NOTHROW*/;
jit_float64 jit_float64_sqrt(jit_float64 value1) /*JIT_NOTHROW*/;
jit_float64 jit_float64_tan(jit_float64 value1) /*JIT_NOTHROW*/;
jit_float64 jit_float64_tanh(jit_float64 value1) /*JIT_NOTHROW*/;
jit_float64 jit_float64_trunc(jit_float64 value1) /*JIT_NOTHROW*/;
jit_int jit_float64_is_finite(jit_float64 value) /*JIT_NOTHROW*/;
jit_int jit_float64_is_nan(jit_float64 value) /*JIT_NOTHROW*/;
jit_int jit_float64_is_inf(jit_float64 value) /*JIT_NOTHROW*/;
jit_float64 jit_float64_abs(jit_float64 value1) /*JIT_NOTHROW*/;
jit_float64 jit_float64_min
  (jit_float64 value1, jit_float64 value2) /*JIT_NOTHROW*/;
jit_float64 jit_float64_max
  (jit_float64 value1, jit_float64 value2) /*JIT_NOTHROW*/;
jit_int jit_float64_sign(jit_float64 value1) /*JIT_NOTHROW*/;

/*
 * Perform operations on native floating-point values.
 */
jit_nfloat jit_nfloat_add(jit_nfloat value1, jit_nfloat value2) /*JIT_NOTHROW*/;
jit_nfloat jit_nfloat_sub(jit_nfloat value1, jit_nfloat value2) /*JIT_NOTHROW*/;
jit_nfloat jit_nfloat_mul(jit_nfloat value1, jit_nfloat value2) /*JIT_NOTHROW*/;
jit_nfloat jit_nfloat_div(jit_nfloat value1, jit_nfloat value2) /*JIT_NOTHROW*/;
jit_nfloat jit_nfloat_rem(jit_nfloat value1, jit_nfloat value2) /*JIT_NOTHROW*/;
jit_nfloat jit_nfloat_ieee_rem
  (jit_nfloat value1, jit_nfloat value2) /*JIT_NOTHROW*/;
jit_nfloat jit_nfloat_neg(jit_nfloat value1) /*JIT_NOTHROW*/;
jit_int jit_nfloat_eq(jit_nfloat value1, jit_nfloat value2) /*JIT_NOTHROW*/;
jit_int jit_nfloat_ne(jit_nfloat value1, jit_nfloat value2) /*JIT_NOTHROW*/;
jit_int jit_nfloat_lt(jit_nfloat value1, jit_nfloat value2) /*JIT_NOTHROW*/;
jit_int jit_nfloat_le(jit_nfloat value1, jit_nfloat value2) /*JIT_NOTHROW*/;
jit_int jit_nfloat_gt(jit_nfloat value1, jit_nfloat value2) /*JIT_NOTHROW*/;
jit_int jit_nfloat_ge(jit_nfloat value1, jit_nfloat value2) /*JIT_NOTHROW*/;
jit_int jit_nfloat_cmpl(jit_nfloat value1, jit_nfloat value2) /*JIT_NOTHROW*/;
jit_int jit_nfloat_cmpg(jit_nfloat value1, jit_nfloat value2) /*JIT_NOTHROW*/;
jit_nfloat jit_nfloat_acos(jit_nfloat value1) /*JIT_NOTHROW*/;
jit_nfloat jit_nfloat_asin(jit_nfloat value1) /*JIT_NOTHROW*/;
jit_nfloat jit_nfloat_atan(jit_nfloat value1) /*JIT_NOTHROW*/;
jit_nfloat jit_nfloat_atan2(jit_nfloat value1, jit_nfloat value2) /*JIT_NOTHROW*/;
jit_nfloat jit_nfloat_ceil(jit_nfloat value1) /*JIT_NOTHROW*/;
jit_nfloat jit_nfloat_cos(jit_nfloat value1) /*JIT_NOTHROW*/;
jit_nfloat jit_nfloat_cosh(jit_nfloat value1) /*JIT_NOTHROW*/;
jit_nfloat jit_nfloat_exp(jit_nfloat value1) /*JIT_NOTHROW*/;
jit_nfloat jit_nfloat_floor(jit_nfloat value1) /*JIT_NOTHROW*/;
jit_nfloat jit_nfloat_log(jit_nfloat value1) /*JIT_NOTHROW*/;
jit_nfloat jit_nfloat_log10(jit_nfloat value1) /*JIT_NOTHROW*/;
jit_nfloat jit_nfloat_pow(jit_nfloat value1, jit_nfloat value2) /*JIT_NOTHROW*/;
jit_nfloat jit_nfloat_rint(jit_nfloat value1) /*JIT_NOTHROW*/;
jit_nfloat jit_nfloat_round(jit_nfloat value1) /*JIT_NOTHROW*/;
jit_nfloat jit_nfloat_sin(jit_nfloat value1) /*JIT_NOTHROW*/;
jit_nfloat jit_nfloat_sinh(jit_nfloat value1) /*JIT_NOTHROW*/;
jit_nfloat jit_nfloat_sqrt(jit_nfloat value1) /*JIT_NOTHROW*/;
jit_nfloat jit_nfloat_tan(jit_nfloat value1) /*JIT_NOTHROW*/;
jit_nfloat jit_nfloat_tanh(jit_nfloat value1) /*JIT_NOTHROW*/;
jit_nfloat jit_nfloat_trunc(jit_nfloat value1) /*JIT_NOTHROW*/;
jit_int jit_nfloat_is_finite(jit_nfloat value) /*JIT_NOTHROW*/;
jit_int jit_nfloat_is_nan(jit_nfloat value) /*JIT_NOTHROW*/;
jit_int jit_nfloat_is_inf(jit_nfloat value) /*JIT_NOTHROW*/;
jit_nfloat jit_nfloat_abs(jit_nfloat value1) /*JIT_NOTHROW*/;
jit_nfloat jit_nfloat_min(jit_nfloat value1, jit_nfloat value2) /*JIT_NOTHROW*/;
jit_nfloat jit_nfloat_max(jit_nfloat value1, jit_nfloat value2) /*JIT_NOTHROW*/;
jit_int jit_nfloat_sign(jit_nfloat value1) /*JIT_NOTHROW*/;

/*
 * Convert between integer types.
 */
jit_int jit_int_to_sbyte(jit_int value) /*JIT_NOTHROW*/;
jit_int jit_int_to_ubyte(jit_int value) /*JIT_NOTHROW*/;
jit_int jit_int_to_short(jit_int value) /*JIT_NOTHROW*/;
jit_int jit_int_to_ushort(jit_int value) /*JIT_NOTHROW*/;
jit_int jit_int_to_int(jit_int value) /*JIT_NOTHROW*/;
jit_uint jit_int_to_uint(jit_int value) /*JIT_NOTHROW*/;
jit_long jit_int_to_long(jit_int value) /*JIT_NOTHROW*/;
jit_ulong jit_int_to_ulong(jit_int value) /*JIT_NOTHROW*/;
jit_int jit_uint_to_int(jit_uint value) /*JIT_NOTHROW*/;
jit_uint jit_uint_to_uint(jit_uint value) /*JIT_NOTHROW*/;
jit_long jit_uint_to_long(jit_uint value) /*JIT_NOTHROW*/;
jit_ulong jit_uint_to_ulong(jit_uint value) /*JIT_NOTHROW*/;
jit_int jit_long_to_int(jit_long value) /*JIT_NOTHROW*/;
jit_uint jit_long_to_uint(jit_long value) /*JIT_NOTHROW*/;
jit_long jit_long_to_long(jit_long value) /*JIT_NOTHROW*/;
jit_ulong jit_long_to_ulong(jit_long value) /*JIT_NOTHROW*/;
jit_int jit_ulong_to_int(jit_ulong value) /*JIT_NOTHROW*/;
jit_uint jit_ulong_to_uint(jit_ulong value) /*JIT_NOTHROW*/;
jit_long jit_ulong_to_long(jit_ulong value) /*JIT_NOTHROW*/;
jit_ulong jit_ulong_to_ulong(jit_ulong value) /*JIT_NOTHROW*/;

/*
 * Convert between integer types with overflow detection.
 */
jit_int jit_int_to_sbyte_ovf(jit_int* result, jit_int value) /*JIT_NOTHROW*/;
jit_int jit_int_to_ubyte_ovf(jit_int* result, jit_int value) /*JIT_NOTHROW*/;
jit_int jit_int_to_short_ovf(jit_int* result, jit_int value) /*JIT_NOTHROW*/;
jit_int jit_int_to_ushort_ovf(jit_int* result, jit_int value) /*JIT_NOTHROW*/;
jit_int jit_int_to_int_ovf(jit_int* result, jit_int value) /*JIT_NOTHROW*/;
jit_int jit_int_to_uint_ovf(jit_uint* result, jit_int value) /*JIT_NOTHROW*/;
jit_int jit_int_to_long_ovf(jit_long* result, jit_int value) /*JIT_NOTHROW*/;
jit_int jit_int_to_ulong_ovf(jit_ulong* result, jit_int value) /*JIT_NOTHROW*/;
jit_int jit_uint_to_int_ovf(jit_int* result, jit_uint value) /*JIT_NOTHROW*/;
jit_int jit_uint_to_uint_ovf(jit_uint* result, jit_uint value) /*JIT_NOTHROW*/;
jit_int jit_uint_to_long_ovf(jit_long* result, jit_uint value) /*JIT_NOTHROW*/;
jit_int jit_uint_to_ulong_ovf(jit_ulong* result, jit_uint value) /*JIT_NOTHROW*/;
jit_int jit_long_to_int_ovf(jit_int* result, jit_long value) /*JIT_NOTHROW*/;
jit_int jit_long_to_uint_ovf(jit_uint* result, jit_long value) /*JIT_NOTHROW*/;
jit_int jit_long_to_long_ovf(jit_long* result, jit_long value) /*JIT_NOTHROW*/;
jit_int jit_long_to_ulong_ovf(jit_ulong* result, jit_long value) /*JIT_NOTHROW*/;
jit_int jit_ulong_to_int_ovf(jit_int* result, jit_ulong value) /*JIT_NOTHROW*/;
jit_int jit_ulong_to_uint_ovf(jit_uint* result, jit_ulong value) /*JIT_NOTHROW*/;
jit_int jit_ulong_to_long_ovf(jit_long* result, jit_ulong value) /*JIT_NOTHROW*/;
jit_int jit_ulong_to_ulong_ovf(jit_ulong* result, jit_ulong value) /*JIT_NOTHROW*/;

/*
 * Convert a 32-bit floating-point value into various integer types.
 */
jit_int jit_float32_to_int(jit_float32 value) /*JIT_NOTHROW*/;
jit_uint jit_float32_to_uint(jit_float32 value) /*JIT_NOTHROW*/;
jit_long jit_float32_to_long(jit_float32 value) /*JIT_NOTHROW*/;
jit_ulong jit_float32_to_ulong(jit_float32 value) /*JIT_NOTHROW*/;

/*
 * Convert a 32-bit floating-point value into various integer types,
 * with overflow detection.
 */
jit_int jit_float32_to_int_ovf(jit_int* result, jit_float32 value) /*JIT_NOTHROW*/;
jit_int jit_float32_to_uint_ovf(jit_uint* result, jit_float32 value) /*JIT_NOTHROW*/;
jit_int jit_float32_to_long_ovf(jit_long* result, jit_float32 value) /*JIT_NOTHROW*/;
jit_int jit_float32_to_ulong_ovf
  (jit_ulong* result, jit_float32 value) /*JIT_NOTHROW*/;

/*
 * Convert a 64-bit floating-point value into various integer types.
 */
jit_int jit_float64_to_int(jit_float64 value) /*JIT_NOTHROW*/;
jit_uint jit_float64_to_uint(jit_float64 value) /*JIT_NOTHROW*/;
jit_long jit_float64_to_long(jit_float64 value) /*JIT_NOTHROW*/;
jit_ulong jit_float64_to_ulong(jit_float64 value) /*JIT_NOTHROW*/;

/*
 * Convert a 64-bit floating-point value into various integer types,
 * with overflow detection.
 */
jit_int jit_float64_to_int_ovf(jit_int* result, jit_float64 value) /*JIT_NOTHROW*/;
jit_int jit_float64_to_uint_ovf(jit_uint* result, jit_float64 value) /*JIT_NOTHROW*/;
jit_int jit_float64_to_long_ovf(jit_long* result, jit_float64 value) /*JIT_NOTHROW*/;
jit_int jit_float64_to_ulong_ovf
  (jit_ulong* result, jit_float64 value) /*JIT_NOTHROW*/;

/*
 * Convert a native floating-point value into various integer types.
 */
jit_int jit_nfloat_to_int(jit_nfloat value) /*JIT_NOTHROW*/;
jit_uint jit_nfloat_to_uint(jit_nfloat value) /*JIT_NOTHROW*/;
jit_long jit_nfloat_to_long(jit_nfloat value) /*JIT_NOTHROW*/;
jit_ulong jit_nfloat_to_ulong(jit_nfloat value) /*JIT_NOTHROW*/;

/*
 * Convert a native floating-point value into various integer types,
 * with overflow detection.
 */
jit_int jit_nfloat_to_int_ovf(jit_int* result, jit_nfloat value) /*JIT_NOTHROW*/;
jit_int jit_nfloat_to_uint_ovf(jit_uint* result, jit_nfloat value) /*JIT_NOTHROW*/;
jit_int jit_nfloat_to_long_ovf(jit_long* result, jit_nfloat value) /*JIT_NOTHROW*/;
jit_int jit_nfloat_to_ulong_ovf
  (jit_ulong* result, jit_nfloat value) /*JIT_NOTHROW*/;

/*
 * Convert integer types into floating-point values.
 */
jit_float32 jit_int_to_float32(jit_int value) /*JIT_NOTHROW*/;
jit_float64 jit_int_to_float64(jit_int value) /*JIT_NOTHROW*/;
jit_nfloat jit_int_to_nfloat(jit_int value) /*JIT_NOTHROW*/;
jit_float32 jit_uint_to_float32(jit_uint value) /*JIT_NOTHROW*/;
jit_float64 jit_uint_to_float64(jit_uint value) /*JIT_NOTHROW*/;
jit_nfloat jit_uint_to_nfloat(jit_uint value) /*JIT_NOTHROW*/;
jit_float32 jit_long_to_float32(jit_long value) /*JIT_NOTHROW*/;
jit_float64 jit_long_to_float64(jit_long value) /*JIT_NOTHROW*/;
jit_nfloat jit_long_to_nfloat(jit_long value) /*JIT_NOTHROW*/;
jit_float32 jit_ulong_to_float32(jit_ulong value) /*JIT_NOTHROW*/;
jit_float64 jit_ulong_to_float64(jit_ulong value) /*JIT_NOTHROW*/;
jit_nfloat jit_ulong_to_nfloat(jit_ulong value) /*JIT_NOTHROW*/;

/*
 * Convert between floating-point types.
 */
jit_float64 jit_float32_to_float64(jit_float32 value) /*JIT_NOTHROW*/;
jit_nfloat jit_float32_to_nfloat(jit_float32 value) /*JIT_NOTHROW*/;
jit_float32 jit_float64_to_float32(jit_float64 value) /*JIT_NOTHROW*/;
jit_nfloat jit_float64_to_nfloat(jit_float64 value) /*JIT_NOTHROW*/;
jit_float32 jit_nfloat_to_float32(jit_nfloat value) /*JIT_NOTHROW*/;
jit_float64 jit_nfloat_to_float64(jit_nfloat value) /*JIT_NOTHROW*/;


struct _jit_meta {}
alias jit_meta_t = _jit_meta*;

int jit_meta_set
  (jit_meta_t* list, int type, void* data,
   jit_meta_free_func free_data, jit_function_t pool_owner) /*JIT_NOTHROW*/;
void* jit_meta_get(jit_meta_t list, int type) /*JIT_NOTHROW*/;
void jit_meta_free(jit_meta_t* list, int type) /*JIT_NOTHROW*/;
void jit_meta_destroy(jit_meta_t* list) /*JIT_NOTHROW*/;


/*
 * Opaque types that describe object model elements.
 */
struct jit_objmodel {}
alias jit_objmodel_t = jit_objmodel*;
struct jitom_class {}
alias jitom_class_t = jitom_class*;
struct jitom_field {}
alias jitom_field_t = jitom_field*;
struct jitom_method {}
alias jitom_method_t = jitom_method*;

/*
 * Modifier flags that describe an item's properties.
 */
enum JITOM_MODIFIER_ACCESS_MASK = 0x0007;
enum JITOM_MODIFIER_PUBLIC = 0x0000;
enum JITOM_MODIFIER_PRIVATE = 0x0001;
enum JITOM_MODIFIER_PROTECTED = 0x0002;
enum JITOM_MODIFIER_PACKAGE = 0x0003;
enum JITOM_MODIFIER_PACKAGE_OR_PROTECTED = 0x0004;
enum JITOM_MODIFIER_PACKAGE_AND_PROTECTED = 0x0005;
enum JITOM_MODIFIER_OTHER1 = 0x0006;
enum JITOM_MODIFIER_OTHER2 = 0x0007;
enum JITOM_MODIFIER_STATIC = 0x0008;
enum JITOM_MODIFIER_VIRTUAL = 0x0010;
enum JITOM_MODIFIER_NEW_SLOT = 0x0020;
enum JITOM_MODIFIER_ABSTRACT = 0x0040;
enum JITOM_MODIFIER_LITERAL = 0x0080;
enum JITOM_MODIFIER_CTOR = 0x0100;
enum JITOM_MODIFIER_STATIC_CTOR = 0x0200;
enum JITOM_MODIFIER_DTOR = 0x0400;
enum JITOM_MODIFIER_INTERFACE = 0x0800;
enum JITOM_MODIFIER_VALUE = 0x1000;
enum JITOM_MODIFIER_FINAL = 0x2000;
enum JITOM_MODIFIER_DELETE = 0x4000;
enum JITOM_MODIFIER_REFERENCE_COUNTED = 0x8000;

/*
 * Type tags that are used to mark instances of object model classes.
 */
enum JITOM_TYPETAG_CLASS = 11000; /* Object reference */
enum JITOM_TYPETAG_VALUE = 11001; /* Inline stack value */

/*
 * Operations on object models.
 */
void jitom_destroy_model(jit_objmodel_t model) /*JIT_NOTHROW*/;
jitom_class_t jitom_get_class_by_name
  (jit_objmodel_t model, const(char)* name) /*JIT_NOTHROW*/;

/*
 * Operations on object model classes.
 */
char* jitom_class_get_name
  (jit_objmodel_t model, jitom_class_t klass) /*JIT_NOTHROW*/;
int jitom_class_get_modifiers
  (jit_objmodel_t model, jitom_class_t klass) /*JIT_NOTHROW*/;
jit_type_t jitom_class_get_type
  (jit_objmodel_t model, jitom_class_t klass) /*JIT_NOTHROW*/;
jit_type_t jitom_class_get_value_type
  (jit_objmodel_t model, jitom_class_t klass) /*JIT_NOTHROW*/;
jitom_class_t jitom_class_get_primary_super
  (jit_objmodel_t model, jitom_class_t klass) /*JIT_NOTHROW*/;
jitom_class_t* jitom_class_get_all_supers
  (jit_objmodel_t model, jitom_class_t klass, uint* num) /*JIT_NOTHROW*/;
jitom_class_t* jitom_class_get_interfaces
  (jit_objmodel_t model, jitom_class_t klass, uint* num) /*JIT_NOTHROW*/;
jitom_field_t* jitom_class_get_fields
  (jit_objmodel_t model, jitom_class_t klass, uint* num) /*JIT_NOTHROW*/;
jitom_method_t* jitom_class_get_methods
  (jit_objmodel_t model, jitom_class_t klass, uint* num) /*JIT_NOTHROW*/;
jit_value_t jitom_class_new
  (jit_objmodel_t model, jitom_class_t klass,
   jitom_method_t ctor, jit_function_t func,
   jit_value_t* args, uint num_args, int flags) /*JIT_NOTHROW*/;
jit_value_t jitom_class_new_value
  (jit_objmodel_t model, jitom_class_t klass,
   jitom_method_t ctor, jit_function_t func,
   jit_value_t* args, uint num_args, int flags) /*JIT_NOTHROW*/;
int jitom_class_delete
  (jit_objmodel_t model, jitom_class_t klass,
   jit_value_t obj_value) /*JIT_NOTHROW*/;
int jitom_class_add_ref
  (jit_objmodel_t model, jitom_class_t klass,
   jit_value_t obj_value) /*JIT_NOTHROW*/;

/*
 * Operations on object model fields.
 */
char* jitom_field_get_name
  (jit_objmodel_t model, jitom_class_t klass,
   jitom_field_t field) /*JIT_NOTHROW*/;
jit_type_t jitom_field_get_type
  (jit_objmodel_t model, jitom_class_t klass,
   jitom_field_t field) /*JIT_NOTHROW*/;
int jitom_field_get_modifiers
  (jit_objmodel_t model, jitom_class_t klass,
   jitom_field_t field) /*JIT_NOTHROW*/;
jit_value_t jitom_field_load
  (jit_objmodel_t model, jitom_class_t klass, jitom_field_t field,
   jit_function_t func, jit_value_t obj_value) /*JIT_NOTHROW*/;
jit_value_t jitom_field_load_address
  (jit_objmodel_t model, jitom_class_t klass, jitom_field_t field,
   jit_function_t func, jit_value_t obj_value) /*JIT_NOTHROW*/;
int jitom_field_store
  (jit_objmodel_t model, jitom_class_t klass, jitom_field_t field,
   jit_function_t func, jit_value_t obj_value, jit_value_t value) /*JIT_NOTHROW*/;

/*
 * Operations on object model methods.
 */
char* jitom_method_get_name
  (jit_objmodel_t model, jitom_class_t klass,
   jitom_method_t method) /*JIT_NOTHROW*/;
jit_type_t jitom_method_get_type
  (jit_objmodel_t model, jitom_class_t klass,
   jitom_method_t method) /*JIT_NOTHROW*/;
int jitom_method_get_modifiers
  (jit_objmodel_t model, jitom_class_t klass,
   jitom_method_t method) /*JIT_NOTHROW*/;
jit_value_t jitom_method_invoke
  (jit_objmodel_t model, jitom_class_t klass, jitom_method_t method,
   jit_function_t func, jit_value_t* args,
   uint num_args, int flags) /*JIT_NOTHROW*/;
jit_value_t jitom_method_invoke_virtual
  (jit_objmodel_t model, jitom_class_t klass, jitom_method_t method,
   jit_function_t func, jit_value_t* args,
   uint num_args, int flags) /*JIT_NOTHROW*/;

/*
 * Manipulate types that represent objects and inline values.
 */
jit_type_t jitom_type_tag_as_class
  (jit_type_t type, jit_objmodel_t model,
   jitom_class_t klass, int incref) /*JIT_NOTHROW*/;
jit_type_t jitom_type_tag_as_value
  (jit_type_t type, jit_objmodel_t model,
   jitom_class_t klass, int incref) /*JIT_NOTHROW*/;
int jitom_type_is_class(jit_type_t type) /*JIT_NOTHROW*/;
int jitom_type_is_value(jit_type_t type) /*JIT_NOTHROW*/;
jit_objmodel_t jitom_type_get_model(jit_type_t type) /*JIT_NOTHROW*/;
jitom_class_t jitom_type_get_class(jit_type_t type) /*JIT_NOTHROW*/;


enum JIT_OP_NOP = 0x0000;
enum JIT_OP_TRUNC_SBYTE = 0x0001;
enum JIT_OP_TRUNC_UBYTE = 0x0002;
enum JIT_OP_TRUNC_SHORT = 0x0003;
enum JIT_OP_TRUNC_USHORT = 0x0004;
enum JIT_OP_TRUNC_INT = 0x0005;
enum JIT_OP_TRUNC_UINT = 0x0006;
enum JIT_OP_CHECK_SBYTE = 0x0007;
enum JIT_OP_CHECK_UBYTE = 0x0008;
enum JIT_OP_CHECK_SHORT = 0x0009;
enum JIT_OP_CHECK_USHORT = 0x000A;
enum JIT_OP_CHECK_INT = 0x000B;
enum JIT_OP_CHECK_UINT = 0x000C;
enum JIT_OP_LOW_WORD = 0x000D;
enum JIT_OP_EXPAND_INT = 0x000E;
enum JIT_OP_EXPAND_UINT = 0x000F;
enum JIT_OP_CHECK_LOW_WORD = 0x0010;
enum JIT_OP_CHECK_SIGNED_LOW_WORD = 0x0011;
enum JIT_OP_CHECK_LONG = 0x0012;
enum JIT_OP_CHECK_ULONG = 0x0013;
enum JIT_OP_FLOAT32_TO_INT = 0x0014;
enum JIT_OP_FLOAT32_TO_UINT = 0x0015;
enum JIT_OP_FLOAT32_TO_LONG = 0x0016;
enum JIT_OP_FLOAT32_TO_ULONG = 0x0017;
enum JIT_OP_CHECK_FLOAT32_TO_INT = 0x0018;
enum JIT_OP_CHECK_FLOAT32_TO_UINT = 0x0019;
enum JIT_OP_CHECK_FLOAT32_TO_LONG = 0x001A;
enum JIT_OP_CHECK_FLOAT32_TO_ULONG = 0x001B;
enum JIT_OP_INT_TO_FLOAT32 = 0x001C;
enum JIT_OP_UINT_TO_FLOAT32 = 0x001D;
enum JIT_OP_LONG_TO_FLOAT32 = 0x001E;
enum JIT_OP_ULONG_TO_FLOAT32 = 0x001F;
enum JIT_OP_FLOAT32_TO_FLOAT64 = 0x0020;
enum JIT_OP_FLOAT64_TO_INT = 0x0021;
enum JIT_OP_FLOAT64_TO_UINT = 0x0022;
enum JIT_OP_FLOAT64_TO_LONG = 0x0023;
enum JIT_OP_FLOAT64_TO_ULONG = 0x0024;
enum JIT_OP_CHECK_FLOAT64_TO_INT = 0x0025;
enum JIT_OP_CHECK_FLOAT64_TO_UINT = 0x0026;
enum JIT_OP_CHECK_FLOAT64_TO_LONG = 0x0027;
enum JIT_OP_CHECK_FLOAT64_TO_ULONG = 0x0028;
enum JIT_OP_INT_TO_FLOAT64 = 0x0029;
enum JIT_OP_UINT_TO_FLOAT64 = 0x002A;
enum JIT_OP_LONG_TO_FLOAT64 = 0x002B;
enum JIT_OP_ULONG_TO_FLOAT64 = 0x002C;
enum JIT_OP_FLOAT64_TO_FLOAT32 = 0x002D;
enum JIT_OP_NFLOAT_TO_INT = 0x002E;
enum JIT_OP_NFLOAT_TO_UINT = 0x002F;
enum JIT_OP_NFLOAT_TO_LONG = 0x0030;
enum JIT_OP_NFLOAT_TO_ULONG = 0x0031;
enum JIT_OP_CHECK_NFLOAT_TO_INT = 0x0032;
enum JIT_OP_CHECK_NFLOAT_TO_UINT = 0x0033;
enum JIT_OP_CHECK_NFLOAT_TO_LONG = 0x0034;
enum JIT_OP_CHECK_NFLOAT_TO_ULONG = 0x0035;
enum JIT_OP_INT_TO_NFLOAT = 0x0036;
enum JIT_OP_UINT_TO_NFLOAT = 0x0037;
enum JIT_OP_LONG_TO_NFLOAT = 0x0038;
enum JIT_OP_ULONG_TO_NFLOAT = 0x0039;
enum JIT_OP_NFLOAT_TO_FLOAT32 = 0x003A;
enum JIT_OP_NFLOAT_TO_FLOAT64 = 0x003B;
enum JIT_OP_FLOAT32_TO_NFLOAT = 0x003C;
enum JIT_OP_FLOAT64_TO_NFLOAT = 0x003D;
enum JIT_OP_IADD = 0x003E;
enum JIT_OP_IADD_OVF = 0x003F;
enum JIT_OP_IADD_OVF_UN = 0x0040;
enum JIT_OP_ISUB = 0x0041;
enum JIT_OP_ISUB_OVF = 0x0042;
enum JIT_OP_ISUB_OVF_UN = 0x0043;
enum JIT_OP_IMUL = 0x0044;
enum JIT_OP_IMUL_OVF = 0x0045;
enum JIT_OP_IMUL_OVF_UN = 0x0046;
enum JIT_OP_IDIV = 0x0047;
enum JIT_OP_IDIV_UN = 0x0048;
enum JIT_OP_IREM = 0x0049;
enum JIT_OP_IREM_UN = 0x004A;
enum JIT_OP_INEG = 0x004B;
enum JIT_OP_LADD = 0x004C;
enum JIT_OP_LADD_OVF = 0x004D;
enum JIT_OP_LADD_OVF_UN = 0x004E;
enum JIT_OP_LSUB = 0x004F;
enum JIT_OP_LSUB_OVF = 0x0050;
enum JIT_OP_LSUB_OVF_UN = 0x0051;
enum JIT_OP_LMUL = 0x0052;
enum JIT_OP_LMUL_OVF = 0x0053;
enum JIT_OP_LMUL_OVF_UN = 0x0054;
enum JIT_OP_LDIV = 0x0055;
enum JIT_OP_LDIV_UN = 0x0056;
enum JIT_OP_LREM = 0x0057;
enum JIT_OP_LREM_UN = 0x0058;
enum JIT_OP_LNEG = 0x0059;
enum JIT_OP_FADD = 0x005A;
enum JIT_OP_FSUB = 0x005B;
enum JIT_OP_FMUL = 0x005C;
enum JIT_OP_FDIV = 0x005D;
enum JIT_OP_FREM = 0x005E;
enum JIT_OP_FREM_IEEE = 0x005F;
enum JIT_OP_FNEG = 0x0060;
enum JIT_OP_DADD = 0x0061;
enum JIT_OP_DSUB = 0x0062;
enum JIT_OP_DMUL = 0x0063;
enum JIT_OP_DDIV = 0x0064;
enum JIT_OP_DREM = 0x0065;
enum JIT_OP_DREM_IEEE = 0x0066;
enum JIT_OP_DNEG = 0x0067;
enum JIT_OP_NFADD = 0x0068;
enum JIT_OP_NFSUB = 0x0069;
enum JIT_OP_NFMUL = 0x006A;
enum JIT_OP_NFDIV = 0x006B;
enum JIT_OP_NFREM = 0x006C;
enum JIT_OP_NFREM_IEEE = 0x006D;
enum JIT_OP_NFNEG = 0x006E;
enum JIT_OP_IAND = 0x006F;
enum JIT_OP_IOR = 0x0070;
enum JIT_OP_IXOR = 0x0071;
enum JIT_OP_INOT = 0x0072;
enum JIT_OP_ISHL = 0x0073;
enum JIT_OP_ISHR = 0x0074;
enum JIT_OP_ISHR_UN = 0x0075;
enum JIT_OP_LAND = 0x0076;
enum JIT_OP_LOR = 0x0077;
enum JIT_OP_LXOR = 0x0078;
enum JIT_OP_LNOT = 0x0079;
enum JIT_OP_LSHL = 0x007A;
enum JIT_OP_LSHR = 0x007B;
enum JIT_OP_LSHR_UN = 0x007C;
enum JIT_OP_BR = 0x007D;
enum JIT_OP_BR_IFALSE = 0x007E;
enum JIT_OP_BR_ITRUE = 0x007F;
enum JIT_OP_BR_IEQ = 0x0080;
enum JIT_OP_BR_INE = 0x0081;
enum JIT_OP_BR_ILT = 0x0082;
enum JIT_OP_BR_ILT_UN = 0x0083;
enum JIT_OP_BR_ILE = 0x0084;
enum JIT_OP_BR_ILE_UN = 0x0085;
enum JIT_OP_BR_IGT = 0x0086;
enum JIT_OP_BR_IGT_UN = 0x0087;
enum JIT_OP_BR_IGE = 0x0088;
enum JIT_OP_BR_IGE_UN = 0x0089;
enum JIT_OP_BR_LFALSE = 0x008A;
enum JIT_OP_BR_LTRUE = 0x008B;
enum JIT_OP_BR_LEQ = 0x008C;
enum JIT_OP_BR_LNE = 0x008D;
enum JIT_OP_BR_LLT = 0x008E;
enum JIT_OP_BR_LLT_UN = 0x008F;
enum JIT_OP_BR_LLE = 0x0090;
enum JIT_OP_BR_LLE_UN = 0x0091;
enum JIT_OP_BR_LGT = 0x0092;
enum JIT_OP_BR_LGT_UN = 0x0093;
enum JIT_OP_BR_LGE = 0x0094;
enum JIT_OP_BR_LGE_UN = 0x0095;
enum JIT_OP_BR_FEQ = 0x0096;
enum JIT_OP_BR_FNE = 0x0097;
enum JIT_OP_BR_FLT = 0x0098;
enum JIT_OP_BR_FLE = 0x0099;
enum JIT_OP_BR_FGT = 0x009A;
enum JIT_OP_BR_FGE = 0x009B;
enum JIT_OP_BR_FLT_INV = 0x009C;
enum JIT_OP_BR_FLE_INV = 0x009D;
enum JIT_OP_BR_FGT_INV = 0x009E;
enum JIT_OP_BR_FGE_INV = 0x009F;
enum JIT_OP_BR_DEQ = 0x00A0;
enum JIT_OP_BR_DNE = 0x00A1;
enum JIT_OP_BR_DLT = 0x00A2;
enum JIT_OP_BR_DLE = 0x00A3;
enum JIT_OP_BR_DGT = 0x00A4;
enum JIT_OP_BR_DGE = 0x00A5;
enum JIT_OP_BR_DLT_INV = 0x00A6;
enum JIT_OP_BR_DLE_INV = 0x00A7;
enum JIT_OP_BR_DGT_INV = 0x00A8;
enum JIT_OP_BR_DGE_INV = 0x00A9;
enum JIT_OP_BR_NFEQ = 0x00AA;
enum JIT_OP_BR_NFNE = 0x00AB;
enum JIT_OP_BR_NFLT = 0x00AC;
enum JIT_OP_BR_NFLE = 0x00AD;
enum JIT_OP_BR_NFGT = 0x00AE;
enum JIT_OP_BR_NFGE = 0x00AF;
enum JIT_OP_BR_NFLT_INV = 0x00B0;
enum JIT_OP_BR_NFLE_INV = 0x00B1;
enum JIT_OP_BR_NFGT_INV = 0x00B2;
enum JIT_OP_BR_NFGE_INV = 0x00B3;
enum JIT_OP_ICMP = 0x00B4;
enum JIT_OP_ICMP_UN = 0x00B5;
enum JIT_OP_LCMP = 0x00B6;
enum JIT_OP_LCMP_UN = 0x00B7;
enum JIT_OP_FCMPL = 0x00B8;
enum JIT_OP_FCMPG = 0x00B9;
enum JIT_OP_DCMPL = 0x00BA;
enum JIT_OP_DCMPG = 0x00BB;
enum JIT_OP_NFCMPL = 0x00BC;
enum JIT_OP_NFCMPG = 0x00BD;
enum JIT_OP_IEQ = 0x00BE;
enum JIT_OP_INE = 0x00BF;
enum JIT_OP_ILT = 0x00C0;
enum JIT_OP_ILT_UN = 0x00C1;
enum JIT_OP_ILE = 0x00C2;
enum JIT_OP_ILE_UN = 0x00C3;
enum JIT_OP_IGT = 0x00C4;
enum JIT_OP_IGT_UN = 0x00C5;
enum JIT_OP_IGE = 0x00C6;
enum JIT_OP_IGE_UN = 0x00C7;
enum JIT_OP_LEQ = 0x00C8;
enum JIT_OP_LNE = 0x00C9;
enum JIT_OP_LLT = 0x00CA;
enum JIT_OP_LLT_UN = 0x00CB;
enum JIT_OP_LLE = 0x00CC;
enum JIT_OP_LLE_UN = 0x00CD;
enum JIT_OP_LGT = 0x00CE;
enum JIT_OP_LGT_UN = 0x00CF;
enum JIT_OP_LGE = 0x00D0;
enum JIT_OP_LGE_UN = 0x00D1;
enum JIT_OP_FEQ = 0x00D2;
enum JIT_OP_FNE = 0x00D3;
enum JIT_OP_FLT = 0x00D4;
enum JIT_OP_FLE = 0x00D5;
enum JIT_OP_FGT = 0x00D6;
enum JIT_OP_FGE = 0x00D7;
enum JIT_OP_FLT_INV = 0x00D8;
enum JIT_OP_FLE_INV = 0x00D9;
enum JIT_OP_FGT_INV = 0x00DA;
enum JIT_OP_FGE_INV = 0x00DB;
enum JIT_OP_DEQ = 0x00DC;
enum JIT_OP_DNE = 0x00DD;
enum JIT_OP_DLT = 0x00DE;
enum JIT_OP_DLE = 0x00DF;
enum JIT_OP_DGT = 0x00E0;
enum JIT_OP_DGE = 0x00E1;
enum JIT_OP_DLT_INV = 0x00E2;
enum JIT_OP_DLE_INV = 0x00E3;
enum JIT_OP_DGT_INV = 0x00E4;
enum JIT_OP_DGE_INV = 0x00E5;
enum JIT_OP_NFEQ = 0x00E6;
enum JIT_OP_NFNE = 0x00E7;
enum JIT_OP_NFLT = 0x00E8;
enum JIT_OP_NFLE = 0x00E9;
enum JIT_OP_NFGT = 0x00EA;
enum JIT_OP_NFGE = 0x00EB;
enum JIT_OP_NFLT_INV = 0x00EC;
enum JIT_OP_NFLE_INV = 0x00ED;
enum JIT_OP_NFGT_INV = 0x00EE;
enum JIT_OP_NFGE_INV = 0x00EF;
enum JIT_OP_IS_FNAN = 0x00F0;
enum JIT_OP_IS_FINF = 0x00F1;
enum JIT_OP_IS_FFINITE = 0x00F2;
enum JIT_OP_IS_DNAN = 0x00F3;
enum JIT_OP_IS_DINF = 0x00F4;
enum JIT_OP_IS_DFINITE = 0x00F5;
enum JIT_OP_IS_NFNAN = 0x00F6;
enum JIT_OP_IS_NFINF = 0x00F7;
enum JIT_OP_IS_NFFINITE = 0x00F8;
enum JIT_OP_FACOS = 0x00F9;
enum JIT_OP_FASIN = 0x00FA;
enum JIT_OP_FATAN = 0x00FB;
enum JIT_OP_FATAN2 = 0x00FC;
enum JIT_OP_FCEIL = 0x00FD;
enum JIT_OP_FCOS = 0x00FE;
enum JIT_OP_FCOSH = 0x00FF;
enum JIT_OP_FEXP = 0x0100;
enum JIT_OP_FFLOOR = 0x0101;
enum JIT_OP_FLOG = 0x0102;
enum JIT_OP_FLOG10 = 0x0103;
enum JIT_OP_FPOW = 0x0104;
enum JIT_OP_FRINT = 0x0105;
enum JIT_OP_FROUND = 0x0106;
enum JIT_OP_FSIN = 0x0107;
enum JIT_OP_FSINH = 0x0108;
enum JIT_OP_FSQRT = 0x0109;
enum JIT_OP_FTAN = 0x010A;
enum JIT_OP_FTANH = 0x010B;
enum JIT_OP_FTRUNC = 0x010C;
enum JIT_OP_DACOS = 0x010D;
enum JIT_OP_DASIN = 0x010E;
enum JIT_OP_DATAN = 0x010F;
enum JIT_OP_DATAN2 = 0x0110;
enum JIT_OP_DCEIL = 0x0111;
enum JIT_OP_DCOS = 0x0112;
enum JIT_OP_DCOSH = 0x0113;
enum JIT_OP_DEXP = 0x0114;
enum JIT_OP_DFLOOR = 0x0115;
enum JIT_OP_DLOG = 0x0116;
enum JIT_OP_DLOG10 = 0x0117;
enum JIT_OP_DPOW = 0x0118;
enum JIT_OP_DRINT = 0x0119;
enum JIT_OP_DROUND = 0x011A;
enum JIT_OP_DSIN = 0x011B;
enum JIT_OP_DSINH = 0x011C;
enum JIT_OP_DSQRT = 0x011D;
enum JIT_OP_DTAN = 0x011E;
enum JIT_OP_DTANH = 0x011F;
enum JIT_OP_DTRUNC = 0x0120;
enum JIT_OP_NFACOS = 0x0121;
enum JIT_OP_NFASIN = 0x0122;
enum JIT_OP_NFATAN = 0x0123;
enum JIT_OP_NFATAN2 = 0x0124;
enum JIT_OP_NFCEIL = 0x0125;
enum JIT_OP_NFCOS = 0x0126;
enum JIT_OP_NFCOSH = 0x0127;
enum JIT_OP_NFEXP = 0x0128;
enum JIT_OP_NFFLOOR = 0x0129;
enum JIT_OP_NFLOG = 0x012A;
enum JIT_OP_NFLOG10 = 0x012B;
enum JIT_OP_NFPOW = 0x012C;
enum JIT_OP_NFRINT = 0x012D;
enum JIT_OP_NFROUND = 0x012E;
enum JIT_OP_NFSIN = 0x012F;
enum JIT_OP_NFSINH = 0x0130;
enum JIT_OP_NFSQRT = 0x0131;
enum JIT_OP_NFTAN = 0x0132;
enum JIT_OP_NFTANH = 0x0133;
enum JIT_OP_NFTRUNC = 0x0134;
enum JIT_OP_IABS = 0x0135;
enum JIT_OP_LABS = 0x0136;
enum JIT_OP_FABS = 0x0137;
enum JIT_OP_DABS = 0x0138;
enum JIT_OP_NFABS = 0x0139;
enum JIT_OP_IMIN = 0x013A;
enum JIT_OP_IMIN_UN = 0x013B;
enum JIT_OP_LMIN = 0x013C;
enum JIT_OP_LMIN_UN = 0x013D;
enum JIT_OP_FMIN = 0x013E;
enum JIT_OP_DMIN = 0x013F;
enum JIT_OP_NFMIN = 0x0140;
enum JIT_OP_IMAX = 0x0141;
enum JIT_OP_IMAX_UN = 0x0142;
enum JIT_OP_LMAX = 0x0143;
enum JIT_OP_LMAX_UN = 0x0144;
enum JIT_OP_FMAX = 0x0145;
enum JIT_OP_DMAX = 0x0146;
enum JIT_OP_NFMAX = 0x0147;
enum JIT_OP_ISIGN = 0x0148;
enum JIT_OP_LSIGN = 0x0149;
enum JIT_OP_FSIGN = 0x014A;
enum JIT_OP_DSIGN = 0x014B;
enum JIT_OP_NFSIGN = 0x014C;
enum JIT_OP_CHECK_NULL = 0x014D;
enum JIT_OP_CALL = 0x014E;
enum JIT_OP_CALL_TAIL = 0x014F;
enum JIT_OP_CALL_INDIRECT = 0x0150;
enum JIT_OP_CALL_INDIRECT_TAIL = 0x0151;
enum JIT_OP_CALL_VTABLE_PTR = 0x0152;
enum JIT_OP_CALL_VTABLE_PTR_TAIL = 0x0153;
enum JIT_OP_CALL_EXTERNAL = 0x0154;
enum JIT_OP_CALL_EXTERNAL_TAIL = 0x0155;
enum JIT_OP_RETURN = 0x0156;
enum JIT_OP_RETURN_INT = 0x0157;
enum JIT_OP_RETURN_LONG = 0x0158;
enum JIT_OP_RETURN_FLOAT32 = 0x0159;
enum JIT_OP_RETURN_FLOAT64 = 0x015A;
enum JIT_OP_RETURN_NFLOAT = 0x015B;
enum JIT_OP_RETURN_SMALL_STRUCT = 0x015C;
enum JIT_OP_SETUP_FOR_NESTED = 0x015D;
enum JIT_OP_SETUP_FOR_SIBLING = 0x015E;
enum JIT_OP_IMPORT = 0x015F;
enum JIT_OP_THROW = 0x0160;
enum JIT_OP_RETHROW = 0x0161;
enum JIT_OP_LOAD_PC = 0x0162;
enum JIT_OP_LOAD_EXCEPTION_PC = 0x0163;
enum JIT_OP_ENTER_FINALLY = 0x0164;
enum JIT_OP_LEAVE_FINALLY = 0x0165;
enum JIT_OP_CALL_FINALLY = 0x0166;
enum JIT_OP_ENTER_FILTER = 0x0167;
enum JIT_OP_LEAVE_FILTER = 0x0168;
enum JIT_OP_CALL_FILTER = 0x0169;
enum JIT_OP_CALL_FILTER_RETURN = 0x016A;
enum JIT_OP_ADDRESS_OF_LABEL = 0x016B;
enum JIT_OP_COPY_LOAD_SBYTE = 0x016C;
enum JIT_OP_COPY_LOAD_UBYTE = 0x016D;
enum JIT_OP_COPY_LOAD_SHORT = 0x016E;
enum JIT_OP_COPY_LOAD_USHORT = 0x016F;
enum JIT_OP_COPY_INT = 0x0170;
enum JIT_OP_COPY_LONG = 0x0171;
enum JIT_OP_COPY_FLOAT32 = 0x0172;
enum JIT_OP_COPY_FLOAT64 = 0x0173;
enum JIT_OP_COPY_NFLOAT = 0x0174;
enum JIT_OP_COPY_STRUCT = 0x0175;
enum JIT_OP_COPY_STORE_BYTE = 0x0176;
enum JIT_OP_COPY_STORE_SHORT = 0x0177;
enum JIT_OP_ADDRESS_OF = 0x0178;
enum JIT_OP_INCOMING_REG = 0x0179;
enum JIT_OP_INCOMING_FRAME_POSN = 0x017A;
enum JIT_OP_OUTGOING_REG = 0x017B;
enum JIT_OP_OUTGOING_FRAME_POSN = 0x017C;
enum JIT_OP_RETURN_REG = 0x017D;
enum JIT_OP_PUSH_INT = 0x017E;
enum JIT_OP_PUSH_LONG = 0x017F;
enum JIT_OP_PUSH_FLOAT32 = 0x0180;
enum JIT_OP_PUSH_FLOAT64 = 0x0181;
enum JIT_OP_PUSH_NFLOAT = 0x0182;
enum JIT_OP_PUSH_STRUCT = 0x0183;
enum JIT_OP_POP_STACK = 0x0184;
enum JIT_OP_FLUSH_SMALL_STRUCT = 0x0185;
enum JIT_OP_SET_PARAM_INT = 0x0186;
enum JIT_OP_SET_PARAM_LONG = 0x0187;
enum JIT_OP_SET_PARAM_FLOAT32 = 0x0188;
enum JIT_OP_SET_PARAM_FLOAT64 = 0x0189;
enum JIT_OP_SET_PARAM_NFLOAT = 0x018A;
enum JIT_OP_SET_PARAM_STRUCT = 0x018B;
enum JIT_OP_PUSH_RETURN_AREA_PTR = 0x018C;
enum JIT_OP_LOAD_RELATIVE_SBYTE = 0x018D;
enum JIT_OP_LOAD_RELATIVE_UBYTE = 0x018E;
enum JIT_OP_LOAD_RELATIVE_SHORT = 0x018F;
enum JIT_OP_LOAD_RELATIVE_USHORT = 0x0190;
enum JIT_OP_LOAD_RELATIVE_INT = 0x0191;
enum JIT_OP_LOAD_RELATIVE_LONG = 0x0192;
enum JIT_OP_LOAD_RELATIVE_FLOAT32 = 0x0193;
enum JIT_OP_LOAD_RELATIVE_FLOAT64 = 0x0194;
enum JIT_OP_LOAD_RELATIVE_NFLOAT = 0x0195;
enum JIT_OP_LOAD_RELATIVE_STRUCT = 0x0196;
enum JIT_OP_STORE_RELATIVE_BYTE = 0x0197;
enum JIT_OP_STORE_RELATIVE_SHORT = 0x0198;
enum JIT_OP_STORE_RELATIVE_INT = 0x0199;
enum JIT_OP_STORE_RELATIVE_LONG = 0x019A;
enum JIT_OP_STORE_RELATIVE_FLOAT32 = 0x019B;
enum JIT_OP_STORE_RELATIVE_FLOAT64 = 0x019C;
enum JIT_OP_STORE_RELATIVE_NFLOAT = 0x019D;
enum JIT_OP_STORE_RELATIVE_STRUCT = 0x019E;
enum JIT_OP_ADD_RELATIVE = 0x019F;
enum JIT_OP_LOAD_ELEMENT_SBYTE = 0x01A0;
enum JIT_OP_LOAD_ELEMENT_UBYTE = 0x01A1;
enum JIT_OP_LOAD_ELEMENT_SHORT = 0x01A2;
enum JIT_OP_LOAD_ELEMENT_USHORT = 0x01A3;
enum JIT_OP_LOAD_ELEMENT_INT = 0x01A4;
enum JIT_OP_LOAD_ELEMENT_LONG = 0x01A5;
enum JIT_OP_LOAD_ELEMENT_FLOAT32 = 0x01A6;
enum JIT_OP_LOAD_ELEMENT_FLOAT64 = 0x01A7;
enum JIT_OP_LOAD_ELEMENT_NFLOAT = 0x01A8;
enum JIT_OP_STORE_ELEMENT_BYTE = 0x01A9;
enum JIT_OP_STORE_ELEMENT_SHORT = 0x01AA;
enum JIT_OP_STORE_ELEMENT_INT = 0x01AB;
enum JIT_OP_STORE_ELEMENT_LONG = 0x01AC;
enum JIT_OP_STORE_ELEMENT_FLOAT32 = 0x01AD;
enum JIT_OP_STORE_ELEMENT_FLOAT64 = 0x01AE;
enum JIT_OP_STORE_ELEMENT_NFLOAT = 0x01AF;
enum JIT_OP_MEMCPY = 0x01B0;
enum JIT_OP_MEMMOVE = 0x01B1;
enum JIT_OP_MEMSET = 0x01B2;
enum JIT_OP_ALLOCA = 0x01B3;
enum JIT_OP_MARK_OFFSET = 0x01B4;
enum JIT_OP_MARK_BREAKPOINT = 0x01B5;
enum JIT_OP_JUMP_TABLE = 0x01B6;
enum JIT_OP_NUM_OPCODES = 0x01B7;

/*
 * Opcode information.
 */
alias jit_opcode_info_t = jit_opcode_info;
struct jit_opcode_info
{
  const(char)* name;
  int     flags;
}
enum JIT_OPCODE_DEST_MASK = 0x0000000F;
enum JIT_OPCODE_DEST_EMPTY = 0x00000000;
enum JIT_OPCODE_DEST_INT = 0x00000001;
enum JIT_OPCODE_DEST_LONG = 0x00000002;
enum JIT_OPCODE_DEST_FLOAT32 = 0x00000003;
enum JIT_OPCODE_DEST_FLOAT64 = 0x00000004;
enum JIT_OPCODE_DEST_NFLOAT = 0x00000005;
enum JIT_OPCODE_DEST_ANY = 0x00000006;
enum JIT_OPCODE_SRC1_MASK = 0x000000F0;
enum JIT_OPCODE_SRC1_EMPTY = 0x00000000;
enum JIT_OPCODE_SRC1_INT = 0x00000010;
enum JIT_OPCODE_SRC1_LONG = 0x00000020;
enum JIT_OPCODE_SRC1_FLOAT32 = 0x00000030;
enum JIT_OPCODE_SRC1_FLOAT64 = 0x00000040;
enum JIT_OPCODE_SRC1_NFLOAT = 0x00000050;
enum JIT_OPCODE_SRC1_ANY = 0x00000060;
enum JIT_OPCODE_SRC2_MASK = 0x00000F00;
enum JIT_OPCODE_SRC2_EMPTY = 0x00000000;
enum JIT_OPCODE_SRC2_INT = 0x00000100;
enum JIT_OPCODE_SRC2_LONG = 0x00000200;
enum JIT_OPCODE_SRC2_FLOAT32 = 0x00000300;
enum JIT_OPCODE_SRC2_FLOAT64 = 0x00000400;
enum JIT_OPCODE_SRC2_NFLOAT = 0x00000500;
enum JIT_OPCODE_SRC2_ANY = 0x00000600;
enum JIT_OPCODE_IS_BRANCH = 0x00001000;
enum JIT_OPCODE_IS_CALL = 0x00002000;
enum JIT_OPCODE_IS_CALL_EXTERNAL = 0x00004000;
enum JIT_OPCODE_IS_REG = 0x00008000;
enum JIT_OPCODE_IS_ADDROF_LABEL = 0x00010000;
enum JIT_OPCODE_IS_JUMP_TABLE = 0x00020000;
enum JIT_OPCODE_OPER_MASK = 0x01F00000;
enum JIT_OPCODE_OPER_NONE = 0x00000000;
enum JIT_OPCODE_OPER_ADD = 0x00100000;
enum JIT_OPCODE_OPER_SUB = 0x00200000;
enum JIT_OPCODE_OPER_MUL = 0x00300000;
enum JIT_OPCODE_OPER_DIV = 0x00400000;
enum JIT_OPCODE_OPER_REM = 0x00500000;
enum JIT_OPCODE_OPER_NEG = 0x00600000;
enum JIT_OPCODE_OPER_AND = 0x00700000;
enum JIT_OPCODE_OPER_OR = 0x00800000;
enum JIT_OPCODE_OPER_XOR = 0x00900000;
enum JIT_OPCODE_OPER_NOT = 0x00A00000;
enum JIT_OPCODE_OPER_EQ = 0x00B00000;
enum JIT_OPCODE_OPER_NE = 0x00C00000;
enum JIT_OPCODE_OPER_LT = 0x00D00000;
enum JIT_OPCODE_OPER_LE = 0x00E00000;
enum JIT_OPCODE_OPER_GT = 0x00F00000;
enum JIT_OPCODE_OPER_GE = 0x01000000;
enum JIT_OPCODE_OPER_SHL = 0x01100000;
enum JIT_OPCODE_OPER_SHR = 0x01200000;
enum JIT_OPCODE_OPER_SHR_UN = 0x01300000;
enum JIT_OPCODE_OPER_COPY = 0x01400000;
enum JIT_OPCODE_OPER_ADDRESS_OF = 0x01500000;
static if (JIT_NATIVE_INT32) {
  enum JIT_OPCODE_DEST_PTR = JIT_OPCODE_DEST_INT;
  enum JIT_OPCODE_SRC1_PTR = JIT_OPCODE_SRC1_INT;
  enum JIT_OPCODE_SRC2_PTR = JIT_OPCODE_SRC2_INT;
} else {
  enum JIT_OPCODE_DEST_PTR = JIT_OPCODE_DEST_LONG;
  enum JIT_OPCODE_SRC1_PTR = JIT_OPCODE_SRC1_LONG;
  enum JIT_OPCODE_SRC2_PTR = JIT_OPCODE_SRC2_LONG;
}
extern __gshared const jit_opcode_info_t[JIT_OP_NUM_OPCODES] jit_opcodes;


/*
 * Some obsolete opcodes that have been removed because they are duplicates
 * of other opcodes.
 */
enum JIT_OP_FEQ_INV = JIT_OP_FEQ;
enum JIT_OP_FNE_INV = JIT_OP_FNE;
enum JIT_OP_DEQ_INV = JIT_OP_DEQ;
enum JIT_OP_DNE_INV = JIT_OP_DNE;
enum JIT_OP_NFEQ_INV = JIT_OP_NFEQ;
enum JIT_OP_NFNE_INV = JIT_OP_NFNE;
enum JIT_OP_BR_FEQ_INV = JIT_OP_BR_FEQ;
enum JIT_OP_BR_FNE_INV = JIT_OP_BR_FNE;
enum JIT_OP_BR_DEQ_INV = JIT_OP_BR_DEQ;
enum JIT_OP_BR_DNE_INV = JIT_OP_BR_DNE;
enum JIT_OP_BR_NFEQ_INV = JIT_OP_BR_NFEQ;
enum JIT_OP_BR_NFNE_INV = JIT_OP_BR_NFNE;


/*
 * Pre-defined type descriptors.
 */
extern __gshared /*const*/ jit_type_t jit_type_void;
extern __gshared /*const*/ jit_type_t jit_type_sbyte;
extern __gshared /*const*/ jit_type_t jit_type_ubyte;
extern __gshared /*const*/ jit_type_t jit_type_short;
extern __gshared /*const*/ jit_type_t jit_type_ushort;
extern __gshared /*const*/ jit_type_t jit_type_int;
extern __gshared /*const*/ jit_type_t jit_type_uint;
extern __gshared /*const*/ jit_type_t jit_type_nint;
extern __gshared /*const*/ jit_type_t jit_type_nuint;
extern __gshared /*const*/ jit_type_t jit_type_long;
extern __gshared /*const*/ jit_type_t jit_type_ulong;
extern __gshared /*const*/ jit_type_t jit_type_float32;
extern __gshared /*const*/ jit_type_t jit_type_float64;
extern __gshared /*const*/ jit_type_t jit_type_nfloat;
extern __gshared /*const*/ jit_type_t jit_type_void_ptr;

/*
 * Type descriptors for the system "char", "int", "long", etc types.
 * These are defined to one of the above values.
 */
extern __gshared /*const*/ jit_type_t jit_type_sys_bool;
extern __gshared /*const*/ jit_type_t jit_type_sys_char;
extern __gshared /*const*/ jit_type_t jit_type_sys_schar;
extern __gshared /*const*/ jit_type_t jit_type_sys_uchar;
extern __gshared /*const*/ jit_type_t jit_type_sys_short;
extern __gshared /*const*/ jit_type_t jit_type_sys_ushort;
extern __gshared /*const*/ jit_type_t jit_type_sys_int;
extern __gshared /*const*/ jit_type_t jit_type_sys_uint;
extern __gshared /*const*/ jit_type_t jit_type_sys_long;
extern __gshared /*const*/ jit_type_t jit_type_sys_ulong;
extern __gshared /*const*/ jit_type_t jit_type_sys_longlong;
extern __gshared /*const*/ jit_type_t jit_type_sys_ulonglong;
extern __gshared /*const*/ jit_type_t jit_type_sys_float;
extern __gshared /*const*/ jit_type_t jit_type_sys_double;
extern __gshared /*const*/ jit_type_t jit_type_sys_long_double;

/*
 * Type kinds that may be returned by "jit_type_get_kind".
 */
enum JIT_TYPE_INVALID = -1;
enum JIT_TYPE_VOID = 0;
enum JIT_TYPE_SBYTE = 1;
enum JIT_TYPE_UBYTE = 2;
enum JIT_TYPE_SHORT = 3;
enum JIT_TYPE_USHORT = 4;
enum JIT_TYPE_INT = 5;
enum JIT_TYPE_UINT = 6;
enum JIT_TYPE_NINT = 7;
enum JIT_TYPE_NUINT = 8;
enum JIT_TYPE_LONG = 9;
enum JIT_TYPE_ULONG = 10;
enum JIT_TYPE_FLOAT32 = 11;
enum JIT_TYPE_FLOAT64 = 12;
enum JIT_TYPE_NFLOAT = 13;
enum JIT_TYPE_MAX_PRIMITIVE = JIT_TYPE_NFLOAT;
enum JIT_TYPE_STRUCT = 14;
enum JIT_TYPE_UNION = 15;
enum JIT_TYPE_SIGNATURE = 16;
enum JIT_TYPE_PTR = 17;
enum JIT_TYPE_FIRST_TAGGED = 32;

/*
 * Special tag types.
 */
enum JIT_TYPETAG_NAME = 10000;
enum JIT_TYPETAG_STRUCT_NAME = 10001;
enum JIT_TYPETAG_UNION_NAME = 10002;
enum JIT_TYPETAG_ENUM_NAME = 10003;
enum JIT_TYPETAG_CONST = 10004;
enum JIT_TYPETAG_VOLATILE = 10005;
enum JIT_TYPETAG_REFERENCE = 10006;
enum JIT_TYPETAG_OUTPUT = 10007;
enum JIT_TYPETAG_RESTRICT = 10008;
enum JIT_TYPETAG_SYS_BOOL = 10009;
enum JIT_TYPETAG_SYS_CHAR = 10010;
enum JIT_TYPETAG_SYS_SCHAR = 10011;
enum JIT_TYPETAG_SYS_UCHAR = 10012;
enum JIT_TYPETAG_SYS_SHORT = 10013;
enum JIT_TYPETAG_SYS_USHORT = 10014;
enum JIT_TYPETAG_SYS_INT = 10015;
enum JIT_TYPETAG_SYS_UINT = 10016;
enum JIT_TYPETAG_SYS_LONG = 10017;
enum JIT_TYPETAG_SYS_ULONG = 10018;
enum JIT_TYPETAG_SYS_LONGLONG = 10019;
enum JIT_TYPETAG_SYS_ULONGLONG = 10020;
enum JIT_TYPETAG_SYS_FLOAT = 10021;
enum JIT_TYPETAG_SYS_DOUBLE = 10022;
enum JIT_TYPETAG_SYS_LONGDOUBLE = 10023;

/*
 * ABI types for function signatures.
 */
alias jit_abi_t = uint;
enum : uint /*jit_abi_t*/
{
  jit_abi_cdecl,      /* Native C calling conventions */
  jit_abi_vararg,     /* Native C with optional variable arguments */
  jit_abi_stdcall,    /* Win32 STDCALL (same as cdecl if not Win32) */
  jit_abi_fastcall,   /* Win32 FASTCALL (same as cdecl if not Win32) */
}

/*
 * External function declarations.
 */
jit_type_t jit_type_copy(jit_type_t type) /*JIT_NOTHROW*/;
void jit_type_free(jit_type_t type) /*JIT_NOTHROW*/;
jit_type_t jit_type_create_struct
  (jit_type_t* fields, uint num_fields, int incref) /*JIT_NOTHROW*/;
jit_type_t jit_type_create_union
  (jit_type_t* fields, uint num_fields, int incref) /*JIT_NOTHROW*/;
jit_type_t jit_type_create_signature
  (jit_abi_t abi, jit_type_t return_type, jit_type_t* params,
   uint num_params, int incref) /*JIT_NOTHROW*/;
jit_type_t jit_type_create_pointer(jit_type_t type, int incref) /*JIT_NOTHROW*/;
jit_type_t jit_type_create_tagged
  (jit_type_t type, int kind, void* data,
   jit_meta_free_func free_func, int incref) /*JIT_NOTHROW*/;
int jit_type_set_names
  (jit_type_t type, char** names, uint num_names) /*JIT_NOTHROW*/;
void jit_type_set_size_and_alignment
  (jit_type_t type, jit_nint size, jit_nint alignment) /*JIT_NOTHROW*/;
void jit_type_set_offset
  (jit_type_t type, uint field_index, jit_nuint offset) /*JIT_NOTHROW*/;
int jit_type_get_kind(jit_type_t type) /*JIT_NOTHROW*/;
jit_nuint jit_type_get_size(jit_type_t type) /*JIT_NOTHROW*/;
jit_nuint jit_type_get_alignment(jit_type_t type) /*JIT_NOTHROW*/;
uint jit_type_num_fields(jit_type_t type) /*JIT_NOTHROW*/;
jit_type_t jit_type_get_field
  (jit_type_t type, uint field_index) /*JIT_NOTHROW*/;
jit_nuint jit_type_get_offset
  (jit_type_t type, uint field_index) /*JIT_NOTHROW*/;
const(char)* jit_type_get_name(jit_type_t type, uint index) /*JIT_NOTHROW*/;
enum JIT_INVALID_NAME = (~(cast(uint)0));
uint jit_type_find_name(jit_type_t type, const(char)* name) /*JIT_NOTHROW*/;
uint jit_type_num_params(jit_type_t type) /*JIT_NOTHROW*/;
jit_type_t jit_type_get_return(jit_type_t type) /*JIT_NOTHROW*/;
jit_type_t jit_type_get_param
  (jit_type_t type, uint param_index) /*JIT_NOTHROW*/;
jit_abi_t jit_type_get_abi(jit_type_t type) /*JIT_NOTHROW*/;
jit_type_t jit_type_get_ref(jit_type_t type) /*JIT_NOTHROW*/;
jit_type_t jit_type_get_tagged_type(jit_type_t type) /*JIT_NOTHROW*/;
void jit_type_set_tagged_type
  (jit_type_t type, jit_type_t underlying, int incref) /*JIT_NOTHROW*/;
int jit_type_get_tagged_kind(jit_type_t type) /*JIT_NOTHROW*/;
void* jit_type_get_tagged_data(jit_type_t type) /*JIT_NOTHROW*/;
void jit_type_set_tagged_data
  (jit_type_t type, void* data, jit_meta_free_func free_func) /*JIT_NOTHROW*/;
int jit_type_is_primitive(jit_type_t type) /*JIT_NOTHROW*/;
int jit_type_is_struct(jit_type_t type) /*JIT_NOTHROW*/;
int jit_type_is_union(jit_type_t type) /*JIT_NOTHROW*/;
int jit_type_is_signature(jit_type_t type) /*JIT_NOTHROW*/;
int jit_type_is_pointer(jit_type_t type) /*JIT_NOTHROW*/;
int jit_type_is_tagged(jit_type_t type) /*JIT_NOTHROW*/;
jit_nuint jit_type_best_alignment() /*JIT_NOTHROW*/;
jit_type_t jit_type_normalize(jit_type_t type) /*JIT_NOTHROW*/;
jit_type_t jit_type_remove_tags(jit_type_t type) /*JIT_NOTHROW*/;
jit_type_t jit_type_promote_int(jit_type_t type) /*JIT_NOTHROW*/;
int jit_type_return_via_pointer(jit_type_t type) /*JIT_NOTHROW*/;
int jit_type_has_tag(jit_type_t type, int kind) /*JIT_NOTHROW*/;


struct jit_unwind_context_t
{
  void* frame;
  void* cache;
  jit_context_t context;
/+k8:???
#ifdef _JIT_ARCH_UNWIND_DATA
  _JIT_ARCH_UNWIND_DATA
#endif
+/
}

int jit_unwind_init(jit_unwind_context_t* unwind, jit_context_t context);
void jit_unwind_free(jit_unwind_context_t* unwind);

int jit_unwind_next(jit_unwind_context_t* unwind);
int jit_unwind_next_pc(jit_unwind_context_t* unwind);
void* jit_unwind_get_pc(jit_unwind_context_t* unwind);

int jit_unwind_jump(jit_unwind_context_t* unwind, void* pc);

jit_function_t jit_unwind_get_function(jit_unwind_context_t* unwind);
uint jit_unwind_get_offset(jit_unwind_context_t* unwind);


/*
 * Memory allocation routines.
 */
void* jit_malloc(uint size) /*JIT_NOTHROW*/;
void* jit_calloc(uint num, uint size) /*JIT_NOTHROW*/;
void* jit_realloc(void* ptr, uint size) /*JIT_NOTHROW*/;
void jit_free(void* ptr) /*JIT_NOTHROW*/;

/*
#define jit_new(type)   ((type *)jit_malloc(sizeof(type)))
#define jit_cnew(type)    ((type *)jit_calloc(1, sizeof(type)))
*/
auto jit_new(T) () { return cast(T*)jit_malloc(T.sizeof); }
auto jit_cnew(T) () { return cast(T*)jit_cmalloc(1, T.sizeof); }

/*
 * Memory set/copy/compare routines.
 */
void* jit_memset(void* dest, int ch, uint len) /*JIT_NOTHROW*/;
void* jit_memcpy(void* dest, const(void)* src, uint len) /*JIT_NOTHROW*/;
void* jit_memmove(void* dest, const(void)* src, uint len) /*JIT_NOTHROW*/;
int   jit_memcmp(const(void)* s1, const(void)* s2, uint len) /*JIT_NOTHROW*/;
void* jit_memchr(const(void)* str, int ch, uint len) /*JIT_NOTHROW*/;

/*
 * String routines.
 */
uint jit_strlen(const(char)* str) /*JIT_NOTHROW*/;
char* jit_strcpy(char* dest, const(char)* src) /*JIT_NOTHROW*/;
char* jit_strcat(char* dest, const(char)* src) /*JIT_NOTHROW*/;
char* jit_strncpy(char* dest, const(char)* src, uint len) /*JIT_NOTHROW*/;
char* jit_strdup(const(char)* str) /*JIT_NOTHROW*/;
char* jit_strndup(const(char)* str, uint len) /*JIT_NOTHROW*/;
int jit_strcmp(const(char)* str1, const(char)* str2) /*JIT_NOTHROW*/;
int jit_strncmp
  (const(char)* str1, const(char)* str2, uint len) /*JIT_NOTHROW*/;
int jit_stricmp(const(char)* str1, const(char)* str2) /*JIT_NOTHROW*/;
int jit_strnicmp
  (const(char)* str1, const(char)* str2, uint len) /*JIT_NOTHROW*/;
char* jit_strchr(const(char)* str, int ch) /*JIT_NOTHROW*/;
char* jit_strrchr(const(char)* str, int ch) /*JIT_NOTHROW*/;
int jit_sprintf(char* str, const(char)* format, ...) /*JIT_NOTHROW*/;
int jit_snprintf
  (char* str, uint len, const(char)* format, ...) /*JIT_NOTHROW*/;


/*
 * Full struction that can hold a constant of any type.
 */
struct jit_constant_t
{
  jit_type_t      type;
  union
  {
    void* ptr_value;
    jit_int     int_value;
    jit_uint    uint_value;
    jit_nint    nint_value;
    jit_nuint   nuint_value;
    jit_long    long_value;
    jit_ulong   ulong_value;
    jit_float32   float32_value;
    jit_float64   float64_value;
    jit_nfloat    nfloat_value;
  } /*un;*/ //k8
}

/*
 * External function declarations.
 */
jit_value_t jit_value_create(jit_function_t func, jit_type_t type) /*JIT_NOTHROW*/;
jit_value_t jit_value_create_nint_constant
  (jit_function_t func, jit_type_t type, jit_nint const_value) /*JIT_NOTHROW*/;
jit_value_t jit_value_create_long_constant
  (jit_function_t func, jit_type_t type, jit_long const_value) /*JIT_NOTHROW*/;
jit_value_t jit_value_create_float32_constant
  (jit_function_t func, jit_type_t type,
   jit_float32 const_value) /*JIT_NOTHROW*/;
jit_value_t jit_value_create_float64_constant
  (jit_function_t func, jit_type_t type,
   jit_float64 const_value) /*JIT_NOTHROW*/;
jit_value_t jit_value_create_nfloat_constant
  (jit_function_t func, jit_type_t type,
   jit_nfloat const_value) /*JIT_NOTHROW*/;
jit_value_t jit_value_create_constant
  (jit_function_t func, const jit_constant_t* const_value) /*JIT_NOTHROW*/;
jit_value_t jit_value_get_param
  (jit_function_t func, uint param) /*JIT_NOTHROW*/;
jit_value_t jit_value_get_struct_pointer(jit_function_t func) /*JIT_NOTHROW*/;
int jit_value_is_temporary(jit_value_t value) /*JIT_NOTHROW*/;
int jit_value_is_local(jit_value_t value) /*JIT_NOTHROW*/;
int jit_value_is_constant(jit_value_t value) /*JIT_NOTHROW*/;
int jit_value_is_parameter(jit_value_t value) /*JIT_NOTHROW*/;
void jit_value_ref(jit_function_t func, jit_value_t value) /*JIT_NOTHROW*/;
void jit_value_set_volatile(jit_value_t value) /*JIT_NOTHROW*/;
int jit_value_is_volatile(jit_value_t value) /*JIT_NOTHROW*/;
void jit_value_set_addressable(jit_value_t value) /*JIT_NOTHROW*/;
int jit_value_is_addressable(jit_value_t value) /*JIT_NOTHROW*/;
jit_type_t jit_value_get_type(jit_value_t value) /*JIT_NOTHROW*/;
jit_function_t jit_value_get_function(jit_value_t value) /*JIT_NOTHROW*/;
jit_block_t jit_value_get_block(jit_value_t value) /*JIT_NOTHROW*/;
jit_context_t jit_value_get_context(jit_value_t value) /*JIT_NOTHROW*/;
jit_constant_t jit_value_get_constant(jit_value_t value) /*JIT_NOTHROW*/;
jit_nint jit_value_get_nint_constant(jit_value_t value) /*JIT_NOTHROW*/;
jit_long jit_value_get_long_constant(jit_value_t value) /*JIT_NOTHROW*/;
jit_float32 jit_value_get_float32_constant(jit_value_t value) /*JIT_NOTHROW*/;
jit_float64 jit_value_get_float64_constant(jit_value_t value) /*JIT_NOTHROW*/;
jit_nfloat jit_value_get_nfloat_constant(jit_value_t value) /*JIT_NOTHROW*/;
int jit_value_is_true(jit_value_t value) /*JIT_NOTHROW*/;
int jit_constant_convert
  (jit_constant_t* result, const jit_constant_t* value,
   jit_type_t type, int overflow_check) /*JIT_NOTHROW*/;


enum jit_prot_t {
  JIT_PROT_NONE,
  JIT_PROT_READ,
  JIT_PROT_READ_WRITE,
  JIT_PROT_EXEC_READ,
  JIT_PROT_EXEC_READ_WRITE,
}


void jit_vmem_init();

jit_uint jit_vmem_page_size();
jit_nuint jit_vmem_round_up(jit_nuint value);
jit_nuint jit_vmem_round_down(jit_nuint value);

void* jit_vmem_reserve(jit_uint size);
void* jit_vmem_reserve_committed(jit_uint size, jit_prot_t prot);
int jit_vmem_release(void* addr, jit_uint size);

int jit_vmem_commit(void* addr, jit_uint size, jit_prot_t prot);
int jit_vmem_decommit(void* addr, jit_uint size);

int jit_vmem_protect(void* addr, jit_uint size, jit_prot_t prot);


/*
 * Get the frame address for a frame which is "n" levels up the stack.
 * A level value of zero indicates the current frame.
 */
void* _jit_get_frame_address(void* start, uint n);
/+k8:???
#if defined(__GNUC__)
# define jit_get_frame_address(n) \
  (_jit_get_frame_address(jit_get_current_frame(), (n)))
#else
# define jit_get_frame_address(n) (_jit_get_frame_address(0, (n)))
#endif
+/

/*
 * Get the frame address for the current frame.  May be more efficient
 * than using "jit_get_frame_address(0)".
 *
 * Note: some gcc vestions have broken __builtin_frame_address() so use
 * _JIT_ARCH_GET_CURRENT_FRAME() if available.
 */
/+k8:???
#if defined(__GNUC__)
# define JIT_FAST_GET_CURRENT_FRAME 1
# if defined(_JIT_ARCH_GET_CURRENT_FRAME)
#  define jit_get_current_frame()     \
  ({            \
    void* address;        \
    _JIT_ARCH_GET_CURRENT_FRAME(address); \
    address;        \
  })
# else
#  define jit_get_current_frame() (__builtin_frame_address(0))
# endif
#else
# define JIT_FAST_GET_CURRENT_FRAME 0
# define jit_get_current_frame()  (jit_get_frame_address(0))
#endif

/*
 * Get the next frame up the stack from a specified frame.
 * Returns NULL if it isn't possible to retrieve the next frame.
 */
void* _jit_get_next_frame_address(void* frame);
#if defined(__GNUC__) && defined(_JIT_ARCH_GET_NEXT_FRAME)
# define jit_get_next_frame_address(frame)      \
  ({              \
    void* address;          \
    _JIT_ARCH_GET_NEXT_FRAME(address, (frame)); \
    address;          \
  })
#else
# define jit_get_next_frame_address(frame)  \
  (_jit_get_next_frame_address(frame))
#endif

/*
 * Get the return address for a specific frame.
 */
void* _jit_get_return_address(void* frame, void* frame0, void* return0);
#if defined(__GNUC__)
# if defined(_JIT_ARCH_GET_RETURN_ADDRESS)
#  define jit_get_return_address(frame)       \
  ({              \
    void* address;          \
    _JIT_ARCH_GET_RETURN_ADDRESS(address, (frame)); \
    address;          \
  })
# else
#  define jit_get_return_address(frame)     \
  (_jit_get_return_address      \
    ((frame),       \
     __builtin_frame_address(0),    \
     __builtin_return_address(0)))
# endif
#else
# define jit_get_return_address(frame)  \
  (_jit_get_return_address((frame), 0, 0))
#endif

/*
 * Get the return address for the current frame.  May be more efficient
 * than using "jit_get_return_address(0)".
 */
#if defined(__GNUC__)
# if defined(_JIT_ARCH_GET_CURRENT_RETURN)
#  define jit_get_current_return()      \
  ({            \
    void* address;        \
    _JIT_ARCH_GET_CURRENT_RETURN(address);  \
    address;        \
  })
# else
#  define jit_get_current_return()  (__builtin_return_address(0))
# endif
#else
# define jit_get_current_return() \
  (jit_get_return_address(jit_get_current_frame()))
#endif
+/

/*
 * Declare a stack crawl mark variable.  The address of this variable
 * can be passed to "jit_frame_contains_crawl_mark" to determine
 * if a frame contains the mark.
 */
//k8:??? struct jit_crawl_mark_t { void* volatile mark; }
//k8:??? #define jit_declare_crawl_mark(name)  jit_crawl_mark_t name = {0}

/*
 * Determine if the stack frame just above "frame" contains a
 * particular crawl mark.
 */
//k8:??? int jit_frame_contains_crawl_mark(void* frame, jit_crawl_mark_t* mark);


/*
 * Result values for "_jit_cache_start_function" and "_jit_cache_end_function".
 */
enum JIT_MEMORY_OK = 0; /* Function is OK */
enum JIT_MEMORY_RESTART = 1; /* Restart is required */
enum JIT_MEMORY_TOO_BIG = 2; /* Function is too big for the cache */
enum JIT_MEMORY_ERROR = 3; /* Other error */


/* TODO: the proper place for this is jit-def.h and it's going to depend on the platform. */
alias jit_size_t = uint;

alias jit_memory_context_t = void*;
alias jit_function_info_t = void*;

alias jit_memory_manager_t = const(jit_memory_manager)*; //k8: const?!

struct jit_memory_manager
{
  jit_memory_context_t function (jit_context_t context) create;
  void function (jit_memory_context_t memctx) destroy;

  jit_function_info_t function (jit_memory_context_t memctx, void *pc) find_function_info;
  jit_function_t function (jit_memory_context_t memctx, jit_function_info_t info) get_function;
  void* function (jit_memory_context_t memctx, jit_function_info_t info) get_function_start;
  void* function (jit_memory_context_t memctx, jit_function_info_t info) get_function_end;

  jit_function_t function (jit_memory_context_t memctx) alloc_function;
  void function (jit_memory_context_t memctx, jit_function_t func) free_function;

  int function (jit_memory_context_t memctx, jit_function_t func) start_function;
  int function (jit_memory_context_t memctx, int result) end_function;
  int function (jit_memory_context_t memctx, int count) extend_limit;

  void* function (jit_memory_context_t memctx) get_limit;
  void* function (jit_memory_context_t memctx) get_break;
  void function (jit_memory_context_t memctx, void *brk) set_break;

  void* function (jit_memory_context_t memctx) alloc_trampoline;
  void function (jit_memory_context_t memctx, void *ptr) free_trampoline;

  void* function (jit_memory_context_t memctx) alloc_closure;
  void function (jit_memory_context_t memctx, void *ptr) free_closure;

  void* function (jit_memory_context_t memctx, jit_size_t size, jit_size_t align_) alloc_data;
}

jit_memory_manager_t jit_default_memory_manager() /*JIT_NOTHROW*/;
