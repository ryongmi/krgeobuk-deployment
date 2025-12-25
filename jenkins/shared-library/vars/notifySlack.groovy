#!/usr/bin/env groovy

/**
 * Slack 알림 전송
 *
 * @param config Map 설정
 *   - status: 빌드 상태 (SUCCESS/FAILURE/WARNING) (required)
 *   - environment: 배포 환경 (dev/prod)
 *   - service: 서비스 이름
 *   - message: 커스텀 메시지
 *   - channel: Slack 채널 (default: 환경변수 SLACK_CHANNEL)
 *   - webhookUrl: Webhook URL (default: 환경변수 SLACK_WEBHOOK)
 */
def call(Map config) {
    if (!config.status) {
        error("status is required")
    }

    def status = config.status
    def environment = config.environment ?: 'unknown'
    def service = config.service ?: 'unknown'
    def message = config.message ?: ''
    def channel = config.channel ?: env.SLACK_CHANNEL ?: '#krgeobuk-ci-cd'

    // 상태에 따른 색상 및 이모지
    def color = ''
    def emoji = ''
    def statusText = ''

    switch (status) {
        case 'SUCCESS':
            color = 'good'
            emoji = ':white_check_mark:'
            statusText = '성공'
            break
        case 'FAILURE':
            color = 'danger'
            emoji = ':x:'
            statusText = '실패'
            break
        case 'WARNING':
            color = 'warning'
            emoji = ':warning:'
            statusText = '경고'
            break
        case 'STARTED':
            color = '#0099CC'
            emoji = ':rocket:'
            statusText = '시작'
            break
        default:
            color = '#808080'
            emoji = ':grey_question:'
            statusText = status
    }

    // 빌드 정보
    def buildNumber = env.BUILD_NUMBER ?: 'N/A'
    def buildUrl = env.BUILD_URL ?: ''
    def jobName = env.JOB_NAME ?: 'Unknown Job'
    def gitBranch = env.GIT_BRANCH ?: 'unknown'
    def gitCommit = env.GIT_COMMIT_SHORT ?: env.GIT_COMMIT?.take(7) ?: 'unknown'
    def duration = currentBuild?.durationString ?: 'N/A'

    // Slack 메시지 구성
    def slackMessage = [
        channel: channel,
        color: color,
        attachments: [
            [
                color: color,
                title: "${emoji} ${jobName} - ${statusText}",
                title_link: buildUrl,
                fields: [
                    [
                        title: "환경",
                        value: environment,
                        short: true
                    ],
                    [
                        title: "서비스",
                        value: service,
                        short: true
                    ],
                    [
                        title: "빌드 번호",
                        value: "#${buildNumber}",
                        short: true
                    ],
                    [
                        title: "Git Commit",
                        value: "${gitBranch}@${gitCommit}",
                        short: true
                    ],
                    [
                        title: "소요 시간",
                        value: duration,
                        short: true
                    ],
                    [
                        title: "실행자",
                        value: env.BUILD_USER ?: 'Jenkins',
                        short: true
                    ]
                ],
                footer: "Jenkins CI/CD",
                footer_icon: "https://www.jenkins.io/images/logos/jenkins/jenkins.png",
                ts: System.currentTimeMillis() / 1000
            ]
        ]
    ]

    // 커스텀 메시지 추가
    if (message) {
        slackMessage.attachments[0].text = message
    }

    // 실패 시 추가 정보
    if (status == 'FAILURE' && buildUrl) {
        slackMessage.attachments[0].fields << [
            title: "로그",
            value: "<${buildUrl}console|콘솔 로그 보기>",
            short: false
        ]
    }

    try {
        // Slack 알림 전송
        def webhookUrl = config.webhookUrl ?: env.SLACK_WEBHOOK

        if (!webhookUrl) {
            echo "⚠ Slack webhook URL not configured, skipping notification"
            return [success: false, reason: 'No webhook URL']
        }

        // HTTP POST 요청
        def jsonPayload = groovy.json.JsonOutput.toJson(slackMessage)

        sh """
            curl -X POST \
                -H 'Content-type: application/json' \
                --data '${jsonPayload}' \
                ${webhookUrl}
        """

        echo "✓ Slack notification sent: ${status} - ${service} (${environment})"

        return [success: true, message: slackMessage]

    } catch (Exception e) {
        echo "✗ Failed to send Slack notification: ${e.message}"
        // 알림 실패는 빌드를 실패시키지 않음
        return [success: false, reason: e.message]
    }
}
