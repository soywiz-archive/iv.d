/* coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * Understanding is not required. Only obedience.
 *
 *                   INVISIBLE VECTOR PUBLIC LICENSE
 *                       Version 1, September 2015
 *
 * Copyright (C) 2015 Ketmar Dark <ketmar@ketmar.no-ip.org>
 *
 * Everyone is permitted to copy and distribute verbatim or modified
 * copies of this license document, and changing it is allowed as long
 * as the name is changed.
 *
 *                   INVISIBLE VECTOR PUBLIC LICENSE
 *   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
 *
 * 0. You may not use this software in either source or binary form, any
 *    software derived from this software, any library which uses either
 *    this software or code derived from this software in any other
 *    software on the territory of Russian Federation, either directly or
 *    indirectly via any chain of libraries.
 *
 * 1. Redistributions of this software in either source or binary form must
 *    retain this list of conditions and the following disclaimer.
 *
 * 2. Otherwise, you are allowed to use this software in any way that will
 *    not violate paragraphs 0 and 1 of this license.
 *
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 * Authors: Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * License: IVPLv1
 */
module iv.sq3 is aliced;
pragma(lib, "sqlite3");

import etc.c.sqlite3;
import std.traits;
import std.range.primitives;


////////////////////////////////////////////////////////////////////////////////
mixin(NewExceptionClass!("SQLiteException", "Exception"));

class SQLiteErr : SQLiteException {
  int code;

  this (int rc, string file=__FILE__, size_t line=__LINE__, Throwable next=null) @trusted nothrow {
    //import core.stdc.stdio : stderr, fprintf;
    //fprintf(stderr, "SQLITE ERROR: %s\n", sqlite3_errstr(rc));
    import std.exception : assumeUnique;
    import std.string : fromStringz;
    code = rc;
    super(sqlite3_errstr(rc).fromStringz.assumeUnique, file, line, next);
  }
}


private void sqcheck (int rc, string file=__FILE__, size_t line=__LINE__) {
  //pragma(inline, true);
  if (rc != SQLITE_OK) throw new SQLiteErr(rc, file, line);
}


////////////////////////////////////////////////////////////////////////////////
shared static this () {
  if (sqlite3_initialize() != SQLITE_OK) throw new Error("can't initialize SQLite");
}

shared static ~this () {
  sqlite3_shutdown();
}


////////////////////////////////////////////////////////////////////////////////
struct Database {
private:
  sqlite3* db;

public:
  @disable this (this); // no copy!

  this (const(char)[] name, const(char)[] schema=null) => open(name, schema);
  ~this () => close();

  void open (const(char)[] name, const(char)[] schema=null) {
    close();
    import std.internal.cstring;
    sqcheck(sqlite3_open_v2(name.tempCString, &db, (schema !is null ? SQLITE_OPEN_READWRITE|SQLITE_OPEN_CREATE : SQLITE_OPEN_READONLY), null));
    scope(failure) { sqlite3_close_v2(db); db = null; }
    if (schema.length) execute(schema);
  }

  @property bool isOpen () const pure nothrow @safe @nogc => (db !is null);

  void close () {
    if (db !is null) sqlite3_close_v2(db);
    db = null;
  }

  ulong lastRowId () => (db ? sqlite3_last_insert_rowid(db) : 0);

  void execute (const(char)[] ops) {
    if (!isOpen) throw new Exception("database is not opened");
    foreach (auto opstr; sqlSplit(ops)) {
      import std.internal.cstring;
      char* errmsg;
      auto rc = sqlite3_exec(db, opstr.tempCString, null, null, &errmsg);
      if (rc != SQLITE_OK) {
        import core.stdc.stdio : stderr, fprintf;
        fprintf(stderr, "SQLITE ERROR: %s\n", errmsg);
        sqlite3_free(errmsg);
        sqcheck(rc);
      }
    }
  }

  DBStatement statement (const(char)[] stmtstr) {
    if (!isOpen) throw new Exception("database is not opened");
    return DBStatement(db, stmtstr);
  }

