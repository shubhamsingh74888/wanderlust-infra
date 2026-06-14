# ============================================================
# Root Module — Orchestrates all child modules
# Direct AWS resources belong in their respective modules
# ============================================================

# ── Step 1: Build the VPC & Network Layer ────────────────────
module "vpc" {
  source = "./modules/vpc"

  project              = var.project
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
}

# ── Step 2: Build the Jenkins CI/CD Server ───────────────────
module "cicd" {
  source = "./modules/cicd-server"
  count  = 1

  project           = var.project
  environment       = var.environment
  aws_region        = var.aws_region
  vpc_id            = module.vpc.vpc_id
  subnet_id         = module.vpc.public_subnet_ids[0]
  instance_type     = var.jenkins_instance_type
  root_volume_size  = var.jenkins_volume_size
  data_volume_size  = var.jenkins_data_volume_size
  backup_s3_bucket  = var.backup_s3_bucket
  deploy_addons     = var.deploy_addons
  availability_zone = var.availability_zones[0]
  ebs_volume_size   = var.jenkins_data_volume_size
  key_name          = var.key_name
}

# ── Step 3: Build the EKS Cluster ────────────────────────────
module "eks" {
  source = "./modules/eks"
  count  = var.deploy_eks ? 1 : 0

  project              = var.project
  environment          = var.environment
  aws_region           = var.aws_region
  vpc_id               = module.vpc.vpc_id
  private_subnet_ids   = module.vpc.private_subnet_ids
  public_subnet_ids    = module.vpc.public_subnet_ids
  cluster_version      = var.eks_cluster_version
  node_instance_type   = var.eks_node_instance_type
  node_min_size        = var.eks_node_min

