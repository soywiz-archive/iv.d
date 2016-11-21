/**
 * Signals and Slots are an implementation of the $(LINK2 http://en.wikipedia.org/wiki/Observer_pattern, Observer pattern)$(BR)
 * Essentially, when a Signal is emitted, a list of connected Observers
 * (called slots) are called.
 *
 * They were first introduced in the
 * $(LINK2 http://en.wikipedia.org/wiki/Qt_%28framework%29, Qt GUI toolkit), alternate implementations are
 * $(LINK2 http://libsigc.sourceforge.net, libsig++) or
 * $(LINK2 http://www.boost.org/doc/libs/1_55_0/doc/html/signals2.html, Boost.Signals2)
 * similar concepts are implemented in other languages than C++ too.$(BR)
 * $(LINK2 https://github.com/phobos-x/phobosx.git, original)
 *
 * Copyright: Copyright Robert Klotzner 2012 - 2014; Ketmar Dark 2015
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Robert Klotzner, Ketmar Dark
 */

/*          Copyright Robert Klotzner 2012 - 2014.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 *
 * Based on the original implementation written by Walter Bright. (std.signals)
 * I shamelessly stole some ideas of: http://forum.dlang.org/thread/jjote0$1cql$1@digitalmars.com
 * written by Alex Rønne Petersen.
 *
 * Also thanks to Denis Shelomovskij who made me aware of some
 * deficiencies in the concurrent part of WeakRef.
 */
module iv.signal is aliced;

// Hook into the GC to get informed about object deletions.
private alias void delegate (Object) DisposeEvt;
private extern (C) void rt_attachDisposeEvent (Object obj, DisposeEvt evt);
private extern (C) void rt_detachDisposeEvent (Object obj, DisposeEvt evt);


/**
 * Full signal implementation.
 *
 * It implements the emit function, for all other functionality it has
 * this aliased to RestrictedSignal.
 *
 * A signal is a way to couple components together in a very loose
 * way. The receiver does not need to know anything about the sender
 * and the sender does not need to know anything about the
 * receivers. The sender will just call emit when something happens,
 * the signal takes care of notifying all interested parties. By using
 * wrapper delegates/functions, not even the function signature of
 * sender/receiver need to match.
 *
 * Another consequence of this very loose coupling is, that a
 * connected object will be freed by the GC if all references to it
 * are dropped, even if it was still connected to a signal. The
 * connection will simply be removed. This way the developer is freed of
 * manually keeping track of connections.
 *
 * If in your application the connections made by a signal are not
 * that loose you can use strongConnect(), in this case the GC won't
 * free your object until it was disconnected from the signal or the
 * signal got itself destroyed.
 *
 * This struct is not thread-safe in general, it just handles the
 * concurrent parts of the GC.
 *
 * Example:
 ---
 import iv.signal;
 import std.stdio;

 class MyObject {
 private:
   int mValue;
 public:
   // Public accessor method returning a RestrictedSignal, thus restricting
   // the use of emit to this module. See the signal() string mixin below
   // for a simpler way.
   ref RestrictedSignal!(string, int) valueChanged () { return valueChangedSg.restricted; }
   private Signal!(string, int) valueChangedSg;

   @property int value () => mValue;
   @property int value (int v) {
     if (v != mValue) {
       mValue = v;
       // call all the connected slots with the two parameters
       valueChangedSg.emit("setting new value", v);
     }
     return v;
   }
 }

 class Observer {
   // our slot
   void watch (string msg, int i) {
     writefln("Observed msg '%s' and value %s", msg, i);
   }
 }
 void watch (string msg, int i) {
   writefln("Globally observed msg '%s' and value %s", msg, i);
 }
 void main () {
   auto a = new MyObject;
   Observer o = new Observer;

   a.value = 3;                // should not call o.watch()
   a.valueChanged.connect!"watch"(o);        // o.watch is the slot
   a.value = 4;                // should call o.watch()
   a.valueChanged.disconnect!"watch"(o);     // o.watch is no longer a slot
   a.value = 5;                // should not call o.watch()
   a.valueChanged.connect!"watch"(o);        // connect again
   // Do some fancy stuff:
   a.valueChanged.connect!Observer(o, (obj, msg, i) => obj.watch("Some other text I made up", i+1));
   a.valueChanged.connect(&watch);
   a.value = 6;                // should call o.watch()
   destroy(o);                 // destroying o should automatically disconnect it
   a.value = 7;                // should not call o.watch()
 }
---
 * which should print:
 * <pre>
 * Observed msg 'setting new value' and value 4
 * Observed msg 'setting new value' and value 6
 * Observed msg 'Some other text I made up' and value 7
 * Globally observed msg 'setting new value' and value 6
 * Globally observed msg 'setting new value' and value 7
 * </pre>
 */
struct Signal(Args...) {
private:
  RestrictedSignal!(Args) mRestricted;

public:
  alias restricted this;

  /**
   * Emit the signal.
   *
   * All connected slots which are still alive will be called.  If
   * any of the slots throws an exception, the other slots will
   * still be called. You'll receive a chained exception with all
   * exceptions that were thrown. Thus slots won't influence each
   * others execution.
   *
   * The slots are called in the same sequence as they were registered.
   *
   * emit also takes care of actually removing dead connections. For
   * concurrency reasons they are just set to an invalid state by the GC.
   *
   * If you remove a slot during emit() it won't be called in the
   * current run if it was not already.
   *
   * If you add a slot during emit() it will be called in the
   * current emit() run. Note however, Signal is not thread-safe, "called
   * during emit" basically means called from within a slot.
   */
  void emit (Args args) @trusted => mRestricted.mImpl.emit(args);

  /**
   * Get access to the rest of the signals functionality.
   *
   * By only granting your users access to the returned RestrictedSignal
   * reference, you are preventing your users from calling emit on their
   * own.
   */
  @property ref RestrictedSignal!(Args) restricted () @trusted => mRestricted;
}


/**
 * The signal implementation, not providing an emit method.
 *
 * A RestrictedSignal reference is returned by Signal.restricted,
 * it can safely be passed to users of your API, without
 * allowing them to call emit().
 */
