# Phase 1: Migrate from Docker to Kubernetes

Phase 1 focuses on **migrating the entire stack from Docker Compose to Kubernetes** with manifest files in this folder. Subsequent phases (monitoring, CI/CD, etc.) will have separate folders and documentation to avoid confusion.

- **Architecture diagram:** see [ARCHITECTURE.md](./ARCHITECTURE.md) (traffic flow, components, Mermaid diagram).

---

## Goals

- **Postgres**, **Redis**: run as **StatefulSet** (database/cache with state, need stable identity and storage).
- **Kong**: API Gateway (Deployment + ConfigMap).
- **Application services**: auth-service, account-service, transfer-service, notification-service (Deployment + Service).
- **Frontend**: Deployment + Service.
- **Ingress**: path-based via **HAProxy Ingress** (cluster already has HAProxy Ingress installed).
- **Storage**: PVC using **StorageClass `nfs-client`** (NFS server + NFS subdir provisioner).

---

## Manifest Structure in This Folder

| File | Description |
|------|-------------|
| `namespace.yaml` | Namespace `banking` |
| `secret.yaml` | DB Secret (Postgres user/pass, DATABASE_URL, REDIS_URL) |
| `postgres.yaml` | **StatefulSet** + Headless Service (volumeClaimTemplate for `/var/lib/postgresql/data`) |
| `redis.yaml` | **StatefulSet** + Headless Service (volumeClaimTemplate for `/data`) |
| `kong-configmap.yaml` | Kong config (routes `/api/auth`, `/api/account`, `/api/transfer`, `/api/notifications`, `/ws`) |
| `kong.yaml` | Kong Deployment (proxy 8000, admin 8001) |
| `kong-service.yaml` | Kong Service |
| `auth-service.yaml` | auth-service Deployment + Service (8001) |
| `account-service.yaml` | account-service Deployment + Service (8002) |
| `transfer-service.yaml` | transfer-service Deployment + Service (8003) |
| `notification-service.yaml` | notification-service Deployment + Service (8004) |
| `frontend.yaml` | frontend Deployment + Service (80) |
| `ingress.yaml` | HAProxy Ingress (/) → frontend, (/api, /ws) → kong |

---

## Deployment Order (kubectl apply)

Apply in correct order to ensure dependencies (DB/Redis first, then Kong, then services, finally Ingress).

```bash
# 1. Namespace + Secret
kubectl apply -f namespace.yaml
kubectl apply -f secret.yaml

# 2. Database & cache (StatefulSet)
kubectl apply -f postgres.yaml
kubectl apply -f redis.yaml

# Wait for Postgres and Redis to be ready (depends on cluster)
kubectl -n banking rollout status statefulset/postgres
kubectl -n banking rollout status statefulset/redis

# 3. Kong (needs ConfigMap first)
kubectl apply -f kong-configmap.yaml
kubectl apply -f kong.yaml -f kong-service.yaml

# 4. Applications
kubectl apply -f auth-service.yaml
kubectl apply -f account-service.yaml
kubectl apply -f transfer-service.yaml
kubectl apply -f notification-service.yaml
kubectl apply -f frontend.yaml

# 5. Ingress (cluster already has HAProxy Ingress)
kubectl apply -f ingress.yaml
```

**One command (apply entire folder):**

```bash
kubectl apply -f namespace.yaml -f secret.yaml
kubectl apply -f postgres.yaml -f redis.yaml
kubectl apply -f kong-configmap.yaml -f kong.yaml -f kong-service.yaml
kubectl apply -f auth-service.yaml -f account-service.yaml -f transfer-service.yaml -f notification-service.yaml -f frontend.yaml
kubectl apply -f ingress.yaml
```

---

## Notes

### StatefulSet for Postgres and Redis

- **Postgres**: `volumeClaimTemplates` creates PVC `pgdata-postgres-0`, mounts at `/var/lib/postgresql/data`. Pod has fixed name `postgres-0`, headless Service `postgres` (clusterIP: None). **StorageClass: `nfs-client`** (NFS subdir provisioner).
- **Redis**: `volumeClaimTemplates` creates PVC `redis-data-redis-0` (256Mi), mounts at `/data` for RDB/AOF if needed. Headless Service `redis`. **StorageClass: `nfs-client`**.

### Storage (NFS)

- Cluster uses **NFS server** and **NFS subdir provisioner**, StorageClass named **`nfs-client`**. Postgres and Redis PVCs all specify `storageClassName: nfs-client` to store on NFS.

### Images and Registry

- Manifests default to **images from GitLab Registry** and **imagePullSecrets: gitlab-registry**. Need to create Secret `gitlab-registry` in namespace `banking` if using private registry:

  ```bash
  kubectl -n banking create secret docker-registry gitlab-registry \
    --docker-server=registry.gitlab.com \
    --docker-username=<user> \
    --docker-password=<token>
  ```

- **Docker Hub rate limit (429 / ImagePullBackOff):** Images **postgres**, **redis**, **kong** pulled from Docker Hub. If cluster hits pull limit (error `429 Too Many Requests` / `toomanyrequests`), need to create Docker Hub login secret and declare `imagePullSecrets` to increase rate limit:

  ```bash
  kubectl -n banking create secret docker-registry dockerhub-registry \
    --docker-server=https://index.docker.io/v1/ \
    --docker-username=<username> \
    --docker-password=<password>
  ```

  Files `postgres.yaml`, `redis.yaml`, `kong.yaml` already declare `imagePullSecrets: - name: dockerhub-registry`. After creating secret, delete pods to pull images again (e.g., `kubectl delete pod redis-0 postgres-0 -n banking`, redeploy kong if needed).

- **Running with locally built images:** edit manifests: remove `imagePullSecrets`, set `imagePullPolicy: Never` and `image: <local-image-name>`.

### Ingress (HAProxy)

- Cluster has **HAProxy Ingress** installed. Ingress uses `ingressClassName: haproxy`, path-based: `/` → frontend, `/api` and `/ws` → Kong. Access via host/IP configured by HAProxy Ingress (e.g., LoadBalancer IP or hostname).

### Next Phases

- Phase 1 does **not** include monitoring (Prometheus, Grafana, Jaeger, Otel). Files in `k8s/monitoring/` and OTEL variables in services belong to later phases. The `k8s/` folder at root can be used for common phases or reference; everything needed for **just Docker → K8s migration** is in **phases/docker-to-k8s** folder and this **README.md** file.

---

## Quick Comparison with Docker Compose

| Docker Compose | Phase 1 (K8s) |
|----------------|---------------|
| `postgres` (volume pgdata) | StatefulSet `postgres` + volumeClaimTemplate |
| `redis` | StatefulSet `redis` + volumeClaimTemplate |
| `kong` + volume kong.yml | Kong Deployment + ConfigMap `kong-config` |
| `auth-service`, `account-service`, … | Deployment + Service per service |
| `frontend` | frontend Deployment + Service |
| Local port mapping | Ingress (path /, /api, /ws) |

After applying everything, the banking application can be used via Ingress equivalent to using Docker Compose (frontend + API via Kong).
