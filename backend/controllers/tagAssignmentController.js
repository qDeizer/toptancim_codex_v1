const db = require('../db');
const generateId = require('../utils/generateId');

// Bir bağlantıya atanmış etiketleri getir
const getTagsForConnection = async (req, res) => {
    const { relationId } = req.params;
    const assigner_id = req.user.id;

    try {
        const query = `
            SELECT t.tag_id, t.name, t.note, t.pricing_percentage, t.pricing_delta 
            FROM tags t
            JOIN tag_assignments ta ON t.tag_id = ta.tag_id
            WHERE ta.relation_id = $1 AND ta.assigner_id = $2
            ORDER BY t.name ASC;
        `;
        const result = await db.query(query, [relationId, assigner_id]);
        res.json(result.rows);
    } catch (error) {
        console.error('Error getting tags for connection:', error);
        res.status(500).json({ message: 'Server error' });
    }
};

// Bir etikete atanan bağlantıları getir
const getConnectionsForTag = async (req, res) => {
    const { tagId } = req.params;
    const assigner_id = req.user.id;

    try {
        const query = `
            SELECT r.relation_id, 
                   CASE WHEN r.is_customer_internal THEN cu.isletme_ismi ELSE ceu.isletme_ismi END AS isletme_ismi,
                   CASE WHEN r.is_customer_internal THEN cu.ad ELSE ceu.ad END AS ad,
                   CASE WHEN r.is_customer_internal THEN cu.soyad ELSE ceu.soyad END AS soyad,
                   'customer' as relation_role
            FROM relations r
            JOIN tag_assignments ta ON r.relation_id = ta.relation_id
            LEFT JOIN users cu ON r.customer_id = cu.user_id AND r.is_customer_internal = TRUE
            LEFT JOIN external_users ceu ON r.customer_id = ceu.external_user_id AND r.is_customer_internal = FALSE
            WHERE ta.tag_id = $1 AND r.wholesaler_id = $2
            
            UNION
            
            SELECT r.relation_id, 
                   CASE WHEN r.is_wholesaler_internal THEN wu.isletme_ismi ELSE weu.isletme_ismi END AS isletme_ismi,
                   CASE WHEN r.is_wholesaler_internal THEN wu.ad ELSE weu.ad END AS ad,
                   CASE WHEN r.is_wholesaler_internal THEN wu.soyad ELSE weu.soyad END AS soyad,
                   'wholesaler' as relation_role
            FROM relations r
            JOIN tag_assignments ta ON r.relation_id = ta.relation_id
            LEFT JOIN users wu ON r.wholesaler_id = wu.user_id AND r.is_wholesaler_internal = TRUE
            LEFT JOIN external_users weu ON r.wholesaler_id = weu.external_user_id AND r.is_wholesaler_internal = FALSE
            WHERE ta.tag_id = $1 AND r.customer_id = $2;
        `;
        const result = await db.query(query, [tagId, assigner_id]);
        res.json(result.rows);
    } catch (error) {
        console.error('Error getting connections for tag:', error);
        res.status(500).json({ message: 'Server error' });
    }
};

// Bir bağlantı için etiket atamalarını senkronize et
const syncAssignmentsForConnection = async (req, res) => {
    const { relationId } = req.params;
    const { tag_ids } = req.body; // ["tag_id_1", "tag_id_2"]
    const assigner_id = req.user.id;

    if (!Array.isArray(tag_ids)) {
        return res.status(400).json({ message: 'tag_ids must be an array.' });
    }

    const client = await db.connect();
    try {
        await client.query('BEGIN');

        // YENİ: YETKİ KONTROLÜ - Kullanıcının bu bağlantının bir parçası olduğundan emin ol
        const relationCheck = await client.query(
            'SELECT * FROM relations WHERE relation_id = $1 AND (wholesaler_id = $2 OR customer_id = $2)',
            [relationId, assigner_id]
        );

        if (relationCheck.rows.length === 0) {
            await client.query('ROLLBACK');
            return res.status(403).json({ message: 'Permission denied. You are not part of this relation.' });
        }
        // YETKİ KONTROLÜ SONU

        // 1. Mevcut tüm atamaları bu kullanıcı ve bağlantı için sil
        await client.query(
            'DELETE FROM tag_assignments WHERE relation_id = $1 AND assigner_id = $2',
            [relationId, assigner_id]
        );

        // 2. Yeni etiketleri ekle
        if (tag_ids.length > 0) {
            // Foreign key constraint hatasını önlemek için kullanıcının kendi etiketlerini kullandığından emin ol
            const validTagsCheck = await client.query(
                'SELECT tag_id FROM tags WHERE creator_id = $1 AND tag_id = ANY($2::text[])',
                [assigner_id, tag_ids]
            );

            if (validTagsCheck.rows.length !== tag_ids.length) {
                 await client.query('ROLLBACK');
                 return res.status(400).json({ message: 'Invalid tag_id found. You can only use your own tags.' });
            }

            const insertPromises = tag_ids.map(tagId => {
                const assignment_id = generateId('tag_assign_', 12);
                const query = `
                    INSERT INTO tag_assignments (assignment_id, tag_id, relation_id, assigner_id)
                    VALUES ($1, $2, $3, $4);
                `;
                return client.query(query, [assignment_id, tagId, relationId, assigner_id]);
            });
            await Promise.all(insertPromises);
        }

        await client.query('COMMIT');

        // 3. Güncel etiket listesini geri döndür
        const newTagsResult = await client.query(`
            SELECT t.tag_id, t.name, t.note FROM tags t
            JOIN tag_assignments ta ON t.tag_id = ta.tag_id
            WHERE ta.relation_id = $1 AND ta.assigner_id = $2
            ORDER BY t.name ASC;
        `, [relationId, assigner_id]);

        res.status(200).json(newTagsResult.rows);

    } catch (error) {
        await client.query('ROLLBACK');
        console.error('Error syncing assignments:', error);
        res.status(500).json({ message: 'Server error during assignment sync' });
    } finally {
        client.release();
    }
};


module.exports = {
    getTagsForConnection,
    getConnectionsForTag,
    syncAssignmentsForConnection,
};