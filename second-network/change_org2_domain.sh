#!/bin/bash

echo "chaning ORG2_DOMAIN to $1"

if [ ! -z "$1" -a "$1" != " " ]; then

echo "chaning ORG2_DOMAIN to $1"


FILES="./base/docker-compose-base.yaml
./configtx.yaml
./control-network.sh
./crypto-config.yaml
./docker-compose-cli.yaml
./docker-compose-couch.yaml
./docker-compose-e2e-template.yaml
./scripts/script.sh"
for f in $FILES
do
	sed -i_backup "s/ORG2_DOMAIN/$1/g" $f
	# rm "${f}_backup"
done

fi