/*
 * Invisible Vector Library
 * Andersson tree library
 *
 * based on the code from Julienne Walker
 * further coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * Understanding is not required. Only obedience.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */
module iv.aatree /*is aliced*/;

import iv.alice;


// ////////////////////////////////////////////////////////////////////////// //
final class AATree(TKey, TValue, bool stableIter=true) if (is(typeof((TKey a, TKey b) => a < b || a > b))) {
public:
  enum HEIGHT_LIMIT = 64; // tallest allowable tree

private:
  enum Left = 0;
  enum Right = 1;
  static if (stableIter) enum HasNodeList = true; else enum HasNodeList = false;

  static if (is(TKey == string)) enum KeyIsString = true; else enum KeyIsString = false;
  static if (is(TValue == string)) enum ValueIsString = true; else enum ValueIsString = false;

  static if (is(TKey == struct)) enum KeyIsStruct = true; else enum KeyIsStruct = false;
  static if (is(TValue == struct)) enum ValueIsStruct = true; else enum ValueIsStruct = false;

  private static template ArgPfx(bool isStruct) {
    static if (isStruct) enum ArgPfx = "auto ref"; else enum ArgPfx = "";
  }

  static final class Node {
  private:
    static if (is(typeof((TKey n) => n.clone()))) enum HasKeyClone = true; else enum HasKeyClone = false;
    static if (is(typeof((TValue n) => n.clone()))) enum HasValueClone = true; else enum HasValueClone = false;

    static if (is(typeof((TKey n) { n.release(); }))) enum HasKeyRelease = true; else enum HasKeyRelease = false;
    static if (is(typeof((TValue n) { n.release(); }))) enum HasValueRelease = true; else enum HasValueRelease = false;

    int level; // horizontal level for balance
    public TKey key;
    public TValue value;
    Node[2] link; // left (0) and right (1) links
    static if (stableIter) { public Node prev, next; }

    // create sentinel node
    this (AATree tree) {
      //value = null; // simplifies some ops
      level = 0;
      link.ptr[Left] = link.ptr[Right] = this;
    }

    private enum ThisBodyMixin = q{
      level = 1;
      link.ptr[Left] = link.ptr[Right] = tree.nil;
      static if (HasKeyClone) {
        static if (is(typeof(akey is null))) {
          if (akey !is null) key = akey.clone();
        } else {
          key = akey.clone();
        }
      } else {
        key = akey;
      }
      static if (HasValueClone) {
        static if (is(typeof(avalue is null))) {
          if (avalue !is null) value = avalue.clone();
        } else {
          value = avalue.clone();
        }
      } else {
        value = avalue;
      }
    };

    // create normal node
    mixin("this() (AATree tree, "~ArgPfx!KeyIsStruct~" TKey akey, "~ArgPfx!ValueIsStruct~" TValue avalue) {"~ThisBodyMixin~"}");

    void release () {
      //pragma(inline, true);
      static if (HasKeyRelease) {
        static if (is(typeof(key is null))) {
          if (key !is null) key.release();
        } else {
          key.release();
        }
      }
      static if (HasValueRelease) {
        static if (is(typeof(value is null))) {
          if (value !is null) value.release();
        } else {
          value.release();
        }
      }
    }
  }

private:
  Node root; // top of the tree
  Node nil;  // end of tree sentinel
  usize treeSize; // number of items (user-defined)
  ulong modFrame; // to invalidate walkers

  static if (stableIter) {
    Node head, tail;

    void addNodeToList (Node n) {
      pragma(inline, true);
      n.prev = tail;
      if (tail !is null) tail.next = n;
      tail = n;
      if (head is null) head = n;
    }

    void removeNodeFromList (Node n) {
      pragma(inline, true);
      if (n.prev !is null) n.prev.next = n.next; else head = n.next;
      if (n.next !is null) n.next.prev = n.prev; else tail = n.prev;
      assert(head is null || head.prev is null);
      assert(tail is null || tail.next is null);
    }

    Node firstNode () { pragma(inline, true); return head; }
    Node lastNode () { pragma(inline, true); return tail; }

    auto byNodes(bool fromHead=true) () {
      //alias TreeType = typeof(this);
      static struct Iterator(bool fromHead) {
      nothrow @safe @nogc:
        AATree tree;
        Node it; // current node
        ulong modFrame; // to sync with owner tree

        this (AATree atree) {
          tree = atree;
          modFrame = atree.modFrame;
          static if (fromHead) it = tree.firstNode; else it = tree.lastNode;
        }

        @property bool empty () const pure { pragma(inline, true); return (it is null || it is tree.nil || modFrame != tree.modFrame); }
        @property Node front () pure { pragma(inline, true); return it; }
        @property auto save () @trusted {
          pragma(inline, true);
          typeof(this) res = void;
          res.tree = tree;
          res.it = it;
          res.modFrame = modFrame;
          return res;
        }
        void popFront () {
          if (empty) { it = null; tree = null; return; }
          static if (fromHead) it = it.next; else it = it.prev;
          if (empty) { it = null; tree = null; return; }
        }
      }
      return Iterator!fromHead(this);
    }

    alias fromFirstNode = byNodes!true;
    alias fromLastNode = byNodes!false;
  }

