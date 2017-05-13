#!/bin/sh

odir=`pwd`
mdir=`dirname "$0"`
cd "$mdir/../vfs"

rm /opt/dmd/lib/libivvfs.a 2>/dev/null

echo -n "compiling iv.vfs..."
dmd \
 -conf=/opt/dmd/bin/dmd_clean.conf \
 -c -lib -O -inline -of/opt/dmd/lib/libivvfs.a \
  config.d \
  error.d \
  inflate.d \
  io.d \
  koi8.d \
  main.d \
  package.d \
  posixci.d \
  pred.d \
  stream.d \
  types.d \
  util.d \
  vfile.d \
  arc/abuse.d \
  arc/arcanum.d \
  arc/arcz.d \
  arc/bsa.d \
  arc/dfwad.d \
  arc/dunepak.d \
  arc/f2dat.d \
  arc/internal.d \
  arc/kengrp.d \
  arc/package.d \
  arc/q1pak.d \
  arc/toeedat.d \
  arc/wad.d \
  arc/wad2.d \
  arc/zip.d
res=$?
echo "done"

cd "$odir"

exit $res
