/* Invisible Vector Library
 * coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
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
module iv.prng.seeder /*is aliced*/;
import iv.alice;


public uint xyzzyPRNGHashU32() (uint a) {
  a -= (a<<6);
  a ^= (a>>17);
  a -= (a<<9);
  a ^= (a<<4);
  a -= (a<<3);
  a ^= (a<<10);
  a ^= (a>>15);
  return a;
}


public uint getTwoUintSeeds (uint* second=null) nothrow @trusted @nogc {
  version(Windows) {
    import win32.windef, win32.winbase;
    uint s0 = xyzzyPRNGHashU32(cast(uint)GetCurrentProcessId());
    uint s1 = xyzzyPRNGHashU32(cast(uint)GetTickCount());
    if (second is null) return s0^s1;
    *second = s1;
    return s0;
  } else {
    // assume POSIX
    import core.sys.posix.fcntl;
    import core.sys.posix.unistd;
    uint s0 = 0xdeadf00du;
    int fd = open("/dev/urandom", O_RDONLY);
    if (fd >= 0) {
      // assume that we always have endless supply of bytes from that
      read(fd, &s0, s0.sizeof);
      if (second !is null) read(fd, second, (*second).sizeof);
      close(fd);
      return s0;
    }
    // try something another
    import core.sys.posix.unistd;
    import core.sys.posix.time;
    s0 = cast(uint)xyzzyPRNGHashU32(cast(uint)getpid());
    timespec stt = void;
    if (clock_gettime(CLOCK_MONOTONIC, &stt) == 0) {
      uint s1 = xyzzyPRNGHashU32(cast(uint)(stt.tv_sec^stt.tv_sec));
      if (second is null) return s0^s1;
      *second = s1;
      return s0;
    }
    if (second is null) *second = xyzzyPRNGHashU32(s0);
    return s0;
  }
}


public ulong getUlongSeed () nothrow @trusted @nogc {
  uint s1;
  uint s0 = getTwoUintSeeds(&s1);
  return ((cast(ulong)s1)<<32)|s0;
}
