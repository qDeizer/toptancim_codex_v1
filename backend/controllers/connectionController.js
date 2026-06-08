const db = require('../db');
const generateId = require('../utils/generateId');

// Dahili kullanıcı bağlantısı oluştur (çift rol desteği ile)
const createInternalConnection = async (req, res, next) => {
    const { target_user_identifier, relation_type } = req.body;
    const own_user_id = req.user.id;

    if (!target_user_identifier || !relation_type) {
        return res.status(400).json({ message: 'Target user identifier and relation type are required.' });
    }

    if (!['customer', 'wholesaler'].includes(relation_type)) {
        return res.status(400).json({ message: "Invalid relation_type. Must be 'customer' or 'wholesaler'." });
    }

    const client = await db.connect();

    try {
        await client.query('BEGIN');
        const targetUserResult = await client.query(
            'SELECT user_id, ad, soyad FROM users WHERE user_name = $1 OR email = $1 OR tel_no = $1',
            [target_user_identifier]
        );
        if (targetUserResult.rows.length === 0) {
            await client.query('ROLLBACK');
            return res.status(404).json({ message: 'Target user not found.' });
        }

        const target_user_id = targetUserResult.rows[0].user_id;
        const targetUser = targetUserResult.rows[0];

        if (target_user_id === own_user_id) {
            await client.query('ROLLBACK');
            return res.status(400).json({ message: 'You cannot create a connection with yourself.' });
        }

        let wholesaler_id, customer_id;
        if (relation_type === 'customer') {
            wholesaler_id = own_user_id;
            customer_id = target_user_id;
        } else {
            wholesaler_id = target_user_id;
            customer_id = own_user_id;
        }

        const existingRelation = await client.query(
            'SELECT relation_id FROM relations WHERE wholesaler_id = $1 AND customer_id = $2',
            [wholesaler_id, customer_id]
        );
        if (existingRelation.rows.length > 0) {
            await client.query('ROLLBACK');
            const relationTypeText = relation_type === 'customer' ? 'müşteri' : 'toptancı';
            return res.status(409).json({
                message: `${targetUser.ad} ${targetUser.soyad} zaten ${relationTypeText} olarak eklenmiş.`
            });
        }

        const relation_id = generateId('rel_', 12);
        const newRelation = await client.query(
            `INSERT INTO relations (relation_id, wholesaler_id, customer_id, is_wholesaler_internal, is_customer_internal)
             VALUES ($1, $2, $3, $4, $5) RETURNING *;`,
            [relation_id, wholesaler_id, customer_id, true, true]
        );
        await client.query('COMMIT');
        res.status(201).json(newRelation.rows[0]);

    } catch (error) {
        await client.query('ROLLBACK');
        next(error);
    } finally {
        client.release();
    }
};
const createExternalConnection = async (req, res, next) => {
    const { relation_type, ...userDetails } = req.body;
    const creator_id = req.user.id;
    const client = await db.connect();

    try {
        await client.query('BEGIN');
        const external_user_id = generateId('ext_', 12);
        const newUser = await client.query(
            `INSERT INTO external_users (external_user_id, creator_id, isletme_ismi, ad, soyad, tel_no, email, address_title, address, detailed_address, latitude, longitude)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12) RETURNING *;`,
            [external_user_id, creator_id, userDetails.isletme_ismi, userDetails.ad, userDetails.soyad, userDetails.tel_no, userDetails.email, userDetails.address_title, userDetails.address, userDetails.detailed_address, userDetails.latitude, userDetails.longitude]
        );
        let wholesaler_id, customer_id, is_wholesaler_internal, is_customer_internal;
        if (relation_type === 'customer') {
            wholesaler_id = creator_id;
            customer_id = external_user_id;
            is_wholesaler_internal = true;
            is_customer_internal = false;
        } else if (relation_type === 'wholesaler') {
            wholesaler_id = external_user_id;
            customer_id = creator_id;
            is_wholesaler_internal = false;
            is_customer_internal = true;
        } else {
            await client.query('ROLLBACK');
            return res.status(400).json({ message: "Invalid relation_type." });
        }

        const relation_id = generateId('rel_', 12);
        const newRelation = await client.query(
            `INSERT INTO relations (relation_id, wholesaler_id, customer_id, is_wholesaler_internal, is_customer_internal)
             VALUES ($1, $2, $3, $4, $5) RETURNING *;`,
            [relation_id, wholesaler_id, customer_id, is_wholesaler_internal, is_customer_internal]
        );
        await client.query('COMMIT');
        res.status(201).json({ external_user: newUser.rows[0], relation: newRelation.rows[0] });

    } catch (error) {
        await client.query('ROLLBACK');
        next(error);
    } finally {
        client.release();
    }
};
const listConnections = async (req, res, next) => {
    const userId = req.user.id;
    try {
        const customersQuery = `
            SELECT 'customer' AS relation_role, r.relation_id, r.is_customer_internal as is_internal,
                   CASE WHEN r.is_customer_internal THEN u.user_id ELSE eu.external_user_id END AS user_id,
                   CASE WHEN r.is_customer_internal THEN u.isletme_ismi ELSE eu.isletme_ismi END AS isletme_ismi,
                   CASE WHEN r.is_customer_internal THEN u.ad ELSE eu.ad END AS ad,
                   CASE WHEN r.is_customer_internal THEN u.soyad ELSE eu.soyad END AS soyad,
                   CASE WHEN r.is_customer_internal THEN u.profil_fotografi ELSE eu.profil_fotografi END as profil_fotografi
            FROM relations r
            LEFT JOIN users u ON r.customer_id = u.user_id AND r.is_customer_internal = TRUE
            LEFT JOIN external_users eu ON r.customer_id = eu.external_user_id AND r.is_customer_internal = FALSE
            WHERE r.wholesaler_id = $1
        `;
        const wholesalersQuery = `
            SELECT 'wholesaler' AS relation_role, r.relation_id, r.is_wholesaler_internal as is_internal,
                   CASE WHEN r.is_wholesaler_internal THEN u.user_id ELSE eu.external_user_id END AS user_id,
                   CASE WHEN r.is_wholesaler_internal THEN u.isletme_ismi ELSE eu.isletme_ismi END AS isletme_ismi,
                   CASE WHEN r.is_wholesaler_internal THEN u.ad ELSE eu.ad END AS ad,
                   CASE WHEN r.is_wholesaler_internal THEN u.soyad ELSE eu.soyad END AS soyad,
                   CASE WHEN r.is_wholesaler_internal THEN u.profil_fotografi ELSE eu.profil_fotografi END as profil_fotografi
            FROM relations r
            LEFT JOIN users u ON r.wholesaler_id = u.user_id AND r.is_wholesaler_internal = TRUE
            LEFT JOIN external_users eu ON r.wholesaler_id = eu.external_user_id AND r.is_wholesaler_internal = FALSE
            WHERE r.customer_id = $1
        `;
        const myCustomers = await db.query(customersQuery, [userId]);
        const myWholesalers = await db.query(wholesalersQuery, [userId]);
        res.json({
            customers: myCustomers.rows,
            wholesalers: myWholesalers.rows
        });
    } catch (error) {
        next(error);
    }
};
const getTransactionablePersons = async (req, res, next) => {
    const userId = req.user.id;
    try {
        const query = `
            SELECT
                CASE WHEN r.is_customer_internal THEN u.user_id ELSE eu.external_user_id END AS person_id,
                CASE WHEN r.is_customer_internal THEN u.isletme_ismi ELSE eu.isletme_ismi END AS isletme_ismi,
                CASE WHEN r.is_customer_internal THEN u.ad ELSE eu.ad END AS ad,
                CASE WHEN r.is_customer_internal THEN u.soyad ELSE eu.soyad END AS soyad,
                CASE WHEN r.is_customer_internal THEN u.profil_fotografi ELSE eu.profil_fotografi END AS profil_fotografi
            FROM relations r
            LEFT JOIN users u ON r.customer_id = u.user_id AND r.is_customer_internal = TRUE
            LEFT JOIN external_users eu ON r.customer_id = eu.external_user_id AND r.is_customer_internal = FALSE
            WHERE r.wholesaler_id = $1
            UNION
            SELECT
                CASE WHEN r.is_wholesaler_internal THEN u.user_id ELSE eu.external_user_id END AS person_id,
                CASE WHEN r.is_wholesaler_internal THEN u.isletme_ismi ELSE eu.isletme_ismi END AS isletme_ismi,
                CASE WHEN r.is_wholesaler_internal THEN u.ad ELSE eu.ad END AS ad,
                CASE WHEN r.is_wholesaler_internal THEN u.soyad ELSE eu.soyad END AS soyad,
                CASE WHEN r.is_wholesaler_internal THEN u.profil_fotografi ELSE eu.profil_fotografi END AS profil_fotografi
            FROM relations r
            LEFT JOIN users u ON r.wholesaler_id = u.user_id AND r.is_wholesaler_internal = TRUE
            LEFT JOIN external_users eu ON r.wholesaler_id = eu.external_user_id AND r.is_wholesaler_internal = FALSE
            WHERE r.customer_id = $1;
        `;
        const result = await db.query(query, [userId]);
        res.json(result.rows);
    } catch (error) {
        next(error);
    }
};

