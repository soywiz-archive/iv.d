/// A D API for libgccjit, purely as final class wrapper functions.
/// Copyright (C) 2014-2015 Iain Buclaw.

/// This file is part of gccjitd.

/// This program is free software: you can redistribute it and/or modify
/// it under the terms of the GNU General Public License as published by
/// the Free Software Foundation, version 3 of the License ONLY.

/// This program is distributed in the hope that it will be useful,
/// but WITHOUT ANY WARRANTY; without even the implied warranty of
/// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
/// GNU General Public License for more details.

/// You should have received a copy of the GNU General Public License
/// along with this program.  If not, see <http://www.gnu.org/licenses/>.
module iv.gccjit /*is aliced*/;
pragma(lib, "gccjit");

import iv.alice;
import std.conv : to;
import std.string : toStringz;
import std.traits : isIntegral, isSigned;

/// Errors within the API become D exceptions of this class.
final class JITError : Exception
{
    @safe pure nothrow this(string msg, Throwable next = null)
    {
        super(msg, next);
    }

    @safe pure nothrow this(string msg, string file, usize line, Throwable next = null)
    {
        super(msg, file, line, next);
    }
}

/// Class wrapper for gcc_jit_object.
/// All JITObject's are created within a JITContext, and are automatically
/// cleaned up when the context is released.

/// The class hierachy looks like this:
///  $(OL - JITObject
///      $(OL - JITLocation)
///      $(OL - JITType
///         $(OL - JITStruct))
///      $(OL - JITField)
///      $(OL - JITFunction)
///      $(OL - JITBlock)
///      $(OL - JITRValue
///          $(OL - JITLValue
///              $(OL - JITParam))))
class JITObject
{
    /// Return the context this JITObject is within.
    final JITContext getContext()
    {
        auto result = gcc_jit_object_get_context(this.m_inner_obj);
        return new JITContext(result);
    }

    /// Get a human-readable description of this object.
    override final string toString()
    {
        auto result = gcc_jit_object_get_debug_string(this.m_inner_obj);
        return to!string(result);
    }

protected:
    // Constructors and getObject are hidden from public.
    this()
    {
        this.m_inner_obj = null;
    }

    this(gcc_jit_object *obj)
    {
        if (!obj)
            throw new JITError("Unknown error, got bad object");
        this.m_inner_obj = obj;
    }

    final gcc_jit_object *getObject()
    {
        return this.m_inner_obj;
    }

private:
    // The actual gccjit object we interface with.
    gcc_jit_object *m_inner_obj;
}

/// Class wrapper for gcc_jit_location.
/// A JITLocation encapsulates a source code locations, so that you can associate
/// locations in your language with statements in the JIT-compiled code.
class JITLocation : JITObject
{
    ///
    this()
    {
        super();
    }

    ///
    this(gcc_jit_location *loc)
    {
        super(gcc_jit_location_as_object(loc));
    }

    /// Returns the internal gcc_jit_location object.
    final gcc_jit_location *getLocation()
    {
        // Manual downcast.
        return cast(gcc_jit_location *)(this.getObject());
    }
}

/// The top-level of the API is the JITContext class.

/// A JITContext instance encapsulates the state of a compilation.
/// It goes through two states.
/// Initial:
///     During which you can set up options on it, and add types,
///     functions and code, using the API below. Invoking compile
///     on it transitions it to the PostCompilation state.
/// PostCompilation:
///     When you can call JITContext.release to clean it up.
final class JITContext
{
    ///
    this(bool acquire = true)
    {
        if (acquire)
            this.m_inner_ctxt = gcc_jit_context_acquire();
        else
            this.m_inner_ctxt = null;
    }

    ///
    this(gcc_jit_context *context)
    {
        if (!context)
            throw new JITError("Unknown error, got bad context");
        this.m_inner_ctxt = context;
    }

    /// Acquire a JIT-compilation context.
    static JITContext acquire()
    {
        return new JITContext(gcc_jit_context_acquire());
    }

    /// Release the context.
    /// After this call, it's no longer valid to use this JITContext.
    void release()
    {
        gcc_jit_context_release(this.m_inner_ctxt);
        this.m_inner_ctxt = null;
    }

    /// Set a string option of the context; see JITStrOption for notes
    /// on the options and their meanings.
    /// Params:
    ///     opt   = Which option to set.
    ///     value = The new value.
    void setOption(JITStrOption opt, string value)
    {
        gcc_jit_context_set_str_option(this.m_inner_ctxt, opt, value.toStringz());
    }

    /// Set an integer option of the context; see JITIntOption for notes
    /// on the options and their meanings.
    /// Params:
    ///     opt   = Which option to set.
    ///     value = The new value.
    void setOption(JITIntOption opt, int value)
    {
        gcc_jit_context_set_int_option(this.m_inner_ctxt, opt, value);
    }

    /// Set a boolean option of the context; see JITBoolOption for notes
    /// on the options and their meanings.
    /// Params:
    ///     opt   = Which option to set.
    ///     value = The new value.
    void setOption(JITBoolOption opt, bool value)
    {
        gcc_jit_context_set_bool_option(this.m_inner_ctxt, opt, value);
    }

    /// Calls into GCC and runs the build.  It can only be called once on a
    /// given context.
    /// Returns:
    ///     A wrapper around a .so file.
    JITResult compile()
    {
        auto result = gcc_jit_context_compile(this.m_inner_ctxt);
        if (!result)
            throw new JITError(this.getFirstError());
        return new JITResult(result);
    }

    /// Returns:
    ///     The first error message that occurred when compiling the context.
    string getFirstError()
    {
        const char *err = gcc_jit_context_get_first_error(this.m_inner_ctxt);
        if (err)
            return to!string(err);
        return null;
    }

    /// Dump a C-like representation describing what's been set up on the
    /// context to file.
    /// Params:
    ///     path             = Location of file to write to.
    ///     update_locations = If true, then also write JITLocation information.
    void dump(string path, bool update_locations)
    {
        gcc_jit_context_dump_to_file(this.m_inner_ctxt,
                                     path.toStringz(),
                                     update_locations);
    }

    /// Returns the internal gcc_jit_context object.
    gcc_jit_context *getContext()
    {
        return this.m_inner_ctxt;
    }

    /// Build a JITType from one of the types in JITTypeKind.
    JITType getType(JITTypeKind kind)
    {
        auto result = gcc_jit_context_get_type(this.m_inner_ctxt, kind);
        return new JITType(result);
    }

    /// Build an integer type of a given size and signedness.
    JITType getIntType(int num_bytes, bool is_signed)
    {
        auto result = gcc_jit_context_get_int_type(this.m_inner_ctxt,
                                                   num_bytes, is_signed);
        return new JITType(result);
    }

    /// A way to map a specific int type, using the compiler to
    /// get the details automatically e.g:
    ///     JITType type = getIntType!usize();
    JITType getIntType(T)() if (isIntegral!T)
    {
        return this.getIntType(T.sizeof, isSigned!T);
    }

    /// Create a reference to a GCC builtin function.
    JITFunction getBuiltinFunction(string name)
    {
        auto result = gcc_jit_context_get_builtin_function(this.m_inner_ctxt,
                                                           name.toStringz());
        return new JITFunction(result);
    }

    /// Create a new child context of the given JITContext, inheriting a copy
    /// of all option settings from the parent.
    /// The returned JITContext can reference objects created within the
    /// parent, but not vice-versa.  The lifetime of the child context must be
    /// bounded by that of the parent. You should release a child context
    /// before releasing the parent context.
    JITContext newChildContext()
    {
        auto result = gcc_jit_context_new_child_context(this.m_inner_ctxt);
        if (!result)
            throw new JITError("Unknown error creating child context");
        return new JITContext(result);
    }

    /// Make a JITLocation representing a source location,
    /// for use by the debugger.
    /// Note:
    ///     You need to enable JITBoolOption.DEBUGINFO on the context
    ///     for these locations to actually be usable by the debugger.
    JITLocation newLocation(string filename, int line, int column)
    {
        auto result = gcc_jit_context_new_location(this.m_inner_ctxt,
                                                   filename.toStringz(),
                                                   line, column);
        return new JITLocation(result);
    }

    /// Given type "T", build a new array type of "T[N]".
    JITType newArrayType(JITLocation loc, JITType type, int dims)
    {
        auto result = gcc_jit_context_new_array_type(this.m_inner_ctxt,
                                                     loc ? loc.getLocation() : null,
                                                     type.getType(), dims);
        return new JITType(result);
    }

    /// Ditto
    JITType newArrayType(JITType type, int dims)
    {
        return this.newArrayType(null, type, dims);
    }

    /// Ditto
    JITType newArrayType(JITLocation loc, JITTypeKind kind, int dims)
    {
        return this.newArrayType(loc, this.getType(kind), dims);
    }

    /// Ditto
    JITType newArrayType(JITTypeKind kind, int dims)
    {
        return this.newArrayType(null, this.getType(kind), dims);
    }

    /// Create a field, for use within a struct or union.
    JITField newField(JITLocation loc, JITType type, string name)
    {
        auto result = gcc_jit_context_new_field(this.m_inner_ctxt,
                                                loc ? loc.getLocation() : null,
                                                type.getType(),
                                                name.toStringz());
        return new JITField(result);
    }

    /// Ditto
    JITField newField(JITType type, string name)
    {
        return this.newField(null, type, name);
    }

    /// Ditto
    JITField newField(JITLocation loc, JITTypeKind kind, string name)
    {
        return this.newField(loc, this.getType(kind), name);
    }

    /// Ditto
    JITField newField(JITTypeKind kind, string name)
    {
        return this.newField(null, this.getType(kind), name);
    }

    /// Create a struct type from an array of fields.
    JITStruct newStructType(JITLocation loc, string name, JITField[] fields...)
    {
        // Convert to an array of inner pointers.
        gcc_jit_field*[] field_p = new gcc_jit_field*[fields.length];
        foreach(i, field; fields)
            field_p[i] = field.getField();

        // Treat the array as being of the underlying pointers, relying on
        // the wrapper type being such a pointer internally.
        auto result = gcc_jit_context_new_struct_type(this.m_inner_ctxt,
                                                      loc ? loc.getLocation() : null,
                                                      name.toStringz(),
                                                      cast(int)fields.length,
                                                      field_p.ptr);
        return new JITStruct(result);
    }

    /// Ditto
    JITStruct newStructType(string name, JITField[] fields...)
    {
        return this.newStructType(null, name, fields);
    }

    /// Create an opaque struct type.
    JITStruct newOpaqueStructType(JITLocation loc, string name)
    {
        auto result = gcc_jit_context_new_opaque_struct(this.m_inner_ctxt,
                                                        loc ? loc.getLocation() : null,
                                                        name.toStringz());
        return new JITStruct(result);
    }

