-- Verify address migration
\c toptancimdb_codex;

-- Check table structure
\d external_users;

-- Verify new columns exist
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'external_users' 
AND column_name IN ('address_title', 'address', 'detailed_address', 'latitude', 'longitude');