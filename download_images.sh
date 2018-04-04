#!/bin/bash -eu
for i in $(seq 1 1000); do
	echo "download images of loop: "$i;
	. ./bin/get-docker-images.sh;
 done

