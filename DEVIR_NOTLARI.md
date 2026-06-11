# DEVİR NOTLARI — AI Medya Modülü Geliştirme (2026-06-11)

Bu doküman, yarım kalan işin başka bir AI tarafından devralınması için yazıldı.
Proje: `C:\Users\deizer\Desktop\toptancim rapor\toptancim_B2B` (Node.js backend + Flutter frontend + PostgreSQL).

---

## 1. ŞU ANA KADAR TAMAMLANANLAR (deploy edildi, çalışıyor)

### AI görsel üretim modülü (TAMAM, canlıda test edildi)
- `backend/controllers/mediaController.js` — gpt-image-2 ile üretim:
  - Text-to-image: `POST https://api.openai.com/v1/images/generations` (JSON)
  - Image-to-image (referanslı): `POST /v1/images/edits` — **multipart/form-data ZORUNLU**, `FormData` + `Blob` ile `image[]` alanında en fazla 4 referans (Node 18+ global FormData/Blob; sunucuda Node v20 var)
  - Tek istekte `n` görsel (1-4) — maliyet: referans input token'ları 1 kez ödenir
  - `quality`: low(varsayılan ~$0.006)/medium/high; `size`: 1024x1024 | 1024x1536 | 1536x1024
  - Çıktı: `output_format: 'webp'`, `output_compression: 90`; dosya adı `ai_<ts>_<mediaId>.webp` → `backend/uploads/media/`
  - `moderation_blocked` için Türkçe hata; 429/5xx ayrımı
  - **KULLANICI TERCİHİ: maliyet hep minimum tutulsun (quality=low varsayılan), ek vision/GPT-4o çağrısı YAPILMASIN**
