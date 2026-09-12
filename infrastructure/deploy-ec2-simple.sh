#!/bin/bash

# Simple EC2 Deployment Script - Non-interactive

set -e

# Configuration
KEY_NAME="tipjar-key"
SECURITY_GROUP="tipjar-ec2-sg"
INSTANCE_TYPE="t3.micro"
AMI_ID="ami-0c7217cdde317cfec"  # Amazon Linux 2023 in us-east-1
REGION="us-east-1"

echo "Creating EC2 instance for TipJar Backend..."

# Create key pair if it doesn't exist
if aws ec2 describe-key-pairs --key-names $KEY_NAME --region $REGION 2>/dev/null; then
  echo "Key pair already exists: $KEY_NAME"
else
  echo "Creating key pair..."
  aws ec2 create-key-pair --key-name $KEY_NAME --region $REGION --query 'KeyMaterial' --output text > tipjar-key.pem
  chmod 400 tipjar-key.pem
  echo "Key pair created: tipjar-key.pem"
fi

# Create security group if it doesn't exist
if aws ec2 describe-security-groups --group-names $SECURITY_GROUP --region $REGION 2>/dev/null; then
  SG_ID=$(aws ec2 describe-security-groups --group-names $SECURITY_GROUP --region $REGION --query 'SecurityGroups[0].GroupId' --output text)
  echo "Security group already exists: $SG_ID"
else
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

# Launch EC2 instance without user data (will configure manually)
echo "Launching EC2 instance..."
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --count 1 \
  --instance-type $INSTANCE_TYPE \
  --key-name $KEY_NAME \
  --security-group-ids $SG_ID \
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
echo "1. Wait 2-3 minutes for instance to fully initialize"
echo "2. SSH into the instance:"
echo "   ssh -i tipjar-key.pem ec2-user@$PUBLIC_IP"
echo ""
echo "3. Copy application files:"
echo "   scp -i tipjar-key.pem -r . ec2-user@$PUBLIC_IP:/home/ec2-user/tipjar-backend"
echo ""
echo "4. SSH into instance and setup:"
echo "   ssh -i tipjar-key.pem ec2-user@$PUBLIC_IP"
echo "   cd /home/ec2-user/tipjar-backend"
echo "   sudo yum install -y nodejs"
echo "   npm install"
echo "   sudo yum install -y postgresql-server"
echo "   sudo postgresql-setup initdb"
echo "   sudo systemctl start postgresql"
echo "   sudo systemctl enable postgresql"
echo ""
echo "5. Setup database:"
echo "   sudo -u postgres psql -c \"CREATE DATABASE tipjar_db;\""
echo "   sudo -u postgres psql -c \"CREATE USER tipjar_user WITH PASSWORD 'your-password';\""
echo "   sudo -u postgres psql -c \"GRANT ALL PRIVILEGES ON DATABASE tipjar_db TO tipjar_user;\""
echo "   sudo -u postgres psql -d tipjar_db -c \"GRANT ALL ON SCHEMA public TO tipjar_user;\""
echo ""
echo "6. Run migrations:"
echo "   PGPASSWORD=your-password psql -h localhost -U tipjar_user -d tipjar_db -f schema.sql"
echo "   PGPASSWORD=your-password psql -h localhost -U tipjar_user -d tipjar_db -f stored_providers.sql"
echo "   PGPASSWORD=your-password psql -h localhost -U tipjar_user -d tipjar_db -f stored_tips.sql"
echo "   PGPASSWORD=your-password psql -h localhost -U tipjar_user -d tipjar_db -f stored_bank_payments.sql"
echo "   PGPASSWORD=your-password psql -h localhost -U tipjar_user -d tipjar_db -f functions.sql"
echo ""
echo "7. Setup environment:"
echo "   cat > .env << EOF"
echo "   DB_HOST=localhost"
echo "   DB_PORT=5432"
echo "   DB_NAME=tipjar_db"
echo "   DB_USER=tipjar_user"
echo "   DB_PASSWORD=your-password"
echo "   PORT=3001"
echo "   EOF"
echo ""
echo "8. Start application:"
echo "   npm install -g pm2"
echo "   pm2 start server.js --name tipjar-backend"
echo "   pm2 save"
echo "   pm2 startup"
