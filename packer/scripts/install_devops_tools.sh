#!/bin/bash
# Everything SLOW and STATIC lives here — runs once at AMI bake time.
set -euo pipefail
exec > >(tee /var/log/packer-build.log) 2>&1
echo "=== PACKER BAKE STARTING: $(date) ==="

export DEBIAN_FRONTEND=noninteractive

# ── 1. Base packages ─────────────────────────────────────────
apt-get update -y
apt-get install -y \
  ca-certificates curl fontconfig openjdk-21-jre \
  unzip wget tar jq gnupg lsb-release apt-transport-https

# ── 2. Repo signing keys ─────────────────────────────────────
mkdir -p /usr/share/keyrings /etc/apt/sources.list.d

# Jenkins
wget -q -O /usr/share/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key
chmod a+r /usr/share/keyrings/jenkins-keyring.asc
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/" \
  > /etc/apt/sources.list.d/jenkins.list

# Docker
wget -q -O /usr/share/keyrings/docker.asc \
  https://download.docker.com/linux/ubuntu/gpg
chmod a+r /usr/share/keyrings/docker.asc
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker.asc] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  > /etc/apt/sources.list.d/docker.list

# Trivy
wget -q -O /usr/share/keyrings/trivy-keyring.asc \
  https://aquasecurity.github.io/trivy-repo/deb/public.key
chmod a+r /usr/share/keyrings/trivy-keyring.asc
echo "deb [signed-by=/usr/share/keyrings/trivy-keyring.asc] \
  https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -cs) main" \
  > /etc/apt/sources.list.d/trivy.list

# ── 3. Install all heavy packages ────────────────────────────
apt-get update -y
apt-get install -y \
  jenkins docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin trivy

# Stop Jenkins — user_data will configure JENKINS_HOME before first start
systemctl stop jenkins || true
systemctl enable jenkins docker

# Add users to docker group
usermod -aG docker ubuntu
usermod -aG docker jenkins

# ── 4. Terraform ─────────────────────────────────────────────
TERRAFORM_VERSION="1.9.8"
curl -fsSL \
  "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" \
  -o /tmp/terraform.zip
unzip /tmp/terraform.zip -d /usr/local/bin/
chmod +x /usr/local/bin/terraform
rm -f /tmp/terraform.zip
terraform version

# ── 5. kubectl ───────────────────────────────────────────────
curl -fsSL "https://dl.k8s.io/release/v1.30.0/bin/linux/amd64/kubectl" \
  -o /tmp/kubectl
install -o root -g root -m 0755 /tmp/kubectl /usr/local/bin/kubectl
rm -f /tmp/kubectl
kubectl version --client

# ── 6. eksctl ────────────────────────────────────────────────
curl -fsSL \
  "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz" \
  | tar -xz -C /tmp
install -o root -g root -m 0755 /tmp/eksctl /usr/local/bin/eksctl
rm -f /tmp/eksctl
eksctl version

# ── 7. helm ──────────────────────────────────────────────────
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version --short

# ── 8. argocd CLI ────────────────────────────────────────────
ARGOCD_VER=$(curl -fsSL \
  https://api.github.com/repos/argoproj/argo-cd/releases/latest \
  | jq -r '.tag_name')
curl -fsSL \
  "https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VER}/argocd-linux-amd64" \
  -o /tmp/argocd
install -o root -g root -m 0755 /tmp/argocd /usr/local/bin/argocd
rm -f /tmp/argocd
argocd version --client

# ── 9. AWS CLI v2 ────────────────────────────────────────────
cd /tmp
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
unzip -q awscliv2.zip
./aws/install --update
rm -rf awscliv2.zip aws/
aws --version

# ── 10. Node.js 21 ───────────────────────────────────────────
curl -fsSL https://deb.nodesource.com/setup_21.x | bash -
apt-get install -y nodejs
node --version

# ── 11. Symlinks — tools visible to Jenkins restricted PATH ──
# Both /usr/local/bin AND /usr/bin so any PATH permutation works
ln -sf /usr/local/bin/kubectl   /usr/bin/kubectl
ln -sf /usr/local/bin/helm      /usr/bin/helm
ln -sf /usr/local/bin/argocd    /usr/bin/argocd
ln -sf /usr/local/bin/eksctl    /usr/bin/eksctl
ln -sf /usr/local/bin/terraform /usr/bin/terraform

# Verify symlinks resolve correctly
echo "[SYMLINKS] Verifying tool resolution:"
for tool in kubectl helm argocd eksctl terraform; do
  echo "  $tool -> $(readlink -f /usr/bin/$tool)"
done

# ── 12. Jenkins user PATH ────────────────────────────────────
# .bashrc and .profile are NOT sourced by the Jenkins daemon.
# The ONLY reliable method is the systemd service override below.
mkdir -p /var/lib/jenkins
cat >> /var/lib/jenkins/.bashrc << 'BASHEOF'
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH
BASHEOF
cat >> /var/lib/jenkins/.profile << 'PROFEOF'
export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH
PROFEOF

# ── 13. CRITICAL: Jenkins systemd environment override ───────
# Jenkins daemon is started by systemd — it does NOT source .bashrc or .profile.
# Without this override, the daemon inherits a minimal PATH from systemd
# that does NOT include /usr/local/bin, so kubectl/helm/terraform are "missing"
# even though the binaries exist on disk. This is the root cause of the failure.
mkdir -p /etc/systemd/system/jenkins.service.d
cat > /etc/systemd/system/jenkins.service.d/override.conf << 'UNITEOF'
[Service]
Environment="PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
Environment="JAVA_OPTS=-Djava.awt.headless=true"
UNITEOF

# Reload systemd so override is picked up on next start
systemctl daemon-reload

echo "[SYSTEMD] Jenkins override.conf written:"
cat /etc/systemd/system/jenkins.service.d/override.conf

# ── 14. Verify all tools installed correctly ─────────────────
echo ""
echo "=== TOOL VERSIONS ==="
terraform version
kubectl version --client
eksctl version
helm version --short
argocd version --client
aws --version
node --version
docker --version
echo ""
echo "=== PATH visible to shell ==="
echo "$PATH"
echo ""
echo "=== Binary locations ==="
which kubectl terraform helm argocd eksctl aws docker node
echo ""
echo "=== PACKER BAKE COMPLETE: $(date) ==="
