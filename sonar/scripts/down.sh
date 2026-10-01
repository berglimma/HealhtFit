#!/usr/bin/env bash
# Para portal + containers SonarQube.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
COMPOSE="$ROOT/sonar/docker-compose.yml"
PORTAL_PORT="${SONAR_DASHBOARD_PORT:-9040}"

if [[ -f "$ROOT/sonar/dashboard/portal.pid" ]]; then
  kill "$(cat "$ROOT/sonar/dashboard/portal.pid")" 2>/dev/null || true
  rm -f "$ROOT/sonar/dashboard/portal.pid"
fi
if lsof -ti tcp:"$PORTAL_PORT" >/dev/null 2>&1; then
  kill "$(lsof -ti tcp:"$PORTAL_PORT")" 2>/dev/null || true
fi

docker compose -f "$COMPOSE" down
echo "SonarQube e portal encerrados."
