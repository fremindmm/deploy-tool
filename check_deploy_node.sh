#!/bin/bash
set -o xtrace
PXE_START_IP=192.168.1.225
PXE_END_IP=192.168.1.245
PXE_GATEWAY=192.168.1.1

FIRST_CARD=`ip a|grep 2:|head -1|awk -F':' '{print $2}'`
DEPLOY_NODE_IP=`ip a |grep ${FIRST_CARD} |grep inet |awk -F' ' '{print $2}'|awk -F'/' '{print $1}'`

START=`echo ${PXE_START_IP}| awk -F'.' '{print $4}'`
END=`echo ${PXE_END_IP}| awk -F'.' '{print $4}'`

#1
echo "deploy node net_card: ${FIRST_CARD}, ip: ${DEPLOY_NODE_IP}"

#2
docker ps -a|grep cobbler |grep Up
#if Down then `docker satrt cobbler`

#3 set default pxe boot setting

function set_default_boot_setting(){
    if [[ ! -f /tmp/cobbler_list ]];then
        docker exec -u root cobbler sed -i /^DEFAULT/s/menu/CentOS-7-x86_64/g /etc/cobbler/pxe/pxedefault.template
        docker exec -u root cobbler sed -i '8,11d' /etc/cobbler/pxe/pxedefault.template
        docker exec -u root cobbler cat /etc/cobbler/pxe/pxedefault.template
        docker restart cobbler

        #check cobbler is ok
        docker exec -u root cobbler cobbler list |tee /tmp/cobbler_list
    fi
}

#set pxe ip range
function set_pxe_ip_range(){
    if [[ ! -f /tmp/ip_range ]];then
        docker exec -u root cobbler sed -i /dynamic-bootp/s/\(2/\(${START}/g /usr/share/ansible/templates/dhcp.template

        docker exec -u root cobbler sed -i /dynamic-bootp/s/\(-2/\(${END}/g /usr/share/ansible/templates/dhcp.template

        docker exec -u root cobbler cat /usr/share/ansible/templates/dhcp.template |grep dynamic-bootp |tee /tmp/ip_range
    fi
}

function restart_cobbler(){
    docker stop cobbler
    sleep 120
    docker start cobbler
}

function check_ip_ok(){
    docker exec -u root cobbler cat /etc/dhcp/dhcpd.conf |grep range
    START_IP=`docker exec -u root cobbler cat /etc/dhcp/dhcpd.conf|grep range|awk -F' ' '{print $3}'`
    END_IP=`docker exec -u root cobbler cat /etc/dhcp/dhcpd.conf|grep range|awk -F' ' '{print $4}'`
    END_IP=`echo ${END_IP} |awk -F';' '{print $1}'`
    if [[ "${PXE_START_IP}" == ${START_IP} ]] && [[ "${PXE_END_IP}" == ${END_IP} ]];then
        echo "ok"
    else
        echo "pxe ip range is not ok"
        restart_cobbler
        docker exec -u root cobbler cat /etc/dhcp/dhcpd.conf |grep range
    fi
}
function set_pxe_gateway(){
   cur_gateway=`route -n |sed -n '3p'|awk -F' ' '{print $2}'`
   if [ ${cur_gateway} != ${PXE_GATEWAY} ];then
       route del -net 0.0.0.0 gw ${cur_gateway}
       route add default gw ${PXE_GATEWAY}
   fi
}
function clear_dhcp_leases(){
   docker exec -it cobbler mv /var/lib/dhcpd/dhcpd.leases /tmp
   docker exec -it cobbler touch /var/lib/dhcpd/dhcpd.leases
}

function main(){
   set_default_boot_setting
   set_pxe_ip_range
   set_pxe_gateway
   restart_cobbler
   restart_cobbler
   restart_cobbler
   clear_dhcp_leases
   check_ip_ok
}
main
