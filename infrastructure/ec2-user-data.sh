#!/bin/bash

# EC2 User Data Script - Automated TipJar Backend Setup
# This script runs when the EC2 instance first launches

set -e

# Update system
yum update -y

# Install Node.js 18
curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
yum install -y nodejs git

# Install Docker
yum install -y docker
service docker start
usermod -a -G docker ec2-user

# Install PostgreSQL client
yum install -y postgresql

# Create app directory
mkdir -p /home/ec2-user/tipjar-backend
cd /home/ec2-user/tipjar-backend

# Clone repository (or copy files)
# git clone https://github.com/your-repo/tipjar-backend.git .
# For now, we'll assume files are copied manually or via S3

# Install dependencies
npm install

# Setup environment variables
cat > .env << EOF
DB_HOST=${DB_HOST}
DB_PORT=${DB_PORT}
DB_NAME=${DB_NAME}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}
PORT=3001
AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
AWS_REGION=${AWS_REGION}
S3_BUCKET_NAME=${S3_BUCKET_NAME}
EOF

# Create uploads directory
mkdir -p uploads

# Run database migrations
# PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -f schema.sql
# PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -f stored_providers.sql
# PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -f stored_tips.sql
# PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -f stored_bank_payments.sql
# PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -f functions.sql

# Install PM2 for process management
npm install -g pm2

# Start application with PM2
pm2 start server.js --name tipjar-backend
pm2 save
pm2 startup

# Configure firewall
if command -v firewall-cmd &> /dev/null; then
    firewall-cmd --permanent --add-port=3001/tcp
    firewall-cmd --reload
fi

echo "TipJar Backend setup complete!"
