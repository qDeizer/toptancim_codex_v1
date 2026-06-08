-- Migration script to simplify address_info table structure
-- Run this script: psql -U postgres -d toptancimdb_codex -f backend/db/migration_simplify_address_info.sql

\c toptancimdb_codex;

-- Step 1: Add new simplified columns to address_info table
ALTER TABLE address_info ADD COLUMN IF NOT EXISTS address_title TEXT;

-- Step 2: Remove unnecessary columns
ALTER TABLE address_info DROP COLUMN IF EXISTS address_type;
ALTER TABLE address_info DROP COLUMN IF EXISTS is_primary;
ALTER TABLE address_info DROP COLUMN IF EXISTS created_at;
ALTER TABLE address_info DROP COLUMN IF EXISTS updated_at;

-- Step 3: Rename delivery_address to address for consistency
ALTER TABLE address_info RENAME COLUMN delivery_address TO address;

-- Step 4: Update existing data with a default address title if null
UPDATE address_info SET address_title = 'Varsayılan Adres' WHERE address_title IS NULL;

-- Step 5: Drop the unique index since we're removing is_primary
DROP INDEX IF EXISTS unique_primary_address;

-- Step 6: Recreate the simplified index
CREATE INDEX IF NOT EXISTS idx_address_info_user_id ON address_info(user_id);

-- Verify the structure
\d address_info;

SELECT 'Address info table structure simplified successfully!' AS status;