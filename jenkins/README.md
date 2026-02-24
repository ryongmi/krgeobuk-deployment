# Jenkins 파이프라인

krgeobuk 프로젝트의 CI/CD 파이프라인을 관리합니다.
모든 Jenkinsfile과 공유 라이브러리, Job 정의가 이 디렉토리에서 코드로 관리됩니다.

## 구조

```
jenkins/
├── Jenkinsfile                      # 통합 배포 파이프라인 (전체/서비스 선택)
├── Jenkinsfile.auth-server          # auth-server 전용 파이프라인
├── Jenkinsfile.auth-client          # auth-client 전용 파이프라인
├── Jenkinsfile.authz-server         # authz-server 전용 파이프라인
├── Jenkinsfile.portal-server        # portal-server 전용 파이프라인
├── Jenkinsfile.portal-client        # portal-client 전용 파이프라인
├── Jenkinsfile.my-pick-server       # my-pick-server 전용 파이프라인
├── Jenkinsfile.my-pick-client       # my-pick-client 전용 파이프라인
├── Jenkinsfile.portal-admin-client  # portal-admin-client 전용 파이프라인
├── Jenkinsfile.my-pick-admin-client # my-pick-admin-client 전용 파이프라인
│
├── config/                          # 환경별 설정 파일
│   ├── dev.groovy                   # dev 환경 변수 (네임스페이스, 리소스, 브랜치 등)
│   └── prod.groovy                  # prod 환경 변수 (리소스 증가, 수동 승인, HPA 등)
│
├── jobs/                            # Job DSL 정의 (Seed Job이 읽어서 Jenkins Job 생성)
│   ├── krgeobuk-deploy.groovy       # krgeobuk-deploy Job
│   ├── auth-server.groovy           # auth-server-pipeline Job
│   ├── auth-client.groovy           # auth-client-pipeline Job
│   ├── authz-server.groovy          # authz-server-pipeline Job
│   ├── portal-server.groovy         # portal-server-pipeline Job
│   ├── portal-client.groovy         # portal-client-pipeline Job
│   ├── my-pick-server.groovy        # my-pick-server-pipeline Job
│   ├── my-pick-client.groovy        # my-pick-client-pipeline Job
│   ├── portal-admin-client.groovy   # portal-admin-client-pipeline Job
│   └── my-pick-admin-client.groovy  # my-pick-admin-client-pipeline Job
│
├── shared-library/                  # Jenkins 공유 라이브러리
│   └── vars/
│       ├── buildImage.groovy        # Docker 이미지 빌드 및 Registry 푸시
│       ├── deployToK8s.groovy       # Kubernetes 배포 (Kustomize)
│       └── notifySlack.groovy       # Slack 빌드 결과 알림
│
└── k8s/                             # Jenkins K8s 배포 매니페스트
    └── README.md                    # K8s 배포 가이드
```

---

## 아키텍처

### Seed Job 패턴

Jenkins Job은 JCasC + Job DSL의 2단계로 관리됩니다.

```
[JCasC - configmap-casc.yaml]
    ↓ Jenkins 기동 시 자동 적용
[seed-job 생성] ← freeStyleJob 1개만 생성
    ↓ 수동 실행 또는 krgeobuk-deployment push 시 자동 실행
[jenkins/jobs/*.groovy 처리] ← Job DSL
    ↓
[서비스별 파이프라인 Job 생성/갱신] ← 10개 pipelineJob
```

**왜 Seed Job 패턴인가?**

모든 Jenkinsfile이 서비스 레포가 아닌 `krgeobuk-deployment`에서 중앙 관리됩니다.
따라서 GitHub Organization Folder(서비스 레포의 Jenkinsfile을 자동 탐색) 방식은 적합하지 않으며,
Job DSL로 각 파이프라인을 명시적으로 정의하는 Seed Job 패턴을 사용합니다.

### 파이프라인 실행 흐름

```
개발자 → Jenkins UI → Build with Parameters
                          ↓
              Jenkinsfile.{서비스명} 로드 (krgeobuk-deployment SCM)
                          ↓
              서비스 레포 클론 (GIT_BRANCH 파라미터)
                          ↓
              npm ci → 테스트/린트 → npm run build
                          ↓
              Docker 이미지 빌드 → Registry 푸시 (prod만)
                          ↓
              kubectl 배포 (Kustomize)
                          ↓
              롤아웃 상태 확인 → 헬스체크
                          ↓
              Slack 알림 (성공/실패)
```

