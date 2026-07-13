pipeline {
    agent any

    options {
        skipDefaultCheckout(true)
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20'))
        timeout(time: 90, unit: 'MINUTES')
    }

    environment {
        /*
         * Homebrew paths:
         * Apple Silicon: /opt/homebrew/bin
         * Intel Mac:     /usr/local/bin
         */
        PATH = "/opt/homebrew/bin:/usr/local/bin:${env.PATH}"

        CI = "true"

        /*
         * Container image configuration.
         */
        IMAGE_PREFIX = "banking-demo"
        TARGET_PLATFORM = "linux/arm64"

        /*
         * Cloud Native Buildpacks builder.
         */
	CNB_BUILDER = "heroku/builder:24"
        /*
         * JFrog Artifactory configuration.
         */
        JFROG_REGISTRY = "kamloicc.jfrog.io"
        JFROG_REPOSITORY = "banking-docker-local"
    }

    stages {
        stage('Checkout') {
            steps {
                deleteDir()
                checkout scm

                sh '''
                    set -eu

                    git rev-parse --short=12 HEAD > .image-tag

                    echo "Repository: $(git config --get remote.origin.url)"
                    echo "Commit:     $(cat .image-tag)"
                '''
            }
        }

        stage('Verify toolchain') {
            steps {
                sh '''
                    set -eu

                    echo "Git:"
                    command -v git
                    git --version

                    echo
                    echo "Node:"
                    command -v node
                    node --version

                    echo
                    echo "npm:"
                    command -v npm
                    npm --version

                    echo
                    echo "Docker:"
                    command -v docker
                    docker --version
                    docker info >/dev/null

                    echo
                    echo "Docker Buildx:"
                    docker buildx version

                    echo
                    echo "Cloud Native Buildpacks Pack CLI:"
                    command -v pack
                    pack version

                    echo
                    echo "Toolchain validation completed."
                '''
            }
        }

        stage('Build frontend application') {
            steps {
                dir('frontend') {
                    sh '''
                        set -eu

                        rm -rf node_modules build

                        npm ci --no-audit --no-fund
                        npm run build

                        test -f build/index.html

                        echo "Frontend application build completed."
                    '''
                }
            }
        }

        stage('Build and publish images') {
            options {
                timeout(time: 75, unit: 'MINUTES')
            }

            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'jfrog-docker-credentials',
                        usernameVariable: 'JFROG_USERNAME',
                        passwordVariable: 'JFROG_PASSWORD'
                    )
                ]) {
                    sh '''
                        set -eu

                        # Disable shell tracing while credentials are available.
                        set +x

                        image_tag="$(cat .image-tag)"

                        cleanup_registry_login() {
                            docker logout "${JFROG_REGISTRY}" \
                                >/dev/null 2>&1 || true
                        }

                        trap cleanup_registry_login EXIT INT TERM

                        echo "Authenticating to JFrog registry..."

                        printf '%s' "${JFROG_PASSWORD}" |
                            docker login "${JFROG_REGISTRY}" \
                                --username "${JFROG_USERNAME}" \
                                --password-stdin

                        echo "JFrog authentication succeeded."

                        chmod +x scripts/build-images.sh

                        IMAGE_TAG="${image_tag}" \
                        IMAGE_PREFIX="${IMAGE_PREFIX}" \
                        TARGET_PLATFORM="${TARGET_PLATFORM}" \
                        CNB_BUILDER="${CNB_BUILDER}" \
                        JFROG_REGISTRY="${JFROG_REGISTRY}" \
                        JFROG_REPOSITORY="${JFROG_REPOSITORY}" \
                        scripts/build-images.sh
                    '''
                }
            }

            post {
                always {
                    sh '''
                        set +e

                        docker logout "${JFROG_REGISTRY}" \
                            >/dev/null 2>&1 || true
                    '''

                    archiveArtifacts(
                        artifacts: 'published-images.txt',
                        allowEmptyArchive: true,
                        fingerprint: true
                    )
                }
            }
        }

        stage('Display published images') {
            steps {
                sh '''
                    set -eu

                    test -s published-images.txt

                    echo
                    echo "Published images:"
                    cat published-images.txt
                '''
            }
        }
    }

    post {
        success {
            archiveArtifacts(
                artifacts: 'frontend/build/**',
                fingerprint: true
            )

            echo 'Application build and JFrog image publication succeeded.'
        }

        failure {
            echo 'Pipeline failed. Review the first failed stage in Console Output.'
        }

        cleanup {
            sh '''
                set +e

                docker logout "${JFROG_REGISTRY}" \
                    >/dev/null 2>&1 || true

                rm -rf .cnb-contexts
            '''
        }
    }
}
