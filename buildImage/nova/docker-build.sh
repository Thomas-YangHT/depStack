docker build -t 168447636/deepin20-nova:20.5 --rm -f Dockerfile.nova .
docker images |grep none |awk '{print $3}' |xargs docker rmi
