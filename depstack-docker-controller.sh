#!/bin/bash
##
## a shell script for docker coontroller 
## system:  deepin 20.5
##
#引入配置
source depstack.conf

[ -n "`echo $DOCKER_REGISTRY |grep myharbor`" ] && echo 10.121.1.254 www.myharbor.com >>/etc/hosts
#确认配置主机名
cat /etc/hosts|grep controller || cat hosts >>/etc/hosts
hostnamectl set-hostname controller
#安装ebtables
apt install -y ebtables 
#chrony 时间服务
docker run -d --cap-add SYS_TIME \
--name chrony \
--restart=always \
-e ALLOW_CIDR=$openNET.0/24 \
-e NTP_SERVER=2.debian.pool.ntp.org \
-p 123:123/udp \
$DOCKER_REGISTRY/chrony
#geoffh1977/chrony
echo "--------------------------------------"
echo -e "\033[32m 时间同步服务器安装完成 \033[0m"
echo "--------------------------------------"
#Mariadb数据库
docker run -d --name mariadb \
--restart=always \
-v /var/run/mysqld:/var/run/mysqld \
--env MARIADB_USER=example-user \
--env MARIADB_PASSWORD=my_cool_secret \
--env MARIADB_ROOT_PASSWORD=mariadb  \
-p 3306:3306 \
$DOCKER_REGISTRY/mariadb:10.7
#mariadb:10.7
echo "--------------------------------------"
echo -e "\033[32m Mariadb 数据库安装完成 \033[0m"
echo "--------------------------------------"
#安装Memcache缓存服务器
docker run --name my-memcache \
--restart=always \
-p 11211:11211 \
-d \
$DOCKER_REGISTRY/memcached:alpine
#memcached:alpine
echo "--------------------------------------"
echo -e "\033[32m Memcache缓存服务器安装完成 \033[0m"
echo "--------------------------------------"
#安装消息队列服务
docker run -d \
--restart=always \
--hostname controller \
--name rabbit \
-e RABBITMQ_DEFAULT_USER=uosrabbitmq \
-e RABBITMQ_DEFAULT_PASS=rabbitmq \
-p 5672:5672 \
-p 15672:15672 \
$DOCKER_REGISTRY/rabbitmq:3-management
#rabbitmq:3-management

sleep 10
#赋予uosrabbitmq用户管理员权限
docker exec rabbit rabbitmqctl set_user_tags uosrabbitmq administrator
#赋予uosrabbitmq资源配置、读和写的权限
docker exec rabbit rabbitmqctl set_permissions uosrabbitmq ".*" ".*" ".*"
echo "--------------------------------------"
echo -e "\033[32m 消息队列服务器安装完成 \033[0m"
echo "--------------------------------------"
# keystone
shopt  -s  expand_aliases
alias mysql="docker exec mariadb mysql"
#创建keystone数据库
mysql -uroot -pmariadb -e "CREATE DATABASE keystone" 
#赋予访问keystone数据库的权限
mysql -uroot -pmariadb -e "GRANT ALL PRIVILEGES ON keystone.* TO 'uoskeystone'@'localhost' IDENTIFIED BY 'keystone'" 
mysql -uroot -pmariadb -e "GRANT ALL PRIVILEGES ON keystone.* TO 'uoskeystone'@'%' IDENTIFIED BY 'keystone'"
#启动keystone/ dashboard 服务
docker run --name keystone \
--restart=always \
--net=host \
-p 80:80 \
-p 5000:5000 \
-p 35357:35357 \
-v $PWD/hosts:/depstack/hosts \
-d \
$DOCKER_REGISTRY/deepin20-keystone:20.5
#168447636/deepin20-keystone:20.5

docker exec keystone sed -i 's/OPENSTACK_HOST =.*/OPENSTACK_HOST = "controller"/' /etc/openstack-dashboard/local_settings.py

