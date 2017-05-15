/*
 * MPEG Audio Layer III decoder
 * Copyright (c) 2001, 2002 Fabrice Bellard,
 *           (c) 2007 Martin J. Fiedler
 *
 * D conversion by Ketmar // Invisible Vector
 *
 * This file is a stripped-down version of the MPEG Audio decoder from
 * the FFmpeg libavcodec library.
 *
 * FFmpeg and minimp3 are free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * FFmpeg and minimp3 are distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with FFmpeg; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */
module iv.mp3scan is aliced;


// ////////////////////////////////////////////////////////////////////////// //
enum Mp3Max {
  FrameSize = 1152, // maxinum frame size
  Channels = 2,
}

enum Mp3Mode {
  Stereo = 0,
  JStereo = 1,
  Dual = 2,
  Mono = 3,
}


// ////////////////////////////////////////////////////////////////////////// //
struct Mp3Info {
  uint sampleRate;
  ubyte channels;
  ulong samples;
  Mp3Mode mode;
  uint bitrate;
  long id3v1ofs;
  uint id3v1size;
  long id3v2ofs;
  uint id3v2size;

  static struct Index { ulong fpos; ulong samples; } // samples done before this frame (*multiplied* by channels)
  Index[] index; // WARNING: DON'T STORE SLICES OF IT!

  @property bool valid () const pure nothrow @safe @nogc { return (sampleRate != 0); }
  @property bool hasID3v1 () const pure nothrow @safe @nogc { return (id3v1size == 128); }
  @property bool hasID3v2 () const pure nothrow @safe @nogc { return (id3v2size > 10); }
}