    /// Ditto
    JITStruct newOpaqueStructType(string name)
    {
        return this.newOpaqueStructType(null, name);
    }

    /// Create a union type from an array of fields.
    JITType newUnionType(JITLocation loc, string name, JITField[] fields...)
    {
        // Convert to an array of inner pointers.
        gcc_jit_field*[] field_p = new gcc_jit_field*[fields.length];
        foreach(i, field; fields)
            field_p[i] = field.getField();

        // Treat the array as being of the underlying pointers, relying on
        // the wrapper type being such a pointer internally.
        auto result = gcc_jit_context_new_union_type(this.m_inner_ctxt,
                                                     loc ? loc.getLocation() : null,
                                                     name.toStringz(),
                                                     cast(int)fields.length,
                                                     field_p.ptr);
        return new JITType(result);
    }

    /// Ditto
    JITType newUnionType(string name, JITField[] fields...)
    {
        return this.newUnionType(null, name, fields);
    }

    /// Create a function type.
    JITType newFunctionType(JITLocation loc, JITType return_type,
                            bool is_variadic, JITType[] param_types...)
    {
        // Convert to an array of inner pointers.
        gcc_jit_type*[] type_p = new gcc_jit_type*[param_types.length];
        foreach(i, type; param_types)
            type_p[i] = type.getType();

        // Treat the array as being of the underlying pointers, relying on
        // the wrapper type being such a pointer internally.
        auto result = gcc_jit_context_new_function_ptr_type(this.m_inner_ctxt,
                                                            loc ? loc.getLocation() : null,
                                                            return_type.getType(),
                                                            cast(int)param_types.length,
                                                            type_p.ptr, is_variadic);
        return new JITType(result);
    }

    /// Ditto
    JITType newFunctionType(JITType return_type, bool is_variadic,
                            JITType[] param_types...)
    {
        return this.newFunctionType(null, return_type, is_variadic,
                                    param_types);
    }

    /// Ditto
    JITType newFunctionType(JITLocation loc, JITTypeKind return_kind,
                            bool is_variadic, JITType[] param_types...)
    {
        return this.newFunctionType(loc, this.getType(return_kind),
                                    is_variadic, param_types);
    }

    /// Ditto
    JITType newFunctionType(JITTypeKind return_kind, bool is_variadic,
                            JITType[] param_types...)
    {
        return this.newFunctionType(null, this.getType(return_kind),
                                    is_variadic, param_types);
    }

    /// Create a function parameter.
    JITParam newParam(JITLocation loc, JITType type, string name)
    {
        auto result = gcc_jit_context_new_param(this.m_inner_ctxt,
                                                loc ? loc.getLocation() : null,
                                                type.getType(),
                                                name.toStringz());
        return new JITParam(result);
    }

    /// Ditto
    JITParam newParam(JITType type, string name)
    {
        return this.newParam(null, type, name);
    }

    /// Ditto
    JITParam newParam(JITLocation loc, JITTypeKind kind, string name)
    {
        return this.newParam(loc, this.getType(kind), name);
    }

    /// Ditto
    JITParam newParam(JITTypeKind kind, string name)
    {
        return this.newParam(null, this.getType(kind), name);
    }

    /// Create a function.
    JITFunction newFunction(JITLocation loc, JITFunctionKind kind, JITType return_type,
                            string name, bool is_variadic, JITParam[] params...)
    {
        // Convert to an array of inner pointers.
        gcc_jit_param*[] param_p = new gcc_jit_param*[params.length];
        foreach(i, param; params)
            param_p[i] = param.getParam();

        // Treat the array as being of the underlying pointers, relying on
        // the wrapper type being such a pointer internally.
        auto result = gcc_jit_context_new_function(this.m_inner_ctxt,
                                                   loc ? loc.getLocation() : null,
                                                   kind, return_type.getType(),
                                                   name.toStringz(),
                                                   cast(int)params.length,
                                                   param_p.ptr, is_variadic);
        return new JITFunction(result);
    }

    /// Ditto
    JITFunction newFunction(JITFunctionKind kind, JITType return_type,
                            string name, bool is_variadic, JITParam[] params...)
    {
        return this.newFunction(null, kind, return_type, name, is_variadic, params);
    }

    /// Ditto
    JITFunction newFunction(JITLocation loc, JITFunctionKind kind, JITTypeKind return_kind,
                            string name, bool is_variadic, JITParam[] params...)
    {
        return this.newFunction(loc, kind, this.getType(return_kind),
                                name, is_variadic, params);
    }

    /// Ditto
    JITFunction newFunction(JITFunctionKind kind, JITTypeKind return_kind,
                            string name, bool is_variadic, JITParam[] params...)
    {
        return this.newFunction(null, kind, this.getType(return_kind),
                                name, is_variadic, params);
    }

    ///
    JITLValue newGlobal(JITLocation loc, JITGlobalKind global_kind,
                        JITType type, string name)
    {
        auto result = gcc_jit_context_new_global(this.m_inner_ctxt,
                                                 loc ? loc.getLocation() : null,
                                                 global_kind, type.getType(),
                                                 name.toStringz());
        return new JITLValue(result);
    }

    /// Ditto
    JITLValue newGlobal(JITGlobalKind global_kind, JITType type, string name)
    {
        return this.newGlobal(null, global_kind, type, name);
    }

    /// Ditto
    JITLValue newGlobal(JITLocation loc, JITGlobalKind global_kind,
                        JITTypeKind kind, string name)
    {
        return this.newGlobal(loc, global_kind, this.getType(kind), name);
    }

    /// Ditto
    JITLValue newGlobal(JITGlobalKind global_kind, JITTypeKind kind, string name)
    {
        return this.newGlobal(null, global_kind, this.getType(kind), name);
    }

    /// Given a JITType, which must be a numeric type, get an integer constant
    /// as a JITRValue of that type.
    JITRValue newRValue(JITType type, int value)
    {
        auto result = gcc_jit_context_new_rvalue_from_int(this.m_inner_ctxt,
                                                          type.getType(), value);
        return new JITRValue(result);
    }

    /// Ditto
    JITRValue newRValue(JITTypeKind kind, int value)
    {
        return newRValue(this.getType(kind), value);
    }

    /// Given a JITType, which must be a floating point type, get a floating
    /// point constant as a JITRValue of that type.
    JITRValue newRValue(JITType type, double value)
    {
        auto result = gcc_jit_context_new_rvalue_from_double(this.m_inner_ctxt,
                                                             type.getType(), value);
        return new JITRValue(result);
    }

    /// Ditto
    JITRValue newRValue(JITTypeKind kind, double value)
    {
        return newRValue(this.getType(kind), value);
    }

    /// Given a JITType, which must be a pointer type, and an address, get a
    /// JITRValue representing that address as a pointer of that type.
    JITRValue newRValue(JITType type, void *value)
    {
        auto result = gcc_jit_context_new_rvalue_from_ptr(this.m_inner_ctxt,
                                                          type.getType(), value);
        return new JITRValue(result);
    }

    /// Ditto
    JITRValue newRValue(JITTypeKind kind, void *value)
    {
        return newRValue(this.getType(kind), value);
    }

    /// Make a JITRValue for the given string literal value.
    /// Params:
    ///     value = The string literal.
    JITRValue newRValue(string value)
    {
        auto result = gcc_jit_context_new_string_literal(this.m_inner_ctxt,
                                                         value.toStringz());
        return new JITRValue(result);
    }

    /// Given a JITType, which must be a numeric type, get the constant 0 as a
    /// JITRValue of that type.
    JITRValue zero(JITType type)
    {
        auto result = gcc_jit_context_zero(this.m_inner_ctxt, type.getType());
        return new JITRValue(result);
    }

    /// Ditto
    JITRValue zero(JITTypeKind kind)
    {
        return this.zero(this.getType(kind));
    }

    /// Given a JITType, which must be a numeric type, get the constant 1 as a
    /// JITRValue of that type.
    JITRValue one(JITType type)
    {
        auto result = gcc_jit_context_one(this.m_inner_ctxt, type.getType());
        return new JITRValue(result);
    }

    /// Ditto
    JITRValue one(JITTypeKind kind)
    {
        return this.one(this.getType(kind));
    }

    /// Given a JITType, which must be a pointer type, get a JITRValue
    /// representing the NULL pointer of that type.
    JITRValue nil(JITType type)
    {
        auto result = gcc_jit_context_null(this.m_inner_ctxt, type.getType());
        return new JITRValue(result);
    }

    /// Ditto
    JITRValue nil(JITTypeKind kind)
    {
        return this.nil(this.getType(kind));
    }

    /// Generic unary operations.

    /// Make a JITRValue for the given unary operation.
    /// Params:
    ///     loc  = The source location, if any.
    ///     op   = Which unary operation.
    ///     type = The type of the result.
    ///     a    = The input expression.
    JITRValue newUnaryOp(JITLocation loc, JITUnaryOp op, JITType type, JITRValue a)
    {
        auto result = gcc_jit_context_new_unary_op(this.m_inner_ctxt,
                                                   loc ? loc.getLocation() : null,
                                                   op, type.getType(),
                                                   a.getRValue());
        return new JITRValue(result);
    }

    /// Ditto
    JITRValue newUnaryOp(JITUnaryOp op, JITType type, JITRValue a)
    {
        return this.newUnaryOp(null, op, type, a);
    }

    /// Generic binary operations.

    /// Make a JITRValue for the given binary operation.
    /// Params:
    ///     loc  = The source location, if any.
    ///     op   = Which binary operation.
    ///     type = The type of the result.
    ///     a    = The first input expression.
    ///     b    = The second input expression.
    JITRValue newBinaryOp(JITLocation loc, JITBinaryOp op,
                          JITType type, JITRValue a, JITRValue b)
    {
        auto result = gcc_jit_context_new_binary_op(this.m_inner_ctxt,
                                                    loc ? loc.getLocation() : null,
                                                    op, type.getType(),
                                                    a.getRValue(),
                                                    b.getRValue());
        return new JITRValue(result);
    }

    /// Ditto
    JITRValue newBinaryOp(JITBinaryOp op, JITType type, JITRValue a, JITRValue b)
    {
        return this.newBinaryOp(null, op, type, a, b);
    }

    /// Generic comparisons.

    /// Make a JITRValue of boolean type for the given comparison.
    /// Params:
    ///     loc  = The source location, if any.
    ///     op   = Which comparison.
    ///     a    = The first input expression.
    ///     b    = The second input expression.
    JITRValue newComparison(JITLocation loc, JITComparison op,
                            JITRValue a, JITRValue b)
    {
        auto result = gcc_jit_context_new_comparison(this.m_inner_ctxt,
                                                     loc ? loc.getLocation() : null,
                                                     op, a.getRValue(),
                                                     b.getRValue());
        return new JITRValue(result);
    }

