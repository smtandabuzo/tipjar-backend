# EC2 Deployment Guide for TipJar Backend

Simplified deployment using AWS EC2 instead of ECS.

## Prerequisites

- AWS Account with appropriate permissions
- AWS CLI installed and configured
- SSH client

## Architecture

- **EC2 Instance**: Single VM running the Node.js backend
- **RDS PostgreSQL** (optional): Managed database, or use local PostgreSQL
- **S3** (optional): Object storage for uploaded images

## Quick Start Deployment

### Option 1: Automated Deployment Script

```bash
# Make the script executable
chmod +x infrastructure/deploy-ec2.sh

# Run the deployment script
./infrastructure/deploy-ec2.sh
```

The script will:
- Create a key pair for SSH access
- Create a security group with necessary ports open
- Launch an EC2 instance with automated setup
- Provide connection details

### Option 2: Manual Deployment

#### Step 1: Create Key Pair

```bash
# Create key pair
aws ec2 create-key-pair --key-name tipjar-key --query 'KeyMaterial' --output text > tipjar-key.pem
chmod 400 tipjar-key.pem
```

#### Step 2: Create Security Group

```bash
# Create security group
SG_ID=$(aws ec2 create-security-group --group-name tipjar-ec2-sg --description "Security group for TipJar" --query 'GroupId' --output text)

# Allow SSH
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 22 --cidr 0.0.0.0/0

# Allow HTTP
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 80 --cidr 0.0.0.0/0

# Allow application port
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 3001 --cidr 0.0.0.0/0
```

#### Step 3: Launch EC2 Instance

```bash
# Launch instance (Amazon Linux 2023)
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id ami-0c7217cdde317cfec \
  --count 1 \
  --instance-type t3.micro \
  --key-name tipjar-key \
  --security-group-ids $SG_ID \
  --user-data file://infrastructure/ec2-user-data.sh \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "Instance ID: $INSTANCE_ID"
```

#### Step 4: Get Instance Details

```bash
# Wait for instance to be running
aws ec2 wait instance-running --instance-ids $INSTANCE_ID

# Get public IP
PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Instances[0].PublicIpAddress' --output text)
echo "Public IP: $PUBLIC_IP"
```

#### Step 5: Deploy Application

```bash
# Copy application files to instance
scp -i tipjar-key.pem -r . ec2-user@$PUBLIC_IP:/home/ec2-user/tipjar-backend

# SSH into instance
ssh -i tipjar-key.pem ec2-user@$PUBLIC_IP

# On the instance:
cd /home/ec2-user/tipjar-backend
npm install

# Setup environment variables
cat > .env << EOF
DB_HOST=localhost
DB_PORT=5432
DB_NAME=tipjar_db
DB_USER=tipjar_user
DB_PASSWORD=your-password
PORT=3001
EOF

# Install PostgreSQL locally (if not using RDS)
sudo yum install -y postgresql-server
sudo postgresql-setup initdb
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Create database and user
sudo -u postgres psql << EOF
CREATE DATABASE tipjar_db;
CREATE USER tipjar_user WITH PASSWORD 'your-password';
GRANT ALL PRIVILEGES ON DATABASE tipjar_db TO tipjar_user;
\c tipjar_db
GRANT ALL ON SCHEMA public TO tipjar_user;
EOF

# Run migrations
PGPASSWORD=your-password psql -h localhost -U tipjar_user -d tipjar_db -f schema.sql
PGPASSWORD=your-password psql -h localhost -U tipjar_user -d tipjar_db -f stored_providers.sql
PGPASSWORD=your-password psql -h localhost -U tipjar_user -d tipjar_db -f stored_tips.sql
PGPASSWORD=your-password psql -h localhost -U tipjar_user -d tipjar_db -f stored_bank_payments.sql
PGPASSWORD=your-password psql -h localhost -U tipjar_user -d tipjar_db -f functions.sql

# Install PM2 for process management
npm install -g pm2

# Start application
pm2 start server.js --name tipjar-backend
pm2 save
pm2 startup
```

## Using RDS Instead of Local PostgreSQL

### Create RDS Instance

```bash
# Create RDS PostgreSQL instance
aws rds create-db-instance \
  --db-instance-identifier tipjar-db \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --engine-version 15.4 \
  --master-username tipjar_user \
  --master-user-password YourSecurePassword123! \
  --allocated-storage 20 \
  --publicly-accessible \
  --backup-retention-period 7

# Wait for RDS to be available
aws rds wait db-instance-available --db-instance-identifier tipjar-db

# Get RDS endpoint
RDS_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier tipjar-db --query 'DBInstances[0].Endpoint.Address' --output text)
echo "RDS endpoint: $RDS_ENDPOINT"
```

