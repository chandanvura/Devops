# devops-project

> Production-grade DevOps pipeline — Java 17 microservice deployed with Docker, Kubernetes, Jenkins, Terraform, Ansible, and monitored with Prometheus + Grafana.

Built to demonstrate real-world DevOps engineering skills: CI/CD pipeline authoring, container lifecycle management, infrastructure-as-code, Kubernetes operations, and production observability. Based on patterns used at scale in the games industry.

---

## Architecture overview

```
Developer
    │
    ▼ git push / PR
GitHub / GitLab
    │
    ▼ webhook trigger
Jenkins (runs on K8s pod agent)
    │
    ├─ 1. Maven build + unit tests (Java 17)
    ├─ 2. Trivy security scan (CVE check)
    ├─ 3. Docker multi-stage build
    ├─ 4. Push to container registry (GHCR / ECR)
    ├─ 5. Helm deploy → nonprod K8s namespace
    ├─ 6. Smoke test (readiness probe check)
    └─ 7. Manual approval gate → prod deploy
                │
                ▼
        Kubernetes (EKS / minikube)
        ┌───────────────────────────┐
        │  Deployment (replicas: 3) │
        │  Service (ClusterIP)      │
        │  HPA (auto-scales 2–20)   │
        │  RBAC (least privilege)   │
        └───────────────────────────┘
                │
                ▼
        Prometheus ──── Grafana
        (scrapes /actuator/prometheus every 15s)
        Alert rules: error rate, latency, OOM, crash loop
```

---

## Tech stack

| Layer | Technology |
|---|---|
| Application | Java 17, Spring Boot 3, Maven |
| Containerisation | Docker (multi-stage, non-root user) |
| Orchestration | Kubernetes, Helm 3 |
| CI/CD | Jenkins (Jenkinsfile), GitHub Actions |
| Infrastructure as Code | Terraform (AWS VPC + EKS + ECR) |
| Configuration Management | Ansible |
| Monitoring | Prometheus, Grafana |
| Security scanning | Trivy (CVE scanning in CI) |
| Local dev | Docker Compose |

---

## Project structure

```
devops-project/
│
├── app/                          # Spring Boot application
│   ├── src/main/java/...         # REST API (3 endpoints)
│   ├── src/test/java/...         # Unit tests (JUnit 5)
│   ├── Dockerfile                # Multi-stage: build (Maven) → runtime (JRE Alpine)
│   └── pom.xml                   # Java 17, Spring Boot 3, Micrometer Prometheus
│
├── .github/workflows/
│   └── ci-cd.yml                 # GitHub Actions: build → scan → push → deploy
│
├── Jenkinsfile                   # Jenkins pipeline (K8s pod agents, approval gates)
│
├── docker-compose.yml            # Local stack: app + Prometheus + Grafana
│
├── helm/devops-app/              # Helm chart
│   ├── Chart.yaml
│   ├── values.yaml               # defaults
│   ├── values-nonprod.yaml       # nonprod overrides (1 replica, low resources)
│   ├── values-prod.yaml          # prod overrides (3 replicas, HPA enabled)
│   └── templates/                # Deployment, Service, HPA
│
├── k8s/
│   └── deployment.yaml           # Raw K8s manifests (Deployment, Service, HPA, RBAC)
│
├── terraform/
│   └── main.tf                   # AWS VPC + EKS cluster + ECR repo + S3 state
│
├── ansible/
│   ├── setup-server.yml          # Playbook: install Java 17, Docker, systemd service
│   ├── inventory.ini
│   └── templates/                # Jinja2: application.yml, systemd service
│
├── monitoring/
│   ├── prometheus.yml            # Scrape config (app + K8s pod auto-discovery)
│   ├── alert-rules.yml           # Alerts: app down, high errors, high latency, OOM
│   └── grafana/provisioning/     # Auto-provision Prometheus datasource
│
├── scripts/
│   ├── setup-local.sh            # One-command local bootstrap
│   └── push-to-github.sh         # Git init + remote setup helper
│
└── Makefile                      # All common commands (make help)
```

---

## Quickstart — run locally in 2 minutes

**Prerequisites:** Docker Desktop, Git

```bash
# Clone the repo
git clone https://github.com/YOUR_GITHUB_USERNAME/devops-project.git
cd devops-project

# Start everything (app + Prometheus + Grafana)
chmod +x scripts/setup-local.sh
./scripts/setup-local.sh
```

**URLs after startup:**

| Service | URL | Credentials |
|---|---|---|
| App (Hello) | http://localhost:8080/api/hello | — |
| App (Health) | http://localhost:8080/actuator/health | — |
| App (Metrics) | http://localhost:8080/actuator/prometheus | — |
| Prometheus | http://localhost:9090 | — |
| Grafana | http://localhost:3000 | admin / admin123 |

---

## Running with Kubernetes (minikube)

```bash
# Start minikube
minikube start --memory=4096 --cpus=2

# Deploy to nonprod namespace via Helm
make k8s-deploy

# Check status
make k8s-status

# Stream logs
make k8s-logs

# Rollback to previous version
make k8s-rollback

# Full command reference
make help
```

---

## CI/CD pipeline explanation

