#!/usr/bin/env groovy

/**
 * Docker 이미지 빌드 및 푸시
 *
 * @param config Map 설정
 *   - serviceName: 서비스 이름 (required)
 *   - imageTag: 이미지 태그 (required)
 *   - dockerRegistry: Docker 레지스트리 (default: 'krgeobuk')
 *   - dockerfile: Dockerfile 경로 (default: 'Dockerfile')
 *   - context: 빌드 컨텍스트 (default: '.')
 *   - additionalTags: 추가 태그 배열 (default: [])
 *   - buildArgs: 빌드 인자 (default: '')
 *   - noCache: 캐시 사용 안 함 (default: false)
 */
def call(Map config) {
    // 필수 파라미터 검증
    if (!config.serviceName) {
        error("serviceName is required")
    }
    if (!config.imageTag) {
        error("imageTag is required")
    }

    // 기본값 설정
    def serviceName = config.serviceName
    def imageTag = config.imageTag
    def dockerRegistry = config.dockerRegistry ?: 'krgeobuk'
    def dockerfile = config.dockerfile ?: 'Dockerfile'
    def context = config.context ?: '.'
    def additionalTags = config.additionalTags ?: []
    def buildArgs = config.buildArgs ?: ''
    def noCache = config.noCache ?: false

    // 이미지 이름
    def imageName = "${dockerRegistry}/${serviceName}"
    def fullImageName = "${imageName}:${imageTag}"

    echo """
    ========================================
    Building Docker Image
    ========================================
    Service: ${serviceName}
    Image: ${fullImageName}
    Dockerfile: ${dockerfile}
    Context: ${context}
    Additional Tags: ${additionalTags}
    No Cache: ${noCache}
    ========================================
    """

    try {
        // Docker 빌드 명령어 구성
        def buildCmd = "docker build"

        if (noCache) {
            buildCmd += " --no-cache"
        }

        if (buildArgs) {
            buildCmd += " ${buildArgs}"
        }

        buildCmd += " -f ${dockerfile}"
        buildCmd += " -t ${fullImageName}"

        // 추가 태그
        additionalTags.each { tag ->
            buildCmd += " -t ${imageName}:${tag}"
        }

        buildCmd += " ${context}"

        // Docker 빌드 실행
        sh buildCmd

        echo "✓ Docker image built successfully: ${fullImageName}"

        // Docker 레지스트리에 푸시
        withCredentials([usernamePassword(
            credentialsId: env.DOCKER_CREDENTIALS_ID ?: 'docker-registry-credentials',
            usernameVariable: 'DOCKER_USER',
            passwordVariable: 'DOCKER_PASS'
        )]) {
            sh """
                echo \$DOCKER_PASS | docker login -u \$DOCKER_USER --password-stdin
                docker push ${fullImageName}
            """

            // 추가 태그 푸시
            additionalTags.each { tag ->
                sh "docker push ${imageName}:${tag}"
                echo "✓ Pushed additional tag: ${imageName}:${tag}"
            }
        }

        echo "✓ Docker image pushed successfully: ${fullImageName}"

        // 로컬 이미지 정리 (옵션)
        if (config.cleanupLocal) {
            sh """
                docker rmi ${fullImageName} || true
                ${additionalTags.collect { "docker rmi ${imageName}:${it} || true" }.join('\n')}
            """
            echo "✓ Local images cleaned up"
        }

        return [
            success: true,
            imageName: fullImageName,
            tags: [imageTag] + additionalTags
        ]

    } catch (Exception e) {
        echo "✗ Docker build failed: ${e.message}"
        throw e
    }
}
