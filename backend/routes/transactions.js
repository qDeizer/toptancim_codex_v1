const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const {
    createTransaction,
    getTransactions,
    getTransactionSummary,
    deleteTransaction,
    respondTransaction,
    cancelTransaction,
    requestCancelTransaction,
    respondCancelRequest
} = require('../controllers/transactionController');

/**
 * @swagger
 * tags:
 * name: Transactions
 * description: Financial transaction management
 */

router.get('/summary', auth, getTransactionSummary);
router.post('/', auth, createTransaction);
router.get('/', auth, getTransactions);
router.delete('/:id', auth, deleteTransaction);
router.post('/:id/respond', auth, respondTransaction);
router.post('/:id/cancel', auth, cancelTransaction);
router.post('/:id/cancel-request', auth, requestCancelTransaction);
router.post('/:id/cancel-respond', auth, respondCancelRequest);

/**
 * @swagger
 * tags:
 *   name: Transactions
 *   description: Financial transaction management
 */

/**
 * @swagger
 * /api/transactions:
 *   post:
 *     summary: Create a new financial transaction
 *     tags: [Transactions]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               frontend_type:
 *                 type: string
 *                 enum: [satis, tahsilat, alis, odeme, gelir, gider]
 *               person_id:
 *                 type: string
 *               amount:
 *                 type: number
 *               currency:
 *                 type: string
 *               payment_method:
 *                 type: string
 *               description:
 *                 type: string
 *               transaction_date:
 *                 type: string
 *                 format: date-time
 *     responses:
 *       '201':
 *         description: Transaction created successfully
 *       '400':
 *         description: Bad request
 */
/**
 * @swagger
 * /api/transactions/summary:
 *   get:
 *     summary: Get a financial summary for the logged-in user
 *     tags: [Transactions]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       '200':
 *         description: A summary of financial metrics.
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 total_receivable:
 *                   type: number
 *                 total_debt:
 *                   type: number
 *                 total_revenue:
 *                   type: number
 *                 total_expense:
 *                   type: number
 *                 net_cash:
 *                   type: number
 *                 current_balance:
 *                   type: number
 *       '401':
 *         description: Unauthorized.
 */
router.get('/summary', auth, getTransactionSummary);

router.post('/', auth, createTransaction);

/**
 * @swagger
 * /api/transactions:
 *   get:
 *     summary: Get all financial transactions for the user
 *     tags: [Transactions]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       '200':
 *         description: A list of financial transactions.
 *       '401':
 *         description: Unauthorized.
 */
router.get('/', auth, getTransactions);





module.exports = router;