struct RestrictedSignal(Args...) {
private:
  SignalImpl mImpl;

public:
  /**
   * Direct connection to an object.
   *
   * Use this method if you want to connect directly to an object's
   * method matching the signature of this signal.  The connection
   * will have weak reference semantics, meaning if you drop all
   * references to the object the garbage collector will collect it
   * and this connection will be removed.
   *
   * Preconditions: mixin("&obj."~method) must be valid and compatible.
   *
   * Params:
   *     obj = Some object of a class implementing a method
   *     compatible with this signal.
   */
  void connect(string method, ClassType) (ClassType obj) @trusted
  if (is(ClassType == class) && __traits(compiles, {void delegate (Args) dg = mixin("&obj."~method);}))
  {
    if (obj) mImpl.addSlot(obj, cast(void delegate ())mixin("&obj."~method));
  }

  /**
   * Indirect connection to an object.
   *
   * Use this overload if you want to connect to an objects method
   * which does not match the signal's signature.  You can provide
   * any delegate to do the parameter adaption, but make sure your
   * delegates' context does not contain a reference to the target
   * object, instead use the provided obj parameter, where the
   * object passed to connect will be passed to your delegate.
   * This is to make weak ref semantics possible, if your delegate
   * contains a ref to obj, the object won't be freed as long as
   * the connection remains.
   *
   * Preconditions: dg's context must not be equal to obj.
   *
   * Params:
   *     obj = The object to connect to. It will be passed to the
   *     delegate when the signal is emitted.
   *
   *     dg = A wrapper delegate which takes care of calling some
   *     method of obj. It can do any kind of parameter adjustments
   *     necessary.
   */
  void connect(ClassType) (ClassType obj, void delegate (ClassType obj, Args) dg) @trusted
  if (is(ClassType == class))
  {
    if (obj !is null && dg) {
      if (cast(void*)obj is dg.ptr) assert(0, "iv.signal connect: invalid delegate");
      mImpl.addSlot(obj, cast(void delegate ())dg);
    }
  }

  /**
   * Connect with strong ref semantics.
   *
   * Use this overload if you either want strong ref
   * semantics for some reason or because you want to connect some
   * non-class method delegate. Whatever the delegates' context
   * references will stay in memory as long as the signals'
   * connection is not removed and the signal gets not destroyed
   * itself.
   *
   * Params:
   *     dg = The delegate to be connected.
   */
  void strongConnect (void delegate (Args) dg) @trusted {
    if (dg !is null) mImpl.addSlot(null, cast(void delegate ())dg);
  }

  /**
   * Connect a free function to this signal.
   *
   * Params:
   *     fn = The free function to be connected.
   */
  void connect (void function (Args) fn) @trusted {
    if (fn !is null) {
      import std.functional : toDelegate;
      auto dg = toDelegate(fn);
      mImpl.addSlot(null, cast(void delegate ())dg);
    }
  }

  /**
   * Disconnect a direct connection.
   *
   * After issuing this call, the connection to method of obj is lost
   * and obj.method() will no longer be called on emit.
   * Preconditions: Same as for direct connect.
   */
  void disconnect(string method, ClassType) (ClassType obj) @trusted
  if (is(ClassType == class) && __traits(compiles, {void delegate (Args) dg = mixin("&obj."~method);}))
  {
    if (obj !is null) {
      void delegate (Args) dg = mixin("&obj."~method);
      mImpl.removeSlot(obj, cast(void delegate ()) dg);
    }
  }

  /**
   * Disconnect an indirect connection.
   *
   * For this to work properly, dg has to be exactly the same as
   * the one passed to connect. So if you used a lamda you have to
   * keep a reference to it somewhere if you want to disconnect
   * the connection later on.  If you want to remove all
   * connections to a particular object, use the overload which only
   * takes an object parameter.
   */
  void disconnect(ClassType) (ClassType obj, void delegate (ClassType, T1) dg) @trusted
  if (is(ClassType == class))
  {
    if (obj !is null && dg !is null) mImpl.removeSlot(obj, cast(void delegate ())dg);
  }

  /**
   * Disconnect all connections to obj.
   *
   * All connections to obj made with calls to connect are removed.
   */
  void disconnect(ClassType) (ClassType obj) @trusted
  if (is(ClassType == class))
  {
    if (obj !is null) mImpl.removeSlot(obj);
  }

  /**
   * Disconnect a connection made with strongConnect.
   *
   * Disconnects all connections to dg.
   */
  void strongDisconnect (void delegate (Args) dg) @trusted {
    if (dg !is null) mImpl.removeSlot(null, cast(void delegate ())dg);
  }

  /**
   * Disconnect a free function.
   *
   * Params:
   *    fn = The function to be disconnected.
   */
  void disconnect (void function (Args) fn) @trusted {
    if (fn !is null) {
      import std.functional : toDelegate;
      auto dg = toDelegate(fn);
      mImpl.removeSlot(null, cast(void delegate ())dg);
    }
  }
}


/**
 * string mixin for creating a signal.
 *
 * If you found the above:
---
     ref RestrictedSignal!(string, int) valueChanged () { return valueChangedSg.restricted; }
     private Signal!(string, int) valueChangedSg;
---
   a bit tedious, but still want to restrict the use of emit, you can use this
   string mixin. The following would result in exactly the same code:
---
     mixin(signal!(string, int)("valueChanged"));
---
 * Additional flexibility is provided by the protection parameter,
 * where you can change the protection of sgValueChanged to protected
 * for example.
 *
 * Params:
 *   name = How the signal should be named. The ref returning function
 *   will be named like this, the actual struct instance will have an
 *   underscore prefixed.
 *
 *   protection = Specifies how the full functionality (emit) of the
 *   signal should be protected. Default is private. If
 *   Protection.None is given, private is used for the Signal member
 *   variable and the ref returning accessor method will return a
 *   Signal instead of a RestrictedSignal. The protection of the
 *   accessor method is specified by the surrounding protection scope:
 ---
 *     public: // Everyone can access mysig now:
 *     // Result of mixin(signal!int("mysig", Protection.None))
 *     Signal!int* mysig () { return mysigSg; }
 *     private Signal!int mysigSg;
 ---
 */
