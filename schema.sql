-- TipJar Database Schema
-- This schema supports the TipJar frontend application
-- PostgreSQL version

-- Create custom types for enums
CREATE TYPE service_type_enum AS ENUM ('car-guard', 'waiter', 'petrol-attendant', 'porter', 'other');
CREATE TYPE payment_method_enum AS ENUM ('card', 'eft', 'mobile-money');
CREATE TYPE payment_status_enum AS ENUM (
    'pending', 'awaiting_approval', 'authorized', 'completed', 'failed', 'declined', 'refunded'
);
CREATE TYPE action_type_enum AS ENUM (
    'created', 'completed', 'failed', 'refunded', 'authorized', 'declined', 'bank_selected'
);
CREATE TYPE payer_bank_enum AS ENUM ('fnb', 'capitec', 'standard', 'absa', 'nedbank', 'discovery');

-- Providers table
CREATE TABLE providers (
    provider_id SERIAL PRIMARY KEY,
    display_name VARCHAR(100) NOT NULL,
    service_type service_type_enum NOT NULL,
    work_location VARCHAR(255) NOT NULL,
    phone_number VARCHAR(20) NOT NULL,
    bank_details TEXT,
    default_tip_amount NUMERIC(10, 2) DEFAULT 20.00,
    provider_code VARCHAR(20) UNIQUE NOT NULL,
    qr_code_url VARCHAR(255),
    photo_url VARCHAR(255),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for providers
CREATE INDEX idx_provider_code ON providers(provider_code);
CREATE INDEX idx_service_type ON providers(service_type);
CREATE INDEX idx_work_location ON providers(work_location);

-- Tips/Payments table
CREATE TABLE tips (
    tip_id SERIAL PRIMARY KEY,
    provider_id INTEGER NOT NULL,
    amount NUMERIC(10, 2) NOT NULL,
    sender_name VARCHAR(100),
    sender_phone VARCHAR(20),
    message TEXT,
    payment_method payment_method_enum NOT NULL,
    payment_status payment_status_enum DEFAULT 'pending',
    payer_bank payer_bank_enum,
    transaction_reference VARCHAR(100) UNIQUE,
    authorized_at TIMESTAMP,
    completed_at TIMESTAMP,
    declined_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_tips_provider FOREIGN KEY (provider_id) REFERENCES providers(provider_id) ON DELETE CASCADE
);

-- Create indexes for tips
CREATE INDEX idx_tips_provider_id ON tips(provider_id);
CREATE INDEX idx_payment_status ON tips(payment_status);
CREATE INDEX idx_tips_created_at ON tips(created_at);
CREATE INDEX idx_tips_payer_bank ON tips(payer_bank);
CREATE INDEX idx_tips_transaction_reference ON tips(transaction_reference);

-- Provider earnings summary table (for dashboard statistics)
CREATE TABLE provider_earnings (
    summary_id SERIAL PRIMARY KEY,
    provider_id INTEGER NOT NULL,
    total_earned NUMERIC(10, 2) DEFAULT 0.00,
    total_tips_received INTEGER DEFAULT 0,
    today_earned NUMERIC(10, 2) DEFAULT 0.00,
    today_tips_received INTEGER DEFAULT 0,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_earnings_provider FOREIGN KEY (provider_id) REFERENCES providers(provider_id) ON DELETE CASCADE,
    CONSTRAINT uk_provider_id UNIQUE (provider_id)
);

-- Payment history log (for audit trail)
CREATE TABLE payment_log (
    log_id SERIAL PRIMARY KEY,
    tip_id INTEGER NOT NULL,
    action_type action_type_enum NOT NULL,
    old_status VARCHAR(20),
    new_status VARCHAR(20),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_log_tip FOREIGN KEY (tip_id) REFERENCES tips(tip_id) ON DELETE CASCADE
);

-- Create indexes for payment_log
CREATE INDEX idx_log_tip_id ON payment_log(tip_id);
CREATE INDEX idx_action_type ON payment_log(action_type);

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for updated_at
CREATE TRIGGER update_providers_updated_at BEFORE UPDATE ON providers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_tips_updated_at BEFORE UPDATE ON tips
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE FUNCTION update_earnings_last_updated()
RETURNS TRIGGER AS $$
BEGIN
    NEW.last_updated = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_earnings_last_updated BEFORE UPDATE ON provider_earnings
    FOR EACH ROW EXECUTE FUNCTION update_earnings_last_updated();

-- Insert sample test data
INSERT INTO providers (display_name, service_type, work_location, phone_number, bank_details, default_tip_amount, provider_code) VALUES
('John M.', 'car-guard', 'Sandton City', '+27 12 345 6789', 'FNB: 1234567890', 20.00, 'JM2024'),
('Sarah K.', 'waiter', 'Ocean Basket VBA', '+27 12 345 6790', 'Standard Bank: 0987654321', 20.00, 'SK2024'),
('Thabo N.', 'petrol-attendant', 'Engen N1 City', '+27 12 345 6791', 'Capitec: 1122334455', 20.00, 'TN2024'),
('Yami', 'petrol-attendant', 'Engen', '+27 12 345 6792', 'Nedbank: 5544332211', 20.00, 'Q6C4BG'),
('Namhla M.', 'waiter', 'Soncike', '+27 12 345 6793', 'ABSA: 6677889900', 20.00, 'BYNFX9');

-- Initialize earnings for sample providers
INSERT INTO provider_earnings (provider_id, total_earned, total_tips_received, today_earned, today_tips_received)
SELECT provider_id, 0, 0, 0, 0 FROM providers;
