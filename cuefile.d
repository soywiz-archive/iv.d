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
module iv.cuefile is aliced;

import iv.encoding;
import iv.strex;
import iv.vfs;
import iv.vfs.io;


// ////////////////////////////////////////////////////////////////////////// //
struct CueFile {
public:
  static string koi2trlocase (const(char)[] s) {
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
  void clear () { this = this.default; }

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
    foreach (immutable tidx, ref trk; tracks) {
      if (trk.artist == artist) trk.artist = null;
      if (trk.year == year) trk.year = 0;
      if (trk.genre == genre) trk.genre = null;
      if (trk.filename == filename) trk.filename = null;
      int pidx;
      string t = simpleParseInt(trk.title, pidx);
      if (pidx == tidx+1 && t.length && t.ptr[0] == '.') t = t[1..$].xstrip;
      if (pidx == tidx+1 && t.length) trk.title = t;
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
        if (trk.title.length) fo.writeln("  XFILE : <", koi2trlocase(trk.title.recodeToKOI8), ">");
      }
    }
  }

  void dump () { dump(stdout); }

private:
  // num<0: no number
  // return string w/o parsed number
  static inout(char)[] simpleParseInt (inout(char)[] src, out int num) nothrow @trusted @nogc {
    usize pos = 0;
    while (pos < src.length && src.ptr[pos] <= ' ') ++pos;
    if (pos >= src.length || src.ptr[pos] < '0' || src.ptr[pos] > '9') {
      num = -1;
      return src;
    }
    num = 0;
    while (pos < src.length) {
      char ch = src.ptr[pos];
      if (ch < '0' || ch > '9') break;
      auto onum = num;
      num = num*10+ch-'0';
      if (num < onum) { num = -1; return src; }
      ++pos;
    }
    while (pos < src.length && src.ptr[pos] <= ' ') ++pos;
    return src[pos..$];
  }
}
