#!/usr/bin/env rdmd
module zflacvt is aliced;

import iv.drflac;
import iv.cmdcon;
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
struct CueFile {
private import iv.encoding;
private import iv.vfs;
private import iv.vfs.io;

public:
  static string koi2tr (const(char)[] s) {
    string res;
    foreach (char ch; s) {
           if (ch == '\xe1' || ch == '\xc1') res ~= "a";
      else if (ch == '\xe2' || ch == '\xc2') res ~= "b";
      else if (ch == '\xf7' || ch == '\xd7') res ~= "v";
      else if (ch == '\xe7' || ch == '\xc7') res ~= "g";
      else if (ch == '\xe4' || ch == '\xc4') res ~= "d";
      else if (ch == '\xe5' || ch == '\xc5') res ~= "e";
      else if (ch == '\xb3' || ch == '\xa3') res ~= "yo";
      else if (ch == '\xf6' || ch == '\xd6') res ~= "zh";
      else if (ch == '\xfa' || ch == '\xda') res ~= "z";
      else if (ch == '\xe9' || ch == '\xc9') res ~= "i";
      else if (ch == '\xea' || ch == '\xca') res ~= "j";
      else if (ch == '\xeb' || ch == '\xcb') res ~= "k";
      else if (ch == '\xec' || ch == '\xcc') res ~= "l";
      else if (ch == '\xed' || ch == '\xcd') res ~= "m";
      else if (ch == '\xee' || ch == '\xce') res ~= "n";
      else if (ch == '\xef' || ch == '\xcf') res ~= "o";
      else if (ch == '\xf0' || ch == '\xd0') res ~= "p";
      else if (ch == '\xf2' || ch == '\xd2') res ~= "r";
      else if (ch == '\xf3' || ch == '\xd3') res ~= "s";
      else if (ch == '\xf4' || ch == '\xd4') res ~= "t";
      else if (ch == '\xf5' || ch == '\xd5') res ~= "u";
      else if (ch == '\xe6' || ch == '\xc6') res ~= "f";
      else if (ch == '\xe8' || ch == '\xc8') res ~= "h";
      else if (ch == '\xe3' || ch == '\xc3') res ~= "c";
      else if (ch == '\xfe' || ch == '\xde') res ~= "ch";
      else if (ch == '\xfb' || ch == '\xdb') res ~= "sh";
      else if (ch == '\xfd' || ch == '\xdd') res ~= "sch";
      else if (ch == '\xff' || ch == '\xdf') {} //res ~= "x"; // tvyordyj znak
      else if (ch == '\xf9' || ch == '\xd9') res ~= "y";
      else if (ch == '\xf8' || ch == '\xd8') {} //res ~= "w"; // myagkij znak
      else if (ch == '\xfc' || ch == '\xdc') res ~= "e";
      else if (ch == '\xe0' || ch == '\xc0') res ~= "ju";
      else if (ch == '\xf1' || ch == '\xd1') res ~= "ja";
      else if (ch >= 'A' && ch <= 'Z') res ~= cast(char)(ch+32);
      else if (ch >= 'a' && ch <= 'z') res ~= ch;
      else if (ch >= '0' && ch <= '9') res ~= ch;
      else {
        if (res.length > 0 && res[$-1] != '_') res ~= '_';
      }
    }
    while (res.length && res[$-1] == '_') res = res[0..$-1];
    if (res.length == 0) res = "_";
    return res;
  }

public:
  static struct Track {
    string artist; // performer
    string title;
    string genre;
    uint year; // 0: unknown
    string filename;
    ulong startmsecs; // index 01
  }

private:
  ulong parseIndex (const(char)[] s) {
    import std.algorithm : splitter;
    import std.conv : to;
    import std.range : enumerate;
    uint[3] msf;
    bool lastHit = false;
    foreach (immutable idx, auto sv; s.splitter(':').enumerate) {
      if (idx >= msf.length) throw new Exception("invalid index");
      lastHit = (idx == msf.length-1);
      msf[idx] = sv.to!uint;
    }
    if (!lastHit) throw new Exception("invalid index");
    if (msf[1] > 59) throw new Exception("invalid index");
    if (msf[2] > 74) throw new Exception("invalid index");
    return cast(uint)((((msf[1]+msf[0]*60)*75)/75.0)*1000.0);
  }

public:
  string artist;
  string album;
  string genre;
  uint year; // 0: unknown
  string filename;
  Track[] tracks;

public:
  void clear () { this = this.init; }

