locals {
  // List of maps with key and propagations
  propagations = flatten([
    for rtb_key, rtb in var.route_tables : [
      for propagations_key, propagations in rtb.propagations : {
        rtb_key = rtb_key
        propagations_key  = propagations_key
        attachment_id = propagations.attachment_id
        routing_table_id = aws_ec2_transit_gateway_route_table.this[rtb_key].id
      }
    ]
  ])

  // List of maps with key and associations
  associations = flatten([
    for rtb_key, rtb in var.route_tables : [
      for associations_key, associations in rtb.associations : {
        rtb_key = rtb_key
        associations_key  = associations_key
        attachment_id = associations.attachment_id
        routing_table_id = aws_ec2_transit_gateway_route_table.this[rtb_key].id
      }
    ]
  ])

  // List of maps with key and route values
  static_routes = flatten([
    for rtb_key, rtb in var.route_tables : [
      for routes_key, routes in rtb.static_routes : {
        rtb_key = rtb_key
        routes_key  = routes_key
        destination_cidr_block = routes.destination_cidr_block
        blackhole = routes.blackhole
        attachment_id = routes.attachment_id
        routing_table_id = aws_ec2_transit_gateway_route_table.this[rtb_key].id
      }
    ]
  ])

  depends_on_acceptor = var.transit_gateway_share_arn == null ? null : aws_ram_resource_share_accepter.receiver_accept.*.id
}

resource "aws_ec2_transit_gateway" "this" {
  count = var.create_tgw ? 1 : 0

  description                     = coalesce(var.description, var.name)
  amazon_side_asn                 = var.amazon_side_asn
  default_route_table_association = var.enable_default_route_table_association ? "enable" : "disable"
  default_route_table_propagation = var.enable_default_route_table_propagation ? "enable" : "disable"
  auto_accept_shared_attachments  = var.enable_auto_accept_shared_attachments ? "enable" : "disable"
  vpn_ecmp_support                = var.enable_vpn_ecmp_support ? "enable" : "disable"
  dns_support                     = var.enable_dns_support ? "enable" : "disable"

  tags = merge(
    {
      "Name" = format("%s", var.name)
    },
    var.tags,
    var.tgw_tags,
    var.default_tags,
  )
}

/*
* Route table and routes
*/
resource "aws_ec2_transit_gateway_route_table" "this" {
  for_each = var.route_tables

  transit_gateway_id = aws_ec2_transit_gateway.this[0].id

  tags = merge(
    {
      "Name" = format("%s", each.key)
    },
    var.tags,
    var.tgw_route_table_tags,
    var.default_tags,
  )
}

// VPC attachment routes
resource "aws_ec2_transit_gateway_route" "this" {
  for_each = {
    for routes in local.static_routes : "${routes.rtb_key}.${routes.routes_key}" => routes
  }

  destination_cidr_block         = each.value.destination_cidr_block
  blackhole                      = each.value.blackhole
  transit_gateway_attachment_id  = each.value.blackhole ? null : each.value.attachment_id
  transit_gateway_route_table_id = each.value.routing_table_id
}

// VPC attachment associations
resource "aws_ec2_transit_gateway_route_table_association" "this" {
  for_each = {
    for associations in local.associations : "${associations.rtb_key}.${associations.associations_key}" => associations
  }

  transit_gateway_route_table_id = each.value.routing_table_id
  transit_gateway_attachment_id  = each.value.attachment_id
}

// VPC attachment propagations
resource "aws_ec2_transit_gateway_route_table_propagation" "this" {
  for_each = {
    for propagations in local.propagations : "${propagations.rtb_key}.${propagations.propagations_key}" => propagations
  }

  transit_gateway_route_table_id = each.value.routing_table_id
  transit_gateway_attachment_id  = each.value.attachment_id
}

/*
* VPC Attachments, route table association and propagation
*/

resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  for_each = var.vpc_attachments

  transit_gateway_id = lookup(each.value, "tgw_id", var.create_tgw ? aws_ec2_transit_gateway.this[0].id : var.transit_gateway_id)
  vpc_id             = each.value["vpc_id"]
  subnet_ids         = each.value["subnet_ids"]

  dns_support                                     = lookup(each.value, "dns_support", true) ? "enable" : "disable"
  ipv6_support                                    = lookup(each.value, "ipv6_support", false) ? "enable" : "disable"
  transit_gateway_default_route_table_association = lookup(each.value, "transit_gateway_default_route_table_association", false)
  transit_gateway_default_route_table_propagation = lookup(each.value, "transit_gateway_default_route_table_propagation", false)

  tags = merge(
    {
      Name = format("%s-%s", var.name, each.key)
    },
    var.tags,
    var.tgw_vpc_attachment_tags,
    var.default_tags,
  )

  depends_on = [
     local.depends_on_acceptor
  ]
}


/*
* DX Attachments, route table association and propagation
*/
resource "aws_dx_gateway_association" "this" {
  for_each = var.dx_associations

  dx_gateway_id         = each.value["dx_id"]
  
  associated_gateway_id = lookup(each.value, "tgw_id", aws_ec2_transit_gateway.this[0].id)
  allowed_prefixes      = each.value["allowed_prefixes"]

  depends_on = [
     local.depends_on_acceptor
  ]
}

/*
* Resource Access Manager
*/
resource "aws_ram_resource_share" "this" {
  count = var.create_tgw && var.share_tgw ? 1 : 0

  name                      = coalesce(var.ram_name, var.name)
  allow_external_principals = var.ram_allow_external_principals

  tags = merge(
    {
      "Name" = format("%s", coalesce(var.ram_name, var.name))
    },
    var.tags,
    var.ram_tags,
    var.default_tags,
  )
}

resource "aws_ram_resource_association" "this" {
  count = var.create_tgw && var.share_tgw ? 1 : 0

  resource_arn       = aws_ec2_transit_gateway.this[0].arn
  resource_share_arn = aws_ram_resource_share.this[0].id
}

resource "aws_ram_principal_association" "this" {
  count = var.create_tgw && var.share_tgw ? length(var.ram_principals) : 0

  principal          = var.ram_principals[count.index]
  resource_share_arn = aws_ram_resource_share.this[0].arn
}

resource "aws_ram_resource_share_accepter" "receiver_accept" {
  count = var.transit_gateway_share_arn == null ? 0 : 1
  share_arn = var.transit_gateway_share_arn
}

provider "aws" {
  version = "~> 2.51"

  region = var.aws_region
}
