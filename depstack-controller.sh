#!/bin/bash
##
## a shell script for coontroller auto install
## system:  deepin 20.5
##
#引入配置
source depstack.conf
cat /etc/hosts|grep controller || cat hosts >>/etc/hosts
hostnamectl set-hostname controller
#更新软件源
apt update
#下载与配置
cat ./controller/apt-download.sh |bash
cat ./controller/debconf*.sh |bash

#安装时间同步服务
apt install -y chrony crudini
#修改配置文件
sed -i 's/pool 2.debian.pool.ntp.org iburst/#&/' /etc/chrony/chrony.conf
#允许$openNET.0网段主机同步时间
echo "allow $openNET.0/24" >> /etc/chrony/chrony.conf
#本机作为时间源
echo 'local stratum 10' >> /etc/chrony/chrony.conf
#重启时间同步服务器
systemctl restart chronyd
systemctl enable chronyd
echo "--------------------------------------"
echo -e "\033[32m 时间同步服务器安装完成 \033[0m"
echo "--------------------------------------"
#安装Mariadb数据库
apt -y install mariadb-server python-pymysql
#初始化数据库密码
mysqladmin -uroot password mariadb
#修改配置文件，其他主机均可访问数据库服务
sed -i 's/127.0.0.1/0.0.0.0/' /etc/mysql/mariadb.conf.d/50-server.cnf
#更改字符集
sed -i 's/^collation-server/#&/' /etc/mysql/mariadb.conf.d/50-server.cnf
sed -i 's/utf8mb4/utf8/' /etc/mysql/mariadb.conf.d/50-server.cnf
#重启Mariadb数据库服务
systemctl restart mariadb.service
systemctl enable mariadb.service
echo "--------------------------------------"
echo -e "\033[32m Mariadb 数据库安装完成 \033[0m"
echo "--------------------------------------"
#安装Memcache缓存服务器
apt install -y memcached python-memcache
#修改配置文件，其他主机均可访问缓存服务
sed -i 's/127.0.0.1/0.0.0.0/' /etc/memcached.conf
#重启Memcache缓存服务
systemctl restart memcached 
systemctl enable memcached
echo "--------------------------------------"
echo -e "\033[32m Memcache缓存服务器安装完成 \033[0m"
echo "--------------------------------------"
#安装消息队列服务
apt install -y rabbitmq-server
#创建消息队列用户uosrabbitmq
rabbitmqctl add_user uosrabbitmq rabbitmq
#赋予uosrabbitmq用户管理员权限
rabbitmqctl set_user_tags uosrabbitmq administrator
#赋予uosrabbitmq资源配置、读和写的权限
rabbitmqctl set_permissions uosrabbitmq ".*" ".*" ".*"
#启用消息队列web界面
rabbitmq-plugins enable rabbitmq_management
echo "--------------------------------------"
echo -e "\033[32m 消息队列服务器安装完成 \033[0m"
echo "--------------------------------------"
#创建keystone数据库
mysql -uroot -pmariadb -e "CREATE DATABASE keystone" 
#赋予访问keystone数据库的权限
mysql -uroot -pmariadb -e "GRANT ALL PRIVILEGES ON keystone.* TO 'uoskeystone'@'localhost' IDENTIFIED BY 'keystone'" 
mysql -uroot -pmariadb -e "GRANT ALL PRIVILEGES ON keystone.* TO 'uoskeystone'@'%' IDENTIFIED BY 'keystone'"
#安装keystone组件
apt -y install keystone
mv /etc/keystone/keystone.conf /etc/keystone/keystone.conf.bak
egrep -v "^#|^$" /etc/keystone/keystone.conf.bak > /etc/keystone/keystone.conf
#配置文件编写
sed -i '/database/a\connection = mysql+pymysql://uoskeystone:keystone@controller/keystone' /etc/keystone/keystone.conf
sed -i '/\[cache\]/a\memcache_servers = controller:11211' /etc/keystone/keystone.conf
sed -i '/\[token\]/a\provider = fernet' /etc/keystone/keystone.conf
#生成keystone数据库的数据
su -s /bin/bash keystone -c "keystone-manage db_sync"
#初始化Fernet密钥存储库
keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
keystone-manage credential_setup --keystone-user keystone --keystone-group keystone
#引导身份服务，密码为keystone
keystone-manage bootstrap --bootstrap-password keystone \
  --bootstrap-admin-url http://controller:35357/v3/ \
  --bootstrap-internal-url http://controller:5000/v3/ \
  --bootstrap-public-url http://controller:5000/v3/ \
  --bootstrap-region-id RegionOne
