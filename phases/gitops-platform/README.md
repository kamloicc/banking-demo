# Phase 9: GitOps Platform (ArgoCD + Jenkins CI/CD + Harbor Registry + Vault)

Phase 9 focuses on building a complete **GitOps platform**: ArgoCD for declarative K8s deployments, Jenkins for CI/CD pipelines, Harbor as private Docker registry, and Vault for secrets management.

## Goals

- **GitOps with ArgoCD**: Manage all K8s resources declaratively in Git; ArgoCD syncs repo → cluster automatically.
- **Jenkins CI/CD**: Build Docker images (Kaniko), run tests, push to Harbor, update GitOps repo to trigger ArgoCD deployment.
- **Harbor Registry**: Private Docker registry with vulnerability scanning, image signing, RBAC.
- **Vault**: Store secrets (DB passwords, API keys) securely; integrate with Kubernetes External Secrets Operator to inject secrets into Pods.

## Directory Structure

```text
gitops-platform/
├── README.md                           # This file – Phase 9 overview
├── argocd/
│   ├── README.md                       # ArgoCD setup guide
│   ├── app-of-apps.yaml                # Root Application (App of Apps pattern)
│   ├── project.yaml                    # ArgoCD Project for banking-demo
│   ├── deploy-all.sh                   # Script to deploy all Applications
│   ├── applications/
│   │   ├── banking-app-of-apps.yaml    # App of Apps for banking services
│   │   ├── infra-app-of-apps.yaml      # App of Apps for infrastructure (Kong, Redis, Postgres, RabbitMQ)
│   │   ├── platform-app-of-apps.yaml   # App of Apps for platform (Harbor, Vault, External Secrets)
│   │   ├── banking/                    # Individual Applications for banking services
│   │   ├── infra/                      # Individual Applications for infrastructure
│   │   └── platform/                   # Individual Applications for platform components
├── jenkins/
│   ├── Jenkinsfile.example             # Example Jenkinsfile using shared library
│   └── pod-templates/
│       └── kaniko-pod.yaml             # Pod template for Kaniko Docker builds
├── jenkins-shared-library/
│   ├── README.md                       # Shared Library usage guide
│   ├── src/com/bankingdemo/
│   │   ├── ChangeDetector.groovy       # Detect changed services in Git diff
│   │   ├── KanikoBuilder.groovy        # Build Docker images with Kaniko
│   │   ├── GitOpsUpdater.groovy        # Update image tags in GitOps repo
│   │   └── PipelineConfig.groovy       # Pipeline configuration
│   └── vars/
│       └── bankingDemoPipeline.groovy  # Main pipeline entry point
├── harbor/
│   └── README.md                       # Harbor installation and configuration
├── vault/
│   ├── README.md                       # Vault setup guide
│   └── external-secrets/
│       ├── cluster-secret-store.yaml   # ClusterSecretStore pointing to Vault
│       ├── banking-db-external-secret.yaml      # ExternalSecret for DB credentials
│       └── rabbitmq-external-secret.yaml        # ExternalSecret for RabbitMQ credentials
├── bootstrap/
│   └── BOOTSTRAP.md                    # Bootstrap guide: install ArgoCD, Harbor, Vault first
└── gitops/
    ├── values-gitops-env.yaml          # Environment-specific values (dev, staging, prod)
    └── values-images.yaml              # Image tags (updated by CI pipeline)
```

## Implementation Roadmap (suggested)

1. **Bootstrap Platform** – read `bootstrap/BOOTSTRAP.md`. Install ArgoCD, Harbor, Vault on cluster; configure ingress, RBAC, initial secrets.
2. **ArgoCD Setup** – read `argocd/README.md`. Create ArgoCD Project and Applications (App of Apps pattern); point to this repo; ArgoCD syncs `phases/helm-chart/banking-demo`.
3. **Harbor Registry** – read `harbor/README.md`. Install Harbor via Helm; create projects, users, robot accounts; configure vulnerability scanning.
4. **Vault & External Secrets** – read `vault/README.md`. Install Vault; store DB passwords, RabbitMQ credentials; install External Secrets Operator; create ExternalSecrets to inject secrets into banking namespace.
5. **Jenkins CI/CD** – read `jenkins-shared-library/README.md`. Install Jenkins on K8s; load shared library; create Jenkinsfile using `bankingDemoPipeline`; pipeline builds images with Kaniko, pushes to Harbor, updates GitOps repo → ArgoCD auto-deploys.

## Prerequisites

- Kubernetes cluster with Helm 3+ installed.
- `kubectl` and `helm` CLI access.
- Git repository for GitOps (can be this repo or a separate one for prod).
- (Recommended) Ingress controller (NGINX/Traefik) for ArgoCD, Harbor, Vault UIs.

## Key Concepts

- **GitOps**: Store desired state of infrastructure/apps in Git; tool (ArgoCD) continuously reconciles Git → cluster.
- **App of Apps Pattern**: Root Application in ArgoCD creates child Applications, enabling hierarchical management.
- **Kaniko**: Build Docker images inside Kubernetes Pods (no Docker daemon needed), suitable for CI/CD in K8s.
- **External Secrets Operator**: Sync secrets from external stores (Vault, AWS Secrets Manager) into K8s Secrets.
- **Jenkins Shared Library**: Reusable Groovy code for pipelines, reducing duplication across Jenkinsfiles.

## CI/CD Flow

1. Developer pushes code to Git repo.
2. GitHub/GitLab webhook triggers Jenkins pipeline.
3. Jenkins:
   - Detects changed services (ChangeDetector).
   - Builds Docker images with Kaniko (KanikoBuilder).
   - Pushes images to Harbor registry.
   - Updates image tags in GitOps repo (GitOpsUpdater).
4. ArgoCD detects change in GitOps repo.
5. ArgoCD applies new manifests/values to cluster → new Pods deployed.

## Related Phases

- **Phase 2**: `phases/helm-chart/banking-demo` – Helm chart managed by ArgoCD in Phase 9.
- **Phase 3**: `phases/monitoring-keda` – Monitoring stack can also be managed by ArgoCD.
- **Phase 7**: `phases/security-reliability` – CI security (image scanning, SAST) integrated in Jenkins pipeline.
