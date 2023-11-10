# Skadi
Shell script to install OpenStack with Debian

# Debian OpenStack Installer for home lab setup

Install Debian 12 (Bookworm) on a physical/virtual machine.
If you decide used virtual machine, this must be have 12-16 cores of processor and 12-16 Gb ram


# 1. setup static IP for controller

/etc/network/interfaces
-------------------------------
...

`allow-hotplug enp1s0  
iface enp1s0 inet dhcp #192.168.122.145`  


allow-hotplug enp7s0
iface enp7s0 inet static
    address 10.0.0.11
    broadcast 10.0.0.255
    netmask 255.255.255.0

# setup static IP for compute

/etc/network/interfaces
-------------------------------
...

allow-hotplug enp1s0
iface enp1s0 inet dhcp #192.168.122.145

allow-hotplug enp7s0
iface enp7s0 inet static
    address 10.0.0.31
    broadcast 10.0.0.255
    netmask 255.255.255.0
--------------------------------
We will use same ethernet connection for host and virtual machines.

systemctl restart networking


external
router
  |
  |
 enp7s0
  |
  -------> static IP: 192.168.122.155


# Edit "openstack_setup.sh" and set the following setting:

OPENSTACK_HOST_IP="192.168.122.145"
EXTERNAL_BRIDGE_INTERFACE="enp1s0"

chmod +x openstack_setup.sh
./openstack_setup.sh

# Initial Configurations
$ . skady/admin-openrc

Verify network agent list
$ openstack network agent list

Create network and subnet
$ openstack network create --share --external \
  --provider-physical-network provider \
  --provider-network-type flat provider

$ openstack subnet create --network provider \
  --allocation-pool start=192.168.0.20,end=192.168.0.90 \
  --dns-nameserver 192.168.0.1 --gateway 192.168.0.1 \
  --subnet-range 192.168.0.0/24 provider

Enabled network protocols
$ openstack security group rule create --proto icmp default
$ openstack security group rule create --proto tcp --dst-port 22 default

Openstack keypair
Generate key
$ ssh-keygen -q -N ""

$ openstack keypair create --public-key ~/.ssh/id_rsa.pub mykey
$ openstack keypair list

Create cpu and memory flavor
$ openstack flavor create --id 0 --vcpus 2 --ram 1024 --disk 10 m1.nano

Debian openstack image
$ wget  https://cdimage.debian.org/cdimage/openstack/10.13.18-20230817/debian-10.13.18-20230817-openstack-amd64.qcow2

Upload image to Glance
$ openstack image create \
  --container-format bare \
  --disk-format qcow2 \
  --property hw_disk_bus=scsi \
  --property hw_scsi_model=virtio-scsi \
  --property os_type=linux \
  --property os_distro=debian \
  --property os_admin_user=debian \
  --property os_version='10' \
  --public \
  --file debian-10.13.18-20230817-openstack-amd64.qcow2 \
  debian-10-openstack-amd64

# Check "next_steps" for networking and launching your first instance.

# You can access dashboard: https://192.168.122.145/horizon/
After you launch your first instance

external
router
  |
  |
 enp7s0
  |
  -------> bridge-xxx - static IP: 10.0.0.11
              |
	      |
	      ------- virtual machines ...
# Now you should install the virtual machine that will do the computing.
1 Copy skdy dir from controller to compute machine
2 Change the permissions of the main scripts
chmod +x openstack_compute_setup.sh
./openstack_compute_setup.sh

# Create an intance
$ openstack network list
+--------------------------------------+----------+--------------------------------------+
| ID                                   | Name     | Subnets                              |
+--------------------------------------+----------+--------------------------------------+
| cec7e586-e1fc-4faa-a2a3-d4eb22042eb1 | provider | 62865e2a-9cf1-4df7-9fce-a47d6dd7dca9 |
+--------------------------------------+----------+--------------------------------------+

Copy ID as net-id
$ openstack server create --flavor m1.nano \
  --image debian-10-openstack-amd64 \
  --nic net-id=62865e2a-9cf1-4df7-9fce-a47d6dd7dca9 \
  --security-group default \
  --key-name mykey \
  debianinstance

Verify
$ openstack server list

# Dashboard login
https://192.168.122.145/horizon/
The IP addres could be different in your deployed

login: admin
pass: You must see the file admin-openrc
Domain: default
