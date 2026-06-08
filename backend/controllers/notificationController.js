const db = require('../db');
const { getIO } = require('../socket');
const logger = require('../utils/logger');

// INTERNAL HELPER: Not exposed via route directly usually, but used by other controllers
const createNotification = async (client, userId, title, message, type, relatedId = null, data = {}, actorId = null) => {
    try {
        const query = `
            INSERT INTO notifications (user_id, title, message, type, related_id, data, actor_id)
            VALUES ($1, $2, $3, $4, $5, $6, $7)
            RETURNING *;
        `;
        const result = await client.query(query, [userId, title, message, type, relatedId, data, actorId]);
        const notification = result.rows[0];

        // Ensure we fetch actor details before emitting if actorId is present
        let actorDetails = null;
        if (actorId) {
            const actorQuery = `
                SELECT 
                    COALESCE(u.isletme_ismi, ext.isletme_ismi, u.ad || ' ' || u.soyad, ext.ad || ' ' || ext.soyad) as actor_name,
                    COALESCE(u.profil_fotografi, ext.profil_fotografi) as actor_photo
                FROM (SELECT $1::text as id) as r
                LEFT JOIN users u ON u.user_id = r.id
                LEFT JOIN external_users ext ON ext.external_user_id = r.id
            `;
            const actorRes = await client.query(actorQuery, [actorId]);
            if (actorRes.rows.length > 0) actorDetails = actorRes.rows[0];
        }

        const notificationWithActor = { ...notification, actor_name: actorDetails?.actor_name, actor_photo: actorDetails?.actor_photo };

        // Emit socket event
        try {
            getIO().to(`user_${userId}`).emit('notification', notificationWithActor);
            logger.debug('Notification emitted', { userId, type });
        } catch (err) {
            logger.error('Socket notification emit failed', err);
        }

        return notification;
    } catch (error) {
        logger.error('createNotification failed', error);
        throw error;
    }
};

const getNotifications = async (req, res, next) => {
    const userId = req.user.id;
    const { page = 1, limit = 20 } = req.query;
    const offset = (page - 1) * limit;

    const client = await db.connect();
    try {
        const query = `
            SELECT 
                n.*,
                COALESCE(u.isletme_ismi, ext.isletme_ismi, u.ad || ' ' || u.soyad, ext.ad || ' ' || ext.soyad) as actor_name,
                COALESCE(u.profil_fotografi, ext.profil_fotografi) as actor_photo
            FROM notifications n
            LEFT JOIN users u ON n.actor_id = u.user_id
            LEFT JOIN external_users ext ON n.actor_id = ext.external_user_id
            WHERE n.user_id = $1 
            ORDER BY n.created_at DESC 
            LIMIT $2 OFFSET $3
        `;
        const result = await client.query(query, [userId, limit, offset]);

        const countQuery = `SELECT COUNT(*) FROM notifications WHERE user_id = $1`;
        const countResult = await client.query(countQuery, [userId]);

        const unreadQuery = `SELECT COUNT(*) FROM notifications WHERE user_id = $1 AND is_read = FALSE`;
        const unreadResult = await client.query(unreadQuery, [userId]);

        res.json({
            notifications: result.rows,
            total: parseInt(countResult.rows[0].count),
            unreadCount: parseInt(unreadResult.rows[0].count),
            page: parseInt(page),
            totalPages: Math.ceil(parseInt(countResult.rows[0].count) / limit)
        });
    } catch (error) {
        next(error);
    } finally {
        client.release();
    }
};

const markAsRead = async (req, res, next) => {
    const userId = req.user.id;
    const { notificationId } = req.params; // 'all' or specific UUID

    const client = await db.connect();
    try {
        if (notificationId === 'all') {
            await client.query(`UPDATE notifications SET is_read = TRUE WHERE user_id = $1`, [userId]);
        } else {
            await client.query(`UPDATE notifications SET is_read = TRUE WHERE notification_id = $1 AND user_id = $2`, [notificationId, userId]);
        }
        res.json({ message: 'Marked as read' });
    } catch (error) {
        next(error);
    } finally {
        client.release();
    }
};

const getUnreadCount = async (req, res, next) => {
    const userId = req.user.id;
    const client = await db.connect();
    try {
        const result = await client.query(`SELECT COUNT(*) FROM notifications WHERE user_id = $1 AND is_read = FALSE`, [userId]);
        res.json({ count: parseInt(result.rows[0].count) });
    } catch (error) {
        next(error);
    } finally {
        client.release();
    }
};

module.exports = {
    createNotification,
    getNotifications,
    markAsRead,
    getUnreadCount
};
