/*-
 * Public Domain 2014-2016 MongoDB, Inc.
 * Public Domain 2008-2014 WiredTiger, Inc.
 *
 * This is free and unencumbered software released into the public domain.
 *
 * Anyone is free to copy, modify, publish, use, compile, sell, or
 * distribute this software, either in source code form or as a compiled
 * binary, for any purpose, commercial or non-commercial, and by any
 * means.
 *
 * In jurisdictions that recognize copyright laws, the author or authors
 * of this software dedicate any and all copyright interest in the
 * software to the public domain. We make this dedication for the benefit
 * of the public at large and to the detriment of our heirs and
 * successors. We intend this dedication to be an overt act of
 * relinquishment in perpetuity of all present and future rights to this
 * software under copyright law.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 * IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
 * OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
 * ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */
module iv.follin.rwlock;

/*
 * Based on "Spinlocks and Read-Write Locks" by Dr. Steven Fuerst:
 *  http://locklessinc.com/articles/locks/
 *
 * Dr. Fuerst further credits:
 *  There exists a form of the ticket lock that is designed for read-write
 * locks. An example written in assembly was posted to the Linux kernel mailing
 * list in 2002 by David Howells from RedHat. This was a highly optimized
 * version of a read-write ticket lock developed at IBM in the early 90's by
 * Joseph Seigh. Note that a similar (but not identical) algorithm was published
 * by John Mellor-Crummey and Michael Scott in their landmark paper "Scalable
 * Reader-Writer Synchronization for Shared-Memory Multiprocessors".
 *
 * The following is an explanation of this code. First, the underlying lock
 * structure.
 *
 *  struct {
 *    uint16_t writers; Now serving for writers
 *    uint16_t readers; Now serving for readers
 *    uint16_t users;   Next available ticket number
 *    uint16_t __notused; Padding
 *  }
 *
 * First, imagine a store's 'take a number' ticket algorithm. A customer takes
 * a unique ticket number and customers are served in ticket order. In the data
 * structure, 'writers' is the next writer to be served, 'readers' is the next
 * reader to be served, and 'users' is the next available ticket number.
 *
 * Next, consider exclusive (write) locks. The 'now serving' number for writers
 * is 'writers'. To lock, 'take a number' and wait until that number is being
 * served; more specifically, atomically copy and increment the current value of
 * 'users', and then wait until 'writers' equals that copied number.
 *
 * Shared (read) locks are similar. Like writers, readers atomically get the
 * next number available. However, instead of waiting for 'writers' to equal
 * their number, they wait for 'readers' to equal their number.
 *
 * This has the effect of queuing lock requests in the order they arrive
 * (incidentally avoiding starvation).
 *
 * Each lock/unlock pair requires incrementing both 'readers' and 'writers'.
 * In the case of a reader, the 'readers' increment happens when the reader
 * acquires the lock (to allow read-lock sharing), and the 'writers' increment
 * happens when the reader releases the lock. In the case of a writer, both
 * 'readers' and 'writers' are incremented when the writer releases the lock.
 *
 * For example, consider the following read (R) and write (W) lock requests:
 *
 *            writers readers users
 *            0 0 0
 *  R: ticket 0, readers match  OK  0 1 1
 *  R: ticket 1, readers match  OK  0 2 2
 *  R: ticket 2, readers match  OK  0 3 3
 *  W: ticket 3, writers no match block 0 3 4
 *  R: ticket 2, unlock     1 3 4
 *  R: ticket 0, unlock     2 3 4
 *  R: ticket 1, unlock     3 3 4
 *  W: ticket 3, writers match  OK  3 3 4
 *
 * Note the writer blocks until 'writers' equals its ticket number and it does
 * not matter if readers unlock in order or not.
 *
 * Readers or writers entering the system after the write lock is queued block,
 * and the next ticket holder (reader or writer) will unblock when the writer
 * unlocks. An example, continuing from the last line of the above example:
 *
 *            writers readers users
 *  W: ticket 3, writers match  OK  3 3 4
 *  R: ticket 4, readers no match block 3 3 5
 *  R: ticket 5, readers no match block 3 3 6
 *  W: ticket 6, writers no match block 3 3 7
 *  W: ticket 3, unlock     4 4 7
 *  R: ticket 4, readers match  OK  4 5 7
 *  R: ticket 5, readers match  OK  4 6 7
 *
 * The 'users' field is a 2-byte value so the available ticket number wraps at
 * 64K requests. If a thread's lock request is not granted until the 'users'
 * field cycles and the same ticket is taken by another thread, we could grant
 * a lock to two separate threads at the same time, and bad things happen: two
 * writer threads or a reader thread and a writer thread would run in parallel,
 * and lock waiters could be skipped if the unlocks race. This is unlikely, it
 * only happens if a lock request is blocked by 64K other requests. The fix is
 * to grow the lock structure fields, but the largest atomic instruction we have
 * is 8 bytes, the structure has no room to grow.
 */

/*
 * !!!
 * Don't modify this structure without understanding the read/write locking
 * functions.
 */
