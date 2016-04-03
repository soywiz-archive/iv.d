#!/bin/sh


# $1: module name
function dotest() {
  #echo "testing $1..."
  #rdmd -unittest -main -J. -I.. ../iv/stc/$1.d
  rdmd -unittest -main -J. -I.. ../$1.d
}


dotest rabbit
dotest salsa
rdmd testarc4.d
rdmd testchacha8.d
rdmd testchacha.d
