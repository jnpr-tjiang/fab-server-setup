#!/bin/bash

EOF=EOF
DIR="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/user-list.cfg

print_usage() {
    echo ""
    echo "Usage: create_vm.sh [user-id] [VM OPTIONS]"
    echo ""
    echo "    VM OPTIONS:"
    echo "       --dev        : Create the Dev VM"
    echo "       --all <tag>  : Create the Contrail all-in-one VM"
    echo "       --ui         : Create the Contrail UI VM"
    echo "       --destroy    : Destroy the VM"
    echo ""
    echo "Note: Each developer is assigned with an ip range. The dev VM is created with the"
    echo "first ip in that range. For example, if your assgined range is 10.155.75.100-109, then"
    echo "dev VM is assigned 10.155.75.100."
    echo "The target VM is created with the second ip in that range."
    echo ""
    echo "Here are assigned ip ranges:"
    echo "   akshayam:   10.155.75.100 - 10.155.75.109"
    echo "   atandon:    10.155.75.110 - 10.155.75.119"
    echo "   josephw:    10.155.75.120 - 10.155.75.129"
    echo "   rtulsian:   10.155.75.130 - 10.155.75.139"
    echo "   sahanas:    10.155.75.140 - 10.155.75.149"
    echo "   svajjhala:  10.155.75.150 - 10.155.75.159"
    echo "   sjeevaraj:  10.155.75.160 - 10.155.75.169"
    echo "   supriyas:   10.155.75.170 - 10.155.75.179"
    echo "   tjiang:     10.155.75.180 - 10.155.75.189"
    echo ""

    if [ $# -eq 1 ]; then
        exit $1
    fi
    exit 1
}

generate_vagrantfile() {
    local name=$1
    local memory=$2
    local cpus=$3

    mkdir -p $DIR/"$name"_vm

    cat << EOF > $DIR/"$name"_vm/Vagrantfile
Vagrant.configure("2") do |config|
  config.vm.box = "centos/7"

  config.vm.define "$name-$user_id" do |$name|
    $name.vm.provider "virtualbox" do |v|
      v.memory = $memory
      v.cpus = $cpus
    end

    $name.vm.network "public_network", auto_config: false, bridge: '$host_interface'

    $name.vm.provision :ansible do |ansible|
      ansible.playbook = "ansible/$name.yml"
      ansible.extra_vars = {
          vm_interface: "$interface",
          vm_gateway_ip: "$gateway_ip",
          vm_ip: "$base_ip.$offset",
          ntp_server: "$ntp_server",
          contrail_version: "$tag"
      }
    end
  end
end
EOF
}

create_vm() {
    cd $DIR/"$1"_vm
    if [ $destroy -eq 1 ]; then
        vagrant destroy -f
    else
        echo "Creating $1 vm..."
        vagrant up
    fi
    cd $DIR
}

dev_vm=0
all_vm=0
ui_vm=0
destroy=0

while [ $# -gt 0 ]
do
    case "$1" in
        --dev)     dev_vm=1                           ;;
        --all)     all_vm=1; tag=$2; shift            ;;
        --ui)      ui_vm=1                            ;;
        --destroy) destroy=1                       ;;
        --help)    print_usage 0                      ;;
        -*)        echo "Error! Unknown option $1";
                   print_usage                        ;;
        *)         if [ -z "$user_id" ]; then
                       user_id="$1"
                   else
                       print_usage
                   fi                                 ;;
    esac
    shift
done

if [ -z "$user_id" ]; then
    user_id=$(whoami)
fi
if [ $dev_vm -eq 0 -a $all_vm -eq 0 -a $ui_vm -eq 0 ]; then
    print_usage
fi
if [ $all_vm -eq 1 -a -z "$tag" ]; then
    print_usage
fi

set -e
interface="eth1"
host_interface="eno1"
ntp_server=172.21.200.60
gateway_ip=$(ip route | grep default | grep $host_interface | awk '{print $3}')
base_ip=$(ip address | grep inet | grep $host_interface | awk '{print $2}' | awk -F '/' '{print $1}' | cut -d"." -f1-3)

user_offset=${!user_id}
if [ -z "$user_offset" ]; then
    echo "Error! Unknown user $user_id"
    print_usage
fi

(vagrant plugin list | grep vbguest >& /dev/null) || vagrant plugin install vagrant-vbguest
if [ $dev_vm -eq 1 ]; then
    offset=$(($user_offset * 10 + 90))
    playbook="dev.yml"
    generate_vagrantfile dev 32000 7
    create_vm dev
fi
if [ $all_vm -eq 1 ]; then
    offset=$(($user_offset * 10 + 91))
    playbook="all.yml"
    generate_vagrantfile all 64000 8
    create_vm all
fi
if [ $ui_vm -eq 1 ]; then
    offset=$(($user_offset * 10 + 95))
    playbook="ui.yml"
    generate_vagrantfile ui 4000 2
    create_vm ui
fi
