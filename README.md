# krgeobuk-deployment

krgeobuk 프로젝트의 CI/CD 파이프라인과 인프라 서비스 배포를 관리하는 리포지토리입니다.

## 역할

- Jenkins CI/CD 파이프라인 정의 (Jenkinsfile, Job DSL, 공유 라이브러리)
- Jenkins K8s 배포 매니페스트 관리 (JCasC 포함)
- Verdaccio 프라이빗 NPM 레지스트리 K8s 배포 매니페스트 관리
- 보조 배포 스크립트 (수동 배포 / 롤백)

## 다른 리포지토리와의 관계

```
krgeobuk-deployment           krgeobuk-k8s
(이 리포지토리)               (애플리케이션 K8s 매니페스트)
        │                             │
        ▼                             ▼
Jenkins 파이프라인         Kustomize 오버레이 (dev/prod)
Verdaccio, Jenkins         서비스별 Deployment/Service/Ingress
K8s 매니페스트             환경별 패치
```

- **krgeobuk-k8s**: 각 서비스(auth-server, portal-client 등)의 K8s 매니페스트 관리. Jenkins 파이프라인이 배포 시 이 리포지토리를 클론하여 `kubectl apply -k` 실행
- **krgeobuk-deployment** (이 리포지토리): 파이프라인 정의와 인프라 서비스(Jenkins, Verdaccio) 배포 관리

---

## 구조

```
krgeobuk-deployment/
│
├── jenkins/                          # Jenkins CI/CD
│   ├── Jenkinsfile                   # 통합 배포 파이프라인 (전체/서비스 선택)
│   ├── Jenkinsfile.auth-server       # 서비스별 파이프라인 (9개)
│   ├── Jenkinsfile.*
│   │
│   ├── config/                       # 환경별 공통 설정
│   │   ├── dev.groovy                # K8S_NAMESPACE, SLACK_CHANNEL, MANUAL_APPROVAL
│   │   └── prod.groovy
│   │
│   ├── jobs/                         # Job DSL 정의 (Seed Job이 읽어 Jenkins Job 생성)
│   │   └── *.groovy                  # 서비스별 pipelineJob 정의 (10개)
│   │
│   ├── shared-library/               # Jenkins 공유 라이브러리
│   │   └── vars/
│   │       ├── buildImage.groovy     # Docker 이미지 빌드 및 Registry 푸시
│   │       ├── deployToK8s.groovy    # Kubernetes 배포 (Kustomize)
│   │       └── notifySlack.groovy    # Slack 빌드 결과 알림
│   │
│   ├── k8s/                          # Jenkins K8s 배포 매니페스트
│   │   ├── configmap-casc.yaml       # JCasC 설정 (유저/크레덴셜/Job/공유라이브러리)
│   │   ├── deployment.yaml           # Jenkins Deployment
│   │   ├── ingress-dev.yaml          # dev:  http://jenkins.192.168.0.28.nip.io
│   │   ├── ingress.yaml              # prod: https://jenkins.krgeobuk.com
│   │   ├── secret.yaml.template      # Secret 템플릿 (커밋 금지)
│   │   └── ...
│   │
│   └── README.md                     # Jenkins 파이프라인 상세 가이드
│
├── verdaccio/
│   └── k8s/                          # Verdaccio K8s 배포 매니페스트
│       ├── configmap.yaml            # Verdaccio config.yaml
│       ├── deployment.yaml
│       ├── ingress-dev.yaml          # dev:  http://verdaccio.192.168.0.28.nip.io
│       ├── ingress.yaml              # prod: https://verdaccio.krgeobuk.com
│       ├── secret.yaml.template      # htpasswd Secret 템플릿 (커밋 금지)
│       └── README.md                 # Verdaccio 배포 상세 가이드
│
└── scripts/                          # 보조 배포 스크립트 (수동 배포 / 롤백)
    ├── deploy-dev.sh                 # krgeobuk-k8s 기반 dev 환경 배포
    ├── deploy-prod.sh                # krgeobuk-k8s 기반 prod 환경 배포
    ├── rollback.sh                   # 롤백
    └── smoke-test.sh                 # 배포 후 스모크 테스트
```

---

## 배포 구조 (정상 운영 시)

