@echo off
TITLE Toptancim PostgreSQL (CODEX)

SET "RUNTIME=%USERPROFILE%\tools\codex-runtime"
SET "PGBIN=%RUNTIME%\pgsql\bin"
SET "PGDATA=%RUNTIME%\pgdata"
SET "PGLOG=%RUNTIME%\postgres.log"

ECHO ========================================
ECHO      TOPTANCIM POSTGRESQL (CODEX)
ECHO ========================================
ECHO.

IF NOT EXIST "%PGBIN%\pg_ctl.exe" (
  ECHO [HATA] PostgreSQL portable runtime bulunamadi: %PGBIN%
  ECHO Once projeyi Codex ile kurulumdan gecirin.
  PAUSE
  EXIT /B 1
)

IF NOT EXIST "%PGDATA%\PG_VERSION" (
  ECHO [HATA] PostgreSQL data klasoru bulunamadi: %PGDATA%
  ECHO Veritabani cluster'i henuz olusturulmamis.
  PAUSE
  EXIT /B 1
)

ECHO [INFO] PostgreSQL durumu kontrol ediliyor...
"%PGBIN%\pg_isready.exe" -h localhost -p 5432 >NUL 2>NUL
IF %ERRORLEVEL% EQU 0 (
  ECHO [INFO] PostgreSQL zaten calisiyor.
  GOTO :ready
)

ECHO [INFO] PostgreSQL 5432 portunda baslatiliyor...
"%PGBIN%\pg_ctl.exe" -D "%PGDATA%" -o "-p 5432" -l "%PGLOG%" start
ECHO.
ECHO [INFO] PostgreSQL komutu tamamlandi. Log: %PGLOG%
:ready
ECHO Bu pencereyi kapatabilirsiniz; PostgreSQL arka planda calismaya devam eder.
PAUSE
