const db = require('../db');
const { recalculateCartTotal, synchronizeCart } = require('../utils/cartUtils');
const generateId = require('../utils/generateId');

const getOrdersBetweenUsers = async (req, res, next) => {
    const own_user_id = req.user.id;
    const { personId } = req.params;

    try {
        const query = `
            SELECT
                c.cart_id, c.customer_id, c.wholesaler_id, c.status, c.total_amount, c.updated_at, c.ordered_at,
                w.isletme_ismi as wholesaler_name,
                w.profil_fotografi as wholesaler_photo,
                cust.isletme_ismi as customer_name,
                cust.profil_fotografi as customer_photo,
                COALESCE(
                    (
                        SELECT json_agg(item_obj)
                        FROM (
                            SELECT
                                ci.cart_item_id, ci.variant_id, ci.quantity, ci.current_price as price,
                                pv.name as variant_name, pv.images[1] as variant_image, p.name as product_name,
                                (p.name || ' - ' || pv.name) as display_name
                            FROM cart_items ci
                            JOIN product_variants pv ON ci.variant_id = pv.variant_id
                            JOIN products p ON pv.product_id = p.product_id
                            WHERE ci.cart_id = c.cart_id
                        ) as item_obj
                    ),
                    '[]'::json
                ) as items
            FROM carts c
            JOIN users w ON c.wholesaler_id = w.user_id
            JOIN users cust ON c.customer_id = cust.user_id
            WHERE
                c.status != 'active' AND
                ((c.customer_id = $1 AND c.wholesaler_id = $2) OR (c.customer_id = $2 AND c.wholesaler_id = $1))
            GROUP BY c.cart_id, w.isletme_ismi, w.profil_fotografi, cust.isletme_ismi, cust.profil_fotografi
            ORDER BY c.ordered_at DESC;
        `;
        const result = await db.query(query, [own_user_id, personId]);
        res.json(result.rows);
    } catch (error) {
        next(error);
    }
};


const getWholesalerOrders = async (req, res, next) => {
    const wholesaler_id = req.user.id;
    try {
        const query = `
            SELECT
                c.cart_id, c.customer_id, c.status, c.total_amount, c.updated_at, c.ordered_at,
                u.isletme_ismi as customer_name,
                u.profil_fotografi as customer_photo,
                COALESCE(
                    (
                        SELECT json_agg(item_obj)
                        FROM (
                            SELECT
                                ci.cart_item_id,
                                ci.variant_id,
                                ci.quantity,
                                ci.current_price as price,
                                pv.name as variant_name,
                                pv.images[1] as variant_image,
                                p.name as product_name,
                                (p.name || ' - ' || pv.name) as display_name
                             FROM cart_items ci
                            JOIN product_variants pv ON ci.variant_id = pv.variant_id
                            JOIN products p ON pv.product_id = p.product_id
                            WHERE ci.cart_id = c.cart_id
                         ) as item_obj
                    ),
                    '[]'::json
                ) as items
            FROM carts c
            JOIN users u ON c.customer_id = u.user_id
            WHERE c.wholesaler_id = $1 AND c.status != 'active'
            GROUP BY c.cart_id, u.isletme_ismi, u.profil_fotografi
            ORDER BY
                CASE c.status
                    WHEN 'ordered' THEN 1
                    WHEN 'preparing' THEN 2
                    WHEN 'shipped' THEN 3
                    WHEN 'delivered' THEN 4
                    WHEN 'cancelled' THEN 5
                    ELSE 6
                END,
                c.updated_at DESC;
        `;
        const result = await db.query(query, [wholesaler_id]);
        res.json(result.rows);
    } catch (error) {
        next(error);
    }
};