string signal(Args...) (string name, Protection protection=Protection.Private) @trusted { // trusted necessary because of to!string
  static string pnorm() (string n) => ""~cast(char)(n[0]+32)~n[1..$];

  import std.conv : to;

  string argList = "(";
  foreach (auto arg; Args) {
    import std.traits : fullyQualifiedName;
    argList ~= fullyQualifiedName!(arg)~", ";
  }
  if (argList.length > "(".length) argList = argList[0..$-2];
  argList ~= ")";

  string fieldName = name~"Sg";

  string output = (protection == Protection.None ? "private" : pnorm(to!string(protection)))~
    " Signal!"~argList~" "~fieldName~";\n";
  if (protection == Protection.None) {
    output ~= "ref Signal!"~argList~" "~name~" () { return "~fieldName~"; }\n";
  } else {
    output ~= "ref RestrictedSignal!"~argList~" "~name~" () { return "~fieldName~".restricted; }\n";
  }
  return output;
}


/**
 * Protection to use for the signal string mixin.
 */
enum Protection {
  None, /// No protection at all, the wrapping function will return a ref Signal instead of a ref RestrictedSignal
  Private, /// The Signal member variable will be private.
  Protected, /// The signal member variable will be protected.
  Package /// The signal member variable will have package protection.
}


private struct SignalImpl {
private:
  SlotArray mSlots;

public:
  /**
   * Forbid copying.
   * Unlike the old implementations, it would now be theoretically
   * possible to copy a signal. Even different semantics are
   * possible. But none of the possible semantics are what the user
   * intended in all cases, so I believe it is still the safer
   * choice to simply disallow copying.
   */
  @disable this (this);
  /// Forbid copying
  @disable void opAssign (SignalImpl other);

  ~this () {
    foreach (ref slot; mSlots.slots) {
      debug(signal) {
        import iv.writer;
        errwritefln!"Destruction, removing some slot(%08X, weakref: %08X), signal: %08X"(&slot, &slot.mObj, &this);
      }
      slot.reset(); // This is needed because ATM the GC won't trigger struct
                    // destructors to be run when within a GC managed array.
    }
  }

  void emit(Args...) (Args args) {
    int emptyCount = 0;
    if (!mSlots.emitInProgress) {
      mSlots.emitInProgress = true;
      scope (exit) mSlots.emitInProgress = false;
    } else {
      emptyCount = -1;
    }
    doEmit(0, emptyCount, args);
    if (emptyCount > 0) {
      mSlots.slots = mSlots.slots[0..$-emptyCount];
      mSlots.slots.assumeSafeAppend();
    }
  }

  void addSlot (Object obj, void delegate () dg) {
    auto oldSlots = mSlots.slots;
    if (oldSlots.capacity <= oldSlots.length) {
      auto buf = new SlotImpl[oldSlots.length+1]; // TODO: This growing strategy might be inefficient.
      foreach (immutable i, ref slot; oldSlots) buf[i].moveFrom(slot);
      oldSlots = buf;
    } else {
      oldSlots.length = oldSlots.length+1;
    }
    oldSlots[$-1].construct(obj, dg);
    mSlots.slots = oldSlots;
  }

  void removeSlot (Object obj, void delegate () dg) => removeSlot((ref SlotImpl item) => item.wasConstructedFrom(obj, dg));
  void removeSlot (Object obj) => removeSlot((ref SlotImpl item) => item.obj is obj);

  /// Little helper functions:

  /**
   * Find and make invalid any slot for which isRemoved returns true.
   */
  void removeSlot (bool delegate (ref SlotImpl) isRemoved) {
    if (mSlots.emitInProgress) {
      foreach (ref slot; mSlots.slots) if (isRemoved(slot)) slot.reset();
    } else {
      // It is save to do immediate cleanup:
      int emptyCount = 0;
      auto mslots = mSlots.slots;
      foreach (int i, ref slot; mslots) {
        // We are retrieving obj twice which is quite expensive because of GC lock:
        if (!slot.isValid || isRemoved(slot)) {
          ++emptyCount;
          slot.reset();
        } else if (emptyCount) {
          mslots[i-emptyCount].moveFrom(slot);
        }
      }
      if (emptyCount > 0) {
        mslots = mslots[0..$-emptyCount];
        mslots.assumeSafeAppend();
        mSlots.slots = mslots;
      }
    }
  }

  /**
   * Helper method to allow all slots being called even in case of an exception.
   * All exceptions that occur will be chained.
   * Any invalid slots (GC collected or removed) will be dropped.
   */
  void doEmit(Args...) (int offset, ref int emptyCount, Args args) {
    int i = offset;
    auto myslots = mSlots.slots;
    scope (exit) if (i+1 < myslots.length) doEmit(i+1, emptyCount, args); // Carry on.
    if (emptyCount == -1) {
      for (; i < myslots.length; ++i) {
        myslots[i](args);
        myslots = mSlots.slots; // Refresh because addSlot might have been called.
      }
    } else {
      for (; i < myslots.length; ++i) {
        bool result = myslots[i](args);
        myslots = mSlots.slots; // Refresh because addSlot might have been called.
        if (!result) {
          ++emptyCount;
        } else if (emptyCount > 0) {
          myslots[i-emptyCount].reset();
          myslots[i-emptyCount].moveFrom(myslots[i]);
        }
      }
    }
  }
}


// Simple convenience struct for signal implementation.
// Its is inherently unsafe. It is not a template so SignalImpl does
// not need to be one.
private struct SlotImpl {
private:
  void* mFuncPtr;
  void* mDataPtr;
  WeakRef mObj;

  enum directPtrFlag = cast(void*)(~0);
  enum HasObjectFlag = 1uL<<(sptrdiff.sizeof*8-1);

public:
  @disable this (this);
  @disable void opAssign (SlotImpl other);

  /// Pass null for o if you have a strong ref delegate.
  /// dg.funcptr must not point to heap memory.
  void construct (Object o, void delegate () dg)
  in { assert(this is SlotImpl.default); }
  body {
    import core.memory : GC;
    mObj.construct(o);
    mDataPtr = dg.ptr;
    mFuncPtr = dg.funcptr;
    // as high addresses are reserved for kernel almost everywhere,
    // i'll use highest bit for keeping "hasObject" flag instead of lowest bit
    if ((cast(usize)mFuncPtr)&HasObjectFlag) assert(0, "iv.signals internal error 001");
    assert(GC.addrOf(mFuncPtr) is null, "Your function is implemented on the heap? Such dirty tricks are not supported with iv.signal!");
    if (o) {
      if (mDataPtr is cast(void*)o) mDataPtr = directPtrFlag;
      hasObject = true;
    }
  }

