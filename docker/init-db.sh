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

# 1. Ana şemayı oluştur (init.sql - Docker uyumlu versiyon)
echo "[1/3] Ana şema oluşturuluyor..."
$PSQL -f /sql/docker-init.sql

# 2. Migration'ları sırayla çalıştır
echo "[2/3] Migration'lar uygulanıyor..."

$PSQL -f /sql/migration_create_notifications.sql
echo "  ✓ notifications tablosu"

$PSQL -f /sql/migration_add_media.sql
echo "  ✓ media tablosu"

$PSQL -f /sql/migration_add_variant_sort_order.sql
echo "  ✓ variant sort_order"

$PSQL -f /sql/migration_add_user_tables.sql
echo "  ✓ user detail tables"

$PSQL -f /sql/migration_add_created_at.sql
echo "  ✓ created_at columns"

$PSQL -f /sql/migration_add_updated_at.sql
echo "  ✓ updated_at columns"

$PSQL -f /sql/migration_add_approval_columns.sql
echo "  ✓ approval columns"

$PSQL -f /sql/migration_add_unique_constraint.sql
echo "  ✓ unique constraints"

$PSQL -f /sql/migration_add_actor_id.sql
echo "  ✓ actor_id"

$PSQL -f /sql/migration_fix_dual_roles.sql
echo "  ✓ dual roles fix"

$PSQL -f /sql/migration_recreate_user_details_tables.sql
echo "  ✓ user details tables recreated"

$PSQL -f /sql/migration_simplify_address_info.sql
echo "  ✓ address info simplified"

$PSQL -f /sql/migration_remove_jsonb_columns.sql
echo "  ✓ jsonb columns removed"

$PSQL -f /sql/migration_update_address_structure.sql
echo "  ✓ address structure updated"

echo "[3/3] ML view oluşturuluyor..."
$PSQL -f /sql/create_ml_view.sql 2>/dev/null || echo "  ⚠ ML view atlandı (opsiyonel)"

echo ""
echo "========================================="
echo " ✅ Veritabanı başarıyla başlatıldı!"
echo " Tablo sayısı:"
$PSQL -t -c "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE';"
echo "========================================="
