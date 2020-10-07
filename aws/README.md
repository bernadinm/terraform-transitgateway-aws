# Transit Gateway Module

This repository makes use of how to use a single transit gateway and define the running allowed vpc attachemnts and direct connection associations to transit gateway interface.

# Usage

The behavior of how this TGW Central module is intended to be used is that all attachments must be created first before adding it to the transit gateway central module. If you want 

## Transit Gateway Central Module

### Example Usage



```hcl
module "tgw" {
  source  = "./aws"

  name                    = "tgw-eu-west-1"
  description             = "EU-WEST-1 Transit Gateway"
  amazon_side_asn         = 65534
  create_tgw              = true
  enable_auto_accept_shared_attachments = true
  enable_default_route_table_association = false
  enable_default_route_table_propagation = false

  ram_allow_external_principals = true
  ram_principals = [662839120368]

  route_tables = {
    test_vpc_only_rtb = {
      associations = {
        test = {
          attachment_id = "tgw-attach-0a15abd40d8619bb1" # TEST VPC
        }
      },
      propagations = {
        test = {
          attachment_id = "tgw-attach-0a15abd40d8619bb1" # TEST VPC
        }
      },
      static_routes = {
        dx = {
          destination_cidr_block = "10.0.0.0/8"
          blackhole  =  false
          attachment_id = "tgw-attach-0a15abd40d8619bb1" # Direct Connect
        }
      }
    },
    shared_vpc_dx_rtb = {
      associations = {
        dx = {
          attachment_id = "tgw-attach-028b6c96eada6e77b" # Direct Connect
        }
      },
      propagations = {
        quentin-test = {
          attachment_id = "tgw-attach-0310b97e0dde44576" # Quentin attachment test
        },
        test = {
          attachment_id = "tgw-attach-0a15abd40d8619bb1" # TEST VPC
        },
        dx = {
          attachment_id = "tgw-attach-028b6c96eada6e77b" # Direct Connect
        }
      },
      static_routes = {
        dx = {
          destination_cidr_block = "10.0.0.0/8"
          blackhole  = true
          attachment_id = "tgw-attach-0a15abd40d8619bb1" # Direct Connect
        }
      }
    }
  }

  dx_associations = {
    san_francisco_direct_connect = {
      dx_id = aws_dx_gateway.sf-megaport-equinix-dc.id

      allowed_prefixes = [
        "172.29.255.0/24"  # SEC SF DC
      ]
    }
  }

  tags = {
    Purpose = "tgw-eu-west-1"
  }
}

output "tgw_id" {
  value = module.tgw.this_ec2_transit_gateway_id
}

output "tgw_route_table_id" {
  value = module.tgw.this_ec2_transit_gateway_route_table_id
}

output "tgw_share_arn" {
  value = module.tgw.this_ram_resource_share_id
}
```

## Transit Gateway Client Module

Here is an example below on how you can use the client module to create attachments that can be used on the transit gateway on the subsequent apply.

### Example Usage

```hcl

variable "transit_gateway_id" {
  default = "tgw-05fce14b98b3e9db5"
}

variable "vpc_id" {
  default = "vpc-<insert-yours-here>" # if do not have own resource to reference
}

/*
* VPC Attachment
*/

data "aws_subnet_ids" "subnet" {
  vpc_id = <aws_vpc.default.id or var.vpc_id> # reference or use static variable
}

data "aws_subnet" "subnet" {
  for_each = data.aws_subnet_ids.subnet.ids
  id       = each.value
}

locals {
  single_subnet_per_az = [ for k, v in { for subnet in data.aws_subnet.subnet : subnet.availability_zone => subnet.id... } : v[0] ]
}

module "tgw" {
  source = "./aws"
  name = "nameyourenvironment"
  transit_gateway_id = var.transit_gateway_id

  vpc_attachments = {
    default = {
      vpc_id       = <aws_vpc.default.id or var.vpc_id> # reference or use static variable
      subnet_ids   = local.single_subnet_per_az
      dns_support  = true
      ipv6_support = false
    }
  }

  tags = {
    Purpose = "nameyourenvironment"
  }
}
```

### VPC Usage Example

To have the VPC send the traffic based on a CIDR block to the transit gateway, it needs to know what range to identify to forward the packets to the transit gateway. It is recommended to use an `aws_route` resources rather then defining it within the `aws_route_table` as an inline block. It is recommended to use a `for_each` if you need multiple routes instead of using the `count` method.

```hcl
/*
* VPC Route Table Rules
*/

resource "aws_route" "tgw_class_a" {
  for_each                    = toset(concat(aws_route_table.private.*.id, aws_route_table.public.*.id))
  route_table_id              = each.value
  destination_cidr_block      = "10.0.0.0/8"
  transit_gateway_id          = var.transit_gateway_id
}
resource "aws_route" "tgw_class_b" {
  for_each                    = toset(concat(aws_route_table.private.*.id, aws_route_table.public.*.id))
  route_table_id              = each.value
  destination_cidr_block      = "172.16.0.0/12"
  transit_gateway_id          = var.transit_gateway_id
}
resource "aws_route" "tgw_class_c" {
  for_each                    = toset(concat(aws_route_table.private.*.id, aws_route_table.public.*.id))
  route_table_id              = each.value
  destination_cidr_block      = "192.168.0.0/16"
  transit_gateway_id          = var.transit_gateway_id
}
```

### Direct Connect and VPN Connections

In order for DX and VPN connectivity you need to run this on the same account as the AWS Transit Gateway.
```hcl
/*
*  DIRECT CONNECT (ATTACH BY DX ID)
*/

resource "aws_dx_gateway" "sf-megaport-equinix-dc" {
  name            = "SanFran-Megaport-Equinix-DC"
  amazon_side_asn = "64512"
}

output "sf-megaport-equinix-dc" {
  value = aws_dx_gateway.sf-megaport-equinix-dc.id
}

/*
* VPN CONNECTION (CREATES ATTACHMENT)
*/

resource "aws_vpn_connection" "sf-dc" {
  transit_gateway_id  = "tgw-0e720f08abe17a239"
  customer_gateway_id = "${aws_customer_gateway.customer_gateway.id}"
  type                = "ipsec.1"
}
```

