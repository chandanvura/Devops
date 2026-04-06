# Makefile — shortcuts for common DevOps tasks
# Usage: make <target>
# Run 'make help' to see all commands

.PHONY: help build test docker-build docker-run compose-up compose-down \
        k8s-deploy k8s-status k8s-logs k8s-rollback tf-init tf-plan tf-apply clean

APP_NAME    := devops-app
IMAGE_TAG   := $(shell git rev-parse --short HEAD 2>/dev/null || echo "latest")
REGISTRY    := ghcr.io/YOUR_GITHUB_USERNAME
NAMESPACE   := nonprod

help:   ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ─── Local Development ─────────────────────────────────────────
build:  ## Build the Java JAR
	cd app && mvn clean package -DskipTests -q
	@echo "JAR built: app/target/devops-app-*.jar"

test:   ## Run unit tests
	cd app && mvn test
	@echo "Tests complete — results in app/target/surefire-reports/"

# ─── Docker ────────────────────────────────────────────────────
docker-build:  ## Build Docker image
	docker build -t $(APP_NAME):$(IMAGE_TAG) ./app
	docker tag $(APP_NAME):$(IMAGE_TAG) $(APP_NAME):latest
	@echo "Image built: $(APP_NAME):$(IMAGE_TAG)"

docker-run:    ## Run app container locally
	docker run --rm -p 8080:8080 \
	  -e APP_ENV=local \
	  $(APP_NAME):latest

docker-push:   ## Push image to registry
	docker tag $(APP_NAME):$(IMAGE_TAG) $(REGISTRY)/$(APP_NAME):$(IMAGE_TAG)
	docker push $(REGISTRY)/$(APP_NAME):$(IMAGE_TAG)

# ─── Docker Compose (local full stack) ────────────────────────
compose-up:    ## Start app + Prometheus + Grafana
	docker-compose up -d --build
	@echo ""
	@echo "  App:        http://localhost:8080/api/hello"
	@echo "  Health:     http://localhost:8080/actuator/health"
	@echo "  Metrics:    http://localhost:8080/actuator/prometheus"
	@echo "  Prometheus: http://localhost:9090"
	@echo "  Grafana:    http://localhost:3000  (admin/admin123)"

compose-down:  ## Stop all containers
	docker-compose down -v

compose-logs:  ## Tail app logs
	docker-compose logs -f app

# ─── Kubernetes ────────────────────────────────────────────────
k8s-deploy:    ## Deploy to K8s with Helm
	helm upgrade --install $(APP_NAME) ./helm/$(APP_NAME) \
	  --namespace $(NAMESPACE) \
	  --create-namespace \
	  --set image.repository=$(REGISTRY)/$(APP_NAME) \
	  --set image.tag=$(IMAGE_TAG) \
	  --values ./helm/$(APP_NAME)/values-nonprod.yaml \
	  --wait
	@echo "Deployed $(APP_NAME):$(IMAGE_TAG) to $(NAMESPACE)"

k8s-status:    ## Show pods, deployments, HPA
	@echo "=== Pods ==="
	kubectl get pods -n $(NAMESPACE) -l app=$(APP_NAME)
	@echo ""
	@echo "=== Deployment ==="
	kubectl get deployment $(APP_NAME) -n $(NAMESPACE)
	@echo ""
	@echo "=== HPA ==="
	kubectl get hpa -n $(NAMESPACE) 2>/dev/null || echo "No HPA found"

k8s-logs:      ## Stream pod logs
	kubectl logs -n $(NAMESPACE) -l app=$(APP_NAME) -f --tail=100

k8s-rollback:  ## Rollback to previous Helm release
	helm rollback $(APP_NAME) 0 --namespace $(NAMESPACE)
	@echo "Rolled back $(APP_NAME) in $(NAMESPACE)"

k8s-history:   ## Show Helm release history
	helm history $(APP_NAME) --namespace $(NAMESPACE)

# ─── Terraform ─────────────────────────────────────────────────
tf-init:       ## Init Terraform
	cd terraform && terraform init

tf-plan:       ## Show infra changes (dry run — safe)
	cd terraform && terraform plan

tf-apply:      ## Apply infra changes
	cd terraform && terraform apply

tf-destroy:    ## Destroy all infra (CAREFUL!)
	cd terraform && terraform destroy

# ─── Cleanup ───────────────────────────────────────────────────
clean:         ## Remove build artifacts and Docker images
	cd app && mvn clean -q
	docker image prune -f
	@echo "Cleaned up"
