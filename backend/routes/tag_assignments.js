const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const {
    getTagsForConnection,
    getConnectionsForTag,
    syncAssignmentsForConnection
} = require('../controllers/tagAssignmentController');

/**
 * @swagger
 * tags:
 *   name: Tag Assignments
 *   description: API to manage assignments between tags and connections
 */

/**
 * @swagger
 * /api/assignments/connection/{relationId}:
 *   get:
 *     summary: Get all tags assigned to a specific connection
 *     tags: [Tag Assignments]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: relationId
 *         required: true
 *         schema:
 *           type: string
 *         description: The ID of the connection (relation)
 *     responses:
 *       '200':
 *         description: A list of tags assigned to the connection
 *       '401':
 *         description: Unauthorized
 */
router.get('/connection/:relationId', auth, getTagsForConnection);

/**
 * @swagger
 * /api/assignments/tag/{tagId}:
 *   get:
 *     summary: Get all connections assigned to a specific tag
 *     tags: [Tag Assignments]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: tagId
 *         required: true
 *         schema:
 *           type: string
 *         description: The ID of the tag
 *     responses:
 *       '200':
 *         description: A list of connections (users) assigned to the tag
 *       '401':
 *         description: Unauthorized
 */
router.get('/tag/:tagId', auth, getConnectionsForTag);

/**
 * @swagger
 * /api/assignments/connection/{relationId}:
 *   post:
 *     summary: Sync (set/update) all tags for a specific connection
 *     tags: [Tag Assignments]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: relationId
 *         required: true
 *         schema:
 *           type: string
 *         description: The ID of the connection to assign tags to
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               tag_ids:
 *                 type: array
 *                 items:
 *                   type: string
 *                 description: An array of tag IDs to be assigned. Existing assignments will be replaced.
 *     responses:
 *       '200':
 *         description: Tags successfully synchronized for the connection
 *       '400':
 *         description: Bad request (e.g., tag_ids is not an array)
 *       '401':
 *         description: Unauthorized
 */
router.post('/connection/:relationId', auth, syncAssignmentsForConnection);

module.exports = router;