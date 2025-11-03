\
pipeline {
  agent any
  options { timestamps() }
  environment {
    AWS_REGION  = "ap-south-1"              // Mumbai
    ECR_REPO    = "prithwin-cia2-devops"    // ECR repo name
    STACK_NAME  = "prithwin-cicd-ecs"       // CloudFormation stack
    IMAGE_NAME  = "prithwin-cia2-devops"
  }
  triggers { githubPush() }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }
    stage('Set Version Tag') {
      steps {
        script {
          def shortCommit = sh(returnStdout: true, script: 'git rev-parse --short=7 HEAD').trim()
          env.IMAGE_TAG = "${shortCommit}-${env.BUILD_NUMBER}"
        }
      }
    }
    stage('Configure AWS Credentials') {
      steps {
        withCredentials([
          string(credentialsId: 'aws-access-key-id',     variable: 'AWS_ACCESS_KEY_ID'),
          string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY'),
          string(credentialsId: 'aws-session-token',     variable: 'AWS_SESSION_TOKEN') // optional
        ]) {
          sh 'aws sts get-caller-identity --region ${AWS_REGION}'
          script {
            env.AWS_ACCOUNT_ID = sh(returnStdout: true, script: 'aws sts get-caller-identity --query Account --output text --region ${AWS_REGION}').trim()
          }
        }
      }
    }
    stage('ECR Login + Ensure Repo') {
      steps {
        sh '''
          set -euxo pipefail
          aws ecr describe-repositories --repository-names ${ECR_REPO} --region ${AWS_REGION} >/dev/null 2>&1 || \
            aws ecr create-repository --repository-name ${ECR_REPO} --region ${AWS_REGION}
          aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
        '''
      }
    }
    stage('Build Image') {
      steps {
        script { env.IMAGE_URI = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}:${IMAGE_TAG}" }
        sh '''
          set -euxo pipefail
          docker build -t ${IMAGE_URI} .
          docker tag ${IMAGE_URI} ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}:latest
        '''
      }
    }
    stage('Test Container') {
      steps {
        sh '''
          set -euxo pipefail
          cid=$(docker run -d -p 8080:80 ${IMAGE_URI})
          for i in $(seq 1 30); do
            if curl -fsS http://localhost:8080 | grep -iq "Prithwin CIA 2"; then break; fi
            sleep 1
          done
          curl -fsS http://localhost:8080 | grep -iq "Prithwin CIA 2"
          docker stop "$cid"
        '''
      }
    }
    stage('Push Image') {
      steps {
        sh '''
          set -euxo pipefail
          docker push ${IMAGE_URI}
          docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}:latest
        '''
      }
    }
    stage('Provision/Update ECS via CloudFormation') {
      steps {
        sh '''
          set -euxo pipefail
          aws cloudformation deploy \
            --stack-name ${STACK_NAME} \
            --template-file cloudformation/ecs-fargate.yml \
            --capabilities CAPABILITY_NAMED_IAM \
            --region ${AWS_REGION} \
            --parameter-overrides \
                EcrRepositoryName=${ECR_REPO} \
                ImageUrl=${IMAGE_URI}
        '''
      }
    }
    stage('Health Check') {
      steps {
        script {
          env.APP_URL = sh(returnStdout: true, script: "aws cloudformation describe-stacks --stack-name ${STACK_NAME} --region ${AWS_REGION} --query 'Stacks[0].Outputs[?OutputKey==`ServiceURL`].OutputValue' --output text").trim()
        }
        sh '''
          set -euxo pipefail
          echo "App URL: http://${APP_URL}"
          for i in $(seq 1 40); do
            if curl -fsS "http://${APP_URL}" | grep -iq "Prithwin CIA 2"; then exit 0; fi
            sleep 5
          done
          exit 1
        '''
      }
    }
  }
  post {
    success { echo "Deployed to: http://${env.APP_URL}" }
    failure { echo "Build failed." }
  }
}
