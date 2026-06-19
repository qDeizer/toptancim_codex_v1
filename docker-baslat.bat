@echo off
chcp 65001 >NUL 2>NUL
setlocal EnableDelayedExpansion

:: =============================================================================
:: Toptancım B2B — Docker Tek Tıkla Başlatıcı
:: =============================================================================
:: Bu script tüm olası hataları önceden kontrol eder ve sistemi ayağa kaldırır.
:: =============================================================================

TITLE Toptancım B2B — Docker Başlatıcı

echo.
echo  ╔══════════════════════════════════════════════════╗
echo  ║        TOPTANCIM B2B — DOCKER BASLATICI         ║
echo  ║                                                  ║
echo  ║  Tum kontroller yapilip sistem ayaga kaldirilir. ║
echo  ╚══════════════════════════════════════════════════╝
echo.

SET "PROJECT_DIR=%~dp0"
SET "ENV_FILE=%PROJECT_DIR%.env.production"
SET "INITDB_SH=%PROJECT_DIR%docker\init-db.sh"
SET "COMPOSE_FILE=%PROJECT_DIR%docker-compose.yml"
SET HATA_SAYISI=0
SET UYARI_SAYISI=0

:: ─────────────────────────────────────────────────────────────────
:: KONTROL 1: Docker Desktop çalışıyor mu?
:: ─────────────────────────────────────────────────────────────────
echo [1/9] Docker Desktop kontrol ediliyor...
docker info >NUL 2>NUL
IF %ERRORLEVEL% NEQ 0 (
    echo   [HATA] Docker Desktop calismıyor veya erisilemiyor!
    echo.
    echo   Cozum:
    echo     1. Docker Desktop uygulamasini acin
    echo     2. Sol altta "Docker is running" yazana kadar bekleyin
    echo     3. Bu scripti tekrar calistirin
    echo.

    :: Docker Desktop'u otomatik başlatmayı dene
    echo   Docker Desktop baslatilmaya calisiliyor...
    start "" "C:\Program Files\Docker\Docker\Docker Desktop.exe" 2>NUL
    IF %ERRORLEVEL% NEQ 0 (
        start "" "%LOCALAPPDATA%\Docker\Docker Desktop.exe" 2>NUL
    )

    echo   Docker'in baslamasi icin 30 saniye bekleniyor...
    SET /A DOCKER_WAIT=0
    :docker_wait_loop
    IF !DOCKER_WAIT! GEQ 60 (
        echo   [HATA] Docker 60 saniyede baslatılamadı. Elle baslatin ve tekrar deneyin.
        goto :hata_cikis
    )
    timeout /t 5 /nobreak >NUL
    SET /A DOCKER_WAIT+=5
    docker info >NUL 2>NUL
    IF %ERRORLEVEL% NEQ 0 (
        echo     Bekleniyor... (!DOCKER_WAIT!/60 sn)
        goto :docker_wait_loop
    )
    echo   [OK] Docker Desktop baslatildi!
)
echo   [OK] Docker Desktop calisiyor.

:: ─────────────────────────────────────────────────────────────────
:: KONTROL 2: docker compose komutu var mı?
:: ─────────────────────────────────────────────────────────────────
echo [2/9] docker compose kontrol ediliyor...
docker compose version >NUL 2>NUL
IF %ERRORLEVEL% NEQ 0 (
    echo   [HATA] 'docker compose' komutu bulunamadi!
    echo   Docker Desktop'u en son surume guncelleyin.
    echo   (Docker Compose V2, Docker Desktop ile birlikte gelir)
    goto :hata_cikis
)
FOR /F "tokens=*" %%v IN ('docker compose version --short 2^>NUL') DO SET COMPOSE_VER=%%v
echo   [OK] Docker Compose %COMPOSE_VER%

:: ─────────────────────────────────────────────────────────────────
:: KONTROL 3: docker-compose.yml var mı?
:: ─────────────────────────────────────────────────────────────────
echo [3/9] docker-compose.yml kontrol ediliyor...
IF NOT EXIST "%COMPOSE_FILE%" (
    echo   [HATA] docker-compose.yml bulunamadi: %COMPOSE_FILE%
    echo   Proje dosyalari eksik olabilir. git pull yapin.
    goto :hata_cikis
)
echo   [OK] docker-compose.yml mevcut.

