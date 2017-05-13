#!/bin/sh

odir=`pwd`
mdir=`dirname "$0"`
cd "$mdir/.."

rm /opt/dmd/lib/libivmisc.a 2>/dev/null

echo -n "compiling IV: misc..."
dmd \
 -conf=/opt/dmd/bin/dmd_clean.conf \
 -c -lib -O -inline -of/opt/dmd/lib/libivmisc.a \
  rawtty.d \
  pxclock.d \
  strex.d \
  tweetNaCl.d \
  utfutil.d \
  vmath.d

res=$?
echo "done"

cd "$odir"

exit $res