Mp3Info mp3Scan(bool buildIndex=false, RDG) (scope RDG rdg) if (is(typeof({
  ubyte[2] buf;
  int rd = rdg(buf[]);
}))) {
  Mp3Info info;
  bool eofhit;
  ubyte[4096] inbuf;
  uint inbufpos, inbufused;
  Mp3Ctx s;
  uint headersCount;
  ulong bytesRead = 0;

  ulong streamOfs () { pragma(inline, true); return bytesRead-inbufused+inbufpos; }

  void fillInputBuffer () {
    if (inbufpos < inbufused) {
      import core.stdc.string : memmove;
      if (inbufused-inbufpos >= 1800) return; // no need to get more data
      if (inbufpos > 0) memmove(inbuf.ptr, inbuf.ptr+inbufpos, inbufused-inbufpos);
      inbufused -= inbufpos;
      inbufpos = 0;
    } else {
      inbufpos = inbufused = 0;
    }
    // read more bytes
    while (!eofhit && inbufused < inbuf.length) {
      int rd = rdg(inbuf[inbufused..$]);
      if (rd <= 0) {
        eofhit = true;
      } else {
        bytesRead += rd;
        inbufused += rd;
      }
    }
  }

  bool skipBytes (uint count) {
    while (!eofhit && count > 0) {
      auto left = inbufused-inbufpos;
      if (left == 0) {
        fillInputBuffer();
      } else {
        if (left <= count) {
          // eat whole buffer
          inbufused = inbufpos = 0;
          count -= left;
        } else {
          // eat buffer part
          inbufpos += count;
          count = 0;
        }
      }
    }
    return (count == 0);
  }

  // now skip frames
  while (!eofhit) {
    fillInputBuffer();
    auto left = inbufused-inbufpos;
    if (left < Mp3HeaderSize) break;
    // check for tags
    // check for ID3v2
    if (info.id3v2size == 0 && left >= 10 && inbuf.ptr[inbufpos+0] == 'I' && inbuf.ptr[inbufpos+1] == 'D' && inbuf.ptr[inbufpos+2] == '3' && inbuf.ptr[inbufpos+3] != 0xff && inbuf.ptr[inbufpos+4] != 0xff &&
        ((inbuf.ptr[inbufpos+6]|inbuf.ptr[inbufpos+7]|inbuf.ptr[inbufpos+8]|inbuf.ptr[inbufpos+9])&0x80) == 0) { // see ID3v2 specs
      // get tag size
      uint sz = (inbuf.ptr[inbufpos+9]|(inbuf.ptr[inbufpos+8]<<7)|(inbuf.ptr[inbufpos+7]<<14)|(inbuf.ptr[inbufpos+6]<<21))+10;
      if (sz > 10) {
        info.id3v2ofs = streamOfs;
        info.id3v2size = sz;
      }
      // skip `sz` bytes, it's a tag
      skipBytes(sz);
      continue;
    }
    // check for ID3v1
    if (info.id3v1size == 0 && left >= 3 && inbuf.ptr[inbufpos+0] == 'T' && inbuf.ptr[inbufpos+1] == 'A' && inbuf.ptr[inbufpos+2] == 'G') {
      // this may be ID3v1, just skip 128 bytes
      info.id3v1ofs = streamOfs;
      info.id3v1size = 128;
      skipBytes(128);
      continue;
    }
    int res = mp3SkipFrame(s, inbuf.ptr+inbufpos, left); // return bytes used in buffer or -1
    debug(mp3scan_verbose) { import core.stdc.stdio : printf; printf("FRAME: res=%d; valid=%u; frame_size=%d; samples=%d (%u) read=%u (inbufpos=%u; inbufused=%u)\n", res, (s.valid ? 1 : 0), s.frame_size, s.sample_count, headersCount, cast(uint)bytesRead, inbufpos, inbufused); }
    if (res < 0) {
      // no frame found in the buffer, get more data
      // but left at least Mp3HeaderSize old bytes
      assert(inbufused >= Mp3HeaderSize);
      inbufpos = inbufused-Mp3HeaderSize;
    } else if (!s.valid) {
      // got header, but there is not enough data for it
      inbufpos += (res > Mp3HeaderSize ? res-Mp3HeaderSize : 1); // move to header
    } else {
      // got valid frame
      static if (buildIndex) {
        auto optr = info.index.ptr;
        info.index ~= info.Index(streamOfs, info.samples);
        if (info.index.ptr !is optr) {
          import core.memory : GC;
          if (info.index.ptr is GC.addrOf(info.index.ptr)) GC.setAttr(info.index.ptr, GC.BlkAttr.NO_INTERIOR);
          //GC.collect(); // somehow this fixes amper
        }
      }
      inbufpos += res; // move past frame
      if (++headersCount == 0) headersCount = uint.max;
      if (!info.valid) {
        // if first found frame is invalid... consider the whole file invalid
        if (s.sample_rate < 1024 || s.sample_rate > 96000) break;
        if (s.nb_channels < 1 || s.nb_channels > 2) break;
        info.sampleRate = s.sample_rate;
        info.channels = cast(ubyte)s.nb_channels;
        info.mode = cast(Mp3Mode)s.mode;
        info.bitrate = s.bit_rate;
      }
      info.samples += s.sample_count*s.nb_channels;
    }
  }
  debug(mp3scan_verbose) { import core.stdc.stdio : printf, fflush, stdout; printf("%u\n", headersCount); fflush(stdout); }
  if (headersCount < 6) info = info.default;
  return info;
}


