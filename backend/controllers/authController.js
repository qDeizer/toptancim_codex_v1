const db = require('../db');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const generateId = require('../utils/generateId');

const register = async (req, res, next) => {
    const {
        user_name,
        isletme_ismi,
        ad,
        soyad,
        tel_no,
        email,
        password,
        hakkinda,
        profil_fotografi,
        address_info
    } = req.body;

    const client = await db.connect();

    try {
        await client.query('BEGIN');

        const existingUser = await client.query(
            'SELECT * FROM users WHERE email = $1 OR tel_no = $2 OR user_name = $3',
            [email, tel_no, user_name]
        );

        if (existingUser.rows.length > 0) {
            await client.query('ROLLBACK');
            return res.status(409).json({ message: 'Bu e-posta, telefon numarası veya kullanıcı adı zaten kullanımda.' });
        }

        const salt = await bcrypt.genSalt(10);
        const password_hash = await bcrypt.hash(password, salt);
        const user_id = generateId('usr_', 10);
        const now = new Date();

        // 1. Insert into users table
        const newUserResult = await client.query(
            `INSERT INTO users (user_id, user_name, isletme_ismi, ad, soyad, tel_no, email, password_hash, hakkinda, profil_fotografi) 
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10) RETURNING user_id, email`,
            [user_id, user_name, isletme_ismi, ad, soyad, tel_no, email, password_hash, hakkinda, profil_fotografi]
        );
        const newUser = newUserResult.rows[0];

        // 2. Insert into account_movements table
        const movement_id = 'mov_' + user_id;
        await client.query(
            `INSERT INTO account_movements (movement_id, user_id, creation_date, last_update) 
             VALUES ($1, $2, $3, $3)`,
            [movement_id, user_id, now]
        );

        // 3. Insert into address_info table
        if (address_info) {
            const address_id = 'addr_' + user_id;
            await client.query(
                `INSERT INTO address_info (address_id, user_id, address_title, address, detailed_address, latitude, longitude) 
                 VALUES ($1, $2, $3, $4, $5, $6, $7)`,
                [
                    address_id, 
                    user_id, 
                    address_info.address_title,
                    address_info.address, 
                    address_info.detailed_address, 
                    address_info.latitude, 
                    address_info.longitude
                ]
            );
        }

        await client.query('COMMIT');
        res.status(201).json(newUser);

    } catch (error) {
        await client.query('ROLLBACK');
        next(error);
    } finally {
        client.release();
    }
};

const login = async (req, res, next) => {
    const { loginIdentifier, password } = req.body;

    try {
        const userResult = await db.query(
            'SELECT * FROM users WHERE email = $1 OR tel_no = $1 OR user_name = $1',
            [loginIdentifier]
        );

        if (userResult.rows.length === 0) {
            return res.status(404).json({ message: 'Kullanıcı bulunamadı.' });
        }

        const user = userResult.rows[0];
        const isMatch = await bcrypt.compare(password, user.password_hash);
        const now = new Date();
        const movement_id = 'mov_' + user.user_id;

        if (!isMatch) {
            const upsertFailedLoginQuery = `
                INSERT INTO account_movements (movement_id, user_id, creation_date, last_update, last_failed_login, failed_login_count)
                VALUES ($1, $2, $3, $3, $3, 1)
                ON CONFLICT (user_id) DO UPDATE SET
                    last_failed_login = EXCLUDED.last_failed_login,
                    failed_login_count = account_movements.failed_login_count + 1,
                    last_update = EXCLUDED.last_update;
            `;
            await db.query(upsertFailedLoginQuery, [movement_id, user.user_id, now]);
            return res.status(401).json({ message: 'Geçersiz kimlik bilgileri.' });
        }
        
        const upsertSuccessfulLoginQuery = `
            INSERT INTO account_movements (movement_id, user_id, creation_date, last_update, last_login, login_count)
            VALUES ($1, $2, $3, $3, $3, 1)
            ON CONFLICT (user_id) DO UPDATE SET
                last_login = EXCLUDED.last_login,
                login_count = account_movements.login_count + 1,
                last_update = EXCLUDED.last_update;
        `;
        await db.query(upsertSuccessfulLoginQuery, [movement_id, user.user_id, now]);
        
        const payload = {
            user: {
                id: user.user_id,
                role: user.role,
            },
        };

        const token = jwt.sign(payload, process.env.JWT_SECRET, { expiresIn: '1d' });

        res.json({ token });

    } catch (error) {
        next(error);
    }
};

module.exports = {
    register,
    login,
};