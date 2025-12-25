# krgeobuk-deployment

krgeobuk 프로젝트의 CI/CD 및 배포 오케스트레이션 리포지토리입니다.

## 📌 리포지토리 역할

이 리포지토리는 **배포 프로세스 전체를 관리**합니다:

- ✅ 배포 워크플로우 오케스트레이션 (빌드 → 테스트 → 배포 → 검증)
- ✅ 환경별 배포 스크립트 (dev, prod)
- ✅ CI/CD 파이프라인 (Jenkins)
- ✅ 배포 전후 검증 및 체크리스트

## 🔗 다른 리포지토리와의 관계

```
krgeobuk-infrastructure     krgeobuk-k8s              krgeobuk-deployment
(인프라 환경)               (K8s 리소스)              (배포 오케스트레이션)
        │                         │                           │
        │                         │                           │
        ▼                         ▼                           ▼
   MySQL, Redis          매니페스트 + 운영 도구         전체 배포 프로세스
   Jenkins, etc.         kubectl 직접 조작             빌드 → 테스트 → 배포
```

**관계**:
- **krgeobuk-infrastructure**: 기반 인프라 제공 (MySQL, Redis 등)
- **krgeobuk-k8s**: K8s 매니페스트 및 직접 운영 도구 제공
- **krgeobuk-deployment** (이 리포지토리): 위 두 리포지토리를 활용하여 전체 배포 흐름 관리

## 🎯 사용 시나리오

| 상황 | 사용할 스크립트 | 설명 |
|------|----------------|------|
| **정식 배포** | `deploy-dev.sh` / `deploy-prod.sh` | 전체 배포 프로세스 (권장) |
| **긴급 핫픽스** | `../krgeobuk-k8s/scripts/deploy.sh` | K8s 직접 배포 |
| **롤백** | `../krgeobuk-k8s/scripts/rollback.sh` | 이전 버전으로 복구 |
| **상태 확인** | `../krgeobuk-k8s/scripts/health-check.sh` | Pod 상태 점검 |

## 구조

```
krgeobuk-deployment/
├── scripts/                       # 배포 스크립트
│   ├── deploy-dev.sh             # dev 환경 배포
│   └── deploy-prod.sh            # prod 환경 배포
│
├── jenkins/                       # Jenkins 파이프라인 (추후 추가)
│   └── Jenkinsfile
│
└── docs/                          # 문서
```

## 배포 스크립트 사용법

### Dev 환경 배포

```bash
cd scripts/
./deploy-dev.sh
```

**실행 과정:**
1. Kustomize 빌드 테스트
2. 배포 확인 프롬프트
3. krgeobuk-dev namespace에 배포
4. 배포 상태 확인
5. 롤아웃 완료 대기

### Prod 환경 배포

```bash
cd scripts/
./deploy-prod.sh
```

**실행 과정:**
1. Kustomize 빌드 테스트
2. 배포 확인 프롬프트 (Production 경고)
3. 백업 완료 확인
4. krgeobuk-prod namespace에 배포
5. 배포 상태 확인
6. 롤아웃 완료 대기
7. 헬스체크 실행

## 환경 변수

### K8S_PATH
krgeobuk-k8s 리포지토리 경로 (기본값: `../krgeobuk-k8s`)

```bash
# 사용 예시
K8S_PATH=/path/to/krgeobuk-k8s ./deploy-dev.sh
```

## 사전 준비사항

### 1. kubectl 설정

```bash
# k3s 설정 복사 (miniPC에서)
sudo cat /etc/rancher/k3s/k3s.yaml

# 로컬 머신에 kubeconfig 설정
mkdir -p ~/.kube
# k3s.yaml 내용을 ~/.kube/config에 복사
# server: https://127.0.0.1:6443 → https://miniPC-IP:6443로 변경
```

### 2. 리포지토리 클론

```bash
# 세 개의 리포지토리를 같은 디렉토리에 클론
git clone https://github.com/ryongmi/krgeobuk-k8s.git
git clone https://github.com/ryongmi/krgeobuk-infrastructure.git
git clone https://github.com/ryongmi/krgeobuk-deployment.git
```

### 3. Secret 생성

```bash
cd ../krgeobuk-k8s/applications/auth-server/
cp secret.yaml.template secret.yaml
# secret.yaml 파일을 열어 실제 값 입력
```

### 4. External Service IP 설정

`krgeobuk-k8s/base/external-mysql.yaml`과 `external-redis.yaml`에서 miniPC IP 주소를 실제 값으로 변경

## 배포 전 체크리스트

### Dev 환경
- [ ] krgeobuk-k8s 리포지토리 최신 상태
- [ ] Secret 파일 생성 완료
- [ ] External Service IP 설정 완료
- [ ] Docker 이미지 빌드 완료

### Prod 환경
- [ ] Dev 환경에서 테스트 완료
- [ ] Database 백업 완료
- [ ] 모든 팀원에게 배포 알림
- [ ] Docker 이미지 빌드 완료 (프로덕션 태그)
- [ ] 롤백 계획 수립

## 문제 해결

### 배포 실패 시

```bash
# 배포 상태 확인
kubectl get pods -n krgeobuk-dev
kubectl describe pod <pod-name> -n krgeobuk-dev

# 로그 확인
kubectl logs <pod-name> -n krgeobuk-dev

# 이벤트 확인
kubectl get events -n krgeobuk-dev --sort-by='.lastTimestamp'
```

### 롤백

```bash
# 이전 버전으로 롤백
kubectl rollout undo deployment/auth-server -n krgeobuk-prod

# 롤백 확인
kubectl rollout status deployment/auth-server -n krgeobuk-prod
```

## Jenkins 파이프라인 (추후 구현)

Jenkins를 사용한 자동 배포 파이프라인은 `jenkins/Jenkinsfile`에 정의됩니다.

**계획된 기능:**
- GitHub Webhook 연동
- 자동 이미지 빌드
- 자동 배포 (dev → staging → prod)
- Slack 알림

## 참고

- 배포 스크립트는 bash로 작성되었습니다
- kubectl 명령어가 필요합니다
- krgeobuk-k8s 리포지토리와 함께 사용됩니다
