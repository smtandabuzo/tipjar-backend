# TipJar API Endpoints Documentation

This document describes the API endpoints that integrate with the TipJar frontend application.

## Base URL
```
https://api.tipjar.app/v1
```

## Authentication
All endpoints require API key authentication via the `X-API-Key` header.

## Provider Endpoints

### Register Provider
Create a new provider account.

**Endpoint:** `POST /providers/register`

**Request Body:**
```json
{
  "display_name": "John M.",
  "service_type": "car-guard",
  "work_location": "Sandton City",
  "phone_number": "+27 12 345 6789",
  "bank_details": "FNB: 1234567890",
  "default_tip_amount": 20.00,
  "photo_url": "https://example.com/photo.jpg"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Provider registered successfully",
  "data": {
    "provider_id": 1,
    "provider_code": "JMC202412345",
    "qr_code_url": "https://tipjar.app/qr/JMC202412345"
  }
}
```

**Stored Procedure:** `sp_register_provider`

---

### Get Provider by Code
Retrieve provider information using their unique code.

**Endpoint:** `GET /providers/{code}`

**Response:**
```json
{
  "success": true,
  "message": "Provider found",
  "data": {
    "provider_id": 1,
    "display_name": "John M.",
    "service_type": "car-guard",
    "work_location": "Sandton City",
    "default_tip_amount": 20.00,
    "qr_code_url": "https://tipjar.app/qr/JMC202412345",
    "photo_url": "https://example.com/photo.jpg"
  }
}
```

**Stored Procedure:** `sp_get_provider_by_code`

---

### Get Provider Dashboard
Retrieve dashboard statistics for a provider.

**Endpoint:** `GET /providers/{id}/dashboard`

**Response:**
```json
{
  "success": true,
  "message": "Dashboard data retrieved",
  "data": {
    "total_earned": 4520.00,
    "total_tips_received": 127,
    "today_earned": 250.00,
    "today_tips_received": 8
  }
}
```

**Stored Procedure:** `sp_get_provider_dashboard`

---

### Update Provider Profile
Update provider information.

**Endpoint:** `PUT /providers/{id}`

**Request Body:**
```json
{
  "display_name": "John M.",
  "service_type": "car-guard",
  "work_location": "Sandton City",
  "phone_number": "+27 12 345 6789",
  "bank_details": "FNB: 1234567890",
  "default_tip_amount": 20.00,
  "photo_url": "https://example.com/photo.jpg"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Provider updated successfully"
}
```

**Stored Procedure:** `sp_update_provider`

---

### Get All Providers (Admin/Dev)
Retrieve all providers (admin/dev mode only).