const confirmSaleByWholesaler = async (req, res, next) => {
    const { cartId } = req.params;
    const wholesaler_id = req.user.id;
    const client = await db.connect();

    try {
        await client.query('BEGIN');
        const syncResult = await synchronizeCart(client, cartId);

        const cartResult = await client.query(
            "SELECT * FROM carts WHERE cart_id = $1 AND wholesaler_id = $2 AND status = 'ordered'",
            [cartId, wholesaler_id]
        );
        if (cartResult.rows.length === 0) {
            await client.query('ROLLBACK');
            return res.status(404).json({ message: "Onaylanacak sipariş bulunamadı veya bu siparişi onaylama yetkiniz yok." });
        }
        
        const itemsResult = await client.query(
            "SELECT variant_id, quantity FROM cart_items WHERE cart_id = $1",
            [cartId]
        );
        const items = itemsResult.rows;

        if (items.length === 0) {
            await client.query('ROLLBACK');
            return res.status(400).json({ message: "Onaylanacak sipariş boş." });
        }
        
        for (const item of items) {
            const variantResult = await client.query(
                "SELECT stock_quantity, sold_quantity, name FROM product_variants WHERE variant_id = $1 FOR UPDATE",
                [item.variant_id]
            );
            if (variantResult.rows.length === 0) {
                throw new Error(`Sipariş içerisindeki bir ürün (${item.variant_id}) artık mevcut değil.`);
            }

            const variant = variantResult.rows[0];
            const availableStock = variant.stock_quantity - variant.sold_quantity;

            if (item.quantity > availableStock) {
                throw new Error(`"${variant.name}" adlı ürün için stok yetersiz. İstenen: ${item.quantity}, Mevcut: ${availableStock}.`);
            }

            await client.query(
                "UPDATE product_variants SET sold_quantity = sold_quantity + $1 WHERE variant_id = $2",
                [item.quantity, item.variant_id]
            );
        }

        const updatedCart = await client.query(
            "UPDATE carts SET status = 'preparing', updated_at = NOW() WHERE cart_id = $1 RETURNING *",
            [cartId]
        );
        await client.query('COMMIT');
        res.status(200).json({ 
            message: "Sipariş başarıyla onaylandı ve stok güncellendi.", 
            cart: updatedCart.rows[0],
            syncChanges: syncResult.changes
        });
    } catch (error) {
        await client.query('ROLLBACK');
        error.message = error.message.replace('error: ', '');
        next(error);
    } finally {
        client.release();
    }
};

const updateOrderStatusByWholesaler = async (req, res, next) => {
    const { cartId } = req.params;
    const { status, createTransaction } = req.body;
    const wholesaler_id = req.user.id;
    
    const allowedStatus = ['preparing', 'shipped', 'delivered', 'cancelled'];
    if (!status || !allowedStatus.includes(status)) {
        return res.status(400).json({ message: 'Geçersiz veya izin verilmeyen durum.' });
    }

    const client = await db.connect();
    try {
        await client.query('BEGIN');
        const cartRes = await client.query(
            "SELECT * FROM carts WHERE cart_id = $1 AND wholesaler_id = $2", 
            [cartId, wholesaler_id]
        );
        if (cartRes.rowCount === 0) {
            await client.query('ROLLBACK');
            return res.status(404).json({ message: 'Sipariş bulunamadı veya yetkiniz yok.' });
        }
        
        const cart = cartRes.rows[0];
        const result = await client.query(
            "UPDATE carts SET status = $1, updated_at = NOW() WHERE cart_id = $2 RETURNING *",
            [status, cartId]
        );
        if (status === 'delivered' && createTransaction === true) {
            const transaction_id = generateId('trn_', 16);
            const saleTransactionQuery = `
                INSERT INTO financial_transactions 
                (transaction_id, creator_id, transaction_type, category, amount, currency, payment_method, description, transaction_date, from_id, is_from_internal, to_id, is_to_internal, reference_id, reference_type)
                VALUES ($1, $2, 'Tahakkuk', 'Satış', $3, 'TRY', 'Veresiye', $4, NOW(), $2, TRUE, $5, TRUE, $6, 'Alışveriş')
                RETURNING transaction_id;
            `;
            const description = `${cart.customer_name || 'Müşteri'} adlı kişiye yapılan satış.`;
            const transactionResult = await client.query(saleTransactionQuery, [
                transaction_id, 
                wholesaler_id, 
                cart.total_amount,
                description,
                cart.customer_id,
                cartId
            ]);
            
            const newTransactionId = transactionResult.rows[0].transaction_id;
            await client.query(
                "UPDATE carts SET financial_transaction_id = $1 WHERE cart_id = $2",
                [newTransactionId, cartId]
            );
        }

        await client.query('COMMIT');
        res.json(result.rows[0]);
    } catch (error) {
        await client.query('ROLLBACK');
        next(error);
    } finally {
        client.release();
    }
};

