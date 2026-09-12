# TipJar Backend Integration

This workspace contains database integration points for the TipJar frontend application, including stored procedures, database functions, and API endpoint documentation.

**Database:** PostgreSQL

## Directory Structure

```
tipjar-backend/
├── schema.sql                    # Database schema and tables
├── stored_providers.sql          # Stored procedures for provider operations
├── stored_tips.sql              # Stored procedures for tip/payment operations
├── functions.sql                # Database functions for data retrieval
├── api_endpoints.md             # API endpoints documentation
└── README.md                    # This file
```

## Database Schema

The database consists of the following tables:

### Tables
- **providers** - Provider information and profiles
- **tips** - Tip/payment records
- **provider_earnings** - Earnings summary for dashboard statistics
- **payment_log** - Audit trail for payment actions

### Custom Types
- **service_type_enum** - ENUM for service types (car-guard, waiter, petrol-attendant, porter, other)
- **payment_method_enum** - ENUM for payment methods (card, eft, mobile-money)
- **payment_status_enum** - ENUM for payment status (pending, completed, failed, refunded)
- **action_type_enum** - ENUM for log action types (created, completed, failed, refunded)

### Key Features
- Unique provider codes for easy lookup
- Payment status tracking (pending, completed, failed, refunded)
- Earnings aggregation for dashboard statistics
- Comprehensive audit logging
- Automatic timestamp updates via triggers

## Stored Procedures (PostgreSQL Functions)

### Provider Operations (`stored_providers.sql`)
- `sp_register_provider` - Register a new provider with auto-generated code
- `sp_get_provider_by_code` - Retrieve provider by unique code
- `sp_get_provider_dashboard` - Get dashboard statistics
- `sp_update_provider` - Update provider profile
- `sp_get_all_providers` - Get all providers (admin/dev mode)

### Tip/Payment Operations (`stored_tips.sql`)
- `sp_create_tip` - Create a new tip/payment
- `sp_complete_payment` - Mark payment as completed
- `sp_fail_payment` - Mark payment as failed
- `sp_get_provider_recent_tips` - Get recent tips for a provider
- `sp_get_payment_receipt` - Get full payment receipt
- `sp_get_provider_payment_history` - Get payment history

## Database Functions (`functions.sql`)

- `fn_generate_qr_code_url` - Generate QR code URL for a provider
- `fn_get_daily_earnings` - Calculate daily earnings for a provider
- `fn_get_daily_tip_count` - Calculate daily tip count
- `fn_get_average_tip` - Get average tip amount
- `fn_provider_code_exists` - Check if provider code exists
- `fn_get_provider_stats` - Get provider statistics
- `fn_format_receipt` - Format payment receipt as text

## API Endpoints

See `api_endpoints.md` for complete API documentation including:
- Request/response formats
- Authentication requirements
- Error handling
- Integration examples

## Setup Instructions

### Prerequisites
- PostgreSQL 12 or higher
- psql command-line tool

### 1. Create Database
```bash
# Create database
createdb tipjar_db

# Or using psql
psql -U postgres -c "CREATE DATABASE tipjar_db;"
```

### 2. Create Schema and Tables
```bash
psql -U postgres -d tipjar_db -f schema.sql
```

### 3. Create Stored Procedures
```bash
psql -U postgres -d tipjar_db -f stored_providers.sql
psql -U postgres -d tipjar_db -f stored_tips.sql
```

### 4. Create Functions
```bash
psql -U postgres -d tipjar_db -f functions.sql
```

### Alternative: Single Script Execution
```bash
# Execute all scripts at once
psql -U postgres -d tipjar_db -f schema.sql \
                          -f stored_providers.sql \
                          -f stored_tips.sql \
                          -f functions.sql
```

## Sample Data

The schema includes sample test data with 5 providers:
- John M. (Car Guard - Sandton City) - Code: JM2024
- Sarah K. (Waiter - Ocean Basket VBA) - Code: SK2024
- Thabo N. (Petrol Attendant - Engen N1 City) - Code: TN2024
- Yami (Petrol Attendant - Engen) - Code: Q6C4BG
- Namhla M. (Waiter - Soncike) - Code: BYNFX9

## Frontend Integration

The frontend application at `/home/sazi/IdeaProjects/tipJar` can integrate with this backend using the following code examples:

### API Configuration

```javascript
const API_BASE_URL = 'https://api.tipjar.app/v1';
const API_KEY = 'your-api-key-here';

const apiCall = async (endpoint, options = {}) => {
  const response = await fetch(`${API_BASE_URL}${endpoint}`, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      'X-API-Key': API_KEY,
      ...options.headers
    }
  });
  return response.json();
};
```

### Provider Registration

```javascript
const registerProvider = async (providerData) => {
  const response = await apiCall('/providers/register', {
    method: 'POST',
    body: JSON.stringify({
      display_name: providerData.displayName,
      service_type: providerData.serviceType,
      work_location: providerData.workLocation,
      phone_number: providerData.phoneNumber,
      bank_details: providerData.bankDetails,
      default_tip_amount: providerData.defaultTipAmount,
      photo_url: providerData.photoUrl
    })
  });

  if (response.success) {
    console.log('Provider registered:', response.data.provider_code);
    console.log('QR Code URL:', response.data.qr_code_url);
    return response.data;
  }
  throw new Error(response.message);
};

// Usage
registerProvider({
  displayName: 'John M.',
  serviceType: 'car-guard',
  workLocation: 'Sandton City',
  phoneNumber: '+27 12 345 6789',
  bankDetails: 'FNB: 1234567890',
  defaultTipAmount: 20.00,
  photoUrl: 'https://example.com/photo.jpg'
});
```

### Get Provider by Code

