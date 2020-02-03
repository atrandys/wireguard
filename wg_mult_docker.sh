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
    
    elif [ "$RELEASE" == "ubuntu" ]; then
    
    elif [ "$RELEASE" == "debian" ]; then
    
    else
    
    fi
}
