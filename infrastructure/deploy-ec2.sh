#!/bin/bash

# EC2 Deployment Script for TipJar Backend

set -e

# Configuration
KEY_NAME="tipjar-key"
SECURITY_GROUP="tipjar-ec2-sg"
INSTANCE_TYPE="t3.micro"
AMI_ID="ami-0c7217cdde317cfec"  # Amazon Linux 2023 in us-east-1 (update for your region)
REGION="us-east-1"

echo "Creating EC2 instance for TipJar Backend..."

# Create key pair if it doesn't exist
if ! aws ec2 describe-key-pairs --key-names $KEY_NAME --region $REGION 2>/dev/null; then
  echo "Creating key pair..."
  aws ec2 create-key-pair --key-name $KEY_NAME --region $REGION --query 'KeyMaterial' --output text > tipjar-key.pem
  chmod 400 tipjar-key.pem
  echo "Key pair created: tipjar-key.pem"
fi

# Create security group if it doesn't exist
SG_ID=$(aws ec2 describe-security-groups --group-names $SECURITY_GROUP --region $REGION --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || echo "")

if [ -z "$SG_ID" ]; then
  echo "Creating security group..."
  SG_ID=$(aws ec2 create-security-group --group-name $SECURITY_GROUP --description "Security group for TipJar EC2" --region $REGION --query 'GroupId' --output text)
  
  # Allow SSH
  aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 22 --cidr 0.0.0.0/0 --region $REGION
  
  # Allow HTTP
  aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 80 --cidr 0.0.0.0/0 --region $REGION
  
  # Allow application port
  aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 3001 --cidr 0.0.0.0/0 --region $REGION
  
  echo "Security group created: $SG_ID"
fi

# Get environment variables from user or use defaults
read -p "Enter RDS endpoint (or press Enter to skip): " RDS_ENDPOINT
read -p "Enter DB name (default: tipjar_db): " DB_NAME
DB_NAME=${DB_NAME:-tipjar_db}
read -p "Enter DB user (default: tipjar_user): " DB_USER
DB_USER=${DB_USER:-tipjar_user}
read -s -p "Enter DB password: " DB_PASSWORD
echo
read -p "Enter AWS Access Key ID (or press Enter to skip): " AWS_ACCESS_KEY_ID
read -s -p "Enter AWS Secret Access Key (or press Enter to skip): " AWS_SECRET_ACCESS_KEY
echo
read -p "Enter AWS Region (default: us-east-1): " AWS_REGION
AWS_REGION=${AWS_REGION:-us-east-1}
read -p "Enter S3 Bucket Name (or press Enter to skip): " S3_BUCKET_NAME

# Create user data script with environment variables
USER_DATA=$(cat infrastructure/ec2-user-data.sh | \
  sed "s/\${DB_HOST}/$RDS_ENDPOINT/g" | \
  sed "s/\${DB_PORT}/5432/g" | \
  sed "s/\${DB_NAME}/$DB_NAME/g" | \
  sed "s/\${DB_USER}/$DB_USER/g" | \
  sed "s/\${DB_PASSWORD}/$DB_PASSWORD/g" | \
  sed "s/\${AWS_ACCESS_KEY_ID}/$AWS_ACCESS_KEY_ID/g" | \
  sed "s/\${AWS_SECRET_ACCESS_KEY}/$AWS_SECRET_ACCESS_KEY/g" | \
  sed "s/\${AWS_REGION}/$AWS_REGION/g" | \
  sed "s/\${S3_BUCKET_NAME}/$S3_BUCKET_NAME/g" | \
  base64 -w 0)

# Launch EC2 instance
echo "Launching EC2 instance..."
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --count 1 \
  --instance-type $INSTANCE_TYPE \
  --key-name $KEY_NAME \
  --security-group-ids $SG_ID \
  --user-data "$USER_DATA" \
  --region $REGION \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "Instance launched: $INSTANCE_ID"

# Wait for instance to be running
echo "Waiting for instance to be running..."
aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region $REGION

# Get public IP
PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --region $REGION --query 'Instances[0].PublicIpAddress' --output text)
PUBLIC_DNS=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --region $REGION --query 'Instances[0].PublicDnsName' --output text)

echo "=========================================="
echo "EC2 Instance deployed successfully!"
echo "=========================================="
echo "Instance ID: $INSTANCE_ID"
echo "Public IP: $PUBLIC_IP"
echo "Public DNS: $PUBLIC_DNS"
echo "SSH command: ssh -i tipjar-key.pem ec2-user@$PUBLIC_IP"
echo "Application URL: http://$PUBLIC_IP:3001"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Copy your application files to the instance:"
echo "   scp -i tipjar-key.pem -r . ec2-user@$PUBLIC_IP:/home/ec2-user/tipjar-backend"
echo ""
echo "2. SSH into the instance:"
echo "   ssh -i tipjar-key.pem ec2-user@$PUBLIC_IP"
echo ""
echo "3. Navigate to app directory and install dependencies:"
echo "   cd /home/ec2-user/tipjar-backend"
echo "   npm install"
echo ""
echo "4. Run database migrations (if using RDS):"
echo "   ./infrastructure/migrate-rds.sh $RDS_ENDPOINT"
echo ""
echo "5. Start the application:"
echo "   pm2 start server.js --name tipjar-backend"
echo "   pm2 save"
