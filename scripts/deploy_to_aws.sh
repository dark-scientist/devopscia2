#!/usr/bin/env bash
set -euo pipefail

: "${AWS_REGION:=ap-south-1}"
: "${STACK_NAME:=prithwin-cicd-ecs}"
: "${IMAGE_URI?Set IMAGE_URI}"

aws cloudformation deploy \
  --stack-name "$STACK_NAME" \
  --template-file cloudformation/ecs-fargate.yml \
  --capabilities CAPABILITY_NAMED_IAM \
  --region "$AWS_REGION" \
  --parameter-overrides ImageUrl="$IMAGE_URI" EcrRepositoryName="$(echo "$IMAGE_URI" | awk -F'/' '{print $2}' | awk -F: '{print $1}')" \
  --no-fail-on-empty-changeset

ALB=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$AWS_REGION" --query 'Stacks[0].Outputs[?OutputKey==`ServiceURL`].OutputValue' --output text)
echo "Updated service. URL: http://$ALB"
