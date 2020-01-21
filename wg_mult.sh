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

function install_wg(){

    source /etc/os-release
    RELEASE=$ID
    VERSION=$VERSION_ID
    if [ "$RELEASE" == "centos" ] && [ "$VERSION" == "7" ]; then
        yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
        curl -o /etc/yum.repos.d/jdoss-wireguard-epel-7.repo https://copr.fedorainfracloud.org/coprs/jdoss/wireguard/repo/epel-7/jdoss-wireguard-epel-7.repo
        yum install -y wireguard-dkms wireguard-tools
    elif [ "$RELEASE" == "centos" ] && [ "$VERSION" == "8" ]; then
        yum install -y epel-release
        yum config-manager --set-enabled PowerTools
        yum copr enable jdoss/wireguard
        yum install -y wireguard-dkms wireguard-tools
    elif [ "$RELEASE" == "ubuntu" ]; then
        add-apt-repository ppa:wireguard/wireguard
        apt-get update
        apt-get install -y wireguard
    elif [ "$RELEASE" == "debian" ]; then
        echo "deb http://deb.debian.org/debian/ unstable main" > /etc/apt/sources.list.d/unstable.list
        printf 'Package: *\nPin: release a=unstable\nPin-Priority: 90\n' > /etc/apt/preferences.d/limit-unstable
        apt update
        apt install -y wireguard
    else
        red "您当前系统暂未支持"
    fi
}

function config_wg(){


}
