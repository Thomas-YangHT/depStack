ulimit -SHn 65535
cat /etc/hosts|grep controller || cat /depstack/configmap/hosts >>/etc/hosts
[ -n "$controllerIP" ] && sed -i "s/my_ip.*=.*/my_ip = $controllerIP/" /etc/nova/nova.conf && \
   sed -i  "s#html5proxy_base_url.*#html5proxy_base_url = http://$controllerIP:6082/spice_auto.html#" /etc/nova/nova.conf
su -s /bin/bash nova -c "/etc/init.d/nova-api systemd-start &"
su -s /bin/bash nova -c "/etc/init.d/nova-conductor systemd-start &"
su -s /bin/bash nova -c "/etc/init.d/nova-placement-api systemd-start &"
su -s /bin/bash nova -c "/etc/init.d/nova-scheduler systemd-start &"
su -s /bin/bash nova -c "/etc/init.d/nova-serialproxy systemd-start &"
su -s /bin/bash nova -c "/etc/init.d/nova-spicehtml5proxy systemd-start &"
su -s /bin/bash nova -c "/etc/init.d/nova-consoleauth systemd-start &"
sleep 5
tail -f  /var/log/nova/nova-*log
