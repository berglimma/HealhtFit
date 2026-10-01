#!/usr/bin/env bash
# Executa análise SonarScanner no repositório HealthFit.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
export DOCKER_HOST="${DOCKER_HOST:-unix://${HOME}/.colima/default/docker.sock}"
SONAR_URL="${SONAR_HOST_URL:-http://host.docker.internal:9000}"
TOKEN="${SONAR_TOKEN:-}"
USER="${SONAR_USER:-admin}"
PASS="${SONAR_PASSWORD:-HealthFitSonar1!}"

if ! curl -sf http://127.0.0.1:9000/api/system/status >/dev/null 2>&1; then
  echo "SonarQube não está UP em 127.0.0.1:9000. Rode ./sonar/scripts/up.sh primeiro."
  exit 1
fi

# SonarQube 9.9 LTS: token vai em sonar.login (sonar.token é 10+)
AUTH_ARGS=()
if [[ -n "$TOKEN" ]]; then
  AUTH_ARGS+=(-Dsonar.login="$TOKEN")
else
  AUTH_ARGS+=(-Dsonar.login="$USER" -Dsonar.password="$PASS")
fi

echo "==> Analisando projeto (SonarScanner CLI via Docker)…"
docker run --rm \
  --platform linux/amd64 \
  --add-host=host.docker.internal:host-gateway \
  -e SONAR_HOST_URL="$SONAR_URL" \
  -v "$ROOT:/usr/src" \
  -w /usr/src \
  sonarsource/sonar-scanner-cli:11 \
  -Dsonar.projectBaseDir=/usr/src \
  -Dsonar.host.url="$SONAR_URL" \
  "${AUTH_ARGS[@]}"

echo ""
echo "Análise enviada. Abra:"
echo "  Portal: http://127.0.0.1:${SONAR_DASHBOARD_PORT:-9040}"
echo "  Sonar:  http://127.0.0.1:9000/dashboard?id=healthfit"