#编写环境变量脚本
echo -e "export OS_USERNAME=admin OS_PASSWORD=keystone  OS_PROJECT_NAME=admin OS_USER_DOMAIN_NAME=Default OS_PROJECT_DOMAIN_NAME=Default OS_AUTH_URL=http://controller:35357/v3 OS_IDENTITY_API_VERSION=3 OS_IMAGE_API_VERSION=2  " > /root/admin-openrc.sh
#执行环境变量脚本
source /root/admin-openrc.sh
#在default域下创建service项目
openstack project create --domain default --description "Service Project" service
#常规（非管理员）任务应使用非特权项目和用户，创建demo项目
openstack project create --domain default --description "Demo Project" demo
#创建demo用户
openstack user create --domain default --password demo demo
#创建user角色
openstack role create user
#将user角色添加到demo项目和demo用户
openstack role add --project demo --user demo user
echo "--------------------------------------"
echo -e "\033[32m Keystone组件安装完成 \033[0m"
echo "--------------------------------------"
#创建glance数据库
mysql -uroot -pmariadb -e "CREATE DATABASE glance" 
#赋予访问glance数据库的权限
mysql -uroot -pmariadb -e "GRANT ALL PRIVILEGES ON glance.* TO 'uosglance'@'localhost' IDENTIFIED BY 'glance'" 
mysql -uroot -pmariadb -e "GRANT ALL PRIVILEGES ON glance.* TO 'uosglance'@'%' IDENTIFIED BY 'glance'"
#在default域下创建glance用户
openstack user create --domain default --password glance glance
#将admin角色添加到glance用户和service项目上
openstack role add --project service --user glance admin
#创建glance项目
openstack service create --name glance --description "OpenStack Image" image
#创建访问glance的endpoint端点
openstack endpoint create --region RegionOne image public http://controller:9292
openstack endpoint create --region RegionOne image internal http://controller:9292
openstack endpoint create --region RegionOne image admin http://controller:9292
#安装glance组件
apt -y install glance
mv /etc/glance/glance-api.conf /etc/glance/glance-api.conf.bak
#配置文件编写
echo -e "
[DEFAULT]\n
bind_host = 0.0.0.0\n
[glance_store]\n
default_store = file\n
filesystem_store_datadir = /var/lib/glance/images/\n
[database]\n
connection = mysql+pymysql://uosglance:glance@controller/glance\n
[keystone_authtoken]\n
www_authenticate_uri = http://controller:5000\n
auth_url = http://controller:35357\n
memcached_servers = controller:11211\n
auth_type = password\n
project_domain_name = default\n
user_domain_name = default\n
project_name = service\n
username = glance\n
password = glance\n
[paste_deploy]\n
flavor = keystone" > /etc/glance/glance-api.conf
mv /etc/glance/glance-registry.conf /etc/glance/glance-registry.conf.bak
echo -e "
[DEFAULT]\n
bind_host = 0.0.0.0\n
[database]\n
connection = mysql+pymysql://uosglance:glance@controller/glance\n
[keystone_authtoken]\n
www_authenticate_uri = http://controller:5000\n
auth_url = http://controller:35357\n
memcached_servers = controller:11211\n
auth_type = password\n
project_domain_name = default\n
user_domain_name = default\n
project_name = service\n
username = glance\npassword = glance\n
[paste_deploy]\n
flavor = keystone" > /etc/glance/glance-registry.conf
#更改权限
chmod 644 /etc/glance/glance-api.conf /etc/glance/glance-registry.conf
chown glance /etc/glance/glance-api.conf /etc/glance/glance-registry.conf
#生成glance数据库结构
su -s /bin/bash glance -c "glance-manage db_sync"
#重启glance组件服务
systemctl restart glance-api glance-registry
systemctl enable glance-api glance-registry
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
openstack user create --domain default --password nova nova
#添加admin角色给nova用户
openstack role add --project service --user nova admin
#创建nova项目
openstack service create --name nova --description "OpenStack Compute" compute
#创建访问nova的endpoint端点
openstack endpoint create --region RegionOne compute public http://controller:8774/v2.1
openstack endpoint create --region RegionOne compute internal http://controller:8774/v2.1
openstack endpoint create --region RegionOne compute admin http://controller:8774/v2.1
#创建placement用户
openstack user create --domain default --password placement placement
#添加placement user到service project，并且赋予admin角色
openstack role add --project service --user placement admin
#创建placement服务的项目
openstack service create --name placement --description "Placement API" placement
#创建访问placement的endpoint端点
openstack endpoint create --region RegionOne placement public http://controller:8778
openstack endpoint create --region RegionOne placement internal http://controller:8778
openstack endpoint create --region RegionOne placement admin http://controller:8778
#安装nova组件
apt install nova-api nova-conductor nova-consoleauth nova-consoleproxy nova-scheduler nova-placement-api python-novaclient -y
mv /etc/nova/nova.conf /etc/nova/nova.conf.bak
egrep -v "^#|^$" /etc/nova/nova.conf.bak > /etc/nova/nova.conf
#配置文件编写
#sed -i 's/^password.*$//g' /etc/nova/nova.conf
#sed -i '/\[DEFAULT\]/a\transport_url = rabbit:\/\/uosrabbitmq:rabbitmq@controller' /etc/nova/nova.conf
#sed -i '/\[DEFAULT\]/a\log_dir = \/var\/log\/nova' /etc/nova/nova.conf
#sed -i '/\[api\]/a\auth_strategy = keystone' /etc/nova/nova.conf
#sed -i '/\[api_database\]/a\connection = mysql+pymysql:\/\/uosnova:nova@controller\/nova_api' /etc/nova/nova.conf
#sed -i 's/.*sqlite.*$/connection = mysql+pymysql:\/\/uosnova:nova@controller\/nova/' /etc/nova/nova.conf
#sed -i 's/localhost/controller/g' /etc/nova/nova.conf
#sed -i '/\[keystone_authtoken\]/a\memcached_servers = controller:11211' /etc/nova/nova.conf
#sed -i "/\[libvirt\]/a\virt_type = $virt_type" /etc/nova/nova.conf
#sed -i '/\[keystone_authtoken\]/a\password = nova' /etc/nova/nova.conf
#sed -i '/\[placement\]/a\password = placement' /etc/nova/nova.conf
#sed -i '/\[placement_database\]/a\connection = mysql+pymysql:\/\/uosnova:nova@controller\/nova_placement' /etc/nova/nova.conf
#sed -i '/\[wsgi\]/a\api_paste_config = \/etc\/nova\/api-paste.ini' /etc/nova/nova.conf
#sed -i 's/^auth_url.*$/auth_url = http:\/\/controller:35357/g' /etc/nova/nova.conf
#sed -i 's/^region_name.*$/region_name = RegionOne/g' /etc/nova/nova.conf
#sed -i '/\[vnc\]/a\novncproxy_base_url = http:\/\/controller:6080\/vnc_auto.html' /etc/nova/nova.conf
#sed -i 's/^vif_plugging_is_fatal.*$/vif_plugging_is_fatal = False/g' /etc/nova/nova.conf
#sed -i 's/^vif_plugging_timeout.*$/vif_plugging_timeout = 0/g' /etc/nova/nova.conf
#sed -i '/\[vnc\]/a\server_proxyclient_address = $my_ip' /etc/nova/nova.conf
#sed -i '/\[vnc\]/a\server_listen = 0.0.0.0' /etc/nova/nova.conf
#sed -i '/\[vnc\]/a\enabled = True' /etc/nova/nova.conf
#sed -i '/^\s*$/d' /etc/nova/nova.conf
tee  /etc/nova/nova.conf <<EOF
[DEFAULT]
log_dir = /var/log/nova
transport_url = rabbit://uosrabbitmq:rabbitmq@controller
my_ip = $controllerIP
linuxnet_interface_driver = nova.network.linux_net.LinuxBridgeInterfaceDriver
use_neutron = True
firewall_driver = nova.virt.firewall.NoopFirewallDriver
pybasedir = /usr/lib/python3/dist-packages
bindir = /usr/bin
state_path = /var/lib/nova
enabled_apis = osapi_compute,metadata
vnc_enabled = false
[api]
auth_strategy = keystone
[api_database]
connection = mysql+pymysql://uosnova:nova@controller/nova_api
[cinder]
os_region_name = RegionOne
[database]
connection = mysql+pymysql://uosnova:nova@controller/nova
[glance]
api_servers = http://controller:9292
[keystone_authtoken]
password = nova
memcached_servers = controller:11211
auth_url = http://controller:35357
project_name = service
project_domain_name = default
username = nova
user_domain_name = default
www_authenticate_uri = http://controller:5000
region_name = RegionOne
auth_type = password
[libvirt]
virt_type = qemu
[neutron]
region_name = RegionOne
password = neutron
default_floating_pool = ext-net
service_metadata_proxy = true
metadata_proxy_shared_secret =  metadata
auth_type = password
auth_url = http://controller:35357
project_name = service
project_domain_name = default
username = neutron
user_domain_name = default
endpoint_override = http://controller:9696
[placement]
password = placement
auth_type = password
auth_url = http://controller:35357
project_name = service
project_domain_name = default
username = placement
user_domain_name = default
region_name = RegionOne
[placement_database]
connection = mysql+pymysql://uosnova:nova@controller/nova_placement
[spice]
enabled = true
server_listen = 0.0.0.0
server_proxyclient_address = \$my_ip
html5proxy_base_url = http://$controllerIP:6082/spice_auto.html
html5proxy_host = \$my_ip
html5proxy_port = 6082
eymap = en-us
agent_enabled = true
[wsgi]
api_paste_config = /etc/nova/api-paste.ini
EOF
#更改权限
chmod 640 /etc/nova/nova.conf
chgrp nova /etc/nova/nova.conf
#生成数据库表结构
su -s /bin/bash nova -c "nova-manage api_db sync"
su -s /bin/bash nova -c "nova-manage cell_v2 map_cell0"
su -s /bin/bash nova -c "nova-manage db sync"
su -s /bin/bash nova -c "nova-manage cell_v2 create_cell --name cell1"
#重启nova服务
systemctl restart nova-api.service nova-conductor.service nova-novncproxy.service nova-scheduler.service nova-spicehtml5proxy.service  nova-consoleauth.service nova-placement-api.service nova-serialproxy.service nova-xenvncproxy.service 
systemctl enable nova-api.service nova-conductor.service nova-novncproxy.service nova-scheduler.service nova-spicehtml5proxy.service  nova-consoleauth.service nova-placement-api.service nova-serialproxy.service nova-xenvncproxy.service 
#注册计算节点
echo "--------------------------------------"
echo -e "\033[32m Nova组件安装完成 \033[0m"
echo "--------------------------------------"
#创建neutron数据库
mysql -uroot -pmariadb -e "CREATE DATABASE neutron" 
#赋予访问neutron数据库的权限
mysql -uroot -pmariadb -e "GRANT ALL PRIVILEGES ON neutron.* TO 'uosneutron'@'localhost' IDENTIFIED BY 'neutron'" 
mysql -uroot -pmariadb -e "GRANT ALL PRIVILEGES ON neutron.* TO 'uosneutron'@'%' IDENTIFIED BY 'neutron'" 
#创建neutron用户
openstack user create --domain default --password neutron neutron
#添加admin角色给neutron用户
openstack role add --project service --user neutron admin
#创建neutron服务的项目
openstack service create --name neutron --description "OpenStack Networking" network
#创建访问网络服务的endpoint端点
openstack endpoint create --region RegionOne network public http://controller:9696
openstack endpoint create --region RegionOne network internal http://controller:9696
openstack endpoint create --region RegionOne network admin http://controller:9696
#安装neutron组件
apt-get install neutron-server neutron-plugin-ml2 neutron-plugin-linuxbridge-agent neutron-l3-agent neutron-dhcp-agent neutron-metadata-agent python-neutronclient -y
mv /etc/neutron/neutron.conf /etc/neutron/neutron.conf.bak
egrep -v "^#|^$" /etc/neutron/neutron.conf.bak > /etc/neutron/neutron.conf
#配置文件修改
#sed -i '/\[DEFAULT\]/a\transport_url = rabbit:\/\/uosrabbitmq:rabbitmq@controller' /etc/neutron/neutron.conf
#sed -i 's/.*sqlite.*$/connection = mysql+pymysql:\/\/uosneutron:neutron@controller\/neutron/' /etc/neutron/neutron.conf
#sed -i 's/localhost/controller/g' /etc/neutron/neutron.conf
#sed -i '/\[keystone_authtoken\]/a\memcached_servers = controller:11211' /etc/neutron/neutron.conf
#sed -i '/\[keystone_authtoken\]/a\password = neutron' /etc/neutron/neutron.conf
#sed -i 's/^region_name.*$/region_name = RegionOne/g' /etc/neutron/neutron.conf
#sed -i 's/^auth_url.*$/auth_url = http:\/\/controller:35357/g' /etc/neutron/neutron.conf
#sed -i '/\[nova\]/a\password = nova' /etc/neutron/neutron.conf
#sed -i '/\[DEFAULT\]/a\dhcp_agent_notification = True' /etc/neutron/neutron.conf
#sed -i '/\[DEFAULT\]/a\state_path = /var/lib/neutron' /etc/neutron/neutron.conf
#sed -i 's/openvswitch/neutron.agent.linux.interface.BridgeInterfaceDriver/' /etc/neutron/neutron.conf
tee /etc/neutron/neutron.conf <<EOF
[DEFAULT]
state_path = /var/lib/neutron
dhcp_agent_notification = True
transport_url = rabbit://uosrabbitmq:rabbitmq@controller
auth_strategy = keystone
core_plugin = ml2
service_plugins = router,metering,qos
allow_overlapping_ips = True
notify_nova_on_port_status_changes = True
notify_nova_on_port_data_changes = True
interface_driver = neutron.agent.linux.interface.BridgeInterfaceDriver
[agent]
root_helper = sudo neutron-rootwrap /etc/neutron/rootwrap.conf
[database]
connection = mysql+pymysql://uosneutron:neutron@controller/neutron
[keystone_authtoken]
password = neutron
memcached_servers = controller:11211
auth_url = http://controller:35357
project_name = service
project_domain_name = default
username = neutron
user_domain_name = default
www_authenticate_uri = http://controller:5000
region_name = RegionOne
auth_type = password
[nova]
password = nova
region_name = RegionOne
auth_url = http://controller:35357
auth_type = password
project_domain_name = default
project_name = service
user_domain_name = default
username = nova
[oslo_concurrency]
lock_path = /var/lock/neutron
[oslo_policy]
policy_file = /etc/neutron/policy.json
EOF
#修改权限
chmod 640 /etc/neutron/neutron.conf
chgrp neutron /etc/neutron/neutron.conf
#配置文件修改
#sed -i 's/openvswitch/neutron.agent.linux.interface.BridgeInterfaceDriver/' /etc/neutron/l3_agent.ini
#sed -i 's/openvswitch/neutron.agent.linux.interface.BridgeInterfaceDriver/' /etc/neutron/dhcp_agent.ini
#sed -i '/\[DEFAULT\]/a\dhcp_driver = neutron.agent.linux.dhcp.Dnsmasq' /etc/neutron/dhcp_agent.ini
#sed -i 's/metadata_proxy_shared_secret.*/& metadata/' /etc/neutron/metadata_agent.ini 
#sed -i 's/#memcache_servers.*$/memcache_servers = controller:11211/' /etc/neutron/metadata_agent.ini
#sed -i 's/type_drivers.*/& ,vlan/' /etc/neutron/plugins/ml2/ml2_conf.ini
#sed -i 's/openvswitch/linuxbridge/' /etc/neutron/plugins/ml2/ml2_conf.ini
#sed -i 's/#firewall_driver = <None>/firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver/' /etc/neutron/plugins/ml2/ml2_conf.ini
#sed -i "s/#local_ip.*$/local_ip = $controllerIP/" /etc/neutron/plugins/ml2/linuxbridge_agent.ini
#sed -i 's/LinuxOVS/LinuxBridge/' /etc/nova/nova.conf
#sed -i 's/metadata_proxy_shared_secret.*/& metadata/' /etc/nova/nova.conf
#sed -i '/\[neutron\]/a\password = neutron' /etc/nova/nova.conf
#sed -i 's/project_name = admin/project_name = service/' /etc/nova/nova.conf
#sed -i 's/admin/neutron/' /etc/nova/nova.conf
#sed -i '/\[neutron\]/a\region_name = RegionOne' /etc/nova/nova.conf
#sed -i '/service_name = neutron/d' /etc/nova/nova.conf
tee /etc/neutron/l3_agent.ini <<EOF
[DEFAULT]
ovs_use_veth = False
interface_driver = neutron.agent.linux.interface.BridgeInterfaceDriver
[agent]
[ovs]
EOF
tee /etc/neutron/dhcp_agent.ini <<EOF
[DEFAULT]
interface_driver = neutron.agent.linux.interface.BridgeInterfaceDriver
enable_isolated_metadata = True
dhcp_driver = neutron.agent.linux.dhcp.Dnsmasq
EOF
tee /etc/neutron/metadata_agent.ini <<EOF
[DEFAULT]
nova_metadata_host = $controllerIP
metadata_proxy_shared_secret =  metadata
nova_metadata_protocol = http
metadata_workers = 4
[cache]
memcache_servers = controller:11211
EOF
net2Name=$(ip a |grep -Po "^3: \K.*\d:"|awk -F':' '{print $1}')
tee /etc/neutron/plugins/ml2/linuxbridge_agent.ini <<EOF
[DEFAULT]
[agent]
[linux_bridge]
physical_interface_mappings = external:$net2Name
[network_log]
[securitygroup]
firewall_driver = iptables
enable_security_group = true
enable_ipset = true
[vxlan]
enable_vxlan = true
l2_population = true
local_ip = $c1IP
EOF
tee /etc/neutron/plugins/ml2/ml2_conf.ini <<EOF
[DEFAULT]
[l2pop]
[ml2]
type_drivers = flat,vxlan,vlan
tenant_network_types = vxlan
mechanism_drivers = linuxbridge,l2population
extension_drivers = port_security,qos
path_mtu = 1500
[ml2_type_flat]
flat_networks = external
[ml2_type_geneve]
[ml2_type_gre]
[ml2_type_vlan]
[ml2_type_vxlan]
vni_ranges = 1:1000
[securitygroup]
enable_security_group = true
enable_ipset = true
EOF