    /// Ditto
    JITRValue newComparison(JITComparison op, JITRValue a, JITRValue b)
    {
        return this.newComparison(null, op, a, b);
    }

    /// The most general way of creating a function call.
    JITRValue newCall(JITLocation loc, JITFunction func, JITRValue[] args...)
    {
        // Convert to an array of inner pointers.
        gcc_jit_rvalue*[] arg_p = new gcc_jit_rvalue*[args.length];
        foreach(i, arg; args)
            arg_p[i] = arg.getRValue();

        // Treat the array as being of the underlying pointers, relying on
        // the wrapper type being such a pointer internally.
        auto result = gcc_jit_context_new_call(this.m_inner_ctxt,
                                               loc ? loc.getLocation() : null,
                                               func.getFunction(),
                                               cast(int)args.length,
                                               arg_p.ptr);
        return new JITRValue(result);
    }

    /// Ditto
    JITRValue newCall(JITFunction func, JITRValue[] args...)
    {
        return this.newCall(null, func, args);
    }

    /// Calling a function through a pointer.
    JITRValue newCall(JITLocation loc, JITRValue ptr, JITRValue[] args...)
    {
        // Convert to an array of inner pointers.
        gcc_jit_rvalue*[] arg_p = new gcc_jit_rvalue*[args.length];
        foreach(i, arg; args)
            arg_p[i] = arg.getRValue();

        // Treat the array as being of the underlying pointers, relying on
        // the wrapper type being such a pointer internally.
        auto result = gcc_jit_context_new_call_through_ptr(this.m_inner_ctxt,
                                                           loc ? loc.getLocation() : null,
                                                           ptr.getRValue(),
                                                           cast(int)args.length,
                                                           arg_p.ptr);
        return new JITRValue(result);
    }

    /// Ditto
    JITRValue newCall(JITRValue ptr, JITRValue[] args...)
    {
        return this.newCall(null, ptr, args);
    }

    /// Type-coercion.
    /// Currently only a limited set of conversions are possible.
    /// int <=> float and int <=> bool.
    JITRValue newCast(JITLocation loc, JITRValue expr, JITType type)
    {
        auto result = gcc_jit_context_new_cast(this.m_inner_ctxt,
                                               loc ? loc.getLocation() : null,
                                               expr.getRValue(), type.getType());
        return new JITRValue(result);
    }

    /// Ditto
    JITRValue newCast(JITRValue expr, JITType type)
    {
        return this.newCast(null, expr, type);
    }

    /// Ditto
    JITRValue newCast(JITLocation loc, JITRValue expr, JITTypeKind kind)
    {
        return this.newCast(loc, expr, this.getType(kind));
    }

    /// Ditto
    JITRValue newCast(JITRValue expr, JITTypeKind kind)
    {
        return this.newCast(null, expr, this.getType(kind));
    }

    /// Accessing an array or pointer through an index.
    /// Params:
    ///     loc   = The source location, if any.
    ///     ptr   = The pointer or array.
    ///     index = The index within the array.
    JITLValue newArrayAccess(JITLocation loc, JITRValue ptr, JITRValue index)
    {
        auto result = gcc_jit_context_new_array_access(this.m_inner_ctxt,
                                                       loc ? loc.getLocation() : null,
                                                       ptr.getRValue(), index.getRValue());
        return new JITLValue(result);
    }

    /// Ditto
    JITLValue newArrayAccess(JITRValue ptr, JITRValue index)
    {
        return this.newArrayAccess(null, ptr, index);
    }

private:
    gcc_jit_context *m_inner_ctxt;
}

/// Class wrapper for gcc_jit_field
class JITField : JITObject
{
    ///
    this()
    {
        super();
    }

    ///
    this(gcc_jit_field *field)
    {
        super(gcc_jit_field_as_object(field));
    }

    /// Returns the internal gcc_jit_field object.
    final gcc_jit_field *getField()
    {
        // Manual downcast.
        return cast(gcc_jit_field *)(this.getObject());
    }
}

/// Types can be created in several ways:
/// $(UL
///     $(LI Fundamental types can be accessed using JITContext.getType())
///     $(LI Derived types can be accessed by calling methods on an existing type.)
///     $(LI By creating structures via JITStruct.)
/// )

class JITType : JITObject
{
    ///
    this()
    {
        super();
    }

    ///
    this(gcc_jit_type *type)
    {
        super(gcc_jit_type_as_object(type));
    }

    /// Returns the internal gcc_jit_type object.
    final gcc_jit_type *getType()
    {
        // Manual downcast.
        return cast(gcc_jit_type *)(this.getObject());
    }

    /// Given type T, get type T*.
    final JITType pointerOf()
    {
        auto result = gcc_jit_type_get_pointer(this.getType());
        return new JITType(result);
    }

    /// Given type T, get type const T.
    final JITType constOf()
    {
        auto result = gcc_jit_type_get_const(this.getType());
        return new JITType(result);
    }

    /// Given type T, get type volatile T.
    final JITType volatileOf()
    {
        auto result = gcc_jit_type_get_volatile(this.getType());
        return new JITType(result);
    }
}

/// You can model C struct types by creating JITStruct and JITField
/// instances, in either order:
/// $(UL
///     $(LI By creating the fields, then the structure.)
///     $(LI By creating the structure, then populating it with fields,
///          typically to allow modelling self-referential structs.)
/// )
class JITStruct : JITType
{
    ///
    this()
    {
        super(null);
    }

    ///
    this(gcc_jit_struct *agg)
    {
        super(gcc_jit_struct_as_type(agg));
    }

    /// Returns the internal gcc_jit_struct object.
    final gcc_jit_struct *getStruct()
    {
        // Manual downcast.
        return cast(gcc_jit_struct *)(this.getObject());
    }

    /// Populate the fields of a formerly-opaque struct type.
    /// This can only be called once on a given struct type.
    final void setFields(JITLocation loc, JITField[] fields...)
    {
        // Convert to an array of inner pointers.
        gcc_jit_field*[] field_p = new gcc_jit_field*[fields.length];
        foreach(i, field; fields)
            field_p[i] = field.getField();

        // Treat the array as being of the underlying pointers, relying on
        // the wrapper type being such a pointer internally.
        gcc_jit_struct_set_fields(this.getStruct(), loc ? loc.getLocation() : null,
                                  cast(int)fields.length, field_p.ptr);
    }

    /// Ditto
    final void setFields(JITField[] fields...)
    {
        this.setFields(null, fields);
    }
}

/// Class wrapper for gcc_jit_function
class JITFunction : JITObject
{
    ///
    this()
    {
        super();
    }

    ///
    this(gcc_jit_function *func)
    {
        if (!func)
            throw new JITError("Unknown error, got bad function");
        super(gcc_jit_function_as_object(func));
    }

    /// Returns the internal gcc_jit_function object.
    final gcc_jit_function *getFunction()
    {
        // Manual downcast.
        return cast(gcc_jit_function *)(this.getObject());
    }

    /// Dump function to dot file.
    final void dump(string path)
    {
        gcc_jit_function_dump_to_dot(this.getFunction(), path.toStringz());
    }

    /// Get a specific param of a function by index.
    final JITParam getParam(int index)
    {
        auto result = gcc_jit_function_get_param(this.getFunction(), index);
        return new JITParam(result);
    }

    /// Create a new JITBlock.
    /// The name can be null, or you can give it a meaningful name, which may
    /// show up in dumps of the internal representation, and in error messages.
    final JITBlock newBlock()
    {
        auto result = gcc_jit_function_new_block(this.getFunction(), null);
        return new JITBlock(result);
    }

    /// Ditto
    final JITBlock newBlock(string name)
    {
        auto result = gcc_jit_function_new_block(this.getFunction(),
                                                 name.toStringz());
        return new JITBlock(result);
    }

    /// Create a new local variable.
    final JITLValue newLocal(JITLocation loc, JITType type, string name)
    {
        auto result = gcc_jit_function_new_local(this.getFunction(),
                                                 loc ? loc.getLocation() : null,
                                                 type.getType(),
                                                 name.toStringz());
        return new JITLValue(result);
    }

    /// Ditto
    final JITLValue newLocal(JITType type, string name)
    {
        return this.newLocal(null, type, name);
    }
}


/// Class wrapper for gcc_jit_block
class JITBlock : JITObject
{
    ///
    this()
    {
        super();
    }

    ///
    this(gcc_jit_block *block)
    {
        super(gcc_jit_block_as_object(block));
    }

    /// Returns the internal gcc_jit_block object.
    final gcc_jit_block *getBlock()
    {
        // Manual downcast.
        return cast(gcc_jit_block *)(this.getObject());
    }

    /// Returns the JITFunction this JITBlock is within.
    final JITFunction getFunction()
    {
        auto result = gcc_jit_block_get_function(this.getBlock());
        return new JITFunction(result);
    }

    /// Add evaluation of an rvalue, discarding the result.
    final void addEval(JITLocation loc, JITRValue rvalue)
    {
        gcc_jit_block_add_eval(this.getBlock(),
                               loc ? loc.getLocation() : null,
                               rvalue.getRValue());
    }

    /// Ditto
    final void addEval(JITRValue rvalue)
    {
        return this.addEval(null, rvalue);
    }

    /// Add evaluation of an rvalue, assigning the result to the given lvalue.
    /// This is equivalent to "lvalue = rvalue".
    final void addAssignment(JITLocation loc, JITLValue lvalue, JITRValue rvalue)
    {
        gcc_jit_block_add_assignment(this.getBlock(),
                                     loc ? loc.getLocation() : null,
                                     lvalue.getLValue(), rvalue.getRValue());
    }

    /// Ditto
    final void addAssignment(JITLValue lvalue, JITRValue rvalue)
    {
        return this.addAssignment(null, lvalue, rvalue);
    }

    /// Add evaluation of an rvalue, using the result to modify an lvalue.
    /// This is equivalent to "lvalue op= rvalue".
    final void addAssignmentOp(JITLocation loc, JITLValue lvalue,
                         JITBinaryOp op, JITRValue rvalue)
    {
        gcc_jit_block_add_assignment_op(this.getBlock(),
                                        loc ? loc.getLocation() : null,
                                        lvalue.getLValue(), op, rvalue.getRValue());
    }

    /// Ditto
    final void addAssignmentOp(JITLValue lvalue, JITBinaryOp op, JITRValue rvalue)
    {
        return this.addAssignmentOp(null, lvalue, op, rvalue);
    }

    /// A way to add a function call to the body of a function being
    /// defined, with various number of args.
    final JITRValue addCall(JITLocation loc, JITFunction func, JITRValue[] args...)
    {
        JITRValue rv = this.getContext().newCall(loc, func, args);
        this.addEval(loc, rv);
        return rv;
    }

