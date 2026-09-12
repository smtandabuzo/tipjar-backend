#!/bin/bash

# EC2 User Data Script - Automated TipJar Backend Setup (Ubuntu)
# This script runs when the EC2 instance first launches

set -e

# Update system
apt update -y
apt upgrade -y

# Install Node.js 18
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt install -y nodejs git

# Install PostgreSQL
apt install -y postgresql postgresql-contrib

# PostgreSQL is automatically initialized and started on Ubuntu
systemctl start postgresql
systemctl enable postgresql

# Create database and user
sudo -u postgres psql << EOF
CREATE DATABASE tipjar_db;
CREATE USER tipjar_user WITH PASSWORD 'tipjar_password';
GRANT ALL PRIVILEGES ON DATABASE tipjar_db TO tipjar_user;
\c tipjar_db
GRANT ALL ON SCHEMA public TO tipjar_user;
EOF

# Create app directory
mkdir -p /home/ubuntu/tipjar-backend
cd /home/ubuntu/tipjar-backend

# Create a simple placeholder for the application files
# In production, you would copy files here via S3 or git

# Install PM2 for process management
npm install -g pm2

# Create a simple server placeholder
cat > server.js << 'EOF'
const express = require('express');
const app = express();
const port = process.env.PORT || 3001;

app.get('/', (req, res) => {
  res.json({ message: 'TipJar Backend is running!', status: 'ready' });
});

app.listen(port, () => {
  console.log(`Server running on port ${port}`);
});
EOF

# Create package.json
cat > package.json << 'EOF'
{
  "name": "tipjar-backend",
  "version": "1.0.0",
  "description": "TipJar Backend API",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.2"
  }
}
EOF

# Install dependencies
npm install

# Setup environment variables
cat > .env << EOF
DB_HOST=localhost
DB_PORT=5432
DB_NAME=tipjar_db
DB_USER=tipjar_user
DB_PASSWORD=tipjar_password
PORT=3001
EOF

# Create uploads directory
mkdir -p uploads

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
