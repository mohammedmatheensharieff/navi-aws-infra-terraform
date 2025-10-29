locals {
  name = var.project
}

resource "aws_vpc" "this" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${local.name}-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.name}-igw" }
}

# Public subnets
resource "aws_subnet" "public" {
  for_each                = toset(var.azs)
  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.value
  cidr_block              = cidrsubnet(aws_vpc.this.cidr_block, 4, index(var.azs, each.value))
  map_public_ip_on_launch = true
  tags                    = { Name = "${local.name}-public-${each.value}", Tier = "public" }
}

# Private app subnets
resource "aws_subnet" "priv_app" {
  for_each          = toset(var.azs)
  vpc_id            = aws_vpc.this.id
  availability_zone = each.value
  cidr_block        = cidrsubnet(aws_vpc.this.cidr_block, 4, 4 + index(var.azs, each.value))
  tags              = { Name = "${local.name}-priv-app-${each.value}", Tier = "app" }
}

# Private db subnets
resource "aws_subnet" "priv_db" {
  for_each          = toset(var.azs)
  vpc_id            = aws_vpc.this.id
  availability_zone = each.value
  cidr_block        = cidrsubnet(aws_vpc.this.cidr_block, 4, 8 + index(var.azs, each.value))
  tags              = { Name = "${local.name}-priv-db-${each.value}", Tier = "db" }
}

# Public route table -> IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "${local.name}-rt-public" }
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# NAT (single NAT by default)
resource "aws_eip" "nat" {
  for_each = var.nat_per_az ? aws_subnet.public : { single = values(aws_subnet.public)[0] }
  domain   = "vpc"
  tags     = { Name = "${local.name}-nat-eip-${try(each.key, "single")}" }
}

resource "aws_nat_gateway" "nat" {
  for_each      = var.nat_per_az ? aws_subnet.public : { single = values(aws_subnet.public)[0] }
  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = var.nat_per_az ? aws_subnet.public[each.key].id : values(aws_subnet.public)[0].id
  depends_on    = [aws_internet_gateway.igw]
  tags          = { Name = "${local.name}-nat-${try(each.key, "single")}" }
}

# Private app route table(s) -> NAT
resource "aws_route_table" "priv_app" {
  for_each = var.nat_per_az ? aws_nat_gateway.nat : { shared = values(aws_nat_gateway.nat)[0] }
  vpc_id   = aws_vpc.this.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = var.nat_per_az ? aws_nat_gateway.nat[each.key].id : values(aws_nat_gateway.nat)[0].id
  }
  tags = { Name = "${local.name}-rt-priv-app-${try(each.key, "shared")}" }
}

# ✅ FIXED: ternary on a single line
resource "aws_route_table_association" "priv_app" {
  for_each       = aws_subnet.priv_app
  subnet_id      = each.value.id
  route_table_id = var.nat_per_az ? aws_route_table.priv_app[each.key].id : aws_route_table.priv_app["shared"].id
}

# Private db route table (no internet)
resource "aws_route_table" "priv_db" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.name}-rt-priv-db" }
}

resource "aws_route_table_association" "priv_db" {
  for_each       = aws_subnet.priv_db
  subnet_id      = each.value.id
  route_table_id = aws_route_table.priv_db.id
}
