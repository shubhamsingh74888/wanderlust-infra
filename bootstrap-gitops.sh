#!/usr/bin/env bash
# ============================================================
#  bootstrap-gitops.sh
#  Called by Jenkinsfile Stage 08 after Terraform Apply.
#
#  Receives KUBECTL_PATH env var from caller (Stage 08).
#  Falls back to binary path checks, then /tmp download.
#  Never uses: install -o root  (Jenkins has no root)
# ============================================================

export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH

# ── Resolve kubectl — same 4-step logic as Stage 08 ─────────
KUBECTL_BIN="${KUBECTL_PATH:-}"

if [ -n "$KUBECTL_BIN" ] && [ -x "$KUBECTL_BIN" ]; then
  echo "[BOOTSTRAP] Using kubectl passed from caller: $KUBECTL_BIN"
elif [ -x /usr/local/bin/kubectl   ]; then
  KUBECTL_BIN=/usr/local/bin/kubectl
  echo "[BOOTSTRAP] Found kubectl at /usr/local/bin/kubectl"
elif [ -x /usr/bin/kubectl         ]; then
  KUBECTL_BIN=/usr/bin/kubectl
  echo "[BOOTSTRAP] Found kubectl at /usr/bin/kubectl"
elif [ -x /tmp/kubectl-bin/kubectl ]; then
  KUBECTL_BIN=/tmp/kubectl-bin/kubectl
  echo "[BOOTSTRAP] Found kubectl at /tmp/kubectl-bin/kubectl (cached)"
else
  echo "[BOOTSTRAP] kubectl not found — downloading to /tmp/kubectl-bin ..."
  mkdir -p /tmp/kubectl-bin
  curl -fsSL "https://dl.k8s.io/release/v1.30.0/bin/linux/amd64/kubectl" \
    -o /tmp/kubectl-bin/kubectl
  chmod +x /tmp/kubectl-bin/kubectl
  KUBECTL_BIN=/tmp/kubectl-bin/kubectl
  echo "[BOOTSTRAP] ✔ kubectl downloaded"
fi

# Hard-fail early with diagnostics if still not available
if [ ! -x "$KUBECTL_BIN" ]; then
  echo "[BOOTSTRAP] ✘ FATAL: kubectl not executable at: $KUBECTL_BIN"
  ls -la "$KUBECTL_BIN" 2>/dev/null || true
  exit 1
fi

export PATH=$(dirname "$KUBECTL_BIN"):$PATH
echo "[BOOTSTRAP] kubectl: $($KUBECTL_BIN version --client --short 2>/dev/null || $KUBECTL_BIN version --client)"

# ── All kubectl calls use $KUBECTL_BIN explicitly ────────────
# This guarantees the correct binary regardless of PATH state.
# ============================================================

set -euo pipefail

ARGOCD_NAMESPACE="argocd"
GITOPS_RAW="https://raw.githubusercontent.com/shubhamsingh74888/wanderlust-gitops/main/argocd"
GITOPS_LOCAL="${HOME}/wanderlust-gitops/argocd"
MAX_WAIT=300

echo ""
echo "======================================================"
echo " [BOOTSTRAP] Starting GitOps bootstrap"
echo "======================================================"

# ── Step 1: Wait for ArgoCD server ───────────────────────────
echo ""
echo "[BOOTSTRAP] Waiting for ArgoCD server to be Ready..."
$KUBECTL_BIN wait deployment argocd-server \
  --namespace "$ARGOCD_NAMESPACE" \
  --for=condition=Available \
  --timeout="${MAX_WAIT}s" \
  || {
    echo "[BOOTSTRAP] ⚠ ArgoCD not Ready — pod status:"
    $KUBECTL_BIN get pods -n "$ARGOCD_NAMESPACE" || true
    exit 1
  }
echo "[BOOTSTRAP] ✔ ArgoCD server is Ready."

# ── Step 2: Apply ArgoCD Application manifests ───────────────
echo ""
echo "[BOOTSTRAP] Applying ArgoCD Application manifests..."

apply_manifest() {
  local name="$1"
  local local_path="${GITOPS_LOCAL}/${name}"
  local remote_url="${GITOPS_RAW}/${name}"

  if [ -f "$local_path" ]; then
    echo "[BOOTSTRAP] Applying ${name} from local copy..."
    $KUBECTL_BIN apply -f "$local_path" && \
      echo "[BOOTSTRAP] ✔ ${name} applied (local)" || \
      { echo "[BOOTSTRAP] ✘ Failed to apply ${name}"; return 1; }
  else
    echo "[BOOTSTRAP] Local copy not found — fetching ${name} from GitHub..."
    for attempt in 1 2 3; do
      if $KUBECTL_BIN apply -f "$remote_url"; then
        echo "[BOOTSTRAP] ✔ ${name} applied (remote, attempt ${attempt})"
        return 0
      fi
      echo "[BOOTSTRAP] Attempt ${attempt} failed. Retrying in 5s..."
      sleep 5
    done
    echo "[BOOTSTRAP] ✘ Failed to apply ${name} after 3 attempts"
    return 1
  fi
}

apply_manifest "wanderlust-app.yaml"
apply_manifest "prometheus.yaml"

echo "[BOOTSTRAP] ✔ All ArgoCD manifests applied."

# ── Step 3: Verify Application objects registered ────────────
echo ""
echo "[BOOTSTRAP] Verifying ArgoCD Application registration..."
WAIT=0
until $KUBECTL_BIN get application wanderlust -n "$ARGOCD_NAMESPACE" > /dev/null 2>&1; do
  if [ $WAIT -ge 60 ]; then
    echo "[BOOTSTRAP] ✘ wanderlust Application not found after 60s"
    $KUBECTL_BIN get pods -n "$ARGOCD_NAMESPACE" || true
    exit 1
  fi
  echo "[BOOTSTRAP] Waiting for Application object... (${WAIT}s)"
  sleep 5
  WAIT=$((WAIT + 5))
done
echo "[BOOTSTRAP] ✔ wanderlust Application registered."

# ── Step 4: Check EBS CSI driver ─────────────────────────────
echo ""
echo "[BOOTSTRAP] Checking EBS CSI driver..."
EBS_SA=$($KUBECTL_BIN get serviceaccount ebs-csi-controller-sa \
  -n kube-system \
  -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}' \
  2>/dev/null || echo "")

if [ -z "$EBS_SA" ]; then
  echo "[BOOTSTRAP] ⚠ EBS CSI annotation not found — PVCs may not provision."
else
  echo "[BOOTSTRAP] ✔ EBS CSI annotated: $EBS_SA"
fi

# ── Step 5: Final status ──────────────────────────────────────
echo ""
echo "[BOOTSTRAP] ── Nodes ──────────────────────────────────"
$KUBECTL_BIN get nodes 2>/dev/null || true
echo ""
echo "[BOOTSTRAP] ── ArgoCD Applications ────────────────────"
$KUBECTL_BIN get applications -n "$ARGOCD_NAMESPACE" 2>/dev/null || true
echo ""
echo "[BOOTSTRAP] ── Monitoring namespace ───────────────────"
$KUBECTL_BIN get pods -n monitoring 2>/dev/null || \
  echo "[BOOTSTRAP] monitoring namespace not yet created."
echo ""
echo "[BOOTSTRAP] ✅ Bootstrap complete."
echo "[BOOTSTRAP]    Monitor sync: kubectl get applications -n argocd -w"
echo "======================================================"
