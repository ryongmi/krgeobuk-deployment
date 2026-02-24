// krgeobuk 통합 배포 파이프라인 Job 정의
// ENVIRONMENT(dev/prod), SERVICE(all/개별) 파라미터로 선택적 배포

def githubOrg = System.getenv('GITHUB_ORG') ?: 'your-org'

pipelineJob('krgeobuk-deploy') {
    description('krgeobuk 통합 배포 파이프라인 (dev/prod 전체 서비스)')

    logRotator {
        numToKeep(30)
    }

    parameters {
        choiceParam('ENVIRONMENT', ['dev', 'prod'], '배포 환경')
        choiceParam('SERVICE', [
            'all',
            'auth-server',
            'authz-server',
            'auth-client',
            'portal-client',
            'portal-server',
            'my-pick-server',
            'my-pick-client',
            'portal-admin-client',
            'my-pick-admin-client'
        ], '배포할 서비스 (all = 전체)')
        booleanParam('SKIP_TESTS', false, '테스트 건너뛰기')
        booleanParam('FORCE_BUILD', false, '변경사항 없어도 강제 빌드')
    }

    definition {
        cpsScm {
            scm {
                git {
                    remote {
                        url("https://github.com/${githubOrg}/krgeobuk-deployment.git")
                        credentials('github-credentials')
                    }
                    branch('*/main')
                }
            }
            scriptPath('jenkins/Jenkinsfile')
        }
    }
}
