fab-server setup
================
![fab-server](images/fab-server.png)

## Contrail VM
Here are the steps to create target VM loaded with Contrail nightly build:
1. Destroy the existing vagrant VM
```
$ cd /root/fab-server-setup
$ vagrant destroy
```
2. Go to https://hub.docker.com/r/opencontrailnightly/contrail-openstack-neutron-init/tags/ and copy the tag name for the nightly build.
3. Run `vmcreate.sh` script to spawn the VM loaded with the nightly build
```
$ cd /root/fab-server-setup
$ sh vmcreate.sh <tag name>
```

#### How do I access the VM?
The VM ip is based on the fab-server name. If the fab server name is fab-server07, then IP for the contrail VM is 10.155.75.27. 
- fab-server02:  10.155.75.22
- fab-server04:  10.155.75.24
- fab-server05:  10.155.75.25
- fab-server06:  10.155.75.26
- fab-server07:  10.155.75.27
- fab-server08:  10.155.75.28
- fab-server09:  10.155.75.29


