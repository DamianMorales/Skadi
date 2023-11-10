#!/bin/bash

#    Author Damian Morales <damian7820@gmail.com>
#    Based on the base scripts
#
#    Copyright (C) 2023  Pasha <pasha@member.fsf.org>
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


OPENSTACK_HOST_IP="10.0.0.11"
EXTERNAL_BRIDGE_INTERFACE="enp1s0" #is diferent OPENSTACK_HOST_IP
MY_USER_NAME="openstack"
MY_USER_PASS="openstack"
HOSTNAME="controller"
NTP_SERVER="sv.pool.ntp.org"

if [ -z ${OPENSTACK_HOST_IP} ]; then
    echo "Please set OpenStack host IP"
    exit 1
fi

if [ -z ${EXTERNAL_BRIDGE_INTERFACE} ]; then
    echo "Please set external bridge interface name"
    exit 1
fi

hostnamectl set-hostname $HOSTNAME

OPENSTACK_HOST=$HOSTNAME
CONFIG_DIR="configs"
CONFIG_DEPLOY_DIR="deployed"
SECURITY_OPENRC="security-openrc"

export DEBIAN_FRONTEND=noninteractive

function setup_admin_pass(){
  ADMIN_PASS=$(openssl rand -hex 10)
  RABBIT_PASS=$(openssl rand -hex 10)
}

function setup_security_services() {
  KEYSTONE_PASS=$(openssl rand -hex 10)
  sed -i "s/REPLACE_WITH_KEYSTONE_PASS/${KEYSTONE_PASS}/" ${CONFIG_DIR}/database.sql
  GLANCE_PASS=$(openssl rand -hex 10)
  sed -i "s/REPLACE_WITH_GLANCE_PASS/${GLANCE_PASS}/" ${CONFIG_DIR}/database.sql
  PLACEMENT_PASS=$(openssl rand -hex 10)
  sed -i "s/REPLACE_WITH_PLACEMENT_PASS/${PLACEMENT_PASS}/" ${CONFIG_DIR}/database.sql
  NOVA_PASS=$(openssl rand -hex 10)
  sed -i "s/REPLACE_WITH_NOVA_PASS/${NOVA_PASS}/" ${CONFIG_DIR}/database.sql
  NEUTRON_PASS=$(openssl rand -hex 10)
  sed -i "s/REPLACE_WITH_NEUTRON_PASS/${NEUTRON_PASS}/" ${CONFIG_DIR}/database.sql
  HEAT_PASS=$(openssl rand -hex 10)
  sed -i "s/REPLACE_WITH_HEAT_PASS/${HEAT_PASS}/" ${CONFIG_DIR}/database.sql
}

function setup_security_oprnrc(){
  echo "export ADMIN_PASS=${ADMIN_PASS}" >> ${CONFIG_DIR}/${SECURITY_OPENRC}
  echo "export RABBIT_PASS=${RABBIT_PASS}" >> ${CONFIG_DIR}/${SECURITY_OPENRC}
  echo "export KEYSTONE_PASS=${KEYSTONE_PASS}" >> ${CONFIG_DIR}/${SECURITY_OPENRC}
  echo "export GLANCE_PASS=${GLANCE_PASS}" >> ${CONFIG_DIR}/${SECURITY_OPENRC}
  echo "export PLACEMENT_PASS=${PLACEMENT_PASS}" >> ${CONFIG_DIR}/${SECURITY_OPENRC}
  echo "export NOVA_PASS=${NOVA_PASS}" >> ${CONFIG_DIR}/${SECURITY_OPENRC}
  echo "export NEUTRON_PASS=${NEUTRON_PASS}" >> ${CONFIG_DIR}/${SECURITY_OPENRC}
  echo "export HEAT_PASS=${HEAT_PASS}" >> ${CONFIG_DIR}/${SECURITY_OPENRC}
}

