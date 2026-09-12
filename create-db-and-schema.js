const { Client } = require('pg');
const fs = require('fs');
const path = require('path');

const client = new Client({
  host: 'tipjar-postgres.crukm4ck4zuu.af-south-1.rds.amazonaws.com',
  user: 'postgres',
  password: 'tipjar_password',
  database: 'postgres',
  port: 5432,
  ssl: { rejectUnauthorized: false },
  connectionTimeoutMillis: 10000
});

const schemas = [
  'schema.sql',
  'stored_providers.sql',
  'stored_tips.sql',
  'stored_bank_payments.sql',
  'functions.sql'
];

async function createDbAndSchema() {
  try {
    console.log('Connecting to RDS...');
    await client.connect();
    console.log('✅ Connected to RDS');

    // Create database if it doesn't exist
    console.log('\nCreating tipjar_db database...');
    try {
      await client.query('CREATE DATABASE tipjar_db');
      console.log('✅ Database tipjar_db created');
    } catch (err) {
      if (err.message.includes('already exists')) {
        console.log('✅ Database tipjar_db already exists');
      } else {
        throw err;
      }
    }

    // Connect to tipjar_db
    await client.end();
    const tipjarClient = new Client({
      host: 'tipjar-postgres.crukm4ck4zuu.af-south-1.rds.amazonaws.com',
      user: 'postgres',
      password: 'tipjar_password',
      database: 'tipjar_db',
      port: 5432,
      ssl: { rejectUnauthorized: false },
      connectionTimeoutMillis: 10000
    });
    
    await tipjarClient.connect();
    console.log('✅ Connected to tipjar_db');

    // Load schema files
    for (const file of schemas) {
      const filePath = path.join(__dirname, file);
      if (!fs.existsSync(filePath)) {
        console.log(`⚠️  Skipping ${file} (not found)`);
        continue;
      }

      console.log(`\nLoading ${file}...`);
      const sql = fs.readFileSync(filePath, 'utf8');
      
      try {
        await tipjarClient.query(sql);
        console.log(`✅ ${file} loaded successfully`);
      } catch (err) {
        if (err.message.includes('already exists') || err.message.includes('Duplicate')) {
          console.log(`✅ ${file} (already exists)`);
        } else {
          console.error(`❌ Error loading ${file}:`, err.message);
        }
      }
    }

    console.log('\n🎉 Database setup completed successfully!');
    await tipjarClient.end();
    process.exit(0);
  } catch (err) {
    console.error('❌ Database setup error:', err.message);
    process.exit(1);
  }
}

createDbAndSchema();
