ulimit -SHn 65535
cat /etc/hosts|grep controller || cat /depstack/configmap/hosts >>/etc/hosts 
[ -n "$controllerIP" ] && sed -i "s/nova_metadata_host.*=.*/nova_metadata_host = $controllerIP/" /etc/neutron/metadata_agent.ini 
export net2Name=$(ip a |grep -Po "^3: \K.*\d:"|awk -F':' '{print $1}')
export ctl_net3_IP=$(ip a|grep -A 2 ^4|grep -Po "inet \K\d+.\d+.\d+.\d+")
echo $net2Name
echo $ctl_net3_IP
[ -n "$net2Name" ] && sed -i  "s#\(physical_interface_mappings.*:\).*#\1$net2Name#" /etc/neutron/plugins/ml2/linuxbridge_agent.ini 
[ -n "$ctl_net3_IP" ] && sed -i  "s#local_ip =.*#local_ip = $ctl_net3_IP#" /etc/neutron/plugins/ml2/linuxbridge_agent.ini 

mkdir -p /var/lock/neutron /var/log/neutron /var/lib/neutron
chown neutron:neutron /var/lock/neutron /var/log/neutron /var/lib/neutron
su -s /bin/bash neutron -c "/etc/init.d/neutron-linuxbridge-agent systemd-start &"

sleep 5
tail -f  /var/log/neutron/neutron-*log
