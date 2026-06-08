const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const { 
    createTag, 
    getAllTags, 
    updateTag, 
    deleteTag 
} = require('../controllers/tagController');

/**
 * @swagger
 * tags:
 *   name: Tags
 *   description: Tag management
 */

/**
 * @swagger
 * /api/tags:
 *   get:
 *     summary: Get all tags for the logged-in user
 *     tags: [Tags]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       '200':
 *         description: A list of tags
 *       '401':
 *         description: Unauthorized
 *   post:
 *     summary: Create a new tag
 *     tags: [Tags]
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
 *               note:
 *                 type: string
 *               pricing_percentage:
 *                 type: number
 *               pricing_delta:
 *                 type: number
 *     responses:
 *       '201':
 *         description: Tag created successfully
 *       '401':
 *         description: Unauthorized
 */
router.route('/')
    .get(auth, getAllTags)
    .post(auth, createTag);

/**
 * @swagger
 * /api/tags/{id}:
 *   put:
 *     summary: Update a tag by ID
 *     tags: [Tags]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: The ID of the tag to update
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               name:
 *                 type: string
 *               note:
 *                 type: string
 *               pricing_percentage:
 *                 type: number
 *               pricing_delta:
 *                 type: number
 *     responses:
 *       '200':
 *         description: Tag updated successfully
 *       '404':
 *         description: Tag not found
 *   delete:
 *     summary: Delete a tag by ID
 *     tags: [Tags]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *         description: The ID of the tag to delete
 *     responses:
 *       '200':
 *         description: Tag deleted successfully
 *       '404':
 *         description: Tag not found
 */
router.route('/:id')
    .put(auth, updateTag)
    .delete(auth, deleteTag);

module.exports = router;