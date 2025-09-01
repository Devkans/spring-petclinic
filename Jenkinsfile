pipeline {
    agent any

    environment {
        NEXUS_REGISTRY   = '${NEXUS_PATH}'   // приходит из Jenkins var/credential
        DOCKER_MAIN_REPO = 'docker-main'
        DOCKER_MR_REPO   = 'docker-mr'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.SHORT_GIT_COMMIT = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                }
            }
        }

        stage('Checkstyle') {
            steps {
                sh 'mvn checkstyle:checkstyle'
                archiveArtifacts artifacts: 'target/checkstyle-result.xml', allowEmptyArchive: true
            }
        }

        stage('Test') {
            steps {
                sh 'mvn test'
            }
            post {
                always {
                    // публикуем отчёты JUnit для Jenkins Test Result
                    junit 'target/surefire-reports/*.xml'
                    // архивируем как артефакты для загрузки
                    archiveArtifacts artifacts: 'target/surefire-reports/*.xml', allowEmptyArchive: true
                }
            }
        }

        stage('Build') {
            steps {
                sh 'mvn clean package -DskipTests'
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    if (env.CHANGE_ID) {
                        // MR build
                        env.IMAGE_NAME = "${NEXUS_REGISTRY}/${DOCKER_MR_REPO}:${SHORT_GIT_COMMIT}"
                    } else {
                        // Normal branch build
                        env.IMAGE_NAME = "${NEXUS_REGISTRY}/${DOCKER_MAIN_REPO}:${SHORT_GIT_COMMIT}"
                    }
                    sh "docker build -t ${IMAGE_NAME} ."
                }
            }
        }

        stage('Push to Nexus') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'nexus-docker-creds',
                    usernameVariable: 'NEXUS_USERNAME',
                    passwordVariable: 'NEXUS_PASSWORD'
                )]) {
                    sh """
                        echo "${NEXUS_PASSWORD}" | docker login ${NEXUS_REGISTRY} -u "${NEXUS_USERNAME}" --password-stdin
                        docker push ${IMAGE_NAME}
                    """
                }
            }
        }
        stage('Debug') {
            steps {
                echo "Branch: ${env.BRANCH_NAME}"
                echo "Change ID (MR?): ${env.CHANGE_ID}"
                echo "Image will be pushed to: ${IMAGE_NAME}"
            }
        }
    }
}
