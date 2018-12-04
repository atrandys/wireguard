#!/bin/sh



SUBNET=192.168.100

###############

umask 077

rand(){
	min=$1
	max=$(($2-$min+1))
	num=$(cat /dev/urandom | head -n 10 | cksum | awk -F ' ' '{print $1}')
	echo $(($num%$max+$min))  
}


get_public_ip()
{
	dig +short myip.opendns.com @resolver1.opendns.com
}


install_wireguard()
{
	if grep Debian /etc/issue ; then
		apt install -y dkms linux-headers-`uname -r`
		apt install -y dnsutils resolvconf
		wg && return;

		echo "Install Wireguard"
		echo "deb http://deb.debian.org/debian/ unstable main"  > /etc/apt/sources.list.d/unstable.list
		printf 'Package: *\nPin: release a=unstable\nPin-Priority: 150\n' >  /etc/apt/preferences.d/limit-unstable
		apt update
		apt install -y  wireguard resolvconf dnsutils
		apt install -y gettext build-essential unzip gzip openssl libssl-dev \
						autoconf automake libtool gcc g++ make zlib1g-dev \
						libev-dev libc-ares-dev git
	fi

	if [ -f /etc/centos-release ] ; then
		curl -Lo /etc/yum.repos.d/wireguard.repo https://copr.fedorainfracloud.org/coprs/jdoss/wireguard/repo/epel-7/jdoss-wireguard-epel-7.repo
		yum install -y epel-release
		yum install -y wireguard-dkms wireguard-tools
		yum install -y bind-utils
		yum install -y  unzip gzip openssl openssl-devel gcc libtool libevent \
						autoconf automake make curl curl-devel zlib-devel  cpio gettext-devel \
						libev-devel c-ares-devel git
	fi
}

