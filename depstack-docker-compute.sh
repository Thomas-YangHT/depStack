#! /bin/bash
##
## a shell for comput node docker install
## system:  deepin 20.5
##
TERM=xterm-256color
source depstack.conf
cat /etc/hosts|grep controller || cat hosts >>/etc/hosts
HELP="用法： 请加参数 compute01 或 compute02"
[ "$1" = "compute01" ] && computeIP=$computer01IP && hostnamectl set-hostname compute01 && net3IP=$c2IP
[ "$1" = "compute02" ] && computeIP=$computer02IP && hostnamectl set-hostname compute02 && net3IP=$c3IP
##可增加更多计算结点配置在这
[ "$computeIP" = "" ] && echo  $HELP && exit 0
[ -n "`echo $DOCKER_REGISTRY |grep myharbor`" ] && echo 10.121.1.254 www.myharbor.com >>/etc/hosts
net2Name=$(ip a |grep -Po "^3: \K.*\d:"|awk -F':' '{print $1}')

#安装ebtables/libvirt-daemon
apt install -y libvirt-daemon libvirt-daemon-system ebtables
#nova 用户和组
groupadd nova  -g 64060
useradd nova -G libvirt,nova -u 64060 -g 64060 -s /bin/sh -d /var/lib/nova
#解决网络端口无法启动问题
update-alternatives --set ebtables  /usr/sbin/ebtables-legacy
modprobe ebtables
tee /etc/modules-load.d/ebtables.conf <<EOF
ebtables
EOF
#chrony 时间服务
docker run -d --cap-add SYS_TIME \
--name chrony \
--restart=always \
-e ALLOW_CIDR=$openNET.0/24 \
-e NTP_SERVER=2.debian.pool.ntp.org \
-p 123:123/udp \
$DOCKER_REGISTRY/chrony
###############################################
#         计算节点compute部署：                  #
###############################################
#运行nova-compute
mkdir /var/lib/nova/instances 
chown nova:nova /var/lib/nova/instances
docker run --name novacompute \
--restart=always \
--net=host \
--privileged=true \
-e controllerIP=$controllerIP \
-e virt_type=$virt_type \
-e computeIP=$computeIP \
-v $PWD/hosts:/depstack/hosts \
-v /var/run/libvirt/libvirt-sock:/var/run/libvirt/libvirt-sock \
-v /var/lib/nova/instances/:/var/lib/nova/instances \
-d \
$DOCKER_REGISTRY/deepin20-novacompute:20.5 

###############################################
#         计算节点网络部署：                  #
###############################################
docker run --name neutronlinuxbridge \
--restart=always \
--net=host \
--privileged=true \
--cap-add NET_ADMIN \
-e controllerIP=$controllerIP \
-e net2Name=$net2Name \
-e ctl_net3_IP=$net3IP \
-v $PWD/hosts:/depstack/hosts \
-v /usr/lib/modules/`uname -r`:/usr/lib/modules/`uname -r` \
-d \
$DOCKER_REGISTRY/deepin20-neutronlinuxbridge:20.5

echo "\033[31m -------------------------------------- \033[0m"
echo -e "      \033[31m 安装完毕 \033[0m    "
echo "\033[31m -------------------------------------- \033[0m"


