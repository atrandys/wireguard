#!/bin/bash
#wireguard onekey script for ubuntu/debian
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

function version_lt(){
    test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" != "$1"; 
}

function check_selinux(){

    CHECK=$(grep SELINUX= /etc/selinux/config | grep -v "#")
    if [ "$CHECK" == "SELINUX=enforcing" ]; then
        red "============"
        red "Turn off SELinux"
        red "============"
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi
    if [ "$CHECK" == "SELINUX=permissive" ]; then
        red "============"
        red "Turn off SELinux"
        red "============"
        sed -i 's/SELINUX=permissive/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi
}

function check_release(){

    source /etc/os-release
    RELEASE=$ID
    VERSION=$VERSION_ID

}

function install_wg(){
    check_release
    if [ "$RELEASE" == "ubuntu" ]; then
        if [ "$VERSION" == "12.04" ] || [ "$VERSION" == "16.04" ]; then
	    red "=================="
            red "$RELEASE $VERSION System not supported at this timem not supported at this time"
            red "=================="
	    exit
	fi
        systemctl stop ufw
        systemctl disable ufw
	apt-get install -y wget
        apt-get install -y qrencode
	wget https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.8.15/amd64/linux-headers-5.8.15-050815-generic_5.8.15-050815.202010141131_amd64.deb
	wget https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.8.15/amd64/linux-headers-5.8.15-050815_5.8.15-050815.202010141131_all.deb
	wget https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.8.15/amd64/linux-image-unsigned-5.8.15-050815-generic_5.8.15-050815.202010141131_amd64.deb
	wget https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.8.15/amd64/linux-modules-5.8.15-050815-generic_5.8.15-050815.202010141131_amd64.deb
	dpkg -i *.deb
        apt -y update
        apt install -y linux-headers-$(uname -r)
	apt install -y linux-image-unsigned-$(uname -r)
	apt install -y linux-modules-$(uname -r)
	apt-get -y update
        #apt-get install -y software-properties-common
        apt-get install -y openresolv
        #add-apt-repository -y ppa:wireguard/wireguard
        apt-get install -y wireguard
        install_tools "apt-get"
    elif [ "$RELEASE" == "debian" ]; then
        echo "deb http://deb.debian.org/debian buster-backports main" >> /etc/apt/sources.list
        #printf 'Package: *\nPin: release a=unstable\nPin-Priority: 90\n' > /etc/apt/preferences.d/limit-unstable
        apt update
	apt install -y linux-image-$(uname -r)
	apt install -y wireguard openresolv
	#apt update
        #apt install -y wireguard
        install_tools "apt"
    else
        red "=================="
        red "$RELEASE $VERSION System not supported at this time"
        red "=================="
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
    port=1111
    eth=$(ls /sys/class/net| grep ^e | head -n1)
    chmod 777 -R /etc/wireguard

cat > /etc/wireguard/wg0.conf <<-EOF
[Interface]
PrivateKey = $s1
Address = 10.77.0.1/24 
PostUp   = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o $eth -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o $eth -j MASQUERADE
ListenPort = $port
DNS = 94.140.14.14, 94.140.15.15, 1.1.1.1, 1.0.0.1, 8.8.8.8, 8.8.4.4, 9.9.9.9, 149.112.112.112
MTU = 1420
[Peer]
PublicKey = $c2
AllowedIPs = 10.77.0.2/32
EOF

cat > /etc/wireguard/client.conf <<-EOF
[Interface]
PrivateKey = $c1
Address = 10.77.0.2/24 
DNS = 94.140.14.14, 94.140.15.15, 1.1.1.1, 1.0.0.1, 8.8.8.8, 8.8.4.4, 9.9.9.9, 149.112.112.112
MTU = 1420
[Peer]
PublicKey = $s2
Endpoint = $serverip:$port
AllowedIPs = 0.0.0.0/0, ::0/0
PersistentKeepalive = 25
EOF
    #wg-quick up wg0
    systemctl enable wg-quick@wg0
    content=$(cat /etc/wireguard/client.conf)
    green "Download the /etc/wireguard/client.conf file on your computer. You can scan the code directly on your mobile phone."
    green "${content}" | qrencode -o - -t UTF8
    red "Note: This installation must be restarted once before the wireguard can be used properly"
    echo "port: $port"
    read -p "Restart Now ? [Y/n] :" yn
    [ -z "${yn}" ] && yn="y"
    if [[ $yn == [Yy] ]]; then
        echo -e "VPS Restarting..."
        reboot
    fi
}

function add_user(){

    green "=================================="
    green "Name a new user and cannot overlap with an existing user"
    green "=================================="
    read -p "Please enter username：" newname
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
        green "Addition complete, file：/etc/wireguard/$newname.conf"
        green "============================================="
        rm -f temprikey tempubkey
    else
        red "======================"
        red "The username already exists, please change the name"
        red "======================"
    fi

}

function remove_wg(){
    check_release
    if [ -d "/etc/wireguard" ]; then
        wg-quick down wg0
        if [ "$RELEASE" == "ubuntu" ]; then
            apt-get remove -y wireguard
            rm -rf /etc/wireguard/
            green "Uninstall complete"
        elif [ "$RELEASE" == "debian" ]; then
            apt remove -y wireguard
            rm -rf /etc/wireguard/
            green "Uninstall complete"
        else
            red "The system does not meet the requirements."
        fi
    else
        red "Wireguard not detected"
    fi
}

function start_menu(){
    clear
    green "==============================================="
    green " Introduction: One-click installation of wireguard, adding multiple users of wireguard"
    green " System: Ubuntu18.04+/Debian9+"
    green " author: atrandys www.atrandys.com"
    green " presentation: Do not use the production environment because the kernel is upgraded during script installation."
    green "==============================================="
    green "1. Installation wireguard"
    red "2. Delete wireguard"
    green "3. Show Default User QR Code"
    green "4. Increase the number of users"
    red "0. Exit"
    echo
    read -p "Please select:" num
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