function setup_file_pass() {
  # Keystone
  sed -i "s/REPLACE_WITH_KEYSTONE_PASS/${KEYSTONE_PASS}/" ${CONFIG_DIR}/keystone.conf
  # Glance
  sed -i "s/REPLACE_WITH_RABBIT_PASS/${RABBIT_PASS}/" ${CONFIG_DIR}/glance-api.conf
  sed -i "s/REPLACE_WITH_GLANCE_PASS/${GLANCE_PASS}/" ${CONFIG_DIR}/glance-api.conf
  # Nova
  sed -i "s/REPLACE_WITH_RABBIT_PASS/${RABBIT_PASS}/" ${CONFIG_DIR}/nova.conf
  sed -i "s/REPLACE_WITH_NOVA_PASS/${NOVA_PASS}/" ${CONFIG_DIR}/nova.conf
  sed -i "s/REPLACE_WITH_PLACEMENT_PASS/${PLACEMENT_PASS}/" ${CONFIG_DIR}/nova.conf
  # Nova 2
  sed -i "s/REPLACE_WITH_RABBIT_PASS/${RABBIT_PASS}/" ${CONFIG_DIR}/nova2.conf
  sed -i "s/REPLACE_WITH_NOVA_PASS/${NOVA_PASS}/" ${CONFIG_DIR}/nova2.conf
  sed -i "s/REPLACE_WITH_PLACEMENT_PASS/${PLACEMENT_PASS}/" ${CONFIG_DIR}/nova2.conf
  sed -i "s/REPLACE_WITH_NEUTRON_PASS/${NEUTRON_PASS}/" ${CONFIG_DIR}/nova2.conf
  # Placement
  sed -i "s/REPLACE_WITH_PLACEMENT_PASS/${PLACEMENT_PASS}/" ${CONFIG_DIR}/placement.conf
  # Neutron
  sed -i "s/REPLACE_WITH_RABBIT_PASS/${RABBIT_PASS}/" ${CONFIG_DIR}/neutron.conf
  sed -i "s/REPLACE_WITH_NEUTRON_PASS/${NEUTRON_PASS}/" ${CONFIG_DIR}/neutron.conf
  sed -i "s/REPLACE_WITH_NOVA_PASS/${NOVA_PASS}/" ${CONFIG_DIR}/neutron.conf
   # Heat
  sed -i "s/REPLACE_WITH_HEAT_PASS/${HEAT_PASS}/" ${CONFIG_DIR}/heat.conf
}

function set_openstack_repository() {
  echo "respository setting.."
  apt-get install -y extrepo
  extrepo enable openstack_bobcat
  apt-get update
}

function download_packages() {
    echo "downloading packages..."
    apt-get -dy install chrony mariadb-server python3-pymysql rabbitmq-server memcached python3-memcache etcd keystone apache2 python3-openstackclient glance placement-api libguestfs-tools virt-manager nova-api nova-conductor nova-novncproxy nova-scheduler neutron-server neutron-plugin-ml2 neutron-linuxbridge-agent neutron-dhcp-agent neutron-metadata-agent neutron-plugin-ml2 neutron-openvswitch-agent neutron-l3-agent python3-neutronclient
    apt-get -dy install openstack-dashboard openstack-dashboard-apache
    echo "done"
}

function update_hostip() {
    echo "updating host IP..."
    sed -i "s/127.0.1.1[[:blank:]]${OPENSTACK_HOST}/#127.0.1.1	${OPENSTACK_HOST}/" /etc/hosts
    sed -i "/127.0.0.1.*/a\\${OPENSTACK_HOST_IP}      ${OPENSTACK_HOST}" /etc/hosts
    echo "done"
}

function setup_chrony() {
    echo "installing chrony..."
    apt-get -y install chrony
    echo "server ${NTP_SERVER} iburst" >> /etc/chrony/chrony.conf
    systemctl enable chrony
    systemctl restart chrony
    echo "done"
}

function setup_mariadb() {
    echo "installing mariadb..."
    apt-get -y install mariadb-server python3-pymysql
    sed "s/REPLACE_WITH_OPENSTACK_HOST_IP/${OPENSTACK_HOST_IP}/" ${CONFIG_DIR}/99-openstack.cnf > /etc/mysql/mariadb.conf.d/99-openstack.cnf
    systemctl restart mariadb
    echo "done"
}