---

## Jenkinsfile 목록

### Jenkinsfile (통합 배포)

모든 서비스를 한 번에 또는 선택적으로 배포합니다.

| 파라미터 | 타입 | 설명 |
|---|---|---|
| `ENVIRONMENT` | choice | `dev` / `prod` |
| `SERVICE` | choice | `all` 또는 서비스명 |
| `SKIP_TESTS` | boolean | 테스트 건너뛰기 (기본: false) |
| `FORCE_BUILD` | boolean | 변경사항 없어도 강제 빌드 (기본: false) |

### Jenkinsfile.{서비스명} (서비스별 배포)

각 서비스의 독립적인 CI/CD 파이프라인입니다.

| 파라미터 | 타입 | 기본값 | 설명 |
|---|---|---|---|
| `ENVIRONMENT` | choice | `dev` | `dev` / `prod` |
| `GIT_BRANCH` | string | `dev` | 서비스 레포 브랜치 |
| `SKIP_TESTS` | boolean | false | 테스트 건너뛰기 |
| `RUN_E2E_TESTS` | boolean | false | E2E 테스트 실행 |

**Docker 이미지 태그 전략:**
- dev: `latest` (로컬 빌드, Registry 푸시 없음)
- prod: `{timestamp}-{git-short-hash}` (Registry 푸시)

**prod 배포 시 수동 승인** (input step) 이 필요합니다.

---

## 공유 라이브러리 (shared-library)

`@Library('krgeobuk-shared-library') _` 로 모든 Jenkinsfile에서 사용합니다.
JCasC의 `globalLibraries`에 의해 krgeobuk-deployment 레포에서 자동으로 로드됩니다.

### buildImage

Docker 이미지를 빌드하고 Registry에 푸시합니다.

```groovy
buildImage(
    serviceName: 'auth-server',       // 필수: 서비스 이름
    imageTag: '20240101-abc1234',     // 필수: 이미지 태그
    dockerRegistry: 'krgeobuk',       // 선택: Registry 이름 (기본: 'krgeobuk')
    dockerfile: 'Dockerfile',         // 선택: Dockerfile 경로 (기본: 'Dockerfile')
    additionalTags: ['latest'],       // 선택: 추가 태그 목록
    buildArgs: '--build-arg NODE_ENV=production', // 선택: 빌드 인자
    noCache: false,                   // 선택: 캐시 미사용 (기본: false)
    cleanupLocal: false               // 선택: 빌드 후 로컬 이미지 삭제
)
```

Registry 로그인은 `docker-registry-credentials` credential을 사용합니다.

### deployToK8s

Kustomize를 통해 Kubernetes에 배포합니다.

```groovy
deployToK8s(
    environment: 'dev',              // 필수: 배포 환경 (dev/prod)
    service: 'auth-server',          // 필수: 서비스 이름 ('all' 가능)
    imageTag: '20240101-abc1234',    // 필수: 이미지 태그
    namespace: 'krgeobuk-dev',       // 선택: K8s 네임스페이스 (자동 추론)
    k8sRepo: '../krgeobuk-k8s',      // 선택: krgeobuk-k8s 레포 경로
    timeout: '5m',                   // 선택: 롤아웃 타임아웃
    waitForRollout: true             // 선택: 롤아웃 완료 대기
)
```

내부적으로 `kustomize edit set image` → `kubectl apply -k` 순서로 실행합니다.

### notifySlack

빌드 결과를 Slack으로 알립니다.

```groovy
notifySlack(
    status: 'SUCCESS',               // 필수: SUCCESS / FAILURE / WARNING / STARTED
    environment: 'dev',              // 선택: 배포 환경
    service: 'auth-server',          // 선택: 서비스 이름
    message: '배포 성공 메시지'       // 선택: 커스텀 메시지
)
```

알림 실패 시 빌드를 실패시키지 않습니다 (빌드 결과에 영향 없음).

---

## 환경 설정 (config/)

`Jenkinsfile`의 Prepare 스테이지에서 환경별 설정을 로드합니다.

