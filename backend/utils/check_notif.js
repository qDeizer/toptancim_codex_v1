const db = require('../db');

async function checkNotifications() {
    const targetUserId = '10bae8d053c4'; // mesefar
    try {
        const client = await db.connect();
        const res = await client.query('SELECT * FROM notifications WHERE user_id = $1 ORDER BY created_at DESC', [targetUserId]);
        console.log('Notifications found:', res.rows.length);
        console.log(JSON.stringify(res.rows, null, 2));
        client.release();
        process.exit(0);
    } catch (err) {
        console.error(err);
        process.exit(1);
    }
}

checkNotifications();
