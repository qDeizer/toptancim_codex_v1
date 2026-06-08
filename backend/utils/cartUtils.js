const db = require('../db');
const generateId = require('./generateId');

const recalculateCartTotal = async (client, cart_id) => {
    const totalResult = await client.query(
        "SELECT SUM(quantity * current_price) as total FROM cart_items WHERE cart_id = $1",
        [cart_id]
    );
    const totalAmount = totalResult.rows[0].total || 0;
    await client.query(
        "UPDATE carts SET total_amount = $1, updated_at = NOW() WHERE cart_id = $2",
        [totalAmount, cart_id]
    );
    return totalAmount;
};

const synchronizeCart = async (client, cart_id) => {
    const cartResult = await client.query("SELECT * FROM carts WHERE cart_id = $1", [cart_id]);
    if (cartResult.rows.length === 0) {
        return { updated: false, changes: [] };
    }

    const cart = cartResult.rows[0];
    const { customer_id, wholesaler_id, status } = cart;
    if (!['active', 'ordered'].includes(status)) {
        return { updated: false, changes: [] };
    }

    const itemsResult = await client.query("SELECT * FROM cart_items WHERE cart_id = $1", [cart_id]);
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

    const changes = [];
    let needsRecalculation = false;

    for (const item of itemsResult.rows) {
        const variantResult = await client.query(
            `SELECT v.price, p.is_active as product_active, v.is_active as variant_active, v.stock_quantity, v.sold_quantity, pv.name as variant_name
             FROM product_variants v
             JOIN products p ON v.product_id = p.product_id
             JOIN product_variants pv ON v.variant_id = pv.variant_id
             WHERE v.variant_id = $1 AND p.creator_id = $2`,
            [item.variant_id, wholesaler_id]
        );
        if (variantResult.rows.length === 0) {
            await client.query("DELETE FROM cart_items WHERE cart_item_id = $1", [item.cart_item_id]);
            changes.push(`Bir ürün (ID: ${item.variant_id}) artık mevcut olmadığı için sepetten kaldırıldı.`);
            needsRecalculation = true;
            continue;
        }

        const variant = variantResult.rows[0];
        if (!variant.product_active || !variant.variant_active) {
            await client.query("DELETE FROM cart_items WHERE cart_item_id = $1", [item.cart_item_id]);
            changes.push(`'${variant.variant_name}' ürünü satıştan kaldırıldığı için sepetten çıkarıldı.`);
            needsRecalculation = true;
            continue;
        }

        const basePrice = parseFloat(variant.price);
        const newPrice = basePrice * (1 + (parseFloat(total_percentage) / 100)) + parseFloat(total_delta);
        const currentPrice = parseFloat(item.current_price);
        if (newPrice.toFixed(2) !== currentPrice.toFixed(2)) {
            await client.query(
                "UPDATE cart_items SET current_price = $1 WHERE cart_item_id = $2",
                [newPrice.toFixed(2), item.cart_item_id]
            );
            changes.push(`'${variant.variant_name}' ürününün fiyatı ${currentPrice.toFixed(2)} ₺'den ${newPrice.toFixed(2)} ₺'ye güncellendi.`);
            needsRecalculation = true;
        }
        
        const availableStock = variant.stock_quantity - variant.sold_quantity;
        if (item.quantity > availableStock) {
            if (availableStock <= 0) {
                 await client.query("DELETE FROM cart_items WHERE cart_item_id = $1", [item.cart_item_id]);
                 changes.push(`'${variant.variant_name}' ürününün stoğu tükendiği için sepetten kaldırıldı.`);
            } else {
                await client.query(
                    "UPDATE cart_items SET quantity = $1 WHERE cart_item_id = $2",
                    [availableStock, item.cart_item_id]
                );
                changes.push(`'${variant.variant_name}' ürününün stoğu azaldığı için sepet miktarı ${item.quantity}'den ${availableStock} adede düşürüldü.`);
            }
            needsRecalculation = true;
        }
    }

    const verificationResult = await client.query(
        "SELECT SUM(quantity * current_price) as total FROM cart_items WHERE cart_id = $1",
        [cart_id]
    );
    const verifiedTotal = parseFloat(verificationResult.rows[0].total || 0);
    const storedTotal = parseFloat(cart.total_amount);

    if (verifiedTotal.toFixed(2) !== storedTotal.toFixed(2)) {
        await client.query(
            "UPDATE carts SET total_amount = $1, updated_at = NOW() WHERE cart_id = $2",
            [verifiedTotal.toFixed(2), cart_id]
        );
        if (!needsRecalculation) {
             changes.push(`Sepet toplam tutarı, ürünlerdeki değişiklikler nedeniyle güncellendi.`);
        }
        needsRecalculation = true;
    }

    return { updated: needsRecalculation, changes };
};

const findOrCreateCart = async (client, customer_id, wholesaler_id) => {
    let cartResult = await client.query(
        "SELECT * FROM carts WHERE customer_id = $1 AND wholesaler_id = $2 AND status = 'active'",
        [customer_id, wholesaler_id]
    );

    if (cartResult.rows.length > 0) {
        return cartResult.rows[0];
    }

    const cart_id = generateId('cart_', 16);
    cartResult = await client.query(
        "INSERT INTO carts (cart_id, customer_id, wholesaler_id) VALUES ($1, $2, $3) RETURNING *",
        [cart_id, customer_id, wholesaler_id]
    );
    return cartResult.rows[0];
};

module.exports = {
    recalculateCartTotal,
    synchronizeCart,
    findOrCreateCart
};