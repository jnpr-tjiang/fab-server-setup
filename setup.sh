#!/bin/bash 

if [ $# != 1 ]; then
  echo "Usage: setup.sh <tag-name>"
  echo "Note: contrail nightly build tag must be provided. The latest nightly build tag can be"
  echo "found at https://hub.docker.com/r/opencontrailnightly/contrail-openstack-neutron-init/tags"
  exit 1
fi

# initialize variables
tag=$1
interface=eth1
ip=$(ip address|grep inet|grep eno1|awk '{print $2}'|awk -F '/' '{print $1}'|awk -F '.' -v x=$(($(hostname|cut -b 11-) + 20)) '{print $1"."$2"."$3"."x}')
gateway_ip=$(ip route | grep default | awk '{print $3}')
ntp_server=172.21.200.60
EOF=EOF

# generate vagrant file for the contrail VM
cat << EOF > Vagrantfile
Vagrant.configure("2") do |config|
  config.vm.box = "centos/7"
  config.vm.provider "virtualbox" do |v|
    v.memory = 102400
    v.cpus = 24
  end

  config.vm.network "public_network", auto_config: false, bridge: 'eno1'

  config.vm.provision :shell do |shell|
    shell.path = "/tmp/init.sh"
  end

  config.vm.provision :ansible do |ansible|
    ansible.playbook = "ansible-provisioner/provision.yml"
  end

  config.vm.provision :shell do |shell|
    shell.path = "/tmp/kolla-bootstrap.sh"
  end

  config.vm.provision :shell do |shell|
    shell.path = "/tmp/ntp.sh"
  end

  config.vm.provision :shell do |shell|
    shell.path = "/tmp/deploy-kolla.sh"
  end

  config.vm.provision :shell do |shell|
    shell.path = "/tmp/deploy-contrail.sh"
  end

  config.vm.provision :shell do |shell|
    shell.path = "/tmp/post-deploy.sh"
  end
end
EOF

# generate the standup script to be invoked after the VM is spawned
cat << EOF > /tmp/init.sh
# configure interface $interface
cat << EOF > /etc/sysconfig/network-scripts/ifcfg-$interface
DEVICE="$interface"
BOOTPROTO="static"
ONBOOT="yes"
TYPE="Ethernet"
IPADDR=$ip
NETMASK=255.255.224.0
GATEWAY=$gateway_ip
DNS1=10.155.191.252
DNS2=172.21.200.60
DOMAIN=englab.juniper.net spglab.juniper.net jnpr.net juniper.net
$EOF
systemctl restart network.service
EOF

# generate script to invoke contrail deployment playbooks
cat << EOF > /tmp/ntp.sh
echo "-----------Configure NTP---------------------------------"
cd /root/contrail-ansible-deployer
ansible-playbook -e '{"CONFIGURE_VMS":true}' -e '{"CONTAINER_VM_CONFIG":{"network":{"ntpserver":"$ntp_server"}}}' -t configure_vms -i inventory/ playbooks/deploy.yml
EOF

cat << EOF > /tmp/kolla-bootstrap.sh
echo "-----------Kolla Bootstrap-------------------------------"
cd /root/contrail-kolla-ansible/ansible
ansible-playbook -i inventory/all-in-one -e@../etc/kolla/globals.yml -e@../etc/kolla/passwords.yml -e action=bootstrap-servers kolla-host.yml
EOF

cat << EOF > /tmp/deploy-kolla.sh
echo "-----------Install contrail kolla containers-------------"
cd /root/contrail-kolla-ansible/ansible
ansible-playbook -i inventory/all-in-one -e@../etc/kolla/globals.yml -e@../etc/kolla/passwords.yml -e action=deploy site.yml
EOF

cat << EOF > /tmp/deploy-contrail.sh
echo "-----------Install contrail containers-------------------"
cd ~/contrail-ansible-deployer
ansible-playbook -e '{"CREATE_CONTAINERS":true}' -i inventory/ playbooks/deploy.yml
EOF

cat << EOF > /tmp/post-deploy.sh
echo "-----------Post deployment-------------------------------"
cd ~/contrail-kolla-ansible/ansible
ansible-playbook -i inventory/all-in-one -e@../etc/kolla/globals.yml -e@../etc/kolla/passwords.yml -e action=deploy post-deploy.yml
ansible-playbook -i inventory/all-in-one -e@../etc/kolla/globals.yml -e@../etc/kolla/passwords.yml -e action=deploy post-deploy-contrail.yml
EOF

# update group_vars/all.yml
cat << EOF > ansible-provisioner/group_vars/all.yml
all_in_one_node: "$ip"
interface_name: "$interface"
container_registry: "opencontrailnightly"
contrail_version: "$tag"
ntp_server: "$ntp_server"
gateway_ip: "$gateway_ip"
EOF

# bring up the VM
timespent=$(time vagrant up)
echo "***********************************************************"
echo "* Total Time Spent: $timespent"
echo "***********************************************************"
