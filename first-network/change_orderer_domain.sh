#!/bin/bash

# TODO: change this into a python file
FILES="./base/docker-compose-base.yaml
./configtx.yaml
./crypto-config.yaml
./docker-compose-cli.yaml
./scripts/script.sh"
for f in $FILES
do
	sed -it "s/tencent.com/ORDERER_DOMAIN/g" $f
	rm "${f}t"
done
