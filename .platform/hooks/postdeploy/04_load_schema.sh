#!/bin/bash
set -e

export DB_HOST=${DB_HOST}
export DB_USER=${DB_USER}
export DB_PASSWORD=${DB_PASSWORD}
export DB_PORT=${DB_PORT:-5432}

# Create database and load schema files
node << 'NODEJS'
const { Client } = require('pg');
const fs = require('fs');
const path = require('path');

const schemas = [
  '/var/app/current/schema.sql',
  '/var/app/current/stored_providers.sql',
  '/var/app/current/stored_tips.sql',
  '/var/app/current/stored_bank_payments.sql',
  '/var/app/current/functions.sql'
];

async function loadSchema() {
  let adminClient, client;
  
  try {
    // First connect to postgres to create database
    adminClient = new Client({
      host: process.env.DB_HOST,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      database: 'postgres',
      port: parseInt(process.env.DB_PORT || '5432', 10),
      ssl: { rejectUnauthorized: false },
      connectionTimeoutMillis: 5000
    });

    await adminClient.connect();
    console.log('Schema: Connected to RDS (postgres)');

    // Create database if it doesn't exist
    try {
      await adminClient.query('CREATE DATABASE tipjar_db');
      console.log('Schema: Created tipjar_db database');
    } catch (err) {
      if (err.message.includes('already exists')) {
        console.log('Schema: Database tipjar_db already exists');
      } else {
        throw err;
      }
    }

    await adminClient.end();

    // Connect to tipjar_db
    client = new Client({
      host: process.env.DB_HOST,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      database: 'tipjar_db',
      port: parseInt(process.env.DB_PORT || '5432', 10),
      ssl: { rejectUnauthorized: false },
      connectionTimeoutMillis: 5000
    });

    await client.connect();
    console.log('Schema: Connected to tipjar_db');

    for (const file of schemas) {
      if (!fs.existsSync(file)) {
        console.log(`Schema: Skipping ${path.basename(file)}`);
        continue;
      }

      const sql = fs.readFileSync(file, 'utf8');
      console.log(`Schema: Loading ${path.basename(file)}...`);
      
      try {
        await client.query(sql);
        console.log(`Schema: ✓ ${path.basename(file)}`);
      } catch (err) {
        if (err.message.includes('already exists') || err.message.includes('Duplicate')) {
          console.log(`Schema: ✓ ${path.basename(file)} (exists)`);
        } else {
          console.log(`Schema: ✗ ${path.basename(file)} - ${err.message.split('\n')[0]}`);
        }
      }
    }
    
    console.log('Schema: Load complete');
    process.exit(0);
  } catch (err) {
    console.error('Schema error:', err.message);
    process.exit(0); // Don't fail deployment
  } finally {
    if (client) await client.end().catch(() => {});
    if (adminClient) await adminClient.end().catch(() => {});
  }
}

setTimeout(() => { process.exit(0); }, 10000);
loadSchema();
NODEJS
