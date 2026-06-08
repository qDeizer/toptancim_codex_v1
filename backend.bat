@echo off
TITLE Toptancim Backend (CODEX)

ECHO ========================================
ECHO      TOPTANCIM BACKEND SERVER (CODEX)
ECHO ========================================
ECHO.
ECHO Backend sunucusu baslatiliyor (CODEX instance)...
ECHO Konum: backend/
ECHO Port: 3002
ECHO.

REM Backend'i mevcut pencerede baslat ve hata durumunda pencereyi acik tut
cd /d "%~dp0backend"
echo [INFO] Backend dizinine gecildi: %CD%
echo [INFO] Node.js versiyonu kontrol ediliyor...
node --version || (echo [HATA] Node.js bulunamadi! Lutfen Node.js yukleyin. && pause && exit /b 1)
echo.
echo [INFO] Package.json kontrol ediliyor...
if not exist package.json (echo [HATA] package.json bulunamadi! && pause && exit /b 1)
echo.
echo [INFO] .env dosyasi kontrol ediliyor...
if not exist .env (echo [UYARI] .env dosyasi bulunamadi! Veritabani baglantisi basarisiz olabilir.)
echo.
echo [INFO] Backend server baslatiliyor (CODEX - Port 3002)...
echo ========================================
node index.js
echo.
echo [INFO] Backend server durduruldu.
echo Pencereyi kapatmak icin bir tusa basin...
pause