  /**
   * Check whether this slot was constructed from object o and delegate dg.
   */
  bool wasConstructedFrom (Object o, void delegate () dg) {
    if (o && dg.ptr is cast(void*)o) {
      return (obj is o && mDataPtr is directPtrFlag && funcPtr is dg.funcptr);
    } else {
      return (obj is o && mDataPtr is dg.ptr && funcPtr is dg.funcptr);
    }
  }

  /**
   * Implement proper explicit move.
   */
  void moveFrom (ref SlotImpl other)
  in { assert(this is SlotImpl.default); }
  body {
    auto o = other.obj;
    mObj.construct(o);
    mDataPtr = other.mDataPtr;
    mFuncPtr = other.mFuncPtr;
    other.reset(); // Destroy original!
  }

  @property Object obj () => mObj.obj;

  /**
   * Whether or not mObj should contain a valid object. (We have a weak connection)
   */
  @property bool hasObject () const => (cast(usize)mFuncPtr&HasObjectFlag) != 0;

  /**
   * Check whether this is a valid slot.
   *
   * Meaning opCall will call something and return true;
   */
  @property bool isValid () => funcPtr && (!hasObject || obj !is null);

  /**
   * Call the slot.
   *
   * Returns: True if the call was successful (the slot was valid).
   */
  bool opCall(Args...) (Args args) {
    auto o = obj;
    void* o_addr = cast(void*)(o);
    if (!funcPtr || (hasObject && !o_addr)) return false;
    if (mDataPtr is directPtrFlag || !hasObject) {
      void delegate (Args) mdg;
      mdg.funcptr = cast(void function(Args))funcPtr;
      assert((hasObject && mDataPtr is directPtrFlag) || (!hasObject && mDataPtr !is directPtrFlag));
      mdg.ptr = (hasObject ? o_addr : mDataPtr);
      mdg(args);
    } else {
      void delegate (Object, Args) mdg;
      mdg.ptr = mDataPtr;
      mdg.funcptr = cast(void function(Object, Args))funcPtr;
      mdg(o, args);
    }
    return true;
  }

  /**
   * Reset this instance to its initial value.
   */
  void reset () {
    mFuncPtr = SlotImpl.default.mFuncPtr;
    mDataPtr = SlotImpl.default.mDataPtr;
    mObj.reset();
  }

private:
  @property void* funcPtr () const => cast(void*)(cast(usize)mFuncPtr&~HasObjectFlag);
  @property void hasObject (bool yes) {
    if (yes) {
      mFuncPtr = cast(void*)(cast(usize)mFuncPtr|HasObjectFlag);
    } else {
      mFuncPtr = cast(void*)(cast(usize)mFuncPtr&~HasObjectFlag);
    }
  }
}


// Provides a way of holding a reference to an object, without the GC seeing it.
private struct WeakRef {
private:
  shared(InvisibleAddress) mObj;

public:
  /**
   * As struct must be relocatable, it is not even possible to
   * provide proper copy support for WeakRef.  rt_attachDisposeEvent
   * is used for registering unhook. D's move semantics assume
   * relocatable objects, which results in this(this) being called
   * for one instance and the destructor for another, thus the wrong
   * handlers are deregistered.  D's assumption of relocatable
   * objects is not matched, so move() for example will still simply
   * swap contents of two structs, resulting in the wrong unhook
   * delegates being unregistered.
   *
   * Unfortunately the runtime still blindly copies WeakRefs if they
   * are in a dynamic array and reallocation is needed. This case
   * has to be handled separately.
   */
  @disable this (this);
  @disable void opAssign (WeakRef other);

  ~this () => reset();

  void construct (Object o)
  in { assert(this is WeakRef.default); }
  body {
    debug(signal) createdThis = &this;
    debug(signal) { import iv.writer; writefln!"WeakRef.construct for %08X and object: %08X"(&this, cast(void*)o); }
    if (!o) return;
    mObj.construct(cast(void*)o);
    rt_attachDisposeEvent(o, &unhook);
  }

  @property Object obj () => cast(Object)mObj.address;

  /**
   * Reset this instance to its intial value.
   */
  void reset () {
    auto o = obj;
    debug(signal) { import iv.writer; writefln!"WeakRef.reset for %08X and object: %08x"(&this, cast(void*)o); }
    if (o) rt_detachDisposeEvent(o, &unhook);
    unhook(o); // unhook has to be done unconditionally, because in case the GC
    // kicked in during toggleVisibility(), obj would contain -1
    // so the assertion of SlotImpl.moveFrom would fail.
    debug(signal) createdThis = null;
  }

  private:
  debug(signal) {
    invariant() {
      import std.conv : text;
      assert(createdThis is null || &this is createdThis,
             text("We changed address! This should really not happen! Orig address: ",
              cast(void*)createdThis, " new address: ", cast(void*)&this));
    }
    WeakRef* createdThis;
  }

  void unhook (Object o) => mObj.reset();
}


