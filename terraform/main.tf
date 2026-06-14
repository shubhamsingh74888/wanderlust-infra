module "vpc" {
  source               = "./modules/vpc"
  project              = var.project
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
}

module "cicd" {
  source            = "./modules/cicd-server"
  count             = 1
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

module "eks" {
  source               = "./modules/eks"
  count                = var.deploy_eks ? 1 : 0
  project              = var.project
  environment          = var.environment
  aws_region           = var.aws_region
  vpc_id               = module.vpc.vpc_id
  private_subnet_ids   = module.vpc.private_subnet_ids
  public_subnet_ids    = module.vpc.public_subnet_ids
  cluster_version      = var.eks_cluster_version
  node_instance_type   = var.eks_node_instance_type
  node_min_size        = var.eks_node_min_size
  node_max_size        = var.eks_node_max_size
  node_desired_size    = var.eks_node_desired_size
  jenkins_server_sg_id = module.cicd[0].security_group_id
  deploy_addons        = var.deploy_addons
  cluster_name         = "${var.project}-${var.environment}-eks"
}

resource "helm_release" "argocd" {
  count            = var.deploy_eks && var.deploy_addons ? 1 : 0
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = "5.51.6"
  set {
    name  = "server.extraArgs[0]"
    value = "--insecure"
  }
  depends_on = [module.eks]
}

resource "aws_sns_topic" "alerts" {
  name = "wanderlust-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = "shubhamsingh74888@gmail.com"
}

resource "aws_cloudwatch_metric_alarm" "jenkins_cpu" {
  alarm_name          = "jenkins-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 85
  dimensions          = { InstanceId = module.cicd[0].instance_id }
  alarm_actions       = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "jenkins_status_check" {
  alarm_name          = "jenkins-status-check-failed"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Maximum"
  threshold           = 0
  dimensions          = { InstanceId = module.cicd[0].instance_id }
  alarm_actions       = [aws_sns_topic.alerts.arn]
}
