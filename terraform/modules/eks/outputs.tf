# ============================================================
#  terraform/modules/eks/outputs.tf
#
#  These outputs are consumed by:
#  - providers.tf (cluster_endpoint, cluster_ca for helm/k8s providers)
#  - root main.tf (cluster_name for helm_release.argocd depends_on)
# ============================================================

output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "EKS API endpoint — used by helm/kubernetes providers in providers.tf"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_ca" {
  description = "EKS CA certificate (base64) — used by helm/kubernetes providers"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "node_group_name" {
  description = "EKS node group name"
  value       = aws_eks_node_group.main.node_group_name
}

