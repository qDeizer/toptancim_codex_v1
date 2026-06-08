const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const {
    addItemToCart,
    getMyCarts,
    updateCartItem,
    removeCartItem,
    placeOrder,
} = require('../controllers/customerCartController');
const {
    getWholesalerOrders,
    confirmSaleByWholesaler,
    updateOrderStatusByWholesaler,
    updateItemInOrderByWholesaler,
    removeItemFromOrderByWholesaler,
    addItemToOrderByWholesaler,
    overrideTotalAmountByWholesaler,
    bulkUpdateOrderByWholesaler,
    getOrdersBetweenUsers
} = require('../controllers/wholesalerOrderController');

/**
 * @swagger
 * tags:
 * name: Cart
 * description: Shopping cart and order management
 */

// =================================================================
// MÜŞTERİ ROTALARI (CUSTOMER ROUTES)
// =================================================================

router.get('/', auth, getMyCarts);
router.post('/items', auth, addItemToCart);
router.put('/items/:cart_item_id', auth, updateCartItem);
router.delete('/items/:cart_item_id', auth, removeCartItem);
router.post('/:cartId/place-order', auth, placeOrder);

// =================================================================
// TOPTANCI ROTALARI (WHOLESALER ROUTES)
// =================================================================

router.get('/wholesaler-orders', auth, getWholesalerOrders);
router.post('/:cartId/confirm-sale', auth, confirmSaleByWholesaler);
router.put('/:cartId/status', auth, updateOrderStatusByWholesaler);
// Sipariş Düzenleme Rotaları
router.put('/wholesaler/:cartId/items/:cartItemId', auth, updateItemInOrderByWholesaler);
router.delete('/wholesaler/:cartId/items/:cartItemId', auth, removeItemFromOrderByWholesaler);
router.post('/wholesaler/:cartId/items', auth, addItemToOrderByWholesaler);
router.put('/wholesaler/:cartId/override-total', auth, overrideTotalAmountByWholesaler);


// =================================================================
// ORTAK ROTALAR (COMMON ROUTES)
// =================================================================
router.get('/between/:personId', auth, getOrdersBetweenUsers);


module.exports = router;