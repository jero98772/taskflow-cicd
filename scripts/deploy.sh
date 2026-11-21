#!/usr/bin/env bash
# Despliegue Blue/Green de TaskFlow en un ambiente (namespace) del cluster kind.
# Uso: scripts/deploy.sh <staging|production> <version> [api_image] [frontend_image]
source "$(dirname "$0")/lib.sh"

ENV="${1:?ambiente requerido}"
VERSION="${2:?version requerida}"
API_IMAGE="${3:-taskflow-api:$VERSION}"
FRONT_IMAGE="${4:-taskflow-frontend:$VERSION}"

log "Cargando imágenes en kind ($CLUSTER)"
kind load docker-image "$API_IMAGE" "$FRONT_IMAGE" --name "$CLUSTER" >/dev/null

log "[$ENV] Aplicando recursos compartidos (kustomize overlay)"
kubectl kustomize "$ROOT/k8s/overlays/$ENV" \
  | sed "s#image: taskflow-frontend:latest#image: $FRONT_IMAGE#" \
  | kubectl apply -f -

if ! kubectl -n "$ENV" get svc api >/dev/null 2>&1; then
  log "[$ENV] Primer despliegue: creando Service api"
  kubectl -n "$ENV" apply -f "$ROOT/k8s/bluegreen/api-service.yaml"
  FIRST=1
fi

ACTIVE="$(active_color "$ENV")"
if [ "${FIRST:-0}" = 1 ]; then TARGET="$ACTIVE"; else TARGET="$(other_color "$ACTIVE")"; fi
log "[$ENV] Color activo: $ACTIVE -> desplegando $VERSION en: $TARGET"

COLOR="$TARGET" IMAGE="$API_IMAGE" VERSION="$VERSION" \
  envsubst '${COLOR} ${IMAGE} ${VERSION}' < "$ROOT/k8s/bluegreen/api-deployment.tpl.yaml" \
  | kubectl -n "$ENV" apply -f -

kubectl -n "$ENV" rollout status "deploy/api-$TARGET" --timeout=180s
kubectl -n "$ENV" rollout status deploy/frontend --timeout=180s

log "[$ENV] Smoke interno sobre api-$TARGET antes de recibir tráfico"
kubectl -n "$ENV" exec "deploy/api-$TARGET" -- python -c \
  "import urllib.request,json;r=json.load(urllib.request.urlopen('http://127.0.0.1:8000/version'));assert r['version']=='$VERSION',r;print(r)"

if [ "${FIRST:-0}" != 1 ]; then switch_to "$ENV" "$TARGET"; fi

# Exporta el resultado para GitHub Actions
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  { echo "active=$TARGET"; echo "previous=$ACTIVE"; } >> "$GITHUB_OUTPUT"
fi
log "[$ENV] OK -> http://localhost:$(env_port "$ENV") (color $TARGET, v$VERSION)"
