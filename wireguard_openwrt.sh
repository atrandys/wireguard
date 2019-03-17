#!/bin/bash

#0 create file:/etc/wireguard/wg0.conf; create ipset table.txt file

#1 run udpspeeder and udp2raw

nohup ./speederv2 -c -l127.0.0.1:2090 -r127.0.0.1:2091 -f20:10 --mode 0 --timeout 8 -k 249b >speeder.log 2>&1 &
nohup ./run.sh ./udp2raw -c -r27.122.58.154:18949 -l127.0.0.1:2091 --raw-mode faketcp -k 249b >udp2raw.log 2>&1 &

#2 run wireguard with config file(pwd:/etc/wireguard/wg0.conf) 

ip link add dev wg0 type wireguard
ip address add dev wg0 10.0.0.2/24
wg setconf wg0 /etc/wireguard/wg0.conf
ip link set up dev wg0

#3 notice: wg0.conf example

#[Interface]
#PrivateKey = yG/bs7lAYy3yJLGqWDXVZrpT16CmDHanpI9g9haPC28=

#[Peer]
#PublicKey = dddHotJ9qujdydvjNDYJVrGWCjpvudX9qcNXk7W4wCo=
#Endpoint = 127.0.0.1:2090
#AllowedIPs = 0.0.0.0/0, ::0/0
#PersistentKeepalive = 5

#4 add route table for wireguard

echo "200 game" >> /etc/iproute2/rt_tables

#5 create ipset table

#ipset create game hash:net
#保存规则ipset save game -f game.txt
#从文件创建
ipset restore -f game.txt

#6 enable iptables rule，mark ip packages equal ipset table

iptables -t mangle -A PREROUTING -m set --match-set game dst -j MARK --set-mark 8 
iptables -t mangle -A OUTPUT -m set --match-set game dst -j MARK --set-mark 8 
iptables -t nat -A POSTROUTING -m mark --mark 8 -j MASQUERADE
iptables -I FORWARD -o wg0 -j ACCEPT

#7 config route table game:default route,lan 
ip route add default dev wg0 table game
ip route add 192.168.3.0/24 dev br-lan table game

#8 enable ip rule 

ip rule add fwmark 8 table game


