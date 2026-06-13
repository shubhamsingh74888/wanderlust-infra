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


# ============================================================
# VPC Flow Logs & IAM Roles (MOVED OUTSIDE THE ROUTE TABLE)
# ============================================================

resource "aws_flow_log" "vpc_flow_log" {
  vpc_id               = aws_vpc.main.id
  traffic_type         = "ALL"
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.flow_log.arn
  iam_role_arn         = aws_iam_role.flow_log_role.arn
}

resource "aws_cloudwatch_log_group" "flow_log" {
  name              = "/vpc/flow-logs/wanderlust"
  retention_in_days = 7
}

resource "aws_iam_role" "flow_log_role" {
  name = "vpc-flow-log-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "flow_log_policy" {
  name = "vpc-flow-log-policy"
  role = aws_iam_role.flow_log_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents","logs:DescribeLogGroups","logs:DescribeLogStreams"]
      Resource = "*"
    }]
  })
}
