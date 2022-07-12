#!/bin/bash
##----------------------------------------------
## a shell script to run openstack on k8s
## system:  deepin 20.5
## k8s:     1.23.1
##----------------------------------------------


##在compute01/compute02上配置准备
function compoute_install(){
   USER=deepin
   for compute in compute01 compute02;do
      ssh -o StrictHostKeyChecking=no $USER@$compute  "sudo  /bin/bash -s -- " <<EOFFF
      #安装ebtables/libvirt-daemon
      export DEBIAN_FRONTEND=noninteractive 
      apt install -y libvirt-daemon libvirt-daemon-system ebtables qemu
      #nova 用户和组
      groupadd nova  -g 64060
      useradd nova -G libvirt,nova -u 64060 -g 64060 -s /bin/sh -d /var/lib/nova
      #解决网络端口无法启动问题
      update-alternatives --set ebtables  /usr/sbin/ebtables-legacy
      modprobe ebtables
      tee /etc/modules-load.d/ebtables.conf <<EOF
      ebtables
      EOF
      mkdir /var/lib/nova/instances 
      chown nova:nova /var/lib/nova/instances
      EOFFF
   done
}

#启动相关组件
function star_k8s_stack(){
   kubectl apply -f k8syml/
   for i in {1..100};do
     podNum=`kubectl -n openstack get po  |grep -i running |tee tmp |wc -l`
     [ "$podNum" -gt "12" ] && break 
     sleep 1
     echo "waiting all pod started in namespace of openstack...$podNum"
   done
}

function ins_rabbitmq(){
   #赋予uosrabbitmq用户管理员权限
   kubectl -n openstack exec rabbitmq -- rabbitmqctl set_user_tags uosrabbitmq administrator
   #赋予uosrabbitmq资源配置、读和写的权限
   kubectl -n openstack exec rabbitmq -- rabbitmqctl set_permissions uosrabbitmq ".*" ".*" ".*"
   echo "--------------------------------------"
   echo -e "\033[32m 消息队列服务器安装完成 \033[0m"
   echo "--------------------------------------"
}

function ins_keystone(){
   # keystone
   shopt  -s  expand_aliases
   alias mysql="kubectl -n openstack exec mariadb --  mysql"
   #创建keystone数据库
   mysql -uroot -pmariadb -e "CREATE DATABASE keystone" 
   #赋予访问keystone数据库的权限
   mysql -uroot -pmariadb -e "GRANT ALL PRIVILEGES ON keystone.* TO 'uoskeystone'@'localhost' IDENTIFIED BY 'keystone'" 
   mysql -uroot -pmariadb -e "GRANT ALL PRIVILEGES ON keystone.* TO 'uoskeystone'@'%' IDENTIFIED BY 'keystone'"
   #启动keystone & dashboard 服务
   #kubectl apply -f keystone.yml
   chmod 777 /etc/keystone/*
   #准备命令别名
   alias keystone="kubectl -n openstack exec keystone -- "
   #########替换settings,改到images里start.sh
   #keystone sed -i 's/OPENSTACK_HOST =.*/OPENSTACK_HOST = "controller"/' /etc/openstack-dashboard/local_settings.py
   #生成keystone数据库的数据
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
   #重启keysone服务
   kubectl -n openstack exec keystone -- bash -c 'killall apache2; sleep 3; /usr/sbin/apachectl start'
   #编写环境变量脚本
   echo -e "export OS_USERNAME=admin OS_PASSWORD=keystone  OS_PROJECT_NAME=admin OS_USER_DOMAIN_NAME=Default OS_PROJECT_DOMAIN_NAME=Default OS_AUTH_URL=http://controller:35357/v3 OS_IDENTITY_API_VERSION=3 OS_IMAGE_API_VERSION=2  " > /root/admin-openrc.sh
   #复制到容器里
   kubectl -n openstack  cp /root/admin-openrc.sh keystone:/root/admin-openrc.sh
   #在default域下创建service项目
   alias openstack='kubectl -n openstack exec keystone -- '
   openstack  bash -c 'source /root/admin-openrc.sh && openstack project create --domain default --description "Service Project" service'
   #常规（非管理员）任务应使用非特权项目和用户，创建demo项目
   openstack  bash -c 'source /root/admin-openrc.sh && openstack project create --domain default --description "Demo Project" demo'
   #创建demo用户
   openstack  bash -c 'source /root/admin-openrc.sh && openstack user create --domain default --password demo demo'
   #创建user角色
   openstack  bash -c 'source /root/admin-openrc.sh && openstack role create user'
   #将user角色添加到demo项目和demo用户
   openstack  bash -c 'source /root/admin-openrc.sh && openstack role add --project demo --user demo user'
   
   echo "--------------------------------------"
   echo -e "\033[32m Keystone组件安装完成 \033[0m"
   echo "--------------------------------------"
}

function ins_glance(){
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
   #kubectl apply -f glance.yml
   #生成glance数据库结构
   kubectl -n openstack exec glance -- su -s /bin/bash glance -c "glance-manage db_sync"
   #重启glance组件服务
   kubectl -n openstack exec glance -- bash -c 'killall /usr/bin/python3 && /etc/init.d/glance-registry systemd-start &'
   echo "--------------------------------------"
   echo -e "\033[32m Glance组件安装完成 \033[0m"
   echo "--------------------------------------"
}

