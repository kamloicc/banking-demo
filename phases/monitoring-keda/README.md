# Phase 3: Monitoring, Logging, Tracing & KEDA (HPA)

Phase 3 focuses on **comprehensive observability** (metrics, logging, tracing) and **autoscaling with KEDA**, including **load testing scenarios** to verify KEDA functions correctly.

---

## Goals

- **Monitoring:** Prometheus (metrics) + Grafana (dashboards). Phase3 deploys using **Helm** (pull chart, modify values) — see `helm-monitoring/`.
- **Logging:** Loki + Promtail (Helm). Pod logs → Promtail → Loki; Grafana queries Loki.
- **Tracing:** OpenTelemetry Collector + Tempo (Helm). App sends OTLP → Collector → Tempo. (Tempo is lighter than Jaeger, integrates well with Grafana)
- **KEDA:** Scale Deployments (auth, account, transfer, notification) based on **Prometheus metrics** (e.g. `http_requests_total` rate). Not using K8s default HPA.
- **Load test:** Scripts (k6) generate load on API → increase RPS → KEDA scales up; stop load → scale down. Includes instructions for running and checking results.

---

## Flow Diagram

- **Draw.io:** Open `phase3-flow.drawio` with [draw.io](https://app.diagrams.net/) to view/edit.
- **Mermaid + description:** See `PHASE3-FLOW.md`.

---

## Directory Structure

```
monitoring-keda/
├── README.md                 # This file
├── PHASE3-FLOW.md            # Flow diagram (Mermaid) + notes
├── METRICS-PERCENTILES.md    # Explains P50, P95, P99 and usage in dashboards/load tests
├── phase3-flow.drawio        # Draw.io diagram
├── helm-monitoring/          # Monitoring + Logging + Tracing (Helm)
│   ├── README.md             # Repos, install order, per chart
│   ├── values-kube-prometheus-stack.yaml  # Prometheus + Grafana
│   ├── values-loki.yaml      # Loki
│   ├── values-promtail.yaml  # Promtail → Loki
│   ├── values-tempo.yaml     # Tempo (tracing backend)
│   └── values-otel-collector.yaml  # OTEL Collector → Tempo
├── keda/
│   ├── README.md             # Install KEDA, apply ScaledObjects
│   ├── scaledobject-auth.yaml
│   ├── scaledobject-account.yaml
│   ├── scaledobject-transfer.yaml
│   └── scaledobject-notification.yaml
└── load-test/
    ├── README.md             # How to run, scenarios, KEDA evaluation
    ├── k6-auth.js            # Load /api/auth (login)
    ├── k6-account.js         # Load /api/account (me, balance)
    ├── k6-transfer.js        # Load /api/transfer
    └── run-scenarios.sh      # Run scenarios, command suggestions
```

---

## Prerequisites

1. **Banking app** is running (phase1 or phase2): namespace `banking`, services have `/metrics` and OTEL (if using tracing).
2. **Monitoring stack** in namespace `monitoring`:
   - **Phase3 recommended:** deploy using Helm per `helm-monitoring/README.md` (Prometheus + Grafana, Loki, Promtail, Tempo, OpenTelemetry Collector). Pull chart, modify `values-*.yaml`, then `helm install/upgrade`.
   - Or use `k8s/monitoring` (YAML manifests). See `OBSERVABILITY.md` and `k8s/monitoring/`.
3. **KEDA** installed on cluster (see `keda/README.md`).
4. **k6** installed locally or in container to run load tests (see `load-test/README.md`).

---

## Workflow (KEDA + load test)

1. **Prometheus** scrapes `http_requests_total` from each service. KEDA queries e.g.:
   - `sum(rate(http_requests_total{job="auth-service"}[2m]))`
2. **ScaledObject** compares query value with **threshold**. If > threshold → increase replica; if < **activationThreshold** (and conditions met) → decrease replica.
3. **Load test** sends many requests to `/api/auth`, `/api/account`, `/api/transfer` via Ingress or port-forward → RPS increases → KEDA scales up.
4. Stop load test → RPS decreases → after cooldown, KEDA scales down.

---

## Deployment Order (summary)

```bash
# 1. Monitoring + Logging + Tracing (Helm) — see helm-monitoring/README.md
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update
kubectl create namespace monitoring
helm upgrade -i kube-prometheus-stack prometheus-community/kube-prometheus-stack -n monitoring -f phases/monitoring-keda/helm-monitoring/values-kube-prometheus-stack.yaml
helm upgrade -i loki grafana/loki -n monitoring -f phases/monitoring-keda/helm-monitoring/values-loki.yaml
helm upgrade -i promtail grafana/promtail -n monitoring -f phases/monitoring-keda/helm-monitoring/values-promtail.yaml
helm upgrade -i tempo grafana/tempo -n monitoring -f phases/monitoring-keda/helm-monitoring/values-tempo.yaml
helm upgrade -i otel-collector open-telemetry/opentelemetry-collector -n monitoring -f phases/monitoring-keda/helm-monitoring/values-otel-collector.yaml

# 2. KEDA (operator + CRDs) — see keda/README.md
helm repo add kedacore https://kedacore.github.io/charts
helm upgrade -i keda kedacore/keda -n keda --create-namespace

# 3. ScaledObjects (after Prometheus has scraped metrics)
kubectl apply -f phases/monitoring-keda/keda/

# 4. Run load test and check scaling
cd phases/monitoring-keda/load-test && ./run-scenarios.sh
kubectl get hpa -n banking
```

## Notes

- **Grafana dashboards:** After installing kube-prometheus-stack, access Grafana (default NodePort or Ingress), add Loki and Tempo as datasources, import dashboards from `helm-monitoring/dashboards/`.
- **KEDA threshold tuning:** Each ScaledObject has `threshold`, `activationThreshold`, `minReplicaCount`, `maxReplicaCount`. Adjust based on service capacity and load patterns.
- **Load test duration:** k6 scripts have configurable VUs (virtual users) and duration. See `load-test/README.md` for scenarios.
- **Cooldown period:** KEDA scales down after metrics drop below activation threshold for stabilization window. Check ScaledObject status: `kubectl describe scaledobject -n banking`.

For detailed flow and architecture, see **PHASE3-FLOW.md**.
