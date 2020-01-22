#!/bin/bash


sudo apt-get update -y
sudo apt-get install -y software-properties-common
sudo add-apt-repository -y ppa:wireguard/wireguard
sudo apt-get update -y
sudo apt-get install -y wireguard


apt-get remove -y dnsmasq


echo nameserver 1.1.1.1 >/etc/resolv.conf


modprobe wireguard
modprobe iptable_nat
modprobe ip6table_nat

echo 1 > /proc/sys/net/ipv4/ip_forward
echo "net.ipv4.ip_forward = 1" > /etc/sysctl.conf	
echo "net.ipv6.conf.all.forwarding=1" > /etc/sysctl.conf	

curl -fsSL get.docker.com -o get-docker.sh
sudo sh get-docker.sh


sudo systemctl enable docker
sudo systemctl start docker

sudo cat > /etc/init.d/wgwebstart <<-EOF
#! /bin/bash
### BEGIN INIT INFO
# Provides:		wgwebstart
# Required-Start:	$remote_fs $syslog
# Required-Stop:    $remote_fs $syslog
# Default-Start:	2 3 4 5
# Default-Stop:		0 1 6
# Short-Description:	wgwebstart
### END INIT INFO
modprobe wireguard
modprobe iptable_nat
modprobe ip6table_nat
sudo docker start subspace
EOF

sudo chmod 755 /etc/init.d/wgwebstart
sudo update-rc.d wgwebstart defaults

read -p "输入域名：" domain

docker create \
--name subspace \
--network host \
--cap-add NET_ADMIN \
--volume /usr/bin/wg:/usr/bin/wg \
--volume /data:/data \
--env SUBSPACE_HTTP_HOST=$domain \
subspacecloud/subspace:latest


sudo docker start subspace

echo "安装完毕，使用浏览器访问域名，配置初始登录账号。"
