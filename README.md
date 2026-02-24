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
(인프라 환경)               (K8s 리소스 + 운영)       (배포 오케스트레이션)
        │                         │                           │
        ▼                         ▼                           ▼
   MySQL, Redis          매니페스트 + kubectl 조작     전체 배포 프로세스
   (Docker Compose)      운영 스크립트                 Jenkins K8s 매니페스트
                                                        파이프라인 정의
```

**관계**:
- **krgeobuk-infrastructure**: 기반 인프라 제공 (MySQL, Redis — Docker Compose)
- **krgeobuk-k8s**: 애플리케이션 K8s 매니페스트 및 운영 도구 제공
- **krgeobuk-deployment** (이 리포지토리): CI/CD 파이프라인 + Jenkins K8s 배포 관리

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
├── jenkins/                       # Jenkins CI/CD
│   ├── Jenkinsfile               # 통합 배포 파이프라인
│   ├── Jenkinsfile.*             # 서비스별 파이프라인
│   ├── config/                   # 환경별 설정 (dev.groovy, prod.groovy)
│   ├── shared-library/           # 공유 라이브러리 (buildImage, deployToK8s, notifySlack)
│   └── k8s/                      # Jenkins K8s 배포 매니페스트
│       ├── namespace.yaml        # krgeobuk-devops 네임스페이스
│       ├── serviceaccount.yaml   # Jenkins ServiceAccount
│       ├── rbac.yaml             # ClusterRole + ClusterRoleBinding
│       ├── pvc.yaml              # Jenkins 홈 영구 볼륨 (10Gi)
│       ├── configmap-plugins.yaml # 설치 플러그인 목록
│       ├── configmap-casc.yaml   # JCasC 설정 (유저/크레덴셜/Job)
│       ├── deployment.yaml       # Jenkins Deployment
│       ├── service.yaml          # ClusterIP Service
│       ├── ingress.yaml          # jenkins.krgeobuk.com Ingress
│       ├── secret.yaml.template  # Secret 템플릿 (커밋 금지)
│       └── kustomization.yaml    # Kustomize 진입점
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

## Jenkins K8s 배포

Jenkins를 Docker Compose 대신 Kubernetes에서 운영합니다.
`jenkins/k8s/` 디렉토리의 매니페스트로 관리되며, JCasC(Configuration as Code)로 모든 설정을 코드화합니다.

### 아키텍처

```
[GitHub Webhook]
       ↓
[NGINX Ingress] → jenkins.krgeobuk.com
       ↓
[Jenkins Pod - krgeobuk-devops namespace]
  - JCasC: 유저/크레덴셜/Job 자동 설정
  - docker.sock 마운트: 호스트 Docker로 이미지 빌드
  - ServiceAccount RBAC: kubectl 명령 직접 실행
       ↓
[krgeobuk-dev / krgeobuk-prod namespace 배포]
```

### 사전 준비

#### 1. DNS 설정

`jenkins.krgeobuk.com` A 레코드를 미니PC 공인 IP로 등록합니다.

로컬 테스트 시 `/etc/hosts`에 추가:
```
192.168.0.28 jenkins.krgeobuk.com
```

#### 2. JCasC 설정 수정

`jenkins/k8s/configmap-casc.yaml`에서 파이프라인 Job의 GitHub 레포 URL을 실제 조직명으로 수정합니다:
```yaml
# 수정 전 (플레이스홀더)
remote: "https://github.com/${GITHUB_ORG}/krgeobuk-deployment.git"

# GITHUB_ORG는 secret.yaml에서 환경변수로 주입됨
# secret.yaml의 GITHUB_ORG 값을 실제 조직명으로 설정하면 자동 반영
```

### 배포 순서

#### Step 1. Secret 생성

```bash
cd jenkins/k8s/

# 템플릿 복사
cp secret.yaml.template secret.yaml

