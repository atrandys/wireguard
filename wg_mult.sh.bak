#!/bin/bash
#wireguard onekey script for centos7+/ubuntu/debian
function blue(){
    echo -e "\033[34m\033[01m$1\033[0m"
}
function green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}
function red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}

function rand(){
    min=$1
    max=$(($2-$min+1))
    num=$(cat /dev/urandom | head -n 10 | cksum | awk -F ' ' '{print $1}')
    echo $(($num%$max+$min))  
}

function check_selinux(){

    CHECK=$(grep SELINUX= /etc/selinux/config | grep -v "#")
    if [ "$CHECK" == "SELINUX=enforcing" ]; then
        red "======================================================================="
        red "检测到SELinux为开启状态，为防止wireguard连接失败，请先重启VPS后，再执行本脚本"
        red "======================================================================="
        read -p "是否现在重启 ?请输入 [Y/n] :" yn
	    [ -z "${yn}" ] && yn="y"
	    if [[ $yn == [Yy] ]]; then
    	    sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
            setenforce 0
	        echo -e "VPS 重启中..."
	        reboot
	    fi
        exit
    fi
    if [ "$CHECK" == "SELINUX=permissive" ]; then
        red "======================================================================="
        red "检测到SELinux为宽容状态，为防止wireguard连接失败，请先重启VPS后，再执行本脚本"
        red "======================================================================="
        read -p "是否现在重启 ?请输入 [Y/n] :" yn
	    [ -z "${yn}" ] && yn="y"
	    if [[ $yn == [Yy] ]]; then
	        sed -i 's/SELINUX=permissive/SELINUX=disabled/g' /etc/selinux/config
            setenforce 0
	        echo -e "VPS 重启中..."
	        reboot
	    fi
        exit
    fi
}

function check_release(){

    source /etc/os-release
    RELEASE=$ID
    VERSION=$VERSION_ID

}


function install_wg(){
    check_release
    if [ "$RELEASE" == "centos" ] && [ "$VERSION" == "7" ]; then
        yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
	yum install -y "kernel-devel-uname-r == $(uname -r)"
        curl -o /etc/yum.repos.d/jdoss-wireguard-epel-7.repo https://copr.fedorainfracloud.org/coprs/jdoss/wireguard/repo/epel-7/jdoss-wireguard-epel-7.repo
        yum install -y wireguard-dkms wireguard-tools qrencode iptables-services
	systemctl stop firewalld
        systemctl disable firewalld
        systemctl enable iptables 
        systemctl start iptables 
	iptables -P INPUT ACCEPT
   	iptables -P OUTPUT ACCEPT
        iptables -P FORWARD ACCEPT
 	iptables -F
        service iptables save
  	service iptables restart
        echo 1 > /proc/sys/net/ipv4/ip_forward
        echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
        sysctl -p
    elif [ "$RELEASE" == "centos" ] && [ "$VERSION" == "8" ]; then
        yum install -y epel-release
	yum install -y "kernel-devel-uname-r == $(uname -r)"
        yum config-manager --set-enabled PowerTools
        yum copr enable -y jdoss/wireguard
        yum install -y wireguard-dkms wireguard-tools qrencode iptables-services
	systemctl stop firewalld
        systemctl disable firewalld
	systemctl enable iptables 
        systemctl start iptables
	iptables -P INPUT ACCEPT
   	iptables -P OUTPUT ACCEPT
        iptables -P FORWARD ACCEPT
 	iptables -F
        service iptables save
  	service iptables restart
        echo 1 > /proc/sys/net/ipv4/ip_forward
        echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
        sysctl -p
    elif [ "$RELEASE" == "ubuntu" ]  && [ "$VERSION" == "19.04" ]; then
    	red "==================="
        red "暂未支持ubuntu19.04系统"
        red "==================="
    elif [ "$RELEASE" == "ubuntu" ]  && [ "$VERSION" == "19.10" ]; then 
    	red "==================="
        red "暂未支持ubuntu19.10系统"
        red "==================="
    elif [ "$RELEASE" == "ubuntu" ]  && [ "$VERSION" == "16.04" ]; then
        systemctl stop ufw
        systemctl disable ufw
        apt-get -y update 
	add-apt-repository -y ppa:wireguard/wireguard
        apt-get update
        apt-get install -y wireguard qrencode iptables
	systemctl enable iptables 
        systemctl start iptables   
	echo 1 > /proc/sys/net/ipv4/ip_forward
        echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
        sysctl -p
    elif [ "$RELEASE" == "ubuntu" ] && [ "$VERSION" == "18.04" ]; then
        systemctl stop ufw
        systemctl disable ufw
        apt-get -y update 
	apt-get install -y software-properties-common
        apt-get install -y openresolv
	add-apt-repository -y ppa:wireguard/wireguard
        apt-get -y update
        apt-get install -y wireguard qrencode iptables
	systemctl enable iptables 
        systemctl start iptables   
	echo 1 > /proc/sys/net/ipv4/ip_forward
        echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
        sysctl -p
    elif [ "$RELEASE" == "debian" ]; then
        echo "deb http://deb.debian.org/debian/ unstable main" > /etc/apt/sources.list.d/unstable.list
        printf 'Package: *\nPin: release a=unstable\nPin-Priority: 90\n' > /etc/apt/preferences.d/limit-unstable
        apt update
        apt install -y wireguard qrencode iptables
	systemctl enable iptables 
        systemctl start iptables
	echo 1 > /proc/sys/net/ipv4/ip_forward
        echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
        sysctl -p
    else
    	red "================="
        red "您当前系统暂未支持"
	red "================="
    fi
}

