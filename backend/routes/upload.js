const express = require('express');
const router = express.Router();
const { uploadSingle, uploadMultiple } = require('../middleware/upload');
const auth = require('../middleware/auth');
const path = require('path');

/**
 * @swagger
 * /api/upload/profile:
 *   post:
 *     summary: Profil fotoğrafı yükle
 *     tags: [Upload]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             properties:
 *               profile:
 *                 type: string
 *                 format: binary
 *     responses:
 *       200:
 *         description: Profil fotoğrafı başarıyla yüklendi
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                 filename:
 *                   type: string
 *                 url:
 *                   type: string
 */
router.post('/profile', auth, (req, res) => {
    const upload = uploadSingle('profile');
    upload(req, res, (err) => {
        if (err) {
            console.error('Upload error:', err);
            return res.status(400).json({ message: err.message || 'Dosya yükleme hatası' });
        }
        
        try {
            if (!req.file) {
                return res.status(400).json({ message: 'Dosya yüklenmedi' });
            }

            const fileUrl = `/uploads/profiles/${req.file.filename}`;
            
            res.json({
                message: 'Profil fotoğrafı başarıyla yüklendi',
                filename: req.file.filename,
                url: fileUrl
            });
        } catch (error) {
            console.error('Profile upload error:', error);
            res.status(500).json({ message: 'Dosya yükleme hatası' });
        }
    });
});

/**
 * @swagger
 * /api/upload/product:
 *   post:
 *     summary: Ürün resmi/resimleri yükle
 *     tags: [Upload]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             properties:
 *               products:
 *                 type: array
 *                 items:
 *                   type: string
 *                   format: binary
 *     responses:
 *       200:
 *         description: Ürün resimleri başarıyla yüklendi
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                 files:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       filename:
 *                         type: string
 *                       url:
 *                         type: string
 */
router.post('/product', auth, (req, res) => {
    const upload = uploadMultiple('products', 10);
    upload(req, res, (err) => {
        if (err) {
            console.error('Upload error:', err);
            return res.status(400).json({ message: err.message || 'Dosya yükleme hatası' });
        }
        
        try {
            if (!req.files || req.files.length === 0) {
                return res.status(400).json({ message: 'Dosya yüklenmedi' });
            }

            const files = req.files.map(file => ({
                filename: file.filename,
                url: `/uploads/products/${file.filename}`
            }));
            
            res.json({
                message: 'Ürün resimleri başarıyla yüklendi',
                files: files
            });
        } catch (error) {
            console.error('Product upload error:', error);
            res.status(500).json({ message: 'Dosya yükleme hatası' });
        }
    });
});

module.exports = router;