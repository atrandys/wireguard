#!/bin/bash

function blue(){
    echo -e "\033[34m\033[01m $1 \033[0m"
}
function green(){
    echo -e "\033[32m\033[01m $1 \033[0m"
}
function red(){
    echo -e "\033[31m\033[01m $1 \033[0m"
}
function yellow(){
    echo -e "\033[33m\033[01m $1 \033[0m"
}

rand(){
    min=$1
    max=$(($2-$min+1))
    num=$(cat /dev/urandom | head -n 10 | cksum | awk -F ' ' '{print $1}')
    echo $(($num%$max+$min))  
}

randpwd(){
    mpasswd=$(cat /dev/urandom | head -1 | md5sum | head -c 4)
    echo ${mpasswd}  
}

wireguard_install(){
    version=$(cat /etc/os-release | awk -F '[".]' '$1=="VERSION="{print $2}')
    if [ $version == 18 ]
    then
        sudo apt-get update -y
        sudo apt-get install -y software-properties-common
        sudo apt-get install -y openresolv
    else
        sudo apt-get update -y
        sudo apt-get install -y software-properties-common
    fi
    sudo add-apt-repository -y ppa:wireguard/wireguard
    sudo apt-get update -y
    sudo apt-get install -y wireguard curl

    sudo echo net.ipv4.ip_forward = 1 >> /etc/sysctl.conf
    sysctl -p
    echo "1"> /proc/sys/net/ipv4/ip_forward
    
    mkdir /etc/wireguard
    cd /etc/wireguard
    wg genkey | tee sprivatekey | wg pubkey > spublickey
    wg genkey | tee cprivatekey | wg pubkey > cpublickey
    s1=$(cat sprivatekey)
    s2=$(cat spublickey)
    c1=$(cat cprivatekey)
    c2=$(cat cpublickey)
    serverip=$(curl ipv4.icanhazip.com)
    port=$(rand 10000 60000)
    eth=$(ls /sys/class/net | awk '/^e/{print $1}')

sudo cat > /etc/wireguard/wg0.conf <<-EOF
[Interface]
PrivateKey = $s1
Address = 10.0.0.1/24 
PostUp   = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o $eth -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o $eth -j MASQUERADE
ListenPort = $port
DNS = 8.8.8.8
MTU = 1420

[Peer]
PublicKey = $c2
AllowedIPs = 10.0.0.2/32
EOF

sudo cat > /etc/init.d/wgstart <<-EOF
#! /bin/bash
### BEGIN INIT INFO
# Provides:		wgstart
# Required-Start:	$remote_fs $syslog
# Required-Stop:    $remote_fs $syslog
# Default-Start:	2 3 4 5
# Default-Stop:		0 1 6
# Short-Description:	wgstart
### END INIT INFO

sudo wg-quick up wg0
EOF



    sudo chmod 755 /etc/init.d/wgstart
    cd /etc/init.d
    if [ $version == 14 ]
    then
        sudo update-rc.d wgstart defaults 90
    else
        sudo update-rc.d wgstart defaults
    fi
    
    udp_install
    sudo wg-quick up wg0
    
    green "下面是wireguard配置文件"
    green "================================================="
    cat /etc/wireguard/client/client.conf
    green "================================================="
}

