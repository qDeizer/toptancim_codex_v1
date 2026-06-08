const db = require('../db');
const generateId = require('../utils/generateId');

const createProduct = async (req, res, next) => {
    const { name, supplier_id, tags, is_active, last_purchase_date, wholesale_price, create_financial_transaction, variants, category_ids } = req.body;
    const creator_id = req.user.id;

    if (!name || !variants || !Array.isArray(variants) || variants.length === 0) {
        return res.status(400).json({ message: 'Product name and at least one variant are required.' });
    }

    const client = await db.connect();

    try {
        await client.query('BEGIN');
        const product_id = generateId('prod_', 12);
        const productQuery = `
            INSERT INTO products (product_id, creator_id, name, supplier_id, tags, is_active, last_purchase_date, wholesale_price, create_financial_transaction)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING *;
        `;
        await client.query(productQuery, [product_id, creator_id, name, supplier_id, tags, is_active, last_purchase_date, wholesale_price, create_financial_transaction]);
        const variantPromises = variants.map((variant, index) => {
            const { name, description, rating, shelf_location, images, price, cost_price, stock_quantity, is_active: variant_is_active, tags: variant_tags } = variant;
            const variant_id = generateId('var_', 12);
            const variantQuery = `
                INSERT INTO product_variants (variant_id, product_id, name, description, rating, shelf_location, images, price, cost_price, stock_quantity, is_active, tags, sort_order)
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13);
            `;
            return client.query(variantQuery, [variant_id, product_id, name, description, rating, shelf_location, images, price, cost_price, stock_quantity, variant_is_active, variant_tags, index]);
        });
        await Promise.all(variantPromises);

        if (category_ids && Array.isArray(category_ids) && category_ids.length > 0) {
            const assignmentPromises = category_ids.map(cat_id => {
                const assignment_id = generateId('cat_assign_', 12);
                const assignmentQuery = `
                    INSERT INTO category_assignments (assignment_id, product_id, category_id, assigner_id)
                    VALUES ($1, $2, $3, $4);
                `;
                return client.query(assignmentQuery, [assignment_id, product_id, cat_id, creator_id]);
            });
            await Promise.all(assignmentPromises);
        }

        await client.query('COMMIT');

        const finalResult = await getProductByIdQuery(product_id, creator_id);
        res.status(201).json(finalResult);
    } catch (error) {
        await client.query('ROLLBACK');
        next(error);
    } finally {
        client.release();
    }
};

const updateProduct = async (req, res, next) => {
    const { id } = req.params;
    const { name, supplier_id, tags, is_active, last_purchase_date, wholesale_price, create_financial_transaction, variants, category_ids, deleted_variant_ids } = req.body;
    const creator_id = req.user.id;
    if (!name || !variants || !Array.isArray(variants) || variants.length === 0) {
        return res.status(400).json({ message: 'Product name and at least one variant are required.' });
    }

    const client = await db.connect();
    try {
        await client.query('BEGIN');
        // 1. Ana ürünü güncelle
        const productQuery = `
            UPDATE products SET name = $1, supplier_id = $2, tags = $3, is_active = $4, last_purchase_date = $5, wholesale_price = $6, create_financial_transaction = $7, updated_at = NOW()
            WHERE product_id = $8 AND creator_id = $9;
        `;
        await client.query(productQuery, [name, supplier_id, tags, is_active, last_purchase_date, wholesale_price, create_financial_transaction, id, creator_id]);
        // 2. Kategori atamalarını senkronize et (önce sil, sonra ekle)
        await client.query('DELETE FROM category_assignments WHERE product_id = $1', [id]);
        if (category_ids && Array.isArray(category_ids) && category_ids.length > 0) {
            const assignmentPromises = category_ids.map(cat_id => {
                const assignment_id = generateId('cat_assign_', 12);
                return client.query('INSERT INTO category_assignments (assignment_id, product_id, category_id, assigner_id) VALUES ($1, $2, $3, $4)', [assignment_id, id, cat_id, creator_id]);
            });
            await Promise.all(assignmentPromises);
        }

        // 3. Silinmesi istenen varyantları sil
        if (deleted_variant_ids && Array.isArray(deleted_variant_ids) && deleted_variant_ids.length > 0) {
            await client.query('DELETE FROM product_variants WHERE product_id = $1 AND variant_id = ANY($2::text[])', [id, deleted_variant_ids]);
        }

        // 4. Mevcut varyantları güncelle veya yenilerini ekle
        const variantPromises = variants.map((variant, index) => {
            const { variant_id, name, description, rating, shelf_location, images, price, cost_price, stock_quantity, sold_quantity, is_active: variant_is_active, tags: variant_tags } = variant;
            if (variant_id) {
                // Mevcut varyantı güncelle - sort_order güncelle
                return client.query(`
                    UPDATE product_variants 
                    SET name = $1, description = $2, rating = $3, shelf_location = $4, images = $5, price = $6, cost_price = $7, stock_quantity = $8, sold_quantity = $9, is_active = $10, tags = $11, sort_order = $14, updated_at = NOW()
                    WHERE variant_id = $12 AND product_id = $13`,
                    [name, description, rating, shelf_location, images, price, cost_price, stock_quantity, sold_quantity, variant_is_active, variant_tags, variant_id, id, index]
                );
            } else {
                // Yeni varyant ekle - sort_order ile
                const new_variant_id = generateId('var_', 12);
                return client.query(`
                    INSERT INTO product_variants (variant_id, product_id, name, description, rating, shelf_location, images, price, cost_price, stock_quantity, sold_quantity, is_active, tags, sort_order)
                    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)`,
                    [new_variant_id, id, name, description, rating, shelf_location, images, price, cost_price, stock_quantity, sold_quantity, variant_is_active, variant_tags, index]
                );
            }
        });
        await Promise.all(variantPromises);

        await client.query('COMMIT');

        const finalResult = await getProductByIdQuery(id, creator_id);
        res.status(200).json(finalResult);
    } catch (error) {
        await client.query('ROLLBACK');
        next(error);
    } finally {
        client.release();
    }
};

