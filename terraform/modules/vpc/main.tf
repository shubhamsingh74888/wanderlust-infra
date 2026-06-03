# ============================================================
# Core Network Infrastructure Module
# Handles VPC, Border Gateways, and Base Private Route Rules
# ============================================================

locals {
  name_prefix = "${var.project}-${var.environment}"
}

# ── VPC ──────────────────────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${local.name_prefix}-vpc"
    Environment = var.environment
    Project     = var.project
  }
}

# ── Internet Gateway ─────────────────────────────────────────
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${local.name_prefix}-igw"
    Environment = var.environment
    Project     = var.project
  }
}

# ── Elastic IP for NAT Gateway ───────────────────────────────
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name        = "${local.name_prefix}-nat-eip"
    Environment = var.environment
    Project     = var.project
  }

  depends_on = [aws_internet_gateway.main]
}

# ── NAT Gateway ──────────────────────────────────────────────
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id # Puts NAT inside the first public subnet

  tags = {
    Name        = "${local.name_prefix}-nat"
    Environment = var.environment
    Project     = var.project
  }

  depends_on = [aws_internet_gateway.main]
}

# ── Route Table: Public ───────────────────────────────────────
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${local.name_prefix}-public-rt"
    Environment = var.environment
    Project     = var.project
  }
}

# ── Route Table: Private (Enables Outbound Sync) ───────────────
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id # Routes internal cluster out via NAT
  }

  tags = {
    Name        = "${local.name_prefix}-private-rt"
    Environment = var.environment
    Project     = var.project
  }
}
