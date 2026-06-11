require('dotenv').config();
const express = require('express');
const cors = require('cors');
const path = require('path');
const app = express();
const swaggerUi = require('swagger-ui-express');
const swaggerJsdoc = require('swagger-jsdoc');
const http = require('http');
const socket = require('./socket');
const fs = require('fs');
const logger = require('./utils/logger');

// Import Routes
const authRoutes = require('./routes/auth');
const categoryRoutes = require('./routes/categories');
const tagRoutes = require('./routes/tags');
const connectionRoutes = require('./routes/connections');
const productRoutes = require('./routes/products');
const uploadRoutes = require('./routes/upload');
const userRoutes = require('./routes/users');
const tagAssignmentRoutes = require('./routes/tag_assignments');
const transactionRoutes = require('./routes/transactions');
const shopRoutes = require('./routes/shop');
const cartRoutes = require('./routes/cart');
const notificationRoutes = require('./routes/notifications');
const aiRoutes = require('./routes/ai');
const mediaRoutes = require('./routes/media');

// Temporarily disable Swagger to identify the issue
// const swaggerSpec = swaggerJsdoc({
//   definition: {
//     openapi: "3.0.0",
//     info: { title: "Toptancım API", version: "1.0.0" },
//     components: {
//         securitySchemes: {
//             bearerAuth: {
//                 type: 'http',
//                 scheme: 'bearer',
//                 bearerFormat: 'JWT',
//             }
//         }
//     },
//     security: [{
//         bearerAuth: []
//     }]
//   },
//   apis: ['./routes/*.js']
// });

// app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec));


// --- CORS AYARLARI (GÜNCELLENDİ) ---
app.use(cors({
  origin: [
    // Localhost adresleri (Codex Instance - Port 3002/8089)
    'http://localhost:3002',
    'http://localhost:8089',
    'http://127.0.0.1:3002',
    'http://127.0.0.1:8089',
    'http://10.0.2.2:3002',
    // Azure Frontend Adresleri (Canlı Sunucu)
    'https://toptancim-web-taha.azurewebsites.net',
    'http://toptancim-web-taha.azurewebsites.net',
    // Regex ile tüm Azure subdomainlerine izin ver
    /^https:\/\/.*\.azurewebsites\.net$/,
    /^http:\/\/localhost:\d+$/
  ],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS', 'PATCH'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With']
}));

app.use(express.json());

// Use Routes
app.use('/api/auth', authRoutes);
app.use('/api/categories', categoryRoutes);
app.use('/api/tags', tagRoutes);
app.use('/api/connections', connectionRoutes);
app.use('/api/products', productRoutes);
app.use('/api/upload', uploadRoutes);
app.use('/api/users', userRoutes);
app.use('/api/assignments', tagAssignmentRoutes);
app.use('/api/transactions', transactionRoutes);
app.use('/api/shop', shopRoutes);
app.use('/api/cart', cartRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/ai', aiRoutes);
app.use('/api/media', mediaRoutes);

// Static file serving for uploads (Azure için UPLOADS_DIR ile override edilebilir)
const uploadsDir = process.env.UPLOADS_DIR
  ? path.resolve(process.env.UPLOADS_DIR)
  : path.join(__dirname, 'uploads');

if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir, { recursive: true });
}

app.use('/uploads', express.static(uploadsDir));

// Test endpoint
app.get('/', (req, res) => {
  logger.debug('Health check requested', {
    path: req.originalUrl
  });
  res.send('API Calisiyor');
});

// GENEL HATA YAKALAMA MIDDLEWARE'İ
app.use((err, req, res, next) => {
  logger.error('Unhandled backend error', {
    path: req.originalUrl,
    method: req.method,
    message: err.message,
    stack: err.stack
  });

  if (res.headersSent) {
    return next(err);
  }

  res.status(500).json({
    message: 'Sunucuda beklenmedik bir hata oluştu.',
    error: process.env.NODE_ENV === 'development' ? err.message : undefined
  });
});

const server = http.createServer(app);

// Initialize Socket.IO
const io = socket.init(server);

const PORT = process.env.PORT || 3002;
server.listen(PORT, () => logger.info('Backend server started', { port: PORT }));