  debug usize maxTreeDepth () {
    usize maxdepth = 0;
    void descend (Node n, usize depth) {
      if (n is null || n is nil) {
        if (depth-1 > maxdepth) maxdepth = depth-1;
        return;
      }
      descend(n.link[0], depth+1);
      descend(n.link[1], depth+1);
    }
    descend(root, 0);
    return maxdepth;
  }

public:
  this () {
    // initialize sentinel
    nil = new Node(this);
    // initialize tree
    root = nil;
    treeSize = 0;
  }

  ~this () { clear(); }

  void clear () {
    auto it = root;
    Node save;
    // destruction by rotation
    while (it !is nil) {
      if (it.link.ptr[Left] is nil) {
        // remove node
        save = it.link.ptr[Right];
        it.release();
        static if (stableIter) removeNodeFromList(it);
        //free(it);
      } else {
        // rotate right
        save = it.link.ptr[Left];
        it.link.ptr[Left] = save.link.ptr[Right];
        save.link.ptr[Right] = it;
      }
      it = save;
    }
    ++modFrame;
    // finalize destruction
    //free(this.nil);
    //free(this);
  }


  private enum FindBodyMixin = q{
    auto it = root;
    while (it !is nil) {
      int cmp = (it.key < key ? -1 : it.key > key ? 1 : 0);
      if (cmp == 0) break;
      it = it.link.ptr[(cmp < 0 ? Right : Left)];
    }
    // nil.value == null
    return (it !is nil ? it : null);
  };

  static if (KeyIsString) {
    Node find() (const(char)[] key) { mixin(FindBodyMixin); }
    Node opBinaryRight(string op : "in") (const(char)[] key) { pragma(inline, true); return find(key); }
  } else {
    mixin("Node find() ("~ArgPfx!KeyIsStruct~" TKey key) { "~FindBodyMixin~" }");
    mixin("Node opBinaryRight(string op : `in`) ("~ArgPfx!KeyIsStruct~" TKey key) { pragma(inline, true); return find(key); }");
  }


  private enum InsertBodyMixin = q{
    if (root is nil) {
      // empty this case
      static if (KeyIsString) { static if (!is(TK == string)) { auto dkey = key.idup; } else { alias dkey = key; } } else { alias dkey = key; }
      static if (ValueIsString) { static if (!is(TV == string)) { auto dvalue = value.idup; } else { alias dvalue = value; } } else { alias dvalue = value; }
      root = new Node(this, dkey, dvalue);
      static if (stableIter) addNodeToList(root);
      //if (root is nil) return false;
    } else {
      auto it = root;
      Node[HEIGHT_LIMIT] path;
      int top = 0, dir;
      // find a spot and save the path
      for (;;) {
        path[top++] = it;
        dir = (it.key < key ? Right : Left);
        if (it.link.ptr[dir] is nil) break;
        it = it.link.ptr[dir];
      }
      // create a new item
      static if (KeyIsString) { static if (!is(TK == string)) { auto dkey = key.idup; } else { alias dkey = key; } } else { alias dkey = key; }
      static if (ValueIsString) { static if (!is(TV == string)) { auto dvalue = value.idup; } else { alias dvalue = value; } } else { alias dvalue = value; }
      it.link.ptr[dir] = new Node(this, dkey, dvalue);
      static if (stableIter) addNodeToList(it.link.ptr[dir]);
      //if (it.link.ptr[dir] is nil) return false;
      // walk back and rebalance
      while (--top >= 0) {
        // which child?
        if (top != 0) dir = (path[top-1].link.ptr[Right] is path[top] ? Right : Left);
        mixin(skew!"path[top]");
        mixin(split!"path[top]");
        // fix the parent
        if (top != 0) {
          path[top-1].link.ptr[dir] = path[top];
        } else {
          root = path[top];
        }
      }
    }
    ++treeSize;
    ++modFrame;
    return true;
  };

