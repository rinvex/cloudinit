# cloud-init

When provisioning a new Ubuntu 16.04 server on the cloud, write the following code in the **User data** field at your cloud service provider provisioning page. This is applicable for both AWS EC2 & DigitalOcean Droplet instances:

```shell
#cloud-config
fqdn: coworkit.localdomain
hostname: coworkit
manage_etc_hosts: true
system_info:
  default_user:
    name: coworkit
power_state:
  delay: "now"
  mode: reboot
runcmd:
  - wget https://raw.githubusercontent.com/rinvex/cloudinit/coworkit/commands.sh
  - chmod +x commands.sh
  - ./commands.sh
  - wget https://raw.githubusercontent.com/rinvex/cloudinit/coworkit/provision.sh
  - chmod +x provision.sh
  - ./provision.sh
ssh_authorized_keys:
  - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCejl6eLn4Fc5i+huFDsDZvUFDOaoZCrU9xdErfjaYZW3RKRANPDDQcy+hdkPlxGFDiJQ7cqZEpQxsYkFi9YZr2VtCWV4J3OTqUK2LFCk3Dm76IIXpYABvBSTy6Mo9AYrAZVDvKE5qj4KZGzUkRug1dx7HGji2B4io52cadHrYZg8m+l+H17sqSWeaY8KYybiPPh5lILpMpZjSIVJyvRG2XOAkWFuhk8SQH1riqBGbQ1EN9WzBpEyUg35iKTWEMolWELYadUNLkIzF+CV9xUB7CYoWd9BHLBa4D90KZtdrNUJiWtUa73l8L4yjPR7JxGKnMz7rOrCKd67aiIup6MFqy/DOvQ0u+nyoHP9DQ2ywDw/F+G6uFEi5MjeTLoV/ZmvMA9QMrgGmcE5gqVwqaE3um9UxT42keSo66LrdqpQMQr044NU1wG1A0laJxpTnxM24WsW6T3a3OYjFiSH2hqZJ3iQHq/MPEgta2qf7tJM8DkySI2rb1p7geVG1rN1lhstemh/DBXs0iUWiNxX56QVYtHjgFjeXWHDBotacM8KKLt2s26RxOrHmw1sI7Ej/1KTMhYpJap5QBF60X1pglJiGUhTnl0lOg0ECbWwQIPQuktfargG8HUXTYFTXH22YzDiwJBVFB/k1X23hTif35qNW8TABim5gACDYtAwYjota5vQ== me+gitlab-coworkit@omranic.com
```

> **Notes:**

> 1. Some configurations has been ommitted since the default AWS Ubuntu AMI, and the default DigitalOcean Ubuntu Droplet has these config by default.
> 2. Notice that the provisioning script uses **coworkit** as a default user system-wide, change if required.
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
