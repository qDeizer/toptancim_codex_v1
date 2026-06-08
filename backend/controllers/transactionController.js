const db = require('../db');
const generateId = require('../utils/generateId');
const { createNotification } = require('./notificationController');

const getOtherPartyId = (transaction, currentUserId) => {
    if (transaction.creator_id === currentUserId) {
        // Current user is creator, other party is the one in the transaction who is NOT me.
        // Transaction has from_id and to_id.
        // If creator is from_id, other is to_id.
        // If creator is to_id, other is from_id.
        return transaction.from_id === currentUserId ? transaction.to_id : transaction.from_id;
    } else {
        // Current user is NOT creator. So other party is creator (usually). 
        // But wait, the transaction is between A and B. Creator is A.
        // If I am B, other party is A (creator).
        return transaction.creator_id;
    }
};

const isInternalUser = async (client, userId) => {
    if (!userId) return null;
    const userCheck = await client.query('SELECT 1 FROM users WHERE user_id = $1', [userId]);
    return userCheck.rowCount > 0;
};
const createTransaction = async (req, res, next) => {
    const {
        frontend_type, // satis, tahsilat, alis, odeme, gelir, gider
        person_id,     // İşlem yapılan karşı tarafın ID'si
        amount,
        currency,
        payment_method,
        description,
        transaction_date,
        proof_image_url,
        reference_id,
        reference_type,
        category
    } = req.body;
    const creator_id = req.user.id;
    const client = await db.connect();

    try {
        await client.query('BEGIN');
        let from_id = null;
        let to_id = null;
        let transaction_type = '';
        let final_payment_method = payment_method;

        switch (frontend_type) {
            case 'satis':
                from_id = creator_id;
                to_id = person_id;
                transaction_type = 'Tahakkuk';
                final_payment_method = null; // Satış işlemlerinde ödeme yöntemi null
                break;
            case 'tahsilat':
                from_id = person_id;
                to_id = creator_id;
                transaction_type = 'Nakit Akışı';
                break;
            case 'alis':
                from_id = person_id;
                to_id = creator_id;
                transaction_type = 'Tahakkuk';
                final_payment_method = null; // Alış işlemlerinde ödeme yöntemi null
                break;
            case 'odeme':
                from_id = creator_id;
                to_id = person_id;
                transaction_type = 'Nakit Akışı';
                break;
            case 'gelir':
                from_id = person_id || null; // Gelirin kaynağı seçilirse person_id, yoksa null
                to_id = creator_id; // Gelir bana geliyor
                transaction_type = 'Doğrudan İşlem';
                break;
            case 'gider':
                from_id = creator_id; // Gider benden çıkıyor
                to_id = person_id || null; // Giderin hedefi seçilirse person_id, yoksa null
                transaction_type = 'Doğrudan İşlem';
                break;
            default:
                throw new Error('Geçersiz işlem tipi.');
        }

        const is_from_internal = await isInternalUser(client, from_id);
        const is_to_internal = await isInternalUser(client, to_id);

        // Check for Mutual Approval
        let approval_status = 'onayli';
        // Only valid if there is a person_id (target)
        if (person_id) {
            const relationRes = await client.query(
                `SELECT wholesaler_id, customer_id, wholesaler_approval, customer_approval 
                 FROM relations 
                 WHERE (wholesaler_id = $1 AND customer_id = $2) OR (wholesaler_id = $2 AND customer_id = $1)`,
                [creator_id, person_id]
            );

            if (relationRes.rowCount > 0) {
                const rel = relationRes.rows[0];
                if (rel.wholesaler_id === creator_id) {
                    // Creator is Wholesaler. Check if Customer requires approval.
                    if (rel.customer_approval) {
                        approval_status = 'beklemede';
                    }
                } else {
                    // Creator is Customer. Check if Wholesaler requires approval.
                    if (rel.wholesaler_approval) {
                        approval_status = 'beklemede';
                    }
                }
            }
        }

        const transaction_id = generateId('trn_', 16);

        const query = `
            INSERT INTO financial_transactions 
            (transaction_id, creator_id, transaction_type, category, amount, currency, payment_method, description, transaction_date, from_id, is_from_internal, to_id, is_to_internal, proof_url, reference_id, reference_type, approval_status)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17)
            RETURNING *;
        `;

        const values = [
            transaction_id, creator_id, transaction_type, category, amount, currency, final_payment_method, description, transaction_date, from_id, is_from_internal, to_id, is_to_internal, proof_image_url, reference_id, reference_type, approval_status
        ];
        const result = await client.query(query, values);

        await client.query('COMMIT');
        res.status(201).json(result.rows[0]);

        // Send Notification to the other party
        if (to_id && to_id !== creator_id && is_to_internal) {
            await createNotification(
                client,
                to_id,
                'Yeni Finansal İşlem',
                `${amount} ${currency} tutarında bir ${frontend_type} işlemi kaydedildi.`,
                'transaction',
                transaction_id,
                { amount, currency, type: frontend_type },
                creator_id // actor_id
            );
        }
        if (from_id && from_id !== creator_id && is_from_internal) {
            await createNotification(
                client,
                from_id,
                'Yeni Finansal İşlem',
                `${amount} ${currency} tutarında bir ${frontend_type} işlemi kaydedildi.`,
                'transaction',
                transaction_id,
                { amount, currency, type: frontend_type },
                creator_id // actor_id
            );
        }


    } catch (error) {
        await client.query('ROLLBACK');
        next(error); // Hata yakalama middleware'ine gönder
    } finally {
        client.release();
    }
};


