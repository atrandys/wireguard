#!/bin/bash

#颜色
Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m"
#判断系统
if [ ! -e '/etc/redhat-release' ]; then
echo "仅支持centos7"
exit
fi
if  [ -n "$(grep ' 6\.' /etc/redhat-release)" ] ;then
echo "仅支持centos7"
exit
fi

#更新epel
sudo yum -y install epel-release
sed -i "0,/enabled=0/s//enabled=1/" /etc/yum.repos.d/epel.repo

#更新内核
update_kernel(){
    rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
    rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-2.el7.elrepo.noarch.rpm
    yum --disablerepo="*" --enablerepo="elrepo-kernel" list available
    yum --enablerepo=elrepo-kernel install kernel-ml
    sed -i "s/GRUB_DEFAULT=saved/GRUB_DEFAULT=0/" /etc/default/grub
    grub2-mkconfig -o /boot/grub2/grub.cfg
    yum remove -y kernel-devel
    #wget http://elrepo.org/linux/kernel/el7/x86_64/RPMS/kernel-ml-devel-4.18.12-1.el7.elrepo.x86_64.rpm
    #rpm -ivh kernel-ml-devel-4.18.12-1.el7.elrepo.x86_64.rpm
    #yum --enablerepo=elrepo-kernel install kernel-ml-devel
    read -p "需要重启VPS，再次执行脚本选择安装wireguard，是否现在重启 ? [Y/n] :" yn
	[ -z "${yn}" ] && yn="y"
	if [[ $yn == [Yy] ]]; then
		echo -e "${Info} VPS 重启中..."
		reboot
	fi
}

#生成随机端口
rand(){
    min=$1
    max=$(($2-$min+1))
    num=$(cat /dev/urandom | head -n 10 | cksum | awk -F ' ' '{print $1}')
    echo $(($num%$max+$min))  
}

#centos7安装wireguard
wireguard_install(){
    sudo curl -Lo /etc/yum.repos.d/wireguard.repo https://copr.fedorainfracloud.org/coprs/jdoss/wireguard/repo/epel-7/jdoss-wireguard-epel-7.repo
    sudo yum install -y dkms gcc-c++ gcc-gfortran glibc-headers glibc-devel libquadmath-devel libtool systemtap systemtap-devel
    sudo yum -y install wireguard-dkms wireguard-tools
    mkdir /etc/wireguard
    cd /etc/wireguard
    wg genkey | tee sprivatekey | wg pubkey > spublickey
    wg genkey | tee cprivatekey | wg pubkey > cpublickey
    s1=$(cat sprivatekey)
    s2=$(cat spublickey)
    c1=$(cat cprivatekey)
    c2=$(cat cpublickey)
    serverip=$(curl icanhazip.com)
    port=$(rand 10000 60000)
    chmod 777 -R /etc/wireguard
    echo 1 > /proc/sys/net/ipv4/ip_forward
    echo "net.ipv4.ip_forward = 1" > /etc/sysctl.conf	
    cat > /etc/wireguard/wg0.conf <<-EOF
    [Interface]
    PrivateKey = $s1
    Address = 10.0.0.1/24 
    PostUp   = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
    PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
    ListenPort = $port

    [Peer]
    PublicKey = $c2
    AllowedIPs = 10.0.0.2/32
EOF    
    cat > /etc/wireguard/client.conf <<-EOF
    [Interface]
    PrivateKey = $c1
    Address = 10.0.0.2/24 
    DNS = 10.0.0.1

    [Peer]
    PublicKey = $s2
    Endpoint = $serverip:$port
    AllowedIPs = 0.0.0.0/0, ::0/0
    PersistentKeepalive = 25
EOF
    
    wg-quick up wg0
    systemctl enable wg-quick@wg0
}

#开始菜单
start_menu(){
    clear
    ${Green_font_prefix}1.${Font_color_suffix} 升级系统内核
    ${Green_font_prefix}2.${Font_color_suffix} 安装wireguard
    ————————————————————————————————" && echo
    echo
    read -p " 请输入数字:" num
    case "$num" in
    	1)
	update_kernel
	;;
	2)
	wireguard_install
	;;
	3)
	exit 1
	;;
	*)
	clear
	echo -e "请输入正确数字"
	sleep 5s
	start_menu
	;;
    esac
}

start_menu