const updateItemInOrderByWholesaler = async (req, res, next) => {
    const { cartId, cartItemId } = req.params;
    const { quantity } = req.body;
    const wholesaler_id = req.user.id;
    if (quantity === undefined || quantity < 0) {
        return res.status(400).json({ message: 'Geçersiz miktar. Miktar 0\'dan küçük olamaz.' });
    }

    const client = await db.connect();
    try {
        await client.query('BEGIN');
        const cartResult = await client.query(
            "SELECT status FROM carts WHERE cart_id = $1 AND wholesaler_id = $2",
            [cartId, wholesaler_id]
        );
        if (cartResult.rows.length === 0) {
            await client.query('ROLLBACK');
            return res.status(404).json({ message: 'Sipariş bulunamadı veya size ait değil.' });
        }
        const cartStatus = cartResult.rows[0].status;
        if (!['ordered', 'preparing', 'shipped'].includes(cartStatus)) {
            await client.query('ROLLBACK');
            return res.status(400).json({ message: `Bu sipariş durumu (${cartStatus}) düzenlenemez.` });
        }
        
        if (quantity === 0) {
            await client.query("DELETE FROM cart_items WHERE cart_item_id = $1 AND cart_id = $2", [cartItemId, cartId]);
        } else {
            await client.query(
                "UPDATE cart_items SET quantity = $1 WHERE cart_item_id = $2 AND cart_id = $3",
                [quantity, cartItemId, cartId]
            );
        }
        
        const newTotal = await recalculateCartTotal(client, cartId);
        await client.query('COMMIT');
        res.status(200).json({ message: 'Sipariş güncellendi.', newTotalAmount: newTotal });

    } catch (error) {
        await client.query('ROLLBACK');
        next(error);
    } finally {
        client.release();
    }
};

const removeItemFromOrderByWholesaler = async (req, res, next) => {
    const { cartId, cartItemId } = req.params;
    const wholesaler_id = req.user.id;
    const client = await db.connect();
    
    try {
        await client.query('BEGIN');
        const cartResult = await client.query("SELECT status FROM carts WHERE cart_id = $1 AND wholesaler_id = $2", [cartId, wholesaler_id]);
        if (cartResult.rows.length === 0) {
            await client.query('ROLLBACK');
            return res.status(404).json({ message: 'Sipariş bulunamadı veya size ait değil.' });
        }
         const cartStatus = cartResult.rows[0].status;
        if (!['ordered', 'preparing', 'shipped'].includes(cartStatus)) {
            await client.query('ROLLBACK');
            return res.status(400).json({ message: `Bu sipariş durumu (${cartStatus}) düzenlenemez.` });
        }

        await client.query("DELETE FROM cart_items WHERE cart_item_id = $1 AND cart_id = $2", [cartItemId, cartId]);
        const newTotal = await recalculateCartTotal(client, cartId);
        
        await client.query('COMMIT');
        res.status(200).json({ message: 'Ürün siparişten kaldırıldı.', newTotalAmount: newTotal });
    } catch (error) {
        await client.query('ROLLBACK');
        next(error);
    } finally {
        client.release();
    }
};

