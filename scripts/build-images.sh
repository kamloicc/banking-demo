#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

BUILDER="${CNB_BUILDER:-paketobuildpacks/builder-jammy-base}"
TARGET_PLATFORM="${TARGET_PLATFORM:-linux/amd64}"
IMAGE_TAG="${IMAGE_TAG:-$(git -C "${ROOT_DIR}" rev-parse --short=12 HEAD)}"

JFROG_REGISTRY="${JFROG_REGISTRY:-}"
JFROG_REPOSITORY="${JFROG_REPOSITORY:-}"

CONTEXT_ROOT="${ROOT_DIR}/.cnb-contexts"
PUBLISHED_FILE="${ROOT_DIR}/published-images.txt"

COMPONENT_NAMESPACE="banking-demo"

require_variable() {
    local variable_name="$1"
    local variable_value="$2"

    if [[ -z "${variable_value}" ]]; then
        echo "Required environment variable ${variable_name} is not set." >&2
        exit 1
    fi
}

require_command() {
    local command_name="$1"

    if ! command -v "${command_name}" >/dev/null 2>&1; then
        echo "Required command '${command_name}' was not found." >&2
        exit 1
    fi
}

cleanup() {
    rm -rf "${CONTEXT_ROOT}"
}

trap cleanup EXIT

require_variable "JFROG_REGISTRY" "${JFROG_REGISTRY}"
require_variable "JFROG_REPOSITORY" "${JFROG_REPOSITORY}"

require_command git
require_command docker
require_command pack

docker info >/dev/null

REMOTE_PREFIX="${JFROG_REGISTRY}/${JFROG_REPOSITORY}/${COMPONENT_NAMESPACE}"

rm -rf "${CONTEXT_ROOT}"
mkdir -p "${CONTEXT_ROOT}"

: > "${PUBLISHED_FILE}"

echo "Cloud Native Buildpacks configuration:"
echo "  Builder:         ${BUILDER}"
echo "  Target platform: ${TARGET_PLATFORM}"
echo "  Image tag:       ${IMAGE_TAG}"
echo "  Registry:        ${JFROG_REGISTRY}"
echo "  Repository:      ${JFROG_REPOSITORY}"
echo "  Remote prefix:   ${REMOTE_PREFIX}"

verify_remote_image() {
    local image="$1"
    local attempt=1
    local maximum_attempts=12

    echo "Verifying remote image ${image}..."

    while [[ "${attempt}" -le "${maximum_attempts}" ]]; do
        if docker buildx imagetools inspect "${image}" \
            >/dev/null 2>&1; then
            echo "Remote image verified: ${image}"
            return 0
        fi

        echo \
            "Image is not visible yet; retrying " \
            "(${attempt}/${maximum_attempts})..."

        attempt=$((attempt + 1))
        sleep 5
    done

    echo "Unable to verify remote image: ${image}" >&2
    return 1
}

record_published_image() {
    local image="$1"

    printf '%s\n' "${image}" >> "${PUBLISHED_FILE}"
}

build_python_service() {
    local service_name="$1"
    local service_port="$2"

    local service_source="${ROOT_DIR}/services/${service_name}"
    local context="${CONTEXT_ROOT}/${service_name}"

    local versioned_image
    local latest_image

    versioned_image="${REMOTE_PREFIX}/${service_name}:${IMAGE_TAG}"
    latest_image="${REMOTE_PREFIX}/${service_name}:latest"

    echo
    echo "============================================================"
    echo "Preparing Python service: ${service_name}"
    echo "============================================================"

    test -d "${service_source}"
    test -f "${service_source}/main.py"
    test -f "${ROOT_DIR}/common/requirements.txt"

    mkdir -p "${context}"

    # Copy the shared application package.
    cp -R "${ROOT_DIR}/common" "${context}/common"

    # Copy the individual service source.
    cp -R "${service_source}/." "${context}/"

    # Dockerfiles are not used by Cloud Native Buildpacks.
    rm -f "${context}/Dockerfile"

    # Paketo's pip buildpack expects requirements.txt at the
    # application context root.
    cp \
        "${ROOT_DIR}/common/requirements.txt" \
        "${context}/requirements.txt"

    # Use python -m so the process does not depend on the uvicorn
    # executable being directly available on PATH.
    cat > "${context}/Procfile" <<EOF
web: python -m uvicorn main:app --host 0.0.0.0 --port ${service_port}
EOF

    # Remove local Python cache files from the build context.
    find "${context}" \
        -type d \
        -name "__pycache__" \
        -prune \
        -exec rm -rf {} + \
        2>/dev/null || true

    find "${context}" \
        -type f \
        -name "*.pyc" \
        -delete \
        2>/dev/null || true

    echo "Building and publishing:"
    echo "  ${versioned_image}"
    echo "  ${latest_image}"

    pack build "${versioned_image}" \
        --path "${context}" \
        --builder "${BUILDER}" \
        --buildpack paketo-buildpacks/python \
        --env "BP_CPYTHON_VERSION=3.11.*" \
        --platform "${TARGET_PLATFORM}" \
        --pull-policy if-not-present \
        --trust-builder \
        --publish \
        --tag "${latest_image}"

    verify_remote_image "${versioned_image}"
    verify_remote_image "${latest_image}"

    record_published_image "${versioned_image}"
    record_published_image "${latest_image}"

    echo "${service_name} was published successfully."
}