    /// Ditto
    final JITRValue addCall(JITFunction func, JITRValue[] args...)
    {
        return this.addCall(null, func, args);
    }

    /// Add a no-op textual comment to the internal representation of the code.
    /// It will be optimized away, but visible in the dumps seens via
    /// JITBoolOption.DUMP_INITIAL_TREE and JITBoolOption.DUMP_INITIAL_GIMPLE.
    final void addComment(JITLocation loc, string text)
    {
        gcc_jit_block_add_comment(this.getBlock(),
                                  loc ? loc.getLocation() : null,
                                  text.toStringz());
    }

    /// Ditto
    final void addComment(string text)
    {
        return this.addComment(null, text);
    }

    /// Terminate a block by adding evaluation of an rvalue, branching on the
    /// result to the appropriate successor block.
    final void endWithConditional(JITLocation loc, JITRValue val,
                            JITBlock on_true, JITBlock on_false)
    {
        gcc_jit_block_end_with_conditional(this.getBlock(),
                                           loc ? loc.getLocation() : null,
                                           val.getRValue(),
                                           on_true.getBlock(),
                                           on_false.getBlock());
    }

    /// Ditto
    final void endWithConditional(JITRValue val, JITBlock on_true, JITBlock on_false)
    {
        return this.endWithConditional(null, val, on_true, on_false);
    }

    /// Terminate a block by adding a jump to the given target block.
    /// This is equivalent to "goto target".
    final void endWithJump(JITLocation loc, JITBlock target)
    {
        gcc_jit_block_end_with_jump(this.getBlock(),
                                    loc ? loc.getLocation() : null,
                                    target.getBlock());
    }

    /// Ditto
    final void endWithJump(JITBlock target)
    {
        return this.endWithJump(null, target);
    }

    /// Terminate a block by adding evaluation of an rvalue, returning the value.
    /// This is equivalent to "return rvalue".
    final void endWithReturn(JITLocation loc, JITRValue rvalue)
    {
        gcc_jit_block_end_with_return(this.getBlock(),
                                      loc ? loc.getLocation() : null,
                                      rvalue.getRValue());
    }

    /// Ditto
    final void endWithReturn(JITRValue rvalue)
    {
        return this.endWithReturn(null, rvalue);
    }

    /// Terminate a block by adding a valueless return, for use within a
    /// function with "void" return type.
    /// This is equivalent to "return".
    final void endWithReturn(JITLocation loc = null)
    {
        gcc_jit_block_end_with_void_return(this.getBlock(),
                                           loc ? loc.getLocation() : null);
    }
}

/// Class wrapper for gcc_jit_rvalue
class JITRValue : JITObject
{
    ///
    this()
    {
        super();
    }

    ///
    this(gcc_jit_rvalue *rvalue)
    {
        if (!rvalue)
            throw new JITError("Unknown error, got bad rvalue");
        super(gcc_jit_rvalue_as_object(rvalue));
    }

    /// Returns the internal gcc_jit_rvalue object.
    final gcc_jit_rvalue *getRValue()
    {
        // Manual downcast.
        return cast(gcc_jit_rvalue *)(this.getObject());
    }

    /// Returns the JITType of the rvalue.
    final JITType getType()
    {
        auto result = gcc_jit_rvalue_get_type(this.getRValue());
        return new JITType(result);
    }

    /// Accessing a field of an rvalue of struct type.
    /// This is equivalent to "(value).field".
    JITRValue accessField(JITLocation loc, JITField field)
    {
        auto result = gcc_jit_rvalue_access_field(this.getRValue(),
                                                  loc ? loc.getLocation() : null,
                                                  field.getField());
        return new JITRValue(result);
    }

    /// Ditto
    JITRValue accessField(JITField field)
    {
        return this.accessField(null, field);
    }

    /// Accessing a field of an rvalue of pointer type.
    /// This is equivalent to "(*value).field".
    final JITLValue dereferenceField(JITLocation loc, JITField field)
    {
        auto result = gcc_jit_rvalue_dereference_field(this.getRValue(),
                                                       loc ? loc.getLocation() : null,
                                                       field.getField());
        return new JITLValue(result);
    }

    /// Ditto
    final JITLValue dereferenceField(JITField field)
    {
        return this.dereferenceField(null, field);
    }

    /// Dereferencing an rvalue of pointer type.
    /// This is equivalent to "*(value)".
    final JITLValue dereference(JITLocation loc = null)
    {
        auto result = gcc_jit_rvalue_dereference(this.getRValue(),
                                                 loc ? loc.getLocation() : null);
        return new JITLValue(result);
    }

    /// Convert an rvalue to the given JITType.  See JITContext.newCast for
    /// limitations.
    final JITRValue castTo(JITLocation loc, JITType type)
    {
        return this.getContext().newCast(loc, this, type);
    }

    /// Ditto
    final JITRValue castTo(JITType type)
    {
        return this.castTo(null, type);
    }

    /// Ditto
    final JITRValue castTo(JITLocation loc, JITTypeKind kind)
    {
        return this.castTo(loc, this.getContext().getType(kind));
    }

    /// Ditto
    final JITRValue castTo(JITTypeKind kind)
    {
        return this.castTo(null, this.getContext().getType(kind));
    }
}

/// Class wrapper for gcc_jit_lvalue
class JITLValue : JITRValue
{
    ///
    this()
    {
        super();
    }

    ///
    this(gcc_jit_lvalue *lvalue)
    {
        if (!lvalue)
            throw new JITError("Unknown error, got bad lvalue");
        super(gcc_jit_lvalue_as_rvalue(lvalue));
    }

    /// Returns the internal gcc_jit_lvalue object.
    final gcc_jit_lvalue *getLValue()
    {
        // Manual downcast.
        return cast(gcc_jit_lvalue *)(this.getObject());
    }

    /// Accessing a field of an lvalue of struct type.
    /// This is equivalent to "(value).field = ...".
    override JITLValue accessField(JITLocation loc, JITField field)
    {
        auto result = gcc_jit_lvalue_access_field(this.getLValue(),
                                                  loc ? loc.getLocation() : null,
                                                  field.getField());
        return new JITLValue(result);
    }

    /// Ditto
    override JITLValue accessField(JITField field)
    {
        return this.accessField(null, field);
    }

    /// Taking the address of an lvalue.
    /// This is equivalent to "&(value)".
    final JITRValue getAddress(JITLocation loc = null)
    {
        auto result = gcc_jit_lvalue_get_address(this.getLValue(),
                                                 loc ? loc.getLocation() : null);
        return new JITRValue(result);
    }
}

/// Class wrapper for gcc_jit_param
class JITParam : JITLValue
{
    ///
    this()
    {
        super();
    }

    ///
    this(gcc_jit_param *param)
    {
        if (!param)
            throw new JITError("Unknown error, got bad param");
        super(gcc_jit_param_as_lvalue(param));
    }

    /// Returns the internal gcc_jit_param object.
    final gcc_jit_param *getParam()
    {
        // Manual downcast.
        return cast(gcc_jit_param *)(this.getObject());
    }
}

/// Class wrapper for gcc_jit_result
final class JITResult
{
    ///
    this()
    {
        this.m_inner_result = null;
    }

    ///
    this(gcc_jit_result *result)
    {
        if (!result)
            throw new JITError("Unknown error, got bad result");
        this.m_inner_result = result;
    }

    /// Returns the internal gcc_jit_result object.
    gcc_jit_result *getResult()
    {
        return this.m_inner_result;
    }

    /// Locate a given function within the built machine code.
    /// This will need to be cast to a function pointer of the correct type
    /// before it can be called.
    void *getCode(string name)
    {
        return gcc_jit_result_get_code(this.getResult(), name.toStringz());
    }

    /// Locate a given global within the built machine code.
    /// It must have been created using JITGlobalKind.EXPORTED.
    /// This returns is a pointer to the global.
    void *getGlobal(string name)
    {
        return gcc_jit_result_get_global(this.getResult(), name.toStringz());
    }

    /// Once we're done with the code, this unloads the built .so file.
    /// After this call, it's no longer valid to use this JITResult.
    void release()
    {
        gcc_jit_result_release(this.getResult());
    }

private:
    gcc_jit_result *m_inner_result;
}

/// Kinds of function.
enum JITFunctionKind : gcc_jit_function_kind
{
    /// Function is defined by the client code and visible by name
    /// outside of the JIT.
    EXPORTED = GCC_JIT_FUNCTION_EXPORTED,
    /// Function is defined by the client code, but is invisible
    /// outside of the JIT.
    INTERNAL = GCC_JIT_FUNCTION_INTERNAL,
    /// Function is not defined by the client code; we're merely
    /// referring to it.
    IMPORTED = GCC_JIT_FUNCTION_IMPORTED,
    /// Function is only ever inlined into other functions, and is
    /// invisible outside of the JIT.
    ALWAYS_INLINE = GCC_JIT_FUNCTION_ALWAYS_INLINE,
}

/// Kinds of global.
enum JITGlobalKind : gcc_jit_global_kind
{
  /// Global is defined by the client code and visible by name
  /// outside of this JIT context.
  EXPORTED = GCC_JIT_GLOBAL_EXPORTED,
  /// Global is defined by the client code, but is invisible
  /// outside of this JIT context.  Analogous to a "static" global.
  INTERNAL = GCC_JIT_GLOBAL_INTERNAL,
  /// Global is not defined by the client code; we're merely
  /// referring to it.  Analogous to using an "extern" global.
  IMPORTED = GCC_JIT_GLOBAL_IMPORTED,
}

/// Standard types.
enum JITTypeKind : gcc_jit_types
{
    /// C's void type.
    VOID = GCC_JIT_TYPE_VOID,

    /// C's void* type.
    VOID_PTR = GCC_JIT_TYPE_VOID_PTR,

    /// C++'s bool type.
    BOOL = GCC_JIT_TYPE_BOOL,

    /// C's char type.
    CHAR = GCC_JIT_TYPE_CHAR,

    /// C's signed char type.
    SIGNED_CHAR = GCC_JIT_TYPE_SIGNED_CHAR,

    /// C's unsigned char type.
    UNSIGNED_CHAR = GCC_JIT_TYPE_UNSIGNED_CHAR,

    /// C's short type.
    SHORT = GCC_JIT_TYPE_SHORT,

    /// C's unsigned short type.
    UNSIGNED_SHORT = GCC_JIT_TYPE_UNSIGNED_SHORT,

    /// C's int type.
    INT = GCC_JIT_TYPE_INT,

    /// C's unsigned int type.
    UNSIGNED_INT = GCC_JIT_TYPE_UNSIGNED_INT,

    /// C's long type.
    LONG = GCC_JIT_TYPE_LONG,

