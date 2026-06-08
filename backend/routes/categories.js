const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const { 
    createCategory, 
    getAllCategories, 
    deleteCategory 
} = require('../controllers/categoryController');

/**
 * @swagger
 * tags:
 *   name: Categories
 *   description: Category management
 */

/**
 * @swagger
 * /api/categories:
 *   get:
 *     summary: Get all categories for the logged-in user
 *     tags: [Categories]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       '200':
 *         description: A list of categories
 *       '401':
 *         description: Unauthorized
 *   post:
 *     summary: Create a new category
 *     tags: [Categories]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               name:
 *                 type: string
 *     responses:
 *       '201':
 *         description: Category created successfully
 *       '400':
 *         description: Bad request (e.g., name is missing)
 *       '401':
 *         description: Unauthorized
 *       '409':
 *         description: Conflict - Category with this name already exists
 */
router.route('/')
    .get(auth, getAllCategories)
    .post(auth, createCategory);

/**
 * @swagger
 * /api/categories/{id}:
 *   delete:
 *     summary: Delete a category by ID
 *     tags: [Categories]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: The ID of the category to delete
 *     responses:
 *       '200':
 *         description: Category deleted successfully
 *       '401':
 *         description: Unauthorized
 *       '404':
 *         description: Category not found
 */
router.delete('/:id', auth, deleteCategory);

module.exports = router;