# AWS Deployment Guide for TipJar Backend

This guide will help you deploy the TipJar backend to AWS using ECS (Elastic Container Service) with RDS PostgreSQL.

## Prerequisites

- AWS Account with appropriate permissions
- AWS CLI installed and configured
- Docker installed locally
- Node.js 18+ installed

## Architecture Overview

- **ECS Fargate**: Container orchestration for the Node.js backend
- **RDS PostgreSQL**: Managed PostgreSQL database
- **S3**: Object storage for uploaded images
- **Application Load Balancer**: Traffic distribution and SSL termination
- **CloudWatch**: Logging and monitoring

## Step 1: Set Up AWS Resources

### 1.1 Create VPC and Networking

```bash
# Create VPC
VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --query 'Vpc.VpcId' --output text)
echo "Created VPC: $VPC_ID"

# Enable DNS support
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-support
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames

# Create Internet Gateway
IGW_ID=$(aws ec2 create-internet-gateway --query 'InternetGateway.InternetGatewayId' --output text)
aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID
echo "Created IGW: $IGW_ID"

# Create public subnets
PUBLIC_SUBNET_1=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.1.0/24 --availability-zone us-east-1a --query 'Subnet.SubnetId' --output text)
PUBLIC_SUBNET_2=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.2.0/24 --availability-zone us-east-1b --query 'Subnet.SubnetId' --output text)
echo "Created public subnets: $PUBLIC_SUBNET_1, $PUBLIC_SUBNET_2"

# Create private subnets
PRIVATE_SUBNET_1=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.3.0/24 --availability-zone us-east-1a --query 'Subnet.SubnetId' --output text)
PRIVATE_SUBNET_2=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.4.0/24 --availability-zone us-east-1b --query 'Subnet.SubnetId' --output text)
echo "Created private subnets: $PRIVATE_SUBNET_1, $PRIVATE_SUBNET_2"

# Create route table for public subnets
ROUTE_TABLE_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-route --route-table-id $ROUTE_TABLE_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID
aws ec2 associate-route-table --route-table-id $ROUTE_TABLE_ID --subnet-id $PUBLIC_SUBNET_1
aws ec2 associate-route-table --route-table-id $ROUTE_TABLE_ID --subnet-id $PUBLIC_SUBNET_2
echo "Created route table: $ROUTE_TABLE_ID"

# Create security group for ECS
SG_ID=$(aws ec2 create-security-group --group-name tipjar-ecs-sg --description "Security group for ECS" --vpc-id $VPC_ID --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 3001 --cidr 0.0.0.0/0
echo "Created security group: $SG_ID"

# Create security group for RDS (only accessible from ECS)
RDS_SG_ID=$(aws ec2 create-security-group --group-name tipjar-rds-sg --description "Security group for RDS" --vpc-id $VPC_ID --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id $RDS_SG_ID --protocol tcp --port 5432 --source-group $SG_ID
echo "Created RDS security group: $RDS_SG_ID"
```

### 1.2 Create RDS PostgreSQL Instance

```bash
# Create RDS PostgreSQL subnet group
aws rds create-db-subnet-group \
  --db-subnet-group-name tipjar-subnet-group \
  --db-subnet-group-description "Subnet group for TipJar RDS" \
  --subnet-ids $PRIVATE_SUBNET_1 $PRIVATE_SUBNET_2

# Create RDS PostgreSQL instance
DB_INSTANCE_ID=$(aws rds create-db-instance \
  --db-instance-identifier tipjar-db \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --engine-version 15.4 \
  --master-username tipjar_user \
  --master-user-password YourSecurePassword123! \
  --allocated-storage 20 \
  --storage-type gp2 \
  --db-subnet-group-name tipjar-subnet-group \
  --vpc-security-group-ids $RDS_SG_ID \
  --backup-retention-period 7 \
  --no-multi-az \
  --publicly-accessible \
  --query 'DBInstance.DBInstanceIdentifier' \
  --output text)

echo "Creating RDS instance: $DB_INSTANCE_ID"
echo "Wait for instance to be available (this takes 10-15 minutes)..."

# Wait for RDS to be available
aws rds wait db-instance-available --db-instance-identifier tipjar-db

# Get RDS endpoint
RDS_ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier tipjar-db \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text)

echo "RDS endpoint: $RDS_ENDPOINT"
```

### 1.3 Create S3 Bucket for Uploads

```bash
# Create S3 bucket
aws s3 mb s3://tipjar-uploads --region us-east-1

# Enable public read access (or configure CloudFront)
aws s3api put-bucket-policy --bucket tipjar-uploads --policy file://infrastructure/s3-policy.json
```

### 1.4 Create ECR Repository

```bash
# Create ECR repository
aws ecr create-repository --repository-name tipjar-backend --region us-east-1
```

### 1.5 Create ECS Cluster

```bash
# Create ECS cluster
aws ecs create-cluster --cluster-name tipjar-cluster --region us-east-1
```

### 1.6 Create IAM Roles

Create the following IAM roles:

- **ecsTaskExecutionRole**: For ECS to pull images and write logs
- **ecsTaskRole**: For the application to access S3 and RDS

```bash
# Create execution role
aws iam create-role --role-name ecsTaskExecutionRole --assume-role-policy-document file://infrastructure/ecs-execution-role-trust.json
aws iam attach-role-policy --role-name ecsTaskExecutionRole --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

# Create task role with S3 and RDS access
aws iam create-role --role-name ecsTaskRole --assume-role-policy-document file://infrastructure/ecs-task-role-trust.json
aws iam attach-role-policy --role-name ecsTaskRole --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess
```

## Step 2: Configure Environment Variables

