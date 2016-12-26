/* Copyright (c) 2007-2008 CSIRO
   Copyright (c) 2007-2009 Xiph.Org Foundation
   Written by Jean-Marc Valin */
/*
   Redistribution and use in source and binary forms, with or without
   modification, are permitted provided that the following conditions
   are met:

   - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

   - Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimer in the
   documentation and/or other materials provided with the distribution.

   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
   ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
   A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER
   OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
   EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
   PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
   PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
   LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
   NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
   SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
import std.conv : to;

import iv.cmdcon;
import iv.vfs;

import iv.libcelt;

import xalsa;


int main (string[] args) {
  int err;
  OpusCustomMode* mode;
  OpusCustomEncoder* enc;
  OpusCustomDecoder* dec;
  int len;
  opus_int32 frame_size, channels, rate;
  int bytes_per_packet;
  ubyte[OPUS_CUSTOM_MAX_PACKET] data;
  int complexity;
  opus_int32 skip;

  if (args.length != 7 && args.length != 8 && args.length != 3 && args.length != 2) {
    conwriteln("encode usage: opus_demo <rate> <channels> <frame size> <bytes per packet> [<complexity>] <input> <output>");
    conwriteln("decode usage: opus_demo <input> [<output>]");
    return 1;
  }

  if (args.length <= 3) {
    auto fi = VFile(args[1]);
    char[8] sign;
    fi.rawReadExact(sign[]);
    if (sign != "K8CELTV0") {
      conwriteln("invalid signature");
      return 1;
    }

    rate = fi.readNum!uint;
    channels = fi.readNum!ubyte;
    frame_size = fi.readNum!ushort;

    if (rate < 8000 || rate > 48000) { conwriteln("invalid sampling rate: ", rate); return 1; }
    if (frame_size < 1 || frame_size > 6000) { conwriteln("invalid frame size: ", frame_size); return 1; }
    if (channels < 1 || channels > 2) { conwriteln("invalid number of channels: ", channels); return 1; }

    mode = opus_custom_mode_create(rate, frame_size, null);
    if (mode is null) { conwriteln("can't create codec"); return 1; }
    scope(exit) opus_custom_mode_destroy(mode);

    dec = opus_custom_decoder_create(mode, channels, &err);
    if (err != 0) {
      conwriteln("Failed to create the decoder: ", opus_strerr(err));
      return 1;
    }
    scope(exit) opus_custom_decoder_destroy(dec);
    opus_custom_decoder_ctl(dec, OPUS_GET_LOOKAHEAD_REQUEST, &skip);

    VFile fo;
    bool doplay = true;
    if (args.length > 2) {
      fo = VFile(args[2], "w");
      doplay = false;
    }

    ubyte[] packet;
    short[] sound;
    sound.length = 48000*2;
    alsaOpen(channels);
    scope(exit) alsaClose();
    for (;;) {
      ubyte[2] bb;
      if (fi.rawRead(bb[0..1]).length == 0) break;
      if (fi.rawRead(bb[1..2]).length == 0) break;
      uint pktsize = bb[0]|(bb[1]<<8);
      if (pktsize < 1 || pktsize > OPUS_CUSTOM_MAX_PACKET) { conwriteln("invalid packet size: ", pktsize); return 1; }
      if (packet.length < pktsize) packet.length = pktsize;
      fi.rawReadExact(packet[0..pktsize]);
      auto ret = opus_custom_decode(dec, packet.ptr, cast(uint)packet.length, sound.ptr, cast(uint)sound.length);
      if (ret < 0) {
        conwriteln("decode failed: ", opus_strerr(ret));
        return 1;
      }
      if (skip < ret) {
        if (doplay) {
          alsaWriteX(sound.ptr+skip*channels, (ret-skip));
        } else {
          fo.rawWriteExact(sound[skip*channels..ret*channels]);
        }
        //fwrite(out+skip*channels, sizeof(short), (ret-skip)*channels, fout);
      }
      skip = 0;
    }
  } else {
    rate = args[1].to!opus_int32;
    channels = args[2].to!ubyte;
    frame_size = args[3].to!ushort;
    bytes_per_packet = args[4].to!ushort;

    if (rate < 8000 || rate > 48000) { conwriteln("invalid sampling rate: ", rate); return 1; }
    if (frame_size < 1 || frame_size > 6000) { conwriteln("invalid frame size: ", frame_size); return 1; }
    if (channels < 1 || channels > 2) { conwriteln("invalid number of channels: ", channels); return 1; }
    if (bytes_per_packet < 1 || bytes_per_packet > OPUS_CUSTOM_MAX_PACKET) { conwriteln("invalid packet size: ", bytes_per_packet); return 1; }

    mode = opus_custom_mode_create(rate, frame_size, null);
    if (mode is null) { conwriteln("can't create codec"); return 1; }
    scope(exit) opus_custom_mode_destroy(mode);

    auto fi = VFile(args[$-2]);
    auto fo = VFile(args[$-1], "w");

    enc = opus_custom_encoder_create(mode, channels, &err);
    if (err != 0) {
      conwriteln("Failed to create the encoder: ", opus_strerr(err));
      return 1;
    }
    scope(exit) opus_custom_encoder_destroy(enc);

    if (args.length > 7) {
      complexity = args[5].to!ubyte;
      if (complexity > 10) { conwriteln("invalid complexity: ", complexity); return 1; }
      opus_custom_encoder_ctl(enc, OPUS_SET_COMPLEXITY_REQUEST, complexity);
    }

    fo.rawWriteExact("K8CELTV0");
    fo.writeNum!uint(rate);
    fo.writeNum!ubyte(cast(ubyte)channels);
    fo.writeNum!ushort(cast(ushort)frame_size);

    short[] frame;
    frame.length = frame_size*channels;
    mainloop: for (;;) {
      uint pos = 0;
      while (pos < frame.length) {
        auto rd = fi.rawRead(frame[pos..$]);
        if (rd.length == 0) break mainloop; //FIXME
        pos += rd.length;
      }
      len = opus_custom_encode(enc, frame.ptr, frame_size, data.ptr, bytes_per_packet);
      if (len <= 0) {
        conwriteln("opus_custom_encode() failed: ", opus_strerr(len));
        return 1;
      }
      if (len > ushort.max) assert(0, "internal error");
      fo.writeNum!ushort(cast(ushort)len);
      fo.rawWriteExact(data[0..len]);
    }
  }
  return 0;
}

