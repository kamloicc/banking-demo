# Detailed Guide to Helm Chart Structure

This document is for beginners: explaining the **folder structure**, **what Helm is used for**, and **how the files connect together**.

---

## 1. What is Helm and Why Use It?

- **Phase 1** (folder `docker-to-k8s`): You have many Kubernetes YAML files (namespace, deployment, service, …). Every time you change port, image, env you have to manually edit each file.
- **Phase 2**: Convert everything to **Helm chart**. Instead of hardcoding in YAML, we use **variables** (values). To change configuration you only need to edit **values** or pass **override** when installing, no need to edit each manifest.

**Main benefits:**

- One command install: `helm install banking-demo ./banking-demo -n banking` → deploys namespace, database, gateway, all services, frontend, ingress.
- Configuration per environment: dev/staging/prod only differs in values file or `--set`.
- Easy enable/disable components: for example disable ingress with `--set ingress.enabled=false`.

---

## 2. Overall Directory Structure

```
helm-chart/
├── README.md              ← You are reading this
├── PHASE2.md              ← Technical summary, install/upgrade commands
├── helm-quickstart/       ← Simple Helm example for beginners (see section 8)
└── banking-demo/          ← Main (umbrella) chart for entire application
    ├── Chart.yaml         ← Chart metadata (name, version, description)
    ├── values.yaml        ← Default configuration for ALL components
    ├── templates/         ← ALL template files (Deployment, Service, …) — centralized
    │   ├── _helpers.tpl
    │   ├── namespace.yaml
    │   ├── secret.yaml
    │   ├── postgres-*.yaml, redis-*.yaml, kong-*.yaml
    │   ├── *-service-*.yaml (auth, account, transfer, notification)
    │   ├── frontend-*.yaml
    │   ├── ingress.yaml
    │   └── NOTES.txt
    └── charts/            ← Each service: ONLY has Chart.yaml + values.yaml (no templates)
        ├── postgres/
        ├── redis/
        ├── kong/
        ├── auth-service/
        ├── account-service/
        ├── transfer-service/
        ├── notification-service/
        └── frontend/
```

**Design concept:**

- **Centralized templates**: All files that create Kubernetes manifests (Deployment, Service, ConfigMap, …) are in **one** directory `banking-demo/templates/`. Easy to find, easy to modify consistently.
- **One folder per service (values only)**: In `charts/<service-name>/` there are **only** `Chart.yaml` and `values.yaml`. This folder does **not** contain template files; used to **override** configuration (e.g., image, port, env) when deploying.

---

## 3. Important Parts in `banking-demo/`

### 3.1. `Chart.yaml`

- **Role**: Declares what the chart is (name, description, version, appVersion, …).
- **What beginners need to know**: This is the chart's "passport". Helm uses it to identify the chart; it doesn't contain runtime configuration (port, image, …).

```yaml
name: banking-demo
description: Banking Demo - Helm bootstrap chart ...
version: 0.1.0
appVersion: "1"
```

This chart does **not** use `dependencies` (subchart). Configuration is in `values.yaml` and files in `charts/<service>/values.yaml`.

---

### 3.2. `values.yaml` (at banking-demo root)

- **Role**: **Default** configuration file for the **entire** application. All templates in `templates/` get values from here (via `.Values.postgres`, `.Values.redis`, `.Values.kong`, `.Values.auth-service`, …).
- **What beginners need to know**:
  - If you **don't** pass `-f` or `--set`, Helm will use **all** values from this file.
  - When you use `-f charts/auth-service/values.yaml` or `--set postgres.storage.size=2Gi`, Helm **merges** with this file: where you override it uses your value, everything else keeps default.

**Structure in `values.yaml` (summary):**

| Section | Meaning |
|---------|---------|
| `global` | Namespace, Secret name, CORS, imagePullSecrets — shared |
| `namespace` | Enable/disable namespace creation (e.g., `banking`) |
| `secret` | Enable/disable and content of Secret (DB user/password, URL) |
| `postgres` | Image, port, storage, probe, resources, hook … |
| `redis` | Similar to postgres |
| `kong` | Image, port, backends, CORS, config … |
| `auth-service`, `account-service`, … | Image, port, env, probe, resources … |
| `frontend` | Image, port, env … |
| `ingress` | Host, class, paths (route to which service, which port) |

Each key (e.g., `postgres`, `auth-service`) **matches the folder name** in `charts/`. To override only for one service, you can edit `charts/<service>/values.yaml` and use `-f charts/<service>/values.yaml` when `helm install` or `helm upgrade`.

---

### 3.3. `templates/` Directory

- **Role**: Contains **all** template files. Each file is one (or a few) Kubernetes manifest(s), but with placeholders to **fill in variables** (name, image, port, …) from `values.yaml`.
- **What beginners need to know**:
  - Templates use **Go template** syntax (Helm extended): `{{ .Values.postgres.image.tag }}`, `{{ include "banking-demo.postgres.fullname" . }}`, …
  - When Helm runs `helm install` or `helm template` it **renders**: replaces all `{{ ... }}` with actual values, then sends rendered YAML to cluster (or prints to screen).

**Mapping table: template file ↔ Kubernetes resource**