function setup_rabbitmq() {
    echo "installing rabbitmq"
    apt-get -y install rabbitmq-server
    export PATH=$PATH:/usr/sbin/:/sbin
    rabbitmqctl add_user openstack ${RABBIT_PASS}
    rabbitmqctl set_permissions openstack ".*" ".*" ".*"
    echo "done"
}

function setup_memcahed() {
    echo "installing memcahed"
    apt-get -y install memcached python3-memcache
    sed -i "s/-l 127.0.0.1/-l ${OPENSTACK_HOST_IP}/" /etc/memcached.conf
    systemctl enable memcached
    systemctl restart memcached
    echo "done"
}

function setup_etcd() {
    echo "installing etcd"
    apt-get -y install etcd-server etcd-client
    sed "s/REPLACE_WITH_OPENSTACK_HOST_IP/${OPENSTACK_HOST_IP}/" ${CONFIG_DIR}/etcd >> /etc/default/etcd
    sed -i "s/REPLACE_WITH_HOST/${OPENSTACK_HOST}/" /etc/default/etcd
    systemctl enable etcd
    systemctl restart etcd
    echo "done"
}

function setup_database_tables() {
    echo "creating database tables..."
    mysql -u root < ${CONFIG_DIR}/database.sql
    echo "done"
}

function setup_apache2() {
    echo "installing apache2..."
    apt-get -y install apache2
    # set servername in apache2
    sed -i "1i ServerName ${OPENSTACK_HOST}" /etc/apache2/apache2.conf
    systemctl restart apache2
    echo "done"
}


function setup_keystone() {
    echo "installing keystone..."
    apt-get -y install keystone
    mv /etc/keystone/keystone.conf /etc/keystone/keystone.conf.org
    systemctl stop keystone
    sed "s/REPLACE_WITH_HOST/${OPENSTACK_HOST}/" ${CONFIG_DIR}/keystone.conf > /etc/keystone/keystone.conf
    apt-get -y install python3-openstackclient
    su -s /bin/sh -c "keystone-manage db_sync" keystone
    systemctl restart apache2
    systemctl start keystone
    echo "done"
}

function configure_keystone() {
    echo "configuring keystone..."
    # keystone-manage
    keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
    keystone-manage credential_setup --keystone-user keystone --keystone-group keystone
    keystone-manage bootstrap --bootstrap-password ${ADMIN_PASS} --bootstrap-admin-url http://${OPENSTACK_HOST}:5000/v3/ --bootstrap-internal-url http://${OPENSTACK_HOST}:5000/v3/ --bootstrap-public-url http://${OPENSTACK_HOST}:5000/v3/ --bootstrap-region-id RegionOne
    echo "done"
}


function set_auth_variables() {
    echo "setting auth variables..."
    sed -i "s/REPLACE_WITH_ADMIN_PASS/${ADMIN_PASS}/" ${CONFIG_DIR}/admin-openrc
    sed "s/REPLACE_WITH_HOST/${OPENSTACK_HOST}/" ${CONFIG_DIR}/admin-openrc > admin-openrc
    sed "s/REPLACE_WITH_HOST/${OPENSTACK_HOST}/" ${CONFIG_DIR}/demo-openrc > demo-openrc
    source admin-openrc
    echo "done"
}

function configure_domain_project() {
    echo "configuring doamin and project..."
    openstack domain create --description "An Example Domain" example
    openstack project create --domain default --description "Service Project" service
    openstack project create --domain default --description "Demo Project" myproject
    openstack user create --domain default --password ${MY_USER_PASS} ${MY_USER_NAME}
    openstack role create myrole
    openstack role add --project myproject --user ${MY_USER_NAME} myrole
    echo "done"
}


function configure_glance_endpoints() {
    echo "configuring glance endpoints..."
    openstack user create --domain default --password ${GLANCE_PASS} glance
    openstack role add --project service --user glance admin
    openstack service create --name glance --description "OpenStack Image" image

    openstack endpoint create --region RegionOne image public http://${OPENSTACK_HOST}:9292
    openstack endpoint create --region RegionOne image internal http://${OPENSTACK_HOST}:9292
    openstack endpoint create --region RegionOne image admin http://${OPENSTACK_HOST}:9292

    openstack user create --domain default --password MY_SERVICE MY_SERVICE
    openstack role add --user MY_SERVICE --user-domain default --system all reader
    echo "done"
}

