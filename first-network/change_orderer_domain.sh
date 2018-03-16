#!/bin/bash
# TODO: change this into a python file

# $0 是脚本名，$0 才是参数名

echo "chaning ORDERER_DOMAIN to $1"

if [ ! -z "$1" -a "$1" != " " ]; then

echo "chaning ORDERER_DOMAIN to $1"

FILES="./base/docker-compose-base.yaml
./configtx.yaml
./crypto-config.yaml
./docker-compose-cli.yaml
./scripts/script.sh"
for f in $FILES
do

	sed -i_backup "s/ORDERER_DOMAIN/$1/g" $f
	# rm "${f}_backup"
done

fi
