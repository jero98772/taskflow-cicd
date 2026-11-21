# TaskFlow · CI/CD end-to-end sobre Kubernetes

Gestor de tareas con **2 componentes** (frontend Nginx/JS + API FastAPI con SQLite persistente) entregado
con un pipeline completo de **CI/CD en GitHub Actions**: análisis estático, pruebas unitarias con cobertura,
escaneo de seguridad, versionado semántico automático, IaC con Terraform, **2 ambientes** (staging y
production) en Kubernetes (kind), despliegue **Blue/Green**, pruebas pre y post producción, **aprobación
manual**, **rollback automático** y **botón de pánico**.

| Documento | Contenido |
|---|---|
| [docs/pipeline.md](docs/pipeline.md) | Flujograma del pipeline y herramientas por paso |
| [docs/architecture.md](docs/architecture.md) | Arquitectura de software/infra y Blue/Green |
| [docs/branching.md](docs/branching.md) | Estrategia de ramas y qué corre en cada evento |
| [docs/tests.md](docs/tests.md) | Matriz de pruebas (qué, dónde, por qué) |
| [presentation/TaskFlow_CICD.pptx](presentation/TaskFlow_CICD.pptx) | Slides de la sustentación |

## Funcionalidades
- Crear, listar, filtrar (pendientes/completadas), completar y eliminar tareas con prioridad.
- Estadísticas de avance (`/api/tasks/stats`).
- `/health` (liveness/readiness) y `/version` (versión, color blue/green y ambiente — visible en la UI).

## Estructura
```
api/                FastAPI + SQLAlchemy, tests pytest, Dockerfile multi-stage no-root
frontend/           SPA JS + Nginx (gateway /api), tests node:test + c8
infra/terraform/    IaC: cluster kind + namespaces staging/production + quotas + configmaps
k8s/                kustomize base + overlays por ambiente; plantillas blue/green
scripts/            deploy.sh (blue/green) · rollback.sh · smoke.sh
tests/e2e/          pruebas E2E pre-prod (pytest + httpx)
tests/load/         prueba de carga k6
.github/workflows/  ci.yml · cd.yml (reutilizable) · rollback.yml (botón de pánico)
```

## Las mejoras sobre el pipeline base
1. **Seguridad shift-left**: Bandit (SAST), Hadolint y Trivy (bloquea CVEs CRITICAL). Detectó CVEs reales
   (starlette, zlib, nginx) que se corrigieron actualizando dependencias e imágenes base.
2. **Blue/Green en Kubernetes**: dos Deployments por ambiente y un Service que conmuta por selector;
   smoke interno antes de enviar tráfico y rollback en ~1 s.
3. **Versionado semántico automático**: semantic-release + Conventional Commits → tags, GitHub Releases,
   pre-releases `-rc` en develop. La misma versión se promueve de staging a production.
4. **Aprobación manual + notificaciones**: GitHub Environment `production` con required reviewers;
   notificaciones a Discord y Job Summaries.
5. **IaC sin nube**: Terraform aprovisiona el cluster kind y ambos ambientes con cuotas y límites.

## Ejecutar en local
```bash
# Dev rápido
docker compose up --build            # http://localhost:8090

# Ambientes completos (como lo hace el CD)
cd infra/terraform
terraform init -backend-config="path=$HOME/.taskflow/terraform.tfstate"
terraform apply                      # crea kind + staging + production
cd ../..
docker build -t taskflow-api:1.0.0 api && docker build -t taskflow-frontend:1.0.0 frontend
scripts/deploy.sh staging 1.0.0 && scripts/smoke.sh staging 1.0.0        # http://localhost:8080
scripts/deploy.sh production 1.0.0 && scripts/smoke.sh production 1.0.0  # http://localhost:8081
scripts/rollback.sh production       # vuelve al color anterior
```

## Configuración en GitHub (una sola vez)
1. **Self-hosted runner** (Settings → Actions → Runners → New self-hosted runner) en la máquina con
   docker, kind, kubectl y terraform; agregar la etiqueta **`kind`**.
2. **Environments**: `staging` (sin reglas) y `production` con *Required reviewers*.
3. **Secret opcional** `DISCORD_WEBHOOK` para notificaciones.
4. Settings → Actions → General → *Workflow permissions*: **Read and write**.
5. Ramas protegidas `main` y `develop` exigiendo el check de CI.

## Pruebas locales
```bash
cd api && pip install -r requirements-dev.txt && ruff check . && bandit -r app && pytest --cov
cd frontend && npm ci && npm run lint && npm test
BASE_URL=http://localhost:8080 pytest tests/e2e
```

## Guion de demo (sustentación, ~15 min)
Repositorio: https://github.com/jero98772/taskflow-cicd · staging http://localhost:8080 · production http://localhost:8081

1. **Runner arriba**: `cd ~/actions-runner-taskflow && ./run.sh` (debe verse *online* en Settings → Actions → Runners).
2. **Cambio real**: rama `feature/x` desde `develop`, commit `feat: ...`, PR a `develop` → CI como gate.
3. Merge → CI + pre-release `vX.Y.Z-rc.1` → CD despliega en **staging** (mostrar el color en la UI).
4. PR `develop` → `main`, merge → release `vX.Y.Z` → staging → pre-prod → **aprobar** en *Review deployments*
   → production Blue/Green → post-prod. Mostrar la GitHub Release y las imágenes en *Packages*.
5. **Rollback automático**: Actions → CD → *Run workflow* con `simulate_failure = true` → ver el job
   *Rollback automático production*.
6. **Botón de pánico**: Actions → *Rollback manual* → production → la UI cambia de color al instante.

Runs de evidencia ya ejecutados: CI+CD completo en `main` (v1.0.0 en ambos ambientes), rollback manual en
staging, CD con fallo simulado y rollback automático en production, CI+CD de `develop` a staging.