function setup_glance() {
    echo "installing glance..."
    apt-get -y install glance
    systemctl stop glance-*
    mv /etc/glance/glance-api.conf /etc/glance/glance-api.conf.org
    sed "s/REPLACE_WITH_HOST/${OPENSTACK_HOST}/" ${CONFIG_DIR}/glance-api.conf > /etc/glance/glance-api.conf    
    su -s /bin/sh -c "glance-manage db_sync" glance
    systemctl start glance-api
    systemctl enable glance-api
    #wget http://download.cirros-cloud.net/0.4.0/cirros-0.4.0-x86_64-disk.img
    #glance image-create --name "cirros" \
    #	   --file cirros-0.4.0-x86_64-disk.img \
    #	   --disk-format qcow2 --container-format bare \
    #	   --visibility=public
    echo "done"
}

function configure_placement_endpoints() {
    echo "configuring placement endpoints..."
    openstack user create --domain default --password ${PLACEMENT_PASS} placement
    openstack role add --project service --user placement admin
    openstack service create --name placement --description "Placement API" placement
    openstack endpoint create --region RegionOne placement public http://${OPENSTACK_HOST}:8778
    openstack endpoint create --region RegionOne placement internal http://${OPENSTACK_HOST}:8778
    openstack endpoint create --region RegionOne placement admin http://${OPENSTACK_HOST}:8778
    echo "done"
}

function setup_placement() {
    echo "installing placement..."
    apt-get -y install placement-api
    mv /etc/placement/placement.conf /etc/placement/placement.conf.org
    sed "s/REPLACE_WITH_HOST/${OPENSTACK_HOST}/" ${CONFIG_DIR}/placement.conf > /etc/placement/placement.conf   
    su -s /bin/sh -c "placement-manage db sync" placement
    systemctl restart placement-api
    systemctl enable placement-api
    systemctl restart apache2
    echo "done"
}

function configure_nova_endpoints() {
    echo "configuring nova endpoints..."
    openstack user create --domain default --password ${NOVA_PASS} nova
    openstack role add --project service --user nova admin
    openstack service create --name nova --description "OpenStack Compute" compute
    openstack endpoint create --region RegionOne compute public http://${OPENSTACK_HOST}:8774/v2.1
    openstack endpoint create --region RegionOne compute internal http://${OPENSTACK_HOST}:8774/v2.1
    openstack endpoint create --region RegionOne compute admin http://${OPENSTACK_HOST}:8774/v2.1    
    echo "done"
}

function setup_nova() {
    echo "installing nova..."
    apt-get -y install libguestfs-tools virt-manager
    apt-get -y install nova-api nova-conductor nova-novncproxy nova-scheduler
    systemctl stop nova-*
    mv /etc/nova/nova.conf /etc/nova/nova.conf.org
    cp ${CONFIG_DIR}/nova.conf /etc/nova/nova.conf

    sed -i "s/REPLACE_WITH_HOST/${OPENSTACK_HOST}/" /etc/nova/nova.conf
    sed -i "s/REPLACE_WITH_OPENSTACK_HOST_IP/${OPENSTACK_HOST_IP}/" /etc/nova/nova.conf

    su -s /bin/sh -c "nova-manage api_db sync" nova
    su -s /bin/sh -c "nova-manage cell_v2 map_cell0" nova
    su -s /bin/sh -c "nova-manage cell_v2 create_cell --name=cell1 --verbose" nova
    su -s /bin/sh -c "nova-manage db sync" nova
    #apt-get -y install nova-compute
    #apt-get -y install nova-compute-qemu
    systemctl start nova-api
    systemctl enable nova-api
    systemctl enable nova-scheduler
    systemctl enable nova-conductor
    systemctl enable nova-serialproxy
    systemctl enable nova-spicehtml5proxy
    systemctl enable nova-novncproxy
    #systemctl enable nova-compute
    # find hypervisor
    su -s /bin/bash nova -c "nova-manage cell_v2 discover_hosts"
    #systemctl restart nova-*
    systemctl restart nova-api
    systemctl restart nova-scheduler
    systemctl restart nova-conductor
    systemctl restart nova-novncproxy
    systemctl restart nova-serialproxy
    systemctl restart nova-spicehtml5proxy
    #systemctl restart nova-compute
    echo "done"
}


