# Phase 6: Deployment Strategies (Blue-Green & Canary)

Phase 6 focuses on **rollout strategies** on Kubernetes: Blue-Green and Canary to safely deploy new versions with easy rollback.

## Goals

- Understand **Blue-Green**: two environments (blue = current, green = new), switch traffic at once.
- Understand **Canary**: route some traffic to new version, gradually increase or rollback if errors.
- Apply with **Phase 2 Helm chart** (banking-demo) and can combine with **Phase 3** (metrics) to decide promote/rollback.

## Directory Structure

```text
deployment-strategies/
├── README.md                     # This file – overview + checklist
├── helm-deployment-strategies/   # Separate Helm chart for Phase 6 (not mixed with Phase 2)
│   ├── Chart.yaml
│   ├── values.yaml
│   ├── values-blue-green.yaml
│   ├── values-canary.yaml
│   ├── README.md
│   └── templates/
│       ├── _helpers.tpl
│       ├── deployment-slot.yaml
│       ├── service-slot.yaml
│       └── service-active.yaml
├── blue-green/
│   └── BLUE-GREEN.md             # Blue-Green design with K8s/Helm
└── canary/
    └── CANARY.md                 # Canary design with K8s/Ingress or Argo Rollouts
```

## Quick Comparison

| Strategy   | Concept                    | Rollback              | Resources      |
|-------------|----------------------------|------------------------|-----------------|
| **Rolling** | K8s default: update pods gradually | Automatic (rollback revision) | 1 deployment    |
| **Blue-Green** | 2 versions (blue/green), switch traffic | Change Service/Ingress → blue | 2 versions running |
| **Canary**  | % traffic to new version | Decrease % or delete canary       | 2 versions, 1 gets less traffic |

## Phase 6 Helm Chart (separate, not mixed with Phase 2)

Phase 6 has **a separate Helm chart** in `helm-deployment-strategies/`:

- **Chart**: `banking-deployment-strategies` – deploys banking services (auth, account, transfer, notification) using **Blue-Green** or **Canary** strategy.
- **How to use**: Disable corresponding services in Phase 2 (auth-service, account-service, …), then install Phase 6 chart in same namespace `banking`. Kong (Phase 2) still points to names `auth-service`, `account-service` – Phase 6 chart creates these Services with blue/green or stable selectors.
- **Details**: see `helm-deployment-strategies/README.md`.

## Implementation Roadmap (suggested)

1. **Blue-Green** – use chart `helm-deployment-strategies` with `strategy: blueGreen`; read `blue-green/BLUE-GREEN.md`.
   - Two Deployments + two Services; Ingress points to "active" Service (blue or green). Change Ingress/Service when promoting.
   - Or one Service with changing selector (version label): deploy green, change selector → green receives traffic.
2. **Canary** – read `canary/CANARY.md`. Can implement with:
   - Ingress (HAProxy/NGINX) supporting traffic split by weight or header.
   - Or Argo Rollouts / Flagger for automated canary + analysis based on Prometheus (Phase 3).
3. **Combine Phase 3** – use SLO/error rate from Prometheus to decide canary promotion or rollback (see Phase 7 `phases/security-reliability/sre/SLO-ALERTING.md`).

## Prerequisites

- **Phase 2** Helm chart banking-demo is running (namespace `banking`).
- (Recommended) **Phase 3** monitoring installed (Prometheus + Grafana) to monitor canary/blue-green when switching traffic.
- **Phase 4** if rolling out v2 image: build v2 image, use same chart with different tag for green/canary.

## Reference Commands

**Phase 6 chart (recommended):**

```bash
cd phases/deployment-strategies/helm-deployment-strategies
helm upgrade -i banking-rollout . -n banking -f values.yaml -f values-blue-green.yaml
helm upgrade banking-rollout . -n banking -f values.yaml -f values-blue-green.yaml --set activeSlot=green  # promote
```

**Phase 2** (only use when not using Phase 6 chart): `phases/helm-chart/banking-demo` – installs banking-demo; when using Phase 6 chart **disable** auth-service, account-service, transfer-service, notification-service in Phase 2 to avoid name conflicts.