// Do all the dirty stuff, WeakRef is only a thin wrapper completing
// the functionality by means of rt_ hooks.
private shared struct InvisibleAddress {
  debug(signal) string toString () {
    import std.conv : text;
    return text(address);
  }

nothrow:
  /// Initialize with o, state is set to invisible immediately.
  /// No precautions regarding thread safety are necessary because
  /// obviously a live reference exists.
  void construct (void* o) @nogc {
    mAddr = makeInvisible(cast(usize)o);
  }

  void reset () @nogc {
    import core.atomic : atomicStore;
    atomicStore(mAddr, 0L);
  }

  @property void* address () {
    import core.atomic : atomicLoad;
    import core.memory : GC;
    makeVisible();
    scope (exit) makeInvisible();
    GC.addrOf(cast(void*)atomicLoad(mAddr)); // Just a dummy call to the GC
                                             // in order to wait for any possible running
                                             // collection to complete (have unhook called).
    auto buf = atomicLoad(mAddr);
    if (isNull(buf)) return null;
    assert(isVisible(buf));
    return cast(void*)buf;
  }

private:
@nogc:
  ulong mAddr;

  void makeVisible () {
    import core.atomic : cas;
    ulong buf, wbuf;
    do {
      import core.atomic : atomicLoad;
      buf = atomicLoad(mAddr);
      wbuf = makeVisible(buf);
    } while (!cas(&mAddr, buf, wbuf));
  }

  void makeInvisible () {
    import core.atomic : cas;
    ulong buf, wbuf;
    do {
      import core.atomic : atomicLoad;
      buf = atomicLoad(mAddr);
      wbuf = makeInvisible(buf);
    } while (!cas(&mAddr, buf, wbuf));
  }

  version(D_LP64) {
    static ulong makeVisible() (ulong addr) => ~addr;
    static ulong makeInvisible() (ulong addr) => ~addr;
    static bool isVisible() (ulong addr) => !(addr&(1uL<<(sptrdiff.sizeof*8-1)));
    static bool isNull() (ulong addr) => (addr == 0 || addr == ~0);
  } else {
    static ulong makeVisible() (ulong addr) {
      /*
      immutable addrHigh = (addr>>32)&0xffff;
      immutable addrLow = addr&0xffff;
      return (addrHigh<<16)|addrLow;
      */
      return (addr&0xffff)|((addr>>16)&0xffff0000u);
    }
    static ulong makeInvisible() (ulong addr) {
      /*
      immutable addrHigh = ((addr>>16)&0x0000ffff)|0xffff0000;
      immutable addrLow = (addr&0x0000ffff)|0xffff0000;
      return (cast(ulong)addrHigh<<32)|addrLow;
      */
      return
        (addr&0xffff)|
        ((addr&0xffff0000u)<<16)|
        0xffff0000_ffff0000uL;
    }
    static bool isVisible() (ulong addr) => !((addr>>32)&0xffffffff);
    static bool isNull() (ulong addr) => (addr == 0 || addr == ((0xffff0000L<<32)|0xffff0000));
  }
}


/**
 * Provides a way of storing flags in unused parts of a typical D array.
 *
 * By unused I mean the highest bits of the length.
 * (We don't need to support 4 billion slots per signal with int
 * or 10^19 if length gets changed to 64 bits.)
 */
private struct SlotArray {
private:
  SlotImpl* mPtr;
  union BitsLength {
    mixin(bitfields!(
       bool, "", lengthType.sizeof*8-1,
       bool, "emitInProgress", 1
    ));
    lengthType length;
  }
  BitsLength mBLength;

public:
  // Choose uint for now, this saves 4 bytes on 64 bits.
  alias uint lengthType;
  import std.bitmanip : bitfields;
  enum reservedBitsCount = 3;
  enum maxSlotCount = lengthType.max>>reservedBitsCount;
  @property SlotImpl[] slots() => mPtr[0..length];
  @property void slots (SlotImpl[] newSlots) {
    mPtr = newSlots.ptr;
    version(assert) {
      import std.conv : text;
      assert(newSlots.length <= maxSlotCount, text("Maximum slots per signal exceeded: ", newSlots.length, "/", maxSlotCount));
    }
    mBLength.length &= ~maxSlotCount;
    mBLength.length |= newSlots.length;
  }
  @property usize length () const => mBLength.length&maxSlotCount;
  @property bool emitInProgress() const => mBLength.emitInProgress;
  @property void emitInProgress (bool val) => mBLength.emitInProgress = val;
}

version(unittest_signal)
unittest {
  SlotArray arr;
  auto tmp = new SlotImpl[10];
  arr.slots = tmp;
  assert(arr.length == 10);
  assert(!arr.emitInProgress);
  arr.emitInProgress = true;
  assert(arr.emitInProgress);
  assert(arr.length == 10);
  assert(arr.slots is tmp);
  arr.slots = tmp;
  assert(arr.emitInProgress);
  assert(arr.length == 10);
  assert(arr.slots is tmp);
  debug(signal) { import iv.writer; writeln("Slot array tests passed!"); }
}

version(unittest_signal)
unittest {
  // Check that above example really works ...
  import std.functional;
  debug(signal) import iv.writer;
  class MyObject {
  private:
    int mValue;
  public:
    mixin(signal!(string, int)("valueChanged"));
    //pragma(msg, signal!(string, int)("valueChanged"));

    @property int value () => mValue;
    @property int value (int v) {
      if (v != mValue) {
        mValue = v;
        // call all the connected slots with the two parameters
        valueChangedSg.emit("setting new value", v);
      }
      return v;
    }
  }

  class Observer {
    // our slot
    void watch (string msg, int i) {
      debug(signal) writefln!"Observed msg '%s' and value %s"(msg, i);
    }
  }

  static void watch (string msg, int i) {
    debug(signal) writefln!"Globally observed msg '%s' and value %s"(msg, i);
  }

  auto a = new MyObject;
  Observer o = new Observer;

  a.value = 3;                          // should not call o.watch()
  a.valueChanged.connect!"watch"(o);    // o.watch is the slot
  a.value = 4;                          // should call o.watch()
  a.valueChanged.disconnect!"watch"(o); // o.watch is no longer a slot
  a.value = 5;                          // so should not call o.watch()
  a.valueChanged.connect!"watch"(o);    // connect again
  // Do some fancy stuff:
  a.valueChanged.connect!Observer(o, (obj, msg, i) =>  obj.watch("Some other text I made up", i+1));
  a.valueChanged.strongConnect(toDelegate(&watch));
  a.value = 6; // should call o.watch()
  destroy(o);  // destroying o should automatically disconnect it
  a.value = 7; // should not call o.watch()
}

