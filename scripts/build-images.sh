#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

BUILDER="${CNB_BUILDER:-heroku/builder:24}"
TARGET_PLATFORM="${TARGET_PLATFORM:-linux/arm64}"
IMAGE_TAG="${IMAGE_TAG:-$(git -C "${ROOT_DIR}" rev-parse --short=12 HEAD)}"

JFROG_REGISTRY="${JFROG_REGISTRY:-}"
JFROG_REPOSITORY="${JFROG_REPOSITORY:-}"

COMPONENT_NAMESPACE="banking-demo"

CONTEXT_ROOT="${ROOT_DIR}/.cnb-contexts"
PUBLISHED_FILE="${ROOT_DIR}/published-images.txt"

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
docker buildx version >/dev/null

REMOTE_PREFIX="${JFROG_REGISTRY}/${JFROG_REPOSITORY}/${COMPONENT_NAMESPACE}"

rm -rf "${CONTEXT_ROOT}"
mkdir -p "${CONTEXT_ROOT}"

: > "${PUBLISHED_FILE}"

echo "Container build configuration:"
echo "  Python builder:  ${BUILDER}"
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

verify_remote_platform() {
    local image="$1"

    local expected_os
    local expected_architecture
    local platform_part
    local image_config

    expected_os="${TARGET_PLATFORM%%/*}"

    platform_part="${TARGET_PLATFORM#*/}"
    expected_architecture="${platform_part%%/*}"

    echo "Checking image platform for ${image}..."

    image_config="$(
        docker buildx imagetools inspect "${image}" \
            --format '{{json .Image}}'
    )"

    if ! printf '%s' "${image_config}" |
        grep -q "\"os\":\"${expected_os}\""; then

        echo \
            "Image ${image} does not have the expected " \
            "operating system ${expected_os}." >&2

        printf '%s\n' "${image_config}" >&2
        return 1
    fi

    if ! printf '%s' "${image_config}" |
        grep -q "\"architecture\":\"${expected_architecture}\""; then

        echo \
            "Image ${image} does not have the expected " \
            "architecture ${expected_architecture}." >&2

        printf '%s\n' "${image_config}" >&2
        return 1
    fi

    echo "Image platform verified: ${expected_os}/${expected_architecture}"
}

record_published_image() {
    local image="$1"

    printf '%s\n' "${image}" >> "${PUBLISHED_FILE}"
}

remove_python_cache_files() {
    local directory="$1"

    find "${directory}" \
        -type d \
        -name "__pycache__" \
        -prune \
        -exec rm -rf {} + \
        2>/dev/null || true

    find "${directory}" \
        -type f \
        -name "*.pyc" \
        -delete \
        2>/dev/null || true
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
    test -d "${ROOT_DIR}/common"
    test -f "${ROOT_DIR}/common/requirements.txt"

    rm -rf "${context}"
    mkdir -p "${context}"

    # Copy the shared application package.
    cp -R "${ROOT_DIR}/common" "${context}/common"

    # Copy the service source files into the application root.
    cp -R "${service_source}/." "${context}/"

    # Dockerfiles are not used for the Python Buildpack build.
    rm -f "${context}/Dockerfile"

    # Heroku's Python buildpack detects requirements.txt in the
    # application root.
    cp \
        "${ROOT_DIR}/common/requirements.txt" \
        "${context}/requirements.txt"

    # Select the Python runtime used by the Heroku builder.
    printf '%s\n' "3.11" > "${context}/.python-version"

    # Define the process that runs inside the final image.
    cat > "${context}/Procfile" <<EOF
web: python -m uvicorn main:app --host 0.0.0.0 --port ${service_port}
EOF

    remove_python_cache_files "${context}"

    echo "Building and publishing:"
    echo "  ${versioned_image}"
    echo "  ${latest_image}"

    pack build "${versioned_image}" \
        --path "${context}" \
        --builder "${BUILDER}" \
        --platform "${TARGET_PLATFORM}" \
        --pull-policy if-not-present \
        --trust-builder \
        --publish \
        --tag "${latest_image}"

    verify_remote_image "${versioned_image}"
    verify_remote_image "${latest_image}"

    verify_remote_platform "${versioned_image}"

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

    rm -rf "${context}"
    mkdir -p "${context}/build"

    cp -R \
        "${ROOT_DIR}/frontend/build/." \
        "${context}/build/"

    cat > "${context}/nginx.conf" <<'EOF'
worker_processes auto;
daemon off;

error_log /dev/stderr warn;
pid /tmp/nginx.pid;

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

    include /etc/nginx/mime.types;
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

        root /usr/share/nginx/html;
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

    cat > "${context}/Dockerfile" <<'EOF'
FROM nginx:stable-alpine

COPY nginx.conf /etc/nginx/nginx.conf
COPY build/ /usr/share/nginx/html/

EXPOSE 8080

CMD ["nginx"]
EOF

    cat > "${context}/.dockerignore" <<'EOF'
.git
.gitignore
Dockerfile*
README*
EOF

    echo "Building and publishing:"
    echo "  ${versioned_image}"
    echo "  ${latest_image}"

    docker buildx build \
        --platform "${TARGET_PLATFORM}" \
        --file "${context}/Dockerfile" \
        --tag "${versioned_image}" \
        --tag "${latest_image}" \
        --push \
        "${context}"

    verify_remote_image "${versioned_image}"
    verify_remote_image "${latest_image}"

    verify_remote_platform "${versioned_image}"

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
