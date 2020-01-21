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

function check_release(){

    source /etc/os-release
    RELEASE=$ID
    VERSION=$VERSION_ID
    if [ "$Release" == "centos" ] && [ "$VERSION_ID" == "7" ]; then
        centos7
    elif [ "$Release" == "centos" ] && [ "$VERSION_ID" == "8" ]; then
    
    
    

}
