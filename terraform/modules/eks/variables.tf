variable "project"        { type = string }
variable "environment"         { type = string }
variable "aws_region"          { type = string }
variable "vpc_id"              { type = string }
variable "private_subnet_ids"  { type = list(string) }
variable "public_subnet_ids"   { type = list(string) }
variable "cluster_version"     { type = string }
variable "node_instance_type"  { type = string }
variable "node_min_size"       { type = number }
variable "node_max_size"       { type = number }
variable "node_desired_size"   { type = number }
variable "jenkins_server_sg_id" { type = string }


variable "deploy_addons" {
  type        = bool
  description = "Toggle to deploy Helm-based EKS addons"
  default     = false
}

variable "cluster_name" {
  type        = string
  description = "The name of the EKS cluster"
}