### Jenkins (Jenkinsfile)

```
Checkout → Build (Maven) → Unit Tests → Trivy Scan
    → Docker Build → Push to Registry
    → Helm Deploy NonProd → Smoke Test
    → [Manual Approval]
    → Helm Deploy Production
    → [Auto-rollback on failure]
```

Key design decisions:
- **K8s pod agents** — each stage runs in an ephemeral container. No leftover state between builds. Agents spin up in seconds (not minutes like EC2).
- **Trivy before push** — security scan runs on the filesystem before the image is even built. CVEs blocked before they reach the registry.
- **`--wait` on Helm** — Jenkins blocks until all pods are healthy before marking the stage green. If readiness probes fail, the build fails rather than silently deploying broken code.
- **Auto-rollback** — the `post { failure { } }` block runs `helm rollback` if the production deploy stage fails.

### GitHub Actions (.github/workflows/ci-cd.yml)

Alternative to Jenkins. Same logical stages, different syntax. Uses:
- `actions/setup-java@v4` with Maven cache — fast builds
- `aquasecurity/trivy-action` — CVE scanning
- `docker/build-push-action@v5` — builds and pushes to GHCR with layer caching
- GitHub Environments with required reviewers for production approval gate

---

## Infrastructure as Code (Terraform)

The `terraform/main.tf` provisions:

```
AWS account
└── VPC (10.0.0.0/16)
    ├── Public subnets  [2 AZs]  — ALB, NAT Gateway
    ├── Private subnets [2 AZs]  — EKS nodes
    ├── EKS cluster (v1.29)
    │   └── Managed node group  (t3.small, min:1 max:3)
    ├── ECR repository           — Docker image storage
    └── S3 bucket                — Terraform remote state
```

```bash
cd terraform
terraform init
terraform plan    # always review before apply
terraform apply
```

The `prevent_destroy = true` lifecycle rule on critical resources ensures `terraform plan` will error before deleting production databases or clusters.

---

## Monitoring and alerting

Prometheus scrapes `/actuator/prometheus` every 15 seconds.

Alert rules defined in `monitoring/alert-rules.yml`:

| Alert | Condition | Severity |
|---|---|---|
| AppDown | Prometheus can't scrape app for 1m | Critical |
| HighErrorRate | >5% HTTP 500s over 5m | Critical |
| HighLatency | p95 latency >1s over 5m | Warning |
| HighJVMMemory | Heap >85% of max for 5m | Warning |
| PodCrashLooping | >3 restarts in 15m | Critical |

**Grafana dashboards:**
- Import dashboard ID `4701` (JVM Micrometer) from grafana.com for full Spring Boot metrics
- Add ID `315` (Kubernetes cluster monitoring) for node/pod-level metrics

---

## Key design decisions (for interviews)

**Why multi-stage Docker build?**
Stage 1 uses `maven:3.9-eclipse-temurin-17` (~600MB) to compile. Stage 2 uses `eclipse-temurin:17-jre-alpine` (~80MB) for runtime. Final image has no Maven, no source code, no JDK — just the JRE and the JAR. Smaller image = faster pulls, smaller attack surface.

**Why non-root user in Dockerfile?**
If a container escape exploit runs as root, the attacker has root on the host. Running as `appuser` limits blast radius. Standard security hardening in any production container setup.

**Why `requests` AND `limits` on K8s pods?**
Requests are used by the scheduler (which node can fit this pod?). Limits are the hard ceiling. Without requests, HPA can't calculate CPU utilisation percentage. Without limits, one misbehaving pod can starve all others on the same node.

**Why separate values files per environment?**
`values.yaml` → defaults. `values-nonprod.yaml` → overrides for nonprod (1 replica, low resources). `values-prod.yaml` → overrides for prod (3 replicas, HPA enabled, higher limits). One chart, three environments, zero YAML duplication.

**Why `--wait` in Helm deploy?**
Without `--wait`, Helm returns success as soon as K8s accepts the manifests — even if the pods fail to start. With `--wait`, Helm polls until all pods pass readiness probes. A failed deployment fails the pipeline, which triggers auto-rollback.

---

## What I learned building this

This project mirrors the infrastructure patterns I worked with at Sony Interactive Entertainment, where I managed Java microservice deployments across nonprod, pre-prod, and production Kubernetes environments. Building it from scratch filled the gaps I had in infrastructure provisioning (Terraform) and GitOps (ArgoCD) — areas previously handled by a dedicated platform team.

The biggest lesson: the tools are secondary. The discipline is: every change goes through Git, every deployment is tested before promotion, every production incident gets a written post-mortem.

---

## Next steps (roadmap)

- [ ] Add ArgoCD for GitOps CD (replace `helm upgrade` in Jenkins)
- [ ] Add Istio service mesh for mTLS between services
- [ ] Add second microservice to demonstrate inter-service communication
- [ ] Add chaos testing with Chaos Mesh (prove resilience)
- [ ] CKA certification (in progress)

---

## Author

Built by a DevOps engineer with production experience in Java microservice deployments, CI/CD pipeline management, and Kubernetes operations.

LinkedIn: [your-linkedin]
GitHub: [your-github]