```groovy
load("jenkins/config/${params.ENVIRONMENT}.groovy")
```

### dev.groovy 주요 설정

| 항목 | 값 |
|---|---|
| K8s 네임스페이스 | `krgeobuk-dev` |
| 복제본 수 | 1 |
| 기본 브랜치 | `dev` |
| 자동 배포 | true |
| 수동 승인 | false |
| E2E 테스트 | false |
| 코드 커버리지 | 70% |

### prod.groovy 주요 설정

| 항목 | 값 |
|---|---|
| K8s 네임스페이스 | `krgeobuk-prod` |
| 복제본 수 | 2 |
| 기본 브랜치 | `main` |
| 자동 배포 | false (수동 승인 필요) |
| E2E 테스트 | true |
| 코드 커버리지 | 80% |
| HPA | 2~5 replica (CPU 80%) |
| 배포 전 백업 | true |

---

## Job 정의 (jobs/)

Seed Job이 읽어 Jenkins에 파이프라인 Job을 생성합니다.

### 생성되는 Job 목록

| groovy 파일 | Jenkins Job 이름 | Jenkinsfile |
|---|---|---|
| `krgeobuk-deploy.groovy` | `krgeobuk-deploy` | `jenkins/Jenkinsfile` |
| `auth-server.groovy` | `auth-server-pipeline` | `jenkins/Jenkinsfile.auth-server` |
| `auth-client.groovy` | `auth-client-pipeline` | `jenkins/Jenkinsfile.auth-client` |
| `authz-server.groovy` | `authz-server-pipeline` | `jenkins/Jenkinsfile.authz-server` |
| `portal-server.groovy` | `portal-server-pipeline` | `jenkins/Jenkinsfile.portal-server` |
| `portal-client.groovy` | `portal-client-pipeline` | `jenkins/Jenkinsfile.portal-client` |
| `my-pick-server.groovy` | `my-pick-server-pipeline` | `jenkins/Jenkinsfile.my-pick-server` |
| `my-pick-client.groovy` | `my-pick-client-pipeline` | `jenkins/Jenkinsfile.my-pick-client` |
| `portal-admin-client.groovy` | `portal-admin-client-pipeline` | `jenkins/Jenkinsfile.portal-admin-client` |
| `my-pick-admin-client.groovy` | `my-pick-admin-client-pipeline` | `jenkins/Jenkinsfile.my-pick-admin-client` |

모든 Job의 SCM은 `krgeobuk-deployment` 레포이며, 각 파이프라인이 실행될 때 서비스 레포를 직접 클론합니다.

---

## 새 서비스 추가

1. **Jenkinsfile 작성** (기존 파일 복사 후 수정)

```bash
cp jenkins/Jenkinsfile.auth-server jenkins/Jenkinsfile.new-service
# SERVICE_NAME, GIT_REPO 수정
vi jenkins/Jenkinsfile.new-service
```

2. **Job 정의 파일 추가**

```bash
cp jenkins/jobs/auth-server.groovy jenkins/jobs/new-service.groovy
# 'new-service-pipeline', scriptPath 수정
vi jenkins/jobs/new-service.groovy
```

3. **krgeobuk-deployment에 push**

```bash
git add jenkins/Jenkinsfile.new-service jenkins/jobs/new-service.groovy
git commit -m "jenkins: new-service 파이프라인 추가"
git push
```

4. **seed-job 실행** (GitHub Webhook이 설정된 경우 자동, 아닌 경우 수동)

```
Jenkins UI → seed-job → Build Now
```

---

## 파이프라인 실행 방법

### 개별 서비스 배포

```
Jenkins UI → {서비스명}-pipeline → Build with Parameters
  ENVIRONMENT: dev 또는 prod
  GIT_BRANCH: dev 또는 main
  SKIP_TESTS: false (기본)
```

### 전체 배포 또는 복수 서비스 배포

```
Jenkins UI → krgeobuk-deploy → Build with Parameters
  ENVIRONMENT: dev 또는 prod
  SERVICE: all 또는 특정 서비스명
```

---

## K8s 배포

Jenkins 자체를 Kubernetes에서 운영하는 매니페스트는 `k8s/` 디렉토리에 있습니다.

자세한 내용은 [k8s/README.md](./k8s/README.md)를 참고하세요.