  void load (const(char)[] fname) { load(VFile(fname)); }

  void load (VFile fl) {
    clear();
    scope(failure) clear();
    char[4096] linebuf;
    char lastSavedChar = 0;
    char[] line;
    bool firstLine = true;

    bool readLine () {
      scope(success) {
        if (firstLine) {
          firstLine = false;
          if (line.length >= 3 && line[0..3] == "\xEF\xBB\xBF") line = line[3..$]; // fuck BOM
        }
      }
      uint pos = 0;
      if (lastSavedChar) { linebuf[pos++] = lastSavedChar; lastSavedChar = 0; }
      while (pos < linebuf.length) {
        auto rd = fl.rawRead(linebuf[pos..pos+1]);
        if (rd.length == 0) {
          if (pos == 0) { line = null; return false; }
          line = linebuf[0..pos];
          return true;
        }
        char ch = linebuf[pos];
        if (ch == '\n') {
          line = linebuf[0..pos];
          return true;
        }
        if (ch == '\r') {
          rd = fl.rawRead((&lastSavedChar)[0..1]);
          if (rd.length == 1 && lastSavedChar == '\n') lastSavedChar = 0;
          line = linebuf[0..pos];
          return true;
        }
        ++pos;
      }
      throw new Exception("line too long!");
    }

    // null: EOL
    const(char)[] nextWord(bool doupper) () {
      while (line.length && line[0] <= ' ') line = line[1..$];
      if (line.length == 0) return null;
      char[] res;
      uint epos = 1;
      if (line[0] == '"') {
        // quoted
        while (epos < line.length && line[epos] != '"') {
          // just in case
          if (line[epos] == '\\' && line.length-epos > 1) epos += 2; else ++epos;
        }
        res = line[1..epos];
        if (epos < line.length) {
          assert(line[epos] == '"');
          ++epos;
        }
        line = line[epos..$];
        // remove spaces (i don't need 'em anyway; and i don't care about idiotic filenames)
        while (res.length && res[0] <= ' ') res = res[1..$];
        while (res.length && res[$-1] <= ' ') res = res[0..$-1];
      } else {
        // normal
        while (epos < line.length && line[epos] > ' ') ++epos;
        res = line[0..epos];
        line = line[epos..$];
      }
      // recode
      if (res !is null && !res.utf8Valid) return res.recode("utf-8", "cp1251");
      static if (doupper) {
        if (res !is null) {
          // upcase
          bool doconv = false;
          foreach (char ch; res) {
            if (ch >= 128) { doconv = false; break; }
            if (ch >= 'a' && ch <= 'z') doconv = true;
          }
          if (doconv) foreach (ref char ch; res) if (ch >= 'a' && ch <= 'z') ch -= 32;
        }
      }
      return res;
    }

    while (readLine) {
      //writeln("[", line, "]");
      auto w = nextWord!true();
      if (w is null) continue;
      switch (w) {
        case "REM": // special
          w = nextWord!true();
          switch (w) {
            case "DATE": case "YEAR":
              w = nextWord!false();
              int yr = 0;
              try { import std.conv : to; yr = w.to!ushort(10); } catch (Exception) {}
              if (yr >= 1900 && yr <= 3000) {
                if (tracks.length) tracks[$-1].year = yr; else year = yr;
              }
              break;
            case "GENRE":
              w = nextWord!false();
              if (w.length) {
                if (tracks.length) tracks[$-1].genre = w.idup; else genre = w.idup;
              }
              break;
            default: break;
          }
          break;
        case "TRACK": // new track
          tracks.length += 1;
          w = nextWord!true();
          try {
            import std.conv : to;
            auto tn = w.to!ubyte(10);
            if (tn != tracks.length) throw new Exception("invalid track number");
          } catch (Exception) {
            throw new Exception("fucked track number");
          }
          w = nextWord!true();
          if (w != "AUDIO") throw new Exception("non-audio track");
          break;
        case "PERFORMER":
          w = nextWord!false();
          if (w.length) {
            if (tracks.length) tracks[$-1].artist = w.idup; else artist = w.idup;
          }
          break;
        case "TITLE":
          w = nextWord!false();
          if (w.length) {
            if (tracks.length) tracks[$-1].title = w.idup; else album = w.idup;
          }
          break;
        case "FILE":
          w = nextWord!false();
          if (w.length) {
            if (tracks.length) tracks[$-1].filename = w.idup; else filename = w.idup;
          }
          break;
        case "INDEX":
          // mm:ss:ff (minute-second-frame) format. There are 75 such frames per second of audio
          // 00: pregap, optional
          // 01: song start
          if (tracks.length == 0) throw new Exception("index without track");
          w = nextWord!false();
          try {
            import std.conv : to;
            auto n = w.to!ubyte(10);
            if (n == 1) tracks[$-1].startmsecs = parseIndex(nextWord!true);
          } catch (Exception e) {
            writeln("ERROR: ", e.msg);
            throw new Exception("fucked index");
          }
          break;
        case "PREGAP": case "POSTGAP": break; // ignore
        case "ISRC": case "CATALOG": case "FLAGS": case "CDTEXTFILE": break;
        // SONGWRITER
        default:
          writeln("unknown CUE keyword: '", w, "'");
          throw new Exception("invalid keyword");
      }
    }

    // normalize tracks
    foreach (ref trk; tracks) {
      if (trk.artist == artist) trk.artist = null;
      if (trk.year == year) trk.year = 0;
      if (trk.genre == genre) trk.genre = null;
      if (trk.filename == filename) trk.filename = null;
    }
  }

