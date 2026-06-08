-- Backup script before address migration
-- Run this BEFORE the migration

\c toptancimdb_codex;

-- Create backup table
CREATE TABLE external_users_backup_address AS 
SELECT * FROM external_users;

-- Verify backup
SELECT COUNT(*) as total_records FROM external_users_backup_address;
SELECT 'Backup created successfully' AS status;