| File in templates/ | Creates what resource |
|--------------------|----------------------|
| `namespace.yaml` | Namespace (e.g., `banking`) |
| `secret.yaml` | Secret (DB password, URL, …) |
| `postgres-statefulset.yaml` | StatefulSet Postgres |
| `postgres-service.yaml` | Service Postgres |
| `redis-statefulset.yaml` | StatefulSet Redis |
| `redis-service.yaml` | Service Redis |
| `kong-configmap.yaml` | ConfigMap for Kong configuration |
| `kong-deployment.yaml` | Deployment Kong |
| `kong-service.yaml` | Service Kong |
| `auth-service-deployment.yaml` | Deployment auth-service |
| `auth-service-service.yaml` | Service auth-service |
| (similar) `account-service-*`, `transfer-service-*`, `notification-service-*` | Deployment + Service per service |
| `frontend-deployment.yaml`, `frontend-service.yaml` | Deployment + Service frontend |
| `ingress.yaml` | Ingress (HTTP routing) |
| `_helpers.tpl` | Doesn't create resource; contains shared functions (fullname, labels, …) for other templates |
| `NOTES.txt` | Text printed after installation (user instructions) |

Example in template: `{{ $svc := index .Values "auth-service" }}` and `{{ $svc.image.repository }}` — means "get the configuration section with key `auth-service` from values, then get `image.repository`". That value is in `values.yaml` (parent) or overridden by `charts/auth-service/values.yaml`.

---

### 3.4. `charts/<service>/` Directory

- **Role**: Each service (postgres, redis, kong, auth-service, …) has **one folder**. In the folder there are **only** two files:
  - `Chart.yaml`: metadata of "subchart" (name, version) — in current design chart doesn't load dependency so just for reference/organization.
  - `values.yaml`: **Override values** for that specific service.
- **What beginners need to know**:
  - There is **no** `templates` directory in each `charts/<service>/`. Real templates are in `banking-demo/templates/`.
  - When you run:  
    `helm install banking-demo ./banking-demo -n banking -f charts/auth-service/values.yaml`  
    Helm will merge `charts/auth-service/values.yaml` with parent `values.yaml`. Keys in the override file (e.g., `auth-service.image.tag`) will overwrite the same key in parent.

Example in `charts/auth-service/values.yaml` you can set:

```yaml
fullnameOverride: auth-service
image:
  repository: registry.gitlab.com/.../auth-service
  tag: v1
service:
  port: 8001
```

What you **don't** declare here will be taken from `banking-demo/values.yaml` (the `auth-service:` section).

---

## 4. Flow: values → template → manifest

1. You run Helm command, e.g.:  
   `helm install banking-demo ./banking-demo -n banking`
2. Helm reads:
   - `values.yaml` (parent),
   - (if any) files `-f file1.yaml -f file2.yaml` and `--set key=value`.
3. Merges all into one `.Values` set (later file / --set overwrites earlier).
4. For **each file** in `templates/` (except files starting with `_`), Helm **renders** content: replaces `{{ ... }}` with values from `.Values` and helpers.
5. Some files have conditionals `{{- if .Values.xxx.enabled }}`. If `enabled: false` then that manifest section is not created.
6. Result: a complete set of Kubernetes YAML. Helm sends to cluster (install/upgrade) or prints (template).

---

## 5. Overriding Configuration (common for beginners)

- **Override with file** (common for per-service or per-environment):

  ```bash
  helm install banking-demo ./banking-demo -n banking -f charts/auth-service/values.yaml
  ```

  Or use custom filename:

  ```bash
  helm install banking-demo ./banking-demo -n banking -f my-dev-values.yaml
  ```

- **Override a few values quickly** (use `--set`):

  ```bash
  helm install banking-demo ./banking-demo -n banking --set postgres.storage.size=2Gi
  ```

- **Disable a component** (e.g., disable ingress):

  ```bash
  helm install banking-demo ./banking-demo -n banking --set ingress.enabled=false
  ```

Key structure must match what's in `values.yaml` (e.g., `postgres.storage.size`, `ingress.enabled`).

---

## 6. Basic Helm Commands (in helm-chart directory)

- **Check chart (lint):**  
  `helm lint ./banking-demo`

- **View manifests that will be applied (doesn't install to cluster):**  
  `helm template banking-demo ./banking-demo -n banking`

- **Install first time:**  
  `helm install banking-demo ./banking-demo -n banking --create-namespace`

- **Upgrade (after editing values/template):**  
  `helm upgrade banking-demo ./banking-demo -n banking`

- **View installed releases:**  
  `helm list -n banking`

- **Uninstall:**  
  `helm uninstall banking-demo -n banking`

---

## 7. Summary for Beginners

| You want to… | Do this |
|--------------|---------|
| Understand "what this chart contains" | Look at `Chart.yaml` and `values.yaml` structure (top-level keys: postgres, redis, kong, auth-service, …). |
| Know "which YAML file creates Deployment/Service X" | Go to `banking-demo/templates/`, find corresponding name (e.g., `auth-service-deployment.yaml`). |
| Change default configuration for whole chart | Edit `banking-demo/values.yaml`. |
| Change configuration for only one service (e.g., auth-service) | Edit `banking-demo/charts/auth-service/values.yaml` and use `-f charts/auth-service/values.yaml` when install/upgrade. |
| Quickly change 1-2 values when installing | Use `--set postgres.storage.size=2Gi` (example). |
| View actual YAML before installing | Run `helm template banking-demo ./banking-demo -n banking`. |

---

## 8. Learn Helm from Simple: `helm-quickstart` Example

In helm-chart there's an additional directory **`helm-quickstart/`**: a **very small** chart (example with one Deployment + one Service). It has:

- Minimal Helm structure: `Chart.yaml`, `values.yaml`, `templates/` with few files.
- README with step-by-step guide: `helm template`, `helm install`, `--set`, `-f`, `helm upgrade`.

You should try commands in `helm-quickstart/` first before diving deep into `banking-demo` structure. Once familiar with how values + templates create manifests, you'll see phase2 is just "bigger chart, more services" using the same approach.

Details in file: **`helm-quickstart/README.md`**.
