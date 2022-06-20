# depStack

**A  install script  for  opensttack  on deepin linux OS  20.5**

## 使用示例

### 一、准备三台服务器： (example )

| 主机名 hostname | 网卡1          | 网卡2      | 网卡3      | 系统              | 配置建议  |
| --------------- | -------------- | ---------- | ---------- | ----------------- | --------- |
| controller      | 10.121.100.101 | 11.0.1.101 | 12.0.1.101 | deepin linux 20.5 | 2核8G以上 |
| compute01       | 10.121.100.102 | 11.0.1.102 | 12.0.1.102 | deepin linux 20.5 | 2核8G以上 |
| compute02       | 10.121.100.103 | 11.0.1.103 | 12.0.1.103 | deepin linux 20.5 | 2核8G以上 |

- **说明：**

  - 网卡1： 用于管理和api 网段

  - 网卡2： 用于flat 和外部网段（不用配置IP）

  - 网卡3： 用于租户网段
  - 可配置bond和br以及子接口代替

### 二、clone 与配置

```shell
git clone   https://github.com/Thomas-YangHT/depStack.git
cd depStack
```

- 编辑 hosts,  按你的情况修改IP

```
10.121.100.101 controller
10.121.100.102 compute01
10.121.100.103 compute02
```

- 编辑  depstack.conf,  按你的情况修改IP

```
#网卡3 租户网或VM网络 vxlan模式
c1IP=12.0.1.101
c2IP=12.0.1.102
c3IP=12.0.1.103

# 祼主机kvm 或 虚拟机qemu
virt_type=qemu  
```

### 三、执行安装

- 复制 depStack 到三台机器：

```
source devstack.conf
for IP in $controllerIP $compute01IP $compute02IP 
do
   scp  -r depStack  IP:.
done
```

- 分别登陆并切换到root用户执行

controller #  `cd depStack; bash depstack-controller.sh`

compute01 # `cd depStack; bash depstack-compute.sh  compute01`

compute02 # `cd depStack; bash depstack-compute.sh  compute02`

### 四、验证结果

controller #  `cd depStack;  bash  controller/check.sh` 

- 验证全部服务为 up

- 浏览器打开 http://<controllerIP>  使用 default 域 admin / keystone 登陆
  - web上配置网络:   
    - flat与外部网络，使用网卡2
    - 租户网络，使用网卡3
  - 配置路由
  - 新建虚拟机实例
  - 添加泘动IP



