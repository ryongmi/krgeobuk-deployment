// prod 환경 설정
// 운영 환경용 배포 설정입니다.

env.ENVIRONMENT = 'prod'
env.K8S_NAMESPACE = 'krgeobuk-prod'

// Docker Registry 설정
env.DOCKER_REGISTRY = 'krgeobuk'
env.DOCKER_TAG_PREFIX = 'prod'

// Kubernetes 클러스터 설정
env.K8S_CLUSTER = 'production-cluster'
env.K8S_CONTEXT = 'production'

// 리소스 제한 (프로덕션은 더 많은 리소스)
env.CPU_REQUEST = '500m'
env.CPU_LIMIT = '1000m'
env.MEMORY_REQUEST = '512Mi'
env.MEMORY_LIMIT = '1Gi'

// 복제본 수 (고가용성을 위해 2개 이상)
env.REPLICAS = '2'

// 타임아웃 설정
env.DEPLOYMENT_TIMEOUT = '10m'
env.HEALTH_CHECK_TIMEOUT = '5m'

// 로그 레벨
env.LOG_LEVEL = 'info'

// 데이터베이스 설정
env.MYSQL_HOST = 'krgeobuk-mysql'
env.MYSQL_PORT = '3306'
env.REDIS_HOST = 'krgeobuk-redis'
env.REDIS_PORT = '6379'

// 서비스별 데이터베이스 (프로덕션)
env.AUTH_DB = 'auth_prod'
env.AUTHZ_DB = 'authz_prod'
env.PORTAL_DB = 'portal_prod'
env.MYPICK_DB = 'mypick_prod'

// Redis DB 번호
env.AUTH_REDIS_DB = '1'
env.AUTHZ_REDIS_DB = '3'
env.PORTAL_REDIS_DB = '5'
env.MYPICK_REDIS_DB = '7'

// 알림 설정
env.SLACK_CHANNEL = '#krgeobuk-prod'
env.SLACK_WEBHOOK = credentials('slack-webhook-prod')

// Git 브랜치
env.DEFAULT_BRANCH = 'main'

// 빌드 설정
env.SKIP_CACHE = 'false'
env.BUILD_ARGS = '--build-arg NODE_ENV=production'

// 자동 배포 설정 (프로덕션은 수동 승인 필요)
env.AUTO_DEPLOY = 'false'
env.MANUAL_APPROVAL = 'true'

// 테스트 설정
env.RUN_UNIT_TESTS = 'true'
env.RUN_E2E_TESTS = 'true'
env.CODE_COVERAGE_THRESHOLD = '80'

// Ingress 도메인
env.INGRESS_DOMAIN = 'krgeobuk.com'

// 외부 서비스 URL
env.AUTH_SERVER_URL = "http://auth-server.${env.K8S_NAMESPACE}.svc.cluster.local"
env.AUTHZ_SERVER_URL = "http://authz-server.${env.K8S_NAMESPACE}.svc.cluster.local"

// 백업 설정
env.PRE_DEPLOY_BACKUP = 'true'
env.BACKUP_RETENTION_DAYS = '30'

// 롤링 업데이트 전략
env.MAX_SURGE = '1'
env.MAX_UNAVAILABLE = '0'

// Pod Disruption Budget
env.MIN_AVAILABLE = '1'

// HPA (Horizontal Pod Autoscaler) 설정
env.HPA_ENABLED = 'true'
env.HPA_MIN_REPLICAS = '2'
env.HPA_MAX_REPLICAS = '5'
env.HPA_CPU_THRESHOLD = '80'

// 모니터링 및 알림
env.ENABLE_MONITORING = 'true'
env.ENABLE_ALERTS = 'true'
env.ALERT_EMAIL = 'devops@krgeobuk.com'

// 보안 설정
env.ENABLE_SECURITY_SCAN = 'true'
env.VULNERABILITY_THRESHOLD = 'HIGH'

echo """
========================================
Production Environment Configuration Loaded
========================================
Namespace: ${env.K8S_NAMESPACE}
Replicas: ${env.REPLICAS} (HPA: ${env.HPA_MIN_REPLICAS}-${env.HPA_MAX_REPLICAS})
Resources: ${env.CPU_REQUEST}/${env.MEMORY_REQUEST}
Log Level: ${env.LOG_LEVEL}
Manual Approval: ${env.MANUAL_APPROVAL}
Backup: ${env.PRE_DEPLOY_BACKUP}
========================================
⚠️  Production deployment requires manual approval!
========================================
"""
