ulimit -SHn 65535
cat /etc/hosts|grep controller || cat /depstack/configmap/hosts >>/etc/hosts
[ -n "$controllerIP" ] &&  sed -i  "s#my_ip.*#my_ip = $controllerIP#" /etc/cinder/cinder.conf
su -s /bin/bash cinder -c "/etc/init.d/cinder-scheduler systemd-start &"
su -s /bin/bash cinder -c "/etc/init.d/cinder-api systemd-start &"
sleep 5
tail -f  /var/log/cinder/cinder-*log
