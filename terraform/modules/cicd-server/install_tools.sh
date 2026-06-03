#!/bin/bash
# Boot-time only. Tools are already installed in the AMI by Packer.
# This script handles: repo clone, disk mount, env config, S3 restore, service start.
set -euo pipefail
exec > >(tee /var/log/user-data.log) 2>&1
echo "=== USER-DATA STARTING: $(date) ==="

# ── SELF-BOOTSTRAP: clone repo so all scripts/configs are available ──────────
REPO_URL="https://github.com/shubhamsingh74888/Wanderlust-Mega-Project.git"
REPO_DIR="/opt/wanderlust"

# If repo is PRIVATE, fetch token from SSM first:
# GITHUB_TOKEN=$(aws ssm get-parameter \
#   --name "/wanderlust/github-token" \
#   --with-decryption \
#   --region ${region} \
#   --query 'Parameter.Value' \
#   --output text)
# REPO_URL="https://shubhamsingh74888:$GITHUB_TOKEN@github.com/shubhamsingh74888/Wanderlust-Mega-Project.git"

if [ ! -d "$REPO_DIR/.git" ]; then
  echo "[REPO] Cloning project repo..."
  git clone "$REPO_URL" "$REPO_DIR"
  echo "[REPO] ✔ Cloned to $REPO_DIR"
else
  echo "[REPO] Repo already present, pulling latest..."
  git -C "$REPO_DIR" pull
  echo "[REPO] ✔ Repo updated"
fi
# All Jenkinsfiles, configs, k8s manifests now available at $REPO_DIR
# ─────────────────────────────────────────────────────────────────────────────

# 1. Mount EBS data volume
DEVICE=""
for i in $(seq 1 15); do
  if   [ -b /dev/nvme1n1 ]; then DEVICE=/dev/nvme1n1; break
  elif [ -b /dev/xvdf    ]; then DEVICE=/dev/xvdf;    break
  fi
  echo "[MOUNT] Waiting for EBS device... attempt $i"
  sleep 5
done

JENKINS_HOME="/var/lib/jenkins"
SQ_BASE_DIR="/var/lib/sonarqube"

if [ -n "$DEVICE" ]; then
  echo "[MOUNT] Found device: $DEVICE"
  blkid "$DEVICE" || mkfs.ext4 -L jenkins-data "$DEVICE"
  mkdir -p /mnt/jenkins-data
  mount "$DEVICE" /mnt/jenkins-data
  DEVICE_UUID=$(blkid -s UUID -o value "$DEVICE")
  grep -q "$DEVICE_UUID" /etc/fstab \
    || echo "UUID=$DEVICE_UUID /mnt/jenkins-data ext4 defaults,nofail 0 2" >> /etc/fstab
  mkdir -p /mnt/jenkins-data/jenkins-home /mnt/jenkins-data/sonarqube
  JENKINS_HOME="/mnt/jenkins-data/jenkins-home"
  SQ_BASE_DIR="/mnt/jenkins-data/sonarqube"
  echo "[MOUNT] ✔ EBS mounted at /mnt/jenkins-data"
else
  echo "[MOUNT] No EBS device found, using default paths"
fi

# 2. Configure JENKINS_HOME via systemd override
mkdir -p /etc/systemd/system/jenkins.service.d

# Create systemd mount unit for EBS volume
cat > /etc/systemd/system/mnt-jenkins\x2ddata.mount << MOUNTUNIT
[Unit]
Description=Jenkins EBS Data Volume
After=local-fs.target

[Mount]
What=/dev/xvdf
Where=/mnt/jenkins-data
Type=ext4
Options=defaults,nofail

[Install]
WantedBy=multi-user.target
MOUNTUNIT

systemctl daemon-reload
systemctl enable mnt-jenkins\x2ddata.mount || true

cat > /etc/systemd/system/jenkins.service.d/override.conf << OVERRIDE
[Unit]
After=mnt-jenkins\x2ddata.mount network-online.target
Wants=mnt-jenkins\x2ddata.mount

[Service]
Environment="JENKINS_HOME=${JENKINS_HOME}"
Environment="JAVA_OPTS=-Djenkins.install.runSetupWizard=false -Djava.awt.headless=true"
OVERRIDE
chown -R jenkins:jenkins "$JENKINS_HOME"
systemctl daemon-reload
echo "[CONFIG] ✔ JENKINS_HOME set to: $JENKINS_HOME"

