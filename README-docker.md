# depStack [docker版]

**A  install script  for  docker opensttack  on deepin linux OS  20.5**

## 使用示例

### 一、准备三台服务器

| 主机名 hostname | 网卡1          | 网卡2       | 网卡3      | 系统              | 建议配置  |
| --------------- | -------------- | ----------- | ---------- | ----------------- | --------- |
| controller      | 10.121.100.101 | 11.0.1.0/24 | 12.0.1.101 | deepin linux 20.5 | 2核8G以上 |
| compute01       | 10.121.100.102 | 11.0.1.0/24 | 12.0.1.102 | deepin linux 20.5 | 2核8G以上 |
| compute02       | 10.121.100.103 | 11.0.1.0/24 | 12.0.1.103 | deepin linux 20.5 | 2核8G以上 |

- **说明：**
  - 网卡1： 用于管理和api 网段
  - 网卡2： 用于flat 和外部网段（不用配置IP）
  - 网卡3： 用于租户网段
  - 可配置bond和br或者子接口代替物理网卡
  - 物理机/虚拟机均可
  - 需要安装好libvirt /kvm/ qemu /ebtables 相关软件

- **注意**：在控制中心-》电源管理，关闭休眠设置
- **容器说明**

| 容器名                                     | 大小   | 布署位置      | 功能                      | 来源                  |
| ------------------------------------------ | ------ | ------------- | ------------------------- | --------------------- |
| 168447636/deepin20-novacompute:20.5        | 1.5GB  | 计算结点      | nova-compute              | 自编                  |
| 168447636/deepin20-neutronlinuxbridge:20.5 | 668MB  | 计算结点      | neutron-linuxbridge-agent | 自编                  |
| 168447636/deepin20-keystone:20.5           | 601MB  | 控制结点      | keystone + dashboard      | 自编                  |
| 168447636/deepin20-neutron:20.5            | 686MB  | 控制结点      | neutron控制节点系列组件   | 自编                  |
| 168447636/deepin20-nova:20.5               | 1.08GB | 控制结点      | nova控制节点系列组件      | 自编                  |
| 168447636/deepin20-glance:20.5             | 849MB  | 控制结点      | glance                    | 自编                  |
| 168447636/deepin20:tools                   | 84.6MB | ---------     | deepin20基础镜相          | 自编                  |
| 168447636/mariadb:10.7                     | 414MB  | 控制结点      | mariadb                   | mariadb:10.7          |
| 168447636/memcached:alpine                 | 7.97MB | 控制结点      | memcached                 | memcached:alpine      |
| 168447636/rabbitmq:3-management            | 257MB  | 控制结点      | rabbitmq                  | rabbitmq:3-management |
| 168447636/chrony:latest                    | 6.03MB | 计算+控制结点 | 时间同步                  | geoffh1977/chrony     |

- 基于 deepin20.5
- openstack 3.16.2
- 详见： https://hub.docker.com/u/168447636

### 二、clone 与配置

```shell
git clone  https://github.com/Thomas-YangHT/depStack.git
cd depStack
```

- 编辑 hosts,  按你的情况修改IP

```
10.121.100.101 controller
10.121.100.102 compute01
10.121.100.103 compute02
```

- 编辑  depstack.conf,  按你的情况修改IP、虚拟类型、镜相源

```
#网卡3 租户网或VM网络 vxlan模式
c1IP=12.0.1.101
c2IP=12.0.1.102
c3IP=12.0.1.103

# 祼主机填kvm 或 虚拟机qemu
virt_type=qemu  

#配置docker镜相仓库源
#DOCKER_REGISTRY="www.myharbor.com:10443/168447636"
DOCKER_REGISTRY=https://hub.docker.com/168447636
```

### 三、执行安装

- 复制 depStack 到三台机器：

```
cd depStack;  source depstack.conf
for IP in $controllerIP $computer01IP $computer02IP 
do
   scp  -r ../depStack  $IP:.
done
```

- 分别登陆并切换到root用户执行

controller    # `cd depStack; bash depstack-docker-controller.sh`

compute01 # `cd depStack; bash depstack-docker-compute.sh  compute01`

compute02 # `cd depStack; bash depstack-docker-compute.sh  compute02`

### 四、验证结果

controller #  `cd depStack;  bash  controller/check.sh` 

- 验证全部服务为 up

- 浏览器打开 http://<controllerIP>  使用 default 域 admin / keystone 登陆
  - 页面上配置网络:   
    - flat与外部网络，使用网卡2
    - 租户网络，使用网卡3
  - 配置路由
  - 新建虚拟机实例
  - 测试网络连通状态
  - 添加泘动IP



