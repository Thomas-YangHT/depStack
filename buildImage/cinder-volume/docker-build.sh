docker build -t 168447636/deepin20-cindervolume:20.5 --rm -f Dockerfile.cinderVolume .
docker images |grep none |awk '{print $3}' |xargs docker rmi
