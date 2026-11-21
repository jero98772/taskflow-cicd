#!/usr/bin/env bash
# Utilidades comunes para los scripts de despliegue.
set -euo pipefail
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/taskflow-config}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLUSTER="${CLUSTER:-taskflow}"

log() { printf '\033[1;34m[%s]\033[0m %s\n' "$(date +%H:%M:%S)" "$*"; }
die() { printf '\033[1;31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

env_port() {
  case "$1" in
    staging) echo 8080 ;;
    production) echo 8081 ;;
    *) die "ambiente desconocido: $1" ;;
  esac
}

active_color() {
  kubectl -n "$1" get svc api -o jsonpath='{.spec.selector.color}' 2>/dev/null || true
}

other_color() { [ "$1" = "blue" ] && echo green || echo blue; }

# Conmuta el Service api al color indicado y guarda el anterior en una anotación.
switch_to() {
  local ns="$1" target="$2" current
  current="$(active_color "$ns")"
  kubectl -n "$ns" patch svc api --type merge -p \
    "{\"spec\":{\"selector\":{\"color\":\"$target\"}},\"metadata\":{\"annotations\":{\"taskflow/active-color\":\"$target\",\"taskflow/previous-color\":\"$current\"}}}"
  log "[$ns] tráfico conmutado: $current -> $target"
}
