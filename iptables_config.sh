#!/bin/bash

#Open ssh port, loopback, outbound, default policy
config_default(){
    systemctl stop firewalld
    systemctl disable firewalld
    apt install -y iptables
    systemctl start iptables
    systemctl enable iptables
    ssh_port=$(awk '$1=="Port" {print $2}' /etc/ssh/sshd_config)
    if [ ! -n "$ssh_port" ]; then
        iptables -A INPUT -p tcp -m tcp --dport 22 -j ACCEPT
    else
        iptables -A INPUT -p tcp -m tcp --dport ${ssh_port} -j ACCEPT
    fi
    iptables -A INPUT -p tcp --tcp-flags RST RST --sport 443 -j DROP
    iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
    iptables -A INPUT -i lo -j ACCEPT
    iptables -P INPUT DROP
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    service iptables save
    echo "Initial Settings Completed"
}

#No Mailbox
config_mail(){
    iptables -A FORWARD -p tcp -m multiport --dports 24,25,26,50,57,105,106,109,110,143 -j REJECT --reject-with tcp-reset
    iptables -A FORWARD -p udp -m multiport --dports 24,25,26,50,57,105,106,109,110,143 -j DROP
    iptables -A FORWARD -p tcp -m multiport --dports 158,209,218,220,465,587,993,995,1109,60177,60179 -j REJECT --reject-with tcp-reset
    iptables -A FORWARD -p udp -m multiport --dports 158,209,218,220,465,587,993,995,1109,60177,60179 -j DROP
    service iptables save
    echo "Mailbox completion prohibited"
}

#No Keywords
config_keyword(){
    iptables -A FORWARD -m string --string "netflix.com" --algo bm -j DROP
    iptables -A FORWARD -m string --string "tumblr.com" --algo bm -j DROP
    iptables -A FORWARD -m string --string "facebook.com" --algo bm -j DROP
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
    echo "Keyword completion prohibited"
}

#Open Custom Port
config_port(){
    echo "Open one custom port segment"
    read -p "Enter Start Port：" start_port
    read -p "Enter End Port：" stop_port
    iptables -A INPUT -p tcp -m tcp --dport ${start_port}:${stop_port} -j ACCEPT
    iptables -A INPUT -p udp -m udp --dport ${start_port}:${stop_port} -j ACCEPT
    service iptables save
    echo "Open Port Completed"
}

#Limit number of connections
config_conn(){
    echo "Limit the number of connections to one port segment"
    read -p "Enter Start Port：" start_conn
    read -p "Enter End Port：" stop_conn
    read -p "Enter the number of connections allowed per ip：" conn_num
    iptables -A INPUT -p tcp --dport ${start_conn}:${stop_conn} -m connlimit --connlimit-above ${conn_num} -j DROP
    iptables -A INPUT -p udp --dport ${start_conn}:${stop_conn} -m connlimit --connlimit-above ${conn_num} -j DROP
    service iptables save
    echo "Limit number of connections completed"
}

#IP speed limit
config_IP(){
    echo "IP speed limit, 10.0.0.2-254, 100/sec limit"
    for ((i=2; i<=254; i ++))
    do
	iptables -I FORWARD -d 10.0.0.$i/32 -j DROP
    	iptables -I FORWARD -d 10.0.0.$i/32 -m limit --limit 100/sec -j ACCEPT 
    done
    service iptables save
    echo "IP speed limit complete"
}

#rule of emptying
config_clear(){
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -F
    service iptables save
    echo "Rule removal complete."
}

#start
start_menu(){
while [ 1 ] 
do
    clear
    echo "========================="
    echo " Introduction：Apply to Ubuntu"
    echo " author：atrandys"
    echo " Web site：www.atrandys.com"
    echo " Youtube：atrandys"
    echo "========================="
    echo "1. Turn on ssh (required)"
    echo "2. No Mailbox"
    echo "3. Do not use keywords frequently"
    echo "4. Open Custom Port"
    echo "5. Limit number of connections"
    echo "6. ip speed limit"
    echo "7. Remove all rules"
    echo "0. exit"
    echo
    read -p "Please enter a number:" num
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
	echo "Please enter a valid number"
	sleep 5s
	start_menu
	;;
    esac
done
}

start_menu
