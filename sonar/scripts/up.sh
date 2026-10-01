#!/usr/bin/env bash
# Sobe SonarQube (Docker via Colima) + portal web local HealthFit.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SONAR_DIR="$ROOT/sonar"
COMPOSE="$SONAR_DIR/docker-compose.yml"
PORTAL_PORT="${SONAR_DASHBOARD_PORT:-9040}"

export DOCKER_HOST="${DOCKER_HOST:-unix://${HOME}/.colima/default/docker.sock}"

echo "==> Garantindo Colima (Docker)…"
if ! docker info >/dev/null 2>&1; then
  if command -v colima >/dev/null 2>&1; then
    colima start --cpu 4 --memory 8 --disk 40
  else
    echo "Docker/Colima indisponível. Instale: brew install colima docker docker-compose"
    exit 1
  fi
fi

echo "==> Subindo SonarQube + Postgres…"
docker compose -f "$COMPOSE" up -d

echo "==> Aguardando SonarQube ficar UP (pode levar 1–3 min)…"
for i in $(seq 1 90); do
  if curl -sf http://127.0.0.1:9000/api/system/status 2>/dev/null | grep -q '"status":"UP"'; then
    echo "SonarQube UP."
    break
  fi
  if [[ "$i" -eq 90 ]]; then
    echo "Timeout aguardando SonarQube. Veja: docker compose -f $COMPOSE logs sonarqube"
    exit 1
  fi
  sleep 5
done

echo "==> Iniciando portal em http://127.0.0.1:${PORTAL_PORT} …"
cd "$SONAR_DIR/dashboard"
if lsof -nP -iTCP:"$PORTAL_PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "Portal já ativo."
else
  nohup /usr/local/bin/node server.mjs >"$SONAR_DIR/dashboard/portal.log" 2>&1 &
  echo $! >"$SONAR_DIR/dashboard/portal.pid"
  sleep 1
fi

echo ""
echo "Pronto."
echo "  Portal HealthFit : http://127.0.0.1:${PORTAL_PORT}"
echo "  SonarQube        : http://127.0.0.1:9000  (admin / admin na 1ª vez)"
echo ""
echo "Depois rode: ./sonar/scripts/scan.sh"
open "http://127.0.0.1:9000/" || true
open "http://127.0.0.1:${PORTAL_PORT}/" || true
