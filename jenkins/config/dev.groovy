// dev 환경 공통 설정
// 파이프라인 실행 시 load("jenkins/config/dev.groovy") 로 주입됩니다.

env.K8S_NAMESPACE   = 'krgeobuk-dev'
env.SLACK_CHANNEL   = '#krgeobuk-dev'
env.MANUAL_APPROVAL = false
