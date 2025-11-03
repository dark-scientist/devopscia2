# Prithwin CIA 2 – DevOps (AWS CI/CD with Jenkins & Docker)

End-to-end pipeline: **GitHub → Jenkins → Docker → ECR → ECS Fargate (ALB)**

## Contents
- `index.html` — static site
- `Dockerfile` — container image (Nginx)
- `Jenkinsfile` — CI/CD (build/test/push/deploy)
- `cloudformation/ecs-fargate.yml` — VPC, ALB, ECS Fargate, IAM, logs
- `scripts/provision_aws.sh` — one-time infra
- `scripts/deploy_to_aws.sh` — update to a new image

## 1) Push to GitHub
```bash
unzip prithwin-cia2-devops-aws.zip && cd prithwin-cia2-devops-aws
git init && git branch -m main
git add . && git commit -m "AWS CI/CD initial"
git remote add origin https://github.com/dark-scientist/prithwin-cia2-devops-aws.git
git push -u origin main
```

## 2) Provision AWS infra
```bash
export AWS_REGION=ap-south-1
export ECR_REPO=prithwin-cia2-devops
export STACK_NAME=prithwin-cicd-ecs
bash scripts/provision_aws.sh
```

## 3) Jenkins setup
- Agent with **Docker** and **AWS CLI**
- Credentials:
  - `aws-access-key-id`, `aws-secret-access-key` (string secret)
  - `aws-session-token` (optional)
- Pipeline from SCM: `https://github.com/dark-scientist/prithwin-cia2-devops-aws.git`

On push, Jenkins:
1) builds & tests the container,
2) pushes to ECR,
3) deploys stack with new image,
4) checks `ServiceURL` (ALB DNS).

**Screenshots to submit**: Jenkins stages, ECR repo with tags, App in browser (ALB DNS), Jenkinsfile.