    /// C's unsigned long type.
    UNSIGNED_LONG = GCC_JIT_TYPE_UNSIGNED_LONG,

    /// C99's long long type.
    LONG_LONG = GCC_JIT_TYPE_LONG_LONG,

    /// C99's unsigned long long type.
    UNSIGNED_LONG_LONG = GCC_JIT_TYPE_UNSIGNED_LONG_LONG,

    /// Single precision floating point type.
    FLOAT = GCC_JIT_TYPE_FLOAT,

    /// Double precision floating point type.
    DOUBLE = GCC_JIT_TYPE_DOUBLE,

    /// Largest supported floating point type.
    LONG_DOUBLE = GCC_JIT_TYPE_LONG_DOUBLE,

    /// C's const char* type.
    CONST_CHAR_PTR = GCC_JIT_TYPE_CONST_CHAR_PTR,

    /// C's usize type.
    SIZE_T = GCC_JIT_TYPE_SIZE_T,

    /// C's FILE* type.
    FILE_PTR = GCC_JIT_TYPE_FILE_PTR,

    /// Single precision complex float type.
    COMPLEX_FLOAT = GCC_JIT_TYPE_COMPLEX_FLOAT,

    /// Double precision complex float type.
    COMPLEX_DOUBLE = GCC_JIT_TYPE_COMPLEX_DOUBLE,

    /// Largest supported complex float type.
    COMPLEX_LONG_DOUBLE = GCC_JIT_TYPE_COMPLEX_LONG_DOUBLE,
}

/// Kinds of unary ops.
enum JITUnaryOp : gcc_jit_unary_op
{
    /// Negate an arithmetic value.
    /// This is equivalent to "-(value)".
    MINUS = GCC_JIT_UNARY_OP_MINUS,
    /// Bitwise negation of an integer value (one's complement).
    /// This is equivalent to "~(value)".
    BITWISE_NEGATE = GCC_JIT_UNARY_OP_BITWISE_NEGATE,
    /// Logical negation of an arithmetic or pointer value.
    /// This is equivalent to "!(value)".
    LOGICAL_NEGATE = GCC_JIT_UNARY_OP_LOGICAL_NEGATE,
}

/// Kinds of binary ops.
enum JITBinaryOp : gcc_jit_binary_op
{
    /// Addition of arithmetic values.
    /// This is equivalent to "(a) + (b)".
    PLUS = GCC_JIT_BINARY_OP_PLUS,
    /// Subtraction of arithmetic values.
    /// This is equivalent to "(a) - (b)".
    MINUS = GCC_JIT_BINARY_OP_MINUS,
    /// Multiplication of a pair of arithmetic values.
    /// This is equivalent to "(a) * (b)".
    MULT = GCC_JIT_BINARY_OP_MULT,
    /// Quotient of division of arithmetic values.
    /// This is equivalent to "(a) / (b)".
    DIVIDE = GCC_JIT_BINARY_OP_DIVIDE,
    /// Remainder of division of arithmetic values.
    /// This is equivalent to "(a) % (b)".
    MODULO = GCC_JIT_BINARY_OP_MODULO,
    /// Bitwise AND.
    /// This is equivalent to "(a) & (b)".
    BITWISE_AND = GCC_JIT_BINARY_OP_BITWISE_AND,
    /// Bitwise exclusive OR.
    /// This is equivalent to "(a) ^ (b)".
    BITWISE_XOR = GCC_JIT_BINARY_OP_BITWISE_XOR,
    /// Bitwise inclusive OR.
    /// This is equivalent to "(a) | (b)".
    BITWISE_OR = GCC_JIT_BINARY_OP_BITWISE_OR,
    /// Logical AND.
    /// This is equivalent to "(a) && (b)".
    LOGICAL_AND = GCC_JIT_BINARY_OP_LOGICAL_AND,
    /// Logical OR.
    /// This is equivalent to "(a) || (b)".
    LOGICAL_OR = GCC_JIT_BINARY_OP_LOGICAL_OR,
    /// Left shift.
    /// This is equivalent to "(a) << (b)".
    LSHIFT = GCC_JIT_BINARY_OP_LSHIFT,
    /// Right shift.
    /// This is equivalent to "(a) >> (b)".
    RSHIFT = GCC_JIT_BINARY_OP_RSHIFT,
}

/// Kinds of comparison.
enum JITComparison : gcc_jit_comparison
{
    /// This is equivalent to "(a) == (b)".
    EQ = GCC_JIT_COMPARISON_EQ,
    /// This is equivalent to "(a) != (b)".
    NE = GCC_JIT_COMPARISON_NE,
    /// This is equivalent to "(a) < (b)".
    LT = GCC_JIT_COMPARISON_LT,
    /// This is equivalent to "(a) <= (b)".
    LE = GCC_JIT_COMPARISON_LE,
    /// This is equivalent to "(a) > (b)".
    GT = GCC_JIT_COMPARISON_GT,
    /// This is equivalent to "(a) >= (b)".
    GE = GCC_JIT_COMPARISON_GE,
}

/// String options
enum JITStrOption : gcc_jit_str_option
{
    /// The name of the program, for use as a prefix when printing error
    /// messages to stderr. If None, or default, "libgccjit.so" is used.
    PROGNAME = GCC_JIT_STR_OPTION_PROGNAME,
}

/// Integer options
enum JITIntOption : gcc_jit_int_option
{
    /// How much to optimize the code.

    /// Valid values are 0-3, corresponding to GCC's command-line options
    /// -O0 through -O3.

    /// The default value is 0 (unoptimized).
    OPTIMIZATION_LEVEL = GCC_JIT_INT_OPTION_OPTIMIZATION_LEVEL,
}

/// Boolean options
enum JITBoolOption : gcc_jit_bool_option
{
    /// If true, JITContext.compile() will attempt to do the right thing
    /// so that if you attach a debugger to the process, it will be able
    /// to inspect variables and step through your code.

    /// Note that you can’t step through code unless you set up source
    /// location information for the code (by creating and passing in
    /// JITLocation instances).
    DEBUGINFO = GCC_JIT_BOOL_OPTION_DEBUGINFO,

    /// If true, JITContext.compile() will dump its initial "tree"
    /// representation of your code to stderr, before any optimizations.
    DUMP_INITIAL_TREE = GCC_JIT_BOOL_OPTION_DUMP_INITIAL_TREE,

    /// If true, JITContext.compile() will dump its initial "gimple"
    /// representation of your code to stderr, before any optimizations
    /// are performed. The dump resembles C code.
    DUMP_INITIAL_GIMPLE = GCC_JIT_BOOL_OPTION_DUMP_INITIAL_GIMPLE,

    /// If true, JITContext.compile() will dump the final generated code
    /// to stderr, in the form of assembly language.
    DUMP_GENERATED_CODE = GCC_JIT_BOOL_OPTION_DUMP_GENERATED_CODE,

    /// If true, JITContext.compile() will print information to stderr
    /// on the actions it is performing, followed by a profile showing
    /// the time taken and memory usage of each phase.
    DUMP_SUMMARY = GCC_JIT_BOOL_OPTION_DUMP_SUMMARY,

    /// If true, JITContext.compile() will dump copious amounts of
    /// information on what it’s doing to various files within a
    /// temporary directory. Use JITBoolOption.KEEP_INTERMEDIATES
    /// to see the results. The files are intended to be human-readable,
    /// but the exact files and their formats are subject to change.
    DUMP_EVERYTHING = GCC_JIT_BOOL_OPTION_DUMP_EVERYTHING,

    /// If true, libgccjit will aggressively run its garbage collector,
    /// to shake out bugs (greatly slowing down the compile). This is
    /// likely to only be of interest to developers of the library.
    SELFCHECK_GC = GCC_JIT_BOOL_OPTION_SELFCHECK_GC,

    /// If true, the JITContext will not clean up intermediate files
    /// written to the filesystem, and will display their location on
    /// stderr.
    KEEP_INTERMEDIATES = GCC_JIT_BOOL_OPTION_KEEP_INTERMEDIATES,
}



/* A pure C API to enable client code to embed GCC as a JIT-compiler.

   This file has been modified from the libgccjit.h header to work with
   the D compiler.  The original file is part of the GCC distribution
   and is licensed under the following terms.

   Copyright (C) 2013-2015 Free Software Foundation, Inc.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, version 3 of the License ONLY.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import core.stdc.stdio;

extern(C):

/**********************************************************************
 Data structures.
 **********************************************************************/
/* All structs within the API are opaque. */

/* A gcc_jit_context encapsulates the state of a compilation.
   You can set up options on it, and add types, functions and code, using
   the API below.

   Invoking gcc_jit_context_compile on it gives you a gcc_jit_result *
   (or NULL), representing in-memory machine code.

   You can call gcc_jit_context_compile repeatedly on one context, giving
   multiple independent results.

   Similarly, you can call gcc_jit_context_compile_to_file on a context
   to compile to disk.

   Eventually you can call gcc_jit_context_release to clean up the
   context; any in-memory results created from it are still usable, and
   should be cleaned up via gcc_jit_result_release.  */
struct gcc_jit_context;

/* A gcc_jit_result encapsulates the result of an in-memory compilation.  */
struct gcc_jit_result;

/* An object created within a context.  Such objects are automatically
   cleaned up when the context is released.

   The class hierarchy looks like this:

     +- gcc_jit_object
         +- gcc_jit_location
         +- gcc_jit_type
            +- gcc_jit_struct
         +- gcc_jit_field
         +- gcc_jit_function
         +- gcc_jit_block
         +- gcc_jit_rvalue
             +- gcc_jit_lvalue
                 +- gcc_jit_param
*/
struct gcc_jit_object;

/* A gcc_jit_location encapsulates a source code location, so that
   you can (optionally) associate locations in your language with
   statements in the JIT-compiled code, allowing the debugger to
   single-step through your language.

   Note that to do so, you also need to enable
     GCC_JIT_BOOL_OPTION_DEBUGINFO
   on the gcc_jit_context.

   gcc_jit_location instances are optional; you can always pass
   NULL.  */
struct gcc_jit_location;

/* A gcc_jit_type encapsulates a type e.g. "int" or a "struct foo*".  */
struct gcc_jit_type;

/* A gcc_jit_field encapsulates a field within a struct; it is used
   when creating a struct type (using gcc_jit_context_new_struct_type).
   Fields cannot be shared between structs.  */
struct gcc_jit_field;

/* A gcc_jit_struct encapsulates a struct type, either one that we have
   the layout for, or an opaque type.  */
struct gcc_jit_struct;

/* A gcc_jit_function encapsulates a function: either one that you're
   creating yourself, or a reference to one that you're dynamically
   linking to within the rest of the process.  */
struct gcc_jit_function;

