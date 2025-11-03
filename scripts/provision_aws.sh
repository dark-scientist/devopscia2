#!/usr/bin/env bash
set -euo pipefail

: "${AWS_REGION:=ap-south-1}"
: "${ECR_REPO:=prithwin-cia2-devops}"
: "${STACK_NAME:=prithwin-cicd-ecs}"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --region "$AWS_REGION")

aws ecr describe-repositories --repository-names "$ECR_REPO" --region "$AWS_REGION" >/dev/null 2>&1 || \
  aws ecr create-repository --repository-name "$ECR_REPO" --region "$AWS_REGION"

aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

IMAGE_URI="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO:bootstrap"
docker pull public.ecr.aws/nginx/nginx:alpine || true
docker tag public.ecr.aws/nginx/nginx:alpine "$IMAGE_URI"
docker push "$IMAGE_URI"

aws cloudformation deploy \
  --stack-name "$STACK_NAME" \
  --template-file cloudformation/ecs-fargate.yml \
  --capabilities CAPABILITY_NAMED_IAM \
  --region "$AWS_REGION" \
  --parameter-overrides \
      EcrRepositoryName="$ECR_REPO" \
      ImageUrl="$IMAGE_URI"

ALB=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$AWS_REGION" --query 'Stacks[0].Outputs[?OutputKey==`ServiceURL`].OutputValue' --output text)
echo "Provisioned. ALB URL: http://$ALB"