### 2.1 Store Secrets in AWS Secrets Manager

```bash
# Store database credentials
aws secretsmanager create-secret --name tipjar/db-host --secret-string "your-rds-endpoint.rds.amazonaws.com"
aws secretsmanager create-secret --name tipjar/db-port --secret-string "5432"
aws secretsmanager create-secret --name tipjar/db-name --secret-string "tipjar_db"
aws secretsmanager create-secret --name tipjar/db-user --secret-string "tipjar_user"
aws secretsmanager create-secret --name tipjar/db-password --secret-string "your-secure-password"

# Store AWS credentials
aws secretsmanager create-secret --name tipjar/aws-access-key-id --secret-string "your-access-key-id"
aws secretsmanager create-secret --name tipjar/aws-secret-access-key --secret-string "your-secret-access-key"
aws secretsmanager create-secret --name tipjar/aws-region --secret-string "us-east-1"
aws secretsmanager create-secret --name tipjar/s3-bucket-name --secret-string "tipjar-uploads"
```

### 2.2 Update Task Definition

Edit `infrastructure/ecs-task-definition.json`:
- Replace `ACCOUNT_ID` with your AWS account ID
- Replace `REGION` with your AWS region
- Replace `TASK_DEFINITION_ARN` after creating the task definition

## Step 3: Migrate Database

```bash
# Make the migration script executable
chmod +x infrastructure/migrate-rds.sh

# Run migration
./infrastructure/migrate-rds.sh your-rds-endpoint.rds.amazonaws.com tipjar_db tipjar_user your-password
```

## Step 4: Build and Deploy

### 4.1 Build Docker Image

```bash
# Build production image
docker build -f infrastructure/Dockerfile.prod -t tipjar-backend:latest .
```

### 4.2 Push to ECR

```bash
# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com

# Tag image
docker tag tipjar-backend:latest YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/tipjar-backend:latest

# Push image
docker push YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/tipjar-backend:latest
```

### 4.3 Register Task Definition

```bash
aws ecs register-task-definition --cli-input-json file://infrastructure/ecs-task-definition.json
```

### 4.4 Create ECS Service

```bash
aws ecs create-service \
  --cluster tipjar-cluster \
  --service-name tipjar-backend \
  --task-definition tipjar-backend \
  --desired-count 1 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-12345,subnet-67890],securityGroups=[sg-12345],assignPublicIp=ENABLED}" \
  --region us-east-1
```

### 4.5 Create Application Load Balancer

```bash
# Create ALB
aws elbv2 create-load-balancer \
  --name tipjar-alb \
  --subnets subnet-12345 subnet-67890 \
  --security-groups sg-12345 \
  --region us-east-1

# Create target group
aws elbv2 create-target-group \
  --name tipjar-targets \
  --protocol HTTP \
  --port 3001 \
  --vpc-id vpc-12345 \
  --target-type ip \
  --region us-east-1

# Create listener
aws elbv2 create-listener \
  --load-balancer-arn YOUR_ALB_ARN \
  --protocol HTTP \
  --port 80 \
  --default-actions Type=forward,TargetGroupArn=YOUR_TARGET_GROUP_ARN \
  --region us-east-1
```

## Step 5: Automated Deployment

Use the provided deployment script:

```bash
# Make it executable
chmod +x infrastructure/deploy.sh

# Run deployment
./infrastructure/deploy.sh
```

## Step 6: Configure SSL (Optional but Recommended)

```bash
# Request SSL certificate via ACM
aws acm request-certificate --domain-name api.tipjar.com --validation-method DNS

# Create HTTPS listener
aws elbv2 create-listener \
  --load-balancer-arn YOUR_ALB_ARN \
  --protocol HTTPS \
  --port 443 \
  --certificates CertificateArn=YOUR_CERT_ARN \
  --default-actions Type=forward,TargetGroupArn=YOUR_TARGET_GROUP_ARN \
  --region us-east-1
```

## Monitoring and Logs

### CloudWatch Logs

```bash
# View logs
aws logs tail /ecs/tipjar-backend --follow
```

### CloudWatch Metrics

Set up CloudWatch dashboards for:
- CPU utilization
- Memory utilization
- Request count
- Error rate

## Cost Optimization

- Use Fargate Spot instances for non-critical workloads
- Enable S3 lifecycle policies for old uploads
- Use RDS Reserved Instances for production
- Set up CloudWatch alarms to monitor costs

## Security Best Practices

1. **Never commit credentials** - Use AWS Secrets Manager
2. **Enable VPC endpoints** - For S3 and RDS access
3. **Use security groups** - Restrict access to necessary ports only
4. **Enable encryption** - Use SSL/TLS for all communications
5. **Regular updates** - Keep dependencies and AMIs updated
6. **Enable audit logging** - Use CloudTrail for API auditing

## Troubleshooting

### Container won't start
```bash
# Check task logs
aws logs tail /ecs/tipjar-backend --follow

# Describe task
aws ecs describe-tasks --cluster tipjar-cluster --tasks TASK_ID
```

### Database connection issues
```bash
# Check security group allows traffic from ECS to RDS
# Verify VPC routing
# Check RDS is in available state
```

### S3 upload failures
```bash
# Verify IAM role has S3 permissions
# Check bucket policy
# Verify bucket exists in correct region
```

## Rollback Procedure

```bash
# Revert to previous task definition
aws ecs update-service \
  --cluster tipjar-cluster \
  --service tipjar-backend \
  --task-definition tipjar-backend:PREVIOUS_VERSION \
  --force-new-deployment
```

## Support

For issues or questions:
- Check CloudWatch logs
- Review ECS events
- Verify security group rules
- Check RDS connection status
