#!/bin/bash

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
    fi
    if [ $version == 16 ]
    then
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
    eth=$(ls /sys/class/net | awk '/^e/{print}')

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


sudo cat > /etc/wireguard/client.conf <<-EOF
[Interface]
PrivateKey = $c1
Address = 10.0.0.2/24 
DNS = 8.8.8.8
MTU = 1420

[Peer]
PublicKey = $s2
Endpoint = $serverip:$port
AllowedIPs = 0.0.0.0/0, ::0/0
PersistentKeepalive = 25
EOF

sudo cat > /etc/init.d/wgstart <<-EOF
#!/bin/bash
#启动wg
sudo wg-quick up wg0
EOF

    sudo chmod 755 /etc/init.d/wgstart
    cd /etc/init.d
    sudo update-rc.d wgstart defaults 98
    udp_install
    sudo wg-quick up wg0
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
    
    #启动udpspeeder和udp2raw
    udpport=$(rand 10000 60000)
    password=$(randpwd)
    nohup ./speederv2 -s -l127.0.0.1:23333 -r127.0.0.1:$port -f2:1 --mode 0 --timeout 0 >speeder.log 2>&1 &
    nohup ./run.sh ./udp2raw -s -l0.0.0.0:$udpport -r 127.0.0.1:23333  --raw-mode faketcp  -a -k $password >udp2raw.log 2>&1 &
    echo -e "\033[37;41m输入你客户端电脑的默认网关，打开cmd，使用ipconfig命令查看\033[0m"
    read -p "比如192.168.1.1 ：" ugateway

cat > /etc/wireguard/client/client.conf <<-EOF
[Interface]
PrivateKey = $c1
PostUp = mshta vbscript:CreateObject("WScript.Shell").Run("cmd /c route add $serverip mask 255.255.255.255 $ugateway METRIC 20 & start /b c:/udp/speederv2.exe -c -l127.0.0.1:2090 -r127.0.0.1:2091 -f2:1 --mode 0 --timeout 0 & start /b c:/udp/udp2raw.exe -c -r$serverip:$udpport -l127.0.0.1:2091 --raw-mode faketcp -k $password",0)(window.close)
PostDown = route delete $serverip && taskkill /im udp2raw.exe /f && taskkill /im speederv2.exe /f
Address = 10.0.0.2/24 
DNS = 8.8.8.8
MTU = 1200

[Peer]
PublicKey = $s2
Endpoint = 127.0.0.1:2090
AllowedIPs = 0.0.0.0/0, ::0/0
PersistentKeepalive = 25
EOF

#增加自启动脚本
cat > /etc/init.d/autoudp<<-EOF
#!/bin/sh
#description:autoudp
cd /usr/src/udp
nohup ./speederv2 -s -l127.0.0.1:23333 -r127.0.0.1:$port -f2:1 --mode 0 --timeout 0 >speeder.log 2>&1 &
nohup ./run.sh ./udp2raw -s -l0.0.0.0:$udpport -r 127.0.0.1:23333  --raw-mode faketcp  -a -k $password >udp2raw.log 2>&1 &
EOF

#设置脚本权限
    sudo chmod 755 /etc/init.d/autoudp
    cd /etc/init.d
    sudo update-rc.d autoudp defaults 99
}

wireguard_remove(){

    sudo wg-quick down wg0
    sudo apt-get remove -y wireguard
    sudo rm -rf /etc/wireguard

}
#开始菜单
start_menu(){
    clear
    echo -e "\033[43;42m ====================================\033[0m"
    echo -e "\033[43;42m 介绍：wireguard+udpspeeder+udp2raw  \033[0m"
    echo -e "\033[43;42m 系统：CentOS7                       \033[0m"
    echo -e "\033[43;42m 作者：atrandys                      \033[0m"
    echo -e "\033[43;42m 网站：www.atrandys.com              \033[0m"
    echo -e "\033[43;42m Youtube：atrandys                   \033[0m"
    echo -e "\033[43;42m ====================================\033[0m"
    echo
    echo -e "\033[0;33m 1. 安装wireguard+udpspeeder+udp2raw\033[0m"
    echo -e "\033[0;31m 2. 删除wireguard+udpspeeder+udp2raw\033[0m"
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






