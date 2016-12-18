#!/usr/bin/env rdmd

import iv.cmdcon;
import iv.chromaprint;
import iv.encoding;
import iv.vfs.io;
import iv.xogg.tremor;


enum BUF_SIZE = 4096;
ubyte[BUF_SIZE] buffer;

__gshared uint seconds = 0;

void main (string[] args) {
  conRegVar!seconds("seconds", "how many seconds to process (0: whole song)");

  concmd("exec .config.rc tan");
  conProcessArgs!true(args);

  if (args.length != 2) assert(0, "filename?");
  string fname = args[1];

  int err;

  OggVorbis_File vf;
  bool eof = false;
  int currstream;

  err = ov_fopen(VFile(fname), &vf);
  if (err != 0) {
    assert(0, "Error opening file '"~fname~"'");
  } else {
    scope(exit) ov_clear(&vf);

    import std.string : fromStringz;

    vorbis_info* vi = ov_info(&vf, -1);

    long prevtime = -1;
    long totaltime = ov_time_total(&vf);

    stderr.writeln("Bitstream is ", vi.channels, " channel, ", vi.rate, "Hz");
    stderr.writeln("Encoded by: ", ov_comment(&vf, -1).vendor.fromStringz.recodeToKOI8);
    stderr.writeln("streams: ", ov_streams(&vf));
    stderr.writeln("bitrate: ", ov_bitrate(&vf));
    stderr.writefln("time: %d:%02d", totaltime/1000/60, totaltime/1000%60);

    if (auto vc = ov_comment(&vf, -1)) {
      foreach (immutable idx; 0..vc.comments) {
        stderr.writeln("  ", vc.user_comments[idx][0..vc.comment_lengths[idx]].recodeToKOI8);
      }
    }

    if (vi.channels < 1 || vi.channels > 2) {
      stderr.writeln("ERROR: vorbis channels (", vi.channels, ")");
      throw new Exception("vorbis error");
    }

    if (vi.rate < 1024 || vi.rate > 96000) {
      stderr.writeln("ERROR: vorbis sample rate (", vi.rate, ")");
      throw new Exception("vorbis error");
    }

    ChromaprintContext* cct = chromaprint_new();
    if (cct is null) throw new Exception("can't create ChromaPrint context");
    scope(exit) chromaprint_free(cct);

    if (chromaprint_start(cct, vi.rate, vi.channels) == 0) throw new Exception("can't initialize ChromaPrint context");
    //scope(exit) chromaprint_finish(cct);

    ulong total = 0;
    while (!eof) {
      auto ret = ov_read(&vf, buffer.ptr, BUF_SIZE, /*0, 2, 1,*/ &currstream);
      if (ret == 0) {
        // EOF
        eof = true;
      } else if (ret < 0) {
        // error in the stream
      } else {
        if (chromaprint_feed(cct, cast(const(short)*)buffer.ptr, ret/2) == 0) throw new Exception("error feeding ChromaPrint context");
        total += ret;
        //stderr.writeln(total/2.0/vi.channels/vi.rate*1000.0);
        //if (total >= 1024*1024*3) { stderr.writeln("ABORT!"); break; }
        if (seconds > 0) {
          if (total/2.0/vi.channels/vi.rate >= seconds) { stderr.writeln("ABORT at ", total, "!"); break; }
        }
      }
    }
    stderr.writeln("TOTAL=", total);

    chromaprint_finish(cct);

    {
      char *fp;
      if (chromaprint_get_fingerprint(cct, &fp) == 0) throw new Exception("can't create ChromaPrint fingerprint");
      scope(exit) chromaprint_dealloc(fp);
      import core.stdc.stdio : printf;
      printf("DURATION=%u\n", cast(uint)(totaltime/1000));
      printf("FINGERPRINT=%s\n", fp);
    }
  }
}
