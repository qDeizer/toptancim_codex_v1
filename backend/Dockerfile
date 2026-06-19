# =============================================================================
# Toptancım B2B — Backend Dockerfile
# =============================================================================
# Node.js Express + Socket.IO backend
# =============================================================================

FROM node:20-alpine

WORKDIR /app

# Bağımlılıkları önce kopyala (cache layer)
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

# Uygulama kodunu kopyala
COPY . .

# Uploads alt dizinlerini oluştur
RUN mkdir -p /app/uploads/products /app/uploads/profiles /app/uploads/media

# AI settings varsayılan dosyasını oluştur (yoksa uygulama kendi oluşturur)
RUN mkdir -p /app/config

EXPOSE 3002

# Healthcheck
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget -qO- http://localhost:3002/ || exit 1

CMD ["node", "index.js"]
