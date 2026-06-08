const db = require('../db');

// Test the new user registration with separate tables
async function testUserRegistration() {
    console.log('Testing user registration with new table structure...');
    
    const testUser = {
        user_name: 'test_new_structure',
        isletme_ismi: 'Test Business',
        ad: 'Test',
        soyad: 'User',
        tel_no: '+905551112233',
        email: 'test_new@example.com',
        password: 'testpass123',
        hakkinda: 'Test user for new structure',
        address_info: {
            address: '123 Test Street',
            delivery_address: '456 Delivery Ave',
            detailed_address: 'Apartment 7B',
            latitude: 41.0082,
            longitude: 28.9784,
            city: 'Istanbul',
            district: 'Kadıköy',
            postal_code: '34710'
        }
    };
    
    try {
        // Simulate the registration process
        const userId = 'test_user_' + Math.random().toString(36).substring(2, 12);
        const now = new Date().toISOString();
        
        // Begin transaction
        await db.query('BEGIN');
        
        // Insert user
        await db.query(
            `INSERT INTO users (user_id, user_name, isletme_ismi, ad, soyad, tel_no, email, password_hash, hakkinda, profil_fotografi, toptanci_uyelik) 
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)`,
            [userId, testUser.user_name, testUser.isletme_ismi, testUser.ad, testUser.soyad, 
             testUser.tel_no, testUser.email, 'hashed_password', testUser.hakkinda, null, false]
        );
        
        // Insert account movements
        const movement_id = 'acc_mov_' + userId;
        await db.query(
            `INSERT INTO account_movements (movement_id, user_id, creation_date, last_login, last_failed_login, last_update) 
             VALUES ($1, $2, $3, $4, $5, $6)`,
            [movement_id, userId, now, null, null, now]
        );
        
        // Insert address info
        const address_id = 'addr_' + userId;
        await db.query(
            `INSERT INTO address_info (address_id, user_id, address, delivery_address, detailed_address, latitude, longitude, city, district, postal_code, is_primary) 
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)`,
            [address_id, userId, testUser.address_info.address, testUser.address_info.delivery_address, 
             testUser.address_info.detailed_address, testUser.address_info.latitude, testUser.address_info.longitude,
             testUser.address_info.city, testUser.address_info.district, testUser.address_info.postal_code, true]
        );
        
        await db.query('COMMIT');
        
        console.log('✓ User registration successful!');
        console.log('User ID:', userId);
        
        // Test retrieving user with joined data
        const result = await db.query(`
            SELECT u.user_id, u.user_name, u.isletme_ismi, u.ad, u.soyad, u.tel_no, u.email, 
                   u.hakkinda, u.profil_fotografi, u.toptanci_uyelik, u.role,
                   a.address, a.delivery_address, a.detailed_address, a.latitude, a.longitude,
                   a.city, a.district, a.postal_code,
                   am.creation_date, am.last_login, am.last_failed_login, am.login_count, am.failed_login_count
            FROM users u
            LEFT JOIN address_info a ON u.user_id = a.user_id AND a.is_primary = true
            LEFT JOIN account_movements am ON u.user_id = am.user_id
            WHERE u.user_id = $1
        `, [userId]);
        
        console.log('✓ User data retrieval successful!');
        console.log('Retrieved user data:', JSON.stringify(result.rows[0], null, 2));
        
        // Test CASCADE delete
        await db.query('DELETE FROM users WHERE user_id = $1', [userId]);
        
        // Verify cascade worked
        const cascadeCheck = await db.query(`
            SELECT 
                (SELECT COUNT(*) FROM users WHERE user_id = $1) as users_count,
                (SELECT COUNT(*) FROM account_movements WHERE user_id = $1) as movements_count,
                (SELECT COUNT(*) FROM address_info WHERE user_id = $1) as address_count
        `, [userId]);
        
        const counts = cascadeCheck.rows[0];
        if (counts.users_count === '0' && counts.movements_count === '0' && counts.address_count === '0') {
            console.log('✓ CASCADE delete working correctly!');
        } else {
            console.log('✗ CASCADE delete failed:', counts);
        }
        
        return true;
        
    } catch (error) {
        await db.query('ROLLBACK');
        console.error('✗ Test failed:', error.message);
        return false;
    }
}

// Run the test
testUserRegistration()
    .then((success) => {
        if (success) {
            console.log('\n🎉 All tests passed! New table structure is working correctly.');
        } else {
            console.log('\n❌ Tests failed!');
        }
        process.exit(success ? 0 : 1);
    })
    .catch((error) => {
        console.error('Test execution failed:', error);
        process.exit(1);
    });