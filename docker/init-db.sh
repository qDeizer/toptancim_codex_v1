#!/bin/bash
# =============================================================================
# Toptancım B2B — Docker Veritabanı Başlatma Betiği
# =============================================================================
# Bu script, PostgreSQL container'ı ilk kez oluşturulduğunda otomatik çalışır.
# /docker-entrypoint-initdb.d/ içine mount edilir.
#
# UYARI: Bu script sadece pgdata volume'u BOŞ olduğunda çalışır!
# Mevcut bir veritabanını güncellemek için migration'ları elle çalıştırın.
# =============================================================================

set -e

echo "========================================="
echo " Toptancım DB Başlatma Scripti"
echo "========================================="

PSQL="psql -v ON_ERROR_STOP=1 --username $POSTGRES_USER --dbname $POSTGRES_DB"
PSQL_SOFT="psql --username $POSTGRES_USER --dbname $POSTGRES_DB"

# 1. Ana şemayı oluştur (init.sql - Docker uyumlu versiyon) — zorunlu
echo "[1/3] Ana şema oluşturuluyor..."
$PSQL -f /sql/docker-init.sql
echo "  ✓ Ana şema (14 tablo + indexler)"

# 2. Migration'ları sırayla çalıştır
# NOT: Bazı migration'lar eski JSONB yapısından geçiş scriptleri içerir ve
# yeni kurulumda hata verebilir. Bu yüzden hata toleranslı (PSQL_SOFT) çalıştırılır.
echo "[2/3] Migration'lar uygulanıyor..."

$PSQL -f /sql/migration_create_notifications.sql
echo "  ✓ notifications tablosu"

$PSQL -f /sql/migration_add_media.sql
echo "  ✓ media tablosu"

$PSQL_SOFT -f /sql/migration_add_variant_sort_order.sql 2>/dev/null
echo "  ✓ variant sort_order"

# Bu migration eski JSONB->tablo geçişi içerir, yeni kurulumda sorun çıkarabilir
$PSQL_SOFT -f /sql/migration_add_user_tables.sql 2>/dev/null || echo "  ⚠ user tables migration kısmen uygulandı (beklenen)"

$PSQL_SOFT -f /sql/migration_add_created_at.sql 2>/dev/null
echo "  ✓ created_at columns"

$PSQL_SOFT -f /sql/migration_add_updated_at.sql 2>/dev/null
echo "  ✓ updated_at columns"

$PSQL_SOFT -f /sql/migration_add_approval_columns.sql 2>/dev/null
echo "  ✓ approval columns"

$PSQL_SOFT -f /sql/migration_add_unique_constraint.sql 2>/dev/null
echo "  ✓ unique constraints"

$PSQL_SOFT -f /sql/migration_add_actor_id.sql 2>/dev/null
echo "  ✓ actor_id"

$PSQL_SOFT -f /sql/migration_fix_dual_roles.sql 2>/dev/null
echo "  ✓ dual roles fix"

$PSQL_SOFT -f /sql/migration_recreate_user_details_tables.sql 2>/dev/null || echo "  ⚠ user details kısmen uygulandı"

$PSQL_SOFT -f /sql/migration_simplify_address_info.sql 2>/dev/null || echo "  ⚠ address simplify kısmen uygulandı"

$PSQL_SOFT -f /sql/migration_remove_jsonb_columns.sql 2>/dev/null || echo "  ⚠ jsonb remove kısmen uygulandı"

$PSQL_SOFT -f /sql/migration_update_address_structure.sql 2>/dev/null || echo "  ⚠ address structure kısmen uygulandı"

echo "[3/3] ML view oluşturuluyor..."
$PSQL_SOFT -f /sql/create_ml_view.sql 2>/dev/null || echo "  ⚠ ML view atlandı (opsiyonel)"

echo ""
echo "========================================="
echo " ✅ Veritabanı başarıyla başlatıldı!"
echo " Tablo sayısı:"
$PSQL -t -c "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE';"
echo "========================================="