#生成keystone数据库的数据
alias keystone="docker exec keystone"
keystone su -s /bin/bash keystone -c "keystone-manage db_sync"
#初始化Fernet密钥存储库
keystone keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
keystone keystone-manage credential_setup --keystone-user keystone --keystone-group keystone
#引导身份服务，密码为keystone
keystone keystone-manage bootstrap --bootstrap-password keystone \
  --bootstrap-admin-url http://controller:35357/v3/ \
  --bootstrap-internal-url http://controller:5000/v3/ \
  --bootstrap-public-url http://controller:5000/v3/ \
  --bootstrap-region-id RegionOne
#编写环境变量脚本
echo -e "export OS_USERNAME=admin OS_PASSWORD=keystone  OS_PROJECT_NAME=admin OS_USER_DOMAIN_NAME=Default OS_PROJECT_DOMAIN_NAME=Default OS_AUTH_URL=http://controller:35357/v3 OS_IDENTITY_API_VERSION=3 OS_IMAGE_API_VERSION=2  " > /root/admin-openrc.sh
#复制到容器里
docker cp /root/admin-openrc.sh keystone:/root/admin-openrc.sh

#在default域下创建service项目
alias openstack='docker exec keystone'
openstack  bash -c 'source /root/admin-openrc.sh && openstack project create --domain default --description "Service Project" service'
#常规（非管理员）任务应使用非特权项目和用户，创建demo项目
openstack  bash -c 'source /root/admin-openrc.sh && openstack project create --domain default --description "Demo Project" demo'
#创建demo用户
openstack  bash -c 'source /root/admin-openrc.sh && openstack user create --domain default --password demo demo'
#创建user角色
openstack  bash -c 'source /root/admin-openrc.sh && openstack role create user'
#将user角色添加到demo项目和demo用户
openstack  bash -c 'source /root/admin-openrc.sh && openstack role add --project demo --user demo user'
#重启
docker restart keystone my-memcache
echo "--------------------------------------"
echo -e "\033[32m Keystone组件安装完成 \033[0m"
echo "--------------------------------------"
#创建glance数据库
mysql -uroot -pmariadb -e "CREATE DATABASE glance" 
#赋予访问glance数据库的权限
mysql -uroot -pmariadb -e "GRANT ALL PRIVILEGES ON glance.* TO 'uosglance'@'localhost' IDENTIFIED BY 'glance'" 
mysql -uroot -pmariadb -e "GRANT ALL PRIVILEGES ON glance.* TO 'uosglance'@'%' IDENTIFIED BY 'glance'"
#在default域下创建glance用户
openstack  bash -c 'source /root/admin-openrc.sh && openstack user create --domain default --password glance glance'
#将admin角色添加到glance用户和service项目上
openstack  bash -c 'source /root/admin-openrc.sh && openstack role add --project service --user glance admin'
#创建glance项目
openstack  bash -c 'source /root/admin-openrc.sh && openstack service create --name glance --description "OpenStack Image" image'
#创建访问glance的endpoint端点
openstack  bash -c 'source /root/admin-openrc.sh && openstack endpoint create --region RegionOne image public http://controller:9292  && \
openstack endpoint create --region RegionOne image internal http://controller:9292 && \
openstack endpoint create --region RegionOne image admin http://controller:9292'
#安装glance组件
docker run --name glance \
--restart=always \
-p 9191:9191 \
-p 9292:9292 \
-v $PWD/hosts:/depstack/hosts \
-d \
$DOCKER_REGISTRY/deepin20-glance:20.5
#168447636/deepin20-glance:20.5

