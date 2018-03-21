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
      shell.path="run/contrail-vm-init.sh"
    end

    contrail.vm.provision :ansible do |ansible|
      ansible.playbook = "provision.yml"
    end

    contrail.vm.provision :shell do |shell|
      shell.path = "run/kolla-bootstrap.sh"
    end
  
    contrail.vm.provision :shell do |shell|
      shell.path = "run/ntp.sh"
    end
  
    contrail.vm.provision :shell do |shell|
      shell.path = "run/deploy-kolla.sh"
    end
  
    contrail.vm.provision :shell do |shell|
      shell.path = "run/deploy-contrail.sh"
    end
  
    contrail.vm.provision :shell do |shell|
      shell.path = "run/post-deploy.sh"
    end
  end
end
EOF

# generate the standup script to be invoked after the dev VM is spawned
cat << EOF > run/contrail-vm-init.sh
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
EOF

# generate script to invoke contrail deployment playbooks
cat << EOF > run/ntp.sh
echo "-----------Configure NTP---------------------------------"
cd /root/contrail-ansible-deployer
ansible-playbook -e '{"CONFIGURE_VMS":true}' -e '{"CONTAINER_VM_CONFIG":{"network":{"ntpserver":"$ntp_server"}}}' -t configure_vms -i inventory/ playbooks/deploy.yml
EOF

cat << EOF > run/kolla-bootstrap.sh
echo "-----------Kolla Bootstrap-------------------------------"
cd /root/contrail-kolla-ansible/ansible
ansible-playbook -i inventory/all-in-one -e@../etc/kolla/globals.yml -e@../etc/kolla/passwords.yml -e action=bootstrap-servers kolla-host.yml
EOF

cat << EOF > run/deploy-kolla.sh
echo "-----------Install contrail kolla containers-------------"
cd /root/contrail-kolla-ansible/ansible
ansible-playbook -i inventory/all-in-one -e@../etc/kolla/globals.yml -e@../etc/kolla/passwords.yml -e action=deploy site.yml
EOF

cat << EOF > run/deploy-contrail.sh
echo "-----------Install contrail containers-------------------"
cd ~/contrail-ansible-deployer
ansible-playbook -e '{"CREATE_CONTAINERS":true}' -i inventory/ playbooks/deploy.yml
EOF

cat << EOF > run/post-deploy.sh
echo "-----------Post deployment-------------------------------"
cd ~/contrail-kolla-ansible/ansible
ansible-playbook -i inventory/all-in-one -e@../etc/kolla/globals.yml -e@../etc/kolla/passwords.yml -e action=deploy post-deploy.yml
ansible-playbook -i inventory/all-in-one -e@../etc/kolla/globals.yml -e@../etc/kolla/passwords.yml -e action=deploy post-deploy-contrail.yml
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

# bring up the VM
vagrant up
