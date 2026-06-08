-- Migration: Update external_users address structure (SAFE VERSION)
-- Date: 2025-01-27
-- Description: Add structured address fields and migrate existing data

-- Connect to toptancimdb_codex database
\c toptancimdb_codex;

-- Step 1: Add new structured address columns
ALTER TABLE external_users ADD COLUMN IF NOT EXISTS address_title TEXT;
ALTER TABLE external_users ADD COLUMN IF NOT EXISTS address TEXT;
ALTER TABLE external_users ADD COLUMN IF NOT EXISTS detailed_address TEXT;
ALTER TABLE external_users ADD COLUMN IF NOT EXISTS latitude NUMERIC(10, 7);
ALTER TABLE external_users ADD COLUMN IF NOT EXISTS longitude NUMERIC(10, 7);

-- Step 2: Migrate existing 'adres' data to new 'address' column (if adres exists)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns 
               WHERE table_name = 'external_users' AND column_name = 'adres') THEN
        UPDATE external_users 
        SET address = adres 
        WHERE adres IS NOT NULL AND address IS NULL;
        
        RAISE NOTICE 'Existing adres data migrated to address column';
    END IF;
END $$;

-- Step 3: Remove old 'adres' column (only after data migration)
ALTER TABLE external_users DROP COLUMN IF EXISTS adres;

-- Success message
SELECT 'external_users tablosu yeni adres alanları ile başarıyla güncellendi.' AS status;