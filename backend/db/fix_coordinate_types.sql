-- Koordinat tiplerini düzelt
\c toptancimdb_codex;

-- Önce mevcut verileri kontrol et
SELECT 'Mevcut veri tipleri:' AS info;
SELECT pg_typeof(latitude) as lat_type, pg_typeof(longitude) as lng_type FROM address_info LIMIT 1;

-- Eğer text tipindeyse, numeric'e dönüştür
-- Önce geçici sütunlar oluştur
ALTER TABLE address_info ADD COLUMN IF NOT EXISTS latitude_temp NUMERIC(10,7);
ALTER TABLE address_info ADD COLUMN IF NOT EXISTS longitude_temp NUMERIC(10,7);

-- Mevcut verileri numeric'e dönüştür (sadece geçerli sayısal değerler için)
UPDATE address_info 
SET 
    latitude_temp = CASE 
        WHEN latitude ~ '^-?[0-9]+\.?[0-9]*$' THEN latitude::NUMERIC(10,7)
        ELSE NULL 
    END,
    longitude_temp = CASE 
        WHEN longitude ~ '^-?[0-9]+\.?[0-9]*$' THEN longitude::NUMERIC(10,7)
        ELSE NULL 
    END;

-- Eski sütunları sil
ALTER TABLE address_info DROP COLUMN IF EXISTS latitude;
ALTER TABLE address_info DROP COLUMN IF EXISTS longitude;

-- Yeni sütunları yeniden adlandır
ALTER TABLE address_info RENAME COLUMN latitude_temp TO latitude;
ALTER TABLE address_info RENAME COLUMN longitude_temp TO longitude;

SELECT 'Koordinat tipleri başarıyla düzeltildi!' AS result;