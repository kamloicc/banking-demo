package com.bankingdemo

class GitOpsUpdater implements Serializable {

    /**
     * Cập nhật tag trong values-images.yaml rồi commit/push.
     * Production: dùng yq hoặc Groovy YAML parser; skeleton dùng sed đơn giản.
     */
    static void bumpImageTags(def steps, Map cfg, List<String> services) {
        def tag = steps.env.GIT_COMMIT?.take(7) ?: 'latest'
        def file = cfg.gitopsValuesFile

        services.each { svc ->
            def meta = PipelineConfig.SERVICES[svc]
            def helmKey = meta.helmKey
            steps.sh """
                set -e
                # Cập nhật tag dưới block helmKey (skeleton — thay bằng yq khi production)
                sed -i '/^${helmKey}:/,/^[^ ]/ s/^    tag: .*/    tag: ${tag}/' ${file} || true
            """
        }

        def repoUrl = cfg.gitRepoUrl.replace('https://', '')
        steps.withCredentials([steps.usernamePassword(
            credentialsId: cfg.gitopsCredId,
            usernameVariable: 'GIT_USER',
            passwordVariable: 'GIT_TOKEN',
        )]) {
            steps.sh """
                set -e
                git config user.email "jenkins@banking-demo.local"
                git config user.name "Jenkins CI"
                git add ${file}
                if git diff --cached --quiet; then
                  echo 'GitOps values unchanged'
                  exit 0
                fi
                git commit -m "ci: bump image tags to ${tag} [${services.join(', ')}]"
                git push https://\${GIT_USER}:\${GIT_TOKEN}@${repoUrl} HEAD:${cfg.gitBranch}
            """
        }
        steps.echo "Updated ${file} — ArgoCD will sync."
    }
}
