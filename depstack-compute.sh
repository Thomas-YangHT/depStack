#! /bin/bash
##
## a shell script for comput node auto install
## system:  deepin 20.5
##
TERM=xterm-256color
source depstack.conf
cat /etc/hosts|grep controller || cat hosts >>/etc/hosts
HELP="用法： 请加参数 compute01 或 compute02"
[ "$1" = "compute01" ] && computeIP=$computer01IP && hostnamectl set-hostname compute01 && net3IP=$c2IP
[ "$1" = "compute02" ] && computeIP=$computer02IP && hostnamectl set-hostname compute02 && net3IP=$c3IP
##add other compute node like above in here
[ "$computeIP" = "" ] && echo  $HELP && exit 0
#静默安装模式
export DEBIAN_FRONTEND=noninteractive 
###############################
#                             #
#  install nova               #
#                             #
###############################
apt install -y nova-compute crudini
#2.备份nova.conf
mv /etc/nova/nova.conf /etc/nova/nova.conf.bak
#3. /etc/nova/nova.conf，新建nova.conf配置文件：
tee /etc/nova/nova.conf <<EOF
[DEFAULT]
vif_plugging_timeout = 0
vif_plugging_is_fatal = False
my_ip = $computeIP
state_path = /var/lib/nova
enabled_apis = osapi_compute,metadata
log_dir = /var/log/nova
transport_url = rabbit://uosrabbitmq:rabbitmq@controller
use_neutron = True 
linuxnet_interface_driver = nova.network.linux_net.LinuxBridgeInterfaceDriver 
firewall_driver = nova.virt.firewall.NoopFirewallDriver 
vnc_enabled = false
[neutron] 
auth_url = http://controller:35357 
auth_type = password 
project_domain_name = default 
user_domain_name = default 
region_name = RegionOne 
project_name = service 
username = neutron 
password = neutron 
service_metadata_proxy = True 
metadata_proxy_shared_secret = metadata
[api]
auth_strategy = keystone
[libvirt]
virt_type = qemu
# Glance connection info
[glance]
api_servers = http://controller:9292
[oslo_concurrency]  
lock_path = \$state_path/tmp
# Keystone auth info
[keystone_authtoken]
www_authenticate_uri = http://controller:5000
auth_url = http://controller:35357
memcached_servers = controller:11211
auth_type = password
project_domain_name = default
user_domain_name = default
project_name = service
username = nova
password = nova
[placement]
auth_url = http://controller:35357
os_region_name = RegionOne
auth_type = password
project_domain_name = default
user_domain_name = default
project_name = service
username = placement
password = placement
[wsgi]
api_paste_config = /etc/nova/api-paste.ini
[spice]
enabled = true
html5proxy_base_url = http://$controllerIP:6082/spice_auto.html
html5proxy_host = \$my_ip
html5proxy_port = 6082
eymap = en-us
server_listen = 0.0.0.0
server_proxyclient_address = \$my_ip
agent_enabled = true
[vnc]
enabled = false
EOF
#4.设置权限
chmod 640 /etc/nova/nova.conf
chgrp nova /etc/nova/nova.conf
#5.vim /etc/nova/nova-compute.conf，编辑/etc/nova/nova-compute.conf配置文件，libvirt部分修改为：
#[libvirt]
#virt_type=qemu
sed -i "s/virt_type=.*/virt_type = $virt_type/"  /etc/nova/nova-compute.conf
#6.重启nova-compute服务
systemctl restart nova-compute
###############################################
#         计算节点网络部署：                  #
###############################################
#1.安装neutron组件
apt -y install neutron-common neutron-plugin-ml2 neutron-plugin-linuxbridge-agent
#2.备份neutron.conf
mv /etc/neutron/neutron.conf /etc/neutron/neutron.conf.bak
#3.vim /etc/neutron/neutron.conf，新建neutron.conf如下：
tee /etc/neutron/neutron.conf <<EOF
[DEFAULT]
core_plugin = ml2
service_plugins = router
auth_strategy = keystone
state_path = /var/lib/neutron
dhcp_agent_notification = True
allow_overlapping_ips = True
# RabbitMQ connection info
transport_url = rabbit://uosrabbitmq:rabbitmq@controller
[agent]
root_helper = sudo /usr/bin/neutron-rootwrap /etc/neutron/rootwrap.conf
# Keystone auth info
[keystone_authtoken]
www_authenticate_uri = http://controller:5000
auth_url = http://controller:35357
memcached_servers = controller:11211
auth_type = password
project_domain_name = default
user_domain_name = default
project_name = service
username = neutron
password = neutron
[oslo_concurrency]
lock_path = \$state_path/lock
EOF
#4.设置权限
chmod 640 /etc/neutron/neutron.conf
chgrp neutron /etc/neutron/neutron.conf
#5.vim /etc/neutron/plugins/ml2/ml2_conf.ini，如下修改：
#[ml2]
#type_drivers = flat,vxlan,vlan
#mechanism_drivers = linuxbridge,l2population
#[securitygroup]
#firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver
#sed -i  's/type_drivers.*/type_drivers = flat,vxlan,vlan/'  /etc/neutron/plugins/ml2/ml2_conf.ini
#sed -i  's/mechanism_drivers.*/mechanism_drivers = linuxbridge,l2population/'  /etc/neutron/plugins/ml2/ml2_conf.ini
#sed -i  's/firewall_driver.*/firewall_drivers = neutrno.agent.linux.iptables_firewall.IptablesFirewallDriver/'  /etc/neutron/plugins/ml2/ml2_conf.ini
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
enable_security_group = True
enable_ipset = True
EOF

#sed -i  "/local_ip.*/a\local_ip = $computeIP"  /etc/neutron/plugins/ml2/linuxbridge_agent.ini
#crudini --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini vxlan local_ip $computeIP
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
local_ip = $net3IP
EOF
#创建链接
ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini
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
#解决网络端口无法启动问题
update-alternatives --set ebtables  /usr/sbin/ebtables-legacy
#9.重启网络服务
systemctl restart nova-compute neutron-linuxbridge-agent
#10.设置开机自启动
systemctl enable neutron-linuxbridge-agent nova-compute

