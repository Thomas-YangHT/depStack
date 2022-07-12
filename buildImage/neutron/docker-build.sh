docker build -t 168447636/deepin20-neutron:20.5 --rm -f Dockerfile.neutron .
docker images |grep none |awk '{print $3}' |xargs docker rmi
