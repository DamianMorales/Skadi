#!/bin/bash

#    Copyright (C) 2023  Damian Morales <damian7820@gmail.com>
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <https://www.gnu.org/licenses/>.

OPENSTACK_HOST_IP="10.0.0.31"
OPENSTACK_CONTROLLER_HOST_IP="10.0.0.11"
EXTERNAL_INTERFACE="enp1s0" #is diferent OPENSTACK_HOST_IP
HOSTNAME="compute1"
HOSTNAME_CONTROLLER="controller"
CONFIG_DEPLOY_DIR="deployed"

hostnamectl set-hostname $HOSTNAME

OPENSTACK_HOST=$HOSTNAME
CONFIG_DIR="configs"
CONFIG_COMPUTE_DIR="compute"
export PATH=$PATH:/usr/sbin/:/sbin
export DEBIAN_FRONTEND=noninteractive
source $CONFIG_DIR/security-openrc

function setup_file_pass() {
  # Nova
  sed -i "s/REPLACE_WITH_RABBIT_PASS/${RABBIT_PASS}/" ${CONFIG_DIR}/${CONFIG_COMPUTE_DIR}/nova.conf
  sed -i "s/REPLACE_WITH_NOVA_PASS/${NOVA_PASS}/" ${CONFIG_DIR}/${CONFIG_COMPUTE_DIR}/nova.conf
  sed -i "s/REPLACE_WITH_PLACEMENT_PASS/${PLACEMENT_PASS}/" ${CONFIG_DIR}/${CONFIG_COMPUTE_DIR}/nova.conf
  # Nova 2
  sed -i "s/REPLACE_WITH_RABBIT_PASS/${RABBIT_PASS}/" ${CONFIG_DIR}/${CONFIG_COMPUTE_DIR}/nova2.conf
  sed -i "s/REPLACE_WITH_NOVA_PASS/${NOVA_PASS}/" ${CONFIG_DIR}/${CONFIG_COMPUTE_DIR}/nova2.conf
  sed -i "s/REPLACE_WITH_PLACEMENT_PASS/${PLACEMENT_PASS}/" ${CONFIG_DIR}/${CONFIG_COMPUTE_DIR}/nova2.conf
  sed -i "s/REPLACE_WITH_NEUTRON_PASS/${NEUTRON_PASS}/" ${CONFIG_DIR}/${CONFIG_COMPUTE_DIR}/nova2.conf
  # Neutron
  sed -i "s/REPLACE_WITH_RABBIT_PASS/${RABBIT_PASS}/" ${CONFIG_DIR}/${CONFIG_COMPUTE_DIR}/neutron.conf
  sed -i "s/REPLACE_WITH_NEUTRON_PASS/${NEUTRON_PASS}/" ${CONFIG_DIR}/${CONFIG_COMPUTE_DIR}/neutron.conf
  sed -i "s/REPLACE_WITH_NOVA_PASS/${NOVA_PASS}/" ${CONFIG_DIR}/${CONFIG_COMPUTE_DIR}/neutron.conf
}

function set_openstack_repository() {
  echo "respository setting.."
  apt-get install -y extrepo
  extrepo enable openstack_bobcat
  apt-get update
}

function download_packages() {
    echo "downloading packages..."
    apt-get -dy install nova-compute chrony python3-pymysql python3-memcache python3-openstackclient libguestfs-tools virt-manager neutron-linuxbridge-agent neutron-dhcp-agent neutron-metadata-agent neutron-plugin-ml2 neutron-openvswitch-agent neutron-l3-agent python3-neutronclient
    echo "done"
}

function update_hostip() {
    echo "updating host IP..."
    sed -i "s/127.0.1.1[[:blank:]]${OPENSTACK_HOST}/#127.0.1.1	${OPENSTACK_HOST}/" /etc/hosts
    sed -i "/127.0.0.1.*/a\\${OPENSTACK_HOST_IP}      ${OPENSTACK_HOST}" /etc/hosts
    sed -i "/${OPENSTACK_HOST_IP}.*/a\\${OPENSTACK_CONTROLLER_HOST_IP}      ${HOSTNAME_CONTROLLER}" /etc/hosts
    echo "done"
}

function setup_chrony() {
    echo "installing chrony..."
    apt-get -y install chrony
    echo "server ${HOSTNAME_CONTROLLER} iburst" >> /etc/chrony/cohrony.conf
    systemctl enable chrony
    systemctl restart chrony
    echo "done"
}