version(unittest_signal)
unittest {
  debug(signal) import iv.writer;

  class Observer {
    void watch (string msg, int i) {
      //debug(signal) writeln("Observed msg '", msg, "' and value ", i);
      captured_value = i;
      captured_msg = msg;
    }
    int captured_value;
    string captured_msg;
  }

  class SimpleObserver {
    void watchOnlyInt (int i) => captured_value = i;
    int captured_value;
  }

  class Foo {
  private:
    int mValue;

  public:
    @property int value() => mValue;
    @property int value (int v) {
      if (v != mValue) {
        mValue = v;
        extendedSigSg.emit("setting new value", v);
        //simpleSig.emit(v);
      }
      return v;
    }

    mixin(signal!(string, int)("extendedSig"));
    //pragma(msg, signal!(string, int)("extendedSig"));
    //Signal!(int) simpleSig;
  }

  Foo a = new Foo;
  Observer o = new Observer;
  SimpleObserver so = new SimpleObserver;
  // check initial condition
  assert(o.captured_value == 0);
  assert(o.captured_msg == "");

  // set a value while no observation is in place
  a.value = 3;
  assert(o.captured_value == 0);
  assert(o.captured_msg == "");

  // connect the watcher and trigger it
  a.extendedSig.connect!"watch"(o);
  a.value = 4;
  //debug(signal) { writeln("o.captured_value=", o.captured_value, " (must be 4)"); }
  assert(o.captured_value == 4);
  assert(o.captured_msg == "setting new value");

  // disconnect the watcher and make sure it doesn't trigger
  a.extendedSig.disconnect!"watch"(o);
  a.value = 5;
  assert(o.captured_value == 4);
  assert(o.captured_msg == "setting new value");
  //a.extendedSig.connect!Observer(o, (obj, msg, i) { obj.watch("Hahah", i); });
  a.extendedSig.connect!Observer(o, (obj, msg, i) => obj.watch("Hahah", i) );

  a.value = 7;
  debug(signal) errwriteln("After asignment!");
  //debug(signal) { writeln("o.captured_value=", o.captured_value, " (must be 7)"); }
  assert(o.captured_value == 7);
  assert(o.captured_msg == "Hahah");
  a.extendedSig.disconnect(o); // Simply disconnect o, otherwise we would have to store the lamda somewhere if we want to disconnect later on.
  // reconnect the watcher and make sure it triggers
  a.extendedSig.connect!"watch"(o);
  a.value = 6;
  assert(o.captured_value == 6);
  assert(o.captured_msg == "setting new value");

  // destroy the underlying object and make sure it doesn't cause
  // a crash or other problems
  debug(signal) errwriteln("Disposing");
  destroy(o);
  debug(signal) errwriteln("Disposed");
  a.value = 7;
}

version(unittest_signal)
unittest {
  class Observer {
    int i;
    long l;
    string str;

    void watchInt (string str, int i) {
      this.str = str;
      this.i = i;
    }

    void watchLong (string str, long l) {
      this.str = str;
      this.l = l;
    }
  }

  class Bar {
    @property void value1 (int v)  => s1Sg.emit("str1", v);
    @property void value2 (int v)  => s2Sg.emit("str2", v);
    @property void value3 (long v) => s3Sg.emit("str3", v);

    mixin(signal!(string, int) ("s1"));
    mixin(signal!(string, int) ("s2"));
    mixin(signal!(string, long)("s3"));
  }

  void test(T) (T a) {
    auto o1 = new Observer;
    auto o2 = new Observer;
    auto o3 = new Observer;

    // connect the watcher and trigger it
    a.s1.connect!"watchInt"(o1);
    a.s2.connect!"watchInt"(o2);
    a.s3.connect!"watchLong"(o3);

    assert(!o1.i && !o1.l && !o1.str.length);
    assert(!o2.i && !o2.l && !o2.str.length);
    assert(!o3.i && !o3.l && !o3.str.length);

    a.value1 = 11;
    assert(o1.i == 11 && !o1.l && o1.str == "str1");
    assert(!o2.i && !o2.l && !o2.str.length);
    assert(!o3.i && !o3.l && !o3.str.length);
    o1.i = -11; o1.str = "x1";

    a.value2 = 12;
    assert(o1.i == -11 && !o1.l && o1.str == "x1");
    assert(o2.i == 12 && !o2.l && o2.str == "str2");
    assert(!o3.i && !o3.l && !o3.str.length);
    o2.i = -12; o2.str = "x2";

    a.value3 = 13;
    assert(o1.i == -11 && !o1.l && o1.str == "x1");
    assert(o2.i == -12 && !o1.l && o2.str == "x2");
    assert(!o3.i && o3.l == 13 && o3.str == "str3");
    o3.l = -13; o3.str = "x3";

    // disconnect the watchers and make sure it doesn't trigger
    a.s1.disconnect!"watchInt"(o1);
    a.s2.disconnect!"watchInt"(o2);
    a.s3.disconnect!"watchLong"(o3);

    a.value1 = 21;
    a.value2 = 22;
    a.value3 = 23;
    assert(o1.i == -11 && !o1.l && o1.str == "x1");
    assert(o2.i == -12 && !o1.l && o2.str == "x2");
    assert(!o3.i && o3.l == -13 && o3.str == "x3");

    // reconnect the watcher and make sure it triggers
    a.s1.connect!"watchInt"(o1);
    a.s2.connect!"watchInt"(o2);
    a.s3.connect!"watchLong"(o3);

    a.value1 = 31;
    a.value2 = 32;
    a.value3 = 33;
    assert(o1.i == 31 && !o1.l && o1.str == "str1");
    assert(o2.i == 32 && !o1.l && o2.str == "str2");
    assert(!o3.i && o3.l == 33 && o3.str == "str3");

    // destroy observers
    destroy(o1);
    destroy(o2);
    destroy(o3);
    a.value1 = 41;
    a.value2 = 42;
    a.value3 = 43;
  }

  test(new Bar);

  class BarDerived: Bar {
    @property void value4 (int v)  => s4Sg.emit("str4", v);
    @property void value5 (int v)  => s5Sg.emit("str5", v);
    @property void value6 (long v) => s6Sg.emit("str6", v);

    mixin(signal!(string, int) ("s4"));
    mixin(signal!(string, int) ("s5"));
    mixin(signal!(string, long)("s6"));
  }

  auto a = new BarDerived;

  test!Bar(a);
  test!BarDerived(a);

  auto o4 = new Observer;
  auto o5 = new Observer;
  auto o6 = new Observer;

  // connect the watcher and trigger it
  a.s4.connect!"watchInt"(o4);
  a.s5.connect!"watchInt"(o5);
  a.s6.connect!"watchLong"(o6);

  assert(!o4.i && !o4.l && !o4.str.length);
  assert(!o5.i && !o5.l && !o5.str.length);
  assert(!o6.i && !o6.l && !o6.str.length);

  a.value4 = 44;
  assert(o4.i == 44 && !o4.l && o4.str == "str4");
  assert(!o5.i && !o5.l && !o5.str.length);
  assert(!o6.i && !o6.l && !o6.str.length);
  o4.i = -44; o4.str = "x4";

  a.value5 = 45;
  assert(o4.i == -44 && !o4.l && o4.str == "x4");
  assert(o5.i == 45 && !o5.l && o5.str == "str5");
  assert(!o6.i && !o6.l && !o6.str.length);
  o5.i = -45; o5.str = "x5";

  a.value6 = 46;
  assert(o4.i == -44 && !o4.l && o4.str == "x4");
  assert(o5.i == -45 && !o4.l && o5.str == "x5");
  assert(!o6.i && o6.l == 46 && o6.str == "str6");
  o6.l = -46; o6.str = "x6";

  // disconnect the watchers and make sure it doesn't trigger
  a.s4.disconnect!"watchInt"(o4);
  a.s5.disconnect!"watchInt"(o5);
  a.s6.disconnect!"watchLong"(o6);

  a.value4 = 54;
  a.value5 = 55;
  a.value6 = 56;
  assert(o4.i == -44 && !o4.l && o4.str == "x4");
  assert(o5.i == -45 && !o4.l && o5.str == "x5");
  assert(!o6.i && o6.l == -46 && o6.str == "x6");

  // reconnect the watcher and make sure it triggers
  a.s4.connect!"watchInt"(o4);
  a.s5.connect!"watchInt"(o5);
  a.s6.connect!"watchLong"(o6);

  a.value4 = 64;
  a.value5 = 65;
  a.value6 = 66;
  assert(o4.i == 64 && !o4.l && o4.str == "str4");
  assert(o5.i == 65 && !o4.l && o5.str == "str5");
  assert(!o6.i && o6.l == 66 && o6.str == "str6");

  // destroy observers
  destroy(o4);
  destroy(o5);
  destroy(o6);
  a.value4 = 44;
  a.value5 = 45;
  a.value6 = 46;
}

