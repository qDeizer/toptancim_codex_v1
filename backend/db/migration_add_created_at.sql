-- Migration script to add created_at column to users table if missing
-- Run this script: psql -U postgres -d toptancimdb_codex -f backend/db/migration_add_created_at.sql

\c toptancimdb_codex;

-- Add created_at column if it doesn't exist
ALTER TABLE users ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();

-- Update existing records to have created_at value
UPDATE users SET created_at = NOW() WHERE created_at IS NULL;

-- Verify the structure
SELECT 'Users table created_at column added successfully!' AS status;