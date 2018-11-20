# wireguard一键配置脚本 (含服务器端与客户端)

## 初次安装
wget wget --no-check-certificate  https://raw.githubusercontent.com/ysy/wireguard/master/wg.sh && chmod +x wg.sh && ./wg.sh

选择 1.重新安装配置Wireguard
配置完成后，会以红字显示第一个客户端配置文件的内容，拷贝到客户端或生成二维码即可使用。


## 增加用户
选择 2.增加用户 <br>
输入用户名，即会生成客户端配置文件 <br>

## 删除用户
选择 4.删除用户 <br>
输入用户名，即可删除 <br>

## 配置透明代理软路由
目前透明代理软路由只在Ubuntu系统上测试过 <br>
### 客户端配置
wget wget --no-check-certificate  https://raw.githubusercontent.com/ysy/wireguard/master/install_tproxy.sh && chmod +x install_tproxy.sh && ./install_tproxy.sh <br>

### 服务器端配置
选择 3. 增加用户(udp2raw配置) <br>
输入用户名，再输入软路由下设的局域网地址段 (如: 192.168.0.0) <br>
脚本会自动生成客户端的wg配置文件，将其文件拷贝至软路由(Ubuntu系统）的 /etc/wireguard/wg0.conf <br>
在软路由上运行  wg-quick up wg0  <br>
需要将终端机的网关和DNS设为软路由的地个址（如: 192.168.0.1 或 192.168.0.2 等) <br>
这个配置会根据域名是否在GfwList中来做分流，所以必须将终端机的DNS为软路由的地址。 <br>
另外，在软路由的wg0口上没有做NAT，整个局域网的地址段跟服务器是相通的，可以在服务器上PING通局域网上的主机。如果配置多个客户端时，注意局域网地址段不能一样，否则无法路由。如果有多个局域网接入，这些局域网也是相通的，如果认为有安全风险，请自行增加iptables规则。<br>