const getAllProducts = async (req, res, next) => {
    const creator_id = req.user.id;
    try {
        const query = `
            SELECT 
                p.*,
                (
                    SELECT json_agg(v.* ORDER BY v.sort_order ASC, v.created_at ASC)
                    FROM product_variants v
                    WHERE v.product_id = p.product_id
                ) as variants,
                (SELECT json_agg(c.name) FROM category_assignments ca JOIN categories c ON ca.category_id = c.category_id WHERE ca.product_id = p.product_id) as category_names,
                (SELECT COUNT(*) FROM product_variants pv WHERE pv.product_id = p.product_id) as variant_count,
                (SELECT SUM(pv.stock_quantity) FROM product_variants pv WHERE pv.product_id = p.product_id) as total_stock_quantity,
                (SELECT SUM(pv.sold_quantity) FROM product_variants pv WHERE pv.product_id = p.product_id) as total_sold_quantity,
                (SELECT SUM(pv.sold_quantity * pv.price) FROM product_variants pv WHERE pv.product_id = p.product_id) as total_profit,
                (SELECT pv.price FROM product_variants pv WHERE pv.product_id = p.product_id ORDER BY pv.sort_order ASC, pv.created_at ASC LIMIT 1) as first_variant_price,
                CASE 
                    WHEN p.supplier_id IS NOT NULL THEN
                        COALESCE(
                            (SELECT u.isletme_ismi FROM users u WHERE u.user_id = p.supplier_id),
                            (SELECT eu.isletme_ismi FROM external_users eu WHERE eu.external_user_id = p.supplier_id)
                        )
                    ELSE NULL
                END as supplier_name
            FROM products p
            WHERE p.creator_id = $1
            ORDER BY p.created_at DESC;
        `;
        const result = await db.query(query, [creator_id]);

        const finalProducts = result.rows.map(product => {
            if (product.variants) {
                product.variant_thumbnails = product.variants
                    .map(v => (v.images && v.images.length > 0) ? v.images[0] : null)
                    .filter(img => img != null);
            } else {
                product.variant_thumbnails = [];
            }
            return product;
        });

        res.json(finalProducts);
    } catch (error) {
        next(error);
    }
};

const getProductByIdQuery = async (productId, creatorId) => {
    const query = `
        SELECT 
            p.*,
            (
                SELECT json_agg(variants_with_profit ORDER BY variants_with_profit.sort_order ASC, variants_with_profit.created_at ASC) 
                FROM (
                    SELECT 
                        *, 
                        (sold_quantity * price) as variant_profit 
                    FROM product_variants 
                    WHERE product_id = p.product_id
                ) AS variants_with_profit
            ) as variants,
            (SELECT SUM(sold_quantity * price) FROM product_variants WHERE product_id = p.product_id) as total_profit,
            (SELECT json_agg(ca.category_id) FROM category_assignments ca WHERE ca.product_id = p.product_id) as category_ids,
            (SELECT json_agg(c.name) FROM category_assignments ca JOIN categories c ON ca.category_id = c.category_id WHERE ca.product_id = p.product_id) as category_names,
            CASE 
                WHEN p.supplier_id IS NOT NULL THEN
                    COALESCE(
                        (SELECT u.isletme_ismi FROM users u WHERE u.user_id = p.supplier_id),
                        (SELECT eu.isletme_ismi FROM external_users eu WHERE eu.external_user_id = p.supplier_id)
                    )
                ELSE NULL
            END as supplier_name
        FROM products p
        WHERE p.product_id = $1 AND p.creator_id = $2;
    `;
    const result = await db.query(query, [productId, creatorId]);
    return result.rows[0];
};

const getProductById = async (req, res, next) => {
    const { id } = req.params;
    const creator_id = req.user.id;
    try {
        const product = await getProductByIdQuery(id, creator_id);
        if (!product) {
            return res.status(404).json({ message: 'Product not found.' });
        }
        res.json(product);
    } catch (error) {
        next(error);
    }
};

const deleteProduct = async (req, res, next) => {
    const { id } = req.params;
    const creator_id = req.user.id;
    try {
        const deleteResult = await db.query(
            'DELETE FROM products WHERE product_id = $1 AND creator_id = $2 RETURNING *',
            [id, creator_id]
        );
        if (deleteResult.rowCount === 0) {
            return res.status(404).json({ message: 'Product not found or you do not have permission to delete it.' });
        }
        res.json({ message: 'Product and its associations deleted successfully.' });
    } catch (error) {
        next(error);
    }
};

module.exports = {
    createProduct,
    getAllProducts,
    getProductById,
    updateProduct,
    deleteProduct,
};