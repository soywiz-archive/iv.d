/*
Copyright (c) 2016, Ketmar // Invisible Vector

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:

- Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.

- Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the distribution.

- Neither the name of the Xiph.org Foundation nor the names of its
contributors may be used to endorse or promote products derived from
this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION
OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
import std.stdio;
import iv.alsa;

import iv.xogg.tremor;


string recodeToKOI8 (const(char)[] s) {
  immutable wchar[128] charMapKOI8 = [
    '\u2500','\u2502','\u250C','\u2510','\u2514','\u2518','\u251C','\u2524','\u252C','\u2534','\u253C','\u2580','\u2584','\u2588','\u258C','\u2590',
    '\u2591','\u2592','\u2593','\u2320','\u25A0','\u2219','\u221A','\u2248','\u2264','\u2265','\u00A0','\u2321','\u00B0','\u00B2','\u00B7','\u00F7',
    '\u2550','\u2551','\u2552','\u0451','\u0454','\u2554','\u0456','\u0457','\u2557','\u2558','\u2559','\u255A','\u255B','\u0491','\u255D','\u255E',
    '\u255F','\u2560','\u2561','\u0401','\u0404','\u2563','\u0406','\u0407','\u2566','\u2567','\u2568','\u2569','\u256A','\u0490','\u256C','\u00A9',
    '\u044E','\u0430','\u0431','\u0446','\u0434','\u0435','\u0444','\u0433','\u0445','\u0438','\u0439','\u043A','\u043B','\u043C','\u043D','\u043E',
    '\u043F','\u044F','\u0440','\u0441','\u0442','\u0443','\u0436','\u0432','\u044C','\u044B','\u0437','\u0448','\u044D','\u0449','\u0447','\u044A',
    '\u042E','\u0410','\u0411','\u0426','\u0414','\u0415','\u0424','\u0413','\u0425','\u0418','\u0419','\u041A','\u041B','\u041C','\u041D','\u041E',
    '\u041F','\u042F','\u0420','\u0421','\u0422','\u0423','\u0416','\u0412','\u042C','\u042B','\u0417','\u0428','\u042D','\u0429','\u0427','\u042A',
  ];
  string res;
  foreach (dchar ch; s) {
    if (ch < 128) {
      if (ch < ' ') ch = ' ';
      if (ch == 127) ch = '?';
      res ~= cast(char)ch;
    } else {
      bool found = false;
      foreach (immutable idx, wchar wch; charMapKOI8[]) {
        if (wch == ch) { res ~= cast(char)(idx+128); found = true; break; }
      }
      if (!found) res ~= '?';
    }
  }
  return res;
}


enum device = "plug:default";

enum BUF_SIZE = 4096;
ubyte[BUF_SIZE] buffer;


void main (string[] args) {
  import std.string : toStringz;

  if (args.length != 2) assert(0, "file?!");

  int err;
  snd_pcm_t *handle;
  snd_pcm_sframes_t frames;

  OggVorbis_File vf;
  int eof = 0;
  int current_section;

  err = ov_fopen(args[1].toStringz, &vf);
  if (err != 0) {
    assert(0, "Error opening file");
  } else {
    import std.string : fromStringz;
    vorbis_info *vi = ov_info(&vf, -1);
    writeln("Bitstream is ", vi.channels, " channel, ", vi.rate, "Hz");
    writeln("Encoded by: ", ov_comment(&vf, -1).vendor.fromStringz.recodeToKOI8);

    if (auto vc = ov_comment(&vf, -1)) {
      foreach (immutable idx; 0..vc.comments) {
        writeln("  ", vc.user_comments[idx][0..vc.comment_lengths[idx]].recodeToKOI8);
      }
    }

    if (vi.channels < 1 || vi.channels > 2) assert(0, "vorbis channels");
    if (vi.rate < 1024 || vi.rate > 96000) assert(0, "vorbis rate");

    //writeln("pcmlengths=", vf.pcmlengths);

    if ((err = snd_pcm_open(&handle, device, SND_PCM_STREAM_PLAYBACK, 0)) < 0) {
      import core.stdc.stdio : printf;
      import core.stdc.stdlib : exit, EXIT_FAILURE;
      printf("Playback open error: %s\n", snd_strerror(err));
      exit(EXIT_FAILURE);
    }

    if ((err = snd_pcm_set_params(handle, SND_PCM_FORMAT_S16_LE, SND_PCM_ACCESS_RW_INTERLEAVED, /*2*/vi.channels, /*44100*/vi.rate, 1, 500000)) < 0) {
      import core.stdc.stdio : printf;
      import core.stdc.stdlib : exit, EXIT_FAILURE;
      printf("Playback open error: %s\n", snd_strerror(err));
      exit(EXIT_FAILURE);
    }

    while (!eof) {
      auto ret = ov_read(&vf, buffer.ptr, BUF_SIZE, /*0, 2, 1,*/ &current_section);
      if (ret == 0) {
        // EOF
        eof = 1;
      } else if (ret < 0) {
        // error in the stream
      } else {
        frames = snd_pcm_writei(handle, buffer.ptr, ret/(2*vi.channels));
        if (frames < 0) frames = snd_pcm_recover(handle, cast(int)frames, 0);
        if (frames < 0) {
          import core.stdc.stdio : printf;
          printf("snd_pcm_writei failed: %s\n", snd_strerror(err));
          break;
        }
        //if (frames > 0 && frames < ret/(2*vi.channels)) printf("Short write (expected %li, wrote %li)\n", ret, frames);
      }
    }
    ov_clear(&vf);
  }

  snd_pcm_close(handle);
}
