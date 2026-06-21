package com.bankingdemo

class ChangeDetector implements Serializable {

    static List<String> detect(def steps, Map cfg) {
        def all = PipelineConfig.SERVICES.keySet() as List
        if (steps.env.FORCE_BUILD_ALL == 'true') {
            return all
        }
        def changed = [] as Set
        def prefix = cfg.watchPathPrefix ?: 'phase8-application-v3/'
        try {
            def diff = steps.sh(script: "git diff --name-only HEAD~1 HEAD 2>/dev/null || git diff --name-only origin/${cfg.gitBranch}...HEAD", returnStdout: true).trim()
            if (!diff) {
                steps.echo 'No diff — building all services (first run or shallow clone).'
                return all
            }
            diff.split('\n').each { path ->
                if (path.startsWith('phase8-application-v3/common/')) {
                    changed.addAll(all)
                } else {
                    PipelineConfig.SERVICES.each { name, meta ->
                        if (path.startsWith(meta.dockerfile.replace('/Dockerfile', '')) || path == meta.dockerfile) {
                            changed << name
                        }
                    }
                }
            }
        } catch (ignored) {
            steps.echo 'Change detection failed — build all.'
            return all
        }
        return changed ? changed as List : all
    }
}