const getTransactions = async (req, res, next) => {
    const creator_id = req.user.id;
    try {
        const query = `
            SELECT 
                ft.*,
                COALESCE(from_user.isletme_ismi, from_ext.isletme_ismi, from_user.ad || ' ' || from_user.soyad, from_ext.ad || ' ' || from_ext.soyad) as from_name,
                COALESCE(from_user.profil_fotografi, from_ext.profil_fotografi) as from_photo,
                COALESCE(to_user.isletme_ismi, to_ext.isletme_ismi, to_user.ad || ' ' || to_user.soyad, to_ext.ad || ' ' || to_ext.soyad) as to_name,
                COALESCE(to_user.profil_fotografi, to_ext.profil_fotografi) as to_photo
            FROM financial_transactions ft
            LEFT JOIN users from_user ON ft.from_id = from_user.user_id AND ft.is_from_internal = TRUE
            LEFT JOIN external_users from_ext ON ft.from_id = from_ext.external_user_id AND ft.is_from_internal = FALSE
            LEFT JOIN users to_user ON ft.to_id = to_user.user_id AND ft.is_to_internal = TRUE
            LEFT JOIN external_users to_ext ON ft.to_id = to_ext.external_user_id AND ft.is_to_internal = FALSE
            WHERE ft.creator_id = $1 OR ft.from_id = $1 OR ft.to_id = $1
            ORDER BY ft.transaction_date DESC;
        `;
        const result = await db.query(query, [creator_id]);
        res.json(result.rows);
    } catch (error) {
        next(error);
    }
};

