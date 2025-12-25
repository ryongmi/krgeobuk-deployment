#!/bin/bash

# krgeobuk prod 환경 배포 스크립트

set -e  # 에러 발생 시 즉시 종료

echo "========================================="
echo "krgeobuk Production Environment Deployment"
echo "⚠️  WARNING: This will deploy to PRODUCTION"
echo "========================================="
echo ""

# k8s 리포지토리 경로
K8S_PATH="${K8S_PATH:-../krgeobuk-k8s}"

# K8s 리포지토리 존재 확인
if [ ! -d "$K8S_PATH" ]; then
  echo "✗ Error: krgeobuk-k8s repository not found at $K8S_PATH"
  echo "  Set K8S_PATH environment variable to the correct path"
  exit 1
fi

# Kustomize 빌드 테스트
echo "1. Testing Kustomize build..."
kubectl kustomize "$K8S_PATH/environments/prod/" > /dev/null
if [ $? -eq 0 ]; then
  echo "✓ Kustomize build successful"
else
  echo "✗ Kustomize build failed"
  exit 1
fi

# 배포 확인 (Production은 두 번 확인)
echo ""
echo "⚠️  You are about to deploy to PRODUCTION environment"
echo ""
read -p "Type 'deploy-to-production' to confirm: " CONFIRM
if [ "$CONFIRM" != "deploy-to-production" ]; then
  echo "Deployment cancelled."
  exit 0
fi

# 백업 권장
echo ""
echo "2. Pre-deployment checklist:"
echo "  - Database backup completed? (yes/no)"
read -p "Answer: " BACKUP_DONE
if [ "$BACKUP_DONE" != "yes" ]; then
  echo "⚠️  Please complete database backup first"
  echo "  Run: /opt/krgeobuk/infrastructure/backup/mysql-backup.sh"
  exit 1
fi

# 배포 실행
echo ""
echo "3. Deploying to krgeobuk-prod namespace..."
kubectl apply -k "$K8S_PATH/environments/prod/"

if [ $? -eq 0 ]; then
  echo "✓ Deployment successful"
else
  echo "✗ Deployment failed"
  exit 1
fi

# 배포 상태 확인
echo ""
echo "4. Checking deployment status..."
echo ""
echo "Pods:"
kubectl get pods -n krgeobuk-prod

echo ""
echo "Services:"
kubectl get svc -n krgeobuk-prod

# 롤아웃 상태 확인
echo ""
echo "5. Waiting for rollout to complete..."
kubectl rollout status deployment/auth-server -n krgeobuk-prod --timeout=10m
kubectl rollout status deployment/auth-client -n krgeobuk-prod --timeout=10m

# 헬스체크
echo ""
echo "6. Running health check..."
sleep 10  # Pod가 완전히 준비될 때까지 대기

# 간단한 헬스체크 (kubectl exec 사용)
echo "  - Checking auth-server health..."
kubectl exec -n krgeobuk-prod deployment/auth-server -- wget -q -O- http://localhost:8000/health || echo "⚠️  Health check failed"

echo ""
echo "========================================="
echo "Production deployment completed!"
echo "========================================="
echo ""
echo "Next steps:"
echo "  - Monitor logs: kubectl logs -f deployment/auth-server -n krgeobuk-prod"
echo "  - Check metrics: kubectl top pods -n krgeobuk-prod"
echo "  - Rollback if needed: kubectl rollout undo deployment/auth-server -n krgeobuk-prod"