const checkUserRoles = async (req, res, next) => {
    const { target_user_identifier } = req.query;
    const own_user_id = req.user.id;

    if (!target_user_identifier) {
        return res.status(400).json({ message: 'Target user identifier is required.' });
    }

    try {
        const targetUserResult = await db.query(
            'SELECT user_id FROM users WHERE user_name = $1 OR email = $1 OR tel_no = $1',
            [target_user_identifier]
        );
        if (targetUserResult.rows.length === 0) {
            return res.status(404).json({ message: 'Target user not found.' });
        }

        const target_user_id = targetUserResult.rows[0].user_id;
        const allRelations = await db.query(
            `SELECT wholesaler_id FROM relations 
             WHERE (wholesaler_id = $1 AND customer_id = $2) OR (wholesaler_id = $2 AND customer_id = $1)`,
            [own_user_id, target_user_id]
        );
        const currentRoles = allRelations.rows.map(relation =>
            relation.wholesaler_id === own_user_id ? 'customer' : 'wholesaler'
        );
        res.json({
            current_roles: currentRoles,
            can_add_as_customer: !currentRoles.includes('customer'),
            can_add_as_wholesaler: !currentRoles.includes('wholesaler')
        });
    } catch (error) {
        next(error);
    }
};
const deleteConnection = async (req, res, next) => {
    const { id } = req.params;
    const userId = req.user.id;
    const client = await db.connect();

    try {
        await client.query('BEGIN');
        const relationRes = await client.query('SELECT * FROM relations WHERE relation_id = $1 AND (wholesaler_id = $2 OR customer_id = $2)', [id, userId]);
        if (relationRes.rowCount === 0) {
            await client.query('ROLLBACK');
            return res.status(404).json({ message: 'Relation not found or you are not part of it.' });
        }

        const relation = relationRes.rows[0];
        await client.query('DELETE FROM relations WHERE relation_id = $1', [id]);

        if (!relation.is_customer_internal && relation.wholesaler_id === userId) {
            await client.query('DELETE FROM external_users WHERE external_user_id = $1', [relation.customer_id]);
        }
        if (!relation.is_wholesaler_internal && relation.customer_id === userId) {
            await client.query('DELETE FROM external_users WHERE external_user_id = $1', [relation.wholesaler_id]);
        }

        await client.query('COMMIT');
        res.json({ message: 'Connection deleted successfully.' });

    } catch (error) {
        await client.query('ROLLBACK');
        next(error);
    } finally {
        client.release();
    }
};
const getConnectionDetails = async (req, res, next) => {
    const { id } = req.params;
    const own_user_id = req.user.id;

    try {
        const relationRes = await db.query(
            `SELECT * FROM relations WHERE relation_id = $1 AND (wholesaler_id = $2 OR customer_id = $2)`,
            [id, own_user_id]
        );
        if (relationRes.rowCount === 0) {
            return res.status(404).json({ message: 'Relation not found or you are not part of this relation.' });
        }

        const relation = relationRes.rows[0];
        const other_person_id = relation.wholesaler_id === own_user_id ? relation.customer_id : relation.wholesaler_id;
        const other_person_is_internal = relation.wholesaler_id === own_user_id ? relation.is_customer_internal : relation.is_wholesaler_internal;
        const allRelationsRes = await db.query(
            `SELECT wholesaler_id FROM relations
              WHERE (wholesaler_id = $1 AND customer_id = $2) OR (wholesaler_id = $2 AND customer_id = $1)`,
            [own_user_id, other_person_id]
        );
        const roles = allRelationsRes.rows.map(r => r.wholesaler_id === own_user_id ? 'Müşterim' : 'Toptancım');

        let personDetails;
        let can_edit = false;

        if (other_person_is_internal) {
            const result = await db.query(
                `SELECT u.user_id as id, u.ad, u.soyad, u.isletme_ismi, u.tel_no, u.email, u.profil_fotografi, 
                        a.address_title, a.address, a.detailed_address, a.latitude, a.longitude
                 FROM users u 
                 LEFT JOIN address_info a ON u.user_id = a.user_id
                 WHERE u.user_id = $1`,
                [other_person_id]
            );
            personDetails = result.rows[0];
        } else {
            const result = await db.query(
                `SELECT external_user_id as id, creator_id, ad, soyad, isletme_ismi, tel_no, email, profil_fotografi, 
                        address_title, address, detailed_address, latitude, longitude
                 FROM external_users 
                 WHERE external_user_id = $1`,
                [other_person_id]
            );
            personDetails = result.rows[0];
            if (personDetails && personDetails.creator_id === own_user_id) {
                can_edit = true;
            }
        }

        if (!personDetails) {
            return res.status(404).json({ message: 'Connection user details not found.' });
        }

        const allRelationIdsRes = await db.query(
            `SELECT relation_id FROM relations 
             WHERE (wholesaler_id = $1 AND customer_id = $2) OR (wholesaler_id = $2 AND customer_id = $1)`,
            [own_user_id, other_person_id]
        );
        const allRelationIds = allRelationIdsRes.rows.map(r => r.relation_id);

        const tagsRes = await db.query(
            `SELECT DISTINCT t.tag_id, t.name FROM tags t
             JOIN tag_assignments ta ON t.tag_id = ta.tag_id
             WHERE ta.relation_id = ANY($1::text[]) AND ta.assigner_id = $2`,
            [allRelationIds, own_user_id]
        );
        res.json({
            ...personDetails,
            roles: roles,
            scope: other_person_is_internal ? 'Dahili' : 'Harici',
            tags: tagsRes.rows,
            can_edit: can_edit,
            wholesaler_approval: relation.wholesaler_approval,
            customer_approval: relation.customer_approval,
            relation_id: relation.relation_id,
            is_wholesaler: relation.wholesaler_id === own_user_id
        });
    } catch (error) {
        next(error);
    }
};