const addItemToOrderByWholesaler = async (req, res, next) => {
    const { cartId } = req.params;
    const { variant_id, quantity } = req.body;
    const wholesaler_id = req.user.id;
    const client = await db.connect();
    try {
        await client.query('BEGIN');
        const cartResult = await client.query(
            "SELECT customer_id, status FROM carts WHERE cart_id = $1 AND wholesaler_id = $2",
            [cartId, wholesaler_id]
        );
        if (cartResult.rows.length === 0) {
            await client.query('ROLLBACK');
            return res.status(404).json({ message: "Sipariş bulunamadı veya yetkiniz yok." });
        }
        
        const { customer_id, status } = cartResult.rows[0];
        if (!['ordered', 'preparing', 'shipped'].includes(status)) {
            await client.query('ROLLBACK');
            return res.status(400).json({ message: `Bu sipariş durumu (${status}) düzenlenemez.` });
        }

        const variantResult = await client.query(
            `SELECT price FROM product_variants WHERE variant_id = $1`, [variant_id]
        );
        if (variantResult.rows.length === 0) {
             await client.query('ROLLBACK');
            return res.status(404).json({ message: "Ürün bulunamadı." });
        }

        const pricingQuery = `
            SELECT COALESCE(SUM(t.pricing_percentage), 0) as total_percentage,
                   COALESCE(SUM(t.pricing_delta), 0) as total_delta
            FROM relations r
            LEFT JOIN tag_assignments ta ON r.relation_id = ta.relation_id
            LEFT JOIN tags t ON ta.tag_id = t.tag_id AND t.creator_id = r.wholesaler_id
            WHERE r.customer_id = $1 AND r.wholesaler_id = $2;
        `;
        const pricingResult = await client.query(pricingQuery, [customer_id, wholesaler_id]);
        const { total_percentage, total_delta } = pricingResult.rows[0];
        const finalPrice = variantResult.rows[0].price * (1 + (parseFloat(total_percentage) / 100)) + parseFloat(total_delta);
        const existingItemResult = await client.query(
            "SELECT cart_item_id FROM cart_items WHERE cart_id = $1 AND variant_id = $2", [cartId, variant_id]
        );
        if (existingItemResult.rows.length > 0) {
            await client.query(
                "UPDATE cart_items SET quantity = quantity + $1 WHERE cart_id = $2 AND variant_id = $3",
                [quantity, cartId, variant_id]
            );
        } else {
            const cart_item_id = generateId('item_', 16);
            await client.query(
                "INSERT INTO cart_items (cart_item_id, cart_id, variant_id, quantity, current_price) VALUES ($1, $2, $3, $4, $5)",
                [cart_item_id, cartId, variant_id, quantity, finalPrice]
            );
        }

        await recalculateCartTotal(client, cartId);
        await client.query('COMMIT');
        res.status(200).json({ message: 'Ürün siparişe eklendi.' });
    } catch (error) {
        await client.query('ROLLBACK');
        next(error);
    } finally {
        client.release();
    }
};

const overrideTotalAmountByWholesaler = async (req, res, next) => {
    const { cartId } = req.params;
    const { total_amount } = req.body;
    const wholesaler_id = req.user.id;
    if (total_amount === undefined || isNaN(parseFloat(total_amount)) || total_amount < 0) {
        return res.status(400).json({ message: 'Geçerli bir toplam tutar girilmelidir.' });
    }

    try {
        const result = await db.query(
            "UPDATE carts SET total_amount = $1, updated_at = NOW() WHERE cart_id = $2 AND wholesaler_id = $3 RETURNING *",
            [total_amount, cartId, wholesaler_id]
        );
        if (result.rowCount === 0) {
            return res.status(404).json({ message: 'Sipariş bulunamadı veya yetkiniz yok.' });
        }
        res.status(200).json({ message: 'Toplam tutar güncellendi.', cart: result.rows[0] });
    } catch (error) {
        next(error);
    }
};

module.exports = {
    getWholesalerOrders,
    confirmSaleByWholesaler,
    updateOrderStatusByWholesaler,
    updateItemInOrderByWholesaler,
    removeItemFromOrderByWholesaler,
    addItemToOrderByWholesaler,
    overrideTotalAmountByWholesaler,
    getOrdersBetweenUsers,
};