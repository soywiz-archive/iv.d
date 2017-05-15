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
// stand-alone unpacker
module haunp is aliced;


// ////////////////////////////////////////////////////////////////////////// //
import iv.oldpakerz.crc32;
import iv.oldpakerz.haunpack;

import iv.cmdcon;
import iv.vfs;


// ////////////////////////////////////////////////////////////////////////// //
enum InFileName = "z00.hpk";
enum OutFileName = "z00.hpk.unp";


// ////////////////////////////////////////////////////////////////////////// //
void main () {
  auto fi = VFile(InFileName);
  auto fo = VFile(OutFileName, "w");

  uint crc = 0;

  haunp_t ha = haunp_create();
  scope(exit) haunp_free(ha);

  conwriteln("unpacking...");

  ubyte[1024] buf;
  for (;;) {
    auto rd = ha.haunp_read(buf[],
      (void* buf, int buf_len) {
        auto b = cast(ubyte*)buf;
        auto rd = fi.rawRead(b[0..buf_len]);
        return cast(int)rd.length;
      }
    );
    if (rd > 0) {
      crc = wdx_crc32(buf[0..rd], crc);
      fo.rawWriteExact(buf[0..rd]);
    }
    if (rd < buf.length) break;
  }

  conwriteln(fi.tell, " --> ", fo.tell);
  conwritefln!"crc: 0x%08x"(crc);
}
