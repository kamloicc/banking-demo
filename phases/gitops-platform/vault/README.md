# Vault + External Secrets — Phase 9

Thay `kubectl create secret` thủ công (Phase 8 README) bằng sync từ Vault.

## Vault paths (KV v2)

```text
secret/banking/db          → banking-db-secret (ns banking)
secret/banking/rabbitmq    → rabbitmq-connection-secret (ns banking)
secret/rabbitmq/admin      → rabbitmq-secret (ns rabbit)
secret/platform/harbor     → harbor-registry dockerconfigjson
```

Ví dụ seed (Vault dev mode):

```bash
vault kv put secret/banking/db \
  DATABASE_URL='postgresql://banking:bankingpass@postgres.postgres.svc.cluster.local:5432/banking' \
  REDIS_URL='redis://redis.redis.svc.cluster.local:6379/0'

vault kv put secret/banking/rabbitmq \
  RABBITMQ_URL='amqp://banking:PASSWORD@rabbitmq.rabbit.svc.cluster.local:5672/'
```

## Apply External Secrets

Sau khi ESO controller chạy:

```bash
kubectl apply -f phase9-gitops-platform/vault/external-secrets/
```

Hoặc qua ArgoCD Application `platform-external-secrets`.

## ClusterSecretStore

Chỉnh `vault/server` và `auth` trong `cluster-secret-store.yaml` cho môi trường thật (Kubernetes auth recommended).
