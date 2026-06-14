#!/usr/bin/env bash
# Apply Phase 9 App of Apps (Linux/Mac)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
kubectl apply -f "$ROOT/argocd/project.yaml" -n argocd
kubectl apply -f "$ROOT/argocd/app-of-apps.yaml" -n argocd
echo "Done. Open ArgoCD UI and sync banking-platform-root if needed."
