#!/bin/bash
set -e

export DB_HOST=${DB_HOST}
export DB_USER=${DB_USER}
export DB_PASSWORD=${DB_PASSWORD}
export DB_PORT=${DB_PORT:-5432}

# Create tipjar_db if it doesn't exist
node << 'NODEJS'
const { Pool } = require('pg');

const pool = new Pool({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: 'postgres',
  port: parseInt(process.env.DB_PORT || '5432', 10),
  ssl: { rejectUnauthorized: false }
});

pool.query('CREATE DATABASE IF NOT EXISTS tipjar_db', (err) => {
  if (err && !err.message.includes('already exists')) {
    console.error('Error creating database:', err.message);
  } else {
    console.log('Database tipjar_db ready');
  }
  pool.end();
  process.exit(0);
});

setTimeout(() => { process.exit(0); }, 5000);
NODEJS
