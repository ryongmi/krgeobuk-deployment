#!/bin/bash

#####################################################################
# krgeobuk 전체 이미지 빌드 스크립트
#
# 설명: 모든 마이크로서비스의 Docker 이미지를 빌드합니다.
# 사용법: ./build-all-images.sh [tag] [--push] [--no-cache]
#####################################################################

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 파라미터
IMAGE_TAG=${1:-"latest"}
PUSH=false
NO_CACHE=false

# 옵션 파싱
for arg in "$@"; do
    case $arg in
        --push)
            PUSH=true
            shift
            ;;
        --no-cache)
            NO_CACHE=true
            shift
            ;;
    esac
done

# Docker Registry
DOCKER_REGISTRY="${DOCKER_REGISTRY:-krgeobuk}"

# 서비스 목록 및 경로
declare -A SERVICES=(
    ["auth-server"]="../auth-server"
    ["authz-server"]="../authz-server"
    ["auth-client"]="../auth-client"
    ["portal-client"]="../portal-client"
    ["portal-server"]="../portal-server"
    ["my-pick-server"]="../my-pick-server"
    ["my-pick-client"]="../my-pick-client"
    ["portal-admin-client"]="../portal-admin-client"
    ["my-pick-admin-client"]="../my-pick-admin-client"
)

# 결과 카운터
TOTAL_SERVICES=${#SERVICES[@]}
SUCCESS_COUNT=0
FAILED_COUNT=0
FAILED_SERVICES=()

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}krgeobuk 전체 이미지 빌드${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "Registry: ${YELLOW}${DOCKER_REGISTRY}${NC}"
echo -e "Tag: ${YELLOW}${IMAGE_TAG}${NC}"
echo -e "Push to Registry: ${YELLOW}${PUSH}${NC}"
echo -e "No Cache: ${YELLOW}${NO_CACHE}${NC}"
echo -e "Total Services: ${YELLOW}${TOTAL_SERVICES}${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

#####################################################################
# 빌드 함수
#####################################################################

build_service() {
    local service=$1
    local path=$2

    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Building ${service}...${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    # 경로 확인
    if [ ! -d "$path" ]; then
        echo -e "${RED}✗ Directory not found: $path${NC}"
        FAILED_COUNT=$((FAILED_COUNT + 1))
        FAILED_SERVICES+=("$service")
        return 1
    fi

    cd "$path"

    # Dockerfile 확인
    if [ ! -f "Dockerfile" ]; then
        echo -e "${RED}✗ Dockerfile not found in $path${NC}"
        cd - > /dev/null
        FAILED_COUNT=$((FAILED_COUNT + 1))
        FAILED_SERVICES+=("$service")
        return 1
    fi

    # 이미지 이름
    local image_name="${DOCKER_REGISTRY}/${service}:${IMAGE_TAG}"

    # Docker 빌드 명령어
    local build_cmd="docker build"

    if [ "$NO_CACHE" = true ]; then
        build_cmd="$build_cmd --no-cache"
    fi

    build_cmd="$build_cmd -t $image_name ."

    # 빌드 실행
    echo -e "${YELLOW}[INFO] Building $image_name...${NC}"
    if $build_cmd; then
        echo -e "${GREEN}✓ Build successful: $image_name${NC}"

        # 이미지 크기 확인
        local image_size=$(docker images "$image_name" --format "{{.Size}}")
        echo -e "${BLUE}   Image size: $image_size${NC}"

        # Push (옵션)
        if [ "$PUSH" = true ]; then
            echo -e "${YELLOW}[INFO] Pushing $image_name...${NC}"
            if docker push "$image_name"; then
                echo -e "${GREEN}✓ Push successful: $image_name${NC}"
            else
                echo -e "${RED}✗ Push failed: $image_name${NC}"
                cd - > /dev/null
                FAILED_COUNT=$((FAILED_COUNT + 1))
                FAILED_SERVICES+=("$service")
                return 1
            fi
        fi

        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        cd - > /dev/null
        return 0
    else
        echo -e "${RED}✗ Build failed: $service${NC}"
        cd - > /dev/null
        FAILED_COUNT=$((FAILED_COUNT + 1))
        FAILED_SERVICES+=("$service")
        return 1
    fi
}

#####################################################################
# 모든 서비스 빌드
#####################################################################

START_TIME=$(date +%s)

for service in "${!SERVICES[@]}"; do
    build_service "$service" "${SERVICES[$service]}"
    echo ""
done

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

#####################################################################
# 결과 출력
#####################################################################

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Build Results${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "Total Services: ${TOTAL_SERVICES}"
echo -e "${GREEN}Success: ${SUCCESS_COUNT}${NC}"
echo -e "${RED}Failed: ${FAILED_COUNT}${NC}"
echo -e "Duration: ${DURATION}s"

if [ $FAILED_COUNT -gt 0 ]; then
    echo ""
    echo -e "${RED}Failed Services:${NC}"
    for failed_service in "${FAILED_SERVICES[@]}"; do
        echo -e "  ${RED}✗ ${failed_service}${NC}"
    done
fi

echo ""

if [ $FAILED_COUNT -eq 0 ]; then
    echo -e "${GREEN}✓ All services built successfully!${NC}"
    echo -e "${GREEN}========================================${NC}"

    # 빌드된 이미지 목록
    echo ""
    echo -e "${BLUE}Built Images:${NC}"
    docker images "${DOCKER_REGISTRY}/*:${IMAGE_TAG}" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"

    exit 0
else
    echo -e "${RED}✗ Some services failed to build!${NC}"
    echo -e "${RED}========================================${NC}"
    exit 1
fi