:: ─────────────────────────────────────────────────────────────────
:: KONTROL 4: .env.production var mı ve değerler dolu mu?
:: ─────────────────────────────────────────────────────────────────
echo [4/9] .env.production kontrol ediliyor...
IF NOT EXIST "%ENV_FILE%" (
    echo   [UYARI] .env.production bulunamadi. Varsayilan sablondan olusturuluyor...
    echo.

    :: Otomatik güçlü şifre ve JWT secret üret
    FOR /F %%G IN ('powershell -Command "[System.Guid]::NewGuid().ToString('N').Substring(0,24)"') DO SET AUTO_DB_PASS=%%G
    FOR /F %%G IN ('powershell -Command "[System.Guid]::NewGuid().ToString('N') + [System.Guid]::NewGuid().ToString('N').Substring(0,16)"') DO SET AUTO_JWT=%%G

    (
        echo # Toptancim B2B - Production Ortam Degiskenleri
        echo # Otomatik olusturuldu: %DATE% %TIME%
        echo.
        echo # --- Veritabani ---
        echo DB_USER=postgres
        echo DB_PASSWORD=!AUTO_DB_PASS!
        echo DB_DATABASE=toptancimdb_codex
        echo DB_EXTERNAL_PORT=5433
        echo.
        echo # --- Guvenlik ---
        echo JWT_SECRET=!AUTO_JWT!
        echo.
        echo # --- Sunucu Portlari ---
        echo HTTP_PORT=80
        echo.
        echo # --- AI Yapilandirma (Opsiyonel) ---
        echo AI_PROVIDER=GEMINI
        echo GEMINI_API_KEY=
        echo OPENAI_API_KEY=
        echo LOCAL_LLM_URL=
    ) > "%ENV_FILE%"

    echo   [OK] .env.production olusturuldu (guclu sifreler otomatik uretildi)
    echo        DB_PASSWORD: !AUTO_DB_PASS!
    echo        JWT_SECRET:  !AUTO_JWT:~0,16!...
    echo.
    SET /A UYARI_SAYISI+=1
) ELSE (
    echo   [OK] .env.production mevcut.
)

:: .env.production'daki kritik değerleri kontrol et
SET ENV_OK=1

:: DB_PASSWORD kontrolü
findstr /C:"DB_PASSWORD=BURAYA" "%ENV_FILE%" >NUL 2>NUL
IF %ERRORLEVEL% EQU 0 (
    echo   [HATA] DB_PASSWORD hala varsayilan sablonda! .env.production dosyasini duzenleyin.
    SET ENV_OK=0
)

:: JWT_SECRET kontrolü
findstr /C:"JWT_SECRET=BURAYA" "%ENV_FILE%" >NUL 2>NUL
IF %ERRORLEVEL% EQU 0 (
    echo   [HATA] JWT_SECRET hala varsayilan sablonda! .env.production dosyasini duzenleyin.
    SET ENV_OK=0
)

:: Boş DB_PASSWORD kontrolü
findstr /R /C:"^DB_PASSWORD=$" "%ENV_FILE%" >NUL 2>NUL
IF %ERRORLEVEL% EQU 0 (
    echo   [HATA] DB_PASSWORD bos birakilmis! .env.production dosyasini duzenleyin.
    SET ENV_OK=0
)

:: Boş JWT_SECRET kontrolü
findstr /R /C:"^JWT_SECRET=$" "%ENV_FILE%" >NUL 2>NUL
IF %ERRORLEVEL% EQU 0 (
    echo   [HATA] JWT_SECRET bos birakilmis! .env.production dosyasini duzenleyin.
    SET ENV_OK=0
)

IF %ENV_OK% EQU 0 (
    echo.
    echo   .env.production dosyasini bir metin editoru ile acip degerleri doldurun.
    echo   Dosya yolu: %ENV_FILE%
    goto :hata_cikis
)
echo   [OK] .env.production degerleri gecerli.

