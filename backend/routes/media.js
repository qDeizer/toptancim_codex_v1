const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const auth = require('../middleware/auth');
const { getMyMedia, uploadMedia, toggleFavorite, deleteMedia, generateAiImages } = require('../controllers/mediaController');

const uploadsDir = process.env.UPLOADS_DIR
    ? path.resolve(process.env.UPLOADS_DIR)
    : path.join(__dirname, '../uploads');
const mediaDir = path.join(uploadsDir, 'media');
if (!fs.existsSync(mediaDir)) fs.mkdirSync(mediaDir, { recursive: true });

const fileFilter = (req, file, cb) => {
    const allowedExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'tiff', 'svg'];
    const ext = file.originalname.toLowerCase().split('.').pop();
    if (allowedExtensions.includes(ext)) cb(null, true);
    else cb(new Error('Sadece geçerli görsel formatları kabul edilir'), false);
};

const storage = multer.diskStorage({
    destination: (req, file, cb) => cb(null, mediaDir),
    filename: (req, file, cb) => {
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        const ext = path.extname(file.originalname);
        cb(null, 'up_' + uniqueSuffix + ext);
    }
});

const mediaUpload = multer({ storage, fileFilter, limits: { fileSize: 10 * 1024 * 1024 } });

router.get('/', auth, getMyMedia);
router.post('/upload', auth, mediaUpload.single('media'), uploadMedia);
router.patch('/:mediaId/favorite', auth, toggleFavorite);
router.delete('/:mediaId', auth, deleteMedia);
router.post('/generate-ai', auth, generateAiImages);

module.exports = router;
