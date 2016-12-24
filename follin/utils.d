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
module iv.follin.utils;

// ////////////////////////////////////////////////////////////////////////// //
version(X86) {
  version = follin_use_sse;
  version = follin_use_sse2;
}


// ////////////////////////////////////////////////////////////////////////// //
/// convert buffer of shorts to buffer of floats; will not resize output
public void tflShort2Float (in short[] input, float[] output) nothrow @trusted @nogc {
  if (output.length < input.length) assert(0, "invalid length");
  auto d = output.ptr;
  enum mul = cast(float)(1.0f/32768.0f);
  auto src = input.ptr;
  auto len = input.length;
  while (len >= 4) {
    *d++ = mul*(*src++);
    *d++ = mul*(*src++);
    *d++ = mul*(*src++);
    *d++ = mul*(*src++);
    len -= 4;
  }
  while (len-- > 0) *d++ = mul*(*src++);
}


// will not resize output
/// convert buffer of floats to buffer of shorts; will not resize output
public void tflFloat2Short (in float[] input, short[] output) nothrow @trusted @nogc {
  if (output.length < input.length) assert(0, "invalid length");
  auto s = input.ptr;
  auto d = output.ptr;
  /*ALIGN NOT WORKING YET:*/ version(follin_use_sse) {
    auto blen = cast(uint)input.length;
    if (blen > 0) {
      //TODO: use aligned instructions
      align(64) __gshared float[256] mvol = 32768.0;
      __gshared ubyte* mvolptr = null;
      if (mvolptr is null) {
        mvolptr = cast(ubyte*)mvol.ptr;
        if ((cast(uint)mvolptr&0x3f) != 0) {
          // fix pointer
          mvolptr += 0x40-cast(uint)mvolptr&0x3f;
          // and refill
          (cast(float*)mvolptr)[0..8] = 32768.0;
        }
      }
      float tmp;
      auto tmpptr = &tmp;
      asm nothrow @safe @nogc {
        mov       EAX,[mvolptr]; // source
        //movntdqa  XMM4,[EAX]; // XMM4: multipliers (sse4.1)
        movaps    XMM4,[EAX];
        mov       EAX,[s]; // source
        mov       EBX,[d]; // dest
        mov       ECX,[blen];
        mov       EDX,ECX;
        shr       ECX,2;
        jz        skip4part;
        // process 4 floats per step
        align 8;
       finalloopmix:
        movups    XMM0,[EAX];
        mulps     XMM0,XMM4;    // mul by volume and shift
      }
      version(follin_use_sse2) asm nothrow @safe @nogc {
        cvttps2dq XMM1,XMM0;    // XMM1 now contains four int32 values
        packssdw  XMM1,XMM1;
        movq      [EBX],XMM1;   // four s16 == one double
      } else asm nothrow @safe @nogc {
        cvtps2pi  MM0,XMM0;     // MM0 now contains two low int32 values
        movhlps   XMM5,XMM0;    // get high floats
        cvtps2pi  MM1,XMM5;     // MM1 now contains two high int32 values
        packssdw  MM0,MM1;      // MM0 now contains 4 int16 values
        movq      [EBX],MM0;
      }
      asm nothrow @safe @nogc {
        add       EAX,16;
        add       EBX,8;
        dec       ECX;
        jnz       finalloopmix;
       skip4part:
        test      EDX,2;
        jz        skip2part;
        // do 2 floats
        movsd     XMM0,[EAX];   // one double == two floats
      }
      version(follin_use_sse2) asm nothrow @safe @nogc {
        cvttps2dq XMM1,XMM0;    // XMM1 now contains int32 values
        packssdw  XMM1,XMM1;
        movd      [EBX],XMM1;   // one float == two s16
      } else asm nothrow @safe @nogc {
        cvtps2pi  MM0,XMM0;     // MM0 now contains two low int32 values
        movhlps   XMM5,XMM0;    // get high floats
        packssdw  MM0,MM1;      // MM0 now contains 4 int16 values
        movd      [EBX],MM0;
      }
      asm nothrow @safe @nogc {
        add       EAX,8;
        add       EBX,4;
       skip2part:
        test      EDX,1;
        jz        skip1part;
        movss     XMM0,[EAX];
      }
      version(follin_use_sse2) asm nothrow @safe @nogc {
        cvttps2dq XMM1,XMM0;    // XMM1 now contains int32 values
        packssdw  XMM1,XMM1;
        mov       EAX,[tmpptr];
        movss     [EAX],XMM1;
      } else asm nothrow @safe @nogc {
        cvtps2pi  MM0,XMM0;     // MM0 now contains two low int32 values
        movhlps   XMM5,XMM0;    // get high floats
        packssdw  MM0,MM1;      // MM0 now contains 4 int16 values
        mov       EAX,[tmpptr]
        movss     [EAX],MM0;
      }
      asm nothrow @safe @nogc {
        mov       CX,[EAX];
        mov       [EBX],CX;
       skip1part:;
      }
      version(follin_use_sse2) {} else {
        asm nothrow @safe @nogc { emms; }
      }
    }
  } else {
    mixin(declfcvar!"temp");
    foreach (immutable _; 0..input.length) {
      mixin(FAST_SCALED_FLOAT_TO_INT!("*s", "15"));
      if (cast(uint)(v+32768) > 65535) v = (v < 0 ? -32768 : 32767);
      *d++ = cast(short)v;
      ++s;
    }
  }
}
