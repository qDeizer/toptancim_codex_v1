-- PostgreSQL'de çalıştır: psql -U postgres -d toptancimdb_codex -f migration_fix_dual_roles.sql

\c toptancimdb_codex

ALTER TABLE relations DROP CONSTRAINT IF EXISTS relations_wholesaler_id_customer_id_key;