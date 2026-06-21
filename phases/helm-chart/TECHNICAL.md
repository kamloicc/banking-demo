# Phase 2: Helm Chart (Bootstrap)

Converting manifests from **phases/docker-to-k8s** to Helm following **bootstrap** style, with three main principles:

1. **Each service is a separate folder (values only)**: In `charts/<service>/` there is **only** `Chart.yaml` and `values.yaml`; no `templates` directory in each service.
2. **Centralized templates**: **All** template files (deployment, service, configmap, …) are **together** in `banking-demo/templates/`, easy to edit and maintain consistency.
3. **Highly parameterized templates**: Port, probe, resources, env, paths… all come from values, minimize hardcoding.

## Structure

```
helm-chart/
└── banking-demo/                 # Umbrella chart
    ├── Chart.yaml                # No dependencies (standalone chart)
    ├── values.yaml               # Default config for ALL components (postgres, redis, kong, auth-service, …)
    ├── templates/                # ALL templates for every service (centralized)
    │   ├── _helpers.tpl
    │   ├── namespace.yaml
    │   ├── secret.yaml
    │   ├── ingress.yaml
    │   ├── postgres-statefulset.yaml
    │   ├── postgres-service.yaml
    │   ├── redis-statefulset.yaml
    │   ├── redis-service.yaml
    │   ├── kong-configmap.yaml
    │   ├── kong-deployment.yaml
    │   ├── kong-service.yaml
    │   ├── auth-service-deployment.yaml
    │   ├── auth-service-service.yaml
    │   ├── account-service-deployment.yaml
    │   ├── account-service-service.yaml
    │   ├── transfer-service-deployment.yaml
    │   ├── transfer-service-service.yaml
    │   ├── notification-service-deployment.yaml
    │   ├── notification-service-service.yaml
    │   ├── frontend-deployment.yaml
    │   ├── frontend-service.yaml
    │   └── NOTES.txt
    └── charts/                   # Each service: ONLY Chart.yaml + values.yaml (no templates)
        ├── postgres/
        │   ├── Chart.yaml
        │   └── values.yaml
        ├── redis/
        │   ├── Chart.yaml
        │   └── values.yaml
        ├── kong/
        │   ├── Chart.yaml
        │   └── values.yaml
        ├── auth-service/
        │   ├── Chart.yaml
        │   └── values.yaml
        ├── account-service/
        ├── transfer-service/
        ├── notification-service/
        └── frontend/
```

- **Parent (`banking-demo`)**: `values.yaml` contains complete default config for all components (matching keys: `postgres:`, `redis:`, `kong:`, `auth-service:`, …). Override on install: `-f charts/<service>/values.yaml` or `--set …`.
- **Per-service folder (`charts/<service>/`)**: **Only** `Chart.yaml` and `values.yaml`; used to override values when deploying, no templates. All manifests rendered from `banking-demo/templates/`.

## Template Parameterization

Values not hardcoded in templates, taken from values:

- **Port / service**: `service.port`, `service.portName`, `proxyPort`, `adminPort` (Kong).
- **Probe**: `readinessProbe.enabled`, `path`, `port`, `initialDelaySeconds`, `periodSeconds`, `timeoutSeconds`; postgres/redis use `readinessProbe.command` or `user` (pg_isready).
- **Resources**: `resources.requests` / `limits` in values per chart.
- **Secret**: `secretRef.name`, `secretRef.keys.*` (key name in Secret).
- **Storage**: `storage.storageClassName`, `size`, `volumeName`, `mountPath`.
- **Security**: `securityContext.pod`, `securityContext.container`.
- **Kong**: `backends` (list of services, url, routes, paths), `corsOrigins`, `corsMethods`, `corsHeaders`; `env` key-value.
- **Ingress**: `ingress.paths[]` with `path`, `pathType`, `serviceName`, `servicePort`.

Override from parent or edit directly in `charts/<service>/values.yaml` as needed.

## Bootstrap Design

- **One release, multiple subcharts**: Install once `helm install banking-demo ./banking-demo -n banking` to deploy namespace, secret, postgres, redis, kong, 4 microservices, frontend and ingress.
- **Enable/disable per component**: Each subchart has `enabled: true/false`. Override from parent: `--set postgres.enabled=false` or in values file.
- **Global**: `global.namespace`, `global.secretName`, `global.corsOrigins`, `global.imagePullSecrets` (parent); subcharts receive overrides via matching key, e.g. `auth-service.secretRef.name`.
- **Deploy order (Helm hooks)**: Namespace (-10) → Secret (-8) → Postgres, Redis (-5) → Kong and remaining services.

## Installation

**Preparation:** StorageClass (e.g. `nfs-client`), imagePullSecrets in namespace (`dockerhub-registry`, `gitlab-registry`), or override in values per chart.

```bash
cd helm-chart
helm install banking-demo ./banking-demo -n banking --create-namespace
```

**View manifests before installing:**

```bash
helm template banking-demo ./banking-demo -n banking
```

**Deploy only part (e.g. only infra):** Override `enabled` for each subchart (key matches folder name):

```yaml
# values-infra-only.yaml
auth-service:
  enabled: false
account-service:
  enabled: false
transfer-service:
  enabled: false
notification-service:
  enabled: false
frontend:
  enabled: false
kong:
  enabled: false
ingress:
  enabled: false
```

```bash
helm install banking-demo ./banking-demo -n banking -f values-infra-only.yaml
```

## Upgrade / Override

- General upgrade: `helm upgrade banking-demo ./banking-demo -n banking`
- Disable service: `--set notification-service.enabled=false`
- Change service image: `--set auth-service.image.tag=v2` or edit `charts/auth-service/values.yaml`

## Phase 1 → Phase 2 Mapping

| Phase 1 (manifest)   | Phase 2 (Helm) |
|----------------------|----------------|
| namespace.yaml       | templates/namespace.yaml |
| secret.yaml          | templates/secret.yaml |
| postgres             | templates/postgres-*.yaml ; values: values.yaml + charts/postgres/values.yaml |
| redis                | templates/redis-*.yaml ; values: values.yaml + charts/redis/values.yaml |
| kong-configmap + kong | templates/kong-*.yaml ; values: values.yaml + charts/kong/values.yaml |
| auth/account/transfer/notification-service | templates/*-service-*.yaml ; values: charts/<service>/values.yaml |
| frontend              | templates/frontend-*.yaml ; values: charts/frontend/values.yaml |
| ingress.yaml         | templates/ingress.yaml (paths parameterized) |

## Deploy with ArgoCD (GitOps)

To deploy chart using ArgoCD (Git as source of truth, auto sync):

- Configure Application/ApplicationSet in **`argocd/`** (`application.yaml`, `application-set.yaml`).
- Environment-specific values: **`banking-demo/values-production.yaml`**, **`banking-demo/values-staging.yaml`** (override when using ArgoCD).
- Detailed guide: **`argocd/ARGOCD.md`**.

## Notes

- **Passwords:** Used for demo in values; prod should use `--set secret.postgresPassword=...` or uncommitted values file / external secrets.
- **Ingress:** Host, class, paths configured in `values.ingress`; backend `serviceName`/`servicePort` match `fullnameOverride` and port of each subchart.
- **Edit one service:** Adjust `charts/<service>/values.yaml` (override) or parent `values.yaml`. Templates for all services are in `banking-demo/templates/`, not in per-service folders.
- **ArgoCD:** Deploy via GitOps following guide in `argocd/ARGOCD.md`.
