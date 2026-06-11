const db = require('../db');
const generateId = require('../utils/generateId');
const path = require('path');
const fs = require('fs');

const uploadsDir = process.env.UPLOADS_DIR
    ? path.resolve(process.env.UPLOADS_DIR)
    : path.join(__dirname, '../uploads');
const mediaDir = path.join(uploadsDir, 'media');
if (!fs.existsSync(mediaDir)) fs.mkdirSync(mediaDir, { recursive: true });

// Kullanıcının medyalarını getir
const getMyMedia = async (req, res, next) => {
    const userId = req.user.id;
    try {
        const result = await db.query(
            'SELECT * FROM media WHERE user_id = $1 ORDER BY created_at DESC',
            [userId]
        );
        res.json(result.rows);
    } catch (error) { next(error); }
};

// Medya yükle
const uploadMedia = async (req, res, next) => {
    const userId = req.user.id;
    if (!req.file) return res.status(400).json({ message: 'Dosya yüklenmedi' });

    try {
        const mediaId = generateId('med_', 14);
        const url = '/uploads/media/' + req.file.filename;
        await db.query(
            'INSERT INTO media (media_id, user_id, filename, url, type) VALUES ($1, $2, $3, $4, $5)',
            [mediaId, userId, req.file.originalname, url, 'image']
        );
        res.status(201).json({ media_id: mediaId, user_id: userId, filename: req.file.originalname, url, type: 'image', is_favorite: false });
    } catch (error) { next(error); }
};

// Favorile / unfavorile
const toggleFavorite = async (req, res, next) => {
    const userId = req.user.id;
    const { mediaId } = req.params;
    try {
        const result = await db.query(
            'UPDATE media SET is_favorite = NOT is_favorite WHERE media_id = $1 AND user_id = $2 RETURNING *',
            [mediaId, userId]
        );
        if (result.rows.length === 0) return res.status(404).json({ message: 'Medya bulunamadı' });
        res.json(result.rows[0]);
    } catch (error) { next(error); }
};

