-- Rollback script for address migration
-- Use this if you need to revert changes

\c toptancimdb_codex;

-- Step 1: Add back the original 'adres' column
ALTER TABLE external_users ADD COLUMN IF NOT EXISTS adres TEXT;

-- Step 2: Restore data from address column to adres
UPDATE external_users 
SET adres = address 
WHERE address IS NOT NULL;

-- Step 3: Remove new columns
ALTER TABLE external_users DROP COLUMN IF EXISTS address_title;
ALTER TABLE external_users DROP COLUMN IF EXISTS address;
ALTER TABLE external_users DROP COLUMN IF EXISTS detailed_address;
ALTER TABLE external_users DROP COLUMN IF EXISTS latitude;
ALTER TABLE external_users DROP COLUMN IF EXISTS longitude;

-- Step 4: Restore from backup if needed (uncomment if necessary)
-- DROP TABLE IF EXISTS external_users;
-- ALTER TABLE external_users_backup_address RENAME TO external_users;

SELECT 'Migration rolled back successfully' AS status;