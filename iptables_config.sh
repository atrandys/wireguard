#!/bin/bash

#开放ssh端口、回环、外网、默认策略
config_default(){
    systemctl stop firewalld
    systemctl disable firewalld
    yum install -y iptables-services
    systemctl start iptables
    systemctl enable iptables
    ssh_port=$(awk '$1=="Port" {print $2}' /etc/ssh/sshd_config)
    if [ ! -n "$ssh_port" ]; then
        iptables -A INPUT -p tcp -m tcp --dport 22 -j ACCEPT
    else
        iptables -A INPUT -p tcp -m tcp --dport ${ssh_port} -j ACCEPT
    fi
    iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
    iptables -A INPUT -i lo -j ACCEPT
    iptables -P INPUT DROP
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    service iptables save
    echo "初始配置完成"
}

#禁止邮箱
config_mail(){
    iptables -A FORWARD -p tcp -m multiport --dports 24,25,26,50,57,105,106,109,110,143 -j REJECT --reject-with tcp-reset
    iptables -A FORWARD -p udp -m multiport --dports 24,25,26,50,57,105,106,109,110,143 -j DROP
    iptables -A FORWARD -p tcp -m multiport --dports 158,209,218,220,465,587,993,995,1109,60177,60179 -j REJECT --reject-with tcp-reset
    iptables -A FORWARD -p udp -m multiport --dports 158,209,218,220,465,587,993,995,1109,60177,60179 -j DROP
    service iptables save
    echo "禁止邮箱完毕"
}

#禁止关键字
config_keyword(){
    iptables -A FORWARD -m string --string "netflix.com" --algo bm -j DROP
    iptables -A FORWARD -m string --string "tumblr.com" --algo bm -j DROP
    iptables -A FORWARD -m string --string "facebook.com.com" --algo bm -j DROP
    iptables -A FORWARD -m string --string "instagram.com" --algo bm -j DROP
    iptables -A FORWARD -m string --string "pixiv.net" --algo bm -j DROP
    iptables -A FORWARD -m string --string "whatsapp.com" --algo bm -j DROP
    iptables -A FORWARD -m string --string "telegram.com" --algo bm -j DROP
    iptables -A FORWARD -m string --string "tunsafe.com" --algo bm -j DROP
    iptables -A FORWARD -m string --string "reddit.com" --algo bm -j DROP
    iptables -A FORWARD -m string --string "vimeo.com" --algo bm -j DROP
    iptables -A FORWARD -m string --string "dailymotion.com" --algo bm -j DROP
    iptables -A FORWARD -m string --string "hulu.com" --algo bm -j DROP
    iptables -A FORWARD -m string --string "liveleak.com" --algo bm -j DROP
    iptables -A FORWARD -m string --string "vine.co" --algo bm -j DROP
    iptables -A FORWARD -m string --string "ustream.tv" --algo bm -j DROP
    iptables -A FORWARD -m string --string "metacafe.com" --algo bm -j DROP
    iptables -A FORWARD -m string --string "viewstr.com" --algo bm -j DROP
    iptables -A FORWARD -m string --string "torrent" --algo bm -j DROP
    iptables -A FORWARD -m string --string ".torrent" --algo bm -j DROP
    iptables -A FORWARD -m string --string "peer_id=" --algo bm -j DROP
    iptables -A FORWARD -m string --string "announce" --algo bm -j DROP
    iptables -A FORWARD -m string --string "info_hash" --algo bm -j DROP
    iptables -A FORWARD -m string --string "get_peers" --algo bm -j DROP
    iptables -A FORWARD -m string --string "find_node" --algo bm -j DROP
    iptables -A FORWARD -m string --string "BitToorent" --algo bm -j DROP
    iptables -A FORWARD -m string --string "announce_peer" --algo bm -j DROP
    iptables -A FORWARD -m string --string "BitTorrent protocol" --algo bm -j DROP
    iptables -A FORWARD -m string --string "announce.php?passkey=" --algo bm -j DROP
    iptables -A FORWARD -m string --string "magnet:" --algo bm -j DROP
    iptables -A FORWARD -m string --string "xunlei" --algo bm -j DROP
    iptables -A FORWARD -m string --string "sandai" --algo bm -j DROP
    iptables -A FORWARD -m string --string "Thunder" --algo bm -j DROP
    iptables -A FORWARD -m string --string "XLLiveUD" --algo bm -j DROP
    iptables -A FORWARD -m string --string "youtube.com" --algo bm -j DROP
    iptables -A FORWARD -m string --string "google.com" --algo bm -j DROP
    iptables -A FORWARD -m string --string "youku.com" --algo bm -j DROP
    iptables -A FORWARD -m string --string "iqiyi.com" --algo bm -j DROP
    iptables -A FORWARD -m string --string "qq.com" --algo bm -j DROP
    iptables -A FORWARD -m string --string "huya.com" --algo bm -j DROP
    iptables -A FORWARD -m string --string "douyu.com" --algo bm -j DROP
    iptables -A FORWARD -m string --string "twitch.tv" --algo bm -j DROP
    iptables -A FORWARD -m string --string "panda.tv" --algo bm -j DROP
    iptables -A FORWARD -m string --string "porn" --algo bm -j DROP
    iptables -A FORWARD -m string --string "renminbao.com" --algo bm -j DROP
    iptables -A FORWARD -m string --string "dajiyuan.com" --algo bm -j DROP
    iptables -A FORWARD -m string --string "bignews.org" --algo bm -j DROP
    iptables -A FORWARD -m string --string "creaders.net" --algo bm -j DROP
    iptables -A FORWARD -m string --string "rfa.org" --algo bm -j DROP
    iptables -A FORWARD -m string --string "internetfreedom.org" --algo bm -j DROP
    iptables -A FORWARD -m string --string "voanews.com" --algo bm -j DROP
    iptables -A FORWARD -m string --string "minghui.org" --algo bm -j DROP
    iptables -A FORWARD -m string --string "kanzhongguo.com" --algo bm -j DROP
    iptables -A FORWARD -m string --string "peacehall.com" --algo bm -j DROP
    iptables -A FORWARD -m string --string "twister" --algo bm -j DROP
    service iptables save
    echo "禁止关键字完毕"
}