// Medya sil
const deleteMedia = async (req, res, next) => {
    const userId = req.user.id;
    const { mediaId } = req.params;
    try {
        const result = await db.query(
            'DELETE FROM media WHERE media_id = $1 AND user_id = $2 RETURNING *',
            [mediaId, userId]
        );
        if (result.rows.length === 0) return res.status(404).json({ message: 'Medya bulunamadı' });
        // Dosyayı fiziksel olarak silmeye çalış
        try {
            const filepath = path.join(uploadsDir, result.rows[0].url.replace(/^\/uploads\//, ''));
            if (fs.existsSync(filepath)) fs.unlinkSync(filepath);
        } catch (e) { /* ignore */ }
        res.json({ message: 'Medya silindi' });
    } catch (error) { next(error); }
};

// AI görsel oluşturma endpoint'i
const ALLOWED_QUALITIES = ['low', 'medium', 'high'];
const ALLOWED_SIZES = ['1024x1024', '1024x1536', '1536x1024'];
const MIME_BY_EXT = { '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.webp': 'image/webp' };

const generateAiImages = async (req, res, next) => {
    const userId = req.user.id;
    const { prompt, n, quality, size, reference_media_ids } = req.body;

    if (!prompt || !prompt.trim()) return res.status(400).json({ message: 'Prompt gereklidir' });

    const apiKey = process.env.OPENAI_API_KEY;
    if (!apiKey) return res.status(503).json({ message: 'AI görsel servisi yapılandırılmamış (OPENAI_API_KEY eksik)' });

    const numImages = Math.max(1, Math.min(4, parseInt(n) || 1));
    const imgQuality = ALLOWED_QUALITIES.includes(quality) ? quality : 'low';
    const imgSize = ALLOWED_SIZES.includes(size) ? size : '1024x1024';

    // Üretim 2 dakikayı bulabiliyor; bağlantı erken kopmasın
    req.setTimeout(8 * 60 * 1000);
    res.setTimeout(8 * 60 * 1000);

    try {
        // Referans görselleri diskten oku (edits endpoint'i image[] ile en fazla 4 referansı doğrudan kabul eder)
        const referenceFiles = [];
        const requestedRefs = Array.isArray(reference_media_ids) ? reference_media_ids.slice(0, 4) : [];
        for (const mediaId of requestedRefs) {
            const mr = await db.query('SELECT url FROM media WHERE media_id = $1 AND user_id = $2', [mediaId, userId]);
            if (mr.rows.length === 0) continue;
            const fpath = path.join(uploadsDir, mr.rows[0].url.replace(/^\/uploads\//, ''));
            if (!fs.existsSync(fpath)) {
                console.error('AI görsel: referans dosyası diskte yok:', fpath);
                continue;
            }
            const ext = path.extname(fpath).toLowerCase();
            referenceFiles.push({
                buffer: fs.readFileSync(fpath),
                mime: MIME_BY_EXT[ext] || 'image/png',
                name: 'ref' + referenceFiles.length + (ext || '.png'),
            });
        }
        // Referans istendiyse ama hiçbiri okunamadıysa sessizce prompt-only üretime düşme
        if (requestedRefs.length > 0 && referenceFiles.length === 0) {
            return res.status(400).json({ message: 'Seçilen referans görseller okunamadı. Görselleri yeniden yükleyip tekrar deneyin.' });
        }

        // Tek istekte n görsel: prompt ve referans input token maliyeti N kez yerine 1 kez ödenir
        let response;
        if (referenceFiles.length > 0) {
            // IMAGE-TO-IMAGE: /v1/images/edits — multipart/form-data ister
            const form = new FormData();
            form.append('model', 'gpt-image-2');
            form.append('prompt', prompt);
            form.append('n', String(numImages));
            form.append('size', imgSize);
            form.append('quality', imgQuality);
            form.append('output_format', 'webp');
            form.append('output_compression', '90');
            for (const ref of referenceFiles) {
                form.append('image[]', new Blob([ref.buffer], { type: ref.mime }), ref.name);
            }
            response = await fetch('https://api.openai.com/v1/images/edits', {
                method: 'POST',
                headers: { 'Authorization': 'Bearer ' + apiKey },
                body: form,
            });
        } else {
            // TEXT-TO-IMAGE: /v1/images/generations
            response = await fetch('https://api.openai.com/v1/images/generations', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + apiKey },
                body: JSON.stringify({
                    model: 'gpt-image-2',
                    prompt: prompt,
                    n: numImages,
                    size: imgSize,
                    quality: imgQuality,
                    output_format: 'webp',
                    output_compression: 90,
                }),
            });
        }

        if (!response.ok) {
            const errData = await response.json().catch(() => ({}));
            const apiError = errData.error || {};
            let message = apiError.message || 'AI görsel oluşturma başarısız';
            if (apiError.code === 'moderation_blocked') {
                message = apiError.moderation_details?.moderation_stage === 'output'
                    ? 'Oluşturulan görsel güvenlik kontrolüne takıldı. Prompt\'u değiştirip tekrar deneyin.'
                    : 'Prompt güvenlik kurallarına takıldı. İfadeyi yumuşatıp tekrar deneyin.';
            } else if (response.status === 429) {
                message = 'AI servisi şu an yoğun, lütfen biraz sonra tekrar deneyin.';
            } else if (response.status >= 500) {
                message = 'AI servisinde geçici bir sorun var, lütfen tekrar deneyin.';
            }
            console.error('AI görsel hatası:', response.status, apiError.code, apiError.message);
            return res.status(response.status === 400 ? 400 : 502).json({ message });
        }

        const data = await response.json();
        const items = Array.isArray(data.data) ? data.data : [];
        if (items.length === 0) return res.status(502).json({ message: 'AI servisi görsel döndürmedi' });

        const savedImages = [];
        for (const item of items) {
            const mediaId = generateId('med_', 14);
            const filename = 'ai_' + Date.now() + '_' + mediaId + '.webp';
            fs.writeFileSync(path.join(mediaDir, filename), Buffer.from(item.b64_json, 'base64'));
            const url = '/uploads/media/' + filename;

            await db.query(
                'INSERT INTO media (media_id, user_id, filename, url, type, prompt) VALUES ($1, $2, $3, $4, $5, $6)',
                [mediaId, userId, filename, url, 'image', prompt]
            );

            savedImages.push({ media_id: mediaId, user_id: userId, filename, url, type: 'image', is_favorite: false, prompt });
        }

        res.json({ images: savedImages });
    } catch (error) { next(error); }
};

module.exports = { getMyMedia, uploadMedia, toggleFavorite, deleteMedia, generateAiImages };