const getTransactionSummary = async (req, res, next) => {
    const userId = req.user.id;
    try {
        // 'Doğrudan İşlem' tipi, formüllerdeki 'Karşılıksız Hareket' ile aynı anlama gelmektedir.
        const query = `
            SELECT
                -- Toplam Alacak = (Satışlar) - (Tahsilatlar)
                COALESCE(SUM(CASE WHEN transaction_type = 'Tahakkuk' AND from_id = $1 THEN amount ELSE 0 END), 0) -
                COALESCE(SUM(CASE WHEN transaction_type = 'Nakit Akışı' AND to_id = $1 THEN amount ELSE 0 END), 0)
                AS total_receivable,

                -- Toplam Borç = (Alışlar) - (Ödemeler)
                COALESCE(SUM(CASE WHEN transaction_type = 'Tahakkuk' AND to_id = $1 THEN amount ELSE 0 END), 0) -
                COALESCE(SUM(CASE WHEN transaction_type = 'Nakit Akışı' AND from_id = $1 THEN amount ELSE 0 END), 0)
                AS total_debt,

                -- Toplam Gelir = (Satışlar) + (Doğrudan Gelen Para)
                COALESCE(SUM(CASE WHEN transaction_type = 'Tahakkuk' AND from_id = $1 THEN amount ELSE 0 END), 0) +
                COALESCE(SUM(CASE WHEN transaction_type = 'Doğrudan İşlem' AND to_id = $1 THEN amount ELSE 0 END), 0)
                AS total_revenue,

                -- Toplam Gider = (Alışlar) + (Doğrudan Giden Para)
                COALESCE(SUM(CASE WHEN transaction_type = 'Tahakkuk' AND to_id = $1 THEN amount ELSE 0 END), 0) +
                COALESCE(SUM(CASE WHEN transaction_type = 'Doğrudan İşlem' AND from_id = $1 THEN amount ELSE 0 END), 0)
                AS total_expense,

                -- Net Nakit = (Tahsilatlar + Doğrudan Gelen Para) - (Ödemeler + Doğrudan Giden Para)
                (COALESCE(SUM(CASE WHEN transaction_type = 'Nakit Akışı' AND to_id = $1 THEN amount ELSE 0 END), 0) +
                  COALESCE(SUM(CASE WHEN transaction_type = 'Doğrudan İşlem' AND to_id = $1 THEN amount ELSE 0 END), 0)) -
                (COALESCE(SUM(CASE WHEN transaction_type = 'Nakit Akışı' AND from_id = $1 THEN amount ELSE 0 END), 0) +
                 COALESCE(SUM(CASE WHEN transaction_type = 'Doğrudan İşlem' AND from_id = $1 THEN amount ELSE 0 END), 0))
                AS net_cash
            FROM financial_transactions
            WHERE $1 = ANY(ARRAY[creator_id, from_id, to_id]);
        `;

        const result = await db.query(query, [userId]);
        const summary = result.rows[0];
        // Cari Durum (Current Account Balance) = Toplam Alacak - Toplam Borç
        const current_balance = parseFloat(summary.total_receivable) - parseFloat(summary.total_debt);
        res.json({
            total_receivable: parseFloat(summary.total_receivable),
            total_debt: parseFloat(summary.total_debt),
            total_revenue: parseFloat(summary.total_revenue),
            total_expense: parseFloat(summary.total_expense),
            net_cash: parseFloat(summary.net_cash),
            current_balance: current_balance
        });
    } catch (error) {
        next(error);
    }
};

const deleteTransaction = async (req, res, next) => {
    const { id } = req.params;
    const creator_id = req.user.id;

    try {
        const deleteResult = await db.query(
            'DELETE FROM financial_transactions WHERE transaction_id = $1 AND creator_id = $2 RETURNING *',
            [id, creator_id]
        );

        if (deleteResult.rowCount === 0) {
            return res.status(404).json({ message: 'İşlem bulunamadı veya bu işlemi silme yetkiniz yok.' });
        }

        res.status(200).json({ message: 'İşlem başarıyla silindi.' });
    } catch (error) {
        next(error);
    }
};

