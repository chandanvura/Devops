#!/bin/bash
# scripts/setup-local.sh
# ─────────────────────────────────────────────────────────────────
# Quickstart script — verifies prerequisites and boots the stack
# Usage: chmod +x scripts/setup-local.sh && ./scripts/setup-local.sh
# ─────────────────────────────────────────────────────────────────

set -e

GREEN='\033[0;32m'
AMBER='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # no colour

info()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
warn()  { echo -e "${AMBER}[WARN]${NC}  $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

echo ""
echo "  devops-app — local setup"
echo "  ─────────────────────────"
echo ""

# ─── Check prerequisites ───────────────────────────────────────
info "Checking prerequisites..."

command -v docker       >/dev/null 2>&1 || error "Docker not found — install Docker Desktop"
command -v docker-compose >/dev/null 2>&1 || warn  "docker-compose not found — trying 'docker compose'"
command -v git          >/dev/null 2>&1 || error "Git not found"

# Java is optional locally (Docker builds it)
if command -v java >/dev/null 2>&1; then
  JAVA_VER=$(java -version 2>&1 | head -n1 | awk -F '"' '{print $2}' | cut -d'.' -f1)
  if [ "$JAVA_VER" -ge 17 ]; then
    info "Java $JAVA_VER found"
  else
    warn "Java $JAVA_VER found — project requires Java 17+ (Docker will handle this)"
  fi
else
  warn "Java not found locally — Docker will build the app inside a container"
fi

info "Docker: $(docker --version)"
info "Git: $(git --version)"

# ─── Start the stack ───────────────────────────────────────────
echo ""
info "Starting devops-app + Prometheus + Grafana..."

docker-compose up -d --build

echo ""
info "Waiting for app to become healthy..."
MAX_TRIES=20
TRIES=0
until curl -sf http://localhost:8080/actuator/health > /dev/null 2>&1; do
  TRIES=$((TRIES + 1))
  if [ $TRIES -ge $MAX_TRIES ]; then
    error "App did not become healthy after ${MAX_TRIES} attempts. Run: docker-compose logs app"
  fi
  echo -n "."
  sleep 3
done
echo ""

# ─── Print URLs ────────────────────────────────────────────────
echo ""
echo "  ─────────────────────────────────────────"
echo -e "  ${GREEN}Everything is running!${NC}"
echo "  ─────────────────────────────────────────"
echo ""
echo "  App endpoints:"
echo "    Hello:      http://localhost:8080/api/hello"
echo "    Health:     http://localhost:8080/actuator/health"
echo "    Metrics:    http://localhost:8080/actuator/prometheus"
echo "    Info:       http://localhost:8080/api/info"
echo ""
echo "  Monitoring:"
echo "    Prometheus: http://localhost:9090"
echo "    Grafana:    http://localhost:3000  (admin / admin123)"
echo ""
echo "  Useful commands:"
echo "    make compose-logs   — tail app logs"
echo "    make compose-down   — stop everything"
echo "    make test           — run unit tests"
echo "    make help           — all commands"
echo ""
