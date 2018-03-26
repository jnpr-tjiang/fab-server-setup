#!/bin/bash
pip install jmespath
pip install junos-eznc --upgrade
ansible-galaxy install Juniper.junos
pip install jxmlease
pip install requests
pip install python-swiftclient
pip install python-keystoneclient
pip install pysnmp
pip install inflection

sed -i -e '/host_key_checking/c\host_key_checking = False' -e '/log_path/c\log_path = /var/log/ansible.log' /etc/ansible/ansible.cfg
