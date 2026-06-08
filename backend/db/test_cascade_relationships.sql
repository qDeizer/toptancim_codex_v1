-- Test script to verify CASCADE relationships work correctly
-- Run this script: psql -U postgres -d toptancimdb_codex -f backend/db/test_cascade_relationships.sql

\c toptancimdb_codex;

-- Check if tables exist
\dt account_movements address_info;

-- Show foreign key constraints
SELECT 
    tc.table_name, 
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name,
    rc.delete_rule
FROM information_schema.table_constraints AS tc 
    JOIN information_schema.key_column_usage AS kcu
        ON tc.constraint_name = kcu.constraint_name
    JOIN information_schema.constraint_column_usage AS ccu
        ON ccu.constraint_name = tc.constraint_name
    JOIN information_schema.referential_constraints AS rc
        ON tc.constraint_name = rc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY' 
    AND tc.table_name IN ('account_movements', 'address_info');

-- Insert a test user
INSERT INTO users (user_id, user_name, isletme_ismi, ad, soyad, tel_no, email, password_hash)
VALUES ('test_cascade_user_001', 'test_cascade_user', 'Test Company', 'Test', 'User', '+905551234567', 'test@cascade.com', '$2a$10$hashedpassword')
ON CONFLICT (user_id) DO NOTHING;

-- Insert test data into account_movements
INSERT INTO account_movements (movement_id, user_id, creation_date, last_update)
VALUES ('acc_test_001', 'test_cascade_user_001', NOW(), NOW())
ON CONFLICT (movement_id) DO NOTHING;

-- Insert test data into address_info  
INSERT INTO address_info (address_id, user_id, address, is_primary)
VALUES ('addr_test_001', 'test_cascade_user_001', 'Test Address', TRUE)
ON CONFLICT (address_id) DO NOTHING;

-- Verify data was inserted
SELECT 'Before deletion:' AS status;
SELECT COUNT(*) AS user_count FROM users WHERE user_id = 'test_cascade_user_001';
SELECT COUNT(*) AS account_movements_count FROM account_movements WHERE user_id = 'test_cascade_user_001';
SELECT COUNT(*) AS address_info_count FROM address_info WHERE user_id = 'test_cascade_user_001';

-- Test CASCADE: Delete the user and verify related records are also deleted
DELETE FROM users WHERE user_id = 'test_cascade_user_001';

-- Verify CASCADE worked - all related records should be deleted
SELECT 'After deletion (should all be 0):' AS status;
SELECT COUNT(*) AS user_count FROM users WHERE user_id = 'test_cascade_user_001';
SELECT COUNT(*) AS account_movements_count FROM account_movements WHERE user_id = 'test_cascade_user_001';
SELECT COUNT(*) AS address_info_count FROM address_info WHERE user_id = 'test_cascade_user_001';

SELECT 'CASCADE relationship test completed successfully!' AS result;