function configure_neutron_endpoints() {
    echo "configuring neutron endpoints..."
    openstack user create --domain default --password ${NEUTRON_PASS} neutron
    openstack role add --project service --user neutron admin
    openstack service create --name neutron --description "OpenStack Networking" network
    openstack endpoint create --region RegionOne network public http://${OPENSTACK_HOST}:9696
    openstack endpoint create --region RegionOne network internal http://${OPENSTACK_HOST}:9696
    openstack endpoint create --region RegionOne network admin http://${OPENSTACK_HOST}:9696
    echo "done"
}


function setup_neutron() {
    echo "installing neutron..."
    apt-get -y install neutron-server neutron-plugin-ml2 neutron-linuxbridge-agent neutron-dhcp-agent neutron-metadata-agent neutron-l3-agent
    systemctl stop neutron-*

    mv /etc/neutron/neutron.conf /etc/neutron/neutron.conf.org
    cp ${CONFIG_DIR}/neutron.conf /etc/neutron/neutron.conf
    sed -i "s/REPLACE_WITH_HOST/${OPENSTACK_HOST}/" /etc/neutron/neutron.conf

    mv /etc/neutron/metadata_agent.ini /etc/neutron/metadata_agent.ini.org
    cp ${CONFIG_DIR}/metadata_agent.ini /etc/neutron/metadata_agent.ini
    sed -i "s/REPLACE_WITH_HOST/${OPENSTACK_HOST}/" /etc/neutron/metadata_agent.ini

    # update for neutron config
    cp ${CONFIG_DIR}/nova2.conf /etc/nova/nova.conf
    sed -i "s/REPLACE_WITH_HOST/${OPENSTACK_HOST}/" /etc/nova/nova.conf
    sed -i "s/REPLACE_WITH_OPENSTACK_HOST_IP/${OPENSTACK_HOST_IP}/" /etc/nova/nova.conf

    mv /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugins/ml2/ml2_conf.ini.org
    cp ${CONFIG_DIR}/ml2_conf.ini /etc/neutron/plugins/ml2/ml2_conf.ini
    mv /etc/neutron/plugins/ml2/linuxbridge_agent.ini /etc/neutron/plugins/ml2/linuxbridge_agent.ini.org
    cp ${CONFIG_DIR}/linuxbridge_agent.ini /etc/neutron/plugins/ml2/linuxbridge_agent.ini
    sed 's/PROVIDER_INTERFACE/'$EXTERNAL_BRIDGE_INTERFACE'/' ${CONFIG_DIR}/linuxbridge_agent.ini > /etc/neutron/plugins/ml2/linuxbridge_agent.ini
    mv /etc/neutron/dhcp_agent.ini /etc/neutron/dhcp_agent.ini.org
    cp ${CONFIG_DIR}/dhcp_agent.ini /etc/neutron/dhcp_agent.ini

    mv /etc/neutron/l3_agent.ini /etc/neutron/l3_agent.ini.org
    cp ${CONFIG_DIR}/l3_agent.ini /etc/neutron/l3_agent.ini
    sed -i "s/interface_driver = openvswitch/interface_driver = linuxbridge/" /etc/neutron/l3_agent.ini

    echo "net.bridge.bridge-nf-call-iptables=1" >> /etc/sysctl.conf
    echo "net.bridge.bridge-nf-call-ip6tables=1" >> /etc/sysctl.conf
    sysctl -p

    systemctl enable neutron-api
    systemctl enable neutron-rpc-server
    systemctl enable neutron-metadata-agent
    systemctl enable neutron-linuxbridge-agent
    systemctl enable neutron-dhcp-agent
    systemctl enable neutron-l3-agent


    systemctl restart nova-*
    systemctl restart neutron-api
    systemctl restart neutron-rpc-server
    systemctl restart neutron-metadata-agent
    systemctl restart neutron-linuxbridge-agent
    systemctl restart neutron-dhcp-agent
    systemctl restart neutron-l3-agent

    su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron

    echo "done"
}

