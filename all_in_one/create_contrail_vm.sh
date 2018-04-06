#!/bin/bash 

if [ $# != 1 ]; then
  echo "Usage: create_contrail_vm.sh <build-tag>"
  echo "Note: contrail nightly build tag must be provided. The latest nightly build tag can be"
  echo "found at https://hub.docker.com/r/opencontrailnightly/contrail-openstack-neutron-init/tags"
  exit 1
fi

# initialize variables
tag=$1
interface=eth1
contrail_vm_ip=$(ip address|grep inet|grep eno1|awk '{print $2}'|awk -F '/' '{print $1}'|awk -F '.' -v x=$(expr $(hostname|cut -b 11-) + 30) '{print $1"."$2"."$3"."x}')
gateway_ip=$(ip route | grep default | awk '{print $3}')
ntp_server=172.21.200.60
EOF=EOF

mkdir -p run

# generate vagrant file for the contrail VM
cat << EOF > Vagrantfile
Vagrant.configure("2") do |config|
  config.vm.box = "centos/7"

  config.vm.define "contrail" do |contrail|
    contrail.vm.provider "virtualbox" do |v|
      v.memory=100000
      v.cpus = 16
    end

    contrail.vm.network "public_network", auto_config: false, bridge: 'eno1'

    contrail.vm.provision :shell do |shell|
      shell.path="/tmp/contrail-vm-init.sh"
    end

    contrail.vm.provision :ansible do |ansible|
      ansible.playbook = "provision.yml"
    end

    contrail.vm.provision :shell do |shell|
      shell.path = "/tmp/install_contrail_kolla_requirements.sh"
    end

    contrail.vm.provision :shell do |shell|
      shell.path = "/tmp/deploy-contrail.sh"
    end

    contrail.vm.provision :shell do |shell|
      shell.path = "/tmp/authorized-keys.sh"
    end
  end
end
EOF

# generate the standup script to be invoked after the dev VM is spawned
cat << EOF > /tmp/contrail-vm-init.sh
# configure interface $interface
cat << EOF > /etc/sysconfig/network-scripts/ifcfg-$interface
DEVICE="$interface"
BOOTPROTO="static"
ONBOOT="yes"
TYPE="Ethernet"
IPADDR=$contrail_vm_ip
NETMASK=255.255.224.0
GATEWAY=$gateway_ip
DNS1=10.155.191.252
DNS2=172.21.200.60
DOMAIN=englab.juniper.net spglab.juniper.net jnpr.net juniper.net
$EOF
systemctl restart network.service
echo "contrail123" | passwd --stdin root
EOF

# Install Contrail and Kolla requirements
cat << EOF > /tmp/install_contrail_kolla_requirements.sh
echo "-----------Install contrail & kolla requirements-------------------"
cd ~/contrail-ansible-deployer
ansible-playbook -i inventory/ playbooks/configure_instances.yml
EOF

# Deploy contrail and kolla containers
cat << EOF > /tmp/deploy-contrail.sh
echo "-----------Deploy contrail containers-------------------"
cd ~/contrail-ansible-deployer
ansible-playbook -i inventory/ -e orchestrator=openstack playbooks/install_contrail.yml
EOF

# update group_vars/all.yml
cat << EOF > group_vars/all.yml
all_in_one_node: "$contrail_vm_ip"
interface_name: "$interface"
container_registry: "opencontrailnightly"
contrail_version: "$tag"
ntp_server: "$ntp_server"
gateway_ip: "$gateway_ip"
EOF

# add authorized keys
authorized_keys=$(cat ~/.ssh/authorized_keys)
cat << EOF > /tmp/authorized-keys.sh
sudo echo "$authorized_keys" >> /root/.ssh/authorized_keys
EOF

# bring up the VM
vagrant plugin install vagrant-vbguest
vagrant up
