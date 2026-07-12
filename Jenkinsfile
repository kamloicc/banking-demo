pipeline {
    agent any

    options {
        skipDefaultCheckout(true)
        timestamps()
        disableConcurrentBuilds()
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Verify repository') {
            steps {
                sh '''
                    set -eu

                    echo "Remote repository:"
                    git config --get remote.origin.url

                    echo "Checked-out commit:"
                    git rev-parse --short HEAD

                    echo "Validating project structure..."

                    test -f backend/requirements.txt
                    test -f common/requirements.txt
                    test -f frontend/package.json

                    test -f services/auth-service/main.py
                    test -f services/account-service/main.py
                    test -f services/transfer-service/main.py
                    test -f services/notification-service/main.py

                    echo "Repository integration is valid."
                '''
            }
        }
    }

    post {
        success {
            echo 'Jenkins successfully checked out the banking-demo repository.'
        }

        failure {
            echo 'Repository checkout or validation failed. Review the Console Output.'
        }
    }
}
