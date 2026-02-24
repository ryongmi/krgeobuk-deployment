// my-pick-admin-client CI/CD 파이프라인 Job 정의
// 수동 실행: Build with Parameters → ENVIRONMENT, GIT_BRANCH 선택

def githubOrg = System.getenv('GITHUB_ORG') ?: 'your-org'

pipelineJob('my-pick-admin-client-pipeline') {
    description('my-pick-admin-client CI/CD 파이프라인')

    logRotator {
        numToKeep(30)
    }

    parameters {
        choiceParam('ENVIRONMENT', ['dev', 'prod'], '배포 환경')
        stringParam('GIT_BRANCH', 'dev', 'Git 브랜치 (dev: dev 브랜치, prod: main 브랜치)')
        booleanParam('SKIP_TESTS', false, '테스트 건너뛰기')
        booleanParam('RUN_E2E_TESTS', false, 'E2E 테스트 실행')
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
            scriptPath('jenkins/Jenkinsfile.my-pick-admin-client')
        }
    }
}
