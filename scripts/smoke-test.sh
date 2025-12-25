#!/bin/bash

#####################################################################
# krgeobuk Smoke Test 스크립트
#
# 설명: 배포 후 서비스의 기본 동작을 테스트합니다.
# 사용법: ./smoke-test.sh <environment>
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

# 사용법
usage() {
    echo "Usage: $0 <environment>"
    echo ""
    echo "Parameters:"
    echo "  environment  - 배포 환경 (dev/prod)"
    echo ""
    echo "Examples:"
    echo "  $0 dev       # dev 환경 smoke test"
    echo "  $0 prod      # prod 환경 smoke test"
    exit 1
}

# 파라미터 검증
if [ -z "$ENVIRONMENT" ]; then
    usage
fi

if [ "$ENVIRONMENT" != "dev" ] && [ "$ENVIRONMENT" != "prod" ]; then
    echo -e "${RED}Error: Environment must be 'dev' or 'prod'${NC}"
    exit 1
fi

# 네임스페이스 설정
NAMESPACE="krgeobuk-${ENVIRONMENT}"

# 결과 카운터
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}krgeobuk Smoke Test${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "Environment: ${YELLOW}${ENVIRONMENT}${NC}"
echo -e "Namespace: ${YELLOW}${NAMESPACE}${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

#####################################################################
# 테스트 함수
#####################################################################

# Pod 상태 확인
test_pod_status() {
    local service=$1
    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    echo -n "Testing Pod status for ${service}... "

    # Pod가 Running 상태인지 확인
    local pod_status=$(kubectl get pods -n "$NAMESPACE" -l app="$service" -o jsonpath='{.items[*].status.phase}' 2>/dev/null)

    if echo "$pod_status" | grep -q "Running"; then
        echo -e "${GREEN}✓ PASS${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        echo -e "${RED}✗ FAIL (Status: $pod_status)${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

# Health 엔드포인트 확인
test_health_endpoint() {
    local service=$1
    local port=$2
    local path=${3:-/health}
    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    echo -n "Testing ${service} health endpoint... "

    # Pod 이름 가져오기
    local pod_name=$(kubectl get pod -n "$NAMESPACE" -l app="$service" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

    if [ -z "$pod_name" ]; then
        echo -e "${RED}✗ FAIL (Pod not found)${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi

    # Health 엔드포인트 호출
    local http_code=$(kubectl exec "$pod_name" -n "$NAMESPACE" -- curl -s -o /dev/null -w "%{http_code}" "http://localhost:${port}${path}" 2>/dev/null || echo "000")

    if [ "$http_code" == "200" ]; then
        echo -e "${GREEN}✓ PASS (HTTP $http_code)${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        echo -e "${RED}✗ FAIL (HTTP $http_code)${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

# Service 연결성 확인
test_service_connectivity() {
    local service=$1
    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    echo -n "Testing ${service} service connectivity... "

    # Service가 존재하는지 확인
    if kubectl get svc "$service" -n "$NAMESPACE" &> /dev/null; then
        # Endpoint가 있는지 확인
        local endpoints=$(kubectl get endpoints "$service" -n "$NAMESPACE" -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null)

        if [ -n "$endpoints" ]; then
            echo -e "${GREEN}✓ PASS (Endpoints: $(echo $endpoints | wc -w))${NC}"
            PASSED_TESTS=$((PASSED_TESTS + 1))
            return 0
        else
            echo -e "${RED}✗ FAIL (No endpoints)${NC}"
            FAILED_TESTS=$((FAILED_TESTS + 1))
            return 1
        fi
    else
        echo -e "${RED}✗ FAIL (Service not found)${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

# 데이터베이스 연결 확인
test_database_connection() {
    local service=$1
    local db_host=${2:-krgeobuk-mysql}
    local db_port=${3:-3306}
    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    echo -n "Testing ${service} database connection... "

    # Pod 이름 가져오기
    local pod_name=$(kubectl get pod -n "$NAMESPACE" -l app="$service" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

    if [ -z "$pod_name" ]; then
        echo -e "${YELLOW}⊘ SKIP (Pod not found)${NC}"
        return 0
    fi

    # nc 명령어로 DB 연결 확인
    if kubectl exec "$pod_name" -n "$NAMESPACE" -- sh -c "nc -zv $db_host $db_port" &> /dev/null; then
        echo -e "${GREEN}✓ PASS${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

#####################################################################
# 서비스별 테스트 실행
#####################################################################

echo -e "${BLUE}1. Testing auth-server${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
test_pod_status "auth-server"
test_service_connectivity "auth-server"
test_health_endpoint "auth-server" 8000
test_database_connection "auth-server"
echo ""

echo -e "${BLUE}2. Testing authz-server${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
test_pod_status "authz-server"
test_service_connectivity "authz-server"
test_health_endpoint "authz-server" 8100
test_database_connection "authz-server"
echo ""

echo -e "${BLUE}3. Testing auth-client${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
test_pod_status "auth-client"
test_service_connectivity "auth-client"
echo ""

echo -e "${BLUE}4. Testing portal-client${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
test_pod_status "portal-client"
test_service_connectivity "portal-client"
echo ""

#####################################################################
# 결과 출력
#####################################################################

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Smoke Test Results${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "Total Tests: ${TOTAL_TESTS}"
echo -e "${GREEN}Passed: ${PASSED_TESTS}${NC}"
echo -e "${RED}Failed: ${FAILED_TESTS}${NC}"

if [ $FAILED_TESTS -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✓ All smoke tests passed!${NC}"
    echo -e "${GREEN}========================================${NC}"
    exit 0
else
    echo ""
    echo -e "${RED}✗ Some smoke tests failed!${NC}"
    echo -e "${RED}========================================${NC}"
    echo ""
    echo -e "${YELLOW}Debugging commands:${NC}"
    echo -e "  kubectl get pods -n ${NAMESPACE}"
    echo -e "  kubectl describe pod <pod-name> -n ${NAMESPACE}"
    echo -e "  kubectl logs <pod-name> -n ${NAMESPACE}"
    exit 1
fi
