# ============================================================
# Global Variable Scope Declarations (Root Level)
# ============================================================

variable "aws_region" {
  type        = string
  description = "AWS region to deploy all infrastructure assets"
  default     = "ap-south-1"
}

variable "environment" {
  type        = string
  description = "Target deployment workspace boundary validation rule"
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "The targeted runtime environment value must be restricted to 'dev' or 'prod'."
  }
}

variable "project" {
  type        = string
  description = "Core namespace prefix used as an identifier anchor for resources"
  default     = "wanderlust"
}

# ── Network Topology Configurations ───────────────────────────
variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "The base network block allocated for the VPC"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
  description = "CIDR blocks for public facing routing structures"
}

variable "private_subnet_cidrs" {
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
  description = "CIDR blocks for isolated secure private compute subnets"
}

variable "availability_zones" {
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b"]
  description = "Target physical data centers for regional high availability"
}

# ── Jenkins Infrastructure Parameters ──────────────────────────
variable "jenkins_instance_type" {
  type        = string
  default     = "t3.large"
  description = "Compute hardware footprint size for Jenkins"
}

variable "jenkins_volume_size" {
  type        = number
  default     = 30
  description = "Root operating system block storage scale"
}

variable "jenkins_data_volume_size" {
  type        = number
  default     = 20
  description = "Dedicated workspace volume persistent data block scale"
}

variable "backup_s3_bucket" {
  type        = string
  description = "Target cold storage tier destination bucket identifier"
}

variable "allowed_ssh_cidr" {
  type        = string
  default     = "0.0.0.0/0"
  description = "Firewall rule constraint perimeter pattern for secure entry"
}

# ── EKS Cluster Configuration Parameters ───────────────────────
variable "eks_cluster_version" {
  type        = string
  default     = "1.34"
  description = "Target Kubernetes Control Plane engine version constraint"
}

variable "eks_node_instance_type" {
  type        = string
  default     = "t3.medium"
  description = "Instance type assigned to handle target worker pod operations"
}

variable "eks_node_min_size" {
  type        = number
  default     = 1
  description = "Minimum node capacity bounds floor configuration"
}

variable "eks_node_max_size" {
  type        = number
  default     = 3
  description = "Maximum elasticity limit threshold configuration"
}

variable "eks_node_desired_size" {
  type        = number
  default     = 2
  description = "Baseline persistent running capacity node allocation target"
}

# ── Addon Deployment Toggle ────────────────────────────────────
variable "deploy_addons" {
  type        = bool
  default     = true
  description = "Toggle to deploy Helm-based EKS addons (ArgoCD, Prometheus)"
}

variable "deploy_eks" {
  type        = bool
  default     = true
  description = "Toggle to enable or disable EKS cluster deployment"
}

variable "key_name" {
  type = string
}

variable "allowed_cidr_blocks" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