  static if (KeyIsString && ValueIsString) {
    bool insert(TK, TV) (TK key, TV value) if (is(TK : const(char)[]) && is(TV : const(char)[])) { mixin(InsertBodyMixin); }
  } else static if (KeyIsString) {
    mixin("bool insert(TK) (TK key, "~ArgPfx!ValueIsStruct~" TValue value) if (is(TK : const(char)[])) { "~InsertBodyMixin~" }");
  } else static if (ValueIsString) {
    mixin("bool insert(TV) ("~ArgPfx!KeyIsStruct~" TKey key, TV value) if (is(TV : const(char)[])) { "~InsertBodyMixin~" }");
  } else {
    mixin("bool insert() ("~ArgPfx!KeyIsStruct~" TKey key, "~ArgPfx!ValueIsStruct~" TValue value) { "~InsertBodyMixin~" }");
  }


  private enum RemoveBodyMixin = q{
    if (root is nil) return false;
    auto it = root;
    Node[HEIGHT_LIMIT] path;
    int top = 0, dir, cmp;
    // find node to remove and save path
    for (;;) {
      path[top++] = it;
      if (it is nil) return false;
      cmp = (it.key < key ? -1 : it.key > key ? 1 : 0);
      if (cmp == 0) break;
      dir = (cmp < 0 ? Right : Left);
      it = it.link.ptr[dir];
    }
    // remove the found node
    if (it.link.ptr[Left] is nil || it.link.ptr[Right] is nil) {
      // single child case
      int dir2 = (it.link.ptr[Left] is nil ? Right : Left);
      // unlink the item
      if (--top != 0) {
        path[top-1].link.ptr[dir] = it.link.ptr[dir2];
      } else {
        root = it.link.ptr[Right];
      }
      it.release();
      static if (stableIter) removeNodeFromList(it);
      //free(it);
    } else {
      // two child case
      auto heir = it.link.ptr[Right];
      auto prev = it;
      while (heir.link.ptr[Left] !is nil) {
        path[top++] = prev = heir;
        heir = heir.link.ptr[Left];
      }
      // order is important!
      // (free item, replace item, free heir)
      it.release();
      it.key = heir.key;
      it.value = heir.value;
      prev.link.ptr[(prev is it ? Right : Left)] = heir.link.ptr[Right];
      static if (stableIter) {
        // replace `heir` with `it` in node list
        removeNodeFromList(it);
        it.prev = heir.prev;
        it.next = heir.next;
        // patch nodes
        if (it.prev !is null) it.prev.next = it; else head = it;
        if (it.next !is null) it.next.prev = it; else tail = it;
      }
      //free(heir);
    }
    // walk back up and rebalance
    while (--top >= 0) {
      auto up = path[top];
      if (top != 0) dir = (path[top-1].link.ptr[Right] is up ? Right : Left);
      // rebalance (aka. black magic)
      if (up.link.ptr[Left].level < up.level-1 || up.link.ptr[Right].level < up.level-1) {
        if (up.link.ptr[Right].level > --up.level) up.link.ptr[Right].level = up.level;
        // order is important!
        mixin(skew!"up");
        mixin(skew!"up.link.ptr[Right]");
        mixin(skew!"up.link.ptr[Right].link.ptr[Right]");
        mixin(split!"up");
        mixin(split!"up.link.ptr[Right]");
      }
      // fix the parent
      if (top != 0) {
        path[top-1].link.ptr[dir] = up;
      } else {
        root = up;
      }
    }
    --treeSize;
    ++modFrame;
    return true;
  };

  static if (KeyIsString) {
    bool remove() (const(char)[] key) { mixin(RemoveBodyMixin); }
  } else {
    mixin("bool remove() ("~ArgPfx!KeyIsStruct~" TKey key) { "~RemoveBodyMixin~" }");
  }

  usize size () const pure nothrow @safe @nogc { pragma(inline, true); return treeSize; }

  auto fromMin () { pragma(inline, true); return Walker(this, Left); }
  auto fromMax () { pragma(inline, true); return Walker(this, Right); }

static private:
  // remove left horizontal links
  enum skew(string t) = "{\n"~
    "  if ("~t~".link.ptr[Left].level == "~t~".level && "~t~".level != 0) {\n"~
    "    auto save = "~t~".link.ptr[Left];\n"~
    "    "~t~".link.ptr[Left] = save.link.ptr[Right];\n"~
    "    save.link.ptr[Right] = "~t~";\n"~
    "    "~t~" = save;\n"~
    "  }\n"~
    "}";

