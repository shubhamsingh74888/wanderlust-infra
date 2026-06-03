packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "~> 1"
    }
  }
}

variable "aws_region"    { default = "ap-south-1" }
variable "base_ami"      { default = "ami-0dee22c13ea7a9a67" }
variable "instance_type" { default = "t3.large" }

source "amazon-ebs" "jenkins" {
  region            = var.aws_region
  source_ami        = var.base_ami
  instance_type     = var.instance_type
  ssh_username      = "ubuntu"
  ami_name          = "wanderlust-jenkins-{{timestamp}}"
  ami_description   = "Pre-baked Jenkins CI server with all DevOps tooling"
  force_deregister  = true
  force_delete_snapshot = true

  tags = {
    Name        = "wanderlust-jenkins-ami"
    Project     = "wanderlust"
    ManagedBy   = "packer"
    BaseAMI     = var.base_ami
  }
}

build {
  sources = ["source.amazon-ebs.jenkins"]

  provisioner "shell" {
    script = "scripts/install_devops_tools.sh"
    execute_command = "sudo bash '{{.Path}}'"
  }
}