/* A gcc_jit_block encapsulates a "basic block" of statements within a
   function (i.e. with one entry point and one exit point).

   Every block within a function must be terminated with a conditional,
   a branch, or a return.

   The blocks within a function form a directed graph.

   The entrypoint to the function is the first block created within
   it.

   All of the blocks in a function must be reachable via some path from
   the first block.

   It's OK to have more than one "return" from a function (i.e. multiple
   blocks that terminate by returning).  */
struct gcc_jit_block;

/* A gcc_jit_rvalue is an expression within your code, with some type.  */
struct gcc_jit_rvalue;

/* A gcc_jit_lvalue is a storage location within your code (e.g. a
   variable, a parameter, etc).  It is also a gcc_jit_rvalue; use
   gcc_jit_lvalue_as_rvalue to cast.  */
struct gcc_jit_lvalue;

/* A gcc_jit_param is a function parameter, used when creating a
   gcc_jit_function.  It is also a gcc_jit_lvalue (and thus also an
   rvalue); use gcc_jit_param_as_lvalue to convert.  */
struct gcc_jit_param;

/* Acquire a JIT-compilation context.  */
gcc_jit_context *gcc_jit_context_acquire();

/* Release the context.  After this call, it's no longer valid to use
   the ctxt.  */
void gcc_jit_context_release(gcc_jit_context *ctxt);

/* Options taking string values. */
alias gcc_jit_str_option = uint;
enum : gcc_jit_str_option
{
    /* The name of the program, for use as a prefix when printing error
       messages to stderr.  If NULL, or default, "libgccjit.so" is used.  */
    GCC_JIT_STR_OPTION_PROGNAME,

    GCC_JIT_NUM_STR_OPTIONS
}

/* Options taking int values. */
alias gcc_jit_int_option = uint;
enum : gcc_jit_int_option
{
    /* How much to optimize the code.
       Valid values are 0-3, corresponding to GCC's command-line options
       -O0 through -O3.

       The default value is 0 (unoptimized).  */
    GCC_JIT_INT_OPTION_OPTIMIZATION_LEVEL,

    GCC_JIT_NUM_INT_OPTIONS
}

/* Options taking boolean values.
   These all default to "false".  */
alias gcc_jit_bool_option = uint;
enum : gcc_jit_bool_option
{
    /* If true, gcc_jit_context_compile will attempt to do the right
       thing so that if you attach a debugger to the process, it will
       be able to inspect variables and step through your code.

       Note that you can't step through code unless you set up source
       location information for the code (by creating and passing in
       gcc_jit_location instances).  */
    GCC_JIT_BOOL_OPTION_DEBUGINFO,

    /* If true, gcc_jit_context_compile will dump its initial "tree"
       representation of your code to stderr (before any
       optimizations).  */
    GCC_JIT_BOOL_OPTION_DUMP_INITIAL_TREE,

    /* If true, gcc_jit_context_compile will dump the "gimple"
       representation of your code to stderr, before any optimizations
       are performed.  The dump resembles C code.  */
    GCC_JIT_BOOL_OPTION_DUMP_INITIAL_GIMPLE,

    /* If true, gcc_jit_context_compile will dump the final
       generated code to stderr, in the form of assembly language.  */
    GCC_JIT_BOOL_OPTION_DUMP_GENERATED_CODE,

    /* If true, gcc_jit_context_compile will print information to stderr
       on the actions it is performing, followed by a profile showing
       the time taken and memory usage of each phase.
     */
    GCC_JIT_BOOL_OPTION_DUMP_SUMMARY,

    /* If true, gcc_jit_context_compile will dump copious
       amount of information on what it's doing to various
       files within a temporary directory.  Use
       GCC_JIT_BOOL_OPTION_KEEP_INTERMEDIATES (see below) to
       see the results.  The files are intended to be human-readable,
       but the exact files and their formats are subject to change.
     */
    GCC_JIT_BOOL_OPTION_DUMP_EVERYTHING,

    /* If true, libgccjit will aggressively run its garbage collector, to
       shake out bugs (greatly slowing down the compile).  This is likely
       to only be of interest to developers *of* the library.  It is
       used when running the selftest suite.  */
    GCC_JIT_BOOL_OPTION_SELFCHECK_GC,

    /* If true, gcc_jit_context_release will not clean up
       intermediate files written to the filesystem, and will display
       their location on stderr.  */
    GCC_JIT_BOOL_OPTION_KEEP_INTERMEDIATES,

    GCC_JIT_NUM_BOOL_OPTIONS
}

/* Set a string option on the given context.

   The context directly stores the (const char *), so the passed string
   must outlive the context.  */
void gcc_jit_context_set_str_option(gcc_jit_context *ctxt,
                                    gcc_jit_str_option opt,
                                    in char *value);

/* Set an int option on the given context.  */
void gcc_jit_context_set_int_option(gcc_jit_context *ctxt,
                                    gcc_jit_int_option opt,
                                    int value);

/* Set a boolean option on the given context.

   Zero is "false" (the default), non-zero is "true".  */
void gcc_jit_context_set_bool_option(gcc_jit_context *ctxt,
                                     gcc_jit_bool_option opt,
                                     int value);

/* Compile the context to in-memory machine code.

   This can be called more that once on a given context,
   although any errors that occur will block further compilation.  */

gcc_jit_result *gcc_jit_context_compile(gcc_jit_context *ctxt);

/* Kinds of ahead-of-time compilation, for use with
   gcc_jit_context_compile_to_file.  */

alias gcc_jit_output_kind = uint;
enum : gcc_jit_output_kind
{
    /* Compile the context to an assembler file.  */
    GCC_JIT_OUTPUT_KIND_ASSEMBLER,

    /* Compile the context to an object file.  */
    GCC_JIT_OUTPUT_KIND_OBJECT_FILE,

    /* Compile the context to a dynamic library.  */
    GCC_JIT_OUTPUT_KIND_DYNAMIC_LIBRARY,

    /* Compile the context to an executable.  */
    GCC_JIT_OUTPUT_KIND_EXECUTABLE
}

/* Compile the context to a file of the given kind.

   This can be called more that once on a given context,
   although any errors that occur will block further compilation.  */

void gcc_jit_context_compile_to_file(gcc_jit_context *ctxt,
                                     gcc_jit_output_kind output_kind,
                                     in char *output_path);

/* To help with debugging: dump a C-like representation to the given path,
   describing what's been set up on the context.

   If "update_locations" is true, then also set up gcc_jit_location
   information throughout the context, pointing at the dump file as if it
   were a source file.  This may be of use in conjunction with
   GCC_JIT_BOOL_OPTION_DEBUGINFO to allow stepping through the code in a
   debugger.  */
void gcc_jit_context_dump_to_file(gcc_jit_context *ctxt,
                                  in char *path,
                                  int update_locations);

/* To help with debugging; enable ongoing logging of the context's
   activity to the given FILE *.

   The caller remains responsible for closing "logfile".

   Params "flags" and "verbosity" are reserved for future use, and
   must both be 0 for now.  */
void gcc_jit_context_set_logfile(gcc_jit_context *ctxt,
                                 FILE *logfile,
                                 int flags,
                                 int verbosity);

/* To be called after any API call, this gives the first error message
   that occurred on the context.

   The returned string is valid for the rest of the lifetime of the
   context.

   If no errors occurred, this will be NULL.  */
const(char) *gcc_jit_context_get_first_error(gcc_jit_context *ctxt);

/* To be called after any API call, this gives the last error message
   that occurred on the context.

   If no errors occurred, this will be NULL.

   If non-NULL, the returned string is only guaranteed to be valid until
   the next call to libgccjit relating to this context. */
const(char) *gcc_jit_context_get_last_error(gcc_jit_context *ctxt);

/* Locate a given function within the built machine code.
   This will need to be cast to a function pointer of the
   correct type before it can be called. */
void *gcc_jit_result_get_code(gcc_jit_result *result,
                              in char *funcname);

/* Locate a given global within the built machine code.
   It must have been created using GCC_JIT_GLOBAL_EXPORTED.
   This is a ptr to the global, so e.g. for an int this is an int *.  */
void *gcc_jit_result_get_global (gcc_jit_result *result,
                                 in char *name);

/* Once we're done with the code, this unloads the built .so file.
   This cleans up the result; after calling this, it's no longer
   valid to use the result.  */
void gcc_jit_result_release(gcc_jit_result *result);


/**********************************************************************
 Functions for creating "contextual" objects.

 All objects created by these functions share the lifetime of the context
 they are created within, and are automatically cleaned up for you when
 you call gcc_jit_context_release on the context.

 Note that this means you can't use references to them after you've
 released their context.

 All (const char *) string arguments passed to these functions are
 copied, so you don't need to keep them around.  Note that this *isn't*
 the case for other parts of the API.

 You create code by adding a sequence of statements to blocks.
**********************************************************************/

/**********************************************************************
 The base class of "contextual" object.
 **********************************************************************/
/* Which context is "obj" within?  */
gcc_jit_context *gcc_jit_object_get_context(gcc_jit_object *obj);

/* Get a human-readable description of this object.
   The string buffer is created the first time this is called on a given
   object, and persists until the object's context is released.  */
const(char) *gcc_jit_object_get_debug_string(gcc_jit_object *obj);

/**********************************************************************
 Debugging information.
 **********************************************************************/

/* Creating source code locations for use by the debugger.
   Line and column numbers are 1-based.  */
gcc_jit_location *gcc_jit_context_new_location(gcc_jit_context *ctxt,
                                               in char *filename,
                                               int line,
                                               int column);

/* Upcasting from location to object.  */
gcc_jit_object *gcc_jit_location_as_object(gcc_jit_location *loc);


/**********************************************************************
 Types.
 **********************************************************************/

/* Upcasting from type to object.  */
gcc_jit_object *gcc_jit_type_as_object(gcc_jit_type *type);

/* Access to specific types.  */
alias gcc_jit_types = uint;
enum : gcc_jit_types
{
    /* C's "void" type.  */
    GCC_JIT_TYPE_VOID,

    /* "void *".  */
    GCC_JIT_TYPE_VOID_PTR,

    /* C++'s bool type; also C99's "_Bool" type, aka "bool" if using
       stdbool.h.  */
    GCC_JIT_TYPE_BOOL,

    /* Various integer types.  */

    /* C's "char" (of some signedness) and the variants where the
       signedness is specified.  */
    GCC_JIT_TYPE_CHAR,
    GCC_JIT_TYPE_SIGNED_CHAR,
    GCC_JIT_TYPE_UNSIGNED_CHAR,

    /* C's "short" and "unsigned short".  */
    GCC_JIT_TYPE_SHORT, /* signed */
    GCC_JIT_TYPE_UNSIGNED_SHORT,

    /* C's "int" and "unsigned int".  */
    GCC_JIT_TYPE_INT, /* signed */
    GCC_JIT_TYPE_UNSIGNED_INT,

