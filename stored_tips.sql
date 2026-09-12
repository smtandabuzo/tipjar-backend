-- Stored Procedures for Tip/Payment Operations
-- These procedures support the TipJar frontend payment processing
-- PostgreSQL version

-- Function to create a new tip/payment
CREATE OR REPLACE FUNCTION sp_create_tip(
    p_provider_code VARCHAR(20),
    p_amount NUMERIC(10, 2),
    p_sender_name VARCHAR(100),
    p_sender_phone VARCHAR(20),
    p_message TEXT,
    p_payment_method payment_method_enum,
    OUT p_tip_id INTEGER,
    OUT p_transaction_reference VARCHAR(100),
    OUT p_success BOOLEAN,
    OUT p_message_out VARCHAR(255)
)
RETURNS RECORD AS $$
DECLARE
    v_provider_id INTEGER;
    v_ref VARCHAR(100);
BEGIN
    -- Get provider ID
    SELECT provider_id INTO v_provider_id
    FROM providers
    WHERE provider_code = p_provider_code AND is_active = TRUE;
    
    IF v_provider_id IS NULL THEN
        p_tip_id := NULL;
        p_transaction_reference := NULL;
        p_success := FALSE;
        p_message_out := 'Provider not found or inactive';
        RETURN;
    END IF;
    
    -- Generate transaction reference
    v_ref := 'TIP' || TO_CHAR(CURRENT_DATE, 'YYYYMMDD') || LPAD((FLOOR(RANDOM() * 1000000))::TEXT, 6, '0');
    
    -- Insert tip
    BEGIN
        INSERT INTO tips (
            provider_id,
            amount,
            sender_name,
            sender_phone,
            message,
            payment_method,
            transaction_reference
        ) VALUES (
            v_provider_id,
            p_amount,
            p_sender_name,
            p_sender_phone,
            p_message,
            p_payment_method,
            v_ref
        ) RETURNING tip_id INTO p_tip_id;
        
        p_transaction_reference := v_ref;
        p_success := TRUE;
        p_message_out := 'Tip created successfully';
        
        -- Log the action
        INSERT INTO payment_log (tip_id, action_type, old_status, new_status, notes)
        VALUES (p_tip_id, 'created'::action_type_enum, NULL, 'pending'::payment_status_enum::TEXT, 'Tip created');
        
    EXCEPTION
        WHEN OTHERS THEN
            p_tip_id := NULL;
            p_transaction_reference := NULL;
            p_success := FALSE;
            p_message_out := 'Error creating tip: ' || SQLERRM;
    END;
    
    RETURN;
END;
$$ LANGUAGE plpgsql;

-- Function to complete a payment
CREATE OR REPLACE FUNCTION sp_complete_payment(
    p_tip_id INTEGER,
    OUT p_success BOOLEAN,
    OUT p_message VARCHAR(255)
)
RETURNS RECORD AS $$
DECLARE
    v_provider_id INTEGER;
    v_amount NUMERIC(10, 2);
    v_old_status payment_status_enum;
BEGIN
    -- Get tip details
    SELECT provider_id, amount, payment_status INTO v_provider_id, v_amount, v_old_status
    FROM tips
    WHERE tip_id = p_tip_id;
    
    IF v_provider_id IS NULL THEN
        p_success := FALSE;
        p_message := 'Tip not found';
        RETURN;
    END IF;
    
    IF v_old_status = 'completed' THEN
        p_success := FALSE;
        p_message := 'Payment already completed';
        RETURN;
    END IF;

    IF v_old_status NOT IN ('pending', 'awaiting_approval', 'authorized') THEN
        p_success := FALSE;
        p_message := 'Payment cannot be completed from status: ' || v_old_status::TEXT;
        RETURN;
    END IF;
    
    -- Update tip status
    UPDATE tips
    SET payment_status = 'completed',
        completed_at = COALESCE(completed_at, CURRENT_TIMESTAMP)
    WHERE tip_id = p_tip_id;
    
    -- Update provider earnings
    UPDATE provider_earnings
    SET 
        total_earned = total_earned + v_amount,
        total_tips_received = total_tips_received + 1,
        today_earned = today_earned + v_amount,
        today_tips_received = today_tips_received + 1
    WHERE provider_id = v_provider_id;
    
    -- Log the action
    INSERT INTO payment_log (tip_id, action_type, old_status, new_status, notes)
    VALUES (p_tip_id, 'completed'::action_type_enum, v_old_status::TEXT, 'completed'::payment_status_enum::TEXT, 'Payment completed successfully');
    
    p_success := TRUE;
    p_message := 'Payment completed successfully';
    
    RETURN;
    
