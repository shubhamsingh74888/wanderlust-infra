# Production Environment Runtime Inputs
# ============================================================

environment  = "prod"
project      = "wanderlust"
aws_region   = "ap-south-1"
key_name     = "infra"

# ── Core Network Topology ─────────────────────────────────────
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
availability_zones   = ["ap-south-1a", "ap-south-1b"]

# ── CI/CD Infrastructure Layer ────────────────────────────────
jenkins_instance_type    = "t3.large"
jenkins_volume_size      = 30
jenkins_data_volume_size = 30
backup_s3_bucket         = "my-s3-bucket-shubham-prod"
allowed_ssh_cidr         = "0.0.0.0/0"

# ── Container Orchestration Layer ─────────────────────────────
eks_cluster_version    = "1.34"
eks_node_instance_type = "t3.medium"
eks_node_min_size      = 2
eks_node_max_size      = 3
eks_node_desired_size  = 2

deploy_eks    = true
deploy_addons = true

