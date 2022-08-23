#!/bin/bash

#CentOS、Rocky静态IP代码部分来自hiCasper
#Windows部分来自veip007
#基于以上添加了custom password、自定义端口

GET_NETCMD(){
    if [[ $static == 'true' ]];then
        MAINIP=$(ip route get 1 | awk -F 'src ' '{print $2}' | awk '{print $1}')
        GATEWAYIP=$(ip route | grep default | awk '{print $3}')
        SUBNET=$(ip -o -f inet addr show | awk '/scope global/{sub(/[^.]+\//,"0/",$4);print $4}' | head -1 | awk -F '/' '{print $2}')
        value=$(( 0xffffffff ^ ((1 << (32 - $SUBNET)) - 1) ))
        NETMASK="$(( (value >> 24) & 0xff )).$(( (value >> 16) & 0xff )).$(( (value >> 8) & 0xff )).$(( value & 0xff ))"
        
        echo -e "MAINIP: ${MAINIP}\nGATEWAYIP: ${GATEWAYIP}\nNETMASK: ${NETMASK}"
        read -p "请检查是否正确(is ok?)!!![Y/n][Default Yes]: " input
        case $input in
            [yY][eE][sS]|[yY]) NETCMD="--ip-addr ${MAINIP} --ip-gate ${GATEWAYIP} --ip-mask ${NETMASK}" ;;
            [nN][oO]|[nN]) UPDATE_NETCMD ;;
            *) NETCMD="--ip-addr ${MAINIP} --ip-gate ${GATEWAYIP} --ip-mask ${NETMASK}" ;;
        esac
    else
        NETCMD=""
    fi
}

UPDATE_NETCMD(){
    read -p "输入IP(Input IP)[Default ${MAINIP}]: " NEW_MAINIP
    read -p "输入网关(Input GATEWAYIP)[Default ${GATEWAYIP}]: " NEW_GATEWAYIP
    read -p "输入掩码(Input NETMASK)[Default ${NETMASK}]: " NEW_NETMASK
    if [[ ${NEW_MAINIP} ]];then MAINIP=${NEW_MAINIP}; fi
    if [[ ${NEW_GATEWAYIP} ]];then GATEWAYIP=${NEW_GATEWAYIP}; fi
    if [[ ${NEW_NETMASK} ]];then NETMASK=${NEW_NETMASK}; fi

    echo -e "MAINIP: ${MAINIP}\nGATEWAYIP: ${GATEWAYIP}\nNETMASK: ${NETMASK}"
    read -p "请再次检查是否正确(is ok?)!!![Y/n][Default Yes]: " input
    case $input in
        [yY][eE][sS]|[yY]) NETCMD="--ip-addr ${MAINIP} --ip-gate ${GATEWAYIP} --ip-mask ${NETMASK}" ;;
        [nN][oO]|[nN]) UPDATE_NETCMD ;;
        *) NETCMD="--ip-addr ${MAINIP} --ip-gate ${GATEWAYIP} --ip-mask ${NETMASK}" ;;
    esac
}

RHELImageBootConf() {
    touch /tmp/bootconf.sh
    echo '#!/bin/sh'>/tmp/bootconf.sh

    if [ "$static" == 'true' ]; then
        cat >>/tmp/bootconf.sh <<EOF
sed -i 's/dhcp/static/' /etc/sysconfig/network-scripts/ifcfg-eth0;
echo -e "IPADDR=$MAINIP\nNETMASK=$NETMASK\nGATEWAY=$GATEWAYIP\nDNS1=8.8.8.8\nDNS2=8.8.4.4" >> /etc/sysconfig/network-scripts/ifcfg-eth0
EOF
    fi
    echo "echo root:${password:-haoduck.com}|chpasswd;" >>/tmp/bootconf.sh
    if [[ ${port} ]];then
    cat >>/tmp/bootconf.sh <<EOF
sed -ri 's/^#?Port.*/Port ${port}/g' /etc/ssh/sshd_config; \
sed -ri 's/^#?PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config; \
sed -ri 's/^#?PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config;
EOF
    fi
    cat >>/tmp/bootconf.sh <<EOF
rm -f /etc/rc.d/rc.local
cp -f /etc/rc.d/rc.local.bak /etc/rc.d/rc.local
rm -rf /bootconf.sh
shutdown -r now
EOF
    sed -i '/sbin\/reboot/i\ sync; umount \\$(list-devices partition |head -n1); mount -t ext4 \\$(list-devices partition |head -n1) \/mnt; cp -f \/mnt\/etc\/rc.d\/rc.local \/mnt\/etc\/rc.d\/rc.local.bak; chmod +x \/mnt\/etc\/rc.d\/rc.local; cp -f \/bootconf.sh \/mnt\/bootconf.sh; chmod 755 \/mnt\/bootconf.sh; echo \"\/bootconf.sh\" >> \/mnt\/etc\/rc.d\/rc.local; sync; umount \/mnt; \\' /tmp/InstallNET.sh
    sed -i '/newc/i\cp -f \/tmp\/bootconf.sh \/tmp\/boot\/bootconf.sh'  /tmp/InstallNET.sh
}

