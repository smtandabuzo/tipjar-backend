-- Bank payment flow stored procedures
-- Requires migrations/002_bank_payment_flow.sql

CREATE OR REPLACE FUNCTION fn_generate_tip_reference()
RETURNS VARCHAR(100) AS $$
BEGIN
    RETURN 'TIP' || TO_CHAR(CURRENT_DATE, 'YYYYMMDD')
        || LPAD((FLOOR(RANDOM() * 1000000))::TEXT, 6, '0');
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fn_validate_payer_bank(p_bank TEXT)
RETURNS payer_bank_enum AS $$
BEGIN
    RETURN p_bank::payer_bank_enum;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Invalid payer bank: %', p_bank;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sp_initiate_bank_payment(
    p_provider_code VARCHAR(20),
    p_amount NUMERIC(10, 2),
    p_sender_name VARCHAR(100),
    p_sender_phone VARCHAR(20),
    p_message TEXT,
    p_payment_method payment_method_enum,
    p_payer_bank TEXT,
    OUT p_tip_id INTEGER,
    OUT p_transaction_reference VARCHAR(100),
    OUT p_provider_name VARCHAR(100),
    OUT p_provider_code_out VARCHAR(20),
    OUT p_pay_to VARCHAR(50),
    OUT p_amount_out NUMERIC(10, 2),
    OUT p_payer_bank_out payer_bank_enum,
    OUT p_payment_status payment_status_enum,
    OUT p_success BOOLEAN,
    OUT p_message_out VARCHAR(255)
)
RETURNS RECORD AS $$
DECLARE
    v_provider_id INTEGER;
    v_bank payer_bank_enum;
    v_ref VARCHAR(100);
BEGIN
    IF p_amount IS NULL OR p_amount <= 0 THEN
        p_success := FALSE;
        p_message_out := 'Amount must be greater than zero';
        RETURN;
    END IF;

    v_bank := fn_validate_payer_bank(LOWER(TRIM(p_payer_bank)));

    SELECT provider_id, display_name, provider_code
    INTO v_provider_id, p_provider_name, p_provider_code_out
    FROM providers
    WHERE provider_code = UPPER(TRIM(p_provider_code)) AND is_active = TRUE;

    IF v_provider_id IS NULL THEN
        p_success := FALSE;
        p_message_out := 'Provider not found or inactive';
        RETURN;
    END IF;

    v_ref := fn_generate_tip_reference();
    p_pay_to := 'tipjar';

    INSERT INTO tips (
        provider_id,
        amount,
        sender_name,
        sender_phone,
        message,
        payment_method,
        payment_status,
        transaction_reference,
        payer_bank
    ) VALUES (
        v_provider_id,
        p_amount,
        COALESCE(NULLIF(TRIM(p_sender_name), ''), 'Anonymous'),
        p_sender_phone,
        p_message,
        p_payment_method,
        'awaiting_approval',
        v_ref,
        v_bank
    ) RETURNING tip_id INTO p_tip_id;

    p_transaction_reference := v_ref;
    p_amount_out := p_amount;
    p_payer_bank_out := v_bank;
    p_payment_status := 'awaiting_approval';
    p_success := TRUE;
    p_message_out := 'Payment initiated — awaiting bank approval';

    INSERT INTO payment_log (tip_id, action_type, old_status, new_status, notes)
    VALUES (
        p_tip_id,
        'bank_selected'::action_type_enum,
        NULL,
        'awaiting_approval',
        'Bank selected: ' || v_bank::TEXT
    );

    RETURN;
EXCEPTION
    WHEN OTHERS THEN
        p_tip_id := NULL;
        p_success := FALSE;
        p_message_out := 'Error initiating payment: ' || SQLERRM;
        RETURN;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sp_get_payment_request(p_tip_id INTEGER)
RETURNS TABLE (
    tip_id INTEGER,
    transaction_reference VARCHAR(100),
    pay_to VARCHAR(50),
    provider_name VARCHAR(100),
    provider_code VARCHAR(20),
    amount NUMERIC(10, 2),
    payer_bank payer_bank_enum,
    payment_method payment_method_enum,
    payment_status payment_status_enum,
    sender_name VARCHAR(100),
    message TEXT,
    success BOOLEAN,
    message_out VARCHAR(255)
) AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM tips WHERE tips.tip_id = p_tip_id) THEN
        RETURN QUERY
        SELECT
            NULL::INTEGER, NULL::VARCHAR(100), NULL::VARCHAR(50),
            NULL::VARCHAR(100), NULL::VARCHAR(20), NULL::NUMERIC(10, 2),
            NULL::payer_bank_enum, NULL::payment_method_enum, NULL::payment_status_enum,
            NULL::VARCHAR(100), NULL::TEXT,
            FALSE,
            'Payment not found'::VARCHAR(255);
        RETURN;
    END IF;

    RETURN QUERY
    SELECT
        t.tip_id,
        t.transaction_reference,
        'tipjar'::VARCHAR(50),
        p.display_name,
        p.provider_code,
        t.amount,
        t.payer_bank,
        t.payment_method,
        t.payment_status,
        t.sender_name,
        t.message,
        TRUE,
        'Payment request retrieved'::VARCHAR(255)
    FROM tips t
    INNER JOIN providers p ON t.provider_id = p.provider_id
    WHERE t.tip_id = p_tip_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sp_approve_bank_payment(
    p_tip_id INTEGER,
    OUT p_success BOOLEAN,
    OUT p_message VARCHAR(255),
    OUT p_provider_name VARCHAR(100),
    OUT p_amount NUMERIC(10, 2),
    OUT p_transaction_reference VARCHAR(100),
    OUT p_payment_status payment_status_enum,
    OUT p_payer_bank payer_bank_enum,
    OUT p_completed_at TIMESTAMP
)
RETURNS RECORD AS $$
DECLARE
    v_provider_id INTEGER;
    v_old_status payment_status_enum;
    v_amount NUMERIC(10, 2);
