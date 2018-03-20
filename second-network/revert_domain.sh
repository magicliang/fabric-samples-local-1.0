#!/bin/bash

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
	# 一定要用双引号求值
	# 一定要用这个符号来连词
	# 不需要 rm，因为 mv 就直接把两个文件变成一个了
	mv "$f"_backup "$f"
	#rm "$f"_backup
	# in case of absence of *_backup files.
	git checkout $f
done