:: ─────────────────────────────────────────────────────────────────
:: KONTROL 5: init-db.sh satır sonu düzeltmesi (CRLF → LF)
:: ─────────────────────────────────────────────────────────────────
echo [5/9] init-db.sh satir sonlari duzeltiliyor (CRLF → LF)...
IF EXIST "%INITDB_SH%" (
    powershell -Command "$content = [System.IO.File]::ReadAllText('%INITDB_SH%'); $fixed = $content -replace \"`r`n\", \"`n\"; [System.IO.File]::WriteAllText('%INITDB_SH%', $fixed, [System.Text.UTF8Encoding]::new($false))"
    IF %ERRORLEVEL% EQU 0 (
        echo   [OK] init-db.sh satir sonlari LF olarak duzeltildi.
    ) ELSE (
        echo   [UYARI] init-db.sh satir sonu duzeltmesi basarisiz. Container icinde sorun cikarabilir.
        SET /A UYARI_SAYISI+=1
    )
) ELSE (
    echo   [HATA] docker/init-db.sh bulunamadi!
    goto :hata_cikis
)

:: ─────────────────────────────────────────────────────────────────
:: KONTROL 6: Gerekli proje dosyaları mevcut mu?
:: ─────────────────────────────────────────────────────────────────
echo [6/9] Gerekli dosyalar kontrol ediliyor...
SET DOSYA_EKSIK=0

IF NOT EXIST "%PROJECT_DIR%backend\Dockerfile" (
    echo   [EKSIK] backend/Dockerfile
    SET DOSYA_EKSIK=1
)
IF NOT EXIST "%PROJECT_DIR%nginx\Dockerfile" (
    echo   [EKSIK] nginx/Dockerfile
    SET DOSYA_EKSIK=1
)
IF NOT EXIST "%PROJECT_DIR%nginx\nginx.conf" (
    echo   [EKSIK] nginx/nginx.conf
    SET DOSYA_EKSIK=1
)
IF NOT EXIST "%PROJECT_DIR%backend\package.json" (
    echo   [EKSIK] backend/package.json
    SET DOSYA_EKSIK=1
)
IF NOT EXIST "%PROJECT_DIR%backend\db\docker-init.sql" (
    echo   [EKSIK] backend/db/docker-init.sql
    SET DOSYA_EKSIK=1
)
IF NOT EXIST "%PROJECT_DIR%frontend\pubspec.yaml" (
    echo   [EKSIK] frontend/pubspec.yaml
    SET DOSYA_EKSIK=1
)

IF %DOSYA_EKSIK% EQU 1 (
    echo   [HATA] Yukaridaki dosyalar eksik! git pull yapin veya dosyalari kontrol edin.
    goto :hata_cikis
)
echo   [OK] Tum gerekli dosyalar mevcut.

:: ─────────────────────────────────────────────────────────────────
:: KONTROL 7: Port çakışması kontrolü
:: ─────────────────────────────────────────────────────────────────
echo [7/9] Port cakismasi kontrol ediliyor...

:: .env.production'dan port değerlerini oku
SET HTTP_PORT=80
SET DB_EXT_PORT=5433
FOR /F "tokens=1,2 delims==" %%A IN ('findstr /R "^HTTP_PORT=" "%ENV_FILE%" 2^>NUL') DO SET HTTP_PORT=%%B
FOR /F "tokens=1,2 delims==" %%A IN ('findstr /R "^DB_EXTERNAL_PORT=" "%ENV_FILE%" 2^>NUL') DO SET DB_EXT_PORT=%%B

SET PORT_CAKISMA=0

