@echo off
chcp 65001 >NUL 2>NUL
TITLE Toptancım B2B — Docker Durdur

echo.
echo  ╔══════════════════════════════════════════════════╗
echo  ║        TOPTANCIM B2B — DOCKER DURDUR             ║
echo  ╚══════════════════════════════════════════════════╝
echo.

SET "ENV_FILE=%~dp0.env.production"

echo [1/2] Container'lar durduruluyor...
docker compose --env-file "%ENV_FILE%" down --timeout 15 2>NUL
IF %ERRORLEVEL% EQU 0 (
    echo   [OK] Tum container'lar durduruldu.
) ELSE (
    echo   [UYARI] Bazi container'lar durdurulurken sorun olustu.
    echo           Elle durdurmak icin: docker compose down --remove-orphans
)

echo.
echo [2/2] Container durumlari:
docker compose --env-file "%ENV_FILE%" ps -a 2>NUL
echo.

echo NOT: Veritabani verileri ve yuklemeler korunmustur (Docker volumes).
echo      Tamamen silmek icin: docker compose --env-file .env.production down -v
echo.
pause
