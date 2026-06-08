-- Migration script to remove old JSONB columns from users table
-- IMPORTANT: Run this ONLY after migration_add_user_tables.sql has been executed successfully
-- Run this script: psql -U postgres -d toptancimdb_codex -f backend/db/migration_remove_jsonb_columns.sql

\c toptancimdb_codex;

-- Remove the old JSONB columns from users table
ALTER TABLE users DROP COLUMN IF EXISTS adres_bilgisi;
ALTER TABLE users DROP COLUMN IF EXISTS hesap_hareketi;

-- Verify the migration was successful
SELECT 'Migration completed successfully. Old JSONB columns removed.' AS status;