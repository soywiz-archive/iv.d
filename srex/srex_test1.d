/*
 * Copyright 2012 Yichun "agentzh" Zhang
 * Copyright 2007-2009 Russ Cox.  All Rights Reserved.
 * Use of this source code is governed by a BSD-style
 *
 * Part of this code is from the NGINX opensource project: http://nginx.org/LICENSE
 *
 * This library is licensed under the BSD license.
 *
 * Copyright (c) 2012-2014 Yichun "agentzh" Zhang.
 *
 * Copyright (c) 2007-2009 Russ Cox, Google Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met:
 *
 *    * Redistributions of source code must retain the above copyright
 * notice, this list of conditions and the following disclaimer.
 *    * Redistributions in binary form must reproduce the above
 * copyright notice, this list of conditions and the following disclaimer
 * in the documentation and/or other materials provided with the
 * distribution.
 *    * Neither the name of Google, Inc. nor the names of its
 * contributors may be used to endorse or promote products derived from
 * this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
module srex_test /*is aliced*/;

import iv.alice;
import iv.vfs.io;
import iv.srex;


void main () {
  import std.utf : byChar;

  //enum str = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
  enum str = "abc \ndef";
  enum restr = `.*?\s+`;

  writeln("\n\n\n");

  //auto pre = RegExp.create("^a+bc|d".byChar);
  //auto re = RegExp.create("bc".byChar);
  auto re = RegExp.create(restr.byChar, SRFlags.Multiline);
  if (!re.valid) {
    writeln("*** ERROR at ", re.lastErrorPos, ": ", re.lastError);
    assert(0);
  }
  writeln("captures: ", re.captureCount);


  {
    writeln("======================================");
    Pike.Capture[64] ovec;
    auto ctx = Pike.create(re, ovec[]);
    auto res = ctx.exec(str);
    writeln("pike: ", res);
    if (res == 0) {
      foreach (immutable idx; 0..re.captureCount) {
        writeln("capture #", idx, ": s=", ovec[idx].s, "; e=", ovec[idx].e);
      }
    }
    writeln("======================================");
  }

  {
    writeln("======================================");
    auto ctx = Thompson.create(re);
    auto res = ctx.exec(str);
    writeln("thompson: ", res);
    writeln("======================================");
  }
}
