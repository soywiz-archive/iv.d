#!/bin/sh


# $1: module name
function dotest() {
  #echo "testing $1..."
  rdmd -unittest -main ../rng/$1.d
}


dotest isaac
