const db = require('../db');
const generateId = require('../utils/generateId');
const path = require('path');
const fs = require('fs');

const uploadsDir = process.env.UPLOADS_DIR
    ? path.resolve(process.env.UPLOADS_DIR)
    : path.join(__dirname, '../uploads');
const mediaDir = path.join(uploadsDir, 'media');
if (!fs.existsSync(mediaDir)) fs.mkdirSync(mediaDir, { recursive: true });

// Socket emit için (init edilmemişse hata vermez — emit sessizce skip edilir)
let getIO;
try { getIO = require('../socket').getIO; } catch (_) { getIO = () => null; }

const ALLOWED_QUALITIES = ['low', 'medium', 'high'];
const ALLOWED_SIZES = ['1024x1024', '1024x1536', '1536x1024'];
const MIME_BY_EXT = { '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.webp': 'image/webp' };

// ========== KULLANICI MEDYASINI GETİR ==========
const getMyMedia = async (req, res, next) => {
    const userId = req.user.id;
    try {
        const result = await db.query(`
            SELECT m.*,
                   COALESCE(u.used_in, '[]'::json) AS used_in
            FROM media m
            LEFT JOIN LATERAL (
                SELECT json_agg(json_build_object(
                    'product_id', pp.product_id,
                    'name', pp.name
                )) AS used_in
                FROM (
                    SELECT DISTINCT p.product_id, p.name
                    FROM product_variants v
                    JOIN products p ON p.product_id = v.product_id
                    WHERE p.creator_id = $1
                      AND v.images IS NOT NULL
                      AND m.url <> ''
                      AND m.url = ANY(v.images)
                ) pp
            ) u ON true
            WHERE m.user_id = $1
            ORDER BY m.created_at DESC
        `, [userId]);
        res.json(result.rows);
    } catch (error) { next(error); }
};

// ========== MEDYA YÜKLE ==========
const uploadMedia = async (req, res, next) => {
    const userId = req.user.id;
    if (!req.file) return res.status(400).json({ message: 'Dosya yüklenmedi' });

    try {
        const mediaId = generateId('med_', 14);
        const url = '/uploads/media/' + req.file.filename;
        await db.query(
            'INSERT INTO media (media_id, user_id, filename, url, type, source, status) VALUES ($1, $2, $3, $4, $5, $6, $7)',
            [mediaId, userId, req.file.originalname, url, 'image', 'upload', 'ready']
        );
        const created = await db.query('SELECT * FROM media WHERE media_id = $1', [mediaId]);
        res.status(201).json(created.rows[0]);
    } catch (error) { next(error); }
};

// ========== FAVORİLE / UNFAVORİLE ==========
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