if [[ $EUID -ne 0 ]]; then
    clear
    echo "请使用ROOT用户执行脚本(run as root)" 1>&2
    exit 1
fi

if [[ `command -v apt-get` ]];then apt-get update && apt-get install -y curl wget file xz-utils; fi
if [[ `command -v yum` ]];then yum install -y curl wget file xz; fi

curl -sSL -o /tmp/InstallNET.sh 'https://fastly.jsdelivr.net/gh/haoduck/dd@latest/InstallNET.sh' && chmod a+x /tmp/InstallNET.sh
#https://fastly.jsdelivr.net/gh/haoduck/dd@latest/InstallNET.sh
#https://fastly.jsdelivr.net/gh/MoeClub/Note@latest/InstallNET.sh

read -p "是否使用DHCP(Use DHCP)[Y/n][Default No]: " dhcp
case $dhcp in
    [yY][eE][sS]|[yY]) static=false ;;
    [nN][oO]|[nN]) static=true ;;
    *) static=true ;;
esac
GET_NETCMD

geo=$(curl -fsSL --connect-timeout 5 -m 10 http://ipinfo.io/json) || geo=$(curl -fsSL --connect-timeout 5 -m 10 http://api.ip.sb/geoip -A Mozilla|sed 's/,/,\n/g') || geo=''
if [[ $(echo "$geo" | grep "country"|grep "CN") ]];then
    DEFAULT_CN=Y
else
    DEFAULT_CN=n
fi

clear
echo ""
echo "IP: $MAINIP"
echo "GATEWAY: $GATEWAYIP"
echo "NETMASK: $NETMASK"
echo ""
echo "请选择您需要的镜像包:"
echo ""
echo "  1) Debian 11 [custom password]"
echo "  2) Debian 10 [custom password]"
echo "  3) Debian 9 [custom password]"
echo "  4) Ubuntu 20.04 [custom password]"
echo "  5) Ubuntu 18.04 [custom password]"
echo "  6) Ubuntu 16.04 [custom password]"
echo "  7) CentOS 6 [custom password]"
echo ""
echo "  ————————以下起均为dd模式————————"
echo ""
echo "  以下CentOS、Rocky部分来自hiCasper"
echo ""
echo "  8) CentOS 7.8 [custom password]"
echo "  9) CentOS 7.6 [custom password]"
echo "  10) Rocky Linux 8.6 [custom password]"
echo ""
echo "  以下Windows部分来自veip007"
echo ""
echo "  11) 萌咖Win7x64 用户名:Administrator  密码：Vicer"
echo "  12) Win2019 By:MeowLove  密码：cxthhhhh.com"
echo "  13) Win2016 By:MeowLove  密码：cxthhhhh.com"
echo "  14) Win2012 R2 By:MeowLove  密码：cxthhhhh.com"
echo "  15) Win2008 R2 By:MeowLove  密码：cxthhhhh.com"
echo "  16) Windows 7 Vienna By:MeowLove  密码：cxthhhhh.com"
echo "  17) Windows 2003 Vienna By:MeowLove  密码：cxthhhhh.com"
echo "  18) Win7x32 By:老司机  用户名:Administrator  密码：Windows7x86-Chinese"
echo "  19) Win-2003x32 By:老司机  用户名:Administrator  密码：WinSrv2003x86-Chinese"
echo "  20) Win2008x64 By:老司机  用户名:Administrator  密码：WinSrv2008x64-Chinese"
echo "  21) Win2012R2x64 By:老司机  用户名:Administrator  密码：WinSrv2012r2"
echo "  22) CentOS 8 用户名：root 密码：cxthhhhh.com 推荐512M以上使用"
echo "  23) Win7x64 By:net.nn  用户名:Administrator  密码：nat.ee"
echo "  24) Win7x64 Uefi启动的VPS专用(如:甲骨文)By:net.nn  用户名:Administrator  密码：nat.ee"
echo "  25) Win8.1x64 By:net.nn  用户名:Administrator  密码：nat.ee"
echo "  26) Win8.1x64 Uefi启动的VPS专用(如:甲骨文)By:net.nn  用户名:Administrator  密码：nat.ee"
echo "  27) 2008r2x64 By:net.nn  用户名:Administrator  密码：nat.ee"
echo "  28) 2008r2x64 Uefi启动的VPS专用(如:甲骨文)By:net.nn  用户名:Administrator  密码：nat.ee"
echo "  29) Win8.1x64 By:net.nn  用户名:Administrator  密码：nat.ee"
echo "  30) Win8.1x64 Uefi启动的VPS专用(如:甲骨文)By:net.nn  用户名:Administrator  密码：nat.ee"
echo ""
echo "  以下Windows部分来自haoduck，国内鸡专用，国外鸡用特别慢(Suitable for Chinese servers!!!)"
echo ""
echo "  31) win10-ltsc-x64-cn Username:Administrator  Password：nat.ee"
echo "  32) win7-ent-sp1-x64-cn Username:Administrator  Password：nat.ee"
echo "  33) win8.1-ent-x64-cn Username:Administrator  Password：nat.ee"
echo "  34) winsrv2008r2-data-sp1-x64-cn Username:Administrator  Password：nat.ee"
echo "  35) winsrv2012r2-data-x64-cn Username:Administrator  Password：nat.ee"
echo ""
echo "  99) 自定义直链(custom url)"
echo ""
echo "  自定义镜像也可以使用：bash /tmp/InstallNET.sh -dd '您的直连'"
echo -n "请输入编号(Input number): "
read N

RUN(){
    N=$1
    if [[ $N == 99 ]];then read -p "Input your url: " DDURL; fi
    read -p "使用国内源(Use CN mirror)[Y/n][Default: $DEFAULT_CN]" input
    if [[ -z $input ]];then input=$DEFAULT_CN; fi
    case $input in
        [yY][eE][sS]|[yY]) CN=true ;;
        [nN][oO]|[nN]) CN=false ;;
    esac
    if [[ $CN == 'true' ]];then
        echo "  选择一个源"
        echo "  1) mirrors.aliyun.com [Default]"
        echo "  2) mirrors.tencent.com"
        echo "  3) mirrors.163.com"
        echo "  4) mirrors.huaweicloud.com"
        echo "  5) mirrors.tuna.tsinghua.edu.cn"
        echo "  6) mirrors.ustc.edu.cn"
        echo "  7) mirrors.tencentyun.com [仅内网Intranet!!!]"
        echo "  99) 手动输入,示例: http://mirrors.aliyun.com"
        read -p "选择一个源(Input number): " input
        case $input in
            1) mirror=http://mirrors.aliyun.com ;;
            2) mirror=http://mirrors.tencent.com ;;
            3) mirror=http://mirrors.163.com ;;
            4) mirror=http://mirrors.huaweicloud.com ;;
            5) mirror=http://mirrors.tuna.tsinghua.edu.cn ;;
            6) mirror=http://mirrors.ustc.edu.cn ;;
            7) mirror=http://mirrors.tencentyun.com ;;
            99) if [[ ! $input =~ ^http:// ]] && [[ ! $input =~ ^https:// ]];then input=http://${input}; fi; if [[ $input =~ /$ ]];then input=${input:0:-1}; fi; mirror=$input ;;
        esac
        CMIRROR="--mirror ${mirror}/centos/"
        CVMIRROR="--mirror ${mirror}/centos-vault/"
        DMIRROR="--mirror ${mirror}/debian/"
        UMIRROR="--mirror ${mirror}/ubuntu/"
    else
        CMIRROR=''
        CVMIRROR=''
        DMIRROR=''
        UMIRROR=''
    fi
    case $N in
        1|2|3|4|5|6|7|8|9|10|22)
        read -p "Input root password[Default: haoduck.com]: " password
        read -p "Input ssh port[Default: 22]: " port
        echo -e "\nPassword: ${password:-haoduck.com}\nPort: ${port:-22}\n"
        ;;
    esac
    read -p "回车确认开始执行(Press any key to continue)，CTRL+C退出"
    case $N in
        1) bash /tmp/InstallNET.sh -d 11 -v 64 $NETCMD $DMIRROR -p ${password:-haoduck.com} -port ${port:-22} ;;
        2) bash /tmp/InstallNET.sh -d 10 -v 64 $NETCMD $DMIRROR -p ${password:-haoduck.com} -port ${port:-22} ;;
        3) bash /tmp/InstallNET.sh -d 9 -v 64 $NETCMD $DMIRROR -p ${password:-haoduck.com} -port ${port:-22} ;;
        4) bash /tmp/InstallNET.sh -u 20.04 -v 64 $NETCMD $UMIRROR -p ${password:-haoduck.com} -port ${port:-22} ;;
        5) bash /tmp/InstallNET.sh -u 18.04 -v 64 $NETCMD $UMIRROR -p ${password:-haoduck.com} -port ${port:-22} ;;
        6) bash /tmp/InstallNET.sh -u 16.04 -v 64 $NETCMD $UMIRROR -p ${password:-haoduck.com} -port ${port:-22} ;;
        7) bash /tmp/InstallNET.sh -c 6.10 -v 64 $NETCMD $CVMIRROR -p ${password:-haoduck.com} -port ${port:-22} ;;
        8) RHELImageBootConf; bash /tmp/InstallNET.sh $NETCMD -dd 'https://api.moetools.net/get/centos-78-image' $DMIRROR ;;
        9) RHELImageBootConf; bash /tmp/InstallNET.sh $NETCMD -dd 'https://api.moetools.net/get/centos-76-image' $DMIRROR ;;
        10) RHELImageBootConf; bash /tmp/InstallNET.sh $NETCMD -dd 'https://api.moetools.net/get/rocky-8-image' $DMIRROR ;;
        11) bash /tmp/InstallNET.sh $NETCMD -dd 'https://www.lefu.men/gdzl/?id=1qhE4hHkCAgAiRby8WHngNduHHhqrUeMQ' $DMIRROR ;;
        12) bash /tmp/InstallNET.sh $NETCMD -dd 'https://www.lefu.men/gdzl/?id=1IXdK-ruDrNmorxZRoJaep1Fo9p4aPi0s' $DMIRROR ;;
        13) bash /tmp/InstallNET.sh $NETCMD -dd 'https://www.lefu.men/gdzl/?id=1JnbvgbvF4hzT1msk1RJ-rjrzqqzTwI1I' $DMIRROR ;;
        14) bash /tmp/InstallNET.sh $NETCMD -dd 'https://www.lefu.men/gdzl/?id=1vz2Y9kPlbRYdP8blD0oGs5MY7EfYVgFR' $DMIRROR ;;
        15) bash /tmp/InstallNET.sh $NETCMD -dd 'https://www.lefu.men/gdzl/?id=1dvNvV9OLm-x6p9sUbnRrKTLDuaiVj_Kg' $DMIRROR ;;
        16) bash /tmp/InstallNET.sh $NETCMD -dd 'https://www.lefu.men/gdzl/?id=1O3jXs9KagrCb1SbM-DVZMAZ7gw9r3Vtp' $DMIRROR ;;
        17) bash /tmp/InstallNET.sh $NETCMD -dd 'https://www.lefu.men/gdzl/?id=1PLG3EdCziMMTIWz1vnUupMPmje2pQX43' $DMIRROR ;;
        18) bash /tmp/InstallNET.sh $NETCMD -dd 'https://www.lefu.men/gdzl/?id=16Xh4iq6guHWT92MAr-NCOzStZqMTdnmU' $DMIRROR ;;
        19) bash /tmp/InstallNET.sh $NETCMD -dd 'https://drive.google.com/open?id=1rzkH24tCtwPvcT3HquoF9tZgcj022voG' $DMIRROR ;;
        20) bash /tmp/InstallNET.sh $NETCMD -dd 'https://www.lefu.men/gdzl/?id=1wtUWaag5pVwmN-QUfTSJ6xbNWulLbLy-' $DMIRROR ;;
        21) bash /tmp/InstallNET.sh $NETCMD -dd 'https://www.lefu.men/gdzl/?id=1GUdLXMwBx4uM8-iBU6ClcD5HRmkURuEl' $DMIRROR ;;
        22) RHELImageBootConf; bash /tmp/InstallNET.sh $NETCMD -dd "https://odc.cxthhhhh.com/d/SyStem/CentOS/CentOS_8.X_x64_Legacy_NetInstallation_Stable_v6.8.vhd.gz" $DMIRROR ;;
        23) bash /tmp/InstallNET.sh $NETCMD -dd "https://www.lefu.men/gdzl/?id=1fGsryTy6xZi5EC9GlOpvqTK-Uty0_gFo" $DMIRROR ;;
        24) bash /tmp/InstallNET.sh $NETCMD -dd "https://www.lefu.men/gdzl/?id=1LxzyhswxkpI_BqUolnI0HyawNvPQJHAO" $DMIRROR ;;
        25) bash /tmp/InstallNET.sh $NETCMD -dd "https://www.lefu.men/gdzl/?id=1SKUFoUujxh3sTtLIWWcBW8riibd1q5ka" $DMIRROR ;;
        26) bash /tmp/InstallNET.sh $NETCMD -dd "https://www.lefu.men/gdzl/?id=1GUz7Suysv0S7qRuyB9vQ_IGkTbFckFcE" $DMIRROR ;;
        27) bash /tmp/InstallNET.sh $NETCMD -dd "https://www.lefu.men/gdzl/?id=1eA35gszGgUXI6P7dR5g5sqsIPnMJwUuN" $DMIRROR ;;
        28) bash /tmp/InstallNET.sh $NETCMD -dd "https://www.lefu.men/gdzl/?id=1a8gEiZTEG5aeTrTflP9icAZF-HJhYU1N" $DMIRROR ;;
        29) bash /tmp/InstallNET.sh $NETCMD -dd "https://www.lefu.men/gdzl/?id=1eboWyVSkt1Hcnsl2dqgA-8p40Qbk2QvG" $DMIRROR ;;
        30) bash /tmp/InstallNET.sh $NETCMD -dd "https://www.lefu.men/gdzl/?id=1IY8IyLt66uKhZ7Jb4QzEb_bTUUqU76_3" $DMIRROR ;;
        31) bash /tmp/InstallNET.sh $NETCMD -dd 'https://haoduck.com/files/dd/laosiji/win10-ltsc-x64-cn.vhd.gz ' $DMIRROR ;;
        32) bash /tmp/InstallNET.sh $NETCMD -dd 'https://haoduck.com/files/dd/laosiji/win7-ent-sp1-x64-cn.vhd.gz ' $DMIRROR ;;
        33) bash /tmp/InstallNET.sh $NETCMD -dd 'https://haoduck.com/files/dd/laosiji/win8.1-ent-x64-cn.vhd.gz ' $DMIRROR ;;
        34) bash /tmp/InstallNET.sh $NETCMD -dd 'https://haoduck.com/files/dd/laosiji/winsrv2008r2-data-sp1-x64-cn.vhd.gz ' $DMIRROR ;;
        35) bash /tmp/InstallNET.sh $NETCMD -dd 'https://haoduck.com/files/dd/laosiji/winsrv2012r2-data-x64-cn.vhd.gz ' $DMIRROR ;;
        99) bash /tmp/InstallNET.sh $NETCMD -dd "$DDURL" $DMIRROR ;;
        *) echo "Wrong input!" ;;
    esac
}
RUN $N
