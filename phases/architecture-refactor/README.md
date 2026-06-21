# Phase 5: Architecture Refactor – Split Namespaces & Helm Charts (Kong, Redis, DB)

Phase 5 focuses on **architecture refactoring**: splitting Kong, Redis, Postgres (DB) into **separate namespaces** and **separate Helm charts**, no longer bundled in the banking-demo chart. Goal: easier to scale new features and give Kong its **own DB** for use (Kong DB mode).

## Goals

- **Split namespaces**: Kong → separate namespace (e.g. `kong` or `api-gateway`), Redis → `redis`, Postgres (app DB) → `postgres` or `data`; banking app keeps namespace `banking` and connects via cross-namespace DNS.
- **Split Helm charts**: Kong, Redis, Postgres each gets its own chart (or chart per group), no longer in `phases/helm-chart/banking-demo`. The banking-demo chart only contains **application** (frontend, auth-service, account-service, transfer-service, notification-service) + Ingress pointing to Kong.
- **Kong dedicated DB**: Kong switches from declarative file mode (`KONG_DATABASE: "off"`) to **DB mode** (dedicated Postgres for Kong), enabling config/route management via Admin API and easier Kong scaling.
- **Scalability**: Split architecture allows adding new services, gateways, or shared DB/Redis for multiple apps without affecting banking chart.

## Directory Structure

```text
architecture-refactor/
├── README.md                         # This file – Phase 5 overview (architecture)
├── postgres-ha/                      # Deploy Postgres HA + migrate data
│   ├── README.md                     # Step-by-step guide
│   ├── values-postgres-ha.yaml       # Bitnami PostgreSQL values (HA)
│   └── migrate-db-job.yaml           # Job to migrate old DB → new DB
├── kong-ha/                          # Deploy Kong HA with Postgres
│   ├── README.md                     # Step-by-step guide
│   ├── values-kong-ha.yaml           # Kong values (DB mode, 2 replicas)
│   ├── kong-db-init-job.yaml         # Job to create kong DB on Postgres
│   ├── kong-import-job.yaml          # Job to import declarative config into DB
│   └── kong-declarative.yaml         # Config services/routes/plugins (FQDN)
├── redis-ha/                         # Deploy Redis HA + migrate
│   ├── README.md
│   ├── values-redis-ha.yaml          # Bitnami Redis values (master + replica)
│   └── migrate-redis-job.yaml        # Job to migrate session/presence to new Redis
├── APP-CUTOVER.md                    # Guide to switch app to new DB/Redis/Kong
└── architecture/
    ├── NAMESPACE-SPLIT.md            # Split namespaces: banking, kong, redis, postgres; DNS, connections
    ├── KONG-DEDICATED-DB.md          # Kong dedicated DB (DB mode), benefits, migration
    ├── HELM-CHART-SPLIT.md           # Split Helm charts; use existing charts (Kong, Bitnami Redis/Postgres)
    └── PHASE2-TO-PHASE5-MAPPING.md   # HA (Kong/Redis/Postgres), config mapping Phase 2 → Phase 5, app changes
```

**Security & Reliability** (JWT, Kong plugins, CI security, SLO/alerts) moved to **Phase 7**: `phases/security-reliability/`.

## Implementation Roadmap (suggested)

1. **Namespace split** – read `architecture/NAMESPACE-SPLIT.md`. Deploy: create namespaces `kong`, `redis`, `postgres`; deploy Kong, Redis, Postgres into each ns; update banking app to connect via FQDN.
2. **Helm chart split** – read `architecture/HELM-CHART-SPLIT.md`. Kong, Redis, Postgres **use existing charts** (Kong official, Bitnami Redis, Bitnami PostgreSQL); banking-demo chart only contains app + Ingress pointing to Kong (cross-namespace).
3. **Kong dedicated DB** – read `architecture/KONG-DEDICATED-DB.md`. Deploy dedicated Postgres for Kong; switch Kong to DB mode; migrate config from kong.yml to Admin API or db_import.
4. **Phase 2 → Phase 5 mapping** – read `architecture/PHASE2-TO-PHASE5-MAPPING.md`: Kong/Redis/Postgres HA, config mapping to existing charts, Application **no code changes needed** (only change connection string via values/Secret).
5. **Security & Reliability** – see **Phase 7** (`phases/security-reliability/`).

## Prerequisites

- **Phase 2** Helm chart banking-demo is running (currently Kong, Redis, Postgres in same chart/namespace `banking`).
- Basic understanding of Kubernetes DNS (cross-namespace FQDN: `<svc>.<ns>.svc.cluster.local`).

## Related Phases

- **Phase 2**: `phases/helm-chart/banking-demo` – current chart (will be simplified after split).
- **Phase 3**: Monitoring still scrapes cross-namespace (Prometheus can scrape Kong, Redis, Postgres in different ns).
- **Phase 6**: Deployment strategies (blue-green/canary) still apply to app in ns `banking`; Kong/Redis/DB can rollout independently.
- **Phase 7**: Security & Reliability – `phases/security-reliability/`.
