// NOTE: this pipeline uses Windows `bat` steps because Jenkins is running
// locally on Windows. If you ever move Jenkins to a Linux server, swap
// `bat` back to `sh` and use Linux-style syntax ($VAR instead of %VAR%).
pipeline {
    agent any

    environment {
        DOCKERHUB_CREDENTIALS = credentials('dockerhub-creds')   // Jenkins credential ID (username+password)
        DOCKERHUB_USERNAME    = 'anukavb'
        IMAGE_NAME            = "${DOCKERHUB_USERNAME}/devops-project-app"
        IMAGE_TAG             = "${BUILD_NUMBER}"
        EC2_HOST              = 'ubuntu@13.232.245.249'
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
                script {
                    def scannerHome = tool 'SonarScanner'   // name set in Manage Jenkins > Tools
                    withSonarQubeEnv('MySonarQubeServer') {   // name set in Manage Jenkins > System
                        bat """
                            "${scannerHome}\\bin\\sonar-scanner.bat" ^
                              -Dsonar.projectKey=devops-project-app ^
                              -Dsonar.sources=. ^
                              -Dsonar.host.url=%SONAR_HOST_URL% ^
                              -Dsonar.login=%SONAR_AUTH_TOKEN%
                        """
                    }
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
                bat "docker build -t %IMAGE_NAME%:%IMAGE_TAG% -t %IMAGE_NAME%:latest .\\app"
            }
        }

        stage('Trivy Scan') {
            steps {
                bat "trivy image --severity HIGH,CRITICAL --exit-code 0 --format table -o trivy-report.txt %IMAGE_NAME%:%IMAGE_TAG%"
                archiveArtifacts artifacts: 'trivy-report.txt', fingerprint: true
            }
        }

        stage('Push to Docker Hub') {
            steps {
                bat "docker login -u %DOCKERHUB_CREDENTIALS_USR% -p %DOCKERHUB_CREDENTIALS_PSW%"
                bat "docker push %IMAGE_NAME%:%IMAGE_TAG%"
                bat "docker push %IMAGE_NAME%:latest"
            }
        }

        stage('Deploy to EC2') {
            steps {
                withCredentials([sshUserPrivateKey(credentialsId: 'ec2-ssh-key', keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER')]) {
                    bat "icacls %SSH_KEY% /inheritance:r"
                    bat "icacls %SSH_KEY% /grant:r \"NT AUTHORITY\\SYSTEM:(R)\" \"BUILTIN\\Administrators:(F)\""
                    bat "ssh -o StrictHostKeyChecking=no -i %SSH_KEY% %SSH_USER%@13.232.245.249 \"docker pull %IMAGE_NAME%:latest && docker stop app-container || true && docker rm app-container || true && docker run -d --name app-container -p 80:%APP_PORT% %IMAGE_NAME%:latest\""
                }
            }
        }
    }

    post {
        always {
            bat 'docker logout || exit 0'
        }
        success {
            echo 'Pipeline completed successfully. App deployed on EC2.'
        }
        failure {
            echo 'Pipeline failed. Check console output above.'
        }
    }
}