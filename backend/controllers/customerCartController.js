const db = require('../db');
const generateId = require('../utils/generateId');
const { getIO } = require('../socket');
const { recalculateCartTotal, synchronizeCart, findOrCreateCart } = require('../utils/cartUtils');
const logger = require('../utils/logger');

const resolveCustomerContext = async (client, requesterId, requestedCustomerId, wholesalerIdForAction = requesterId) => {
    if (!requestedCustomerId || requestedCustomerId === requesterId) {
        return { actingCustomerId: requesterId, isProxyAction: false };
    }

    if (wholesalerIdForAction !== requesterId) {
        return {
            error: {
                status: 403,
                message: 'Sadece kendi urunlerinizle musteri adina siparis olusturabilirsiniz.'
            }
        };
    }

    const relationResult = await client.query(
        `SELECT 1
         FROM relations
         WHERE wholesaler_id = $1 AND customer_id = $2 AND is_customer_internal = TRUE`,
        [requesterId, requestedCustomerId]
    );

    if (relationResult.rowCount === 0) {
        return {
            error: {
                status: 403,
                message: 'Secilen musteri icin siparis olusturma yetkiniz yok.'
            }
        };
    }

    return { actingCustomerId: requestedCustomerId, isProxyAction: true };
};


const addItemToCart = async (req, res, next) => {
    const { variant_id, quantity, wholesaler_id, customer_id: requestedCustomerId } = req.body;
    const requester_id = req.user.id;
    const client = await db.connect();

    try {
        await client.query('BEGIN');
        const contextResult = await resolveCustomerContext(
            client,
            requester_id,
            requestedCustomerId,
            wholesaler_id
        );
        if (contextResult.error) {
            await client.query('ROLLBACK');
            return res.status(contextResult.error.status).json({ message: contextResult.error.message });
        }

        const customer_id = contextResult.actingCustomerId;
        const variantResult = await client.query(
            `SELECT v.price, p.is_active as product_active, v.is_active as variant_active, v.stock_quantity, v.sold_quantity
             FROM product_variants v
             JOIN products p ON v.product_id = p.product_id
             WHERE v.variant_id = $1 AND p.creator_id = $2`,
            [variant_id, wholesaler_id]
        );

        if (variantResult.rows.length === 0) {
            await client.query('ROLLBACK');
            logger.warn('addItemToCart: Variant not found or invalid owner', { variant_id, wholesaler_id });
            return res.status(404).json({ message: "Ürün bulunamadı veya bu toptancıya ait değil." });
        }

        const variant = variantResult.rows[0];
        if (!variant.product_active || !variant.variant_active) {
            await client.query('ROLLBACK');
            return res.status(400).json({ message: "Bu ürün şu anda satışta değil." });
        }

        const availableStock = variant.stock_quantity - variant.sold_quantity;
        const cart = await findOrCreateCart(client, customer_id, wholesaler_id);
        const existingItemResult = await client.query(
            "SELECT quantity FROM cart_items WHERE cart_id = $1 AND variant_id = $2",
            [cart.cart_id, variant_id]
        );
        const currentCartQuantity = existingItemResult.rows.length > 0 ? existingItemResult.rows[0].quantity : 0;

        if (quantity + currentCartQuantity > availableStock) {
            await client.query('ROLLBACK');
            const maxAddable = availableStock - currentCartQuantity;
            return res.status(400).json({
                message: `Stok yetersiz. Bu üründen en fazla ${maxAddable > 0 ? maxAddable : 0} adet daha ekleyebilirsiniz.`
            });
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
        const finalPrice = variant.price * (1 + (parseFloat(total_percentage) / 100)) + parseFloat(total_delta);

        if (existingItemResult.rows.length > 0) {
            await client.query(
                "UPDATE cart_items SET quantity = quantity + $1 WHERE cart_id = $2 AND variant_id = $3",
                [quantity, cart.cart_id, variant_id]
            );
        } else {
            const cart_item_id = generateId('item_', 16);
            await client.query(
                "INSERT INTO cart_items (cart_item_id, cart_id, variant_id, quantity, current_price) VALUES ($1, $2, $3, $4, $5)",
                [cart_item_id, cart.cart_id, variant_id, quantity, finalPrice]
            );
        }

        await recalculateCartTotal(client, cart.cart_id);
        await client.query('COMMIT');

        try {
            getIO().to(`user_${customer_id}`).emit('cart_updated', { action: 'add_item', cartId: cart.cart_id });
            logger.debug('Cart update event emitted', { customer_id, action: 'add_item' });
        } catch (err) {
            logger.error('Socket emit error', err);
        }

        logger.info('addItemToCart success');
        res.status(200).json({ message: 'Ürün sepete eklendi.' });

    } catch (error) {
        await client.query('ROLLBACK');
        next(error);
    } finally {
        client.release();
    }
};

const getMyCarts = async (req, res, next) => {
    const requester_id = req.user.id;
    const requestedCustomerId = req.query.customer_id;
    const client = await db.connect();
    try {
        await client.query('BEGIN');
        const contextResult = await resolveCustomerContext(
            client,
            requester_id,
            requestedCustomerId
        );
        if (contextResult.error) {
            await client.query('ROLLBACK');
            return res.status(contextResult.error.status).json({ message: contextResult.error.message });
        }

        const customer_id = contextResult.actingCustomerId;
        const userCartsResult = await client.query(
            contextResult.isProxyAction
                ? "SELECT cart_id FROM carts WHERE customer_id = $1 AND wholesaler_id = $2 AND status IN ('active', 'ordered')"
                : "SELECT cart_id FROM carts WHERE customer_id = $1 AND status IN ('active', 'ordered')",
            contextResult.isProxyAction ? [customer_id, requester_id] : [customer_id]
        );

        for (const userCart of userCartsResult.rows) {
            await synchronizeCart(client, userCart.cart_id);
        }

        const query = `
            SELECT
                c.cart_id, c.customer_id, c.wholesaler_id, c.status, c.total_amount, c.updated_at, c.ordered_at,
                u.isletme_ismi as wholesaler_name,
                u.profil_fotografi as wholesaler_photo,
                cu.isletme_ismi as customer_name,
                cu.profil_fotografi as customer_photo,
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
                                p.name as product_name
                            FROM cart_items ci
                            JOIN product_variants pv ON ci.variant_id = pv.variant_id
                            JOIN products p ON pv.product_id = p.product_id
                            WHERE ci.cart_id = c.cart_id
                        ) as item_obj
                    ),
                     '[]'::json
                ) as items
            FROM carts c
            JOIN users u ON c.wholesaler_id = u.user_id
            JOIN users cu ON c.customer_id = cu.user_id
            WHERE c.customer_id = $1
            ${contextResult.isProxyAction ? 'AND c.wholesaler_id = $2' : ''}
            GROUP BY c.cart_id, c.customer_id, u.isletme_ismi, u.profil_fotografi, cu.isletme_ismi, cu.profil_fotografi
            ORDER BY
                CASE c.status
                    WHEN 'active' THEN 1
                    WHEN 'ordered' THEN 2
                    WHEN 'preparing' THEN 3
                    WHEN 'shipped' THEN 4
                    WHEN 'delivered' THEN 5
                    WHEN 'cancelled' THEN 6
                    ELSE 7
                END,
                c.updated_at DESC;
        `;
        const result = await client.query(
            query,
            contextResult.isProxyAction ? [customer_id, requester_id] : [customer_id]
        );
        await client.query('COMMIT');
        res.json(result.rows);
    } catch (error) {
        await client.query('ROLLBACK');
        next(error);
    } finally {
        client.release();
    }
};

const updateCartItem = async (req, res, next) => {
    const { cart_item_id } = req.params;
    const { quantity } = req.body;
    const requester_id = req.user.id;
    const requestedCustomerId = req.query.customer_id;

    if (!quantity || quantity < 1) {
        return res.status(400).json({ message: 'Geçersiz miktar. Miktar en az 1 olmalıdır.' });
    }

    const client = await db.connect();
    try {
        await client.query('BEGIN');
        const contextResult = await resolveCustomerContext(
            client,
            requester_id,
            requestedCustomerId
        );
        if (contextResult.error) {
            await client.query('ROLLBACK');
            return res.status(contextResult.error.status).json({ message: contextResult.error.message });
        }

        const customer_id = contextResult.actingCustomerId;
        const itemResult = await client.query(
            `SELECT ci.cart_id, ci.variant_id, c.status 
             FROM cart_items ci 
             JOIN carts c ON ci.cart_id = c.cart_id
             WHERE ci.cart_item_id = $1 AND c.customer_id = $2 ${contextResult.isProxyAction ? 'AND c.wholesaler_id = $3' : ''}`,
            contextResult.isProxyAction ? [cart_item_id, customer_id, requester_id] : [cart_item_id, customer_id]
        );

        if (itemResult.rows.length === 0) {
            await client.query('ROLLBACK');
            return res.status(404).json({ message: 'Sepet öğesi bulunamadı veya yetkiniz yok.' });
        }

        const cart = itemResult.rows[0];
        if (cart.status !== 'active') {
            await client.query('ROLLBACK');
            return res.status(400).json({ message: 'Sadece aktif sepetler düzenlenebilir.' });
        }

        const variantResult = await client.query(
            `SELECT stock_quantity, sold_quantity FROM product_variants WHERE variant_id = $1`, [cart.variant_id]
        );
        const availableStock = variantResult.rows[0].stock_quantity - variantResult.rows[0].sold_quantity;

        if (quantity > availableStock) {
            await client.query('ROLLBACK');
            return res.status(400).json({ message: `Stok yetersiz. En fazla ${availableStock} adet ekleyebilirsiniz.` });
        }

        await client.query(
            "UPDATE cart_items SET quantity = $1 WHERE cart_item_id = $2",
            [quantity, cart_item_id]
        );

        const newTotal = await recalculateCartTotal(client, cart.cart_id);

        await client.query('COMMIT');

        try {
            getIO().to(`user_${customer_id}`).emit('cart_updated', { action: 'update_item', cartId: cart.cart_id });
        } catch (err) {
            console.error('Socket emit error:', err);
        }

        res.status(200).json({ message: 'Miktar güncellendi.', newTotalAmount: newTotal });

    } catch (error) {
        await client.query('ROLLBACK');
        next(error);
    } finally {
        client.release();
    }
};

const removeCartItem = async (req, res, next) => {
    const { cart_item_id } = req.params;
    const requester_id = req.user.id;
    const requestedCustomerId = req.query.customer_id;
    const client = await db.connect();

    try {
        await client.query('BEGIN');
        const contextResult = await resolveCustomerContext(
            client,
            requester_id,
            requestedCustomerId
        );
        if (contextResult.error) {
            await client.query('ROLLBACK');
            return res.status(contextResult.error.status).json({ message: contextResult.error.message });
        }

        const customer_id = contextResult.actingCustomerId;
        const itemResult = await client.query(
            `SELECT ci.cart_id, c.status
             FROM cart_items ci
             JOIN carts c ON ci.cart_id = c.cart_id
             WHERE ci.cart_item_id = $1 AND c.customer_id = $2 ${contextResult.isProxyAction ? 'AND c.wholesaler_id = $3' : ''}`,
            contextResult.isProxyAction ? [cart_item_id, customer_id, requester_id] : [cart_item_id, customer_id]
        );

        if (itemResult.rows.length === 0) {
            await client.query('ROLLBACK');
            return res.status(404).json({ message: 'Sepet öğesi bulunamadı veya yetkiniz yok.' });
        }

        const cart = itemResult.rows[0];
        if (cart.status !== 'active') {
            await client.query('ROLLBACK');
            return res.status(400).json({ message: 'Sadece aktif sepetler düzenlenebilir.' });
        }

        await client.query("DELETE FROM cart_items WHERE cart_item_id = $1", [cart_item_id]);

        const newTotal = await recalculateCartTotal(client, cart.cart_id);

        await client.query('COMMIT');

        try {
            getIO().to(`user_${customer_id}`).emit('cart_updated', { action: 'remove_item', cartId: cart.cart_id });
            logger.debug('Cart update event emitted for remove', { customer_id });
        } catch (err) {
            logger.error('Socket emit error:', err);
        }

        res.status(200).json({ message: 'Ürün sepetten kaldırıldı.', newTotalAmount: newTotal });

    } catch (error) {
        await client.query('ROLLBACK');
        next(error);
    } finally {
        client.release();
    }
};

const placeOrder = async (req, res, next) => {
    const { cartId } = req.params;
    const requester_id = req.user.id;
    const requestedCustomerId = req.query.customer_id;
    const client = await db.connect();
    try {
        await client.query('BEGIN');
        const contextResult = await resolveCustomerContext(
            client,
            requester_id,
            requestedCustomerId
        );
        if (contextResult.error) {
            await client.query('ROLLBACK');
            return res.status(contextResult.error.status).json({ message: contextResult.error.message });
        }

        const customer_id = contextResult.actingCustomerId;
        const syncResult = await synchronizeCart(client, cartId);

        const cartToOrderResult = await client.query(
            contextResult.isProxyAction
                ? "SELECT * FROM carts WHERE cart_id = $1 AND customer_id = $2 AND wholesaler_id = $3 AND status = 'active'"
                : "SELECT * FROM carts WHERE cart_id = $1 AND customer_id = $2 AND status = 'active'",
            contextResult.isProxyAction ? [cartId, customer_id, requester_id] : [cartId, customer_id]
        );

        if (cartToOrderResult.rows.length === 0) {
            await client.query('ROLLBACK');
            return res.status(404).json({ message: 'Aktif sepet bulunamadı veya size ait değil.' });
        }

        const cartToOrder = cartToOrderResult.rows[0];
        const wholesaler_id = cartToOrder.wholesaler_id;

        const existingOrderedCartResult = await client.query(
            "SELECT * FROM carts WHERE customer_id = $1 AND wholesaler_id = $2 AND status = 'ordered'",
            [customer_id, wholesaler_id]
        );

        if (existingOrderedCartResult.rows.length > 0) {
            const existingOrderedCart = existingOrderedCartResult.rows[0];
            const cartItemsResult = await client.query(
                "SELECT * FROM cart_items WHERE cart_id = $1",
                [cartId]
            );

            for (const item of cartItemsResult.rows) {
                const upsertQuery = `
                    INSERT INTO cart_items (cart_item_id, cart_id, variant_id, quantity, current_price)
                    VALUES ($1, $2, $3, $4, $5)
                    ON CONFLICT (cart_id, variant_id) DO UPDATE 
                    SET quantity = cart_items.quantity + EXCLUDED.quantity;
                `;
                const new_cart_item_id = generateId('item_', 16);
                await client.query(upsertQuery, [
                    new_cart_item_id,
                    existingOrderedCart.cart_id,
                    item.variant_id,
                    item.quantity,
                    item.current_price
                ]);
            }

            await recalculateCartTotal(client, existingOrderedCart.cart_id);

            await client.query("DELETE FROM cart_items WHERE cart_id = $1", [cartId]);
            await client.query("DELETE FROM carts WHERE cart_id = $1", [cartId]);

            await client.query('COMMIT');
            const finalCartResult = await db.query("SELECT * FROM carts WHERE cart_id = $1", [existingOrderedCart.cart_id]);
            res.json({
                message: 'Sipariş mevcut siparişinizle birleştirildi.',
                cart: finalCartResult.rows[0],
                merged: true,
                syncChanges: syncResult.changes
            });
            try {
                getIO().to(`user_${customer_id}`).emit('cart_updated', { action: 'place_order_merged', cartId: existingOrderedCart.cart_id });
            } catch (err) {
                console.error('Socket emit error:', err);
            }
        } else {
            const result = await client.query(
                "UPDATE carts SET status = 'ordered', ordered_at = NOW() WHERE cart_id = $1 RETURNING *",
                [cartId]
            );
            await client.query('COMMIT');
            res.json({
                message: 'Sipariş başarıyla oluşturuldu.',
                cart: result.rows[0],
                merged: false,
                syncChanges: syncResult.changes
            });
            try {
                getIO().to(`user_${customer_id}`).emit('cart_updated', { action: 'place_order', cartId: cartId });
            } catch (err) {
                console.error('Socket emit error:', err);
            }
        }

    } catch (error) {
        await client.query('ROLLBACK');
        next(error);
    } finally {
        client.release();
    }
};

module.exports = {
    addItemToCart,
    getMyCarts,
    updateCartItem,
    removeCartItem,
    placeOrder,
};