const getRelationByUsers = async (req, res, next) => {
    const own_user_id = req.user.id;
    const { other_user_id } = req.query;

    if (!other_user_id) {
        return res.status(400).json({ message: 'Other user ID is required.' });
    }

    try {
        const result = await db.query(
            `SELECT relation_id FROM relations
             WHERE (wholesaler_id = $1 AND customer_id = $2) OR (wholesaler_id = $2 AND customer_id = $1)`,
            [own_user_id, other_user_id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ message: 'No relation found between these users.' });
        }

        const relationIds = result.rows.map(r => r.relation_id);
        res.json({ relation_ids: relationIds });

    } catch (error) {
        next(error);
    }
};

const updateExternalUser = async (req, res, next) => {
    const { id } = req.params; // external_user_id
    const creator_id = req.user.id;
    const { isletme_ismi, ad, soyad, tel_no, email, profil_fotografi, address_title, address, detailed_address, latitude, longitude } = req.body;

    try {
        const result = await db.query(
            `UPDATE external_users 
             SET 
                isletme_ismi = $1, ad = $2, soyad = $3, tel_no = $4, email = $5, profil_fotografi = $6, 
                address_title = $7, address = $8, detailed_address = $9, latitude = $10, longitude = $11, 
                updated_at = NOW()
             WHERE external_user_id = $12 AND creator_id = $13
             RETURNING *`,
            [isletme_ismi, ad, soyad, tel_no, email, profil_fotografi, address_title, address, detailed_address, latitude, longitude, id, creator_id]
        );

        if (result.rowCount === 0) {
            return res.status(404).json({ message: 'External user not found or you do not have permission to edit.' });
        }

        res.json(result.rows[0]);
    } catch (error) {
        next(error);
    }
};

