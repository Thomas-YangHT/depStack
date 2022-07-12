docker build -t 168447636/deepin20-cinderschedule:20.5 --rm -f Dockerfile.cinderSchedule .
docker images |grep none |awk '{print $3}' |xargs docker rmi
