-- Migration script to create account_movements and address_info tables
-- Run this script: psql -U postgres -d toptancimdb_codex -f backend/db/migration_add_user_tables.sql

\c toptancimdb_codex;

-- Create account_movements table
CREATE TABLE IF NOT EXISTS account_movements (
    movement_id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    creation_date TIMESTAMPTZ NOT NULL,
    last_login TIMESTAMPTZ,
    last_failed_login TIMESTAMPTZ,
    last_update TIMESTAMPTZ NOT NULL,
    login_count INTEGER DEFAULT 0,
    failed_login_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create address_info table
CREATE TABLE IF NOT EXISTS address_info (
    address_id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    address TEXT,
    delivery_address TEXT,
    detailed_address TEXT,
    latitude NUMERIC(10, 7),
    longitude NUMERIC(10, 7),
    city TEXT,
    district TEXT,
    postal_code TEXT,
    is_primary BOOLEAN DEFAULT TRUE,
    address_type VARCHAR(50) DEFAULT 'business', -- business, home, delivery, etc.
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_account_movements_user_id ON account_movements(user_id);
CREATE INDEX IF NOT EXISTS idx_address_info_user_id ON address_info(user_id);
CREATE INDEX IF NOT EXISTS idx_address_info_is_primary ON address_info(user_id, is_primary) WHERE is_primary = TRUE;

-- Ensure only one primary address per user
CREATE UNIQUE INDEX IF NOT EXISTS unique_primary_address ON address_info(user_id) WHERE is_primary = TRUE;

-- Migrate existing data from JSONB columns to new tables
INSERT INTO account_movements (movement_id, user_id, creation_date, last_login, last_failed_login, last_update)
SELECT 
    'acc_mov_' || user_id,
    user_id,
    COALESCE((hesap_hareketi->>'olusturma_tarihi')::timestamptz, created_at),
    CASE WHEN hesap_hareketi->>'son_giris' IS NOT NULL AND hesap_hareketi->>'son_giris' != 'null'
         THEN (hesap_hareketi->>'son_giris')::timestamptz
         ELSE NULL END,
    CASE WHEN hesap_hareketi->>'son_hatali_giris' IS NOT NULL AND hesap_hareketi->>'son_hatali_giris' != 'null'
         THEN (hesap_hareketi->>'son_hatali_giris')::timestamptz
         ELSE NULL END,
    COALESCE((hesap_hareketi->>'son_guncelleme')::timestamptz, updated_at)
FROM users
WHERE hesap_hareketi IS NOT NULL
ON CONFLICT (movement_id) DO NOTHING;

-- Create account_movements for users who don't have hesap_hareketi data
INSERT INTO account_movements (movement_id, user_id, creation_date, last_login, last_failed_login, last_update)
SELECT 
    'acc_mov_' || user_id,
    user_id,
    created_at,
    NULL,
    NULL,
    updated_at
FROM users
WHERE hesap_hareketi IS NULL
ON CONFLICT (movement_id) DO NOTHING;

-- Migrate address information
INSERT INTO address_info (address_id, user_id, address, delivery_address, detailed_address, latitude, longitude)
SELECT 
    'addr_' || user_id,
    user_id,
    adres_bilgisi->>'adres',
    adres_bilgisi->>'teslimat_adresi',
    adres_bilgisi->>'acik_adres',
    CASE WHEN adres_bilgisi->>'enlem' IS NOT NULL AND adres_bilgisi->>'enlem' != 'null'
         THEN (adres_bilgisi->>'enlem')::numeric
         ELSE NULL END,
    CASE WHEN adres_bilgisi->>'boylam' IS NOT NULL AND adres_bilgisi->>'boylam' != 'null'
         THEN (adres_bilgisi->>'boylam')::numeric
         ELSE NULL END
FROM users
WHERE adres_bilgisi IS NOT NULL
ON CONFLICT (address_id) DO NOTHING;

-- Create empty address records for users who don't have address data
INSERT INTO address_info (address_id, user_id, address, delivery_address, detailed_address, latitude, longitude)
SELECT 
    'addr_' || user_id,
    user_id,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL
FROM users
WHERE adres_bilgisi IS NULL
ON CONFLICT (address_id) DO NOTHING;