#!/bin/bash
# scripts/push-to-github.sh
# ─────────────────────────────────────────────────────────────────
# One-time script to initialise and push this project to GitHub
# Usage: chmod +x scripts/push-to-github.sh
#        ./scripts/push-to-github.sh YOUR_GITHUB_USERNAME
# ─────────────────────────────────────────────────────────────────

set -e

GITHUB_USER=${1:-"YOUR_GITHUB_USERNAME"}
REPO_NAME="devops-project"
REMOTE_URL="https://github.com/${GITHUB_USER}/${REPO_NAME}.git"

echo ""
echo "  Pushing devops-project to GitHub"
echo "  ─────────────────────────────────────────"
echo "  User: ${GITHUB_USER}"
echo "  Repo: ${REMOTE_URL}"
echo ""

# Step 1 — init git if not already
if [ ! -d ".git" ]; then
  git init
  echo "[OK] Git repo initialised"
fi

# Step 2 — initial commit
git add .
git commit -m "feat: initial devops-project — Java 17, Docker, K8s, Jenkins, Terraform

Stack:
- Spring Boot 3 REST API (Java 17)
- Multi-stage Dockerfile with non-root user
- Docker Compose with Prometheus + Grafana
- Jenkins pipeline (K8s pod agents, Trivy scan)
- GitHub Actions workflow (CI/CD alternative)
- Kubernetes manifests (Deployment, Service, HPA, RBAC)
- Helm chart with nonprod/prod value overrides
- Terraform infra (VPC, EKS, ECR, S3 state)
- Ansible server provisioning playbook
- Prometheus alert rules + Grafana setup
- Makefile with all common commands" || echo "[INFO] Nothing new to commit"

# Step 3 — set remote and push
git branch -M main
git remote remove origin 2>/dev/null || true
git remote add origin "${REMOTE_URL}"

echo ""
echo "  Ready to push. You need to:"
echo "  1. Create a NEW repo on GitHub: https://github.com/new"
echo "     Name: devops-project"
echo "     Visibility: Public"
echo "     Do NOT add README or .gitignore (we have those)"
echo ""
echo "  2. Then run: git push -u origin main"
echo ""
echo "  Or run this all at once:"
echo "    git push -u origin main"
echo ""