function enable_hypervisor() {
    echo "updating hypervisor"
    su -s /bin/bash nova -c "nova-manage cell_v2 discover_hosts"
    echo "done"
}

function configure_heat_endpoints() {
    echo "configuring heat endpoints..."
    openstack user create --domain default --password ${HEAT_PASS} heat
    openstack role add --project service --user heat admin
    openstack service create --name heat --description "Orchestration" orchestration
    openstack service create --name heat-cfn --description "Orchestration"  cloudformation
    openstack endpoint create --region RegionOne orchestration public http://${OPENSTACK_HOST}:8004/v1/%\(tenant_id\)s
    openstack endpoint create --region RegionOne orchestration internal http://${OPENSTACK_HOST}:8004/v1/%\(tenant_id\)s
    openstack endpoint create --region RegionOne orchestration admin http://${OPENSTACK_HOST}:8004/v1/%\(tenant_id\)s
    openstack endpoint create --region RegionOne cloudformation public http://${OPENSTACK_HOST}:8000/v1
    openstack endpoint create --region RegionOne cloudformation internal http://${OPENSTACK_HOST}:8000/v1
    openstack endpoint create --region RegionOne cloudformation admin http://${OPENSTACK_HOST}:8000/v1
    openstack domain create --description "Stack projects and users" heat
    openstack user create --domain heat --password ${HEAT_PASS} heat_domain_admin
    openstack role add --domain heat --user-domain heat --user heat_domain_admin admin
    openstack role create heat_stack_owner
    openstack role add --project myproject --user ${MY_USER_NAME} heat_stack_owner
    openstack role create heat_stack_user
    echo "done"
}

function setup_heat() {
    echo "installing heat..."
    apt-get -y install heat-api heat-api-cfn heat-engine
    mv /etc/heat/heat.conf /etc/heat/heat.conf.org
    sed "s/REPLACE_WITH_HOST/${OPENSTACK_HOST}/" ${CONFIG_DIR}/heat.conf > /etc/heat/heat.conf
    su -s /bin/sh -c "heat-manage db_sync" heat
    systemctl restart heat-api
    systemctl restart heat-api-cfn
    systemctl restart heat-engine
    systemctl enable heat-api
    systemctl enable heat-api-cfn
    systemctl enable heat-engine
    echo "done"
}

function install_dashboard() {
    echo "installing dashboard"
    apt-get -y install openstack-dashboard-apache
    mv /etc/openstack-dashboard/local_settings.py /etc/openstack-dashboard/local_settings.py.org
    sed "s/REPLACE_WITH_HOST/${OPENSTACK_HOST}/" ${CONFIG_DIR}/local_settings.py > /etc/openstack-dashboard/local_settings.py
    /usr/sbin/a2enmod ssl
    /usr/sbin/a2enmod rewrite
    systemctl restart apache2
    echo "done"
}

function install_heat_dashboard() {
    echo "installing heat-dashboard..."
    apt-get -y install python3-heat-dashboard
    systemctl restart apache2
}


set_openstack_repository
download_packages
update_hostip
setup_chrony
setup_mariadb
setup_admin_pass
setup_rabbitmq
setup_memcahed
setup_etcd
setup_security_services
setup_security_oprnrc
setup_file_pass
setup_database_tables
setup_apache2
setup_keystone
configure_keystone
set_auth_variables
configure_domain_project
configure_glance_endpoints
setup_glance
configure_placement_endpoints
setup_placement
configure_nova_endpoints
setup_nova
configure_neutron_endpoints
setup_neutron
enable_hypervisor
configure_heat_endpoints
setup_heat
install_dashboard
install_heat_dashboard
