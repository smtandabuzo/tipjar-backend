#!/bin/bash

set -e

# Configuration
AWS_REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REPOSITORY_NAME="tipjar-backend"
CLUSTER_NAME="tipjar-cluster"
SERVICE_NAME="tipjar-backend"

echo "Building Docker image..."
docker build -f infrastructure/Dockerfile.prod -t $REPOSITORY_NAME:latest .

echo "Logging in to ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

echo "Creating ECR repository if it doesn't exist..."
aws ecr describe-repositories --repository-names $REPOSITORY_NAME --region $AWS_REGION || \
  aws ecr create-repository --repository-name $REPOSITORY_NAME --region $AWS_REGION

echo "Tagging image..."
docker tag $REPOSITORY_NAME:latest $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$REPOSITORY_NAME:latest

echo "Pushing image to ECR..."
docker push $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$REPOSITORY_NAME:latest

echo "Updating ECS service..."
aws ecs update-service --cluster $CLUSTER_NAME --service $SERVICE_NAME --force-new-deployment --region $AWS_REGION

echo "Deployment initiated successfully!"
