#!/usr/bin/env bash
# Rollback instantáneo Blue/Green: devuelve el tráfico al color anterior.
# Uso: scripts/rollback.sh <staging|production>
source "$(dirname "$0")/lib.sh"
ENV="${1:?ambiente requerido}"

CURRENT="$(active_color "$ENV")"
[ -n "$CURRENT" ] || die "[$ENV] no hay Service api desplegado"
PREVIOUS="$(other_color "$CURRENT")"

if ! kubectl -n "$ENV" get deploy "api-$PREVIOUS" >/dev/null 2>&1; then
  die "[$ENV] no existe api-$PREVIOUS: no hay versión anterior a la cual volver"
fi
PREV_VERSION="$(kubectl -n "$ENV" get deploy "api-$PREVIOUS" -o jsonpath='{.metadata.annotations.taskflow/version}')"
log "[$ENV] ROLLBACK: $CURRENT -> $PREVIOUS (v$PREV_VERSION)"
kubectl -n "$ENV" scale "deploy/api-$PREVIOUS" --replicas=1
kubectl -n "$ENV" rollout status "deploy/api-$PREVIOUS" --timeout=120s
switch_to "$ENV" "$PREVIOUS"
kubectl -n "$ENV" rollout undo deploy/frontend >/dev/null 2>&1 || true
kubectl -n "$ENV" rollout status deploy/frontend --timeout=120s
if [ -n "${GITHUB_OUTPUT:-}" ]; then echo "version=$PREV_VERSION" >> "$GITHUB_OUTPUT"; fi
log "[$ENV] Rollback completado. Versión en servicio: v$PREV_VERSION"