function setup_nova() {
    echo "installing nova..."
    apt-get -y install libguestfs-tools virt-manager
    apt-get -y install nova-compute
    apt-get -y install nova-compute-qemu nova-novncproxy nova-spicehtml5proxy
    systemctl stop nova-*
    mv /etc/nova/nova.conf /etc/nova/nova.conf.org
    cp ${CONFIG_DIR}/${CONFIG_COMPUTE_DIR}/nova.conf /etc/nova/nova.conf

    sed -i "s/REPLACE_WITH_HOST/${HOSTNAME_CONTROLLER}/" /etc/nova/nova.conf
    sed -i "s/REPLACE_WITH_OPENSTACK_HOST_IP/${OPENSTACK_HOST_IP}/" /etc/nova/nova.conf
    sed -i "s/virt_type=qemu/virt_type=qemu/" /etc/nova/nova-compute.conf

    systemctl enable nova-compute
    systemctl enable nova-novncproxy
    systemctl enable nova-spicehtml5proxy
    systemctl enable nova-serialproxy
    systemctl restart nova-compute
    systemctl restart nova-novncproxy
    systemctl restart nova-spicehtml5proxy
    systemctl restart nova-serialproxy
    echo "done"
}

function setup_neutron() {
    echo "installing neutron..."
    apt-get -y install neutron-plugin-ml2 neutron-linuxbridge-agent neutron-l3-agent neutron-openvswitch-agent neutron-dhcp-agent neutron-metadata-agent neutron-l3-agent
    systemctl stop neutron-*

    mv /etc/neutron/neutron.conf /etc/neutron/neutron.conf.org
    cp ${CONFIG_DIR}/${CONFIG_COMPUTE_DIR}/neutron.conf /etc/neutron/neutron.conf
    sed -i "s/REPLACE_WITH_HOST/${HOSTNAME_CONTROLLER}/" /etc/neutron/neutron.conf

    # update for neutron config
    cp ${CONFIG_DIR}/${CONFIG_COMPUTE_DIR}/nova2.conf /etc/nova/nova.conf
    sed -i "s/REPLACE_WITH_HOST/${HOSTNAME_CONTROLLER}/" /etc/nova/nova.conf
    sed -i "s/REPLACE_WITH_OPENSTACK_HOST_IP/${OPENSTACK_HOST_IP}/" /etc/nova/nova.conf

    mv /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugins/ml2/ml2_conf.ini.org
    cp ${CONFIG_DIR}/${CONFIG_COMPUTE_DIR}/ml2_conf.ini /etc/neutron/plugins/ml2/ml2_conf.ini
    mv /etc/neutron/plugins/ml2/linuxbridge_agent.ini /etc/neutron/plugins/ml2/linuxbridge_agent.ini.org
    cp ${CONFIG_DIR}/${CONFIG_COMPUTE_DIR}/linuxbridge_agent.ini /etc/neutron/plugins/ml2/linuxbridge_agent.ini
    sed -i "s/PROVIDER_INTERFACE/${EXTERNAL_INTERFACE}/" /etc/neutron/plugins/ml2/linuxbridge_agent.ini
    sed -i "s/OVERLAY_INTERFACE_IP_ADDRESS/${OPENSTACK_HOST_IP}/" /etc/neutron/plugins/ml2/linuxbridge_agent.ini
    mv /etc/neutron/dhcp_agent.ini /etc/neutron/dhcp_agent.ini.org
    cp ${CONFIG_DIR}/${CONFIG_COMPUTE_DIR}/dhcp_agent.ini /etc/neutron/dhcp_agent.ini

    mv /etc/neutron/l3_agent.ini /etc/neutron/l3_agent.ini.org
    cp ${CONFIG_DIR}/${CONFIG_COMPUTE_DIR}/l3_agent.ini /etc/neutron/l3_agent.ini
    sed -i "s/interface_driver = openvswitch/interface_driver = linuxbridge/" /etc/neutron/l3_agent.ini

    echo "net.bridge.bridge-nf-call-iptables=1" >> /etc/sysctl.conf
    echo "net.bridge.bridge-nf-call-ip6tables=1" >> /etc/sysctl.conf
    export PATH=$PATH:/usr/sbin/:/sbin
    sysctl -p

    systemctl restart nova-compute
    systemctl restart neutron-linuxbridge-agent
    systemctl restart neutron-l3-agent

    echo "done"
}

set_openstack_repository
download_packages
setup_file_pass
update_hostip
setup_chrony
setup_nova
setup_neutron
