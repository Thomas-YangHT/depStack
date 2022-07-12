docker build -t 168447636/deepin20-keystone:20.5 --rm -f Dockerfile.keystone .
docker images |grep none |awk '{print $3}' |xargs docker rmi
