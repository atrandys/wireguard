#!/bin/bash
#
blue(){
    echo -e "\033[34m\033[01m$1\033[0m"
}
green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}
red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}

function install_wg(){

    source /etc/os-release
    RELEASE=$ID
    VERSION=$VERSION_ID
    if [ "$Release" == "centos" ] && [ "$VERSION_ID" == "7" ]; then
        yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
        curl -o /etc/yum.repos.d/jdoss-wireguard-epel-7.repo https://copr.fedorainfracloud.org/coprs/jdoss/wireguard/repo/epel-7/jdoss-wireguard-epel-7.repo
        yum install -y wireguard-dkms wireguard-tools
    elif [ "$Release" == "centos" ] && [ "$VERSION_ID" == "8" ]; then
        yum install -y epel-release
        yum config-manager --set-enabled PowerTools
        yum copr enable jdoss/wireguard
        yum install -y wireguard-dkms wireguard-tools
    elif [ "$Release" == "ubuntu" ]; then
        add-apt-repository ppa:wireguard/wireguard
        apt-get update
        apt-get install -y wireguard
    elif [ "$Release" == "debian" ]; then
        echo "deb http://deb.debian.org/debian/ unstable main" > /etc/apt/sources.list.d/unstable.list
        printf 'Package: *\nPin: release a=unstable\nPin-Priority: 90\n' > /etc/apt/preferences.d/limit-unstable
        apt update
        apt install -y wireguard
    else
        red "您当前系统暂未支持"
    fi
    }
    