    /* C's "long" and "unsigned long".  */
    GCC_JIT_TYPE_LONG, /* signed */
    GCC_JIT_TYPE_UNSIGNED_LONG,

    /* C99's "long long" and "unsigned long long".  */
    GCC_JIT_TYPE_LONG_LONG, /* signed */
    GCC_JIT_TYPE_UNSIGNED_LONG_LONG,

    /* Floating-point types  */

    GCC_JIT_TYPE_FLOAT,
    GCC_JIT_TYPE_DOUBLE,
    GCC_JIT_TYPE_LONG_DOUBLE,

    /* C type: (const char *).  */
    GCC_JIT_TYPE_CONST_CHAR_PTR,

    /* The C "usize" type.  */
    GCC_JIT_TYPE_SIZE_T,

    /* C type: (FILE *)  */
    GCC_JIT_TYPE_FILE_PTR,

    /* Complex numbers.  */
    GCC_JIT_TYPE_COMPLEX_FLOAT,
    GCC_JIT_TYPE_COMPLEX_DOUBLE,
    GCC_JIT_TYPE_COMPLEX_LONG_DOUBLE
}

gcc_jit_type *gcc_jit_context_get_type(gcc_jit_context *ctxt,
                                       gcc_jit_types type_);

gcc_jit_type *gcc_jit_context_get_int_type(gcc_jit_context *ctxt,
                                           int num_bytes, int is_signed);

/* Constructing new types. */

/* Given type "T", get type "T*".  */
gcc_jit_type *gcc_jit_type_get_pointer(gcc_jit_type *type);

/* Given type "T", get type "const T".  */
gcc_jit_type *gcc_jit_type_get_const(gcc_jit_type *type);

/* Given type "T", get type "volatile T".  */
gcc_jit_type *gcc_jit_type_get_volatile(gcc_jit_type *type);

/* Given type "T", get type "T[N]" (for a constant N).  */
gcc_jit_type *gcc_jit_context_new_array_type(gcc_jit_context *ctxt,
                                             gcc_jit_location *loc,
                                             gcc_jit_type *element_type,
                                             int num_elements);

/* Struct-handling.  */
gcc_jit_field *gcc_jit_context_new_field(gcc_jit_context *ctxt,
                                         gcc_jit_location *loc,
                                         gcc_jit_type *type,
                                         in char *name);

/* Upcasting from field to object.  */
gcc_jit_object *gcc_jit_field_as_object(gcc_jit_field *field);

/* Create a struct type from an array of fields.  */
gcc_jit_struct *gcc_jit_context_new_struct_type(gcc_jit_context *ctxt,
                                                gcc_jit_location *loc,
                                                in char *name,
                                                int num_fields,
                                                gcc_jit_field **fields);


/* Create an opaque struct type.  */
gcc_jit_struct *gcc_jit_context_new_opaque_struct(gcc_jit_context *ctxt,
                                                  gcc_jit_location *loc,
                                                  in char *name);

/* Upcast a struct to a type.  */
gcc_jit_type *gcc_jit_struct_as_type(gcc_jit_struct *struct_type);

/* Populating the fields of a formerly-opaque struct type.
   This can only be called once on a given struct type.  */
void gcc_jit_struct_set_fields(gcc_jit_struct *struct_type,
                               gcc_jit_location *loc,
                               int num_fields,
                               gcc_jit_field **fields);

/* Unions work similarly to structs.  */
gcc_jit_type *gcc_jit_context_new_union_type(gcc_jit_context *ctxt,
                                             gcc_jit_location *loc,
                                             in char *name,
                                             int num_fields,
                                             gcc_jit_field **fields);

/* Function pointers. */
gcc_jit_type *gcc_jit_context_new_function_ptr_type(gcc_jit_context *ctxt,
                                                    gcc_jit_location *loc,
                                                    gcc_jit_type *return_type,
                                                    int num_params,
                                                    gcc_jit_type **param_types,
                                                    int is_variadic);


/**********************************************************************
 Constructing functions.
 **********************************************************************/
/* Create a function param.  */
gcc_jit_param *gcc_jit_context_new_param(gcc_jit_context *ctxt,
                                         gcc_jit_location *loc,
                                         gcc_jit_type *type,
                                         in char *name);

/* Upcasting from param to object.  */
gcc_jit_object *gcc_jit_param_as_object(gcc_jit_param *param);

/* Upcasting from param to lvalue.  */
gcc_jit_lvalue *gcc_jit_param_as_lvalue(gcc_jit_param *param);

/* Upcasting from param to rvalue.  */
gcc_jit_rvalue *gcc_jit_param_as_rvalue(gcc_jit_param *param);

/* Kinds of function.  */
alias gcc_jit_function_kind = uint;
enum : gcc_jit_function_kind
{
    /* Function is defined by the client code and visible
       by name outside of the JIT.  */
    GCC_JIT_FUNCTION_EXPORTED,

    /* Function is defined by the client code, but is invisible
       outside of the JIT.  Analogous to a "static" function.  */
    GCC_JIT_FUNCTION_INTERNAL,

    /* Function is not defined by the client code; we're merely
       referring to it.  Analogous to using an "extern" function from a
       header file.  */
    GCC_JIT_FUNCTION_IMPORTED,

    /* Function is only ever inlined into other functions, and is
       invisible outside of the JIT.

       Analogous to prefixing with "inline" and adding
       __attribute__((always_inline)).

       Inlining will only occur when the optimization level is
       above 0; when optimization is off, this is essentially the
       same as GCC_JIT_FUNCTION_INTERNAL.  */
    GCC_JIT_FUNCTION_ALWAYS_INLINE
}

/* Create a function.  */
gcc_jit_function *gcc_jit_context_new_function(gcc_jit_context *ctxt,
                                               gcc_jit_location *loc,
                                               gcc_jit_function_kind kind,
                                               gcc_jit_type *return_type,
                                               in char *name,
                                               int num_params,
                                               gcc_jit_param **params,
                                               int is_variadic);

/* Create a reference to a builtin function (sometimes called intrinsic functions).  */
gcc_jit_function *gcc_jit_context_get_builtin_function(gcc_jit_context *ctxt,
                                                       in char *name);

/* Upcasting from function to object.  */
gcc_jit_object *gcc_jit_function_as_object(gcc_jit_function *func);

/* Get a specific param of a function by index.  */
gcc_jit_param *gcc_jit_function_get_param(gcc_jit_function *func, int index);

/* Emit the function in graphviz format.  */
void gcc_jit_function_dump_to_dot(gcc_jit_function *func,
                                  in char *path);

/* Create a block.

   The name can be NULL, or you can give it a meaningful name, which
   may show up in dumps of the internal representation, and in error
   messages.  */
gcc_jit_block *gcc_jit_function_new_block(gcc_jit_function *func,
                                          in char *name);

/* Upcasting from block to object.  */
gcc_jit_object *gcc_jit_block_as_object(gcc_jit_block *block);

/* Which function is this block within?  */
gcc_jit_function *gcc_jit_block_get_function(gcc_jit_block *block);

/**********************************************************************
 lvalues, rvalues and expressions.
 **********************************************************************/
alias gcc_jit_global_kind = uint;
enum : gcc_jit_global_kind
{
  /* Global is defined by the client code and visible
     by name outside of this JIT context via gcc_jit_result_get_global.  */
  GCC_JIT_GLOBAL_EXPORTED,

  /* Global is defined by the client code, but is invisible
     outside of this JIT context.  Analogous to a "static" global.  */
  GCC_JIT_GLOBAL_INTERNAL,

  /* Global is not defined by the client code; we're merely
     referring to it.  Analogous to using an "extern" global from a
     header file.  */
  GCC_JIT_GLOBAL_IMPORTED
}

gcc_jit_lvalue *gcc_jit_context_new_global(gcc_jit_context *ctxt,
                                           gcc_jit_location *loc,
                                           gcc_jit_global_kind kind,
                                           gcc_jit_type *type,
                                           in char *name);

/* Upcasting.  */
gcc_jit_object *gcc_jit_lvalue_as_object(gcc_jit_lvalue *lvalue);

gcc_jit_rvalue *gcc_jit_lvalue_as_rvalue(gcc_jit_lvalue *lvalue);

gcc_jit_object *gcc_jit_rvalue_as_object(gcc_jit_rvalue *rvalue);

gcc_jit_type *gcc_jit_rvalue_get_type(gcc_jit_rvalue *rvalue);

/* Integer constants. */
gcc_jit_rvalue *gcc_jit_context_new_rvalue_from_int(gcc_jit_context *ctxt,
                                                    gcc_jit_type *numeric_type,
                                                    int value);

gcc_jit_rvalue *gcc_jit_context_new_rvalue_from_long(gcc_jit_context *ctxt,
                                                     gcc_jit_type *numeric_type,
                                                     long value);

gcc_jit_rvalue *gcc_jit_context_zero(gcc_jit_context *ctxt,
                                     gcc_jit_type *numeric_type);

gcc_jit_rvalue *gcc_jit_context_one(gcc_jit_context *ctxt,
                                    gcc_jit_type *numeric_type);

/* Floating-point constants.  */
gcc_jit_rvalue *gcc_jit_context_new_rvalue_from_double(gcc_jit_context *ctxt,
                                                       gcc_jit_type *numeric_type,
                                                       double value);

/* Pointers.  */
gcc_jit_rvalue *gcc_jit_context_new_rvalue_from_ptr(gcc_jit_context *ctxt,
                                                    gcc_jit_type *pointer_type,
                                                    void *value);

gcc_jit_rvalue *gcc_jit_context_null(gcc_jit_context *ctxt,
                                     gcc_jit_type *pointer_type);

/* String literals. */
gcc_jit_rvalue *gcc_jit_context_new_string_literal(gcc_jit_context *ctxt,
                                                   in char *value);

alias gcc_jit_unary_op = uint;
enum : gcc_jit_unary_op
{
    /* Negate an arithmetic value; analogous to:
         -(EXPR)
       in C.  */
    GCC_JIT_UNARY_OP_MINUS,

    /* Bitwise negation of an integer value (one's complement); analogous
       to:
         ~(EXPR)
       in C.  */
    GCC_JIT_UNARY_OP_BITWISE_NEGATE,

    /* Logical negation of an arithmetic or pointer value; analogous to:
         !(EXPR)
       in C.  */
    GCC_JIT_UNARY_OP_LOGICAL_NEGATE
}

gcc_jit_rvalue *gcc_jit_context_new_unary_op(gcc_jit_context *ctxt,
                                             gcc_jit_location *loc,
                                             gcc_jit_unary_op op,
                                             gcc_jit_type *result_type,
                                             gcc_jit_rvalue *rvalue);