  static auto sqlSplit(T) (T text) if (isNarrowString!T) {
    static struct StatRange {
      T text;
      T front;

      this (T atext) {
        text = atext;
        popFront();
      }

      @property bool empty () const pure nothrow @safe @nogc => (front is null);

      void popFront () {
        front = null;
        while (text.length) {
          // spaces
          if (text[0] <= ' ') { text = text[1..$]; continue; }
          if (text[0] == ';') { text = text[1..$]; continue; }
          // leading comments
          if (text[0] == '/' && text.length > 1 && text[1] == '*') {
            text = text[2..$];
            while (text.length >= 2) {
              if (text[0] == '*' && text[1] == '/') break;
              text = text[1..$];
            }
            text = (text.length >= 2 ? text[2..$] : null);
            continue;
          }
          usize pos = 0;
          while (pos < text.length) {
            // eos?
            if (text[pos] == ';') {
              front = text[0..pos];
              text = text[pos+1..$];
              return;
            }
            // string
            if (text[pos] == '\'' || text[pos] == '"') {
              char q = text[pos++];
              bool wasQ = false;
              while (pos < text.length) {
                char ch = text[pos++];
                if (ch == q) {
                  // check for double quote
                  if (text.length-pos == 0 || text[pos] != q) {
                    wasQ = true;
                    break;
                  }
                  ++pos;
                  continue;
                }
              }
              if (!wasQ) throw new Exception("interminated string");
            }
            // comment
            if (text[pos] == '/' && text.length-pos > 1 && text[pos+1] == '*') {
              pos += 2;
              while (text.length-pos >= 2) {
                if (text[pos] == '*' && text[pos+1] == '/') break;
                ++pos;
              }
              if (text.length-pos < 2) throw new Exception("unterminated comment");
              continue;
            }
            // other
            ++pos;
          }
          front = (text.length ? text : null);
          text = null;
          return;
        }
      }
    }
    return StatRange(text);
  }
}


////////////////////////////////////////////////////////////////////////////////
struct DBStatement {
private:
  sqlite3_stmt* st;

public:
  @disable this (this); // no copy!

  private this (sqlite3* db, const(char)[] stmtstr) {
    if (db is null) throw new SQLiteException("database is not opened");
    if (stmtstr.length > int.max) throw new SQLiteException("statement too big");
    const(char)* e;
    sqcheck(sqlite3_prepare_v2(db, stmtstr.ptr, cast(int)stmtstr.length, &st, &e));
  }

  ~this () {
    reset();
    if (st !is null) sqlite3_finalize(st);
    st = null;
  }

  void reset () {
    if (st !is null) {
      sqlite3_reset(st);
      sqlite3_clear_bindings(st);
    }
  }

  void stepAll () {
    //if (st is null) throw new SQLiteException("statement is not prepared");
    scope(exit) reset();
    for (;;) {
      auto rc = sqlite3_step(st);
      if (rc == SQLITE_DONE) break;
      if (rc != SQLITE_ROW) sqcheck(rc);
    }
  }

  bool step () {
    //if (st is null) throw new SQLiteException("statement is not prepared");
    auto rc = sqlite3_step(st);
    if (rc == SQLITE_DONE) { reset(); return false; }
    if (rc != SQLITE_ROW) { reset(); sqcheck(rc); }
    return true;
  }

