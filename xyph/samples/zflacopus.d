#!/usr/bin/env rdmd
module zflacvt is aliced;

import iv.drflac;
import iv.cmdcon;
import iv.cuefile;
import iv.encoding;
import iv.strex;
import iv.vfs;
import iv.vfs.io;


// ////////////////////////////////////////////////////////////////////////// //
__gshared ushort kbps = 192;
__gshared ubyte comp = 10;
__gshared int progressms = 500;
__gshared uint toffset = 0;
__gshared uint tmax = 0;
__gshared bool dbgShowArgs;

shared static this () {
  conRegVar!dbgShowArgs("dbg_show_args", "debug: show opusenc args");
  conRegVar!kbps(64, 320, "kbps", "opus encoding kbps");
  conRegVar!comp(0, 10, "comp", "opus compression quality");
  conRegVar!progressms("progress_time", "progress update time, in milliseconds (-1: don't show progress)");
  conRegVar!toffset("toffset", "track offset");
  conRegVar!tmax("tmax", "maxumum track number (0: default)");
}



// ////////////////////////////////////////////////////////////////////////// //
enum READ = 1024; // there is no reason to use bigger buffer
int[READ*2] smpbuffer; // out of the data segment, not the stack


// ////////////////////////////////////////////////////////////////////////// //
void makeOggs (string flacfile, ref CueFile cue, ushort kbps) {
  import std.file : mkdirRecurse;
  import std.string : toStringz;

  short[] xopbuf;

  import core.stdc.stdlib : malloc, free;
  drflac* flc;
  uint commentCount;
  char* fcmts;
  scope(exit) if (fcmts !is null) free(fcmts);

  /+
  flc = drflac_open_file_with_metadata(flacfile.toStringz, (void* pUserData, drflac_metadata* pMetadata) {
    if (pMetadata.type == DRFLAC_METADATA_BLOCK_TYPE_VORBIS_COMMENT) {
      if (fcmts !is null) free(fcmts);
      auto csz = drflac_vorbis_comment_size(pMetadata.data.vorbis_comment.commentCount, pMetadata.data.vorbis_comment.comments);
      if (csz > 0 && csz < 0x100_0000) {
        fcmts = cast(char*)malloc(cast(uint)csz);
      } else {
        fcmts = null;
      }
      if (fcmts is null) {
        commentCount = 0;
      } else {
        import core.stdc.string : memcpy;
        commentCount = pMetadata.data.vorbis_comment.commentCount;
        memcpy(fcmts, pMetadata.data.vorbis_comment.comments, cast(uint)csz);
      }
    }
  });
  +/

  flc = drflac_open_file(flacfile);
  if (flc is null) throw new Exception("can't open input file");
  scope(exit) drflac_close(flc);


  if (flc.sampleRate < 1024 || flc.sampleRate > 96000) throw new Exception("invalid flac sample rate");
  if (flc.channels < 1 || flc.channels > 2) throw new Exception("invalid flac channel number");
  if (flc.totalSampleCount%flc.channels != 0) throw new Exception("invalid flac sample count");

  writeln(flc.sampleRate, "Hz, ", flc.channels, " channels; kbps=", kbps, "; comp=", comp);

  writeln("=======================");
  if (cue.artist.length) writeln("ARTIST: <", cue.artist.recodeToKOI8, ">");
  if (cue.album.length) writeln("ALBUM : <", cue.album.recodeToKOI8, ">");
  if (cue.genre.length) writeln("GENRE : <", cue.genre.recodeToKOI8, ">");
  if (cue.year) writeln("YEAR  : <", cue.year, ">");

  void encodeSamples (const(char)[] outfname, uint tidx, ulong totalSamples) {
    import std.internal.cstring;
    import std.conv : to;
    import std.process;

    string[] args;

    args ~= "opusenc";
    args ~= "--quiet";

    // metadata args
    args ~= ["--padding", "0"];

    void addTag (string name, string value) {
      name = name.xstrip;
      value = value.xstrip;
      if (name.length == 0) return;
      if (value.length == 0) return;
      bool doFix = false;
      foreach (char ch; name) {
        if (ch >= 127 || ch == '=') assert(0, "tag name is fucked: '"~name~"'");
        if (ch >= 'a' && ch <= 'z') { doFix = true; break; }
      }
      if (doFix) {
        string s;
        foreach (char ch; name) {
          if (ch >= 'a' && ch <= 'z') ch -= 32;
          s ~= ch;
        }
        name = s;
      }
      assert(value.length);
      args ~= ["--comment", name~"="~value];
    }

    {
      string val = cue.tracks[tidx].artist;
      if (val.length == 0) val = cue.artist;
      addTag("ARTIST", val);
    }
         if (cue.tracks[tidx].year) addTag("DATE", cue.tracks[tidx].year.to!string);
    else if (cue.year) addTag("DATE", cue.year.to!string);
    addTag("ALBUM", cue.album);
    {
      string val = cue.tracks[tidx].title;
      if (val.length == 0) val = cue.album;
      if (val.length == 0) val = "untitled";
      addTag("TITLE", val);
    }
    {
      string val = cue.tracks[tidx].genre;
      if (val.length == 0) val = cue.genre;
      addTag("GENRE", val);
    }
    {
      string val = cue.tracks[tidx].artist;
      if (val.length == 0) val = cue.artist;
      addTag("PERFORMER", val);
    }
    addTag("TRACKNUMBER", (tidx+1+toffset).to!string);
    addTag("TRACKTOTAL", (tmax ? tmax : cue.tracks.length+toffset).to!string);

    // raw data format
    args ~= "--raw";
    args ~= ["--raw-bits", "16"];
    args ~= ["--raw-rate", flc.sampleRate.to!string];
    args ~= ["--raw-chan", flc.channels.to!string];

    args ~= ["--comp", comp.to!string];

    args ~= ["--bitrate", kbps.to!string];

    args ~= "-"; // input: stdin
    args ~= outfname.idup; // output

    if (dbgShowArgs) writeln("args: ", args);
    auto ppc = pipeProcess(args, Redirect.stdin, null, Config.retainStdout|Config.retainStderr);
    if (!ppc.stdin.isOpen) assert(0, "fuuuuu");

    import core.time;
    long samplesDone = 0, prc = 0;
    MonoTime lastPrcTime = MonoTime.currTime;
    if (progressms >= 0) write("  0%");
    for (;;) {
      uint rdsmp = cast(uint)(totalSamples-samplesDone > smpbuffer.length ? smpbuffer.length : totalSamples-samplesDone);
      if (rdsmp == 0) break;
      auto rdx = cast(int)drflac_read_s32(flc, rdsmp, smpbuffer.ptr); // interleaved 32-bit samples
      if (rdx < 1) {
        // alas -- the thing that should not be
        writeln("FUCK!");
      } else {
        samplesDone += rdx;
        if (progressms >= 0) {
          auto nprc = 100*samplesDone/totalSamples;
          if (nprc != prc) {
            auto ctt = MonoTime.currTime;
            if ((ctt-lastPrcTime).total!"msecs" >= progressms) {
              lastPrcTime = ctt;
              if (prc >= 0) write("\x08\x08\x08\x08");
              prc = nprc;
              writef("%3d%%", prc);
            }
          }
        }

        // convert samples from 32 bit to 16 bit
        if (xopbuf.length < rdx) xopbuf.length = rdx;
        auto s = smpbuffer.ptr;
        auto d = xopbuf.ptr;
        foreach (immutable i; 0..rdx) {
          int n = *s++;
          n >>= 16;
          if (n < short.min) n = short.min; else if (n > short.max) n = short.max;
          *d++ = cast(short)n;
        }

        ppc.stdin.rawWrite(xopbuf[0..rdx]);
      }
    }
    ppc.stdin.flush();
    ppc.stdin.close();
    wait(ppc.pid);

    if (progressms >= 0) {
      if (prc >= 0) write("\x08\x08\x08\x08");
    }
    writeln("... DONE");
  }

  mkdirRecurse("opus");
  ulong samplesProcessed = 0;
  foreach (immutable tidx, ref trk; cue.tracks) {
    import std.format : format;
    string fname;
    if (trk.title.length) fname = CueFile.koi2trlocase(trk.title.recodeToKOI8); else fname = "untitled";
    string ofname = "opus/%02d_%s.opus".format(tidx+1+toffset, fname);
    write("[", tidx+1, "/", cue.tracks.length, "] ", (trk.title.length ? trk.title.recodeToKOI8 : "untitled"), " -> ", ofname, " ");
    ulong smpstart, smpend;
    if (tidx == 0) smpstart = 0; else smpstart = cast(ulong)((trk.startmsecs/1000.0)*flc.sampleRate)*flc.channels;
    if (smpstart != samplesProcessed) assert(0, "index fucked");
    if (tidx == cue.tracks.length-1) smpend = flc.totalSampleCount; else smpend = cast(ulong)((cue.tracks[tidx+1].startmsecs/1000.0)*flc.sampleRate)*flc.channels;
    if (smpend <= samplesProcessed) assert(0, "index fucked");
    samplesProcessed = smpend;
    try { import std.file : remove; ofname.remove; } catch (Exception) {}
    encodeSamples(ofname, tidx, smpend-smpstart);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
void main (string[] args) {
  import std.path;
  import std.file : exists;

  concmd("exec .encoder.rc tan");
  conProcessArgs!true(args);

  string flacfile, cuefile;

  if (args.length < 2) {
    import std.file : dirEntries, DirEntry, SpanMode;
    foreach (DirEntry de; dirEntries(".", SpanMode.shallow)) {
      import std.path;
      if (de.isFile && de.extension.strEquCI(".cue")) {
        if (args.length == 2) assert(0, "filename?");
        args ~= de.name;
      }
    }
    if (args.length < 2) assert(0, "filename?");
  }

  void findFlac (string dir) {
    import std.file;
    flacfile = null;
    foreach (DirEntry de; dirEntries(dir, "*.flac", SpanMode.shallow)) {
      if (de.isFile) {
        if (flacfile.length) assert(0, "too many flac files");
        //writeln("flac: <", de.name, ">");
        flacfile = de.name;
      }
    }
    if (flacfile.length == 0) assert(0, "no flac file");
  }

  void findCue (string dir) {
    //writeln("dir: <", dir, ">");
    import std.file;
    cuefile = null;
    foreach (DirEntry de; dirEntries(dir, "*.cue", SpanMode.shallow)) {
      if (de.isFile) {
        //writeln("cue: <", de.name, ">");
        if (cuefile.length) assert(0, "too many cue files");
        cuefile = de.name;
      }
    }
    if (cuefile.length == 0) assert(0, "no cue file");
  }


  if (args.length < 2) assert(0, "input file?");
  flacfile = args[1];
  if (args.length > 2) {
    if (args.length > 3) assert(0, "too many input files");
    if (flacfile.extension.strEquCI(".flac")) {
      cuefile = args[2];
      if (cuefile.extension.strEquCI(".cue")) assert(0, "invalid input files");
    } else if (flacfile.extension.strEquCI(".cue")) {
      cuefile = flacfile;
      flacfile = args[2];
      if (flacfile.extension.strEquCI(".flac")) assert(0, "invalid input files");
    } else {
      assert(0, "invalid input files");
    }
  } else {
    if (flacfile.extension.strEquCI(".cue")) {
      cuefile = flacfile;
      flacfile = cuefile.setExtension(".flac");
      if (!flacfile.exists) findFlac(flacfile.dirName);
    } else if (flacfile.extension.strEquCI(".flac")) {
      cuefile = flacfile.setExtension(".cue");
      if (!cuefile.exists) findCue(cuefile.dirName);
    } else {
      if (exists(flacfile~".flac")) {
        flacfile ~= ".flac";
        findCue(flacfile.dirName);
      } else if (exists(flacfile~".cue")) {
        cuefile = flacfile~".cue";
        findFlac(cuefile.dirName);
      } else {
        assert(0, "wtf?!");
      }
    }
  }

  writeln("FLAC: ", flacfile);
  writeln("CUE : ", cuefile);

  CueFile cue;
  cue.load(cuefile);

  if (cue.tracks.length == 0) assert(0, "no tracks");
  if (cue.tracks[0].startmsecs != 0) assert(0, "found first hidden track");

  //cue.dump();
  makeOggs(flacfile, cue, kbps);
}
