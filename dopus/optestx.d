import iv.dopus;

import iv.alsa;
import iv.cmdcon;
import iv.vfs;

import xalsa;


// ////////////////////////////////////////////////////////////////////////// //
void main (string[] args) {
  assert(args.length > 1);

  OpusFile of = opusOpen(VFile(args[1]));
  scope(exit) opusClose(of);

  conwriteln("vendor: [", of.vendor, "]");
  conwriteln("channels: ", of.channels);
  conwritefln!"duration: %s:%02s"(of.duration/1000/60, of.duration/1000%60);
  conwriteln("comment count: ", of.commentCount);
  foreach (immutable cidx; 0..of.commentCount) conwriteln("  #", cidx, ": [", of.comment(cidx), "]");

  version(noplay) {} else alsaOpen(of.channels);
  version(noplay) {} else scope(exit) alsaClose();

  of.seek(25000);

  long lasttime = -1;
  for (;;) {
    auto rd = of.readFrame();
    if (rd.length == 0) break;

    version(noplay) {} else {
      if (lasttime != of.curtime) {
        lasttime = of.curtime;
        conwritef!"\r%s:%02s / %s:%02s"(lasttime/1000/60, lasttime/1000%60, of.duration/1000/60, of.duration/1000%60);
      }
      alsaWriteX(rd.ptr, cast(uint)rd.length/of.channels);
    }
  }
  conwriteln;
}