const updateConnectionSettings = async (req, res, next) => {
    const { id } = req.params; // relation_id
    const userId = req.user.id;
    const { wholesaler_approval, customer_approval } = req.body;

    try {
        const relationCheck = await db.query(
            `SELECT * FROM relations WHERE relation_id = $1 AND (wholesaler_id = $2 OR customer_id = $2)`,
            [id, userId]
        );

        if (relationCheck.rowCount === 0) {
            return res.status(404).json({ message: 'Relation not found or access denied.' });
        }

        const relation = relationCheck.rows[0];
        let query = 'UPDATE relations SET ';
        const values = [];
        let valueIndex = 1;

        if (relation.wholesaler_id === userId) {
            if (wholesaler_approval !== undefined) {
                query += `wholesaler_approval = $${valueIndex} `;
                values.push(wholesaler_approval);
                valueIndex++;
            }
        } else if (relation.customer_id === userId) {
            if (customer_approval !== undefined) {
                query += `customer_approval = $${valueIndex} `;
                values.push(customer_approval);
                valueIndex++;
            }
        }

        if (values.length === 0) {
            return res.status(400).json({ message: 'No valid fields to update for your role.' });
        }

        query += `WHERE relation_id = $${valueIndex} RETURNING *`;
        values.push(id);

        const result = await db.query(query, values);
        res.json(result.rows[0]);

    } catch (error) {
        next(error);
    }
};

module.exports = {
    createInternalConnection,
    createExternalConnection,
    listConnections,
    getTransactionablePersons,
    checkUserRoles,
    deleteConnection,
    getConnectionDetails,
    getRelationByUsers,
    updateExternalUser,
    updateConnectionSettings,
};