  void dump (VFile fo) {
    fo.writeln("=======================");
    if (artist.length) fo.writeln("ARTIST: <", artist.recodeToKOI8, ">");
    if (album.length) fo.writeln("ALBUM : <", album.recodeToKOI8, ">");
    if (genre.length) fo.writeln("GENRE : <", genre.recodeToKOI8, ">");
    if (year) fo.writeln("YEAR  : <", year, ">");
    if (filename.length) fo.writeln("FILE  : <", filename.recodeToKOI8, ">");
    if (tracks.length) {
      fo.writeln("TRACKS: ", tracks.length);
      foreach (immutable tidx, const ref trk; tracks) {
        fo.writefln(" TRACK #%02d:  start: %d:%02d.%03d", tidx+1, trk.startmsecs/1000/60, (trk.startmsecs/1000)%60, trk.startmsecs%1000);
        if (trk.artist.length) fo.writeln("  ARTIST: <", trk.artist.recodeToKOI8, ">");
        if (trk.title.length) fo.writeln("  TITLE : <", trk.title.recodeToKOI8, ">");
        if (trk.genre.length) fo.writeln("  GENRE : <", trk.genre.recodeToKOI8, ">");
        if (trk.year) fo.writeln("  YEAR  : <", trk.year, ">");
        if (trk.filename.length) fo.writeln("  FILE  : <", trk.filename.recodeToKOI8, ">");
        if (trk.title.length) fo.writeln("  XFILE : <", koi2tr(trk.title.recodeToKOI8), ">");
      }
    }
  }

  void dump () { dump(stdout); }
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
    if (trk.title.length) fname = CueFile.koi2tr(trk.title.recodeToKOI8); else fname = "untitled";
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

  //writeln(args);

  string flacfile, cuefile;
  //if (args.length == 1) args ~= "linda_karandashi_i_spichki.cue";
  if (args.length < 2) assert(0, "filename?");

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
