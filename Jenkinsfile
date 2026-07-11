pipeline {
    agent any

    environment {
        DOCKERHUB_CREDENTIALS = credentials('dockerhub-creds')   // Jenkins credential ID (username+password)
        DOCKERHUB_USERNAME    = 'anukavb'
        IMAGE_NAME            = "${DOCKERHUB_USERNAME}/devops-project-app"
        IMAGE_TAG             = "${BUILD_NUMBER}"
        EC2_HOST              = 'ubuntu@13.232.245.249'          // fill in after terraform apply
        APP_PORT              = '5000'
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', url: 'https://github.com/anukavb/webapp-deploy-project.git'
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('MySonarQubeServer') {   // name configured in Manage Jenkins > System
                    sh '''
                        sonar-scanner \
                          -Dsonar.projectKey=devops-project-app \
                          -Dsonar.sources=. \
                          -Dsonar.host.url=$SONAR_HOST_URL \
                          -Dsonar.login=$SONAR_AUTH_TOKEN
                    '''
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                sh "docker build -t ${IMAGE_NAME}:${IMAGE_TAG} -t ${IMAGE_NAME}:latest ./app"
            }
        }

        stage('Trivy Scan') {
            steps {
                sh "trivy image --severity HIGH,CRITICAL --exit-code 0 --format table -o trivy-report.txt ${IMAGE_NAME}:${IMAGE_TAG}"
                archiveArtifacts artifacts: 'trivy-report.txt', fingerprint: true
            }
        }

        stage('Push to Docker Hub') {
            steps {
                sh "echo $DOCKERHUB_CREDENTIALS_PSW | docker login -u $DOCKERHUB_CREDENTIALS_USR --password-stdin"
                sh "docker push ${IMAGE_NAME}:${IMAGE_TAG}"
                sh "docker push ${IMAGE_NAME}:latest"
            }
        }

        stage('Deploy to EC2') {
            steps {
                sshagent(credentials: ['ec2-ssh-key']) {   // SSH private key credential in Jenkins
                    sh """
                        ssh -o StrictHostKeyChecking=no ${EC2_HOST} '
                          docker pull ${IMAGE_NAME}:latest &&
                          docker stop app-container || true &&
                          docker rm app-container || true &&
                          docker run -d --name app-container -p 80:${APP_PORT} ${IMAGE_NAME}:latest
                        '
                    """
                }
            }
        }
    }

    post {
        always {
            sh 'docker logout || true'
        }
        success {
            echo 'Pipeline completed successfully. App deployed on EC2.'
        }
        failure {
            echo 'Pipeline failed. Check console output above.'
        }
    }
}
