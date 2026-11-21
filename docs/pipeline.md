# Diseño del pipeline CI/CD

```mermaid
flowchart TB
  subgraph CI["CI · ci.yml · ubuntu-latest"]
    A[Checkout<br/><i>actions/checkout</i>] --> B
    subgraph B[Test estático]
      B1[Ruff lint+format]:::t
      B2[Bandit SAST]:::s
      B3[ESLint + HTMLHint]:::t
      B4[Hadolint Dockerfiles]:::s
      B5[terraform fmt/validate]:::t
      B6[kubeconform K8s]:::t
    end
    A --> U
    subgraph U[Test unitario + cobertura · matrix]
      U1[pytest + pytest-cov ≥80%]:::t
      U2[node --test + c8 ≥80%]:::t
    end
    B & U --> C[Build imágenes<br/><i>docker buildx + cache GHA</i>]
    C --> D[Trivy scan<br/>falla en CRITICAL]:::s
    D --> R{push a develop/main?}
    R -- no: feature/PR --> X([fin CI])
    R -- sí --> E[Release<br/><i>semantic-release</i><br/>tag vX.Y.Z / vX.Y.Z-rc.N<br/>GitHub Release]:::n
    E --> F[Push artefacto a GHCR<br/>taskflow-api/frontend:X.Y.Z]
  end
  F --> CD
  subgraph CD["CD · cd.yml (reutilizable) · self-hosted runner kind"]
    I[IaC: terraform init/plan/apply<br/>kind + namespaces + quotas]:::n --> S1
    S1[Deploy staging<br/>blue/green · deploy.sh] --> T1
    T1[Tests pre-prod en staging<br/>smoke.sh · pytest E2E · k6 carga]:::t
    T1 -- falla --> RB1[Rollback auto staging<br/>rollback.sh]:::r
    T1 -- ok y rama main --> AP{{Aprobación manual<br/>GitHub Environment production}}:::n
    AP --> P1[Deploy production<br/>blue/green · deploy.sh]
    P1 --> T2[Tests post-prod<br/>smoke.sh vs versión]:::t
    T2 -- falla --> RB2[Rollback auto production<br/>rollback.sh + smoke]:::r
    T2 -- ok --> OK([✅ Release en producción])
    RB1 & RB2 & OK --> N[Notificación<br/>Discord webhook + Job Summary]:::n
  end
  PANIC[[🚨 rollback.yml<br/>botón de pánico<br/>workflow_dispatch]]:::r -.-> P1
  classDef t fill:#dbeafe,stroke:#1e40af
  classDef s fill:#fee2e2,stroke:#991b1b
  classDef n fill:#dcfce7,stroke:#166534
  classDef r fill:#fde68a,stroke:#92400e
```

Leyenda: azul = pruebas · rojo = seguridad · verde = mejoras de pipeline · amarillo = rollback.

## Herramientas por paso

| Etapa | Paso | Herramienta |
|---|---|---|
| CI | Checkout | `actions/checkout@v4` |
| CI | Test estático | Ruff, Bandit, ESLint, HTMLHint, Hadolint, Terraform validate, kubeconform |
| CI | Test unitario + cobertura | pytest + pytest-cov (umbral 80%), node:test + c8 (umbral 80%) |
| CI | Build | Docker Buildx (`docker/build-push-action`) con caché GHA |
| CI | Seguridad imagen | Trivy (`aquasecurity/trivy-action`) |
| CI | Release | semantic-release (Conventional Commits) → tag + GitHub Release; imágenes en GHCR |
| CD | IaC + Deploy infra | Terraform (`tehcyx/kind`, `hashicorp/kubernetes`) → cluster + 2 namespaces |
| CD | Deploy app (×2 ambientes) | kustomize overlays + `scripts/deploy.sh` (blue/green) |
| CD | Tests pre-prod | `scripts/smoke.sh`, pytest + httpx (E2E), k6 (carga) |
| CD | Aprobación | GitHub Environments (required reviewers) |
| CD | Tests post-prod | `scripts/smoke.sh` contra el puerto público de production |
| CD | Rollback automático | job `rollback-*` con `if: failure()` → `scripts/rollback.sh` |
| CD | Rollback manual | `rollback.yml` (workflow_dispatch = botón de pánico) |
| CD | Notificación | composite action `.github/actions/notify` (Discord) + Job Summary |