- `backend/routes/media.js` — GET /, POST /upload (multer, field 'media'), PATCH /:mediaId/favorite, DELETE /:mediaId, POST /generate-ai. Hepsi `auth` middleware'li. index.js'te kayıt: `app.use('/api/media', mediaRoutes)`
- `backend/db/migration_add_media.sql` — media tablosu + prompt + YENİ eklenen ama SUNUCUYA HENÜZ UYGULANMAYAN kolonlar (bkz. bölüm 3)
- Frontend: `media_screen.dart` (galeri + AI üretim sheet'i), `media_provider.dart`, `media_service.dart`, `models/media.dart`
- `constants.dart` web fix: webde `Uri.base.host` localhost ise `http://localhost:3002/api`, değilse `${Uri.base.origin}/api` (sunucuda nginx /api proxy)
- API key `backend/.env` içinde `OPENAI_API_KEY` (koddan çıkarıldı; rotate önerildi). Sunucu .env'ine de eklendi.

### Düzeltilen kritik bug'lar
1. `/v1/images/edits` JSON+data-URL ile çağrılıyordu → multipart'a çevrildi
2. **Yol bug'ı**: `path.join(uploadsDir, '/uploads/media/x.png')` → `uploads/uploads/...` oluyordu. Düzeltme: `media.url.replace(/^\/uploads\//, '')` sonra join. Bu bug yüzünden referans görseller SESSİZCE gönderilmiyordu (kullanıcının şikayeti buydu). Artık referans istenip hiçbiri okunamazsa 400 dönüyor.
3. `deleteMedia`'da aynı yol bug'ı düzeltildi.

### Deploy durumu (sunucu CANLI ve çalışıyor)
- Sunucu: **207.154.240.53** (toptancim-server, Ubuntu, Node v20.20.2)
- SSH: root / erikVe4dut (ve deizer / erikVe4dut). Paramiko ile bağlanılıyor (şifre girişi açık)
- Yollar: backend `/opt/toptancim/backend` (pm2 process adı: `toptancim-backend`, root olarak çalışıyor), frontend `/opt/toptancim/frontend` (nginx :80; `/api` ve `/uploads` → 127.0.0.1:3002 proxy)
- DB: PostgreSQL `toptancimdb_codex` (şifre sunucu .env'inde). Migration: `su - postgres -c "psql -v ON_ERROR_STOP=1 -d toptancimdb_codex -f /opt/toptancim/backend/db/migration_add_media.sql"`
- Proje kökündeki hazır scriptler (İÇLERİNDE SUNUCU ŞİFRESİ VAR, gitignore'da):
  - `deploy_backend.py` — modül dosyalarını yükler, index.js patch, .env key, migration, pm2 restart, smoke test
  - `deploy_frontend.py` — `frontend/build/web` → `/opt/toptancim/frontend` (eskisini `frontend_bak_media`ya yedekler)
  - `deploy_e2e_test.py` — register→login→üretim→dosya/DB/nginx doğrulama
  - `deploy_snapshot.py` — sunucuda git commit + pg_dump + tar yedek (argüman: etiket)
  - `deploy_recon.py` — durum kontrolü
- Windows'ta paramiko çıktıları için `sys.stdout.reconfigure(encoding='utf-8', errors='replace')` ŞART (cp1254 hatası)
- Flutter SDK lokalde: `C:\Users\deizer\tools\codex-runtime\flutter\bin\flutter.bat` (PATH'te YOK). Build: `flutter.bat build web --release` (~3.5 dk)
- Lokal'de PostgreSQL YOK — backend lokal çalıştırılamaz, doğrulama sunucuda yapılır
- Test kullanıcısı sunucuda: `ai_e2e_test_user` / `AiTest2026!x` (usr_66c7dee94f)

### Sistem imajları (kullanıcının istediği "imaj alma" — YAPILDI, "önce" imajı)
- Sunucu: git commit `db6b903` (/opt/toptancim repo), DB dump `/opt/toptancim/backups/db_backup_20260611_1131.sql`, tar `/opt/toptancim-backup-20260611_1131.tar.gz` (74M, node_modules hariç)
- Lokal: git commit `a2482d0` (main branch)
- **İŞ BİTİNCE TEKRAR İMAJ ALINACAK** (deploy_snapshot.py + lokal commit) — kullanıcının 3. maddesinin son cümlesi

---

## 2. KULLANICININ SON İSTEĞİ (yarım kalan iş — 3 madde)

1. **Async üretim**: AI görsel oluşturduktan sonra kullanıcı üretim menüsünde BEKLEMESİN. Sheet kapatılabilsin; galeri, üretilmekte olan görselleri animasyonlu/işaretli tile ile göstersin. Medya sayfası yenilensin: ürün görselleri mi / AI üretimi mi filtreleri, hangi üründe kullanılmış bilgisi, "akla gelebilecek her şey".
2. **Ürün ekle/düzenle ekranlarına foto eklerken**: Cihazdan / Kameradan / **Medyadan** seçenekleri. Medyadan'da medya galerisi picker'ı + içinden AI üretim akışı çalışsın.
3. **Genel iyileştirmeler** (tasarım+UX+mantık) — aşağıda tespit edilenler var. Sonra tekrar imaj al.

---

## 3. KEŞİF BULGULARI (5 paralel ajanla çıkarıldı — yeniden keşfe GEREK YOK)

### DB şeması (backend/db/init.sql)
- `products` tablosunda GÖRSEL KOLONU YOK. Görseller `product_variants.images TEXT[]` kolonunda **relative URL listesi** (`/uploads/products/<file>` veya artık `/uploads/media/<file>`).
- `product_variants`: variant_id TEXT PK, product_id FK, name, description, rating, shelf_location, **images TEXT[]**, price, cost_price, stock_quantity, sold_quantity, tags TEXT[], is_active, sort_order (migration ile)
- `products`: product_id TEXT PK, creator_id TEXT FK→users, supplier_id, name, tags[], is_active, wholesale_price...
- `media`: media_id VARCHAR(50) PK, user_id FK→users CASCADE, filename, url TEXT NOT NULL, type, is_favorite, prompt TEXT, created_at. **Lokal migration dosyasına eklendi ama sunucuya uygulanmadı:** `status VARCHAR(20) DEFAULT 'ready'` (generating|ready|failed), `source VARCHAR(20) DEFAULT 'upload'` (upload|ai), `error_message TEXT`, ve backfill `UPDATE media SET source='ai' WHERE filename LIKE 'ai\_%' ESCAPE '\'`
- media ↔ product arasında FK YOK; bağ kurmanın yolu **URL eşleştirme**: `m.url = ANY(v.images)`

### Backend ürün/upload akışı
- POST/PUT /api/products gövdesinde görseller `variants[].images` URL string dizisi; backend doğrulamadan TEXT[]'e yazar (productController.js:23-29, 91-106)
- POST /api/upload/product → multer field `products`, max 10 dosya → `{files:[{filename,url:'/uploads/products/...'}]}`
- `app.use('/uploads', express.static(uploadsDir))` (index.js:101) → `/uploads/media/...` URL'si ÜRÜN GÖRSELİ OLARAK DOĞRUDAN KULLANILABİLİR, kopyalama gerekmez
- GET /api/products: her ürün `variants` (json_agg, images dahil) + `variant_thumbnails` (her varyantın images[0])
- RİSK: medya silinince fiziksel dosya da siliniyor → onu kullanan ürün görseli kırılır. ÇÖZÜM (planlandı): DELETE /api/media/:id kullanımdaysa 409 + used_in listesi dönsün; `?force=true` ile silinsin.

### Socket altyapısı
- `backend/socket.js`: init(httpServer) + getIO() singleton. io.use ile JWT auth (`socket.handshake.auth.token`), bağlantıda `user_${userId}` odasına otomatik join.
- **BUG (düzeltildi, lokal, deploy edilmedi)**: socket.js:39 `socket.decoded_token.id` okuyordu ama JWT payload `{ user: { id, role } }` (authController.js:126-133). Oda `user_undefined` oluyordu → hedefli emitler hiç ulaşmıyordu. Düzeltme uygulandı: `socket.decoded_token.user?.id || socket.decoded_token.id`. **BU DOSYA SUNUCUYA DEPLOY EDİLMELİ.**
- Controller'dan emit kalıbı: `const { getIO } = require('../socket');` → `try { getIO().to('user_'+userId).emit('event', payload) } catch(e){}` (örnek: notificationController.js:35, customerCartController.js:125)
- Frontend `socket_service.dart`: singleton; `CartProvider.updateAuth` içinde `SocketService().connect(token)` ile başlatılıyor; 'cart_updated' ve 'notification' dinleniyor. Yeni event ekleme kalıbı: StreamController.broadcast + getter ekle, connect() içine `_socket!.on('media_updated', ...)` ekle, provider'da `.listen()`.

### Frontend ürün ekranları
- `product_add_screen.dart` ve `product_edit_screen.dart` neredeyse aynı yapı. Görseller XFile olarak TUTULMUYOR: seçilince hemen `ImageService.uploadProductImages()` ile yüklenip dönen URL'ler `variant.images` (List<String>?) listesine ekleniyor; ürün kaydında URL'ler `variants[].images` JSON'unda gidiyor.
- **`_addFromMedia(ProductVariant variant)` HER İKİ ekranda yazılmış ama HİÇBİR BUTONA BAĞLANMAMIŞ (ölü kod)**: add_screen:468-502, edit_screen:488-522. MediaProvider.media'dan dialog ile tek öğe seçip `variant.images!.add(selected.url)` yapıyor. Bunu kaldırıp paylaşılan çok-seçimli picker'la değiştir (plan bölüm 4).
- Görsel butonları `_buildImageSection`: 'Resim Ekle' (_addSingleImage) ve 'Çoklu Resim' (_addMultipleImages) — add:445-463, edit:465-483. Önizleme: 100px yatay ListView, Stack[Image.network + sağ üst silme + index==0 'Kapak' rozeti] — add:395-443, edit:415-463
- Provider imzaları: `addProduct(Product)`, `updateProduct(String productId, Map<String,dynamic> payload)`, `fetchProductById(String)`
- analyze uyarıları: her iki ekranda unused import 'models/category.dart' ve 'models/connection.dart'; `_addFromMedia` unused_element

### Frontend navigasyon
- `main.dart:81-84`: MediaProvider ChangeNotifierProxyProvider ile kayıtlı (token almaz)
- `home_screen.dart:94`: 'Medya' modül kartı → MediaScreen; home refresh'te fetchMedia çağrılıyor (satır 47)

---

## 4. UYGULAMA PLANI (tasarlandı, kısmen başlandı)

### 4a. Backend — `mediaController.js` async üretime çevrilecek (BAŞLANMADI)
- `generateAiImages`: prompt/key/param doğrula; referansları SENKRON oku (okunamazsa 400); N adet placeholder satır INSERT et (`status='generating'`, `source='ai'`, `url=''`, filename `ai_pending_<id>`, prompt); **hemen 202** dön `{ images: [placeholder'lar] }`; üretimi `runAiGeneration(...)` ile arka planda başlat (await ETME, .catch ile logla). `req.setTimeout(8dk)` satırları artık GEREKSİZ, kaldır.
- `runAiGeneration({userId, prompt, numImages, imgQuality, imgSize, referenceFiles, placeholderIds, apiKey})`:
  - Mevcut OpenAI çağrı kodunun aynısı (edits multipart / generations JSON, n'li tek istek)
  - Başarıda her item için: dosyayı yaz, `UPDATE media SET filename=$1, url=$2, status='ready' WHERE media_id=$3 AND status='generating' RETURNING media_id` — 0 satır dönerse (kullanıcı silmiş) yazılan dosyayı unlink et
  - items[i] yoksa o placeholder'ı failed işaretle
  - Hata/moderation'da: `UPDATE media SET status='failed', error_message=$1 WHERE media_id = ANY($2) AND status='generating'` (mevcut Türkçe hata mesajı mantığını taşı)
  - Sonda: `try { getIO().to('user_'+userId).emit('media_updated', {action: 'generation_done'|'generation_failed'}) } catch(e){}` — `const { getIO } = require('../socket')` import et
- `getMyMedia`: used_in bilgisi eklensin:
```sql
SELECT m.*, COALESCE(u.used_in, '[]'::json) AS used_in
FROM media m
LEFT JOIN LATERAL (
  SELECT json_agg(json_build_object('product_id', pp.product_id, 'name', pp.name)) AS used_in
  FROM (
    SELECT DISTINCT p.product_id, p.name
    FROM product_variants v
    JOIN products p ON p.product_id = v.product_id
    WHERE p.creator_id = m.user_id AND v.images IS NOT NULL
      AND m.url <> '' AND m.url = ANY(v.images)
  ) pp
) u ON true
WHERE m.user_id = $1
ORDER BY m.created_at DESC
```
- `deleteMedia`: önce SELECT ile medyayı al; `req.query.force !== 'true'` ve url doluysa kullanım sorgusu çalıştır (yukarıdaki DISTINCT alt sorgusu, $2 = media.url); kullanım varsa **409** `{ message: 'Bu görsel ürünlerde kullanılıyor', used_in: rows }`; yoksa DELETE + fiziksel dosya sil ('generating' satırı da silinebilir — arka plan UPDATE 0 satır görüp dosyayı temizler)

### 4b. Frontend — model/servis/provider (BAŞLANMADI)
- `models/media.dart`: `status` ('ready' varsayılan), `source` ('upload'), `errorMessage`, `usedIn` (List<Map> ya da küçük sınıf: productId, name) alanları; fromJson'da `used_in` parse et. `isGenerating`/`isFailed`/`isAi` getter'ları pratik.
- `services/media_service.dart`: `deleteMedia(mediaId, {force})` → 409'da özel exception fırlat (used_in taşıyan, örn. `MediaInUseException(List products)`); `generateAiImages` 200 yerine **202**'yi de kabul et (`res.statusCode != 200 && != 202` hata).
- `services/socket_service.dart`: `_mediaUpdateController = StreamController<Map<String,dynamic>>.broadcast()` + `mediaUpdates` getter; connect() içine `_socket!.on('media_updated', (d) => _mediaUpdateController.add(Map<String,dynamic>.from(d ?? {})))`; dispose'da close.
- `providers/media_provider.dart`:
  - Constructor'da `SocketService().mediaUpdates.listen((_) => fetchMedia(refresh: true))` aboneliği; dispose'da cancel
  - Polling fallback: `hasGenerating` (listede status=='generating' var mı) true iken `Timer.periodic(6sn, fetchMedia)`; kalmayınca timer iptal. fetchMedia/generateAiImages sonrası kontrol et.
  - `deleteMedia(id, {force=false})` — MediaInUseException'ı yukarı fırlat (ekran onay diyaloğu gösterip force=true ile tekrar çağıracak)

### 4c. Frontend — `media_screen.dart` yenileme (BAŞLANMADI)
- AppBar altına filtre çipleri: **Tümü | AI Üretilen | Yüklenen | Favoriler** (mevcut yıldız toggle yerine)
- Tile durumları:
  - `generating`: animasyonlu placeholder (gradyan + dönen progress + auto_awesome ikonu, hafif pulse) — kullanıcı sheet'i kapatınca galeride bunlar görünür
  - `failed`: kırmızı tonlu tile + error ikonu; tıklayınca error_message + 'Sil' aksiyonu
  - `ready`: görsel; `source=='ai'` ise sol altta küçük auto_awesome rozeti; favori yıldızı; usedIn doluysa küçük sepet/etiket rozeti
- Detay görünümü (dialog yerine bottom sheet): büyük görsel (tıkla → InteractiveViewer tam ekran), AI ise prompt (kopyalanabilir), kaynak+tarih, **kullanıldığı ürün çipleri**, aksiyonlar: favori, sil (usage-aware onay), kapat
- AI üretim sheet'i (`AiImageGeneratorSheet._generate`): 202 placeholders dönünce SnackBar 'Üretim başlatıldı — galeriden takip edebilirsin' + **Navigator.pop ile sheet'i KAPAT** (kullanıcı istedi: beklemesin). Sonuç gösterme bölümü kaldırılabilir.
- Çoklu seçim silme işlemine onay diyaloğu ekle (şu an onaysız siliyor)

### 4d. Frontend — ürün ekranlarına 'Medyadan' (BAŞLANMADI)
- YENİ paylaşılan widget: `frontend/lib/widgets/media_picker_sheet.dart` — MediaProvider.media'dan `status=='ready'` öğeler, çok-seçimli grid, üstte 'AI ile Oluştur' butonu (AiImageGeneratorSheet'i açar — AiImageGeneratorSheet'i media_screen.dart'tan export et ya da ayrı dosyaya taşı), generating tile'lar animasyonlu görünür (provider polling sayesinde hazır olunca seçilebilir), onaylayınca `List<String>` URL döner
- `product_add_screen.dart` + `product_edit_screen.dart`:
  - `_buildImageSection`'a 3. buton: 'Medyadan' (Icons.photo_library/auto_awesome) → picker'ı aç → dönen URL'leri `variant.images!.addAll(urls)` (upload GEREKMEZ, URL doğrudan kullanılır)
  - Ölü `_addFromMedia` fonksiyonlarını sil; unused import'ları (category.dart, connection.dart) temizle

### 4e. Genel iyileştirmeler (madde 3 için aday listesi)
- [x] socket.js user_undefined bug'ı (lokalde düzeltildi — deploy bekliyor)
- [ ] Medya silme onayları + kullanımdaysa 409/force akışı (4a/4c'de)
- [ ] media_screen'deki kendi lint'lerim: curly_braces (satır 42-63 civarı upload metodları), use_build_context_synchronously (await sonrası ScaffoldMessenger — messenger'ı await ÖNCESİ değişkene al)
- [ ] Ürün ekranlarındaki unused import + unused_element temizliği (4d ile)
- [ ] İsteğe bağlı küçük dokunuşlar: deprecated withOpacity→withValues (sadece dokunulan dosyalarda), media upload'da da kalan use_build_context_synchronously düzeltmeleri
- SONRA: tüm diff'in incelemesi (mantık hataları için), `flutter analyze` (yeni dosyalarda 0 hata hedefi), `node --check` her backend dosyası

### 4f. Deploy + doğrulama + son imaj
1. `node --check` backend dosyaları; `flutter analyze`; `flutter.bat build web --release`
2. Backend deploy: mediaController.js, routes/media.js (değiştiyse), **socket.js**, migration → `deploy_backend.py` örnek alınabilir (index.js zaten kayıtlı, tekrar patch'lemeye çalışma — script 'zaten içeriyor' diye atlar)
3. Migration'ı sunucuda çalıştır (yeni kolonlar + backfill)
4. `pm2 restart toptancim-backend --update-env`
5. Frontend: `deploy_frontend.py`
6. E2E: login (ai_e2e_test_user/AiTest2026!x) → POST generate-ai (202 + placeholder bekleniyor) → birkaç sn poll GET /api/media → status 'ready' olmalı, url dolu → nginx'ten dosya 200
7. **Son imaj**: `python deploy_snapshot.py "async medya + urun entegrasyonu"` + lokal `git add -A && git commit`
8. Memory güncelle: `C:\Users\deizer\.claude\projects\C--Users-deizer-Desktop-toptancim-rapor-toptancim-B2B\memory\` (MEMORY.md index + ilgili dosyalar)

---

## 5. DOSYA DURUMU (lokal, commit edilmemiş değişiklikler)

- `backend/socket.js` — userId düzeltmesi UYGULANDI (deploy edilmedi)
- `backend/db/migration_add_media.sql` — status/source/error_message + backfill EKLENDİ (sunucuya uygulanmadı)
- Diğer her şey commit `a2482d0`'da temiz durumda
- Görev listesi: #7 backend async (in_progress), #8 medya galerisi, #9 ürün ekranları, #10 genel iyileştirme+inceleme, #11 deploy+e2e+son imaj (pending)

## 6. DİKKAT EDİLECEKLER
- Üretim 1-2 dk sürebilir; async olduğundan HTTP timeout artık sorun değil, ama OpenAI çağrısındaki hata mesajı mantığını (moderation_blocked/429/5xx Türkçe mesajlar) arka plan fonksiyonuna TAŞI, kaybetme
- `url=''` placeholder'larken used_in sorgusundaki `m.url <> ''` guard'ı önemli (boş URL her şeyle eşleşmesin)
- Flutter'da `withValues(alpha:)` kullanılıyor (Flutter 3.27+ mevcut, sorun yok); `SegmentedButton`, `surfaceContainerHighest` çalışıyor
- pm2 root'ta; nginx config'e DOKUNMA (proxy'ler hazır)
- Sunucudaki frontend yedeği: `/opt/toptancim/frontend_bak_media`; index.js yedeği: `index.js.bak_media`
- OpenAI key git geçmişinde göründü — kullanıcıya rotate hatırlatması yapıldı, henüz yapmadı
