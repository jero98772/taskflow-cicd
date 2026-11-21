# Arquitectura de software e infraestructura

TaskFlow tiene **2 componentes desplegables** (frontend Nginx + API FastAPI) y una capa de datos
(SQLite sobre un PersistentVolume). Se despliega sobre **Kubernetes (kind)** aprovisionado con
**Terraform**, en **2 ambientes aislados** (namespaces `staging` y `production`).

```mermaid
flowchart LR
  user([👤 Usuario / navegador])
  subgraph GH[GitHub]
    repo[(Repositorio<br/>main · develop · feature/*)]
    gha[GitHub Actions<br/>runners ubuntu-latest]
    ghcr[(GHCR<br/>taskflow-api / taskflow-frontend<br/>tags semver)]
    rel[GitHub Releases<br/>notas + tag vX.Y.Z]
  end
  subgraph HOST[Host · self-hosted runner label kind]
    runner[Actions runner<br/>docker · kind · kubectl · terraform]
    subgraph KIND[Cluster kind 'taskflow' · creado con Terraform]
      subgraph STG[namespace staging · quota + limitrange + configmap]
        sfe[Deployment frontend<br/>Nginx :8080] --> ssvc{{Service api<br/>selector color}}
        ssvc --> sb[api-blue] & sg[api-green]
        sb & sg --> spvc[(PVC api-data<br/>SQLite)]
      end
      subgraph PRD[namespace production · quota + limitrange + configmap]
        pfe[Deployment frontend x2<br/>Nginx :8080] --> psvc{{Service api<br/>selector color}}
        psvc --> pb[api-blue] & pg[api-green]
        pb & pg --> ppvc[(PVC api-data<br/>SQLite)]
      end
    end
  end
  repo --> gha --> ghcr
  gha --> rel
  gha -. jobs CD .-> runner
  runner -->|pull| ghcr
  runner -->|kind load + kubectl apply| KIND
  user -->|:8080 NodePort 30080| sfe
  user -->|:8081 NodePort 30081| pfe
```

## Equivalencia con AWS (lo visto en clase)

| AWS (clase)            | Este proyecto (kind)                              |
|------------------------|---------------------------------------------------|
| ECR                    | GHCR (GitHub Container Registry)                  |
| ECS Cluster            | Cluster Kubernetes kind (Terraform `tehcyx/kind`) |
| ECS Service / Task     | Deployment / Pod                                  |
| ALB + Target Groups    | NodePort + Service `api` con selector `color`     |
| CodeDeploy Blue/Green  | `scripts/deploy.sh` + `scripts/rollback.sh`       |
| Cuenta/VPC por ambiente| Namespace + ResourceQuota + LimitRange por ambiente |

## Flujo de una petición
1. El navegador entra a `http://localhost:8081` (production) → NodePort 30081 → Pod Nginx.
2. Nginx sirve la SPA y hace de **gateway**: `/api/*`, `/health`, `/version` → Service `api:8000`.
3. El Service `api` envía el tráfico **sólo** a los Pods del color activo (`blue` o `green`).
4. Ambos colores montan el mismo PVC, por lo que los datos sobreviven al cambio de versión y al rollback.

## Blue/Green
```mermaid
sequenceDiagram
  participant CD as Pipeline CD
  participant G as api-green (nueva vX.Y.Z)
  participant S as Service api
  participant B as api-blue (actual)
  Note over S,B: tráfico 100% → blue
  CD->>G: kubectl apply (versión nueva)
  CD->>G: rollout status + smoke interno (/version == X.Y.Z)
  CD->>S: patch selector color=green (anota previous-color=blue)
  Note over S,G: tráfico 100% → green · blue queda vivo (standby)
  CD->>S: smoke post-prod vía puerto público
  alt smoke falla / botón de pánico
    CD->>S: patch selector color=blue  (rollback en ~1 s)
  end
```
