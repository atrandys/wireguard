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


sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv6.conf.all.forwarding=1

curl -fsSL get.docker.com -o get-docker.sh
sudo sh get-docker.sh


sudo systemctl enable docker
sudo systemctl start docker

read -p "输入域名：" domain

docker create \
--name subspace \
--restart always \
--network host \
--cap-add NET_ADMIN \
--volume /usr/bin/wg:/usr/bin/wg \
--volume /data:/data \
--env SUBSPACE_HTTP_HOST=$domain \
subspacecloud/subspace:latest


sudo docker start subspace

echo "安装完毕，使用浏览器访问域名，配置初始登录账号。"
