FILES="./base/docker-compose-base.yaml
./configtx.yaml
./crypto-config.yaml
./docker-compose-cli.yaml
./scripts/script.sh"
for f in $FILES
do
	# 一定要用双引号求值
	# 一定要用这个符号来连词
	mv "$f"_backup "$f"
	rm "$f"_backup
	git checkout $f
done