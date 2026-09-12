-- Database Functions for Data Retrieval
-- These functions support the TipJar frontend data queries
-- PostgreSQL version

-- Function to generate QR code URL for a provider
CREATE OR REPLACE FUNCTION fn_generate_qr_code_url(p_provider_id INTEGER) 
RETURNS VARCHAR(255)
AS $$
DECLARE
    v_code VARCHAR(20);
    v_url VARCHAR(255);
BEGIN
    SELECT provider_code INTO v_code
    FROM providers
    WHERE provider_id = p_provider_id;
    
    v_url := 'https://tipjar.app/qr/' || v_code;
    
    RETURN v_url;
END;
$$ LANGUAGE plpgsql;

-- Function to calculate daily earnings for a provider
CREATE OR REPLACE FUNCTION fn_get_daily_earnings(p_provider_id INTEGER, p_date DATE) 
RETURNS NUMERIC(10, 2)
AS $$
DECLARE
    v_total NUMERIC(10, 2);
BEGIN
    SELECT COALESCE(SUM(amount), 0) INTO v_total
    FROM tips
    WHERE provider_id = p_provider_id
        AND payment_status = 'completed'
        AND DATE(created_at) = p_date;
    
    RETURN v_total;
END;
$$ LANGUAGE plpgsql;

-- Function to calculate daily tip count for a provider
CREATE OR REPLACE FUNCTION fn_get_daily_tip_count(p_provider_id INTEGER, p_date DATE) 
RETURNS INTEGER
AS $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM tips
    WHERE provider_id = p_provider_id
        AND payment_status = 'completed'
        AND DATE(created_at) = p_date;
    
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- Function to get average tip amount for a provider
CREATE OR REPLACE FUNCTION fn_get_average_tip(p_provider_id INTEGER) 
RETURNS NUMERIC(10, 2)
AS $$
DECLARE
    v_avg NUMERIC(10, 2);
BEGIN
    SELECT COALESCE(AVG(amount), 0) INTO v_avg
    FROM tips
    WHERE provider_id = p_provider_id
        AND payment_status = 'completed';
    
    RETURN v_avg;
END;
$$ LANGUAGE plpgsql;

-- Function to check if provider code exists
CREATE OR REPLACE FUNCTION fn_provider_code_exists(p_provider_code VARCHAR(20)) 
RETURNS BOOLEAN
AS $$
DECLARE
    v_exists INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_exists
    FROM providers
    WHERE provider_code = p_provider_code;
    
    RETURN v_exists > 0;
END;
$$ LANGUAGE plpgsql;

-- Function to get provider statistics
CREATE OR REPLACE FUNCTION fn_get_provider_stats(p_provider_id INTEGER, p_stat_type VARCHAR(20)) 
RETURNS NUMERIC(10, 2)
AS $$
DECLARE
    v_result NUMERIC(10, 2);
BEGIN
    IF p_stat_type = 'total_earned' THEN
        SELECT COALESCE(SUM(amount), 0) INTO v_result
        FROM tips
        WHERE provider_id = p_provider_id AND payment_status = 'completed';
    ELSIF p_stat_type = 'total_tips' THEN
        SELECT COUNT(*) INTO v_result
        FROM tips
        WHERE provider_id = p_provider_id AND payment_status = 'completed';
    ELSIF p_stat_type = 'today_earned' THEN
        SELECT COALESCE(SUM(amount), 0) INTO v_result
        FROM tips
        WHERE provider_id = p_provider_id 
            AND payment_status = 'completed'
            AND DATE(created_at) = CURRENT_DATE;
    ELSIF p_stat_type = 'today_tips' THEN
        SELECT COUNT(*) INTO v_result
        FROM tips
        WHERE provider_id = p_provider_id 
            AND payment_status = 'completed'
            AND DATE(created_at) = CURRENT_DATE;
    ELSE
        v_result := 0;
    END IF;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- Function to format payment receipt
CREATE OR REPLACE FUNCTION fn_format_receipt(p_tip_id INTEGER) 
RETURNS TEXT
AS $$
DECLARE
    v_receipt TEXT;
    v_provider_name VARCHAR(100);
    v_amount NUMERIC(10, 2);
    v_sender VARCHAR(100);
    v_status payment_status_enum;
    v_timestamp TIMESTAMP;
    v_ref VARCHAR(100);
BEGIN
    SELECT 
        p.display_name,
        t.amount,
        COALESCE(t.sender_name, 'Anonymous'),
        t.payment_status,
        t.created_at,
        t.transaction_reference
    INTO
        v_provider_name,
        v_amount,
        v_sender,
        v_status,
        v_timestamp,
        v_ref
    FROM tips t
    INNER JOIN providers p ON t.provider_id = p.provider_id
    WHERE t.tip_id = p_tip_id;
    
    v_receipt := '=== TIPJAR PAYMENT RECEIPT ===' || E'\n' ||
                 'Reference: ' || v_ref || E'\n' ||
                 'Date: ' || TO_CHAR(v_timestamp, 'YYYY-MM-DD HH24:MI:SS') || E'\n' ||
                 '--------------------------------' || E'\n' ||
                 'Provider: ' || v_provider_name || E'\n' ||
                 'Amount: R' || v_amount || E'\n' ||
                 'From: ' || v_sender || E'\n' ||
                 'Status: ' || UPPER(v_status::TEXT) || E'\n' ||
                 '================================';
    
    RETURN v_receipt;
END;
$$ LANGUAGE plpgsql;