alias gcc_jit_binary_op = uint;
enum : gcc_jit_binary_op
{
    /* Addition of arithmetic values; analogous to:
         (EXPR_A) + (EXPR_B)
       in C.
       For pointer addition, use gcc_jit_context_new_array_access.  */
    GCC_JIT_BINARY_OP_PLUS,

    /* Subtraction of arithmetic values; analogous to:
         (EXPR_A) - (EXPR_B)
       in C.  */
    GCC_JIT_BINARY_OP_MINUS,

    /* Multiplication of a pair of arithmetic values; analogous to:
         (EXPR_A) * (EXPR_B)
       in C.  */
    GCC_JIT_BINARY_OP_MULT,

    /* Quotient of division of arithmetic values; analogous to:
         (EXPR_A) / (EXPR_B)
       in C.
       The result type affects the kind of division: if the result type is
       integer-based, then the result is truncated towards zero, whereas
       a floating-point result type indicates floating-point division.  */
    GCC_JIT_BINARY_OP_DIVIDE,

    /* Remainder of division of arithmetic values; analogous to:
         (EXPR_A) % (EXPR_B)
       in C.  */
    GCC_JIT_BINARY_OP_MODULO,

    /* Bitwise AND; analogous to:
         (EXPR_A) & (EXPR_B)
       in C.  */
    GCC_JIT_BINARY_OP_BITWISE_AND,

    /* Bitwise exclusive OR; analogous to:
         (EXPR_A) ^ (EXPR_B)
       in C.  */
    GCC_JIT_BINARY_OP_BITWISE_XOR,

    /* Bitwise inclusive OR; analogous to:
         (EXPR_A) | (EXPR_B)
       in C.  */
    GCC_JIT_BINARY_OP_BITWISE_OR,

    /* Logical AND; analogous to:
         (EXPR_A) && (EXPR_B)
       in C.  */
    GCC_JIT_BINARY_OP_LOGICAL_AND,

    /* Logical OR; analogous to:
         (EXPR_A) || (EXPR_B)
       in C.  */
    GCC_JIT_BINARY_OP_LOGICAL_OR,

    /* Left shift; analogous to:
       (EXPR_A) << (EXPR_B)
       in C.  */
    GCC_JIT_BINARY_OP_LSHIFT,

    /* Right shift; analogous to:
       (EXPR_A) >> (EXPR_B)
       in C.  */
    GCC_JIT_BINARY_OP_RSHIFT
}

gcc_jit_rvalue *gcc_jit_context_new_binary_op(gcc_jit_context *ctxt,
                                              gcc_jit_location *loc,
                                              gcc_jit_binary_op op,
                                              gcc_jit_type *result_type,
                                              gcc_jit_rvalue *a, gcc_jit_rvalue *b);

/* (Comparisons are treated as separate from "binary_op" to save
   you having to specify the result_type).  */

alias gcc_jit_comparison = uint;
enum : gcc_jit_comparison
{
    /* (EXPR_A) == (EXPR_B).  */
    GCC_JIT_COMPARISON_EQ,

    /* (EXPR_A) != (EXPR_B).  */
    GCC_JIT_COMPARISON_NE,

    /* (EXPR_A) < (EXPR_B).  */
    GCC_JIT_COMPARISON_LT,

    /* (EXPR_A) <=(EXPR_B).  */
    GCC_JIT_COMPARISON_LE,

    /* (EXPR_A) > (EXPR_B).  */
    GCC_JIT_COMPARISON_GT,

    /* (EXPR_A) >= (EXPR_B).  */
    GCC_JIT_COMPARISON_GE
}

gcc_jit_rvalue *gcc_jit_context_new_comparison(gcc_jit_context *ctxt,
                                               gcc_jit_location *loc,
                                               gcc_jit_comparison op,
                                               gcc_jit_rvalue *a, gcc_jit_rvalue *b);

/* Function calls.  */

/* Call of a specific function.  */
gcc_jit_rvalue *gcc_jit_context_new_call(gcc_jit_context *ctxt,
                                         gcc_jit_location *loc,
                                         gcc_jit_function *func,
                                         int numargs , gcc_jit_rvalue **args);

/* Call through a function pointer.  */
gcc_jit_rvalue *gcc_jit_context_new_call_through_ptr(gcc_jit_context *ctxt,
                                                     gcc_jit_location *loc,
                                                     gcc_jit_rvalue *fn_ptr,
                                                     int numargs, gcc_jit_rvalue **args);

/* Type-coercion.

   Currently only a limited set of conversions are possible:
     int <-> float
     int <-> bool  */
gcc_jit_rvalue *gcc_jit_context_new_cast(gcc_jit_context *ctxt,
                                         gcc_jit_location *loc,
                                         gcc_jit_rvalue *rvalue,
                                         gcc_jit_type *type);

gcc_jit_lvalue *gcc_jit_context_new_array_access(gcc_jit_context *ctxt,
                                                 gcc_jit_location *loc,
                                                 gcc_jit_rvalue *ptr,
                                                 gcc_jit_rvalue *index);

/* Field access is provided separately for both lvalues and rvalues.  */

/* Accessing a field of an lvalue of struct type, analogous to:
      (EXPR).field = ...;
   in C.  */
gcc_jit_lvalue *gcc_jit_lvalue_access_field(gcc_jit_lvalue *struct_or_union,
                                            gcc_jit_location *loc,
                                            gcc_jit_field *field);

/* Accessing a field of an rvalue of struct type, analogous to:
      (EXPR).field
   in C.  */
gcc_jit_rvalue *gcc_jit_rvalue_access_field(gcc_jit_rvalue *struct_or_union,
                                            gcc_jit_location *loc,
                                            gcc_jit_field *field);

/* Accessing a field of an rvalue of pointer type, analogous to:
      (EXPR)->field
   in C, itself equivalent to (*EXPR).FIELD  */
gcc_jit_lvalue *gcc_jit_rvalue_dereference_field(gcc_jit_rvalue *ptr,
                                                 gcc_jit_location *loc,
                                                 gcc_jit_field *field);

/* Dereferencing a pointer; analogous to:
     *(EXPR)
*/
gcc_jit_lvalue *gcc_jit_rvalue_dereference(gcc_jit_rvalue *rvalue,
                                           gcc_jit_location *loc);

/* Taking the address of an lvalue; analogous to:
     &(EXPR)
   in C.  */
gcc_jit_rvalue *gcc_jit_lvalue_get_address(gcc_jit_lvalue *lvalue,
                                           gcc_jit_location *loc);

gcc_jit_lvalue *gcc_jit_function_new_local(gcc_jit_function *func,
                                           gcc_jit_location *loc,
                                           gcc_jit_type *type,
                                           in char *name);

/**********************************************************************
 Statement-creation.
 **********************************************************************/

/* Add evaluation of an rvalue, discarding the result
   (e.g. a function call that "returns" void).

   This is equivalent to this C code:

     (void)expression;
*/
void gcc_jit_block_add_eval(gcc_jit_block *block,
                            gcc_jit_location *loc,
                            gcc_jit_rvalue *rvalue);

/* Add evaluation of an rvalue, assigning the result to the given
   lvalue.

   This is roughly equivalent to this C code:

     lvalue = rvalue;
*/
void gcc_jit_block_add_assignment(gcc_jit_block *block,
                                  gcc_jit_location *loc,
                                  gcc_jit_lvalue *lvalue,
                                  gcc_jit_rvalue *rvalue);

/* Add evaluation of an rvalue, using the result to modify an
   lvalue.

   This is analogous to "+=" and friends:

     lvalue += rvalue;
     lvalue *= rvalue;
     lvalue /= rvalue;
   etc  */
void gcc_jit_block_add_assignment_op(gcc_jit_block *block,
                                     gcc_jit_location *loc,
                                     gcc_jit_lvalue *lvalue,
                                     gcc_jit_binary_op op,
                                     gcc_jit_rvalue *rvalue);

/* Add a no-op textual comment to the internal representation of the
   code.  It will be optimized away, but will be visible in the dumps
   seen via
     GCC_JIT_BOOL_OPTION_DUMP_INITIAL_TREE
   and
     GCC_JIT_BOOL_OPTION_DUMP_INITIAL_GIMPLE,
   and thus may be of use when debugging how your project's internal
   representation gets converted to the libgccjit IR.  */
void gcc_jit_block_add_comment(gcc_jit_block *block,
                               gcc_jit_location *loc,
                               in char *text);

/* Terminate a block by adding evaluation of an rvalue, branching on the
   result to the appropriate successor block.

   This is roughly equivalent to this C code:

     if (boolval)
       goto on_true;
     else
       goto on_false;

   block, boolval, on_true, and on_false must be non-NULL.  */
void gcc_jit_block_end_with_conditional(gcc_jit_block *block,
                                        gcc_jit_location *loc,
                                        gcc_jit_rvalue *boolval,
                                        gcc_jit_block *on_true,
                                        gcc_jit_block *on_false);

/* Terminate a block by adding a jump to the given target block.

   This is roughly equivalent to this C code:

      goto target;
*/
void gcc_jit_block_end_with_jump(gcc_jit_block *block,
                                 gcc_jit_location *loc,
                                 gcc_jit_block *target);

/* Terminate a block by adding evaluation of an rvalue, returning the value.

   This is roughly equivalent to this C code:

      return expression;
*/
void gcc_jit_block_end_with_return(gcc_jit_block *block,
                                   gcc_jit_location *loc,
                                   gcc_jit_rvalue *rvalue);

/* Terminate a block by adding a valueless return, for use within a function
   with "void" return type.

   This is equivalent to this C code:

      return;
*/
void gcc_jit_block_end_with_void_return(gcc_jit_block *block,
                                        gcc_jit_location *loc);

/**********************************************************************
 Nested contexts.
 **********************************************************************/

/* Given an existing JIT context, create a child context.

   The child inherits a copy of all option-settings from the parent.

   The child can reference objects created within the parent, but not
   vice-versa.

   The lifetime of the child context must be bounded by that of the
   parent: you should release a child context before releasing the parent
   context.

   If you use a function from a parent context within a child context,
   you have to compile the parent context before you can compile the
   child context, and the gcc_jit_result of the parent context must
   outlive the gcc_jit_result of the child context.

   This allows caching of shared initializations.  For example, you could
   create types and declarations of global functions in a parent context
   once within a process, and then create child contexts whenever a
   function or loop becomes hot. Each such child context can be used for
   JIT-compiling just one function or loop, but can reference types
   and helper functions created within the parent context.

   Contexts can be arbitrarily nested, provided the above rules are
   followed, but it's probably not worth going above 2 or 3 levels, and
   there will likely be a performance hit for such nesting.  */

gcc_jit_context *gcc_jit_context_new_child_context(gcc_jit_context *parent_ctxt);
