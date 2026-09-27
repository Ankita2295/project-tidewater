variable "name" { type = string }
variable "cidr_block" { type = string }
variable "azs" {
  type = list(string)
  default = ["a", "b"] # 2 AZs minimum per brief; suffixed onto var.region
}
variable "region" { type = string }
variable "single_nat_gateway" {
  type        = bool
  default     = true # staging: 1 NAT to hit the $250/mo budget. prod overrides to false.
  description = "true = 1 shared NAT (cheap, single point of failure). false = 1 NAT per AZ."
}

locals {
  az_full = [for a in var.azs : "${var.region}${a}"]
}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = var.name }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-igw" }
}

resource "aws_subnet" "public" {
  for_each                = toset(var.azs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.cidr_block, 4, index(var.azs, each.value))
  availability_zone       = "${var.region}${each.value}"
  map_public_ip_on_launch = true
  tags = {
    Name                     = "${var.name}-public-${each.value}"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "private" {
  for_each          = toset(var.azs)
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.cidr_block, 4, index(var.azs, each.value) + 10)
  availability_zone = "${var.region}${each.value}"
  tags = {
    Name                              = "${var.name}-private-${each.value}"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_eip" "nat" {
  for_each = var.single_nat_gateway ? { "shared" = var.azs[0] } : { for a in var.azs : a => a }
  domain   = "vpc"
}

resource "aws_nat_gateway" "this" {
  for_each      = var.single_nat_gateway ? { "shared" = var.azs[0] } : { for a in var.azs : a => a }
  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.value].id
  tags          = { Name = "${var.name}-nat-${each.key}" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = { Name = "${var.name}-public-rt" }
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  for_each = toset(var.azs)
  vpc_id   = aws_vpc.this.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = var.single_nat_gateway ? aws_nat_gateway.this["shared"].id : aws_nat_gateway.this[each.value].id
  }
  tags = { Name = "${var.name}-private-rt-${each.value}" }
}

resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

output "vpc_id" { value = aws_vpc.this.id }
output "public_subnet_ids" { value = [for s in aws_subnet.public : s.id] }
output "private_subnet_ids" { value = [for s in aws_subnet.private : s.id] }
