#!/bin/sh

odir=`pwd`
mdir=`dirname "$0"`
cd "$mdir/.."

rm /opt/dmd/lib/libivcmdcon.a 2>/dev/null

echo -n "compiling iv.cmdcon..."
dmd \
 -conf=/opt/dmd/bin/dmd_clean.conf \
 -c -lib -O -of/opt/dmd/lib/libivcmdcon.a \
  cmdcon.d \
  cmdcongl.d

res=$?
echo "done"

cd "$odir"

exit $res
