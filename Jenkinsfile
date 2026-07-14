cd "$HOME/banking-demo"

set -Eeuo pipefail

REGISTRY="kamloicc.jfrog.io/banking-docker-local/banking-demo"
TAG="$(git rev-parse --short=12 HEAD)-multiarch-test"
BUILD_ID="${BUILD_NUMBER:-local-$(date +%s)}"
BUILDER="banking-${BUILD_ID}"

docker buildx create \
  --name "$BUILDER" \
  --driver docker-container \
  --use

cleanup() {
  docker buildx rm "$BUILDER" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker buildx inspect --bootstrap

for SERVICE in \
  auth-service \
  account-service \
  transfer-service \
  notification-service
do
  echo
  echo "Building ${SERVICE}:${TAG}"

  docker buildx build \
    --builder "$BUILDER" \
    --platform linux/amd64,linux/arm64 \
    --file "services/${SERVICE}/Dockerfile" \
    --tag "${REGISTRY}/${SERVICE}:${TAG}" \
    --push \
    .
done

echo
echo "Building frontend:${TAG}"

docker buildx build \
  --builder "$BUILDER" \
  --platform linux/amd64,linux/arm64 \
  --tag "${REGISTRY}/frontend:${TAG}" \
  --push \
  ./frontend
