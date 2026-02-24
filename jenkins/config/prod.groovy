// prod 환경 공통 설정
// 파이프라인 실행 시 load("jenkins/config/prod.groovy") 로 주입됩니다.

env.K8S_NAMESPACE   = 'krgeobuk-prod'
env.SLACK_CHANNEL   = '#krgeobuk-prod'
env.MANUAL_APPROVAL = true
