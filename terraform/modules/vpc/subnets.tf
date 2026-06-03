# ── Public Subnets ──────────────────────────────────────────
# Provisions front-facing subnets mapping to specified AZs
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                                                = "${local.name_prefix}-public-${var.availability_zones[count.index]}"
    Environment                                         = var.environment
    Project                                             = var.project
    "kubernetes.io/role/elb"                            = "1" # Required by EKS AWS Load Balancer Controller for Public LBs
  }
}

# ── Private Subnets ─────────────────────────────────────────
# Provisions back-channel isolated subnets for EKS Worker Nodes
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name                                                = "${local.name_prefix}-private-${var.availability_zones[count.index]}"
    Environment                                         = var.environment
    Project                                             = var.project
    "kubernetes.io/role/internal-elb"                   = "1" # Required by EKS AWS Load Balancer Controller for Private LBs
  }
}

# ── Public Route Table Associations ─────────────────────────
resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ── Private Route Table Associations ────────────────────────
resource "aws_route_table_association" "private" {
  count          = length(var.private_subnet_cidrs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
