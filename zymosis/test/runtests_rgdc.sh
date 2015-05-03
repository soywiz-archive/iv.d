#!/bin/sh

odir=`pwd`
mdir=`dirname "$0"`
cd "$mdir"
rgdc -g -O2 -frelease -I../../.. zytest.d >z10.out
if [ $? != 0 ]; then
  echo "FAIL!"
  exit 1
fi
diff -uEBbw testdata/tests.expected z10.out
cd "$odir"
