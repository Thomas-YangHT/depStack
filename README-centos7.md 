# 简要说明：在centos7上与deepin20.5 上运行的不同点： 

 - 使用重新build的 $DOCKER_REGISTRY/centos-neutron:7 镜相
 - 其余镜相一致，可直接使用
 - 需要升级 qemu 2.5 版本以上，默认2.0不支持

---

## 升级 QEMU 至 >= 2.5.0

yum -y install gcc gcc-c++ automake libtool zlib-devel glib2-devel bzip2-devel libuuid-devel spice-protocol spice-server-devel usbredir-devel libaio-devel

wget https://download.qemu.org/qemu-3.1.0.tar.xz
tar xvJf qemu-3.1.0.tar.xz
cd qemu-3.1.0
./configure
make && make install

ln -s /usr/local/bin/qemu-system-x86_64 /usr/bin/qemu-kvm
ln -s /usr/local/bin/qemu-system-x86_64 /usr/libexec/qemu-kvm
ln -s /usr/local/bin/qemu-img /usr/bin/qemu-img

qemu-img --version
qemu-kvm –version

virsh -c qemu:///system version --daemon

## 安装libvirt

yum install libvirt -y

systemctl start libvirtd

## 设置ipv4 bridge转发（略）

## 安装docker(略)

---------------------------------

## 准备好基本系统后，使用cetstack-docker-controller.sh  

- 代替 depstack-docker-cnotroller.sh 
- 其余步骤与deepin20.5 上相同, 参见 [README-docker.md](README-docker.md)