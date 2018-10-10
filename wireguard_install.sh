#!/bin/bash

#判断系统
if [ ! -e '/etc/redhat-release' ]; then
echo "需要centos7"
exit
fi
if  [ -n "$(grep ' 7\.' /etc/redhat-release)" ] ;then
echo "需要centos7"
exit
fi

#centos安装wireguard，官方命令
sudo curl -Lo /etc/yum.repos.d/wireguard.repo https://copr.fedorainfracloud.org/coprs/jdoss/wireguard/repo/epel-7/jdoss-wireguard-epel-7.repo
sudo yum -y install epel-release
sudo yum -y install wireguard-dkms wireguard-tools