build_udp2raw()
{
	rm -rf udp2raw-tunnel
	git clone https://github.com/wangyu-/udp2raw-tunnel.git
	cd udp2raw-tunnel
	make
	cp udp2raw  /usr/local/bin
	cd -
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
	build_udp2raw

	wg-quick down wg0 2>/dev/null
	rm -rf /etc/wireguard/*
	echo "正在获取服务器公网IP地址"
	SERVER_PUBLIC_IP=$(get_public_ip)
	wg genkey | tee server_priv | wg pubkey > server_pub
	wg genkey | tee client_priv | wg pubkey > client_pub

	echo $SUBNET > /etc/wireguard/subnet
	
	SERVER_PUB=$(cat server_pub)
	SERVER_PRIV=$(cat server_priv)
	CLIENT_PUB=$(cat client_pub)
	CLIENT_PRIV=$(cat client_priv)

	echo $SERVER_PUB > /etc/wireguard/server_pubkey
	
	PORT=$(rand 20000 60000)
	UDP2RAW_PORT=$(rand 10000 20000)
	UDP2RAW_PASSWORD=$(cat /dev/urandom | head -n 10 | md5sum | head -c 12)

	echo $UDP2RAW_PORT > /etc/wireguard/udp2raw_port
	echo $UDP2RAW_PASSWORD > /etc/wireguard/udp2raw_password

	mv /etc/wireguard/wg0.conf /etc/wireguard/wg0.conf.bak  2> /dev/null

	ip=$SUBNET.2
	cat > /etc/wireguard/wg0.conf <<-EOF
	[Interface]
	PrivateKey = $SERVER_PRIV
	Address = $SUBNET.1/24
	PreUp = udp2raw -s -l0.0.0.0:$UDP2RAW_PORT -r127.0.0.1:$PORT -k $UDP2RAW_PASSWORD --raw-mode faketcp --cipher-mode xor -a > /var/log/udp2raw.log &
	PostUp   = sysctl net.ipv4.ip_forward=1
	PostUp   = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
	PostDown = sysctl net.ipv4.ip_forward=0 ;
	PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
	PostDown = killall udp2raw
	ListenPort = $PORT
	#DNS = 8.8.8.8
	MTU = 1200

	[Peer]
	PublicKey = $CLIENT_PUB
	AllowedIPs = $SUBNET.2/32
	EOF

	cat > client.conf <<-EOF
	[Interface]
	PrivateKey = $CLIENT_PRIV
	Address = $ip/32
	MTU = 1200
	DNS = 8.8.8.8


	[Peer]
	AllowedIPs = 0.0.0.0/0
	Endpoint = $SERVER_PUBLIC_IP:$PORT
	PublicKey = $SERVER_PUB

	EOF

	rm -rf server_* client_*

	systemctl enable wg-quick@wg0
	wg-quick up wg0

	mkdir -p /etc/wireguard/clients/default/
	cp client.conf /etc/wireguard/clients/default/
	echo $ip > /etc/wireguard/lastip
	show_client_conf

	rm client.conf
}

add_peer_udp2raw()
{
	read -p  "请输入要增加的用户名(英文+数字): "  peer_name

	if [ -d /etc/wireguard/clients/$peer_name ]; then
		echo "用户已经存在"
		return;
	fi

	read -p "请输入局域网网段(例如192.168.0.0): "  lan_ip


	SERVER_PUBLIC_IP=$(get_public_ip)
	subnet=$(cat /etc/wireguard/subnet)

	ip=$subnet.$(expr $(cat /etc/wireguard/lastip | tr "." " " | awk '{print $4}') + 1)


	wg genkey | tee client_priv | wg pubkey > client_pub

	cat > client.conf <<-EOF
	[Interface]
	PrivateKey = $(cat client_priv)
	Address = $ip/32
	MTU = 1200
	DNS = 8.8.8.8

	PreUp = udp2raw -c -l0.0.0.0:$(cat /etc/wireguard/udp2raw_port) -r$SERVER_PUBLIC_IP:$(cat /etc/wireguard/udp2raw_port) -k $(cat /etc/wireguard/udp2raw_password) --raw-mode faketcp --cipher-mode xor -a > /var/log/udp2raw.log &
	PreUp = ipset create gfwlist hash:ip family inet timeout 3600 || echo "gfwlist create" > /dev/null
	PostUp = iptables -A POSTROUTING -t mangle -p tcp --tcp-flags SYN,RST SYN -o wg0 -j TCPMSS  --clamp-mss-to-pmtu
	PostUp = iptables -t mangle -A OUTPUT -m set --match-set gfwlist dst -j  MARK  --set-mark 2222
	PostUp = iptables -t mangle -A PREROUTING -m set --match-set gfwlist dst -j  MARK  --set-mark 2222
	PostUp = ip rule add fwmark 51820 lookup main
	PostUp = ip rule add fwmark 2222 lookup 51820
	PostUp = ip rule add to 8.8.8.8 lookup 51820
	PostUp = ip rule add to $SERVER_PUBLIC_IP table main
	PostUp = ip rule add to $SUBNET.0/24 lookup 51820
	PostUp = ip rule del not fwmark 51820 lookup 51820
	PostUp = sysctl net.ipv4.ip_forward=1
	PostUp = systemctl restart dnsmasq
	PostDown = killall udp2raw || echo "no udp2raw"
	PostDown = iptables -D POSTROUTING -t mangle -p tcp --tcp-flags SYN,RST SYN -o wg0 -j TCPMSS  --clamp-mss-to-pmtu
	PostDown = iptables -t mangle -D OUTPUT -m set --match-set gfwlist dst -j  MARK  --set-mark 2222
	PostDown = iptables -t mangle -D PREROUTING -m set --match-set gfwlist dst -j  MARK  --set-mark 2222
	PostDown = sysctl net.ipv4.ip_forward=0

	[Peer]
	AllowedIPs = 0.0.0.0/0
	Endpoint = 127.0.0.1:$(cat /etc/wireguard/udp2raw_port)
	PublicKey = $(wg | grep 'public key:' | awk '{print $3}')

	EOF

	wg set wg0 peer $(cat client_pub) allowed-ips $ip/32,$lan_ip/24

	echo "$peer_name $(cat client_priv) $ip" >> /etc/wireguard/peers
	echo $ip > /etc/wireguard/lastip

	wg-quick save wg0

	mkdir -p /etc/wireguard/clients/$peer_name/
	cp client.conf /etc/wireguard/clients/$peer_name/

	show_client_conf
	rm client.conf
	rm client_*
}


add_peer() 
{
	read -p  "请输入要增加的用户名(英文+数字): "  peer_name

	if [ -d /etc/wireguard/clients/$peer_name ]; then
		echo "用户已经存在"
		return;
	fi

	subnet=$(cat /etc/wireguard/subnet)

	ip=$subnet.$(expr $(cat /etc/wireguard/lastip | tr "." " " | awk '{print $4}') + 1)

	wg genkey | tee client_priv | wg pubkey > client_pub

	cat > client.conf <<-EOF
	[Interface]
	PrivateKey = $(cat client_priv)
	Address = $ip/32
	MTU = 1200
	DNS = 8.8.8.8

	[Peer]
	AllowedIPs = 0.0.0.0/0
	Endpoint = $(get_public_ip):$(cat /etc/wireguard/wg0.conf | grep ListenPort | awk '{ print $3}')
	PublicKey = $(wg | grep 'public key:' | awk '{print $3}')

	EOF

	wg set wg0 peer $(cat client_pub) allowed-ips $ip/32

	echo "$peer_name $(cat client_priv) $ip" >> /etc/wireguard/peers
	echo $ip > /etc/wireguard/lastip

	wg-quick save wg0

	mkdir -p /etc/wireguard/clients/$peer_name/
	cp client.conf /etc/wireguard/clients/$peer_name/

	show_client_conf
	rm client.conf
	rm client_*
}


delete_peer()
{
	read -p  "请输入要删除的用户名: "  peer_name

	[ -d /etc/wireguard/clients/$peer_name ] || ( echo "用户不存在" ; return ;) 

	cat /etc/wireguard/clients/$peer_name/client.conf  | grep "PrivateKey" | awk '{print $3}' > client_priv

	wg set wg0 peer  $(cat /etc/wireguard/clients/$peer_name/client.conf  | grep "PrivateKey" | awk '{print $3}' | wg pubkey) remove 
	wg-quick save wg0

	rm -rf /etc/wireguard/clients/$peer_name
	echo "用户删除成功"
}

list_peer()
{
	cd /etc/wireguard/clients >/dev/null 2>/dev/null && ls && cd - 2>/dev/null 1>/dev/null
}

start_menu(){
    echo "========================="
    echo " 作者：基于atrandys版本修改"
    echo "========================="
    echo "1. 重新安装配置Wireguard"
    echo "2. 增加用户"
    echo "3. 增加用户(udp2raw配置)"
    echo "4. 删除用户"
    
    echo "5. 用户列表"

    echo "6. 退出脚本"
    read -p "请输入数字:" num
    case "$num" in
    	1)
		configure_wireguard
	;;
	2)
		add_peer
	;;

	3)
		add_peer_udp2raw
	;;

	4)
		delete_peer
	;;
	5)
		list_peer
	;;
	6)
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