# 실제 값 입력
vi secret.yaml
```

`secret.yaml` 필수 입력 항목:

| 키 | 설명 |
|---|---|
| `JENKINS_ADMIN_ID` | Jenkins 관리자 계정명 |
| `JENKINS_ADMIN_PASSWORD` | Jenkins 관리자 비밀번호 |
| `DOCKER_REGISTRY_USER` | Docker Hub 계정명 |
| `DOCKER_REGISTRY_PASSWORD` | Docker Hub 비밀번호 또는 Access Token |
| `GITHUB_USER` | GitHub 계정명 |
| `GITHUB_TOKEN` | GitHub Personal Access Token (repo, webhook 권한) |
| `GITHUB_ORG` | GitHub 조직명 (레포 URL에 사용) |
| `SLACK_WEBHOOK_URL` | Slack Incoming Webhook URL |
| `SLACK_TEAM_DOMAIN` | Slack 워크스페이스 도메인 |

```bash
# Secret 적용
kubectl apply -f jenkins/k8s/secret.yaml
```

#### Step 2. 나머지 리소스 배포

```bash
kubectl apply -k jenkins/k8s/
```

#### Step 3. 기동 확인

```bash
# Pod 상태 확인
kubectl get pods -n krgeobuk-devops

# 로그 확인 (첫 기동 시 플러그인 설치로 2~5분 소요)
kubectl logs -n krgeobuk-devops -l app=jenkins -f

# Jenkins 접속 확인
curl -I https://jenkins.krgeobuk.com/login
```

### GitHub Webhook 설정

Jenkins가 기동된 후 각 서비스 레포지토리에 Webhook을 등록합니다.

각 레포 → Settings → Webhooks → Add webhook:

| 항목 | 값 |
|---|---|
| Payload URL | `https://jenkins.krgeobuk.com/github-webhook/` |
| Content type | `application/json` |
| Trigger | `Just the push event` |

### JCasC 동작 원리

Jenkins 기동 시 `configmap-casc.yaml`의 `jenkins.yaml`을 자동으로 읽어 설정을 적용합니다.
`secret.yaml`의 값들은 Pod 환경변수로 주입되어 `${VAR_NAME}` 형태로 참조됩니다.

```
secret.yaml (K8s Secret)
    ↓ envFrom.secretRef
Jenkins Pod 환경변수
    ↓ JCasC 파싱 시 ${VAR_NAME} 치환
유저 계정, 크레덴셜, 공유 라이브러리, Job 자동 생성
```

설정 변경 시 ConfigMap을 수정하고 Pod를 재시작합니다:
```bash
# ConfigMap 수정 후 적용
kubectl apply -k jenkins/k8s/

# Pod 재시작 (JCasC 재로드)
kubectl rollout restart deployment/jenkins -n krgeobuk-devops
```

### 클라우드 이관 시

AWS EKS 이관 시 변경이 필요한 항목만 교체하면 됩니다:

| 항목 | 미니PC (현재) | AWS EKS |
|---|---|---|
| StorageClass | `local-path` | `gp2` 또는 `gp3` |
| docker.sock | 호스트 소켓 마운트 | Kaniko 또는 ECR |
| Jenkins 설정 (JCasC) | 변경 없음 ✅ | 변경 없음 ✅ |
| 파이프라인 (Jenkinsfile) | 변경 없음 ✅ | 변경 없음 ✅ |

`pvc.yaml`의 `storageClassName`만 교체하면 Jenkins 설정과 파이프라인은 그대로 재사용됩니다.

### 문제 해결

#### Pod가 기동되지 않을 때

```bash
# Pod 상태 상세 확인
kubectl describe pod -n krgeobuk-devops -l app=jenkins

# initContainer 로그 확인 (권한 설정 / 플러그인 설치)
kubectl logs -n krgeobuk-devops -l app=jenkins -c fix-permissions
kubectl logs -n krgeobuk-devops -l app=jenkins -c install-plugins
```

#### JCasC 설정이 적용되지 않을 때

```bash
# ConfigMap 내용 확인
kubectl get configmap jenkins-casc -n krgeobuk-devops -o yaml

# Secret 환경변수 주입 확인
kubectl exec -n krgeobuk-devops deploy/jenkins -- env | grep JENKINS
```

#### docker 빌드 오류 시

```bash
# docker.sock 권한 확인 (미니PC에서 실행)
ls -la /var/run/docker.sock
# 필요 시: sudo chmod 666 /var/run/docker.sock
```

## 참고

- 배포 스크립트는 bash로 작성되었습니다
- kubectl 명령어가 필요합니다
- krgeobuk-k8s 리포지토리와 함께 사용됩니다