// ========== MEDYA SİL (kullanım kontrolü ile) ==========
const deleteMedia = async (req, res, next) => {
    const userId = req.user.id;
    const { mediaId } = req.params;
    const force = req.query.force === 'true';
    try {
        // Önce medyayı bul
        const mr = await db.query('SELECT * FROM media WHERE media_id = $1 AND user_id = $2', [mediaId, userId]);
        if (mr.rows.length === 0) return res.status(404).json({ message: 'Medya bulunamadı' });

        const media = mr.rows[0];

        // URL boş değilse kullanım kontrolü yap
        if (media.url && !force) {
            const usage = await db.query(`
                SELECT DISTINCT p.product_id, p.name
                FROM product_variants v
                JOIN products p ON p.product_id = v.product_id
                WHERE p.creator_id = $1
                  AND v.images IS NOT NULL
                  AND $2 = ANY(v.images)
            `, [userId, media.url]);

            if (usage.rows.length > 0) {
                return res.status(409).json({
                    message: 'Bu görsel ürünlerde kullanılıyor. Silmek için kullanılan ürünlerden manuel olarak kaldırın ya da force ile silin.',
                    used_in: usage.rows,
                });
            }
        }

        // Sil
        await db.query('DELETE FROM media WHERE media_id = $1 AND user_id = $2', [mediaId, userId]);

        // Fiziksel dosyayı sil (varsa)
        if (media.url) {
            try {
                const fpath = path.join(uploadsDir, media.url.replace(/^\/uploads\//, ''));
                if (fs.existsSync(fpath)) fs.unlinkSync(fpath);
            } catch (_) { /* ignore */ }
        }
        res.json({ message: 'Medya silindi' });
    } catch (error) { next(error); }
};

// ========== ARKAPLAN AI ÜRETİM YARDIMCISI ==========
async function runAiGeneration({
    userId,
    prompt,
    numImages,
    imgQuality,
    imgSize,
    referenceFiles,
    placeholderIds,
    apiKey,
}) {
    const timerLabel = `ai-gen-${placeholderIds[0]}`;
    console.time(timerLabel);
    try {
        // OpenAI çağrısı — referans varsa edits, yoksa generations
        let response;
        if (referenceFiles.length > 0) {
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
            response = await fetch('https://api.openai.com/v1/images/generations', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + apiKey },
                body: JSON.stringify({
                    model: 'gpt-image-2',
                    prompt,
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
                    ? 'Oluşturulan görsel güvenlik kontrolüne takıldı.'
                    : 'Prompt güvenlik kurallarına takıldı.';
            } else if (response.status === 429) {
                message = 'AI servisi şu an yoğun.';
            } else if (response.status >= 500) {
                message = 'AI servisinde geçici bir sorun var.';
            }
            console.error('AI görsel hatası:', response.status, apiError.code, apiError.message);

            // Tüm placeholder'ları failed yap
            await db.query(
                "UPDATE media SET status='failed', error_message=$1 WHERE media_id = ANY($2::text[]) AND status='generating'",
                [message, placeholderIds]
            );
            emitToUser(userId, 'media_updated', { action: 'generation_failed', error: message });
            console.timeEnd(timerLabel);
            return;
        }

        const data = await response.json();
        const items = Array.isArray(data.data) ? data.data : [];
        if (items.length === 0) {
            await db.query(
                "UPDATE media SET status='failed', error_message='AI servisi görsel döndürmedi' WHERE media_id = ANY($2::text[]) AND status='generating'",
                [placeholderIds]
            );
            emitToUser(userId, 'media_updated', { action: 'generation_failed', error: 'AI servisi görsel döndürmedi' });
            console.timeEnd(timerLabel);
            return;
        }

        // Her item'i kaydet
        for (let i = 0; i < items.length; i++) {
            const item = items[i];
            const placeholderId = placeholderIds[i];
            if (!placeholderId) break; // placeholder sayısı item'dan az olabilir

            const filename = 'ai_' + Date.now() + '_' + placeholderId + '.webp';
            fs.writeFileSync(path.join(mediaDir, filename), Buffer.from(item.b64_json, 'base64'));
            const url = '/uploads/media/' + filename;

            const updated = await db.query(
                "UPDATE media SET filename=$1, url=$2, status='ready', error_message=NULL WHERE media_id=$3 AND status='generating' AND user_id=$4 RETURNING *",
                [filename, url, placeholderId, userId]
            );

            // Kullanıcı placeholder'ı silmiş olabilir → yazdığımız dosyayı temizle
            if (updated.rows.length === 0) {
                try { fs.unlinkSync(path.join(mediaDir, filename)); } catch (_) { }
            }
        }

        // İsteğe bağlı: eşleşmeyen kalan placeholder'lar (item'dan fazla placeholder varsa) → failed
        if (placeholderIds.length > items.length) {
            const unused = placeholderIds.slice(items.length);
            await db.query(
                "UPDATE media SET status='failed', error_message='Beklenenden az görsel döndü' WHERE media_id = ANY($1::text[]) AND status='generating'",
                [unused]
            );
        }

        emitToUser(userId, 'media_updated', { action: 'generation_done', count: items.length });
        console.timeEnd(timerLabel);
    } catch (error) {
        console.error('AI üretim arkaplan hatası:', error);
        try {
            await db.query(
                "UPDATE media SET status='failed', error_message=$1 WHERE media_id = ANY($2::text[]) AND status='generating'",
                ['Beklenmeyen bir hata oluştu.', placeholderIds]
            );
        } catch (_) { }
        emitToUser(userId, 'media_updated', { action: 'generation_failed', error: 'Beklenmeyen bir hata oluştu.' });
        console.timeEnd(timerLabel);
    }
}

function emitToUser(userId, event, payload) {
    try {
        const io = getIO();
        if (io) io.to(`user_${userId}`).emit(event, payload);
    } catch (_) { }
}

// ========== ASYNC AI GÖRSEL OLUŞTURMA ENDPOINT'İ ==========
const generateAiImages = async (req, res, next) => {
    const userId = req.user.id;
    const { prompt, n, quality, size, reference_media_ids } = req.body;

    if (!prompt || !prompt.trim()) return res.status(400).json({ message: 'Prompt gereklidir' });

    const apiKey = process.env.OPENAI_API_KEY;
    if (!apiKey) return res.status(503).json({ message: 'AI görsel servisi yapılandırılmamış (OPENAI_API_KEY eksik)' });

    const numImages = Math.max(1, Math.min(4, parseInt(n) || 1));
    const imgQuality = ALLOWED_QUALITIES.includes(quality) ? quality : 'low';
    const imgSize = ALLOWED_SIZES.includes(size) ? size : '1024x1024';

    try {
        // Referans görselleri SENKRON oku (dosyadan)
        const referenceFiles = [];
        const requestedRefs = Array.isArray(reference_media_ids) ? reference_media_ids.slice(0, 4) : [];
        for (const mediaId of requestedRefs) {
            const mr = await db.query('SELECT url FROM media WHERE media_id = $1 AND user_id = $2', [mediaId, userId]);
            if (mr.rows.length === 0) continue;
            const fpath = path.join(uploadsDir, mr.rows[0].url.replace(/^\/uploads\//, ''));
            if (!fs.existsSync(fpath)) continue;
            const ext = path.extname(fpath).toLowerCase();
            referenceFiles.push({
                buffer: fs.readFileSync(fpath),
                mime: MIME_BY_EXT[ext] || 'image/png',
                name: 'ref' + referenceFiles.length + (ext || '.png'),
            });
        }

        if (requestedRefs.length > 0 && referenceFiles.length === 0) {
            return res.status(400).json({ message: 'Seçilen referans görseller okunamadı.' });
        }

        // N adet placeholder INSERT et (status='generating', url='')
        const placeholders = [];
        for (let i = 0; i < numImages; i++) {
            const mediaId = generateId('med_', 14);
            await db.query(
                "INSERT INTO media (media_id, user_id, filename, url, type, source, status, prompt) VALUES ($1,$2,$3,$4,$5,$6,$7,$8)",
                [mediaId, userId, '', '', 'image', 'ai', 'generating', prompt]
            );
            placeholders.push(mediaId);
        }

        // Placeholder'ları döndür (id boş URL ile gelir — frontend status'e göre render eder)
        const created = await db.query(
            'SELECT * FROM media WHERE media_id = ANY($1::text[]) ORDER BY media_id',
            [placeholders]
        );
        res.status(202).json({ images: created.rows });

        // Arkaplanda üretimi başlat (await YOK — response zaten gitti)
        runAiGeneration({
            userId,
            prompt,
            numImages,
            imgQuality,
            imgSize,
            referenceFiles,
            placeholderIds: placeholders,
            apiKey,
        });

    } catch (error) { next(error); }
};

module.exports = { getMyMedia, uploadMedia, toggleFavorite, deleteMedia, generateAiImages };
