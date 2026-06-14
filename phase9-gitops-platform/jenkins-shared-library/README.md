# Jenkins Shared Library — banking-demo Phase 9

Thư viện dùng cho Pipeline CI: build image Kaniko → push Harbor → cập nhật GitOps.

## Cài đặt

1. Copy thư mục này vào repo Jenkins hoặc repo riêng `banking-demo-jenkins-library`.
2. Jenkins → **Manage Jenkins → System → Global Pipeline Libraries**:
   - Name: `banking-demo`
   - Default version: `main`
   - Retrieval method: Modern SCM → Git → URL repo library
3. Pipeline job dùng `@Library('banking-demo') _` + `jenkins/Jenkinsfile.example`.

## Entry point

```groovy
@Library('banking-demo') _

bankingDemoPipeline([
  harborHost: 'harbor.example.com',
  harborProject: 'banking-demo',
  gitBranch: 'main',
  gitopsValuesFile: 'phase9-gitops-platform/gitops/values-images.yaml',
])
```

## Services (Phase 8)

| Key | Dockerfile | Context |
|-----|------------|---------|
| api-producer | `phase8-application-v3/producer/Dockerfile` | `.` |
| auth-service | `phase8-application-v3/services/auth-service/Dockerfile` | `.` |
| account-service | `phase8-application-v3/services/account-service/Dockerfile` | `.` |
| transfer-service | `phase8-application-v3/services/transfer-service/Dockerfile` | `.` |
| notification-service | `phase8-application-v3/services/notification-service/Dockerfile` | `.` |

## Credentials Jenkins (gợi ý)

| ID | Mục đích |
|----|----------|
| `harbor-ci-push` | Username/password robot Harbor push |
| `github-gitops-push` | PAT push commit values-images.yaml |
| `github-webhook` | (tùy chọn) clone repo app |

Lưu credential trong Vault; Jenkins lấy qua plugin hoặc K8s Secret mount.

## Kaniko pod

Template: `../jenkins/pod-templates/kaniko-pod.yaml` — mount dockerconfig cho Harbor.
