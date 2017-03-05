# cloud-init

```shell
#cloud-config
system_info:
  default_user:
    name: rinvex
runcmd:
  - wget https://raw.githubusercontent.com/rinvex/cloudinit/master/provision.sh
  - chmod +x provision.sh
  - ./provision.sh
```
