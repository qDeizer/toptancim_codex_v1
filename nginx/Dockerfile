# =============================================================================
# Toptancım B2B — Nginx + Flutter Web Frontend Dockerfile
# =============================================================================
# Multi-stage build:
#   Stage 1: Flutter SDK ile web build
#   Stage 2: Nginx ile statik dosyaları servis et
# =============================================================================

# --- Stage 1: Flutter Web Build ---
FROM ghcr.io/cirruslabs/flutter:stable AS flutter-builder

WORKDIR /app

# pubspec dosyalarını önce kopyala (pub get cache)
COPY frontend/pubspec.yaml frontend/pubspec.lock ./
RUN flutter pub get

# Tüm frontend kodunu kopyala
COPY frontend/ .

# Flutter web build (release)
RUN flutter build web --release --base-href /

# --- Stage 2: Nginx ile Serve ---
FROM nginx:1.27-alpine

# Nginx yapılandırması
COPY nginx/nginx.conf /etc/nginx/conf.d/default.conf

# Flutter web build çıktısını kopyala
COPY --from=flutter-builder /app/build/web /usr/share/nginx/html

# Nginx'in PID dosyası için dizin
RUN mkdir -p /var/cache/nginx

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