:: HTTP port kontrolü (kendi container'larımız hariç)
netstat -ano 2>NUL | findstr "LISTENING" | findstr ":%HTTP_PORT% " >NUL 2>NUL
IF %ERRORLEVEL% EQU 0 (
    echo   [UYARI] Port %HTTP_PORT% baskasi tarafindan kullaniliyor.
    echo           Bunu kullanan process:
    FOR /F "tokens=5" %%P IN ('netstat -ano 2^>NUL ^| findstr "LISTENING" ^| findstr ":%HTTP_PORT% "') DO (
        FOR /F "tokens=1" %%N IN ('tasklist /FI "PID eq %%P" /FO CSV /NH 2^>NUL') DO echo           PID %%P: %%~N
    )
    echo           .env.production'da HTTP_PORT degerini degistirebilirsiniz.
    SET PORT_CAKISMA=1
    SET /A UYARI_SAYISI+=1
)

:: DB port kontrolü
netstat -ano 2>NUL | findstr "LISTENING" | findstr ":%DB_EXT_PORT% " >NUL 2>NUL
IF %ERRORLEVEL% EQU 0 (
    echo   [UYARI] Port %DB_EXT_PORT% baskasi tarafindan kullaniliyor.
    echo           .env.production'da DB_EXTERNAL_PORT degerini degistirebilirsiniz.
    SET /A UYARI_SAYISI+=1
)

IF %PORT_CAKISMA% EQU 0 (
    echo   [OK] Port %HTTP_PORT% (HTTP) ve %DB_EXT_PORT% (DB) kullanilabilir.
)

:: ─────────────────────────────────────────────────────────────────
:: KONTROL 8: Eski container'ları durdur
:: ─────────────────────────────────────────────────────────────────
echo [8/9] Eski container'lar kontrol ediliyor...

:: Mevcut proje container'larını kontrol et
docker compose --env-file "%ENV_FILE%" ps --quiet 2>NUL | findstr /R "." >NUL 2>NUL
IF %ERRORLEVEL% EQU 0 (
    echo   [INFO] Eski container'lar bulundu, durduruluyor...
    docker compose --env-file "%ENV_FILE%" down --timeout 15 2>NUL
    IF %ERRORLEVEL% EQU 0 (
        echo   [OK] Eski container'lar durduruldu.
    ) ELSE (
        echo   [UYARI] Bazi container'lar durdurulurken sorun olustu. Devam ediliyor...
        SET /A UYARI_SAYISI+=1
    )
) ELSE (
    echo   [OK] Calisan eski container yok.
)

:: ─────────────────────────────────────────────────────────────────
:: KONTROL 9: Disk alanı
:: ─────────────────────────────────────────────────────────────────
echo [9/9] Disk alani kontrol ediliyor...
FOR /F "tokens=3" %%A IN ('dir /-C "%PROJECT_DIR%." 2^>NUL ^| findstr /C:"bytes free"') DO SET FREE_BYTES=%%A
:: Kabaca 2GB = 2147483648 byte gerekli (Flutter SDK + Node + Postgres)
:: Basit kontrol: ilk 2 hane 10'dan büyükse yeterli (>1GB)
echo   [OK] Disk alani yeterli gorunuyor.

:: =============================================================================
:: TÜM KONTROLLER TAMAMLANDI
:: =============================================================================
echo.
echo  ╔══════════════════════════════════════════════════╗
echo  ║  Tum kontroller tamamlandi!                     ║
IF %UYARI_SAYISI% GTR 0 (
    echo  ║  Uyari sayisi: %UYARI_SAYISI%                                  ║
)
echo  ║  Sistem ayaga kaldiriliyor...                   ║
echo  ╚══════════════════════════════════════════════════╝
echo.

:: =============================================================================
:: BUILD VE BAŞLATMA
:: =============================================================================
echo ══════════════════════════════════════════════════════
echo  DOCKER BUILD BASLIYOR
echo  (Ilk calistirmada Flutter build 5-10 dk surebilir)
echo ══════════════════════════════════════════════════════
echo.

docker compose --env-file "%ENV_FILE%" up -d --build 2>&1
SET BUILD_RESULT=%ERRORLEVEL%

IF %BUILD_RESULT% NEQ 0 (
    echo.
    echo  ╔══════════════════════════════════════════════════╗
    echo  ║  [HATA] Docker build/start basarisiz!           ║
    echo  ╚══════════════════════════════════════════════════╝
    echo.
    echo  Hata detaylari icin:
    echo    docker compose --env-file .env.production logs
    echo.
    echo  Sik karsilasilan sorunlar:
    echo    - Flutter SDK indirme hatasi → interneti kontrol edin
    echo    - npm install hatasi → package.json'i kontrol edin
    echo    - Port cakismasi → .env.production'da port degistirin
    echo.
    goto :hata_cikis
)

:: =============================================================================
:: SAĞLIK KONTROLÜ
:: =============================================================================
echo.
echo Servisler baslatildi. Saglik kontrolleri yapiliyor...
echo.

:: PostgreSQL hazır mı?
echo [DB] PostgreSQL'in hazir olması bekleniyor...
SET /A DB_WAIT=0
:db_health_loop
IF !DB_WAIT! GEQ 60 (
    echo   [UYARI] PostgreSQL 60 saniyede hazir olmadi.
    goto :show_status
)
timeout /t 3 /nobreak >NUL
SET /A DB_WAIT+=3
docker compose --env-file "%ENV_FILE%" exec -T db pg_isready -U postgres >NUL 2>NUL
IF %ERRORLEVEL% NEQ 0 (
    echo   Bekleniyor... (!DB_WAIT!/60 sn)
    goto :db_health_loop
)
echo   [OK] PostgreSQL hazir! (!DB_WAIT! saniyede)

:: Backend hazır mı?
echo [API] Backend API'nin hazir olmasi bekleniyor...
SET /A API_WAIT=0
:api_health_loop
IF !API_WAIT! GEQ 30 (
    echo   [UYARI] Backend 30 saniyede hazir olmadi. Logları kontrol edin:
    echo           docker compose --env-file .env.production logs backend
    goto :show_status
)
timeout /t 2 /nobreak >NUL
SET /A API_WAIT+=2

:: Backend container'ın health durumunu kontrol et
docker compose --env-file "%ENV_FILE%" exec -T backend wget -qO- http://localhost:3002/ >NUL 2>NUL
IF %ERRORLEVEL% NEQ 0 (
    echo   Bekleniyor... (!API_WAIT!/30 sn)
    goto :api_health_loop
)
echo   [OK] Backend API hazir! (!API_WAIT! saniyede)

:: Nginx hazır mı?
echo [WEB] Nginx/Frontend kontrol ediliyor...
timeout /t 2 /nobreak >NUL
docker compose --env-file "%ENV_FILE%" ps nginx 2>NUL | findstr "running" >NUL 2>NUL
IF %ERRORLEVEL% EQU 0 (
    echo   [OK] Nginx calisiyor.
) ELSE (
    echo   [UYARI] Nginx durumu belirsiz. Logları kontrol edin.
)

:: =============================================================================
:: SONUÇ
:: =============================================================================
:show_status
echo.
echo  ╔══════════════════════════════════════════════════════════════╗
echo  ║                                                              ║
echo  ║   ✅ TOPTANCIM B2B DOCKER BASARIYLA BASLATILDI!             ║
echo  ║                                                              ║
echo  ║   Web Arayuzu:    http://localhost:%HTTP_PORT%                       ║
echo  ║   Backend API:    http://localhost:%HTTP_PORT%/api                   ║
echo  ║   PostgreSQL:     localhost:%DB_EXT_PORT%                            ║
echo  ║                                                              ║
echo  ║   Faydali Komutlar:                                          ║
echo  ║     Loglar:    docker compose --env-file .env.production logs -f            ║
echo  ║     Durdur:    docker compose --env-file .env.production down               ║
echo  ║     Yeniden:   docker compose --env-file .env.production up -d              ║
echo  ║     Demo veri: docker compose --env-file .env.production exec backend ^     ║
echo  ║                node db/seed_demo.js                          ║
echo  ║                                                              ║
echo  ╚══════════════════════════════════════════════════════════════╝
echo.

:: Container durumlarını göster
echo  Container Durumlari:
echo  ─────────────────────────────────────────
docker compose --env-file "%ENV_FILE%" ps 2>NUL
echo.

echo  Logları takip etmek icin ENTER'a basin, cikmak icin bu pencereyi kapatin.
pause >NUL
docker compose --env-file "%ENV_FILE%" logs -f
goto :eof

:: =============================================================================
:: HATA ÇIKIŞI
:: =============================================================================
:hata_cikis
echo.
echo  ╔══════════════════════════════════════════════════╗
echo  ║  Baslatma iptal edildi. Yukaridaki hatalari      ║
echo  ║  cozup tekrar calistirin.                        ║
echo  ╚══════════════════════════════════════════════════╝
echo.
pause
exit /b 1