  // remove consecutive horizontal links
  enum split(string t) = "{\n"~
    "  if ("~t~".link.ptr[Right].link.ptr[Right].level == "~t~".level && "~t~".level != 0) {\n"~
    "    auto save = "~t~".link.ptr[Right];\n"~
    "    "~t~".link.ptr[Right] = save.link.ptr[Left];\n"~
    "    save.link.ptr[Left] = "~t~";\n"~
    "    "~t~" = save;\n"~
    "    ++"~t~".level;\n"~
    "  }\n"~
    "}";

  static struct Walker {
  nothrow @trusted @nogc:
  private:
    AATree tree;             // paired tree
    Node it;                 // current node
    Node[HEIGHT_LIMIT] path; // traversal path (actually, pointer to Node)
    usize top;               // top of stack
    int curdir;              // direction
    ulong modFrame;          // to sync with owner tree

  public:
    // 0: min; 1: max
    this (AATree atree, int dir) {
      tree = atree;
      curdir = !!dir;
      modFrame = tree.modFrame;
      top = 0;
      auto nil = tree.nil;
      it = tree.root;
      while (it !is nil) {
        path[top++] = it;
        it = it.link.ptr[curdir];
      }
      if (top) it = path[top-1];
    }

    @property bool empty () const pure { pragma(inline, true); return (tree is null || it is tree.nil || modFrame != tree.modFrame); }
    Node front () pure { pragma(inline, true); return it; }

    @property auto save () {
      Walker res = void;
      res.tree = tree;
      res.it = it;
      res.path[] = path[];
      res.top = top;
      res.curdir = curdir;
      res.modFrame = modFrame;
      return res;
    }

    // if TOS is it: now we should go opposite dir
    // go opposite dir: pop TOS (we shouldn't return there)
    void popFront () {
      if (tree is null || modFrame != tree.modFrame || it is tree.nil || top == 0) { top = 0; it = tree.nil; tree = null; return; }
      auto nil = tree.nil;
      if (it is path[top-1]) {
        // we should go right, and pop this branch
        --top;
        it = it.link.ptr[curdir^1];
        while (it !is nil) {
          path[top++] = it;
          // stepped right branch, now go left again
          it = it.link.ptr[curdir];
        }
      }
      // use stack top
      if (top) it = path[top-1];
      if (it is tree.nil) { tree = null; }
    }

    @property bool toMin () const pure { pragma(inline, true); return (curdir != Left); }
    @property bool toMax () const pure { pragma(inline, true); return (curdir == Left); }
  }
}


