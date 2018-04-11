# cloud-init

When provisioning a new Ubuntu 16.04 server on the cloud, write the following code in the **User data** field at your cloud service provider provisioning page. This is applicable for both AWS EC2 & DigitalOcean Droplet instances:

```shell
#cloud-config
fqdn: rinvex.localdomain
hostname: rinvex
manage_etc_hosts: true
system_info:
  default_user:
    name: rinvex
power_state:
  delay: "now"
  mode: reboot
runcmd:
  - wget https://raw.githubusercontent.com/rinvex/cloudinit/develop/commands.sh
  - chmod +x commands.sh
  - ./commands.sh
  - wget https://raw.githubusercontent.com/rinvex/cloudinit/develop/provision.sh
  - chmod +x provision.sh
  - ./provision.sh
```

> **Notes:**

> 1. Some configurations has been ommitted since the default AWS Ubuntu AMI, and the default DigitalOcean Ubuntu Droplet has these config by default.
> 2. Notice that the provisioning script uses **rinvex** as a default user system-wide, change if required.
> 3. This is intended to be just web server, that's why no database or other software config included.
> 4. Tested only in AWS EC2 Ubuntu 16.04, but should work with DigitalOcean droplets as well.
> 5. Log file found on provisioned server here: `/var/log/cloud-init-output.log`
> 6. References: 
>   - http://cloudinit.readthedocs.io/en/latest/topics/examples.html
>   - http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/user-data.html
>   - http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-metadata.html
>   - https://www.digitalocean.com/community/tutorials/an-introduction-to-droplet-metadata
>   - https://www.digitalocean.com/community/tutorials/an-introduction-to-cloud-config-scripting
>   - https://www.digitalocean.com/community/tutorials/how-to-use-cloud-config-for-your-initial-server-setup
