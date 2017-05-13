#!/bin/sh

odir=`pwd`
mdir=`dirname "$0"`
cd "$mdir/.."

rm /opt/dmd/lib/libivaudec.a 2>/dev/null

echo -n "compiling IV: audio decoders..."
dmd \
 -conf=/opt/dmd/bin/dmd_clean.conf \
 -c -lib -O -inline -of/opt/dmd/lib/libivaudec.a \
  audiostream.d \
  drflac.d \
  id3v2.d \
  minimp3.d \
  mp3scan.d \
  tremor.d \
  dopus/dopus.d

res=$?
echo "done"

cd "$odir"

exit $res
