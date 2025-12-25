#!/bin/bash

#####################################################################
# krgeobuk 롤백 스크립트
#
# 설명: Kubernetes Deployment를 이전 버전으로 롤백합니다.
# 사용법: ./rollback.sh <environment> <service> [revision]
#####################################################################

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 파라미터
ENVIRONMENT=$1
SERVICE=$2
REVISION=$3

# 사용법
usage() {
    echo "Usage: $0 <environment> <service> [revision]"
    echo ""
    echo "Parameters:"
    echo "  environment  - 배포 환경 (dev/prod)"
    echo "  service      - 서비스 이름 (또는 'all')"
    echo "  revision     - 롤백할 리비전 번호 (선택사항, 기본값: 이전 버전)"
    echo ""
    echo "Examples:"
    echo "  $0 dev auth-server              # dev 환경의 auth-server를 이전 버전으로 롤백"
    echo "  $0 prod authz-server 3          # prod 환경의 authz-server를 리비전 3으로 롤백"
    echo "  $0 dev all                      # dev 환경의 모든 서비스 롤백"
    exit 1
}

# 파라미터 검증
if [ -z "$ENVIRONMENT" ] || [ -z "$SERVICE" ]; then
    usage
fi

if [ "$ENVIRONMENT" != "dev" ] && [ "$ENVIRONMENT" != "prod" ]; then
    echo -e "${RED}Error: Environment must be 'dev' or 'prod'${NC}"
    exit 1
fi

# 네임스페이스 설정
NAMESPACE="krgeobuk-${ENVIRONMENT}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}krgeobuk Rollback${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "Environment: ${YELLOW}${ENVIRONMENT}${NC}"
echo -e "Service: ${YELLOW}${SERVICE}${NC}"
echo -e "Namespace: ${YELLOW}${NAMESPACE}${NC}"
if [ -n "$REVISION" ]; then
    echo -e "Target Revision: ${YELLOW}${REVISION}${NC}"
else
    echo -e "Target: ${YELLOW}Previous version${NC}"
fi
echo -e "${BLUE}========================================${NC}"
echo ""

# 롤백 확인
if [ "$ENVIRONMENT" == "prod" ]; then
    echo -e "${RED}⚠ WARNING: Production 환경 롤백을 진행합니다!${NC}"
    echo ""
    read -p "계속하시겠습니까? (yes/no): " CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
        echo -e "${YELLOW}Rollback cancelled.${NC}"
        exit 0
    fi
fi

# 롤백 함수
rollback_service() {
    local svc=$1
    local rev=$2

    echo -e "${YELLOW}[INFO] Rolling back ${svc}...${NC}"

    # Deployment 존재 확인
    if ! kubectl get deployment "$svc" -n "$NAMESPACE" &> /dev/null; then
        echo -e "${RED}[ERROR] Deployment '${svc}' not found in namespace '${NAMESPACE}'${NC}"
        return 1
    fi

    # 롤아웃 히스토리 확인
    echo ""
    echo -e "${BLUE}Rollout History:${NC}"
    kubectl rollout history deployment/"$svc" -n "$NAMESPACE"
    echo ""

    # 롤백 실행
    if [ -n "$rev" ]; then
        echo -e "${YELLOW}[INFO] Rolling back to revision ${rev}...${NC}"
        kubectl rollout undo deployment/"$svc" -n "$NAMESPACE" --to-revision="$rev"
    else
        echo -e "${YELLOW}[INFO] Rolling back to previous version...${NC}"
        kubectl rollout undo deployment/"$svc" -n "$NAMESPACE"
    fi

    # 롤백 상태 확인
    echo ""
    echo -e "${YELLOW}[INFO] Waiting for rollback to complete...${NC}"
    kubectl rollout status deployment/"$svc" -n "$NAMESPACE" --timeout=5m

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Rollback successful: ${svc}${NC}"
        echo ""

        # Pod 상태 확인
        echo -e "${BLUE}Current Pods:${NC}"
        kubectl get pods -n "$NAMESPACE" -l app="$svc"
        echo ""

        return 0
    else
        echo -e "${RED}✗ Rollback failed: ${svc}${NC}"
        return 1
    fi
}

# 롤백 실행
if [ "$SERVICE" == "all" ]; then
    echo -e "${YELLOW}[INFO] Rolling back all services in ${NAMESPACE}...${NC}"
    echo ""

    # 모든 Deployment 가져오기
    DEPLOYMENTS=$(kubectl get deployments -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')

    FAILED=0
    for deploy in $DEPLOYMENTS; do
        if ! rollback_service "$deploy" "$REVISION"; then
            FAILED=$((FAILED + 1))
        fi
    done

    if [ $FAILED -eq 0 ]; then
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}All services rolled back successfully!${NC}"
        echo -e "${GREEN}========================================${NC}"
    else
        echo -e "${RED}========================================${NC}"
        echo -e "${RED}${FAILED} service(s) failed to rollback${NC}"
        echo -e "${RED}========================================${NC}"
        exit 1
    fi
else
    # 단일 서비스 롤백
    if rollback_service "$SERVICE" "$REVISION"; then
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}Rollback completed successfully!${NC}"
        echo -e "${GREEN}========================================${NC}"
    else
        exit 1
    fi
fi

echo ""
echo -e "${BLUE}Rollback completed!${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  - Verify application: kubectl logs -f deployment/${SERVICE} -n ${NAMESPACE}"
echo -e "  - Check service: kubectl get svc ${SERVICE} -n ${NAMESPACE}"
echo -e "  - Monitor pods: kubectl get pods -n ${NAMESPACE} -w"
echo ""