EXCEPTION
    WHEN OTHERS THEN
        p_success := FALSE;
        p_message := 'Error completing payment: ' || SQLERRM;
        RETURN;
END;
$$ LANGUAGE plpgsql;

-- Function to fail a payment
CREATE OR REPLACE FUNCTION sp_fail_payment(
    p_tip_id INTEGER,
    p_notes TEXT,
    OUT p_success BOOLEAN,
    OUT p_message VARCHAR(255)
)
RETURNS RECORD AS $$
DECLARE
    v_old_status payment_status_enum;
BEGIN
    -- Get current status
    SELECT payment_status INTO v_old_status
    FROM tips
    WHERE tip_id = p_tip_id;
    
    IF v_old_status IS NULL THEN
        p_success := FALSE;
        p_message := 'Tip not found';
        RETURN;
    END IF;
    
    -- Update tip status
    UPDATE tips
    SET payment_status = 'failed'
    WHERE tip_id = p_tip_id;
    
    -- Log the action
    INSERT INTO payment_log (tip_id, action_type, old_status, new_status, notes)
    VALUES (p_tip_id, 'failed'::action_type_enum, v_old_status::TEXT, 'failed'::payment_status_enum::TEXT, p_notes);
    
    p_success := TRUE;
    p_message := 'Payment marked as failed';
    
    RETURN;
    
EXCEPTION
    WHEN OTHERS THEN
        p_success := FALSE;
        p_message := 'Error failing payment: ' || SQLERRM;
        RETURN;
END;
$$ LANGUAGE plpgsql;

-- Function to get recent tips for a provider
CREATE OR REPLACE FUNCTION sp_get_provider_recent_tips(
    p_provider_id INTEGER,
    p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
    tip_id INTEGER,
    amount NUMERIC(10, 2),
    sender_name VARCHAR(100),
    message TEXT,
    payment_status payment_status_enum,
    payment_method payment_method_enum,
    transaction_reference VARCHAR(100),
    created_at TIMESTAMP,
    provider_name VARCHAR(100)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.tip_id,
        t.amount,
        t.sender_name,
        t.message,
        t.payment_status,
        t.payment_method,
        t.transaction_reference,
        t.created_at,
        p.display_name
    FROM tips t
    INNER JOIN providers p ON t.provider_id = p.provider_id
    WHERE t.provider_id = p_provider_id
    ORDER BY t.created_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- Function to get payment receipt
CREATE OR REPLACE FUNCTION sp_get_payment_receipt(
    p_tip_id INTEGER,
    OUT p_provider_name VARCHAR(100),
    OUT p_provider_code VARCHAR(20),
    OUT p_amount NUMERIC(10, 2),
    OUT p_payment_status payment_status_enum,
    OUT p_sender_name VARCHAR(100),
    OUT p_message TEXT,
    OUT p_timestamp TIMESTAMP,
    OUT p_transaction_reference VARCHAR(100),
    OUT p_success BOOLEAN,
    OUT p_message_out VARCHAR(255)
)
RETURNS RECORD AS $$
BEGIN
    SELECT 
        p.display_name,
        p.provider_code,
        t.amount,
        t.payment_status,
        t.sender_name,
        t.message,
        t.created_at,
        t.transaction_reference
    INTO
        p_provider_name,
        p_provider_code,
        p_amount,
        p_payment_status,
        p_sender_name,
        p_message,
        p_timestamp,
        p_transaction_reference
    FROM tips t
    INNER JOIN providers p ON t.provider_id = p.provider_id
    WHERE t.tip_id = p_tip_id;
    
    IF p_provider_name IS NOT NULL THEN
        p_success := TRUE;
        p_message_out := 'Receipt retrieved successfully';
    ELSE
        p_success := FALSE;
        p_message_out := 'Payment not found';
    END IF;
    
    RETURN;
END;
$$ LANGUAGE plpgsql;

-- Function to get payment history for a provider
CREATE OR REPLACE FUNCTION sp_get_provider_payment_history(
    p_provider_id INTEGER,
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL,
    p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
    tip_id INTEGER,
    amount NUMERIC(10, 2),
    sender_name VARCHAR(100),
    message TEXT,
    payment_status payment_status_enum,
    payment_method payment_method_enum,
    transaction_reference VARCHAR(100),
    created_at TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        tip_id,
        amount,
        sender_name,
        message,
        payment_status,
        payment_method,
        transaction_reference,
        created_at
    FROM tips
    WHERE provider_id = p_provider_id
        AND (p_start_date IS NULL OR DATE(created_at) >= p_start_date)
        AND (p_end_date IS NULL OR DATE(created_at) <= p_end_date)
    ORDER BY created_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;
