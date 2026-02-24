// dev 환경 설정
// 개발 환경용 배포 설정입니다.

env.ENVIRONMENT = 'dev'
env.K8S_NAMESPACE = 'krgeobuk-dev'

// Docker Registry 설정
env.DOCKER_REGISTRY = 'krgeobuk'
env.DOCKER_TAG_PREFIX = 'dev'

// Kubernetes 클러스터 설정
env.K8S_CLUSTER = 'minikube'  // 또는 실제 클러스터 이름
env.K8S_CONTEXT = 'minikube'

// 리소스 제한
env.CPU_REQUEST = '100m'
env.CPU_LIMIT = '500m'
env.MEMORY_REQUEST = '128Mi'
env.MEMORY_LIMIT = '512Mi'

// 복제본 수
env.REPLICAS = '1'

// 타임아웃 설정
env.DEPLOYMENT_TIMEOUT = '5m'
env.HEALTH_CHECK_TIMEOUT = '2m'

// 로그 레벨
env.LOG_LEVEL = 'debug'

// 데이터베이스 설정
env.MYSQL_HOST = 'krgeobuk-mysql'
env.MYSQL_PORT = '3306'
env.REDIS_HOST = 'krgeobuk-redis'
env.REDIS_PORT = '6379'

// 서비스별 데이터베이스
env.AUTH_DB = 'auth_dev'
env.AUTHZ_DB = 'authz_dev'
env.PORTAL_DB = 'portal_dev'
env.MYPICK_DB = 'mypick_dev'

// Redis DB 번호
env.AUTH_REDIS_DB = '0'
env.AUTHZ_REDIS_DB = '2'
env.PORTAL_REDIS_DB = '4'
env.MYPICK_REDIS_DB = '6'

// 알림 설정
env.SLACK_CHANNEL = '#krgeobuk-dev'
env.SLACK_WEBHOOK = credentials('slack-webhook-dev')

// Git 브랜치
env.DEFAULT_BRANCH = 'dev'

// 빌드 설정
env.SKIP_CACHE = 'false'
env.BUILD_ARGS = '--build-arg NODE_ENV=development'

// 자동 배포 설정
env.AUTO_DEPLOY = 'true'
env.MANUAL_APPROVAL = 'false'

// 테스트 설정
env.RUN_UNIT_TESTS = 'true'
env.RUN_E2E_TESTS = 'false'
env.CODE_COVERAGE_THRESHOLD = '70'

// Ingress 도메인
env.INGRESS_DOMAIN = 'dev.krgeobuk.local'

// 외부 서비스 URL
env.AUTH_SERVER_URL = "http://auth-server.${env.K8S_NAMESPACE}.svc.cluster.local"
env.AUTHZ_SERVER_URL = "http://authz-server.${env.K8S_NAMESPACE}.svc.cluster.local"

echo """
========================================
Dev Environment Configuration Loaded
========================================
Namespace: ${env.K8S_NAMESPACE}
Replicas: ${env.REPLICAS}
Resources: ${env.CPU_REQUEST}/${env.MEMORY_REQUEST}
Log Level: ${env.LOG_LEVEL}
Auto Deploy: ${env.AUTO_DEPLOY}
========================================
"""
