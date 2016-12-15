/* SR3C, a symbol ranking data compressor.
 *
 * This file implements a fast and effective data compressor.
 * The compression is on par (k8: i guess ;-) to gzip -7.
 * bzip2 -2 compresses slightly better than SR3C, but takes almost
 * three times as long. Furthermore, since bzip2 is  based on
 * Burrows-Wheeler block sorting, it can't be used in on-line
 * compression tasks.
 * Memory consumption of SR3C is currently around 4.5 MB per ongoing
 * compression and decompression.
 *
 * Author: Kenneth Oksanen <cessu@iki.fi>, 2008.
 * Copyright (C) Helsinki University of Technology.
 * D conversion by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 *
 * This code borrows many ideas and some paragraphs of comments from
 * Matt Mahoney's s symbol ranking compression program SR2 and Peter
 * Fenwicks SRANK, but otherwise all code has been implemented from
 * scratch.
 *
 * This file is distributed under the following license:
 *
 * The MIT License
 * Copyright (c) 2008 Helsinki University of Technology
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */
import std.stdio;
import iv.sr3c;


void main (string[] args) {
  assert(args.length == 4);
  SR3C ctx;

  ubyte[] idata;

  {
    auto fi = File(args[2]);
    idata = new ubyte[](cast(uint)fi.size);
    fi.rawRead(idata[]);
  }

  if (args[1] == "p") {
    auto fo = File(args[3], "w");
    ctx = new SR3C(
      (const(void)[] bytes, bool flush) {
        fo.rawWrite(bytes[]);
        return 0;
      });
    auto res = ctx.compress(idata[]);
    assert(res == 0);
    res = ctx.flush();
  } else if (args[1] == "u") {
    auto fo = File(args[3], "w");
    ctx = new SR3C(
      (const(void)[] bytes, bool flush) {
        fo.rawWrite(bytes[]);
        return 0;
      });
    auto res = ctx.uncompress(idata[]);
    assert(res == 0);
  }
}
