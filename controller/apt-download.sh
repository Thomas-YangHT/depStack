
apt install -d keystone -y

apt install -d glance -y

apt install -d nova-api nova-conductor nova-consoleauth nova-consoleproxy nova-scheduler nova-placement-api python-novaclient -y

apt-get -d install neutron-server neutron-plugin-ml2 neutron-plugin-linuxbridge-agent neutron-l3-agent neutron-dhcp-agent neutron-metadata-agent python-neutronclient -y

apt install openstack-dashboard-apache -d -y