version(unittest_signal)
unittest {
  import iv.writer;

  struct Property {
  private:
    int mValue;

  public:
    alias value this;
    mixin(signal!(int)("signal"));
    @property int value () => mValue;
    ref Property opAssign (int val) {
      debug(signal) writefln!"Assigning int to property with signal: %08X"(&this);
      mValue = val;
      signalSg.emit(val);
      return this;
    }
  }

  void observe (int val) {
    debug(signal) writeln("observe: Wow! The value changed: ", val);
  }

  class Observer {
    void observe (int val) {
      debug(signal) writeln("Observer: Wow! The value changed: ", val);
      debug(signal) writeln("Really! I must know I am an observer (old value was: ", observed, ")!");
      observed = val;
      ++count;
    }
    int observed;
    int count;
  }
  Property prop;
  void delegate (int) dg = (val) => observe(val);
  prop.signal.strongConnect(dg);
  assert(prop.signal.mImpl.mSlots.length==1);
  Observer o = new Observer;
  prop.signal.connect!"observe"(o);
  assert(prop.signal.mImpl.mSlots.length==2);
  debug(signal) writeln("Triggering on original property with value 8 ...");
  prop=8;
  assert(o.count==1);
  assert(o.observed==prop);
}

version(unittest_signal)
unittest {
  debug(signal) import iv.writer;
  import std.conv;
  Signal!() s1;
  void testfunc (int id) { throw new Exception(to!string(id)); }
  s1.strongConnect(() => testfunc(0));
  s1.strongConnect(() => testfunc(1));
  s1.strongConnect(() => testfunc(2));
  try {
    s1.emit();
  } catch (Exception e) {
    Throwable t = e;
    int i = 0;
    while (t) {
      debug(signal) errwriteln("*** Caught exception (this is fine); i=", i, "; msg=", t.msg);
      version(DigitalMars) assert(to!int(t.msg) == i);
      t = t.next;
      ++i;
    }
    debug(signal) errwriteln("+++");
    version(DigitalMars) assert(i == 3);
  }
}

version(unittest_signal)
unittest {
  class A {
    mixin(signal!(string, int)("s1"));
  }

  class B : A {
    mixin(signal!(string, int)("s2"));
  }
}

version(unittest_signal)
unittest {
  struct Test {
    mixin(signal!int("a", Protection.Package));
    mixin(signal!int("ap", Protection.Private));
    mixin(signal!int("app", Protection.Protected));
    mixin(signal!int("an", Protection.None));
  }

  /*
  pragma(msg, signal!int("a", Protection.Package));
  pragma(msg, signal!int("a", Protection.Protected));
  pragma(msg, signal!int("a", Protection.Private));
  pragma(msg, signal!int("a", Protection.None));
  */

  static assert(signal!int("a", Protection.Package) == "package Signal!(int) aSg;\nref RestrictedSignal!(int) a () { return aSg.restricted; }\n");
  static assert(signal!int("a", Protection.Protected) == "protected Signal!(int) aSg;\nref RestrictedSignal!(int) a () { return aSg.restricted; }\n");
  static assert(signal!int("a", Protection.Private) == "private Signal!(int) aSg;\nref RestrictedSignal!(int) a () { return aSg.restricted; }\n");
  static assert(signal!int("a", Protection.None) == "private Signal!(int) aSg;\nref Signal!(int) a () { return aSg; }\n");

  debug(signal) {
    pragma(msg, signal!int("a", Protection.Package));
    pragma(msg, signal!(int, string, int[int])("a", Protection.Private));
    pragma(msg, signal!(int, string, int[int], float, double)("a", Protection.Protected));
    pragma(msg, signal!(int, string, int[int], float, double, long)("a", Protection.None));
  }
}

