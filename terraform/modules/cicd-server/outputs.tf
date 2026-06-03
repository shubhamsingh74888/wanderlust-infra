
output "public_ip" {
  description = "Jenkins server public IP"
  value       = aws_instance.cicd.public_ip
}

output "instance_id" {
  description = "Jenkins EC2 instance ID — use with terraform taint"
  value       = aws_instance.cicd.id
}

output "ebs_volume_id" {
  description = "Jenkins data EBS volume ID — DO NOT DELETE"
  value       = aws_ebs_volume.jenkins_data.id
}

output "security_group_id" {
  description = "Jenkins security group ID — passed to EKS for cluster access"
  value       = aws_security_group.cicd.id
}

