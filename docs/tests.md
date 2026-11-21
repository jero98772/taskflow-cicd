# Estrategia de pruebas

| # | Prueba | Herramienta | Ambiente | Qué valida | Por qué |
|---|---|---|---|---|---|
| 1 | Lint + formato Python | Ruff | CI | Estilo, imports, bugs comunes (B), sintaxis moderna (UP) | Código homogéneo y errores detectados antes de ejecutar |
| 2 | SAST | Bandit | CI | Patrones inseguros (SQL injection, `eval`, secretos, etc.) | Seguridad shift-left |
| 3 | Lint frontend | ESLint + HTMLHint | CI | JS (eqeqeq, no-unused-vars) y HTML válido | Evitar errores en runtime del navegador |
| 4 | Lint Dockerfiles | Hadolint | CI | Buenas prácticas de imagen (no-root, JSON CMD…) | Imágenes seguras y reproducibles |
| 5 | IaC | `terraform fmt/validate`, kubeconform | CI | Sintaxis Terraform y esquema de manifiestos K8s | Que la infraestructura no falle al desplegar |
| 6 | Unitarias API | pytest (14 tests) | CI (SQLite en memoria) | CRUD, validaciones 422, 404, filtros, estadísticas, config | Lógica de negocio aislada y rápida |
| 7 | Unitarias frontend | node:test (7 tests) | CI | Ordenamiento, filtros, validación de título, escape XSS | Lógica de UI sin navegador |
| 8 | Cobertura | pytest-cov / c8 | CI | **≥80%** obligatorio (actual: API 97%, frontend 100%) | Garantiza que las pruebas recorren el código |
| 9 | Escaneo de imagen | Trivy | CI | CVEs CRITICAL con fix disponible → falla | Detectó CVEs reales en starlette, zlib y nginx (corregidos) |
| 10 | Smoke interno | `deploy.sh` (kubectl exec) | staging / prod, color nuevo **antes** de recibir tráfico | `/version` == versión esperada | Nunca se conmuta tráfico a una versión rota |
| 11 | Smoke pre-prod | `smoke.sh` | staging | Frontend, gateway, health, API, versión y ambiente | Validación rápida de disponibilidad |
| 12 | E2E integración | pytest + httpx (7 tests) | staging | Ciclo completo de tarea a través de Nginx → API → PVC, errores 422, SPA fallback, assets | Valida la integración real de los 2 componentes |
| 13 | Carga ligera | k6 (10 VUs, 20 s) | staging | p95 < 500 ms, errores < 1% | Detecta regresiones de rendimiento antes de prod |
| 14 | Smoke post-prod | `smoke.sh` | production | Mismos chequeos no destructivos + versión desplegada | Confirma la salida a prod; si falla → **rollback automático** |
| 15 | Verificación de rollback | `smoke.sh` | production / staging | Que la versión restaurada responde | El rollback también se prueba |
