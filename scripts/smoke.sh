#!/usr/bin/env bash
# Smoke tests post-despliegue (rápidos, no destructivos) a través del punto de entrada público.
# Uso: scripts/smoke.sh <staging|production> [version_esperada]
source "$(dirname "$0")/lib.sh"
ENV="${1:?ambiente requerido}"
EXPECTED="${2:-}"
BASE="http://localhost:$(env_port "$ENV")"
fail=0

check() {
  local name="$1" url="$2" pattern="$3" body
  for _ in 1 2 3 4 5; do
    body="$(curl -fsS --max-time 5 "$url" 2>/dev/null)" && echo "$body" | grep -q "$pattern" \
      && { log "PASS  $name"; return 0; }
    sleep 2
  done
  log "FAIL  $name ($url)"; fail=1
}

check "frontend responde (index.html)" "$BASE/" "TaskFlow"
check "nginx healthz"                  "$BASE/healthz" "ok"
check "api /health vía gateway"         "$BASE/health"      "ok"
check "api lista de tareas"            "$BASE/api/tasks" "\["
check "api stats"                       "$BASE/api/tasks/stats" "completion_rate"
check "version en $ENV"                 "$BASE/version" "\"environment\":\"$ENV\""
if [ -n "$EXPECTED" ]; then check "versión desplegada = $EXPECTED" "$BASE/version" "\"version\":\"$EXPECTED\""; fi

[ "$fail" = 0 ] || die "Smoke tests fallaron en $ENV"
log "Smoke tests OK en $ENV"