/* Read/write lock */
align(1) shared union TflRWLock {
nothrow @trusted @nogc:
align(1):
  ulong u;
  struct {
    align(1):
    uint wr;    /* Writers and readers */
  }
  struct {
    align(1):
    ushort writers; /* Now serving for writers */
    ushort readers; /* Now serving for readers */
    ushort users;   /* Next available ticket number */
    //ushort __notused; /* Padding */
  }

  //@disable this (this);

  // try to get a shared lock, fail immediately if unavailable
  bool tryReadLock () {
    import core.atomic;
    TflRWLock newl = void, old = void;
    newl = old = this;
    /*
     * This read lock can only be granted if the lock was last granted to
     * a reader and there are no readers or writers blocked on the lock,
     * that is, if this thread's ticket would be the next ticket granted.
     * Do the cheap test to see if this can possibly succeed (and confirm
     * the lock is in the correct state to grant this read lock).
     */
    if (old.readers != old.users) return false;
    /*
     * The replacement lock value is a result of allocating a newl ticket and
     * incrementing the reader value to match it.
     */
    newl.readers = newl.users = cast(ushort)(old.users+1);
    return (cas(&u, old.u, newl.u) ? true : false);
  }

  // et a shared lock
  void readLock () {
    import core.atomic;
    /*
     * Possibly wrap: if we have more than 64K lockers waiting, the ticket
     * value will wrap and two lockers will simultaneously be granted the
     * lock.
     */
    ushort ticket = cast(ushort)(atomicOp!"+="(users, 1)-1);
    for (int pause_cnt = 0; ticket != atomicLoad(readers); ) {
      /*
       * We failed to get the lock; pause before retrying and if we've
       * paused enough, sleep so we don't burn CPU to no purpose. This
       * situation happens if there are more threads than cores in the
       * system and we're thrashing on shared resources.
       *
       * Don't sleep long when waiting on a read lock, hopefully we're
       * waiting on another read thread to increment the reader count.
       */
      if (++pause_cnt < 1000) {
        asm nothrow @safe @nogc {
          db 0xf3,0x90; //pause;
        }
      } else {
        // one second is 1_000_000_000 nanoseconds or 1_000_000 microseconds or 1_000 milliseconds
        import core.sys.posix.signal : timespec;
        import core.sys.posix.time : nanosleep;
        timespec ts = void;
        ts.tv_sec = 0;
        ts.tv_nsec = 10*1000; // micro to nano
        nanosleep(&ts, null); // idc how much time was passed
      }
    }
    /*
     * We're the only writer of the readers field, so the update does not
     * need to be atomic. But stupid DMD insists. Alas.
     */
    //++readers;
    atomicOp!"+="(readers, 1);
  }

  // release a shared lock
  void readUnlock () {
    import core.atomic;
    /*
     * Increment the writers value (other readers are doing the same, make
     * sure we don't race).
     */
    cast(void)atomicOp!"+="(writers, 1);
  }

  // try to get an exclusive lock, fail immediately if unavailable
  bool tryWriteLock () {
    import core.atomic;
    TflRWLock newl = void, old = void;
    old = newl = this;
    /*
     * This write lock can only be granted if the lock was last granted to
     * a writer and there are no readers or writers blocked on the lock,
     * that is, if this thread's ticket would be the next ticket granted.
     * Do the cheap test to see if this can possibly succeed (and confirm
     * the lock is in the correct state to grant this write lock).
     */
    if (old.writers != old.users) return false;
    /* The replacement lock value is a result of allocating a newl ticket. */
    //++newl.users;
    atomicOp!"+="(newl.users, 1); // Stupid DMD insists. Alas.
    return (cas(&u, old.u, newl.u) ? true : false);
  }

  // wait to get an exclusive lock
  void writeLock () {
    import core.atomic;
    /*
     * Possibly wrap: if we have more than 64K lockers waiting, the ticket
     * value will wrap and two lockers will simultaneously be granted the
     * lock.
     */
    ushort ticket = cast(ushort)(atomicOp!"+="(users, 1)-1);
    for (int pause_cnt = 0; ticket != atomicLoad(writers); ) {
      /*
       * We failed to get the lock; pause before retrying and if we've
       * paused enough, sleep so we don't burn CPU to no purpose. This
       * situation happens if there are more threads than cores in the
       * system and we're thrashing on shared resources.
       */
      if (++pause_cnt < 1000) {
        asm nothrow @safe @nogc {
          db 0xf3,0x90; //pause;
        }
      } else {
        // one second is 1_000_000_000 nanoseconds or 1_000_000 microseconds or 1_000 milliseconds
        import core.sys.posix.signal : timespec;
        import core.sys.posix.time : nanosleep;
        timespec ts = void;
        ts.tv_sec = 0;
        ts.tv_nsec = 10*1000; // micro to nano
        nanosleep(&ts, null); // idc how much time was passed
      }
    }
  }

  // release an exclusive lock
  void writeUnlock () {
    import core.atomic;
    TflRWLock copy = this;
    /*
     * We're the only writer of the writers/readers fields, so the update
     * does not need to be atomic; we have to update both values at the
     * same time though, otherwise we'd potentially race with the thread
     * next granted the lock.
     *
     * Use a memory barrier to ensure the compiler doesn't mess with these
     * instructions and rework the code in a way that avoids the update as
     * a unit.
     */
    atomicFence();
    //++copy.writers;
    //++copy.readers;
    // Stupid DMD insists. Alas.
    atomicOp!"+="(copy.writers, 1);
    atomicOp!"+="(copy.readers, 1);
    wr = copy.wr;
  }
}
