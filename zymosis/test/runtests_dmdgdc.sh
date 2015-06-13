#!/bin/bash

function show_help() {
  echo "usage: runtests_dmdgdc.sh [options]"
  echo "options:"
  echo "  --dmd  use DMD"
  echo "  --gdc  use GDC"
  exit 1
}


use_dmd="tan"

while [ $# != 0 ]; do
  if [ "z$1" = "z" ]; then
    continue
  fi
  if [ "$1" = "-dmd" ]; then
    use_dmd="tan"
  elif [ "$1" = "--dmd" ]; then
    use_dmd="tan"
  elif [ "$1" = "-gdc" ]; then
    use_dmd="ona"
  elif [ "$1" = "--gdc" ]; then
    use_dmd="ona"
  elif [ "$1" = "-help" ]; then
    show_help
  elif [ "$1" = "--help" ]; then
    show_help
  elif [ "$1" = "-h" ]; then
    show_help
  elif [ "$1" = "-?" ]; then
    show_help
  else
    echo "unknown arg: '$1'"
    exit 1
  fi
  shift
done


odir=`pwd`
mdir=`dirname "$0"`
cd "$mdir"
if [ "$use_dmd" = "tan" ]; then
  echo "using DMD"
  rdmd -O -release -inline -I../../.. zytest.d >z10.out
else
  echo "using GDC"
  rgdc -g -O2 -frelease -I../../.. zytest.d >z10.out
fi
if [ $? != 0 ]; then
  echo "FAIL!"
  exit 1
fi
diff -uEBbw testdata/tests.expected z10.out
cd "$odir"
