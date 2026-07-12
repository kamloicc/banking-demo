pipeline {
    agent any

    options {
        skipDefaultCheckout(true)
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20'))
    }

    environment {
        PATH = "/opt/homebrew/bin:/usr/local/bin:${env.PATH}"

        CI = "true"

        IMAGE_PREFIX = "banking-demo"

        /*
         * Most cloud Kubernetes nodes use AMD64.
         * Change this to linux/arm64 when the deployment cluster is ARM.
         */
        TARGET_PLATFORM = "linux/amd64"
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

                    echo "Node:"
                    command -v node
                    node --version

                    echo "npm:"
                    command -v npm
                    npm --version

                    echo "Docker:"
                    command -v docker
                    docker --version
                    docker info >/dev/null

                    echo "Cloud Native Buildpacks Pack CLI:"
                    command -v pack
                    pack version
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

        stage('Build container images') {
            steps {
                sh '''
                    set -eu

                    chmod +x scripts/build-images.sh

                    IMAGE_TAG="$(cat .image-tag)" \
                    IMAGE_PREFIX="${IMAGE_PREFIX}" \
                    TARGET_PLATFORM="${TARGET_PLATFORM}" \
                    scripts/build-images.sh
                '''
            }
        }

        stage('Verify container images') {
            steps {
                sh '''
                    set -eu

                    image_tag="$(cat .image-tag)"

                    for component in \
                        auth-service \
                        account-service \
                        transfer-service \
                        notification-service \
                        frontend
                    do
                        image="${IMAGE_PREFIX}/${component}:${image_tag}"

                        docker image inspect "${image}" >/dev/null

                        architecture="$(
                            docker image inspect \
                                --format '{{.Os}}/{{.Architecture}}' \
                                "${image}"
                        )"

                        echo "${image} -> ${architecture}"
                    done
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

            echo 'Application and container image builds succeeded.'
        }

        failure {
            echo 'Application or image build failed. Review the first failed stage.'
        }
    }
}
