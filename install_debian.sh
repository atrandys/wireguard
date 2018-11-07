#!/bin/sh



SUBNET=192.168.100

###############

umask 077

install_wireguard()
{
	wg && return;

	echo "Install Wireguard"
	echo "deb http://deb.debian.org/debian/ unstable main" &gt; /etc/apt/sources.list.d/unstable.list
	printf 'Package: *\nPin: release a=unstable\nPin-Priority: 150\n' &gt; /etc/apt/preferences.d/limit-unstable
	apt update
	apt install -y  wireguard resolvconf dig
}

show_client_conf()
{
	echo ""
	echo "\033[32m"
	echo "*********************************************************"
	echo "复制以下红色内容，在谷歌浏览器安装Offline QRcode Generator"
	echo "插件生成二维码, 在WireGuard客户端扫描导入生成的二维码"
	echo "*********************************************************"
	echo "\033[0m"
	echo "====================================================="
	echo "====================================================="
	echo "\033[31m"
	cat  client.conf
	echo  "\033[0m"
	echo "====================================================="
	echo "====================================================="
}


configure_wireguard()
{	
	install_wireguard
	wg-quick down wg0 2>/dev/null
	
	echo "正在获取服务器公网IP地址"
	SERVER_PUBLIC_IP=$(get_public_ip)
	wg genkey | tee server_priv | wg pubkey > server_pub
	wg genkey | tee client_priv | wg pubkey > client_pub

	echo SUBNET > /etc/wireguard/subnet
	echo SERVER_PUB > /etc/wireguard/server_pubkey
	

	SERVER_PUB=$(cat server_pub)
	SERVER_PRIV=$(cat server_priv)
	CLIENT_PUB=$(cat client_pub)
	CLIENT_PRIV=$(cat client_priv)

	PORT=$(rand 10000 60000)

	mv /etc/wireguard/wg0.conf /etc/wireguard/wg0.conf.bak  2> /dev/null

	cat > /etc/wireguard/wg0.conf <<-EOF
	[Interface]
	PrivateKey = $SERVER_PRIV
	Address = $SUBNET.1/24
	PostUp   = sysctl net.ipv4.ip_forward=1 ; iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
	PostDown = sysctl net.ipv4.ip_forward=0 ;iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
	ListenPort = $PORT
	#DNS = 8.8.8.8
	MTU = 1420

	[Peer]
	PublicKey = $CLIENT_PUB
	AllowedIPs = $SUBNET.2/32
	EOF

	cat > client.conf <<-EOF
	[Interface]
	PrivateKey = $CLIENT_PRIV
	Address = $SUBNET.2/32
	DNS = 8.8.8.8


	[Peer]
	AllowedIPs = 0.0.0.0/0
	Endpoint = $SERVER_PUBLIC_IP:$PORT
	PublicKey = $SERVER_PUB

	EOF

	rm -rf server_* client_*

	systemctl enable wg-quick@wg0
	wg-quick up wg0

	show_client_conf
}


start_menu(){
    echo "========================="
    echo " 介绍：适用于Debian"
    echo " 作者：基于atrandys版本修改"
    echo " 网站：www.atrandys.com"
    echo " Youtube：atrandys"
    echo "========================="
    echo "1. 重新安装配置Wireguard"
    echo "2. 退出脚本"
    echo
    read -p "请输入数字:" num
    case "$num" in
    	1)
		configure_wireguard
	;;
	2)
		#wireguard_install
		exit 1
	;;
	*)
	clear
	echo "请输入正确数字"
	sleep 2s
	start_menu
	;;
    esac
}

start_menu