// Test nested emit/removal/addition ...
version(unittest_signal)
unittest {
  Signal!() sig;
  bool doEmit = true;
  int counter = 0;
  int slot3called = 0;
  int slot3shouldcalled = 0;
  void slot1 () {
    doEmit = !doEmit;
    if (!doEmit) sig.emit();
  }
  void slot3 () => ++slot3called;
  void slot2 () {
    debug(signal) { import iv.writer; writefln!"CALLED: %s, should called: %s"(slot3called, slot3shouldcalled); }
    assert(slot3called == slot3shouldcalled);
    if (++counter < 100) slot3shouldcalled += counter;
    if (counter < 100) sig.strongConnect(&slot3);
  }
  void slot4 () {
    if (counter == 100) sig.strongDisconnect(&slot3); // All connections dropped
  }
  sig.strongConnect(&slot1);
  sig.strongConnect(&slot2);
  sig.strongConnect(&slot4);
  foreach (; 0..1000) sig.emit();
  debug(signal) {
    import iv.writer;
    writeln("slot3called: ", slot3called);
  }
}

version(unittest_signal)
unittest {
  import iv.writer; errwriteln("tests passed!");
}


// parse signal definition, return mixin string
public template Signals(string sstr) {
  static string doIt() (string sstr) {
    usize skipSpaces() (usize pos) {
      while (pos < sstr.length) {
        if (pos+1 < sstr.length && sstr[pos] == '/') {
          if (sstr[pos+1] == '/') {
            while (pos < sstr.length && sstr[pos] != '\n') ++pos;
          } else if (sstr[pos+1] == '*' || sstr[pos+1] == '+') {
            //FIXME: "+" should nest
            char ech = sstr[pos+1];
            pos += 2;
            while (pos < sstr.length-1) {
              if (sstr[pos+1] == '/' && sstr[pos] == ech) { ++pos; break; }
              ++pos;
            }
            ++pos;
          } else {
            break;
          }
        } else if (sstr[pos] <= ' ') {
          ++pos;
        } else {
          break;
        }
      }
      return pos;
    }

    string res;
    while (sstr.length) {
      // get signal name
      // skip spaces
      usize pos = skipSpaces(0);
      if (pos >= sstr.length) break;
      // skip id
      usize end = pos;
      while (end < sstr.length) {
        if (sstr[end] <= ' ' || sstr[end] == '(' || sstr[end] == '/') break;
        ++end;
      }
      string id = sstr[pos..end];
      end = skipSpaces(end);
      if (end >= sstr.length || sstr[end] != '(') assert(0, "Signals: '(' expected");
      sstr = sstr[end+1..$];
      //assert(0, "*** "~sstr);
      res ~= "mixin(signal!(";
      // parse args
      while (sstr.length) {
        pos = skipSpaces(0);
        if (pos >= sstr.length) assert(0, "Signals: ')' expected");
        if (sstr[pos] == ')') {
          pos = skipSpaces(pos+1);
          sstr = sstr[pos..$];
          break;
        }
        // find ')' or ','
        end = pos;
        //usize lastSpace = usize.max;
        usize bcnt = 0;
        //TODO: comments
        while (end < sstr.length) {
          if (sstr[end] == '(') {
            ++bcnt;
          } else if (sstr[end] == ')') {
            if (bcnt-- == 0) break;
          } else if (sstr[end] == ',') {
            if (bcnt != 0) assert(0, "Signals: unbalanced parens: "~sstr[pos..end]);
            break;
          }
          ++end;
        }
        if (end >= sstr.length || end == pos) assert(0, "Signals: ')' expected");
        // get definition
        string def = sstr[pos..end];
        end = skipSpaces(end);
        if (sstr[end] == ',') ++end;
        sstr = sstr[end..$];
        // strip trailing spaces
        for (end = def.length; end > 0; --end) if (def[end] > ' ') break;
        //if (end < def.length) def = def[0..end];
        // now cut out the last word
        usize xxend = end;
        while (end > 0 && def[end] > ' ') --end;
        if (end == 0) {
          // only one word, wtf?!
          assert(0, "Signals: argument name expected: "~def);
        } else {
          while (end > 0 && def[end] <= ' ') --end;
          res ~= def[0..end+1]~",";
        }
      }
      if (!sstr.length || sstr[0] != ';') assert(0, "Signals: ';' expected: "~sstr);
      sstr = sstr[1..$];
      if (res[$-1] == ',') res = res[0..$-1];
      res ~= ")(`"~id~"`));\n";
    }
    return res;
  }
  enum Signals = doIt(sstr);
}


version(unittest_signal)
unittest {
  pragma(msg, Signals!q{
    onBottomLineChange (uint id, uint newln);
    onWriteBytes (uint id, const(char)[] buf);
  });
}


struct slot {
  string signalName;
}


public template AutoConnect(string srcobj, T) if (is(T == class) || is(T == struct)) {
  private import iv.udas;
  template doMember(MB...) {
    static if (MB.length == 0) {
      enum doMember = "";
    } else static if (is(typeof(__traits(getMember, T, MB[0])))) {
      static if (hasUDA!(__traits(getMember, T, MB[0]), slot)) {
        //pragma(msg, MB[0]);
        static if (is(typeof(getUDA!(__traits(getMember, T, MB[0]), slot))))
          enum slt = getUDA!(__traits(getMember, T, MB[0]), slot).signalName;
        else
          enum slt = "";
        enum doMember =
          srcobj~"."~(slt.length ? slt : MB[0].stringof[1..$-1])~
          ".connect!"~MB[0].stringof~"(this);\n"~
          doMember!(MB[1..$]);
      } else {
        enum doMember = doMember!(MB[1..$]);
      }
    } else {
      enum doMember = doMember!(MB[1..$]);
    }
  }
  //private enum mems = __traits(T, getMembers);
  enum AutoConnect = doMember!(__traits(allMembers, T));
}

// to allow calling `mixin(AutoConnect!("term", this));` from class/struct methods
public template AutoConnect(string srcobj, alias obj) if (is(typeof(obj) == class) || is(typeof(obj) == struct)) {
  enum AutoConnect = AutoConnect!(srcobj, typeof(obj));
}


version(unittest_signal)
unittest {
  static class A {
    @slot void onFuck () {}
    @slot("onShit") void crap () {}
    void piss () {};
  }

  pragma(msg, AutoConnect!("term", A));
}
