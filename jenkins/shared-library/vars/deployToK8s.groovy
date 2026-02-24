#!/usr/bin/env groovy

/**
 * Kubernetes 배포
 *
 * @param config Map 설정
 *   - environment: 배포 환경 (dev/prod) (required)
 *   - service: 서비스 이름 (required)
 *   - imageTag: 이미지 태그 (required)
 *   - namespace: K8s 네임스페이스 (optional, 환경에서 자동 설정)
 *   - k8sRepo: K8s 리포지토리 경로 (default: '../krgeobuk-k8s')
 *   - timeout: 배포 타임아웃 (default: '5m')
 *   - waitForRollout: 롤아웃 완료 대기 (default: true)
 */
def call(Map config) {
    // 필수 파라미터 검증
    if (!config.environment) {
        error("environment is required")
    }
    if (!config.service) {
        error("service is required")
    }
    if (!config.imageTag) {
        error("imageTag is required")
    }

    def environment = config.environment
    def service = config.service
    def imageTag = config.imageTag
    def namespace = config.namespace ?: "krgeobuk-${environment}"
    def k8sRepo = config.k8sRepo ?: '../krgeobuk-k8s'
    def timeout = config.timeout ?: '5m'
    def waitForRollout = config.waitForRollout != null ? config.waitForRollout : true

    echo """
    ========================================
    Deploying to Kubernetes
    ========================================
    Environment: ${environment}
    Service: ${service}
    Image Tag: ${imageTag}
    Namespace: ${namespace}
    Timeout: ${timeout}
    ========================================
    """

    try {
        // K8s 리포지토리 클론 (이미 없는 경우)
        if (!fileExists(k8sRepo)) {
            sh """
                git clone ${env.K8S_REPO ?: "https://github.com/${env.GITHUB_ORG}/krgeobuk-k8s.git"} ${k8sRepo}
            """
        }

        dir(k8sRepo) {
            // 최신 코드 가져오기
            sh 'git pull origin main'

            // Kustomize로 이미지 태그 업데이트
            if (service == 'all') {
                // 모든 서비스 배포
                echo "Deploying all services to ${environment}..."
                sh """
                    kubectl apply -k environments/${environment}/
                """
            } else {
                // 특정 서비스만 배포
                echo "Deploying ${service} to ${environment}..."

                // 이미지 태그 업데이트
                def imageName = "${env.DOCKER_REGISTRY ?: 'krgeobuk'}/${service}:${imageTag}"

                sh """
                    cd environments/${environment}

                    # Kustomize로 이미지 설정
                    kustomize edit set image ${service}=${imageName}

                    # 배포 적용
                    kubectl apply -k .
                """
            }

            // 롤아웃 상태 확인
            if (waitForRollout) {
                if (service == 'all') {
                    // 모든 Deployment 확인
                    sh """
                        kubectl get deployments -n ${namespace} -o name | while read deploy; do
                            kubectl rollout status \$deploy -n ${namespace} --timeout=${timeout} || exit 1
                        done
                    """
                } else {
                    // 특정 서비스만 확인
                    sh """
                        kubectl rollout status deployment/${service} -n ${namespace} --timeout=${timeout}
                    """
                }

                echo "✓ Rollout completed successfully"
            }

            // Pod 상태 확인
            sh """
                echo ""
                echo "Pod Status:"
                kubectl get pods -n ${namespace} ${service != 'all' ? "-l app=${service}" : ''}
                echo ""
            """

            // Service 확인
            sh """
                echo "Service Status:"
                kubectl get svc -n ${namespace} ${service != 'all' ? service : ''}
                echo ""
            """
        }

        echo "✓ Deployment successful: ${service} → ${environment}"

        return [
            success: true,
            environment: environment,
            service: service,
            namespace: namespace,
            imageTag: imageTag
        ]

    } catch (Exception e) {
        echo "✗ Deployment failed: ${e.message}"

        // 실패 시 Pod 로그 수집
        if (service != 'all') {
            try {
                sh """
                    echo "Collecting pod logs for debugging..."
                    kubectl logs -n ${namespace} -l app=${service} --tail=100 || true
                """
            } catch (ignored) {
                // 로그 수집 실패는 무시
            }
        }

        throw e
    }
}
