const express = require('express');
const fs = require('fs');
const path = require('path');
const { Pool } = require('pg');
const cors = require('cors');
const multer = require('multer');
require('dotenv').config();

const app = express();
const port = process.env.PORT || 8080;
const uploadsDir = path.join(__dirname, 'uploads');

// 1. Initialize the PostgreSQL Connection Pool
const pool = new Pool({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME || 'postgres',
  port: parseInt(process.env.DB_PORT || '5432', 10),
  ssl: {
    rejectUnauthorized: false
  },
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

// 2. Test the connection pool availability on boot
pool.query('SELECT NOW() AS current_time', (err, res) => {
  if (err) {
    console.error('❌ Database connection verification failed:', err.stack);
  } else {
    console.log('✅ Database connected successfully at:', res.rows[0].current_time);
  }
});

if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir, { recursive: true });
}

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => {
    cb(null, uploadsDir);
  },
  filename: (_req, file, cb) => {
    const extension = path.extname(file.originalname || '').toLowerCase() || '.jpg';
    const safeExtension = ['.jpg', '.jpeg', '.png', '.webp'].includes(extension) ? extension : '.jpg';
    cb(null, `${Date.now()}-${Math.round(Math.random() * 1e9)}${safeExtension}`);
  }
});

const upload = multer({
  storage,
  limits: {
    fileSize: 5 * 1024 * 1024
  },
  fileFilter: (_req, file, cb) => {
    if (['image/jpeg', 'image/png', 'image/webp'].includes(file.mimetype)) {
      cb(null, true);
      return;
    }
    cb(new Error('Only JPG, PNG, and WebP images are allowed'));
  }
});

app.use(cors({
  origin: [
    'https://master.d2n7tr7le31njn.amplifyapp.com',
    'https://d2n7tr7le31njn.amplifyapp.com',
    'https://d1fb3pxq9zz09f.cloudfront.net'
  ],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With']
}))

app.options('*', cors({
  origin: [
    'https://master.d2n7tr7le31njn.amplifyapp.com',
    'https://d2n7tr7le31njn.amplifyapp.com',
    'https://d1fb3pxq9zz09f.cloudfront.net'
  ],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With']
}))

// Middleware
app.use(express.json());
app.use('/uploads', express.static(uploadsDir));

// Test endpoint - no DB required
app.get('/healthcheck', (req, res) => {
  res.json({ status: 'ok', message: 'Backend is running' });
});

// Test database connection (non-blocking)
pool.query('SELECT NOW()', (err, res) => {
  if (err) {
    console.error('Database connection error:', err);
  } else {
    console.log('Database connected successfully at:', res.rows[0].now);
  }
});

