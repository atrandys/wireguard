#!/bin/bash 
# 配置透明代理路由器

# 需要与Wireguard一键脚本所生成的UDP2RAW客户端配置文件相配合
# 适合Debian/Ubuntu 桌面/服务器系统，用于做软路由透明代理
# 需要使用root权限运行
GFWLIST_IPSET=gfwlist
GFWLIST_TIMEOUT=3600

install_udp2raw()
{
	[ -e /usr/local/bin/udp2raw ] && return ; 

        rm -rf udp2raw-tunnel
        git clone https://github.com/wangyu-/udp2raw-tunnel.git
        cd udp2raw-tunnel
        make
        cp udp2raw  /usr/local/bin
        cd -
}

install_packages()
{
        if grep -q Debian /etc/issue || grep -q Ubuntu /etc/issue ;  then
		apt purge -y dnsmasq
		rm -rf /etc/dnsmasq.conf
		rm -rf /etc/dnsmasq.d
                apt install -y dnsmasq dnsutils resolvconf wget curl ipset sed
                apt install -y gettext build-essential unzip gzip openssl libssl-dev \
                                                autoconf automake libtool gcc g++ make zlib1g-dev \
                                                libev-dev libc-ares-dev git
 
		if ! wg > /dev/null ; then 
                	echo "Install Wireguard"
                	echo "deb http://deb.debian.org/debian/ unstable main"  > /etc/apt/sources.list.d/unstable.list
                	printf 'Package: *\nPin: release a=unstable\nPin-Priority: 150\n' >  /etc/apt/preferences.d/limit-unstable
                	apt update
               		apt install -y dkms linux-headers-`uname -r`
                	apt install -y  wireguard
		fi
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

	if ! [ -e /usr/local/bin/gfwlist2dnsmasq.sh ];  then
                wget https://raw.githubusercontent.com/cokebar/gfwlist2dnsmasq/master/gfwlist2dnsmasq.sh
                chmod +x gfwlist2dnsmasq.sh
		mv gfwlist2dnsmasq.sh /usr/local/bin/
        fi
	
	install_udp2raw
}


config_dnsmasq()
{
	if (cat /etc/issue | grep -q 'Ubuntu' | grep -q  '18.' ) ; then
        	if  !(grep -q "DNSStubListener=no" /etc/systemd/resolved.conf) ; then
			echo "disable systemd-resolved server"
        		sudo echo "DNSStubListener=no" >> /etc/systemd/resolved.conf
        		service systemd-resolved restart
		fi 
	fi
	
	grep -q  "server=223.5.5.5"  /etc/dnsmasq.conf ||  echo "server=223.5.5.5" >> /etc/dnsmasq.conf
	
	ipset destroy $GFWLIST_IPSET
        ipset create $GFWLIST_IPSET  hash:ip family inet timeout $GFWLIST_TIMEOUT
	/usr/local/bin/gfwlist2dnsmasq.sh -d 8.8.8.8 -p 53 -s $GFWLIST_IPSET -o /etc/dnsmasq.d/gfwlist.conf
	
	echo "0 0 * * 0  cd /tmp && /usr/local/bin/gfwlist2dnsmasq.sh -d 8.8.8.8 -p 53 -s $GFWLIST_IPSET -o /etc/dnsmasq.d/gfwlist.conf && /etc/init.d/dnsmasq restart> /dev/null"  > /tmp/crontab.root	

	crontab /tmp/crontab.root
	service dnsmasq restart
	
}


main()
{
	install_packages
	config_dnsmasq
}

main
