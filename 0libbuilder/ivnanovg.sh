#!/bin/sh

odir=`pwd`
mdir=`dirname "$0"`
cd "$mdir/../nanovg"

rm /opt/dmd/lib/libivnanovg.a 2>/dev/null

echo -n "compiling iv.nanovg..."
dmd \
 -conf=/opt/dmd/bin/dmd_clean.conf \
 -c -lib -O -inline -of/opt/dmd/lib/libivnanovg.a \
  nanovg.d \
  perf.d \
  svg.d

res=$?
echo "done"

cd "$odir"

exit $res
