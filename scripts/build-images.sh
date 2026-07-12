#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

BUILDER="${CNB_BUILDER:-paketobuildpacks/builder-jammy-base}"
TARGET_PLATFORM="${TARGET_PLATFORM:-linux/amd64}"
IMAGE_PREFIX="${IMAGE_PREFIX:-banking-demo}"
IMAGE_TAG="${IMAGE_TAG:-$(git -C "${ROOT_DIR}" rev-parse --short=12 HEAD)}"

CONTEXT_ROOT="${ROOT_DIR}/.cnb-contexts"

rm -rf "${CONTEXT_ROOT}"
mkdir -p "${CONTEXT_ROOT}"

command -v docker >/dev/null
command -v pack >/dev/null

docker info >/dev/null

build_python_service() {
    service_name="$1"
    service_port="$2"

    context="${CONTEXT_ROOT}/${service_name}"
    latest_image="${IMAGE_PREFIX}/${service_name}:latest"
    versioned_image="${IMAGE_PREFIX}/${service_name}:${IMAGE_TAG}"

    echo
    echo "Preparing ${service_name} context..."

    mkdir -p "${context}"

    # Copy the shared Python modules.
    cp -R "${ROOT_DIR}/common" "${context}/common"

    # Copy the service source, excluding its Dockerfile.
    cp -R "${ROOT_DIR}/services/${service_name}/." "${context}/"
    rm -f "${context}/Dockerfile"

    # Paketo Pip detection expects requirements.txt in the application root.
    cp "${ROOT_DIR}/common/requirements.txt" \
       "${context}/requirements.txt"

    # Define the runtime process for this particular service.
    cat > "${context}/Procfile" <<EOF
web: uvicorn main:app --host 0.0.0.0 --port ${service_port}
EOF

    find "${context}" -type d -name "__pycache__" \
        -prune -exec rm -rf {} + 2>/dev/null || true

    find "${context}" -type f -name "*.pyc" \
        -delete 2>/dev/null || true

    echo "Building ${latest_image}..."

    pack build "${latest_image}" \
        --path "${context}" \
        --builder "${BUILDER}" \
        --buildpack paketo-buildpacks/python \
        --env "BP_CPYTHON_VERSION=3.11.*" \
        --platform "${TARGET_PLATFORM}" \
        --pull-policy if-not-present \
        --trust-builder

    docker tag "${latest_image}" "${versioned_image}"

    echo "Created ${versioned_image}"
}

build_frontend() {
    context="${CONTEXT_ROOT}/frontend"
    latest_image="${IMAGE_PREFIX}/frontend:latest"
    versioned_image="${IMAGE_PREFIX}/frontend:${IMAGE_TAG}"

    echo
    echo "Preparing frontend context..."

    test -f "${ROOT_DIR}/frontend/build/index.html"

    mkdir -p "${context}/build"

    cp -R "${ROOT_DIR}/frontend/build/." \
          "${context}/build/"

    # CNB images run as a non-root user, so use port 8080 instead of port 80.
    cat > "${context}/nginx.conf" <<'EOF'
worker_processes 1;
daemon off;
error_log stderr;

events {
    worker_connections 1024;
}

http {
    charset utf-8;

    log_format cnb 'NginxLog "$request" $status $body_bytes_sent';
    access_log /dev/stdout cnb;

    default_type application/octet-stream;
    include mime.types;

    sendfile on;
    tcp_nopush on;
    keepalive_timeout 30;
    port_in_redirect off;

    server {
        listen 8080;
        server_name _;

        root build;
        index index.html;

        location / {
            try_files $uri $uri/ /index.html;
        }

        location /api/ {
            proxy_pass http://kong:8000/api/;

            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        location /ws {
            proxy_pass http://kong:8000/ws;
            proxy_http_version 1.1;

            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }
    }
}
EOF

    echo "Building ${latest_image}..."

    pack build "${latest_image}" \
        --path "${context}" \
        --builder "${BUILDER}" \
        --buildpack paketo-buildpacks/nginx \
        --platform "${TARGET_PLATFORM}" \
        --pull-policy if-not-present \
        --trust-builder

    docker tag "${latest_image}" "${versioned_image}"

    echo "Created ${versioned_image}"
}

build_python_service "auth-service" 8001
build_python_service "account-service" 8002
build_python_service "transfer-service" 8003
build_python_service "notification-service" 8004

build_frontend

echo
echo "Verifying generated images..."

for component in \
    auth-service \
    account-service \
    transfer-service \
    notification-service \
    frontend
do
    image="${IMAGE_PREFIX}/${component}:${IMAGE_TAG}"

    docker image inspect "${image}" >/dev/null

    architecture="$(
        docker image inspect \
            --format '{{.Os}}/{{.Architecture}}' \
            "${image}"
    )"

    echo "${image} -> ${architecture}"
done

printf '%s\n' "${IMAGE_TAG}" > "${ROOT_DIR}/.image-tag"

echo
echo "All application images were built successfully."
