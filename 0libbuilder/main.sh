#!/bin/sh

odir=`pwd`
mdir=`dirname "$0"`
cd "$mdir"

list="
ivvfs.sh
ivcmdcon.sh
ivnanovg.sh
ivaudec.sh
ivmisc.sh
"

for cc in $list; do
  sh $cc
  res=$?
  if [ $res != 0 ]; then
    echo "FUCKED: $cc"
    exit $res
  fi
done

cd "$odir"
