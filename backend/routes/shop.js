const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const { getShopProducts } = require('../controllers/shopController');

/**
 * @swagger
 * tags:
 *   name: Shop
 *   description: Customer shopping experience
 */

/**
 * @swagger
 * /api/shop/products:
 *   get:
 *     summary: Get products from my wholesalers with custom pricing
 *     description: Fetches active products from all wholesalers the current user is a customer of. Applies pricing adjustments based on tags.
 *     tags: [Shop]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: wholesaler_id
 *         schema:
 *           type: string
 *         required: false
 *         description: Optional. Filter products by a specific wholesaler ID.
 *     responses:
 *       200:
 *         description: A list of products with customer-specific prices.
 *       401:
 *         description: Unauthorized.
 */
router.get('/products', auth, getShopProducts);

module.exports = router;