version(aat_test) {
// ////////////////////////////////////////////////////////////////////////// //
void test00 () {
  import std.stdio : writeln;

  /*
  void checkIterators(AATree) (AATree tree, int[] values) {
    import std.conv : to;
    int curK = 0;
    { import std.stdio; writeln("*** size=", tree.size); }
    foreach (/+auto+/ n; tree.fromMin) {
      { import std.stdio; writeln("  curK=", curK, "; values[", curK, "]=", values[curK]); }
      if (n.key != values[curK]) assert(0, "(0)Invalid key for key "~to!string(curK)~" ("~to!string(n.key)~","~to!string(n.value)~" : "~to!string(values[curK])~")");
      if (n.value != curK+1) assert(0, "(0)Invalid value for key "~to!string(curK)~" ("~to!string(n.key)~","~to!string(n.value)~" : "~to!string(values[curK])~")");
      ++curK;
    }
    curK = cast(int)tree.size;
    { import std.stdio; writeln(" curK=", curK, "; size=", tree.size); }
    foreach (/+auto+/ n; tree.fromMax) {
      --curK;
      { import std.stdio; writeln("  curK=", curK, "; values[", curK, "]=", values[curK]); }
      if (n.key != values[curK]) assert(0, "(1)Invalid key for key "~to!string(curK)~" ("~to!string(n.key)~","~to!string(n.value)~" : "~to!string(values[curK])~")");
      if (n.value != curK+1) assert(0, "(1)Invalid value for key "~to!string(curK)~" ("~to!string(n.key)~","~to!string(n.value)~" : "~to!string(values[curK])~")");
    }
  }
  */

  void checkIterators(AATree) (AATree tree) {
    import std.conv : to;
    //int curK = int.min, curV = int.min;
    /*
    {
      auto it = tree.fromMin();
      while (!it.empty) {
        import std.stdio;
        writeln(" k=", it.front.key, "; v=", it.front.value);
        it.popFront();
      }
    }
    { import std.stdio; writeln("---"); }
    { auto it = tree.fromMax(); while (!it.empty) { import std.stdio; writeln(" k=", it.front.key, "; v=", it.front.value); it.popFront(); } }
    */
    int count = 0, ln = int.min;
    { auto it = tree.fromMin(); while (!it.empty) { assert(it.front.key > ln); ln = it.front.key; ++count; it.popFront(); } }
    assert(count == tree.size);
    count = 0;
    ln = int.max;
    { auto it = tree.fromMax(); while (!it.empty) { assert(it.front.key < ln); ln = it.front.key; ++count; it.popFront(); } }
    assert(count == tree.size);
    int[] keys, values;
    //{ import std.stdio; writeln(" ** size=", tree.size); }
    foreach (/*auto*/ n; tree.fromMin) {
      //if (n.key <= curK) assert(0, "(0)Invalid key for key "~to!string(curK)~" ("~to!string(n.key)~","~to!string(n.value)~")");
      //if (n.value <= curV) assert(0, "(0)Invalid value for key "~to!string(curK)~" ("~to!string(n.key)~","~to!string(n.value)~")");
      keys ~= n.key;
      values ~= n.value;
      //curK = n.key;
      //curV = n.value;
    }
    //{ import std.stdio; writeln("  keys=", keys); writeln("  values=", values); }
    foreach (/*auto*/ n; tree.fromMax) {
      if (n.key != keys[$-1]) assert(0, "(1)Invalid key for key "~to!string(keys.length-1)~" ("~to!string(n.key)~","~to!string(n.value)~")");
      if (n.value != values[$-1]) assert(0, "(1)Invalid value for key "~to!string(keys.length-1)~" ("~to!string(n.key)~","~to!string(n.value)~")");
      keys = keys[0..$-1];
      values = values[0..$-1];
    }
  }

  void test (int[] values) {
    import std.conv : to;
    //{ import std.stdio; writeln("*** len=", values.length); }
    auto tree = new AATree!(int, int, true)();

    static if (tree.HasNodeList) {
      void checkNodeList () {
        auto n = tree.firstNode;
        int count = 0;
        //auto ln = int.min;
        while (n !is null) {
          //if (n.key <= ln) { import std.stdio; writeln("ln=", ln, "; key=", n.key); }
          //assert(n.key > ln);
          //ln = n.key;
          n = n.next;
          ++count;
        }
        ///*if (count != tree.size)*/ { import std.stdio; writeln("count=", count, "; size=", tree.size); }
        assert(count == tree.size);
        n = tree.lastNode;
        count = 0;
        //ln = int.max;
        while (n !is null) {
          //assert(n.key < ln);
          //ln = n.key;
          n = n.prev;
          ++count;
        }
        import std.range : enumerate;
        assert(count == tree.size);
        count = 0;
        foreach (/*auto*/ idx, /*auto*/ nn; tree.fromFirstNode.enumerate) { assert(count == idx); ++count; }
        assert(count == tree.size);
        count = 0;
        foreach (/*auto*/ idx, /*auto*/ nn; tree.fromLastNode.enumerate) { assert(count == idx); ++count; }
        assert(count == tree.size);
        if (count != tree.size) { import std.stdio; writeln("count=", count, "; size=", tree.size); }
      }
    } else {
      void checkNodeList () {}
    }

    for (int i = 0; i < values.length; ++i) {
      if (!tree.insert(values[i], i+1)) assert(0, "Failed to insert {0}"~to!string(values[i]));
      if (auto n = tree.find(values[i])) {
        if (n.value != i+1) assert(0, "Invalid value for key "~to!string(values[i]));
      } else {
        assert(0, "Could not find key "~to!string(values[i]));
      }
      checkIterators(tree);
      checkNodeList();
    }
    checkIterators(tree);
    checkNodeList();
    for (int i = 0; i < values.length; ++i) {
      for (int j = 0; j < i; j++) {
        if (tree.find(values[j])) assert(0, "Found deleted key {0}"~to!string(values[j]));
      }
      for (int j = i; j < values.length; j++) {
        if (auto n = tree.find(values[j])) {
          if (n.value != j+1) assert(0, "Invalid value for key {0}"~to!string(values[j]));
        } else {
          assert(0, "Could not find key {0}"~to!string(values[j]));
        }
      }
      if (!tree.remove(values[i])) assert(0, "Failed to delete {0}"~to!string(values[i]));
      checkIterators(tree);
      checkNodeList();
    }
  }

  writeln("test00 (0)");
  test([1, 2, 3, 4]);

  test([1]);

  test([1, 2]);
  test([2, 1]);

  test([1, 2, 3]);
  test([2, 1, 3]);
  test([1, 3, 2]);
  test([2, 3, 1]);
  test([3, 1, 2]);
  test([3, 2, 1]);

  test([1, 2, 3, 4]);
  test([2, 1, 3, 4]);
  test([1, 3, 2, 4]);
  test([2, 3, 1, 4]);
  test([3, 1, 2, 4]);
  test([3, 2, 1, 4]);
  test([1, 2, 4, 3]);
  test([2, 1, 4, 3]);
  test([1, 3, 4, 2]);
  test([2, 3, 4, 1]);
  test([3, 1, 4, 2]);
  test([3, 2, 4, 1]);
  test([1, 4, 2, 3]);
  test([2, 4, 1, 3]);
  test([1, 4, 3, 2]);
  test([2, 4, 3, 1]);
  test([3, 4, 1, 2]);
  test([3, 4, 2, 1]);
  test([4, 1, 2, 3]);
  test([4, 2, 1, 3]);
  test([4, 1, 3, 2]);
  test([4, 2, 3, 1]);
  test([4, 3, 1, 2]);
  test([4, 3, 2, 1]);

  writeln("test00 (1)");
  foreach (int count; 0..1000) {
    auto a = new int[](100);
    for (int i = 0; i < a.length; ++i) {
      int r;
      bool dup;
      do {
        import std.random : uniform;
        dup = false;
        r = uniform!"[]"(r.min, r.max);
        for (int j = 0; j < i; ++j) {
          if (a[j] == r) { dup = true; break; }
        }
      } while (dup);
      a[i] = r;
    }
    test(a);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
void test01 () {
  import std.stdio;

  static final class Data {
    usize idx;
    string word;
    uint cloneCount;

    this (usize aidx, string aword) { idx = aidx; word = aword; }

    Data clone () {
      //writeln("cloning #", idx, "[", word, "](", cloneCount, "+1)");
      auto res = new Data(idx, word);
      res.cloneCount = cloneCount+1;
      return res;
    }

    void release () {
      //writeln("releasing #", idx, "[", word, "](", cloneCount, ")");
    }
  }

  writeln("test01");

  auto tree = new AATree!(string, Data, true);

  writeln("creating tree...");
  string[] words;
  foreach (string line; File("/usr/share/dict/words").byLineCopy) {
    assert(line.length);
    words ~= line;
  }

  import std.random : randomShuffle, uniform;
  words.randomShuffle;

  foreach (immutable idx, string w; words) tree.insert(w, new Data(idx, w));

  debug { writeln("tree items: ", tree.size, "; max tree depth: ", tree.maxTreeDepth); }

  char[] key = "supernatural".dup;
  assert(key in tree);

  key = "motherfucker".dup;
  assert(key !in tree);
  tree.insert(key, new Data(words.length, key.idup));
  words ~= key.idup;

  void checkTree () {
    string ww;

    foreach (/*auto*/ node; tree.fromMin) {
      assert(ww.length == 0 || ww < node.key);
      ww = node.key;
    }

    ww = null;
    foreach (/*auto*/ node; tree.fromMax) {
      assert(ww.length == 0 || ww > node.key);
      ww = node.key;
    }

    import std.range : enumerate;

    foreach (immutable idx, /*auto*/ node; tree.fromFirstNode.enumerate) assert(node.key == words[idx]);
    foreach (immutable idx, /*auto*/ node; tree.fromLastNode.enumerate) assert(node.key == words[words.length-idx-1]);
  }

  checkTree();

  writeln("removing elements from tree...");

  usize count = 0;
  while (words.length != 0) {
    if (count++%128 == 0) {
      stdout.write("\r", words.length, " items left\x1b[K");
      stdout.flush();
    }
    import std.algorithm.mutation : remove;
    auto idx = uniform!"[)"(0, words.length);
    auto w = words[idx];
    words = words.remove(idx);
    if (!tree.remove(cast(const(char)[])w)) assert(0, "boo!");
    checkTree();
  }
  stdout.writeln("\r0 items left\x1b[K");

  writeln("clearing tree...");
  tree.clear;
}


// ////////////////////////////////////////////////////////////////////////// //
void main () {
  test00();
  test01();
}

} // version
