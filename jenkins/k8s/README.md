# Jenkins K8s 배포

krgeobuk 프로젝트의 CI/CD 파이프라인을 Kubernetes에서 운영합니다.
JCasC(Configuration as Code)로 모든 설정을 코드로 관리하여 클라우드 이관 시에도 동일하게 재현할 수 있습니다.

## 구조

```
jenkins/k8s/
├── namespace.yaml          # krgeobuk-devops 네임스페이스
├── serviceaccount.yaml     # Jenkins ServiceAccount
├── rbac.yaml               # ClusterRole + ClusterRoleBinding
├── pvc.yaml                # Jenkins 홈 영구 볼륨 (10Gi)
├── configmap-plugins.yaml  # 설치 플러그인 목록
├── configmap-casc.yaml     # JCasC 설정 (유저/크레덴셜/Job/공유라이브러리)
├── deployment.yaml         # Jenkins Deployment
├── service.yaml            # ClusterIP Service (8080, 50000)
├── ingress.yaml            # jenkins.krgeobuk.com
├── secret.yaml.template    # Secret 템플릿 (커밋 금지)
└── kustomization.yaml
```

## 아키텍처

```
[git push]
    ↓
[GitHub Webhook POST]
    ↓
[NGINX Ingress] → jenkins.krgeobuk.com
    ↓
[Jenkins Pod - krgeobuk-devops namespace]
  ├── JCasC         ← ConfigMap (유저/크레덴셜/Job 자동 설정)
  ├── Plugins       ← PVC (10Gi, 재시작 시 재설치 불필요)
  ├── docker.sock   ← hostPath (호스트 Docker로 이미지 빌드)
  └── ServiceAccount RBAC (kubectl 명령 직접 실행)
    ↓
[krgeobuk-dev / krgeobuk-prod namespace 배포]
```

### 볼륨 구조

| 볼륨 | 종류 | 마운트 경로 | 설명 |
|---|---|---|---|
| `jenkins-pvc` (10Gi) | PVC | `/var/jenkins_home` | 플러그인, 빌드 히스토리 |
| `jenkins-casc` | ConfigMap | `/var/jenkins_casc` | JCasC 설정 파일 (읽기 전용) |
| `docker.sock` | hostPath | `/var/run/docker.sock` | 호스트 Docker 빌드용 |
| `docker-bin` | hostPath | `/usr/local/bin/docker` | Docker CLI 바이너리 |

### JCasC 동작 원리

```
secret.yaml (K8s Secret)
    ↓ envFrom.secretRef
Jenkins Pod 환경변수
    ↓ JCasC 파싱 시 ${VAR_NAME} 치환
유저 계정, 크레덴셜, 공유 라이브러리, Job 자동 생성
```

### 플러그인 초기화 흐름

```
최초 기동: PVC 비어있음 → plugins.txt 기반 플러그인 설치 (2~5분)
재기동:    PVC에 플러그인 존재 → 설치 스킵, 30초~1분 내 기동
```

---

## 배포 순서

### Step 1. Secret 생성

```bash
cd jenkins/k8s/

cp secret.yaml.template secret.yaml
vi secret.yaml   # 실제 값 입력
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
| `GITHUB_ORG` | GitHub 조직명 또는 계정명 |
| `SLACK_WEBHOOK_URL` | Slack Incoming Webhook URL |
| `SLACK_TEAM_DOMAIN` | Slack 워크스페이스 도메인 |

```bash
kubectl apply -f jenkins/k8s/secret.yaml
```

### Step 2. 나머지 리소스 배포

```bash
kubectl apply -k jenkins/k8s/
```

### Step 3. 기동 확인

```bash
# Pod 상태 확인
kubectl get pods -n krgeobuk-devops -l app=jenkins

# initContainer 로그 (플러그인 설치 진행 확인)
kubectl logs -n krgeobuk-devops -l app=jenkins -c install-plugins -f

# Jenkins 기동 후 접속 확인
kubectl logs -n krgeobuk-devops -l app=jenkins -c jenkins -f

# 헬스체크
curl -I https://jenkins.krgeobuk.com/login
```

---

## GitHub Webhook 설정

Jenkins 기동 후 각 서비스 레포지토리에 Webhook을 등록합니다.

각 레포 → **Settings → Webhooks → Add webhook**

| 항목 | 값 |
|---|---|
| Payload URL | `https://jenkins.krgeobuk.com/github-webhook/` |
| Content type | `application/json` |
| Secret | (선택사항) |
| Trigger | `Just the push event` |

---

## 파이프라인 사용

### Job 구조

JCasC에 의해 자동 생성되는 Job 목록:

