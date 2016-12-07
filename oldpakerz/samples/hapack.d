/***********************************************************************
 * This file is part of HA, a general purpose file archiver.
 * Copyright (C) 1995 Harri Hirvola
 * Modified by Ketmar // Invisible Vector
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 ***********************************************************************/
module hapack;

import iv.oldpakerz.crc32;
import iv.oldpakerz.hapack;

import iv.cmdcon;
import iv.vfs;


// ////////////////////////////////////////////////////////////////////////// //
enum InFileName = "KA_HM.WAD";
enum OutFileName = "z00.hpk";


// ////////////////////////////////////////////////////////////////////////// //
void main () {
  auto fi = VFile(InFileName);
  auto fo = VFile(OutFileName, "w");

  uint crc = 0;

  libha_t ha = libha_alloc(
    (void *buf, int buf_len, void *udata) {
      auto b = cast(ubyte*)buf;
      auto rd = fi.rawRead(b[0..buf_len]);
      crc = wdx_crc32(rd, crc);
      return cast(int)rd.length;
    },
    (const(void)* buf, int buf_len, void *udata) {
      auto b = cast(const(ubyte)*)buf;
      fo.rawWriteExact(b[0..buf_len]);
      return buf_len;
    },
  );
  scope(exit) libha_free(ha);

  conwriteln("packing...");
  libha_pack_start(ha);
  while (libha_pack_step(ha)) {}
  libha_pack_finish(ha);
  conwriteln(fi.tell, " --> ", fo.tell);
  conwritefln!"crc: 0x%08x"(crc);
}
