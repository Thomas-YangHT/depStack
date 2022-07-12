docker build -t 168447636/deepin20-neutronlinuxbridge:20.5 --rm -f Dockerfile.neutronlinuxbridge .
docker images |grep none |awk '{print $3}' |xargs docker rmi
