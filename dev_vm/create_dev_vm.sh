#!/bin/bash 

# initialize variables
interface=eth1
dev_vm_ip=$(ip address|grep inet|grep eno1|awk '{print $2}'|awk -F '/' '{print $1}'|awk -F '.' -v x=$(expr $(hostname|cut -b 11-) + 20) '{print $1"."$2"."$3"."x}')
gateway_ip=$(ip route | grep default | awk '{print $3}')
EOF=EOF

# generate vagrant file for the contrail VM
cat << EOF > Vagrantfile
Vagrant.configure("2") do |config|
  config.vm.box = "centos/7"

  config.vm.define "dev" do |dev|
    dev.vm.provider "virtualbox" do |v|
      v.memory=32000
      v.cpus = 8
    end

    dev.vm.network "public_network", auto_config: false, bridge: 'eno1'

    dev.vm.provision :shell do |shell|
      shell.path="/tmp/dev-vm-init.sh"
    end

    dev.vm.provision :ansible do |ansible|
      ansible.playbook = "provision_dev_vm.yml"
    end
  end
end
EOF

# generate the standup script to be invoked after the dev VM is spawned
cat << EOF > /tmp/dev-vm-init.sh
# configure interface $interface
cat << EOF > /etc/sysconfig/network-scripts/ifcfg-$interface
DEVICE="$interface"
BOOTPROTO="static"
ONBOOT="yes"
TYPE="Ethernet"
IPADDR=$dev_vm_ip
NETMASK=255.255.224.0
GATEWAY=$gateway_ip
DNS1=10.155.191.252
DNS2=172.21.200.60
DOMAIN=englab.juniper.net spglab.juniper.net jnpr.net juniper.net
$EOF
systemctl restart network.service
EOF

# bring up the VM
vagrant up
