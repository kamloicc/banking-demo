# Harbor — Phase 9

Registry nội bộ cho CI (Jenkins Kaniko) và CD (ArgoCD pull image).

## Sau khi cài (Helm / ArgoCD `platform-harbor`)

1. Đăng nhập UI `https://harbor.example.com` — đổi admin password ngay.
2. Tạo project **`banking-demo`** (public hoặc private).
3. Tạo **Robot Accounts**:
   - `ci-push` — push image (Jenkins credential `harbor-ci-push`)
   - `k8s-pull` — pull only (dockerconfigjson Secret `harbor-registry`)

## K8s pull secret (ns banking, platform)

```bash
kubectl create secret docker-registry harbor-registry \
  --docker-server=harbor.example.com \
  --docker-username='robot$k8s-pull' \
  --docker-password='<TOKEN>' \
  -n banking

kubectl create secret docker-registry harbor-registry \
  --docker-server=harbor.example.com \
  --docker-username='robot$k8s-pull' \
  --docker-password='<TOKEN>' \
  -n platform
```

Production: sync từ Vault qua ExternalSecret (`secret/platform/harbor`).

## Image naming (khớp values-images.yaml)

```text
harbor.example.com/banking-demo/api-producer:<sha>
harbor.example.com/banking-demo/auth-service:<sha>
...
```

## TLS

Ingress Harbor cần cert hợp lệ hoặc `insecure-registry` trên node/Kaniko nếu lab dùng self-signed.
