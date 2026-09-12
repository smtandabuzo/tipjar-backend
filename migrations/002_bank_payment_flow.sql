-- Migration: bank payment initiation, approval, and decline flow
-- Run: psql -h localhost -p 5433 -U tipjar_user -d tipjar_db -f migrations/002_bank_payment_flow.sql

-- Extend enums (idempotent)
DO $$ BEGIN
  ALTER TYPE payment_status_enum ADD VALUE 'awaiting_approval';
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TYPE payment_status_enum ADD VALUE 'authorized';
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TYPE payment_status_enum ADD VALUE 'declined';
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TYPE action_type_enum ADD VALUE 'authorized';
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TYPE action_type_enum ADD VALUE 'declined';
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TYPE action_type_enum ADD VALUE 'bank_selected';
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE payer_bank_enum AS ENUM ('fnb', 'capitec', 'standard', 'absa', 'nedbank', 'discovery');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Tips: bank and lifecycle timestamps
ALTER TABLE tips ADD COLUMN IF NOT EXISTS payer_bank payer_bank_enum;
ALTER TABLE tips ADD COLUMN IF NOT EXISTS authorized_at TIMESTAMP;
ALTER TABLE tips ADD COLUMN IF NOT EXISTS completed_at TIMESTAMP;
ALTER TABLE tips ADD COLUMN IF NOT EXISTS declined_at TIMESTAMP;

CREATE INDEX IF NOT EXISTS idx_tips_payer_bank ON tips(payer_bank);
CREATE INDEX IF NOT EXISTS idx_tips_transaction_reference ON tips(transaction_reference);