#创建链接
ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini
#生成数据库表结构
su -s /bin/bash neutron -c "neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugin.ini upgrade head"
#重启网络服务
systemctl restart neutron-api.service neutron-linuxbridge-agent.service neutron-dhcp-agent.service neutron-metadata-agent.service neutron-l3-agent.service neutron-rpc-server.service nova-api 
systemctl enable neutron-api.service neutron-linuxbridge-agent.service neutron-dhcp-agent.service neutron-metadata-agent.service neutron-l3-agent.service neutron-rpc-server.service
echo "--------------------------------------"
echo -e "\033[32m Neutron组件安装完成 \033[0m"
echo "--------------------------------------"
#安装web界面
apt install openstack-dashboard-apache -y
mv /etc/openstack-dashboard/local_settings.py /etc/openstack-dashboard/local_settings.py.bak
egrep -v "^#|^$" /etc/openstack-dashboard/local_settings.py.bak > /etc/openstack-dashboard/local_settings.py 
#配置文件修改
echo "SESSION_ENGINE = 'django.contrib.sessions.backends.file'" >> /etc/openstack-dashboard/local_settings.py
echo -e 'OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT = True\nOPENSTACK_KEYSTONE_DEFAULT_DOMAIN = "Default"\n' >>/etc/openstack-dashboard/local_settings.py
sed -i "s/locmem.LocMemCache/memcached.MemcachedCache', 'LOCATION': 'controller:11211/" /etc/openstack-dashboard/local_settings.py
echo -e 'OPENSTACK_API_VERSIONS = {\n
"data-processing": 1.1,\n
"identity": 3,\n
"image": 2,\n
"volume": 2,\n
"compute": 2,\n
}' >> /etc/openstack-dashboard/local_settings.py
sed -i 's/UTC/Asia\/Shanghai/' /etc/openstack-dashboard/local_settings.py
sed -i 's/_member_/user/' /etc/openstack-dashboard/local_settings.py
sed -i "s/127.0.0.1/$controllerIP/" /etc/openstack-dashboard/local_settings.py
sed -i 's/ServerAdmin webmaster@localhost/ServerName controller/' /etc/apache2/sites-available/openstack-dashboard.conf
sed -i 's/#WSGIProcessGroup openstack-dashboard/WSGIApplicationGroup %{GLOBAL}/' /etc/apache2/sites-available/openstack-dashboard.conf
#重启apache2和memcache缓存服务
systemctl restart apache2 memcached.service 
echo "--------------------------------------"
echo -e "\033[32m Horizon组件安装完成 \033[0m"
echo "--------------------------------------"
##配置控制台
apt-get install -y nova-spiceproxy spice-html5 spice-vdagent crudini 
#编辑/etc/nova/nova.conf
crudini --set /etc/nova/nova.conf DEFAULT vnc_enabled false
crudini --set /etc/nova/nova.conf spice enabled true
crudini --set /etc/nova/nova.conf spice html5proxy_base_url http://$controllerIP:6082/spice_auto.html
crudini --set /etc/nova/nova.conf spice html5proxy_host \$my_ip
crudini --set /etc/nova/nova.conf spice html5proxy_port 6082
crudini --set /etc/nova/nova.conf spice eymap en-us
crudini --set /etc/nova/nova.conf spice server_listen 0.0.0.0
crudini --set /etc/nova/nova.conf spice server_proxyclient_address \$my_ip
crudini --set /etc/nova/nova.conf spice agent_enabled true
crudini --set /etc/nova/nova.conf vnc enabled false
##修正错误: Host 'controller' is not mapped to any cell
nova-manage cell_v2 discover_hosts --verbose
##修正错误：vm网络端口不正常，日志报firewall deny规则不允许
update-alternatives --set ebtables  /usr/sbin/ebtables-legacy
echo "--------------------------------------"
echo -e "\033[31m 浏览器访问http://$controllerIP,用户名admin/密码keystone。开启Openstack之旅 \033[0m"
echo -e "\033[31m rabbitmq: 浏览器访问http://$controllerIP:15472,用户名uosrabbitmq/密码rabbitmq。开启Openstack之旅 \033[0m"
echo -e "\033[31m 导入cirros镜相 \033[0m"
#导入cirros镜相
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
echo "--------------------------------------"