// Provider registration endpoint
app.post('/api/providers/register', upload.single('photo'), async (req, res) => {
  try {
    const {
      display_name,
      service_type,
      work_location,
      phone_number,
      bank_details,
      default_tip_amount,
      photo_url
    } = req.body;
    const requestBaseUrl = `${req.protocol}://${req.get('host')}`;
    const resolvedPhotoUrl = req.file
        ? `${requestBaseUrl}/uploads/${req.file.filename}`
        : (photo_url || null);

    // Call the stored procedure
    const result = await pool.query(
        'SELECT * FROM sp_register_provider($1, $2, $3, $4, $5, $6, $7)',
        [display_name, service_type, work_location, phone_number, bank_details, default_tip_amount, resolvedPhotoUrl]
    );

    const provider = result.rows[0];

    if (provider.p_success) {
      res.json({
        success: true,
        data: {
          provider_id: provider.p_provider_id,
          provider_code: provider.p_provider_code,
          display_name: display_name,
          qr_code_url: `https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${provider.p_provider_code}`
        }
      });
    } else {
      res.status(400).json({
        success: false,
        message: provider.p_message
      });
    }
  } catch (error) {
    console.error('Registration error:', error);
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

app.use((error, _req, res, next) => {
  if (error instanceof multer.MulterError) {
    return res.status(400).json({
      success: false,
      message: error.message
    });
  }

  if (error && error.message === 'Only JPG, PNG, and WebP images are allowed') {
    return res.status(400).json({
      success: false,
      message: error.message
    });
  }

  return next(error);
});

// Get provider by code
app.get('/api/providers/:code', async (req, res) => {
  try {
    const code = String(req.params.code || '').trim().toUpperCase();
    const result = await pool.query('SELECT * FROM sp_get_provider_by_code($1)', [code]);
    const row = result.rows[0];

    if (!row || row.p_success === false || row.p_provider_id == null) {
      return res.status(404).json({
        success: false,
        message: row?.p_message || 'Provider not found'
      });
    }

    res.json({
      success: true,
      data: {
        provider_id: row.p_provider_id,
        display_name: row.p_display_name,
        service_type: row.p_service_type,
        work_location: row.p_work_location,
        default_tip_amount: row.p_default_tip_amount,
        qr_code_url: row.p_qr_code_url,
        photo_url: row.p_photo_url
      }
    });
  } catch (error) {
    console.error('Error fetching provider:', error);
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

// Get provider dashboard
app.get('/api/providers/:id/dashboard', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await pool.query('SELECT * FROM sp_get_provider_dashboard($1)', [id]);

    res.json({
      success: true,
      data: result.rows[0]
    });
  } catch (error) {
    console.error('Error fetching dashboard:', error);
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

const mapPaymentRequest = (row) => ({
  tip_id: row.tip_id,
  transaction_reference: row.transaction_reference,
  pay_to: row.pay_to,
  provider_name: row.provider_name,
  provider_code: row.provider_code,
  amount: row.amount,
  payer_bank: row.payer_bank,
  payment_method: row.payment_method,
  payment_status: row.payment_status,
  sender_name: row.sender_name,
  message: row.message
});

const mapReceipt = (row) => ({
  tip_id: row.p_tip_id ?? row.tip_id,
  provider_name: row.p_provider_name ?? row.provider_name,
  provider_code: row.p_provider_code ?? row.provider_code,
  amount: row.p_amount ?? row.amount,
  payment_status: row.p_payment_status ?? row.payment_status,
  sender_name: row.p_sender_name ?? row.sender_name,
  message: row.p_message ?? row.message,
  transaction_reference: row.p_transaction_reference ?? row.transaction_reference,
  payer_bank: row.p_payer_bank ?? row.payer_bank,
  completed_at: row.p_timestamp ?? row.completed_at ?? row.timestamp,
  payment_method: row.p_payment_method ?? row.payment_method
});

// Initiate bank payment (bank selected — creates tip awaiting approval)
app.post('/api/payments/initiate', async (req, res) => {
  try {
    const {
      provider_code,
      amount,
      sender_name,
      sender_phone,
      message,
      payment_method,
      payer_bank
    } = req.body;

    if (!provider_code || !amount || !payment_method || !payer_bank) {
      return res.status(400).json({
        success: false,
        message: 'provider_code, amount, payment_method, and payer_bank are required'
      });
    }

    const result = await pool.query(
        'SELECT * FROM sp_initiate_bank_payment($1, $2, $3, $4, $5, $6, $7)',
        [
          String(provider_code).trim().toUpperCase(),
          amount,
          sender_name || null,
          sender_phone || null,
          message || null,
          payment_method,
          String(payer_bank).trim().toLowerCase()
        ]
    );

    const row = result.rows[0];

    if (!row || row.p_success === false || row.p_tip_id == null) {
      return res.status(400).json({
        success: false,
        message: row?.p_message_out || 'Failed to initiate payment'
      });
    }

    res.status(201).json({
      success: true,
      message: row.p_message_out,
      data: {
        tip_id: row.p_tip_id,
        transaction_reference: row.p_transaction_reference,
        payment_status: row.p_payment_status,
        payment_request: {
          tip_id: row.p_tip_id,
          transaction_reference: row.p_transaction_reference,
          pay_to: row.p_pay_to,
          provider_name: row.p_provider_name,
          provider_code: row.p_provider_code_out,
          amount: row.p_amount_out,
          payer_bank: row.p_payer_bank_out,
          payment_status: row.p_payment_status
        }
      }
    });
  } catch (error) {
    console.error('Error initiating payment:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

// Get payment request for bank approval screen
app.get('/api/payments/:tipId/request', async (req, res) => {
  try {
    const tipId = parseInt(req.params.tipId, 10);
    if (Number.isNaN(tipId)) {
      return res.status(400).json({ success: false, message: 'Invalid tip id' });
    }

    const result = await pool.query('SELECT * FROM sp_get_payment_request($1)', [tipId]);
    const row = result.rows[0];

    if (!row || row.success === false) {
      return res.status(404).json({
        success: false,
        message: row?.message_out || 'Payment not found'
      });
    }

    res.json({
      success: true,
      data: mapPaymentRequest(row)
    });
  } catch (error) {
    console.error('Error fetching payment request:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

// Approve bank payment (simulated bank approval)
app.post('/api/payments/:tipId/approve', async (req, res) => {
  try {
    const tipId = parseInt(req.params.tipId, 10);
    if (Number.isNaN(tipId)) {
      return res.status(400).json({ success: false, message: 'Invalid tip id' });
    }

    const result = await pool.query('SELECT * FROM sp_approve_bank_payment($1)', [tipId]);
    const row = result.rows[0];

    if (!row || row.p_success === false) {
      return res.status(400).json({
        success: false,
        message: row?.p_message || 'Failed to approve payment'
      });
    }

    res.json({
      success: true,
      message: row.p_message,
      data: {
        tip_id: tipId,
        provider_name: row.p_provider_name,
        amount: row.p_amount,
        transaction_reference: row.p_transaction_reference,
        payment_status: row.p_payment_status,
        payer_bank: row.p_payer_bank,
        completed_at: row.p_completed_at
      }
    });
  } catch (error) {
    console.error('Error approving payment:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

// Decline bank payment
app.post('/api/payments/:tipId/decline', async (req, res) => {
  try {
    const tipId = parseInt(req.params.tipId, 10);
    if (Number.isNaN(tipId)) {
      return res.status(400).json({ success: false, message: 'Invalid tip id' });
    }

    const { notes } = req.body || {};
    const result = await pool.query('SELECT * FROM sp_decline_bank_payment($1, $2)', [tipId, notes || null]);
    const row = result.rows[0];

    if (!row || row.p_success === false) {
      return res.status(400).json({
        success: false,
        message: row?.p_message || 'Failed to decline payment'
      });
    }

    res.json({ success: true, message: row.p_message });
  } catch (error) {
    console.error('Error declining payment:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

// Payment receipt
app.get('/api/tips/:id/receipt', async (req, res) => {
  try {
    const tipId = parseInt(req.params.id, 10);
    if (Number.isNaN(tipId)) {
      return res.status(400).json({ success: false, message: 'Invalid tip id' });
    }

    const result = await pool.query('SELECT * FROM sp_get_payment_receipt($1)', [tipId]);
    const row = result.rows[0];

    if (!row || row.p_success === false) {
      return res.status(404).json({
        success: false,
        message: row?.p_message_out || 'Receipt not found'
      });
    }

    const receiptResult = await pool.query(
        `SELECT t.payer_bank, t.payment_method, t.completed_at
         FROM tips t WHERE t.tip_id = $1`,
        [tipId]
    );
    const extra = receiptResult.rows[0] || {};

    res.json({
      success: true,
      data: {
        ...mapReceipt(row),
        payer_bank: extra.payer_bank,
        payment_method: extra.payment_method,
        completed_at: extra.completed_at || row.p_timestamp
      }
    });
  } catch (error) {
    console.error('Error fetching receipt:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

// Create tip (legacy — pending, no bank flow)
app.post('/api/tips', async (req, res) => {
  try {
    const {
      provider_code,
      amount,
      sender_name,
      sender_phone,
      message,
      payment_method
    } = req.body;

    if (!provider_code || !amount || !payment_method) {
      return res.status(400).json({
        success: false,
        message: 'provider_code, amount, and payment_method are required'
      });
    }

    const result = await pool.query(
        'SELECT * FROM sp_create_tip($1, $2, $3, $4, $5, $6)',
        [
          String(provider_code).trim().toUpperCase(),
          amount,
          sender_name || null,
          sender_phone || null,
          message || null,
          payment_method
        ]
    );

    const row = result.rows[0];

    if (!row || row.p_success === false || row.p_tip_id == null) {
      return res.status(400).json({
        success: false,
        message: row?.p_message_out || 'Failed to create tip'
      });
    }

    res.status(201).json({
      success: true,
      message: row.p_message_out,
      data: {
        tip_id: row.p_tip_id,
        transaction_reference: row.p_transaction_reference
      }
    });
  } catch (error) {
    console.error('Error creating tip:', error);
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

// Complete tip payment
app.post('/api/tips/:id/complete', async (req, res) => {
  try {
    const tipId = parseInt(req.params.id, 10);

    if (Number.isNaN(tipId)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid tip id'
      });
    }

    const result = await pool.query('SELECT * FROM sp_complete_payment($1)', [tipId]);
    const row = result.rows[0];

    if (!row || row.p_success === false) {
      return res.status(400).json({
        success: false,
        message: row?.p_message || 'Failed to complete payment'
      });
    }

    res.json({
      success: true,
      message: row.p_message
    });
  } catch (error) {
    console.error('Error completing payment:', error);
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

// Get all providers (admin/dev)
app.get('/api/providers', async (_req, res) => {
  try {
    const result = await pool.query('SELECT * FROM sp_get_all_providers()');
    res.json({
      success: true,
      data: result.rows
    });
  } catch (error) {
    console.error('Error fetching providers:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

// Update provider profile
app.put('/api/providers/:id', upload.single('photo'), async (req, res) => {
  try {
    const providerId = parseInt(req.params.id, 10);
    if (Number.isNaN(providerId)) {
      return res.status(400).json({ success: false, message: 'Invalid provider id' });
    }

    const {
      display_name,
      service_type,
      work_location,
      phone_number,
      bank_details,
      default_tip_amount,
      photo_url
    } = req.body;

    const requestBaseUrl = `${req.protocol}://${req.get('host')}`;
    const resolvedPhotoUrl = req.file
        ? `${requestBaseUrl}/uploads/${req.file.filename}`
        : (photo_url || null);

    const result = await pool.query(
        'SELECT * FROM sp_update_provider($1, $2, $3, $4, $5, $6, $7, $8)',
        [providerId, display_name, service_type, work_location, phone_number, bank_details, default_tip_amount, resolvedPhotoUrl]
    );

    const row = result.rows[0];

    if (!row || row.p_success === false) {
      return res.status(400).json({
        success: false,
        message: row?.p_message || 'Failed to update provider'
      });
    }

    res.json({ success: true, message: row.p_message || 'Provider updated successfully' });
  } catch (error) {
    console.error('Error updating provider:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

// Fail a payment
app.post('/api/tips/:id/fail', async (req, res) => {
  try {
    const tipId = parseInt(req.params.id, 10);
    if (Number.isNaN(tipId)) {
      return res.status(400).json({ success: false, message: 'Invalid tip id' });
    }

    const { notes } = req.body || {};
    const result = await pool.query('SELECT * FROM sp_fail_payment($1, $2)', [tipId, notes || null]);
    const row = result.rows[0];

    if (!row || row.p_success === false) {
      return res.status(400).json({
        success: false,
        message: row?.p_message || 'Failed to mark payment as failed'
      });
    }

    res.json({ success: true, message: row.p_message });
  } catch (error) {
    console.error('Error failing payment:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

// Get recent tips for a provider
app.get('/api/providers/:id/tips/recent', async (req, res) => {
  try {
    const providerId = parseInt(req.params.id, 10);
    if (Number.isNaN(providerId)) {
      return res.status(400).json({ success: false, message: 'Invalid provider id' });
    }

    const limit = Math.min(parseInt(req.query.limit, 10) || 10, 100);
    const result = await pool.query('SELECT * FROM sp_get_provider_recent_tips($1, $2)', [providerId, limit]);

    res.json({ success: true, data: result.rows });
  } catch (error) {
    console.error('Error fetching recent tips:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

// Get payment history for a provider
app.get('/api/providers/:id/payments/history', async (req, res) => {
  try {
    const providerId = parseInt(req.params.id, 10);
    if (Number.isNaN(providerId)) {
      return res.status(400).json({ success: false, message: 'Invalid provider id' });
    }

    const { start_date, end_date } = req.query;
    const limit = Math.min(parseInt(req.query.limit, 10) || 50, 200);
    const result = await pool.query(
        'SELECT * FROM sp_get_provider_payment_history($1, $2, $3, $4)',
        [providerId, start_date || null, end_date || null, limit]
    );

    res.json({ success: true, data: result.rows });
  } catch (error) {
    console.error('Error fetching payment history:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

// Start server
app.listen(port, () => {
  console.log(`Server running on port ${port}`);
});