# 3. Restore from S3 backup (environment-specific, dynamic)
BACKUP_BUCKET="${backup_s3_bucket}"
BACKUP_PREFIX="jenkins-backup/${environment}"
BACKUP_EXISTS=$(aws s3 ls "s3://$BACKUP_BUCKET/$BACKUP_PREFIX/" \
  --region ${region} 2>/dev/null | wc -l || echo 0)

if [ "$BACKUP_EXISTS" -gt 0 ]; then
  echo "[RESTORE] Found backup at s3://$BACKUP_BUCKET/$BACKUP_PREFIX/ — restoring..."
  aws s3 sync "s3://$BACKUP_BUCKET/$BACKUP_PREFIX/" "$JENKINS_HOME/" \
    --region ${region} \
    --exclude "*/workspace/*" \
    --exclude "*.tmp"
  chown -R jenkins:jenkins "$JENKINS_HOME"
  echo "[RESTORE] ✔ Jenkins state restored from S3"
else
  echo "[RESTORE] No backup found — fresh Jenkins install"
fi

# 4. SonarQube (docker already installed by Packer)
sysctl -w vm.max_map_count=524288
grep -q "vm.max_map_count" /etc/sysctl.conf \
  || echo "vm.max_map_count=524288" >> /etc/sysctl.conf

mkdir -p "$SQ_BASE_DIR/data" "$SQ_BASE_DIR/extensions" "$SQ_BASE_DIR/logs"
chown -R 1000:1000 "$SQ_BASE_DIR"

if docker ps -a --format '{{.Names}}' | grep -q "^sonarqube$"; then
  echo "[SONAR] Restarting existing SonarQube container..."
  docker start sonarqube
else
  echo "[SONAR] Starting SonarQube container..."
  docker run -d \
    --name sonarqube \
    --restart always \
    -p 9000:9000 \
    -v "$SQ_BASE_DIR/data:/opt/sonarqube/data" \
    -v "$SQ_BASE_DIR/extensions:/opt/sonarqube/extensions" \
    -v "$SQ_BASE_DIR/logs:/opt/sonarqube/logs" \
    sonarqube:community
fi

# 5. Add jenkins user to docker group so pipelines can run docker commands
usermod -aG docker jenkins
chmod 666 /var/run/docker.sock
echo "[DOCKER] ✔ Jenkins added to docker group"


# ── Install kubectl if not present (from Packer AMI) ─────────
if ! command -v kubectl &>/dev/null; then
  echo "[KUBECTL] Installing kubectl..."
  curl -fsSL "https://dl.k8s.io/release/v1.30.0/bin/linux/amd64/kubectl" -o /tmp/kubectl
  install -o root -g root -m 0755 /tmp/kubectl /usr/local/bin/kubectl
  rm -f /tmp/kubectl
  echo "[KUBECTL] ✔ kubectl installed"
fi

# ── Symlinks — ensure all tools in /usr/bin (Jenkins PATH) ───
for tool in kubectl helm argocd eksctl terraform; do
  [ -f "/usr/local/bin/$tool" ] && ln -sf "/usr/local/bin/$tool" "/usr/bin/$tool" &&     echo "[SYMLINK] ✔ /usr/bin/$tool -> /usr/local/bin/$tool" || true
done

# ── Jenkins user PATH fix ─────────────────────────────────────
JPATH_FILE="$JENKINS_HOME/.bashrc"
grep -q '/usr/local/bin' "$JPATH_FILE" 2>/dev/null ||   echo 'export PATH=$PATH:/usr/local/bin' >> "$JPATH_FILE" || true

echo "[PATH] ✔ Tools symlinked and PATH configured"

# 6. Start Jenkins
systemctl restart jenkins
echo "[START] ✔ Jenkins started"

# 7. S3 backup cron
cat > /etc/cron.d/jenkins-s3-backup << CRONEOF
0 2 * * * root aws s3 sync $JENKINS_HOME s3://$BACKUP_BUCKET/$BACKUP_PREFIX/ \
  --region ${region} \
  --exclude "*/workspace/*" \
  --exclude "*.tmp" \
  --exclude "*/cache/*" \
  >> /var/log/jenkins-backup.log 2>&1
CRONEOF
chmod 644 /etc/cron.d/jenkins-s3-backup

TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
PUBLIC_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/public-ipv4)

echo "=========================================================="
echo "  BOOTSTRAP COMPLETE: $(date)"
echo "  Repo dir : $REPO_DIR  (Jenkinsfiles, k8s manifests)"
echo "  Jenkins  : http://$PUBLIC_IP:8080"
echo "  SonarQube: http://$PUBLIC_IP:9000"
echo "  Data dir : $JENKINS_HOME  (on EBS)"
echo "=========================================================="

