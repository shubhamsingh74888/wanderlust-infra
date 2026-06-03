# ============================================================
#  terraform/providers.tf
#
#  FIX: "Kubernetes cluster unreachable" during plan
#
#  WHY IT HAPPENS:
#  Even with try(), Terraform validates the kubernetes/helm provider
#  connection at plan time. If the EKS cluster doesn't exist yet,
#  it crashes with "no configuration has been provided."
#
#  THE FIX:
#  Use an exec-based auth block that calls aws eks get-token.
#  This defers authentication to apply time (when cluster exists).
#  During plan, Terraform skips the live connection check.
# ============================================================

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ── Kubernetes provider ──────────────────────────────────────
# exec block calls aws eks get-token at apply time — not plan time.
# This means Terraform never tries to open a live connection during plan.
# cluster_name uses try() so it returns "" safely if module.eks
# doesn't exist yet (fresh account, first run).
provider "kubernetes" {
  host                   = try(module.eks[0].cluster_endpoint, "https://localhost")
  cluster_ca_certificate = try(base64decode(module.eks[0].cluster_ca), null)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks", "get-token",
      "--cluster-name", try(module.eks[0].cluster_name, "placeholder"),
      "--region", var.aws_region
    ]
  }
}

# ── Helm provider ────────────────────────────────────────────
provider "helm" {
  kubernetes {
    host                   = try(module.eks[0].cluster_endpoint, "https://localhost")
    cluster_ca_certificate = try(base64decode(module.eks[0].cluster_ca), null)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks", "get-token",
        "--cluster-name", try(module.eks[0].cluster_name, "placeholder"),
        "--region", var.aws_region
      ]
    }
  }
}

