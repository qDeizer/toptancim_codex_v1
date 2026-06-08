const db = require('../db');

const getShopProducts = async (req, res, next) => {
    const customer_id = req.user.id;
    const { wholesaler_id } = req.query; // İsteğe bağlı filtreleme

    try {
        const query = `
        WITH customer_wholesalers AS (
            SELECT r.wholesaler_id, r.relation_id
            FROM relations r
            WHERE r.customer_id = $1 AND r.is_wholesaler_internal = TRUE
              AND ($2::text IS NULL OR r.wholesaler_id = $2::text)
        ),
        customer_pricing AS (
            SELECT
                t.creator_id AS wholesaler_id,
                COALESCE(SUM(t.pricing_percentage), 0) as total_percentage,
                COALESCE(SUM(t.pricing_delta), 0) as total_delta
            FROM customer_wholesalers cw
            JOIN tag_assignments ta ON cw.relation_id = ta.relation_id
            JOIN tags t ON ta.tag_id = t.tag_id
            GROUP BY t.creator_id
        )
        SELECT 
            p.*,
            v.variant_id,
            v.name as variant_name,
            v.description as variant_description,
            v.images as variant_images,
            v.rating as variant_rating, -- YENİ
            (v.stock_quantity - v.sold_quantity) as available_stock,
            -- Müşteriye özel fiyatı hesapla
            (
                v.price * (1 + COALESCE(cp.total_percentage, 0) / 100) + COALESCE(cp.total_delta, 0)
            ) as final_price,
            v.price as original_price,
            (SELECT json_agg(c.name) 
             FROM category_assignments ca 
             JOIN categories c ON ca.category_id = c.category_id 
             WHERE ca.product_id = p.product_id) as category_names,
            COALESCE(u.isletme_ismi, u.ad || ' ' || u.soyad) as wholesaler_name,
            u.profil_fotografi as wholesaler_photo
        FROM products p
        JOIN product_variants v ON p.product_id = v.product_id
        -- Sadece müşterinin toptancılarına ait ürünleri getir
        JOIN customer_wholesalers cw ON p.creator_id = cw.wholesaler_id
        -- Toptancı bilgilerini getir
        JOIN users u ON p.creator_id = u.user_id
        -- Fiyatlandırma bilgilerini join et
        LEFT JOIN customer_pricing cp ON p.creator_id = cp.wholesaler_id
        WHERE p.is_active = TRUE AND v.is_active = TRUE
        ORDER BY p.created_at DESC, v.sort_order ASC, v.created_at ASC; -- Varyantları tutarlı sırala
        `;

        const result = await db.query(query, [customer_id, wholesaler_id || null]);
        // Gelen veriyi ürün bazında grupla
        const productsMap = new Map();
        result.rows.forEach(row => {
            if (!productsMap.has(row.product_id)) {
                productsMap.set(row.product_id, {
                    product_id: row.product_id,
                    name: row.name,
                    creator_id: row.creator_id,
                    wholesaler_name: row.wholesaler_name,
                    wholesaler_photo: row.wholesaler_photo,
                    category_names: row.category_names,
                    variants: [],
                    // Geçici alanlar
                    _total_rating: 0,
                    _rating_count: 0,
                });
            }

            const product = productsMap.get(row.product_id);

            product.variants.push({
                variant_id: row.variant_id,
                name: row.variant_name,
                description: row.variant_description,
                images: row.variant_images,
                stock_quantity: row.available_stock,
                price: parseFloat(row.final_price).toFixed(2),
                original_price: parseFloat(row.original_price).toFixed(2),
                rating: row.variant_rating,
            });

            if (row.variant_rating != null) {
                product._total_rating += parseFloat(row.variant_rating);
                product._rating_count += 1;
            }
        });

        const finalProducts = Array.from(productsMap.values()).map(product => {
            // Ortalama puanı hesapla
            product.average_rating = product._rating_count > 0
                ? (product._total_rating / product._rating_count)
                : 0;

            // Varyant resimlerini topla (her varyanttan ilk resim) - SIRALI OLARAK
            // Önce varyantları created_at sırasına göre sıralayalım
            // Bu zaten sorguda ORDER BY p.created_at DESC, v.created_at ASC ile yapıldı
            product.variant_thumbnails = product.variants
                .map(v => (v.images && v.images.length > 0) ? v.images[0] : null)
                .filter(img => img != null);

            // Geçici alanları sil
            delete product._total_rating;
            delete product._rating_count;

            return product;
        });


        res.json(finalProducts);

    } catch (error) {
        next(error);
    }
};

module.exports = {
    getShopProducts,
};