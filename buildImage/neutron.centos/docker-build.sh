docker build -t 168447636/centos-neutron:7 --rm -f Dockerfile.neutron .
docker images |grep none |awk '{print $3}' |xargs docker rmi