```
개발자 push
    ↓
Jenkins 파이프라인 (Build with Parameters)
    ↓
서비스 레포 클론 → 빌드/테스트
    ↓
dev:  docker build → k3s ctr images import (imagePullPolicy: Never)
prod: docker build → Docker Registry push
    ↓
kubectl apply -k (krgeobuk-k8s 레포 Kustomize)
    ↓
Slack 알림
```

파이프라인 상세 내용은 [jenkins/README.md](./jenkins/README.md)를 참조하세요.

---

## 시작하기

### 1. Jenkins 배포

Jenkins를 Kubernetes에 배포합니다.

```bash
cd jenkins/k8s/

# Secret 생성
cp secret.yaml.template secret.yaml
vi secret.yaml   # 실제 값 입력

# kustomization.yaml에서 Ingress 환경 선택
# dev:  ingress-dev.yaml (기본값, http://jenkins.192.168.0.28.nip.io)
# prod: ingress.yaml     (https://jenkins.krgeobuk.com)

kubectl apply -f secret.yaml
kubectl apply -k .
```

필수 Secret 항목:

| 키 | 설명 |
|---|---|
| `JENKINS_ADMIN_ID` | Jenkins 관리자 계정명 |
| `JENKINS_ADMIN_PASSWORD` | Jenkins 관리자 비밀번호 |
| `DOCKER_REGISTRY_USER` | Docker Hub 계정명 |
| `DOCKER_REGISTRY_PASSWORD` | Docker Hub 비밀번호 또는 Access Token |
| `GITHUB_USER` | GitHub 계정명 |
| `GITHUB_TOKEN` | GitHub Personal Access Token (repo, webhook 권한) |
| `GITHUB_ORG` | GitHub 조직명 또는 계정명 |
| `SLACK_WEBHOOK_URL` | Slack Incoming Webhook URL |
| `SLACK_TEAM_DOMAIN` | Slack 워크스페이스 도메인 |

배포 상세 가이드: [jenkins/k8s/README.md](./jenkins/k8s/README.md)

### 2. Verdaccio 배포

`@krgeobuk/*` 패키지용 프라이빗 NPM 레지스트리를 배포합니다.

```bash
cd verdaccio/k8s/

# htpasswd 해시 생성 후 Secret 생성
cp secret.yaml.template secret.yaml
vi secret.yaml

# kustomization.yaml에서 Ingress 환경 선택
# dev:  ingress-dev.yaml (기본값, http://verdaccio.192.168.0.28.nip.io)
# prod: ingress.yaml     (https://verdaccio.krgeobuk.com)

kubectl apply -f secret.yaml
kubectl apply -k .
```

배포 상세 가이드: [verdaccio/k8s/README.md](./verdaccio/k8s/README.md)

### 3. Seed Job 실행 (최초 1회)

Jenkins 기동 후 `seed-job`을 수동으로 실행하면 서비스별 파이프라인 Job이 자동 생성됩니다.

```
Jenkins 웹 UI → seed-job → Build Now
```

이후 `krgeobuk-deployment` push 시 GitHub Webhook으로 `seed-job`이 자동 실행되어 Job 정의가 갱신됩니다.

---

## 보조 스크립트

Jenkins를 사용하지 않고 직접 K8s에 배포할 때 사용합니다.
`krgeobuk-k8s` 리포지토리가 `../krgeobuk-k8s` 경로에 있어야 합니다.

```bash
# dev 환경 직접 배포
./scripts/deploy-dev.sh

# prod 환경 직접 배포
./scripts/deploy-prod.sh

# 롤백
./scripts/rollback.sh

# 배포 후 스모크 테스트
./scripts/smoke-test.sh
```

`krgeobuk-k8s` 경로가 다를 경우:
```bash
K8S_PATH=/path/to/krgeobuk-k8s ./scripts/deploy-dev.sh
```

---

## 문제 해결

### 배포 실패 시

```bash
# Pod 상태 확인
kubectl get pods -n krgeobuk-dev
kubectl describe pod <pod-name> -n krgeobuk-dev

# 로그 확인
kubectl logs <pod-name> -n krgeobuk-dev

# 이전 버전으로 롤백
kubectl rollout undo deployment/<서비스명> -n krgeobuk-dev
```

### Jenkins 문제

[jenkins/k8s/README.md → 문제 해결](./jenkins/k8s/README.md#문제-해결) 참조

### Verdaccio 문제

[verdaccio/k8s/README.md → 문제 해결](./verdaccio/k8s/README.md#문제-해결) 참조