**Endpoint:** `GET /providers`

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "provider_id": 1,
      "display_name": "John M.",
      "service_type": "car-guard",
      "work_location": "Sandton City",
      "provider_code": "JM2024",
      "is_active": true,
      "created_at": "2024-01-15T10:30:00Z"
    }
  ]
}
```

**Stored Procedure:** `sp_get_all_providers`

---

## Tip/Payment Endpoints

### Bank payment flow (recommended)

Matches the frontend: bank selection → approval screen → approve/decline.

| Step | Method | Endpoint | Stored procedure |
|------|--------|----------|------------------|
| 1. Select bank | `POST` | `/payments/initiate` | `sp_initiate_bank_payment` |
| 2. Approval UI | `GET` | `/payments/{tipId}/request` | `sp_get_payment_request` |
| 3. Approve | `POST` | `/payments/{tipId}/approve` | `sp_approve_bank_payment` |
| 4. Decline | `POST` | `/payments/{tipId}/decline` | `sp_decline_bank_payment` |
| 5. Receipt | `GET` | `/tips/{id}/receipt` | `sp_get_payment_receipt` |

**Initiate request body:**
```json
{
  "provider_code": "SK2024",
  "amount": 20,
  "payment_method": "eft",
  "payer_bank": "capitec",
  "sender_name": "Anonymous",
  "message": "Thank you!"
}
```

Payment statuses: `pending` → `awaiting_approval` → `authorized` → `completed` (or `declined`).

Apply DB changes: `migrations/002_bank_payment_flow.sql` then `stored_bank_payments.sql`.

---

### Create Tip (legacy)
Create a pending tip without the bank approval flow.

**Endpoint:** `POST /tips`

**Request Body:**
```json
{
  "provider_code": "JM2024",
  "amount": 50.00,
  "sender_name": "Sarah J.",
  "sender_phone": "+27 12 345 6799",
  "message": "Great service!",
  "payment_method": "card"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Tip created successfully",
  "data": {
    "tip_id": 123,
    "transaction_reference": "TIP20240115123456"
  }
}
```

**Stored Procedure:** `sp_create_tip`

---

### Complete Payment
Mark a payment as completed.

**Endpoint:** `POST /tips/{id}/complete`

**Response:**
```json
{
  "success": true,
  "message": "Payment completed successfully"
}
```

**Stored Procedure:** `sp_complete_payment`

---

### Fail Payment
Mark a payment as failed.

**Endpoint:** `POST /tips/{id}/fail`

**Request Body:**
```json
{
  "notes": "Payment gateway timeout"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Payment marked as failed"
}
```

**Stored Procedure:** `sp_fail_payment`

---

### Get Recent Tips
Retrieve recent tips for a provider.

**Endpoint:** `GET /providers/{id}/tips/recent?limit=10`

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "tip_id": 123,
      "amount": 50.00,
      "sender_name": "Sarah J.",
      "message": "Great service!",
      "payment_status": "completed",
      "payment_method": "card",
      "transaction_reference": "TIP20240115123456",
      "created_at": "2024-01-15T14:30:00Z"
    }
  ]
}
```

**Stored Procedure:** `sp_get_provider_recent_tips`

---

### Get Payment Receipt
Retrieve full payment receipt.

**Endpoint:** `GET /tips/{id}/receipt`

**Response:**
```json
{
  "success": true,
  "message": "Receipt retrieved successfully",
  "data": {
    "provider_name": "John M.",
    "provider_code": "JM2024",
    "amount": 50.00,
    "payment_status": "completed",
    "sender_name": "Sarah J.",
    "message": "Great service!",
    "timestamp": "2024-01-15T14:30:00Z",
    "transaction_reference": "TIP20240115123456"
  }
}
```

**Stored Procedure:** `sp_get_payment_receipt`

---

### Get Payment History
Retrieve payment history for a provider.

**Endpoint:** `GET /providers/{id}/payments/history?start_date=2024-01-01&end_date=2024-01-31&limit=50`

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "tip_id": 123,
      "amount": 50.00,
      "sender_name": "Sarah J.",
      "message": "Great service!",
      "payment_status": "completed",
      "payment_method": "card",
      "transaction_reference": "TIP20240115123456",
      "created_at": "2024-01-15T14:30:00Z"
    }
  ]
}
```

**Stored Procedure:** `sp_get_provider_payment_history`

---

## Database Functions

The following database functions are available for data retrieval:

- `fn_generate_qr_code_url(provider_id)` - Generate QR code URL
- `fn_get_daily_earnings(provider_id, date)` - Calculate daily earnings
- `fn_get_daily_tip_count(provider_id, date)` - Calculate daily tip count
- `fn_get_average_tip(provider_id)` - Get average tip amount
- `fn_provider_code_exists(code)` - Check if provider code exists
- `fn_get_provider_stats(provider_id, stat_type)` - Get provider statistics
- `fn_format_receipt(tip_id)` - Format payment receipt

---

## Error Responses

All endpoints return error responses in the following format:

```json
{
  "success": false,
  "message": "Error description",
  "error_code": "ERROR_CODE"
}
```

### Common Error Codes
- `INVALID_REQUEST` - Invalid request parameters
- `PROVIDER_NOT_FOUND` - Provider not found
- `PAYMENT_FAILED` - Payment processing failed
- `UNAUTHORIZED` - Invalid API key
- `SERVER_ERROR` - Internal server error
