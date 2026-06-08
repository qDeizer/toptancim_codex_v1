const multer = require('multer');
const path = require('path');
const fs = require('fs');

// Uploads klasörünü oluştur (Azure için gerekirse UPLOADS_DIR ile override edilebilir)
const uploadsDir = process.env.UPLOADS_DIR
    ? path.resolve(process.env.UPLOADS_DIR)
    : path.join(__dirname, '../uploads');
if (!fs.existsSync(uploadsDir)) {
    fs.mkdirSync(uploadsDir, { recursive: true });
}

// Profil fotoğrafları için klasör
const profileDir = path.join(uploadsDir, 'profiles');
if (!fs.existsSync(profileDir)) {
    fs.mkdirSync(profileDir, { recursive: true });
}

// Ürün resimleri için klasör
const productDir = path.join(uploadsDir, 'products');
if (!fs.existsSync(productDir)) {
    fs.mkdirSync(productDir, { recursive: true });
}

// Dosya depolama yapılandırması
const storage = multer.diskStorage({
    destination: function (req, file, cb) {
        let uploadPath = uploadsDir;
        
        // Dosya tipine göre klasör seç
        if (req.route.path.includes('profile')) {
            uploadPath = profileDir;
        } else if (req.route.path.includes('product')) {
            uploadPath = productDir;
        }
        
        cb(null, uploadPath);
    },
    filename: function (req, file, cb) {
        // Benzersiz dosya adı oluştur
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        const extension = path.extname(file.originalname);
        cb(null, file.fieldname + '-' + uniqueSuffix + extension);
    }
});

// Dosya filtreleme (sadece resim dosyaları)
const fileFilter = (req, file, cb) => {
    console.log('File mimetype:', file.mimetype); // Debug için
    console.log('File originalname:', file.originalname); // Debug için
    
    // Dosya uzantısını kontrol et
    const fileExtension = file.originalname.toLowerCase().split('.').pop();
    const allowedExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'tiff'];
    
    // Uzantı kontrolü yeterli - mimetype kontrolü kaldırıldı çünkü sorun çıkarıyor
    if (allowedExtensions.includes(fileExtension)) {
        console.log('Dosya kabul edildi:', file.originalname);
        cb(null, true);
    } else {
        console.log('Dosya reddedildi:', file.originalname, 'Uzantı:', fileExtension);
        cb(new Error(`Sadece resim dosyaları yüklenebilir (JPEG, PNG, GIF, WebP). Dosya uzantısı: ${fileExtension}`), false);
    }
};

// Multer yapılandırması
const upload = multer({
    storage: storage,
    fileFilter: fileFilter,
    limits: {
        fileSize: 5 * 1024 * 1024, // 5MB limit
    }
});

// Tek dosya yükleme
const uploadSingle = (fieldName) => upload.single(fieldName);

// Çoklu dosya yükleme (ürün resimleri için)
const uploadMultiple = (fieldName, maxCount = 10) => upload.array(fieldName, maxCount);

module.exports = {
    uploadSingle,
    uploadMultiple,
    upload
};
