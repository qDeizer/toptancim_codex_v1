const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const { updateProfile, getProfile } = require('../controllers/userController');

/**
 * @swagger
 * /api/users/profile:
 *   get:
 *     summary: Kullanıcı profilini getir
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Kullanıcı profili başarıyla getirildi
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 user_id:
 *                   type: string
 *                 user_name:
 *                   type: string
 *                 isletme_ismi:
 *                   type: string
 *                 ad:
 *                   type: string
 *                 soyad:
 *                   type: string
 *                 tel_no:
 *                   type: string
 *                 email:
 *                   type: string
 *                 hakkinda:
 *                   type: string
 *                 profil_fotografi:
 *                   type: string
 *                 toptanci_uyelik:
 *                   type: boolean
 *                 role:
 *                   type: string
 */
router.get('/profile', auth, getProfile);

/**
 * @swagger
 * /api/users/profile:
 *   put:
 *     summary: Kullanıcı profilini güncelle
 *     tags: [Users]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               user_name:
 *                 type: string
 *               isletme_ismi:
 *                 type: string
 *               ad:
 *                 type: string
 *               soyad:
 *                 type: string
 *               tel_no:
 *                 type: string
 *               email:
 *                 type: string
 *               hakkinda:
 *                 type: string
 *               profil_fotografi:
 *                 type: string
 *               address_info:
 *                 type: object
 *                 properties:
 *                   address:
 *                     type: string
 *                   delivery_address:
 *                     type: string
 *                   detailed_address:
 *                     type: string
 *                   city:
 *                     type: string
 *                   district:
 *                     type: string
 *                   postal_code:
 *                     type: string
 *     responses:
 *       200:
 *         description: Profil başarıyla güncellendi
 */
router.put('/profile', auth, updateProfile);



module.exports = router;