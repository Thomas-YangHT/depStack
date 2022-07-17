
docker ps -aq |xargs docker rm -f 
[ -d /var/lib/mysql ] && rm -rf /var/lib/mysql
[ -d /var/lib/rabbitmq/ ] && rm -rf /var/lib/rabbitmq
[ -d /etc/keystone/ ] && rm -rf /etc/keystone/
[ -d /etc/glance ] && rm -rf /etc/glance
[ -d /etc/nova ] && rm -rf /etc/nova
[ -d /etc/neutron ] && rm -rf /etc/neutroon