  auto q () {
    static struct Q {
      private sqlite3_stmt** stx____;

      @disable this (this); // no copy!
      private this (ref DBStatement ast) { stx____ = &ast.st; }

      private @property sqlite3_stmt* st____ () pure nothrow @safe @nogc => *stx____;

      void set(T) (usize idx, T v) if ((isNarrowString!T && is(ElementEncodingType!T : char)) || isIntegral!T) {
        if (st____ is null) throw new SQLiteException("statement closed");
        if (idx < 1 || idx > sqlite3_bind_parameter_count(st____)) throw new SQLiteException("invalid field index");
        int rc;
        static if (isNarrowString!T) {
          if (v.length > int.max) throw new SQLiteException("value too big");
          static if (is(ElementEncodingType!T == immutable(char))) {
            rc = sqlite3_bind_text(st____, idx, v.ptr, cast(int)v.length, /*SQLITE_STATIC*/SQLITE_TRANSIENT);
          } else {
            rc = sqlite3_bind_text(st____, idx, v.ptr, cast(int)v.length, SQLITE_TRANSIENT);
          }
        } else static if (isIntegral!T) {
          static if (isSigned!T) {
            rc = sqlite3_bind_int64(st____, idx, cast(long)v);
          } else {
            rc = sqlite3_bind_int64(st____, idx, cast(ulong)v);
          }
        } else {
          static assert(0, "WTF?!");
        }
        sqcheck(rc);
      }
      void set(T) (const(char)[] name, T v) {
        import std.internal.cstring;
        auto idx = sqlite3_bind_parameter_index(st____, name.tempCString);
        if (idx < 1) throw new SQLiteException("invalid field name: '"~name.idup~"'");
        return this.set!T(idx, v);
      }
      template opDispatch(string name) {
        void opDispatchImpl(T) (T v) if ((isNarrowString!T && is(ElementEncodingType!T : char)) || (is(T == ulong) || is(T == long))) => this.set!T(":"~name, v);
        alias opDispatch = opDispatchImpl;
      }
      template opIndexAssign() {
        void opIndexAssignImpl(T) (T v, const(char)[] name) if ((isNarrowString!T && is(ElementEncodingType!T : char)) || isIntegral!T) => this.set!T(name, v);
        void opIndexAssignImpl(T) (T v, usize idx) if ((isNarrowString!T && is(ElementEncodingType!T : char)) || isIntegral!T) => this.set!T(idx, v);
      }
    }
    return Q(this);
  }

  auto row () {
    static struct Row {
      private sqlite3_stmt** stx____;

      @disable this (this); // no copy!
      private this (ref DBStatement ast) { stx____ = &ast.st; }

      private @property sqlite3_stmt* st____ () pure nothrow @safe @nogc => *stx____;

      int fieldIndex____ (const(char)[] name) {
        if (st____ is null) throw new SQLiteException("statement closed");
        if (name.length > 0) {
          foreach (immutable int idx; 0..sqlite3_data_count(st____)) {
            import core.stdc.string : memcmp, strlen;
            auto n = sqlite3_column_name(st____, idx);
            if (n !is null) {
              auto len = strlen(n);
              if (len == name.length && memcmp(n, name.ptr, len) == 0) return idx;
            }
          }
        }
        throw new SQLiteException("invalid field name: '"~name.idup~"'");
      }

      T to(T) (usize idx) if ((isNarrowString!T && is(ElementEncodingType!T : char)) || (is(T == ulong) || is(T == long))) {
        if (st____ is null) throw new SQLiteException("statement closed");
        if (idx >= sqlite3_data_count(st____)) throw new SQLiteException("invalid result index");
        static if (is(T == ulong) || is(T == long)) {
          return sqlite3_column_int64(st____, idx);
        } else {
          auto res = sqlite3_column_text(st____, idx);
          auto len = sqlite3_column_bytes(st____, idx);
          if (len < 0) throw new SQLiteException("invalid result");
          static if (is(ElementEncodingType!T == const(char))) {
            return res[0..len];
          } else static if (is(ElementEncodingType!T == immutable(char))) {
            return res[0..len].idup;
          } else {
            return res[0..len].dup;
          }
        }
      }
      T to(T) (const(char)[] name) => this.to!T(fieldIndex____(name));

      template opIndex() {
        T opIndexImpl(T) (usize idx) if ((isNarrowString!T && is(ElementEncodingType!T : char)) || (is(T == ulong) || is(T == long))) => this.to!T(idx);
        T opIndexImpl(T) (const(char)[] name) if ((isNarrowString!T && is(ElementEncodingType!T : char)) || (is(T == ulong) || is(T == long))) => this.to!T(name);
        alias opIndex = opIndexImpl;
      }

      template opDispatch(string name) {
        T opDispatchImpl(T) () if ((isNarrowString!T && is(ElementEncodingType!T : char)) || (is(T == ulong) || is(T == long))) => this.to!T(name);
        alias opDispatch = opDispatchImpl;
      }
    }
    return Row(this);
  }
}
