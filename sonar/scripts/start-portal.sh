#!/usr/bin/env bash
# Sobe o portal Sonar em 127.0.0.1:9040 de forma persistente (fora do agente).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DASH="$ROOT/sonar/dashboard"
PORT="${SONAR_DASHBOARD_PORT:-9040}"
LOG="$DASH/portal.log"
PIDFILE="$DASH/portal.pid"

if lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "Já escutando na porta $PORT"
else
  cd "$DASH"
  /usr/local/bin/node server.mjs >>"$LOG" 2>&1 &
  echo $! >"$PIDFILE"
  sleep 1
fi

if curl -sf "http://127.0.0.1:${PORT}/api/health" >/dev/null; then
  echo "OK → http://127.0.0.1:${PORT}"
  open "http://127.0.0.1:${PORT}/"
else
  echo "Falha ao iniciar. Log:"
  tail -30 "$LOG" || true
  exit 1
fi
