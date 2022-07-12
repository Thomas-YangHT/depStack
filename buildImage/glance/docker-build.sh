docker build -t 168447636/deepin20-glance:20.5 --rm -f Dockerfile.glance .
docker images |grep none |awk '{print $3}' |xargs docker rmi
