# ============================================================
# CI/CD Host Security Policies (IAM Profiles)
# Grants Jenkins the exact permission boundaries required to
# provision infrastructure via EKSCTL and run S3 backups.
# ============================================================

#locals {
# name_prefix = "${var.project}-${var.environment}"
#}

# ── IAM Role ──────────────────────────────────────────────────
resource "aws_iam_role" "jenkins" {
  name = "${local.name_prefix}-jenkins-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = {
    Name        = "${local.name_prefix}-jenkins-role"
    Environment = var.environment
    Project     = var.project
  }
}

# ── Managed Policy Attachments ────────────────────────────────
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.jenkins.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ecr" {
  role       = aws_iam_role.jenkins.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
}

# ── Custom Inline Permissions ─────────────────────────────────
resource "aws_iam_role_policy" "jenkins_custom" {
  name = "${local.name_prefix}-jenkins-custom"
  role = aws_iam_role.jenkins.name # ✅ FIXED: Bound to .name to prevent dependency race conditions

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "JenkinsS3Backup"
        Effect = "Allow"
        Action = [
          "s3:PutObject", 
          "s3:GetObject",
          "s3:DeleteObject", 
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.backup_s3_bucket}",
          "arn:aws:s3:::${var.backup_s3_bucket}/*"
        ]
      },
      {
        Sid      = "EKSPlatformAccess"
        Effect   = "Allow"
        Action   = ["eks:*"]
        Resource = "*"
      },
      {
        Sid    = "ECRTokenBroker"
        Effect = "Allow"
        Action = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "ComputeOrchestrationForEksctl"
        Effect = "Allow"
        Action = [
          "ec2:*",
          "autoscaling:*",
          "elasticloadbalancing:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "IAMOrchestrationForEksctl"
        Effect = "Allow"
        Action = [
          "iam:CreateRole", 
          "iam:DeleteRole",
          "iam:AttachRolePolicy", 
          "iam:DetachRolePolicy",
          "iam:PutRolePolicy", 
          "iam:DeleteRolePolicy",
          "iam:GetRole", 
          "iam:PassRole",
          "iam:CreateInstanceProfile", 
          "iam:DeleteInstanceProfile",
          "iam:AddRoleToInstanceProfile", 
          "iam:RemoveRoleFromInstanceProfile",
          "iam:GetInstanceProfile", 
          "iam:ListAttachedRolePolicies",
          "iam:ListRolePolicies", 
          "iam:TagRole", 
          "iam:UntagRole",
          "iam:CreateOpenIDConnectProvider", 
          "iam:DeleteOpenIDConnectProvider",
          "iam:GetOpenIDConnectProvider"
        ]
        Resource = "*"
      },
      {
        Sid      = "CloudFormationStackManagement"
        Effect   = "Allow"
        Action   = ["cloudformation:*"]
        Resource = "*"
      }
    ]
  })
}

# ── IAM Instance Profile ──────────────────────────────────────
resource "aws_iam_instance_profile" "jenkins" {
  name = "${local.name_prefix}-jenkins-profile"
  role = aws_iam_role.jenkins.name
}
