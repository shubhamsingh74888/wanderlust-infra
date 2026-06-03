# ============================================================
#  terraform/modules/eks/addons.tf
#
#  This file is intentionally minimal.
#
#  HISTORY OF CHANGES:
#  - helm_release.argocd   → moved to root main.tf (broke provider cycle)
#  - helm_release.prometheus → moved to ArgoCD GitOps (kubernetes/argocd-apps/prometheus.yaml)
#  - aws_eks_access_entry  → already exists in access_entries.tf (removed duplicate)
#
#  All AWS EKS access resources live in access_entries.tf.
#  All Helm resources live in root main.tf.
#  This file is kept for future addon resources if needed.
# ============================================================

