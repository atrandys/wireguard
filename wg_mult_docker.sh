#!/bin/bash

blue(){
    echo -e "\033[34m\033[01m$1\033[0m"
}
green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}
red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}

rand(){
    min=$1
    max=$(($2-$min+1))
    num=$(cat /dev/urandom | head -n 10 | cksum | awk -F ' ' '{print $1}')
    echo $(($num%$max+$min))  
}

check_selinux(){
    CHECK=$(grep SELINUX= /etc/selinux/config | grep -v "#")
    if [ "$CHECK" == "SELINUX=enforcing" ]; then
        red "==========================================================="
        red "SELinux is enforcing, please reboot your VPS and try again."
        red "==========================================================="
        read -p "Reboot now ? Please input [Y/n] :" yn
	    [ -z "${yn}" ] && yn="y"
	    if [[ $yn == [Yy] ]]; then
    	    sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
          setenforce 0
	        echo -e "VPS rebooting..."
	        reboot
	    fi
        exit
    fi
    if [ "$CHECK" == "SELINUX=permissive" ]; then
        red "==========================================================="
        red "SELinux is permissive, please reboot your VPS and try again."
        red "==========================================================="
        read -p "Reboot now ? Please input [Y/n] :" yn
	    [ -z "${yn}" ] && yn="y"
	    if [[ $yn == [Yy] ]]; then
	        sed -i 's/SELINUX=permissive/SELINUX=disabled/g' /etc/selinux/config
          setenforce 0
	        echo -e "VPS rebooting..."
	        reboot
	    fi
        exit
    fi
}

check_release(){
    source /etc/os-release
    RELEASE=$ID
    VERSION=$VERSION_ID
}

docker_install(){
    check_release
    if [ "$RELEASE" == "centos" ]; then
        green "=========================="
	green "Start installing docker..."
	green "=========================="
	sleep 2
        yum remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine
	yum install -y yum-utils device-mapper-persistent-data lvm2
	yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
	yum install -y docker-ce docker-ce-cli containerd.io
    elif [ "$RELEASE" == "ubuntu" ]; then
        green "=========================="
	green "Start installing docker..."
	green "=========================="
	sleep 2
        apt-get remove -y docker docker-engine docker.io containerd runc
	apt-get update
	apt-get install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
	add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
	apt-get update
	apt-get install -y docker-ce docker-ce-cli containerd.io
    elif [ "$RELEASE" == "debian" ]; then
        green "=========================="
	green "Start installing docker..."
	green "=========================="
	sleep 2
        apt-get remove -y docker docker-engine docker.io containerd runc
	apt-get update
	apt-get install -y apt-transport-https ca-certificates curl gnupg2 software-properties-common
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
	add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"
	apt-get update
	apt-get install -y docker-ce docker-ce-cli containerd.io
    else
        red "======================================="
    	red "Does not supported Current OS"$RELEASE
	red "======================================="
	exit 1
    fi
    systemctl enable docker
    systemctl start docker
}

wg_install(){
    docker pull atrandys/wireguard
    mkdir /etc/wireguard
    cd /etc/wireguard
    docker run -itd -P --restart=always --name wireguard -v /etc/wireguard:/etc/wireguard atrandys/wireguard /bin/sh
    docker exec -it wireguard /bin/sh "cd /etc/wireguard;wg genkey | tee sprivatekey | wg pubkey > spublickey;wg genkey | tee cprivatekey | wg pubkey > cpublickey"
    s1=$(cat sprivatekey)
    s2=$(cat spublickey)
    c1=$(cat cprivatekey)
    c2=$(cat cpublickey)
    serverip=$(curl ipv4.icanhazip.com)
    port=$(rand 10000 60000)
    eth=$(ls /sys/class/net| awk 'NR==1&&/^e/{print $1}')
    #chmod 777 -R /etc/wireguard

cat > /etc/wireguard/wg0.conf <<-EOF
[Interface]
PrivateKey = $s1
Address = 10.77.0.1/24 
PostUp   = iptables -t nat -A POSTROUTING -o $eth -j MASQUERADE
PostDown = iptables -t nat -D POSTROUTING -o $eth -j MASQUERADE
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
    docker exec -it wireguard /bin/sh -c "wg-quick up wg0"
    green "========================================================="
    green "wireguard安装完成，请复制以下红色内容复制，保存为client.conf"
    green "在wireguard客户端导入client.conf即可连接"
    red `cat /etc/wireguard/client.conf`
}

user_add(){
    green "=================================="
    green "给新用户起个名字，不能和已有用户重复"
    green "=================================="
    read -p "请输入用户名：" newname
    cd /etc/wireguard/
    if [ ! -f "/etc/wireguard/$newname.conf" ]; then
        cp client.conf $newname.conf
    	docker exec -it wireguard /bin/sh -c "wg genkey | tee temprikey | wg pubkey > tempubkey"
    	ipnum=$(grep Allowed /etc/wireguard/wg0.conf | tail -1 | awk -F '[ ./]' '{print $6}')
    	newnum=$((10#${ipnum}+1))
    	sed -i 's%^PrivateKey.*$%'"PrivateKey = $(cat temprikey)"'%' $newname.conf
    	sed -i 's%^Address.*$%'"Address = 10.77.0.$newnum\/24"'%' $newname.conf
	cat >> /etc/wireguard/wg0.conf <<-EOF
[Peer]
PublicKey = $(cat tempubkey)
AllowedIPs = 10.77.0.$newnum/32
EOF
    	docker exec -it wireguard /bin/sh -c "wg set wg0 peer $(cat tempubkey) allowed-ips 10.77.0.$newnum/32"
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

wg_remove(){
    if [ -d "/etc/wireguard" ]; then
        docker update --restart=no wireguard
	docker stop wireguard
	docker rm wireguard
	rm -rf /etc/wireguard/
	green "wireguard docker容器已删除"
	green "wireguard配置文件已删除"
    else
        red "你似乎没有安装wireguard"
    fi
}

start_menu(){
    clear
    green "=========================================="
    green " Info   : For Centos7+/Ubuntu16+/Debian9+"
    green " Author : atrandys"
    green " Website: www.atrandys.com"
    green " YouTube: Randy's 堡垒"
    green "=========================================="
    green "1. Install wireguard"
    red "2. Remove wireguard"
    green "3. Add user"
    red "0. Exit"
    echo
    read -p "Please enter a number:" num
    case "$num" in
    	1)
	docker_install
        wg_install
	;;
	2)
	wg_remove
	;;
	3)
	user_add
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
