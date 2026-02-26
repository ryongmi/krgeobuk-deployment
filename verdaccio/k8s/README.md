# Verdaccio K8s 배포

krgeobuk 프로젝트의 Private NPM 레지스트리(`@krgeobuk/*`)를 Kubernetes에서 운영합니다.

## 구조

```
verdaccio/k8s/
├── pvc.yaml                # 영구 볼륨 (storage 5Gi, conf 100Mi)
├── configmap.yaml          # Verdaccio 설정 (config.yaml)
├── deployment.yaml         # Verdaccio Deployment
├── service.yaml            # ClusterIP Service (4873)
├── ingress-dev.yaml        # dev:  http://verdaccio.192.168.0.28.nip.io
├── ingress.yaml            # prod: https://verdaccio.krgeobuk.com
├── secret.yaml.template    # Secret 템플릿 (커밋 금지)
└── kustomization.yaml      # 환경에 맞게 ingress 둘 중 하나만 활성화
```

## 아키텍처

```
[npm publish / npm install]
         ↓
[NGINX Ingress]
  dev:  http://verdaccio.192.168.0.28.nip.io
  prod: https://verdaccio.krgeobuk.com
         ↓
[Verdaccio Pod - krgeobuk-devops namespace]
  ├── config.yaml     ← ConfigMap (읽기 전용)
  ├── htpasswd        ← conf PVC (Verdaccio가 직접 쓰기)
  └── storage/        ← storage PVC (패키지 파일)
```

### 볼륨 분리 구조

| PVC | 경로 | 용량 | 설명 |
|---|---|---|---|
| `verdaccio-storage-pvc` | `/verdaccio/storage` | 5Gi | 패키지 파일 |
| `verdaccio-conf-pvc` | `/verdaccio/conf` | 100Mi | htpasswd (유저 계정) |

`config.yaml`은 ConfigMap으로 관리하고, `htpasswd`만 PVC에서 쓰기 가능하게 분리합니다.
Verdaccio가 신규 유저 등록 시 htpasswd를 직접 수정하기 때문입니다.

### htpasswd 초기화 흐름

```
최초 기동: conf PVC 비어있음 → Secret의 htpasswd를 PVC로 복사
재기동:    conf PVC에 htpasswd 존재 → 건드리지 않음 (유저 등록 내역 보존)
```

---

## 배포 순서

### Step 1. htpasswd 생성

`secret.yaml`에 입력할 bcrypt 해시를 생성합니다.

```bash
# Docker로 생성 (권장)
docker run --rm verdaccio/verdaccio:5 \
  node -e "const bcrypt=require('bcryptjs'); \
  console.log('admin:' + bcrypt.hashSync('your_password', 10))"

# 출력 예시
# admin:$2b$10$abcdefghijklmnopqrstuvwxyz...
```

여러 사용자가 필요한 경우 줄을 추가합니다:
```
admin:$2b$10$xxxxx...
developer:$2b$10$yyyyy...
```

### Step 2. Secret 생성

```bash
cd verdaccio/k8s/

cp secret.yaml.template secret.yaml
vi secret.yaml   # 생성한 htpasswd 해시 입력

kubectl apply -f secret.yaml
```

### Step 3. Ingress 환경 선택

`kustomization.yaml`에서 사용할 환경의 ingress만 활성화합니다.

```yaml
# kustomization.yaml
  - ingress-dev.yaml    # dev:  http://verdaccio.192.168.0.28.nip.io
  # - ingress.yaml      # prod: https://verdaccio.krgeobuk.com
```

### Step 4. 나머지 리소스 배포

```bash
kubectl apply -k verdaccio/k8s/
```

### Step 5. 기동 확인

```bash
# Pod 상태 확인
kubectl get pods -n krgeobuk-devops -l app=verdaccio

# 로그 확인
kubectl logs -n krgeobuk-devops -l app=verdaccio -f

# 헬스체크
# dev
curl http://verdaccio.192.168.0.28.nip.io/-/ping
# prod
curl https://verdaccio.krgeobuk.com/-/ping
# 응답: {"status":"ok"}
```

---

## npm 클라이언트 설정

Verdaccio 배포 후 각 개발 환경에서 레지스트리를 설정합니다.

### 레지스트리 URL

| 환경 | URL |
|---|---|
| dev | `http://verdaccio.192.168.0.28.nip.io` |
| prod | `https://verdaccio.krgeobuk.com` |

### 로그인