```javascript
const getProviderByCode = async (code) => {
  const response = await apiCall(`/providers/${code}`);

  if (response.success) {
    return response.data;
  }
  throw new Error(response.message);
};

// Usage
getProviderByCode('JM2024').then(provider => {
  console.log('Provider found:', provider.display_name);
  console.log('Default tip:', provider.default_tip_amount);
});
```

### Get Provider Dashboard

```javascript
const getProviderDashboard = async (providerId) => {
  const response = await apiCall(`/providers/${providerId}/dashboard`);

  if (response.success) {
    return response.data;
  }
  throw new Error(response.message);
};

// Usage
getProviderDashboard(1).then(dashboard => {
  console.log('Total earned:', dashboard.total_earned);
  console.log('Today\'s tips:', dashboard.today_tips_received);
});
```

### Create Tip/Payment

```javascript
const createTip = async (tipData) => {
  const response = await apiCall('/tips', {
    method: 'POST',
    body: JSON.stringify({
      provider_code: tipData.providerCode,
      amount: tipData.amount,
      sender_name: tipData.senderName,
      sender_phone: tipData.senderPhone,
      message: tipData.message,
      payment_method: tipData.paymentMethod
    })
  });

  if (response.success) {
    console.log('Tip created:', response.data.tip_id);
    console.log('Transaction ref:', response.data.transaction_reference);
    return response.data;
  }
  throw new Error(response.message);
};

// Usage
createTip({
  providerCode: 'JM2024',
  amount: 50.00,
  senderName: 'Sarah J.',
  senderPhone: '+27 12 345 6799',
  message: 'Great service!',
  paymentMethod: 'card'
});
```

### Complete Payment

```javascript
const completePayment = async (tipId) => {
  const response = await apiCall(`/tips/${tipId}/complete`, {
    method: 'POST'
  });

  if (response.success) {
    console.log('Payment completed successfully');
    return true;
  }
  throw new Error(response.message);
};

// Usage
completePayment(123);
```

### Get Recent Tips

```javascript
const getRecentTips = async (providerId, limit = 10) => {
  const response = await apiCall(`/providers/${providerId}/tips/recent?limit=${limit}`);

  if (response.success) {
    return response.data;
  }
  throw new Error(response.message);
};

// Usage
getRecentTips(1, 10).then(tips => {
  tips.forEach(tip => {
    console.log(`${tip.sender_name} tipped R${tip.amount}: ${tip.message}`);
  });
});
```

### Get Payment Receipt

```javascript
const getPaymentReceipt = async (tipId) => {
  const response = await apiCall(`/tips/${tipId}/receipt`);

  if (response.success) {
    return response.data;
  }
  throw new Error(response.message);
};

// Usage
getPaymentReceipt(123).then(receipt => {
  console.log('Receipt for:', receipt.provider_name);
  console.log('Amount: R', receipt.amount);
  console.log('Status:', receipt.payment_status);
  console.log('Transaction:', receipt.transaction_reference);
});
```

### Update Provider Profile

```javascript
const updateProvider = async (providerId, updateData) => {
  const response = await apiCall(`/providers/${providerId}`, {
    method: 'PUT',
    body: JSON.stringify({
      display_name: updateData.displayName,
      service_type: updateData.serviceType,
      work_location: updateData.workLocation,
      phone_number: updateData.phoneNumber,
      bank_details: updateData.bankDetails,
      default_tip_amount: updateData.defaultTipAmount,
      photo_url: updateData.photoUrl
    })
  });

  if (response.success) {
    console.log('Provider updated successfully');
    return true;
  }
  throw new Error(response.message);
};

// Usage
updateProvider(1, {
  displayName: 'John M.',
  serviceType: 'car-guard',
  workLocation: 'Sandton City Mall',
  phoneNumber: '+27 12 345 6789',
  bankDetails: 'FNB: 1234567890',
  defaultTipAmount: 25.00,
  photoUrl: 'https://example.com/new-photo.jpg'
});
```

### Error Handling

```javascript
const safeApiCall = async (apiFunction, ...args) => {
  try {
    const result = await apiFunction(...args);
    return { success: true, data: result };
  } catch (error) {
    console.error('API Error:', error.message);
    return { success: false, error: error.message };
  }
};

// Usage
safeApiCall(getProviderByCode, 'INVALID_CODE')
  .then(result => {
    if (!result.success) {
      // Show error to user
      alert('Provider not found');
    }
  });
```

## Security Considerations

- All stored procedures include error handling and transaction management
- Payment status changes are logged in the `payment_log` table
- Provider codes are unique and auto-generated
- Database connections should use prepared statements to prevent SQL injection
- API endpoints should implement proper authentication and rate limiting
- PostgreSQL's row-level security can be implemented for additional access control

## Testing

To test the stored procedures:

```sql
-- Test provider registration
SELECT * FROM sp_register_provider(
    'Test User', 
    'car-guard', 
    'Test Location', 
    '+27 123 456 7890', 
    'Test Bank', 
    20.00, 
    NULL
);

-- Test tip creation
SELECT * FROM sp_create_tip(
    'JM2024', 
    50.00, 
    'Test Sender', 
    '+27 123 456 7899', 
    'Test message', 
    'card'
);

-- Test getting all providers
SELECT * FROM sp_get_all_providers();

-- Test getting recent tips
SELECT * FROM sp_get_provider_recent_tips(1, 10);
```

## PostgreSQL-Specific Notes

- Functions use `CREATE OR REPLACE` for easy updates
- Custom ENUM types are used for type safety
- Triggers automatically update `updated_at` timestamps
- Functions use `$$` dollar quoting for string literals
- Error handling uses PostgreSQL's EXCEPTION blocks
- Transaction management is handled automatically by PostgreSQL

## Support

For questions or issues with the backend integration, refer to the API documentation in `api_endpoints.md`.
