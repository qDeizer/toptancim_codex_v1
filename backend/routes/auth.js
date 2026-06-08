const express = require('express');
const router = express.Router();
const { register, login } = require('../controllers/authController');

/**
 * @swagger
 * tags:
 *   name: Auth
 *   description: Authentication endpoints
 */

/**
 * @swagger
 * /api/auth/register:
 *   post:
 *     summary: Register a new user
 *     tags: [Auth]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               user_name:
 *                 type: string
 *               isletme_ismi:
 *                 type: string
 *               ad:
 *                 type: string
 *               soyad:
 *                 type: string
 *               tel_no:
 *                 type: string
 *               email:
 *                 type: string
 *               password:
 *                 type: string
 *               hakkinda:
 *                 type: string
 *               address_info:
 *                 type: object
 *                 properties:
 *                   address:
 *                     type: string
 *                   delivery_address:
 *                     type: string
 *                   detailed_address:
 *                     type: string
 *                   latitude:
 *                     type: number
 *                   longitude:
 *                     type: number
 *                   city:
 *                     type: string
 *                   district:
 *                     type: string
 *                   postal_code:
 *                     type: string
 *     responses:
 *       '201':
 *         description: User created
 *       '409':
 *         description: Conflict - User already exists
 */
router.post('/register', register);

/**
 * @swagger
 * /api/auth/login:
 *   post:
 *     summary: Login user
 *     tags: [Auth]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               loginIdentifier:
 *                 type: string
 *                 description: Email, phone number, or username
 *               password:
 *                 type: string
 *     responses:
 *       '200':
 *         description: Login successful
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 token:
 *                   type: string
 *       '401':
 *         description: Invalid credentials
 *       '404':
 *         description: User not found
 */
router.post('/login', login);

module.exports = router;