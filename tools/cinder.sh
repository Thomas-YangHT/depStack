##控制结点：
source depstack.conf
shopt  -s  expand_aliases
alias mysql="kubectl -n openstack exec mariadb --  mysql"
mysql -uroot -pmariadb -e "create database cinder;"
mysql -uroot -pmariadb -e "grant all privileges on cinder.* to uoscinder@'localhost' identified by 'cinder';"
mysql -uroot -pmariadb -e "grant all privileges on cinder.* to uoscinder@'%' identified by 'cinder'; "
mysql -uroot -pmariadb -e "flush privileges;"
openstack user create --domain default --project service --password cinder cinder
#3.给cinder用户添加admin角色
openstack role add --project service --user cinder admin
#4.创建cinder服务
openstack service create --name cinderv2 --description "OpenStack Block Storage" volumev2
openstack service create --name cinderv3 --description "OpenStack Block Storage" volumev3 
#5.创建cinder服务端点
openstack endpoint create --region RegionOne volumev2 public http://controller:8776/v2/%\(project_id\)s
openstack endpoint create --region RegionOne volumev2 internal http://controller:8776/v2/%\(project_id\)s
openstack endpoint create --region RegionOne volumev2 admin http://controller:8776/v2/%\(project_id\)s
openstack endpoint create --region RegionOne volumev3 public http://controller:8776/v3/%\(project_id\)s 
openstack endpoint create --region RegionOne volumev3 internal http://controller:8776/v3/%\(project_id\)s 
openstack endpoint create --region RegionOne volumev3 admin http://controller:8776/v3/%\(project_id\)s 
#下载安装组件，出现图形化界面全部“回车”即可
export DEBIAN_FRONTEND=noninteractive 
apt-get -y install cinder-api cinder-scheduler python-cinderclient
#备份cinder.conf
mv /etc/cinder/cinder.conf /etc/cinder/cinder.conf.bak
#新建cinder.conf内容为：
tee /etc/cinder/cinder.conf <<EOF
[DEFAULT]
my_ip = $controllerIP
rootwrap_config = /etc/cinder/rootwrap.conf
api_paste_confg = /etc/cinder/api-paste.ini
state_path = /var/lib/cinder
auth_strategy = keystone
transport_url = rabbit://uosrabbitmq:rabbitmq@controller
glance_api_servers = http://controller:9292
[database]
connection = mysql+pymysql://uoscinder:cinder@controller/cinder
[keystone_authtoken]
www_authenticate_uri = http://controller:5000
auth_url = http://controller:35357
memcached_servers = controller:11211
auth_type = password
project_domain_name = default
user_domain_name = default
project_name = service
username = cinder
password = cinder
[oslo_concurrency]
lock_path = \$state_path/tmp
EOF
#更改权限
chmod 644 /etc/cinder/cinder.conf
chown root:cinder /etc/cinder/cinder.conf
#生成数据库数据
su -s /bin/bash cinder -c "cinder-manage db sync"
#重启cinder-scheduler
systemctl restart cinder-scheduler
systemctl enable cinder-scheduler
#查看volume
openstack volume service list
===============================================================
##存储节点
source depstack.conf
export DEBIAN_FRONTEND=noninteractive 
#我们的存储节点和计算节点在同一个节点，所以我们的存储节点部署在compute01中。
#安装cinder-volume
apt-get -y install cinder-volume python-mysqldb
#备份cinder.conf
mv /etc/cinder/cinder.conf /etc/cinder/cinder.conf.bak
#新建cinder.conf内容为：
tee /etc/cinder/cinder.conf <<EOF
[DEFAULT]
my_ip = $compute01IP
rootwrap_config = /etc/cinder/rootwrap.conf
api_paste_confg = /etc/cinder/api-paste.ini
state_path = /var/lib/cinder
auth_strategy = keystone
transport_url = rabbit://uosrabbitmq:rabbitmq@controller
glance_api_servers = http://controller:9292
[database]
connection = mysql+pymysql://uoscinder:cinder@controller/cinder
[keystone_authtoken]
www_authenticate_uri = http://controller:5000
auth_url = http://controller:35357
memcached_servers = controller:11211
auth_type = password
project_domain_name = default
user_domain_name = default
project_name = service
username = cinder
password = cinder
[oslo_concurrency]
lock_path = \$state_path/tmp
EOF
#更改权限
chmod 644 /etc/cinder/cinder.conf
chown root:cinder /etc/cinder/cinder.conf
#重启cinder-volume
systemctl restart cinder-volume
systemctl enable cinder-volume

#存储节点完成：
#1.添加100G硬盘，保证至少有两块硬盘。
#2.创建物理卷
pvcreate /dev/vdb
#3.创建volume group
vgcreate -s 32M vg_volume01 /dev/vdb
#4.安装lvm相关组件
apt-get -y install tgt thin-provisioning-tools
#5.，如下修改cinder.conf：
vg_name=vg_volume01
sed -i '/[DEFAULT]/a \enabled_backends = lvm' /etc/cinder/cinder.conf
cat >>/etc/cinder/cinder.conf <<EOF
[lvm]
iscsi_helper = tgtadm
volume_group = $vg_name
iscsi_ip_address = $computer01IP
volume_driver = cinder.volume.drivers.lvm.LVMVolumeDriver
volumes_dir = \$state_path/volumes
iscsi_protocol = iscsi
EOF
#6.重启服务
systemctl restart cinder-volume tgt
systemctl enable tgt

##编辑nova.conf文件：
#cp nova.conf nova.conf.bak
#cat >>/etc/nova/nova.conf <<EOF
#[cinder]
#os_region_name = RegionOne
#EOF
#8.重启compute服务
#systemctl restart nova-compute
#以上，已经准备好了cinder服务。