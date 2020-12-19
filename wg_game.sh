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

function randpwd(){
    mpasswd=$(cat /dev/urandom | head -1 | md5sum | head -c 4)
    echo ${mpasswd}  
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
        red "关闭SELinux"
        red "============"
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi
    if [ "$CHECK" == "SELINUX=permissive" ]; then
        red "============"
        red "关闭SELinux"
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

function install_tools(){
    if [ "$RELEASE" == "centos" ]; then
        $1 install -y qrencode iptables-services
        systemctl enable iptables 
        systemctl start iptables 
        iptables -F
	service iptables save
    else
        $1 install -y qrencode iptables
    fi
    echo 1 > /proc/sys/net/ipv4/ip_forward
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
    sysctl -p

}

function install_wg(){
    check_release
    if [ "$RELEASE" == "centos" ] && [ "$VERSION" == "7" ]; then
        yum install -y yum-utils epel-release
        yum-config-manager --setopt=centosplus.includepkgs=kernel-plus --enablerepo=centosplus --save
        sed -e 's/^DEFAULTKERNEL=kernel$/DEFAULTKERNEL=kernel-plus/' -i /etc/sysconfig/kernel
        yum install -y kernel-plus wireguard-tools
	sed -i "s/GRUB_DEFAULT=saved/GRUB_DEFAULT=0/" /etc/default/grub
        grub2-mkconfig -o /boot/grub2/grub.cfg
        systemctl stop firewalld
        systemctl disable firewalld
        install_tools "yum"
    elif [ "$RELEASE" == "centos" ] && [ "$VERSION" == "8" ]; then
        yum install -y yum-utils epel-release
        yum-config-manager --setopt=centosplus.includepkgs="kernel-plus, kernel-plus-*" --setopt=centosplus.enabled=1 --save
        sed -e 's/^DEFAULTKERNEL=kernel-core$/DEFAULTKERNEL=kernel-plus-core/' -i /etc/sysconfig/kernel
        yum install -y kernel-plus wireguard-tools
	sed -i "s/GRUB_DEFAULT=saved/GRUB_DEFAULT=0/" /etc/default/grub
        grub2-mkconfig -o /boot/grub2/grub.cfg
        systemctl stop firewalld
        systemctl disable firewalld
        install_tools "yum"
    elif [ "$RELEASE" == "ubuntu" ]; then
        if [ "$VERSION" == "12.04" ] || [ "$VERSION" == "16.04" ]; then
	    red "=================="
            red "$RELEASE $VERSION系统暂未支持"
            red "=================="
	    exit
	fi
        systemctl stop ufw
        systemctl disable ufw
	apt-get install -y wget
	wget https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.8.15/amd64/linux-headers-5.8.15-050815-generic_5.8.15-050815.202010141131_amd64.deb
	wget https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.8.15/amd64/linux-headers-5.8.15-050815_5.8.15-050815.202010141131_all.deb
	wget https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.8.15/amd64/linux-image-unsigned-5.8.15-050815-generic_5.8.15-050815.202010141131_amd64.deb
	wget https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.8.15/amd64/linux-modules-5.8.15-050815-generic_5.8.15-050815.202010141131_amd64.deb
	dpkg -i *.deb
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
	apt install -y linux-image-5.8.0-0.bpo.2-cloud-amd64
	apt install -y wireguard openresolv
	#apt update
        #apt install -y wireguard
        install_tools "apt"
    else
        red "=================="
        red "$RELEASE $VERSION系统暂未支持"
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
    port=$(rand 10000 60000)
    eth=$(ls /sys/class/net| grep ^e | head -n1)
    chmod 777 -R /etc/wireguard

cat > /etc/wireguard/wg0.conf <<-EOF
[Interface]
PrivateKey = $s1
Address = 10.77.0.1/24 
PostUp   = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o $eth -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o $eth -j MASQUERADE
ListenPort = $port
DNS = 8.8.8.8
MTU = 1300
[Peer]
PublicKey = $c2
AllowedIPs = 10.77.0.2/32
EOF

#cat > /etc/wireguard/client.conf <<-EOF
#[Interface]
#PrivateKey = $c1
#Address = 10.77.0.2/24 
#DNS = 8.8.8.8
#MTU = 1420
#[Peer]
#PublicKey = $s2
#Endpoint = $serverip:$port
#AllowedIPs = 0.0.0.0/0, ::0/0
#PersistentKeepalive = 25
#EOF
    #wg-quick up wg0
    udp_install
    systemctl enable wg-quick@wg0
    #content=$(cat /etc/wireguard/client.conf)
    green "配置文件位置:/etc/wireguard/client.conf"
    #green "${content}" | qrencode -o - -t UTF8
    red "注意：本次安装必须重启一次, wireguard才能正常使用"
    read -p "是否现在重启 ? [Y/n] :" yn
    [ -z "${yn}" ] && yn="y"
    if [[ $yn == [Yy] ]]; then
        echo -e "VPS 重启中..."
        reboot
    fi
}

function udp_install(){
    #下载udpspeeder和udp2raw （amd64版）
    mkdir /usr/src/udp
    cd /usr/src/udp
    wget https://github.com/atrandys/wireguard/raw/master/speederv2
    wget https://github.com/atrandys/wireguard/raw/master/udp2raw
    wget https://raw.githubusercontent.com/atrandys/wireguard/master/run.sh
    chmod +x speederv2 udp2raw run.sh
    
    #启动udpspeeder和udp2raw
    udpport=$(rand 10000 60000)
    password=$(randpwd)
    #nohup ./speederv2 -s -l127.0.0.1:23333 -r127.0.0.1:$port -f2:4 --mode 0 --timeout 0 >speeder.log 2>&1 &
    #nohup ./udp2raw -s -l0.0.0.0:$udpport -r 127.0.0.1:23333  --raw-mode faketcp  -a -k $password >udp2raw.log 2>&1 &
    echo -e "\033[37;41m输入你客户端电脑的默认网关，打开cmd，使用ipconfig命令查看\033[0m"
    read -p "比如192.168.1.1 ：" ugateway

cat > /etc/wireguard/client.conf <<-EOF
[Interface]
PrivateKey = $c1
PostUp = mshta vbscript:CreateObject("WScript.Shell").Run("cmd /c route add $serverip mask 255.255.255.255 $ugateway METRIC 20 & start /b c:/udp/speederv2.exe -c -l127.0.0.1:2090 -r127.0.0.1:2091 -f2:4 --mode 0 --timeout 0 & start /b c:/udp/udp2raw.exe -c -r$serverip:$udpport -l127.0.0.1:2091 --raw-mode faketcp -k $password",0)(window.close)
PostDown = route delete $serverip && taskkill /im udp2raw.exe /f && taskkill /im speederv2.exe /f
Address = 10.77.0.2/24 
DNS = 8.8.8.8
MTU = 1300
[Peer]
PublicKey = $s2
Endpoint = 127.0.0.1:2090
AllowedIPs = 0.0.0.0/0, ::0/0
PersistentKeepalive = 25
EOF

cat > /etc/wireguard/client_noudp.conf <<-EOF
[Interface]
PrivateKey = $c1
Address = 10.77.0.2/24 
DNS = 8.8.8.8
MTU = 1300
[Peer]
PublicKey = $s2
Endpoint = $serverip:$port
AllowedIPs = 0.0.0.0/0, ::0/0
PersistentKeepalive = 25
EOF

cat > /etc/wireguard/udp.sh <<-EOF
#!/bin/bash
nohup usr/src/udp/speederv2 -s -l127.0.0.1:23333 -r127.0.0.1:$port -f2:4 --mode 0 --timeout 0 >speeder.log 2>&1 &
nohup usr/src/udp/udp2raw -s -l0.0.0.0:$udpport -r 127.0.0.1:23333  --raw-mode faketcp  -a -k $password >udp2raw.log 2>&1 &
EOF

    chmod +x /etc/wireguard/udp.sh

#增加自启动脚本
cat > /etc/systemd/system/autoudp.service<<-EOF
[Unit]  
Description=autoudp 
After=network.target  
   
[Service]  
Type=forking
ExecStart=/etc/wireguard/udp.sh
ExecReload=/bin/kill -9 \$(pidof udp2raw) && /bin/kill -9 \$(pidof udpspeeder)
Restart=on-failure
RestartSec=1s
   
[Install]  
WantedBy=multi-user.target
EOF

#设置脚本权限
    chmod +x /etc/systemd/system/autoudp.service
    systemctl enable autoudp.service
    systemctl start autoudp.service
}

function add_user(){

    green "=================================="
    green "给新用户起个名字，不能和已有用户重复"
    green "=================================="
    read -p "请输入用户名：" newname
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
        green "添加完成，文件：/etc/wireguard/$newname.conf"
        green "============================================="
        rm -f temprikey tempubkey
    else
        red "======================"
        red "用户名已存在，请更换名称"
        red "======================"
    fi

}

function remove_wg(){
    check_release
    if [ -d "/etc/wireguard" ]; then
        wg-quick down wg0
        if [ "$RELEASE" == "centos" ]; then
            yum remove -y wireguard-dkms wireguard-tools
            rm -rf /etc/wireguard/
            green "卸载完成"
        elif [ "$RELEASE" == "ubuntu" ]; then
            apt-get remove -y wireguard
            rm -rf /etc/wireguard/
            green "卸载完成"
        elif [ "$RELEASE" == "debian" ]; then
            apt remove -y wireguard
            rm -rf /etc/wireguard/
            green "卸载完成"
        else
            red "系统不符合要求"
        fi
    else
        red "未检测到wireguard"
    fi
}

function start_menu(){
    clear
    green "==============================================="
    green " 介绍: 一键安装wireguard + udpspeeder + udp2raw"
    green " 系统: Centos7+/Ubuntu18.04+/Debian9+"
    green " 作者: atrandys www.atrandys.com"
    green " 提示: 脚本安装过程中会升级内核，请勿生产环境使用"
    green "==============================================="
    green "1. 安装wireguard + udpspeeder + udp2raw"
    red "2. 删除wireguard"
    green "3. 增加用户"
    red "0. 退出"
    echo
    read -p "请选择:" num
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
