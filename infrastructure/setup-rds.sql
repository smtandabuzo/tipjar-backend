-- AWS RDS Setup Script
-- Run this to create the database and user on RDS

-- Create database
CREATE DATABASE tipjar_db;

-- Connect to the database
\c tipjar_db

-- Create user with password
CREATE USER tipjar_user WITH PASSWORD 'your-secure-password';

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE tipjar_db TO tipjar_user;

-- Connect to database and grant schema privileges
\c tipjar_db
GRANT ALL ON SCHEMA public TO tipjar_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO tipjar_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO tipjar_user;