function config_wg(){

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
    eth=$(ls /sys/class/net| awk 'NR==1&&/^e/{print $1}')
    chmod 777 -R /etc/wireguard

cat > /etc/wireguard/wg0.conf <<-EOF
[Interface]
PrivateKey = $s1
Address = 10.77.0.1/24 
PostUp   = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o $eth -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o $eth -j MASQUERADE
ListenPort = $port
DNS = 8.8.8.8
MTU = 1420
[Peer]
PublicKey = $c2
AllowedIPs = 10.77.0.2/32
EOF

cat > /etc/wireguard/client.conf <<-EOF
[Interface]
PrivateKey = $c1
Address = 10.77.0.2/24 
DNS = 8.8.8.8
MTU = 1420
[Peer]
PublicKey = $s2
Endpoint = $serverip:$port
AllowedIPs = 0.0.0.0/0, ::0/0
PersistentKeepalive = 25
EOF
    wg-quick up wg0
    systemctl enable wg-quick@wg0
    content=$(cat /etc/wireguard/client.conf)
    green "电脑端请下载/etc/wireguard/client.conf文件，手机端可直接使用软件扫码"
    green "${content}" | qrencode -o - -t UTF8

}

function add_user(){

    green "=================================="
    green "给新用户起个名字，不能和已有用户重复"
    green "=================================="
    read -p "请输入用户名：" newname
    cd /etc/wireguard/
    if [ ! -f "/etc/wireguard/$newname.conf" ]; then
        cp client.conf $newname.conf
    	wg genkey | tee temprikey | wg pubkey > tempubkey
    	ipnum=$(grep Allowed /etc/wireguard/wg0.conf | tail -1 | awk -F '[ ./]' '{print $6}')
    	newnum=$((10#${ipnum}+1))
    	sed -i 's%^PrivateKey.*$%'"PrivateKey = $(cat temprikey)"'%' $newname.conf
    	sed -i 's%^Address.*$%'"Address = 10.77.0.$newnum\/24"'%' $newname.conf
	cat >> /etc/wireguard/wg0.conf <<-EOF
[Peer]
PublicKey = $(cat tempubkey)
AllowedIPs = 10.77.0.$newnum/32
EOF
    	wg set wg0 peer $(cat tempubkey) allowed-ips 10.77.0.$newnum/32
    	green "============================================="
    	green "添加完成，文件：/etc/wireguard/$newname.conf"
    	green "============================================="
    	rm -f temprikey tempubkey
    else
    	red "======================"
	red "用户名已存在，请更换名称"
	red "======================"
    fi

}

function remove_wg(){
    check_release
    if [ -d "/etc/wireguard" ]; then
    	wg-quick down wg0
    	if [ "$RELEASE" == "centos" ]; then
            yum remove -y wireguard-dkms wireguard-tools
            rm -rf /etc/wireguard/
            green "卸载完成"
        elif [ "$RELEASE" == "ubuntu" ]; then
    	    apt-get remove -y wireguard
	    rm -rf /etc/wireguard/
            green "卸载完成"
        elif [ "$RELEASE" == "debian" ]; then
    	    apt remove -y wireguard
	    rm -rf /etc/wireguard/
            green "卸载完成"
        else
    	    red "系统不符合要求"
        fi
    else
    	red "未检测到wireguard"
    fi
}

function start_menu(){
    clear
    green "=========================================="
    green " Info   : For Centos7+/Ubuntu16+/Debian9+"
    green " Author : A"
    green "=========================================="
    green "1. Install wireguard"
    red "2. Remove wireguard"
    green "3. Show client QRcode"
    green "4. Add user"
    red "0. Exit"
    echo
    read -p "Please enter a number:" num
    case "$num" in
    	1)
	check_selinux
	install_wg
	config_wg
	;;
	2)
	remove_wg
	;;
	3)
	content=$(cat /etc/wireguard/client.conf)
    	echo "${content}" | qrencode -o - -t UTF8
	;;
	4)
	add_user
	;;
	0)
	exit 1
	;;
	*)
	clear
	red "Please enter the correct number!"
	sleep 1s
	start_menu
	;;
    esac
}

start_menu
