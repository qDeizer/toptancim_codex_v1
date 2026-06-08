-- Bu betik, mevcut 'account_movements' tablosuna user_id için UNIQUE kısıtlaması ekler.
-- 'ON CONFLICT' ifadesinin doğru çalışması için bu gereklidir.
-- Çalıştırmak için: psql -U postgres -d toptancimdb_codex -f backend/db/migration_add_unique_constraint.sql

\c toptancimdb_codex;

-- Hata almamak için öncelikle mevcut bir kısıtlama varsa onu kaldıralım.
ALTER TABLE account_movements DROP CONSTRAINT IF EXISTS account_movements_user_id_key;

-- user_id kolonuna UNIQUE kısıtlamasını ekle.
ALTER TABLE account_movements ADD CONSTRAINT account_movements_user_id_key UNIQUE (user_id);

SELECT 'account_movements tablosuna user_id için UNIQUE kısıtlaması başarıyla eklendi.' AS status;