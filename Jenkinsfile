pipeline {
    agent any

    options {
        skipDefaultCheckout(true)
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20'))
    }

    environment {
        /*
         * Homebrew locations:
         *   Apple Silicon: /opt/homebrew/bin
         *   Intel Mac:    /usr/local/bin
         */
        PATH = "/opt/homebrew/bin:/usr/local/bin:${env.PATH}"

        PIP_DISABLE_PIP_VERSION_CHECK = "1"
        PYTHONDONTWRITEBYTECODE = "1"
        CI = "true"
    }

    stages {
        stage('Checkout') {
            steps {
                deleteDir()
                checkout scm

                sh '''
                    set -eu

                    echo "Repository: $(git config --get remote.origin.url)"
                    echo "Branch:     $(git branch --show-current || true)"
                    echo "Commit:     $(git rev-parse --short HEAD)"
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

                    echo "Python:"
                    command -v python3.11
                    python3.11 --version

                    echo "Node:"
                    command -v node
                    node --version

                    echo "npm:"
                    command -v npm
                    npm --version
                '''
            }
        }

        stage('Install Python dependencies') {
            steps {
                sh '''
                    set -eu

                    rm -rf .venv
                    python3.11 -m venv .venv

                    . .venv/bin/activate

                    python -m pip install --upgrade pip
                    python -m pip install \
                        -r backend/requirements.txt \
                        -r common/requirements.txt
                '''
            }
        }

        stage('Validate Python code') {
            steps {
                sh '''
                    set -eu

                    . .venv/bin/activate

                    python -m compileall -q \
                        backend \
                        common \
                        services

                    echo "Python source validation succeeded."
                '''
            }
        }

        stage('Install frontend dependencies') {
            steps {
                dir('frontend') {
                    sh '''
                        set -eu
                        npm ci --no-audit --no-fund
                    '''
                }
            }
        }

        stage('Build frontend') {
            steps {
                dir('frontend') {
                    sh '''
                        set -eu

                        npm run build
                        test -f build/index.html

                        echo "Frontend build succeeded."
                    '''
                }
            }
        }
    }

    post {
        success {
            archiveArtifacts(
                artifacts: 'frontend/build/**',
                fingerprint: true
            )

            echo 'Application dependency installation and build succeeded.'
        }

        failure {
            echo 'Build failed. Open the first failed stage in Console Output.'
        }
    }
}
