fab-server setup
================
![fab-server](images/fab-server.png)

## Contrail developer sandbox
Attach to the developer sandbox and build contrail:
```
$ docker ps 
$ docker attach contrail-developer-sandbox
$ cd contrail
$ scons --kernel-dir=$KERNELDIR
```
To start the sandbox VM if it is down. 
```
$ cd contrail-dev-env
$ sh startup.sh
```
Once you attach to the sandbox container, there is only one shell to work with. So it is recommended to use tmux so that you can have multiple shells. Here are the tmux cheatsheet:
```
ctrl-a w  # list all windows
ctrl-a c  # create a new window
ctrl-a d  # detach from tmux
ctrl-a n  # go to next window
ctrl-a p  # go to previous window
ctrl-a 1  # go to the first window
```

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
To access the VM from the fab-server:
```
$ cd /root/fab-server-setup
$ vagrant ssh
```
The VM ip is based on the fab-server name. 
- `fab-server02:  10.155.75.22`
- `fab-server04:  10.155.75.24`
- `fab-server05:  10.155.75.25`
- `fab-server06:  10.155.75.26`
- `fab-server07:  10.155.75.27`
- `fab-server08:  10.155.75.28`
- IP for the VM on fab-server09:  10.155.75.29

## Re-image fab-server
To re-image a fab-server, you need go to fab-server03 and run the following commnands:
```
$ cd /root/fab-server-setup/fab-server
$ ansible-playbook --extra-vars server=<fab server name> provision_fab_server.yml 
```
Here are the valid fab server names: 
- `ab-server02`
- `ab-server04`
- `ab-server05`
- `ab-server06`
- `ab-server07`
- `ab-server08`
- `ab-server09`
