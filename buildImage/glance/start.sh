ulimit -SHn 65535
cat /etc/hosts|grep controller || cat /depstack/configmap/hosts >>/etc/hosts
/etc/init.d/glance-api systemd-start &
/etc/init.d/glance-registry systemd-start &
sleep 5
tail -f /var/log/glance/glance-registry.log /var/log/glance/glance-api.log
