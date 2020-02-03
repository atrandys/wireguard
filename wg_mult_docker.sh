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
        yum remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine
	yum install -y yum-utils device-mapper-persistent-data lvm2
	yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
	yum install -y docker-ce docker-ce-cli containerd.io
    elif [ "$RELEASE" == "ubuntu" ]; then
        apt-get remove -y docker docker-engine docker.io containerd runc
	apt-get update
	apt-get install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
	add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
	apt-get update
	apt-get install -y docker-ce docker-ce-cli containerd.io
    elif [ "$RELEASE" == "debian" ]; then
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
}
