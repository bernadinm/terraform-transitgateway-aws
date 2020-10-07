# Transit Gateway VPC Automated Connectivity

This codebase leverages a custom made transit gateway module that allows for a more dynamic and safe interface for using the transit gateway for production use. This shows an example on how you can deploy two VPCs and have them communiate to each other using the transit gateway.

## How to Use

### Provide `admin_access_ip` variable

In order for you to access your instances via ssh, you need to allow your public ip to talk to the vpcs.

In the tgw.tf file, edit your variable `admin_access_ip` to your own. 

### Provide your ssh key in `user-data.txt`

In order for you to ssh, you need your keys to be sent and installed on your machines. Add your ssh pub key in the user-data.txt file.

The default operating system is ubuntu. To ssh, the example command is `ssh ubuntu@<public-ip>`

### Deploy TGW

Simply run:

```bash
terraform apply
```

### Shutdown TGW

Simply run:

```bash
terraform destroy
```
