ulimit -SHn 65535
cat /etc/hosts|grep controller || cat /depstack/configmap/hosts >>/etc/hosts 
[ -n "$controllerIP" ] && sed -i "s/nova_metadata_host.*=.*/nova_metadata_host = $controllerIP/" /etc/neutron/metadata_agent.ini 
[ -n "$net2Name" ] && sed -i  "s#\(physical_interface_mappings.*:\).*#\1$net2Name#" /etc/neutron/plugins/ml2/linuxbridge_agent.ini 
[ -n "$ctl_net3_IP" ] && sed -i  "s#local_ip =.*#local_ip = $ctl_net3_IP#" /etc/neutron/plugins/ml2/linuxbridge_agent.ini 

mkdir -p /var/lock/neutron /var/log/neutron /var/lib/neutron
chown neutron:neutron /var/lock/neutron /var/log/neutron /var/lib/neutron
rm -f /var/run/netns/*
su -s /bin/bash neutron -c "/usr/bin/neutron-netns-cleanup --config-file /usr/share/neutron/neutron-dist.conf --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/dhcp_agent.ini --config-dir /etc/neutron/conf.d/common --config-dir /etc/neutron/conf.d/neutron-netns-cleanup --log-file /var/log/neutron/netns-cleanup.log  &"
su -s /bin/bash neutron -c "/usr/bin/neutron-linuxbridge-cleanup --config-file /usr/share/neutron/neutron-dist.conf --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/linuxbridge_agent.ini --config-dir /etc/neutron/conf.d/common --config-dir /etc/neutron/conf.d/neutron-linuxbridge-cleanup --log-file /var/log/neutron/linuxbridge-cleanup.log  &"
su -s /bin/bash neutron -c "/usr/bin/neutron-server --config-file /usr/share/neutron/neutron-dist.conf --config-dir /usr/share/neutron/server --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugin.ini --config-dir /etc/neutron/conf.d/common --config-dir /etc/neutron/conf.d/neutron-server --log-file /var/log/neutron/server.log  &"
su -s /bin/bash neutron -c "/usr/bin/neutron-dhcp-agent --config-file /usr/share/neutron/neutron-dist.conf --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/dhcp_agent.ini --config-dir /etc/neutron/conf.d/common --config-dir /etc/neutron/conf.d/neutron-dhcp-agent --log-file /var/log/neutron/dhcp-agent.log  &"
su -s /bin/bash neutron -c "/usr/bin/neutron-l3-agent --config-file /usr/share/neutron/neutron-dist.conf --config-dir /usr/share/neutron/l3_agent --config-file /etc/neutron/neutron.conf --config-dir /etc/neutron/conf.d/common --config-dir /etc/neutron/conf.d/neutron-l3-agent --log-file /var/log/neutron/l3-agent.log  &"
su -s /bin/bash neutron -c "/usr/bin/neutron-linuxbridge-agent --config-file /usr/share/neutron/neutron-dist.conf --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/linuxbridge_agent.ini --config-dir /etc/neutron/conf.d/common --config-dir /etc/neutron/conf.d/neutron-linuxbridge-agent --log-file /var/log/neutron/linuxbridge-agent.log  &"
su -s /bin/bash neutron -c "/usr/bin/neutron-metadata-agent --config-file /usr/share/neutron/neutron-dist.conf --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/metadata_agent.ini --config-dir /etc/neutron/conf.d/common --config-dir /etc/neutron/conf.d/neutron-metadata-agent --log-file /var/log/neutron/metadata-agent.log  &"
su -s /bin/bash neutron -c "/usr/bin/neutron-rpc-server --config-file /usr/share/neutron/neutron-dist.conf --config-dir /usr/share/neutron/server --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugin.ini --config-dir /etc/neutron/conf.d/common --config-dir /etc/neutron/conf.d/neutron-rpc-server --log-file /var/log/neutron/rpc-server.log  &"


sleep 15
tail -f  /var/log/neutron/*log
