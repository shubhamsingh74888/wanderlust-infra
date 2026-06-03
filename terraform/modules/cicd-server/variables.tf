# ============================================================
# CI/CD Module Variables Definition
# ============================================================

variable "project" {
  type        = string
  description = "Project name prefix"
}

variable "environment" {
  type        = string
  description = "Target deployment environment"
}

variable "aws_region" {
  type        = string
  description = "Target AWS region"
}

# ── Network Layout Inputs ────────────────────────────────────
variable "vpc_id" {
  type        = string
  description = "VPC ID target mapping"
}

variable "subnet_id" {
  type        = string
  description = "Public Subnet ID where Jenkins will be hosted"
}

# ── Compute Capacity Inputs ──────────────────────────────────
variable "instance_type" {
  type        = string
  description = "EC2 computing tier for Jenkins"
}


variable "root_volume_size" {
  type        = number
  description = "Root operating system space allocation in GB"
}

variable "data_volume_size" {
  type        = number
  description = "Dedicated persistent storage space in GB"
}

variable "backup_s3_bucket" {
  type        = string
  description = "S3 destination target for pipeline state captures"
}

variable "allowed_ssh_cidr" {
  type        = string
  description = "Firewall boundary restriction network pattern"
  default     = "0.0.0.0/0"
}

variable "deploy_addons" {
  type    = bool
  description = "Toggle to deploy EKS addons"
  default = false

}



variable "availability_zone" {
  type        = string
  description = "AZ for the EBS volume"
}

variable "ebs_volume_size" {
  type        = number
  description = "Size of the data volume"
}

variable "key_name" {
  type        = string
  description = "SSH key name"
}

variable "allowed_cidr_blocks" {
  type        = list(string)
  description = "List of allowed CIDR blocks for security group"
  default     = ["0.0.0.0/0"] # Or your specific network range
}
