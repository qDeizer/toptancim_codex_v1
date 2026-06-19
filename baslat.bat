@echo off
REM Toptancim - tum servisleri baslatir (PostgreSQL -> Backend -> Frontend)
SETLOCAL
SET "RUNTIME=%USERPROFILE%\tools\codex-runtime"
SET "PGBIN=%RUNTIME%\pgsql\bin"

REM 1) PostgreSQL'i ayri pencerede baslat
START "Toptancim PostgreSQL (CODEX)" postgres.bat

REM 2) PostgreSQL gercekten hazir olana kadar bekle (sabit 4 sn yerine pg_isready)
ECHO [INFO] PostgreSQL hazir olmasi bekleniyor...
SET /A tries=0
:waitpg
IF NOT EXIST "%PGBIN%\pg_isready.exe" (
  ECHO [UYARI] pg_isready bulunamadi, 4 sn beklenip devam edilecek.
  TIMEOUT /T 4 /NOBREAK >NUL
  GOTO pgready
)
"%PGBIN%\pg_isready.exe" -h localhost -p 5432 >NUL 2>NUL
IF %ERRORLEVEL% EQU 0 GOTO pgready
SET /A tries+=1
IF %tries% GEQ 30 (
  ECHO [UYARI] PostgreSQL 30 sn icinde hazir olmadi, yine de devam ediliyor.
  GOTO pgready
)
TIMEOUT /T 1 /NOBREAK >NUL
GOTO waitpg
:pgready
ECHO [INFO] PostgreSQL hazir.

REM 3) Backend (port 3002) ve Frontend (port 8089) baslat
START "Toptancim Backend (CODEX)" backend.bat
START "Toptancim Frontend (CODEX)" frontend.bat

ENDLOCAL
