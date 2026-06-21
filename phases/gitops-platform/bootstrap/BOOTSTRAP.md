# Bootstrap — Cài platform lần đầu

Một số thành phần **không thể** tự cài từ chính nó (gà/trứng). Thứ tự gợi ý:

## Thứ tự

| # | Thành phần | Cách cài | Ghi chú |
|---|------------|----------|---------|
| 1 | **ArgoCD** | `kubectl apply -n argocd -f install.yaml` | Đã có từ Phase 2 thì bỏ qua |
| 2 | **Namespaces** | `kubectl create ns platform vault external-secrets postgres redis kong rabbit banking` | Hoặc để ArgoCD `CreateNamespace=true` |
| 3 | **Harbor** | Helm / manifest + Ingress | Robot account `ci-push`, `k8s-pull` |
| 4 | **Vault** | Helm + init/unseal | KV path `secret/banking/*` |
| 5 | **External Secrets** | Helm ESO + `ClusterSecretStore` | Xem `vault/external-secrets/` |
| 6 | **Jenkins** | Helm + Shared Library + K8s cloud | ServiceAccount cho Kaniko |
| 7 | **AppProject** | `kubectl apply -f argocd/project.yaml` | |
| 8 | **App of Apps** | `kubectl apply -f argocd/app-of-apps.yaml` | |
| 9 | **Secrets qua Vault** | ExternalSecret sync | Thay `kubectl create secret` thủ công Phase 8 |
| 10 | **Kong Phase 8 import** | Job `phase8-application-v3/kong-ha/kong-import-job.yaml` | Sau Kong HA sync |

## Secret cần trong Vault (thay kubectl thủ công)

| Vault path | K8s Secret | Namespace |
|------------|------------|-----------|
| `secret/banking/db` | `banking-db-secret` | `banking` |
| `secret/banking/rabbitmq` | `rabbitmq-connection-secret` | `banking` |
| `secret/rabbitmq/admin` | `rabbitmq-secret` | `rabbit` |
| `secret/platform/harbor` | `harbor-registry` (dockerconfigjson) | `banking`, `platform` |
| `secret/platform/jenkins` | GitHub webhook / git push credential | `platform` |

## Sau bootstrap

1. Cấu hình Jenkins job từ `jenkins/Jenkinsfile.example`.
2. Push thay đổi `phase8-application-v3/` → CI chạy → kiểm tra `gitops/values-images.yaml` được commit.
3. ArgoCD sync `banking-demo-auth-service` (và các app khác) → verify rollout.

## Rollback

- ArgoCD UI → History → Rollback Application cụ thể.
- Image tag: revert commit trên `gitops/values-images.yaml`.
