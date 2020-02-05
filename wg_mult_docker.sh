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
}

docker_install
wg_install
