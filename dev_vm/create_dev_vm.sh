#!/bin/bash 

if [ $# != 1 ]; then
  echo "Usage: create_dev_vm.sh <dev_vm_ip>"
  echo "Note: Each developer is assigned with an ip range. You should choose the first ip in the"
  echo "range as your dev VM IP. For example, if your assgined range is 10.155.75.40-49, then"
  echo "use 10.155.75.40 as your dev VM IP."
  echo ""
  echo "Here are assigned ip ranges:"
  echo "   Ankur:   10.155.75.40 - 10.155.75.49"
  echo "   Sirisha: 10.155.75.50 - 10.155.75.59"
  echo "   Sahana:  10.155.75.60 - 10.155.75.69"
  echo "   Supriya: 10.155.75.70 - 10.155.75.79"
  echo "   Tong:    10.155.75.80 - 10.155.75.89"
  echo "   Rishabh: 10.155.75.90 - 10.155.75.99"
  echo "   Sridevi: 10.155.75.100 - 10.155.75.109"
  echo "   Joe:     10.155.75.110 - 10.155.75.119"
  echo "   Akshaya: 10.155.75.120 - 10.155.75.129"
  echo ""
  exit 1
fi

# initialize variables
interface=eth1
#dev_vm_ip=$(ip address|grep inet|grep eno1|awk '{print $2}'|awk -F '/' '{print $1}'|awk -F '.' -v x=$(expr $(hostname|cut -b 11-) + 20) '{print $1"."$2"."$3"."x}')
dev_vm_ip=$1
gateway_ip=$(ip route | grep default | awk '{print $3}')
EOF=EOF

script_dir=/tmp/$dev_vm_ip
mkdir -p $script_dir

# generate vagrant file for the contrail VM
cat << EOF > Vagrantfile
Vagrant.configure("2") do |config|
  config.vm.box = "centos/7"

  config.vm.define "dev" do |dev|
    dev.vm.provider "virtualbox" do |v|
      v.memory=32000
      v.cpus = 7
    end

    dev.vm.network "public_network", auto_config: false, bridge: 'eno1'

    dev.vm.provision :shell do |shell|
      shell.path="$script_dir/dev-vm-init.sh"
    end

    dev.vm.provision :ansible do |ansible|
      ansible.playbook = "provision_dev_vm.yml"
    end

    dev.vm.provision :shell do |shell|
      shell.path = "$script_dir/authorized-keys.sh"
    end
  end
end
EOF

# generate the standup script to be invoked after the dev VM is spawned
cat << EOF > $script_dir/dev-vm-init.sh
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

# add authorized keys
authorized_keys=$(cat ~/.ssh/authorized_keys)
cat << EOF > $script_dir/authorized-keys.sh
sudo mkdir -p /root/.ssh
sudo echo "$authorized_keys" >> /root/.ssh/authorized_keys
EOF

# bring up the VM
vagrant plugin install vagrant-vbguest
vagrant up
