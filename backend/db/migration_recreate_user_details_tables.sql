-- Bu betik, 'account_movements' ve 'address_info' tablolarını en son istenen yapıya göre yeniden oluşturur.
-- Önce mevcut tabloları (varsa) siler ve ardından doğru şema ile yeniden yaratır.
-- DİKKAT: Bu işlem bu tablolardaki mevcut tüm verileri silecektir!
-- Çalıştırmak için: psql -U postgres -d toptancimdb_codex -f backend/db/migration_recreate_user_details_tables.sql

\c toptancimdb_codex;

-- Mevcut tabloları ve bağımlılıklarını sil
DROP TABLE IF EXISTS address_info CASCADE;
DROP TABLE IF EXISTS account_movements CASCADE;

-- account_movements tablosunu yeniden oluştur
CREATE TABLE account_movements (
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

-- address_info tablosunu istenen yeni yapıya göre yeniden oluştur
CREATE TABLE address_info (
    address_id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    address_title TEXT, -- Adres Başlığı
    address TEXT, -- Adres
    detailed_address TEXT, -- Açık Adres
    latitude NUMERIC(10, 7), -- Enlem
    longitude NUMERIC(10, 7) -- Boylam
);

-- Performans için index'leri ekle
CREATE INDEX idx_account_movements_user_id ON account_movements(user_id);
CREATE INDEX idx_address_info_user_id ON address_info(user_id);

SELECT 'account_movements ve address_info tabloları başarıyla yeniden oluşturuldu.' AS status;