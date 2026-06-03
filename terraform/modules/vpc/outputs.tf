output "vpc_id" {
  description = "VPC ID — passed to security groups and EKS"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs — Jenkins server goes here"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs — EKS worker nodes go here"
  value       = aws_subnet.private[*].id
}

output "vpc_cidr" {
  description = "VPC CIDR block — used in security group rules"
  value       = aws_vpc.main.cidr_block
}

