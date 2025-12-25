#!/bin/bash

# krgeobuk dev 환경 배포 스크립트

set -e  # 에러 발생 시 즉시 종료

echo "========================================="
echo "krgeobuk Dev Environment Deployment"
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
kubectl kustomize "$K8S_PATH/environments/dev/" > /dev/null
if [ $? -eq 0 ]; then
  echo "✓ Kustomize build successful"
else
  echo "✗ Kustomize build failed"
  exit 1
fi

# 배포 확인
echo ""
read -p "Deploy to krgeobuk-dev namespace? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "Deployment cancelled."
  exit 0
fi

# 배포 실행
echo ""
echo "2. Deploying to krgeobuk-dev namespace..."
kubectl apply -k "$K8S_PATH/environments/dev/"

if [ $? -eq 0 ]; then
  echo "✓ Deployment successful"
else
  echo "✗ Deployment failed"
  exit 1
fi

# 배포 상태 확인
echo ""
echo "3. Checking deployment status..."
echo ""
echo "Pods:"
kubectl get pods -n krgeobuk-dev

echo ""
echo "Services:"
kubectl get svc -n krgeobuk-dev

# 롤아웃 상태 확인
echo ""
echo "4. Waiting for rollout to complete..."
kubectl rollout status deployment/auth-server -n krgeobuk-dev --timeout=5m
kubectl rollout status deployment/auth-client -n krgeobuk-dev --timeout=5m

echo ""
echo "========================================="
echo "Deployment completed successfully!"
echo "========================================="
echo ""
echo "Next steps:"
echo "  - Check logs: kubectl logs -f deployment/auth-server -n krgeobuk-dev"
echo "  - Port forward: kubectl port-forward svc/auth-server 8000:80 -n krgeobuk-dev"