const respondTransaction = async (req, res, next) => {
    const { id } = req.params;
    const { response } = req.body; // 'onayla' or 'reddet'
    const userId = req.user.id;
    const client = await db.connect();

    if (!['onayla', 'reddet'].includes(response)) {
        return res.status(400).json({ message: "Geçersiz yanıt. 'onayla' veya 'reddet' olmalı." });
    }

    try {
        await client.query('BEGIN');

        const trnRes = await client.query('SELECT * FROM financial_transactions WHERE transaction_id = $1', [id]);
        if (trnRes.rowCount === 0) {
            await client.query('ROLLBACK');
            return res.status(404).json({ message: 'İşlem bulunamadı.' });
        }
        const transaction = trnRes.rows[0];

        // Authorization: User must be the "other party" (not the creator)
        // And transaction must be in 'beklemede' status.
        if (transaction.approval_status !== 'beklemede') {
            await client.query('ROLLBACK');
            return res.status(400).json({ message: 'Bu işlem bekleyen bir onay işlemine sahip değil.' });
        }

        // Identify roles
        // If creator is wholesaler, user must be customer? Or just ensure user is the OTHER party.
        // The transaction stores to_id and from_id. One is creator. The other is the pending approver.
        if (transaction.creator_id === userId) {
            await client.query('ROLLBACK');
            return res.status(403).json({ message: 'Kendi işleminizi onaylayamazsınız.' });
        }

        const isAuthorizedArg = [userId, userId];
        // Ensure userId is either from_id or to_id
        if (transaction.from_id !== userId && transaction.to_id !== userId) {
            await client.query('ROLLBACK');
            return res.status(403).json({ message: 'Bu işlemle ilişkiniz yok.' });
        }

        const newStatus = response === 'onayla' ? 'onayli' : 'reddedildi';

        await client.query(
            'UPDATE financial_transactions SET approval_status = $1, updated_at = NOW() WHERE transaction_id = $2',
            [newStatus, id]
        );

        await client.query('COMMIT');
        res.json({ message: `İşlem ${newStatus}.`, approval_status: newStatus });

        // Notify Creator
        await createNotification(
            client,
            transaction.creator_id,
            'İşlem Durumu Güncellendi',
            `Oluşturduğunuz finansal işlem ${response === 'onayla' ? 'onaylandı' : 'reddedildi'}.`,
            'transaction',
            id,
            { status: newStatus },
            userId
        );

    } catch (error) {
        await client.query('ROLLBACK');
        next(error);
    } finally {
        client.release();
    }
};

const cancelTransaction = async (req, res, next) => {
    // Creator cancels BEFORE approval (while pending)
    const { id } = req.params;
    const userId = req.user.id;
    const client = await db.connect();

    try {
        await client.query('BEGIN');
        const trnRes = await client.query('SELECT * FROM financial_transactions WHERE transaction_id = $1', [id]);
        if (trnRes.rowCount === 0) {
            await client.query('ROLLBACK');
            return res.status(404).json({ message: 'İşlem bulunamadı.' });
        }
        const transaction = trnRes.rows[0];

        if (transaction.creator_id !== userId) {
            await client.query('ROLLBACK');
            return res.status(403).json({ message: 'Sadece işlemi oluşturan kişi iptal edebilir.' });
        }

        if (transaction.approval_status !== 'beklemede') {
            await client.query('ROLLBACK');
            return res.status(400).json({ message: 'Sadece beklemedeki işlemler doğrudan iptal edilebilir. Onaylanmış işlemler için iptal talebi oluşturun.' });
        }

        // Hard delete or set status? User said "iptal edebilecek". 
        // If I delete, it's gone.
        // Ideally update status to 'iptal_edildi' to keep history?
        // But pre-approval usually implies "oops, mistake". 
        // Let's set status to 'iptal_edildi' to correspond with user request "creator_iptal".
        // Actually for Pre-approval, standard is usually DELETE or "Cancelled".
        // Going with 'iptal_edildi' status update.
        await client.query(
            "UPDATE financial_transactions SET approval_status = 'iptal_edildi', updated_at = NOW() WHERE transaction_id = $1",
            [id]
        );

        await client.query('COMMIT');
        res.json({ message: 'İşlem iptal edildi.', approval_status: 'iptal_edildi' });

    } catch (error) {
        await client.query('ROLLBACK');
        next(error);
    } finally {
        client.release();
    }
};

const requestCancelTransaction = async (req, res, next) => {
    // Post-approval cancellation request
    const { id } = req.params;
    const userId = req.user.id;
    const client = await db.connect();

    try {
        await client.query('BEGIN');
        const trnRes = await client.query('SELECT * FROM financial_transactions WHERE transaction_id = $1', [id]);
        if (trnRes.rowCount === 0) {
            await client.query('ROLLBACK');
            return res.status(404).json({ message: 'İşlem bulunamadı.' });
        }
        const transaction = trnRes.rows[0];

        if (transaction.approval_status !== 'onayli') {
            await client.query('ROLLBACK');
            return res.status(400).json({ message: 'Sadece onaylı işlemler için iptal talebi oluşturulabilir.' });
        }

        let newStatus = '';
        let targetUserId = '';

        if (transaction.creator_id === userId) {
            newStatus = 'creator_iptal_talebi';
            // Target is the other party
            targetUserId = (transaction.from_id === userId) ? transaction.to_id : transaction.from_id;
        } else if (transaction.from_id === userId || transaction.to_id === userId) {
            newStatus = 'ilgili_iptal_talebi';
            // Target is creator
            targetUserId = transaction.creator_id;
        } else {
            await client.query('ROLLBACK');
            return res.status(403).json({ message: 'Bu işlemle ilişkiniz yok.' });
        }

        await client.query(
            'UPDATE financial_transactions SET approval_status = $1, updated_at = NOW() WHERE transaction_id = $2',
            [newStatus, id]
        );

        await client.query('COMMIT');
        res.json({ message: 'İptal talebi oluşturuldu.', approval_status: newStatus });

        // Notify
        await createNotification(
            client,
            targetUserId,
            'İptal Talebi',
            'Bir işlem için iptal talebi oluşturuldu.',
            'transaction',
            id,
            { status: newStatus },
            userId
        );

    } catch (error) {
        await client.query('ROLLBACK');
        next(error);
    } finally {
        client.release();
    }
};