| Job | 설명 | Jenkinsfile 위치 |
|---|---|---|
| `krgeobuk-deploy` | 통합 배포 파이프라인 (dev/prod 전체) | `jenkins/Jenkinsfile` |
| `auth-server-pipeline` | auth-server CI/CD | 각 서비스 레포 `Jenkinsfile` |
| `authz-server-pipeline` | authz-server CI/CD | 각 서비스 레포 `Jenkinsfile` |

### 수동 배포 실행

```
Jenkins 웹 UI → 해당 Job → Build with Parameters
  ENVIRONMENT: dev 또는 prod
  SERVICE: all 또는 특정 서비스명
```

### 자동 배포 (Webhook)

git push → GitHub Webhook → Jenkins 자동 트리거 → 빌드/배포

---

## 설정 변경

### JCasC 설정 변경

`configmap-casc.yaml` 수정 후 적용합니다.

```bash
kubectl apply -k jenkins/k8s/

# Pod 재시작 (JCasC 재로드)
kubectl rollout restart deployment/jenkins -n krgeobuk-devops

# 재시작 완료 확인
kubectl rollout status deployment/jenkins -n krgeobuk-devops
```

### 플러그인 추가

`configmap-plugins.yaml`의 `plugins.txt`에 추가 후 적용합니다.

```bash
kubectl apply -k jenkins/k8s/

# 플러그인 재설치를 위해 PVC의 마커 파일 삭제 후 재시작
kubectl exec -n krgeobuk-devops deploy/jenkins -- \
  rm /var/jenkins_home/plugins/.plugins-installed

kubectl rollout restart deployment/jenkins -n krgeobuk-devops
```

---

## 기존 Docker Compose 데이터 이전

Docker Compose Jenkins의 데이터를 K8s PVC로 이전합니다.

```bash
# 1. Pod이 기동된 상태에서 기존 jenkins/data 복사
kubectl cp \
  /path/to/jenkins/data/. \
  krgeobuk-devops/$(kubectl get pod -n krgeobuk-devops -l app=jenkins -o jsonpath='{.items[0].metadata.name}'):/var/jenkins_home/

# 2. 권한 설정
kubectl exec -n krgeobuk-devops deploy/jenkins -- \
  chown -R 1000:1000 /var/jenkins_home

# 3. 재시작
kubectl rollout restart deployment/jenkins -n krgeobuk-devops
```

> JCasC를 사용하면 기존 데이터 이전 없이 새로 구성하는 것도 가능합니다.
> 유저·크레덴셜은 `secret.yaml`과 `configmap-casc.yaml`로 재현되며,
> 파이프라인은 Jenkinsfile로 코드화되어 있습니다.

---

## 클라우드 이관 시

AWS EKS 이관 시 변경이 필요한 항목만 교체합니다.

| 항목 | 미니PC (현재) | AWS EKS |
|---|---|---|
| StorageClass | `local-path` | `gp2` 또는 `gp3` |
| Docker 빌드 | `docker.sock` hostPath | Kaniko (권한 불필요) |
| Jenkins 설정 (JCasC) | 변경 없음 ✅ | 변경 없음 ✅ |
| 파이프라인 (Jenkinsfile) | 변경 없음 ✅ | 변경 없음 ✅ |
| Secret | K8s Secret | AWS Secrets Manager 연동 가능 |

`pvc.yaml`의 `storageClassName`만 교체하면 Jenkins 설정과 파이프라인은 그대로 재사용됩니다.

---

## 문제 해결

### Pod가 기동되지 않을 때

```bash
# Pod 상세 상태 확인
kubectl describe pod -n krgeobuk-devops -l app=jenkins

# initContainer 로그 확인
kubectl logs -n krgeobuk-devops -l app=jenkins -c fix-permissions
kubectl logs -n krgeobuk-devops -l app=jenkins -c install-plugins
```

### JCasC 설정이 적용되지 않을 때

```bash
# ConfigMap 내용 확인
kubectl get configmap jenkins-casc -n krgeobuk-devops -o yaml

# Secret 환경변수 주입 확인
kubectl exec -n krgeobuk-devops deploy/jenkins -- env | grep -E 'JENKINS|DOCKER|GITHUB|SLACK'
```

### Docker 빌드 오류 시

```bash
# docker.sock 권한 확인 (미니PC에서 실행)
ls -la /var/run/docker.sock

# 필요 시 권한 부여
sudo chmod 666 /var/run/docker.sock
```

### kubectl 권한 오류 시

```bash
# ServiceAccount RBAC 확인
kubectl get clusterrolebinding jenkins-deploy-binding -o yaml

# 권한 재적용
kubectl apply -f jenkins/k8s/rbac.yaml
```

---

## DNS 설정

```
jenkins.krgeobuk.com → 미니PC 공인 IP (A 레코드)
```

로컬 테스트 시 `/etc/hosts`에 추가:
```
192.168.0.28 jenkins.krgeobuk.com
```