#生成glance数据库结构
docker exec glance su -s /bin/bash glance -c "glance-manage db_sync"
#重启glance组件服务
docker restart glance
echo "--------------------------------------"
echo -e "\033[32m Glance组件安装完成 \033[0m"
echo "--------------------------------------"
#创建nova组件相关的数据库
mysql -uroot -pmariadb -e "CREATE DATABASE nova_api" 
mysql -uroot -pmariadb -e "CREATE DATABASE nova" 
mysql -uroot -pmariadb -e "CREATE DATABASE nova_placement" 
mysql -uroot -pmariadb -e "CREATE DATABASE nova_cell0" 
#赋予访问nova数据库的权限
mysql -uroot -pmariadb -e "GRANT ALL PRIVILEGES ON nova_api.* TO 'uosnova'@'localhost' IDENTIFIED BY 'nova'" 
mysql -uroot -pmariadb -e "GRANT ALL PRIVILEGES ON nova_api.* TO 'uosnova'@'%' IDENTIFIED BY 'nova'" 
mysql -uroot -pmariadb -e "GRANT ALL PRIVILEGES ON nova.* TO 'uosnova'@'localhost' IDENTIFIED BY 'nova'" 
mysql -uroot -pmariadb -e "GRANT ALL PRIVILEGES ON nova.* TO 'uosnova'@'%' IDENTIFIED BY 'nova'" 
mysql -uroot -pmariadb -e "GRANT ALL PRIVILEGES ON nova_placement.* TO 'uosnova'@'localhost' IDENTIFIED BY 'nova'" 
mysql -uroot -pmariadb -e "GRANT ALL PRIVILEGES ON nova_placement.* TO 'uosnova'@'%' IDENTIFIED BY 'nova'" 
mysql -uroot -pmariadb -e "GRANT ALL PRIVILEGES ON nova_cell0.* TO 'uosnova'@'localhost' IDENTIFIED BY 'nova'" 
mysql -uroot -pmariadb -e "GRANT ALL PRIVILEGES ON nova_cell0.* TO 'uosnova'@'%' IDENTIFIED BY 'nova'" 
#创建nova用户

openstack  bash -c 'source /root/admin-openrc.sh && openstack user create --domain default --password nova nova'
#添加admin角色给nova用户
openstack  bash -c 'source /root/admin-openrc.sh && openstack role add --project service --user nova admin'
#创建nova项目
openstack  bash -c 'source /root/admin-openrc.sh && openstack service create --name nova --description "OpenStack Compute" compute'
#创建访问nova的endpoint端点
openstack  bash -c 'source /root/admin-openrc.sh && openstack endpoint create --region RegionOne compute public http://controller:8774/v2.1 && \
openstack endpoint create --region RegionOne compute internal http://controller:8774/v2.1 && \
openstack endpoint create --region RegionOne compute admin http://controller:8774/v2.1'
#创建placement用户
openstack  bash -c 'source /root/admin-openrc.sh && openstack user create --domain default --password placement placement'
#添加placement user到service project，并且赋予admin角色
openstack  bash -c 'source /root/admin-openrc.sh && openstack role add --project service --user placement admin'
#创建placement服务的项目
openstack  bash -c 'source /root/admin-openrc.sh && openstack service create --name placement --description "Placement API" placement'
#创建访问placement的endpoint端点
openstack  bash -c 'source /root/admin-openrc.sh && openstack endpoint create --region RegionOne placement public http://controller:8778 && \
openstack endpoint create --region RegionOne placement internal http://controller:8778 && \
openstack endpoint create --region RegionOne placement admin http://controller:8778'
#安装nova组件
docker run --name nova \
--restart=always \
--net=host \
-e controllerIP=$controllerIP \
-e virt_type=$virt_type \
-p 8774:8774 \
-p 8775:8775 \
-p 8778:8778 \
-p 6082:6082 \
-p 6083:6083 \
-v $PWD/hosts:/depstack/hosts \
-d \
$DOCKER_REGISTRY/deepin20-nova:20.5 
#168447636/deepin20-nova:20.5 