#开放自定义端口
config_port(){
    echo "开放一个自定义的端口段"
    read -p "输入开始端口：" start_port
    read -p "输入结束端口：" stop_port
    iptables -A INPUT -p tcp -m tcp --dport ${start_port}:${stop_port} -j ACCEPT
    iptables -A INPUT -p udp -m udp --dport ${start_port}:${stop_port} -j ACCEPT
    service iptables save
    echo "开放端口完毕"
}

#连接数限制
config_conn(){
    echo "限制一个端口段的连接数"
    read -p "输入开始端口：" start_conn
    read -p "输入结束端口：" stop_conn
    read -p "输入每个ip允许的连接数：" conn_num
    iptables -A INPUT -p tcp --dport ${start_conn}:${stop_conn} -m connlimit --connlimit-above ${conn_num} -j DROP
    iptables -A INPUT -p udp --dport ${start_conn}:${stop_conn} -m connlimit --connlimit-above ${conn_num} -j DROP
    service iptables save
    echo "限制连接数完毕"
}

#IP限速
config_IP(){
    echo "限制IP的速度，从10.0.0.2-254，限制100/sec"
    for ((i=2; i<=254; i ++))
    do
	iptables -I FORWARD -d 10.0.0.$i/32 -j DROP
    	iptables -I FORWARD -d 10.0.0.$i/32 -m limit --limit 100/sec -j ACCEPT 
    done
    service iptables save
    echo "限制IP速度完毕"
}

#清空规则
config_clear(){
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -F
    service iptables save
    echo "清除规则完毕"
}

#start
start_menu(){
while [ 1 ] 
do
    echo "========================="
    echo " 介绍：适用于CentOS7"
    echo " 作者：atrandys"
    echo " 网站：www.atrandys.com"
    echo " Youtube：atrandys"
    echo "========================="
    echo "1. 开启ssh（必须）"
    echo "2. 禁止邮箱"
    echo "3. 禁止常用关键字"
    echo "4. 开放自定义端口"
    echo "5. 连接数限制"
    echo "6. ip限速"
    echo "7. 清除所有规则"
    echo "0. 退出"
    echo
    read -p "请输入数字:" num
    case "$num" in
    	1)
	config_default
	;;
	2)
	config_mail
	;;
        3)
	config_keyword
	;;
        4)
	config_port
	;;
        5)
	config_conn
	;;
	6)
	config_IP
	;;
        7)
	config_clear
	;;
	0)
	exit 1
	;;
	*)
	clear
	echo "请输入正确数字"
	sleep 5s
	start_menu
	;;
    esac
done
}

start_menu