const respondCancelRequest = async (req, res, next) => {
    const { id } = req.params;
    const { response } = req.body; // 'onay' (accept cancel) or 'red' (reject cancel)
    const userId = req.user.id; // The responder
    const client = await db.connect();

    if (!['onayla', 'reddet'].includes(response)) {
        return res.status(400).json({ message: "Geçersiz yanıt. 'onayla' veya 'reddet' olmalı." });
    }

    try {
        await client.query('BEGIN');
        const trnRes = await client.query('SELECT * FROM financial_transactions WHERE transaction_id = $1', [id]);
        if (trnRes.rowCount === 0) {
            await client.query('ROLLBACK');
            return res.status(404).json({ message: 'İşlem bulunamadı.' });
        }
        const transaction = trnRes.rows[0];
        const status = transaction.approval_status;

        // Determine who can respond
        // If status is 'creator_iptal_talebi', creator requested it, so OTHER party must respond.
        // If status is 'ilgili_iptal_talebi', other party requested it, so CREATOR must respond.

        let authorized = false;
        let requesterId = '';

        if (status === 'creator_iptal_talebi') {
            // Responder must be the other party
            const otherPartyId = (transaction.from_id === transaction.creator_id) ? transaction.to_id : transaction.from_id;
            if (userId === otherPartyId) {
                authorized = true;
                requesterId = transaction.creator_id;
            }
        } else if (status === 'ilgili_iptal_talebi') {
            // Responder must be Creator
            if (userId === transaction.creator_id) {
                authorized = true;
                // Who was the requester? The other party.
                requesterId = (transaction.from_id === transaction.creator_id) ? transaction.to_id : transaction.from_id;
            }
        } else {
            await client.query('ROLLBACK');
            return res.status(400).json({ message: 'Yanıtlanacak bir iptal talebi yok.' });
        }

        if (!authorized) {
            await client.query('ROLLBACK');
            return res.status(403).json({ message: 'Bu talebi yanıtlama yetkiniz yok.' });
        }

        let newStatus = '';
        if (response === 'onayla') {
            newStatus = 'iptal_edildi'; // Finally cancelled
        } else {
            newStatus = 'onayli'; // Revert to approved
        }

        await client.query(
            'UPDATE financial_transactions SET approval_status = $1, updated_at = NOW() WHERE transaction_id = $2',
            [newStatus, id]
        );

        await client.query('COMMIT');
        res.json({ message: response === 'onayla' ? 'İşlem iptal edildi.' : 'İptal talebi reddedildi.', approval_status: newStatus });

        // Notify Requester
        await createNotification(
            client,
            requesterId,
            'İptal Talebi Yanıtlandı',
            `İptal talebiniz ${response === 'onayla' ? 'onaylandı' : 'reddedildi'}.`,
            'transaction',
            id,
            { status: newStatus },
            userId
        );

    } catch (error) {
        await client.query('ROLLBACK');
        next(error);
    } finally {
        client.release();
    }
};


module.exports = {
    createTransaction,
    getTransactions,
    getTransactionSummary,
    deleteTransaction,
    respondTransaction,
    cancelTransaction,
    requestCancelTransaction,
    respondCancelRequest
};
