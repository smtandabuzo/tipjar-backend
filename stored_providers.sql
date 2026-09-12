-- Stored Procedures for Provider Operations
-- These procedures support the TipJar frontend provider management
-- PostgreSQL version

-- Function to register a new provider
CREATE OR REPLACE FUNCTION sp_register_provider(
    p_display_name VARCHAR(100),
    p_service_type service_type_enum,
    p_work_location VARCHAR(255),
    p_phone_number VARCHAR(20),
    p_bank_details TEXT,
    p_default_tip_amount NUMERIC(10, 2),
    p_photo_url VARCHAR(255),
    OUT p_provider_id INTEGER,
    OUT p_provider_code VARCHAR(20),
    OUT p_success BOOLEAN,
    OUT p_message VARCHAR(255)
)
RETURNS RECORD AS $$
DECLARE
    v_code_exists INTEGER;
    v_generated_code VARCHAR(20);
    v_attempts INTEGER DEFAULT 0;
BEGIN
    -- Generate unique provider code
    LOOP
        v_generated_code := UPPER(SUBSTRING(p_display_name, 1, 2)) ||
                            UPPER(SUBSTRING(p_service_type::TEXT, 1, 1)) ||
                            (FLOOR(RANDOM() * 9000) + 1000)::TEXT ||
                            EXTRACT(YEAR FROM CURRENT_DATE)::TEXT;
        
        SELECT COUNT(*) INTO v_code_exists 
        FROM providers 
        WHERE provider_code = v_generated_code;
        
        EXIT WHEN v_code_exists = 0 OR v_attempts > 10;
        v_attempts := v_attempts + 1;
    END LOOP;
    
    -- Insert provider
    BEGIN
        INSERT INTO providers (
            display_name, 
            service_type, 
            work_location, 
            phone_number, 
            bank_details, 
            default_tip_amount,
            provider_code,
            photo_url
        ) VALUES (
            p_display_name, 
            p_service_type, 
            p_work_location, 
            p_phone_number, 
            p_bank_details, 
            p_default_tip_amount,
            v_generated_code,
            p_photo_url
        ) RETURNING provider_id INTO p_provider_id;
        
        p_provider_code := v_generated_code;
        p_success := TRUE;
        p_message := 'Provider registered successfully';
        
        -- Initialize earnings
        INSERT INTO provider_earnings (provider_id, total_earned, total_tips_received, today_earned, today_tips_received)
        VALUES (p_provider_id, 0, 0, 0, 0);
        
    EXCEPTION
        WHEN OTHERS THEN
            p_provider_id := NULL;
            p_provider_code := NULL;
            p_success := FALSE;
            p_message := 'Error registering provider: ' || SQLERRM;
    END;
    
    RETURN;
END;
$$ LANGUAGE plpgsql;

-- Function to get provider by code
CREATE OR REPLACE FUNCTION sp_get_provider_by_code(
    p_provider_code VARCHAR(20),
    OUT p_provider_id INTEGER,
    OUT p_display_name VARCHAR(100),
    OUT p_service_type service_type_enum,
    OUT p_work_location VARCHAR(255),
    OUT p_default_tip_amount NUMERIC(10, 2),
    OUT p_qr_code_url VARCHAR(255),
    OUT p_photo_url VARCHAR(255),
    OUT p_success BOOLEAN,
    OUT p_message VARCHAR(255)
)
RETURNS RECORD AS $$
BEGIN
    SELECT 
        provider_id,
        display_name,
        service_type,
        work_location,
        default_tip_amount,
        qr_code_url,
        photo_url
    INTO 
        p_provider_id,
        p_display_name,
        p_service_type,
        p_work_location,
        p_default_tip_amount,
        p_qr_code_url,
        p_photo_url
    FROM providers
    WHERE provider_code = p_provider_code AND is_active = TRUE;
    
    IF p_provider_id IS NOT NULL THEN
        p_success := TRUE;
        p_message := 'Provider found';
    ELSE
        p_success := FALSE;
        p_message := 'Provider not found or inactive';
    END IF;
    
    RETURN;
END;
$$ LANGUAGE plpgsql;

-- Function to get provider dashboard data
CREATE OR REPLACE FUNCTION sp_get_provider_dashboard(
    p_provider_id INTEGER,
    OUT p_total_earned NUMERIC(10, 2),
    OUT p_total_tips_received INTEGER,
    OUT p_today_earned NUMERIC(10, 2),
    OUT p_today_tips_received INTEGER,
    OUT p_success BOOLEAN,
    OUT p_message VARCHAR(255)
)
RETURNS RECORD AS $$
BEGIN
    SELECT 
        total_earned,
        total_tips_received,
        today_earned,
        today_tips_received
    INTO
        p_total_earned,
        p_total_tips_received,
        p_today_earned,
        p_today_tips_received
    FROM provider_earnings
    WHERE provider_id = p_provider_id;
    
    IF p_total_earned IS NOT NULL THEN
        p_success := TRUE;
        p_message := 'Dashboard data retrieved';
    ELSE
        p_success := FALSE;
        p_message := 'Provider not found';
    END IF;
    
    RETURN;
END;
$$ LANGUAGE plpgsql;

-- Function to update provider profile
CREATE OR REPLACE FUNCTION sp_update_provider(
    p_provider_id INTEGER,
    p_display_name VARCHAR(100),
    p_service_type service_type_enum,
    p_work_location VARCHAR(255),
    p_phone_number VARCHAR(20),
    p_bank_details TEXT,
    p_default_tip_amount NUMERIC(10, 2),
    p_photo_url VARCHAR(255),
    OUT p_success BOOLEAN,
    OUT p_message VARCHAR(255)
)
RETURNS RECORD AS $$
BEGIN
    UPDATE providers
    SET 
        display_name = COALESCE(p_display_name, display_name),
        service_type = COALESCE(p_service_type, service_type),
        work_location = COALESCE(p_work_location, work_location),
        phone_number = COALESCE(p_phone_number, phone_number),
        bank_details = COALESCE(p_bank_details, bank_details),
        default_tip_amount = COALESCE(p_default_tip_amount, default_tip_amount),
        photo_url = COALESCE(p_photo_url, photo_url)
    WHERE provider_id = p_provider_id;
    
    IF FOUND THEN
        p_success := TRUE;
        p_message := 'Provider updated successfully';
    ELSE
        p_success := FALSE;
        p_message := 'Provider not found or no changes made';
    END IF;
    
    RETURN;
    
EXCEPTION
    WHEN OTHERS THEN
        p_success := FALSE;
        p_message := 'Error updating provider: ' || SQLERRM;
        RETURN;
END;
$$ LANGUAGE plpgsql;

-- Function to get all providers (for admin/dev mode)
CREATE OR REPLACE FUNCTION sp_get_all_providers()
RETURNS TABLE (
    provider_id INTEGER,
    display_name VARCHAR(100),
    service_type service_type_enum,
    work_location VARCHAR(255),
    provider_code VARCHAR(20),
    is_active BOOLEAN,
    created_at TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        provider_id,
        display_name,
        service_type,
        work_location,
        provider_code,
        is_active,
        created_at
    FROM providers
    ORDER BY created_at DESC;
END;
$$ LANGUAGE plpgsql;
