variable "admin_access_ip" { default = "73.71.5.56/32" }

module "tgw" {
  source = "./aws"

  name            = "testing-tgw"
  description     = "EU-WEST-1 Testing Transit Gateway"
  amazon_side_asn = 65534
  share_tgw       = false
  create_tgw      = true

 route_tables = {
   vpn = {
     associations = {
       vpn = {
         attachment_id = module.tgw_client.this_ec2_transit_gateway_vpc_attachment_ids[0] #VPN
       }
     },
     propagations = {
       vpn2 = {
         attachment_id = module.tgw_client.this_ec2_transit_gateway_vpc_attachment_ids[1] #VPN
       }
     },
     static_routes = {}
   },
   vpn2 = {
     associations = {
       vpn2 = {
         attachment_id = module.tgw_client.this_ec2_transit_gateway_vpc_attachment_ids[1] #VPN
       }
     },
     propagations = {
       vpn = {
         attachment_id = module.tgw_client.this_ec2_transit_gateway_vpc_attachment_ids[0] #VPN
       }
     },
     static_routes = {}
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

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 2.0"

  name = "miguel-bernadin-delete-me-test-transit-gateway"

  cidr = "10.10.0.0/16"

  azs             = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  private_subnets = ["10.10.1.0/24", "10.10.2.0/24", "10.10.3.0/24"]

  enable_ipv6                                    = true
  enable_dns_hostnames                           = true
  enable_dns_support                             = true
  private_subnet_assign_ipv6_address_on_creation = true
  private_subnet_ipv6_prefixes                   = [0, 1, 2]
}

module "vpc2" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 2.0"

  name = "miguel-bernadin-delete-me-test-transit-gateway-2"

  cidr = "10.20.0.0/16"

  azs             = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  private_subnets = ["10.20.1.0/24", "10.20.2.0/24", "10.20.3.0/24"]

  enable_ipv6                                    = true
  enable_dns_hostnames                           = true
  enable_dns_support                             = true
  private_subnet_assign_ipv6_address_on_creation = true
  private_subnet_ipv6_prefixes                   = [0, 1, 2]
}

variable "tgw_enabled" { default = true }

variable "transit_gateway_id" {
  default = "tgw-05fce14b98b3e9db5"
}

/*
* VPC Attachment
*/

locals {
  single_subnet_per_az_vpc  = module.vpc.private_subnets
  single_subnet_per_az_vpc2 = module.vpc2.private_subnets
}

module "tgw_client" {
  source = "./aws"
  name               = "testing-tgw-performance"
  transit_gateway_id = module.tgw.this_ec2_transit_gateway_id

  vpc_attachments = {
    vpc = {
      vpc_id       = module.vpc.vpc_id
      subnet_ids   = local.single_subnet_per_az_vpc
      dns_support  = true
      ipv6_support = false
    }
    vpc2 = {
      vpc_id       = module.vpc2.vpc_id
      subnet_ids   = local.single_subnet_per_az_vpc2
      dns_support  = true
      ipv6_support = false
    }
  }

  tags = {
    Purpose = "alvarez-marsal-analytics-tgw"
  }
}

/*
* VPC Route Table Rules
*/

resource "aws_route" "tgw_class_a" {
  count                  = length(module.vpc.private_route_table_ids)
  route_table_id         = module.vpc.private_route_table_ids[count.index]
  destination_cidr_block = "10.0.0.0/8"
  transit_gateway_id     = module.tgw.this_ec2_transit_gateway_id

  depends_on = [module.tgw]
}
resource "aws_route" "tgw_class_b" {
  count                  = length(module.vpc.private_route_table_ids)
  route_table_id         = module.vpc.private_route_table_ids[count.index]
  destination_cidr_block = "172.16.0.0/12"
  transit_gateway_id     = module.tgw.this_ec2_transit_gateway_id

  depends_on = [module.tgw]
}
resource "aws_route" "tgw_class_c" {
  count                  = length(module.vpc.private_route_table_ids)
  route_table_id         = module.vpc.private_route_table_ids[count.index]
  destination_cidr_block = "192.168.0.0/16"
  transit_gateway_id     = module.tgw.this_ec2_transit_gateway_id

  depends_on = [module.tgw]
}

/*
* VPC Route Table Rules
*/

resource "aws_route" "tgw_class_a2" {
  count                  = length(module.vpc2.private_route_table_ids)
  route_table_id         = module.vpc2.private_route_table_ids[count.index]
  destination_cidr_block = "10.0.0.0/8"
  transit_gateway_id     = module.tgw.this_ec2_transit_gateway_id

  depends_on = [module.tgw]
}
resource "aws_route" "tgw_class_b2" {
  count                  = length(module.vpc2.private_route_table_ids)
  route_table_id         = module.vpc2.private_route_table_ids[count.index]
  destination_cidr_block = "172.16.0.0/12"
  transit_gateway_id     = module.tgw.this_ec2_transit_gateway_id

  depends_on = [module.tgw]
}
resource "aws_route" "tgw_class_c2" {
  count                  = length(module.vpc2.private_route_table_ids)
  route_table_id         = module.vpc2.private_route_table_ids[count.index]
  destination_cidr_block = "192.168.0.0/16"
  transit_gateway_id     = module.tgw.this_ec2_transit_gateway_id

  depends_on = [module.tgw]
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-trusty-14.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_security_group" "allow_ssh_vpc2" {
  name        = "allow_ssh"
  description = "Allow ssh inbound traffic"
  vpc_id      = module.vpc2.vpc_id

  ingress {
    description = "All internal"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/8"]
  }

  ingress {
    description = "All from VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.admin_access_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_ssh"
  }
}
resource "aws_security_group" "allow_ssh_vpc" {
  name        = "allow_ssh"
  description = "Allow ssh inbound traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "All internal"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/8"]
  }

  ingress {
    description = "All from VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.admin_access_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_ssh"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = module.vpc.vpc_id

  tags = {
    Name = "main"
  }
}

resource "aws_internet_gateway" "gw2" {
  vpc_id = module.vpc2.vpc_id

  tags = {
    Name = "main"
  }
}


# Create a route
resource "aws_route" "r_gw" {
  count                  = length(module.vpc.private_route_table_ids)
  route_table_id         = module.vpc.private_route_table_ids[count.index]
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}


# Create a route
resource "aws_route" "r2_gw" {
  count                  = length(module.vpc2.private_route_table_ids)
  route_table_id         = module.vpc2.private_route_table_ids[count.index]
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw2.id
}

resource "aws_instance" "vpc" {
  ami                         = data.aws_ami.ubuntu.id
  subnet_id                   = module.vpc.private_subnets[0]
  instance_type               = "t2.micro"
  user_data                   = file("user-data.txt")
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.allow_ssh_vpc.id]


  tags = {
    Name = "instance1-tgw-test"
  }
}

resource "aws_instance" "vpc2" {
  ami                         = data.aws_ami.ubuntu.id
  subnet_id                   = module.vpc2.private_subnets[0]
  instance_type               = "t2.micro"
  user_data                   = file("user-data.txt")
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.allow_ssh_vpc2.id]

  tags = {
    Name = "instance2-tgw-test"
  }
}

output "allowed_outside_range_ip" {
  value = [var.admin_access_ip]
}

output "instance1" {
  value = [aws_instance.vpc.public_ip, aws_instance.vpc.private_ip]
}
output "instance2" {
  value = [aws_instance.vpc2.public_ip, aws_instance.vpc2.private_ip]
}