BEGIN
    SELECT t.provider_id, t.amount, t.payment_status, t.payer_bank, p.display_name, t.transaction_reference
    INTO v_provider_id, v_amount, v_old_status, p_payer_bank, p_provider_name, p_transaction_reference
    FROM tips t
    INNER JOIN providers p ON t.provider_id = p.provider_id
    WHERE t.tip_id = p_tip_id;

    IF v_provider_id IS NULL THEN
        p_success := FALSE;
        p_message := 'Payment not found';
        RETURN;
    END IF;

    IF v_old_status = 'completed' THEN
        p_success := FALSE;
        p_message := 'Payment already completed';
        RETURN;
    END IF;

    IF v_old_status NOT IN ('awaiting_approval', 'pending', 'authorized') THEN
        p_success := FALSE;
        p_message := 'Payment cannot be approved from status: ' || v_old_status::TEXT;
        RETURN;
    END IF;

    UPDATE tips
    SET payment_status = 'authorized',
        authorized_at = CURRENT_TIMESTAMP
    WHERE tip_id = p_tip_id;

    INSERT INTO payment_log (tip_id, action_type, old_status, new_status, notes)
    VALUES (p_tip_id, 'authorized'::action_type_enum, v_old_status::TEXT, 'authorized', 'Bank approval received');

    UPDATE tips
    SET payment_status = 'completed',
        completed_at = CURRENT_TIMESTAMP
    WHERE tip_id = p_tip_id;

    UPDATE provider_earnings
    SET
        total_earned = total_earned + v_amount,
        total_tips_received = total_tips_received + 1,
        today_earned = today_earned + v_amount,
        today_tips_received = today_tips_received + 1
    WHERE provider_id = v_provider_id;

    INSERT INTO payment_log (tip_id, action_type, old_status, new_status, notes)
    VALUES (p_tip_id, 'completed'::action_type_enum, 'authorized', 'completed', 'Payment completed after bank approval');

    p_amount := v_amount;
    p_payment_status := 'completed';
    p_completed_at := CURRENT_TIMESTAMP;
    p_success := TRUE;
    p_message := 'Payment approved and completed successfully';

    RETURN;
EXCEPTION
    WHEN OTHERS THEN
        p_success := FALSE;
        p_message := 'Error approving payment: ' || SQLERRM;
        RETURN;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sp_decline_bank_payment(
    p_tip_id INTEGER,
    p_notes TEXT DEFAULT 'Payment declined by user',
    OUT p_success BOOLEAN,
    OUT p_message VARCHAR(255)
)
RETURNS RECORD AS $$
DECLARE
    v_old_status payment_status_enum;
BEGIN
    SELECT payment_status INTO v_old_status
    FROM tips
    WHERE tip_id = p_tip_id;

    IF v_old_status IS NULL THEN
        p_success := FALSE;
        p_message := 'Payment not found';
        RETURN;
    END IF;

    IF v_old_status IN ('completed', 'declined', 'refunded') THEN
        p_success := FALSE;
        p_message := 'Payment cannot be declined from status: ' || v_old_status::TEXT;
        RETURN;
    END IF;

    UPDATE tips
    SET payment_status = 'declined',
        declined_at = CURRENT_TIMESTAMP
    WHERE tip_id = p_tip_id;

    INSERT INTO payment_log (tip_id, action_type, old_status, new_status, notes)
    VALUES (p_tip_id, 'declined'::action_type_enum, v_old_status::TEXT, 'declined', COALESCE(p_notes, 'Payment declined'));

    p_success := TRUE;
    p_message := 'Payment declined';

    RETURN;
EXCEPTION
    WHEN OTHERS THEN
        p_success := FALSE;
        p_message := 'Error declining payment: ' || SQLERRM;
        RETURN;
END;
$$ LANGUAGE plpgsql;

-- Lifecycle timestamps on status transitions
CREATE OR REPLACE FUNCTION trg_tips_set_lifecycle_timestamps()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.payment_status = 'authorized' AND OLD.payment_status IS DISTINCT FROM NEW.payment_status THEN
        NEW.authorized_at := COALESCE(NEW.authorized_at, CURRENT_TIMESTAMP);
    END IF;
    IF NEW.payment_status = 'completed' AND OLD.payment_status IS DISTINCT FROM NEW.payment_status THEN
        NEW.completed_at := COALESCE(NEW.completed_at, CURRENT_TIMESTAMP);
    END IF;
    IF NEW.payment_status = 'declined' AND OLD.payment_status IS DISTINCT FROM NEW.payment_status THEN
        NEW.declined_at := COALESCE(NEW.declined_at, CURRENT_TIMESTAMP);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tips_lifecycle_timestamps ON tips;
CREATE TRIGGER tips_lifecycle_timestamps
    BEFORE UPDATE OF payment_status ON tips
    FOR EACH ROW
    EXECUTE FUNCTION trg_tips_set_lifecycle_timestamps();
