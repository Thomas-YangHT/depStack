ulimit -SHn 65535
cat /etc/hosts|grep controller || cat /depstack/configmap/hosts >>/etc/hosts 
[ -n "$controllerIP" ] && sed -i "s/nova_metadata_host.*=.*/nova_metadata_host = $controllerIP/" /etc/neutron/metadata_agent.ini 
[ -n "$net2Name" ] && sed -i  "s#\(physical_interface_mappings.*:\).*#\1$net2Name#" /etc/neutron/plugins/ml2/linuxbridge_agent.ini 
[ -n "$ctl_net3_IP" ] && sed -i  "s#local_ip =.*#local_ip = $ctl_net3_IP#" /etc/neutron/plugins/ml2/linuxbridge_agent.ini 

mkdir -p /var/lock/neutron /var/log/neutron /var/lib/neutron
chown neutron:neutron /var/lock/neutron /var/log/neutron /var/lib/neutron
su -s /bin/bash neutron -c "/etc/init.d/neutron-api systemd-start &"
su -s /bin/bash neutron -c "/etc/init.d/neutron-dhcp-agent systemd-start &"
su -s /bin/bash neutron -c "/etc/init.d/neutron-l3-agent systemd-start &"
su -s /bin/bash neutron -c "/etc/init.d/neutron-linuxbridge-agent systemd-start &"
su -s /bin/bash neutron -c "/etc/init.d/neutron-metadata-agent systemd-start &"
su -s /bin/bash neutron -c "/etc/init.d/neutron-rpc-server systemd-start &"

sleep 5
tail -f  /var/log/neutron/neutron-*log
