-- Run with:
-- psql -U postgres -d toptancimdb_codex -f backend/db/create_ml_view.sql

CREATE OR REPLACE VIEW ml_sales_view AS
SELECT
    p.name AS product_name,
    p.product_id,
    pv.variant_id,
    pv.name AS variant_name,
    c.name AS category_name,
    pv.shelf_location,
    pv.cost_price,
    ci.current_price AS sold_price,
    ci.quantity,
    ca.total_amount,
    u.role AS customer_role,
    u.user_id AS customer_id,
    addr.latitude AS customer_lat,
    addr.longitude AS customer_lng,
    ca.created_at AS sale_date,
    ca.status AS order_status,
    pv.stock_quantity AS current_stock,
    ca.wholesaler_id,
    ca.cart_id,
    (ci.quantity * ci.current_price) AS line_total,
    u.isletme_ismi AS customer_business_name,
    u.ad AS customer_first_name,
    u.soyad AS customer_last_name,
    wholesaler.isletme_ismi AS wholesaler_business_name
FROM cart_items ci
JOIN product_variants pv ON ci.variant_id = pv.variant_id
JOIN products p ON pv.product_id = p.product_id
JOIN carts ca ON ci.cart_id = ca.cart_id
JOIN users u ON ca.customer_id = u.user_id
LEFT JOIN users wholesaler ON ca.wholesaler_id = wholesaler.user_id
LEFT JOIN address_info addr ON addr.user_id = u.user_id
LEFT JOIN LATERAL (
    SELECT c_sub.name
    FROM category_assignments ca_sub
    JOIN categories c_sub ON ca_sub.category_id = c_sub.category_id
    WHERE ca_sub.product_id = p.product_id
    ORDER BY ca_sub.created_at ASC
    LIMIT 1
) c ON true;