### Update Environment Variables

```bash
# On the EC2 instance, update .env
cat > .env << EOF
DB_HOST=$RDS_ENDPOINT
DB_PORT=5432
DB_NAME=tipjar_db
DB_USER=tipjar_user
DB_PASSWORD=YourSecurePassword123!
PORT=3001
EOF
```

### Run Migrations

```bash
# From the EC2 instance
cd /home/ec2-user/tipjar-backend
PGPASSWORD=YourSecurePassword123! psql -h $RDS_ENDPOINT -U tipjar_user -d tipjar_db -f schema.sql
PGPASSWORD=YourSecurePassword123! psql -h $RDS_ENDPOINT -U tipjar_user -d tipjar_db -f stored_providers.sql
PGPASSWORD=YourSecurePassword123! psql -h $RDS_ENDPOINT -U tipjar_user -d tipjar_db -f stored_tips.sql
PGPASSWORD=YourSecurePassword123! psql -h $RDS_ENDPOINT -U tipjar_user -d tipjar_db -f stored_bank_payments.sql
PGPASSWORD=YourSecurePassword123! psql -h $RDS_ENDPOINT -U tipjar_user -d tipjar_db -f functions.sql
```

## Using S3 for File Uploads

### Create S3 Bucket

```bash
# Create S3 bucket
aws s3 mb s3://tipjar-uploads --region us-east-1

# Enable public read access
aws s3api put-bucket-policy --bucket tipjar-uploads --policy file://infrastructure/s3-policy.json
```

### Update Application for S3

The application needs to be modified to use S3 instead of local file storage. The `infrastructure/s3-upload.js` utility is already provided.

Update `server.js` to use S3 uploads when `S3_BUCKET_NAME` is set in environment variables.

## Accessing Your Application

Once deployed, access your application at:

```
http://<PUBLIC_IP>:3001
```

## Monitoring and Logs

### View Application Logs

```bash
# SSH into instance
ssh -i tipjar-key.pem ec2-user@$PUBLIC_IP

# View PM2 logs
pm2 logs tipjar-backend

# View PM2 status
pm2 status
```

### System Logs

```bash
# View system logs
sudo journalctl -u docker -f
```

## Updating the Application

```bash
# SSH into instance
ssh -i tipjar-key.pem ec2-user@$PUBLIC_IP

# Pull latest changes (if using git)
cd /home/ec2-user/tipjar-backend
git pull

# Or copy new files from local
# On your local machine:
scp -i tipjar-key.pem -r . ec2-user@$PUBLIC_IP:/home/ec2-user/tipjar-backend

# On the instance:
cd /home/ec2-user/tipjar-backend
npm install

# Restart application
pm2 restart tipjar-backend
```

## Security Best Practices

1. **Use a strong password** for database and SSH key
2. **Restrict security group** to specific IP addresses when possible
3. **Enable SSL/TLS** using a reverse proxy (nginx) with Let's Encrypt
4. **Regular updates** - Keep the OS and packages updated
5. **Backup database** - Enable RDS automated backups
6. **Use IAM roles** instead of access keys when possible

## Cost Optimization

- Use **t3.micro** or **t2.micro** for development/testing
- Use **Reserved Instances** for production
- Enable **RDS automated backups** with appropriate retention
- Monitor costs using AWS Cost Explorer
- Stop instance when not in use for development

## Troubleshooting

### Instance not accessible

```bash
# Check security group rules
aws ec2 describe-security-groups --group-ids $SG_ID

# Check instance state
aws ec2 describe-instances --instance-ids $INSTANCE_ID
```

### Application not starting

```bash
# SSH into instance
ssh -i tipjar-key.pem ec2-user@$PUBLIC_IP

# Check PM2 logs
pm2 logs tipjar-backend

# Check if port is in use
sudo netstat -tlnp | grep 3001

# Test application manually
node server.js
```

### Database connection issues

```bash
# Test database connection
PGPASSWORD=your-password psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "SELECT 1"

# Check security group allows database traffic
```

## Cleanup

```bash
# Terminate EC2 instance
aws ec2 terminate-instances --instance-ids $INSTANCE_ID

# Delete security group
aws ec2 delete-security-group --group-id $SG_ID

# Delete key pair
aws ec2 delete-key-pair --key-name tipjar-key
rm tipjar-key.pem

# Delete RDS (if used)
aws rds delete-db-instance --db-instance-identifier tipjar-db --skip-final-snapshot

# Delete S3 bucket (if used)
aws s3 rb s3://tipjar-uploads --force
```
