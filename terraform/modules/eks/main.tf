# ============================================================
# Container Orchestration Engine Modules (Amazon EKS)
# Provisions the Managed Kubernetes Control Plane Perimeter
# ============================================================



locals {
  name_prefix  = "${var.project}-${var.environment}"
  cluster_name = "${local.name_prefix}-eks"
}

# ── IAM Role for EKS Control Plane ───────────────────────────
resource "aws_iam_role" "eks_cluster" {
  name = "${local.cluster_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
    }]
  })

  tags = {
    Name        = "${local.cluster_name}-role"
    Environment = var.environment
    Project     = var.project
  }
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# ── Security Group for EKS Cluster ───────────────────────────
resource "aws_security_group" "eks_cluster" {
  name        = "${local.cluster_name}-sg"
  description = "Security firewall boundaries wrapping control plane API brokers"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Restricted TLS API transport from dedicated Jenkins automation hosts"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [var.jenkins_server_sg_id]
  }


# Rule 2: Allow your Workstation IP
  ingress {
    description = "Allow admin workstation to run bootstrap script"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["152.57.34.124/32"] 
  }



  egress {
    description = "Allow all outbound calls"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { 
    Name        = "${local.cluster_name}-sg"
    Environment = var.environment
    Project     = var.project
  }
}

# ── EKS Cluster Control Plane ─────────────────────────────────
resource "aws_eks_cluster" "main" {
  name     = local.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.cluster_version

access_config {
    authentication_mode        = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  } 

  vpc_config {
    
    subnet_ids              = var.private_subnet_ids
    security_group_ids      = [aws_security_group.eks_cluster.id]
    endpoint_private_access = true
    endpoint_public_access  = true
    
    public_access_cidrs     = ["0.0.0.0/0"] # Change to [var.vpc_cidr] or your specific corporate gateway block for production lockout
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator"]

  tags = {
    Name        = local.cluster_name
    Environment = var.environment
    Project     = var.project
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]
}


# OIDC provider — required for IRSA (pod-level IAM)
data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# IAM role for EBS CSI driver (IRSA pattern)
data "aws_iam_policy_document" "ebs_csi_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  name               = "${var.cluster_name}-ebs-csi-role"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_trust.json
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# EBS CSI addon — always enabled, not behind deploy_addons flag
resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = "v1.32.0-eksbuild.1"
  service_account_role_arn = aws_iam_role.ebs_csi.arn

  depends_on = [
    aws_eks_node_group.main,
    aws_iam_role_policy_attachment.ebs_csi,
    aws_iam_openid_connect_provider.eks,
  ]
}
