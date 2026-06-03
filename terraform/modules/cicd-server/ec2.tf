###############################################################################
# cicd-server/ec2.tf
# EC2 instance for Jenkins + SonarQube CI/CD server
###############################################################################

locals {
  name_prefix = "${var.project}-${var.environment}"
  ami_id      = try(data.aws_ami.packer.id, data.aws_ami.ubuntu.id)
}

# ── Latest Ubuntu 22.04 AMI (fallback if Packer AMI not found) ───────────────
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ── Packer-built AMI (preferred — tools pre-installed) ───────────────────────
data "aws_ami" "packer" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["wanderlust-jenkins-*"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# ── EBS data volume (persists Jenkins home + SonarQube data) ─────────────────
resource "aws_ebs_volume" "jenkins_data" {
  availability_zone = var.availability_zone
  size              = var.ebs_volume_size
  type              = "gp3"
  encrypted         = true

  tags = {
    Name        = "${local.name_prefix}-jenkins-data"
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_volume_attachment" "jenkins_data" {
  device_name  = "/dev/xvdf"
  volume_id    = aws_ebs_volume.jenkins_data.id
  instance_id  = aws_instance.cicd.id
  force_detach = true
}

# ── Security group ────────────────────────────────────────────────────────────
resource "aws_security_group" "cicd" {
  name        = "${local.name_prefix}-cicd-sg"
  description = "Jenkins + SonarQube CI/CD server"
  vpc_id      = var.vpc_id

  ingress {
    description = "Jenkins"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  ingress {
    description = "SonarQube"
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${local.name_prefix}-cicd-sg"
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# ── EC2 instance ──────────────────────────────────────────────────────────────
resource "aws_instance" "cicd" {
  ami                    = local.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.cicd.id]
  iam_instance_profile   = aws_iam_instance_profile.jenkins.name
  key_name               = var.key_name

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  user_data = templatefile("${path.module}/install_tools.sh", {
    backup_s3_bucket = var.backup_s3_bucket
    environment      = var.environment
    region           = var.aws_region
    JENKINS_HOME     = "/mnt/jenkins-data/jenkins-home"
    SQ_BASE_DIR      = "/mnt/jenkins-data/sonarqube"
  })

  user_data_replace_on_change = true

  tags = {
    Name        = "${local.name_prefix}-cicd-server"
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }

  depends_on = [aws_iam_instance_profile.jenkins]
}

# ── Elastic IP (stable public address across reboots) ────────────────────────
resource "aws_eip" "cicd" {
  instance = aws_instance.cicd.id
  domain   = "vpc"

  tags = {
    Name        = "${local.name_prefix}-cicd-eip"
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