#生成数据库表结构
docker exec nova su -s /bin/bash nova -c "nova-manage api_db sync"
docker exec nova su -s /bin/bash nova -c "nova-manage cell_v2 map_cell0"
docker exec nova su -s /bin/bash nova -c "nova-manage db sync"
docker exec nova su -s /bin/bash nova -c "nova-manage cell_v2 create_cell --name cell1"
#重启nova服务
docker restart nova
echo "--------------------------------------"
echo -e "\033[32m Nova组件安装完成 \033[0m"
echo "--------------------------------------"
#创建neutron数据库
mysql -uroot -pmariadb -e "CREATE DATABASE neutron" 
#赋予访问neutron数据库的权限
mysql -uroot -pmariadb -e "GRANT ALL PRIVILEGES ON neutron.* TO 'uosneutron'@'localhost' IDENTIFIED BY 'neutron'" 
mysql -uroot -pmariadb -e "GRANT ALL PRIVILEGES ON neutron.* TO 'uosneutron'@'%' IDENTIFIED BY 'neutron'" 
#创建neutron用户
openstack  bash -c 'source /root/admin-openrc.sh && openstack user create --domain default --password neutron neutron'
#添加admin角色给neutron用户
openstack  bash -c 'source /root/admin-openrc.sh && openstack role add --project service --user neutron admin'
#创建neutron服务的项目
openstack  bash -c 'source /root/admin-openrc.sh && openstack service create --name neutron --description "OpenStack Networking" network'
#创建访问网络服务的endpoint端点
openstack  bash -c 'source /root/admin-openrc.sh && openstack endpoint create --region RegionOne network public http://controller:9696 && \
openstack endpoint create --region RegionOne network internal http://controller:9696 && \
openstack endpoint create --region RegionOne network admin http://controller:9696'
#安装neutron组件
net2Name=$(ip a |grep -Po "^3: \K.*\d:"|awk -F':' '{print $1}')
docker run --name neutron \
--restart=always \
--net=host \
--privileged=true \
--cap-add NET_ADMIN \
-e controllerIP=$controllerIP \
-e net2Name=$net2Name \
-e ctl_net3_IP=$c1IP \
-v $PWD/hosts:/depstack/hosts \
-v /usr/lib/modules/`uname -r`:/usr/lib/modules/`uname -r` \
-d \
$DOCKER_REGISTRY/deepin20-neutron:20.5
#168447636/deepin20-neutron:20.5
#-v /var/run/netns:/var/run/netns \
#-v /sys/fs/cgroup:/sys/fs/cgroup \
#临时cp
#docker cp  /usr/sbin/sysctl  neutron:/usr/sbin/sysctl

#生成数据库表结构
docker exec neutron su -s /bin/bash neutron -c "neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugin.ini upgrade head"
echo "--------------------------------------"
echo -e "\033[32m Neutron组件安装完成 \033[0m"
echo "--------------------------------------"
##修正错误：vm网络端口不正常，日志报firewall deny规则不允许
modprobe ebtables
tee /etc/modules-load.d/ebtables.conf <<EOF
ebtables
EOF
update-alternatives --set ebtables  /usr/sbin/ebtables-legacy
docker exec neutron update-alternatives --set ebtables  /usr/sbin/ebtables-legacy
##修正错误: Host 'controller' is not mapped to any cell
docker exec nova  nova-manage cell_v2 discover_hosts --verbose
#重启服务
echo -e "\033[32m 重启docker容器，请稍候... \033[0m"
systemctl restart docker
sleep 30
#执行环境变量脚本
source /root/admin-openrc.sh
#安装openstack命令cli
apt install -y python3-openstackclient 
#导入cirros镜相
unalias openstack
openstack image create --file controller/cirros-0.4.0-x86_64-disk.img --disk-format qcow2 --container-format bare --public cirros
openstack image list
openstack flavor create --vcpus 1 --ram 512 --disk 1 --public vm.linux.1H512M
openstack flavor list
#openstack server create \
#--flavor vm.4H8G \
#--image CentOS-7.8-x86_64-2003 \
#--nic net-id=581375e6-9130-4818-b307-cc33ccc07a01,v4-fixed-ip=10.4.1.4 \
#--security-group 28be0a23-9c5b-4948-8672-7ac53b6f756f \
#cirros
##检查安装服务状态
cat ./controller/check.sh |bash
echo "--------------------------------------"
echo -e "\033[31m 浏览器访问http://$controllerIP,用户名admin/密码keystone。开启Openstack之旅 \033[0m"
echo -e "\033[31m rabbitmq: 浏览器访问http://$controllerIP:15472,用户名uosrabbitmq/密码rabbitmq。开启Openstack之旅 \033[0m"
echo -e "\033[31m 导入cirros镜相 \033[0m"
echo "--------------------------------------"
