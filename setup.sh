#!/bin/bash 

if [ $# != 1 ]; then
  echo "Usage: setup.sh <tag-name>"
  return 1
fi

tag=$1

cat << EOF > /etc/resolv.conf
nameserver 10.155.191.252
nameserver 172.21.200.60
search englab.juniper.net spglab.juniper.net jnpr.net juniper.net
EOF

yum -y install epel-release
yum -y remove python-jinja2
yum -y install centos-release-openstack-ocata
yum -y install ansible-2.3.1.0
yum -y install python-oslo-config
yum -y install git
yum -y install net-tools
yum -y install wget
yum -y install python-pip
pip install --upgrade Jinja2
pip install --upgrade pip

modprobe ip_vs

cd 
if [ -d contrail-kolla-ansible ]; then
  rm -rf contrail-kolla-ansible
fi
git clone https://github.com/Juniper/contrail-kolla-ansible.git
cd contrail-kolla-ansible && git checkout contrail/ocata

ip=$(ip address|grep inet|grep eno1|awk '{print $2}'|awk -F '/' '{print $1}')
interface=$(ip address|grep inet|grep eno1|awk '{print $NF}')

cat << EOF > etc/kolla/globals.yml
kolla_internal_vip_address: "$ip"
kolla_external_vip_address: "$ip"
contrail_api_interface_address: "$ip"
network_interface: "$interface"
kolla_external_vip_interface: "$interface"

neutron_opencontrail_init_image_full: "opencontrailnightly/contrail-openstack-neutron-init:$tag"
nova_compute_opencontrail_init_image_full: "opencontrailnightly/contrail-openstack-compute-init:$tag"

openstack_release: "4.0.0"
neutron_plugin_agent: "opencontrail"
enable_haproxy: "no"
EOF

cd ~/contrail-kolla-ansible/ansible
ansible-playbook -i inventory/all-in-one -e@../etc/kolla/globals.yml -e@../etc/kolla/passwords.yml -e action=bootstrap-servers kolla-host.yml

cd
if [ -d contrail-ansible-deployer ]; then
  rm -rf contrail-ansible-deployer
fi
git clone http://github.com/Juniper/contrail-ansible-deployer
cd contrail-ansible-deployer

cat << EOF > inventory/hosts
container_hosts:
  hosts:
    $ip:
      ansible_connection: local
EOF

cat << EOF > inventory/group_vars/container_hosts.yml
contrail_configuration:
  CONTAINER_REGISTRY: opencontrailnightly
  CONTRAIL_VERSION: $tag
  CONTROLLER_NODES: $ip
  CLOUD_ORCHESTRATOR: openstack
  AUTH_MODE: keystone
  KEYSTONE_AUTH_ADMIN_PASSWORD: c0ntrail123
  KEYSTONE_AUTH_HOST: $ip
  KEYSTONE_AUTH_URL_VERSION: "/v3"
  RABBITMQ_NODE_PORT: 5673
  PHYSICAL_INTERFACE: eth0
  VROUTER_GATEWAY: 10.155.95.254
roles:
  $ip:
    config_database:
    config:
    control:
    webui:
    analytics:
    analytics_database:
    vrouter:
EOF

ansible-playbook -e '{"CONFIGURE_VMS":true}' -e '{"CONTAINER_VM_CONFIG":{"network":{"ntpserver":"172.21.200.60"}}}' -t configure_vms -i inventory/ playbooks/deploy.yml

cd ~/contrail-kolla-ansible/ansible
ansible-playbook -i inventory/all-in-one -e@../etc/kolla/globals.yml -e@../etc/kolla/passwords.yml -e action=deploy site.yml

cd ~/contrail-ansible-deployer
ansible-playbook -e '{"CREATE_CONTAINERS":true}' -i inventory/ playbooks/deploy.yml

cd ~/contrail-kolla-ansible/ansible
ansible-playbook -i inventory/all-in-one -e@../etc/kolla/globals.yml -e@../etc/kolla/passwords.yml -e action=deploy post-deploy.yml
ansible-playbook -i inventory/all-in-one -e@../etc/kolla/globals.yml -e@../etc/kolla/passwords.yml -e action=deploy post-deploy-contrail.yml

source /etc/kolla/admin-openrc.sh
openstack network list
openstack image list
