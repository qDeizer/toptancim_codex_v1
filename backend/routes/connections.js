const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const {
    createInternalConnection,
    createExternalConnection,
    listConnections,
    getTransactionablePersons,
    checkUserRoles,
    deleteConnection,
    getConnectionDetails,
    getRelationByUsers,
    updateExternalUser
} = require('../controllers/connectionController');
/**
 * @swagger
 * tags:
 * name: Connections
 * description: API to manage user connections
 */

/**
 * @swagger
 * /api/connections:
 * get:
 * summary: List all connections (customers and wholesalers)
 * tags: [Connections]
 * security:
 * - bearerAuth: []
 * responses:
 * '200':
 * description: A list of the user's connections.
 * '401':
 * description: Unauthorized.
 */
router.get('/', auth, listConnections);

/**
 * @swagger
 * /api/connections/transactionable:
 * get:
 * summary: Get all unique persons (customers and wholesalers) for financial transactions
 * tags: [Connections]
 * security:
 * - bearerAuth: []
 * responses:
 * '200':
 * description: A unique list of persons the user has a relationship with.
 * '401':
 * description: Unauthorized.
 */
router.get('/transactionable', auth, getTransactionablePersons);

/**
 * @swagger
 * /api/connections/by-users:
 * get:
 * summary: Find relation ID(s) between two users
 * tags: [Connections]
 * security:
 * - bearerAuth: []
 * parameters:
 * - in: query
 * name: other_user_id
 * schema:
 * type: string
 * required: true
 * description: The ID of the other user in the relation
 * responses:
 * '200':
 * description: A list of relation IDs found
 * '404':
 * description: No relation found
 */
router.get('/by-users', auth, getRelationByUsers);

/**
 * @swagger
 * /api/connections/check-roles:
 * get:
 * summary: Check existing roles for a specific user
 * tags: [Connections]
 * security:
 * - bearerAuth: []
 * parameters:
 * - in: query
 * name: target_user_identifier
 * schema:
 * type: string
 * required: true
 * description: Username, email, or phone of the target user
 * responses:
 * '200':
 * description: User roles information
 * '404':
 * description: Target user not found
 */
router.get('/check-roles', auth, checkUserRoles);
/**
 * @swagger
 * /api/connections/internal:
 * post:
 * summary: Create a connection with an existing internal user
 * tags: [Connections]
 * security:
 * - bearerAuth: []
 * requestBody:
 * required: true
 * content:
 * application/json:
 * schema:
 * type: object
 * properties:
 * target_user_identifier:
 * type: string
 * description: Username, email, or phone of the target user
 * relation_type:
 * type: string
 * enum: [customer, wholesaler]
 * responses:
 * '201':
 * description: Connection created successfully.
 * '404':
 * description: Target user not found.
 * '409':
 * description: Connection already exists.
 */
router.post('/internal', auth, createInternalConnection);
/**
 * @swagger
 * /api/connections/external:
 * post:
 * summary: Add a new external user and create a connection
 * tags: [Connections]
 * security:
 * - bearerAuth: []
 * requestBody:
 * required: true
 * content:
 * application/json:
 * schema:
 * type: object
 * properties:
 * relation_type:
 * type: string
 * enum: [customer, wholesaler]
 * isletme_ismi:
 * type: string
 * ad:
 * type: string
 * soyad:
 * type: string
 * tel_no:
 * type: string
 * email:
 * type: string
 * adres:
 * type: string
 * responses:
 * '201':
 * description: External user and connection created successfully.
 * '401':
 * description: Unauthorized.
 */
router.post('/external', auth, createExternalConnection);

router.get('/:id/details', auth, getConnectionDetails);
router.put('/:id/settings', auth, require('../controllers/connectionController').updateConnectionSettings);
router.put('/external/:id', auth, updateExternalUser);

/**
 * @swagger
 * /api/connections/{id}:
 * delete:
 * summary: Delete a connection by its relation_id
 * tags: [Connections]
 * security:
 * - bearerAuth: []
 * parameters:
 * - in: path
 * name: id
 * schema:
 * type: string
 * required: true
 * description: The ID of the relation to delete.
 * responses:
 * '200':
 * description: Connection deleted successfully.
 * '404':
 * description: Not Found.
 */
router.delete('/:id', auth, deleteConnection);

module.exports = router;