```bash
# dev
npm login --registry http://verdaccio.192.168.0.28.nip.io

# prod
npm login --registry https://verdaccio.krgeobuk.com

# Username: admin (secret.yaml에 설정한 계정)
# Password: your_password
# Email: (임의 입력 가능)
```

### 레지스트리 설정

```bash
# dev: @krgeobuk 스코프만 Verdaccio 사용, 나머지는 npm 공식 레지스트리
npm config set @krgeobuk:registry http://verdaccio.192.168.0.28.nip.io

# prod
npm config set @krgeobuk:registry https://verdaccio.krgeobuk.com
```

또는 프로젝트 루트의 `.npmrc`에 추가:
```
# dev
@krgeobuk:registry=http://verdaccio.192.168.0.28.nip.io

# prod
@krgeobuk:registry=https://verdaccio.krgeobuk.com
```

### 패키지 배포 (publish)

```bash
# shared-lib 패키지 예시 (dev)
cd shared-lib/packages/core
npm publish --registry http://verdaccio.192.168.0.28.nip.io
```

### 패키지 설치 (install)

```bash
# @krgeobuk:registry 설정 후
npm install @krgeobuk/core
```

---

## 설정 변경

`configmap.yaml`의 `config.yaml`을 수정 후 적용합니다.

```bash
kubectl apply -k verdaccio/k8s/

# Pod 재시작 (설정 반영)
kubectl rollout restart deployment/verdaccio -n krgeobuk-devops
```

---

## 유저 관리

### 신규 유저 추가 (htpasswd 직접 수정)

```bash
# 새 bcrypt 해시 생성
docker run --rm verdaccio/verdaccio:5 \
  node -e "const bcrypt=require('bcryptjs'); \
  console.log('newuser:' + bcrypt.hashSync('password', 10))"

# conf PVC의 htpasswd에 직접 추가
kubectl exec -n krgeobuk-devops deploy/verdaccio -- \
  sh -c 'echo "newuser:HASH" >> /verdaccio/conf/htpasswd'
```

### 유저 목록 확인

```bash
kubectl exec -n krgeobuk-devops deploy/verdaccio -- \
  cat /verdaccio/conf/htpasswd
```

### 유저 삭제

```bash
kubectl exec -n krgeobuk-devops deploy/verdaccio -- \
  sed -i '/^username:/d' /verdaccio/conf/htpasswd
```

---

## 기존 Docker Compose 데이터 이전

Docker Compose에서 저장된 패키지를 K8s PVC로 이전합니다.

```bash
# 1. 미니PC에서 기존 storage 경로 확인
#    krgeobuk-infrastructure/docker-compose/verdaccio/storage/

# 2. Pod이 기동된 상태에서 파일 복사
kubectl cp \
  /path/to/verdaccio/storage/. \
  krgeobuk-devops/$(kubectl get pod -n krgeobuk-devops -l app=verdaccio -o jsonpath='{.items[0].metadata.name}'):/verdaccio/storage/

# 3. 권한 설정
kubectl exec -n krgeobuk-devops deploy/verdaccio -- \
  chown -R 10001:65533 /verdaccio/storage
```

---

## 문제 해결

### Pod가 기동되지 않을 때

```bash
kubectl describe pod -n krgeobuk-devops -l app=verdaccio

# initContainer 로그 확인
kubectl logs -n krgeobuk-devops -l app=verdaccio -c fix-storage-permissions
kubectl logs -n krgeobuk-devops -l app=verdaccio -c init-htpasswd
```

### 패키지 publish 실패 시 (403 Forbidden)

```bash
# 로그인 상태 확인 (dev)
npm whoami --registry http://verdaccio.192.168.0.28.nip.io

# 재로그인 (dev)
npm login --registry http://verdaccio.192.168.0.28.nip.io
```

### 패키지 install 실패 시 (404 Not Found)

```bash
# 레지스트리 설정 확인
npm config get @krgeobuk:registry

# Verdaccio에 패키지 존재 여부 확인 (dev)
curl http://verdaccio.192.168.0.28.nip.io/@krgeobuk/core
```

---

## DNS 설정

### dev (nip.io)

별도 DNS 설정 불필요합니다. `nip.io`가 IP를 자동으로 해석합니다.

```
verdaccio.192.168.0.28.nip.io → 자동으로 192.168.0.28로 해석
```

### prod

```
verdaccio.krgeobuk.com → 미니PC 공인 IP (A 레코드)
```

### prod로 전환

`kustomization.yaml`에서 ingress 파일을 교체합니다.

```yaml
  # - ingress-dev.yaml
  - ingress.yaml
```