udp_install(){
    #下载udpspeeder和udp2raw （amd64版）
    mkdir /usr/src/udp
    mkdir /etc/wireguard/client
    cd /usr/src/udp
    wget https://github.com/atrandys/wireguard/raw/master/speederv2
    wget https://github.com/atrandys/wireguard/raw/master/udp2raw
    wget https://raw.githubusercontent.com/atrandys/wireguard/master/run.sh
    chmod +x speederv2 udp2raw run.sh
    green "udp模式选择："
    green "1. wireguard+udpspeeder"
    green "2. wireguard+udp2raw"
    green "3. wireguard+udpspeeder+udp2raw"
    read udptype
    
    #启动udpspeeder和udp2raw
    udpport=$(rand 10000 60000)
    speederport=$(rand 10000 60000)
    password=$(randpwd)
if [ "$udptype" == "1" ]; then    
nohup ./speederv2 -s -l0.0.0.0:$speederport -r127.0.0.1:$port -f2:4 --mode 0 --timeout 0 -k $password>speeder.log 2>&1 &
#增加自启动脚本
cat > /etc/init.d/autoudp<<-EOF
#! /bin/sh
### BEGIN INIT INFO
# Provides:		autoudp
# Required-Start:    $remote_fs $syslog
# Required-Stop:    $remote_fs $syslog
# Default-Start:	2 3 4 5
# Default-Stop:		0 1 6
# Short-Description:	autoudp
### END INIT INFO

cd /usr/src/udp
nohup ./speederv2 -s -l0.0.0.0:$speederport -r127.0.0.1:$port -f2:4 --mode 0 --timeout 0 -k $password >speeder.log 2>&1 &

EOF

    green "下面是udpspeeder配置参数"
    green "================================================="
    blue "服务器IP：$serverip"
    blue "服务器端口：$speederport"
    blue "-fec：2:4"
    blue "--mode：0"
    blue "--timeout：0"
    blue "-k $password"
    green "================================================="
    
fi

if [ "$udptype" == "2" ]; then    
nohup ./run.sh ./udp2raw -s -l0.0.0.0:$udpport -r 127.0.0.1:$port  --raw-mode faketcp  -a -k $password >udp2raw.log 2>&1 &
#增加自启动脚本
cat > /etc/init.d/autoudp<<-EOF
#! /bin/sh
### BEGIN INIT INFO
# Provides:		autoudp
# Required-Start:    $remote_fs $syslog
# Required-Stop:    $remote_fs $syslog
# Default-Start:	2 3 4 5
# Default-Stop:		0 1 6
# Short-Description:	autoudp
### END INIT INFO

cd /usr/src/udp
nohup ./run.sh ./udp2raw -s -l0.0.0.0:$udpport -r 127.0.0.1:$port  --raw-mode faketcp  -a -k $password >udp2raw.log 2>&1 &

EOF

    green "下面是udp2raw配置参数"
    green "================================================="
    blue "服务器IP：$serverip"
    blue "服务器端口：$udpport"
    blue "--raw-mode：faketcp"
    blue "-k $password"
    green "================================================="
    
fi

if [ "$udptype" == "3" ]; then    
nohup ./speederv2 -s -l127.0.0.1:$speederport -r127.0.0.1:$port -f2:4 --mode 0 --timeout 0 -k $password>speeder.log 2>&1 &
nohup ./run.sh ./udp2raw -s -l0.0.0.0:$udpport -r 127.0.0.1:$speederport  --raw-mode faketcp  -a -k $password >udp2raw.log 2>&1 &
#增加自启动脚本
cat > /etc/init.d/autoudp<<-EOF
#! /bin/sh
### BEGIN INIT INFO
# Provides:		autoudp
# Required-Start:    $remote_fs $syslog
# Required-Stop:    $remote_fs $syslog
# Default-Start:	2 3 4 5
# Default-Stop:		0 1 6
# Short-Description:	autoudp
### END INIT INFO

cd /usr/src/udp
nohup ./speederv2 -s -l127.0.0.1:$speederport -r127.0.0.1:$port -f2:4 --mode 0 --timeout 0 -k $password >speeder.log 2>&1 &
nohup ./run.sh ./udp2raw -s -l0.0.0.0:$udpport -r 127.0.0.1:$speederport  --raw-mode faketcp  -a -k $password >udp2raw.log 2>&1 &

EOF

    green "下面是udpspeeder+udp2raw配置参数"
    green "================================================="
    blue "服务器IP：$serverip"
    blue "udp2raw端口：$udpport"
    blue "udp2raw --raw-mode：faketcp"
    blue "udp2raw -k $password"
    blue "speeder -fec：2:4"
    blue "speeder --mode：0"
    blue "speeder --timeout：0"
    blue "speeder -k $password"
    green "================================================="
    
fi


cat > /etc/wireguard/client/client.conf <<-EOF
[Interface]
PrivateKey = $c1
Address = 10.0.0.2/24 
DNS = 8.8.8.8
MTU = 1420

[Peer]
PublicKey = $s2
Endpoint = 127.0.0.1:2090
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF







#设置脚本权限
    sudo chmod 755 /etc/init.d/autoudp
    cd /etc/init.d
    if [ $version == 14 ]
    then
        sudo update-rc.d autoudp defaults 90
    else
        sudo update-rc.d autoudp defaults
    fi
}

wireguard_remove(){

    sudo wg-quick down wg0
    sudo apt-get remove -y wireguard
    sudo rm -rf /etc/wireguard
    sudo rm -f /etc/init.d/wgstart
    sudo rm -f /etc/init.d/autoudp
    echo -e "\033[37;41m卸载完成，建议重启服务器\033[0m"

}

add_user(){
    echo -e "\033[37;41m给新用户起个名字，不能和已有用户重复\033[0m"
    read -p "请输入用户名：" newname
    cd /etc/wireguard/client
    cp client.conf $newname.conf
    wg genkey | tee temprikey | wg pubkey > tempubkey
    ipnum=$(grep Allowed /etc/wireguard/wg0.conf | tail -1 | awk -F '[ ./]' '{print $6}')
    newnum=$((10#${ipnum}+1))
    sed -i 's%^PrivateKey.*$%'"PrivateKey = $(cat temprikey)"'%' $newname.conf
    sed -i 's%^Address.*$%'"Address = 10.0.0.$newnum\/24"'%' $newname.conf

cat >> /etc/wireguard/wg0.conf <<-EOF

[Peer]
PublicKey = $(cat tempubkey)
AllowedIPs = 10.0.0.$newnum/32
EOF
    wg set wg0 peer $(cat tempubkey) allowed-ips 10.0.0.$newnum/32
    echo -e "\033[37;41m添加完成，文件：/etc/wireguard/client/$newname.conf\033[0m"
    rm -f temprikey tempubkey
}

#开始菜单
start_menu(){
    clear
    echo -e "\033[43;42m ====================================\033[0m"
    echo -e "\033[43;42m 介绍：wireguard+udpspeeder+udp2raw  \033[0m"
    echo -e "\033[43;42m 系统：Ubuntu,用于koolshare lede     \033[0m"
    echo -e "\033[43;42m 作者：atrandys                      \033[0m"
    echo -e "\033[43;42m 网站：www.atrandys.com              \033[0m"
    echo -e "\033[43;42m Youtube：atrandys                   \033[0m"
    echo -e "\033[43;42m ====================================\033[0m"
    echo
    echo -e "\033[0;33m 1. 安装wireguard+udpspeeder+udp2raw\033[0m"
    echo -e "\033[0;31m 2. 删除wireguard+udpspeeder+udp2raw\033[0m"
    echo -e "\033[37;41m 3. 增加用户\033[0m"
    echo -e " 0. 退出脚本"
    echo
    read -p "请输入数字:" num
    case "$num" in
    1)
    wireguard_install
    ;;
    2)
    wireguard_remove
    ;;
    3)
    add_user
    ;;
    0)
    exit 1
    ;;
    *)
    clear
    echo -e "请输入正确数字"
    sleep 2s
    start_menu
    ;;
    esac
}

start_menu






