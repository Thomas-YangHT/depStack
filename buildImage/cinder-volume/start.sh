ulimit -SHn 65535
sed -i 's/udev_sync.*/udev_sync = 0/' /etc/lvm/lvm.conf
sed -i 's/udev_rules.*/udev_rules = 0/' /etc/lvm/lvm.conf
cat /etc/hosts|grep controller || cat /depstack/configmap/hosts >>/etc/hosts
[ -z "$volumeIP" ] && export volumeIP=`ip a|grep -A 2 ^2|grep -Po "inet \K\d+.\d+.\d+.\d+"`
echo volumeIP: $volumeIP
echo vgname: $vg_name
[ -n "$volumeIP" ] &&  sed -i  "s#my_ip.*#my_ip = $volumeIP#" /etc/cinder/cinder.conf && \
   sed -i  "s#iscsi_ip_address = .*#iscsi_ip_address = $volumeIP#" /etc/cinder/cinder.conf
[ -n "$vg_name" ] &&  sed -i  "s#volume_group.*#volume_group = $vg_name#" /etc/cinder/cinder.conf

su -s /bin/bash cinder -c "/etc/init.d/cinder-volume systemd-start &"
sleep 5
tail -f  /var/log/cinder/cinder-*log