build_frontend() {
    local context="${CONTEXT_ROOT}/frontend"

    local versioned_image="${REMOTE_PREFIX}/frontend:${IMAGE_TAG}"
    local latest_image="${REMOTE_PREFIX}/frontend:latest"

    echo
    echo "============================================================"
    echo "Preparing frontend image"
    echo "============================================================"

    test -d "${ROOT_DIR}/frontend/build"
    test -f "${ROOT_DIR}/frontend/build/index.html"

    mkdir -p "${context}/build"

    cp -R \
        "${ROOT_DIR}/frontend/build/." \
        "${context}/build/"

    cat > "${context}/nginx.conf" <<'EOF'
worker_processes 1;
daemon off;

error_log /dev/stderr warn;

events {
    worker_connections 1024;
}

http {
    charset utf-8;

    access_log /dev/stdout;

    client_body_temp_path /tmp/nginx-client-body;
    proxy_temp_path       /tmp/nginx-proxy;
    fastcgi_temp_path     /tmp/nginx-fastcgi;
    uwsgi_temp_path       /tmp/nginx-uwsgi;
    scgi_temp_path        /tmp/nginx-scgi;

    types {
        text/html                       html htm;
        text/css                        css;
        text/plain                      txt;
        application/javascript         js;
        application/json               json;
        application/xml                xml;
        application/manifest+json      webmanifest;
        image/svg+xml                   svg;
        image/png                       png;
        image/jpeg                      jpg jpeg;
        image/gif                       gif;
        image/x-icon                    ico;
        font/woff                       woff;
        font/woff2                      woff2;
        application/octet-stream        bin;
    }

    default_type application/octet-stream;

    sendfile on;
    tcp_nopush on;
    keepalive_timeout 30;
    port_in_redirect off;

    gzip on;
    gzip_types
        text/plain
        text/css
        application/json
        application/javascript
        application/xml
        image/svg+xml;

    server {
        listen 8080;
        server_name _;

        root /workspace/build;
        index index.html;

        location = /health {
            access_log off;
            default_type text/plain;
            return 200 "ok\n";
        }

        location / {
            try_files $uri $uri/ /index.html;
        }

        location /api/ {
            proxy_pass http://kong:8000/api/;

            proxy_http_version 1.1;
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
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
}
EOF

    echo "Building and publishing:"
    echo "  ${versioned_image}"
    echo "  ${latest_image}"

    pack build "${versioned_image}" \
        --path "${context}" \
        --builder "${BUILDER}" \
        --buildpack paketo-buildpacks/nginx \
        --platform "${TARGET_PLATFORM}" \
        --pull-policy if-not-present \
        --trust-builder \
        --publish \
        --tag "${latest_image}"

    verify_remote_image "${versioned_image}"
    verify_remote_image "${latest_image}"

    record_published_image "${versioned_image}"
    record_published_image "${latest_image}"

    echo "Frontend was published successfully."
}

build_python_service "auth-service" 8001
build_python_service "account-service" 8002
build_python_service "transfer-service" 8003
build_python_service "notification-service" 8004

build_frontend

echo
echo "============================================================"
echo "All application images were published successfully"
echo "============================================================"
echo
cat "${PUBLISHED_FILE}"
