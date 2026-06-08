const db = require('../db');
const generateId = require('../utils/generateId');

const getProfile = async (req, res, next) => {
    const userId = req.user.id;
    try {
        const query = `
            SELECT 
                u.user_id, u.user_name, u.isletme_ismi, u.ad, u.soyad, u.tel_no, u.email, 
                u.hakkinda, u.profil_fotografi, u.toptanci_uyelik, u.role, u.created_at,
                a.address_title, a.address, a.detailed_address, a.latitude, a.longitude
            FROM users u
            LEFT JOIN address_info a ON u.user_id = a.user_id
            WHERE u.user_id = $1;
        `;
        const result = await db.query(query, [userId]);

        if (result.rows.length === 0) {
            return res.status(404).json({ message: 'Kullanıcı bulunamadı' });
        }

        const user = result.rows[0];
        // latitude ve longitude değerlerini number'a çevir
        if (user.latitude) user.latitude = parseFloat(user.latitude);
        if (user.longitude) user.longitude = parseFloat(user.longitude);

        res.json(user);
    } catch (error) {
        next(error);
    }
};

const updateProfile = async (req, res, next) => {
    const userId = req.user.id;
    const { 
        user_name, isletme_ismi, ad, soyad, tel_no, 
        email, hakkinda, profil_fotografi, address_info 
    } = req.body;
    
    const client = await db.connect();

    try {
        await client.query('BEGIN');

        const userQuery = `
            UPDATE users 
            SET 
                user_name = $1, isletme_ismi = $2, ad = $3, soyad = $4, 
                tel_no = $5, email = $6, hakkinda = $7, profil_fotografi = $8,
                updated_at = NOW()
            WHERE user_id = $9
            RETURNING user_id;
        `;
        const userResult = await client.query(userQuery, [
            user_name, isletme_ismi, ad, soyad, tel_no, email, 
            hakkinda, profil_fotografi, userId
        ]);

        if (userResult.rows.length === 0) {
            await client.query('ROLLBACK');
            return res.status(404).json({ message: 'Kullanıcı bulunamadı' });
        }

        if (address_info) {
            const address_id = 'addr_' + userId;
            const addressQuery = `
                INSERT INTO address_info (address_id, user_id, address_title, address, detailed_address, latitude, longitude)
                VALUES ($1, $2, $3, $4, $5, $6, $7)
                ON CONFLICT ON CONSTRAINT address_info_user_id_unique DO UPDATE SET
                    address_title = EXCLUDED.address_title,
                    address = EXCLUDED.address,
                    detailed_address = EXCLUDED.detailed_address,
                    latitude = EXCLUDED.latitude,
                    longitude = EXCLUDED.longitude;
            `;
            await client.query(addressQuery, [
                address_id,
                userId,
                address_info.address_title,
                address_info.address,
                address_info.detailed_address,
                address_info.latitude,
                address_info.longitude,
            ]);
        }

        await client.query('COMMIT');

        const completeUserQuery = `
            SELECT 
                u.user_id, u.user_name, u.isletme_ismi, u.ad, u.soyad, u.tel_no, u.email, 
                u.hakkinda, u.profil_fotografi, u.toptanci_uyelik, u.role, u.created_at,
                a.address_title, a.address, a.detailed_address, a.latitude, a.longitude
            FROM users u
            LEFT JOIN address_info a ON u.user_id = a.user_id
            WHERE u.user_id = $1;
        `;
        const completeResult = await client.query(completeUserQuery, [userId]);

        const user = completeResult.rows[0];
        // latitude ve longitude değerlerini number'a çevir
        if (user.latitude) user.latitude = parseFloat(user.latitude);
        if (user.longitude) user.longitude = parseFloat(user.longitude);

        res.json({
            message: 'Profil başarıyla güncellendi',
            user: user
        });

    } catch (error) {
        await client.query('ROLLBACK');
        if (error.code === '23505') {
            return res.status(400).json({ message: 'Bu kullanıcı adı, telefon veya e-posta zaten kullanımda.' });
        }
        next(error);
    } finally {
        client.release();
    }
};

module.exports = {
    getProfile,
    updateProfile,
};