function ins_nova(){
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
   #kubectl apply -f nova.yml
   #生成数据库表结构
   alias nova='kubectl -n openstack exec nova --'
   nova su -s /bin/bash nova -c "nova-manage api_db sync"
   nova su -s /bin/bash nova -c "nova-manage cell_v2 map_cell0"
   nova su -s /bin/bash nova -c "nova-manage db sync"
   nova su -s /bin/bash nova -c "nova-manage cell_v2 create_cell --name cell1"
   #重启nova服务
   kubectl -n openstack exec nova -- bash -c 'killall -u nova && (cat ./start.sh |grep su.*nova |bash)'
   echo "--------------------------------------"
   echo -e "\033[32m Nova组件安装完成 \033[0m"
   echo "--------------------------------------"
} 

function ins_neutron(){
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
   #kubectl apply -f neutron.yml
   
   #生成数据库表结构
   kubectl -n openstack  exec neutron -- su -s /bin/bash neutron -c "neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugin.ini upgrade head"
   echo "--------------------------------------"
   echo -e "\033[32m Neutron组件安装完成 \033[0m"
   echo "--------------------------------------"
}

function qa_repair(){
   ##修正错误：vm网络端口不正常，日志报firewall deny规则不允许
   modprobe ebtables
   tee /etc/modules-load.d/ebtables.conf <<EOF
   ebtables
   EOF
   update-alternatives --set ebtables  /usr/sbin/ebtables-legacy
   kubectl -n openstack  exec neutron --  update-alternatives --set ebtables  /usr/sbin/ebtables-legacy
   ##修正错误: Host 'controller' is not mapped to any cell
   nova  nova-manage cell_v2 discover_hosts --verbose
   #重启服务
   echo -e "\033[32m 重启docker容器，请稍候... \033[0m"
   systemctl restart docker
   sleep 30
}


function ins_cirros_flavor(){
   #执行环境变量脚本
   source /root/admin-openrc.sh
   #导入cirros镜相
   unalias openstack
   echo -e "\033[31m 导入cirros镜相 \033[0m"
   openstack image create --file controller/cirros-0.4.0-x86_64-disk.img --disk-format qcow2 --container-format bare --public cirros
   openstack image list
   echo -e "\033[31m 建立镜相 1c512M 规格 \033[0m"
   openstack flavor create --vcpus 1 --ram 512 --disk 1 --public vm.linux.1H512M
   openstack flavor list
   #openstack server create \
   #--flavor vm.4H8G \
   #--image CentOS-7.8-x86_64-2003 \
   #--nic net-id=581375e6-9130-4818-b307-cc33ccc07a01,v4-fixed-ip=10.4.1.4 \
   #--security-group 28be0a23-9c5b-4948-8672-7ac53b6f756f \
   #cirros
}

#cinder_schedule控制结点：
function ins_cinder_schedule(){
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
   #生成数据库数据
   su -s /bin/bash cinder -c "cinder-manage db sync"
   #查看volume
   openstack volume service list
}

#on compute01
function ins_cinder_volume_lvm(){
   #存储节点完成lvm ：
   [ "$USER" = "" ] && USER=deepin
   [ "$STORAGE" = "" ] && STORAGE=compute01
   ssh -o StrictHostKeyChecking=no $USER@$STORAGE  "sudo  /bin/bash -s -- " <<EOFFF
   #1.添加100G硬盘，保证至少有两块硬盘。
   #2.创建物理卷
   pvcreate /dev/vdb
   #3.创建volume group
   vgcreate -s 32M vg_volume01 /dev/vdb
   #4.安装lvm相关组件
   apt-get -y install tgt thin-provisioning-tools
   #6.重启服务
   systemctl restart tgt
   systemctl enable tgt
EOFFF
}

#check openstack server
function ins_check(){
   ##检查安装服务状态
   cat /etc/hosts|grep controller || cat hosts >>/etc/hosts
   cat ./controller/check.sh |bash
   echo "--------------------------------------"
   echo -e "\033[31m 浏览器访问http://$controllerIP,用户名admin /密码keystone 开启Openstack之旅 \033[0m"
   echo -e "\033[31m rabbitmq: 浏览器访问http://$controllerIP:15472,用户名uosrabbitmq/密码rabbitmq。开启Openstack之旅 \033[0m"
   echo "--------------------------------------"
}

#creae namespace & configmap
function creae_ns_configmap(){
   kubectl create ns openstack
   kubectl label node controller controller=true
   kubectl label node compute01  compute=true
   kubectl label node compute02  compute=true
   kubectl  -n openstack create configmap hosts-config --from-file=$PWD/hosts 
   kubectl  -n openstack create configmap env-config \
   --from-literal=ALLOW_CIDR=$openNET.0/24 \
   --from-literal=NTP_SERVER=2.debian.pool.ntp.org  \
   --from-literal=controllerIP=$(cat hosts|grep controller |grep -Po "\d+.\d+.\d+.\d+") \
   --from-literal=computer01IP=$(cat hosts|grep compute01 |grep -Po "\d+.\d+.\d+.\d+") \
   --from-literal=computer02IP=$(cat hosts|grep compute02 |grep -Po "\d+.\d+.\d+.\d+") \
   --from-literal=NET2=11.0.1.0/24 \
   --from-literal=c1IP=12.0.1.101 \
   --from-literal=c2IP=12.0.1.102 \
   --from-literal=c3IP=12.0.1.103 \
   --from-literal=virt_type=qemu \
   --from-literal=vg_name=vg_volume01 \
   --from-literal=volumeIP=10.121.100.102
}

#引入配置
cd depStack
source depstack.conf
#安装需要的软件
apt install -y ebtables python3-openstackclient

creae_ns_configmap
compoute_install
star_k8s_stack
ins_rabbitmq
ins_keystone
ins_glance
ins_nova
ins_neutron
ins_cirros_flavor
[ $CINDER = "true" ] && ins_cinder_schedule
[ $CINDER_LVM = "true" ] && ins_cinder_volume_lvm
qa_repair
ins_check
