# ============================================================
# Development Environment Runtime Inputs
# Target Architecture: Minimal Sandbox Testing Topology
# ============================================================

environment  = "dev"
project = "wanderlust"
aws_region   = "ap-south-1"
key_name = "portfolio-key-pair"
# ── Core Network Topology ─────────────────────────────────────
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
availability_zones   = ["ap-south-1a", "ap-south-1b"]

# ── CI/CD Infrastructure Layer (Jenkins / SonarQube) ──────────
jenkins_instance_type    = "t3.medium"
jenkins_ami_id           = "ami-02d272fa43bc32f8d"
jenkins_volume_size      = 30
jenkins_data_volume_size = 20
backup_s3_bucket         = "my-s3-bucket-shubham-prod"
allowed_ssh_cidr         = "0.0.0.0/16"

# ── Container Orchestration Layer (Amazon EKS) ────────────────
eks_cluster_version    = "1.34" # ✅ Aligned with modern engine standards
eks_node_instance_type = "t3.medium"
eks_node_min_size      = 2
eks_node_max_size      = 3
eks_node_desired_size  = 2

deploy_eks = true # or false if you want to stop it
