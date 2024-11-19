data "aws_region" "current" {}
# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    var.mandatory_tags,
    {
      Name = "${var.mandatory_tags.Project}-vpc"
    }
  )
}

# Public subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main.id
  count                   = length(var.public_subnets_cidr_block)
  cidr_block              = element(var.public_subnets_cidr_block, count.index)
  availability_zone       = element(local.availability_zones, count.index)
  map_public_ip_on_launch = true

  tags = merge(
    var.mandatory_tags,
    var.public_subnet_tags,
    {
      Name = "${var.mandatory_tags.Project}-${element(local.availability_zones, count.index)}-public-subnet"
    }
  )
}

# Private Subnet
resource "aws_subnet" "private_subnet" {
  vpc_id                  = aws_vpc.main.id
  count                   = length(var.private_subnets_cidr_block)
  cidr_block              = element(var.private_subnets_cidr_block, count.index)
  availability_zone       = element(local.availability_zones, count.index)
  map_public_ip_on_launch = false

  tags = merge(
    var.mandatory_tags,
    var.private_subnet_tags,
    {
      Name = "${var.mandatory_tags.Project}-${element(local.availability_zones, count.index)}-private-subnet"
    }
  )
}

#Internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.mandatory_tags,
    {
      Name = "${var.mandatory_tags.Project}-igw"
    }
  )
}

# Elastic-IP (eip) for NAT
resource "aws_eip" "nat_eip" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.igw]
}

# NAT Gateway
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = element(aws_subnet.public_subnet.*.id, 0)

  tags = merge(
    var.mandatory_tags,
    {
      Name = "${var.mandatory_tags.Project}-nat-gateway"
    }
  )
}

# Routing tables to route traffic for Private Subnet
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.mandatory_tags,
    {
      Name = "${var.mandatory_tags.Project}-private-route-table"
    }
  )
}

# Routing tables to route traffic for Public Subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.mandatory_tags,
    {
      Name = "${var.mandatory_tags.Project}-public-route-table"
    }
  )
}

# Route for Internet Gateway
resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# Route for NAT Gateway
resource "aws_route" "private_internet_gateway" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_nat_gateway.nat.id
}

# Route table associations for both Public & Private Subnets
resource "aws_route_table_association" "public" {
  count          = length(var.public_subnets_cidr_block)
  subnet_id      = element(aws_subnet.public_subnet.*.id, count.index)
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = length(var.private_subnets_cidr_block)
  subnet_id      = element(aws_subnet.private_subnet.*.id, count.index)
  route_table_id = aws_route_table.private.id
}