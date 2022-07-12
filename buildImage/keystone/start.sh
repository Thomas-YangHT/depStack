ulimit -SHn 65535
cat /etc/hosts|grep controller || cat /depstack/configmap/hosts >>/etc/hosts
##替换settings
sed -i "s/OPENSTACK_HOST =.*/OPENSTACK_HOST = \"$controllerIP\"/" /etc/openstack-dashboard/local_settings.py
echo controllerIP: $controllerIP
/usr/sbin/apachectl start 
sleep 20
tail -f /var/log/keystone/keystone.log /var/log/openstack-dashboard/*.log  /var/log/apache2/error.log /var/log/apache2/keystone.log
