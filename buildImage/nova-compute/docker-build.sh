docker build -t 168447636/deepin20-novacompute:20.5 --rm -f Dockerfile.novacompute .
docker images |grep none |awk '{print $3}' |xargs docker rmi
