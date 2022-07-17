source ~/admin-openrc.sh
openstack compute service list
openstack network agent list
openstack --version

portslist="
3306 mysql 
5672 rabbitmq
15672 rabbitmq
11211 memcached
123  chronyd
80  dashboard
35357 keystone
5000  keystone
9191  glance
9292  glance
9696  neutron
8774 nova
8775 nova
8778 nova
6082 nova-spice
6083 nova-spice
"
ports=`echo $portslist |xargs -n 2|awk '{printf $1"|"}'|xargs`
portscheck=`ss -nltu |grep -P "$ports"`

while read pnum pname;do
  test=`echo $portscheck |grep $pnum` && \
  echo -e "$pnum $pname \033[32m OK\033[0m" || \
  echo -e "$pnum $pname \033[31m Fail\033[0m" 
done<<EOF
`echo $portslist|xargs -n 2`
EOF