// ////////////////////////////////////////////////////////////////////////// //
private nothrow @nogc {


// ////////////////////////////////////////////////////////////////////////// //
struct Mp3Ctx {
  int frame_size;
  int error_protection;
  int sample_rate;
  int sample_rate_index;
  int bit_rate;
  int nb_channels;
  int sample_count;
  int mode;
  int mode_ext;
  int lsf;
  uint last_header; //&0xffff0c00u;
  bool valid;
}


// ////////////////////////////////////////////////////////////////////////// //
enum Mp3HeaderSize = 4;


// ////////////////////////////////////////////////////////////////////////// //
bool mp3CheckHeader (uint header) pure @safe {
  // header
  if ((header&0xffe00000u) != 0xffe00000u) return false;
  // layer check
  if ((header&(3<<17)) != (1<<17)) return false;
  // bit rate
  if ((header&(0xf<<12)) == 0xf<<12) return false;
  // frequency
  if ((header&(3<<10)) == 3<<10) return false;
  // seems to be acceptable
  return true;
}


bool mp3DecodeHeader (ref Mp3Ctx s, uint header) @trusted {
  static immutable ushort[15][2] mp3_bitrate_tab = [
    [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320 ],
    [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160]
  ];

  static immutable ushort[3] mp3_freq_tab = [ 44100, 48000, 32000 ];

  static immutable short[4][4] sampleCount = [
    [0, 576, 1152, 384], // v2.5
    [0, 0, 0, 0], // reserved
    [0, 576, 1152, 384], // v2
    [0, 1152, 1152, 384], // v1
  ];
  ubyte mpid = (header>>19)&0x03;
  ubyte layer = (header>>17)&0x03;

  s.sample_count = sampleCount.ptr[mpid].ptr[layer];

  int sample_rate, frame_size, mpeg25, padding;
  int sample_rate_index, bitrate_index;
  if (header&(1<<20)) {
    s.lsf = (header&(1<<19) ? 0 : 1);
    mpeg25 = 0;
  } else {
    s.lsf = 1;
    mpeg25 = 1;
  }

  sample_rate_index = (header>>10)&3;
  sample_rate = mp3_freq_tab[sample_rate_index]>>(s.lsf+mpeg25);
  sample_rate_index += 3*(s.lsf+mpeg25);
  s.sample_rate_index = sample_rate_index;
  s.error_protection = ((header>>16)&1)^1;
  s.sample_rate = sample_rate;

  bitrate_index = (header>>12)&0xf;
  padding = (header>>9)&1;
  s.mode = (header>>6)&3;
  s.mode_ext = (header>>4)&3;
  s.nb_channels = (s.mode == Mp3Mode.Mono ? 1 : 2);

  if (bitrate_index == 0) return false; // no frame size computed, signal it
  frame_size = mp3_bitrate_tab[s.lsf][bitrate_index];
  s.bit_rate = frame_size*1000;
  s.frame_size = (frame_size*144000)/(sample_rate<<s.lsf)+padding;
  return true;
}


// return bytes used in `buf` or -1 if no header was found
// will set `s.valid` if fully valid header was skipped
// i.e. if it returned something that is not -1, and s.valid == false,
// it means that frame header is ok at the given offset, but there is
// no data to skip the full header; so caller may read more data and
// restart from that offset.
int mp3SkipFrame (ref Mp3Ctx s, const(void)* buff, int bufsize) @trusted {
  auto buf = cast(const(ubyte)*)buff;
  s.valid = false;
  int bufleft = bufsize;
  while (bufleft >= Mp3HeaderSize) {
    uint header = (buf[0]<<24)|(buf[1]<<16)|(buf[2]<<8)|buf[3];
    if (mp3CheckHeader(header)) {
      if (s.last_header == 0 || (header&0xffff0c00u) == s.last_header) {
        if (mp3DecodeHeader(s, header)) {
          if (s.frame_size <= 0 || s.frame_size > bufleft) {
            // incomplete frame
            s.valid = false;
          } else {
            s.valid = true;
            bufleft -= s.frame_size;
            s.last_header = header&0xffff0c00u;
            //s.frame_size += extra_bytes;
          }
          return bufsize-bufleft;
        }
      }
    }
    ++buf;
    --bufleft;
  }
  return -1;
}

}


// ////////////////////////////////////////////////////////////////////////// //
/+
import iv.cmdcon;
import iv.vfs;

void main (string[] args) {
  if (args.length == 1) args ~= "melodie_128.mp3";

  auto fl = VFile(args[1]);

  auto info = mp3Scan!true((void[] buf) {
    auto rd = fl.rawRead(buf[]);
    return cast(uint)rd.length;
  });
  //conwriteln(fl.tell);

  if (!info.valid) {
    conwriteln("invalid MP3 file!");
  } else {
    conwriteln("sample rate: ", info.sampleRate, " Hz");
    conwriteln("channels   : ", info.channels);
    conwriteln("samples    : ", info.samples);
    conwriteln("mode       : ", info.mode);
    conwriteln("bitrate    : ", info.bitrate/1000, " kbps");
    auto seconds = info.samples/info.sampleRate;
    conwritefln!"time: %2s:%02s"(seconds/60, seconds%60);
    if (info.index.length) conwriteln(info.index.length, " index entries");
    foreach (immutable idx, const ref i; info.index) {
      if (idx > 4) break;
      conwriteln(idx, ": ", i);
    }
  }
}
+/
